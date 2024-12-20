# Enseignant

prepare_teacher_data <- function(data, id_personnel, config) {
  # La validation initiale et la gestion du code groupe restent identiques
  if (!id_personnel %in% data$g01q13) {
    stop("ID personnel non trouvé")
  }
  
  individual_data <- data %>%
    filter(g01q13 == id_personnel)
  
  code_groupe <- individual_data$groupecode[1]
  if (is.na(code_groupe) || code_groupe == "") {
    code_groupe <- "divers"
  }
  
  scale_stats <- map_dfr(names(config$scales), function(scale_name) {
    individual_scores <- calculate_scale_scores(individual_data, scale_name, config)
    
    if (is.null(individual_scores) || nrow(individual_scores) == 0) {
      return(NULL)
    }
    
    score_columns <- setdiff(names(individual_scores), 
                           c("timestamp", "group_id", "person_id"))
    
    if (length(score_columns) == 0) {
      return(NULL)
    }
    
    # Transformation des scores individuels (inchangée)
    scores_long <- individual_scores %>%
      pivot_longer(
        cols = all_of(score_columns),
        names_to = "score_type",
        values_to = "score_value"
      ) %>%
      mutate(
        period = timestamp,
        scale = scale_name,
        measurement_type = "Score personnel"
      )
    
    # Préparation des moyennes de groupe avec correspondance temporelle
    group_data <- data %>%
      filter(groupecode == code_groupe)
    group_scores <- calculate_scale_scores(group_data, scale_name, config)
    
    if (!is.null(group_scores)) {
      # Identification des mois uniques où l'individu a des mesures
      individual_months <- scores_long %>%
        mutate(month = floor_date(period, "month")) %>%
        pull(month) %>%
        unique()
      
      # Calcul des moyennes de groupe pour chaque mois pertinent
      group_scores_long <- group_scores %>%
        pivot_longer(
          cols = all_of(score_columns),
          names_to = "score_type",
          values_to = "score_value"
        ) %>%
        mutate(month = floor_date(timestamp, "month")) %>%
        # Filtrer pour ne garder que les mois où l'individu a des mesures
        filter(month %in% individual_months) %>%
        group_by(month, scale = scale_name, score_type) %>%
        summarise(
          score_value = mean(score_value, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        mutate(
          period = month,
          measurement_type = "Moyenne du groupe"
        ) %>%
        select(-month)  # Nettoyage de la colonne temporaire
      
      # Combinaison des scores
      scores_long <- bind_rows(scores_long, group_scores_long)
    }
    
    return(scores_long)
  })
  
  # La structure des résultats reste identique
  results <- list(
    code_groupe = code_groupe,
    stats = scale_stats,
    metadata = list(
      available_scales = unique(scale_stats$scale),
      available_score_types = unique(scale_stats$score_type),
      date_range = range(scale_stats$period),
      total_measurements = nrow(scale_stats[scale_stats$measurement_type == "Score personnel", ])
    )
  )
  
  return(results)
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
    
    # Identification des colonnes de scores (tout sauf timestamp, group_id, person_id)
    score_columns <- setdiff(names(scores), c("timestamp", "group_id", "person_id"))
    
    if (length(score_columns) == 0) {
      return(NULL)
    }
    
    # Transformation en format long pour traiter tous les types de scores
    scores_long <- scores %>%
      pivot_longer(
        cols = all_of(score_columns),
        names_to = "score_type",
        values_to = "score_value"
      ) %>%
      mutate(
        period = floor_date(timestamp, "month"),
        scale = scale_name
      )
    
    # Statistiques pour le groupe sélectionné
    group_stats <- scores_long %>%
      filter(group_id == code_groupe) %>%
      group_by(period, scale, score_type) %>%
      summarise(
        n_group = n(),
        mean_group = mean(score_value, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(group_type = "Groupe sélectionné")
    
    # Statistiques pour tous les groupes
    overall_stats <- scores_long %>%
      group_by(period, scale, score_type) %>%
      summarise(
        n_group = n(),
        mean_group = mean(score_value, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(group_type = "Tous les groupes")
    
    # Combiner les statistiques
    combined_stats <- bind_rows(group_stats, overall_stats)
    return(combined_stats)
  })
  
  # Structure des résultats avec métadonnées enrichies
  results <- list(
    code_groupe = code_groupe,
    stats = scale_stats,
    metadata = list(
      available_scales = unique(scale_stats$scale),
      available_score_types = unique(scale_stats$score_type),
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