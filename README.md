# Studia · StudentPlanning

Application Android Flutter + API FastAPI pour transformer un emploi du temps **PDF textuel** en planning hebdomadaire personnel. Le [cahier des charges original](docs/CONTEXTE.md) est conservé dans `docs/CONTEXTE.md` (converti en UTF-8 pour être lisible sur GitHub).

## Aperçu des écrans Flutter

| Écran | Parcours |
| --- | --- |
| Accueil | Semaine en cours, cours du jour, accès rapide à l'import. Au premier lancement, un **exemple fictif L2 SIR explicitement marqué DÉMO** montre la maquette ; il n'est jamais enregistré. |
| Import | Choisir un PDF, saisir la classe exacte, choisir la semaine (lundi calculé automatiquement), envoyer au serveur. |
| Vérification | Voir les avertissements et les différences proposées avec N-1 ; toucher un cours pour corriger ses champs, le glisser pour le retirer, puis valider. |
| Planning | Parcourir les 7 jours, voir horaires, salle et enseignant. |
| Historique | Revoir les semaines validées enregistrées localement en SQLite, même hors ligne. |
| Révisions | Placer des séances dans les trous du planning, en soirée et le week-end ; suivre les séances terminées et recevoir des rappels Android locaux. |

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

Documentation interactive : `http://localhost:8000/docs` · santé : `GET /health`. Pour une image Docker, des contrôles HTTP et les étapes de mise en ligne sur un hébergeur, voir [Déployer l'API FastAPI](docs/DEPLOY_API.md). Aucun service public permanent n'est encore configuré.

Pour essayer **le PDF réel L2 SIR** (depuis `backend/`, API lancée, sans clé IA pour ce modèle reconnu) :

```bash
curl -F 'file=@tests/Emploi_temps_12 -17-oct 2026.pdf;type=application/pdf' \
  -F 'class_name=L2 SIR' -F 'week_start=2026-10-12' \
  http://localhost:8000/api/import
```
La clé **ne doit jamais** être placée dans Flutter ou versionnée. Sans clé, les PDF au format de grille ESUPEX reconnu sont traités par l’extracteur déterministe ; un format non reconnu renvoie une erreur explicite 503 si le service IA n’est pas configuré. Le backend ne conserve pas le PDF importé en disque : il valide sa signature, sa taille (10 Mo), son nombre de pages (20) et extrait le texte avec PyMuPDF avant de transmettre **seulement ce texte et ses coordonnées** à OpenRouter. Les scans sans texte nécessitent un OCR et sont refusés. Il n'y a ni authentification ni limitation de débit : ne pas déployer cette API publiquement en l'état.

## Démarrage Flutter / Android

Installer [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable), Android SDK et Java 17, puis :

```bash
cd mobile
flutter create --platforms=android . # génère le wrapper Gradle et les fichiers natifs manquants
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

L'URL `10.0.2.2` fonctionne pour **l'émulateur Android**. Sur téléphone physique en développement, utiliser l'adresse IP locale de l'ordinateur hébergeant l'API (même réseau), par exemple `--dart-define=API_BASE_URL=http://192.168.1.10:8000`. **L'URL doit être fournie au build** : aucune IP personnelle n'est plus configurée par défaut. Pour un serveur déployé, utiliser `--dart-define=API_BASE_URL=https://api.votre-domaine.tld` avec le vrai domaine HTTPS ; une version release refuse HTTP. Le manifeste Android debug autorise HTTP uniquement pour le développement. La commande `flutter create` génère le wrapper Gradle et les fichiers de plateforme non versionnés ; elle préserve le code Dart existant. L'environnement de développement utilisé pour préparer ce dépôt ne comporte pas Flutter SDK : la compilation Android reste à vérifier sur une machine équipée.

## Contrat API

- `POST /api/import` : multipart avec `file` (PDF), `class_name`, `week_start` (lundi ISO `YYYY-MM-DD`) et éventuellement `previous` (planning N-1 validé en JSON). Répond `{schedule, changes_from_previous_week}`. Un PDF scanné, un document ambigu ou une réponse IA invalide ne génèrent pas silencieusement de faux cours. Les pages sont filtrées par classe ; la date du PDF est comparée au lundi choisi lorsqu’elle est lisible.
- `POST /api/compare` : `{previous: Schedule, current: Schedule}` pour des semaines consécutives de la même classe ; répond `{changes: [...]}`. Les changements sont des **propositions** à confirmer, et la comparaison reste prudente sur les cours répétés.
- `Schedule` : `{class_name, week_start, courses: [{subject, day, start, end, room, teacher, source_page, kind, delivery_mode, needs_review}], warnings}` ; `day` va de 1 (lundi) à 7 (dimanche). Les horaires sont en `HH:mm`. `kind` vaut `course`, `assessment` ou `unknown` ; `delivery_mode` vaut `online`, `in_person` ou `unknown`.

```bash
cd backend
python -m pytest -q
```

### Codes couleur des emplois du temps

D'après la convention décrite par l'utilisateur pour l'année scolaire, **le rouge dans une case peut signaler un devoir** et **le jaune peut signaler un cours en ligne**. Le backend extrait maintenant la couleur du texte et des fonds dessinés à proximité des blocs (`visual_cues` : `red_text`, `red_fill`, `yellow_text`, `yellow_fill`). Ces indices sont transmis **avec le texte et les coordonnées**, jamais le PDF brut, au modèle d'interprétation. Le modèle doit confirmer la classe et le contexte de la case : une couleur de titre ou de légende ne doit pas qualifier tous les cours. En cas de doute, `unknown` et `needs_review` sont préférables à une classification inventée. La revue Flutter permet de modifier le type de séance et la modalité ; les cartes affichent « DEVOIR » en rouge et « EN LIGNE » en jaune. Les maquettes HTML utilisent uniquement des exemples fictifs, sans analyse de PDF.

**Document réel vérifié :** `backend/tests/Emploi_temps_12 -17-oct 2026.pdf` comporte 13 pages ; **L2 SIR est sur la page 6**, et non sur la page L3 SIR. La grille L2 SIR contient 7 cours du 12 au 17 octobre 2026. Le bandeau jaune « Prévision des devoirs » et les textes rouges de la légende/pied de page **ne sont pas** des cours en ligne ou des devoirs planifiés cette semaine. L'import de cette page fonctionne sans clé IA grâce à l'analyse géométrique des cases fusionnées ; les autres mises en page peuvent encore nécessiter OpenRouter. Voir [le diagnostic de cette semaine](docs/EXTRACTION_L2_SIR.md).

### Limitations actuelles

La grille du PDF réel fourni est couverte par des tests pour L2 SIR. Les autres semaines de l’année et les changements de mise en page restent à valider ; un format non reconnu passe par OpenRouter. L'API ne fait pas d'OCR, la comparaison ne garantit pas que les différences de documents soient de vrais changements, et les corrections manuelles effectuées après import ne recalculent pas les propositions N-1 affichées (un avertissement le signale). Le stockage est local par appareil, sans compte ni synchronisation. Le prototype HTML simule seulement les révisions ; les alertes réelles nécessitent l'application Android et son autorisation de notifications. Le traitement différé côté API n'est pas inclus.

## Révisions et notifications locales

Après validation d'un vrai planning, l'onglet **Révisions** construit un programme sur le téléphone : séances libres de 50 minutes en journée, créneaux de **20 h à 22 h 30** et week-end, sans collision avec les cours. Les matières moins travaillées **la semaine précédente** sont prioritaires selon les séances réellement marquées terminées. Les données restent dans SQLite local (migration automatique version 1 → 2). Les cours du matin sont rappelés **1 h avant** (07 h 30 → 06 h 30) et les révisions à leur début. L'utilisateur doit activer les notifications ; Android peut différer les alarmes si les alarmes exactes ne sont pas autorisées. [Détails et limites](docs/REVISION_PLAN.md). Cette fonctionnalité n'envoie pas l'historique de révisions au backend. En cas de `MissingPluginException`, relancer une **compilation complète** depuis `mobile/` : `flutter clean && flutter pub get && flutter run` ; le hot reload ne charge pas le code Kotlin.

## Maquettes interactives HTML / CSS / JavaScript

Le prototype **visible dans le navigateur** est dans [`maquettes/`](maquettes/) : sept écrans (accueil, import, vérification avec édition, planning par jour, révisions fictives, comparaison, historique), adaptés au mobile et au bureau. Ouvrir directement `maquettes/index.html` dans un navigateur, ou démarrer un serveur local :

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

Sans `SHOW_MOCKUPS`, l'icône « Voir les maquettes » en haut de l'accueil ouvre cette galerie. Le mode maquette Flutter n'appelle pas l'API et n'enregistre aucun planning. L'onglet de révisions Android se configure après validation d'un vrai PDF ; les séances de la galerie HTML restent fictives. L'aperçu HTML est un **prototype visuel séparé**, pas une compilation Flutter Web. La compilation Flutter reste à vérifier sur une machine avec Flutter SDK.
