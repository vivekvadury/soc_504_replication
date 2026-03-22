# Purpose: Fit the main tract-level models and create the coefficient plot.
# Inputs: data/derived/analysis/tract_model_dataset.rds.
# Outputs: Model objects, coefficient tables, fit statistics, and Figure 7.
# Dependencies: R/utils_io.R, R/utils_figures.R, R/utils_modeling.R, tidyverse, broom.

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
source(file.path(repo_root, "R", "utils_figures.R"))
source(file.path(repo_root, "R", "utils_modeling.R"))
initialize_project_context(repo_root)

ensure_packages_installed(c("tidyverse", "broom"))

suppressPackageStartupMessages(library(tidyverse))

paths <- build_paths()
tract_model_dataset <- read_rds_required(file.path(paths$analysis_dir, "tract_model_dataset.rds"))

model_data <- tract_model_dataset |>
  dplyr::filter(
    !is.na(median_age),
    !is.na(log_median_household_income),
    !is.na(pct_black),
    !is.na(pct_hispanic),
    !is.na(pct_renter_households)
  )

message("Fitting tract-level models...")

main_models <- fit_main_models(model_data)
model_coefficients <- tidy_main_models(main_models)
model_fit_statistics <- glance_main_models(main_models)

model_data_summary <- tibble::tibble(
  metric = c(
    "rows_used",
    "unique_tracts",
    "negative_missing_rows"
  ),
  value = c(
    nrow(model_data),
    dplyr::n_distinct(model_data$tract_geoid),
    sum(model_data$negative_missing_flag, na.rm = TRUE)
  )
)

term_order <- c(
  "SLR (ft)",
  "Median age",
  "ln(median household income)",
  "Percent Black",
  "Percent Hispanic",
  "Percent renter households"
)

figure_7_data <- model_coefficients |>
  dplyr::filter(term != "(Intercept)") |>
  dplyr::mutate(
    term_label = factor(
      vapply(term, label_model_term, character(1)),
      levels = rev(term_order)
    )
  )

figure_7_plot <- ggplot(
  figure_7_data,
  aes(x = estimate, y = term_label, color = outcome, xmin = conf.low, xmax = conf.high)
) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey60") +
  geom_pointrange(
    position = position_dodge(width = 0.6),
    linewidth = 0.5
  ) +
  scale_color_manual(
    values = outcome_palette,
    labels = c(
      isolation = "Isolation",
      inundation = "Inundation",
      missing = "Missing"
    )
  ) +
  labs(
    title = "Coefficient plot for tract-level isolation, inundation, and missing models",
    x = "Coefficient estimate",
    y = NULL,
    color = "Outcome"
  ) +
  theme_clean_replication()

save_plot(
  figure_7_plot,
  file.path(paths$figures_dir, "figure_7_model_coefficients.png"),
  width = 10,
  height = 6.5
)

write_rds_output(main_models, file.path(paths$model_dir, "main_models.rds"))
write_csv_output(model_coefficients, file.path(paths$tables_dir, "model_coefficients.csv"))
write_csv_output(model_fit_statistics, file.path(paths$tables_dir, "model_fit_statistics.csv"))
write_csv_output(model_data_summary, file.path(paths$tables_dir, "model_data_summary.csv"))
write_csv_output(figure_7_data, file.path(paths$tables_dir, "figure_7_model_coefficients_data.csv"))

message("Model run and coefficient figure complete.")
