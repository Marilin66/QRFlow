import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Résultat d'un décodage d'image.
class QrDecodeResult {
  const QrDecodeResult({required this.values, this.formats = const [], this.failed = false});

  /// Contenus bruts décodés (vide si aucun QR détecté).
  final List<String> values;

  /// Formats des codes détectés, dans le même ordre que [values].
  final List<String> formats;

  /// Vrai si l'image n'a pas pu être lue du tout (erreur de décodage).
  final bool failed;
}

/// Décodage de QR codes dans une image statique via Google ML Kit (local,
/// hors-ligne — aucune donnée n'est envoyée sur Internet).
///
/// Stratégie de décodage à multi-passes :
/// 1. Essai avec tous les formats supportés (QR_CODE, AZTEC, DATA_MATRIX,
///    CODE_128, CODE_39, CODE_93, CODABAR, EAN_8, EAN_13, ITF, UPC_A, UPC_E,
///    PDF417).
/// 2. Si aucun résultat : essai avec uniquement les formats 2D (QR, Aztec,
///    DataMatrix, PDF417) — plus de chance de détecter un code 2D dans une
///    image complexe.
/// 3. Si toujours rien : retourne "aucun détecté" (pas d'erreur générique).
class QrDecoder {
  /// Formats 2D principaux — plus de priorité.
  static final List<BarcodeFormat> _formats2D = [
    BarcodeFormat.qrCode,
    BarcodeFormat.aztec,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.pdf417,
  ];

  /// Tous les formats supportés par ML Kit.
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

  /// Convertit un BarcodeFormat ML Kit en nom lisible.
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
        BarcodeFormat.all => 'Tous formats',
        BarcodeFormat.unknown => 'Inconnu',
      };

  Future<QrDecodeResult> decodeImage(String path) async {
    // ── Pass 1 : tous les formats ──
    final QrDecodeResult result = await _decodeWithFormats(_allFormats, path);
    if (result.values.isNotEmpty) return result;

    // ── Pass 2 : formats 2D uniquement (plus de sensibilité) ──
    final QrDecodeResult result2D = await _decodeWithFormats(_formats2D, path);
    if (result2D.values.isNotEmpty) return result2D;

    // ── Pass 3 : tous les formats sans restriction ──
    final BarcodeScanner scanner = BarcodeScanner(formats: _allFormats);
    try {
      final List<Barcode> barcodes =
          await scanner.processImage(InputImage.fromFilePath(path));
      final (List<String>, List<String>) extracted = _extractBarcodes(barcodes);
      return QrDecodeResult(values: extracted.$1, formats: extracted.$2);
    } catch (_) {
      return const QrDecodeResult(values: [], failed: true);
    } finally {
      await scanner.close();
    }
  }

  Future<QrDecodeResult> _decodeWithFormats(
      List<BarcodeFormat> formats, String path) async {
    final BarcodeScanner scanner = BarcodeScanner(formats: formats);
    try {
      final List<Barcode> barcodes =
          await scanner.processImage(InputImage.fromFilePath(path));
      final (List<String>, List<String>) extracted = _extractBarcodes(barcodes);
      return QrDecodeResult(values: extracted.$1, formats: extracted.$2);
    } catch (_) {
      return const QrDecodeResult(values: [], failed: false);
    } finally {
      await scanner.close();
    }
  }

  /// Extrait les valeurs et les formats des barcodes détectés.
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
