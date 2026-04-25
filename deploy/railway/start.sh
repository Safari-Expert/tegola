#!/bin/sh
set -eu

config="${TEGOLA_CONFIG_URL:-${TEGOLA_CONFIG:-/opt/tegola_config/config.toml}}"
port="${PORT:-8080}"
bind_host="${TEGOLA_BIND_HOST:-::}"

case "$config" in
	http://*|https://*|-)
		;;
	*)
		if [ ! -f "$config" ]; then
			echo "Tegola config not found at $config. Set TEGOLA_CONFIG_URL or mount TEGOLA_CONFIG." >&2
			exit 1
		fi
		;;
esac

case "$bind_host" in
	"")
		bind_addr=":${port}"
		;;
	"["*"]")
		bind_addr="${bind_host}:${port}"
		;;
	*:*)
		bind_addr="[${bind_host}]:${port}"
		;;
	*)
		bind_addr="${bind_host}:${port}"
		;;
esac

echo "Starting Tegola on ${bind_addr} with config ${config}"
exec /opt/tegola serve --config "$config" --port "$bind_addr"
