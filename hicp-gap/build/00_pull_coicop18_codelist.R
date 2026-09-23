# ==============================================================================
# 00_pull_coicop18_codelist.R
# Pulls Eurostat's COICOP 2018 codelist (labels for the coicop18 dimension of
# prc_hicp_minr / prc_hicp_iw) from the SDMX 2.1 dissemination API. The codelist
# version is read from the prc_hicp_minr data structure definition, not typed,
# and that exact version is requested.
#
# Writes, under data/raw/<download-date>/ (raw bytes as downloaded):
#   eurostat_prc_hicp_minr_dsd.xml            data structure definition
#   eurostat_codelist_COICOP18_<version>.tsv  codelist, TSV, no header, code<TAB>label
# Cached: skipped if any date folder already holds both files.
#
# Run from the piece root:  Rscript build/00_pull_coicop18_codelist.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(stringr)
}))

PROJ <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
BASE <- "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/"
DIVS <- sprintf("CP%02d", 1:13)

raw_root <- file.path(PROJ, "data/raw")
has_cl <- function(d) file.exists(file.path(d, "eurostat_prc_hicp_minr_dsd.xml")) &&
  length(list.files(d, "^eurostat_codelist_COICOP18_.*\\.tsv$")) == 1
dated <- sort(list.dirs(raw_root, recursive = FALSE), decreasing = TRUE)
dated <- dated[grepl("^\\d{4}-\\d{2}-\\d{2}$", basename(dated))]
hit <- dated[vapply(dated, has_cl, logical(1))]

if (length(hit)) {
  raw_dir <- hit[1]
  cat("raw already present, skipping download:", raw_dir, "\n")
} else {
  raw_dir <- file.path(raw_root, as.character(Sys.Date()))
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  dsd_f <- file.path(raw_dir, "eurostat_prc_hicp_minr_dsd.xml")
  download.file(paste0(BASE, "datastructure/ESTAT/PRC_HICP_MINR/latest"), dsd_f,
                mode = "wb", quiet = TRUE)
  Sys.sleep(2)
  ref <- str_extract_all(paste(readLines(dsd_f, warn = FALSE), collapse = ""),
                         '<Ref agencyID="ESTAT" class="Codelist" id="COICOP18"[^>]*>')[[1]]
  ver <- unique(str_match(ref, 'version="([^"]+)"')[, 2])
  stopifnot(length(ver) == 1, !is.na(ver))
  cat("DSD references COICOP18 version", ver, "\n")
  cl_f <- file.path(raw_dir, sprintf("eurostat_codelist_COICOP18_%s.tsv", ver))
  download.file(sprintf("%scodelist/ESTAT/COICOP18/%s?format=TSV&lang=en", BASE, ver),
                cl_f, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
}

cl_f <- list.files(raw_dir, "^eurostat_codelist_COICOP18_.*\\.tsv$", full.names = TRUE)
cl <- read_tsv(cl_f, col_names = c("code", "label"), col_types = "cc", progress = FALSE)
cat("codelist:", basename(cl_f), "| rows:", nrow(cl), "| cols:", paste(names(cl), collapse = ", "), "\n")
stopifnot(!anyDuplicated(cl$code), all(c("TOTAL", DIVS) %in% cl$code),
          !any(grepl("[\r\n]", cl$label)), !anyNA(cl$label))

cat("\nDivision labels (verbatim from the codelist):\n")
print(as.data.frame(cl |> filter(code %in% DIVS) |> arrange(code)), row.names = FALSE, right = FALSE)
