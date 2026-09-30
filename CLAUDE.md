# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Commands

```bash
make lint        # helm lint
make template    # render templates to stdout with default values
make validate    # helm template piped into kubeconform -strict
make package     # lint + helm package → *.tgz (local test only)
make clean       # remove *.tgz
```

Releases are not made from the Makefile. semantic-release runs in `.github/workflows/release.yml` on pushes to `main` and `release/**`. It derives the version from Conventional Commits, and `build_tools/set-versions.js` writes it into `Chart.yaml`. It then commits, tags and publishes the GitHub release. The published release triggers `.github/workflows/package.yml`, which runs `helm package`, attaches the `.tgz` to the release and pushes it to `oci://ghcr.io/<owner>/charts`.

## Architecture

The chart deploys the web UI of `genebit/s3-garagehq-webui` (image `genebit/garage-webui`). Garage itself is not part of the chart.

The web UI is a single Go binary in a `FROM scratch` image. It listens on `PORT` (3909). It reads its Garage connection from environment variables (`API_BASE_URL`, `API_ADMIN_KEY`, `S3_ENDPOINT_URL`, `S3_REGION`), or else from `/etc/garage.toml`. Its state (`users.json`, audit log, temp dir) lives under `/data`.

### Key conventions

- `replicas: 1` and `strategy: Recreate` are hard-coded in `templates/deployment.yaml`. Sessions are in memory upstream (`backend/utils/session.go`) and the user store is a single file, so do not expose a replica count. `values.schema.json` rejects `replicaCount > 1`.
- Env vars are rendered only when their value is non-empty. This keeps the in-binary defaults and the `garage.toml` fallback working.
- Every inline secret value goes into the one chart Secret, built by the `garage-webui.secretData` helper. The Secret is rendered only when that helper yields something. The same output feeds the `checksum/secret` pod annotation. An `existingSecret` always takes precedence over the inline value.
- `garage.toml` contains `rpc_secret`, so it is only ever mounted from a Secret (`garageConfig.existingSecret`), never from a ConfigMap.
- Value checks that the schema cannot express go in `garage-webui.validate`, which is included at the top of `deployment.yaml`. An example is that Google sign-in requires `allowedDomains`, whose upstream default is a university's domains.
- Probes get `basePath` prefixed by the `garage-webui.probe` helper. `/` redirects (301) when `BASE_PATH` is set.
