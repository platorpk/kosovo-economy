# ==============================================================================
# 03_fx.R  --  VERIFICATION ONLY
# Reports monthly exchange rates of RSD, ALL and MKD against the euro, 2021-01 to
# the latest month published: levels, % change over fixed windows, max / min.
# No interpretation.
#
# Source table (Eurostat > Economy and finance > Exchange rates > Bilateral
# exchange rates > Euro/ECU exchange rates):
#   ert_bil_eur_m  Euro/ECU exchange rates - monthly data
# Pulled as the full bulk SDMX-CSV (gzip) from the SDMX 2.1 dissemination API,
# saved raw, then filtered in R. The bulk file is gitignored by the existing
# data/raw/*/eurostat_*_bulk.csv.gz pattern; delete it and rerun to regenerate.
# HICP peak months are read from the committed filtered record
# data/raw/2026-09-23/eurostat_prc_hicp_minr_WB_EA.rds (verify/02_peers.R).
#
# Writes:
#   data/raw/<today>/eurostat_ert_bil_eur_m_bulk.csv.gz   raw bytes (gitignored)
#   data/raw/<today>/eurostat_ert_bil_eur_m_RSD_ALL_MKD.rds  filtered record
#   verify/fx_monthly.csv          every month, AVG and END, 2021-01..latest
#   verify/fx_tables_generated.md  every table in followup_report.md section 1
#
# Concept notes:
#   - Main series: statinfo AVG (monthly average); END (end of month) goes to the
#     CSV only (Plator, 2026-09-29).
#   - Quoted as units of national currency per 1 EUR; a higher value = more
#     national currency per euro. No reading of that is made here.
#   - "Peak month" = the month(s) of the geo's highest published HICP TOTAL RCH_A
#     in 2021-01..2023-12. Ties are all reported. Currency -> geo: RSD RS,
#     ALL AL, MKD MK.
#
# Run from the piece root:  Rscript verify/03_fx.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(tidyr); library(stringr)
}))
options(timeout = 600, width = 200, dplyr.summarise.inform = FALSE)

PROJ  <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
API   <- "https://ec.europa.eu/eurostat/api/dissemination/"
VER   <- file.path(PROJ, "verify")
CUR   <- c(RSD = "RS", ALL = "AL", MKD = "MK")
START <- "2021-01"

tm <- function(time) as.integer(substr(time, 1, 4)) * 12L + as.integer(substr(time, 6, 7)) - 1L
fm <- function(mi) sprintf("%04d-%02d", mi %/% 12L, mi %% 12L + 1L)
f  <- function(x, d) formatC(x, format = "f", digits = d)
md <- character(); md_add <- function(...) md <<- c(md, ...)
md_table <- function(df) {
  df <- as.data.frame(df); df[] <- lapply(df, function(x) { x <- as.character(x); x[is.na(x)] <- ""; x })
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")), "")
}
show <- function(df, title) { cat("\n--", title, "--\n"); print(as.data.frame(df), row.names = FALSE) }

# ------------------------------------------------------------------------------
# 0. Raw pull (cached) and schema
# ------------------------------------------------------------------------------
raw_dir <- file.path(PROJ, "data/raw", as.character(Sys.Date()))
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
bulk <- file.path(raw_dir, "eurostat_ert_bil_eur_m_bulk.csv.gz")
if (file.exists(bulk)) {
  cat("raw already present, skipping download:", bulk, "\n")
} else {
  download.file(paste0(API, "sdmx/2.1/data/ert_bil_eur_m?format=SDMX-CSV&compressed=true"),
                bulk, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
  cat("saved", bulk, sprintf("(%.1f MB)", file.size(bulk) / 2^20), "\n")
}
d <- read_csv(bulk, col_types = cols(.default = col_character()), progress = FALSE)
cat("bulk rows:", nrow(d), "| columns:", paste(names(d), collapse = ", "), "\n")
stopifnot(all(c("freq", "statinfo", "unit", "currency", "TIME_PERIOD", "OBS_VALUE", "LAST UPDATE") %in% names(d)))
cat("statinfo:", paste(sort(unique(d$statinfo)), collapse = ", "),
    "| unit:", paste(sort(unique(d$unit)), collapse = ", "),
    "| freq:", paste(sort(unique(d$freq)), collapse = ", "), "\n")
lu <- unique(d[["LAST UPDATE"]]); cat("LAST UPDATE:", paste(lu, collapse = " | "), "\n")
stopifnot(length(lu) == 1)

toc_f <- file.path(PROJ, "data/raw/2026-09-29/eurostat_catalogue_toc_en.txt")
toc <- read_tsv(toc_f, col_types = cols(.default = col_character()), progress = FALSE) |>
  rename(last_update = `last update of data`) |> distinct(code, .keep_all = TRUE)
toc_lu <- toc$last_update[toc$code == "ert_bil_eur_m"]
cat("catalogue (", basename(dirname(toc_f)), ") last update of ert_bil_eur_m:", toc_lu, "\n")

fx <- d |> filter(currency %in% names(CUR)) |>
  transmute(currency, statinfo, unit, freq, time = TIME_PERIOD, value_chr = OBS_VALUE,
            value = as.numeric(OBS_VALUE), flag = OBS_FLAG)
saveRDS(fx, file.path(raw_dir, "eurostat_ert_bil_eur_m_RSD_ALL_MKD.rds"))
show(fx |> count(currency, statinfo, unit, freq), "rows kept, by currency x statinfo x unit x freq")
stopifnot(all(fx$freq == "M"), setequal(unique(fx$currency), names(CUR)),
          all(c("AVG", "END") %in% fx$statinfo), n_distinct(fx$unit) == 1, unique(fx$unit) == "NAC")
show(fx |> slice_head(n = 3), "sample rows")

# ------------------------------------------------------------------------------
# 1. Window 2021-01..latest: completeness, levels
# ------------------------------------------------------------------------------
w <- fx |> mutate(mi = tm(time)) |> filter(mi >= tm(START))
span <- w |> filter(!is.na(value)) |> group_by(currency, statinfo) |>
  summarise(first = fm(min(mi)), last = fm(max(mi)), n = n(), expected = max(mi) - min(mi) + 1L,
            flags = paste(unique(na.omit(flag[flag != ""])), collapse = ","))
show(span, "coverage from 2021-01")
stopifnot(all(span$first == START), all(span$n == span$expected), n_distinct(span$last) == 1)
LATEST <- span$last[1]
dec <- w |> filter(!is.na(value)) |> group_by(currency, statinfo) |>
  summarise(decimals_as_written = max(nchar(str_extract(value_chr, "(?<=\\.)\\d+$")), na.rm = TRUE),
            significant_decimals = max(nchar(str_remove(str_extract(value_chr, "(?<=\\.)\\d+$"), "0+$")), na.rm = TRUE))
show(dec, "decimals published (as written in the bulk file; excluding trailing zeros)")

monthly <- w |> filter(!is.na(value)) |> select(month = time, mi, currency, statinfo, value, flag) |>
  arrange(statinfo, currency, mi)
write_csv(monthly |> select(-mi), file.path(VER, "fx_monthly.csv"))
avg <- monthly |> filter(statinfo == "AVG")
lev <- avg |> select(month, currency, value) |> pivot_wider(names_from = currency, values_from = value) |>
  select(month, all_of(names(CUR)))
stopifnot(nrow(lev) == tm(LATEST) - tm(START) + 1L, !anyNA(lev))
md_add("# Generated tables: 03_fx.R", "",
       sprintf("Eurostat `ert_bil_eur_m`, bulk LAST UPDATE %s; catalogue last update %s (TOC of %s).",
               lu, toc_lu, basename(dirname(toc_f))),
       "Units of national currency per 1 EUR (unit `NAC`), monthly average (statinfo `AVG`). END-of-month is in `fx_monthly.csv` only.", "",
       "## 1a. Coverage from 2021-01", "", md_table(span), "Decimals published:", "", md_table(dec),
       sprintf("## 1b. Monthly levels, AVG, %s..%s", START, LATEST), "", md_table(lev))

# ------------------------------------------------------------------------------
# 2. HICP peak months (RCH_A TOTAL, 2021-01..2023-12) and % changes
# ------------------------------------------------------------------------------
minr <- readRDS(file.path(PROJ, "data/raw/2026-09-23/eurostat_prc_hicp_minr_WB_EA.rds"))
peaks <- minr |> filter(coicop18 == "TOTAL", unit == "RCH_A", geo %in% CUR) |>
  mutate(mi = tm(time)) |> filter(mi >= tm("2021-01"), mi <= tm("2023-12"), !is.na(values)) |>
  group_by(geo) |> filter(values == max(values)) |> ungroup() |>
  transmute(geo, peak_month = fm(mi), peak_RCH_A = values)
show(peaks, "HICP TOTAL RCH_A peak month(s), 2021-01..2023-12")
stopifnot(setequal(peaks$geo, CUR))

val <- function(cur, month) { v <- avg$value[avg$currency == cur & avg$month == month]; stopifnot(length(v) == 1); v }
pct <- function(cur, to) 100 * (val(cur, to) / val(cur, START) - 1)
to_peak <- peaks |> mutate(currency = names(CUR)[match(geo, CUR)]) |> rowwise() |>
  mutate(level_2021_01 = val(currency, START), level_peak = val(currency, peak_month),
         pct_change = pct(currency, peak_month)) |> ungroup() |>
  transmute(currency, geo, peak_month, peak_RCH_A = f(peak_RCH_A, 1), level_2021_01 = f(level_2021_01, 4),
            level_peak = f(level_peak, 4), pct_change = f(pct_change, 2)) |> arrange(match(currency, names(CUR)))
common <- expand_grid(currency = names(CUR), to = c("2023-12", LATEST)) |> rowwise() |>
  mutate(window = paste0(START, " -> ", to), level_2021_01 = f(val(currency, START), 4),
         level_end = f(val(currency, to), 4), pct_change = f(pct(currency, to), 2)) |> ungroup() |>
  select(window, currency, level_2021_01, level_end, pct_change)
show(to_peak, "% change, 2021-01 -> HICP peak month")
show(common, "% change, common windows")

# ------------------------------------------------------------------------------
# 3. Max / min over 2021-01..latest (all tied months listed)
# ------------------------------------------------------------------------------
mm <- avg |> group_by(currency) |>
  summarise(max = f(max(value), 4), max_month = paste(month[value == max(value)], collapse = ", "),
            min = f(min(value), 4), min_month = paste(month[value == min(value)], collapse = ", "),
            max_over_min_pct = f(100 * (max(value) / min(value) - 1), 2)) |>
  arrange(match(currency, names(CUR)))
show(mm, sprintf("max / min, AVG, %s..%s", START, LATEST))

md_add("## 1c. % change, 2021-01 -> the geo's HICP peak month", "",
       "Peak month = month(s) of the highest published HICP TOTAL `RCH_A` in 2021-01..2023-12 (`prc_hicp_minr`); ties listed as separate rows.",
       "% change = 100 x (level at peak month / level 2021-01 - 1).", "", md_table(to_peak),
       "## 1d. % change, common windows", "", md_table(common),
       sprintf("## 1e. Max and min, AVG, %s..%s", START, LATEST), "",
       "`max_over_min_pct` = 100 x (max / min - 1), regardless of which month comes first.", "", md_table(mm))
writeLines(md, file.path(VER, "fx_tables_generated.md"), useBytes = TRUE)
cat("\nwrote verify/fx_monthly.csv, verify/fx_tables_generated.md\nDone.\n")
