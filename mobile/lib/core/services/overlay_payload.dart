import '../models/content_presentation.dart';
import '../models/qr_content.dart';

/// Construit le payload de rendu pour l'overlay natif (fenêtre au-dessus de
/// l'app en cours). C'est la source unique de vérité : l'analyse est faite
/// côté Dart, le natif ne fait qu'afficher et exécuter les actions.
Map<String, dynamic> buildOverlayPayload(QrContent content) {
  final Map<String, dynamic> payload = {
    'typeLabel': typeLabel(content),
    'raw': content.raw,
    'display': _display(content),
    'primaryLabel': _primaryLabel(content),
    'primaryCode': _primaryCode(content),
    'details': _details(content),
  };

  if (content is QrUrl) {
    payload['domain'] = content.host;
    payload['suspicious'] = content.suspicious;
  }
  if (content is QrPhone) {
    payload['number'] = content.number;
  }
  if (content is QrSms) {
    payload['number'] = content.number;
    if (content.message != null) payload['message'] = content.message;
  }
  if (content is QrEmail) {
    payload['address'] = content.address;
    if (content.subject != null) payload['subject'] = content.subject;
    if (content.body != null) payload['body'] = content.body;
  }
  if (content is QrWifi) {
    payload['ssid'] = content.ssid;
    if (content.password != null) payload['password'] = content.password;
  }
  if (content is QrGeo) {
    payload['latitude'] = content.latitude;
    payload['longitude'] = content.longitude;
  }
  return payload;
}

String _display(QrContent content) => switch (content) {
      QrUrl() => content.url,
      QrPhone() => content.number,
      QrEmail() => content.address,
      QrSms() => content.number,
      QrWifi() => 'Réseau : ${content.ssid}',
      QrGeo() => '${content.latitude}, ${content.longitude}',
      QrVcard() =>
        (content.name != null && content.name!.isNotEmpty) ? content.name! : content.raw,
      QrCalendar() =>
        (content.title != null && content.title!.isNotEmpty) ? content.title! : content.raw,
      _ => content.raw,
    };

String _primaryLabel(QrContent content) => switch (content) {
      QrUrl() => 'Ouvrir le lien',
      QrPhone() => 'Appeler',
      QrEmail() => 'Écrire un e-mail',
      QrSms() => 'Envoyer un SMS',
      QrWifi() => 'Copier le mot de passe',
      QrGeo() => 'Ouvrir dans Maps',
      _ => 'Copier',
    };

String _primaryCode(QrContent content) => switch (content) {
      QrUrl() => 'openUrl',
      QrPhone() => 'dial',
      QrEmail() => 'email',
      QrSms() => 'sms',
      QrWifi() => 'copyPassword',
      QrGeo() => 'maps',
      _ => 'copy',
    };

List<String> _details(QrContent content) {
  switch (content) {
    case QrWifi(:final ssid, :final security, :final password):
      return [
        'Réseau : $ssid',
        'Sécurité : ${security.isEmpty ? '—' : security}',
        'Mot de passe : ${password ?? '—'}',
      ];
    case QrVcard(:final name, :final phones, :final emails):
      return [
        if (name != null && name.isNotEmpty) 'Nom : $name',
        for (final String p in phones) 'Téléphone : $p',
        for (final String e in emails) 'E-mail : $e',
      ];
    case QrCalendar(:final title, :final start, :final end, :final location):
      return [
        if (title != null && title.isNotEmpty) 'Événement : $title',
        if (start != null) 'Début : $start',
        if (end != null) 'Fin : $end',
        if (location != null && location.isNotEmpty) 'Lieu : $location',
      ];
    case QrSms(:final number, :final message):
      return [
        'Numéro : $number',
        if (message != null && message.isNotEmpty) 'Message : $message',
      ];
    case QrEmail(:final address):
      return ['Adresse : $address'];
    case QrPhone(:final number):
      return ['Numéro : $number'];
    default:
      return const [];
  }
}
