# Background Maps
crsEPSG4326 <- leafletCRS(crsClass="L.CRS.EPSG4326") 

# Background satellite map ----
observe({ 
  if (input$show_sat==T) {
    proxy  %>% 
      removeTiles(layerId='OSM')  %>% 
      addProviderTiles('Esri.WorldImagery',
                       layerId="satmap",
                       group="satmap",
                       options=leafletOptions(pane="back_maps",opacity=0.38)) }
  else if  (input$show_sat==F) {
    proxy %>% 
      removeTiles(layerId="satmap") %>%
      addTiles(layerId='OSM',options=tileOptions(pane='back_maps'))
  }}) # end map selections

# Topographic map ----
observe({
  if (input$show_topo==T) {
    proxy %>% 
      addTiles(
        urlTemplate='https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
        layerId='OTM',
        attribution="© OpenStreetMap-Contributors, SRTM | Map Display: © OpenTopoMap (CC-BY-SA)",
        option=tileOptions(
          tms=F,
          transparent=T,
          tileSize=256,
          pane="topo_map",
          minZoom=10,
          maxNativeZoom=15,
          maxZoom=20)
      )
  }
  else if (input$show_topo==F){
    proxy %>%
      removeTiles(layerId='OTM')
  }
})