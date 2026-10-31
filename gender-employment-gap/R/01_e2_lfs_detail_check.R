# ==============================================================================
# 01_e2_lfs_detail_check.R
# Verification step 2 (2026-10-23).
# Still verification only: no estimation, no within/composition split computed.
#
# 1. The full published table for the latest year: employment-to-population
#    ratio by sex for every education category ASK reports, and the share of
#    men and of women in each category (shares guarded to sum to 1).
# 2. Indicator, population and table IDs, read from the PxWeb metadata.
# 3. ASK documentation on breaks, weighting and redesign 2012-2024: documents
#    are downloaded and methodology passages extracted with page numbers to
#    checks/e2_doc_passages.csv. The passages are reported, not interpreted
#    as a trend.
# 4. Reliability flags / cell sizes: what ASK publishes for these cells.
#
# Sources (ASK PxWeb, Labour market > Anketa e Fuqisë Punëtore > Annual labour
# market): tab3.px, tab20.px, tab29.px (cached by 01_e), tab0.px "Population by
# sex and age group, 2012 - 2024" (new). ASK LFS annual reports (askapi PDFs),
# the ASK LFS Q4 2020 report, and ASK's LFS 2012-2014 metadata as catalogued by
# IHSN (DDI export).
#
# Concept notes:
#   - The education-by-sex population is NOT published. It is derived as
#     employment / (employment-to-population ratio / 100). The shares below are
#     shares of that derived population, normalised within sex over the five
#     categories.
#   - PxWeb publishes employment in thousands (3 decimals); the annual report's
#     Tab. 1.2 prints the same figures in persons under a heading that says
#     "NË MIJËRA" (in thousands). Both are compared below.
#
# Writes: data/raw/ask_lfs_tab0_population.csv, data/raw/lfs_docs/*,
#   data/processed/e2_latest_full_table.csv, checks/e2_*.csv|json|png (not
#   published), figures.json (check_e2_* keys)
# Run from the piece root:  Rscript R/01_e2_lfs_detail_check.R
# ==============================================================================
source("R/00_functions.R")
dir.create(file.path(RAW_DIR, "lfs_docs"), showWarnings = FALSE)

node <- paste0(ASK_BASE, "/Labour%20market/Anketa%20e%20Fuqis%C3%AB%20Pun%C3%ABtore/",
               "Annual%20labour%20market")
num <- function(x) suppressWarnings(as.numeric(x))

# --- 1. PxWeb tables ---------------------------------------------------------------
t3  <- ask_pull_cached(paste0(node, "/tab3.px"),
                       list(Variabla = "*", `Niveli i arsimit` = "*", Viti = "*", Gjinia = "*"),
                       "ask_lfs_tab3_employment_by_education_sex.csv")
t20 <- ask_pull_cached(paste0(node, "/tab20.px"),
                       list(Variabla = "*", `Kosovë` = "*", Viti = "*", Gjinia = "*"),
                       "ask_lfs_tab20_unemployment_by_education_sex.csv")
t0  <- ask_pull_cached(paste0(node, "/tab0.px"),
                       list(Variabla = "*", `Grup-mosha` = "*", Viti = "*", Gjinia = "*"),
                       "ask_lfs_tab0_population.csv")
verify_block(t0, "tab0 raw")

# Table metadata (titles, variable labels) saved raw for the indicator statement
meta_file <- file.path(RAW_DIR, "ask_lfs_tab3_tab20_tab0_metadata.json")
if (!file.exists(meta_file)) {
  m <- lapply(c("tab3.px", "tab20.px", "tab0.px"), function(t) {
    x <- jsonlite::fromJSON(paste0(node, "/", t)); Sys.sleep(POLITE_SLEEP)
    list(table = t, title = x$title, variables = x$variables)
  })
  writeLines(toJSON(m, auto_unbox = TRUE, pretty = TRUE), meta_file, useBytes = TRUE)
  log_download(basename(meta_file), paste0(node, "/{tab3,tab20,tab0}.px"), "ASK PxWeb metadata", TRUE)
}
meta <- fromJSON(meta_file, simplifyVector = FALSE)
title_of <- function(t) meta[[which(vapply(meta, `[[`, "", "table") == t)]]$title

e3 <- t3 |> setNames(c("variable", "education", "year", "sex", "value")) |>
  mutate(value = num(value), year = as.integer(year),
         variable = recode(variable, "Employment ('000s)" = "emp_k",
                           "Employment-to-population ratio (%)" = "emp_rate")) |>
  pivot_wider(names_from = variable, values_from = value)
stopifnot(setequal(names(e3), c("education", "year", "sex", "emp_k", "emp_rate")))
cats <- c("No formal education", "Primary", "Secondary education, vocational",
          "Secondary education, gymnasium", "Tertiary")
stopifnot(setequal(unique(e3$education), c(cats, "Total")))      # every category ASK reports

p0 <- t0 |> setNames(c("variable", "age", "year", "sex", "value")) |>
  mutate(value = num(value), year = as.integer(year)) |>
  filter(variable == "Population ('000s)", age == "15-64") |>
  select(year, sex, pop_tab0_k = value)
stopifnot(nrow(p0) == 13 * 3)

latest <- max(e3$year)
L <- e3 |> filter(year == latest) |>
  mutate(pop_k = emp_k / (emp_rate / 100))                        # derived
stopifnot(nrow(L) == 6 * 3, !anyNA(L))

# --- 2. Full latest-year table, shares guarded --------------------------------------
full <- L |> filter(sex != "Total", education != "Total") |>
  group_by(sex) |> mutate(share = pop_k / sum(pop_k)) |> ungroup()
share_sums <- full |> group_by(sex) |> summarise(s = sum(share), .groups = "drop")
stopifnot(all(abs(share_sums$s - 1) < 1e-12))                     # shares sum to 1, by sex
# Derived category populations vs derived Total row, and vs tab0 (published)
chk <- L |> filter(sex != "Total") |> group_by(sex) |>
  summarise(sum_cats = sum(pop_k[education != "Total"]),
            total_row = pop_k[education == "Total"], .groups = "drop") |>
  left_join(p0 |> filter(year == latest), by = "sex") |>
  mutate(pct_cats_vs_total = 100 * (sum_cats / total_row - 1),
         pct_total_vs_tab0 = 100 * (total_row / pop_tab0_k - 1),
         pct_cats_vs_tab0 = 100 * (sum_cats / pop_tab0_k - 1))
print(chk)
# Same agency, separately published tables -> tolerance, report on breach (§2)
tol_pct <- 1
if (any(abs(c(chk$pct_cats_vs_total, chk$pct_total_vs_tab0)) > tol_pct))
  cat("NOTE: derived population differs from tab0 by more than", tol_pct, "%\n")
# Identities within tab3 (hard)
emp_id <- L |> filter(sex != "Total") |> group_by(sex) |>
  summarise(d = sum(emp_k[education != "Total"]) - emp_k[education == "Total"], .groups = "drop")
stopifnot(all(abs(emp_id$d) < 0.002))
mf_id <- L |> group_by(education) |>
  summarise(d = emp_k[sex == "Male"] + emp_k[sex == "Female"] - emp_k[sex == "Total"], .groups = "drop")
stopifnot(all(abs(mf_id$d) < 0.002))

wide <- L |> filter(education != "Total" | TRUE) |>
  select(education, sex, emp_k, emp_rate, pop_k) |>
  pivot_wider(names_from = sex, values_from = c(emp_k, emp_rate, pop_k)) |>
  left_join(full |> select(education, sex, share) |>
              pivot_wider(names_from = sex, values_from = share, names_prefix = "share_"),
            by = "education") |>
  mutate(gap_pp = emp_rate_Male - emp_rate_Female,
         education = factor(education, c(cats, "Total"))) |> arrange(education)
write_csv(wide, file.path(PROC_DIR, "e2_latest_full_table.csv"))
print(wide, width = 200)

# --- 3. Cross-check against the printed annual report (ASK LFS 2024, Tab. 1.2) -------
rep24 <- download_cached("https://askapi.rks-gov.net/Custom/085719f6-0ef0-4365-afa7-9a02c8d10cf5.pdf",
                         "lfs_docs/ask_085719f6-0ef0-4365-afa7-9a02c8d10cf5.pdf", "ASK")
tx24 <- pdftools::pdf_text(rep24)
pg <- which(grepl("Tab. 1.2: Të punësuar", tx24) & grepl("Pa shkollë", tx24))
stopifnot(length(pg) == 1)
lines <- str_squish(strsplit(tx24[pg], "\n")[[1]])
lab_al <- c("Pa shkollë" = "No formal education", "Fillor" = "Primary",
            "Arsim i mesëm profesional" = "Secondary education, vocational",
            "Arsim i mesëm - gjimnazi" = "Secondary education, gymnasium",
            "Terciar" = "Tertiary", "Gjithsej" = "Total")
start <- which(grepl("^Tab\\. 1\\.2", lines))
rows <- lines[seq(start, length(lines))]
parse_block <- function(rows, integer_vals) {
  out <- map_dfr(names(lab_al), function(a) {
    hit <- rows[startsWith(rows, paste0(a, " "))]
    hit <- hit[grepl(if (integer_vals) "\\d+ \\d+ \\d+$" else "\\d+\\.\\d \\d+\\.\\d \\d+\\.\\d$", hit)]
    v <- as.numeric(strsplit(sub(paste0("^", a, " "), "", hit[1]), " ")[[1]])
    tibble(education = lab_al[[a]], Male = v[1], Female = v[2], Total = v[3])
  })
  out
}
rep_emp  <- parse_block(rows, TRUE)
rep_rate <- parse_block(rows, FALSE)
heading_says_thousands <- any(grepl("PUNËSIMI \\(NË MIJËRA\\)", rows))
stopifnot(nrow(rep_emp) == 6, !anyNA(rep_emp), nrow(rep_rate) == 6, !anyNA(rep_rate))
cmp <- L |> select(education, sex, emp_k, emp_rate) |>
  left_join(rep_emp |> pivot_longer(-education, names_to = "sex", values_to = "rep_persons"),
            by = c("education", "sex")) |>
  left_join(rep_rate |> pivot_longer(-education, names_to = "sex", values_to = "rep_rate"),
            by = c("education", "sex")) |>
  mutate(d_emp_persons = emp_k * 1000 - rep_persons, d_rate = emp_rate - rep_rate)
print(cmp |> filter(abs(d_emp_persons) > 1 | abs(d_rate) > 0.05))
rep_emp_maxabs  <- max(abs(cmp$d_emp_persons))
rep_rate_maxabs <- max(abs(cmp$d_rate))
stopifnot(rep_emp_maxabs <= 1, rep_rate_maxabs < 0.05)

# Population base printed in the 2024 and 2023 reports (Fig. 1), vs tab0
fig1 <- function(tx) {
  pg <- which(grepl("Popullsia në moshë pune \\(15 - 64\\)", tx))[1]
  l  <- str_squish(strsplit(tx[pg], "\n")[[1]])
  ib <- which(grepl("^Popullsia e përgjithshme", l))[1]
  base_lab <- l[ib]
  base_total <- as.numeric(gsub(" ", "", l[ib + 1]))
  i  <- which(grepl("^Popullsia në moshë pune", l))
  val <- as.numeric(gsub(" ", "", l[i + 1]))
  mf  <- as.numeric(gsub(" ", "", regmatches(l[i + 2], gregexpr("[0-9][0-9 ]+[0-9]", l[i + 2]))[[1]]))
  list(base_label = base_lab, base_total = base_total, wa_total = val,
       wa_male = mf[1], wa_female = mf[2])
}
f24 <- fig1(tx24)
rep23 <- download_cached("https://askapi.rks-gov.net/Custom/d8b6019c-eccf-419f-a5b0-9fb7df247ce3.pdf",
                         "lfs_docs/ask_d8b6019c-eccf-419f-a5b0-9fb7df247ce3.pdf", "ASK")
tx23 <- pdftools::pdf_text(rep23)
f23 <- fig1(tx23)
str(f24); str(f23)
stopifnot(f24$wa_male + f24$wa_female == f24$wa_total, f23$wa_male + f23$wa_female == f23$wa_total)
# The 2024 base vs the census total that includes ASK's estimates for the four
# northern municipalities (census2024_00, KOSOVA row, pulled by 01_b).
cen <- read_csv(file.path(RAW_DIR, "ask_census2024_00_population.csv"), show_col_types = FALSE)
cen_total_2024 <- as.numeric(cen[[ncol(cen)]][cen$Municipality == "KOSOVA" & cen$Year == 2024 &
                                               cen$Age == "Total"])
stopifnot(length(cen_total_2024) == 1)
base24_equals_census_incl_north <- f24$base_total == cen_total_2024
tab0_total <- function(y) p0$pop_tab0_k[p0$year == y & p0$sex == "Total"] * 1000
d_tab0_rep24 <- tab0_total(2024) - f24$wa_total
d_tab0_rep23 <- tab0_total(2023) - f23$wa_total
cat("tab0 vs report working-age population: 2024", d_tab0_rep24, " 2023", d_tab0_rep23, "\n")

# Weighting base across years, as published in tab0 (not a trend in the indicator)
pop_series <- p0 |> filter(sex == "Total") |> arrange(year) |>
  mutate(yoy_pct = 100 * (pop_tab0_k / lag(pop_tab0_k) - 1))
write_utf8_csv(pop_series, "e2_tab0_working_age_population.csv")
print(pop_series)
yoy_2024 <- pop_series$yoy_pct[pop_series$year == 2024]
yoy_prior_maxabs <- max(abs(pop_series$yoy_pct[pop_series$year < 2024]), na.rm = TRUE)

# --- 4. Documentation: breaks, weighting, redesign -------------------------------------
docs <- tribble(
  ~id, ~url, ~file,
  "afp2024",  "https://askapi.rks-gov.net/Custom/085719f6-0ef0-4365-afa7-9a02c8d10cf5.pdf", "lfs_docs/ask_085719f6-0ef0-4365-afa7-9a02c8d10cf5.pdf",
  "afp2023",  "https://askapi.rks-gov.net/Custom/d8b6019c-eccf-419f-a5b0-9fb7df247ce3.pdf", "lfs_docs/ask_d8b6019c-eccf-419f-a5b0-9fb7df247ce3.pdf",
  "lfs_q4_2020", "https://askapi.rks-gov.net/Custom/2c09a68c-35f9-4131-9c66-beb6255acfb0.pdf", "lfs_docs/ask_2c09a68c.pdf",
  "ask_f809b076", "https://askapi.rks-gov.net/Custom/f809b076-a9eb-4641-938c-d7f4d94f90bb.pdf", "lfs_docs/ask_f809b076.pdf",
  "ask_9bee491c", "https://askapi.rks-gov.net/Custom/9bee491c-a7bb-477d-a86c-a5f1f049dab8.pdf", "lfs_docs/ask_9bee491c.pdf",
  "ask_d483c4e9", "https://askapi.rks-gov.net/Custom/d483c4e9-d88b-4c56-b888-4a05f5fff76e.pdf", "lfs_docs/ask_d483c4e9.pdf",
  "ask_0e4f8244", "https://askapi.rks-gov.net/Custom/0e4f8244-38b2-4104-b198-d2ed4b28bb41.pdf", "lfs_docs/ask_0e4f8244.pdf",
  "ask_eae105cc", "https://askapi.rks-gov.net/Custom/eae105cc-1eb7-41c3-b327-0e25782f183b.pdf", "lfs_docs/ask_eae105cc.pdf",
  "ask_75dc2a44", "https://askapi.rks-gov.net/Custom/75dc2a44-2ff1-4237-b7f5-a33eca52b215.pdf", "lfs_docs/ask_75dc2a44.pdf",
  "ihsn_2012", "https://catalog.ihsn.org/metadata/export/7242/ddi", "lfs_docs/ihsn_7242_ddi.xml",
  "ihsn_2013", "https://catalog.ihsn.org/metadata/export/7243/ddi", "lfs_docs/ihsn_7243_ddi.xml",
  "ihsn_2014", "https://catalog.ihsn.org/metadata/export/7244/ddi", "lfs_docs/ihsn_7244_ddi.xml"
)
read_doc <- function(path) {
  if (grepl("\\.pdf$", path)) pdftools::pdf_text(path)
  else {                                                  # DDI XML: one "page", tags stripped
    x <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    x <- gsub("<!\\[CDATA\\[|\\]\\]>", "", x)
    gsub("<[^>]+>", "\n", x)
  }
}
kw <- paste(c("pesh", "weight", "projekt", "projection", "projected", "regjistrim", "census",
              "CATI", "CAPI", "telefon", "phone", "COVID", "pandemi", "krahasue", "comparab",
              "ndërpre", "break", "rishik", "revis", "metodologji", "methodolog",
              "Zona", "Enumeration Area", "ekonomi familjare të", "ISCED", "redesign",
              "kalibr", "calibrat"), collapse = "|")
doc_meta <- list(); passages <- list()
for (i in seq_len(nrow(docs))) {
  d <- docs[i, ]
  p <- download_cached(d$url, d$file, if (grepl("ihsn", d$id)) "IHSN catalog (DDI, ASK metadata)" else "ASK")
  tx <- read_doc(p)
  first <- str_squish(paste(tx[1:min(2, length(tx))], collapse = " "))
  title <- str_extract(first, "(Anketa e Fuqisë Punëtore|Labour Force Survey|Rezultatet e Anketës së Fuqisë Punëtore|KSV_20[0-9]{2}_LFS)[^.]{0,60}")
  doc_meta[[d$id]] <- tibble(id = d$id, url = d$url, n_pages = length(tx),
                             title = title %||% NA_character_, first_chars = substr(first, 1, 300))
  for (pg in seq_along(tx)) {
    ls <- str_squish(strsplit(tx[pg], "\n")[[1]])
    h <- which(grepl(kw, ls, ignore.case = TRUE) & nchar(ls) > 25)
    if (length(h)) passages[[length(passages) + 1]] <-
      tibble(id = d$id, page = pg, line = ls[h])
  }
}
doc_meta <- bind_rows(doc_meta); passages <- bind_rows(passages)
print(doc_meta |> select(id, n_pages, title), width = 200)
write_utf8_csv(doc_meta, "e2_doc_inventory.csv")
write_utf8_csv(passages, "e2_doc_passages.csv")

# Key passages: each documentation finding is tied to a verbatim line (doc, page).
# The finding labels are reviewed summaries; the quoted text is the document's own.
KEY <- tribble(
  ~finding, ~id, ~pattern,
  "2012 redesign: Eurostat methodology, continuous survey, new frame from the 2011 census", "afp2024", "Nga viti 2012",
  "2012: sample phased in quarter by quarter; weights computed per quarter", "ihsn_2012", "weights are calculated separately",
  "2013/2014: weights adjusted to a projected population total", "ihsn_2014", "adjust the 2014 Kosovo LFS weights",
  "2013: a similar adjustment, to a projection variant", "ihsn_2014", "For the 2013 LFS a similar adjustment",
  "2020 Q2: field collection stopped for three months (non-response)", "afp2021", "ndërpresë grumbullimin e të dhënave",
  "2020-21: new law barred external interviewer staff; collection later covered the preceding months retrospectively", "afp2021", "hyrjes në fuqi të legjislacionit",
  "2020 Q4: households refusing contact were interviewed by phone", "lfs_q4_2020", "were contacted by phone",
  "2022 H1: two further one-month interruptions of field interviews", "afp2021", "ndërprejë intervistat",
  "From March 2022: re-interviews by telephone (CATI)", "tm3_2022", "CATI \\(përmes telefonit\\)",
  "Panel design: delays in collection affect the quality of published data", "tm3_2022", "ndikojnë në cilësinë",
  "2021 report: interviews described as CAPI only", "afp2021", "metodës CAPI",
  "2023 report: first interviews CAPI, re-interviews CATI", "afp2023", "rianketimet",
  "2023 report: population base 'estimated' for 2023", "afp2023", "Popullsia e përgjithshme e vlerësuar",
  "2024 report: population base from the 2024 census", "afp2024", "Popullsia e përgjithshme sipas regjistrimit"
)
docs <- docs |> mutate(id = recode(id, ask_d483c4e9 = "afp2021", ask_9bee491c = "tm3_2022",
                                   ask_f809b076 = "afp2022"))
passages <- passages |> mutate(id = recode(id, ask_d483c4e9 = "afp2021", ask_9bee491c = "tm3_2022",
                                           ask_f809b076 = "afp2022"))
key_hits <- pmap_dfr(KEY, function(finding, id, pattern) {
  d <- docs[docs$id == id, ]
  tx <- read_doc(file.path(RAW_DIR, d$file))
  for (pg in seq_along(tx)) {
    flat <- str_squish(tx[pg])
    j <- regexpr(pattern, flat, perl = TRUE)
    if (j > 0) return(tibble(finding = finding, doc = id, page = pg,
                             quote = substr(flat, max(1, j - 60), j + 220), url = d$url))
  }
  tibble(finding = finding, doc = id, page = NA_integer_, quote = NA_character_, url = d$url)
})
stopifnot(!anyNA(key_hits$page))               # every stated finding rests on a located passage
write_utf8_csv(key_hits, "e2_key_passages.csv")
print(key_hits |> select(finding, doc, page), n = 30, width = 200)
doc_years_covered <- c("2012", "2013", "2014", "2020 (Q4)", "2021", "2022 (Q3)", "2022", "2023", "2024")
doc_years_missing <- setdiff(as.character(2012:2024), sub(" .*", "", doc_years_covered))

# Education categories: share of total employment by year (both sexes). Large
# opposite-signed moves in the two secondary categories are flagged as possible
# coding/classification changes; no ASK note explaining them was found.
cat_sh <- read_csv(file.path(PROC_DIR, "e_lfs_education_sex.csv"), show_col_types = FALSE) |>
  filter(sex == "Total") |> group_by(year) |>
  mutate(emp_share = 100 * emp_k / emp_k[education == "Total"]) |> ungroup() |>
  filter(education != "Total") |> select(year, education, emp_share) |>
  pivot_wider(names_from = education, values_from = emp_share) |> arrange(year)
stopifnot(all(abs(rowSums(cat_sh[, -1]) - 100) < 0.2))
mv <- cat_sh |> transmute(year, d_voc = `Secondary education, vocational` - lag(`Secondary education, vocational`),
                          d_gym = `Secondary education, gymnasium` - lag(`Secondary education, gymnasium`)) |>
  filter(!is.na(d_voc))
SWING_PP <- 5
swings <- mv |> filter(sign(d_voc) != sign(d_gym), abs(d_voc) > SWING_PP, abs(d_gym) > SWING_PP)
print(swings)
write_utf8_csv(cat_sh, "e2_category_shares_by_year.csv")

# --- 5. Reliability -------------------------------------------------------------------
# What ASK publishes: tab29 (national headline accuracy only). Cell-level: nothing.
t29 <- read_csv(file.path(RAW_DIR, "ask_lfs_tab29_accuracy.csv"), show_col_types = FALSE)
acc_vars <- unique(t29[[3]])
cells_small <- full |> arrange(emp_k) |> head(4)

# --- 6. Diagnostic figure -------------------------------------------------------------
plot_d <- full |> mutate(education = factor(education, cats))
p <- ggplot(plot_d, aes(education, 100 * share, fill = sex)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c(Male = "#1A4E8A", Female = "#C0552E")) +
  coord_flip() + labs(title = paste("Derived share of each sex's 15-64 population by education,", latest),
                      x = NULL, y = "%", fill = NULL) + diag_theme
ggsave(file.path(CHECK_DIR, "e2_shares_latest.png"), p, width = 8, height = 4, dpi = 150)

# --- 7. Numbers out ---------------------------------------------------------------------
fmt <- function(x, d = 1) sprintf(paste0("%.", d, "f"), x)
# Access dates from the download log (raw files used by this script; direct reads listed)
src_dates <- accessed_from_log(extra = c("ask_lfs_tab3_tab20_tab0_metadata.json",
                                             "ask_census2024_00_population.csv",
                                             "ask_lfs_tab29_accuracy.csv"))
write_numbers(list(
  accessed = src_dates$display, accessed_first = src_dates$first, accessed_last = src_dates$last, latest_year = latest,
  tab3_title = title_of("tab3.px"), tab20_title = title_of("tab20.px"), tab0_title = title_of("tab0.px"),
  n_categories = length(cats),
  share_sum_male = fmt(share_sums$s[share_sums$sex == "Male"], 6),
  share_sum_female = fmt(share_sums$s[share_sums$sex == "Female"], 6),
  pct_cats_vs_total_male = fmt(chk$pct_cats_vs_total[chk$sex == "Male"], 2),
  pct_cats_vs_total_female = fmt(chk$pct_cats_vs_total[chk$sex == "Female"], 2),
  pct_total_vs_tab0_male = fmt(chk$pct_total_vs_tab0[chk$sex == "Male"], 2),
  pct_total_vs_tab0_female = fmt(chk$pct_total_vs_tab0[chk$sex == "Female"], 2),
  rep_emp_maxabs_persons = fmt(rep_emp_maxabs, 0), rep_rate_maxabs = fmt(rep_rate_maxabs, 2),
  report_heading_says_thousands = heading_says_thousands,
  rep24_base_label = f24$base_label, rep23_base_label = f23$base_label,
  rep24_wa_total = f24$wa_total, rep23_wa_total = f23$wa_total,
  rep24_base_total = f24$base_total, rep23_base_total = f23$base_total,
  census2024_total_incl_north = cen_total_2024,
  base24_equals_census_incl_north = base24_equals_census_incl_north,
  d_tab0_rep24 = d_tab0_rep24, d_tab0_rep23 = d_tab0_rep23,
  tab0_wa_2023 = fmt(tab0_total(2023) / 1000, 1), tab0_wa_2024 = fmt(tab0_total(2024) / 1000, 1),
  tab0_yoy_2024 = fmt(yoy_2024), tab0_yoy_prior_maxabs = fmt(yoy_prior_maxabs),
  tab29_variables = paste(acc_vars, collapse = " | "),
  smallest_cells = paste(sprintf("%s %s %s thousand", cells_small$education, cells_small$sex,
                                 fmt(cells_small$emp_k, 3)), collapse = "; "),
  n_docs = nrow(doc_meta), n_passages = nrow(passages),
  n_isced_hits = sum(grepl("ISCED", passages$line)),
  n_lfs_docs = sum(grepl("Fuqisë Punëtore|Labour Force|LFS", doc_meta$title)),
  non_lfs_docs = paste(doc_meta$id[!grepl("Fuqisë Punëtore|Labour Force|LFS", doc_meta$title %||% "")], collapse = ", "),
  doc_years_missing = paste(doc_years_missing, collapse = ", "),
  swing_pp = SWING_PP,
  swing_years = paste(sprintf("%d (vocational %+.1f, gymnasium %+.1f pp)", swings$year, swings$d_voc, swings$d_gym),
                      collapse = "; "),
  n_swings = nrow(swings)
), "e2")

# --- figures.json (check_e2_* keys): the numbers the README quotes from this step --
chk <- fromJSON(file.path(CHECK_DIR, "e2_numbers.json"))
keep <- c("accessed_first", "accessed_last", "tab0_wa_2023", "tab0_wa_2024", "tab0_yoy_2024",
          "tab0_yoy_prior_maxabs", "rep24_base_total", "base24_equals_census_incl_north",
          "n_swings", "swing_years", "doc_years_missing")
stopifnot(all(keep %in% names(chk)))
fj_merge(c(setNames(chk[keep], paste0("check_e2_", keep)),
           list(check_e2_key_passages = key_hits |> select(finding, doc, page, url))))
