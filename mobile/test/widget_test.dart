import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qrflow_mobile/app/app.dart';

/// Pompe suffisamment de frames pour laisser la transition de route se
/// terminer (l'animation infinie de ScanLine empêche l'usage de
/// pumpAndSettle).
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets("La marque QRFlow s'affiche sur l'accueil",
      (WidgetTester tester) async {
    await tester.pumpWidget(const QrFlowApp());
    expect(find.text('QRFlow'), findsOneWidget);
  });

  testWidgets('Naviguer vers Importer une image',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QrFlowApp());
    await tester.tap(find.text('Importer une image'));
    await _settle(tester);
    // Une fois la transition finie, la carte d'accueil est hors écran :
    // seul le titre de l'AppBar reste visible.
    expect(find.text('Importer une image'), findsOneWidget);
  });

  testWidgets('Naviguer vers les Réglages', (WidgetTester tester) async {
    await tester.pumpWidget(const QrFlowApp());
    await tester.tap(find.byIcon(Icons.tune));
    await _settle(tester);
    expect(find.text('Apparence'), findsOneWidget);
  });
}
