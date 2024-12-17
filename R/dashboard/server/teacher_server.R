teacher_server <- function(input, output, session, survey_data) {
  is_valid_id <- reactive({
    req(input$user_id)
    req(survey_data())
    input$user_id %in% survey_data()$g01q13
  })
  
  prepared_data <- reactive({
    req(is_valid_id())
    prepare_teacher_data(
      data = survey_data(), 
      id_personnel = input$user_id, 
      config = config
    )
  })
  
  output$scale_selector <- renderUI({
    req(prepared_data())
    scales <- names(prepared_data()$individual_scores)
    checkboxGroupInput(
      "selected_scales",
      "Sélectionner les échelles à visualiser:",
      choices = scales,
      selected = scales[1]
    )
  })
  
  output$personal_scores_plot <- renderPlot({
    req(prepared_data(), input$selected_scales)
    
    # Préparation des données individuelles
    individual_data <- map_dfr(input$selected_scales, function(scale) {
      prepared_data()$individual_scores[[scale]] %>%
        select(timestamp, total_score) %>%
        mutate(
          scale = scale,
          temps = dense_rank(timestamp),
          date = format(timestamp, "%d/%m/%Y"),
          type = "Score personnel"
        ) %>%
        arrange(timestamp) %>%
        mutate(
          label_temps = if(n() == 1) {
            "Mesure unique"
          } else {
            paste("Mesure", temps, "-", date)
          }
        )
    })
    
    # Utilisation des moyennes de groupe déjà calculées
    group_data <- map_dfr(input$selected_scales, function(scale) {
      prepared_data()$group_means[[scale]] %>%
        select(total_score) %>%
        mutate(
          scale = scale,
          type = "Moyenne du groupe"
        ) %>%
        crossing(
          timestamp = unique(individual_data$timestamp),
          temps = unique(individual_data$temps),
          label_temps = unique(individual_data$label_temps)
        )
    })
    
    # Combinaison des données
    plot_data <- bind_rows(individual_data, group_data)
    
    if(length(unique(plot_data$temps)) == 1) {
      # Graphique pour une seule mesure
      ggplot(plot_data, aes(x = scale, y = total_score, fill = type)) +
        geom_col(data = subset(plot_data, type == "Score personnel"), 
                 position = position_dodge()) +
        geom_hline(data = subset(plot_data, type == "Moyenne du groupe"),
                   aes(yintercept = total_score, color = type),
                   linetype = "dashed", linewidth = 1) +
        scale_fill_manual(values = c("Score personnel" = "#2C3E50", 
                                     "Moyenne du groupe" = "#E74C3C")) +
        scale_color_manual(values = c("Score personnel" = "#2C3E50", 
                                      "Moyenne du groupe" = "#E74C3C")) +
        theme_minimal() +
        labs(
          title = "Scores par échelle",
          subtitle = unique(plot_data$date),
          x = "Échelle",
          y = "Score"
        ) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    } else {
      # Graphique pour l'évolution temporelle
      ggplot(plot_data, aes(x = temps, y = total_score, group = interaction(scale, type))) +
        geom_line(aes(color = scale, linetype = type)) +
        geom_point(data = subset(plot_data, type == "Score personnel"),
                   aes(color = scale), size = 3) +
        theme_minimal() +
        labs(
          title = "Évolution des scores par échelle",
          x = "Temps de mesure",
          y = "Score",
          color = "Échelle",
          linetype = "Type de score"
        ) +
        scale_x_continuous(
          breaks = plot_data$temps,
          labels = plot_data$label_temps
        ) +
        scale_linetype_manual(values = c("Score personnel" = "solid",
                                         "Moyenne du groupe" = "dashed")) +
        scale_color_brewer(palette = "Set2") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    }
  })
  
  output$teacher_content <- renderUI({
    req(is_valid_id())
    tagList(
      uiOutput("scale_selector"),
      tabsetPanel(
        id = "teacherTabs",
        tabPanel(
          "Scores personnels",
          h3("Vos scores personnels"),
          plotOutput("personal_scores_plot")
        )
      )
    )
  })
}