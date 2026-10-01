# hicp-gap: Western Balkan peers verification report

**Status: verification only.** This report records coverage, weights, consistency checks
and published values for a possible peer extension (XK, ME, RS, AL, MK, plus EA, and BiH
via national CPI). It contains no decomposition, no figure, no finding and no
interpretation. Where a choice arose, it is listed under "Open decisions for Plator" at
the end and was not made.

- Script: `verify/02_peers.R` (run from the piece root: `Rscript verify/02_peers.R`).
- Date of this session: 2026-09-29.
- Every number in sections 1–6 is copied verbatim from
  `verify/peers_tables_generated.md`, which the script writes. Sections 7–8
  (BiH source, metadata) were read by hand from the saved pages listed there.

## Data vintage

- **HICP data:** Eurostat `LAST UPDATE` **17/09/26 11:00:00** for `prc_hicp_minr` and
  `prc_hicp_iw`. These are the bulk files already on disk from `verify/01_coverage.R`
  (`data/raw/2026-09-23/`). They were **not re-downloaded**. The script fetched Eurostat's
  catalogue on 2026-09-29, and its "last update of data" for both tables is 17.09.2026,
  equal to the bulk stamp. The script asserts this equality and stops if it breaks.
- **New raw files, `data/raw/2026-09-29/`** (all saved as downloaded):
  - `eurostat_catalogue_toc_en.txt`: the catalogue, used for the vintage guard and the
    table list.
  - `contentconstraint/*.xml`: the geo codes carried by 48 HICP tables.
  - `eurostat_ei_cphi_m_BA.csv` and `eurostat_ei_cphi_m_bulk.csv.gz`: the BA check. The
    bulk file is gitignored under the existing `hicp-gap/.gitignore` pattern.
  - The ESMS metadata pages, the Eurostat HICP 2026 Q&A PDF, and the BHAS CPI ESMS page.
- **Filtered record of this vintage, `data/raw/2026-09-23/`:**
  `eurostat_prc_hicp_minr_WB_EA.rds` (7.4 MB) and `eurostat_prc_hicp_iw_WB_EA.rds`
  (0.2 MB). These are the bulk files filtered to geo XK, ME, RS, AL, MK and EA. The filter
  also looked for BA, and no BA rows exist.
- **Euro-area code:** `EA`, the same code hicp-gap uses: Eurostat's changing-composition
  aggregate.

## Where each task is answered

| task | section |
|---|---|
| 1 Coverage (codes listed first, then the matrix) | 1a–1e, CSVs `peers_coicop_codes.csv`, `peers_coverage.csv` |
| 2 Weights | 2, CSV `peers_weights.csv` |
| 3 Headline consistency | 3, CSV `peers_headline_check.csv` |
| 4 Aggregation residual | 4, CSV `peers_aggregation_residuals.csv` |
| 5 BiH | 6 (Eurostat scan) and 7 (BHAS source) |
| 6 External claims | 5 |
| 7 Metadata | 8 |

Scope notes, stated rather than chosen:

- "Special aggregate" means any `coicop18` code that is neither `TOTAL` nor `CP*`. All 48
  of them are in the coverage CSV. The printed tables show the four main aggregates plus
  `TOT_X_NRG_FOOD`: `FOOD` (food including alcohol and tobacco), `NRG`, `IGD_NNRG`, `SERV`.
- Units covered: `I15`, `I25` (index) and `RCH_A` (annual rate). `prc_hicp_minr` also
  carries `RCH_M` and `RCH_MV12MAVR`. They were not checked.
- Task 4 is reported under three variants side by side, because the task left two inputs
  open: the source of the division YoY (published vs derived) and the weight year (t vs
  t−1). No variant is preferred.

## Computed tables (verbatim from `peers_tables_generated.md`, written by `verify/02_peers.R`)

Eurostat vintage: LAST UPDATE 17/09/26 11:00:00 (bulk, `2026-09-23`); catalogue last update 17.09.2026 for both tables.

### 1a. coicop18 codes returned by prc_hicp_minr (units I15/I25/RCH_A)

Distinct codes with at least one non-empty value, by class and geo:

| class | XK | ME | RS | AL | MK | EA |
|---|---|---|---|---|---|---|
| division | 13 | 13 | 13 | 13 | 13 | 13 |
| special aggregate | 46 | 46 | 46 | 46 | 46 | 48 |
| sub-division | 337 | 369 | 364 | 361 | 381 | 478 |
| total | 1 | 1 | 1 | 1 | 1 | 1 |

Special aggregates (label from the COICOP18 codelist) and the units each geo carries:

| coicop18 | label | XK | ME | RS | AL | MK | EA |
|---|---|---|---|---|---|---|---|
| AP | Administered prices | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| APF | Fully administered prices | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| APM | Mainly administered prices | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| AP_NRG | Administered prices - energy | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| AP_NRG_FOOD | Administered prices - energy and food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| AP_X_NRG | Administered prices excluding energy | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| AP_X_NRG_FOOD | Administered prices excluding energy and food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| EDUC_HLTH_SPR | Education, health and social protection | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| ELC_GAS | Electricity, gas, solid fuels and heat energy | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| FOOD | Food including alcohol and tobacco | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| FOOD_NP | Unprocessed food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| FOOD_P | Processed food including alcohol and tobacco | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| FOOD_P_X_ALC_TBC | Processed food excluding alcohol and tobacco | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| FOOD_P_X_TBC | Processed food excluding tobacco | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| FOOD_S | Seasonal food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| FROOPP | Frequent out-of-pocket purchases |  |  |  |  |  | I15,I25,RCH_A |
| FUEL | Liquid fuels and fuels for personal transport equipment | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| GD | Goods (overall index excluding services) | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| IGD | Industrial goods | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| IGD_NNRG | Non-energy industrial goods | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| IGD_NNRG_D | Non-energy industrial goods, durables only | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| IGD_NNRG_ND | Non-energy industrial goods, non-durables only | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| IGD_NNRG_SD | Non-energy industrial goods, semi-durables only | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| NRG | Energy | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| NRG_FOOD_NP | Energy and unprocessed food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| NRG_FOOD_S | Energy and seasonal food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV | Services (overall index excluding goods) | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV_COM | Services related to communication | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV_HOUS | Services related to housing | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV_MSC | Services - miscellaneous | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV_REC | Services related to recreation, including repairs and personal care | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV_REC_HOA | Services related to package holidays and accommodation | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV_REC_X_HOA | Services related to recreation and personal care, excluding package holidays and accommodation | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| SERV_TRA | Services related to transport | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_ALC_TBC | Overall index excluding alcohol and tobacco | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_AP | Overall index excluding administered prices | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_APF | Overall index excluding fully administered prices | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_APM | Overall index excluding mainly administered prices | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_EDUC_HLTH_SPR | Overall index excluding education, health and social protection | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_FOOD_S | Overall index excluding seasonal food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_FROOPP | Overall index excluding frequent out-of-pocket purchases |  |  |  |  |  | I15,I25,RCH_A |
| TOT_X_FUEL | Overall index excluding liquid fuels and fuels for personal transport equipment | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_HOUS | Overall index excluding housing, water, electricity, gas and other fuels | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_NRG | Overall index excluding energy | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_NRG_FOOD | Overall index excluding energy, food, alcohol and tobacco | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_NRG_FOOD_NP | Overall index excluding energy and unprocessed food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_NRG_FOOD_S | Overall index excluding energy and seasonal food | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |
| TOT_X_TBC | Overall index excluding tobacco | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A | I15,I25,RCH_A |

### 1b. Coverage, unit I15: TOTAL, divisions, main special aggregates

Cell = first..last month with a value; "(gaps n)" = months missing inside that span.

| coicop18 | XK | ME | RS | AL | MK | EA |
|---|---|---|---|---|---|---|
| TOTAL | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP01 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP02 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP03 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP04 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP05 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP06 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP07 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP08 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP09 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP10 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP11 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP12 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP13 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| FOOD | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| NRG | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| IGD_NNRG | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1999-12..2026-08 |
| SERV | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1999-12..2026-08 |
| TOT_X_NRG_FOOD | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1999-12..2026-08 |

### 1b. Coverage, unit I25: TOTAL, divisions, main special aggregates

Cell = first..last month with a value; "(gaps n)" = months missing inside that span.

| coicop18 | XK | ME | RS | AL | MK | EA |
|---|---|---|---|---|---|---|
| TOTAL | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP01 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP02 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP03 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP04 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP05 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP06 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP07 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP08 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP09 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP10 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP11 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP12 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| CP13 | 2015-01..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| FOOD | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| NRG | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1996-01..2026-08 |
| IGD_NNRG | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1999-12..2026-08 |
| SERV | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1999-12..2026-08 |
| TOT_X_NRG_FOOD | 2015-12..2026-08 | 2014-12..2026-08 | 2005-12..2026-08 | 2015-12..2026-08 | 2004-12..2026-08 | 1999-12..2026-08 |

### 1b. Coverage, unit RCH_A: TOTAL, divisions, main special aggregates

Cell = first..last month with a value; "(gaps n)" = months missing inside that span.

| coicop18 | XK | ME | RS | AL | MK | EA |
|---|---|---|---|---|---|---|
| TOTAL | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP01 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP02 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP03 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP04 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP05 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP06 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP07 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP08 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP09 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP10 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP11 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP12 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| CP13 | 2016-01..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| FOOD | 2016-12..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| NRG | 2016-12..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 1997-01..2026-08 |
| IGD_NNRG | 2016-12..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 2000-12..2026-08 |
| SERV | 2016-12..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 2000-12..2026-08 |
| TOT_X_NRG_FOOD | 2016-12..2026-08 | 2015-12..2026-08 | 2006-12..2026-08 | 2016-12..2026-08 | 2005-12..2026-08 | 2000-12..2026-08 |

### 1c. Flags on TOTAL, divisions and main special aggregates

Format `flag:count (first..last flagged month)`. Eurostat flags: b = break in time series, 
d = definition differs (see metadata), u = low reliability, e = estimated, p = provisional.

| geo | unit | coicop18 | flags |
|---|---|---|---|
| XK | I15 | FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I15 | IGD_NNRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I15 | NRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I15 | SERV | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I15 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I25 | FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I25 | IGD_NNRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I25 | NRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I25 | SERV | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | I25 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| XK | RCH_A | FOOD | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| XK | RCH_A | IGD_NNRG | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| XK | RCH_A | NRG | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| XK | RCH_A | SERV | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| XK | RCH_A | TOT_X_NRG_FOOD | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| ME | I15 | FOOD | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I15 | IGD_NNRG | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I15 | NRG | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I15 | SERV | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I15 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I25 | FOOD | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I25 | IGD_NNRG | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I25 | NRG | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I25 | SERV | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | I25 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:25 (2014-12..2016-12) |
| ME | RCH_A | FOOD | b:2 (2017-01..2018-01); d:24 (2015-12..2017-12) |
| ME | RCH_A | IGD_NNRG | b:2 (2017-01..2018-01); d:24 (2015-12..2017-12) |
| ME | RCH_A | NRG | b:2 (2017-01..2018-01); d:24 (2015-12..2017-12) |
| ME | RCH_A | SERV | b:2 (2017-01..2018-01); d:24 (2015-12..2017-12) |
| ME | RCH_A | TOT_X_NRG_FOOD | b:2 (2017-01..2018-01); d:24 (2015-12..2017-12) |
| RS | I15 | FOOD | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I15 | IGD_NNRG | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I15 | NRG | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I15 | SERV | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I15 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I25 | FOOD | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I25 | IGD_NNRG | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I25 | NRG | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I25 | SERV | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | I25 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:133 (2005-12..2016-12) |
| RS | RCH_A | FOOD | b:2 (2017-01..2018-01); d:132 (2006-12..2017-12) |
| RS | RCH_A | IGD_NNRG | b:2 (2017-01..2018-01); d:132 (2006-12..2017-12) |
| RS | RCH_A | NRG | b:2 (2017-01..2018-01); d:132 (2006-12..2017-12) |
| RS | RCH_A | SERV | b:2 (2017-01..2018-01); d:132 (2006-12..2017-12) |
| RS | RCH_A | TOT_X_NRG_FOOD | b:2 (2017-01..2018-01); d:132 (2006-12..2017-12) |
| AL | I15 | FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I15 | IGD_NNRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I15 | NRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I15 | SERV | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I15 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I25 | FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I25 | IGD_NNRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I25 | NRG | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I25 | SERV | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | I25 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:13 (2015-12..2016-12) |
| AL | RCH_A | FOOD | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| AL | RCH_A | IGD_NNRG | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| AL | RCH_A | NRG | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| AL | RCH_A | SERV | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| AL | RCH_A | TOT_X_NRG_FOOD | b:2 (2017-01..2018-01); d:2 (2016-12..2017-12) |
| MK | I15 | FOOD | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I15 | IGD_NNRG | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I15 | NRG | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I15 | SERV | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I15 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I25 | FOOD | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I25 | IGD_NNRG | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I25 | NRG | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I25 | SERV | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | I25 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:145 (2004-12..2016-12) |
| MK | RCH_A | FOOD | b:2 (2017-01..2018-01); d:144 (2005-12..2017-12) |
| MK | RCH_A | IGD_NNRG | b:2 (2017-01..2018-01); d:144 (2005-12..2017-12) |
| MK | RCH_A | NRG | b:2 (2017-01..2018-01); d:144 (2005-12..2017-12) |
| MK | RCH_A | SERV | b:2 (2017-01..2018-01); d:144 (2005-12..2017-12) |
| MK | RCH_A | TOT_X_NRG_FOOD | b:2 (2017-01..2018-01); d:144 (2005-12..2017-12) |
| EA | I15 | CP03 | u:3 (2020-04..2021-02) |
| EA | I15 | CP05 | u:3 (2020-04..2021-02) |
| EA | I15 | CP09 | u:3 (2020-04..2021-02) |
| EA | I15 | CP11 | u:9 (2020-04..2021-05) |
| EA | I15 | FOOD | b:1 (2017-01..2017-01); d:252 (1996-01..2016-12) |
| EA | I15 | IGD_NNRG | b:1 (2017-01..2017-01); d:205 (1999-12..2016-12) |
| EA | I15 | NRG | b:1 (2017-01..2017-01); d:252 (1996-01..2016-12) |
| EA | I15 | SERV | b:1 (2017-01..2017-01); d:205 (1999-12..2016-12) |
| EA | I15 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:205 (1999-12..2016-12) |
| EA | I25 | CP03 | u:3 (2020-04..2021-02) |
| EA | I25 | CP05 | u:3 (2020-04..2021-02) |
| EA | I25 | CP09 | u:3 (2020-04..2021-02) |
| EA | I25 | CP11 | u:9 (2020-04..2021-05) |
| EA | I25 | FOOD | b:1 (2017-01..2017-01); d:252 (1996-01..2016-12) |
| EA | I25 | IGD_NNRG | b:1 (2017-01..2017-01); d:205 (1999-12..2016-12) |
| EA | I25 | NRG | b:1 (2017-01..2017-01); d:252 (1996-01..2016-12) |
| EA | I25 | SERV | b:1 (2017-01..2017-01); d:205 (1999-12..2016-12) |
| EA | I25 | TOT_X_NRG_FOOD | b:1 (2017-01..2017-01); d:205 (1999-12..2016-12) |
| EA | RCH_A | CP03 | u:6 (2020-04..2022-02) |
| EA | RCH_A | CP05 | u:6 (2020-04..2022-02) |
| EA | RCH_A | CP09 | u:6 (2020-04..2022-02) |
| EA | RCH_A | CP11 | u:16 (2020-04..2022-05) |
| EA | RCH_A | FOOD | b:2 (2017-01..2018-01); d:251 (1997-01..2017-12) |
| EA | RCH_A | IGD_NNRG | b:2 (2017-01..2018-01); d:204 (2000-12..2017-12) |
| EA | RCH_A | NRG | b:2 (2017-01..2018-01); d:251 (1997-01..2017-12) |
| EA | RCH_A | SERV | b:2 (2017-01..2018-01); d:204 (2000-12..2017-12) |
| EA | RCH_A | TOT_X_NRG_FOOD | b:2 (2017-01..2018-01); d:204 (2000-12..2017-12) |

Codes carrying any flag, over all special aggregates too (full detail in `peers_coverage.csv`):

| geo | unit | codes_with_flags |
|---|---|---|
| AL | I15 | 46 |
| AL | I25 | 46 |
| AL | RCH_A | 39 |
| EA | I15 | 52 |
| EA | I25 | 52 |
| EA | RCH_A | 52 |
| ME | I15 | 46 |
| ME | I25 | 46 |
| ME | RCH_A | 39 |
| MK | I15 | 39 |
| MK | I25 | 39 |
| MK | RCH_A | 39 |
| RS | I15 | 46 |
| RS | I25 | 46 |
| RS | RCH_A | 46 |
| XK | I15 | 46 |
| XK | I25 | 46 |
| XK | RCH_A | 36 |

### 1d. Series with internal gaps (all codes in scope)

| geo | unit | coicop18 | first_month | last_month | missing_internal |
|---|---|---|---|---|---|
| MK | I15 | TOT_X_AP | 2004-12 | 2026-08 | 35 |
| MK | I15 | TOT_X_APF | 2004-12 | 2026-08 | 35 |
| MK | I15 | TOT_X_APM | 2004-12 | 2026-08 | 35 |
| MK | I25 | TOT_X_AP | 2004-12 | 2026-08 | 35 |
| MK | I25 | TOT_X_APF | 2004-12 | 2026-08 | 35 |
| MK | I25 | TOT_X_APM | 2004-12 | 2026-08 | 35 |
| MK | RCH_A | TOT_X_AP | 2005-12 | 2026-08 | 47 |
| MK | RCH_A | TOT_X_APF | 2005-12 | 2026-08 | 47 |
| MK | RCH_A | TOT_X_APM | 2005-12 | 2026-08 | 47 |

### 1e. Codes in scope absent for a geo x unit

| geo | unit | absent_codes |
|---|---|---|
| AL | I15 | FROOPP, TOT_X_FROOPP |
| AL | I25 | FROOPP, TOT_X_FROOPP |
| AL | RCH_A | FROOPP, TOT_X_FROOPP |
| ME | I15 | FROOPP, TOT_X_FROOPP |
| ME | I25 | FROOPP, TOT_X_FROOPP |
| ME | RCH_A | FROOPP, TOT_X_FROOPP |
| MK | I15 | FROOPP, TOT_X_FROOPP |
| MK | I25 | FROOPP, TOT_X_FROOPP |
| MK | RCH_A | FROOPP, TOT_X_FROOPP |
| RS | I15 | FROOPP, TOT_X_FROOPP |
| RS | I25 | FROOPP, TOT_X_FROOPP |
| RS | RCH_A | FROOPP, TOT_X_FROOPP |
| XK | I15 | FROOPP, TOT_X_FROOPP |
| XK | I25 | FROOPP, TOT_X_FROOPP |
| XK | RCH_A | FROOPP, TOT_X_FROOPP |

### 2. Division weights (prc_hicp_iw), per geo

Rounding bound for 13 weights published to 2 decimals: 13 x 0.005 = 0.065.

| geo | years | n_years | contiguous | years_all_13 | max_abs_dev | years_dev_nonzero | years_outside_bound | decimals |
|---|---|---|---|---|---|---|---|---|
| XK | 2015-2026 | 12 | TRUE | 12 | 0.02 | 2 | 0 | 2 |
| ME | 2015-2026 | 12 | TRUE | 12 | 0.02 | 4 | 0 | 2 |
| RS | 2006-2026 | 21 | TRUE | 21 | 0.02 | 16 | 0 | 2 |
| AL | 2016-2026 | 11 | TRUE | 11 | 0.03 | 4 | 0 | 2 |
| MK | 2005-2026 | 22 | TRUE | 22 | 0.03 | 14 | 0 | 2 |
| EA | 1996-2026 | 31 | TRUE | 31 | 0.02 | 15 | 0 | 2 |

Item-weight codes with a value, by class x geo:

| class | XK | ME | RS | AL | MK | EA |
|---|---|---|---|---|---|---|
| division | 13 | 13 | 13 | 13 | 13 | 13 |
| special aggregate | 46 | 46 | 46 | 46 | 46 | 48 |
| sub-division | 493 | 493 | 497 | 493 | 497 | 493 |
| total | 1 | 1 | 1 | 1 | 1 | 1 |

Exceptions (fewer than 13 divisions, sum outside 1000 +/- 0.065, or any flag):

None.

Geo-years whose 13 division weights do not sum to exactly 1000.00 (all within the bound unless listed above):

| geo | year | wsum | dev |
|---|---|---|---|
| AL | 2016 | 1000.01 | 0.01 |
| AL | 2018 | 999.97 | -0.03 |
| AL | 2024 | 1000.01 | 0.01 |
| AL | 2025 | 1000.01 | 0.01 |
| EA | 1997 | 999.99 | -0.01 |
| EA | 1998 | 999.98 | -0.02 |
| EA | 1999 | 999.98 | -0.02 |
| EA | 2003 | 1000.01 | 0.01 |
| EA | 2008 | 999.99 | -0.01 |
| EA | 2009 | 999.99 | -0.01 |
| EA | 2011 | 999.99 | -0.01 |
| EA | 2013 | 1000.01 | 0.01 |
| EA | 2016 | 999.99 | -0.01 |
| EA | 2017 | 999.99 | -0.01 |
| EA | 2018 | 999.99 | -0.01 |
| EA | 2020 | 999.99 | -0.01 |
| EA | 2022 | 1000.01 | 0.01 |
| EA | 2023 | 999.99 | -0.01 |
| EA | 2026 | 1000.01 | 0.01 |
| ME | 2021 | 999.99 | -0.01 |
| ME | 2022 | 999.98 | -0.02 |
| ME | 2025 | 1000.01 | 0.01 |
| ME | 2026 | 1000.01 | 0.01 |
| MK | 2005 | 1000.02 | 0.02 |
| MK | 2008 | 1000.01 | 0.01 |
| MK | 2009 | 999.99 | -0.01 |
| MK | 2010 | 999.99 | -0.01 |
| MK | 2012 | 999.99 | -0.01 |
| MK | 2014 | 1000.03 | 0.03 |
| MK | 2015 | 999.99 | -0.01 |
| MK | 2017 | 999.99 | -0.01 |
| MK | 2018 | 1000.01 | 0.01 |
| MK | 2019 | 999.99 | -0.01 |
| MK | 2020 | 999.99 | -0.01 |
| MK | 2022 | 999.99 | -0.01 |
| MK | 2023 | 999.99 | -0.01 |
| MK | 2026 | 999.99 | -0.01 |
| RS | 2006 | 999.98 | -0.02 |
| RS | 2007 | 1000.02 | 0.02 |
| RS | 2008 | 999.99 | -0.01 |
| RS | 2009 | 999.99 | -0.01 |
| RS | 2010 | 1000.01 | 0.01 |
| RS | 2011 | 999.99 | -0.01 |
| RS | 2012 | 1000.01 | 0.01 |
| RS | 2014 | 1000.01 | 0.01 |
| RS | 2015 | 1000.01 | 0.01 |
| RS | 2017 | 1000.01 | 0.01 |
| RS | 2019 | 999.99 | -0.01 |
| RS | 2021 | 999.99 | -0.01 |
| RS | 2022 | 1000.02 | 0.02 |
| RS | 2024 | 999.99 | -0.01 |
| RS | 2025 | 1000.01 | 0.01 |
| RS | 2026 | 1000.02 | 0.02 |
| XK | 2023 | 999.98 | -0.02 |
| XK | 2026 | 999.99 | -0.01 |

### 3. Headline consistency: YoY derived from TOTAL index vs published RCH_A

Derived = 100 x (I_m / I_m-12 - 1). Diff = derived - published, pp. Rounding bound = half a unit of
RCH_A's last decimal + 100 x h x (1/I_m-12 + I_m/I_m-12^2), h = half a unit of the index's last decimal.

Decimals published (TOTAL):

| geo | dec_I15 | dec_I25 | dec_RCH_A |
|---|---|---|---|
| AL | 2 | 2 | 1 |
| EA | 2 | 2 | 1 |
| ME | 2 | 2 | 1 |
| MK | 2 | 2 | 1 |
| RS | 2 | 2 | 1 |
| XK | 2 | 2 | 1 |

| geo | months | n | max_abs_diff_I15 | month_of_max_I15 | n_gt_0.05_I15 | max_abs_diff_I25 | n_gt_0.05_I25 | max_rounding_bound | n_beyond_bound |
|---|---|---|---|---|---|---|---|---|---|
| XK | 2016-01..2026-08 | 128 | 0.059 | 2023-09 | 5 | 0.050 | 0 | 0.064 | 1 |
| ME | 2015-12..2026-08 | 129 | 0.053 | 2024-10 | 6 | 0.049 | 0 | 0.065 | 0 |
| RS | 2006-12..2026-08 | 237 | 0.058 | 2008-03 | 12 | 0.050 | 0 | 0.081 | 0 |
| AL | 2016-12..2026-08 | 117 | 0.057 | 2018-10 | 8 | 0.050 | 1 | 0.064 | 0 |
| MK | 2005-12..2026-08 | 249 | 0.064 | 2017-08 | 17 | 0.050 | 0 | 0.069 | 3 |
| EA | 1997-01..2026-08 | 356 | 0.062 | 2008-09 | 25 | 0.050 | 0 | 0.068 | 2 |

Months where |diff| > 0.05 pp under I15 or I25:

| geo | month | RCH_A | flag_RCH_A | der_I15 | diff_I15 | der_I25 | diff_I25 | bound |
|---|---|---|---|---|---|---|---|---|
| AL | 2017-08 | 2.6 |  | 2.547 | -0.053 | 2.555 | -0.045 | 0.063 |
| AL | 2018-10 | 1.3 |  | 1.243 | -0.057 | 1.250 | -0.050 | 0.063 |
| AL | 2019-12 | 1.4 |  | 1.450 | 0.050 | 1.448 | 0.048 | 0.063 |
| AL | 2021-02 | 1.3 |  | 1.351 | 0.051 | 1.349 | 0.049 | 0.062 |
| AL | 2021-08 | 2.7 |  | 2.650 | -0.050 | 2.661 | -0.039 | 0.062 |
| AL | 2025-09 | 2.3 |  | 2.249 | -0.051 | 2.258 | -0.042 | 0.060 |
| AL | 2025-12 | 2.1 |  | 2.151 | 0.051 | 2.150 | 0.050 | 0.060 |
| AL | 2026-03 | 2.5 |  | 2.551 | 0.051 | 2.546 | 0.046 | 0.060 |
| EA | 1997-01 | 2.1 |  | 2.043 | -0.057 | 2.050 | -0.050 | 0.068 |
| EA | 1997-03 | 1.5 |  | 1.552 | 0.052 | 1.530 | 0.030 | 0.068 |
| EA | 1999-11 | 1.4 |  | 1.450 | 0.050 | 1.449 | 0.049 | 0.068 |
| EA | 2000-05 | 1.7 |  | 1.760 | 0.060 | 1.746 | 0.046 | 0.067 |
| EA | 2000-08 | 2.1 |  | 2.049 | -0.051 | 2.069 | -0.031 | 0.067 |
| EA | 2000-11 | 2.4 |  | 2.459 | 0.059 | 2.443 | 0.043 | 0.067 |
| EA | 2001-10 | 2.2 |  | 2.261 | 0.061 | 2.238 | 0.038 | 0.067 |
| EA | 2001-12 | 2 |  | 2.053 | 0.053 | 2.041 | 0.041 | 0.067 |
| EA | 2004-05 | 2.4 |  | 2.452 | 0.052 | 2.443 | 0.043 | 0.066 |
| EA | 2004-11 | 2.3 |  | 2.240 | -0.060 | 2.254 | -0.046 | 0.066 |
| EA | 2005-12 | 2.2 |  | 2.254 | 0.054 | 2.242 | 0.042 | 0.066 |
| EA | 2006-11 | 1.9 |  | 1.849 | -0.051 | 1.853 | -0.047 | 0.065 |
| EA | 2007-02 | 1.9 |  | 1.846 | -0.054 | 1.850 | -0.050 | 0.065 |
| EA | 2007-11 | 3 |  | 3.056 | 0.056 | 3.047 | 0.047 | 0.065 |
| EA | 2008-06 | 4 |  | 3.950 | -0.050 | 3.952 | -0.048 | 0.065 |
| EA | 2008-09 | 3.7 |  | 3.638 | -0.062 | 3.655 | -0.045 | 0.065 |
| EA | 2009-07 | -0.7 |  | -0.642 | 0.058 | -0.658 | 0.042 | 0.064 |
| EA | 2010-01 | 1 |  | 0.948 | -0.052 | 0.951 | -0.049 | 0.064 |
| EA | 2011-07 | 2.5 |  | 2.561 | 0.061 | 2.548 | 0.048 | 0.064 |
| EA | 2015-07 | 0.6 |  | 0.542 | -0.058 | 0.556 | -0.044 | 0.063 |
| EA | 2015-12 | 0.2 |  | 0.251 | 0.051 | 0.245 | 0.045 | 0.063 |
| EA | 2016-06 | 0.1 |  | 0.050 | -0.050 | 0.051 | -0.049 | 0.063 |
| EA | 2022-04 | 7.5 |  | 7.439 | -0.061 | 7.451 | -0.049 | 0.062 |
| EA | 2023-04 | 6.9 |  | 6.959 | 0.059 | 6.946 | 0.046 | 0.062 |
| EA | 2026-07 | 2.9 |  | 2.951 | 0.051 | 2.941 | 0.041 | 0.060 |
| ME | 2018-04 | 3.5 |  | 3.551 | 0.051 | 3.539 | 0.039 | 0.064 |
| ME | 2019-03 | 0.9 |  | 0.848 | -0.052 | 0.851 | -0.049 | 0.064 |
| ME | 2020-04 | -0.9 |  | -0.849 | 0.051 | -0.856 | 0.044 | 0.063 |
| ME | 2020-08 | -1.3 |  | -1.250 | 0.050 | -1.252 | 0.048 | 0.063 |
| ME | 2021-10 | 3.8 |  | 3.853 | 0.053 | 3.849 | 0.049 | 0.064 |
| ME | 2024-10 | 1.7 |  | 1.753 | 0.053 | 1.749 | 0.049 | 0.061 |
| MK | 2006-07 | 4.2 |  | 4.253 | 0.053 | 4.241 | 0.041 | 0.069 |
| MK | 2007-01 | 1.2 |  | 1.148 | -0.052 | 1.153 | -0.047 | 0.068 |
| MK | 2007-04 | 1.3 |  | 1.248 | -0.052 | 1.253 | -0.047 | 0.068 |
| MK | 2009-06 | -1 |  | -0.950 | 0.050 | -0.966 | 0.034 | 0.066 |
| MK | 2009-07 | -0.6 |  | -0.653 | -0.053 | -0.649 | -0.049 | 0.066 |
| MK | 2010-11 | 2.5 |  | 2.450 | -0.050 | 2.452 | -0.048 | 0.067 |
| MK | 2013-06 | 4.2 |  | 4.144 | -0.056 | 4.151 | -0.049 | 0.066 |
| MK | 2016-03 | -0.1 |  | -0.160 | -0.060 | -0.149 | -0.049 | 0.065 |
| MK | 2017-07 | 2.2 |  | 2.138 | -0.062 | 2.151 | -0.049 | 0.065 |
| MK | 2017-08 | 2.4 |  | 2.464 | 0.064 | 2.445 | 0.045 | 0.065 |
| MK | 2018-02 | 3.1 |  | 3.045 | -0.055 | 3.052 | -0.048 | 0.065 |
| MK | 2018-03 | 2.7 |  | 2.649 | -0.051 | 2.664 | -0.036 | 0.065 |
| MK | 2018-10 | 2.4 |  | 2.345 | -0.055 | 2.356 | -0.044 | 0.065 |
| MK | 2018-12 | 1.5 |  | 1.550 | 0.050 | 1.546 | 0.046 | 0.065 |
| MK | 2021-03 | 2.6 |  | 2.656 | 0.056 | 2.645 | 0.045 | 0.064 |
| MK | 2024-07 | 3.5 |  | 3.552 | 0.052 | 3.546 | 0.046 | 0.061 |
| MK | 2026-05 | 4.9 |  | 4.849 | -0.051 | 4.851 | -0.049 | 0.060 |
| RS | 2007-07 | 3.9 |  | 3.843 | -0.057 | 3.859 | -0.041 | 0.079 |
| RS | 2008-02 | 12 |  | 12.054 | 0.054 | 12.047 | 0.047 | 0.080 |
| RS | 2008-03 | 13.4 |  | 13.458 | 0.058 | 13.447 | 0.047 | 0.080 |
| RS | 2011-08 | 10.7 |  | 10.644 | -0.056 | 10.652 | -0.048 | 0.072 |
| RS | 2013-08 | 7.5 |  | 7.449 | -0.051 | 7.455 | -0.045 | 0.068 |
| RS | 2014-09 | 2.5 |  | 2.448 | -0.052 | 2.452 | -0.048 | 0.066 |
| RS | 2015-01 | 0.4 |  | 0.348 | -0.052 | 0.354 | -0.046 | 0.066 |
| RS | 2015-08 | 2.2 |  | 2.251 | 0.051 | 2.232 | 0.032 | 0.066 |
| RS | 2019-01 | 2 |  | 2.051 | 0.051 | 2.046 | 0.046 | 0.065 |
| RS | 2019-08 | 1.4 |  | 1.450 | 0.050 | 1.447 | 0.047 | 0.065 |
| RS | 2020-06 | 1.8 |  | 1.852 | 0.052 | 1.845 | 0.045 | 0.065 |
| RS | 2022-02 | 8.8 |  | 8.750 | -0.050 | 8.757 | -0.043 | 0.065 |
| XK | 2016-09 | 0.5 |  | 0.553 | 0.053 | 0.544 | 0.044 | 0.064 |
| XK | 2018-10 | 1.5 |  | 1.444 | -0.056 | 1.461 | -0.039 | 0.063 |
| XK | 2020-01 | 1.6 |  | 1.550 | -0.050 | 1.555 | -0.045 | 0.063 |
| XK | 2023-09 | 4.3 |  | 4.241 | -0.059 | 4.253 | -0.047 | 0.061 |
| XK | 2025-02 | 1.8 |  | 1.749 | -0.051 | 1.752 | -0.048 | 0.060 |

Months where |diff| exceeds that index's own rounding bound:

| geo | month | RCH_A | diff_I15 | bound_I15 | diff_I25 | bound_I25 |
|---|---|---|---|---|---|---|
| EA | 2008-09 | 3.7 | -0.062 | 0.061 | -0.045 | 0.065 |
| EA | 2022-04 | 7.5 | -0.061 | 0.060 | -0.049 | 0.062 |
| MK | 2016-03 | -0.1 | -0.060 | 0.060 | -0.049 | 0.065 |
| MK | 2017-07 | 2.2 | -0.062 | 0.060 | -0.049 | 0.065 |
| MK | 2017-08 | 2.4 | 0.064 | 0.060 | 0.045 | 0.065 |
| XK | 2023-09 | 4.3 | -0.059 | 0.058 | -0.047 | 0.061 |

### 4. Aggregation residual: sum_i (w_i / 1000) x division YoY_i - headline YoY (pp)

| variant | desc |
|---|---|
| V1 | published RCH_A, weights of calendar year t |
| V2 | YoY derived from I15, weights of calendar year t |
| V3 | published RCH_A, weights of calendar year t-1 |

Months = every month where the headline, all 13 division rates and all 13 weights exist.

Full common span:

| variant | geo | months | n | min | p10 | median | p90 | max | max_abs |
|---|---|---|---|---|---|---|---|---|---|
| V1 | XK | 2016-01..2026-08 | 128 | -0.144 | -0.063 | 0.008 | 0.084 | 0.264 | 0.264 |
| V1 | ME | 2015-12..2026-08 | 129 | -0.190 | -0.046 | 0.034 | 0.138 | 0.491 | 0.491 |
| V1 | RS | 2006-12..2026-08 | 237 | -0.084 | -0.030 | 0.031 | 0.237 | 0.975 | 0.975 |
| V1 | AL | 2016-12..2026-08 | 117 | -0.271 | -0.053 | 0.016 | 0.092 | 0.234 | 0.271 |
| V1 | MK | 2005-12..2026-08 | 249 | -0.387 | -0.091 | 0.014 | 0.125 | 0.347 | 0.387 |
| V1 | EA | 1997-01..2026-08 | 356 | -0.170 | -0.047 | 0.000 | 0.049 | 0.180 | 0.180 |
| V2 | XK | 2016-01..2026-08 | 128 | -0.098 | -0.069 | 0.012 | 0.093 | 0.215 | 0.215 |
| V2 | ME | 2015-12..2026-08 | 129 | -0.214 | -0.032 | 0.020 | 0.150 | 0.445 | 0.445 |
| V2 | RS | 2006-12..2026-08 | 237 | -0.099 | -0.011 | 0.019 | 0.252 | 0.972 | 0.972 |
| V2 | AL | 2016-12..2026-08 | 117 | -0.274 | -0.032 | 0.007 | 0.084 | 0.235 | 0.274 |
| V2 | MK | 2005-12..2026-08 | 249 | -0.368 | -0.078 | 0.014 | 0.122 | 0.286 | 0.368 |
| V2 | EA | 1997-01..2026-08 | 356 | -0.199 | -0.021 | 0.002 | 0.027 | 0.187 | 0.199 |
| V3 | XK | 2016-01..2026-08 | 128 | -0.210 | -0.069 | 0.019 | 0.173 | 0.534 | 0.534 |
| V3 | ME | 2016-01..2026-08 | 128 | -0.390 | -0.140 | -0.005 | 0.091 | 0.596 | 0.596 |
| V3 | RS | 2007-01..2026-08 | 236 | -0.264 | -0.064 | 0.019 | 0.128 | 0.494 | 0.494 |
| V3 | AL | 2017-01..2026-08 | 116 | -0.303 | -0.092 | 0.015 | 0.145 | 0.308 | 0.308 |
| V3 | MK | 2006-01..2026-08 | 248 | -0.138 | -0.088 | 0.004 | 0.098 | 0.265 | 0.265 |
| V3 | EA | 1997-01..2026-08 | 356 | -0.335 | -0.063 | -0.007 | 0.043 | 0.132 | 0.335 |

2021-01..2023-12 only:

| variant | geo | months | n | min | p10 | median | p90 | max | max_abs |
|---|---|---|---|---|---|---|---|---|---|
| V1 | XK | 2021-01..2023-12 | 36 | -0.136 | -0.072 | 0.017 | 0.132 | 0.264 | 0.264 |
| V1 | ME | 2021-01..2023-12 | 36 | -0.190 | -0.090 | 0.005 | 0.240 | 0.491 | 0.491 |
| V1 | RS | 2021-01..2023-12 | 36 | -0.044 | -0.026 | 0.030 | 0.120 | 0.216 | 0.216 |
| V1 | AL | 2021-01..2023-12 | 36 | -0.271 | -0.058 | 0.008 | 0.097 | 0.234 | 0.271 |
| V1 | MK | 2021-01..2023-12 | 36 | -0.387 | -0.295 | -0.000 | 0.077 | 0.126 | 0.387 |
| V1 | EA | 2021-01..2023-12 | 36 | -0.170 | -0.124 | 0.014 | 0.100 | 0.180 | 0.180 |
| V2 | XK | 2021-01..2023-12 | 36 | -0.093 | -0.076 | 0.023 | 0.119 | 0.215 | 0.215 |
| V2 | ME | 2021-01..2023-12 | 36 | -0.214 | -0.070 | 0.002 | 0.252 | 0.445 | 0.445 |
| V2 | RS | 2021-01..2023-12 | 36 | -0.014 | -0.004 | 0.015 | 0.141 | 0.173 | 0.173 |
| V2 | AL | 2021-01..2023-12 | 36 | -0.274 | -0.058 | -0.002 | 0.058 | 0.235 | 0.274 |
| V2 | MK | 2021-01..2023-12 | 36 | -0.368 | -0.304 | 0.008 | 0.075 | 0.085 | 0.368 |
| V2 | EA | 2021-01..2023-12 | 36 | -0.199 | -0.149 | 0.009 | 0.097 | 0.187 | 0.199 |
| V3 | XK | 2021-01..2023-12 | 36 | -0.092 | -0.039 | 0.083 | 0.207 | 0.534 | 0.534 |
| V3 | ME | 2021-01..2023-12 | 36 | -0.390 | -0.208 | -0.052 | 0.098 | 0.596 | 0.596 |
| V3 | RS | 2021-01..2023-12 | 36 | -0.130 | -0.028 | 0.065 | 0.148 | 0.172 | 0.172 |
| V3 | AL | 2021-01..2023-12 | 36 | -0.303 | -0.220 | 0.001 | 0.143 | 0.187 | 0.303 |
| V3 | MK | 2021-01..2023-12 | 36 | -0.129 | -0.029 | 0.038 | 0.117 | 0.148 | 0.148 |
| V3 | EA | 2021-01..2023-12 | 36 | -0.335 | -0.222 | -0.011 | 0.066 | 0.103 | 0.335 |

Largest absolute change in any residual from dividing by sum(w) instead of 1000: 0.0003 pp.

### 5. Exact published values, TOTAL, unit RCH_A (annual rate of change, %)

(a)/(c) Peak in 2021-01..2023-12 (all months listed if tied):

| geo | peak_RCH_A | peak_month | n_months_at_peak | der_I15_at_peak | flags |
|---|---|---|---|---|---|
| XK | 14.2 | 2022-07 | 1 | 14.20 |  |
| ME | 15.8 | 2022-11 | 1 | 15.78 |  |
| RS | 15.6 | 2023-03 | 1 | 15.56 |  |
| AL | 8.0 | 2022-10, 2022-11 | 2 | 8.04, 7.99 |  |
| MK | 19.4 | 2022-10 | 1 | 19.36 |  |
| EA | 10.6 | 2022-10 | 1 | 10.62 |  |

(b) XK, 2024-10: RCH_A = 0.4.

(d) All geos, 2024-10, ranked by RCH_A descending (`min_rank`, ties share a rank):

| rank | geo | RCH_A | der_I15 | flag_RCH_A |
|---|---|---|---|---|
| 1 | MK | 4.6 | 4.62 |  |
| 1 | RS | 4.6 | 4.59 |  |
| 3 | AL | 2.3 | 2.29 |  |
| 4 | EA | 2.0 | 2.00 |  |
| 5 | ME | 1.7 | 1.75 |  |
| 6 | XK | 0.4 | 0.42 |  |

### 6. BA in Eurostat HICP tables (SDMX contentconstraint, geo dimension)

Tables scanned: 48 (every catalogue dataset/table whose title contains "HICP" or "Harmonised index of consumer prices", or whose code starts prc_hicp / teicp / ei_cphi). Constraint parsed: 48. Listing geo BA in the constraint: 1 (see 6b for whether data exist).

| code | title | last_update | n_geo | has_BA | wb_present |
|---|---|---|---|---|---|
| ei_cphi_m | Harmonised index of consumer prices - monthly data | 17.09.2026 | 49 | TRUE | XK ME RS AL MK |
| prc_hicp_admp | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - administered prices composition | 17.07.2026 | 36 | FALSE | XK ME RS AL MK |
| prc_hicp_aind | HICP - annual data (average index and rate of change) (1996-2025) | 06.02.2026 | 45 | FALSE | XK ME RS AL MK |
| prc_hicp_ainr | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - indices and rates of change, annual data | 17.09.2026 | 46 | FALSE | XK ME RS AL MK |
| prc_hicp_apc | HICP - administered prices (composition) (2001-2025) | 06.02.2026 | 34 | FALSE | ME RS AL MK |
| prc_hicp_cann | HICP at constant tax rates - monthly data (annual rate of change) (2003-2025) | 06.02.2026 | 39 | FALSE | ME RS MK |
| prc_hicp_cind | HICP at constant tax rates - monthly data (index) (2002-2025) | 06.02.2026 | 39 | FALSE | ME RS MK |
| prc_hicp_cmon | HICP at constant tax rates - monthly data (monthly rate of change) (2002-2025) | 06.02.2026 | 39 | FALSE | ME RS MK |
| prc_hicp_cow | HICP - country weights (1996-2025) | 20.08.2025 | 37 | FALSE |  |
| prc_hicp_ct | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - indices and rates of change at constant tax rates, monthly data | 17.09.2026 | 40 | FALSE | XK ME RS MK |
| prc_hicp_ctr | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - contributions to euro area annual inflation | 17.09.2026 | 1 | FALSE |  |
| prc_hicp_ctrb | HICP - contributions to EA annual inflation (in percentage points) (2002-2025) | 06.02.2026 | 1 | FALSE |  |
| prc_hicp_cw | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - country weights | 17.07.2026 | 37 | FALSE |  |
| prc_hicp_fp | HICP - first published data (monthly index and annual rate of change) (1996-2025) | 06.02.2026 | 45 | FALSE | ME RS AL MK |
| prc_hicp_fpd | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - first released data | 17.09.2026 | 46 | FALSE | XK ME RS AL MK |
| prc_hicp_inw | HICP - item weights (1996-2025) | 20.08.2025 | 45 | FALSE | XK ME RS AL MK |
| prc_hicp_iw | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - item weights | 17.09.2026 | 46 | FALSE | XK ME RS AL MK |
| prc_hicp_manr | HICP - monthly data (annual rate of change) (1997-2025) | 06.02.2026 | 45 | FALSE | XK ME RS AL MK |
| prc_hicp_midx | HICP - monthly data (index) (1996-2025) | 06.02.2026 | 45 | FALSE | XK ME RS AL MK |
| prc_hicp_minr | Harmonised index of consumer prices (HICP) - ECOICOP ver.2 - indices and rates of change, monthly data | 17.09.2026 | 46 | FALSE | XK ME RS AL MK |
| prc_hicp_mmor | HICP - monthly data (monthly rate of change) (1996-2025) | 06.02.2026 | 45 | FALSE | XK ME RS AL MK |
| prc_hicp_mv12r | HICP - monthly data (12-month average rate of change) (1997-2025) | 06.02.2026 | 45 | FALSE | XK ME RS AL MK |
| tec00027 | HICP - all items - annual average indices | 17.09.2026 | 44 | FALSE | XK ME RS AL MK |
| tec00118 | HICP - inflation rate | 17.09.2026 | 43 | FALSE | XK ME RS AL MK |
| teicp000 | HICP - all items | 17.09.2026 | 43 | FALSE | XK ME RS AL MK |
| teicp010 | HICP - food | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp020 | HICP - alcohol and tobacco | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp030 | HICP - clothing | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp040 | HICP - housing | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp050 | HICP - household equipment | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp060 | HICP - health | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp070 | HICP - transport | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp080 | HICP - communications | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp090 | HICP - recreation and culture | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp100 | HICP - education | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp110 | HICP - hotels and restaurants | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp120 | HICP - miscellaneous goods and services | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp130 | HICP - insurance and financial services | 17.09.2026 | 41 | FALSE | XK ME RS AL MK |
| teicp200 | HICP - all items excluding energy, food, alcohol and tobacco | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp210 | HICP - all items excluding energy | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp220 | HICP - all items excluding energy and unprocessed food | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp230 | HICP - all items excluding energy and seasonal food | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp240 | HICP - all items excluding tobacco | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp250 | HICP - energy | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp260 | HICP - food, alcohol and tobacco | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp270 | House price index (2025 = 100) - quarterly data | 02.07.2026 | 36 | FALSE |  |
| teicp280 | HICP - services | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |
| teicp290 | HICP - non-energy industrial goods | 17.09.2026 | 42 | FALSE | XK ME RS AL MK |

#### 6b. `ei_cphi_m`, geo BA

- Key query `https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ei_cphi_m/...BA?format=SDMX-CSV`: 0 rows.
- Unfiltered bulk `https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ei_cphi_m?format=SDMX-CSV&compressed=true` (LAST UPDATE 17/09/26 11:00:00): 1050411 rows in total, 0 with geo BA, of which 0 carry a value.


## 7. BiH: national CPI source (BHAS), not downloaded

**Eurostat.** BA does not appear in `prc_hicp_minr` or `prc_hicp_iw` (0 bulk rows). Of the
48 HICP tables scanned (section 6), only `ei_cphi_m` lists BA in its content constraint.
Both its key-filtered data query and its full bulk file return 0 BA rows. No Eurostat HICP
table holds BA observations in this vintage.

**Source identified:** Agency for Statistics of Bosnia and Herzegovina (BHAS), national
Consumer Price Index. This is not an HICP. As instructed, the data files were **not
downloaded or read**. The file formats below come from HTTP HEAD responses, and the
content details come from BHAS's ESMS metadata page.

| item | value | source |
|---|---|---|
| Prices landing page | https://bhas.gov.ba/Calendar/Category/10?lang=en | site |
| Time series, current | https://bhas.gov.ba/data/Publikacije/VremenskeSerije/PRI_01.xlsx — `.xlsx` (HEAD: 112,847 bytes); listed on the page as updated 9/25/2026 | page, HEAD |
| Time series, older | `PRI_01_2010_2015.xls` and `PRI_01_2005_2010.xls` (same folder), `.xls` | page, HEAD |
| Monthly first release | PDF, e.g. https://bhas.gov.ba/data/Publikacije/Saopstenja/2026/PRI_01_2026_08_1_BS.pdf (August 2026, released 9/25/2026) | page |
| Annual bulletin | PDF, e.g. https://bhas.gov.ba/data/Publikacije/Bilteni/2026/PRI_00_2025_TB_1_BS.pdf | page |
| ESMS metadata | https://bhas.gov.ba/data/Publikacije/ESMS/PRI00_mjesecno_istrazivanje_o_indeksu_potrosackih_cijena_u_BiH_EN.htm (metadata last update 10/11/2025; saved raw) | — |
| COICOP depth | ESMS 3.2: classified to 4-digit COICOP/HICP categories and subcategories. The 12 main categories listed are 01–12 with 12 "Other goods and services", which is the pre-ECOICOP-ver.2 12-division structure, not the 13 divisions of `prc_hicp_minr` | ESMS 3.2 |
| Base period | 2015 (ESMS 3.9) | ESMS |
| Periodicity / availability | Monthly, "2005-ongoing" (ESMS 3.8, 9); published about T+25 days; data published as final, not revised (ESMS 14.1, 17.2) | ESMS |
| Weights | Household Budget Survey, conducted every four years (ESMS 18.5); horizontal population weights across 12 cities | ESMS |
| Index type | Laspeyres; elementary indices by geometric mean (ESMS 3.1, 18.5) | ESMS |

Not verified, because it would need the data file: which COICOP levels and which months
`PRI_01.xlsx` actually contains, and whether division weights are published with it.

## 8. Metadata: HICP conformity for enlargement countries, and Kosova-specific notes

All pages are saved raw in `data/raw/2026-09-29/`. Eurostat pages are written in English and
use Eurostat's own designation for Kosova. That designation is a source string and is kept
verbatim in the saved files only.

### Eurostat, all enlargement countries

| note | URL | date on page |
|---|---|---|
| HICP ESMS §3.1: HICPs for Albania, Georgia, Montenegro, North Macedonia, Serbia and Türkiye (enlargement countries) and for Kosova are published. Eurostat states their comparability may differ, because these countries are still aligning with the EU acquis and their conformity with HICP methodological requirements "has not been fully evaluated by Eurostat". | https://ec.europa.eu/eurostat/cache/metadata/en/prc_hicp_esms.htm | metadata last update 4 February 2026 |
| Same page, §3.2: ECOICOP ver. 2 applies to the full series starting with the January 2026 data (Commission Delegated Regulation (EU) 2024/3159, http://data.europa.eu/eli/reg_del/2024/3159/oj). ECOICOP ver. 2 has 13 divisions; the old ECOICOP had 12. The ECOICOP datasets (1996–2025) are archived and frozen. Special aggregates are computed from the ECOICOP 5-digit level from the January 2017 index onwards. | same | same |
| Same page, §3.9 / §4: the index reference period is 2025=100 from 2026 (Commission Implementing Regulation (EU) 2025/1182, https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32025R1182). ECOICOP ver. 2 datasets carry 2025=100 and 2015=100. | same | same |
| Q&A Q8: the all-items HICP back series (1996–2025) had to stay identical to the second decimal, and the back-series compilation methods are documented in the country metadata files. Q17.b: a statistical break in the special-aggregate series in January 2017. Annex tables 1–2 (impact of the ECOICOP ver. 2 transition) list EU/EFTA countries and aggregates only; no enlargement country appears. | https://ec.europa.eu/eurostat/documents/272892/11336726/HICP+improvements+-+Questions+and+Answers-2026-EN.pdf/dff14a89-9f65-8371-e143-488231305710?t=1766052045691 | 25 February 2026, updated 3 March 2026 |

### Country ESMS pages (linked from the HICP ESMS "Enlargement countries" group)

| geo | URL | metadata last update | national start of series | stated base | ECOICOP ver. 2 / 2025=100 mentioned | compliance field (§11.2.1) |
|---|---|---|---|---|---|---|
| XK | https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_xk.htm | 23 October 2023 | CPI "in effect an HICP" from the December 2014 index; renamed HICP from January 2015 (§3.8.2) | 2015=100 | no | "Not applicable." |
| ME | https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_me.htm | 16 August 2023 | HICP produced by MONSTAT from January 2011 (§3.8.2, §15.2) | 2015=100 | no | refers to Eurostat's HICP quality page |
| RS | https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_rs.htm | 1 September 2023 | harmonised coverage since January 2013, back-cast to January 2005; 5-digit ECOICOP on Eurostat from January 2016 (§3.8.2) | 2015=100 | no | "Not available." |
| AL | https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_al.htm | 18 September 2023 | available from 2016 (§3.8.2) | 2015=100 | no | "Not available." |
| AL (second page) | https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi3_al.htm | 11 September 2025 | series started in 2016 (§3.8.2) | 2015=100 | no | — |
| MK | https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_mk.htm | 18 September 2023 | January 2005 (§3.8.2); rebased 2005=100 → 2015=100 from January 2016 (§15.2) | 2015=100 | no | "Not available." |

None of the country pages mentions ECOICOP ver. 2, 2025=100 or a back-series method (text
search for "ECOICOP ver", "version 2", "2025=100"). All six pages are older than or
contemporaneous with Q&A Q8, which says country metadata files document the back-series
methods.

### Kosova-specific notes (XK page, verbatim facts, no interpretation)

- **Weight reference years (§13.1, §18.1.1.3):**
  - 2016 weights: national accounts (NA) 2014.
  - 2017: NA reference year 2015.
  - 2018: NA 2016.
  - From January 2019: NA 2017.
  - From January 2020: NA 2018.
  - From January 2021: NA 2019.
  - 2023 weights: NA reference year 2020/2021, prepared with IPA2019 technical support.
  - **Not stated on the page:** weight years 2015, 2022, 2024, 2025, 2026.
- **Weight updating (§18.1.1):**
  - Weights are updated annually, with a t−2 source.
  - They are price-updated to the previous December's price level.
  - Higher-level weights come from household final monetary consumption expenditure.
  - The most detailed weights come from the HBS.
- **Classification (§3.2, §10):** "ECOICOP". The first release covers "the 12 ECOICOP
  Divisions". There is no mention of ECOICOP ver. 2, although `prc_hicp_minr` publishes 13
  ECOICOP ver. 2 divisions for XK from 2015-01 (section 1b).
- **Methodology and coverage:**
  - Prices are collected in 14 municipalities.
  - In rural parts, only food items are priced (§3.7.2).
  - Laspeyres-type aggregation; Jevons elementary indices (§18.1.1).
  - "Actually we are in process of implementation of HICP without CT" (§3.8.2, verbatim).
- **Quality (§11.2.2, §13.1):** KAS describes the HICP as "largely compliant" and "still
  under development". §11.2.1 compliance monitoring: "Not applicable."
- **Revision (§17.2):** the CPI was revised for May 2002 to December 2006 after a
  methodological error.
- **Template text:** §3.8.1 says the HICP series "started in January 1997". That is the
  generic EU sentence. It is not consistent with §3.8.2 or with the data, which starts in
  2015-01. It is recorded as published.

## 9. Recorded without interpretation

- **Special aggregates:**
  - For every peer, `FOOD`, `NRG`, `IGD_NNRG`, `SERV` and `TOT_X_NRG_FOOD` carry flag
    `d` up to 2016-12 and flag `b` at 2017-01 (index units). `RCH_A` carries `b` at
    2017-01 and 2018-01. The date of the `b` flag matches the January 2017 break in the
    Q&A (Q17.b) and the HICP ESMS §3.2.
  - XK's special aggregates start in 2015-12, while XK's TOTAL and divisions start in
    2015-01. For every other peer, they start in the same month as TOTAL.
- **Other coverage:**
  - `FROOPP` and `TOT_X_FROOPP` exist for EA only.
  - MK's `TOT_X_AP*` series have internal gaps (section 1d).
  - TOTAL and the 13 divisions have no flags and no internal gaps for any peer.
  - EA carries `u` flags on CP03, CP05, CP09 and CP11 in 2020–2022 (section 1c).
- **Start dates, metadata vs `prc_hicp_minr` (first `I15` month):**
  - ME: metadata says HICP from January 2011; the data starts 2014-12.
  - RS: harmonised from January 2013, back to January 2005; the data starts 2005-12.
  - AL: metadata says 2016; the data starts 2015-12.
  - MK: metadata says January 2005; the data starts 2004-12.
  - XK: metadata says January 2015 (December 2014 index); the data starts 2015-01.
- **Headline check:** six months exceed their own rounding bound under `I15`: XK 2023-09,
  MK 2016-03, 2017-07, 2017-08, EA 2008-09, 2022-04. None exceeds it under `I25`
  (section 3).
- **Tied values:** AL's 2021–23 peak value 8.0 occurs in two months (2022-10, 2022-11).
  MK and RS tie at 4.6 in 2024-10.

## Open decisions for Plator

Every choice this session met. None was taken. Where the session had to proceed, the
default used is stated, and it is reversible.

1. **Folder layout.** *Resolved 2026-09-29 by Plator: option (b).*
   - The report and CSVs were first written to `hicp-gap/verification/`. They have now been
     moved to `verify/`, next to the scripts, and `02_peers.R` writes there.
   - The re-run after the move reproduced all 7 script outputs byte-identically.
2. **Vintage.**
   - The 2026-09-23 bulk (Eurostat 17.09.2026) was reused, and the catalogue confirms it is
     current.
   - Options: (a) freeze this vintage for the peer work; (b) re-pull after the next
     Eurostat HICP release before any build.
3. **Peer set and BiH.**
   - BiH has no Eurostat HICP data. The BHAS CPI is a national CPI: 12 COICOP-1999-style
     divisions, base 2015, HBS weights every four years.
   - Options: (a) drop BiH; (b) include the BHAS CPI headline only, with a comparability
     caveat; (c) include BHAS at division level, which needs a 12→13-division mapping
     decision; (d) download and inspect `PRI_01.xlsx` first.
4. **Currency-regime grouping.**
   - The euroised vs own-currency grouping in the brief was not verified here.
   - Options for a source: IMF AREAER de facto classification; the central banks' own
     statements; other.
   - Related: whether MK's peg is grouped as "own currency".
5. **Comparison window.**
   - Common `RCH_A` span for all six geos: TOTAL and divisions from 2016-12 (AL is the
     binding start); main special aggregates also from 2016-12. The special aggregates
     carry `b` at 2017-01 and `d` before that.
   - Options: (a) 2021–2023 only; (b) from 2017-01 or 2018-01, after the flags; (c) the
     longest span per geo, unbalanced.
6. **Comparator.** `EA` (changing composition, as in hicp-gap) vs a fixed composition
   (`EA20`, `EA21`).
7. **Index reference and rate source.**
   - `I15` vs `I25`.
   - Published `RCH_A` (1 decimal) vs YoY derived from the index (2-decimal inputs).
   - Under `I15`, 6 months exceed the rounding bound; under `I25`, none.
   - Options for those 6 months: treat as rounding, or query Eurostat.
8. **Aggregation structure.**
   - Task 4 used a YoY-weighted sum of divisions. Its residual reaches 0.975 pp (RS, V1,
     full span) and 0.596 pp (ME, V3).
   - hicp-gap's DESIGN.md uses a December-link, within-weight-year structure instead.
   - Options: (a) reuse the DESIGN.md structure for peers; (b) a YoY-weighted-sum
     approximation with a stated residual tolerance; (c) something else.
   - Sub-choice for (b): weight year t (V1/V2) vs t−1 (V3).
   - The normalisation choice (÷1000 vs ÷Σw) changes residuals by at most 0.0003 pp.
9. **Breakdown level.** 13 divisions vs the main special aggregates (FOOD, NRG, IGD_NNRG,
   SERV). The aggregates are flagged before 2017-01, and their composition changed with
   ECOICOP ver. 2 (Q&A Q12).
10. **Stating peaks and ranks.**
    - AL's peak is tied across two months.
    - MK and RS tie in 2024-10.
    - Options: report published 1-decimal values with ties shown, or derived 2-decimal
      values. Section 5 shows both.
11. **Conformity caveat.**
    - Eurostat has not fully evaluated the enlargement countries' conformity.
    - The country metadata (2023–2025) predates ECOICOP ver. 2, and no peer back-series
      method is documented.
    - How and where to state this: limitations only, or next to every peer number as well.
12. **What to commit.** Nothing was committed. Candidates:
    - `verify/02_peers.R`
    - `verify/peers_*`
    - the two `*_WB_EA.rds` files (7.4 MB + 0.2 MB)
    - `data/raw/2026-09-29/`: TOC 2 MB, constraint XMLs, ESMS pages, Q&A PDF 0.8 MB,
      `eurostat_ei_cphi_m_BA.csv`
    - `HANDOFF.md`
    - The `ei_cphi_m` bulk file is already gitignored by the existing pattern.
