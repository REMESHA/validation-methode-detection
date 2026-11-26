# 2. Les outils du projet

Pour chaque outil : **ce que c'est**, **à quoi il sert ici**, et **ce qu'il
faut savoir dire** en entretien.

## 2.1 Langage et environnement

### R
Langage de statistique. Tout le calcul du projet est en R (version 4.3 ou
plus récente). Tu le maîtrises déjà ; ici, il est utilisé en **scripts**
(fichiers `.R` lancés du début à la fin) plutôt qu'en exploration à la main.

### RStudio (ou Positron)
L'éditeur dans lequel tu ouvres le projet. Ouvre toujours le fichier
`validation-methode-detection.Rproj` : RStudio se place alors automatiquement
à la **racine** du projet, ce qui est indispensable car tous les chemins sont
écrits à partir de la racine (`config/config.yml`, `data/raw/…`).

### Rscript
La commande qui lance un script R **sans** ouvrir RStudio, dans un terminal :
`Rscript executer_pipeline.R`. C'est ce que fait GitHub Actions.

## 2.2 Les packages R

| Package | Rôle dans le projet | Fonctions utilisées |
|---------|--------------------|---------------------|
| **yaml** | Lire le fichier de configuration `config/config.yml` | `read_yaml()` |
| **digest** | Calculer l'empreinte SHA-256 des fichiers bruts (traçabilité) | `digest(file = , algo = "sha256")` |
| **ggplot2** | Toutes les figures | `ggplot()`, `geom_pointrange()`, `geom_contour_filled()`… |
| **lme4** | Modèle linéaire généralisé **mixte** pour l'étude interlaboratoires | `glmer()`, `fixef()`, `VarCorr()` |
| **FrF2** | Construire le plan **factoriel fractionnaire** à 2 niveaux | `FrF2()`, `generators()` |
| **rsm** | Plan **composite centré** et **surface de réponse** | `ccd()`, `rsm()`, `SO()`, `decode.data()` |
| **testthat** | Tests automatiques du code | `test_that()`, `expect_equal()` |
| **knitr / rmarkdown** | Utilisés par Quarto pour exécuter le R dans le rapport | (automatique) |

Fonctions de base R importantes :

- `glm(..., family = binomial(link = "cloglog"))` : régression binomiale avec
  lien log-log complémentaire (modèle de la LOD50) ;
- `confint()` : intervalles de confiance par **profil de vraisemblance**
  (plus fiables que « estimation ± 1,96 × erreur type » quand les effectifs
  sont petits) ;
- `anova(m1, m2, test = "LRT")` : test du rapport de vraisemblance entre deux
  modèles emboîtés ;
- `prop.test(x, n, correct = FALSE)` : sert dans les tests à vérifier notre
  intervalle de Wilson avec un calcul indépendant.

## 2.3 Quarto

Outil de rédaction de rapports : du texte (Markdown) + des morceaux de code R
qui s'exécutent. Le fichier `rapport/index.qmd` donne `rapport/index.html`.
Points utilisés ici :

- `embed-resources: true` : toutes les images sont **dans** le fichier HTML
  (un seul fichier à envoyer) ;
- **code en ligne** : `` `r f2(lod$rlod$rlod)` `` écrit un chiffre calculé
  dans le texte. Ainsi, le texte ne peut pas contredire les résultats ;
- les blocs `::: {.callout-warning}` font les encadrés colorés.

Commande : `quarto render rapport/index.qmd`.

## 2.4 Configuration en YAML

`config/config.yml` contient **tous les paramètres** : seuil de positivité,
plans des études, graine aléatoire, vraies valeurs de la simulation. Le YAML
est un format texte lisible (indentation = hiérarchie). Pourquoi c'est
important en milieu réglementé :

- un paramètre se change à **un seul endroit** ;
- le fichier est **versionné** avec Git : on sait qui a changé le seuil,
  quand, et pourquoi (message de commit).

## 2.5 Git et GitHub

- **Git** : garde l'historique de toutes les versions du code. Chaque
  « commit » a un identifiant unique (40 caractères). Le pipeline écrit cet
  identifiant dans `output/tracabilite/environnement_execution.csv` : on
  sait exactement quelle version du code a produit les résultats.
- **GitHub** : héberge le dépôt en ligne.
- **GitHub Actions** : un ordinateur de GitHub relance tout le pipeline à
  chaque modification (fichier `.github/workflows/pipeline.yml`). Si le code
  casse ou si un test échoue, tu le vois tout de suite (croix rouge).
- **GitHub Pages** : publie le rapport HTML à une adresse publique, du type
  `https://remesha.github.io/validation-methode-detection/`.

Tu as déjà utilisé ces outils pour l'observatoire des prix du porc : c'est le
même principe.

## 2.6 Le fichier DESCRIPTION

Il liste les packages nécessaires. GitHub Actions le lit
(`setup-r-dependencies`) pour installer automatiquement les bons packages.
Ce n'est pas un package R au sens strict (`Type: Project`).

## 2.7 Ce qu'il faut savoir dire

> « J'ai organisé l'analyse en pipeline scripté : les paramètres sont dans un
> fichier de configuration versionné, chaque fichier d'entrée est identifié
> par son empreinte SHA-256, les anomalies sont écrites dans un registre au
> lieu d'être corrigées en silence, des tests automatiques vérifient les
> calculs, et tout est relancé automatiquement par GitHub Actions. »

Cette phrase est vraie pour ce projet, et elle répond directement à la
mission « automatisation et traçabilité » de l'offre.
