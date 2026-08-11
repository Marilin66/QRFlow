import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/history_entry.dart';
import '../../core/services/content_analyzer.dart';
import '../result/result_screen.dart';

/// Écran de sélection et de cadrage de QR code sur capture d'écran.
/// Conçu comme un filtre de visée caméra immersif au-dessus de l'écran capturé,
/// avec balayage laser, détection automatique et rectangle de cadrage manuel.
class MultiQRSelectorScreen extends StatefulWidget {
  final String imagePath;

  const MultiQRSelectorScreen({super.key, required this.imagePath});

  @override
  State<MultiQRSelectorScreen> createState() => _MultiQRSelectorScreenState();
}

class _MultiQRSelectorScreenState extends State<MultiQRSelectorScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  static const _analyzer = ContentAnalyzer();

  List<Barcode> _detectedBarcodes = [];
  bool _isAnalyzing = true;
  bool _isCroppingScan = false;
  String? _errorMessage;
  Size? _imageSize;

  // Animation du laser de balayage type caméra sci-fi
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  // Rectangle de cadrage manuel (exprimé en pourcentages 0.0 -> 1.0 de l'image)
  Rect _cropRect = const Rect.fromLTWH(0.15, 0.25, 0.70, 0.50);
  bool _showManualFrame = false;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _analyzeImage();
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final image = File(widget.imagePath);
      if (!image.existsSync()) {
        if (mounted) {
          setState(() {
            _errorMessage = "Fichier de capture introuvable.";
            _isAnalyzing = false;
          });
        }
        return;
      }

      final bytes = await image.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          _imageSize = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
        });
      }

      final capture = await _controller.analyzeImage(widget.imagePath);
      if (mounted) {
        final barcodes = capture?.barcodes ?? [];
        setState(() {
          _detectedBarcodes = barcodes;
          _isAnalyzing = false;
          if (barcodes.isEmpty) {
            _showManualFrame = true; // Activer le cadrage manuel si aucun QR auto
            _errorMessage =
                "Aucun QR code détecté automatiquement.\nPlacez le rectangle de visée sur le QR code et appuyez sur « Scanner la zone ».";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur d'analyse : $e";
          _isAnalyzing = false;
        });
      }
    }
  }

  /// Rogne la zone délimitée par le rectangle manuel et lance le scan dessus
  Future<void> _scanCroppedArea(Size viewportSize, Rect imageRenderBounds) async {
    if (_imageSize == null) return;

    setState(() {
      _isCroppingScan = true;
    });

    try {
      final srcFile = File(widget.imagePath);
      final bytes = await srcFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final ui.Image fullImage = frameInfo.image;

      // Convertir _cropRect (pourcentages) en pixels réels de l'image source
      final double cropX = (_cropRect.left * fullImage.width)
          .clamp(0.0, fullImage.width.toDouble() - 10);
      final double cropY = (_cropRect.top * fullImage.height)
          .clamp(0.0, fullImage.height.toDouble() - 10);
      final double cropW = (_cropRect.width * fullImage.width)
          .clamp(10.0, fullImage.width.toDouble() - cropX);
      final double cropH = (_cropRect.height * fullImage.height)
          .clamp(10.0, fullImage.height.toDouble() - cropY);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, cropW, cropH),
      );

      canvas.drawImageRect(
        fullImage,
        Rect.fromLTWH(cropX, cropY, cropW, cropH),
        Rect.fromLTWH(0, 0, cropW, cropH),
        Paint(),
      );

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(cropW.toInt(), cropH.toInt());
      final byteData =
          await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception("Impossible de générer l'image rognée.");
      }

      final tempDir = await getTemporaryDirectory();
      final croppedFile = File(
          '${tempDir.path}/cropped_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await croppedFile.writeAsBytes(byteData.buffer.asUint8List());

      // Analyse de la sous-zone rognée
      final capture = await _controller.analyzeImage(croppedFile.path);
      final barcodes = capture?.barcodes ?? [];

      if (!mounted) return;

      if (barcodes.isNotEmpty) {
        _onBarcodeTapped(barcodes.first);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aucun QR code trouvé dans la zone sélectionnée. Ajustez le cadre et réessayez."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de cadrage : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCroppingScan = false;
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fond : Capture d'écran (simulant la vue caméra arrière)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                    ),

                    // 2. Filtre Overlay Viseur Caméra (Sci-Fi Vignette)
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),

                    // 3. Laser de balayage animé sur toute la hauteur
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: constraints.maxHeight * _scanAnimation.value,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  primaryColor.withValues(alpha: 0.4),
                                  primaryColor,
                                  primaryColor.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.8),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // 4. Calcul des coordonnées de l'image rendue
                    if (_imageSize != null)
                      _buildInteractiveOverlays(
                        context,
                        constraints,
                        primaryColor,
                      ),
                  ],
                );
              },
            ),
          ),

          // 5. En-tête HUD Viseur Caméra
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "VISEUR ÉCRAN ACTIF",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _detectedBarcodes.isNotEmpty
                                ? "${_detectedBarcodes.length} QR code(s) détecté(s) — Touchez pour ouvrir"
                                : "Ajustez le viseur sur le QR code",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showManualFrame
                            ? Icons.crop_free
                            : Icons.crop_square_rounded,
                        color: _showManualFrame
                            ? primaryColor
                            : Colors.white70,
                      ),
                      tooltip: "Activer/Désactiver le cadrage manuel",
                      onPressed: () {
                        setState(() {
                          _showManualFrame = !_showManualFrame;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Indicateur de chargement / message d'erreur
          if (_isAnalyzing || _isCroppingScan)
            Container(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 14),
                      Text(
                        _isCroppingScan
                            ? "Analyse de la zone sélectionnée..."
                            : "Scan de l'écran en cours...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. Barre d'action inférieure HUD
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMessage != null && _detectedBarcodes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _analyzeImage,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("Réanalyser"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_showManualFrame) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final media = MediaQuery.of(context);
                                final size = media.size;
                                _scanCroppedArea(
                                  size,
                                  Rect.fromLTWH(0, 0, size.width, size.height),
                                );
                              },
                              icon: const Icon(Icons.qr_code_scanner, size: 20),
                              label: const Text("Scanner la zone"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Superpose les cibles QR détectées automatiquement et le cadre manuel réglable
  Widget _buildInteractiveOverlays(
    BuildContext context,
    BoxConstraints constraints,
    Color primaryColor,
  ) {
    final imageWidth = _imageSize!.width;
    final imageHeight = _imageSize!.height;

    final widthRatio = constraints.maxWidth / imageWidth;
    final heightRatio = constraints.maxHeight / imageHeight;
    final scale = widthRatio < heightRatio ? widthRatio : heightRatio;

    final renderW = imageWidth * scale;
    final renderH = imageHeight * scale;
    final dx = (constraints.maxWidth - renderW) / 2;
    final dy = (constraints.maxHeight - renderH) / 2;

    return Stack(
      children: [
        // A. QR Codes détectés automatiquement (Bounding boxes néon)
        ..._detectedBarcodes.map((barcode) {
          final corners = barcode.corners;
          if (corners.isEmpty) return const SizedBox();

          double minX = corners[0].dx;
          double maxX = corners[0].dx;
          double minY = corners[0].dy;
          double maxY = corners[0].dy;

          for (var c in corners) {
            if (c.dx < minX) minX = c.dx;
            if (c.dx > maxX) maxX = c.dx;
            if (c.dy < minY) minY = c.dy;
            if (c.dy > maxY) maxY = c.dy;
          }

          final targetLeft = dx + minX * scale;
          final targetTop = dy + minY * scale;
          final targetW = (maxX - minX) * scale;
          final targetH = (maxY - minY) * scale;

          return Positioned(
            left: targetLeft - 8,
            top: targetTop - 8,
            width: targetW + 16,
            height: targetH + 16,
            child: GestureDetector(
              onTap: () => _onBarcodeTapped(barcode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor, width: 3),
                  color: primaryColor.withValues(alpha: 0.25),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Icone Viseur au centre
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Ouvrir",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // B. Cadre de visée manuel déplaçable / redimensionnable
        if (_showManualFrame)
          Positioned(
            left: dx + _cropRect.left * renderW,
            top: dy + _cropRect.top * renderH,
            width: _cropRect.width * renderW,
            height: _cropRect.height * renderH,
            child: _ManualViewfinderFrame(
              primaryColor: primaryColor,
              onDragUpdate: (delta) {
                setState(() {
                  final newLeft = (_cropRect.left + delta.dx / renderW)
                      .clamp(0.0, 1.0 - _cropRect.width);
                  final newTop = (_cropRect.top + delta.dy / renderH)
                      .clamp(0.0, 1.0 - _cropRect.height);
                  _cropRect = Rect.fromLTWH(
                    newLeft,
                    newTop,
                    _cropRect.width,
                    _cropRect.height,
                  );
                });
              },
              onResizeUpdate: (delta, corner) {
                setState(() {
                  double left = _cropRect.left;
                  double top = _cropRect.top;
                  double w = _cropRect.width;
                  double h = _cropRect.height;

                  final dw = delta.dx / renderW;
                  final dh = delta.dy / renderH;

                  if (corner.contains('right')) {
                    w = (w + dw).clamp(0.1, 1.0 - left);
                  }
                  if (corner.contains('left')) {
                    final maxLeft = left + w - 0.1;
                    left = (left + dw).clamp(0.0, maxLeft);
                    w = w - (left - _cropRect.left);
                  }
                  if (corner.contains('bottom')) {
                    h = (h + dh).clamp(0.1, 1.0 - top);
                  }
                  if (corner.contains('top')) {
                    final maxTop = top + h - 0.1;
                    top = (top + dh).clamp(0.0, maxTop);
                    h = h - (top - _cropRect.top);
                  }

                  _cropRect = Rect.fromLTWH(left, top, w, h);
                });
              },
            ),
          ),
      ],
    );
  }
}

/// Composant représentant le cadre de visée caméra manuel avec poignées de redimensionnement
class _ManualViewfinderFrame extends StatelessWidget {
  final Color primaryColor;
  final ValueChanged<Offset> onDragUpdate;
  final Function(Offset delta, String corner) onResizeUpdate;

  const _ManualViewfinderFrame({
    required this.primaryColor,
    required this.onDragUpdate,
    required this.onResizeUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => onDragUpdate(details.delta),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amberAccent, width: 2),
          color: Colors.amberAccent.withValues(alpha: 0.15),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Coins type viseur caméra (HUD brackets)
            Positioned(top: -2, left: -2, child: _buildCorner(true, true)),
            Positioned(top: -2, right: -2, child: _buildCorner(true, false)),
            Positioned(bottom: -2, left: -2, child: _buildCorner(false, true)),
            Positioned(bottom: -2, right: -2, child: _buildCorner(false, false)),

            // Poignée centrale de déplacement
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_with, color: Colors.black, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Cadre de visée",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Poignées de redimensionnement aux 4 coins
            _buildResizeHandle('top_left', Alignment.topLeft),
            _buildResizeHandle('top_right', Alignment.topRight),
            _buildResizeHandle('bottom_left', Alignment.bottomLeft),
            _buildResizeHandle('bottom_right', Alignment.bottomRight),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(bool top, bool left) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: Colors.amberAccent, width: 4)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: Colors.amberAccent, width: 4)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: Colors.amberAccent, width: 4)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: Colors.amberAccent, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildResizeHandle(String corner, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: (details) => onResizeUpdate(details.delta, corner),
        child: Container(
          width: 28,
          height: 28,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.amberAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
