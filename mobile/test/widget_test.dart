import 'package:flutter_test/flutter_test.dart';

import 'package:qrflow_mobile/app/app.dart';

void main() {
  testWidgets("La marque QRFlow s'affiche sur l'écran d'accueil",
      (WidgetTester tester) async {
    await tester.pumpWidget(const QrFlowApp());
    expect(find.text('QRFlow'), findsOneWidget);
  });
}
