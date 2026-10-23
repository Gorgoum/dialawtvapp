import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dialaw_tv/subscription.dart';

const _api = 'https://api.test';

String _iso(Duration fromNow) =>
    DateTime.now().add(fromNow).toUtc().toIso8601String();

Map<String, dynamic> _access(String status, {Duration? until}) => {
  'status': status,
  'trialEndsAt': _iso(const Duration(days: 30)),
  'paidUntil': null,
  'accessUntil': until == null ? null : _iso(until),
  'serverTime': _iso(Duration.zero),
};

MockClient _server(Map<String, dynamic> Function(http.Request) handler) =>
    MockClient((request) async {
      final body = handler(request);
      final status = body.containsKey('error') ? 400 : 200;
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sans serveur configuré, le direct reste gratuit', () async {
    final sub = await SubscriptionService.load(baseUrl: '');
    expect(sub.enabled, isFalse);
    expect(sub.canWatch, isTrue);
    expect(await sub.refresh(), isFalse);
  });

  test('premier lancement : essai de 30 jours, identifiant envoyé', () async {
    late Map<String, dynamic> sent;
    final sub = await SubscriptionService.load(
      baseUrl: _api,
      client: _server((r) {
        expect(r.url.toString(), '$_api/api/access');
        sent = jsonDecode(r.body);
        return _access('trial', until: const Duration(days: 30));
      }),
    );
    // Avant toute réponse : on laisse regarder.
    expect(sub.canWatch, isTrue);
    expect(await sub.refresh(), isTrue);
    expect(sub.info!.status, AccessStatus.trial);
    expect(sub.daysLeft, 30);
    expect(sub.canWatch, isTrue);
    expect(sent['deviceId'], sub.deviceId);
    expect(sub.deviceId, matches(RegExp(r'^[A-Za-z0-9_-]{8,128}$')));
  });

  test('essai terminé sans paiement : direct verrouillé', () async {
    final sub = await SubscriptionService.load(
      baseUrl: _api,
      client: _server((_) => _access('expired')),
    );
    await sub.refresh();
    expect(sub.canWatch, isFalse);
  });

  test(
    'hors ligne : le dernier état connu est conservé, jusqu’à sa date de fin',
    () async {
      final online = await SubscriptionService.load(
        baseUrl: _api,
        client: _server(
          (_) => _access('active', until: const Duration(hours: 5)),
        ),
      );
      await online.refresh();

      // Relance de l'appli sans réseau : l'abonnement mémorisé reste valable.
      final offline = await SubscriptionService.load(
        baseUrl: _api,
        client: MockClient(
          (_) async => throw http.ClientException('hors ligne'),
        ),
      );
      expect(await offline.refresh(), isFalse);
      expect(offline.info!.status, AccessStatus.active);
      expect(offline.canWatch, isTrue);
      expect(offline.deviceId, online.deviceId, reason: 'même identifiant');
    },
  );

  test('hors ligne avec un abonnement mémorisé échu : verrouillé', () async {
    final online = await SubscriptionService.load(
      baseUrl: _api,
      client: _server(
        (_) => _access('active', until: const Duration(seconds: -1)),
      ),
    );
    await online.refresh();
    final offline = await SubscriptionService.load(
      baseUrl: _api,
      client: MockClient((_) async => throw http.ClientException('hors ligne')),
    );
    expect(offline.canWatch, isFalse);
  });

  test(
    'paiement : le lien Wave est renvoyé, les erreurs sont lisibles',
    () async {
      final sub = await SubscriptionService.load(
        baseUrl: _api,
        client: _server((r) {
          final body = jsonDecode(r.body);
          if (body['plan'] == 'yearly') {
            return {
              'paymentId': 'p1',
              'launchUrl': 'https://pay.wave.com/c/cos-123',
            };
          }
          return {'error': 'Wave indisponible, réessayez.'};
        }),
      );
      expect(
        (await sub.startCheckout(Plan.yearly)).toString(),
        'https://pay.wave.com/c/cos-123',
      );
      expect(
        () => sub.startCheckout(Plan.monthly),
        throwsA(
          isA<SubscriptionException>().having(
            (e) => e.message,
            'message',
            'Wave indisponible, réessayez.',
          ),
        ),
      );
    },
  );

  test('tarifs affichés identiques à ceux du serveur', () {
    expect(Plan.monthly.amount, 1000);
    expect(Plan.yearly.amount, 10000);
  });
}
