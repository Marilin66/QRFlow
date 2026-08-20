import jsQR from 'jsqr';

// ── Adaptive scaling constants ─────────────────────────────────────────────
const MIN_EDGE = 400;
const MAX_EDGE = 2400;

// ── BarcodeDetector detection ──────────────────────────────────────────────
// BarcodeDetector API uses Google's native ML Kit under the hood.
// Supported in Chrome 83+, Edge 83+, Safari 17+.
// Falls back to jsQR when unavailable (Firefox, older browsers).

const barcodeDetectorSupported = typeof BarcodeDetector !== 'undefined';

let barcodeDetector: BarcodeDetector | null = null;
if (barcodeDetectorSupported) {
  try {
    barcodeDetector = new BarcodeDetector({
      formats: [
        'qr_code', 'aztec', 'data_matrix', 'pdf417',
        'code_128', 'code_39', 'code_93', 'codabar',
        'ean_8', 'ean_13', 'itf', 'upc_a', 'upc_e',
      ],
    });
  } catch {
    barcodeDetector = null;
  }
}

// ── Preprocessing helpers ──────────────────────────────────────────────────

function toGrayscale(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const gray = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
    d[i] = d[i + 1] = d[i + 2] = gray;
  }
  ctx.putImageData(img, 0, 0);
}

function contrastStretch(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  let min = 255;
  let max = 0;
  for (let i = 0; i < d.length; i += 4) {
    const gray = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
    if (gray < min) min = gray;
    if (gray > max) max = gray;
  }
  const range = max - min || 1;
  const scale = 255 / range;
  for (let i = 0; i < d.length; i += 4) {
    const v = Math.round(((d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114) - min) * scale);
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
}

function adaptiveThreshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  const hist = new Uint32Array(256);
  const total = w * h;
  for (let i = 0; i < d.length; i += 4) {
    const gray = Math.round(d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114);
    hist[gray]++;
  }
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * hist[i];
  let sumB = 0;
  let wB = 0;
  let maxVariance = 0;
  let threshold = 128;
  for (let t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB === 0) continue;
    const wF = total - wB;
    if (wF === 0) break;
    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const variance = wB * wF * (mB - mF) * (mB - mF);
    if (variance > maxVariance) {
      maxVariance = variance;
      threshold = t;
    }
  }
  for (let i = 0; i < d.length; i += 4) {
    const gray = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
    const v = gray > threshold ? 255 : 0;
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
}

function invertColors(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    d[i] = 255 - d[i];
    d[i + 1] = 255 - d[i + 1];
    d[i + 2] = 255 - d[i + 2];
  }
  ctx.putImageData(img, 0, 0);
}

function sharpen(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const src = new Uint8ClampedArray(img.data);
  const d = img.data;
  const kernel = [0, -1, 0, -1, 5, -1, 0, -1, 0];
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      for (let c = 0; c < 3; c++) {
        let val = 0;
        for (let ky = -1; ky <= 1; ky++) {
          for (let kx = -1; kx <= 1; kx++) {
            val += src[((y + ky) * w + (x + kx)) * 4 + c] * kernel[(ky + 1) * 3 + (kx + 1)];
          }
        }
        d[(y * w + x) * 4 + c] = Math.max(0, Math.min(255, val));
      }
    }
  }
  ctx.putImageData(img, 0, 0);
}

// ── Gaussian blur (3×3 kernel) — réduit le moiré des écrans ──────────────
function gaussianBlur(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const src = new Uint8ClampedArray(img.data);
  const d = img.data;
  // Noyau gaussien 3×3 normalisé
  const k = [1, 2, 1, 2, 4, 2, 1, 2, 1];
  const kSum = 16;
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      for (let c = 0; c < 3; c++) {
        let val = 0;
        for (let ky = -1; ky <= 1; ky++) {
          for (let kx = -1; kx <= 1; kx++) {
            val += src[((y + ky) * w + (x + kx)) * 4 + c] * k[(ky + 1) * 3 + (kx + 1)];
          }
        }
        d[(y * w + x) * 4 + c] = Math.round(val / kSum);
      }
    }
  }
  ctx.putImageData(img, 0, 0);
}

// ── Gaussian blur 5×5 pour moiré plus fort ────────────────────────────────
function gaussianBlur5(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const src = new Uint8ClampedArray(img.data);
  const d = img.data;
  // Noyau gaussien 5×5 (sigma ≈ 1.4)
  const k = [
    1,  4,  6,  4, 1,
    4, 16, 24, 16, 4,
    6, 24, 36, 24, 6,
    4, 16, 24, 16, 4,
    1,  4,  6,  4, 1,
  ];
  const kSum = 256;
  for (let y = 2; y < h - 2; y++) {
    for (let x = 2; x < w - 2; x++) {
      for (let c = 0; c < 3; c++) {
        let val = 0;
        for (let ky = -2; ky <= 2; ky++) {
          for (let kx = -2; kx <= 2; kx++) {
            val += src[((y + ky) * w + (x + kx)) * 4 + c] * k[(ky + 2) * 5 + (kx + 2)];
          }
        }
        d[(y * w + x) * 4 + c] = Math.round(val / kSum);
      }
    }
  }
  ctx.putImageData(img, 0, 0);
}

// ── Ajustement de luminosité (+/- 40) ─────────────────────────────────────
function brightnessUp(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    d[i] = Math.min(255, d[i] + 40);
    d[i + 1] = Math.min(255, d[i + 1] + 40);
    d[i + 2] = Math.min(255, d[i + 2] + 40);
  }
  ctx.putImageData(img, 0, 0);
}



// ── Unsharp mask (netteté améliorée, plus contrôlée que sharpen) ──────────
function unsharpMask(ctx: CanvasRenderingContext2D, w: number, h: number) {
  // 1. Créer la version floue
  const blurred = ctx.getImageData(0, 0, w, h);
  const src = new Uint8ClampedArray(blurred.data);
  const bd = blurred.data;
  const k = [1, 2, 1, 2, 4, 2, 1, 2, 1];
  const kSum = 16;
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      for (let c = 0; c < 3; c++) {
        let val = 0;
        for (let ky = -1; ky <= 1; ky++) {
          for (let kx = -1; kx <= 1; kx++) {
            val += src[((y + ky) * w + (x + kx)) * 4 + c] * k[(ky + 1) * 3 + (kx + 1)];
          }
        }
        bd[(y * w + x) * 4 + c] = Math.round(val / kSum);
      }
    }
  }
  // 2. Original + amount * (original - blurred)  → amount = 1.5
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    for (let c = 0; c < 3; c++) {
      const diff = d[i + c] - bd[i + c];
      d[i + c] = Math.max(0, Math.min(255, Math.round(d[i + c] + 1.5 * diff)));
    }
  }
  ctx.putImageData(img, 0, 0);
}

// ── Netteté aggressive (pour QR très flous) ───────────────────────────────
function sharpenStrong(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const src = new Uint8ClampedArray(img.data);
  const d = img.data;
  const kernel = [0, -2, 0, -2, 13, -2, 0, -2, 0];
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      for (let c = 0; c < 3; c++) {
        let val = 0;
        for (let ky = -1; ky <= 1; ky++) {
          for (let kx = -1; kx <= 1; kx++) {
            val += src[((y + ky) * w + (x + kx)) * 4 + c] * kernel[(ky + 1) * 3 + (kx + 1)];
          }
        }
        d[(y * w + x) * 4 + c] = Math.max(0, Math.min(255, val));
      }
    }
  }
  ctx.putImageData(img, 0, 0);
}

function grayscaleContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  toGrayscale(ctx, w, h);
  contrastStretch(ctx, w, h);
}

function grayscaleThreshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  toGrayscale(ctx, w, h);
  adaptiveThreshold(ctx, w, h);
}

// ── Compositions spécifiques écran ─────────────────────────────────────────

/** Flou léger + contraste : réduit le moiré puis maximise les bords QR */
function blurContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  gaussianBlur(ctx, w, h);
  contrastStretch(ctx, w, h);
}

/** Flou + seuillage : flou pour moiré, puis binaire net */
function blurThreshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  gaussianBlur(ctx, w, h);
  adaptiveThreshold(ctx, w, h);
}

/** Flou 5×5 + contraste : moiré plus agressif + contraste */
function blur5Contrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  gaussianBlur5(ctx, w, h);
  contrastStretch(ctx, w, h);
}

/** Flou 5×5 + seuillage binaire */
function blur5Threshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  gaussianBlur5(ctx, w, h);
  adaptiveThreshold(ctx, w, h);
}

/** Luminosité + contraste : écran trop sombre ou trop clair */
function brightContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  brightnessUp(ctx, w, h);
  contrastStretch(ctx, w, h);
}

/** Netteté + contraste :QR flou mais contraste correct */
function sharpenContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  unsharpMask(ctx, w, h);
  contrastStretch(ctx, w, h);
}

/** Netteté forte + contraste : QR très flou */
function sharpenStrongContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  sharpenStrong(ctx, w, h);
  contrastStretch(ctx, w, h);
}

/** Inversé + flou + contraste : QR à fond sombre sur écran */
function invertBlurContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  invertColors(ctx, w, h);
  gaussianBlur(ctx, w, h);
  contrastStretch(ctx, w, h);
}

/** Inversé + flou + seuillage */
function invertBlurThreshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  invertColors(ctx, w, h);
  gaussianBlur(ctx, w, h);
  adaptiveThreshold(ctx, w, h);
}

/** Noir et blanc + flou 5×5 + seuillage : anti-moiré maximal */
function grayBlur5Threshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  toGrayscale(ctx, w, h);
  gaussianBlur5(ctx, w, h);
  adaptiveThreshold(ctx, w, h);
}

// ── Preprocessing strategy list ────────────────────────────────────────────

interface DecodeStrategy {
  name: string;
  transform: (ctx: CanvasRenderingContext2D, w: number, h: number) => void;
}

const STRATEGIES: DecodeStrategy[] = [
  // ── Pass 1-2 : brut + inversé (vérification rapide) ──
  { name: 'raw', transform: () => {} },
  { name: 'inverted', transform: invertColors },

  // ── Pass 3-6 : niveaux de gris + ajustements ──
  { name: 'grayscale', transform: toGrayscale },
  { name: 'grayscale+contrast', transform: grayscaleContrast },
  { name: 'contrast', transform: contrastStretch },
  { name: 'brightness+contrast', transform: brightContrast },

  // ── Pass 7-8 : netteté ──
  { name: 'sharpen', transform: sharpen },
  { name: 'sharpen+contrast', transform: sharpenContrast },
  { name: 'sharpenStrong+contrast', transform: sharpenStrongContrast },

  // ── Pass 9-10 : flou anti-moiré (écrans) ──
  { name: 'blur+contrast', transform: blurContrast },
  { name: 'blur+threshold', transform: blurThreshold },

  // ── Pass 11-12 : flou 5×5 plus agressif ──
  { name: 'blur5+contrast', transform: blur5Contrast },
  { name: 'blur5+threshold', transform: blur5Threshold },

  // ── Pass 13 : noir et blanc + flou + seuillage ──
  { name: 'grayBlur5+threshold', transform: grayBlur5Threshold },

  // ── Pass 14-15 : seuillage binaire ──
  { name: 'grayscale+threshold', transform: grayscaleThreshold },
  { name: 'sharpen+threshold', transform: (ctx, w, h) => { sharpen(ctx, w, h); adaptiveThreshold(ctx, w, h); } },

  // ── Pass 16-19 : combinaisons inversées (QR à fond sombre) ──
  { name: 'inverted+grayscale', transform: (ctx, w, h) => { invertColors(ctx, w, h); toGrayscale(ctx, w, h); } },
  { name: 'inverted+contrast', transform: (ctx, w, h) => { invertColors(ctx, w, h); contrastStretch(ctx, w, h); } },
  { name: 'inverted+threshold', transform: (ctx, w, h) => { invertColors(ctx, w, h); adaptiveThreshold(ctx, w, h); } },
  { name: 'inverted+blur+contrast', transform: invertBlurContrast },
  { name: 'inverted+blur+threshold', transform: invertBlurThreshold },

  // ── Pass 20 : inversion + netteté + contraste ──
  { name: 'inverted+sharpen+contrast', transform: (ctx, w, h) => { invertColors(ctx, w, h); unsharpMask(ctx, w, h); contrastStretch(ctx, w, h); } },
];

// ── Adaptive scaling ───────────────────────────────────────────────────────
function computeScale(w: number, h: number): number {
  const maxDim = Math.max(w, h);
  if (maxDim < MIN_EDGE) return MIN_EDGE / maxDim;
  if (maxDim > MAX_EDGE) return MAX_EDGE / maxDim;
  return 1;
}

// ── Shared: BarcodeDetector multi-QR detection ────────────────────────────
async function detectWithBarcodeDetector(
  canvas: HTMLCanvasElement,
): Promise<string[]> {
  if (!barcodeDetector) return [];

  const results: string[] = [];

  for (let i = 0; i < 15; i++) {
    try {
      const result = await barcodeDetector.detect(canvas);
      const found = result.barcodes;
      if (found.length === 0) break;

      for (const barcode of found) {
        if (barcode.rawValue && !results.includes(barcode.rawValue)) {
          results.push(barcode.rawValue);
        }
      }

      if (results.length === 0) break;

      // Mask detected regions to find additional codes
      const ctx = canvas.getContext('2d');
      if (!ctx) break;

      let maskedAnything = false;
      for (const barcode of found) {
        if (barcode.boundingBox) {
          const bb = barcode.boundingBox;
          const padding = 12;
          ctx.fillStyle = '#FFFFFF';
          ctx.fillRect(
            Math.max(0, bb.x - padding),
            Math.max(0, bb.y - padding),
            Math.min(canvas.width, bb.width + padding * 2),
            Math.min(canvas.height, bb.height + padding * 2),
          );
          maskedAnything = true;
        }
      }

      if (!maskedAnything) break;
      // Check if the masked image has any new barcodes
      const newResult = await barcodeDetector.detect(canvas);
      if (newResult.barcodes.length === 0) break;
    } catch {
      break;
    }
  }

  return results;
}

// ── Shared: jsQR single-attempt detection ──────────────────────────────────
function jsQRDetect(
  imageData: ImageData,
  w: number,
  h: number,
): string | null {
  const code1 = jsQR(imageData.data, w, h, { inversionAttempts: 'dontInvert' });
  if (code1?.data) return code1.data;

  const code2 = jsQR(imageData.data, w, h, { inversionAttempts: 'attemptBoth' });
  if (code2?.data) return code2.data;

  return null;
}

// ── Shared: jsQR multi-QR detection with preprocessing ─────────────────────
async function detectWithJsQR(
  canvas: HTMLCanvasElement,
  w: number,
  h: number,
): Promise<string[]> {
  const results: string[] = [];
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return results;

  for (let i = 0; i < 15; i++) {
    const savedData = ctx.getImageData(0, 0, w, h);
    let found = false;

    for (const strategy of STRATEGIES) {
      ctx.putImageData(savedData, 0, 0);
      strategy.transform(ctx, w, h);

      const imageData = ctx.getImageData(0, 0, w, h);
      const value = jsQRDetect(imageData, w, h);

      if (value && !results.includes(value)) {
        results.push(value);
        // Mask the found QR region for next iteration
        ctx.putImageData(savedData, 0, 0);
        maskQrRegion(ctx, w, h);
        found = true;
        break;
      }
    }

    if (!found) break;
  }

  return results;
}

/** Mask the QR region in the canvas to find additional codes in next iteration. */
function maskQrRegion(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
): void {
  const imageData = ctx.getImageData(0, 0, w, h);
  const code = jsQR(imageData.data, w, h, { inversionAttempts: 'dontInvert' });

  if (code?.location) {
    const loc = code.location;
    const padding = 12;
    const minX = Math.max(0, Math.floor(Math.min(loc.topLeftCorner.x, loc.bottomLeftCorner.x) - padding));
    const maxX = Math.min(w, Math.ceil(Math.max(loc.topRightCorner.x, loc.bottomRightCorner.x) + padding));
    const minY = Math.max(0, Math.floor(Math.min(loc.topLeftCorner.y, loc.topRightCorner.y) - padding));
    const maxY = Math.min(h, Math.ceil(Math.max(loc.bottomLeftCorner.y, loc.bottomRightCorner.y) + padding));

    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(minX, minY, Math.max(1, maxX - minX), Math.max(1, maxY - minY));
  }
}

// ── BarcodeDetector with preprocessing combos ─────────────────────────────
// Tries BarcodeDetector (native ML Kit) with various image preprocessing
// strategies. Significantly improves detection on difficult images.
async function tryBarcodeDetectorWithPreprocessing(
  canvas: HTMLCanvasElement,
  w: number,
  h: number,
  originalPixels: ImageData,
): Promise<string[]> {
  if (!barcodeDetector) return [];
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return [];

  const combos: (() => void)[] = [
    () => { toGrayscale(ctx, w, h); contrastStretch(ctx, w, h); },
    () => { gaussianBlur(ctx, w, h); contrastStretch(ctx, w, h); },
    () => { unsharpMask(ctx, w, h); contrastStretch(ctx, w, h); },
    () => { adaptiveThreshold(ctx, w, h); },
    () => { invertColors(ctx, w, h); },
    () => { invertColors(ctx, w, h); contrastStretch(ctx, w, h); },
    () => { gaussianBlur5(ctx, w, h); contrastStretch(ctx, w, h); },
    () => { sharpenStrong(ctx, w, h); contrastStretch(ctx, w, h); },
    () => { invertColors(ctx, w, h); gaussianBlur(ctx, w, h); contrastStretch(ctx, w, h); },
  ];

  for (const combo of combos) {
    ctx.putImageData(originalPixels, 0, 0);
    combo();
    try {
      const result = await barcodeDetector.detect(canvas);
      if (result.barcodes.length > 0 && result.barcodes[0].rawValue) {
        return [result.barcodes[0].rawValue];
      }
    } catch {}
  }

  return [];
}

// ── Image file decoder ─────────────────────────────────────────────────────
export async function decodeImageFile(file: File): Promise<string[]> {
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    throw new ImageDecodeError('load', 'Impossible de charger cette image. Le fichier semble corrompu ou dans un format non supporté.');
  }

  try {
    const scale = computeScale(bitmap.width, bitmap.height);
    const w = Math.max(1, Math.round(bitmap.width * scale));
    const h = Math.max(1, Math.round(bitmap.height * scale));

    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) throw new ImageDecodeError('canvas', 'Impossible de créer le contexte de rendu.');

    ctx.drawImage(bitmap, 0, 0, w, h);

    // ── Phase 1: BarcodeDetector on raw image (fastest, most robust) ──
    if (barcodeDetector) {
      const bdResults = await detectWithBarcodeDetector(canvas);
      if (bdResults.length > 0) return bdResults;
    }

    // ── Phase 2: jsQR with preprocessing ──
    const ctx2 = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx2) return [];
    const originalPixels = ctx2.getImageData(0, 0, w, h);

    const jsQRResults = await detectWithJsQR(canvas, w, h);
    if (jsQRResults.length > 0) return jsQRResults;

    // ── Phase 3: BarcodeDetector with preprocessing combos ──
    const bdPreprocessed = await tryBarcodeDetectorWithPreprocessing(canvas, w, h, originalPixels);
    if (bdPreprocessed.length > 0) return bdPreprocessed;

    // ── Phase 4: jsQR on blur+contrast (moiré-optimized) ──
    ctx2.putImageData(originalPixels, 0, 0);
    gaussianBlur(ctx2, w, h);
    contrastStretch(ctx2, w, h);

    const imageData5 = ctx2.getImageData(0, 0, w, h);
    const lastChance5 = jsQRDetect(imageData5, w, h);
    if (lastChance5) return [lastChance5];

    // ── Phase 5: jsQR on sharp+contrast ──
    ctx2.putImageData(originalPixels, 0, 0);
    unsharpMask(ctx2, w, h);
    contrastStretch(ctx2, w, h);

    const imageData6 = ctx2.getImageData(0, 0, w, h);
    const lastChance6 = jsQRDetect(imageData6, w, h);
    if (lastChance6) return [lastChance6];

    return [];
  } finally {
    bitmap.close();
  }
}

// ── Video frame decoder (async — uses BarcodeDetector) ─────────────────────
/**
 * Decode a code from a live video frame.
 * Uses BarcodeDetector (native, fast) as primary engine,
 * falls back to jsQR with preprocessing if unavailable.
 *
 * NOTE: This function is async because BarcodeDetector.detect() is async.
 * The caller must await it.
 */
export async function decodeVideoFrame(video: HTMLVideoElement): Promise<string | null> {
  if (!video.videoWidth || !video.videoHeight) return null;

  const vw = video.videoWidth;
  const vh = video.videoHeight;

  const canvas = document.createElement('canvas');
  canvas.width = vw;
  canvas.height = vh;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return null;

  ctx.drawImage(video, 0, 0);

  // ── Strategy 1: BarcodeDetector (native, fastest, most formats) ──
  if (barcodeDetector) {
    try {
      const result = await barcodeDetector.detect(canvas);
      if (result.barcodes.length > 0 && result.barcodes[0].rawValue) {
        return result.barcodes[0].rawValue;
      }
    } catch {
      // BarcodeDetector failed, fall through to jsQR
    }
  }

  // ── Save original pixels for preprocessing strategies ──
  const originalPixels = ctx.getImageData(0, 0, vw, vh);

  // ── Strategy 2-7: jsQR with preprocessing strategies (subset for speed) ──
  // Pour la vidéo, on utilise un sous-ensemble des stratégies pour maintenir
  // la fluidité. Les stratégies les plus efficaces pour les écrans en premier.
  const videoStrategies = STRATEGIES.slice(0, 8); // raw, inverted, gray, gray+contrast, contrast, bright+contrast, sharpen, sharpen+contrast

  for (const strategy of videoStrategies) {
    ctx.putImageData(originalPixels, 0, 0);
    strategy.transform(ctx, vw, vh);

    const imageData = ctx.getImageData(0, 0, vw, vh);
    const value = jsQRDetect(imageData, vw, vh);
    if (value) return value;
  }

  // ── Strategy 8: Blur + contrast (moiré-optimized for screens) ──
  ctx.putImageData(originalPixels, 0, 0);
  gaussianBlur(ctx, vw, vh);
  contrastStretch(ctx, vw, vh);

  const imgDataBlur = ctx.getImageData(0, 0, vw, vh);
  const decodedBlur = jsQRDetect(imgDataBlur, vw, vh);
  if (decodedBlur) return decodedBlur;

  // ── Strategy 9: Blur 5×5 + threshold (heavy moiré) ──
  ctx.putImageData(originalPixels, 0, 0);
  gaussianBlur5(ctx, vw, vh);
  adaptiveThreshold(ctx, vw, vh);

  const imgDataBlur5 = ctx.getImageData(0, 0, vw, vh);
  const decodedBlur5 = jsQRDetect(imgDataBlur5, vw, vh);
  if (decodedBlur5) return decodedBlur5;

  // ── Strategy 10: BarcodeDetector on grayscale+contrast ──
  if (barcodeDetector) {
    try {
      ctx.putImageData(originalPixels, 0, 0);
      toGrayscale(ctx, vw, vh);
      contrastStretch(ctx, vw, vh);
      const result2 = await barcodeDetector.detect(canvas);
      if (result2.barcodes.length > 0 && result2.barcodes[0].rawValue) {
        return result2.barcodes[0].rawValue;
      }
    } catch {
      // Fall through
    }
  }

  // ── Strategy 11: BarcodeDetector on blur+contrast ──
  if (barcodeDetector) {
    try {
      ctx.putImageData(originalPixels, 0, 0);
      gaussianBlur(ctx, vw, vh);
      contrastStretch(ctx, vw, vh);
      const result3 = await barcodeDetector.detect(canvas);
      if (result3.barcodes.length > 0 && result3.barcodes[0].rawValue) {
        return result3.barcodes[0].rawValue;
      }
    } catch {
      // Fall through
    }
  }

  // ── Strategy 12: BarcodeDetector on sharpen+contrast ──
  if (barcodeDetector) {
    try {
      ctx.putImageData(originalPixels, 0, 0);
      unsharpMask(ctx, vw, vh);
      contrastStretch(ctx, vw, vh);
      const result4 = await barcodeDetector.detect(canvas);
      if (result4.barcodes.length > 0 && result4.barcodes[0].rawValue) {
        return result4.barcodes[0].rawValue;
      }
    } catch {}
  }

  // ── Strategy 13: BarcodeDetector on threshold ──
  if (barcodeDetector) {
    try {
      ctx.putImageData(originalPixels, 0, 0);
      adaptiveThreshold(ctx, vw, vh);
      const result5 = await barcodeDetector.detect(canvas);
      if (result5.barcodes.length > 0 && result5.barcodes[0].rawValue) {
        return result5.barcodes[0].rawValue;
      }
    } catch {}
  }

  // ── Strategy 14: BarcodeDetector on inverted+contrast ──
  if (barcodeDetector) {
    try {
      ctx.putImageData(originalPixels, 0, 0);
      invertColors(ctx, vw, vh);
      contrastStretch(ctx, vw, vh);
      const result6 = await barcodeDetector.detect(canvas);
      if (result6.barcodes.length > 0 && result6.barcodes[0].rawValue) {
        return result6.barcodes[0].rawValue;
      }
    } catch {}
  }

  // ── Strategy 15: BarcodeDetector on blur5+contrast ──
  if (barcodeDetector) {
    try {
      ctx.putImageData(originalPixels, 0, 0);
      gaussianBlur5(ctx, vw, vh);
      contrastStretch(ctx, vw, vh);
      const result7 = await barcodeDetector.detect(canvas);
      if (result7.barcodes.length > 0 && result7.barcodes[0].rawValue) {
        return result7.barcodes[0].rawValue;
      }
    } catch {}
  }

  // ── Strategy 16: BarcodeDetector on sharpenStrong+contrast ──
  if (barcodeDetector) {
    try {
      ctx.putImageData(originalPixels, 0, 0);
      sharpenStrong(ctx, vw, vh);
      contrastStretch(ctx, vw, vh);
      const result8 = await barcodeDetector.detect(canvas);
      if (result8.barcodes.length > 0 && result8.barcodes[0].rawValue) {
        return result8.barcodes[0].rawValue;
      }
    } catch {}
  }

  // ── Strategy 17: Inverted + blur + contrast (dark QR on screen) ──
  ctx.putImageData(originalPixels, 0, 0);
  invertColors(ctx, vw, vh);
  gaussianBlur(ctx, vw, vh);
  contrastStretch(ctx, vw, vh);

  const imgDataInvBlur = ctx.getImageData(0, 0, vw, vh);
  const decodedInvBlur = jsQRDetect(imgDataInvBlur, vw, vh);
  if (decodedInvBlur) return decodedInvBlur;

  return null;
}

// ── Custom error type ──────────────────────────────────────────────────────
export type ImageDecodeErrorPhase = 'load' | 'canvas' | 'decode';

export class ImageDecodeError extends Error {
  phase: ImageDecodeErrorPhase;
  constructor(phase: ImageDecodeErrorPhase, message: string) {
    super(message);
    this.name = 'ImageDecodeError';
    this.phase = phase;
  }
}
