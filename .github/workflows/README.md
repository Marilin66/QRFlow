# GitHub Actions Workflows

Ce dossier contient les workflows automatisés pour le projet QRFlow.

## [~] Workflows Disponibles

### 1. Build Android APK (`build-android.yml`)

**Déclenchement :**
- À chaque push sur `main` ou `develop` qui modifie `mobile/**`
- À chaque Pull Request vers `main`
- Manuellement depuis l'onglet Actions

**Actions effectuées :**
1. [OK] Installation de Java 17
2. [OK] Installation de Flutter 3.24.0
3. [OK] Récupération des dépendances (`flutter pub get`)
4. [OK] Exécution des tests (`flutter test`)
5. [OK] Build APK Debug
6. [OK] Build APK Release
7. [OK] Upload des APKs comme artifacts

**Artefacts générés :**
- `qrflow-debug-apk` (conservé 30 jours)
- `qrflow-release-apk` (conservé 90 jours)

**Télécharger les APKs :**
1. Allez dans l'onglet "Actions" du repo GitHub
2. Cliquez sur le workflow "Build Android APK"
3. Sélectionnez la dernière exécution réussie
4. Scrollez vers le bas jusqu'à "Artifacts"
5. Téléchargez l'APK souhaité

---

### 2. Tests & Quality (`tests.yml`)

**Déclenchement :**
- À chaque push sur `main` ou `develop`
- À chaque Pull Request vers `main`

**Actions effectuées :**
1. [OK] Installation de Flutter
2. [OK] Analyse du code (`flutter analyze`)
3. [OK] Exécution des tests avec couverture
4. [OK] Upload de la couverture vers Codecov (optionnel)

**Badge de statut :**
```markdown
![Tests](https://github.com/Marilin66/QRFlow/workflows/Tests%20&%20Quality/badge.svg)
```

---

### 3. Build Web App (`build-web.yml`)

**Déclenchement :**
- À chaque push sur `main` qui modifie `web/**`
- Manuellement depuis l'onglet Actions

**Actions effectuées :**
1. [OK] Installation de Node.js 20
2. [OK] Installation des dépendances npm
3. [OK] Build de l'app web (`npm run build`)
4. [OK] Upload du dossier `dist/` comme artifact
5. [OK] Déploiement sur GitHub Pages (optionnel)

**Artefacts générés :**
- `qrflow-web-dist` (conservé 30 jours)

---

## [=>] Utilisation

### Déclencher manuellement un build

1. Allez dans l'onglet **Actions** de votre repository
2. Sélectionnez le workflow souhaité (ex: "Build Android APK")
3. Cliquez sur **Run workflow**
4. Sélectionnez la branche
5. Cliquez sur **Run workflow**

### Voir l'historique des builds

1. Allez dans l'onglet **Actions**
2. Vous verrez tous les workflows exécutés
3. Cliquez sur un workflow pour voir les détails
4. Vous pouvez voir les logs de chaque étape

### Télécharger un APK buildé

1. Allez dans **Actions**
2. Cliquez sur le workflow "Build Android APK"
3. Sélectionnez une exécution réussie ([OK])
4. Scrollez vers le bas
5. Téléchargez l'artifact dans la section **Artifacts**

---

## [TAG] Créer une Release avec Tag

Pour créer une release officielle :

```bash
# Créer un tag
git tag -a v0.1.0 -m "Release version 0.1.0"

# Pousser le tag
git push origin v0.1.0
```

Le workflow créera automatiquement une Release GitHub avec l'APK attaché.

---

## [CONFIG] Configuration Requise

### Secrets GitHub

Aucun secret n'est requis pour les builds basiques.

**Optionnel (pour Codecov) :**
- `CODECOV_TOKEN` : Token Codecov pour l'upload de la couverture de code

### Permissions

Le workflow nécessite les permissions suivantes :
- [OK] Read access au code
- [OK] Write access aux Actions (artifacts)
- [OK] Write access aux Releases (si tags)

Ces permissions sont généralement accordées par défaut.

---

## [CHART] Badges de Statut

Ajoutez ces badges à votre README.md :

```markdown
![Build Android](https://github.com/Marilin66/QRFlow/workflows/Build%20Android%20APK/badge.svg)
![Tests](https://github.com/Marilin66/QRFlow/workflows/Tests%20&%20Quality/badge.svg)
![Build Web](https://github.com/Marilin66/QRFlow/workflows/Build%20Web%20App/badge.svg)
```

---

## [TOOL] Personnalisation

### Changer la version de Flutter

Dans `build-android.yml` et `tests.yml` :
```yaml
flutter-version: '3.24.0'  # Changez cette version
```

### Changer la version de Java

Dans `build-android.yml` :
```yaml
java-version: '17'  # Changez cette version
```

### Modifier la durée de conservation des artifacts

Dans `build-android.yml` :
```yaml
retention-days: 30  # Changez cette valeur (1-90 jours)
```

### Ajouter des branches

Pour builder sur d'autres branches :
```yaml
on:
  push:
    branches: [ main, develop, feature/* ]  # Ajoutez vos branches
```

---

## [BUG] Dépannage

### Le build échoue

1. Vérifiez les logs dans l'onglet Actions
2. Recherchez les erreurs en rouge
3. Les erreurs communes :
   - Dépendances manquantes
   - Tests qui échouent
   - Problèmes de versions Java/Flutter

### Les artifacts ne sont pas disponibles

- Les artifacts sont uniquement créés si le build réussit
- Vérifiez que l'étape "Upload" est en vert ([OK])
- Les artifacts expirent après la période de rétention

### Le workflow ne se déclenche pas

- Vérifiez que vos changements touchent les bons fichiers (`mobile/**`)
- Vérifiez que vous poussez sur les bonnes branches (`main` ou `develop`)
- Les workflows peuvent être désactivés dans Settings > Actions

---

## [DOCS] Ressources

- [Documentation GitHub Actions](https://docs.github.com/en/actions)
- [Flutter Action](https://github.com/subosito/flutter-action)
- [Upload Artifact Action](https://github.com/actions/upload-artifact)
- [Create Release Action](https://github.com/softprops/action-gh-release)

---

**Note :** Ces workflows sont configurés pour le projet QRFlow. Adaptez-les selon vos besoins spécifiques.
