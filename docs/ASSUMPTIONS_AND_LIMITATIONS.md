# Assumptions and Limitations

## Core assumptions

- The analysis county universe is defined by the counties identified during reverse engineering and stored in `data/raw/metadata/legacy_county_universe.csv`.
- The block universe is reconstructed as all 2020 Census blocks in those counties.
- Zero-population blocks are retained in the block universe.
- The included SLR files are treated as exposure inputs only; they do not define the analysis universe.

## What is replicated

- National by-race isolation summaries across SLR scenarios
- County disproportionate-risk counts and county map outputs
- Tract disparity distributions
- Tract characteristics by disparity group
- Tract-level models for isolation, inundation, and missing outcomes

## What is not recomputed here

- Service-location routing logic
- Nearest-facility calculations
- Road-network accessibility calculations
- Tide-gauge or time-to-year projection analysis analogous to paper Figure 2

Those components would require additional source data and preprocessing that are not part of the portable replication repo.

## Modeling note on the missing outcome

- `missing_population` is defined as `pmax(isolated_population - inundated_population, 0)`.
- `missing_share_percent` is defined as `missing_population / isolated_population * 100`.
- The tract dataset also keeps `negative_missing_flag` so rows where raw inundation exceeds raw isolation are still visible in diagnostics.

## Package-management note

- `renv` is included and `renv.lock` is populated.
- Automatic `renv` activation is intentionally disabled in `.Rprofile`.
- `scripts/01_setup.R` handles restore explicitly and falls back to direct CRAN installs if `renv` restore fails.

## Census API key behavior

- `scripts/01_setup.R` sets the Census API key for the current session.
- It also attempts to write the key to the user profile using `census_api_key(..., install = TRUE, overwrite = TRUE)`.
- If that profile write fails, the script falls back to session-only use.
