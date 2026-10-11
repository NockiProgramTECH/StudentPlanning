# Révisions et rappels Android (MVP)

La génération du programme se fait **dans l'application**, sans API ni compte. Elle utilise uniquement le planning **validé** sur le téléphone. Les données DÉMO ne déclenchent jamais de rappels.

## Règles de planification

- Séances de **50 minutes**, avec **10 minutes de pause** au minimum entre deux séances.
- Créneaux autorisés : **09 h–12 h** et **14 h–18 h** si libres ; à la maison **20 h–22 h 30** ; mêmes créneaux le samedi et le dimanche. Maximum **2 séances par jour** en semaine et **3 le week-end**. Les séances ne chevauchent pas les cours (marge de 10 minutes), ni les séances déjà terminées.
- La matière la **moins révisée la semaine précédente** passe en priorité. Seules les séances marquées « terminées » comptent, pas les séances simplement proposées. L'algorithme évite autant que possible la même matière deux fois par jour et favorise une évaluation proche.
- Les séances achevées sont conservées lors d'un recalcul ; seules les séances non terminées changent. Les comptes de la semaine N-1 restent en SQLite sur le téléphone.
- Les créneaux du soir et du week-end sont des **propositions**, pas une obligation. Une semaine passée ne reçoit plus de nouvelles séances.

## Alertes locales

- **Cours du matin uniquement** (début avant midi) : notification **1 heure avant**. Ainsi un cours à 07 h 30 donne un rappel à **06 h 30**, et un cours à 07 h 00 un rappel à 06 h 00. Pas de rappel pour les cours de l'après-midi.
- **Révisions** : notification **à l'heure de début** de la séance avec le nom de la matière. Une séance terminée annule son rappel.
- Sous Android 13+, l'utilisateur doit autoriser les notifications. Les alarmes futures sont gardées localement et réinstallées après redémarrage du téléphone. Sans autorisation d'alarme exacte sur certaines versions d'Android, le système peut décaler l'alerte de quelques minutes (économie de batterie). Aucun service de notification distant n'est utilisé. Le bouton « Tester une notification locale » permet de vérifier immédiatement les permissions sur un vrai téléphone.

**À vérifier sur appareil :** l'environnement de développement utilisé ici ne dispose pas de Flutter SDK ni d'un émulateur Android. Les tests Dart/Android (`cd mobile && flutter test`, puis test de notifications sur téléphone) restent à exécuter sur une machine équipée. La galerie HTML est une simulation visuelle qui n'émet jamais de notification réelle.
