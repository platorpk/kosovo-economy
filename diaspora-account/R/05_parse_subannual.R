# ==============================================================================
# 05_parse_subannual.R
# Extract the QUARTERLY and MONTHLY blocks of the same six CBK series that 04
# extracts annually, and append them to the 04 schema.
#
# WHY THIS NEEDS ITS OWN DATING ROUTINE. Each CBK sheet stacks three frequency
# blocks in one period column — annual, then quarterly, then monthly — and the
# year stamp inside the sub-annual blocks is irregular AND inconsistent between
# workbooks:
#   * the stamp sits sometimes on Q4 ("2009 T4"), sometimes on Q1 ("2026 T1"),
#     sometimes on December ("2025 Dhjetor"), sometimes on January ("2026 Janar")
#   * word order flips between the Albanian and English workbooks:
#     "2009 T4" but "Q4 2025"
#   * month and quarter names are Albanian in some files, English in others
#   * a "(p)" suffix marks preliminary periods in the English workbooks only
#   * 29 Secondary Income's monthly block OPENS on a bare "Janar" with no year
#     anywhere on the row
#
# The routine therefore does not try to infer the stamping convention. It:
#   1. parses every label into (year-or-NA, period-within-year)
#   2. takes the block to be a contiguous run of rows of one frequency
#   3. derives an absolute period index from the FIRST stamped row
#   4. propagates by period sequence across the whole block
#   5. ASSERTS that EVERY OTHER stamped row agrees with the propagation, and
#      errors on any disagreement
# A single mis-stamped row therefore fails loudly rather than shifting a year of
# data silently.
#
# GUARDS. Monthly sums must reconcile to the annual figures already parsed by 04,
# per component per year — a hard assertion, since both come from the same file.
# Quarterly likewise. Years that do not reconcile are REPORTED, never smoothed or
# adjusted.
#
# KNOWN DISCREPANCIES. Three component-years in the published workbooks do not
# reconcile. They are registered below, carried in the data with
# `sub_annual_discrepancy = TRUE` and a reason, and excluded from the hard
# failure — they are documented source defects, not parse defects. Nothing is
# dropped, nothing is smoothed, and the tolerance is NOT widened: any
# component-year that fails and is NOT in the registry still errors the script.
#
# OUTPUT IS WRITTEN ONLY IF ALL GUARDS PASS. Files are written to a .tmp path
# beside their destination and moved into place at the end, so a failed run
# leaves no output behind to be mistaken for good data.
#
# PROVISIONAL. Travel monthly and quarterly 2021-2024 are provisional: the
# September 2026 CBK revision covers exactly that window for services. Remittances
# and the other components are outside the revision window and are not flagged for
# it. Periods carrying CBK's own "(p)" marker are flagged separately.
#
# SCHEMA. The 04 columns, plus `quarter`. Annual rows from 04 carry
# quarter = NA and month = NA; quarterly rows carry a quarter and month = NA;
# monthly rows carry a month and quarter = NA. A combined table is
# bind_rows(components_annual_*, components_subannual_*).
#
# Writes:
#   data/processed/components_subannual_<vintage>.csv / .rds
#   data/processed/subannual_guard_report_<vintage>.txt
#
# Run from the piece root:  Rscript R/05_parse_subannual.R [YYYY-MM]
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr); library(tibble); library(readxl)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

VINTAGE <- resolve_vintage()
VDIR    <- vintage_dir(VINTAGE)
options(width = 200)

GR <- character(0)
gr <- function(...) { l <- paste0(...); GR <<- c(GR, l); cat(l, "\n", sep = "") }
FAILURES <- character(0)
fail <- function(...) FAILURES <<- c(FAILURES, paste0(...))

annual <- readRDS(file.path(PROC_DIR, paste0("components_annual_", VINTAGE, ".rds")))

# Same six series as 04. Kept here rather than shared so that a change to one
# script cannot silently redefine the other.
SPEC <- tribble(
  ~component,               ~file, ~sheet, ~col, ~code, ~entry, ~variant,
  "remittances",
    "29 Secondary Income.xls", "BiP - Të ardhurat dytësore", 9L,
    "967.1DF00Z.c.O.A.6", "credit", "baseline",
  "travel_credits",
    "27 Services.xls", "BiP - Services", 19L,
    "967.1BD000.C.X.N.6", "credit", "baseline",
  "compensation_employees",
    "28 Primary Income.xls", "BiP - Të ardhurat parësore", 3L,
    "967.1CA000.B.X.A.6", "net (credit - debit)", "baseline",
  "fdi_equity_excl_re",
    "33.1 Direct_investment_flows_In_&_Out.xls", "In Kosova", 3L,
    NA, "equity excl. reinvested earnings, net", "baseline",
  "fdi_equity_incl_re",
    "30 Financial account.xls", "BiP_Llogaria_financiare", 35L,
    NA, "equity incl. reinvested earnings, liabilities", "variant",
  "errors_omissions",
    "26 Balance of payments - main components.xls", "BOP", 14L,
    NA, "net", "baseline",
  "fdi_equity_directional",
    "33.1 Direct_investment_flows_In_&_Out.xls", "In Kosova", 7L,
    NA, "inward (directional)", "variant"
)

# --- registry of known source discrepancies ------------------------------------
# Quarterly totals that do not equal the annual figure in the SAME workbook.
# Established by the 2008-2012 and full-series reconciliation sweep: across
# 2009-2025 exactly three component-years deviate by more than floating-point
# noise. Everything else is exact to ~1e-13.
#
# `quarters` names the quarters to flag, or "all" where the discrepancy cannot be
# localised (no monthly series exists before 2014 to attribute it to a quarter).
KNOWN_DISCREPANCIES <- tribble(
  ~component,               ~freq,        ~year,  ~quarters, ~reason,
  "compensation_employees", "quarterly",  2021L,  "3,4",
    paste("Quarterly cells not updated with the 2021 revision: Q3 and Q4 fall short",
          "of the monthly series by 2.00 and 3.17 EUR million (year total 258.26 vs",
          "annual 263.43 on the net column). Q1 and Q2 match monthly exactly, and",
          "monthly reconciles to annual exactly. The deviation is -5.1669 on both",
          "the net and the credit column, so the debit side reconciles and the",
          "defect sits entirely in the credit cells. Monthly is the reliable",
          "series for this year."),
  "errors_omissions",       "quarterly",  2009L,  "all",
    paste("Quarterly year total exceeds the annual figure by 0.392 EUR million.",
          "No monthly series before 2014, so it cannot be localised to a quarter.",
          "Isolated to errors and omissions; all other components reconcile exactly",
          "in this year. Nearly offset by the opposite deviation in 2010."),
  "errors_omissions",       "quarterly",  2010L,  "all",
    paste("Quarterly year total falls short of the annual figure by 0.423 EUR",
          "million. No monthly series before 2014, so it cannot be localised to a",
          "quarter. Isolated to errors and omissions; all other components reconcile",
          "exactly in this year. Nearly offset by the opposite deviation in 2009.")
)

# --- label vocabulary ----------------------------------------------------------
MONTHS_SQ <- c("janar","shkurt","mars","prill","maj","qershor",
               "korrik","gusht","shtator","tetor","nentor","dhjetor")
MONTHS_EN <- c("january","february","march","april","may","june",
               "july","august","september","october","november","december")

# CBK's Albanian uses ë/ç; fold diacritics so "Nëntor" and "Nentor" both match.
fold <- function(x) {
  x <- tolower(trimws(gsub("[\r\n]+", " ", x)))
  x <- gsub("[ëe]", "e", x); x <- gsub("[çc]", "c", x)
  gsub("\\s+", " ", x)
}

# Parse one period label -> list(freq, year, period, preliminary)
# freq is "annual", "quarterly", "monthly" or NA. `year` is NA when unstamped.
parse_label <- function(raw) {
  if (is.na(raw)) return(list(freq = NA_character_, year = NA_integer_,
                              period = NA_integer_, prelim = FALSE))
  s <- fold(raw)
  prelim <- grepl("\\(p\\)", s)
  s <- trimws(gsub("\\(p\\)", "", s))

  yr <- regmatches(s, regexpr("(19|20)[0-9]{2}", s))
  yr <- if (length(yr)) as.integer(yr) else NA_integer_
  s2 <- trimws(gsub("(19|20)[0-9]{2}", "", s))

  if (!nzchar(s2))
    return(list(freq = "annual", year = yr, period = NA_integer_, prelim = prelim))

  q <- regmatches(s2, regexpr("^[qt]\\s*([1-4])$", s2))
  if (length(q)) {
    n <- as.integer(sub("^[qt]\\s*", "", q))
    return(list(freq = "quarterly", year = yr, period = n, prelim = prelim))
  }
  m <- match(s2, MONTHS_SQ); if (is.na(m)) m <- match(s2, MONTHS_EN)
  if (!is.na(m))
    return(list(freq = "monthly", year = yr, period = m, prelim = prelim))

  list(freq = NA_character_, year = NA_integer_, period = NA_integer_, prelim = prelim)
}

parse_column <- function(p) {
  out <- lapply(p, parse_label)
  tibble(row    = seq_along(p),
         raw    = p,
         freq   = vapply(out, `[[`, character(1), "freq"),
         year   = vapply(out, `[[`, integer(1),   "year"),
         period = vapply(out, `[[`, integer(1),   "period"),
         prelim = vapply(out, `[[`, logical(1),   "prelim"))
}

# Longest contiguous run of rows of one frequency.
block_of <- function(lab, want) {
  idx <- lab$row[!is.na(lab$freq) & lab$freq == want]
  if (!length(idx)) return(NULL)
  brk  <- c(0, which(diff(idx) != 1), length(idx))
  runs <- lapply(seq_len(length(brk) - 1), function(i) idx[(brk[i] + 1):brk[i + 1]])
  runs[[which.max(vapply(runs, length, integer(1)))]]
}

# THE DATING ROUTINE. Anchor on stamped rows, propagate by period sequence,
# assert every stamped row agrees. Errors on any disagreement.
date_block <- function(lab, rows, per_year, label) {
  b <- lab[lab$row %in% rows, ]
  stopifnot(all(diff(b$row) == 1))                  # contiguity
  if (any(is.na(b$period))) stop(label, ": unparsed period inside block")

  stamped <- which(!is.na(b$year))
  if (!length(stamped)) stop(label, ": no year stamp anywhere in the block")

  # absolute index: year * per_year + (period - 1)
  a  <- stamped[1]
  i0 <- b$year[a] * per_year + (b$period[a] - 1L)
  idx <- i0 + (seq_len(nrow(b)) - a)

  yr <- idx %/% per_year
  pd <- idx %% per_year + 1L

  # 1. the propagated period must match the label's own period on EVERY row
  bad_p <- which(pd != b$period)
  # 2. every stamped row must agree with the propagated year
  bad_y <- stamped[yr[stamped] != b$year[stamped]]

  list(rows = b$row, year = yr, period = pd, prelim = b$prelim, raw = b$raw,
       n_stamped = length(stamped),
       anchor = sprintf("r%d '%s'", b$row[a], trimws(b$raw[a])),
       bad_p = bad_p, bad_y = bad_y, tbl = b)
}

read_sheet <- function(f, sh) suppressMessages(read_excel(
  file.path(VDIR, f), sheet = sh, col_names = FALSE,
  .name_repair = "minimal", col_types = "text"))

gr(strrep("=", 100))
gr("05_parse_subannual.R — vintage ", VINTAGE)
gr(strrep("=", 100))

# --- extraction ----------------------------------------------------------------
gr("\n[1] DATING VERIFICATION")
gr(sprintf("  %-24s %-10s %-5s %-7s %-26s %s", "component", "freq", "rows",
           "stamped", "anchor", "coverage"))
gr("  ", strrep("-", 96))

out <- list()
for (i in seq_len(nrow(SPEC))) {
  s   <- SPEC[i, ]
  d   <- read_sheet(s$file, s$sheet)
  lab <- parse_column(trimws(as.character(d[[1]])))
  colv <- suppressWarnings(as.numeric(as.character(d[[s$col]])))

  for (fq in c("quarterly", "monthly")) {
    per_year <- if (fq == "quarterly") 4L else 12L
    rows <- block_of(lab, fq)
    if (is.null(rows) || length(rows) < per_year) {
      gr(sprintf("  %-24s %-10s  no %s block found", s$component, fq, fq))
      next
    }
    db <- date_block(lab, rows, per_year, paste(s$component, fq))

    ok <- length(db$bad_p) == 0 && length(db$bad_y) == 0
    gr(sprintf("  %-24s %-10s %-5d %-7d %-26s %d-%02d .. %d-%02d  %s",
               s$component, fq, length(db$rows), db$n_stamped, db$anchor,
               db$year[1], db$period[1], db$year[length(db$year)],
               db$period[length(db$period)], if (ok) "verified" else "MISMATCH"))
    if (!ok) {
      for (k in db$bad_p)
        gr(sprintf("      period mismatch r%d '%s': label says %d, sequence says %d",
                   db$rows[k], trimws(db$raw[k]), db$tbl$period[k], db$period[k]))
      for (k in db$bad_y)
        gr(sprintf("      YEAR STAMP DISAGREES r%d '%s': stamp %d, propagation %d",
                   db$rows[k], trimws(db$raw[k]), db$tbl$year[k], db$year[k]))
      fail(s$component, " ", fq, ": dating verification failed")
      next
    }

    out[[length(out) + 1]] <- tibble(
      component   = s$component,
      year        = db$year,
      quarter     = if (fq == "quarterly") db$period else NA_integer_,
      month       = if (fq == "monthly")   db$period else NA_integer_,
      freq        = fq,
      value       = colv[db$rows],
      source_file = s$file, sheet = s$sheet, series_code = s$code,
      column      = s$col, entry = s$entry, variant = s$variant,
      vintage     = VINTAGE,
      cbk_prelim  = db$prelim)
  }
}

sub <- bind_rows(out)

# --- [2] reconciliation to the annual figures parsed in 04 ---------------------
gr("\n[2] RECONCILIATION TO ANNUAL (04), per component per year")
gr("    hard assertion — same file, so the identity must hold")
REC_TOL <- 0.5   # EUR million, across 12 monthly or 4 quarterly observations

ann <- annual |> select(component, year, annual_value = value)

recon <- sub |>
  group_by(component, freq, year) |>
  summarise(n = sum(!is.na(value)), sum_value = sum(value, na.rm = FALSE),
            .groups = "drop") |>
  filter((freq == "monthly" & n == 12) | (freq == "quarterly" & n == 4)) |>
  inner_join(ann, by = c("component", "year")) |>
  mutate(diff = sum_value - annual_value)

known_key <- KNOWN_DISCREPANCIES |> select(component, freq, year) |> mutate(known = TRUE)

for (fq in c("quarterly", "monthly")) {
  r <- recon |> filter(freq == fq) |>
    left_join(known_key, by = c("component", "freq", "year")) |>
    mutate(known = !is.na(known))
  if (!nrow(r)) { gr(sprintf("  %-10s no complete years to reconcile", fq)); next }
  bad     <- r |> filter(abs(diff) > REC_TOL)
  flagged <- bad |> filter(known)
  unknown <- bad |> filter(!known)
  gr(sprintf("  %-10s complete years: %-3d  max|diff| = %.4f  tol = %.2f  deviations: %d (registered %d, UNREGISTERED %d)",
             fq, nrow(r), max(abs(r$diff)), REC_TOL, nrow(bad), nrow(flagged), nrow(unknown)))
  for (k in seq_len(nrow(flagged)))
    gr(sprintf("      [registered] %-24s %d: sum %.4f vs annual %.4f  diff %+.4f",
               flagged$component[k], flagged$year[k], flagged$sum_value[k],
               flagged$annual_value[k], flagged$diff[k]))
  for (k in seq_len(nrow(unknown)))
    gr(sprintf("      [UNREGISTERED] %-24s %d: sum %.4f vs annual %.4f  diff %+.4f",
               unknown$component[k], unknown$year[k], unknown$sum_value[k],
               unknown$annual_value[k], unknown$diff[k]))
  if (nrow(unknown))
    fail(fq, ": ", nrow(unknown), " UNREGISTERED component-year(s) do not reconcile")
}

# Registry status. A registered entry is STALE only when its deviation has gone to
# floating-point zero, i.e. the source was corrected — NOT merely when it sits
# under the reconciliation tolerance. Two of the three entries (errors_omissions
# 2009 and 2010) deviate by less than REC_TOL and so never trigger a breach; they
# are registered because they are genuinely non-zero, in a series where every
# other component-year is exact to ~1e-13.
EXACT_TOL <- 1e-6
gr("\n  registry status (current deviation of each registered entry):")
reg <- KNOWN_DISCREPANCIES |> select(component, freq, year) |>
  left_join(recon |> select(component, freq, year, diff), by = c("component", "freq", "year"))
for (k in seq_len(nrow(reg))) {
  d <- reg$diff[k]
  status <- if (is.na(d)) "NOT RECONCILABLE (incomplete year)"
            else if (abs(d) <= EXACT_TOL) "STALE — now exact, review the registry"
            else if (abs(d) <= REC_TOL)   "active, below reconciliation tolerance"
            else                          "active, breaches tolerance"
  gr(sprintf("      %-24s %-10s %d  diff %+.6f  %s",
             reg$component[k], reg$freq[k], reg$year[k], ifelse(is.na(d), NA_real_, d), status))
}

gr("\n  per-component reconciliation coverage:")
cov <- recon |> group_by(component, freq) |>
  summarise(years = n(), from = min(year), to = max(year),
            max_abs_diff = max(abs(diff)), .groups = "drop")
for (k in seq_len(nrow(cov)))
  gr(sprintf("    %-24s %-10s %2d years %d-%d  max|diff| %.4f",
             cov$component[k], cov$freq[k], cov$years[k], cov$from[k], cov$to[k],
             cov$max_abs_diff[k]))

# --- [3] provisional flags -----------------------------------------------------
REV_REASON  <- "CBK services revision announced for September 2026 (travel only)"
PREL_REASON <- "CBK preliminary marker (p) on the period label"

sub <- sub |>
  mutate(
    in_revision_window  = component == "travel_credits" & year >= 2021L & year <= 2024L,
    provisional         = in_revision_window | cbk_prelim,
    provisional_reason  = case_when(
      in_revision_window & cbk_prelim ~ paste(REV_REASON, "; ", PREL_REASON),
      in_revision_window              ~ REV_REASON,
      cbk_prelim                      ~ PREL_REASON,
      TRUE                            ~ NA_character_)) |>
  select(-in_revision_window)

gr("\n[3] PROVISIONAL FLAGS")
pv <- sub |> count(freq, provisional, provisional_reason, name = "rows")
for (k in seq_len(nrow(pv)))
  gr(sprintf("  %-10s provisional=%-5s rows=%-5d %s", pv$freq[k], pv$provisional[k],
             pv$rows[k], ifelse(is.na(pv$provisional_reason[k]), "-", pv$provisional_reason[k])))
gr("  Remittances is outside the September revision window and is not flagged for it.")

# --- [3b] sub-annual discrepancy flags -----------------------------------------
# Both series are carried. Nothing is dropped or adjusted; the flag marks the
# rows a downstream selection has to reckon with. Section 4.3 selects monthly.
flag_rows <- KNOWN_DISCREPANCIES |>
  rowwise() |>
  mutate(q = list(if (quarters == "all") 1:4 else as.integer(strsplit(quarters, ",")[[1]]))) |>
  ungroup() |>
  tidyr::unnest(q) |>
  transmute(component, freq, year, quarter = q,
            sub_annual_discrepancy = TRUE, discrepancy_reason = reason)

sub <- sub |>
  left_join(flag_rows, by = c("component", "freq", "year", "quarter")) |>
  mutate(sub_annual_discrepancy = !is.na(sub_annual_discrepancy))

gr("\n[3b] SUB-ANNUAL DISCREPANCY FLAGS")
gr(sprintf("  registry entries: %d | rows flagged: %d",
           nrow(KNOWN_DISCREPANCIES), sum(sub$sub_annual_discrepancy)))
fl <- sub |> filter(sub_annual_discrepancy) |> count(component, freq, year, name = "rows")
for (k in seq_len(nrow(fl)))
  gr(sprintf("    %-24s %-10s %d  rows=%d", fl$component[k], fl$freq[k], fl$year[k], fl$rows[k]))
gr("  Both series are carried in full. Nothing dropped, nothing smoothed,")
gr("  tolerance unchanged. Section 4.3 selects monthly and the piece says why.")

# --- [4] shape -----------------------------------------------------------------
gr("\n[4] OUTPUT SHAPE")
shp <- sub |> group_by(component, freq) |>
  summarise(n = n(), from = sprintf("%d-%02d", min(year),
              min(ifelse(freq[1] == "monthly", month, quarter), na.rm = TRUE)),
            to = max(year), .groups = "drop")
for (k in seq_len(nrow(shp)))
  gr(sprintf("  %-24s %-10s n=%-4d through %d", shp$component[k], shp$freq[k],
             shp$n[k], shp$to[k]))
gr(sprintf("  total rows: %d | columns: %d", nrow(sub), ncol(sub)))

# --- write ---------------------------------------------------------------------
csv_out <- file.path(PROC_DIR, paste0("components_subannual_", VINTAGE, ".csv"))
rds_out <- file.path(PROC_DIR, paste0("components_subannual_", VINTAGE, ".rds"))
txt_out <- file.path(PROC_DIR, paste0("subannual_guard_report_", VINTAGE, ".txt"))

gr("\n", strrep("=", 100))
if (length(FAILURES)) {
  gr("GUARD SUMMARY: ", length(FAILURES), " HARD FAILURE(S)")
  for (f in FAILURES) gr("  - ", f)
} else gr("GUARD SUMMARY: all hard guards passed.")
gr(strrep("=", 100))

# Write only if every guard passed. Output goes to .tmp paths beside the
# destination and is moved into place at the very end, so a failed run leaves no
# file behind that could be mistaken for good data.
if (length(FAILURES)) {
  cat("\nNo output written — guards failed.\n")
  stop(length(FAILURES), " hard guard failure(s) — see report above.")
}

tmp <- paste0(c(csv_out, rds_out, txt_out), ".tmp")
on.exit(unlink(tmp[file.exists(tmp)]), add = TRUE)
write_csv(sub, tmp[1]); saveRDS(sub, tmp[2]); write_utf8(GR, tmp[3])
ok <- file.rename(tmp, c(csv_out, rds_out, txt_out))
if (!all(ok)) stop("Failed to move output into place: ",
                   paste(basename(tmp[!ok]), collapse = ", "))

cat("\nWrote:\n  ", csv_out, "\n  ", rds_out, "\n  ", txt_out, "\n", sep = "")
