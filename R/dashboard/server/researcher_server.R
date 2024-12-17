# R/dashboard/server/researcher_server.R

researcher_server <- function(input, output, session, survey_data, config, credentials) {
  # Valider l'identifiant du chercheur
  valid_id <- reactive({
    req(input$user_id)
    input$user_id %in% credentials$researcher_codes
  })
  
  # Afficher un message si l'identifiant est invalide
  observeEvent(input$view_data, {
    if (input$user_type == "researcher") {
      if (!valid_id()) {
        showNotification("Identifiant chercheur invalide.", type = "error")
      }
    }
  })
  
  # Générer le contenu de l'interface du chercheur si l'identifiant est valide
  output$researcher_content <- renderUI({
    req(valid_id())
    req(survey_data())
    
    tagList(
      sidebarLayout(
        sidebarPanel(
          h3("Filtres Démographiques"),
          # Filtre pour le statut
          selectInput(
            inputId = "filter_status",
            label = "Statut",
            choices = c("Tous", config$demographics$status$labels),
            selected = "Tous"
          ),
          # Filtre conditionnel pour les années d'expérience
          uiOutput("conditional_filters"),
          # Bouton pour appliquer les filtres
          actionButton("apply_filters", "Appliquer les filtres")
        ),
        mainPanel(
          h3("Résultats"),
          DTOutput("researcher_table"),
          plotOutput("researcher_plot")
        )
      )
    )
  })
  
  # Générer le filtre conditionnel pour les années d'expérience
  output$conditional_filters <- renderUI({
    req(input$filter_status)
    if (input$filter_status == config$demographics$status$labels$AO02) {
      selectInput(
        inputId = "filter_experience",
        label = "Années d'expérience",
        choices = c("Tous", config$demographics$experience$labels),
        selected = "Tous"
      )
    }
  })
  
  # Observer le bouton "Appliquer les filtres"
  observeEvent(input$apply_filters, {
    req(valid_id())
    req(survey_data())
    
    # Récupérer les filtres sélectionnés
    filters <- list()
    filters$status <- input$filter_status
    if (!is.null(input$filter_experience)) {
      filters$experience <- input$filter_experience
    }
    
    # Préparer les données en appliquant les filtres
    researcher_data <- prepare_researcher_data(
      data = survey_data(),
      config = config,
      filters = filters
    )
    
    if (is.null(researcher_data) || nrow(researcher_data) == 0) {
      showNotification("Aucune donnée ne correspond aux filtres sélectionnés.", type = "warning")
      output$researcher_table <- renderDT(NULL)
      output$researcher_plot <- renderPlot(NULL)
    } else {
      # Afficher le tableau avec les sous-scores et scores globaux
      output$researcher_table <- renderDT({
        datatable(researcher_data, options = list(pageLength = 10, autoWidth = TRUE))
      })
      
      # Créer un graphique des scores globaux
      output$researcher_plot <- renderPlot({
        data_long <- researcher_data %>%
          pivot_longer(
            cols = -c(person_id, timestamp),
            names_to = "scale",
            values_to = "score"
          )
        ggplot(data_long, aes(x = score)) +
          geom_histogram(binwidth = 0.5, fill = "blue", color = "white") +
          facet_wrap(~ scale, scales = "free") +
          theme_minimal() +
          labs(title = "Distribution des scores par échelle", x = "Score", y = "Fréquence")
      })
    }
  })
}