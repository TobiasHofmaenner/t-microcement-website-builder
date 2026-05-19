# t-microcement-website

Source for [www.t-microcement.com](https://www.t-microcement.com/).

Static site built with [Hugo](https://gohugo.io/), packaged as an
nginx-unprivileged image, deployed on the operator's k8s cluster via
Flux. Auto-deployed on push to `main`.

## Layout

```
content/                # Markdown source per page
layouts/                # Custom theme (no /themes/ subdir — keep it lean)
assets/css/main.css     # Inline-fingerprinted stylesheet
static/                 # Raw assets (favicon, raw images)
hugo.toml               # Hugo config
Dockerfile              # Multi-stage: hugo build → nginx-unprivileged
.github/workflows/      # CI: build + push to GHCR on every main commit
```

## Local development

```bash
hugo server -D            # http://localhost:1313
```

## How a push deploys

1. Push to `main` → GitHub Actions builds the image
2. CI pushes `ghcr.io/tobiashofmaenner/t-microcement-website:main-<unix-ts>-<sha>`
3. Flux's image-reflector-controller polls GHCR within 1 min
4. image-automation-controller rewrites the image tag in
   [thf-infra](https://github.com/TobiasHofmaenner/thf-infra)'s
   `apps/customers/t-microcement/website/app/deployment.yaml`
5. Flux applies the new tag, pods roll, site is live

End-to-end: ~3–5 minutes from `git push` to live.

## Editing content

Most updates only touch `content/*.md`. Push to main → it's live.
For layout changes, edit `layouts/` or `assets/css/main.css`.

## Adding pages

Drop a `content/<name>.md` with a `title:` front-matter. Add to
`layouts/partials/header.html` nav if you want it linked.
