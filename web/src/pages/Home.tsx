import { Link } from 'react-router-dom';
import FinderMark from '../components/FinderMark';
import { Icon, type IconName } from '../components/icons';

const SECONDARY_LINKS: Array<{ to: string; icon: IconName; label: string }> = [
  { to: '/history', icon: 'history', label: 'Historique' },
  { to: '/settings', icon: 'settings', label: 'Paramètres' },
  { to: '/help', icon: 'help', label: 'Aide' },
];

export default function Home() {
  return (
    <div className="page-enter space-y-8">
      {/* ── Héro : le QR comme sujet ─────────────────────────────── */}
      <section className="hero-glow relative overflow-hidden rounded-3xl border border-slate-200/70 bg-white px-6 py-12 text-center dark:border-ink-800 dark:bg-ink-900">
        <div className="relative mx-auto grid size-24 place-items-center text-electric-500 dark:text-electric-400">
          <FinderMark size={72} />
        </div>
        <span className="scanline" />
        <h1 className="font-display mx-auto mt-6 max-w-lg text-3xl font-bold leading-tight tracking-tight sm:text-4xl">
          Le QR code est déjà sur votre écran.
          <span className="text-electric-500 dark:text-electric-400"> Scannez-le sans autre téléphone.</span>
        </h1>
        <p className="mx-auto mt-4 max-w-md text-sm leading-relaxed text-slate-500 dark:text-slate-400">
          Importez une capture d’écran ou pointez la caméra. QRFlow identifie le
          contenu, vous propose l’action adaptée — et ne fait jamais rien sans
          votre accord.
        </p>
      </section>

      {/* ── Les deux modes ───────────────────────────────────────── */}
      <section className="grid gap-4 sm:grid-cols-2">
        <Link
          to="/import"
          className="group card relative overflow-hidden p-6 transition hover:-translate-y-1 hover:shadow-lg hover:shadow-electric-500/10"
        >
          <span className="corner corner-tl opacity-0 transition group-hover:opacity-100" />
          <span className="corner corner-br opacity-0 transition group-hover:opacity-100" />
          <div className="grid size-12 place-items-center rounded-2xl bg-electric-500/10 text-electric-500 dark:text-electric-400">
            <Icon name="image" className="size-7" />
          </div>
          <h2 className="font-display mt-4 text-lg font-bold">Depuis une capture</h2>
          <p className="mt-1.5 text-sm text-slate-500 dark:text-slate-400">
            Importez une capture d’écran ou une image : le QR code est détecté
            automatiquement, même s’il y en a plusieurs.
          </p>
          <span className="mt-4 inline-flex items-center gap-1.5 text-sm font-semibold text-electric-500">
            Importer une image
            <Icon name="chevron-right" className="size-4 transition group-hover:translate-x-1" />
          </span>
        </Link>

        <Link
          to="/scan"
          className="group card relative overflow-hidden p-6 transition hover:-translate-y-1 hover:shadow-lg hover:shadow-electric-500/10"
        >
          <span className="corner corner-tl opacity-0 transition group-hover:opacity-100" />
          <span className="corner corner-br opacity-0 transition group-hover:opacity-100" />
          <div className="grid size-12 place-items-center rounded-2xl bg-electric-500/10 text-electric-500 dark:text-electric-400">
            <Icon name="camera" className="size-7" />
          </div>
          <h2 className="font-display mt-4 text-lg font-bold">Caméra</h2>
          <p className="mt-1.5 text-sm text-slate-500 dark:text-slate-400">
            Pointez la caméra du navigateur : la détection est continue et
            instantanée.
          </p>
          <span className="mt-4 inline-flex items-center gap-1.5 text-sm font-semibold text-electric-500">
            Démarrer le scan
            <Icon name="chevron-right" className="size-4 transition group-hover:translate-x-1" />
          </span>
        </Link>
      </section>

      {/* ── Note sur le mode « Scanner l'écran » ─────────────────── */}
      <section className="card flex gap-4 border-safety-500/30 bg-safety-500/5 p-5 dark:border-safety-500/20">
        <Icon name="smartphone" className="mt-0.5 size-6 shrink-0 text-safety-500" />
        <div className="text-sm leading-relaxed">
          <p className="font-semibold text-safety-500">
            À propos du mode « Scanner l’écran »
          </p>
          <p className="mt-1 text-slate-500 dark:text-slate-400">
            La bulle flottante et la capture directe de l’écran demandent des
            autorisations Android : elles vivent dans l’application{' '}
            <strong>QRFlow Android</strong>. Sur le web, QRFlow propose
            l’import de capture et le scan caméra.
          </p>
        </div>
      </section>

      {/* ── Accès secondaires ────────────────────────────────────── */}
      <section className="grid gap-3 sm:grid-cols-3">
        {SECONDARY_LINKS.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            className="card flex items-center gap-3 px-4 py-3.5 transition hover:border-electric-400 dark:hover:border-electric-500"
          >
            <span className="grid size-9 place-items-center rounded-lg bg-electric-500/10 text-electric-500">
              <Icon name={item.icon} className="size-5" />
            </span>
            <span className="text-sm font-semibold">{item.label}</span>
          </Link>
        ))}
      </section>
    </div>
  );
}
