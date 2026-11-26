# =====================================================================
# 01_simuler_donnees_brutes.R
# ---------------------------------------------------------------------
# Fabrique les fichiers bruts FICTIFS, comme s'ils venaient :
#   - de l'instrument de la méthode candidate (data/raw/instrument/)
#   - du laboratoire de référence (data/raw/reference/)
# Dans un vrai projet, ce script n'existe pas : les fichiers arrivent
# du laboratoire. Tout le reste du pipeline fonctionnerait pareil.
# =====================================================================

source("scripts/00_initialisation.R")
dir.create("data/raw/instrument", recursive = TRUE, showWarnings = FALSE)
dir.create("data/raw/reference", recursive = TRUE, showWarnings = FALSE)
set.seed(cfg$graine)
journal_ecrire(chemin_journal, "01_simulation",
               paste("graine =", cfg$graine))

# ---- 1. Étude de matrice (2 matrices, plan 5 / 20 / 5) --------------
em <- cfg$etude_matrice
for (mat in em$matrices) {
  plan <- rbind(
    plan_portions("matrice", mat, em$niveaux_ufc, em$replicats, "candidate"),
    plan_portions("matrice", mat, em$niveaux_ufc, em$replicats, "reference"))
  sim <- simuler_etude(plan, cfg, prefixe = paste0("MAT-", toupper(substr(mat, 1, 3))))

  # Anomalies volontaires dans le fichier de l'acier seulement
  if (mat == "acier_inoxydable") {
    sim <- injecter_anomalies(sim$candidate, sim$reference)
  }
  ecrire_csv(sim$candidate,
             file.path("data/raw/instrument", paste0("matrice_", mat, ".csv")))
  ecrire_csv(sim$reference,
             file.path("data/raw/reference", paste0("matrice_", mat, ".csv")))
}

# ---- 2. Étude du niveau de détection (5 niveaux x 20 réplicats) -----
el <- cfg$etude_lod
niv <- as.list(el$niveaux_ufc)
rep <- as.list(rep(el$replicats, length(niv)))
plan <- rbind(plan_portions("lod", el$matrice, niv, rep, "candidate"),
              plan_portions("lod", el$matrice, niv, rep, "reference"))
sim <- simuler_etude(plan, cfg, prefixe = "LOD")
ecrire_csv(sim$candidate, "data/raw/instrument/lod_acier_inoxydable.csv")
ecrire_csv(sim$reference, "data/raw/reference/lod_acier_inoxydable.csv")

# ---- 3. Étude interlaboratoires (12 labos) ---------------------------
ei <- cfg$etude_interlabo
labos <- sprintf("LAB%02d", seq_len(ei$n_laboratoires))
# Chaque labo a sa propre efficacité (effet aléatoire sur l'échelle log)
effet_labo <- setNames(rnorm(length(labos), 0,
                             cfg$verite_simulation$sd_laboratoire_log), labos)
plan <- do.call(rbind, lapply(labos, function(l) rbind(
  plan_portions("interlabo", ei$matrice, ei$niveaux_ufc,
                lapply(ei$niveaux_ufc, function(x) ei$replicats),
                "candidate", l),
  plan_portions("interlabo", ei$matrice, ei$niveaux_ufc,
                lapply(ei$niveaux_ufc, function(x) ei$replicats),
                "reference", l))))
sim <- simuler_etude(plan, cfg, prefixe = "IL", effet_labo = effet_labo)
ecrire_csv(sim$candidate, "data/raw/instrument/interlabo_acier_inoxydable.csv")
ecrire_csv(sim$reference, "data/raw/reference/interlabo_acier_inoxydable.csv")

# On garde les "vrais" effets labo pour vérification (jamais utilisés
# dans l'analyse elle-même)
saveRDS(effet_labo, "output/resultats/verite_effet_labo.rds")

journal_ecrire(chemin_journal, "01_simulation",
               paste(length(list.files("data/raw", recursive = TRUE)),
                     "fichiers bruts écrits"))
