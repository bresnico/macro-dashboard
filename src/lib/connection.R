# libraries nécessaires
library(tidyverse)
library(limer)

# fonction pour charger les données LimeSurvey
setup_limesurvey_connection <- function(credentials) {
  # Chargement des credentials
  tryCatch({

    # Configuration avec les credentials reçus
    options(
      lime_api = credentials$limesurvey$api_url,
      lime_username = credentials$limesurvey$username,
      lime_password = credentials$limesurvey$password
    )
    
    # Test de connexion
    session_key <- get_session_key()
    if (!is.null(session_key)) {
      release_session_key()
      return(TRUE)
    }
    return(FALSE)
  }, error = function(e) {
    warning("Erreur de configuration LimeSurvey: ", e$message)
    return(FALSE)
  })
  
}
