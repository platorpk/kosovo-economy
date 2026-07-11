# ==============================================================================
# 01_functions.R  —  Reusable helpers for the Ookla digital-divide piece
# Kosovo municipal internet speeds. Author: Plator Krasniqi
# Open data only. R / tidyverse. No external services beyond public S3 + geodata.
# ==============================================================================

# --- Slippy-tile / quadkey helpers (standard Bing tile system, Ookla uses z=16)
# Ookla tiles are keyed by quadkey; the tile centroid can be reconstructed
# exactly from the quadkey (validated against Ookla's WKT geometry to ~1e-8 deg),
# so no WKT parsing is needed to geolocate a tile.

lonlat_to_tile <- function(lon, lat, z) {
  n <- 2^z
  x <- floor((lon + 180) / 360 * n)
  sinlat <- sin(lat * pi / 180)
  y <- floor((0.5 - log((1 + sinlat) / (1 - sinlat)) / (4 * pi)) * n)
  cbind(x = pmin(pmax(x, 0), n - 1), y = pmin(pmax(y, 0), n - 1))
}

tilexy_to_quadkey <- function(x, y, z) {
  qk <- rep("", length(x))
  for (i in seq(z, 1)) {
    mask <- bitwShiftL(1L, i - 1L)
    d <- ifelse(bitwAnd(x, mask) != 0, 1L, 0L) + ifelse(bitwAnd(y, mask) != 0, 2L, 0L)
    qk <- paste0(qk, d)
  }
  qk
}

# Zoom-`z` quadkey prefixes covering a lon/lat bounding box (a coarse pre-filter).
bbox_prefixes <- function(xmin, ymin, xmax, ymax, z) {
  tl <- lonlat_to_tile(xmin, ymax, z); br <- lonlat_to_tile(xmax, ymin, z)
  xs <- seq(min(tl[, "x"], br[, "x"]), max(tl[, "x"], br[, "x"]))
  ys <- seq(min(tl[, "y"], br[, "y"]), max(tl[, "y"], br[, "y"]))
  g <- expand.grid(x = xs, y = ys)
  unique(tilexy_to_quadkey(g$x, g$y, z))
}

# Reconstruct tile-centroid lon/lat from a vector of zoom-16 quadkeys.
quadkey_to_centroid <- function(qk) {
  z <- nchar(qk[1]); n <- 2^z
  ch <- do.call(rbind, strsplit(qk, "", fixed = TRUE))
  x <- integer(length(qk)); y <- integer(length(qk))
  for (i in seq_len(z)) {
    d <- as.integer(ch[, i]); bit <- z - i
    x <- x + ifelse(d %% 2 == 1, bitwShiftL(1L, bit), 0L)
    y <- y + ifelse(d %/% 2 == 1, bitwShiftL(1L, bit), 0L)
  }
  data.frame(lon = (x + 0.5) / n * 360 - 180,
             lat = atan(sinh(pi * (1 - 2 * ((y + 0.5) / n)))) * 180 / pi)
}

# --- Pull one quarter/type of Ookla tiles, clipped to a bbox, with local cache.
# Reads only quadkey + metric columns from the public S3 parquet (no WKT), then
# reconstructs centroids. Caches the clip to `cache_dir` so re-runs are instant.
ookla_clip <- function(bucket, type, year, quarter, bbox, cache_dir, z = 8) {
  cache <- file.path(cache_dir,
                     sprintf("ookla_%s_%dQ%d_kosovo_bbox.parquet", type, year, quarter))
  if (file.exists(cache)) {
    df <- arrow::read_parquet(cache)
  } else {
    dir  <- sprintf("parquet/performance/type=%s/year=%d/quarter=%d", type, year, quarter)
    ds   <- arrow::open_dataset(bucket$path(dir))
    pref <- bbox_prefixes(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax, z)
    df <- ds |>
      dplyr::filter(substr(quadkey, 1, 8) %in% pref) |>
      dplyr::select(quadkey, avg_d_kbps, avg_u_kbps, avg_lat_ms, tests, devices) |>
      dplyr::collect()
    cent <- quadkey_to_centroid(df$quadkey)
    df$lon <- cent$lon; df$lat <- cent$lat
    df$year <- year; df$quarter <- quarter
    arrow::write_parquet(df, cache)     # save raw clip before parsing (house rule)
    Sys.sleep(2)                        # be polite between web pulls (house rule)
  }
  df
}

# --- Standardise geoBoundaries ADM2 shapeName -> house-style Albanian labels.
clean_muni_names <- function(x) {
  x <- sub("^Municipality of ", "", x)
  dplyr::recode(x,
    "Pristina"        = "Prishtina",
    "Gracanica"       = "Graçanica",
    "Mamusha"         = "Mamushë",
    "North Mitrovica" = "Mitrovica e Veriut"
  )
}
