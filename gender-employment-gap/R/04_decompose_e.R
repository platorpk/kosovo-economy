# ==============================================================================
# 04_decompose_e.R
# Within/composition split of the aggregate employment-rate
# gap (men minus women, ages 15-64, Kosova, 2024) across the three pooled
# education categories. Reported in the README; not shown in the figure.
#
# Input: data/processed/e3_pooled_2024.csv (03_build_pooled_e.R). No download.
#
# With s = each sex's share of its working-age population per category and
# r = the pooled employment rate, the aggregate gap
#     G = sum_k s_m,k r_m,k - sum_k s_f,k r_f,k
# splits into a within-category part and a composition part. The split depends
# on which shares and rates serve as reference — a judgement, not a measurement
# — so all three standard weightings are computed and reported as a range:
#   (i)   men's shares:   within = sum s_m (r_m - r_f);       comp = sum (s_m - s_f) r_f
#   (ii)  women's shares: within = sum s_f (r_m - r_f);       comp = sum (s_m - s_f) r_m
#   (iii) average:        within = sum (s_m+s_f)/2 (r_m-r_f); comp = sum (s_m - s_f)(r_m+r_f)/2
# Each must add up to G exactly (hard identity).
#
# G here is computed from the pooled derived values, so it equals the gap
# recomputed in 03 (a check), not ASK's published Total-row gap (the headline).
#
# Writes: data/processed/e3_decomposition_2024.csv, figures.json (decomp keys)
# Run from the piece root:  Rscript R/04_decompose_e.R
# ==============================================================================
source("R/00_functions.R")

p <- read_csv(file.path(PROC_DIR, "e3_pooled_2024.csv"), show_col_types = FALSE) |>
  filter(pooled != "All, 15-64")
stopifnot(nrow(p) == 3, !anyNA(p[, c("rate_Male", "rate_Female", "share_Male", "share_Female")]))
stopifnot(abs(sum(p$share_Male) - 1) < 1e-12, abs(sum(p$share_Female) - 1) < 1e-12)

sm <- p$share_Male; sf <- p$share_Female; rm <- p$rate_Male; rf <- p$rate_Female
G  <- sum(sm * rm) - sum(sf * rf)

dec <- tibble(
  weighting   = c("men's shares as reference", "women's shares as reference", "average of the two"),
  within_pp   = c(sum(sm * (rm - rf)), sum(sf * (rm - rf)), sum((sm + sf) / 2 * (rm - rf))),
  composition_pp = c(sum((sm - sf) * rf), sum((sm - sf) * rm), sum((sm - sf) * (rm + rf) / 2))
) |> mutate(total_pp = within_pp + composition_pp,
            within_share = within_pp / G)
print(dec, width = 200)
stopifnot(all(abs(dec$total_pp - G) < 1e-9))                     # identity, each weighting

# G must equal the pooled recomputation stored by 03
fj_path <- file.path(PROC_DIR, "figures.json")
fj <- fromJSON(fj_path)
stopifnot(abs(round(G, 2) - fj$gap_recomputed_pp) < 0.006)

# Per-category contributions to the within part (average weighting), for the note
contrib <- p |> transmute(pooled, weight_avg = (share_Male + share_Female) / 2,
                          gap_pp = rate_Male - rate_Female,
                          within_contrib_pp = weight_avg * gap_pp)
stopifnot(abs(sum(contrib$within_contrib_pp) - dec$within_pp[3]) < 1e-9)

write_csv(dec |> mutate(G_pp = G), file.path(PROC_DIR, "e3_decomposition_2024.csv"))
write_csv(contrib, file.path(PROC_DIR, "e3_within_contributions_2024.csv"))

fj$decomp_G_pp <- round(G, 2)
fj$decomp_within_min_pp <- round(min(dec$within_pp), 1)
fj$decomp_within_max_pp <- round(max(dec$within_pp), 1)
fj$decomp_comp_min_pp   <- round(min(dec$composition_pp), 1)
fj$decomp_comp_max_pp   <- round(max(dec$composition_pp), 1)
# Each weighting, at 4 dp, for the README table and the composition-share range
# (08 computes composition / (within + composition) from these rows).
fj$decomp_lfs <- dec |>
  transmute(weighting,
            composition_valued_at = c("women's rates", "men's rates", "the average of the two")[
              match(weighting, c("men's shares as reference", "women's shares as reference",
                                 "average of the two"))],
            within_pp = round(within_pp, 4), composition_pp = round(composition_pp, 4))
stopifnot(!anyNA(fj$decomp_lfs$composition_valued_at), nrow(fj$decomp_lfs) == 3)

# Same split on ASK's five unpooled categories (sensitivity to the pooling), from the
# 2024 rows written by 01_e (population derived the same way, employment / rate).
five <- read_csv(file.path(PROC_DIR, "e_lfs_education_sex.csv"), show_col_types = FALSE) |>
  filter(year == fj$year, education != "Total", sex %in% c("Male", "Female")) |>
  group_by(sex) |> mutate(share = pop_k / sum(pop_k), rate = 100 * emp_k / pop_k) |> ungroup() |>
  select(education, sex, share, rate) |>
  pivot_wider(names_from = sex, values_from = c(share, rate))
stopifnot(nrow(five) == 5, !anyNA(five))
s5m <- five$share_Male; s5f <- five$share_Female; r5m <- five$rate_Male; r5f <- five$rate_Female
G5 <- sum(s5m * r5m) - sum(s5f * r5f)
dec5 <- tibble(weighting = dec$weighting,
               within_pp = c(sum(s5m * (r5m - r5f)), sum(s5f * (r5m - r5f)), sum((s5m + s5f) / 2 * (r5m - r5f))),
               composition_pp = c(sum((s5m - s5f) * r5f), sum((s5m - s5f) * r5m), sum((s5m - s5f) * (r5m + r5f) / 2)))
stopifnot(all(abs(dec5$within_pp + dec5$composition_pp - G5) < 1e-9),   # identity, each weighting
          abs(G5 - G) < 0.2)                                              # same data, different pooling
print(dec5 |> mutate(share = composition_pp / G5))
fj$decomp_lfs_five <- dec5 |> transmute(weighting, within_pp = round(within_pp, 4),
                                        composition_pp = round(composition_pp, 4))

# Participation and unemployment, all education levels (tab3 + tab20 via 01_e), for the
# limitation that the employment rate combines the two.
tot <- read_csv(file.path(PROC_DIR, "e_lfs_education_sex.csv"), show_col_types = FALSE) |>
  filter(year == fj$year, education == "Total", sex %in% c("Male", "Female"))
stopifnot(nrow(tot) == 2, all(tot$act_rate > tot$emp_rate), all(tot$act_rate < 100))
fj$lfs_activity_rate_women <- round(tot$act_rate[tot$sex == "Female"], 4)
fj$lfs_activity_rate_men   <- round(tot$act_rate[tot$sex == "Male"], 4)
fj$lfs_unemployment_rate_women <- tot$unemp_rate[tot$sex == "Female"]
fj$lfs_unemployment_rate_men   <- tot$unemp_rate[tot$sex == "Male"]
writeLines(enc2utf8(toJSON(fj, auto_unbox = TRUE, pretty = TRUE, digits = NA)), fj_path,
           useBytes = TRUE)

cat(sprintf("\nG (pooled, derived) = %.2f pp\n", G))
cat(sprintf("Within-category part: %.1f to %.1f pp | composition part: %.1f to %.1f pp (three weightings)\n",
            min(dec$within_pp), max(dec$within_pp), min(dec$composition_pp), max(dec$composition_pp)))
