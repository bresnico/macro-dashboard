prepare_global_summary <- function(data, config) {
  data %>%
    summarise(
      total_observations = n(),
      complete_observations = sum(!is.na(submitdate)),
      nb_groups = n_distinct(groupecode),
      last_update = max(submitdate, na.rm = TRUE)
    ) %>%
    mutate(
      scales_available = list(names(config$scales))
    )
}

prepare_teacher_scores <- function(data, config) {
  map_dfr(names(config$scales), function(scale_name) {
    scores <- calculate_scale_scores(data, scale_name, config)
    if (is.null(scores)) return(NULL)
    
    scores %>% 
      select(
        teacher_id = person_id,
        group_id,
        timestamp,
        everything()
      )
  })
}

prepare_metadata <- function(config) {
  map_dfr(names(config$scales), function(scale_name) {
    scale_config <- config$scales[[scale_name]]
    tibble(
      scale_id = scale_name,
      has_total = !is.null(scale_config$scoring$total) && scale_config$scoring$total,
      subscales = list(names(scale_config$scoring$subscales))
    )
  })
}

# Fonction principale pour générer tous les fichiers
export_dashboard_data <- function(survey_id, config, data_dir = "data") {
  # Création du dossier si nécessaire
  dir.create(data_dir, showWarnings = FALSE)
  
  # Préparation de la configuration
  
  setup_limesurvey_connection()
  
  # Récupération et traitement des données
  data <- get_limesurvey_data(survey_id, config) %>%
    standardize_limesurvey_names(config) %>%
    convert_responses(config) %>%
    mutate(
      submitdate = ymd_hms(submitdate),
      startdate = ymd_hms(startdate),
      datestamp = ymd_hms(datestamp),
      timestamp = submitdate
    )
  
  # Génération et export des fichiers
  write_csv(
    prepare_global_summary(data, config),
    file.path(data_dir, "global_summary.csv")
  )
  
  write_csv(
    prepare_teacher_scores(data, config),
    file.path(data_dir, "teacher_scores.csv")
  )
  
  write_csv(
    prepare_metadata(config),
    file.path(data_dir, "metadata.csv")
  )
}