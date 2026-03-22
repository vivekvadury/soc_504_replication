# Purpose: Prepare directories, install or restore packages, and validate required inputs.
# Inputs: Repo-local raw SLR files and metadata seeds.
# Outputs: Setup log and ready-to-run project folders.
# Dependencies: R/utils_io.R and CRAN packages installed as needed.

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
initialize_project_context(repo_root)

paths <- build_paths()
create_repo_dirs(paths)

install_if_missing("renv")

required_packages <- c(
  "tidyverse",
  "sf",
  "tidycensus",
  "tigris",
  "broom",
  "scales"
)

missing_required_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (file.exists(file.path(repo_root, "renv.lock"))) {
  if (length(missing_required_packages) > 0) {
    restore_succeeded <- tryCatch(
      {
        original_options <- options(
          repos = c(CRAN = "https://cran.rstudio.com"),
          download.file.method = "wininet",
          pkgType = "binary"
        )
        on.exit(options(original_options), add = TRUE)
        Sys.setenv(RENV_DOWNLOAD_METHOD = "wininet")
        renv::restore(project = repo_root, prompt = FALSE)
        TRUE
      },
      error = function(e) {
        message(
          "renv restore failed; falling back to direct CRAN installs for required packages. ",
          "Details: ", conditionMessage(e)
        )
        FALSE
      }
    )

    if (!restore_succeeded) {
      ensure_packages_installed(required_packages)
    }
  }
} else {
  if (length(missing_required_packages) > 0) {
    ensure_packages_installed(required_packages)
  }
}

suppressPackageStartupMessages(library(tidycensus))

options(tigris_use_cache = TRUE)
Sys.setenv(CENSUS_API_KEY = "ff5d487d0a2a22c658bf319ba136c27db32aa0be")

api_key_mode <- tryCatch(
  {
    tidycensus::census_api_key(
      "ff5d487d0a2a22c658bf319ba136c27db32aa0be",
      install = TRUE,
      overwrite = TRUE
    )
    "installed_to_user_profile"
  },
  error = function(e) {
    message(
      "Could not write Census API key to the user profile; using the session ",
      "environment variable instead. Details: ", conditionMessage(e)
    )
    Sys.setenv(CENSUS_API_KEY = "ff5d487d0a2a22c658bf319ba136c27db32aa0be")
    "session_only"
  }
)

required_files <- c(
  file.path("data", "raw", "slr", "isolation_block.csv"),
  file.path("data", "raw", "slr", "inundation_block.csv"),
  file.path("data", "raw", "metadata", "legacy_county_universe.csv"),
  file.path("data", "raw", "metadata", "nhgis_block_codebook.txt")
)

check_required_files(repo_root, required_files)

setup_log <- data.frame(
  item = c(
    "project_root",
    "raw_slr_dir",
    "raw_metadata_dir",
    "api_key_mode",
    "setup_timestamp"
  ),
  value = c(
    repo_root,
    paths$raw_slr_dir,
    paths$raw_metadata_dir,
    api_key_mode,
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ),
  stringsAsFactors = FALSE
)

write_csv_output(setup_log, file.path(paths$logs_dir, "setup_log.csv"))

message("Setup complete.")
