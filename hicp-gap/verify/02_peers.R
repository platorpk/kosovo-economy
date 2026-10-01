# ==============================================================================
# 02_peers.R  --  VERIFICATION ONLY
# Checks whether Eurostat HICP data support extending hicp-gap to Western Balkan
# peers: XK, ME, RS, AL, MK, plus the euro-area aggregate hicp-gap already uses
# (EA). It reports coverage, weights, the published-vs-derived headline rate,
# the size of the weighted-division aggregation residual, and exact published
# values. It makes no analytical choice and writes no finding.
#
# Source tables (Eurostat > Economy and finance > Prices > Harmonised index of
# consumer prices (HICP) > HICP - ECOICOP ver.2):
#   prc_hicp_minr  indices and rates of change, monthly data
#   prc_hicp_iw    item weights (annual)
# Both are read from the unfiltered bulk SDMX-CSV already on disk from
# verify/01_coverage.R (latest date folder that holds both bulk files). No
# re-download: the catalogue guard in section 0 asserts that Eurostat's "last
# update of data" for both tables equals the LAST UPDATE stamped in the bulk
# files. If it does not, the script stops (the cached vintage is stale).
#
# Also reads, from the Eurostat dissemination API (cached, 2 s between calls):
#   catalogue/toc/txt              table of contents with last-update dates
#   sdmx/2.1/contentconstraint/    the geo codes each HICP table carries
#                                  (used for the BA check only)
#
# Writes:
#   data/raw/<bulk date>/eurostat_prc_hicp_{minr,iw}_WB_EA.rds  bulk filtered to
#       geo XK, ME, RS, AL, MK, EA (committed record of this vintage)
#   data/raw/<toc date>/eurostat_catalogue_toc_en.txt           raw bytes
#   data/raw/<toc date>/contentconstraint/*.xml                  raw bytes
#   data/raw/<toc date>/eurostat_ei_cphi_m_{BA.csv,bulk.csv.gz}  BA check (bulk gitignored)
#   data/raw/<toc date>/<metadata pages>                         section 7, raw bytes
#   verify/peers_coicop_codes.csv        every coicop18 code returned
#   verify/peers_coverage.csv            geo x unit x code coverage matrix
#   verify/peers_weights.csv             division weights, geo x year
#   verify/peers_headline_check.csv      derived vs published TOTAL YoY
#   verify/peers_aggregation_residuals.csv  monthly residuals, 3 variants
#   verify/peers_ba_scan.csv             BA presence per HICP table
#   verify/peers_tables_generated.md     every table in the report
#
# Concept notes:
#   - Division = coicop18 ^CP\d{2}$ (ECOICOP ver.2 has 13, CP01-CP13).
#     "Special aggregate" = any code that is neither TOTAL nor ^CP.
#   - Units checked: I15 and I25 (index), RCH_A (annual rate of change).
#   - Derived YoY = 100 * (I_m / I_{m-12} - 1). Rounding bound for
#     |derived - published| = half a unit of RCH_A's last published decimal
#     + the index-rounding term 100 * h * (1/I_{m-12} + I_m/I_{m-12}^2),
#     h = half a unit of the index's last published decimal.
#   - Aggregation residual = sum_i (w_i / 1000) * YoY_i  -  YoY_TOTAL, over the
#     13 divisions. Three variants are reported side by side; none is chosen:
#       V1 published RCH_A, weights of the month's calendar year
#       V2 YoY derived from I15, weights of the month's calendar year
#       V3 published RCH_A, weights of the previous calendar year
#     The effect of dividing by sum(w) instead of 1000 is reported as one number.
#
# Run from the piece root:  Rscript verify/02_peers.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(tidyr); library(stringr); library(purrr)
}))
options(timeout = 1800, width = 200, dplyr.summarise.inform = FALSE)

PROJ   <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
API    <- "https://ec.europa.eu/eurostat/api/dissemination/"
PEERS  <- c("XK", "ME", "RS", "AL", "MK")
GEOS   <- c(PEERS, "EA")
DIVS   <- sprintf("CP%02d", 1:13)
UNITS  <- c("I15", "I25", "RCH_A")
TABLES <- c("prc_hicp_iw", "prc_hicp_minr")
KEY_AGG <- c("FOOD", "NRG", "IGD_NNRG", "SERV", "TOT_X_NRG_FOOD")
VER    <- file.path(PROJ, "verify")
dir.create(VER, showWarnings = FALSE)

tm <- function(time) as.integer(substr(time, 1, 4)) * 12L + as.integer(substr(time, 6, 7)) - 1L
fm <- function(mi) ifelse(is.na(mi), NA_character_, sprintf("%04d-%02d", mi %/% 12L, mi %% 12L + 1L))
n_dec <- function(x) { x <- x[!is.na(x)]; max(0L, nchar(str_extract(x, "(?<=\\.)\\d+$")), na.rm = TRUE) }
f2 <- function(x, d = 3) ifelse(is.na(x), "", formatC(x, format = "f", digits = d))

md <- character()
md_add <- function(...) md <<- c(md, ...)
md_table <- function(df) {
  df <- as.data.frame(df)
  df[] <- lapply(df, function(x) { x <- as.character(x); x[is.na(x)] <- ""; x })
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")), "")
}
show <- function(df, title) { cat("\n--", title, "--\n"); print(as.data.frame(df), row.names = FALSE) }

raw_root <- file.path(PROJ, "data/raw")
dated_dirs <- function() {
  d <- sort(list.dirs(raw_root, recursive = FALSE), decreasing = TRUE)
  d[grepl("^\\d{4}-\\d{2}-\\d{2}$", basename(d))]
}
latest_with <- function(files) {
  hit <- dated_dirs()[vapply(dated_dirs(), function(d) all(file.exists(file.path(d, files))), logical(1))]
  if (length(hit)) hit[1] else file.path(raw_root, as.character(Sys.Date()))
}

# ------------------------------------------------------------------------------
# 0. Catalogue snapshot and vintage guard
# ------------------------------------------------------------------------------
cat("== 0. Catalogue and vintage ==\n")
toc_dir  <- latest_with("eurostat_catalogue_toc_en.txt")
dir.create(toc_dir, recursive = TRUE, showWarnings = FALSE)
toc_file <- file.path(toc_dir, "eurostat_catalogue_toc_en.txt")
if (file.exists(toc_file)) {
  cat("raw already present, skipping download:", toc_file, "\n")
} else {
  download.file(paste0(API, "catalogue/toc/txt?lang=en"), toc_file, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
}
toc <- read_tsv(toc_file, col_types = cols(.default = col_character()), progress = FALSE) |>
  rename(last_update = `last update of data`) |>
  mutate(title = str_trim(title)) |> distinct(code, .keep_all = TRUE)
cat("TOC rows:", nrow(toc), "| file:", toc_file, "\n")

bulk_name <- function(t) sprintf("eurostat_%s_bulk.csv.gz", t)
bulk_dir  <- latest_with(bulk_name(TABLES))
stopifnot(all(file.exists(file.path(bulk_dir, bulk_name(TABLES)))))
cat("bulk folder:", bulk_dir, "\n")

# ------------------------------------------------------------------------------
# 1. Load the bulk tables filtered to the six geos (cached .rds)
# ------------------------------------------------------------------------------
load_table <- function(t, dims) {
  rds <- file.path(bulk_dir, sprintf("eurostat_%s_WB_EA.rds", t))
  if (file.exists(rds)) {
    cat("filtered .rds already present, reading:", rds, "\n")
    return(readRDS(rds))
  }
  d <- read_csv(file.path(bulk_dir, bulk_name(t)),
                col_types = cols(.default = col_character()), progress = FALSE)
  cat("\n==", t, "== bulk rows:", nrow(d), "| columns:", paste(names(d), collapse = ", "), "\n")
  d <- rename(d, time = TIME_PERIOD, values_chr = OBS_VALUE)
  stopifnot(all(c("freq", dims, "coicop18", "geo", "time", "values_chr", "LAST UPDATE") %in% names(d)))
  d <- d |> filter(geo %in% c(GEOS, "BA")) |> mutate(values = as.numeric(values_chr))
  saveRDS(d, rds)
  cat("  geos kept:", paste(sort(unique(d$geo)), collapse = ", "), "| rows:", nrow(d), "-> saved", rds, "\n")
  d
}
iw   <- load_table("prc_hicp_iw",   dims = "statinfo")
minr <- load_table("prc_hicp_minr", dims = "unit")

bulk_lu <- unique(c(iw[["LAST UPDATE"]], minr[["LAST UPDATE"]]))
cat("LAST UPDATE in bulk:", paste(bulk_lu, collapse = " | "), "\n")
stopifnot(length(bulk_lu) == 1)
bulk_lu_date <- format(as.Date(substr(bulk_lu, 1, 8), "%d/%m/%y"), "%d.%m.%Y")
toc_lu <- toc |> filter(code %in% TABLES) |> select(code, last_update)
show(toc_lu, "catalogue last update of data")
if (!all(toc_lu$last_update == bulk_lu_date)) {
  stop("Eurostat has updated since the cached bulk vintage (", bulk_lu_date,
       "). Stop and report: re-download is a decision for Plator.")
}
cat("PASS: catalogue last update", bulk_lu_date, "== bulk LAST UPDATE; cached vintage is current\n")

stopifnot(!"BA" %in% minr$geo, !"BA" %in% iw$geo)
stopifnot(setequal(unique(minr$geo), GEOS), setequal(unique(iw$geo), GEOS))
stopifnot(all(minr$freq == "M"), all(iw$statinfo == "IW"))
cat("BA rows in bulk minr:", sum(minr$geo == "BA"), "| in bulk iw:", sum(iw$geo == "BA"), "\n")

md_add("# Generated tables: 02_peers.R", "",
       sprintf("Eurostat vintage: LAST UPDATE %s (bulk, `%s`); catalogue last update %s for both tables.",
               bulk_lu, basename(bulk_dir), bulk_lu_date), "")

labels <- read_tsv(list.files(bulk_dir, "^eurostat_codelist_COICOP18_.*\\.tsv$", full.names = TRUE)[1],
                   col_names = c("coicop18", "label"), col_types = "cc", progress = FALSE)

# ------------------------------------------------------------------------------
# 1a. COICOP codes actually returned
# ------------------------------------------------------------------------------
cat("\n== 1a. coicop18 codes returned (prc_hicp_minr) ==\n")
classify <- function(c) case_when(c == "TOTAL" ~ "total", str_detect(c, "^CP\\d{2}$") ~ "division",
                                  str_detect(c, "^CP\\d{3,}$") ~ "sub-division", TRUE ~ "special aggregate")
codes <- minr |> filter(!is.na(values)) |> distinct(geo, unit, coicop18)
cat("units in table:", paste(sort(unique(minr$unit)), collapse = ", "), "\n")
code_wide <- codes |> filter(unit %in% UNITS) |> group_by(coicop18, geo) |>
  summarise(units = paste(sort(unit), collapse = ",")) |>
  pivot_wider(names_from = geo, values_from = units, values_fill = "") |>
  left_join(labels, by = "coicop18") |> mutate(class = classify(coicop18)) |>
  select(coicop18, label, class, all_of(GEOS)) |> arrange(class, coicop18)
write_csv(code_wide, file.path(VER, "peers_coicop_codes.csv"))
n_codes <- codes |> filter(unit %in% UNITS) |> mutate(class = classify(coicop18)) |>
  group_by(geo, class) |> summarise(n = n_distinct(coicop18)) |>
  pivot_wider(names_from = geo, values_from = n, values_fill = 0L) |> select(class, all_of(GEOS))
show(n_codes, "distinct codes with >=1 value in I15/I25/RCH_A, by class x geo")
cat("codes without a codelist label:", paste(code_wide$coicop18[is.na(code_wide$label)], collapse = ", "), "\n")
special <- code_wide |> filter(class == "special aggregate") |> pull(coicop18)
cat("special aggregates (", length(special), "):", paste(special, collapse = ", "), "\n")
stopifnot(all(KEY_AGG %in% special), "TOTAL" %in% code_wide$coicop18, all(DIVS %in% code_wide$coicop18))
md_add("## 1a. coicop18 codes returned by prc_hicp_minr (units I15/I25/RCH_A)", "",
       "Distinct codes with at least one non-empty value, by class and geo:", "", md_table(n_codes),
       "Special aggregates (label from the COICOP18 codelist) and the units each geo carries:", "",
       md_table(code_wide |> filter(class == "special aggregate") |> select(-class)))

# ------------------------------------------------------------------------------
# 1b. Coverage matrix: geo x unit x code (TOTAL, divisions, special aggregates)
# ------------------------------------------------------------------------------
cat("\n== 1b. Coverage matrix ==\n")
scope <- c("TOTAL", DIVS, special)
flag_str <- function(flag, mi) {
  k <- !is.na(flag) & flag != ""
  if (!any(k)) return("")
  tibble(f = flag[k], mi = mi[k]) |> group_by(f) |>
    summarise(s = sprintf("%s:%d (%s..%s)", f[1], n(), fm(min(mi)), fm(max(mi)))) |>
    pull(s) |> paste(collapse = "; ")
}
spans <- minr |> filter(unit %in% UNITS, coicop18 %in% scope) |> mutate(mi = tm(time)) |>
  group_by(geo, unit, coicop18) |>
  summarise(n_obs = sum(!is.na(values)), n_empty_rows = sum(is.na(values)),
            first_mi = if (any(!is.na(values))) min(mi[!is.na(values)]) else NA_integer_,
            last_mi  = if (any(!is.na(values))) max(mi[!is.na(values)]) else NA_integer_,
            flags = flag_str(OBS_FLAG, mi))
coverage <- expand_grid(geo = GEOS, unit = UNITS, coicop18 = scope) |>
  left_join(spans, by = c("geo", "unit", "coicop18")) |>
  mutate(n_obs = coalesce(n_obs, 0L), n_empty_rows = coalesce(n_empty_rows, 0L),
         flags = coalesce(flags, ""),
         missing_internal = ifelse(n_obs > 0, last_mi - first_mi + 1L - n_obs, NA_integer_),
         first_month = fm(first_mi), last_month = fm(last_mi),
         status = case_when(n_obs == 0 ~ "absent", missing_internal > 0 ~ "internal gaps", TRUE ~ "complete span"),
         class = classify(coicop18)) |>
  left_join(labels, by = "coicop18") |>
  select(geo, unit, coicop18, label, class, first_month, last_month, n_obs,
         missing_internal, n_empty_rows, flags, status)
stopifnot(nrow(coverage) == length(GEOS) * length(UNITS) * length(scope))
stopifnot(all(coverage$missing_internal >= 0, na.rm = TRUE))
write_csv(coverage, file.path(VER, "peers_coverage.csv"))
cat("rows:", nrow(coverage), "-> verify/peers_coverage.csv\n")
show(coverage |> count(geo, unit, status) |> pivot_wider(names_from = status, values_from = n, values_fill = 0L),
     "status counts (TOTAL + 13 divisions + all special aggregates)")

span_cell <- function(first, last, miss, n) ifelse(n == 0, "absent",
  paste0(first, "..", last, ifelse(miss > 0, sprintf(" (gaps %d)", miss), "")))
key_codes <- c("TOTAL", DIVS, KEY_AGG)
for (u in UNITS) {
  tab <- coverage |> filter(unit == u, coicop18 %in% key_codes) |>
    mutate(cell = span_cell(first_month, last_month, missing_internal, n_obs),
           coicop18 = factor(coicop18, levels = key_codes)) |>
    select(coicop18, geo, cell) |> pivot_wider(names_from = geo, values_from = cell) |>
    arrange(coicop18) |> select(coicop18, all_of(GEOS))
  show(tab, paste("coverage, unit", u))
  md_add(sprintf("## 1b. Coverage, unit %s: TOTAL, divisions, main special aggregates", u), "",
         "Cell = first..last month with a value; \"(gaps n)\" = months missing inside that span.", "",
         md_table(tab))
}
flagged <- coverage |> filter(flags != "", coicop18 %in% key_codes) |> select(geo, unit, coicop18, flags)
show(flagged, "flags on TOTAL / divisions / main aggregates")
all_flags <- coverage |> filter(flags != "") |> count(geo, unit, name = "codes_with_flags")
md_add("## 1c. Flags on TOTAL, divisions and main special aggregates", "",
       "Format `flag:count (first..last flagged month)`. Eurostat flags: b = break in time series, ",
       "d = definition differs (see metadata), u = low reliability, e = estimated, p = provisional.", "",
       if (nrow(flagged)) md_table(flagged) else c("None.", ""),
       "Codes carrying any flag, over all special aggregates too (full detail in `peers_coverage.csv`):", "",
       md_table(all_flags))
gaps_any <- coverage |> filter(status == "internal gaps")
md_add("## 1d. Series with internal gaps (all codes in scope)", "",
       if (nrow(gaps_any)) md_table(gaps_any |> select(geo, unit, coicop18, first_month, last_month, missing_internal))
       else c("None.", ""))
absent_any <- coverage |> filter(status == "absent") |> group_by(geo, unit) |>
  summarise(absent_codes = paste(coicop18, collapse = ", "))
md_add("## 1e. Codes in scope absent for a geo x unit", "",
       if (nrow(absent_any)) md_table(absent_any) else c("None.", ""))
show(absent_any, "absent codes")

# ------------------------------------------------------------------------------
# 2. Weights: division level, geo x year
# ------------------------------------------------------------------------------
cat("\n== 2. Weights (prc_hicp_iw) ==\n")
iwp <- iw |> mutate(year = as.integer(time))
stopifnot(!anyNA(iwp$year))
iw_classes <- iwp |> filter(!is.na(values)) |> mutate(class = classify(coicop18)) |>
  group_by(geo, class) |> summarise(n = n_distinct(coicop18)) |>
  pivot_wider(names_from = geo, values_from = n, values_fill = 0L) |> select(class, any_of(GEOS))
show(iw_classes, "item-weight codes with a value, by class x geo")
BOUND <- 13 * 0.005 + 1e-9
wt <- iwp |> distinct(geo, year) |>
  left_join(iwp |> filter(coicop18 %in% DIVS) |> group_by(geo, year) |>
              summarise(n_div = sum(!is.na(values)),
                        missing_divs = paste(setdiff(DIVS, coicop18[!is.na(values)]), collapse = " "),
                        wsum = sum(values, na.rm = TRUE),
                        decimals = n_dec(values_chr),
                        flags = paste(unique(na.omit(OBS_FLAG[OBS_FLAG != ""])), collapse = ",")),
            by = c("geo", "year")) |>
  left_join(iwp |> filter(coicop18 == "TOTAL") |> select(geo, year, w_TOTAL = values), by = c("geo", "year")) |>
  mutate(n_div = coalesce(n_div, 0L), dev = wsum - 1000,
         sums_to_1000 = n_div == 13 & abs(dev) <= BOUND) |>
  arrange(geo, year)
write_csv(wt, file.path(VER, "peers_weights.csv"))
wt_sum <- wt |> group_by(geo) |>
  summarise(years = sprintf("%d-%d", min(year), max(year)), n_years = n(),
            contiguous = n_years == max(year) - min(year) + 1,
            years_all_13 = sum(n_div == 13), max_abs_dev = f2(max(abs(dev[n_div == 13])), 2),
            years_dev_nonzero = sum(abs(dev) > 1e-9 & n_div == 13),
            years_outside_bound = sum(!sums_to_1000), decimals = max(decimals, na.rm = TRUE)) |>
  slice(match(GEOS, geo))
show(wt_sum, "division weights by geo")
wt_exc <- wt |> filter(!sums_to_1000 | flags != "") |>
  transmute(geo, year, n_div, missing_divs, wsum = f2(wsum, 2), dev = f2(dev, 2), flags)
show(wt_exc, "exceptions (n_div < 13, |sum - 1000| > 13*0.005, or flagged)")
wt_nonzero <- wt |> filter(n_div == 13, abs(dev) > 1e-9) |> transmute(geo, year, wsum = f2(wsum, 2), dev = f2(dev, 2))
md_add("## 2. Division weights (prc_hicp_iw), per geo", "",
       "Rounding bound for 13 weights published to 2 decimals: 13 x 0.005 = 0.065.", "",
       md_table(wt_sum),
       "Item-weight codes with a value, by class x geo:", "", md_table(iw_classes),
       "Exceptions (fewer than 13 divisions, sum outside 1000 +/- 0.065, or any flag):", "",
       if (nrow(wt_exc)) md_table(wt_exc) else c("None.", ""),
       "Geo-years whose 13 division weights do not sum to exactly 1000.00 (all within the bound unless listed above):", "",
       if (nrow(wt_nonzero)) md_table(wt_nonzero) else c("None.", ""))

# ------------------------------------------------------------------------------
# 3. Headline consistency: YoY derived from the TOTAL index vs published RCH_A
# ------------------------------------------------------------------------------
cat("\n== 3. Headline consistency (TOTAL) ==\n")
tot <- minr |> filter(coicop18 == "TOTAL", unit %in% UNITS) |> mutate(mi = tm(time))
decs <- tot |> group_by(geo, unit) |> summarise(decimals = n_dec(values_chr)) |>
  pivot_wider(names_from = unit, values_from = decimals, names_prefix = "dec_")
show(decs, "decimals published, TOTAL")
tw <- tot |> select(geo, unit, mi, values) |> pivot_wider(names_from = unit, values_from = values)
tf <- tot |> filter(unit == "RCH_A") |> select(geo, mi, flag_RCH_A = OBS_FLAG)
hc <- tw |> inner_join(tw |> transmute(geo, mi = mi + 12L, I15_l = I15, I25_l = I25), by = c("geo", "mi")) |>
  left_join(decs, by = "geo") |> left_join(tf, by = c("geo", "mi")) |>
  filter(!is.na(RCH_A), !is.na(I15), !is.na(I15_l)) |>
  mutate(der_I15 = 100 * (I15 / I15_l - 1), der_I25 = 100 * (I25 / I25_l - 1),
         diff_I15 = der_I15 - RCH_A, diff_I25 = der_I25 - RCH_A,
         bound_I15 = 0.5 * 10^-dec_RCH_A + 100 * 0.5 * 10^-dec_I15 * (1 / I15_l + I15 / I15_l^2),
         bound_I25 = 0.5 * 10^-dec_RCH_A + 100 * 0.5 * 10^-dec_I25 * (1 / I25_l + I25 / I25_l^2),
         month = fm(mi))
write_csv(hc |> select(geo, month, RCH_A, flag_RCH_A, der_I15, diff_I15, bound_I15, der_I25, diff_I25, bound_I25),
          file.path(VER, "peers_headline_check.csv"))
hc_sum <- hc |> group_by(geo) |>
  summarise(months = sprintf("%s..%s", fm(min(mi)), fm(max(mi))), n = n(),
            max_abs_diff_I15 = f2(max(abs(diff_I15))), month_of_max_I15 = month[which.max(abs(diff_I15))],
            n_gt_0.05_I15 = sum(abs(diff_I15) > 0.05),
            max_abs_diff_I25 = f2(max(abs(diff_I25))), n_gt_0.05_I25 = sum(abs(diff_I25) > 0.05),
            max_rounding_bound = f2(max(pmax(bound_I15, bound_I25))),
            n_beyond_bound = sum(abs(diff_I15) > bound_I15 + 1e-9 | abs(diff_I25) > bound_I25 + 1e-9)) |>
  slice(match(GEOS, geo))
show(hc_sum, "derived minus published RCH_A, TOTAL")
hc_exc <- hc |> filter(abs(diff_I15) > 0.05 | abs(diff_I25) > 0.05) |>
  transmute(geo, month, RCH_A, flag_RCH_A, der_I15 = f2(der_I15), diff_I15 = f2(diff_I15),
            der_I25 = f2(der_I25), diff_I25 = f2(diff_I25), bound = f2(pmax(bound_I15, bound_I25)))
show(hc_exc, "months with |diff| > 0.05 pp")
hc_beyond <- hc |> filter(abs(diff_I15) > bound_I15 + 1e-9 | abs(diff_I25) > bound_I25 + 1e-9) |>
  transmute(geo, month, RCH_A, diff_I15 = f2(diff_I15), bound_I15 = f2(bound_I15),
            diff_I25 = f2(diff_I25), bound_I25 = f2(bound_I25))
show(hc_beyond, "months where |diff| exceeds that index's own rounding bound")
md_add("## 3. Headline consistency: YoY derived from TOTAL index vs published RCH_A", "",
       "Derived = 100 x (I_m / I_m-12 - 1). Diff = derived - published, pp. Rounding bound = half a unit of",
       "RCH_A's last decimal + 100 x h x (1/I_m-12 + I_m/I_m-12^2), h = half a unit of the index's last decimal.", "",
       "Decimals published (TOTAL):", "", md_table(decs), md_table(hc_sum),
       "Months where |diff| > 0.05 pp under I15 or I25:", "",
       if (nrow(hc_exc)) md_table(hc_exc) else c("None.", ""),
       "Months where |diff| exceeds that index's own rounding bound:", "",
       if (nrow(hc_beyond)) md_table(hc_beyond) else c("None.", ""))

# ------------------------------------------------------------------------------
# 4. Aggregation residual: sum_i (w_i/1000) * division YoY  -  headline YoY
# ------------------------------------------------------------------------------
cat("\n== 4. Aggregation residual ==\n")
dv <- minr |> filter(coicop18 %in% c("TOTAL", DIVS), unit %in% c("I15", "RCH_A")) |>
  mutate(mi = tm(time)) |> select(geo, unit, coicop18, mi, values)
i15 <- dv |> filter(unit == "I15")
derived <- i15 |> inner_join(i15 |> transmute(geo, coicop18, mi = mi + 12L, lag = values),
                             by = c("geo", "coicop18", "mi")) |>
  transmute(geo, coicop18, mi, rate = 100 * (values / lag - 1), src = "derived_I15")
rates <- bind_rows(dv |> filter(unit == "RCH_A") |> transmute(geo, coicop18, mi, rate = values, src = "published_RCH_A"),
                   derived)
wts <- iwp |> filter(coicop18 %in% DIVS) |> select(geo, wyear = year, coicop18, w = values)
variants <- tribble(~variant, ~src, ~offset, ~desc,
  "V1", "published_RCH_A", 0L, "published RCH_A, weights of calendar year t",
  "V2", "derived_I15",     0L, "YoY derived from I15, weights of calendar year t",
  "V3", "published_RCH_A", 1L, "published RCH_A, weights of calendar year t-1")
resid_one <- function(variant, src, offset, desc) {
  r <- rates[rates$src == src, ]
  hl <- r |> filter(coicop18 == "TOTAL") |> select(geo, mi, headline = rate)
  r |> filter(coicop18 %in% DIVS) |> mutate(wyear = mi %/% 12L - offset) |>
    inner_join(wts, by = c("geo", "wyear", "coicop18")) |>
    group_by(geo, mi) |>
    summarise(n = sum(!is.na(rate) & !is.na(w)), wsum = sum(w),
              s1000 = sum(w / 1000 * rate), s_norm = sum(w / sum(w) * rate)) |>
    filter(n == 13) |> inner_join(hl, by = c("geo", "mi")) |> filter(!is.na(headline)) |>
    mutate(variant = variant, residual = s1000 - headline, residual_norm = s_norm - headline, month = fm(mi))
}
res <- pmap_dfr(variants |> select(-desc), function(variant, src, offset) resid_one(variant, src, offset))
stopifnot(all(res$n == 13))
write_csv(res |> ungroup() |> select(variant, geo, month, headline, weighted_sum = s1000, residual, residual_norm_sum_w = residual_norm),
          file.path(VER, "peers_aggregation_residuals.csv"))
dist <- function(d) d |> summarise(months = sprintf("%s..%s", fm(min(mi)), fm(max(mi))), n = n(),
  min = f2(min(residual)), p10 = f2(quantile(residual, 0.10)), median = f2(median(residual)),
  p90 = f2(quantile(residual, 0.90)), max = f2(max(residual)), max_abs = f2(max(abs(residual))))
res_full <- res |> group_by(variant, geo) |> dist() |> arrange(variant, match(geo, GEOS))
res_win  <- res |> filter(mi >= tm("2021-01"), mi <= tm("2023-12")) |> group_by(variant, geo) |> dist() |>
  arrange(variant, match(geo, GEOS))
norm_eff <- max(abs(res$residual_norm - res$residual))
show(res_full, "residual distribution, full common span (pp)")
show(res_win, "residual distribution, 2021-01..2023-12 (pp)")
cat(sprintf("max |effect of dividing by sum(w) instead of 1000| over all variants/geo-months: %.4f pp\n", norm_eff))
md_add("## 4. Aggregation residual: sum_i (w_i / 1000) x division YoY_i - headline YoY (pp)", "",
       md_table(variants |> select(variant, desc)),
       "Months = every month where the headline, all 13 division rates and all 13 weights exist.", "",
       "Full common span:", "", md_table(res_full),
       "2021-01..2023-12 only:", "", md_table(res_win),
       sprintf("Largest absolute change in any residual from dividing by sum(w) instead of 1000: %.4f pp.", norm_eff), "")

# ------------------------------------------------------------------------------
# 5. Exact published values (RCH_A, TOTAL); derived I15 shown for reference
# ------------------------------------------------------------------------------
cat("\n== 5. Exact values ==\n")
all_pub <- tot |> filter(unit == "RCH_A") |> transmute(geo, mi, month = fm(mi), RCH_A = values, flag_RCH_A = OBS_FLAG) |>
  left_join(hc |> select(geo, mi, der_I15), by = c("geo", "mi"))
win <- all_pub |> filter(mi >= tm("2021-01"), mi <= tm("2023-12"), !is.na(RCH_A))
stopifnot(all(win |> count(geo) |> pull(n) == 36), setequal(unique(win$geo), GEOS))
peaks <- win |> group_by(geo) |> filter(RCH_A == max(RCH_A)) |>
  summarise(peak_RCH_A = f2(first(RCH_A), 1), peak_month = paste(month, collapse = ", "),
            n_months_at_peak = n(), der_I15_at_peak = paste(f2(der_I15, 2), collapse = ", "),
            flags = paste(unique(na.omit(flag_RCH_A)), collapse = ",")) |>
  slice(match(GEOS, geo))
show(peaks, "(a)/(c) peak RCH_A TOTAL, 2021-01..2023-12")
oct <- all_pub |> filter(month == "2024-10") |>
  mutate(rank = min_rank(desc(RCH_A))) |> arrange(rank) |>
  transmute(rank, geo, RCH_A = f2(RCH_A, 1), der_I15 = f2(der_I15, 2), flag_RCH_A)
stopifnot(nrow(oct) == length(GEOS), all(oct$RCH_A != ""))
show(oct, "(b)/(d) RCH_A TOTAL, 2024-10, ranked descending (ties share the lower rank)")
md_add("## 5. Exact published values, TOTAL, unit RCH_A (annual rate of change, %)", "",
       "(a)/(c) Peak in 2021-01..2023-12 (all months listed if tied):", "", md_table(peaks),
       sprintf("(b) XK, 2024-10: RCH_A = %s.", oct$RCH_A[oct$geo == "XK"]), "",
       "(d) All geos, 2024-10, ranked by RCH_A descending (`min_rank`, ties share a rank):", "", md_table(oct))

# ------------------------------------------------------------------------------
# 6. BA: which Eurostat HICP tables carry geo BA (contentconstraint, cached)
# ------------------------------------------------------------------------------
cat("\n== 6. BA scan ==\n")
hicp_sets <- toc |> filter(type %in% c("dataset", "table"),
                           str_detect(title, "HICP|Harmonised index of consumer prices") |
                             str_detect(code, "^(prc_hicp|teicp|ei_cphi)")) |>
  select(code, type, title, last_update) |> arrange(code)
cc_dir <- file.path(toc_dir, "contentconstraint")
dir.create(cc_dir, showWarnings = FALSE)
geo_codes <- function(code) {
  f <- file.path(cc_dir, sprintf("eurostat_%s_contentconstraint.xml", code))
  if (!file.exists(f)) {
    ok <- tryCatch({ download.file(paste0(API, "sdmx/2.1/contentconstraint/ESTAT/", code), f,
                                   mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
    Sys.sleep(2)
    if (!ok) return(NA_character_)
  }
  x <- paste(readLines(f, warn = FALSE), collapse = "")
  blk <- str_match(x, '(?i)id="geo">(.*?)</c:KeyValue>')[, 2]
  if (is.na(blk)) return(NA_character_)
  paste(str_match_all(blk, "<c:Value>([^<]+)</c:Value>")[[1]][, 2], collapse = ",")
}
ba <- hicp_sets |> mutate(geos = map_chr(code, geo_codes),
                          parsed = !is.na(geos),
                          n_geo = ifelse(parsed, str_count(geos, ",") + 1L, NA_integer_),
                          has_BA = ifelse(parsed, str_detect(paste0(",", geos, ","), ",BA,"), NA),
                          wb_present = ifelse(parsed, map_chr(geos, function(g)
                            paste(intersect(PEERS, strsplit(g, ",")[[1]]), collapse = " ")), NA))
write_csv(ba, file.path(VER, "peers_ba_scan.csv"))
show(ba |> select(code, last_update, parsed, n_geo, has_BA, wb_present), "HICP tables: geo BA present?")
cat("tables scanned:", nrow(ba), "| parsed:", sum(ba$parsed), "| with BA:", sum(ba$has_BA, na.rm = TRUE), "\n")
md_add("## 6. BA in Eurostat HICP tables (SDMX contentconstraint, geo dimension)", "",
       sprintf("Tables scanned: %d (every catalogue dataset/table whose title contains \"HICP\" or \"Harmonised index of consumer prices\", or whose code starts prc_hicp / teicp / ei_cphi). Constraint parsed: %d. Listing geo BA in the constraint: %d (see 6b for whether data exist).",
               nrow(ba), sum(ba$parsed), sum(ba$has_BA, na.rm = TRUE)), "",
       md_table(ba |> select(code, title, last_update, n_geo, has_BA, wb_present)))

# 6b. What the tables that list BA hold for BA. Two routes, both saved raw:
#     (i) SDMX-CSV data query with the key filtered to geo BA;
#     (ii) the unfiltered bulk table (gitignored like the other bulk files),
#          which also shows rows published with an empty value.
cov_ba <- function(b, other) {
  b |> mutate(mi = tm(TIME_PERIOD), v = as.numeric(OBS_VALUE)) |>
    group_by(across(all_of(other))) |>
    summarise(rows = n(), n_obs = sum(!is.na(v)),
              first_month = if (any(!is.na(v))) fm(min(mi[!is.na(v)])) else NA_character_,
              last_month  = if (any(!is.na(v))) fm(max(mi[!is.na(v)])) else NA_character_,
              first_row_month = fm(min(mi)), last_row_month = fm(max(mi)),
              flags = flag_str(OBS_FLAG, mi)) |> ungroup()
}
for (code in ba$code[ba$has_BA %in% TRUE]) {
  dims <- str_match_all(paste(readLines(file.path(cc_dir, sprintf("eurostat_%s_contentconstraint.xml", code)),
                                        warn = FALSE), collapse = ""), 'KeyValue id="([^"]+)"')[[1]][, 2]
  dims  <- setdiff(dims, "TIME_PERIOD")
  other <- setdiff(dims, c("freq", "geo"))
  key   <- paste(ifelse(dims == "geo", "BA", ""), collapse = ".")
  q_url <- sprintf("%ssdmx/2.1/data/%s/%s?format=SDMX-CSV", API, code, key)
  b_url <- sprintf("%ssdmx/2.1/data/%s?format=SDMX-CSV&compressed=true", API, code)
  f_q <- file.path(toc_dir, sprintf("eurostat_%s_BA.csv", code))
  f_b <- file.path(toc_dir, bulk_name(code))
  for (p in list(c(q_url, f_q), c(b_url, f_b))) {
    if (file.exists(p[2])) cat("raw already present, skipping download:", p[2], "\n") else {
      download.file(p[1], p[2], mode = "wb", quiet = TRUE); Sys.sleep(2)
    }
  }
  bq <- read_csv(f_q, col_types = cols(.default = col_character()), progress = FALSE)
  bb <- read_csv(f_b, col_types = cols(.default = col_character()), progress = FALSE)
  cat("\n", code, "| key query geo BA rows:", nrow(bq), "| bulk rows:", nrow(bb),
      "| bulk rows geo BA:", sum(bb$geo == "BA"), "| bulk LAST UPDATE:",
      paste(unique(bb[["LAST UPDATE"]]), collapse = " | "), "\n")
  stopifnot(all(bq$geo == "BA"))
  bba <- bb |> filter(geo == "BA")
  lines <- c(sprintf("### 6b. `%s`, geo BA", code), "",
             sprintf("- Key query `%s`: %d rows.", q_url, nrow(bq)),
             sprintf("- Unfiltered bulk `%s` (LAST UPDATE %s): %d rows in total, %d with geo BA, of which %d carry a value.",
                     b_url, paste(unique(bb[["LAST UPDATE"]]), collapse = " | "), nrow(bb), nrow(bba),
                     sum(!is.na(suppressWarnings(as.numeric(bba$OBS_VALUE))))), "")
  if (nrow(bba)) {
    b_cov <- cov_ba(bba, other)
    show(b_cov, paste(code, "- BA rows in bulk"))
    lines <- c(lines, md_table(b_cov))
  }
  md_add(lines)
}

# ------------------------------------------------------------------------------
# 7. Metadata pages cited in peers_report.md, saved raw (cached, 2 s apart).
#    Read by hand for the report; nothing is parsed here. BHAS: the ESMS
#    metadata page only; the BHAS CPI data files are not downloaded.
# ------------------------------------------------------------------------------
cat("\n== 7. Metadata pages ==\n")
META <- c(
  eurostat_prc_hicp_esms.htm         = "https://ec.europa.eu/eurostat/cache/metadata/en/prc_hicp_esms.htm",
  eurostat_prc_hicp_esmshi_xk.htm    = "https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_xk.htm",
  eurostat_prc_hicp_esmshi_me.htm    = "https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_me.htm",
  eurostat_prc_hicp_esmshi_rs.htm    = "https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_rs.htm",
  eurostat_prc_hicp_esmshi_al.htm    = "https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_al.htm",
  eurostat_prc_hicp_esmshi3_al.htm   = "https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi3_al.htm",
  eurostat_prc_hicp_esmshi_mk.htm    = "https://ec.europa.eu/eurostat/cache/metadata/EN/prc_hicp_esmshi_mk.htm",
  eurostat_HICP_improvements_QA_2026_EN.pdf = "https://ec.europa.eu/eurostat/documents/272892/11336726/HICP+improvements+-+Questions+and+Answers-2026-EN.pdf/dff14a89-9f65-8371-e143-488231305710?t=1766052045691",
  bhas_esms_PRI00_cpi_EN.htm         = "https://bhas.gov.ba/data/Publikacije/ESMS/PRI00_mjesecno_istrazivanje_o_indeksu_potrosackih_cijena_u_BiH_EN.htm")
for (nm in names(META)) {
  f <- file.path(toc_dir, nm)
  if (file.exists(f)) { cat("raw already present, skipping download:", f, "\n"); next }
  download.file(META[[nm]], f, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
  cat("saved", f, sprintf("(%.0f KB)", file.size(f) / 1024), "\n")
}

writeLines(md, file.path(VER, "peers_tables_generated.md"), useBytes = TRUE)
cat("\nwrote verify/peers_tables_generated.md\nDone.\n")
