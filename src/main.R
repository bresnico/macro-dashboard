source("src/lib/connection.R")
source("src/lib/import.R")
source("src/lib/scales.R")

library(glue)

# Chargement config
config <- yaml::read_yaml("src/config/scales.yml")
credentials <- yaml::read_yaml("src/config/credentials.yml")
survey_id <- credentials$limesurvey$survey_id

# Préparation du log
log_info <- function(msg) {
  log_dir <- "logs"
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }
  cat(glue("[{Sys.time()}] {msg}\n\n"), 
      file = file.path(log_dir, "process.log"), 
      append = TRUE)
}

# Fonction pour envoyer des messages Telegram
send_telegram_notification <- function(message, bot_token, chat_id) {
  if (!startsWith(as.character(chat_id), "-100")) {
    chat_id <- paste0("-100", gsub("-", "", chat_id))
  }
  
  url <- paste0("https://api.telegram.org/bot", bot_token, "/sendMessage")
  
  body <- list(
    chat_id = chat_id,
    text = message,
    parse_mode = "HTML"
  )
  
  tryCatch({
    response <- httr::POST(
      url = url,
      body = body,
      encode = "json"
    )
    return(httr::status_code(response) == 200)
  }, error = function(e) {
    return(FALSE)
  })
}

# Pipeline principal
main <- function(survey_id, credentials) {
  start_time <- Sys.time()
  status <- "✅ Succès"
  error_msg <- NULL
  n_rows <- 0
  
  tryCatch({
    log_info("\nDémarrage du traitement")
    
    # 1. Connection
    log_info("\nTentative de connexion à LimeSurvey")
    if(!setup_limesurvey_connection(credentials)) {
      stop("Échec de connexion LimeSurvey")
    }
    log_info("\nConnexion établie")
    
    # 2. Import et standardisation  
    log_info("\nImport des données brutes")
    raw_data <- get_limesurvey_data(survey_id, config)
    log_info(glue("\nImport terminé: {nrow(raw_data)} lignes"))
    
    log_info("\nStandardisation des noms")
    std_data <- standardize_limesurvey_names(raw_data, config)
    log_info("\nStandardisation terminée")
    
    # 3. Traitement des échelles
    log_info("\nCalcul des scores")
    processed_data <- prepare_all_scales_scores(std_data, config)
    n_rows <- nrow(processed_data)
    log_info(glue("\nCalcul terminé: {n_rows} lignes"))
    
    # 4. Export avec timestamp
    output_dir <- "data/processed"
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
      log_info("\nCréation du dossier de sortie")
    }
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    output_file <- file.path(output_dir, glue("survey_data_{timestamp}.csv"))
    write_csv(processed_data, output_file)
    log_info(glue("\nDonnées exportées: {output_file}"))
    
    log_info("\nTraitement terminé avec succès")
    
  }, error = function(e) {
    status <- "❌ Échec"
    error_msg <- conditionMessage(e)
    log_info(glue("\nERREUR: {error_msg}"))
  }, finally = {
    # Préparation du message Telegram
    # Calcul simple en secondes
    duration <- sprintf("%.1f secondes", 
                        as.numeric(difftime(Sys.time(), start_time, units = "secs")))
    
    message <- glue("
🤖 Mise à jour LimeSurvey

Status: {status}
Temps d'exécution: {duration}
Observations: {n_rows}
{if(!is.null(error_msg)) paste('Erreur:', error_msg) else ''}
    ")
    
    # Envoi de la notification Telegram
    send_telegram_notification(
      message,
      bot_token = credentials$telegram$bot_token,
      chat_id = credentials$telegram$chat_id
    )
  })
}

# Exécution
main(survey_id, credentials)