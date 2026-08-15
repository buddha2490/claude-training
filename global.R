# global.R — Wu AI Harness
# Runs once at startup. Loads packages, data, and constants.

library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)

# --- Data --------------------------------------------------------------------
dm <- readRDS("data/dm.rds")

# --- Summary constants (used in home page value boxes) -----------------------
N_SUBJECTS  <- nrow(dm)
N_SITES     <- n_distinct(dm$SITEID)
N_COUNTRIES <- n_distinct(dm$COUNTRY)
N_ARMS      <- n_distinct(dm$ARMCD)
