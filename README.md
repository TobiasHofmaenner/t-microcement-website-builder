# t-microcement-website-builder

Build pipeline + theme for [www.t-microcement.com](https://www.t-microcement.com/).
The **operator** owns this repo. The customer's editable content lives
in a sibling repo:
[`t-microcement-content`](https://github.com/TobiasHofmaenner/t-microcement-content).

## Architecture

```
              ┌─────────────────────────┐
              │ t-microcement-content   │   (customer-facing,
              │   content/*.md          │    public, edit freely)
              │   static/*.{jpg,svg}    │
              │   assets/css/main.css   │
              └────────────┬────────────┘
                           │ checked out at build time
                           ▼
              ┌─────────────────────────┐
              │ t-microcement-website-  │   (this repo, operator-owned,
              │ -builder                │    controls what code runs)
              │   Dockerfile            │
              │   layouts/              │
              │   hugo.toml             │
              │   .github/workflows/    │
              └────────────┬────────────┘
                           │ docker build + push
                           ▼
                ghcr.io/.../...-builder:main-<ts>-<sha>
                           │ Flux image-automation picks up
                           ▼
                     cluster pulls + serves
```

## Why two repos

- **Trust boundary** — customer can edit content / static / CSS freely
  without touching what code runs in the cluster. The Dockerfile, GH
  Actions workflow, and Hugo layouts stay locked to operator review.
  The boundary is intentionally drawn at "things that build an image"
  vs "things the image renders" — note that this *does not* sandbox the
  content repo from injecting HTML/JS into the served site (Hugo's
  goldmark `unsafe = true` is on, so raw HTML in markdown renders).
  That's the explicit trade-off — we don't try to prevent the customer
  from injecting client-side script, only from running server-side code
  in the cluster.
- **Hand-off** — when the customer takes over content editing, you
  transfer ownership of the content repo only. The builder stays yours.
- **Cleanliness** — content is the thing that changes weekly; the
  builder is the thing that changes yearly. Separate lifecycles.

## Coupling notes (don't break these)

- `layouts/_default/baseof.html` references `assets/css/main.css` via
  Hugo Pipes. If the content repo renames or removes that file, the
  build fails. Keep the filename stable.
- `hugo.toml` is operator-owned. If the customer wants new front-matter
  fields or site params surfaced, that's a builder-side change.

## Build triggers

The workflow runs on:
- **push to main** here (Dockerfile / layouts / hugo.toml changes)
- **schedule** every hour at :17 (picks up content repo changes)
- **workflow_dispatch** (manual "Run workflow" — for immediate rebuild
  after a content commit)

Hourly cadence avoids the cross-repo PAT/App setup needed for instant
content-push → rebuild. Upgrade path: add a fine-grained PAT in the
content repo and a `repository_dispatch` step here. Not done in v1 —
manual dispatch covers it.

## Local development

```bash
# Pull the content repo as a sibling, symlink it in
git clone https://github.com/TobiasHofmaenner/t-microcement-content.git ../t-microcement-content
ln -sf ../t-microcement-content/content ./content
ln -sf ../t-microcement-content/static  ./static
ln -sf ../t-microcement-content/assets  ./assets

hugo server -D    # http://localhost:1313
```

The symlinks are in `.gitignore` — never committed.

## How a push deploys

1. CI builds `ghcr.io/tobiashofmaenner/t-microcement-website-builder:main-<unix-ts>-<sha>`
2. Flux image-reflector-controller polls GHCR within 1 min
3. image-automation-controller rewrites the image tag in
   [thf-infra](https://github.com/TobiasHofmaenner/thf-infra)'s
   `apps/customers/t-microcement/website/app/deployment.yaml`
4. Flux applies the new tag, pods roll, site is live

End-to-end: ~3–5 minutes from `git push` to live.
