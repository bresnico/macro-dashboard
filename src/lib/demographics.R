# Fonction pour traiter les données démographiques
process_demographics <- function(data, config) {
  # Construction des variables depuis la config 
  demographic_fields <- list(
    age = list(
      id = paste0(config$demographics$age$group, config$demographics$age$question),
      mapping = config$demographics$age$labels
    ),
    gender = list(
      id = paste0(config$demographics$gender$group, config$demographics$gender$question),
      mapping = config$demographics$gender$labels 
    ),
    status = list(
      id = paste0(config$demographics$status$group, config$demographics$status$question),
      mapping = config$demographics$status$labels
    ),
    experience = list(
      id = paste0(config$demographics$experience$group, config$demographics$experience$question),
      mapping = config$demographics$experience$labels
    )
  )
  
  # Préparation des données avec les mêmes identifiants que scales.R
  demographics_data <- data %>%
    mutate(
      person_id = clean_teacher_id(g01q13),
      person_id_secure = g01q13,
      group_id = groupecode,           # Maintenir pour compatibilité
      subgroup_id = grouperef,         # Nouveau
      timestamp = as.Date(ymd_hms(datestamp)),
      month = format(timestamp, "%B %Y"),
      # Conversion des codes en labels pour chaque variable démographique
      age = recode(!!sym(demographic_fields$age$id), !!!demographic_fields$age$mapping),
      gender = recode(!!sym(demographic_fields$gender$id), !!!demographic_fields$gender$mapping),
      status = recode(!!sym(demographic_fields$status$id), !!!demographic_fields$status$mapping),
      experience = recode(!!sym(demographic_fields$experience$id), !!!demographic_fields$experience$mapping)
    ) %>%
    select(timestamp, month, person_id_secure, group_id, subgroup_id, age, gender, status, experience)
  
  return(demographics_data)
}