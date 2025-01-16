# Fonctions utilitaires ----

clean_teacher_id <- function(full_id) {
  ifelse(
    grepl("-", full_id),
    sub("^(.+?)-.*$", "\\1", full_id),
    full_id
  )
}

invert_score <- function(score, scale_type, config) {
  scale_limits <- config$scale_types[[scale_type]]
  if (is.null(scale_limits)) {
    warning(sprintf("Type d'échelle '%s' non trouvé dans la configuration", scale_type))
    return(score)
  }
  
  min_value <- scale_limits$min_value
  max_value <- scale_limits$max_value
  (max_value + min_value) - score
}

# Préparation des données ----

prepare_numeric_responses <- function(data, scale_name, config, debug = FALSE) {
  scale_config <- config$scales[[scale_name]]
  items_info <- scale_config$items
  
  processed_data <- data
  
  for(item in items_info) {
    col_name <- item$id
    
    if(debug) {
      cat(sprintf("Traitement de l'item %s (inversé: %s)\n", 
                  col_name, 
                  ifelse(item$reversed, "oui", "non")))
    }
    
    # Conversion numérique
    processed_data[[col_name]] <- as.numeric(
      sub(scale_config$response_prefix, "", processed_data[[col_name]])
    )
    
    # Inversion si nécessaire
    if(isTRUE(item$reversed)) {
      if(debug) cat(sprintf("Inversion des scores pour l'item %s\n", col_name))
      processed_data[[col_name]] <- invert_score(
        processed_data[[col_name]], 
        scale_config$type,
        config
      )
    }
  }
  
  return(processed_data)
}

# Préparation des métadonnées ----

prepare_scale_labels <- function(scale_names, config) {
  map_dfr(scale_names, function(scale_name) {
    scale_config <- config$scales[[scale_name]]
    
    # Labels des sous-scores
    subscore_labels <- NULL
    if(!is.null(scale_config$scoring$subscales)) {
      subscore_labels <- map_dfr(names(scale_config$scoring$subscales), function(subscale_name) {
        tibble(
          scale = scale_name,
          scale_label = scale_config$label,
          scale_description = scale_config$description,
          scale_reference = scale_config$reference,
          score_type = subscale_name,
          score_type_label = scale_config$scoring$subscales[[subscale_name]]$label
        )
      })
    }
    
    # Label du score total
    total_label <- NULL
    if(is.list(scale_config$scoring$total) && isTRUE(scale_config$scoring$total$enabled)) {
      total_label <- tibble(
        scale = scale_name,
        scale_label = scale_config$label,
        scale_description = scale_config$description,
        scale_reference = scale_config$reference,
        score_type = "total_score",
        score_type_label = "Score global"
      )
    }
    
    bind_rows(subscore_labels, total_label)
  })
}

prepare_score_categories <- function(config) {
  map_dfr(names(config$scales), function(scale_name) {
    scale_config <- config$scales[[scale_name]]
    scoring_config <- scale_config$scoring
    
    # Catégories pour score total
    total_category <- if(is.list(scoring_config$total) && 
                         isTRUE(scoring_config$total$enabled)) {
      tibble(
        scale = scale_name,
        score_type = "total_score",
        jdr_category = scoring_config$total$category
      )
    }
    
    # Catégories pour subscales
    subscale_categories <- if(!is.null(scoring_config$subscales)) {
      map_dfr(names(scoring_config$subscales), function(subscale_name) {
        tibble(
          scale = scale_name,
          score_type = subscale_name,
          jdr_category = scoring_config$subscales[[subscale_name]]$category
        )
      })
    }
    
    bind_rows(total_category, subscale_categories)
  })
}

# Traitement des scores ----

process_single_scale <- function(data, scale_name, config, debug = TRUE) {
  if(debug) cat("\nTraitement de l'échelle:", scale_name, "\n")
  
  # Préparation numérique
  data <- prepare_numeric_responses(data, scale_name, config)
  scale_config <- config$scales[[scale_name]]
  item_ids <- sapply(scale_config$items, function(x) x$id)
  
  # Préparation des données de base
  scores_data <- data %>%
    mutate(
      person_id = clean_teacher_id(g01q13),
      person_id_secure = g01q13,
      group_id = groupecode,
      subgroup_id = ifelse(is.na(grouperef) | grouperef == "", "all", grouperef),
      timestamp = ymd_hms(datestamp),
      month = floor_date(timestamp, "month")
    ) %>%
    select(timestamp, month, person_id, person_id_secure, 
           group_id, subgroup_id, all_of(item_ids))
  
  # Calcul des scores
  if(is.list(scale_config$scoring$total) && 
     isTRUE(scale_config$scoring$total$enabled)) {
    scores_data <- scores_data %>%
      rowwise() %>%
      mutate(
        total_score = if(all(is.na(c_across(all_of(item_ids))))) {
          -99
        } else {
          mean(c_across(all_of(item_ids)), na.rm = TRUE)
        }
      ) %>%
      ungroup()
  }
  
  if(!is.null(scale_config$scoring$subscales)) {
    for(subscale_name in names(scale_config$scoring$subscales)) {
      subscale_items <- scale_config$scoring$subscales[[subscale_name]]$items
      scores_data <- scores_data %>%
        rowwise() %>%
        mutate(
          !!subscale_name := if(all(is.na(c_across(all_of(subscale_items))))) {
            -99
          } else {
            mean(c_across(all_of(subscale_items)), na.rm = TRUE)
          }
        ) %>%
        ungroup()
    }
  }
  
  # Préparation format long et calcul des références
  score_columns <- setdiff(
    names(scores_data),
    c("timestamp", "month", "person_id", "person_id_secure", 
      "group_id", "subgroup_id", item_ids)
  )
  
  scores_long <- scores_data %>%
    select(timestamp, month, person_id, person_id_secure, 
           group_id, subgroup_id, all_of(score_columns)) %>%
    pivot_longer(
      cols = all_of(score_columns),
      names_to = "score_type",
      values_to = "score_value"
    ) %>%
    # Références sous-groupe
    group_by(group_id, subgroup_id, month, score_type) %>%
    mutate(
      subgroup_n = sum(score_value != -99, na.rm = TRUE),
      subgroup_reference = if(subgroup_n >= 10) {
        mean(score_value[score_value != -99], na.rm = TRUE)
      } else {
        NA_real_
      },
      subgroup_sd = if(subgroup_n >= 10) {
        sd(score_value[score_value != -99], na.rm = TRUE)
      } else {
        NA_real_
      }
    ) %>%
    ungroup() %>%
    # Références groupe
    group_by(group_id, month, score_type) %>%
    mutate(
      group_n = sum(score_value != -99, na.rm = TRUE),
      group_reference = if(group_n >= 10) {
        mean(score_value[score_value != -99], na.rm = TRUE)
      } else {
        NA_real_
      },
      group_sd = if(group_n >= 10) {
        sd(score_value[score_value != -99], na.rm = TRUE)
      } else {
        NA_real_
      },
      quartile = if(group_n >= 10) {
        ntile(score_value[score_value != -99], 4)
      } else {
        NA_integer_
      },
      scale = scale_name
    ) %>%
    ungroup()
  
  return(scores_long)
}

# Standardisation des types de données ----

standardize_data_types <- function(scores) {
  scores %>%
    mutate(
      timestamp = as.Date(timestamp),
      month = format(month, "%B %Y"),
      across(c(score_value, 
               subgroup_reference, subgroup_sd,
               group_reference, group_sd), 
             ~as.numeric(.x)),
      across(c(subgroup_n, group_n), as.integer),
      quartile = as.integer(quartile)
    )
}

# Fonction principale ----

prepare_all_scales_scores <- function(data, config, debug = FALSE) {
  # Préparation des métadonnées
  scale_names <- names(config$scales)
  scale_labels <- prepare_scale_labels(scale_names, config)
  categories <- prepare_score_categories(config)
  
  # Traitement des échelles
  all_scores <- map_dfr(scale_names, 
                        ~process_single_scale(data, .x, config, debug))
  
  # Assemblage final
  final_scores <- all_scores %>%
    left_join(scale_labels, by = c("scale", "score_type")) %>%
    left_join(categories, by = c("scale", "score_type")) %>%
    mutate(
      jdr_category = if_else(is.na(jdr_category), 
                             "non_categorise", jdr_category)
    ) %>%
    arrange(timestamp, group_id, subgroup_id, 
            person_id, scale, score_type) %>%
    standardize_data_types() %>%
    select(
      timestamp, month, person_id, person_id_secure,
      group_id, subgroup_id, scale, scale_label,
      scale_description, scale_reference, score_type,
      score_type_label, jdr_category, score_value,
      subgroup_reference, subgroup_sd, subgroup_n,
      group_reference, group_sd, group_n, quartile
    )
  
  return(final_scores)
}