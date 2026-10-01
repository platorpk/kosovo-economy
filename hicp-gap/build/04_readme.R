# ==============================================================================
# 04_readme.R
# Generates README.md and the LinkedIn post text from computed values.
#
# House rule (CLAUDE.md §2): every number in prose is computed by a script,
# never typed by hand. Values are collected into data/processed/figures.json
# and all prose is built from them with sprintf().
#
# Reads:  output/hicp_gap_decomposition.csv, output/hicp_gap_within_top3.csv
#         data/raw/<date>/eurostat_prc_hicp_minr_XK_EA.rds, ..._iw_XK_EA.rds
# Writes: data/processed/figures.json
#         README.md
#         output/linkedin_post.txt   (gitignored; not part of the public piece)
#
# Run from the piece root:  Rscript build/04_readme.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(stringr); library(jsonlite)
}))

options(warn = 2)                     # a sprintf argument mismatch must error, not warn
PROJ    <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
YEARS   <- 2016:2025
GATE_PP <- 0.05                       # gate threshold and dominance margin (DESIGN.md)
REPO    <- "github.com/platorpk/kosovo-economy"
PIECE_URL <- sprintf("https://%s/tree/main/hicp-gap", REPO)

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
mn  <- function(s) gsub("-", "\u2212", s, fixed = TRUE)     # typographic minus
s1  <- function(x) ifelse(round(x, 1) == 0, "0.0", mn(sprintf("%+.1f", x)))   # signed, 1 dp
s2  <- function(x) ifelse(round(x, 2) == 0, "0.00", mn(sprintf("%+.2f", x)))
u3  <- function(x) mn(sprintf("%.3f", x))
sq  <- function(x) str_squish(x)                            # join continuation lines cleanly
it  <- function(x) sprintf("*%s*", x)                       # labels verbatim, set off in italics
u1  <- function(x) mn(sprintf("%.1f", x))
u2  <- function(x) mn(sprintf("%.2f", x))
pct <- function(x) sprintf("%.0f%%", 100 * x)
year_runs <- function(y) {
  y <- sort(y); runs <- split(y, cumsum(c(1, diff(y) != 1)))
  s <- vapply(runs, function(r) if (length(r) == 1) as.character(r)
              else sprintf("%d\u2013%d", min(r), max(r)), "")
  if (length(s) == 1) s else paste(paste(s[-length(s)], collapse = ", "), "and", s[length(s)])
}

# ------------------------------------------------------------------------------
# Inputs
# ------------------------------------------------------------------------------
dec <- read_csv(file.path(PROJ, "output/hicp_gap_decomposition.csv"),
                col_types = cols(period = "c", type = "c", verdict = "c", seasonality_caveat = "c",
                                 ea_u_flag = "l", offset_by_other = "l", .default = col_double()))
top <- read_csv(file.path(PROJ, "output/hicp_gap_within_top3.csv"),
                col_types = cols(period = "c", division = "c", division_label = "c",
                                 seasonality_caveat = "c", rank = "i", .default = col_double()))
dated <- sort(list.dirs(file.path(PROJ, "data/raw"), recursive = FALSE), decreasing = TRUE)
dated <- dated[file.exists(file.path(dated, "eurostat_prc_hicp_minr_XK_EA.rds"))]
minr <- readRDS(file.path(dated[1], "eurostat_prc_hicp_minr_XK_EA.rds"))
iw   <- readRDS(file.path(dated[1], "eurostat_prc_hicp_iw_XK_EA.rds"))

yr  <- dec |> filter(type == "year") |> mutate(year = as.integer(period))
win <- dec |> filter(type == "window_mean")
ytd <- dec |> filter(type == "ytd_excluded_from_averages")
stopifnot(identical(sort(yr$year), YEARS), nrow(win) == 1, nrow(ytd) == 1)
EMPH <- max(YEARS)
e    <- yr |> filter(year == EMPH)
t25  <- top |> filter(period == as.character(EMPH)) |> arrange(rank)
stopifnot(nrow(t25) == 3, e$verdict == "within-division")

# ------------------------------------------------------------------------------
# Computed values -> figures.json
# ------------------------------------------------------------------------------
divs <- iw |> filter(grepl("^CP\\d{2}$", coicop18))
w_sum <- divs |> group_by(geo, time) |> summarise(s = sum(values), .groups = "drop")
w_dec <- max(nchar(sub("^[^.]*\\.?", "", format(divs$values, scientific = FALSE, drop0trailing = TRUE))))
# Precision per geo-year, from all item weights of that geo-year (DECISIONS.md C3)
sig_dec <- function(v) {
  v <- v[!is.na(v)]
  for (k in 0:6) if (all(abs(round(v, k) - v) < 1e-9)) return(k)
  stop("more than 6 decimals")
}
w_dec_gy <- iw |> group_by(geo, year = as.integer(time)) |>
  summarise(dec = sig_dec(values), .groups = "drop")
w_low <- w_dec_gy |> filter(dec < w_dec)
stopifnot(max(w_dec_gy$dec) == w_dec, n_distinct(w_low$dec) == 1,
          all(w_low$geo == "XK"), identical(w_low$year, 2021:2022))   # verify/followup_report.md
idx_div <- minr |> filter(unit == "I25", grepl("^CP\\d{2}$", coicop18))
uf <- idx_div |> filter(geo == "EA", OBS_FLAG %in% "u")
uf_dec <- uf |> filter(substr(time, 6, 7) == "12") |> distinct(coicop18, time)
stopifnot(nrow(uf_dec) >= 1)

F <- list(
  vintage          = sub(" .*$", "", unique(minr[["LAST UPDATE"]])),
  downloaded       = basename(dated[1]),
  n_div            = n_distinct(divs$coicop18),
  years            = range(YEARS),
  xk_weight_years  = range(as.integer(divs$time[divs$geo == "XK"])),
  ea_weight_years  = range(as.integer(divs$time[divs$geo == "EA"])),
  xk_index_first   = min(idx_div$time[idx_div$geo == "XK"]),
  ea_index_first   = min(idx_div$time[idx_div$geo == "EA"]),
  index_last       = max(idx_div$time),
  w_sum_max_dev    = max(abs(w_sum$s - 1000)),
  w_decimals       = w_dec,
  w_round_bound    = 13 * 0.5 * 10^-w_dec,
  w_low_years_xk   = w_low$year,
  w_low_decimals   = unique(w_low$dec),
  w_low_round_bound = 13 * 0.5 * 10^-unique(w_low$dec),
  gate_pp          = GATE_PP,
  max_abs_resid    = max(abs(yr$resid_pp)),
  u_first          = min(uf$time), u_last = max(uf$time),
  u_dec            = paste(sprintf("%s %s", uf_dec$coicop18, uf_dec$time), collapse = ", "),
  u_years          = yr$year[yr$ea_u_flag %in% TRUE],
  e = as.list(e |> select(-seasonality_caveat)),
  win = as.list(win |> select(-seasonality_caveat, -ea_u_flag, -offset_by_other)),
  ytd = as.list(ytd |> select(-seasonality_caveat)),
  top3_2025 = t25 |> select(rank, division, division_label, contribution_pp),
  top3_share_2025  = unique(t25$top3_combined_share),
  verdict_years    = split(yr$year, yr$verdict),
  sign_mismatch    = yr$year[sign(yr$gap_pp) * sign(yr$ref_aa_gap_pp_not_decomposed) < 0],
  ref_zero_years   = yr$year[yr$ref_aa_gap_pp_not_decomposed == 0],
  r_version        = R.version.string)
stopifnot(length(F$top3_share_2025) == 1, F$w_sum_max_dev <= F$w_round_bound + 1e-9)
dir.create(file.path(PROJ, "data/processed"), showWarnings = FALSE, recursive = TRUE)
write_json(F, file.path(PROJ, "data/processed/figures.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)

within_yrs <- F$verdict_years[["within-division"]]
range_yrs  <- F$verdict_years[["range"]]
stopifnot(setequal(c(within_yrs, range_yrs), YEARS))        # no other verdict occurs

# ------------------------------------------------------------------------------
# README
# ------------------------------------------------------------------------------
L <- c(); add <- function(...) L <<- c(L, ...)

add(
"# Hendeku i inflacionit me zonën e euros — Kosova's inflation gap with the euro area",
"",
sprintf(paste("Reproducible R analysis that splits the gap between Kosova's and the euro area's",
"consumer-price inflation (HICP, December to December) into a **composition** part and a",
"**within-division** part, across the %d ECOICOP ver.2 divisions, for weight years %d–%d."),
  F$n_div, F$years[1], F$years[2]),
"",
sprintf(paste("**The finding: in %d, Kosova's consumer prices rose %s%% from December to December",
"against %s%% in the euro area, a gap of %s pp, and the within-division term (%s pp) is larger",
"than the whole gap, with composition slightly negative (%s pp).** That holds under both",
"orderings of the decomposition (see the dominance rule below). Over %d–%d as a whole the gap",
"averaged %s pp a year, but which part is larger depends on the ordering, so no dominance",
"statement is made for the window."),
  EMPH, u1(e$pi_XK_pp), u1(e$pi_EA_pp), s1(e$gap_pp), s1(e$within_mid_pp), s1(e$comp_mid_pp),
  F$years[1], F$years[2], s1(F$win$gap_pp)),
"",
paste("*Composition* is the part of the gap that comes from the two areas spending different shares",
"on each division. *Within-division* is the part that comes from different inflation inside the",
"same division. It mixes price differences for the same goods with differences in what each",
"area's basket holds inside a division; division-level data cannot separate the two. Both are",
"accounting splits of the gap, not explanations of it: why prices within these divisions rose",
"faster in Kosova is not identified here."),
"",
"![Kosova's HICP inflation gap with the euro area, by component](output/hicp_gap_decomposition.png)",
"")

add(
"## Data sources (all open)",
"",
"All from Eurostat's database, *Economy and finance > Prices > Harmonised index of consumer",
"prices (HICP) > Harmonised index of consumer prices (HICP) - ECOICOP ver.2*:",
"",
"- **`prc_hicp_minr`** — HICP - ECOICOP ver.2 - indices and rates of change, monthly data.",
"  Units used: `I25` (Index, 2025=100) for every calculation; `I15` (Index, 2015=100) only for",
"  a cross-check; `RCH_A` (Annual rate of change) only for the gate; `RCH_MV12MAVR` (Moving",
"  12 months average rate of change) only for the reference column. All-items is `TOTAL`.",
"- **`prc_hicp_iw`** — HICP - ECOICOP ver.2 - item weights, per mille. Eurostat's dataset",
"  description states that each country's item weights add up to 1,000 in every year",
"  ([Data Browser](https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_iw/default/table),",
"  retrieved 2026-09-23).",
"- **COICOP 2018 codelist** (`ESTAT/COICOP18`, the version referenced by the `prc_hicp_minr`",
"  data structure definition) — division labels, used verbatim.",
"",
sprintf(paste("Geographies: `XK` (Kosova; the source labels it `Kosovo*`) and `EA`, the euro area",
"with its membership as it changed over time. Vintage: downloaded %s; Eurostat last update %s."),
  F$downloaded, F$vintage),
"",
"Deliberately not used:",
"",
"- **Fixed-composition euro-area aggregates** (`EA19`, `EA20`, `EA21`). They project members",
"  backwards to years before they used the euro; the piece compares against the euro area as",
"  it actually was in each year.",
sprintf("- **Kosova's %d weights.** The Kosova index starts in %s, so there is no December %d base to link from.",
  F$xk_weight_years[1], F$xk_index_first, F$xk_weight_years[1] - 1),
"- **Eurostat's published rates as inputs.** Rates are derived from the index levels; the",
"  published rates serve only as checks.",
"")

add(
"## Method",
"",
sprintf(paste("1. **`verify/01_coverage.R`** — pulls both tables in bulk with no filters (Eurostat's",
"JSON API errors on `prc_hicp_minr`), filters to `XK` and `EA`, and saves the result as `.rds`.",
"Guards: Kosova weights exist for %d–%d and euro-area weights for %d–%d, with all %d divisions",
"in every year, and the division weights sum to 1,000 within publication rounding (weights",
"are published to %d decimals, but Kosova's %s item weights carry no nonzero second decimal,",
"so they are effectively %d-decimal; %d rounded weights can therefore miss 1,000 by up to %s,",
"or %s in those years; the largest miss is %s).",
"Division indices run from %s for Kosova and %s for the euro area to %s, with no missing months."),
  F$xk_weight_years[1], F$xk_weight_years[2], F$ea_weight_years[1], F$ea_weight_years[2], F$n_div,
  F$w_decimals, year_runs(F$w_low_years_xk), F$w_low_decimals, F$n_div, u3(F$w_round_bound),
  u2(F$w_low_round_bound), u2(F$w_sum_max_dev),
  F$xk_index_first, F$ea_index_first, F$index_last),
"2. **`build/00_pull_coicop18_codelist.R`** — pulls the COICOP 2018 codelist for division labels.",
sprintf(paste("3. **`build/01_gate.R`** — checks that the design closes on the published data before",
"anything is decomposed. (a) In every month of every weight year and for both areas, the",
"all-items index relative to December of the previous year equals the weight-share-weighted sum",
"of the division indices relative to the same December, within %s pp. (b) The derived",
"December-to-December all-items rate matches Eurostat's published `RCH_A` within the rounding",
"bound computed for that area-year. (c) `I15` and `I25` give the same December-to-December",
"rates within index rounding. The gate passed on this vintage. Check (b) originally used the",
"same %s pp threshold as (a); because `RCH_A` is published to one decimal, it was amended after",
"the first run to the computed rounding bound. That first run had already passed %s pp in every",
"area-year, so the outcome did not change."),
  u2(F$gate_pp), u2(F$gate_pp), u2(F$gate_pp)),
sprintf(paste("4. **`build/02_decompose.R`** — the decomposition, one weight year at a time, from",
"December to December. For each area, *r* is a division's December-to-December rate and *s* its",
"weight as a share of the %d division weights (shares sum to exactly 1). The gap splits as"),
  F$n_div),
"",
"   ```",
"   composition    = Σ (s_XK − s_EA) · (r_XK + r_EA) / 2",
"   within-division = Σ (s_XK + s_EA) / 2 · (r_XK − r_EA)",
"   residual       = (π_XK − Σ s_XK·r_XK) − (π_EA − Σ s_EA·r_EA)",
"   gap = π_XK − π_EA = composition + within-division + residual",
"   ```",
"",
"   where π is the all-items December-to-December rate. This midpoint form is the headline. Two",
"   ordered variants are computed alongside it as bounds, and each adds up to the same gap:",
"",
"   | variant | composition | within-division |",
"   |---|---|---|",
"   | A: composition at euro-area rates | Σ (s_XK − s_EA) · r_EA | Σ s_XK · (r_XK − r_EA) |",
"   | B: composition at Kosova rates | Σ (s_XK − s_EA) · r_XK | Σ s_EA · (r_XK − r_EA) |",
"",
"   The midpoint terms are the average of A and B. The difference between the variants is the",
"   interaction Σ (s_XK − s_EA)(r_XK − r_EA). The window figure is the plain average of the",
"   yearly terms, so the parts still add up; compounded price-level gaps are not decomposed.",
paste0("   ", sq(sprintf(paste("The residual comes from rounding in the published indices and weights; it is at most",
"%s pp in any year and is reported in its own column, never folded into either term."),
  u2(F$max_abs_resid)))),
"",
"   December to December is used because a year's weights apply to price change measured from",
"   the previous December, so within a weight year the decomposition is an exact identity (check",
"   (a) above). A calendar-year average rate mixes two years' weights and cannot be split this",
"   way. Eurostat's published annual-average rate (`RCH_MV12MAVR`, December value, checked",
"   against the average recomputed from `I25` within rounding) is shown as a reference column",
"   and is **not decomposed**.",
"5. **`build/03_chart.R`** — the lead figure and a portrait version for LinkedIn.",
"6. **`build/04_readme.R`** — writes `data/processed/figures.json` and generates this README",
"   from it, so every number here is computed.",
"")

add(
"### The dominance rule (pre-registered)",
"",
"Fixed in `DESIGN.md` before any decomposition was computed. A term (composition or",
"within-division) **dominates** only if, under **both** ordered variants A and B:",
"",
"- it has the same sign as the gap, **and**",
sprintf("- its absolute value exceeds the other term's by more than %s pp (the gate threshold).", u2(F$gate_pp)),
"",
"Otherwise, in this order:",
"",
"- if the two terms have opposite signs under both variants, they are reported as **offsetting**;",
sprintf("- if their absolute values differ by %s pp or less under both variants, the result is a **tie**;", u2(F$gate_pp)),
"- in any other case the result is **range**: the A–B range is reported and no dominance statement is made.",
"",
"Year statements apply the rule to that year's terms. Window statements apply it to the window",
"averages of variant A and of variant B separately, never to a count of years. The rule decides",
"only the verdict. A separate column, `offset_by_other`, marks years where a term dominates while",
"the other term has the opposite sign to the gap under both variants.",
"")

row <- function(r) sprintf("| %s | %s | %s | %s | %s | %s | %s | %s to %s | %s | %s |",
  r$period, u2(r$pi_XK_pp), u2(r$pi_EA_pp), s2(r$gap_pp), s2(r$comp_mid_pp), s2(r$within_mid_pp),
  s2(r$resid_pp), s2(min(r$comp_A_pp, r$comp_B_pp)), s2(max(r$comp_A_pp, r$comp_B_pp)),
  r$verdict, if (is.na(r$ref_aa_gap_pp_not_decomposed)) "–" else s1(r$ref_aa_gap_pp_not_decomposed))
yr_rows <- vapply(seq_len(nrow(yr)), function(k) row(yr[k, ]), "")
win_row <- sprintf("| **Mean %d–%d** | %s | %s | %s | %s | %s | %s | %s to %s | %s | %s |",
  F$years[1], F$years[2], u2(F$win$pi_XK_pp), u2(F$win$pi_EA_pp), s2(F$win$gap_pp),
  s2(F$win$comp_mid_pp), s2(F$win$within_mid_pp), s2(F$win$resid_pp),
  s2(min(F$win$comp_A_pp, F$win$comp_B_pp)), s2(max(F$win$comp_A_pp, F$win$comp_B_pp)),
  win$verdict, s1(F$win$ref_aa_gap_pp_not_decomposed))

add(
"## Key results",
"",
"Percentage points; December to December unless marked. Midpoint terms; the composition range",
"is variant A to variant B.",
"",
"| Weight year | Kosova | Euro area | Gap | Composition | Within-division | Residual | Composition, A–B | Verdict | Annual-average gap (not decomposed) |",
"|---|---|---|---|---|---|---|---|---|---|",
yr_rows, win_row,
"",
sprintf(paste("- **%d:** gap %s pp, within-division %s pp, composition %s pp; within-division",
"dominates under both variants. The three divisions with the largest within-division",
"contributions are %s (%s pp), %s (%s pp) and %s (%s pp), together %s of the within-division",
"term."),
  EMPH, s1(e$gap_pp), s1(e$within_mid_pp), s1(e$comp_mid_pp),
  it(t25$division_label[1]), s1(t25$contribution_pp[1]), it(t25$division_label[2]), s1(t25$contribution_pp[2]),
  it(t25$division_label[3]), s1(t25$contribution_pp[3]), pct(F$top3_share_2025)),
sprintf("- **Verdicts by year:** within-division in %s; range in %s. No year is composition, offsetting or a tie.",
  year_runs(within_yrs), year_runs(range_yrs)),
sprintf(paste("- **Window %d–%d:** mean gap %s pp. Under variant A the within-division term is",
"larger (%s against %s pp); under variant B composition is larger (%s against %s pp). The",
"verdict is therefore range, and no statement is made about which part is larger over the window."),
  F$years[1], F$years[2], s1(F$win$gap_pp), s2(F$win$within_A_pp), s2(F$win$comp_A_pp),
  s2(F$win$comp_B_pp), s2(F$win$within_B_pp)),
sprintf(paste("- **2026 year to date (provisional):** from December 2025 to %s, cumulative, not",
"annual, and excluded from all averages: Kosova %s%%, euro area %s%%, gap %s pp. This spans",
"December to August, not a full seasonal cycle, so it appears only with that caveat, and its",
"division-level split is not reported."),
  F$index_last, u1(F$ytd$pi_XK_pp), u1(F$ytd$pi_EA_pp), s1(F$ytd$gap_pp)),
"")

add(
"## Reproduce",
"",
sprintf("%s. Packages: `dplyr`, `tidyr`, `readr`, `stringr`, `ggplot2`, `showtext`, `magick`, `scales`, `jsonlite`.", F$r_version),
"From the piece root, in order:",
"",
"```",
"Rscript verify/01_coverage.R",
"Rscript build/00_pull_coicop18_codelist.R",
"Rscript build/01_gate.R",
"Rscript build/02_decompose.R",
"Rscript build/03_chart.R",
"Rscript build/04_readme.R",
"```",
"",
"The raw Eurostat bulk downloads are not committed: `prc_hicp_minr` is over GitHub's 100 MB",
"limit. `verify/01_coverage.R` downloads them again if they are missing. Eurostat revises, so",
"a fresh download may not match; the committed `.rds` files filtered to `XK` and `EA` are the",
"record of the vintage used here.",
"")

add(
"## Outputs",
"",
"- `output/hicp_gap_decomposition.csv` — one row per weight year, the window mean and the 2026",
"  year-to-date row: rates, gap, midpoint and variant terms, interaction, residual, reference",
"  annual-average rates, euro-area `u`-flag marker, verdict, `offset_by_other`, seasonality caveat.",
sprintf("- `output/hicp_gap_within_top3.csv` — top three division contributions to the within-division term, %d and 2026 year to date (the latter not reported in prose, see Limitations).", EMPH),
"- `output/hicp_gap_decomposition.png` — lead figure.",
"- `output/hicp_gap_linkedin.png` — portrait version, 1200 × 1500.",
"- `data/processed/figures.json` — every number used in this README.",
"- `DESIGN.md`, `HANDOFF.md` — the design as fixed before computation, and the verification record.",
"")

add(
"## Limitations",
"",
"- **Within-division mixes two things.** It combines price differences for the same goods with",
"  differences in what each basket holds inside a division. Separating them would need weights",
"  and indices below division level, which this piece does not use.",
"- **The split depends on the ordering.** The midpoint form is a convention. Variants A and B",
"  bound it, and the dominance rule only reports a winner when both variants agree.",
sq(sprintf(paste("- **December to December is not the headline annual rate.** The annual-average gap",
"(reference column) can have the opposite sign: it does in %s, and is zero in %s. Only December to",
"December can be split exactly."),
  year_runs(F$sign_mismatch), year_runs(F$ref_zero_years))),
"- **Comparator.** From 2023 the EA comparator includes Croatia.",
sq(sprintf(paste("- **Low-reliability flags.** Eurostat flags some euro-area division index values between",
"%s and %s as low reliability (`u`). Of those, only %s is a December value, so it enters",
"weight years %s. It is used as published, because it is the value inside Eurostat's own",
"euro-area all-items index."),
  F$u_first, F$u_last, F$u_dec, year_runs(F$u_years))),
"- **Back-calculation.** Pre-2026 figures are back-calculated under the 2026 classification",
"  (ECOICOP ver.2) and can differ from figures published at the time.",
"- **Conformity.** Eurostat publishes HICPs for the enlargement countries and Kosova, and notes",
"  that their conformity with HICP methodological requirements \"has not been fully evaluated",
"  by Eurostat\" ([HICP metadata](https://ec.europa.eu/eurostat/cache/metadata/en/prc_hicp_esms.htm),",
"  retrieved 2026-09-23).",
sq(sprintf(paste("- **Residual.** Up to %s pp in any year, from rounding in the published indices and",
"weights. It is reported, not allocated."), u2(F$max_abs_resid))),
"- **2026 year to date.** It spans December to August, not a full seasonal cycle. Division-level",
"  year-to-date contributions can reflect differing seasonal patterns between the two areas (for",
"  example, sales calendars) and are not reported. The year-to-date aggregate appears only with",
"  this caveat.",
"- **Vintage.** Eurostat revises HICP data; figures here are for the vintage stated above.",
"",
"---",
"",
"Data: Eurostat (`prc_hicp_minr`, `prc_hicp_iw`, COICOP 2018 codelist). Analysis: Plator Krasniqi.")

n_blank <- sum(L == "")
L <- unlist(lapply(L, function(x) if (x == "") "" else strsplit(x, "\n", fixed = TRUE)[[1]]))
stopifnot(sum(L == "") == n_blank)                              # blank lines preserved
in_code <- cumsum(grepl("^\\s*```", L)) %% 2 == 1 | grepl("^\\s*```", L)
stopifnot(!any(grepl("\\S {2,}\\S", L[!in_code])))            # no stray space runs in prose
tbl <- L[grepl("^\\| (\\d{4}|\\*\\*Mean)", L)]
stopifnot(length(tbl) == length(YEARS) + 1,
          all(lengths(regmatches(tbl, gregexpr("\\|", tbl))) == 11))   # 10 columns per row
writeLines(L, file.path(PROJ, "README.md"), useBytes = FALSE)

# ------------------------------------------------------------------------------
# LinkedIn post (not part of the public piece)
# ------------------------------------------------------------------------------
# Guards on the wording: each claim in the post must follow from the computed terms.
p2 <- t25 |> filter(rank %in% 1:2) |> arrange(rank)
stopifnot(
  e$verdict == "within-division",                       # "holds under both ways" (dominance rule, A and B)
  e$comp_mid_pp < 0, e$within_mid_pp >= e$gap_pp,       # "the whole gap sits in the second part"
  F$win$verdict == "range",                             # window split "isn't robust"
  sign(F$win$comp_A_pp - F$win$within_A_pp) != sign(F$win$comp_B_pp - F$win$within_B_pp),  # "either part can come out larger"
  nrow(p2) == 2, identical(p2$rank, 1:2),               # the two listed divisions are the top two of t25
  all(p2$contribution_pp > 0), p2$contribution_pp[1] >= p2$contribution_pp[2],
  sum(p2$contribution_pp) < e$within_mid_pp)            # and together less than the within-division total
post <- c(
  sprintf("Consumer prices in Kosova rose %s%% in %d, December to December. In the euro area: %s%%. Same currency, a gap of %s percentage points.",
          u1(e$pi_XK_pp), EMPH, u1(e$pi_EA_pp), u1(e$gap_pp)),
  "Kosova uses the euro without being part of the euro area. It has no monetary policy of its own: its central bank does not set interest rates.",
  "A gap like this can come from two places:",
  "",
  sprintf("1. How spending is split across the %d main consumption categories (food, housing and energy, transport, and so on).", F$n_div),
  "2. Differences inside each category: what exactly is bought within it, and how those prices moved.",
  "",
  sprintf("In %d the whole gap sits in the second part: %s pp from inside the categories, %s pp from the split of spending across them. The result holds under both ways of computing the decomposition.",
          EMPH, s1(e$within_mid_pp), s1(e$comp_mid_pp)),
  sprintf("Within that %s pp, the largest contributions came from %s (%s pp) and %s (%s pp).",
          s1(e$within_mid_pp), tolower(p2$division_label[1]), s1(p2$contribution_pp[1]),
          tolower(p2$division_label[2]), s1(p2$contribution_pp[2])),
  sprintf("%d stands out. Over %d–%d the gap averaged %s pp a year, and over that period the split isn't robust: depending on how it's computed, either part can come out larger.",
          EMPH, F$years[1], F$years[2], s1(F$win$gap_pp)),
  "So last year's gap wasn't about how Kosova divides its spending across the main categories. It came from what happened inside them.",
  sprintf("Method, data and limitations, including HICP comparability caveats for Kosova: %s", PIECE_URL),
  "Personal analysis, public data.")
writeLines(post, file.path(PROJ, "output/linkedin_post.txt"))

cat("wrote README.md (", length(L), "lines ), data/processed/figures.json, output/linkedin_post.txt\n")
