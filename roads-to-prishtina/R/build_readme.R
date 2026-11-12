# ==============================================================================
# build_readme.R   (unnumbered: run by hand after 06_figure.R, so the README is
# not silently rewritten by the numbered run)
# Generates README.md for the piece and records the software versions it was
# generated with. Every number in the README is built here with sprintf() from
# the pipeline's recorded outputs and constants; none is typed.
# Reads:  data/processed/figures_kosova.json, network_summary_kosova.json,
#         benchmark_kosova.csv, origins_kosova.csv, fragments_kosova.csv,
#         speed_profile_kosova.csv, boundary_record.csv, network_kosova.rds,
#         data/raw/kosovo-<yymmdd>.osm.pbf and its .md5
# Writes: README.md, output/session_info.txt
# Concept notes:
#  - Guards: recorded outputs must agree with each other (JSON vs origins table,
#    JSON vs benchmark table, local MD5 vs Geofabrik's, all outputs from the same
#    extract). The reviewed values in 01_functions.R are tied to one extract MD5:
#    with that extract a mismatch stops the script; with another extract it is
#    reported with a warning and the README is written from the run's numbers.
#  - Wording guard: the generated text is checked, case-insensitively, for the
#    country name in a non-house spelling (source-controlled file names are
#    taken out first), for causal wording, and for labels the piece does not
#    use for itself. A hit stops the script.
# Run from the piece root:  Rscript R/build_readme.R
# ==============================================================================
source("R/01_functions.R")
suppressWarnings(suppressMessages({
  library(readr); library(tibble); library(jsonlite); library(osmextract); library(dodgr)
  library(ggplot2); library(scales); library(showtext); library(magick)
}))
n <- function(x) format(x, big.mark = ",", trim = TRUE)
long_date <- function(d) sprintf("%d %s %s", as.integer(format(d, "%d")),
                                 month.name[as.integer(format(d, "%m"))], format(d, "%Y"))

# ---- recorded outputs ----------------------------------------------------------
fig   <- jsonlite::read_json(file.path(PROC, sprintf("figures_%s.json", TAG)), simplifyVector = TRUE)
ns    <- jsonlite::read_json(file.path(PROC, sprintf("network_summary_%s.json", TAG)), simplifyVector = TRUE)
bench <- read_csv(file.path(PROC, sprintf("benchmark_%s.csv", TAG)), show_col_types = FALSE)
orig  <- read_csv(file.path(PROC, sprintf("origins_%s.csv", TAG)), show_col_types = FALSE)
frag  <- read_csv(file.path(PROC, sprintf("fragments_%s.csv", TAG)), show_col_types = FALSE)
speed <- read_csv(file.path(PROC, sprintf("speed_profile_%s.csv", TAG)), show_col_types = FALSE)
bnd   <- read_csv(file.path(PROC, "boundary_record.csv"), show_col_types = FALSE)
net   <- readRDS(file.path(PROC, sprintf("network_%s.rds", TAG)))
fig_png <- sprintf("output/roads_to_prishtina_%s_linkedin_1200.png", TAG)
stopifnot(file.exists(file.path(PROJ, fig_png)))

# ---- raw extract: one extract behind every output ------------------------------------
md5_published <- strsplit(trimws(readLines(paste0(PBF, ".md5"), warn = FALSE)[1]), "\\s+")[[1]][1]
md5 <- unname(tools::md5sum(PBF))
stopifnot(identical(md5_published, md5), nchar(md5) == 32)
stopifnot(identical(fig$extract_md5, md5), identical(ns$extract_md5, md5))
stopifnot(fig$extract_date == EXTRACT_DATE)

# ---- origins: JSON and origins table agree; reviewed values ----------------------
st <- table(factor(orig$status, levels = c("dropped_far_from_road", "unreachable", "routed")))
stopifnot(!anyNA(orig$status), sum(st) == nrow(orig))
stopifnot(nrow(orig) == fig$n_grid,
          st[["dropped_far_from_road"]] == fig$n_dropped_far,
          st[["unreachable"]] == fig$n_unreachable,
          st[["routed"]] == fig$n_routed)
stopifnot(fig$n_dropped_far + fig$n_unreachable + fig$n_routed == fig$n_grid)   # identity
stopifnot(fig$grid_km == GRID_KM, fig$max_road_m == MAX_ROAD_M)
stopifnot(fig$graph_edges == nrow(net), fig$graph_edges == ns$edges_main)
stopifnot(fig$n_at_dest == 0, fig$max_flow == fig$n_routed)   # all routes meet at the destination
routed <- orig[orig$status == "routed", ]
stopifnot(all(is.finite(routed$snap_m)), abs(max(routed$snap_m, orig$snap_m, na.rm = TRUE) - fig$snap_max_m) < 1e-6,
          fig$snap_max_m <= MAX_ROAD_M)
check_reviewed("grid points",          fig$n_grid,        REVIEWED$n_grid,        md5)
check_reviewed("origins dropped",      fig$n_dropped_far, REVIEWED$n_dropped_far, md5)
check_reviewed("origins unreachable",  fig$n_unreachable, REVIEWED$n_unreachable, md5)
check_reviewed("origins routed",       fig$n_routed,      REVIEWED$n_routed,      md5)
med_km  <- stats::median(routed$dist_km);  max_km  <- max(routed$dist_km)
med_min <- stats::median(routed$time_min); max_min <- max(routed$time_min)
stopifnot(all(is.finite(c(med_km, max_km, med_min, max_min))))

# ---- benchmark -------------------------------------------------------------------
stopifnot(nrow(bench) == 1, bench$pair_id == "prizren_prishtina", isTRUE(bench$pass))
stopifnot(abs(bench$model_km - fig$benchmark$model_km) < 1e-4, bench$ref_km == fig$benchmark$ref_km)
stopifnot(abs(bench$ratio - bench$model_km / bench$ref_km) < 1e-9, abs(bench$ratio - 1) <= BENCH_TOL)
stopifnot(grepl("Google Maps", bench$source), !is.na(bench$accessed),
          is.finite(bench$model_min), is.finite(bench$ref_min))
check_reviewed("benchmark model km", bench$model_km, REVIEWED$bench_model_km, md5, tol = 0.05)
bench_date <- long_date(as.Date(bench$accessed))
time_ratio <- bench$model_min / bench$ref_min

# ---- network -----------------------------------------------------------------------
stopifnot(ns$ways_converted - ns$ways_access_removed == ns$ways_routable)        # identity
stopifnot(sum(unlist(ns$ways_access_removed_by_value)) == ns$ways_access_removed,
          setequal(names(ns$ways_access_removed_by_value), ACCESS_EXCLUDED))
stopifnot(ns$fragments == nrow(frag), ns$components == ns$fragments + 1)
main_km <- sum(net$d) / 1000                       # directed edge length, as in the fragments table
stopifnot(abs(main_km / (main_km + sum(frag$km)) - ns$share_main) < 1e-9,
          ns$share_main >= 0.90, ns$share_main < 1)
stopifnot(setequal(speed$highway, HIGHWAY_CLASSES), all(speed$profile == WT_PROFILE),
          length(unique(speed$dodgr_version)) == 1, speed$dodgr_version[1] == fig$dodgr_version)
kmh <- net$d / net$time * 3.6                      # the graph on disk runs at the table's speeds
stopifnot(all(abs(kmh - speed$kmh[match(net$highway, speed$highway)]) < 1e-6))
share_edges <- fig$n_edges_with_route / fig$graph_edges

# ---- boundary -------------------------------------------------------------------------
stopifnot(nrow(bnd) == 1, bnd$commit == GB_SHA, nchar(GB_SHA) == 40, bnd$md5 == GB_XKX_MD5,
          identical(unname(tools::md5sum(GB_XKX_RAW)), GB_XKX_MD5))

# ---- software versions, to a file the README cites ---------------------------------------
ses_file <- "output/session_info.txt"
ext <- sf::sf_extSoftVersion()
writeLines(c(
  "Software versions on the machine that ran the pipeline, recorded when the README was generated.",
  "",
  sprintf("GDAL %s | PROJ %s | GEOS %s", ext[["GDAL"]], ext[["PROJ"]], ext[["GEOS"]]),
  "",
  utils::capture.output(print(utils::sessionInfo(), locale = FALSE))),
  file.path(PROJ, ses_file))
stopifnot(utils::packageVersion("dodgr") == fig$dodgr_version)

speed_tbl <- c("| OSM road class (`highway`) | Assumed speed, km/h |", "|---|---|",
               sprintf("| `%s` | %s |", speed$highway, format(speed$kmh)))
acc <- ns$ways_access_removed_by_value

# ---- text ----------------------------------------------------------------------------
md <- c(
"# Të gjitha rrugët të çojnë në Prishtinë — All roads lead to Prishtina",
"",
"A map of modelled fastest driving routes to Prishtina from evenly spaced points across Kosova, built on the road network from OpenStreetMap, routed in R with dodgr.",
"",
sprintf("**The figure draws the modelled fastest driving route to Prishtina from %s of the %s points of a %s km grid over Kosova, and draws a road thicker the more of those routes share it. It carries no statistic: it shows the shape of the road network as seen from one destination under one fixed set of speed assumptions.**",
        n(fig$n_routed), n(fig$n_grid), format(fig$grid_km)),
"",
sprintf("![All roads lead to Prishtina](%s)", fig_png),
"",
"## What the figure shows",
"",
sprintf("Each line is a piece of road used by at least one modelled route to Prishtina; %s directed network edges are drawn. A route starts at a grid point, is moved to the nearest point of the road network, and follows the fastest path to one destination point in Prishtina under an assumed speed for each class of road. Where routes from many points join the same road, the line gets wider, so the widest lines are the roads shared by the most starting points, not the roads with the most vehicles. All routes end at the same point by construction, so the lines get wider towards Prishtina whatever the network looks like. No boundary is drawn; the extent of the lines follows the polygon used to place the grid points, since only points inside it are origins. Prishtina is the only label.",
        n(fig$n_edges_with_route)),
"",
"## Data sources (all open)",
"",
sprintf("- **Roads:** © OpenStreetMap contributors, Open Database Licence (ODbL) 1.0, <https://www.openstreetmap.org/copyright>, via Geofabrik (download.geofabrik.de > Europe > `%s`). Extract of %s, %s bytes, MD5 `%s`; the local file matches the MD5 that Geofabrik publishes beside it. Geofabrik's file name is kept as published.",
        basename(PBF), extract_date_txt(), n(file.size(PBF)), md5),
sprintf("- **Polygon for placing origins:** geoBoundaries gbOpen, `XKX` ADM0 (wmgeolab/geoBoundaries > releaseData > gbOpen > XKX > ADM0), pinned to commit `%s`, file MD5 `%s`. Its metadata file gives the licence as \"%s\" and the source as \"%s\". The polygon decides which grid points are origins and is not drawn.",
        bnd$commit, bnd$md5, bnd$licence, bnd$source),
sprintf("- **Sanity check only, not an input:** one driving distance and time read from Google Maps on %s (Method, step 9). Nothing from Google Maps enters the routes or the figure.", bench_date),
"- Raw downloads and processed data are not committed; the scripts regenerate them.",
"",
"## Method",
"",
"Every item below is an analyst choice unless it says otherwise.",
"",
sprintf("1. **Origins: a %s km grid clipped to the country polygon.** Grid centres are laid out every %s km in UTM zone 34N over the polygon's bounding box; the %s centres inside the polygon are the origins. They are evenly spaced points and carry no population weight.",
        format(fig$grid_km), format(fig$grid_km), n(fig$n_grid)),
sprintf("2. **Destination: one point.** The destination is the OpenStreetMap place node for the city (node `%s`, at %.5f° N, %.5f° E), moved %.0f m to the nearest vertex of the road network (%.5f° N, %.5f° E). Every route ends at that vertex.",
        fig$dest$osm_node, fig$dest$node_lat, fig$dest$node_lon, fig$dest$snap_m,
        fig$dest$vertex_lat, fig$dest$vertex_lon),
sprintf("3. **Road classes and access.** %s OSM ways in %d `highway` classes are read (the classes in the table below); service roads and tracks are left out. Of these, %s ways tagged `access=private` (%s), `access=no` (%s) or `access=military` (%s) are removed, which leaves %s ways.",
        n(ns$ways_converted), length(HIGHWAY_CLASSES), n(ns$ways_access_removed),
        n(acc[["private"]]), n(acc[["no"]]), n(acc[["military"]]), n(ns$ways_routable)),
sprintf("4. **Snap cap of %s km.** An origin more than %s km from a road of the routable network is dropped: %s origins. Each remaining origin is moved to its nearest network vertex, with distances measured in metres in UTM zone 34N; the largest move is %s m, and the script stops if any origin moves more than %s km. %s origins sit on a vertex with no directed path to the destination and are reported as unreachable. %s origins are routed (%s + %s + %s = %s).",
        format(fig$max_road_m / 1000), format(fig$max_road_m / 1000), n(fig$n_dropped_far),
        n(round(fig$snap_max_m)), format(fig$max_road_m / 1000),
        n(fig$n_unreachable), n(fig$n_routed), n(fig$n_dropped_far), n(fig$n_unreachable),
        n(fig$n_routed), n(fig$n_grid)),
sprintf("5. **Speeds: dodgr's fixed car profile.** Every road runs at the speed that dodgr %s assigns to its class in the `%s` profile, shown below. These are assumed speeds. OSM `maxspeed` and `surface` tags are not used. The script asserts that every edge of the graph runs at exactly its class speed.",
        fig$dodgr_version, fig$wt_profile),
"",
speed_tbl,
"",
"6. **No turn or traffic penalties.** The fastest route is the path with the lowest total of (length ÷ class speed). There is no delay for turns, junctions or traffic lights, and no traffic.",
sprintf("7. **One-way streets and roundabouts.** One-way tags are kept. Before the graph is built the script sets three cases itself: %s ways tagged `oneway=-1` (one-way against the drawn direction) have their geometry reversed and are set to one-way; %s roundabouts and %s circular junctions without a one-way tag are set to one-way. The script stops on any other `oneway` value. It then checks the first segment of every way: a one-way way must be in the graph in its drawn direction only, a two-way way in both directions.",
        n(ns$oneway_reversed), n(ns$roundabouts_set_oneway), n(ns$circular_set_oneway)),
sprintf("8. **Disconnected fragments dropped.** Only the largest connected part of the network is routed. It holds %.2f%% of the network's directed edge length; %s smaller fragments make up the rest and are dropped, not patched.",
        100 * ns$share_main, n(ns$fragments)),
sprintf("9. **Sanity check on one distance.** Before any grid routing, the distance along the model's fastest path from Prizren to Prishtina is compared with the Google Maps driving distance for the same pair: %.1f km in the model against %s km in Google Maps (read on %s), a ratio of %.2f. The tolerance is ±%s%%; outside it the script stops. The check compares distance only, not travel time. Anchors are the OSM place nodes of the two cities.",
        bench$model_km, format(bench$ref_km), bench_date, bench$ratio, format(100 * BENCH_TOL)),
sprintf("10. **Line width and colour.** Width follows the square root of the number of routes on an edge, between %s and %s ggplot2 line-width units. Colour is opaque: an edge with one route is drawn in a mix of %s%% navy and %s%% background, the mix reaches full navy at %s routes per edge on a log scale, and stays navy above that. Heavier edges are drawn on top. These are drawing choices for legibility.",
        format(LW_RANGE[1]), format(LW_RANGE[2]), format(100 * LIGHT_MIX),
        format(100 * (1 - LIGHT_MIX)), format(FULL_NAVY_AT)),
"11. **Label.** The label sits in the nearest area with no line under it and is joined to the destination by a leader line; its position is a drawing choice.",
"",
"## Key results",
"",
"These describe the model run, not travel in Kosova.",
"",
sprintf("- %s of %s grid points (%.1f%%) are routed; %s are dropped for lying more than %s km from a routable road and %s are unreachable.",
        n(fig$n_routed), n(fig$n_grid), 100 * fig$n_routed / fig$n_grid, n(fig$n_dropped_far),
        format(fig$max_road_m / 1000), n(fig$n_unreachable)),
sprintf("- %s of the %s directed edges of the routed network (%.1f%%) carry at least one route.",
        n(fig$n_edges_with_route), n(fig$graph_edges), 100 * share_edges),
sprintf("- The median modelled route is %.0f km long and takes %.0f minutes at the assumed speeds; the longest is %.0f km and %.0f minutes.",
        med_km, med_min, max_km, max_min),
sprintf("- The Prizren–Prishtina check gives %.1f km in the model against %s km in Google Maps.",
        bench$model_km, format(bench$ref_km)),
"",
"## Reproduce",
"",
sprintf("%s, dodgr %s. The full package list and the GDAL, PROJ and GEOS versions are in [`%s`](%s).",
        R.version.string, fig$dodgr_version, ses_file, ses_file),
"",
"Run from the piece root, in order:",
"",
"```",
"Rscript R/02_pull_osm.R        # Geofabrik extract and its MD5 (cached, never re-downloaded)",
"Rscript R/03_pull_boundary.R   # geoBoundaries polygon and its metadata",
"Rscript R/04_build_network.R   # road filter, access filter, one-way settings, graph, fragments",
"Rscript R/05_build_routes.R    # sanity check, origins, routes",
"Rscript R/06_figure.R          # figure",
"Rscript R/build_readme.R       # this README and the software-version file",
"```",
"",
sprintf("`R/01_functions.R` holds the constants and helpers and is sourced, not run. Geofabrik keeps dated extracts for a limited time, so the extract of %s may no longer be downloadable. A later extract gives slightly different numbers: the scripts then report each difference from the numbers above with a warning and carry on, while the checks that do not depend on the extract still stop the run.",
        extract_date_txt()),
"",
"## Outputs",
"",
sprintf("- `%s`: the figure, 1200 px wide, downscaled from a 2000 px render (the 2000 px file is written beside it and not committed).", fig_png),
sprintf("- `%s`: software versions.", ses_file),
sprintf("- `data/processed/` (not committed): `figures_%s.json`, `network_summary_%s.json`, `benchmark_%s.csv`, `origins_%s.csv`, `flows_%s.rds`, `fragments_%s.csv`, `speed_profile_%s.csv`, `boundary_record.csv`, `network_%s.rds`, `roads_main_%s.rds`, `places_%s.rds` and the converted roads file.",
        TAG, TAG, TAG, TAG, TAG, TAG, TAG, TAG, TAG, TAG),
"- `data/lookup_benchmark.csv`: the reference distance and time for the sanity check, with source and date.",
"",
"## Limitations",
"",
"- **Origins are evenly spaced points, not people or traffic.** A wide line means many grid points share that road on their modelled route. It says nothing about how many people live at those points or how many vehicles use the road. Separating these would need population by grid cell and traffic counts, neither of which is used here.",
"- **One destination, by construction.** Every route ends at the same point, so lines widen towards it in any network. The figure does not compare Prishtina with other destinations.",
"- **Speeds are assumed per road class, not measured.** Two roads of the same class run at the same speed, whether flat and straight or steep and winding. Posted limits, surface, gradient, congestion and weather are ignored, and so are delays at turns and junctions. Modelled routes can differ from the routes drivers take.",
sprintf("- **Travel time is not checked, and differs on the one pair looked at.** The sanity check compares distance only. For Prizren–Prishtina the model's travel time is %.0f minutes against %s minutes in Google Maps at the time of reading, a ratio of %.2f. Modelled times should not be read as travel times.",
        bench$model_min, format(bench$ref_min), time_ratio),
"- **The sanity check is one pair.** It compares one route with one Google Maps reading, which depends on traffic at the time it was read. One pair inside the tolerance does not validate the routes elsewhere.",
"- **OpenStreetMap completeness is not verified.** A road missing from OSM, or tagged in a class outside the list, does not exist for the model; a wrongly tagged one-way street or access restriction changes the routes around it. Access restrictions tagged in other ways than the three values removed are not considered.",
sprintf("- **Blank areas are not measured as roadless.** %s origins are left out for lying more than %s km from a road in the listed classes, and the dropped fragments carry no routes. A gap in the figure means no route was modelled there.",
        n(fig$n_dropped_far), format(fig$max_road_m / 1000)),
"- **The network ends at the edge of the extract.** A route cannot use a road outside the Geofabrik extract, so for origins near the edge the modelled route may be longer than one that crosses out and back in.",
"- **Width, colour and label position are drawing choices**, not measurements.",
"",
"Data: © OpenStreetMap contributors (ODbL) via Geofabrik; geoBoundaries. Analysis: Plator Krasniqi.",
"")

# ---- wording guards --------------------------------------------------------------------
txt <- paste(md, collapse = "\n")
prose <- gsub(basename(PBF), "", txt, fixed = TRUE)                  # source-controlled file name
stopifnot(!grepl("kosovo", prose, ignore.case = TRUE))               # house spelling, any case
causal <- c("causes", "drives", "leads to", "results in", "reduces", "boosts",
            "because of", "the effect of", "impact")
hit <- causal[vapply(causal, function(w) grepl(w, txt, ignore.case = TRUE), TRUE)]
if (length(hit) > 0) stop("causal wording in README: ", paste(hit, collapse = ", "))
stopifnot(!grepl("\\bGIS\\b|spatial|accessib|busiest", txt, ignore.case = TRUE))
stopifnot(!anyNA(md), !grepl("\\bNA\\b|NaN", txt))

con <- file(file.path(PROJ, "README.md"), open = "wb")
writeLines(enc2utf8(md), con, sep = "\n", useBytes = TRUE); close(con)

cat(sprintf("extract MD5 %s | reviewed extract: %s\n", md5, identical(md5, REVIEWED$extract_md5)))
cat(sprintf("origins %s = dropped %s + unreachable %s + routed %s | largest snap %.0f m\n", n(fig$n_grid),
            n(fig$n_dropped_far), n(fig$n_unreachable), n(fig$n_routed), fig$snap_max_m))
cat(sprintf("ways read %s | access removed %s | routable %s | oneway=-1 %s | roundabouts %s | circular %s\n",
            n(ns$ways_converted), n(ns$ways_access_removed), n(ns$ways_routable),
            n(ns$oneway_reversed), n(ns$roundabouts_set_oneway), n(ns$circular_set_oneway)))
cat(sprintf("fragments %s | main share %.2f%% | edges with a route %s of %s (%.1f%%)\n",
            n(ns$fragments), 100 * ns$share_main, n(fig$n_edges_with_route), n(fig$graph_edges), 100 * share_edges))
cat(sprintf("routes: median %.0f km / %.0f min | longest %.0f km / %.0f min\n", med_km, med_min, max_km, max_min))
cat(sprintf("check: %.1f km vs %s km (ratio %.3f) | %.0f min vs %s min (ratio %.2f) | read %s\n",
            bench$model_km, format(bench$ref_km), bench$ratio, bench$model_min, format(bench$ref_min),
            time_ratio, bench_date))
cat("wrote README.md,", length(md), "lines, and", ses_file, "\n")
