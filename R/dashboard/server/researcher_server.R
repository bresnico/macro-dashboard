# R/server/researcher_server.R

researcher_server <- function(input, output, session, survey_data) {
  
  # Chargement des codes chercheurs depuis credentials.yml
  credentials <- yaml::read_yaml("config/credentials.yml")
  valid_researcher_codes <- credentials$researcher_codes
  
  # Reactive pour vérifier si le code chercheur est valide
  is_valid_researcher <- reactive({
    req(input$user_id)
    input$user_id %in% valid_researcher_codes
  })
  
  # Message d'erreur si le code chercheur est invalide
  output$researcher_error <- renderUI({
    req(input$user_id)
    
    if(!is_valid_researcher()) {
      div(
        class = "alert alert-danger",
        "Code chercheur invalide."
      )
    }
  })
  
  # Contenu principal pour code chercheur valide
  output$researcher_content <- renderUI({
    req(is_valid_researcher())
    
    tagList(
      h3("Analyse des données"),
      
      # Graphiques ou analyses à venir
      tabsetPanel(
        id = "researcherTabs",
        tabPanel(
          "Scores par échelle",
          plotOutput("researcher_scores_plot")
        ),
        tabPanel(
          "Évolution des scores",
          plotOutput("researcher_evolution_plot")
        )
        # Ajouter d'autres analyses si nécessaire
      )
    )
  })
  
  # Calcul des scores sur l'ensemble des données
  researcher_scores <- reactive({
    req(is_valid_researcher())
    req(survey_data())
    
    scores <- list()
    for (scale_name in names(config$scales)) {
      score <- calculate_scale_scores(survey_data(), scale_name, config)
      if (!is.null(score)) {
        scores[[scale_name]] <- score
      }
    }
    scores
  })
  
  # 1. Affichage des scores moyens par échelle
  output$researcher_scores_plot <- renderPlot({
    req(researcher_scores())
    
    # Préparation des données pour le graphique
    scores_df <- bind_rows(researcher_scores(), .id = "scale") %>%
      group_by(scale) %>%
      summarise(mean_score = mean(total_score, na.rm = TRUE))
    
    # Création du graphique
    ggplot(scores_df, aes(x = scale, y = mean_score, fill = scale)) +
      geom_bar(stat = "identity", show.legend = FALSE) +
      labs(title = "Scores moyens par échelle",
           x = "Échelle",
           y = "Score moyen") +
      theme_minimal()
  })
  
  # 2. Affichage de l'évolution des scores
  output$researcher_evolution_plot <- renderPlot({
    req(researcher_scores())
    
    # Préparation des données pour le graphique
    evolution_df <- bind_rows(researcher_scores(), .id = "scale") %>%
      group_by(scale, timestamp) %>%
      summarise(mean_score = mean(total_score, na.rm = TRUE))
    
    # Création du graphique
    ggplot(evolution_df, aes(x = timestamp, y = mean_score, color = scale)) +
      geom_line() +
      geom_point() +
      labs(title = "Évolution des scores dans le temps",
           x = "Date",
           y = "Score moyen",
           color = "Échelle") +
      theme_minimal()
  })
}