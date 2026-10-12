# Public Lands Tracker

The tracker has moved to a static JavaScript + Leaflet app. Use **[Public Lands Tracker](https://garrettgcraig.com/wilderness)**.

The maintained application source lives in **[garrettgcraig/Personal-Website](https://github.com/garrettgcraig/Personal-Website)**:

- [Page](https://github.com/garrettgcraig/Personal-Website/blob/main/wilderness.html)
- [Application JavaScript](https://github.com/garrettgcraig/Personal-Website/blob/main/assets/js/lands-tracker.js)
- [Development, basemaps, storage, backups and deployment](https://github.com/garrettgcraig/Personal-Website/blob/main/docs/public-lands-tracker.md)
- [R boundary preparation](https://github.com/garrettgcraig/Personal-Website/blob/main/data/build_layers.R)

The public app needs no Shiny server or R process. It tracks wilderness areas, National Park Service units and national forests. Visits save in the current browser; export CSV for backup or transfer to another browser. Old Shiny CSV exports with `name` or `wid` columns can be imported. Cross-device account syncing is not included.

## Legacy Shiny reference

The original Shiny app, bundled data and preparation script are preserved under `legacy/`. They are historical reference, not the production deployment. To run that version, install `shiny`, `bslib`, `leaflet`, `sf`, `dplyr`, `DT`, `jsonlite` and `scales`, then run `shiny::runApp("legacy")` from this repository root. Its visited list is session-only, so export before closing.

For new changes, use the maintained website repository. Keeping one production source avoids the old Shiny app and live website drifting apart.
