# Lance tous les tests : Rscript tests/lancer_tests.R
# (depuis la racine du projet)
resultat <- testthat::test_dir("tests/testthat", reporter = "summary",
                               stop_on_failure = TRUE)
