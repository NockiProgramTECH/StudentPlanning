# Vérification du PDF ESUPEX — L2 SIR, semaine du 12 octobre 2026

Source de test : `backend/tests/Emploi_temps_12 -17-oct 2026.pdf` (fichier fourni dans le dépôt). Il contient **13 pages** ; la page **6** porte l'en-tête `L2 SIR`, la page **12** porte `L3 - SIR`. Seule la page 6 est lue pour un étudiant L2 SIR. La date est vérifiée avant l'import.

| Jour | Début | Fin | Matière |
| --- | --- | --- | --- |
| Mardi | 07:30 | 12:30 | Transmission des signaux analogiques |
| Mercredi | 07:30 | 12:30 | Electronique analogique |
| Mercredi | 14:00 | 18:00 | Electronique analogique |
| Jeudi | 07:30 | 12:30 | TEEO |
| Vendredi | 07:30 | 12:30 | Electronique analogique |
| Vendredi | 14:00 | 18:00 | Electronique analogique |
| Samedi | 07:30 | 12:30 | Electronique analogique |

Le lundi n'a **aucun cours** dans cette grille. Les cases sont fusionnées sur plusieurs lignes d'horaires : la durée se lit sur les **bordures de cellule**, pas en déduisant la durée du texte centré. Salle et enseignant figurent dans la réponse structurée de l'API.

La bande **jaune** « PRÉVISION DES DEVOIRS » et les libellés **rouges** en bas de page sont des sections hors de la grille horaire. Ils ne doivent pas créer de devoir ni de cours en ligne pour cette semaine. Si une future case de cours est rouge ou jaune, l'API la proposera respectivement comme devoir ou cours en ligne **à vérifier** avant validation.

L'API sait traiter ce modèle de grille sans clé OpenRouter lorsque toutes les cases sont lisibles. Si la grille d'une autre semaine ne peut pas être reconstruite ou si une case est ambiguë, elle transmet uniquement les éléments de la classe choisie au modèle configuré ; elle ne doit pas attribuer automatiquement des cours à partir d'une autre filière.
