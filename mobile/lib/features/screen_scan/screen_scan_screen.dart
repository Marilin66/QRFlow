import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/history_entry.dart';
import '../../core/platform/screen_capture_bridge.dart';
import '../../core/services/content_analyzer.dart';
import '../result/result_screen.dart';

/// Mode 2 — « Scanner l'écran ».
///
/// Active une bulle flottante au-dessus des autres applications. Un appui sur
/// la bulle déclenche la capture d'écran officielle (MediaProjection), puis
/// l'analyse du QR code affiché.
class ScreenScanScreen extends StatefulWidget {
  const ScreenScanScreen({super.key});

  @override
  State<ScreenScanScreen> createState() => _ScreenScanScreenState();
}

class _ScreenScanScreenState extends State<ScreenScanScreen>
    with WidgetsBindingObserver {
  static const _analyzer = ContentAnalyzer();

  bool _overlayGranted = false;
  bool _bubbleActive = false;
  bool _loading = true;
  bool _unsupported = false;
  bool _checking = false;

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
    // L'utilisateur revient des paramètres système ou après une capture.
    if (state == AppLifecycleState.resumed) {
      _refreshState();
      _checkPendingCapture();
    }
  }

  Future<void> _refreshState() async {
    final state = await ScreenCaptureBridge.getPlatformState();
    if (!mounted) return;
    setState(() {
      _unsupported = !(state['supported'] == true || state['isAndroid'] == true);
      _overlayGranted = state['overlayPermission'] == true;
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

    await ScreenCaptureBridge.ensureNotificationPermission();
    if (!_overlayGranted) {
      await ScreenCaptureBridge.requestOverlayPermission();
      // La permission est accordée dans les paramètres système ; on reverra
      // l'état au retour de l'utilisateur.
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

  /// Vérifie si une capture a été produite par la bulle pendant que
  /// l'application était en arrière-plan.
  Future<void> _checkPendingCapture() async {
    if (_checking) return;
    _checking = true;
    try {
      final path = await ScreenCaptureBridge.takePendingCapture();
      if (path == null || !mounted) return;

      final controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
      String? raw;
      try {
        final capture = await controller.analyzeImage(path);
        raw = capture?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
      } finally {
        await controller.dispose();
      }

      if (!mounted) return;
      if (raw == null || raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun QR code détecté sur cette capture.\n'
              'Essayez à nouveau avec un QR code bien visible.',
            ),
          ),
        );
        return;
      }

      final content = _analyzer.analyze(raw);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            content: content,
            raw: raw!,
            method: ScanMethod.screenScan,
          ),
        ),
      );
    } finally {
      _checking = false;
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
                    'Le scanner direct d\u2019écran nécessite Android.\n'
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
                  '1. Activez la bulle flottante.\n'
                  '2. Ouvrez l\u2019application où le QR code est affiché.\n'
                  '3. Appuyez sur la bulle : Android demande votre accord '
                  'pour la capture d\u2019écran.\n'
                  '4. Le QR code est analysé et le résultat s\u2019affiche.',
            ),
            const SizedBox(height: 16),

            _InfoCard(
              icon: Icons.security_outlined,
              color: theme.colorScheme.secondary,
              title: 'Respect des règles Android',
              message:
                  'QRFlow n\u2019utilise que les mécanismes officiels : '
                  'permission d\u2019affichage par-dessus les applications, '
                  'consentement de capture (MediaProjection) et services '
                  'au premier plan déclarés. Sur Android 14+, le consentement '
                  'est demandé à chaque session, et Android 15 affiche une '
                  'pastille tant que la capture est active. Rien n\u2019est '
                  'fait sans votre accord explicite.',
            ),
            const SizedBox(height: 16),

            if (!_unsupported) ...[
              _PermissionRow(
                label: 'Affichage par-dessus les applications',
                granted: _overlayGranted,
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
                  label: const Text('Accorder la permission'),
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
