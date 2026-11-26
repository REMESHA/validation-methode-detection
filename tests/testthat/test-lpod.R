# Tests de la procédure LPOD / dLPOD (étude interlaboratoires)

donnees_exemple <- function() {
  # 3 laboratoires x 4 portions
  data.frame(laboratoire = rep(c("L1", "L2", "L3"), each = 4),
             positif = c(1, 1, 0, 0,   1, 1, 1, 0,   0, 0, 0, 1))
}

test_that("les composantes de variance sont celles de l'ANOVA à un facteur", {
  d <- donnees_exemple()
  cv <- composantes_variance(d$positif, d$laboratoire)
  # Référence indépendante : la table d'ANOVA de R (fonction aov)
  tab <- summary(aov(positif ~ laboratoire, data = d))[[1]]
  cm_inter <- tab[["Mean Sq"]][1]
  cm_intra <- tab[["Mean Sq"]][2]
  expect_equal(cv$s_r^2, cm_intra)
  expect_equal(cv$s_L^2, max(0, (cm_inter - cm_intra) / 4))
  expect_equal(cv$s_R^2, cv$s_r^2 + cv$s_L^2)
})

test_that("degrés de liberté de Satterthwaite : cas limites", {
  # sans variabilité intra-labo : ddl = L - 1
  expect_equal(ddl_satterthwaite(s_L = 0.2, s_r = 0, L = 12, N = 144), 11)
  # sans variabilité entre labos : ddl = N - L
  expect_equal(ddl_satterthwaite(s_L = 0, s_r = 0.5, L = 12, N = 144), 132)
  # cas général : entre les deux bornes
  ddl <- ddl_satterthwaite(s_L = 0.15, s_r = 0.5, L = 12, N = 144)
  expect_gt(ddl, 11)
  expect_lt(ddl, 11 + 132)
  # rien ne varie : on retombe sur L - 1
  expect_equal(ddl_satterthwaite(0, 0, 12, 144), 11)
})

test_that("LPOD extrême : intervalle de Wilson, comme l'AOAC", {
  d <- data.frame(laboratoire = rep(paste0("L", 1:12), each = 12), positif = 1)
  l <- lpod_ic(d)
  expect_equal(l$methode_ic, "Wilson")
  expect_equal(l$ic_haut, 1)
  expect_equal(l$ic_bas, 144 / (144 + 3.8415), tolerance = 1e-4)
})

test_that("LPOD intermédiaire : intervalle de Student", {
  set.seed(5)
  d <- data.frame(laboratoire = rep(paste0("L", 1:12), each = 12),
                  positif = rbinom(144, 1, 0.5))
  l <- lpod_ic(d)
  expect_equal(l$methode_ic, "Student (Satterthwaite)")
  pod_labos <- tapply(d$positif, d$laboratoire, mean)
  t <- qt(0.975, l$ddl)
  expect_equal(l$ic_bas, l$lpod - t * sd(pod_labos) / sqrt(12))
})

test_that("dLPOD : même combinaison des bornes que la dPOD", {
  l1 <- data.frame(lpod = 0.5, ic_bas = 0.38, ic_haut = 0.63)
  l2 <- data.frame(lpod = 0.4, ic_bas = 0.30, ic_haut = 0.52)
  d <- dlpod_ic(l1, l2)
  expect_equal(d$dlpod, 0.1)
  expect_equal(d$ic_bas, 0.1 - sqrt(0.12^2 + 0.12^2))
  expect_equal(d$ic_haut, 0.1 + sqrt(0.13^2 + 0.10^2))
})
