# ==============================================================================
# 06_figure.R  —  "All roads lead to Prishtina"
# Draws every directed network edge that carries at least one modelled route to
# Prishtina, line width by the number of routes on the edge.
# Reads:  data/processed/flows_kosova.rds, figures_kosova.json
# Writes: output/roads_to_prishtina_kosova.png               (2000 px wide, gitignored)
#         output/roads_to_prishtina_kosova_linkedin_1200.png (raster downscale)
# Concept notes:
#  - The figure carries no statistic. The numbers in its text are the grid
#    spacing and the extract date, both built from the pipeline's constants.
#  - No boundary is drawn. Prishtina is the only label. The extent of the lines
#    follows the polygon used to place the grid origins.
#  - Line width is a square-root scale of routes per edge and colour a log scale
#    up to a cap: ANALYST JUDGEMENT, chosen for legibility; drawing choices, not
#    measurements.
# Run from the piece root:  Rscript R/06_figure.R
# ==============================================================================
t0 <- proc.time()
source("R/01_functions.R")
suppressWarnings(suppressMessages({ library(ggplot2); library(showtext) }))
font_add_google("Source Sans 3", "ss3"); showtext_auto(); showtext_opts(dpi = 300)

navy <- "#1A4E8A"; rust <- "#C0552E"; off <- "#F7F5F2"
grey_na <- "#C4C4BD"; ink <- "#23282D"; sub <- "#5C636B"; grid <- "#E4E4E0"

fl  <- readRDS(file.path(PROC, sprintf("flows_%s.rds", TAG)))
fig <- jsonlite::read_json(file.path(PROC, sprintf("figures_%s.json", TAG)), simplifyVector = TRUE)
seg <- fl$seg[order(fl$seg$flow), ]            # heaviest edges drawn last, on top
dest <- fl$dest

# guards: the flows on disk are the ones the JSON describes, and the gate passed
stopifnot(fig$extract_date == EXTRACT_DATE, fig$grid_km == GRID_KM)
stopifnot(nrow(seg) == fig$n_edges_with_route, max(seg$flow) == fig$max_flow)
stopifnot(fig$max_flow <= fig$n_routed - fig$n_at_dest)
stopifnot(all(fig$benchmark$pass))
stopifnot(all(is.finite(c(seg$x1, seg$y1, seg$x2, seg$y2))), all(seg$flow >= 1))

title_txt    <- "All roads lead to Prishtina"
subtitle_txt <- sprintf(
  "Modelled fastest driving routes to Prishtina from a %s km grid of points across Kosova",
  format(fig$grid_km))
caption_txt <- paste(
  wrap("Line width shows how many routes share a road; origins are evenly spaced points, not people or traffic. Fastest routes under assumed car speeds per road class, ignoring traffic.", 118),
  sprintf("Source: © OpenStreetMap contributors (ODbL) via Geofabrik (extract of %s)  |  Analysis: Plator Krasniqi",
          extract_date_txt(short = TRUE)), sep = "\n")

# Opaque colours only. Light edges are drawn in navy pre-mixed with the
# background (LIGHT_MIX navy : rest background) instead of with transparency:
# with alpha < 1 the round caps of consecutive edges overlap and add up, so a
# road digitised in many short pieces would come out darker than one digitised
# in few long ones. Draw order is ascending by flow, heaviest last. Colour runs
# from the light mix (one route) to full navy at FULL_NAVY_AT routes and stays
# navy above it.
navy_light <- grDevices::rgb(grDevices::colorRamp(c(off, navy))(LIGHT_MIX), maxColorValue = 255)
stopifnot(!is.unsorted(seg$flow))

# Canvas: the panel is fitted to the lines with a small pad, and the image height
# follows from their aspect ratio, so no band is left above or below.
W_PX <- 2000; SIDE_PT <- 12; TEXT_PX <- 500    # TEXT_PX: title + subtitle + caption + margins
PAD  <- 0.012
xr <- range(c(seg$x1, seg$x2)); yr <- range(c(seg$y1, seg$y2))
xl <- xr + c(-1, 1) * PAD * diff(xr); yl <- yr + c(-1, 1) * PAD * diff(yr)
panel_px <- W_PX - 2 * SIDE_PT * 300 / 72
upm  <- diff(xl) / panel_px                     # metres per pixel
H_PX <- round(panel_px * diff(yl) / diff(xl) + TEXT_PX)

# Label: a 2 km grid puts a road under any box of this size near the city, so the
# label sits in the nearest road-free area, north-east of the city, joined to the
# point by a thin leader. Position is a drawing choice; the guard asserts that no
# edge endpoint or midpoint lies under the text box. Halo: the same text in the
# background colour, offset on a circle, drawn underneath.
LAB_DX <- 21000; LAB_DY <- 13500                # metres from Prishtina to the label's left-centre
lab_x <- dest[["x"]] + LAB_DX; lab_y <- dest[["y"]] + LAB_DY
box_w <- 300 * upm; box_h <- 80 * upm           # generous box around the rendered text
in_box <- function(x, y) x >= lab_x - 10 * upm & x <= lab_x + box_w & abs(y - lab_y) <= box_h / 2
n_under <- sum(in_box(seg$x1, seg$y1) | in_box(seg$x2, seg$y2) |
               in_box((seg$x1 + seg$x2) / 2, (seg$y1 + seg$y2) / 2))
cat("network edges under the label box:", n_under, "\n")
stopifnot(n_under == 0)
stopifnot(max(sqrt((seg$x2 - seg$x1)^2 + (seg$y2 - seg$y1)^2)) < box_h)  # no edge can span the box unseen
stopifnot(lab_x + box_w <= xl[2], lab_y + box_h / 2 <= yl[2])
ang  <- seq(0, 2 * pi, length.out = 25)[-1]
halo <- data.frame(x = lab_x + 6 * upm * cos(ang), y = lab_y + 6 * upm * sin(ang))

p <- ggplot(seg) +
  geom_segment(aes(x = x1, y = y1, xend = x2, yend = y2, linewidth = flow, colour = flow),
               lineend = "round") +
  scale_linewidth_continuous(range = LW_RANGE, transform = "sqrt", guide = "none") +
  scale_colour_gradient(low = navy_light, high = navy, transform = "log10",
                        limits = c(1, FULL_NAVY_AT), oob = scales::squish, guide = "none") +
  annotate("segment", x = dest[["x"]], y = dest[["y"]], xend = lab_x - 14 * upm, yend = lab_y,
           colour = rust, linewidth = 0.35) +
  annotate("point", x = dest[["x"]], y = dest[["y"]], colour = off, size = 4.2) +
  annotate("point", x = dest[["x"]], y = dest[["y"]], colour = rust, size = 2.8) +
  geom_text(data = halo, aes(x, y), label = "Prishtina", family = "ss3", fontface = "bold",
            size = 4.6, colour = off, hjust = 0) +
  annotate("text", x = lab_x, y = lab_y, label = "Prishtina", family = "ss3",
           fontface = "bold", size = 4.6, colour = rust, hjust = 0) +
  coord_equal(xlim = xl, ylim = yl, expand = FALSE) +
  labs(title = title_txt, subtitle = subtitle_txt, caption = caption_txt) +
  theme_void(base_family = "ss3") +
  theme(
    plot.title    = element_text(face = "bold", size = 22, colour = ink, margin = margin(b = 4)),
    plot.subtitle = element_text(size = 11, colour = sub, lineheight = 1.15, margin = margin(b = 2)),
    plot.caption  = element_text(size = 8.5, colour = sub, hjust = 0, lineheight = 1.3,
                                 margin = margin(t = 4)),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin   = margin(16, SIDE_PT, 12, SIDE_PT))

# Render once at full size; downscale the raster for the 1200 px version.
stem <- sprintf("roads_to_prishtina_%s", TAG)
hi   <- file.path(OUT, paste0(stem, ".png"))
ggsave(hi, p, width = W_PX, height = H_PX, units = "px", dpi = 300, bg = off)
magick::image_write(magick::image_resize(magick::image_read(hi), "1200x"),
                    file.path(OUT, paste0(stem, "_linkedin_1200.png")))

cat(sprintf("directed edges drawn: %d | routed origins: %d of %d grid points\n",
            nrow(seg), fig$n_routed, fig$n_grid))
cat(sprintf("extract: %s | dodgr %s, profile %s | grid %s km\n",
            extract_date_txt(), fig$dodgr_version, fig$wt_profile, format(fig$grid_km)))
cat("benchmark:\n"); print(as.data.frame(fig$benchmark), digits = 4)
cat("saved:", hi, "\n")
report_resources(t0, "06_figure")
