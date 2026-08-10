import { TYPE_META, type QrContentType } from '../lib/types';

export default function QrBadge({ type }: { type: QrContentType }) {
  const meta = TYPE_META[type];
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-blue-100 px-3 py-1 text-sm font-semibold text-blue-700 dark:bg-blue-950 dark:text-blue-300">
      <span aria-hidden>{meta.emoji}</span>
      {meta.label}
    </span>
  );
}

export function TypeEmoji({ type, className }: { type: QrContentType; className?: string }) {
  return (
    <span className={className} aria-hidden>
      {TYPE_META[type].emoji}
    </span>
  );
}
