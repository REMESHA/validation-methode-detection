# =====================================================================
# fonctions_reproductibilite.R
# ---------------------------------------------------------------------
# Vérifier qu'une nouvelle exécution redonne les MÊMES résultats qu'une
# exécution de référence (enregistrée dans le dossier reference/).
#
# On compare le CONTENU des fichiers (valeur par valeur), et non leurs
# empreintes : une empreinte change pour une simple différence de fin de
# ligne ou d'arrondi d'affichage, alors que le contenu est le même.
#   - colonnes texte et logiques : égalité stricte
#   - colonnes numériques : écart relatif <= tolerance
# =====================================================================

# ---------------------------------------------------------------------
# comparer_fichiers() : compare un fichier CSV à sa version de référence
# Renvoie une ligne : fichier, statut, écart maximal, détail
# ---------------------------------------------------------------------
comparer_fichiers <- function(actuel, reference, tolerance = 1e-6) {
  ligne <- function(statut, ecart = NA_real_, detail = "") {
    data.frame(fichier = actuel, statut = statut,
               ecart_relatif_max = ecart, detail = detail,
               stringsAsFactors = FALSE)
  }
  if (!file.exists(reference)) return(ligne("ABSENT DE LA RÉFÉRENCE"))
  a <- read.csv(actuel, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  r <- read.csv(reference, stringsAsFactors = FALSE, fileEncoding = "UTF-8")

  if (!identical(names(a), names(r)))
    return(ligne("DIFFÉRENT", detail = "noms de colonnes différents"))
  if (nrow(a) != nrow(r))
    return(ligne("DIFFÉRENT", detail = sprintf("%d lignes au lieu de %d",
                                              nrow(a), nrow(r))))
  ecart_max <- 0
  for (v in names(a)) {
    x <- a[[v]]; y <- r[[v]]
    if (is.numeric(x) && is.numeric(y)) {
      if (!identical(is.na(x), is.na(y)))
        return(ligne("DIFFÉRENT", detail = paste("valeurs manquantes :", v)))
      ok <- !is.na(x)
      e <- abs(x[ok] - y[ok]) / pmax(1, abs(y[ok]))
      if (length(e)) ecart_max <- max(ecart_max, e)
    } else if (!identical(as.character(x), as.character(y))) {
      return(ligne("DIFFÉRENT", detail = paste("valeurs différentes :", v)))
    }
  }
  if (ecart_max == 0) return(ligne("identique", 0))
  if (ecart_max <= tolerance)
    return(ligne("identique à la tolérance près", ecart_max))
  ligne("DIFFÉRENT", ecart_max, "écart numérique au-delà de la tolérance")
}

# ---------------------------------------------------------------------
# fichiers_a_comparer() : les fichiers qui définissent les résultats
# (données brutes simulées, données validées, tables de résultats,
# registre QC). Le manifeste et le journal ne sont pas comparés :
# ils contiennent des dates, des tailles et des empreintes.
# ---------------------------------------------------------------------
fichiers_a_comparer <- function() {
  sort(c(Sys.glob("data/raw/*/*.csv"),
         Sys.glob("data/processed/*.csv"),
         Sys.glob("output/tables/*.csv"),
         "output/qc/registre_anomalies.csv",
         "output/qc/bilan_par_fichier.csv",
         "output/dictionnaire/resume_variables.csv"))
}
