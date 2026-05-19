# syntax=docker/dockerfile:1.7

# ---- builder ----
# Downloads pinned Hugo extended, runs the build, outputs /public.
# Renovate keeps HUGO_VERSION current via the comment marker below.
FROM alpine:3.20 AS builder

# renovate: datasource=github-releases depName=gohugoio/hugo
ARG HUGO_VERSION=0.140.0

RUN apk add --no-cache curl tar libstdc++ \
 && curl -fsSL -o /tmp/hugo.tar.gz \
      https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz \
 && tar -xzf /tmp/hugo.tar.gz -C /usr/local/bin hugo \
 && rm /tmp/hugo.tar.gz

WORKDIR /src
COPY . .
RUN hugo --minify --gc

# ---- runtime ----
# nginx-unprivileged: listens on :8080 by default, non-root user 101.
# matches the cluster Deployment's pod securityContext.
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY --from=builder /src/public /usr/share/nginx/html

# Default config serves /usr/share/nginx/html on :8080 fine for our case.
# (No SPA fallback needed — Hugo generates real .html files per route.)
EXPOSE 8080
