import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';

/// Réglages : apparence (thème) — s'étoffera aux niveaux suivants.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppState appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Apparence',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QrTokens.radiusCard),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                _ThemeTile(
                  icon: Icons.brightness_auto,
                  title: 'Système',
                  subtitle: 'Suivre le thème du téléphone',
                  selected: appState.themeMode == ThemeMode.system,
                  onTap: () => appState.themeMode = ThemeMode.system,
                ),
                _ThemeTile(
                  icon: Icons.light_mode,
                  title: 'Clair',
                  selected: appState.themeMode == ThemeMode.light,
                  onTap: () => appState.themeMode = ThemeMode.light,
                ),
                _ThemeTile(
                  icon: Icons.dark_mode,
                  title: 'Sombre',
                  selected: appState.themeMode == ThemeMode.dark,
                  onTap: () => appState.themeMode = ThemeMode.dark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'À propos',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(QrTokens.radiusCard),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              'QRFlow détecte, décode et interprète les QR codes déjà affichés à l’écran. Toutes les analyses sont locales : aucune donnée n’est envoyée sur Internet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected
          ? Icon(Icons.check_circle, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
