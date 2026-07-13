# ==============================================================================
# 01_functions.R  —  Reusable helpers for the census "empty homes" piece.
# Kosova 2011 vs 2024 census: population decline vs vacant dwellings.
# Author: Plator Krasniqi.  Open data only (ASK PxWeb, geoBoundaries, ASK report).
# Sourced by 02–05; not run directly.
# ==============================================================================
suppressWarnings(suppressMessages({ library(pxweb) }))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# --- ASK PxWeb -----------------------------------------------------------------
# English database node; the /PXWeb/ path variant returns HTTP 500, the plain
# /api/v1/en/ASKdata node is the working one (resolved by probe, 2026-07-13).
ASK_BASE <- "https://askdata.rks-gov.net/api/v1/en/ASKdata"

# Pull one PxWeb table as a labelled data frame. `query` is a named list of
# dimension code -> selected value codes (use "*" for all). 2s delay = house rule.
ask_pull <- function(table_url, query, polite = TRUE) {
  q  <- pxweb_query(query)
  px <- pxweb_get(table_url, query = q)
  df <- as.data.frame(px, column.name.type = "text", variable.value.type = "text")
  if (polite) Sys.sleep(2)
  df
}

# --- Municipality names --------------------------------------------------------
# Standardise geoBoundaries ADM2 shapeName -> house-style Albanian labels.
# (Extends the mapping used in ../ookla-digital-divide/R/01_functions.R.)
clean_muni_names <- function(x) {
  x <- sub("^Municipality of ", "", x)
  dplyr::recode(x,
    "Pristina"        = "Prishtina",
    "Gracanica"       = "Graçanica",
    "Mamusha"         = "Mamushë",
    "North Mitrovica" = "Mitrovica e Veriut"
  )
}
