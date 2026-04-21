# Western Balkans Nighttime Lights Map

**Author:** Plator Krasniqi  
**Data Source:** VIIRS VNL v22 (2024 Annual Average) — NOAA Earth Observation Group  
**Repository:** [github.com/platorpk/kosovo-economy](https://github.com/platorpk/kosovo-economy)

---

## Overview

This map visualizes nighttime radiance across the Western Balkans (Albania, Bosnia & Herzegovina, Kosovo, Montenegro, North Macedonia, Serbia) using satellite-derived data from the Visible Infrared Imaging Radiometer Suite (VIIRS).

Nighttime lights are increasingly used in development economics as a proxy for local economic activity. They correlate with GDP, electrification rates, urbanization, and infrastructure density — particularly useful in regions where traditional economic data collection is incomplete or inconsistent.

![Western Balkans Nighttime Lights 2024](Western_Balkans_Nightlights_Gold_2024.png)

---

## Key Findings

The map reveals the region's spatial economic structure:

- **Major urban nodes** (Belgrade, Tirana, Sarajevo, Skopje, Prishtina) anchor bright clusters
- **Transport corridors** along the Danube (Serbia), Vardar valley (North Macedonia), and Adriatic coast (Albania, Montenegro) show concentrated light
- **Mountainous regions** (Dinaric Alps, Sharr Mountains, Prokletije) remain largely dark, reflecting low population density and limited electrification
- **Kosovo's settlement pattern** concentrates in Prishtina, Prizren, and Peja, with sparse rural coverage

---

## Data & Methodology

**Source:**  
VIIRS Day/Night Band (DNB) annual composite, 2024 (VNL v22)  
Provider: NOAA Earth Observation Group (EOG)  
Native resolution: ~500m at nadir

**Processing:**
1. Raster cropped and masked to Western Balkans boundary (GADM ADM0)
2. Upsampled 3× using bilinear interpolation for smoother visualization
3. Noise floor applied (radiance < 0.3 nW/cm²/sr set to NA)
4. Upper tail winsorized at 99.9th percentile to prevent blowout in city cores
5. Log-transformed and gamma-corrected (γ = 0.40) for perceptually uniform brightness
6. Mapped to monochrome gold palette (bias = 1.6 toward darker tones)

**Tools:**  
R 4.4+ with packages: `terra`, `sf`, `geodata`, `ggplot2`, `ggrepel`, `showtext`

**Visualization approach inspired by Milan Janosov's nighttime lights work.**

---

## Files in This Repository

```
western-balkans-nightlights/
├── western_balkans_nightlights.R          # Full R script
├── Western_Balkans_Nightlights_Gold_2024.png   # High-res output (600 DPI)
├── Western_Balkans_Nightlights_LinkedIn.png    # Web-optimized (400 DPI)
└── README.md
```

---

## Usage Notes

**Data acquisition:**  
VIIRS annual composites are available at [https://eogdata.mines.edu/products/vnl/](https://eogdata.mines.edu/products/vnl/)  
Requires free registration. Download the `.average_masked.dat.tif` file for 2024.

**Replicating this map:**  
1. Download the VIIRS 2024 global composite
2. Adjust file paths in the R script to your working directory
3. Run the script — GADM boundaries download automatically
4. Output saved to working directory

**Adapting to other regions:**  
Modify the `wb_countries` vector with desired ISO codes. Adjust gamma, noise floor, and palette as needed for different radiance distributions.

---

## Citation

If using this work, please cite:

```
Krasniqi, P. (2026). Western Balkans Nighttime Lights Map.
Data: VIIRS VNL v22 (NOAA/EOG, 2024).
Available at: https://github.com/platorpk/kosovo-economy
```

---

## License

Code: MIT License  
Map output: CC BY 4.0 (attribution required)  
VIIRS data: Public domain (NOAA)

---

## Contact

**Plator Krasniqi**  
Email: plator.pk@gmail.com  
LinkedIn: [linkedin.com/in/plator-krasniqi](https://linkedin.com/in/plator-krasniqi)
