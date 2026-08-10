import '../models/qr_content.dart';

/// Analyse le contenu brut d'un QR code et identifie son type.
///
/// Ordre de détection : formats structurés (Wi-Fi, GEO, vCard, calendrier,
/// SMS, e-mail, téléphone), puis URL, puis texte libre.
class ContentAnalyzer {
  const ContentAnalyzer();

  static const List<String> _suspiciousTlds = [
    'tk', 'ml', 'ga', 'cf', 'gq',
  ];

  static final RegExp _emailPattern =
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9][0-9 \.\-\(\)]{6,19}$');
  static final RegExp _genericScheme = RegExp(r'^([a-z][a-z0-9+.\-]*)://');

  /// Analyse une chaîne brute et retourne le contenu typé.
  QrContent analyze(String raw) {
    final content = raw.trim();
    if (content.isEmpty) {
      return QrUnknown(raw: raw);
    }

    final wifi = _tryWifi(content);
    if (wifi != null) return wifi;

    final geo = _tryGeo(content);
    if (geo != null) return geo;

    final vcard = _tryVCard(content);
    if (vcard != null) return vcard;

    final calendar = _tryCalendar(content);
    if (calendar != null) return calendar;

    final sms = _trySms(content);
    if (sms != null) return sms;

    final email = _tryEmail(content);
    if (email != null) return email;

    final phone = _tryPhone(content);
    if (phone != null) return phone;

    final app = _tryApp(content);
    if (app != null) return app;

    final url = _tryUrl(content);
    if (url != null) return url;

    return QrText(text: content, raw: raw);
  }

  // ── Formats structurés ──────────────────────────────────────────────

  QrWifi? _tryWifi(String content) {
    final upper = content.toUpperCase();
    if (!upper.startsWith('WIFI:')) return null;
    String? ssid, security, password;
    var hidden = false;
    for (final part in content.substring(5).split(';')) {
      if (part.isEmpty) continue;
      final colon = part.indexOf(':');
      if (colon <= 0) continue;
      final key = part.substring(0, colon).toUpperCase();
      final value = part.substring(colon + 1);
      switch (key) {
        case 'S':
          ssid = value;
        case 'T':
          security = value.isEmpty ? 'nopass' : value;
        case 'P':
          password = value;
        case 'H':
          hidden = value.toUpperCase() == 'TRUE';
      }
    }
    if (ssid == null || ssid.isEmpty) return null;
    return QrWifi(
      raw: content,
      ssid: ssid,
      security: (security ?? 'nopass').toUpperCase(),
      password: password,
      hidden: hidden,
    );
  }

  QrGeo? _tryGeo(String content) {
    final match = RegExp(r'^(?:GEO|geo):\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)')
        .firstMatch(content);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return QrGeo(raw: content, latitude: lat, longitude: lng);
  }

  QrVCard? _tryVCard(String content) {
    final upper = content.toUpperCase();
    final isVcard = upper.contains('BEGIN:VCARD');
    final isMecard = upper.startsWith('MECARD:');

    String? name, phone, email, org, address, url, note;

    if (isVcard) {
      final fields = <String, String>{};
      for (final line in content.split(RegExp(r'[\r\n]+'))) {
        final colon = line.indexOf(':');
        if (colon <= 0) continue;
        // Ignorer les propriétés préfixées (ex. TEL;TYPE=CELL)
        final key = line.substring(0, colon).split(';').first.toUpperCase();
        fields[key] = line.substring(colon + 1).trim();
      }
      name = fields['FN'] ?? fields['N'];
      phone = fields['TEL'];
      email = fields['EMAIL'];
      org = fields['ORG'];
      address = fields['ADR'];
      url = fields['URL'];
      note = fields['NOTE'];
    } else if (isMecard) {
      for (final part in content.substring(7).split(';')) {
        final colon = part.indexOf(':');
        if (colon <= 0) continue;
        final key = part.substring(0, colon).toUpperCase();
        final value = part.substring(colon + 1);
        switch (key) {
          case 'N':
            name = value;
          case 'TEL':
            phone = value;
          case 'EMAIL':
            email = value;
          case 'ORG':
            org = value;
          case 'ADR':
            address = value;
          case 'URL':
            url = value;
          case 'NOTE':
            note = value;
        }
      }
    } else {
      return null;
    }

    if (name == null && phone == null && email == null && org == null &&
        address == null && url == null && note == null) {
      return null;
    }
    return QrVCard(
      raw: content,
      name: name,
      phone: phone,
      email: email,
      org: org,
      address: address,
      url: url,
      note: note,
    );
  }

  QrCalendar? _tryCalendar(String content) {
    if (!content.toUpperCase().contains('BEGIN:VEVENT')) return null;

    String? read(String key) {
      final match = RegExp('$key:([^\\r\\n]*)', caseSensitive: false)
          .firstMatch(content);
      return match?.group(1)?.trim();
    }

    DateTime? parseDate(String? value) {
      if (value == null || value.isEmpty) return null;
      final v = value.replaceAll('T', '').replaceAll('Z', '');
      // Format YYYYMMDDHHMMSS ou YYYYMMDD
      if (v.length == 14) {
        return DateTime.tryParse(
          '${v.substring(0, 4)}-${v.substring(4, 6)}-${v.substring(6, 8)} '
          '${v.substring(8, 10)}:${v.substring(10, 12)}:${v.substring(12, 14)}',
        );
      }
      if (v.length == 8) {
        return DateTime.tryParse(
          '${v.substring(0, 4)}-${v.substring(4, 6)}-${v.substring(6, 8)}',
        );
      }
      return null;
    }

    final title = read('SUMMARY');
    final start = parseDate(read('DTSTART'));
    final end = parseDate(read('DTEND'));
    final location = read('LOCATION');
    final description = read('DESCRIPTION');

    if (title == null && start == null && location == null) return null;

    return QrCalendar(
      raw: content,
      title: title,
      start: start,
      end: end,
      location: location,
      description: description,
    );
  }

  QrSms? _trySms(String content) {
    final upper = content.toUpperCase();
    if (upper.startsWith('SMSTO:')) {
      final rest = content.substring(6);
      final colon = rest.indexOf(':');
      final number = colon >= 0 ? rest.substring(0, colon) : rest;
      final message = colon >= 0 ? rest.substring(colon + 1) : null;
      if (number.isNotEmpty) {
        return QrSms(raw: content, number: number, message: message);
      }
    }
    if (upper.startsWith('SMS:') || upper.startsWith('SMSP:')) {
      final uri = Uri.tryParse(content);
      if (uri != null) {
        final number = uri.path.isEmpty ? uri.host : uri.path;
        if (number.isNotEmpty) {
          return QrSms(
            raw: content,
            number: number,
            message: uri.queryParameters['body'],
          );
        }
      }
    }
    return null;
  }

  QrEmail? _tryEmail(String content) {
    final upper = content.toUpperCase();
    if (upper.startsWith('MAILTO:')) {
      final uri = Uri.tryParse(content);
      if (uri != null && uri.path.isNotEmpty) {
        return QrEmail(
          raw: content,
          address: uri.path,
          subject: uri.queryParameters['subject'],
          body: uri.queryParameters['body'],
        );
      }
      return null;
    }
    if (upper.startsWith('MATMSG:')) {
      String? read(String key) {
        final match =
            RegExp('$key:([^;]*)', caseSensitive: false).firstMatch(content);
        return match?.group(1)?.trim();
      }

      final address = read('TO');
      if (address != null && address.isNotEmpty) {
        return QrEmail(
          raw: content,
          address: address,
          subject: read('SUB'),
          body: read('BODY'),
        );
      }
      return null;
    }
    // Adresse e-mail brute.
    if (_emailPattern.hasMatch(content)) {
      return QrEmail(raw: content, address: content);
    }
    return null;
  }

  QrPhone? _tryPhone(String content) {
    final upper = content.toUpperCase();
    if (upper.startsWith('TEL:')) {
      final number = content.substring(4).trim();
      if (number.isNotEmpty) return QrPhone(raw: content, number: number);
      return null;
    }
    if (_phonePattern.hasMatch(content)) {
      return QrPhone(raw: content, number: content);
    }
    return null;
  }

  QrApp? _tryApp(String content) {
    final lower = content.toLowerCase();
    if (lower.startsWith('market://')) {
      final uri = Uri.tryParse(content);
      final id = uri?.queryParameters['id'];
      return QrApp(raw: content, uri: content, packageName: id);
    }
    if (lower.startsWith('intent://')) {
      return QrApp(raw: content, uri: content);
    }
    return null;
  }

  QrUrl? _tryUrl(String content) {
    final schemeMatch = _genericScheme.firstMatch(content);
    var url = content;
    String? scheme;
    if (schemeMatch != null) {
      scheme = schemeMatch.group(1)!.toLowerCase();
    } else if (content.startsWith('www.')) {
      url = 'https://$content';
      scheme = 'https';
    } else {
      return null;
    }

    // Les schémas de type « application » sont gérés ailleurs.
    const urlSchemes = {
      'http', 'https', 'ftp',
    };
    if (!urlSchemes.contains(scheme)) return null;

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return QrUrl(
        raw: content,
        url: url,
        domain: content,
        isSecure: scheme == 'https',
        suspicious: false,
        suspicionReasons: const [],
      );
    }

    final domain = uri.host.toLowerCase();
    final reasons = <String>[];

    final isIp = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(domain);
    if (isIp) reasons.add('Le domaine est une adresse IP (peu fiable).');

    final tld = domain.split('.').last;
    if (_suspiciousTlds.contains(tld)) {
      reasons.add('Extension de domaine souvent utilisée pour des arnaques (.$tld).');
    }

    if (domain.contains('@')) {
      reasons.add('Le domaine contient un « @ », ce qui peut masquer la vraie destination.');
    }

    if (RegExp(r'^[^a-z0-9\-\.]', caseSensitive: false).hasMatch(domain)) {
      reasons.add('Le domaine contient des caractères inhabituels.');
    }

    return QrUrl(
      raw: content,
      url: url,
      domain: domain,
      isSecure: scheme == 'https',
      suspicious: reasons.isNotEmpty,
      suspicionReasons: reasons,
    );
  }
}
