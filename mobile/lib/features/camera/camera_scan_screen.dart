import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/history_entry.dart';
import '../../core/services/content_analyzer.dart';
import '../result/result_screen.dart';

/// Scan en direct via la caméra (fonctionnalité complémentaire).
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  static const _analyzer = ContentAnalyzer();

  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    HapticFeedback.mediumImpact();

    final content = _analyzer.analyze(raw);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          content: content,
          raw: raw,
          method: ScanMethod.camera,
        ),
      ),
    ).then((_) {
      _handled = false;
      _controller.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner avec la caméra')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                return const _CameraError(
                  icon: Icons.no_photography_outlined,
                  message: 'Autorisation caméra refusée.\n'
                      'Activez-la dans les paramètres de l\u2019application.',
                );
              }
              return const _CameraError(
                icon: Icons.videocam_off_outlined,
                message: 'Impossible d\u2019accéder à la caméra.',
              );
            },
          ),
          // Cadre de visée
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2.5),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Text(
                'Placez le QR code dans le cadre',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white54, size: 56),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
