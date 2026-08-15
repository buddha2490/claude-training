# setup.R — Wu AI Harness Training Environment Setup
# =============================================================================
# Run this script ONCE after cloning the repository.
#
# In the Positron console, type:
#   source("setup.R")
#
# What it does:
#   1. Installs all required R packages from the lockfile (renv::restore)
#   2. Loads each package to confirm everything works
#
# This will take several minutes on a fresh machine. Subsequent runs are fast.
# =============================================================================

# --- Step 1a: Install R packages ---------------------------------------------
# renv::restore() reads renv.lock and installs the exact package versions
# used in this project. Packages are downloaded from CRAN automatically.

message("\nStep 1a: Installing R packages from renv.lock...")
message("(This may take several minutes on a fresh machine — please wait)\n")
renv::restore()
message("\nR packages installed.\n")

# --- Step 1b: Install CDISC RAG server dependencies -------------------------
# The RAG MCP server (rag/server.js) needs two small Node.js packages.
# Node.js is already installed on your machine as a Claude Code dependency.

message("Step 1b: Installing RAG server dependencies (npm)...")
result <- system("npm --prefix rag install", intern = FALSE)
if (result != 0L) {
  warning("npm install failed. Check that Node.js is installed and on your PATH.")
} else {
  message("RAG server dependencies installed.\n")
}

message("All packages installed. Loading them now to verify...\n")

# --- Step 2: Verify — load every package -------------------------------------
# If any library() call fails, a package was not installed correctly.
# Report the error to your instructor.

# Core Shiny
library(shiny)            # Shiny web framework
library(bslib)            # Bootstrap theming and layout
library(bsicons)          # Bootstrap icons
library(shinyjs)          # JavaScript helpers for Shiny
library(shinyWidgets)     # Enhanced UI widgets
library(shinycssloaders)  # Loading spinners
library(shinybusy)        # Busy indicators
library(shinyvalidate)    # Form validation
library(htmltools)        # HTML generation utilities
library(htmlwidgets)      # JavaScript widget framework

# Dashboard Layouts
library(shinydashboard)   # Classic shinydashboard layout
library(bs4Dash)          # Bootstrap 4 dashboards
library(fresh)            # Custom theming
library(waiter)           # Full-page loading screens
library(sortable)         # Drag-and-drop UI elements

# Tables
library(DT)               # DataTables (interactive HTML tables)
library(reactable)        # React-based tables
library(gt)               # Publication-quality tables
library(gtsummary)        # Summary statistics tables

# Visualization
library(ggplot2)          # Grammar of graphics
library(plotly)           # Interactive plots
library(ggiraph)          # Interactive ggplot2
library(ggrepel)          # Non-overlapping labels
library(ggridges)         # Ridgeline plots
library(crosstalk)        # Linked widgets across htmlwidgets
library(leaflet)          # Interactive maps
library(visNetwork)       # Network visualization

# Tidyverse + Data
library(tidyverse)        # Core tidyverse (dplyr, tidyr, readr, purrr, tibble,
                          #   stringr, forcats, lubridate, ggplot2, etc.)
library(haven)            # Read/write SAS, SPSS, Stata files
library(readxl)           # Read Excel files
library(janitor)          # Data cleaning utilities
library(data.table)       # High-performance data manipulation
library(arrow)            # Apache Arrow / Parquet support
library(here)             # Project-relative file paths
library(fs)               # File system operations
library(glue)             # String interpolation

# CDISC / Pharma
library(pharmaverse)      # Pharmaverse meta-package

# Error Handling / Logging
library(log4r)            # Structured logging (project standard)
library(config)           # Environment-based configuration
library(conflicted)       # Make namespace conflicts explicit errors

# Async / Parallel
library(promises)         # Async promise support for Shiny
library(future)           # Parallel and async computation
library(mirai)            # Lightweight async (nanonext-based)

# Development Tools
library(devtools)         # Package development helpers
library(usethis)          # Project setup automation
library(testthat)         # Unit testing framework
library(shinytest2)       # End-to-end Shiny app testing
library(golem)            # Shiny app framework (package-based)

# Quarto / R Markdown
library(rmarkdown)        # R Markdown documents
library(knitr)            # Knitting engine
library(quarto)           # Quarto integration
library(tinytex)          # Lightweight LaTeX for PDF output

# Utilities
library(jsonlite)         # JSON parsing and generation
library(httr2)            # Modern HTTP client
library(scales)           # Scale functions for visualization
library(lubridate)        # Date/time manipulation (also in tidyverse)
library(uuid)             # UUID generation
library(rstudioapi)       # IDE integration helpers

message("\nSetup complete! Your environment is ready for the training.\n")
