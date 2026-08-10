import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/history_entry.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/content_analyzer.dart';
import '../../core/services/history_service.dart';
import '../result/result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _analyzer = ContentAnalyzer();

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _clearAll() async {
    final history = context.read<HistoryService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout supprimer ?'),
        content: const Text(
          'L\u2019intégralité de l\u2019historique sera supprimée. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await history.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = context.watch<HistoryService>();
    final entries = history.search(_query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            tooltip: 'Tout supprimer',
            onPressed: entries.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Rechercher dans l\u2019historique…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? _buildEmpty(theme)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _HistoryTile(
                          entry: entry,
                          onDelete: () => history.delete(entry.id!),
                          onOpen: () {
                            final content = _analyzer.analyze(entry.raw);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ResultScreen(
                                  content: content,
                                  raw: entry.raw,
                                  method: entry.method,
                                  fromHistory: true,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty
                ? 'Aucune analyse pour le moment.'
                : 'Aucun résultat pour « $_query ».',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onDelete,
    required this.onOpen,
  });

  final HistoryEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeEmoji = QrContentType.values
        .where((t) => t.label == entry.type)
        .map((t) => t.emoji)
        .firstOrNull;

    return Card(
      child: Dismissible(
        key: ValueKey('history_${entry.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete, color: theme.colorScheme.error),
        ),
        child: ListTile(
          leading: Text(typeEmoji ?? '❓', style: const TextStyle(fontSize: 26)),
          title: Text(
            entry.summary ?? entry.raw,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_formatDate(entry.timestamp)}  •  ${entry.type}'
            '${entry.action != null ? '  •  ${entry.action}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: entry.method == ScanMethod.screenScan
              ? const Icon(Icons.smartphone, size: 18)
              : entry.method == ScanMethod.camera
                  ? const Icon(Icons.photo_camera_outlined, size: 18)
                  : const Icon(Icons.image_outlined, size: 18),
          onTap: onOpen,
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final datePart = day == today
        ? 'Aujourd\u2019hui'
        : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$datePart à $time';
  }
}
