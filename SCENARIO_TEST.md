# [TEST] Scénario de Test Complet - QRFlow Mobile

## [LIST] Vue d'ensemble

Ce document décrit tous les scénarios de test pour valider le fonctionnement complet de l'application QRFlow Mobile.

---

## [OK] Tests Unitaires (Automatisés)

### Test 1 : Analyse de Contenu QR

**Fichier :** `test/content_analyzer_test.dart`

**Tests couverts :**
- [OK] URLs (https, http, www, IP, extensions suspectes)
- [OK] Texte simple
- [OK] Numéros de téléphone (libre, tel:)
- [OK] E-mails (simple, mailto:, MATMSG)
- [OK] SMS (SMSTO:, sms:)
- [OK] Wi-Fi (WPA, WPA2, ouvert)
- [OK] Géolocalisation (geo:, GEO:)
- [OK] Contacts (vCard, MECARD)
- [OK] Calendrier (VEVENT)
- [OK] Applications (market://)

**Commande :**
```bash
cd mobile
flutter test test/content_analyzer_test.dart
```

**Résultat attendu :** Tous les tests passent (31 tests)

---

## [MOBILE] Tests d'Interface (Manuels)

### Test 2 : Écran d'Accueil

**Étapes :**
1. Lancer l'application
2. Vérifier que l'écran d'accueil s'affiche
3. Vérifier la présence de 2 options principales :
   - [CAMERA] "Depuis une capture"
   - [MOBILE] "Scanner l'écran"
4. Vérifier la présence des boutons :
   - Historique
   - Paramètres
   - Aide

**Résultat attendu :**
- [OK] Interface Material 3 affichée
- [OK] Tous les boutons visibles et cliquables
- [OK] Navigation fluide

---

### Test 3 : Mode "Depuis une Capture"

#### Test 3.1 : Import d'Image avec QR Code

**Étapes :**
1. Depuis l'accueil, appuyer sur "Depuis une capture"
2. Sélectionner "Choisir une image"
3. Sélectionner une image contenant un QR code
4. Attendre l'analyse

**Résultat attendu :**
- [OK] Sélecteur de fichiers s'ouvre
- [OK] Image chargée
- [OK] QR code détecté
- [OK] Contenu analysé et affiché
- [OK] Navigation vers écran de résultat

#### Test 3.2 : Image sans QR Code

**Étapes :**
1. Sélectionner une image sans QR code
2. Attendre l'analyse

**Résultat attendu :**
- [OK] Message "Aucun QR code détecté" affiché
- [OK] Proposition de réessayer

#### Test 3.3 : Annulation de l'Import

**Étapes :**
1. Appuyer sur "Depuis une capture"
2. Appuyer sur retour dans le sélecteur

**Résultat attendu :**
- [OK] Retour à l'écran précédent
- [OK] Pas de crash

---

### Test 4 : Mode Scan Caméra

**Étapes :**
1. Depuis l'accueil, cliquer sur l'icône caméra
2. Accorder la permission caméra si demandée
3. Pointer la caméra vers un QR code
4. Attendre la détection automatique

**Résultat attendu :**
- [OK] Demande de permission caméra
- [OK] Aperçu caméra affiché
- [OK] Détection automatique du QR code
- [OK] Navigation vers écran de résultat
- [OK] Pas de crash si permission refusée

---

### Test 5 : Mode "Scanner l'Écran" (Bulle Flottante)

#### Test 5.1 : Activation de la Permission

**Étapes :**
1. Depuis l'accueil, appuyer sur "Scanner l'écran"
2. Lire les instructions
3. Appuyer sur "Accorder la permission"
4. Dans les paramètres Android, rechercher "QRFlow"
5. Activer la permission "Afficher par-dessus les autres applications"
6. Revenir dans l'app

**Résultat attendu :**
- [OK] QRFlow apparaît dans la liste des applications [*] (CORRIGÉ)
- [OK] Permission accordée
- [OK] État mis à jour dans l'app

#### Test 5.2 : Activation de la Bulle

**Étapes :**
1. Après avoir accordé la permission
2. Appuyer sur "Activer la bulle flottante"
3. Vérifier que la bulle "QR" apparaît

**Résultat attendu :**
- [OK] Bulle "QR" visible (80dp - taille d'icône) [*] (AMÉLIORÉ)
- [OK] Bulle déplaçable
- [OK] Notification "Bulle QRFlow active" affichée
- [OK] Message d'instruction affiché

#### Test 5.3 : Capture d'Écran avec la Bulle

**Préparation :**
- Ouvrir une autre app affichant un QR code (exemple : Google Keep, navigateur web)

**Étapes :**
1. Avec la bulle activée, ouvrir l'app avec le QR code
2. Appuyer sur la bulle "QR"
3. Accorder le consentement MediaProjection (si première fois)
4. Attendre

**Résultat attendu :**
- [OK] Consentement MediaProjection demandé
- [OK] Pastille système visible (Android 15+)
- [OK] Capture effectuée
- [OK] Retour automatique dans QRFlow [*] (CORRIGÉ)
- [OK] Image analysée [*] (CORRIGÉ)
- [OK] QR code détecté [*] (CORRIGÉ)
- [OK] Résultat affiché [*] (CORRIGÉ)

#### Test 5.4 : Désactivation de la Bulle

**Étapes :**
1. Dans "Scanner l'écran", appuyer sur "Désactiver la bulle"

**Résultat attendu :**
- [OK] Bulle disparaît
- [OK] Notification disparaît
- [OK] État mis à jour

---

### Test 6 : Écran de Résultat

#### Test 6.1 : URL

**QR Test :** `https://www.google.com`

**Résultat attendu :**
- [OK] Type détecté : "URL"
- [OK] Domaine affiché : "www.google.com"
- [OK] Icône [WEB]
- [OK] Boutons : "Ouvrir le lien", "Copier", "Partager"
- [OK] Sécurité : "Sécurisé (HTTPS)"

**Test d'action :**
- Appuyer sur "Ouvrir le lien" -> [OK] Confirmation puis ouverture navigateur

#### Test 6.2 : Téléphone

**QR Test :** `tel:+33612345678`

**Résultat attendu :**
- [OK] Type : "Numéro de téléphone"
- [OK] Numéro affiché : "+33612345678"
- [OK] Icône [PHONE]
- [OK] Boutons : "Appeler", "SMS", "Copier"

**Test d'action :**
- Appuyer sur "Appeler" -> [OK] Confirmation puis ouverture téléphone

#### Test 6.3 : E-mail

**QR Test :** `mailto:contact@example.com?subject=Hello`

**Résultat attendu :**
- [OK] Type : "Adresse e-mail"
- [OK] Adresse : "contact@example.com"
- [OK] Sujet : "Hello"
- [OK] Boutons : "Composer", "Copier"

#### Test 6.4 : Wi-Fi

**QR Test :** `WIFI:T:WPA;S:MonReseau;P:MotDePasse123;;`

**Résultat attendu :**
- [OK] Type : "Réseau Wi-Fi"
- [OK] SSID : "MonReseau"
- [OK] Sécurité : "WPA"
- [OK] Mot de passe affiché
- [OK] Bouton : "Se connecter"

#### Test 6.5 : Contact (vCard)

**QR Test :**
```
BEGIN:VCARD
VERSION:3.0
FN:Jean Dupont
TEL:+33612345678
EMAIL:jean@example.com
END:VCARD
```

**Résultat attendu :**
- [OK] Type : "Contact"
- [OK] Nom : "Jean Dupont"
- [OK] Téléphone : "+33612345678"
- [OK] E-mail : "jean@example.com"
- [OK] Bouton : "Ajouter aux contacts"

#### Test 6.6 : Géolocalisation

**QR Test :** `geo:48.8584,2.2945`

**Résultat attendu :**
- [OK] Type : "Géolocalisation"
- [OK] Latitude : 48.8584
- [OK] Longitude : 2.2945
- [OK] Bouton : "Ouvrir dans Maps"

#### Test 6.7 : SMS

**QR Test :** `SMSTO:+33612345678:Bonjour`

**Résultat attendu :**
- [OK] Type : "SMS"
- [OK] Numéro : "+33612345678"
- [OK] Message : "Bonjour"
- [OK] Bouton : "Envoyer SMS"

#### Test 6.8 : Calendrier

**QR Test :**
```
BEGIN:VEVENT
SUMMARY:Réunion
DTSTART:20260815T100000Z
DTEND:20260815T110000Z
LOCATION:Bureau 3
END:VEVENT
```

**Résultat attendu :**
- [OK] Type : "Événement"
- [OK] Titre : "Réunion"
- [OK] Date et heure affichées
- [OK] Lieu : "Bureau 3"
- [OK] Bouton : "Ajouter au calendrier"

#### Test 6.9 : Texte Simple

**QR Test :** `Ceci est un simple texte`

**Résultat attendu :**
- [OK] Type : "Texte"
- [OK] Contenu affiché
- [OK] Boutons : "Copier", "Partager"

---

### Test 7 : Historique

**Étapes :**
1. Scanner plusieurs QR codes
2. Aller dans "Historique"
3. Vérifier la liste

**Résultat attendu :**
- [OK] Tous les scans affichés
- [OK] Date et heure pour chaque entrée
- [OK] Type et aperçu du contenu
- [OK] Méthode de scan indiquée (capture/écran/caméra)
- [OK] Clic sur une entrée -> Ouvre le résultat
- [OK] Bouton de suppression individuelle
- [OK] Recherche fonctionnelle
- [OK] Bouton "Tout supprimer"

**Test de suppression :**
1. Appuyer sur "Tout supprimer"
2. Confirmer

**Résultat :**
- [OK] Confirmation demandée
- [OK] Historique vidé
- [OK] Message "Aucun historique"

---

### Test 8 : Paramètres

#### Test 8.1 : Thème

**Étapes :**
1. Aller dans "Paramètres"
2. Section "Apparence"
3. Changer le thème

**Résultat attendu :**
- [OK] Thème système (défaut)
- [OK] Thème clair
- [OK] Thème sombre
- [OK] Changement immédiat

#### Test 8.2 : Scanner

**Options disponibles :**
- [OK] Confirmation avant action (activé par défaut)
- [OK] Détection de plusieurs QR codes (activé par défaut)

#### Test 8.3 : Bulle Flottante

**Options :**
1. Activer/désactiver la bulle
2. Taille de la bulle : 56-120 dp
3. Opacité : 40-100%

**Test :**
1. Changer la taille à 100 dp
2. Activer la bulle
3. Vérifier la taille

**Résultat :**
- [OK] Bulle plus grande
- [OK] Changement immédiat

#### Test 8.4 : Historique

**Options :**
- [OK] Conserver l'historique
- [OK] Durée de conservation (30j/90j/1an/illimité)
- [OK] Supprimer tout

#### Test 8.5 : Sécurité

**Options :**
- [OK] Avertir pour les URL suspectes (activé par défaut)

**Test :**
1. Scanner un QR avec URL suspecte : `http://192.168.1.1/admin`

**Résultat :**
- [OK] Avertissement de sécurité affiché

---

### Test 9 : Aide

**Étapes :**
1. Aller dans "Aide"
2. Lire les sections

**Résultat attendu :**
- [OK] Instructions claires
- [OK] Exemples d'utilisation
- [OK] FAQ
- [OK] Contact/support

---

### Test 10 : Gestion des Permissions

#### Test 10.1 : Permission Caméra Refusée

**Étapes :**
1. Refuser la permission caméra
2. Essayer d'ouvrir le scan caméra

**Résultat :**
- [OK] Message d'erreur clair
- [OK] Instructions pour accorder la permission
- [OK] Pas de crash

#### Test 10.2 : Permission Overlay Refusée

**Étapes :**
1. Ne pas accorder la permission overlay
2. Essayer d'activer la bulle

**Résultat :**
- [OK] Message d'erreur clair
- [OK] Redirection vers paramètres
- [OK] Pas de crash

---

### Test 11 : Gestion des Erreurs

#### Test 11.1 : QR Code Invalide

**Test :** Scanner un QR code corrompu

**Résultat :**
- [OK] Message "QR code invalide"
- [OK] Proposition de réessayer
- [OK] Pas de crash

#### Test 11.2 : Image Trop Petite

**Test :** Image avec QR code très petit

**Résultat :**
- [OK] Message "QR code trop petit"
- [OK] Conseil d'utiliser une meilleure image
- [OK] Pas de crash

#### Test 11.3 : Pas de Connexion (Actions Réseau)

**Test :** Tenter d'ouvrir une URL sans connexion

**Résultat :**
- [OK] Erreur du navigateur (comportement natif)
- [OK] QRFlow ne crash pas

---

### Test 12 : Cycle de Vie de l'Application

#### Test 12.1 : Mise en Arrière-Plan

**Étapes :**
1. Ouvrir QRFlow
2. Appuyer sur Home
3. Rouvrir QRFlow

**Résultat :**
- [OK] État préservé
- [OK] Pas de crash
- [OK] Retour à l'écran précédent

#### Test 12.2 : Rotation d'Écran

**Étapes :**
1. Tourner l'écran en mode paysage
2. Tourner en mode portrait

**Résultat :**
- [OK] Interface s'adapte
- [OK] Pas de perte de données
- [OK] Pas de crash

---

## [TARGET] Checklist Finale de Validation

### Fonctionnalités Principales
- [ ] Import de capture d'écran
- [ ] Scan caméra en direct
- [ ] Bulle flottante (permission) [*]
- [ ] Capture MediaProjection [*]
- [ ] Détection QR code [*]
- [ ] Analyse intelligente du contenu
- [ ] Actions par type de contenu
- [ ] Historique SQLite
- [ ] Recherche dans historique
- [ ] Paramètres persistés

### Types de Contenu Supportés
- [ ] URL (sécurisée/non sécurisée/suspecte)
- [ ] Texte simple
- [ ] Téléphone
- [ ] E-mail (simple/mailto/MATMSG)
- [ ] SMS (SMSTO/sms:)
- [ ] Wi-Fi (WPA/WPA2/ouvert)
- [ ] Contact (vCard/MECARD)
- [ ] Géolocalisation (geo:/GEO:)
- [ ] Calendrier (VEVENT)
- [ ] Application (market://)

### Interface Utilisateur
- [ ] Thème clair/sombre/système
- [ ] Material 3
- [ ] Navigation fluide
- [ ] Messages d'erreur clairs
- [ ] Confirmations avant actions
- [ ] Animations légères

### Sécurité
- [ ] Aucune action automatique
- [ ] Confirmation obligatoire
- [ ] Détection URL suspectes
- [ ] Respect des permissions Android
- [ ] Pas de fuite de données

### Performance
- [ ] Lancement rapide
- [ ] Détection QR rapide
- [ ] Pas de lag
- [ ] Utilisation mémoire raisonnable
- [ ] Batterie non impactée excessivement

### Robustesse
- [ ] Pas de crash
- [ ] Gestion erreurs complète
- [ ] Récupération après erreur
- [ ] État préservé

---

## [CHART] Résultats Attendus

### Tests Unitaires
```bash
cd mobile
flutter test
```

**Résultat attendu :**
```
[OK] Tous les tests passent
[OK] 31+ tests
[OK] Couverture > 80% pour core/services
```

### Tests d'Intégration

**Résultat attendu :**
```
[OK] 12/12 scénarios principaux validés
[OK] 40+ tests d'interface réussis
[OK] 0 crash détecté
[OK] Toutes les fonctionnalités opérationnelles
```

---

## [=>] Commande de Test Complète

```bash
# 1. Tests unitaires
cd mobile
flutter test

# 2. Build APK de test
flutter build apk --debug

# 3. Installer et tester
adb install build/app/outputs/flutter-apk/app-debug.apk

# 4. Observer les logs pendant les tests
adb logcat -s ScreenCaptureService:D ScreenCaptureChannel:D flutter:I
```

---

## [OK] Déclaration de Fonctionnalité

**Après avoir suivi tous les scénarios de test ci-dessus, si aucun échec n'est rencontré :**

> [OK] **L'APPLICATION QRFLOW MOBILE EST FONCTIONNELLE**
> 
> - [OK] Toutes les fonctionnalités principales opérationnelles
> - [OK] Bulle flottante fonctionnelle avec permission corrigée
> - [OK] Capture et analyse d'écran opérationnelles
> - [OK] Détection intelligente de tous les types de QR codes
> - [OK] Interface utilisateur complète et polie
> - [OK] Aucun crash détecté
> - [OK] Sécurité respectée
> - [OK] Prête pour utilisation

**Date de validation :** [À compléter après tests]  
**Version testée :** 0.1.0+1  
**Plateforme :** Android  
**Testeur :** [Nom]

---

**Note :** Les éléments marqués [*] ont été spécifiquement corrigés dans les derniers commits.
