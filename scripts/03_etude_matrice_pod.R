# =====================================================================
# 03_etude_matrice_pod.R
# ---------------------------------------------------------------------
# Étude de matrice : pour chaque matrice et chaque niveau, on calcule
#   - la POD de la méthode candidate et de la référence (IC de Wilson)
#   - la dPOD = POD candidate - POD référence (IC à 95 %)
# Décision : si l'IC de la dPOD contient 0, pas de différence
# significative entre les deux méthodes à ce niveau.
# =====================================================================

source("scripts/00_initialisation.R")

donnees <- lire_csv("data/processed/resultats_portions.csv")
dm <- donnees[donnees$etude == "matrice", ]

tab <- tableau_pod(dm)
ecrire_csv(tab, "output/tables/pod_dpod_etude_matrice.csv")

# Vérifier que le niveau bas donne bien des résultats fractionnaires
# (entre 25 % et 75 % de positifs), comme le demande le plan AOAC
bas <- tab[tab$niveau_cible == cfg$etude_matrice$niveaux_ufc$bas, ]
fractionnaire_ok <- (bas$pod_reference >= 0.25 & bas$pod_reference <= 0.75) |
                    (bas$pod_candidate >= 0.25 & bas$pod_candidate <= 0.75)

saveRDS(list(tableau = tab, fractionnaire_ok = fractionnaire_ok),
        "output/resultats/etude_matrice.rds")

# ---- Figure : POD et dPOD avec IC ------------------------------------
long <- rbind(
  data.frame(matrice = tab$matrice, niveau = tab$niveau_cible,
             mesure = "POD candidate", valeur = tab$pod_candidate,
             bas = tab$pod_c_bas, haut = tab$pod_c_haut),
  data.frame(matrice = tab$matrice, niveau = tab$niveau_cible,
             mesure = "POD référence", valeur = tab$pod_reference,
             bas = tab$pod_r_bas, haut = tab$pod_r_haut),
  data.frame(matrice = tab$matrice, niveau = tab$niveau_cible,
             mesure = "dPOD (candidate - référence)", valeur = tab$dpod,
             bas = tab$dpod_bas, haut = tab$dpod_haut))
long$niveau <- factor(paste(long$niveau, "UFC"),
                      levels = paste(sort(unique(tab$niveau_cible)), "UFC"))

g <- ggplot(long, aes(x = niveau, y = valeur, colour = mesure)) +
  geom_hline(yintercept = 0, linetype = 3) +
  geom_pointrange(aes(ymin = bas, ymax = haut),
                  position = position_dodge(width = 0.5)) +
  facet_wrap(~ matrice) +
  scale_colour_manual(values = c("POD candidate" = "#2C7FB8",
                                 "POD référence" = "#D95F0E",
                                 "dPOD (candidate - référence)" = "black")) +
  labs(x = "Niveau d'inoculation (par portion)", y = "Valeur (IC à 95 %)",
       colour = NULL, title = "Étude de matrice : POD et dPOD") +
  theme(legend.position = "bottom")
ggsave("output/figures/pod_dpod_etude_matrice.png", g, width = 8,
       height = 4.5, dpi = 150)

journal_ecrire(chemin_journal, "03_pod",
               sprintf("%d lignes POD/dPOD ; différence significative : %d",
                       nrow(tab), sum(tab$difference_significative)))
