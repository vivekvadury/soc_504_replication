# Purpose: Build national, county, tract, and model-ready analysis datasets from the block universe and block-level exposures.
# Inputs: Derived block universe, ACS covariates, national baseline, and ingested block exposure files.
# Outputs: Analysis datasets, model dataset, and integrity summaries.
# Dependencies: R/utils_io.R, R/utils_cleaning.R, tidyverse.

find_project_root <- function(start_dir = getwd()) {
  current_dir <- normalizePath(start_dir, winslash = "/", mustWork = TRUE)

  repeat {
    sentinel_path <- file.path(current_dir, "soc_504_replication.Rproj")
    if (file.exists(sentinel_path)) {
      return(current_dir)
    }

    parent_dir <- dirname(current_dir)
    if (identical(parent_dir, current_dir)) {
      stop(
        "Could not find project root. Open the soc_504_replication project ",
        "or run this script from inside the repository.",
        call. = FALSE
      )
    }

    current_dir <- parent_dir
  }
}

repo_root <- find_project_root()
source(file.path(repo_root, "R", "utils_io.R"))
source(file.path(repo_root, "R", "utils_cleaning.R"))
initialize_project_context(repo_root)

ensure_packages_installed(c("tidyverse"))

suppressPackageStartupMessages(library(tidyverse))

paths <- build_paths()
create_repo_dirs(paths)

message("Reading universe, Census, and exposure inputs...")

block_universe <- read_rds_required(file.path(paths$universe_dir, "block_universe.rds"))
acs_tract_2019 <- read_rds_required(file.path(paths$census_dir, "acs_tract_2019.rds"))
acs_county_2019 <- read_rds_required(file.path(paths$census_dir, "acs_county_2019.rds"))
national_race_baseline_2020 <- read_rds_required(file.path(paths$census_dir, "national_race_baseline_2020.rds"))
isolation_block <- read_rds_required(file.path(paths$ingest_dir, "isolation_block.rds"))
inundation_block <- read_rds_required(file.path(paths$ingest_dir, "inundation_block.rds"))

rises <- tibble::tibble(rise_ft = 1:10)

tract_universe <- block_universe |>
  dplyr::group_by(tract_geoid, county_geoid, state_code, state_name) |>
  dplyr::summarise(
    total_population_2020 = sum(total_population_2020, na.rm = TRUE),
    n_blocks = dplyr::n(),
    zero_population_blocks = sum(total_population_2020 == 0, na.rm = TRUE),
    .groups = "drop"
  )

county_universe <- block_universe |>
  dplyr::group_by(county_geoid, state_code, state_name) |>
  dplyr::summarise(
    total_population_2020 = sum(total_population_2020, na.rm = TRUE),
    n_blocks = dplyr::n(),
    zero_population_blocks = sum(total_population_2020 == 0, na.rm = TRUE),
    .groups = "drop"
  )

isolation_tract_from_blocks <- isolation_block |>
  dplyr::group_by(rise_ft, tract_geoid) |>
  dplyr::summarise(
    isolated_population = sum(isolated_population, na.rm = TRUE),
    isolated_white_non_hispanic_population = sum(isolated_white_non_hispanic_population, na.rm = TRUE),
    isolated_black_population = sum(isolated_black_population, na.rm = TRUE),
    isolated_hispanic_population = sum(isolated_hispanic_population, na.rm = TRUE),
    .groups = "drop"
  )

isolation_county_from_blocks <- isolation_block |>
  dplyr::mutate(county_geoid = substr(block_geoid, 1, 5)) |>
  dplyr::group_by(rise_ft, county_geoid) |>
  dplyr::summarise(
    isolated_population = sum(isolated_population, na.rm = TRUE),
    isolated_white_non_hispanic_population = sum(isolated_white_non_hispanic_population, na.rm = TRUE),
    isolated_black_population = sum(isolated_black_population, na.rm = TRUE),
    isolated_hispanic_population = sum(isolated_hispanic_population, na.rm = TRUE),
    .groups = "drop"
  )

isolation_country_from_blocks <- isolation_block |>
  dplyr::group_by(rise_ft) |>
  dplyr::summarise(
    isolated_population = sum(isolated_population, na.rm = TRUE),
    isolated_white_non_hispanic_population = sum(isolated_white_non_hispanic_population, na.rm = TRUE),
    isolated_black_population = sum(isolated_black_population, na.rm = TRUE),
    isolated_hispanic_population = sum(isolated_hispanic_population, na.rm = TRUE),
    .groups = "drop"
  )

inundation_tract_from_blocks <- inundation_block |>
  dplyr::group_by(rise_ft, tract_geoid) |>
  dplyr::summarise(
    inundated_population = sum(inundated_population, na.rm = TRUE),
    inundated_white_non_hispanic_population = sum(inundated_white_non_hispanic_population, na.rm = TRUE),
    inundated_black_population = sum(inundated_black_population, na.rm = TRUE),
    inundated_hispanic_population = sum(inundated_hispanic_population, na.rm = TRUE),
    .groups = "drop"
  )

county_baseline <- acs_county_2019 |>
  dplyr::transmute(
    county_geoid,
    county_name,
    state_code,
    state_name,
    total_population_2020,
    county_pct_white_non_hispanic = pct_white_non_hispanic,
    county_pct_black = pct_black,
    county_pct_hispanic = pct_hispanic,
    county_pct_renter_households = pct_renter_households,
    county_median_household_income = median_household_income,
    county_median_age = median_age
  )

national_baseline_long <- national_race_baseline_2020 |>
  dplyr::transmute(
    white_non_hispanic = pct_white_non_hispanic,
    black = pct_black,
    hispanic = pct_hispanic
  ) |>
  tidyr::pivot_longer(
    cols = dplyr::everything(),
    names_to = "race_group",
    values_to = "national_share_percent"
  )

message("Constructing national summary...")

national_race_summary <- isolation_country_from_blocks |>
  dplyr::transmute(
    rise_ft,
    white_non_hispanic = percent_or_na(
      isolated_white_non_hispanic_population,
      isolated_population
    ),
    black = percent_or_na(
      isolated_black_population,
      isolated_population
    ),
    hispanic = percent_or_na(
      isolated_hispanic_population,
      isolated_population
    )
  ) |>
  tidyr::pivot_longer(
    cols = c(white_non_hispanic, black, hispanic),
    names_to = "race_group",
    values_to = "isolated_share_percent"
  ) |>
  dplyr::left_join(national_baseline_long, by = "race_group")

message("Constructing county analysis...")

county_analysis <- tidyr::crossing(county_universe, rises) |>
  dplyr::left_join(
    isolation_county_from_blocks,
    by = c("county_geoid", "rise_ft")
  ) |>
  fill_missing_isolation_zero() |>
  dplyr::left_join(
    county_baseline,
    by = c("county_geoid", "state_code", "state_name", "total_population_2020")
  ) |>
  dplyr::mutate(
    isolated_share_percent = percent_or_na(isolated_population, total_population_2020),
    isolated_black_share_percent = percent_or_na(isolated_black_population, isolated_population),
    isolated_hispanic_share_percent = percent_or_na(isolated_hispanic_population, isolated_population),
    isolated_white_non_hispanic_share_percent = percent_or_na(
      isolated_white_non_hispanic_population,
      isolated_population
    ),
    black_disparity_ratio = safe_divide(isolated_black_share_percent, county_pct_black),
    hispanic_disparity_ratio = safe_divide(isolated_hispanic_share_percent, county_pct_hispanic),
    county_disparity_category = classify_disparity(
      black_disparity_ratio,
      hispanic_disparity_ratio
    )
  )

message("Constructing tract analysis and model data...")

tract_analysis_base <- tidyr::crossing(tract_universe, rises) |>
  dplyr::left_join(
    isolation_tract_from_blocks,
    by = c("tract_geoid", "rise_ft")
  ) |>
  fill_missing_isolation_zero() |>
  dplyr::left_join(
    inundation_tract_from_blocks,
    by = c("tract_geoid", "rise_ft")
  ) |>
  fill_missing_inundation_zero() |>
  dplyr::left_join(
    acs_tract_2019 |>
      dplyr::select(
        tract_geoid,
        tract_name,
        median_age,
        median_household_income,
        log_median_household_income,
        total_population,
        white_non_hispanic_population,
        black_population,
        hispanic_population,
        occupied_housing_units,
        renter_occupied_housing_units,
        pct_white_non_hispanic,
        pct_black,
        pct_hispanic,
        pct_renter_households
      ),
    by = "tract_geoid"
  ) |>
  dplyr::left_join(
    county_baseline |>
      dplyr::select(
        county_geoid,
        county_name,
        county_pct_white_non_hispanic,
        county_pct_black,
        county_pct_hispanic
      ),
    by = "county_geoid"
  ) |>
  dplyr::mutate(
    isolated_share_percent = percent_or_na(isolated_population, total_population_2020),
    inundated_share_percent = percent_or_na(inundated_population, total_population_2020),
    missing_population_raw = isolated_population - inundated_population,
    missing_population = pmax(missing_population_raw, 0),
    negative_missing_flag = missing_population_raw < 0,
    missing_share_percent = percent_or_na(missing_population, isolated_population),
    missing_share_of_tract_population = percent_or_na(missing_population, total_population_2020),
    isolated_black_share_percent = percent_or_na(isolated_black_population, isolated_population),
    isolated_hispanic_share_percent = percent_or_na(isolated_hispanic_population, isolated_population),
    isolated_white_non_hispanic_share_percent = percent_or_na(
      isolated_white_non_hispanic_population,
      isolated_population
    ),
    black_disparity_ratio = safe_divide(isolated_black_share_percent, county_pct_black),
    hispanic_disparity_ratio = safe_divide(isolated_hispanic_share_percent, county_pct_hispanic),
    disparity_category = classify_disparity(black_disparity_ratio, hispanic_disparity_ratio)
  )

tract_disparity_analysis <- tract_analysis_base
tract_model_dataset <- tract_analysis_base

analysis_inventory <- tibble::tibble(
  dataset_name = c(
    "national_race_summary",
    "county_analysis",
    "tract_disparity_analysis",
    "tract_model_dataset"
  ),
  rows = c(
    nrow(national_race_summary),
    nrow(county_analysis),
    nrow(tract_disparity_analysis),
    nrow(tract_model_dataset)
  )
)

integrity_summary <- tibble::tibble(
  metric = c(
    "county_rows",
    "tract_rows",
    "negative_missing_rows",
    "county_rows_with_black_disparity",
    "county_rows_with_hispanic_disparity"
  ),
  value = c(
    nrow(county_analysis),
    nrow(tract_disparity_analysis),
    sum(tract_disparity_analysis$negative_missing_flag, na.rm = TRUE),
    sum(county_analysis$black_disparity_ratio > 1, na.rm = TRUE),
    sum(county_analysis$hispanic_disparity_ratio > 1, na.rm = TRUE)
  )
)

write_rds_output(national_race_summary, file.path(paths$analysis_dir, "national_race_summary.rds"))
write_rds_output(county_analysis, file.path(paths$analysis_dir, "county_analysis.rds"))
write_rds_output(tract_disparity_analysis, file.path(paths$analysis_dir, "tract_disparity_analysis.rds"))
write_rds_output(tract_model_dataset, file.path(paths$analysis_dir, "tract_model_dataset.rds"))

write_csv_output(national_race_summary, file.path(paths$analysis_dir, "national_race_summary.csv"))
write_csv_output(county_analysis, file.path(paths$analysis_dir, "county_analysis.csv"))
write_csv_output(analysis_inventory, file.path(paths$analysis_dir, "analysis_inventory.csv"))
write_csv_output(integrity_summary, file.path(paths$analysis_dir, "integrity_summary.csv"))

message("Analysis data construction complete.")
