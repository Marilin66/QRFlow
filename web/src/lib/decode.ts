import jsQR from 'jsqr';

// ── Adaptive scaling constants ─────────────────────────────────────────────
const MIN_EDGE = 400;
const MAX_EDGE = 2400;
// ── Preprocessing pipeline ─────────────────────────────────────────────────
// Each strategy is tried in order; first successful decode wins.

interface DecodeStrategy {
  name: string;
  transform: (ctx: CanvasRenderingContext2D, w: number, h: number) => void;
}

/** Convert to grayscale. */
function toGrayscale(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const gray = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
    d[i] = d[i + 1] = d[i + 2] = gray;
  }
  ctx.putImageData(img, 0, 0);
}

/** Contrast stretch (histogram normalization). */
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

/** Adaptive threshold (Otsu-like simple binarization). */
function adaptiveThreshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  // Build histogram
  const hist = new Uint32Array(256);
  const total = w * h;
  for (let i = 0; i < d.length; i += 4) {
    const gray = Math.round(d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114);
    hist[gray]++;
  }
  // Otsu's method
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

/** Invert colors (white-on-black QR codes). */
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

/** Sharpen via unsharp mask. */
function sharpen(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const img = ctx.getImageData(0, 0, w, h);
  const src = new Uint8ClampedArray(img.data);
  const d = img.data;
  // Simple 3x3 sharpen kernel
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

/** Combined: grayscale + contrast stretch. */
function grayscaleContrast(ctx: CanvasRenderingContext2D, w: number, h: number) {
  toGrayscale(ctx, w, h);
  contrastStretch(ctx, w, h);
}

/** Combined: grayscale + adaptive threshold. */
function grayscaleThreshold(ctx: CanvasRenderingContext2D, w: number, h: number) {
  toGrayscale(ctx, w, h);
  adaptiveThreshold(ctx, w, h);
}

const STRATEGIES: DecodeStrategy[] = [
  // --- Pass 1: Standard attempts ---
  { name: 'raw', transform: () => {} },  // no-op, try raw pixels
  { name: 'inverted', transform: invertColors },
  // --- Pass 2: Preprocessing ---
  { name: 'grayscale', transform: toGrayscale },
  { name: 'grayscale+contrast', transform: grayscaleContrast },
  { name: 'contrast', transform: contrastStretch },
  { name: 'sharpen', transform: sharpen },
  // --- Pass 3: Aggressive ---
  { name: 'grayscale+threshold', transform: grayscaleThreshold },
  { name: 'inverted+grayscale', transform: (ctx, w, h) => { invertColors(ctx, w, h); toGrayscale(ctx, w, h); } },
  { name: 'inverted+contrast', transform: (ctx, w, h) => { invertColors(ctx, w, h); contrastStretch(ctx, w, h); } },
  { name: 'inverted+threshold', transform: (ctx, w, h) => { invertColors(ctx, w, h); adaptiveThreshold(ctx, w, h); } },
];

// ── Adaptive scaling ───────────────────────────────────────────────────────
/** Compute optimal canvas size for QR detection. */
function computeScale(w: number, h: number): number {
  const maxDim = Math.max(w, h);
  // Don't upscale small images, don't downscale large ones too aggressively
  if (maxDim < MIN_EDGE) {
    return MIN_EDGE / maxDim;  // upscale
  }
  if (maxDim > MAX_EDGE) {
    return MAX_EDGE / maxDim;  // downscale
  }
  return 1;
}

// ── Core jsQR wrapper ──────────────────────────────────────────────────────
function tryDecode(
  imageData: ImageData,
  w: number,
  h: number,
): { data: string; version: number } | null {
  // Try with dontInvert first (faster)
  const code1 = jsQR(imageData.data, w, h, { inversionAttempts: 'dontInvert' });
  if (code1?.data) return { data: code1.data, version: code1.version };

  // Try with attemptBoth (handles inverted QR)
  const code2 = jsQR(imageData.data, w, h, { inversionAttempts: 'attemptBoth' });
  if (code2?.data) return { data: code2.data, version: code2.version };

  return null;
}

// ── Image file decoder ─────────────────────────────────────────────────────
/** Decode all QR codes from an imported image file. */
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

    const results: string[] = [];
    const maxIterations = 20;

    for (let i = 0; i < maxIterations; i++) {
      // Try all preprocessing strategies on current state
      const savedData = ctx.getImageData(0, 0, w, h);

      let found = false;
      for (const strategy of STRATEGIES) {
        // Restore original image for each strategy
        ctx.putImageData(savedData, 0, 0);
        strategy.transform(ctx, w, h);

        const imageData = ctx.getImageData(0, 0, w, h);
        const decoded = tryDecode(imageData, w, h);

        if (decoded && !results.includes(decoded.data)) {
          results.push(decoded.data);
          // Restore original, mask the QR, and continue looking
          ctx.putImageData(savedData, 0, 0);
          maskQrRegion(ctx, w, h, decoded.data, savedData);
          found = true;
          break;
        }
      }

      if (!found) break;
    }

    return results;
  } finally {
    bitmap.close();
  }
}

/** Mask the QR region in the canvas to find additional QR codes. */
function maskQrRegion(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  _data: string,
  originalData: ImageData,
): void {
  // Use the raw image to find QR patterns and mask them
  // jsQR gives us location data, but we've lost it after preprocessing
  // Instead, re-scan with dontInvert to get location info
  ctx.putImageData(originalData, 0, 0);
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

// ── Video frame decoder ────────────────────────────────────────────────────
/** Decode a QR code from a live video frame. Optimized for speed. */
export function decodeVideoFrame(video: HTMLVideoElement): string | null {
  if (!video.videoWidth || !video.videoHeight) return null;

  const vw = video.videoWidth;
  const vh = video.videoHeight;

  const canvas = document.createElement('canvas');
  canvas.width = vw;
  canvas.height = vh;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return null;

  ctx.drawImage(video, 0, 0);

  // Strategy 1: Try raw pixels (fastest, works for most QR codes)
  const imageData = ctx.getImageData(0, 0, vw, vh);
  const decoded = tryDecode(imageData, vw, vh);
  if (decoded?.data) return decoded.data;

  // Strategy 2: Try with inversion (for inverted QR codes)
  const img2 = ctx.getImageData(0, 0, vw, vh);
  const d = img2.data;
  for (let i = 0; i < d.length; i += 4) {
    d[i] = 255 - d[i];
    d[i + 1] = 255 - d[i + 1];
    d[i + 2] = 255 - d[i + 2];
  }
  const decoded2 = tryDecode(img2, vw, vh);
  if (decoded2?.data) return decoded2.data;

  // Strategy 3: Grayscale + contrast for challenging lighting
  const img3 = ctx.getImageData(0, 0, vw, vh);
  const d3 = img3.data;
  let min = 255, max = 0;
  for (let i = 0; i < d3.length; i += 4) {
    const gray = d3[i] * 0.299 + d3[i + 1] * 0.587 + d3[i + 2] * 0.114;
    if (gray < min) min = gray;
    if (gray > max) max = gray;
  }
  const range = max - min || 1;
  const scale = 255 / range;
  for (let i = 0; i < d3.length; i += 4) {
    const v = Math.round(((d3[i] * 0.299 + d3[i + 1] * 0.587 + d3[i + 2] * 0.114) - min) * scale);
    d3[i] = d3[i + 1] = d3[i + 2] = v;
  }
  const decoded3 = tryDecode(img3, vw, vh);
  if (decoded3?.data) return decoded3.data;

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
