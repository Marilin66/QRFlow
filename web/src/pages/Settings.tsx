import { useState } from 'react';
import FinderMark from '../components/FinderMark';
import { clearHistory, pruneHistory } from '../lib/history';
import { useApp } from '../lib/store';

function Toggle({
  checked,
  onChange,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={`relative h-6 w-11 shrink-0 rounded-full transition ${
        checked ? 'bg-electric-500' : 'bg-slate-300 dark:bg-ink-700'
      }`}
    >
      <span
        className={`absolute top-0.5 size-5 rounded-full bg-white shadow transition-all ${
          checked ? 'left-[22px]' : 'left-0.5'
        }`}
      />
    </button>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-2">
      <h2 className="eyebrow">{title}</h2>
      <div className="card divide-y divide-slate-100 dark:divide-ink-800">{children}</div>
    </section>
  );
}

function Row({
  label,
  hint,
  right,
}: {
  label: string;
  hint?: string;
  right?: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-4 px-4 py-3.5">
      <div>
        <p className="text-sm font-semibold">{label}</p>
        {hint && <p className="mt-0.5 text-xs text-slate-400 dark:text-slate-500">{hint}</p>}
      </div>
      {right}
    </div>
  );
}

export default function Settings() {
  const {
    dark,
    setDark,
    confirmActions,
    setConfirmActions,
    warnSuspicious,
    setWarnSuspicious,
    multiQr,
    setMultiQr,
    retentionDays,
    setRetentionDays,
  } = useApp();
  const [historyCount, setHistoryCount] = useState(() => {
    const entries = JSON.parse(localStorage.getItem('qrflow:history') ?? '[]') as unknown[];
    return entries.length;
  });

  const applyRetention = (days: number) => {
    setRetentionDays(days);
    setHistoryCount(pruneHistory(days).length);
  };

  return (
    <div className="page-enter space-y-6">
      <h1 className="font-display text-2xl font-bold tracking-tight">Paramètres</h1>

      <Section title="Apparence">
        <Row
          label="Mode sombre"
          hint="S’applique immédiatement et reste mémorisé."
          right={<Toggle checked={dark} onChange={setDark} />}
        />
      </Section>

      <Section title="Scanner">
        <Row
          label="Confirmation avant action"
          hint="Demander confirmation avant d’ouvrir un lien, appeler, envoyer un SMS…"
          right={<Toggle checked={confirmActions} onChange={setConfirmActions} />}
        />
        <Row
          label="Avertir pour les URL suspectes"
          hint="Signaler les liens risqués (adresses IP, extensions douteuses…)."
          right={<Toggle checked={warnSuspicious} onChange={setWarnSuspicious} />}
        />
        <Row
          label="Détection de plusieurs QR codes"
          hint="Proposer un choix lorsqu’une image contient plusieurs QR codes."
          right={<Toggle checked={multiQr} onChange={setMultiQr} />}
        />
      </Section>

      <Section title="Historique">
        <Row
          label="Durée de conservation"
          hint={`${historyCount} entrée${historyCount > 1 ? 's' : ''} actuellement.`}
          right={
            <select
              value={retentionDays}
              onChange={(e) => applyRetention(Number(e.target.value))}
              className="rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 text-sm dark:border-ink-700 dark:bg-ink-800"
            >
              <option value={30}>30 jours</option>
              <option value={90}>90 jours</option>
              <option value={365}>1 an</option>
              <option value={0}>Illimité</option>
            </select>
          }
        />
        <button
          onClick={() => {
            if (window.confirm('Tout supprimer ? Cette action est irréversible.')) {
              setHistoryCount(clearHistory().length);
            }
          }}
          className="w-full px-4 py-3.5 text-left text-sm font-semibold text-red-600 transition hover:bg-red-500/10 dark:text-red-400"
        >
          Supprimer tout l’historique
        </button>
      </Section>

      <Section title="À propos">
        <Row label="Version" hint="QRFlow web — 0.1.0" />
        <Row
          label="Vie privée"
          hint="Toutes les analyses sont locales. Aucune donnée n’est envoyée sur Internet."
        />
      </Section>

      <div className="flex items-center justify-center gap-2.5 pt-2 text-xs text-slate-400 dark:text-slate-500">
        <FinderMark size={18} className="text-electric-500" />
        <span>
          Le mode « Scanner l’écran » (bulle flottante) vit dans l’application
          Android.
        </span>
      </div>
    </div>
  );
}
