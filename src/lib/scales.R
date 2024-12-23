prepare_numeric_responses <- function(data, scale_name, config) {
  scale_config <- config$scales[[scale_name]]
  item_ids <- sapply(scale_config$items, function(x) x$id)
  
  # Convertir les réponses de format "AO01" en numériques
  data <- data %>%
    mutate(across(all_of(item_ids), 
                  ~as.numeric(sub(scale_config$response_prefix, "", .x))))
  
  return(data)
}

process_single_scale <- function(data, scale_name, config, debug = TRUE) {
  if(debug) cat("\nTraitement de l'échelle:", scale_name, "\n")
  
  # Préparation numérique avant tout traitement
  data <- prepare_numeric_responses(data, scale_name, config)
  
  # Extraction de la configuration de l'échelle
  scale_config <- config$scales[[scale_name]]
  # Extraction des IDs des items
  item_ids <- sapply(scale_config$items, function(x) x$id)
  
  if(debug) {
    cat("Items de l'échelle:\n")
    print(item_ids)
  }
  
  # Préparation initiale des données avec calcul des scores
  scores_data <- data %>%
    mutate(
      person_id = g01q13,
      group_id = groupecode,
      timestamp = ymd_hms(datestamp),
      month = floor_date(timestamp, "month")
    ) %>%
    select(timestamp, month, person_id, group_id, all_of(item_ids))
  
  # Calcul des scores individuels
  if(scale_config$scoring$total) {
    scores_data <- scores_data %>%
      rowwise() %>%
      mutate(
        total_score = mean(c_across(all_of(item_ids)), na.rm = TRUE)
      ) %>%
      ungroup()
  }
  
  if(!is.null(scale_config$scoring$subscales)) {
    for(subscale_name in names(scale_config$scoring$subscales)) {
      subscale_items <- scale_config$scoring$subscales[[subscale_name]]$items
      scores_data <- scores_data %>%
        rowwise() %>%
        mutate(
          !!subscale_name := mean(c_across(all_of(subscale_items)), na.rm = TRUE)
        ) %>%
        ungroup()
    }
  }
  
  # Identification des colonnes de scores
  score_columns <- setdiff(names(scores_data), 
                           c("timestamp", "month", "person_id", "group_id", item_ids))
  
  # Préparation du format long avec scores de référence
  scores_long <- scores_data %>%
    select(timestamp, month, person_id, group_id, all_of(score_columns)) %>%
    pivot_longer(
      cols = all_of(score_columns),
      names_to = "score_type",
      values_to = "score_value"
    ) %>%
    # Ajout des scores de référence par groupe et par mois
    group_by(group_id, month, score_type) %>%
    mutate(
      reference_value = mean(score_value, na.rm = TRUE),
      reference_sd = sd(score_value, na.rm = TRUE),
      quartile = ntile(score_value, 4),  # Calcul du quartile
      scale = scale_name,
      n_group = n()
    ) %>%
    ungroup()
  
  if(debug) {
    cat("\nNombre d'observations:", nrow(scores_long))
    cat("\nNombre de groupes uniques:", n_distinct(scores_long$group_id))
    cat("\nPremières lignes du résultat:\n")
    print(head(scores_long))
  }
  
  return(scores_long)
}


prepare_all_scales_scores <- function(data, config, debug = FALSE) {
  scale_names <- names(config$scales)
  
  # Préparation des labels
  scale_labels <- map_dfr(scale_names, function(scale_name) {
    scale_config <- config$scales[[scale_name]]
    
    # Labels des sous-scores
    subscore_labels <- NULL
    if(!is.null(scale_config$scoring$subscales)) {
      subscore_labels <- map_dfr(names(scale_config$scoring$subscales), function(subscale_name) {
        label <- scale_config$scoring$subscales[[subscale_name]]$label  # Correction ici!
        tibble(
          scale = scale_name,
          scale_label = scale_config$label,
          score_type = subscale_name,
          score_type_label = label
        )
      })
    }
    
    # Label du score total
    total_label <- NULL
    if(isTRUE(scale_config$scoring$total)) {
      total_label <- tibble(
        scale = scale_name,
        scale_label = scale_config$label,
        score_type = "total_score",
        score_type_label = "Score global"
      )
    }
    
    bind_rows(subscore_labels, total_label)
  })
  
  # Reste de la fonction inchangé...
  all_scores <- map_dfr(scale_names, ~process_single_scale(data, .x, config, debug = debug))
  
  final_scores <- all_scores %>%
    left_join(scale_labels, by = c("scale", "score_type")) %>%
    arrange(timestamp, group_id, person_id, scale, score_type) %>%
    select(
      timestamp,
      month,
      person_id,
      group_id,
      scale,
      scale_label,
      score_type,
      score_type_label,
      score_value,
      reference_value,
      reference_sd,    # Nouvelle colonne
      quartile,
      n_group
    )
  
  # Transformation finale pour assurer des types corrects
  final_scores <- final_scores %>%
    mutate(
      # Dates
      timestamp = as.Date(timestamp),
      month = format(month, "%B %Y"),
      
      # S'assurer que tous les scores sont numériques
      across(c(score_value, reference_value, reference_sd), 
             ~as.numeric(.x)),
      
      # Quartile doit être un entier
      quartile = as.integer(quartile),
      
      # S'assurer que n_group est un entier
      n_group = as.integer(n_group)
    )
  
  return(final_scores)
}
