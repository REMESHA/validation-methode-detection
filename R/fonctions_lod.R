# =====================================================================
# fonctions_lod.R
# ---------------------------------------------------------------------
# Niveau de détection à 50 % (LOD50) et niveau de détection relatif
# (RLOD) à partir de résultats positifs/négatifs.
#
# Idée (modèle de Poisson "à un coup", classique en microbiologie) :
#   - le nombre de cellules dans une portion suit une loi de Poisson de
#     moyenne lambda (le niveau d'inoculation, en UFC par portion) ;
#   - chaque cellule est détectée avec une probabilité r ;
#   - alors POD(lambda) = 1 - exp(-r * lambda).
# En passant au lien "log-log complémentaire" (cloglog) :
#   log(-log(1 - POD)) = log(r) + log(lambda)
# C'est un modèle linéaire généralisé (GLM) binomial, lien cloglog,
# avec log(lambda) en "offset" (pente fixée à 1).
#
# LOD50 = niveau tel que POD = 0,5  =>  LOD50 = log(2) / r
# RLOD  = LOD50 candidate / LOD50 référence = r_reference / r_candidate
#   RLOD < 1 : la candidate détecte à des niveaux plus bas.
# =====================================================================

# ---------------------------------------------------------------------
# ajuster_lod50() : estime r et la LOD50 pour UNE méthode
#   donnees : colonnes niveau_cible (> 0) et positif (0/1)
# ---------------------------------------------------------------------
ajuster_lod50 <- function(donnees, niveau_confiance = 0.95) {
  donnees <- donnees[donnees$niveau_cible > 0, ]   # log(0) impossible
  modele <- glm(positif ~ 1, offset = log(niveau_cible),
                family = binomial(link = "cloglog"), data = donnees)

  log_r    <- unname(coef(modele)[1])
  ic_log_r <- suppressMessages(confint(modele, level = niveau_confiance))

  # LOD50 = log(2)/r : quand r augmente, LOD50 diminue, d'où l'inversion
  # des bornes.
  list(
    modele = modele,
    r = exp(log_r),
    lod50 = log(2) / exp(log_r),
    lod50_bas  = log(2) / exp(ic_log_r[2]),
    lod50_haut = log(2) / exp(ic_log_r[1])
  )
}

# ---------------------------------------------------------------------
# tester_pente_un() : le modèle "à un coup" (pente = 1) est-il
# acceptable ? On le compare à un modèle à pente libre :
#   cloglog(POD) = a + b * log(lambda)
# par un test du rapport de vraisemblance. Une p-valeur élevée signifie
# que les données ne contredisent pas l'hypothèse b = 1.
# ---------------------------------------------------------------------
tester_pente_un <- function(donnees) {
  donnees <- donnees[donnees$niveau_cible > 0, ]
  m1 <- glm(positif ~ 1, offset = log(niveau_cible),
            family = binomial(link = "cloglog"), data = donnees)
  m2 <- glm(positif ~ log(niveau_cible),
            family = binomial(link = "cloglog"), data = donnees)
  test <- anova(m1, m2, test = "LRT")
  list(pente_libre = unname(coef(m2)[2]),
       p_valeur = test$`Pr(>Chi)`[2])
}

# ---------------------------------------------------------------------
# ajuster_rlod() : compare les deux méthodes dans un seul modèle
#   cloglog(POD) = log(r_ref) + delta * [méthode = candidate] + log(lambda)
#   RLOD = exp(-delta)
#   donnees : colonnes niveau_cible, positif, methode
# ---------------------------------------------------------------------
ajuster_rlod <- function(donnees, niveau_confiance = 0.95) {
  donnees <- donnees[donnees$niveau_cible > 0, ]
  donnees$methode <- factor(donnees$methode,
                            levels = c("reference", "candidate"))
  modele <- glm(positif ~ methode, offset = log(niveau_cible),
                family = binomial(link = "cloglog"), data = donnees)
  delta    <- unname(coef(modele)["methodecandidate"])
  ic_delta <- suppressMessages(
    confint(modele, parm = "methodecandidate", level = niveau_confiance))
  list(
    modele = modele,
    rlod = exp(-delta),
    rlod_bas  = exp(-ic_delta[2]),
    rlod_haut = exp(-ic_delta[1]),
    p_valeur = summary(modele)$coefficients["methodecandidate", 4]
  )
}

# ---------------------------------------------------------------------
# courbe_pod() : POD prédite (et IC à 95 %) sur une grille de niveaux,
# pour tracer la courbe dose-réponse.
# ---------------------------------------------------------------------
courbe_pod <- function(modele, niveaux) {
  nd <- data.frame(niveau_cible = niveaux)
  # predict() ajoute l'offset log(niveau_cible) automatiquement
  # car il est déclaré dans l'appel glm(offset = ...).
  p  <- predict(modele, newdata = nd, type = "link", se.fit = TRUE)
  inv <- modele$family$linkinv
  data.frame(niveau_cible = niveaux,
             pod = inv(p$fit),
             ic_bas = inv(p$fit - 1.96 * p$se.fit),
             ic_haut = inv(p$fit + 1.96 * p$se.fit))
}
