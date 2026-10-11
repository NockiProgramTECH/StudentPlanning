# Icône, splash et sons Android de Studia

## Identité visuelle

- Icône source : [`mobile/branding/studia_icon_master.png`](../mobile/branding/studia_icon_master.png). Livre ouvert, coche et accent soleil ; couleurs cohérentes avec `mobile/lib/theme.dart`.
- Visuel portrait du splash : [`mobile/branding/studia_splash_master.png`](../mobile/branding/studia_splash_master.png). Sur Android, le vrai écran de démarrage reprend son emblème centré sur un fond ivoire : cela s'adapte aux différentes tailles et au splash imposé par **Android 12+** (qui ne permet pas d'afficher librement une image plein écran). Les lignes discrètes de la maquette portrait sont donc une **prévisualisation créative**, pas des éléments affichés sur tous les téléphones.
- Anciennes versions Android : `res/drawable/launch_background.xml` centre l'emblème. Android 12+ : `res/values-v31/styles.xml` utilise le splash système. L'icône existe en cinq densités classiques, en version adaptative (Android 8+) et monochrome thématique (Android 13+). Le manifeste Android pointe vers `@mipmap/ic_launcher`.
- Les sources et ressources générées sont incluses dans le dépôt. Pour régénérer après modification des sources : `python -m pip install pillow` puis `python mobile/tools/generate_brand_assets.py` depuis la racine du dépôt. Pillow n'est **pas** une dépendance de l'APK.

## Son des notifications

- **Cours** : `res/raw/studia_course.wav`, deux notes ascendantes. **Révisions** (y compris les deux tests depuis l'écran Révisions) : `res/raw/studia_revision.wav`, trois notes distinctes. Ces sons sont générés localement ; ils ne proviennent pas de la bibliothèque de sons système d'Android.
- Android 8+ impose le son au niveau du **canal de notification**, qui est immuable après sa première création. Pour mettre à jour les installations existantes sans effacer les données, les nouveaux canaux sont `courses_studia_v2` et `revisions_studia_v2`. Les alarmes déjà prévues conservent leurs informations de cours/révision ; leur réception utilise automatiquement le bon nouveau canal. Les anciens canaux peuvent encore apparaître dans les réglages et ne sont pas supprimés. Sur Android 7 et antérieur, le son est défini sur chaque notification.
- Un utilisateur peut toujours couper/changer le son du canal dans **Paramètres Android → Applications → Studia → Notifications**. Le mode silencieux, « Ne pas déranger », un refus d'autorisation, ou les restrictions du fabricant peuvent empêcher d'entendre une alerte. L'application ne force **jamais** le volume ni ne contourne ces choix.

## Vérification après installation

```bash
python -m unittest discover -s mobile/tools -p 'test_*.py'
cd mobile
flutter clean
flutter pub get
flutter test
flutter run -d <ID_ANDROID>
```

Fermer l'application avant de la reconstruire, **sans la désinstaller** si vous souhaitez conserver SQLite. Regarder l'icône dans le lanceur et le splash au démarrage à froid (pas un hot reload). Valider un planning courant/futur ; dans Révisions, autoriser les notifications, tester la notification immédiate puis celle dans une minute. Le test joue le **son Révisions**. Pour le **son Cours**, il faut attendre une vraie alarme de cours du matin, normalement une heure avant, avec un planning validé ; les maquettes n'envoient pas d'alertes. Vérifier dans les réglages Android que les deux nouveaux canaux ont un son actif. Si le son reste celui du téléphone : ouvrir les réglages du canal, vérifier son choix, le volume et le mode silencieux ; indiquer l'OS et le modèle de téléphone. Ces sons n'ont pas été auditionnés ni vérifiés sur un appareil dans l'environnement de développement actuel (sans Flutter SDK/Android SDK).
