# Plateforme d'évaluation du développement professionnel

## Vue d'ensemble

Cette plateforme est un outil de récolte et d'analyse de données pour les établissements scolaires, permettant un monitorage en temps réel du développement professionnel à travers différentes échelles d'évaluation.

### Objectifs principaux
- Fournir aux directions d'établissement un tableau de bord interactif pour le pilotage
- Permettre la récolte standardisée de données via des questionnaires validés scientifiquement
- Offrir différentes vues des données selon le profil utilisateur (enseignant, directeur, chercheur)

### Architecture globale
La plateforme s'articule autour de trois composants principaux :
1. Un backend LimeSurvey pour la récolte des données
2. Un système de traitement R pour l'analyse et le scoring
3. Une interface Shiny pour la visualisation des données

Le système est conçu pour être extensible, avec une architecture basée sur des fichiers de configuration YAML qui permettent l'ajout simple de nouvelles échelles d'évaluation et la gestion sécurisée des credentials.

## Installation et Configuration

### Prérequis
- R (>= 4.2.0)
- RStudio (recommandé pour le développement)
- Instance LimeSurvey active
- Packages R requis :
  - shiny
  - bslib
  - tidyverse
  - lubridate
  - yaml
  - limer

### Configuration des credentials

1. Dans le dossier `config/`, copiez le template des credentials :
```bash
cp credentials.yml.template credentials.yml
```

2. Modifiez `credentials.yml` avec vos informations de connexion :
```yaml
limesurvey:
  api_url: 'URL_DE_VOTRE_LIMESURVEY'
  username: 'VOTRE_USERNAME'
  password: 'VOTRE_PASSWORD'

researcher_codes:
  - 'CODE_CHERCHEUR_1'
  - 'CODE_CHERCHEUR_2'
```

**Important** : Ne committez jamais le fichier `credentials.yml` - il est déjà inclus dans le `.gitignore`.

### Gestion des dépendances avec {renv}

Ce projet utilise {renv} pour gérer les dépendances R. {renv} crée un environnement isolé pour le projet, garantissant la reproductibilité des analyses.

1. Installation initiale :
```R
install.packages("renv")
renv::restore()
```

2. Ajout d'un nouveau package :
```R
renv::install("nom_du_package")
```

3. Mise à jour du fichier de verrouillage :
```R
renv::snapshot()
```

### Structure du projet
```
.
├── R
│   ├── core                # Fonctions fondamentales
│   │   ├── analysis.R      # Analyses statistiques
│   │   ├── config.R        # Configuration système
│   │   └── data_processing.R # Traitement des données
│   ├── dashboard          # Interface utilisateur
│   │   ├── functions.R    # Fonctions communes dashboard
│   │   ├── server        # Logique serveur par profil
│   │   └── ui           # Interfaces utilisateur par profil
│   └── functions.R       # Point d'entrée des fonctions
├── config
│   ├── credentials.yml   # Credentials (non commité)
│   └── scales_definition.yml # Configuration des échelles
├── data
│   └── test_data_full.csv # Données de test
├── tests
│   └── tests.R          # Tests unitaires et fonctionnels
└── app.R               # Point d'entrée de l'application
```

### Configuration des échelles

Le fichier `config/scales_definition.yml` définit la structure des échelles et leur scoring. Pour ajouter une nouvelle échelle :

1. **Définition dans LimeSurvey**
   - Créez les questions
   - Notez les identifiants

2. **Configuration YAML**
```yaml
scales:
  votre_echelle:
    id: "group_id"
    type: "likert_5"
    response_prefix: "AO0"
    items:
      - id: "question_id_1"
        reversed: false
```

3. **Validation**
   - Vérifiez le format YAML
   - Testez avec les données de test
   - Validez le scoring

### Vérification de l'installation

Lancez les tests pour vérifier la configuration :
```R
source("tests/tests.R")
```

## Utilisation

### Lancement de l'application
```R
shiny::runApp()
```

### Profils utilisateurs

#### Enseignants
- Visualisation des scores individuels
- Comparaison avec les moyennes du groupe
- Suivi temporel

#### Directeurs
- Vue d'ensemble de l'établissement
- Tableaux de bord agrégés
- Analyse des tendances

#### Chercheurs
- Accès aux données anonymisées
- Analyses statistiques avancées
- Filtrage démographique

## Développement

### Bonnes pratiques
- Documentez toute nouvelle échelle
- Testez avec les données de test
- Ne committez jamais de credentials
- Utilisez les branches pour les nouvelles fonctionnalités

### Pipeline de traitement
1. Import LimeSurvey
2. Standardisation des variables
3. Conversion des réponses
4. Calcul des scores
5. Préparation pour visualisation

## Contact et Support

Pour toute question ou problème :
- Consultez la documentation dans le readme.md
- Soumettez une issue sur GitHub
- Contactez l'équipe de développement

## Licence

Ce projet est sous licence Creative Commons Attribution 4.0 International (CC BY 4.0).