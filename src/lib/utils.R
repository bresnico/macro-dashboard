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