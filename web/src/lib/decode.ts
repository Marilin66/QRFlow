import jsQR from 'jsqr';

const MAX_EDGE = 1600;

/** Décode tous les QR codes d'un fichier image importé. */
export async function decodeImageFile(file: File): Promise<string[]> {
  const bitmap = await createImageBitmap(file);
  try {
    const scale = Math.min(1, MAX_EDGE / Math.max(bitmap.width, bitmap.height));
    const w = Math.max(1, Math.round(bitmap.width * scale));
    const h = Math.max(1, Math.round(bitmap.height * scale));

    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) return [];
    ctx.drawImage(bitmap, 0, 0, w, h);

    const { data } = ctx.getImageData(0, 0, w, h);
    const code = jsQR(data, w, h);
    return code && code.data ? [code.data] : [];
  } finally {
    bitmap.close();
  }
}

/** Tente de décoder une frame vidéo (utilisé par le scan caméra). */
export function decodeVideoFrame(video: HTMLVideoElement): string | null {
  if (!video.videoWidth) return null;
  const canvas = document.createElement('canvas');
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return null;
  ctx.drawImage(video, 0, 0);
  const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const code = jsQR(data, canvas.width, canvas.height);
  return code && code.data ? code.data : null;
}
