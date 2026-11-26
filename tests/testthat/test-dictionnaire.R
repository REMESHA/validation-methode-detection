# Tests du contrôle par le dictionnaire des variables

jeu_test <- list(
  nom = "essai", controler_valeurs = TRUE,
  variables = list(
    list(nom = "methode", type = "texte", valeurs = list("candidate", "reference")),
    list(nom = "pod", type = "numerique", min = 0, max = 1),
    list(nom = "x", type = "entier", min = 0),
    list(nom = "date_analyse", type = "date")))

d_ok <- data.frame(methode = c("candidate", "reference"), pod = c(0.2, 0.9),
                   x = c(4L, 18L), date_analyse = c("2026-01-10", "2026-02-01"),
                   stringsAsFactors = FALSE)

test_that("un fichier conforme ne donne que des contrôles conformes", {
  r <- controler_jeu(d_ok, jeu_test, "f.csv")
  expect_true(all(r$statut == "conforme"))
})

test_that("colonne en trop et colonne manquante sont détectées", {
  d <- d_ok; d$inconnue <- 1; d$x <- NULL
  r <- controler_jeu(d, jeu_test, "f.csv")
  nc <- r[r$statut != "conforme", ]
  expect_true("inconnue" %in% nc$variable)
  expect_true("x" %in% nc$variable)
})

test_that("type, valeurs et bornes sont contrôlés", {
  d <- d_ok
  d$methode[1] <- "autre"          # valeur non permise
  d$pod[2] <- 1.2                  # au-dessus du maximum
  d$x <- c(4.5, 18)                # pas un entier
  r <- controler_jeu(d, jeu_test, "f.csv")
  nc <- r[r$statut != "conforme", ]
  expect_true(all(c("methode", "pod", "x") %in% nc$variable))
})

test_that("le dictionnaire du projet se lit et chaque variable a une description", {
  dico <- yaml::read_yaml(file.path(racine, "config", "dictionnaire_variables.yml"),
                          fileEncoding = "UTF-8")
  plat <- dictionnaire_a_plat(dico)
  expect_true(all(nchar(plat$description) > 0))
  expect_true(all(plat$type %in% c("texte", "numerique", "entier", "logique", "date")))
  expect_true(is.character(plat$variable))
})
