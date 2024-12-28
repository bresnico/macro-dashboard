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

# Pipeline principal
main <- function(survey_id) {
  log_info("\nDémarrage du traitement")
  
  # 1. Connection
  log_info("\nTentative de connexion à LimeSurvey")
  if(!setup_limesurvey_connection()) {
    log_info("\nERREUR: Échec de connexion LimeSurvey")
    stop("\nErreur de connexion LimeSurvey")
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
  log_info(glue("\nCalcul terminé: {nrow(processed_data)} lignes"))
  
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
}

main(survey_id)
