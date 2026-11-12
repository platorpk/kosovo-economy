# ==============================================================================
# 03_pull_boundary.R
# Downloads the geoBoundaries gbOpen ADM0 polygon for XKX and its metadata file,
# pinned to a full commit SHA (wmgeolab/geoBoundaries > releaseData > gbOpen >
# XKX > ADM0).
# Writes: data/raw/geoBoundaries-XKX-ADM0.geojson
#         data/raw/geoBoundaries-XKX-ADM0-metaData.json
#         data/processed/boundary_record.csv   (commit, checksum, licence, source)
# The polygon places the grid origins (only centres inside it are origins). It is
# NOT drawn on the figure.
# The source's own name label stays verbatim inside the files; prose uses "Kosova".
# Run from the piece root:  Rscript R/03_pull_boundary.R
# ==============================================================================
t0 <- proc.time()
source("R/01_functions.R")

polite_download(GB_XKX_URL, GB_XKX_RAW)
polite_download(GB_META_URL, GB_META_RAW)

xkx  <- sf::st_read(GB_XKX_RAW, quiet = TRUE)
meta <- jsonlite::read_json(GB_META_RAW)
md5  <- unname(tools::md5sum(GB_XKX_RAW))
cat("\n== verify ==\n")
cat("rows   :", nrow(xkx), "\n")
cat("columns:", paste(names(xkx), collapse = ", "), "\n")
print(sf::st_drop_geometry(xkx))
print(sf::st_bbox(xkx))
cat("md5    :", md5, "\n")
cat("licence:", meta$boundaryLicense, "| source:", meta$boundarySource, "| id:", meta$boundaryID, "\n")
stopifnot(nrow(xkx) == 1)
stopifnot("shapeGroup" %in% names(xkx), xkx$shapeGroup == "XKX")
stopifnot(identical(md5, GB_XKX_MD5))                      # the pinned file, byte for byte
stopifnot(meta$boundaryISO == "XKX", meta$boundaryType == "ADM0")
stopifnot(is.character(meta$boundaryLicense), nzchar(meta$boundaryLicense),
          is.character(meta$boundarySource), nzchar(meta$boundarySource))

readr::write_csv(tibble::tibble(
  file = basename(GB_XKX_RAW), commit = GB_SHA, md5 = md5,
  boundary_id = meta$boundaryID, licence = meta$boundaryLicense,
  source = meta$boundarySource), file.path(PROC, "boundary_record.csv"))

report_resources(t0, "03_pull_boundary")
