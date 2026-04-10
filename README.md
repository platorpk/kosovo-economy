# Kosovo Economy — Data Notes & Portfolio

**Author:** Plator Krasniqi  
**Contact:** plator.pk@gmail.com  
**Background:** M.Sc. Economics, Heidelberg University (2025) — specialisation in 
causal inference and development economics. Currently based in Prishtina.

---

## Post 1 — Kosovo's Remittance Dependence in Regional Context

**File:** `remittances-regional-context/analysis.R`  
**Chart:** `remittances-regional-context/remittances_western_balkans.png`

### Question
How dependent is Kosovo on remittances relative to its Western Balkans neighbours 
and the EU average, and has that dependence changed over time?

### Data
- Source: World Bank World Development Indicators  
- Indicator: `BX.TRF.PWKR.DT.GD.ZS` — Personal remittances received (% of GDP)  
- Countries: Kosovo, Albania, North Macedonia, Bosnia & Herzegovina, Serbia, 
  Montenegro, EU average  
- Period: 2008–2024  
- Access: via `wbstats` R package — fully reproducible, no manual download required

### Key findings
- Kosovo's remittances have equalled 15–22% of GDP throughout the period, 
  consistently the highest in the Western Balkans
- The EU average has remained below 1% across the same period
- Despite sustained GDP growth, Kosovo's remittance share has not declined 
  meaningfully, suggesting diaspora transfers are growing in line with — 
  rather than being displaced by — domestic economic activity
- A modest spike is visible in 2020, consistent with increased diaspora 
  support during the COVID-19 contraction

### Methods
Descriptive time series and cross-sectional comparison. No causal claims are made. 
Data are downloaded programmatically via the World Bank API.

### How to reproduce
```r
install.packages(c("wbstats", "ggplot2", "dplyr", "ggrepel", "patchwork"))
source("remittances_western_balkans/analysis.R")
```

---

*More posts on Kosovo's labour market, trade, and EU integration forthcoming.*
