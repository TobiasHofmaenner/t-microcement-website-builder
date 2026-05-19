# t-microcement-website-builder

Build pipeline for [www.t-microcement.com](https://www.t-microcement.com/).
The **operator** owns this repo. Everything Hugo renders — content,
layouts, CSS, site config — lives in the sibling repo
[`t-microcement-content`](https://github.com/TobiasHofmaenner/t-microcement-content)
which the customer co-owns.

## Architecture

```
              ┌─────────────────────────┐
              │ t-microcement-content   │   (customer-facing, public,
              │   hugo.toml             │    edit freely — this is a
              │   layouts/              │    self-contained Hugo site;
              │   content/*.md          │    `hugo server` just works)
              │   assets/css/main.css   │
              │   static/*.{jpg,svg}    │
              └────────────┬────────────┘
                           │ checked out at build time
                           ▼
              ┌─────────────────────────┐
              │ t-microcement-website-  │   (this repo, operator-owned,
              │ -builder                │    controls what code runs)
              │   Dockerfile            │
              │   .github/workflows/    │
              └────────────┬────────────┘
                           │ docker build + push
                           ▼
                ghcr.io/.../...-builder:main-<ts>-<sha>
                           │ Flux image-automation picks up
                           ▼
                     cluster pulls + serves
```

## Why the split

- **Operator control surface = container only.** Dockerfile pins the
  Hugo version and the runtime base image. GH Actions workflow controls
  what gets pushed to GHCR and when. Everything else — site behaviour,
  HTML output, configuration — is in the content repo where the
  customer can iterate.
- **Trust boundary**, explicitly: the customer can write arbitrary HTML
  via markdown (Hugo's `goldmark unsafe = true` is on) and arbitrary
  Hugo template logic in `layouts/`. They cannot change what runs in
  the cluster, what container is published, or how it's deployed. The
  boundary is "code that runs in the cluster" vs "everything else."
- **Hand-off**: transfer ownership of the content repo to take the
  customer fully self-serve. The builder stays yours.
- **Lifecycles**: content changes weekly. Builder changes yearly when
  Hugo or the base image gets bumped.

## Build triggers

The workflow runs on:
- **push to main** here (Dockerfile or CI changes)
- **schedule** every hour at :17 (picks up content repo changes)
- **workflow_dispatch** (manual "Run workflow" — immediate rebuild
  after a content commit)

Hourly cadence avoids the cross-repo PAT/App setup needed for instant
content-push → rebuild. Upgrade path: add a fine-grained PAT in the
content repo and a `repository_dispatch` step here. Not done in v1 —
manual dispatch covers it.

## How a push deploys

1. CI builds `ghcr.io/tobiashofmaenner/t-microcement-website-builder:main-<unix-ts>-<sha>`
2. Flux image-reflector-controller polls GHCR within 1 min
3. image-automation-controller rewrites the image tag in
   [thf-infra](https://github.com/TobiasHofmaenner/thf-infra)'s
   `apps/customers/t-microcement/website/app/deployment.yaml` and
   pushes a `chore(images)` commit as fluxcdbot
4. Flux applies the new tag, pods roll, site is live

End-to-end: ~3–5 minutes from `git push` to live.

## Local testing of the build

You usually don't need to. The Dockerfile is the source of truth and
CI proves it green. If you do want to test container behaviour locally:

```bash
git clone https://github.com/TobiasHofmaenner/t-microcement-content.git ../t-microcement-content
cp -r ../t-microcement-content/{content,static,assets,layouts} ./
cp    ../t-microcement-content/hugo.toml ./
docker build -t t-microcement-website:local .
docker run --rm -p 8080:8080 t-microcement-website:local   # http://localhost:8080
```

For previewing Hugo changes without Docker, use `hugo server -D`
directly from the **content** repo — it's self-contained.
