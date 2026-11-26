# =====================================================================
# 05_etude_interlaboratoires.R
# ---------------------------------------------------------------------
# Étude collaborative simulée : 12 laboratoires, 12 portions par niveau.
#   1. POD de chaque laboratoire
#   2. LPOD = POD de tous les laboratoires réunis, et dLPOD
#   3. Variabilité entre laboratoires : modèle linéaire généralisé MIXTE
#      (package lme4), avec un effet aléatoire "laboratoire"
#   4. Faux positifs sur les portions non inoculées
#
# LPOD / dLPOD : procédure AOAC en 6 étapes (R/fonctions_lpod.R), avec
# une réserve sur la formule des degrés de liberté (voir ce fichier).
# =====================================================================

source("scripts/00_initialisation.R")
suppressPackageStartupMessages(library(lme4))

donnees <- lire_csv("data/processed/resultats_portions.csv")
di <- donnees[donnees$etude == "interlabo", ]
L  <- length(unique(di$laboratoire))

# ---- 1. POD par laboratoire ----------------------------------------
par_labo <- aggregate(positif ~ laboratoire + methode + niveau_cible,
                      data = di, FUN = function(x) c(x = sum(x), n = length(x)))
par_labo <- data.frame(laboratoire = par_labo$laboratoire,
                       methode = par_labo$methode,
                       niveau_cible = par_labo$niveau_cible,
                       x = par_labo$positif[, "x"], n = par_labo$positif[, "n"])
par_labo$pod <- par_labo$x / par_labo$n
ecrire_csv(par_labo, "output/tables/pod_par_laboratoire.csv")

# ---- 2. LPOD et dLPOD (procédure AOAC, voir R/fonctions_lpod.R) ------
lignes <- list()
for (niv in sort(unique(di$niveau_cible))) {
  dc <- di[di$niveau_cible == niv & di$methode == "candidate", ]
  dr <- di[di$niveau_cible == niv & di$methode == "reference", ]
  lc <- lpod_ic(dc)
  lr <- lpod_ic(dr)
  dd <- dlpod_ic(lc, lr)
  lignes[[length(lignes) + 1]] <- data.frame(
    niveau_cible = niv,
    lpod_candidate = lc$lpod, lpod_c_bas = lc$ic_bas, lpod_c_haut = lc$ic_haut,
    s_r_candidate = lc$s_r, s_L_candidate = lc$s_L, s_R_candidate = lc$s_R,
    ddl_candidate = lc$ddl, methode_ic_candidate = lc$methode_ic,
    lpod_reference = lr$lpod, lpod_r_bas = lr$ic_bas, lpod_r_haut = lr$ic_haut,
    s_r_reference = lr$s_r, s_L_reference = lr$s_L, s_R_reference = lr$s_R,
    ddl_reference = lr$ddl, methode_ic_reference = lr$methode_ic,
    dlpod = dd$dlpod, dlpod_bas = dd$ic_bas, dlpod_haut = dd$ic_haut,
    difference_significative = dd$significatif)
}
tab_lpod <- do.call(rbind, lignes)
ecrire_csv(tab_lpod, "output/tables/lpod_dlpod.csv")

# ---- 3. Modèle mixte : variabilité entre laboratoires ----------------
# cloglog(POD) = log(r_methode) + u_labo + log(lambda)
# u_labo ~ Normale(0, sigma_labo^2)
# Deux écritures du MÊME modèle :
#   (a) sans constante : un coefficient log(r) par méthode -> LOD50
#   (b) avec la référence comme base : delta = log(r_cand / r_ref) -> RLOD
# Les intervalles de confiance sont obtenus par profil de vraisemblance.
#
# INTERPRÉTATION : ces LOD50 sont celles d'un laboratoire "médian"
# (u_labo = 0), pas la moyenne des POD de tous les laboratoires.
inoc <- di[di$niveau_cible > 0, ]
inoc$methode <- factor(inoc$methode, levels = c("reference", "candidate"))

modele_a <- glmer(positif ~ 0 + methode + offset(log(niveau_cible)) +
                    (1 | laboratoire),
                  family = binomial(link = "cloglog"), data = inoc)
modele_b <- glmer(positif ~ methode + offset(log(niveau_cible)) +
                    (1 | laboratoire),
                  family = binomial(link = "cloglog"), data = inoc)

ic_a <- suppressMessages(confint(modele_a, method = "profile"))
ic_b <- suppressMessages(confint(modele_b, parm = "methodecandidate",
                                 method = "profile"))
fe_a <- fixef(modele_a)
fe_b <- fixef(modele_b)
sigma_labo <- as.data.frame(VarCorr(modele_a))$sdcor[1]

v <- cfg$verite_simulation
# LOD50 = log(2)/r : les bornes s'inversent (r grand -> LOD50 petite)
mixte <- data.frame(
  parametre = c("LOD50 référence (laboratoire médian, UFC)",
                "LOD50 candidate (laboratoire médian, UFC)",
                "RLOD (candidate / référence)",
                "Écart-type entre laboratoires (échelle log)"),
  estimation = c(log(2) / exp(fe_a["methodereference"]),
                 log(2) / exp(fe_a["methodecandidate"]),
                 exp(-fe_b["methodecandidate"]),
                 sigma_labo),
  ic_bas = c(log(2) / exp(ic_a["methodereference", 2]),
             log(2) / exp(ic_a["methodecandidate", 2]),
             exp(-ic_b["methodecandidate", 2]),
             ic_a[".sig01", 1]),
  ic_haut = c(log(2) / exp(ic_a["methodereference", 1]),
              log(2) / exp(ic_a["methodecandidate", 1]),
              exp(-ic_b["methodecandidate", 1]),
              ic_a[".sig01", 2]),
  valeur_vraie_simulation = c(
    log(2) / v$efficacite_cellule$reference,
    log(2) / v$efficacite_cellule$candidate,
    v$efficacite_cellule$reference / v$efficacite_cellule$candidate,
    v$sd_laboratoire_log),
  row.names = NULL)
mixte$vraie_valeur_dans_ic <- mixte$valeur_vraie_simulation >= mixte$ic_bas &
  mixte$valeur_vraie_simulation <= mixte$ic_haut
ecrire_csv(mixte, "output/tables/modele_mixte_interlabo.csv")

# ---- 4. Faux positifs (portions non inoculées) -----------------------
zero <- di[di$niveau_cible == 0, ]
fp <- do.call(rbind, lapply(c("candidate", "reference"), function(m) {
  z <- zero[zero$methode == m, ]
  w <- pod_ic(sum(z$positif), nrow(z))
  data.frame(methode = m, faux_positifs = w$x, n = w$n,
             taux = w$pod, ic_bas = w$ic_bas, ic_haut = w$ic_haut)
}))
ecrire_csv(fp, "output/tables/faux_positifs_interlabo.csv")

saveRDS(list(par_labo = par_labo, lpod = tab_lpod, mixte = mixte,
             faux_positifs = fp, n_labos = L,
             resume_modele = capture.output(summary(modele_a))),
        "output/resultats/interlabo.rds")

# ---- Figure : POD par laboratoire au niveau bas ----------------------
bas <- par_labo[par_labo$niveau_cible == cfg$etude_interlabo$niveaux_ufc$bas, ]
bas <- cbind(bas, pod_ic(bas$x, bas$n)[, c("ic_bas", "ic_haut")])
g <- ggplot(bas, aes(x = laboratoire, y = pod, colour = methode)) +
  geom_pointrange(aes(ymin = ic_bas, ymax = ic_haut),
                  position = position_dodge(width = 0.5)) +
  geom_hline(data = data.frame(
    methode = c("candidate", "reference"),
    y = c(tab_lpod$lpod_candidate[tab_lpod$niveau_cible ==
                                    cfg$etude_interlabo$niveaux_ufc$bas],
          tab_lpod$lpod_reference[tab_lpod$niveau_cible ==
                                    cfg$etude_interlabo$niveaux_ufc$bas])),
    aes(yintercept = y, colour = methode), linetype = 2) +
  scale_colour_manual(values = c(candidate = "#2C7FB8", reference = "#D95F0E")) +
  labs(x = NULL, y = "POD (IC de Wilson à 95 %)", colour = NULL,
       title = paste("POD par laboratoire au niveau bas (",
                     cfg$etude_interlabo$niveaux_ufc$bas, "UFC par portion)"),
       subtitle = "Traits pointillés : LPOD (tous laboratoires réunis)") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")
ggsave("output/figures/pod_par_laboratoire.png", g, width = 8, height = 4.5,
       dpi = 150)

journal_ecrire(chemin_journal, "05_interlabo",
               sprintf("%d labos ; écart-type labo estimé = %.2f", L, sigma_labo))
