# Purpose: Shared helpers for crosswalks and geographic downloads.
# Inputs: Tract GEOIDs, county GEOIDs, and state abbreviations from analysis data.
# Outputs: Tract-county crosswalks and sf objects for county/state plotting.
# Dependencies: dplyr, sf, stringr, tigris, purrr.

build_tract_county_crosswalk <- function(tract_geoids) {
  tibble::tibble(
    tract_geoid = unique(as.character(tract_geoids))
  ) |>
    dplyr::mutate(
      county_geoid = stringr::str_sub(tract_geoid, 1, 5),
      state_fips = stringr::str_sub(tract_geoid, 1, 2)
    )
}

download_analysis_geographies <- function(state_codes, county_geoids) {
  message("Downloading county geometries for mapped outputs...")

  county_sf <- purrr::map(
    unique(state_codes),
    ~ run_with_retries(
      function() {
        tigris::counties(
          state = .x,
          cb = TRUE,
          year = 2021,
          class = "sf",
          progress_bar = FALSE
        )
      },
      label = paste("County geometry pull for state", .x)
    )
  ) |>
    dplyr::bind_rows() |>
    dplyr::filter(GEOID %in% county_geoids) |>
    dplyr::rename(
      county_geoid = GEOID,
      county_name = NAME
    )

  state_sf <- run_with_retries(
    function() {
      tigris::states(
        cb = TRUE,
        year = 2021,
        class = "sf",
        progress_bar = FALSE
      )
    },
    label = "State geometry pull"
  ) |>
    dplyr::filter(STUSPS %in% unique(state_codes)) |>
    dplyr::rename(
      state_code = STUSPS,
      state_name_plot = NAME
    )

  list(
    counties = county_sf,
    states = state_sf
  )
}
