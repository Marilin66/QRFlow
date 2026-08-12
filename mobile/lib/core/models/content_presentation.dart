import 'package:flutter/material.dart';

import 'qr_content.dart';

/// Étiquette lisible d'un type de contenu (partagée entre écrans).
String typeLabel(QrContent content) => switch (content) {
      QrUrl() => 'Lien web',
      QrText() => 'Texte',
      QrPhone() => 'Numéro de téléphone',
      QrEmail() => 'Adresse e-mail',
      QrSms() => 'Message SMS',
      QrWifi() => 'Réseau Wi-Fi',
      QrGeo() => 'Coordonnées GPS',
      QrVcard() => 'Contact',
      QrCalendar() => 'Événement',
      QrUnknown() => 'Contenu inconnu',
    };

/// Icône d'un type de contenu (partagée entre écrans).
IconData typeIcon(QrContent content) => switch (content) {
      QrUrl() => Icons.link,
      QrText() => Icons.notes,
      QrPhone() => Icons.phone_outlined,
      QrEmail() => Icons.mail_outline,
      QrSms() => Icons.chat_bubble_outline,
      QrWifi() => Icons.wifi,
      QrGeo() => Icons.place_outlined,
      QrVcard() => Icons.person_outline,
      QrCalendar() => Icons.event_outlined,
      QrUnknown() => Icons.help_outline,
    };
