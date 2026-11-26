# Tests des contrôles qualité : chaque anomalie injectée doit être vue.

fabriquer <- function() {
  set.seed(4)
  plan <- rbind(
    plan_portions("matrice", "acier_inoxydable",
                  list(0, 1.2, 10), list(5, 20, 5), "candidate"),
    plan_portions("matrice", "acier_inoxydable",
                  list(0, 1.2, 10), list(5, 20, 5), "reference"))
  simuler_etude(plan, cfg_test, prefixe = "T")
}

test_that("des données propres ne déclenchent aucune anomalie", {
  sim <- fabriquer()
  qc <- controler_candidate(sim$candidate, cfg_test, "test.csv")
  expect_null(qc$anomalies)
  expect_equal(qc$n_exclu, 0)
})

test_that("toutes les anomalies injectées sont détectées", {
  sim <- fabriquer()
  bad <- injecter_anomalies(sim$candidate, sim$reference)
  qc_c <- controler_candidate(bad$candidate, cfg_test, "test.csv")
  qc_r <- controler_reference(bad$reference, cfg_test, "test.csv")
  regles <- c(qc_c$anomalies$regle, qc_r$anomalies$regle)
  for (r in c("doublon_exact", "signal_manquant", "signal_impossible",
              "signal_sature", "date_hors_periode", "resultat_non_autorise")) {
    expect_true(r %in% regles, info = r)
  }
  # 4 lignes bloquantes côté candidate (doublon, manquant, négatif, date)
  expect_equal(qc_c$n_exclu, 4)
})

test_that("un fichier sans colonne obligatoire arrête l'analyse", {
  sim <- fabriquer()
  d <- sim$candidate
  d$signal_rfu <- NULL
  expect_error(controler_candidate(d, cfg_test, "test.csv"), "manquante")
})

test_that("le seuil de positivité est appliqué correctement", {
  sim <- fabriquer()
  qc <- controler_candidate(sim$candidate, cfg_test, "test.csv")
  s <- cfg_test$signal$seuil_positivite
  expect_true(all(qc$valides$positif == (qc$valides$signal_rfu >= s)))
})
