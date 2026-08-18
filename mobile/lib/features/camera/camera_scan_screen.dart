import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/models/content_presentation.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/content_analyzer.dart';
import '../../widgets/finder_mark.dart';
import '../../widgets/scan_line.dart';
import '../result/result_screen.dart';

/// Mode Caméra : scan de QR codes en direct.
///
/// Stratégie de détection :
/// - `DetectionSpeed.normal` pour ne jamais manquer un QR code.
/// - Pas de filtre de format : le moteur détecte QR_CODE, AZTEC, DATA_MATRIX,
///   CODE_128, etc. Le type exact est affiché dans le résultat.
/// - Confirmation multi-frame : le même résultat doit apparaître sur plusieurs
///   frames avant d'être accepté (réduit les faux positifs).
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // DetectionSpeed.normal : analyse chaque frame. Plus fiable que
    // noDuplicates qui peut ignorer des QR valides.
    detectionSpeed: DetectionSpeed.normal,
    // Pas de filtre de format : on détecte tout pour pouvoir afficher
    // le type exact (QR Code, Data Matrix, Code 128, etc.)
    // La limite de détection est à 256 pour éviter la surcharge.
    detectionTimeoutMs: 250,
    returnImage: false,
  );

  bool _handled = false;
  bool _torchOn = false;

  // ── Multi-frame confirmation ──────────────────────────────────────────────
  // Le même résultat brut doit apparaître au moins 2 fois avant d'être accepté.
  String? _lastRaw;
  int _confirmCount = 0;
  static const int _requiredConfirmations = 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final Barcode b in capture.barcodes) {
      final String? raw = b.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;

      // ── Confirmation multi-frame ──
      if (raw == _lastRaw) {
        _confirmCount++;
      } else {
        _lastRaw = raw;
        _confirmCount = 1;
      }

      if (_confirmCount >= _requiredConfirmations) {
        _handled = true;
        HapticFeedback.mediumImpact();
        _controller.stop();
        final String? formatName = _barcodeFormatLabel(b.format);
        final QrContent content = ContentAnalyzer.analyze(raw, barcodeFormat: formatName);
        context.read<AppState>().recordScan(
              type: typeLabel(content),
              source: 'Caméra',
              raw: content.raw,
            );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(content: content, source: 'Caméra'),
          ),
        );
        return;
      }
    }
  }

  /// Convertit un BarcodeFormat enum en nom lisible.
  String? _barcodeFormatLabel(BarcodeFormat? format) {
    if (format == null) return null;
    return switch (format) {
      BarcodeFormat.qrCode => 'QR Code',
      BarcodeFormat.microQrCode => 'Micro QR',
      BarcodeFormat.aztec => 'Aztec',
      BarcodeFormat.dataMatrix => 'Data Matrix',
      BarcodeFormat.pdf417 => 'PDF417',
      BarcodeFormat.code128 => 'Code 128',
      BarcodeFormat.code39 => 'Code 39',
      BarcodeFormat.code93 => 'Code 93',
      BarcodeFormat.codabar => 'Codabar',
      BarcodeFormat.ean8 => 'EAN-8',
      BarcodeFormat.ean13 => 'EAN-13',
      BarcodeFormat.itf2of5 => 'ITF',
      BarcodeFormat.upcA => 'UPC-A',
      BarcodeFormat.upcE => 'UPC-E',
      BarcodeFormat.maxiCode => 'MaxiCode',
      BarcodeFormat.dataBar => 'GS1 DataBar',
      BarcodeFormat.dataBarExpanded => 'GS1 DataBar Expanded',
      BarcodeFormat.dataBarLimited => 'GS1 DataBar Limited',
      BarcodeFormat.itf2of5WithChecksum => 'ITF',
      BarcodeFormat.all => null,
      BarcodeFormat.unknown => null,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (BuildContext context, MobileScannerException error) =>
                _buildError(theme, scheme, error),
          ),
          // Voile + signature du viseur
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FinderMark(
                          size: 260, color: Colors.white, strokeRatio: 0.06),
                      ScanLine(size: 260, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Barre du haut
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fermer',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _torchOn ? 'Éteindre la lampe' : 'Allumer la lampe',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: _torchOn ? Colors.amber : Colors.white,
                    ),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (mounted) {
                        setState(() => _torchOn = !_torchOn);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          // Indication basse
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Visez un QR code pour le scanner',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
      ThemeData theme, ColorScheme scheme, MobileScannerException error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.no_photography_outlined,
                  size: 56, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                'Caméra indisponible',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Vérifiez que l\'autorisation caméra est accordée, puis réessayez.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _controller.start(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
