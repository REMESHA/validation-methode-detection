# =====================================================================
# fonctions_tracabilite.R
# ---------------------------------------------------------------------
# Garder une trace de CE QUI a été analysé, AVEC QUOI et QUAND.
#   - empreinte SHA-256 de chaque fichier d'entrée : si un seul caractère
#     change dans le fichier, l'empreinte change complètement ;
#   - version de R et des packages ;
#   - identifiant du commit Git (version exacte du code) ;
#   - journal horodaté des étapes du pipeline.
# =====================================================================

# Empreinte SHA-256 d'un fichier (package digest)
empreinte_fichier <- function(chemin) {
  digest::digest(file = chemin, algo = "sha256")
}

# ---------------------------------------------------------------------
# manifeste_fichiers() : tableau des fichiers lus, avec leur empreinte
# ---------------------------------------------------------------------
manifeste_fichiers <- function(chemins) {
  data.frame(
    fichier = chemins,
    taille_octets = file.size(chemins),
    n_lignes_donnees = vapply(chemins, function(f) length(readLines(f)) - 1L,
                              integer(1)),
    sha256 = vapply(chemins, empreinte_fichier, character(1)),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------
# commit_git() : identifiant du commit courant, ou "non disponible"
# (par exemple si le dossier n'est pas encore un dépôt Git)
# ---------------------------------------------------------------------
commit_git <- function() {
  res <- tryCatch(
    suppressWarnings(system2("git", c("rev-parse", "HEAD"),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character(0))
  if (length(res) == 1 && nchar(res) == 40) res else "non disponible"
}

# ---------------------------------------------------------------------
# environnement_execution() : versions de R et des packages utilisés
# ---------------------------------------------------------------------
environnement_execution <- function(packages) {
  data.frame(
    element = c("R", packages, "commit_git", "systeme"),
    version = c(R.version.string,
                vapply(packages, function(p) as.character(packageVersion(p)),
                       character(1)),
                commit_git(),
                paste(Sys.info()[["sysname"]], Sys.info()[["release"]])),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------
# Journal des étapes : une ligne par événement, avec date et heure.
# ---------------------------------------------------------------------
journal_initialiser <- function(chemin) {
  writeLines("horodatage;etape;message", chemin, useBytes = TRUE)
  invisible(chemin)
}

journal_ecrire <- function(chemin, etape, message) {
  ligne <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
                 etape, gsub(";", ",", message), sep = ";")
  cat(ligne, "\n", file = chemin, append = TRUE, sep = "")
  message("[", etape, "] ", message)
  invisible(ligne)
}
