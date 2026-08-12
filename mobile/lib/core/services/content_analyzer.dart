import '../models/qr_content.dart';

/// Moteur d'analyse : transforme le texte brut d'un QR code en contenu typé.
///
/// Aucune action n'est déclenchée ici : uniquement la compréhension
/// (Détection → Présentation → Confirmation → Action).
class ContentAnalyzer {
  static const List<String> _shorteners = [
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'buff.ly', 'ow.ly',
    'rebrand.ly', 'cutt.ly', 'shorturl.at', 'rb.gy', 's.id', 'lnkd.in',
    'tiny.cc', 'bit.do', 'soo.gd', 'bc.vc', 'v.gd',
  ];

  static const List<String> _suspiciousTlds = [
    'tk', 'ml', 'ga', 'cf', 'gq', 'xyz', 'top', 'club', 'work', 'click',
    'link', 'zip', 'country', 'rest', 'cyou', 'mom', 'lol', 'men', 'bar',
    'online', 'site', 'icu', 'cam', 'fun', 'vip', 'bid', 'loan',
  ];

  static QrContent analyze(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return QrUnknown(raw);

    // ── URL ────────────────────────────────────────────────────────────
    final String lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final Uri? uri = Uri.tryParse(text);
      if (uri != null && uri.host.isNotEmpty) {
        final String host = uri.host.toLowerCase();
        return QrUrl(
          text,
          url: text,
          uri: uri,
          host: host,
          suspicious: _isSuspiciousUrl(uri, host),
        );
      }
    }

    // ── Téléphone ──────────────────────────────────────────────────────
    if (lower.startsWith('tel:')) {
      return QrPhone(text, number: text.substring(4).trim());
    }

    // ── E-mail ─────────────────────────────────────────────────────────
    if (lower.startsWith('mailto:')) {
      final String rest = text.substring(7);
      final int q = rest.indexOf('?');
      return QrEmail(text, address: (q >= 0 ? rest.substring(0, q) : rest).trim());
    }

    // ── SMS ────────────────────────────────────────────────────────────
    if (lower.startsWith('sms:')) {
      final List<String> parts = text.substring(4).split('?');
      String? message;
      for (final String p in parts.skip(1)) {
        if (p.toLowerCase().startsWith('body=')) {
          message = p.substring(5);
        }
      }
      return QrSms(text, number: parts.first.trim(), message: message);
    }

    // ── Wi-Fi ──────────────────────────────────────────────────────────
    if (lower.startsWith('wifi:')) {
      String ssid = '', password = '', security = '';
      for (final String part in text.substring(5).split(';')) {
        final int idx = part.indexOf(':');
        if (idx < 0) continue;
        final String key = part.substring(0, idx).trim().toUpperCase();
        final String value = part.substring(idx + 1).trim();
        switch (key) {
          case 'S':
            ssid = value;
          case 'P':
            password = value;
          case 'T':
            security = value;
        }
      }
      return QrWifi(
        text,
        ssid: ssid,
        password: password.isEmpty ? null : password,
        security: security,
      );
    }

    // ── Coordonnées GPS ────────────────────────────────────────────────
    if (lower.startsWith('geo:')) {
      final String rest = text.substring(4).split('?').first;
      final List<String> parts = rest.split(',');
      if (parts.length >= 2) {
        final double? lat = double.tryParse(parts[0]);
        final double? lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          String? label;
          final int q = text.indexOf('?q=');
          if (q >= 0) label = text.substring(q + 3);
          return QrGeo(text, latitude: lat, longitude: lng, label: label);
        }
      }
    }

    // ── Contact / vCard ────────────────────────────────────────────────
    if (text.toUpperCase().contains('BEGIN:VCARD')) {
      String? name;
      final List<String> phones = [];
      final List<String> emails = [];
      for (final String line in text.split('\n')) {
        final String t = line.trim();
        final String tl = t.toLowerCase();
        if (tl.startsWith('fn:')) {
          name = t.substring(3).trim();
        } else if (tl.startsWith('tel')) {
          final int c = t.indexOf(':');
          if (c >= 0 && t.substring(c + 1).trim().isNotEmpty) {
            phones.add(t.substring(c + 1).trim());
          }
        } else if (tl.startsWith('email')) {
          final int c = t.indexOf(':');
          if (c >= 0 && t.substring(c + 1).trim().isNotEmpty) {
            emails.add(t.substring(c + 1).trim());
          }
        }
      }
      return QrVcard(text, name: name, phones: phones, emails: emails);
    }

    // ── Événement calendrier ───────────────────────────────────────────
    if (text.toUpperCase().contains('BEGIN:VEVENT')) {
      String? title, location;
      DateTime? start, end;
      for (final String line in text.split('\n')) {
        final String t = line.trim();
        final String tl = t.toLowerCase();
        if (tl.startsWith('summary:')) {
          title = t.substring(8).trim();
        } else if (tl.startsWith('location:')) {
          location = t.substring(9).trim();
        } else if (tl.startsWith('dtstart:')) {
          start = _parseCalDate(t.substring(8).trim());
        } else if (tl.startsWith('dtend:')) {
          end = _parseCalDate(t.substring(6).trim());
        }
      }
      return QrCalendar(text, title: title, start: start, end: end, location: location);
    }

    // ── E-mail brut (adresse seule) ────────────────────────────────────
    final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (emailPattern.hasMatch(text)) {
      return QrEmail(text, address: text);
    }

    // ── Numéro de téléphone brut ───────────────────────────────────────
    final RegExp phonePattern = RegExp(r'^\+?[0-9][0-9\s.\-()]{5,19}$');
    if (phonePattern.hasMatch(text) &&
        RegExp(r'\d').allMatches(text).length >= 6) {
      return QrPhone(text, number: text);
    }

    // ── Texte libre ────────────────────────────────────────────────────
    return QrText(text);
  }

  /// Détection d'un lien suspect : IP brute, '@' trompeur, raccourcisseur
  /// ou extension de domaine douteuse.
  static bool _isSuspiciousUrl(Uri uri, String host) {
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) return true;
    if (uri.toString().contains('@')) return true;

    final String root = host.replaceFirst(RegExp(r'^www\.'), '');
    if (_shorteners.contains(root) ||
        _shorteners.any((String s) => root.endsWith('.$s'))) {
      return true;
    }
    final String tld = root.contains('.') ? root.split('.').last : '';
    if (_suspiciousTlds.contains(tld)) return true;
    return false;
  }

  /// Parse une date calendrier au format compact (20240101T100000Z) ou ISO.
  static DateTime? _parseCalDate(String raw) {
    if (raw.contains('-')) {
      return DateTime.tryParse(raw);
    }
    final String value = raw.replaceAll(RegExp('[TZ]'), '');
    final RegExpMatch? m =
        RegExp(r'^(\d{4})(\d{2})(\d{2})(?:(\d{2})(\d{2})(\d{2}))?$')
            .firstMatch(value);
    if (m == null) return null;
    final int h = m.group(4) == null ? 0 : int.parse(m.group(4)!);
    final int mi = m.group(5) == null ? 0 : int.parse(m.group(5)!);
    final int s = m.group(6) == null ? 0 : int.parse(m.group(6)!);
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      h,
      mi,
      s,
    );
  }
}
