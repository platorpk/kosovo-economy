# hicp-gap — design

Approved 2026-09-23. Builds on the verification in `HANDOFF.md` (data vintage:
Eurostat last update 17/09/26). This document fixes the analytical choices
before any rate or decomposition is computed.

Notation, per area a ∈ {XK, EA}, weight year t, division i ∈ CP01–CP13:

- s_a,i — year-t item weight of division i as a share of the 13 division
  weights (see Mechanical).
- r_a,i = I_a,i,Dec t / I_a,i,Dec t−1 − 1 — December-to-December division rate.
- π_a — published all-items December-to-December rate, derived from the
  all-items index.
- R_a = π_a − Σ_i s_a,i r_a,i — residual.
- gap_t = π_XK − π_EA.

---

## 1. Comparator

**Choice:** `EA`, the euro area with membership as it changed over time.

**Reason:** it is the euro area as it actually was in each year, which is what
a Kosova reader means by "euro-area inflation". Within one weight year, EA's
item weights and division indices cover the same countries, which is all a
within-year decomposition needs. Membership changes only at the January link.
The fixed-membership series project members backwards to years before they used
the euro (`EA21` carries weights from 2000).

**Rules out:** reading the gap as a comparison against a constant set of
countries; other comparators (EU27, Western Balkan neighbours), which would be a
different piece.

**Limitation text:** "From 2023 the EA comparator includes Croatia."

## 2. Window

**Choice:** weight years 2016–2025 (December 2015 to December 2025), each year
shown separately plus the ten-year average. No sub-period averages.

**Reason:**
- 2016 is the first weight year with a December base in the XK index (the
  series starts 2015-01, so weight year 2015 has no December 2014 base).
- 2025 is the last complete year.
- Year-by-year figures already show 2021–2023. Sub-period averages would need
  cut points chosen after seeing the data, and ten years leave groups of 2–5.

**Rules out:**
- The 2015 weights (unused).
- 2026 in any average: December 2025 to August 2026 is 8 months, and EA
  includes Bulgaria from January 2026. It appears only as a labelled
  year-to-date row in the table.
- Period statements such as "during the surge"; the text points to individual
  years.

**EA `u` flags (2020-04 to 2021-05):** the design uses December values only.
Of the flagged months, only EA CP11 December 2020 is a December; it enters
CP11's 2020 and 2021 rates, and so both terms in those years. It is used as
published, because it is the value inside Eurostat's own EA all-items index.
2020 and 2021 are marked in the table and named in the limitations.

## 3. Decomposition, chain-linking and gate

**Choice:** decompose within each weight year, December to December, then
average the yearly terms across the window.

**Midpoint form (headline):**

    composition_t = Σ_i (s_XK,i − s_EA,i) · (r_XK,i + r_EA,i) / 2
    within_t      = Σ_i (s_XK,i + s_EA,i) / 2 · (r_XK,i − r_EA,i)
    residual_t    = R_XK − R_EA

    gap_t = composition_t + within_t + residual_t

**Ordered variants (bounds):** both are computed and reported alongside the
midpoint.

| variant | composition | within-division |
|---|---|---|
| A: composition at EA rates | Σ (s_XK − s_EA) · r_EA | Σ s_XK · (r_XK − r_EA) |
| B: composition at XK rates | Σ (s_XK − s_EA) · r_XK | Σ s_EA · (r_XK − r_EA) |

Each variant adds up to the same gap with the same residual. The midpoint terms
are the average of A and B.

**Term naming:** the second term is the **within-division** term, never "price".
It mixes price differences for the same goods with differences in what each
area's basket holds inside a division; division-level data cannot separate the
two.

**Pre-registered dominance rule:** a term (composition or within-division)
dominates only if, under **both** ordered variants A and B:
- it has the same sign as the gap, **and**
- |term| exceeds |other term| by more than 0.05 pp (the gate threshold).

Otherwise:
- if the two terms have opposite signs, they are reported as **offsetting**;
- if |composition| and |within-division| differ by 0.05 pp or less, the result
  is reported as a **tie**;
- in any other case the piece reports the range across A and B and makes no
  dominance statement.

Year-level statements apply the rule to that year's terms. **Window statements
apply the rule to the window averages of variant A and of variant B
separately**, never to a count of years in which a term dominates.

**Aggregation over years:** the window figure is the arithmetic mean of the
yearly terms, in percentage points, so the parts still add up (mean gap = mean
composition + mean within + mean residual, for the midpoint and for each
variant). Compounded price-level gaps are not decomposed.

**Reason for December to December:** if year-t weights apply to price change
from the December link, then within a weight year the all-items index is
exactly the weighted sum of division indices relative to December, and the
decomposition is an identity. This is an assumption about Eurostat's
compilation, not a citation; gate check (a) tests it directly.

**Why not annual averages:** a year-average rate mixes months under last year's
weights with months under this year's, so no single weight vector reproduces
it; the residual would be structural, not rounding.

**Reference column:** Eurostat's published annual-average all-items rate per
area-year, shown beside the December-to-December gap and **labelled as not
decomposed**. Intended source: `prc_hicp_minr`, unit `RCH_MV12MAVR`, December
value (the 12-month moving-average rate, which in December covers the calendar
year). That equivalence is to be confirmed in the build script that produces
the table; it is not part of the gate.

**Residual:** its own column in every year and in the average, never folded
into composition or within-division.

**Gate (first build script; stop for review after it):**
- (a) Aggregation identity: for every month of every weight year 2016–2025 and
  both areas, all-items I_m / I_Dec t−1 against Σ_i s_i · I_i,m / I_i,Dec t−1.
  Tests the December-link assumption in all 12 months.
- (b) Published rate: derived December-to-December all-items rate against the
  published `RCH_A` for December, within its publication rounding.
- Threshold for (a): |R| ≤ 0.05 pp in every month of every area-year.
  Rounding alone should keep it near 0.03 pp; the script computes that bound
  from the actual index levels rather than hard-coding it.
- Threshold for (b): the computed rounding bound for that area-year (half a unit
  of `RCH_A`'s published decimals plus the rounding error of the derived
  all-items ratio, from the actual index levels).
  - **Amendment, made after the first gate run (2026-09-23 vintage).** (b)
    originally used the same 0.05 pp threshold as (a). `RCH_A` is published to
    1 decimal, so rounding alone can put it up to about 0.06 pp from the derived
    rate, and a fixed 0.05 pp could fail on rounding. The first run passed the
    original 0.05 pp threshold for every area-year (max 0.041 pp), so the
    outcome is unchanged.
- Any breach: stop and report. The piece fails the gate.

## Mechanical

- **Index base:** `I25`. December-to-December ratios are base-invariant up to
  rounding; the build asserts `I15` and `I25` give the same rates within
  rounding.
- **Rates:** derived from indices. Published `RCH_A` only for gate check (b);
  published `RCH_MV12MAVR` only for the reference column.
- **Weights:** normalised to shares over the 13 divisions. Removes the
  ≤ 0.065 per-mille rounding miss so shares sum to exactly 1; changes any share
  by at most 0.0065% of its value.

## Pre-registered extension: division contributions, 2025 and 2026 YTD

Added 2026-09-23, after the first decomposition run and **before** any
division-level contribution was computed.

- Scope: weight year 2025 and the 2026 year-to-date row only.
- Per division i: midpoint within-division contribution
  c_i = (s_XK,i + s_EA,i) / 2 · (r_XK,i − r_EA,i), in pp. The 13 contributions
  sum to the midpoint within-division term (asserted).
- Reported: the top three divisions by contribution, and their combined share
  of the midpoint within-division term (Σ top-three c_i / within_mid; can exceed
  100% if other divisions offset).
- "Top by contribution" means ranked by c_i in the direction of the
  within-division term's sign (largest c_i when the term is positive, most
  negative when it is negative).
- Nothing else from the division table is reported or saved.

## Limitations recorded at design

Carried into the README's limitations section, alongside the Croatia (§1) and
`u`-flag (§2) notes:

- "Pre-2026 figures are back-calculated under the 2026 classification (ECOICOP
  ver.2) and can differ from figures published at the time."
- 2026 year-to-date (added 2026-09-23, before any further output): the YTD row
  spans December to August, not a full seasonal cycle. Division-level YTD
  contributions can reflect differing seasonal patterns between the two areas
  (for example, sales calendars) and are **not reported in the piece**. The YTD
  aggregate appears only with this caveat attached.

---

## Peers addendum

Pre-registered 2026-09-29, before any peer decomposition is run. Decisions are in
`DECISIONS.md`; the verification is in `verify/peers_report.md` and
`verify/followup_report.md`.

Descriptive peer data (published monthly rates, peaks, exchange rates) were
inspected before this addendum. No peer decomposition term had been computed.

**§1 amended (scope).**
- §1 originally excluded Western Balkan neighbours from this piece. This addendum
  amends that: pairwise decompositions of each peer against EA are now in scope.
  Using a peer as the comparator remains excluded, and no term is computed
  between two peers.
- Cross-peer statements compare published values, or each peer's own decomposition
  against `EA`.
- The XK–EA pair is the existing piece. The peer build must reproduce its output exactly.
- BiH is not included. Eurostat holds no BA observations in any HICP table
  (`verify/peers_report.md` §6), so it gets one footnote.

**Applied unchanged.** Substitute p for XK throughout §§1–3 and Mechanical:
- comparator `EA`
- weight years 2016–2025, December to December, each year plus the ten-year arithmetic
  mean; 2026 YTD as a labelled row only
- midpoint headline, with variant A (composition at EA rates) and variant B (composition
  at peer rates) as bounds
- the dominance rule, with its 0.05 pp margin
- the second term named "within-division", never "price"
- the residual as its own column
- `I25`; rates derived from indices; shares over the 13 divisions

**Gate, per peer, before any peer term.**
- §3 (a) and (b), plus the `I15`/`I25` check, for every peer-year.
- (b) stays pass/fail. `DECISIONS.md` C2 governs only the monthly exact-contribution
  verification check.
- Weight rounding half-units are taken per geo-year. Item weights of XK 2021–2022 and
  ME 2015–2018 carry no nonzero second decimal, so their half-unit is 0.05.
- Any breach: stop and report.

**Reference column.**
- Published December `RCH_MV12MAVR`, labelled as not decomposed.
- AL has none for 2016 (published from 2017). That cell is left blank and marked
  "not published".

**Descriptive layer.** Never decomposed. §2's rule on period statements governs the
decomposition, not this layer.
- Published monthly TOTAL `RCH_A`, 2021-01 → 2026-08, and each geo's peak value and
  month(s), with ties shown.
- Published `RCH_A` for FOOD, NRG, IGD_NNRG and SERV, 2021-01 → 2023-12, for the
  Albania comparison (`DECISIONS.md` D2).
- ALL, RSD and MKD per EUR, monthly average, as in `verify/03_fx.R`.
- Prose may state each geo's published peak month(s), e.g. "between July 2022 and
  March 2023".
- Decomposition statements stay single weight year.
- No cross-peer ranking of any single month in prose. Ranked tables show ties as "=1".

**Grouping** (`DECISIONS.md` D1).
- "Anchored": the currency stays within a band of less than 1% against the euro over
  2021-01 → 2026-08. The band is the max/min range of the monthly-average rate.
  This covers XK, ME, RS and MK.
- "Moving": AL.
- The exact ranges are reported. No de jure regime labels are used.

**Pre-registered division-contribution extension** (2025 and 2026 YTD, above): XK only,
not extended to the peers.

**Limitations added:**
- `EA` includes Croatia from 2023 and Bulgaria from 2026.
- Eurostat has not fully evaluated the enlargement countries' conformity with HICP
  requirements.
- The peers' country metadata (2023–2025) predate ECOICOP ver.2 and document no
  back-series method.
- The XK metadata page gives no weight source year for weight years 2022, 2024 and 2025.
- The pre-2026 back-calculation limitation (above) applies to every peer.
- Item weights are effectively 1-decimal in XK 2021–2022 and ME 2016–2018 (inside the
  window).
