# =============================================================
# 00_setup.R
# Run this script first every time before anything else.
# It installs/loads all packages and defines file paths.
# =============================================================

# --- 1. Install packages (only runs if not already installed) ---
packages <- c(
  "tidyverse",   # data cleaning and manipulation
  "plm",         # panel data models (fixed effects)
  "lmtest",      # hypothesis testing
  "sandwich",    # robust standard errors
  "modelsummary",# clean regression tables
  "ggplot2",     # figures
  "readr",       # reading CSVs
  "lubridate",   # date handling
  "tidycensus",  # ACS demographic data
  "gtrendsR",    # Google Trends data
  "fixest",      # fast fixed effects (alternative to plm)
  "knitr",       # tables in Quarto
  "kableExtra"   # prettier tables
)

installed <- rownames(installed.packages())
to_install <- packages[!packages %in% installed]
if (length(to_install) > 0) install.packages(to_install)

lapply(packages, library, character.only = TRUE)

# --- 2. File paths ---
# CHANGE THIS LINE to match your Posit Cloud project folder path
project_path <- "/cloud/project"  # default in Posit Cloud

raw_data     <- file.path(project_path, "data/raw")
clean_data   <- file.path(project_path, "data/clean")
scripts      <- file.path(project_path, "scripts")
outputs      <- file.path(project_path, "outputs")

# --- 3. Confirm folders exist ---
dirs <- c(raw_data, clean_data, scripts, outputs)
for (d in dirs) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  cat("OK:", d, "\n")
}

cat("\nSetup complete. Ready to load data.\n")
