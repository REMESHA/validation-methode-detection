# =====================================================================
# fonctions_lpod.R
# ---------------------------------------------------------------------
# Étude collaborative (interlaboratoires) : LPOD et dLPOD.
#
# Procédure de l'AOAC (annexe "Calculation of LPOD and dLPOD values from
# qualitative method collaborative study") :
#   Étape 1 : analyser les 0/1 comme des données quantitatives
#             (analyse de variance à un facteur "laboratoire") :
#             s_r = écart-type de répétabilité (intra-laboratoire)
#             s_R = écart-type de reproductibilité (total)
#   Étape 2 : s_L = racine(s_R^2 - s_r^2) (part "laboratoire")
#   Étape 3 : s(POD) = écart-type des POD des L laboratoires
#   Étape 4 : degrés de liberté de s(POD) par une approximation de
#             Satterthwaite (voir ddl_satterthwaite())
#   Étape 5 : IC à 95 % de la LPOD :
#             - si 0,15 <= LPOD <= 0,85 : LPOD -/+ t(0,975 ; ddl) * s(POD)/racine(L)
#               (bornes ramenées dans [0 ; 1])
#             - sinon : intervalle de Wilson sur x positifs parmi N portions
#   Étape 6 : dLPOD = LPOD1 - LPOD2, IC par la même combinaison que la dPOD
#
# ATTENTION (honnêteté) : la formule exacte des degrés de liberté de
# l'étape 4 était illisible dans les copies du texte que j'ai pu
# consulter. La formule ci-dessous est la forme de Satterthwaite
# cohérente avec les éléments lisibles (s_L, s_r, L, N). Elle est à
# vérifier dans le PDF original de l'AOAC avant tout usage réel.
# =====================================================================

# ---------------------------------------------------------------------
# composantes_variance() : étapes 1 et 2 (ANOVA à un facteur sur 0/1)
#   positif     : vecteur de 0/1
#   laboratoire : vecteur des laboratoires (même longueur)
# ---------------------------------------------------------------------
composantes_variance <- function(positif, laboratoire) {
  laboratoire <- as.character(laboratoire)
  L <- length(unique(laboratoire))
  N <- length(positif)
  R <- N / L                                  # réplicats par labo (moyen)
  moy_labo <- tapply(positif, laboratoire, mean)
  moy <- mean(positif)

  sce_intra <- sum((positif - moy_labo[laboratoire])^2)
  sce_inter <- sum(table(laboratoire)[names(moy_labo)] * (moy_labo - moy)^2)
  cm_intra <- sce_intra / (N - L)             # carré moyen intra (= s_r^2)
  cm_inter <- sce_inter / (L - 1)             # carré moyen inter

  s_r2 <- cm_intra
  s_L2 <- max(0, (cm_inter - cm_intra) / R)   # tronqué à 0 si négatif
  list(L = L, N = N, R = R, s_r = sqrt(s_r2), s_L = sqrt(s_L2),
       s_R = sqrt(s_r2 + s_L2))
}

# ---------------------------------------------------------------------
# ddl_satterthwaite() : étape 4
#   ddl = (s_L^2/L + s_r^2/N)^2 /
#         [ (s_L^2/L)^2 / (L - 1) + (s_r^2/N)^2 / (N - L) ]
# Idée : la variance de la LPOD vaut environ s_L^2/L + s_r^2/N, somme de
# deux variances estimées avec L - 1 et N - L degrés de liberté.
# Si les deux variances sont nulles (tous positifs ou tous négatifs),
# on prend L - 1 (l'intervalle de Wilson sera de toute façon utilisé).
# ---------------------------------------------------------------------
ddl_satterthwaite <- function(s_L, s_r, L, N) {
  a <- s_L^2 / L
  b <- s_r^2 / N
  if (a + b == 0) return(L - 1)
  (a + b)^2 / (a^2 / (L - 1) + b^2 / (N - L))
}

# ---------------------------------------------------------------------
# lpod_ic() : étapes 1 à 5 pour une méthode et un niveau
#   d : data.frame avec les colonnes positif (0/1) et laboratoire
# ---------------------------------------------------------------------
lpod_ic <- function(d, niveau_confiance = 0.95) {
  cv <- composantes_variance(d$positif, d$laboratoire)
  pod_labos <- tapply(d$positif, d$laboratoire, mean)
  x <- sum(d$positif)
  lpod <- x / cv$N
  s_pod <- sd(pod_labos)
  ddl <- ddl_satterthwaite(cv$s_L, cv$s_r, cv$L, cv$N)

  if (lpod >= 0.15 && lpod <= 0.85) {
    t <- qt(1 - (1 - niveau_confiance) / 2, df = ddl)
    bas  <- max(0, lpod - t * s_pod / sqrt(cv$L))
    haut <- min(1, lpod + t * s_pod / sqrt(cv$L))
    methode_ic <- "Student (Satterthwaite)"
  } else {
    w <- pod_ic(x, cv$N, niveau_confiance)
    bas <- w$ic_bas; haut <- w$ic_haut
    methode_ic <- "Wilson"
  }
  data.frame(x = x, N = cv$N, L = cv$L, lpod = lpod, ic_bas = bas,
             ic_haut = haut, s_r = cv$s_r, s_L = cv$s_L, s_R = cv$s_R,
             s_pod = s_pod, ddl = ddl, methode_ic = methode_ic)
}

# ---------------------------------------------------------------------
# dlpod_ic() : étape 6, à partir de deux résultats de lpod_ic()
# ---------------------------------------------------------------------
dlpod_ic <- function(l1, l2) {
  d <- l1$lpod - l2$lpod
  bas  <- d - sqrt((l1$lpod - l1$ic_bas)^2 + (l2$ic_haut - l2$lpod)^2)
  haut <- d + sqrt((l1$ic_haut - l1$lpod)^2 + (l2$lpod - l2$ic_bas)^2)
  data.frame(dlpod = d, ic_bas = bas, ic_haut = haut,
             significatif = bas > 0 | haut < 0)
}
