# StudentPlanning

# Document de contexte --- Application de génération automatique de planning étudiant

## 1. Présentation du projet

L'application permet à un étudiant de générer automatiquement son
planning personnel de la semaine à partir d'un emploi du temps officiel
fourni au format PDF.

Le PDF peut contenir les emplois du temps de plusieurs classes.
L'étudiant choisit sa classe et l'application extrait uniquement les
cours qui lui correspondent. Elle conserve le planning sur le téléphone
et peut comparer le nouvel emploi du temps avec celui de la semaine
précédente (**semaine N-1**) afin de repérer les changements.

L'application est conçue en priorité pour Android. L'interface est
réalisée avec Flutter. Le traitement du document est assuré par une API
Python et un modèle d'intelligence artificielle accessible via
OpenRouter.

## 2. Objectifs

-   Importer un PDF d'emploi du temps depuis le téléphone.
-   Extraire les informations du PDF avec des bibliothèques Python, sans
    envoyer le PDF brut au modèle d'IA dans le flux normal.
-   Transmettre à l'IA les données textuelles et structurées extraites,
    ainsi que les consignes nécessaires pour les interpréter.
-   Identifier l'emploi du temps de la classe sélectionnée.
-   Convertir les cours en données structurées et vérifiables.
-   Comparer l'emploi du temps courant avec celui de la semaine N-1.
-   Signaler les cours ajoutés, supprimés, déplacés ou modifiés lorsque
    la comparaison est fiable.
-   Présenter les résultats à l'étudiant pour vérification avant
    validation.
-   Afficher et conserver le planning dans l'application, y compris hors
    connexion après l'importation.

## 3. Utilisateurs et scénario principal

L'utilisateur principal est un étudiant qui reçoit chaque semaine un
document d'emploi du temps de son établissement.

Scénario d'utilisation :

1.  L'étudiant ouvre l'application.
2.  Il importe le PDF de la nouvelle semaine.
3.  Il sélectionne ou confirme sa classe.
4.  L'API Python extrait le texte et les positions utiles du PDF.
5.  Le système prépare les informations extraites et les transmet au
    modèle d'IA.
6.  L'IA organise les informations et identifie les cours correspondant
    à la classe.
7.  Le système compare les résultats avec le planning enregistré pour la
    semaine N-1.
8.  L'application affiche le nouveau planning et un résumé des
    changements détectés.
9.  L'étudiant vérifie et corrige les données incertaines.
10. Après validation, le planning est enregistré localement et devient
    consultable hors connexion.

## 4. Principe essentiel : extraire d'abord, interpréter ensuite

Dans le flux normal, le modèle d'IA ne reçoit pas directement le PDF. Le
PDF est d'abord traité par des bibliothèques Python.

### 4.1 Extraction déterministe avec Python

Bibliothèques candidates :

-   **PyMuPDF (`pymupdf`)** : extraction du texte des pages et de ses
    coordonnées.
-   **pdfplumber** : extraction de texte, de mots avec positions et
    tentative de reconstruction des tableaux.
-   **pydantic** : validation des structures de données reçues et
    produites par l'API.
-   **FastAPI** : réception du fichier et exposition des routes HTTP.

Le choix entre PyMuPDF et pdfplumber sera confirmé par un test sur un
vrai document de l'établissement. Il n'est pas nécessaire d'utiliser les
deux si une seule bibliothèque fournit une extraction suffisamment
fiable.

Comme le PDF contient du texte sélectionnable, l'OCR n'est pas prévu
dans le MVP. Si certains documents futurs sont scannés, une solution OCR
pourra être ajoutée séparément.

### 4.2 Préparation des données pour l'IA

L'extracteur prépare notamment :

-   le texte extrait ;
-   les numéros de page ;
-   les blocs ou mots avec leurs coordonnées, lorsque disponibles ;
-   les lignes ou cellules candidates ;
-   les en-têtes identifiés, si possible ;
-   les avertissements sur les cellules ambiguës ou les informations
    manquantes.

Le backend transmet ces données à l'IA sous une forme compacte et
structurée. Il ne doit pas inventer les cellules que l'extraction n'a
pas permis de reconstituer.

### 4.3 Rôle de l'intelligence artificielle

Le modèle via OpenRouter sert à interpréter les informations extraites,
notamment lorsque le tableau comporte des abréviations, plusieurs
classes, des cellules fusionnées ou une organisation difficile à
analyser avec des règles simples.

Il doit :

-   identifier les cours appartenant à la classe choisie ;
-   interpréter les jours et les horaires ;
-   normaliser les noms de matières et les noms de classes sans changer
    leur sens ;
-   associer les salles et enseignants uniquement lorsque l'information
    est présente ;
-   structurer les cours au format JSON attendu ;
-   signaler les ambiguïtés au lieu de deviner ;
-   comparer le planning courant à celui de la semaine N-1 et proposer
    une liste de changements justifiés par les données disponibles.

L'IA est un outil d'interprétation, pas la source de vérité. Le backend
valide les données et l'étudiant confirme les résultats.

## 5. Comparaison avec la semaine N-1

La comparaison avec la semaine précédente est une fonctionnalité
importante du projet.

### 5.1 Données à conserver

Pour chaque planning validé, conserver au minimum :

-   la classe ;
-   la date de début de semaine ;
-   la date ou la période couverte ;
-   les cours validés ;
-   la provenance du planning ;
-   la date d'importation ;
-   le statut de validation.

Le planning de la semaine N-1 doit rester enregistré afin de pouvoir le
comparer au nouveau document. L'historique peut être conservé localement
dans SQLite via Drift.

### 5.2 Changements à détecter

Le système cherche à identifier :

-   **Cours ajouté** : un cours existe dans le nouveau planning mais pas
    dans l'ancien.
-   **Cours supprimé** : un cours de l'ancien planning ne figure plus
    dans le nouveau.
-   **Horaire modifié** : un cours comparable commence ou se termine à
    une heure différente.
-   **Salle modifiée** : le cours semble identique, mais la salle
    change.
-   **Matière ou enseignant modifié** : les données disponibles
    permettent de relier les deux entrées avec suffisamment de
    confiance.
-   **Changement incertain** : les éléments ne sont pas assez fiables
    pour conclure.

La comparaison ne doit pas se fonder uniquement sur l'horaire, car un
cours déplacé pourrait alors être considéré à tort comme supprimé puis
ajouté. Elle doit utiliser plusieurs indices : classe, matière,
enseignant, salle et proximité des horaires. Si aucune correspondance
fiable n'est possible, le résultat doit être signalé comme incertain.

### 5.3 Limite à expliciter

Une différence entre deux fichiers n'est pas toujours une modification
réelle de l'emploi du temps : le document peut être incomplet, corrigé
ou présenter une autre mise en page. L'application doit afficher les
changements comme des propositions à vérifier, surtout lorsque les
correspondances sont ambiguës.

## 6. Architecture technique

### Application Android --- Flutter

Responsabilités :

-   choisir et envoyer le PDF ;
-   permettre de choisir la classe ;
-   afficher l'état du traitement ;
-   présenter les cours extraits dans une interface de vérification ;
-   afficher le planning hebdomadaire ;
-   afficher les différences avec la semaine N-1 ;
-   sauvegarder et consulter les plannings hors connexion.

Bibliothèques candidates :

-   `file_picker` : sélection du PDF ;
-   `flutter_riverpod` : gestion de l'état et séparation des
    responsabilités ;
-   `drift` : accès typé à la base locale SQLite ;
-   `path_provider` : accès aux répertoires locaux si nécessaire ;
-   `flutter_local_notifications` : rappels de cours, dans une version
    ultérieure.

### API --- Python

Responsabilités :

-   recevoir et contrôler le PDF ;
-   limiter la taille et vérifier le type de fichier ;
-   extraire le texte et les positions avec PyMuPDF ou pdfplumber ;
-   préparer les données à transmettre au modèle ;
-   appeler OpenRouter depuis le serveur ;
-   valider le JSON retourné ;
-   effectuer ou superviser la comparaison avec la semaine N-1 ;
-   renvoyer à Flutter un résultat propre, accompagné des avertissements
    nécessaires.

Technologies :

-   FastAPI pour l'API HTTP ;
-   Pydantic pour les schémas et la validation ;
-   PyMuPDF et/ou pdfplumber pour l'extraction ;
-   client HTTP Python pour appeler OpenRouter ;
-   SQLite côté téléphone via Drift pour l'historique des plannings.

Pour le MVP, il n'est pas nécessaire d'ajouter un serveur de base de
données distant ni un système de comptes utilisateurs. L'API peut être
sans état et traiter chaque importation. L'historique est conservé sur
le téléphone.

### Service d'intelligence artificielle

-   OpenRouter sert de passerelle vers les modèles disponibles.
-   Le modèle est choisi selon sa capacité à interpréter du texte
    structuré, à suivre les consignes et à produire du JSON.
-   Le nom du modèle doit être configurable côté serveur.
-   Les modèles gratuits peuvent avoir des limites, une disponibilité
    variable et des capacités différentes. Prévoir des erreurs
    explicites et la possibilité de réessayer.
-   La clé OpenRouter reste uniquement côté serveur, jamais dans
    l'application Flutter.

## 7. Flux de données

``` mermaid
flowchart TD
    A[Étudiant importe le PDF dans Flutter] --> B[API FastAPI reçoit et contrôle le fichier]
    B --> C[Python extrait texte et coordonnées du PDF]
    C --> D[Préparation des données extraites]
    D --> E[OpenRouter : interprétation et structuration]
    E --> F[Validation du JSON par le backend]
    F --> G[Comparaison avec le planning N-1]
    G --> H[API renvoie cours et changements à Flutter]
    H --> I[Étudiant vérifie et corrige]
    I --> J[Enregistrement local dans Drift / SQLite]
    J --> K[Affichage du planning hors connexion]
```

## 8. Format des données

Les cours doivent être représentés par une structure cohérente. Exemple
indicatif :

``` json
{
  "class_name": "L2 SIR",
  "week_start": "2026-10-12",
  "courses": [
    {
      "day": "monday",
      "start_time": "08:00",
      "end_time": "10:00",
      "subject": "Réseaux",
      "room": "A12",
      "teacher": null,
      "confidence": "high",
      "needs_review": false
    }
  ],
  "changes_from_previous_week": [
    {
      "type": "room_changed",
      "subject": "Réseaux",
      "previous_value": "A10",
      "current_value": "A12",
      "needs_review": true
    }
  ],
  "warnings": []
}
```

Cet exemple définit une forme cible ; ce ne sont pas des données
réelles. Le schéma final doit être défini avec Pydantic côté serveur et
reproduit dans les modèles Dart. Les champs de confiance ne doivent pas
être présentés comme une probabilité mathématique si le modèle ne
fournit pas une mesure calibrée.

Les jours, dates et heures doivent être normalisés. Il faut distinguer
la date de début de semaine, le jour du cours et les horaires, pour
éviter de comparer des semaines différentes par erreur.

## 9. Écrans du MVP

1.  **Accueil** : planning de la semaine actuelle et accès à
    l'importation.
2.  **Importation** : sélection du PDF, choix de la classe et lancement
    du traitement.
3.  **Traitement** : indication de l'étape en cours et gestion des
    erreurs.
4.  **Vérification des cours** : liste modifiable des cours extraits.
5.  **Planning hebdomadaire** : calendrier lisible avec jour, heure,
    matière et salle.
6.  **Comparaison des semaines** : cours ajoutés, supprimés ou modifiés,
    avec indication des changements incertains.
7.  **Historique** : accès aux plannings précédents et possibilité de
    les consulter.

## 10. Périmètre du MVP

### Inclus

-   Android uniquement ;
-   import de PDF contenant du texte sélectionnable ;
-   choix manuel de la classe ;
-   extraction locale côté serveur avec des bibliothèques Python ;
-   interprétation des données extraites via OpenRouter ;
-   retour de données JSON structurées ;
-   vérification et correction par l'étudiant ;
-   comparaison avec le planning validé de la semaine N-1 ;
-   sauvegarde locale et consultation hors connexion ;
-   gestion des erreurs d'extraction, d'API et de modèle.

### Non inclus au départ

-   reconnaissance OCR des scans et des photos ;
-   comptes utilisateurs et synchronisation multi-appareils ;
-   partage de planning entre étudiants ;
-   génération automatique d'un emploi du temps en cas de données
    manquantes ;
-   intégration complète avec Google Calendar ;
-   notifications avancées ;
-   analyse directe du PDF par vision multimodale lorsque l'extraction
    textuelle échoue.

Ces fonctions pourront être ajoutées après validation du flux principal.

## 11. Sécurité, confidentialité et robustesse

-   La clé OpenRouter doit rester dans une variable d'environnement côté
    serveur.
-   Le PDF doit être supprimé après traitement, sauf besoin explicite de
    conservation.
-   Ne transmettre au modèle que les informations nécessaires à
    l'interprétation.
-   Informer l'utilisateur que le texte extrait est envoyé à un
    fournisseur externe d'IA.
-   Limiter la taille du PDF, le nombre de pages et la durée de
    traitement.
-   Ne pas faire confiance au JSON du modèle avant validation par
    Pydantic.
-   Ne pas laisser les données extraites déclencher des actions
    arbitraires : le contenu du document doit être traité comme une
    donnée non fiable.
-   Prévoir des délais d'attente, une gestion des erreurs et un nombre
    limité de tentatives.
-   Ne pas écraser le planning précédent avant que le nouveau planning
    ait été vérifié et validé.
-   Conserver le planning local pour qu'il reste accessible sans
    Internet.
-   Éviter de journaliser les contenus complets des emplois du temps si
    cela n'est pas nécessaire.

## 12. Plan de développement

### Étape 1 --- Valider l'extraction

-   Obtenir un véritable PDF de l'établissement.
-   Tester PyMuPDF et pdfplumber.
-   Examiner l'ordre du texte, les positions et les cellules fusionnées.
-   Définir la meilleure représentation des lignes et cellules.
-   Produire un résultat de diagnostic avant toute intégration de l'IA.

**Livrable :** un script Python qui extrait les informations utiles de
manière reproductible.

### Étape 2 --- Construire le traitement IA

-   Définir les schémas Pydantic.
-   Préparer un prompt demandant une sortie JSON stricte.
-   Envoyer uniquement les données extraites à OpenRouter.
-   Vérifier la classe, les jours, les horaires et les informations
    manquantes.
-   Tester le résultat sur plusieurs documents réels.

**Livrable :** un endpoint qui renvoie une liste de cours structurés et
des avertissements.

### Étape 3 --- Comparer les semaines

-   Définir la logique de rapprochement entre cours.
-   Comparer le nouvel emploi du temps au planning N-1 validé.
-   Identifier les ajouts, suppressions et modifications.
-   Marquer les correspondances incertaines pour révision.

**Livrable :** un rapport de différences testable indépendamment de
l'interface.

### Étape 4 --- Créer l'application Flutter

-   Construire les écrans d'importation et de sélection de classe.
-   Appeler l'API et gérer le chargement ou les erreurs.
-   Afficher les cours dans une liste de vérification.
-   Construire le calendrier hebdomadaire.
-   Enregistrer les plannings validés dans Drift.

**Livrable :** une application Android fonctionnelle.

### Étape 5 --- Tester et stabiliser

-   Tester les PDF de plusieurs semaines.
-   Vérifier les cours déplacés et les documents corrigés.
-   Tester les pannes réseau et les limites du modèle.
-   Vérifier le fonctionnement hors connexion.
-   Tester les doublons et la préservation de l'ancien planning.

**Livrable :** un MVP fiable sur les documents ciblés.

## 13. Critères d'acceptation

Le MVP est acceptable lorsque :

-   un PDF textuel peut être importé ;
-   l'étudiant peut sélectionner sa classe ;
-   les cours extraits sont structurés et modifiables ;
-   les erreurs ou ambiguïtés sont visibles ;
-   le planning de la semaine N-1 peut être retrouvé ;
-   les changements sont présentés sans inventer d'informations ;
-   un planning validé reste accessible hors connexion ;
-   une erreur d'OpenRouter n'efface jamais le planning existant ;
-   aucune clé secrète n'est embarquée dans l'application Android.

## 14. Décision d'architecture

La solution retenue est :

**Flutter + FastAPI + PyMuPDF/pdfplumber + OpenRouter + Pydantic +
Drift/SQLite.**

Le PDF est d'abord analysé par Python. Seules les informations extraites
et utiles sont envoyées au modèle d'IA. Le backend contrôle la réponse,
compare les cours à la semaine N-1 et renvoie des données structurées à
Flutter. L'étudiant vérifie le résultat avant son enregistrement local.

La priorité technique est de valider l'extraction sur un document réel
avant de développer l'ensemble de l'application.
