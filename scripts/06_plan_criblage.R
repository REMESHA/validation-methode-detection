# =====================================================================
# 06_plan_criblage.R
# ---------------------------------------------------------------------
# Étape 1 des plans d'expériences : le CRIBLAGE.
# Question : parmi 5 paramètres physiques, lesquels influencent le
# rapport signal / bruit (S/B) de la chambre optique ?
#
# Plan choisi : factoriel fractionnaire 2^(5-1), soit 16 essais au lieu
# de 32 pour le plan complet, + 4 points au centre.
#   - Résolution V : les effets principaux et les interactions entre
#     2 facteurs ne sont pas confondus entre eux (seulement avec des
#     interactions d'ordre supérieur, supposées négligeables).
#   - Les points au centre servent à : estimer l'erreur de mesure
#     (répétitions) et détecter une COURBURE (réponse non linéaire).
# =====================================================================

source("scripts/00_initialisation.R")
suppressPackageStartupMessages(library(FrF2))
set.seed(cfg$graine + 6)

f <- cfg$plan_experiences$facteurs
noms <- names(f)                       # les 5 facteurs du config
niveaux <- lapply(f, function(x) c(x$bas, x$haut))

# ---- 1. Construire le plan ------------------------------------------
plan <- FrF2(nruns = 16, nfactors = 5, factor.names = niveaux,
             ncenter = cfg$plan_experiences$n_points_centraux_criblage,
             randomize = TRUE, seed = cfg$graine)
essais <- as.data.frame(plan)[, noms]
essais <- cbind(ordre_essai = seq_len(nrow(essais)), essais)

# Générateur du plan (quelle colonne est fabriquée à partir des autres)
generateur <- paste(unlist(generators(plan)), collapse = "; ")

# ---- 2. "Réaliser" les essais au banc (simulation) -------------------
essais$sb <- mesurer_sb(essais, cfg)
ecrire_csv(essais, "output/tables/plan_criblage_essais.csv")

# ---- 3. Analyse en unités codées -----------------------------------
codes <- as.data.frame(mapply(function(col, nm) coder(col, f[[nm]]$bas,
                                                     f[[nm]]$haut),
                              essais[, noms], noms))
names(codes) <- c("A", "B", "C", "D", "E")
codes$centre <- as.integer(rowSums(codes[, 1:5] == 0) == 5)
codes$sb <- essais$sb

# Modèle : effets principaux + interactions d'ordre 2 + indicateur
# "point central" (son coefficient mesure la courbure).
modele <- lm(sb ~ (A + B + C + D + E)^2 + centre, data = codes)
coefs <- summary(modele)$coefficients
tab_effets <- data.frame(
  terme = rownames(coefs)[-1],
  coefficient = coefs[-1, "Estimate"],
  effet = 2 * coefs[-1, "Estimate"],  # effet = passage de -1 à +1
  erreur_type = coefs[-1, "Std. Error"],
  p_valeur = coefs[-1, "Pr(>|t|)"],
  row.names = NULL)
tab_effets$effet[tab_effets$terme == "centre"] <-
  tab_effets$coefficient[tab_effets$terme == "centre"]
tab_effets <- tab_effets[order(-abs(tab_effets$effet)), ]
ecrire_csv(tab_effets, "output/tables/plan_criblage_effets.csv")

legende <- data.frame(code = c("A", "B", "C", "D", "E"), facteur = noms,
                      bas = sapply(f, `[[`, "bas"),
                      haut = sapply(f, `[[`, "haut"),
                      unite = sapply(f, `[[`, "unite"), row.names = NULL)

saveRDS(list(essais = essais, effets = tab_effets, legende = legende,
             generateur = generateur, residus_df = modele$df.residual,
             sigma = summary(modele)$sigma),
        "output/resultats/plan_criblage.rds")

# ---- 4. Figure : diagramme de Pareto des effets ---------------------
pe <- tab_effets[tab_effets$terme != "centre", ]
pe$terme <- factor(pe$terme, levels = rev(pe$terme))
pe$signif <- ifelse(pe$p_valeur < 0.05, "p < 0,05", "p >= 0,05")
g <- ggplot(pe, aes(x = abs(effet), y = terme, fill = signif)) +
  geom_col() +
  scale_fill_manual(values = c("p < 0,05" = "#2C7FB8", "p >= 0,05" = "grey70")) +
  labs(x = "|Effet| sur le rapport S/B (passage du niveau bas au niveau haut)",
       y = NULL, fill = NULL,
       title = "Criblage : quels paramètres comptent ?",
       subtitle = "A = température, B = durée, C = substrat, D = volume, E = gain")
ggsave("output/figures/plan_criblage_pareto.png", g, width = 7, height = 5,
       dpi = 150)

courbure <- tab_effets[tab_effets$terme == "centre", ]
journal_ecrire(chemin_journal, "06_criblage",
               sprintf("%d essais ; courbure = %.2f (p = %.3g)",
                       nrow(essais), courbure$coefficient, courbure$p_valeur))
