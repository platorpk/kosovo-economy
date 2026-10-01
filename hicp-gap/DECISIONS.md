# DECISIONS — hicp-gap peer extension

Authoritative for the peer build (Plator, 2026-09-29). Every entry is a design choice.

---

## A. Relationship to DESIGN.md

**A1. DESIGN.md stays authoritative and unamended in its core rules.** The peer extension applies the *same* design to each peer, pairwise against the euro area:
- December-to-December, by weight year
- midpoint split as the headline, with ordered variants A (EA rates) and B (peer rates) reported as bounds
- the pre-registered dominance rule, unchanged
- the second term is called **"within-division"**, never "price" (§3)
- no sub-period averages and no period statements such as "during the surge" (§2); single-weight-year statements are allowed

**A2. Add a short "Peers addendum" section to DESIGN.md before any peer decomposition is run.** It extends the geo list and applies A1 unchanged. It must be committed locally before Phase 2 produces any peer results, so the pre-registration stays genuine.

**A3. This supersedes Claude's earlier Phase 2 prompt.** That prompt asked for "composition vs price shares of a peak-window gap" over a monthly window, which conflicts with DESIGN.md §§2–3. There is no peak-window decomposition.

## B. Scope and data

**B1. Geos:** XK, ME, RS, AL, MK, each against the euro-area comparator. **BiH is dropped:** no Eurostat HICP observations; the national CPI uses 12 old-style divisions; one footnote.

**B2. EA comparator:** the same euro-area code the existing hicp-gap build uses. Unchanged.

**B3. Index:** 2025=100 (I25). It reproduces the published annual rates best, per the peers report.

**B4. Vintage:** Eurostat release of 17.09.2026, from the cached bulk of 2026-09-23. The build asserts the vintage and stops if the catalogue date changes. Re-check the vintage before publication; if it has changed, re-run the gates.

**B5. Window:**
- Decomposition: December-to-December for weight years 2016–2025, identical to DESIGN.md. Albania's annual rate from 2016-12 allows this for all geos.
- Descriptive context: published monthly annual rates (RCH_A), Jan 2021 → latest (2026-08). These are descriptive only and are never decomposed.

**B6. Level:** division level (13 ECOICOP v2 divisions) for all contributions and decompositions.

**B7. Special aggregates (FOOD, NRG, IGD_NNRG, SERV):** published annual rates only, used descriptively (for example, the Albania energy check in D2). **No contributions are computed from them**, so no aggregate-level gate is needed. If contributions are wanted later, a gate step per CLAUDE.md §9 is required first.

## C. Aggregation and gates

**C1. Aggregation structure (item 13):** December-to-December contributions = s_i^t × the division's December-to-December rate, with s = w / Σw over the 13 divisions. This is the exact special case of the verified December-link formula (the previous-year-weight term vanishes when m = December). The general formula is used only if any monthly contribution is ever shown; none is planned.

**C2. Gate residual (item 14):** applies **only to the monthly exact-contribution verification check** (`verify/04_contributions.R`). There, the check passes or fails on **R_der** (against the headline derived from the index) against its computed bound. **R_pub** (against the published rate) is reported for information only, because a one-decimal published rate makes its bound too loose to gate on. C2 does **not** change DESIGN.md §3: gate (b), the derived December-to-December rate against the published December `RCH_A` within its computed bound, stays pass/fail for every peer.

**C3. Weight precision (item 15):** `build/01_gate.R` reads weight precision per geo-year. Already settled.

## D. Grouping, ties and descriptive facts

**D1. Grouping:** by **observed** exchange-rate movement against the euro, as verified in `verify/03_fx.R`. Movement means the max/min range of the monthly-average rate (national currency per EUR) over 2021-01 → 2026-08, computed as 100 × (max / min − 1), not the change from start to end:
- "anchored": the currency stays within a band of less than 1% against the euro over 2021-01 → 2026-08. That covers XK and ME (they use the euro), RS (RSD range 0.65%) and MK (MKD range 0.68%).
- "moving": AL (ALL range 33.23%).
- Source of the ranges: `verify/fx_tables_generated.md` §1e, column `max_over_min_pct`. The build recomputes them and asserts the grouping.

**No de jure regime labels (peg, managed float, currency board) are used as claims in the piece**, which removes the need to source them. Stating that Kosova and Montenegro use the euro is fine.

**D2. Albania check:** report AL's published NRG and FOOD annual rates against the anchored four, monthly Jan 2021 → 2023-12, descriptively. **Don't attribute Albania's lower inflation to the exchange rate** without this comparison. The prose describes Albania as "the case where the exchange rate moved", not "the case it explains".

**D3. Ties (item 16):**
- Tables report both tied months.
- Prose uses "October–November 2022" for Albania's peak, and "about 5%" for the exchange-rate change to that peak (computed −5.08 % / −5.19 %).
- **No cross-peer ranking of any single month in prose** (for example, which peer had the highest rate in 2024-10). Tables that rank show ties as "=1" (for example, MK and RS at 4.6 in 2024-10).

**D4. Exchange-rate figures in prose:**
- main figure: change in ALL per EUR from 2021-01 to 2023-12 (−16.80 %), worded as "the euro bought 17% fewer lek"
- the latest month (2026-08) goes in the README only
- one convention throughout; no switching to "the lek appreciated X%"

## E. Caveats and outputs

**E1. Conformity caveat:** Eurostat has not fully evaluated the enlargement countries' conformity with HICP rules. The Kosova metadata page gives no weight source year for weight years 2022, 2024 and 2025, which lie inside the window. It also omits 2015 and 2026, which lie outside it. Both go in the chart caption (short) and the README limitations (full, with URLs).

**E2. Figures:** not specified yet. The hero-chart spec in the earlier plan (monthly contributions by component) conflicts with B6/B7 and DESIGN.md §2 and is withdrawn. A new spec will be added here before Phase 3.

**E3. Commit (items 12 and 17):** local commits only, in two separate commits:
1. The main XK–EA piece: `README.md`, `build/04_readme.R`, `data/processed/figures.json`, and the `.gitignore` diff.
2. The peer verification: the `verify/` scripts, reports, CSVs and generated tables; the run-1 log; the filtered `data/raw/2026-09-23/*_WB_EA.rds`; the small raw files in `data/raw/2026-09-29/`; HANDOFF.md; DECISIONS.md.

The DESIGN.md Peers addendum (A2) is committed locally before Phase 2 produces any peer result. Raw bulk data stays gitignored. **Nothing goes to remote**; publication comes later, via a worktree from `origin/main` and a scoped cherry-pick.

## F. Working headline (to be filled by Phase 2, not before)

> *Four economies whose currencies stayed within a 1% band against the euro saw inflation peak at 14–19% between July 2022 and March 2023; Albania, where the euro bought 17% fewer lek by end-2023, peaked at 8.0% in October–November 2022. In [weight year], the gap between [peer] and the euro area came mostly from [basket composition / within-division differences].*

The first sentence is descriptive (published monthly rates). The second comes only from the December-to-December decomposition, one weight year at a time, as §2 requires.
