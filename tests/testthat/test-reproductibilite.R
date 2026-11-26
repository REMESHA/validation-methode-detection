# Tests de la comparaison avec la référence

ecrire_tmp <- function(d) {
  f <- tempfile(fileext = ".csv")
  write.csv(d, f, row.names = FALSE)
  f
}

test_that("fichiers identiques => 'identique'", {
  d <- data.frame(a = c(1.5, 2), b = c("x", "y"))
  expect_equal(comparer_fichiers(ecrire_tmp(d), ecrire_tmp(d))$statut, "identique")
})

test_that("tout petit écart numérique => identique à la tolérance près", {
  d1 <- data.frame(a = c(1.5, 2)); d2 <- data.frame(a = c(1.5, 2 + 1e-9))
  expect_equal(comparer_fichiers(ecrire_tmp(d2), ecrire_tmp(d1))$statut,
               "identique à la tolérance près")
})

test_that("vrai écart ou texte différent => DIFFÉRENT", {
  d1 <- data.frame(a = c(1.5, 2), b = c("x", "y"))
  d2 <- data.frame(a = c(1.5, 2.1), b = c("x", "y"))
  d3 <- data.frame(a = c(1.5, 2), b = c("x", "z"))
  expect_equal(comparer_fichiers(ecrire_tmp(d2), ecrire_tmp(d1))$statut, "DIFFÉRENT")
  expect_equal(comparer_fichiers(ecrire_tmp(d3), ecrire_tmp(d1))$statut, "DIFFÉRENT")
})
