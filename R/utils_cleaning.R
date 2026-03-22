# Purpose: Shared data cleaning and variable construction helpers.
# Inputs: Raw without_zero files, legacy benchmark files, and Census pulls.
# Outputs: Standardized exposure tables and derived variables.
# Dependencies: dplyr, readr, stringr.

pad_geoid <- function(x, width) {
  stringr::str_pad(as.character(x), width = width, side = "left", pad = "0")
}

safe_divide <- function(numerator, denominator) {
  dplyr::if_else(
    is.na(denominator) | denominator == 0,
    NA_real_,
    numerator / denominator
  )
}

percent_or_na <- function(numerator, denominator) {
  100 * safe_divide(numerator, denominator)
}

clean_index_column <- function(data) {
  dplyr::select(data, -dplyr::any_of(c("", "...1", "X1")))
}

standardize_raw_geoids <- function(data) {
  output <- data

  if ("geoid" %in% names(output)) {
    output$geoid <- pad_geoid(output$geoid, 15)
  }
  if ("geoid_tract" %in% names(output)) {
    output$geoid_tract <- pad_geoid(output$geoid_tract, 11)
  }
  if ("geoid_county" %in% names(output)) {
    output$geoid_county <- pad_geoid(output$geoid_county, 5)
  }

  output
}

standardize_analysis_geoids <- function(data) {
  output <- data

  if ("block_geoid" %in% names(output)) {
    output$block_geoid <- pad_geoid(output$block_geoid, 15)
  }
  if ("tract_geoid" %in% names(output)) {
    output$tract_geoid <- pad_geoid(output$tract_geoid, 11)
  }
  if ("county_geoid" %in% names(output)) {
    output$county_geoid <- pad_geoid(output$county_geoid, 5)
  }

  output
}

read_without_zero_csv <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    clean_index_column() |>
    standardize_raw_geoids()
}

rename_exposure_columns <- function(data, exposure_type) {
  exposure_prefix <- switch(
    exposure_type,
    isolation = "isolated",
    inundation = "inundated",
    stop("Unsupported exposure type: ", exposure_type, call. = FALSE)
  )

  output <- data

  if ("rise" %in% names(output)) {
    output <- dplyr::rename(output, rise_ft = rise)
  }
  if ("geoid" %in% names(output)) {
    output <- dplyr::rename(output, block_geoid = geoid)
  }
  if ("geoid_tract" %in% names(output)) {
    output <- dplyr::rename(output, tract_geoid = geoid_tract)
  }
  if ("geoid_county" %in% names(output)) {
    output <- dplyr::rename(output, county_geoid = geoid_county)
  }

  names(output)[names(output) == "U7B001"] <- paste0(exposure_prefix, "_population")
  names(output)[names(output) == "U7C005"] <- paste0(exposure_prefix, "_white_non_hispanic_population")
  names(output)[names(output) == "U7B004"] <- paste0(exposure_prefix, "_black_population")
  names(output)[names(output) == "U7C002"] <- paste0(exposure_prefix, "_hispanic_population")

  if ("U7B001_total" %in% names(output)) {
    names(output)[names(output) == "U7B001_total"] <- "total_population_2020"
  }
  if ("U7B001_percentage" %in% names(output)) {
    names(output)[names(output) == "U7B001_percentage"] <- paste0(exposure_prefix, "_share_percent_source")
  }

  standardize_analysis_geoids(output)
}

add_exact_share_percent <- function(data, exposure_type) {
  exposure_prefix <- switch(
    exposure_type,
    isolation = "isolated",
    inundation = "inundated",
    stop("Unsupported exposure type: ", exposure_type, call. = FALSE)
  )

  population_col <- paste0(exposure_prefix, "_population")
  share_col <- paste0(exposure_prefix, "_share_percent")

  if (!all(c(population_col, "total_population_2020") %in% names(data))) {
    return(data)
  }

  output <- data
  output[[share_col]] <- percent_or_na(
    output[[population_col]],
    output[["total_population_2020"]]
  )

  output
}

prepare_acs_demographics <- function(data) {
  data |>
    dplyr::mutate(
      pct_white_non_hispanic = percent_or_na(
        white_non_hispanic_population,
        total_population
      ),
      pct_black = percent_or_na(
        black_population,
        total_population
      ),
      pct_hispanic = percent_or_na(
        hispanic_population,
        total_population
      ),
      pct_renter_households = percent_or_na(
        renter_occupied_housing_units,
        occupied_housing_units
      ),
      log_median_household_income = dplyr::if_else(
        !is.na(median_household_income) & median_household_income > 0,
        log(median_household_income),
        NA_real_
      )
    )
}

fill_missing_inundation_zero <- function(data) {
  inundation_columns <- c(
    "inundated_population",
    "inundated_white_non_hispanic_population",
    "inundated_black_population",
    "inundated_hispanic_population",
    "inundated_share_percent_source",
    "inundated_share_percent"
  )

  data |>
    dplyr::mutate(
      dplyr::across(
        dplyr::any_of(inundation_columns),
        ~ dplyr::coalesce(.x, 0)
      )
    )
}

fill_missing_isolation_zero <- function(data) {
  isolation_columns <- c(
    "isolated_population",
    "isolated_white_non_hispanic_population",
    "isolated_black_population",
    "isolated_hispanic_population",
    "isolated_share_percent_source",
    "isolated_share_percent"
  )

  data |>
    dplyr::mutate(
      dplyr::across(
        dplyr::any_of(isolation_columns),
        ~ dplyr::coalesce(.x, 0)
      )
    )
}

classify_disparity <- function(black_ratio, hispanic_ratio) {
  dplyr::case_when(
    !is.na(black_ratio) & black_ratio > 1 & !is.na(hispanic_ratio) & hispanic_ratio > 1 ~ "both",
    !is.na(black_ratio) & black_ratio > 1 ~ "black_only",
    !is.na(hispanic_ratio) & hispanic_ratio > 1 ~ "hispanic_only",
    TRUE ~ "neither"
  )
}

label_disparity_category <- function(category) {
  dplyr::recode(
    category,
    black_only = "Black only",
    hispanic_only = "Hispanic only",
    both = "Both",
    neither = "Neither",
    .default = category
  )
}
