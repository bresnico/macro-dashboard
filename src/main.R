source("src/lib/dependencies.R")
load_dependencies()

source("src/lib/connection.R")
source("src/lib/import.R")
source("src/lib/scales.R")
source("src/lib/demographics.R")
source("src/lib/utils.R")
source("src/lib/groups.R")

# Chargement config
config <- yaml::read_yaml("src/config/scales.yml")
credentials <- yaml::read_yaml("src/config/credentials.yml")
survey_id <- credentials$limesurvey$survey_id
groups_config <- yaml::read_yaml("src/config/groups.yml")

# Pipeline principal
main <- function(survey_id, credentials, groups_config) {
  start_time <- Sys.time()
  status <- "✅ Succès"
  error_msg <- NULL
  n_rows <- 0
  n_scales <- 0
  n_scores <- 0
  n_administration <- 0
  
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
    
    # 3. Traitement des échelles et des données démographiques en parallèle
    log_info("\nCalcul des scores")
    scales_data <- prepare_all_scales_scores(std_data, config)
    n_rows <- nrow(scales_data)
    # Nombre d'échelles prises en compte
    n_scales <- scales_data |> 
      distinct(scale_label) |> 
      nrow()
    # Nombre de scores différents calculés, basé sur scale_label et score_type_label
    n_scores <- scales_data |> 
      distinct(scale_label, score_type_label) |> 
      nrow()
    # Nombre de passations basées sur person_id_secure et timestamp
    n_administration <- scales_data |> 
      distinct(person_id_secure, timestamp) |> 
      nrow()
    log_info(glue("\nCalcul terminé: {n_rows} lignes"))
    log_info("\nPréparation des données démographiques")
    demographics_data <- process_demographics(std_data, config)
    log_info("\nPréparation terminée")

    # 4. Joindre les données
    log_info("\nCréation de processed_data")
    processed_data <- scales_data %>%
      left_join(
        demographics_data,
        by = c(
          "person_id_secure",
          "timestamp", 
          "month",
          "group_id",
          "subgroup_id"
        )
      )
    log_info("\nJointure terminée")
    
    # 5. Ajout des labels de groupe
    log_info("\nAjout des labels de groupe")
    labels_data <- get_group_labels(groups_config)
    processed_data <- processed_data %>%
      left_join(
        labels_data$group_labels,
        by = "group_id"
      ) %>%
      left_join(
        labels_data$subgroup_labels,
        by = c("group_id", "subgroup_id")
      )
    
    log_info("\nJointure terminée")
    
    # Ajout de la colonne reseacher id pour chaque observation avec credentials$researcher_codes[1]
    log_info("\nCréation de researcher_id")
    processed_data$researcher_id <- credentials$researcher_codes[1]
    log_info("\nCréation de researcher_id terminée")
    
    # 6. Export avec timestamp
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
Echelles: {n_scales}
Scores: {n_scores}
Passations: {n_administration}
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
main(survey_id, credentials, groups_config)
