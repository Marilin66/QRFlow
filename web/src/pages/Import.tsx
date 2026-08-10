import { useCallback, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import QrBadge from '../components/QrBadge';
import { analyze } from '../lib/analyzer';
import { decodeImageFile } from '../lib/decode';
import { useApp } from '../lib/store';

type Phase = 'idle' | 'analyzing' | 'multiple' | 'error';

export default function Import() {
  const navigate = useNavigate();
  const { setLastResult, multiQr } = useApp();
  const inputRef = useRef<HTMLInputElement>(null);
  const [phase, setPhase] = useState<Phase>('idle');
  const [values, setValues] = useState<string[]>([]);
  const [error, setError] = useState('');
  const [dragging, setDragging] = useState(false);

  const handleFile = useCallback(
    async (file: File) => {
      if (!file.type.startsWith('image/')) {
        setPhase('error');
        setError('Ce fichier n’est pas une image. Choisissez un fichier JPG, PNG ou WEBP.');
        return;
      }
      setPhase('analyzing');
      try {
        const decoded = await decodeImageFile(file);
        if (decoded.length === 0) {
          setPhase('error');
          setError(
            'Aucun QR code détecté.\n'
            + 'Essayez de recadrer l’image ou utilisez une image où le QR code est plus visible.',
          );
          return;
        }
        if (decoded.length === 1 || !multiQr) {
          openResult(decoded[0]);
          return;
        }
        setValues(decoded);
        setPhase('multiple');
      } catch {
        setPhase('error');
        setError('Impossible de lire cette image. Vérifiez son format.');
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [multiQr],
  );

  function openResult(raw: string) {
    setLastResult({ result: analyze(raw), raw, method: 'screenshot', fromHistory: false });
    navigate('/result');
  }

  return (
    <div className="page-enter space-y-5">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight">Depuis une capture</h1>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          Importez une capture d’écran ou une image contenant un QR code.
        </p>
      </div>

      {phase === 'analyzing' ? (
        <div className="relative flex flex-col items-center gap-4 overflow-hidden rounded-2xl border border-electric-500/40 bg-ink-950 py-20 dark:bg-ink-900">
          <span className="scanline" />
          <div className="size-10 animate-spin rounded-full border-4 border-electric-500 border-t-transparent" />
          <p className="font-mono text-xs uppercase tracking-widest text-laser-400">
            analyse de l’image…
          </p>
        </div>
      ) : phase === 'error' ? (
        <div className="card border-red-300/60 bg-red-500/5 p-6 dark:border-red-900">
          <div className="text-3xl">😕</div>
          <p className="mt-2 whitespace-pre-line text-sm leading-relaxed text-red-700 dark:text-red-300">
            {error}
          </p>
          <button onClick={() => setPhase('idle')} className="btn btn-danger mt-4">
            Réessayer
          </button>
        </div>
      ) : phase === 'multiple' ? (
        <div className="space-y-2">
          <p className="text-sm font-semibold">
            Plusieurs QR codes détectés — choisissez celui à consulter :
          </p>
          {values.map((raw, i) => {
            const result = analyze(raw);
            return (
              <button
                key={i}
                onClick={() => openResult(raw)}
                className="card flex w-full items-center gap-3 p-4 text-left transition hover:border-electric-400 hover:shadow"
              >
                <QrBadge type={result.type} />
                <span className="ml-auto max-w-44 truncate font-mono text-xs text-slate-500 dark:text-slate-400">
                  {result.summary}
                </span>
              </button>
            );
          })}
        </div>
      ) : (
        <div
          className={`flex min-h-64 flex-col items-center justify-center gap-3 rounded-2xl border-2 border-dashed bg-white p-8 text-center transition dark:bg-ink-900 ${
            dragging
              ? 'border-electric-500 bg-electric-500/5'
              : 'border-slate-300 dark:border-ink-700'
          }`}
          onDragOver={(e) => {
            e.preventDefault();
            setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDragging(false);
            const file = e.dataTransfer.files?.[0];
            if (file) void handleFile(file);
          }}
          onClick={() => inputRef.current?.click()}
          role="button"
          tabIndex={0}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') inputRef.current?.click();
          }}
        >
          <div className="grid size-16 place-items-center rounded-2xl bg-electric-500/10 text-3xl">
            🖼️
          </div>
          <p className="font-display text-lg font-bold">
            Glissez votre image ici
          </p>
          <p className="text-sm text-slate-500 dark:text-slate-400">
            ou cliquez pour choisir un fichier — JPG, PNG, WEBP
          </p>
          <span className="mt-2 text-xs text-slate-400 dark:text-slate-500">
            Capture d’écran, photo, export…
          </span>
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) void handleFile(file);
              e.target.value = '';
            }}
          />
        </div>
      )}

      <p className="text-center text-xs text-slate-400 dark:text-slate-500">
        🔒 L’analyse est 100 % locale : l’image n’est jamais envoyée sur Internet.
      </p>
    </div>
  );
}
