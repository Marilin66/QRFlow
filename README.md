# QRFlow

![Build Android](https://github.com/Marilin66/QRFlow/workflows/Build%20Android%20APK/badge.svg)
![Tests](https://github.com/Marilin66/QRFlow/workflows/Tests%20&%20Quality/badge.svg)
![Build Web](https://github.com/Marilin66/QRFlow/workflows/Build%20Web%20App/badge.svg)

> **« Le QR code est déjà sur mon téléphone : je veux pouvoir le scanner
> sans utiliser un autre téléphone. »**

QRFlow détecte, décode et interprète intelligemment les QR codes **déjà
affichés à l'écran** — à partir d'une capture d'écran ou directement via une
bulle flottante (sur Android). Toutes les analyses sont **locales** : aucun
backend, aucune donnée envoyée sur Internet.

## Les deux applications

| Dossier | Techno | Plateformes | Fonctionnalités |
|---|---|---|---|
| [`mobile/`](mobile/) | Flutter | Android | Import de capture, scan caméra, **bulle flottante + MediaProjection**, analyse intelligente, historique, paramètres |
| [`web/`](web/) | React + Vite + Tailwind | Navigateur | Import d'image, **scan caméra** (getUserMedia), analyse intelligente, historique local, paramètres |

Le web ne peut pas afficher de bulle par-dessus les autres onglets ni capturer
l'écran d'une autre application : ces fonctionnalités sont **exclusivement
Android** (contrainte technique des navigateurs, conforme à la spec).

## Principe de sécurité

> **Détection → Présentation → Confirmation → Action**

Aucun lien ouvert, appel, SMS, contact, réseau Wi-Fi ou application lancé
automatiquement. Les URL suspectes sont signalées.

## Démarrage rapide

```bash
# Mobile (voir mobile/README.md pour le détail)
cd mobile
flutter create . --org com.qrflow --project-name qrflow_mobile   # une seule fois
flutter pub get
flutter run

# Web
cd web
npm install
npm run dev
```

## Historique du projet

- Spec : `Nouveau document texte.txt` (cahier des charges complet).
- Architecture : monorepo `mobile/` (Flutter) + `web/` (React).
