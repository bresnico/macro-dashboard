teacher_ui <- function() {
  tagList(
    # Message d'erreur pour ID invalide
    uiOutput("id_error"),
    
    # Contenu principal
    uiOutput("teacher_content")
  )
}