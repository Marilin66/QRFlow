# QRFlow — Application mobile (Flutter + Android)

> **« Je vois un QR Code dans une application. J'appelle QRFlow sans en sortir.
> Je scanne. Je comprends. Je confirme. J'agis. »**

QRFlow détecte, décode et interprète intelligemment des QR codes — via
l'**import d'image** (capture d'écran ou photo de la galerie) ou le
**scan caméra** en direct. Toutes les analyses sont **100 % locales** : aucun
backend, aucune donnée envoyée sur Internet.

---

## Architecture

```
lib/
├── main.dart                       # Point d'entrée
├── app/
│   ├── app.dart                    # Shell MaterialApp (thème, routes, init)
│   ├── app_state.dart              # État global (réglages, historique)
│   └── theme.dart                  # Design system (tokens, typographies)
├── core/
│   ├── models/
│   │   ├── qr_content.dart         # Hiérarchie scellée des 10 types
│   │   ├── content_presentation.dart  # Étiquettes & icônes par type
│   │   └── history_entry.dart      # Entrée d'historique
│   └── services/
│       ├── content_analyzer.dart   # Moteur d'analyse (source unique)
│       ├── qr_decoder.dart         # Décodage image statique (ML Kit)
│       ├── action_manager.dart     # Actions (toujours après confirmation)
│       └── history_service.dart    # Historique SQLite
├── features/
│   ├── home/            # Accueil-hub des 3 modes
│   ├── import/          # Mode Import (photo ou fichier)
│   ├── camera/          # Scan caméra en direct
│   ├── result/          # Résultat : présentation → confirmation → action
│   ├── history/         # Historique (recherche, suppression)
│   └── settings/        # Réglages (thème clair/sombre/système)
└── widgets/             # Signature finder, ligne de balayage, mode cards
```

## Les 3 modes

| Mode | Description | Source |
|---|---|---|
| **Import** | Photo ou image de la galerie décodée par ML Kit | `features/import/` |
| **Caméra** | Scan en direct avec viseur signature + torche | `features/camera/` |
| **Historique** | Local SQLite : recherche, suppression individuelle, vidage | `features/history/` |

## Moteur d'analyse

`ContentAnalyzer.analyze(String)` reconnaît **10 types** de contenu :
URL, texte brut, téléphone, e-mail, contact vCard, réseau Wi-Fi, coordonnées
GPS, événement calendrier, SMS, contenu inconnu.

Règles de sécurité intégrées :

- **Aucune action automatique** — le flux est toujours
  *Détection → Présentation → Confirmation → Action*.
- **Domaine toujours visible en clair**, jamais masqué.
- **Avertissement visuel** pour les URL suspectes : raccourcisseurs
  (`bit.ly`…), adresse IP brute, TLD douteux, caractères trompeurs.
- Possibilité de **copier sans ouvrir**.

## Design system

- **Palette** : bleu-violet `#5B5FEF` (marque), vert `#2FB380` (succès),
  rouge `#E2574C` (alertes uniquement), fond `#F7F8FC` / `#12131A`.
- **Typographies** : Space Grotesk (titres), Inter (texte) — embarquées.
- **Mode clair / sombre** : suivi du thème système, surchargeable dans les
  réglages.
- **Signature visuelle** : repères de viseur (finder) + ligne de balayage
  animée, partagés entre accueil et caméra.

## Build

Prérequis : Flutter 3.44+ stable, JDK 17, Android SDK (minSdk 26).

```bash
cd mobile
flutter pub get

# APK debug (installation directe sur appareil)
flutter build apk --debug

# APK release
flutter build apk --release
```

Artifacts : `build/app/outputs/flutter-apk/app-{debug,release}.apk`

### CI (GitHub Actions)

| Workflow | Ce qu'il fait |
|---|---|
| `Tests & Quality` | `flutter analyze` + `flutter test` |
| `Build Android APK` | APK debug + release, uploadé en artifact (release conservé 90 j) |

## Tests

```bash
cd mobile
flutter test
```

- `test/content_analyzer_test.dart` — les 10 types + URL suspectes
  (IP brute, raccourcisseur, TLD douteux).
- `test/widget_test.dart` — navigation et écrans de l'application.

## Permissions (demandées au moment de l'usage uniquement)

| Permission | Déclenchée par |
|---|---|
| `CAMERA` | Mode Caméra |
| Photo Picker | Aucune permission requise |
