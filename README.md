# garage-webui Helm chart

This chart deploys [Garage Web UI](https://github.com/genebit/s3-garagehq-webui), the `genebit` fork of the admin web UI for the [Garage](https://garagehq.deuxfleurs.fr/) S3 object store. The fork adds multi-user access control, Google sign-in, an audit log and bulk object management.

The chart deploys only the web UI. It connects to a Garage cluster that already runs, for example one installed with Garage's own Helm chart.

## Install

Create a Secret with the Garage admin token (`admin.admin_token` in `garage.toml`):

```sh
kubectl create secret generic garage-admin --from-literal=admin-token='YOUR_ADMIN_TOKEN'
```

Then install the chart. It points at the Garage Service:

```sh
helm install webui . \
  --set garage.adminApiUrl=http://garage.garage.svc:3903 \
  --set garage.s3EndpointUrl=http://garage.garage.svc:3900 \
  --set garage.existingSecret=garage-admin
```

Open the UI and create the owner account right away. On first launch the UI shows a one-time registration screen, and whoever reaches it first becomes the owner.

## Connecting to Garage

The web UI can learn how to reach Garage in two ways. You can combine them, and environment variables take precedence.

1. **Explicit values** (recommended): `garage.adminApiUrl`, `garage.s3EndpointUrl`, and the admin token through `garage.existingSecret` or `garage.adminToken`.
2. **A mounted `garage.toml`**: set `garageConfig.existingSecret` to a Secret that holds the file under `garageConfig.key`. The UI then derives the endpoints from `rpc_public_addr` and the bind ports, and reads the token from `[admin]`. The file contains `rpc_secret`, so the chart reads it from a Secret only. To rely on the file alone, set `garage.adminApiUrl` and `garage.s3EndpointUrl` to `""`.

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `genebit/garage-webui` | Image. Only `linux/amd64` is published. |
| `image.tag` | chart `appVersion` (`1.1.0`) | Image tag. |
| `garage.adminApiUrl` | `http://garage:3903` | Garage admin API (`API_BASE_URL`). |
| `garage.s3EndpointUrl` | `http://garage:3900` | Garage S3 API (`S3_ENDPOINT_URL`). |
| `garage.s3Region` | `""` | S3 region (`S3_REGION`). Empty means the value from `garage.toml`, or `garage`. |
| `garage.adminToken` | `""` | Admin token. The chart stores it in its own Secret. |
| `garage.existingSecret` / `existingSecretKey` | `""` / `admin-token` | Existing Secret holding the admin token. |
| `garageConfig.existingSecret` / `key` | `""` / `garage.toml` | Secret mounted at `/etc/garage.toml`. |
| `basePath` | `""` | URL prefix (`BASE_PATH`), such as `/webui`. Probes and `helm test` follow it. |
| `auth.legacyUserPass` | `""` | Legacy `username:bcrypt` login (`AUTH_USER_PASS`). It is honoured only while no user exists. |
| `auth.existingSecret` / `existingSecretKey` | `""` / `auth-user-pass` | Existing Secret holding that value. |
| `google.enabled` | `false` | Enables Google sign-in. |
| `google.clientId` / `clientSecret` | `""` | OAuth client credentials. |
| `google.existingSecret` | `""` | Secret with keys `client-id` and `client-secret` (renamable via `clientIdKey` and `clientSecretKey`). |
| `google.allowedDomains` | `""` | Hosted-domain allowlist (`GOOGLE_ALLOWED_DOMAINS`). Required when Google sign-in is enabled. |
| `persistence.enabled` | `true` | PVC for `/data`. When disabled, an `emptyDir` is used. |
| `persistence.existingClaim` | `""` | Reuse an existing PVC. |
| `persistence.size` / `storageClass` / `accessModes` | `1Gi` / `""` / `[ReadWriteOnce]` | PVC settings. |
| `service.type` / `service.port` | `ClusterIP` / `3909` | Service. |
| `ingress.*` | disabled | Standard `networking.k8s.io/v1` Ingress (`className`, `annotations`, `hosts`, `tls`). |
| `podSecurityContext` | non-root UID/GID/fsGroup 65532 | Pod security context. |
| `securityContext` | read-only rootfs, no capabilities | Container security context. |
| `nodeSelector` | `kubernetes.io/arch: amd64` | Keeps the pod on nodes that can run the image. |
| `extraEnv`, `extraVolumes`, `extraVolumeMounts` | `[]` | Escape hatches. |
| `resources`, `tolerations`, `affinity`, `podAnnotations`, `podLabels` | empty | Usual pod settings. |

## Behaviour and caveats

- **Single replica only.** The web UI keeps sessions in memory and stores accounts in a JSON file. The Deployment therefore has `replicas: 1` fixed and uses the `Recreate` strategy. Every pod restart signs all users out.
- **Persistent data.** `/data` holds `users.json`, the audit log (`logs/app.log`) and a temp directory. The PVC carries `helm.sh/resource-policy: keep`, so `helm uninstall` does not delete the accounts. Delete the PVC by hand to start over.
- **Uploads through an Ingress.** Uploads are streamed to Garage and can be many gigabytes. ingress-nginx limits and buffers request bodies by default. Set these annotations:

  ```yaml
  ingress:
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
  ```

- **Google sign-in.** Register `<origin><basePath>/api/v1/auth/google/callback` as a redirect URI in the Google console. Sign-in is deny-by-default: an admin must first create a user with the matching email address. The upstream default domain allowlist only admits `adnu.edu.ph` accounts, so the chart requires `google.allowedDomains` to be set explicitly.
- **Non-root.** The image is built `FROM scratch` without a `USER`. The chart runs it as UID 65532 and uses `fsGroup` to make `/data` writable.

## Development

```sh
make lint       # helm lint
make template   # render with default values
make package    # lint and package into a .tgz
```

See `CLAUDE.md` for the release process.
