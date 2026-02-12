# Geospatial Project: Diabetes Mortality in Italy

Final project for the course *Geospatial Analysis and Representation for Data Science*.

## Project Goal
This project analyzes spatial patterns of diabetes mortality across Italian provinces and explores socio-demographic and lifestyle correlates using descriptive maps, spatial autocorrelation diagnostics, and spatial regression models.

## Repository Structure
```text
geospatial-project2/
|-- scripts/
|   |-- 01_data_cleaning.R
|   |-- 02_descriptive_analysis.Rmd
|   |-- 03_Moran's_I_.Rmd
|   |-- 04_univariate_regressions.Rmd
|   `-- 05_spatial_regression.Rmd
|-- outputs/
|   |-- diabetes_mortality_rate.png
|   |-- lisa_clusters_diabetes.png
|   |-- moran_scatter_diabetes.png
|   |-- pct_65+.png
|   |-- unemployment_rate.png
|   |-- low_education_share.png
|   |-- adequate_nutrition.png
|   `-- sedentariness.png
|-- docs/
|   |-- interactive_map.html
|   `-- interactive_map_files/
|-- data_clean/
|   |-- provinces_base.rds
|   |-- provinces_mortality.rds
|   |-- provinces_mortality_ageing.rds
|   |-- provinces_plus_education.rds
|   |-- provinces_full.rds
|   `-- provinces_prov_level.rds
|-- data_raw/
|   `-- provinces_shapefiles/
|-- geospatial-project2.Rproj
`-- README.md
```

## How The Analysis Was Conducted
The analysis followed a pipeline that goes from data preparation to model-based spatial interpretation. The central idea is that diabetes mortality is not only related to local characteristics of each province, but can also be affected by neighboring provinces through spatial spillovers.

### 1. Data Cleaning and Integration
In `scripts/01_data_cleaning.R`, raw administrative boundaries and province-level indicators were cleaned and merged into a harmonized geospatial dataset. During this phase, variable names were standardized, key geographic identifiers were aligned across sources, and output objects were saved in `data_clean/` to make the subsequent scripts reproducible and modular.

The cleaned dataset includes the mortality outcome together with explanatory factors used later in the regressions:
- `pct_65plus` (population ageing)
- `unemployment_rate`
- `low_education_share`
- `adequate_nutrition`
- `sedentariness`

### 2. Descriptive Spatial Exploration
In `scripts/02_descriptive_analysis.Rmd`, the project first explores distribution and geographic heterogeneity through choropleth maps. This stage is used to identify broad territorial patterns before estimating any model.

The interactive map allows visual comparison across provinces:
- Interactive map (HTML): [`docs/interactive_map.html`](docs/interactive_map.html)

## Descriptive Analysis
### Diabetes Mortality Map
![Diabetes mortality rate map](outputs/diabetes_mortality_rate.png)

### 3. Spatial Autocorrelation Diagnostics
In `scripts/03_Moran's_I_.Rmd`, the analysis tests whether similar mortality values cluster geographically. Global Moran's I is used to evaluate overall spatial dependence, while local indicators (LISA) are used to detect province-level clusters and potential spatial outliers.

This step is important because significant spatial autocorrelation implies that standard non-spatial assumptions are not fully appropriate. It motivates moving from purely aspatial models toward specifications that explicitly incorporate neighborhood structure.

### 4. Regression Phase
In `scripts/04_univariate_regressions.Rmd`, the project runs initial regression checks to understand one-by-one associations and directionality of effects. These baseline results are then extended in `scripts/05_spatial_regression.Rmd`, where spatially informed models are estimated.

### 5. SLX Model and Interpretation Strategy
The Spatial Lag of X (SLX) framework includes:
- local covariates (province characteristics)
- spatial lags of covariates (neighboring provinces' characteristics)

This allows separate interpretation of:
- direct local associations
- indirect neighborhood spillovers

Substantively, this means a province's mortality level can be linked both to its own socioeconomic profile and to the profile of nearby provinces.

## Spatial Lag of X (SLX) Model Results
Model call:
```r
lm(formula = formula(paste("y ~ ", paste(colnames(x)[-1], collapse = "+"))), 
    data = as.data.frame(x), weights = weights)
```

| Term | Estimate | Std. Error | t value | Pr(>|t|) |
|---|---:|---:|---:|---:|
| (Intercept) | 2.434e+00 | 1.772e+00 | 1.374e+00 | 1.727e-01 |
| pct_65plus | 2.137e-01 | 3.861e-02 | 5.534e+00 | 2.705e-07 |
| unemployment_rate | 7.135e-02 | 3.052e-02 | 2.338e+00 | 2.146e-02 |
| low_education_share | 2.226e-02 | 3.783e-02 | 5.884e-01 | 5.576e-01 |
| adequate_nutrition | -3.807e-02 | 3.857e-02 | -9.871e-01 | 3.261e-01 |
| sedentariness | 3.432e-02 | 3.352e-02 | 1.024e+00 | 3.084e-01 |
| lag.pct_65plus | -6.644e-02 | 6.934e-02 | -9.582e-01 | 3.404e-01 |
| lag.unemployment_rate | 1.630e-01 | 5.416e-02 | 3.010e+00 | 3.335e-03 |
| lag.low_education_share | -1.253e-01 | 4.853e-02 | -2.581e+00 | 1.136e-02 |
| lag.adequate_nutrition | -1.493e-02 | 5.063e-02 | -2.948e-01 | 7.688e-01 |
| lag.sedentariness | 3.379e-02 | 3.912e-02 | 8.636e-01 | 3.899e-01 |

### Main Signals (p < 0.05)
- `pct_65plus`: positive and statistically significant; provinces with older populations tend to show higher diabetes mortality.
- `unemployment_rate`: positive and statistically significant; weaker labor-market conditions are associated with higher mortality.
- `lag.unemployment_rate`: positive and statistically significant; neighboring unemployment conditions also matter (spillover effect).
- `lag.low_education_share`: negative and statistically significant; this indicates a spatially mediated association that differs from the local coefficient and should be interpreted as a contextual neighboring effect rather than a direct causal claim.

### Reading The Non-Significant Terms
Several local and lagged lifestyle covariates are not statistically significant in this model specification (`low_education_share`, `adequate_nutrition`, `sedentariness`, and selected lagged terms). In this project, these are treated as signals that either:
- the effect is weak once other factors are controlled for,
- the effect may be captured through correlated variables,
- or the available cross-sectional variation is not strong enough for precise estimation.

## Analytical Notes
- The analysis is observational and cross-sectional; results indicate association, not strict causation.
- Spatial effects are interpreted as dependence/contextual structure across neighboring provinces.
- The workflow combines map-based exploration, autocorrelation diagnostics, and model-based inference to avoid relying on a single method.

## Reproducibility
Run scripts in numeric order (`01` -> `05`) to reproduce the full workflow:
1. Build cleaned datasets.
2. Produce descriptive and interactive maps.
3. Evaluate global/local spatial autocorrelation.
4. Estimate baseline and spatial regression models.
