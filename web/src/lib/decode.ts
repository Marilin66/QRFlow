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

    const results: string[] = [];
    const maxIterations = 15;

    for (let i = 0; i < maxIterations; i++) {
      const imageData = ctx.getImageData(0, 0, w, h);
      const code = jsQR(imageData.data, w, h, { inversionAttempts: 'dontInvert' });
      if (!code || !code.data) break;

      if (!results.includes(code.data)) {
        results.push(code.data);
      }

      // Masquer le QR code détecté (remplissage blanc) pour détecter le suivant
      const loc = code.location;
      const minX = Math.max(0, Math.floor(Math.min(loc.topLeftCorner.x, loc.bottomLeftCorner.x) - 12));
      const maxX = Math.min(w, Math.ceil(Math.max(loc.topRightCorner.x, loc.bottomRightCorner.x) + 12));
      const minY = Math.max(0, Math.floor(Math.min(loc.topLeftCorner.y, loc.topRightCorner.y) - 12));
      const maxY = Math.min(h, Math.ceil(Math.max(loc.bottomLeftCorner.y, loc.bottomRightCorner.y) + 12));

      ctx.fillStyle = '#FFFFFF';
      ctx.fillRect(minX, minY, Math.max(1, maxX - minX), Math.max(1, maxY - minY));
    }

    // Seconde passe (si aucun QR code standard trouvé) pour les QR inversés
    if (results.length === 0) {
      const imageData = ctx.getImageData(0, 0, w, h);
      const code = jsQR(imageData.data, w, h, { inversionAttempts: 'onlyInvert' });
      if (code && code.data && !results.includes(code.data)) {
        results.push(code.data);
      }
    }

    return results;
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
