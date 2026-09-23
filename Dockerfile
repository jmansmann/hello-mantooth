# syntax=docker/dockerfile:1

# Build stage runs on the host architecture; Go cross-compiles to the target,
# so the same Dockerfile produces both linux/amd64 and linux/arm64 (ADR-004).
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build

ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev

WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" \
    -o /out/server ./src

# Minimal, non-root runtime image.
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/server /server

USER 65532:65532
EXPOSE 8080

ENTRYPOINT ["/server"]
