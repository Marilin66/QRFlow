# QRFlow — Mobile (Flutter)

Application Android de détection intelligente de QR codes déjà affichés à
l'écran du téléphone. Deux modes complémentaires :

1. **Depuis une capture** — import d'une capture d'écran / image, détection,
   décodage et analyse du contenu ;
2. **Scanner l'écran** — bulle flottante + capture d'écran officielle
   (MediaProjection) pour analyser un QR code affiché dans une autre
   application.

Aucun backend : toutes les analyses sont **100 % locales**.

## Architecture

```
lib/
├── main.dart                     Point d'entrée
├── app/                          Thème, état global, providers
│   ├── app.dart
│   ├── app_state.dart            Paramètres persistés (SharedPreferences)
│   └── theme.dart                Material 3 (clair / sombre)
├── core/
│   ├── models/
│   │   ├── qr_content.dart       Types de contenu (URL, Wi-Fi, vCard…)
│   │   └── history_entry.dart
│   ├── services/
│   │   ├── content_analyzer.dart Analyse et typage du contenu
│   │   ├── history_service.dart  Historique SQLite
│   │   └── action_manager.dart   Actions par type (avec confirmations)
│   └── platform/
│       └── screen_capture_bridge.dart  Canal natif (bulle + MediaProjection)
├── features/
│   ├── home/                     Accueil (2 modes + accès rapides)
│   ├── import/                   Mode 1 : import d'une capture
│   ├── camera/                   Scan caméra en direct
│   ├── screen_scan/              Mode 2 : bulle flottante
│   ├── result/                   Écran de résultat + actions
│   ├── history/                  Historique (recherche, suppression)
│   ├── settings/                 Paramètres
│   └── help/                     Aide
└── widgets/                      Widgets partagés
```

### Module natif Android (`android/…/com/qrflow/app/`)

| Fichier | Rôle |
|---|---|
| `MainActivity.kt` | Consentement MediaProjection (résultat d'intent) |
| `ScreenCaptureChannel.kt` | Canal MethodChannel `com.qrflow.app/screen_capture` |
| `BubbleService.kt` | Bulle flottante déplaçable (service `specialUse`) |
| `ScreenCaptureService.kt` | Capture MediaProjection + enregistrement PNG |

## Installation

Prérequis : Flutter ≥ 3.24, Android Studio avec le SDK Android.

```bash
cd mobile

# 1. Complète le scaffolding de plateforme (wrapper Gradle, icônes, styles).
#    N'écrase pas le code existant.
flutter create . --org com.qrflow --project-name qrflow_mobile

# 2. Récupère les dépendances
flutter pub get

# 3. Lance sur un appareil / émulateur
flutter run
```

> ℹ Si `flutter create .` signale que des fichiers existent, c'est normal :
> il ajoute uniquement les fichiers manquants.

## Compilation de l'APK

```bash
cd mobile
flutter build apk --release
# APK : build/app/outputs/flutter-apk/app-release.apk
```

## Tests

```bash
cd mobile
flutter test
```

## Contraintes Android (importantes)

- **Android 14+** : le jeton MediaProjection est **à usage unique** et le
  consentement doit précéder le démarrage du service de capture.
- **Android 15+** : une pastille système est affichée pendant la capture ;
  l'utilisateur peut l'arrêter à tout moment (`onStop` géré).
- La permission « Afficher par-dessus les applications » est nécessaire pour
  la bulle flottante (demandée explicitement, jamais au démarrage).
- Certaines applications bloquent volontairement la capture (banque, DRM) :
  l'interface propose alors le repli vers le mode « Depuis une capture ».
- Aucune action (lien, appel, SMS, Wi-Fi, contact…) n'est effectuée sans
  confirmation explicite de l'utilisateur.

## Notes de phase 2 (squelette fonctionnel)

- La bulle applique la taille et l'opacité choisies dans les paramètres.
- Chaque appui sur la bulle demande le consentement (si le service n'est pas
  encore actif), puis capture et analyse l'écran.
- L'ajout d'un contact via l'intent système Android et la connexion Wi-Fi
  automatique (WifiNetworkSuggestion) sont prévus pour les phases suivantes.
