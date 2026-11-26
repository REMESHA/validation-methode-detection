# Tests de l'estimation de la LOD50 : sur un très grand jeu simulé,
# l'estimation doit être proche de la vraie valeur.

test_that("la LOD50 retrouve la vraie valeur sur de grandes données", {
  set.seed(1)
  r <- 0.6
  niveaux <- rep(c(0.25, 0.5, 1, 2, 4), each = 2000)
  d <- data.frame(niveau_cible = niveaux,
                  positif = as.integer(simuler_detection(niveaux, r)))
  res <- ajuster_lod50(d)
  expect_equal(res$lod50, log(2) / r, tolerance = 0.05)   # à 5 % près
  expect_lt(res$lod50_bas, log(2) / r)
  expect_gt(res$lod50_haut, log(2) / r)
})

test_that("la simulation suit bien POD = 1 - exp(-r * lambda)", {
  set.seed(2)
  lambda <- rep(1.5, 50000)
  p_obs <- mean(simuler_detection(lambda, 0.5))
  expect_equal(p_obs, 1 - exp(-0.5 * 1.5), tolerance = 0.01)
})

test_that("le RLOD retrouve le rapport des efficacités", {
  set.seed(3)
  niv <- rep(c(0.5, 1, 2, 4), each = 3000)
  d <- rbind(
    data.frame(niveau_cible = niv, methode = "candidate",
               positif = as.integer(simuler_detection(niv, 0.6))),
    data.frame(niveau_cible = niv, methode = "reference",
               positif = as.integer(simuler_detection(niv, 0.5))))
  res <- ajuster_rlod(d)
  expect_equal(res$rlod, 0.5 / 0.6, tolerance = 0.05)
})
