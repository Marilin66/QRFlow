import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Résultat d'un décodage d'image.
class QrDecodeResult {
  const QrDecodeResult({required this.values, this.formats = const [], this.failed = false, this.errorMessage});

  /// Contenus bruts décodés (vide si aucun QR détecté).
  final List<String> values;

  /// Formats des codes détectés, dans le même ordre que [values].
  final List<String> formats;

  /// Vrai si l'image n'a pas pu être lue du tout (erreur de décodage).
  final bool failed;

  /// Message d'erreur détaillé si [failed] est vrai.
  final String? errorMessage;
}

/// Décodage de QR codes dans une image statique via Google ML Kit (local,
/// hors-ligne — aucune donnée n'est envoyée sur Internet).
///
/// Stratégie de décodage :
/// 1. Essai avec tous les formats supportés en UN SEUL passage.
/// 2. Si aucun résultat : essai avec uniquement les formats 2D.
/// 3. Si toujours rien : retourne "aucun détecté" (pas d'erreur générique).
class QrDecoder {
  /// Formats 2D principaux.
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
        _ => 'Code',
      };

  Future<QrDecodeResult> decodeImage(String path) async {
    // ── Un seul scanner, un seul passage avec tous les formats ──
    final BarcodeScanner scanner = BarcodeScanner(formats: _allFormats);
    try {
      final List<Barcode> barcodes =
          await scanner.processImage(InputImage.fromFilePath(path));

      final (List<String>, List<String>) extracted = _extractBarcodes(barcodes);
      if (extracted.$1.isNotEmpty) {
        return QrDecodeResult(values: extracted.$1, formats: extracted.$2);
      }

      // ── Pass 2 : formats 2D uniquement (plus de sensibilité) ──
      final BarcodeScanner scanner2D = BarcodeScanner(formats: _formats2D);
      try {
        final List<Barcode> barcodes2D =
            await scanner2D.processImage(InputImage.fromFilePath(path));
        final (List<String>, List<String>) extracted2D = _extractBarcodes(barcodes2D);
        return QrDecodeResult(values: extracted2D.$1, formats: extracted2D.$2);
      } finally {
        await scanner2D.close();
      }
    } on Exception catch (e) {
      // Erreur réelle (fichier corrompu, permission refusée, etc.)
      return QrDecodeResult(
        values: [],
        failed: true,
        errorMessage: e.toString(),
      );
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
