# ==============================================================================
# 04b_census_check_e.R
# Census robustness check: the same three pooled
# education categories as 03, built from the 2024 census, for ages 25-64
# and 15-64, so the source difference (LFS vs census, same age band) and the
# age difference (census 15-64 vs 25-64) can be separated. Tables only.
#
# Sources (ASK PxWeb, cached raw; lc07ensus is NOT used here — its sex labels
# contradict lc06ensus; see 01_e3 and the README limitations):
#   Census population > 4_Labour market > lc06ensus.px  "Employed by gender,
#     education level and age group, 2024" (KOSOVA; bands 15-64, 15-24, 25-54,
#     55-64). 25-64 = 25-54 + 55-64.
#   Census population > 2_Education > tabcensusedu1.px  "Population aged 15 and
#     over by educational attainment, gender and age 2024" (5-year bands).
#   Census population > 1_Demographic_Characteristics > census2024_00.px
#     "Population by age, sex and municipality" (cached by 01_b), compared with
#     tabcensusedu1 at 15-64 for the limitations (section 4b); not used in rates.
#
# Method (approved defaults):
#   - Overall gap = census Total rows (all employed / all population, incl.
#     Other/Unknown); the gap recomputed from the three categories is a check,
#     and the difference is printed.
#   - Other/Unknown is excluded from rates, shares and the split; its size is
#     reported by sex, as a count and as a share of each sex's total.
#   - The north: national figures as published; the four northern
#     municipalities' employed (lc06) are reported, not removed (tabcensusedu1
#     has no municipality breakdown).
#   - Within/composition split under the same three reference weightings as 04.
#
# Guards: every source row assigned to exactly one of {three categories,
#   Other/Unknown, Total}; no row between lower secondary and upper secondary
#   (stop and list if any); categories sum to each table's own Total; lc06 bands
#   add up; employed <= population; shares sum to 1; within + composition = G;
#   3 categories x 2 sexes per version.
#
# Writes: data/processed/e4_census_2024.csv, e4_census_decomposition_2024.csv,
#   e4_census_other_unknown_2024.csv, e4_census_mapping.csv, figures.json
#   (census_* keys), data/raw/ask_census2024_lc06_north.csv
# Run from the piece root:  Rscript R/04b_census_check_e.R
# ==============================================================================
source("R/00_functions.R")

l6 <- read_csv(file.path(RAW_DIR, "ask_census2024_lc06_employed_educ_age_sex_kosova.csv"),
               show_col_types = FALSE, name_repair = "minimal") |>
  setNames(c("muni", "age", "educ", "sex", "n")) |> mutate(n = as.numeric(n))
e1 <- read_csv(file.path(RAW_DIR, "ask_census2024_edu1_population_educ_age_sex.csv"),
               show_col_types = FALSE, name_repair = "minimal") |>
  setNames(c("educ", "sex", "age", "n")) |> mutate(n = as.numeric(n))
stopifnot(all(l6$muni == "KOSOVA"), !anyNA(l6$n), !anyNA(e1$n))
verify_block(l6, "lc06 (cached)"); verify_block(e1, "tabcensusedu1 (cached)")

# --- 1. Mapping, every row exactly once ----------------------------------------------
map_l6 <- tribble(
  ~source_row,                       ~category,
  "Total",                           "Total",
  "No education",                    "No formal education or primary",
  "Primary education",               "No formal education or primary",
  "Secondary education",             "Upper secondary",
  "Higher school",                   "Tertiary",
  "Faculty, Bachelor's degree",      "Tertiary",
  "Postgraduate (Master's degree)",  "Tertiary",
  "Doctorate",                       "Tertiary",
  "Other",                           "Other/Unknown",
  "Unknown",                         "Other/Unknown")
map_e1 <- tribble(
  ~source_row,                                ~category,
  "Kosova",                                   "Total",
  "No formal education",                      "No formal education or primary",
  "No level completed",                       "No formal education or primary",
  "Primary, 4 grades old system",             "No formal education or primary",
  "Primary, 5 grades new system",             "No formal education or primary",
  "Lower secondary, 8 grades old system",     "No formal education or primary",
  "Lower secondary, 9 grades new system",     "No formal education or primary",
  "Higher secondary, 12 grades old system",   "Upper secondary",
  "Higher secondary, 13 grades new system",   "Upper secondary",
  "Higher school",                            "Tertiary",
  "Faculty, Bachelor's",                      "Tertiary",
  "Postgraduate (Master's)",                  "Tertiary",
  "Doctorate/PhD",                            "Tertiary",
  "Unknown",                                  "Other/Unknown")
allowed <- c("No formal education or primary", "Upper secondary", "Tertiary", "Other/Unknown", "Total")
for (m in list(map_l6, map_e1)) stopifnot(!anyDuplicated(m$source_row), all(m$category %in% allowed))
# Every source row appears in the mapping exactly once, and every mapped row exists
stopifnot(setequal(unique(l6$educ), map_l6$source_row), setequal(unique(e1$educ), map_e1$source_row))
# Intermediate levels (between 8/9-grade lower secondary and 12/13-grade upper
# secondary): stop and list if any source row looks like one. None is assigned.
inter_re <- "10 grades|11 grades|10/11|incomplete secondary|short vocational|2-year|two-year|3-year vocational|lower vocational"
inter <- c(grep(inter_re, unique(l6$educ), ignore.case = TRUE, value = TRUE),
           grep(inter_re, unique(e1$educ), ignore.case = TRUE, value = TRUE))
if (length(inter)) stop("Intermediate education rows found (not assigned; decision needed): ",
                        paste(inter, collapse = "; "))
mapping <- bind_rows(map_l6 |> mutate(table = "lc06ensus.px"), map_e1 |> mutate(table = "tabcensusedu1.px")) |>
  select(table, source_row, category)
write_csv(mapping, file.path(PROC_DIR, "e4_census_mapping.csv"))

# --- 2. Within-table identities (hard) --------------------------------------------
id_l6 <- l6 |> left_join(map_l6, by = c("educ" = "source_row")) |> filter(category != "Total") |>
  group_by(age, sex) |> summarise(s = sum(n), .groups = "drop") |>
  left_join(l6 |> filter(educ == "Total") |> select(age, sex, tot = n), by = c("age", "sex"))
stopifnot(all(id_l6$s == id_l6$tot))
id_e1 <- e1 |> left_join(map_e1, by = c("educ" = "source_row")) |> filter(category != "Total") |>
  group_by(age, sex) |> summarise(s = sum(n), .groups = "drop") |>
  left_join(e1 |> filter(educ == "Kosova") |> select(age, sex, tot = n), by = c("age", "sex"))
stopifnot(all(id_e1$s == id_e1$tot))
# lc06 bands: 15-24 + 25-54 + 55-64 = 15-64 for every education x sex
bands <- l6 |> pivot_wider(names_from = age, values_from = n) |>
  mutate(d = `15-24` + `25-54` + `55-64` - `15-64`)
stopifnot(all(bands$d == 0))
# Male + Female = Total in both tables
for (d in list(l6 |> rename(g = age), e1 |> rename(g = age))) {
  mf <- d |> pivot_wider(names_from = sex, values_from = n) |> mutate(dd = Male + Female - Total)
  stopifnot(all(mf$dd == 0))
}

# --- 3. Build both versions --------------------------------------------------------
pop_bands <- list(`15-64` = c("15 - 19", "20 - 24", "25 - 29", "30 - 34", "35 - 39", "40 - 44",
                              "45 - 49", "50 - 54", "55 - 59", "60 - 64"),
                  `25-64` = c("25 - 29", "30 - 34", "35 - 39", "40 - 44", "45 - 49", "50 - 54",
                              "55 - 59", "60 - 64"))
emp_bands <- list(`15-64` = "15-64", `25-64` = c("25-54", "55-64"))
stopifnot(all(unlist(pop_bands) %in% e1$age), all(unlist(emp_bands) %in% l6$age))
cats3 <- c("No formal education or primary", "Upper secondary", "Tertiary")

decompose <- function(sm, sf, rm, rf) {
  G <- sum(sm * rm) - sum(sf * rf)
  tibble(weighting = c("men's shares as reference", "women's shares as reference", "average of the two"),
         within_pp = c(sum(sm * (rm - rf)), sum(sf * (rm - rf)), sum((sm + sf) / 2 * (rm - rf))),
         composition_pp = c(sum((sm - sf) * rf), sum((sm - sf) * rm), sum((sm - sf) * (rm + rf) / 2))) |>
    mutate(total_pp = within_pp + composition_pp, G_pp = G)
}

build <- function(band) {
  emp <- l6 |> filter(age %in% emp_bands[[band]], sex != "Total") |>
    left_join(map_l6, by = c("educ" = "source_row")) |>
    group_by(category, sex) |> summarise(employed = sum(n), .groups = "drop")
  pop <- e1 |> filter(age %in% pop_bands[[band]], sex != "Total") |>
    left_join(map_e1, by = c("educ" = "source_row")) |>
    group_by(category, sex) |> summarise(population = sum(n), .groups = "drop")
  all <- full_join(emp, pop, by = c("category", "sex"))
  stopifnot(nrow(all) == 5 * 2, !anyNA(all))
  # Accounting: three categories + Other/Unknown = Total (exact, both measures)
  acc <- all |> filter(category != "Total") |> group_by(sex) |>
    summarise(e = sum(employed), p = sum(population), .groups = "drop") |>
    left_join(all |> filter(category == "Total") |> select(sex, te = employed, tp = population), by = "sex")
  stopifnot(all(acc$e == acc$te), all(acc$p == acc$tp))
  three <- all |> filter(category %in% cats3) |>
    mutate(rate = 100 * employed / population) |>
    group_by(sex) |> mutate(share = population / sum(population)) |> ungroup()
  stopifnot(nrow(three) == 3 * 2, all(three$employed <= three$population))
  stopifnot(all(abs(tapply(three$share, three$sex, sum) - 1) < 1e-12))
  w <- three |> select(category, sex, employed, population, rate, share) |>
    pivot_wider(names_from = sex, values_from = c(employed, population, rate, share)) |>
    mutate(gap_pp = rate_Male - rate_Female, category = factor(category, cats3)) |> arrange(category)
  tot <- all |> filter(category == "Total")
  rt <- function(s) 100 * tot$employed[tot$sex == s] / tot$population[tot$sex == s]
  gap_total <- rt("Male") - rt("Female")
  r3 <- function(s) 100 * sum(three$employed[three$sex == s]) / sum(three$population[three$sex == s])
  gap_three <- r3("Male") - r3("Female")
  ou <- all |> filter(category == "Other/Unknown") |>
    left_join(tot |> select(sex, te = employed, tp = population), by = "sex") |>
    transmute(band, sex, other_unknown_employed = employed, share_of_employed = employed / te,
              other_unknown_population = population, share_of_population = population / tp)
  dec <- decompose(w$share_Male, w$share_Female, w$rate_Male, w$rate_Female)
  stopifnot(all(abs(dec$total_pp - dec$G_pp) < 1e-9), abs(dec$G_pp[1] - gap_three) < 1e-9)
  list(table = bind_rows(w |> mutate(category = as.character(category)),
                         tibble(category = "All (census Total rows)",
                                employed_Female = tot$employed[tot$sex == "Female"],
                                employed_Male = tot$employed[tot$sex == "Male"],
                                population_Female = tot$population[tot$sex == "Female"],
                                population_Male = tot$population[tot$sex == "Male"],
                                rate_Female = rt("Female"), rate_Male = rt("Male"),
                                gap_pp = gap_total)) |> mutate(band = band),
       gap_total = gap_total, gap_three = gap_three, ou = ou, dec = dec |> mutate(band = band))
}
res <- map(c(`15-64` = "15-64", `25-64` = "25-64"), build)

tab <- bind_rows(map(res, "table"))
dec <- bind_rows(map(res, "dec"))
ou  <- bind_rows(map(res, "ou"))
stopifnot(nrow(tab) == 2 * 4, nrow(dec) == 2 * 3, nrow(ou) == 2 * 2)
write_csv(tab, file.path(PROC_DIR, "e4_census_2024.csv"))
write_csv(dec, file.path(PROC_DIR, "e4_census_decomposition_2024.csv"))
write_csv(ou,  file.path(PROC_DIR, "e4_census_other_unknown_2024.csv"))
print(tab, width = 200); print(dec); print(ou)

# --- 4. The north (lc06, reported only) ----------------------------------------------
node_lab <- paste0(ASK_BASE, "/Census%20population/4_Labour%20market")
north <- ask_pull_cached(paste0(node_lab, "/lc06ensus.px"),
                         list(Komuna = c("12", "28", "29", "38"), Grupmosha = "*",
                              `Niveli me i larte i arsimit` = "0", Gjinia = "*"),
                         "ask_census2024_lc06_north.csv") |>
  setNames(c("muni", "age", "educ", "sex", "n")) |> mutate(n = as.numeric(n))
stopifnot(setequal(unique(north$muni), c("Leposaviq", "Zubin Potok", "Zveqan", "Mitrovica Veriore")))
north_emp <- function(b) sum(north$n[north$age %in% emp_bands[[b]] & north$sex == "Total"])

# --- 4b. Census universes, 15-64 (reported, for the limitations) -------------------------
# tabcensusedu1 (the population denominator above) against the census population
# table census2024_00.px (1_Demographic_Characteristics; cached by 01_b), which is
# also the LFS 2024 weighting base (tab0). Not reconciled: the difference is
# recorded as a limitation.
c00 <- read_csv(file.path(RAW_DIR, "ask_census2024_00_population.csv"),
                show_col_types = FALSE, name_repair = "minimal") |>
  setNames(c("year", "muni", "sex", "age", "n")) |>
  filter(year == 2024, muni == "KOSOVA", sex == "Total", age != "Total") |>
  mutate(a = suppressWarnings(as.integer(age)))
stopifnot(setequal(c00$age[is.na(c00$a)], "85+"), all(0:84 %in% c00$a), !anyNA(c00$n))
pop1564_tab00 <- sum(c00$n[!is.na(c00$a) & c00$a >= 15 & c00$a <= 64])
pop1564_edu1  <- sum(e1$n[e1$educ == "Kosova" & e1$sex == "Total" & e1$age %in% pop_bands[["15-64"]]])
pop1564_gap   <- pop1564_tab00 - pop1564_edu1
lfs_tab0_1564 <- read_csv(file.path(RAW_DIR, "ask_lfs_tab0_population.csv"),
                          show_col_types = FALSE, name_repair = "minimal") |>
  setNames(c("variable", "age", "year", "sex", "value")) |>
  filter(year == 2024, variable == "Population ('000s)", age == "15-64", sex == "Total") |>
  pull(value)
stopifnot(length(lfs_tab0_1564) == 1)
# Cross-file check (separately published ASK tables): tab00 15-64 = LFS tab0 15-64, within 1 person
if (abs(pop1564_tab00 - 1000 * lfs_tab0_1564) > 1) {
  cat("census2024_00 15-64:", pop1564_tab00, " LFS tab0 15-64 (x1000):", 1000 * lfs_tab0_1564, "\n")
  print(read_csv(file.path(RAW_DIR, "_download_log.csv"), show_col_types = FALSE) |>
          filter(file %in% c("ask_census2024_00_population.csv", "ask_lfs_tab0_population.csv")))
  stop("census2024_00 and LFS tab0 disagree on the 15-64 population")
}
stopifnot(pop1564_gap > 0, pop1564_gap < 0.02 * pop1564_tab00,
          pop1564_edu1 + pop1564_gap == pop1564_tab00)
cat(sprintf("Census 15-64: census2024_00 %d | tabcensusedu1 %d | difference %d (%.2f%%)\n",
            pop1564_tab00, pop1564_edu1, pop1564_gap, 100 * pop1564_gap / pop1564_tab00))

# --- 5. figures.json (census_* keys) -------------------------------------------------
fj_path <- file.path(PROC_DIR, "figures.json")
fj <- fromJSON(fj_path)
for (b in names(res)) {
  k <- paste0("census_", gsub("-", "", b))
  fj[[paste0(k, "_gap_total_pp")]] <- round(res[[b]]$gap_total, 2)
  fj[[paste0(k, "_gap_three_pp")]] <- round(res[[b]]$gap_three, 2)
  fj[[paste0(k, "_gap_three_minus_total_pp")]] <- round(res[[b]]$gap_three - res[[b]]$gap_total, 2)
  d <- res[[b]]$dec
  fj[[paste0(k, "_within_min_pp")]] <- round(min(d$within_pp), 1)
  fj[[paste0(k, "_within_max_pp")]] <- round(max(d$within_pp), 1)
  fj[[paste0(k, "_comp_min_pp")]]   <- round(min(d$composition_pp), 1)
  fj[[paste0(k, "_comp_max_pp")]]   <- round(max(d$composition_pp), 1)
  fj[[paste0(k, "_north_employed")]] <- north_emp(b)
}
fj$census_1564_pop_tab00 <- pop1564_tab00
fj$census_1564_pop_edu1  <- pop1564_edu1
fj$census_1564_pop_gap   <- pop1564_gap
# --- 6. Composition share of the gap, all versions x all weightings ------------------
# composition / G, with G the recomputed three-category gap of each version
# (LFS 15-64 from 04; census 15-64 and 25-64 from above). The README says
# "less than a fifth" in every combination, so the maximum is guarded below 0.20.
lfs_dec <- read_csv(file.path(PROC_DIR, "e3_decomposition_2024.csv"), show_col_types = FALSE) |>
  transmute(version = "LFS 15-64", weighting, composition_pp, G_pp)
cshare <- bind_rows(lfs_dec,
                    dec |> transmute(version = paste("Census", band), weighting, composition_pp, G_pp)) |>
  mutate(composition_share = composition_pp / G_pp)
stopifnot(nrow(cshare) == 3 * 3, all(cshare$G_pp > 0), all(cshare$composition_share > 0))
write_csv(cshare, file.path(PROC_DIR, "e4_composition_share_2024.csv"))
composition_share_max <- max(cshare$composition_share)
composition_share_min <- min(cshare$composition_share)
stopifnot(composition_share_max < 0.20)
fj$composition_share_max <- round(composition_share_max, 4)
fj$composition_share_min <- round(composition_share_min, 4)
fj$composition_share_max_at <- with(cshare[which.max(cshare$composition_share), ], paste(version, "/", weighting))
fj$composition_share_min_at <- with(cshare[which.min(cshare$composition_share), ], paste(version, "/", weighting))
print(cshare)
# Tables for the README, at 4 dp (rates and gaps in %, shares as fractions)
fj$census_table <- tab |>
  transmute(band, category, rate_women = round(rate_Female, 4), rate_men = round(rate_Male, 4),
            gap_pp = round(gap_pp, 4), share_women = round(share_Female, 4),
            share_men = round(share_Male, 4))
fj$census_decomp <- dec |>
  transmute(band, weighting, within_pp = round(within_pp, 4), composition_pp = round(composition_pp, 4))
fj$composition_shares <- cshare |>
  transmute(version, weighting, composition_pp = round(composition_pp, 4), G_pp = round(G_pp, 4),
            composition_share = round(composition_share, 6))
fj$census_other_unknown <- ou |>
  transmute(band, sex, employed = other_unknown_employed, share_of_employed = round(share_of_employed, 6),
            population = other_unknown_population, share_of_population = round(share_of_population, 6))
stopifnot(nrow(fj$census_table) == 8, nrow(fj$census_decomp) == 6, nrow(fj$composition_shares) == 9,
          nrow(fj$census_other_unknown) == 4)
writeLines(enc2utf8(toJSON(fj, auto_unbox = TRUE, pretty = TRUE, digits = NA)), fj_path, useBytes = TRUE)
cat(sprintf("\nComposition share of the gap: min %.3f (%s), max %.3f (%s)\n",
            composition_share_min, fj$composition_share_min_at,
            composition_share_max, fj$composition_share_max_at))

for (b in names(res))
  cat(sprintf("\nCensus %s: overall gap (Total rows) %.2f pp | three-category recomputation %.2f pp | diff %+.2f\n",
              b, res[[b]]$gap_total, res[[b]]$gap_three, res[[b]]$gap_three - res[[b]]$gap_total))
