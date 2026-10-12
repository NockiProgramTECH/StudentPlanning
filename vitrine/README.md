# Studia — site vitrine

Une vitrine éditoriale en français pour le projet Android Studia, **L2 SIR uniquement**.
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

Les six tests Node/jsdom couvrent les liens et ressources, le menu mobile, les jours du
planning, les étapes et leur navigation clavier, la démo et sa réinitialisation, les
informations de confidentialité et les liens externes.

## Contenu et interactions

- Direction artistique ivoire / vert profond / citron, typographies Manrope et Instrument Serif.
- Illustrations d'interface en HTML/CSS/SVG, sans capture de données personnelles.
- Apparition progressive au défilement, cartes flottantes, transitions et micro-interactions.
- Respect de `prefers-reduced-motion` et contenu lisible sans les animations.
- Parcours en trois étapes, jours interactifs dans l'aperçu du téléphone.
- Démo modale : planning fictif, suivi de révisions et QCM avec explication.
- Menu mobile, navigation clavier des onglets, dialogues natifs avec fermeture Échap
  et restitution du focus, FAQ et information sur les données.

**Pas de backend connecté, pas d'inscription, pas de stockage navigateur, pas de cookie
applicatif ni d'outil de suivi.** La démo utilise des exemples explicitement fictifs,
conservés uniquement en mémoire et réinitialisés à chaque ouverture. Les éventuels journaux
techniques d'hébergement sont distincts. Le statut « projet en développement » et l'absence
de téléchargement public sont indiqués : aucun faux bouton de téléchargement.

Les noms d'étudiants, témoignages et chiffres d'adoption ne sont pas inventés. Les horaires
illustrent le produit ; ils ne remplacent pas le planning officiel de l'université.

## Déployer

Publier ces fichiers sur un hébergeur statique HTTPS :

- `index.html`
- `styles.css`
- `app.js`
- `assets/` (inclure les licences des polices)

Aucune variable d'environnement et aucune clé API nécessaires. Ne pas publier
`node_modules/`, `tests/` ni le reste du dépôt. La vitrine fonctionne aussi dans un
sous-répertoire. Un domaine permanent n'est pas configuré par ce changement.

Les polices sont hébergées localement et distribuées sous licence SIL Open Font License :
voir `assets/fonts/*-LICENSE.txt`. Les icônes SVG et illustrations sont intégrées localement.
