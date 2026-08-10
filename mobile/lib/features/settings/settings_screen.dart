import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/platform/screen_capture_bridge.dart';
import '../../core/services/history_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bubbleActive = false;

  @override
  void initState() {
    super.initState();
    _refreshBubbleState();
  }

  Future<void> _refreshBubbleState() async {
    final state = await ScreenCaptureBridge.getPlatformState();
    if (mounted) {
      setState(() => _bubbleActive = state['bubbleActive'] == true);
    }
  }

  Future<void> _toggleBubble(bool value) async {
    if (value) {
      await ScreenCaptureBridge.ensureNotificationPermission();
      final state = await ScreenCaptureBridge.getPlatformState();
      if (state['overlayPermission'] != true) {
        await ScreenCaptureBridge.requestOverlayPermission();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Autorisez l\u2019affichage par-dessus les applications, '
              'puis réactivez la bulle.',
            ),
          ),
        );
        return;
      }
      await ScreenCaptureBridge.startBubble();
    } else {
      await ScreenCaptureBridge.stopBubble();
    }
    if (context.mounted) _refreshBubbleState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionTitle('Apparence'),
            Card(
              child: RadioGroup<ThemeMode>(
                groupValue: state.themeMode,
                onChanged: (v) {
                  if (v != null) state.themeMode = v;
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text('Thème système'),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('Clair'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('Sombre'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const _SectionTitle('Scanner'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Confirmation avant action'),
                    subtitle: const Text(
                      'Demander confirmation avant d\u2019ouvrir un lien, '
                      'appeler, envoyer un SMS…',
                    ),
                    value: state.confirmActions,
                    onChanged: (v) => state.confirmActions = v,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Détection de plusieurs QR codes'),
                    subtitle: const Text(
                      'Proposer un choix lorsque plusieurs QR codes sont présents.',
                    ),
                    value: state.multiQr,
                    onChanged: (v) => state.multiQr = v,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const _SectionTitle('Bulle flottante'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Bulle flottante active'),
                    value: _bubbleActive,
                    onChanged: _toggleBubble,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Taille de la bulle'),
                    trailing: Text('${state.bubbleSize.round()} dp'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      min: 56,
                      max: 120,
                      divisions: 16,
                      value: state.bubbleSize,
                      onChanged: (v) => state.bubbleSize = v,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Opacité de la bulle'),
                    trailing: Text('${(state.bubbleOpacity * 100).round()} %'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      min: 0.4,
                      max: 1.0,
                      divisions: 12,
                      value: state.bubbleOpacity,
                      onChanged: (v) => state.bubbleOpacity = v,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const _SectionTitle('Historique'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Conserver l\u2019historique'),
                    value: state.keepHistory,
                    onChanged: (v) => state.keepHistory = v,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Durée de conservation'),
                    trailing: Text(_retentionLabel(state.retentionDays)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<int>(
                      initialValue: state.retentionDays,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                      ),
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('30 jours')),
                        DropdownMenuItem(value: 90, child: Text('90 jours')),
                        DropdownMenuItem(value: 365, child: Text('1 an')),
                        DropdownMenuItem(value: 0, child: Text('Illimité')),
                      ],
                      onChanged: (v) {
                        if (v != null) state.retentionDays = v;
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Supprimer tout l\u2019historique'),
                    subtitle: const Text('Action irréversible'),
                    onTap: () async {
                      final history = context.read<HistoryService>();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Tout supprimer ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await history.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const _SectionTitle('Sécurité'),
            Card(
              child: SwitchListTile(
                title: const Text('Avertir pour les URL suspectes'),
                subtitle: const Text(
                  'Afficher un avertissement pour les liens risqués '
                  '(IP, extensions douteuses…).',
                ),
                value: state.warnSuspicious,
                onChanged: (v) => state.warnSuspicious = v,
              ),
            ),
            const SizedBox(height: 32),

            Center(
              child: Text(
                'QRFlow v0.1.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _retentionLabel(int days) => switch (days) {
        0 => 'Illimité',
        30 => '30 jours',
        90 => '90 jours',
        365 => '1 an',
        _ => '$days jours',
      };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
