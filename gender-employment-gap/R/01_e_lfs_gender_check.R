# ==============================================================================
# 01_e_lfs_gender_check.R
# Kosova: gender gap in employment, by level of education.
# Verification step 1, no estimation: which breakdowns ASK publishes, whether the aggregate
# gap and the within-education gaps can be computed from published tables,
# cell sizes and published reliability. No regression, no correlation
# coefficient, no standardised ("adjusted") gap here; the split is in 04.
#
# Sources: ASK PxWeb, Labour market > Anketa e Fuqisë Punëtore (Labour Force
#   Survey) > Annual labour market:
#   tab3.px  "Employment and employment-to-population ratio; employment rate, by
#            education attainment and sex, age group 15-64, 2012 - 2024"
#   tab20.px "Unemployed and unemployment rate by educational attainment by sex,
#            age group 15 - 64, 2012 - 2024"
#   tab1b.px "Main labor market indicators (%), 2012 - 2024"
#   tab29.px "Annual accuracy of LFS-based estimates at country level in
#            percentage (%), age group 15-64, 2012 - 2024"
#
# Concept notes:
#   - Population by education x sex is NOT published in these tables; it is
#     derived as employment / employment-to-population ratio. Rounding in the
#     published ratio and in employment ('000s) propagates into it.
#   - tab29 gives sampling accuracy for the national headline rates only; no
#     cell-level standard errors or reliability flags are published for the
#     education x sex cells. Year-to-year movement of each cell is reported as
#     a rough stability signal, not as a standard error.
#
# Writes: data/raw/ (ASK CSVs), data/processed/e_lfs_education_sex.csv,
#   checks/e_*.png|csv|json (not published), figures.json (check_e_* keys)
# Run from the piece root:  Rscript R/01_e_lfs_gender_check.R
# ==============================================================================
source("R/00_functions.R")

node <- paste0(ASK_BASE, "/Labour%20market/Anketa%20e%20Fuqis%C3%AB%20Pun%C3%ABtore/",
               "Annual%20labour%20market")
t3  <- ask_pull_cached(paste0(node, "/tab3.px"),
                       list(Variabla = "*", `Niveli i arsimit` = "*", Viti = "*", Gjinia = "*"),
                       "ask_lfs_tab3_employment_by_education_sex.csv")
t20 <- ask_pull_cached(paste0(node, "/tab20.px"),
                       list(Variabla = "*", `Kosovë` = "*", Viti = "*", Gjinia = "*"),
                       "ask_lfs_tab20_unemployment_by_education_sex.csv")
t1b <- ask_pull_cached(paste0(node, "/tab1b.px"),
                       list(Variabla = "*", Viti = "*", Gjinia = "*"),
                       "ask_lfs_tab1b_main_indicators.csv")
t29 <- ask_pull_cached(paste0(node, "/tab29.px"),
                       list(`Kosovë` = "*", Viti = "*", Variabla = "*"),
                       "ask_lfs_tab29_accuracy.csv")
for (x in list(t3, t20, t1b, t29)) verify_block(x, "ASK LFS raw")

num <- function(x) suppressWarnings(as.numeric(x))
codes_seen <- function(df) { v <- df[[ncol(df)]]; sort(unique(v[is.na(num(v))])) }
non_numeric <- unique(c(codes_seen(t3), codes_seen(t20), codes_seen(t1b), codes_seen(t29)))
cat("non-numeric cells:", paste(non_numeric, collapse = " | "), "\n")

levels_order <- c("No formal education", "Primary", "Secondary education, vocational",
                  "Secondary education, gymnasium", "Tertiary", "Total")
e3 <- t3 |> setNames(c("variable", "education", "year", "sex", "value")) |>
  mutate(value = num(value), year = as.integer(year),
         variable = recode(variable, "Employment ('000s)" = "emp_k",
                           "Employment-to-population ratio (%)" = "emp_rate")) |>
  pivot_wider(names_from = variable, values_from = value)
u20 <- t20 |> setNames(c("variable", "education", "year", "sex", "value")) |>
  mutate(value = num(value), year = as.integer(year),
         variable = recode(variable, "Unemployment ('000s)" = "unemp_k",
                           "Unemployment rate (%)" = "unemp_rate")) |>
  pivot_wider(names_from = variable, values_from = value)
stopifnot(setequal(unique(e3$education), levels_order), setequal(unique(u20$education), levels_order),
          setequal(unique(e3$sex), c("Male", "Female", "Total")))

lfs <- e3 |> left_join(u20, by = c("education", "year", "sex")) |>
  mutate(pop_k = emp_k / (emp_rate / 100),                       # derived, see header
         act_rate = 100 * (emp_k + unemp_k) / pop_k,
         education = factor(education, levels_order))
stopifnot(nrow(lfs) == 6 * 13 * 3)
write_csv(lfs, file.path(PROC_DIR, "e_lfs_education_sex.csv"))

latest <- max(lfs$year)
L <- lfs |> filter(year == latest)

# --- Identities -------------------------------------------------------------------
# Within one table: employment by level sums to the Total row (hard, rounding tol.)
emp_sum <- lfs |> filter(education != "Total") |> group_by(year, sex) |>
  summarise(s = sum(emp_k), .groups = "drop") |>
  left_join(lfs |> filter(education == "Total") |> select(year, sex, tot = emp_k),
            by = c("year", "sex")) |> mutate(d = s - tot)
print(emp_sum |> arrange(desc(abs(d))) |> head(5))
stopifnot(all(abs(emp_sum$d) < 0.5))         # '000s published to 1 dp; 5 cells rounding
# Male + Female = Total (hard)
mf <- lfs |> select(education, year, sex, emp_k) |>
  pivot_wider(names_from = sex, values_from = emp_k) |> mutate(d = Male + Female - Total)
stopifnot(all(abs(mf$d) < 0.2))
# Across tables: tab3 Total employment rate vs tab1b headline (tolerance, report)
h1b <- t1b |> setNames(c("variable", "year", "sex", "value")) |>
  mutate(value = num(value), year = as.integer(year))
hd <- h1b |> filter(variable == "Employment to population ratio - employment rate (15-64 years old)") |>
  select(year, sex, h = value) |>
  inner_join(lfs |> filter(education == "Total") |> select(year, sex, emp_rate), by = c("year", "sex")) |>
  mutate(d = emp_rate - h)
hd_max <- max(abs(hd$d))
cat("max |tab3 total rate - tab1b headline| =", hd_max, "\n")
if (hd_max > 0.15) print(hd |> filter(abs(d) > 0.15))
# Derived population by level sums to derived total population (tolerance)
pop_sum <- lfs |> filter(education != "Total") |> group_by(year, sex) |>
  summarise(s = sum(pop_k), .groups = "drop") |>
  left_join(lfs |> filter(education == "Total") |> select(year, sex, tot = pop_k), by = c("year", "sex")) |>
  mutate(pct = 100 * (s / tot - 1))
pop_sum_maxpct <- max(abs(pop_sum$pct))

# --- Gaps (descriptive arithmetic only) -------------------------------------------
gaps <- lfs |> select(education, year, sex, emp_rate) |>
  pivot_wider(names_from = sex, values_from = emp_rate) |>
  mutate(gap_pp = Male - Female) |> arrange(year, education)
write_utf8_csv(gaps, "e_gaps_by_year.csv")
comp <- L |> filter(education != "Total", sex != "Total") |>
  group_by(sex) |> mutate(pop_share = 100 * pop_k / sum(pop_k)) |> ungroup()
write_utf8_csv(comp |> select(education, sex, emp_k, emp_rate, pop_k, pop_share), "e_composition_latest.csv")
print(comp |> select(education, sex, emp_k, emp_rate, pop_share))

# Stability: per level, s.d. of the year-to-year change in the gap
stab <- gaps |> group_by(education) |> arrange(year) |>
  summarise(sd_change = sd(diff(gap_pp)), min_gap = min(gap_pp), max_gap = max(gap_pp),
            .groups = "drop")
print(stab); write_utf8_csv(stab, "e_gap_stability.csv")

# Accuracy (national only)
acc <- t29 |> setNames(c("measure", "year", "variable", "value")) |>
  mutate(value = num(value), year = as.integer(year)) |>
  filter(year == latest)
print(acc)
cv_emp <- acc$value[acc$measure == "Variation coefficient (%)" &
                    grepl("^Employment", acc$variable)]

# --- Diagnostics ------------------------------------------------------------------
p1 <- ggplot(L |> filter(sex != "Total"), aes(emp_rate, education, colour = sex)) +
  geom_point(size = 3) + scale_colour_manual(values = c(Male = "#1A4E8A", Female = "#C0552E")) +
  labs(title = paste("Employment-to-population ratio by education and sex,", latest, "(15-64)"),
       x = "%", y = NULL, colour = NULL) + diag_theme
ggsave(file.path(CHECK_DIR, "e_rates_latest.png"), p1, width = 8, height = 4, dpi = 150)
p2 <- ggplot(comp, aes(pop_share, education, fill = sex)) +
  geom_col(position = "dodge") + scale_fill_manual(values = c(Male = "#1A4E8A", Female = "#C0552E")) +
  labs(title = paste("Derived population share by education, within sex,", latest),
       x = "% of the sex's 15-64 population", y = NULL, fill = NULL) + diag_theme
ggsave(file.path(CHECK_DIR, "e_composition_latest.png"), p2, width = 8, height = 4, dpi = 150)
p3 <- ggplot(gaps, aes(year, gap_pp, colour = education)) + geom_point() + geom_path() +
  labs(title = "Male minus female employment rate, percentage points, by education", x = NULL,
       y = "pp", colour = NULL) + diag_theme + theme(legend.position = "bottom")
ggsave(file.path(CHECK_DIR, "e_gaps_over_time.png"), p3, width = 8, height = 5, dpi = 150)
hist_panel(lfs |> filter(education != "Total", sex != "Total"), c("emp_k", "emp_rate", "pop_k"),
           "e_hist_cells.png", "Education x sex cells, all years")

# --- Numbers out ------------------------------------------------------------------
fmt <- function(x, d = 1) sprintf(paste0("%.", d, "f"), x)
g <- function(lv) gaps$gap_pp[gaps$year == latest & gaps$education == lv]
r <- function(lv, s) L$emp_rate[L$education == lv & L$sex == s]
smallest <- comp |> slice_min(emp_k, n = 1)
# Access dates from the download log (raw files used by this script; direct reads listed)
src_dates <- accessed_from_log()
write_numbers(list(
  accessed = src_dates$display, accessed_first = src_dates$first, accessed_last = src_dates$last, latest_year = latest, first_year = min(lfs$year),
  non_numeric_cells = paste(non_numeric, collapse = " | "),
  n_levels = length(levels_order) - 1,
  gap_total = fmt(g("Total")), rate_m_total = fmt(r("Total", "Male")), rate_f_total = fmt(r("Total", "Female")),
  gap_none = fmt(g("No formal education")), gap_primary = fmt(g("Primary")),
  gap_voc = fmt(g("Secondary education, vocational")), gap_gym = fmt(g("Secondary education, gymnasium")),
  gap_tertiary = fmt(g("Tertiary")),
  rate_f_tertiary = fmt(r("Tertiary", "Female")), rate_m_tertiary = fmt(r("Tertiary", "Male")),
  rate_f_primary = fmt(r("Primary", "Female")), rate_m_primary = fmt(r("Primary", "Male")),
  share_f_tertiary = fmt(comp$pop_share[comp$sex == "Female" & comp$education == "Tertiary"]),
  share_m_tertiary = fmt(comp$pop_share[comp$sex == "Male" & comp$education == "Tertiary"]),
  share_f_primary_or_less = fmt(sum(comp$pop_share[comp$sex == "Female" & comp$education %in% c("No formal education", "Primary")])),
  share_m_primary_or_less = fmt(sum(comp$pop_share[comp$sex == "Male" & comp$education %in% c("No formal education", "Primary")])),
  n_levels_gap_below_total = sum(gaps$gap_pp[gaps$year == latest & gaps$education != "Total"] < g("Total")),
  levels_gap_above_total = paste(as.character(gaps$education[gaps$year == latest & gaps$education != "Total" &
                                                               gaps$gap_pp > g("Total")]), collapse = " and "),
  gap_latest_is_max = g("Total") == max(gaps$gap_pp[gaps$education == "Total"]),
  smallest_cell = paste(smallest$education, smallest$sex), smallest_cell_emp_k = fmt(smallest$emp_k),
  n_cells_under_5k = sum(comp$emp_k < 5),
  cells_under_5k = paste(comp$education[comp$emp_k < 5], comp$sex[comp$emp_k < 5], collapse = "; "),
  emp_sum_maxabs = fmt(max(abs(emp_sum$d)), 2), mf_maxabs = fmt(max(abs(mf$d)), 2),
  headline_vs_tab3_maxabs = fmt(hd_max, 2),
  derived_pop_sum_maxpct = fmt(pop_sum_maxpct, 2),
  cv_employment_rate = fmt(cv_emp, 2),
  most_volatile_level = stab$education[which.max(stab$sd_change)],
  most_volatile_sd = fmt(max(stab$sd_change)),
  total_gap_sd_change = fmt(stab$sd_change[stab$education == "Total"]),
  gap_total_min = fmt(stab$min_gap[stab$education == "Total"]),
  gap_total_max = fmt(stab$max_gap[stab$education == "Total"])
), "e")

# --- figures.json (check_e_* keys): the numbers the README quotes from this step ---
chk <- fromJSON(file.path(CHECK_DIR, "e_numbers.json"))
keep <- c("accessed_first", "accessed_last", "first_year", "latest_year", "n_levels",
          "gap_none", "gap_primary", "gap_voc", "gap_gym", "gap_tertiary",
          "cv_employment_rate", "smallest_cell", "smallest_cell_emp_k")
stopifnot(all(keep %in% names(chk)))
fj_merge(setNames(chk[keep], paste0("check_e_", keep)))
