# Purpose: Run the full standalone replication pipeline from a clean session.
# Inputs: Repo-internal raw SLR files plus programmatic Census and TIGER pulls.
# Outputs: Derived data, figures, tables, and run logs.
# Dependencies: Base R only.

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
scripts_dir <- file.path(repo_root, "scripts")

script_files <- c(
  "01_setup.R",
  "02_build_block_universe.R",
  "03_pull_census_and_geography.R",
  "04_load_slr_exposure_data.R",
  "05_construct_analysis_data.R",
  "06_make_figures.R",
  "07_run_models.R",
  "08_make_tables.R"
)

for (script_name in script_files) {
  message("Running ", script_name, "...")
  source(file.path(scripts_dir, script_name), chdir = TRUE, echo = FALSE)
}

message("Standalone replication pipeline complete.")
