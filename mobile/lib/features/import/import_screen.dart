import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/content_analyzer.dart';
import '../../core/services/qr_decoder.dart';
import '../../widgets/finder_mark.dart';
import '../../widgets/scan_line.dart';
import '../result/result_screen.dart';

/// Mode Import : décodage d'une image choisie dans la galerie.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ImagePicker _picker = ImagePicker();
  final QrDecoder _decoder = QrDecoder();
  bool _busy = false;

  Future<void> _pickAndDecode() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final QrDecodeResult result = await _decoder.decodeImage(picked.path);
      if (!mounted) return;

      if (result.failed) {
        _showInfo(
          'Image illisible',
          'Impossible de lire cette image. Essayez-en une autre.',
        );
        return;
      }
      if (result.values.isEmpty) {
        _showInfo(
          'Aucun QR code détecté',
          'Ce QR code semble flou, trop petit ou partiellement masqué. '
          'Essayez une image plus nette.',
        );
        return;
      }

      final List<QrContent> contents =
          result.values.map(ContentAnalyzer.analyze).toList();

      QrContent? content;
      if (contents.length == 1) {
        content = contents.first;
      } else {
        content = await _chooseOne(contents);
      }
      if (content == null || !mounted) return;

      // L'écran de résultat s'ouvre : on relâche l'état « Décodage… » pour
      // que le sélecteur soit immédiatement visible au retour.
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(content: content, source: 'Import'),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showInfo(
          'Erreur de décodage',
          'Un problème est survenu pendant l’analyse de l’image.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<QrContent?> _chooseOne(List<QrContent> contents) {
    final ThemeData theme = Theme.of(context);
    return showModalBottomSheet<QrContent>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                '${contents.length} QR codes détectés — choisissez-en un :',
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final QrContent c in contents)
              ListTile(
                leading: Icon(_typeIcon(c), color: theme.colorScheme.primary),
                title: Text(
                  _preview(c.raw),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: QrTokens.monoFamily),
                ),
                subtitle: Text(_typeLabel(c)),
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  String _preview(String raw) =>
      raw.length > 64 ? '${raw.substring(0, 64)}…' : raw;

  String _typeLabel(QrContent c) => switch (c) {
        QrUrl() => 'Lien web',
        QrText() => 'Texte',
        QrPhone() => 'Téléphone',
        QrEmail() => 'E-mail',
        QrSms() => 'SMS',
        QrWifi() => 'Wi-Fi',
        QrGeo() => 'GPS',
        QrVcard() => 'Contact',
        QrCalendar() => 'Événement',
        QrUnknown() => 'Contenu inconnu',
      };

  IconData _typeIcon(QrContent c) => switch (c) {
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Importer une image')),
      body: _busy ? _buildScanning(theme) : _buildChooser(theme, scheme),
    );
  }

  Widget _buildScanning(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FinderMark(size: 140, color: QrTokens.primary),
                ScanLine(size: 140, color: QrTokens.primary),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Décodage…', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Analyse locale : l’image ne quitte pas votre téléphone.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooser(ThemeData theme, ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(QrTokens.radiusCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(QrTokens.radiusCard),
            onTap: _pickAndDecode,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(QrTokens.radiusCard),
                border: Border.all(color: scheme.primary, width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Choisir une image',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture d’écran ou photo de la galerie\navec un QR code visible',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(QrTokens.radiusField),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: QrTokens.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aucune permission requise, analyse 100 % locale : '
                  'vos images ne sont jamais envoyées sur Internet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
