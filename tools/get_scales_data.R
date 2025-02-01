# Chargement des packages nécessaires
library(yaml)
library(officer)
library(dplyr)

#' Formate les items inversés d'une échelle
#' @param scale Une échelle du fichier YAML
#' @return Une chaîne de caractères décrivant les items inversés
format_reversed_items <- function(scale) {
  # Trouve les items inversés
  reversed_items <- which(sapply(scale$items, function(x) isTRUE(x$reversed)))
  
  if (length(reversed_items) == 0) {
    return("Items inversés : aucun")
  } else {
    # Extrait les 2 derniers chiffres de l'id pour chaque item inversé
    item_numbers <- sapply(scale$items[reversed_items], function(x) {
      substr(x$id, nchar(x$id)-1, nchar(x$id))
    })
    return(sprintf("Items inversés : %s", paste(item_numbers, collapse = ", ")))
  }
}

#' Format les items d'une sous-échelle
#' @param subscale Une sous-échelle du fichier YAML
#' @return Une chaîne de caractères listant les items
format_subscale_items <- function(subscale) {
  if (length(subscale$items) == 0) {
    return("Pas d'items")
  } else {
    # Extrait les 2 derniers chiffres de chaque id comme pour les items inversés
    item_numbers <- sapply(subscale$items, function(x) {
      substr(x, nchar(x)-1, nchar(x))
    })
    return(sprintf("Items : %s", paste(item_numbers, collapse = ", ")))
  }
}

#' Formate les sous-échelles
#' @param scale Une échelle du fichier YAML
#' @return Une chaîne de caractères listant les sous-échelles
format_subscales <- function(scale) {
  if (!is.null(scale$scoring$subscales)) {
    subscales <- names(scale$scoring$subscales)
    labels <- sapply(scale$scoring$subscales, function(x) {
      sprintf("%s (catégorie: %s)", x$label, x$category)
    })
    paste0("\n", paste(labels, collapse = "\n"))
  } else {
    "Pas de sous-échelles"
  }
}

#' Génère un document Word décrivant les échelles psychométriques
#' @param yaml_file Chemin vers le fichier YAML
#' @param output_file Nom du fichier Word à générer
generate_scales_doc <- function(yaml_file = "src/config/scales.yml", 
                              output_file = "output/echelles_description.docx") {
  # Lecture du fichier YAML
  scales_data <- read_yaml(yaml_file)
  
  # Création d'un nouveau document Word
  doc <- read_docx()
  
  # Pour chaque échelle
  for (scale_id in names(scales_data$scales)) {
    scale <- scales_data$scales[[scale_id]]
    
    # Titre de l'échelle
    doc <- doc %>%
      body_add_par(scale$label, style = "heading 1") %>%
      body_add_par("", style = "Normal")
    
    # Description
    if (!is.null(scale$description)) {
      doc <- doc %>%
        body_add_par("Description :", style = "heading 2") %>%
        body_add_par(scale$description, style = "Normal") %>%
        body_add_par("", style = "Normal")
    }
    
    # Référence
    if (!is.null(scale$reference)) {
      doc <- doc %>%
        body_add_par("Référence :", style = "heading 2") %>%
        body_add_par(scale$reference, style = "Normal") %>%
        body_add_par("", style = "Normal")
    }
    
    # Informations techniques
    doc <- doc %>%
      body_add_par("Informations techniques :", style = "heading 2") %>%
      body_add_par(
        sprintf("Type : Échelle de Likert à %d points (%d-%d)",
                scales_data$scale_types[[scale$type]]$max_value,
                scales_data$scale_types[[scale$type]]$min_value,
                scales_data$scale_types[[scale$type]]$max_value),
        style = "Normal"
      ) %>%
      body_add_par(
        sprintf("Nombre d'items : %d", length(scale$items)),
        style = "Normal"
      )
    
    # Score total - nouvelle structure
    scoring_info <- scale$scoring
    if(is.list(scoring_info$total) && isTRUE(scoring_info$total$enabled)) {
      doc <- doc %>%
        body_add_par(
          sprintf("Score total : Oui (catégorie : %s)",
                  scoring_info$total$category),
          style = "Normal"
        )
    } else {
      doc <- doc %>%
        body_add_par("Score total : Non", style = "Normal")
    }
    
    # Items inversés
    doc <- doc %>%
      body_add_par(format_reversed_items(scale),
                  style = "Normal") %>%
      body_add_par("", style = "Normal")
    
    # Sous-échelles
    doc <- doc %>%
      body_add_par("Sous-échelles :", style = "heading 2")
    
    if (!is.null(scoring_info$subscales)) {
      for (subscale_name in names(scoring_info$subscales)) {
        subscale <- scoring_info$subscales[[subscale_name]]
        doc <- doc %>%
          body_add_par(
            sprintf("%s (catégorie : %s)", 
                    subscale$label,
                    subscale$category),
            style = "Normal"
          ) %>%
          body_add_par(
            format_subscale_items(subscale),
            style = "Normal"
          ) %>%
          body_add_par("", style = "Normal")
      }
    } else {
      doc <- doc %>%
        body_add_par("Pas de sous-échelles", style = "Normal") %>%
        body_add_par("", style = "Normal")
    }
    
    # Ajoute un saut de page entre les échelles
    doc <- doc %>% 
      body_add_break()
  }
  
  # Création du dossier de sortie si nécessaire
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Sauvegarde du document
  print(doc, target = output_file)
}

# Exécution du script
generate_scales_doc()
