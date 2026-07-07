# =============================================================
# 02_analysis.R
# Runs replication models and extension models.
# Run AFTER 01_clean_data.R
# =============================================================

source("scripts/00_setup.R")

# Load cleaned data
# merged_data <- read_csv(file.path(clean_data, "merged_data.csv"))

# =============================================================
# REPLICATION
# =============================================================

# --- Difference-in-Differences (DiD) ---
# Main model from Eilam & Delhommer
# Outcome: STI rate (chlamydia, gonorrhea, syphilis)
# Treatment: PrEP adoption rate
# Fixed effects: state + year

# did_model <- feols(
#   sti_rate ~ prep_rate | state + year,
#   data = merged_data,
#   vcov = "hetero"  # robust standard errors
# )
# summary(did_model)

# --- Triple Difference (DDD) ---
# Adds sex as a third dimension (men vs women as control group)

# ddd_model <- feols(
#   sti_rate ~ prep_rate:male | state + year + state:male,
#   data = merged_data,
#   vcov = "hetero"
# )
# summary(ddd_model)

# =============================================================
# EXTENSION
# =============================================================

# --- Subgroup analysis by demographics ---
# Does the PrEP effect on STIs vary by age group, race, income?

# extension_model <- feols(
#   sti_rate ~ prep_rate:age_group | state + year,
#   data = merged_data,
#   vcov = "hetero"
# )
# summary(extension_model)

# --- Google Trends interaction ---
# Does higher regional app engagement amplify the PrEP effect?

# trends_model <- feols(
#   sti_rate ~ prep_rate * trends_index | state + year,
#   data = merged_data,
#   vcov = "hetero"
# )
# summary(trends_model)
