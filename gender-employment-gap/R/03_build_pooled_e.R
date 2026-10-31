# ==============================================================================
# 03_build_pooled_e.R
# Employment rate by sex, ages
# 15-64, Kosova, 2024 only, in three pooled education categories.
#
# Source: ASK PxWeb, Labour market > Anketa e Fuqisë Punëtore > Annual labour
#   market > tab3.px (employment '000s and employment-to-population ratio, by
#   education and sex, 15-64) and tab0.px (population by sex and age group).
#   Read from the raw files cached by 01_e / 01_e2; nothing is downloaded.
#
# Pooling (author's choice):
#   "No formal education or primary" = No formal education + Primary
#   "Upper secondary"                = Secondary vocational + Secondary gymnasium
#   "Tertiary"                       = Tertiary
#   The first label is ASK's own wording. ASK publishes no ISCED mapping for its
#   "Primary" (Fillor) category.
#
# Method:
#   - Population per sex x category is DERIVED: employment / (rate / 100).
#   - Pooled rate = summed employed / summed derived population.
#   - Share of each sex's working-age population in a category = category
#     population / sum over the three categories (normalised within sex).
#   - The headline overall gap is ASK's published Total row (author's choice);
#     the gap recomputed from the pooled sums is kept as a check only.
#
# Rounding: ASK publishes rates to 1 decimal, so each derived population is
#   known only within employed / (rate +/- 0.05). Guards on population use that
#   interval rather than exact equality.
#
# Writes: data/processed/e3_pooled_2024.csv, data/processed/figures.json (E keys)
# Run from the piece root:  Rscript R/03_build_pooled_e.R
# ==============================================================================
source("R/00_functions.R")

YEAR <- 2024L
num  <- function(x) suppressWarnings(as.numeric(x))

pool_map <- c("No formal education"            = "No formal education or primary",
              "Primary"                        = "No formal education or primary",
              "Secondary education, vocational" = "Upper secondary",
              "Secondary education, gymnasium"  = "Upper secondary",
              "Tertiary"                       = "Tertiary")
pool_levels <- c("No formal education or primary", "Upper secondary", "Tertiary")

# --- 1. Read cached raw ---------------------------------------------------------
t3 <- read_csv(file.path(RAW_DIR, "ask_lfs_tab3_employment_by_education_sex.csv"),
               show_col_types = FALSE, name_repair = "minimal") |>
  setNames(c("variable", "education", "year", "sex", "value")) |>
  mutate(value = num(value), year = as.integer(year)) |>
  filter(year == YEAR) |>
  mutate(variable = recode(variable, "Employment ('000s)" = "emp_k",
                           "Employment-to-population ratio (%)" = "rate")) |>
  pivot_wider(names_from = variable, values_from = value)
verify_block(t3, "tab3, 2024")
stopifnot(nrow(t3) == 6 * 3, setequal(unique(t3$education), c(names(pool_map), "Total")),
          setequal(unique(t3$sex), c("Male", "Female", "Total")), !anyNA(t3))

t0 <- read_csv(file.path(RAW_DIR, "ask_lfs_tab0_population.csv"),
               show_col_types = FALSE, name_repair = "minimal") |>
  setNames(c("variable", "age", "year", "sex", "value")) |>
  mutate(value = num(value), year = as.integer(year)) |>
  filter(year == YEAR, variable == "Population ('000s)", age == "15-64") |>
  select(sex, pop_tab0_k = value)
stopifnot(nrow(t0) == 3)

# --- 2. Derive and pool (men and women; Total row kept separately) -------------
cells <- t3 |> filter(education != "Total", sex != "Total") |>
  mutate(pop_k    = emp_k / (rate / 100),
         pop_lo_k = emp_k / ((rate + 0.05) / 100),        # rounding interval
         pop_hi_k = emp_k / ((rate - 0.05) / 100),
         pooled   = pool_map[education])
stopifnot(nrow(cells) == 5 * 2, all(cells$rate > 0.05))

pooled <- cells |>
  group_by(pooled, sex) |>
  summarise(emp_k = sum(emp_k), pop_k = sum(pop_k), pop_lo_k = sum(pop_lo_k),
            pop_hi_k = sum(pop_hi_k), n_ask_categories = n(), .groups = "drop") |>
  mutate(rate = 100 * emp_k / pop_k) |>
  group_by(sex) |> mutate(share = pop_k / sum(pop_k)) |> ungroup() |>
  mutate(pooled = factor(pooled, pool_levels)) |> arrange(pooled, sex)
stopifnot(nrow(pooled) == 3 * 2)
stopifnot(identical(pooled$n_ask_categories[pooled$pooled == "No formal education or primary"], c(2L, 2L)),
          identical(pooled$n_ask_categories[pooled$pooled == "Upper secondary"], c(2L, 2L)))

total <- t3 |> filter(education == "Total")
tot <- function(s, v) total[[v]][total$sex == s]

# --- 3. Guards against ASK's Total row ---------------------------------------------
# (a) Employment: pooled sums reproduce the Total row (published to 0.001 thousand).
emp_chk <- pooled |> group_by(sex) |> summarise(emp_k = sum(emp_k), .groups = "drop") |>
  mutate(ask = map2_dbl(sex, "emp_k", tot), d = emp_k - ask)
print(emp_chk)
stopifnot(all(abs(emp_chk$d) < 0.002))
stopifnot(abs(sum(emp_chk$emp_k) - tot("Total", "emp_k")) < 0.003)

# (b) Shares sum to 1 within each sex.
share_chk <- pooled |> group_by(sex) |> summarise(s = sum(share), .groups = "drop")
stopifnot(all(abs(share_chk$s - 1) < 1e-12))

# (c) Population: the summed rounding interval contains both ASK's published
#     15-64 population (tab0) and the population implied by the Total row.
pop_chk <- pooled |> group_by(sex) |>
  summarise(pop_k = sum(pop_k), lo = sum(pop_lo_k), hi = sum(pop_hi_k), .groups = "drop") |>
  left_join(t0, by = "sex") |>
  mutate(pop_total_row_k = map_dbl(sex, ~ tot(.x, "emp_k") / (tot(.x, "rate") / 100)),
         tab0_in  = pop_tab0_k >= lo & pop_tab0_k <= hi,
         trow_in  = pop_total_row_k >= lo & pop_total_row_k <= hi,
         pct_vs_tab0 = 100 * (pop_k / pop_tab0_k - 1))
print(pop_chk)
stopifnot(all(pop_chk$tab0_in), all(pop_chk$trow_in))

# (d) Overall rate recomputed from the pooled sums vs ASK's published Total rate,
#     within the bound implied by rounding: the interval [emp/hi, emp/lo] must
#     contain the published rate +/- 0.05 (i.e. the two intervals overlap).
rate_chk <- pop_chk |>
  mutate(emp_k = map_dbl(sex, ~ tot(.x, "emp_k")),
         rate_recomp = 100 * emp_k / pop_k,
         rate_lo = 100 * emp_k / hi, rate_hi = 100 * emp_k / lo,
         rate_ask = map_dbl(sex, ~ tot(.x, "rate")),
         d = rate_recomp - rate_ask,
         consistent = rate_lo <= rate_ask + 0.05 & rate_hi >= rate_ask - 0.05)
print(rate_chk |> select(sex, rate_recomp, rate_lo, rate_hi, rate_ask, d, consistent))
stopifnot(all(rate_chk$consistent))

# --- 4. Gaps ------------------------------------------------------------------------
wide <- pooled |>
  select(pooled, sex, emp_k, pop_k, rate, share) |>
  pivot_wider(names_from = sex, values_from = c(emp_k, pop_k, rate, share)) |>
  mutate(gap_pp = rate_Male - rate_Female)
stopifnot(nrow(wide) == 3)

gap_headline <- tot("Male", "rate") - tot("Female", "rate")          # ASK Total row
gap_recomp   <- rate_chk$rate_recomp[rate_chk$sex == "Male"] -
                rate_chk$rate_recomp[rate_chk$sex == "Female"]
# Published reference point: the 2024 LFS report prints 55.9 and 21.2 (asserted
# in 01_e2 against the PDF); the headline gap must equal their difference.
stopifnot(abs(gap_headline - (55.9 - 21.2)) < 1e-9)

all_row <- tibble(pooled = "All, 15-64",
                  emp_k_Female = tot("Female", "emp_k"), emp_k_Male = tot("Male", "emp_k"),
                  pop_k_Female = NA_real_, pop_k_Male = NA_real_,
                  rate_Female = tot("Female", "rate"), rate_Male = tot("Male", "rate"),
                  share_Female = NA_real_, share_Male = NA_real_,
                  gap_pp = gap_headline, source = "ASK Total row (published)")
out <- bind_rows(wide |> mutate(pooled = as.character(pooled),
                                source = "pooled from ASK categories (derived population)"),
                 all_row)
write_csv(out, file.path(PROC_DIR, "e3_pooled_2024.csv"))
print(out, width = 200)

# --- 5. figures.json (E keys) ---------------------------------------------------------
fj_path <- file.path(PROC_DIR, "figures.json")
fj <- if (file.exists(fj_path)) fromJSON(fj_path) else list()
r1 <- function(x) round(x, 1)
row_of <- function(lab) out[out$pooled == lab, ]
cat_key <- c("No formal education or primary" = "low", "Upper secondary" = "upper_sec",
             "Tertiary" = "tertiary", "All, 15-64" = "all")
for (lab in names(cat_key)) {
  r <- row_of(lab); k <- cat_key[[lab]]
  fj[[paste0(k, "_rate_women")]] <- r1(r$rate_Female)
  fj[[paste0(k, "_rate_men")]]   <- r1(r$rate_Male)
  fj[[paste0(k, "_gap_pp")]]     <- r1(r$gap_pp)
  if (k != "all") {
    fj[[paste0(k, "_share_women")]] <- r1(100 * r$share_Female)
    fj[[paste0(k, "_share_men")]]   <- r1(100 * r$share_Male)
  }
}
fj$year <- YEAR
fj$gap_headline_pp <- r1(gap_headline)
fj$gap_recomputed_pp <- round(gap_recomp, 2)
fj$gap_recomputed_minus_headline_pp <- round(gap_recomp - gap_headline, 2)
fj$pop_pct_vs_tab0_women <- round(pop_chk$pct_vs_tab0[pop_chk$sex == "Female"], 2)
fj$pop_pct_vs_tab0_men   <- round(pop_chk$pct_vs_tab0[pop_chk$sex == "Male"], 2)
writeLines(enc2utf8(toJSON(fj, auto_unbox = TRUE, pretty = TRUE, digits = NA)), fj_path,
           useBytes = TRUE)
cat("wrote", fj_path, "\n")

cat(sprintf("\nHeadline gap (ASK Total row): %.1f pp | recomputed from pooled sums: %.2f pp\n",
            gap_headline, gap_recomp))
for (i in seq_len(nrow(wide)))
  cat(sprintf("%-32s women %5.1f%%  men %5.1f%%  gap %5.1f pp | share women %4.1f%%  men %4.1f%%\n",
              wide$pooled[i], wide$rate_Female[i], wide$rate_Male[i], wide$gap_pp[i],
              100 * wide$share_Female[i], 100 * wide$share_Male[i]))
