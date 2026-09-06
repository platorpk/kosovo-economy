# ==============================================================================
# 07_figures.R  —  "Llogaria e diasporës" / The diaspora account
#
# TRUNCATED AT 2020. No provisional year enters any figure. 2021-2024 sit inside
# the CBK services revision announced for September 2026, and 2025 has no GDP
# denominator. The series is drawn 2008-2020 and stops there deliberately.
#
#   TOP    : diaspora account as % of GDP, 2008-2020, three estimates drawn as
#            THREE DISTINCT LINES, never a shaded interval — they are not
#            ordered (see below). Remittances-only plotted alongside in rust so
#            the gap between the headline number and the account is the visual.
#   BOTTOM : component composition, stacked, same years, IMF baseline shares.
#
# WHY NOT A SHADED BAND. Errors and omissions is negative in 2020, so attributing
# 100% of it (maximal_attribution) yields a SMALLER total than attributing 50%
# (imf_baseline): 30.97% against 31.02% of GDP. A shaded interval would render
# that crossing as a pinch and imply an ordering that does not exist. The crossing
# is annotated instead.
#
# PALETTE. House style per CLAUDE.md section 6: navy #1A4E8A, rust #C0552E, on
# off-white #F7F5F2, Source Sans 3 via showtext. The three derived component
# fills were checked with a categorical-palette validator: worst adjacent pair
# separates at dE 14.5 (protan) and 19.3 (normal vision), both comfortably above
# the 8 / 15 floors. Navy sits outside the validator's lightness band and the
# errors-and-omissions grey below its chroma floor; both are kept deliberately —
# navy is the house colour, and grey is the right reading for a residual line
# that changes sign. The low-contrast fill is relieved by the legend and by the
# component table in the README.
#
# Run from the piece root:  Rscript R/07_figures.R [YYYY-MM]
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2)
  library(showtext); library(patchwork); library(scales); library(ggrepel)
}))

source("C:/Users/plato/Documents/kosovo-economy/diaspora-account/R/01_functions.R")

VINTAGE <- resolve_vintage()
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
house_font()

YR_MIN <- 2008L
YR_MAX <- 2020L        # hard truncation — nothing provisional in any figure

acct <- readRDS(file.path(PROC_DIR, paste0("diaspora_account_", VINTAGE, ".rds")))
comp <- readRDS(file.path(PROC_DIR, paste0("components_annual_", VINTAGE, ".rds")))
gdp  <- read_csv(file.path(PROC_DIR, "gdp_nominal_annual.csv"), show_col_types = FALSE)

# FDI treatment. excl_reinvested is carried as the baseline because it averages
# 3.203% of IMF GDP over 2018-19 against the 3.2 Box 1 prints — but that is a
# COINCIDENCE WITH A DIFFERENT CONCEPT, not evidence. Box 1's own arithmetic
# (Total -3.1 = Residents +0.1 + Diaspora -3.2) identifies its diaspora row with
# whole-economy NET direct investment (-3.095%), not with equity liabilities
# (+3.894%). The footnote and the Box's numbers cannot be reconciled from the
# published material, and the 2020 test fails at -1.26 pp. See 06 section [3].
FDI_BASE <- "excl_reinvested"

# Bands drawn. travel_070 and travel_050 are sensitivity variants reported in the
# README and the processed data, not plotted — two more navy lines would clutter
# the panel without adding a distinct shape.
PLOT_BANDS <- c("maximal_attribution", "imf_baseline", "remittances_and_travel")

# Guard the truncation itself: no provisional year may reach a figure.
base <- acct |> filter(fdi_variant == FDI_BASE, band %in% PLOT_BANDS,
                       year >= YR_MIN, year <= YR_MAX)
stopifnot(!any(base$provisional), all(base$has_denominator))
stopifnot(nrow(distinct(base, year)) == YR_MAX - YR_MIN + 1L)
stopifnot(setequal(unique(base$band), PLOT_BANDS))

# --- lead panel data -----------------------------------------------------------
remit_only <- comp |>
  filter(component == "remittances", year >= YR_MIN, year <= YR_MAX) |>
  left_join(gdp |> select(year, gdp_eur_m), by = "year") |>
  transmute(year, band = "remittances_only", pct_gdp = 100 * value / gdp_eur_m)

lines_df <- bind_rows(base |> select(year, band, pct_gdp), remit_only) |>
  mutate(band = factor(band, levels = c("maximal_attribution", "imf_baseline",
                                        "remittances_and_travel", "remittances_only")))

LAB <- c(maximal_attribution = "Maximal attribution",
         imf_baseline        = "IMF baseline",
         remittances_and_travel        = "Remittances + travel",
         remittances_only    = "Remittances only")
COL <- c(maximal_attribution = navy, imf_baseline = navy,
         remittances_and_travel = navy, remittances_only = rust)
LTY <- c(maximal_attribution = "dotted", imf_baseline = "solid",
         remittances_and_travel = "dashed", remittances_only = "solid")
LWD <- c(maximal_attribution = 0.7, imf_baseline = 1.3,
         remittances_and_travel = 0.7, remittances_only = 1.1)

ends <- lines_df |> filter(year == YR_MAX)

# --- headline numbers, computed (never typed) ----------------------------------
v <- function(b, y) { x <- lines_df$pct_gdp[which(lines_df$band == b & lines_df$year == y)]
  stopifnot(length(x) == 1L); x }
bl_2019 <- v("imf_baseline", 2019); bl_2020 <- v("imf_baseline", 2020)
mx_2020 <- v("maximal_attribution", 2020)
rm_2019 <- v("remittances_only", 2019); ns_2019 <- v("remittances_and_travel", 2019)
bl_2008 <- v("imf_baseline", 2008)

# The figure must carry its own epistemics: read alone, it should not state as
# fact what the README qualifies. The subtitle names the quantity as an
# ATTRIBUTION and gives the share of it that cannot be independently checked.
unver_2019 <- {
  g <- gdp$gdp_eur_m[gdp$year == 2019]
  cw <- comp |> select(component, year, value) |>
    tidyr::pivot_wider(names_from = component, values_from = value)
  o <- function(c) cw[[c]][cw$year == 2019]
  100 * (0.92 * o("travel_credits") + o("remittances")) / g / bl_2019 * 100
}

title_txt <- "Llogaria e diasporës"
sub_txt <- wrap(sprintf(
  paste("What the IMF's allocation attributes to the diaspora, percent of GDP, 2008-2020. On those shares the",
        "total reaches %.1f%% of GDP in 2019, against the %.1f%% the workers' remittance line shows on its own.",
        "About %.0f%% of the 2019 total rests on lines that cannot be checked against any independently published",
        "figure. The estimates vary the staff judgements, not the data, and they are not an ordered band."),
  bl_2019, rm_2019, unver_2019), 92)

cap_txt <- paste(
  wrap(paste("Estimates apply the allocation in IMF Country Report No. 21/41, PDF p24 [printed p20], footnote 1/ to the",
             "table embedded in Box 1: 92% of travel services receipts, 100% of workers' remittances, 100% of",
             "compensation of employees, 100% of FDI equity liabilities, 50% of errors and omissions. Remittances +",
             "travel keeps only those two — it is not a lower bound, since 59% of it is the 92% travel share."), 124),
  wrap(paste("Compensation of employees is the net entry. The FDI series excludes reinvested earnings; the source's",
             "footnote and its own arithmetic disagree about what that row is, so the FDI mapping has no established",
             "basis. Series stops at 2020: CBK has announced a revision to travel services for 2021-2024, not yet",
             "applied, and 2025 has no published GDP denominator. Shares are staff judgement — see Limitations."), 124),
  sprintf("Source: CBK time series (vintage %s); ASK national accounts  |  Analysis: Plator Krasniqi",
          VINTAGE), sep = "\n")

pLine <- ggplot(lines_df, aes(year, pct_gdp, colour = band,
                              linetype = band, linewidth = band)) +
  geom_line(lineend = "round") +
  geom_point(data = ends, size = 1.9, show.legend = FALSE) +
  # The crossing: maximal attribution falls BELOW baseline in 2020. Placed in the
  # empty area beneath the remittances line. No leader — a connector to 2020 would
  # have to cross the remittances series, and the label names the year itself.
  annotate("text", x = 2008.2, y = 7.2, hjust = 0, vjust = 1, family = "ss3",
           size = 3.0, colour = sub, lineheight = 1.2,
           label = sprintf(paste("2020: maximal attribution (%.1f%%) falls BELOW the",
                                 "baseline (%.1f%%) — errors and omissions turns negative,",
                                 "so attributing more subtracts. Not an ordered band.", sep = "\n"),
                           mx_2020, bl_2020)) +
  scale_colour_manual(values = COL, labels = LAB, name = NULL) +
  scale_linetype_manual(values = LTY, labels = LAB, name = NULL) +
  scale_linewidth_manual(values = LWD, labels = LAB, name = NULL, guide = "none") +
  # two rows: "Remittances + travel" is long enough that one row overflows
  guides(colour = guide_legend(nrow = 2, byrow = TRUE),
         linetype = guide_legend(nrow = 2, byrow = TRUE)) +
  scale_x_continuous(breaks = seq(2008, 2020, 2), limits = c(YR_MIN, 2024.4)) +
  # Lower limit runs below zero to give the crossing note clear room; breaks stop
  # at 0 so the empty strip carries no misleading negative gridline.
  scale_y_continuous(labels = function(y) paste0(y, "%"),
                     breaks = seq(0, 40, 10), limits = c(-7, 46)) +
  # Direct labels in addition to the legend; repelled on y because maximal
  # attribution and the baseline converge at 2020.
  geom_text_repel(data = ends, aes(label = LAB[as.character(band)]),
                  family = "ss3", fontface = "bold", size = 3.2, hjust = 0,
                  direction = "y", nudge_x = 0.45, seed = 42,
                  xlim = c(2020.5, 2024.4), min.segment.length = 0,
                  segment.colour = sub, segment.size = 0.25,
                  box.padding = 0.28, point.padding = 0.25, show.legend = FALSE) +
  labs(x = NULL, y = "Percent of GDP") +
  theme_minimal(base_family = "ss3", base_size = 12) +
  theme(
    legend.position   = "top", legend.justification = "left",
    legend.margin     = margin(b = 2), legend.key.width = unit(26, "pt"),
    legend.text       = element_text(size = 9.5, colour = sub),
    axis.title.y      = element_text(size = 10, colour = sub),
    axis.text         = element_text(size = 9.5, colour = sub),
    panel.grid.minor  = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = grid, linewidth = 0.3),
    plot.margin       = margin(4, 10, 4, 6))

# --- composition panel ---------------------------------------------------------
# Validated fills. Order is the stack order; adjacency is what the validator
# checked. Grey marks the residual, and it is the segment that goes negative.
navy_lt <- "#4A90C7"; rust_lt <- "#E39B62"; resid <- "#7D7D76"

# Labels name the series as mapped, not as the IMF footnote words it: our
# compensation series is the net entry, and our FDI series is equity excluding
# reinvested earnings.
CLAB <- c(c_travel = "Travel receipts (92%)", c_remit = "Workers' remittances",
          c_comp = "Compensation of employees (net)",
          c_fdi = "FDI equity (excl. reinvested)",
          c_eo = "Errors and omissions (50%)")
CFILL <- c(c_travel = rust, c_remit = navy, c_comp = navy_lt,
           c_fdi = rust_lt, c_eo = resid)

stack <- base |>
  filter(band == "imf_baseline") |>
  select(year, gdp_eur_m, c_travel, c_remit, c_comp, c_fdi, c_eo) |>
  pivot_longer(starts_with("c_"), names_to = "part", values_to = "eur_m") |>
  mutate(pct = 100 * eur_m / gdp_eur_m,
         part = factor(part, levels = names(CLAB)))

eo_2020 <- stack$pct[stack$year == 2020 & stack$part == "c_eo"]

pStack <- ggplot(stack, aes(year, pct, fill = part)) +
  geom_hline(yintercept = 0, colour = sub, linewidth = 0.4) +
  # 2px surface gap between stacked segments
  geom_col(width = 0.72, colour = off, linewidth = 0.35) +
  annotate("segment", x = 2018.9, xend = 2019.75, y = -4.6, yend = eo_2020 - 0.5,
           colour = sub, linewidth = 0.3) +
  annotate("text", x = 2018.7, y = -4.9, family = "ss3", size = 3.0,
           colour = sub, hjust = 1, vjust = 0.5,
           label = sprintf("2020: errors and omissions turns negative (%.1f%% of GDP)", eo_2020)) +
  scale_fill_manual(values = CFILL, labels = CLAB, name = NULL) +
  scale_x_continuous(breaks = seq(2008, 2020, 2)) +
  scale_y_continuous(labels = function(y) paste0(y, "%"), breaks = seq(-10, 40, 10),
                     limits = c(-7.5, 41)) +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(title = "What the account is made of",
       subtitle = "IMF baseline allocation, percent of GDP",
       x = NULL, y = "Percent of GDP") +
  theme_minimal(base_family = "ss3", base_size = 12) +
  theme(
    plot.title    = element_text(size = 13, colour = ink, face = "bold", margin = margin(b = 1)),
    plot.subtitle = element_text(size = 10, colour = sub, margin = margin(b = 6)),
    legend.position = "bottom", legend.justification = "left",
    legend.text   = element_text(size = 9, colour = sub),
    legend.key.size = unit(10, "pt"),
    axis.title.y  = element_text(size = 10, colour = sub),
    axis.text     = element_text(size = 9.5, colour = sub),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = grid, linewidth = 0.3),
    plot.margin   = margin(8, 10, 4, 6))

fig <- (pLine / pStack) + plot_layout(heights = c(1, 0.82)) +
  plot_annotation(
    title = title_txt, subtitle = sub_txt, caption = cap_txt,
    theme = theme(
      plot.title    = element_text(family = "ss3", face = "bold", size = 22, colour = ink,
                                   margin = margin(b = 4)),
      plot.subtitle = element_text(family = "ss3", size = 11, colour = sub, lineheight = 1.15,
                                   margin = margin(b = 10)),
      plot.caption  = element_text(family = "ss3", size = 8, colour = sub, hjust = 0,
                                   lineheight = 1.3, margin = margin(t = 12)),
      plot.margin   = margin(18, 20, 14, 20)))

# Render once at full size; downscale the raster for the 1200px version so layout
# and typography stay identical (re-rendering smaller rescales showtext).
save_fig <- function(plot, stem, w = 2000, h = 2750) {
  hi <- file.path(OUT_DIR, paste0(stem, ".png"))
  ggsave(hi, plot, width = w, height = h, units = "px", dpi = 300, bg = off)
  magick::image_write(magick::image_resize(magick::image_read(hi), "1200x"),
                      file.path(OUT_DIR, paste0(stem, "_linkedin_1200.png")))
  hi
}
p <- save_fig(fig, "diaspora_account_2008_2020")

# --- headline numbers to stdout ------------------------------------------------
cat("\n", strrep("-", 78), "\n", sep = "")
cat("HEADLINE NUMBERS (computed, not typed)\n")
cat(sprintf("  vintage                      : %s | FDI treatment: %s\n", VINTAGE, FDI_BASE))
cat(sprintf("  IMF baseline 2008            : %.1f%% of GDP\n", bl_2008))
cat(sprintf("  IMF baseline 2019            : %.1f%% of GDP\n", bl_2019))
cat(sprintf("  Remittances only  2019       : %.1f%% of GDP\n", rm_2019))
cat(sprintf("  gap, baseline - remittances  : %.1f pp (%.2fx)\n",
            bl_2019 - rm_2019, bl_2019 / rm_2019))
cat(sprintf("  Remittances + travel 2019    : %.1f%% of GDP\n", ns_2019))
cat(sprintf("  IMF baseline 2020            : %.1f%% of GDP\n", bl_2020))
cat(sprintf("  Maximal attribution 2020     : %.1f%% of GDP\n", mx_2020))
cat(sprintf("  2020 crossing                : maximal - baseline = %+.3f pp  (%s)\n",
            mx_2020 - bl_2020,
            if (mx_2020 < bl_2020) "CROSSING PRESENT — maximal falls BELOW baseline"
            else "no crossing — ordering holds"))
cat(sprintf("  E&O contribution 2020        : %.1f%% of GDP\n", eo_2020))
# every year where the ordering inverts, not just the one the annotation names
inv <- lines_df |> filter(band %in% c("imf_baseline", "maximal_attribution")) |>
  select(year, band, pct_gdp) |> tidyr::pivot_wider(names_from = band, values_from = pct_gdp) |>
  filter(maximal_attribution < imf_baseline)
cat(sprintf("  years with an inverted ordering in the plotted window: %s\n",
            if (nrow(inv)) paste(inv$year, collapse = ", ") else "none"))
cat(sprintf("  years plotted                : %d-%d (%d), provisional: %d\n",
            YR_MIN, YR_MAX, nrow(distinct(base, year)), sum(base$provisional)))
cat("\n2019 composition, percent of GDP:\n")
print(as.data.frame(stack |> filter(year == 2019) |>
        transmute(component = CLAB[as.character(part)], pct_gdp = round(pct, 2))),
      row.names = FALSE, right = FALSE)
cat("\nSaved:\n  ", p, "\n  ",
    file.path(OUT_DIR, "diaspora_account_2008_2020_linkedin_1200.png"), "\n", sep = "")
