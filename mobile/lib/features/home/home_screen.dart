import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../widgets/finder_mark.dart';

/// Écran d'accueil : la marque, la promesse, et (dès le niveau 2) les modes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FinderMark(size: 96, color: QrTokens.primary),
                const SizedBox(height: 28),
                Text(
                  'QRFlow',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Le QR code est déjà sur votre écran.\nScannez-le, comprenez-le, agissez.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
