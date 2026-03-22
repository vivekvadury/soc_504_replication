# Replication Project for SOC 504 (Spring 2026)

Standalone R replication repository for the main analysis in [Best et al. (2023)](https://www.nature.com/articles/s41467-023-43835-6). 

## What this repo does

This repository reproduces the main replicable analysis workflow for:

- the block-universe construction used for the coastal analysis counties
- ACS and TIGER data pulls
- national racial disparity summaries across SLR scenarios
- county-level disproportionate-risk summaries and a county map
- tract-level disparity distributions
- tract characteristics by disparity category
- tract-level regression models and a coefficient plot

## What this repo does not do

- It does not recompute isolation from road networks, schools, fire stations, or service routing.
- It does not replicate the timing / tide-gauge projection analysis analogous to paper Figure 2.

## System requirements

- R 4.5 or later
- Internet access for:
  - CRAN package downloads
  - Census API requests
  - TIGER geometry downloads
- Enough disk space for downloaded packages, derived data, and figures

## Project structure

- `data/raw/slr/`: included block-level SLR exposure inputs
- `data/raw/metadata/`: included metadata and county-universe seed
- `data/derived/`: derived analysis inputs created by the scripts
- `output/figures/`: figure outputs
- `output/tables/`: table outputs and figure data
- `R/`: internal helper functions
- `scripts/`: runnable pipeline scripts
- `docs/`: provenance, assumptions, and replication notes

## Package management

Recommended options:

1. Easiest: run `scripts/00_run_all.R`. It calls `scripts/01_setup.R` first.
2. If you want to restore packages explicitly before running the pipeline, run `scripts/01_setup.R`.

`01_setup.R` uses this order:

1. try `renv::restore()` if the lockfile is present and required packages are missing
2. if `renv` restore fails, fall back to direct CRAN installation of the required packages

## How to run

From the repository root, either:

```r
source("scripts/00_run_all.R", chdir = TRUE)
```

or from a terminal:

```powershell
Rscript scripts/00_run_all.R
```

If you are using RStudio, run the whole file with `Source`. Do not run individual bootstrap lines manually in the Console.

## Main scripts

- `scripts/00_run_all.R`: full pipeline entrypoint
- `scripts/01_setup.R`: directories, packages, Census API key, input checks
- `scripts/02_build_block_universe.R`: 2020 Census block universe
- `scripts/03_pull_census_and_geography.R`: ACS covariates and TIGER geometries
- `scripts/04_load_slr_exposure_data.R`: SLR block exposure ingest
- `scripts/05_construct_analysis_data.R`: national, county, tract, and model datasets
- `scripts/06_make_figures.R`: descriptive figures
- `scripts/07_run_models.R`: tract models and coefficient plot
- `scripts/08_make_tables.R`: table-ready CSV outputs

## Expected outputs

Figures:

- `output/figures/figure_1_national_race_summary.png`
- `output/figures/figure_3_county_disparity_counts.png`
- `output/figures/figure_4_county_map_3ft.png`
- `output/figures/figure_5_tract_disparity_distribution.png`
- `output/figures/figure_6_tract_characteristics_by_disparity.png`
- `output/figures/figure_7_model_coefficients.png`

Tables and supporting data:

- `output/tables/table_national_race_summary.csv`
- `output/tables/table_county_disparity_counts.csv`
- `output/tables/table_tract_characteristics_by_disparity.csv`
- `output/tables/table_1_model_coefficients.csv`
- `output/tables/table_1_model_fit_statistics.csv`

## Manual data requirements

None for the current standalone workflow. All required runtime inputs are either included in the repo or downloaded programmatically.

## Documentation

- `docs/ASSUMPTIONS_AND_LIMITATIONS.md`
- - `docs/Best et al. (2023).pdf`
