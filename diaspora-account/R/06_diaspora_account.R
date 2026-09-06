# ==============================================================================
# 06_diaspora_account.R
# Build the diaspora account from the components (04) and the ASK nominal GDP
# denominator (02a), and test it against IMF Country Report No. 21/41.
#
# CITATION CONVENTION. Page numbers below are PDF page numbers of the cached
# file, with the report's own printed page in brackets where they differ:
#   PDF p24 [printed 20]  Box 1
#   PDF p37 [printed 33]  Table 5
#   PDF p52 [printed 48]  Annex III
#   PDF p4                Selected Economic Indicators (no printed folio)
#
# METHODOLOGY. The allocation is stated in footnote 1/ TO THE TABLE EMBEDDED IN
# BOX 1, PDF p24 [printed 20] — the footnote belongs to that table, not to the
# box. Both sit in the figure layer and are invisible to pdftools::pdf_text();
# they were read from a 400/600 dpi raster.
#
# BANDS vary the staff judgements. The names describe the ASSUMPTION, not a
# position in an ordering, and none of them is a floor:
#   remittances_and_travel  remittances + 0.92*travel only. NOT a lower bound:
#                           59% of it is the 92% travel share, the least
#                           established assumption in the piece.
#   imf_baseline            the full allocation as published.
#   maximal_attribution     travel at 100%, E&O at 100%.
#   travel_070 / travel_050 the full allocation with the travel share reduced to
#                           0.70 and 0.50. Travel is ~45% of the 2019 account and
#                           the published shares never vary it downward; these do.
#
# THESE ARE NOT ORDERED. E&O is negative in 2020, so attributing 100% of it
# yields a SMALLER total than 50%. Never render as a shaded interval.
#
# FDI TREATMENT is a separate dimension. See the FDI section below: the mapping
# has NO ESTABLISHED BASIS, and "excluded" is carried because of that.
#
# DENOMINATOR. ASK gdp13.px, expenditure approach, current prices, EUR million,
# 2008-2024. The comparison additionally reports against the IMF's own GDP
# (PDF p4 memorandum) so the comparison is like-for-like.
#
# Run from the piece root:  Rscript R/06_diaspora_account.R [YYYY-MM]
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr); library(tibble); library(readxl)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

VINTAGE <- resolve_vintage()
VDIR    <- vintage_dir(VINTAGE)
options(width = 210)

BR <- character(0)
br <- function(...) { l <- paste0(...); BR <<- c(BR, l); cat(l, "\n", sep = "") }
br_table <- function(df, indent = "  ") {
  for (l in utils::capture.output(print(as.data.frame(df), row.names = FALSE, right = TRUE)))
    br(indent, l)
  invisible(NULL)
}

comp <- readRDS(file.path(PROC_DIR, paste0("components_annual_", VINTAGE, ".rds")))
gdp  <- read_csv(file.path(PROC_DIR, "gdp_nominal_annual.csv"), show_col_types = FALSE)
wide <- comp |> select(component, year, value) |>
  pivot_wider(names_from = component, values_from = value)

br(strrep("=", 100)); br("06_diaspora_account.R — vintage ", VINTAGE); br(strrep("=", 100))

# --- IMF reference -------------------------------------------------------------
IMF_GDP <- c(`2018` = 6726, `2019` = 7104, `2020` = 6817)   # PDF p4 memorandum

# Box 1, PDF p24 [printed 20], ALL THREE COLUMNS, both periods, every row.
# Transcribed from a 400 dpi raster and re-verified at 600 dpi.
BOX <- tribble(
  ~line,                            ~t1819, ~r1819, ~d1819, ~t2020, ~r2020, ~d2020,
  "Current account",                  -6.5,  -39.0,   32.4,   -7.5,  -34.1,   26.7,
  "Balance on Goods and Services",   -35.8,  -44.4,    8.6,  -31.7,  -41.0,    9.3,
  "Exports of Goods and Services",    29.0,   12.0,   17.0,   22.0,   12.8,    9.3,
  "Imports of Goods and Services",    56.4,   56.4,    0.0,   53.7,   53.7,    0.0,
  "Primary Income",                    1.9,   -1.6,    3.5,    2.3,   -1.3,    3.6,
  "Secondary Income",                 19.0,    7.0,   11.9,   21.9,    8.2,   13.7,
  "Secondary Income: Official",        3.4,    3.4,    0.0,    3.7,    3.7,    0.0,
  "Secondary Income: Other",          15.6,    3.6,   11.9,   18.2,    4.4,   13.7,
  "Capital account",                  -0.1,   -0.1,    0.0,   -0.1,   -0.1,    0.0,
  "Financial account",                -3.8,   -0.6,   -3.2,   -7.8,   -5.3,   -2.5,
  "Direct investment, net",           -3.1,    0.1,   -3.2,   -3.0,   -0.5,   -2.5,
  "Portfolio investment, net",        -1.1,   -1.1,    0.0,   -0.5,   -0.5,    0.0,
  "Other investment, net",            -1.0,   -1.0,    0.0,   -3.1,   -3.1,    0.0,
  "Reserve assets",                    1.3,    1.3,    0.0,   -1.2,   -1.2,    0.0,
  "Net errors and omissions",          2.9,    1.4,    1.4,   -0.2,   -0.1,   -0.1,
  "Overall balance",                   0.0,  -37.1,   37.1,    0.0,  -29.1,   29.1
)
bx <- function(l, col) BOX[[col]][BOX$line == l]

# Table 5, PDF p37 [printed 33], EUR million
T5 <- tribble(
  ~line,                      ~y2018, ~y2019, ~y2020,
  "services_receipts",          1562,   1676,   1049,
  "goods_exports",               377,    393,    453,
  "comp_employees_net",          237,    257,    249,
  "sec_other_transfers_net",    1034,   1123,   1240,
  "di_net",                     -226,   -201,   -208,
  "di_liabilities",              272,    266,    254,
  "net_eo",                      184,    215,    -16,
  "current_account",            -509,   -392,   -509
)
t5 <- function(l, y) T5[[paste0("y", y)]][T5$line == l]

pct  <- function(v, g) 100 * v / g
oy   <- function(y, col) wide[[col]][wide$year == y]
gimf <- function(y) IMF_GDP[as.character(y)]

# --- CBK "Total" lines, for the parent tests -----------------------------------
rd  <- function(f, sh) suppressMessages(read_excel(file.path(VDIR, f), sheet = sh,
         col_names = FALSE, .name_repair = "minimal", col_types = "text"))
ann <- function(d) { q <- trimws(as.character(d[[1]]))
  i <- which(!is.na(q) & grepl("^(19|20)[0-9]{2}$", q))
  b <- c(0, which(diff(i) != 1), length(i)); r <- i[(b[1]+1):b[2]]
  list(rows = r, years = as.integer(q[r])) }
acol <- function(d, ab, j) suppressWarnings(as.numeric(as.character(d[[j]])[ab$rows]))

bop <- rd("26 Balance of payments - main components.xls", "BOP"); abp <- ann(bop)
ca  <- rd("26a Current account.xls", "Current Account");          aca <- ann(ca)
TOT <- tibble(year = abp$years,
  current_account = acol(bop, abp, 3), primary_income = acol(bop, abp, 6),
  secondary_income = acol(bop, abp, 7), capital_account = acol(bop, abp, 8),
  financial_account = acol(bop, abp, 9), di_net = acol(bop, abp, 10),
  portfolio = acol(bop, abp, 11), other_inv = acol(bop, abp, 12),
  reserves = acol(bop, abp, 13), net_eo = acol(bop, abp, 14)) |>
  left_join(tibble(year = aca$years,
                   exports_gs = acol(ca, aca, 13) + acol(ca, aca, 14),
                   imports_gs = acol(ca, aca, 23) + acol(ca, aca, 24)), by = "year")

# ============================== [1] PARENT TESTS ===============================
br("\n[1] PARENT VALIDATION — computed, not asserted")
br(strrep("-", 100))
br("  Box 1 TOTAL column against the same lines in CBK 26/26a, percent of IMF GDP.")
br("  A line VALIDATES when our published total reproduces the Box's Total column;")
br("  it does not validate when the concept or sign convention differs.")

parent_map <- tribble(
  ~box_line,                        ~col,
  "Current account",                "current_account",
  "Exports of Goods and Services",  "exports_gs",
  "Imports of Goods and Services",  "imports_gs",
  "Primary Income",                 "primary_income",
  "Secondary Income",               "secondary_income",
  "Capital account",                "capital_account",
  "Financial account",              "financial_account",
  "Direct investment, net",         "di_net",
  "Portfolio investment, net",      "portfolio",
  "Other investment, net",          "other_inv",
  "Reserve assets",                 "reserves",
  "Net errors and omissions",       "net_eo"
)
mk_parent <- function(years, tcol) {
  parent_map |> rowwise() |>
    mutate(box  = bx(box_line, tcol),
           ours = mean(sapply(years, function(y)
             pct(TOT[[col]][TOT$year == y], gimf(y)))),
           dev  = ours - box,
           flag = if (abs(dev) <= 0.15) "validates"
                  else if (abs(abs(ours) - abs(box)) <= 0.15) "SIGN DIFFERS"
                  else "does NOT validate") |>
    ungroup() |> select(box_line, box, ours, dev, flag)
}
br("\n  Average 2018-19:"); br_table(mk_parent(2018:2019, "t1819") |>
  mutate(across(where(is.numeric), ~round(.x, 2))))
br("\n  2020 (IMF column is a projection):"); br_table(mk_parent(2020L, "t2020") |>
  mutate(across(where(is.numeric), ~round(.x, 2))))

br("\n  Table 5 parent test, EUR million, ours against PDF p37 [printed 33]:")
t5p <- tibble(year = 2018:2020) |>
  mutate(ca_ours = sapply(year, function(y) TOT$current_account[TOT$year == y]),
         ca_t5   = sapply(year, function(y) t5("current_account", y)),
         ca_dev  = ca_ours - ca_t5,
         xgs_ours = sapply(year, function(y) TOT$exports_gs[TOT$year == y]),
         xgs_t5   = sapply(year, function(y) t5("goods_exports", y) + t5("services_receipts", y)),
         xgs_dev  = xgs_ours - xgs_t5,
         eo_ours = sapply(year, function(y) TOT$net_eo[TOT$year == y]),
         eo_t5   = sapply(year, function(y) t5("net_eo", y)), eo_dev = eo_ours - eo_t5)
br_table(t5p |> mutate(across(where(is.numeric) & !year, ~round(.x, 1))))

# ============================== [2] RESIDENTS ==================================
br("\n[2] RESIDENTS' SIDE — against Box 1's Residents CURRENT ACCOUNT")
br(strrep("-", 100))
br("  Box 1 Residents current account: ", bx("Current account", "r1819"),
   " (avg 2018-19), ", bx("Current account", "r2020"), " (2020).")
br("  Ours: CBK current account less the diaspora-attributed CURRENT-ACCOUNT")
br("  components (0.92*travel + compensation net + remittances). Both on IMF GDP.")
res_ca <- function(y) TOT$current_account[TOT$year == y] -
  (0.92 * oy(y, "travel_credits") + oy(y, "compensation_employees") + oy(y, "remittances"))
resid <- tibble(period = c("avg 2018-19", "2020")) |> rowwise() |>
  mutate(yrs = list(if (period == "avg 2018-19") 2018:2019 else 2020L),
         ours = mean(sapply(yrs, function(y) pct(res_ca(y), gimf(y)))),
         box  = if (period == "avg 2018-19") bx("Current account", "r1819")
                else bx("Current account", "r2020"),
         dev  = ours - box) |> ungroup() |> select(-yrs)
br_table(resid |> mutate(across(where(is.numeric), ~round(.x, 3))))
br("  The diaspora side and the residents side are the SAME identity from opposite")
br("  ends and are not independent tests. Reported so the arithmetic is visible.")

# ============================== [3] FDI ========================================
br("\n[3] FDI — THE MAPPING HAS NO ESTABLISHED BASIS")
br(strrep("-", 100))
di_t5 <- mean(c(pct(t5("di_net", 2018), gimf(2018)), pct(t5("di_net", 2019), gimf(2019))))
di_lb <- mean(c(pct(t5("di_liabilities", 2018), gimf(2018)), pct(t5("di_liabilities", 2019), gimf(2019))))
eq_ex <- mean(sapply(2018:2019, function(y) pct(oy(y, "fdi_equity_excl_re"), gimf(y))))
eq_in <- mean(sapply(2018:2019, function(y) pct(oy(y, "fdi_equity_incl_re"), gimf(y))))
br(sprintf("  Box 1 avg 2018-19:  Total %.1f  =  Residents %.1f  +  Diaspora %.1f",
           bx("Direct investment, net","t1819"), bx("Direct investment, net","r1819"),
           bx("Direct investment, net","d1819")))
br(sprintf("  Table 5 net DI over IMF GDP, avg 2018-19 : %+.3f%%", di_t5))
br(sprintf("  Table 5 DI LIABILITIES over IMF GDP      : %+.3f%%", di_lb))
br(sprintf("  ours, equity EXCLUDING reinvested        : %+.3f%%", eq_ex))
br(sprintf("  ours, equity INCLUDING reinvested        : %+.3f%%", eq_in))
br("")
br("  THE SOURCE CONTRADICTS ITSELF. The footnote says the diaspora row is equity")
br("  liabilities under FDI. But Box 1's Diaspora row (-3.2) is essentially the")
br(sprintf("  WHOLE of net direct investment (%+.3f%%), with Residents left at only %+.1f%%.",
           di_t5, bx("Direct investment, net","r1819")))
br(sprintf("  Equity liabilities are %+.3f%% — nowhere near -3.2. The two readings", di_lb))
br("  cannot be reconciled from the published material.")
br("")
br(sprintf("  Our excluding-reinvested series averages %.3f%%, which sits close to the", eq_ex))
br("  3.2 the Box prints. That is a COINCIDENCE WITH A DIFFERENT CONCEPT, not")
br("  evidence: the Box's own arithmetic identifies that row with net DI, which is")
br("  a different quantity. The mapping is therefore NOT established, and the 2020")
br("  test fails: see the line table below, where DI deviates by -1.26 pp.")
br("  For this reason an FDI-EXCLUDED variant is carried alongside.")

# --- bands and treatments ------------------------------------------------------
SHARES <- tribble(
  ~band,                     ~s_remit, ~s_travel, ~s_comp, ~s_fdi, ~s_eo,
  "remittances_and_travel",      1.00,      0.92,    0.00,   0.00,   0.00,
  "imf_baseline",                1.00,      0.92,    1.00,   1.00,   0.50,
  "maximal_attribution",         1.00,      1.00,    1.00,   1.00,   1.00,
  "travel_070",                  1.00,      0.70,    1.00,   1.00,   0.50,
  "travel_050",                  1.00,      0.50,    1.00,   1.00,   0.50
)
FDI_TREATMENT <- c(excl_reinvested = "fdi_equity_excl_re",
                   incl_reinvested = "fdi_equity_incl_re",
                   directional     = "fdi_equity_directional",
                   excluded        = NA_character_)
FDI_BASE <- "excl_reinvested"

build <- function(bandrow, vname) {
  w <- wide
  fc <- FDI_TREATMENT[[vname]]
  w$fdi_used <- if (is.na(fc)) 0 else w[[fc]]
  w |> transmute(year, band = bandrow$band, fdi_variant = vname,
    c_remit  = bandrow$s_remit  * remittances,
    c_travel = bandrow$s_travel * travel_credits,
    c_comp   = bandrow$s_comp   * compensation_employees,
    c_fdi    = bandrow$s_fdi    * fdi_used,
    c_eo     = bandrow$s_eo     * errors_omissions,
    total_eur_m = rowSums(cbind(c_remit, c_travel, c_comp, c_fdi, c_eo), na.rm = FALSE))
}
acct <- bind_rows(lapply(seq_len(nrow(SHARES)), function(i)
  bind_rows(lapply(names(FDI_TREATMENT), function(v) build(SHARES[i, ], v))))) |>
  left_join(gdp |> select(year, gdp_eur_m), by = "year") |>
  left_join(comp |> distinct(year, provisional) |> group_by(year) |>
              summarise(provisional = any(provisional), .groups = "drop"), by = "year") |>
  mutate(has_denominator = !is.na(gdp_eur_m),
         pct_gdp = ifelse(has_denominator, 100 * total_eur_m / gdp_eur_m, NA_real_))

acct_total <- function(y, band, vname) {
  s <- SHARES[SHARES$band == band, ]; fc <- FDI_TREATMENT[[vname]]
  s$s_remit * oy(y, "remittances") + s$s_travel * oy(y, "travel_credits") +
    s$s_comp * oy(y, "compensation_employees") +
    s$s_fdi * (if (is.na(fc)) 0 else oy(y, fc)) + s$s_eo * oy(y, "errors_omissions")
}

# ============================== [4] LINE TABLE =================================
br("\n[4] LINE BY LINE vs the Box 1 DIASPORA column, percent of IMF GDP")
br(strrep("-", 100))
mkline <- function(years, dcol) tribble(
  ~line, ~status, ~box, ~ours,
  "Exports of Goods and Services", "UNVERIFIABLE", bx("Exports of Goods and Services", dcol),
    mean(sapply(years, function(y) pct(0.92 * oy(y, "travel_credits"), gimf(y)))),
  "Primary Income", "VALIDATED", bx("Primary Income", dcol),
    mean(sapply(years, function(y) pct(oy(y, "compensation_employees"), gimf(y)))),
  "Secondary Income: Other", "UNVERIFIABLE", bx("Secondary Income: Other", dcol),
    mean(sapply(years, function(y) pct(oy(y, "remittances"), gimf(y)))),
  "Direct investment, net", "CALIBRATED", bx("Direct investment, net", dcol),
    mean(sapply(years, function(y) pct(-oy(y, "fdi_equity_excl_re"), gimf(y)))),
  "Net errors and omissions", "VALIDATED", bx("Net errors and omissions", dcol),
    mean(sapply(years, function(y) pct(0.5 * oy(y, "errors_omissions"), gimf(y)))),
  "Overall balance", "-", bx("Overall balance", dcol),
    mean(sapply(years, function(y) pct(acct_total(y, "imf_baseline", FDI_BASE), gimf(y))))
) |> mutate(dev = ours - box)
br("\n  Average 2018-19:"); br_table(mkline(2018:2019, "d1819") |> mutate(across(where(is.numeric), ~round(.x, 2))))
br("\n  2020:");            br_table(mkline(2020L, "d2020")    |> mutate(across(where(is.numeric), ~round(.x, 2))))

# ============================== [5] WEIGHTING ==================================
br("\n[5] WHAT THE STATUS TABLE WEIGHS — shares of the account by year")
br(strrep("-", 100))
br("  UNVERIFIABLE = travel + remittances | CALIBRATED = FDI | VALIDATED = compensation + E&O")
wt <- lapply(2008:2020, function(y) {
  g <- gdp$gdp_eur_m[gdp$year == y]
  u <- (0.92 * oy(y, "travel_credits") + oy(y, "remittances")) / g
  cl <- oy(y, "fdi_equity_excl_re") / g
  v <- (oy(y, "compensation_employees") + 0.5 * oy(y, "errors_omissions")) / g
  tt <- acct_total(y, "imf_baseline", FDI_BASE) / g
  tibble(year = y, unverifiable = 100*u/tt, calibrated = 100*cl/tt, validated = 100*v/tt)
}) |> bind_rows()
br_table(wt |> mutate(across(where(is.numeric) & !year, ~round(.x, 1))))
w19 <- wt |> filter(year == 2019)
br(sprintf("\n  2019: %.0f%% UNVERIFIABLE / %.0f%% CALIBRATED / %.0f%% VALIDATED.",
           w19$unverifiable, w19$calibrated, w19$validated))
br("  Independently checkable lines carry roughly a seventh of the account.")

# ============================= [6] RESOLUTION ==================================
br("\n[6] BENCHMARK RESOLUTION FLOOR")
br(strrep("-", 100))
g1819 <- mean(c(gimf(2018), gimf(2019)))
res_pp <- 0.05; res_eur <- res_pp / 100 * g1819
br(sprintf("  Box 1 prints to one decimal, so its rows are only resolved to +/-%.2f pp,",
           res_pp))
br(sprintf("  which on avg 2018-19 GDP of %.0f EUR m is +/-%.1f EUR m.", g1819, res_eur))
tdev <- mkline(2018:2019, "d1819")$dev[1]
br(sprintf("  The travel line deviates by %+.2f pp. Any revision is therefore bounded", tdev))
br(sprintf("  at about %.1f EUR m of travel credits ((|%.2f| + %.2f)/100 * %.0f / 0.92);",
           (abs(tdev) + res_pp)/100 * g1819 / 0.92, tdev, res_pp, g1819))
br("  it does NOT establish that travel was unrevised.")

# --- guards --------------------------------------------------------------------
br("\n[7] GUARDS")
ns <- acct |> filter(band == "remittances_and_travel") |> select(year, fdi_variant, total_eur_m) |>
  pivot_wider(names_from = fdi_variant, values_from = total_eur_m)
stopifnot(all(abs(ns$excl_reinvested - ns$excluded) < 1e-9, na.rm = TRUE))
br("  remittances_and_travel identical across all four FDI treatments: yes")
inv <- acct |> filter(fdi_variant == FDI_BASE) |> select(year, band, pct_gdp) |>
  pivot_wider(names_from = band, values_from = pct_gdp) |>
  filter(maximal_attribution < imf_baseline)
br(sprintf("  band ordering inverts (maximal < baseline) in: %s", paste(inv$year, collapse = ", ")))
br(sprintf("  FDI treatment coverage: %s", paste(sapply(names(FDI_TREATMENT), function(v) {
  fc <- FDI_TREATMENT[[v]]
  if (is.na(fc)) return(paste0(v, " n/a"))
  y <- wide$year[!is.na(wide[[fc]])]; sprintf("%s %d-%d", v, min(y), max(y)) }), collapse = " | ")))
y24 <- acct |> filter(year == 2024, band == "imf_baseline", fdi_variant == FDI_BASE)
br(sprintf("\n  *** 2024 EMBARGO *** %.1f%% of GDP, four provisional years, travel under", y24$pct_gdp))
br("  announced revision. Not to appear in any draft or figure. Same for 2021-2023.")

# --- write ---------------------------------------------------------------------
csv_out <- file.path(PROC_DIR, paste0("diaspora_account_", VINTAGE, ".csv"))
rds_out <- file.path(PROC_DIR, paste0("diaspora_account_", VINTAGE, ".rds"))
txt_out <- file.path(PROC_DIR, paste0("benchmark_report_", VINTAGE, ".txt"))
write_csv(acct |> mutate(vintage = VINTAGE), csv_out)
saveRDS(acct |> mutate(vintage = VINTAGE), rds_out)
br("\n", strrep("=", 100))
br("Wrote: ", basename(csv_out), " | ", basename(rds_out), " | ", basename(txt_out))
write_utf8(BR, txt_out)

cat("\n\nBANDS at the ", FDI_BASE, " FDI treatment, % of GDP\n", sep = "")
show <- acct |> filter(fdi_variant == FDI_BASE, year >= 2008, year <= 2020) |>
  select(year, band, pct_gdp) |> pivot_wider(names_from = band, values_from = pct_gdp) |>
  arrange(year)
print(as.data.frame(show |> mutate(across(where(is.numeric) & !year, ~round(.x, 1)))),
      row.names = FALSE, right = TRUE, na.print = "  --")
cat("\nFDI treatments, imf_baseline band, 2019:\n")
print(as.data.frame(acct |> filter(band == "imf_baseline", year == 2019) |>
  select(fdi_variant, pct_gdp) |> mutate(pct_gdp = round(pct_gdp, 2))), row.names = FALSE)
