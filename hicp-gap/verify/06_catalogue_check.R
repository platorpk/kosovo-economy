# ==============================================================================
# 06_catalogue_check.R  --  VERIFICATION ONLY (pre-publication vintage check)
# Downloads Eurostat's catalogue table of contents into today's raw folder and
# asserts that both source tables still carry the release the piece was built
# on: "last update of data" for prc_hicp_minr and prc_hicp_iw must equal the
# LAST UPDATE stamp in the committed XK+EA extracts. If Eurostat has published
# a newer release, the script stops: re-downloading is a decision, not a fix.
#
# Source: Eurostat SDMX 2.1 dissemination API, catalogue/toc/txt?lang=en
#   (the same endpoint as verify/02_peers.R section 0).
# Reads:  data/raw/<date>/eurostat_prc_hicp_{minr,iw}_XK_EA.rds  (LAST UPDATE)
# Writes: data/raw/<today>/eurostat_catalogue_toc_en.txt          raw bytes
#   Cached: if today's folder already holds the file, no request is made.
# build/04_readme.R reads the latest saved catalogue and repeats the assertion,
# so the README's vintage sentence cannot outlive a failed check.
#
# Run from the piece root:  Rscript verify/06_catalogue_check.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(stringr)
}))

PROJ   <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
API    <- "https://ec.europa.eu/eurostat/api/dissemination/"
TABLES <- c("prc_hicp_minr", "prc_hicp_iw")

# Vintage of the committed extracts
dated <- sort(list.dirs(file.path(PROJ, "data/raw"), recursive = FALSE), decreasing = TRUE)
dated <- dated[file.exists(file.path(dated, "eurostat_prc_hicp_minr_XK_EA.rds"))]
stopifnot(length(dated) >= 1)
lu <- unique(c(readRDS(file.path(dated[1], "eurostat_prc_hicp_minr_XK_EA.rds"))[["LAST UPDATE"]],
               readRDS(file.path(dated[1], "eurostat_prc_hicp_iw_XK_EA.rds"))[["LAST UPDATE"]]))
stopifnot(length(lu) == 1)
vintage <- format(as.Date(substr(lu, 1, 8), "%d/%m/%y"), "%d.%m.%Y")
cat("committed extracts:", dated[1], "| LAST UPDATE:", lu, "->", vintage, "\n")

# Today's catalogue, saved raw before parsing
toc_dir  <- file.path(PROJ, "data/raw", as.character(Sys.Date()))
toc_file <- file.path(toc_dir, "eurostat_catalogue_toc_en.txt")
if (file.exists(toc_file)) {
  cat("raw already present, skipping download:", toc_file, "\n")
} else {
  dir.create(toc_dir, recursive = TRUE, showWarnings = FALSE)
  download.file(paste0(API, "catalogue/toc/txt?lang=en"), toc_file, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
}

toc <- read_tsv(toc_file, col_types = cols(.default = col_character()), progress = FALSE)
cat("TOC rows:", nrow(toc), "| columns:", paste(names(toc), collapse = ", "), "\n")
stopifnot(all(c("code", "last update of data") %in% names(toc)))
hit <- toc |> filter(code %in% TABLES) |>
  distinct(code, last_update = `last update of data`, data_end = `data end`)
print(as.data.frame(hit), row.names = FALSE)

stopifnot(setequal(hit$code, TABLES), !anyDuplicated(hit$code))
if (!all(hit$last_update == vintage)) {
  stop("Eurostat's catalogue no longer shows the ", vintage, " release for both tables. ",
       "Stop and report: re-downloading is a decision, not a fix.")
}
cat("PASS: catalogue retrieved", basename(toc_dir), "shows the", vintage,
    "release for", paste(TABLES, collapse = " and "), "\n")
