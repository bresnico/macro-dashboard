director_ui <- function(id, config) {
  tagList(
    uiOutput("group_error"),
    uiOutput("director_content"),
    fluidRow(
      column(3,
             uiOutput("scaleCheckboxes")  # Utiliser uiOutput au lieu de checkboxGroupInput
      ),
      column(9,
             plotOutput("evolution_plot"),
             tableOutput("stats_table")
      )
    )
  )
}