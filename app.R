# 1. Chargement du fichier global.R et des modules
source("global.R")

# Chargement des interfaces utilisateur
source("R/dashboard/ui/teacher_ui.R")
source("R/dashboard/ui/director_ui.R")
source("R/dashboard/ui/researcher_ui.R")

# Chargement des logiques serveur
source("R/dashboard/server/teacher_server.R")
source("R/dashboard/server/director_server.R")
source("R/dashboard/server/researcher_server.R")

# Chargement des identifiants chercheurs
credentials <- yaml::read_yaml("config/credentials.yml")

# L'UI
ui <- fluidPage(
  theme = bs_theme(
    version = 5,
    bootswatch = "litera",
    primary = "#2C3E50"
  ),
  
  # En-tête
  div(
    class = "container-fluid bg-primary text-white p-3 mb-4",
    h1("Plateforme d'évaluation", class = "h3")
  ),
  
  # Corps principal
  sidebarLayout(
    sidebarPanel(
      # Type d'utilisateur
      selectInput("user_type", 
                  "Type d'utilisateur",
                  choices = c(
                    "Enseignant" = "teacher",
                    "Direction" = "director",
                    "Chercheur" = "researcher"
                  )),
      
      # Champ d'identifiant (rendu dynamiquement)
      uiOutput("id_field"),
      
      # Bouton pour voir les données
      div(
        class = "card p-3 mt-3",
        actionButton("view_data", 
                     "Voir les données",
                     class = "btn-primary w-100"),
        
        # Indicateur de statut
        div(
          id = "connection_status",
          class = "mt-3 text-muted",
          "État de la connexion : en attente"
        )
      )
    ),
    
    mainPanel(
      # Interface conditionnelle selon le type d'utilisateur
      conditionalPanel(
        condition = "input.user_type == 'teacher'",
        teacher_ui()
      ),
      
      conditionalPanel(
        condition = "input.user_type == 'director'",
        director_ui()
      ),
      
      conditionalPanel(
        condition = "input.user_type == 'researcher'",
        researcher_ui(config)
      )
    )
  )
)

# Le serveur
server <- function(input, output, session) {
  
  # UI conditionnelle pour le champ d'identification
  output$id_field <- renderUI({
    field_label <- switch(input$user_type,
                          "teacher" = "Votre identifiant personnel",
                          "director" = "Code de l'établissement",
                          "researcher" = "Code chercheur")
    
    field_placeholder <- switch(input$user_type,
                                "teacher" = "01NS14",
                                "director" = "un",
                                "researcher" = "RES001")
    
    textInput("user_id", 
              field_label, 
              placeholder = field_placeholder)
  })
  
  # Reactive value pour stocker les données
  survey_data <- reactiveVal(NULL)
  
  # Reactive value pour stocker la validité de l'identifiant
  valid_id <- reactiveVal(FALSE)
  
  # Chargement des données et validation de l'identifiant
  observeEvent(input$view_data, {
    # Informer l'utilisateur
    showNotification("Chargement des données...", 
                     type = "message", 
                     id = "loading")
    
    tryCatch({
      # Test de connexion
      if (!setup_limesurvey_connection()) {
        removeNotification("loading")
        showNotification("Erreur de connexion à LimeSurvey", 
                         type = "error")
        valid_id(FALSE)
        return()
      }
      
      # Chargement des données
      data <- get_limesurvey_data(637555, config = config)
      
      if (is.null(data) || nrow(data) == 0) {
        removeNotification("loading")
        showNotification("Aucune donnée disponible", 
                         type = "warning")
        valid_id(FALSE)
        return()
      }
      
      # Traitement des données et conversion des dates
      processed_data <- data %>%
        standardize_limesurvey_names(config) %>%
        convert_responses(config) %>%
        mutate(
          submitdate = ymd_hms(submitdate),
          startdate = ymd_hms(startdate),
          datestamp  = ymd_hms(datestamp),
          timestamp  = submitdate
        )
      
      # Afficher les noms des colonnes
      print("Colonnes de processed_data :")
      print(names(processed_data))
      
      survey_data(processed_data)
      
      # Validation de l'identifiant pour enseignants et directeurs
      user_type <- input$user_type
      user_id <- input$user_id
      
      if (user_type == "teacher") {
        valid_ids <- unique(processed_data$g01q13)
      } else if (user_type == "director") {
        valid_ids <- unique(processed_data$groupecode)
      } else if (user_type == "researcher") {
        valid_ids <- credentials$researcher_codes
      }
      
      if (user_id %in% valid_ids) {
        valid_id(TRUE)
        showNotification("Données chargées avec succès", 
                         type = "message")
      } else {
        valid_id(FALSE)
        showNotification("Le code saisi est inconnu.", 
                         type = "error")
      }
      
      removeNotification("loading")
      
    }, error = function(e) {
      removeNotification("loading")
      showNotification(
        paste("Erreur lors du chargement :", e$message), 
        type = "error"
      )
      valid_id(FALSE)
    })
  })
  
  # Appel des serveurs spécifiques selon le type d'utilisateur
  observeEvent(input$view_data, {
    req(valid_id())
    
    if(input$user_type == "teacher") {
      teacher_server(input, output, session, survey_data, config)
    } else if(input$user_type == "director") {
      director_server(input, output, session, survey_data, config)
    } else if(input$user_type == "researcher") {
      researcher_server(input, output, session, survey_data, config, credentials)
    }
  })
}


# Lancement de l'app
shinyApp(ui = ui, server = server)