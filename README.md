# QRFlow

![Build Mobile](https://github.com/Marilin66/QRFlow/workflows/Build%20Android%20APK/badge.svg)
![Tests](https://github.com/Marilin66/QRFlow/workflows/Tests%20%26%20Quality/badge.svg)
![Build Web](https://github.com/Marilin66/QRFlow/workflows/Build%20Web%20App/badge.svg)

> **« Le QR code est déjà affiché sur mon écran : je veux pouvoir le scanner
> sans utiliser un autre appareil. »**

QRFlow détecte, décode et interprète intelligemment les QR codes **déjà
affichés à l'écran** — depuis une image importée (capture d'écran ou photo)
ou un scan caméra. Toutes les analyses sont **locales** :
aucun backend, aucune donnée envoyée sur Internet.

## L'application

| Dossier | Techno | Fonctionnalités |
|---|---|---|
| [`mobile/`](mobile/) | Flutter + Android | Import d'image, Scan caméra, Historique SQLite, thème clair/sombre |
| [`web/`](web/) | React + Vite | Import d'image, analyse intelligente, historique local, paramètres (le web n'accède pas à l'écran d'une autre app : Mode Import uniquement) |

## Principe de sécurité

> **Détection -> Présentation -> Confirmation -> Action**

Aucun lien ouvert, appel, SMS, contact, réseau Wi-Fi ou application lancé
automatiquement. Les URL suspectes (raccourcisseur, IP brute, TLD douteux)
sont signalées ; le domaine est toujours affiché en clair.

## Démarrage rapide

### Mobile (Android)

```bash
cd mobile
flutter pub get
flutter build apk --debug   # APK dans build/app/outputs/flutter-apk/
```

### Web

```bash
cd web
npm install
npm run dev
```

## CI

- **Tests & Quality** : `flutter analyze` + `flutter test`.
- **Build Android APK** : APK debug + release (artifacts téléchargeables).
- **Build Web App** : build React + déploiement GitHub Pages (branche main).

## Documentation technique

- [`mobile/README.md`](mobile/README.md) : architecture, design system,
  tests, permissions.

## Historique du projet

- Spec : `Nouveau document texte.txt` (cahier des charges complet).
- Roadmap livrée niveau par niveau (CI verte à chaque étape) : socle &
  design system → identité → analyse & import → caméra → historique &
  réglages → déploiement.
