import 'package:flutter/material.dart';

/// Types de contenu reconnus dans un QR code.
enum QrContentType {
  url('URL', Icons.public),
  text('Texte', Icons.description_outlined),
  phone('Numéro de téléphone', Icons.phone_outlined),
  email('Adresse e-mail', Icons.mail_outline),
  sms('SMS', Icons.sms_outlined),
  vcard('Contact', Icons.person_outline),
  wifi('Réseau Wi-Fi', Icons.wifi),
  geo('Géolocalisation', Icons.place_outlined),
  calendar('Événement', Icons.event_outlined),
  app('Application', Icons.phone_android),
  unknown('Contenu inconnu', Icons.help_outline);

  const QrContentType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Contenu analysé d'un QR code.
///
/// Hiérarchie scellée : chaque type de contenu a sa propre classe.
sealed class QrContent {
  const QrContent({required this.raw});

  /// Contenu brut décodé.
  final String raw;

  QrContentType get type;
  String get typeLabel => type.label;

  /// Courte description affichée dans l'historique.
  String get summary;
}

class QrUrl extends QrContent {
  const QrUrl({
    required super.raw,
    required this.url,
    required this.domain,
    required this.isSecure,
    required this.suspicious,
    required this.suspicionReasons,
  });

  /// URL normalisée (préfixe https:// ajouté si nécessaire).
  final String url;
  final String domain;
  final bool isSecure;

  /// Indique si le lien présente des signaux suspects forts.
  final bool suspicious;
  final List<String> suspicionReasons;

  @override
  QrContentType get type => QrContentType.url;

  @override
  String get summary => domain;
}

class QrText extends QrContent {
  const QrText({required super.raw, required this.text});

  final String text;

  @override
  QrContentType get type => QrContentType.text;

  @override
  String get summary => _shorten(text);
}

class QrPhone extends QrContent {
  const QrPhone({required super.raw, required this.number});

  final String number;

  @override
  QrContentType get type => QrContentType.phone;

  @override
  String get summary => number;
}

class QrEmail extends QrContent {
  const QrEmail({
    required super.raw,
    required this.address,
    this.subject,
    this.body,
  });

  final String address;
  final String? subject;
  final String? body;

  @override
  QrContentType get type => QrContentType.email;

  @override
  String get summary => address;
}

class QrSms extends QrContent {
  const QrSms({required super.raw, required this.number, this.message});

  final String number;
  final String? message;

  @override
  QrContentType get type => QrContentType.sms;

  @override
  String get summary => number;
}

class QrVCard extends QrContent {
  const QrVCard({
    required super.raw,
    this.name,
    this.phone,
    this.email,
    this.org,
    this.address,
    this.url,
    this.note,
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? org;
  final String? address;
  final String? url;
  final String? note;

  @override
  QrContentType get type => QrContentType.vcard;

  @override
  String get summary => name ?? phone ?? email ?? 'Contact';
}

class QrWifi extends QrContent {
  const QrWifi({
    required super.raw,
    required this.ssid,
    required this.security,
    this.password,
    this.hidden = false,
  });

  final String ssid;
  final String security; // WPA, WEP, nopass, …
  final String? password;
  final bool hidden;

  @override
  QrContentType get type => QrContentType.wifi;

  @override
  String get summary => ssid;
}

class QrGeo extends QrContent {
  const QrGeo({required super.raw, required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  QrContentType get type => QrContentType.geo;

  @override
  String get summary =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

class QrCalendar extends QrContent {
  const QrCalendar({
    required super.raw,
    this.title,
    this.start,
    this.end,
    this.location,
    this.description,
  });

  final String? title;
  final DateTime? start;
  final DateTime? end;
  final String? location;
  final String? description;

  @override
  QrContentType get type => QrContentType.calendar;

  @override
  String get summary => title ?? 'Événement';
}

class QrApp extends QrContent {
  const QrApp({required super.raw, required this.uri, this.packageName});

  final String uri;
  final String? packageName;

  @override
  QrContentType get type => QrContentType.app;

  @override
  String get summary => packageName ?? uri;
}

class QrUnknown extends QrContent {
  const QrUnknown({required super.raw});

  @override
  QrContentType get type => QrContentType.unknown;

  @override
  String get summary => _shorten(raw);
}

String _shorten(String value, [int max = 60]) {
  final v = value.replaceAll('\n', ' ').trim();
  return v.length <= max ? v : '${v.substring(0, max)}…';
}
