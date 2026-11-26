# =====================================================================
# 02_controle_qualite.R
# ---------------------------------------------------------------------
# 1. Liste et "empreinte" les fichiers bruts (traçabilité)
# 2. Applique les contrôles qualité à chaque fichier
# 3. Classe chaque portion de la méthode candidate en positif/négatif
#    selon le seuil de config.yml
# 4. Écrit : les données propres, le registre d'anomalies, un bilan
# =====================================================================

source("scripts/00_initialisation.R")

# ---- 1. Manifeste des fichiers d'entrée ------------------------------
fichiers_instr <- sort(list.files("data/raw/instrument", "\\.csv$",
                                  full.names = TRUE))
fichiers_ref   <- sort(list.files("data/raw/reference", "\\.csv$",
                                  full.names = TRUE))
if (length(fichiers_instr) == 0 || length(fichiers_ref) == 0) {
  stop("Aucun fichier brut trouvé. Lancez d'abord ",
       "scripts/01_simuler_donnees_brutes.R", call. = FALSE)
}
manifeste <- manifeste_fichiers(c(fichiers_instr, fichiers_ref))
ecrire_csv(manifeste, "output/tracabilite/manifeste_entrees.csv")
journal_ecrire(chemin_journal, "02_qc",
               paste(nrow(manifeste), "fichiers bruts lus et empreintés"))

# ---- 2. et 3. Contrôles fichier par fichier --------------------------
resultats <- list()
anomalies <- list()
bilan <- list()

for (f in fichiers_instr) {
  qc <- controler_candidate(lire_csv(f), cfg, basename(f))
  resultats[[f]] <- qc$valides[, c("id_echantillon", "etude", "matrice",
                                   "niveau_cible", "laboratoire",
                                   "date_analyse", "methode", "signal_rfu",
                                   "positif")]
  anomalies[[f]] <- qc$anomalies
  bilan[[f]] <- data.frame(fichier = basename(f), methode = "candidate",
                           lignes_lues = qc$n_lu, lignes_exclues = qc$n_exclu)
}
for (f in fichiers_ref) {
  qc <- controler_reference(lire_csv(f), cfg, basename(f))
  v <- qc$valides
  v$signal_rfu <- NA   # pas de signal pour la culture
  resultats[[f]] <- v[, c("id_echantillon", "etude", "matrice",
                          "niveau_cible", "laboratoire", "date_analyse",
                          "methode", "signal_rfu", "positif")]
  anomalies[[f]] <- qc$anomalies
  bilan[[f]] <- data.frame(fichier = basename(f), methode = "reference",
                           lignes_lues = qc$n_lu, lignes_exclues = qc$n_exclu)
}

donnees <- do.call(rbind, resultats)
rownames(donnees) <- NULL
anos <- do.call(rbind, anomalies)
if (is.null(anos)) {
  anos <- data.frame(fichier = character(), id_echantillon = character(),
                     regle = character(), gravite = character(),
                     detail = character())
}
rownames(anos) <- NULL
bilan <- do.call(rbind, bilan)
rownames(bilan) <- NULL

# ---- 4. Écriture des sorties -----------------------------------------
ecrire_csv(donnees, "data/processed/resultats_portions.csv")
ecrire_csv(anos, "output/qc/registre_anomalies.csv")
ecrire_csv(bilan, "output/qc/bilan_par_fichier.csv")
saveRDS(list(bilan = bilan, anomalies = anos, manifeste = manifeste,
             seuil = cfg$signal$seuil_positivite),
        "output/resultats/qc.rds")

journal_ecrire(chemin_journal, "02_qc",
               sprintf("%d portions valides ; %d anomalie(s) dont %d bloquante(s)",
                       nrow(donnees), nrow(anos),
                       sum(anos$gravite == "bloquant")))

# Figure : distribution du signal avec le seuil de positivité
cand <- donnees[donnees$methode == "candidate", ]
g <- ggplot(cand, aes(x = signal_rfu, fill = factor(positif))) +
  geom_histogram(bins = 50, colour = "white") +
  geom_vline(xintercept = cfg$signal$seuil_positivite, linetype = 2) +
  scale_x_log10() +
  scale_fill_manual(values = c("0" = "grey60", "1" = "#2C7FB8"),
                    labels = c("négatif", "positif"), name = NULL) +
  labs(x = paste0("Signal (", cfg$signal$unite, ", échelle log)"),
       y = "Nombre de portions",
       title = "Signal de la méthode candidate",
       subtitle = paste("Trait pointillé : seuil de positivité =",
                        cfg$signal$seuil_positivite, cfg$signal$unite))
ggsave("output/figures/distribution_signal.png", g, width = 7, height = 4,
       dpi = 150)
