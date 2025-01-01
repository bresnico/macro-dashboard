library(httr)

# Configuration Telegram
credentials <- yaml::read_yaml("src/config/credentials.yml")

bot_token <- credentials$telegram$bot_token
chat_id <- credentials$telegram$chat_id

# Fonction pour envoyer la notification
send_notification <- function(success) {
  if (!startsWith(chat_id, "-100")) {
    chat_id <- paste0("-100", gsub("-", "", chat_id))
  }
  
  status <- if(success) "✅ Succès" else "❌ Échec"
  message <- sprintf("🎯 Rendu dashboard\n\nStatus: %s", status)
  
  url <- paste0("https://api.telegram.org/bot", bot_token, "/sendMessage")
  body <- list(
    chat_id = chat_id,
    text = message,
    parse_mode = "HTML"
  )
  
  httr::POST(url, body = body, encode = "json")
}

# Exécution de la commande quarto avec try-catch
tryCatch({
  cmd_output <- system("quarto render dashboard.qmd", intern = TRUE)
  # Si on arrive ici, c'est que la commande a réussi
  send_notification(TRUE)
}, error = function(e) {
  # Si on arrive ici, c'est qu'il y a eu une erreur
  send_notification(FALSE)
})