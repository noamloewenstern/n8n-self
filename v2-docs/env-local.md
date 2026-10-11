# `.env.local` and `.env.secrets.local`

## Files

| File | Committed | Content |
|---|---|---|
| `.env.local` | Yes (force-added, because `.gitignore` lists it) | All non-secret dev settings: ports, telemetry off, module list, feature flags, v2 flags. |
| `.env.secrets.local` | No (gitignored) | `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and any future token or key. |
| `.env.local.example` | Yes | Older template. It also lists license and AI key names. Keep it for those names. |

The repository is public. Never put a secret in `.env.local`.

## Use

1. Clone the repository. `.env.local` is already there.
2. Create `.env.secrets.local` by hand. Add `ADMIN_EMAIL` and `ADMIN_PASSWORD`. n8n does not read them. Use them for browser login checks.
3. Run every dev command with dotenvx: `pnpm exec dotenvx run -f .env.local -- <cmd>`.
4. To load a secret into n8n, add the file: `-f .env.local -f .env.secrets.local`.
5. Put a new secret key in `.env.secrets.local`. For example, `N8N_INSTANCE_REPORTING_AUTH_TOKEN` (empty in `.env.local`).

## Rules

- Do not run `git add -A` for secrets. `.env.local` is tracked, so edits to it show in `git status`. Read the diff before you commit.
- Docker: `**/.env*` stays in both dockerignore files. The image never holds these files. On the server, set variables in Coolify. See `docker-and-coolify.md`.
- Do not copy `.env.local` as a whole to the server. Copy only the names you need. `DEPLOY-PROMPT.md` lists them.
- Decision record: `decisions.md`, row dated 2026-10-11.
