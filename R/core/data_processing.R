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
  # Conversion des réponses pour chaque échelle
  for (scale_name in names(config$scales)) {
    scale_config <- config$scales[[scale_name]]
    
    # Obtenir les identifiants des items
    item_ids <- sapply(scale_config$items, function(x) x$id)
    
    # Vérifier que les colonnes existent dans les données
    item_ids_in_data <- item_ids[item_ids %in% names(data)]
    
    if (length(item_ids_in_data) > 0) {
      # Conversion des réponses
      data[item_ids_in_data] <- lapply(data[item_ids_in_data], function(x) {
        # Utiliser le 'response_prefix' du YAML s'il est défini, sinon valeur par défaut
        response_prefix <- ifelse(!is.null(scale_config$response_prefix), scale_config$response_prefix, "AO0")
        # Convertir la réponse en numérique
        as.numeric(sub(response_prefix, "", x))
      })
    }
  }
  
  # Conversion des données démographiques
  for (var_name in names(config$demographics)) {
    dem_config <- config$demographics[[var_name]]
    field <- paste0(dem_config$group, dem_config$question)
    
    if(field %in% names(data)) {
      data[[field]] <- factor(
        data[[field]],
        levels = names(dem_config$labels),
        labels = dem_config$labels
      )
    }
  }
  
  return(data)
}

# Vérification des conversions

verify_conversion <- function(data, config) {
  for (scale_name in names(config$scales)) {
    scale_config <- config$scales[[scale_name]]
    # Obtenir les identifiants des items
    item_ids <- sapply(scale_config$items, function(x) x$id)
    
    # Vérifier si les items existent dans les données
    item_ids_in_data <- item_ids[item_ids %in% names(data)]
    
    if (length(item_ids_in_data) > 0) {
      scale_values <- unlist(data[item_ids_in_data])
      scale_range <- range(scale_values, na.rm = TRUE)
      cat(scale_name, "range:", scale_range[1], "to", scale_range[2], "\n")
      scale_na <- sum(is.na(scale_values))
      cat("Missing values -", scale_name, ":", scale_na, "\n")
    } else {
      cat("Aucun item trouvé pour l'échelle", scale_name, "\n")
    }
  }
  
  return(data)
}

# Calcul des scores

calculate_scale_scores <- function(data, scale_name, config) {
  if (!scale_name %in% names(config$scales)) {
    return(NULL)
  }
  
  scale_config <- config$scales[[scale_name]]
  item_list <- scale_config$items
  item_ids <- sapply(item_list, function(x) x$id)
  
  # Vérifions d'abord si nous avons suffisamment de données valides
  item_ids_in_data <- item_ids[item_ids %in% names(data)]
  if (length(item_ids_in_data) == 0) {
    return(NULL)
  }
  
  # Préparation des données avec gestion des valeurs manquantes
  data_scored <- data
  valid_items <- character(0)
  
  for (item in item_list) {
    item_id <- item$id
    if (!item_id %in% names(data_scored)) {
      next
    }
    
    # Tentative de conversion en numérique
    converted_values <- try(as.numeric(data_scored[[item_id]]), silent = TRUE)
    if (!inherits(converted_values, "try-error") && !all(is.na(converted_values))) {
      data_scored[[item_id]] <- converted_values
      valid_items <- c(valid_items, item_id)
      
      # Inversion si nécessaire
      if (item$reversed == TRUE) {
        scale_info <- config$scale_types[[scale_config$type]]
        max_value <- as.numeric(scale_info$max_value)
        min_value <- as.numeric(scale_info$min_value)
        data_scored[[item_id]] <- (max_value + min_value) - data_scored[[item_id]]
      }
    }
  }
  
  # Vérification du taux minimum de réponses valides requis
  min_responses_required <- config$validation$min_responses[[scale_name]]
  valid_rate <- length(valid_items) / length(item_ids)
  
  if (valid_rate < min_responses_required) {
    return(NULL)
  }
  
  # Construction du dataframe de sortie avec les champs obligatoires
  scores <- data_scored %>%
    select(
      timestamp = datestamp,
      group_id = groupecode,
      person_id = !!sym(paste0(config$identification$personal_id$group, config$identification$personal_id$question)),
      all_of(valid_items)
    )
  
  # Calcul du score total si spécifié
  if (!is.null(scale_config$scoring$total) && scale_config$scoring$total == TRUE) {
    scores <- scores %>%
      rowwise() %>%
      mutate(
        total_score = mean(c_across(all_of(valid_items)), na.rm = TRUE)
      ) %>%
      ungroup()
  }
  
  # Calcul des sous-échelles valides
  if (!is.null(scale_config$scoring$subscales)) {
    for (subscale_name in names(scale_config$scoring$subscales)) {
      subscale_items <- intersect(
        scale_config$scoring$subscales[[subscale_name]]$items,
        valid_items
      )
      
      if (length(subscale_items) > 0) {
        scores <- scores %>%
          rowwise() %>%
          mutate(
            !!subscale_name := mean(c_across(all_of(subscale_items)), na.rm = TRUE)
          ) %>%
          ungroup()
      }
    }
  }
  
  return(scores)
}
