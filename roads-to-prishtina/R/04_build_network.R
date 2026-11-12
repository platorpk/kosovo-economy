# ==============================================================================
# 04_build_network.R
# Converts the raw .osm.pbf to a GeoPackage of drivable roads, filtering road
# classes INSIDE the GDAL conversion (osmextract vectortranslate_options,
# -where highway IN (...)), removes ways not open to a private car, and builds
# the dodgr routing graph. Also reads city/town place nodes for the route anchors.
# Source: OSM "lines" and "points" layers of the Geofabrik extract in data/raw.
# Writes: data/processed/roads_kosovo-<yymmdd>.gpkg (+ .spec.txt: what it was built with)
#         data/processed/network_kosova.rds           (dodgr graph, main component)
#         data/processed/roads_main_kosova.rds        (sf lines of that component)
#         data/processed/places_kosova.rds            (place = city / town nodes)
#         data/processed/fragments_kosova.csv         (dropped components)
#         data/processed/speed_profile_kosova.csv     (km/h per class, dodgr version)
#         data/processed/network_summary_kosova.json  (counts reported in the README)
# Concept notes:
#  - "Drivable" is the analyst's class list HIGHWAY_CLASSES in 01_functions.R,
#    minus ways tagged access = private, no or military.
#  - Routing is by TIME: fastest route under dodgr's "motorcar" speed per road
#    class. No traffic, turn or traffic-light penalties. OSM maxspeed and surface
#    tags are not used.
#  - One-way tags are set and asserted in build_graph().
#  - Only the largest connected component is kept; every other fragment is
#    counted and written out, not patched.
#  - A cached GeoPackage is reused only if it was built with the current class
#    and tag lists; otherwise the script stops.
# Run from the piece root:  Rscript R/04_build_network.R
# ==============================================================================
t0 <- proc.time()
source("R/01_functions.R")
suppressWarnings(suppressMessages({ library(osmextract); library(dodgr) }))
stopifnot(file.exists(PBF))

# ---- 1. .pbf -> filtered .gpkg -------------------------------------------------
spec <- conversion_spec()
if (file.exists(ROADS_GPKG)) {
  if (!file.exists(ROADS_SPEC)) {
    stop("cached GeoPackage has no record of the class list it was built with: ", ROADS_GPKG,
         ". Move it away and rerun.")
  }
  if (!identical(readLines(ROADS_SPEC, warn = FALSE), spec)) {
    cat("cached :", readLines(ROADS_SPEC, warn = FALSE), sep = "\n  ")
    cat("current:", spec, sep = "\n  ")
    stop("cached GeoPackage was built with a different class or tag list. Move it away and rerun.")
  }
  cat("converted roads already present and built with the current class list:", ROADS_GPKG, "\n")
} else {
  # osmextract writes the .gpkg beside the .pbf; data/raw holds downloads only,
  # so the derived file is moved to data/processed straight away.
  made <- oe_vectortranslate(PBF, layer = "lines", extra_tags = EXTRA_TAGS,
                             vectortranslate_options = c("-where", highway_where()), quiet = TRUE)
  stopifnot(file.exists(made))
  stopifnot(file.rename(made, ROADS_GPKG))
  writeLines(spec, ROADS_SPEC)
}
roads <- sf::st_read(ROADS_GPKG, layer = "lines", quiet = TRUE)

cat("\n== verify: converted roads ==\n")
cat("rows   :", nrow(roads), "\n")
cat("columns:", paste(names(roads), collapse = ", "), "\n")
print(as.data.frame(sort(table(highway = roads$highway, useNA = "ifany"), decreasing = TRUE)))
print(head(sf::st_drop_geometry(roads[, c("osm_id", "name", "highway", "oneway", "access")]), 5))

stopifnot(nrow(roads) > 0)
stopifnot(!anyNA(roads$osm_id), !anyNA(roads$highway), !any(duplicated(roads$osm_id)))
stopifnot(all(roads$highway %in% HIGHWAY_CLASSES))          # the GDAL filter held
stopifnot(all(sf::st_geometry_type(roads) == "LINESTRING"))
stopifnot(all(EXTRA_TAGS %in% names(roads)))
n_converted <- nrow(roads)

# ---- 2. Ways not open to a private car ----------------------------------------
cat("\n== verify: access ==\n")
rr    <- routable_roads(roads)
roads <- rr$roads
stopifnot(nrow(roads) + rr$n_removed == n_converted)

# ---- 3. Graph: one-way settings, time weighting, largest component --------------
cat("\n== verify: graph ==\n")
g <- build_graph(roads)
cat("edges, all components:", g$edges_all, "| edges, main component:", nrow(g$net), "\n")
cat("speed profile (km/h per class), dodgr", g$speeds$dodgr_version[1], "profile", WT_PROFILE, ":\n")
print(g$speeds[, c("highway", "kmh")], row.names = FALSE)
readr::write_csv(g$speeds, file.path(PROC, sprintf("speed_profile_%s.csv", TAG)))

cat(sprintf("\ncomponents: %d | main component holds %.2f%% of directed edge length\n",
            g$n_components, 100 * g$share_main))
cat(sprintf("dropped fragments: %d, %.0f directed-edge km in total. Largest 10:\n",
            nrow(g$fragments), sum(g$fragments$km)))
print(as.data.frame(head(g$fragments, 10)), digits = 5)
readr::write_csv(g$fragments, file.path(PROC, sprintf("fragments_%s.csv", TAG)))
# ANALYST THRESHOLD: a main component below 90% of length means the class filter
# has broken the network, and the run must not continue.
stopifnot(g$share_main >= 0.90)
cat("ways kept in main component:", nrow(g$roads_main), "of", g$ways_all, "\n")

# ---- 4. Place nodes for the route anchors ---------------------------------------
places <- sf::st_read(PBF, quiet = TRUE,
  query = "SELECT osm_id, name, place FROM points WHERE place IN ('city','town')")
stopifnot(nrow(places) > 0, !any(duplicated(places$osm_id)))
cat("\n== verify: place nodes (city / town) ==\n")
cat("rows:", nrow(places), "\n")
print(head(sf::st_drop_geometry(places), 10))

saveRDS(g$net,        file.path(PROC, sprintf("network_%s.rds", TAG)))
saveRDS(g$roads_main, file.path(PROC, sprintf("roads_main_%s.rds", TAG)))
saveRDS(places,       file.path(PROC, sprintf("places_%s.rds", TAG)))

jsonlite::write_json(list(
  extract_md5 = unname(tools::md5sum(PBF)),
  ways_converted = n_converted, ways_access_removed = rr$n_removed,
  ways_access_removed_by_value = as.list(rr$by_value),
  ways_routable = g$ways_all, ways_main = nrow(g$roads_main),
  oneway_reversed = g$oneway_counts[["reversed"]],
  roundabouts_set_oneway = g$oneway_counts[["roundabout"]],
  circular_set_oneway = g$oneway_counts[["circular"]],
  components = g$n_components, fragments = nrow(g$fragments), share_main = g$share_main,
  edges_all = g$edges_all, edges_main = nrow(g$net)),
  file.path(PROC, sprintf("network_summary_%s.json", TAG)), auto_unbox = TRUE, pretty = TRUE, digits = 10)

report_resources(t0, "04_build_network")
