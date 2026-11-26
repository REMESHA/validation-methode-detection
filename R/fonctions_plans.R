# =====================================================================
# fonctions_plans.R
# ---------------------------------------------------------------------
# Banc d'essai SIMULÉ pour les plans d'expériences.
# Réponse étudiée : rapport signal / bruit (S/B) de la chambre optique,
# en unités arbitraires. Plus il est grand, mieux la méthode sépare les
# portions contaminées du bruit de fond.
#
# La "vraie" loi de réponse ci-dessous est cachée à l'analyste : dans la
# réalité, on ne la connaît pas. On s'en sert seulement pour produire
# des mesures, puis pour vérifier que le plan d'expériences la retrouve.
# =====================================================================

# Passage unités réelles -> unités codées (-1 = niveau bas, +1 = haut)
coder <- function(valeur, bas, haut) {
  (valeur - (bas + haut) / 2) / ((haut - bas) / 2)
}

# Passage unités codées -> unités réelles
decoder <- function(code, bas, haut) {
  (bas + haut) / 2 + code * (haut - bas) / 2
}

# ---------------------------------------------------------------------
# reponse_vraie() : loi de réponse cachée, en unités codées
#   A = température, B = durée d'enrichissement, C = concentration du
#   substrat, D = volume d'échantillon, E = gain du détecteur
# Effets forts : A, B, leur interaction et une courbure (termes au
# carré). Effet moyen : C. Effets presque nuls : D et E.
# ---------------------------------------------------------------------
reponse_vraie <- function(A, B, C, D, E) {
  10 + 1.2 * A + 1.5 * B + 0.8 * C + 0.1 * D + 0.2 * E +
    0.6 * A * B - 1.4 * A^2 - 1.1 * B^2
}

# ---------------------------------------------------------------------
# mesurer_sb() : une "mesure" au banc = vraie réponse + bruit
#   essais : data.frame en unités RÉELLES avec les 5 facteurs
# ---------------------------------------------------------------------
mesurer_sb <- function(essais, cfg) {
  f <- cfg$plan_experiences$facteurs
  A <- coder(essais$temperature, f$temperature$bas, f$temperature$haut)
  B <- coder(essais$duree_enrichissement, f$duree_enrichissement$bas,
             f$duree_enrichissement$haut)
  C <- coder(essais$concentration_substrat, f$concentration_substrat$bas,
             f$concentration_substrat$haut)
  D <- coder(essais$volume_echantillon, f$volume_echantillon$bas,
             f$volume_echantillon$haut)
  E <- coder(essais$gain_detecteur, f$gain_detecteur$bas,
             f$gain_detecteur$haut)
  vrai <- reponse_vraie(A, B, C, D, E)
  round(vrai + rnorm(length(vrai), 0, cfg$plan_experiences$ecart_type_bruit), 2)
}

# ---------------------------------------------------------------------
# optimum_vrai() : maximum de la vraie loi en A et B (C, D, E fixés).
# Sert uniquement à vérifier le résultat du plan composite.
# ---------------------------------------------------------------------
optimum_vrai <- function(C = 1, D = 0, E = 0) {
  f <- function(p) -reponse_vraie(p[1], p[2], C, D, E)
  opt <- optim(c(0, 0), f)
  c(A = opt$par[1], B = opt$par[2], sb = -opt$value)
}

# ---------------------------------------------------------------------
# choisir_alpha_ccd() : position des points axiaux du plan composite
#   centres, demi : centre et demi-étendue de chaque facteur (réels)
#   limites       : liste list(facteur = list(min =, max =))
# Essaie d'abord le plan "rotatable" : alpha = (2^k)^(1/4) quand le
# carré est un plan factoriel complet à k facteurs (k = 2 : 1,414). Si un point axial sort des limites physiques,
# passe aux points sur les faces (alpha = 1). Si même alpha = 1 sort
# des limites, arrête tout : le domaine du criblage est déjà infaisable.
# Renvoie une liste : alpha ("rotatable" ou "faces"), valeur, tableau.
# ---------------------------------------------------------------------
choisir_alpha_ccd <- function(centres, demi, limites) {
  k <- length(centres)
  essayer <- function(a) {
    data.frame(facteur = names(centres),
               axial_bas = centres - a * demi,
               axial_haut = centres + a * demi,
               limite_min = sapply(limites[names(centres)], `[[`, "min"),
               limite_max = sapply(limites[names(centres)], `[[`, "max"),
               row.names = NULL)
  }
  dans <- function(t) all(t$axial_bas >= t$limite_min &
                          t$axial_haut <= t$limite_max)
  a_rot <- (2^k)^(1 / 4)
  t_rot <- essayer(a_rot)
  if (dans(t_rot)) {
    return(list(alpha = "rotatable", valeur = a_rot, tableau = t_rot))
  }
  t_face <- essayer(1)
  if (dans(t_face)) {
    return(list(alpha = "faces", valeur = 1, tableau = t_face))
  }
  stop("Le domaine étudié sort des limites physiques même avec des ",
       "points axiaux sur les faces : revoir les niveaux du criblage.",
       call. = FALSE)
}
