import 'package:flutter_test/flutter_test.dart';

import 'package:qrflow_mobile/core/models/qr_content.dart';
import 'package:qrflow_mobile/core/services/content_analyzer.dart';
import 'package:qrflow_mobile/core/services/overlay_payload.dart';

void main() {
  group('buildOverlayPayload', () {
    test('URL : domaine et suspicion transmis au natif', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('https://bit.ly/3xYzAb') as QrUrl,
      );
      expect(p['typeLabel'], 'Lien web');
      expect(p['domain'], 'bit.ly');
      expect(p['suspicious'], isTrue);
      expect(p['primaryCode'], 'openUrl');
      expect(p['display'], 'https://bit.ly/3xYzAb');
    });

    test('URL saine : suspicion à faux', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('https://example.com/page') as QrUrl,
      );
      expect(p['suspicious'], isFalse);
      expect(p['domain'], 'example.com');
    });

    test('Téléphone : numéro + action d’appel', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('tel:+33123456789') as QrPhone,
      );
      expect(p['number'], '+33123456789');
      expect(p['primaryCode'], 'dial');
      expect(p['primaryLabel'], 'Appeler');
    });

    test('E-mail : adresse transmise', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('mailto:jean@example.com') as QrEmail,
      );
      expect(p['address'], 'jean@example.com');
      expect(p['primaryCode'], 'email');
    });

    test('Wi-Fi : mot de passe pour l’action copier', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('WIFI:T:WPA;S:LaFibre;P:secret123;;') as QrWifi,
      );
      expect(p['ssid'], 'LaFibre');
      expect(p['password'], 'secret123');
      expect(p['primaryCode'], 'copyPassword');
      expect(p['details'], contains('Réseau : LaFibre'));
    });

    test('GPS : latitude/longitude numériques', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('geo:48.8566,2.3522') as QrGeo,
      );
      expect(p['latitude'], closeTo(48.8566, 0.0001));
      expect(p['longitude'], closeTo(2.3522, 0.0001));
      expect(p['primaryCode'], 'maps');
    });

    test('SMS : numéro et message', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('sms:+33123456789?body=Bonjour') as QrSms,
      );
      expect(p['number'], '+33123456789');
      expect(p['message'], 'Bonjour');
    });

    test('Texte brut : repli générique copier', () {
      final Map<String, dynamic> p = buildOverlayPayload(
        ContentAnalyzer.analyze('Bonjour le monde') as QrText,
      );
      expect(p['primaryCode'], 'copy');
      expect(p['typeLabel'], 'Texte');
    });
  });
}
