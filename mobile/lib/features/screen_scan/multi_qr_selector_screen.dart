import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/history_entry.dart';
import '../../core/services/content_analyzer.dart';
import '../result/result_screen.dart';

class MultiQRSelectorScreen extends StatefulWidget {
  final String imagePath;

  const MultiQRSelectorScreen({super.key, required this.imagePath});

  @override
  State<MultiQRSelectorScreen> createState() => _MultiQRSelectorScreenState();
}

class _MultiQRSelectorScreenState extends State<MultiQRSelectorScreen> {
  final MobileScannerController _controller =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  static const _analyzer = ContentAnalyzer();

  List<Barcode> _detectedBarcodes = [];
  bool _isAnalyzing = true;
  String? _errorMessage;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    try {
      final image = File(widget.imagePath);
      final decodedImage = await decodeImageFromList(await image.readAsBytes());
      if (mounted) {
        setState(() {
          _imageSize = Size(
              decodedImage.width.toDouble(), decodedImage.height.toDouble());
        });
      }

      final capture = await _controller.analyzeImage(widget.imagePath);
      if (mounted) {
        setState(() {
          _detectedBarcodes = capture?.barcodes ?? [];
          _isAnalyzing = false;
        });

        if (_detectedBarcodes.isEmpty) {
          _errorMessage = "Aucun QR code détecté sur cette capture.";
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur lors de l'analyse : $e";
          _isAnalyzing = false;
        });
      }
    }
  }

  void _onBarcodeTapped(Barcode barcode) {
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    final content = _analyzer.analyze(raw);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          content: content,
          raw: raw,
          method: ScanMethod.screenScan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Sélectionnez un QR Code"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      extendBodyBehindAppBar: true,
      body: _isAnalyzing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.black54,
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (_imageSize == null) return const SizedBox();

                    // Calculer le ratio pour adapter les bounding boxes
                    final widthRatio = constraints.maxWidth / _imageSize!.width;
                    final heightRatio =
                        constraints.maxHeight / _imageSize!.height;
                    final scale =
                        widthRatio < heightRatio ? widthRatio : heightRatio;

                    final dx =
                        (constraints.maxWidth - _imageSize!.width * scale) / 2;
                    final dy =
                        (constraints.maxHeight - _imageSize!.height * scale) /
                            2;

                    return Stack(
                      children: [
                        Center(
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                        ..._detectedBarcodes.map((barcode) {
                          final corners = barcode.corners;
                          if (corners.isEmpty) {
                            return const SizedBox();
                          }

                          // Calculer la bounding box
                          double minX = corners[0].dx;
                          double maxX = corners[0].dx;
                          double minY = corners[0].dy;
                          double maxY = corners[0].dy;

                          for (var corner in corners) {
                            if (corner.dx < minX) minX = corner.dx;
                            if (corner.dx > maxX) maxX = corner.dx;
                            if (corner.dy < minY) minY = corner.dy;
                            if (corner.dy > maxY) maxY = corner.dy;
                          }

                          final left = dx + minX * scale;
                          final top = dy + minY * scale;
                          final width = (maxX - minX) * scale;
                          final height = (maxY - minY) * scale;

                          return Positioned(
                            left: left,
                            top: top,
                            width: width,
                            height: height,
                            child: GestureDetector(
                              onTap: () => _onBarcodeTapped(barcode),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 3,
                                  ),
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
    );
  }
}
