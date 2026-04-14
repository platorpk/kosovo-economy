# Kosovo Economy — Data Notes & Portfolio

**Author:** Plator Krasniqi  
**Contact:** plator.pk@gmail.com  
**Background:** M.Sc. Economics, Heidelberg University (2025), specialisation 
in causal inference and development economics. Currently based in Prishtina, 
working at GIZ Kosovo.

This repository contains short data analyses on Kosovo's economy, produced for 
a general audience. All code is reproducible and uses open data sources only.

---

## Post 1 — Kosovo's Remittance Dependence in Regional Context

**Folder:** `remittances-regional-context/`  
**Chart:** `remittances-regional-context/remittances_western_balkans.png`

### Question
How dependent is Kosovo on remittances relative to its Western Balkans 
neighbours and the EU average, and has that dependence changed over time?

### Data
- Source: World Bank World Development Indicators
- Indicator: `BX.TRF.PWKR.DT.GD.ZS` — Personal remittances received (% of GDP)
- Countries: Kosovo, Albania, North Macedonia, Bosnia & Herzegovina, Serbia,
  Montenegro, EU average
- Period: 2008–2024
- Access: `wbstats` R package — no manual download required

### Key findings
- Kosovo's remittances have equalled 15–22% of GDP throughout the period,
  consistently the highest in the Western Balkans
- The EU average has remained below 1% across the same period
- Despite sustained GDP growth, Kosovo's remittance share has not declined
  meaningfully — diaspora transfers are keeping pace with the economy rather
  than being displaced by domestic income growth
- A modest spike is visible in 2020, consistent with increased diaspora
  support during the COVID-19 contraction

### Methods
Descriptive time series and cross-sectional comparison. No causal claims made.

### Reproduce
```r
install.packages(c("wbstats", "ggplot2", "dplyr", "ggrepel", "patchwork"))
source("remittances-regional-context/analysis.R")
```

---

## Post 2 — Kosovo's Trade Structure: A Services-Led Export Boom

**Folder:** `trade-structure/`  
**Chart:** `trade-structure/kosovo_trade_structure.png`

### Question
How has Kosovo's export structure evolved since 2008, and what does the 
composition of exports — services versus goods — reveal about the nature 
of Kosovo's external sector?

### Data
- Source: World Bank World Development Indicators
- Indicators:
  - `NE.EXP.GNFS.ZS` — Exports of goods and services (% of GDP)
  - `NE.IMP.GNFS.ZS` — Imports of goods and services (% of GDP)
  - `BN.CAB.XOKA.GD.ZS` — Current account balance (% of GDP)
  - `BX.GSR.NFSV.CD` — Service exports (current USD)
  - `BX.GSR.MRCH.CD` — Goods exports (current USD)
- Countries: Kosovo (panels A and B); Western Balkans six (panel C)
- Period: 2008–2024

### Key findings
- Kosovo's exports grew from 17% to 42% of GDP between 2008 and 2024,
  a genuine structural shift
- Services dominate: in 2024, Kosovo exported $3.7bn in services versus
  $1.0bn in goods — a ratio of 3.5 to 1
- Services exports have grown sixfold since 2008; goods exports threefold
- Despite export growth, the import gap has not closed — imports reached
  72% of GDP in 2024
- Kosovo's current account deficit of -8.3% of GDP is the second largest
  in the Western Balkans in 2024, after Montenegro (-17.0%)
- Read alongside Post 1: remittances equivalent to 17% of GDP are a 
  significant part of what finances this persistent import gap

### Methods
Descriptive time series and cross-sectional comparison. No causal claims made.

### Reproduce
```r
install.packages(c("wbstats", "ggplot2", "dplyr", "tidyr", 
                   "ggrepel", "patchwork", "scales"))
source("trade-structure/analysis.R")
```

---

*Further posts on Kosovo's labour market, public finance, and EU integration 
forthcoming.*
