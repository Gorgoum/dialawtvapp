import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dialaw_tv/coverage.dart';
import 'package:dialaw_tv/pages/contacts_page.dart';
import 'package:dialaw_tv/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('La page Contacts s’affiche en thème ${brightness.name}', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness),
          home: Scaffold(
            body: ContactsPage(onRequestCoverage: () => tapped = true),
          ),
        ),
      );

      expect(find.text('Restons connectés'), findsOneWidget);
      expect(find.text('Site web'), findsOneWidget);
      await tester.tap(find.text('Demander une couverture'));
      expect(tapped, isTrue);
    });
  }

  test('Le message de demande de couverture reprend tous les champs', () async {
    await initializeDateFormatting('fr');
    final request = CoverageRequest(
      id: '1',
      live: true,
      title: 'Conférence de presse',
      category: 'Politique',
      date: DateTime(2026, 11, 7, 15, 30),
      place: 'Dakar, Plateau',
      requester: 'Association Test',
      phone: '77 000 00 00',
      details: '',
      sentAt: DateTime(2026, 10, 23),
    );

    final message = request.toMessage();
    expect(message, contains('*Type :* Couverture en direct'));
    expect(message, contains('*Date :* Samedi 7 novembre 2026 à 15:30'));
    expect(message, contains('*Lieu :* Dakar, Plateau'));
    expect(message, isNot(contains('Détails')));

    final roundTrip = CoverageRequest.fromJson(request.toJson());
    expect(roundTrip.toMessage(), message);
  });
}
