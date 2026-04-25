#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
data_dir="${OSM_DATA_DIR:-${repo_root}/deploy/maps/data}"
pg_host="${PGHOST:-127.0.0.1}"
pg_port="${PGPORT:-55432}"
pg_database="${PGDATABASE:-gis}"
pg_user="${PGUSER:-postgres}"
pg_password="${PGPASSWORD:-postgres}"
osm2pgsql_image="${OSM2PGSQL_IMAGE:-iboates/osm2pgsql:latest}"
postgres_image="${POSTGRES_IMAGE:-postgres:16-alpine}"

default_countries="tanzania kenya uganda rwanda burundi"
read -r -a countries <<< "${OSM_COUNTRIES:-${default_countries}}"
drop_middle_tables="${OSM2PGSQL_DROP_MIDDLE_TABLES:-true}"

mkdir -p "${data_dir}"

run_psql() {
  docker run --rm --network=host \
    -e PGPASSWORD="${pg_password}" \
    "${postgres_image}" \
    psql \
      -h "${pg_host}" \
      -p "${pg_port}" \
      -U "${pg_user}" \
      -d "${pg_database}" \
      -v ON_ERROR_STOP=1 \
      "$@"
}

run_psql -c "CREATE SCHEMA IF NOT EXISTS gis;"

first_import=true
last_country_index=$((${#countries[@]} - 1))
for country_index in "${!countries[@]}"; do
  country="${countries[${country_index}]}"
  pbf_path="${data_dir}/${country}-latest.osm.pbf"
  if [ ! -f "${pbf_path}" ]; then
    url="https://download.geofabrik.de/africa/${country}-latest.osm.pbf"
    echo "Downloading ${url}"
    tmp_pbf_path="${pbf_path}.download"
    rm -f "${tmp_pbf_path}"
    curl -fL "${url}" -o "${tmp_pbf_path}"
    mv "${tmp_pbf_path}" "${pbf_path}"
  fi

  if [ "${first_import}" = true ]; then
    mode="--create"
    first_import=false
  else
    mode="--append"
  fi

  drop_args=()
  if [ "${drop_middle_tables}" = "true" ] && [ "${country_index}" -eq "${last_country_index}" ]; then
    drop_args=(--drop)
  fi

  echo "Importing protected areas from ${country}"
  docker run --rm --network=host \
    -e PGPASSWORD="${pg_password}" \
    -v "${data_dir}:/data:ro" \
    -v "${script_dir}:/maps:ro" \
    "${osm2pgsql_image}" \
    osm2pgsql \
      --output=flex \
      --style=/maps/protected_areas.lua \
      --schema=gis \
      --slim \
      "${drop_args[@]}" \
      "${mode}" \
      --host="${pg_host}" \
      --port="${pg_port}" \
      --database="${pg_database}" \
      --username="${pg_user}" \
      "/data/$(basename "${pbf_path}")"
done

run_psql <<'SQL'
ALTER TABLE gis.protected_areas
  ALTER COLUMN geom TYPE geometry(MultiPolygon, 4326)
  USING ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3));

DELETE FROM gis.protected_areas
WHERE geom IS NULL OR ST_IsEmpty(geom);

CREATE INDEX IF NOT EXISTS protected_areas_geom_idx
  ON gis.protected_areas
  USING GIST (geom);

CREATE INDEX IF NOT EXISTS protected_areas_name_idx
  ON gis.protected_areas (name);

ANALYZE gis.protected_areas;

SELECT count(*) AS protected_area_count FROM gis.protected_areas;
SQL
