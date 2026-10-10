# v2 backlog

Deferred work. Mark items "re-check on bump" when a new n8n version can change them.

## B1. engine-v2 (re-check on bump)

State at n8n 2.43.0 (checked 2026-10-11):
- Module `engine-v2`, not a default module. Load it with `N8N_ENABLED_MODULES=engine-v2`.
- Execution mode `N8N_ENGINE_MODE` defaults to `in-process`. A `remote` mode runs a separate `n8n engine` process.
- It is a new execution engine, separate from the current one. It changes how every workflow runs.
- Scaffold added 2026-08-20 (#36480). Recent commits 2026-09-30 to 2026-10-02 are `(no-changelog)`.
- `packages/@n8n/engine/README.md` says the package is "currently a scaffold ... not yet wired into n8n". The text may be stale. Treat the engine as in development.
- Limits: main instance only. No queue mode (the module throws). In-process work is lost on restart.
- Docs: no public docs. ADRs in `packages/@n8n/engine/docs/adr/`.
- Source: `packages/cli/src/modules/engine-v2/engine-v2.module.ts:10-33`, `packages/@n8n/engine/README.md`.

Action when n8n marks it production-ready (public docs or changelog entry, or it becomes a default module): re-read the module, test with a copy of real workflows, then decide.

## B2. instance-reporting (enable when a receiver exists)

- Module `instance-reporting`, opt-in. Sends a daily report to a receiver.
- Env: `N8N_INSTANCE_REPORTING_BASE_URL`, `N8N_INSTANCE_REPORTING_AUTH_TOKEN`, `N8N_INSTANCE_REPORTING_LABEL`. The first two are in `.env.local` and `.env.local.example`, empty.
- Owner wants it later.
- To enable: set the URL and token (token only in `.env.local`), add `instance-reporting` to `N8N_ENABLED_MODULES`, test.
- Unknown: how the module behaves with an empty URL, so it stays off until configured.

## B3. Security audit version check (local solution)

- Phase I patches `getOutdatedState()` in `packages/cli/src/security-audit/risk-reporters/instance-risk-reporter.ts` to skip the network call (no `api.n8n.io`, no instance ID).
- Result: the audit reports no "outdated instance" risk.
- Later, if wanted: compare against a local release note, or a manual version check the owner runs.

## B4. Runtime egress audit (light, deferred)

- Run a portable logging proxy (CONNECT host and port only). Idle 5 minutes, log in, open main pages, run a workflow, open templates, assistant, MCP settings.
- Goal: find telemetry or analytics calls that slipped through. Not a blocker.
- Unverified until run: license SDK sends nothing at startup, FE handling of `-1` quotas, hard load of `/saml/onboarding`, OpenRouter `url: ''` fallback.

## B5. Docker phase

- `DOCKER_PLATFORM=linux/amd64 pnpm build:docker`, from a clean shell, not under dotenvx.
- Add to `.dockerignore`: `**/*.local`, `**/.vscode`, `**/.idea`, `**/.remember`.
- Build with a fresh `compiled/` so license patches ship.
- Container env file separate from `.env.local`. Grep the image for `.env` files.
- Source: `research/r8-docker.md`.

## B6. Audit logs (verify after Phase I)

- `enterprise.auditLogs` is forced true. No audit-log page was found in v2 source. After the patch, check the UI. If nothing appears, it is a vestigial flag.
- Related working features: log streaming (license gated, opens with the license patch), activity log (needs flag `114_instance_activity_context`, set).

## B7. Other

- Provisioning (SCIM role mapping): FE forces false. Upstream says not ready. Skipped.
- `promotions` needs the owner's git remote. Owner will connect it.
- Add an OpenRouter key in the admin UI. Start SearXNG at `http://localhost:8888` (needs `format=json`).
- Optional hardening from r4/r5 not yet decided: none open.
