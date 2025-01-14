# Préparation de l'identifiant utilisateur sans le mot de sécurité (fonction rétrocompatible)

clean_teacher_id <- function(full_id) {
  # Vectorisation avec ifelse pour gérer les vecteurs
  ifelse(
    grepl("-", full_id),
    sub("^(.+?)-.*$", "\\1", full_id),
    full_id
  )
}

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
      person_id = clean_teacher_id(g01q13),   # ID nettoyé pour les agrégations 
      person_id_secure = g01q13,              # ID complet pour l'interface      
      group_id = groupecode,           # Maintenir pour compatibilité
      subgroup_id = ifelse(is.na(grouperef) | grouperef == "", "all", grouperef),  # Nouveau avec valeur par défaut
      timestamp = ymd_hms(datestamp),
      month = floor_date(timestamp, "month")
    ) %>%
    select(timestamp, month, person_id, person_id_secure, group_id, subgroup_id, all_of(item_ids))
  
  # Calcul des scores individuels
  if(scale_config$scoring$total) {
    scores_data <- scores_data %>%
      rowwise() %>%
      mutate(
        # Si toutes les valeurs de l'échelle sont NA, retourne -99, sinon calcule la moyenne
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
  
  # Identification des colonnes de scores
  score_columns <- setdiff(names(scores_data), 
                           c("timestamp", "month", "person_id", "person_id_secure", "group_id", "subgroup_id", item_ids))
  
  # Préparation du format long avec scores de référence
  scores_long <- scores_data %>%
    select(timestamp, month, person_id, person_id_secure, group_id, subgroup_id, all_of(score_columns)) %>%
    pivot_longer(
      cols = all_of(score_columns),
      names_to = "score_type",
      values_to = "score_value"
    ) %>%
    # Calcul des références au niveau du sous-groupe
    group_by(group_id, subgroup_id, month, score_type) %>%
    mutate(
      subgroup_reference = mean(score_value[score_value != -99], na.rm = TRUE),
      subgroup_sd = sd(score_value[score_value != -99], na.rm = TRUE),
      subgroup_n = sum(score_value != -99, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    # Calcul des références au niveau du groupe principal
    group_by(group_id, month, score_type) %>%
    mutate(
      group_reference = mean(score_value[score_value != -99], na.rm = TRUE),
      group_sd = sd(score_value[score_value != -99], na.rm = TRUE),
      group_n = sum(score_value != -99, na.rm = TRUE),
      quartile = ifelse(score_value != -99, 
                        ntile(score_value, 4), 
                        NA),
      scale = scale_name
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
        label <- scale_config$scoring$subscales[[subscale_name]]$label
        tibble(
          scale = scale_name,
          scale_label = scale_config$label,
          scale_description = scale_config$description,
          scale_reference = scale_config$reference,
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
        scale_description = scale_config$description,
        scale_reference = scale_config$reference,
        score_type = "total_score",
        score_type_label = "Score global"
      )
    }
    
    bind_rows(subscore_labels, total_label)
  })
  
  # Traitement de toutes les échelles
  all_scores <- map_dfr(scale_names, ~process_single_scale(data, .x, config, debug = debug))
  
  final_scores <- all_scores %>%
    left_join(scale_labels, by = c("scale", "score_type")) %>%
    arrange(timestamp, group_id, subgroup_id, person_id, scale, score_type) %>%
    select(
      timestamp,
      month,
      person_id,
      person_id_secure,
      group_id,
      subgroup_id,
      scale,
      scale_label,
      scale_description,
      scale_reference,
      score_type,
      score_type_label,
      score_value,
      subgroup_reference,  # Nouvelle colonne
      subgroup_sd,         # Nouvelle colonne
      subgroup_n,          # Nouvelle colonne
      group_reference,     # Renommé de reference_value
      group_sd,           # Renommé de reference_sd
      group_n,            # Renommé de n_group
      quartile
    )
  
  # Transformation finale pour assurer des types corrects
  final_scores <- final_scores %>%
    mutate(
      # Dates
      timestamp = as.Date(timestamp),
      month = format(month, "%B %Y"),
      
      # S'assurer que tous les scores sont numériques
      across(c(score_value, 
               subgroup_reference, subgroup_sd,
               group_reference, group_sd), 
             ~as.numeric(.x)),
      
      # Compteurs en entiers
      across(c(subgroup_n, group_n), as.integer),
      
      # Quartile doit être un entier
      quartile = as.integer(quartile)
    )
  
  return(final_scores)
}
