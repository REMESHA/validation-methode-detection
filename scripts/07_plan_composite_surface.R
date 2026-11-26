# =====================================================================
# 07_plan_composite_surface.R
# ---------------------------------------------------------------------
# Étape 2 des plans d'expériences : l'OPTIMISATION.
# Le criblage a montré que la température (A) et la durée (B) comptent,
# avec une interaction et une courbure. Un plan à 2 niveaux ne peut pas
# estimer une courbure : il faut au moins 3 niveaux par facteur.
#
# Plan choisi : plan composite centré (CCD) :
#   - 4 points du carré (niveaux -1 / +1)
#   - 4 points axiaux : à -1,414 / +1,414 ("rotatable") s'ils restent
#     dans les limites physiques de config.yml, sinon sur les faces
#     du carré (-1 / +1). Vérification automatique ci-dessous.
#   - 5 points au centre, en 2 blocs
# Modèle : surface de réponse du second ordre, puis analyse canonique
# (où est le maximum ?).
# Les autres facteurs sont fixés : C (substrat) au niveau haut car son
# effet est positif ; D et E (effets négligeables) au niveau le plus
# pratique.
# =====================================================================

source("scripts/00_initialisation.R")
suppressPackageStartupMessages(library(rsm))
set.seed(cfg$graine + 7)

f <- cfg$plan_experiences$facteurs
cA <- (f$temperature$bas + f$temperature$haut) / 2
dA <- (f$temperature$haut - f$temperature$bas) / 2
cB <- (f$duree_enrichissement$bas + f$duree_enrichissement$haut) / 2
dB <- (f$duree_enrichissement$haut - f$duree_enrichissement$bas) / 2

# ---- 1. Vérifier les limites physiques, puis construire le plan -----
choix <- choisir_alpha_ccd(
  centres = c(temperature = cA, duree_enrichissement = cB),
  demi = c(temperature = dA, duree_enrichissement = dB),
  limites = cfg$plan_experiences$limites_physiques)
journal_ecrire(chemin_journal, "07_composite",
               paste0("points axiaux '", choix$alpha, "' (alpha = ",
                      round(choix$valeur, 3), ") : dans les limites physiques"))

plan <- ccd(~ x1 + x2, n0 = c(2, 3), alpha = choix$alpha, randomize = TRUE,
            coding = list(
              as.formula(sprintf("x1 ~ (temperature - %s) / %s", cA, dA)),
              as.formula(sprintf("x2 ~ (duree_enrichissement - %s) / %s", cB, dB))))

reel <- decode.data(plan)
fixes <- list(concentration_substrat = f$concentration_substrat$haut,
              volume_echantillon = f$volume_echantillon$bas,
              gain_detecteur = f$gain_detecteur$bas)
essais <- data.frame(reel[, c("run.order", "Block", "temperature",
                              "duree_enrichissement")], fixes)

# Double sécurité : chaque essai réel doit être dans les limites
lim <- cfg$plan_experiences$limites_physiques
hors <- essais$temperature < lim$temperature$min |
  essais$temperature > lim$temperature$max |
  essais$duree_enrichissement < lim$duree_enrichissement$min |
  essais$duree_enrichissement > lim$duree_enrichissement$max
if (any(hors)) stop("Essai(s) hors limites physiques : ",
                    paste(which(hors), collapse = ", "), call. = FALSE)

# ---- 2. "Réaliser" les essais (simulation) ---------------------------
plan$sb <- mesurer_sb(essais, cfg)
essais$sb <- plan$sb
ecrire_csv(essais, "output/tables/plan_composite_essais.csv")

# ---- 3. Ajuster la surface de réponse --------------------------------
# SO() = "second order" : x1, x2, x1:x2, x1^2, x2^2
modele <- rsm(sb ~ Block + SO(x1, x2), data = plan)
s <- summary(modele)
optimum_code <- s$canonical$xs
optimum_reel <- c(temperature = cA + optimum_code[["x1"]] * dA,
                  duree_enrichissement = cB + optimum_code[["x2"]] * dB)
valeurs_propres <- s$canonical$eigen$values
type_point <- if (all(valeurs_propres < 0)) "maximum" else
  if (all(valeurs_propres > 0)) "minimum" else "point selle"

# Prédiction au point stationnaire (bloc 1)
pred_opt <- predict(modele, newdata = data.frame(
  x1 = optimum_code[["x1"]], x2 = optimum_code[["x2"]],
  Block = factor(1, levels = levels(plan$Block))), interval = "confidence")

# Comparaison avec la vraie loi cachée (C = +1, D = -1, E = -1 en codé)
vrai <- optimum_vrai(C = 1, D = -1, E = -1)
comparaison <- data.frame(
  grandeur = c("Température optimale (°C)", "Durée optimale (h)",
               "S/B au point optimal"),
  estimation_plan = c(optimum_reel[["temperature"]],
                      optimum_reel[["duree_enrichissement"]], pred_opt[1, "fit"]),
  valeur_vraie_simulation = c(decoder(vrai[["A"]], f$temperature$bas,
                                      f$temperature$haut),
                              decoder(vrai[["B"]], f$duree_enrichissement$bas,
                                      f$duree_enrichissement$haut),
                              vrai[["sb"]]))
ecrire_csv(comparaison, "output/tables/plan_composite_optimum.csv")

coefs <- as.data.frame(s$coefficients)
coefs$terme <- rownames(coefs)
saveRDS(list(essais = essais, coefficients = coefs, r2 = s$r.squared,
             manque_ajustement = as.data.frame(s$lof),
             optimum = comparaison, type_point = type_point,
             valeurs_propres = valeurs_propres,
             ic_prediction = pred_opt, choix_alpha = choix),
        "output/resultats/plan_composite.rds")

# ---- 4. Figure : courbes de niveau de la surface ---------------------
grille <- expand.grid(x1 = seq(-1.5, 1.5, length.out = 80),
                      x2 = seq(-1.5, 1.5, length.out = 80))
grille$Block <- factor(1, levels = levels(plan$Block))
grille$sb <- predict(modele, newdata = grille)
grille$temperature <- cA + grille$x1 * dA
grille$duree_enrichissement <- cB + grille$x2 * dB

g <- ggplot(grille, aes(temperature, duree_enrichissement, z = sb)) +
  geom_contour_filled(bins = 10) +
  geom_point(data = essais, aes(temperature, duree_enrichissement),
             inherit.aes = FALSE, shape = 21, fill = "white", size = 2.5) +
  annotate("point", x = optimum_reel[["temperature"]],
           y = optimum_reel[["duree_enrichissement"]],
           shape = 4, size = 5, stroke = 1.5, colour = "red") +
  labs(x = "Température d'incubation (°C)",
       y = "Durée d'enrichissement (h)", fill = "S/B prédit",
       title = "Surface de réponse (plan composite centré)",
       subtitle = "Ronds : essais réalisés ; croix rouge : optimum estimé")
ggsave("output/figures/plan_composite_surface.png", g, width = 7.5,
       height = 5.5, dpi = 150)

journal_ecrire(chemin_journal, "07_composite",
               sprintf("optimum (%s) : %.1f °C, %.1f h ; S/B prédit = %.2f",
                       type_point, optimum_reel[["temperature"]],
                       optimum_reel[["duree_enrichissement"]], pred_opt[1, "fit"]))
