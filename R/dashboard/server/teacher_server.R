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
  
# Préparation des données pour la visualisation (inchangé)
visualization_data <- reactive({
  req(teacher_data(), input$selected_scale, input$selected_scores)
  
  plot_data <- teacher_data()$stats %>%
    filter(
      scale == input$selected_scale,
      score_type %in% input$selected_scores
    ) |> 
    mutate(
      # Pour les mesures individuelles: garder la date exacte
      period = if_else(
        measurement_type == "Score personnel",
        as.Date(period),
        # Pour les moyennes de groupe: premier jour du mois
        floor_date(period, "month") %>% as.Date()
      )
    )
  
# Débogage
  cat("Structure des données de visualisation :\n")
  str(plot_data)
  
  cat("\nRésumé des dates par type de mesure :\n")
  print(plot_data %>%
    group_by(measurement_type) %>%
    summarise(
      n_obs = n(),
      min_date = min(period),
      max_date = max(period)
    ))

  if (nrow(plot_data) == 0) {
    showNotification("Aucune donnée à afficher pour la sélection actuelle.", type = "warning")
    return(NULL)
  }
  
  plot_data
})

# Graphique d'évolution
output$evolution_plot <- renderPlot({
  req(visualization_data())
  
  # Séparation des données
  individual_data <- visualization_data() %>%
    filter(measurement_type == "Score personnel")
  
  group_data <- visualization_data() %>%
    filter(measurement_type == "Moyenne du groupe")
  
  # Analyse temporelle
  dates_individuelles <- sort(unique(individual_data$period))
  n_measurements <- length(dates_individuelles)

  cat("individual data period:")
  print(individual_data$period)
  
  if (n_measurements == 1) {
    # Code pour une seule mesure (inchangé)
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
     # Commencer par établir la base du graphique avec les données individuelles
    ggplot() +
      # Tracer les données individuelles
      geom_line(data = individual_data, aes(x = period, y = score_value, color = score_type), linewidth = 0.8) +
      geom_point(data = individual_data, aes(x = period, y = score_value, color = score_type), size = 3) +
      # Ajouter les données du groupe (1 point par mois avec la moyenne du groupe)
      geom_point(data = group_data, aes(x = period, y = score_value, color = score_type), size = 5, shape = 24) +
      #geom_hline(data = group_data, aes(yintercept = score_value, color = score_type), linetype = "dashed", alpha = 0.5) +
      # Personnalisation
      scale_color_brewer(palette = "Set2") +
      theme_minimal() +
      labs(
        title = sprintf("Évolution des scores pour l'échelle %s", input$selected_scale),
        subtitle = sprintf("Moyenne du groupe en %s", format(unique(group_data$period), "%B %Y")),
        x = "Période",
        y = "Score",
        color = "Type de score"
      ) +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom",
        panel.grid.minor = element_blank()
      )
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