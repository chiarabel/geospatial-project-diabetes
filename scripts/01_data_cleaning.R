# 1. Load libraries ####
library(sf)
library(dplyr)
library(readxl)
library(stringr)
library(writexl)


# 2. Read and explore province shapefile (ISTAT) ####
provinces_sf <- st_read(
  "data_raw/provinces_shapefiles/ProvCM01012023_g/ProvCM01012023_g_WGS84.shp"
)


# Look at attribute names
names(provinces_sf)

# Preview first rows 
head(provinces_sf)

# Check CRS 
st_crs

## 2.1 Keep only what is needed from the shapefile ####
provinces_base <- provinces_sf %>%
  transmute(
    prov_code = COD_PROV,
    prov_name = DEN_PROV,
    sigla = SIGLA,
    cod_reg = COD_REG,
    geometry = geometry
  )

## 2.2 join with region names ####
regions_sf <- st_read("data_raw/provinces_shapefiles/Reg01012023_g/Reg01012023_g_WGS84.shp")

regions_lookup <- regions_sf %>%
  st_drop_geometry() %>%
  transmute(
    cod_reg = COD_REG,
    region_name = DEN_REG
  )

provinces_base <- provinces_base %>%
  left_join(regions_lookup, by = "cod_reg")

provinces_base <- provinces_sf %>%
  mutate(
    prov_name_clean = ifelse(
      DEN_PROV == "-" | is.na(DEN_PROV),
      DEN_CM,      # use metropolitan city name
      DEN_PROV     # use province name
    )
  ) %>%
  transmute(
    prov_code = COD_PROV,
    prov_name = prov_name_clean,
    sigla = SIGLA,
    cod_reg = COD_REG,
    geometry = geometry
  )

# some checkups 
nrow(provinces_base)
any(duplicated(provinces_base$prov_code))
any(is.na(provinces_base$region_name))
any(is.na(provinces_base$prov_name))


## 2.3 Save clean base layer ####
saveRDS(
  provinces_base,
  "data_clean/provinces_base.rds"
)



# 3. Read and explore mortality dataset ####
mort_raw <- read_excel(
  "data_raw/mortality_diabetes.xlsx",
  skip = 0
)

names(mort_raw)
rate_col <- grep("Quoziente.*10\\.?000|Quoziente.*10,?000", names(mort_raw), value = TRUE)
rate_col 
# clean territory
mort_clean <- mort_raw %>%
  rename(territorio = 1) %>%              # first column as territory label
  mutate(territorio = str_trim(as.character(territorio))) %>%
  filter(!is.na(territorio))

## 3.1 keep only provinces ####
prov_names <- provinces_base %>%
  st_drop_geometry() %>%
  distinct(prov_name) %>%
  pull(prov_name)

mort_clean <- mort_clean %>%
  filter(territorio %in% prov_names)
# rows are 103 and not 107. Four provinces are missing

# check which provinces are missing
missing_provs <- setdiff(prov_names, mort_clean$territorio)
length(missing_provs)
missing_provs
# output: [1] "Aosta"         "Bolzano"       "Forli'-Cesena" "Massa Carrara"


mort_all_terr <- mort_raw %>%
  rename(territorio = 1) %>%
  mutate(territorio = trimws(as.character(territorio))) %>%
  filter(!is.na(territorio)) %>%
  distinct(territorio) %>%
  pull(territorio)

# Show candidates that "contain" pieces of missing names
lapply(missing_provs, function(p) mort_all_terr[grepl(substr(p, 1, 4), mort_all_terr, ignore.case = TRUE)])

# fix the names: adapt mortality file to the shapefile

mort_clean_1row <- mort_raw %>%
  rename(territorio = 1) %>%
  mutate(
    territorio = trimws(as.character(territorio)),
    territorio = case_when(
      territorio == "Valle d'Aosta / Vallée d'Aoste" ~ "Aosta",
      territorio %in% c("Bolzano / Bozen", "Provincia Autonoma Bolzano / Bozen") ~ "Bolzano",
      territorio == "Forlì-Cesena" ~ "Forli'-Cesena",
      territorio == "Massa-Carrara" ~ "Massa Carrara",
      TRUE ~ territorio
    )
  ) %>%
  filter(!is.na(territorio)) %>%
  filter(territorio %in% prov_names) %>%
  transmute(
    prov_name = territorio,
    diabetes_mort_rate = as.numeric(gsub(",", ".", as.character(.data[[rate_col[1]]])))
  ) %>%
  group_by(prov_name) %>%
  summarise(
    diabetes_mort_rate = first(na.omit(diabetes_mort_rate)),
    .groups = "drop"
  )


## 3.2 join provinces with mortality rate ####
provinces_joined <- provinces_base %>%
  left_join(mort_clean_1row, by = "prov_name")

sum(is.na(provinces_joined$diabetes_mort_rate))

## 3.3 Save RDS ####
saveRDS(
  provinces_joined,
  "data_clean/provinces_mortality.rds"
)


# 4. Read and explore ageing data ####
age_raw <- read_excel("data_raw/ageing_data.xlsx")

names(age_raw)
head(age_raw)

## 4.1 standardize names so they match prov_name ####
age_clean <- age_raw %>%
  rename(territorio = 1) %>%
  mutate(
    territorio = trimws(as.character(territorio)),
    territorio = case_when(
      territorio == "Valle d'Aosta" ~ "Aosta",
      territorio == "Valle d'Aosta / Vallée d'Aoste" ~ "Aosta",         
      territorio == "Provincia Autonoma Trento" ~ "Trento",          
      territorio == "Forli'" ~ "Forli'-Cesena",
      territorio == "Massa-Carrara" ~ "Massa Carrara",
      TRUE ~ territorio
    )
  ) %>%
  filter(!is.na(territorio)) %>%
  filter(territorio %in% prov_names) %>%
  transmute(
    prov_name = territorio,
    pct_65plus = as.numeric(
      gsub(",", ".", as.character(dplyr::pick(matches("65"))[[1]]))
    )
  ) %>%
  group_by(prov_name) %>%
  summarise(
    pct_65plus = first(na.omit(pct_65plus)),
    .groups = "drop"
  )

nrow(age_clean)
summary(age_clean$pct_65plus)
sum(is.na(age_clean$pct_65plus))

## 4.3 Save RDS ####

saveRDS(
  provinces_joined,
  "data_clean/provinces_mortality_ageing.rds"
)


# 5. Read and explore unemployment data ####
unemp_raw <- read_excel("data_raw/unemployment_data.xlsx")

## 5.1 Standardize names so they match prov_name and filter the column ####
unemp_clean <- unemp_raw %>%
  rename(territorio = 1) %>%
  mutate(
    territorio = trimws(as.character(territorio)),
    territorio = case_when(
      territorio == "Valle d'Aosta / Vallée d'Aoste" ~ "Aosta",
      territorio %in% c("Bolzano / Bozen", "Provincia Autonoma Bolzano / Bozen") ~ "Bolzano",
      territorio == "Provincia Autonoma Trento" ~ "Trento",     
      territorio == "Forlì-Cesena" ~ "Forli'-Cesena",
      territorio == "Massa-Carrara" ~ "Massa Carrara",
      TRUE ~ territorio
    )
  ) %>%
  filter(!is.na(territorio)) %>%
  filter(territorio %in% prov_names) %>%
  transmute(
    prov_name = territorio,
    unemployment_rate = as.numeric(
      gsub(",", ".", as.character(dplyr::pick(matches("^Totale$|Totale"))[[1]]))
    )
  ) %>%
  group_by(prov_name) %>%                              
  summarise(
    unemployment_rate = first(na.omit(unemployment_rate)),
    .groups = "drop"
  )

nrow(unemp_clean)
summary(unemp_clean$unemployment_rate)

## 5.2 Save RDS
saveRDS(
  provinces_joined,
  "data_clean/provinces_prov_level.rds"
)


# 6. Read and explore education data (regional) ####
prov <- readRDS("data_clean/provinces_prov_level.rds")


regions_lookup <- regions_sf %>%
  st_drop_geometry() %>%
  transmute(
    cod_reg = COD_REG,
    region_name = DEN_REG
  ) %>%
  distinct()

nrow(regions_lookup) 

edu_raw <- read_excel("data_raw/education_data.xlsx")
names(edu_raw)

# After reading edu_raw:
edu_tmp <- edu_raw %>%
  rename(region_name_raw = 1) %>%
  mutate(region_name_raw = trimws(as.character(region_name_raw))) %>%
  filter(!is.na(region_name_raw))

# See what is extra (diagnostic)
setdiff(unique(edu_tmp$region_name_raw), regions_lookup$region_name)

# matching the names of the regions with the ones in regions_sf
edu_tmp <- edu_raw %>%
  rename(region_name_raw = 1) %>%
  mutate(
    region_name_raw = trimws(as.character(region_name_raw)),
    region_name_raw = case_when(
      region_name_raw == "Valle d'Aosta / Vallée d'Aoste" ~ "Valle d'Aosta",
      region_name_raw == "Trentino Alto Adige / Südtirol" ~ "Trentino-Alto Adige",
      TRUE ~ region_name_raw
    )
  ) %>%
  filter(!is.na(region_name_raw)) %>%
  filter(!region_name_raw %in% c("Provincia Autonoma Bolzano / Bozen", "Provincia Autonoma Trento")) %>%
  filter(region_name_raw %in% regions_lookup$region_name)


n_distinct(edu_tmp$region_name_raw)

## 6.2 compute a low_education_share #### 
grep("Licenza di scuola elementare", names(edu_raw), value = TRUE)
grep("Licenza di scuola media", names(edu_raw), value = TRUE)
grep("^Totale$|Totale", names(edu_raw), value = TRUE)

### 6.2.1 Build the education indicator ####
edu_clean <- edu_tmp %>%
  transmute(
    region_name = region_name_raw,
    low_education_share = (
      as.numeric(`Licenza di scuola elementare, nessun titolo di studio`) +
        as.numeric(`Licenza di scuola media`)
    ) / as.numeric(Totale) * 100
  )

# Sanity checks
nrow(edu_clean)                       # should be 20
summary(edu_clean$low_education_share)

### 6.2.2 Add region codes (cod_reg) using the region lookup ####
edu_clean <- edu_clean %>%
  left_join(regions_lookup, by = "region_name") %>%
  select(cod_reg, region_name, low_education_share)

# Check that all regions got a code
sum(is.na(edu_clean$cod_reg))         # should be 0

### 6.2.3 Join to provinces (prov has cod_reg already)
prov2 <- prov %>%
  left_join(edu_clean %>% select(cod_reg, low_education_share), by = "cod_reg")

# Check join success
sum(is.na(prov2$low_education_share)) # should be 0
summary(prov2$low_education_share)

### 6.2.3 Save checkpoint ####
saveRDS(prov2, "data_clean/provinces_plus_education.rds")


# 7. Read and explore nutrition and sedentariness

prov2 <- readRDS("data_clean/provinces_plus_education.rds")
life_raw <- read_excel("data_raw/nutrition_data.xlsx")
names(life_raw)

## 7.1 Clean and keep only 20 regions ####
life_clean <- life_raw %>%
  rename(
    region_name_raw = territorio,
    adequate_nutrition = `adequate nutrition`,
    sedentariness = sedentariness
  ) %>%
  mutate(
    region_name_raw = trimws(as.character(region_name_raw)),
    region_name = case_when(
      region_name_raw == "Valle d'Aosta/Vallée d'Aoste" ~ "Valle d'Aosta",
      region_name_raw == "Trentino-Alto Adige/Südtirol" ~ "Trentino-Alto Adige",
      region_name_raw == "Trentino Alto Adige / Südtirol" ~ "Trentino-Alto Adige",
      TRUE ~ region_name_raw
    ),
    adequate_nutrition = as.numeric(adequate_nutrition),
    sedentariness = as.numeric(sedentariness)
  ) %>%
  # drop non-regional rows
  filter(!region_name_raw %in% c(
    "Nord","Nord-Ovest","Nord-Est","Centro","Sud e Isole","Sud","Isole","Italia"
  )) %>%
  # drop autonomous provinces (not regions)
  filter(!region_name_raw %in% c("Bolzano/Bozen","Trento")) %>%
  # keep only official regions
  filter(region_name %in% regions_lookup$region_name) %>%
  transmute(region_name, adequate_nutrition, sedentariness)

# check
nrow(life_clean)                     # should be 20
summary(life_clean$adequate_nutrition)
summary(life_clean$sedentariness)

## 7.2 join to provinces ####
life_clean <- life_clean %>%
  left_join(regions_lookup, by = "region_name") %>%
  select(cod_reg, adequate_nutrition, sedentariness)

prov3 <- prov2 %>%
  left_join(life_clean, by = "cod_reg")

# check
sum(is.na(prov3$adequate_nutrition))  # should be 0
sum(is.na(prov3$sedentariness))       # should be 0
summary(prov3$adequate_nutrition)
summary(prov3$sedentariness)

## 7.3 Save RDS ####
saveRDS(prov3, "data_clean/provinces_full.rds")


provinces_full <- readRDS("data_clean/provinces_full.rds")
df_export <- provinces_full %>% 
  st_drop_geometry()




# age and unemployment are missing.
prov_base <- readRDS("data_clean/provinces_prov_level.rds")
names(prov_base)

# join age
prov_base <- prov_base %>%
  left_join(
    age_clean %>% select(prov_name, pct_65plus),
    by = "prov_name"
  )

# join unemp
prov_base <- prov_base %>%
  left_join(
    unemp_clean %>% select(prov_name, unemployment_rate),
    by = "prov_name"
  )

# join education and nutrition
prov_base <- prov_base %>%
  left_join(
    edu_clean %>% select(cod_reg, low_education_share),
    by = "cod_reg"
  ) %>%
  left_join(
    life_clean %>% select(cod_reg, adequate_nutrition, sedentariness),
    by = "cod_reg"
  )

summary(prov_base)


# add region names
regions_sf <- st_read(
  "data_raw/provinces_shapefiles/Reg01012023_g/Reg01012023_g_WGS84.shp",
  quiet = TRUE
)

regions_lookup <- regions_sf %>%
  st_drop_geometry() %>%
  transmute(
    cod_reg = COD_REG,
    region_name = DEN_REG
  ) %>%
  distinct()

prov_base <- prov_base %>%
  left_join(regions_lookup, by = "cod_reg")

saveRDS(prov_base, "data_clean/provinces_full.rds")
provinces_full <- readRDS("data_clean/provinces_full.rds")
df_export <- provinces_full %>% 
  st_drop_geometry()

write_xlsx(df_export, "data_clean/provinces_full_table.xlsx")
