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