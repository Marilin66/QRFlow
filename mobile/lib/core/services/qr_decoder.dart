import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

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

/// Stratégie de prétraitement d'image pour améliorer la détection de QR codes.
class _Strategy {
  const _Strategy(this.name, this.transform);
  final String name;
  final img.Image Function(img.Image image) transform;
}

/// Décodage de QR codes dans une image statique via Google ML Kit (local,
/// hors-ligne — aucune donnée n'est envoyée sur Internet).
///
/// Stratégie de décodage multi-pass :
/// 1. Image originale (pas de traitement) — rapide.
/// 2. Niveaux de gris + contraste — améliore les images ternes.
/// 3. Flou gaussien + contraste — réduit le moiré des écrans.
/// 4. Netteté (unsharp mask) + contraste — améliore les images floues.
/// 5. Flou 5×5 + seuillage — moiré agressif.
/// 6. Inversé + contraste — QR à fond sombre.
/// 7. Inversé + flou + contraste — QR inversé sur écran.
/// 8. Seuillage adaptatif (Otsu) — image binaire nette.
/// 9. Noir et blanc + flou + seuillage — anti-moiré maximal.
/// 10. Netteté forte + contraste — QR très flou.
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
        _ => 'Code',
      };

  /// Stratégies de prétraitement, de la plus rapide à la plus agressive.
  /// Chaque stratégie essaie d'améliorer l'image pour un scénario différent.
  static final List<_Strategy> _strategies = [
    // ── Pass 1 : image originale (vérification rapide) ──
    const _Strategy('raw', _noTransform),

    // ── Pass 2-3 : niveaux de gris + ajustements ──
    _Strategy('grayscale+contrast', (img.Image i) {
      return _contrastStretch(_toGrayscale(i));
    }),
    _Strategy('contrast', _contrastStretch),

    // ── Pass 4-5 : flou anti-moiré (écrans) ──
    _Strategy('blur3+contrast', (img.Image i) {
      return _contrastStretch(_gaussianBlur3(i));
    }),
    _Strategy('blur5+contrast', (img.Image i) {
      return _contrastStretch(_gaussianBlur5(i));
    }),

    // ── Pass 6-7 : netteté ──
    _Strategy('unsharp+contrast', (img.Image i) {
      return _contrastStretch(_unsharpMask(i));
    }),
    _Strategy('sharpenStrong+contrast', (img.Image i) {
      return _contrastStretch(_sharpenStrong(i));
    }),

    // ── Pass 8 : luminosité + contraste ──
    _Strategy('brighten+contrast', (img.Image i) {
      return _contrastStretch(_brighten(i));
    }),

    // ── Pass 9 : flou 5×5 + seuillage ──
    _Strategy('blur5+threshold', (img.Image i) {
      return _adaptiveThreshold(_gaussianBlur5(i));
    }),

    // ── Pass 10 : noir et blanc + flou + seuillage (anti-moiré max) ──
    _Strategy('gray+blur5+threshold', (img.Image i) {
      return _adaptiveThreshold(_gaussianBlur5(_toGrayscale(i)));
    }),

    // ── Pass 11 : seuillage adaptatif ──
    _Strategy('threshold', _adaptiveThreshold),

    // ── Pass 12-14 : inversés (QR à fond sombre) ──
    _Strategy('invert+contrast', (img.Image i) {
      return _contrastStretch(_invert(i));
    }),
    _Strategy('invert+blur3+contrast', (img.Image i) {
      return _contrastStretch(_gaussianBlur3(_invert(i)));
    }),
    _Strategy('invert+threshold', (img.Image i) {
      return _adaptiveThreshold(_invert(i));
    }),

    // ── Pass 15 : inversion + netteté + contraste ──
    _Strategy('invert+unsharp+contrast', (img.Image i) {
      return _contrastStretch(_unsharpMask(_invert(i)));
    }),

    // ── Pass 16 : flou léger + seuillage (moiré intermédiaire) ──
    _Strategy('blur3+threshold', (img.Image i) {
      return _adaptiveThreshold(_gaussianBlur3(i));
    }),

    // ── Pass 17 : contraste agressif ──
    _Strategy('contrastStretch+threshold', (img.Image i) {
      return _adaptiveThreshold(_contrastStretch(i));
    }),

    // ── Pass 18 : nette agressif + flou (anti-moiré léger + bords nets) ──
    _Strategy('sharpenStrong+blur3+contrast', (img.Image i) {
      return _contrastStretch(_gaussianBlur3(_sharpenStrong(i)));
    }),
  ];

  /// Aucune transformation — image originale.
  static img.Image _noTransform(img.Image image) => image;

  // ── Transformations de base ─────────────────────────────────────────────

  /// Conversion en niveaux de gris.
  static img.Image _toGrayscale(img.Image image) {
    return img.grayscale(image);
  }

  /// Ajustement de luminosité (multiplier 1.4×).
  static img.Image _brighten(img.Image image) {
    return img.adjustColor(image, brightness: 1.4);
  }

  /// Inversion des couleurs (QR à fond sombre).
  static img.Image _invert(img.Image image) {
    return img.invert(image);
  }

  /// Extension de contraste (min-max) : maximise la plage dynamique.
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
    // Étirement min-max : mapper [min, max] vers [0, 255]
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

  /// Flou gaussien 3×3 : réduit le moiré des écrans.
  static img.Image _gaussianBlur3(img.Image image) {
    return img.gaussianBlur(image, radius: 1);
  }

  /// Flou gaussien 5×5 : moiré plus agressif.
  static img.Image _gaussianBlur5(img.Image image) {
    return img.gaussianBlur(image, radius: 2);
  }

  /// Netteté améliorée (unsharp mask) : améliore les bords sans excess de bruit.
  /// Original + 1.5 × (original - flou)
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

  /// Netteté forte : pour QR très flous.
  static img.Image _sharpenStrong(img.Image image) {
    return img.convolution(
      image,
      filter: [0, -2, 0, -2, 13, -2, 0, -2, 0],
      div: 1,
    );
  }

  /// Seuillage adaptatif (méthode d'Otsu) : image binaire nette.
  static img.Image _adaptiveThreshold(img.Image image) {
    final gray = img.grayscale(image);
    // Histogramme
    final hist = List<int>.filled(256, 0);
    final total = gray.width * gray.height;
    for (final pixel in gray) {
      hist[pixel.r.toInt()]++;
    }
    // Calcul du seuil optimal (Otsu)
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
    // Appliquer le seuillage
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

  // ── Pipeline principal ──────────────────────────────────────────────────

  Future<QrDecodeResult> decodeImage(String path) async {
    // Lire l'image originale en bytes
    final File file = File(path);
    final Uint8List originalBytes = await file.readAsBytes();

    // Décoder l'image originale pour le prétraitement
    final img.Image? originalImage = img.decodeImage(originalBytes);
    if (originalImage == null) {
      return QrDecodeResult(
        values: [],
        failed: true,
        errorMessage: 'Impossible de décoder le fichier image.',
      );
    }

    // ── Pass 1 : image originale via ML Kit (rapide) ──
    final BarcodeScanner scanner = BarcodeScanner(formats: _allFormats);
    try {
      final List<Barcode> barcodes =
          await scanner.processImage(InputImage.fromFilePath(path));
      final (List<String>, List<String>) extracted = _extractBarcodes(barcodes);
      if (extracted.$1.isNotEmpty) {
        return QrDecodeResult(values: extracted.$1, formats: extracted.$2);
      }

      // ── Pass 2 : formats 2D uniquement sur image originale ──
      final BarcodeScanner scanner2D = BarcodeScanner(formats: _formats2D);
      try {
        final List<Barcode> barcodes2D =
            await scanner2D.processImage(InputImage.fromFilePath(path));
        final (List<String>, List<String>) extracted2D = _extractBarcodes(barcodes2D);
        if (extracted2D.$1.isNotEmpty) {
          return QrDecodeResult(values: extracted2D.$1, formats: extracted2D.$2);
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
    } finally {
      await scanner.close();
    }

    // ── Pass 3+ : essais avec prétraitement croissant ──
    // On applique chaque stratégie et on passe le résultat à ML Kit.
    // On garde un scanner réutilisé pour la performance.
    final BarcodeScanner retryScanner = BarcodeScanner(formats: _allFormats);
    try {
      for (int s = 1; s < _strategies.length; s++) {
        final strategy = _strategies[s];
        try {
          final img.Image processed = strategy.transform(img.Image.from(originalImage));
          final Uint8List processedBytes = Uint8List.fromList(
            img.encodePng(processed, level: 0), // level 0 = pas de compression = plus rapide
          );

          // Écrire dans un fichier temporaire pour ML Kit
          final String tempPath = '${path}_preprocessed_$s.png';
          final File tempFile = File(tempPath);
          await tempFile.writeAsBytes(processedBytes);

          try {
            final BarcodeScanner preScanner = BarcodeScanner(formats: _allFormats);
            try {
              final List<Barcode> barcodes =
                  await preScanner.processImage(InputImage.fromFilePath(tempPath));
              final (List<String>, List<String>) extracted = _extractBarcodes(barcodes);
              if (extracted.$1.isNotEmpty) {
                // Nettoyage du fichier temp
                await tempFile.delete();
                return QrDecodeResult(values: extracted.$1, formats: extracted.$2);
              }

              // Aussi essayer avec formats 2D uniquement
              final BarcodeScanner preScanner2D = BarcodeScanner(formats: _formats2D);
              try {
                final List<Barcode> barcodes2D =
                    await preScanner2D.processImage(InputImage.fromFilePath(tempPath));
                final (List<String>, List<String>) extracted2D =
                    _extractBarcodes(barcodes2D);
                if (extracted2D.$1.isNotEmpty) {
                  await tempFile.delete();
                  return QrDecodeResult(values: extracted2D.$1, formats: extracted2D.$2);
                }
              } finally {
                await preScanner2D.close();
              }
            } finally {
              await preScanner.close();
            }
          } finally {
            await tempFile.delete();
          }
        } catch (_) {
          // Cette stratégie a échoué, on passe à la suivante
          continue;
        }
      }
    } finally {
      await retryScanner.close();
    }

    // Aucun QR détecté avec toutes les stratégies
    return const QrDecodeResult(values: []);
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
