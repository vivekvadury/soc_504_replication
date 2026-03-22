# Purpose: Shared plotting helpers, labels, and themes.
# Inputs: Data frames prepared by analysis scripts.
# Outputs: Consistent ggplot styling and figure saves.
# Dependencies: dplyr, ggplot2.

race_palette <- c(
  white_non_hispanic = "#4E79A7",
  black = "#E15759",
  hispanic = "#59A14F"
)

disparity_palette <- c(
  black_only = "#D55E00",
  hispanic_only = "#0072B2",
  both = "#009E73",
  neither = "#7F7F7F"
)

outcome_palette <- c(
  isolation = "#C44E52",
  inundation = "#4C72B0",
  missing = "#55A868"
)

theme_clean_replication <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      legend.title = ggplot2::element_blank(),
      axis.title = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

save_plot <- function(plot_object, path, width = 10, height = 6, dpi = 320) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  ggplot2::ggsave(
    filename = path,
    plot = plot_object,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"
  )

  invisible(path)
}

label_model_term <- function(term) {
  dplyr::recode(
    term,
    rise_ft = "SLR (ft)",
    median_age = "Median age",
    log_median_household_income = "ln(median household income)",
    pct_black = "Percent Black",
    pct_hispanic = "Percent Hispanic",
    pct_renter_households = "Percent renter households",
    `(Intercept)` = "Intercept",
    .default = term
  )
}

label_race_group <- function(race_group) {
  dplyr::recode(
    race_group,
    white_non_hispanic = "White",
    black = "Black",
    hispanic = "Hispanic",
    .default = race_group
  )
}
