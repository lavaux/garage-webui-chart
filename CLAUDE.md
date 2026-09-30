# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Commands

```bash
make lint        # helm lint
make template    # render templates to stdout with default values
make package     # lint + helm package → *.tgz
make bump-patch  # increment patch version in Chart.yaml and commit
make bump-minor  # increment minor version in Chart.yaml and commit
make bump-major  # increment major version in Chart.yaml and commit
make release     # package + git tag + push + Forgejo release asset upload (requires FORGEJO_TOKEN)
make clean       # remove *.tgz
```

Validate the rendered output with
`helm template t . | docker run --rm -i ghcr.io/yannh/kubeconform -strict -summary -`.

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
