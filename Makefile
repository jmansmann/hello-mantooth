# hello-mantooth — developer entry points.
# Thin wrappers only; CI runs the same `make verify` (ADR-012).

IMAGE   ?= ghcr.io/jmansmann/hello-mantooth
TAG     ?= dev
ENV     ?= k3d
CLUSTER ?= dev
APP     ?= hello-mantooth
NAMESPACE ?= $(APP)-dev
GO      ?= go
DOCKER  ?= docker
K3D     ?= k3d
KUBECTL ?= kubectl
KUSTOMIZE ?= kustomize

.DEFAULT_GOAL := help

.PHONY: help fmt fmt-check vet test verify build image load namespace apply rollout dev undeploy manifests deploy port-forward argocd-port-forward clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

fmt: ## Format Go code
	$(GO) fmt ./...

fmt-check: ## Fail if Go code is not formatted
	@test -z "$$(gofmt -l .)" || { echo "unformatted files:"; gofmt -l .; exit 1; }

vet: ## Run go vet
	$(GO) vet ./...

test: ## Run tests
	$(GO) test ./...

verify: fmt-check vet test ## Quality gate (format, vet, test) — what CI runs

build: ## Compile the server binary into bin/
	$(GO) build -trimpath -o bin/server ./src

# --- Local dev loop (build → load into k3d → apply → wait) ------------------
# This is a local escape hatch, not the GitOps path. `make deploy` is GitOps.

image: ## Build a local single-arch dev image
	$(DOCKER) build --build-arg VERSION=$(TAG) -t $(IMAGE):$(TAG) .

load: image ## Import the local image into the k3d cluster
	$(K3D) image import $(IMAGE):$(TAG) -c $(CLUSTER)

namespace: ## Ensure local dev namespace NAMESPACE exists
	@$(KUBECTL) get namespace $(NAMESPACE) >/dev/null 2>&1 || $(KUBECTL) create namespace $(NAMESPACE)

apply: namespace ## Apply rendered manifests and pin the local image tag
	$(KUSTOMIZE) build deploy/overlays/$(ENV) | $(KUBECTL) -n $(NAMESPACE) apply -f -
	$(KUBECTL) -n $(NAMESPACE) set image deployment/$(APP) app=$(IMAGE):$(TAG)
	$(KUBECTL) -n $(NAMESPACE) rollout restart deployment/$(APP)

rollout: ## Wait for the Deployment to finish rolling out
	$(KUBECTL) -n $(NAMESPACE) rollout status deployment/$(APP) --timeout=120s

dev: load apply rollout ## One-shot local loop: build, load into k3d, apply, wait

undeploy: ## Delete local dev namespace NAMESPACE (defaults to hello-mantooth-dev)
	$(KUBECTL) delete namespace $(NAMESPACE) --ignore-not-found

# --- GitOps -----------------------------------------------------------------

manifests: ## Render manifests for ENV (k3d|homelab)
	$(KUSTOMIZE) build deploy/overlays/$(ENV)

deploy: ## Sync the app through Argo CD (GitOps)
	argocd app sync $(APP)

port-forward: ## Forward the service to http://localhost:8090
	$(KUBECTL) -n $(NAMESPACE) port-forward svc/$(APP) 8090:80

argocd-port-forward: ## Forward the Argo-managed service to http://localhost:8090
	$(KUBECTL) -n $(APP) port-forward svc/$(APP) 8090:80

clean: ## Remove build output
	rm -rf bin
