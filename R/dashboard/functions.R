read_dashboard_data <- function(data_dir = "data") {
  list(
    global = read_csv(file.path(data_dir, "global_summary.csv")),
    scores = read_csv(file.path(data_dir, "teacher_scores.csv")),
    metadata = read_csv(file.path(data_dir, "metadata.csv"))
  )
}

filter_teacher_data <- function(scores, teacher_id) {
  scores %>%
    filter(teacher_id == !!teacher_id) %>%
    arrange(timestamp)
}