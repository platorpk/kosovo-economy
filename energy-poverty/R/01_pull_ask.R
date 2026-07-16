# ==============================================================================
# 01_pull_ask.R
# Pull the two ASK PxWeb series for the energy-poverty piece:
#   1. silc10.px  "Affordability of households to keep the house warm adequately"
#      ASKdata > Anketa mbi të Ardhurat dhe Kushtet e Jetesës (SILC), 2018-2024.
#      NOTE: the table title says "2023"; the year dimension runs 2018-2024.
#   2. cpi04.px   COICOP 04.5 (electricity, gas and other fuels) y-o-y series —
#      context only; the piece quotes at most one sentence from it.
# Excluded by design (approved Stage 1): silc12.px and Eurostat ilc_mdes07
# (payment/arrears indicators).
#
# Run from the piece root:  Rscript R/01_pull_ask.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(pxweb); library(dplyr); library(tidyr); library(readr)
}))

proj <- "C:/Users/plato/Documents/kosovo-economy/energy-poverty"
for (d in c("data/raw", "data/processed", "output"))
  dir.create(file.path(proj, d), recursive = TRUE, showWarnings = FALSE)

ask_base <- "https://askdata.rks-gov.net/api/v1/en/ASKdata"
enc <- function(x) URLencode(x, reserved = FALSE)

# --- 1. silc10: keep home adequately warm, 2018-2024 ---------------------------
silc_url <- paste0(ask_base, "/",
  enc("Anketa mbi të Ardhurat dhe Kushtet e Jetesës"), "/silc10.px")
message("Pulling silc10.px ...")
qry  <- pxweb_query(list(viti = "*", `e perballueshme` = "*"))
px   <- pxweb_get(silc_url, query = qry)
raw  <- as.data.frame(px, column.name.type = "text", variable.value.type = "text")
write_csv(raw, file.path(proj, "data/raw/silc10_keep_warm_raw.csv"))
Sys.sleep(2)

cat("\nsilc10 raw rows:", nrow(raw), "| cols:", paste(names(raw), collapse = " | "), "\n")
print(head(raw, 5), row.names = FALSE)

names(raw) <- c("year", "response", "value")
raw$value <- suppressWarnings(as.numeric(raw$value))
warm <- raw |>
  mutate(response = ifelse(grepl("^y", response, ignore.case = TRUE), "yes", "no")) |>
  pivot_wider(names_from = response, values_from = value) |>
  arrange(year)

# verify-before-proceeding: 7 years, shares sum to ~100
stopifnot(nrow(warm) == 7, setequal(warm$year, as.character(2018:2024)))
bad <- warm |> filter(abs(yes + no - 100) > 1)
if (nrow(bad)) stop("silc10 yes+no != 100 in: ", paste(bad$year, collapse = ", "))
write_csv(warm, file.path(proj, "data/processed/silc10_keep_warm.csv"))
cat("\n== Kosova: cannot keep home adequately warm (ASK silc10, % of households) ==\n")
print(as.data.frame(warm |> select(year, cannot_keep_warm = no)), row.names = FALSE)

# --- 2. cpi04: COICOP 04.5 y-o-y (context sentence only) ------------------------
cpi_url <- paste0(ask_base, "/", enc("Prices/Consumer Price Index/Monthly indicators"), "/cpi04.px")
message("\nPulling cpi04.px metadata ...")
meta <- pxweb_get(cpi_url)
dims <- vapply(meta$variables, function(v) v$code, character(1))
grp  <- meta$variables[[ grep("grup", dims, ignore.case = TRUE)[1] ]]
i045 <- grep("^04\\.5", unlist(grp$valueTexts))
stopifnot(length(i045) == 1)
code045 <- unlist(grp$values)[i045]
cat("04.5 label on en endpoint: '", unlist(grp$valueTexts)[i045], "' (code ", code045, ")\n", sep = "")

time_dim <- setdiff(dims, grp$code)[1]
qry2 <- pxweb_query(setNames(list("*", code045), c(time_dim, grp$code)))
px2  <- pxweb_get(cpi_url, query = qry2)
cpi  <- as.data.frame(px2, column.name.type = "text", variable.value.type = "text")
write_csv(cpi, file.path(proj, "data/raw/cpi04_coicop045_yoy_raw.csv"))
Sys.sleep(2)

names(cpi) <- c("month", "group", "yoy")
cpi$yoy <- suppressWarnings(as.numeric(cpi$yoy))
cpi <- cpi |> filter(!is.na(yoy)) |> arrange(month)
write_csv(cpi, file.path(proj, "data/processed/cpi_045_yoy.csv"))
cat("\ncpi 04.5 rows:", nrow(cpi), "| range:", cpi$month[1], "->", cpi$month[nrow(cpi)], "\n")
cat("last 6 y-o-y values:\n")
print(as.data.frame(tail(cpi |> select(month, yoy), 6)), row.names = FALSE)
