# ==============================================================================
# 02_pull_population.R
# Pull ASK census population by municipality for 2011 and 2024, both censuses.
# Table: census2024_00.px  "Population by age, sex and municipality, 2011 and 2024"
#   ASKdata > Census population > 1_Demographic_Characteristics
# Writes raw (Total sex, all ages incl. the "Total" aggregate) to data/raw/ and a
# tidy municipality x year table to data/processed/.
#
# Population concept: the KOSOVA (national) 2024 figure this table carries is
# 1,602,515 — i.e. INCLUDING ASK estimates for the four northern municipalities
# (Leposaviq, Mitrovica Veriore, Zubin Potok, Zveqan), which boycotted and are
# BLANK for 2011. The separately published "registered/enumerated" 2024 headline
# was 1,586,659. We map the table's concept and flag the north downstream.
#
# Run from the piece root:  Rscript R/02_pull_population.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr)
}))

proj <- "C:/Users/plato/Documents/kosovo-economy/census-vacancy"
source(file.path(proj, "R", "01_functions.R"))
raw_dir  <- file.path(proj, "data", "raw")
proc_dir <- file.path(proj, "data", "processed")

turl <- paste0(ASK_BASE,
  "/Census%20population/1_Demographic_Characteristics/census2024_00.px")

# --- Pull: Total sex, all municipalities (incl. KOSOVA), both years, all ages --
message("Pulling census2024_00.px (Total sex, all ages, 2011 & 2024) ...")
raw <- ask_pull(turl, list(Viti = "*", Komuna = "*", Gjinia = "0", Mosha = "*"))
val <- names(raw)[ncol(raw)]                       # "Number of population"
names(raw)[names(raw) == val] <- "population"
raw$population <- suppressWarnings(as.numeric(raw$population))   # north 2011 = "." -> NA
write_csv(raw, file.path(raw_dir, "census2024_00_population_total_sex.csv"))

# --- Verify-before-proceeding (house rule) ------------------------------------
cat("\nraw rows:", nrow(raw), " | cols:", paste(names(raw), collapse = " | "), "\n")
cat("5 sample rows:\n"); print(head(raw, 5), row.names = FALSE)

# --- Derive municipality x year totals (Age == "Total", the aggregate row) -----
pop <- raw |>
  filter(Age == "Total") |>
  select(muni_ask = Municipality, year = Year, population) |>
  pivot_wider(names_from = year, values_from = population,
              names_prefix = "pop_")

natl <- pop |> filter(muni_ask == "KOSOVA")
muni <- pop |> filter(muni_ask != "KOSOVA") |>
  mutate(pop_change_abs = pop_2024 - pop_2011,
         pop_change_pct = 100 * (pop_2024 - pop_2011) / pop_2011,
         has_2011       = !is.na(pop_2011))

write_csv(muni, file.path(proc_dir, "population_by_municipality.csv"))

# --- Report -------------------------------------------------------------------
cat(sprintf("\nNATIONAL (KOSOVA):  2011 = %s   2024 = %s   change = %+.1f%%\n",
            format(natl$pop_2011, big.mark = ","), format(natl$pop_2024, big.mark = ","),
            100 * (natl$pop_2024 - natl$pop_2011) / natl$pop_2011))
cat(sprintf("Municipalities: %d total | %d with 2011 data | %d with 2024 data\n",
            nrow(muni), sum(muni$has_2011), sum(!is.na(muni$pop_2024))))
cat(sprintf("Shrank 2011->2024 (of %d with both years): %d\n",
            sum(!is.na(muni$pop_change_pct)), sum(muni$pop_change_pct < 0, na.rm = TRUE)))
cat("No 2011 count (boycott):",
    paste(muni$muni_ask[!muni$has_2011], collapse = ", "), "\n")
cat("\nWrote:\n  ", file.path(raw_dir, "census2024_00_population_total_sex.csv"),
    "\n  ", file.path(proc_dir, "population_by_municipality.csv"), "\n")
