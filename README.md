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

## Fast local loop in k3d

One-shot local loop — builds the image from the working tree, imports it into
k3d, applies the Kustomize overlay, and waits for rollout. No registry or CI
needed. It deploys into an isolated `hello-mantooth-dev` namespace, so Argo CD
can keep managing the remote-Git version in the `hello-mantooth` namespace
without fighting local changes:

```bash
make dev          # build → k3d image import → kubectl apply → rollout
make port-forward # local dev copy at http://localhost:8090
make undeploy     # delete only hello-mantooth-dev
```

`make deploy` syncs the Argo-managed copy from remote Git. To access that copy,
run `make argocd-port-forward`. Argo cannot see uncommitted local files; changes
to the GitOps version must be pushed and merged to `main`.

### Observe Service DNS and EndpointSlices

`make dev` uses the `hello-mantooth-dev` namespace. The short Service DNS name
inside that namespace is `hello-mantooth`; its full name is
`hello-mantooth.hello-mantooth-dev.svc.cluster.local`.

In one terminal, watch the ready backend endpoints:

```bash
kubectl -n hello-mantooth-dev get endpointslices \
  -l kubernetes.io/service-name=hello-mantooth -o wide -w
```

From another terminal, resolve and call the Service from inside the cluster:

```bash
kubectl run dns-check -n hello-mantooth-dev --rm -it --restart=Never \
  --image=busybox:1.36.1 -- sh -c \
  'nslookup hello-mantooth.hello-mantooth-dev.svc.cluster.local; for i in 1 2 3 4 5 6; do wget -qO- http://hello-mantooth.hello-mantooth-dev.svc.cluster.local/; done'
```

The JSON response includes the pod hostname, so repeated connections can show
which replica served each request. A small sample may not hit every replica.

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

### GHCR visibility

The GHCR package is public (verified with an anonymous pull), so the Deployment
does not need an image-pull secret. Both Git repositories are currently public
as well, so Argo CD can fetch their sources without credentials.

## Verify

```bash
kubectl -n hello-mantooth port-forward svc/hello-mantooth 8090:80
open http://localhost:8090
```
