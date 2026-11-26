# 6. Partie 3 — Automatisation, contrôles qualité et traçabilité

Scripts : `02_controle_qualite.R`, `executer_pipeline.R`.
Fonctions : `R/fonctions_qc.R`, `R/fonctions_tracabilite.R`. Tests : `tests/`.

---

## 6.1 Pourquoi c'est central chez un client pharmaceutique

Dans l'industrie pharmaceutique, une donnée qui sert à une décision
(libérer un lot, valider une méthode, déposer un dossier) doit être
**fiable et vérifiable**. Les autorités et les auditeurs parlent
d'**intégrité des données** et utilisent souvent l'acronyme **ALCOA+** :

| Lettre | Principe | Ce que fait le projet |
|--------|----------|-----------------------|
| **A**ttributable | On sait qui a produit la donnée | Colonnes `operateur`, `laboratoire`, `instrument` |
| **L**egible | Lisible et compréhensible | CSV en UTF-8, noms de colonnes explicites |
| **C**ontemporaneous | Enregistrée au moment où elle est produite | Colonne `date_analyse`, journal horodaté |
| **O**riginal | On garde la donnée d'origine | `data/raw/` n'est **jamais** modifié ; les données propres vont dans `data/processed/` |
| **A**ccurate | Exacte | Contrôles qualité automatiques, tests |
| **+** Complete, Consistent, Enduring, Available | Complète, cohérente, durable, disponible | Registre d'anomalies (rien n'est supprimé sans trace), Git, artefacts GitHub |

> Ce projet **illustre** ces principes. Il n'est pas un système informatisé
> validé au sens réglementaire (par exemple 21 CFR Part 11 aux États-Unis ou
> l'annexe 11 des BPF en Europe). Ne le présente jamais comme tel.

---

## 6.2 Le principe : ne jamais corriger en silence

Le script 02 lit les fichiers bruts et applique des **règles**. Quand une
règle n'est pas respectée :

- **bloquant** : la ligne est **exclue** de l'analyse ;
- **avertissement** : la ligne est **gardée** mais signalée ;
- dans les deux cas, une ligne est écrite dans
  `output/qc/registre_anomalies.csv` avec : le fichier, l'échantillon, la
  règle, la gravité, le détail.

Ce registre sert de base aux échanges avec le laboratoire (« l'échantillon
MAT-ACI-0019 a une date de 2025 : erreur de saisie ? »).

### Les règles (fonctions_qc.R)

| N° | Règle | Gravité | Pourquoi |
|----|-------|---------|----------|
| 0 | Colonnes obligatoires présentes | **arrêt total** | Un fichier mal formé ne doit pas être analysé |
| 1 | Doublon exact | bloquant (copie exclue) | Une même portion comptée deux fois fausse la POD |
| 2 | Même identifiant, contenus différents | bloquant (toutes les lignes) | On ne sait pas laquelle est la bonne |
| 3 | Niveau d'inoculation valide | bloquant | Indispensable aux calculs |
| 4 | Date dans la période d'étude | bloquant | Signe d'erreur de saisie ou de mauvais fichier |
| 5 | Signal présent | bloquant | Pas de résultat sans mesure |
| 6 | Signal ≥ 0 | bloquant | Un signal négatif est physiquement impossible |
| 7 | Signal < saturation (65 535) | avertissement | La portion est positive, mais la mesure est au plafond du détecteur |
| 8 | Résultat de référence = « positif » ou « negatif » | bloquant | Une faute de frappe (« pos ») ne doit pas être interprétée |

Tous les seuils sont dans `config.yml`, pas dans le code.

### Les anomalies injectées

`injecter_anomalies()` met volontairement 6 erreurs dans le fichier de l'inox
(une de chaque type). Le test `test-qc.R` vérifie qu'elles sont **toutes**
détectées, et qu'un fichier propre n'en déclenche **aucune**. Tester les deux
sens est important : un contrôle qui signale tout est aussi inutile qu'un
contrôle qui ne signale rien.

---

## 6.3 La traçabilité (fonctions_tracabilite.R)

### Empreinte SHA-256

```r
digest::digest(file = "data/raw/instrument/matrice_plastique.csv", algo = "sha256")
```

Donne une chaîne de 64 caractères. Si **un seul caractère** du fichier
change, l'empreinte change complètement. Le fichier
`output/tracabilite/manifeste_entrees.csv` liste chaque fichier lu, sa
taille, son nombre de lignes et son empreinte. Six mois plus tard, on peut
prouver que l'analyse a porté sur **ces** fichiers-là.

Essaie : ouvre un fichier brut, change un chiffre, relance le script 02 et
compare les empreintes.

**Fins de ligne.** Sous Windows, R écrit normalement les fins de ligne
« \r\n », et sous Linux « \n ». Les fichiers ont l'air identiques mais leurs
empreintes diffèrent. La fonction `ecrire_csv()` (script 00) ouvre les
fichiers en mode binaire (`open = "wb"`) pour écrire « \n » partout : les
empreintes sont alors les mêmes sous Windows et sous Linux.

### Version du code et de l'environnement

`output/tracabilite/environnement_execution.csv` contient la version de R,
celle de chaque package, et l'identifiant du **commit Git**. En local, avant
le premier commit, il affiche « non disponible » ; sur GitHub Actions, il
affiche le vrai commit.

### Le journal

`output/tracabilite/journal.csv` : une ligne horodatée par étape, avec un
résumé chiffré (nombre de portions valides, LOD50, optimum…). C'est un
résumé de l'exécution lisible par un humain.

---

## 6.4 L'automatisation

### Un seul point d'entrée

`executer_pipeline.R` lance les scripts dans l'ordre. Chaque script tourne
dans un **environnement neuf** (`source(e, local = new.env())`) : aucune
variable ne passe en cachette d'un script à l'autre. Si un script a besoin
d'un résultat, il le **relit sur le disque**. C'est plus robuste et plus
facile à auditer.

### Les tests automatiques (testthat)

`Rscript tests/lancer_tests.R` lance 74 vérifications, réparties en
7 fichiers :

- `test-pod.R` : notre IC de Wilson = celui de `prop.test()` ; cas 0/n et
  n/n conformes aux formules AOAC ; propriétés de la dPOD ;
- `test-lod.R` : sur de très grands jeux simulés, la LOD50 et le RLOD
  retrouvent les vraies valeurs à 5 % près ;
- `test-lpod.R` : composantes de variance identiques à celles de `aov()` ;
  cas limites des degrés de liberté ; Wilson pour une LPOD extrême ;
  formule de la dLPOD ;
- `test-qc.R` : toutes les anomalies sont détectées, aucune fausse alerte,
  arrêt si une colonne manque, seuil bien appliqué ;
- `test-plans.R` : codage, choix automatique des points axiaux selon les
  limites physiques ;
- `test-dictionnaire.R` : colonne en trop ou manquante, mauvais type,
  valeur non permise, borne dépassée sont détectés ;
- `test-reproductibilite.R` : la comparaison à la référence distingue
  « identique », « identique à la tolérance près » et « DIFFÉRENT ».

Un test qui échoue arrête GitHub Actions (croix rouge) : on ne publie pas un
rapport faux.

### GitHub Actions

Voir le chapitre 7. À chaque modification poussée sur GitHub : installation
→ pipeline → tests → rapport → publication. Les sorties (`output/`) sont
gardées comme **artefact** téléchargeable depuis l'onglet *Actions*.

---

## 6.5 Exercices

1. Ajoute une règle : « l'opérateur doit faire partie de la liste OP1, OP2,
   OP3 » (liste dans `config.yml`). Écris le test correspondant.
2. Ajoute une règle d'avertissement : « signal entre 800 et 1 200 RFU » (zone
   grise autour du seuil, résultat à confirmer).
3. Modifie un fichier brut à la main, relance, et retrouve la modification
   grâce au manifeste.
4. Fais échouer volontairement un test : dans `pod_ic()`, remplace
   `z2 <- z^2` par `z2 <- z^2 + 0.5`, lance les tests, lis le message, puis
   annule ta modification.
