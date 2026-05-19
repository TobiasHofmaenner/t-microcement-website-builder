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
              └────────────┬────────────┘
                           │ checked out at build time
                           ▼
              ┌─────────────────────────┐
              │ t-microcement-website-  │   (this repo, operator-owned,
              │ -builder                │    controls what code runs)
              │   Dockerfile            │
              │   layouts/, assets/     │
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

- **Trust boundary** — customer can edit content freely without touching
  what code runs in the cluster. The Dockerfile, GH Actions workflow,
  and layouts stay locked to operator review.
- **Hand-off** — when the customer takes over content editing, you
  transfer ownership of the content repo only. The builder stays yours.
- **Cleanliness** — content is the thing that changes weekly; the
  builder is the thing that changes yearly. Separate lifecycles.

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
