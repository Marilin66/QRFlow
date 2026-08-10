# ✅ Solution au problème de permission "Afficher par-dessus les applications"

## 🔍 Problème identifié

L'application QRFlow n'apparaissait pas dans la liste des applications dans les paramètres Android pour accorder la permission "Afficher par-dessus les autres applications".

## ⚠️ Cause

La permission `SYSTEM_ALERT_WINDOW` était **manquante** dans le fichier `AndroidManifest.xml`.

Sans cette permission déclarée dans le manifest, Android ne propose pas l'application dans la liste des paramètres, même si le code demande correctement la permission.

## ✅ Solution appliquée

J'ai ajouté la ligne suivante dans `mobile/android/app/src/main/AndroidManifest.xml` :

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

Cette permission a été placée **avant** les permissions de services au premier plan.

## 🔧 Prochaines étapes pour tester

### 1. Désinstaller l'ancienne version
Sur votre téléphone Android :
```
Paramètres → Applications → QRFlow → Désinstaller
```

OU utilisez adb :
```bash
adb uninstall com.qrflow.qrflow_mobile
```

### 2. Recompiler l'APK
```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release
```

### 3. Installer la nouvelle version
L'APK se trouve dans : `mobile/build/app/outputs/flutter-apk/app-release.apk`

Transférez-le sur votre téléphone et installez-le.

OU via adb :
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 4. Tester la fonctionnalité

1. Ouvrez l'application QRFlow
2. Appuyez sur **"Scanner l'écran"**
3. Appuyez sur **"Accorder la permission"**
4. Android devrait maintenant vous rediriger vers les paramètres système
5. **Votre application "QRFlow" devrait maintenant apparaître dans la liste** ✅
6. Activez la permission
7. Revenez dans l'application
8. Appuyez sur **"Activer la bulle flottante"**

## 📱 Vérification manuelle (alternative)

Si vous voulez vérifier manuellement que l'application apparaît maintenant :

```
Paramètres Android
  → Applications
    → Accès spécial
      → Afficher par-dessus les autres applications
        → QRFlow devrait maintenant être dans la liste ✅
```

## 🎯 Pourquoi cette permission est nécessaire

La permission `SYSTEM_ALERT_WINDOW` est **obligatoire** pour :
- Afficher une bulle flottante par-dessus les autres applications
- Apparaître dans les paramètres système Android
- Permettre à l'utilisateur d'accorder explicitement cette autorisation

Sans cette déclaration dans le manifest, l'application ne peut pas demander cette permission, même si le code Kotlin est correct.

## 📝 Code modifié

**Fichier modifié** : `mobile/android/app/src/main/AndroidManifest.xml`

**Ligne ajoutée** (ligne ~11) :
```xml
<!-- Overlay / Bulle flottante (CRITIQUE : requis pour apparaître dans les paramètres) -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

## ✅ Résultat attendu

Après cette modification et la réinstallation :
1. ✅ QRFlow apparaît dans la liste des applications dans les paramètres système
2. ✅ L'utilisateur peut accorder la permission "Afficher par-dessus les autres applications"
3. ✅ La bulle flottante peut être activée
4. ✅ La fonctionnalité de scan d'écran fonctionne complètement

---

**Date de correction** : 10 août 2026  
**Fichiers modifiés** : 1 (`AndroidManifest.xml`)  
**Lignes ajoutées** : 2
