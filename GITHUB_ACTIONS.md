# 🤖 GitHub Actions - Guide Complet

## [LIST] Vue d'ensemble

Ce projet utilise **GitHub Actions** pour automatiser les builds et les tests à chaque push. Cela garantit que l'application peut toujours être compilée et que les tests passent.

---

## [~] Workflows Configurés

### 1. [BUILD] Build Android APK

**Fichier :** `.github/workflows/build-android.yml`

**Quand s'exécute-t-il ?**
- [OK] À chaque push sur `main` ou `develop` qui modifie des fichiers dans `mobile/`
- [OK] À chaque Pull Request vers `main`
- [OK] Manuellement depuis l'onglet Actions

**Que fait-il ?**
1. Installe Java 17
2. Installe Flutter 3.24.0
3. Récupère les dépendances (`flutter pub get`)
4. Exécute les tests (`flutter test`)
5. Compile l'APK Debug
6. Compile l'APK Release
7. Upload les APKs comme artifacts

**Résultats :**
- APK Debug disponible pendant 30 jours
- APK Release disponible pendant 90 jours

---

### 2. [TEST] Tests & Quality

**Fichier :** `.github/workflows/tests.yml`

**Quand s'exécute-t-il ?**
- [OK] À chaque push sur `main` ou `develop`
- [OK] À chaque Pull Request

**Que fait-il ?**
1. Analyse le code (`flutter analyze`)
2. Exécute tous les tests unitaires
3. Génère un rapport de couverture de code
4. Upload la couverture vers Codecov (optionnel)

---

### 3. [WEB] Build Web App

**Fichier :** `.github/workflows/build-web.yml`

**Quand s'exécute-t-il ?**
- [OK] À chaque push sur `main` qui modifie des fichiers dans `web/`
- [OK] Manuellement depuis l'onglet Actions

**Que fait-il ?**
1. Installe Node.js 20
2. Installe les dépendances npm
3. Compile l'application web
4. Upload le build comme artifact
5. Déploie sur GitHub Pages (optionnel)

---

## 📥 Comment Télécharger les APKs Buildés

### Méthode 1 : Via l'Interface GitHub

1. Allez sur https://github.com/Marilin66/QRFlow
2. Cliquez sur l'onglet **"Actions"**
3. Dans la liste de gauche, cliquez sur **"Build Android APK"**
4. Sélectionnez la dernière exécution avec une [OK] (checkmark vert)
5. Scrollez vers le bas jusqu'à la section **"Artifacts"**
6. Cliquez sur :
   - **qrflow-debug-apk** pour télécharger l'APK de debug
   - **qrflow-release-apk** pour télécharger l'APK de release

### Méthode 2 : Via l'API GitHub (avancé)

```bash
# Liste des artifacts
gh run list --workflow=build-android.yml

# Télécharger le dernier artifact
gh run download --name qrflow-release-apk
```

---

## [=>] Déclencher un Build Manuellement

### Via l'Interface Web

1. Allez dans l'onglet **Actions**
2. Sélectionnez le workflow souhaité (ex: "Build Android APK")
3. Cliquez sur le bouton **"Run workflow"** (à droite)
4. Sélectionnez la branche (généralement `main`)
5. Cliquez sur **"Run workflow"**

### Via GitHub CLI

```bash
# Déclencher le build Android
gh workflow run build-android.yml

# Déclencher les tests
gh workflow run tests.yml

# Déclencher le build web
gh workflow run build-web.yml
```

---

## [TAG] Créer une Release Automatique

Lorsque vous créez un tag Git, le workflow créera automatiquement une **GitHub Release** avec l'APK Release attaché.

### Étapes

```bash
# 1. Créer un tag avec la version
git tag -a v0.1.0 -m "Release version 0.1.0"

# 2. Pousser le tag sur GitHub
git push origin v0.1.0
```

**Résultat :**
- [OK] Une Release GitHub est créée automatiquement
- [OK] L'APK Release est attaché à la release
- [OK] Les notes de release sont générées automatiquement

**Accès :**
- Allez dans l'onglet **"Releases"** du repository
- La nouvelle release apparaît avec l'APK téléchargeable

---

## [CHART] Badges de Statut

Les badges suivants sont affichés dans le README.md :

```markdown
![Build Android](https://github.com/Marilin66/QRFlow/workflows/Build%20Android%20APK/badge.svg)
![Tests](https://github.com/Marilin66/QRFlow/workflows/Tests%20&%20Quality/badge.svg)
![Build Web](https://github.com/Marilin66/QRFlow/workflows/Build%20Web%20App/badge.svg)
```

**Signification des couleurs :**
- [OK] **Vert (passing)** : Le dernier build/test a réussi
- [ERROR] **Rouge (failing)** : Le dernier build/test a échoué
- [WAIT] **Jaune (running)** : Un build/test est en cours
- [ ] **Gris (no status)** : Aucun workflow exécuté récemment

---

## [SEARCH] Voir les Logs d'Exécution

### Pour déboguer un build qui échoue

1. Allez dans **Actions**
2. Cliquez sur le workflow qui a échoué ([ERROR])
3. Cliquez sur l'exécution spécifique
4. Cliquez sur le job "Build APK"
5. Vous verrez tous les steps :
   - [OK] Steps réussis
   - [ERROR] Steps échoués
6. Cliquez sur un step pour voir ses logs détaillés

**Les erreurs communes :**
- Tests qui échouent → Vérifier `Run tests`
- Problème de dépendances → Vérifier `Get dependencies`
- Problème de compilation → Vérifier `Build APK Release`

---

## [CONFIG] Configuration Avancée

### Changer la Version de Flutter

Dans `.github/workflows/build-android.yml` :

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.24.0'  # ← Changez ici
    channel: 'stable'
```

### Ajouter des Tests Supplémentaires

Dans `.github/workflows/tests.yml`, ajoutez après `flutter test` :

```yaml
- name: Run integration tests
  working-directory: mobile
  run: flutter test integration_test
```

### Modifier la Durée de Conservation des Artifacts

Dans `.github/workflows/build-android.yml` :

```yaml
- name: Upload Release APK
  uses: actions/upload-artifact@v4
  with:
    name: qrflow-release-apk
    path: mobile/build/app/outputs/flutter-apk/app-release.apk
    retention-days: 90  # ← Changez ici (max 90 jours)
```

### Builder sur Plus de Branches

Dans `.github/workflows/build-android.yml` :

```yaml
on:
  push:
    branches: [ main, develop, feature/* ]  # ← Ajoutez vos branches
```

---

## [LOCK] Sécurité et Permissions

### Permissions Requises

Les workflows utilisent `GITHUB_TOKEN` qui est automatiquement fourni par GitHub.

**Permissions nécessaires :**
- [OK] `contents: read` - Lire le code
- [OK] `actions: write` - Créer des artifacts
- [OK] `releases: write` - Créer des releases (pour les tags)

Ces permissions sont généralement accordées par défaut.

### Secrets

Aucun secret n'est requis pour les builds de base.

**Secrets optionnels :**
- `CODECOV_TOKEN` - Pour uploader la couverture de code sur Codecov
- `KEYSTORE_PASSWORD` - Pour signer les APKs (pas encore configuré)

**Ajouter un secret :**
1. Allez dans Settings > Secrets and variables > Actions
2. Cliquez sur "New repository secret"
3. Ajoutez le nom et la valeur
4. Utilisez-le dans le workflow avec `${{ secrets.NOM_SECRET }}`

---

## [UP] Statistiques et Métriques

### Voir l'Historique des Builds

1. Allez dans **Actions**
2. Sélectionnez un workflow
3. Vous verrez :
   - Combien de temps chaque build prend
   - Taux de succès/échec
   - Historique complet

### Temps d'Exécution Typique

- **Tests uniquement :** ~2-3 minutes
- **Build Debug APK :** ~5-7 minutes
- **Build Release APK :** ~8-10 minutes
- **Build Web :** ~2-3 minutes

---

## [BUG] Dépannage

### Le workflow ne se déclenche pas

**Vérifications :**
- [OK] Vos changements touchent-ils les bons fichiers ? (ex: `mobile/**`)
- [OK] Êtes-vous sur la bonne branche ? (`main` ou `develop`)
- [OK] Les workflows sont-ils activés ? (Settings > Actions)

### Le build échoue

**Étapes de diagnostic :**
1. Vérifiez les logs dans Actions
2. Recherchez les lignes en rouge (erreurs)
3. Testez localement : `flutter test` et `flutter build apk`
4. Vérifiez que toutes les dépendances sont à jour

### Les artifacts ne sont pas disponibles

**Raisons possibles :**
- Le build a échoué avant l'étape d'upload
- Les artifacts ont expiré (après 30-90 jours)
- Vous n'êtes pas connecté à GitHub

### Build lent

**Optimisations :**
- Le cache Flutter est activé (via `cache: true`)
- Le cache Gradle est activé (via `cache: 'gradle'`)
- Les artifacts sont uploadés en parallèle

---

## [DOCS] Ressources Utiles

### Documentation Officielle
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Flutter Action](https://github.com/subosito/flutter-action)
- [Upload Artifact Action](https://github.com/actions/upload-artifact)

### Actions Utilisées
- `actions/checkout@v4` - Récupère le code
- `actions/setup-java@v4` - Installe Java
- `subosito/flutter-action@v2` - Installe Flutter
- `actions/upload-artifact@v4` - Upload les artifacts
- `softprops/action-gh-release@v1` - Crée les releases

### Commandes Utiles
```bash
# Voir le statut des workflows
gh workflow list

# Voir les runs récents
gh run list

# Voir les logs d'un run
gh run view <run-id> --log

# Télécharger un artifact
gh run download <run-id>
```

---

## [OK] Checklist de Validation

Après avoir configuré GitHub Actions, vérifiez :

- [ ] Les workflows sont dans `.github/workflows/`
- [ ] Un push sur `main` déclenche le build Android
- [ ] Les tests s'exécutent automatiquement
- [ ] Les APKs sont disponibles dans les artifacts
- [ ] Les badges s'affichent dans le README
- [ ] Les logs sont accessibles dans Actions
- [ ] Vous pouvez télécharger les APKs buildés

---

## [TARGET] Résumé

**Avec GitHub Actions, vous avez maintenant :**

[OK] **Builds automatiques** - À chaque push  
[OK] **Tests automatiques** - Garantit la qualité  
[OK] **APKs disponibles** - Téléchargeables sans compiler localement  
[OK] **Releases automatiques** - Avec les tags Git  
[OK] **Historique complet** - De tous les builds  
[OK] **Badges de statut** - Visibilité du statut du projet  

**Plus besoin de compiler manuellement !** [=>]

---

**Dernière mise à jour :** 10 août 2026  
**Version :** 1.0
