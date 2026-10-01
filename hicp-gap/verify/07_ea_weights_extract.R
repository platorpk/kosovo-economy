# ==============================================================================
# 07_ea_weights_extract.R  --  VERIFICATION ONLY (committed extract)
# Filters the bulk HICP item-weights table to the three euro-area codes needed
# for the euro-area membership check in build/04_readme.R (EA, EA20, EA21), so
# a fresh clone can run the build without the gitignored bulk download.
#
# Source: Eurostat prc_hicp_iw (HICP - ECOICOP ver.2 - item weights), bulk
#   SDMX-CSV as saved by verify/01_coverage.R:
#   data/raw/<date>/eurostat_prc_hicp_iw_bulk.csv.gz   (gitignored)
# Writes: data/raw/<same date>/eurostat_prc_hicp_iw_EA_EA20_EA21.rds
#   Columns harmonised as in verify/01_coverage.R: TIME_PERIOD -> time,
#   OBS_VALUE -> values (numeric). Cached: skipped if the .rds already exists.
# Concept: EA is the changing-composition euro area; EA20 and EA21 are fixed
#   compositions. EA's item weights equal EA20's while the euro area has 20
#   members and EA21's once Bulgaria joins.
#
# Run from the piece root:  Rscript verify/07_ea_weights_extract.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr)
}))

PROJ <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
GEOS <- c("EA", "EA20", "EA21")

dated <- sort(list.dirs(file.path(PROJ, "data/raw"), recursive = FALSE), decreasing = TRUE)
dated <- dated[file.exists(file.path(dated, "eurostat_prc_hicp_iw_bulk.csv.gz"))]
stopifnot(length(dated) >= 1)
raw_dir <- dated[1]
out <- file.path(raw_dir, "eurostat_prc_hicp_iw_EA_EA20_EA21.rds")

if (file.exists(out)) {
  cat("extract already present, skipping:", out, "\n")
  d <- readRDS(out)
} else {
  d <- read_csv(file.path(raw_dir, "eurostat_prc_hicp_iw_bulk.csv.gz"),
                col_types = cols(.default = col_character()), progress = FALSE)
  cat("bulk rows:", nrow(d), "| columns:", paste(names(d), collapse = ", "), "\n")
  stopifnot(all(c("TIME_PERIOD", "OBS_VALUE", "geo", "coicop18", "LAST UPDATE") %in% names(d)))
  d <- d |> rename(time = TIME_PERIOD, values = OBS_VALUE) |>
    filter(geo %in% GEOS) |> mutate(values = as.numeric(values))
  saveRDS(d, out)
  cat("saved", out, "\n")
}

# Verify before proceeding
stopifnot(setequal(unique(d$geo), GEOS), length(unique(d[["LAST UPDATE"]])) == 1)
cat("rows:", nrow(d), "| LAST UPDATE:", unique(d[["LAST UPDATE"]]), "\n")
cat("columns:", paste(names(d), collapse = ", "), "\n")
print(d |> count(geo, first = min(time), last = max(time)) |> as.data.frame(), row.names = FALSE)
print(head(as.data.frame(d |> filter(grepl("^CP\\d{2}$", coicop18)) |> select(geo, coicop18, time, values)), 3),
      row.names = FALSE)
