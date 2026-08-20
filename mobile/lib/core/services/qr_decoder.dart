import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

/// Result of a QR decode operation.
class QrDecodeResult {
  const QrDecodeResult({
    required this.values,
    this.formats = const [],
    this.failed = false,
    this.errorMessage,
    this.strategyUsed,
    this.attemptsCount = 0,
  });

  /// Decoded content strings (empty if no QR detected).
  final List<String> values;

  /// Barcode format labels, in the same order as [values].
  final List<String> formats;

  /// True if the image could not be read at all.
  final bool failed;

  /// Detailed error message if [failed] is true.
  final String? errorMessage;

  /// Name of the preprocessing strategy that succeeded (null for raw image).
  final String? strategyUsed;

  /// Number of decode attempts made.
  final int attemptsCount;
}

/// A preprocessing strategy applied to an image before QR decoding.
class _Strategy {
  const _Strategy(this.name, this.transform);

  /// Human-readable name for debugging/logging.
  final String name;

  /// The image transformation function.
  final img.Image Function(img.Image image) transform;
}

/// QR code decoder with a multi-phase preprocessing pipeline.
///
/// Pipeline:
/// 1. FAST PATH — ML Kit on original image (<500ms)
/// 2. SMART PATH — preprocessing strategies on original + upscaled (1–3s)
/// 3. DEEP RECOVERY — aggressive preprocessing + upscaling (3–10s)
///
/// Each phase tries progressively more aggressive transformations.
/// The pipeline stops as soon as a valid result is found.
class QrDecoder {
  // ── Format definitions ──────────────────────────────────────────────────

  static final List<BarcodeFormat> _formats2D = [
    BarcodeFormat.qrCode,
    BarcodeFormat.aztec,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.pdf417,
  ];

  static final List<BarcodeFormat> _allFormats = [
    ..._formats2D,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.codabar,
    BarcodeFormat.ean8,
    BarcodeFormat.ean13,
    BarcodeFormat.itf,
    BarcodeFormat.upca,
    BarcodeFormat.upce,
  ];

  /// Converts a BarcodeFormat enum to a human-readable label.
  static String _formatLabel(BarcodeFormat format) => switch (format) {
        BarcodeFormat.qrCode => 'QR Code',
        BarcodeFormat.aztec => 'Aztec',
        BarcodeFormat.dataMatrix => 'Data Matrix',
        BarcodeFormat.pdf417 => 'PDF417',
        BarcodeFormat.code128 => 'Code 128',
        BarcodeFormat.code39 => 'Code 39',
        BarcodeFormat.code93 => 'Code 93',
        BarcodeFormat.codabar => 'Codabar',
        BarcodeFormat.ean8 => 'EAN-8',
        BarcodeFormat.ean13 => 'EAN-13',
        BarcodeFormat.itf => 'ITF',
        BarcodeFormat.upca => 'UPC-A',
        BarcodeFormat.upce => 'UPC-E',
        _ => 'Code',
      };

  // ── Preprocessing functions ─────────────────────────────────────────────

  static img.Image _toGrayscale(img.Image image) => img.grayscale(image);

  static img.Image _brighten(img.Image image) =>
      img.adjustColor(image, brightness: 1.4);

  static img.Image _invert(img.Image image) => img.invert(image);

  /// Contrast stretch: maps [min, max] intensity to [0, 255].
  static img.Image _contrastStretch(img.Image image) {
    final gray = img.grayscale(image);
    int min = 255, max = 0;
    for (final pixel in gray) {
      final v = pixel.r.toInt();
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = max - min;
    if (range <= 0) return image;
    final scale = 255.0 / range;
    final result = img.Image(width: gray.width, height: gray.height);
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final v = gray.getPixel(x, y).r.toInt();
        final stretched = ((v - min) * scale).round().clamp(0, 255);
        result.setPixelRgba(x, y, stretched, stretched, stretched, 255);
      }
    }
    return result;
  }

  static img.Image _gaussianBlur3(img.Image image) =>
      img.gaussianBlur(image, radius: 1);

  static img.Image _gaussianBlur5(img.Image image) =>
      img.gaussianBlur(image, radius: 2);

  /// Unsharp mask: original + 1.5 × (original − blurred).
  static img.Image _unsharpMask(img.Image image) {
    final blurred = img.gaussianBlur(image, radius: 1);
    final result = img.Image.from(image);
    for (final pixel in result) {
      final blurredPixel = blurred.getPixel(pixel.x, pixel.y);
      final dr = (pixel.r - blurredPixel.r) * 1.5;
      final dg = (pixel.g - blurredPixel.g) * 1.5;
      final db = (pixel.b - blurredPixel.b) * 1.5;
      pixel
        ..r = (pixel.r + dr).clamp(0, 255).toInt()
        ..g = (pixel.g + dg).clamp(0, 255).toInt()
        ..b = (pixel.b + db).clamp(0, 255).toInt();
    }
    return result;
  }

  /// Strong sharpening kernel for very blurry QR codes.
  static img.Image _sharpenStrong(img.Image image) {
    return img.convolution(
      image,
      filter: [0, -2, 0, -2, 13, -2, 0, -2, 0],
      div: 1,
    );
  }

  /// Otsu's adaptive threshold: produces a clean binary image.
  static img.Image _adaptiveThreshold(img.Image image) {
    final gray = img.grayscale(image);
    final hist = List<int>.filled(256, 0);
    final total = gray.width * gray.height;
    for (final pixel in gray) {
      hist[pixel.r.toInt()]++;
    }
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * hist[i];
    }
    double sumB = 0;
    int wB = 0;
    double maxVariance = 0;
    int threshold = 128;
    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final variance = wB * wF * (mB - mF) * (mB - mF);
      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = t;
      }
    }
    final result = img.Image(width: gray.width, height: gray.height);
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final v = gray.getPixel(x, y).r.toInt();
        final val = v > threshold ? 255 : 0;
        result.setPixelRgba(x, y, val, val, val, 255);
      }
    }
    return result;
  }

  // ── Upscaling ───────────────────────────────────────────────────────────

  /// Upscale using nearest-neighbor to preserve QR module edges.
  static img.Image _upscale2x(img.Image image) => img.copyResize(
        image,
        width: image.width * 2,
        height: image.height * 2,
        interpolation: img.Interpolation.nearest,
      );

  static img.Image _upscale3x(img.Image image) => img.copyResize(
        image,
        width: image.width * 3,
        height: image.height * 3,
        interpolation: img.Interpolation.nearest,
      );

  static img.Image _upscale4x(img.Image image) => img.copyResize(
        image,
        width: image.width * 4,
        height: image.height * 4,
        interpolation: img.Interpolation.nearest,
      );

  /// Returns an upscaled version if the image is too small for reliable QR
  /// decoding, or null if the image is already large enough.
  static img.Image? _upscaleIfNeeded(img.Image image) {
    final int minDim =
        image.width < image.height ? image.width : image.height;
    if (minDim >= 400) return null; // Already large enough
    if (minDim < 150) return _upscale4x(image);
    if (minDim < 250) return _upscale3x(image);
    return _upscale2x(image);
  }

  // ── Strategy lists ──────────────────────────────────────────────────────

  /// Phase 2: most effective strategies, tried first on original image.
  static final List<_Strategy> _smartStrategies = [
    const _Strategy('contrast', _contrastStretch),
    _Strategy('grayscale+contrast',
        (img.Image i) => _contrastStretch(_toGrayscale(i))),
    _Strategy(
        'blur3+contrast', (img.Image i) => _contrastStretch(_gaussianBlur3(i))),
    _Strategy(
        'blur5+contrast', (img.Image i) => _contrastStretch(_gaussianBlur5(i))),
    _Strategy('unsharp+contrast',
        (img.Image i) => _contrastStretch(_unsharpMask(i))),
    _Strategy('sharpenStrong+contrast',
        (img.Image i) => _contrastStretch(_sharpenStrong(i))),
    const _Strategy('threshold', _adaptiveThreshold),
    _Strategy(
        'invert+contrast', (img.Image i) => _contrastStretch(_invert(i))),
    _Strategy(
        'invert+threshold', (img.Image i) => _adaptiveThreshold(_invert(i))),
    _Strategy(
        'brighten+contrast', (img.Image i) => _contrastStretch(_brighten(i))),
  ];

  /// Phase 3: aggressive strategies for difficult images.
  static final List<_Strategy> _deepStrategies = [
    _Strategy('blur5+threshold',
        (img.Image i) => _adaptiveThreshold(_gaussianBlur5(i))),
    _Strategy('gray+blur5+threshold',
        (img.Image i) => _adaptiveThreshold(_gaussianBlur5(_toGrayscale(i)))),
    _Strategy('invert+blur3+contrast',
        (img.Image i) => _contrastStretch(_gaussianBlur3(_invert(i)))),
    _Strategy('invert+unsharp+contrast',
        (img.Image i) => _contrastStretch(_unsharpMask(_invert(i)))),
    _Strategy('blur3+threshold',
        (img.Image i) => _adaptiveThreshold(_gaussianBlur3(i))),
    _Strategy('contrastStretch+threshold',
        (img.Image i) => _adaptiveThreshold(_contrastStretch(i))),
    _Strategy('sharpenStrong+blur3+contrast',
        (img.Image i) => _contrastStretch(_gaussianBlur3(_sharpenStrong(i)))),
  ];

  /// Strategies applied to upscaled images (small QR codes).
  static final List<_Strategy> _upscaleStrategies = [
    _Strategy('upscale2x+contrast',
        (img.Image i) => _contrastStretch(_upscale2x(i))),
    _Strategy('upscale3x+contrast',
        (img.Image i) => _contrastStretch(_upscale3x(i))),
    _Strategy('upscale2x+threshold',
        (img.Image i) => _adaptiveThreshold(_upscale2x(i))),
    _Strategy('upscale3x+threshold',
        (img.Image i) => _adaptiveThreshold(_upscale3x(i))),
    _Strategy('upscale2x+sharpen',
        (img.Image i) => _contrastStretch(_unsharpMask(_upscale2x(i)))),
    _Strategy('upscale3x+sharpen',
        (img.Image i) => _contrastStretch(_unsharpMask(_upscale3x(i)))),
  ];

  // ── Pipeline ────────────────────────────────────────────────────────────

  /// Decodes QR codes from an image file.
  ///
  /// Uses a progressive pipeline:
  /// 1. Fast path: ML Kit on original image
  /// 2. Smart path: preprocessing + upscaling
  /// 3. Deep recovery: aggressive preprocessing combinations
  Future<QrDecodeResult> decodeImage(String path) async {
    // Read and decode the image
    final File file = File(path);
    final Uint8List originalBytes = await file.readAsBytes();
    final img.Image? originalImage = img.decodeImage(originalBytes);
    if (originalImage == null) {
      return const QrDecodeResult(
        values: [],
        failed: true,
        errorMessage: 'Impossible de décoder le fichier image.',
      );
    }

    int attempts = 0;

    // ── Phase 1: Fast path — ML Kit on original image ──
    try {
      final BarcodeScanner scanner = BarcodeScanner(formats: _allFormats);
      try {
        final List<Barcode> barcodes =
            await scanner.processImage(InputImage.fromFilePath(path));
        final (List<String>, List<String>) extracted =
            _extractBarcodes(barcodes);
        if (extracted.$1.isNotEmpty) {
          return QrDecodeResult(
            values: extracted.$1,
            formats: extracted.$2,
            strategyUsed: 'raw',
            attemptsCount: ++attempts,
          );
        }
      } finally {
        await scanner.close();
      }

      // Also try with 2D-only formats (faster, catches edge cases)
      final BarcodeScanner scanner2D = BarcodeScanner(formats: _formats2D);
      try {
        final List<Barcode> barcodes2D =
            await scanner2D.processImage(InputImage.fromFilePath(path));
        final (List<String>, List<String>) extracted2D =
            _extractBarcodes(barcodes2D);
        if (extracted2D.$1.isNotEmpty) {
          return QrDecodeResult(
            values: extracted2D.$1,
            formats: extracted2D.$2,
            strategyUsed: 'raw-2d',
            attemptsCount: ++attempts,
          );
        }
      } finally {
        await scanner2D.close();
      }
    } on Exception catch (e) {
      return QrDecodeResult(
        values: [],
        failed: true,
        errorMessage: e.toString(),
      );
    }

    // ── Phase 2: Smart path — preprocessing on original image ──
    for (final _Strategy strategy in _smartStrategies) {
      attempts++;
      final result = await _tryStrategy(path, originalImage, strategy);
      if (result != null) {
        return QrDecodeResult(
          values: result.$1,
          formats: result.$2,
          strategyUsed: strategy.name,
          attemptsCount: attempts,
        );
      }
    }

    // ── Phase 2b: Upscale if small + try upscale strategies ──
    final img.Image? upscaled = _upscaleIfNeeded(originalImage);
    if (upscaled != null) {
      for (final _Strategy strategy in _upscaleStrategies) {
        attempts++;
        final result = await _tryStrategy(path, upscaled, strategy);
        if (result != null) {
          return QrDecodeResult(
            values: result.$1,
            formats: result.$2,
            strategyUsed: strategy.name,
            attemptsCount: attempts,
          );
        }
      }
    }

    // ── Phase 3: Deep recovery — aggressive preprocessing ──
    for (final _Strategy strategy in _deepStrategies) {
      attempts++;
      final result = await _tryStrategy(path, originalImage, strategy);
      if (result != null) {
        return QrDecodeResult(
          values: result.$1,
          formats: result.$2,
          strategyUsed: strategy.name,
          attemptsCount: attempts,
        );
      }
    }

    // ── Phase 3b: Upscaled + deep strategies ──
    if (upscaled != null) {
      for (final _Strategy strategy in _deepStrategies) {
        attempts++;
        final result = await _tryStrategy(path, upscaled, strategy);
        if (result != null) {
          return QrDecodeResult(
            values: result.$1,
            formats: result.$2,
            strategyUsed: strategy.name,
            attemptsCount: attempts,
          );
        }
      }
    }

    // Aucun QR détecté avec toutes les stratégies
    return QrDecodeResult(values: [], attemptsCount: attempts);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Applies a preprocessing strategy and attempts to decode with ML Kit.
  /// Returns the extracted barcodes if any were found, null otherwise.
  Future<(List<String>, List<String>)?> _tryStrategy(
    String basePath,
    img.Image baseImage,
    _Strategy strategy,
  ) async {
    try {
      final img.Image processed =
          strategy.transform(img.Image.from(baseImage));
      final Uint8List processedBytes = Uint8List.fromList(
        img.encodePng(processed, level: 0), // level 0 = no compression = fastest
      );

      final String safeName = strategy.name.replaceAll('+', '_');
      final String tempPath = '${basePath}_preprocessed_$safeName.png';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(processedBytes);

      try {
        final BarcodeScanner scanner = BarcodeScanner(formats: _allFormats);
        try {
          final List<Barcode> barcodes =
              await scanner.processImage(InputImage.fromFilePath(tempPath));
          final (List<String>, List<String>) extracted =
              _extractBarcodes(barcodes);
          if (extracted.$1.isNotEmpty) return extracted;
        } finally {
          await scanner.close();
        }
      } finally {
        await tempFile.delete();
      }
    } catch (_) {
      // Strategy failed, continue to next
    }
    return null;
  }

  /// Extracts values and format labels from detected barcodes.
  (List<String>, List<String>) _extractBarcodes(List<Barcode> barcodes) {
    final List<String> values = [];
    final List<String> formats = [];
    for (final Barcode b in barcodes) {
      final String? v = b.rawValue ?? b.displayValue;
      if (v != null && v.trim().isNotEmpty && !values.contains(v)) {
        values.add(v.trim());
        formats.add(_formatLabel(b.format));
      }
    }
    return (values, formats);
  }
}
