# ==============================================================================
# 04_build_join.R
# Join census population (02) + dwellings/vacancy (03) onto geoBoundaries ADM2
# polygons via the reviewed lookup (data/lookup_municipalities.csv). Flags the
# boycott-affected municipalities and writes the analysis table (+ sf rds) used
# by 05_figure.R.
#
# House rule: if a join produces NAs, STOP and show the unmatched keys.
# Run from the piece root:  Rscript R/04_build_join.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(sf)
}))

proj <- "C:/Users/plato/Documents/kosovo-economy/census-vacancy"
source(file.path(proj, "R", "01_functions.R"))
raw_dir  <- file.path(proj, "data", "raw")
proc_dir <- file.path(proj, "data", "processed")

lk  <- read_csv(file.path(proj, "data/lookup_municipalities.csv"), show_col_types = FALSE)
pop <- read_csv(file.path(proc_dir, "population_by_municipality.csv"), show_col_types = FALSE)
vac <- read_csv(file.path(proc_dir, "vacancy_by_municipality.csv"), show_col_types = FALSE) |>
  filter(muni_ask != "KOSOVA")

# --- attach canonical name via lookup; stop on any unmatched key ----------------
stop_if_unmatched <- function(df, key, ref, label) {
  bad <- setdiff(df[[key]], ref)
  if (length(bad)) stop("Unmatched ", label, " keys: ", paste(bad, collapse = ", "))
}
stop_if_unmatched(pop, "muni_ask", lk$pxweb_pop, "population")
stop_if_unmatched(vac, "muni_ask", lk$pxweb_vac, "vacancy")

pop2 <- pop |> left_join(lk |> select(muni, shapeName, pxweb_pop), by = c("muni_ask" = "pxweb_pop"))
vac2 <- vac |> left_join(lk |> select(muni, pxweb_vac), by = c("muni_ask" = "pxweb_vac"))
stopifnot(!any(is.na(pop2$muni)), !any(is.na(vac2$muni)))

# --- assemble municipality analysis table (38) ---------------------------------
north <- c("Mitrovica e Veriut", "Leposaviq", "Zveçan", "Zubin Potok")
serb_south <- c("Graçanica", "Kllokot", "Ranillug", "Partesh", "Shtërpca")

dat <- pop2 |>
  select(muni, shapeName, pop_2011, pop_2024, pop_change_pct, has_2011) |>
  left_join(vac2 |> select(muni, conventional_2011, vacant_2011, vac_share_2011,
                           conventional_2024, vacant_2024, vac_share_2024),
            by = "muni") |>
  mutate(is_north      = muni %in% north,
         is_serb_south = muni %in% serb_south,
         in_scatter    = has_2011 & !is_north & !is_serb_south)

# --- assertions (house rule) ---------------------------------------------------
stopifnot(nrow(dat) == 38)
must_have <- c("pop_2024", "conventional_2024", "vacant_2024", "vac_share_2024")
for (c_ in must_have) if (any(is.na(dat[[c_]])))
  stop("Unexpected NA in ", c_, ": ", paste(dat$muni[is.na(dat[[c_]])], collapse = ", "))
# pop_2011 may be NA only for the 4 northern municipalities
na11 <- dat$muni[is.na(dat$pop_2011)]
if (!setequal(na11, north)) stop("pop_2011 NA set != northern four: ", paste(na11, collapse = ", "))

# --- join geometry (exact shapeName) -------------------------------------------
g <- st_read(file.path(raw_dir, "geoBoundaries-XKX-ADM2.geojson"), quiet = TRUE) |>
  select(shapeName) |> st_make_valid()
stop_if_unmatched(data.frame(shapeName = dat$shapeName), "shapeName", g$shapeName, "geometry")
sfdat <- g |> left_join(dat, by = "shapeName")
stopifnot(nrow(sfdat) == 38, !any(is.na(sfdat$muni)), all(!st_is_empty(sfdat)))

# --- save ----------------------------------------------------------------------
write_csv(st_drop_geometry(sfdat), file.path(proc_dir, "analysis_municipalities.csv"))
saveRDS(sfdat, file.path(proc_dir, "analysis_municipalities.rds"))

# --- report --------------------------------------------------------------------
cat("Joined 38 municipalities. Polygons OK, no unexpected NAs.\n")
cat(sprintf("National vacant 2024: %s | vacancy share 2024: %.1f%%\n",
    format(sum(dat$vacant_2024), big.mark = ","),
    100 * sum(dat$vacant_2024) / sum(dat$conventional_2024)))
cat(sprintf("Scatter municipalities (has 2011, not north, not Serb-south): %d\n", sum(dat$in_scatter)))
cat(sprintf("  shrinking among those: %d | growing: %d\n",
    sum(dat$in_scatter & dat$pop_change_pct < 0), sum(dat$in_scatter & dat$pop_change_pct >= 0)))
cat("Greyed on map (north):", paste(north, collapse = ", "), "\n")
cat("On map, off scatter (Serb-south):", paste(serb_south, collapse = ", "), "\n")
cat("\nWrote analysis_municipalities.csv + .rds to", proc_dir, "\n")
