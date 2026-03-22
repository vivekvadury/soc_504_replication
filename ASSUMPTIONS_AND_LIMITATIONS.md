# Assumptions and Limitations

## Main Decisions

1. The clean rebuild uses the preferred replacement block exposure files as the primary exposure source.
2. The block universe is reconstructed from fresh 2020 Census block pulls, keyed to the legacy county universe, rather than copied from the legacy block xlsx files.
3. Missing block / tract / county rows in the preferred `without_zero` exposure inputs are interpreted as zero affected population after universe expansion.

## Why The Legacy Block Files Were Not Used Directly

- `data/kelsea/isolation/blocks2020.xlsx` is truncated at the Excel row limit.
- `data/kelsea/isolation/isolation_block_w_zero.xlsx` is also truncated at the Excel row limit.
- Those files are therefore useful as clues about legacy logic, but not safe as authoritative replication inputs.

## Universe Mismatches That Matter

### Legacy county universe vs preferred replacement county universe

- The legacy county panel contains 329 counties.
- The preferred replacement county file contains 328 counties.
- The legacy-only county is `12117` (Seminole County, Florida).
- In the clean rebuild, the county stays in the universe because the legacy repo is the operational source of truth for the county list; the preferred exposure files simply contribute zero rows for it.

### Block-defined tract universe vs legacy tract files

- The fresh block-defined universe produces 28,716 tracts in the legacy coastal-county universe.
- The legacy `tract_acs_w_zero.csv` contains only 7,732 unique tracts and is not a complete tract-by-scenario panel.
- Because of that, the legacy tract "with zero" files are treated as incomplete benchmarks rather than the target universe.

## Benchmark Results Observed In This Run

- The clean tract reconstruction matches the preferred replacement tract exposure counts exactly after zero fill.
- The clean national race summary matches the preferred replacement national race shares exactly.
- The clean county reconstruction differs from the preferred replacement county file in 10 county-scenario rows:
  - Georgetown County, South Carolina
  - Horry County, South Carolina
  - the difference is a 26-person swap at rises 6 to 10
- The clean county reconstruction differs substantially from the legacy county file, so the legacy county panel is used only as a benchmark and logic clue, not as a dependency.

## Modeling Limitation

- There are 391 tract-scenario rows where `isolated_population - inundated_population` is negative.
- The clean workflow records that flag and sets `missing_population = pmax(isolated - inundated, 0)` for the modeling outcome.
- This keeps the "missing" outcome aligned with the paper’s isolation-minus-inundation framing while remaining transparent about internal inconsistencies in the source inputs.

## Skipped Component

Figure 2 timing-by-year analysis is not part of the clean main pipeline.

It would require validated use of:

- `data/blocks_gauges.csv`
- `data/SLR_US_Projections.csv`
- the legacy block-gauge matching logic from `projection_scenarios.R`

Those inputs exist in the legacy repo, but I did not treat them as reproducible enough to fold into the clean main workflow without a separate validation pass.
