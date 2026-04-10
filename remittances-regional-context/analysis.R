# ============================================================
# Kosovo Remittance Dependence in Regional Context
# Author: Plator Krasniqi
# Data: World Bank WDI (BX.TRF.PWKR.DT.GD.ZS)
# Last updated: April 2026
# ============================================================

library(wbstats)
library(ggplot2)
library(dplyr)
library(ggrepel)
library(patchwork)

# --- 1. Data download ---
countries <- c("XKX", "ALB", "MKD", "BIH", "SRB", "MNE", "EUU")

data_raw <- wb_data(
  indicator = "BX.TRF.PWKR.DT.GD.ZS",
  country   = countries,
  start_date = 2008,
  end_date   = 2024
)

# --- 2. Clean and label ---
data_clean <- data_raw %>%
  select(country, iso3c, date, remit_gdp = BX.TRF.PWKR.DT.GD.ZS) %>%
  filter(!is.na(remit_gdp)) %>%
  mutate(
    country_label = case_when(
      iso3c == "XKX" ~ "Kosovo",
      iso3c == "ALB" ~ "Albania",
      iso3c == "MKD" ~ "North Macedonia",
      iso3c == "BIH" ~ "Bosnia & Herz.",
      iso3c == "SRB" ~ "Serbia",
      iso3c == "MNE" ~ "Montenegro",
      iso3c == "EUU" ~ "EU average",
      TRUE ~ country
    ),
    group = case_when(
      iso3c == "XKX" ~ "kosovo",
      iso3c == "EUU" ~ "eu",
      TRUE ~ "other"
    )
  )

# --- 3. End-of-series labels (2024) ---
labels_2024 <- data_clean %>% filter(date == 2024)

# --- 4. Panel A: Time series ---
p1 <- ggplot(data_clean,
             aes(x = date, y = remit_gdp,
                 group = country_label,
                 color = group,
                 linewidth = group)) +
  geom_line() +
  geom_point(data = labels_2024, size = 2) +
  geom_text_repel(
    data          = labels_2024,
    aes(label     = paste0(country_label, " (", round(remit_gdp, 1), "%)")),
    hjust         = 0,
    nudge_x       = 1.5,
    direction     = "y",
    segment.color = "grey70",
    segment.size  = 0.3,
    size          = 3.0,
    box.padding   = 0.4,
    force         = 2
  ) +
  scale_color_manual(
    values = c("kosovo" = "#1a4e8a", "eu" = "#e05c2a", "other" = "#aab4c4")
  ) +
  scale_linewidth_manual(
    values = c("kosovo" = 1.4, "eu" = 1.0, "other" = 0.7)
  ) +
  scale_x_continuous(
    breaks = seq(2008, 2024, by = 4),
    limits = c(2008, 2028)
  ) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    title = "A: Remittances over time, 2008–2024",
    x     = NULL,
    y     = "Remittances (% of GDP)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "none",
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold", size = 11),
    plot.margin      = margin(10, 90, 10, 10)
  )

# --- 5. Panel B: 2024 snapshot bar chart ---
bar_data <- labels_2024 %>%
  arrange(remit_gdp) %>%
  mutate(country_label = factor(country_label, levels = country_label))

p2 <- ggplot(bar_data, aes(x = remit_gdp, y = country_label, fill = group)) +
  geom_col(width = 0.6) +
  geom_text(
    aes(label = paste0(round(remit_gdp, 1), "%")),
    hjust = -0.15, size = 3.2
  ) +
  scale_fill_manual(
    values = c("kosovo" = "#1a4e8a", "eu" = "#e05c2a", "other" = "#aab4c4")
  ) +
  scale_x_continuous(
    labels  = function(x) paste0(x, "%"),
    limits  = c(0, 23),
    expand  = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title = "B: 2024 snapshot",
    x     = "Remittances (% of GDP)",
    y     = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position        = "none",
    panel.grid.minor       = element_blank(),
    panel.grid.major.y     = element_blank(),
    plot.title             = element_text(face = "bold", size = 11),
    plot.margin            = margin(10, 20, 10, 10)
  )

# --- 6. Combine and save ---
combined <- p1 + p2 +
  plot_annotation(
    title    = "Kosovo's remittance dependence: an outlier in Europe",
    subtitle = "Personal remittances received as % of GDP, Western Balkans + EU average, 2008–2024",
    caption  = "Source: World Bank WDI (BX.TRF.PWKR.DT.GD.ZS). Author: Plator Krasniqi.",
    theme    = theme(
      plot.title    = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(color = "grey40", size = 10),
      plot.caption  = element_text(color = "grey50", size = 8)
    )
  )

ggsave("remittances_western_balkans.png", plot = combined,
       width = 13, height = 5.5, dpi = 300)

print(combined)
