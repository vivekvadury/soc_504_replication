# Purpose: Pull tract and county ACS covariates plus county and state geometries for the analysis universe.
# Inputs: data/derived/universe/block_universe.rds and Census API access.
# Outputs: ACS tract and county covariates, national baseline, crosswalks, and mapping geometries.
# Dependencies: R/utils_io.R, R/utils_cleaning.R, R/utils_geo.R, tidyverse, sf, tidycensus, tigris.

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
source(file.path(repo_root, "R", "utils_geo.R"))
initialize_project_context(repo_root)

ensure_packages_installed(c("tidyverse", "sf", "tidycensus", "tigris"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(tidycensus)
  library(tigris)
})

options(tigris_use_cache = TRUE)

paths <- build_paths()
create_repo_dirs(paths)

block_universe <- read_rds_required(file.path(paths$universe_dir, "block_universe.rds"))

county_universe <- block_universe |>
  dplyr::distinct(county_geoid, state_code, state_name)

tract_population_2020 <- block_universe |>
  dplyr::group_by(tract_geoid) |>
  dplyr::summarise(total_population_2020 = sum(total_population_2020, na.rm = TRUE), .groups = "drop")

county_population_2020 <- block_universe |>
  dplyr::group_by(county_geoid) |>
  dplyr::summarise(total_population_2020 = sum(total_population_2020, na.rm = TRUE), .groups = "drop")

state_codes <- sort(unique(county_universe$state_code))
county_geoids <- sort(unique(county_universe$county_geoid))

acs_variables <- c(
  median_age = "B01002_001",
  median_household_income = "B19013_001",
  total_population = "B01003_001",
  white_non_hispanic_population = "B03002_003",
  black_population = "B03002_004",
  hispanic_population = "B03002_012",
  occupied_housing_units = "B25003_001",
  renter_occupied_housing_units = "B25003_003"
)

message("Pulling ACS tract covariates...")
acs_tract_2019 <- purrr::map_dfr(
  state_codes,
  ~ run_with_retries(
    function() {
      tidycensus::get_acs(
        geography = "tract",
        state = .x,
        variables = acs_variables,
        year = 2019,
        survey = "acs5",
        geometry = FALSE
      )
    },
    label = paste("ACS tract pull for state", .x)
  )
) |>
  dplyr::filter(substr(GEOID, 1, 5) %in% county_geoids) |>
  tidyr::pivot_wider(
    id_cols = c(GEOID, NAME),
    names_from = variable,
    values_from = estimate
  ) |>
  dplyr::rename(
    tract_geoid = GEOID,
    tract_name = NAME
  ) |>
  dplyr::mutate(county_geoid = substr(tract_geoid, 1, 5)) |>
  standardize_analysis_geoids() |>
  prepare_acs_demographics() |>
  dplyr::left_join(tract_population_2020, by = "tract_geoid")

message("Pulling ACS county covariates...")
acs_county_2019 <- purrr::map_dfr(
  state_codes,
  ~ run_with_retries(
    function() {
      tidycensus::get_acs(
        geography = "county",
        state = .x,
        variables = acs_variables,
        year = 2019,
        survey = "acs5",
        geometry = FALSE
      )
    },
    label = paste("ACS county pull for state", .x)
  )
) |>
  dplyr::filter(GEOID %in% county_geoids) |>
  tidyr::pivot_wider(
    id_cols = c(GEOID, NAME),
    names_from = variable,
    values_from = estimate
  ) |>
  dplyr::rename(
    county_geoid = GEOID,
    county_name = NAME
  ) |>
  standardize_analysis_geoids() |>
  prepare_acs_demographics() |>
  dplyr::left_join(county_population_2020, by = "county_geoid") |>
  dplyr::left_join(county_universe, by = "county_geoid")

message("Pulling national 2020 race baseline...")
national_race_baseline_2020 <- dplyr::bind_rows(
  run_with_retries(
    function() {
      tidycensus::get_decennial(
        geography = "us",
        variables = c(
          total_population = "P1_001N",
          black_population = "P1_004N"
        ),
        year = 2020,
        sumfile = "pl"
      )
    },
    label = "National decennial pull (P1)"
  ),
  run_with_retries(
    function() {
      tidycensus::get_decennial(
        geography = "us",
        variables = c(
          hispanic_population = "P2_002N",
          white_non_hispanic_population = "P2_005N"
        ),
        year = 2020,
        sumfile = "pl"
      )
    },
    label = "National decennial pull (P2)"
  )
) |>
  dplyr::select(variable, value) |>
  tidyr::pivot_wider(names_from = variable, values_from = value) |>
  dplyr::mutate(
    pct_white_non_hispanic = percent_or_na(white_non_hispanic_population, total_population),
    pct_black = percent_or_na(black_population, total_population),
    pct_hispanic = percent_or_na(hispanic_population, total_population)
  )

tract_county_crosswalk <- block_universe |>
  dplyr::distinct(tract_geoid, county_geoid, state_code, state_name)

geography_objects <- download_analysis_geographies(
  state_codes = tract_county_crosswalk$state_code,
  county_geoids = tract_county_crosswalk$county_geoid
)

write_rds_output(acs_tract_2019, file.path(paths$census_dir, "acs_tract_2019.rds"))
write_rds_output(acs_county_2019, file.path(paths$census_dir, "acs_county_2019.rds"))
write_rds_output(national_race_baseline_2020, file.path(paths$census_dir, "national_race_baseline_2020.rds"))
write_rds_output(tract_county_crosswalk, file.path(paths$geography_dir, "tract_county_crosswalk.rds"))
write_rds_output(geography_objects$counties, file.path(paths$geography_dir, "analysis_counties.rds"))
write_rds_output(geography_objects$states, file.path(paths$geography_dir, "analysis_states.rds"))

write_csv_output(acs_tract_2019, file.path(paths$census_dir, "acs_tract_2019.csv"))
write_csv_output(acs_county_2019, file.path(paths$census_dir, "acs_county_2019.csv"))
write_csv_output(national_race_baseline_2020, file.path(paths$census_dir, "national_race_baseline_2020.csv"))
write_csv_output(tract_county_crosswalk, file.path(paths$geography_dir, "tract_county_crosswalk.csv"))

message("Census and geography pull complete.")
