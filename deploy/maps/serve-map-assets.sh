#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
map_assets_dir="${MAP_ASSETS_DIR:-${repo_root}/deploy/maps/map-assets}"
port="${MAP_ASSETS_PORT:-8088}"
container_name="${MAP_ASSETS_CONTAINER:-safari-map-assets}"
detach="${MAP_ASSETS_DETACH:-true}"

if [ ! -f "${map_assets_dir}/east-africa.pmtiles" ]; then
  echo "Missing ${map_assets_dir}/east-africa.pmtiles. Run deploy/maps/build-east-africa-pmtiles.sh first." >&2
  exit 1
fi

docker rm -f "${container_name}" >/dev/null 2>&1 || true

docker_args=()
if [ "${detach}" = "true" ]; then
  docker_args+=(-d)
fi

docker run --rm \
  "${docker_args[@]}" \
  --name "${container_name}" \
  -p "${port}:80" \
  -v "${map_assets_dir}:/usr/share/nginx/html/map-assets:ro" \
  -v "${script_dir}/nginx.map-assets.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:1.25-alpine

if [ "${detach}" = "true" ]; then
  echo "Serving map assets at http://localhost:${port}/map-assets"
fi
