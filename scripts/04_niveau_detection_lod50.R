# =====================================================================
# 04_niveau_detection_lod50.R
# ---------------------------------------------------------------------
# Étude du niveau de détection : 5 niveaux x 20 réplicats par méthode.
#   1. Courbe POD en fonction du niveau (modèle de Poisson / cloglog)
#   2. LOD50 de chaque méthode avec IC à 95 %
#   3. Vérification de l'hypothèse "à un coup" (pente = 1)
#   4. RLOD = LOD50 candidate / LOD50 référence
#   5. Comparaison avec la vérité de la simulation
# =====================================================================

source("scripts/00_initialisation.R")

donnees <- lire_csv("data/processed/resultats_portions.csv")
dl <- donnees[donnees$etude == "lod", ]

# ---- 1 et 2. LOD50 par méthode -------------------------------------
res <- lapply(c(candidate = "candidate", reference = "reference"),
              function(m) ajuster_lod50(dl[dl$methode == m, ]))
pentes <- lapply(c(candidate = "candidate", reference = "reference"),
                 function(m) tester_pente_un(dl[dl$methode == m, ]))

# ---- 4. RLOD -------------------------------------------------------
rlod <- ajuster_rlod(dl)

# ---- 5. Vérité de la simulation ------------------------------------
v <- cfg$verite_simulation
r_vrai <- unlist(v$efficacite_cellule) *
  v$effet_matrice[[cfg$etude_lod$matrice]]
lod_vrai <- log(2) / r_vrai

tab <- data.frame(
  methode = names(res),
  lod50_estimee = sapply(res, `[[`, "lod50"),
  ic_bas = sapply(res, `[[`, "lod50_bas"),
  ic_haut = sapply(res, `[[`, "lod50_haut"),
  lod50_vraie_simulation = unname(lod_vrai[names(res)]),
  pente_libre = sapply(pentes, `[[`, "pente_libre"),
  p_test_pente_1 = sapply(pentes, `[[`, "p_valeur"),
  row.names = NULL)
tab_rlod <- data.frame(rlod = rlod$rlod, ic_bas = rlod$rlod_bas,
                       ic_haut = rlod$rlod_haut, p_valeur = rlod$p_valeur,
                       rlod_vrai = unname(lod_vrai["candidate"] /
                                          lod_vrai["reference"]))
ecrire_csv(tab, "output/tables/lod50.csv")
ecrire_csv(tab_rlod, "output/tables/rlod.csv")

# POD observée par niveau (pour la figure et le rapport)
obs <- aggregate(positif ~ methode + niveau_cible, data = dl,
                 FUN = function(x) c(x = sum(x), n = length(x)))
obs <- data.frame(methode = obs$methode, niveau_cible = obs$niveau_cible,
                  x = obs$positif[, "x"], n = obs$positif[, "n"])
obs <- cbind(obs, pod_ic(obs$x, obs$n)[, c("pod", "ic_bas", "ic_haut")])

saveRDS(list(lod50 = tab, rlod = tab_rlod, observe = obs),
        "output/resultats/lod50.rds")

# ---- Figure : courbes dose-réponse --------------------------------
grille <- exp(seq(log(0.1), log(10), length.out = 200))
courbes <- do.call(rbind, lapply(names(res), function(m)
  cbind(methode = m, courbe_pod(res[[m]]$modele, grille))))

g <- ggplot() +
  geom_ribbon(data = courbes, aes(x = niveau_cible, ymin = ic_bas,
                                  ymax = ic_haut, fill = methode), alpha = 0.2) +
  geom_line(data = courbes, aes(x = niveau_cible, y = pod, colour = methode)) +
  geom_pointrange(data = obs, aes(x = niveau_cible, y = pod, ymin = ic_bas,
                                  ymax = ic_haut, colour = methode),
                  position = position_dodge(width = 0.05)) +
  geom_hline(yintercept = 0.5, linetype = 3) +
  geom_vline(data = tab, aes(xintercept = lod50_estimee, colour = methode),
             linetype = 2) +
  scale_x_log10() +
  scale_colour_manual(values = c(candidate = "#2C7FB8", reference = "#D95F0E")) +
  scale_fill_manual(values = c(candidate = "#2C7FB8", reference = "#D95F0E")) +
  labs(x = "Niveau d'inoculation (UFC par portion, échelle log)",
       y = "Probabilité de détection (POD)", colour = NULL, fill = NULL,
       title = "Courbes POD et LOD50 (traits pointillés verticaux)",
       subtitle = "Points : POD observée (IC de Wilson) ; courbes : modèle de Poisson")
ggsave("output/figures/courbes_lod50.png", g, width = 7.5, height = 4.5,
       dpi = 150)

journal_ecrire(chemin_journal, "04_lod50",
               sprintf("LOD50 candidate = %.2f UFC ; référence = %.2f UFC ; RLOD = %.2f",
                       tab$lod50_estimee[1], tab$lod50_estimee[2], rlod$rlod))
