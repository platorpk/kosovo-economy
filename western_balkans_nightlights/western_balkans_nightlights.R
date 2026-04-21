################################################################################
# PURPOSE: Publication-quality Nighttime Lights Map (Western Balkans)
# STYLE: Monochrome Gold — Milan Janosov-inspired
# DATA: VIIRS VNL v22 2024 Annual Average (EOG/NOAA)
# Author: Plator Krasniqi | github.com/platorpk/kosovo-economy
################################################################################

# 1. Libraries ----------------------------------------------------------------
library(terra)
library(sf)
library(geodata)
library(ggplot2)
library(dplyr)
library(showtext)
library(ggrepel)  # For non-overlapping labels with arrows

# 2. Typography ---------------------------------------------------------------
font_add_google("Barlow Condensed", "barlow")
showtext_auto()
showtext_opts(dpi = 600)

# 3. Paths --------------------------------------------------------------------
setwd("C:/Users/plato/Desktop/Maps")
workdir  <- "data"
vnl_file <- file.path(workdir, "viirs",
  "VNL_npp_2024_global_vcmslcfg_v2_c202502261200.average.dat.tif")
if (!file.exists(vnl_file)) stop("VIIRS file not found: ", vnl_file)

# 4. Boundaries — Western Balkans countries -----------------------------------
wb_countries <- c("SRB", "MKD", "ALB", "MNE", "BIH", "XKO")

wb_list <- lapply(wb_countries, function(iso) {
  tryCatch({
    gadm <- geodata::gadm(iso, level = 0, path = workdir, version = "latest")
    st_as_sf(gadm) |> mutate(iso = iso)
  }, error = function(e) {
    message("Failed to fetch ", iso, ": ", e$message)
    NULL
  })
})

wb_sf <- do.call(rbind, Filter(Negate(is.null), wb_list))
wb_outline <- st_union(wb_sf) |> st_as_sf()

# 5. Load & clip VIIRS --------------------------------------------------------
viirs_rast <- terra::rast(vnl_file)

wb_sf_r      <- st_transform(wb_sf,      crs(viirs_rast))
wb_outline_r <- st_transform(wb_outline, crs(viirs_rast))

viirs_wb <- viirs_rast |>
  terra::crop(terra::vect(wb_outline_r)) |>
  terra::mask(terra::vect(wb_outline_r))

# 6. Upsample 3x --------------------------------------------------------------
viirs_up <- terra::disagg(viirs_wb, fact = 3, method = "bilinear")

# 7. Tonal mapping ------------------------------------------------------------
vals <- values(viirs_up, na.rm = TRUE)
viirs_up[viirs_up <= 0.3] <- NA

q999 <- quantile(vals[vals > 0.3], 0.999)
viirs_up[viirs_up > q999] <- q999

gamma_val  <- 0.40
viirs_norm <- (log1p(viirs_up) / log1p(q999))^gamma_val
viirs_norm[viirs_norm < 0.08] <- NA

# 8. Map normalised values → gold colours -------------------------------------
gold_ramp <- colorRampPalette(c(
  "#000000", "#0d0800", "#1f1000", "#3d2200",
  "#6b3d00", "#a86200", "#d4890a", "#f0b429",
  "#ffd966", "#fff0a0", "#ffffff"
), bias = 1.6)(2048)

vi_df <- as.data.frame(viirs_norm, xy = TRUE, na.rm = TRUE)
names(vi_df) <- c("x", "y", "val")

idx          <- pmax(1, pmin(2048, round(vi_df$val * 2047) + 1))
vi_df$colour <- gold_ramp[idx]

# 9. City points with label positioning --------------------------------------
cities <- data.frame(
  name = c("Belgrade", "Tirana", "Sarajevo", "Skopje", "Prishtina", 
           "Podgorica", "Niš", "Shkodër"),
  lon  = c(20.4612, 19.8187, 18.4131, 21.4254, 21.1655, 
           19.2636, 21.8958, 19.5126),
  lat  = c(44.7866, 41.3275, 43.8564, 41.9973, 42.6629, 
           42.4304, 43.3209, 42.0687)
) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  st_transform(crs(viirs_rast))

cities_coords <- st_coordinates(cities)
cities$x <- cities_coords[,1]
cities$y <- cities_coords[,2]

# 10. Build the map -----------------------------------------------------------
ext   <- terra::ext(viirs_norm)
xmin  <- as.numeric(ext[1])
xmax  <- as.numeric(ext[2])
ymin  <- as.numeric(ext[3])
ymax  <- as.numeric(ext[4])
yrange <- ymax - ymin

p <- ggplot() +

  # Nighttime lights layer
  geom_raster(
    data        = vi_df,
    aes(x = x, y = y, fill = colour),
    interpolate = FALSE
  ) +
  scale_fill_identity() +

  # Country borders
  geom_sf(data = wb_sf_r, colour = "white", fill = NA,
          linewidth = 0.15, alpha = 0.45) +

  # Regional outline
  geom_sf(data = wb_outline_r, colour = "white", fill = NA,
          linewidth = 0.28, alpha = 0.70) +

  # City points (small dots at exact locations)
  geom_point(
    data   = cities,
    aes(x = x, y = y),
    colour = "#ffffff",
    size   = 1.2,
    alpha  = 0.9
  ) +

  # City labels with arrows using ggrepel
  geom_text_repel(
    data      = cities,
    aes(x = x, y = y, label = name),
    colour    = "#ffffff",
    size      = 3.5,
    family    = "barlow",
    fontface  = "bold",
    bg.color  = "#000000",
    bg.r      = 0.10,
    segment.color  = "#ffffff",
    segment.size   = 0.3,
    segment.alpha  = 0.7,
    min.segment.length = 0,
    box.padding    = 0.5,
    point.padding  = 0.3,
    force          = 2,
    max.overlaps   = Inf
  ) +

  # Title block — OUTSIDE the map area, in the bottom margin
  annotate("text",
    x = xmin, 
    y = ymin - yrange * 0.06,
    label    = "WESTERN BALKANS",
    hjust    = 0, vjust = 1,
    size     = 14, fontface = "bold",
    colour   = "#f0b429", family = "barlow"
  ) +
  annotate("text",
    x = xmin, 
    y = ymin - yrange * 0.12,
    label    = "Nighttime Radiance  ·  2024",
    hjust    = 0, vjust = 1,
    size     = 5.5,
    colour   = "#a86200", family = "barlow"
  ) +
  annotate("text",
    x = xmin, 
    y = ymin - yrange * 0.17,
    label    = "VIIRS VNL v22  ·  Annual Average  ·  NOAA / EOG",
    hjust    = 0, vjust = 1,
    size     = 3.6,
    colour   = "#6b3d00", family = "barlow"
  ) +

  # Expand canvas to accommodate title with NO overlap
  coord_sf(
    xlim   = c(xmin, xmax),
    ylim   = c(ymin - yrange * 0.24, ymax + yrange * 0.02),
    expand = FALSE
  ) +

  theme_void() +
  theme(
    panel.background = element_rect(fill = "black", colour = NA),
    plot.background  = element_rect(fill = "black", colour = NA),
    plot.margin      = margin(25, 25, 25, 25),
    legend.position  = "none"
  )

# 11. Export (High-res for GitHub) --------------------------------------------
ggsave(
  "Western_Balkans_Nightlights_Gold_2024.png",
  plot   = p,
  width  = 12,
  height = 11.5,
  dpi    = 600,
  bg     = "black"
)

# 12. Export (LinkedIn-optimized: max dimension 5000px) -----------------------
ggsave(
  "Western_Balkans_Nightlights_LinkedIn.png",
  plot   = p,
  width  = 12,
  height = 11.5,
  dpi    = 400,
  bg     = "black"
)

print(p)
