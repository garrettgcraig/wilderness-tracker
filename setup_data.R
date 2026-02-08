# setup_data.R
# Downloads and processes the National Wilderness Areas shapefile
# from wilderness.net into a simplified GeoJSON for the Shiny app.
# Run this once before launching the app.

library(sf)
library(dplyr)

data_dir <- file.path(getwd(), "data")
zip_path <- file.path(data_dir, "Wilderness_Areas.zip")
geojson_path <- file.path(data_dir, "wilderness_areas.geojson")

if (file.exists(geojson_path)) {
  message("GeoJSON already exists at: ", geojson_path)
  message("Delete it and re-run this script to refresh the data.")
} else {
  # Download shapefile from wilderness.net
  message("Downloading wilderness areas shapefile...")
  download.file(
    url = "https://www.wilderness.net/GIS/Wilderness_Areas.zip",
    destfile = zip_path,
    mode = "wb"
  )

  # Unzip
  message("Extracting shapefile...")
  unzip(zip_path, exdir = file.path(data_dir, "shp"))

  # Find the .shp file
shp_file <- list.files(
    file.path(data_dir, "shp"),
    pattern = "\\.shp$",
    full.names = TRUE,
    recursive = TRUE
  )
  if (length(shp_file) == 0) stop("No .shp file found in archive.")
  message("Reading: ", shp_file[1])

  wild <- st_read(shp_file[1], quiet = TRUE)

  # Inspect columns
  message("Columns: ", paste(names(wild), collapse = ", "))

  # Simplify geometry to reduce file size for web rendering
  message("Simplifying geometry (tolerance = 500m)...")
  wild_simple <- wild |>
    st_transform(5070) |>
    st_simplify(dTolerance = 500) |>
    st_transform(4326)

  # Keep only the columns we need
  # Typical columns: NAME or WILDERNE_1 for name, WID, GIS_ACRES, BOUNDARYST
  # Adjust column names based on what's in the shapefile
  name_col <- intersect(names(wild_simple), c("NAME", "WILDERNE_1", "WildernessName"))
  if (length(name_col) == 0) {
    message("Available columns: ", paste(names(wild_simple), collapse = ", "))
    stop("Cannot find a wilderness name column. Check column names above and adjust script.")
  }
  name_col <- name_col[1]

  # Build a clean sf object
  # Actual shapefile columns: NAME, STATE, Agency, Acreage, WID, Designated, etc.
  wild_clean <- wild_simple |>
    transmute(
      name = .data[[name_col]],
      acres = if ("Acreage" %in% names(wild_simple)) Acreage else if ("GIS_ACRES" %in% names(wild_simple)) GIS_ACRES else NA_real_,
      state = if ("STATE" %in% names(wild_simple)) STATE else NA_character_,
      agency = if ("Agency" %in% names(wild_simple)) Agency else if ("AGENCY" %in% names(wild_simple)) AGENCY else NA_character_,
      designated = if ("Designated" %in% names(wild_simple)) Designated else NA_character_,
      wid = if ("WID" %in% names(wild_simple)) WID else NA_integer_
    )

  # Write as GeoJSON
  message("Writing GeoJSON to: ", geojson_path)
  st_write(wild_clean, geojson_path, driver = "GeoJSON", delete_dsn = TRUE)

  # Clean up
  unlink(file.path(data_dir, "shp"), recursive = TRUE)
  unlink(zip_path)

  message("Done! ", nrow(wild_clean), " wilderness areas processed.")
}
