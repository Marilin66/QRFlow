import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/platform/screen_capture_bridge.dart';
import '../../widgets/finder_mark.dart';

/// Mode Flash : activation de la bulle flottante et capture d'écran.
class ScreenScanScreen extends StatefulWidget {
  const ScreenScanScreen({super.key});

  @override
  State<ScreenScanScreen> createState() => _ScreenScanScreenState();
}

class _ScreenScanScreenState extends State<ScreenScanScreen>
    with WidgetsBindingObserver {
  bool _active = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour des écrans de permission (overlay / capture) : on relit l'état.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final bool active = await ScreenCaptureBridge.instance.isBubbleActive();
    if (mounted) {
      setState(() {
        _active = active;
        _checking = false;
      });
    }
  }

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    try {
      if (_active) {
        await ScreenCaptureBridge.instance.stopBubble();
      } else {
        await ScreenCaptureBridge.instance.startBubble();
      }
    } on PlatformException {
      // Le natif a refusé le démarrage (restrictions Android sur les
      // services avant-plan) : message clair, pas de crash.
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                  'Impossible de démarrer la bulle. Réessayez depuis l’écran « Scanner l’écran ».'),
            ),
          );
      }
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scanner l’écran')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          const Center(
            child: SizedBox(
              width: 88,
              height: 88,
              child: FinderMark(size: 88, color: QrTokens.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scannez un QR code affiché dans une autre app,\nsans quitter cette app.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          // État de la bulle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _active ? scheme.secondaryContainer : scheme.errorContainer,
              borderRadius: BorderRadius.circular(QrTokens.radiusField),
            ),
            child: Row(
              children: [
                Icon(
                  _active ? Icons.check_circle_outline : Icons.pause_circle_outline,
                  color: _active ? scheme.onSecondaryContainer : scheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _checking
                        ? 'Vérification…'
                        : _active
                            ? 'Bulle active : touchez-la pour scanner l’écran.'
                            : 'Bulle inactive.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _active
                          ? scheme.onSecondaryContainer
                          : scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_active ? Icons.stop : Icons.play_arrow),
              label: Text(_active ? 'Désactiver la bulle' : 'Activer la bulle'),
            ),
          ),
          const SizedBox(height: 28),
          _stepCard(
            theme,
            scheme,
            index: 1,
            title: 'Autoriser l’affichage par-dessus les apps',
            body:
                'Android demandera la permission « afficher par-dessus les '
                'autres applications » : elle est nécessaire à la bulle.',
          ),
          const SizedBox(height: 12),
          _stepCard(
            theme,
            scheme,
            index: 2,
            title: 'Confirmer la capture d’écran',
            body: "Une seule confirmation par session d’activation. "
                "Android l'exige : sans elle, rien n'est capturé.",
          ),
          const SizedBox(height: 12),
          _stepCard(
            theme,
            scheme,
            index: 3,
            title: 'Toucher la bulle',
            body:
                'La bulle capte l’écran, décode le QR et affiche le résultat '
                'en overlay — sans jamais quitter l’app en cours.',
          ),
          const SizedBox(height: 24),
          Text(
            'Note : les apps protégées (banques, paiement) bloquent la '
            'capture par sécurité. Dans ce cas, utilisez le Mode Import.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(
    ThemeData theme,
    ColorScheme scheme, {
    required int index,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(QrTokens.radiusCard),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontFamily: QrTokens.displayFamily,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
