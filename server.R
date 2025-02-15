# Chill Path
# Created by Svetlana Serikova Sep 2023
#rm(list=ls()) # Clear local variables

# Packages ----
# Custom download of geoshaper
# https://github.com/RedOakStrategic/geoshaper
library(shiny)
library(shinyWidgets)
library(shinyjs)
library(shinybusy)
library(rsconnect)
library(Rcpp)
library(reshape2)
library(plotly)
library(leaflet)
library(leaflet.extras)
library(leaflet.extras2)
library(leafem)
library(leafgl)
library(dplyr)
library(gstat)
library(raster)
library(geoshaper)
library(stars)
library(tidyverse)
library(sp)
library(sf)
library(htmlwidgets)
library(lwgeom)

# Source  script for data processing and functions ----
source("./data_scripts/data_processing.R",local=T)

## Server script ----
server <- function(input,output,session){
  # Set name and zone
  app_name='Chill Path'
  UTM_zone=32
  start_zoom=13.4
  # Create reactive variables for routes
  selected_building <- reactiveVal(NULL)
  selected_destination <- reactiveVal(NULL)
  filtered_osm <- reactiveVal(NULL)
  # Create reactive values for the "Cool areas" layers
  show_sk9 <- reactiveVal(F)
  show_sk12 <- reactiveVal(F)
  show_sk15 <- reactiveVal(F)
  # Create reactive values for the "Hot areas" layers
  show_msb2018_2020 <- reactiveVal(F)
  show_msb2019_2021 <- reactiveVal(F)
  show_msb2020_2022 <- reactiveVal(F)
  # Create a reactive value to track the state of the Green Index layer
  show_green_index <- reactiveVal(F)
  # Custom HTML control for the disclaimer popup
  observe({session$sendCustomMessage("hideDisclaimer","disclaimer")})
  # Initialize leaflet ----
  output$Map <- renderLeaflet({
    leaflet(
      # Leaflet rendering and options
      options=leafletOptions(maxZoom=18,
                             wheelPxPerZoomLevel=80,
                             zoomAnimation=T,
                             worldCopyJump=T,
                             preferCanvas=T,
                             doubleClickZoom=F,
                             # map won't update tiles until zoom is done
                             updateWhenZooming=T,
                             # map won't load new tiles when panning
                             updateWhenIdle=F,
                             updateInterval=50)) %>%
      # Make it possible to store tile in browser cache (faster)
      enableTileCaching() %>% 
      setView(lng=20.2630,lat=63.8258,zoom=start_zoom)  %>% 
      addControlGPS(options=gpsOptions(position="bottomleft",activate=T, 
                                       autoCenter=T,setView=F)) %>%
      addScaleBar(position=c("bottomright"),options=scaleBarOptions(maxWidth=250,metric=T,imperial=F)) %>%
      addMouseCoordinates() %>%
      addMapPane('back_maps',100) %>%
      addTiles(layerId='OSM',options=leafletOptions(pane="back_maps")) %>%
      # Map pane layer order
      addMapPane("topo_map",zIndex=110) %>%
      addMapPane("ortho",zIndex=140)
  }) 
  # Leaflet proxy
  proxy <- leafletProxy("Map") # proxy for accessing map
  # Background maps
  source("data_scripts/background_maps.R",local=T)
  # Function to filter osm
  filterdata <- function(osm,bg,rp) {
    filtered_data <- osm[osm$sourceID %in% bg$sourceID & osm$destID %in% rp$destID, ]
    return(filtered_data)}
  # Palette for routes
  type_palette <- c("#007ea7","#003459","#90e0ef")
  proxy %>% clearGroup("buildings")
  # Buildings
  observe({
    proxy %>%
      addPolygons(
        data=bg,
        fillColor="#272b30",
        fillOpacity=0.5,
        color="#272b30",
        weight=3,
        group="buildings",
        label=~paste(address),
        labelOptions=labelOptions(
          direction="auto",
          style=list(fontSize="14px")
        )
      )
  })
  # Observe the click event on the "bg" polygons and toggle the destinations in the legend
  sf_use_s2(FALSE)
  observeEvent(input$Map_shape_click, {
    selected_building <- input$Map_shape_click
    
    ###########
    # JONAS: Filtrera fram OSM för byggnader och rastplatser som låg närmast de två klicken
    clicked_src_point <- st_point(c(selected_building$lng,selected_building$lat)) # Omvandla först klickade koordinater till en punkt
    clicked_src_sf <- st_sfc(clicked_src_point,crs=st_crs(bg$geometry)) # Sätt koordsys till byggnadens för avståndsberäkningen
    bg_distances <- as.numeric(st_distance(bg$geometry,clicked_src_sf)) # Beräkna avstånd till respektive punkt från klickpunkten
    bg_threshold <- 4.5e-5 # Ca 5 meter från klicket (4.5e-5 grader) för att inte kräva så exakta klick. Kan justeras...
    nearest_bg <<- bg[bg_distances < bg_threshold, ]
    ###########
    
    # Check if a building is selected
    selected_building <- T 
    # Determine if destinations should be shown in the legend
    show_destinations <- selected_building
    # Clear the awesome-markers group from the leafletProxy
    proxy %>% clearGroup("awesome-markers")
    # Add the destination markers
    if (show_destinations) {
      awic <- makeAwesomeIcon(
        icon="leaf",
        iconColor="#367E18",
        markerColor="white",
        library="fa"
      )
      proxy %>%
        addAwesomeMarkers(icon=awic,
                          data=rp,
                          group="awesome-markers",
                          label=~paste(namn),
                          labelOptions=labelOptions(
                            direction="auto",
                            style=list(fontSize="14px")))
    }
  })
  # Display icons
  tree_icon <- icon("tree")
  clock_icon <- icon("clock")
  tape_icon <- icon("ruler")
  burger_icon <- icon("hamburger")
  shade_icon <- icon("adjust")
  therm_icon <- icon("thermometer")
  
  observeEvent(input$Map_marker_click, {
    selected_destination <- input$Map_marker_click
    if (!is.null(selected_destination)) {
      
      ###########
      # JONAS: Filtrera fram OSM för byggnader och rastplatser som låg närmast de två klicken
      proxy %>% clearGroup("routes")
      clicked_dest_point <- st_point(c(selected_destination$lng,selected_destination$lat)) # Omvandla först klickade koordinater till en punkt
      clicked_dest_sf <- st_sfc(clicked_dest_point,crs=st_crs(rp$geometry)) # Sätt koordsys till rastplatsens för avståndsberäkningen
      rp_distances <- as.numeric(st_distance(rp$geometry,clicked_dest_sf)) # Beräkna avstånd till respektive punkt från klickpunkten
      rp_threshold <- 4.5e-5 # Ca 5 meter från klicket (4.5e-5 grader) för att inte kräva så exakta klick
      nearest_rp <- rp[rp_distances < rp_threshold, ]
      filtered_osm <- filterdata(osm,nearest_bg,nearest_rp)
      ###########
      
      custom_label <- lapply(seq(nrow(filtered_osm)), function(i) {
        type <- filtered_osm$type[i]
        icon <- switch(type,
                       "Car"=icon("car"),
                       "Bike"=icon("bicycle"),
                       "Foot"=icon("walking")
        )
        label <- HTML(paste(
          "Transportation:",icon,
          "<br>",clock_icon,"Duration, min:",round(filtered_osm$durations[i],2),
          "<br>",tape_icon,"Distance, km:",round(filtered_osm$distances_km[i],3),
          "<br>", burger_icon,"Calories burned, kcal:",filtered_osm$cal_burnt_kcal[i],
          "<br>Carbon emitted, g:",round(filtered_osm$CO2_emitted_g[i],3),
          "<br>Days needed for",tree_icon,"to absorb emissions:",round(filtered_osm$tree_abs_days[i],0),
          "<br>% route in",shade_icon,"shade at 9 am:",round(filtered_osm$percent_shade_0900[i],0),
          "<br>% route in",shade_icon,"shade at 12 pm:",round(filtered_osm$percent_shade_1200[i],0),
          "<br>% route in",shade_icon,"shade at 15 pm:",round(filtered_osm$percent_shade_1500[i],0),
          "<br>average",therm_icon,"2018-2020:",round(filtered_osm$t_2018_2020[i],0),"&deg;C",
          "<br>average",therm_icon,"2019-2021:",round(filtered_osm$t_2019_2021[i],0),"&deg;C",
          "<br>average",therm_icon,"2020-2022:",round(filtered_osm$t_2020_2022[i],0),"&deg;C"
        ))
        return(label)
      })
      custom_popup <- lapply(seq(nrow(filtered_osm)), function(i) {
        type <- filtered_osm$type[i]
        icon <- switch(type,
                       "Car"=icon("car"),
                       "Bike"=icon("bicycle"),
                       "Foot"=icon("walking")
        )
        popup_content <- HTML(paste(
          "<div style='font-size: 14px; white-space: nowrap; max-width: 2200px;'>",
          "Transportation:",icon,
          "<br>",clock_icon,"Duration, min:",round(filtered_osm$durations[i],2),
          "<br>",tape_icon,"Distance, km:",round(filtered_osm$distances_km[i],3),
          "<br>", burger_icon,"Calories burned, kcal:",filtered_osm$cal_burnt_kcal[i],
          "<br>Carbon emitted, g:",round(filtered_osm$CO2_emitted_g[i],3),
          "<br>Days needed for",tree_icon,"to absorb emissions:",round(filtered_osm$tree_abs_days[i],0),
          "<br>% route in",shade_icon,"shade at 9 am:",round(filtered_osm$percent_shade_0900[i],0),
          "<br>% route in",shade_icon,"shade at 12 pm:",round(filtered_osm$percent_shade_1200[i],0),
          "<br>% route in",shade_icon,"shade at 15 pm:",round(filtered_osm$percent_shade_1500[i],0),
          "<br>average",therm_icon,"2018-2020:",round(filtered_osm$t_2018_2020[i],0),"&deg;C",
          "<br>average",therm_icon,"2019-2021:",round(filtered_osm$t_2019_2021[i],0),"&deg;C",
          "<br>average",therm_icon,"2020-2022:",round(filtered_osm$t_2020_2022[i],0),"&deg;C",
          "</div>"
        ))
        return(popup_content)
      })
      proxy %>% 
        addPolylines(
          data=filtered_osm,
          color=~colorFactor(type_palette,domain=c("Car","Bike","Foot"))(type),
          weight=5,
          opacity=1,
          label=custom_label,
          labelOptions=labelOptions(
            interactive=T,
            direction="auto",
            style=list(fontSize="14px")
          ),
          popup=custom_popup,
          options=popupOptions(
            maxWidth="auto",
            autoPan=TRUE,
            autoPanPadding=c(5,5)),
          group="routes",
          highlight=highlightOptions(
            weight=5,
            color="#272b30",
            fillOpacity=0.7,
            bringToFront=TRUE
          )
        )
    }
  })
  # Cool areas ----
  observeEvent(input$cool_areas, {
    selected_layers <- input$cool_areas
    layer_info <- list(
      list(name="sk9",data=sk9,show=show_sk9,fillColor="black"),
      list(name="sk12",data=sk12,show=show_sk12,fillColor="black"),
      list(name="sk15",data=sk15,show=show_sk15,fillColor="black")
    )
    for (layer in layer_info) {
      name <- layer$name
      data <- layer$data
      show <- layer$show
      fillColor <- layer$fillColor
      if (name %in% selected_layers) {
        proxy %>%
          clearGroup("green_index") %>%
          clearGroup("cool_areas") %>%
          clearGroup(c("hot_areas","MSB_2018_2020","MSB_2019_2021","MSB_2020_2022")) %>%
          clearShapes() %>% 
          addPolygons(
            data=data,
            fillColor=fillColor,
            fillOpacity=0.7,
            color="transparent",
            weight=2,
            group="cool_areas"
          ) %>%
          addPolygons(
            data=bg,
            fillColor="#ffe536",
            fillOpacity=0.6,
            color="#ffe536",
            weight=3,
            group="buildings"
          )
      } else {
        show(F)
      }
    }
  })
  # MSB layers ----
  observeEvent(input$hot_areas, {
    proxy %>%
      clearGroup("green_index") %>%
      clearGroup("cool_areas") %>%
      clearGroup(c("hot_areas","MSB_2018_2020","MSB_2019_2021","MSB_2020_2022")) %>%
      clearShapes()
    # Check if any of the MSB layers are selected
    msb_layers <- c("MSB_2018_2020","MSB_2019_2021","MSB_2020_2022")
    msb_layers_selected <- any(msb_layers %in% input$hot_areas)
    if (msb_layers_selected) {
      # Loop through the MSB layers
      for (msb_layer in msb_layers) {
        show_function <- paste("show_",msb_layer,sep="")
        show <- ifelse(msb_layer %in% input$hot_areas,T,F)
        if (show) {
          proxy %>%
            addRasterImage(
              x=get(msb_layer),
              colors=ramp,
              opacity=0.7,
              group="hot_areas"
            )
          assign(show_function,T,envir=.GlobalEnv)
        } else {
          assign(show_function,F,envir=.GlobalEnv)
        }
      }
      # Recolor the "bg" layer
      proxy %>%
        addPolygons(
          data=bg,
          fillColor="#272b30",
          fillOpacity=0.1,
          color="#272b30",
          weight=2,
          group="buildings"
        )
    } else {
      clearImages("hot_areas") 
    }
  })
  # GI layer ----
  observe({
    if (input$show_green_index) {
      # Add the Green Index layer to the map
      proxy %>%
        addPolylines(
          data=gi,
          color=~leaflet::colorNumeric(
            palette=c("#eca733","#b6d326","#367E18"),
            domain=round(gi$green_index,digits=2)
          )(round(gi$green_index,digits=2)),
          weight=3,
          opacity=0.8,
          group="green_index",
          label=~paste("Green Index:",round(gi$green_index,digits=2)),
          labelOptions=labelOptions(
            direction="auto",
            style=list(fontSize="14px")
          ),
          highlight=highlightOptions(
            weight=5,
            color="#272b30",
            fillOpacity=0.7,
            bringToFront=TRUE
          )
        )
    } else {
      # Remove the Green Index layer from the map if not selected
      proxy %>%
        removeShape("green_index")
    }
  })
} # END ----