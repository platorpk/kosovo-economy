# hicp-gap: peers follow-up verification (2026-09-29)

**Status: verification only.** This report contains no decomposition, no figure, no finding
and no interpretation. It follows up `verify/peers_report.md` on four points Plator raised.
The choices it met are listed at the end, and none was made.

- Scripts, each run from the piece root:
  - `verify/03_fx.R` (exchange rates)
  - `verify/04_contributions.R` (exact contributions)
  - `verify/05_sa_weights.R` (special-aggregate weights)
- Every table below is copied verbatim from the script's generated file
  (`verify/{fx,contrib,sa_weights}_tables_generated.md`). The copy was made by R
  (`readLines`/`writeLines`), with the headings demoted one level. CSVs are in `verify/`.
- **HICP vintage:** Eurostat `LAST UPDATE` 17/09/26 11:00:00. This is the committed filtered
  record `data/raw/2026-09-23/*_WB_EA.rds`. There was no re-download.
- **FX vintage:** `ert_bil_eur_m` was downloaded on 2026-09-29, with bulk `LAST UPDATE`
  05/09/26 11:00:00. That matches the catalogue fetched on 2026-09-29. The raw file is
  `data/raw/2026-09-29/eurostat_ert_bil_eur_m_bulk.csv.gz`, gitignored by the existing
  pattern. The filtered record is `eurostat_ert_bil_eur_m_RSD_ALL_MKD.rds`.

## Housekeeping: folder move (open decision 1 of peers_report.md, resolved)

- The 8 files in `hicp-gap/verification/` were moved into `verify/`, and the empty folder
  was removed.
- `02_peers.R` now writes to `verify/`. Links in `peers_report.md` and `HANDOFF.md` were
  updated.
- `02_peers.R` was re-run after the move from the cached files. All 7 files it writes came
  out byte-identical to the moved copies (MD5 compared).

## Item 4 (dropped by Plator)

I15 XK 2023-09 exceeds bound by 0.001 pp; moot as I25 is adopted.

## Notes on method, stated where they apply

- **Item 1:**
  - The main series is the monthly average (`AVG`). End-of-month (`END`) is in
    `fx_monthly.csv` only.
  - "Peak month" is the month of the geo's highest published HICP TOTAL `RCH_A` in
    2021-01..2023-12. This is recomputed by `03_fx.R` from `prc_hicp_minr`. AL's peak is tied
    across two months, and both are shown.
  - The currency-to-geo map is RSD–RS, ALL–AL, MKD–MK.
  - The bulk file writes values with trailing zeros, so "decimals as written" overstates
    precision. "Significant decimals" excludes trailing zeros.
- **Item 2:**
  - The formula, both residuals and the bound are defined in the header of
    `04_contributions.R`.
  - The shares are w / Σw over the 13 divisions, as in DESIGN.md. The effect of using /1000
    instead is shown as one number.
  - The bound is a first-order worst-case propagation of half a unit of every published
    input's last significant decimal (index levels, item weights, and `RCH_A` for R_pub).
  - The self-test on synthetic exact data checks the implementation, not the data.
- **Item 2, weight precision:**
  - The script was run twice. Run 1 used one weight precision per geo: 2 decimals, so a
    half-unit of 0.005 everywhere. It passed the gate with 0 breaches. Its log is kept as
    `verify/contrib_run1_per_geo_weight_precision.log`.
  - Item 3 then showed that XK 2021–2022 and ME 2015–2018 item weights carry no nonzero
    second decimal. The script now takes the precision per geo-year, from all item weights
    of that geo-year, which sets a half-unit of 0.05 for those years.
  - This widens the bound in the months that use those weights and changes nothing else. The
    residuals are unchanged. The tables below are from run 2, and both runs pass.
- **Item 3:** the sum of the four aggregates is reported against 1000, not asserted.

## Generated tables: 03_fx.R

Eurostat `ert_bil_eur_m`, bulk LAST UPDATE 05/09/26 11:00:00; catalogue last update 05.09.2026 (TOC of 2026-09-29).
Units of national currency per 1 EUR (unit `NAC`), monthly average (statinfo `AVG`). END-of-month is in `fx_monthly.csv` only.

### 1a. Coverage from 2021-01

| currency | statinfo | first | last | n | expected | flags |
|---|---|---|---|---|---|---|
| ALL | AVG | 2021-01 | 2026-08 | 68 | 68 |  |
| ALL | END | 2021-01 | 2026-08 | 68 | 68 |  |
| MKD | AVG | 2021-01 | 2026-08 | 68 | 68 |  |
| MKD | END | 2021-01 | 2026-08 | 68 | 68 |  |
| RSD | AVG | 2021-01 | 2026-08 | 68 | 68 |  |
| RSD | END | 2021-01 | 2026-08 | 68 | 68 |  |

Decimals published:

| currency | statinfo | decimals_as_written | significant_decimals |
|---|---|---|---|
| ALL | AVG | 5 | 5 |
| ALL | END | 5 | 2 |
| MKD | AVG | 4 | 4 |
| MKD | END | 4 | 4 |
| RSD | AVG | 4 | 4 |
| RSD | END | 4 | 4 |

### 1b. Monthly levels, AVG, 2021-01..2026-08

| month | RSD | ALL | MKD |
|---|---|---|---|
| 2021-01 | 117.582 | 123.53 | 61.6948 |
| 2021-02 | 117.5764 | 123.61 | 61.6948 |
| 2021-03 | 117.5766 | 123.33571 | 61.6928 |
| 2021-04 | 117.5728 | 123.1 | 61.5994 |
| 2021-05 | 117.5789 | 123.01 | 61.5539 |
| 2021-06 | 117.5703 | 122.83 | 61.6837 |
| 2021-07 | 117.5629 | 122.32 | 61.566 |
| 2021-08 | 117.5675 | 121.55 | 61.4939 |
| 2021-09 | 117.5668 | 121.59 | 61.6089 |
| 2021-10 | 117.5674 | 121.71 | 61.6919 |
| 2021-11 | 117.5806 | 122.13 | 61.6945 |
| 2021-12 | 117.5801 | 120.81 | 61.6668 |
| 2022-01 | 117.5843 | 121.49 | 61.6909 |
| 2022-02 | 117.5907 | 121.32 | 61.6952 |
| 2022-03 | 117.6766 | 122.96 | 61.6951 |
| 2022-04 | 117.7275 | 121 | 61.6344 |
| 2022-05 | 117.5572 | 120.47 | 61.6743 |
| 2022-06 | 117.4297 | 119.8 | 61.6951 |
| 2022-07 | 117.3938 | 117.47 | 61.5511 |
| 2022-08 | 117.355 | 116.97 | 61.4947 |
| 2022-09 | 117.3246 | 116.99 | 61.4949 |
| 2022-10 | 117.3129 | 117.25 | 61.5299 |
| 2022-11 | 117.3086 | 117.12 | 61.6952 |
| 2022-12 | 117.3097 | 114.93 | 61.6271 |
| 2023-01 | 117.3635 | 116.39 | 61.6226 |
| 2023-02 | 117.3266 | 115.72 | 61.695 |
| 2023-03 | 117.3144 | 114.35 | 61.6908 |
| 2023-04 | 117.2824 | 112.38 | 61.6373 |
| 2023-05 | 117.2831 | 111.1 | 61.5045 |
| 2023-06 | 117.2731 | 107.26 | 61.5486 |
| 2023-07 | 117.2269 | 103.24 | 61.4964 |
| 2023-08 | 117.2139 | 105.67 | 61.4932 |
| 2023-09 | 117.2015 | 106.85 | 61.5288 |
| 2023-10 | 117.1852 | 105.77 | 61.5058 |
| 2023-11 | 117.1934 | 104.09 | 61.4957 |
| 2023-12 | 117.174 | 102.78 | 61.4937 |
| 2024-01 | 117.2102 | 103.91 | 61.6071 |
| 2024-02 | 117.1795 | 103.91 | 61.6949 |
| 2024-03 | 117.1912 | 103.57 | 61.5662 |
| 2024-04 | 117.1384 | 101.48 | 61.494 |
| 2024-05 | 117.1161 | 100.52 | 61.2781 |
| 2024-06 | 117.0715 | 100.35 | 61.5554 |
| 2024-07 | 117.0507 | 100.31 | 61.5043 |
| 2024-08 | 117.0366 | 99.97 | 61.492 |
| 2024-09 | 117.0461 | 99.35 | 61.4939 |
| 2024-10 | 117.0341 | 98.68 | 61.4944 |
| 2024-11 | 116.9936 | 98.21 | 61.4939 |
| 2024-12 | 116.973 | 98.3 | 61.4946 |
| 2025-01 | 117.1216 | 98.51 | 61.5492 |
| 2025-02 | 117.1386 | 99.03 | 61.5158 |
| 2025-03 | 117.1713 | 99.23 | 61.6606 |
| 2025-04 | 117.2029 | 98.71 | 61.5787 |
| 2025-05 | 117.2275 | 98.21 | 61.6594 |
| 2025-06 | 117.2074 | 98.07 | 61.6094 |
| 2025-07 | 117.1756 | 97.72 | 61.6661 |
| 2025-08 | 117.1725 | 97.29 | 61.5331 |
| 2025-09 | 117.1773 | 97.07 | 61.5645 |
| 2025-10 | 117.1952 | 96.74 | 61.634 |
| 2025-11 | 117.2495 | 96.66 | 61.5436 |
| 2025-12 | 117.3751 | 96.54 | 61.5407 |
| 2026-01 | 117.3644 | 96.56 | 61.5868 |
| 2026-02 | 117.3998 | 96.44 | 61.6831 |
| 2026-03 | 117.4164 | 96.04 | 61.6952 |
| 2026-04 | 117.3931 | 95.68 | 61.695 |
| 2026-05 | 117.3973 | 95.48 | 61.6951 |
| 2026-06 | 117.3892 | 94.79 | 61.6642 |
| 2026-07 | 117.3836 | 93.73 | 61.5761 |
| 2026-08 | 117.3635 | 92.78 | 61.4935 |

### 1c. % change, 2021-01 -> the geo's HICP peak month

Peak month = month(s) of the highest published HICP TOTAL `RCH_A` in 2021-01..2023-12 (`prc_hicp_minr`); ties listed as separate rows.
% change = 100 x (level at peak month / level 2021-01 - 1).

| currency | geo | peak_month | peak_RCH_A | level_2021_01 | level_peak | pct_change |
|---|---|---|---|---|---|---|
| RSD | RS | 2023-03 | 15.6 | 117.5820 | 117.3144 | -0.23 |
| ALL | AL | 2022-10 | 8.0 | 123.5300 | 117.2500 | -5.08 |
| ALL | AL | 2022-11 | 8.0 | 123.5300 | 117.1200 | -5.19 |
| MKD | MK | 2022-10 | 19.4 | 61.6948 | 61.5299 | -0.27 |

### 1d. % change, common windows

| window | currency | level_2021_01 | level_end | pct_change |
|---|---|---|---|---|
| 2021-01 -> 2023-12 | RSD | 117.5820 | 117.1740 | -0.35 |
| 2021-01 -> 2026-08 | RSD | 117.5820 | 117.3635 | -0.19 |
| 2021-01 -> 2023-12 | ALL | 123.5300 | 102.7800 | -16.80 |
| 2021-01 -> 2026-08 | ALL | 123.5300 | 92.7800 | -24.89 |
| 2021-01 -> 2023-12 | MKD | 61.6948 | 61.4937 | -0.33 |
| 2021-01 -> 2026-08 | MKD | 61.6948 | 61.4935 | -0.33 |

### 1e. Max and min, AVG, 2021-01..2026-08

`max_over_min_pct` = 100 x (max / min - 1), regardless of which month comes first.

| currency | max | max_month | min | min_month | max_over_min_pct |
|---|---|---|---|---|---|
| RSD | 117.7275 | 2022-04 | 116.9730 | 2024-12 | 0.65 |
| ALL | 123.6100 | 2021-02 | 92.7800 | 2026-08 | 33.23 |
| MKD | 61.6952 | 2022-02, 2022-11, 2026-03 | 61.2781 | 2024-05 | 0.68 |


## Generated tables: 04_contributions.R

Eurostat LAST UPDATE 17/09/26 11:00:00 (`prc_hicp_minr`, `prc_hicp_iw`, filtered record `*_WB_EA.rds`). Index: I25 (2025=100).

Self-test on synthetic exact December-linked data: max |R| = 9.77e-15 pp (must be < 1e-9).

### 2a. Months computed (all 13 divisions and TOTAL at the four dates, weights of t-1 and t)

| geo | first | last | n | contiguous | n_with_RCH_A |
|---|---|---|---|---|---|
| XK | 2017-01 | 2026-08 | 116 | TRUE | 116 |
| ME | 2016-01 | 2026-08 | 128 | TRUE | 128 |
| RS | 2007-01 | 2026-08 | 236 | TRUE | 236 |
| AL | 2017-01 | 2026-08 | 116 | TRUE | 116 |
| MK | 2006-01 | 2026-08 | 248 | TRUE | 248 |
| EA | 1998-01 | 2026-08 | 344 | TRUE | 344 |

Significant decimals used for the rounding half-units:

| geo | I25_decimals | weight_decimals | RCH_A_decimals |
|---|---|---|---|
| XK | 2 | 1,2 | 1 |
| ME | 2 | 1,2 | 1 |
| RS | 2 | 2 | 1 |
| AL | 2 | 2 | 1 |
| MK | 2 | 2 | 1 |
| EA | 2 | 2 | 1 |

Geo-years whose item weights (all codes) carry no nonzero second decimal; their half-unit is 0.05:

| geo | years |
|---|---|
| ME | 2015, 2016, 2017, 2018 |
| XK | 2021, 2022 |

### 2b. Residual distribution, whole span (pp)

| residual | geo | months | n | min | p10 | median | p90 | max | max_abs |
|---|---|---|---|---|---|---|---|---|---|
| R_der (vs I25 TOTAL YoY) | XK | 2017-01..2026-08 | 116 | -0.016 | -0.006 | 0.001 | 0.007 | 0.012 | 0.016 |
| R_der (vs I25 TOTAL YoY) | ME | 2016-01..2026-08 | 128 | -0.014 | -0.007 | -0.001 | 0.006 | 0.011 | 0.014 |
| R_der (vs I25 TOTAL YoY) | RS | 2007-01..2026-08 | 236 | -0.025 | -0.010 | 0.000 | 0.009 | 0.033 | 0.033 |
| R_der (vs I25 TOTAL YoY) | AL | 2017-01..2026-08 | 116 | -0.011 | -0.006 | 0.000 | 0.007 | 0.010 | 0.011 |
| R_der (vs I25 TOTAL YoY) | MK | 2006-01..2026-08 | 248 | -0.016 | -0.008 | -0.000 | 0.009 | 0.015 | 0.016 |
| R_der (vs I25 TOTAL YoY) | EA | 1998-01..2026-08 | 344 | -0.017 | -0.008 | 0.000 | 0.009 | 0.019 | 0.019 |
| R_pub (vs RCH_A) | XK | 2017-01..2026-08 | 116 | -0.055 | -0.039 | -0.002 | 0.034 | 0.050 | 0.055 |
| R_pub (vs RCH_A) | ME | 2016-01..2026-08 | 128 | -0.056 | -0.037 | 0.007 | 0.040 | 0.050 | 0.056 |
| R_pub (vs RCH_A) | RS | 2007-01..2026-08 | 236 | -0.060 | -0.038 | 0.004 | 0.038 | 0.067 | 0.067 |
| R_pub (vs RCH_A) | AL | 2017-01..2026-08 | 116 | -0.057 | -0.042 | -0.001 | 0.041 | 0.054 | 0.057 |
| R_pub (vs RCH_A) | MK | 2006-01..2026-08 | 248 | -0.061 | -0.044 | -0.004 | 0.035 | 0.058 | 0.061 |
| R_pub (vs RCH_A) | EA | 1998-01..2026-08 | 344 | -0.060 | -0.041 | 0.001 | 0.042 | 0.061 | 0.061 |

### 2c. Residual distribution, 2021-01..2023-12 (pp)

| residual | geo | months | n | min | p10 | median | p90 | max | max_abs |
|---|---|---|---|---|---|---|---|---|---|
| R_der (vs I25 TOTAL YoY) | XK | 2021-01..2023-12 | 36 | -0.009 | -0.007 | -0.002 | 0.006 | 0.008 | 0.009 |
| R_der (vs I25 TOTAL YoY) | ME | 2021-01..2023-12 | 36 | -0.011 | -0.006 | 0.001 | 0.007 | 0.011 | 0.011 |
| R_der (vs I25 TOTAL YoY) | RS | 2021-01..2023-12 | 36 | -0.011 | -0.005 | 0.000 | 0.005 | 0.010 | 0.011 |
| R_der (vs I25 TOTAL YoY) | AL | 2021-01..2023-12 | 36 | -0.011 | -0.006 | -0.000 | 0.007 | 0.010 | 0.011 |
| R_der (vs I25 TOTAL YoY) | MK | 2021-01..2023-12 | 36 | -0.012 | -0.010 | 0.000 | 0.005 | 0.013 | 0.013 |
| R_der (vs I25 TOTAL YoY) | EA | 2021-01..2023-12 | 36 | -0.009 | -0.006 | 0.002 | 0.007 | 0.010 | 0.010 |
| R_pub (vs RCH_A) | XK | 2021-01..2023-12 | 36 | -0.055 | -0.042 | -0.003 | 0.032 | 0.044 | 0.055 |
| R_pub (vs RCH_A) | ME | 2021-01..2023-12 | 36 | -0.051 | -0.031 | -0.002 | 0.037 | 0.048 | 0.051 |
| R_pub (vs RCH_A) | RS | 2021-01..2023-12 | 36 | -0.046 | -0.043 | 0.005 | 0.035 | 0.047 | 0.047 |
| R_pub (vs RCH_A) | AL | 2021-01..2023-12 | 36 | -0.047 | -0.031 | 0.003 | 0.041 | 0.050 | 0.050 |
| R_pub (vs RCH_A) | MK | 2021-01..2023-12 | 36 | -0.046 | -0.044 | -0.008 | 0.033 | 0.058 | 0.058 |
| R_pub (vs RCH_A) | EA | 2021-01..2023-12 | 36 | -0.056 | -0.045 | 0.004 | 0.044 | 0.054 | 0.056 |

### 2d. Computed rounding bound (pp) and |R| / bound, whole span. Flag = median bound > 0.05 pp.

| residual | geo | n | bound_min | bound_median | bound_p90 | bound_max | flag_median_bound_gt_0.05 | ratio_median | ratio_p90 | ratio_max | n_breach |
|---|---|---|---|---|---|---|---|---|---|---|---|
| R_der (vs I25 TOTAL YoY) | XK | 116 | 0.021 | 0.027 | 0.030 | 0.033 | FALSE | 0.17 | 0.33 | 0.59 | 0 |
| R_der (vs I25 TOTAL YoY) | ME | 128 | 0.021 | 0.028 | 0.032 | 0.033 | FALSE | 0.14 | 0.33 | 0.62 | 0 |
| R_der (vs I25 TOTAL YoY) | RS | 236 | 0.021 | 0.032 | 0.055 | 0.064 | FALSE | 0.14 | 0.34 | 0.59 | 0 |
| R_der (vs I25 TOTAL YoY) | AL | 116 | 0.021 | 0.025 | 0.027 | 0.029 | FALSE | 0.14 | 0.34 | 0.52 | 0 |
| R_der (vs I25 TOTAL YoY) | MK | 248 | 0.020 | 0.031 | 0.037 | 0.039 | FALSE | 0.16 | 0.35 | 0.53 | 0 |
| R_der (vs I25 TOTAL YoY) | EA | 344 | 0.020 | 0.028 | 0.036 | 0.037 | FALSE | 0.16 | 0.37 | 0.57 | 0 |
| R_pub (vs RCH_A) | XK | 116 | 0.061 | 0.064 | 0.067 | 0.072 | TRUE | 0.32 | 0.67 | 0.86 | 0 |
| R_pub (vs RCH_A) | ME | 128 | 0.061 | 0.065 | 0.068 | 0.069 | TRUE | 0.37 | 0.69 | 0.86 | 0 |
| R_pub (vs RCH_A) | RS | 236 | 0.061 | 0.067 | 0.081 | 0.086 | TRUE | 0.33 | 0.67 | 0.88 | 0 |
| R_pub (vs RCH_A) | AL | 116 | 0.060 | 0.063 | 0.064 | 0.066 | TRUE | 0.40 | 0.74 | 0.89 | 0 |
| R_pub (vs RCH_A) | MK | 248 | 0.060 | 0.066 | 0.070 | 0.071 | TRUE | 0.42 | 0.70 | 0.92 | 0 |
| R_pub (vs RCH_A) | EA | 344 | 0.060 | 0.064 | 0.069 | 0.069 | TRUE | 0.42 | 0.74 | 0.94 | 0 |

### 2e. Same, 2021-01..2023-12

| residual | geo | n | bound_min | bound_median | bound_p90 | bound_max | flag_median_bound_gt_0.05 | ratio_median | ratio_p90 | ratio_max | n_breach |
|---|---|---|---|---|---|---|---|---|---|---|---|
| R_der (vs I25 TOTAL YoY) | XK | 36 | 0.022 | 0.028 | 0.032 | 0.033 | FALSE | 0.14 | 0.29 | 0.37 | 0 |
| R_der (vs I25 TOTAL YoY) | ME | 36 | 0.023 | 0.028 | 0.029 | 0.029 | FALSE | 0.15 | 0.32 | 0.44 | 0 |
| R_der (vs I25 TOTAL YoY) | RS | 36 | 0.024 | 0.029 | 0.030 | 0.030 | FALSE | 0.13 | 0.25 | 0.37 | 0 |
| R_der (vs I25 TOTAL YoY) | AL | 36 | 0.022 | 0.025 | 0.025 | 0.025 | FALSE | 0.14 | 0.34 | 0.43 | 0 |
| R_der (vs I25 TOTAL YoY) | MK | 36 | 0.023 | 0.029 | 0.030 | 0.030 | FALSE | 0.14 | 0.40 | 0.45 | 0 |
| R_der (vs I25 TOTAL YoY) | EA | 36 | 0.022 | 0.025 | 0.026 | 0.026 | FALSE | 0.15 | 0.35 | 0.39 | 0 |
| R_pub (vs RCH_A) | XK | 36 | 0.061 | 0.066 | 0.070 | 0.072 | TRUE | 0.29 | 0.67 | 0.86 | 0 |
| R_pub (vs RCH_A) | ME | 36 | 0.062 | 0.065 | 0.067 | 0.067 | TRUE | 0.28 | 0.61 | 0.79 | 0 |
| R_pub (vs RCH_A) | RS | 36 | 0.062 | 0.066 | 0.067 | 0.067 | TRUE | 0.39 | 0.67 | 0.73 | 0 |
| R_pub (vs RCH_A) | AL | 36 | 0.061 | 0.063 | 0.064 | 0.064 | TRUE | 0.39 | 0.74 | 0.79 | 0 |
| R_pub (vs RCH_A) | MK | 36 | 0.062 | 0.066 | 0.067 | 0.068 | TRUE | 0.41 | 0.68 | 0.89 | 0 |
| R_pub (vs RCH_A) | EA | 36 | 0.061 | 0.064 | 0.064 | 0.064 | TRUE | 0.49 | 0.74 | 0.89 | 0 |

Largest absolute change in R_der from dividing by 1000 instead of sum(w): 0.0003 pp.

### 2f. Comparison with V1-V3 (`peers_aggregation_residuals.csv`), whole span (pp)

V1 = published RCH_A, weights of t; V2 = YoY derived from I15, weights of t; V3 = published RCH_A, weights of t-1.
Spans differ: the exact formula needs I(Dec, t-2) and the weights of t-1, so it starts later.

| geo | method | months | n | min | p10 | median | p90 | max | max_abs |
|---|---|---|---|---|---|---|---|---|---|
| XK | Ribe, vs I25 TOTAL YoY | 2017-01..2026-08 | 116 | -0.016 | -0.006 | 0.001 | 0.007 | 0.012 | 0.016 |
| XK | Ribe, vs RCH_A | 2017-01..2026-08 | 116 | -0.055 | -0.039 | -0.002 | 0.034 | 0.050 | 0.055 |
| XK | V1 | 2016-01..2026-08 | 128 | -0.144 | -0.063 | 0.008 | 0.084 | 0.264 | 0.264 |
| XK | V2 | 2016-01..2026-08 | 128 | -0.098 | -0.069 | 0.012 | 0.093 | 0.215 | 0.215 |
| XK | V3 | 2016-01..2026-08 | 128 | -0.210 | -0.069 | 0.019 | 0.173 | 0.534 | 0.534 |
| ME | Ribe, vs I25 TOTAL YoY | 2016-01..2026-08 | 128 | -0.014 | -0.007 | -0.001 | 0.006 | 0.011 | 0.014 |
| ME | Ribe, vs RCH_A | 2016-01..2026-08 | 128 | -0.056 | -0.037 | 0.007 | 0.040 | 0.050 | 0.056 |
| ME | V1 | 2015-12..2026-08 | 129 | -0.190 | -0.046 | 0.034 | 0.138 | 0.491 | 0.491 |
| ME | V2 | 2015-12..2026-08 | 129 | -0.214 | -0.032 | 0.020 | 0.150 | 0.445 | 0.445 |
| ME | V3 | 2016-01..2026-08 | 128 | -0.390 | -0.140 | -0.005 | 0.091 | 0.596 | 0.596 |
| RS | Ribe, vs I25 TOTAL YoY | 2007-01..2026-08 | 236 | -0.025 | -0.010 | 0.000 | 0.009 | 0.033 | 0.033 |
| RS | Ribe, vs RCH_A | 2007-01..2026-08 | 236 | -0.060 | -0.038 | 0.004 | 0.038 | 0.067 | 0.067 |
| RS | V1 | 2006-12..2026-08 | 237 | -0.084 | -0.030 | 0.031 | 0.237 | 0.975 | 0.975 |
| RS | V2 | 2006-12..2026-08 | 237 | -0.099 | -0.011 | 0.019 | 0.252 | 0.972 | 0.972 |
| RS | V3 | 2007-01..2026-08 | 236 | -0.264 | -0.064 | 0.019 | 0.128 | 0.494 | 0.494 |
| AL | Ribe, vs I25 TOTAL YoY | 2017-01..2026-08 | 116 | -0.011 | -0.006 | 0.000 | 0.007 | 0.010 | 0.011 |
| AL | Ribe, vs RCH_A | 2017-01..2026-08 | 116 | -0.057 | -0.042 | -0.001 | 0.041 | 0.054 | 0.057 |
| AL | V1 | 2016-12..2026-08 | 117 | -0.271 | -0.053 | 0.016 | 0.092 | 0.234 | 0.271 |
| AL | V2 | 2016-12..2026-08 | 117 | -0.274 | -0.032 | 0.007 | 0.084 | 0.235 | 0.274 |
| AL | V3 | 2017-01..2026-08 | 116 | -0.303 | -0.092 | 0.015 | 0.145 | 0.308 | 0.308 |
| MK | Ribe, vs I25 TOTAL YoY | 2006-01..2026-08 | 248 | -0.016 | -0.008 | -0.000 | 0.009 | 0.015 | 0.016 |
| MK | Ribe, vs RCH_A | 2006-01..2026-08 | 248 | -0.061 | -0.044 | -0.004 | 0.035 | 0.058 | 0.061 |
| MK | V1 | 2005-12..2026-08 | 249 | -0.387 | -0.091 | 0.014 | 0.125 | 0.347 | 0.387 |
| MK | V2 | 2005-12..2026-08 | 249 | -0.368 | -0.078 | 0.014 | 0.122 | 0.286 | 0.368 |
| MK | V3 | 2006-01..2026-08 | 248 | -0.138 | -0.088 | 0.004 | 0.098 | 0.265 | 0.265 |
| EA | Ribe, vs I25 TOTAL YoY | 1998-01..2026-08 | 344 | -0.017 | -0.008 | 0.000 | 0.009 | 0.019 | 0.019 |
| EA | Ribe, vs RCH_A | 1998-01..2026-08 | 344 | -0.060 | -0.041 | 0.001 | 0.042 | 0.061 | 0.061 |
| EA | V1 | 1997-01..2026-08 | 356 | -0.170 | -0.047 | 0.000 | 0.049 | 0.180 | 0.180 |
| EA | V2 | 1997-01..2026-08 | 356 | -0.199 | -0.021 | 0.002 | 0.027 | 0.187 | 0.199 |
| EA | V3 | 1997-01..2026-08 | 356 | -0.335 | -0.063 | -0.007 | 0.043 | 0.132 | 0.335 |

### 2g. Same, 2021-01..2023-12 (pp)

| geo | method | months | n | min | p10 | median | p90 | max | max_abs |
|---|---|---|---|---|---|---|---|---|---|
| XK | Ribe, vs I25 TOTAL YoY | 2021-01..2023-12 | 36 | -0.009 | -0.007 | -0.002 | 0.006 | 0.008 | 0.009 |
| XK | Ribe, vs RCH_A | 2021-01..2023-12 | 36 | -0.055 | -0.042 | -0.003 | 0.032 | 0.044 | 0.055 |
| XK | V1 | 2021-01..2023-12 | 36 | -0.136 | -0.072 | 0.017 | 0.132 | 0.264 | 0.264 |
| XK | V2 | 2021-01..2023-12 | 36 | -0.093 | -0.076 | 0.023 | 0.119 | 0.215 | 0.215 |
| XK | V3 | 2021-01..2023-12 | 36 | -0.092 | -0.039 | 0.083 | 0.207 | 0.534 | 0.534 |
| ME | Ribe, vs I25 TOTAL YoY | 2021-01..2023-12 | 36 | -0.011 | -0.006 | 0.001 | 0.007 | 0.011 | 0.011 |
| ME | Ribe, vs RCH_A | 2021-01..2023-12 | 36 | -0.051 | -0.031 | -0.002 | 0.037 | 0.048 | 0.051 |
| ME | V1 | 2021-01..2023-12 | 36 | -0.190 | -0.090 | 0.005 | 0.240 | 0.491 | 0.491 |
| ME | V2 | 2021-01..2023-12 | 36 | -0.214 | -0.070 | 0.002 | 0.252 | 0.445 | 0.445 |
| ME | V3 | 2021-01..2023-12 | 36 | -0.390 | -0.208 | -0.052 | 0.098 | 0.596 | 0.596 |
| RS | Ribe, vs I25 TOTAL YoY | 2021-01..2023-12 | 36 | -0.011 | -0.005 | 0.000 | 0.005 | 0.010 | 0.011 |
| RS | Ribe, vs RCH_A | 2021-01..2023-12 | 36 | -0.046 | -0.043 | 0.005 | 0.035 | 0.047 | 0.047 |
| RS | V1 | 2021-01..2023-12 | 36 | -0.044 | -0.026 | 0.030 | 0.120 | 0.216 | 0.216 |
| RS | V2 | 2021-01..2023-12 | 36 | -0.014 | -0.004 | 0.015 | 0.141 | 0.173 | 0.173 |
| RS | V3 | 2021-01..2023-12 | 36 | -0.130 | -0.028 | 0.065 | 0.148 | 0.172 | 0.172 |
| AL | Ribe, vs I25 TOTAL YoY | 2021-01..2023-12 | 36 | -0.011 | -0.006 | -0.000 | 0.007 | 0.010 | 0.011 |
| AL | Ribe, vs RCH_A | 2021-01..2023-12 | 36 | -0.047 | -0.031 | 0.003 | 0.041 | 0.050 | 0.050 |
| AL | V1 | 2021-01..2023-12 | 36 | -0.271 | -0.058 | 0.008 | 0.097 | 0.234 | 0.271 |
| AL | V2 | 2021-01..2023-12 | 36 | -0.274 | -0.058 | -0.002 | 0.058 | 0.235 | 0.274 |
| AL | V3 | 2021-01..2023-12 | 36 | -0.303 | -0.220 | 0.001 | 0.143 | 0.187 | 0.303 |
| MK | Ribe, vs I25 TOTAL YoY | 2021-01..2023-12 | 36 | -0.012 | -0.010 | 0.000 | 0.005 | 0.013 | 0.013 |
| MK | Ribe, vs RCH_A | 2021-01..2023-12 | 36 | -0.046 | -0.044 | -0.008 | 0.033 | 0.058 | 0.058 |
| MK | V1 | 2021-01..2023-12 | 36 | -0.387 | -0.295 | -0.000 | 0.077 | 0.126 | 0.387 |
| MK | V2 | 2021-01..2023-12 | 36 | -0.368 | -0.304 | 0.008 | 0.075 | 0.085 | 0.368 |
| MK | V3 | 2021-01..2023-12 | 36 | -0.129 | -0.029 | 0.038 | 0.117 | 0.148 | 0.148 |
| EA | Ribe, vs I25 TOTAL YoY | 2021-01..2023-12 | 36 | -0.009 | -0.006 | 0.002 | 0.007 | 0.010 | 0.010 |
| EA | Ribe, vs RCH_A | 2021-01..2023-12 | 36 | -0.056 | -0.045 | 0.004 | 0.044 | 0.054 | 0.056 |
| EA | V1 | 2021-01..2023-12 | 36 | -0.170 | -0.124 | 0.014 | 0.100 | 0.180 | 0.180 |
| EA | V2 | 2021-01..2023-12 | 36 | -0.199 | -0.149 | 0.009 | 0.097 | 0.187 | 0.199 |
| EA | V3 | 2021-01..2023-12 | 36 | -0.335 | -0.222 | -0.011 | 0.066 | 0.103 | 0.335 |

### 2h. Gate: |R| <= bound in every geo-month, both residuals, no tolerance. Breaches: 0.


## Generated tables: 05_sa_weights.R

Eurostat `prc_hicp_iw`, LAST UPDATE 17/09/26 11:00:00 (filtered record `eurostat_prc_hicp_iw_WB_EA.rds`).

### 3a. Codes (as published) and codelist labels

| coicop18 | label |
|---|---|
| FOOD | Food including alcohol and tobacco |
| IGD_NNRG | Non-energy industrial goods |
| NRG | Energy |
| SERV | Services (overall index excluding goods) |

### 3b. Status over 168 geo x year x code cells

| coicop18 | value |
|---|---|
| FOOD | 42 |
| IGD_NNRG | 42 |
| NRG | 42 |
| SERV | 42 |

### 3c. Item weights per mille, 2020-2026 (flag in brackets); sum of the four vs 1000 reported, not asserted

| geo | year | FOOD | NRG | IGD_NNRG | SERV | n_present | sum_4 | dev_from_1000 |
|---|---|---|---|---|---|---|---|---|
| XK | 2020 | 458.50 | 106.60 | 269.60 | 165.30 | 4 | 1000.00 | 0.00 |
| XK | 2021 | 462.90 | 107.80 | 275.80 | 153.50 | 4 | 1000.00 | 0.00 |
| XK | 2022 | 456.40 | 105.90 | 269.10 | 168.60 | 4 | 1000.00 | 0.00 |
| XK | 2023 | 446.28 | 147.44 | 264.90 | 141.38 | 4 | 1000.00 | 0.00 |
| XK | 2024 | 418.78 | 129.38 | 278.55 | 173.30 | 4 | 1000.01 | 0.01 |
| XK | 2025 | 383.30 | 129.35 | 294.60 | 192.74 | 4 | 999.99 | -0.01 |
| XK | 2026 | 385.23 | 122.20 | 293.25 | 199.32 | 4 | 1000.00 | 0.00 |
| ME | 2020 | 341.27 | 94.73 | 255.02 | 308.98 | 4 | 1000.00 | 0.00 |
| ME | 2021 | 340.71 | 84.40 | 266.14 | 308.75 | 4 | 1000.00 | 0.00 |
| ME | 2022 | 369.92 | 118.39 | 244.12 | 267.56 | 4 | 999.99 | -0.01 |
| ME | 2023 | 381.60 | 123.44 | 207.20 | 287.75 | 4 | 999.99 | -0.01 |
| ME | 2024 | 384.47 | 111.05 | 206.80 | 297.68 | 4 | 1000.00 | 0.00 |
| ME | 2025 | 370.33 | 106.74 | 212.82 | 310.10 | 4 | 999.99 | -0.01 |
| ME | 2026 | 366.50 | 107.29 | 213.31 | 312.89 | 4 | 999.99 | -0.01 |
| RS | 2020 | 379.40 | 149.38 | 228.63 | 242.59 | 4 | 1000.00 | 0.00 |
| RS | 2021 | 384.50 | 145.29 | 229.46 | 240.75 | 4 | 1000.00 | 0.00 |
| RS | 2022 | 376.54 | 145.81 | 227.73 | 249.92 | 4 | 1000.00 | 0.00 |
| RS | 2023 | 375.47 | 141.66 | 237.61 | 245.27 | 4 | 1000.01 | 0.01 |
| RS | 2024 | 375.57 | 144.08 | 234.41 | 245.94 | 4 | 1000.00 | 0.00 |
| RS | 2025 | 375.65 | 144.49 | 232.63 | 247.23 | 4 | 1000.00 | 0.00 |
| RS | 2026 | 375.62 | 144.10 | 234.06 | 246.22 | 4 | 1000.00 | 0.00 |
| AL | 2020 | 414.84 | 66.34 | 202.41 | 316.41 | 4 | 1000.00 | 0.00 |
| AL | 2021 | 415.82 | 60.44 | 195.88 | 327.85 | 4 | 999.99 | -0.01 |
| AL | 2022 | 407.37 | 61.45 | 194.36 | 336.82 | 4 | 1000.00 | 0.00 |
| AL | 2023 | 381.29 | 60.95 | 174.75 | 383.00 | 4 | 999.99 | -0.01 |
| AL | 2024 | 398.04 | 57.38 | 188.33 | 356.26 | 4 | 1000.01 | 0.01 |
| AL | 2025 | 397.85 | 50.25 | 179.14 | 372.75 | 4 | 999.99 | -0.01 |
| AL | 2026 | 396.48 | 54.47 | 179.59 | 369.46 | 4 | 1000.00 | 0.00 |
| MK | 2020 | 448.78 | 99.65 | 198.92 | 252.66 | 4 | 1000.01 | 0.01 |
| MK | 2021 | 479.31 | 100.08 | 191.20 | 229.41 | 4 | 1000.00 | 0.00 |
| MK | 2022 | 470.54 | 100.50 | 193.48 | 235.48 | 4 | 1000.00 | 0.00 |
| MK | 2023 | 472.66 | 102.35 | 192.84 | 232.14 | 4 | 999.99 | -0.01 |
| MK | 2024 | 475.71 | 105.34 | 187.60 | 231.35 | 4 | 1000.00 | 0.00 |
| MK | 2025 | 471.87 | 95.44 | 192.08 | 240.61 | 4 | 1000.00 | 0.00 |
| MK | 2026 | 468.21 | 98.00 | 192.37 | 241.43 | 4 | 1000.01 | 0.01 |
| EA | 2020 | 190.73 | 98.49 | 260.70 | 450.08 | 4 | 1000.00 | 0.00 |
| EA | 2021 | 217.61 | 94.97 | 267.71 | 419.71 | 4 | 1000.00 | 0.00 |
| EA | 2022 | 208.85 | 109.30 | 263.75 | 418.09 | 4 | 999.99 | -0.01 |
| EA | 2023 | 199.72 | 102.31 | 260.90 | 437.08 | 4 | 1000.01 | 0.01 |
| EA | 2024 | 194.66 | 99.12 | 255.47 | 450.75 | 4 | 1000.00 | 0.00 |
| EA | 2025 | 193.22 | 93.98 | 254.20 | 458.60 | 4 | 1000.00 | 0.00 |
| EA | 2026 | 189.35 | 90.26 | 252.16 | 468.23 | 4 | 1000.00 | 0.00 |


## Recorded without interpretation

- **Item 2:**
  - The gate passed. |R| ≤ its computed bound in every geo-month, for both residuals and
    all six geos (section 2h).
  - The flag "median bound > 0.05 pp" is TRUE for R_pub in every geo, over the whole span
    and in 2021–23. It is FALSE for R_der everywhere (sections 2d–2e).
  - R_pub's bound includes the 0.05 half-unit of `RCH_A`'s single published decimal.
- **Item 2, rates:** in every geo, the max_abs of both exact residuals is below the max_abs of
  each of V1–V3, over the whole span and in 2021–23 (sections 2f–2g). The spans differ, because the exact formula needs I(Dec, t−2) and the
  weights of t−1.
- **Item 3:**
  - FOOD, NRG, IGD_NNRG and SERV each have a value in all 42 geo-years of 2020–2026
    (6 × 7), with no flags.
  - The four sum to 1000 within ±0.01 in every geo-year (section 3c).
- **Item 3, precision:** XK 2021–2022 and ME 2015–2018 item weights carry no nonzero second
  decimal in any of the 553 codes.
- **Item 1:** ALL `AVG` shows 5 significant decimals in at least one month in the window.
  RSD and MKD show 4.

## Open decisions for Plator

Decisions 2–12 of `peers_report.md` are still open. Decision 1 is resolved (see above). New
decisions from this session:

13. **Structure for peers.** The exact December-link contribution formula closes within
    rounding for all six geos on I25. Adopt it as the aggregation structure for peers? That
    is decision 8(a) of `peers_report.md`, extended from the within-year identity to
    contributions to the annual rate.
14. **Residual used in any gate.** R_der (vs the I25-derived TOTAL YoY) has a median bound
    below 0.05 pp. R_pub (vs published `RCH_A`) is flagged, because its bound is dominated by
    `RCH_A`'s rounding. Options: gate on R_der only; on both (as here); or on R_pub with the
    computed bound.
15. **Weight precision in existing gates.** Should `build/01_gate.R` (XK vs EA, already
    passed) also take weight precision per geo-year? XK 2021–2022 weights carry 1 decimal.
    Widening a bound cannot turn that gate's pass into a fail.
16. **FX series and windows for any prose.** `AVG` vs `END`, and which of the windows in
    1c–1e would be quoted. AL's peak month is tied (2022-10, 2022-11), so the AL
    peak-window % change has two values.
17. **What to commit.** Candidates:
    - `verify/03_fx.R`, `04_contributions.R`, `05_sa_weights.R`
    - their CSVs and generated `.md`
    - this report
    - the run-1 log
    - `data/raw/2026-09-29/eurostat_ert_bil_eur_m_RSD_ALL_MKD.rds`
    - the moved `verify/peers_*` files
    The FX bulk file is gitignored.
