# dependencies.R
required_packages <- c(
  "tidyverse",  # Data manipulation
  "limer",      # LimeSurvey API
  "httr",       # HTTP requests
  "yaml",       # Config files
  "glue"        # String interpolation
)

# Fonction pour charger les packages
load_dependencies <- function() {
  for(pkg in required_packages) {
    if (!require(pkg, character.only = TRUE)) {
      stop(sprintf("Le package %s est requis", pkg))
    }
  }
}