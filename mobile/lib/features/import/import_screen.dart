import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/models/history_entry.dart';
import '../../core/services/content_analyzer.dart';
import '../result/result_screen.dart';

enum _Phase { idle, analyzing, multiple, error }

/// Mode 1 — Analyse d'une capture d'écran ou d'une image importée.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  static const _analyzer = ContentAnalyzer();

  final ImagePicker _picker = ImagePicker();
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  _Phase _phase = _Phase.idle;
  List<String> _rawValues = const [];
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyze() async {
    setState(() {
      _phase = _Phase.analyzing;
      _errorMessage = null;
    });

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (file == null) {
        if (mounted) setState(() => _phase = _Phase.idle);
        return;
      }

      final capture = await _controller.analyzeImage(file.path);
      final barcodes = capture?.barcodes ?? const [];
      final values = barcodes
          .map((b) => b.rawValue)
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toList();

      if (!mounted) return;

      if (values.isEmpty) {
        setState(() {
          _phase = _Phase.error;
          _errorMessage =
              'Aucun QR code détecté.\nEssayez de recadrer l\u2019image ou '
              'utilisez une image où le QR code est plus visible.';
        });
        return;
      }

      if (values.length == 1) {
        _openResult(values.first);
        return;
      }

      // Plusieurs QR codes : laisser l'utilisateur choisir.
      setState(() {
        _phase = _Phase.multiple;
        _rawValues = values;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMessage =
              'Impossible de lire cette image.\nVérifiez qu\u2019il s\u2019agit '
              'd\u2019une image au format pris en charge.';
        });
      }
    }
  }

  void _openResult(String raw) {
    final content = _analyzer.analyze(raw);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          content: content,
          raw: raw,
          method: ScanMethod.screenshot,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _phase = _Phase.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multiQr = context.watch<AppState>().multiQr;

    return Scaffold(
      appBar: AppBar(title: const Text('Depuis une capture')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_phase) {
            _Phase.idle => _buildIdle(theme),
            _Phase.analyzing => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyse de l\u2019image…'),
                  ],
                ),
              ),
            _Phase.multiple => _buildMultiple(theme, multiQr),
            _Phase.error => _buildError(theme),
          },
        ),
      ),
    );
  }

  Widget _buildIdle(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.screenshot_monitor_outlined,
            size: 52,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Importez une capture d\u2019écran\nou une image contenant un QR code.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _pickAndAnalyze,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Choisir une image'),
        ),
        const SizedBox(height: 12),
        Text(
          'L\u2019analyse est 100 % locale : rien n\u2019est envoyé sur Internet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMultiple(ThemeData theme, bool multiQr) {
    if (!multiQr) {
      // Détection multi-QR désactivée : on prend le premier trouvé.
      _openResult(_rawValues.first);
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plusieurs QR codes détectés',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Choisissez celui que vous souhaitez consulter :',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _rawValues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final raw = _rawValues[index];
              final content = _analyzer.analyze(raw);
              return Card(
                child: ListTile(
                  leading: Text(
                    content.type.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                  title: Text(
                    content.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(content.typeLabel),
                  onTap: () => _openResult(raw),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildError(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Erreur.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _pickAndAnalyze,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}
