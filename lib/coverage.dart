import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

/// Catégories proposées dans le formulaire de demande de couverture.
const coverageCategories = [
  'Conférence / séminaire',
  'Cérémonie religieuse',
  'Mariage / baptême',
  'Politique',
  'Sport',
  'Culture / spectacle',
  'Association / ONG',
  'Entreprise',
  'Autre',
];

/// Demande de couverture d'un événement par l'équipe de Dialaw TV.
class CoverageRequest {
  const CoverageRequest({
    required this.id,
    required this.live,
    required this.title,
    required this.category,
    required this.date,
    required this.place,
    required this.requester,
    required this.phone,
    required this.details,
    required this.sentAt,
  });

  factory CoverageRequest.fromJson(Map<String, dynamic> json) {
    return CoverageRequest(
      id: json['id'] as String,
      live: json['live'] as bool,
      title: json['title'] as String,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      place: json['place'] as String,
      requester: json['requester'] as String,
      phone: json['phone'] as String,
      details: json['details'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );
  }

  final String id;

  /// true : couverture en direct ; false : couverture simple (reportage).
  final bool live;
  final String title;
  final String category;
  final DateTime date;
  final String place;
  final String requester;
  final String phone;
  final String details;
  final DateTime sentAt;

  String get typeLabel => live ? 'Couverture en direct' : 'Couverture simple';

  Map<String, dynamic> toJson() => {
    'id': id,
    'live': live,
    'title': title,
    'category': category,
    'date': date.toIso8601String(),
    'place': place,
    'requester': requester,
    'phone': phone,
    'details': details,
    'sentAt': sentAt.toIso8601String(),
  };

  /// Message reçu par la rédaction. Les astérisques mettent en gras dans WhatsApp.
  String toMessage() {
    final lines = [
      '*Demande de couverture – ${AppConfig.appName}*',
      '',
      '*Type :* $typeLabel',
      '*Événement :* $title',
      '*Catégorie :* $category',
      '*Date :* ${formatCoverageDate(date)}',
      '*Lieu :* $place',
      '*Demandeur :* $requester',
      '*Téléphone :* $phone',
      if (details.isNotEmpty) '*Détails :* $details',
      '',
      '_Envoyé depuis l’application ${AppConfig.appName}_',
    ];
    return lines.join('\n');
  }
}

String formatCoverageDate(DateTime date) {
  final text = DateFormat("EEEE d MMMM y 'à' HH:mm", 'fr').format(date);
  return text[0].toUpperCase() + text.substring(1);
}

/// Version abrégée pour les champs étroits : « Mer. 28 oct. 2026 à 10:00 ».
String formatCoverageDateShort(DateTime date) {
  final text = DateFormat("EEE d MMM y 'à' HH:mm", 'fr').format(date);
  return text[0].toUpperCase() + text.substring(1);
}

/// La rédaction est joignable si un numéro WhatsApp ou un e-mail est configuré.
bool get coverageContactConfigured =>
    AppConfig.whatsapp.isNotEmpty || AppConfig.email.isNotEmpty;

/// Ouvre WhatsApp (ou, à défaut, la messagerie) avec la demande pré-remplie.
/// Renvoie false si aucun contact n'est configuré ou si rien n'a pu s'ouvrir.
Future<bool> sendCoverageRequest(CoverageRequest request) async {
  final message = request.toMessage();
  final Uri uri;
  if (AppConfig.whatsapp.isNotEmpty) {
    uri = Uri.https('wa.me', '/${AppConfig.whatsapp}', {'text': message});
  } else if (AppConfig.email.isNotEmpty) {
    uri = Uri(
      scheme: 'mailto',
      path: AppConfig.email,
      // Uri encode les espaces en « + » dans queryParameters, ce que les
      // clients mail affichent tels quels : on encode à la main.
      query:
          'subject=${Uri.encodeComponent('Demande de couverture : ${request.title}')}'
          '&body=${Uri.encodeComponent(message.replaceAll('*', '').replaceAll('_', ''))}',
    );
  } else {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Historique des demandes envoyées depuis cet appareil.
class CoverageStore extends ChangeNotifier {
  CoverageStore._(this._prefs, this._requests);

  static const _kRequests = 'coverage_requests';

  static Future<CoverageStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final requests = <CoverageRequest>[];
    for (final raw in prefs.getStringList(_kRequests) ?? const <String>[]) {
      try {
        requests.add(CoverageRequest.fromJson(jsonDecode(raw)));
      } catch (_) {
        // Entrée corrompue ou d'un ancien format : ignorée.
      }
    }
    return CoverageStore._(prefs, requests);
  }

  final SharedPreferences _prefs;
  final List<CoverageRequest> _requests;

  /// Les plus récentes d'abord.
  List<CoverageRequest> get requests => List.unmodifiable(_requests.reversed);

  Future<void> add(CoverageRequest request) async {
    _requests.add(request);
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _requests.removeWhere((r) => r.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _prefs.setStringList(_kRequests, [
    for (final r in _requests) jsonEncode(r.toJson()),
  ]);
}
