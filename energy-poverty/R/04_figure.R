# ==============================================================================
# 04_figure.R  —  "Shtëpi të ftohta" / Kosova's cold homes
# Vertically stacked composition (patchwork):
#   TOP    : Kosova, unable to keep home adequately warm, ASK SILC 2018-2024
#            (shown as published; 2019 flagged — see README Limitations).
#   BOTTOM : regional dispersion strip, Eurostat EU-SILC latest year per country
#            (framed as spread, not ranking); Kosova at 2018 (EU-comparable,
#            filled) and 2024 (ASK national series, hollow).
# All quoted numbers are computed from the processed CSVs (reconciled in 03).
# House style: navy/rust, Source Sans 3 (showtext). Descriptive language only.
# Run from the piece root:  Rscript R/04_figure.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(ggplot2); library(ggrepel)
  library(showtext); library(patchwork)
}))

proj    <- "C:/Users/plato/Documents/kosovo-economy/energy-poverty"
out_dir <- file.path(proj, "output")
font_add_google("Source Sans 3", "ss3"); showtext_auto(); showtext_opts(dpi = 300)

navy <- "#1A4E8A"; rust <- "#C0552E"; off <- "#F7F5F2"
ink  <- "#23282D"; sub <- "#5C636B"; grid <- "#E4E4E0"; ref_grey <- "#8A8F94"

wrap <- function(x, w) paste(strwrap(x, width = w), collapse = "\n")

ask <- read_csv(file.path(proj, "data/processed/silc10_keep_warm.csv"), show_col_types = FALSE) |>
  mutate(year = as.integer(year))
eur <- read_csv(file.path(proj, "data/processed/eurostat_keep_warm.csv"), show_col_types = FALSE) |>
  filter(poverty == "total")

# --- pinned values used in text (all from data; none hard-coded) ---------------
xk18   <- ask$no[ask$year == 2018]                       # 40.2, reconciled == Eurostat
xk24   <- ask$no[ask$year == 2024]                       # ASK latest
eu18   <- eur$value[eur$geo == "EU27_2020" & eur$year == 2018]
latest <- eur |> filter(geo != "XK") |> group_by(geo) |>
  slice_max(year, n = 1) |> ungroup()
rs <- latest |> filter(geo == "RS"); al <- latest |> filter(geo == "AL")
stopifnot(length(xk18) == 1, length(eu18) == 1, nrow(rs) == 1, nrow(al) == 1)

# ============================ TOP: KOSOVA SERIES ================================
ask <- ask |> mutate(lab = sprintf("%.1f%s", no, ifelse(year == 2019, "*", "")))

pA <- ggplot(ask, aes(year, no)) +
  geom_line(colour = navy, linewidth = 0.6, alpha = 0.65) +
  geom_point(colour = navy, size = 3.2) +
  geom_point(data = ask |> filter(year == 2018), shape = 21, size = 6,
             colour = rust, fill = NA, stroke = 1.1) +
  geom_text(aes(label = lab), family = "ss3", size = 3.2, colour = ink,
            vjust = -1.25, fontface = "bold") +
  annotate("text", x = 2018, y = xk18 + 12.5, label = "2018: last\nEU-comparable point",
           family = "ss3", size = 2.9, colour = rust, lineheight = 0.95, hjust = 0.2) +
  scale_x_continuous(breaks = 2018:2024, limits = c(2017.7, 2024.3)) +
  scale_y_continuous(labels = function(y) paste0(y, "%"), breaks = c(0, 20, 40, 60),
                     limits = c(0, 78), expand = c(0, 0)) +
  labs(title = "Kosova: unable to keep the home adequately warm",
       subtitle = "% of households, ASK SILC survey years") +
  theme_minimal(base_family = "ss3", base_size = 12) +
  theme(
    plot.title    = element_text(size = 13, colour = ink, face = "bold", margin = margin(b = 1)),
    plot.subtitle = element_text(size = 10, colour = sub, margin = margin(b = 8)),
    axis.title    = element_blank(),
    axis.text     = element_text(size = 9.5, colour = sub),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = grid, linewidth = 0.3),
    plot.margin   = margin(6, 12, 10, 6))

# ============================ BOTTOM: DISPERSION STRIP ==========================
strip <- bind_rows(
  latest |> transmute(geo, value, year,
                      name = recode(geo, AL = "Shqipëria", RS = "Serbia", ME = "Mali i Zi",
                                    MK = "Maqedonia e V.", TR = "Turqia", EU27_2020 = "BE-27"),
                      kind = ifelse(geo == "EU27_2020", "ref", "comparator")),
  tibble(geo = "XK18", value = xk18, year = 2018, name = "Kosova", kind = "kosova_eu"),
  tibble(geo = "XK24", value = xk24, year = 2024, name = "Kosova (ASK)", kind = "kosova_ask")
) |>
  mutate(label = sprintf("%s %.1f ('%02d)", name, value, year %% 100),
         # explicit label rows: bottom holds only the well-spaced EU-27, Turqia,
         # Kosova-ASK; everything else on top (avoids the 19.5/21.6/27.0 pile-up)
         side  = c(AL = 1, EU27_2020 = -1, ME = 1, MK = 1, RS = 1,
                   TR = -1, XK18 = 1, XK24 = -1)[geo])

pB <- ggplot(strip, aes(value, 0)) +
  geom_hline(yintercept = 0, colour = grid, linewidth = 0.5) +
  geom_point(data = ~ filter(.x, kind == "comparator"),
             colour = navy, size = 4, alpha = 0.9) +
  geom_point(data = ~ filter(.x, kind == "ref"), colour = ref_grey, size = 4) +
  geom_point(data = ~ filter(.x, kind == "kosova_eu"), colour = rust, size = 4.6) +
  geom_point(data = ~ filter(.x, kind == "kosova_ask"), shape = 21, colour = rust,
             fill = off, size = 4.6, stroke = 1.2) +
  geom_text_repel(data = ~ filter(.x, side == 1),
                  aes(label = label,
                      colour = ifelse(kind %in% c("kosova_eu", "kosova_ask"), rust,
                                      ifelse(kind == "ref", ref_grey, navy))),
                  family = "ss3", size = 3.1, fontface = "bold", seed = 7,
                  nudge_y = 0.55, direction = "both", ylim = c(0.25, 0.95), xlim = c(0, 46),
                  min.segment.length = 0, segment.color = sub, segment.size = 0.25,
                  box.padding = 0.28, max.overlaps = Inf) +
  geom_text_repel(data = ~ filter(.x, side == -1),
                  aes(label = label,
                      colour = ifelse(kind %in% c("kosova_eu", "kosova_ask"), rust,
                                      ifelse(kind == "ref", ref_grey, navy))),
                  family = "ss3", size = 3.1, fontface = "bold", seed = 7,
                  nudge_y = -0.55, direction = "both", ylim = c(-0.95, -0.25), xlim = c(0, 46),
                  min.segment.length = 0, segment.color = sub, segment.size = 0.25,
                  box.padding = 0.28, max.overlaps = Inf) +
  scale_colour_identity() +
  scale_x_continuous(labels = function(x) paste0(x, "%"), breaks = seq(0, 40, 10),
                     limits = c(0, 46)) +
  scale_y_continuous(limits = c(-1, 1)) +
  labs(title = "The regional spread, latest available year",
       subtitle = "Eurostat EU-SILC, total population; Kosova shown at 2018 (EU-comparable) and 2024 (ASK series)") +
  theme_minimal(base_family = "ss3", base_size = 12) +
  theme(
    plot.title    = element_text(size = 13, colour = ink, face = "bold", margin = margin(b = 1)),
    plot.subtitle = element_text(size = 10, colour = sub, margin = margin(b = 2)),
    axis.title = element_blank(), axis.text.y = element_blank(),
    axis.text.x = element_text(size = 9.5, colour = sub),
    panel.grid = element_blank(),
    plot.margin = margin(4, 12, 0, 6))

# ============================ COMPOSE ==========================================
title_txt    <- "Shtëpi të ftohta"
subtitle_txt <- wrap(sprintf(
  "Share of households unable to keep their home adequately warm. In 2018 — the last EU-comparable measurement — %.1f%% of households in Kosova could not, versus %.1f%% in the EU-27. The regional spread today runs from about %.0f%% (Serbia, %d) to %.0f%% (Shqipëria, %d); ASK's national series puts Kosova at %.1f%% in 2024.",
  xk18, eu18, rs$value, rs$year, al$value, al$year, xk24), 84)
caption_txt <- paste(
  wrap("* The 2019 value (62.6%) is inconsistent with adjacent survey years on both ASK language endpoints; early waves of Kosova's SILC are volatile. Shown as published — see README, Limitations.", 122),
  wrap("Dispersion panel: filled points = Eurostat EU-SILC (ilc_mdes01, latest year per country; Bosnia & Herzegovina publishes no series). Hollow = ASK national series, not Eurostat-validated.", 122),
  "Source: ASK, Anketa mbi të Ardhurat dhe Kushtet e Jetesës (SILC); Eurostat EU-SILC  |  Analysis: Plator Krasniqi",
  sep = "\n")

fig <- (pA / pB) + plot_layout(heights = c(1, 0.52)) +
  plot_annotation(
    title = title_txt, subtitle = subtitle_txt, caption = caption_txt,
    theme = theme(
      plot.title    = element_text(family = "ss3", face = "bold", size = 22, colour = ink,
                                   margin = margin(b = 4)),
      plot.subtitle = element_text(family = "ss3", size = 11, colour = sub, lineheight = 1.15,
                                   margin = margin(b = 8)),
      plot.caption  = element_text(family = "ss3", size = 8.5, colour = sub, hjust = 0,
                                   lineheight = 1.3, margin = margin(t = 10)),
      plot.margin   = margin(18, 20, 14, 20)))

# Render once at full size; downscale the raster for the 1200px LinkedIn version
# (re-rendering smaller rescales showtext typography).
hi <- file.path(out_dir, "energy_poverty_keep_warm.png")
ggsave(hi, fig, width = 2000, height = 2600, units = "px", dpi = 300, bg = off)
magick::image_write(magick::image_resize(magick::image_read(hi), "1200x"),
                    file.path(out_dir, "energy_poverty_keep_warm_linkedin_1200.png"))

cat(sprintf("Pinned: XK18=%.1f EU27_18=%.1f RS=%.1f('%d) AL=%.1f('%d) XK24(ASK)=%.1f\n",
            xk18, eu18, rs$value, rs$year, al$value, al$year, xk24))
cat("Saved:", hi, "+ 1200px downscale\n")
