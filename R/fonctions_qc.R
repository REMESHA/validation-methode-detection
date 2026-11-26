# =====================================================================
# fonctions_qc.R
# ---------------------------------------------------------------------
# Contrôles qualité automatiques des fichiers bruts.
# Principe : on ne corrige JAMAIS une donnée en silence. Chaque problème
# est écrit dans un registre d'anomalies avec la règle concernée, la
# gravité et le détail. Les lignes "bloquantes" sont exclues de
# l'analyse ; les "avertissements" sont gardées mais signalées.
# =====================================================================

# Petite fonction pour créer une ligne du registre d'anomalies
anomalie <- function(fichier, id, regle, gravite, detail) {
  if (length(id) == 0) return(NULL)
  data.frame(fichier = fichier, id_echantillon = id, regle = regle,
             gravite = gravite, detail = detail, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------
# verifier_colonnes() : le fichier a-t-il toutes les colonnes prévues ?
# Si non, on arrête tout : on ne peut pas analyser un fichier mal formé.
# ---------------------------------------------------------------------
verifier_colonnes <- function(d, attendues, fichier) {
  manquantes <- setdiff(attendues, names(d))
  if (length(manquantes) > 0) {
    stop("Fichier ", fichier, " : colonne(s) manquante(s) : ",
         paste(manquantes, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------
# controles_communs() : règles valables pour les deux méthodes
# Renvoie la liste des anomalies et un vecteur logique "a_exclure".
# ---------------------------------------------------------------------
controles_communs <- function(d, cfg, fichier) {
  anos <- list()
  exclure <- rep(FALSE, nrow(d))

  # 1. Doublons exacts : on garde la première ligne, on exclut les copies
  dup_exact <- duplicated(d)
  anos[[length(anos) + 1]] <- anomalie(
    fichier, d$id_echantillon[dup_exact], "doublon_exact", "bloquant",
    "ligne identique déjà présente : copie exclue")
  exclure <- exclure | dup_exact

  # 2. Même identifiant mais contenu différent : on ne sait pas quelle
  #    ligne est la bonne, donc on exclut toutes les lignes concernées
  d_sans_copie <- d[!dup_exact, ]
  ids_conflit <- unique(d_sans_copie$id_echantillon[
    duplicated(d_sans_copie$id_echantillon)])
  conflit <- d$id_echantillon %in% ids_conflit
  anos[[length(anos) + 1]] <- anomalie(
    fichier, unique(d$id_echantillon[conflit]), "identifiant_en_conflit",
    "bloquant", "même identifiant avec des contenus différents")
  exclure <- exclure | conflit

  # 3. Niveau d'inoculation : nombre positif ou nul
  niv <- suppressWarnings(as.numeric(d$niveau_cible))
  bad_niv <- is.na(niv) | niv < 0
  anos[[length(anos) + 1]] <- anomalie(
    fichier, d$id_echantillon[bad_niv], "niveau_invalide", "bloquant",
    "niveau_cible manquant, non numérique ou négatif")
  exclure <- exclure | bad_niv

  # 4. Date d'analyse dans la période de l'étude
  dt <- suppressWarnings(as.Date(d$date_analyse))
  debut <- as.Date(cfg$controle_qualite$date_debut_etude)
  fin   <- as.Date(cfg$controle_qualite$date_fin_etude)
  bad_dt <- is.na(dt) | dt < debut | dt > fin
  anos[[length(anos) + 1]] <- anomalie(
    fichier, d$id_echantillon[bad_dt], "date_hors_periode", "bloquant",
    paste0("date '", d$date_analyse[bad_dt], "' hors de la période ",
           debut, " - ", fin, " (à vérifier avec le laboratoire)"))
  exclure <- exclure | bad_dt

  list(anomalies = do.call(rbind, anos), exclure = exclure)
}

# ---------------------------------------------------------------------
# controler_candidate() : contrôles + classement positif/négatif
# ---------------------------------------------------------------------
controler_candidate <- function(d, cfg, fichier) {
  verifier_colonnes(d, unlist(cfg$controle_qualite$colonnes_instrument),
                    fichier)
  cc <- controles_communs(d, cfg, fichier)
  anos <- list(cc$anomalies)
  exclure <- cc$exclure
  s <- cfg$signal

  # 5. Signal manquant
  manq <- is.na(d$signal_rfu)
  anos[[length(anos) + 1]] <- anomalie(
    fichier, d$id_echantillon[manq], "signal_manquant", "bloquant",
    "aucune valeur de signal")
  exclure <- exclure | manq

  # 6. Signal impossible (négatif)
  neg <- !manq & d$signal_rfu < s$minimum_possible
  anos[[length(anos) + 1]] <- anomalie(
    fichier, d$id_echantillon[neg], "signal_impossible", "bloquant",
    paste0("signal = ", d$signal_rfu[neg], " ", s$unite))
  exclure <- exclure | neg

  # 7. Signal saturé : la portion est bien positive, mais la mesure est
  #    au plafond du détecteur. On garde, on signale.
  sat <- !manq & d$signal_rfu >= s$saturation
  anos[[length(anos) + 1]] <- anomalie(
    fichier, d$id_echantillon[sat], "signal_sature", "avertissement",
    "signal au maximum du détecteur : résultat gardé (positif)")

  valides <- d[!exclure, ]
  valides$niveau_cible <- as.numeric(valides$niveau_cible)
  valides$methode <- "candidate"
  valides$positif <- as.integer(valides$signal_rfu >= s$seuil_positivite)

  list(valides = valides, anomalies = do.call(rbind, anos),
       n_lu = nrow(d), n_exclu = sum(exclure))
}

# ---------------------------------------------------------------------
# controler_reference() : contrôles des résultats de la culture
# ---------------------------------------------------------------------
controler_reference <- function(d, cfg, fichier) {
  verifier_colonnes(d, unlist(cfg$controle_qualite$colonnes_reference),
                    fichier)
  cc <- controles_communs(d, cfg, fichier)
  anos <- list(cc$anomalies)
  exclure <- cc$exclure

  autorisees <- unlist(cfg$controle_qualite$valeurs_reference_autorisees)
  bad <- is.na(d$resultat_ref) | !(d$resultat_ref %in% autorisees)
  anos[[length(anos) + 1]] <- anomalie(
    fichier, d$id_echantillon[bad], "resultat_non_autorise", "bloquant",
    paste0("valeur '", d$resultat_ref[bad], "' (attendu : ",
           paste(autorisees, collapse = " ou "), ")"))
  exclure <- exclure | bad

  valides <- d[!exclure, ]
  valides$niveau_cible <- as.numeric(valides$niveau_cible)
  valides$methode <- "reference"
  valides$positif <- as.integer(valides$resultat_ref == "positif")

  list(valides = valides, anomalies = do.call(rbind, anos),
       n_lu = nrow(d), n_exclu = sum(exclure))
}
