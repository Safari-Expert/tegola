# Safari Expert Railway Deployment

This repo tracks upstream Tegola, so Safari Expert deployment files are kept in separate `railway.*` and `deploy/railway/*` files to reduce fork-sync conflicts.

## Runtime

Railway should build with `Dockerfile.railway` through `railway.toml`. The container starts Tegola with:

```sh
/opt/tegola serve --config "$TEGOLA_CONFIG" --port "[::]:$PORT"
```

Set these Tegola service variables in Railway:

- `PORT=8080`
- `TEGOLA_BIND_HOST=::`
- `TEGOLA_CONFIG_URL=https://.../config.toml` or `TEGOLA_CONFIG=/opt/tegola_config/config.toml`
- Any provider variables referenced by the Tegola config, for example PostGIS connection variables.

If using a mounted config file, mount it at `/opt/tegola_config/config.toml` or set `TEGOLA_CONFIG` to the mounted path.

## Router

The public browser path is the global router, not the Tegola service domain:

```text
https://dev.meistercrm.com/tegola
```

Set the `global-router` Railway variable:

```text
TEGOLA_URL=http://tegola.railway.internal:8080
```

The router strips `/tegola/` before proxying. It also maps `/tegola/maps/{mapName}` to Tegola's native `/capabilities/{mapName}.json` endpoint so frontend clients can use the POC TileJSON path consistently.

## CI Deploy

`.github/workflows/railway-deploy.yml` deploys after the upstream `On push` workflow succeeds on `main`, and can also be triggered manually. It skips safely when Railway secrets are missing.

Required GitHub secrets:

- `RAILWAY_TOKEN`
- `RAILWAY_PROJECT_ID`
- `RAILWAY_TEGOLA_SERVICE_ID`

Optional GitHub variable:

- `RAILWAY_ENVIRONMENT`, defaulting to `development`

## Smoke Checks

After deploying Tegola and global-router, these should pass:

```sh
curl -i https://dev.meistercrm.com/tegola/capabilities
curl -i https://dev.meistercrm.com/tegola/maps/{mapName}
curl -i https://dev.meistercrm.com/tegola/maps/{mapName}/0/0/0.pbf
```
