library(shiny)
library(shinybusy)
library(plotly)
library(leaflet)
library(shinythemes)
library(shinydashboard)
library(shinyWidgets)
library(shinyBS)
library(leafgl)

# Graphical button shift ----
button_height <- 74
button_shift <- 50 # adjust margin from right border
# Shade labels
choice_labels <- c("shade at 9am"="sk9",
                   "shade at 12pm"="sk12",
                   "shade at 15pm"="sk15")
# MSB labels
msb_labels <- c("MSB_2018_2020"="MSB_2018_2020",
                "MSB_2019_2021"="MSB_2019_2021",
                "MSB_2020_2022"="MSB_2020_2022")
# UI ----
ui <- shinyUI(
  # Start bootstrap page theme ----
  bootstrapPage(theme="slate.min.css",
                add_busy_bar(color="white",height="8px"),              
                # Page size & html tags ----
                tags$style(type="text/css","html, body {width:100%;height:95.5%}"),  
                # Favicon ----
                tags$head(tags$link(rel="shortcut icon",href="norconsult.ico")),
                # Title panel and CPlogga ----
                div(
                  style="display: flex; align-items: center; margin-right: 22px;",
                  tags$div(style="margin-right: 2.4mm;"), # add space before CPlogga
                  img(src="CPlogga.png",height=46,width=38,style="margin-right: 1.7mm;"),
                  titlePanel("Chill Path",windowTitle="Norconsult"),
                ),
                # NC logga ----
                absolutePanel(top=12,right=0,width=210,draggable=F,
                              img(src="NClogga.png",height=50,width=200),  # add Norconsult logga
                ), 
                # leafletMap base map size ----                        
                leafglOutput("Map",width="100%",height="100%"), 
                # Maps dropdown panel
                absolutePanel(top=button_height,right=button_shift,daggable=F,
                              dropdownButton( 
                                inputId="dropdown_maps", 
                                size="sm",
                                width=250 ,
                                right=T,
                                circle=T,
                                tooltip=T,
                                label="Maps",
                                icon=icon("globe"),
                                # Check boxes   
                                awesomeCheckbox("show_sat","Show Satellite Map (Worldwide)", T),
                                awesomeCheckbox("show_topo","Show Open Topographic Map (Worldwide)")
                              )),
                absolutePanel(top=button_height,right=button_shift+40,draggable=F,
                              dropdownButton( 
                                size="sm",
                                width=250,
                                right=T,
                                circle=T,
                                tooltip=T,
                                label="Hot areas",
                                icon=icon("thermometer"), 
                                awesomeCheckboxGroup(
                                  inputId="hot_areas",
                                  label="Hot areas",
                                  choices=msb_labels)
                              )),
                absolutePanel(top=button_height,right=button_shift+80,draggable=F,
                              dropdownButton(
                                size="sm",
                                width=250,
                                right=T,
                                circle=T,
                                tooltip=T,
                                label="Cool areas",
                                icon=icon("adjust"), 
                                awesomeCheckboxGroup(
                                  inputId="cool_areas",
                                  label="Cool areas",
                                  choices=choice_labels)
                              )),
                absolutePanel(top=button_height,right=button_shift+120,draggable=F,
                              dropdownButton(
                                size="sm",
                                width=250,
                                right=T,
                                circle=T,
                                tooltip=T,
                                label="Green Index",
                                icon=icon("leaf"), 
                                awesomeCheckbox("show_green_index","Show Green Index",F)
                              )),
                # Add the disclaimer div
                div(id = "disclaimer", style = "background-color: #272B30; padding: 10px; text-align: center; border-radius: 5px;",
                    p(style = "color: white; font-size: 18px;", "Chill Path PROTOTYPE. Find your 'coolest' way around the city. Interactive webmap for Umeå. @ Norconsult")
                ),
                conditionalPanel(
                  condition="input.Map_shape_click",
                  HTML('<div id="legend" style="background-color: white; padding: 10px; text-align: center; border-radius: 5px; position: absolute; bottom: 100px; right: 10px;">
            <div style="background-color: black; opacity: 0.4; width: 20px; height: 20px; border: 2px solid #1f1f1f; display: inline-block;"></div>
            <p style="font-size: 12px; color: black;">Buildings</p>
            <div style="width: 20px; height: 20px; display: inline-block;">
            <i class="fa fa-leaf" style="color: #367E18; background-color: white; font-size: 18px;"></i>
            </div>
            <p style="font-size: 12px; color: black;">Destinations</p>')),
                conditionalPanel(
                  condition="input.hot_areas.length > 0",
                  HTML('<div id="msb-legend" style="background-color: white; padding: 10px; text-align: center; border-radius: 5px; position: absolute; bottom: 320px; right: 10px; width: 86px;">
          <div style="font-size: 12px; color: black;">Max temperature, &deg;C</div>
          <img src="MSBlegend.png" alt="MSB Legend" width="45px" height="580">
        </div>')),
                conditionalPanel(
                  condition="input.show_green_index",
                  HTML('<div id="legend" style="background-color: white; padding: 10px; text-align: center; border-radius: 5px; position: absolute; bottom: 230px; right: 10px; width: 86px;">
              <div>
                <span style="color: black;">0</span>
                <div style="background: linear-gradient(to bottom, #eca733, #b6d326, #367E18); height: 20px;"></div>
                <span style="color: black;">1</span>
              </div>
            </div>')),
                # Add custom JavaScript code to hide the disclaimer
                tags$script(
                  "
    Shiny.addCustomMessageHandler('hideDisclaimer',
      function(elementId) {
        // Hide the disclaimer after 10 seconds
        setTimeout(function() {
          var disclaimer = document.getElementById(elementId);
          if (disclaimer) {
            disclaimer.style.display = 'none';
          }
        }, 10000); // 10 seconds in milliseconds
      }
    );
    "
    )
  )
) # END ----