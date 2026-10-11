@AGENTS.md

# Local dev setup (this machine, n8n v2, branch `custom.v2`)

## Env vars

- Source: `.env.local` at repo root (committed, no secrets). Secrets: `.env.secrets.local` (gitignored, create by hand). Details: `v2-docs/env-local.md`. Older template: `.env.local.example`.
- Load with dotenvx. Prefix every dev command: `pnpm exec dotenvx run -f .env.local -- <cmd>`.
- dotenvx expands `$HOME`, not `~`.
- Telemetry, diagnostics, metrics, version notifications, hiring banner: all `false`.
- Dropped v1 vars (removed in v2): `N8N_RUNNERS_ENABLED`, `NODE_FUNCTION_ALLOW_*`, `N8N_EDITOR_BASE_URL`, `WEBHOOK_URL` (now `N8N_WEBHOOK_URL`), `NODE_ENV`.
- Local data: `N8N_USER_FOLDER=$HOME/.n8n-dev`. Encryption key auto-generates there.

## Commands

- Install: `pnpm install` (pnpm `12.4.2` pinned in `package.json`; Node `>=24`).
- Build: `pnpm build`.
- Backend dev (port 5678): `pnpm exec dotenvx run -f .env.local -- pnpm dev:be`.
- Editor dev (port 8080): `pnpm exec dotenvx run -f .env.local -- pnpm dev:fe:editor`.
- Docker image: `pnpm build:docker` → `n8nio/n8n:local` (fails on native Windows). Single-file alternative that works everywhere: `docker build -f docker/images/n8n/Dockerfile.custom -t n8n-custom:local .` from an LF clone (`core.autocrlf=false`, short path). Guide and bump checklist: `v2-docs/docker-and-coolify.md`. Run images with a separate container env file, not `.env.local`.

## Sources

- `CONTRIBUTING.md` → "Environment variables", "Development cycle".
- Config classes: `packages/@n8n/config/src/configs/*.ts`.
- Removed/renamed vars: `packages/cli/src/deprecation/deprecation.service.ts`, `packages/cli/BREAKING-CHANGES.md`.
- Port of v1 `custom` patches: not done. See `custom.md` (v1 notes) before porting.

# v2 custom work (read before changing anything under `custom.v2`)

- `v2-docs/decisions.md`: owner decisions and why. Follow them. Do not re-ask.
- `v2-docs/env-local.md`: `.env.local` (committed) vs `.env.secrets.local` (not committed).
- `v2-docs/patch-inventory.md`: every custom patch, status, and v1 mapping.
- `v2-docs/backlog.md`: deferred work and re-check items (engine-v2, instance-reporting, runtime egress audit, Docker phase).
- `v2-docs/research/`: R1 to R11 evidence (commit `55b3f5ac9e`).
- **Unit tests: ignore them** (owner decision 2026-10-11). Do not run, fix, or write unit tests on `custom.v2`. A failing test caused by a custom patch is expected. Check features by reading the diff and by hand. See `v2-docs/decisions.md` "Tests".
- Mark each custom code change `// CUSTOM PATCH` and keep the original line commented above it. Find them with `git grep -n "CUSTOM PATCH"`.
- On every n8n version bump, re-check the backlog items marked "re-check on bump".
