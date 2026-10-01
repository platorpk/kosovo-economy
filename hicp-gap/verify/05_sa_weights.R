# ==============================================================================
# 05_sa_weights.R  --  VERIFICATION ONLY
# Reports whether item weights exist for the main special aggregates FOOD, NRG,
# IGD_NNRG and SERV, for every geo (XK, ME, RS, AL, MK, EA) and year 2020-2026.
#
# Source table (Eurostat > Economy and finance > Prices > HICP > HICP - ECOICOP
# ver.2): prc_hicp_iw  item weights (annual). Read from the committed filtered
# record data/raw/2026-09-23/eurostat_prc_hicp_iw_WB_EA.rds (verify/02_peers.R).
# Code names: FOOD, NRG, IGD_NNRG, SERV are the coicop18 codes as published,
# labelled in the COICOP18 codelist (data/raw/2026-09-23/eurostat_codelist_COICOP18_3.2.tsv).
#
# Writes:
#   verify/sa_weights.csv                 geo x year x code, value / flag / status
#   verify/sa_weights_tables_generated.md every table in followup_report.md section 3
#
# Concept note: the sum of the four weights is reported against 1000, not
# asserted (whether the four partition the all-items index is not assumed).
#
# Run from the piece root:  Rscript verify/05_sa_weights.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(tidyr); library(stringr)
}))
options(width = 200, dplyr.summarise.inform = FALSE)

PROJ  <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
VER   <- file.path(PROJ, "verify")
GEOS  <- c("XK", "ME", "RS", "AL", "MK", "EA")
SA    <- c("FOOD", "NRG", "IGD_NNRG", "SERV")
YEARS <- 2020:2026

md <- character(); md_add <- function(...) md <<- c(md, ...)
md_table <- function(df) {
  df <- as.data.frame(df); df[] <- lapply(df, function(x) { x <- as.character(x); x[is.na(x)] <- ""; x })
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")), "")
}
show <- function(df, title) { cat("\n--", title, "--\n"); print(as.data.frame(df), row.names = FALSE) }

iw <- readRDS(file.path(PROJ, "data/raw/2026-09-23/eurostat_prc_hicp_iw_WB_EA.rds"))
lu <- unique(iw[["LAST UPDATE"]]); stopifnot(length(lu) == 1)
labels <- read_tsv(file.path(PROJ, "data/raw/2026-09-23/eurostat_codelist_COICOP18_3.2.tsv"),
                   col_names = c("coicop18", "label"), col_types = "cc", progress = FALSE)
lab <- labels |> filter(coicop18 %in% SA)
show(lab, "codelist labels")
stopifnot(setequal(lab$coicop18, SA))

grid <- expand_grid(geo = GEOS, year = YEARS, coicop18 = SA)
sa <- grid |>
  left_join(iw |> mutate(year = as.integer(time)) |> filter(coicop18 %in% SA) |>
              select(geo, year, coicop18, value_chr = values_chr, value = values, flag = OBS_FLAG),
            by = c("geo", "year", "coicop18")) |>
  mutate(status = case_when(is.na(value_chr) ~ "no row", is.na(value) ~ "row, empty value", TRUE ~ "value"),
         flag = coalesce(flag, ""))
stopifnot(nrow(sa) == length(GEOS) * length(YEARS) * length(SA))
write_csv(sa |> left_join(lab, by = "coicop18") |> select(geo, year, coicop18, label, value, flag, status),
          file.path(VER, "sa_weights.csv"))

status_tab <- sa |> count(coicop18, status) |> pivot_wider(names_from = status, values_from = n, values_fill = 0L)
show(status_tab, "status counts over geo x year")
wide <- sa |> mutate(cell = ifelse(status == "value", paste0(formatC(value, format = "f", digits = 2),
                                                             ifelse(flag != "", paste0(" (", flag, ")"), "")), status)) |>
  select(geo, year, coicop18, cell) |> pivot_wider(names_from = coicop18, values_from = cell) |>
  arrange(match(geo, GEOS), year)
sums <- sa |> group_by(geo, year) |>
  summarise(n_present = sum(status == "value"), sum_4 = if (all(status == "value")) sum(value) else NA_real_) |>
  mutate(dev_from_1000 = sum_4 - 1000)
tab <- wide |> left_join(sums, by = c("geo", "year")) |>
  mutate(sum_4 = formatC(sum_4, format = "f", digits = 2), dev_from_1000 = formatC(dev_from_1000, format = "f", digits = 2))
show(tab, "weights (per mille), 2020-2026")

md_add("# Generated tables: 05_sa_weights.R", "",
       sprintf("Eurostat `prc_hicp_iw`, LAST UPDATE %s (filtered record `eurostat_prc_hicp_iw_WB_EA.rds`).", lu), "",
       "## 3a. Codes (as published) and codelist labels", "", md_table(lab),
       sprintf("## 3b. Status over %d geo x year x code cells", nrow(sa)), "", md_table(status_tab),
       "## 3c. Item weights per mille, 2020-2026 (flag in brackets); sum of the four vs 1000 reported, not asserted", "",
       md_table(tab))
writeLines(md, file.path(VER, "sa_weights_tables_generated.md"), useBytes = TRUE)
cat("\nwrote verify/sa_weights.csv, verify/sa_weights_tables_generated.md\nDone.\n")
