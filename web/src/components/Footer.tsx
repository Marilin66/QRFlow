import { Link } from 'react-router-dom';
import FinderMark from './FinderMark';

const LINKS = [
  { to: '/', label: 'Accueil' },
  { to: '/import', label: 'Capture' },
  { to: '/scan', label: 'Caméra' },
  { to: '/history', label: 'Historique' },
  { to: '/help', label: 'Aide' },
  { to: '/settings', label: 'Réglages' },
];

export default function Footer() {
  return (
    <footer className="mt-auto border-t border-slate-200/70 bg-paper/80 backdrop-blur dark:border-ink-800 dark:bg-ink-950/80">
      <div className="mx-auto max-w-3xl space-y-6 px-4 py-10">
        {/* Brand + tagline */}
        <div className="flex flex-col items-center gap-3 text-center">
          <Link to="/" className="flex items-center gap-2.5">
            <img src="/logo.png" alt="QRFlow Logo" className="size-8 rounded-lg object-contain" />
            <span className="font-display text-lg font-bold tracking-tight">QRFlow</span>
          </Link>
          <p className="max-w-sm text-xs leading-relaxed text-slate-400 dark:text-slate-500">
            Scannez et décodez les QR codes directement depuis votre navigateur.
            Toutes les analyses restent 100&nbsp;% locales — aucune donnée n'est envoyée sur Internet.
          </p>
        </div>

        {/* Links */}
        <nav className="flex flex-wrap items-center justify-center gap-x-5 gap-y-2" aria-label="Pied de page">
          {LINKS.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              className="text-xs font-medium text-slate-500 transition hover:text-electric-500 dark:text-slate-400 dark:hover:text-electric-400"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        {/* Divider */}
        <div className="border-t border-slate-200/60 dark:border-ink-800" />

        {/* Bottom row */}
        <div className="flex flex-col items-center gap-2 sm:flex-row sm:justify-between">
          <div className="flex items-center gap-1.5 text-[11px] text-slate-400 dark:text-slate-500">
            <FinderMark size={14} className="text-electric-500" />
            <span>Tout reste sur votre appareil.</span>
          </div>
          <p className="text-[11px] text-slate-400 dark:text-slate-500">
            &copy; {new Date().getFullYear()} QRFlow &mdash; version 0.1.0
          </p>
        </div>
      </div>
    </footer>
  );
}
