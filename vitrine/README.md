# Studia — site vitrine

Une vitrine éditoriale en français pour Studia, destinée aux **étudiants de toutes les filières**.
Les premiers tests sur une classe pilote ne constituent pas une restriction de public ;
la compatibilité des différents formats de PDF reste à valider.
Indépendante des maquettes HTML, de Flutter et du backend FastAPI.

## Lancer

```bash
cd vitrine
npm start
# http://localhost:4173
```

Aucune compilation ni dépendance JavaScript de production : HTML, CSS et JavaScript natifs.
Le serveur d'aperçu écoute sur `0.0.0.0`. Les liens et ressources sont relatifs et ne
contiennent aucune adresse locale codée en dur.

## Tester

```bash
cd vitrine
npm ci
npm test
```

Les tests Node/jsdom couvrent les liens et ressources, le menu mobile, les jours du
planning, les étapes et leur navigation clavier, la démo et sa réinitialisation, les
informations de confidentialité, les liens externes et la disponibilité réelle des APK bêta.

## Contenu et interactions

- Direction artistique ivoire / vert profond / citron, typographies Manrope et Instrument Serif.
- Illustrations d'interface en HTML/CSS/SVG, sans capture de données personnelles.
- Apparition progressive au défilement, cartes flottantes, transitions et micro-interactions.
- Respect de `prefers-reduced-motion` et contenu lisible sans les animations.
- Parcours en trois étapes, jours interactifs dans l'aperçu du téléphone.
- Démo modale : planning fictif, suivi de révisions et QCM avec explication.
- Menu mobile, navigation clavier des onglets, dialogues natifs avec fermeture Échap
  et restitution du focus, FAQ et information sur les données.

**Pas de backend Studia connecté, pas d'inscription, pas de stockage navigateur, pas de cookie
applicatif ni d'outil de suivi.** La seule requête tierce dans le JavaScript est une recherche
sur l'API publique GitHub, uniquement après un clic sur « Vérifier la disponibilité ». La démo utilise des exemples explicitement fictifs,
conservés uniquement en mémoire et réinitialisés à chaque ouverture. Les éventuels journaux
techniques d'hébergement sont distincts. GitHub reçoit les informations techniques de
connexion lors de la vérification des versions. Sans APK publié, aucun faux lien de
téléchargement n'est affiché.

Les noms d'étudiants, témoignages et chiffres d'adoption ne sont pas inventés. Les horaires
illustrent le produit ; ils ne remplacent pas le planning officiel de l'université.

## Déployer

Publier ces fichiers sur un hébergeur statique HTTPS :

- `index.html`
- `styles.css`
- `app.js` et `beta.js`
- `assets/` (inclure les licences des polices)

Aucune variable d'environnement et aucune clé API nécessaires. Ne pas publier
`node_modules/`, `tests/` ni le reste du dépôt. La vitrine fonctionne aussi dans un
sous-répertoire. Un domaine permanent n'est pas configuré par ce changement.

Les polices sont hébergées localement et distribuées sous licence SIL Open Font License :
voir `assets/fonts/*-LICENSE.txt`. Les icônes SVG et illustrations sont intégrées localement.


## Bêta Android et retours

La navigation et le bouton principal dirigent vers `#beta`. Un clic de vérification consulte
les 30 releases publiques les plus récentes du dépôt. Seules les préversions ou les tags
contenant « beta » sont retenus, avec un véritable fichier `.apk` publié de taille non nulle.
Les brouillons, réponses invalides, URL hors du dépôt officiel et erreurs réseau ne créent
jamais de lien. Les versions candidates sont triées par date de publication décroissante.

Nom conseillé pour le paquet universel : **`studia-beta.apk`**. À défaut, une release avec
un unique APK est acceptée. Plusieurs APK spécifiques à des architectures sans paquet
universel ne sont pas choisis arbitrairement : les versions officielles restent accessibles.
Pas d'appel réseau automatique ni de clé GitHub côté site.

La section propose un retour prérempli via une issue GitHub. Ce service demande un compte ;
les retours sont publics. Le message et la page avertissent de ne pas y déposer de code,
e-mail personnel ni document étudiant non anonymisé. Aucun faux formulaire de collecte.

La procédure pour préparer l'APK et organiser une semaine d'essai est décrite dans
[`docs/BETA_ET_RETOURS.md`](../docs/BETA_ET_RETOURS.md). Le bouton ne construit pas l'APK et
ne change pas la configuration du backend.
