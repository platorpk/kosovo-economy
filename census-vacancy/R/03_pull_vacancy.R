# ==============================================================================
# 03_pull_vacancy.R
# Pull ASK census dwellings (conventional + vacant) by municipality, 2011 & 2024.
# Table: census2024_51.px  "Buildings and dwellings (inhabited and vacant) at the
#   national and municipal level for the years 2011 and 2024"
#   ASKdata > Census population > 5_Buildings, Dwellings, and Households
# Variables (dim "Zgjidh variablin"): we keep "Number of conventional dwellings"
# (the total stock) and "Number of vacant dwellings" (the subset). Vacancy share
# = vacant / conventional.
#
# The API carries municipal vacancy directly, so the PDF Tab 4.10 fallback in the
# brief is NOT needed. Note: this table spells a few municipalities differently
# from census2024_00 (e.g. Gllogoc vs Gllogovc) — reconciled in 04_build_join.R.
#
# Run from the piece root:  Rscript R/03_pull_vacancy.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr); library(jsonlite)
}))

proj <- "C:/Users/plato/Documents/kosovo-economy/census-vacancy"
source(file.path(proj, "R", "01_functions.R"))
raw_dir  <- file.path(proj, "data", "raw")
proc_dir <- file.path(proj, "data", "processed")

enc      <- function(x) URLencode(x, reserved = FALSE)
get_json <- function(u) tryCatch(fromJSON(u, simplifyVector = FALSE), error = function(e) NULL)
as_nodes <- function(r) do.call(rbind, lapply(r, function(x) data.frame(
  id = x$id %||% NA, type = x$type %||% NA, text = x$text %||% NA, stringsAsFactors = FALSE)))

# --- discover the census2024_51 table URL (avoids embedding non-ASCII path) ----
cpop <- paste0(ASK_BASE, "/", enc("Census population"))
sub  <- as_nodes(get_json(cpop))
fold <- sub$id[grepl("Buildings, Dwellings", sub$text, ignore.case = TRUE) |
               grepl("banesat", sub$id, ignore.case = TRUE)][1]
stopifnot(!is.na(fold))
turl_v <- paste0(cpop, "/", enc(fold), "/census2024_51.px")
message("dwellings table: ", turl_v)

# --- pull all 4 variables, both years, all municipalities ----------------------
raw <- ask_pull(turl_v, setNames(list("*", "*", "*"),
                                  c("Komuna", "Viti", "Zgjidh variablin")))
names(raw)[ncol(raw)] <- "value"
raw$value <- suppressWarnings(as.numeric(raw$value))
write_csv(raw, file.path(raw_dir, "census2024_51_dwellings.csv"))

cat("\nraw rows:", nrow(raw), " | cols:", paste(names(raw), collapse = " | "), "\n")
cat("variable categories:\n"); print(unique(raw[[3]]))
cat("5 sample rows:\n"); print(head(raw, 5), row.names = FALSE)

# --- keep conventional + vacant, reshape to municipality x year ----------------
sel_var <- names(raw)[3]                        # "Select the variable"
keep <- raw |>
  filter(grepl("conventional dwellings$", .data[[sel_var]], ignore.case = TRUE) |
         grepl("vacant dwellings",        .data[[sel_var]], ignore.case = TRUE)) |>
  mutate(metric = ifelse(grepl("vacant", .data[[sel_var]], ignore.case = TRUE),
                         "vacant", "conventional")) |>
  select(muni_ask = Municipality, year = Year, metric, value) |>
  pivot_wider(names_from = c(metric, year), values_from = value,
              names_glue = "{metric}_{year}") |>
  mutate(vac_share_2024 = 100 * vacant_2024 / conventional_2024,
         vac_share_2011 = 100 * vacant_2011 / conventional_2011)

write_csv(keep, file.path(proc_dir, "vacancy_by_municipality.csv"))

# --- verify national totals against the brief ----------------------------------
natl <- keep |> filter(muni_ask == "KOSOVA")
cat(sprintf("\nNATIONAL (KOSOVA) vacant dwellings:  2011 = %s   2024 = %s\n",
            format(natl$vacant_2011, big.mark = ","), format(natl$vacant_2024, big.mark = ",")))
cat("  brief targets: 2024 = 182,849   2011 = 99,808\n")
cat(sprintf("NATIONAL conventional dwellings:     2011 = %s   2024 = %s\n",
            format(natl$conventional_2011, big.mark = ","), format(natl$conventional_2024, big.mark = ",")))
cat(sprintf("NATIONAL vacancy share 2024 = %.1f%%   (2011 = %.1f%%)\n",
            natl$vac_share_2024, natl$vac_share_2011))

muni <- keep |> filter(muni_ask != "KOSOVA")
cat(sprintf("\nMunicipalities: %d | vacant sums to %s (vs KOSOVA %s)\n",
            nrow(muni), format(sum(muni$vacant_2024, na.rm = TRUE), big.mark = ","),
            format(natl$vacant_2024, big.mark = ",")))
cat("any conventional < vacant (impossible):",
    any(muni$vacant_2024 > muni$conventional_2024, na.rm = TRUE), "\n")

cat("\n== vacancy share 2024 by municipality (top & bottom 6) ==\n")
show <- muni |> arrange(desc(vac_share_2024)) |>
  transmute(muni_ask, conventional_2024, vacant_2024, vac_share_2024 = round(vac_share_2024, 1))
print(as.data.frame(bind_rows(head(show, 6), tail(show, 6))), row.names = FALSE)
