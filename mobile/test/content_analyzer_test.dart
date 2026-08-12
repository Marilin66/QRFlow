import 'package:flutter_test/flutter_test.dart';

import 'package:qrflow_mobile/core/models/qr_content.dart';
import 'package:qrflow_mobile/core/services/content_analyzer.dart';

void main() {
  group('ContentAnalyzer', () {
    test('URL https simple', () {
      final QrContent c = ContentAnalyzer.analyze('https://example.com/page');
      expect(c, isA<QrUrl>());
      final QrUrl url = c as QrUrl;
      expect(url.host, 'example.com');
      expect(url.suspicious, isFalse);
    });

    test('URL avec www', () {
      final QrContent c = ContentAnalyzer.analyze('https://www.example.org/a');
      expect((c as QrUrl).host, 'www.example.org');
      expect(c.suspicious, isFalse);
    });

    test('URL suspecte : IP brute', () {
      final QrContent c = ContentAnalyzer.analyze('http://192.168.1.10/login');
      expect((c as QrUrl).suspicious, isTrue);
    });

    test('URL suspecte : raccourcisseur', () {
      final QrContent c = ContentAnalyzer.analyze('https://bit.ly/3xYzAb');
      expect((c as QrUrl).suspicious, isTrue);
    });

    test('URL suspecte : TLD douteux', () {
      final QrContent c = ContentAnalyzer.analyze('https://offre-promo.tk/win');
      expect((c as QrUrl).suspicious, isTrue);
    });

    test('Téléphone via tel:', () {
      final QrContent c = ContentAnalyzer.analyze('tel:+33123456789');
      expect(c, isA<QrPhone>());
      expect((c as QrPhone).number, '+33123456789');
    });

    test('Numéro de téléphone brut', () {
      final QrContent c = ContentAnalyzer.analyze('06 12 34 56 78');
      expect(c, isA<QrPhone>());
    });

    test('E-mail via mailto:', () {
      final QrContent c = ContentAnalyzer.analyze('mailto:jean@example.com');
      expect(c, isA<QrEmail>());
      expect((c as QrEmail).address, 'jean@example.com');
    });

    test('Adresse e-mail brute', () {
      final QrContent c = ContentAnalyzer.analyze('contact@exemple.fr');
      expect(c, isA<QrEmail>());
      expect((c as QrEmail).address, 'contact@exemple.fr');
    });

    test('SMS', () {
      final QrContent c = ContentAnalyzer.analyze('sms:+33123456789?body=Bonjour');
      expect(c, isA<QrSms>());
      final QrSms sms = c as QrSms;
      expect(sms.number, '+33123456789');
      expect(sms.message, 'Bonjour');
    });

    test('Wi-Fi', () {
      final QrContent c = ContentAnalyzer.analyze('WIFI:T:WPA;S:LaFibre;P:secret123;;');
      expect(c, isA<QrWifi>());
      final QrWifi wifi = c as QrWifi;
      expect(wifi.ssid, 'LaFibre');
      expect(wifi.password, 'secret123');
      expect(wifi.security, 'WPA');
    });

    test('Coordonnées GPS', () {
      final QrContent c = ContentAnalyzer.analyze('geo:48.8566,2.3522');
      expect(c, isA<QrGeo>());
      final QrGeo geo = c as QrGeo;
      expect(geo.latitude, closeTo(48.8566, 0.0001));
      expect(geo.longitude, closeTo(2.3522, 0.0001));
    });

    test('Contact vCard', () {
      final QrContent c = ContentAnalyzer.analyze(
        'BEGIN:VCARD\nVERSION:3.0\nFN:Jean Dupont\nTEL:+33123456789\n'
        'EMAIL:jean@example.com\nEND:VCARD',
      );
      expect(c, isA<QrVcard>());
      final QrVcard vcard = c as QrVcard;
      expect(vcard.name, 'Jean Dupont');
      expect(vcard.phones, contains('+33123456789'));
      expect(vcard.emails, contains('jean@example.com'));
    });

    test('Événement calendrier', () {
      final QrContent c = ContentAnalyzer.analyze(
        'BEGIN:VEVENT\nSUMMARY:Réunion projet\nDTSTART:20240101T100000Z\n'
        'DTEND:20240101T110000Z\nLOCATION:Salle 2\nEND:VEVENT',
      );
      expect(c, isA<QrCalendar>());
      final QrCalendar cal = c as QrCalendar;
      expect(cal.title, 'Réunion projet');
      expect(cal.location, 'Salle 2');
      expect(cal.start?.year, 2024);
      expect(cal.start?.hour, 10);
      expect(cal.end?.hour, 11);
    });

    test('Texte libre', () {
      final QrContent c = ContentAnalyzer.analyze('Bonjour le monde');
      expect(c, isA<QrText>());
    });

    test('Contenu vide → inconnu', () {
      expect(ContentAnalyzer.analyze(''), isA<QrUnknown>());
    });
  });
}
