# ==============================================================================
# 05_figure.R  —  "Shtëpitë bosh të Kosovës" / Kosova's empty homes
# Vertically stacked composition (patchwork), so nothing overlaps the map:
#   TOP    : choropleth of vacant-dwelling share by municipality, 2024
#            (sequential off-white -> rust; northern four greyed), legend beneath.
#   BOTTOM : full-width scatter of population change 2011-24 vs 2024 vacancy,
#            excluding the northern four and Serb-majority southern municipalities.
# House style: navy/rust, Source Sans 3 (showtext). Descriptive language only.
# Run from the piece root:  Rscript R/05_figure.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(sf); library(ggplot2); library(ggrepel)
  library(showtext); library(patchwork); library(scales)
}))

proj    <- "C:/Users/plato/Documents/kosovo-economy/census-vacancy"
out_dir <- file.path(proj, "output"); dir.create(out_dir, showWarnings = FALSE)
font_add_google("Source Sans 3", "ss3"); showtext_auto(); showtext_opts(dpi = 300)

navy <- "#1A4E8A"; rust <- "#C0552E"; off <- "#F7F5F2"
grey_na <- "#C4C4BD"; ink <- "#23282D"; sub <- "#5C636B"; grid <- "#E4E4E0"

wrap <- function(x, w) paste(strwrap(x, width = w), collapse = "\n")   # ggplot won't auto-wrap

S <- readRDS(file.path(proj, "data/processed/analysis_municipalities.rds"))
S <- S |> mutate(map_fill = ifelse(is_north, NA_real_, vac_share_2024))

# national figures (from the data)
nat_vac_2024 <- sum(S$vacant_2024)
nat_vac_2011 <- sum(S$vacant_2011, na.rm = TRUE)
nat_share    <- 100 * nat_vac_2024 / sum(S$conventional_2024)

# --- city anchors for orientation (map is now unobstructed) --------------------
cities <- c("Prishtina","Prizren","Peja","Gjakova","Mitrovica","Ferizaj","Gjilan")
cl <- S |> filter(muni %in% cities) |> st_point_on_surface() |>
  mutate(x = st_coordinates(geometry)[,1], y = st_coordinates(geometry)[,2]) |>
  st_drop_geometry()

# --- text (subtitle + headline numbers are approved; do not reword) ------------
title_txt    <- "Shtëpitë bosh të Kosovës"
subtitle_txt <- wrap(sprintf(
  "Share of conventional dwellings vacant, by municipality, 2024 (%.0f%% nationally). Empty homes nearly doubled since 2011 — %s to %s — as the population fell about 8%%, and 25 of the 34 comparable municipalities shrank.",
  nat_share, format(nat_vac_2011, big.mark = ","), format(nat_vac_2024, big.mark = ",")), 82)
caption_txt <- paste(
  wrap("Grey: the four northern municipalities (Mitrovica e Veriut, Leposaviq, Zveçan, Zubin Potok) — 2024 census figures are ASK estimates (2024 boycott).", 120),
  wrap("Scatter excludes those four and the Serb-majority southern municipalities (Graçanica, Kllokot, Partesh, Ranillug, Shtërpca), whose 2011 baselines are distorted by the 2011 boycott.", 120),
  "Source: ASK, Census 2011 & 2024  |  Analysis: Plator Krasniqi", sep = "\n")

# ============================ TOP: MAP =========================================
pMap <- ggplot(S) +
  geom_sf(aes(fill = map_fill), colour = "white", linewidth = 0.3) +
  scale_fill_gradient(
    low = off, high = rust, na.value = grey_na,
    limits = c(5, 45), breaks = c(10, 20, 30, 40), labels = c("10%","20%","30%","40%"),
    name = "Vacant dwellings, % of stock (2024)",
    guide = guide_colourbar(barheight = unit(9, "pt"), barwidth = unit(170, "pt"),
      direction = "horizontal", title.position = "top", title.hjust = 0.5,
      ticks.colour = "white", frame.colour = NA)) +
  geom_text_repel(data = cl, aes(x, y, label = muni), family = "ss3",
    fontface = "bold", size = 3.4, colour = ink, bg.color = "white", bg.r = 0.16,
    min.segment.length = 0.4, segment.color = sub, segment.size = 0.25,
    box.padding = 0.3, seed = 42, max.overlaps = Inf) +
  coord_sf(expand = FALSE) +
  theme_void(base_family = "ss3") +
  theme(
    legend.position = "bottom", legend.justification = "center",
    legend.title = element_text(size = 10, colour = sub),
    legend.text  = element_text(size = 9.5, colour = sub),
    legend.margin = margin(t = 4, b = 2),
    plot.margin  = margin(2, 8, 4, 8))

# ============================ BOTTOM: SCATTER ==================================
sc  <- S |> st_drop_geometry() |> filter(in_scatter)
# Five labels placed OUTSIDE the dense cluster (x in [-35,0], y in [25,42]): the
# cluster is too tight for ggrepel alone to exit (it settles into interior gaps),
# so we seed each label toward an open target and let ggrepel resolve any residual
# collision and draw a thin connector.
tgt_x <- c("Kamenica" = -30, "Junik" = -45, "Deçan" = -41, "Prishtina" = 26, "Fushë Kosova" = 66)
tgt_y <- c("Kamenica" =  45, "Junik" =  33, "Deçan" =  26, "Prishtina" = 34, "Fushë Kosova" = 38)
lab <- sc |> filter(muni %in% names(tgt_x)) |>
  mutate(nx = tgt_x[muni] - pop_change_pct, ny = tgt_y[muni] - vac_share_2024)

pSc <- ggplot(sc, aes(pop_change_pct, vac_share_2024)) +
  geom_vline(xintercept = 0, colour = "#C4C7C2", linewidth = 0.5, linetype = "dashed") +
  geom_point(colour = navy, size = 3.0, alpha = 0.85) +
  geom_text_repel(data = lab, aes(label = muni), family = "ss3", size = 3.5,
    fontface = "bold", colour = rust, seed = 42, min.segment.length = 0,
    box.padding = 0.6, point.padding = 0.4, force = 0.3,
    nudge_x = lab$nx, nudge_y = lab$ny,
    max.overlaps = Inf, segment.color = sub, segment.size = 0.3,
    xlim = c(-47, 92), ylim = c(6, 47)) +
  scale_x_continuous(breaks = c(-25, 0, 25, 50, 75),
                     labels = c("−25%","0","+25%","+50%","+75%"), limits = c(-47, 92)) +
  scale_y_continuous(labels = function(y) paste0(y, "%"), breaks = c(10, 20, 30, 40),
                     limits = c(6, 47)) +
  labs(title = "Population change vs vacant share",
       subtitle = "By municipality, 2011–2024 (29 municipalities with comparable data)",
       x = "Population change, 2011–24", y = "Vacant, 2024") +
  theme_minimal(base_family = "ss3", base_size = 12) +
  theme(
    plot.title    = element_text(size = 13, colour = ink, face = "bold", margin = margin(b = 1)),
    plot.subtitle = element_text(size = 10, colour = sub, margin = margin(b = 8)),
    axis.title    = element_text(size = 10, colour = sub),
    axis.text     = element_text(size = 9.5, colour = sub),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = grid, linewidth = 0.3),
    plot.margin  = margin(6, 10, 4, 6))

# ============================ COMPOSE (vertical stack) =========================
fig <- (pMap / pSc) + plot_layout(heights = c(1, 0.52)) +
  plot_annotation(
    title = title_txt, subtitle = subtitle_txt, caption = caption_txt,
    theme = theme(
      plot.title    = element_text(family = "ss3", face = "bold", size = 22, colour = ink,
                                   margin = margin(b = 4)),
      plot.subtitle = element_text(family = "ss3", size = 11, colour = sub, lineheight = 1.15,
                                   margin = margin(b = 6)),
      plot.caption  = element_text(family = "ss3", size = 8.5, colour = sub, hjust = 0,
                                   lineheight = 1.3, margin = margin(t = 10)),
      plot.margin   = margin(18, 20, 14, 20)))

# Render once at full size; downscale the raster for the 1200px LinkedIn version
# so layout and typography stay identical (re-rendering smaller rescales showtext).
save_fig <- function(plot, stem, w = 2000, h = 3400) {
  hi <- file.path(out_dir, paste0(stem, ".png"))
  ggsave(hi, plot, width = w, height = h, units = "px", dpi = 300, bg = off)
  magick::image_write(magick::image_resize(magick::image_read(hi), "1200x"),
                      file.path(out_dir, paste0(stem, "_linkedin_1200.png")))
}
save_fig(fig, "census_vacancy_2024")

cat(sprintf("National vacant 2024 = %s (%.1f%% of stock); 2011 = %s\n",
    format(nat_vac_2024, big.mark = ","), nat_share, format(nat_vac_2011, big.mark = ",")))
cat("Scatter municipalities:", nrow(sc), " | labelled:", paste(lab$muni, collapse = ", "), "\n")
cat("Saved figures to", out_dir, "\n")
