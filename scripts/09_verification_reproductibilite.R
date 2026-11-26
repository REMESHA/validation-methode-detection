# =====================================================================
# 09_verification_reproductibilite.R
# ---------------------------------------------------------------------
# Les résultats de cette exécution sont-ils les mêmes que ceux de
# l'exécution de référence (dossier reference/) ?
#
# - Si le dossier reference/ n'existe pas, il est CRÉÉ à partir de cette
#   exécution (première fois). Il faut alors le versionner avec Git.
# - Sinon, chaque fichier est comparé valeur par valeur.
# Pour refaire la référence volontairement (par exemple après avoir
# changé config.yml) : supprimer le dossier reference/ et relancer.
# =====================================================================

source("scripts/00_initialisation.R")

dossier_ref <- "reference"
fichiers <- fichiers_a_comparer()
chemins_ref <- file.path(dossier_ref, fichiers)

if (!dir.exists(dossier_ref)) {
  # ---- Première exécution : création de la référence ----------------
  for (i in seq_along(fichiers)) {
    dir.create(dirname(chemins_ref[i]), recursive = TRUE, showWarnings = FALSE)
    file.copy(fichiers[i], chemins_ref[i], overwrite = TRUE)
  }
  info <- c(
    "# Exécution de référence",
    "",
    paste("Créée le :", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
    paste("R :", R.version.string),
    paste("Système :", Sys.info()[["sysname"]], Sys.info()[["release"]]),
    paste("Graine :", cfg$graine),
    "",
    "Ces fichiers servent à vérifier que chaque nouvelle exécution du",
    "pipeline redonne les mêmes résultats (script 09).",
    "Ne pas les modifier à la main.")
  writeLines(info, file.path(dossier_ref, "LISEZMOI.md"), useBytes = TRUE)
  verif <- data.frame(fichier = fichiers, statut = "référence créée",
                      ecart_relatif_max = NA_real_, detail = "",
                      stringsAsFactors = FALSE)
  journal_ecrire(chemin_journal, "09_reproductibilite",
                 paste("référence créée avec", length(fichiers), "fichiers"))
} else {
  # ---- Exécutions suivantes : comparaison ---------------------------
  tol <- cfg$reproductibilite$tolerance_relative
  verif <- do.call(rbind, Map(comparer_fichiers, fichiers, chemins_ref,
                              MoreArgs = list(tolerance = tol)))
  rownames(verif) <- NULL
  n_diff <- sum(grepl("DIFFÉRENT|ABSENT", verif$statut))
  journal_ecrire(chemin_journal, "09_reproductibilite",
                 sprintf("%d fichiers comparés : %d identique(s), %d à la tolérance près, %d différent(s)",
                         nrow(verif), sum(verif$statut == "identique"),
                         sum(verif$statut == "identique à la tolérance près"),
                         n_diff))
  if (n_diff > 0) {
    # Non bloquant : une différence peut venir d'une autre version d'un
    # package. Elle est signalée dans le rapport, à examiner.
    warning("Résultats différents de la référence : voir ",
            "output/tracabilite/verification_reproductibilite.csv",
            call. = FALSE)
  }
}

ecrire_csv(verif, "output/tracabilite/verification_reproductibilite.csv")
ref_info <- if (file.exists(file.path(dossier_ref, "LISEZMOI.md")))
  readLines(file.path(dossier_ref, "LISEZMOI.md")) else character(0)
saveRDS(list(verification = verif, reference = ref_info),
        "output/resultats/reproductibilite.rds")
