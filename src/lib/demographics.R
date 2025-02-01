# initiation pour les tests
# config <- yaml::read_yaml("src/config/scales.yml")
# d <- readRDS("d.RDS")

validate_demographics <- function(data, config) {
  # Récupérer les identifiants des variables démographiques depuis la configuration
  demographic_fields <- sapply(config$demographics, function(x) paste0(x$group, x$question))
  
  # Récupérer les identifiants des champs nécessaires (identification)
  identification_fields <- c(
    config$identification$personal_id,
    config$identification$school_code,
    config$identification$team_code,
    config$identification$timestamp$id
  )
  
  required_fields <- c(demographic_fields, identification_fields)
  
  # Vérifier si tous les champs requis sont présents dans les données
  missing_fields <- setdiff(required_fields, names(data))
  
  if (length(missing_fields) > 0) {
    stop(paste("Les champs suivants sont manquants dans les données :", paste(missing_fields, collapse = ", ")))
  }
}

prepare_demographics_data <- function(data_raw, config) {
  # Extraire les identifiants depuis la configuration
  personal_id_field <- config$identification$personal_id
  school_code_field <- config$identification$school_code
  team_code_field <- config$identification$team_code
  timestamp_field <- config$identification$timestamp$id
  timestamp_format <- config$identification$timestamp$format
  
  # Convertir le timestamp et préparer les données
  data_prepared <- data_raw %>%
    mutate(
      person_id = .data[[personal_id_field]],
      school_code = .data[[school_code_field]],
      team_code = .data[[team_code_field]],
      timestamp = ymd_hms(.data[[timestamp_field]], tz = "UTC"),
      month = format(timestamp, "%B %Y")
    )
  
  return(data_prepared)
}

get_demographic_fields <- function(config) {
  demographic_fields <- lapply(config$demographics, function(demo_config) {
    list(
      id = paste0(demo_config$group, demo_config$question),
      mapping = demo_config$labels
    )
  })
  
  # Nommer les éléments de la liste avec les noms des variables démographiques
  names(demographic_fields) <- names(config$demographics)
  
  return(demographic_fields)
}

recode_demographic <- function(data, field_id, mapping) {
  if (!field_id %in% names(data)) {
    warning(paste("Le champ", field_id, "n'est pas présent dans les données."))
    return(rep(NA_character_, nrow(data)))
  }
  values <- data[[field_id]]
  if (all(is.na(values)) || length(values) == 0) {
    return(rep(NA_character_, nrow(data)))
  }
  recoded_values <- recode(values, !!!mapping)
  return(recoded_values)
}

process_demographics <- function(data_raw, config) {
  # Valider les données
  validate_demographics(data_raw, config)
  
  # Préparer les données
  data_prepared <- prepare_demographics_data(data_raw, config)
  
  # Obtenir les champs démographiques
  demographic_fields <- get_demographic_fields(config)
  
  # Recode les variables démographiques
  data_demographics <- data_prepared
  
  for (demo_var in names(demographic_fields)) {
    field_info <- demographic_fields[[demo_var]]
    field_id <- field_info$id
    mapping <- field_info$mapping
    
    data_demographics[[demo_var]] <- recode_demographic(data_prepared, field_id, mapping)
  }
  
  # Sélectionner les colonnes nécessaires
  demographics_data <- data_demographics %>%
    select(person_id, timestamp, month, school_code, team_code, all_of(names(demographic_fields)))
  
  return(demographics_data)
}