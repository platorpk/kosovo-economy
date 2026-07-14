# ==============================================================================
# 05_figure.R  —  "Shtëpitë bosh të Kosovës" / Kosova's empty homes
#   Main: choropleth of vacant-dwelling share by municipality, 2024
#         (sequential off-white -> rust; northern four greyed).
#   Inset (patchwork, bottom-right): population change 2011-24 vs vacancy 2024,
#         excluding the northern four and Serb-majority southern municipalities.
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

# --- city anchors for orientation (Ferizaj/Gjilan omitted: under the inset) ----
cities <- c("Prishtina","Prizren","Peja","Gjakova","Mitrovica")
cl <- S |> filter(muni %in% cities) |> st_point_on_surface() |>
  mutate(x = st_coordinates(geometry)[,1], y = st_coordinates(geometry)[,2]) |>
  st_drop_geometry()

# ============================ MAIN MAP =========================================
subtitle_txt <- wrap(sprintf(
  "Share of conventional dwellings vacant, by municipality, 2024 (%.0f%% nationally). Empty homes nearly doubled since 2011 — %s to %s — as the population fell about 8%%, and 25 of the 34 comparable municipalities shrank.",
  nat_share, format(nat_vac_2011, big.mark = ","), format(nat_vac_2024, big.mark = ",")), 78)

caption_txt <- paste(
  wrap("Grey: the four northern municipalities (Mitrovica e Veriut, Leposaviq, Zveçan, Zubin Potok) — 2024 census figures are ASK estimates (2024 boycott).", 118),
  wrap("Inset excludes those four and the Serb-majority southern municipalities (Graçanica, Kllokot, Partesh, Ranillug, Shtërpca), whose 2011 baselines are distorted by the 2011 boycott.", 118),
  "Source: ASK, Census 2011 & 2024  |  Analysis: Plator Krasniqi", sep = "\n")

pMap <- ggplot(S) +
  geom_sf(aes(fill = map_fill), colour = "white", linewidth = 0.3) +
  scale_fill_gradient(
    low = off, high = rust, na.value = grey_na,
    limits = c(5, 45), breaks = c(10, 20, 30, 40), labels = c("10%","20%","30%","40%"),
    name = "Vacant dwellings, % of stock (2024)",
    guide = guide_colourbar(barheight = unit(8, "pt"), barwidth = unit(150, "pt"),
      direction = "horizontal", title.position = "top", title.hjust = 0.5,
      ticks.colour = "white", frame.colour = NA)) +
  geom_text_repel(data = cl, aes(x, y, label = muni), family = "ss3",
    fontface = "bold", size = 3.0, colour = ink, bg.color = "white", bg.r = 0.16,
    min.segment.length = 0.4, segment.color = sub, segment.size = 0.25,
    box.padding = 0.3, seed = 42, max.overlaps = Inf) +
  coord_sf(expand = FALSE) +
  labs(title = "Shtëpitë bosh të Kosovës", subtitle = subtitle_txt, caption = caption_txt) +
  theme_void(base_family = "ss3") +
  theme(
    plot.title    = element_text(family = "ss3", face = "bold", size = 20, colour = ink,
                                 margin = margin(b = 3)),
    plot.subtitle = element_text(family = "ss3", size = 10.5, colour = sub, lineheight = 1.15,
                                 margin = margin(b = 4)),
    plot.caption  = element_text(family = "ss3", size = 8, colour = sub, hjust = 0,
                                 lineheight = 1.25, margin = margin(t = 6)),
    plot.title.position = "plot", plot.caption.position = "plot",
    legend.position = "bottom", legend.justification = "center",
    legend.title = element_text(size = 9, colour = sub),
    legend.text  = element_text(size = 8.5, colour = sub),
    legend.margin = margin(t = 2, b = 0),
    plot.margin  = margin(16, 18, 10, 18))

# ============================ INSET SCATTER ====================================
sc <- S |> st_drop_geometry() |> filter(in_scatter)
lab <- sc |> filter(muni %in% c("Kamenica","Junik","Deçan","Fushë Kosova","Prishtina"))
# manual nudges (data units: x = % pop change, y = % vacant) to separate the tight
# Kamenica/Junik/Deçan cluster and pull Fushë Kosova's label off the right edge
nx <- c("Kamenica" = 3, "Junik" = 20, "Deçan" = 3, "Fushë Kosova" = -26, "Prishtina" = 16)
ny <- c("Kamenica" = 8, "Junik" = 2, "Deçan" = -8, "Fushë Kosova" = 2, "Prishtina" = -8)

pSc <- ggplot(sc, aes(pop_change_pct, vac_share_2024)) +
  geom_vline(xintercept = 0, colour = "#C4C7C2", linewidth = 0.4, linetype = "dashed") +
  geom_point(colour = navy, size = 2.6, alpha = 0.85) +
  geom_text_repel(data = lab, aes(label = muni), family = "ss3", size = 2.9,
    fontface = "bold", colour = rust, box.padding = 0.5, point.padding = 0.3,
    nudge_x = nx[lab$muni], nudge_y = ny[lab$muni], force = 0.5, direction = "both",
    min.segment.length = 0, segment.color = sub, segment.size = 0.3,
    seed = 42, max.overlaps = Inf) +
  scale_x_continuous(breaks = c(-25, 0, 50), labels = c("−25%", "0", "+50%"),
                     limits = c(-42, 90)) +
  scale_y_continuous(labels = function(y) paste0(y, "%"), breaks = c(10, 20, 30, 40),
                     limits = c(5, 45)) +
  labs(title = "Population change vs vacant share",
       subtitle = "By municipality, 2011–2024 (inset set, n = 29)",
       x = "Population change, 2011–24", y = "Vacant, 2024") +
  theme_minimal(base_family = "ss3", base_size = 11) +
  theme(
    plot.title    = element_text(size = 11, colour = ink, face = "bold", margin = margin(b = 1)),
    plot.subtitle = element_text(size = 8.7, colour = sub, margin = margin(b = 6)),
    axis.title    = element_text(size = 8.6, colour = sub),
    axis.text     = element_text(size = 8.4, colour = sub),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = grid, linewidth = 0.3),
    plot.background  = element_rect(fill = "white", colour = "#D5D7D2", linewidth = 0.6),
    plot.margin  = margin(10, 12, 8, 10))

# ============================ COMPOSE ==========================================
# Inset anchored to the map panel, over Kosova's south-east corner (bottom-right).
fig <- pMap + inset_element(pSc, left = 0.55, bottom = 0.00, right = 1.02, top = 0.42,
                            align_to = "panel")

# Render once at full size; downscale the raster for the 1200px LinkedIn version
# so layout and typography stay identical (re-rendering smaller rescales showtext).
save_fig <- function(plot, stem, w = 2000, h = 2500) {
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
