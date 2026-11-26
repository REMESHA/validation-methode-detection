# 3. Installer et lancer le projet

## 3.1 Ce qu'il faut sur ton ordinateur

1. **R** (4.3 ou plus récent) : https://cran.r-project.org
2. **RStudio** : https://posit.co/download/rstudio-desktop/
3. **Quarto** : https://quarto.org/docs/get-started/ (si `quarto --version`
   répond dans un terminal, il est déjà installé ; les versions récentes de
   RStudio l'incluent)
4. **Git** : déjà installé chez toi (tu l'utilises pour tes autres dépôts)

## 3.2 Installer les packages R

Dans la console R, une seule fois :

```r
install.packages(c("yaml", "digest", "ggplot2", "lme4", "FrF2", "rsm",
                   "knitr", "rmarkdown", "testthat"))
```

`FrF2` installe aussi `DoE.base` et d'autres packages : c'est normal. Au
chargement, le message « Registered S3 method overwritten by 'DoE.base' » est
**sans gravité**.

## 3.3 Ouvrir le projet

1. Dézippe le dossier `validation-methode-detection`.
2. Double-clique sur `validation-methode-detection.Rproj`.
3. Vérifie dans la console : `getwd()` doit finir par
   `validation-methode-detection`.

## 3.4 Organisation des dossiers

```
validation-methode-detection/
├── config/
│   ├── config.yml                <- TOUS les paramètres
│   └── dictionnaire_variables.yml <- description de chaque variable
├── R/                         <- les fonctions (la "boîte à outils")
│   ├── fonctions_pod.R           POD, dPOD (Wilson, AOAC)
│   ├── fonctions_lod.R           LOD50, RLOD (modèle de Poisson)
│   ├── fonctions_lpod.R          LPOD, dLPOD (procédure AOAC en 6 étapes)
│   ├── fonctions_simulation.R    fabrication des données fictives
│   ├── fonctions_qc.R            contrôles qualité
│   ├── fonctions_tracabilite.R   empreintes, journal, versions
│   ├── fonctions_plans.R         banc d'essai simulé, limites physiques
│   ├── fonctions_dictionnaire.R  contrôle et résumé des variables
│   └── fonctions_reproductibilite.R  comparaison à la référence
├── scripts/                   <- les étapes, numérotées dans l'ordre
│   ├── 00_initialisation.R       chargé par tous les autres
│   ├── 01_simuler_donnees_brutes.R
│   ├── 02_controle_qualite.R
│   ├── 03_etude_matrice_pod.R
│   ├── 04_niveau_detection_lod50.R
│   ├── 05_etude_interlaboratoires.R
│   ├── 06_plan_criblage.R
│   ├── 07_plan_composite_surface.R
│   ├── 08_dictionnaire_variables.R
│   └── 09_verification_reproductibilite.R
├── executer_pipeline.R        <- lance toutes les étapes
├── data/
│   ├── raw/                      fichiers bruts (jamais modifiés à la main)
│   └── processed/                données propres après contrôle qualité
├── reference/                 <- exécution de référence (reproductibilité)
├── output/
│   ├── qc/                       registre des anomalies, bilan
│   ├── dictionnaire/             dictionnaire, contrôles, résumé des variables
│   ├── tracabilite/              manifeste SHA-256, journal, versions,
│   │                             vérification de reproductibilité
│   ├── tables/                   résultats en CSV
│   ├── figures/                  graphiques PNG
│   └── resultats/                objets R (.rds) lus par le rapport
├── rapport/index.qmd          <- le rapport Quarto
├── tests/                     <- tests automatiques
├── docs/                      <- ce guide
└── .github/workflows/         <- GitHub Actions
```

**Séparation fonctions / scripts** : les fichiers de `R/` ne font rien tout
seuls, ils définissent des fonctions. Les scripts de `scripts/` appellent ces
fonctions dans l'ordre. Avantage : une fonction peut être **testée** à part
(dossier `tests/`).

## 3.5 Tout lancer

Dans la console R (ou dans le terminal de RStudio pour `quarto`) :

```r
source("executer_pipeline.R")       # environ 30 secondes
```

```bash
Rscript tests/lancer_tests.R        # tests automatiques
quarto render rapport/index.qmd     # rapport HTML
```

Ouvre ensuite `rapport/index.html` dans ton navigateur.

Ce que tu dois voir dans la console pendant le pipeline :

```
[01_simulation] graine = 2026
[01_simulation] 8 fichiers bruts écrits
[02_qc] 8 fichiers bruts lus et empreintés
[02_qc] 1180 portions valides ; 6 anomalie(s) dont 5 bloquante(s)
[03_pod] 6 lignes POD/dPOD ; différence significative : 0
[04_lod50] LOD50 candidate = 1.50 UFC ; référence = 1.42 UFC ; RLOD = 1.06
[05_interlabo] 12 labos ; écart-type labo estimé = 0.31
[06_criblage] 20 essais ; courbure = 2.01 (p = 0.00332)
[07_composite] points axiaux 'rotatable' (alpha = 1.414) : dans les limites physiques
[07_composite] optimum (maximum) : 35.8 °C, 18.3 h ; S/B prédit = 11.61
[08_dictionnaire] 16 jeux, 124 variables documentées, 288 contrôles, 0 non conforme(s)
[09_reproductibilite] 23 fichiers comparés : 23 identique(s), 0 à la tolérance près, 0 différent(s)
[99_fin] pipeline terminé sans erreur
```

Ces chiffres ont été obtenus avec R 4.3.3 sous Linux. La dernière ligne
avant la fin te dit si **ton** exécution redonne les résultats de la
référence (chapitre 9).

Messages sans gravité sous Windows : « Rtools is required… » à
l'installation (les packages sont installés en version déjà compilée),
« package ‘…’ was built under R version 4.5.3 » (package préparé avec une
version de R un peu plus récente), « Registered S3 method overwritten by
'DoE.base' » (chargement de FrF2).

## 3.6 Lancer une seule étape

Chaque script peut tourner seul, à condition que les étapes précédentes aient
déjà tourné au moins une fois :

```r
source("scripts/04_niveau_detection_lod50.R")
```

Pour **apprendre**, ouvre le script et exécute-le ligne par ligne avec
Ctrl + Entrée. Après chaque ligne, regarde l'objet créé : `head(donnees)`,
`str(tab)`, `summary(modele)`.

## 3.7 Problèmes fréquents

| Message | Cause | Solution |
|---------|-------|----------|
| `Lancez les scripts depuis la racine du projet` | Mauvais dossier de travail | Ouvrir le `.Rproj`, ou `setwd()` vers le dossier du projet |
| `Packages manquants : …` | Package non installé | Lancer la commande `install.packages()` affichée |
| `Aucun fichier brut trouvé` | Script 02 lancé avant le 01 | Lancer `scripts/01_simuler_donnees_brutes.R` |
| `cannot open file '../output/resultats/qc.rds'` au rendu Quarto | Pipeline pas encore lancé | Lancer `executer_pipeline.R` avant `quarto render` |
| Accents illisibles (Ã©) sous Windows | Encodage | Dans RStudio : *File > Reopen with Encoding > UTF-8* ; le code lit déjà les fichiers en UTF-8 |
