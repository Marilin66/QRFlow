# 🚀 Solution pour Pousser les GitHub Actions

## ⚠️ Problème Actuel

Le push des workflows GitHub Actions a échoué car le token n'a pas le scope `workflow`.

```
! [remote rejected] main -> main (refusing to allow a Personal Access Token 
to create or update workflow without `workflow` scope)
```

---

## ✅ Solution Rapide : GitHub Web Interface

**La façon la plus simple sans changer de token :**

### Étape 1 : Créer les Workflows Manuellement sur GitHub

1. **Allez sur GitHub**
   - https://github.com/Marilin66/QRFlow

2. **Créer le dossier .github/workflows**
   - Cliquez sur "Add file" > "Create new file"
   - Dans le nom du fichier, tapez : `.github/workflows/build-android.yml`
   - GitHub créera automatiquement les dossiers

3. **Copier le contenu de build-android.yml**
   - Ouvrez le fichier local : `c:\Users\BADJI\Desktop\QRFlow\.github\workflows\build-android.yml`
   - Copiez tout le contenu
   - Collez-le dans l'éditeur GitHub
   - Message de commit : "ci: add Android build workflow"
   - Cliquez sur "Commit new file"

4. **Répéter pour les autres fichiers**
   
   **Fichier 2 : tests.yml**
   - Create new file : `.github/workflows/tests.yml`
   - Copier le contenu depuis le fichier local
   - Commit

   **Fichier 3 : build-web.yml**
   - Create new file : `.github/workflows/build-web.yml`
   - Copier le contenu depuis le fichier local
   - Commit

   **Fichier 4 : README.md (dans workflows)**
   - Create new file : `.github/workflows/README.md`
   - Copier le contenu depuis le fichier local
   - Commit

### Étape 2 : Mettre à Jour Votre Repo Local

```bash
# Récupérer les changements de GitHub
git pull origin main

# Vérifier que les workflows sont là
ls .github/workflows/

# Ajouter les fichiers de documentation
git add GITHUB_ACTIONS.md WORKFLOW_PERMISSION_FIX.md PUSH_WORKFLOWS_SOLUTION.md

# Commit
git commit -m "docs: add GitHub Actions documentation"

# Push (devrait fonctionner maintenant car ce ne sont que des docs)
git push origin main
```

---

## 🎯 Résultat Attendu

Une fois les workflows ajoutés sur GitHub :

1. **Vérifier dans Actions**
   - Allez sur https://github.com/Marilin66/QRFlow/actions
   - Vous devriez voir :
     - ✅ Build Android APK
     - ✅ Tests & Quality
     - ✅ Build Web App

2. **Premier Build Automatique**
   - Le dernier commit devrait déclencher automatiquement les workflows
   - Attendez quelques minutes
   - Vérifiez le statut dans l'onglet Actions

3. **Télécharger l'APK**
   - Une fois le build terminé (✅)
   - Cliquez sur le workflow "Build Android APK"
   - Section "Artifacts" en bas de page
   - Téléchargez `qrflow-release-apk`

---

## 🔄 Alternative : Installer GitHub CLI (Pour le Futur)

Pour éviter ce problème à l'avenir, installez GitHub CLI :

```powershell
# Installer GitHub CLI
winget install --id GitHub.cli

# Se connecter (ouvre le navigateur)
gh auth login

# Vérifier
gh auth status

# Maintenant vous pouvez push sans problème
git push origin main
```

**Avantages de GitHub CLI :**
- ✅ Gère automatiquement les tokens avec les bons scopes
- ✅ Plus sécurisé
- ✅ Pas besoin de gérer manuellement les PAT
- ✅ Commandes pratiques (`gh workflow run`, `gh run list`, etc.)

---

## 📝 Contenu des Fichiers à Créer

### build-android.yml
```yaml
name: Build Android APK

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'mobile/**'
      - '.github/workflows/build-android.yml'
  pull_request:
    branches: [ main ]
    paths:
      - 'mobile/**'
  workflow_dispatch:

jobs:
  build:
    name: Build APK
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'
          cache: 'gradle'
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true
      
      - name: Flutter doctor
        run: flutter doctor -v
      
      - name: Get dependencies
        working-directory: mobile
        run: flutter pub get
      
      - name: Run tests
        working-directory: mobile
        run: flutter test
      
      - name: Build APK Debug
        working-directory: mobile
        run: flutter build apk --debug
      
      - name: Build APK Release
        working-directory: mobile
        run: flutter build apk --release
      
      - name: Upload Debug APK
        uses: actions/upload-artifact@v4
        with:
          name: qrflow-debug-apk
          path: mobile/build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 30
      
      - name: Upload Release APK
        uses: actions/upload-artifact@v4
        with:
          name: qrflow-release-apk
          path: mobile/build/app/outputs/flutter-apk/app-release.apk
          retention-days: 90
      
      - name: Create Release (if tag)
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: |
            mobile/build/app/outputs/flutter-apk/app-release.apk
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### tests.yml
```yaml
name: Tests & Quality

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true
      
      - name: Get dependencies
        working-directory: mobile
        run: flutter pub get
      
      - name: Analyze code
        working-directory: mobile
        run: flutter analyze
      
      - name: Run tests
        working-directory: mobile
        run: flutter test --coverage
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: mobile/coverage/lcov.info
          flags: mobile
          name: qrflow-mobile
          fail_ci_if_error: false
```

### build-web.yml
```yaml
name: Build Web App

on:
  push:
    branches: [ main ]
    paths:
      - 'web/**'
      - '.github/workflows/build-web.yml'
  workflow_dispatch:

jobs:
  build:
    name: Build Web
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: web/package-lock.json
      
      - name: Install dependencies
        working-directory: web
        run: npm ci
      
      - name: Build
        working-directory: web
        run: npm run build
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: qrflow-web-dist
          path: web/dist/
          retention-days: 30
      
      - name: Deploy to GitHub Pages (optional)
        if: github.ref == 'refs/heads/main'
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./web/dist
```

---

## ✅ Checklist de Validation

Après avoir créé les workflows sur GitHub :

- [ ] Les 3 workflows sont visibles dans l'onglet Actions
- [ ] Un workflow s'est déclenché automatiquement
- [ ] Le workflow "Build Android APK" s'exécute (ou est en attente)
- [ ] Après quelques minutes, le build est terminé (✅)
- [ ] Les artifacts APK sont disponibles en téléchargement
- [ ] Les badges dans le README s'affichent correctement

---

## 🎉 Une Fois Configuré

**À chaque push sur `main` :**
1. ✅ Les tests s'exécutent automatiquement
2. ✅ L'APK est compilé automatiquement
3. ✅ L'APK est disponible en téléchargement dans Actions
4. ✅ Plus besoin de compiler localement !

**Pour télécharger un APK :**
1. GitHub.com → QRFlow → Actions
2. "Build Android APK" → Dernière exécution
3. Artifacts → "qrflow-release-apk"
4. Télécharger et installer sur Android

---

**C'est tout ! Les workflows seront opérationnels dès qu'ils seront sur GitHub.** 🚀
