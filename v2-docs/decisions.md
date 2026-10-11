# Owner decisions (custom.v2)

Owner: Noam. Instance: personal, single user, local first. Base n8n 2.43.0, HEAD at research `55b3f5ac9e`.
Log of what we decided and why. Add new rows at the bottom. Do not re-ask closed items.

## Policy

| Date | Decision | Why |
|---|---|---|
| 2026-10-10 | Block only telemetry and analytics egress (PostHog, RudderStack, Sentry, license server, version/instance-ID reporting). Useful in-app hosts are allowed. The old "localhost only" rule is dropped. | Owner wants in-app features that need a host. Wants no data sent to n8n analytics. |
| 2026-10-10 | `N8N_DIAGNOSTICS_ENABLED=false`. Also patch the code default to `false`. | Stops outbound telemetry. Protects the Docker phase from one missing env var. |
| 2026-10-10 | Never print or commit `.env.local` values. `.env.local` is gitignored. Non-secret mirror lives in `.env.local.example`. | Global no-secrets rule. |
| 2026-10-11 | Owner allows editing `.env.local` (not committing). | Owner instruction. |

## Tests

| Date | Decision | Why |
|---|---|---|
| 2026-10-11 | Ignore unit tests on `custom.v2`. Do not run them, fix them, or write them. If a custom patch changes logic as the spec says, a failing or stale test is fine. Do not edit tests to match. Only the features working as specified matters. | Owner instruction. Personal build. Tests that assert upstream behavior only cost time. |

## Licensing

| Date | Decision | Why |
|---|---|---|
| 2026-10-10 | Patch in the `License` class: `isLicensed()` true, plan `Enterprise`, quotas `-1`. Keep `API_DISABLED` and `SHOW_NON_PROD_BANNER` false. | r1, r2, r3. One seam covers `LicenseState` and `@Licensed` routes. |
| 2026-10-10 | Option B for the license server: skip `LicenseManager` creation, no-op `activate`/`renew`, plus env `N8N_LICENSE_AUTO_RENEW_ENABLED=false`. | The SDK is minified and unverified at runtime. Make silence certain. |
| 2026-10-10 | Hide or disable the Activate, Renew, and "request trial/enterprise key" buttons. The two `enterprise.n8n.io` routes return an error instead of calling out. | The user never needs a real license. |
| 2026-10-11 | Force `enterprise.auditLogs` true in the settings refresh. | Owner wants it. In v2 it is a vestigial flag (no audit-log page found). Harmless. |

## Features

| Date | Decision | Why |
|---|---|---|
| 2026-10-10 | Enable: community nodes catalog, MCP registry, agent evals, computer use, templates, MCP apps, MCP server. | Owner wants all new v2 features. |
| 2026-10-11 | `N8N_ENABLED_MODULES=agent-evals,promotions`. | Owner uses promotions with their own git remote. |
| 2026-10-11 | Enable all PostHog-gated features through dedicated env vars and `N8N_FEATURE_FLAG_OVERRIDES`. | PostHog is off, so flags default off. Env forces them on. |
| 2026-10-11 | Do NOT enable `engine-v2`. Findings in `backlog.md`. | Unreleased scaffold. Changes how workflows run. |
| 2026-10-11 | Do NOT enable `type-availability-policies`. | Built for multi-user credential/node restrictions. Owner is single user. |
| 2026-10-11 | `instance-reporting`: module off for now. `N8N_INSTANCE_REPORTING_BASE_URL` and `_AUTH_TOKEN` stay in env, empty. Enable later. | No receiver yet. See `backlog.md`. |
| 2026-10-11 | Env vars that were "dropped" are set to their explicit default values (`N8N_DISABLED_MODULES` empty, `N8N_VERIFIED_PACKAGES_ENABLED=true`, `N8N_INSTANCE_AI_TEMPLATES_DISABLED=false`). | So no variable is missing from the env file. |
| 2026-10-10 | Do not use v1 item 6 (hosted AI assistant URL). `N8N_AI_ASSISTANT_BASE_URL` stays empty. Add an OpenRouter key in the UI. | Owner choice. |
| 2026-10-10 | Do not set `N8N_INSTANCE_AI_MODEL`, provider API keys, or `N8N_AI_ANTHROPIC_KEY`. | They block UI model connection, or enable a dead classic assistant (r7). |

## Security audit

| Date | Decision | Why |
|---|---|---|
| 2026-10-11 | Keep the security audit (`n8n audit`, `POST /api/v1/audit`). Patch the "outdated version" check to make no network call and send no instance ID. | Owner may use it. Wants no data to `api.n8n.io`. If the version check is needed later, find a local solution (see backlog). |

## Egress

| Date | Decision | Why |
|---|---|---|
| 2026-10-10 | Leave `models.dev`, jsDelivr (Code node types), `docs.n8n.io` as is. | Useful in-app. Not telemetry. |
| 2026-10-10 | Runtime egress audit: approved, but light and deferred. Not a blocker. | Owner. |

## Repo and CI

| Date | Decision | Why |
|---|---|---|
| 2026-10-10 | GitHub Actions disabled in repo settings by the owner. Do not rename `.github`. | A rename breaks local tooling (r9). Rename `.github/workflows/` only if ever needed. |
| 2026-10-11 | `.dockerignore` missing lines (`**/*.local`, `**/.vscode`, `**/.idea`, `**/.remember`) go into the Docker-phase work. No separate commit. | Owner. |
| 2026-10-10 | No auto-commit. One logical change per commit. | Global rules. |
| 2026-10-11 | Docker image: one self-contained `docker/images/n8n/Dockerfile.custom` (compile stage + upstream stages). Upstream Dockerfile stays untouched. Source of truth for the options and the bump checklist: `docker-and-coolify.md`. | Owner. Works from a clean checkout and on Windows hosts. Cost: re-diff against upstream on every bump. |
