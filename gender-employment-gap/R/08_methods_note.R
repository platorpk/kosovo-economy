# ==============================================================================
# 08_methods_note.R
# Writes README.md (the methods note) and output/catalogue_row.md (the row for
# the repository's root catalogue). Every number is read from
# data/processed/figures.json and inserted with sprintf(); none is typed here.
# Ranges and shares quoted in prose are computed below from figures.json values
# and guarded before use.
#
# Wording rules: "Kosova" in prose; source-controlled strings kept verbatim
# (the licensor's required attribution "Kosovo Agency of Statistics (KAS)", ASK
# table labels); no causal language. check_wording() runs on everything written,
# after the permitted source strings are set aside.
#
# Input:  data/processed/figures.json (written by 01_e, 01_e2, 01_e3, 03, 04, 04b)
# Writes: README.md, output/catalogue_row.md
# Run from the piece root, after 05:  Rscript R/08_methods_note.R
# ==============================================================================
source("R/00_functions.R")

f <- fromJSON(FJ_PATH)
p1 <- function(x) sprintf("%.1f", x)
num_word <- function(n) { w <- c("one", "two", "three", "four", "five", "six", "seven", "eight", "nine"); stopifnot(n %in% seq_along(w)); w[n] }
p0 <- function(x) sprintf("%.0f", x)
big <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
md_table <- function(df) {
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(as.data.frame(df), 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}

# The licence page was re-read on this date (ASK, "Copyright notice and free data
# reuse"); a recorded fact, not a computed figure.
ASK_TERMS_URL       <- "https://ask.rks-gov.net/AboutUs/author-rights"
ASK_TERMS_RETRIEVED <- "2026-10-31"

# --- 1. Values and guards ----------------------------------------------------------
yr <- f$year
dl <- f$decomp_lfs
stopifnot(nrow(dl) == 3, all(abs(dl$within_pp + dl$composition_pp - f$decomp_G_pp) < 0.01))
G_lfs   <- dl$within_pp[1] + dl$composition_pp[1]           # recomputed three-category gap
lfs_sh  <- 100 * dl$composition_pp / (dl$within_pp + dl$composition_pp)
comp_lo <- min(dl$composition_pp); comp_hi <- max(dl$composition_pp)
sh_lo   <- min(lfs_sh);            sh_hi   <- max(lfs_sh)

cs <- f$composition_shares
n_combos <- nrow(cs)
stopifnot(n_combos == 9, nrow(dl) * length(unique(cs$version)) == n_combos)
all_lo <- 100 * min(cs$composition_share); all_hi <- 100 * max(cs$composition_share)
stopifnot(all_hi < 20, abs(all_hi / 100 - f$composition_share_max) < 5e-5,
          abs(all_lo / 100 - f$composition_share_min) < 5e-5)
# the LFS rows of the nine must be the three LFS weightings
lfs_rows <- cs[grepl("^LFS", cs$version), ]
stopifnot(nrow(lfs_rows) == 3, abs(min(100 * lfs_rows$composition_share) - sh_lo) < 1e-3,
          abs(max(100 * lfs_rows$composition_share) - sh_hi) < 1e-3)
lfs_band <- sub("^LFS ", "", unique(lfs_rows$version))
cen_bands <- unique(f$census_table$band)
stopifnot(length(lfs_band) == 1, length(cen_bands) == 2)
dash <- function(b) gsub("-", "–", b)

gaps_within <- c(f$low_gap_pp, f$upper_sec_gap_pp, f$tertiary_gap_pp)
stopifnot(f$tertiary_gap_pp == min(gaps_within), f$upper_sec_gap_pp == max(gaps_within),
          f$upper_sec_gap_pp > f$all_gap_pp)

acc_first <- min(as.Date(c(f$check_e_accessed_first, f$check_e2_accessed_first, f$check_e3_accessed_first)))
acc_last  <- max(as.Date(c(f$check_e_accessed_last,  f$check_e2_accessed_last,  f$check_e3_accessed_last)))
accessed  <- if (acc_first == acc_last) format(acc_first) else paste(format(acc_first), "to", format(acc_last))

# lc07 contradiction: the impossible cell, parsed from the check string
imp <- regmatches(f$check_e3_lc07_impossible_cells,
                  gregexpr("[0-9]{1,3}(,[0-9]{3})+", f$check_e3_lc07_impossible_cells))[[1]]
stopifnot(f$check_e3_lc07_matches_lc06_swapped, !f$check_e3_lc07_labels_match_lc06,
          f$check_e3_lc07_n_impossible_cells == 1, length(imp) == 2,
          grepl("^upper Female", f$check_e3_lc07_impossible_cells))

ct <- f$census_table
cen_all <- function(b, col) ct[[col]][ct$band == b & grepl("^All", ct$category)]
ou <- f$census_other_unknown

# Headline shares in whole numbers: they must round the same on the rebuilt gap
# (G_lfs) and on ASK's published gap, so the base choice cannot change them.
sh_pub <- 100 * dl$composition_pp / f$all_gap_pp
stopifnot(p0(min(sh_pub)) == p0(sh_lo), p0(max(sh_pub)) == p0(sh_hi))

# Census shares, by band and overall
cen_cs <- cs[grepl("^Census", cs$version), ]
cen_sh <- function(b) 100 * cen_cs$composition_share[cen_cs$version == paste("Census", b)]
c1 <- cen_sh(cen_bands[1]); c2 <- cen_sh(cen_bands[2])
stopifnot(length(c1) == 3, length(c2) == 3, nrow(cen_cs) == 6)
cen_lo <- min(c(c1, c2)); cen_hi <- max(c(c1, c2))

# Five unpooled categories (04)
d5  <- f$decomp_lfs_five
G5  <- d5$within_pp[1] + d5$composition_pp[1]
sh5 <- 100 * d5$composition_pp / (d5$within_pp + d5$composition_pp)
stopifnot(nrow(d5) == 3, max(sh5) < 20)

# Which reference gives the larger composition part, by version (the interaction's sign)
ord <- vapply(unique(cs$version), function(v) {
  r <- cs[cs$version == v, ]
  r$composition_pp[r$weighting == "men's shares as reference"] -
    r$composition_pp[r$weighting == "women's shares as reference"]
}, numeric(1))
flip_v <- names(ord)[ord > 0]
stopifnot(length(flip_v) == 1, sum(ord < 0) == length(ord) - 1)
flip_r <- cs[cs$version == flip_v, ]

# LFS against census education mix, ages 15-64 (percentage points, by sex and group)
ct1 <- ct[ct$band == lfs_band & !grepl("^All", ct$category), ]
stopifnot(identical(ct1$category, c("No formal education or primary", "Upper secondary", "Tertiary")))
mix <- tibble(group = ct1$category,
              lfs_w = c(f$low_share_women, f$upper_sec_share_women, f$tertiary_share_women),
              cen_w = 100 * ct1$share_women,
              lfs_m = c(f$low_share_men, f$upper_sec_share_men, f$tertiary_share_men),
              cen_m = 100 * ct1$share_men)
mix_max <- max(abs(c(mix$lfs_w - mix$cen_w, mix$lfs_m - mix$cen_m)))
stopifnot(abs(abs(mix$lfs_w[2] - mix$cen_w[2]) - mix_max) < 1e-9 ||        # the example quoted is the largest
          abs(abs(mix$lfs_m[2] - mix$cen_m[2]) - mix_max) < 1e-9)
stopifnot(min(c2) > mean(lfs_sh), max(c2) >= max(lfs_sh) - 1)              # "sits at the top of the LFS range"

# Census universe: relative size of the gap between the two census populations
univ_pct <- 100 * f$census_1564_pop_gap / f$census_1564_pop_edu1

# Tables crossing education, age and sex: census only?
ea <- strsplit(f$check_e3_educ_age_tables, "; ", fixed = TRUE)[[1]]
stopifnot(length(ea) == f$check_e3_n_educ_age_tables, !any(startsWith(ea, "lfs_")))

# Participation and unemployment (04)
stopifnot(f$lfs_activity_rate_women < f$lfs_activity_rate_men,
          f$lfs_unemployment_rate_women > f$lfs_unemployment_rate_men)

# --- 2. Text pieces ------------------------------------------------------------------
finding <- sprintf(paste0(
  "**In %d, %s%% of women aged %s in Kosova were employed, against %s%% of men: a gap of %s ",
  "percentage points. Differences in education level between women and men account for about %s%% to ",
  "%s%% of that gap, depending on whether men's or women's education mix is the reference (an ",
  "accounting split, not a causal effect). In the %d census the same split gives about %s%% to %s%% ",
  "at ages %s and %s%% to %s%% at ages %s, which leaves out most students.**"),
  yr, p1(f$all_rate_women), dash(lfs_band), p1(f$all_rate_men), p1(f$all_gap_pp),
  p0(sh_lo), p0(sh_hi), yr, p0(min(c1)), p0(max(c1)), dash(cen_bands[1]),
  p0(min(c2)), p0(max(c2)), dash(cen_bands[2]))

precision <- sprintf(paste0(
  "The ranges show the choice of reference, not sampling error, which cannot be estimated from ",
  "published tables. Each share is of the gap rebuilt from the three education groups (%s points in ",
  "the LFS, against the published %s) and is computed from unrounded inputs; on either base the LFS ",
  "range rounds to the same whole numbers."),
  p1(G_lfs), p1(f$all_gap_pp))

catalogue <- sprintf(paste0(
  "In %d (LFS, ages %s), differences in education level between women and men account for about ",
  "%s–%s%% of Kosova's %s-point gender employment gap (an accounting split, not a causal effect), ",
  "while women's own employment rate rises steeply with education (%s%% to %s%%); in the %d census, ",
  "about %s–%s%%"),
  yr, dash(lfs_band), p0(sh_lo), p0(sh_hi), p1(f$all_gap_pp),
  p0(f$low_rate_women), p0(f$tertiary_rate_women), yr, p0(cen_lo), p0(cen_hi))

two_questions <- sprintf(paste0(
  "Two different questions sit behind this, and they have different answers. ",
  "**How does women's employment vary with education?** A great deal: %s%% of women with no formal ",
  "or primary education are employed, against %s%% of women with tertiary education, though the groups ",
  "also differ in age: the lowest group includes teenagers still in school. ",
  "**How much of the gap between women and men do differences in their education account for?** ",
  "A minority of it. Women and men are spread differently across education levels (in the LFS, %s%% of ",
  "working-age women and %s%% of men are in the lowest group), but the difference lies mainly between ",
  "the two lower groups, where women's employment is low in both (%s%% and %s%%). Women are slightly ",
  "more likely than men to have tertiary education (%s%% against %s%%, LFS). Within each of the three ",
  "pooled education groups the gap stays large, from %s points (tertiary) to %s points (upper ",
  "secondary). Neither fact says what would happen to women's employment if their education changed; ",
  "that is not identified here."),
  p1(f$low_rate_women), p1(f$tertiary_rate_women), p1(f$low_share_women), p1(f$low_share_men),
  p1(f$low_rate_women), p1(f$upper_sec_rate_women),
  p1(f$tertiary_share_women), p1(f$tertiary_share_men), p1(f$tertiary_gap_pp), p1(f$upper_sec_gap_pp))

# Tables
t_pooled <- tibble(
  `Education (pooled)` = c("No formal education or primary", "Upper secondary", "Tertiary",
                           sprintf("**All, %s** (ASK's published total)", dash(lfs_band))),
  `Women, %` = p1(c(f$low_rate_women, f$upper_sec_rate_women, f$tertiary_rate_women, f$all_rate_women)),
  `Men, %` = p1(c(f$low_rate_men, f$upper_sec_rate_men, f$tertiary_rate_men, f$all_rate_men)),
  `Gap, points` = p1(c(f$low_gap_pp, f$upper_sec_gap_pp, f$tertiary_gap_pp, f$all_gap_pp)),
  `% of women in group` = c(p1(c(f$low_share_women, f$upper_sec_share_women, f$tertiary_share_women)), "—"),
  `% of men in group` = c(p1(c(f$low_share_men, f$upper_sec_share_men, f$tertiary_share_men)), "—"))

w_desc <- c(`men's shares as reference`   = "men's education mix",
            `women's shares as reference` = "women's education mix",
            `average of the two`          = "the average of the two mixes")
stopifnot(all(dl$weighting %in% names(w_desc)))
t_split <- tibble(
  `Within-level gaps weighted by` = unname(w_desc[dl$weighting]),
  `Composition valued at` = dl$composition_valued_at,
  `Within levels, points` = sprintf("%.2f", dl$within_pp),
  `Composition, points` = sprintf("%.2f", dl$composition_pp),
  `Composition, % of gap` = p1(lfs_sh))

cat_lab <- c("No formal education or primary", "Upper secondary", "Tertiary")
lfs_cen_rows <- tibble(
  `Source, ages` = sprintf("LFS, %s", dash(lfs_band)),
  Category = c(cat_lab, "All"),
  `Women, %` = p1(c(f$low_rate_women, f$upper_sec_rate_women, f$tertiary_rate_women, f$all_rate_women)),
  `Men, %` = p1(c(f$low_rate_men, f$upper_sec_rate_men, f$tertiary_rate_men, f$all_rate_men)),
  `Gap, points` = p1(c(f$low_gap_pp, f$upper_sec_gap_pp, f$tertiary_gap_pp, f$all_gap_pp)))
cen_rows <- ct |> transmute(`Source, ages` = sprintf("Census, %s", dash(band)),
                            Category = ifelse(grepl("^All", category), "All", category),
                            `Women, %` = p1(rate_women), `Men, %` = p1(rate_men), `Gap, points` = p1(gap_pp))
t_census <- bind_rows(lfs_cen_rows, cen_rows)
stopifnot(nrow(t_census) == 12)

t_shares <- cs |> transmute(
  `Source, ages` = sub("^(LFS|Census) ", "\\1, ", gsub("-", "–", version)),
  `Within-level gaps weighted by` = unname(w_desc[weighting]),
  `Composition, points` = sprintf("%.2f", composition_pp),
  `Gap rebuilt from three groups, points` = sprintf("%.2f", G_pp),
  `Composition, % of gap` = p1(100 * composition_share))
stopifnot(!anyNA(t_shares$`Within-level gaps weighted by`))
# "the difference lies mainly between the two lower groups" (two_questions)
stopifnot(abs(f$tertiary_share_women - f$tertiary_share_men) <
            min(abs(f$low_share_women - f$low_share_men), abs(f$upper_sec_share_women - f$upper_sec_share_men)))

doc_lab <- c(afp2024 = "ASK, *Anketa e Fuqisë Punëtore 2024*",
             afp2023 = "ASK, *Anketa e Fuqisë Punëtore 2023*",
             afp2021 = "ASK, *Anketa e Fuqisë Punëtore 2021*",
             tm3_2022 = "ASK, *Anketa e Fuqisë Punëtore TM3 2022*",
             lfs_q4_2020 = "ASK, *Labour Force Survey Q4 2020*",
             ihsn_2012 = "ASK LFS 2012 metadata (IHSN catalogue, DDI export)",
             ihsn_2014 = "ASK LFS 2014 metadata (IHSN catalogue, DDI export)")
kp <- f$check_e2_key_passages
stopifnot(all(kp$doc %in% names(doc_lab)), !anyNA(kp$page))
breaks_list <- sprintf("  - %s: [%s](%s), p. %d.", kp$finding, doc_lab[kp$doc], kp$url, as.integer(kp$page))

ou_line <- function(b, s) {
  r <- ou[ou$band == b & ou$sex == s, ]
  sprintf("%s employed (%s%% of the sex's employed), %s people (%s%%)",
          big(r$employed), sprintf("%.2f", 100 * r$share_of_employed), big(r$population),
          sprintf("%.2f", 100 * r$share_of_population))
}

pkgs <- c("dplyr", "tidyr", "readr", "purrr", "stringr", "tibble", "ggplot2", "jsonlite",
          "pxweb", "pdftools", "showtext", "magick")
scripts <- c("R/01_e_lfs_gender_check.R", "R/01_e2_lfs_detail_check.R", "R/01_e3_age_check.R",
             "R/03_build_pooled_e.R", "R/04_decompose_e.R", "R/04b_census_check_e.R",
             "R/05_figure_e.R", "R/08_methods_note.R")
stopifnot(all(file.exists(scripts)))
outputs <- c("data/processed/figures.json", "data/processed/e_lfs_education_sex.csv",
             "data/processed/e2_latest_full_table.csv", "data/processed/e3_pooled_2024.csv",
             "data/processed/e3_decomposition_2024.csv", "data/processed/e3_within_contributions_2024.csv",
             "data/processed/e4_census_2024.csv", "data/processed/e4_census_decomposition_2024.csv",
             "data/processed/e4_census_mapping.csv", "data/processed/e4_census_other_unknown_2024.csv",
             "data/processed/e4_composition_share_2024.csv",
             "output/employment_gap_by_education_2024.png",
             "output/employment_gap_by_education_2024_linkedin_1200.png")
stopifnot(all(file.exists(outputs)))

# --- 3. README -------------------------------------------------------------------------
readme <- c(
"# Punësimi i grave dhe arsimi — Women's employment and education in Kosova",
"",
sprintf(paste0("An accounting split of the gap between women's and men's employment in Kosova by education ",
               "level, from ASK's Labour Force Survey %d, checked against the %d census."), yr, yr),
"",
finding,
"",
precision,
"",
two_questions,
"",
sprintf("![Employment rate of women and men by education level, Kosova, %d](output/employment_gap_by_education_2024_linkedin_1200.png)", yr),
"",
"## The question",
"",
sprintf(paste0("Women in Kosova are far less likely to be employed than men. Women are also more often in the ",
               "lowest education group. This piece asks how much of the employment gap that difference accounts for ",
               "in an accounting sense, by comparing women and men within the same education level and splitting the overall ",
               "gap into a part *within* education levels and a part from the different *composition* of women and ",
               "men across levels. The split is an accounting identity on published %d figures. It is not a model ",
               "of why anyone is or is not employed."), yr),
"",
"## Data sources (all open)",
"",
sprintf("All from ASK (Agjencia e Statistikave të Kosovës), ASKdata PxWeb, English node. Sources accessed %s (UTC), as recorded in `data/raw/_download_log.csv`.", accessed),
"",
"- **Labour Force Survey, annual tables** (Labour market > Anketa e Fuqisë Punëtore > Annual labour market):",
sprintf("  - `tab3.px` — employment ('000s) and employment-to-population ratio (%%), by education attainment and sex, age group %s. The headline table.", dash(lfs_band)),
"  - `tab0.px` — population by sex and age group (checks the derived population).",
"  - `tab1b.px` — main labour-market indicators (checks the headline rates).",
"  - `tab20.px` — unemployment by education and sex (used only for the participation limitation).",
"  - `tab29.px` — accuracy of the national headline estimates.",
sprintf("- **Census %d**:", yr),
"  - `lc06ensus.px` (Census population > 4_Labour market) — employed by gender, education level and age group.",
"  - `tabcensusedu1.px` (Census population > 2_Education) — population aged 15 and over by educational attainment, gender and age.",
"  - `census2024_00.px` (Census population > 1_Demographic_Characteristics) — population by age and sex (checks the census universe).",
"- **ASK documents** on how the LFS series was produced (annual and quarterly LFS reports, and ASK's LFS metadata as catalogued by IHSN), cited by page in the appendix. They are downloaded by `R/01_e2_lfs_detail_check.R` and not redistributed here.",
"",
"Deliberately excluded:",
"",
"- `lc07ensus.px` (employed by education and five-year age group). Its sex labels contradict `lc06ensus.px`; see Limitations.",
"- LFS microdata. They are not published, so no cell-level standard errors or finer controls are possible.",
"",
"## Definitions",
"",
sprintf(paste0("- **Employment rate**: employed persons as a share of the population of the same sex (and, in the ",
               "tables by education, the same education level). ASK calls this the employment-to-population ratio. ",
               "Ages %s, %d."), dash(lfs_band), yr),
sprintf(paste0("- **Three education groups**, pooled from ASK's %s categories: *No formal education or primary* ",
               "= no formal education + primary; *Upper secondary* = secondary vocational + gymnasium; *Tertiary* ",
               "= tertiary. ASK's \"Primary\" has no separate lower-secondary category, and the %s categories sum ",
               "exactly to the total, so lower-secondary completers are almost certainly in \"Primary\"; ASK ",
               "publishes no ISCED mapping that confirms it. In the census tables the lowest group does include ",
               "the 8/9-grade lower-secondary rows (checked in `R/01_e3_age_check.R`)."),
        num_word(f$check_e_n_levels), num_word(f$check_e_n_levels)),
"- **Population by education** is not published in `tab3`. It is derived as employment ÷ (rate ÷ 100). ASK rounds rates to one decimal, so each derived population is known only within a rounding interval; the guards in `R/03_build_pooled_e.R` work with that interval.",
sprintf("- **The gap** is men's rate minus women's rate, in percentage points. The headline %s points is ASK's published total row. The split below uses the gap recomputed from the three pooled groups, %s points.",
        p1(f$all_gap_pp), sprintf("%.2f", G_lfs)),
"",
"## Method",
"",
"Scripts run in this order from the piece root. The numbering has gaps (no 02, 06, 07) because the scripts keep the numbers of the working folder they were developed in.",
"",
"1. **`R/01_e_lfs_gender_check.R`** — pulls the LFS tables and checks them: categories add up to totals, men + women = total, the derived population against `tab0`, cell sizes.",
sprintf("2. **`R/01_e2_lfs_detail_check.R`** — reads the table metadata, compares `tab3` with ASK's printed %d report, and locates ASK's own statements about breaks in the series, with page numbers.", yr),
"3. **`R/01_e3_age_check.R`** — scans the metadata of every LFS and census table for an education × age × sex breakdown, and finds the `lc07ensus` contradiction.",
"4. **`R/03_build_pooled_e.R`** — builds the three pooled groups: pooled rate = summed employed ÷ summed derived population; each sex's share of its working-age population per group.",
"5. **`R/04_decompose_e.R`** — splits the gap into a within-level and a composition part under three weightings (below).",
"6. **`R/04b_census_check_e.R`** — rebuilds the same three groups from the census (`lc06ensus` over `tabcensusedu1`) for two age bands, and repeats the split.",
"7. **`R/05_figure_e.R`** — the lead figure, rendered once at full size and downscaled for LinkedIn.",
"8. **`R/08_methods_note.R`** — writes this README from `data/processed/figures.json`.",
"",
"The `01_` scripts write their own check tables and plots to `checks/`, which is not published; the numbers this README quotes from them are copied into `figures.json`.",
"",
"**The split.** With *s* each sex's share of its working-age population in an education group and *r* the employment rate in that group, the gap between men (m) and women (f) is",
"",
"G = Σ s_m·r_m − Σ s_f·r_f.",
"",
"It splits into a part *within* education levels, a weighted average of the within-level gaps, and a *composition* part, from women and men being spread differently across levels. Which weights to use is a choice, not a measurement, so all three standard choices are reported and the result is a range:",
"",
"- within = Σ s_m (r_m − r_f), composition = Σ (s_m − s_f) r_f;",
"- within = Σ s_f (r_m − r_f), composition = Σ (s_m − s_f) r_m;",
"- within = Σ ½(s_m + s_f)(r_m − r_f), composition = Σ (s_m − s_f) ½(r_m + r_f).",
"",
"Each adds up to G exactly. The difference between the first two is the interaction of the two parts; the third splits it evenly.",
"",
"\"Controlling for education\" here means only this: comparing women and men within the same one of three broad education groups, then averaging those within-group gaps. That average is the within part; the headline reports the other part, the composition part. Whatever differs between women and men inside a group, such as age, field of study, region or family situation, stays in the within part. The average depends on whose education mix supplies the weights, which is why there is a range.",
"",
"## Key results",
"",
sprintf("**Employment rate by education, ages %s, %d** (LFS):", dash(lfs_band), yr),
"",
md_table(t_pooled),
"",
sprintf("The gap within upper secondary (%s points) is larger than the overall gap (%s points). Rates and gaps are rounded to one decimal; a gap is computed before rounding.",
        p1(f$upper_sec_gap_pp), p1(f$all_gap_pp)),
"",
sprintf("**Within/composition split, LFS %s** (gap recomputed from the three groups: %s points):", dash(lfs_band), sprintf("%.2f", G_lfs)),
"",
md_table(t_split),
"",
sprintf("The composition part is %s to %s points, %s%% to %s%% of the gap, depending on the weighting. The within-level part is %s to %s points. Shares are computed from unrounded inputs; rebuilding them from this rounded table gives slightly different decimals.",
        p1(comp_lo), p1(comp_hi), p1(sh_lo), p1(sh_hi), p1(min(dl$within_pp)), p1(max(dl$within_pp))),
"",
sprintf("With ASK's %s unpooled categories instead of three groups, the same split gives a composition part of %s to %s points, %s%% to %s%% of a rebuilt gap of %s points.",
        num_word(f$check_e_n_levels), p1(min(d5$composition_pp)), p1(max(d5$composition_pp)),
        p1(min(sh5)), p1(max(sh5)), sprintf("%.2f", G5)),
"",
sprintf(paste0("**Census check.** The same three groups, from the %d census, for ages %s and, to leave out most ",
               "students, %s. The census measures employment differently from the LFS (activity status at the ",
               "census reference date, against the ILO definition averaged over a year-round survey), so its ",
               "levels differ, mainly for women."), yr, dash(cen_bands[1]), dash(cen_bands[2])),
"",
md_table(t_census),
"",
sprintf("**Composition share in all %s combinations** (three source and age-band versions × three weightings):", num_word(n_combos)),
"",
md_table(t_shares),
"",
sprintf(paste0("Each share is of that version's own gap rebuilt from the three groups. It differs from the ",
               "published LFS total by rounding (%s points) and from the census total rows by the Other/Unknown ",
               "rows left out (%s and %s points)."),
        sprintf("%+.2f", f$gap_recomputed_minus_headline_pp), sprintf("%+.2f", f$census_1564_gap_three_minus_total_pp),
        sprintf("%+.2f", f$census_2564_gap_three_minus_total_pp)),
"",
sprintf("Across all %s the composition part is %s%% to %s%% of the gap: less than a fifth every time. In the census alone it is %s%% to %s%%.",
        num_word(n_combos), p1(all_lo), p1(all_hi), p1(cen_lo), p1(cen_hi)),
"",
sprintf(paste0("Which reference gives the larger composition part is not fixed. In the %s at %s, weighting by men's ",
               "mix gives the larger one (%s against %s points); in the other two versions it gives the smaller."),
        ifelse(startsWith(flip_v, "LFS"), "LFS", "census"), dash(sub("^(LFS|Census) ", "", flip_v)),
        sprintf("%.2f", flip_r$composition_pp[flip_r$weighting == "men's shares as reference"]),
        sprintf("%.2f", flip_r$composition_pp[flip_r$weighting == "women's shares as reference"])),
"",
"## Reproduce",
"",
sprintf("R ≥ %s. Packages: %s.", R_MIN, paste0("`", pkgs, "`", collapse = ", ")),
"",
"From the `gender-employment-gap/` folder:",
"",
"```",
paste0("Rscript ", scripts),
"```",
"",
sprintf("The PxWeb extracts are committed in `data/raw/` and are not re-downloaded. The ASK reports and IHSN metadata are downloaded on the first run (%d-second pause between requests) and kept locally; they are not committed.", as.integer(POLITE_SLEEP)),
"",
"## Outputs",
"",
paste0("- `", outputs, "`"),
"- `README.md`, `output/catalogue_row.md` (from `R/08_methods_note.R`)",
"- `checks/` (verification tables and plots from the `01_` scripts; not published)",
"",
"## Limitations",
"",
paste0("- **No causal claim.** The split is accounting: it says how much of the gap the different education mix of ",
       "women and men accounts for, under one set of weights at a time. It does not say what would happen if ",
       "women's education changed. Age, place of residence, family situation and who goes on to study all differ ",
       "between these groups, and these tables cannot separate them. Whether education and employment are causally ",
       "linked is not identified here."),
paste0("- **What the within-level gap is.** It may include discrimination, preferences, care responsibilities, ",
       "and differences in age, region or field of study. These data cannot tell them apart, and the gap is not a ",
       "measure of any one of them."),
sprintf(paste0("- **Age band.** Ages %s include young people still in education: teenagers still in school sit ",
               "in the lowest group and count as not employed. In the census the gap is %s points at %s and %s points ",
               "at %s, and the composition share at %s (%s%% to %s%%) sits at the top of the LFS range. The headline ",
               "uses %s because ASK publishes no LFS table crossing education, age and sex: of the %s LFS and census ",
               "tables scanned, the %s that do are all census tables."),
        dash(lfs_band), p1(cen_all(cen_bands[1], "gap_pp")), dash(cen_bands[1]),
        p1(cen_all(cen_bands[2], "gap_pp")), dash(cen_bands[2]), dash(cen_bands[2]), p0(min(c2)), p0(max(c2)),
        dash(lfs_band), f$check_e3_n_tables_scanned, num_word(f$check_e3_n_educ_age_tables)),
sprintf(paste0("- **Three broad levels.** \"Education\" here means three groups. Years of schooling, vocational ",
               "against general tracks, field of study and quality are not observed. With ASK's %s unpooled categories ",
               "the composition share is %s%% to %s%% (Key results), and one ordering changes: the gap for *No formal ",
               "education* alone (%s points) is smaller than the tertiary gap (%s)."),
        num_word(f$check_e_n_levels), p1(min(sh5)), p1(max(sh5)), f$check_e_gap_none, p1(f$tertiary_gap_pp)),
sprintf(paste0("- **The LFS and the census give different education mixes.** At %s the share of each sex in a ",
               "group differs between the two sources by up to %s points (upper secondary: women %s%% in the LFS ",
               "against %s%% in the census; men %s%% against %s%%). The LFS %d weighting base equals the census ",
               "population, but its education mix does not match the census. The reason is not established here; ",
               "the shares are the direct input to the composition part."),
        dash(lfs_band), p1(mix_max), p1(mix$lfs_w[2]), p1(mix$cen_w[2]), p1(mix$lfs_m[2]), p1(mix$cen_m[2]), yr),
sprintf(paste0("- **Employment combines participation and unemployment.** In the LFS, %s%% of women and %s%% of men ",
               "aged %s are in the labour force (employed or unemployed), and the unemployment rate is %s%% for women ",
               "and %s%% for men. The employment gap contains both; this piece does not split them."),
        p1(f$lfs_activity_rate_women), p1(f$lfs_activity_rate_men), dash(lfs_band),
        p1(f$lfs_unemployment_rate_women), p1(f$lfs_unemployment_rate_men)),
paste0("- **Emigration.** Emigration, which may differ by sex and education, shapes who is in the ",
       "resident population that these tables describe. These tables do not measure it."),
sprintf(paste0("- **No trend.** Only %d is used. ASK's documents and the series itself show breaks that make ",
               "earlier years hard to compare; they are listed in the appendix below."), yr),
sprintf(paste0("- **`lc07ensus` contradicts `lc06ensus`.** At ages %s, `lc07ensus` labels %s employed as men and %s ",
               "as women; `lc06ensus` has the same two numbers the other way round (%s men, %s women). Read with ",
               "its own labels, `lc07ensus` has one cell where employment exceeds population (upper secondary, women ",
               "%s: %s employed against %s people). `lc07ensus` is therefore not used. The census check depends on ",
               "`lc06ensus` having the correct labels; that agrees with every other source checked, but ASK has not ",
               "confirmed it (tables last updated %s and %s)."),
        dash(lfs_band), big(f$check_e3_lc07_male_1564), big(f$check_e3_lc07_female_1564),
        big(f$check_e3_lc06_male_1564), big(f$check_e3_lc06_female_1564), dash(cen_bands[2]), imp[1], imp[2],
        substr(f$check_e3_lc07_updated, 1, 10), substr(f$check_e3_lc06_updated, 1, 10)),
sprintf(paste0("- **LFS and census measure different things.** The census counts %s employed aged %s; the LFS %s. ",
               "Women's employment rate is %s%% in the census and %s%% in the LFS. The census check tests whether the ",
               "pattern holds, not the level."),
        big(f$check_e3_census_employed_1564), dash(lfs_band), big(f$check_e3_lfs_employed_1564),
        p1(cen_all(cen_bands[1], "rate_women")), p1(f$all_rate_women)),
sprintf(paste0("- **Census universes.** The census education table (`tabcensusedu1`) covers %s fewer people aged %s ",
               "(%s) than the census population table (`census2024_00`, %s; also the LFS %d weighting base). Census ",
               "rates therefore combine two slightly different populations: employed from `lc06ensus`, whose universe ",
               "is not stated, over population from `tabcensusedu1`. If the employed come from the larger universe, ",
               "census rates are too high by up to about %s%% of their value."),
        big(f$census_1564_pop_gap), dash(lfs_band), big(f$census_1564_pop_edu1), big(f$census_1564_pop_tab00), yr,
        p1(univ_pct)),
sprintf(paste0("- **Census residual categories.** \"Other\" and \"Unknown\" education are left out of the census ",
               "groups. At %s: women %s; men %s. At %s: women %s; men %s."),
        dash(cen_bands[1]), ou_line(cen_bands[1], "Female"), ou_line(cen_bands[1], "Male"),
        dash(cen_bands[2]), ou_line(cen_bands[2], "Female"), ou_line(cen_bands[2], "Male")),
sprintf(paste0("- **Northern municipalities.** The census figures include %s employed aged %s in the four northern ",
               "municipalities, as published. Whether these are enumerated persons or include ASK's estimates is not ",
               "stated in the table. Coverage of the north by the LFS sample is not stated; the LFS weighting base ",
               "equals the census total including the north, so if the north is not sampled, its population is ",
               "represented by respondents elsewhere."),
        big(f$census_1564_north_employed), dash(lfs_band)),
sprintf(paste0("- **Sampling.** The LFS is a sample survey. ASK publishes reliability only for the national headline ",
               "rates (coefficient of variation of the %s employment rate: %s%%), not for education × sex cells. The ",
               "smallest cell is %s (%s thousand employed); pooling with \"Primary\" limits its weight."),
        dash(lfs_band), f$check_e_cv_employment_rate, sub(" (Female|Male)$", ", \\L\\1", f$check_e_smallest_cell, perl = TRUE),
        f$check_e_smallest_cell_emp_k),
sprintf(paste0("- **Derived populations.** The derived population summed over the %s categories differs from ",
               "ASK's published %s population by %s%% (women) and %s%% (men), and the overall gap recomputed from ",
               "the three groups differs from the published one by %s points; both are within the rounding of the ",
               "published rates."),
        num_word(f$check_e_n_levels), dash(lfs_band), sprintf("%+.2f", f$pop_pct_vs_tab0_women),
        sprintf("%+.2f", f$pop_pct_vs_tab0_men), sprintf("%+.2f", f$gap_recomputed_minus_headline_pp)),
"",
"## Appendix: breaks in the LFS series",
"",
"Not used in the results, which are for one year only. Recorded so that the 2024 figures are not compared with earlier years without care. From ASK's own documents:",
"",
sub("^  ", "", breaks_list),
"",
"In the data:",
"",
sprintf(paste0("- ASK's working-age population (`tab0`) moves from %s thousand in %d to %s thousand in %d (%s%%), ",
               "against changes of at most %s%% a year in earlier years; the %d base equals the census total (%s)."),
        format(as.numeric(f$check_e2_tab0_wa_2023), big.mark = ",", nsmall = 1), yr - 1L,
        format(as.numeric(f$check_e2_tab0_wa_2024), big.mark = ",", nsmall = 1), yr, f$check_e2_tab0_yoy_2024,
        f$check_e2_tab0_yoy_prior_maxabs, yr, big(f$check_e2_rep24_base_total)),
sprintf("- The split between vocational and general secondary education jumps in %s years with no explanation found: %s. The pooled upper-secondary group is stable across those years, which is one reason the two are pooled.",
        f$check_e2_n_swings, f$check_e2_swing_years),
sprintf("- No ASK LFS documentation was found for %s.", f$check_e2_doc_years_missing),
"",
"## Licence and reuse",
"",
sprintf(paste0("Kosova, all ASK data: Kosovo Agency of Statistics (KAS), licensed under CC BY 4.0 ",
               "(https://creativecommons.org/licenses/by/4.0/; terms: %s, retrieved %s). Modified: education ",
               "categories pooled; populations derived from published employment and rates. No endorsement by KAS is ",
               "implied. The repository licence covers the code only."), ASK_TERMS_URL, ASK_TERMS_RETRIEVED),
"",
"Design, decisions and verification by the author; code written with AI assistance (Claude Code). One independent cold-context review was run before publication; its points were assessed one by one and the accepted ones applied in this version.",
"",
"---",
"",
sprintf("*Data: ASK (Kosovo Agency of Statistics), Labour Force Survey and Census %d, via ASKdata. Analysis: Plator Krasniqi.*", yr)
)
txt <- paste(readme, collapse = "\n")

# --- 4. Wording guard and write --------------------------------------------------------
# Permitted source-controlled strings: the licensor's required attribution.
permitted <- c("Kosovo Agency of Statistics")
strip <- function(x) { for (s in permitted) x <- gsub(s, "", x, fixed = TRUE); x }
check_wording(strip(txt), "README")
check_wording(catalogue, "catalogue row")
stopifnot(grepl("(an accounting split, not a causal effect)", finding, fixed = TRUE),
          grepl("(an accounting split, not a causal effect)", catalogue, fixed = TRUE),
          !grepl("lines? up with", txt), !grepl("about 30", txt), !grepl("{{", txt, fixed = TRUE),
          !grepl("combinations of source", finding), !grepl("combinations", catalogue),   # cold review M2/M3
          grepl("rises steeply with education", catalogue, fixed = TRUE))                  # cold review M5

con <- file(file.path(PROJ, "README.md"), open = "wb"); writeLines(enc2utf8(txt), con, useBytes = TRUE); close(con)
dir.create(file.path(PROJ, "output"), showWarnings = FALSE)
row <- sprintf("| [`gender-employment-gap/`](gender-employment-gap) | %s | ASK Labour Force Survey %d and Census %d (PxWeb) |",
               catalogue, yr, yr)
con <- file(file.path(PROJ, "output", "catalogue_row.md"), open = "wb"); writeLines(enc2utf8(row), con, useBytes = TRUE); close(con)

cat("wrote README.md (", length(strsplit(txt, "\\s+")[[1]]), "words ) and output/catalogue_row.md\n")
cat("\nFinding:\n", finding, "\n\nCatalogue row:\n", row, "\n")
