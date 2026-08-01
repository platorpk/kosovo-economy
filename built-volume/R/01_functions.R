# ==============================================================================
# 01_functions.R  —  Shared helpers for the built-volume piece.
# Built volume per resident across Kosova's 38 municipalities.
# Author: Plator Krasniqi. Open data only. R / tidyverse / sf / arrow.
# Sourced by 02–05; not run directly.
# ==============================================================================
suppressWarnings(suppressMessages({ library(dplyr); library(sf) }))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

PROJ <- "C:/Users/plato/Documents/kosovo-economy/built-volume"

# --- GlobalBuildingAtlas (Zhu et al. 2025, TUM) on Source Cooperative ----------
# LoD1 building polygons + heights, 5-degree tiles. Kosova (20.012-21.789 E,
# 41.858-43.267 N) falls entirely inside a single tile — its western edge sits
# ~1.3 km inside the 20 E boundary, so no second tile is needed.
GBA_S3_PATH <- "us-west-2.opendata.source.coop/tge-labs/globalbuildingatlas-lod1"
GBA_TILE    <- "e020_n45_e025_n40.parquet"

# --- ASK PxWeb ----------------------------------------------------------------
# English database node; the /PXWeb/ path variant returns HTTP 500.
ASK_BASE <- "https://askdata.rks-gov.net/api/v1/en/ASKdata"

ask_pull <- function(table_url, query, polite = TRUE) {
  q  <- pxweb::pxweb_query(query)
  px <- pxweb::pxweb_get(table_url, query = q)
  df <- as.data.frame(px, column.name.type = "text", variable.value.type = "text")
  if (polite) Sys.sleep(2)   # house rule: 2s minimum between web requests
  df
}

# --- Municipality names --------------------------------------------------------
# Standardise geoBoundaries ADM2 shapeName -> house-style Albanian labels.
clean_muni_names <- function(x) {
  x <- sub("^Municipality of ", "", x)
  dplyr::recode(x,
    "Pristina"        = "Prishtina",
    "Gracanica"       = "Graçanica",
    "Mamusha"         = "Mamushë",
    "North Mitrovica" = "Mitrovica e Veriut"
  )
}

# The four northern municipalities: their 2024 population figures are ASK
# ESTIMATES (2024 census boycott). Buildings are satellite-derived and so are
# unaffected — a real numerator over an estimated denominator.
NORTH <- c("Mitrovica e Veriut", "Leposaviq", "Zveçan", "Zubin Potok")

# --- Footprint area + centroid, computed in chunks -----------------------------
# 1.4M WKB polygons will not fit comfortably in memory as one sf object, so parse
# in slices and keep only the numbers, discarding geometry as we go. One pass
# gives both area and centroid, so municipality assignment uses true polygon
# centroids rather than a bounding-box approximation.
#
# Areas are planar in UTM zone 34N (EPSG:32634) rather than geodesic. Reason:
# a share of GBA footprints contain degenerate rings (duplicate vertices), which
# s2 rejects outright ("Loop 0 is not valid: Edge N is degenerate"). GEOS accepts
# them. UTM 34N spans 18-24 E and so contains all of Kosova (20.0-21.8 E), where
# scale distortion is well under a percent — immaterial at building footprint
# size. Requires sf_use_s2(FALSE).
UTM34N <- 32634

chunked_geom_stats <- function(wkb, chunk = 50000L, verbose = TRUE) {
  n <- length(wkb)
  area <- numeric(n); cx <- numeric(n); cy <- numeric(n)
  idx <- split(seq_len(n), ceiling(seq_len(n) / chunk))
  for (i in seq_along(idx)) {
    k <- idx[[i]]
    g <- sf::st_as_sfc(structure(wkb[k], class = "WKB"), EWKB = FALSE)
    sf::st_crs(g) <- 4326
    gp <- sf::st_transform(g, UTM34N)
    area[k] <- as.numeric(sf::st_area(gp))
    ct <- sf::st_transform(suppressWarnings(sf::st_centroid(gp)), 4326)
    xy <- sf::st_coordinates(ct)
    cx[k] <- xy[, 1]; cy[k] <- xy[, 2]
    rm(g, gp, ct, xy)
    if (verbose && (i %% 10 == 0 || i == length(idx)))
      message(sprintf("   geometry: %s / %s rows",
                      format(max(k), big.mark = ","), format(n, big.mark = ",")))
  }
  data.frame(area_m2 = area, cx = cx, cy = cy)
}
