# Purpose: Create the main descriptive figures for the standalone replication workflow.
# Inputs: Analysis datasets and mapping geometries produced by prior scripts.
# Outputs: Figure PNG files and figure-data CSV files in output/.
# Dependencies: R/utils_io.R, R/utils_cleaning.R, R/utils_figures.R, tidyverse, sf.

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
initialize_project_context(repo_root)

ensure_packages_installed(c("tidyverse", "sf"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
})

paths <- build_paths()

national_race_summary <- read_rds_required(file.path(paths$analysis_dir, "national_race_summary.rds"))
county_analysis <- read_rds_required(file.path(paths$analysis_dir, "county_analysis.rds"))
tract_disparity_analysis <- read_rds_required(file.path(paths$analysis_dir, "tract_disparity_analysis.rds"))
analysis_counties <- read_rds_required(file.path(paths$geography_dir, "analysis_counties.rds"))
analysis_states <- read_rds_required(file.path(paths$geography_dir, "analysis_states.rds"))

figure_1_data <- national_race_summary |>
  dplyr::mutate(
    race_group = factor(
      race_group,
      levels = c("white_non_hispanic", "black", "hispanic")
    )
  )

figure_1_baseline <- figure_1_data |>
  dplyr::distinct(race_group, national_share_percent)

figure_1_plot <- ggplot(
  figure_1_data,
  aes(x = rise_ft, y = isolated_share_percent, color = race_group)
) +
  geom_hline(
    data = figure_1_baseline,
    aes(yintercept = national_share_percent, color = race_group),
    linetype = "dashed",
    linewidth = 0.8
  ) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.8) +
  scale_color_manual(
    values = race_palette,
    labels = label_race_group
  ) +
  scale_x_continuous(breaks = 1:10) +
  labs(
    title = "National isolated population by race across SLR scenarios",
    x = "SLR (ft)",
    y = "Share of isolated population (%)"
  ) +
  theme_clean_replication()

save_plot(
  figure_1_plot,
  file.path(paths$figures_dir, "figure_1_national_race_summary.png"),
  width = 10,
  height = 6
)

figure_3_data <- county_analysis |>
  dplyr::filter(county_disparity_category != "neither") |>
  dplyr::count(rise_ft, county_disparity_category, name = "county_count") |>
  tidyr::complete(
    rise_ft = 1:10,
    county_disparity_category = c("black_only", "hispanic_only", "both"),
    fill = list(county_count = 0)
  ) |>
  dplyr::mutate(
    county_disparity_category = factor(
      county_disparity_category,
      levels = c("black_only", "hispanic_only", "both"),
      labels = c("Black only", "Hispanic only", "Both")
    )
  )

figure_3_plot <- ggplot(
  figure_3_data,
  aes(x = rise_ft, y = county_count, fill = county_disparity_category)
) +
  geom_col(color = "white", linewidth = 0.1) +
  scale_fill_manual(
    values = c(
      "Black only" = disparity_palette[["black_only"]],
      "Hispanic only" = disparity_palette[["hispanic_only"]],
      "Both" = disparity_palette[["both"]]
    )
  ) +
  scale_x_continuous(breaks = 1:10) +
  labs(
    title = "Counties with disproportionate racial isolation risk",
    x = "SLR (ft)",
    y = "County count",
    fill = "County category"
  ) +
  theme_clean_replication()

save_plot(
  figure_3_plot,
  file.path(paths$figures_dir, "figure_3_county_disparity_counts.png"),
  width = 10,
  height = 6
)

figure_4_data <- county_analysis |>
  dplyr::filter(rise_ft == 3) |>
  dplyr::select(
    county_geoid,
    county_name,
    state_code,
    county_disparity_category,
    black_disparity_ratio,
    hispanic_disparity_ratio
  )

figure_4_sf <- analysis_counties |>
  dplyr::left_join(figure_4_data, by = "county_geoid")

figure_4_plot <- ggplot() +
  geom_sf(data = analysis_states, fill = NA, color = "grey60", linewidth = 0.3) +
  geom_sf(data = figure_4_sf, fill = "grey92", color = "white", linewidth = 0.05) +
  geom_sf(
    data = dplyr::filter(figure_4_sf, county_disparity_category != "neither"),
    aes(fill = county_disparity_category),
    color = NA
  ) +
  scale_fill_manual(
    values = disparity_palette[c("black_only", "hispanic_only", "both")],
    labels = c(
      black_only = "Black only",
      hispanic_only = "Hispanic only",
      both = "Both"
    )
  ) +
  labs(
    title = "Counties with disproportionate racial isolation risk at 3 ft SLR",
    fill = "County category"
  ) +
  theme_void() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

save_plot(
  figure_4_plot,
  file.path(paths$figures_dir, "figure_4_county_map_3ft.png"),
  width = 11,
  height = 7
)

selected_rises <- c(1, 5, 10)

figure_5_data <- tract_disparity_analysis |>
  dplyr::filter(rise_ft %in% selected_rises) |>
  dplyr::transmute(
    rise_ft,
    black = black_disparity_ratio,
    hispanic = hispanic_disparity_ratio
  ) |>
  tidyr::pivot_longer(
    cols = c(black, hispanic),
    names_to = "race_group",
    values_to = "disparity_ratio"
  ) |>
  dplyr::filter(is.finite(disparity_ratio)) |>
  dplyr::mutate(race_group = factor(race_group, levels = c("black", "hispanic")))

figure_5_plot <- ggplot(figure_5_data, aes(x = disparity_ratio)) +
  geom_density(fill = "#4E79A7", alpha = 0.35, color = "#1F3552") +
  geom_vline(xintercept = 1, linetype = "dashed", color = "#C44E52") +
  facet_grid(
    rows = vars(race_group),
    cols = vars(rise_ft),
    labeller = labeller(race_group = label_race_group)
  ) +
  coord_cartesian(xlim = c(0, 12)) +
  labs(
    title = "Tract-level disparity ratios relative to county baseline shares",
    x = "Disparity ratio",
    y = "Density"
  ) +
  theme_clean_replication()

save_plot(
  figure_5_plot,
  file.path(paths$figures_dir, "figure_5_tract_disparity_distribution.png"),
  width = 11,
  height = 6.5
)

figure_6_data <- tract_disparity_analysis |>
  dplyr::group_by(rise_ft, disparity_category) |>
  dplyr::summarise(
    mean_income = mean(median_household_income, na.rm = TRUE),
    mean_pct_white = mean(pct_white_non_hispanic, na.rm = TRUE),
    mean_age = mean(median_age, na.rm = TRUE),
    n_tracts = dplyr::n(),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    disparity_category_label = label_disparity_category(disparity_category)
  ) |>
  tidyr::pivot_longer(
    cols = c(mean_income, mean_pct_white, mean_age),
    names_to = "metric",
    values_to = "value"
  ) |>
  dplyr::mutate(
    metric = dplyr::recode(
      metric,
      mean_income = "Mean median household income",
      mean_pct_white = "Mean percent White",
      mean_age = "Mean median age"
    )
  )

figure_6_plot <- ggplot(
  figure_6_data,
  aes(x = rise_ft, y = value, color = disparity_category, group = disparity_category)
) +
  geom_line(linewidth = 1) +
  facet_wrap(~ metric, scales = "free_y", ncol = 1) +
  scale_color_manual(
    values = disparity_palette,
    labels = c(
      black_only = "Black only",
      hispanic_only = "Hispanic only",
      both = "Both",
      neither = "Neither"
    )
  ) +
  scale_x_continuous(breaks = 1:10) +
  labs(
    title = "Tract characteristics by disparity category across SLR scenarios",
    x = "SLR (ft)",
    y = NULL,
    color = "Disparity category"
  ) +
  theme_clean_replication()

save_plot(
  figure_6_plot,
  file.path(paths$figures_dir, "figure_6_tract_characteristics_by_disparity.png"),
  width = 10,
  height = 9
)

write_csv_output(figure_1_data, file.path(paths$tables_dir, "figure_1_national_race_summary_data.csv"))
write_csv_output(figure_3_data, file.path(paths$tables_dir, "figure_3_county_disparity_counts_data.csv"))
write_csv_output(figure_4_data, file.path(paths$tables_dir, "figure_4_county_map_3ft_data.csv"))
write_csv_output(figure_5_data, file.path(paths$tables_dir, "figure_5_tract_disparity_distribution_data.csv"))
write_csv_output(figure_6_data, file.path(paths$tables_dir, "figure_6_tract_characteristics_by_disparity_data.csv"))

message("Descriptive figures complete.")
