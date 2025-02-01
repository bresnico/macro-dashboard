validate_groups_config <- function(groups_config) {
  required_fields <- c("label")
  
  for (school_code in names(groups_config)) {
    school_info <- groups_config[[school_code]]
    
    # Vérifier que chaque école a un label
    if (!all(required_fields %in% names(school_info))) {
      stop(paste("L'école avec le code", school_code, "n'a pas de champ 'label'."))
    }
    
    # Vérifier les sous-groupes s'ils existent
    if ("teams" %in% names(school_info)) {
      teams_info <- school_info$teams
      for (team_code in names(teams_info)) {
        team_info <- teams_info[[team_code]]
        if (!"label" %in% names(team_info)) {
          stop(paste("L'équipe avec le code", team_code, "dans l'école", school_code, "n'a pas de champ 'label'."))
        }
      }
    }
  }
}

extract_group_labels <- function(groups_config) {
  group_labels <- tibble(
    school_code = names(groups_config),
    school_label = map_chr(groups_config, ~ .x$label),
    school_description = map_chr(groups_config, ~ .x$description %||% NA_character_)
  )
  return(group_labels)
}

extract_team_labels <- function(groups_config) {
  team_list <- list()
  
  for (school_code in names(groups_config)) {
    school_info <- groups_config[[school_code]]
    
    if ("teams" %in% names(school_info)) {
      teams_info <- school_info$teams
      for (team_code in names(teams_info)) {
        team_info <- teams_info[[team_code]]
        team_label <- team_info$label
        team_description <- team_info$description %||% NA_character_
        
        team_list[[length(team_list) + 1]] <- tibble(
          school_code = school_code,
          team_code = team_code,
          team_label = team_label,
          team_description = team_description
        )
      }
    }
  }
  
  # Combiner toutes les équipes en un seul data frame
  if (length(team_list) > 0) {
    team_labels <- bind_rows(team_list)
  } else {
    team_labels <- tibble(
      school_code = character(),
      team_code = character(),
      team_label = character(),
      team_description = character()
    )
  }
  
  return(team_labels)
}

get_group_labels <- function(groups_config) {
  # Valider la configuration
  validate_groups_config(groups_config)
  
  # Extraire les labels des écoles
  school_labels <- extract_group_labels(groups_config)
  
  # Extraire les labels des équipes
  team_labels <- extract_team_labels(groups_config)
  
  # Retourner les data frames
  list(
    school_labels = school_labels,
    team_labels = team_labels
  )
}

c <- yaml::read_yaml("src/config/groups.yml") |> get_group_labels()

