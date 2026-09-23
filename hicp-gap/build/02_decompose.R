# ==============================================================================
# 02_decompose.R
# Decomposes the Kosova minus euro-area HICP inflation gap, December to December
# within each weight year, at ECOICOP ver.2 division level (DESIGN.md §3).
# Requires build/01_gate.R to have passed on the same vintage.
#
# Reads (committed record of the verification pull):
#   data/raw/<date>/eurostat_prc_hicp_minr_XK_EA.rds   I25, RCH_MV12MAVR
#   data/raw/<date>/eurostat_prc_hicp_iw_XK_EA.rds     item weights
# Writes:
#   output/hicp_gap_decomposition.csv   one row per weight year, window mean, 2026 YTD
#   output/hicp_gap_within_top3.csv     pre-registered extension (DESIGN.md): top three
#                                       division contributions to the midpoint
#                                       within-division term, 2025 and 2026 YTD only,
#                                       with Eurostat COICOP18 division labels
#   YTD rows of both files carry a seasonality_caveat note (DESIGN.md limitations).
# Also reads: data/raw/<date>/eurostat_codelist_COICOP18_<version>.tsv
#   (from build/00_pull_coicop18_codelist.R)
#
# Per weight year t (2016-2025), in percentage points:
#   r_a,i = I25_a,i,Dec t / I25_a,i,Dec t-1 - 1;  s_a,i = weight / sum of 13 divisions
#   pi_a  = I25_a,TOTAL,Dec t / I25_a,TOTAL,Dec t-1 - 1;  R_a = pi_a - sum_i s_a,i r_a,i
#   gap   = pi_XK - pi_EA = composition + within-division + residual, where
#     midpoint:  comp = sum (sX - sE)(rX + rE)/2      within = sum (sX + sE)/2 (rX - rE)
#     variant A: comp = sum (sX - sE) rE              within = sum sX (rX - rE)
#     variant B: comp = sum (sX - sE) rX              within = sum sE (rX - rE)
#     residual = R_XK - R_EA (same in all three forms)
#     interaction = sum (sX - sE)(rX - rE) = comp_B - comp_A = within_A - within_B
#   offset_by_other: TRUE where the non-dominant term has the opposite sign to
#     the gap under both A and B; NA where no term dominates. Changes no verdict.
# "Within-division" mixes price differences for the same goods with differences
# in what each basket holds inside a division; the data cannot separate them.
#
# Reference column (NOT decomposed): published RCH_MV12MAVR, December value, per
# area-year, checked against the calendar-year average rate recomputed from I25
# (mean of 12 monthly indices, year t over year t-1) within rounding; stops if not.
#
# Rows: one per weight year 2016-2025; the window mean of every column (2016-2025
# only); a 2026 year-to-date row (Dec 2025 to the latest month), labelled and
# excluded from all averages. EA includes Bulgaria from January 2026.
#
# Dominance verdict (DESIGN.md §3), from variants A and B only, in this order:
#   composition / within-division: under BOTH A and B the term has the gap's sign
#     and |term| - |other| > 0.05 pp
#   offsetting: otherwise, terms of opposite sign under both A and B
#   tie:        otherwise, ||comp| - |within|| <= 0.05 pp under both A and B
#   range:      any other case (no dominance statement; report A-B range)
# Window verdict applies the same rule to the window means of A and of B.
#
# Run from the piece root:  Rscript build/02_decompose.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr)
}))
options(width = 250)

PROJ    <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
DIVS    <- sprintf("CP%02d", 1:13)
CODES   <- c("TOTAL", DIVS)
YEARS   <- 2016:2025
GATE_PP <- 0.05          # gate threshold, also the dominance margin (DESIGN.md)

# ------------------------------------------------------------------------------
# 0. Load
# ------------------------------------------------------------------------------
rds_name <- function(t) sprintf("eurostat_%s_XK_EA.rds", t)
dated <- sort(list.dirs(file.path(PROJ, "data/raw"), recursive = FALSE), decreasing = TRUE)
dated <- dated[grepl("^\\d{4}-\\d{2}-\\d{2}$", basename(dated)) &
               file.exists(file.path(dated, rds_name("prc_hicp_minr"))) &
               file.exists(file.path(dated, rds_name("prc_hicp_iw")))]
stopifnot(length(dated) >= 1)
raw_dir <- dated[1]
minr <- readRDS(file.path(raw_dir, rds_name("prc_hicp_minr")))
iw   <- readRDS(file.path(raw_dir, rds_name("prc_hicp_iw")))
cat("data:", raw_dir, "| Eurostat LAST UPDATE:",
    paste(unique(c(minr[["LAST UPDATE"]], iw[["LAST UPDATE"]])), collapse = " | "), "\n")

# Division labels: Eurostat COICOP18 codelist (build/00_pull_coicop18_codelist.R)
cl_f <- list.files(file.path(PROJ, "data/raw"), "^eurostat_codelist_COICOP18_.*\\.tsv$",
                   recursive = TRUE, full.names = TRUE)
stopifnot(length(cl_f) >= 1)
cl_f <- sort(cl_f, decreasing = TRUE)[1]
labels <- read_tsv(cl_f, col_names = c("code", "label"), col_types = "cc", progress = FALSE) |>
  filter(code %in% DIVS)
stopifnot(nrow(labels) == 13, setequal(labels$code, DIVS), !anyNA(labels$label))
cat("division labels:", basename(cl_f), "\n")

SEASONALITY_CAVEAT <- paste(
  "Dec to Aug, not a full seasonal cycle; division-level YTD contributions can",
  "reflect differing seasonal patterns between the areas (e.g. sales calendars)",
  "and are not reported in the piece. The YTD aggregate appears only with this caveat.")

ndec <- function(v) {
  v <- v[!is.na(v)]
  for (k in 0:6) if (all(abs(round(v, k) - v) < 1e-9)) return(k)
  stop("more than 6 decimals")
}

lv <- minr |>
  filter(unit == "I25", coicop18 %in% CODES) |>
  transmute(geo, code = coicop18, month = as.Date(paste0(time, "-01")),
            level = values, flag = OBS_FLAG)
stopifnot(!anyNA(lv$level))
h_idx <- 0.5 * 10^-ndec(lv$level)

w <- iw |>
  filter(coicop18 %in% DIVS, as.integer(time) %in% c(YEARS, 2026L)) |>
  transmute(geo, year = as.integer(time), code = coicop18, w = values) |>
  group_by(geo, year) |> mutate(s = w / sum(w)) |> ungroup()
stopifnot(nrow(w) == 2 * (length(YEARS) + 1) * 13)

# Latest month with all 14 codes for both areas
complete_m <- lv |> count(month) |> filter(n == 2 * length(CODES)) |> pull(month)
latest <- max(complete_m)
stopifnot(format(latest, "%Y") == "2026", latest > as.Date("2025-12-01"))
cat("latest complete month (both areas, all 14 codes):", format(latest, "%Y-%m"), "\n")

# ------------------------------------------------------------------------------
# 1. Decomposition per period
# ------------------------------------------------------------------------------
periods <- bind_rows(
  tibble(period = as.character(YEARS), type = "year", wyear = YEARS,
         base_m = as.Date(sprintf("%d-12-01", YEARS - 1)),
         end_m  = as.Date(sprintf("%d-12-01", YEARS))),
  tibble(period = sprintf("2026 YTD — cumulative Dec 2025→%s %s, %d months, not annual; provisional",
                          month.abb[as.integer(format(latest, "%m"))], format(latest, "%Y"),
                          as.integer(format(latest, "%m"))),   # months since Dec 2025
         type = "ytd_excluded_from_averages", wyear = 2026L,
         base_m = as.Date("2025-12-01"), end_m = latest))

decompose <- function(p) {
  b <- lv |> filter(month == p$base_m) |> select(geo, code, base = level, base_flag = flag)
  e <- lv |> filter(month == p$end_m)  |> select(geo, code, level, flag)
  x <- inner_join(b, e, by = c("geo", "code")) |> mutate(r = level / base - 1)
  stopifnot(nrow(x) == 2 * length(CODES))
  pi <- setNames(x$r[x$code == "TOTAL"], x$geo[x$code == "TOTAL"])
  d <- x |> filter(code %in% DIVS) |>
    inner_join(w |> filter(year == p$wyear) |> select(geo, code, s), by = c("geo", "code"))
  stopifnot(nrow(d) == 26)
  d <- d |> select(geo, code, s, r) |>
    pivot_wider(names_from = geo, values_from = c(s, r))
  stopifnot(nrow(d) == 13, !anyNA(d))
  with(d, {
    R_XK <- pi[["XK"]] - sum(s_XK * r_XK)
    R_EA <- pi[["EA"]] - sum(s_EA * r_EA)
    ea_u <- x |> filter(geo == "EA") |> summarise(any(flag %in% "u" | base_flag %in% "u")) |> pull()
    tibble(
      period = p$period, type = p$type,
      pi_XK_pp = 100 * pi[["XK"]], pi_EA_pp = 100 * pi[["EA"]],
      gap_pp = 100 * (pi[["XK"]] - pi[["EA"]]),
      comp_mid_pp   = 100 * sum((s_XK - s_EA) * (r_XK + r_EA) / 2),
      within_mid_pp = 100 * sum((s_XK + s_EA) / 2 * (r_XK - r_EA)),
      resid_pp      = 100 * (R_XK - R_EA),
      comp_A_pp     = 100 * sum((s_XK - s_EA) * r_EA),
      within_A_pp   = 100 * sum(s_XK * (r_XK - r_EA)),
      comp_B_pp     = 100 * sum((s_XK - s_EA) * r_XK),
      within_B_pp   = 100 * sum(s_EA * (r_XK - r_EA)),
      interaction_pp = 100 * sum((s_XK - s_EA) * (r_XK - r_EA)),
      R_XK_pp = 100 * R_XK, R_EA_pp = 100 * R_EA,
      ea_u_flag = ea_u,
      div_c = list(tibble(code, c_pp = 100 * (s_XK + s_EA) / 2 * (r_XK - r_EA))))
  })
}
tab <- bind_rows(lapply(split(periods, seq_len(nrow(periods))), decompose))
stopifnot(nrow(tab) == length(YEARS) + 1)

# Identities: each form adds up to the gap; midpoint = mean of A and B
stopifnot(all(abs(tab$gap_pp - (tab$comp_mid_pp + tab$within_mid_pp + tab$resid_pp)) < 1e-10),
          all(abs(tab$gap_pp - (tab$comp_A_pp   + tab$within_A_pp   + tab$resid_pp)) < 1e-10),
          all(abs(tab$gap_pp - (tab$comp_B_pp   + tab$within_B_pp   + tab$resid_pp)) < 1e-10),
          all(abs(tab$comp_mid_pp   - (tab$comp_A_pp   + tab$comp_B_pp)   / 2) < 1e-10),
          all(abs(tab$within_mid_pp - (tab$within_A_pp + tab$within_B_pp) / 2) < 1e-10),
          all(abs(tab$interaction_pp - (tab$comp_B_pp - tab$comp_A_pp)) < 1e-10),
          all(abs(tab$interaction_pp - (tab$within_A_pp - tab$within_B_pp)) < 1e-10),
          all(abs(vapply(tab$div_c, function(d) sum(d$c_pp), 0) - tab$within_mid_pp) < 1e-10))
# Per-area residual within the gate threshold (2016-2025 already gated; 2026 YTD is new)
stopifnot(all(abs(tab$R_XK_pp) <= GATE_PP), all(abs(tab$R_EA_pp) <= GATE_PP))
# u flags: DESIGN.md §2 expects exactly weight years 2020 and 2021 in the window
u_years <- tab$period[tab$type == "year" & tab$ea_u_flag]
cat("EA u-flag weight years:", paste(u_years, collapse = ", "), "\n")
stopifnot(identical(u_years, c("2020", "2021")))

# ------------------------------------------------------------------------------
# 2. Reference column: published annual-average rate (not decomposed)
# ------------------------------------------------------------------------------
mv <- minr |>
  filter(unit == "RCH_MV12MAVR", coicop18 == "TOTAL", substr(time, 6, 7) == "12") |>
  transmute(geo, year = as.integer(substr(time, 1, 4)), published_pp = values)
h_mv <- 0.5 * 10^-ndec(mv$published_pp)

avg <- lv |> filter(code == "TOTAL") |>
  mutate(year = as.integer(format(month, "%Y"))) |>
  filter(year %in% c(YEARS - 1L, YEARS)) |>
  group_by(geo, year) |> summarise(n = n(), A = mean(level), .groups = "drop")
stopifnot(all(avg$n == 12), nrow(avg) == 2 * (length(YEARS) + 1))
ref <- avg |> arrange(geo, year) |> group_by(geo) |>
  mutate(A_prev = lag(A)) |> ungroup() |> filter(year %in% YEARS) |>
  mutate(recomputed_pp = 100 * (A / A_prev - 1),
         # each 12-month mean of rounded indices is off by at most h
         bound_pp = h_mv + 100 * h_idx * (A + A_prev) / (A_prev * (A_prev - h_idx))) |>
  inner_join(mv, by = c("geo", "year")) |>
  mutate(diff_pp = recomputed_pp - published_pp)
stopifnot(nrow(ref) == 2 * length(YEARS))
cat(sprintf("\nreference check: RCH_MV12MAVR (December) vs calendar-year average rate from I25\n  max |diff| = %.4f pp | min bound = %.4f pp | breaches: %d of %d\n",
            max(abs(ref$diff_pp)), min(ref$bound_pp),
            sum(abs(ref$diff_pp) > ref$bound_pp), nrow(ref)))
if (any(abs(ref$diff_pp) > ref$bound_pp)) {
  print(as.data.frame(ref |> filter(abs(diff_pp) > bound_pp)), row.names = FALSE)
  stop("RCH_MV12MAVR December value does not match the calendar-year average rate within rounding. Stop and report.")
}
ref_w <- ref |> select(geo, year, published_pp) |>
  pivot_wider(names_from = geo, values_from = published_pp, names_prefix = "ref_aa_") |>
  transmute(period = as.character(year),
            ref_aa_XK_pp = ref_aa_XK, ref_aa_EA_pp = ref_aa_EA,
            ref_aa_gap_pp_not_decomposed = ref_aa_XK - ref_aa_EA)
tab <- tab |> left_join(ref_w, by = "period")
stopifnot(!anyNA(tab$ref_aa_gap_pp_not_decomposed[tab$type == "year"]))

# ------------------------------------------------------------------------------
# 3. Window means (2016-2025 only) and dominance verdicts
# ------------------------------------------------------------------------------
num_cols <- names(tab)[vapply(tab, is.numeric, logical(1))]
win <- tab |> filter(type == "year") |>
  summarise(across(all_of(num_cols), mean)) |>
  mutate(period = sprintf("window mean %d-%d", min(YEARS), max(YEARS)),
         type = "window_mean", ea_u_flag = NA)
stopifnot(sum(tab$type == "year") == length(YEARS))
tab <- bind_rows(tab |> filter(type == "year"), win, tab |> filter(type != "year"))

verdict <- function(cA, wA, cB, wB, gap, m = GATE_PP) {
  dom <- function(t, o) sign(t) == sign(gap) & (abs(t) - abs(o) > m)
  opp <- function(c, w) sign(c) * sign(w) < 0
  tie <- function(c, w) abs(abs(c) - abs(w)) <= m
  case_when(
    dom(cA, wA) & dom(cB, wB) ~ "composition",
    dom(wA, cA) & dom(wB, cB) ~ "within-division",
    opp(cA, wA) & opp(cB, wB) ~ "offsetting",
    tie(cA, wA) & tie(cB, wB) ~ "tie",
    TRUE                      ~ "range")
}
tab <- tab |> mutate(verdict = verdict(comp_A_pp, within_A_pp, comp_B_pp, within_B_pp, gap_pp))

# offset_by_other: the non-dominant term has the opposite sign to the gap under
# both variants. Defined only where a term dominates; NA otherwise. Changes no verdict.
against_gap <- function(t, gap) sign(t) * sign(gap) < 0
tab <- tab |> mutate(offset_by_other = case_when(
  verdict == "composition"     ~ against_gap(within_A_pp, gap_pp) & against_gap(within_B_pp, gap_pp),
  verdict == "within-division" ~ against_gap(comp_A_pp, gap_pp)   & against_gap(comp_B_pp, gap_pp),
  TRUE ~ NA))

# ------------------------------------------------------------------------------
# 4. Save and print
# ------------------------------------------------------------------------------
out <- tab |> select(period, type, pi_XK_pp, pi_EA_pp, gap_pp,
                     comp_mid_pp, within_mid_pp, resid_pp,
                     comp_A_pp, within_A_pp, comp_B_pp, within_B_pp, interaction_pp,
                     ref_aa_XK_pp, ref_aa_EA_pp, ref_aa_gap_pp_not_decomposed,
                     ea_u_flag, verdict, offset_by_other) |>
  mutate(seasonality_caveat = if_else(type == "ytd_excluded_from_averages",
                                      SEASONALITY_CAVEAT, NA_character_))
stopifnot(nrow(out) == length(YEARS) + 2)
dir.create(file.path(PROJ, "output"), showWarnings = FALSE)
out_f <- file.path(PROJ, "output/hicp_gap_decomposition.csv")
write_csv(out |> mutate(across(where(is.numeric), ~ round(.x, 6))), out_f, na = "")
cat("\nwrote", out_f, "\n\n")

print(as.data.frame(out |> mutate(across(where(is.numeric), ~ round(.x, 3)))), row.names = FALSE)

# ------------------------------------------------------------------------------
# 5. Pre-registered extension (DESIGN.md): top-three division contributions to
#    the midpoint within-division term, 2025 and 2026 YTD only. Ranked in the
#    direction of the term's sign. Only the top three are reported or saved.
# ------------------------------------------------------------------------------
ext <- tab |> filter(period == "2025" | type == "ytd_excluded_from_averages")
stopifnot(nrow(ext) == 2)
top3 <- bind_rows(lapply(seq_len(nrow(ext)), function(k) {
  e <- ext[k, ]
  dir <- sign(e$within_mid_pp)
  stopifnot(dir != 0)
  e$div_c[[1]] |> arrange(desc(dir * c_pp)) |> slice_head(n = 3) |>
    transmute(period = e$period, type = e$type, rank = row_number(), division = code,
              contribution_pp = c_pp, within_mid_pp = e$within_mid_pp,
              top3_combined_share = sum(c_pp) / e$within_mid_pp)
}))
stopifnot(nrow(top3) == 6)
top3 <- top3 |>
  left_join(labels |> rename(division = code, division_label = label), by = "division") |>
  mutate(seasonality_caveat = if_else(type == "ytd_excluded_from_averages",
                                      SEASONALITY_CAVEAT, NA_character_)) |>
  select(period, rank, division, division_label, contribution_pp, within_mid_pp,
         top3_combined_share, seasonality_caveat)
stopifnot(nrow(top3) == 6, !anyNA(top3$division_label))
top3_f <- file.path(PROJ, "output/hicp_gap_within_top3.csv")
write_csv(top3 |> mutate(across(where(is.numeric), ~ round(.x, 6))), top3_f, na = "")
cat("\nwrote", top3_f, "\n\n")
print(as.data.frame(top3 |> mutate(across(c(contribution_pp, within_mid_pp), ~ round(.x, 3)),
                                   top3_combined_share = round(top3_combined_share, 4))),
      row.names = FALSE)
