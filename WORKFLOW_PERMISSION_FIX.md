# ⚠️ Erreur de Permission GitHub Workflow

## 🔴 Problème Rencontré

Lors du push des workflows GitHub Actions, l'erreur suivante apparaît :

```
! [remote rejected] main -> main (refusing to allow a Personal Access Token 
to create or update workflow `.github/workflows/README.md` without `workflow` scope)
```

## 🔍 Cause

Le **Personal Access Token (PAT)** utilisé n'a pas le scope `workflow` nécessaire pour créer ou modifier des fichiers de workflow GitHub Actions dans le dossier `.github/workflows/`.

## ✅ Solution

### Option 1 : Mettre à Jour le Token Existant (Recommandé)

1. **Aller sur GitHub.com**
   - https://github.com/settings/tokens

2. **Trouver votre token actuel**
   - Cliquez sur le token utilisé pour ce projet

3. **Ajouter le scope `workflow`**
   - Cochez la case `workflow`
   - Cliquez sur "Update token"

4. **Utiliser le token mis à jour**
   ```bash
   # Mettre à jour les credentials Git
   git config credential.helper store
   git push origin main
   # Entrez votre username et le nouveau token quand demandé
   ```

---

### Option 2 : Créer un Nouveau Token

1. **Aller sur GitHub.com**
   - https://github.com/settings/tokens
   - Cliquez sur "Generate new token" > "Generate new token (classic)"

2. **Configurer le token**
   - **Note :** "QRFlow Workflow Token"
   - **Expiration :** 90 jours (ou selon votre préférence)
   - **Scopes à cocher :**
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows)
     - ✅ `write:packages` (si vous utilisez GitHub Packages)

3. **Générer et copier le token**
   - Cliquez sur "Generate token"
   - **Copiez le token immédiatement** (vous ne pourrez plus le voir après)

4. **Utiliser le nouveau token**
   ```bash
   # Option A : Via Git credential helper
   git push origin main
   # Username: votre_username_github
   # Password: collez_votre_nouveau_token
   
   # Option B : Mettre à jour l'URL remote
   git remote set-url origin https://VOTRE_TOKEN@github.com/Marilin66/QRFlow.git
   git push origin main
   ```

---

### Option 3 : Utiliser GitHub CLI (gh) - Plus Simple

```bash
# Installer GitHub CLI si pas déjà fait
# Windows: winget install --id GitHub.cli

# Se connecter
gh auth login
# Suivez les instructions interactives

# Pousser les changements
git push origin main
```

---

### Option 4 : Push via l'Interface Web (Temporaire)

Si vous voulez juste ajouter les workflows rapidement :

1. **Aller sur GitHub.com**
   - https://github.com/Marilin66/QRFlow

2. **Créer les fichiers manuellement**
   - Cliquez sur "Add file" > "Create new file"
   - Nom : `.github/workflows/build-android.yml`
   - Copiez-collez le contenu du fichier local
   - Commitez

3. **Répéter pour chaque workflow**
   - `build-android.yml`
   - `tests.yml`
   - `build-web.yml`
   - `README.md` (dans `.github/workflows/`)

---

## 🔧 Vérifier les Permissions Actuelles

```bash
# Voir la configuration Git actuelle
git config --list | grep credential

# Tester la connexion GitHub
gh auth status

# Voir les scopes du token actuel (avec gh)
gh auth token
```

---

## 📝 Scopes Recommandés pour le Développement

Pour un projet complet, votre PAT devrait avoir :

| Scope | Description | Nécessaire pour |
|-------|-------------|-----------------|
| ✅ `repo` | Accès complet aux repos | Push, pull, clone |
| ✅ `workflow` | Modifier workflows | GitHub Actions |
| ⚪ `write:packages` | Publier packages | GitHub Packages (optionnel) |
| ⚪ `delete_repo` | Supprimer repos | Administration (optionnel) |

---

## 🎯 Après Avoir Mis à Jour le Token

Une fois le token mis à jour avec le scope `workflow` :

```bash
# 1. Vérifier le statut
git status

# 2. Pousser à nouveau
git push origin main

# 3. Vérifier sur GitHub
# Les workflows devraient maintenant apparaître dans l'onglet "Actions"
```

---

## ✅ Vérification

Pour confirmer que tout fonctionne :

1. **Push réussi**
   ```
   ✓ Pas d'erreur de permission
   ✓ Les fichiers sont sur GitHub
   ```

2. **Workflows visibles**
   - Allez sur https://github.com/Marilin66/QRFlow/actions
   - Vous devriez voir les 3 workflows :
     - Build Android APK
     - Tests & Quality
     - Build Web App

3. **Premier build déclenché**
   - Le push devrait automatiquement déclencher les workflows
   - Vérifiez qu'ils s'exécutent (ou attendent dans la queue)

---

## 🔒 Sécurité du Token

**Important :**
- ⚠️ Ne commitez JAMAIS votre token dans le code
- ⚠️ Ne partagez JAMAIS votre token publiquement
- ✅ Régénérez votre token si vous pensez qu'il a été exposé
- ✅ Utilisez des tokens avec le minimum de scopes nécessaires
- ✅ Définissez une date d'expiration

**Si votre token est exposé :**
1. Allez sur https://github.com/settings/tokens
2. Cliquez sur "Delete" pour le token compromis
3. Générez un nouveau token immédiatement

---

## 📚 Ressources

- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [GitHub CLI Documentation](https://cli.github.com/manual/)

---

## 💡 Solution Recommandée

**La solution la plus simple et sécurisée :**

```bash
# 1. Installer GitHub CLI
winget install --id GitHub.cli

# 2. Se connecter
gh auth login
# Choisir: GitHub.com > HTTPS > Login with web browser

# 3. Pousser
git push origin main
```

GitHub CLI gère automatiquement les tokens avec les bons scopes ! 🎉

---

**Une fois le problème résolu, les workflows seront automatiquement actifs et builderont l'APK à chaque push !** ✅
