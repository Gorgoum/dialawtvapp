import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dialaw_tv/pages/contacts_page.dart';

void main() {
  testWidgets('La page Contacts affiche au moins le site web', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ContactsPage())),
    );

    expect(find.text('Contactez-nous'), findsOneWidget);
    expect(find.text('Site web'), findsOneWidget);
  });
}
