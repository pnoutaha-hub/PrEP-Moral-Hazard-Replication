# =============================================================
# 01_clean_data.R
# Loads, cleans, and merges all datasets.
# Run AFTER 00_setup.R
# =============================================================

source("scripts/00_setup.R")
library(readxl)

# =============================================================
# PART 1: LOAD AND STACK PREP DATA (2012-2018)
# =============================================================

# Clean column names using position (avoids issues with \n in names)
clean_prep_names <- function(df) {
  names(df) <- c(
    "fips", "state_abbrev", "state", "prep_users", "prep_rate", "prep_rate_stability",
    "male_prep_users", "male_prep_rate", "male_prep_rate_stability",
    "female_prep_users", "female_prep_rate", "female_prep_rate_stability",
    "age_le24_users", "age_le24_rate", "age_le24_stability",
    "age_2534_users", "age_2534_rate", "age_2534_stability",
    "age_3544_users", "age_3544_rate", "age_3544_stability",
    "age_4554_users", "age_4554_rate", "age_4554_stability",
    "age_5564_users", "age_5564_rate", "age_5564_stability",
    "age_65plus_users", "age_65plus_rate", "age_65plus_stability",
    "black_prep_users", "black_prep_rate", "black_prep_stability",
    "white_prep_users", "white_prep_rate", "white_prep_stability",
    "hispanic_prep_users", "hispanic_prep_rate", "hispanic_prep_stability",
    "year"
  )
  df
}

# List all PrEP xlsx files in data/raw
prep_files <- list.files(
  path       = raw_data,
  pattern    = "prep_.*\\.xlsx",
  full.names = TRUE
)

cat("Found PrEP files:\n")
print(prep_files)

# Read, rename, and stack all years
prep_raw <- map_dfr(prep_files, function(file) {
  read_excel(file, skip = 3) %>%
    clean_prep_names()
})

# Clean PrEP data
prep_clean <- prep_raw %>%
  mutate(across(where(is.numeric), ~ ifelse(. < 0, NA, .))) %>%
  mutate(
    fips = as.numeric(fips),
    year = as.numeric(year)
  ) %>%
  select(
    fips, state_abbrev, state, year,
    prep_users, prep_rate,
    male_prep_users, male_prep_rate,
    female_prep_users, female_prep_rate,
    age_le24_users, age_le24_rate,
    age_2534_users, age_2534_rate,
    age_3544_users, age_3544_rate,
    age_4554_users, age_4554_rate,
    black_prep_users, black_prep_rate,
    white_prep_users, white_prep_rate,
    hispanic_prep_users, hispanic_prep_rate
  )

cat("PrEP data rows:", nrow(prep_clean), "\n")
cat("PrEP years covered:", paste(sort(unique(prep_clean$year)), collapse = ", "), "\n")

# =============================================================
# PART 2: LOAD AND CLEAN STI DATA (CDC NCHHSTP)
# =============================================================

# Helper function using readLines to handle CDC's quoted CSV format
clean_cdc <- function(filename, indicator_name) {
  # Read all lines, skip the 7 header rows, parse as CSV
  lines     <- readLines(file.path(raw_data, filename))
  data_lines <- lines[8:length(lines)]
  df <- read.csv(text = paste(data_lines, collapse = "\n")) %>%
    rename(
      indicator = Indicator,
      year      = Year,
      state     = Geography,
      fips      = FIPS,
      cases     = Cases,
      rate      = Rate.per.100000
    ) %>%
    mutate(
      # Remove commas from numbers e.g. "6,007" -> 6007
      cases = as.numeric(gsub(",", "", as.character(cases))),
      rate  = as.numeric(as.character(rate)),
      fips  = as.numeric(as.character(fips)),
      year  = as.numeric(as.character(year))
    ) %>%
    filter(year >= 2008, year <= 2018) %>%
    mutate(indicator = indicator_name) %>%
    select(fips, state, year, indicator, cases, rate)
  df
}

# Load each STI file
chlamydia <- clean_cdc("chlamydia_male.csv",     "chlamydia")
gonorrhea  <- clean_cdc("gonorrhea_male.csv",     "gonorrhea")
syphilis   <- clean_cdc("syphilis_male.csv",      "syphilis")
hiv <- clean_cdc("hiv_diagnosis_male.csv", "hiv")

cat("Chlamydia rows:", nrow(chlamydia), "\n")
cat("Gonorrhea rows:", nrow(gonorrhea),  "\n")
cat("Syphilis rows:",  nrow(syphilis),   "\n")
cat("HIV rows:",       nrow(hiv),        "\n")

# =============================================================
# PART 3: RESHAPE STI DATA TO WIDE FORMAT
# =============================================================

sti_wide <- bind_rows(chlamydia, gonorrhea, syphilis, hiv) %>%
  select(fips, state, year, indicator, rate) %>%
  pivot_wider(
    names_from  = indicator,
    values_from = rate
  ) %>%
  rename(
    chlamydia_rate = chlamydia,
    gonorrhea_rate = gonorrhea,
    syphilis_rate  = syphilis,
    hiv_rate       = hiv
  )

cat("STI wide rows:", nrow(sti_wide), "\n")

# =============================================================
# PART 4: MERGE STI + PREP DATA
# =============================================================

merged_data <- sti_wide %>%
  left_join(prep_clean, by = c("fips", "year")) %>%
  mutate(state = coalesce(state.x, state.y)) %>%
  select(-state.x, -state.y) %>%
  mutate(post_prep = ifelse(year >= 2012, 1, 0)) %>%
  filter(fips <= 56, fips != 11) %>%
  arrange(fips, year)

cat("\nMerged data rows:", nrow(merged_data), "\n")
cat("States:",            n_distinct(merged_data$state), "\n")
cat("Years:",             paste(sort(unique(merged_data$year)), collapse = ", "), "\n")
cat("Missing prep_rate:", sum(is.na(merged_data$prep_rate)), "rows\n")

# =============================================================
# PART 5: SAVE
# =============================================================

write_csv(merged_data, file.path(clean_data, "merged_data.csv"))
cat("\nSaved: merged_data.csv\n")

# =============================================================
# PART 6: ADD GOOGLE TRENDS GRINDR DATA
# =============================================================

library(gtrendsR)

years <- 2010:2018

trends_yearly <- map_dfr(years, function(yr) {
  cat("Pulling Grindr trends for year:", yr, "\n")
  Sys.sleep(2)  # pause to avoid being blocked by Google
  
  result <- tryCatch(
    gtrends(
      keyword = "Grindr",
      geo     = "US",
      time    = paste0(yr, "-01-01 ", yr, "-12-31")
    ),
    error = function(e) {
      cat("No data for year:", yr, "\n")
      NULL
    }
  )
  
  if (is.null(result)) return(NULL)
  
  result$interest_by_region %>%
    mutate(year = yr)
})

# Clean and merge
grindr_clean <- trends_yearly %>%
  rename(
    state        = location,
    grindr_index = hits
  ) %>%
  select(state, year, grindr_index) %>%
  mutate(grindr_index = ifelse(is.na(grindr_index), 0, grindr_index))

# Merge into main dataset
merged_data <- merged_data %>%
  left_join(grindr_clean, by = c("state", "year"))

cat("Grindr index added\n")
cat("Rows with grindr data:", sum(!is.na(merged_data$grindr_index)), "\n")

# Overwrite saved file
write_csv(merged_data, file.path(clean_data, "merged_data.csv"))
cat("Saved updated merged_data.csv\n")

glimpse(merged_data)
