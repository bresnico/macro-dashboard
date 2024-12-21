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
  
  cat("Stats disponibles entrantes:\n")
  print(str(teacher_data()$stats))
  
  individual_data <- teacher_data()$stats %>%
    filter(
      scale == input$selected_scale,
      score_type %in% input$selected_scores,
      measurement_type == "Score personnel"
    ) %>%
    mutate(period = as.Date(period))
  
  cat("\nDonnées individuelles après filtrage en sortie:\n")
  print(str(individual_data))
  
  # Les moyennes de groupe sans date spécifique
  group_data <- teacher_data()$stats %>%
    filter(
      scale == input$selected_scale,
      score_type %in% input$selected_scores,
      measurement_type == "Moyenne du groupe"
    ) %>%
    select(score_type, score_value)  # On ne garde que le score, pas de date
  
  cat("\nDonnées de groupe après filtrage en sortie:\n")
  print(str(group_data))
  
  list(
    individual = individual_data,
    group = group_data
  )
})

# Graphique d'évolution
output$evolution_plot <- renderPlot({
  req(visualization_data())
  
  data <- visualization_data()
  n_measurements <- length(unique(data$individual$period))
  
  
  if (n_measurements == 0) {
    showNotification("Aucune donnée à afficher pour la sélection actuelle.", type = "warning")
    return(NULL)
  } else if (n_measurements == 1) {
    # Code pour une seule mesure
      ggplot()+
      geom_col(data = data$individual,
               aes(x = score_type,
                   y = score_value,
                   label = score_value,
                   color = score_type,
                   fill = score_type,
                   ),
               position = position_dodge()
               ) +
      geom_hline(data = data$group,
                 aes(yintercept = score_value,
                     color = score_type
                     ),
                 linetype = "dashed", linewidth = 1) +
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
    # Construction du graphique de base avec les données individuelles
    p <- ggplot() +
      # D'abord les lignes de référence des moyennes de groupe
      geom_hline(data = data$group,
                 aes(yintercept = score_value, color = score_type),
                 linetype = "dashed", 
                 alpha = 0.5) +
      # Ensuite les données individuelles 
      geom_line(data = data$individual,
                aes(x = period, y = score_value, color = score_type),
                linewidth = 0.8) +
      geom_point(data = data$individual, 
                 aes(x = period, y = score_value, color = score_type),
                 size = 3) +
      # Configuration de l'échelle temporelle automatique basée sur les dates individuelles
      scale_x_date(
        date_breaks = "1 day",
        date_labels = "%d %b",
        expand = expansion(mult = c(0.05, 0.05))
      ) +
      # Personnalisation
      scale_color_brewer(palette = "Set2") +
      theme_minimal() +
      labs(
        title = sprintf("Évolution des scores pour l'échelle %s", input$selected_scale),
        subtitle = format(unique(floor_date(data$individual$period[1], "month")), "Moyenne du groupe en %B %Y"),
        x = "Période",
        y = "Score",
        color = "Type de score"
      ) +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom", 
        panel.grid.minor = element_blank()
      )
    
    p
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