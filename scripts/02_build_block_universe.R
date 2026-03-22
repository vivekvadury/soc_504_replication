# Purpose: Build the full 2020 Census block universe for the identified coastal-county analysis universe.
# Inputs: data/raw/metadata/legacy_county_universe.csv and Census API access.
# Outputs: Block-universe files and a concise universe statement.
# Dependencies: R/utils_io.R, R/utils_cleaning.R, tidyverse, tidycensus.

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

ensure_packages_installed(c("tidyverse", "tidycensus"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(tidycensus)
})

paths <- build_paths()
create_repo_dirs(paths)

county_seed <- readr::read_csv(
  file.path(paths$raw_metadata_dir, "legacy_county_universe.csv"),
  show_col_types = FALSE
) |>
  standardize_analysis_geoids() |>
  dplyr::mutate(
    state_fips = substr(county_geoid, 1, 2),
    county_fips = substr(county_geoid, 3, 5)
  ) |>
  dplyr::arrange(county_geoid)

county_request_groups <- county_seed |>
  dplyr::distinct(state_fips, county_fips) |>
  (\(x) split(x, x$state_fips))()

message("Pulling 2020 Census block populations for the analysis county universe...")

block_universe <- purrr::imap_dfr(
  county_request_groups,
  ~ run_with_retries(
    function() {
      tidycensus::get_decennial(
        geography = "block",
        state = .y,
        county = .x$county_fips,
        variables = c(total_population_2020 = "P1_001N"),
        year = 2020,
        sumfile = "pl",
        geometry = FALSE
      )
    },
    label = paste("Block population pull for state", .y)
  )
) |>
  dplyr::select(
    block_geoid = GEOID,
    total_population_2020 = value
  ) |>
  standardize_analysis_geoids() |>
  dplyr::mutate(
    tract_geoid = substr(block_geoid, 1, 11),
    county_geoid = substr(block_geoid, 1, 5),
    block_group_geoid = substr(block_geoid, 1, 12)
  ) |>
  dplyr::left_join(
    county_seed |>
      dplyr::select(county_geoid, state_code, state_name),
    by = "county_geoid"
  ) |>
  dplyr::arrange(block_geoid)

block_universe_summary <- tibble::tibble(
  metric = c(
    "counties",
    "tracts",
    "blocks",
    "zero_population_blocks"
  ),
  value = c(
    dplyr::n_distinct(block_universe$county_geoid),
    dplyr::n_distinct(block_universe$tract_geoid),
    nrow(block_universe),
    sum(block_universe$total_population_2020 == 0, na.rm = TRUE)
  )
)

block_universe_statement <- tibble::tribble(
  ~statement, ~detail,
  "County universe source", "Included repo seed copied from the identified legacy county universe",
  "Block universe rule", "All 2020 Census blocks in the seeded analysis counties",
  "Zero-population blocks retained", "Yes",
  "Exposure files define the universe", "No; they are joined after the universe is built",
  "Additional service-access or road filters applied here", "No"
)

write_rds_output(block_universe, file.path(paths$universe_dir, "block_universe.rds"))
write_csv_output(block_universe_summary, file.path(paths$universe_dir, "block_universe_summary.csv"))
write_csv_output(block_universe_statement, file.path(paths$universe_dir, "block_universe_statement.csv"))
write_csv_output(county_seed, file.path(paths$universe_dir, "analysis_county_seed.csv"))

message("Block universe build complete.")
