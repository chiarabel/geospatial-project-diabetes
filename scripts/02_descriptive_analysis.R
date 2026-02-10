# 1. load libraries ####
library(sf)
library(dplyr)
library(tidyr)
library(janitor)
library(ggplot2)
library(viridis)
library(leaflet)


prov <- readRDS("data_clean/provinces_full.rds")

# 2. basic summary of the variables ####
prov_df <- prov %>% st_drop_geometry()

summary_stats <- prov_df %>%
  summarise(
    mort_mean = mean(diabetes_mort_rate, na.rm = TRUE),
    mort_sd   = sd(diabetes_mort_rate, na.rm = TRUE),
    mort_min  = min(diabetes_mort_rate, na.rm = TRUE),
    mort_max  = max(diabetes_mort_rate, na.rm = TRUE),
    
    age_mean  = mean(pct_65plus, na.rm = TRUE),
    unemp_mean = mean(unemployment_rate, na.rm = TRUE),
    edu_mean  = mean(low_education_share, na.rm = TRUE),
    nutr_mean = mean(adequate_nutrition, na.rm = TRUE),
    sed_mean  = mean(sedentariness, na.rm = TRUE)
  )


# 3. Which provinces are most affected? Which are least? ####

## 3.1 Diabetes mortality rate ####
# most affective:
prov_df %>%
  arrange(desc(diabetes_mort_rate)) %>%
  select(prov_name, diabetes_mort_rate) %>%
  slice(1:10)

# least effective:
prov_df %>%
  arrange(diabetes_mort_rate) %>%
  select(prov_name, diabetes_mort_rate) %>%
  slice(1:10)

# we can already see that provinces located in the south have greater diabetes mortality rate.

## 3.2 Ageing ####
# most affective:
prov_df %>%
  arrange(desc(pct_65plus)) %>%
  select(prov_name, pct_65plus) %>%
  slice(1:10)

# least effective:
prov_df %>%
  arrange(pct_65plus) %>%
  select(prov_name, pct_65plus) %>%
  slice(1:10)

## 3.3 Unemployment ####

# most affective:
prov_df %>%
  arrange(desc(unemployment_rate)) %>%
  select(prov_name, unemployment_rate) %>%
  slice(1:10)

# least effective:
prov_df %>%
  arrange(unemployment_rate) %>%
  select(prov_name, unemployment_rate) %>%
  slice(1:10)

# same thing: unemplyment rate is clearly greater in the south

## 3.4 education ####
edu_region <- prov_df %>%
  distinct(region_name, low_education_share)
# Most affected (highest low education share)
edu_region %>%
  arrange(desc(low_education_share)) %>%
  slice(1:10)
# Least affected (lowest low education share)
edu_region %>%
  arrange(low_education_share) %>%
  slice(1:10)


## 3.5 Nutrition and sedentariness ####
nut_region <- prov_df %>%
  distinct(region_name, adequate_nutrition)

# Best (highest adequate nutrition)
nut_region %>%
  arrange(desc(adequate_nutrition)) %>%
  slice(1:10)
# Worst (lowest adequate nutrition)
nut_region %>%
  arrange(adequate_nutrition) %>%
  slice(1:10)

# the same here, the south has the lowest adequate nutrition

sed_region <- prov_df %>%
  distinct(region_name, sedentariness)

# Best (highest sedentariness)
sed_region %>%
  arrange(desc(sedentariness)) %>%
  slice(1:10)
# Worst (lowest sedentariness)
sed_region %>%
  arrange(sedentariness) %>%
  slice(1:10)

# the same 



# 4. cross table analysis with mortality ####
# Helper to create quantile-based groups with nice labels
qcut <- function(x, probs, labels) {
  cut(x,
      breaks = quantile(x, probs = probs, na.rm = TRUE),
      include.lowest = TRUE,
      labels = labels)
}

prov_cat <- prov_df %>%
  mutate(
    # Outcome: mortality quartiles
    mort_q = qcut(diabetes_mort_rate,
                  probs  = c(0, .25, .50, .75, 1),
                  labels = c("Q1 (lowest)", "Q2", "Q3", "Q4 (highest)")),
    
    # Predictors: tertiles (Low/Medium/High)
    age_ter = qcut(pct_65plus,
                   probs  = c(0, 1/3, 2/3, 1),
                   labels = c("Low", "Medium", "High")),
    
    unemp_ter = qcut(unemployment_rate,
                     probs  = c(0, 1/3, 2/3, 1),
                     labels = c("Low", "Medium", "High")),
    
    edu_ter = qcut(low_education_share,
                   probs  = c(0, 1/3, 2/3, 1),
                   labels = c("Low", "Medium", "High")),
    
    nutr_ter = qcut(adequate_nutrition,
                    probs  = c(0, 1/3, 2/3, 1),
                    labels = c("Low", "Medium", "High")),
    
    sed_ter = qcut(sedentariness,
                   probs  = c(0, 1/3, 2/3, 1),
                   labels = c("Low", "Medium", "High"))
  )


crosstab_mort <- function(data, var) {
  data %>%
    count(mort_q, {{ var }}) %>%
    group_by(mort_q) %>%
    mutate(pct_within_mort = n / sum(n) * 100) %>%
    ungroup() %>%
    arrange(mort_q, {{ var }})
}


tab_age  <- crosstab_mort(prov_cat, age_ter)
# “Within each diabetes mortality quartile, how are provinces distributed across age structure (Low / Medium / High %65+)?”

# Q1 :

# Low age     --> 55.5%
# Medium age  --> 37.0%
# High age    --> 7.4%

# --> Among provinces with the lowest diabetes mortality, more than half have a low share of elderly,
# and very few have a high share of elderly.


# Q2:
# Low age     --> 17.9%
# Medium age  --> 35.7%
# High age    --> 46.4%

# --> # In slightly higher mortality provinces, the majority already have medium-to-high ageing.


# Q3:
# Low age     --> 12.0%
# Medium age  --> 20.0%
# High age    --> 68.0%

# --> For provinces in the third mortality quartile, over two thirds belong to the highest ageing group


# Q4:

# Low age     → 48.1%
# Medium age  → 37.0%
# High age    → 14.8%

# Provinces with very high diabetes mortality are not dominated by highly aged populations.
# Ageing explains diabetes mortality up to a point, but cannot explain the highest mortality levels alone.


tab_unem <- crosstab_mort(prov_cat, unemp_ter)

#Q1: 70.4% Low unemployment: Very few high-unemployment provinces

#Q2: Balanced Low / Medium unemployment, Still few high-unemployment provinces

#Q3: 32% High unemployment, Nearly half Medium, Unemployment starts to matter more

#Q4: 81.5% High unemployment, Almost no low-unemployment provinces

# Provinces with the highest diabetes mortality are overwhelmingly concentrated in the highest unemployment tertile, 
# suggesting a strong socio-economic gradient that is not explained by age alone.


tab_edu  <- crosstab_mort(prov_cat, edu_ter)

#Q1: 66.7% Low low-education share, very few High: better education = lower mortality

#Q2, Q3: Increasing presence of Medium & High, gradient is visible but smoother

#Q4: 81.5% High low-education share --> Strong structural association

# The highest mortality quartile is strongly associated with regions exhibiting a high proportion of 
# low-educated population, highlighting the role of long-term structural socio-economic disadvantages.


tab_nutr <- crosstab_mort(prov_cat, nutr_ter)

#Q1: Mostly Medium–High nutrition, Only 11% Low nutrition --> nutrition has a protective effect

#Q2, Q3: Mixed distribution

#Q4: 92.6% Low adequate nutrition

# Provinces with the highest diabetes mortality are almost exclusively located in regions characterized 
# by low levels of adequate nutrition, reinforcing the role of diet-related factors in diabetes-related mortality.


tab_sed  <- crosstab_mort(prov_cat, sed_ter)

#Q1: 92.6% Low sedentariness, Low mortality provinces are almost entirely in low-sedentary regions

#Q2, Q3: Mostly Medium sedentariness, Some High in Q3 --> Clear gradient emerging

#Q4: 88.9% High sedentariness --> Extremely strong concentration

# Provinces in the highest mortality quartile are almost entirely located in regions with high levels of sedentary behavior, 
# indicating that lifestyle-related risk factors play a key role in explaining extreme mortality outcomes.


# 5. MAPPING

## 5.1 Static Maps
### 5.1.1 Diabetes mortality rate ####
ggplot(provinces_full) +
  geom_sf(aes(fill = diabetes_mort_rate), color = "grey30", size = 0.1) +
  scale_fill_viridis(
    name = "Diabetes mortality rate",
    option = "plasma",
    direction = -1
  ) +
  labs(
    title = "Diabetes mortality rate by province",
    subtitle = "Quantile classification",
    caption = "Source: ISTAT"
  ) +
  theme_minimal()

### 5.1.2 Unemplyment rate ####
ggplot(provinces_full) +
  geom_sf(aes(fill = unemployment_rate), color = "grey30", size = 0.1) +
  scale_fill_viridis(
    name = "Unemployment rate (%)",
    option = "magma",
    direction = -1
  ) +
  labs(
    title = "Unemployment rate by province"
  ) +
  theme_minimal()

### 5.1.3 Ageing ####
ggplot(provinces_full) +
  geom_sf(aes(fill = pct_65plus), color = "grey30", size = 0.1) +
  scale_fill_viridis(
    name = "65+ (%)",
    option = "magma",
  ) +
  labs(
    title = "Percentage of 65+ by province"
  ) +
  theme_minimal()

### 5.1.4 Sedentariness ####
ggplot(provinces_full) +
  geom_sf(aes(fill = sedentariness), color = "grey30", size = 0.1) +
  scale_fill_viridis(
    name = "Sedentary population (%)",
    option = "inferno",
    direction = -1
  ) +
  labs(
    title = "Sedentariness (regional indicator)",
    subtitle = "Same value for provinces within the same region"
  ) +
  theme_minimal()

### 5.1.5 Nutrition ####

ggplot(provinces_full) +
  geom_sf(aes(fill = adequate_nutrition), color = "grey30", size = 0.1) +
  scale_fill_viridis(
    name = "Adequate nutrition (%)",
    option = "viridis",
  ) +
  labs(
    title = "Adequate nutrition (regional indicator)"
  ) +
  theme_minimal()



## 5.2 Interactive maps ####
st_crs(provinces_full)
provinces_leaflet <- st_transform(provinces_full, 4326)

mort_breaks <- quantile(
  provinces_leaflet$diabetes_mort_rate,
  probs = seq(0, 1, 0.2),
  na.rm = TRUE
)

pal_mort <- colorBin(
  palette = "YlOrRd",
  domain  = provinces_leaflet$diabetes_mort_rate,
  bins    = mort_breaks
)

provinces_leaflet <- provinces_leaflet %>%
  mutate(
    mort_q = cut(
      diabetes_mort_rate,
      breaks = quantile(diabetes_mort_rate, probs = seq(0, 1, 0.25), na.rm = TRUE),
      include.lowest = TRUE,
      labels = c("Q1", "Q2", "Q3", "Q4")
    )
  )

leaflet(provinces_leaflet) %>%
  addProviderTiles("CartoDB.Positron") %>%
  
  addPolygons(
    fillColor = ~ifelse(mort_q == "Q4", "red", "transparent"),
    color = "red",
    weight = 1,
    fillOpacity = 0.7,
    group = "Highest mortality (Q4)",
    label = ~paste0(prov_name, " – ", region_name)
  ) %>%
  
  addLayersControl(
    overlayGroups = c("Highest mortality (Q4)"),
    options = layersControlOptions(collapsed = FALSE)
  )



# interactive map 
leaflet(provinces_leaflet) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(
    fillColor = ~pal_mort(diabetes_mort_rate),
    weight = 0.4,
    fillOpacity = 0.8,
    
    label = ~paste0(prov_name, " – ", region_name),
    
    popup = ~paste0(
      "<b>", prov_name, "</b><br>",
      "<i>", region_name, "</i><br><br>",
      
      "<b>Diabetes mortality:</b> ",
      round(diabetes_mort_rate, 1), "<br><br>",
      
      "<b>Population 65+:</b> ",
      round(pct_65plus, 1), "%<br>",
      
      "<b>Unemployment:</b> ",
      round(unemployment_rate, 1), "%<br><br>",
      
      "<b>Sedentariness (region):</b> ",
      sedentariness, "%<br>",
      
      "<b>Adequate nutrition (region):</b> ",
      adequate_nutrition, "%<br>",
      
      "<b>Low education share (region):</b> ",
      round(low_education_share, 1), "%"
    )
  ) %>%
  addLegend(
    pal = pal_mort,
    values = ~diabetes_mort_rate,
    title = "Diabetes mortality rate<br>(per 10,000)",
    labFormat = labelFormat(digits = 1),
    opacity = 0.9,
    position = "bottomright"
  )




