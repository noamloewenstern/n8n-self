@AGENTS.md

# Local dev setup (this machine, n8n v2, branch `custom.v2`)

## Env vars

- Source: `.env.local` at repo root (gitignored). Template: `.env.local.example`.
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
- Docker image: `pnpm build:docker` → `n8nio/n8n:local`. Run with a separate container env file, not `.env.local`.

## Sources

- `CONTRIBUTING.md` → "Environment variables", "Development cycle".
- Config classes: `packages/@n8n/config/src/configs/*.ts`.
- Removed/renamed vars: `packages/cli/src/deprecation/deprecation.service.ts`, `packages/cli/BREAKING-CHANGES.md`.
- Port of v1 `custom` patches: not done. See `custom.md` (v1 notes) before porting.
