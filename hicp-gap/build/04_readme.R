# ==============================================================================
# 04_readme.R
# Generates README.md and the LinkedIn post text from computed values.
#
# House rule (CLAUDE.md §2): every number in prose is computed by a script,
# never typed by hand. Values are collected into data/processed/figures.json
# and all prose is built from them with sprintf().
#
# Reads:  output/hicp_gap_decomposition.csv, output/hicp_gap_within_top3.csv
#         output/hicp_gap_2025_composition_by_division.csv,
#         output/hicp_gap_2025_weight_year_robustness.csv,
#         output/hicp_gap_xk_weight_sources.csv   (build/02_decompose.R section 6,
#           added after cold review 2026-10-01, not pre-registered)
#         data/raw/<date>/eurostat_prc_hicp_minr_XK_EA.rds, ..._iw_XK_EA.rds
#         data/raw/<date>/eurostat_prc_hicp_iw_bulk.csv.gz   (EA membership check
#           only: EA item weights equal EA20 through 2025 and EA21 from 2026, i.e.
#           Bulgaria joins in January 2026; gitignored, verify/01_coverage.R
#           downloads it again if missing)
# Writes: data/processed/figures.json   (post-review values under `post_review`)
#         README.md
#         output/linkedin_post.txt   (gitignored; not part of the public piece)
# Post v3 (2026-10-01): every claim in the post must hold under variant A and
# variant B, and every figure in it is pre-registered (headline, reference
# column, top-three share). The 2026 year-to-date row is not quoted in the post.
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
and_list <- function(x) if (length(x) == 1) x else if (length(x) == 2) paste(x, collapse = " and ") else
  paste0(paste(x[-length(x)], collapse = ", "), ", and ", x[length(x)])   # serial comma: names contain "and"

# ------------------------------------------------------------------------------
# Inputs
# ------------------------------------------------------------------------------
dec <- read_csv(file.path(PROJ, "output/hicp_gap_decomposition.csv"),
                col_types = cols(period = "c", type = "c", verdict = "c", seasonality_caveat = "c",
                                 ea_u_flag = "l", offset_by_other = "l", .default = col_double()))
top <- read_csv(file.path(PROJ, "output/hicp_gap_within_top3.csv"),
                col_types = cols(period = "c", division = "c", division_label = "c",
                                 seasonality_caveat = "c", rank = "i", .default = col_double()))
# Added after cold review (2026-10-01), not pre-registered (build/02_decompose.R section 6)
cdiv <- read_csv(file.path(PROJ, "output/hicp_gap_2025_composition_by_division.csv"),
                 col_types = cols(period = "c", division = "c", division_label = "c", .default = col_double()))
rob  <- read_csv(file.path(PROJ, "output/hicp_gap_2025_weight_year_robustness.csv"),
                 col_types = cols(period = "c", verdict = "c", headline = "l",
                                  xk_weight_year = "i", ea_weight_year = "i", .default = col_double()))
wsrc <- read_csv(file.path(PROJ, "output/hicp_gap_xk_weight_sources.csv"),
                 col_types = cols(weight_year = "i", documented = "l", in_window = "l", .default = "c"))
stopifnot(nrow(cdiv) == 13, nrow(rob) >= 2, sum(rob$headline) == 1, nrow(wsrc) >= 1)
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

# --- Added after cold review (2026-10-01) ---------------------------------------
PR_LABEL  <- "added after cold review (2026-10-01), not pre-registered"
REF_LABEL <- "pre-registered reference column, quoted in the post after cold review"

# EA membership: the year Bulgaria enters the EA comparator. EA's item weights
# equal EA20's up to the year before and EA21's from that year (bulk prc_hicp_iw).
iw_bulk_f <- file.path(dated[1], "eurostat_prc_hicp_iw_bulk.csv.gz")
stopifnot(file.exists(iw_bulk_f))
ea_cmp <- read_csv(iw_bulk_f, col_types = cols(.default = "c"), progress = FALSE) |>
  filter(geo %in% c("EA", "EA20", "EA21"), grepl("^CP\\d{2}$", coicop18),
         as.integer(TIME_PERIOD) >= max(YEARS) - 2) |>
  select(geo, coicop18, year = TIME_PERIOD, OBS_VALUE) |>
  tidyr::pivot_wider(names_from = geo, values_from = OBS_VALUE) |>
  group_by(year = as.integer(year)) |>
  summarise(n = n(), eq20 = all(EA == EA20), eq21 = all(EA == EA21), .groups = "drop")
bg_year <- min(ea_cmp$year[ea_cmp$eq21 & !ea_cmp$eq20])
print(as.data.frame(ea_cmp), row.names = FALSE)
stopifnot(all(ea_cmp$n == 13), bg_year == max(YEARS) + 1,
          all(ea_cmp$eq20[ea_cmp$year < bg_year]), all(!ea_cmp$eq21[ea_cmp$year < bg_year]),
          all(ea_cmp$eq21[ea_cmp$year >= bg_year]))

# Within-division contributions of the three named divisions under variants A and B
# (post guard: the named set's share must hold under both orderings)
r25 <- minr |> filter(unit == "I25", coicop18 %in% sprintf("CP%02d", 1:13),
                      time %in% sprintf(c("%d-12", "%d-12"), c(EMPH - 1, EMPH))) |>
  select(geo, code = coicop18, time, values) |>
  tidyr::pivot_wider(names_from = time, values_from = values) |>
  mutate(r = .data[[sprintf("%d-12", EMPH)]] / .data[[sprintf("%d-12", EMPH - 1)]] - 1) |>
  select(geo, code, r) |>
  left_join(iw |> filter(time == as.character(EMPH), grepl("^CP\\d{2}$", coicop18)) |>
              group_by(geo) |> mutate(s = values / sum(values)) |> ungroup() |>
              select(geo, code = coicop18, s), by = c("geo", "code")) |>
  tidyr::pivot_wider(names_from = geo, values_from = c(s, r)) |>
  mutate(cA = 100 * s_XK * (r_XK - r_EA), cB = 100 * s_EA * (r_XK - r_EA))
stopifnot(nrow(r25) == 13, !anyNA(r25),
          abs(sum(r25$cA) - e$within_A_pp) < 1e-5, abs(sum(r25$cB) - e$within_B_pp) < 1e-5)
named_share <- c(A = sum(r25$cA[r25$code %in% t25$division]) / sum(r25$cA),
                 B = sum(r25$cB[r25$code %in% t25$division]) / sum(r25$cB))
food   <- cdiv |> filter(division == "CP01")
rob_h  <- rob |> filter(headline)
rob_o  <- rob |> filter(!headline)
undoc  <- wsrc |> filter(!documented)
food_s <- iw |> filter(geo == "XK", grepl("^CP\\d{2}$", coicop18)) |>
  group_by(year = as.integer(time)) |> summarise(share = values[coicop18 == "CP01"] / sum(values), .groups = "drop")
stopifnot(nrow(food) == 1, abs(sum(cdiv$comp_dev_pp) - e$comp_mid_pp) < 1e-5,
          rob_h$xk_weight_year == EMPH, abs(rob_h$comp_mid_pp - e$comp_mid_pp) < 1e-5,
          abs(rob_h$within_mid_pp - e$within_mid_pp) < 1e-5, rob_h$verdict == e$verdict,
          n_distinct(wsrc$metadata_last_update) == 1, n_distinct(wsrc$metadata_url) == 1,
          abs(food$share_XK - food_s$share[food_s$year == EMPH]) < 1e-6,
          abs(e$ref_aa_gap_pp_not_decomposed - (e$ref_aa_XK_pp - e$ref_aa_EA_pp)) < 1e-9)
F$post_review <- list(
  label = PR_LABEL,
  composition_by_division_2025 = list(
    label = PR_LABEL,
    form = paste("deviation, centred at the share-midpoint-weighted mean of each form's rates:",
                 "midpoint (s_XK - s_EA) * (rbar_i - rbar); A (s_XK - s_EA) * (r_EA,i - rbarA);",
                 "B (s_XK - s_EA) * (r_XK,i - rbarB)"),
    basket_mean_rate_pp = unique(cdiv$basket_mean_rate_pp),
    basket_mean_rate_A_pp = unique(cdiv$basket_mean_rate_A_pp),
    basket_mean_rate_B_pp = unique(cdiv$basket_mean_rate_B_pp),
    divisions = cdiv |> select(division, division_label, share_XK, share_EA, mean_rate_pp,
                               comp_dev_A_pp, comp_dev_pp, comp_dev_B_pp),
    food_share_XK = food$share_XK, food_share_EA = food$share_EA, food_comp_dev_pp = food$comp_dev_pp,
    food_comp_dev_A_pp = food$comp_dev_A_pp, food_comp_dev_B_pp = food$comp_dev_B_pp,
    positive_sum_pp = sum(pmax(cdiv$comp_dev_pp, 0)), negative_sum_pp = sum(pmin(cdiv$comp_dev_pp, 0)),
    sign_differs_A_B = cdiv$division[sign(round(cdiv$comp_dev_A_pp, 2)) * sign(round(cdiv$comp_dev_B_pp, 2)) < 0],
    xk_food_share_by_weight_year = food_s),
  weight_year_robustness_2025 = list(
    label = PR_LABEL, ea_weight_year = unique(rob$ea_weight_year),
    rows = rob |> select(xk_weight_year, comp_mid_pp, within_mid_pp, resid_pp,
                         comp_A_pp, within_A_pp, comp_B_pp, within_B_pp, verdict, headline),
    xk_weight_years = range(rob$xk_weight_year),
    all_within_division = all(rob$verdict == "within-division"),
    comp_mid_range_other_years = range(rob_o$comp_mid_pp),
    comp_A_range_other_years = range(rob_o$comp_A_pp),
    comp_B_range_other_years = range(rob_o$comp_B_pp),
    resid_range_other_years = range(rob_o$resid_pp),
    max_abs_resid_other_years = max(abs(rob_o$resid_pp))),
  ea_membership = list(
    label = PR_LABEL,
    bulgaria_from = bg_year,
    check = "EA item weights equal EA20 before that year and EA21 from it (bulk prc_hicp_iw)"),
  post_guards = list(
    label = "computed for the LinkedIn post guards only; not quoted",
    top3_named_share_A = unname(named_share["A"]), top3_named_share_B = unname(named_share["B"])),
  annual_average_2025 = list(
    label = REF_LABEL, XK_pp = e$ref_aa_XK_pp, EA_pp = e$ref_aa_EA_pp,
    gap_pp = e$ref_aa_gap_pp_not_decomposed),
  weight_sources = list(
    metadata_url = unique(wsrc$metadata_url), metadata_last_update = unique(wsrc$metadata_last_update),
    retrieved = unique(wsrc$retrieved),
    documented_years = wsrc$weight_year[wsrc$documented],
    undocumented_in_window = undoc$weight_year[undoc$in_window],
    undocumented_outside_window = undoc$weight_year[!undoc$in_window]))
dir.create(file.path(PROJ, "data/processed"), showWarnings = FALSE, recursive = TRUE)
write_json(F, file.path(PROJ, "data/processed/figures.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)

# Vintage in words, from Eurostat's "LAST UPDATE" stamp (dd/mm/yy). English month
# names from month.name, so the session locale does not matter.
vintage_date <- as.Date(F$vintage, format = "%d/%m/%y")
stopifnot(length(F$vintage) == 1, !is.na(vintage_date), format(vintage_date, "%d/%m/%y") == F$vintage)
vintage_long <- sprintf("%d %s %s", as.integer(format(vintage_date, "%d")),
                        month.name[as.integer(format(vintage_date, "%m"))], format(vintage_date, "%Y"))

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
"with its membership as it changed over time. Vintage: Eurostat release of %s, downloaded %s."),
  vintage_long, F$downloaded),
"",
"Deliberately not used:",
"",
"- **Fixed-composition euro-area aggregates** (`EA19`, `EA20`, `EA21`). They project members",
"  backwards to years before they used the euro; the piece compares against the euro area as",
"  it actually was in each year.",
sprintf(paste("- **Kosova's %d weights** in the decomposition. The Kosova index starts in %s, so there is",
  "no December %d base to link from. They appear only as one of the alternative baskets in the",
  "weight-year sensitivity check under *Added after cold review*."),
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
"",
"   Section 6 of the script was added after cold review (2026-10-01) and is not pre-registered.",
"   It writes the three files described under *Added after cold review* below; nothing above",
"   depends on it.",
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
# 2026 year-to-date row (DESIGN.md §2: a labelled row, excluded from all averages).
# The README label is set here; the CSV period string is pre-registered output and unchanged.
ytd_last  <- as.Date(paste0(F$index_last, "-01"))
ytd_mon   <- sprintf("%s %s", month.abb[as.integer(format(ytd_last, "%m"))], format(ytd_last, "%Y"))
ytd_label <- sprintf("%s, cumulative Dec %d → %s (latest), provisional", format(ytd_last, "%Y"), EMPH, ytd_mon)
stopifnot(format(ytd_last, "%Y") == as.character(EMPH + 1),
          grepl(sprintf("Dec %d→%s", EMPH, ytd_mon), ytd$period, fixed = TRUE))
ytd_row <- sprintf("| %s | %s | %s | %s | %s | %s | %s | %s to %s | %s | — |",
  ytd_label, u2(F$ytd$pi_XK_pp), u2(F$ytd$pi_EA_pp), s2(F$ytd$gap_pp), s2(F$ytd$comp_mid_pp),
  s2(F$ytd$within_mid_pp), s2(F$ytd$resid_pp), s2(min(F$ytd$comp_A_pp, F$ytd$comp_B_pp)),
  s2(max(F$ytd$comp_A_pp, F$ytd$comp_B_pp)), ytd$verdict)

add(
"## Key results",
"",
"Percentage points; December to December unless marked. Midpoint terms; the composition range",
sprintf("is variant A to variant B. The %d row is cumulative and is excluded from the mean.", EMPH + 1),
"",
"| Weight year | Kosova | Euro area | Gap | Composition | Within-division | Residual | Composition, A–B | Verdict | Annual-average gap (not decomposed) |",
"|---|---|---|---|---|---|---|---|---|---|",
yr_rows, win_row, ytd_row,
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
sprintf(paste("- **%s:** not annual, and excluded from all averages: Kosova %s%%, euro area %s%%, gap",
"%s pp. This spans December to %s, not a full seasonal cycle, so it appears only with that caveat,",
"and its division-level split is not reported. From January %d the euro-area comparator includes",
"Bulgaria."),
  ytd_label, u1(F$ytd$pi_XK_pp), u1(F$ytd$pi_EA_pp), s1(F$ytd$gap_pp),
  month.name[as.integer(format(ytd_last, "%m"))], F$post_review$ea_membership$bulgaria_from),
"")

# --- Added after cold review (2026-10-01) ---------------------------------------
PRc <- F$post_review$composition_by_division_2025
PRr <- F$post_review$weight_year_robustness_2025
PRa <- F$post_review$annual_average_2025
PRw <- F$post_review$weight_sources
p1  <- function(x) sprintf("%.1f%%", 100 * x)
year_list <- function(y) if (length(y) == 1) as.character(y) else
  paste(paste(y[-length(y)], collapse = ", "), "and", y[length(y)])
cdiv_rows <- vapply(seq_len(nrow(cdiv)), function(k) with(cdiv[k, ], sprintf("| %s | %s | %s | %s | %s | %s |",
  it(division_label), p1(share_XK), p1(share_EA), s2(comp_dev_A_pp), s2(comp_dev_pp), s2(comp_dev_B_pp))), "")
sign_ab <- cdiv |> filter(division %in% PRc$sign_differs_A_B)
rob_rows <- vapply(seq_len(nrow(rob)), function(k) with(rob[k, ],
  sprintf("| %d%s | %s | %s | %s | %s | %s | %s | %s | %s |",
  xk_weight_year, if (headline) " (published)" else "", s2(comp_mid_pp), s2(comp_A_pp), s2(comp_B_pp),
  s2(within_mid_pp), s2(within_A_pp), s2(within_B_pp), s2(resid_pp), verdict)), "")
# Summary sentences. The wording below holds only if these conditions do; on
# failure stop and report rather than reword.
stopifnot(PRr$all_within_division,                         # "dominates under every Kosova weight year"
          all(rob_o$comp_A_pp < 0), all(rob_o$comp_B_pp > 0),   # sign statements per variant
          nrow(sign_ab) >= 1)
rob_summary <- sq(sprintf(paste("Within-division dominates under every Kosova weight year from %d to %d.",
  "The composition term does not keep its sign: with the other weight years it lies between %s and %s pp",
  "at the midpoint; under variant A it is negative with every weight year (%s to %s pp), and under",
  "variant B it is positive with every weight year except %d (%s to %s pp)."),
  PRr$xk_weight_years[1], PRr$xk_weight_years[2],
  s2(PRr$comp_mid_range_other_years[1]), s2(PRr$comp_mid_range_other_years[2]),
  s2(PRr$comp_A_range_other_years[1]), s2(PRr$comp_A_range_other_years[2]), EMPH,
  s2(PRr$comp_B_range_other_years[1]), s2(PRr$comp_B_range_other_years[2])))

add(
"## Added after cold review (2026-10-01)",
"",
paste("The items in this section were added after all results above had been seen, following an",
"internal review of the draft text (`DESIGN.md`, *Post-review additions*). The first two are",
"**not pre-registered**. None of them changes a number or verdict above."),
"",
sprintf("### 2025 composition term by division — *%s*", PR_LABEL),
"",
sq(sprintf(paste("The 2025 composition term is the balance of division terms with opposite signs. Per",
"division, in deviation form, the midpoint term is (s_XK − s_EA) · (r̄_i − r̄), where r̄_i is the mean",
"of the two areas' December-to-December rates in division *i* and r̄ is the mean of those, weighted by",
"the average of the two areas' shares (%s%%). Variant A uses the euro-area rates in place of r̄_i,",
"centred on their mean with the same weights (%s%%); variant B uses the Kosova rates (%s%%). Each",
"column adds up exactly to its composition term (A %s, midpoint %s, B %s pp), and unlike the raw form",
"(s_XK − s_EA) · rate it does not change if every rate shifts by the same amount; the choice of centre",
"is a convention. The per-division terms depend on the ordering. Food is %s of Kosova's basket against",
"%s of the euro area's; its term is %s pp under A, %s pp at the midpoint and %s pp under B. The terms of",
"%s have opposite signs under A and B (at two decimals). At the midpoint the positive terms sum to %s pp",
"and the negative terms to %s pp. The shares are Kosova's %d weights, whose source year is not",
"documented (see Limitations)."),
  u2(PRc$basket_mean_rate_pp), u2(PRc$basket_mean_rate_A_pp), u2(PRc$basket_mean_rate_B_pp),
  s2(e$comp_A_pp), s2(e$comp_mid_pp), s2(e$comp_B_pp),
  p1(PRc$food_share_XK), p1(PRc$food_share_EA),
  s2(PRc$food_comp_dev_A_pp), s2(PRc$food_comp_dev_pp), s2(PRc$food_comp_dev_B_pp),
  and_list(it(sign_ab$division_label)), s2(PRc$positive_sum_pp), s2(PRc$negative_sum_pp), EMPH)),
"",
"| Division | Kosova share | Euro-area share | Variant A (pp) | Midpoint (pp) | Variant B (pp) |",
"|---|---|---|---|---|---|",
cdiv_rows,
"",
sprintf("### 2025 split with every Kosova weight year, %d–%d — *%s*", PRr$xk_weight_years[1],
  PRr$xk_weight_years[2], PR_LABEL),
"",
sq(sprintf(paste("The %d rates are split again with every Kosova weight year Eurostat publishes, %d to %d,",
"keeping the euro area at its %d weights. This tests how the split changes with an older or newer",
"Kosova basket. It does not test the undocumented source year of the %d weights (see Limitations):",
"gate (a) shows that Kosova's published all-items index is compiled with its %d weights, within %s pp",
"in every month, so those are the weights it decomposes with, whatever national-accounts year they are",
"based on. Only the %d row is a valid decomposition. With any other weight year the parts no longer add",
"up to the gap exactly, and the residual (its own column) lies between %s and %s pp. The verdict",
"applies the pre-registered dominance rule to variants A and B."),
  EMPH, PRr$xk_weight_years[1], PRr$xk_weight_years[2], PRr$ea_weight_year, EMPH, EMPH, u2(F$gate_pp),
  EMPH, s2(PRr$resid_range_other_years[1]), s2(PRr$resid_range_other_years[2]))),
"",
"| Kosova weight year | Composition, midpoint | Composition, A | Composition, B | Within-division, midpoint | Within-division, A | Within-division, B | Residual | Verdict |",
"|---|---|---|---|---|---|---|---|---|",
rob_rows,
"",
rob_summary,
"",
sprintf("### %d annual-average rates — *%s*", EMPH, REF_LABEL),
"",
sq(sprintf(paste("Eurostat's published annual-average rates for %d (`RCH_MV12MAVR`, December value)",
"are %s%% for Kosova and %s%% for the euro area, a gap of %s pp, against %s pp December to",
"December. This is the reference column of the table above and is not decomposed."),
  EMPH, u1(PRa$XK_pp), u1(PRa$EA_pp), s1(PRa$gap_pp), s1(e$gap_pp))),
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
sprintf("- `output/hicp_gap_2025_composition_by_division.csv` — %s: the %d composition term per division, deviation form, under variant A, the midpoint and variant B.", PR_LABEL, EMPH),
sprintf("- `output/hicp_gap_2025_weight_year_robustness.csv` — %s: the %d split with every Kosova weight year %d–%d (midpoint, A, B, residual, verdict).", PR_LABEL, EMPH, min(rob$xk_weight_year), max(rob$xk_weight_year)),
"- `output/hicp_gap_xk_weight_sources.csv` — weight source years as stated on Eurostat's Kosova metadata page, with the verbatim fragments.",
"- `data/processed/figures.json` — every number used in this README; post-review values under `post_review`.",
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
sq(sprintf(paste("- **Comparator.** From 2023 the EA comparator includes Croatia. EA includes Bulgaria from",
"January %d (EA item weights equal `EA20`'s up to %d and `EA21`'s from %d), which affects only the",
"%d year-to-date row."),
  F$post_review$ea_membership$bulgaria_from, F$post_review$ea_membership$bulgaria_from - 1,
  F$post_review$ea_membership$bulgaria_from, EMPH + 1)),
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
sq(sprintf(paste("- **Weight source years.** Eurostat's Kosova HICP metadata page",
"([metadata](%s), last update %s, retrieved %s) states the national-accounts source of the weights",
"for weight years %s. It gives none for %s, inside the window, or for %s, outside it. The %d headline",
"uses the %d weights. Kosova's food share of the %d division weights is %s in %d, the last documented",
"weight year, and %s in %d. With",
"other Kosova weight years the %d split changes as shown under *Added after cold review*."),
  PRw$metadata_url, PRw$metadata_last_update, PRw$retrieved, year_runs(PRw$documented_years),
  year_list(PRw$undocumented_in_window), year_list(PRw$undocumented_outside_window), EMPH, EMPH,
  F$n_div, p1(food_s$share[food_s$year == max(PRw$documented_years)]), max(PRw$documented_years),
  p1(food_s$share[food_s$year == EMPH]), EMPH, EMPH)),
sq(sprintf(paste("- **Residual.** Up to %s pp in any year, from rounding in the published indices and",
"weights. It is reported, not allocated."), u2(F$max_abs_resid))),
sq(sprintf(paste("- **%d year to date.** It is cumulative from December %d to %s, provisional, and spans",
"December to %s, not a full seasonal cycle. Division-level year-to-date contributions can reflect",
"differing seasonal patterns between the two areas (for example, sales calendars) and are not",
"reported. The year-to-date aggregate appears only with this caveat."),
  EMPH + 1, EMPH, ytd_mon, month.name[as.integer(format(ytd_last, "%m"))])),
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
kr  <- which(L == "## Key results"); pr <- which(L == "## Added after cold review (2026-10-01)")
stopifnot(length(kr) == 1, length(pr) == 1, pr > kr)
tbl <- L[kr:pr][grepl("^\\| (\\d{4}|\\*\\*Mean)", L[kr:pr])]          # Key results table only
stopifnot(length(tbl) == length(YEARS) + 2,                         # years, mean, YTD row
          sum(tbl == ytd_row) == 1,
          all(lengths(regmatches(tbl, gregexpr("\\|", tbl))) == 11))   # 10 columns per row
writeLines(L, file.path(PROJ, "README.md"), useBytes = FALSE)

# ------------------------------------------------------------------------------
# LinkedIn post (not part of the public piece)
# ------------------------------------------------------------------------------
# v3 text (2026-10-01, after the second cold review). Guard rule: every claim in
# the post must hold under variant A AND variant B. Every figure in the post is
# pre-registered: the 2025 headline row, the reference column (published
# RCH_MV12MAVR, December) and the top-three share. The A/B checks below are
# guards only and print nothing into the post. On a failed guard, stop and
# report; do not reword.

# Prose names for divisions: an explicit lookup, keyed by code. Source labels
# stay verbatim in the README.
POST_NAMES <- tribble(
  ~division, ~name,
  "CP01",    "food",
  "CP04",    "housing and energy",
  "CP11",    "restaurants and accommodation")
pname <- function(codes) {
  miss <- setdiff(codes, POST_NAMES$division)
  if (length(miss)) stop("no post name for division(s): ", paste(miss, collapse = ", "))
  POST_NAMES$name[match(codes, POST_NAMES$division)]
}

# "On annual averages, prices rose x% in Kosova against y% in the euro area":
# the published December RCH_MV12MAVR values, read from the raw table, equal to
# the pre-registered reference column and quoted exactly as published (1 decimal)
aa_pub <- minr |> filter(unit == "RCH_MV12MAVR", coicop18 == "TOTAL", time == sprintf("%d-12", EMPH))
aa_XK  <- aa_pub$values[aa_pub$geo == "XK"]
aa_EA  <- aa_pub$values[aa_pub$geo == "EA"]
stopifnot(nrow(aa_pub) == 2, length(aa_XK) == 1, length(aa_EA) == 1,
          aa_XK == e$ref_aa_XK_pp, aa_EA == e$ref_aa_EA_pp,
          aa_XK == PRa$XK_pp, aa_EA == PRa$EA_pp,
          abs(round(aa_XK, 1) - aa_XK) < 1e-9, abs(round(aa_EA, 1) - aa_EA) < 1e-9)

# "the second part accounts for more than the whole gap ... That holds under both
# ways of computing the decomposition": within-division dominates under A and
# under B (the §3 rule), exceeds the gap under A, B and the midpoint, and
# composition is negative under A, B and the midpoint
dom <- function(t, o) sign(t) == sign(e$gap_pp) & (abs(t) - abs(o) > GATE_PP)
stopifnot(e$verdict == "within-division", e$gap_pp > 0,
          dom(e$within_A_pp, e$comp_A_pp), dom(e$within_B_pp, e$comp_B_pp),
          e$within_A_pp > e$gap_pp, e$within_B_pp > e$gap_pp, e$within_mid_pp > e$gap_pp,
          e$comp_A_pp < 0, e$comp_B_pp < 0, e$comp_mid_pp < 0)

# "food, housing and energy, and restaurants and accommodation account for 87%":
# the pre-registered top three and their combined share at the midpoint; the same
# three divisions' share must lie within 85-90% under A and under B as well
SHARE_BAND <- c(0.85, 0.90)
in_band <- function(x) x >= SHARE_BAND[1] & x <= SHARE_BAND[2]
stopifnot(identical(t25$rank, 1:3), all(t25$contribution_pp > 0),
          identical(t25$division, (top |> filter(period == as.character(EMPH)) |>
                                     arrange(desc(contribution_pp)))$division),
          abs(sum(t25$contribution_pp) / e$within_mid_pp - F$top3_share_2025) < 1e-5,
          in_band(F$top3_share_2025), all(in_band(named_share)))

# Caveat sentence: the 2025 weights' source year is undocumented; 2025 precedes
# the classification change, so its division data are back-calculated
ECOICOP2_FROM <- 2026L    # HICP compiled under ECOICOP ver.2 from January 2026 (README, Back-calculation)
stopifnot(EMPH %in% PRw$undocumented_in_window, EMPH < ECOICOP2_FROM)

NOT_IDENTIFIED <- paste("This is an accounting split, not an explanation: why prices inside these",
                        "categories rose faster in Kosova is not identified here.")
post <- c(
  sprintf(paste("Consumer prices in Kosova rose %s%% in %d, December to December. In the euro area: %s%%.",
                "A gap of %s percentage points."),
          u1(e$pi_XK_pp), EMPH, u1(e$pi_EA_pp), u1(e$gap_pp)),
  sprintf(paste("Kosova uses the euro without being part of the euro area. On annual averages, prices rose",
                "%s%% in Kosova against %s%% in the euro area; everything below uses December-to-December rates."),
          u1(aa_XK), u1(aa_EA)),
  "A gap like this can come from two places:",
  "",
  sprintf("1. How spending is split across the %d main consumption categories.", F$n_div),
  "2. Differences inside each category: what exactly is bought within it, and how those prices moved.",
  "",
  sprintf(paste("In %d the second part accounts for more than the whole gap: %s pp inside the categories,",
                "%s pp from the split across them. That holds under both ways of computing the decomposition."),
          EMPH, s1(e$within_mid_pp), s1(e$comp_mid_pp)),
  sprintf("Inside the categories, %s account for %s of the %s pp.",
          and_list(pname(t25$division)), pct(F$top3_share_2025), s1(e$within_mid_pp)),
  NOT_IDENTIFIED,
  sprintf(paste("Caveats: Eurostat has not fully evaluated whether Kosova's HICP meets its methodological",
                "requirements; it does not document the source year of Kosova's %d weights; and %d category",
                "data are back-calculated under the classification introduced in %d.",
                "Details and sensitivity checks: %s"),
          EMPH, EMPH, ECOICOP2_FROM, PIECE_URL),
  "Personal analysis, public data.")

# CLAUDE.md §1: the "not identified here" sentence is present verbatim; no forbidden causal wording
FORBIDDEN <- "\b(caus(e|es|ed|ing)|driv(e|es|en|ing)|leads? to|results? in|reduc(e|es|ed|ing)|boost(s|ed|ing)?|because of|the effect of|impacts?)\b"
stopifnot(sum(post == NOT_IDENTIFIED) == 1, grepl("is not identified here", NOT_IDENTIFIED, fixed = TRUE),
          !any(grepl(FORBIDDEN, post, ignore.case = TRUE)))
writeLines(post, file.path(PROJ, "output/linkedin_post.txt"))
cat(sprintf(paste("\npost guards: within-division A %.3f / B %.3f / mid %.3f vs gap %.3f | composition A %.3f /",
                  "B %.3f / mid %.3f | named top-three share mid %.3f / A %.3f / B %.3f\n"),
            e$within_A_pp, e$within_B_pp, e$within_mid_pp, e$gap_pp, e$comp_A_pp, e$comp_B_pp, e$comp_mid_pp,
            F$top3_share_2025, named_share["A"], named_share["B"]))

cat("wrote README.md (", length(L), "lines ), data/processed/figures.json, output/linkedin_post.txt\n")
