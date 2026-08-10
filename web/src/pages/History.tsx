import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { formatDateTime } from '../lib/actions';
import { analyze } from '../lib/analyzer';
import { clearHistory, deleteHistory, loadHistory } from '../lib/history';
import { useApp } from '../lib/store';
import { TYPE_META } from '../lib/types';

export default function History() {
  const navigate = useNavigate();
  const { setLastResult } = useApp();
  const [entries, setEntries] = useState(loadHistory);
  const [query, setQuery] = useState('');

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return entries;
    return entries.filter(
      (e) =>
        e.type.toLowerCase().includes(q) ||
        e.raw.toLowerCase().includes(q) ||
        e.summary.toLowerCase().includes(q),
    );
  }, [entries, query]);

  const openEntry = (raw: string, method: (typeof entries)[number]['method']) => {
    setLastResult({ result: analyze(raw), raw, method, fromHistory: true });
    navigate('/result');
  };

  const clearAll = () => {
    if (window.confirm('Tout supprimer ? Cette action est irréversible.')) {
      setEntries(clearHistory());
    }
  };

  return (
    <div className="page-enter space-y-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-2xl font-bold tracking-tight">Historique</h1>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            {entries.length > 0
              ? `${entries.length} analyse${entries.length > 1 ? 's' : ''} enregistrée${entries.length > 1 ? 's' : ''} sur cet appareil`
              : 'Vos analyses restent sur cet appareil.'}
          </p>
        </div>
        <button
          onClick={clearAll}
          disabled={entries.length === 0}
          className="rounded-lg px-3 py-1.5 text-sm font-semibold text-red-600 transition hover:bg-red-500/10 disabled:opacity-40 dark:text-red-400"
        >
          Tout supprimer
        </button>
      </div>

      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Rechercher dans l’historique…"
        className="w-full rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm outline-none transition focus:border-electric-500 dark:border-ink-800 dark:bg-ink-900"
      />

      {filtered.length === 0 ? (
        <div className="py-16 text-center">
          <div className="mx-auto grid size-16 place-items-center rounded-2xl bg-electric-500/10 text-3xl">
            ◷
          </div>
          <p className="mt-3 text-slate-500 dark:text-slate-400">
            {query
              ? 'Aucun résultat pour cette recherche.'
              : 'Aucune analyse pour le moment. Lancez un scan !'}
          </p>
        </div>
      ) : (
        <ul className="space-y-2">
          {filtered.map((entry) => {
            const emoji = TYPE_META[entry.type as keyof typeof TYPE_META]?.emoji ?? '❓';
            return (
              <li
                key={entry.id}
                className="card group flex items-center gap-3 p-3.5 transition hover:border-electric-400 hover:shadow"
              >
                <button
                  onClick={() => openEntry(entry.raw, entry.method)}
                  className="flex min-w-0 flex-1 items-center gap-3 text-left"
                >
                  <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-electric-500/10 text-xl">
                    {emoji}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold">
                      {entry.summary}
                    </span>
                    <span className="mt-0.5 block truncate font-mono text-[11px] text-slate-400 dark:text-slate-500">
                      {formatDateTime(entry.ts)} • {entry.type}
                      {entry.action ? ` • ${entry.action}` : ''}
                    </span>
                  </span>
                </button>
                <button
                  onClick={() => setEntries(deleteHistory(entry.id))}
                  className="rounded-lg p-2 text-slate-400 transition hover:bg-red-500/10 hover:text-red-600 focus-visible:opacity-100 sm:opacity-0 sm:group-hover:opacity-100 dark:hover:bg-red-950/40"
                  aria-label="Supprimer"
                  title="Supprimer"
                >
                  🗑️
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
