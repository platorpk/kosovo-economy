# ==============================================================================
# 05_build_routes.R
# Benchmark gate first, then the routes: fastest road route from every origin of
# a regular grid to Prishtina, aggregated to a count of routes per directed edge.
# Reads:  data/processed/network_kosova.rds, roads_main_kosova.rds,
#         places_kosova.rds, data/lookup_benchmark.csv
# Writes: data/processed/benchmark_kosova.csv
#         data/processed/origins_kosova.csv     (every grid origin and its fate)
#         data/processed/flows_kosova.rds       (directed edges carrying >= 1 route)
#         data/processed/figures_kosova.json
# Concept notes:
#  - Fastest route under an assumed car speed per road class (dodgr "motorcar"),
#    ignoring traffic. One-way rules kept.
#  - Origins are grid centres inside the geoBoundaries XKX polygon. The polygon
#    places origins only and is not drawn.
#  - Origins further than MAX_ROAD_M from a road of the routable network are
#    dropped and counted. Each remaining origin is moved to its nearest graph
#    vertex, measured in metres in UTM 34N; no origin may move more than MAX_ROAD_M.
#  - The benchmark is a sanity check, not an input: DISTANCE along the model's
#    fastest path against one reference distance in data/lookup_benchmark.csv,
#    tolerance +/-10%. A miss stops the script before any grid routing. The
#    model's travel time for the pair is recorded beside the reference time but
#    is not gated.
#  - Anchors are OSM place nodes, matched by an explicit regex per town; OSM name
#    labels are source labels and are not used in prose.
# Run from the piece root:  Rscript R/05_build_routes.R
# ==============================================================================
t0 <- proc.time()
source("R/01_functions.R")
suppressWarnings(suppressMessages({ library(dodgr); library(readr) }))
dodgr::dodgr_cache_off()

net        <- readRDS(file.path(PROC, sprintf("network_%s.rds", TAG)))
roads_main <- readRDS(file.path(PROC, sprintf("roads_main_%s.rds", TAG)))
places     <- readRDS(file.path(PROC, sprintf("places_%s.rds", TAG)))
verts      <- dodgr::dodgr_vertices(net)
vpts       <- vertex_points(verts)
cat("graph edges:", nrow(net), "| vertices:", nrow(verts), "\n")
dest <- anchor_vertex(places, verts, vpts, ANCHORS[["prishtina"]])

# ---- 1. BENCHMARK GATE (before any grid routing) -------------------------------
bench <- readr::read_csv(file.path(PROJ, "data/lookup_benchmark.csv"), show_col_types = FALSE)
stopifnot(nrow(bench) == 1, bench$pair_id == "prizren_prishtina")
stopifnot(!anyNA(bench[, c("ref_km", "ref_min", "source", "accessed")]))
a <- anchor_vertex(places, verts, vpts, ANCHORS[["prizren"]])
bench$model_km  <- as.numeric(dodgr::dodgr_dists(net, from = a$id, to = dest$id)) / 1000
bench$model_min <- as.numeric(dodgr::dodgr_times(net, from = a$id, to = dest$id)) / 60
stopifnot(is.finite(bench$model_km), is.finite(bench$model_min))
v_pair <- bench$model_km / (bench$model_min / 60)            # mean speed along the path
stopifnot(v_pair >= 10, v_pair <= 90)                        # inside the profile's speed range
bench$ratio <- bench$model_km / bench$ref_km
bench$pass  <- abs(bench$ratio - 1) <= BENCH_TOL
cat("\n== benchmark (sanity check on distance, tolerance +/-", 100 * BENCH_TOL, "%) ==\n", sep = "")
print(as.data.frame(bench[, c("pair_id", "ref_km", "model_km", "ratio", "pass",
                              "ref_min", "model_min", "accessed")]), digits = 4)
readr::write_csv(bench, file.path(PROC, sprintf("benchmark_%s.csv", TAG)))
if (!all(bench$pass)) stop("Benchmark missed the tolerance. Stopping before the grid run.")

# ---- 2. Grid origins, routes, flows ---------------------------------------------
cat("\n== routes ==\n")
rf <- route_flows(net, roads_main, verts, vpts, dest, origin_polygon())
cat("directed edges carrying at least one route:", nrow(rf$seg),
    "| most routes on one edge:", max(rf$seg$flow), "\n")

readr::write_csv(rf$origins, file.path(PROC, sprintf("origins_%s.csv", TAG)))
saveRDS(list(seg = rf$seg, dest = rf$dest_utm), file.path(PROC, sprintf("flows_%s.rds", TAG)))

speeds <- readr::read_csv(file.path(PROC, sprintf("speed_profile_%s.csv", TAG)), show_col_types = FALSE)
jsonlite::write_json(list(
  extract_date = EXTRACT_DATE, extract_md5 = unname(tools::md5sum(PBF)),
  model = "fastest route, assumed car speed per road class",
  wt_profile = WT_PROFILE, dodgr_version = speeds$dodgr_version[1],
  grid_km = GRID_KM, max_road_m = MAX_ROAD_M,
  n_grid = rf$n[["grid"]], n_dropped_far = rf$n[["dropped_far"]],
  n_routed = rf$n[["routed"]], n_unreachable = rf$n[["unreachable"]],
  n_at_dest = rf$n_at_dest, snap_max_m = rf$snap_max_m,
  n_edges_with_route = nrow(rf$seg), max_flow = max(rf$seg$flow),
  graph_edges = nrow(net), graph_vertices = nrow(verts),
  dest = list(osm_node = dest$osm_node, place = dest$place,
              node_lon = dest$node_lon, node_lat = dest$node_lat,
              vertex_lon = dest$x, vertex_lat = dest$y, snap_m = dest$snap_m),
  benchmark = bench[, c("pair_id", "ref_km", "model_km", "ratio", "pass", "ref_min", "model_min")]),
  file.path(PROC, sprintf("figures_%s.json", TAG)), auto_unbox = TRUE, pretty = TRUE, digits = 8)

report_resources(t0, "05_build_routes")
