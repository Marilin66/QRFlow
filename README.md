# QRFlow

![Build Web](https://github.com/Marilin66/QRFlow/workflows/Build%20Web%20App/badge.svg)

> **« Le QR code est déjà affiché sur mon écran : je veux pouvoir le scanner
> sans utiliser un autre appareil. »**

QRFlow détecte, décode et interprète intelligemment les QR codes **déjà
affichés à l'écran** — à partir d'une image importée ou d'un scan caméra.
Toutes les analyses sont **locales** : aucun backend, aucune donnée envoyée
sur Internet.

## L'application

| Dossier | Techno | Fonctionnalités |
|---|---|---|
| [`web/`](web/) | React + Vite + Tailwind | Import d'image, scan caméra (getUserMedia), analyse intelligente, historique local, paramètres |

## Principe de sécurité

> **Détection -> Présentation -> Confirmation -> Action**

Aucun lien ouvert, appel, SMS, contact, réseau Wi-Fi ou application lancé
automatiquement. Les URL suspectes sont signalées.

## Démarrage rapide

```bash
cd web
npm install
npm run dev
```

## Historique du projet

- Spec : `Nouveau document texte.txt` (cahier des charges complet).
- Architecture : application web `web/` (React). L'application mobile Flutter
  a été retirée du dépôt ; une sauvegarde locale est conservée.
