# ==============================================================================
# 03_chart.R
# Kosova minus euro-area HICP inflation gap, December to December, weight years
# 2016-2025, split into midpoint composition and within-division terms
# (DESIGN.md §3). 2026 YTD is not shown. Two versions from one plotting function:
#
#   GitHub   output/hicp_gap_decomposition.png   2000 x 1400 px
#            full subtitle; composition A-B range as a thin line beside each bar;
#            caption carries residual, Croatia, u-flag, back-calculation,
#            Eurostat conformity and undocumented weight-source-year notes.
#   LinkedIn output/hicp_gap_linkedin.png        1200 x 1500 px portrait
#            rendered once at 2000 x 2500 and downscaled with magick (house
#            rule: never re-render smaller). No range lines; a caption line
#            names the years whose dominance verdict depends on the ordering
#            (verdict "range" in the CSV). Residual, Croatia and u-flag notes
#            live in the README only.
#
# Both: stacked midpoint terms (navy = composition, rust = within-division),
# gap as a dot, 2025 emphasised with a background band, a gap label and a
# composition label. Every number shown is computed from the CSV.
#
# The LinkedIn caption also carries the back-calculation, conformity and weight-
# source-year notes (DECISIONS.md E1: weight-source note in both captions).
#
# Reads:  output/hicp_gap_decomposition.csv                 (build/02_decompose.R)
#         output/hicp_gap_xk_weight_sources.csv             (build/02_decompose.R)
#         data/raw/<date>/eurostat_prc_hicp_minr_XK_EA.rds  (vintage only)
# Run from the piece root:  Rscript build/03_chart.R
# ==============================================================================
suppressWarnings(suppressMessages({
  library(dplyr); library(readr); library(ggplot2); library(showtext); library(magick)
}))

PROJ  <- "C:/Users/plato/Documents/kosovo-economy/hicp-gap"
YEARS <- 2016:2025
EMPH  <- max(YEARS)
REPO  <- "github.com/platorpk/kosovo-economy"

font_add_google("Source Sans 3", "ss3"); showtext_auto(); showtext_opts(dpi = 300)
navy <- "#1A4E8A"; rust <- "#C0552E"; off <- "#F7F5F2"
ink  <- "#23282D"; sub  <- "#5C636B"; grid <- "#E4E4E0"

wrap   <- function(x, width) paste(strwrap(x, width = width), collapse = "\n")
minus  <- function(s) gsub("-", "\u2212", s, fixed = TRUE)   # typographic minus
pp     <- function(x) minus(sprintf("%+.1f pp", x))
# 2016, 2018, 2020, 2021 -> "2016, 2018 and 2020\u20132021"
year_runs <- function(y) {
  y <- sort(y); runs <- split(y, cumsum(c(1, diff(y) != 1)))
  s <- vapply(runs, function(r) if (length(r) == 1) as.character(r)
              else sprintf("%d\u2013%d", min(r), max(r)), "")
  if (length(s) == 1) s else paste(paste(s[-length(s)], collapse = ", "), "and", s[length(s)])
}

# ------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------
tab <- read_csv(file.path(PROJ, "output/hicp_gap_decomposition.csv"),
                col_types = cols(period = "c", type = "c", verdict = "c",
                                 seasonality_caveat = "c", .default = col_guess()))
yr <- tab |> filter(type == "year") |> mutate(year = as.integer(period), emph = year == EMPH)
stopifnot(identical(sort(yr$year), YEARS), !anyNA(yr$verdict))

dated <- sort(list.dirs(file.path(PROJ, "data/raw"), recursive = FALSE), decreasing = TRUE)
dated <- dated[file.exists(file.path(dated, "eurostat_prc_hicp_minr_XK_EA.rds"))]
vintage <- unique(readRDS(file.path(dated[1], "eurostat_prc_hicp_minr_XK_EA.rds"))[["LAST UPDATE"]])
stopifnot(length(vintage) == 1)
vintage <- sub(" .*$", "", vintage)                      # "17/09/26"

e <- yr |> filter(year == EMPH)
max_resid     <- max(abs(yr$resid_pp))
u_years       <- year_runs(yr$year[yr$ea_u_flag %in% TRUE])
ordering_yrs  <- yr$year[!yr$verdict %in% c("composition", "within-division")]
stopifnot(length(ordering_yrs) >= 1)

lab_gap  <- sprintf("%d gap %s", EMPH, pp(e$gap_pp))
lab_comp <- sprintf("Composition:\n%s", pp(e$comp_mid_pp))

backcalc_txt <- paste("Pre-2026 figures are back-calculated under the 2026 classification",
                      "(ECOICOP ver.2) and can differ from figures published at the time.")
conform_txt  <- paste("Eurostat notes that conformity of Kosova's HICP with HICP methodological",
                      "requirements has not been fully evaluated.")
# Weight source years not documented on Eurostat's XK metadata page (DECISIONS.md E1)
wsrc <- read_csv(file.path(PROJ, "output/hicp_gap_xk_weight_sources.csv"),
                 col_types = cols(source_text = "c", na_reference = "c", metadata_last_update = "c",
                                  metadata_url = "c", retrieved = "c", .default = col_guess()))
undoc <- wsrc$weight_year[!wsrc$documented & wsrc$in_window]
stopifnot(length(undoc) >= 1, all(undoc %in% YEARS), n_distinct(wsrc$metadata_last_update) == 1)
year_list <- function(y) if (length(y) == 1) as.character(y) else
  paste(paste(y[-length(y)], collapse = ", "), "and", y[length(y)])
wsrc_txt <- sprintf("Eurostat's Kosova metadata (updated %s) gives no weight source year for %s.",
                    sub("^\\d+ ", "", unique(wsrc$metadata_last_update)), year_list(undoc))
source_txt   <- sprintf("Source: Eurostat, prc_hicp_minr and prc_hicp_iw, data as of %s  |  Analysis: Plator Krasniqi",
                        vintage)

# ------------------------------------------------------------------------------
# Plot builder
# ------------------------------------------------------------------------------
build_plot <- function(title, subtitle, caption, legend_labels, show_range, s = 1) {
  bars <- bind_rows(
    yr |> transmute(year, emph, term = "comp",   value = comp_mid_pp),
    yr |> transmute(year, emph, term = "within", value = within_mid_pp)) |>
    mutate(term = factor(term, levels = c("within", "comp")))
  yl <- range(c(0, yr$gap_pp, yr$comp_A_pp, yr$comp_B_pp,
                with(bars, tapply(pmax(value, 0), year, sum)),
                with(bars, tapply(pmin(value, 0), year, sum)),
                e$comp_mid_pp - 0.55))                    # room for the composition label
  p <- ggplot() +
    annotate("rect", xmin = EMPH - 0.5, xmax = EMPH + 0.5, ymin = -Inf, ymax = Inf,
             fill = grid, alpha = 0.6) +
    geom_hline(yintercept = 0, colour = sub, linewidth = 0.35) +
    geom_col(data = bars, aes(x = year, y = value, fill = term, alpha = emph),
             width = 0.58, colour = off, linewidth = 0.35)
  if (show_range) p <- p +
    geom_linerange(data = yr, aes(x = year + 0.36, ymin = pmin(comp_A_pp, comp_B_pp),
                                  ymax = pmax(comp_A_pp, comp_B_pp), alpha = emph),
                   colour = navy, linewidth = 0.45)
  p + geom_point(data = yr, aes(x = year, y = gap_pp),
                 shape = 21, fill = ink, colour = off, stroke = 0.6, size = 2.3 * s) +
    annotate("text", x = EMPH - 0.36, y = e$gap_pp, label = lab_gap, hjust = 1,
             family = "ss3", size = 2.9 * s, colour = ink, fontface = "bold") +
    annotate("text", x = EMPH, y = e$comp_mid_pp - 0.12, label = lab_comp, vjust = 1,
             family = "ss3", size = 2.6 * s, colour = ink, lineheight = 0.95) +
    scale_fill_manual(values = c(comp = navy, within = rust),
                      breaks = c("comp", "within"), labels = legend_labels, name = NULL) +
    scale_alpha_manual(values = c(`TRUE` = 1, `FALSE` = 0.5), guide = "none") +
    scale_x_continuous(breaks = YEARS, expand = expansion(add = 0.4)) +
    scale_y_continuous(labels = function(x) ifelse(x == 0, "0", minus(sprintf("%+.0f", x))),
                       breaks = scales::breaks_width(1), expand = expansion(mult = 0.06)) +
    coord_cartesian(ylim = yl) +
    labs(title = title, subtitle = subtitle, caption = caption, x = NULL, y = "pp") +
    theme_minimal(base_family = "ss3", base_size = 10 * s) +
    theme(plot.background    = element_rect(fill = off, colour = NA),
          panel.grid.major.x = element_blank(),
          panel.grid.minor   = element_blank(),
          panel.grid.major.y = element_line(colour = grid, linewidth = 0.3),
          plot.title    = element_text(colour = ink, face = "bold", size = 14 * s, lineheight = 1.05),
          plot.subtitle = element_text(colour = sub, size = 9 * s, lineheight = 1.15,
                                       margin = margin(b = 8)),
          plot.caption  = element_text(colour = sub, size = 6.8 * s, hjust = 0, lineheight = 1.15,
                                       margin = margin(t = 10)),
          plot.caption.position = "plot", plot.title.position = "plot",
          axis.text    = element_text(colour = sub, size = 8.5 * s),
          axis.title.y = element_text(colour = sub, size = 8.5 * s, angle = 0, vjust = 1),
          legend.position = "top", legend.justification = "left",
          legend.text = element_text(colour = ink, size = 8.5 * s),
          legend.key.size = unit(9 * s, "pt"), legend.margin = margin(0, 0, 0, 0),
          plot.margin = margin(16, 18, 12, 14))
}

dir.create(file.path(PROJ, "output"), showWarnings = FALSE)

# ------------------------------------------------------------------------------
# GitHub version
# ------------------------------------------------------------------------------
gh_sub <- wrap(sprintf(paste(
  "Kosova minus euro area, December to December, percentage points, weight years %d\u2013%d.",
  "Composition: differences in division weights. Within-division: differences in rates",
  "inside the same division, which mixes price differences with differences in what each",
  "basket holds. Dot: the gap. Thin line: composition term under the two ordered variants."),
  min(YEARS), max(YEARS)), 105)
gh_cap <- paste0(wrap(sprintf(paste(
  "Midpoint decomposition at ECOICOP ver.2 division level (13 divisions); residual up to %.2f pp, not drawn.",
  "Euro area: changing composition; from 2023 it includes Croatia. %s: some euro-area division values",
  "flagged low reliability by Eurostat. %s %s %s"),
  max_resid, u_years, backcalc_txt, conform_txt, wsrc_txt), 140), "\n", source_txt)
p_gh <- build_plot("Kosova's HICP inflation gap with the euro area, by component",
                   gh_sub, gh_cap,
                   legend_labels = c("Composition", "Within-division"), show_range = TRUE)
gh_png <- file.path(PROJ, "output/hicp_gap_decomposition.png")
gh_tmp <- file.path(tempdir(), "hicp_gap_decomposition.png")
t0 <- Sys.time()
ggsave(gh_tmp, p_gh, width = 2000, height = 1400, units = "px", dpi = 300, bg = off)
stopifnot(file.copy(gh_tmp, gh_png, overwrite = TRUE),
          file.mtime(gh_png) >= t0 - 1,                    # really replaced, not stale
          image_info(image_read(gh_png))$width == 2000)

# ------------------------------------------------------------------------------
# LinkedIn version: render at 2000 x 2500, downscale to 1200 x 1500
# ------------------------------------------------------------------------------
li_title <- "What makes up Kosova's inflation gap with the euro area"
stopifnot(!grepl("HICP", li_title))
li_sub   <- "Kosova minus euro area, December to December, percentage points"
li_order <- sprintf("Splits for %s depend on decomposition ordering; see method.",
                    year_runs(ordering_yrs))
li_cap <- paste(wrap(li_order, 118), wrap(backcalc_txt, 118), wrap(conform_txt, 118),
                wrap(wsrc_txt, 118),
                sprintf("Method and caveats: %s", REPO),
                source_txt, sep = "\n")                    # source line never wrapped
p_li <- build_plot(wrap(li_title, 34), li_sub, li_cap,
                   legend_labels = c("Composition (different spending shares)", "Within categories"),
                   show_range = FALSE, s = 1.12)
li_big <- file.path(tempdir(), "hicp_gap_linkedin_2000.png")
t0 <- Sys.time()
ggsave(li_big, p_li, width = 2000, height = 2500, units = "px", dpi = 300, bg = off)
stopifnot(file.mtime(li_big) >= t0 - 1, image_info(image_read(li_big))$height == 2500)
li_png <- file.path(PROJ, "output/hicp_gap_linkedin.png")
image_write(image_resize(image_read(li_big), "1200x1500!"), li_png)
info <- image_info(image_read(li_png))
stopifnot(file.mtime(li_png) >= t0 - 1, info$width == 1200, info$height == 1500)

cat("wrote", gh_png, "\nwrote", li_png, "\n")
cat(sprintf("vintage %s | %s | 2025 composition %s | max |residual| %.4f pp | u-flag years %s\n",
            vintage, lab_gap, pp(e$comp_mid_pp), max_resid, u_years))
cat("ordering-dependent years (verdict 'range'):", year_runs(ordering_yrs), "\n")
