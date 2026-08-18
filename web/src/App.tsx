import { useState } from 'react';
import { NavLink, Route, Routes } from 'react-router-dom';
import { Icon, type IconName } from './components/icons';
import Footer from './components/Footer';
import { useApp } from './lib/store';
import Home from './pages/Home';
import Scan from './pages/Scan';
import Import from './pages/Import';
import Result from './pages/Result';
import History from './pages/History';
import Settings from './pages/Settings';
import Help from './pages/Help';

const NAV: Array<{ to: string; label: string; icon: IconName; end?: boolean }> = [
  { to: '/', label: 'Accueil', icon: 'home', end: true },
  { to: '/scan', label: 'Caméra', icon: 'camera' },
  { to: '/import', label: 'Capture', icon: 'image' },
  { to: '/history', label: 'Historique', icon: 'history' },
  { to: '/settings', label: 'Réglages', icon: 'settings' },
];

export default function App() {
  const { dark, setDark, toast } = useApp();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <div className="flex min-h-screen flex-col">
      {/* ── Header ──────────────────────────────────────────────── */}
      <header className="sticky top-0 z-30 border-b border-slate-200/70 bg-paper/80 backdrop-blur dark:border-ink-800 dark:bg-ink-950/80">
        <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-3">
          <NavLink to="/" className="flex items-center gap-2.5">
            <img src="/logo.png" alt="QRFlow Logo" className="size-10 rounded-xl object-contain shadow-md" />
            <span className="font-display text-xl font-bold tracking-tight">
              QRFlow
            </span>
          </NavLink>

          {/* Navigation bureau */}
          <nav className="hidden items-center gap-1 md:flex" aria-label="Navigation">
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) =>
                  `rounded-lg px-3 py-1.5 text-sm font-medium transition ${
                    isActive
                      ? 'bg-electric-500/10 text-electric-500 dark:text-electric-400'
                      : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-slate-400 dark:hover:bg-ink-800 dark:hover:text-white'
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>

          <div className="flex items-center gap-2">
            {/* Bouton thème */}
            <button
              onClick={() => setDark(!dark)}
              className="grid size-10 place-items-center rounded-xl border border-slate-200 bg-white text-lg transition hover:border-electric-400 dark:border-ink-800 dark:bg-ink-900"
              aria-label="Changer de thème"
              title="Changer de thème"
            >
              {dark ? <Icon name="sun" className="size-5" /> : <Icon name="moon" className="size-5" />}
            </button>

            {/* Hamburger mobile */}
            <button
              onClick={() => setMenuOpen(!menuOpen)}
              className="grid size-10 place-items-center rounded-xl border border-slate-200 bg-white transition hover:border-electric-400 md:hidden dark:border-ink-800 dark:bg-ink-900"
              aria-label="Menu"
              aria-expanded={menuOpen}
            >
              <Icon name={menuOpen ? 'close' : 'menu'} className="size-5" />
            </button>
          </div>
        </div>
      </header>

      {/* ── Menu mobile (slide-down) ───────────────────────────── */}
      {menuOpen && (
        <nav
          className="border-b border-slate-200/70 bg-paper/95 backdrop-blur md:hidden dark:border-ink-800 dark:bg-ink-950/95"
          aria-label="Navigation mobile"
        >
          <div className="mx-auto max-w-3xl px-4 py-3 space-y-1">
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                onClick={() => setMenuOpen(false)}
                className={({ isActive }) =>
                  `flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium transition ${
                    isActive
                      ? 'bg-electric-500/10 text-electric-500 dark:text-electric-400'
                      : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-slate-400 dark:hover:bg-ink-800 dark:hover:text-white'
                  }`
                }
              >
                <Icon name={item.icon} className="size-5" />
                {item.label}
              </NavLink>
            ))}
          </div>
        </nav>
      )}

      {/* ── Main ───────────────────────────────────────────────── */}
      <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-8">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/scan" element={<Scan />} />
          <Route path="/import" element={<Import />} />
          <Route path="/result" element={<Result />} />
          <Route path="/history" element={<History />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/help" element={<Help />} />
          <Route path="*" element={<Home />} />
        </Routes>
      </main>

      {/* ── Footer ─────────────────────────────────────────────── */}
      <Footer />

      {/* Toast */}
      {toast && (
        <div
          role="status"
          className="pointer-events-none fixed inset-x-0 bottom-8 z-50 flex justify-center px-4"
        >
          <div className="page-enter rounded-xl bg-ink-900 px-4 py-2.5 text-sm font-medium text-white shadow-xl shadow-black/20 dark:bg-white dark:text-ink-900">
            {toast}
          </div>
        </div>
      )}
    </div>
  );
}
