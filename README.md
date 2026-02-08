# U.S. Wilderness Tracker

An interactive Shiny app for tracking which U.S. wilderness areas you've visited. Built on boundary data from [Wilderness Connect](https://wilderness.net) covering all 843 areas in the National Wilderness Preservation System.

## Features

- Interactive Leaflet map with all 843 wilderness area boundaries
- Click polygons to toggle visited/unvisited (gold = visited, green = unvisited)
- Search by name with autocomplete
- Zoom-to-area button
- Progress stats: count, percentage, and total acres visited
- Sortable/searchable visited-areas table
- Export your visit list to CSV for safekeeping
- Import a previously exported CSV to restore your list
- Three basemap options: Light, Topo, and Satellite

## Setup

Install the required R packages:

```r
install.packages(c("shiny", "bslib", "leaflet", "sf", "dplyr", "DT", "jsonlite", "scales"))
```

Then launch the app:

```r
shiny::runApp()
```

The boundary data (`data/wilderness_areas.geojson`) is included in the repo. To refresh it from the latest [wilderness.net](https://wilderness.net) shapefile, delete the file and run `source("setup_data.R")`.

## Saving and restoring your list

- Click **Export visited list (.csv)** to download a CSV of your visited areas.
- To restore in a future session, use the **Import visited list (.csv)** file input to re-import the CSV. Areas are matched by wilderness ID (`wid`) or name.

## Data source

Wilderness area boundaries are from [Wilderness Connect (wilderness.net)](https://wilderness.net/visit-wilderness/gis-gps.php), maintained by the University of Montana. The data is available for public use.
