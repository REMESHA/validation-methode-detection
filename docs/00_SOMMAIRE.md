# Guide d'apprentissage — sommaire

Ce guide accompagne le projet pas à pas. Il est écrit pour quelqu'un qui
découvre la validation de méthodes microbiologiques et les plans
d'expériences. Lis-le **dans l'ordre**.

| N° | Fichier | Contenu | Temps conseillé |
|----|---------|---------|-----------------|
| 1 | [01_contexte_metier.md](01_contexte_metier.md) | Le métier : validation de méthode, AOAC, ISO 16140-2, vocabulaire | 1 h 30 |
| 2 | [02_outils.md](02_outils.md) | Chaque outil du projet : à quoi il sert, pourquoi on l'a choisi | 1 h |
| 3 | [03_installer_et_lancer.md](03_installer_et_lancer.md) | Installer, lancer le pipeline, lire les sorties | 1 h |
| 4 | [04_partie1_validation.md](04_partie1_validation.md) | POD, dPOD, LOD50, RLOD, étude interlaboratoires, expliqués ligne par ligne | 3 h |
| 5 | [05_partie2_plans_experiences.md](05_partie2_plans_experiences.md) | Criblage (plan fractionnaire) puis optimisation (surface de réponse) | 2 h 30 |
| 6 | [06_partie3_pipeline_tracabilite.md](06_partie3_pipeline_tracabilite.md) | Contrôles qualité, traçabilité, intégrité des données, tests | 1 h 30 |
| 7 | [07_publier_sur_github.md](07_publier_sur_github.md) | Mettre le projet en ligne, faire tourner GitHub Actions et GitHub Pages | 1 h |
| 8 | [08_limites_et_entretien.md](08_limites_et_entretien.md) | Les limites du projet, ce que tu peux dire (ou non), questions d'entretien | 1 h |
| 9 | [09_reproductibilite_et_dictionnaire.md](09_reproductibilite_et_dictionnaire.md) | Étude reproductible de bout en bout, dictionnaire et restitution des variables | 1 h 30 |

Total : environ 15 heures, réparties sur plusieurs jours.

## Comment travailler

1. Lis un chapitre.
2. Ouvre le script correspondant dans RStudio et exécute-le **ligne par
   ligne** (Ctrl + Entrée), en regardant ce que contient chaque objet.
3. Fais les petits exercices proposés à la fin des chapitres 4, 5 et 6.
4. Note tes questions : elles deviendront tes réponses en entretien.

## Règle d'or

Le projet utilise des **données simulées**. C'est une force (on connaît la
vérité et on peut vérifier que les méthodes la retrouvent) et une limite (le
labo réel est plus compliqué). Il faut toujours le dire clairement.
