# ==============================================================================
# 02_pull_cbk.R
# Download the CBK balance-of-payments and remittance time series from
#   https://bqk-kos.org/statistikat/serite-kohore/  (Statistikat > Seritë kohore)
# and cache them, byte-for-byte as served, into a VINTAGE-STAMPED directory.
#
# Twelve Excel workbooks (external sector: BOP main components, current and
# financial account, services, primary and secondary income, remittances by
# channel and by country, FDI by instrument, by country and by geography), plus
# the CBK's BOP/IIP compilation methodology PDF.
#
# The PDF is DOCUMENTATION, NOT A PIPELINE INPUT. It is cached for reference
# when mapping series and when writing the limitations section. No script parses
# it.
#
# VINTAGES. CBK republishes revised series at the SAME URLs, so a re-pull would
# otherwise overwrite and destroy the previous vintage. Each pull lands in
#   data/raw/vintage_YYYY-MM/
# defaulting to the current month. Nothing outside the active vintage is ever
# written, and the script asserts that before exiting. See data/raw/README.md.
#
# Vintage resolution: command-line arg (YYYY-MM) > CBK_VINTAGE env var > current
# month.
#   Rscript R/02_pull_cbk.R            # -> vintage_<current month>/
#   Rscript R/02_pull_cbk.R 2026-09    # -> vintage_2026-09/
#
# Writes (inside the active vintage only):
#   <CBK filename>       — the bytes as downloaded, names verbatim
#   _download_log.csv    — provenance: url, download date, server Last-Modified,
#                          size, md5
#
# Re-running does not re-download: a file already present IN THAT VINTAGE is
# left alone and its original download date is preserved (§5). Delete a file
# from the vintage directory to force a refresh of that one file.
#
# This script does NO parsing and NO mapping of series to components. Opening
# the workbooks is 03_inspect.R.
#
# Run from the piece root:  Rscript R/02_pull_cbk.R [YYYY-MM]
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(tibble)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

VINTAGE <- resolve_vintage()
VDIR    <- vintage_dir(VINTAGE)

dir.create(VDIR,     recursive = TRUE, showWarnings = FALSE)
dir.create(PROC_DIR, recursive = TRUE, showWarnings = FALSE)

# Fingerprint sibling vintages up front, so we can prove none were touched.
sib_before <- sibling_fingerprint(VINTAGE)

log_path <- file.path(VDIR, "_download_log.csv")

# Read as character throughout. readr would otherwise infer downloaded_utc as a
# datetime, and ifelse() strips POSIXct attributes back to a bare epoch numeric —
# silently turning the provenance timestamp into an integer.
prev <- if (file.exists(log_path)) {
  read_csv(log_path, show_col_types = FALSE,
           col_types = readr::cols(.default = readr::col_character()))
} else {
  tibble(file = character(), downloaded_utc = character())
}

cat("CBK time series\n")
cat("  vintage: ", VINTAGE, "\n", sep = "")
cat("  target : ", VDIR, "\n", sep = "")
other <- setdiff(list_vintages(), paste0("vintage_", VINTAGE))
cat("  other vintages present (will not be touched): ",
    if (length(other)) paste(other, collapse = ", ") else "none", "\n", sep = "")
cat(strrep("-", 78), "\n")

# --- Excel workbooks -----------------------------------------------------------
recs <- vector("list", nrow(CBK_FILES))
for (i in seq_len(nrow(CBK_FILES))) {
  f <- CBK_FILES$file[i]
  cat(sprintf("[%2d/%2d] %s\n", i, nrow(CBK_FILES), f))
  recs[[i]] <- download_cached(
    url   = cbk_url(f),
    dest  = file.path(VDIR, f),
    label = CBK_FILES$label[i]
  )
}

# --- Methodology PDF (documentation, not a pipeline input) ---------------------
cat(sprintf("[doc  ] %s\n", CBK_DOC_FILE))
doc <- download_cached(
  url   = CBK_DOC_URL,
  dest  = file.path(VDIR, CBK_DOC_FILE),
  label = "CBK BOP/IIP compilation methodology (documentation, not a pipeline input)"
)

log <- bind_rows(recs, doc) |> mutate(vintage = VINTAGE, .before = 1)

# --- Preserve the ORIGINAL download date for files that were already cached ----
# The date in the log must be when the bytes were actually fetched, not when the
# script was last re-run.
if (nrow(prev)) {
  log <- log |>
    left_join(prev |> select(file, prior_utc = downloaded_utc), by = "file") |>
    mutate(downloaded_utc = ifelse(newly_fetched | is.na(prior_utc),
                                   downloaded_utc, prior_utc)) |>
    select(-prior_utc)
}

write_csv(log, log_path)

# --- Verify-before-proceeding (house rule) -------------------------------------
cat(strrep("-", 78), "\n")
cat(sprintf("files: %d  |  newly fetched: %d  |  already cached: %d\n",
            nrow(log), sum(log$newly_fetched), sum(!log$newly_fetched)))

report <- log |>
  mutate(kb = round(bytes / 1024)) |>
  select(file, kb, last_modified, downloaded_utc, newly_fetched)
print(as.data.frame(report), row.names = FALSE, right = FALSE)

# A zero-byte or absurdly small file means the server served an error page.
tiny <- log |> filter(is.na(bytes) | bytes < 4096)
if (nrow(tiny)) {
  stop("Suspiciously small download(s) — likely an error page, not a workbook: ",
       paste(tiny$file, collapse = ", "))
}
stopifnot(nrow(log) == nrow(CBK_FILES) + 1L)
stopifnot(all(file.exists(file.path(VDIR, log$file))))

# --- Assert no other vintage was touched ---------------------------------------
sib_after <- sibling_fingerprint(VINTAGE)
if (!identical(sib_before, sib_after)) {
  ch <- union(setdiff(sib_after$path, sib_before$path),
              setdiff(sib_before$path, sib_after$path))
  stop("This pull modified files outside vintage ", VINTAGE, ": ",
       paste(basename(ch), collapse = ", "))
}
cat(sprintf("\nSibling vintages unchanged (%d files fingerprinted before and after).\n",
            nrow(sib_before)))

cat("All files present and non-trivial in size.\n")
cat("Provenance log written to", log_path, "\n")
cat("No parsing performed. Next: Rscript R/03_inspect.R", VINTAGE, "\n")
