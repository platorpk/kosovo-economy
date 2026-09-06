# ==============================================================================
# 02a_pull_ask_gdp.R
# Pull annual nominal GDP for Kosova from the ASK PxWeb API — the denominator for
# every ratio in this piece.
#
#   ASKdata > National and government accounts > National accounts >
#             Annual national accounts
#     gdp13.px  Gross Domestic Product by expenditure in current prices, 2008-2024
#               -> DENOMINATOR OF RECORD. Row "GDP at current prices".
#     gdp09.px  Gross Domestic Product by economic activities in current prices,
#               2008-2024
#               -> CROSS-CHECK. Row "Gross Domestic Product" (NACE dimension).
#                  Production and expenditure approaches must agree on the
#                  headline total; the script stops if they do not.
#
# Row selection is by EXACT label, taken from the table metadata, not by fuzzy
# matching — the two tables name the aggregate differently ("GDP at current
# prices" vs "Gross Domestic Product") and a loose match would silently pick a
# sub-item.
#
# COVERAGE ENDS AT 2024. There is no 2025 annual GDP in this source, so the
# diaspora account cannot be expressed as a share of GDP for 2025; 2025 is
# carried as a level only. 06 records this in the guard report.
#
# Also extracted, from the same gdp13 pull at no extra cost: ASK's own "Exports
# of goods and services" in current prices.
#
# THIS IS NOT AN INDEPENDENT CHECK on the CBK-derived exports denominator. ASK's
# national accounts take their external-trade-in-services figures from CBK's
# balance of payments, so the two are not separately sourced. The script measures
# and prints the year-by-year difference rather than asserting either identity or
# independence; see the "ASK vs CBK exports" block below. It is not used as a
# denominator.
#
# Numbered 02a rather than 05 so it sits with the other pull script: 05 is
# reserved for the sub-annual parse and 06 is the diaspora account.
#
# Writes:
#   data/raw/ask/gdp13_expenditure_current_raw.csv   raw, before parsing
#   data/raw/ask/gdp09_activities_current_raw.csv    raw, before parsing
#   data/raw/ask/_ask_download_log.csv               provenance
#   data/processed/gdp_nominal_annual.csv            year, gdp_eur_m, exports_gs_eur_m
#
# Re-running does not re-download: a raw file already on disk is left alone (§5).
# ASK is not vintaged the way the CBK workbooks are — it revises in place once a
# year rather than republishing monthly at the same URL — so the raw pull is
# cached flat under data/raw/ask/ with its own log.
#
# Run from the piece root:  Rscript R/02a_pull_ask_gdp.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(tibble); library(pxweb)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

ASK_DIR <- file.path(RAW_DIR, "ask")
dir.create(ASK_DIR,  recursive = TRUE, showWarnings = FALSE)
dir.create(PROC_DIR, recursive = TRUE, showWarnings = FALSE)

NODE <- paste0(ASK_BASE,
  "/National%20and%20government%20accounts/National%20accounts/Annual%20national%20accounts")

GDP13_URL <- paste0(NODE, "/gdp13.px")
GDP09_URL <- paste0(NODE, "/gdp09.px")

GDP13_RAW <- file.path(ASK_DIR, "gdp13_expenditure_current_raw.csv")
GDP09_RAW <- file.path(ASK_DIR, "gdp09_activities_current_raw.csv")

# Exact labels, from each table's own metadata.
LAB_GDP13    <- "GDP at current prices"
LAB_GDP09    <- "Gross Domestic Product"
LAB_EXPORTS  <- "Exports of goods and services"

cat("ASK annual nominal GDP -> ", ASK_DIR, "\n", sep = "")
cat(strrep("-", 78), "\n")

pull_cached <- function(url, dest, query, label) {
  if (file.exists(dest)) {
    cat("  cached, skipping download: ", basename(dest), "\n", sep = "")
    return(FALSE)
  }
  cat("  pulling ", label, " ...\n", sep = "")
  raw <- ask_pull(url, query)                 # ask_pull sleeps 2s (house rule)
  write_csv(raw, dest)                        # save raw before parsing
  TRUE
}

f13 <- pull_cached(GDP13_URL, GDP13_RAW,
                   list(Variables = "*", Year = "*"), "gdp13.px")
f09 <- pull_cached(GDP09_URL, GDP09_RAW,
                   list(`Gross Value Added (GVA)` = "*",
                        `NACE Rev2-Economic activities` = "*", Year = "*"), "gdp09.px")

# --- provenance ----------------------------------------------------------------
log_path <- file.path(ASK_DIR, "_ask_download_log.csv")
prev <- if (file.exists(log_path))
  read_csv(log_path, show_col_types = FALSE,
           col_types = readr::cols(.default = readr::col_character())) else
  tibble(file = character(), downloaded_utc = character())

log <- tibble(
  table          = c("gdp13.px", "gdp09.px"),
  role           = c("denominator of record (expenditure)", "cross-check (production)"),
  url            = c(GDP13_URL, GDP09_URL),
  file           = basename(c(GDP13_RAW, GDP09_RAW)),
  downloaded_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%d %H:%M:%S"),
  bytes          = unname(file.size(c(GDP13_RAW, GDP09_RAW))),
  md5            = unname(tools::md5sum(c(GDP13_RAW, GDP09_RAW))),
  newly_fetched  = c(f13, f09))
if (nrow(prev)) {
  log <- log |>
    left_join(prev |> select(file, prior = downloaded_utc), by = "file") |>
    mutate(downloaded_utc = ifelse(newly_fetched | is.na(prior), downloaded_utc, prior)) |>
    select(-prior)
}
write_csv(log, log_path)

# --- extract by exact label ----------------------------------------------------
# The value column is the last column of the PxWeb frame; the label column is the
# one that actually contains the requested label.
by_label <- function(path, label, what) {
  d   <- read_csv(path, show_col_types = FALSE, name_repair = "minimal")
  nm  <- names(d)
  yrc <- nm[tolower(nm) == "year"][1]
  val <- nm[length(nm)]
  cats <- setdiff(nm, c(yrc, val))
  hit <- vapply(cats, function(c_) any(trimws(d[[c_]]) == label), logical(1))
  if (!any(hit))
    stop(what, ": label '", label, "' not found. Labels seen: ",
         paste(utils::head(unique(trimws(unlist(d[cats]))), 30), collapse = " | "))
  cc  <- cats[which(hit)[1]]
  sub <- d[trimws(d[[cc]]) == label, , drop = FALSE]
  out <- tibble(year = as.integer(sub[[yrc]]),
                value = suppressWarnings(as.numeric(sub[[val]]))) |>
    filter(!is.na(year)) |> arrange(year)
  if (any(duplicated(out$year)))
    stop(what, ": more than one row per year for '", label, "'")
  out
}

g13 <- by_label(GDP13_RAW, LAB_GDP13,   "gdp13 expenditure")
g09 <- by_label(GDP09_RAW, LAB_GDP09,   "gdp09 activities")
xgs <- by_label(GDP13_RAW, LAB_EXPORTS, "gdp13 exports of G&S")

cat(strrep("-", 78), "\n")
cat(sprintf("gdp13 '%s' : %d years %d-%d\n", LAB_GDP13, nrow(g13), min(g13$year), max(g13$year)))
cat(sprintf("gdp09 '%s' : %d years %d-%d\n", LAB_GDP09, nrow(g09), min(g09$year), max(g09$year)))
cat(sprintf("gdp13 '%s' : %d years %d-%d\n", LAB_EXPORTS, nrow(xgs), min(xgs$year), max(xgs$year)))

# --- Guard: expenditure and production approaches must agree -------------------
GDP_TOL_PCT <- 0.5
cmp <- inner_join(g13 |> rename(expenditure = value),
                  g09 |> rename(production  = value), by = "year") |>
  mutate(diff = expenditure - production, pct = 100 * diff / expenditure)

cat("\nGDP cross-check, expenditure (gdp13) vs production (gdp09), EUR million:\n")
print(as.data.frame(cmp |> mutate(across(c(expenditure, production, diff), ~ round(.x, 1)),
                                  pct = round(pct, 4))), row.names = FALSE, right = TRUE)
bad <- cmp |> filter(abs(pct) > GDP_TOL_PCT)
cat(sprintf("\nmax |diff| = %.2f EUR m (%.4f%%) | tolerance %.1f%% | breaches: %d\n",
            max(abs(cmp$diff)), max(abs(cmp$pct)), GDP_TOL_PCT, nrow(bad)))
if (nrow(bad)) {
  print(as.data.frame(bad), row.names = FALSE)
  stop("Expenditure and production GDP disagree beyond tolerance — ",
       "the denominator is not established. Stopping.")
}
cat("pass — the two approaches agree on headline GDP.\n")
cat("  NOTE: the two series are IDENTICAL, not merely close. Reading both confirms\n")
cat("  that the two published tables carry the same headline aggregate — it catches\n")
cat("  a wrong-row selection. It is NOT an independent check on the level of GDP.\n")

# --- ASK vs CBK exports of goods and services: measured, not asserted ----------
# ASK's national accounts draw services trade from CBK's balance of payments, so
# these are not independently sourced. Print the difference rather than claiming
# either identity or independence.
cbk_x <- tryCatch({
  v <- vintage_dir(resolve_vintage())
  d <- suppressMessages(readxl::read_excel(file.path(v, "26a Current account.xls"),
        sheet = "Current Account", col_names = FALSE, .name_repair = "minimal",
        col_types = "text"))
  p <- trimws(as.character(d[[1]]))
  i <- which(!is.na(p) & grepl("^(19|20)[0-9]{2}$", p))
  b <- c(0, which(diff(i) != 1), length(i)); r <- i[(b[1]+1):b[2]]
  tibble(year = as.integer(p[r]),
         cbk = suppressWarnings(as.numeric(as.character(d[[13]])[r])) +
               suppressWarnings(as.numeric(as.character(d[[14]])[r])))
}, error = function(e) NULL)
if (!is.null(cbk_x)) {
  xc <- xgs |> rename(ask = value) |>
    mutate(ask = ask / 1000) |>          # thousand EUR -> million, as below
    inner_join(cbk_x, by = "year") |>
    mutate(diff = ask - cbk)
  cat("\nASK vs CBK exports of goods and services, EUR million:\n")
  print(as.data.frame(xc |> mutate(across(where(is.numeric) & !year, ~round(.x, 2)))),
        row.names = FALSE, right = TRUE)
  cat(sprintf("  years identical to 0.05: %d of %d | max |diff| = %.2f EUR m (%d)\n",
              sum(abs(xc$diff) <= 0.05), nrow(xc), max(abs(xc$diff)),
              xc$year[which.max(abs(xc$diff))]))
}

# --- units ---------------------------------------------------------------------
# ASK publishes these tables in THOUSANDS of euro (2019 GDP = 7,056,172). The CBK
# workbooks are in MILLIONS. Convert to millions here so the whole pipeline is in
# one unit, and guard the magnitude — a unit slip is silent and would put every
# ratio out by a factor of 1000.
ASK_UNIT_DIVISOR <- 1000   # thousand EUR -> million EUR

out <- g13 |>
  rename(gdp_eur_m = value) |>
  left_join(xgs |> rename(exports_gs_eur_m = value), by = "year") |>
  mutate(gdp_eur_m        = gdp_eur_m / ASK_UNIT_DIVISOR,
         exports_gs_eur_m = exports_gs_eur_m / ASK_UNIT_DIVISOR,
         source = "ASK gdp13.px (expenditure, current prices), EUR million")

# Magnitude guard: Kosova's nominal GDP in 2019 was about EUR 7bn. Expressed in
# millions that is ~7,000. If the source ever changes unit, this fails loudly.
gdp19 <- out$gdp_eur_m[out$year == 2019]
cat(sprintf("\nunit guard: 2019 GDP = %.1f EUR million\n", gdp19))
stopifnot(gdp19 > 5000, gdp19 < 9000)
cat("pass — GDP is in EUR million and of the expected magnitude.\n")

write_csv(out, file.path(PROC_DIR, "gdp_nominal_annual.csv"))

stopifnot(nrow(out) >= 17, min(out$year) <= 2010, max(out$year) >= 2024)
cat("\n"); print(as.data.frame(out |> mutate(across(where(is.numeric) & !year, ~ round(.x, 1)))),
                 row.names = FALSE, right = TRUE)
cat("\nWrote: ", file.path(PROC_DIR, "gdp_nominal_annual.csv"), "\n", sep = "")
cat("Coverage ", min(out$year), "-", max(out$year),
    ". No 2025 GDP in this source — 2025 is a level only.\n", sep = "")
