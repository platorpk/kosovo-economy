# ==============================================================================
# 03_inspect.R
# Reconnaissance on the cached CBK workbooks. For every file in data/raw/, and
# every sheet within it: sheet names, dimensions, the first 12 rows and the
# LAST 5 rows.
#
# Why the tail matters: CBK workbooks carry footnotes, revision markers and
# break-in-series notes at the bottom of the sheet, and those determine whether
# a series is comparable across its full history. A head-only dump hides them.
#
# Everything is read with col_names = FALSE so that header rows appear as data
# and their position can be read straight off the output. Spreadsheet row
# numbers are printed as r1, r2, ... to make that position explicit.
#
# This script is PURE RECONNAISSANCE. It writes nothing, parses nothing, and
# maps no series to any methodology component. Output goes to stdout only.
#
# Run from the piece root:  Rscript R/03_inspect.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(readxl)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

options(width = 200)

HEAD_N   <- 12
TAIL_N   <- 5
MAX_COLS <- 10

# Inspect one vintage at a time. Same resolution as 02: command-line arg
# (YYYY-MM) > CBK_VINTAGE env var > current month.
#   Rscript R/03_inspect.R 2026-08
VINTAGE <- resolve_vintage()
VDIR    <- vintage_dir(VINTAGE)
if (!dir.exists(VDIR))
  stop("No such vintage: ", VDIR, "\nAvailable: ", paste(list_vintages(), collapse = ", "))

xl <- list.files(VDIR, pattern = "\\.xlsx?$", full.names = TRUE)
xl <- xl[!grepl("^~\\$", basename(xl))]           # skip Excel lock files
xl <- sort(xl)

if (!length(xl)) stop("No workbooks in ", VDIR, " — run R/02_pull_cbk.R first.")

cat(strrep("=", 100), "\n")
cat("CBK workbook reconnaissance — vintage", VINTAGE, "—", length(xl), "files in", VDIR, "\n")
cat("head:", HEAD_N, "rows | tail:", TAIL_N, "rows | first", MAX_COLS, "columns | col_names = FALSE\n")
cat(strrep("=", 100), "\n")

for (path in xl) {
  fname <- basename(path)
  cat("\n\n"); cat(strrep("#", 100), "\n")
  cat("# FILE: ", fname, "\n", sep = "")
  cat("#   ", round(file.size(path) / 1024), " KB\n", sep = "")

  sheets <- tryCatch(excel_sheets(path), error = function(e) {
    cat("#   !! could not read sheet list: ", conditionMessage(e), "\n", sep = ""); character(0)
  })
  if (!length(sheets)) next

  cat("#   sheets (", length(sheets), "): ", paste(sheets, collapse = " | "), "\n", sep = "")
  cat(strrep("#", 100), "\n")

  for (sh in sheets) {
    d <- tryCatch(
      suppressMessages(read_excel(path, sheet = sh, col_names = FALSE,
                                  .name_repair = "minimal", col_types = "text")),
      error = function(e) e
    )
    cat("\n  --- sheet: ", sh, " ", strrep("-", max(0, 60 - nchar(sh))), "\n", sep = "")

    if (inherits(d, "error")) {
      cat("      !! read failed: ", conditionMessage(d), "\n", sep = ""); next
    }
    if (nrow(d) == 0 || ncol(d) == 0) {
      cat("      (empty sheet)\n"); next
    }

    cat("      dim: ", nrow(d), " rows x ", ncol(d), " cols",
        if (ncol(d) > MAX_COLS) paste0("  (showing first ", MAX_COLS, ")") else "", "\n\n", sep = "")

    cat("      HEAD (first ", min(HEAD_N, nrow(d)), " rows):\n", sep = "")
    print_rows(d, seq_len(HEAD_N), max_cols = MAX_COLS)

    # Only show a tail if it is not already inside the head. Printed cell by cell
    # and untruncated: footnote and break-in-series text is the whole point of
    # looking at the bottom of the sheet, and a truncated grid would lose it.
    if (nrow(d) > HEAD_N) {
      cat("\n      TAIL (last ", min(TAIL_N, nrow(d) - HEAD_N), " rows) — footnotes, revision and break-in-series markers, verbatim:\n", sep = "")
      print_cells_verbatim(d, seq(max(HEAD_N + 1, nrow(d) - TAIL_N + 1), nrow(d)))
    } else {
      cat("\n      (sheet shorter than ", HEAD_N, " rows — tail already shown above)\n", sep = "")
    }
  }
}

# --- Reference documents, listed but never parsed ------------------------------
pdfs <- list.files(VDIR, pattern = "\\.pdf$", full.names = TRUE)
if (length(pdfs)) {
  cat("\n\n", strrep("=", 100), "\n", sep = "")
  cat("Reference documents in this vintage (documentation, not pipeline inputs — not parsed):\n")
  for (p in pdfs) cat("  ", basename(p), sprintf("  (%d KB)", round(file.size(p) / 1024)), "\n", sep = "")
}

cat("\n", strrep("=", 100), "\n", sep = "")
cat("Reconnaissance complete. Nothing written, nothing parsed, no series mapped.\n")
