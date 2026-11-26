# =====================================================================
# fonctions_simulation.R
# ---------------------------------------------------------------------
# Fabrique des données FICTIVES qui ressemblent à de vrais exports :
#   - méthode candidate : un signal de fluorescence (RFU) par portion ;
#   - méthode de référence (culture) : un résultat positif/négatif.
# Toutes les "vraies" valeurs viennent de config/config.yml.
# =====================================================================

# ---------------------------------------------------------------------
# simuler_detection() : la cible est-elle détectée dans chaque portion ?
#   lambda : niveau d'inoculation moyen (UFC par portion), un par portion
#   r      : probabilité de détecter chaque cellule (un par portion)
# Étapes :
#   1. nombre réel de cellules dans la portion : loi de Poisson(lambda)
#   2. nombre de cellules détectées : loi binomiale(cellules, r)
#   3. détection si au moins une cellule est détectée
# Mathématiquement, P(détection) = 1 - exp(-r * lambda).
# ---------------------------------------------------------------------
simuler_detection <- function(lambda, r) {
  cellules  <- rpois(length(lambda), lambda)
  detectees <- rbinom(length(lambda), size = cellules, prob = pmin(r, 1))
  detectees > 0
}

# ---------------------------------------------------------------------
# simuler_signal() : signal de la méthode candidate (en RFU)
#   detecte : vecteur logique (la cible est-elle détectée ?)
# Le signal suit une loi log-normale : forte si détectée, faible sinon
# (bruit de fond). Il est plafonné à la saturation du détecteur.
# ---------------------------------------------------------------------
simuler_signal <- function(detecte, cfg) {
  v  <- cfg$verite_simulation
  mu <- ifelse(detecte, v$log10_signal_detecte$moyenne,
                        v$log10_signal_fond$moyenne)
  sd <- ifelse(detecte, v$log10_signal_detecte$ecart_type,
                        v$log10_signal_fond$ecart_type)
  signal <- 10^rnorm(length(detecte), mu, sd)
  round(pmin(signal, cfg$signal$saturation), 1)
}

# ---------------------------------------------------------------------
# plan_portions() : construit la liste des portions à analyser
# (une ligne par portion) pour une étude, une méthode, un labo.
# ---------------------------------------------------------------------
plan_portions <- function(etude, matrice, niveaux, replicats, methode,
                          laboratoire = "LAB01") {
  lignes <- mapply(function(niv, rep) rep(niv, rep),
                   unlist(niveaux), unlist(replicats), SIMPLIFY = FALSE)
  niveau_cible <- unlist(lignes)
  data.frame(etude = etude, matrice = matrice, niveau_cible = niveau_cible,
             laboratoire = laboratoire, methode = methode,
             stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------
# ajouter_metadonnees() : identifiants, opérateur, instrument, dates
# ---------------------------------------------------------------------
ajouter_metadonnees <- function(d, cfg, prefixe) {
  d$id_echantillon <- sprintf("%s-%04d", prefixe, seq_len(nrow(d)))
  d$operateur  <- sample(c("OP1", "OP2", "OP3"), nrow(d), replace = TRUE)
  d$instrument <- ifelse(d$methode == "candidate", "CHAMBRE-OPT-01", NA)
  debut <- as.Date(cfg$controle_qualite$date_debut_etude)
  fin   <- as.Date(cfg$controle_qualite$date_fin_etude)
  d$date_analyse <- format(sample(seq(debut, fin, by = "day"), nrow(d),
                                  replace = TRUE))
  d
}

# ---------------------------------------------------------------------
# simuler_etude() : simule une étude complète (les 2 méthodes)
# Renvoie une liste : $candidate (avec signal) et $reference (résultat)
# effet_labo : décalage log de l'efficacité pour chaque laboratoire
# ---------------------------------------------------------------------
simuler_etude <- function(plan, cfg, prefixe, effet_labo = NULL) {
  v <- cfg$verite_simulation
  r_base <- unlist(v$efficacite_cellule)[plan$methode]
  r_mat  <- unlist(v$effet_matrice)[plan$matrice]
  r <- r_base * r_mat
  if (!is.null(effet_labo)) r <- r * exp(effet_labo[plan$laboratoire])
  r <- unname(r)

  detecte <- simuler_detection(plan$niveau_cible, r)
  plan <- ajouter_metadonnees(plan, cfg, prefixe)

  cand <- plan[plan$methode == "candidate", ]
  cand$signal_rfu <- simuler_signal(detecte[plan$methode == "candidate"], cfg)

  ref <- plan[plan$methode == "reference", ]
  fp  <- runif(nrow(ref)) < v$taux_faux_positif_reference
  ref$resultat_ref <- ifelse(detecte[plan$methode == "reference"] | fp,
                             "positif", "negatif")

  list(
    candidate = cand[, c("id_echantillon", "etude", "matrice", "niveau_cible",
                         "laboratoire", "operateur", "instrument",
                         "date_analyse", "signal_rfu")],
    reference = ref[, c("id_echantillon", "etude", "matrice", "niveau_cible",
                        "laboratoire", "date_analyse", "resultat_ref")]
  )
}

# ---------------------------------------------------------------------
# injecter_anomalies() : ajoute volontairement des erreurs typiques,
# pour montrer que les contrôles qualité les repèrent.
# ---------------------------------------------------------------------
injecter_anomalies <- function(cand, ref) {
  cand$signal_rfu[3] <- NA                 # valeur manquante
  cand <- rbind(cand, cand[7, ])           # ligne en double
  cand$signal_rfu[11] <- -15               # signal impossible
  cand$signal_rfu[15] <- 65535             # signal saturé (avertissement)
  cand$date_analyse[19] <- "2025-12-01"    # date hors période d'étude
  ref$resultat_ref[4] <- "pos"             # faute de saisie
  list(candidate = cand, reference = ref)
}
