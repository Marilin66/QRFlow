import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/content_presentation.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/action_manager.dart';

/// Présentation du contenu décodé : Détection → Présentation → Confirmation
/// → Action. Aucune action automatique.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.content, this.source = 'Import'});

  final QrContent content;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat'),
        actions: [
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy),
            onPressed: () => ActionManager.copy(context, content.raw),
          ),
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => ActionManager.share(content.raw),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildContentCard(context),
          if (content is QrUrl && (content as QrUrl).suspicious) ...[
            const SizedBox(height: 16),
            _buildSuspiciousBanner(context),
          ],
          const SizedBox(height: 12),
          _buildDetails(context),
          const SizedBox(height: 24),
          _buildPrimaryAction(context),
          const SizedBox(height: 12),
          _buildSecondaryActions(context),
        ],
      ),
    );
  }

  // ── Carte de contenu ──────────────────────────────────────────────────
  Widget _buildContentCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(QrTokens.radiusCard),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _typeColor(scheme).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_typeIcon(), color: _typeColor(scheme), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_typeLabel(), style: theme.textTheme.titleMedium),
                    Text(
                      'Via : $source',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            content.raw,
            style: TextStyle(
              fontFamily: QrTokens.monoFamily,
              fontSize: 14,
              height: 1.45,
              color: scheme.onSurface,
            ),
          ),
          if (content is QrUrl) ...[
            const SizedBox(height: 14),
            _buildDomainRow(context, (content as QrUrl).host, (content as QrUrl).suspicious),
          ],
        ],
      ),
    );
  }

  Widget _buildDomainRow(BuildContext context, String host, bool suspicious) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = suspicious ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            suspicious ? Icons.warning_amber_rounded : Icons.lock_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              suspicious ? 'Domaine : $host' : host,
              style: TextStyle(
                fontFamily: QrTokens.monoFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bandeau de lien dangereux ────────────────────────────────────────
  Widget _buildSuspiciousBanner(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(QrTokens.radiusField),
      ),
      child: Row(
        children: [
          Icon(Icons.gpp_bad_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lien potentiellement dangereux : domaine peu fiable, '
              'raccourcisseur ou adresse trompeuse. Vérifiez avant d’ouvrir.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  // ── Détails selon le type ────────────────────────────────────────────
  Widget _buildDetails(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<(String, String)> rows = switch (content) {
      QrWifi(:final ssid, :final security, :final password) => [
          ('Réseau', ssid),
          ('Sécurité', security.isEmpty ? '—' : security),
          ('Mot de passe', password ?? '—'),
        ],
      QrVcard(:final name, :final phones, :final emails) => [
          if (name != null && name.isNotEmpty) ('Nom', name),
          for (final String p in phones) ('Téléphone', p),
          for (final String e in emails) ('E-mail', e),
        ],
      QrCalendar(:final title, :final start, :final end, :final location) => [
          if (title != null && title.isNotEmpty) ('Événement', title),
          if (start != null) ('Début', _fmt(start)),
          if (end != null) ('Fin', _fmt(end)),
          if (location != null && location.isNotEmpty) ('Lieu', location),
        ],
      QrGeo(:final latitude, :final longitude) => [
          ('Latitude', latitude.toStringAsFixed(5)),
          ('Longitude', longitude.toStringAsFixed(5)),
        ],
      QrEmail(:final address) => [('Adresse', address)],
      QrSms(:final number, :final message) => [
          ('Numéro', number),
          if (message != null && message.isNotEmpty) ('Message', message),
        ],
      QrPhone(:final number) => [('Numéro', number)],
      _ => const <(String, String)>[],
    };

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(QrTokens.radiusField),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    rows[i].$1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    rows[i].$2,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Action principale ────────────────────────────────────────────────
  Widget _buildPrimaryAction(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (String label, VoidCallback action) = switch (content) {
      QrUrl(:final url, :final suspicious) => (
          'Ouvrir le lien',
          () => ActionManager.openUrl(context, url, suspicious: suspicious),
        ),
      QrPhone(:final number) => (
          'Appeler',
          () => ActionManager.dial(context, number),
        ),
      QrEmail(:final address) => (
          'Écrire un e-mail',
          () => ActionManager.sendEmail(address),
        ),
      QrSms(:final number, :final message) => (
          'Envoyer un SMS',
          () => ActionManager.sendSms(number, message),
        ),
      QrWifi(:final password) => (
          'Copier le mot de passe',
          () => ActionManager.copy(context, password ?? ''),
        ),
      QrGeo(:final latitude, :final longitude) => (
          'Ouvrir dans Maps',
          () => ActionManager.openMaps(latitude, longitude),
        ),
      _ => (
          'Copier le contenu',
          () => ActionManager.copy(context, content.raw),
        ),
    };

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: action,
        icon: Icon(_typeIcon(), color: scheme.onPrimary),
        label: Text(label),
      ),
    );
  }

  // ── Actions secondaires ──────────────────────────────────────────────
  Widget _buildSecondaryActions(BuildContext context) {
    final List<(String, VoidCallback)> actions = switch (content) {
      QrUrl(:final url) => [
          ('Copier le lien', () => ActionManager.copy(context, url)),
        ],
      QrPhone(:final number) => [
          ('Envoyer un SMS', () => ActionManager.sendSms(number, null)),
          ('Copier le numéro', () => ActionManager.copy(context, number)),
        ],
      QrEmail(:final address) => [
          ('Copier l’adresse', () => ActionManager.copy(context, address)),
        ],
      QrWifi(:final ssid) => [
          ('Copier l’identifiant', () => ActionManager.copy(context, ssid)),
        ],
      QrVcard() => [
          ('Copier le contact', () => ActionManager.copy(context, content.raw)),
        ],
      QrCalendar() => [
          ('Copier les détails', () => ActionManager.copy(context, content.raw)),
        ],
      _ => const <(String, VoidCallback)>[],
    };

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final (String label, VoidCallback action) in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: action,
                child: Text(label),
              ),
            ),
          ),
      ],
    );
  }

  // ── Étiquettes / icônes / couleurs par type ──────────────────────────
  String _typeLabel() => typeLabel(content);

  IconData _typeIcon() => typeIcon(content);

  Color _typeColor(ColorScheme scheme) => switch (content) {
        QrUrl() => scheme.primary,
        QrPhone() => scheme.secondary,
        QrEmail() => scheme.primary,
        QrSms() => scheme.secondary,
        QrWifi() => scheme.secondary,
        QrGeo() => scheme.primary,
        QrVcard() => scheme.primary,
        QrCalendar() => scheme.secondary,
        _ => scheme.onSurfaceVariant,
      };

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
