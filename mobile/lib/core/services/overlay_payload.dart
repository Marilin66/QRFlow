import '../models/qr_content.dart';

/// Construit la charge utile de rendu pour la fenêtre de résultat native
/// (Mode Flash — carte affichée au-dessus de l'application en cours).
///
/// Le côté Kotlin reste un simple « interprète » : le sens du contenu
/// (libellés, URIs, confirmations, texte à copier) est entièrement décidé ici,
/// dans le seul endroit où vit la logique d'analyse.
Map<String, dynamic> buildOverlayPayload(QrContent content) => switch (content) {
      QrUrl c => {
          'type': 'url',
          'typeLabel': c.typeLabel,
          'summary': c.domain,
          'raw': content.raw,
          'subtitle': c.isSecure ? 'Sécurisée (HTTPS)' : 'Non sécurisée (HTTP)',
          'suspicious': c.suspicious,
          'reasons': c.suspicionReasons,
          'primaryAction': {
            'label': 'Ouvrir le lien',
            'uri': c.url,
            'confirmMessage': c.suspicious
                ? '${c.url}\n\n${c.suspicionReasons.join('\n• ')}'
                : c.url,
          },
          'copyAction': {'label': 'Copier', 'copyText': c.url},
        },
      QrText c => {
          'type': 'text',
          'typeLabel': c.typeLabel,
          'summary': c.summary,
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {'label': 'Copier le texte', 'copyText': c.text},
        },
      QrPhone c => {
          'type': 'phone',
          'typeLabel': c.typeLabel,
          'summary': c.number,
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {
            'label': 'Appeler',
            'uri': 'tel:${c.number}',
            'confirmMessage': c.number,
          },
          'copyAction': {'label': 'Copier', 'copyText': c.number},
        },
      QrEmail c => {
          'type': 'email',
          'typeLabel': c.typeLabel,
          'summary': c.address,
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {
            'label': 'Envoyer un e-mail',
            'uri': _mailtoUri(c),
            'confirmMessage': c.address,
          },
          'copyAction': {'label': 'Copier', 'copyText': c.address},
        },
      QrSms c => {
          'type': 'sms',
          'typeLabel': c.typeLabel,
          'summary': c.number,
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {
            'label': 'Ouvrir l\'application SMS',
            'uri': _smsUri(c),
            'confirmMessage':
                c.message != null ? 'À ${c.number}\n\n${c.message}' : c.number,
          },
          'copyAction': {'label': 'Copier', 'copyText': content.raw},
        },
      QrVCard c => {
          'type': 'vcard',
          'typeLabel': c.typeLabel,
          'summary': c.summary,
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {'label': 'Copier la fiche', 'copyText': content.raw},
        },
      QrWifi c => {
          'type': 'wifi',
          'typeLabel': c.typeLabel,
          'summary': c.ssid,
          'raw': content.raw,
          'subtitle': 'Sécurité : ${c.security}',
          'suspicious': false,
          'reasons': <String>[],
          'hasPassword': (c.password ?? '').isNotEmpty,
          if ((c.password ?? '').isNotEmpty)
            'primaryAction': {
              'label': 'Copier le mot de passe',
              'copyText': c.password,
            },
          'copyAction': {'label': 'Copier le réseau', 'copyText': content.raw},
        },
      QrGeo c => {
          'type': 'geo',
          'typeLabel': c.typeLabel,
          'summary': '${c.latitude.toStringAsFixed(5)}, '
              '${c.longitude.toStringAsFixed(5)}',
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {
            'label': 'Ouvrir dans Maps',
            'uri': 'https://www.google.com/maps/search/?api=1'
                '&query=${c.latitude},${c.longitude}',
            'confirmMessage': '${c.latitude}, ${c.longitude}',
          },
          'copyAction': {
            'label': 'Copier les coordonnées',
            'copyText': '${c.latitude}, ${c.longitude}',
          },
        },
      QrCalendar c => {
          'type': 'calendar',
          'typeLabel': c.typeLabel,
          'summary': c.title ?? 'Événement',
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {
            'label': 'Ajouter au calendrier',
            'calendar': {
              'title': c.title ?? 'Événement',
              'start': c.start?.toIso8601String(),
              'end': c.end?.toIso8601String(),
              'location': c.location,
              'description': c.description,
            },
          },
          'copyAction': {'label': 'Copier les détails', 'copyText': content.raw},
        },
      QrApp c => {
          'type': 'app',
          'typeLabel': c.typeLabel,
          'summary': c.packageName ?? c.uri,
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {'label': 'Ouvrir', 'uri': c.uri, 'confirmMessage': c.uri},
          'copyAction': {'label': 'Copier', 'copyText': c.uri},
        },
      QrUnknown c => {
          'type': 'unknown',
          'typeLabel': c.typeLabel,
          'summary': c.summary,
          'raw': content.raw,
          'suspicious': false,
          'reasons': <String>[],
          'primaryAction': {'label': 'Copier', 'copyText': c.raw},
        },
    };

String _mailtoUri(QrEmail c) {
  final query = <String, String>{
    if (c.subject != null) 'subject': c.subject!,
    if (c.body != null) 'body': c.body!,
  };
  final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
  return 'mailto:${c.address}$suffix';
}

String _smsUri(QrSms c) {
  final suffix =
      c.message != null ? '?body=${Uri.encodeQueryComponent(c.message!)}' : '';
  return 'sms:${c.number}$suffix';
}
