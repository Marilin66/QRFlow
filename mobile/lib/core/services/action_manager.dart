import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Actions possibles sur un contenu décodé.
///
/// Règle absolue du cahier des charges : aucune action automatique. Tout ce
/// qui quitte QRFlow (ouvrir, appeler, SMS, e-mail, Maps) passe par une
/// confirmation explicite.
class ActionManager {
  static Future<void> copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Contenu copié')));
    }
  }

  static Future<void> share(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Boîte de confirmation avant toute action externe.
  static Future<bool> confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    bool danger = false,
  }) async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Icon(
          danger ? Icons.warning_amber_rounded : Icons.help_outline,
          color: danger ? scheme.error : scheme.primary,
        ),
        title: Text(title),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: danger
                ? FilledButton.styleFrom(backgroundColor: scheme.error)
                : null,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static Future<void> openUrl(
    BuildContext context,
    String url, {
    bool suspicious = false,
  }) async {
    final bool ok = await confirmAction(
      context,
      title: 'Ouvrir ce lien ?',
      message: suspicious
          ? 'Ce lien a été signalé comme potentiellement dangereux.\n\n$url'
          : 'Vous quittez QRFlow pour ouvrir :\n\n$url',
      actionLabel: 'Ouvrir le lien',
      danger: suspicious,
    );
    if (ok) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> dial(BuildContext context, String number) async {
    final bool ok = await confirmAction(
      context,
      title: 'Appeler ce numéro ?',
      message: number,
      actionLabel: 'Appeler',
    );
    if (ok) {
      await launchUrl(Uri(scheme: 'tel', path: number));
    }
  }

  static Future<void> sendSms(String number, String? message) async {
    await launchUrl(
      Uri(
        scheme: 'sms',
        path: number,
        queryParameters: message == null ? null : {'body': message},
      ),
    );
  }

  static Future<void> sendEmail(
    String address, {
    String? subject,
    String? body,
  }) async {
    await launchUrl(
      Uri(
        scheme: 'mailto',
        path: address,
        queryParameters: {
          if (subject != null) 'subject': subject,
          if (body != null) 'body': body,
        },
      ),
    );
  }

  static Future<void> openMaps(double latitude, double longitude) async {
    await launchUrl(Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude'));
  }
}
