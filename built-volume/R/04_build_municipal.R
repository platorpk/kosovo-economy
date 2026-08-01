# ==============================================================================
# 04_build_municipal.R
# Turn the raw GlobalBuildingAtlas clip into per-building and per-municipality
# tables of built volume, and divide by 2024 census population.
#
#   volume (m3) = geodesic footprint area (m2) x LoD1 height (m)
#
# Order matters: geometry statistics and the municipal assignment are computed
# for every row FIRST, so the -999 sentinel count can be reported for buildings
# actually inside Kosova rather than for GBA's own country attribution. Sentinels
# are then dropped, never imputed.
#
# Outputs (both committed; the 167 MB raw clip is not):
#   data/processed/buildings_kosova.parquet   — per building, WKB dropped
#   data/processed/municipal_built_volume.csv — per municipality
#
# Run from the piece root:  Rscript R/04_build_municipal.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(arrow); library(sf); library(dplyr); library(readr)
}))
source("C:/Users/plato/Documents/kosovo-economy/built-volume/R/01_functions.R")
# GEOS, not s2: some GBA footprints have degenerate rings that s2 rejects.
# Areas are taken in UTM 34N instead — see chunked_geom_stats() in 01_functions.R.
sf_use_s2(FALSE)

t_start <- Sys.time()
d <- read_parquet(file.path(PROJ, "data/raw/gba_kosova_bbox_raw.parquet"))
cat("raw clip rows:", format(nrow(d), big.mark = ","), "\n")

# --- 1. geodesic area + centroid, chunked ------------------------------------
cat("\ncomputing geodesic area and centroids ...\n")
t0 <- Sys.time()
gs <- chunked_geom_stats(d$geometry)
cat(sprintf("  done in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
d$area_m2 <- gs$area_m2; d$cx <- gs$cx; d$cy <- gs$cy
d$geometry <- NULL; d$bbox <- NULL; rm(gs); invisible(gc())

# --- 2. assign each building to a municipality (basic sf point-in-polygon) ----
# Canonical Albanian names come from the reviewed crosswalk, not from
# clean_muni_names() — that helper only recodes four labels and would leave
# Fushë Kosovë / Han i Elezit / Shtërpcë unmatched against the population table.
lk_geo <- read_csv(file.path(PROJ, "data/lookup_municipalities.csv"), show_col_types = FALSE)
adm <- st_read(file.path(PROJ, "data/raw/geoBoundaries-XKX-ADM2.geojson"), quiet = TRUE) |>
  st_make_valid()
miss <- setdiff(adm$shapeName, lk_geo$shapeName)
if (length(miss)) stop("shapeName values missing from the lookup: ", paste(miss, collapse = ", "))
adm <- adm |>
  left_join(lk_geo |> select(shapeName, muni), by = "shapeName") |>
  select(muni)
stopifnot(nrow(adm) == 38, !any(is.na(adm$muni)))

cat("\nassigning buildings to municipalities ...\n")
t0 <- Sys.time()
pts <- st_as_sf(data.frame(cx = d$cx, cy = d$cy), coords = c("cx", "cy"), crs = 4326)
hit <- st_intersects(pts, adm)
d$muni <- adm$muni[vapply(hit, function(x) if (length(x)) x[1] else NA_integer_, integer(1))]
rm(pts, hit); invisible(gc())
cat(sprintf("  done in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

cat("\nassigned to a Kosova municipality:", format(sum(!is.na(d$muni)), big.mark = ","),
    "of", format(nrow(d), big.mark = ","), "in the bbox\n")
cat("cross-check vs GBA's own region field (XKO):",
    format(sum(d$region == "XKO"), big.mark = ","), "\n")

k <- d |> filter(!is.na(muni))

# --- 3. sentinels, counted inside Kosova, then dropped ------------------------
n_sent <- sum(k$height == -999)
cat(sprintf("\n-999 sentinel heights inside Kosova: %s (%.3f%% of %s) — dropped, never imputed\n",
            format(n_sent, big.mark = ","), 100 * n_sent / nrow(k), format(nrow(k), big.mark = ",")))
k <- k |> filter(height != -999)
stopifnot(all(k$height > -999))

# --- 4. volume ----------------------------------------------------------------
k <- k |>
  mutate(volume_m3 = area_m2 * height) |>
  select(id, source, muni, height, area_m2, volume_m3, cx, cy)

cat("\nheight (m) profile, all retained structures:\n")
print(round(quantile(k$height, c(0, .25, .5, .75, .95, 1)), 2))
cat(sprintf("median %.2f m | share under 2.5 m %.1f%% | share under 3 m %.1f%%\n",
            median(k$height), 100 * mean(k$height < 2.5), 100 * mean(k$height < 3)))

write_parquet(k, file.path(PROJ, "data/processed/buildings_kosova.parquet"))
cat(sprintf("\nwrote buildings_kosova.parquet (%s rows, %.0f MB)\n",
            format(nrow(k), big.mark = ","),
            file.size(file.path(PROJ, "data/processed/buildings_kosova.parquet")) / 1024^2))

# --- 5. municipal aggregate + population -------------------------------------
pop <- read_csv(file.path(PROJ, "data/processed/population_2024.csv"), show_col_types = FALSE)

agg <- k |>
  group_by(muni) |>
  summarise(n_buildings   = n(),
            footprint_m2  = sum(area_m2),
            volume_m3     = sum(volume_m3),
            median_h_m    = median(height), .groups = "drop")

# sensitivity: structures at least 2.5 m tall (excludes most sheds/outbuildings)
agg25 <- k |> filter(height >= 2.5) |>
  group_by(muni) |>
  summarise(n_buildings_25 = n(), volume_m3_25 = sum(volume_m3), .groups = "drop")

m <- pop |>
  left_join(agg,   by = "muni") |>
  left_join(agg25, by = "muni") |>
  mutate(vol_per_resident    = volume_m3 / pop_2024,
         vol_per_resident_25 = volume_m3_25 / pop_2024)

bad <- m |> filter(is.na(volume_m3) | is.na(vol_per_resident))
if (nrow(bad)) stop("Municipalities with no buildings or no ratio: ",
                    paste(bad$muni, collapse = ", "))
stopifnot(nrow(m) == 38)

m <- m |> mutate(rank_all = rank(-vol_per_resident), rank_25 = rank(-vol_per_resident_25))
write_csv(m, file.path(PROJ, "data/processed/municipal_built_volume.csv"))

# --- 6. report ----------------------------------------------------------------
natl_vol <- sum(m$volume_m3); natl_pop <- sum(m$pop_2024)
cat(sprintf("\n== NATIONAL ==\n  buildings: %s\n  built volume: %.2f billion m3\n  population: %s\n  volume per resident: %.0f m3\n",
            format(sum(m$n_buildings), big.mark = ","), natl_vol / 1e9,
            format(natl_pop, big.mark = ","), natl_vol / natl_pop))

rho <- cor(m$vol_per_resident, m$vol_per_resident_25, method = "spearman")
cat(sprintf("\n== 2.5 m SENSITIVITY ==\n  Spearman rank correlation, all structures vs >=2.5 m: %.3f\n", rho))
cat("  max rank shift:", max(abs(m$rank_all - m$rank_25)), "places\n")

cat("\n== volume per resident (m3), all structures ==\n")
show <- m |> arrange(desc(vol_per_resident)) |>
  transmute(muni, pop_2024, n_buildings,
            vol_per_resident = round(vol_per_resident),
            vol_per_resident_25 = round(vol_per_resident_25),
            rank_all, rank_25, is_north)
print(as.data.frame(show), row.names = FALSE)

cat(sprintf("\ntotal runtime %.1f min\n", as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
