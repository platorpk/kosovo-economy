# ==============================================================================
# 03_figure.R  —  Figures (house style: navy / rust, Source Sans 3)
#   Panel A: choropleth of municipal fixed download speed (2025) — LinkedIn lead
#   Panel B: fixed speed vs nighttime-lights radiance, by municipality (repo)
#   + combined two-panel figure (repo)
# Language is neutral descriptive geography only (no causal wording anywhere).
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(sf); library(ggplot2); library(ggrepel)
  library(showtext); library(patchwork); library(scales)
}))

proj    <- "C:/Users/plato/Documents/kosovo-economy/ookla-digital-divide"
out_dir <- file.path(proj, "output"); dir.create(out_dir, showWarnings = FALSE)
font_add_google("Source Sans 3", "ss3"); showtext_auto(); showtext_opts(dpi = 300)

# --- palette ------------------------------------------------------------------
navy <- "#1A4E8A"; rust <- "#C0552E"
mid  <- "#E7E7E3"; ns <- "#C4C4BD"                # gray midpoint / low-sample fill
ink  <- "#23282D"; sub <- "#5C636B"; grid <- "#E4E4E0"

S      <- readRDS(file.path(proj, "data/processed/municipal_data_2025.rds"))
md     <- S$muni; natl <- S$national
med_dl <- median(md$dl_mbps[md$adequate], na.rm = TRUE)     # diverging midpoint
md     <- md |> mutate(dl_fill = ifelse(adequate, dl_mbps, NA_real_))

city_names <- c("Prishtina","Prizren","Peja","Gjakova","Ferizaj","Gjilan","Mitrovica")
cities <- md |> filter(muni %in% city_names) |>
  st_point_on_surface() |> mutate(x = st_coordinates(geometry)[,1],
                                  y = st_coordinates(geometry)[,2]) |> st_drop_geometry()
scat <- st_drop_geometry(md) |> filter(adequate) |> mutate(lr = log10(radiance_tw))
lab_pts <- scat |> filter(muni %in% c("Prishtina","Fushë Kosovë","Gjilan","Ferizaj",
  "Peja","Graçanica","Mitrovica e Veriut","Zubin Potok","Leposaviq","Dragash"))

# --- Panel A base (map) -------------------------------------------------------
pA_base <- ggplot(md) +
  geom_sf(aes(fill = dl_fill), colour = "white", linewidth = 0.28) +
  scale_fill_gradient2(low = rust, mid = mid, high = navy, midpoint = med_dl,
    na.value = ns, name = "Fixed download (Mbps)",
    breaks = c(40, 70, 100, 130), labels = c("40","70","100","130"),
    guide = guide_colourbar(barheight = unit(7, "pt"), barwidth = unit(96, "pt"),
      direction = "horizontal", title.position = "top", title.hjust = 0,
      ticks.colour = "white", frame.colour = NA)) +
  geom_text_repel(data = cities, aes(x, y, label = muni), family = "ss3",
    fontface = "bold", size = 2.7, colour = ink, bg.color = "white", bg.r = 0.14,
    min.segment.length = 0.3, segment.color = sub, segment.size = 0.25,
    box.padding = 0.35, seed = 42, max.overlaps = Inf) +
  coord_sf(expand = FALSE) +
  theme_void(base_family = "ss3") +
  theme(legend.title = element_text(size = 8.5, colour = sub),
        legend.text = element_text(size = 8, colour = sub),
        legend.position = "bottom", legend.margin = margin(t = 2, b = 0),
        legend.box.spacing = unit(2, "pt"), plot.margin = margin(4, 4, 4, 4))

# --- Panel B base (scatter) ---------------------------------------------------
pB_base <- ggplot(scat, aes(lr, dl_mbps)) +
  geom_smooth(method = "lm", se = FALSE, colour = rust, linewidth = 0.7,
              linetype = "dashed", formula = y ~ x) +
  geom_point(colour = navy, size = 2.4, alpha = 0.85) +
  geom_text_repel(data = lab_pts, aes(label = muni), family = "ss3", size = 2.6,
    colour = ink, box.padding = 0.4, point.padding = 0.2, min.segment.length = 0,
    segment.color = sub, segment.size = 0.25, seed = 42, max.overlaps = Inf) +
  annotate("text", x = log10(4.4), y = 128, hjust = 0, family = "ss3", size = 3.1,
    colour = sub, label = sprintf("Spearman ρ = %.2f", natl$rho_tw)) +
  scale_x_continuous(breaks = log10(c(5,10,20,50)), labels = c("5","10","20","50"),
                     name = "Nighttime lights · radiance (log scale)") +
  scale_y_continuous(name = "Fixed download (Mbps)", limits = c(20, 132),
                     breaks = c(30, 60, 90, 120)) +
  theme_minimal(base_family = "ss3", base_size = 12) +
  theme(axis.title = element_text(size = 9.5, colour = sub),
        axis.text = element_text(size = 9, colour = sub),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = grid, linewidth = 0.3),
        plot.margin = margin(4, 8, 4, 6))

# --- captions (house style) ---------------------------------------------------
wrap <- function(x, w) paste(strwrap(x, width = w), collapse = "\n")   # ggplot won't auto-wrap
mob_note <- sprintf("Mobile (2025, national): ~%.0f Mbps average download from %s tests — municipal mobile samples are too sparse to map reliably.",
  natl$mobile_dl, format(natl$mobile_tests, big.mark = ","))
src_map <- sprintf("Source: Ookla Speedtest Open Data (fixed tiles, pooled 2025 Q1–Q4) · municipal boundaries geoBoundaries ADM2. Test-weighted mean download; map diverges at the municipal median (%d Mbps). Novobërdë shown grey (fewer than 50 tests). Author: Plator Krasniqi.",
  round(med_dl))
src_scat <- "Source: Ookla Speedtest Open Data (fixed tiles, pooled 2025 Q1–Q4) · nighttime lights VIIRS 2024 (NOAA/EOG) · boundaries geoBoundaries ADM2. Radiance sampled at tested tiles (test-weighted). Author: Plator Krasniqi."
src_full <- sprintf("Sources: Ookla for Good — Speedtest Open Data (fixed tiles, 2025 Q1–Q4); boundaries geoBoundaries ADM2 (38 municipalities); nighttime lights VIIRS 2024 (NOAA/EOG). Municipal values are test-weighted mean download over pooled 2025 tiles; map diverges at the municipal median (%d Mbps). Novobërdë shown grey (fewer than 50 tests). Author: Plator Krasniqi.",
  round(med_dl))

titleA <- "Kosova's broadband divide: fixed download speeds by municipality, 2025"
subA   <- "Mean fixed download speed, Mbps (test-weighted, pooled 2025Q1–Q4)"
titleB <- "Fixed download speed vs nighttime-lights radiance, by municipality"

th_title <- function(ts = 15) theme(
  plot.title    = element_text(family = "ss3", face = "bold", size = ts, colour = ink),
  plot.subtitle = element_text(family = "ss3", size = 10.5, colour = sub, margin = margin(b = 6)),
  plot.caption  = element_text(family = "ss3", size = 7.6, colour = sub, hjust = 0,
                               lineheight = 1.15, margin = margin(t = 8)))

# --- Standalone Panel A (LinkedIn lead) ---------------------------------------
pA_final <- pA_base +
  labs(title = titleA, subtitle = subA,
       caption = paste0(wrap(mob_note, 118), "\n", wrap(src_map, 118))) +
  th_title(14.5) + theme(plot.margin = margin(14, 14, 10, 14))
ggsave(file.path(out_dir, "panelA_choropleth_2025.png"), pA_final,
       width = 8, height = 9, dpi = 300, bg = "white")

# --- Standalone Panel B (repo) ------------------------------------------------
pB_final <- pB_base +
  labs(title = titleB, caption = wrap(src_scat, 96)) +
  th_title(13.5) + theme(plot.margin = margin(14, 12, 10, 12))
ggsave(file.path(out_dir, "panelB_scatter_2025.png"), pB_final,
       width = 7.2, height = 6.6, dpi = 300, bg = "white")

# --- Combined two-panel figure (repo) -----------------------------------------
pan_sub <- function(txt) theme(plot.subtitle = element_text(size = 11, colour = ink,
  face = "bold", margin = margin(b = 4)))
pA_panel <- pA_base + labs(subtitle = "Download speed by municipality") + pan_sub()
pB_panel <- pB_base + labs(subtitle = "Speed vs nighttime-lights radiance") + pan_sub()

fig <- (pA_panel | pB_panel) + plot_layout(widths = c(1, 0.92)) +
  plot_annotation(
    title    = titleA,
    subtitle = sprintf("Mean fixed download (test-weighted, pooled 2025Q1–Q4); %.1f× gap between the fastest and slowest municipality", natl$spread_ratio),
    caption  = paste0(wrap(mob_note, 200), "\n", wrap(src_full, 200)),
    theme = theme(
      plot.title    = element_text(family = "ss3", face = "bold", size = 15.5, colour = ink),
      plot.subtitle = element_text(family = "ss3", size = 10.5, colour = sub, margin = margin(b = 6)),
      plot.caption  = element_text(family = "ss3", size = 7.6, colour = sub, hjust = 0,
                                   lineheight = 1.15, margin = margin(t = 8)),
      plot.margin   = margin(12, 12, 10, 12)))
ggsave(file.path(out_dir, "kosovo_digital_divide_2025.png"), fig,
       width = 12, height = 6.9, dpi = 300, bg = "white")

cat("Saved figures to", out_dir, "\n")
