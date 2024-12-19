teacher_server <- function(input, output, session, survey_data, config) {
  # Données réactives de l'enseignant
  teacher_data <- reactive({
    req(survey_data())
    prepare_teacher_data(
      data = survey_data(),
      id_personnel = input$user_id,
      config = config
    )
  })
  
  # Interface de sélection d'échelle
  output$scaleSelector <- renderUI({
    req(teacher_data())
    selectInput(
      "selected_scale",
      "Échelle à visualiser :",
      choices = teacher_data()$metadata$available_scales,
      selected = teacher_data()$metadata$available_scales[1]
    )
  })
  
  # Interface dynamique des scores disponibles
  output$scoreSelector <- renderUI({
    req(teacher_data(), input$selected_scale)
    
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
    
    checkboxGroupInput(
      "selected_scores",
      "Scores à afficher :",
      choices = score_choices,
      selected = if ("total_score" %in% score_choices) "total_score" else NULL
    )
  })
  
  # Préparation des données pour la visualisation
  visualization_data <- reactive({
    req(teacher_data(), input$selected_scale, input$selected_scores)
    
    plot_data <- teacher_data()$stats %>%
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
    
    n_measurements <- length(unique(visualization_data()$period))
    
    if (n_measurements == 1) {
      # Graphique pour une seule mesure
      ggplot(visualization_data(), 
             aes(x = score_type, y = score_value, fill = measurement_type)) +
        geom_col(data = . %>% filter(measurement_type == "Score personnel"),
                 position = position_dodge()) +
        geom_hline(data = . %>% filter(measurement_type == "Moyenne du groupe"),
                   aes(yintercept = score_value, color = measurement_type),
                   linetype = "dashed", linewidth = 1) +
        scale_fill_manual(values = c("Score personnel" = "#2C3E50",
                                     "Moyenne du groupe" = "#E74C3C")) +
        scale_color_manual(values = c("Score personnel" = "#2C3E50",
                                      "Moyenne du groupe" = "#E74C3C")) +
        theme_minimal() +
        labs(
          title = sprintf("Scores pour l'échelle %s", input$selected_scale),
          x = "Type de score",
          y = "Valeur",
          fill = "Type de mesure",
          color = "Type de mesure"
        ) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    } else {
      # Graphique pour l'évolution temporelle
      ggplot(visualization_data(),
             aes(x = period, y = score_value, 
                 color = score_type, linetype = measurement_type)) +
        geom_line() +
        geom_point(data = . %>% filter(measurement_type == "Score personnel"),
                   size = 3) +
        theme_minimal() +
        labs(
          title = sprintf("Évolution des scores pour l'échelle %s", input$selected_scale),
          x = "Période",
          y = "Score",
          color = "Type de score",
          linetype = "Type de mesure"
        ) +
        scale_linetype_manual(values = c("Score personnel" = "solid",
                                         "Moyenne du groupe" = "dashed")) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    }
  })
  
  # Interface principale
  output$teacher_results <- renderUI({
    req(teacher_data())
    tagList(
      fluidRow(
        column(4, uiOutput("scaleSelector")),
        column(8, uiOutput("scoreSelector"))
      ),
      h3("Évolution de vos scores"),
      plotOutput("evolution_plot")
    )
  })
}