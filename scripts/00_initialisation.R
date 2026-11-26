# =====================================================================
# 00_initialisation.R
# ---------------------------------------------------------------------
# Chargé au début de chaque script : packages, fonctions, configuration.
# Tous les scripts doivent être lancés DEPUIS LA RACINE du projet
# (le dossier qui contient config/, R/, scripts/...).
# =====================================================================

if (!file.exists("config/config.yml")) {
  stop("Lancez les scripts depuis la racine du projet ",
       "(le dossier qui contient config/config.yml).", call. = FALSE)
}

# Packages utilisés dans le projet
packages_projet <- c("yaml", "digest", "ggplot2", "lme4", "FrF2", "rsm")

manquants <- packages_projet[!vapply(packages_projet, requireNamespace,
                                     logical(1), quietly = TRUE)]
if (length(manquants) > 0) {
  stop("Packages manquants : ", paste(manquants, collapse = ", "),
       "\nInstallez-les avec : install.packages(c(\"",
       paste(manquants, collapse = "\", \""), "\"))", call. = FALSE)
}

suppressPackageStartupMessages({
  library(ggplot2)
})

# Toutes les fonctions du dossier R/
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

cfg <- yaml::read_yaml("config/config.yml", fileEncoding = "UTF-8")

# Thème graphique commun
theme_set(theme_minimal(base_size = 12))

# Chemins de sortie
chemin_journal <- "output/tracabilite/journal.csv"
dir.create("output/tracabilite", recursive = TRUE, showWarnings = FALSE)
dir.create("output/qc", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/resultats", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

# Si le journal n'existe pas encore (script lancé seul), on le crée
if (!file.exists(chemin_journal)) journal_initialiser(chemin_journal)

# Écriture CSV commune : séparateur virgule, UTF-8, sans numéros de
# ligne, et fins de ligne "\n" sur TOUS les systèmes. Sous Windows, R
# écrit sinon "\r\n" : les fichiers seraient identiques à l'oeil mais
# leurs empreintes SHA-256 différentes de celles obtenues sous Linux.
# Ouvrir le fichier en mode binaire ("wb") empêche cette conversion.
ecrire_csv <- function(d, chemin) {
  d[] <- lapply(d, function(x) if (is.character(x)) enc2utf8(x) else x)
  con <- file(chemin, open = "wb")
  on.exit(close(con))
  write.csv(d, con, row.names = FALSE, na = "")
}
lire_csv <- function(chemin) {
  read.csv(chemin, stringsAsFactors = FALSE, fileEncoding = "UTF-8",
           na.strings = c("", "NA"))
}
