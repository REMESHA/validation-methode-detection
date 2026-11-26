# =====================================================================
# fonctions_dictionnaire.R
# ---------------------------------------------------------------------
# Dictionnaire des variables : documentation + contrôle automatique.
#   - dictionnaire_a_plat() : transforme le YAML en tableau lisible
#   - controler_jeu()       : compare un fichier au dictionnaire
#   - resumer_variables()   : restitution descriptive de chaque variable
# =====================================================================

# ---------------------------------------------------------------------
# dictionnaire_a_plat() : une ligne par variable et par jeu de données
# ---------------------------------------------------------------------
dictionnaire_a_plat <- function(dico) {
  do.call(rbind, lapply(dico$jeux_de_donnees, function(j) {
    do.call(rbind, lapply(j$variables, function(v) {
      data.frame(
        jeu_de_donnees = j$nom, fichiers = j$fichiers, variable = v$nom,
        type = v$type, unite = if (is.null(v$unite)) "" else v$unite,
        valeurs_permises = if (is.null(v$valeurs)) "" else
          paste(v$valeurs, collapse = " | "),
        minimum = if (is.null(v$min)) NA else v$min,
        maximum = if (is.null(v$max)) NA else v$max,
        description = v$description, stringsAsFactors = FALSE)
    }))
  }))
}

# ---------------------------------------------------------------------
# type_conforme() : la colonne a-t-elle le type annoncé ?
# Une colonne entièrement vide est lue par R comme "logique" : on
# l'accepte quel que soit le type annoncé.
# ---------------------------------------------------------------------
type_conforme <- function(x, type) {
  if (all(is.na(x))) return(TRUE)
  switch(type,
    texte     = is.character(x),
    numerique = is.numeric(x),
    entier    = is.numeric(x) && all(x[!is.na(x)] == round(x[!is.na(x)])),
    logique   = is.logical(x),
    date      = is.character(x) &&
      !anyNA(as.Date(x[!is.na(x)], optional = TRUE)),
    FALSE)
}

# ---------------------------------------------------------------------
# controler_jeu() : contrôle d'UN fichier par rapport à son entrée du
# dictionnaire. Renvoie une ligne par point contrôlé, avec un statut.
# ---------------------------------------------------------------------
controler_jeu <- function(d, jeu, fichier) {
  res <- list()
  ajouter <- function(variable, controle, ok, detail = "") {
    res[[length(res) + 1]] <<- data.frame(
      jeu_de_donnees = jeu$nom, fichier = fichier, variable = variable,
      controle = controle, statut = if (ok) "conforme" else "NON CONFORME",
      detail = detail, stringsAsFactors = FALSE)
  }
  documentees <- vapply(jeu$variables, `[[`, character(1), "nom")

  # 1. Colonnes : ni de plus, ni de moins
  for (v in setdiff(names(d), documentees))
    ajouter(v, "colonne documentée", FALSE, "colonne absente du dictionnaire")
  for (v in setdiff(documentees, names(d)))
    ajouter(v, "colonne présente", FALSE, "colonne documentée mais absente du fichier")

  # 2. Type et valeurs de chaque colonne documentée et présente
  for (v in jeu$variables) {
    if (!v$nom %in% names(d)) next
    x <- d[[v$nom]]
    ok_type <- type_conforme(x, v$type)
    ajouter(v$nom, paste("type", v$type), ok_type,
            if (ok_type) "" else paste("type lu :", class(x)[1]))

    if (!isTRUE(jeu$controler_valeurs) || !ok_type) next
    xn <- x[!is.na(x)]
    if (!is.null(v$valeurs)) {
      hors <- setdiff(unique(as.character(xn)), as.character(unlist(v$valeurs)))
      ajouter(v$nom, "valeurs permises", length(hors) == 0,
              if (length(hors)) paste("valeurs inattendues :",
                                      paste(hors, collapse = ", ")) else "")
    }
    if (!is.null(v$min) && is.numeric(xn) && length(xn)) {
      ajouter(v$nom, paste(">=", v$min), all(xn >= v$min - 1e-12),
              paste("minimum observé :", signif(min(xn), 6)))
    }
    if (!is.null(v$max) && is.numeric(xn) && length(xn)) {
      ajouter(v$nom, paste("<=", v$max), all(xn <= v$max + 1e-12),
              paste("maximum observé :", signif(max(xn), 6)))
    }
  }
  do.call(rbind, res)
}

# ---------------------------------------------------------------------
# resumer_variables() : restitution descriptive d'un jeu de données
#   numérique : n, manquants, minimum, médiane, moyenne, maximum
#   texte / logique : n, manquants, nombre de modalités, effectifs des
#   5 modalités les plus fréquentes
# ---------------------------------------------------------------------
resumer_variables <- function(d, nom_jeu, dico_jeu) {
  types <- setNames(vapply(dico_jeu$variables, `[[`, character(1), "type"),
                    vapply(dico_jeu$variables, `[[`, character(1), "nom"))
  do.call(rbind, lapply(names(d), function(v) {
    x <- d[[v]]
    t <- if (v %in% names(types)) types[[v]] else "non documenté"
    base <- data.frame(jeu_de_donnees = nom_jeu, variable = v, type = t,
                       n = sum(!is.na(x)), manquants = sum(is.na(x)),
                       minimum = NA_real_, mediane = NA_real_,
                       moyenne = NA_real_, maximum = NA_real_,
                       n_modalites = NA_integer_, modalites = "",
                       stringsAsFactors = FALSE)
    if (t %in% c("numerique", "entier") && is.numeric(x) && any(!is.na(x))) {
      base$minimum <- min(x, na.rm = TRUE)
      base$mediane <- median(x, na.rm = TRUE)
      base$moyenne <- mean(x, na.rm = TRUE)
      base$maximum <- max(x, na.rm = TRUE)
    } else if (any(!is.na(x))) {
      tab <- sort(table(x), decreasing = TRUE)
      base$n_modalites <- length(tab)
      haut <- head(tab, 5)
      base$modalites <- paste0(names(haut), " (", as.integer(haut), ")",
                               collapse = " ; ")
      if (length(tab) > 5) base$modalites <- paste0(base$modalites, " ; …")
    }
    base
  }))
}
