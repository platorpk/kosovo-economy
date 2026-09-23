# hicp-gap — verification handoff

**Status: verification phase only.** No inflation rates, differentials or
decomposition have been computed. Nothing here is a finding for the piece.

Planned piece: decompose the gap between Kosova's HICP inflation and the euro
area's into a composition term (weight differences × EA category inflation) and
a within-division term (Kosova weights × category inflation differences), at
ECOICOP ver.2 division level (CP01–CP13). This phase asks only whether the data
support that design. The decomposition has since been fixed in `DESIGN.md`
(midpoint form, with both ordered variants as bounds).

Script: `verify/01_coverage.R` (run from the piece root:
`Rscript verify/01_coverage.R`).

---

## Data vintage

- Downloaded **2026-09-23**.
- Eurostat `LAST UPDATE` on both tables: **17/09/26 11:00:00**.
- Tables, both pulled as the full bulk SDMX-CSV (gzip) with no filters from the
  SDMX 2.1 dissemination API, then filtered in R to `geo %in% c("XK","EA")`:
  - `prc_hicp_iw` — HICP item weights (annual)
  - `prc_hicp_minr` — HICP monthly data (index)

## Raw files and reproducibility

Under `data/raw/2026-09-23/`:

| file | size | tracked |
|---|---|---|
| `eurostat_prc_hicp_iw_bulk.csv.gz` | 2.7 MB | **gitignored** |
| `eurostat_prc_hicp_minr_bulk.csv.gz` | 107.0 MB | **gitignored** (over GitHub's 100 MB limit) |
| `eurostat_prc_hicp_iw_XK_EA.rds` | 0.05 MB | committed |
| `eurostat_prc_hicp_minr_XK_EA.rds` | 1.6 MB | committed |

The raw bulk files are gitignored (`hicp-gap/.gitignore`) and **must be
re-downloaded to reproduce** the pull: delete the date folder and rerun the
script. Eurostat revises, so a re-download may not return the same bytes; the
two filtered `.rds` files are the committed record of this vintage.

## Schema as published (bulk route)

- `prc_hicp_iw`: `DATAFLOW, LAST UPDATE, freq, coicop18, statinfo, geo,
  TIME_PERIOD, OBS_VALUE, OBS_FLAG, CONF_STATUS`. **No `unit` dimension**;
  `statinfo` carries a single value, `IW` (item weight).
- `prc_hicp_minr`: `DATAFLOW, LAST UPDATE, freq, unit, coicop18, geo,
  TIME_PERIOD, OBS_VALUE, OBS_FLAG, CONF_STATUS`.
- Both are harmonised at load: `TIME_PERIOD` → `time`, `OBS_VALUE` → `values`.
  (The `time` column seen in an earlier session came from a different access
  route; on the bulk route both tables publish `TIME_PERIOD`.)
- Euro-area geo codes present in both bulk tables: `EA`, `EA19`, `EA20`, `EA21`.
  This pull uses `EA` only.

---

## Guards (all pass on this vintage)

`prc_hicp_iw`:
- `statinfo == "IW"` on every row.
- Division (`^CP\d{2}$`) weight years: XK exactly 2015–2026, EA exactly
  1996–2026.
- Every geo-year carries exactly the 13 divisions CP01–CP13, no missing values.
- Division weights sum to 1000 in every geo-year within
  `13 * 0.005 + 1e-9`. Max observed deviation: **0.02** (43 geo-years). The miss
  is **publication rounding**: weights are published to 2 decimals, so 13
  rounded division weights can deviate from 1000 by at most 0.065. 17 geo-years
  deviate (EA 15, XK 2: 2023 = 999.98, 2026 = 999.99), all by ±0.01 or ±0.02.
  The first run used a 1e-6 tolerance and failed on this; the tolerance was set
  to the rounding bound on review. Eurostat's dataset description states: "for
  each country and year, the item weights add up to 1,000" (Data Browser,
  `prc_hicp_iw`, "Show description"; retrieved 2026-09-23:
  https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_iw/default/table).

`prc_hicp_minr`:
- Harmonised columns `freq, unit, coicop18, geo, time, values` present.
- Unit `I15` present.

---

## Results: `prc_hicp_minr`

### a) Units

`freq` = `M` only. Rows by unit × geo (all coicop18 levels):

| unit | EA | XK |
|---|---|---|
| I15 | 118076 | 50520 |
| I25 | 118076 | 50520 |
| RCH_A | 111578 | 45852 |
| RCH_M | 117533 | 50123 |
| RCH_MV12MAVR | 105133 | 41837 |

**A 2025=100 series (`I25`) exists alongside `I15`**, with identical row counts
per geo. All five units carry division-level series.

### b) Division-level coverage by geo × unit

| geo | unit | divisions | first month | last month |
|---|---|---|---|---|
| EA | I15 | 13 | 1996-01 | 2026-08 |
| XK | I15 | 13 | 2015-01 | 2026-08 |
| EA | I25 | 13 | 1996-01 | 2026-08 |
| XK | I25 | 13 | 2015-01 | 2026-08 |
| EA | RCH_A | 13 | 1997-01 | 2026-08 |
| XK | RCH_A | 13 | 2016-01 | 2026-08 |
| EA | RCH_M | 13 | 1996-02 | 2026-08 |
| XK | RCH_M | 13 | 2015-02 | 2026-08 |
| EA | RCH_MV12MAVR | 13 | 1997-12 | 2026-08 |
| XK | RCH_MV12MAVR | 13 | 2016-12 | 2026-08 |

All 13 divisions share the same span within every geo × unit (no division
starts late or ends early).

### c) Missing months

- 130 geo × unit × division series checked; **0 with internal gaps**.
- 0 division rows published with an empty value.
- Flags: all XK division rows unflagged. EA carries `u` (low reliability) on
  some division rows — 18 each in I15 and I25, 34 RCH_A, 26 RCH_M, 187
  RCH_MV12MAVR. In I15 they fall in 2020-04 to 2021-05:
  CP03, CP05, CP09 (2020-04, 2021-01, 2021-02) and CP11 (2020-04, 2020-05,
  2020-11 to 2021-05).

### d) XK back-series vs the weights window

- XK index series (`I15`, `I25`) start **2015-01 for all 13 divisions**, so the
  ECOICOP ver.2 back-series covers the whole weights window (2015–2026).
- Published rate units start later by construction (RCH_M 2015-02, RCH_A
  2016-01, RCH_MV12MAVR 2016-12).
- Latest month for both geos: 2026-08.

---

## Open questions for the design phase

Not answered here.

1. Normalise weights to shares (`w / sum(w)`) vs use as published.
2. EA (evolving composition, EA21 from 2026) vs a fixed-composition aggregate
   as the comparator. Composition source: Eurostat's label for geo code `EA` in
   the ESTAT `GEO` codelist, "Euro area (EA11-1999, EA12-2001, EA13-2007,
   EA15-2008, EA16-2009, EA17-2011, EA18-2014, EA19-2015, EA20-2023,
   EA21-2026)" (retrieved 2026-09-23). Note: `EA19`, `EA20` and `EA21` are all in
   the tables; `EA21` carries weights from 2000.
3. Comparison window(s) and base period.
4. Index reference: `I15` vs `I25` (both cover the same span per geo).
5. Derive category inflation from the index levels vs use Eurostat's published
   rate units (`RCH_A`, `RCH_M`), and how to check the two against each other.
6. Treatment of EA's `u`-flagged division observations (in I15/I25:
   2020-04 to 2021-05).
7. Weights are annual, prices monthly: how the annual weight maps onto the
   monthly or annual price change used in each term.
