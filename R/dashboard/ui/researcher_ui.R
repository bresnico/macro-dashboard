# R/dashboard/ui/researcher_ui.R

researcher_ui <- function(config) {
  tagList(
    # L'interface du chercheur est rendue conditionnellement dans app.R
    # Nous pouvons donc simplement préparer un output pour le contenu
    uiOutput("researcher_content")
  )
}