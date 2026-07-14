# ==============================================================================
# build_lookup.R  —  (re)generate data/lookup_municipalities.csv
#
# One-time / reviewed artifact. The municipality name crosswalk is HAND-SPECIFIED
# below (no silent fuzzy matching) and then machine-verified as a complete
# one-to-one match across three sources: geoBoundaries XKX ADM2 shapeName, the
# ASK population table (census2024_00), and the ASK dwellings table (census2024_51).
# Reviewed and confirmed 2026-07-13 (Stage 3, Checkpoint C).
#
# Run after 03_pull_vacancy.R and before 04_build_join.R:
#   Rscript R/build_lookup.R
# It is kept out of the numbered 02–05 sequence on purpose: the crosswalk is a
# reviewed artifact, not something to regenerate silently on every run.
# ==============================================================================
suppressWarnings(suppressMessages({ library(sf); library(dplyr); library(tibble); library(readr) }))

proj    <- "C:/Users/plato/Documents/kosovo-economy/census-vacancy"
raw_dir <- file.path(proj, "data", "raw")

# muni       = house-style display name (Albanian, definite)
# shapeName  = exact geoBoundaries ADM2 field (join key to polygons)
# pxweb_pop  = name in census2024_00 (population)
# pxweb_vac  = name in census2024_51 (dwellings)
lk <- tribble(
  ~muni,                ~shapeName,                         ~pxweb_pop,          ~pxweb_vac,            ~note,
  "Deçan",              "Municipality of Deçan",            "Deçan",             "Deçan",              "",
  "Dragash",            "Municipality of Dragash",          "Dragash",           "Dragash",            "",
  "Drenas",             "Municipality of Drenas",           "Gllogovc",          "Gllogoc",            "dual name: Drenas = Gllogoc/Gllogovc",
  "Ferizaj",            "Municipality of Ferizaj",          "Ferizaj",           "Ferizaj",            "",
  "Fushë Kosova",       "Municipality of Fushë Kosovë",     "Fushë Kosovë",      "Fushë Kosovë",       "display uses definite 'Kosova'",
  "Gjakova",            "Municipality of Gjakova",          "Gjakovë",           "Gjakovë",            "",
  "Gjilan",             "Municipality of Gjilan",           "Gjilan",            "Gjilan",             "",
  "Graçanica",          "Municipality of Gracanica",        "Graçanicë",         "Graçanicë",          "Serb-majority south",
  "Hani i Elezit",      "Municipality of Han i Elezit",     "Hani i Elezit",     "Hani i Elezit",      "",
  "Istog",              "Municipality of Istog",            "Istog",             "Istog",              "",
  "Junik",              "Municipality of Junik",            "Junik",             "Junik",              "",
  "Kamenica",           "Municipality of Kamenica",         "Kamenicë",          "Kamenicë",           "",
  "Kaçanik",            "Municipality of Kaçanik",          "Kaçanik",           "Kaçanik",            "",
  "Klina",              "Municipality of Klina",            "Klinë",             "Klinë",              "",
  "Kllokot",            "Municipality of Kllokot",          "Kllokot",           "Kllokot",            "Serb-majority south",
  "Leposaviq",          "Municipality of Leposaviq",        "Leposaviq",         "Leposaviq",          "NORTH (2024 estimate)",
  "Lipjan",             "Municipality of Lipjan",           "Lipjan",            "Lipjan",             "",
  "Malisheva",          "Municipality of Malisheva",        "Malishevë",         "Malishevë",          "",
  "Mamushë",            "Municipality of Mamusha",          "Mamushë",           "Mamushë",            "",
  "Mitrovica",          "Municipality of Mitrovica",        "Mitrovicë",         "Mitrovicë",          "",
  "Mitrovica e Veriut", "Municipality of North Mitrovica",  "Mitrovica Veriore", "Mitrovicë e Veriut", "NORTH (2024 estimate); 3 name variants",
  "Novobërdë",          "Municipality of Novobërdë",        "Novobërdë",         "Novobërdë",          "",
  "Obiliq",             "Municipality of Obiliq",           "Obiliq",            "Obiliq",             "",
  "Partesh",            "Municipality of Partesh",          "Partesh",           "Partesh",            "Serb-majority south",
  "Peja",               "Municipality of Peja",             "Pejë",              "Pejë",               "",
  "Podujeva",           "Municipality of Podujeva",         "Podujevë",          "Podujevë",           "",
  "Prishtina",          "Municipality of Pristina",         "Prishtinë",         "Prishtinë",          "",
  "Prizren",            "Municipality of Prizren",          "Prizren",           "Prizren",            "",
  "Rahovec",            "Municipality of Rahovec",          "Rahovec",           "Rahovec",            "",
  "Ranillug",           "Municipality of Ranillug",         "Ranillug",          "Ranillug",           "Serb-majority south",
  "Shtime",             "Municipality of Shtime",           "Shtime",            "Shtime",             "",
  "Shtërpca",           "Municipality of Shtërpcë",         "Shtërpcë",          "Shtërpcë",           "Serb-majority south",
  "Skenderaj",          "Municipality of Skenderaj",        "Skenderaj",         "Skënderaj",          "",
  "Suhareka",           "Municipality of Suhareka",         "Suharekë",          "Suharekë",           "",
  "Viti",               "Municipality of Viti",             "Viti",              "Viti",               "",
  "Vushtrri",           "Municipality of Vushtrri",         "Vushtrri",          "Vushtrri",           "",
  "Zubin Potok",        "Municipality of Zubin Potok",      "Zubin Potok",       "Zubin Potok",        "NORTH (2024 estimate)",
  "Zveçan",             "Municipality of Zveçan",           "Zveqan",            "Zveqan",             "NORTH (2024 estimate)"
)

# --- sources (geoBoundaries downloaded if missing; pinned commit) ---------------
bnd <- file.path(raw_dir, "geoBoundaries-XKX-ADM2.geojson")
if (!file.exists(bnd)) {
  dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)
  download.file("https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/XKX/ADM2/geoBoundaries-XKX-ADM2.geojson",
                bnd, mode = "wb", quiet = TRUE)
}
geo <- st_read(bnd, quiet = TRUE)$shapeName
pop <- read_csv(file.path(proj, "data/processed/population_by_municipality.csv"), show_col_types = FALSE)$muni_ask
vac <- setdiff(read_csv(file.path(proj, "data/processed/vacancy_by_municipality.csv"), show_col_types = FALSE)$muni_ask, "KOSOVA")

# --- verify complete bijection (stop on any mismatch) --------------------------
chk <- function(a, b) length(setdiff(a, b)) == 0 && length(setdiff(b, a)) == 0
stopifnot(
  "shapeName != geoBoundaries" = chk(lk$shapeName, geo),
  "pxweb_pop != population"    = chk(lk$pxweb_pop, pop),
  "pxweb_vac != vacancy"       = chk(lk$pxweb_vac, vac),
  "muni not unique"            = !any(duplicated(lk$muni)),
  "not 38 rows"                = nrow(lk) == 38)

write_csv(lk, file.path(proj, "data/lookup_municipalities.csv"))
cat("lookup_municipalities.csv written and verified: 38 municipalities, 1:1 across",
    "geoBoundaries / population / vacancy.\n")
