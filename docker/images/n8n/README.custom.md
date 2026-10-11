# Custom n8n image (`Dockerfile.custom`)

`Dockerfile.custom` builds the whole n8n image from a clean checkout with one `docker build`. It needs no Node, no pnpm and no prebuilt `compiled/` folder on the host. The upstream `Dockerfile` in this folder is not changed.

Full guide, options and checks: [`v2-docs/docker-and-coolify.md`](../../../v2-docs/docker-and-coolify.md).

## Use it in Coolify (the intended way)

1. New resource, then **Public/Private Repository** (or GitHub App). Pick this repository and branch `custom.v2`.
2. Build pack: **Dockerfile**.
3. Base directory: `/`. Dockerfile location: `/docker/images/n8n/Dockerfile.custom`.
4. Ports exposes: `5678`. Set your domain.
5. Storage: add a persistent volume with destination `/home/node/.n8n`.
6. Environment variables: add them as **runtime** variables only (see below). Turn off build-argument injection (Advanced).
7. Health check: keep the Coolify health check **off**. With it on, the proxy returned 502 even though n8n was healthy. Check by hand: `GET /healthz` on `5678`.
8. Deploy. On our PC a fresh build took about 8 minutes with warm caches and about 11 minutes with cold caches. A Coolify server can be slower. Plan for about 8 GB of free RAM (an estimate).

Coolify clones the repository on Linux, so line endings are correct and the build needs no special steps.

### Environment variables

Set them in Coolify. Never commit values. Names only:

| Name | Purpose |
|---|---|
| `N8N_ENCRYPTION_KEY` | One fixed key. Keep a copy. If it changes, saved credentials stop working. |
| `N8N_HOST`, `N8N_PROTOCOL`, `N8N_PORT` | Public host name, `https`, and `5678`. |
| `N8N_PROXY_HOPS` | `1` behind the Coolify proxy. |
| `N8N_WEBHOOK_URL` | Public base URL for webhooks. |
| `N8N_DIAGNOSTICS_ENABLED`, `N8N_VERSION_NOTIFICATIONS_ENABLED`, `N8N_PERSONALIZATION_ENABLED` | `false`. |
| `N8N_ENABLED_MODULES` and the feature flag names in `.env.local.example` | As on your PC. |

Do not copy `.env.local`. It has local paths. The full list of variables used on the first Coolify deploy is in `v2-docs/docker-and-coolify.md`, section "Deployed configuration".

Coolify can pass environment variables to the build as `ARG`s. A build argument stays in the image history. Turn that off: **Advanced, then disable the injection of build arguments**. Mark every variable as runtime only. The build does not need any variable.

## Build it on your own machine

The command is the same on every host. The repository root is the context:

```bash
docker build -f docker/images/n8n/Dockerfile.custom -t n8n-custom:local .
```

Only the checkout differs.

| Host | What to do |
|---|---|
| **Linux, CI, Coolify** | Nothing special. A normal `git clone` works. |
| **Windows (Docker Desktop)** | Do not build from your working tree. Git with `core.autocrlf=true` writes CRLF, and the container fails with `env: 'node\r': No such file or directory`. Clone again with LF endings, in a short path: `git clone -c core.autocrlf=false -c core.longpaths=true --branch custom.v2 <repo> C:\n8n-build`. A long path (for example inside `AppData`) silently loses files. |
| **WSL2** | Clone into the Linux home folder (`~/n8n-build`), not `/mnt/c`. Turn on Docker Desktop's WSL integration. Give WSL 8 GB or more in `%UserProfile%\.wslconfig`. |
| **macOS, Apple silicon** | The image is `linux/arm64`. For an x86-64 server add `--platform linux/amd64`. This runs under emulation and is slow. Build on the server or on an x86-64 host instead. |

The Dockerfile stops in seconds, with a message, if it sees CRLF or a missing source tree.

## What is in the image

Only the last stage ships: the n8n runtime base, the production-only closure from `pnpm deploy --prod`, and three native modules rebuilt for Alpine. It holds no source code, no dev dependencies, no tests, no compilers and no pnpm store. The compile stage and the native-build stage stay in the build cache.

The image is about 1.8 GB. About 1.3 GB is n8n's own production dependencies (about 1,700 packages, for example all the integration nodes). About 0.5 GB is the upstream runtime base (Node, fonts, GraphicsMagick, git, ssh). We tested for more waste and found none: first-party source maps are 0 MB, test files 0 MB, markdown files 1 MB, and no dev tool (vitest, eslint, vite, webpack, storybook, biome, turbo, prettier) is present. Making it smaller means removing features. See the guide, section 3.

## After every n8n update

The upstream stages are copied text. Diff them against `docker/images/n8n/Dockerfile`, copy the pins, and re-run the checks. The list is in the guide, section 8.
