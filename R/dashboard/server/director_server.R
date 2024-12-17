director_server <- function(input, output, session, survey_data, config) {
  # Préparer les données pour le directeur (par groupecode)
  director_data <- reactive({
    req(survey_data())
    # Filtrer les données en fonction de l'ID du directeur (groupecode)
    data_filtered <- survey_data() %>%
      filter(groupecode == input$user_id)
    
    # Afficher une notification si aucune donnée n'est disponible
    if (nrow(data_filtered) == 0) {
      showNotification("Aucune donnée disponible pour cet identifiant.", type = "warning")
      return(NULL)
    }
    
    # Appeler la fonction pour préparer les données du directeur
    prepare_director_data(
      data = data_filtered,
      code_groupe = input$user_id,
      config = config
    )
  })
  
  # Générer le checkboxGroupInput via renderUI
  output$scaleCheckboxes <- renderUI({
    req(director_data())
    checkboxGroupInput(
      "selected_scales",
      "Échelles à visualiser :",
      choices = names(config$scales),  # Accès direct aux échelles
      selected = names(config$scales)[1]
    )
  })
  
  # Graphique d'évolution
  output$evolution_plot <- renderPlot({
    req(director_data(), input$selected_scales)
    
    plot_data <- director_data()$stats %>%
      filter(scale %in% input$selected_scales)
    
    if (nrow(plot_data) == 0) {
      showNotification("Aucune donnée à afficher pour les échelles sélectionnées.", type = "warning")
      return(NULL)
    }
    
    ggplot(plot_data, aes(x = period, y = mean_group, color = scale)) +
      geom_line() +
      geom_point(aes(size = n_group)) +
      scale_size_continuous(name = "Nombre de réponses") +
      labs(
        title = paste("Évolution des scores pour le groupe", input$user_id),
        x = "Période",
        y = "Score moyen",
        color = "Échelle"
      ) +
      theme_minimal() +
      theme(
        legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
  })
  
  # Tableau récapitulatif
  output$stats_table <- renderTable({
    req(director_data(), input$selected_scales)
    
    table_data <- director_data()$stats %>%
      filter(scale %in% input$selected_scales)
    
    if (nrow(table_data) == 0) {
      showNotification("Aucune donnée disponible pour le tableau.", type = "warning")
      return(NULL)
    }
    
    table_data %>%
      select(
        "Période" = period,
        "Échelle" = scale,
        "Type de groupe" = group_type,
        "N observations" = n_group,
        "Score moyen" = mean_group
      ) %>%
      arrange(Période, Échelle, `Type de groupe`) %>%
      mutate(
        Période = format(Période, "%B %Y"),
        `Score moyen` = round(`Score moyen`, 2)
      )
  })
  
  # Contenu principal pour le directeur
  output$director_results <- renderUI({
    req(director_data())
    tagList(
      uiOutput("scaleCheckboxes"),
      h3("Graphique d'évolution des scores"),
      plotOutput("evolution_plot"),
      h3("Tableau récapitulatif"),
      tableOutput("stats_table")
    )
  })
}