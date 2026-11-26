# Tests des fonctions POD / dPOD

test_that("l'IC de Wilson est identique à celui de prop.test (sans correction)", {
  # prop.test(correct = FALSE) calcule l'intervalle de Wilson : c'est une
  # référence indépendante de notre code.
  for (cas in list(c(10, 20), c(3, 20), c(17, 20), c(1, 5), c(6, 18))) {
    attendu <- suppressWarnings(
      prop.test(cas[1], cas[2], correct = FALSE))$conf.int
    obtenu  <- pod_ic(cas[1], cas[2])
    expect_equal(obtenu$ic_bas,  attendu[1], tolerance = 1e-8)
    expect_equal(obtenu$ic_haut, attendu[2], tolerance = 1e-8)
  }
})

test_that("cas particuliers x = 0 et x = n (formules AOAC)", {
  n <- 20
  z0 <- pod_ic(0, n)
  expect_equal(z0$ic_bas, 0)
  expect_equal(z0$ic_haut, 3.8415 / (n + 3.8415), tolerance = 1e-4)
  zn <- pod_ic(n, n)
  expect_equal(zn$ic_haut, 1)
  expect_equal(zn$ic_bas, n / (n + 3.8415), tolerance = 1e-4)
})

test_that("dPOD : méthodes identiques => IC symétrique contenant 0", {
  d <- dpod_non_apparie(10, 20, 10, 20)
  expect_equal(d$dpod, 0)
  expect_equal(d$ic_bas, -d$ic_haut)
  expect_false(d$significatif)
})

test_that("dPOD : très grande différence => significative", {
  d <- dpod_non_apparie(20, 20, 2, 20)
  expect_true(d$significatif)
  expect_gt(d$ic_bas, 0)
})

test_that("dPOD appariée : moyenne des différences", {
  r1 <- c(1, 1, 1, 0, 1, 0, 1, 1)
  r2 <- c(1, 0, 1, 0, 0, 0, 1, 1)
  d <- dpod_apparie(r1, r2)
  expect_equal(d$dpod, mean(r1 - r2))
})
