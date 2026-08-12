import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/models/content_presentation.dart';
import '../../core/models/history_entry.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/content_analyzer.dart';
import '../result/result_screen.dart';

/// Mode Historique : liste des scans passés, recherche, suppression.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Rafraîchit au cas où des scans ont eu lieu entre-temps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppState appState = context.watch<AppState>();

    final List<HistoryEntry> entries = _query.trim().isEmpty
        ? appState.history
        : appState.history
            .where((HistoryEntry e) =>
                e.raw.toLowerCase().contains(_query.toLowerCase()) ||
                e.type.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          if (appState.history.isNotEmpty)
            IconButton(
              tooltip: 'Tout effacer',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, appState),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              onChanged: (String value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Rechercher dans l’historique…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? _buildEmpty(theme, scheme)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final HistoryEntry entry = entries[index];
                      return _buildEntry(context, appState, entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(
      BuildContext context, AppState appState, HistoryEntry entry) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final QrContent content = ContentAnalyzer.analyze(entry.raw);

    return Dismissible(
      key: ValueKey('history-${entry.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => appState.deleteEntry(entry.id!),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(QrTokens.radiusCard),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(QrTokens.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(QrTokens.radiusCard),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ResultScreen(
                content: content,
                source: entry.source,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(QrTokens.radiusCard),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(typeIcon(content),
                      color: scheme.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.type,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.raw,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: QrTokens.monoFamily,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtDate(entry.date)} · via ${entry.source}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _query.isEmpty
                  ? 'Aucun scan pour l’instant'
                  : 'Aucun résultat pour « $_query »',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _query.isEmpty
                  ? 'Scannez un QR code avec l’import ou la caméra :\n'
                      'il apparaîtra ici.'
                  : 'Essayez un autre terme de recherche.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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

  static String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
