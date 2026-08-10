# QRFlow — Web (React)

Version navigateur de QRFlow : import d'une capture d'écran + scan caméra,
analyse intelligente du contenu, historique local.

> Le web ne peut pas afficher de bulle flottante ni capturer l'écran d'une
> autre application : ces fonctions sont réservées à l'appli Android.

## Stack

- **React 18 + TypeScript** (Vite)
- **Tailwind CSS v4**
- **jsQR** — décodage QR (image importée et frames caméra)
- Historique : `localStorage`
- Aucun backend.

## Installation

```bash
cd web
npm install
npm run dev        # http://localhost:5173
```

## Production

```bash
npm run build      # génère dist/
npm run preview    # prévisualise le build
```

La caméra (`getUserMedia`) exige une connexion **HTTPS** (ou localhost) :
déployez le dossier `dist/` sur n'importe quel hébergement statique
(Vercel, Netlify, GitHub Pages…) ou servez-le en HTTPS.

## Structure

```
src/
├── main.tsx / App.tsx      Point d'entrée + routes + layout
├── lib/
│   ├── types.ts            Types de contenus QR
│   ├── analyzer.ts         Analyse et typage du contenu (port Dart)
│   ├── decode.ts           jsQR : image / frame vidéo
│   ├── history.ts          Historique localStorage
│   ├── actions.ts          Copier / partager / ouvrir
│   └── store.tsx           Contexte global (thème, réglages, résultat)
├── components/QrBadge.tsx
└── pages/                  Accueil, Scan, Import, Résultat, Historique,
                            Paramètres, Aide
```

## Tests

```bash
npx tsc --noEmit   # vérification des types
npm run build      # build complet
```
