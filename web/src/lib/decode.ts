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

function grayscaleContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  toGrayscale(ctx, w, h);
  contrastStretch(ctx, w, h);
}

function grayscaleThreshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  toGrayscale(ctx, w, h);
  adaptiveThreshold(ctx, w, h);
}

// ── Preprocessing strategy list ────────────────────────────────────────────

interface DecodeStrategy {
  name: string;
  transform: (ctx: CanvasRenderingContext2D, w: number, h: number) => void;
}

const STRATEGIES: DecodeStrategy[] = [
  { name: 'raw', transform: () => {} },
  { name: 'inverted', transform: invertColors },
  { name: 'grayscale', transform: toGrayscale },
  { name: 'grayscale+contrast', transform: grayscaleContrast },
  { name: 'contrast', transform: contrastStretch },
  { name: 'sharpen', transform: sharpen },
  { name: 'grayscale+threshold', transform: grayscaleThreshold },
  { name: 'inverted+grayscale', transform: (ctx, w, h) => { invertColors(ctx, w, h); toGrayscale(ctx, w, h); } },
  { name: 'inverted+contrast', transform: (ctx, w, h) => { invertColors(ctx, w, h); contrastStretch(ctx, w, h); } },
  { name: 'inverted+threshold', transform: (ctx, w, h) => { invertColors(ctx, w, h); adaptiveThreshold(ctx, w, h); } },
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
    // Save the original pixels so Phase 3 can start fresh
    const ctx2 = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx2) return [];
    const originalPixels = ctx2.getImageData(0, 0, w, h);

    const jsQRResults = await detectWithJsQR(canvas, w, h);
    if (jsQRResults.length > 0) return jsQRResults;

    // ── Phase 3: BarcodeDetector on preprocessed image ──
    // Restore canvas to original before preprocessing
    ctx2.putImageData(originalPixels, 0, 0);
    toGrayscale(ctx2, w, h);
    contrastStretch(ctx2, w, h);

    if (barcodeDetector) {
      const bdResults2 = await detectWithBarcodeDetector(canvas);
      if (bdResults2.length > 0) return bdResults2;
    }

    // ── Phase 4: jsQR on preprocessed image ──
    const imageData = ctx2.getImageData(0, 0, w, h);
    const lastChance = jsQRDetect(imageData, w, h);
    if (lastChance) return [lastChance];

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

  // ── Strategy 2: jsQR raw ──
  const decoded = jsQRDetect(originalPixels, vw, vh);
  if (decoded) return decoded;

  // ── Strategy 3: Inverted ──
  const img2 = ctx.getImageData(0, 0, vw, vh);
  const d2 = img2.data;
  for (let i = 0; i < d2.length; i += 4) {
    d2[i] = 255 - d2[i];
    d2[i + 1] = 255 - d2[i + 1];
    d2[i + 2] = 255 - d2[i + 2];
  }
  const decoded2 = jsQRDetect(img2, vw, vh);
  if (decoded2) return decoded2;

  // ── Strategy 4: Grayscale + contrast ──
  const img3 = ctx.getImageData(0, 0, vw, vh);
  const d3 = img3.data;
  let min = 255, max = 0;
  for (let i = 0; i < d3.length; i += 4) {
    const gray = d3[i] * 0.299 + d3[i + 1] * 0.587 + d3[i + 2] * 0.114;
    if (gray < min) min = gray;
    if (gray > max) max = gray;
  }
  const range = max - min || 1;
  const scaleVal = 255 / range;
  for (let i = 0; i < d3.length; i += 4) {
    const v = Math.round(((d3[i] * 0.299 + d3[i + 1] * 0.587 + d3[i + 2] * 0.114) - min) * scaleVal);
    d3[i] = d3[i + 1] = d3[i + 2] = v;
  }
  const decoded3 = jsQRDetect(img3, vw, vh);
  if (decoded3) return decoded3;

  // ── Strategy 5: Adaptive threshold (Otsu) ──
  const img4 = new ImageData(
    new Uint8ClampedArray(originalPixels.data),
    vw, vh,
  );
  const d4 = img4.data;
  const hist = new Uint32Array(256);
  const total = vw * vh;
  for (let i = 0; i < d4.length; i += 4) {
    const gray = Math.round(d4[i] * 0.299 + d4[i + 1] * 0.587 + d4[i + 2] * 0.114);
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
  for (let i = 0; i < d4.length; i += 4) {
    const gray = d4[i] * 0.299 + d4[i + 1] * 0.587 + d4[i + 2] * 0.114;
    const v = gray > threshold ? 255 : 0;
    d4[i] = d4[i + 1] = d4[i + 2] = v;
  }
  const decoded4 = jsQRDetect(img4, vw, vh);
  if (decoded4) return decoded4;

  // ── Strategy 6: BarcodeDetector on grayscale+contrast ──
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
