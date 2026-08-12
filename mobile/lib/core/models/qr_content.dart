/// Types de contenu reconnus par le moteur d'analyse de QRFlow.
///
/// Tous les types dérivent de [QrContent] et conservent le contenu brut
/// décodé ([QrContent.raw]), source de vérité pour copier/partager.
sealed class QrContent {
  const QrContent(this.raw);

  /// Contenu brut exactement tel que décodé dans le QR code.
  final String raw;
}

class QrUrl extends QrContent {
  const QrUrl(
    super.raw, {
    required this.url,
    required this.uri,
    required this.host,
    required this.suspicious,
  });

  final String url;
  final Uri? uri;

  /// Domaine (toujours affiché en clair, jamais raccourci).
  final String host;

  /// Vrai si le lien paraît suspect (IP brute, raccourcisseur, TLD douteux…).
  final bool suspicious;
}

class QrText extends QrContent {
  const QrText(super.raw);
}

class QrPhone extends QrContent {
  const QrPhone(super.raw, {required this.number});

  final String number;
}

class QrEmail extends QrContent {
  const QrEmail(super.raw, {required this.address, this.subject, this.body});

  final String address;
  final String? subject;
  final String? body;
}

class QrSms extends QrContent {
  const QrSms(super.raw, {required this.number, this.message});

  final String number;
  final String? message;
}

class QrWifi extends QrContent {
  const QrWifi(super.raw, {required this.ssid, this.password, this.security = ''});

  final String ssid;
  final String? password;
  final String security;
}

class QrGeo extends QrContent {
  const QrGeo(super.raw, {required this.latitude, required this.longitude, this.label});

  final double latitude;
  final double longitude;
  final String? label;
}

class QrVcard extends QrContent {
  const QrVcard(super.raw, {this.name, this.phones = const [], this.emails = const []});

  final String? name;
  final List<String> phones;
  final List<String> emails;
}

class QrCalendar extends QrContent {
  const QrCalendar(super.raw, {this.title, this.start, this.end, this.location});

  final String? title;
  final DateTime? start;
  final DateTime? end;
  final String? location;
}

/// Repli générique : contenu reconnu comme QR mais d'aucun type connu.
class QrUnknown extends QrContent {
  const QrUnknown(super.raw);
}
