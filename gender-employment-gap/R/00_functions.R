# ==============================================================================
# 00_functions.R  —  Shared helpers for gender-employment-gap.
# Paths, the cached ASK / document downloads and their provenance log, guards,
# the wording guard, and the figures.json writer.
# Author: Plator Krasniqi. Open data only.
# Sourced by every numbered script; NOT runnable on its own.
#
# Numbering: the scripts keep the numbers of the private working folder they
# were developed in, so the sequence has gaps (no 02, 06, 07). Run order is
# numeric: 01_e, 01_e2, 01_e3, 03, 04, 04b, 05, 08.
#
# PROJ is the working directory, not an absolute path, so the folder runs
# wherever it is checked out. Every script must be run from the piece root;
# the guard below stops otherwise.
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr); library(purrr)
  library(stringr); library(tibble); library(ggplot2); library(jsonlite)
}))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

R_MIN <- "4.5.0"
if (getRversion() < R_MIN)
  stop("This pipeline requires R >= ", R_MIN, "; running ", getRversion(), ".")

PROJ <- normalizePath(getwd(), winslash = "/")
if (basename(PROJ) != "gender-employment-gap")
  stop("Run from the piece root (gender-employment-gap/); working directory is ", PROJ)
RAW_DIR   <- file.path(PROJ, "data", "raw")
PROC_DIR  <- file.path(PROJ, "data", "processed")
CHECK_DIR <- file.path(PROJ, "checks")     # verification outputs; gitignored, not published
for (d in c(RAW_DIR, PROC_DIR, CHECK_DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

POLITE_SLEEP <- 2   # house rule: 2 s minimum between web requests

# --- Polite, cached download ---------------------------------------------------
# Raw pulls are never re-downloaded on rerun; bytes saved exactly as served
# before any parsing. A fetch writes a provenance row to the download log.
LOG_PATH <- file.path(RAW_DIR, "_download_log.csv")
RAW_USED <- new.env(); RAW_USED$files <- character(0)

log_download <- function(file, url, source, fetched) {
  RAW_USED$files <- union(RAW_USED$files, file)   # raw files touched in this run
  row <- tibble(file = file, source = source, url = url,
                accessed_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%d %H:%M:%S"),
                bytes = unname(file.size(file.path(RAW_DIR, file))),
                md5 = unname(tools::md5sum(file.path(RAW_DIR, file))),
                newly_fetched = fetched)
  prev <- if (file.exists(LOG_PATH))
    read_csv(LOG_PATH, show_col_types = FALSE,
             col_types = cols(.default = col_character())) else NULL
  if (!is.null(prev) && file %in% prev$file && !fetched) return(invisible(row))
  prev <- if (!is.null(prev)) prev[prev$file != file, , drop = FALSE] else NULL
  out <- bind_rows(prev, mutate(row, across(everything(), as.character)))
  write_csv(out, LOG_PATH)
  invisible(row)
}

# Access dates come from the download log, never from the run date: the log keeps
# the time each raw file was actually fetched (cached reruns do not rewrite it).
# Files = those touched through the cached helpers in this run, plus `extra` (raw
# files the calling script reads directly). Stops if a file has no log row, or a
# row not marked as fetched (its timestamp would be a logging time).
accessed_from_log <- function(extra = character()) {
  files <- union(RAW_USED$files, extra)
  stopifnot(length(files) > 0)
  lg <- read_csv(LOG_PATH, show_col_types = FALSE, col_types = cols(.default = col_character()))
  unmatched <- setdiff(files, lg$file)
  if (length(unmatched)) stop("Raw files with no row in _download_log.csv: ",
                              paste(unmatched, collapse = ", "))
  rows <- lg[lg$file %in% files, ]
  not_fetched <- rows$file[rows$newly_fetched != "TRUE"]
  if (length(not_fetched)) stop("Log rows not marked as fetched (no true access time): ",
                                paste(not_fetched, collapse = ", "))
  d <- as.Date(substr(rows$accessed_utc, 1, 10))
  stopifnot(nrow(rows) == length(files), !anyNA(d))
  first <- format(min(d)); last <- format(max(d))
  list(first = first, last = last, n_files = length(files),
       display = if (first == last) first else paste(first, "to", last))
}

download_cached <- function(url, file, source) {
  dest <- file.path(RAW_DIR, file)
  fetched <- FALSE
  if (file.exists(dest)) {
    cat("raw already present, skipping download:", file, "\n")
  } else {
    cat("downloading:", file, "\n")
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    utils::download.file(url, dest, mode = "wb", quiet = TRUE, method = "libcurl")
    fetched <- TRUE
    Sys.sleep(POLITE_SLEEP)
  }
  log_download(file, url, source, fetched)
  dest
}

# --- ASK PxWeb -----------------------------------------------------------------
# English database node (resolved by probe in census-vacancy, 2026-07-13).
ASK_BASE <- "https://askdata.rks-gov.net/api/v1/en/ASKdata"

ask_pull_cached <- function(table_url, query, file) {
  dest <- file.path(RAW_DIR, file)
  fetched <- FALSE
  if (file.exists(dest)) {
    cat("raw already present, skipping download:", file, "\n")
  } else {
    cat("pulling ASK", basename(table_url), "\n")
    px <- pxweb::pxweb_get(table_url, query = pxweb::pxweb_query(query))
    d  <- as.data.frame(px, column.name.type = "text", variable.value.type = "text")
    write_csv(d, dest)                       # save raw before parsing
    fetched <- TRUE
    Sys.sleep(POLITE_SLEEP)
  }
  log_download(file, table_url, "ASK PxWeb", fetched)
  read_csv(dest, show_col_types = FALSE, name_repair = "minimal")
}

# --- Guards --------------------------------------------------------------------
stop_if_unmatched <- function(keys, ref, label) {
  bad <- setdiff(keys, ref)
  if (length(bad)) stop("Unmatched ", label, " keys: ", paste(bad, collapse = ", "))
}

verify_block <- function(df, label) {
  cat("\n--- verify:", label, "---\nrows:", nrow(df), "| cols:",
      paste(names(df), collapse = ", "), "\n")
  print(utils::head(as.data.frame(df), 4), row.names = FALSE)
}

# --- Check outputs (checks/, not published) --------------------------------------
diag_theme <- theme_minimal(base_size = 9) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        plot.title = element_text(face = "bold"))

hist_panel <- function(df, vars, file, title) {
  long <- df |> select(all_of(vars)) |>
    pivot_longer(everything(), names_to = "variable", values_to = "value") |>
    filter(!is.na(value))
  p <- ggplot(long, aes(value)) +
    geom_histogram(bins = 15, fill = "#1A4E8A", colour = "white") +
    facet_wrap(~variable, scales = "free", ncol = 3) +
    labs(title = title, x = NULL, y = "count") + diag_theme
  ggsave(file.path(CHECK_DIR, file), p, width = 9,
         height = 2.4 * ceiling(length(vars) / 3) + 0.6, dpi = 150)
}

write_numbers <- function(x, cand) {
  path <- file.path(CHECK_DIR, paste0(cand, "_numbers.json"))
  writeLines(enc2utf8(toJSON(x, auto_unbox = TRUE, pretty = TRUE, digits = NA,
                             na = "null")), path, useBytes = TRUE)
  cat("wrote", path, "\n")
}

write_utf8_csv <- function(df, file) write_csv(df, file.path(CHECK_DIR, file))

# --- figures.json ----------------------------------------------------------------
# Every number the README quotes is written here by the script that computes it;
# 08_methods_note.R reads only this file.
FJ_PATH <- file.path(PROC_DIR, "figures.json")
fj_read  <- function() if (file.exists(FJ_PATH)) fromJSON(FJ_PATH, simplifyVector = FALSE) else list()
fj_merge <- function(x) {
  fj <- fj_read()
  for (k in names(x)) fj[[k]] <- x[[k]]
  writeLines(enc2utf8(toJSON(fj, auto_unbox = TRUE, pretty = TRUE, digits = NA)), FJ_PATH,
             useBytes = TRUE)
  invisible(fj)
}

# --- Wording guard (CLAUDE.md §1) ---------------------------------------------------
# Banned terms in any reader-facing text: the README and catalogue row (08) and
# every string drawn in the figure (05). Errors, naming each hit and where.
BANNED_WORDS <- c("\\bKosovo\\b", "\\bcauses?\\b", "\\bdrives?\\b", "leads? to", "results? in",
                  "\\breduces?\\b", "\\bboosts?\\b", "because of", "the effect of", "\\bimpact\\b",
                  "\\bexplains?\\b")
check_wording <- function(txt, where) {
  txt  <- paste(txt, collapse = "\n")
  hits <- BANNED_WORDS[vapply(BANNED_WORDS, function(b) grepl(b, txt, ignore.case = TRUE, perl = TRUE),
                              logical(1))]
  if (length(hits)) stop("Forbidden wording in ", where, ": ", paste(hits, collapse = ", "))
  invisible(TRUE)
}
