# =====================================================================
# 08_dictionnaire_variables.R
# ---------------------------------------------------------------------
# Restitution et contrôle des variables :
#   1. écrit le dictionnaire des variables sous forme de tableau
#   2. vérifie que chaque fichier produit correspond EXACTEMENT au
#      dictionnaire (colonnes, types, valeurs permises, bornes)
#   3. produit un résumé descriptif de chaque variable
# Si un contrôle est "NON CONFORME", le script s'arrête : on ne publie
# pas des résultats dont la structure n'est pas celle documentée.
# =====================================================================

source("scripts/00_initialisation.R")
dir.create("output/dictionnaire", recursive = TRUE, showWarnings = FALSE)

dico <- yaml::read_yaml("config/dictionnaire_variables.yml",
                        fileEncoding = "UTF-8")

# ---- 1. Dictionnaire à plat ----------------------------------------
a_plat <- dictionnaire_a_plat(dico)
ecrire_csv(a_plat, "output/dictionnaire/dictionnaire_variables.csv")

# ---- 2. et 3. Contrôle et résumé, jeu par jeu ------------------------
controles <- list()
resumes <- list()
for (jeu in dico$jeux_de_donnees) {
  fichiers <- sort(Sys.glob(jeu$fichiers))
  if (length(fichiers) == 0) {
    controles[[length(controles) + 1]] <- data.frame(
      jeu_de_donnees = jeu$nom, fichier = jeu$fichiers, variable = "",
      controle = "fichier présent", statut = "NON CONFORME",
      detail = "aucun fichier trouvé", stringsAsFactors = FALSE)
    next
  }
  donnees_jeu <- list()
  for (f in fichiers) {
    d <- lire_csv(f)
    controles[[length(controles) + 1]] <- controler_jeu(d, jeu, f)
    donnees_jeu[[f]] <- d
  }
  # Résumé sur l'ensemble des fichiers du jeu (mêmes colonnes)
  communes <- Reduce(intersect, lapply(donnees_jeu, names))
  tout <- do.call(rbind, lapply(donnees_jeu, function(d) d[, communes, drop = FALSE]))
  resumes[[jeu$nom]] <- resumer_variables(tout, jeu$nom, jeu)
}
controles <- do.call(rbind, controles); rownames(controles) <- NULL
resumes <- do.call(rbind, resumes); rownames(resumes) <- NULL

ecrire_csv(controles, "output/dictionnaire/controle_dictionnaire.csv")
ecrire_csv(resumes, "output/dictionnaire/resume_variables.csv")
saveRDS(list(dictionnaire = a_plat, controles = controles,
             resumes = resumes),
        "output/resultats/dictionnaire.rds")

n_nc <- sum(controles$statut != "conforme")
journal_ecrire(chemin_journal, "08_dictionnaire",
               sprintf("%d jeux, %d variables documentées, %d contrôles, %d non conforme(s)",
                       length(dico$jeux_de_donnees), nrow(a_plat),
                       nrow(controles), n_nc))
if (n_nc > 0) {
  print(controles[controles$statut != "conforme", ])
  stop("Des fichiers ne correspondent pas au dictionnaire des variables ",
       "(voir output/dictionnaire/controle_dictionnaire.csv).", call. = FALSE)
}
