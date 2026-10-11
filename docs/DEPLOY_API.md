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

Après déploiement, remplacer **`https://api.votre-domaine.tld`** ci-dessous par l'URL HTTPS réelle, et refaire les trois vérifications (santé, OpenAPI et import) contre cette URL. Une réponse 200 sur l'URL publique confirme la mise en ligne ; une réponse 200 locale ne la confirme pas.

## Connecter le téléphone

L'URL du backend doit être fournie **au build Flutter** ; l'application ne contient plus d'adresse IP personnelle implicite :

```bash
cd mobile
flutter run -d <ID_ANDROID> --dart-define=API_BASE_URL=https://api.votre-domaine.tld
# Puis, après validation de l'installation et de la signature release :
flutter build apk --release --dart-define=API_BASE_URL=https://api.votre-domaine.tld
```

Pour le développement seulement : `--dart-define=API_BASE_URL=http://10.0.2.2:8000` (émulateur), ou l'IP LAN de l'ordinateur (téléphone sur le même réseau). **Une version release refuse HTTP** pour l'import. Sans URL configurée, l'interface signale explicitement que le serveur manque au lieu d'essayer une adresse privée qui ne marcherait que chez le développeur. Les options `--dart-define` sont embarquées dans l'APK : n'y placer aucun secret.

## Ce qui bloque une ouverture au public sans précaution

- Le backend **n'authentifie pas les utilisateurs et ne limite pas le nombre de requêtes**. Les contrôles actuels (PDF jusqu'à 10 Mo, 20 pages, texte borné) ne remplacent ni quotas, ni protection contre les abus/attaques, ni plafonnement des coûts IA. Éviter de rendre OpenRouter accessible via cette API tant que ces protections ne sont pas mises en place. Une clé statique dans l'APK **n'est pas** une solution : elle peut être extraite.
- Pour un pilote, n'inviter qu'un groupe limité et utiliser au besoin des restrictions d'accès au niveau de l'hébergeur ; cela ne vaut pas une authentification par étudiant. Protéger HTTPS, logs (ne pas journaliser le texte des PDF), ressources CPU/mémoire et sauvegardes si des comptes sont ajoutés plus tard. Contrôler le comportement sur plusieurs PDF et sur un vrai téléphone avant distribution.
- Ce dépôt ne contient **ni intégration Chariow, ni quiz de supports de cours, ni OCR**. Ce guide ne déploie que l'API actuelle d'import d'emploi du temps et de comparaison.

**Validation ici :** lancement Uvicorn sur `0.0.0.0:8020`, `GET /health` 200, OpenAPI 200, `POST /api/import` avec le PDF L2 SIR : 200 et 7 cours. Le processus de test a ensuite été arrêté. L'image Docker n'a pas pu être construite dans cet environnement (Docker absent) ; le build Flutter et l'accessibilité depuis Internet restent aussi à vérifier sur les environnements cibles.
