import 'package:flutter/material.dart';

import '../../core/platform/screen_capture_bridge.dart';
import '../../core/models/history_entry.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/content_analyzer.dart';
import '../result/result_screen.dart';

/// Liste les contenus textuels détectés à l'écran par lecture directe de
/// l'arbre d'accessibilité — **sans aucune capture d'écran**.
///
/// L'utilisateur touche l'élément correspondant au QR code pour l'analyser.
class ScreenTextSelectorScreen extends StatefulWidget {
  final List<String> candidates;

  const ScreenTextSelectorScreen({super.key, required this.candidates});

  @override
  State<ScreenTextSelectorScreen> createState() => _ScreenTextSelectorScreenState();
}

class _ScreenTextSelectorScreenState extends State<ScreenTextSelectorScreen> {
  static const _analyzer = ContentAnalyzer();

  void _onSelected(String raw) {
    final content = _analyzer.analyze(raw);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          content: content,
          raw: raw,
          method: ScanMethod.screenScan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('QR détecté sans capture')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.touch_app, color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Contenu détecté à l\u2019écran par lecture directe '
                        '(aucune capture). Touchez l\u2019élément correspondant '
                        'au QR code pour l\u2019analyser.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Option de secours : analyser l'écran complet (capture d'écran).
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: ListTile(
                onTap: () {
                  Navigator.of(context).pop();
                  ScreenCaptureBridge.captureScreen();
                },
                leading: const CircleAvatar(
                  child: Icon(Icons.qr_code_2),
                ),
                title: Text(
                  'Analyser l\u2019écran complet',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Le QR code est une image : capture invisible et détection.',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            for (final raw in widget.candidates)
              _CandidateTile(
                content: _analyzer.analyze(raw),
                raw: raw,
                onTap: () => _onSelected(raw),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner autrement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.content,
    required this.raw,
    required this.onTap,
  });

  final QrContent content;
  final String raw;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(content.type.icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          content.typeLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          raw,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
