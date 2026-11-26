# Chargé automatiquement par testthat avant les tests :
# on charge les fonctions du projet et la configuration.
racine <- normalizePath(file.path("..", ".."))
for (f in list.files(file.path(racine, "R"), pattern = "\\.R$",
                     full.names = TRUE)) source(f)
cfg_test <- yaml::read_yaml(file.path(racine, "config", "config.yml"),
                            fileEncoding = "UTF-8")
