# ==============================================================================
# 02_pull_gba.R
# Pull the Kosova extent of GlobalBuildingAtlas LoD1 (Zhu et al. 2025, TUM) from
# Source Cooperative, filtering at the source on the GeoParquet bbox struct so
# the full 10.4M-row tile is never materialised.
#
# Output: data/raw/gba_kosova_bbox_raw.parquet (~167 MB, GITIGNORED — above
# GitHub's 100 MB per-file limit; regenerate by running this script).
#
# Building data (c) GlobalBuildingAtlas contributors, ODbL. Footprints derive
# from Microsoft Building Footprints and OpenStreetMap.
#
# Run from the piece root:  Rscript R/02_pull_gba.R
# ==============================================================================
suppressWarnings(suppressMessages({ library(arrow); library(sf); library(dplyr) }))
source("C:/Users/plato/Documents/kosovo-economy/built-volume/R/01_functions.R")

raw_out <- file.path(PROJ, "data/raw/gba_kosova_bbox_raw.parquet")

# --- Kosova extent from geoBoundaries ADM2 ------------------------------------
bnd <- file.path(PROJ, "data/raw/geoBoundaries-XKX-ADM2.geojson")
if (!file.exists(bnd)) {
  download.file(
    "https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/XKX/ADM2/geoBoundaries-XKX-ADM2.geojson",
    bnd, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
}
gb <- st_read(bnd, quiet = TRUE)
stopifnot(nrow(gb) == 38)
bb <- st_bbox(gb)
cat("Kosova ADM2 extent:", sprintf("%.4f..%.4f E, %.4f..%.4f N\n",
    bb[["xmin"]], bb[["xmax"]], bb[["ymin"]], bb[["ymax"]]))

# --- Pull, filtering at the source --------------------------------------------
if (file.exists(raw_out)) {
  cat("raw clip already present, skipping download:", raw_out, "\n")
} else {
  fs <- S3FileSystem$create(anonymous = TRUE, region = "us-west-2")
  ds <- open_dataset(file.path(GBA_S3_PATH, GBA_TILE), filesystem = fs)
  cat("tile", GBA_TILE, "holds", format(ds$num_rows, big.mark = ","), "buildings\n")

  pad  <- 0.02
  xmin <- bb[["xmin"]] - pad; xmax <- bb[["xmax"]] + pad
  ymin <- bb[["ymin"]] - pad; ymax <- bb[["ymax"]] + pad

  clip <- ds |>
    filter(bbox$xmin < xmax, bbox$xmax > xmin,
           bbox$ymin < ymax, bbox$ymax > ymin) |>
    collect()
  write_parquet(clip, raw_out)          # house rule: save raw before parsing
  cat("pulled", format(nrow(clip), big.mark = ","), "rows ->", raw_out,
      sprintf("(%.0f MB)\n", file.size(raw_out) / 1024^2))
}

# --- Verify ------------------------------------------------------------------
d <- read_parquet(raw_out)
cat("\nrows:", format(nrow(d), big.mark = ","), "| cols:",
    paste(names(d), collapse = " | "), "\n")
cat("region split (GBA's own attribution):\n")
print(d |> count(region, sort = TRUE) |> as.data.frame())
cat("source split:\n")
print(d |> count(source, sort = TRUE) |> as.data.frame())
cat("\nheight == -999 sentinels:", format(sum(d$height == -999), big.mark = ","),
    sprintf("(%.3f%%)\n", 100 * mean(d$height == -999)))
