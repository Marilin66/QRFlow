import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qrflow_mobile/app/app.dart';

void main() {
  testWidgets("La marque QRFlow s'affiche sur l'accueil",
      (WidgetTester tester) async {
    await tester.pumpWidget(const QrFlowApp());
    expect(find.text('QRFlow'), findsOneWidget);
  });

  testWidgets('Naviguer vers Importer une image',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QrFlowApp());
    await tester.tap(find.text('Importer une image'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Importer une image'), findsOneWidget);
  });

  testWidgets('Naviguer vers les Réglages', (WidgetTester tester) async {
    await tester.pumpWidget(const QrFlowApp());
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Apparence'), findsOneWidget);
  });
}
