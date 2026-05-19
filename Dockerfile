# syntax=docker/dockerfile:1.7

# ---- builder ----
# hugomods/hugo is the de-facto community Hugo image. Handles the
# glibc-vs-musl issue (hugo extended is glibc-linked) by shipping a
# correctly-built binary in an alpine base. Renovate tracks the tag.
# renovate: datasource=docker depName=hugomods/hugo
FROM hugomods/hugo:exts-0.140.0 AS builder

WORKDIR /src
COPY . .
RUN hugo --minify --gc

# ---- runtime ----
# nginx-unprivileged: listens on :8080 by default, non-root user 101.
# Matches the cluster Deployment's pod securityContext.
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY --from=builder /src/public /usr/share/nginx/html

EXPOSE 8080
