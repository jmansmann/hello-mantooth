# hello-mantooth

A tiny "hello world" web service used to exercise the homelab delivery pipeline
end to end: **GitHub Actions → GHCR → Argo CD (pull-based GitOps)**.

It is the first application onboarded to `mantooth-homelab` and is intentionally
minimal — a Go backend only, no frontend yet.

## Endpoints

| Path | Purpose |
|---|---|
| `/` | JSON greeting with version, hostname, Go version, uptime |
| `/healthz` | Liveness probe — `200 ok` |
| `/readyz` | Readiness probe — `200 ok` |

## Run locally

```bash
go run ./src
curl localhost:8080
```

`PORT` overrides the listen port (default `8080`).

## Test

```bash
go vet ./...
go test ./...
```

## Build the image

The image is **multi-arch** (`linux/amd64`, `linux/arm64`) — see ADR-004.

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t hello-mantooth .
```

## Deployment

Deployment manifests live in this repo (ADR-002) and are consumed by the
`apps` ApplicationSet in `mantooth-homelab`:

```
deploy/
├── base/                 # Deployment + Service, pinned image
└── overlays/
    ├── k3d/              # local dev cluster
    └── homelab/          # bare-metal cluster (2 replicas)
```

Argo CD syncs `deploy/overlays/k3d` into the `hello-mantooth` namespace. CI
builds on every push to `main`, pushes to GHCR, and bumps the image tag in
`deploy/overlays/{k3d,homelab}`.

### Image pull secret (private GHCR package)

The package is private by default, so the Deployment references a `ghcr-pull`
secret. Create it once per namespace (never commit it):

```bash
kubectl -n hello-mantooth create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=jmansmann \
  --docker-password=<PAT with read:packages>
```

Alternatively, make the GHCR package public and remove the `imagePullSecrets`
entry from `deploy/base/deployment.yaml`.

## Verify

```bash
kubectl -n hello-mantooth port-forward svc/hello-mantooth 8090:80
open http://localhost:8090
```
