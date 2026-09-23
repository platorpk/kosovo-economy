# ==============================================================================
# 01_gate.R  --  GATE ONLY (DESIGN.md §3). No decomposition terms.
# Tests whether the December-link, within-weight-year design closes on the
# published data, before any decomposition is computed.
#
# Reads (committed record of the verification pull, verify/01_coverage.R):
#   data/raw/<date>/eurostat_prc_hicp_minr_XK_EA.rds   HICP monthly (I15, I25, RCH_A)
#   data/raw/<date>/eurostat_prc_hicp_iw_XK_EA.rds     HICP item weights
# Writes nothing. Prints the gate report and errors if the gate fails.
#
# Checks, weight years 2016-2025, geo XK and EA, all-items = coicop18 TOTAL:
#   (a) aggregation identity, every month m of weight year t:
#       R = I_TOTAL,m / I_TOTAL,Dec t-1  -  sum_i s_i * I_i,m / I_i,Dec t-1
#       with s_i = year-t division weight / sum of the 13 division weights.
#   (b) derived December-to-December all-items rate vs published RCH_A (December).
#   (c) I15 vs I25: December-to-December rates agree within index rounding,
#       all 13 divisions + TOTAL (hard assertion).
# Gate thresholds (DESIGN.md §3):
#   (a) |R| <= 0.05 pp in every area-month; the computed bound is shown alongside.
#   (b) |derived - published| <= the computed rounding bound for that area-year.
#       Amended after the first run (2026-09-23 vintage): (b) originally used
#       0.05 pp, which RCH_A's 1-decimal rounding alone can exceed. That run
#       passed 0.05 pp for every area-year (max 0.041 pp); outcome unchanged.
# Rounding bounds per area-year, computed from the actual index levels and
# published decimals:
#   index ratio L/B with both rounded to +-h:  |error| <= h (B + L) / (B (B - h))
#   share s = w / W with w rounded to +-hw:     |error| <= hw (1 + 13 s) / (W - 13 hw)
#   (a) bound = TOTAL ratio error + sum_i s_i * ratio error_i + sum_i share error_i * |x_i - 1|
#       (the share term uses |x_i - 1| because shares sum to exactly 1)
#   (b) bound = half a unit of RCH_A's published decimals + TOTAL ratio error
#
# Run from the piece root:  Rscript build/01_gate.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr)
}))
options(width = 200, pillar.sigfig = 6)

PROJ    <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
GEOS    <- c("XK", "EA")
DIVS    <- sprintf("CP%02d", 1:13)
CODES   <- c("TOTAL", DIVS)
YEARS   <- 2016:2025
GATE_PP <- 0.05

# ------------------------------------------------------------------------------
# 0. Load the committed filtered pulls (latest date folder holding both)
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

ndec <- function(v) {                     # published decimals, read from the data
  v <- v[!is.na(v)]
  for (k in 0:6) if (all(abs(round(v, k) - v) < 1e-9)) return(k)
  stop("more than 6 decimals")
}
ratio_err <- function(level, base, h) h * (base + level) / (base * (base - h))

# ------------------------------------------------------------------------------
# 1. Inputs: index levels, weights as shares, published decimals
# ------------------------------------------------------------------------------
idx <- minr |>
  filter(unit %in% c("I15", "I25"), coicop18 %in% CODES) |>
  transmute(geo, unit, code = coicop18, month = as.Date(paste0(time, "-01")),
            year = as.integer(format(month, "%Y")), mm = as.integer(format(month, "%m")),
            level = values, flag = OBS_FLAG)
stopifnot(!anyNA(idx$level), !anyNA(idx$month))

idx_dec <- idx |> group_by(geo, unit) |> summarise(decimals = ndec(level), .groups = "drop") |>
  mutate(h = 0.5 * 10^-decimals)
cat("\nindex decimals (published):\n"); print(as.data.frame(idx_dec), row.names = FALSE)
idx <- idx |> left_join(idx_dec |> select(geo, unit, h), by = c("geo", "unit"))
stopifnot(!anyNA(idx$h))

w <- iw |>
  filter(coicop18 %in% DIVS, as.integer(time) %in% YEARS) |>
  transmute(geo, year = as.integer(time), code = coicop18, w = values)
stopifnot(nrow(w) == length(GEOS) * length(YEARS) * 13, !anyNA(w$w))
w_dec <- w |> group_by(geo) |> summarise(decimals = ndec(w), .groups = "drop") |>
  mutate(hw = 0.5 * 10^-decimals)
cat("\nweight decimals (published, division weights 2016-2025):\n")
print(as.data.frame(w_dec), row.names = FALSE)
w <- w |> left_join(w_dec |> select(geo, hw), by = "geo") |>
  group_by(geo, year) |>
  mutate(W = sum(w), s = w / W, s_err = hw * (1 + 13 * s) / (W - 13 * hw)) |>
  ungroup()
stopifnot(all(abs(tapply(w$s, paste(w$geo, w$year), sum) - 1) < 1e-12))

# Month m of weight year t against December of t-1, per geo x unit x code
rel_dec <- function(u) {
  lv   <- idx |> filter(unit == u)
  base <- lv |> filter(mm == 12) |>
    transmute(geo, code, year = year + 1L, base = level, base_flag = flag)
  out  <- lv |> filter(year %in% YEARS) |>
    inner_join(base, by = c("geo", "code", "year")) |>
    mutate(x = level / base, x_err = ratio_err(level, base, h))
  stopifnot(nrow(out) == length(GEOS) * length(YEARS) * 12 * length(CODES))
  out
}
r25 <- rel_dec("I25")

# ------------------------------------------------------------------------------
# 2. Check (a): aggregation identity, every month
# ------------------------------------------------------------------------------
div <- r25 |> filter(code %in% DIVS) |>
  inner_join(w |> select(geo, year, code, s, s_err), by = c("geo", "year", "code"))
stopifnot(nrow(div) == length(GEOS) * length(YEARS) * 12 * 13)

agg <- div |> group_by(geo, year, month) |>
  summarise(n = n(), sx = sum(s * x), b_idx = sum(s * x_err),
            b_w = sum(s_err * abs(x - 1)), .groups = "drop")
stopifnot(all(agg$n == 13))

chk_a <- r25 |> filter(code == "TOTAL") |>
  select(geo, year, month, x_tot = x, e_tot = x_err) |>
  inner_join(agg, by = c("geo", "year", "month")) |>
  mutate(R_pp = 100 * (x_tot - sx), bound_pp = 100 * (e_tot + b_idx + b_w))
stopifnot(nrow(chk_a) == length(GEOS) * length(YEARS) * 12)

sum_a <- chk_a |> group_by(geo, year) |>
  summarise(max_abs_R_pp = max(abs(R_pp)),
            at_month     = format(month[which.max(abs(R_pp))], "%Y-%m"),
            max_bound_pp = max(bound_pp),
            n_over_gate  = sum(abs(R_pp) > GATE_PP),
            n_over_bound = sum(abs(R_pp) > bound_pp), .groups = "drop")

cat("\n== (a) Aggregation identity, all 12 months per weight year (pp) ==\n")
print(as.data.frame(sum_a |> mutate(across(c(max_abs_R_pp, max_bound_pp), ~ round(.x, 4)))),
      row.names = FALSE)

breach_a <- chk_a |> filter(abs(R_pp) > GATE_PP) |> arrange(geo, month)
cat(sprintf("\n  (a) breaches of the %.2f pp gate: %d of %d area-months\n",
            GATE_PP, nrow(breach_a), nrow(chk_a)))
over_a <- chk_a |> filter(abs(R_pp) > bound_pp)
cat(sprintf("  (a) area-months above their computed rounding bound: %d\n", nrow(over_a)))

if (nrow(breach_a)) {
  cat("\n  Breach list, with division context (index relative to December t-1):\n")
  for (k in seq_len(nrow(breach_a))) {
    b <- breach_a[k, ]
    cat(sprintf("\n  -- %s %s (weight year %d): R = %.4f pp, bound = %.4f pp\n",
                b$geo, format(b$month, "%Y-%m"), b$year, b$R_pp, b$bound_pp))
    ctx <- div |> filter(geo == b$geo, month == b$month) |>
      transmute(code, share = round(s, 5), base_dec = base, level,
                rel_pp = round(100 * (x - 1), 3), base_flag, flag,
                share_x_rel_pp = round(100 * s * (x - 1), 4)) |> arrange(code)
    print(as.data.frame(ctx), row.names = FALSE)
  }
}

# ------------------------------------------------------------------------------
# 3. Check (b): December derived vs published RCH_A
# ------------------------------------------------------------------------------
rch <- minr |> filter(unit == "RCH_A", coicop18 == "TOTAL") |>
  transmute(geo, year = as.integer(substr(time, 1, 4)), mm = substr(time, 6, 7),
            published_pp = values)
rch_h <- 0.5 * 10^-ndec(rch$published_pp)
cat(sprintf("\n  RCH_A published decimals: %d (half-unit %.3f pp)\n", ndec(rch$published_pp), rch_h))

chk_b <- chk_a |> filter(format(month, "%m") == "12") |>
  transmute(geo, year, derived_pp = 100 * (x_tot - 1), e_tot) |>
  inner_join(rch |> filter(mm == "12") |> select(-mm), by = c("geo", "year")) |>
  mutate(diff_pp = derived_pp - published_pp, bound_pp = rch_h + 100 * e_tot)
stopifnot(nrow(chk_b) == length(GEOS) * length(YEARS), !anyNA(chk_b$published_pp))

cat("\n== (b) December-to-December all-items: derived vs published RCH_A (pp) ==\n")
print(as.data.frame(chk_b |> arrange(geo, year) |>
  transmute(geo, year, derived_pp = round(derived_pp, 4), published_pp,
            abs_diff_pp = round(abs(diff_pp), 4), bound_pp = round(bound_pp, 4),
            over_bound = abs(diff_pp) > bound_pp)),
  row.names = FALSE)
breach_b <- chk_b |> filter(abs(diff_pp) > bound_pp)     # gate (b): computed bound
cat(sprintf("\n  (b) breaches of the computed rounding bound: %d of %d area-years\n",
            nrow(breach_b), nrow(chk_b)))
cat(sprintf("  (b) area-years above the original 0.05 pp threshold (pre-amendment, info only): %d\n",
            sum(abs(chk_b$diff_pp) > GATE_PP)))

# ------------------------------------------------------------------------------
# 4. Check (c): I15 vs I25 December-to-December rates (hard assertion)
# ------------------------------------------------------------------------------
dd <- function(u) rel_dec(u) |> filter(mm == 12) |> select(geo, code, year, x, x_err)
cmp <- inner_join(dd("I15"), dd("I25"), by = c("geo", "code", "year"), suffix = c("15", "25")) |>
  mutate(diff_pp = 100 * (x15 - x25), tol_pp = 100 * (x_err15 + x_err25))
stopifnot(nrow(cmp) == length(GEOS) * length(CODES) * length(YEARS))
cat("\n== (c) I15 vs I25 December-to-December rates, 13 divisions + TOTAL ==\n")
cat(sprintf("  comparisons: %d | max |diff| = %.4f pp | min slack (tol - |diff|) = %.4f pp | over tolerance: %d\n",
            nrow(cmp), max(abs(cmp$diff_pp)), min(cmp$tol_pp - abs(cmp$diff_pp)),
            sum(abs(cmp$diff_pp) > cmp$tol_pp)))
if (any(abs(cmp$diff_pp) > cmp$tol_pp))
  print(as.data.frame(cmp |> filter(abs(diff_pp) > tol_pp)), row.names = FALSE)
stopifnot(all(abs(cmp$diff_pp) <= cmp$tol_pp))

# ------------------------------------------------------------------------------
# 5. Verdict
# ------------------------------------------------------------------------------
cat("\n== GATE ==\n")
cat(sprintf("  (a) max |R| over all area-months: %.4f pp (gate %.2f)\n", max(abs(chk_a$R_pp)), GATE_PP))
cat(sprintf("  (b) max |diff| over all area-years: %.4f pp (gate: computed bound, min %.4f pp)\n",
            max(abs(chk_b$diff_pp)), min(chk_b$bound_pp)))
if (nrow(breach_a) || nrow(breach_b))
  stop(sprintf("GATE FAILED: %d (a) breaches, %d (b) breaches. Stop and report.",
               nrow(breach_a), nrow(breach_b)))
cat("  GATE PASSED\n")
