import 'package:flutter/material.dart';

import '../../core/platform/screen_capture_bridge.dart';

/// Mode 2 — « Scanner l'écran ».
///
/// Active une bulle flottante au-dessus des autres applications. Un appui sur
/// la bulle déclenche la capture d'écran via l'API d'accessibilité.
class ScreenScanScreen extends StatefulWidget {
  const ScreenScanScreen({super.key});

  @override
  State<ScreenScanScreen> createState() => _ScreenScanScreenState();
}

class _ScreenScanScreenState extends State<ScreenScanScreen>
    with WidgetsBindingObserver {
  bool _overlayGranted = false;
  bool _accessibilityGranted = false;
  bool _bubbleActive = false;
  bool _loading = true;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    final state = await ScreenCaptureBridge.getPlatformState();
    if (!mounted) return;
    setState(() {
      // La capture d'écran via l'accessibilité nécessite Android 11+ : sur
      // les autres plateformes (ou Android < 11), le mode est indisponible.
      _unsupported = state['supported'] != true;
      _overlayGranted = state['overlayPermission'] == true;
      _accessibilityGranted = state['accessibilityPermission'] == true;
      _bubbleActive = state['bubbleActive'] == true;
      _loading = false;
    });
  }

  Future<void> _toggleBubble() async {
    if (_bubbleActive) {
      await ScreenCaptureBridge.stopBubble();
      setState(() => _bubbleActive = false);
      return;
    }

    if (!_overlayGranted) {
      await ScreenCaptureBridge.requestOverlayPermission();
      return;
    }

    if (!_accessibilityGranted) {
      await ScreenCaptureBridge.requestAccessibilityPermission();
      return;
    }

    final ok = await ScreenCaptureBridge.startBubble();
    if (!mounted) return;
    if (ok) {
      setState(() => _bubbleActive = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bulle activée. Ouvrez l\u2019application contenant le QR code, '
            'puis appuyez sur la bulle.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Scanner l\u2019écran')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_unsupported) ...[
              _InfoCard(
                icon: Icons.info_outline,
                color: theme.colorScheme.tertiary,
                title: 'Non pris en charge sur cette plateforme',
                message:
                    'Le scanner direct d\u2019écran nécessite Android 11 minimum.\n'
                    'Utilisez plutôt « Depuis une capture ».',
              ),
              const SizedBox(height: 16),
            ],

            // ── Étapes ───────────────────────────────────────────────
            _InfoCard(
              icon: Icons.touch_app,
              color: theme.colorScheme.primary,
              title: 'Comment ça marche',
              message:
                  '1. Accordez les permissions nécessaires.\n'
                  '2. Activez la bulle flottante.\n'
                  '3. Ouvrez l\u2019application où le QR code est affiché.\n'
                  '4. Appuyez sur la bulle : lecture directe du contenu, ou\n'
                  '   capture invisible si besoin.\n'
                  '5. Sélectionnez le QR code détecté à l\u2019écran.',
            ),
            const SizedBox(height: 16),

            _InfoCard(
              icon: Icons.security_outlined,
              color: theme.colorScheme.secondary,
              title: 'Service d\'accessibilité (Lecture Directe)',
              message:
                  'QRFlow utilise le service d\'accessibilité d\'Android '
                  'pour analyser directement le contenu textuel et les liens à l\'écran '
                  'SANS PRENDRE DE CAPTURE D\'ÉCRAN (aucune image enregistrée). '
                  'Si l\'élément est une simple image, un repli silencieux est effectué. '
                  'Aucune donnée n\'est envoyée à l\'extérieur.',
            ),
            const SizedBox(height: 16),

            if (!_unsupported) ...[
              _PermissionRow(
                label: 'Affichage par-dessus les applications',
                granted: _overlayGranted,
              ),
              _PermissionRow(
                label: 'Service d\'accessibilité (Capture)',
                granted: _accessibilityGranted,
              ),
              _PermissionRow(
                label: 'Bulle flottante',
                granted: _bubbleActive,
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (!_overlayGranted)
                FilledButton.icon(
                  onPressed: _toggleBubble,
                  icon: const Icon(Icons.tune),
                  label: const Text('Accorder Superposition'),
                )
              else if (!_accessibilityGranted)
                FilledButton.icon(
                  onPressed: _toggleBubble,
                  icon: const Icon(Icons.accessibility_new),
                  label: const Text('Accorder Accessibilité'),
                )
              else if (!_bubbleActive)
                FilledButton.icon(
                  onPressed: _toggleBubble,
                  icon: const Icon(Icons.bubble_chart),
                  label: const Text('Activer la bulle flottante'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _toggleBubble,
                  icon: const Icon(Icons.stop),
                  label: const Text('Désactiver la bulle'),
                ),
            ],

            const SizedBox(height: 24),
            Text(
              'Capture impossible ?\n'
              'Certaines applications bloquent volontairement la capture '
              'd\u2019écran (banque, DRM…). Dans ce cas, faites une capture '
              'd\u2019écran classique et importez-la dans « Depuis une capture ».',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: granted ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            granted ? 'Activé' : 'Inactif',
            style: theme.textTheme.bodySmall?.copyWith(
              color: granted ? Colors.green : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
