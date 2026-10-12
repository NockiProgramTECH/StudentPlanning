# Construire Studia sur Codemagic

La racine du dépôt contient **`codemagic.yaml`**. Deux workflows manuels :

| Workflow | Usage | Artefact |
| --- | --- | --- |
| `android-debug` | Premier essai technique sur ton téléphone | `studia-test-debug.apk` |
| `android-beta` | Bêta release avec ta signature privée stable | `studia-beta.apk` |

Les builds Android locaux debug, release APK et AAB ont été vérifiés avec Flutter.
Le workflow Codemagic n'a pas encore été exécuté ; un essai sur téléphone réel reste
nécessaire avant de déclarer l'application prête. Ces workflows n'effectuent aucun
déploiement du backend et aucune publication automatique de l'APK.

## 1. Ajouter le dépôt et la configuration publique

Dans Codemagic :

1. Ajouter une application depuis le dépôt `NockiProgramTECH/StudentPlanning`.
2. Choisir la configuration **`codemagic.yaml` à la racine**, pas un fichier dans `mobile/`.
3. Créer un groupe de variables d'environnement nommé **`studia_android`**, accessible à
   cette application, contenant :

   | Variable | Valeur |
   | --- | --- |
   | `API_BASE_URL` | L'URL HTTPS **réelle du backend FastAPI**, sans `/docs`, `/health` ni `/api` final |

   Ce n'est **pas l'URL du site vitrine**, ni `localhost`, ni l'IP de l'émulateur.
   La valeur est publique et sera incorporée dans l'application ; ne jamais y placer
   un secret. Le groupe est importé par les deux workflows.
4. Sélectionner la branche **`arena/3a1c530f-studentplanning`** pour récupérer cette
   configuration. Elle sera aussi accessible depuis `main` après fusion de la PR.

Le YAML utilise une machine Linux, Java 17 et Flutter `stable`. Le `pubspec.lock` actuel
requiert **Flutter ≥ 3.44.0 / Dart ≥ 3.12.0**. `flutter pub get --enforce-lockfile` vérifie
les dépendances verrouillées. Si le SDK stable proposé par Codemagic est plus ancien,
choisir une version disponible compatible dans les deux champs `environment.flutter` ;
ne pas supprimer le verrouillage à l'aveugle pour contourner une erreur de dépendances.

## 2. Premier APK : aucune clé privée à fournir

Cliquer **Start new build**, choisir la branche ci-dessus et **Android - test rapide
(debug)** (`android-debug`). Le pipeline :

- vérifie la forme de l'URL et le compteur de build sans afficher de secret ;
- installe les dépendances Flutter depuis le lockfile ;
- exécute les tests Python des outils mobiles, l'analyse Dart et les tests Flutter ;
- construit l'APK debug et son empreinte SHA-256.

À la fin, télécharger **`studia-test-debug.apk`** depuis les artefacts du build.
C'est un build technique, pas la bêta à distribuer largement. La clé debug générée sur
une machine CI peut changer entre builds. Une signature différente peut empêcher une
mise à jour par-dessus une installation existante. **Ne pas désinstaller sans sauvegarder
les données locales**, qui seraient alors perdues. Préférer la signature stable ci-dessous
pour un groupe de testeurs.

## 3. Bêta signée : créer et conserver sa clé

Si tu possèdes déjà la clé ayant signé une version distribuée de Studia, **réutilise-la**.
Sinon, sur ta propre machine équipée du JDK, crée un keystore hors du dépôt :

```bash
keytool -genkeypair -v -storetype JKS \
  -keystore "$HOME/studia-beta.jks" \
  -alias studia \
  -keyalg RSA -keysize 2048 -validity 10000
```

Les mots de passe sont saisis dans les invites de `keytool`, pas dans le dépôt ni dans
une conversation. Sauvegarder le fichier et ses mots de passe dans un emplacement privé.
La même clé est nécessaire pour les futures mises à jour installées directement par APK.

Dans l'espace Codemagic **Code signing identities → Android keystores** :

- importer `studia-beta.jks` ;
- renseigner le mot de passe du keystore ;
- renseigner l'alias de clé **`studia`** et son mot de passe ;
- donner à cette identité la **référence `studia_beta`** utilisée dans le YAML ;
- autoriser son utilisation par cette application.

Codemagic fournit alors automatiquement les variables :

```text
CM_KEYSTORE_PATH
CM_KEYSTORE_PASSWORD
CM_KEY_ALIAS
CM_KEY_PASSWORD
```

Ne pas recopier ces valeurs dans le code. `mobile/android/app/build.gradle` les lit depuis
l'environnement. Le workflow bêta refuse de démarrer sans les quatre valeurs et vérifie
la signature avec `apksigner` après compilation. Aucun repli sur une clé debug pour le
build release. En local, `mobile/android/app/build.gradle` peut aussi signer avec un
keystore privé décrit dans `mobile/android/key.properties` (ignoré par Git) ; sans
configuration locale ou CI, le build release n'a pas de signature privée.

Lancer **Android - beta signee (release)** (`android-beta`). Récupérer :

```text
studia-beta.apk
studia-beta.apk.sha256
```

L'APK est universel (pas un APK choisi au hasard parmi plusieurs architectures).
Le `versionCode` est dérivé du compteur Codemagic (`BUILD_NUMBER + 1`) ; il doit toujours
être supérieur à celui de la dernière version distribuée. Lors d'un changement de
workflow/application CI, vérifier le compteur avant de publier. Le `versionName` provient
de `mobile/pubspec.yaml` (`0.1.0` actuellement) et doit évoluer avec les versions.

## 4. Commandes principales exécutées dans Codemagic

Les workflows fournissent déjà ces étapes. Il n'est pas nécessaire de les recopier
manuellement dans l'éditeur visuel :

```bash
cd "$CM_BUILD_DIR/mobile"
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release \
  --build-number="$((BUILD_NUMBER + 1))" \
  --dart-define="API_BASE_URL=$API_BASE_URL"
```

Pour le premier essai uniquement, remplacer `--release` par `--debug` et ne pas configurer
l'identité de signature. Les notices de lint restent visibles dans les logs ; seules
leur sévérité non bloquante est choisie, les erreurs d'analyse et les tests échoués
arrêtent toujours le pipeline.

Ne pas lancer `flutter create .` dans ce pipeline : le projet Android, les ressources et
les canaux natifs existent déjà. `flutter pub get` et la construction prennent en charge
les fichiers locaux générés. Le script CI rend `gradlew` exécutable.

## 5. Paramètres à mettre sur le backend, PAS dans Codemagic

Pour une session de bêta gratuite du module Supports de cours & Quiz IA :

```dotenv
STUDIA_FREE_ACCESS=true
OPENROUTER_API_KEY=<SECRET_SERVEUR>
STUDIA_MAX_DOCS_PER_DAY=5
STUDIA_MAX_QUIZ_REQUESTS_PER_DAY=20
STUDIA_MAX_TOKENS_PER_DAY=25000
STUDIA_MAX_COST_USD_PER_MONTH=1.50
```

Ces limites sont des valeurs de départ à ajuster après mesure, pas une protection globale
contre les abus. Configurer aussi le stockage persistant `STUDIA_DB_PATH`, HTTPS, la
limitation de débit et le plafond fournisseur. `CHARIOW_API_KEY` et `CHARIOW_PULSE_SECRET`
restent eux aussi uniquement côté backend lorsqu'on passe en accès contrôlé.

`true` = accès gratuit avec quotas. `false` = accès contrôlé ; cela ne crée pas de période
d'essai individuelle et ne bloque pas le planning local. Une modification serveur ne
nécessite pas de reconstruire l'APK. Une modification de `API_BASE_URL`, en revanche, oui.

Vérifier l'API réelle avant de distribuer, en remplaçant la valeur ci-dessous :

```bash
API_BASE_URL='https://<DOMAINE_REEL_DU_BACKEND>'
curl -fsS "${API_BASE_URL%/}/health"
curl -fsS "${API_BASE_URL%/}/api/access/config"
```

Résultats attendus : `{"status":"ok"}` et `{"free_access":true,"portal_url":"/api/access/portal"}`.
La validation CI de l'URL est **syntaxique** : elle ne prouve ni que le serveur existe,
ni qu'il est accessible depuis le téléphone, ni que le compte OpenRouter fonctionne.

## 6. Rendre la bêta téléchargeable sur la vitrine

Un artefact Codemagic n'est pas automatiquement une release publique GitHub.
Après essai sur un téléphone réel :

1. Télécharger `studia-beta.apk` et son empreinte depuis Codemagic.
2. Créer une préversion GitHub du dépôt (par exemple `v0.1.0-beta.1`) avec des notes
   décrivant dates, limites connues, quotas et installation.
3. Joindre **`studia-beta.apk`** aux assets de cette préversion, pas au code Git.
4. Sur la vitrine, cliquer **Vérifier la disponibilité** : le bouton de téléchargement
   apparaîtra lorsque cet APK réel sera trouvé.

Voir [BETA_ET_RETOURS.md](BETA_ET_RETOURS.md) pour le lancement et les impressions des
testeurs. Les formats PDF, les notifications Android et les libellés historiques de
l'application restent à valider au-delà du premier pilote ; le site ne remplace pas
ces vérifications. La conformité d'une distribution commerciale reste un sujet séparé.
