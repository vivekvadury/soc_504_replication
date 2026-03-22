# Data Provenance

This file documents every dataset used by the standalone workflow and how it enters the pipeline.

## Included directly in the repo

| File | Location | Purpose | Status | Used by |
|---|---|---|---|---|
| `isolation_block.csv` | `data/raw/slr/isolation_block.csv` | Block-level isolation exposure input across SLR scenarios | Included | `04_load_slr_exposure_data.R`, `05_construct_analysis_data.R` |
| `inundation_block.csv` | `data/raw/slr/inundation_block.csv` | Block-level inundation exposure input across SLR scenarios | Included | `04_load_slr_exposure_data.R`, `05_construct_analysis_data.R` |
| `legacy_county_universe.csv` | `data/raw/metadata/legacy_county_universe.csv` | Seed for the identified county analysis universe | Included | `02_build_block_universe.R` |
| `nhgis_block_codebook.txt` | `data/raw/metadata/nhgis_block_codebook.txt` | Metadata reference for the block exposure files | Included | input validation in `01_setup.R` |

## Downloaded programmatically

| Dataset | Created by | Source | Purpose |
|---|---|---|---|
| `block_universe.rds` | `02_build_block_universe.R` | 2020 decennial Census via `tidycensus` | Full block universe with zero-population blocks retained |
| `acs_tract_2019.rds` | `03_pull_census_and_geography.R` | 2019 ACS 5-year via `tidycensus` | Tract covariates for descriptive analysis and models |
| `acs_county_2019.rds` | `03_pull_census_and_geography.R` | 2019 ACS 5-year via `tidycensus` | County baselines for disparity comparisons |
| `national_race_baseline_2020.rds` | `03_pull_census_and_geography.R` | 2020 decennial Census via `tidycensus` | National race-share baseline for Figure 1 analog |
| `analysis_counties.rds` | `03_pull_census_and_geography.R` | TIGER via `tigris` | County geometry for mapped outputs |
| `analysis_states.rds` | `03_pull_census_and_geography.R` | TIGER via `tigris` | State outlines for mapped outputs |

## Derived inside the repo

| Dataset | Created by | Purpose |
|---|---|---|
| `national_race_summary.rds` | `05_construct_analysis_data.R` | National race summary across SLR scenarios |
| `county_analysis.rds` | `05_construct_analysis_data.R` | County disproportionate-risk analysis dataset |
| `tract_disparity_analysis.rds` | `05_construct_analysis_data.R` | Tract disparity analysis dataset |
| `tract_model_dataset.rds` | `05_construct_analysis_data.R` | Tract model dataset |
| `main_models.rds` | `07_run_models.R` | Fitted regression objects |

## Manual or restricted inputs

None for the current standalone workflow.

## Provenance notes

- The two block-level exposure files were copied from the working reconstruction repo because they are the preferred SLR exposure source.
- The county-universe seed was copied into this repo so the runtime workflow no longer needs the legacy repository.
- Legacy precomputed demographic and geography files are not used at runtime.
