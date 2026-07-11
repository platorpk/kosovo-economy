# Kosova municipal digital divide — Ookla Speedtest (2025)

Reproducible R pipeline mapping **fixed-broadband download speed across Kosova's
38 municipalities** in 2025 (Ookla Speedtest open data), compared with nighttime
lights as a proxy for local economic activity. Fixed broadband is the focus;
mobile is summarised at national level only because municipal mobile sampling is
too sparse to map reliably.

## Data sources (all open)
- **Ookla for Good — Speedtest Open Data**: fixed & mobile tiles (zoom-16), quarterly.
  Read directly from the public S3 bucket `ookla-open-data` via the R `arrow`
  package. This piece pools **2025 Q1–Q4**.
- **Municipal boundaries**: geoBoundaries gbOpen **ADM2** (Kosova / `XKX`), 38
  municipalities; names standardised to Albanian in `01_functions.R`.
- **Nighttime lights**: VIIRS VNL v2 **2024** annual average (NOAA / EOG).

## Method
- Tiles are clipped to Kosova with quadkey prefixes; each tile centroid is
  reconstructed from its quadkey (validated against Ookla's WKT geometry).
- Tiles are assigned to municipalities by point-in-polygon. Municipal speed is the
  **test-weighted mean download** over pooled 2025 tiles.
- Economic proxy = nighttime-lights radiance sampled **at the tested tiles** and
  test-weighted (`radiance_tw`). A whole-polygon mean (`radiance_poly`) is also
  computed for transparency.
- Municipalities with fewer than 50 pooled tests are flagged low-sample.

## Key results
- **National fixed download (2025, test-weighted): ~107 Mbps.**
- **A 4.5× municipal gap**: fastest Prishtina (~125 Mbps) to slowest Leposaviq
  (~28 Mbps). Slowest speeds are in the northern and highland-periphery
  municipalities; fastest are Prishtina and the central-western towns.
- **Association with nighttime lights is moderate and proxy-sensitive:**
  - Spearman **ρ = 0.54** using radiance sampled at the tested tiles
    (`radiance_tw`) — **the primary/headline proxy**, shown in Panel B.
  - Spearman **ρ = 0.27** using the whole-polygon mean (`radiance_poly`).
  - **Why test-weighted is primary, and why polygon-mean is flawed:** a mean over
    an entire municipal polygon is dominated by uninhabited terrain — it dilutes
    large rural municipalities (mostly dark) and inflates tiny all-urban
    municipalities (all bright), a size/area confound. Sampling brightness where
    people actually connect (and test) matches the proxy to the same locations the
    speed data comes from, so `radiance_tw` is the appropriate measure.
  - **What the sensitivity means:** the jump from 0.27 to 0.54 shows the
    speed–economy association is real but **understated by the naïve polygon mean**
    and only moderate even when measured correctly — it is not a tight relationship,
    and the exact figure depends on how the economic proxy is constructed. Frame it
    as a moderate, descriptive association, not a strong or causal one.
  - **Named exceptions (bright but below-median speed):** **Mitrovica e Veriut** and
    **Graçanica** — dense, high-radiance municipalities whose fixed speeds sit well
    below the trend. They are visible at the lower-right of Panel B and hold in both
    proxy measures.

## Reproduce
Run in order (R ≥ 4.5; packages: `arrow, sf, terra, dplyr, ggplot2, ggrepel,
showtext, patchwork, scales`):
1. `R/01_functions.R` — helpers (loaded by the others).
2. `R/02_build_municipal_data.R` — pulls/pools Ookla, joins, writes `data/processed/`.
3. `R/03_figure.R` — renders the figures to `output/`.

The VIIRS raster path is set at the top of `02_build_municipal_data.R`. Raw Ookla
clips and boundaries are cached under `data/raw/` on first run.

## Outputs
- `output/panelA_choropleth_2025.png` — municipal choropleth (lead image).
- `output/panelB_scatter_2025.png` — speed vs nighttime lights.
- `output/kosovo_digital_divide_2025.png` — combined two-panel figure.
- `data/processed/municipal_fixed_2025.csv` — per-municipality table (speeds, tests,
  both radiance measures, low-sample flag).

## Caveats
- **Means, not medians.** Ookla open tiles report per-tile *mean* speeds, so all
  municipal figures here are test-weighted **means** (not medians, which Ookla does
  not publish at tile level).
- **Test-weighting.** Municipal speed and `radiance_tw` are weighted by the number
  of tests per tile, so they reflect the experience of where testing is concentrated
  (more populated/used areas) rather than an unweighted average of land area.
- **Novobërdë excluded from the map and scatter** (fewer than 50 pooled tests in
  2025); shown grey on the choropleth.
- **Mobile is national-only.** Even pooling all of 2025, only 34 of 38
  municipalities reach 30 mobile tests, so mobile is reported as a single national
  figure (~143 Mbps) and is *not* mapped by municipality.
- **Nighttime lights (2024) vs speeds (2025)** are not time-matched — lights are
  used as a structural proxy for local economic activity, not a same-period control.
