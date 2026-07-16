# ==============================================================================
# 02_pull_eurostat.R
# Pull Eurostat ilc_mdes01 (population unable to keep home adequately warm,
# EU-SILC) for Kosova and comparators, filtered at source:
#   geo = XK, AL, RS, ME, MK, TR, EU27_2020   (BA has NO series — noted in README)
#   hhcomp = TOTAL, unit = PC
# Pins the EXACT TOTAL and below-poverty-threshold rows (binding: no indicative
# values may be quoted anywhere in the piece).
#
# Run from the piece root:  Rscript R/02_pull_eurostat.R
# ==============================================================================
suppressWarnings(suppressMessages({ library(dplyr); library(readr) }))
options(timeout = 180)

proj <- "C:/Users/plato/Documents/kosovo-economy/energy-poverty"
geos <- c("XK","AL","RS","ME","MK","TR","EU27_2020")

# SDMX key-path filter (dim order: freq.hhcomp.rskpovth.unit.geo). NOTE: plain
# "?geo=XX" query params are silently IGNORED by the dissemination API — they
# return the full dataset; only the key path actually filters server-side.
# BA is requested deliberately: it returns zero rows (no series), which makes the
# Bosnia measurement-gap note verifiable from this script's own assertions.
key <- sprintf("A.TOTAL.TOTAL+B_60.PC.%s", paste(c(geos, "BA"), collapse = "+"))
u <- sprintf("https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ilc_mdes01/%s?format=SDMX-CSV", key)
raw_f <- file.path(proj, "data/raw/eurostat_ilc_mdes01_filtered.csv")
ok <- tryCatch({ download.file(u, raw_f, mode = "wb", quiet = TRUE); TRUE },
               error = function(e) FALSE)
if (!ok) {   # fallback: full table, filtered in R immediately after read
  message("key-path filter rejected; downloading full table and filtering in R")
  u <- "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ilc_mdes01?format=SDMX-CSV"
  download.file(u, raw_f, mode = "wb", quiet = TRUE)
}
Sys.sleep(2)

d <- suppressWarnings(read_csv(raw_f, show_col_types = FALSE))
names(d) <- tolower(names(d))
# Bosnia gap check must run BEFORE the geo filter: on the fallback path the raw
# file is the full table, so BA's absence there proves it publishes no series.
if (length(unique(d$geo)) > length(geos)) stopifnot(!"BA" %in% d$geo)
d <- d |> filter(geo %in% geos)          # no-op if the key path filtered; real work on fallback
cat("rows:", nrow(d), "| cols:", paste(names(d), collapse = ", "), "\n")
cat("geos:", paste(sort(unique(d$geo)), collapse = ", "), "\n")
stopifnot(setequal(unique(d$geo), geos))
cat("hhcomp codes: ", paste(sort(unique(d$hhcomp)),   collapse = ", "), "\n")
cat("rskpovth codes:", paste(sort(unique(d$rskpovth)), collapse = ", "), "\n")
cat("unit codes:    ", paste(sort(unique(d$unit)),     collapse = ", "), "\n")

# pin the exact rows: total households composition, % of population
# rskpovth codelist (verified from data): TOTAL, A_60 (above 60% of median
# equivalised income), B_60 (below 60% = at-risk-of-poverty threshold)
stopifnot("TOTAL" %in% d$hhcomp, "TOTAL" %in% d$rskpovth, "PC" %in% d$unit)
blw <- grep("^B_60$", unique(d$rskpovth), value = TRUE)
cat("below-poverty-threshold code identified as:", blw, "\n")
stopifnot(length(blw) == 1)

k <- d |>
  filter(hhcomp == "TOTAL", unit == "PC", rskpovth %in% c("TOTAL", blw)) |>
  mutate(year = as.integer(time_period),
         poverty = ifelse(rskpovth == "TOTAL", "total", "below_at_risk_of_poverty")) |>
  select(geo, poverty, year, value = obs_value) |>
  arrange(geo, poverty, year)
write_csv(k, file.path(proj, "data/processed/eurostat_keep_warm.csv"))

cat("\n== coverage (TOTAL rows) ==\n")
cov <- k |> filter(poverty == "total") |> group_by(geo) |>
  summarise(years = paste0(min(year), "-", max(year)),
            latest = max(year),
            latest_value = value[year == max(year)], .groups = "drop")
print(as.data.frame(cov), row.names = FALSE)

cat("\n== XK 2018 EXACT (pinned) ==\n")
print(as.data.frame(k |> filter(geo == "XK")), row.names = FALSE)

xk_years <- unique(k$year[k$geo == "XK"])
stopifnot(identical(xk_years, 2018L))     # XK is a single transmission
cat("\nVerified: BA absent; XK = 2018 only.\n")
