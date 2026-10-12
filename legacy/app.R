library(shiny)
library(bslib)
library(leaflet)
library(sf)
library(dplyr)
library(DT)
library(jsonlite)

# ---------------------------------------------------------------------------
# Load wilderness boundaries
# ---------------------------------------------------------------------------
wild <- st_read("data/wilderness_areas.geojson", quiet = TRUE) |>
  mutate(
    row_id = row_number(),
    label = paste0(
      "<strong>", name, "</strong><br>",
      state, " | ", agency, "<br>",
      scales::comma(acres), " acres",
      if_else(!is.na(designated), paste0("<br>Designated ", designated), "")
    ),
    acres_fmt = scales::comma(acres)
  )

# Pre-compute centroids for fly-to on search
centroids <- st_centroid(wild, of_largest_polygon = TRUE)
coords <- st_coordinates(centroids)
wild$lng <- coords[, 1]
wild$lat <- coords[, 2]

name_choices <- sort(wild$name)

# ---------------------------------------------------------------------------
# Color palettes
# ---------------------------------------------------------------------------
pal_unvisited <- "#5a8a5e"
pal_visited   <- "#d4a017"

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- page_sidebar(
  title = "U.S. Wilderness Tracker",
  theme = bs_theme(
    bootswatch = "flatly",
    primary = "#2c6e49",
    "navbar-bg" = "#2c6e49"
  ),

  sidebar = sidebar(
    width = 340,

    h5("Search & Select"),
    selectizeInput(
      "search", "Find a wilderness area:",
      choices = NULL,
      options = list(placeholder = "Type a name...")
    ),
    actionButton("fly_to", "Zoom to selected", class = "btn-primary btn-sm mb-3", icon = icon("crosshairs")),

    hr(),
    h5("Your Visit List"),
    p(
      class = "text-muted small",
      "Click polygons on the map or use the search above to mark areas visited."
    ),
    uiOutput("stats_ui"),
    DTOutput("visited_table"),

    hr(),
    h5("Save / Load"),
    downloadButton("export_btn", "Export visited list (.csv)", class = "btn-outline-primary btn-sm mb-2"),
    fileInput("import_file", "Import visited list (.csv)", accept = ".csv"),
    actionButton("clear_btn", "Clear all visits", class = "btn-outline-danger btn-sm mt-2", icon = icon("trash"))
  ),

  leafletOutput("map", height = "100%"),

  # make map fill available vertical space
  tags$style(HTML("
    .main { height: calc(100vh - 60px); }
    .bslib-sidebar-layout > .main { padding: 0 !important; }
    #map { height: 100% !important; min-height: 600px; }
  "))
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {

  # Reactive set of visited row IDs
  visited <- reactiveVal(integer(0))

  # Update selectize server-side for performance
updateSelectizeInput(session, "search", choices = name_choices, server = TRUE)

  # ------ Base map ----------------------------------------------------------
  output$map <- renderLeaflet({
    leaflet() |>
      addProviderTiles(providers$CartoDB.Positron, group = "Light") |>
      addProviderTiles(providers$Esri.WorldTopoMap, group = "Topo") |>
      addProviderTiles(providers$Esri.WorldImagery, group = "Satellite") |>
      addLayersControl(
        baseGroups = c("Light", "Topo", "Satellite"),
        options = layersControlOptions(collapsed = TRUE)
      ) |>
      setView(lng = -98.5, lat = 39.8, zoom = 4)
  })

  # ------ Redraw polygons when visited list changes -------------------------
  observe({
    v <- visited()

    proxy <- leafletProxy("map") |>
      clearGroup("wilderness")

    # Unvisited polygons
    unvisited_sf <- wild |> filter(!row_id %in% v)
    if (nrow(unvisited_sf) > 0) {
      proxy <- proxy |>
        addPolygons(
          data = unvisited_sf,
          group = "wilderness",
          layerId = ~row_id,
          fillColor = pal_unvisited,
          fillOpacity = 0.35,
          color = pal_unvisited,
          weight = 1.2,
          opacity = 0.7,
          label = ~lapply(label, HTML),
          highlightOptions = highlightOptions(
            weight = 3, color = "#ffffff", fillOpacity = 0.6, bringToFront = TRUE
          )
        )
    }

    # Visited polygons
    visited_sf <- wild |> filter(row_id %in% v)
    if (nrow(visited_sf) > 0) {
      proxy <- proxy |>
        addPolygons(
          data = visited_sf,
          group = "wilderness",
          layerId = ~row_id,
          fillColor = pal_visited,
          fillOpacity = 0.6,
          color = pal_visited,
          weight = 1.5,
          opacity = 0.9,
          label = ~lapply(label, HTML),
          highlightOptions = highlightOptions(
            weight = 3, color = "#ffffff", fillOpacity = 0.8, bringToFront = TRUE
          )
        )
    }
  })

  # ------ Map click: toggle visited -----------------------------------------
  observeEvent(input$map_shape_click, {
    click <- input$map_shape_click
    if (is.null(click$id)) return()
    rid <- as.integer(click$id)
    v <- visited()
    if (rid %in% v) {
      visited(setdiff(v, rid))
    } else {
      visited(c(v, rid))
    }
  })

  # ------ Search: mark visited & fly to -------------------------------------
  observeEvent(input$search, {
    req(input$search)
    sel <- input$search
    match_row <- wild |> filter(name == sel)
    if (nrow(match_row) == 0) return()
    rid <- match_row$row_id[1]
    v <- visited()
    if (!rid %in% v) {
      visited(c(v, rid))
    }
  })

  # Fly-to button
  observeEvent(input$fly_to, {
    req(input$search)
    match_row <- wild |> filter(name == input$search)
    if (nrow(match_row) == 0) return()
    leafletProxy("map") |>
      flyTo(lng = match_row$lng[1], lat = match_row$lat[1], zoom = 11)
  })

  # ------ Stats -------------------------------------------------------------
  output$stats_ui <- renderUI({
    v <- visited()
    n <- length(v)
    pct <- round(100 * n / nrow(wild), 1)
    total_acres <- wild |> filter(row_id %in% v) |> pull(acres) |> sum(na.rm = TRUE)
    tagList(
      div(
        class = "d-flex justify-content-between mb-2",
        span(class = "fw-bold", paste0(n, " / ", nrow(wild), " visited")),
        span(class = "text-muted", paste0(pct, "%"))
      ),
      div(
        class = "progress mb-3",
        style = "height: 8px;",
        div(
          class = "progress-bar bg-warning",
          role = "progressbar",
          style = paste0("width: ", pct, "%;"),
          `aria-valuenow` = pct,
          `aria-valuemin` = "0",
          `aria-valuemax` = "100"
        )
      ),
      p(class = "text-muted small", paste0(scales::comma(total_acres), " total acres visited"))
    )
  })

  # ------ Visited table -----------------------------------------------------
  output$visited_table <- renderDT({
    v <- visited()
    if (length(v) == 0) {
      return(
        datatable(
          data.frame(Name = character(), State = character(), Acres = character()),
          options = list(dom = "t", language = list(emptyTable = "No areas visited yet")),
          rownames = FALSE
        )
      )
    }
    wild |>
      st_drop_geometry() |>
      filter(row_id %in% v) |>
      arrange(name) |>
      select(Name = name, State = state, Agency = agency, Acres = acres_fmt) |>
      datatable(
        rownames = FALSE,
        options = list(pageLength = 10, dom = "ftp", scrollY = "250px"),
        selection = "single"
      )
  }, server = FALSE)

  # ------ Export visited list -----------------------------------------------
  output$export_btn <- downloadHandler(
    filename = function() {
      paste0("wilderness_visits_", Sys.Date(), ".csv")
    },
    content = function(file) {
      v <- visited()
      export_df <- wild |>
        st_drop_geometry() |>
        filter(row_id %in% v) |>
        select(name, state, agency, acres, designated, wid)
      write.csv(export_df, file, row.names = FALSE)
    }
  )

  # ------ Import visited list -----------------------------------------------
  observeEvent(input$import_file, {
    req(input$import_file)
    imported <- tryCatch(
      read.csv(input$import_file$datapath, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
    if (is.null(imported)) {
      showNotification("Could not read CSV file.", type = "error")
      return()
    }
    # Match by name or wid
    if ("wid" %in% names(imported)) {
      matched <- wild |> filter(wid %in% imported$wid) |> pull(row_id)
    } else if ("name" %in% names(imported)) {
      matched <- wild |> filter(name %in% imported$name) |> pull(row_id)
    } else {
      showNotification("CSV must have a 'name' or 'wid' column.", type = "error")
      return()
    }
    visited(union(visited(), matched))
    showNotification(
      paste0("Imported ", length(matched), " wilderness areas."),
      type = "message"
    )
  })

  # ------ Clear all ---------------------------------------------------------
  observeEvent(input$clear_btn, {
    visited(integer(0))
  })
}

shinyApp(ui, server)
