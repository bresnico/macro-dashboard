director_ui <- function() {
  tagList(
    # L'interface du directeur est rendue conditionnellement dans app.R
    # Nous pouvons simplement préparer un output pour le contenu
    uiOutput("director_results")
  )
}