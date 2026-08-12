import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';

/// Réglages : apparence, historique, à propos.
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
          _sectionTitle(theme, scheme, 'Apparence'),
          const SizedBox(height: 12),
          _card(
            scheme,
            Column(
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
          _sectionTitle(theme, scheme, 'Historique'),
          const SizedBox(height: 12),
          _card(
            scheme,
            Column(
              children: [
                SwitchListTile(
                  value: appState.keepHistory,
                  onChanged: (bool value) => appState.keepHistory = value,
                  title: const Text('Conserver l’historique'),
                  subtitle: const Text(
                      'Enregistrer les scans pour les retrouver plus tard'),
                  secondary: const Icon(Icons.bookmark_outline),
                ),
                ListTile(
                  enabled: appState.history.isNotEmpty,
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Effacer l’historique'),
                  subtitle: appState.history.isEmpty
                      ? const Text('Aucun scan enregistré')
                      : Text(
                          '${appState.history.length} '
                          'scan${appState.history.length > 1 ? 's' : ''} '
                          'enregistré${appState.history.length > 1 ? 's' : ''}'),
                  onTap: () => _confirmClear(context, appState),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(theme, scheme, 'À propos'),
          const SizedBox(height: 12),
          _card(
            scheme,
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'QRFlow détecte, décode et interprète les QR codes déjà '
                'affichés à l’écran. Toutes les analyses sont locales : '
                'aucune donnée n’est envoyée sur Internet. Aucune action '
                'n’est déclenchée sans votre confirmation.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, ColorScheme scheme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
  }

  Widget _card(ColorScheme scheme, Widget child) {
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QrTokens.radiusCard),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Future<void> _confirmClear(BuildContext context, AppState appState) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Icon(Icons.delete_sweep_outlined,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Tout effacer ?'),
        content: const Text(
            'L’historique complet sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await appState.clearHistory();
    }
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
