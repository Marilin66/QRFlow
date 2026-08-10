export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

export async function shareText(text: string): Promise<boolean> {
  if (navigator.share) {
    try {
      await navigator.share({ text });
      return true;
    } catch {
      return false;
    }
  }
  return copyText(text);
}

/** Ouvre une URL dans un nouvel onglet après confirmation. */
export function openUrl(url: string, message?: string): boolean {
  if (message && !window.confirm(message)) return false;
  window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}

export function formatDateTime(ts: number): string {
  const d = new Date(ts);
  const date = `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
  const time = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  return `${date} à ${time}`;
}
