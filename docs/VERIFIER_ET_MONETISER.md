# Vérifier Studia avant une mise en vente

## 1. Ce que prouvent les données fictives

- Dans l'application Flutter, ouvrir **Maquettes → 07 Révisions**. L'écran utilise les cours d'exemple L2 SIR de `mobile/lib/demo.dart`, ainsi que des fréquences **inventées** (Mathématiques : 3 séances terminées la semaine précédente ; Algorithmique : 1). Il montre les propositions du lundi au dimanche, les créneaux libres et du soir, les matières et une case « terminée » manipulable **en mémoire seulement**. Aucun accès SQLite, import de PDF, appel réseau ou programmation de rappel Android. Revenir à la maquette pour réinitialiser l'aperçu. Les maquettes HTML/JS dans `maquettes/` vérifient l'interface web, pas les alarmes Android.
- Le document `backend/tests/Emploi_temps_12 -17-oct 2026.pdf` sert à tester l'extraction d'un **vrai** emploi du temps L2 SIR : sa validation dans l'app n'est pas une simulation et enregistre les données localement. Ne pas l'utiliser pour une démo fictive sans le préciser.
- La planification en mémoire et l'algorithme sont couverts par les tests Flutter, l'API d'import par les tests backend ; ni l'un ni l'autre ne prouve que le système Android a réellement affiché une notification.

## 2. Depuis un poste avec Flutter, Android SDK et téléphone Android

```bash
cd mobile
flutter doctor -v
flutter pub get
flutter test
flutter devices
flutter clean
flutter pub get
flutter run -d <ID_ANDROID>
```

Fermer la précédente instance de l'app avant `flutter run` : les changements de code Kotlin ne sont **pas** chargés par un hot reload. Ne pas désinstaller sans sauvegarder l'historique SQLite. La configuration Android exige également le JDK compatible avec votre version du SDK (le projet cible Java 17). Vérifier sur le téléphone que le nouveau build est bien installé.

**Parcours d'acceptation :**

1. Parcourir la maquette **07 Révisions** ; vérifier que les chiffres fictifs sont indiqués comme DÉMO. Cocher une séance, revenir puis rouvrir : l'aperçu redevient vierge et ne se retrouve pas dans le vrai planning.
2. Importer et **valider** un planning de la semaine courante ou à venir (L2 SIR si vous utilisez le PDF fourni). Vérifier les jours, heures et matières avant de sauvegarder. Ouvrir Révisions : séances de 50 min dans les créneaux libres / 20 h–22 h 30 / week-end ; aucune superposition avec cours. Marquer une séance terminée : le compteur augmente. Comparer la semaine suivante : la matière moins révisée doit être priorisée, sauf contraintes d'emploi du temps/évaluation. Le simple fait d'afficher une proposition ne compte pas comme une séance terminée.
3. Autoriser les notifications dans Android (Android 13+). Dans Révisions, appuyer sur « Tester une notification immédiate » : elle doit apparaître. Puis « Tester un rappel dans 1 minute » : noter l'heure affichée, verrouiller l'écran, attendre au moins quelques minutes. Il s'agit d'une **alarme locale ponctuelle**, indépendante des cours et des statistiques. Relancer le test remplace seulement le test précédent. Android peut différer l'alarme si l'autorisation d'alarmes exactes ou l'économie de batterie l'impose ; le mode Ne pas déranger ou les réglages de notification peuvent masquer l'alerte. L'essai n'est disponible que dans l'écran Révisions d'un **planning validé, non expiré** et avec notifications autorisées, pas dans la maquette.
4. Test de bout en bout des vrais cours : avec un planning futur validé, laisser le téléphone sous tension ; vérifier un cours **avant midi** à T−1 h et une séance à son début. Si le cours est déjà passé, aucune alerte rétroactive. Ne pas modifier l'heure système pour simuler cela sur son téléphone principal. Vérifier qu'un redémarrage du téléphone conserve les futures alarmes (si autorisations et fabricant le permettent).

Si la notification immédiate fonctionne mais pas celle à 1 minute, vérifier les autorisations d'**alarmes exactes**, l'optimisation batterie et les journaux `adb logcat`, puis tester avec plusieurs minutes d'attente. Si `MissingPluginException` persiste après installation complète, relever le **canal et la méthode exacts**, l'OS et la sortie `flutter doctor -v`. L'écran de révisions devrait néanmoins rester consultable.

## 3. Construire un APK (ce dépôt ne contient pas d'APK précompilé)

```bash
cd mobile
flutter clean
flutter pub get
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=<MON_URL_PUBLIQUE_HTTPS>
# À installer localement pour essai, par exemple :
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Pour distribuer : configurer d'abord une **signature release** (keystore privé, jamais dans Git), l'identifiant d'application, les versions, la politique de confidentialité et les autorisations Android ; exécuter `flutter build apk --release --dart-define=API_BASE_URL=<MON_URL_PUBLIQUE_HTTPS>` (distribution directe) ou `flutter build appbundle --release --dart-define=API_BASE_URL=<MON_URL_PUBLIQUE_HTTPS>` (Play Store). Un APK debug n'est pas une version commerciale. Ne pas publier avant un essai sur un vrai téléphone.

## 4. Hypothèse commerciale : gratuite hors ligne + modules payants

Conserver gratuitement l'import/validation du planning, les révisions locales et les rappels. Facturer une valeur mesurable, par exemple analyse PDF améliorée, recommandations personnalisées ou synchronisation multi-appareils. Ne pas promettre « IA illimitée à vie » : chaque requête coûte des tokens ; calculer prix et quotas avec les coûts du modèle, commissions, charge serveur et support. Exemple **à ajuster après mesure** : forfait mensuel avec N analyses PDF et un budget maximal de tokens, puis blocage ou recharge explicite.

### OpenRouter : proposition d'architecture, non intégrée

`Flutter → FastAPI (authentification, quotas, validation des entrées) → OpenRouter (modèle choisi côté serveur) → validation JSON du résultat → écran de vérification humaine → stockage local seulement après validation`. Garder `OPENROUTER_API_KEY` dans l'environnement du **backend uniquement**, jamais dans l'APK ou le dépôt. Mettre un plafond de coût par utilisateur, des délais d'attente, une limite de taille et de fréquence de PDF, et traiter 402/429/5xx sans perdre le planning local. Avant de transmettre un emploi du temps étudiant : consentement, minimisation du contenu et vérification de la politique de confidentialité du modèle/fournisseur choisi. Le calcul des révisions et les rappels locaux n'ont pas besoin d'IA.

### Chariow : intégration Licence & Webhook Pulse côté serveur

L'intégration Chariow est implémentée dans `backend/app/chariow.py`, `backend/app/main.py` et `backend/app/course_quiz.py` conformément à la documentation officielle (`https://chariow.dev`) :

1. **Secrets strictement côté serveur FastAPI** (jamais dans Flutter ni dans Git) :
   - `CHARIOW_API_KEY=sk_live_...` (Settings → API Keys)
   - `CHARIOW_PULSE_SECRET=whsec_...` (Pulses → Signing secret)
   - `CHARIOW_PRODUCT_ID=prd_...` (optionnel : restreint l'activation à votre produit Studia L2 SIR)
2. **Activation et vérification de licence (`POST /api/licenses/activate`)** :
   - Interroge `GET https://api.chariow.com/v1/licenses/{licenseKey}` puis, si le statut est `pending_activation` ou qu'un nouvel `device_identifier` est présenté, appelle `POST https://api.chariow.com/v1/licenses/{licenseKey}/activate`.
   - Enregistre l'état de la licence dans SQLite (`chariow_licenses`) et délivre un jeton serveur (`studia_lic_...`) utilisable dans `Authorization: Bearer <token>` sur `/api/courses/*`.
3. **Webhook Chariow Pulse (`POST /api/webhooks/chariow`)** :
   - Vérifie la signature HMAC-SHA256 de l'en-tête `x-chariow-signature: sha256=<hex>` calculée sur les **octets bruts** du corps HTTP avec `CHARIOW_PULSE_SECRET` via `hmac.compare_digest`.
   - Déduplique les livraisons via `x-pulse-delivery-id` (`chariow_pulse_deliveries`).
   - Traite `license.issued`, `license.activated`, `license.expired` et `license.revoked` (révocation immédiate de l'accès aux endpoints `/api/courses/*`, sans jamais bloquer le planning local ni les révisions hors ligne).

Une vente directe d'APK peut utiliser un paiement externe sous réserve des obligations locales (factures, taxes, remboursements, données). **Sur Google Play**, les achats numériques dans l'application relèvent en général de Google Play Billing, avec exceptions/programmes et pays spécifiques : ne pas intégrer un lien d'achat Chariow in-app sans vérifier la politique qui s'applique à votre distribution. Chariow annonce publiquement une commission (actuellement 15 % selon sa page tarifaire) ; confirmer les conditions et frais applicables à votre compte avant de fixer un tarif.

Références : [OpenRouter authentification](https://openrouter.ai/docs/api_reference/authentication), [limites OpenRouter](https://openrouter.ai/docs/api_reference/limits), [Chariow : créer un produit licence](https://help.chariow.com/fr/articles/121-creer-un-produit-sur-chariow), [API Chariow](https://chariow.dev/api-reference/introduction), [Sécurité Pulse Chariow](https://chariow.dev/en/guides/pulse-security), [tarifs Chariow](https://chariow.com/fr/pricing), [politique Google Play](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en).
