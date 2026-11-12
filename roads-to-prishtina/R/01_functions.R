# ==============================================================================
# 01_functions.R  —  Shared helpers and constants for the roads-to-prishtina piece.
# Modelled fastest driving route from a regular grid of points to Prishtina on the
# OpenStreetMap road network, under an assumed car speed per road class.
# Author: Plator Krasniqi. Open data only. R / tidyverse / sf / osmextract / dodgr.
# Sourced by the numbered scripts and by build_readme.R; not run directly.
# ==============================================================================
suppressWarnings(suppressMessages({ library(dplyr); library(sf) }))

# PROJ is the piece root, i.e. the directory the script is run from. The guard
# stops a run started from anywhere else.
PROJ <- normalizePath(getwd(), winslash = "/")
stopifnot(basename(PROJ) == "roads-to-prishtina", file.exists(file.path(PROJ, "R/01_functions.R")))
RAW  <- file.path(PROJ, "data/raw")
PROC <- file.path(PROJ, "data/processed")
OUT  <- file.path(PROJ, "output")
for (d in c(RAW, PROC, OUT)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
TAG  <- "kosova"                                 # suffix of the files this piece writes

# --- Geofabrik extract -----------------------------------------------------------
# A dated file, not "-latest", so the raw input is pinned. The file stem is
# Geofabrik's own and stays verbatim.
GEOFABRIK    <- "https://download.geofabrik.de/europe"
EXTRACT_STEM <- "kosovo"
EXTRACT_DATE <- "261108"                         # yymmdd, as in the Geofabrik file name
PBF     <- file.path(RAW, sprintf("%s-%s.osm.pbf", EXTRACT_STEM, EXTRACT_DATE))
PBF_URL <- sprintf("%s/%s-%s.osm.pbf", GEOFABRIK, EXTRACT_STEM, EXTRACT_DATE)

# Extract date as prose, built by hand so it does not depend on the R locale.
extract_date_txt <- function(short = FALSE) {
  d <- as.Date(EXTRACT_DATE, "%y%m%d")
  stopifnot(!is.na(d))
  m <- if (short) month.abb else month.name
  sprintf("%d %s %s", as.integer(format(d, "%d")), m[as.integer(format(d, "%m"))], format(d, "%Y"))
}

# --- geoBoundaries (pinned to a full commit SHA, not main) ------------------------
GB_SHA      <- "9469f09592ced973a3448cf66b6100b741b64c0d"
GB_DIR      <- sprintf("https://github.com/wmgeolab/geoBoundaries/raw/%s/releaseData/gbOpen/XKX/ADM0", GB_SHA)
GB_XKX_URL  <- file.path(GB_DIR, "geoBoundaries-XKX-ADM0.geojson")
GB_META_URL <- file.path(GB_DIR, "geoBoundaries-XKX-ADM0-metaData.json")
GB_XKX_RAW  <- file.path(RAW, "geoBoundaries-XKX-ADM0.geojson")
GB_META_RAW <- file.path(RAW, "geoBoundaries-XKX-ADM0-metaData.json")
GB_XKX_MD5  <- "26344328c84503f89b0564a071356b77"   # of the .geojson at GB_SHA

# --- Road classes and tags ---------------------------------------------------------
# ANALYST JUDGEMENT: what counts as a drivable road. Service roads and tracks are
# excluded. The class list is applied inside GDAL when the .pbf is converted.
HIGHWAY_CLASSES <- c(
  "motorway", "trunk", "primary", "secondary", "tertiary",
  "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link",
  "unclassified", "residential", "living_street")
EXTRA_TAGS <- c("oneway", "junction", "maxspeed", "surface", "access")
highway_where <- function() {
  sprintf("highway IN (%s)", paste(sprintf("'%s'", HIGHWAY_CLASSES), collapse = ","))
}
# What the converted GeoPackage was built with; written beside it and compared on
# every later run, so a cached file from another class list cannot be reused.
conversion_spec <- function() {
  c(paste("where:", highway_where()), paste("extra_tags:", paste(EXTRA_TAGS, collapse = ",")))
}
ROADS_GPKG <- file.path(PROC, sprintf("roads_%s-%s.gpkg", EXTRACT_STEM, EXTRACT_DATE))
ROADS_SPEC <- paste0(ROADS_GPKG, ".spec.txt")
# ANALYST JUDGEMENT: ways with these access values are not open to a private car.
ACCESS_EXCLUDED <- c("private", "no", "military")

# --- Model constants -----------------------------------------------------------------
UTM34N     <- 32634      # metric CRS for the grid, the snapping and the figure
GRID_KM    <- 2          # origin grid spacing
MAX_ROAD_M <- 2000       # origins further than this from a routable road are dropped
BENCH_TOL  <- 0.10       # sanity check: fastest-path distance within +/-10% of reference
WT_PROFILE <- "motorcar" # dodgr's car profile; speeds recorded by 04
ANCHORS    <- c(prishtina = "^Prisht", prizren = "^Prizren")   # regex on OSM place-node names

# --- Drawing constants (ANALYST JUDGEMENT, legibility only) -------------------------
# Shared by 06_figure.R and build_readme.R so the README reports what was drawn.
LW_RANGE     <- c(0.06, 2.6)  # ggplot linewidth for 1 route and where all routes meet, sqrt scale
LIGHT_MIX    <- 0.55          # colour of a 1-route edge: this share navy, the rest background
FULL_NAVY_AT <- 20            # routes per edge at which the colour reaches full navy

# --- Values reviewed for one extract -------------------------------------------------
# The numbers below were read from a full run on the extract with this MD5. With
# that extract a mismatch is an error. With any other extract the numbers are
# expected to differ, so a mismatch is reported with a warning and the run goes on.
REVIEWED <- list(
  extract_md5    = "3da99cd00efa35fc5b6a9eacd3c72825",
  n_grid         = 2717L,
  n_dropped_far  = 135L,
  n_unreachable  = 2L,
  n_routed       = 2580L,
  bench_model_km = 79.8)       # checked to 0.05 km
check_reviewed <- function(label, value, expected, md5, tol = 0) {
  if (is.na(expected)) {
    warning(sprintf("no reviewed value recorded for %s (run value %s)", label, format(value)),
            call. = FALSE)
    return(invisible(NA))
  }
  ok <- abs(value - expected) <= tol
  if (ok) return(invisible(TRUE))
  msg <- sprintf("%s: run value %s, reviewed value %s", label, format(value), format(expected))
  if (identical(md5, REVIEWED$extract_md5)) stop("reviewed extract, but ", msg, call. = FALSE)
  warning("different extract (MD5 ", md5, "); ", msg, call. = FALSE)
  invisible(FALSE)
}

# --- Routing model --------------------------------------------------------------------
# FASTEST ROUTE under dodgr's car speed per road class. No traffic, no turn or
# traffic-light penalties. OSM maxspeed and surface tags are deliberately NOT
# passed to dodgr, so every way of a class runs at the same assumed speed.

# Ways not open to a private car are removed before the graph is built.
routable_roads <- function(roads) {
  stopifnot("access" %in% names(roads), !any(duplicated(roads$osm_id)))
  cat("access values as tagged:\n")
  print(as.data.frame(table(access = roads$access, useNA = "ifany")))
  drop <- !is.na(roads$access) & roads$access %in% ACCESS_EXCLUDED
  cat(sprintf("ways removed for access in (%s): %d of %d\n",
              paste(ACCESS_EXCLUDED, collapse = ", "), sum(drop), nrow(roads)))
  list(roads = roads[!drop, ], n_removed = sum(drop),
       by_value = table(factor(roads$access[drop], levels = ACCESS_EXCLUDED)))
}

# One-way handling. Before the graph is built, the script sets three cases itself
# rather than leaving them to the routing package: oneway = "-1" (one-way against
# the drawn direction) is reversed and set to "yes"; roundabouts and circular
# junctions without a one-way tag are set to "yes". Any other value stops the run.
normalise_oneway <- function(roads) {
  ow <- roads$oneway
  cat("oneway values as tagged:\n")
  print(as.data.frame(table(oneway = ow, useNA = "ifany")))
  bad <- setdiff(unique(ow[!is.na(ow)]), c("yes", "no", "-1"))
  if (length(bad) > 0) stop("unhandled oneway value(s): ", paste(bad, collapse = ", "))
  rev <- !is.na(ow) & ow == "-1"
  if (any(rev)) {
    g <- sf::st_geometry(roads); g[rev] <- sf::st_reverse(g[rev]); sf::st_geometry(roads) <- g
    roads$oneway[rev] <- "yes"
  }
  rb <- roads$junction %in% "roundabout" & is.na(roads$oneway)
  ci <- roads$junction %in% "circular"   & is.na(roads$oneway)
  roads$oneway[rb | ci] <- "yes"
  counts <- c(reversed = sum(rev), roundabout = sum(rb), circular = sum(ci))
  cat(sprintf("oneway = -1 reversed and set to yes: %d | untagged roundabouts set to yes: %d | untagged circular junctions set to yes: %d\n",
              counts[["reversed"]], counts[["roundabout"]], counts[["circular"]]))
  attr(roads, "oneway_counts") <- counts
  roads
}

# Builds the time-weighted dodgr graph, asserts direction and speed handling, and
# keeps the largest connected component. Returns the graph and its diagnostics.
build_graph <- function(roads) {
  dodgr::dodgr_cache_off()
  r0 <- normalise_oneway(roads)
  counts <- attr(r0, "oneway_counts")
  r  <- r0[, c("osm_id", "highway", "oneway")]
  # any dodgr warning is an error here
  net <- withCallingHandlers(
    dodgr::weight_streetnet(r, wt_profile = WT_PROFILE, type_col = "highway", id_col = "osm_id"),
    warning = function(w) stop("dodgr warning treated as error: ", conditionMessage(w)))
  stopifnot(all(c("from_id", "to_id", "from_lon", "from_lat", "to_lon", "to_lat",
                  "d", "time", "highway", "way_id", "component") %in% names(net)))
  stopifnot(all(is.finite(net$d)), all(is.finite(net$time)), all(net$time > 0))

  # direction guard, on the FIRST segment of every way: a one-way way must be in
  # the graph in its drawn direction only, a two-way way in both directions.
  k  <- function(x1, y1, x2, y2) paste(round(x1, 7), round(y1, 7), round(x2, 7), round(y2, 7))
  ek <- k(net$from_lon, net$from_lat, net$to_lon, net$to_lat)
  co <- sf::st_coordinates(r)
  i1 <- which(!duplicated(co[, "L1"])); i2 <- i1 + 1
  fwd <- k(co[i1, 1], co[i1, 2], co[i2, 1], co[i2, 2]) %in% ek
  bwd <- k(co[i2, 1], co[i2, 2], co[i1, 1], co[i1, 2]) %in% ek
  built <- ifelse(fwd & bwd, "both", ifelse(fwd, "forward_only",
                  ifelse(bwd, "reverse_only", "absent")))
  ow <- ifelse(is.na(r$oneway), "no", r$oneway)
  cat("first segment of each way in the graph, by one-way value after the script's settings:\n")
  print(table(oneway = ow, graph = built))
  stopifnot(all(built[ow == "yes"] == "forward_only"))
  stopifnot(all(built[ow == "no"]  == "both"))

  # speed guard: every edge runs at exactly the profile speed of its class
  prof <- dodgr::weighting_profiles$weighting_profiles
  prof <- prof[prof$name == WT_PROFILE & prof$way %in% HIGHWAY_CLASSES, c("way", "max_speed")]
  stopifnot(setequal(prof$way, HIGHWAY_CLASSES), !anyNA(prof$max_speed))
  kmh <- net$d / net$time * 3.6
  stopifnot(all(abs(kmh - prof$max_speed[match(net$highway, prof$way)]) < 1e-6))
  names(prof) <- c("highway", "kmh")
  prof$profile <- WT_PROFILE
  prof$dodgr_version <- as.character(utils::packageVersion("dodgr"))

  net$d_weighted    <- net$time     # route on time: fastest path, no class preference
  net$time_weighted <- net$time

  comp <- as.data.frame(net) |>
    group_by(component) |>
    summarise(edges = n(), km = sum(d) / 1000,
              lon = mean(from_lon), lat = mean(from_lat), .groups = "drop") |>
    arrange(desc(km))
  main_id    <- comp$component[1]
  net_main   <- net[net$component == main_id, ]
  roads_main <- r[as.character(r$osm_id) %in% unique(as.character(net_main$way_id)), ]
  list(net = net_main, roads_main = roads_main, speeds = prof,
       fragments = comp[comp$component != main_id, ], n_components = nrow(comp),
       share_main = comp$km[1] / sum(comp$km), edges_all = nrow(net), ways_all = nrow(r),
       oneway_counts = counts)
}

# --- Snapping, in metres ----------------------------------------------------------------
# Graph vertices as points in UTM 34N, built once per script.
vertex_points <- function(verts) {
  xy <- sf::sf_project(sf::st_crs(4326), sf::st_crs(UTM34N), cbind(verts$x, verts$y))
  stopifnot(all(is.finite(xy)))
  sf::st_as_sf(data.frame(x = xy[, 1], y = xy[, 2]), coords = c("x", "y"), crs = UTM34N)
}
# Nearest vertex to each point (sfc in UTM 34N) and the distance moved, in metres.
snap_to_vertices <- function(vpts, pts) {
  stopifnot(sf::st_crs(pts) == sf::st_crs(UTM34N), sf::st_crs(vpts) == sf::st_crs(UTM34N))
  i <- sf::st_nearest_feature(pts, vpts)
  m <- as.numeric(sf::st_distance(pts, sf::st_geometry(vpts)[i], by_element = TRUE))
  list(i = i, m = m)
}

# OSM place node (matched by an explicit regex on its name) -> nearest graph vertex.
anchor_vertex <- function(places, verts, vpts, regex) {
  hit <- places[grepl(regex, places$name), ]
  if (nrow(hit) != 1) {
    print(sf::st_drop_geometry(hit))
    stop(sprintf("anchor regex '%s' matched %d place nodes, expected exactly 1", regex, nrow(hit)))
  }
  s  <- snap_to_vertices(vpts, sf::st_transform(sf::st_geometry(hit), UTM34N))
  ll <- sf::st_coordinates(hit)
  cat(sprintf("anchor %-10s -> OSM node %s (place = %s), moved %.0f m to vertex %s\n",
              regex, hit$osm_id, hit$place, s$m, verts$id[s$i]))
  stopifnot(s$m <= MAX_ROAD_M)
  list(id = verts$id[s$i], x = verts$x[s$i], y = verts$y[s$i], snap_m = s$m,
       osm_node = as.character(hit$osm_id), place = hit$place,
       node_lon = ll[1, 1], node_lat = ll[1, 2])
}

# The polygon that grid origins must fall inside (geoBoundaries XKX, UTM 34N).
# It places origins only and is never drawn.
origin_polygon <- function() {
  stopifnot(identical(unname(tools::md5sum(GB_XKX_RAW)), GB_XKX_MD5))
  p <- sf::st_read(GB_XKX_RAW, quiet = TRUE)
  stopifnot(nrow(p) == 1, p$shapeGroup == "XKX")
  sf::st_transform(sf::st_geometry(p), UTM34N)
}

# Grid origins -> fastest route to `dest` -> number of routes per directed edge.
# Origins are the centres of a regular grid that fall INSIDE `clip` (sfc, UTM 34N).
# Every origin ends with a status: dropped_far_from_road, unreachable, routed.
route_flows <- function(net, roads_main, verts, vpts, dest, clip) {
  roads_utm <- sf::st_transform(sf::st_geometry(roads_main), UTM34N)
  stopifnot(sf::st_crs(clip) == sf::st_crs(UTM34N))
  grid <- sf::st_make_grid(sf::st_as_sfc(sf::st_bbox(clip)),
                           cellsize = GRID_KM * 1000, what = "centers")
  n_bbox <- length(grid)
  grid   <- grid[lengths(sf::st_within(grid, clip)) > 0]
  n_grid <- length(grid)
  cat(sprintf("grid centres in the polygon's bounding box: %d | inside the polygon (origins): %d\n",
              n_bbox, n_grid))
  stopifnot(n_grid > 0)
  near   <- sf::st_nearest_feature(grid, roads_utm)
  road_m <- as.numeric(sf::st_distance(grid, roads_utm[near], by_element = TRUE))
  keep   <- road_m <= MAX_ROAD_M
  ll <- sf::st_coordinates(sf::st_transform(grid, 4326))
  ut <- sf::st_coordinates(grid)
  origins <- tibble::tibble(origin = seq_len(n_grid), lon = ll[, 1], lat = ll[, 2],
                            x_utm = ut[, 1], y_utm = ut[, 2], road_m = road_m,
                            status = ifelse(keep, NA_character_, "dropped_far_from_road"),
                            vertex = NA_character_, snap_m = NA_real_,
                            dist_km = NA_real_, time_min = NA_real_)
  # snap in metres (UTM 34N) to the nearest vertex of the routable network
  s <- snap_to_vertices(vpts, grid[keep])
  origins$vertex[keep] <- verts$id[s$i]
  origins$snap_m[keep] <- s$m
  snap_max_m <- max(s$m)
  cat(sprintf("origins moved to their nearest vertex: maximum move %.0f m, median %.0f m\n",
              snap_max_m, stats::median(s$m)))
  stopifnot(all(s$m >= origins$road_m[keep] - 1e-6))  # a vertex is never nearer than the road
  stopifnot(snap_max_m <= MAX_ROAD_M)                 # no origin moves more than the cap

  uv <- unique(origins$vertex[keep])
  dv <- dodgr::dodgr_dists(net, from = uv, to = dest$id)   # metres along the fastest path
  tv <- dodgr::dodgr_times(net, from = uv, to = dest$id)   # seconds along the fastest path
  dv <- setNames(as.numeric(dv[, 1]), uv); tv <- setNames(as.numeric(tv[, 1]), uv)
  origins$dist_km[keep]  <- dv[origins$vertex[keep]] / 1000
  origins$time_min[keep] <- tv[origins$vertex[keep]] / 60
  origins$status[keep]   <- ifelse(is.finite(origins$dist_km[keep]), "routed", "unreachable")
  n <- c(grid = n_grid, dropped_far = sum(!keep),
         routed = sum(origins$status == "routed"),
         unreachable = sum(origins$status == "unreachable"))
  cat(sprintf("origins inside polygon: %d | dropped, more than %d m from a routable road: %d | routed: %d | unreachable: %d\n",
              n[["grid"]], MAX_ROAD_M, n[["dropped_far"]], n[["routed"]], n[["unreachable"]]))
  if (n[["unreachable"]] > 0) {
    cat("unreachable origins (origin id, lon, lat, vertex):\n")
    print(as.data.frame(origins[origins$status == "unreachable", c("origin", "lon", "lat", "vertex")]),
          digits = 7)
  }
  stopifnot(!anyNA(origins$status))
  stopifnot(n[["routed"]] + n[["unreachable"]] + n[["dropped_far"]] == n[["grid"]])
  routed <- origins[origins$status == "routed", ]
  # time and distance agree with the speed range of the profile (10 to 90 km/h)
  stopifnot(all(is.finite(routed$time_min)))
  pos <- routed$dist_km > 0
  v   <- routed$dist_km[pos] / (routed$time_min[pos] / 60)
  stopifnot(all(v >= 10 - 1e-6), all(v <= 90 + 1e-6))

  cnt <- as.data.frame(table(vertex = routed$vertex), stringsAsFactors = FALSE)
  cnt <- cnt[cnt$vertex != dest$id, ]      # an origin sitting on the destination has no route
  fl <- dodgr::dodgr_flows_aggregate(net, from = cnt$vertex, to = dest$id,
                                     flows = matrix(cnt$Freq, ncol = 1),
                                     contract = TRUE, norm_sums = FALSE, quiet = TRUE)
  # accounting identity: every route ends at the destination
  inflow <- sum(fl$flow[fl$to_id == dest$id])
  cat(sprintf("routes arriving at destination: %.3f | routed origins not on destination: %d\n",
              inflow, sum(cnt$Freq)))
  stopifnot(abs(inflow - sum(cnt$Freq)) < 1e-6)

  seg <- as.data.frame(fl[fl$flow > 0, c("from_lon", "from_lat", "to_lon", "to_lat",
                                         "flow", "highway", "d")])
  stopifnot(nrow(seg) > 0, max(seg$flow) <= sum(cnt$Freq) + 1e-6)
  p1 <- sf::sf_project(sf::st_crs(4326), sf::st_crs(UTM34N), as.matrix(seg[, c("from_lon", "from_lat")]))
  p2 <- sf::sf_project(sf::st_crs(4326), sf::st_crs(UTM34N), as.matrix(seg[, c("to_lon", "to_lat")]))
  seg$x1 <- p1[, 1]; seg$y1 <- p1[, 2]; seg$x2 <- p2[, 1]; seg$y2 <- p2[, 2]
  dxy <- sf::sf_project(sf::st_crs(4326), sf::st_crs(UTM34N), cbind(dest$x, dest$y))
  list(origins = origins, seg = seg, n = n, n_at_dest = n[["routed"]] - sum(cnt$Freq),
       snap_max_m = snap_max_m, dest_utm = c(x = dxy[1, 1], y = dxy[1, 2]))
}

# --- Helpers ------------------------------------------------------------------------------
# House rules: cache (never re-download), save raw bytes before parsing, and a
# 2 s minimum delay between web requests.
polite_download <- function(url, dest) {
  if (file.exists(dest)) {
    cat("raw already present, skipping download:", dest, "\n")
    return(invisible(FALSE))
  }
  options(timeout = 3600)
  utils::download.file(url, dest, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
  cat("downloaded:", dest, "\n")
  invisible(TRUE)
}

# Timing and R-heap peak for the end of each script.
report_resources <- function(t0, label) {
  el <- (proc.time() - t0)[["elapsed"]]
  g  <- gc()
  cat(sprintf("[resources] %s: elapsed %.1f s | R heap peak %.0f MB\n",
              label, el, sum(g[, 6])))
}

wrap <- function(x, w) paste(strwrap(x, width = w), collapse = "\n")
