# ==============================================================================
# 05_figure_e.R
# Lead figure: dumbbell chart (English labels). Women's and men's employment rates, ages 15-64,
# Kosova 2024, for the three pooled education categories plus an "All, 15-64"
# row from ASK's published Total row, set apart by a thin rule. The gap in
# percentage points is printed on every row; each sex's share of its working-age
# population per category is printed beside each category row.
#
# Input: data/processed/e3_pooled_2024.csv (03). No download.
# Every label is built with sprintf() from computed values; nothing is typed.
# Portrait 4:5, rendered once at 2400 x 3000 px, then the raster is downscaled
# with magick to 1200 x 1500 (house rule: never re-render smaller).
# No interpretation in the figure text (decision 2026-10-24).
#
# Writes: output/employment_gap_by_education_2024.png (2400x3000),
#         output/employment_gap_by_education_2024_linkedin_1200.png (1200x1500)
# Run from the piece root:  Rscript R/05_figure_e.R
# ==============================================================================
source("R/00_functions.R")
suppressWarnings(suppressMessages({ library(showtext); library(magick) }))

font_add_google("Source Sans 3", "ss3"); showtext_auto(); showtext_opts(dpi = 300)
navy <- "#1A4E8A"; rust <- "#C0552E"; off <- "#F7F5F2"; grey_na <- "#C4C4BD"
ink  <- "#23282D"; sub  <- "#5C636B"; grid <- "#E4E4E0"
wrap <- function(x, w) paste(strwrap(x, width = w), collapse = "\n")

OUT_DIR <- file.path(PROJ, "output"); dir.create(OUT_DIR, showWarnings = FALSE)
W_PX <- 2400; H_PX <- 3000; DPI <- 300

d <- read_csv(file.path(PROC_DIR, "e3_pooled_2024.csv"), show_col_types = FALSE)
cats <- c("No formal education or primary", "Upper secondary", "Tertiary")
stopifnot(nrow(d) == 4, setequal(d$pooled, c(cats, "All, 15-64")))
YEAR <- fromJSON(file.path(PROC_DIR, "figures.json"))$year

# Displayed values: rates and gap to 1 dp. The printed gap must equal the
# difference of the printed rates up to rounding.
d <- d |> mutate(rw = round(rate_Female, 1), rm = round(rate_Male, 1),
                 gp = round(gap_pp, 1),
                 sw = round(100 * share_Female, 1), sm = round(100 * share_Male, 1))
stopifnot(all(abs((d$rm - d$rw) - d$gp) <= 0.1 + 1e-9))

# y positions: categories top to bottom, extra space, then the All row
ypos <- c("No formal education or primary" = 5, "Upper secondary" = 4, "Tertiary" = 3,
          "All, 15-64" = 1.4)
rule_y <- 2.2
d$y <- ypos[d$pooled]
d$is_all <- d$pooled == "All, 15-64"
# Display labels with an en dash; the data label stays as written by 03
d$label <- gsub("-", "–", d$pooled)
band_txt <- sub("^All, ", "", d$label[d$is_all])

X_SHARE_W <- 118; X_SHARE_M <- 136          # share columns, right of the 0-100 axis
pts <- d |> select(pooled, y, is_all, rw, rm) |>
  pivot_longer(c(rw, rm), names_to = "sex", values_to = "rate") |>
  mutate(sex = recode(sex, rw = "Women", rm = "Men"))

share_sum_w <- sum(d$sw[!d$is_all]); share_sum_m <- sum(d$sm[!d$is_all])
off_100 <- c(women = share_sum_w, men = share_sum_m)
off_100 <- off_100[abs(off_100 - 100) > 1e-9]
rounding_note <- if (length(off_100))
  paste0(" ", paste(sprintf("%s's shares sum to %.1f%%", tools::toTitleCase(names(off_100)), off_100),
                    collapse = "; "), " (rounding).") else ""

title_txt <- "Employment rate of women and men, by education"
share_hdr <- "% of each sex\nin this group"
sub_txt <- wrap(sprintf(paste0(
  "Kosova, %d, ages %s. Employed persons as a share of the population of the same sex ",
  "and education. The gap between the dots is in percentage points. Right: each sex's share ",
  "of its own working-age population in each category."), YEAR, band_txt), 78)
cap_txt <- paste0(wrap(paste0(
  "Categories pooled from ASK's five: 'No formal education or primary' = no formal education + ",
  "primary; 'Upper secondary' = secondary vocational + gymnasium. Pooled rates and shares use a ",
  "population derived from ASK's published employment and rates. 'All, ", band_txt, "' is ASK's ",
  "published total; the overall gap is not an average of the three rows, as women and men are ",
  "spread differently across the groups.",
  rounding_note), 118),
  "\nSource: ASK, Labour Force Survey ", YEAR, " (PxWeb tab3)  |  Analysis: Plator Krasniqi")

p <- ggplot() +
  geom_vline(xintercept = seq(0, 100, 20), colour = grid, linewidth = 0.3) +
  annotate("segment", x = -2, xend = 145, y = rule_y, yend = rule_y, colour = grey_na,
           linewidth = 0.4) +
  geom_segment(data = d, aes(x = rw, xend = rm, y = y, yend = y), colour = grey_na,
               linewidth = 2.2, lineend = "round") +
  geom_point(data = pts, aes(rate, y, colour = sex), size = 5.2) +
  geom_text(data = pts |> filter(sex == "Women"),
            aes(rate, y, label = sprintf("%.1f%%", rate)), colour = rust,
            family = "ss3", size = 3.6, vjust = 2.3) +
  geom_text(data = pts |> filter(sex == "Men"),
            aes(rate, y, label = sprintf("%.1f%%", rate)), colour = navy,
            family = "ss3", size = 3.6, vjust = 2.3) +
  geom_text(data = d, aes((rw + rm) / 2, y, label = sprintf("%.1f pp", gp)),
            colour = ink, family = "ss3", fontface = "bold", size = 3.9, vjust = -1.25) +
  geom_text(data = d, aes(-3, y, label = label), hjust = 1, colour = ink,
            family = "ss3", size = 4.0, fontface = ifelse(d$is_all, "bold", "plain")) +
  geom_text(data = d |> filter(!is_all), aes(X_SHARE_W, y, label = sprintf("%.1f%%", sw)),
            colour = rust, family = "ss3", size = 3.9) +
  geom_text(data = d |> filter(!is_all), aes(X_SHARE_M, y, label = sprintf("%.1f%%", sm)),
            colour = navy, family = "ss3", size = 3.9) +
  annotate("text", x = (X_SHARE_W + X_SHARE_M) / 2, y = 5.75,
           label = share_hdr, colour = sub, family = "ss3",
           size = 3.3, lineheight = 0.95) +
  annotate("text", x = X_SHARE_W, y = 5.42, label = "Women", colour = rust, family = "ss3",
           size = 3.4, fontface = "bold") +
  annotate("text", x = X_SHARE_M, y = 5.42, label = "Men", colour = navy, family = "ss3",
           size = 3.4, fontface = "bold") +
  scale_colour_manual(values = c(Women = rust, Men = navy), breaks = c("Women", "Men"),
                      name = NULL) +
  scale_x_continuous(limits = c(-62, 145), breaks = seq(0, 100, 20),
                     labels = function(x) sprintf("%d%%", as.integer(x)), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0.7, 6.1), expand = c(0, 0)) +
  labs(title = title_txt, subtitle = sub_txt, caption = cap_txt, x = NULL, y = NULL) +
  theme_minimal(base_family = "ss3", base_size = 11) +
  theme(plot.background = element_rect(fill = off, colour = NA),
        panel.grid = element_blank(),
        axis.text.y = element_blank(),
        axis.text.x = element_text(colour = sub, size = 9),
        legend.position = "top", legend.justification = "left",
        legend.text = element_text(colour = ink, size = 10),
        plot.title = element_text(colour = ink, face = "bold", size = 17,
                                  margin = margin(b = 6)),
        plot.subtitle = element_text(colour = sub, size = 10.5, lineheight = 1.1,
                                     margin = margin(b = 10)),
        plot.caption = element_text(colour = sub, size = 7.6, hjust = 0, lineheight = 1.1,
                                    margin = margin(t = 14)),
        plot.caption.position = "plot", plot.title.position = "plot",
        plot.margin = margin(30, 30, 24, 30))

# Wording guard on every string drawn in the figure, before anything is written
check_wording(c(title_txt, sub_txt, cap_txt, d$label, share_hdr, "Women", "Men"), "figure text")

hi <- file.path(OUT_DIR, "employment_gap_by_education_2024.png")
lo <- file.path(OUT_DIR, "employment_gap_by_education_2024_linkedin_1200.png")
ggsave(hi, p, width = W_PX, height = H_PX, units = "px", dpi = DPI, bg = off)
img <- image_read(hi)
stopifnot(image_info(img)$width == W_PX, image_info(img)$height == H_PX)
image_write(image_resize(img, "1200x1500!"), lo)
stopifnot(image_info(image_read(lo))$width == 1200, image_info(image_read(lo))$height == 1500)
cat("wrote", hi, "\nwrote", lo, "\n")

# Self-verifying run: print every number shown in the figure
for (i in seq_len(nrow(d)))
  cat(sprintf("%-32s women %5.1f%%  men %5.1f%%  gap %5.1f pp%s\n", d$pooled[i], d$rw[i], d$rm[i], d$gp[i],
              if (d$is_all[i]) "  (ASK Total row)" else sprintf("  | shares women %.1f%%  men %.1f%%", d$sw[i], d$sm[i])))
