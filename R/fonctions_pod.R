# =====================================================================
# fonctions_pod.R
# ---------------------------------------------------------------------
# Probabilité de détection (POD) et différence de POD (dPOD).
#
# Formules reprises des lignes directrices AOAC (Appendix J, annexe de
# calcul "POD and dPOD") :
#   - IC à 95 % d'une POD : intervalle de Wilson (score) ;
#   - IC à 95 % d'une dPOD, étude NON appariée : combinaison des
#     distances entre chaque POD et ses bornes (méthode de Newcombe) ;
#   - IC à 95 % d'une dPOD, étude APPARIÉE : moyenne des différences
#     (-1, 0, +1) et loi de Student.
# Règle de décision : si l'IC de dPOD contient 0, la différence entre
# les deux méthodes n'est pas significative au seuil de 5 %.
# =====================================================================

# ---------------------------------------------------------------------
# pod_ic() : POD et son intervalle de confiance de Wilson
#   x : nombre de résultats positifs
#   n : nombre de portions testées
# Renvoie un data.frame : x, n, pod, ic_bas, ic_haut
# ---------------------------------------------------------------------
pod_ic <- function(x, n, niveau_confiance = 0.95) {
  stopifnot(length(x) == length(n), all(n > 0), all(x >= 0), all(x <= n))

  z  <- qnorm(1 - (1 - niveau_confiance) / 2)   # 1,96 pour 95 %
  z2 <- z^2                                     # 3,8415

  pod     <- x / n
  centre  <- x + z2 / 2                         # x + 1,9207
  marge   <- z * sqrt(x * (n - x) / n + z2 / 4) # 1,96 * sqrt(... + 0,9604)
  ic_bas  <- (centre - marge) / (n + z2)
  ic_haut <- (centre + marge) / (n + z2)

  # Cas particuliers prévus par l'AOAC (la formule générale donne déjà
  # ces valeurs ; on les impose pour éviter les erreurs d'arrondi).
  ic_bas[x == 0]  <- 0
  ic_haut[x == n] <- 1

  data.frame(x = x, n = n, pod = pod, ic_bas = ic_bas, ic_haut = ic_haut)
}

# ---------------------------------------------------------------------
# dpod_non_apparie() : dPOD = POD1 - POD2 et son IC à 95 %
#   (x1, n1) : méthode 1 (en général la méthode candidate)
#   (x2, n2) : méthode 2 (en général la méthode de référence)
# ---------------------------------------------------------------------
dpod_non_apparie <- function(x1, n1, x2, n2, niveau_confiance = 0.95) {
  p1 <- pod_ic(x1, n1, niveau_confiance)
  p2 <- pod_ic(x2, n2, niveau_confiance)

  d <- p1$pod - p2$pod
  ic_bas  <- d - sqrt((p1$pod - p1$ic_bas)^2  + (p2$ic_haut - p2$pod)^2)
  ic_haut <- d + sqrt((p1$ic_haut - p1$pod)^2 + (p2$pod - p2$ic_bas)^2)

  data.frame(pod_1 = p1$pod, pod_2 = p2$pod, dpod = d,
             ic_bas = ic_bas, ic_haut = ic_haut,
             significatif = ic_bas > 0 | ic_haut < 0)
}

# ---------------------------------------------------------------------
# dpod_apparie() : version pour une étude appariée
#   r1, r2 : vecteurs de 0/1 (même portion analysée par les 2 méthodes)
# ---------------------------------------------------------------------
dpod_apparie <- function(r1, r2, niveau_confiance = 0.95) {
  stopifnot(length(r1) == length(r2), all(c(r1, r2) %in% c(0, 1)))
  d_i <- r1 - r2                       # vaut -1, 0 ou +1
  n   <- length(d_i)
  d   <- mean(d_i)
  se  <- sd(d_i) / sqrt(n)
  t_c <- qt(1 - (1 - niveau_confiance) / 2, df = n - 1)
  data.frame(dpod = d, ic_bas = d - t_c * se, ic_haut = d + t_c * se,
             significatif = (d - t_c * se) > 0 | (d + t_c * se) < 0)
}

# ---------------------------------------------------------------------
# tableau_pod() : calcule POD par méthode puis dPOD, pour chaque
# combinaison matrice x niveau.
#   donnees : une ligne par portion, colonnes matrice, niveau_cible,
#             methode ("candidate"/"reference"), positif (0/1)
# ---------------------------------------------------------------------
tableau_pod <- function(donnees) {
  groupes <- unique(donnees[, c("matrice", "niveau_cible")])
  groupes <- groupes[order(groupes$matrice, groupes$niveau_cible), ]

  lignes <- lapply(seq_len(nrow(groupes)), function(i) {
    g  <- groupes[i, ]
    dc <- donnees[donnees$matrice == g$matrice &
                  donnees$niveau_cible == g$niveau_cible &
                  donnees$methode == "candidate", ]
    dr <- donnees[donnees$matrice == g$matrice &
                  donnees$niveau_cible == g$niveau_cible &
                  donnees$methode == "reference", ]
    pc <- pod_ic(sum(dc$positif), nrow(dc))
    pr <- pod_ic(sum(dr$positif), nrow(dr))
    dd <- dpod_non_apparie(sum(dc$positif), nrow(dc),
                           sum(dr$positif), nrow(dr))
    data.frame(
      matrice = g$matrice, niveau_cible = g$niveau_cible,
      n_candidate = pc$n, x_candidate = pc$x,
      pod_candidate = pc$pod, pod_c_bas = pc$ic_bas, pod_c_haut = pc$ic_haut,
      n_reference = pr$n, x_reference = pr$x,
      pod_reference = pr$pod, pod_r_bas = pr$ic_bas, pod_r_haut = pr$ic_haut,
      dpod = dd$dpod, dpod_bas = dd$ic_bas, dpod_haut = dd$ic_haut,
      difference_significative = dd$significatif
    )
  })
  do.call(rbind, lignes)
}
