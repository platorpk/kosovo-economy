# ==============================================================================
# 04_contributions.R  --  VERIFICATION ONLY (a check, not a decomposition)
# Exact contributions to the annual rate of an annually chain-linked HICP
# (December link; Ribe method), applied to the 13 ECOICOP ver.2 divisions on the
# 2025=100 index (I25). Tests whether the division contributions sum to the
# all-items annual rate within the rounding of the published inputs, per geo.
#
# Reads the committed filtered record written by verify/02_peers.R:
#   data/raw/2026-09-23/eurostat_prc_hicp_minr_WB_EA.rds  (prc_hicp_minr, I25, RCH_A)
#   data/raw/2026-09-23/eurostat_prc_hicp_iw_WB_EA.rds    (prc_hicp_iw, item weights)
#   verify/peers_aggregation_residuals.csv                 (V1-V3, for comparison)
# Writes:
#   verify/contrib_residuals.csv           one row per geo-month
#   verify/contrib_tables_generated.md     every table in followup_report.md section 2
#
# Formula, month m of year t, division i, all-items index I, division index I_i:
#   C_i = 100 * [ s_i(t-1) * (I_i(Dec,t-1) - I_i(m,t-1)) / I_i(Dec,t-2) * I(Dec,t-2) / I(m,t-1)
#               + s_i(t)   * (I_i(m,t)     - I_i(Dec,t-1)) / I_i(Dec,t-1) * I(Dec,t-1) / I(m,t-1) ]
#   s_i(y) = year-y item weight / sum of the 13 division weights of year y (the
#   DESIGN.md normalisation); the /1000 alternative is reported as one number.
#   sum_i C_i equals 100 * (I(m,t) / I(m,t-1) - 1) exactly when the all-items
#   index is the December-linked Laspeyres aggregate of the divisions.
#   For m = Dec the first term is zero (I_i(m,t-1) = I_i(Dec,t-1)).
# Residuals:
#   R_der = sum_i C_i - YoY derived from the I25 TOTAL index
#   R_pub = sum_i C_i - published RCH_A
# Rounding bound, per geo-month: first-order worst-case propagation,
#   sum_k |dR/dx_k| * h_k over every distinct published input x_k, with h_k half a
#   unit of that series' last significant published decimal (index levels, item
#   weights; plus RCH_A for R_pub). Derivatives by central differences. For
#   m = Dec, I(m,t-1) and I(Dec,t-1) are the same observation and enter once.
#   Second-order terms are neglected (relative size ~ h / I, about 1e-4).
# Gate (Plator, 2026-09-29): |R| <= bound in every geo-month, no tolerance, for
#   both residuals. On breach the script writes every table, including breaches
#   by year and before/from 2026, and then stops with an error.
#
# Run from the piece root:  Rscript verify/04_contributions.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(tidyr); library(stringr); library(purrr)
}))
options(width = 200, dplyr.summarise.inform = FALSE)

PROJ <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
VER  <- file.path(PROJ, "verify")
GEOS <- c("XK", "ME", "RS", "AL", "MK", "EA")
DIVS <- sprintf("CP%02d", 1:13)
WIN  <- c("2021-01", "2023-12")
FLAG_BOUND_PP <- 0.05

tm <- function(time) as.integer(substr(time, 1, 4)) * 12L + as.integer(substr(time, 6, 7)) - 1L
fm <- function(mi) sprintf("%04d-%02d", mi %/% 12L, mi %% 12L + 1L)
f3 <- function(x, d = 3) formatC(x, format = "f", digits = d)
sig_dec <- function(chr) { x <- str_remove(str_extract(chr, "(?<=\\.)\\d+$"), "0+$"); max(c(0L, nchar(x)), na.rm = TRUE) }
md <- character(); md_add <- function(...) md <<- c(md, ...)
md_table <- function(df) {
  df <- as.data.frame(df); df[] <- lapply(df, function(x) { x <- as.character(x); x[is.na(x)] <- ""; x })
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")), "")
}
show <- function(df, title) { cat("\n--", title, "--\n"); print(as.data.frame(df), row.names = FALSE) }

# ------------------------------------------------------------------------------
# Core: sum of contributions S and derived all-items YoY Y from one month's
# inputs, laid out as p = (a[13], b[13], c[13], d[13], A, B, C, D, w1[13], w2[13])
#   a = I_i(m,t)  b = I_i(Dec,t-1)  c = I_i(m,t-1)  d = I_i(Dec,t-2); A-D the same for TOTAL
# ------------------------------------------------------------------------------
IX <- list(a = 1:13, b = 14:26, c = 27:39, d = 40:52, A = 53, B = 54, C = 55, D = 56,
           w1 = 57:69, w2 = 70:82)
ribe <- function(p, dec, norm = "sum") {
  a <- p[IX$a]; b <- p[IX$b]; d <- p[IX$d]; A <- p[IX$A]; B <- p[IX$B]; D <- p[IX$D]
  c <- if (dec) b else p[IX$c]
  C <- if (dec) B else p[IX$C]
  s1 <- if (norm == "sum") p[IX$w1] / sum(p[IX$w1]) else p[IX$w1] / 1000
  s2 <- if (norm == "sum") p[IX$w2] / sum(p[IX$w2]) else p[IX$w2] / 1000
  C_i <- 100 * (s1 * (b - c) / d * D / C + s2 * (a - b) / b * B / C)
  list(S = sum(C_i), Y = 100 * (A / C - 1), C_i = C_i)
}
grad <- function(p, dec, which) {   # central differences of S or Y w.r.t. every input
  vapply(seq_along(p), function(k) {
    e <- 1e-6 * max(1, abs(p[k])); up <- p; dn <- p; up[k] <- p[k] + e; dn[k] <- p[k] - e
    (ribe(up, dec)[[which]] - ribe(dn, dec)[[which]]) / (2 * e)
  }, numeric(1))
}

# ------------------------------------------------------------------------------
# 0. Self-test on synthetic exact data: an all-items index built by December-
#    linked Laspeyres from random division indices must give R = 0 to machine
#    precision in every month, including December. Checks the implementation,
#    not the data.
# ------------------------------------------------------------------------------
set.seed(20260929)
syn <- matrix(100 * exp(apply(matrix(rnorm(13 * 37, 0.003, 0.02), 37), 2, cumsum)), 37)  # rows: Dec t-2, then 36 months
w_y1 <- runif(13, 5, 200); w_y2 <- runif(13, 5, 200)
tot <- numeric(37); tot[1] <- 100
for (r in 2:13)  tot[r] <- tot[1]  * sum(w_y1 / sum(w_y1) * syn[r, ] / syn[1, ])    # year t-1, linked at Dec t-2
for (r in 14:37) { yr0 <- if (r <= 25) 13 else 25; ws <- if (r <= 25) w_y2 else w_y1
                   tot[r] <- tot[yr0] * sum(ws / sum(ws) * syn[r, ] / syn[yr0, ]) }        # year t (rows 14-25), then t+1
self <- map_dbl(14:25, function(r) {   # months of year t (rows 14-25); Dec t-1 = row 13, Dec t-2 = row 1
  dec <- r == 25
  p <- c(syn[r, ], syn[13, ], syn[r - 12, ], syn[1, ], tot[r], tot[13], tot[r - 12], tot[1], w_y1, w_y2)
  o <- ribe(p, dec); o$S - o$Y
})
cat("self-test: max |R| on synthetic exact data =", format(max(abs(self)), digits = 3), "pp\n")
stopifnot(max(abs(self)) < 1e-9)

# ------------------------------------------------------------------------------
# 1. Inputs
# ------------------------------------------------------------------------------
minr <- readRDS(file.path(PROJ, "data/raw/2026-09-23/eurostat_prc_hicp_minr_WB_EA.rds"))
iw   <- readRDS(file.path(PROJ, "data/raw/2026-09-23/eurostat_prc_hicp_iw_WB_EA.rds"))
lu <- unique(c(minr[["LAST UPDATE"]], iw[["LAST UPDATE"]])); stopifnot(length(lu) == 1)
cat("Eurostat LAST UPDATE:", lu, "\n")

I <- minr |> filter(unit == "I25", coicop18 %in% c("TOTAL", DIVS), geo %in% GEOS, !is.na(values)) |>
  transmute(geo, code = coicop18, mi = tm(time), v = values, chr = values_chr)
h_idx <- I |> group_by(geo, code) |> summarise(dec = sig_dec(chr)) |> mutate(h = 0.5 * 10^-dec)
show(h_idx |> group_by(geo) |> summarise(decimals = paste(sort(unique(dec)), collapse = ",")), "I25 significant decimals (TOTAL + 13 divisions)")
W <- iw |> filter(coicop18 %in% DIVS, geo %in% GEOS, !is.na(values)) |>
  transmute(geo, code = coicop18, year = as.integer(time), w = values, chr = values_chr)
# Weight precision per geo-year, from all item weights of that geo-year (divisions alone are
# 13 values and could end in 0 by chance). Run 1 used one precision per geo (2 decimals
# everywhere) and also passed; see verify/contrib_run1_per_geo_weight_precision.log.
h_w <- iw |> filter(geo %in% GEOS, !is.na(values)) |> mutate(year = as.integer(time)) |>
  group_by(geo, year) |> summarise(n_items = n(), dec = sig_dec(values_chr)) |> mutate(hw = 0.5 * 10^-dec)
show(h_w |> count(geo, dec), "item-weight significant decimals, number of geo-years")
w_1dec <- h_w |> filter(dec < 2) |> group_by(geo) |> summarise(years = paste(year, collapse = ", "))
show(w_1dec, "geo-years whose item weights carry no nonzero second decimal")
rch <- minr |> filter(unit == "RCH_A", coicop18 == "TOTAL", geo %in% GEOS, !is.na(values)) |>
  transmute(geo, mi = tm(time), rch = values, chr = values_chr)
h_r <- rch |> group_by(geo) |> summarise(dec_r = sig_dec(chr)) |> mutate(hr = 0.5 * 10^-dec_r)
show(h_r, "RCH_A TOTAL significant decimals")

months <- I |> filter(code == "TOTAL") |> distinct(geo, mi)

one_geo <- function(g) {
  idx <- lapply(c("TOTAL", DIVS), function(cd) { x <- I[I$geo == g & I$code == cd, ]; setNames(x$v, x$mi) })
  names(idx) <- c("TOTAL", DIVS)
  ix <- function(cd, mi) unname(idx[[cd]][as.character(mi)])
  hv <- setNames(h_idx$h[h_idx$geo == g], h_idx$code[h_idx$geo == g])
  hwy <- function(y) { v <- h_w$hw[h_w$geo == g & h_w$year == y]; stopifnot(length(v) == 1); v }
  wy <- W[W$geo == g, ]
  wv <- function(y) { x <- wy[wy$year == y, ]; unname(setNames(x$w, x$code)[DIVS]) }
  out <- map_dfr(months$mi[months$geo == g], function(mi) {
    t <- mi %/% 12L; m <- mi %% 12L + 1L; dec <- m == 12L
    kb <- 12L * (t - 1L) + 11L; kc <- mi - 12L; kd <- 12L * (t - 2L) + 11L
    p <- c(vapply(DIVS, ix, 0, mi = mi), vapply(DIVS, ix, 0, mi = kb), vapply(DIVS, ix, 0, mi = kc),
           vapply(DIVS, ix, 0, mi = kd), ix("TOTAL", mi), ix("TOTAL", kb), ix("TOTAL", kc), ix("TOTAL", kd),
           wv(t - 1L), wv(t))
    if (length(p) != 82 || anyNA(p)) return(NULL)
    h <- c(rep(hv[DIVS], 4), rep(hv[["TOTAL"]], 4), rep(hwy(t - 1L), 13), rep(hwy(t), 13))
    o <- ribe(p, dec); o1000 <- ribe(p, dec, norm = "1000")
    gS <- grad(p, dec, "S"); gY <- grad(p, dec, "Y")
    tibble(geo = g, mi = mi, S = o$S, Y = o$Y, R_der = o$S - o$Y, R_der_1000 = o1000$S - o$Y,
           bound_der = sum(abs(gS - gY) * h), bound_pub_ex_rch = sum(abs(gS) * h))
  })
  out
}
res <- map_dfr(GEOS, one_geo) |>
  left_join(rch |> select(geo, mi, rch), by = c("geo", "mi")) |> left_join(h_r, by = "geo") |>
  mutate(R_pub = S - rch, bound_pub = bound_pub_ex_rch + hr,
         ratio_der = abs(R_der) / bound_der, ratio_pub = abs(R_pub) / bound_pub,
         breach_der = abs(R_der) > bound_der, breach_pub = !is.na(R_pub) & abs(R_pub) > bound_pub,
         month = fm(mi), year = mi %/% 12L)
stopifnot(!anyNA(res$R_der), all(res$bound_der > 0))
spans <- res |> group_by(geo) |> summarise(first = fm(min(mi)), last = fm(max(mi)), n = n(),
                                           contiguous = n == max(mi) - min(mi) + 1L,
                                           n_with_RCH_A = sum(!is.na(rch))) |> slice(match(GEOS, geo))
show(spans, "months computed (all 82 inputs present)")
stopifnot(all(spans$contiguous))
write_csv(res |> transmute(geo, month, sum_contrib = S, yoy_I25_total = Y, RCH_A = rch, R_der, bound_der,
                           ratio_der, R_pub, bound_pub, ratio_pub, R_der_norm1000 = R_der_1000),
          file.path(VER, "contrib_residuals.csv"))

# ------------------------------------------------------------------------------
# 2. Distributions: residuals, bounds, |R| / bound; whole span and 2021-23
# ------------------------------------------------------------------------------
in_win <- function(d) d |> filter(mi >= tm(WIN[1]), mi <= tm(WIN[2]))
rdist <- function(x) tibble(n = length(x), min = f3(min(x)), p10 = f3(quantile(x, .1)), median = f3(median(x)),
                            p90 = f3(quantile(x, .9)), max = f3(max(x)), max_abs = f3(max(abs(x))))
long <- bind_rows(res |> transmute(geo, mi, residual = "R_der (vs I25 TOTAL YoY)", R = R_der, bound = bound_der),
                  res |> filter(!is.na(R_pub)) |> transmute(geo, mi, residual = "R_pub (vs RCH_A)", R = R_pub, bound = bound_pub))
dist_tab <- function(d) d |> group_by(residual, geo) |>
  reframe(months = sprintf("%s..%s", fm(min(mi)), fm(max(mi))), rdist(R)) |>
  arrange(residual, match(geo, GEOS))
bound_tab <- function(d) d |> group_by(residual, geo) |>
  summarise(n = n(), bound_min = f3(min(bound)), bound_median = f3(median(bound)), bound_p90 = f3(quantile(bound, .9)),
            bound_max = f3(max(bound)), flag_median_bound_gt_0.05 = median(bound) > FLAG_BOUND_PP,
            ratio_median = f3(median(abs(R) / bound), 2), ratio_p90 = f3(quantile(abs(R) / bound, .9), 2),
            ratio_max = f3(max(abs(R) / bound), 2), n_breach = sum(abs(R) > bound)) |>
  arrange(residual, match(geo, GEOS))
d_full <- dist_tab(long); d_win <- dist_tab(in_win(long))
b_full <- bound_tab(long); b_win <- bound_tab(in_win(long))
show(d_full, "residual distribution, whole span (pp)"); show(d_win, "residual distribution, 2021-01..2023-12 (pp)")
show(b_full, "bound and |R|/bound, whole span"); show(b_win, "bound and |R|/bound, 2021-01..2023-12")
norm_eff <- max(abs(res$R_der_1000 - res$R_der))
cat(sprintf("max |effect of /1000 instead of /sum(w)| on R_der: %.4f pp\n", norm_eff))

# Comparison with V1-V3 of 02_peers.R (same distribution statistics)
v <- read_csv(file.path(VER, "peers_aggregation_residuals.csv"), show_col_types = FALSE) |> mutate(mi = tm(month))
cmp_one <- function(dv, dr) bind_rows(
  dv |> group_by(method = variant, geo) |> reframe(months = sprintf("%s..%s", fm(min(mi)), fm(max(mi))), rdist(residual)),
  dr |> mutate(method = ifelse(grepl("^R_der", residual), "Ribe, vs I25 TOTAL YoY", "Ribe, vs RCH_A")) |>
    group_by(method, geo) |> reframe(months = sprintf("%s..%s", fm(min(mi)), fm(max(mi))), rdist(R))) |>
  arrange(match(geo, GEOS), method) |> select(geo, method, months, n, min, p10, median, p90, max, max_abs)
cmp_full <- cmp_one(v, long); cmp_win <- cmp_one(in_win(v), in_win(long))
show(cmp_full |> select(geo, method, n, p10, p90, max_abs), "comparison with V1-V3, whole span")

# ------------------------------------------------------------------------------
# 3. Gate: every |R| <= bound. Breach tables are written before stopping.
# ------------------------------------------------------------------------------
br <- long |> filter(abs(R) > bound) |> mutate(year = mi %/% 12L, ratio = abs(R) / bound)
n_breach <- nrow(br)
md_add("# Generated tables: 04_contributions.R", "",
       sprintf("Eurostat LAST UPDATE %s (`prc_hicp_minr`, `prc_hicp_iw`, filtered record `*_WB_EA.rds`). Index: I25 (2025=100).", lu), "",
       sprintf("Self-test on synthetic exact December-linked data: max |R| = %s pp (must be < 1e-9).", format(max(abs(self)), digits = 3)), "",
       "## 2a. Months computed (all 13 divisions and TOTAL at the four dates, weights of t-1 and t)", "", md_table(spans),
       "Significant decimals used for the rounding half-units:", "",
       md_table(h_idx |> group_by(geo) |> summarise(I25_decimals = paste(sort(unique(dec)), collapse = ",")) |>
                  left_join(h_w |> group_by(geo) |> summarise(weight_decimals = paste(sort(unique(dec)), collapse = ",")), by = "geo") |>
                  left_join(h_r |> select(geo, RCH_A_decimals = dec_r), by = "geo") |> slice(match(GEOS, geo))),
       "Geo-years whose item weights (all codes) carry no nonzero second decimal; their half-unit is 0.05:", "",
       md_table(w_1dec),
       "## 2b. Residual distribution, whole span (pp)", "", md_table(d_full),
       "## 2c. Residual distribution, 2021-01..2023-12 (pp)", "", md_table(d_win),
       sprintf("## 2d. Computed rounding bound (pp) and |R| / bound, whole span. Flag = median bound > %.2f pp.", FLAG_BOUND_PP), "",
       md_table(b_full), "## 2e. Same, 2021-01..2023-12", "", md_table(b_win),
       sprintf("Largest absolute change in R_der from dividing by 1000 instead of sum(w): %.4f pp.", norm_eff), "",
       "## 2f. Comparison with V1-V3 (`peers_aggregation_residuals.csv`), whole span (pp)", "",
       "V1 = published RCH_A, weights of t; V2 = YoY derived from I15, weights of t; V3 = published RCH_A, weights of t-1.",
       "Spans differ: the exact formula needs I(Dec, t-2) and the weights of t-1, so it starts later.", "", md_table(cmp_full),
       "## 2g. Same, 2021-01..2023-12 (pp)", "", md_table(cmp_win),
       sprintf("## 2h. Gate: |R| <= bound in every geo-month, both residuals, no tolerance. Breaches: %d.", n_breach), "")
if (n_breach > 0) {
  by_year <- br |> group_by(residual, geo, year) |>
    summarise(n_breach = n(), max_abs_R = f3(max(abs(R))), max_ratio = f3(max(ratio), 2)) |>
    left_join(long |> mutate(year = mi %/% 12L) |> count(residual, geo, year, name = "n_months"),
              by = c("residual", "geo", "year")) |>
    arrange(residual, match(geo, GEOS), year) |> select(residual, geo, year, n_months, n_breach, max_abs_R, max_ratio)
  era <- long |> mutate(era = ifelse(mi < tm("2026-01"), "before 2026 (back series)", "2026 onward")) |>
    group_by(residual, geo, era) |>
    summarise(n_months = n(), n_breach = sum(abs(R) > bound), share_breach = f3(mean(abs(R) > bound), 2)) |>
    arrange(residual, match(geo, GEOS), desc(era))
  top <- br |> arrange(desc(ratio)) |> slice_head(n = 20) |>
    transmute(residual, geo, month = fm(mi), R = f3(R), bound = f3(bound), ratio = f3(ratio, 2))
  show(by_year, "BREACHES by year"); show(era, "BREACHES before / from 2026"); show(top, "largest breaches")
  md_add("### Breaches by geo and year", "", md_table(by_year),
         "### Before 2026 (ECOICOP ver.2 back series) vs 2026 onward", "", md_table(era),
         "### Largest 20 breaches by |R| / bound", "", md_table(top))
}
writeLines(md, file.path(VER, "contrib_tables_generated.md"), useBytes = TRUE)
cat("\nwrote verify/contrib_residuals.csv, verify/contrib_tables_generated.md\n")
if (n_breach > 0) stop("GATE FAILED: ", n_breach, " geo-months with |R| > computed rounding bound. Stop and report.")
cat("GATE PASSED: every |R| <= its computed rounding bound.\nDone.\n")
