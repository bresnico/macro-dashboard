director_server <- function(input, output, session, survey_data, config) {
  # Validation du code groupe avec prise en compte du groupe "divers"
  is_valid_group <- reactive({
    req(input$user_id)
    req(survey_data())
    
    # Considérer soit le groupe spécifique, soit "divers"
    input$user_id == "divers" || input$user_id %in% survey_data()$groupecode
  })
  
  # Préparation des données avec gestion spéciale pour "divers"
  director_data <- reactive({
    req(is_valid_group())
    
    # Appel à la fonction modifiée dans functions.R
    prepare_director_data(
      data = survey_data(),
      code_groupe = input$user_id,
      config = config
    )
  })
  
  # Générer le checkboxGroupInput via renderUI
  output$scaleCheckboxes <- renderUI({
    checkboxGroupInput(
      "selected_scales",
      "Échelles à visualiser :",
      choices = names(config$scales)  # Accès direct aux échelles
    )
  })
  
  # Graphique d'évolution
  output$evolution_plot <- renderPlot({
    req(director_data(), input$selected_scales)
    
    plot_data <- director_data()$stats %>%
      filter(scale %in% input$selected_scales)
    
    if (nrow(plot_data) == 0) return(NULL)
    
    ggplot(plot_data, aes(x = period, y = mean_group, color = group_type)) +
      geom_line() +
      geom_point(aes(size = n_group)) +
      scale_size_continuous(name = "Nombre de réponses") +
      labs(
        title = paste("Évolution des scores pour le groupe", input$user_id),
        x = "Période",
        y = "Score moyen",
        color = "Type de groupe"
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
    
    if (nrow(table_data) == 0) return(NULL)
    
    table_data %>%
      select(
        "Période" = period,
        "Type de groupe" = group_type,
        "Échelle" = scale,
        "N observations" = n_group,
        "Score moyen" = mean_group
      ) %>%
      arrange(Période, Échelle, `Type de groupe`) %>%
      mutate(
        Période = format(Période, "%B %Y"),
        `Score moyen` = round(`Score moyen`, 2)
      )
  })
}