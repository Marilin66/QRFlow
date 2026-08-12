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
  bool _projectionActive = false;
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
      // La capture par MediaProjection fonctionne dès Android 5 : le mode
      // est disponible sur toutes les versions supportées.
      _unsupported = state['supported'] != true;
      _overlayGranted = state['overlayPermission'] == true;
      _accessibilityGranted = state['accessibilityPermission'] == true;
      _bubbleActive = state['bubbleActive'] == true;
      _projectionActive = state['projectionActive'] == true;
      _loading = false;
    });
  }

  Future<void> _toggleBubble() async {
    if (_bubbleActive) {
      await ScreenCaptureBridge.stopBubble();
      setState(() {
        _bubbleActive = false;
        _projectionActive = false;
      });
      return;
    }

    if (!_overlayGranted) {
      await ScreenCaptureBridge.requestOverlayPermission();
      return;
    }

    // Android 13+ : la notification du service foreground nécessite
    // l'autorisation POST_NOTIFICATIONS.
    await ScreenCaptureBridge.ensureNotificationPermission();

    final ok = await ScreenCaptureBridge.startBubble();
    if (!mounted) return;
    if (ok) {
      setState(() => _bubbleActive = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Autorisation de capture d\u2019écran demandée : acceptez-la pour '
            'activer la bulle.',
          ),
          duration: Duration(seconds: 5),
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
                  '1. Accordez la permission « Afficher par-dessus les applications ».\n'
                  '2. Activez la bulle : QRFlow demande une autorisation de\n'
                  '   capture d\u2019écran (une seule fois, à l\u2019activation).\n'
                  '3. Ouvrez l\u2019application où le QR code est affiché.\n'
                  '4. Appuyez sur la bulle : l\u2019écran est capturé et analysé\n'
                  '   instantanément.\n'
                  '5. Le résultat s\u2019affiche en carte flottante par-dessus votre\n'
                  '   application : agissez ou fermez, sans jamais la quitter.',
            ),
            const SizedBox(height: 16),

            _InfoCard(
              icon: Icons.security_outlined,
              color: theme.colorScheme.secondary,
              title: 'Confidentialité & repli accessibilité',
              message:
                  'Toute l\u2019analyse est locale, aucune donnée n\u2019est envoyée à '
                  'l\u2019extérieur. Si le service d\u2019accessibilité d\u2019Android est '
                  'activé, QRFlow peut lire directement le texte à l\u2019écran '
                  '(sans capture). Sinon, la capture d\u2019écran par projection '
                  'prend le relais automatiquement. Certaines applications '
                  '(banque, DRM…) bloquent la capture : importez alors une '
                  'capture classique.',
            ),
            const SizedBox(height: 16),

            if (!_unsupported) ...[
              _PermissionRow(
                label: 'Affichage par-dessus les applications',
                granted: _overlayGranted,
              ),
              _PermissionRow(
                label: 'Capture d\u2019écran (projection)',
                granted: _projectionActive,
              ),
              _PermissionRow(
                label: 'Bulle flottante',
                granted: _bubbleActive,
              ),
              _PermissionRow(
                label: 'Accessibilité (optionnel, lecture directe)',
                granted: _accessibilityGranted,
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
