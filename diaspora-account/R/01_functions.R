# ==============================================================================
# 01_functions.R  —  Shared helpers for the Diaspora account piece.
# Kosova diaspora-linked external inflows beyond remittances, 2010-2025.
# Author: Plator Krasniqi. Open data only. R / tidyverse / readxl.
# Sourced by 02-NN; not run directly.
#
# Design note: font registration is deliberately NOT run at source time — it is
# slow and pull scripts do not need it. Figure scripts call house_font().
# ==============================================================================
suppressWarnings(suppressMessages({ library(dplyr) }))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# The README states R >= 4.5. Enforce it rather than assert it: the pipeline uses
# the native pipe with placeholder-free lambdas and readxl behaviour that changed
# in 4.4, and an older R would fail in ways that are not obviously version-related.
R_MIN <- "4.5.0"
if (getRversion() < R_MIN)
  stop("This pipeline requires R >= ", R_MIN, "; running ", getRversion(), ".")

PROJ     <- "C:/Users/plato/Documents/kosovo-economy/diaspora-account"
RAW_DIR  <- file.path(PROJ, "data", "raw")
PROC_DIR <- file.path(PROJ, "data", "processed")
OUT_DIR  <- file.path(PROJ, "output")

# --- CBK (Banka Qendrore e Republikës së Kosovës) ------------------------------
# Statistikat > Seritë kohore.  https://bqk-kos.org/statistikat/serite-kohore/
#
# The HTML index returns HTTP 403 to non-browser clients, but the static files
# under /repository/docs/time_series/ serve normally to any client — no
# user-agent workaround needed. The site appends "?lang=en" to every link; that
# is a language-plugin artefact and has no effect on the bytes returned (same
# Content-Length, same Last-Modified), so it is dropped here.
#
# Filenames are the CBK's own, kept verbatim on disk for provenance (§5: raw is
# saved exactly as downloaded). They contain spaces and, in one case, "&".
CBK_BASE <- "https://bqk-kos.org/repository/docs/time_series/"

# `label` is the CBK's own English link text, recorded verbatim. This manifest
# carries NO mapping of files to methodology components — which sheet and row
# holds travel credits, compensation of employees or errors and omissions is
# established by 03_inspect.R against the actual workbooks, not guessed here.
CBK_FILES <- tibble::tribble(
  ~file,                                                        ~label,
  "26 Balance of payments - main components.xls",                "Balance of Payments (BOP) - main components",
  "26a Current account.xls",                                     "BOP current account",
  "27 Services.xls",                                             "Services",
  "27.1 Services by country and activity.xls",                   "Services by country and activity",
  "28 Primary Income.xls",                                       "Primary income",
  "29 Secondary Income.xls",                                     "Secondary income",
  "30 Financial account.xls",                                    "Financial account",
  "31 Remittances-by channel.xls",                               "Remittances inflows - by channel",
  "32 Remittances-by country.xls",                               "Remittances inflows - by country",
  "33.1 Direct_investment_flows_In_&_Out.xls",                   "Foreign direct investment - by financial instruments",
  "34 Foreign direct investments - by country.xls",              "Foreign direct investment - by country",
  "34a Direct investment in Kosovo by geographical breakdown.xls","Direct investment in Kosovo by geographical breakdown"
)

# --- Vintages ------------------------------------------------------------------
# CBK republishes revised series AT THE SAME URLs, so a re-pull silently
# destroys the previous vintage. Every pull therefore lands in its own
# vintage-stamped directory, data/raw/vintage_YYYY-MM/, and nothing outside the
# active vintage is ever written.
#
# This is not hypothetical here: CBK has announced that revised services
# statistics for 2021-2024 will be published in September 2026 (see the note in
# data/raw/README.md). The August 2026 vintage is unrecoverable once that lands.
#
# Vintage resolution order: command-line argument (YYYY-MM) > CBK_VINTAGE
# environment variable > current month.
CBK_VINTAGE_DEFAULT <- format(Sys.Date(), "%Y-%m")

resolve_vintage <- function(default = CBK_VINTAGE_DEFAULT) {
  a <- commandArgs(trailingOnly = TRUE)
  a <- a[grepl("^[0-9]{4}-[0-9]{2}$", a)]
  v <- if (length(a)) a[1] else Sys.getenv("CBK_VINTAGE", unset = default)
  if (!grepl("^[0-9]{4}-[0-9]{2}$", v))
    stop("Vintage must be YYYY-MM, got: ", v)
  v
}

vintage_dir <- function(v = resolve_vintage()) file.path(RAW_DIR, paste0("vintage_", v))

list_vintages <- function() {
  d <- list.dirs(RAW_DIR, full.names = FALSE, recursive = FALSE)
  sort(d[grepl("^vintage_[0-9]{4}-[0-9]{2}$", d)])
}

# Fingerprint of every vintage EXCEPT the active one, so a pull can prove it
# left the others untouched.
sibling_fingerprint <- function(active_v) {
  sibs <- setdiff(list_vintages(), paste0("vintage_", active_v))
  if (!length(sibs)) return(data.frame(path = character(), size = numeric(),
                                       mtime = character(), stringsAsFactors = FALSE))
  f <- unlist(lapply(sibs, function(s)
    list.files(file.path(RAW_DIR, s), full.names = TRUE, all.files = FALSE)))
  if (!length(f)) return(data.frame(path = character(), size = numeric(),
                                    mtime = character(), stringsAsFactors = FALSE))
  info <- file.info(f)
  d <- data.frame(path = f, size = unname(info$size),
                  mtime = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
                  stringsAsFactors = FALSE)
  d[order(d$path), , drop = FALSE]
}

# --- CBK compilation methodology ----------------------------------------------
# DOCUMENTATION, NOT A PIPELINE INPUT. Cached for reference when mapping series
# and when writing the limitations section. Albanian only. Nothing reads it
# programmatically; no script parses it.
CBK_DOC_URL  <- "https://bqk-kos.org/wp-content/uploads/2025/07/Metodologjia-e-perpilimit-te-BP-dhe-PIN.pdf"
CBK_DOC_FILE <- "Metodologjia-e-perpilimit-te-BP-dhe-PIN.pdf"

# --- ASK PxWeb -----------------------------------------------------------------
# English database node; the /PXWeb/ path variant returns HTTP 500.
ASK_BASE <- "https://askdata.rks-gov.net/api/v1/en/ASKdata"

ask_pull <- function(table_url, query, polite = TRUE) {
  q  <- pxweb::pxweb_query(query)
  px <- pxweb::pxweb_get(table_url, query = q)
  df <- as.data.frame(px, column.name.type = "text", variable.value.type = "text")
  if (polite) Sys.sleep(POLITE_SLEEP)   # house rule: 2s minimum between requests
  df
}

# --- House style ---------------------------------------------------------------
navy    <- "#1A4E8A"   # primary
rust    <- "#C0552E"   # accent / highlight / sequential high end
off     <- "#F7F5F2"   # background, sequential low end
grey_na <- "#C4C4BD"   # missing / estimated / excluded
ink     <- "#23282D"   # titles, point labels
sub     <- "#5C636B"   # subtitles, axis text, captions
grid    <- "#E4E4E0"   # major gridlines

# Register Source Sans 3. Call once at the top of a figure script.
house_font <- function() {
  suppressWarnings(suppressMessages(library(showtext)))
  sysfonts::font_add_google("Source Sans 3", "ss3")   # font_add_google is sysfonts, not showtext
  showtext::showtext_auto()
  showtext::showtext_opts(dpi = 300)
  invisible(TRUE)
}

# ggplot will not wrap text; wrap subtitles and captions explicitly.
wrap <- function(x, w) paste(strwrap(x, width = w), collapse = "\n")

# Guard reports carry Albanian place names, em-dashes and CBK's own labels.
# writeLines() emits in the session's native encoding, which mangles them on
# Windows; the committed artifact must be UTF-8.
write_utf8 <- function(lines, path) {
  con <- file(path, open = "wt", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(enc2utf8(as.character(lines)), con, useBytes = TRUE)
  invisible(path)
}

# --- Polite, cached download ---------------------------------------------------
# House rules: raw pulls are never re-downloaded on rerun (§5); 2s minimum
# between web requests (§5); bytes are saved exactly as served, before any
# parsing. Returns a one-row provenance record.
POLITE_SLEEP <- 2

cbk_url <- function(file) paste0(CBK_BASE, utils::URLencode(file, reserved = FALSE))

# Server Last-Modified, so a cached file can be compared against the live one
# without re-downloading it. Returns NA if the HEAD request fails — but WARNS
# when it does, rather than letting a broken provenance field pass as a quiet NA.
remote_last_modified <- function(url) {
  h <- tryCatch(curlGetHeaders(url, redirect = TRUE, timeout = 30L),
                error = function(e) { warning("HEAD failed for ", url, ": ",
                                              conditionMessage(e), call. = FALSE)
                                      character(0) })
  if (!length(h)) return(NA_character_)
  m <- grep("^last-modified:", h, ignore.case = TRUE, value = TRUE)
  if (!length(m)) {
    warning("no Last-Modified header served for ", url, call. = FALSE)
    return(NA_character_)
  }
  trimws(sub("^[Ll]ast-[Mm]odified:", "", m[1]))
}

download_cached <- function(url, dest, label = NA_character_, polite = TRUE) {
  fetched <- FALSE
  if (file.exists(dest)) {
    message("  cached, skipping download: ", basename(dest))
  } else {
    message("  downloading: ", basename(dest))
    utils::download.file(url, dest, mode = "wb", quiet = TRUE, method = "libcurl")
    fetched <- TRUE
    if (polite) Sys.sleep(POLITE_SLEEP)
  }
  lm <- remote_last_modified(url)
  if (polite) Sys.sleep(POLITE_SLEEP)

  tibble::tibble(
    file           = basename(dest),
    label          = label,
    url            = url,
    downloaded_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%d %H:%M:%S"),
    last_modified  = lm %||% NA_character_,
    bytes          = unname(file.size(dest)),
    md5            = unname(tools::md5sum(dest)),
    newly_fetched  = fetched
  )
}

# --- Console printing ----------------------------------------------------------
# Shared by 03_inspect.R. Truncates wide cells so a raw sheet dump stays
# readable in a terminal, and keeps the spreadsheet's own row numbers visible so
# header-row positions can be read straight off the output.
trunc_cells <- function(df, chars = 20) {
  as.data.frame(lapply(df, function(col) {
    s <- ifelse(is.na(col), "-", trimws(format(col, trim = TRUE)))
    ifelse(nchar(s) > chars, paste0(substr(s, 1, chars - 1), "\u2026"), s)
  }), stringsAsFactors = FALSE, optional = TRUE)
}

# Bottom-of-sheet rows are sparse and text-heavy — footnotes, legend entries,
# revision and break-in-series markers. A fixed-width grid truncates exactly the
# text that matters, so these are printed cell by cell, in full.
print_cells_verbatim <- function(df, rows, chars = 200) {
  rows <- rows[rows >= 1 & rows <= nrow(df)]
  if (!length(rows)) { cat("      (no rows)\n"); return(invisible(NULL)) }
  for (i in rows) {
    vals <- unlist(df[i, ], use.names = FALSE)
    keep <- which(!is.na(vals) & nzchar(trimws(as.character(vals))))
    if (!length(keep)) { cat(sprintf("      r%-4d (empty)\n", i)); next }
    for (j in keep) {
      s <- trimws(as.character(vals[j]))
      if (nchar(s) > chars) s <- paste0(substr(s, 1, chars - 1), "…")
      cat(sprintf("      r%-4d c%-3d %s\n", i, j, s))
    }
  }
  invisible(NULL)
}

print_rows <- function(df, rows, max_cols = 10, chars = 20) {
  rows <- rows[rows >= 1 & rows <= nrow(df)]
  if (!length(rows)) { cat("      (no rows)\n"); return(invisible(NULL)) }
  d <- df[rows, seq_len(min(max_cols, ncol(df))), drop = FALSE]
  d <- trunc_cells(d, chars)
  rownames(d) <- paste0("r", rows)
  colnames(d) <- paste0("c", seq_len(ncol(d)))
  print(d)
  invisible(NULL)
}
