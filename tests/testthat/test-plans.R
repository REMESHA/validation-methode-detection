# Tests des fonctions des plans d'expériences

test_that("coder() et decoder() sont réciproques", {
  expect_equal(coder(37, 30, 37), 1)
  expect_equal(coder(30, 30, 37), -1)
  expect_equal(coder(33.5, 30, 37), 0)
  expect_equal(decoder(coder(35.2, 30, 37), 30, 37), 35.2)
})

centres <- c(temperature = 33.5, duree_enrichissement = 12)
demi    <- c(temperature = 3.5,  duree_enrichissement = 6)

test_that("points axiaux rotatables (1,414) gardés s'ils sont dans les limites", {
  ch <- choisir_alpha_ccd(centres, demi, list(
    temperature = list(min = 25, max = 42),
    duree_enrichissement = list(min = 2, max = 24)))
  expect_equal(ch$alpha, "rotatable")
  expect_equal(ch$valeur, sqrt(2))
})

test_that("bascule sur les faces si un point axial sort des limites", {
  # 12 - 1,414 x 6 = 3,5 h < 4 h : le point axial bas est impossible
  ch <- choisir_alpha_ccd(centres, demi, list(
    temperature = list(min = 25, max = 42),
    duree_enrichissement = list(min = 4, max = 24)))
  expect_equal(ch$alpha, "faces")
  expect_equal(ch$valeur, 1)
})

test_that("arrêt si même le carré sort des limites", {
  expect_error(choisir_alpha_ccd(centres, demi, list(
    temperature = list(min = 31, max = 42),
    duree_enrichissement = list(min = 2, max = 24))), "limites physiques")
})

test_that("l'optimum de la loi cachée est bien un maximum intérieur", {
  o <- optimum_vrai(C = 1, D = -1, E = -1)
  expect_true(abs(o[["A"]]) < 1.5 && abs(o[["B"]]) < 1.5)
  expect_gt(o[["sb"]], reponse_vraie(0, 0, 1, -1, -1))
})
