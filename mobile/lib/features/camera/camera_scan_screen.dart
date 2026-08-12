import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/models/content_presentation.dart';
import '../../core/models/qr_content.dart';
import '../../core/services/content_analyzer.dart';
import '../../widgets/finder_mark.dart';
import '../../widgets/scan_line.dart';
import '../result/result_screen.dart';

/// Mode Caméra : scan de QR codes en direct.
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;
  bool _torchOn = false;

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

      _handled = true;
      HapticFeedback.mediumImpact();
      _controller.stop();
      final QrContent content = ContentAnalyzer.analyze(raw);
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
                _buildError(theme, scheme),
          ),
          // Voile + signature du viseur
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: const SizedBox(
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

  Widget _buildError(ThemeData theme, ColorScheme scheme) {
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
                'Vérifiez que l’autorisation caméra est accordée, puis réessayez.',
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
