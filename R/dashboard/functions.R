# Enseignant

prepare_teacher_data <- function(data, id_personnel, config) {
  if (!id_personnel %in% data$g01q13) {
    stop("ID personnel non trouvé")
  }
  
  individual_data <- data %>%
    filter(g01q13 == id_personnel) %>%
    arrange(timestamp)
  
  code_groupe <- individual_data$groupecode[1]
  if (is.na(code_groupe) || code_groupe == "") {
    code_groupe <- "divers"
  }
  
  individual_scores <- list()
  for (scale_name in names(config$scales)) {
    # Nouvelle section : vérification de la validité des données
    scale_items <- sapply(config$scales[[scale_name]]$items, function(x) x$id)
    scale_data <- individual_data[scale_items]
    
    # On calcule le taux de réponses valides
    response_rate <- sum(!is.na(scale_data)) / length(scale_items)
    if (response_rate >= config$validation$min_responses[[scale_name]]) {
      scores <- calculate_scale_scores(individual_data, scale_name, config)
      if (!is.null(scores) && any(!is.na(scores$total_score))) {
        individual_scores[[scale_name]] <- scores
      }
    }
  }
  
  group_data <- data %>%
    filter(groupecode == code_groupe)
  
  group_means <- list()
  for (scale_name in names(individual_scores)) {  # Modification ici pour n'utiliser que les échelles valides
    scores <- calculate_scale_scores(group_data, scale_name, config)
    group_mean <- scores %>%
      summarise(across(where(is.numeric), ~ mean(., na.rm = TRUE)))
    group_means[[scale_name]] <- group_mean
  }
  
  individual_evolution <- list()
  for (scale_name in names(individual_scores)) {  # Modification ici aussi
    scores <- individual_scores[[scale_name]]
    individual_evolution[[scale_name]] <- scores %>%
      arrange(timestamp)
  }
  
  result <- list(
    individual_scores = individual_scores,
    group_means = group_means,
    individual_evolution = individual_evolution,
    code_groupe = code_groupe
  )
  
  return(result)
}

# Directeur

prepare_director_data <- function(data, code_groupe, config) {
  # Validation du code groupe
  possible_groups <- unique(data$groupecode)
  if (!code_groupe %in% possible_groups && code_groupe != "divers") {
    stop("Code groupe non trouvé")
  }
  
  # Gestion spéciale pour le groupe "divers"
  data <- data %>%
    mutate(groupecode = ifelse(is.na(groupecode) | groupecode == "", "divers", groupecode))
  
  # Préparation des statistiques pour chaque échelle
  scale_stats <- map_dfr(names(config$scales), function(scale_name) {
    # Calcul des scores pour l'échelle
    scores <- calculate_scale_scores(data, scale_name, config)
    
    if (is.null(scores) || nrow(scores) == 0) {
      return(NULL)
    }
    
    # Ajout de l'information de groupe
    scores <- scores %>%
      mutate(group_id = data$groupecode)
    
    # Transformation des timestamps en période mensuelle
    scores <- scores %>%
      mutate(period = floor_date(timestamp, "month"))
    
    # Statistiques pour le groupe sélectionné
    group_stats <- scores %>%
      filter(group_id == code_groupe) %>%
      group_by(period, scale = scale_name) %>%
      summarise(
        n_group = n(),
        mean_group = mean(total_score, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(group_type = "Groupe sélectionné")
    
    # Statistiques pour tous les groupes
    overall_stats <- scores %>%
      group_by(period, scale = scale_name) %>%
      summarise(
        n_group = n(),
        mean_group = mean(total_score, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(group_type = "Tous les groupes")
    
    # Combiner les statistiques
    combined_stats <- bind_rows(group_stats, overall_stats)
    return(combined_stats)
  })
  
  # Structure des résultats
  results <- list(
    code_groupe = code_groupe,
    stats = scale_stats,
    metadata = list(
      available_scales = unique(scale_stats$scale),
      date_range = range(scale_stats$period),
      total_observations = nrow(data)
    )
  )
  
  return(results)
}

# Chercheur

# R/functions.R

prepare_researcher_data <- function(data, config, filters = list()) {
  data_filtered <- data
  if (length(filters) > 0) {
    for (filter_name in names(filters)) {
      filter_value <- filters[[filter_name]]
      if (filter_value != "Tous") {
        data_filtered <- data_filtered %>%
          filter(.data[[filter_name]] == filter_value)
      }
    }
  }
  
  if (nrow(data_filtered) == 0) {
    return(NULL)
  }
  
  # Exemple de calcul de score pour l'échelle "via"
  via_items <- grep("^G02Q03_SQ", names(data_filtered), value = TRUE)
  
  scores_df <- data_filtered %>%
    mutate(
      via_score = rowMeans(select(., all_of(via_items)), na.rm = TRUE)
      # Ajouter les calculs pour les autres échelles si nécessaire
    ) %>%
    select(g01q13, timestamp, via_score)
  
  return(scores_df)
}