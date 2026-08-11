import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/models/history_entry.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/action_manager.dart';
import '../../core/services/history_service.dart';

/// Écran de résultat : présente le contenu analysé et les actions adaptées.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.content,
    required this.raw,
    required this.method,
    this.fromHistory = false,
  });

  final QrContent content;
  final String raw;
  final ScanMethod method;

  /// Si vrai, la fiche provient de l'historique : on ne réenregistre pas.
  final bool fromHistory;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const _actionManager = ActionManager();

  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    if (widget.fromHistory || _saved) return;
    _saved = true;
    final appState = context.read<AppState>();
    if (!appState.keepHistory) return;

    final history = context.read<HistoryService>();
    await history.add(HistoryEntry(
      timestamp: DateTime.now(),
      type: widget.content.typeLabel,
      raw: widget.raw,
      method: widget.method,
      summary: widget.content.summary,
    ));
  }

  Future<void> _confirmAndRun(QrAction action) async {
    final appState = context.read<AppState>();
    final history = context.read<HistoryService>();
    var proceed = true;

    if (appState.confirmActions && action.confirmTitle != null) {
      proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(action.confirmTitle!),
              content: Text(action.confirmMessage ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmer'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!proceed || !mounted) return;
    await action.run(context);

    // Note l'action effectuée dans l'entrée la plus récente (best effort).
    if (!context.mounted || widget.fromHistory) return;
    final entries = history.entries;
    if (entries.isNotEmpty) {
      await history.updateAction(entries.first.id!, action.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = widget.content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat'),
        actions: [
          if (!widget.fromHistory)
            IconButton(
              tooltip: 'Supprimer de l\u2019historique',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final history = context.read<HistoryService>();
                final entries = history.entries;
                if (entries.isNotEmpty) {
                  await history.delete(entries.first.id!);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── En-tête : type ──────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Icon(content.type.icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        content.typeLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  widget.method.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Contenu brut ─────────────────────────────────────────
            Card(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  content.raw,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    height: 1.5,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF4DE1FF)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            // ── Détails spécifiques au type ──────────────────────────
            ..._detailsSections(theme),
            const SizedBox(height: 24),

            // ── Actions ──────────────────────────────────────────────
            Text(
              'ACTIONS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            ..._buildActionButtons(theme),
            const SizedBox(height: 28),

            Center(
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Nouveau scan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _detailsSections(ThemeData theme) {
    final content = widget.content;
    final sections = <Widget>[];

    void detail(String label, String value) {
      sections.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      ));
    }

    switch (content) {
      case QrUrl c:
        detail('Domaine', c.domain);
        detail('Connexion', c.isSecure ? 'Sécurisée (HTTPS)' : 'Non sécurisée (HTTP)');
        if (c.suspicious) {
          sections.add(const SizedBox(height: 12));
          sections.add(_WarningCard(reasons: c.suspicionReasons));
        }
      case QrPhone c:
        detail('Numéro', c.number);
      case QrEmail c:
        detail('Adresse', c.address);
        if (c.subject != null) detail('Objet', c.subject!);
        if (c.body != null) detail('Message', c.body!);
      case QrSms c:
        detail('Numéro', c.number);
        if (c.message != null) detail('Message', c.message!);
      case QrVCard c:
        if (c.name != null) detail('Nom', c.name!);
        if (c.phone != null) detail('Téléphone', c.phone!);
        if (c.email != null) detail('E-mail', c.email!);
        if (c.org != null) detail('Organisation', c.org!);
        if (c.address != null) detail('Adresse', c.address!);
        if (c.url != null) detail('Site web', c.url!);
        if (c.note != null) detail('Note', c.note!);
      case QrWifi c:
        detail('Réseau', c.ssid);
        detail('Sécurité', c.security);
        if (c.password != null) detail('Mot de passe', c.password!);
        if (c.hidden) detail('Réseau masqué', 'Oui');
        sections.add(const SizedBox(height: 12));
        sections.add(const _NoteCard(
          text: 'QRFlow ne se connecte jamais automatiquement à un réseau Wi-Fi. '
              'Copiez le mot de passe ou saisissez-le dans les paramètres Wi-Fi.',
        ));
      case QrGeo c:
        detail('Latitude', c.latitude.toStringAsFixed(6));
        detail('Longitude', c.longitude.toStringAsFixed(6));
      case QrCalendar c:
        if (c.title != null) detail('Titre', c.title!);
        if (c.start != null) detail('Début', _formatDateTime(c.start!));
        if (c.end != null) detail('Fin', _formatDateTime(c.end!));
        if (c.location != null) detail('Lieu', c.location!);
        if (c.description != null) detail('Description', c.description!);
      case QrApp c:
        detail('Application', c.packageName ?? c.uri);
      case QrText():
      case QrUnknown():
        break;
    }

    return sections;
  }

  List<Widget> _buildActionButtons(ThemeData theme) {
    final actions = _actionManager.actionsFor(widget.content);
    return [
      for (final action in actions) ...[
        if (action.primary)
          FilledButton.icon(
            onPressed: () => _confirmAndRun(action),
            icon: Icon(action.icon),
            label: Text(action.label),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _confirmAndRun(action),
            icon: Icon(action.icon),
            label: Text(action.label),
          ),
        const SizedBox(height: 10),
      ],
    ];
  }

  static String _formatDateTime(DateTime dt) {
    final date = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$date à $time';
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lien potentiellement dangereux',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final reason in reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $reason',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ),
    );
  }
}
