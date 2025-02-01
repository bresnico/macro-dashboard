# work in progress
# labels des échelles
# calcul intégrée des items inversés
# ajout des interquartiles
# respect de la logique du script
# A temps perdu : check le yaml.
# check comment les groups.yml est utilisé
# regarde comment faire un score Z et le ranking dans le qmd... sur le csv existant

# initiation pour les tests
# config <- yaml::read_yaml("src/config/scales.yml")
# d <- readRDS("d.RDS")

# Préparation des données

prepare_data <- function(data_raw, config) {
  # Extraire les identifiants depuis la configuration
  personal_id_field <- config$identification$personal_id
  school_code_field <- config$identification$school_code
  team_code_field <- config$identification$team_code
  timestamp_field <- config$identification$timestamp$id
  timestamp_format <- config$identification$timestamp$format
  
  # Convertir le timestamp
  data_raw <- data_raw %>%
    mutate(
      person_id = .data[[personal_id_field]],
      school_code = .data[[school_code_field]],
      team_code = .data[[team_code_field]],
      timestamp = ymd_hms(.data[[timestamp_field]]),
      month = format(timestamp, "%B %Y")
    )
  
  return(data_raw)
}

calculate_theoretical_quartiles <- function(config) {
  scales <- names(config$scales)
  
  quartiles_list <- lapply(scales, function(scale_name) {
    scale_config <- config$scales[[scale_name]]
    
    # Obtenir les valeurs min et max de l'échelle
    scale_type <- scale_config$type
    min_value <- config$scale_types[[scale_type]]$min_value
    max_value <- config$scale_types[[scale_type]]$max_value
    
    # Calculer les quartiles théoriques
    Q1 <- min_value + (max_value - min_value) * 0.25
    Q2 <- min_value + (max_value - min_value) * 0.50
    Q3 <- min_value + (max_value - min_value) * 0.75
    
    # Retourner un data frame avec les valeurs
    data.frame(
      scale = scale_name,
      min_value = min_value,
      max_value = max_value,
      Q1 = Q1,
      Q2 = Q2,
      Q3 = Q3
    )
  })
  
  # Combiner les résultats en un seul data frame
  quartiles_df <- do.call(rbind, quartiles_list)
  
  return(quartiles_df)
}

# Calcul des scores pour une échelle

calculate_scale_scores <- function(data, scale_name, config) {
  scale_config <- config$scales[[scale_name]]
  
  # Récupérer les IDs des items
  item_ids <- sapply(scale_config$items, function(x) x$id)
  
  # Préfixe des réponses
  response_prefix <- scale_config$response_prefix
  
  # Extraire les données pertinentes
  scale_data <- data %>%
    select(person_id, timestamp, month, all_of(item_ids))
  
  # Obtenir les valeurs min et max de l'échelle
  scale_type <- scale_config$type
  min_value <- config$scale_types[[scale_type]]$min_value
  max_value <- config$scale_types[[scale_type]]$max_value
  
  # Traiter chaque item
  for (item in scale_config$items) {
    item_id <- item$id
    reversed <- item$reversed
    # Extraire la valeur numérique de la réponse
    # Suppression du préfixe et conversion en numérique
    scale_data[[item_id]] <- as.numeric(sub(response_prefix, "", scale_data[[item_id]]))
    # Inverser la valeur si nécessaire
    if (reversed) {
      scale_data[[item_id]] <- max_value + min_value - scale_data[[item_id]]
    }
  }
  
  # Calculer le score total si activé
  scores <- scale_data %>%
    select(person_id, timestamp, month)
  
  score_info_list <- list()  # Liste pour stocker les informations des scores
  
  if (isTRUE(scale_config$scoring$total$enabled)) {
    total_score_name <- "total_score"
    scores <- scores %>%
      mutate(
        !!total_score_name := rowMeans(scale_data[, item_ids, drop = FALSE], na.rm = TRUE)
      )
    # Ajouter les informations du score total
    score_info_list[[total_score_name]] <- list(
      score_label = "Score total",
      category = scale_config$scoring$total$category
    )
  }
  
  # Calculer les sous-scores
  if (!is.null(scale_config$scoring$subscales)) {
    for (subscale_name in names(scale_config$scoring$subscales)) {
      subscale_items <- scale_config$scoring$subscales[[subscale_name]]$items
      subscale_label <- scale_config$scoring$subscales[[subscale_name]]$label
      category <- scale_config$scoring$subscales[[subscale_name]]$category
      
      if (length(subscale_items) == 1) {
        # Si la sous-échelle n'a qu'un seul item, on prend directement la valeur de l'item
        scores[[subscale_name]] <- scale_data[[subscale_items]]
      } else {
        # Sinon, on calcule la moyenne
        scores[[subscale_name]] <- rowMeans(scale_data[, subscale_items, drop = FALSE], na.rm = TRUE)
      }
      
      # Ajouter les informations du sous-score
      score_info_list[[subscale_name]] <- list(
        score_label = subscale_label,
        category = category
      )
    }
  }
  
  # Transformer en format long
  scores_long <- scores %>%
    pivot_longer(
      cols = -c(person_id, timestamp, month),
      names_to = "score_name",
      values_to = "score_value"
    ) %>%
    mutate(
      scale = scale_name,
      scale_label = scale_config$label
    )
  
  # Convertir score_info_list en data frame
  score_info_df <- enframe(score_info_list, name = "score_name", value = "score_info") %>%
    unnest_wider(score_info)
  
  # Joindre les informations au data frame des scores
  scores_long <- scores_long %>%
    left_join(score_info_df, by = "score_name")
  
  return(scores_long)
}
# Compilation des scores pour toutes les échelles

compile_all_scores <- function(data, config) {
  scale_names <- names(config$scales)
  
  all_scores <- lapply(scale_names, function(scale_name) {
    calculate_scale_scores(data, scale_name, config)
  })
  
  all_scores_df <- bind_rows(all_scores)
  
  return(all_scores_df)
}

# Préparation des scores par établissement et équipes d'établissement

calculate_group_means <- function(all_scores) {
  # Calcul des moyennes par école
  school_means <- all_scores %>%
    group_by(school_code, scale, score_name) %>%
    summarize(school_mean = mean(score_value, na.rm = TRUE), .groups = "drop")
  
  # Calcul des moyennes par équipe (école + équipe)
  team_means <- all_scores %>%
    group_by(school_code, team_code, scale, score_name) %>%
    summarize(team_mean = mean(score_value, na.rm = TRUE), .groups = "drop")
  
  # Joindre les moyennes au data frame initial
  all_scores <- all_scores %>%
    left_join(school_means, by = c("school_code", "scale", "score_name")) %>%
    left_join(team_means, by = c("school_code", "team_code", "scale", "score_name"))
  
  return(all_scores)
}

# Fonction principale pour orchestrer le processus

process_data <- function(data_raw, config) {

  data_prepared <- prepare_data(data_raw, config)
  all_scores <- compile_all_scores(data_prepared, config)
  
  # Joindre les informations supplémentaires (school_code, team_code)
  all_scores <- all_scores %>%
    left_join(data_prepared %>% select(person_id, school_code, team_code), by = "person_id")
  
  # Calculer les moyennes par groupe
  all_scores <- calculate_group_means(all_scores)
  
  # Calculer les quartiles théoriques
  quartiles_df <- calculate_theoretical_quartiles(config)
  
  # Joindre les quartiles au data frame des scores
  all_scores <- all_scores %>%
    left_join(quartiles_df, by = "scale")
  
  # Déterminer la position du quartile pour chaque score et les moyennes de groupe
  all_scores <- all_scores %>%
    mutate(
      quartile_position = case_when(
        score_value <= Q1 ~ 1,
        score_value <= Q2 ~ 2,
        score_value <= Q3 ~ 3,
        score_value <= max_value ~ 4,
        TRUE ~ NA_real_
      ),
      school_quartile_position = case_when(
        school_mean <= Q1 ~ 1,
        school_mean <= Q2 ~ 2,
        school_mean <= Q3 ~ 3,
        school_mean <= max_value ~ 4,
        TRUE ~ NA_real_
      ),
      team_quartile_position = case_when(
        team_mean <= Q1 ~ 1,
        team_mean <= Q2 ~ 2,
        team_mean <= Q3 ~ 3,
        team_mean <= max_value ~ 4,
        TRUE ~ NA_real_
      )
    )
  
  # Réorganiser les colonnes pour une meilleure lisibilité
  all_scores <- all_scores %>%
    select(person_id, timestamp, month, school_code, team_code,
           scale, scale_label, score_name, score_label, category,
           score_value, quartile_position,
           school_mean, school_quartile_position,
           team_mean, team_quartile_position,
           Q1, Q2, Q3, min_value, max_value,
           everything())
  
  return(all_scores)
}
