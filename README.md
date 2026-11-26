# Validation statistique d'une méthode de détection de contaminants

[![pipeline](https://github.com/REMESHA/validation-methode-detection/actions/workflows/pipeline.yml/badge.svg)](https://github.com/REMESHA/validation-methode-detection/actions/workflows/pipeline.yml)

**Rapport en ligne :** https://remesha.github.io/validation-methode-detection/

> ⚠️ **Données simulées.** La méthode « candidate », la méthode de référence
> et le banc d'essai sont fictifs. Le projet montre une **démarche
> statistique** de validation, inspirée des lignes directrices AOAC
> (Appendix J, méthodes microbiologiques pour les aliments et les surfaces de
> l'environnement) et de l'ISO 16140-2. Ce n'est pas une validation conforme à
> ces référentiels.

## Objectif

Une méthode rapide de détection de contaminants bactériens sur des surfaces
mesure un signal de fluorescence dans une chambre optique. Le projet répond à
trois questions :

1. **Valider** : la méthode candidate détecte-t-elle aussi bien que la
   méthode de référence (culture) ?
2. **Optimiser** : quels paramètres physiques améliorent le signal, et quels
   réglages choisir ?
3. **Automatiser et tracer** : comment rendre l'analyse reproductible et
   vérifiable par un auditeur ?

## Ce que contient le projet

| Partie | Méthodes | Script |
|--------|----------|--------|
| Contrôle qualité des données brutes | 8 règles, registre d'anomalies, aucune correction silencieuse | `02_controle_qualite.R` |
| Étude de matrice (inox, plastique ; plan 5 / 20 / 5) | POD avec IC de Wilson, dPOD (non apparié) | `03_etude_matrice_pod.R` |
| Niveau de détection | LOD50 et RLOD, modèle de Poisson (GLM binomial, lien cloglog), test de la pente | `04_niveau_detection_lod50.R` |
| Étude interlaboratoires (12 laboratoires) | LPOD, dLPOD (procédure AOAC en 6 étapes : ANOVA, s_r / s_L / s_R, Satterthwaite), modèle linéaire généralisé mixte (`lme4`) avec IC par profil de vraisemblance | `05_etude_interlaboratoires.R` |
| Criblage de 5 paramètres physiques | Plan factoriel fractionnaire 2^(5-1) de résolution V + points au centre (`FrF2`) | `06_plan_criblage.R` |
| Optimisation | Plan composite centré avec contrôle automatique des limites physiques, surface de réponse, analyse canonique (`rsm`) | `07_plan_composite_surface.R` |
| Dictionnaire et restitution des variables | 16 fichiers, 124 variables décrites (type, unité, valeurs, bornes) ; 288 contrôles automatiques ; résumé descriptif de chaque variable | `08_dictionnaire_variables.R` |
| Reproductibilité | Comparaison valeur par valeur de 23 fichiers avec une exécution de référence | `09_verification_reproductibilite.R` |
| Traçabilité | Empreintes SHA-256, journal horodaté, versions de R / packages / commit Git | `R/fonctions_tracabilite.R` |
| Qualité du code | 74 tests automatiques (`testthat`), intégration continue (GitHub Actions) | `tests/` |

Les vraies valeurs de la simulation sont connues : chaque analyse est
comparée à la vérité, ce qui montre si les méthodes statistiques la
retrouvent.

## Lancer le projet

Prérequis : R ≥ 4.3, Quarto.

```r
install.packages(c("yaml", "digest", "ggplot2", "lme4", "FrF2", "rsm",
                   "knitr", "rmarkdown", "testthat"))
source("executer_pipeline.R")        # depuis la racine du projet
```

```bash
Rscript tests/lancer_tests.R
quarto render rapport/index.qmd
```

Tous les paramètres (plans d'étude, seuil de positivité, graine aléatoire,
limites physiques) sont dans [`config/config.yml`](config/config.yml).
Chaque variable de chaque fichier est décrite dans
[`config/dictionnaire_variables.yml`](config/dictionnaire_variables.yml).

**Reproductibilité** : une seule commande refait toute l'étude, de la
simulation des données brutes jusqu'aux résultats. Le script 09 compare
ensuite chaque fichier produit à l'exécution de référence du dossier
[`reference/`](reference/).

## Organisation

```
config/      paramètres et dictionnaire des variables (YAML)
R/           fonctions (POD, LOD, LPOD, QC, traçabilité, simulation, plans,
             dictionnaire, reproductibilité)
reference/   exécution de référence (vérification de reproductibilité)
scripts/     étapes numérotées du pipeline
data/raw/    fichiers bruts simulés (jamais modifiés)
data/processed/   données après contrôle qualité
output/      tables, figures, registre QC, traçabilité
rapport/     rapport Quarto
tests/       tests automatiques
docs/        guide détaillé (en français)
```

## Limites

- Données simulées, conformes aux hypothèses des modèles.
- Études non couvertes : inclusivité / exclusivité, confirmation, robustesse.
- Formule des degrés de liberté de la LPOD (Satterthwaite) reconstruite à
  partir d'une copie partiellement illisible du texte AOAC : à vérifier ;
  RLOD estimé par un modèle de Poisson et non par l'outil officiel de
  l'ISO 16140-2.
- Versions des packages enregistrées mais non figées (pas de `renv`).
- Le pipeline illustre des principes d'intégrité des données (ALCOA+) mais
  n'est pas un système informatisé validé.

## Auteur

Guy Darcy Remesha, biostatisticien —
[LinkedIn](https://www.linkedin.com/in/guy-darcy-remesha-07a27819a/) ·
ORCID [0009-0005-1801-3787](https://orcid.org/0009-0005-1801-3787)

## Références

- AOAC INTERNATIONAL (2012). *Appendix J: AOAC INTERNATIONAL Methods
  Committee Guidelines for Validation of Microbiological Methods for Food and
  Environmental Surfaces.* Official Methods of Analysis.
- Wehling P. et al. (2011). *Probability of Detection (POD) as a statistical
  model for the validation of qualitative methods.* Journal of AOAC
  International.
- ISO 16140-2:2016 (et amendement 1:2024). *Microbiologie de la chaîne
  alimentaire — Validation des méthodes — Partie 2.*
