import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Résultat d'un décodage d'image.
class QrDecodeResult {
  const QrDecodeResult({required this.values, this.failed = false});

  /// Contenus bruts décodés (vide si aucun QR détecté).
  final List<String> values;

  /// Vrai si l'image n'a pas pu être lue du tout (erreur de décodage).
  final bool failed;
}

/// Décodage de QR codes dans une image statique via Google ML Kit (local,
/// hors-ligne — aucune donnée n'est envoyée sur Internet).
class QrDecoder {
  Future<QrDecodeResult> decodeImage(String path) async {
    // Le scanner est créé à chaque appel : une fois fermé (close), il ne peut
    // plus être réutilisé — un champ partagé casserait les décodages suivants.
    final BarcodeScanner scanner = BarcodeScanner();
    try {
      final List<Barcode> barcodes =
          await scanner.processImage(InputImage.fromFilePath(path));
      final List<String> values = [];
      for (final Barcode b in barcodes) {
        final String? v = b.rawValue ?? b.displayValue;
        if (v != null && v.trim().isNotEmpty && !values.contains(v)) {
          values.add(v.trim());
        }
      }
      return QrDecodeResult(values: values);
    } catch (_) {
      return const QrDecodeResult(values: [], failed: true);
    } finally {
      await scanner.close();
    }
  }
}
