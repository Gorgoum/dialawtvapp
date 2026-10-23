import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Formules proposées. Les montants font foi côté serveur (server/lib/subscription.js).
enum Plan {
  monthly('monthly', 'Mensuel', 1000, 'par mois'),
  yearly('yearly', 'Annuel', 10000, 'par an');

  const Plan(this.id, this.label, this.amount, this.period);

  final String id;
  final String label;
  final int amount;
  final String period;
}

enum AccessStatus { trial, active, expired }

/// Réponse de POST /api/access.
class AccessInfo {
  const AccessInfo({
    required this.status,
    required this.trialEndsAt,
    required this.paidUntil,
    required this.accessUntil,
  });

  factory AccessInfo.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null
        ? null
        : DateTime.parse(json[key] as String).toLocal();
    return AccessInfo(
      status: AccessStatus.values.byName(json['status'] as String),
      trialEndsAt: date('trialEndsAt')!,
      paidUntil: date('paidUntil'),
      accessUntil: date('accessUntil'),
    );
  }

  final AccessStatus status;
  final DateTime trialEndsAt;
  final DateTime? paidUntil;
  final DateTime? accessUntil;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'trialEndsAt': trialEndsAt.toUtc().toIso8601String(),
    'paidUntil': paidUntil?.toUtc().toIso8601String(),
    'accessUntil': accessUntil?.toUtc().toIso8601String(),
  };
}

/// Essai gratuit et abonnement de l'appareil, vérifiés auprès du serveur.
/// Le dernier état connu est gardé pour fonctionner sans réseau.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._(
    this._prefs,
    this.deviceId,
    this._info, {
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _kDeviceId = 'device_id';
  static const _kAccess = 'access_info';
  static const _channel = MethodChannel('sn.dialawtv/device');

  static Future<SubscriptionService> load({
    String baseUrl = AppConfig.apiBaseUrl,
    http.Client? client,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    AccessInfo? cached;
    try {
      final raw = prefs.getString(_kAccess);
      if (raw != null) cached = AccessInfo.fromJson(jsonDecode(raw));
    } catch (_) {
      // Ancien format : ignoré, il sera redemandé au serveur.
    }
    return SubscriptionService._(
      prefs,
      await _deviceId(prefs),
      cached,
      baseUrl: baseUrl,
      client: client,
    );
  }

  /// ANDROID_ID (stable à la réinstallation) ; ailleurs, identifiant aléatoire mémorisé.
  static Future<String> _deviceId(SharedPreferences prefs) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final id = await _channel.invokeMethod<String>('deviceId');
        if (id != null && id.length >= 8) return 'a_$id';
      } on PlatformException {
        // Repli sur l'identifiant mémorisé.
      } on MissingPluginException {
        // Tests : pas de code natif.
      }
    }
    final saved = prefs.getString(_kDeviceId);
    if (saved != null) return saved;
    final random = Random.secure();
    final id =
        'r_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    await prefs.setString(_kDeviceId, id);
    return id;
  }

  final SharedPreferences _prefs;
  final http.Client _client;
  final String deviceId;

  /// Adresse du serveur (AppConfig.apiBaseUrl, remplaçable dans les tests).
  final String baseUrl;
  AccessInfo? _info;
  bool _loading = false;

  /// L'abonnement n'est actif que si le serveur est configuré.
  bool get enabled => baseUrl.isNotEmpty;
  AccessInfo? get info => _info;
  bool get loading => _loading;

  /// Le direct est-il accessible ? Sans réponse du serveur depuis l'installation,
  /// on laisse regarder : le premier contact démarre de toute façon l'essai.
  bool get canWatch {
    if (!enabled) return true;
    final info = _info;
    if (info == null) return true;
    final until = info.accessUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  /// Jours restants d'essai ou d'abonnement (arrondi au jour supérieur).
  int? get daysLeft {
    final until = _info?.accessUntil;
    if (until == null) return null;
    final hours = until.difference(DateTime.now()).inHours;
    return hours <= 0 ? 0 : (hours / 24).ceil();
  }

  Uri _api(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          _api(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw SubscriptionException(
        data['error'] as String? ?? 'Erreur ${response.statusCode}',
      );
    }
    return data;
  }

  /// Redemande l'état au serveur. En cas d'échec, l'état mémorisé est conservé.
  Future<bool> refresh() async {
    if (!enabled || _loading) return false;
    _loading = true;
    notifyListeners();
    try {
      final data = await _post('/api/access', {
        'deviceId': deviceId,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });
      _info = AccessInfo.fromJson(data);
      await _prefs.setString(_kAccess, jsonEncode(_info!.toJson()));
      return true;
    } catch (error) {
      debugPrint('Abonnement : vérification impossible ($error)');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Crée le paiement et renvoie le lien qui ouvre Wave.
  Future<Uri> startCheckout(Plan plan) async {
    try {
      final data = await _post('/api/checkout', {
        'deviceId': deviceId,
        'plan': plan.id,
      });
      return Uri.parse(data['launchUrl'] as String);
    } on SubscriptionException {
      rethrow;
    } catch (_) {
      throw const SubscriptionException(
        'Connexion impossible. Vérifiez votre connexion Internet et réessayez.',
      );
    }
  }
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}
