# ============================================================
# Kosovo Trade Structure in Regional Context
# Author: Plator Krasniqi
# Data: World Bank WDI
# Last updated: April 2026
# ============================================================
rm(list=ls())
install.packages("scales")
library(wbstats)
library(ggplot2)
library(dplyr)
library(tidyr)
library(ggrepel)
library(patchwork)
library(scales)

# --- 1. Data download ---
countries <- c("XKX", "ALB", "MKD", "BIH", "SRB", "MNE")

trade_raw <- wb_data(
  indicator  = c("NE.EXP.GNFS.ZS", "NE.IMP.GNFS.ZS", "BN.CAB.XOKA.GD.ZS"),
  country    = countries,
  start_date = 2008,
  end_date   = 2024
)

services_raw <- wb_data(
  indicator  = c("BX.GSR.NFSV.CD", "BX.GSR.MRCH.CD"),
  country    = "XKX",
  start_date = 2008,
  end_date   = 2024
)

# --- 2. Panel A: Kosovo exports vs imports over time ---
kosovo_trade <- trade_raw %>%
  filter(iso3c == "XKX") %>%
  select(date,
         Exports = NE.EXP.GNFS.ZS,
         Imports = NE.IMP.GNFS.ZS) %>%
  pivot_longer(cols      = c(Exports, Imports),
               names_to  = "flow",
               values_to = "pct_gdp")

# --- 3. Panel B: Kosovo services vs goods exports ---
services_clean <- services_raw %>%
  select(date,
         Services = BX.GSR.NFSV.CD,
         Goods    = BX.GSR.MRCH.CD) %>%
  mutate(
    Services = Services / 1e9,
    Goods    = Goods    / 1e9
  ) %>%
  pivot_longer(cols      = c(Services, Goods),
               names_to  = "type",
               values_to = "usd_bn")

# --- 4. Panel C: current account 2024 cross-country ---
ca_2024 <- trade_raw %>%
  filter(date == 2024) %>%
  select(country, iso3c, ca = BN.CAB.XOKA.GD.ZS) %>%
  mutate(
    country_label = case_when(
      iso3c == "XKX" ~ "Kosovo",
      iso3c == "ALB" ~ "Albania",
      iso3c == "MKD" ~ "North Macedonia",
      iso3c == "BIH" ~ "Bosnia & Herz.",
      iso3c == "SRB" ~ "Serbia",
      iso3c == "MNE" ~ "Montenegro"
    ),
    is_kosovo = iso3c == "XKX"
  ) %>%
  arrange(ca) %>%
  mutate(country_label = factor(country_label, levels = country_label))

# --- 5. Panel A plot ---
p1 <- ggplot(kosovo_trade,
             aes(x        = date,
                 y        = pct_gdp,
                 color    = flow,
                 linetype = flow)) +
  geom_line(linewidth = 1.1) +
  geom_point(
    data = kosovo_trade %>% filter(date == 2024),
    size = 2.5
  ) +
  geom_text_repel(
    data          = kosovo_trade %>% filter(date == 2024),
    aes(label     = paste0(flow, " (", round(pct_gdp, 1), "%)")),
    nudge_x       = 1.2,
    direction     = "y",
    segment.color = "grey70",
    segment.size  = 0.3,
    size          = 3.0,
    box.padding   = 0.4
  ) +
  scale_color_manual(
    values = c("Exports" = "#1a4e8a", "Imports" = "#e05c2a")
  ) +
  scale_linetype_manual(
    values = c("Exports" = "solid", "Imports" = "dashed")
  ) +
  scale_x_continuous(
    breaks = seq(2008, 2024, by = 4),
    limits = c(2008, 2028)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(x, "%"),
    limits = c(0, 85)
  ) +
  labs(
    title = "A: Exports vs imports, Kosovo (% of GDP)",
    x     = NULL,
    y     = "% of GDP"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "none",
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold", size = 11),
    plot.margin      = margin(10, 80, 10, 10)
  )

# --- 6. Panel B plot ---
p2 <- ggplot(services_clean,
             aes(x        = date,
                 y        = usd_bn,
                 color    = type,
                 linetype = type)) +
  geom_line(linewidth = 1.1) +
  geom_point(
    data = services_clean %>% filter(date == 2024),
    size = 2.5
  ) +
  geom_text_repel(
    data          = services_clean %>% filter(date == 2024),
    aes(label     = paste0(type, " ($", round(usd_bn, 1), "bn)")),
    nudge_x       = 1.2,
    direction     = "y",
    segment.color = "grey70",
    segment.size  = 0.3,
    size          = 3.0,
    box.padding   = 0.4
  ) +
  scale_color_manual(
    values = c("Services" = "#1a4e8a", "Goods" = "#e05c2a")
  ) +
  scale_linetype_manual(
    values = c("Services" = "solid", "Goods" = "dashed")
  ) +
  scale_x_continuous(
    breaks = seq(2008, 2024, by = 4),
    limits = c(2008, 2028)
  ) +
  scale_y_continuous(
    labels = function(x) paste0("$", x, "bn")
  ) +
  labs(
    title = "B: Export composition, Kosovo (USD billion)",
    x     = NULL,
    y     = "USD billion"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "none",
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold", size = 11),
    plot.margin      = margin(10, 80, 10, 10)
  )

# --- 7. Panel C plot ---
p3 <- ggplot(ca_2024,
             aes(x    = ca,
                 y    = country_label,
                 fill = is_kosovo)) +
  geom_col(width = 0.6) +
  geom_text(
    aes(label = paste0(round(ca, 1), "%"),
        hjust = ifelse(ca < 0, 1.15, -0.15)),
    size = 3.2
  ) +
  geom_vline(xintercept = 0, color = "grey40", linewidth = 0.4) +
  scale_fill_manual(
    values = c("TRUE" = "#1a4e8a", "FALSE" = "#aab4c4")
  ) +
  scale_x_continuous(
    labels = function(x) paste0(x, "%"),
    limits = c(-20, 3)
  ) +
  labs(
    title = "C: Current account balance, Western Balkans, 2024",
    x     = "% of GDP",
    y     = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position    = "none",
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank(),
    plot.title         = element_text(face = "bold", size = 11),
    plot.margin        = margin(10, 20, 10, 10)
  )

# --- 8. Combine and save ---
combined <- (p1 + p2) / p3 +
  plot_annotation(
    title    = "Kosovo's trade: a services-led export boom with a persistent import gap",
    subtitle = "Exports, imports, current account and export composition, 2008–2024",
    caption  = paste0(
      "Sources: World Bank WDI (NE.EXP.GNFS.ZS, NE.IMP.GNFS.ZS, ",
      "BN.CAB.XOKA.GD.ZS, BX.GSR.NFSV.CD, BX.GSR.MRCH.CD). ",
      "Author: Plator Krasniqi."
    ),
    theme = theme(
      plot.title    = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(color = "grey40", size = 10),
      plot.caption  = element_text(color = "grey50", size = 8)
    )
  )

ggsave("kosovo_trade_structure.png", plot = combined,
       width = 13, height = 9, dpi = 300)

print(combined)
