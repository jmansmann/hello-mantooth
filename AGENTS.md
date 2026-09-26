# AGENTS.md — hello-mantooth

First application repo for the homelab. Source **and** deployment manifests both live here (ADR-002); Argo CD (driven by the `apps` ApplicationSet in `mantooth-homelab`) deploys `deploy/overlays/k3d` and `deploy/overlays/homelab`.

## Commands

`make help` lists every target. The standard repo interface (ADR-012):

| Target | Purpose |
|---|---|
| `make verify` | format check + vet + test — **the same gate CI runs** |
| `make build` | compile the server binary into `bin/` |
| `make image` | local single-arch dev image |
| `make dev` | build → load into k3d → apply to isolated `hello-mantooth-dev` namespace → wait |
| `make undeploy` | delete the local dev namespace, not the Argo-managed namespace |
| `make manifests ENV=k3d` | render manifests for an environment |
| `make deploy` | sync through Argo CD (GitOps) |
| `make port-forward` | forward the local dev Service to `localhost:8090` |
| `make argocd-port-forward` | forward the Argo-managed Service to `localhost:8090` |

Keep targets thin wrappers — never a second source of truth next to CI.

## Conventions

- **Multi-arch images only** (`linux/amd64`, `linux/arm64`) — ADR-004. CI builds both; don't push single-arch from the Mac.
- Image tags are pinned to the git SHA by CI (`kustomize edit set image`); `latest` in the base is only a placeholder.
- Never stage, commit, or push — leave changes unstaged for review.
