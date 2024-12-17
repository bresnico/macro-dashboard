setup_limesurvey_connection <- function() {
  # Chargement des credentials
  tryCatch({
    credentials <- yaml::read_yaml("config/credentials.yml")
    
    # Configuration avec les credentials chargés
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