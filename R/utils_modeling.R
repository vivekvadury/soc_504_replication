# Purpose: Shared model fitting and output helpers.
# Inputs: Tract-level modeling dataset.
# Outputs: Named model lists, tidy coefficient tables, and wide summary tables.
# Dependencies: broom, dplyr, purrr, stats, tidyr.

fit_main_models <- function(model_data) {
  list(
    isolation = stats::lm(
      isolated_share_percent ~ rise_ft + median_age + log_median_household_income +
        pct_black + pct_hispanic + pct_renter_households,
      data = model_data
    ),
    inundation = stats::lm(
      inundated_share_percent ~ rise_ft + median_age + log_median_household_income +
        pct_black + pct_hispanic + pct_renter_households,
      data = model_data
    ),
    missing = stats::lm(
      missing_share_percent ~ rise_ft + median_age + log_median_household_income +
        pct_black + pct_hispanic + pct_renter_households,
      data = model_data
    )
  )
}

tidy_main_models <- function(models) {
  purrr::imap_dfr(
    models,
    ~ broom::tidy(.x, conf.int = TRUE) |>
      dplyr::mutate(outcome = .y)
  )
}

glance_main_models <- function(models) {
  purrr::imap_dfr(
    models,
    ~ broom::glance(.x) |>
      dplyr::mutate(outcome = .y)
  )
}

build_model_table <- function(tidy_results) {
  tidy_results |>
    dplyr::mutate(
      term = vapply(term, label_model_term, character(1)),
      estimate_se = sprintf("%.3f (%.3f)", estimate, std.error)
    ) |>
    dplyr::select(outcome, term, estimate_se) |>
    tidyr::pivot_wider(
      names_from = outcome,
      values_from = estimate_se
    )
}

build_model_fit_table <- function(glance_results) {
  glance_results |>
    dplyr::transmute(
      outcome,
      n_obs = nobs,
      r_squared = r.squared,
      adjusted_r_squared = adj.r.squared,
      sigma = sigma,
      statistic,
      p_value = p.value,
      aic = AIC,
      bic = BIC
    )
}
