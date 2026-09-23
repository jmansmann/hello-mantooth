# hello-mantooth — developer entry points.
# Thin wrappers only; CI runs the same `make verify` (ADR-012).

IMAGE ?= ghcr.io/jmansmann/hello-mantooth
TAG   ?= dev
ENV   ?= k3d
APP   ?= hello-mantooth
GO    ?= go

.DEFAULT_GOAL := help

.PHONY: help fmt fmt-check vet test verify build image manifests deploy port-forward clean

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

image: ## Build a local single-arch dev image
	docker build --build-arg VERSION=$$(git rev-parse --short HEAD 2>/dev/null || echo dev) -t $(IMAGE):$(TAG) .

manifests: ## Render manifests for ENV (k3d|homelab)
	kustomize build deploy/overlays/$(ENV)

deploy: ## Sync the app through Argo CD (GitOps)
	argocd app sync $(APP)

port-forward: ## Forward the service to http://localhost:8090
	kubectl -n $(APP) port-forward svc/$(APP) 8090:80

clean: ## Remove build output
	rm -rf bin
