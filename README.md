# Paying for Power: A Causal Analysis of Data Centre Expansion and Wholesale Electricity Prices in Virginia

This repository contains the data pipeline and analysis code for our master's thesis examining the effect of data centre entry in Virginia census tracts on wholesale electricity prices, as measured by PJM Locational Marginal Prices (LMPs). The empirical strategy combines propensity score matching (PSM) with a staggered difference-in-differences (DiD) design.

> **Note on large data files:** Due to file size limits, the full raw PJM LMP data (filtered to identified Virginia pnodes) is accessible via [Google Drive](https://drive.google.com/drive/folders/19szrJjiv3aYtpBLJYDOeCehJksi4n2yY).

---

## Repository Structure

```
Master-Thesis-2026/
│
├── data/
│   ├── raw/
│   │   ├── census_data/          # TIGER/Line shapefiles (tract, state)
│   │   ├── electricSubstations/  # Electric substation shapefile
│   │   ├── fta/                  # FracTracker data center database
│   │   ├── im3/                  # PNNL Data Center Atlas
│   │   ├── im3_years/            # Verified data center entry years
│   │   └── pjm_lmp_data/         # PJM LMP parquet/duckdb files
│   └── processed/
│       ├── for_analysis/         # Final analysis-ready files
│       └── preprocessing/        # Intermediate pipeline outputs
│
├── notebooks/
│   ├── analysis/
│   │   └── did.rmd               # DiD analysis (R Markdown)
│   └── preprocessing/            # Numbered pipeline notebooks (01–09)
│       ├── 01_download_pjm_data_filtered.ipynb
│       ├── 02_download_pjm_historical.ipynb
│       ├── 03_combine_lmp_averages.ipynb
│       ├── 04_generate_pnode_ids.ipynb
│       ├── 05_download_acs_data.ipynb
│       ├── 06_merge_lmp_pnode.ipynb
│       ├── 07_propensity_score_matching.ipynb
│       ├── 08_build_did_panel.ipynb
│       └── 09_datacenter_construct_panel.ipynb
│
├── output/
│   ├── csv_files/                # Analysis results
│   ├── figures/                  # Plots
│   └── tables/                   # LaTeX tables
│
├── environment_elena.yml         # Python environment for notebooks 01–08
├── README.md
└── .gitignore
```

---

## Data Sources

| Dataset               | Source                  | Description                                      |
|-----------------------|-------------------------|--------------------------------------------------|
| IM3 Data Center Atlas | PNNL                    | Locations of US data centers                     |
| FracTracker Database  | FracTracker Alliance    | Data center locations, capacity, and status      |
| PJM LMP               | PJM Interconnection API | Hourly real-time locational marginal prices      |
| ACS 5-Year Estimates  | US Census Bureau        | Tract-level ACS demographics                     |
| TIGER/Line Shapefiles | US Census Bureau        | Virginia census tract boundaries (2016)          |
| HIFLD Substations     | HIFLD Open Data         | Electric substation locations for pnode matching |


---

## Replication

The preprocessing pipeline and DiD analysis were developed across two environments. 

Use `environment_1.yml` to run the data pre-processing in notebooks 01–08. 
