# ==============================================================================
# 02_build_municipal_data.R
# Pool 2025 (Q1-Q4) Ookla tiles, aggregate to Kosovo's 38 municipalities,
# attach night-lights (VIIRS 2024) as an economic-geography proxy.
# Fixed broadband is the focus; mobile is summarised at national level only
# because municipal mobile sampling is too sparse to map reliably.
#
# Economic proxy note: the headline proxy is night-lights radiance sampled at
# the tested tiles and test-weighted (radiance_tw) -- i.e. brightness where
# people actually connect. A whole-polygon mean (radiance_poly) is also stored
# for transparency; it is a weaker proxy because it is diluted by uninhabited
# terrain in large rural municipalities.
# ==============================================================================
suppressWarnings(suppressMessages({
  library(arrow); library(dplyr); library(sf); library(terra)
}))
Sys.setenv(AWS_EC2_METADATA_DISABLED = "true")
options(scipen = 999)

proj     <- "C:/Users/plato/Documents/kosovo-economy/ookla-digital-divide"
raw_dir  <- file.path(proj, "data", "raw")
proc_dir <- file.path(proj, "data", "processed"); dir.create(proc_dir, showWarnings = FALSE, recursive = TRUE)
viirs    <- "C:/Users/plato/Desktop/Maps/data/viirs/VNL_npp_2024_global_vcmslcfg_v2_c202502261200.average.dat.tif"
source(file.path(proj, "R", "01_functions.R"))

MIN_TESTS <- 50L          # municipalities below this (pooled 2025) are flagged low-sample
YEAR      <- 2025L

# --- Boundaries: 38 municipalities, Albanian names -----------------------------
bnd_file <- file.path(raw_dir, "geoBoundaries-XKX-ADM2.geojson")
if (!file.exists(bnd_file))
  download.file("https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/XKX/ADM2/geoBoundaries-XKX-ADM2.geojson",
                bnd_file, mode = "wb", quiet = TRUE)
munis <- st_read(bnd_file, quiet = TRUE) |>
  mutate(muni = clean_muni_names(shapeName)) |>
  select(muni, shapeID) |>
  st_make_valid()
bbox <- as.list(st_bbox(munis)); names(bbox) <- c("xmin", "ymin", "xmax", "ymax")
cat("Municipalities:", nrow(munis), "\n")

# --- Night-lights raster, cropped to Kosovo ------------------------------------
vnlk <- crop(rast(viirs), ext(vect(munis)))

# --- Pull + pool 2025 tiles ----------------------------------------------------
bucket <- s3_bucket("ookla-open-data", anonymous = TRUE, region = "us-west-2")
pool   <- function(type) bind_rows(lapply(1:4, function(q)
            ookla_clip(bucket, type, YEAR, q, bbox, raw_dir)))
cat("Pulling/pooling fixed 2025 Q1-Q4 ...\n");  fixed  <- pool("fixed")
cat("Pulling/pooling mobile 2025 Q1-Q4 ...\n"); mobile <- pool("mobile")
cat("Pooled tile-quarters  fixed:", nrow(fixed), " mobile:", nrow(mobile), "\n")

# --- Assign tiles to municipalities (point-in-polygon) -------------------------
join_muni <- function(df) {
  pts <- st_as_sf(df, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  st_join(pts, munis["muni"], join = st_within, left = FALSE) |> st_drop_geometry()
}
fj <- join_muni(fixed); mj <- join_muni(mobile)

# night-lights at each tested fixed tile (last column = layer value, robust to ID col)
ex <- terra::extract(vnlk, as.matrix(fj[, c("lon", "lat")])); fj$rad <- ex[[ncol(ex)]]

agg <- function(j) {
  j |> group_by(muni) |>
    summarise(
      n_obs   = n(),                       # tile-quarter observations
      n_tiles = n_distinct(quadkey),       # distinct tiles seen
      dl_mbps = weighted.mean(avg_d_kbps, tests) / 1000,   # test-weighted (uses raw `tests`)
      ul_mbps = weighted.mean(avg_u_kbps, tests) / 1000,
      lat_ms  = weighted.mean(avg_lat_ms, tests),
      dl_mbps_unw = mean(avg_d_kbps) / 1000,               # unweighted tile mean
      radiance_tw = weighted.mean(rad, tests, na.rm = TRUE),  # brightness where people connect
      tests   = sum(tests),                # summed LAST so it does not shadow the weight vector
      devices = sum(devices),
      .groups = "drop")
}
fixed_muni  <- agg(fj)
mobile_muni <- mj |> group_by(muni) |>
  summarise(m_tests = sum(tests), m_tiles = n_distinct(quadkey),
            m_dl = weighted.mean(avg_d_kbps, tests) / 1000, .groups = "drop")

# whole-polygon mean radiance (transparency proxy)
munis$radiance_poly <- terra::extract(vnlk, vect(munis), fun = mean, na.rm = TRUE)[, 2]

# --- Assemble, flag low-sample municipalities ----------------------------------
muni_data <- munis |>
  left_join(fixed_muni, by = "muni") |>
  mutate(adequate = !is.na(tests) & tests >= MIN_TESTS)

# --- National summaries --------------------------------------------------------
national <- list(
  fixed_dl  = weighted.mean(fj$avg_d_kbps, fj$tests) / 1000,
  fixed_ul  = weighted.mean(fj$avg_u_kbps, fj$tests) / 1000,
  fixed_lat = weighted.mean(fj$avg_lat_ms, fj$tests),
  mobile_dl = weighted.mean(mj$avg_d_kbps, mj$tests) / 1000,
  mobile_ul = weighted.mean(mj$avg_u_kbps, mj$tests) / 1000,
  mobile_lat= weighted.mean(mj$avg_lat_ms, mj$tests),
  fixed_tests = sum(fj$tests), mobile_tests = sum(mj$tests),
  mobile_munis_ge30 = sum(mobile_muni$m_tests >= 30),
  n_munis = nrow(munis), year = YEAR)

cor_df <- muni_data |> st_drop_geometry() |> filter(adequate)
national$rho_tw   <- cor(cor_df$radiance_tw,   cor_df$dl_mbps, method = "spearman", use = "complete.obs")
national$rho_poly <- cor(cor_df$radiance_poly, cor_df$dl_mbps, method = "spearman", use = "complete.obs")
national$spread_ratio <- max(cor_df$dl_mbps) / min(cor_df$dl_mbps)

# --- Save processed outputs ----------------------------------------------------
saveRDS(list(muni = muni_data, mobile_muni = mobile_muni, national = national),
        file.path(proc_dir, "municipal_data_2025.rds"))
write.csv(st_drop_geometry(muni_data) |>
            select(muni, n_tiles, tests, dl_mbps, ul_mbps, lat_ms, dl_mbps_unw,
                   radiance_tw, radiance_poly, adequate) |>
            arrange(desc(dl_mbps)),
          file.path(proc_dir, "municipal_fixed_2025.csv"), row.names = FALSE)

# --- Console report ------------------------------------------------------------
cat(sprintf("\nNATIONAL 2025 (test-weighted means):\n  fixed  %.1f Mbps down / %.1f up / %.0f ms  (tests %s)\n  mobile %.1f Mbps down / %.1f up / %.0f ms  (tests %s)\n",
    national$fixed_dl, national$fixed_ul, national$fixed_lat, format(national$fixed_tests, big.mark=","),
    national$mobile_dl, national$mobile_ul, national$mobile_lat, format(national$mobile_tests, big.mark=",")))
cat(sprintf("Mobile municipal coverage: %d of %d municipalities reach >=30 pooled tests\n",
    national$mobile_munis_ge30, national$n_munis))
cat(sprintf("Fixed spread (fastest/slowest adequate): %.1fx\n", national$spread_ratio))
cat(sprintf("Night-lights vs fixed download (n=%d adequate munis):\n  radiance_tw (tested tiles): Spearman rho=%.2f\n  radiance_poly (polygon mean): Spearman rho=%.2f\n",
    nrow(cor_df), national$rho_tw, national$rho_poly))

low <- muni_data |> st_drop_geometry() |> filter(!adequate) |> pull(muni)
cat("Low-sample municipalities (<", MIN_TESTS, "tests, greyed on map):",
    if (length(low)) paste(low, collapse = ", ") else "(none)", "\n")

show <- muni_data |> st_drop_geometry() |> filter(adequate) |>
  arrange(desc(dl_mbps)) |>
  select(muni, n_tiles, tests, dl_mbps, lat_ms, radiance_tw) |>
  mutate(across(where(is.numeric), \(x) round(x, 1)))
cat("\nFIXED download by municipality (adequate), fastest & slowest 8:\n")
print(as.data.frame(bind_rows(head(show, 8), tail(show, 8))), row.names = FALSE)
cat("\nDONE 02.\n")
