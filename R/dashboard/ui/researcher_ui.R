# R/ui/researcher_ui.R

researcher_ui <- function() {
  tagList(
    # Message d'erreur pour code chercheur invalide
    uiOutput("researcher_error"),
    
    # Contenu pour code chercheur valide
    uiOutput("researcher_content")
  )
}