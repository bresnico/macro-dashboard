# Analyse par groupe
analyze_group_scores <- function(scores) {
  # Validation de la colonne 'group_id'
  if (!"group_id" %in% names(scores)) {
    stop("La colonne 'group_id' est manquante dans les scores.")
  }
  
  # Conversion de 'group_id' en facteur si nécessaire
  if (!is.factor(scores$group_id)) {
    scores <- scores %>%
      mutate(group_id = as.factor(group_id))
  }
  
  # Vérification de la présence de variables numériques
  numeric_vars <- names(scores)[sapply(scores, is.numeric)]
  if (length(numeric_vars) == 0) {
    stop("Aucune variable numérique à analyser.")
  }
  
  # Analyse par groupe
  scores %>%
    group_by(group_id) %>%
    summarise(
      across(
        all_of(numeric_vars),
        list(
          n = ~n(),
          mean = ~mean(., na.rm = TRUE),
          sd = ~sd(., na.rm = TRUE),
          min = ~min(., na.rm = TRUE),
          max = ~max(., na.rm = TRUE)
        ),
        .names = "{.col}__{.fn}"
      )
    )
}
# Analyse temporelle
analyze_temporal_trend <- function(scores, period = "month") {
  # Validation des colonnes
  if (!"timestamp" %in% names(scores)) {
    stop("La colonne 'timestamp' est manquante dans les scores.")
  }
  if (!"group_id" %in% names(scores)) {
    stop("La colonne 'group_id' est manquante dans les scores.")
  }
  
  # Conversion de 'timestamp' en date-heure si nécessaire
  if (!inherits(scores$timestamp, "POSIXct")) {
    scores <- scores %>%
      mutate(timestamp = ymd_hms(timestamp))
  }
  
  # Gérer les valeurs manquantes dans 'timestamp'
  scores <- scores %>%
    filter(!is.na(timestamp))
  
  # Analyse temporelle
  scores %>%
    mutate(period = floor_date(timestamp, unit = period)) %>%
    group_by(period, group_id) %>%
    summarise(
      across(
        where(is.numeric),
        list(
          n = ~n(),
          mean = ~mean(., na.rm = TRUE),
          sd = ~sd(., na.rm = TRUE)
        ),
        .names = "{.col}__{.fn}"
      ),
      .groups = "drop"
    )
}
# Identification des mesures répétées
identify_repeated_measures <- function(scores) {
  # Validation des colonnes
  if (!"person_id" %in% names(scores)) {
    stop("La colonne 'person_id' est manquante dans les scores.")
  }
  if (!"timestamp" %in% names(scores)) {
    stop("La colonne 'timestamp' est manquante dans les scores.")
  }
  
  # Conversion de 'timestamp' en date-heure si nécessaire
  if (!inherits(scores$timestamp, "POSIXct")) {
    scores <- scores %>%
      mutate(timestamp = ymd_hms(timestamp))
  }
  
  # Gérer les valeurs manquantes
  scores <- scores %>%
    filter(!is.na(person_id) & !is.na(timestamp))
  
  # Identification des mesures répétées
  scores %>%
    group_by(person_id) %>%
    summarise(
      n_measures = n(),
      first_measure = min(timestamp),
      last_measure = max(timestamp),
      time_span = as.numeric(difftime(max(timestamp), min(timestamp), units = "days"))
    ) %>%
    filter(n_measures > 1)
}