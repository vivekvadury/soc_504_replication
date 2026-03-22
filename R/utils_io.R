# Purpose: Shared helpers for package setup, repo-root discovery, project paths, and file IO.
# Inputs: Called by top-level scripts in this repository.
# Outputs: Path lists, directory creation, and read/write helpers.
# Dependencies: Base R only.

bootstrap_library <- function() {
  root <- tryCatch(
    getOption("soc_504_replication_root", default = locate_project_root()),
    error = function(e) locate_project_root()
  )

  lib_path <- file.path(root, ".bootstrap_lib")
  dir.create(lib_path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(lib_path, winslash = "/", mustWork = TRUE)
}

set_bootstrap_library <- function() {
  lib_path <- bootstrap_library()
  .libPaths(unique(c(lib_path, .libPaths())))
  invisible(lib_path)
}

clear_library_locks <- function(lib_path = bootstrap_library()) {
  if (!dir.exists(lib_path)) {
    return(invisible(lib_path))
  }

  lock_dirs <- list.files(
    lib_path,
    pattern = "^00LOCK",
    full.names = TRUE
  )

  if (length(lock_dirs) > 0) {
    invisible(unlink(lock_dirs, recursive = TRUE, force = TRUE))
  }

  invisible(lib_path)
}

install_packages_with_fallback <- function(packages) {
  set_bootstrap_library()
  clear_library_locks()

  tryCatch(
    {
      utils::install.packages(packages, repos = "https://cloud.r-project.org")
    },
    error = function(e) {
      message(
        "Default package install failed; retrying with a fallback mirror. Details: ",
        conditionMessage(e)
      )

      original_options <- options(download.file.method = "wininet")
      on.exit(options(original_options), add = TRUE)

      utils::install.packages(
        packages,
        repos = "https://cran.rstudio.com",
        type = "binary"
      )
    }
  )
}

install_if_missing <- function(package) {
  set_bootstrap_library()

  if (!requireNamespace(package, quietly = TRUE)) {
    install_packages_with_fallback(package)
  }

  invisible(package)
}

ensure_packages_installed <- function(packages) {
  set_bootstrap_library()
  missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing_packages) > 0) {
    install_packages_with_fallback(missing_packages)
  }

  invisible(packages)
}

locate_project_root <- function(start_dir = getwd()) {
  if (requireNamespace("here", quietly = TRUE)) {
    here_root <- tryCatch(
      normalizePath(here::here(), winslash = "/", mustWork = TRUE),
      error = function(e) ""
    )

    if (nzchar(here_root) &&
        file.exists(file.path(here_root, "soc_504_replication.Rproj")) &&
        dir.exists(file.path(here_root, "scripts")) &&
        dir.exists(file.path(here_root, "R"))) {
      return(here_root)
    }
  }

  search_dir <- normalizePath(start_dir, winslash = "/", mustWork = TRUE)

  repeat {
    has_rproj <- file.exists(file.path(search_dir, "soc_504_replication.Rproj"))
    has_scripts <- dir.exists(file.path(search_dir, "scripts"))
    has_r_dir <- dir.exists(file.path(search_dir, "R"))

    if (has_rproj && has_scripts && has_r_dir) {
      return(search_dir)
    }

    parent_dir <- dirname(search_dir)
    if (identical(parent_dir, search_dir)) {
      break
    }

    search_dir <- parent_dir
  }

  stop(
    "Could not locate the soc_504_replication project root from the current working directory.",
    call. = FALSE
  )
}

initialize_project_context <- function(project_root = locate_project_root()) {
  options(soc_504_replication_root = normalizePath(project_root, winslash = "/", mustWork = TRUE))
  invisible(getOption("soc_504_replication_root"))
}

project_root <- function() {
  option_root <- getOption("soc_504_replication_root")

  if (!is.null(option_root) && dir.exists(option_root)) {
    return(normalizePath(option_root, winslash = "/", mustWork = TRUE))
  }

  initialize_project_context()
}

build_paths <- function() {
  root <- project_root()

  list(
    project_root = root,
    scripts_dir = file.path(root, "scripts"),
    r_dir = file.path(root, "R"),
    docs_dir = file.path(root, "docs"),
    raw_dir = file.path(root, "data", "raw"),
    raw_slr_dir = file.path(root, "data", "raw", "slr"),
    raw_metadata_dir = file.path(root, "data", "raw", "metadata"),
    external_dir = file.path(root, "data", "external"),
    derived_dir = file.path(root, "data", "derived"),
    ingest_dir = file.path(root, "data", "derived", "ingest"),
    universe_dir = file.path(root, "data", "derived", "universe"),
    census_dir = file.path(root, "data", "derived", "census"),
    geography_dir = file.path(root, "data", "derived", "geography"),
    analysis_dir = file.path(root, "data", "derived", "analysis"),
    model_dir = file.path(root, "data", "derived", "models"),
    output_dir = file.path(root, "output"),
    figures_dir = file.path(root, "output", "figures"),
    tables_dir = file.path(root, "output", "tables"),
    logs_dir = file.path(root, "output", "logs")
  )
}

create_repo_dirs <- function(paths) {
  dir_list <- c(
    paths$raw_dir,
    paths$raw_slr_dir,
    paths$raw_metadata_dir,
    paths$external_dir,
    paths$derived_dir,
    paths$ingest_dir,
    paths$universe_dir,
    paths$census_dir,
    paths$geography_dir,
    paths$analysis_dir,
    paths$model_dir,
    paths$output_dir,
    paths$figures_dir,
    paths$tables_dir,
    paths$logs_dir
  )

  invisible(lapply(dir_list, dir.create, recursive = TRUE, showWarnings = FALSE))
}

check_required_files <- function(base_dir, required_files) {
  full_paths <- file.path(base_dir, required_files)
  missing_files <- required_files[!file.exists(full_paths)]

  if (length(missing_files) > 0) {
    stop(
      "Missing required files in: ", normalizePath(base_dir, winslash = "/", mustWork = FALSE), "\n",
      paste(missing_files, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(full_paths)
}

read_rds_required <- function(path) {
  if (!file.exists(path)) {
    stop("Expected file does not exist: ", path, call. = FALSE)
  }

  readRDS(path)
}

write_rds_output <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(object, path)
  invisible(path)
}

write_csv_output <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "")
  invisible(path)
}

run_with_retries <- function(operation, max_attempts = 5, sleep_seconds = 2, label = "operation") {
  attempt <- 1L

  repeat {
    result <- tryCatch(
      operation(),
      error = function(e) e
    )

    if (!inherits(result, "error")) {
      return(result)
    }

    if (attempt >= max_attempts) {
      stop(
        label, " failed after ", max_attempts, " attempts. Last error: ",
        conditionMessage(result),
        call. = FALSE
      )
    }

    message(
      label, " failed on attempt ", attempt, " of ", max_attempts,
      ". Retrying in ", sleep_seconds * attempt, " seconds..."
    )
    Sys.sleep(sleep_seconds * attempt)
    attempt <- attempt + 1L
  }
}
