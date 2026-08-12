# QRFlow — Application mobile (Flutter + Android)

> **« Je vois un QR Code dans une application. J'appelle QRFlow sans en sortir.
> Je scanne. Je comprends. Je confirme. J'agis. »**

QRFlow détecte, décode et interprète intelligemment des QR codes **déjà
affichés à l'écran** — via le **Mode Flash** (bulle flottante + MediaProjection,
sans quitter l'app en cours), l'**import d'image**, ou le **scan caméra**.
Toutes les analyses sont **100 % locales** : aucun backend, aucune donnée
envoyée sur Internet.

---

## Architecture

```
lib/
├── main.dart                       # Point d'entrée
├── app/
│   ├── app.dart                    # Shell MaterialApp (thème, routes, init)
│   ├── app_state.dart              # État global (réglages, pont natif)
│   └── theme.dart                  # Design system (tokens, typographies)
├── core/
│   ├── models/
│   │   ├── qr_content.dart         # Hiérarchie scellée des 10 types
│   │   ├── content_presentation.dart  # Étiquettes & icônes par type
│   │   └── history_entry.dart      # Entrée d'historique
│   ├── platform/
│   │   └── screen_capture_bridge.dart  # Pont Dart ↔ natif (Mode Flash)
│   └── services/
│       ├── content_analyzer.dart   # Moteur d'analyse (source unique)
│       ├── qr_decoder.dart         # Décodage image statique (ML Kit)
│       ├── overlay_payload.dart    # Payload de l'overlay natif
│       ├── action_manager.dart     # Actions (toujours après confirmation)
│       └── history_service.dart    # Historique SQLite
├── features/
│   ├── home/            # Accueil-hub des 4 modes
│   ├── import/          # Mode Import (photo ou fichier)
│   ├── camera/          # Scan caméra en direct
│   ├── screen_scan/     # Mode Flash : activation + session
│   ├── result/          # Résultat : présentation → confirmation → action
│   ├── history/         # Historique (recherche, suppression)
│   └── settings/        # Réglages (thème clair/sombre/système)
└── widgets/             # Signature finder, ligne de balayage, mode cards

android/app/src/main/kotlin/com/qrflow/app/   # Couche native (Mode Flash)
├── MainActivity.kt                  # Activité + consentement MediaProjection
├── ScreenCaptureChannel.kt          # Canal de messages Dart ↔ natif
├── BubbleService.kt                 # Bulle flottante déplaçable
├── ScreenCaptureProjectionService.kt# Capture MediaProjection + ML Kit
└── ResultOverlay.kt                 # Fenêtre TYPE_APPLICATION_OVERLAY
```

## Les 4 modes

| Mode | Description | Source |
|---|---|---|
| **Flash** | Bulle flottante → capture d'écran en place → résultat en overlay, sans quitter l'app en cours | `features/screen_scan/` + Kotlin natif |
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

## Mode Flash (natif)

1. `MainActivity` demande le consentement **MediaProjection** (une seule fois
   par session) et `SYSTEM_ALERT_WINDOW` (permission d'overlay).
2. `ScreenCaptureProjectionService` démarre en **service avant-plan**
   (notification obligatoire Android 8+) et crée un `VirtualDisplay`.
3. `BubbleService` affiche la **bulle flottante** (déplaçable, anneau d'état).
4. Au tap : capture de l'écran → décodage **ML Kit natif** → envoi du contenu
   brut au moteur Dart (`prepareOverlayResult`) pour analyse.
5. `ResultOverlay` affiche la **fenêtre `TYPE_APPLICATION_OVERLAY`** au-dessus
   de l'app en cours : liste des QR → détail → actions avec confirmation.
6. Si le moteur Dart ne répond pas : **repli** — retour à QRFlow au premier
   plan avec le contenu livré.

Contraintes Android gérées :

- **App protégée (FLAG_SECURE)** : capture noire détectée → message clair →
  repli vers le Mode Import. Jamais contournée.
- Permission refusée, overlay désactivé, capture refusée : messages
  pédagogiques, non techniques.

## Design system

- **Palette** : bleu-violet `#5B5FEF` (marque), vert `#2FB380` (succès),
  rouge `#E2574C` (alertes uniquement), fond `#F7F8FC` / `#12131A`.
- **Typographies** : Space Grotesk (titres), Inter (texte) — embarquées.
- **Mode clair / sombre** : suivi du thème système, surchargeable dans les
  réglages.
- **Signature visuelle** : repères de viseur (finder) + ligne de balayage
  animée, partagés entre accueil, caméra et scan d'écran.

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
- `test/overlay_payload_test.dart` — payload de l'overlay natif (domaine,
  suspicion, actions par type).
- `test/widget_test.dart` — navigation et écrans de l'application.

## Permissions (demandées au moment de l'usage uniquement)

| Permission | Déclenchée par |
|---|---|
| `SYSTEM_ALERT_WINDOW` | Activation du Mode Flash |
| `POST_NOTIFICATIONS` (13+) | Notification du service avant-plan |
| `CAMERA` | Mode Caméra |
| MediaProjection (consentement) | Activation du Mode Flash |
| Photo Picker | Aucune permission requise |
