# ==============================================================================
# 03_reconcile.R
# BINDING FIRST BUILD STEP (approved 2026-07-16): reconcile ASK silc10's 2018
# value against Eurostat's 2018 XK transmission before any number is quotable.
# ASK is primary; any divergence gets an explicit footnote in the README.
# Writes data/processed/reconciliation_2018.csv.
#
# Run from the piece root:  Rscript R/03_reconcile.R
# ==============================================================================
suppressWarnings(suppressMessages({ library(dplyr); library(readr) }))

proj <- "C:/Users/plato/Documents/kosovo-economy/energy-poverty"
ask <- read_csv(file.path(proj, "data/processed/silc10_keep_warm.csv"), show_col_types = FALSE)
eur <- read_csv(file.path(proj, "data/processed/eurostat_keep_warm.csv"), show_col_types = FALSE)

ask_2018 <- ask$no[ask$year == "2018"]
eur_2018 <- eur$value[eur$geo == "XK" & eur$year == 2018 & eur$poverty == "total"]
eur_2018_pov <- eur$value[eur$geo == "XK" & eur$year == 2018 &
                          eur$poverty == "below_at_risk_of_poverty"]
stopifnot(length(ask_2018) == 1, length(eur_2018) == 1, length(eur_2018_pov) == 1)

diff <- ask_2018 - eur_2018
verdict <- if (abs(diff) < 0.05) {
  "MATCH: ASK silc10 2018 equals Eurostat XK 2018 TOTAL exactly. No footnote required; ASK silc10 is confirmed as the same EU-SILC indicator transmitted to Eurostat."
} else {
  sprintf(paste0("DIVERGENCE of %+.1f pp (ASK %.1f vs Eurostat %.1f). ASK is primary; ",
                 "this divergence must be footnoted explicitly in README and figure."),
          diff, ask_2018, eur_2018)
}

out <- tibble(
  source    = c("ASK silc10.px ('No' share)", "Eurostat ilc_mdes01 (TOTAL, hhcomp=TOTAL, unit=PC)",
                "Eurostat ilc_mdes01 (below at-risk-of-poverty threshold, B_60)"),
  year      = 2018,
  value_pct = c(ask_2018, eur_2018, eur_2018_pov),
  note      = c("primary series", verdict, "pinned for quotation")
)
write_csv(out, file.path(proj, "data/processed/reconciliation_2018.csv"))

cat("== RECONCILIATION, 2018 ==\n")
cat(sprintf("  ASK silc10 'No' (cannot keep warm): %.1f%%\n", ask_2018))
cat(sprintf("  Eurostat XK TOTAL:                  %.1f%%\n", eur_2018))
cat(sprintf("  Eurostat XK below-poverty (B_60):   %.1f%%\n", eur_2018_pov))
cat(sprintf("  Difference: %+.2f pp\n\n  VERDICT: %s\n", diff, verdict))
