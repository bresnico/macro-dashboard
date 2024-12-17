
# 1. Chargement des packages
library(shiny)
library(bslib)
library(tidyverse)
library(lubridate)
library(yaml)
library(limer)
library(DT)

# 2. Chargement de la configuration
config <- yaml::read_yaml("config/scales_definition.yml")

# 3. Chargement de toutes les fonctions
source("R/functions.R")