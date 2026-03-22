# Purpose: Write table-ready CSV outputs for the main descriptive and modeling results.
# Inputs: Derived analysis datasets and model output tables.
# Outputs: Table CSV files in output/tables.
# Dependencies: R/utils_io.R, R/utils_cleaning.R, R/utils_figures.R, R/utils_modeling.R, tidyverse.

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
source(file.path(repo_root, "R", "utils_figures.R"))
source(file.path(repo_root, "R", "utils_modeling.R"))
initialize_project_context(repo_root)

ensure_packages_installed(c("tidyverse"))

suppressPackageStartupMessages(library(tidyverse))

paths <- build_paths()

national_race_summary <- read_rds_required(file.path(paths$analysis_dir, "national_race_summary.rds"))
county_analysis <- read_rds_required(file.path(paths$analysis_dir, "county_analysis.rds"))
tract_disparity_analysis <- read_rds_required(file.path(paths$analysis_dir, "tract_disparity_analysis.rds"))
model_coefficients <- readr::read_csv(
  file.path(paths$tables_dir, "model_coefficients.csv"),
  show_col_types = FALSE
)
model_fit_statistics <- readr::read_csv(
  file.path(paths$tables_dir, "model_fit_statistics.csv"),
  show_col_types = FALSE
)

table_county_disparity_counts <- county_analysis |>
  dplyr::filter(county_disparity_category != "neither") |>
  dplyr::count(rise_ft, county_disparity_category, name = "county_count") |>
  tidyr::pivot_wider(
    names_from = county_disparity_category,
    values_from = county_count,
    values_fill = 0
  )

table_tract_characteristics_by_disparity <- tract_disparity_analysis |>
  dplyr::group_by(rise_ft, disparity_category) |>
  dplyr::summarise(
    mean_income = mean(median_household_income, na.rm = TRUE),
    mean_pct_white = mean(pct_white_non_hispanic, na.rm = TRUE),
    mean_age = mean(median_age, na.rm = TRUE),
    n_tracts = dplyr::n(),
    .groups = "drop"
  ) |>
  dplyr::mutate(disparity_category = label_disparity_category(disparity_category))

table_1_model_coefficients <- build_model_table(model_coefficients)
table_1_model_fit_statistics <- build_model_fit_table(model_fit_statistics)

write_csv_output(national_race_summary, file.path(paths$tables_dir, "table_national_race_summary.csv"))
write_csv_output(table_county_disparity_counts, file.path(paths$tables_dir, "table_county_disparity_counts.csv"))
write_csv_output(
  table_tract_characteristics_by_disparity,
  file.path(paths$tables_dir, "table_tract_characteristics_by_disparity.csv")
)
write_csv_output(table_1_model_coefficients, file.path(paths$tables_dir, "table_1_model_coefficients.csv"))
write_csv_output(table_1_model_fit_statistics, file.path(paths$tables_dir, "table_1_model_fit_statistics.csv"))

message("Tables complete.")
