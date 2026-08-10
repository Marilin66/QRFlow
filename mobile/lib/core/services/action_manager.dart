import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/qr_content.dart';

/// Une action proposée pour un type de contenu.
class QrAction {
  QrAction({
    required this.label,
    required this.icon,
    this.primary = false,
    this.confirmTitle,
    this.confirmMessage,
    required this.run,
  });

  final String label;
  final IconData icon;
  final bool primary;

  /// Si non nul, une confirmation est demandée avant d'exécuter l'action.
  final String? confirmTitle;
  final String? confirmMessage;

  final Future<bool> Function(BuildContext context) run;

  /// Copie un texte dans le presse-papiers.
  static Future<bool> copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copié dans le presse-papiers')),
      );
    }
    return true;
  }

  static Future<bool> share(BuildContext context, String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openUri(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\u2019ouvrir cette destination')),
          );
        }
        return false;
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\u2019ouvrir cette destination')),
        );
      }
      return false;
    }
  }
}

/// Construit les actions adaptées à chaque type de contenu.
class ActionManager {
  const ActionManager();

  List<QrAction> actionsFor(QrContent content) => switch (content) {
        QrUrl c => _urlActions(c),
        QrText c => _textActions(c),
        QrPhone c => _phoneActions(c),
        QrEmail c => _emailActions(c),
        QrSms c => _smsActions(c),
        QrVCard c => _vcardActions(c),
        QrWifi c => _wifiActions(c),
        QrGeo c => _geoActions(c),
        QrCalendar c => _calendarActions(c),
        QrApp c => _appActions(c),
        QrUnknown c => _unknownActions(c),
      };

  List<QrAction> _urlActions(QrUrl content) {
    final uri = Uri.tryParse(content.url);
    final warnings = content.suspicionReasons;
    return [
      QrAction(
        label: 'Ouvrir le lien',
        icon: Icons.open_in_new,
        primary: true,
        confirmTitle: 'Ouvrir ce lien ?',
        confirmMessage:
            '${content.url}\n\n${warnings.isNotEmpty ? warnings.join('\n• ') : ''}',
        run: (context) async {
          if (uri == null) return false;
          return QrAction.openUri(context, uri);
        },
      ),
      QrAction(
        label: 'Copier',
        icon: Icons.copy,
        run: (context) => QrAction.copy(context, content.url),
      ),
      QrAction(
        label: 'Partager',
        icon: Icons.share,
        run: (context) => QrAction.share(context, content.url),
      ),
    ];
  }

  List<QrAction> _textActions(QrText content) => [
        QrAction(
          label: 'Copier',
          icon: Icons.copy,
          primary: true,
          run: (context) => QrAction.copy(context, content.text),
        ),
        QrAction(
          label: 'Partager',
          icon: Icons.share,
          run: (context) => QrAction.share(context, content.text),
        ),
      ];

  List<QrAction> _phoneActions(QrPhone content) => [
        QrAction(
          label: 'Appeler',
          icon: Icons.call,
          primary: true,
          confirmTitle: 'Appeler ce numéro ?',
          confirmMessage: content.number,
          run: (context) => QrAction.openUri(context, Uri(scheme: 'tel', path: content.number)),
        ),
        QrAction(
          label: 'Envoyer un SMS',
          icon: Icons.sms,
          confirmTitle: 'Ouvrir l\u2019application SMS ?',
          confirmMessage: content.number,
          run: (context) => QrAction.openUri(context, Uri(scheme: 'sms', path: content.number)),
        ),
        QrAction(
          label: 'Copier',
          icon: Icons.copy,
          run: (context) => QrAction.copy(context, content.number),
        ),
      ];

  List<QrAction> _emailActions(QrEmail content) {
    final uri = Uri(
      scheme: 'mailto',
      path: content.address,
      queryParameters: {
        if (content.subject != null) 'subject': content.subject!,
        if (content.body != null) 'body': content.body!,
      },
    );
    return [
      QrAction(
        label: 'Envoyer un e-mail',
        icon: Icons.mail,
        primary: true,
        confirmTitle: 'Ouvrir l\u2019application e-mail ?',
        confirmMessage: content.address,
        run: (context) => QrAction.openUri(context, uri),
      ),
      QrAction(
        label: 'Copier',
        icon: Icons.copy,
        run: (context) => QrAction.copy(context, content.address),
      ),
    ];
  }

  List<QrAction> _smsActions(QrSms content) {
    final uri = Uri(
      scheme: 'sms',
      path: content.number,
      queryParameters: {if (content.message != null) 'body': content.message!},
    );
    return [
      QrAction(
        label: 'Ouvrir l\u2019application SMS',
        icon: Icons.sms,
        primary: true,
        confirmTitle: 'Ouvrir l\u2019application SMS ?',
        confirmMessage: content.message != null
            ? 'À ${content.number}\n\n${content.message}'
            : content.number,
        run: (context) => QrAction.openUri(context, uri),
      ),
      QrAction(
        label: 'Copier',
        icon: Icons.copy,
        run: (context) => QrAction.copy(context, content.raw),
      ),
    ];
  }

  List<QrAction> _vcardActions(QrVCard content) {
    final vcf = [
      'BEGIN:VCARD',
      'VERSION:3.0',
      if (content.name != null) 'FN:${content.name}',
      if (content.phone != null) 'TEL:${content.phone}',
      if (content.email != null) 'EMAIL:${content.email}',
      if (content.org != null) 'ORG:${content.org}',
      if (content.address != null) 'ADR:;;${content.address};;;',
      if (content.url != null) 'URL:${content.url}',
      if (content.note != null) 'NOTE:${content.note}',
      'END:VCARD',
    ].join('\n');

    return [
      QrAction(
        label: 'Partager le contact',
        icon: Icons.person_add,
        primary: true,
        run: (context) => QrAction.share(context, vcf),
      ),
      QrAction(
        label: 'Copier les coordonnées',
        icon: Icons.copy,
        run: (context) => QrAction.copy(context, vcf),
      ),
    ];
  }

  List<QrAction> _wifiActions(QrWifi content) {
    final password = content.password ?? '';
    return [
      QrAction(
        label: password.isNotEmpty ? 'Copier le mot de passe' : 'Réseau sans mot de passe',
        icon: Icons.password,
        primary: true,
        run: (context) async {
          if (password.isEmpty) return true;
          return QrAction.copy(context, password);
        },
      ),
      QrAction(
        label: 'Partager le réseau',
        icon: Icons.share,
        run: (context) => QrAction.share(
              context,
              'Wi-Fi : ${content.ssid}\nSécurité : ${content.security}'
              '${password.isNotEmpty ? '\nMot de passe : $password' : ''}',
            ),
      ),
    ];
  }

  List<QrAction> _geoActions(QrGeo content) {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${content.latitude},${content.longitude}',
    );
    return [
      QrAction(
        label: 'Ouvrir dans Maps',
        icon: Icons.map,
        primary: true,
        confirmTitle: 'Ouvrir dans Maps ?',
        confirmMessage: '${content.latitude}, ${content.longitude}',
        run: (context) => QrAction.openUri(context, uri),
      ),
      QrAction(
        label: 'Copier les coordonnées',
        icon: Icons.copy,
        run: (context) => QrAction.copy(
              context,
              '${content.latitude}, ${content.longitude}',
            ),
      ),
    ];
  }

  List<QrAction> _calendarActions(QrCalendar content) {
    return [
      QrAction(
        label: 'Ajouter au calendrier',
        icon: Icons.event,
        primary: true,
        confirmTitle: 'Ajouter cet événement au calendrier ?',
        confirmMessage: content.title ?? 'Événement',
        run: (context) async {
          final start = content.start ?? DateTime.now();
          final end = content.end ?? start.add(const Duration(hours: 1));
          await Add2Calendar.addEvent2Cal(
            Event(
              title: content.title ?? 'Événement',
              description: content.description ?? '',
              location: content.location ?? '',
              startDate: start,
              endDate: end,
            ),
          );
          return true;
        },
      ),
      QrAction(
        label: 'Copier les détails',
        icon: Icons.copy,
        run: (context) => QrAction.copy(context, content.raw),
      ),
    ];
  }

  List<QrAction> _appActions(QrApp content) {
    final uri = Uri.tryParse(content.uri);
    return [
      QrAction(
        label: 'Ouvrir',
        icon: Icons.launch,
        primary: true,
        confirmTitle: 'Ouvrir cette application ?',
        confirmMessage: content.uri,
        run: (context) async {
          if (uri == null) return false;
          return QrAction.openUri(context, uri);
        },
      ),
      QrAction(
        label: 'Copier',
        icon: Icons.copy,
        run: (context) => QrAction.copy(context, content.uri),
      ),
    ];
  }

  List<QrAction> _unknownActions(QrUnknown content) => [
        QrAction(
          label: 'Copier',
          icon: Icons.copy,
          primary: true,
          run: (context) => QrAction.copy(context, content.raw),
        ),
        QrAction(
          label: 'Partager',
          icon: Icons.share,
          run: (context) => QrAction.share(context, content.raw),
        ),
      ];
}
