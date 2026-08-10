import type { ScanMethod } from './types';

export interface HistoryEntry {
  id: number;
  ts: number;
  type: string;
  raw: string;
  summary: string;
  method: ScanMethod;
  action?: string;
}

const KEY = 'qrflow:history';
const MAX_ENTRIES = 500;

export function loadHistory(): HistoryEntry[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as HistoryEntry[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function save(entries: HistoryEntry[]): HistoryEntry[] {
  localStorage.setItem(KEY, JSON.stringify(entries.slice(0, MAX_ENTRIES)));
  return entries.slice(0, MAX_ENTRIES);
}

export function addHistory(
  entry: Omit<HistoryEntry, 'id'>,
): HistoryEntry[] {
  const entries = loadHistory();
  const id = Date.now();
  const next = [{ ...entry, id }, ...entries];
  return save(next);
}

export function deleteHistory(id: number): HistoryEntry[] {
  return save(loadHistory().filter((e) => e.id !== id));
}

export function clearHistory(): HistoryEntry[] {
  localStorage.removeItem(KEY);
  return [];
}

export function updateActionHistory(id: number, action: string): HistoryEntry[] {
  const entries = loadHistory();
  const index = entries.findIndex((e) => e.id === id);
  if (index >= 0) {
    entries[index] = { ...entries[index], action };
  }
  return save(entries);
}

export function pruneHistory(olderThanDays: number): HistoryEntry[] {
  if (olderThanDays <= 0) return loadHistory();
  const limit = Date.now() - olderThanDays * 24 * 60 * 60 * 1000;
  return save(loadHistory().filter((e) => e.ts >= limit));
}
