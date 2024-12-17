teacher_ui <- function() {
  tagList(
    # L'interface de l'enseignant est rendue conditionnellement dans app.R
    # Nous pouvons simplement préparer un output pour le contenu
    uiOutput("teacher_results")
  )
}