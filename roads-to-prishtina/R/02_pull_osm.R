# ==============================================================================
# 02_pull_osm.R
# Downloads the dated Geofabrik OpenStreetMap extract
# (download.geofabrik.de > Europe > kosovo-<yymmdd>.osm.pbf) and the .md5 file
# Geofabrik publishes beside it.
# Writes: data/raw/kosovo-<yymmdd>.osm.pbf, data/raw/kosovo-<yymmdd>.osm.pbf.md5
# Raw files are gitignored; regenerate by rerunning this script. Geofabrik keeps
# dated files for a limited time only: once the file has expired, set
# EXTRACT_DATE in 01_functions.R to an available date (numbers will then differ).
# Licence: ODbL 1.0, (c) OpenStreetMap contributors.
# Run from the piece root:  Rscript R/02_pull_osm.R
# ==============================================================================
t0 <- proc.time()
source("R/01_functions.R")

md5f <- paste0(PBF, ".md5")
polite_download(paste0(PBF_URL, ".md5"), md5f)
polite_download(PBF_URL, PBF)

# ---- verify before proceeding ------------------------------------------------
md5_published <- strsplit(trimws(readLines(md5f, warn = FALSE)[1]), "\\s+")[[1]][1]
md5_local     <- unname(tools::md5sum(PBF))
cat(sprintf("\n== %s ==\n", basename(PBF)))
cat("bytes        :", file.size(PBF), "\n")
cat("md5 Geofabrik:", md5_published, "\n")
cat("md5 local    :", md5_local, "\n")
stopifnot(identical(md5_published, md5_local))
if (!identical(md5_local, REVIEWED$extract_md5)) {
  warning("this is not the extract the reviewed numbers were read from (MD5 ",
          REVIEWED$extract_md5, "); results will differ", call. = FALSE)
}

lay <- sf::st_layers(PBF)
cat("layers       :", paste(lay$name, collapse = ", "), "\n")
stopifnot("lines" %in% lay$name, "points" %in% lay$name)

smp <- sf::st_read(PBF, quiet = TRUE,
  query = "SELECT osm_id, name, highway FROM lines WHERE highway = 'motorway' LIMIT 5")
cat("columns      :", paste(names(smp), collapse = ", "), "\n")
print(sf::st_drop_geometry(smp))
stopifnot(nrow(smp) > 0)

report_resources(t0, "02_pull_osm")
