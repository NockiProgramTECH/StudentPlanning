# Studia · StudentPlanning

Application Android Flutter + API FastAPI pour transformer un emploi du temps **PDF textuel** en planning hebdomadaire personnel. Le [cahier des charges original](docs/CONTEXTE.md) est conservé dans `docs/CONTEXTE.md` (converti en UTF-8 pour être lisible sur GitHub).

## Aperçu des écrans Flutter

| Écran | Parcours |
| --- | --- |
| Accueil | Semaine en cours, cours du jour, accès rapide à l'import. Au premier lancement, un **exemple explicitement marqué DÉMO** montre la maquette ; il n'est jamais enregistré. |
| Import | Choisir un PDF, saisir la classe exacte, choisir la semaine (lundi calculé automatiquement), envoyer au serveur. |
| Vérification | Voir les avertissements et les différences proposées avec N-1 ; toucher un cours pour corriger ses champs, le glisser pour le retirer, puis valider. |
| Planning | Parcourir les 7 jours, voir horaires, salle et enseignant. |
| Historique | Revoir les semaines validées enregistrées localement en SQLite, même hors ligne. |

## Démarrage API

Python 3.11+ :

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
export OPENROUTER_API_KEY='votre-cle-serveur' # requis uniquement pour l'interprétation
# export OPENROUTER_MODEL='openai/gpt-4o-mini'
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Documentation interactive : `http://localhost:8000/docs` · santé : `GET /health`.
La clé **ne doit jamais** être placée dans Flutter ou versionnée. Sans clé, l'import renvoie une erreur explicite 503 ; la maquette et l'historique restent utilisables. Le backend ne conserve pas le PDF en disque : il valide sa signature, sa taille (10 Mo), son nombre de pages (20) et extrait le texte avec PyMuPDF avant de transmettre **seulement ce texte et ses coordonnées** à OpenRouter. Les scans sans texte nécessitent un OCR et sont refusés. Il n'y a ni authentification ni limitation de débit : ne pas déployer cette API publiquement en l'état.

## Démarrage Flutter / Android

Installer [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable), Android SDK et Java 17, puis :

```bash
cd mobile
flutter create --platforms=android . # génère le wrapper Gradle et les fichiers natifs manquants
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

L'URL `10.0.2.2` fonctionne pour **l'émulateur Android**. Sur téléphone physique, utiliser l'adresse IP locale de l'ordinateur hébergeant l'API (même réseau), par exemple `--dart-define=API_BASE_URL=http://192.168.1.10:8000`. Le manifeste Android debug autorise HTTP uniquement pour le développement ; utiliser HTTPS en production. La commande `flutter create` génère le wrapper Gradle et les fichiers de plateforme non versionnés ; elle préserve le code Dart existant. L'environnement de développement utilisé pour préparer ce dépôt ne comporte pas Flutter SDK : la compilation Android reste à vérifier sur une machine équipée.

## Contrat API

- `POST /api/import` : multipart avec `file` (PDF), `class_name`, `week_start` (lundi ISO `YYYY-MM-DD`) et éventuellement `previous` (planning N-1 validé en JSON). Répond `{schedule, changes_from_previous_week}`. Un PDF scanné, un document ambigu ou une réponse IA invalide ne génèrent pas silencieusement de faux cours.
- `POST /api/compare` : `{previous: Schedule, current: Schedule}` pour des semaines consécutives de la même classe ; répond `{changes: [...]}`. Les changements sont des **propositions** à confirmer, et la comparaison reste prudente sur les cours répétés.
- `Schedule` : `{class_name, week_start, courses: [{subject, day, start, end, room, teacher, source_page, needs_review}], warnings}` ; `day` va de 1 (lundi) à 7 (dimanche). Les horaires sont en `HH:mm`.

```bash
cd backend
python -m pytest -q
```

### Limitations actuelles

La qualité de l'interprétation dépend du PDF réel et du modèle configuré. Aucun PDF d'établissement n'est fourni : la reconstruction des tableaux doit être vérifiée sur des documents représentatifs avant usage réel. L'API ne fait pas d'OCR, la comparaison ne garantit pas que les différences de documents soient de vrais changements, et les corrections manuelles effectuées après import ne recalculent pas les propositions N-1 affichées (un avertissement le signale). Le stockage est local par appareil, sans compte ni synchronisation. La maquette n'implémente pas encore notifications ni traitement différé.

## Maquettes interactives HTML / CSS / JavaScript

Le prototype **visible dans le navigateur** est dans [`maquettes/`](maquettes/) : six écrans (accueil, import, vérification avec édition, planning par jour, comparaison, historique), adaptés au mobile et au bureau. Ouvrir directement `maquettes/index.html` dans un navigateur, ou démarrer un serveur local :

```bash
cd maquettes
python -m http.server 4173 --bind 0.0.0.0
# Ouvrir http://localhost:4173
```

Le prototype est **autonome et fictif** : sélectionner un PDF affiche son nom mais **ne lit ni n'envoie son contenu**. « Voir le résultat simulé » ouvre un planning d'exemple. Les corrections restent dans la session en cours (pas de backend, pas de sauvegarde). Aucun service externe ou CDN n'est nécessaire. Source : `maquettes/index.html`, `maquettes/styles.css`, `maquettes/app.js`. Tests du prototype (facultatifs) : `cd maquettes && npm ci && npm test`.

Les mêmes étapes sont aussi accessibles dans la **galerie de maquettes Flutter** (écrans natifs avec données de démonstration) :

```bash
cd mobile
flutter create --platforms=android . # uniquement si les fichiers de plateforme manquent
flutter pub get
flutter run --dart-define=SHOW_MOCKUPS=true
```

Sans `SHOW_MOCKUPS`, l'icône « Voir les maquettes » en haut de l'accueil ouvre cette galerie. Le mode maquette Flutter n'appelle pas l'API et n'enregistre aucun planning. L'aperçu HTML est un **prototype visuel séparé**, pas une compilation Flutter Web. La compilation Flutter reste à vérifier sur une machine avec Flutter SDK.
