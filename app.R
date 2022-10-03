#4/7/2021 Nick Manna, ARKF, Inc. 
#This file, app.R, works with the sourced capture_efficiency.R file to create the PWD GSI MARS Capture Efficiency Tests app
#See Fieldwork App R script for more details 

# SET UP
#0.0: load libraries --------------
#shiny
library(shiny)
#pool for database connections
library(pool)
#odbc for database connections
library(odbc)
#tidyverse for data manipulations
library(tidyverse)
#shinythemes for colors
library(shinythemes)
#lubridate to work with dates
library(lubridate)
#shinyjs() to use easy java script functions
library(shinyjs)
#DT for datatables
library(DT)
#reactable for reactable tables
library(reactable)

#0.1: database connection and global options --------

#set default page length for datatables
options(DT.options = list(pageLength = 15))

#set db connection
#using a pool connection so separate connnections are unified
#gets environmental variables saved in local or pwdrstudio environment
poolConn <- dbPool(odbc(), dsn = "mars_testing", uid = Sys.getenv("shiny_uid"), pwd = Sys.getenv("shiny_pwd"))

#disconnect from db on stop 
onStop(function(){
  poolClose(poolConn)
})

#js warning about leaving page
jscode <- 'window.onbeforeunload = function() { return "Please use the button on the webpage"; };'

#0.2 source scripts.  ----
#each script contains a module, which includes UI and server code
source("capture_efficiency.R")


#1: UI FUNCTION -----
#initialize variables for UI and call all UI functions
#call all the UI functions

ui <- function(req){
  
  #1.1: load required variables -----
  #define global variables that will be required each time the UI runs
  
  # #capture efficiency high flow types
  high_flow_type <- dbGetQuery(poolConn, "select * from fieldwork.tbl_est_high_flow_efficiency_lookup")
  
  #capture efficiency asset types 
  cet_asset_type <- dbGetQuery(poolConn, "select distinct asset_type from external.mat_assets_ict_limited where component_id is not null order by asset_type") 
  
  #construction phase types
  con_phase <- dbGetQuery(poolConn, "select * from fieldwork.tbl_con_phase_lookup")
  
  #this function adds a little red star to indicate that a field is required. It uses HTML, hence "html_req"
  html_req <- function(label){
    HTML(paste(label, tags$span(style="color:red", tags$sup("*"))))
  }
  
  #this function adds a blue dagger to indicate that a field is required for future tests. It uses HTML. it is slightly Christian
  future_req <- function(label){
    HTML(paste(label, tags$span(style="color:blue", tags$sup("†"))))
  }
  
  #field test priority
  priority <- dbGetQuery(poolConn, "select * from fieldwork.tbl_field_test_priority_lookup")
  
  # 1.2: actual UI------------------------
  
  #use tagList so tags and shinyjs can be called without being inside of the navbarPage. When they're inside navbarpage, they create small invisible fake tabs that take up space and act weird when clicked on
  tagList(
    #call jscode to warn when leaving page
    tags$head(tags$script(jscode)),
    #must call useShinyjs() for shinyjs() functionality to work in app
    useShinyjs(),
    #navbarPage("Fieldwork", theme = shinytheme("cerulean"), id = "inTabset",
    #Capture Efficiency (Add/Edit Capture Efficiency Test, View Capture Efficiency Tests, View Future Capture Efficiency Tests)
    capture_efficiencyUI("capture_efficiency", high_flow_type = high_flow_type,
                         html_req = html_req, con_phase = con_phase, priority = priority,
                         future_req = future_req, cet_asset_type = cet_asset_type)
  )
  # )
  
}

# 2: server function ----
#call modules, referencing the UI names above. These are functions, so any data originating outside the function needs to be named as an argument, whether it is lookup data, or from another tab. Modules need to be assigned to variables so they can be used in other module functions. 
server <- function(input, output, session) {
  
  # 2.1: required variables -----
  #define global variables that will be defined each time server runs
  
  # #capture efficiency high flow types
  high_flow_type <- dbGetQuery(poolConn, "select * from fieldwork.tbl_est_high_flow_efficiency_lookup")
  
  #capture efficiency asset types 
  cet_asset_type <- dbGetQuery(poolConn, "select distinct asset_type from external.mat_assets_ict_limited where component_id is not null order by asset_type")
  
  #con phase
  con_phase <- dbGetQuery(poolConn, "select * from fieldwork.tbl_con_phase_lookup")
  
  #all system ids
  sys_id <- odbc::dbGetQuery(poolConn, paste0("select distinct system_id from external.mat_assets")) %>% 
    dplyr::arrange(system_id) %>% 
    dplyr::pull()
  
  #replace special characters with friendlier characters
  special_char_replace <- function(note){
    
    note_fix <- note %>% 
      str_replace_all(c("•" = "-", "ï‚§" = "-", "“" = '"', '”' = '"'))
    
    return(note_fix)
    
  }
  
  # 2.2: Server Module functions ---------------------------
  #Capture Efficiency
  capture_efficiency <- capture_efficiencyServer("capture_efficiency", parent_session = session,
                                                 poolConn = poolConn, high_flow_type = high_flow_type, con_phase = con_phase,
                                                 cet_asset_type = cet_asset_type, sys_id = sys_id, special_char_replace = special_char_replace)
  
}

#Run this function to run the app!
shinyApp(ui, server)
