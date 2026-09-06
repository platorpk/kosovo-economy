# ==============================================================================
# 04_parse_components.R
# Extract the five IMF diaspora-account components — plus one FDI variant — from
# the cached CBK workbooks into a tidy long table.
#
# ANNUAL BLOCK ONLY. The CBK sheets carry three stacked frequency blocks
# (annual, then quarterly, then monthly) in a single column, and the year stamp
# in the quarterly and monthly blocks is irregular: sometimes on Q1, sometimes on
# Q4, sometimes on December, sometimes on January, with word order flipping
# between the Albanian and English workbooks ("2009 T4" vs "Q4 2025") and the
# first monthly row of some sheets carrying no year at all. Dating those blocks
# needs its own verification routine and is 05_parse_subannual.R. The `month` and
# `freq` columns exist here so 05 appends rather than reshapes.
#
# This script applies NO methodology shares (92% travel, 50% errors and
# omissions, 100% elsewhere), sums nothing into a diaspora account, and computes
# no ratio to GDP. It extracts six series and checks them.
#
# Component -> series mapping (approved). Codes are BPM6, 967.<ITEM>.<ENTRY>.X.N.6
# with entry B=Balance, C=Credit, D=Debit. Three of the six series carry no code
# in the published workbook and are anchored on their label instead.
#
# Writes (vintage-stamped, so a September parse cannot overwrite August's):
#   data/processed/components_annual_<vintage>.csv / .rds
#   data/processed/guard_report_<vintage>.txt
#
# Run from the piece root:  Rscript R/04_parse_components.R [YYYY-MM]
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr); library(tibble); library(readxl)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

VINTAGE <- resolve_vintage()
VDIR    <- vintage_dir(VINTAGE)
if (!dir.exists(VDIR)) stop("No such vintage: ", VDIR)
dir.create(PROC_DIR, recursive = TRUE, showWarnings = FALSE)

options(width = 200)

# --- guard report accumulator --------------------------------------------------
GR <- character(0)
gr <- function(...) { line <- paste0(...); GR <<- c(GR, line); cat(line, "\n", sep = "") }
FAILURES <- character(0)
fail <- function(...) FAILURES <<- c(FAILURES, paste0(...))

# --- series specification ------------------------------------------------------
# `code` NA means the published workbook carries no BPM6 code for this column;
# the series is anchored on `label` instead.
SPEC <- tribble(
  ~component,      ~file, ~sheet, ~col, ~code, ~label, ~entry, ~variant, ~first_year, ~n_years,
  "remittances",
    "29 Secondary Income.xls", "BiP - Të ardhurat dytësore", 9L,
    "967.1DF00Z.c.O.A.6", "Transferet personale", "credit", "baseline", 2004L, 22L,
  "travel_credits",
    "27 Services.xls", "BiP - Services", 19L,
    "967.1BD000.C.X.N.6", "Udhëtimi", "credit", "baseline", 2004L, 22L,
  # NET, not credit. IMF CR 21/41 Table 5 publishes "Compensation of employees,
  # net" as 237 / 257 / 249 for 2018-20; CBK's balance column reproduces those to
  # 0.04 / 0.13 / (2020 is an IMF projection). The credit column, used previously,
  # overstates by the debit (10.6 / 7.3 EUR m).
  "compensation_employees",
    "28 Primary Income.xls", "BiP - Të ardhurat parësore", 3L,
    "967.1CA000.B.X.A.6", "Kompensimi i punëtorve", "net (credit - debit)", "baseline", 2004L, 22L,
  # FDI equity EXCLUDING reinvested earnings is the concept Box 1 reproduces:
  # avg 2018-19 it is 3.203% of IMF GDP against Box 1's 3.2. Including reinvested
  # earnings gives 3.634%. Reinvested earnings of foreign-owned firms are not
  # diaspora real-estate purchase, which is the footnote's stated rationale.
  # Only 33.1 separates the two; 30 does not (c34 = c35 + c36 exactly, 22/22 years).
  "fdi_equity_excl_re",
    "33.1 Direct_investment_flows_In_&_Out.xls", "In Kosova", 3L,
    NA, "Kapitali dhe fondi i investimeve në aksione",
    "equity excl. reinvested earnings, net", "baseline", 2007L, 19L,
  "fdi_equity_incl_re",
    "30 Financial account.xls", "BiP_Llogaria_financiare", 35L,
    NA, "Kapitali dhe fondi i investimeve në aksione",
    "equity incl. reinvested earnings, liabilities", "variant", 2004L, 22L,
  "errors_omissions",
    "26 Balance of payments - main components.xls", "BOP", 14L,
    NA, "Errors and omission", "net", "baseline", 2004L, 22L,
  "fdi_equity_directional",
    "33.1 Direct_investment_flows_In_&_Out.xls", "In Kosova", 7L,
    NA, "Kapitali dhe fondi i investimeve në aksione",
    "inward (directional)", "variant", 2007L, 19L
)

# --- workbook helpers ----------------------------------------------------------
read_sheet <- function(f, sh) suppressMessages(read_excel(
  file.path(VDIR, f), sheet = sh, col_names = FALSE,
  .name_repair = "minimal", col_types = "text"))

# BPM6 entry fields are case-inconsistent in the CBK workbooks: government and
# total rows use ".B."/".C."/".D." while other-sector rows use lowercase
# (".b.", ".c."). Compare case-insensitively; keep the raw code as published.
code_eq <- function(a, b) !is.na(a) && !is.na(b) && toupper(a) == toupper(b)

# The annual block is the first maximal run of consecutive rows whose period
# label is a bare four-digit year increasing by one. Bounded explicitly — never
# by nrow(), which would sweep in the footnote rows (26 BOP's revision-note row —
# 259 in vintage 2026-08, 261 in 2026-09 — carries a literal 0 across columns 2-14).
annual_block <- function(d) {
  p  <- trimws(as.character(d[[1]]))
  is_y <- !is.na(p) & grepl("^(19|20)[0-9]{2}$", p)
  idx <- which(is_y)
  if (!length(idx)) stop("no bare-year rows in period column")
  brk  <- c(0, which(diff(idx) != 1), length(idx))
  runs <- lapply(seq_len(length(brk) - 1), function(i) idx[(brk[i] + 1):brk[i + 1]])
  runs <- Filter(function(r) length(r) >= 10, runs)
  if (!length(runs)) stop("no annual run of >= 10 consecutive year rows")
  r <- runs[[1]]
  yrs <- as.integer(p[r])
  if (!all(diff(yrs) == 1)) stop("annual years not consecutive: ", paste(yrs, collapse = ","))
  list(rows = r, years = yrs)
}

# One mapped column over the annual block, as numeric.
annual_col <- function(f, sh, col) {
  d  <- read_sheet(f, sh)
  ab <- annual_block(d)
  tibble(year = ab$years,
         value = suppressWarnings(as.numeric(as.character(d[[col]])[ab$rows])))
}

gr(strrep("=", 96))
gr("04_parse_components.R — vintage ", VINTAGE)
gr(strrep("=", 96))

# --- extraction ----------------------------------------------------------------
gr("\n[1] EXTRACTION — anchor checks and block bounds")
out <- vector("list", nrow(SPEC))

for (i in seq_len(nrow(SPEC))) {
  s  <- SPEC[i, ]
  d  <- read_sheet(s$file, s$sheet)
  ab <- annual_block(d)
  colv <- as.character(d[[s$col]])

  # anchor: BPM6 code where published, label text otherwise
  if (!is.na(s$code)) {
    hits <- which(vapply(seq_len(min(15L, nrow(d))), function(r)
      code_eq(colv[r], s$code), logical(1)))
    if (!length(hits)) {
      fail(s$component, ": BPM6 code ", s$code, " not found in column ", s$col)
      gr(sprintf("  %-24s ANCHOR FAIL  code %s not found", s$component, s$code))
      next
    }
    anchor <- sprintf("code %s @ r%d", colv[hits[1]], hits[1])
  } else {
    hits <- which(vapply(seq_len(min(15L, nrow(d))), function(r)
      !is.na(colv[r]) && grepl(s$label, colv[r], fixed = TRUE), logical(1)))
    if (!length(hits)) {
      fail(s$component, ": label '", s$label, "' not found in column ", s$col)
      gr(sprintf("  %-24s ANCHOR FAIL  label '%s' not found", s$component, s$label))
      next
    }
    anchor <- sprintf("label '%s' @ r%d (no code published)",
                      substr(trimws(gsub("[\r\n]+", " ", colv[hits[1]])), 1, 34), hits[1])
  }

  # block bounds must match the approved mapping exactly
  if (ab$years[1] != s$first_year) {
    fail(s$component, ": annual block starts ", ab$years[1], ", expected ", s$first_year)
  }
  if (length(ab$years) != s$n_years) {
    fail(s$component, ": annual block has ", length(ab$years), " rows, expected ", s$n_years)
  }

  gr(sprintf("  %-24s r%d-%d  %d..%d (n=%d)  %s",
             s$component, ab$rows[1], ab$rows[length(ab$rows)],
             ab$years[1], ab$years[length(ab$years)], length(ab$years), anchor))

  out[[i]] <- tibble(
    component   = s$component,
    year        = ab$years,
    month       = NA_integer_,
    freq        = "annual",
    value       = suppressWarnings(as.numeric(colv[ab$rows])),
    source_file = s$file,
    sheet       = s$sheet,
    series_code = s$code,
    column      = s$col,
    entry       = s$entry,
    variant     = s$variant,
    vintage     = VINTAGE
  )
}

dat <- bind_rows(out)

# --- provisional flags ---------------------------------------------------------
REV_REASON  <- "CBK services revision announced for September 2026"
PREL_REASON <- "CBK annual figure preliminary; p marker carried in cell formatting, not machine-readable"

dat <- dat |>
  mutate(
    provisional        = year >= 2021L & year <= 2025L,
    provisional_reason = case_when(
      year >= 2021L & year <= 2024L ~ REV_REASON,
      year == 2025L                 ~ PREL_REASON,
      TRUE                          ~ NA_character_))

# --- [2] reference value -------------------------------------------------------
gr("\n[2] REFERENCE VALUE")
# Re-anchored to the observed 2026-08 vintage. The scoping note recorded 1344.5
# for 2023; that was a PRIOR VINTAGE of this series and no longer matches what
# CBK publishes. Tolerance is deliberately tight — this is a same-vintage
# reproducibility check, not an approximate sanity bound.
REMIT_2023     <- 1335.8
REMIT_2023_TOL <- 0.5
r23 <- dat |> filter(component == "remittances", year == 2023L) |> pull(value)
gr(sprintf("  remittances 2023 = %.4f  | expected %.1f +/- %.1f  | prior vintage (scoping note) 1344.5",
           r23, REMIT_2023, REMIT_2023_TOL))
if (!length(r23) || is.na(r23) || abs(r23 - REMIT_2023) > REMIT_2023_TOL) {
  fail("remittances 2023 = ", round(r23, 4), " outside ", REMIT_2023, " +/- ", REMIT_2023_TOL)
  gr("    FAIL")
} else gr("    pass")

# --- [3] within-file identities — HARD -----------------------------------------
gr("\n[3] WITHIN-FILE IDENTITIES (hard assertions, must error on breach)")
IDENT_TOL <- 0.01

check_identity <- function(f, sh, c_bal, c_cr, c_db, lab) {
  b <- annual_col(f, sh, c_bal)$value
  c <- annual_col(f, sh, c_cr)$value
  d <- annual_col(f, sh, c_db)$value
  diffs <- abs(b - (c - d))
  n_bad <- sum(diffs > IDENT_TOL, na.rm = TRUE)
  gr(sprintf("  %-46s max|balance-(credit-debit)| = %.6f  breaches=%d", lab,
             max(diffs, na.rm = TRUE), n_bad))
  if (n_bad > 0) fail(lab, ": ", n_bad, " year(s) breach balance = credit - debit")
}
check_identity("27 Services.xls", "BiP - Services", 2, 15, 28, "27 Services c2 = c15 - c28")
check_identity("28 Primary Income.xls", "BiP - Të ardhurat parësore", 2, 10, 18,
               "28 Primary Income c2 = c10 - c18")
check_identity("29 Secondary Income.xls", "BiP - Të ardhurat dytësore", 2, 6, 10,
               "29 Secondary Income c2 = c6 - c10")

# remittance credits cannot exceed the other-sectors credit total that contains them
oth <- annual_col("29 Secondary Income.xls", "BiP - Të ardhurat dytësore", 8)$value
rem <- annual_col("29 Secondary Income.xls", "BiP - Të ardhurat dytësore", 9)$value
n_bad <- sum(rem > oth + IDENT_TOL, na.rm = TRUE)
gr(sprintf("  %-46s min(other_sectors - remittances) = %.4f  breaches=%d",
           "29 c8 >= c9 (containment)", min(oth - rem, na.rm = TRUE), n_bad))
if (n_bad > 0) fail("29 Secondary Income: remittance credits exceed other-sectors credits")

# the compensation series now mapped is the NET column: assert it is exactly the
# credit less the debit, so a future column shift cannot pass silently
ce_b <- annual_col("28 Primary Income.xls", "BiP - Të ardhurat parësore", 3)$value
ce_c <- annual_col("28 Primary Income.xls", "BiP - Të ardhurat parësore", 11)$value
ce_d <- annual_col("28 Primary Income.xls", "BiP - Të ardhurat parësore", 19)$value
n_bad <- sum(abs(ce_b - (ce_c - ce_d)) > IDENT_TOL, na.rm = TRUE)
gr(sprintf("  %-46s max|net-(credit-debit)| = %.6f  breaches=%d",
           "28 c3 = c11 - c19 (compensation is net)",
           max(abs(ce_b - (ce_c - ce_d)), na.rm = TRUE), n_bad))
if (n_bad > 0) fail("28 Primary Income: mapped compensation column is not credit - debit")

# --- [4] cross-file identities — TOLERANCE + Last-Modified on breach ------------
# CLAUDE.md section 2: identity checks across separately-published files from the
# same agency assert within a stated tolerance; on breach they print the
# discrepancy alongside each file's Last-Modified header, because non-atomic
# republication is the first hypothesis to check. Discrepancies are recorded in
# limitations as observed, never reconciled or smoothed.
gr("\n[4] CROSS-FILE IDENTITIES (tolerance; breach reports, does not error)")

log_path <- file.path(VDIR, "_download_log.csv")
dl <- if (file.exists(log_path))
  read_csv(log_path, show_col_types = FALSE,
           col_types = readr::cols(.default = readr::col_character())) else NULL
lastmod <- function(f) {
  if (is.null(dl)) return("unknown")
  v <- dl$last_modified[dl$file == f]
  if (!length(v) || is.na(v[1])) "unknown" else v[1]
}

check_cross <- function(fa, sa, ca, fb, sb, cb, tol, lab) {
  a <- annual_col(fa, sa, ca); b <- annual_col(fb, sb, cb)
  m <- inner_join(a, b, by = "year", suffix = c(".a", ".b")) |>
    mutate(diff = value.a - value.b)
  bad <- m |> filter(!is.na(diff), abs(diff) > tol)
  gr(sprintf("  %-52s n=%2d  max|diff|=%.4f  tol=%.2f  breaches=%d",
             lab, nrow(m), max(abs(m$diff), na.rm = TRUE), tol, nrow(bad)))
  if (nrow(bad)) {
    gr("      BREACH — non-atomic republication is the first hypothesis:")
    gr(sprintf("        %-46s Last-Modified: %s", fa, lastmod(fa)))
    gr(sprintf("        %-46s Last-Modified: %s", fb, lastmod(fb)))
    for (k in seq_len(nrow(bad)))
      gr(sprintf("        %d: %.4f vs %.4f  diff %+.4f",
                 bad$year[k], bad$value.a[k], bad$value.b[k], bad$diff[k]))
    gr("      Recorded as observed. Not reconciled, not smoothed.")
  }
  invisible(bad)
}

check_cross("29 Secondary Income.xls", "BiP - Të ardhurat dytësore", 9,
            "31 Remittances-by channel.xls", "RemittChanels", 2, 0.50,
            "29 c9 remittances  vs  31 c2 total remittance inflow")
check_cross("26 Balance of payments - main components.xls", "BOP", 7,
            "29 Secondary Income.xls", "BiP - Të ardhurat dytësore", 2, 0.05,
            "26 c7 secondary income  vs  29 c2 balance")
check_cross("26 Balance of payments - main components.xls", "BOP", 6,
            "28 Primary Income.xls", "BiP - Të ardhurat parësore", 2, 0.10,
            "26 c6 primary income  vs  28 c2 balance")
check_cross("26 Balance of payments - main components.xls", "BOP", 5,
            "27 Services.xls", "BiP - Services", 2, 0.05,
            "26 c5 services  vs  27 c2 balance")

# The two FDI equity concepts must differ by exactly reinvested earnings:
# 33.1 (equity excl. RE) + 33.1 (reinvested earnings) == 30 c35 (equity incl. RE).
# Cross-file, so tolerance plus Last-Modified on breach (CLAUDE.md section 2).
{
  e3 <- annual_col("33.1 Direct_investment_flows_In_&_Out.xls", "In Kosova", 3)
  r4 <- annual_col("33.1 Direct_investment_flows_In_&_Out.xls", "In Kosova", 4)
  i5 <- annual_col("30 Financial account.xls", "BiP_Llogaria_financiare", 35)
  m  <- e3 |> rename(equity = value) |>
    inner_join(r4 |> rename(reinvested = value), by = "year") |>
    inner_join(i5 |> rename(incl = value), by = "year") |>
    mutate(diff = equity + reinvested - incl)
  tol <- 0.05
  bad <- m |> filter(!is.na(diff), abs(diff) > tol)
  gr(sprintf("  %-52s n=%2d  max|diff|=%.4f  tol=%.2f  breaches=%d",
             "33.1 c3 + c4  vs  30 c35 (equity + reinvested)", nrow(m),
             max(abs(m$diff), na.rm = TRUE), tol, nrow(bad)))
  if (nrow(bad)) {
    gr("      BREACH — non-atomic republication is the first hypothesis:")
    gr(sprintf("        %-46s Last-Modified: %s",
               "33.1 Direct_investment_flows_In_&_Out.xls",
               lastmod("33.1 Direct_investment_flows_In_&_Out.xls")))
    gr(sprintf("        %-46s Last-Modified: %s",
               "30 Financial account.xls", lastmod("30 Financial account.xls")))
    for (k in seq_len(nrow(bad)))
      gr(sprintf("        %d: %.4f + %.4f vs %.4f  diff %+.4f", bad$year[k],
                 bad$equity[k], bad$reinvested[k], bad$incl[k], bad$diff[k]))
    gr("      Recorded as observed. Not reconciled, not smoothed.")
  }
}

# --- [5] row counts and NA whitelist -------------------------------------------
gr("\n[5] ROW COUNTS AND NA WHITELIST")
cnt <- dat |> count(component, name = "rows")
for (i in seq_len(nrow(SPEC))) {
  got <- cnt$rows[cnt$component == SPEC$component[i]]
  got <- if (length(got)) got else 0L
  ok  <- got == SPEC$n_years[i]
  gr(sprintf("  %-24s rows=%-3d expected=%-3d %s", SPEC$component[i], got,
             SPEC$n_years[i], if (ok) "pass" else "FAIL"))
  if (!ok) fail(SPEC$component[i], ": ", got, " rows, expected ", SPEC$n_years[i])
}

# Only the directional FDI variant may be NA, and only 2007-2011, where CBK
# publishes "n/a" because the inward/outward split does not start until 2012.
NA_WHITELIST <- tibble(component = "fdi_equity_directional", year = 2007:2011)
na_rows <- dat |> filter(is.na(value)) |> select(component, year)
unexpected <- anti_join(na_rows, NA_WHITELIST, by = c("component", "year"))
missing_wl <- anti_join(NA_WHITELIST, na_rows, by = c("component", "year"))
gr(sprintf("  NA cells: %d total | whitelisted: %d | unexpected: %d | whitelisted-but-present: %d",
           nrow(na_rows), nrow(NA_WHITELIST), nrow(unexpected), nrow(missing_wl)))
if (nrow(unexpected)) {
  for (k in seq_len(nrow(unexpected)))
    gr(sprintf("      UNEXPECTED NA: %s %d", unexpected$component[k], unexpected$year[k]))
  fail(nrow(unexpected), " unexpected NA value(s)")
}
if (nrow(missing_wl)) {
  for (k in seq_len(nrow(missing_wl)))
    gr(sprintf("      whitelisted NA now has a value: %s %d",
               missing_wl$component[k], missing_wl$year[k]))
}

# --- [6] provisional coverage --------------------------------------------------
gr("\n[6] PROVISIONAL FLAGS")
pv <- dat |> count(provisional, provisional_reason, name = "rows")
for (k in seq_len(nrow(pv)))
  gr(sprintf("  provisional=%-5s rows=%-3d %s", pv$provisional[k], pv$rows[k],
             ifelse(is.na(pv$provisional_reason[k]), "-", pv$provisional_reason[k])))
stopifnot(all(dat$provisional[dat$year >= 2021 & dat$year <= 2025]))
stopifnot(!any(dat$provisional[dat$year < 2021]))

# --- write ---------------------------------------------------------------------
csv_out <- file.path(PROC_DIR, paste0("components_annual_", VINTAGE, ".csv"))
rds_out <- file.path(PROC_DIR, paste0("components_annual_", VINTAGE, ".rds"))
txt_out <- file.path(PROC_DIR, paste0("guard_report_", VINTAGE, ".txt"))

write_csv(dat, csv_out)
saveRDS(dat, rds_out)

gr("\n", strrep("=", 96))
if (length(FAILURES)) {
  gr("GUARD SUMMARY: ", length(FAILURES), " HARD FAILURE(S)")
  for (f in FAILURES) gr("  - ", f)
} else {
  gr("GUARD SUMMARY: all hard guards passed.")
}
gr(strrep("=", 96))

write_utf8(GR, txt_out)

# --- report --------------------------------------------------------------------
cat("\n\nTIDY TABLE STRUCTURE\n"); cat(strrep("-", 96), "\n")
cat("rows:", nrow(dat), " cols:", ncol(dat), "\n\n")
print(as.data.frame(
  tibble(column = names(dat),
         type   = vapply(dat, function(x) class(x)[1], character(1)),
         example = vapply(dat, function(x) {
           v <- x[!is.na(x)][1]
           if (length(v) == 0) "NA" else substr(as.character(v), 1, 46)
         }, character(1)))), row.names = FALSE, right = FALSE)

cat("\n\nANNUAL SERIES, 2004-2025 (EUR million)\n"); cat(strrep("-", 96), "\n")
wide <- dat |>
  select(year, component, value) |>
  pivot_wider(names_from = component, values_from = value) |>
  arrange(year) |>
  left_join(dat |> distinct(year, provisional) |> group_by(year) |>
              summarise(prov = any(provisional), .groups = "drop"), by = "year") |>
  mutate(across(where(is.numeric) & !year, ~ round(.x, 1)),
         prov = ifelse(prov, "p", ""))
print(as.data.frame(wide), row.names = FALSE, right = TRUE, na.print = "n/a")
cat("\n  p = provisional (2021-2024 pending the September 2026 services revision;\n")
cat("      2025 preliminary, CBK 'p' marker not machine-readable)\n")

cat("\nWrote:\n  ", csv_out, "\n  ", rds_out, "\n  ", txt_out, "\n", sep = "")

if (length(FAILURES)) stop(length(FAILURES), " hard guard failure(s) — see report above.")
cat("\nNo shares applied, nothing aggregated. Next: R/05_parse_subannual.R\n")
