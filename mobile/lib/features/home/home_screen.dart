import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../widgets/mode_card.dart';
import '../../widgets/scan_line.dart';
import '../camera/camera_scan_screen.dart';
import '../history/history_screen.dart';
import '../import/import_screen.dart';
import '../settings/settings_screen.dart';

/// Écran d'accueil : la marque et le hub des modes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/logo.png', width: 32, height: 32, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Text('QRFlow', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Réglages',
                  icon: Icon(Icons.tune, color: scheme.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Center(
              child: SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset('assets/logo.png', width: 120, height: 120, fit: BoxFit.contain),
                    const ScanLine(size: 130, color: QrTokens.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Le QR code est déjà sur votre écran.',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scannez-le, comprenez-le, confirmez, agissez.\nTout reste sur votre téléphone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ModeCard(
              icon: Icons.image_outlined,
              title: 'Importer une image',
              description: 'Capture d’écran ou photo de la galerie',
              onTap: () => _push(context, const ImportScreen()),
            ),
            const SizedBox(height: 12),
            ModeCard(
              icon: Icons.center_focus_strong,
              title: 'Caméra',
              description: 'Scanner un QR code en direct',
              onTap: () => _push(context, const CameraScanScreen()),
            ),
            const SizedBox(height: 12),
            ModeCard(
              icon: Icons.history,
              title: 'Historique',
              description: 'Retrouver et gérer vos scans',
              onTap: () => _push(context, const HistoryScreen()),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
