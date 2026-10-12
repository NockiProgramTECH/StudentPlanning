# Déployer l'API FastAPI — pilote pour L2 SIR

L'API fonctionne déjà avec **FastAPI + Uvicorn**. Les routes `GET /health`, `GET /docs`, `POST /api/import` et `POST /api/compare` existent. Le PDF de test de l'université dans `backend/tests/Emploi_temps_12 -17-oct 2026.pdf` est lu par l'analyseur déterministe, **sans clé OpenRouter** ; le rendu du PDF et la correction des cours restent à valider dans Flutter. Aucune URL publique n'a été créée dans ce dépôt : il faut choisir un hébergeur, un domaine et éventuellement payer l'hébergement.

## Vérification reproductible en local

```bash
cd backend
python3.11 -m venv .venv
. .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Dans un second terminal (depuis `backend/`) :

```bash
curl -f http://127.0.0.1:8000/health
curl -f http://127.0.0.1:8000/openapi.json >/dev/null
curl -f -F 'file=@tests/Emploi_temps_12 -17-oct 2026.pdf;type=application/pdf' \
  -F 'class_name=L2 SIR' -F 'week_start=2026-10-12' \
  http://127.0.0.1:8000/api/import
```

Résultat attendu : santé `{"status":"ok"}`, import HTTP 200, **7 cours L2 SIR**. La semaine de ce PDF est celle du **12 octobre 2026** ; un PDF d'une autre semaine exige le lundi correspondant. Ne confondez pas une réponse 200 de `/health` avec une preuve que l'IA externe fonctionne : l'IA n'est sollicitée que si l'extracteur n'arrive pas à lire la mise en page.

## Déploiement sur un hébergeur acceptant Docker

Choisir le dossier **`backend/` comme contexte de build** et son `Dockerfile` comme Dockerfile ; il n'inclut ni les PDF de tests, ni les secrets. Exemple depuis la racine du dépôt :

```bash
docker build -t studia-api ./backend
docker run --rm -p 8000:8000 -e PORT=8000 studia-api
```

Configurer chez l'hébergeur : port exposé (la variable `PORT` est prise en compte, défaut 8000), health check `/health`, **HTTPS** côté hébergeur/proxy, taille maximale de requête raisonnable au proxy, et variables d'environnement uniquement côté serveur. Aucun disque persistant n'est requis pour cette **API d'emploi du temps** : elle reçoit le PDF, extrait les cours et répond, sans enregistrer de compte ni de PDF. Les plannings validés et rappels sont conservés sur le téléphone.

D'abord déployer **sans `OPENROUTER_API_KEY`** : le PDF L2 SIR reconnu sera importable, les documents non reconnus répondront 503 sans coût IA. Après ajout d'une authentification réelle et de quotas, configurer `OPENROUTER_API_KEY` comme **secret serveur**, `OPENROUTER_MODEL` si nécessaire. Ne jamais la mettre dans Flutter, dans l'image Docker, dans Git, ni dans une URL. L'IA reçoit des extraits textuels filtrés, pas le PDF brut, mais ces extraits peuvent contenir des données personnelles.

Après déploiement, remplacer **`<MON_URL_PUBLIQUE_HTTPS>`** ci-dessous par l'URL HTTPS réelle, et exécuter le script de vérification de bout en bout depuis `backend/` :

```bash
python -m app.verify_remote <MON_URL_PUBLIQUE_HTTPS>
```

Ou avec `curl` :

```bash
curl -fsS <MON_URL_PUBLIQUE_HTTPS>/health
curl -fsS -F 'file=@tests/Emploi_temps_12 -17-oct 2026.pdf;type=application/pdf' \
  -F 'class_name=L2 SIR' -F 'week_start=2026-10-12' \
  <MON_URL_PUBLIQUE_HTTPS>/api/import
```

Une réponse 200 sur l'URL publique confirme la mise en ligne (santé `{"status":"ok"}` et 7 cours L2 SIR sur la page 6) ; une réponse 200 locale ne la confirme pas.

## Connecter le téléphone

L'URL du backend doit être fournie **au build Flutter** ; l'application ne contient plus d'adresse IP personnelle implicite :

```bash
cd mobile
flutter run -d <ID_ANDROID> --dart-define=API_BASE_URL=<MON_URL_PUBLIQUE_HTTPS>
# APK debug (essai direct sur téléphone) :
flutter build apk --debug --dart-define=API_BASE_URL=<MON_URL_PUBLIQUE_HTTPS>
# Puis, après validation de l'installation et de la signature release :
flutter build apk --release --dart-define=API_BASE_URL=<MON_URL_PUBLIQUE_HTTPS>
```

Pour le développement seulement : `--dart-define=API_BASE_URL=http://10.0.2.2:8000` (émulateur), ou l'IP LAN de l'ordinateur (téléphone sur le même réseau). **Une version release refuse HTTP** pour l'import. Sans URL configurée, l'interface signale explicitement que le serveur manque au lieu d'essayer une adresse privée qui ne marcherait que chez le développeur. Les options `--dart-define` sont embarquées dans l'APK : n'y placer aucun secret.

## Ce qui bloque une ouverture au public sans précaution

- Les routes de planning `/api/import` et `/api/compare` **n'authentifient pas les utilisateurs et ne limitent pas le nombre de requêtes**. Les contrôles actuels (PDF jusqu'à 10 Mo, 20 pages, texte borné) ne remplacent ni quotas, ni protection contre les abus/attaques, ni plafonnement des coûts IA. Éviter de rendre OpenRouter accessible via cette API tant que ces protections ne sont pas mises en place. Une clé statique dans l'APK **n'est pas** une solution : elle peut être extraite.
- Pour un pilote, n'inviter qu'un groupe limité et utiliser au besoin des restrictions d'accès au niveau de l'hébergeur ; cela ne vaut pas une authentification par étudiant. Protéger HTTPS, logs (ne pas journaliser le texte des PDF), ressources CPU/mémoire et sauvegardes si des comptes sont ajoutés plus tard. Contrôler le comportement sur plusieurs PDF et sur un vrai téléphone avant distribution.
- Le module **Supports de cours & Quiz IA progressif** (`/api/courses/...`) possède des quotas journaliers/mensuels de tokens et de coût. Son accès est désormais piloté par `STUDIA_FREE_ACCESS`, comme décrit ci-dessous. Il ne contient pas d'OCR.

**Validation ici :** lancement Uvicorn sur `0.0.0.0:8020`, `GET /health` 200, OpenAPI 200, `POST /api/import` avec le PDF L2 SIR : 200 et 7 cours. Le processus de test a ensuite été arrêté. L'image Docker n'a pas pu être construite dans cet environnement (Docker absent) ; le build Flutter et l'accessibilité depuis Internet restent aussi à vérifier sur les environnements cibles.


## Pilotage de l'espace étudiant L2 SIR

`backend/.env.example` décrit les variables, sans véritables secrets. Copier en `.env`
(non versionné), renseigner les valeurs côté serveur et charger explicitement ce fichier :

```bash
cd backend
cp .env.example .env
# Modifier .env, puis :
uvicorn app.main:app --env-file .env --host 0.0.0.0 --port 8000
```

En hébergement, définir les variables dans le gestionnaire de secrets, puis redémarrer
le service après modification. Un fichier `.env` n'est pas chargé implicitement par l'app.

| Variable | Mode gratuit | Mode contrôlé |
| --- | --- | --- |
| `STUDIA_FREE_ACCESS` | `true` | `false` (défaut si absent ou invalide) |
| `CHARIOW_API_KEY` | Inutile | Obligatoire, secret serveur |
| `CHARIOW_PULSE_SECRET` | Inutile | Obligatoire, secret serveur |
| `CHARIOW_STORE_DOMAIN` | Non utilisé par Flutter | Défaut `https://camfbzgd.mychariow.co` |
| `CHARIOW_PRODUCT_ID` | Non utilisé | Défaut `prd_mrrhb8h2`, restriction obligatoire |
| `OPENROUTER_API_KEY` | Nécessaire pour générer les quiz | Idem |
| `STUDIA_DB_PATH` | SQLite serveur persistant | Idem, avec état des accès et webhooks |

**Stockage serveur obligatoire pour ce module**, contrairement à l'import du planning :
monter un volume persistant, sauvegardé et accessible à l'UID 10001 dans Docker ; par exemple
`STUDIA_DB_PATH=/data/studia_courses.sqlite3`. Ne pas placer SQLite dans un répertoire
éphémère ou en lecture seule. `STUDIA_ACCESS_TOKENS` est désormais ignoré : aucun jeton
pilote ne contourne la vérification Chariow.

### Contrat et parcours

- `GET /api/access/config` est public et répond exactement
  `{"free_access": true, "portal_url": "/api/access/portal"}` (ou `false`).
  Réponse `Cache-Control: no-store` ; une panne de configuration ne débloque jamais Flutter.
- En mode gratuit, chaque requête `/api/courses/*` porte `X-Device-Identifier` :
  16–255 caractères ASCII alphanumériques, `_` ou `-`. Flutter crée 32 octets aléatoires,
  les conserve en SQLite et les envoie automatiquement ; aucune saisie n'est requise.
  Le serveur hache cet identifiant pour isoler supports, progression et quotas.
- En mode contrôlé, Flutter ouvre **le backend** `/api/access/portal` par le canal
  `studia/student_portal` / Android `Intent.ACTION_VIEW`, jamais une WebView.
  Le serveur répond 302 vers `{CHARIOW_STORE_DOMAIN}/{CHARIOW_PRODUCT_ID}`. La destination
  doit être une origine HTTPS, sans identifiants, chemin, requête ni fragment.
- Au retour du navigateur, la configuration est relue. L'étudiant saisit son code reçu
  ou son e-mail et touche **Finaliser mon accès**. Aucun retour de navigateur n'est
  considéré comme preuve d'un accès actif.
- `POST /api/access/activate` et `POST /api/licenses/activate` utilisent le même traitement :
  `{access_code: "code ou e-mail", device_identifier: "identifiant installation"}`.
  Les noms historiques `license_key` et `email` sont aussi acceptés.
- L'e-mail est recherché uniquement dans les associations reçues via un Pulse signé
  (`customer.email`, à la racine ou dans `license.customer`, avec `license.key` et
  `product.id`). Un e-mail absent, ambigu ou associé à un autre produit n'ouvre rien :
  attendre le webhook ou utiliser le code. Le serveur revérifie ensuite le statut,
  l'expiration, le produit et les possibilités d'activation auprès de Chariow.
- La signature HMAC sur le corps brut, la déduplication Pulse et les événements
  d'expiration/révocation restent actifs. Tester aussi les vrais événements de votre
  boutique : les tests automatisés n'appellent pas les services externes.
- SQLite Android v4 conserve l'identifiant d'installation et le jeton, séparé par URL
  de serveur, **pas le code ni l'e-mail saisi**. Les plannings existants ne sont pas effacés.
  À la réouverture, le jeton est vérifié via `/api/courses/quota`. Un 401/403 le retire et
  permet de finaliser de nouveau ; une panne réseau ne le supprime pas.

### Budget, sécurité et limites

Les limites `STUDIA_MAX_DOCS_PER_DAY`, `STUDIA_MAX_QUIZ_REQUESTS_PER_DAY`,
`STUDIA_MAX_TOKENS_PER_DAY` et `STUDIA_MAX_COST_USD_PER_MONTH` s'appliquent aux deux modes.
En gratuit elles sont par installation ; en contrôlé elles restent partagées par accès
serveur, donc plusieurs appareils ne multiplient pas le budget du même accès.
Les identités gratuite et contrôlée sont distinctes : les supports locaux sont conservés,
mais un support serveur créé sous l'autre identité doit être réimporté pour poursuivre
sa génération. Il n'y a pas de transfert implicite de propriété.

**Ces quotas ne sont pas une protection anti-abus globale.** Un client modifié peut
changer son identifiant d'installation, et les vérifications actuelles de budget ne
réservent pas atomiquement le coût de requêtes concurrentes. Ajouter une limitation
par IP/fréquence au proxy et un plafond global OpenRouter avant une ouverture publique.

**Reconnaître un e-mail n'en prouve pas la possession.** Le parcours simple demandé est
adapté à un pilote encadré, pas à une authentification forte : quelqu'un connaissant un
e-mail reconnu pourrait tenter une activation. Avant ouverture publique, ajouter un
code à usage unique envoyé à cette adresse (ou une session étudiante authentifiée),
ainsi qu'une limitation des tentatives d'activation. Ne pas journaliser les corps
d'activation, en-têtes Bearer, e-mails ni codes ; protéger les bases et leurs sauvegardes.

Le vocabulaire neutre et l'ouverture dans un navigateur externe **ne garantissent pas
la conformité Google Play**. Vérifier les règles applicables au pays, programme et
canal de distribution avant publication.

### Vérification

```bash
cd backend && python -m pytest -q
cd .. && python -m unittest discover -s mobile/tools -p 'test_*.py'
cd maquettes && npm ci && npm test
cd ../mobile && flutter test
```

Sans SDK Flutter/Android, les trois premières suites sont exécutables ; elles ne valident
pas un build Android. Sur téléphone : reconstruire entièrement après modification Kotlin,
essayer les deux modes, ouvrir/revenir du navigateur, activer, fermer/relancer l'app,
révoquer l'accès via Pulse et vérifier le retour du bloc d'activation. Tester un plafond
journalier puis mensuel, sans utiliser de vrais secrets dans les tests.
