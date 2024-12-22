# Gestion de l'import

standardize_limesurvey_names <- function(data, config) {
  # Afficher quelques noms avant standardisation
  cat("Exemples de noms avant standardisation:", head(names(data)), "\n")
  
  # Copie des noms originaux
  original_names <- names(data)
  
  # Transformation des noms :
  # Suppression des points dans les noms de colonnes
  new_names <- str_replace_all(original_names, "\\.", "")
  
  # Mettre tous les noms en minuscules
  new_names <- tolower(new_names)
  
  # Appliquer les nouveaux noms
  names(data) <- new_names
  
  # Afficher quelques noms après standardisation
  cat("Exemples de noms après standardisation:", head(names(data)), "\n")
  
  # Pour information, compter les variables par échelle
  cat("\nNombres de variables après standardisation par échelle :\n")
  for (scale_name in names(config$scales)) {
    scale_config <- config$scales[[scale_name]]
    item_ids <- sapply(scale_config$items, function(x) x$id)
    count <- sum(item_ids %in% names(data))
    cat(scale_name, ":", count, "\n")
  }
  
  # Gestion des groupes non assignés
  data <- data %>%
    mutate(
      groupecode = case_when(
        is.na(groupecode) ~ "divers",
        groupecode == "" ~ "divers",
        is.null(groupecode) ~ "divers",
        TRUE ~ groupecode
      )
    )
  
  return(data)
}
  
# Fonction sécurisée pour récupérer les données
get_limesurvey_data <- function(survey_id, config) {
  cat("DEBUG: Début de get_limesurvey_data\n")
  
  # Vérifier si nous devons utiliser les données de test
  if (!is.null(config$fake_data) && config$fake_data == TRUE) {
    cat("DEBUG: Utilisation des données de test\n")
    tryCatch({
      # Lecture du fichier de test
      test_data <- read_csv2("data/test_data_full.csv")
      cat("DEBUG: Données de test chargées avec succès\n")
      # Standardisation des noms
      cat("DEBUG: Noms de colonnes avant standardisation:\n")
      print(head(names(test_data)))
      
      cat("DEBUG: Appel de standardize_limesurvey_names\n")
      test_data <- standardize_limesurvey_names(test_data, config)
      
      cat("DEBUG: Noms de colonnes après standardisation:\n")
      print(head(names(test_data)))
      
      # Retourner les données de test
      return(test_data)
    }, error = function(e) {
      stop("Erreur lors de la lecture des données de test: ", e$message)
    })
  }
  
  # Si fake_data n'est pas TRUE, continuer avec la logique existante
  tryCatch({
    cat("DEBUG: Tentative de connexion\n")
    session_key <- get_session_key()
    if (is.null(session_key)) {
      stop("Impossible d'obtenir une clé de session")
    }
    cat("DEBUG: Clé de session obtenue\n")
    
    # Récupération des données
    cat("DEBUG: Récupération des données\n")
    responses <- get_responses(survey_id, sResponseType = "short")
    cat("DEBUG: Données brutes reçues\n")
    
    # Conversion de l'encodage si nécessaire
    responses <- lapply(responses, function(column) {
      if (is.character(column)) {
        iconv(column, from = "UTF-8", to = "UTF-8", sub = "")
      } else {
        column
      }
    })
    responses <- as.data.frame(responses, stringsAsFactors = FALSE)
    
    # Standardisation des noms
    cat("DEBUG: Noms de colonnes avant standardisation:\n")
    print(head(names(responses)))
    
    cat("DEBUG: Appel de standardize_limesurvey_names\n")
    responses <- standardize_limesurvey_names(responses, config)
    
    cat("DEBUG: Noms de colonnes après standardisation:\n")
    print(head(names(responses)))
    
    # Libération de la clé
    cat("DEBUG: Libération de la clé de session\n")
    release_session_key()
    
    return(responses)
  }, error = function(e) {
    cat("DEBUG: Erreur attrapée:", e$message, "\n")
    if (exists("session_key")) {
      release_session_key()
    }
    stop("Erreur lors de la récupération des données: ", e$message)
  }, finally = {
    cat("DEBUG: Finally block\n")
    if (exists("session_key")) {
      try(release_session_key(), silent = TRUE)
    }
  })
}
# Conversion des réponses

convert_responses <- function(data, config) {
  # Fonction utilitaire pour convertir et potentiellement inverser une réponse
  convert_scale_value <- function(x, prefix, scale_type, reversed = FALSE) {
    values <- suppressWarnings(as.numeric(sub(prefix, "", x)))
    
    if (!is.null(scale_type)) {
      min_val <- scale_type$min_value
      max_val <- scale_type$max_value
      
      # Valider la plage
      values <- ifelse(values >= min_val & values <= max_val, values, NA)
      
      # Inverser si nécessaire
      if (reversed && !is.na(values)) {
        values <- (max_val + min_val) - values
      }
    }
    
    return(values)
  }
  
  # Statistiques de conversion
  stats <- list(
    scales = list(),
    demographics = list()
  )
  
  # 1. Conversion des échelles
  for (scale_name in names(config$scales)) {
    scale_config <- config$scales[[scale_name]]
    scale_type <- config$scale_types[[scale_config$type]]
    prefix <- scale_config$response_prefix %||% "AO0"
    
    # Traiter chaque item individuellement pour gérer l'inversion
    for (item in scale_config$items) {
      item_id <- item$id
      
      if (item_id %in% names(data)) {
        data[[item_id]] <- convert_scale_value(
          data[[item_id]], 
          prefix = prefix,
          scale_type = scale_type,
          reversed = item$reversed
        )
        
        # Statistiques par item
        stats$scales[[scale_name]]$items[[item_id]] <- list(
          reversed = item$reversed,
          valid_values = sum(!is.na(data[[item_id]])),
          invalid_values = sum(is.na(data[[item_id]]))
        )
      }
    }
  }
  
  # [Reste du code pour démographiques inchangé...]
  
  # Mise à jour du résumé pour inclure les items inversés
  cat("\nConversion des échelles :\n")
  for (scale_name in names(stats$scales)) {
    s <- stats$scales[[scale_name]]
    n_reversed <- sum(sapply(s$items, function(x) x$reversed))
    
    cat(sprintf("%s: %d items (%d inversés)\n",
                scale_name, length(s$items), n_reversed))
    
    # Détails des items
    for (item_id in names(s$items)) {
      item <- s$items[[item_id]]
      cat(sprintf("  - %s: %s, %d valides, %d invalides\n",
                  item_id,
                  if(item$reversed) "inversé" else "normal",
                  item$valid_values,
                  item$invalid_values))
    }
  }
  
  return(data)
}

# Calcul des scores

old_calculate_scale_scores <- function(data, scale_name, config) {
  # Validation du nom de l'échelle
  if (!scale_name %in% names(config$scales)) {
    return(NULL)
  }
  
  # Récupération de la configuration de l'échelle
  scale_config <- config$scales[[scale_name]]
  item_ids <- sapply(scale_config$items, function(x) x$id)
  
  # Vérification de la présence des items dans les données 
  item_ids_in_data <- item_ids[item_ids %in% names(data)]
  if (length(item_ids_in_data) == 0) {
    return(NULL)
  }
  
  # Vérification du taux minimum de réponses valides requis
  min_responses_required <- config$validation$min_responses[[scale_name]]
  valid_rate <- length(item_ids_in_data) / length(item_ids)
  
  if (valid_rate < min_responses_required) {
    return(NULL)
  }
  
  # Construction du dataframe initial avec les champs obligatoires
  scores <- data %>%
    select(
      timestamp = datestamp,
      group_id = groupecode,
      person_id = !!sym(paste0(config$identification$personal_id$group, config$identification$personal_id$question)),
      all_of(item_ids_in_data)
    )
  
  # Calcul des scores selon la configuration
  scoring_config <- scale_config$scoring
  
  # Calcul score total si configuré
  if (isTRUE(scoring_config$total)) {
    scores <- scores %>%
      rowwise() %>%
      mutate(
        total_score = mean(c_across(all_of(item_ids_in_data)), na.rm = TRUE)
      ) %>%
      ungroup()
  }
  
  # Calcul des sous-échelles si définies
  if (!is.null(scoring_config$subscales)) {
    for (subscale_name in names(scoring_config$subscales)) {
      subscale_items <- scoring_config$subscales[[subscale_name]]$items
      available_subscale_items <- intersect(subscale_items, item_ids_in_data)
      
      if (length(available_subscale_items) > 0) {
        scores <- scores %>%
          rowwise() %>%
          mutate(
            !!subscale_name := mean(c_across(all_of(available_subscale_items)), na.rm = TRUE)
          ) %>%
          ungroup()
      }
    }
  }
  
  # Sélection des colonnes pertinentes pour la sortie
  keep_columns <- c("timestamp", "group_id", "person_id")
  if (isTRUE(scoring_config$total)) {
    keep_columns <- c(keep_columns, "total_score")
  }
  if (!is.null(scoring_config$subscales)) {
    keep_columns <- c(keep_columns, names(scoring_config$subscales))
  }
  
  # Si aucun score calculé, retourner NULL
  if (length(keep_columns) <= 3) {
    return(NULL)
  }
  
  # Retourner le dataframe final avec uniquement les colonnes nécessaires
  scores %>%
    select(all_of(keep_columns))
}