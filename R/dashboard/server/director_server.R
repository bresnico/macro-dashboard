director_server <- function(input, output, session, survey_data, config) {
  # Données réactives du directeur
  director_data <- reactive({
    req(survey_data())
    data_filtered <- survey_data() %>%
      filter(groupecode == input$user_id)
    
    if (nrow(data_filtered) == 0) {
      showNotification("Aucune donnée disponible pour cet identifiant.", type = "warning")
      return(NULL)
    }
    
    prepare_director_data(
      data = data_filtered,
      code_groupe = input$user_id,
      config = config
    )
  })
  
  # Interface de sélection d'échelle
  output$scaleSelector <- renderUI({
    req(director_data())
    selectInput(
      "selected_scale",  # Notez le singulier
      "Échelle à visualiser :",
      choices = director_data()$metadata$available_scales,
      selected = director_data()$metadata$available_scales[1]
    )
  })
  
  # Interface dynamique des scores disponibles
  output$scoreSelector <- renderUI({
    req(director_data(), input$selected_scale)
    
    # Obtenir la configuration de l'échelle sélectionnée
    scale_config <- config$scales[[input$selected_scale]]
    
    # Préparer les choix de scores
    score_choices <- c()
    if (isTRUE(scale_config$scoring$total)) {
      score_choices <- c(score_choices, "Score global" = "total_score")
    }
    
    if (!is.null(scale_config$scoring$subscales)) {
      subscore_choices <- setNames(
        names(scale_config$scoring$subscales),
        paste("Sous-score:", names(scale_config$scoring$subscales))
      )
      score_choices <- c(score_choices, subscore_choices)
    }
    
    # Création du widget de sélection des scores
    checkboxGroupInput(
      "selected_scores",
      "Scores à afficher :",
      choices = score_choices,
      selected = if ("total" %in% score_choices) "total" else NULL
    )
  })
  
  # Préparation des données pour la visualisation
  visualization_data <- reactive({
    req(director_data(), input$selected_scale, input$selected_scores)
    
    plot_data <- director_data()$stats %>%
      filter(
        scale == input$selected_scale,
        score_type %in% input$selected_scores
      )
    
    if (nrow(plot_data) == 0) {
      showNotification("Aucune donnée à afficher pour la sélection actuelle.", type = "warning")
      return(NULL)
    }
    
    plot_data
  })
  
  # Graphique d'évolution
  output$evolution_plot <- renderPlot({
    req(visualization_data())
    
    ggplot(visualization_data(), 
           aes(x = period, y = mean_group, color = score_type)) +
      geom_line(aes(linetype = group_type)) +
      geom_point(aes(size = n_group)) +
      scale_size_continuous(name = "Nombre de réponses") +
      labs(
        title = sprintf("Évolution des scores de l'échelle %s pour le groupe %s",
                        input$selected_scale,
                        input$user_id),
        x = "Période",
        y = "Score moyen",
        color = "Type de score",
        linetype = "Type de groupe"
      ) +
      theme_minimal() +
      theme(
        legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
  })
  
  # Interface principale
  output$director_results <- renderUI({
    req(director_data())
    tagList(
      fluidRow(
        column(4, uiOutput("scaleSelector")),
        column(8, uiOutput("scoreSelector"))
      ),
      h3("Graphique d'évolution des scores"),
      plotOutput("evolution_plot"),
      h3("Tableau récapitulatif"),
      tableOutput("stats_table")
    )
  })
}