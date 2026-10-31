# ==============================================================================
# 01_e3_age_check.R
# Verification step 3 (2026-10-24). No estimation.
# Question: does ASK publish 2024 employment rates (or employed and population)
# by sex x education x age, so that a 25-64 (or 25+) version of the pooled
# table could be built from published tables? If not, what age information
# exists at all for the education categories?
#
# Method: read the metadata (variables, value labels, years) of every table in
#   ASKdata > Labour market > Anketa e Fuqisë Punëtore > Annual labour market
#   ASKdata > Labour market > Anketa e Fuqisë Punëtore > Quarterly labour market
#   ASKdata > Census population > 2_Education
#   ASKdata > Census population > 4_Labour market
# and classify each table by whether it carries an education dimension, an age
# dimension, a sex dimension, a labour-status measure, and 2024. Metadata are
# cached raw (one JSON) before classification. Any table that crosses
# education x age is then pulled for 2024 and its cells are sized.
# The LFS 2024 annual report (PDF, cached) is also searched for education x age
# tables.
#
# Writes: data/raw/ask_pxweb_metadata_e3.json, checks/e3_table_inventory.csv,
#   checks/e3_age_*.csv, checks/e3_numbers.json (not published),
#   figures.json (check_e3_* keys)
# Run from the piece root:  Rscript R/01_e3_age_check.R
# ==============================================================================
source("R/00_functions.R")

folders <- c(
  lfs_annual    = "Labour market/Anketa e Fuqisë Punëtore/Annual labour market",
  lfs_quarterly = "Labour market/Anketa e Fuqisë Punëtore/Quarterly labour market",
  census_educ   = "Census population/2_Education",
  census_labour = "Census population/4_Labour market"
)
enc <- function(p) paste(vapply(strsplit(p, "/")[[1]], utils::URLencode, "", reserved = TRUE),
                         collapse = "/")

# --- 1. Metadata, cached raw ------------------------------------------------------
meta_file <- file.path(RAW_DIR, "ask_pxweb_metadata_e3.json")
if (file.exists(meta_file)) {
  cat("raw already present, skipping download:", basename(meta_file), "\n")
} else {
  all_meta <- list()
  for (f in names(folders)) {
    url <- paste0(ASK_BASE, "/", enc(folders[[f]]))
    lst <- jsonlite::fromJSON(url); Sys.sleep(POLITE_SLEEP)
    tabs <- lst[lst$type == "t", c("id", "text")]
    for (i in seq_len(nrow(tabs))) {
      m <- tryCatch(jsonlite::fromJSON(paste0(url, "/", utils::URLencode(tabs$id[i], reserved = TRUE)),
                                       simplifyVector = FALSE),
                    error = function(e) list(error = conditionMessage(e)))
      Sys.sleep(POLITE_SLEEP)
      all_meta[[length(all_meta) + 1]] <- list(folder = f, path = folders[[f]], id = tabs$id[i],
                                               listing_text = tabs$text[i], meta = m)
    }
  }
  writeLines(enc2utf8(toJSON(all_meta, auto_unbox = TRUE, pretty = FALSE)), meta_file, useBytes = TRUE)
  log_download(basename(meta_file), paste0(ASK_BASE, "/{", paste(folders, collapse = ","), "}"),
               "ASK PxWeb metadata", TRUE)
}
all_meta <- fromJSON(meta_file, simplifyVector = FALSE)

# --- 2. Classify each table -------------------------------------------------------
educ_re <- "educ|arsim|shkollim|Niveli|Tertiary|Terciar|Primary|Fillor|gymnasium|gjimnaz"
age_re  <- "\\bage\\b|mosha|grup-?mosh|Age group|^[0-9]{2} ?- ?[0-9]{2}$|^[0-9]{2}\\+$|and over|e më shumë"
inv <- map_dfr(all_meta, function(x) {
  m <- x$meta
  if (!is.null(m$error) || is.null(m$variables))
    return(tibble(folder = x$folder, id = x$id, title = x$listing_text, error = m$error %||% "no variables"))
  vars <- m$variables
  vtext <- vapply(vars, function(v) v$text, "")
  vals  <- lapply(vars, function(v) unlist(v$valueTexts))
  is_educ <- vapply(seq_along(vars), function(i)
    grepl(educ_re, vtext[i], ignore.case = TRUE) ||
      sum(grepl("Tertiary|Terciar|Primary|Fillor|gymnasium|gjimnaz|vocational|profesional", vals[[i]],
                ignore.case = TRUE)) >= 2, logical(1))
  is_age <- vapply(seq_along(vars), function(i)
    grepl("age|mosh", vtext[i], ignore.case = TRUE) ||
      sum(grepl("^[0-9]{1,2} ?- ?[0-9]{1,2}$|^[0-9]{2}\\+$|and over", vals[[i]])) >= 2, logical(1))
  is_age <- is_age & !is_educ
  is_sex <- vapply(vtext, function(t) grepl("sex|gender|gjini", t, ignore.case = TRUE), logical(1))
  is_year <- vapply(vtext, function(t) grepl("year|viti|period|quarter|tremujor", t, ignore.case = TRUE), logical(1))
  years <- if (any(is_year)) unlist(vals[is_year]) else character()
  tibble(folder = x$folder, id = x$id, title = m$title %||% x$listing_text, error = NA_character_,
         variables = paste(vtext, collapse = " | "),
         has_educ = any(is_educ), has_age = any(is_age), has_sex = any(is_sex),
         educ_values = if (any(is_educ)) paste(vals[[which(is_educ)[1]]], collapse = "; ") else NA_character_,
         age_values  = if (any(is_age)) paste(vals[[which(is_age)[1]]], collapse = "; ") else NA_character_,
         has_2024 = any(grepl("2024", years)),
         measure_values = paste(unlist(vals[!is_educ & !is_age & !is_sex & !is_year]), collapse = "; "))
})
stopifnot(nrow(inv) == length(all_meta))
write_utf8_csv(inv, "e3_table_inventory.csv")
cat("\nTables scanned:", nrow(inv), "| errors:", sum(!is.na(inv$error)), "\n")
print(inv |> count(folder, has_educ, has_age), n = 40)

cross <- inv |> filter(has_educ, has_age)
cat("\nTables with education x age:\n"); print(cross |> select(folder, id, title, has_sex, has_2024), width = 200)
educ_any <- inv |> filter(has_educ)
cat("\nAll tables with an education dimension:\n")
print(educ_any |> select(folder, id, title, has_age, age_values), width = 250, n = 50)

# --- 3. LFS 2024 report: any education x age table? --------------------------------
rep24 <- file.path(RAW_DIR, "lfs_docs", "ask_085719f6-0ef0-4365-afa7-9a02c8d10cf5.pdf")
tx <- pdftools::pdf_text(rep24)
tab_titles <- unique(unlist(lapply(tx, function(p) {
  l <- str_squish(strsplit(p, "\n")[[1]]); l[grepl("^Tab\\.? ?[0-9]", l)]
})))
educ_age_titles <- tab_titles[grepl("arsim", tab_titles, ignore.case = TRUE) &
                              grepl("mosh", tab_titles, ignore.case = TRUE)]
cat("\nLFS 2024 report table titles with both education and age:\n"); print(educ_age_titles)
# Section heading "Punësimi sipas grup moshës dhe nivelit arsimor" exists; record
# whether the tables under it actually cross the two.
sec_pages <- which(grepl("Punësimi sipas grup moshës dhe nivelit arsimor", tx))

# --- 4. The census route: employed (lc07ensus) and population (tabcensusedu1) ------
# Only sizes are computed here (counts per cell); no rate is built; the census
# rates are built in 04b from lc06ensus.
node_lab <- paste0(ASK_BASE, "/", enc("Census population/4_Labour market"))
node_edu <- paste0(ASK_BASE, "/", enc("Census population/2_Education"))
emp_raw <- ask_pull_cached(paste0(node_lab, "/lc07ensus.px"),
                           list(Komuna = "*", Grupmosha = "*", Gjinia = "*",
                                `Niveli me i larte i arsimit` = "*"),
                           "ask_census2024_lc07_employed_educ_age_sex.csv")
pop_raw <- ask_pull_cached(paste0(node_edu, "/tabcensusedu1.px"),
                           list(`Highest level of education completed` = "*", Sex = "*", Age = "*"),
                           "ask_census2024_edu1_population_educ_age_sex.csv")
verify_block(emp_raw, "lc07ensus raw"); verify_block(pop_raw, "tabcensusedu1 raw")
emp <- emp_raw |> setNames(c("muni", "age", "sex", "educ", "n")) |> mutate(n = suppressWarnings(as.numeric(n)))
pop <- pop_raw |> setNames(c("educ", "sex", "age", "n")) |> mutate(n = suppressWarnings(as.numeric(n)))
cat("non-numeric / NA cells: lc07", sum(is.na(emp$n)), "| edu1", sum(is.na(pop$n)), "\n")

# Education mapping to the three pooled categories (by exact label)
emp_map <- c("No formal education" = "low", "No level of education completed" = "low",
             "Primary School - Total" = "low", "Secondary School - Total" = "upper",
             "Higher School" = "tertiary", "Faculty" = "tertiary", "Bachelor" = "tertiary",
             "Postgraduate (Master)" = "tertiary", "Doctorate" = "tertiary",
             "Other" = "unassigned", "Unknown" = "unassigned")
pop_map <- c("No formal education" = "low", "No level completed" = "low",
             "Primary, 4 grades old system" = "low", "Primary, 5 grades new system" = "low",
             "Lower secondary, 8 grades old system" = "low", "Lower secondary, 9 grades new system" = "low",
             "Higher secondary, 12 grades old system" = "upper", "Higher secondary, 13 grades new system" = "upper",
             "Higher school" = "tertiary", "Faculty, Bachelor's" = "tertiary",
             "Postgraduate (Master's)" = "tertiary", "Doctorate/PhD" = "tertiary", "Unknown" = "unassigned")
stop_if_unmatched(setdiff(unique(emp$educ), c("Total", grep("^(Primary|Secondary) School - (?!Total)", unique(emp$educ),
                                                            value = TRUE, perl = TRUE))), names(emp_map), "lc07 education")
stop_if_unmatched(setdiff(unique(pop$educ), "Kosova"), names(pop_map), "edu1 education")

ek <- emp |> filter(muni == "KOSOVA")
# Identities within lc07 (hard): sub-rows sum to their totals; mapped rows sum to Total
sub_sum <- function(prefix) ek |> filter(startsWith(educ, prefix), educ != paste0(prefix, "Total")) |>
  group_by(age, sex) |> summarise(s = sum(n), .groups = "drop") |>
  left_join(ek |> filter(educ == paste0(prefix, "Total")) |> select(age, sex, tot = n), by = c("age", "sex"))
for (pf in c("Primary School - ", "Secondary School - ")) { s <- sub_sum(pf); stopifnot(all(s$s == s$tot)) }
id_emp <- ek |> filter(educ %in% names(emp_map)) |> group_by(age, sex) |> summarise(s = sum(n), .groups = "drop") |>
  left_join(ek |> filter(educ == "Total") |> select(age, sex, tot = n), by = c("age", "sex"))
stopifnot(all(id_emp$s == id_emp$tot))
id_pop <- pop |> filter(educ %in% names(pop_map)) |> group_by(age, sex) |> summarise(s = sum(n), .groups = "drop") |>
  left_join(pop |> filter(educ == "Kosova") |> select(age, sex, tot = n), by = c("age", "sex"))
stopifnot(all(id_pop$s == id_pop$tot))
# KOSOVA row vs sum of municipalities (lc07), and the northern four
mun_sum <- emp |> filter(muni != "KOSOVA", age == "15-64", sex == "Total", educ == "Total")
north_lab <- c("Leposaviq", "Zubin Potok", "Zveqan", "Mitrovica Veriore")
kos_15_64 <- ek$n[ek$age == "15-64" & ek$sex == "Total" & ek$educ == "Total"]
stopifnot(sum(mun_sum$n) == kos_15_64)
north_emp <- mun_sum$n[mun_sum$muni %in% north_lab]
stopifnot(length(north_emp) == 4)

ages_2564 <- c("25-29", "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60-64")
pop_ages_2564 <- gsub("-", " - ", ages_2564)
stopifnot(all(ages_2564 %in% ek$age), all(pop_ages_2564 %in% pop$age))
cells_pop <- pop |> filter(age %in% pop_ages_2564, sex != "Total", educ %in% names(pop_map)) |>
  mutate(cat = pop_map[educ]) |> group_by(cat, sex) |> summarise(population = sum(n), .groups = "drop")

# --- 4b. Sex labels: lc07 vs lc06 (same census, same agency) ------------------------
# lc06ensus "Employed by gender, education level and age group, 2024" carries the
# same employed totals. Its sex labels are compared with lc07's. This is a check
# across separately published tables: the outcome is recorded, not reconciled, and
# neither table is edited. Whichever table disagrees with the LFS and with
# tabcensusedu1 on sex is not used for sizing.
lc06_raw <- ask_pull_cached(paste0(node_lab, "/lc06ensus.px"),
                            list(Komuna = "0", Grupmosha = "*", `Niveli me i larte i arsimit` = "*",
                                 Gjinia = "*"),
                            "ask_census2024_lc06_employed_educ_age_sex_kosova.csv")
l6 <- lc06_raw |> setNames(c("muni", "age", "educ", "sex", "n")) |> mutate(n = as.numeric(n))
stopifnot(all(l6$muni == "KOSOVA"), !anyNA(l6$n))
tot_by_sex <- function(d) d |> filter(age == "15-64", educ == "Total", sex != "Total") |>
  select(sex, n) |> arrange(sex)
t6 <- tot_by_sex(l6); t7 <- tot_by_sex(ek)
stopifnot(sum(t6$n) == sum(t7$n))                        # same grand total
lc07_labels_match_lc06   <- identical(t7$n[t7$sex == "Male"], t6$n[t6$sex == "Male"])
lc07_matches_lc06_swapped <- identical(t7$n[t7$sex == "Male"], t6$n[t6$sex == "Female"]) &&
                             identical(t7$n[t7$sex == "Female"], t6$n[t6$sex == "Male"])
lfs_men_more <- TRUE  # LFS 2024 tab3: men 300.352k, women 114.141k (asserted in 03)
lc06_men_more <- t6$n[t6$sex == "Male"] > t6$n[t6$sex == "Female"]
lc07_men_more <- t7$n[t7$sex == "Male"] > t7$n[t7$sex == "Female"]
cat("lc07 sex labels match lc06:", lc07_labels_match_lc06,
    "| lc07 matches lc06 with labels swapped:", lc07_matches_lc06_swapped, "\n")
# Last-updated stamps from the PxWeb folder listing (cached raw)
lst_file <- file.path(RAW_DIR, "ask_pxweb_listing_census_labour.json")
if (!file.exists(lst_file)) {
  writeLines(toJSON(jsonlite::fromJSON(node_lab), auto_unbox = TRUE, pretty = TRUE), lst_file, useBytes = TRUE)
  Sys.sleep(POLITE_SLEEP); log_download(basename(lst_file), node_lab, "ASK PxWeb listing", TRUE)
}
lst <- fromJSON(lst_file)
upd <- function(id) if ("updated" %in% names(lst)) lst$updated[lst$id == id] %||% NA else NA
# Impossible-value check on lc07 as labelled: employed must not exceed population
lc07_cells <- ek |> filter(age %in% ages_2564, sex != "Total", educ %in% names(emp_map)) |>
  mutate(cat = emp_map[educ]) |> group_by(cat, sex) |> summarise(employed = sum(n), .groups = "drop") |>
  left_join(cells_pop, by = c("cat", "sex"))
lc07_impossible <- lc07_cells |> filter(employed > population)
print(lc07_impossible)

# --- 4c. Sizing from lc06 (bands 25-54 + 55-64 = 25-64) ------------------------------
# lc07 is not used for any sex-specific figure (labels contradict lc06, the LFS and
# tabcensusedu1). lc06 education labels mapped by exact label; its "Primary
# education" total equals lc07's "Primary School - Total", which includes the
# 8/9-grade lower-secondary rows (checked below).
l6_map <- c("No education" = "low", "Primary education" = "low", "Secondary education" = "upper",
            "Higher school" = "tertiary", "Faculty, Bachelor's degree" = "tertiary",
            "Postgraduate (Master's degree)" = "tertiary", "Doctorate" = "tertiary",
            "Other" = "unassigned", "Unknown" = "unassigned")
stop_if_unmatched(setdiff(unique(l6$educ), "Total"), names(l6_map), "lc06 education")
id6 <- l6 |> filter(educ %in% names(l6_map)) |> group_by(age, sex) |> summarise(s = sum(n), .groups = "drop") |>
  left_join(l6 |> filter(educ == "Total") |> select(age, sex, tot = n), by = c("age", "sex"))
stopifnot(all(id6$s == id6$tot))                          # identity within lc06 (hard)
prim_l6 <- l6$n[l6$age == "15-64" & l6$sex == "Total" & l6$educ == "Primary education"]
prim_l7 <- ek$n[ek$age == "15-64" & ek$sex == "Total" & ek$educ == "Primary School - Total"]
lc06_primary_includes_lower_secondary <- prim_l6 == prim_l7
stopifnot(all(c("25-54", "55-64") %in% l6$age))
cells_emp <- l6 |> filter(age %in% c("25-54", "55-64"), sex != "Total", educ %in% names(l6_map)) |>
  mutate(cat = l6_map[educ]) |> group_by(cat, sex) |> summarise(employed = sum(n), .groups = "drop")
cells <- full_join(cells_emp, cells_pop, by = c("cat", "sex")) |>
  mutate(cat = factor(cat, c("low", "upper", "tertiary", "unassigned"))) |> arrange(cat, sex)
stopifnot(nrow(cells) == 8, !anyNA(cells))
stopifnot(all(cells$employed <= cells$population))        # impossible values (hard, lc06 path)
print(cells)
write_utf8_csv(cells, "e3_age_census_2564_cell_sizes.csv")
band <- l6 |> filter(age %in% c("25-54", "55-64"), sex != "Total", educ %in% names(l6_map)) |>
  mutate(cat = l6_map[educ]) |> filter(cat != "unassigned") |>
  group_by(age, cat, sex) |> summarise(employed = sum(n), .groups = "drop") |> arrange(employed)
write_utf8_csv(band, "e3_age_census_band_cells.csv")
TINY <- 1000
# Cross-source comparisons, 15-64 (reported, not reconciled): census vs LFS
pop_1564_census <- pop |> filter(educ == "Kosova", sex == "Total",
                                 age %in% c("15 - 19", "20 - 24", pop_ages_2564)) |> pull(n) |> sum()
lfs_tab0 <- read_csv(file.path(RAW_DIR, "ask_lfs_tab0_population.csv"), show_col_types = FALSE) |>
  setNames(c("v", "age", "year", "sex", "n")) |>
  filter(v == "Population ('000s)", age == "15-64", year == 2024, sex == "Total") |> pull(n) |> as.numeric()
lfs_t3 <- read_csv(file.path(RAW_DIR, "ask_lfs_tab3_employment_by_education_sex.csv"), show_col_types = FALSE) |>
  setNames(c("v", "educ", "year", "sex", "n")) |>
  filter(v == "Employment ('000s)", educ == "Total", year == 2024, sex == "Total") |> pull(n) |> as.numeric()
# The LFS route: age bands available alongside sex (tab2), none alongside education
lfs_age_bands <- inv |> filter(folder == "lfs_annual", has_age,
                             str_count(age_values, "[0-9]{1,2} ?- ?[0-9]{1,2}") >= 1) |> select(id, age_values)

# Access dates from the download log (raw files used by this script; direct reads listed)
src_dates <- accessed_from_log(extra = c("ask_pxweb_metadata_e3.json",
                                             "lfs_docs/ask_085719f6-0ef0-4365-afa7-9a02c8d10cf5.pdf",
                                             "ask_pxweb_listing_census_labour.json",
                                             "ask_lfs_tab0_population.csv",
                                             "ask_lfs_tab3_employment_by_education_sex.csv"))
write_numbers(list(
  accessed = src_dates$display, accessed_first = src_dates$first, accessed_last = src_dates$last,
  n_tables_scanned = nrow(inv),
  n_scan_errors = sum(!is.na(inv$error)),
  n_by_folder = paste(sprintf("%s %d", names(table(inv$folder)), as.integer(table(inv$folder))), collapse = "; "),
  n_educ_tables = nrow(educ_any),
  educ_tables = paste(sprintf("%s/%s", educ_any$folder, educ_any$id), collapse = "; "),
  n_educ_age_tables = nrow(cross),
  educ_age_tables = if (nrow(cross)) paste(sprintf("%s/%s", cross$folder, cross$id), collapse = "; ") else "none",
  report24_table_titles_n = length(tab_titles),
  report24_educ_age_titles = if (length(educ_age_titles)) paste(educ_age_titles, collapse = " || ") else "none",
  report24_section_pages = paste(sec_pages, collapse = ", "),
  lfs_tables_with_age = paste(sprintf("%s (%s)", lfs_age_bands$id, lfs_age_bands$age_values), collapse = "; "),
  lc07_age_bands = paste(unique(ek$age), collapse = ", "),
  lc07_male_1564 = t7$n[t7$sex == "Male"], lc07_female_1564 = t7$n[t7$sex == "Female"],
  lc06_male_1564 = t6$n[t6$sex == "Male"], lc06_female_1564 = t6$n[t6$sex == "Female"],
  lc07_labels_match_lc06 = lc07_labels_match_lc06,
  lc07_matches_lc06_swapped = lc07_matches_lc06_swapped,
  lc06_men_more = lc06_men_more, lc07_men_more = lc07_men_more,
  lc07_n_impossible_cells = nrow(lc07_impossible),
  lc07_impossible_cells = paste(sprintf("%s %s: employed %s > population %s", lc07_impossible$cat, lc07_impossible$sex,
                                        format(lc07_impossible$employed, big.mark = ","),
                                        format(lc07_impossible$population, big.mark = ",")), collapse = "; "),
  lc07_updated = upd("lc07ensus.px"), lc06_updated = upd("lc06ensus.px"),
  lc06_primary_includes_lower_secondary = lc06_primary_includes_lower_secondary,
  lc06_age_bands = inv$age_values[inv$id == "lc06ensus.px"],
  edu1_age_bands = inv$age_values[inv$id == "tabcensusedu1.px"],
  lc07_educ_n = length(unique(emp$educ)), edu1_educ_n = length(unique(pop$educ)),
  lc07_has_other = "Other" %in% emp$educ, edu1_has_other = "Other" %in% pop$educ,
  census_employed_1564 = kos_15_64,
  lfs_employed_1564 = round(lfs_t3 * 1000),
  census_vs_lfs_employed_pct = round(100 * (kos_15_64 / (lfs_t3 * 1000) - 1), 1),
  census_pop_1564 = pop_1564_census,
  lfs_pop_1564 = round(lfs_tab0 * 1000),
  census_vs_lfs_pop_pct = round(100 * (pop_1564_census / (lfs_tab0 * 1000) - 1), 1),
  north_employed_1564 = sum(north_emp),
  north_employed_by_muni = paste(sprintf("%s %s", mun_sum$muni[mun_sum$muni %in% north_lab],
                                         format(north_emp, big.mark = ",")), collapse = "; "),
  tiny_threshold = TINY,
  n_pooled_cells_under_tiny = sum(cells$employed[cells$cat != "unassigned"] < TINY |
                                    cells$population[cells$cat != "unassigned"] < TINY),
  n_pooled_cells_zero = sum(cells$employed == 0 | cells$population == 0),
  pooled_cells = paste(sprintf("%s %s: employed %s, population %s", cells$cat, cells$sex,
                               format(cells$employed, big.mark = ","), format(cells$population, big.mark = ",")),
                       collapse = "; "),
  smallest_band_cells = paste(sprintf("%s %s %s %s", band$cat[1:4], band$sex[1:4], band$age[1:4],
                                      format(band$employed[1:4], big.mark = ",")), collapse = "; "),
  n_band_cells = nrow(band), n_band_cells_under_tiny = sum(band$employed < TINY),
  n_band_cells_zero = sum(band$employed == 0)
), "e3")

# --- figures.json (check_e3_* keys): the numbers the README quotes from this step --
chk <- fromJSON(file.path(CHECK_DIR, "e3_numbers.json"))
keep <- c("accessed_first", "accessed_last", "n_tables_scanned", "n_educ_age_tables", "educ_age_tables",
          "lc07_male_1564", "lc07_female_1564", "lc06_male_1564", "lc06_female_1564",
          "lc07_labels_match_lc06", "lc07_matches_lc06_swapped", "lc07_n_impossible_cells",
          "lc07_impossible_cells", "lc07_updated", "lc06_updated",
          "lc06_primary_includes_lower_secondary", "census_employed_1564", "lfs_employed_1564")
stopifnot(all(keep %in% names(chk)))
fj_merge(setNames(chk[keep], paste0("check_e3_", keep)))
