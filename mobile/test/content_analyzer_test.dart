import 'package:flutter_test/flutter_test.dart';
import 'package:qrflow_mobile/core/models/qr_content.dart';
import 'package:qrflow_mobile/core/services/content_analyzer.dart';

void main() {
  const analyzer = ContentAnalyzer();

  group('URL', () {
    test('https classique', () {
      final c = analyzer.analyze('https://example.com/path');
      expect(c, isA<QrUrl>());
      final url = c as QrUrl;
      expect(url.domain, 'example.com');
      expect(url.isSecure, isTrue);
      expect(url.suspicious, isFalse);
    });

    test('www sans schéma', () {
      final c = analyzer.analyze('www.example.com');
      expect(c, isA<QrUrl>());
      expect((c as QrUrl).url, 'https://www.example.com');
    });

    test('IP non sécurisée = suspecte', () {
      final c = analyzer.analyze('http://192.168.1.1/admin');
      final url = c as QrUrl;
      expect(url.suspicious, isTrue);
      expect(url.isSecure, isFalse);
    });

    test('extension douteuse = suspecte', () {
      final c = analyzer.analyze('https://gagnez-des-cadeaux.tk/offre');
      expect((c as QrUrl).suspicious, isTrue);
    });

    test('http non sécurisé mais pas forcément suspect', () {
      final c = analyzer.analyze('http://example.com');
      final url = c as QrUrl;
      expect(url.isSecure, isFalse);
      expect(url.suspicious, isFalse);
    });
  });

  group('Texte', () {
    test('texte simple', () {
      expect(analyzer.analyze('Bonjour le monde'), isA<QrText>());
    });

    test('chaîne vide -> inconnu', () {
      expect(analyzer.analyze('  '), isA<QrUnknown>());
    });
  });

  group('Téléphone', () {
    test('numéro libre', () {
      final c = analyzer.analyze('+33 6 12 34 56 78');
      expect(c, isA<QrPhone>());
      expect((c as QrPhone).number, '+33 6 12 34 56 78');
    });

    test('préfixe tel:', () {
      final c = analyzer.analyze('tel:+33612345678');
      expect((c as QrPhone).number, '+33612345678');
    });
  });

  group('E-mail', () {
    test('adresse simple', () {
      final c = analyzer.analyze('jean.dupont@example.com');
      expect(c, isA<QrEmail>());
      expect((c as QrEmail).address, 'jean.dupont@example.com');
    });

    test('mailto avec sujet', () {
      final c = analyzer.analyze('mailto:contact@example.com?subject=Hello');
      expect(c, isA<QrEmail>());
      final email = c as QrEmail;
      expect(email.address, 'contact@example.com');
      expect(email.subject, 'Hello');
    });

    test('MATMSG', () {
      final c = analyzer.analyze('MATMSG:TO:a@b.com;SUB:Test;BODY:Salut;;');
      expect(c, isA<QrEmail>());
      expect((c as QrEmail).address, 'a@b.com');
    });
  });

  group('SMS', () {
    test('SMSTO', () {
      final c = analyzer.analyze('SMSTO:+33612345678:Bonjour');
      expect(c, isA<QrSms>());
      final sms = c as QrSms;
      expect(sms.number, '+33612345678');
      expect(sms.message, 'Bonjour');
    });

    test('sms: avec corps', () {
      final c = analyzer.analyze('sms:+33612345678?body=Coucou');
      expect(c, isA<QrSms>());
      expect((c as QrSms).message, 'Coucou');
    });
  });

  group('Wi-Fi', () {
    test('WPA', () {
      final c = analyzer.analyze('WIFI:T:WPA;S:MaBox;P:secret123;;');
      expect(c, isA<QrWifi>());
      final wifi = c as QrWifi;
      expect(wifi.ssid, 'MaBox');
      expect(wifi.security, 'WPA');
      expect(wifi.password, 'secret123');
    });

    test('sans mot de passe', () {
      final c = analyzer.analyze('WIFI:S:OpenNet;T:nopass;;');
      expect(c, isA<QrWifi>());
      expect((c as QrWifi).password, isNull);
    });
  });

  group('Géolocalisation', () {
    test('geo:', () {
      final c = analyzer.analyze('geo:48.8584,2.2945');
      expect(c, isA<QrGeo>());
      final geo = c as QrGeo;
      expect(geo.latitude, closeTo(48.8584, 0.0001));
      expect(geo.longitude, closeTo(2.2945, 0.0001));
    });

    test('GEO:', () {
      expect(analyzer.analyze('GEO:45.5,-73.5'), isA<QrGeo>());
    });
  });

  group('Contact', () {
    test('vCard', () {
      const raw = 'BEGIN:VCARD\nVERSION:3.0\nFN:Jean Dupont\n'
          'TEL:+33612345678\nEMAIL:j@x.com\nEND:VCARD';
      final c = analyzer.analyze(raw);
      expect(c, isA<QrVCard>());
      final vc = c as QrVCard;
      expect(vc.name, 'Jean Dupont');
      expect(vc.phone, '+33612345678');
      expect(vc.email, 'j@x.com');
    });

    test('MECARD', () {
      final c = analyzer.analyze('MECARD:N:Marie Durand;TEL:+33698765432;;');
      expect(c, isA<QrVCard>());
      expect((c as QrVCard).name, 'Marie Durand');
    });
  });

  group('Calendrier', () {
    test('VEVENT', () {
      const raw = 'BEGIN:VEVENT\nSUMMARY:Réunion projet\n'
          'DTSTART:20260810T100000Z\nDTEND:20260810T110000Z\n'
          'LOCATION:Bureau 3\nEND:VEVENT';
      final c = analyzer.analyze(raw);
      expect(c, isA<QrCalendar>());
      final cal = c as QrCalendar;
      expect(cal.title, 'Réunion projet');
      expect(cal.location, 'Bureau 3');
      expect(cal.start, isNotNull);
      expect(cal.end, isNotNull);
    });
  });

  group('Application', () {
    test('market://', () {
      final c = analyzer.analyze('market://details?id=com.example.app');
      expect(c, isA<QrApp>());
      expect((c as QrApp).packageName, 'com.example.app');
    });
  });
}
