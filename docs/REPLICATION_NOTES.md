# Replication Notes

## Portability audit

The working reconstruction repo was not portable on its own for several reasons:

| Dependency type | Where it occurred | Why it broke portability | Replacement in this repo |
|---|---|---|---|
| Absolute path fallbacks | `best_2023_from_scratch/R/utils_io.R` | Paths pointed to one user’s local folders | Replaced with repo-root discovery in `R/utils_io.R` |
| Runtime dependency on older repos | `best_2023_from_scratch/scripts/03_build_block_universe.R`, `07_construct_analysis_dataset.R` | Required `va_best_2023_replication` to be present | Copied only the needed county-universe seed into `data/raw/metadata/legacy_county_universe.csv` |
| Dependence on personal package library conventions | commands run with `r_local_lib` | Another user would not have that library path | Replaced with CRAN installs, repo-local bootstrap library, and `renv` support |
| Interactive path assumptions | earlier script-path logic and manual console use | Failed when lines were run interactively or from a different working directory | Each script now finds the repo root from `soc_504_replication.Rproj` |
| Hidden network brittleness | Census and TIGER pulls | Connection resets could break the run midstream | Added retry logic for `tidycensus` and `tigris` requests |
| Legacy runtime benchmarking | old reconstruction wrote benchmark tables against legacy data | Required external files that would not ship with the repo | Removed as runtime dependencies; legacy material is no longer required after construction |

## Files intentionally not carried over

- Exploratory legacy scripts
- Legacy benchmark tables
- Old repo-specific output folders
- Hard-coded path helpers
- Personal-library assumptions

## Block-universe statement

The standalone repo defines the block universe as:

> all 2020 Census blocks in the seeded analysis counties, with zero-population blocks retained.

That logic is implemented in `scripts/02_build_block_universe.R` and summarized in `data/derived/universe/block_universe_statement.csv`.

## Notes on `renv`

- `renv.lock` is populated.
- `renv` auto-activation is disabled on purpose so scripted runs remain stable.
- `scripts/01_setup.R` is the explicit restore/install entrypoint.

## Notes on runtime behavior

- The full pipeline was verified using `Rscript scripts/00_run_all.R`.
- The longest steps are the block-universe Census pull and the ACS/TIGER pull.
- Repeated runs are faster once packages and downloaded artifacts are already present locally.
