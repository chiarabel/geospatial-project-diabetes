library(htmlwidgets)

provinces_full <- readRDS("../data_clean/provinces_full.rds")
st_crs(provinces_full)
provinces_leaflet <- st_transform(provinces_full, 4326)

m <- leaflet(provinces_leaflet) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(
    fillColor = ~pal_mort(diabetes_mort_rate),
    weight = 0.4,
    fillOpacity = 0.8,
    label = ~paste0(prov_name, " – ", region_name),
    popup = ~paste0(
      "<b>", prov_name, "</b><br>",
      "<i>", region_name, "</i><br><br>",
      "<b>Diabetes mortality:</b> ", round(diabetes_mort_rate, 1), "<br><br>",
      "<b>Population 65+:</b> ", round(pct_65plus, 1), "%<br>",
      "<b>Unemployment:</b> ", round(unemployment_rate, 1), "%<br><br>",
      "<b>Sedentariness (region):</b> ", sedentariness, "%<br>",
      "<b>Adequate nutrition (region):</b> ", adequate_nutrition, "%<br>",
      "<b>Low education share (region):</b> ", round(low_education_share, 1), "%"
    )
  ) %>%
  addLegend(
    pal = pal_mort,
    values = ~diabetes_mort_rate,
    title = "Diabetes mortality rate<br>(per 10,000)",
    opacity = 0.9,
    position = "bottomright"
  )

# Save HTML
saveWidget(m, "docs/interactive_map.html", selfcontained = TRUE)
