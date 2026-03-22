# Purpose: Read repo-local SLR exposure inputs and save standardized ingest files.
# Inputs: data/raw/slr/isolation_block.csv and data/raw/slr/inundation_block.csv.
# Outputs: Standardized block-level exposure RDS files and an ingest inventory.
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

message("Reading SLR exposure inputs...")

isolation_block <- read_without_zero_csv(
  file.path(paths$raw_slr_dir, "isolation_block.csv")
) |>
  rename_exposure_columns("isolation")

inundation_block <- read_without_zero_csv(
  file.path(paths$raw_slr_dir, "inundation_block.csv")
) |>
  rename_exposure_columns("inundation")

ingest_inventory <- tibble::tibble(
  dataset_name = c("isolation_block", "inundation_block"),
  rows = c(nrow(isolation_block), nrow(inundation_block)),
  unique_blocks = c(
    dplyr::n_distinct(isolation_block$block_geoid),
    dplyr::n_distinct(inundation_block$block_geoid)
  ),
  rise_min = c(
    min(isolation_block$rise_ft, na.rm = TRUE),
    min(inundation_block$rise_ft, na.rm = TRUE)
  ),
  rise_max = c(
    max(isolation_block$rise_ft, na.rm = TRUE),
    max(inundation_block$rise_ft, na.rm = TRUE)
  )
)

write_rds_output(isolation_block, file.path(paths$ingest_dir, "isolation_block.rds"))
write_rds_output(inundation_block, file.path(paths$ingest_dir, "inundation_block.rds"))
write_csv_output(ingest_inventory, file.path(paths$ingest_dir, "ingest_inventory.csv"))

message("Exposure ingest complete.")
