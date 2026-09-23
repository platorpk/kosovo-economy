# ==============================================================================
# 01_coverage.R  --  VERIFICATION ONLY
# Checks whether Eurostat HICP data support a division-level (ECOICOP ver.2,
# CP01-CP13) comparison of Kosova (XK) and the euro area (EA). It does not
# compute inflation rates, differentials or any decomposition.
#
# Source tables (Eurostat > Economy and finance > Prices > Harmonised index of
# consumer prices (HICP)), both pulled as the full bulk table with no filters
# from the SDMX 2.1 dissemination API (SDMX-CSV, gzip):
#   prc_hicp_iw    HICP - item weights (annual)
#   prc_hicp_minr  HICP - monthly data (index)  [the JSON API errors on this
#                  table, so only the unfiltered bulk route is used]
#
# Writes, under data/raw/<download-date>/:
#   eurostat_<table>_bulk.csv.gz   the bytes as downloaded (house rule: save raw
#                                  before parsing). prc_hicp_minr is ~107 MB,
#                                  over GitHub's 100 MB limit, so both bulk files
#                                  are gitignored (hicp-gap/.gitignore). To
#                                  regenerate: delete the date folder and rerun.
#                                  Eurostat revises, so a rerun may not reproduce
#                                  the same bytes; the .rds files below are the
#                                  committed record of this pull.
#   eurostat_<table>_XK_EA.rds     the bulk table filtered to geo XK and EA
#
# Concept notes:
#   - Bulk SDMX-CSV names the time column TIME_PERIOD and the value column
#     OBS_VALUE. Both tables are harmonised at load to `time` and `values`.
#   - prc_hicp_iw has no `unit` dimension; it carries `statinfo` (= IW, item
#     weight, per mille) instead. prc_hicp_minr carries `unit`.
#     Per mille: division weights sum to 1000 (± publication rounding) in every
#     geo-year of this pull; see the guard in section 2. Eurostat's dataset
#     description states: "for each country and year, the item weights add up
#     to 1,000" (Data Browser, prc_hicp_iw, "Show description"; retrieved
#     2026-09-23: https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_iw/default/table).
#   - `EA` is Eurostat's changing-composition euro area aggregate, as distinct
#     from fixed-composition codes such as EA20.
#   - Division = coicop18 code matching ^CP\d{2}$.
#
# Run from the piece root:  Rscript verify/01_coverage.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(tidyr); library(stringr)
}))
options(timeout = 1800, width = 200)

PROJ  <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
BASE  <- "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/"
GEOS  <- c("XK", "EA")
DIVS  <- sprintf("CP%02d", 1:13)
TABLES <- c("prc_hicp_iw", "prc_hicp_minr")

# ------------------------------------------------------------------------------
# 0. Raw pull, cached. Reuse the latest date folder that already holds both
#    bulk files; download into today's folder only if none does.
# ------------------------------------------------------------------------------
raw_root <- file.path(PROJ, "data/raw")
bulk_name <- function(t) sprintf("eurostat_%s_bulk.csv.gz", t)
have_all <- function(d) all(file.exists(file.path(d, bulk_name(TABLES))))
dated <- sort(list.dirs(raw_root, recursive = FALSE), decreasing = TRUE)
dated <- dated[grepl("^\\d{4}-\\d{2}-\\d{2}$", basename(dated))]
dated <- dated[vapply(dated, have_all, logical(1))]
raw_dir <- if (length(dated)) dated[1] else file.path(raw_root, as.character(Sys.Date()))
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
cat("raw folder:", raw_dir, "\n")

for (t in TABLES) {
  f <- file.path(raw_dir, bulk_name(t))
  if (file.exists(f)) {
    cat("raw already present, skipping download:", f, "\n")
  } else {
    u <- paste0(BASE, t, "?format=SDMX-CSV&compressed=true")
    cat("downloading", u, "\n")
    download.file(u, f, mode = "wb", quiet = TRUE)
    Sys.sleep(2)
  }
  cat(sprintf("  %s  %.1f MB\n", basename(f), file.size(f) / 1e6))
}

# ------------------------------------------------------------------------------
# 1. Load, harmonise column names, filter to XK + EA, save .rds
# ------------------------------------------------------------------------------
load_table <- function(t, dims) {
  f <- file.path(raw_dir, bulk_name(t))
  d <- read_csv(f, col_types = cols(.default = col_character()), progress = FALSE)
  cat("\n==", t, "== bulk rows:", nrow(d), "\n")
  cat("  columns as published:", paste(names(d), collapse = ", "), "\n")
  stopifnot(xor("TIME_PERIOD" %in% names(d), "time" %in% names(d)))
  if ("TIME_PERIOD" %in% names(d)) d <- rename(d, time = TIME_PERIOD)
  if ("OBS_VALUE"   %in% names(d)) d <- rename(d, values = OBS_VALUE)
  stopifnot(all(c("freq", dims, "coicop18", "geo", "time", "values") %in% names(d)))
  cat("  LAST UPDATE values:", paste(unique(d[["LAST UPDATE"]]), collapse = " | "), "\n")
  cat("  euro-area geo codes in bulk:",
      paste(sort(unique(grep("^EA", d$geo, value = TRUE))), collapse = ", "), "\n")
  d <- d |> filter(geo %in% GEOS) |> mutate(values = as.numeric(values))
  stopifnot(setequal(unique(d$geo), GEOS))
  rds <- file.path(raw_dir, sprintf("eurostat_%s_XK_EA.rds", t))
  saveRDS(d, rds)
  cat("  XK+EA rows:", nrow(d), "-> saved", rds, "\n")
  print(head(as.data.frame(d), 3), row.names = FALSE)
  d
}
iw   <- load_table("prc_hicp_iw",   dims = "statinfo")   # no unit dimension
minr <- load_table("prc_hicp_minr", dims = "unit")

# ------------------------------------------------------------------------------
# 2. Guards: facts verified in an earlier session, re-asserted on this pull
# ------------------------------------------------------------------------------
cat("\n== GUARDS: prc_hicp_iw ==\n")
cat("  statinfo:", paste(unique(iw$statinfo), collapse = ", "),
    "| freq:", paste(unique(iw$freq), collapse = ", "), "\n")
stopifnot(all(iw$statinfo == "IW"))                      # single measure: item weight
iw_div <- iw |> filter(str_detect(coicop18, "^CP\\d{2}$")) |>
  mutate(year = as.integer(time))

iw_years <- lapply(split(iw_div$year, iw_div$geo), function(y) sort(unique(y)))
stopifnot(identical(iw_years$XK, 2015:2026))
stopifnot(identical(iw_years$EA, 1996:2026))

iw_cells <- iw_div |> group_by(geo, year) |>
  summarise(n = n(), n_distinct = n_distinct(coicop18),
            all13 = setequal(coicop18, DIVS), n_na = sum(is.na(values)),
            wsum = sum(values), .groups = "drop")
stopifnot(all(iw_cells$n == 13), all(iw_cells$n_distinct == 13),
          all(iw_cells$all13), all(iw_cells$n_na == 0))
cat(sprintf("  max |sum of division weights - 1000| across %d geo-years: %.2e\n",
            nrow(iw_cells), max(abs(iw_cells$wsum - 1000))))
# Weights are published to 2 decimals, so 13 rounded division weights can
# deviate from 1000 by at most 13 * 0.005 = 0.065.
stopifnot(all(abs(iw_cells$wsum - 1000) <= 13 * 0.005 + 1e-9))
cat("  PASS: XK 2015-2026, EA 1996-2026, 13 divisions every geo-year, weights sum to 1000\n")

cat("\n== GUARDS: prc_hicp_minr ==\n")
stopifnot("I15" %in% minr$unit)
cat("  PASS: harmonised columns present; unit I15 present\n")

# ------------------------------------------------------------------------------
# 3. Report: prc_hicp_minr
# ------------------------------------------------------------------------------
cat("\n== 3a. Units ==\n")
cat("  freq values:", paste(unique(minr$freq), collapse = ", "), "\n")
units_by_geo <- minr |> count(unit, geo) |>
  pivot_wider(names_from = geo, values_from = n, values_fill = 0L) |> arrange(unit)
cat("  rows by unit x geo (all coicop18 levels):\n")
print(as.data.frame(units_by_geo), row.names = FALSE)
cat("  2025=100 (I25) present:", "I25" %in% minr$unit, "\n")

div <- minr |> filter(str_detect(coicop18, "^CP\\d{2}$")) |>
  mutate(month = as.Date(paste0(time, "-01")))
stopifnot(!anyNA(div$month), all(div$freq == "M"))
div_units <- sort(unique(div$unit))
cat("  units carrying division-level (^CP\\d{2}$) series:", paste(div_units, collapse = ", "), "\n")
cat("  division codes present:", paste(sort(unique(div$coicop18)), collapse = ", "), "\n")

cat("\n== 3b. Division-level coverage by geo x unit ==\n")
spans <- div |> filter(!is.na(values)) |> group_by(geo, unit, coicop18) |>
  summarise(first = min(month), last = max(month), n_obs = n(), .groups = "drop")
cov <- spans |> group_by(geo, unit) |>
  summarise(n_divisions  = n_distinct(coicop18),
            first_month  = format(min(first), "%Y-%m"),
            last_month   = format(max(last),  "%Y-%m"),
            latest_start = format(max(first), "%Y-%m"),
            earliest_end = format(min(last),  "%Y-%m"), .groups = "drop") |>
  arrange(unit, geo)
print(as.data.frame(cov), row.names = FALSE)
cat("  (first/last = earliest/latest over divisions; latest_start/earliest_end\n",
    "  show whether all divisions share that span)\n")

cat("\n  Per-division spans that differ from their geo x unit's common span:\n")
odd <- spans |> group_by(geo, unit) |>
  filter(first != min(first) | last != max(last)) |> ungroup()
if (nrow(odd)) print(as.data.frame(odd |> mutate(across(c(first, last), ~ format(.x, "%Y-%m")))),
                     row.names = FALSE) else cat("  none\n")

cat("\n== 3c. Missing months inside each geo x unit x division span ==\n")
gaps <- spans |> rowwise() |>
  mutate(expected = length(seq(first, last, by = "month")),
         missing  = expected - n_obs) |> ungroup()
stopifnot(all(gaps$missing >= 0))
cat("  series checked:", nrow(gaps), "| series with internal gaps:", sum(gaps$missing > 0), "\n")
if (any(gaps$missing > 0)) print(as.data.frame(gaps |> filter(missing > 0) |>
  mutate(across(c(first, last), ~ format(.x, "%Y-%m")))), row.names = FALSE)
na_rows <- div |> filter(is.na(values))
cat("  division rows published with an empty value:", nrow(na_rows), "\n")
if (nrow(na_rows)) print(as.data.frame(na_rows |> count(geo, unit, coicop18, OBS_FLAG)), row.names = FALSE)
cat("  OBS_FLAG values on division rows (geo x unit x flag):\n")
print(as.data.frame(div |> count(geo, unit, OBS_FLAG)), row.names = FALSE)

cat("\n== 3d. XK division indices vs the weights window (2015-2026) ==\n")
xk <- spans |> filter(geo == "XK") |>
  group_by(unit) |>
  summarise(n_divisions = n_distinct(coicop18),
            divisions_from_2015_01 = sum(first <= as.Date("2015-01-01")),
            latest_start = format(max(first), "%Y-%m"), .groups = "drop")
print(as.data.frame(xk), row.names = FALSE)
cat("  XK weights years:", paste(range(iw_years$XK), collapse = "-"), "\n")

cat("\nDone.\n")
