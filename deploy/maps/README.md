# Self-Hosted Proposal Map Data

This directory contains the reproducible local/prod setup for the free map stack:

- `east-africa.pmtiles` is generated from Protomaps/OpenStreetMap and served as a static file.
- Protomaps font and sprite assets are copied into the same static asset directory.
- OSM protected-area polygons are imported into PostGIS and served by Tegola as `protected_areas`.

Generated map data is ignored by git.

## Local Basemap

```sh
cd /home/alexb/code/tegola
./deploy/maps/build-east-africa-pmtiles.sh
./deploy/maps/serve-map-assets.sh
```

This serves:

```text
http://localhost:8088/map-assets/east-africa.pmtiles
http://localhost:8088/map-assets/protomaps-assets/fonts/{fontstack}/{range}.pbf
http://localhost:8088/map-assets/protomaps-assets/sprites/v4/light.json
http://localhost:8088/map-assets/protomaps-assets/sprites/v4/light.png
```

## Local Protected Areas

With the local PostGIS container published on `localhost:55432`:

```sh
cd /home/alexb/code/tegola
./deploy/maps/import-protected-areas.sh
```

For faster local iteration you can limit the import to selected countries:

```sh
OSM_COUNTRIES="tanzania kenya" ./deploy/maps/import-protected-areas.sh
```

By default the script drops osm2pgsql middle tables after the final country to keep the
database smaller. Set `OSM2PGSQL_DROP_MIDDLE_TABLES=false` if you need to keep them.

Then start Tegola with:

```sh
POSTGIS_URI='postgres://postgres:postgres@127.0.0.1:55432/gis?sslmode=disable' \
TEGOLA_CONFIG="$PWD/deploy/maps/tegola.protected_areas.toml" \
PORT=9090 \
TEGOLA_BIND_HOST=0.0.0.0 \
./deploy/railway/start.sh
```

The public router path remains `/tegola`; locally the direct service is:

```text
http://localhost:9090/capabilities
http://localhost:9090/capabilities/protected_areas.json
http://localhost:9090/maps/protected_areas/5/19/16.pbf
```
