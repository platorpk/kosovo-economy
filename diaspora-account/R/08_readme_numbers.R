# ==============================================================================
# 08_readme_numbers.R
# Compute EVERY number that appears in the piece's prose, and print it to stdout
# with the label it carries in the README.
#
# House rule (CLAUDE.md section 2): every number in prose is computed by a
# script, never typed. This script is that script. If a figure appears in
# README.md and is not in this output, it does not belong in the README.
#
# CITATION CONVENTION. PDF page numbers of the cached file, with the report's own
# printed folio in brackets: PDF p24 [printed 20] Box 1; PDF p37 [printed 33]
# Table 5; PDF p52 [printed 48] Annex III; PDF p4 (no printed folio).
#
# DELIBERATE CAUSAL-LANGUAGE EXCEPTION. CLAUDE.md section 1 forbids causal
# language in output. One sentence in README.md breaks that rule on purpose:
#   "Travel receipts are the largest component of the account, so a revision to
#    them moves the headline directly."
# The claim is about ARITHMETIC, not the world: the account is a weighted sum and
# travel carries the largest weight. Reviewed and retained 2026-09-05. No other
# causal construction in the piece is exempt.
#
# Writes: data/processed/readme_numbers_<vintage>.txt
# Run:    Rscript R/08_readme_numbers.R [YYYY-MM]
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr); library(tibble); library(readxl)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

VINTAGE <- resolve_vintage(); VDIR <- vintage_dir(VINTAGE)
options(width = 200)
OUT <- character(0)
p  <- function(...) { l <- paste0(...); OUT <<- c(OUT, l); cat(l, "\n", sep = "") }
pn <- function(lab, v, dp = 2) p(sprintf("  %-54s %s", lab, formatC(v, format = "f", digits = dp)))

acct <- readRDS(file.path(PROC_DIR, paste0("diaspora_account_", VINTAGE, ".rds")))
comp <- readRDS(file.path(PROC_DIR, paste0("components_annual_", VINTAGE, ".rds")))
sub  <- readRDS(file.path(PROC_DIR, paste0("components_subannual_", VINTAGE, ".rds")))
gdp  <- read_csv(file.path(PROC_DIR, "gdp_nominal_annual.csv"), show_col_types = FALSE)
w    <- comp |> select(component, year, value) |> pivot_wider(names_from = component, values_from = value)

FDI_BASE <- "excl_reinvested"; YR_MIN <- 2008L; YR_MAX <- 2020L
IMF_GDP <- c(`2018` = 6726, `2019` = 7104, `2020` = 6817)          # PDF p4
gimf <- function(y) IMF_GDP[as.character(y)]
oy   <- function(y, c) w[[c]][w$year == y]
pct  <- function(v, g) 100 * v / g
B    <- function(b, y) acct$pct_gdp[acct$band == b & acct$fdi_variant == FDI_BASE & acct$year == y]
BV   <- function(b, v, y) acct$pct_gdp[acct$band == b & acct$fdi_variant == v & acct$year == y]

rd  <- function(f, sh) suppressMessages(read_excel(file.path(VDIR, f), sheet = sh,
        col_names = FALSE, .name_repair = "minimal", col_types = "text"))
ann <- function(d) { q <- trimws(as.character(d[[1]]))
  i <- which(!is.na(q) & grepl("^(19|20)[0-9]{2}$", q))
  b <- c(0, which(diff(i) != 1), length(i)); r <- i[(b[1]+1):b[2]]
  list(rows = r, years = as.integer(q[r])) }
acol <- function(d, ab, j) suppressWarnings(as.numeric(as.character(d[[j]])[ab$rows]))
bop <- rd("26 Balance of payments - main components.xls", "BOP"); abp <- ann(bop)
ca  <- rd("26a Current account.xls", "Current Account");          aca <- ann(ca)
CAt <- tibble(year = abp$years, current_account = acol(bop, abp, 3))
XG  <- tibble(year = aca$years, goods = acol(ca, aca, 13), serv = acol(ca, aca, 14)) |>
  mutate(exports_gs = goods + serv) |>
  left_join(w |> select(year, travel_credits), by = "year") |>
  mutate(share = 100 * travel_credits / exports_gs)

p(strrep("=", 96)); p("08_readme_numbers.R — vintage ", VINTAGE, " | FDI treatment ", FDI_BASE)
p("Every number below appears in README.md. Nothing in README.md may be typed.")
p(strrep("=", 96))

# --------------------------------------------------------------- A. headline
p("\n[A] HEADLINE")
bl19 <- B("imf_baseline", 2019); rt19 <- B("remittances_and_travel", 2019)
rem19 <- pct(oy(2019, "remittances"), gdp$gdp_eur_m[gdp$year == 2019])
pn("diaspora account 2019, IMF baseline (% of GDP)", bl19)
pn("remittances only 2019 (% of GDP)", rem19)
pn("difference (pp of GDP)", bl19 - rem19)
pn("ratio (x)", bl19 / rem19)
pn("remittances_and_travel 2019 (% of GDP)", rt19)
pn("diaspora account 2008 (% of GDP)", B("imf_baseline", 2008))
pn("diaspora account 2020 (% of GDP)", B("imf_baseline", 2020))
pn("maximal attribution 2020 (% of GDP)", B("maximal_attribution", 2020))
pn("2020 crossing, maximal minus baseline (pp)", B("maximal_attribution", 2020) - B("imf_baseline", 2020), 3)
win <- acct |> filter(band == "imf_baseline", fdi_variant == FDI_BASE, year >= YR_MIN, year <= YR_MAX)
mn <- win |> slice_min(pct_gdp, n = 1)
p(sprintf("  %-54s %.2f%% in %d", "series MINIMUM in the plotted window", mn$pct_gdp, mn$year))

# ---------------------------------------------------------- B. composition
p("\n[B] COMPOSITION 2019, percent of GDP, ordered by size")
g19 <- gdp$gdp_eur_m[gdp$year == 2019]
cm <- tibble(component = c("Travel receipts at 92%", "Workers' remittances",
                           "FDI equity excl. reinvested", "Compensation of employees, net",
                           "Errors and omissions at 50%"),
             pct = c(pct(0.92*oy(2019,"travel_credits"), g19), pct(oy(2019,"remittances"), g19),
                     pct(oy(2019,"fdi_equity_excl_re"), g19), pct(oy(2019,"compensation_employees"), g19),
                     pct(0.5*oy(2019,"errors_omissions"), g19))) |> arrange(desc(pct))
for (i in seq_len(nrow(cm))) pn(cm$component[i], cm$pct[i])
pn("sum (equals the headline)", sum(cm$pct))
pn("travel as a share of the 2019 account (%)", 100*cm$pct[1]/sum(cm$pct), 1)
pn("travel as a share of remittances_and_travel 2019 (%)",
   100*pct(0.92*oy(2019,"travel_credits"), g19)/rt19, 1)
# Rounded companions. The README's prose cites these to the whole percent; the
# one-decimal values above are the computed quantities. Both are printed so that
# every numeric token in the prose traces literally to this file.
pn("  rounded, as cited in prose — travel / account (%)",
   100*cm$pct[1]/sum(cm$pct), 0)
pn("  rounded, as cited in prose — travel / rem+travel (%)",
   100*pct(0.92*oy(2019,"travel_credits"), g19)/rt19, 0)

# ------------------------------------------------- C. status weighting
p("\n[C] STATUS WEIGHTING — shares of the account, by year")
p("  UNVERIFIABLE = travel + remittances | CALIBRATED = FDI | VALIDATED = compensation + E&O")
wt <- bind_rows(lapply(YR_MIN:YR_MAX, function(y) {
  g <- gdp$gdp_eur_m[gdp$year == y]
  tt <- B("imf_baseline", y)
  tibble(year = y,
         unverifiable = 100*pct(0.92*oy(y,"travel_credits") + oy(y,"remittances"), g)/tt,
         calibrated   = 100*pct(oy(y,"fdi_equity_excl_re"), g)/tt,
         validated    = 100*pct(oy(y,"compensation_employees") + 0.5*oy(y,"errors_omissions"), g)/tt) }))
for (i in seq_len(nrow(wt)))
  p(sprintf("    %d  UNVERIFIABLE %5.1f  CALIBRATED %5.1f  VALIDATED %5.1f",
            wt$year[i], wt$unverifiable[i], wt$calibrated[i], wt$validated[i]))
w19 <- wt |> filter(year == 2019)
p(sprintf("  2019 rounded: %.0f / %.0f / %.0f",
          w19$unverifiable, w19$calibrated, w19$validated))

# ------------------------------------------------ D. travel sensitivity
p("\n[D] TRAVEL SENSITIVITY, 2019, IMF baseline structure, % of GDP")
for (b in c("imf_baseline","travel_070","travel_050"))
  pn(sprintf("  %s", b), B(b, 2019))
p("\n[D2] FDI TREATMENTS, 2019, imf_baseline band, % of GDP")
for (v in c("excl_reinvested","incl_reinvested","directional","excluded"))
  pn(sprintf("  %s", v), BV("imf_baseline", v, 2019))

# ------------------------------------------------------- E. travel share
p("\n[E] TRAVEL AS A SHARE OF EXPORTS OF GOODS AND SERVICES")
for (y in c(2010,2011,2012,2013,2019,2020)) pn(sprintf("  %d (%%)", y), XG$share[XG$year==y], 1)
p("  IMF PDF p24 [printed 20] scatter, KOS point from a 600dpi raster:")
p("    x (2013) ~ 55, y (2019) ~ 64, reading tolerance +/- 2pp")
pn("travel credits 2010 (EUR m)", oy(2010,"travel_credits"), 1)
pn("travel credits 2011 (EUR m)", oy(2011,"travel_credits"), 1)
pn("travel credits, change 2010->2011 (%)", 100*(oy(2011,"travel_credits")/oy(2010,"travel_credits")-1), 1)
post <- XG |> filter(year >= 2011, year <= YR_MAX) |> slice_min(share, n = 1)
p(sprintf("  %-54s %.1f%% in %d", "lowest travel share after the step, to 2020", post$share, post$year))
pn("travel credits, change 2019->2020 (%)", 100*(oy(2020,"travel_credits")/oy(2019,"travel_credits")-1), 1)
pn("remittances, change 2019->2020 (%)", 100*(oy(2020,"remittances")/oy(2019,"remittances")-1), 1)
pn("E&O contribution 2020 (% of GDP)", pct(0.5*oy(2020,"errors_omissions"), gdp$gdp_eur_m[gdp$year==2020]))

# ------------------------------------------------------- F. the comparison
p("\n[F] COMPARISON AGAINST CR 21/41")
tot <- function(y) 0.92*oy(y,"travel_credits") + oy(y,"compensation_employees") +
  oy(y,"remittances") + oy(y,"fdi_equity_excl_re") + 0.5*oy(y,"errors_omissions")
for (nm in c("avg 2018-19","2020")) {
  ys <- if (nm=="avg 2018-19") 2018:2019 else 2020L
  box <- if (nm=="avg 2018-19") 37.1 else 29.1
  a <- mean(sapply(ys, function(y) pct(tot(y), gdp$gdp_eur_m[gdp$year==y])))
  b <- mean(sapply(ys, function(y) pct(tot(y), gimf(y))))
  p(sprintf("  %-14s ours@ASK %6.3f | ours@IMF %6.3f | Box %5.1f | denominator %+.3f | series %+.3f | TOTAL %+.3f",
            nm, a, b, box, a-b, b-box, a-box))
}
p("\n  Box 1 DIASPORA column, line by line, avg 2018-19 (% of IMF GDP):")
ln <- tibble(line = c("Exports of G&S","Primary income","Secondary income other",
                      "Direct investment net","Net errors and omissions","Overall balance"),
             status = c("UNVERIFIABLE","VALIDATED","UNVERIFIABLE","CALIBRATED","VALIDATED","-"),
             box = c(17.0,3.5,11.9,-3.2,1.4,37.1),
             ours = c(mean(sapply(2018:2019, function(y) pct(0.92*oy(y,"travel_credits"), gimf(y)))),
                      mean(sapply(2018:2019, function(y) pct(oy(y,"compensation_employees"), gimf(y)))),
                      mean(sapply(2018:2019, function(y) pct(oy(y,"remittances"), gimf(y)))),
                      mean(sapply(2018:2019, function(y) pct(-oy(y,"fdi_equity_excl_re"), gimf(y)))),
                      mean(sapply(2018:2019, function(y) pct(0.5*oy(y,"errors_omissions"), gimf(y)))),
                      mean(sapply(2018:2019, function(y) pct(tot(y), gimf(y)))))) |>
  mutate(dev = ours - box)
for (i in seq_len(nrow(ln)))
  p(sprintf("    %-26s %-13s box %6.1f  ours %6.2f  dev %+6.2f", ln$line[i], ln$status[i],
            ln$box[i], ln$ours[i], ln$dev[i]))
p("  2020 DI deviation (the calibrated mapping fails there):")
pn("    Direct investment net, 2020 dev (pp)",
   pct(-oy(2020,"fdi_equity_excl_re"), gimf(2020)) - (-2.5))

p("\n  the E&O revision, the one measured contribution:")
for (y in 2018:2019) {
  t5 <- c(`2018`=184, `2019`=215)[as.character(y)]
  p(sprintf("    %d  Table 5 %3.0f  ours %7.2f  difference %+6.2f EUR m", y, t5, oy(y,"errors_omissions"),
            oy(y,"errors_omissions") - t5))
}
half_pp <- mean(sapply(2018:2019, function(y) {
  t5 <- c(`2018`=184, `2019`=215)[as.character(y)]
  pct(0.5*(oy(y,"errors_omissions") - t5), gimf(y)) }))
pn("half the E&O difference, avg 2018-19 (pp of GDP)", half_pp, 3)
p("  The E&O LINE deviation is +0.19 pp; half the measured difference is the")
p("  figure above. The remainder is Box 1's one-decimal rounding.")

# ------------------------------------------------------ F2. parent validation
p("\n[F2] PARENT VALIDATION — Box 1 TOTAL column vs CBK's own totals")
PARENT_TOL <- 0.15
pn("tolerance used to call a line validated (pp)", PARENT_TOL, 2)
TOT <- tibble(year = abp$years,
  current_account = acol(bop, abp, 3), primary_income = acol(bop, abp, 6),
  secondary_income = acol(bop, abp, 7), capital_account = acol(bop, abp, 8),
  financial_account = acol(bop, abp, 9), di_net = acol(bop, abp, 10),
  portfolio = acol(bop, abp, 11), other_inv = acol(bop, abp, 12),
  reserves = acol(bop, abp, 13), net_eo = acol(bop, abp, 14)) |>
  left_join(tibble(year = aca$years,
                   exports_gs = acol(ca, aca, 13) + acol(ca, aca, 14),
                   imports_gs = acol(ca, aca, 23) + acol(ca, aca, 24)), by = "year")
PMAP <- tribble(~lab, ~col, ~box1819, ~box2020,
  "Current account","current_account", -6.5, -7.5,
  "Exports of Goods and Services","exports_gs", 29.0, 22.0,
  "Imports of Goods and Services","imports_gs", 56.4, 53.7,
  "Primary Income","primary_income", 1.9, 2.3,
  "Secondary Income","secondary_income", 19.0, 21.9,
  "Capital account","capital_account", -0.1, -0.1,
  "Financial account","financial_account", -3.8, -7.8,
  "Direct investment, net","di_net", -3.1, -3.0,
  "Portfolio investment, net","portfolio", -1.1, -0.5,
  "Other investment, net","other_inv", -1.0, -3.1,
  "Reserve assets","reserves", 1.3, -1.2,
  "Net errors and omissions","net_eo", 2.9, -0.2)
for (per in c("avg 2018-19","2020")) {
  ys <- if (per == "avg 2018-19") 2018:2019 else 2020L
  bc <- if (per == "avg 2018-19") "box1819" else "box2020"
  d <- PMAP |> rowwise() |>
    mutate(ours = mean(sapply(ys, function(y) pct(TOT[[col]][TOT$year == y], gimf(y)))),
           box = .data[[bc]], dev = ours - box, ok = abs(dev) <= PARENT_TOL) |> ungroup()
  p(sprintf("  %s: %d of %d lines validate within %.2f pp", per, sum(d$ok), nrow(d), PARENT_TOL))
  for (i in seq_len(nrow(d)))
    p(sprintf("    %-30s box %6.1f  ours %6.2f  dev %+6.2f  %s",
              d$lab[i], d$box[i], d$ours[i], d$dev[i], if (d$ok[i]) "validates" else "does NOT"))
}
p("\n  Table 5 current account, EUR million (the 2020 revision):")
for (y in 2018:2020) {
  t5ca <- c(`2018`=-509, `2019`=-392, `2020`=-509)[as.character(y)]
  p(sprintf("    %d  Table 5 %6.0f  ours %8.1f  dev %+7.1f", y, t5ca,
            TOT$current_account[TOT$year == y], TOT$current_account[TOT$year == y] - t5ca))
}

p("\n[F3] THE TWO MAPPING CHANGES")
p("  compensation of employees — MEASURED against Table 5:")
for (y in 2018:2019) {
  t5ce <- c(`2018`=237, `2019`=257)[as.character(y)]
  p(sprintf("    %d  Table 5 %3.0f  CBK net %7.2f  dev %+5.2f", y, t5ce,
            oy(y,"compensation_employees"), oy(y,"compensation_employees") - t5ce))
}
p("  FDI equity — CALIBRATED to Box 1, not measured (see section H).")

# --------------------------------------------------------- G. residents
p("\n[G] RESIDENTS' SIDE — against Box 1's Residents CURRENT ACCOUNT")
res <- function(y) CAt$current_account[CAt$year==y] -
  (0.92*oy(y,"travel_credits") + oy(y,"compensation_employees") + oy(y,"remittances"))
r1819 <- mean(sapply(2018:2019, function(y) pct(res(y), gimf(y))))
r2020 <- pct(res(2020), gimf(2020))
pn("ours, avg 2018-19 (% of IMF GDP)", r1819, 3)
p("  Box 1 Residents current account, avg 2018-19: -39.0")
pn("deviation (pp)", r1819 + 39.0, 3)
pn("ours, 2020 (% of IMF GDP)", r2020, 3)
p("  Box 1 Residents current account, 2020: -34.1")
pn("deviation (pp)", r2020 + 34.1, 3)

# --------------------------------------------------------------- H. FDI
p("\n[H] FDI — THE CONTRADICTION")
di_t5 <- mean(c(pct(-226, gimf(2018)), pct(-201, gimf(2019))))
di_lb <- mean(c(pct(272, gimf(2018)), pct(266, gimf(2019))))
p("  Box 1 avg 2018-19: Total -3.1 = Residents +0.1 + Diaspora -3.2")
pn("Table 5 net DI over IMF GDP (%)", di_t5, 3)
pn("Table 5 DI liabilities over IMF GDP (%)", di_lb, 3)
pn("ours, equity excl. reinvested (%)",
   mean(sapply(2018:2019, function(y) pct(oy(y,"fdi_equity_excl_re"), gimf(y)))), 3)
pn("ours, equity incl. reinvested (%)",
   mean(sapply(2018:2019, function(y) pct(oy(y,"fdi_equity_incl_re"), gimf(y)))), 3)
fv <- w |> select(year, a = fdi_equity_excl_re, b = fdi_equity_directional) |>
  filter(!is.na(a), !is.na(b)) |> mutate(d = a - b)
pn("years both FDI series carry data", nrow(fv), 0)
pn("of those, years they disagree (>0.01)", sum(abs(fv$d) > 0.01), 0)
pn("largest disagreement (EUR m)", max(abs(fv$d)), 1)
p(sprintf("  %-54s %d", "largest disagreement occurs in", fv$year[which.max(abs(fv$d))]))

# ------------------------------------------------------ I. resolution floor
p("\n[I] BENCHMARK RESOLUTION FLOOR")
g1819 <- mean(c(gimf(2018), gimf(2019)))
pn("avg 2018-19 IMF GDP (EUR m)", g1819, 0)
p(sprintf("  %-54s %s", "  ... comma-formatted, as it appears in prose",
          format(round(g1819), big.mark = ",")))
# ASK expenditure vs production GDP, recomputed from the raw pulls rather than
# from the processed file, which carries only the expenditure series.
askg <- function(f, lab) {
  d <- read_csv(file.path(RAW_DIR, "ask", f), show_col_types = FALSE, name_repair = "minimal")
  nm <- names(d); yc <- nm[tolower(nm) == "year"][1]; vc <- nm[length(nm)]
  cs <- setdiff(nm, c(yc, vc))
  hit <- cs[vapply(cs, function(c_) any(trimws(d[[c_]]) == lab), logical(1))][1]
  s <- d[trimws(d[[hit]]) == lab, ]
  tibble(year = as.integer(s[[yc]]), v = suppressWarnings(as.numeric(s[[vc]])) / 1000)
}
gcmp <- inner_join(askg("gdp13_expenditure_current_raw.csv", "GDP at current prices") |> rename(exp = v),
                   askg("gdp09_activities_current_raw.csv", "Gross Domestic Product") |> rename(prod = v),
                   by = "year") |> mutate(d = exp - prod)
p(sprintf("  %-54s %.3f", "ASK gdp13 vs gdp09, max |difference| (EUR m)", max(abs(gcmp$d))))
pn("years compared", nrow(gcmp), 0)
pn("Box 1 resolution, +/- half a printed decimal (pp)", 0.05, 2)
pn("  ... in EUR million", 0.05/100*g1819, 1)
tdev <- ln$dev[1]
pn("travel line deviation (pp)", tdev, 2)
pn("implied bound on a travel revision (EUR m)", (abs(tdev)+0.05)/100*g1819/0.92, 1)

# ---------------------------------------------------------- J. reconciliation
p("\n[J] RECONCILIATION AND SOURCE DEFECTS")
qr <- sub |> filter(freq=="quarterly") |> group_by(component, year) |>
  summarise(n=n(), s=sum(value), .groups="drop") |> filter(n==4) |>
  inner_join(comp |> select(component, year, annual=value), by=c("component","year")) |>
  mutate(d = s - annual)
nz <- qr |> filter(abs(d) > 1e-9) |> arrange(year)
pn("first complete quarterly year", min(qr$year), 0)
w0912 <- qr |> filter(year>=2009, year<=2012)
pn("component-years reconciled 2009-2012", nrow(w0912), 0)
pn("of those deviating beyond 1e-9", sum(abs(w0912$d) > 1e-9), 0)
p(sprintf("  %-54s %.2e", "travel only, max |deviation| 2009-2012",
          max(abs(w0912$d[w0912$component=="travel_credits"]))))
p("  every non-zero quarterly deviation in the series:")
for (i in seq_len(nrow(nz)))
  p(sprintf("    %-24s %d  %+.4f EUR m", nz$component[i], nz$year[i], nz$d[i]))
sv <- rd("27 Services.xls","BiP - Services"); asv <- ann(sv)
d26 <- tibble(year=abp$years, v26=acol(bop, abp, 5)) |>
  inner_join(tibble(year=asv$years, v27=acol(sv, asv, 2)), by="year") |>
  mutate(d = v26 - v27) |> filter(abs(d) > 0.01)
p("  services balance, 26 vs 27:")
for (i in seq_len(nrow(d26)))
  p(sprintf("    %d  %.4f vs %.4f  difference %+.3f EUR m", d26$year[i], d26$v26[i], d26$v27[i], d26$d[i]))

# ---------------------------------------------------------- K. truncation
p("\n[K] WHAT THE TRUNCATION WITHHOLDS")
for (y in 2021:2024) pn(sprintf("  %d (%% of GDP, PROVISIONAL)", y), B("imf_baseline", y), 1)
pn("years plotted", length(YR_MIN:YR_MAX), 0)

# ---------------------------------------------------- L. ASK vs CBK exports
p("\n[L] ASK vs CBK EXPORTS OF GOODS AND SERVICES — not independent")
xc <- gdp |> select(year, ask = exports_gs_eur_m) |> inner_join(XG |> select(year, cbk = exports_gs), by="year") |>
  mutate(d = ask - cbk)
pn("years compared", nrow(xc), 0)
pn("years identical to 0.05 EUR m", sum(abs(xc$d) <= 0.05), 0)
pn("max |difference| (EUR m)", max(abs(xc$d)), 2)
p(sprintf("  %-54s %d", "largest difference occurs in", xc$year[which.max(abs(xc$d))]))
pn("difference in 2019, the benchmark year (EUR m)", xc$d[xc$year==2019], 2)
p("  ASK's national accounts take services trade from CBK's balance of payments,")
p("  so these are not independently sourced.")

# --------------------------------------------------------------- M. prose
p("\n[M] AS THEY APPEAR IN PROSE (rounded display forms)")
prose <- c(sprintf("%.1f", c(bl19, rem19, bl19-rem19, bl19/rem19, rt19,
  B("imf_baseline",2008), B("imf_baseline",2020), B("maximal_attribution",2020), mn$pct_gdp,
  XG$share[XG$year==2019], XG$share[XG$year==2013],
  B("travel_070",2019), B("travel_050",2019), BV("imf_baseline","excluded",2019),
  w19$unverifiable, w19$calibrated, w19$validated,
  sapply(2021:2024, function(y) B("imf_baseline", y)), max(abs(fv$d)), max(abs(xc$d)))),
  sprintf("%.2f", c(abs(nz$d), 0.05/100*g1819, (abs(tdev)+0.05)/100*g1819/0.92)),
  sprintf("%.3f", c(abs(d26$d[1]), half_pp, r1819, r1819+39.0)))
p("  ", paste(sort(unique(prose)), collapse = "  "))

# --------------------------------------------------------------- N. reference
p("\n[N] REFERENCE VALUES — cited, not computed")
p("  IMF Country Report No. 21/41, February 2021, 89 pp.")
p("    PDF p4                 GDP: 2018 6,726 | 2019 7,104 | 2020 6,817")
p("    PDF p24 [printed 20]   Box 1, embedded table, all three columns;")
p("                           footnote 1/ TO THAT TABLE carries the shares")
p("    PDF p37 [printed 33]   Table 5")
p("    PDF p52 [printed 48]   fn2, CBK Sep 2019 revision covers 2017:Q1-2019:Q2")
p("    PDF p84                CBK reports BPM6 from 2013:Q1")
p("  CBK methodology p27: travel credits include modelled components")
p("  R required >= ", R_MIN, " (enforced in 01_functions.R); running ", as.character(getRversion()))

write_utf8(OUT, file.path(PROC_DIR, paste0("readme_numbers_", VINTAGE, ".txt")))
cat("\nWrote: ", file.path(PROC_DIR, paste0("readme_numbers_", VINTAGE, ".txt")), "\n", sep = "")
