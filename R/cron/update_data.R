# Point d'entrée pour la mise à jour des données
source("R/core/0_config.R")
source("R/core/1_data_processing.R")
source("R/core/2_prepare_data.R")

# Chargement config
config <- yaml::read_yaml("config/scales_definition.yml")
survey_id <- "637555"
# Préparation de l'environnement
setup_limesurvey_connection()

data <- get_limesurvey_data(survey_id, config) |> 
  convert_responses(config)

process_single_scale <- function(data, scale_name, config, debug = TRUE) {
  if(debug) cat("\nTraitement de l'échelle:", scale_name, "\n")
  
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

#test

test <- process_single_scale(data, "tses", config, debug = TRUE)

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
  
  return(final_scores)
}

# Test
scores_complet <- prepare_all_scales_scores(data, config, debug = TRUE)


# Test de la fonction
scores_complet <- prepare_all_scales_scores(data, config, debug = TRUE)


write_csv2(scores_complet, "data/scores_complet.csv", na = "NA")

scores_complet |> 
  filter(scale == "tses")


debug_labels <- function(config) {
  scale_names <- names(config$scales)
  
  scale_labels <- map_dfr(scale_names, function(scale_name) {
    scale_config <- config$scales[[scale_name]]
    
    # Labels des sous-scores
    subscore_labels <- NULL
    if(!is.null(scale_config$scoring$subscales)) {
      subscore_labels <- map_dfr(names(scale_config$scoring$subscales), function(subscale_name) {
        tibble(
          scale = scale_name,
          score_type = subscale_name,
          score_type_label = scale_config$scoring$subscales[[subscale_name]]$label
        )
      })
    }
    
    # Label du score total
    total_label <- NULL
    if(isTRUE(scale_config$scoring$total)) {
      total_label <- tibble(
        scale = scale_name,
        score_type = "total_score",
        score_type_label = "Score global"
      )
    }
    
    bind_rows(subscore_labels, total_label)
  })
  
  print("Labels générés:")
  print(scale_labels)
  return(scale_labels)
}

# Test
labels <- debug_labels(config)
