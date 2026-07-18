# Shtëpi të ftohta — energy poverty in Kosova's public data

Reproducible R pipeline on the EU's headline energy-poverty indicator —
**households unable to keep their home adequately warm** — for Kosova and the
Western Balkans, from public data only.

**The finding:** **one in five households in Kosova — 21.6% in 2024, by ASK's
own SILC series — cannot keep their home adequately warm.** The EU-validated
anchor point is 2018, the one year Kosova's data was transmitted to Eurostat:
**40.2%**, against **7.6%** in the EU-27 that year, and **53.1%** among Kosovars
below the at-risk-of-poverty threshold. The regional spread at the latest
available years runs from about **9%** (Serbia, 2025) to **34%** (Shqipëria,
2023). The ASK path from 40.2 to 21.6 is volatile — see Limitations before
reading it as a trend.

## Data sources (all open)

- **ASK SILC** (Anketa mbi të Ardhurat dhe Kushtet e Jetesës), PxWeb table
  **`silc10.px`** — "Affordability of households to keep the house warm
  adequately". The table *title* says 2023; the year dimension runs **2018–2024**.
  Endpoint: `askdata.rks-gov.net/api/v1/en/ASKdata`.
- **Eurostat EU-SILC**, dataset **`ilc_mdes01`** (inability to keep home
  adequately warm), SDMX-CSV. Kosova (XK) exists **for 2018 only** — a single
  transmission. Comparators used: AL, RS, ME, MK, TR, EU27_2020.
  **Bosnia & Herzegovina publishes no series at all** (verified against the full
  dataset before filtering).
- **ASK CPI**, PxWeb table `cpi04.px`, COICOP **04.5 Electricity, gas and other
  fuels** (y-o-y, monthly to 2026M03) — context only: as of March 2026 the 04.5
  index was rising **14.3% year-on-year**. This piece makes no claims about
  tariff decisions.

Deliberately excluded: Eurostat `ilc_mdes07` and ASK `silc12.px`
(utility-arrears / payment-difficulty indicators).

## Method

1. `R/01_pull_ask.R` — pulls `silc10.px` (raw saved before parsing) and the CPI
   04.5 series; verifies 7 survey years and that Yes+No ≈ 100.
2. `R/02_pull_eurostat.R` — pulls `ilc_mdes01`. The SDMX key-path filter is
   attempted first; the dissemination API returns 400 for it and **silently
   ignores plain `?geo=` query parameters**, so the fallback downloads the full
   table and filters in R (geo set asserted). Pins the exact
   `hhcomp=TOTAL, unit=PC` rows for `rskpovth = TOTAL` and `B_60`
   (below the at-risk-of-poverty threshold).
3. `R/03_reconcile.R` — **reconciliation gate (run before quoting anything):**
   ASK silc10 2018 "No" = **40.2** and Eurostat XK 2018 TOTAL = **40.2** match
   **exactly** (diff 0.00 pp), confirming silc10 is the same EU-SILC indicator
   Kosova transmitted to Eurostat. Written to
   `data/processed/reconciliation_2018.csv`.
4. `R/04_figure.R` — the figure. Every quoted number is computed from the
   processed CSVs; nothing is hard-coded.

## Reproduce

R ≥ 4.5; packages: `pxweb, dplyr, tidyr, readr, ggplot2, ggrepel, showtext,
patchwork, magick`. Run in order:

```
Rscript R/01_pull_ask.R
Rscript R/02_pull_eurostat.R
Rscript R/03_reconcile.R
Rscript R/04_figure.R
```

## Outputs

- `output/energy_poverty_keep_warm.png` (2000px) and
  `output/energy_poverty_keep_warm_linkedin_1200.png` (downscaled raster, not
  re-rendered).
- `data/processed/silc10_keep_warm.csv`, `eurostat_keep_warm.csv`,
  `cpi_045_yoy.csv`, `reconciliation_2018.csv`.

## Limitations

- **What the indicator conflates:** self-reported inability to keep the home
  adequately warm mixes three things — household income, energy prices, and the
  dwelling's thermal quality (insulation, heating system) — and separating those
  channels requires household-level microdata linking incomes, expenditures and
  dwelling characteristics, which ASK does not publish.
- **No public distributional expenditure data.** ASK's PxWeb Household Budget
  Survey tables carry no income-decile or quintile breakdowns and no COICOP 04.5
  split (only the 04 "Housing" group), and the HBS series ends in **2022**. An
  expenditure-based energy-burden-by-income analysis is therefore not possible
  from published data.
- **Eurostat coverage of Kosova is a single 2018 transmission.** Later Kosova
  values come from ASK's published national SILC and are not Eurostat-validated;
  the comparator panel mixes each country's latest year (2023–2025).
- **The ASK series is volatile and the 2019 value is anomalous.** 2019 = 62.6%
  is inconsistent with adjacent years (40.2 in 2018, 23.0 in 2020) and identical
  on both ASK language endpoints; no published cross-check could be found. It is
  shown **as published** and flagged in the figure. Early waves of a new SILC
  are commonly unstable; the 2018–2024 path should be read as survey-year
  levels, not a precise trend.
- **Households vs persons.** ASK labels silc10 as a share of *households*;
  Eurostat defines `ilc_mdes01` over *persons*. The identical 2018 values
  (40.2) indicate a single underlying estimate; the figure quotes each source
  with its own label and treats them as the same indicator.
- **Bosnia & Herzegovina** publishes no series in `ilc_mdes01`, so the regional
  comparison itself has a measurement gap.

Source: ASK, Anketa mbi të Ardhurat dhe Kushtet e Jetesës (SILC) 2018–2024;
Eurostat EU-SILC (`ilc_mdes01`). Analysis: Plator Krasniqi.
