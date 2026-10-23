import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dialaw_tv/coverage.dart';
import 'package:dialaw_tv/pages/contacts_page.dart';
import 'package:dialaw_tv/pages/coverage_page.dart';
import 'package:dialaw_tv/pages/live_page.dart';
import 'package:dialaw_tv/pages/settings_page.dart';
import 'package:dialaw_tv/pages/subscription_page.dart';
import 'package:dialaw_tv/settings.dart';
import 'package:dialaw_tv/subscription.dart';
import 'package:dialaw_tv/theme.dart';

/// Tailles d'écran courantes (en points logiques) : du petit Android d'entrée
/// de gamme à la tablette, en portrait et en paysage.
const _screens = {
  'petit téléphone 320x568': Size(320, 568),
  'Android courant 360x640': Size(360, 640),
  'grand Android 412x915': Size(412, 915),
  'iPhone 390x844': Size(390, 844),
  'téléphone paysage 915x412': Size(915, 412),
  'tablette portrait 768x1024': Size(768, 1024),
  'tablette paysage 1280x800': Size(1280, 800),
};

/// Taille de police système : normale, grande, et maximale d'Android 14+.
const _textScales = [1.0, 1.3, 2.0];

void main() {
  late AppSettings settings;
  late CoverageStore store;
  late SubscriptionService subscription;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    // Le direct garde l'écran allumé via wakelock_plus : pas de plugin natif en test.
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'profile_name': 'Awa Ndiaye Diop',
      'profile_phone': '77 000 00 00',
      'profile_email': 'awa.ndiaye.diop@exemple.sn',
    });
    settings = await AppSettings.load();
    store = await CoverageStore.load();
    // Serveur simulé : essai en cours, 12 jours restants.
    subscription = await SubscriptionService.load(
      baseUrl: 'https://api.test',
      client: MockClient(
        (_) async => http.Response(
          '{"status":"trial","trialEndsAt":"${_in(12)}",'
          '"paidUntil":null,"accessUntil":"${_in(12)}"}',
          200,
        ),
      ),
    );
    await subscription.refresh();
    await store.add(
      CoverageRequest(
        id: '1',
        live: true,
        title: 'Grande conférence annuelle des associations de jeunesse',
        category: 'Association / ONG',
        date: DateTime.now().add(const Duration(days: 3)),
        place: 'Centre international de conférences, Diamniadio',
        requester: 'Association Test',
        phone: '77 000 00 00',
        details: '',
        sentAt: DateTime.now(),
      ),
    );
  });

  final pages = <String, Widget Function()>{
    'Direct': () => LivePage(
      active: false,
      onOpenNews: () {},
      onOpenContacts: () {},
      onRequestCoverage: () {},
    ),
    'Contacts': () => ContactsPage(onRequestCoverage: () {}),
    'Paramètres': () => SettingsPage(settings: settings),
    'Mon profil': () => ProfileEditPage(settings: settings),
    'Demande de couverture': () =>
        CoverageRequestPage(settings: settings, store: store),
    'Mes demandes': () => MyCoverageRequestsPage(store: store),
    'Direct verrouillé': () => LivePage(
      active: false,
      onOpenNews: () {},
      onOpenContacts: () {},
      onRequestCoverage: () {},
      locked: true,
      onSubscribe: () {},
    ),
    'Direct en essai': () => LivePage(
      active: false,
      onOpenNews: () {},
      onOpenContacts: () {},
      onRequestCoverage: () {},
      accessNote:
          'Essai gratuit : 12 jours restants. Abonnez-vous dès 1 000 FCFA/mois',
      onSubscribe: () {},
    ),
    'Mon abonnement': () => SubscriptionPage(subscription: subscription),
    'Paramètres avec abonnement': () =>
        SettingsPage(settings: settings, subscription: subscription),
  };

  for (final page in pages.entries) {
    for (final screen in _screens.entries) {
      for (final scale in _textScales) {
        for (final brightness in Brightness.values) {
          testWidgets(
            '${page.key} · ${screen.key} · police ×$scale · ${brightness.name}',
            (tester) async {
              tester.view.physicalSize = screen.value;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(
                MaterialApp(
                  theme: buildTheme(brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(body: page.value()),
                ),
              );
              // Pas de pumpAndSettle : le badge « EN DIRECT » pulse sans fin.
              await tester.pump(const Duration(milliseconds: 300));

              // Une liste ne construit que ce qui est visible : on la fait défiler
              // jusqu'en bas pour vérifier aussi le contenu hors écran.
              final scrollable = find.byType(Scrollable);
              if (scrollable.evaluate().isNotEmpty) {
                for (var i = 0; i < 10; i++) {
                  await tester.drag(
                    scrollable.last,
                    const Offset(0, -400),
                    warnIfMissed: false,
                  );
                  await tester.pump(const Duration(milliseconds: 100));
                }
              }

              // Un débordement de mise en page fait échouer le test avec le
              // widget fautif : pas de takeException, qui masquerait le détail.
            },
          );
        }
      }
    }
  }
}

String _in(int days) =>
    DateTime.now().add(Duration(days: days)).toUtc().toIso8601String();
