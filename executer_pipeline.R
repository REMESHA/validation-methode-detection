# =====================================================================
# executer_pipeline.R
# ---------------------------------------------------------------------
# Lance tout le projet, dans l'ordre, depuis la racine du dépôt :
#     Rscript executer_pipeline.R
# Puis, pour le rapport :
#     quarto render rapport
# =====================================================================

if (!file.exists("config/config.yml")) {
  stop("Lancez ce script depuis la racine du projet.", call. = FALSE)
}

# Repartir d'un journal vide à chaque exécution complète
dir.create("output/tracabilite", recursive = TRUE, showWarnings = FALSE)
source("R/fonctions_tracabilite.R")
journal_initialiser("output/tracabilite/journal.csv")
journal_ecrire("output/tracabilite/journal.csv", "00_debut",
               "exécution complète du pipeline")

etapes <- c("scripts/01_simuler_donnees_brutes.R",
            "scripts/02_controle_qualite.R",
            "scripts/03_etude_matrice_pod.R",
            "scripts/04_niveau_detection_lod50.R",
            "scripts/05_etude_interlaboratoires.R",
            "scripts/06_plan_criblage.R",
            "scripts/07_plan_composite_surface.R",
            "scripts/08_dictionnaire_variables.R",
            "scripts/09_verification_reproductibilite.R")

for (e in etapes) {
  cat("\n==== ", e, " ====\n", sep = "")
  # Chaque script tourne dans un environnement neuf : pas de variable
  # cachée qui passerait d'un script à l'autre.
  source(e, local = new.env())
}

# Environnement d'exécution (versions) : la fin de la traçabilité
source("R/fonctions_tracabilite.R")
env <- environnement_execution(c("yaml", "digest", "ggplot2", "lme4",
                                 "FrF2", "rsm"))
con <- file("output/tracabilite/environnement_execution.csv", open = "wb")
write.csv(env, con, row.names = FALSE)
close(con)
journal_ecrire("output/tracabilite/journal.csv", "99_fin",
               "pipeline terminé sans erreur")
