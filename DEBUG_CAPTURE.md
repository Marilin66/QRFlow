# 🐛 Guide de Débogage de la Capture d'Écran

## 🔍 Problème identifié

Les étapes suivantes fonctionnent :
- ✅ Interface de l'application
- ✅ Bouton d'activation
- ✅ Permission de superposition
- ✅ Bulle Q visible
- ✅ Retour vers l'application précédente

Mais ces étapes ne fonctionnent pas :
- ❌ Récupération de l'image/contenu de l'écran
- ❌ Détection du QR dans ce contenu
- ❌ Décodage
- ❌ Transmission du résultat à QRFlow

## 🔧 Corrections appliquées

### 1. Ajout de logs de débogage (Android)

**Fichiers modifiés :**
- `ScreenCaptureService.kt` : Logs pour la sauvegarde PNG
- `ScreenCaptureChannel.kt` : Logs pour les appels de méthode
- `screen_capture_bridge.dart` : Logs côté Flutter

### 2. Amélioration du timing

**Problème :** La capture peut être trop rapide, avant que l'écran soit bien rendu.

**Solution :**
- Délai de 200ms ajouté avant la capture dans `captureFrame()`
- Délai de 500ms ajouté avant `_checkPendingCapture()` côté Flutter

### 3. Gestion d'erreurs améliorée

**Ajouté :**
- Vérification de l'existence du fichier
- Messages d'erreur détaillés
- Try-catch autour de l'analyse d'image

## 🧪 Comment tester

### Étape 1 : Recompiler
```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release
```

### Étape 2 : Installer et lancer les logs
```bash
# Installer l'APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Lancer les logs en temps réel
adb logcat -s ScreenCaptureService:D ScreenCaptureChannel:D flutter:I
```

### Étape 3 : Tester le flux complet

1. Ouvrez QRFlow
2. Allez dans "Scanner l'écran"
3. Activez la bulle flottante
4. Ouvrez une autre app avec un QR code (par exemple Google Keep avec une note contenant un QR code)
5. Appuyez sur la bulle Q
6. Acceptez le consentement MediaProjection
7. **Observez les logs** pour voir où ça bloque

## 📊 Logs attendus (flux normal)

```
ScreenCaptureChannel: captureScreen appelé, isRunning=false
ScreenCaptureChannel: Demande de consentement MediaProjection
[Utilisateur accepte]
ScreenCaptureService: Capture enregistrée: /data/user/0/com.qrflow.qrflow_mobile/cache/qrflow/capture_1234567890.png
ScreenCaptureService: Chemin enregistré dans SharedPreferences
[Application revient au premier plan]
ScreenCaptureBridge: Demande de capture en attente...
ScreenCaptureChannel: getPendingCapture appelé, path=/data/user/0/com.qrflow.qrflow_mobile/cache/qrflow/capture_1234567890.png
ScreenCaptureChannel: Chemin consommé: /data/user/0/com.qrflow.qrflow_mobile/cache/qrflow/capture_1234567890.png
ScreenCaptureBridge: Chemin reçu: /data/user/0/...
[Analyse du QR code]
[Navigation vers ResultScreen]
```

## 🔍 Points de vérification

### Si aucun log n'apparaît
→ Le service de capture ne démarre pas correctement
→ Vérifier les permissions dans AndroidManifest.xml

### Si "Capture enregistrée" apparaît mais pas "getPendingCapture"
→ L'application ne revient pas au premier plan
→ Ou `didChangeAppLifecycleState` n'est pas appelé

### Si "Chemin reçu: null"
→ Le fichier n'a pas été enregistré dans SharedPreferences
→ Ou il a été consommé par un autre appel

### Si "Erreur lors de l'analyse"
→ Le fichier existe mais mobile_scanner ne peut pas le lire
→ Vérifier le format de l'image
→ Vérifier les permissions de lecture

### Si "Aucun QR code détecté"
→ La capture fonctionne mais :
  - Le QR code est trop petit
  - Le QR code est flou
  - L'écran capturé ne contenait pas le QR code au bon moment

## 🛠️ Solutions par scénario

### Scénario 1 : Le service ne capture pas
```kotlin
// Vérifier dans MainActivity.kt
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    if (intent.action == ScreenCaptureChannel.ACTION_CAPTURE) {
        intent.action = null
        requestScreenCapture()  // ← Cette ligne doit être appelée
    }
}
```

### Scénario 2 : La capture ne revient pas dans Flutter
```dart
// Vérifier que le widget est bien monté
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    print('DEBUG: App resumed');  // ← Devrait s'afficher
    _refreshState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        print('DEBUG: Checking pending capture');  // ← Devrait s'afficher
        _checkPendingCapture();
      }
    });
  }
}
```

### Scénario 3 : mobile_scanner ne détecte pas le QR
```dart
// Tester avec une image de QR code connue
final testPath = '/sdcard/Download/test_qr.png';
final controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
final capture = await controller.analyzeImage(testPath);
print('Barcodes trouvés: ${capture?.barcodes.length}');
```

## 🎯 Checklist de diagnostic

- [ ] Les logs Android apparaissent quand on appuie sur la bulle
- [ ] "Capture enregistrée" apparaît dans les logs
- [ ] "Chemin enregistré dans SharedPreferences" apparaît
- [ ] L'app revient au premier plan (resumed)
- [ ] "getPendingCapture appelé" apparaît
- [ ] Le chemin retourné n'est pas null
- [ ] Le fichier existe sur le système de fichiers
- [ ] mobile_scanner réussit à analyser l'image
- [ ] Au moins un QR code est détecté
- [ ] Le résultat est affiché

## 💡 Test alternatif simple

Pour tester si le problème vient de la bulle ou du flux complet, testez d'abord le mode "Depuis une capture" :

1. Faites une capture d'écran normale (bouton Power + Volume -)
2. Ouvrez QRFlow
3. Allez dans "Depuis une capture"
4. Importez la capture d'écran
5. Vérifiez si le QR code est détecté

Si ça fonctionne → Le problème est dans le flux de la bulle
Si ça ne fonctionne pas → Le problème est dans mobile_scanner

## 📝 Fichiers modifiés

1. `mobile/lib/features/screen_scan/screen_scan_screen.dart`
   - Ajout délai 500ms
   - Amélioration gestion d'erreurs
   - Vérification existence fichier

2. `mobile/lib/core/platform/screen_capture_bridge.dart`
   - Ajout logs debugPrint

3. `mobile/android/app/src/main/kotlin/com/qrflow/app/ScreenCaptureService.kt`
   - Ajout logs
   - Ajout délai 200ms avant capture
   - Try-catch autour de savePng

4. `mobile/android/app/src/main/kotlin/com/qrflow/app/ScreenCaptureChannel.kt`
   - Ajout logs pour tracer les appels

---

**Prochaine étape :** Recompiler, tester et observer les logs pour identifier précisément où le flux se bloque.
