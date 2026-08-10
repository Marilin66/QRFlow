import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import type { QrResult, ScanMethod } from './types';

interface StoredResult {
  result: QrResult;
  raw: string;
  method: ScanMethod;
  fromHistory: boolean;
}

interface AppContextValue {
  lastResult: StoredResult | null;
  setLastResult: (value: StoredResult | null) => void;
  dark: boolean;
  setDark: (value: boolean) => void;
  confirmActions: boolean;
  setConfirmActions: (value: boolean) => void;
  warnSuspicious: boolean;
  setWarnSuspicious: (value: boolean) => void;
  multiQr: boolean;
  setMultiQr: (value: boolean) => void;
  retentionDays: number;
  setRetentionDays: (value: number) => void;
  toast: string | null;
  showToast: (message: string) => void;
}

const AppContext = createContext<AppContextValue | null>(null);

const SETTINGS_KEY = 'qrflow:settings';

interface Settings {
  dark: boolean;
  confirmActions: boolean;
  warnSuspicious: boolean;
  multiQr: boolean;
  retentionDays: number;
}

function loadSettings(): Settings {
  const defaults: Settings = {
    dark: window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false,
    confirmActions: true,
    warnSuspicious: true,
    multiQr: true,
    retentionDays: 90,
  };
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return defaults;
    return { ...defaults, ...(JSON.parse(raw) as Partial<Settings>) };
  } catch {
    return defaults;
  }
}

export function AppProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>(loadSettings);
  const [lastResult, setLastResultState] = useState<StoredResult | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const toastTimer = useRef<number | null>(null);

  const showToast = useCallback((message: string) => {
    setToast(message);
    if (toastTimer.current !== null) window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(null), 2400);
  }, []);

  useEffect(() => {
    return () => {
      if (toastTimer.current !== null) window.clearTimeout(toastTimer.current);
    };
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle('dark', settings.dark);
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  }, [settings]);

  const setLastResult = useCallback((value: StoredResult | null) => {
    setLastResultState(value);
  }, []);

  const value = useMemo<AppContextValue>(
    () => ({
      lastResult,
      setLastResult,
      dark: settings.dark,
      setDark: (v) => setSettings((s) => ({ ...s, dark: v })),
      confirmActions: settings.confirmActions,
      setConfirmActions: (v) => setSettings((s) => ({ ...s, confirmActions: v })),
      warnSuspicious: settings.warnSuspicious,
      setWarnSuspicious: (v) => setSettings((s) => ({ ...s, warnSuspicious: v })),
      multiQr: settings.multiQr,
      setMultiQr: (v) => setSettings((s) => ({ ...s, multiQr: v })),
      retentionDays: settings.retentionDays,
      setRetentionDays: (v) => setSettings((s) => ({ ...s, retentionDays: v })),
      toast,
      showToast,
    }),
    [lastResult, setLastResult, settings, toast, showToast],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp(): AppContextValue {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp doit être utilisé dans AppProvider');
  return ctx;
}
