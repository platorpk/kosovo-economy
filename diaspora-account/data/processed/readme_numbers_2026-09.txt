================================================================================================
08_readme_numbers.R — vintage 2026-09 | FDI treatment excl_reinvested
Every number below appears in README.md. Nothing in README.md may be typed.
================================================================================================

[A] HEADLINE
  diaspora account 2019, IMF baseline (% of GDP)         38.62
  remittances only 2019 (% of GDP)                       12.07
  difference (pp of GDP)                                 26.55
  ratio (x)                                              3.20
  remittances_and_travel 2019 (% of GDP)                 29.30
  diaspora account 2008 (% of GDP)                       35.36
  diaspora account 2020 (% of GDP)                       29.87
  maximal attribution 2020 (% of GDP)                    29.82
  2020 crossing, maximal minus baseline (pp)             -0.051
  series MINIMUM in the plotted window                   29.38% in 2013

[B] COMPOSITION 2019, percent of GDP, ordered by size
  Travel receipts at 92%                                 17.23
  Workers' remittances                                   12.07
  FDI equity excl. reinvested                            3.92
  Compensation of employees, net                         3.64
  Errors and omissions at 50%                            1.75
  sum (equals the headline)                              38.62
  travel as a share of the 2019 account (%)              44.6
  travel as a share of remittances_and_travel 2019 (%)   58.8
    rounded, as cited in prose — travel / account (%)  45
    rounded, as cited in prose — travel / rem+travel (%) 59

[C] STATUS WEIGHTING — shares of the account, by year
  UNVERIFIABLE = travel + remittances | CALIBRATED = FDI | VALIDATED = compensation + E&O
    2008  UNVERIFIABLE  61.7  CALIBRATED  17.8  VALIDATED  20.5
    2009  UNVERIFIABLE  64.7  CALIBRATED  15.9  VALIDATED  19.3
    2010  UNVERIFIABLE  62.6  CALIBRATED  18.2  VALIDATED  19.1
    2011  UNVERIFIABLE  62.4  CALIBRATED  18.3  VALIDATED  19.3
    2012  UNVERIFIABLE  73.6  CALIBRATED  10.5  VALIDATED  15.9
    2013  UNVERIFIABLE  78.5  CALIBRATED   6.4  VALIDATED  15.1
    2014  UNVERIFIABLE  77.6  CALIBRATED   2.9  VALIDATED  19.5
    2015  UNVERIFIABLE  75.8  CALIBRATED   7.9  VALIDATED  16.3
    2016  UNVERIFIABLE  78.5  CALIBRATED   4.5  VALIDATED  17.0
    2017  UNVERIFIABLE  80.4  CALIBRATED   7.8  VALIDATED  11.8
    2018  UNVERIFIABLE  79.4  CALIBRATED   6.9  VALIDATED  13.7
    2019  UNVERIFIABLE  75.9  CALIBRATED  10.2  VALIDATED  14.0
    2020  UNVERIFIABLE  77.0  CALIBRATED  12.7  VALIDATED  10.3
  2019 rounded: 76 / 10 / 14

[D] TRAVEL SENSITIVITY, 2019, IMF baseline structure, % of GDP
    imf_baseline                                         38.62
    travel_070                                           34.50
    travel_050                                           30.75

[D2] FDI TREATMENTS, 2019, imf_baseline band, % of GDP
    excl_reinvested                                      38.62
    incl_reinvested                                      38.07
    directional                                          38.64
    excluded                                             34.70

[E] TRAVEL AS A SHARE OF EXPORTS OF GOODS AND SERVICES
    2010 (%)                                             37.5
    2011 (%)                                             46.8
    2012 (%)                                             54.1
    2013 (%)                                             55.5
    2019 (%)                                             63.9
    2020 (%)                                             42.7
  IMF PDF p24 [printed 20] scatter, KOS point from a 600dpi raster:
    x (2013) ~ 55, y (2019) ~ 64, reading tolerance +/- 2pp
  travel credits 2010 (EUR m)                            327.7
  travel credits 2011 (EUR m)                            531.6
  travel credits, change 2010->2011 (%)                  62.2
  lowest travel share after the step, to 2020            42.7% in 2020
  travel credits, change 2019->2020 (%)                  -52.5
  remittances, change 2019->2020 (%)                     15.1
  E&O contribution 2020 (% of GDP)                       -0.79

[F] COMPARISON AGAINST CR 21/41
  avg 2018-19    ours@ASK 37.541 | ours@IMF 37.263 | Box  37.1 | denominator +0.278 | series +0.163 | TOTAL +0.441
  2020           ours@ASK 29.870 | ours@IMF 29.671 | Box  29.1 | denominator +0.199 | series +0.571 | TOTAL +0.770

  Box 1 DIASPORA column, line by line, avg 2018-19 (% of IMF GDP):
    Exports of G&S             UNVERIFIABLE  box   17.0  ours  16.96  dev  -0.04
    Primary income             VALIDATED     box    3.5  ours   3.57  dev  +0.07
    Secondary income other     UNVERIFIABLE  box   11.9  ours  11.95  dev  +0.05
    Direct investment net      CALIBRATED    box   -3.2  ours  -3.20  dev  -0.00
    Net errors and omissions   VALIDATED     box    1.4  ours   1.59  dev  +0.19
    Overall balance            -             box   37.1  ours  37.26  dev  +0.16
  2020 DI deviation (the calibrated mapping fails there):
      Direct investment net, 2020 dev (pp)               -1.26

  the E&O revision, the one measured contribution:
    2018  Table 5 184  ours  193.02  difference  +9.02 EUR m
    2019  Table 5 215  ours  247.25  difference +32.25 EUR m
  half the E&O difference, avg 2018-19 (pp of GDP)       0.147
  The E&O LINE deviation is +0.19 pp; half the measured difference is the
  figure above. The remainder is Box 1's one-decimal rounding.

[F2] PARENT VALIDATION — Box 1 TOTAL column vs CBK's own totals
  tolerance used to call a line validated (pp)           0.15
  avg 2018-19: 9 of 12 lines validate within 0.15 pp
    Current account                box   -6.5  ours  -6.59  dev  -0.09  validates
    Exports of Goods and Services  box   29.0  ours  28.97  dev  -0.03  validates
    Imports of Goods and Services  box   56.4  ours  56.43  dev  +0.03  validates
    Primary Income                 box    1.9  ours   1.97  dev  +0.07  validates
    Secondary Income               box   19.0  ours  18.90  dev  -0.10  validates
    Capital account                box   -0.1  ours  -0.14  dev  -0.04  validates
    Financial account              box   -3.8  ours  -3.56  dev  +0.24  does NOT
    Direct investment, net         box   -3.1  ours  -3.00  dev  +0.10  validates
    Portfolio investment, net      box   -1.1  ours  -1.07  dev  +0.03  validates
    Other investment, net          box   -1.0  ours  -0.80  dev  +0.20  does NOT
    Reserve assets                 box    1.3  ours   1.32  dev  +0.02  validates
    Net errors and omissions       box    2.9  ours   3.18  dev  +0.28  does NOT
  2020: 2 of 12 lines validate within 0.15 pp
    Current account                box   -7.5  ours  -6.93  dev  +0.57  does NOT
    Exports of Goods and Services  box   22.0  ours  21.56  dev  -0.44  does NOT
    Imports of Goods and Services  box   53.7  ours  53.57  dev  -0.13  validates
    Primary Income                 box    2.3  ours   2.41  dev  +0.11  validates
    Secondary Income               box   21.9  ours  22.67  dev  +0.77  does NOT
    Capital account                box   -0.1  ours   0.26  dev  +0.36  does NOT
    Financial account              box   -7.8  ours  -8.25  dev  -0.45  does NOT
    Direct investment, net         box   -3.0  ours  -4.20  dev  -1.20  does NOT
    Portfolio investment, net      box   -0.5  ours  -1.20  dev  -0.70  does NOT
    Other investment, net          box   -3.1  ours  -3.52  dev  -0.42  does NOT
    Reserve assets                 box   -1.2  ours   0.68  dev  +1.88  does NOT
    Net errors and omissions       box   -0.2  ours  -1.57  dev  -1.37  does NOT

  Table 5 current account, EUR million (the 2020 revision):
    2018  Table 5   -509  ours   -508.8  dev    +0.2
    2019  Table 5   -392  ours   -399.5  dev    -7.5
    2020  Table 5   -509  ours   -472.2  dev   +36.8

[F3] THE TWO MAPPING CHANGES
  compensation of employees — MEASURED against Table 5:
    2018  Table 5 237  CBK net  237.04  dev +0.04
    2019  Table 5 257  CBK net  257.13  dev +0.13
  FDI equity — CALIBRATED to Box 1, not measured (see section H).

[G] RESIDENTS' SIDE — against Box 1's Residents CURRENT ACCOUNT
  ours, avg 2018-19 (% of IMF GDP)                       -39.067
  Box 1 Residents current account, avg 2018-19: -39.0
  deviation (pp)                                         -0.067
  ours, 2020 (% of IMF GDP)                              -33.629
  Box 1 Residents current account, 2020: -34.1
  deviation (pp)                                         0.471

[H] FDI — THE CONTRADICTION
  Box 1 avg 2018-19: Total -3.1 = Residents +0.1 + Diaspora -3.2
  Table 5 net DI over IMF GDP (%)                        -3.095
  Table 5 DI liabilities over IMF GDP (%)                3.894
  ours, equity excl. reinvested (%)                      3.203
  ours, equity incl. reinvested (%)                      3.634
  years both FDI series carry data                       14
  of those, years they disagree (>0.01)                  14
  largest disagreement (EUR m)                           145.7
  largest disagreement occurs in                         2018

[I] BENCHMARK RESOLUTION FLOOR
  avg 2018-19 IMF GDP (EUR m)                            6915
    ... comma-formatted, as it appears in prose          6,915
  ASK gdp13 vs gdp09, max |difference| (EUR m)           0.000
  years compared                                         17
  Box 1 resolution, +/- half a printed decimal (pp)      0.05
    ... in EUR million                                   3.5
  travel line deviation (pp)                             -0.04
  implied bound on a travel revision (EUR m)             7.1

[J] RECONCILIATION AND SOURCE DEFECTS
  first complete quarterly year                          2009
  component-years reconciled 2009-2012                   22
  of those deviating beyond 1e-9                         2
  travel only, max |deviation| 2009-2012                 1.14e-13
  every non-zero quarterly deviation in the series:
    errors_omissions         2009  +0.3921 EUR m
    errors_omissions         2010  -0.4233 EUR m
    compensation_employees   2021  -5.1669 EUR m
  services balance, 26 vs 27:
    2025  2370.0795 vs 2368.0795  difference +2.000 EUR m

[K] WHAT THE TRUNCATION WITHHOLDS
    2021 (% of GDP, PROVISIONAL)                         42.0
    2022 (% of GDP, PROVISIONAL)                         43.5
    2023 (% of GDP, PROVISIONAL)                         45.1
    2024 (% of GDP, PROVISIONAL)                         46.3
  years plotted                                          13

[L] ASK vs CBK EXPORTS OF GOODS AND SERVICES — not independent
  years compared                                         17
  years identical to 0.05 EUR m                          14
  max |difference| (EUR m)                               77.37
  largest difference occurs in                           2022
  difference in 2019, the benchmark year (EUR m)         -0.00
  ASK's national accounts take services trade from CBK's balance of payments,
  so these are not independently sourced.

[M] AS THEY APPEAR IN PROSE (rounded display forms)
  -0.067  -39.067  0.147  0.39  0.42  10.2  12.1  14.0  145.7  2.000  26.5  29.3  29.4  29.8  29.9  3.2  3.46  30.8  34.5  34.7  35.4  38.6  42.0  43.5  45.1  46.3  5.17  55.5  63.9  7.07  75.9  77.4

[N] REFERENCE VALUES — cited, not computed
  IMF Country Report No. 21/41, February 2021, 89 pp.
    PDF p4                 GDP: 2018 6,726 | 2019 7,104 | 2020 6,817
    PDF p24 [printed 20]   Box 1, embedded table, all three columns;
                           footnote 1/ TO THAT TABLE carries the shares
    PDF p37 [printed 33]   Table 5
    PDF p52 [printed 48]   fn2, CBK Sep 2019 revision covers 2017:Q1-2019:Q2
    PDF p84                CBK reports BPM6 from 2013:Q1
  CBK methodology p27: travel credits include modelled components
  R required >= 4.5.0 (enforced in 01_functions.R); running 4.5.3
