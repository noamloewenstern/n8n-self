# n8n - Custom Image

Builds a Docker image from the local n8n source tree, with the `custom` branch patches applied. For local/personal use only. Licensing enforcement is disabled.

Full patch reference: [`custom.md`](../../../custom.md) (repo root). Full diff: `custom-full.diff` (repo root, if present).

## What this image changes

- License checks bypassed: `isLicensed()` returns `true`, quotas hardcoded.
- Enterprise and feature flags forced on in the settings served to the editor.
- Telemetry disabled (frontend and store).
- RBAC and enterprise-feature checks always pass.
- Some router guards removed (usage page, SAML onboarding).
- AI assistant base URL defaults to `https://ai-assistant.n8n.io`.
- GitHub Actions disabled in the repo (`.github/` renamed to `.bak_github/`).

Every patch is marked `// CUSTOM PATCH` in source. Find them with:

```bash
git grep -n "CUSTOM PATCH"
```

## Files

- `Dockerfile`: two-stage build. Stage 1 installs, builds, and deploys `n8n` to `/compiled`. Stage 2 copies it into `n8nio/base`, installs the task-runner launcher (sha256 checked), rebuilds `sqlite3`, and pins `npm@11.4.1`.
- `Dockerfile.ghcr.custom`: `FROM ghcr.io/noamloewenstern/n8n:custom2`, for pulling a prebuilt image.
- `build-x86.sh` / `build-mac.sh`: `docker buildx build` wrappers for `linux/x86_64` and `linux/arm64`.

## Usage

Run from the n8n repo root.

Build for the current host:

```bash
docker build -t n8n-custom -f docker/images/n8n-custom/Dockerfile .
```

Build for a specific platform:

```bash
bash docker/images/n8n-custom/build-x86.sh   # linux/x86_64
bash docker/images/n8n-custom/build-mac.sh   # linux/arm64
```

Run:

```bash
docker run -it --rm -p 5678:5678 -v n8n_data:/home/node/.n8n n8n-custom
```

## Requirements

- Docker with buildx.
- Node 22 base image (`NODE_VERSION=22`) for this branch. Repo is v1 (`1.113.0`).
- `pnpm` 10.16.0 (set by repo `packageManager`).

## Caveats

- This branch is v1. The v2 master needs a separate port; the Dockerfile here does not map onto the v2 multi-stage layout. See `custom.md`, section "Porting to v2".
- `hasRole`, `hasScope`, and `isEnterpriseFeatureEnabled` return `true` for every user. Do not expose a shared deployment.
- Patches are hardcoded against v1 values. Re-verify each one after any upstream change.
