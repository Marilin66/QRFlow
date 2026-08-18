import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Icon } from '../components/icons';
import Viewfinder from '../components/Viewfinder';
import { analyze } from '../lib/analyzer';
import { decodeVideoFrame } from '../lib/decode';
import { useApp } from '../lib/store';

type CamState = 'idle' | 'starting' | 'running' | 'error';

// ── Detection stability ────────────────────────────────────────────────────
// Require the same result on multiple consecutive frames before accepting.
const REQUIRED_CONFIRMATIONS = 3;
const FRAME_INTERVAL_MS = 200; // ~5 fps analysis (balanced performance/accuracy)

export default function Scan() {
  const navigate = useNavigate();
  const { setLastResult } = useApp();
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const rafRef = useRef(0);
  const lastDecodeTime = useRef(0);
  const confirmedValue = useRef<string | null>(null);
  const confirmCount = useRef(0);
  const [state, setState] = useState<CamState>('idle');
  const [error, setError] = useState('');

  const stop = () => {
    cancelAnimationFrame(rafRef.current);
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    confirmedValue.current = null;
    confirmCount.current = 0;
    setState('idle');
  };

  const start = async () => {
    setState('starting');
    setError('');
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false,
      });
      streamRef.current = stream;
      const video = videoRef.current;
      if (!video) throw new Error('no-video');
      video.srcObject = stream;
      await video.play();
      setState('running');
      lastDecodeTime.current = 0;
      confirmedValue.current = null;
      confirmCount.current = 0;
      rafRef.current = requestAnimationFrame(loop);
    } catch (e) {
      const name = e instanceof DOMException ? e.name : '';
      if (name === 'NotAllowedError') {
        setError(
          'Autorisation caméra refusée.\n'
          + 'Activez la caméra pour ce site dans '
          + 'les paramètres de votre navigateur, puis réessayez.',
        );
      } else if (name === 'NotFoundError') {
        setError('Aucune caméra détectée sur cet appareil.');
      } else {
        setError(
          'Impossible d\'accéder à la caméra.\n'
          + 'La caméra exige une connexion sécurisée (HTTPS) ou localhost.',
        );
      }
      setState('error');
    }
  };

  const loop = () => {
    const video = videoRef.current;
    if (!video || video.readyState < 2) {
      rafRef.current = requestAnimationFrame(loop);
      return;
    }

    // ── Frame throttling: don't analyze more than ~5 fps ──
    const now = performance.now();
    if (now - lastDecodeTime.current < FRAME_INTERVAL_MS) {
      rafRef.current = requestAnimationFrame(loop);
      return;
    }
    lastDecodeTime.current = now;

    try {
      const raw = decodeVideoFrame(video);

      if (raw) {
        // ── Multi-frame confirmation ──
        if (raw === confirmedValue.current) {
          confirmCount.current++;
        } else {
          confirmedValue.current = raw;
          confirmCount.current = 1;
        }

        if (confirmCount.current >= REQUIRED_CONFIRMATIONS) {
          // Stable detection confirmed
          setLastResult({
            result: analyze(raw),
            raw,
            method: 'camera',
            fromHistory: false,
          });
          stop();
          navigate('/result');
          return;
        }
      } else {
        // No QR found this frame — reset confirmation counter
        confirmedValue.current = null;
        confirmCount.current = 0;
      }
    } catch {
      // Frame illisible, on continue.
    }

    rafRef.current = requestAnimationFrame(loop);
  };

  useEffect(() => {
    return () => {
      cancelAnimationFrame(rafRef.current);
      streamRef.current?.getTracks().forEach((t) => t.stop());
    };
  }, []);

  return (
    <div className="page-enter space-y-5">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight">Caméra</h1>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          Placez le QR code dans le cadre : la détection est automatique.
        </p>
      </div>

      <Viewfinder
        active={state === 'running'}
        className="aspect-video overflow-hidden rounded-2xl bg-ink-950"
      >
        <video
          ref={videoRef}
          playsInline
          muted
          aria-label="Flux vidéo de la caméra"
          className="size-full object-cover"
        />

        {state === 'running' && (
          <p className="absolute bottom-4 left-0 right-0 flex items-center justify-center gap-1.5 font-mono text-xs uppercase tracking-widest text-laser-400">
            <Icon name="search" className="size-3.5" />
            recherche d'un QR code…
          </p>
        )}

        {state === 'idle' && (
          <div className="absolute inset-0 grid place-items-center">
            <button onClick={() => void start()} className="btn btn-primary inline-flex items-center gap-2">
              <Icon name="camera" className="size-4" />
              Démarrer la caméra
            </button>
          </div>
        )}

        {state === 'starting' && (
          <div className="absolute inset-0 grid place-items-center">
            <div className="size-10 animate-spin rounded-full border-4 border-electric-500 border-t-transparent" />
          </div>
        )}
      </Viewfinder>

      {state === 'error' && (
        <div className="card border-red-300/60 bg-red-500/5 p-5 dark:border-red-900">
          <p className="whitespace-pre-line text-sm leading-relaxed text-red-700 dark:text-red-300">
            {error}
          </p>
          <button
            onClick={() => void start()}
            className="btn btn-danger mt-4"
          >
            Réessayer
          </button>
        </div>
      )}

      {state === 'running' && (
        <button onClick={stop} className="btn btn-ghost w-full inline-flex items-center justify-center gap-2">
          <Icon name="stop" className="size-4" />
          Arrêter la caméra
        </button>
      )}

      <p className="flex items-center justify-center gap-1.5 text-center text-xs text-slate-400 dark:text-slate-500">
        <Icon name="bulb" className="size-3.5" />
        Le flux vidéo est traité localement, image par image. Rien n'est
        envoyé sur Internet.
      </p>
    </div>
  );
}
