const PIPELINE = [
  {
    title: 'Détecter',
    text: 'Un QR code est trouvé dans une image, une capture ou le flux caméra.',
  },
  {
    title: 'Comprendre',
    text: 'Le contenu est identifié : lien, Wi-Fi, contact, coordonnées…',
  },
  {
    title: 'Confirmer',
    text: 'Rien n’est exécuté sans votre accord explicite.',
  },
  {
    title: 'Agir',
    text: 'L’action choisie se lance, et l’analyse rejoint l’historique.',
  },
];

const ITEMS = [
  {
    icon: '🖼️',
    title: 'Mode 1 — Depuis une capture',
    text: 'Importez une capture d’écran ou une image contenant un QR code. '
      + 'L’application détecte, décode et analyse le contenu. Si plusieurs QR '
      + 'codes sont présents, choisissez celui qui vous intéresse.',
  },
  {
    icon: '📷',
    title: 'Mode 2 — Scan caméra',
    text: 'Le navigateur demande l’accès à la caméra, puis les images sont '
      + 'analysées en continu jusqu’à la détection d’un QR code. Nécessite une '
      + 'connexion sécurisée (HTTPS) ou localhost.',
  },
  {
    icon: '🔒',
    title: 'Sécurité avant tout',
    text: 'QRFlow ne fait jamais rien automatiquement : aucun lien ouvert, '
      + 'aucun appel, aucun SMS sans votre confirmation. Les URL suspectes '
      + 'déclenchent un avertissement.',
  },
  {
    icon: '🕵️',
    title: 'Vie privée',
    text: 'Toutes les analyses sont effectuées dans votre navigateur. '
      + 'Aucune donnée n’est envoyée sur Internet. L’historique est stocké '
      + 'localement.',
  },
  {
    icon: '📱',
    title: 'Pourquoi pas de bulle flottante sur le web ?',
    text: 'Les navigateurs ne permettent pas d’afficher une fenêtre par-dessus '
      + 'les autres onglets ni de capturer l’écran d’une autre application. '
      + 'Ces fonctionnalités sont exclusivement Android : elles sont dans '
      + 'l’application QRFlow (Flutter).',
  },
  {
    icon: '📶',
    title: 'Réseau Wi-Fi',
    text: 'Le navigateur ne peut pas rejoindre un réseau à votre place. '
      + 'QRFlow affiche les informations (nom, sécurité, mot de passe) et '
      + 'permet de les copier.',
  },
];

export default function Help() {
  return (
    <div className="page-enter space-y-8">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight">Aide</h1>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          QRFlow suit un principe simple : détecter, comprendre, confirmer, agir.
        </p>
      </div>

      {/* Le pipeline : une vraie séquence du produit */}
      <section className="grid gap-3 sm:grid-cols-4">
        {PIPELINE.map((step, index) => (
          <div key={step.title} className="card p-4">
            <div className="flex items-center gap-2">
              <span className="font-mono text-xs font-bold text-electric-500">
                {String(index + 1).padStart(2, '0')}
              </span>
              <span className="status-dot size-1.5 rounded-full bg-electric-500" />
            </div>
            <p className="font-display mt-3 text-sm font-bold">{step.title}</p>
            <p className="mt-1 text-xs leading-relaxed text-slate-500 dark:text-slate-400">
              {step.text}
            </p>
          </div>
        ))}
      </section>

      {/* Explications détaillées */}
      <section className="space-y-3">
        {ITEMS.map((item) => (
          <div key={item.title} className="card flex gap-4 p-4">
            <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-electric-500/10 text-xl">
              {item.icon}
            </span>
            <div>
              <p className="text-sm font-bold">{item.title}</p>
              <p className="mt-1 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
                {item.text}
              </p>
            </div>
          </div>
        ))}
      </section>
    </div>
  );
}
