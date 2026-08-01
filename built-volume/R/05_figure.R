# ==============================================================================
# 05_figure.R  —  "Vëllimi i ndërtuar për banor" / Built volume per resident
# Vertically stacked composition (patchwork):
#   TOP    : choropleth of built volume per resident, 2024 population
#            (off-white -> navy; northern four greyed — estimated denominator).
#   BOTTOM : height distribution of the underlying structures, disclosing that
#            about two fifths sit under 2.5 m and are largely ancillary.
# House style: navy/rust, Source Sans 3 (showtext). Descriptive language only.
# Run from the piece root:  Rscript R/05_figure.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(arrow); library(sf)
  library(ggplot2); library(ggrepel); library(showtext); library(patchwork)
}))
source("C:/Users/plato/Documents/kosovo-economy/built-volume/R/01_functions.R")
sf_use_s2(FALSE)
font_add_google("Source Sans 3", "ss3"); showtext_auto(); showtext_opts(dpi = 300)

navy <- "#1A4E8A"; rust <- "#C0552E"; off <- "#F7F5F2"
grey_na <- "#C4C4BD"; ink <- "#23282D"; sub <- "#5C636B"; grid <- "#E4E4E0"
wrap <- function(x, w) paste(strwrap(x, width = w), collapse = "\n")

m  <- read_csv(file.path(PROJ, "data/processed/municipal_built_volume.csv"), show_col_types = FALSE)
lk <- read_csv(file.path(PROJ, "data/lookup_municipalities.csv"), show_col_types = FALSE)
b  <- read_parquet(file.path(PROJ, "data/processed/buildings_kosova.parquet"))

# --- headline numbers, all computed from the data ----------------------------
natl_vol  <- sum(m$volume_m3); natl_pop <- sum(m$pop_2024)
natl_vpr  <- natl_vol / natl_pop
enum      <- m |> filter(!is_north)                 # enumerated denominators only
hi <- enum |> slice_max(vol_per_resident, n = 1)
lo <- enum |> slice_min(vol_per_resident, n = 1)
pri <- m |> filter(muni == "Prishtina")
rho <- cor(m$vol_per_resident, m$vol_per_resident_25, method = "spearman")
med_h <- median(b$height); u25 <- 100 * mean(b$height < 2.5)

# --- geometry -----------------------------------------------------------------
adm <- st_read(file.path(PROJ, "data/raw/geoBoundaries-XKX-ADM2.geojson"), quiet = TRUE) |>
  st_make_valid() |>
  left_join(lk |> select(shapeName, muni), by = "shapeName") |>
  left_join(m,  by = "muni") |>
  mutate(fill_val = ifelse(is_north, NA_real_, vol_per_resident))
stopifnot(nrow(adm) == 38, !any(is.na(adm$muni)))

cities <- c("Prishtina","Prizren","Peja","Gjakova","Mitrovica","Ferizaj","Gjilan")
cl <- adm |> filter(muni %in% cities) |> st_point_on_surface() |>
  mutate(x = st_coordinates(geometry)[,1], y = st_coordinates(geometry)[,2]) |>
  st_drop_geometry()

# ============================ TOP: MAP =========================================
pMap <- ggplot(adm) +
  geom_sf(aes(fill = fill_val), colour = "white", linewidth = 0.3) +
  scale_fill_gradient(
    low = off, high = navy, na.value = grey_na, trans = "sqrt",
    breaks = c(200, 300, 400, 600, 800), labels = c("200","300","400","600","800"),
    limits = c(150, 860),
    name = "Built volume per resident (m³), square-root colour scale",
    guide = guide_colourbar(barheight = unit(9, "pt"), barwidth = unit(185, "pt"),
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
    plot.margin = margin(2, 8, 4, 8))

# ============================ BOTTOM: HEIGHT DISTRIBUTION ======================
pH <- ggplot(b |> filter(height <= 15), aes(height)) +
  geom_histogram(binwidth = 0.25, fill = navy, alpha = 0.85) +
  geom_vline(xintercept = 2.5, colour = rust, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = med_h, colour = ink, linewidth = 0.5) +
  annotate("text", x = med_h + 0.3, y = Inf, vjust = 1.4, hjust = 0, family = "ss3",
           size = 3.2, colour = ink, label = sprintf("median %.2f m", med_h)) +
  annotate("text", x = 2.5 - 0.3, y = Inf, vjust = 3.1, hjust = 1, family = "ss3",
           size = 3.2, colour = rust,
           label = sprintf("%.0f%% below 2.5 m", u25)) +
  scale_x_continuous(breaks = seq(0, 15, 2.5), labels = function(x) paste0(x, " m")) +
  # headroom so the two annotations sit clear of the bars
  scale_y_continuous(labels = function(y) format(y/1000, big.mark = ","),
                     name = "thousands of structures",
                     expand = expansion(mult = c(0, 0.20))) +
  labs(title = "What is being measured",
       subtitle = sprintf("Height of all %s structures included, truncated at 15 m",
                          format(nrow(b), big.mark = ","))) +
  theme_minimal(base_family = "ss3", base_size = 12) +
  theme(
    plot.title    = element_text(size = 13, colour = ink, face = "bold", margin = margin(b = 1)),
    plot.subtitle = element_text(size = 10, colour = sub, margin = margin(b = 8)),
    axis.title.x  = element_blank(),
    axis.title.y  = element_text(size = 9.5, colour = sub),
    axis.text     = element_text(size = 9.5, colour = sub),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = grid, linewidth = 0.3),
    plot.margin = margin(6, 10, 4, 6))

# ============================ COMPOSE ==========================================
# Lead on the gradient, not on the top-ranked municipality: that figure rests on
# a very small denominator and reflects structure counts rather than living space
# (see README, Key results). The full range is stated in the README instead.
core <- m |> filter(muni %in% c("Prishtina", "Ferizaj", "Prizren")) |>
  arrange(vol_per_resident)
stopifnot(nrow(core) == 3)
subtitle_txt <- wrap(sprintf(
  "Building footprints times modelled height, divided by 2024 census population. Kosova holds about %.0f m³ of built structure per resident, and the figure is lowest where most people live — %s %.0f m³, %s %.0f m³, %s %.0f m³. It runs higher across small peripheral municipalities, where the total reflects many small structures per person rather than more living space.",
  natl_vpr, core$muni[1], core$vol_per_resident[1], core$muni[2], core$vol_per_resident[2],
  core$muni[3], core$vol_per_resident[3]), 84)

caption_txt <- paste(
  wrap("Grey: the four northern municipalities (Mitrovica e Veriut, Leposaviq, Zveçan, Zubin Potok). Their buildings are satellite-derived and unaffected by the census boycott, but their 2024 population is an ASK estimate — a real numerator over an estimated denominator — so the ratio is not comparable and is not shown.", 122),
  wrap(sprintf("Buildings reflect roughly 2019 imagery; population is 2024, so construction since 2019 is missing from the numerator while its residents are counted — this understates volume per resident, unevenly across municipalities. Ranking is stable if only structures of 2.5 m or more are counted (Spearman ρ = %.3f).", rho), 122),
  wrap("Building data © GlobalBuildingAtlas contributors (Zhu et al. 2025, TUM), ODbL, derived from Microsoft Building Footprints and OpenStreetMap. Population: ASK Census 2024  |  Analysis: Plator Krasniqi", 122),
  sep = "\n")

fig <- (pMap / pH) + plot_layout(heights = c(1, 0.46)) +
  plot_annotation(
    title = "Vëllimi i ndërtuar për banor",
    subtitle = subtitle_txt, caption = caption_txt,
    theme = theme(
      plot.title    = element_text(family = "ss3", face = "bold", size = 22, colour = ink,
                                   margin = margin(b = 4)),
      plot.subtitle = element_text(family = "ss3", size = 11, colour = sub, lineheight = 1.15,
                                   margin = margin(b = 8)),
      plot.caption  = element_text(family = "ss3", size = 8, colour = sub, hjust = 0,
                                   lineheight = 1.3, margin = margin(t = 10)),
      plot.margin   = margin(18, 20, 14, 20)))

hi_png <- file.path(PROJ, "output/built_volume_per_resident.png")
ggsave(hi_png, fig, width = 2000, height = 3200, units = "px", dpi = 300, bg = off)
magick::image_write(magick::image_resize(magick::image_read(hi_png), "1200x"),
                    file.path(PROJ, "output/built_volume_per_resident_linkedin_1200.png"))

cat(sprintf("national: %.0f m3/resident | %s highest %.0f (%s) | lowest %.0f (%s) | Prishtina %.0f\n",
            natl_vpr, "enumerated:", hi$vol_per_resident, hi$muni,
            lo$vol_per_resident, lo$muni, pri$vol_per_resident))
cat(sprintf("median height %.2f m | %.1f%% below 2.5 m | Spearman rho %.3f\n", med_h, u25, rho))
cat("saved figures to", file.path(PROJ, "output"), "\n")
