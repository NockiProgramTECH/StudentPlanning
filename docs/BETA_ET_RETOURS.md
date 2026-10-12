# Bêta Studia : tester, écouter, puis décider

## Public et compatibilité

Studia est destiné aux étudiants, pas à une classe unique. L2 SIR correspond au
premier PDF réellement testé et au périmètre initial du pilote. La vitrine ne
restreint plus son public à cette classe, mais ne prétend pas que tous les formats
universitaires sont déjà validés. Tester plusieurs filières et plusieurs mises en
page avant d'annoncer une compatibilité générale.

Ce changement concerne la vitrine. Il ne remplace pas les exemples L2 SIR, les
libellés historiques de l'application ni les tests d'extraction : leur généralisation
est un chantier distinct, à valider avant de distribuer largement l'application.

## Le sens exact de STUDIA_FREE_ACCESS

- **`true` : module Supports de cours & Quiz IA ouvert gratuitement**, avec les quotas
  journaliers et mensuels par identifiant d'installation. Pas de code à saisir.
- **`false` : accès contrôlé**, configuration Chariow et accès actif nécessaires.
  Ce n'est ni le mode gratuit, ni un interrupteur global de toute l'application.

Le réglage est **global au serveur**, pas une période d'essai de sept jours par
étudiant. Le délai n'est pas automatique. Une semaine d'essai individuelle demanderait
un mécanisme serveur supplémentaire avec des dates de début et d'expiration.
La vitrine ne modifie jamais cette variable et n'affiche pas de faux compte à rebours.

## Parcours conseillé

1. Préparer une API HTTPS opérationnelle, une base persistante et un APK testé sur
   téléphone. Fixer quotas, protection contre les abus et plafond global fournisseur.
2. Annoncer les dates de la session gratuite, ses limites et le caractère expérimental.
   Activer `STUDIA_FREE_ACCESS=true`, redémarrer le backend et vérifier la configuration
   publique. Ne pas promettre de génération IA illimitée.
3. Pendant une semaine, faire tester import, correction, planning hors ligne, rappels et
   quiz à un petit groupe de différentes filières. Vérifier aussi les coûts et erreurs.
4. Recueillir les impressions **avant de fermer la session** : ce qui aide, ce qui bloque,
   ce qui manque, modèle du téléphone/version Android et version de l'app. Les issues
   GitHub sont publiques et nécessitent un compte ; ne pas demander de données étudiantes
   identifiantes ou de PDF contenant des informations personnelles. Pour un public non
   technique, un formulaire dédié pourra ensuite être ajouté avec sa politique de données.
5. Corriger, décider de l'offre et annoncer les nouvelles conditions à l'avance. Au moment
   prévu, passer à `STUDIA_FREE_ACCESS=false`, après vérification du portail, de l'activation,
   des webhooks et des règles applicables au canal de distribution.

Le passage de gratuit à contrôlé ne transfère pas automatiquement les supports serveur
de l'identité appareil vers l'identité d'accès. Prévenir les testeurs : les copies locales
restent disponibles, mais la poursuite de génération peut demander un réimport. Le planning
local et les révisions ne sont pas bloqués par le réglage du module de quiz.

## Préparer un véritable APK bêta

Au moment de ce changement, aucun APK ni release n'est publié dans le dépôt. Le site
ne peut pas fabriquer un binaire et ne doit pas pointer vers un téléchargement fictif.
Il faut une machine avec Flutter/Android SDK et **l'URL réelle de l'API HTTPS**.

1. Exécuter les tests Flutter et les contrôles Android de
   [VERIFIER_ET_MONETISER.md](VERIFIER_ET_MONETISER.md).
2. Configurer une signature privée pour le build release, puis construire :

   ```bash
   cd mobile
   flutter pub get
   flutter test
   flutter build apk --release --dart-define=API_BASE_URL=<URL_REELLE_HTTPS>
   ```

   Ne pas publier de build sans serveur configuré ni incorporer de secrets dans les
   `dart-define`. Conserver la clé de signature privée hors du dépôt et utiliser la même
   signature pour les mises à jour. Un APK debug ne convient qu'à des essais encadrés,
   pas à une version distribuée largement.
3. Installer sur un vrai téléphone et vérifier l'API, les imports, le retour navigateur,
   les quotas, les notifications et la conservation des données lors d'une mise à jour.
4. Publier le paquet universel sous le nom **`studia-beta.apk`** dans une préversion GitHub.
   Depuis la branche de session, après compilation et tests, exemple à adapter à la version :

   ```bash
   cp mobile/build/app/outputs/flutter-apk/app-release.apk \
      mobile/build/app/outputs/flutter-apk/studia-beta.apk
   gh release create v0.1.0-beta.1 \
     --target arena/3a1c530f-studentplanning \
     --prerelease --title 'Studia 0.1.0 — bêta Android' \
     --notes-file <NOTES_DE_VERSION> \
     mobile/build/app/outputs/flutter-apk/studia-beta.apk
   ```

   Le répertoire `build/` n'est pas versionné. Une release ne contenant qu'un seul
   autre fichier `.apk` est aussi reconnue par le site. Ne publier une release qu'après
   vérification du véritable APK.

Inclure dans les notes : version, prérequis Android réels, dates et quotas de la session,
limites connues, procédure d'installation, empreinte SHA-256 (`sha256sum` sur le binaire)
et lien de retour. Les APK restent dans les assets de release, pas dans Git.

## Comment le site trouve le téléchargement

« Tester la bêta » mène à la section `#beta`. « Vérifier la disponibilité » consulte les
30 releases publiques récentes, sans authentification, uniquement sur demande. La plus
récente préversion éligible contenant un APK officiel est proposée. Les archives sources
ne sont pas des APK. Les brouillons, fichiers vides et liens d'un autre dépôt sont refusés.
En présence de plusieurs APK spécifiques à une architecture, publier `studia-beta.apk`
pour fournir un choix universel ; sinon l'utilisateur est orienté vers la liste des versions.

Aucune release n'a été créée par ce changement. Dès qu'un véritable APK est publié, le
lien direct est proposé après vérification sans modifier le site. Sans release, en cas de
limitation API GitHub ou de panne réseau, la page reste explicite et donne accès à la liste
des versions et à la démo. Pas de requête GitHub avant l'action de l'utilisateur.
