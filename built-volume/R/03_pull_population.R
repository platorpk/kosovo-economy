# ==============================================================================
# 03_pull_population.R
# Pull ASK Census 2024 population by municipality — the denominator for built
# volume per resident.
#
# Table: census2024_00.px "Population by age, sex and municipality, 2011 and 2024"
#   ASKdata > Census population > 1_Demographic_Characteristics
#
# Vintage choice: the 2024 census is used rather than an inter-censal estimate
# for 2019 (which would match the imagery better). ASK's pre-census estimates
# were revised sharply downward by the 2024 enumeration, so a 2019 estimate
# would import a known-biased denominator. The five-year gap is stated as a
# limitation instead — see README.
#
# The national total carried by this table is 1,602,515, which INCLUDES ASK
# estimates for the four northern municipalities that boycotted; the separately
# published registered enumeration was 1,586,659.
#
# Run from the piece root:  Rscript R/03_pull_population.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(pxweb); library(dplyr); library(tidyr); library(readr)
}))
source("C:/Users/plato/Documents/kosovo-economy/built-volume/R/01_functions.R")

turl <- paste0(ASK_BASE,
  "/Census%20population/1_Demographic_Characteristics/census2024_00.px")

message("Pulling census2024_00.px (2024, Total sex, all ages) ...")
raw <- ask_pull(turl, list(Viti = "1", Komuna = "*", Gjinia = "0", Mosha = "*"))
names(raw)[ncol(raw)] <- "population"
raw$population <- suppressWarnings(as.numeric(raw$population))
write_csv(raw, file.path(PROJ, "data/raw/census2024_00_population_2024.csv"))

cat("raw rows:", nrow(raw), "| cols:", paste(names(raw), collapse = " | "), "\n")

# Age == "Total" is the aggregate row; using it avoids double counting
pop <- raw |>
  filter(Age == "Total") |>
  select(muni_ask = Municipality, pop_2024 = population)

natl <- pop$pop_2024[pop$muni_ask == "KOSOVA"]
cat(sprintf("national (KOSOVA) 2024: %s  [registered alternative: 1,586,659]\n",
            format(natl, big.mark = ",")))
stopifnot(natl == 1602515)

# --- canonical Albanian names via the reviewed crosswalk ----------------------
lk <- read_csv(file.path(PROJ, "data/lookup_municipalities.csv"), show_col_types = FALSE)
muni <- pop |> filter(muni_ask != "KOSOVA")
bad <- setdiff(muni$muni_ask, lk$pxweb_pop)
if (length(bad)) stop("Unmatched PxWeb municipality names: ", paste(bad, collapse = ", "))

out <- muni |>
  left_join(lk |> select(muni, shapeName, pxweb_pop), by = c("muni_ask" = "pxweb_pop")) |>
  mutate(is_north = muni %in% NORTH) |>
  select(muni, shapeName, pop_2024, is_north) |>
  arrange(muni)

stopifnot(nrow(out) == 38, !any(is.na(out$muni)), !any(is.na(out$pop_2024)),
          sum(out$is_north) == 4, sum(out$pop_2024) == natl)
write_csv(out, file.path(PROJ, "data/processed/population_2024.csv"))

cat("\n38 municipalities, sum matches national total.\n")
cat("northern four (ASK estimates):",
    paste(sprintf("%s %s", out$muni[out$is_north],
                  format(out$pop_2024[out$is_north], big.mark = ",")), collapse = " | "), "\n")
cat("wrote data/processed/population_2024.csv\n")
