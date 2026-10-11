# Implementation prompt: local n8n v2 build (custom.v2)

Use this file as the full brief for any agent that continues this work.
Invoke it with the prompt in section 9.

Writing style: ASD-STE100 (short sentences, active voice, one instruction per sentence). Follow `AGENTS.md`.

---

## 1. Goal

Run a local, personal, n8n v2 build from branch `custom.v2`.

It must:

- Run without a license key. All enterprise (`feat:*`) features unlocked.
- Send no telemetry, diagnostics, metrics or version checks to n8n or PostHog.
- Keep only the outbound calls the owner chose (listed in section 4).
- Keep every custom change marked and documented, so a future v2 bump can re-apply them.
- Run locally first. Docker image is a later phase.

Done means:

1. Patch inventory maps every v1 custom category to a v2 file, or to an explicit "drop" decision.
2. Each patched behavior is checked in the running UI or API.
3. Runtime egress audit shows no hosts outside the allowlist (section 4).
4. Docker image builds and boots with the same checks (later phase).
5. Research and patch docs live in `v2-docs/`.

---

## 2. Background

### 2.1 v1 "custom" branch (reference only)

Branch `custom.v1` held n8n 1.113.0 plus local patches. Full copy is in this branch under `v1-docs/`:

- `v1-docs/custom.md`: patch reference, 8 categories, v1 to v2 path map.
- `v1-docs/custom-full.diff`: full v1 diff, 1736 added lines.
- `v1-docs/docker/images/n8n-custom/`: v1 Docker build files.
- `v1-docs/README.md`: summary.

Commit that added them: `178fcc0999`.

v1 patch categories (all wanted on v2):

1. License bypass (backend `isLicensed()` true, quotas raised).
2. Editor settings forced on (SSO, AI assistant, enterprise flags, MFA, folders).
3. Editor telemetry off (store, `Telemetry.vue`).
4. RBAC checks always pass (`hasRole`, `hasScope`, `isEnterpriseFeatureEnabled`).
5. Router guards removed (usage page, SAML onboarding, community nodes).
6. AI assistant URL default changed to a hosted endpoint. **Not wanted on v2.** Keep empty.
7. Build tweaks (force `linux/amd64`, chat package heap). Only for Docker phase.
8. Disable GitHub CI (`.github` renamed to `.bak_github`). Owner said yes. Verify impact first (R9).

### 2.2 v2 state (this branch)

- Branch: `custom.v2`. Base n8n `2.43.0`. Node `>=24`. pnpm `12.4.2` pinned.
- Dev commands work: `pnpm install`, `pnpm build` (72/72), `pnpm dev:be` (port 5678), `pnpm dev:fe:editor` (port 8080). Both returned HTTP 200.
- Local env: `.env.local` at repo root (committed, no secrets; see `v2-docs/env-local.md`). Loaded with `pnpm exec dotenvx run -f .env.local -- <cmd>`.
- `CLAUDE.md` (repo root) holds local dev setup. Keep it current.
- `.dockerignore`: whitelist (`*`) plus secret guard lines at the end (`**/.env*`, `**/.claude`, `**/.git`). Not yet committed.
- Commit `178fcc0999`: `v1-docs/` added.

### 2.3 Rules that apply (from the owner's global rules)

- **No secrets in committed files.** The admin password lives only in `.env.secrets.local` (gitignored). Never copy it into a doc, commit, or command line. Never put secrets in Docker `ARG` or image layers.
- **No auto-commit.** Commit only when the owner asks in the current turn.
- **One logical change per commit.** Do not bundle categories.
- **Verify behavior.** Type checks and unit tests do not prove a UI feature works. Run the app and exercise the feature.
- **Surgical changes.** Every changed line must trace to the request.
- **Pick the minimum.** No speculative config or abstractions.
- **Subagents.** Set `model` and `tools` explicitly on every Agent call. Use `sonnet` + medium for bounded judgment. Keep synthesis in the main loop.
- **Research output needs citations.** Format: `[Source: <path>:<line> | YYYY-MM-DD | confidence: high|medium|low]`.
- **Plans** go to `.claude/plans/` (gitignored). **Docs** go to `v2-docs/` (committed).
- **Batch questions.** If the owner must decide, write one questionnaire file. Do not ask one question per chat turn.

---

## 3. Decisions locked (owner answers)

| Topic | Decision |
|---|---|
| Patch scope | All 8 v1 categories, except item 6 (AI hosted URL). Item 8 yes. |
| Licensing | Code patch. Not env-only. |
| Telemetry | Off. Remove PostHog and diagnostics egress. Env `N8N_DIAGNOSTICS_ENABLED=false` already set. Verify in R5/R11. |
| License server calls | Bypass in code. Env flag alone does not stop them. Scope set by R2. |
| Feature flags | Env first. Code patch only when a license check blocks a feature. |
| Feature set | Enable all new v2 features unless the owner says otherwise. OTel off. |
| Egress allowlist | `localhost` only, plus any host the owner later adds in writing. |
| Binary data | Filesystem only. No S3/MinIO in this phase. |
| Pruning | `EXECUTIONS_DATA_PRUNE=true`, `EXECUTIONS_DATA_MAX_AGE=336` (hours = 14 days). |
| api.n8n.io | Templates on (`N8N_TEMPLATES_ENABLED=true`). Dynamic banners off. Version notifications off. Community node listing off (install by npm name still works). MCP registry client off (enable later). Onboarding: leave default, check in R10. |
| AI assistant | No hosted URL. Model connection added later in the admin UI (OpenRouter key). No env var for it. |
| Workflow suggestions | On (`N8N_INSTANCE_AI_WORKFLOW_SUGGESTIONS_ENABLED=true`). Needs an LLM connected later. |
| Agent evals | On (`N8N_AGENT_EVALS_ENABLED=true`). For the owner, not PostHog. Needs an LLM connected later. |
| MCP apps | On (`N8N_MCP_APPS_ENABLED=true`). |
| MCP server | On (default). Access toggled in UI. |
| Computer use | On. Tray app on the owner's PC, after pairing. Shell stays denied. |
| OpenTelemetry | Off (`N8N_OTEL_ENABLED=false`). |
| Web search | SearXNG. `N8N_INSTANCE_AI_SEARXNG_URL=http://localhost:8888`. SearXNG not started yet. Brave: off. |
| Sandbox (code run) | Deferred. Prefer self-hosted `n8n-sandbox` service from the Docker compose, later. Daytona: off. |
| Docker | Local image only, later phase. `linux/amd64`. No registry push. |
| Build tweaks / CI disable | Yes. Do in the Docker phase, after R8/R9. |

### Open items (must be answered before the matching phase)

- O1. License call sites: which network calls to bypass, and what local value to keep (R2).
- O2. Q12 (owner, free text): anything else to keep, drop, or check first.
- O3. Confirm `.dockerignore` change is committed in its own commit (owner decision).

---

## 4. Egress policy

Allowed outbound from the app: `localhost` and loopback only. Plus:

- SearXNG upstream search engines (only when web search is used, owner accepts this).
- LLM provider the owner adds in the UI (OpenRouter), only when a model is connected.

Not allowed:

- `ph.n8n.io` (PostHog), `api.n8n.io` except where section 3 keeps templates, `license.n8n.io`, Daytona, Brave.

Known egress sources (from code reading, to verify in R11):

| Source | Where | Switch |
|---|---|---|
| PostHog analytics | `packages/cli/src/posthog/index.ts:60-62` | `N8N_DIAGNOSTICS_ENABLED=false` (verified: init skipped) |
| License server | `packages/@n8n/config/src/configs/license.config.ts:7` (`https://license.n8n.io/v1`), `packages/cli/src/license.ts`, `license.service.ts` | Code patch (O1) |
| Templates | `packages/@n8n/config/src/configs/templates.config.ts` (`https://api.n8n.io/api/`) | `N8N_TEMPLATES_ENABLED` (kept on, owner choice) |
| Version notifications | `packages/@n8n/config/src/configs/version-notifications.config.ts` | `N8N_VERSION_NOTIFICATIONS_ENABLED=false` |
| Dynamic banners | `packages/@n8n/config/src/configs/dynamic-banners.config.ts` (`https://api.n8n.io/api/banners`) | `N8N_DYNAMIC_BANNERS_ENABLED=false` |
| Community node listing | `packages/cli/src/modules/community-packages/*.ts` | Not env-gated found yet (R10) |
| MCP registry client | `packages/cli/src/modules/mcp-registry/registry/mcp-registry-api.client.ts` | Not env-gated found yet (R10) |
| Frontend onboarding | `packages/frontend/@n8n/stores/src/onboarding.api.ts` | R10 |
| OpenTelemetry | `N8N_OTEL_ENABLED` (default false) | `N8N_OTEL_ENABLED=false` |
| Daytona sandbox | `N8N_INSTANCE_AI_SANDBOX_PROVIDER=daytona` | Unset (default is `n8n-sandbox`) |
| Brave search | `INSTANCE_AI_BRAVE_SEARCH_API_KEY` | Unset |
| Local gateway | Tray app dials out to the owner's n8n URL | Owner pairs the PC; not an n8n outbound |

Important: some features are PostHog-gated (MCP apps, agent evals). With PostHog off, these fall back to off. The env force flags (set in `.env.local`) override that.

---

## 5. Feature flags (set in `.env.local`, already applied)

```
N8N_INSTANCE_AI_WORKFLOW_SUGGESTIONS_ENABLED=true
N8N_AGENT_EVALS_ENABLED=true
N8N_MCP_APPS_ENABLED=true
N8N_TEMPLATES_ENABLED=true
N8N_OTEL_ENABLED=false
N8N_DYNAMIC_BANNERS_ENABLED=false
N8N_INSTANCE_AI_SEARXNG_URL=http://localhost:8888
N8N_DIAGNOSTICS_ENABLED=false
N8N_VERSION_NOTIFICATIONS_ENABLED=false
N8N_HIRING_BANNER_ENABLED=false
N8N_METRICS=false
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=336
N8N_DEFAULT_BINARY_DATA_MODE=filesystem
```

Do not print secret values in chat or docs. Name the keys only.

---

## 6. Phases

Run research first. Patches come after research is reviewed.

### Phase R: research (no patch code)

Outputs go to `v2-docs/research/`. One file per workstream.

| # | Question | Output file |
|---|---|---|
| R1 | For each v1 patch in `v1-docs/custom-full.diff`, find the v2 equivalent. Status: exists / moved / removed / replaced. Use `v1-docs/custom.md` path table as a hypothesis. | `r1-patch-map.md` |
| R2 | How v2 gates features. `LicenseState`, `License`, `@n8n/backend-common`, `modules/*`, FE `isEnterpriseFeatureEnabled`, `hasScope`, `hasRole`. Which network calls the license code makes. Which local value each call should return. | `r2-licensing.md` |
| R3 | Quotas. Every value v1 hardcoded (users, workflows, variables, AI credits, insights retention, team projects, evals). v2 defaults and location. | `r3-quotas.md` |
| R4 | Frontend settings. `packages/cli/src/services/frontend.service.ts` settings shape in v2. Store location (`packages/frontend/@n8n/stores/src/settings.store.ts`). Flags for SSO, AI assistant, folders, MFA, history, diffs. | `r4-fe-settings.md` |
| R5 | Telemetry and diagnostics. All BE and FE paths. Which are gated by `N8N_DIAGNOSTICS_ENABLED`. Which are not. Gaps needing a code patch. | `r5-telemetry.md` |
| R6 | RBAC and router. v2 scopes, roles, projects. FE guards in `packages/frontend/editor-ui/src/app/router.ts`. Equivalent of each v1 removed guard. | `r6-rbac-router.md` |
| R7 | AI assistant. `packages/@n8n/config/src/configs/ai-assistant.config.ts`, `packages/@n8n/instance-ai`. Confirm no hosted default. | `r7-ai-assistant.md` |
| R8 | Build and Docker. `scripts/build-n8n.mjs`, `scripts/dockerize-n8n.mjs` (platform logic), `docker/images/n8n/Dockerfile`. Is the `npm@11.4.1` pin still needed? | `r8-docker.md` |
| R9 | CI. Impact of renaming `.github/`. What breaks locally. | `r9-ci.md` |
| R10 | Feature inventory. Every v2 package and module (`packages/@n8n/*`, `packages/modules/*`). Per feature: default, env flag, license gate, telemetry, outbound host. | `r10-feature-inventory.md` |
| R11 | Egress audit. Static: grep non-test source for `http(s)://` hosts and SDK calls. Runtime: see section 7. | `r11-egress.md` |

Ordering: R1 first. R2 to R9 can run in parallel after R1. R10 and R11 can run in parallel with all.

Each research file must include: commit SHA checked, file:line references (re-grep before citing), citations per section 2.3, and a "not verified" list.

### Phase P: patch plan

Output: `v2-docs/patch-inventory.md`. Table columns: v1 category, v2 file, status, decision (port / drop / replace with env), owner answer reference.

No code edits in this phase.

### Phase I: implement (after owner approves P)

One commit per category. Order (suggested):

1. License bypass (backend `isLicensed`, quotas). Verify: `/api/v1/...` license endpoints or UI shows enterprise features.
2. License server calls bypassed. Verify: no request to `license.n8n.io` in the egress run.
3. FE settings forced (SSO, folders, enterprise flags).
4. FE telemetry removed (store and any `Telemetry.vue` equivalent). Verify: no PostHog request.
5. RBAC checks always true (FE). Verify: UI shows all actions for owner.
6. Router guards removed. Verify: usage page, SAML onboarding reachable.
7. Feature flags confirmed in `.env.local` (already done; verify runtime).

Mark every patch with `// CUSTOM PATCH` and keep the original line commented above, as v1 did. Find them with `git grep -n "CUSTOM PATCH"`.

Skip item 6 from v1 (AI hosted URL). Skip v1 category 7 (Docker tweaks) until Phase D.

### Phase V: verify (after each commit)

- `pnpm build` must pass for changed packages. Full log to `build.log` (gitignored).
- Typecheck and lint for changed packages: `pnpm typecheck`, `pnpm lint` in that package.
- Run dev servers with `.env.local`. Exercise the feature in the browser. Record the result.
- Run the egress check (section 7) after each telemetry or license commit.

### Phase D: Docker (later, owner will ask)

- Port v1 `Dockerfile` idea onto `docker/images/n8n/Dockerfile` layout.
- Build tweaks (category 7). `linux/amd64` only.
- Filesystem binary data volume at `/home/node/.n8n`.
- Image tag `n8nio/n8n:local` via `pnpm build:docker`, or a custom tag.
- No registry push.
- Container env file separate from `.env.local`, not copied into the image.
- After build: grep the image for `.env` files and run the same feature checks.

---

## 7. Runtime egress audit (R11, runtime part)

Goal: prove no outbound host except the allowlist.

Method:

1. Start backend and editor with an HTTP(S) proxy in front, for example `HTTPS_PROXY=http://127.0.0.1:<port>` and `HTTP_PROXY`. Use a CONNECT-logging proxy (host and port only, no payload decryption).
2. Record in this order:
   - Idle for 5 minutes after startup.
   - Log in as the admin. Open each main page once.
   - Open the editor, create one workflow, run it.
   - Open templates. Open the AI assistant panel (no model connected).
   - Open MCP settings. Open agent evals page.
3. Save the log to `v2-docs/research/r11-egress-log.txt`, without credentials.
4. Output table: host, time, trigger, action (blocked / patched / allowed).

Pass criteria: only `127.0.0.1`, `localhost`, and hosts in the allowlist (section 4).

Note: the owner must agree before a proxy is installed on the machine. Ask first.

---

## 8. Output locations

| Path | Content | Committed |
|---|---|---|
| `v1-docs/` | v1 reference | Yes (done) |
| `v2-docs/README.md` | Index and status | Yes |
| `v2-docs/research/*.md` | R1 to R11 outputs | Yes |
| `v2-docs/patch-inventory.md` | Patch decisions | Yes |
| `v2-docs/IMPLEMENTATION-PROMPT.md` | This file | Yes |
| `.claude/plans/` | Plans, questionnaires | No (gitignored) |
| `build.log`, `dev-be.log`, `dev-fe.log` | Logs | No (gitignored) |

---

## 9. Invocation prompt

Paste this into a new session (or pass it to a subagent) to start:

```
Read v2-docs/IMPLEMENTATION-PROMPT.md in full. Follow sections 1-8 exactly.

Start with Phase R (research only). Do not edit any source file.

1. Confirm branch is custom.v2 and HEAD. Record SHA.
2. Run R1 first (inline or one agent, model sonnet, effort medium). Write v2-docs/research/r1-patch-map.md.
3. After R1, run R2 to R10 in parallel (one agent per workstream, model sonnet, effort medium, explicit tools: Read, Grep, Glob). Each writes its file under v2-docs/research/.
4. Run R11 static part in the same way. Do not install a proxy or start the runtime audit without owner approval.
5. Write v2-docs/patch-inventory.md (Phase P). Do not edit source yet.
6. Stop and report: summary of findings, open items (section 3, O1-O3), and the questions only the owner can answer. Batch them in one questionnaire file under .claude/plans/.

Rules: sections 2.3 and 4 are binding. Never copy values from .env.local into any file. Do not commit. Do not start Docker work.
```

---

## 10. Pickup notes

- Last known state: env flags applied to `.env.local`. Backend not restarted after the last env change. Restart before runtime checks.
- SearXNG is not running. Web search fails until it runs (`http://localhost:8888`).
- No LLM connected. Workflow suggestions, evals, and assistant need one (owner will add OpenRouter in the admin UI).
- Admin login exists in `.env.secrets.local` (`ADMIN_EMAIL`, `ADMIN_PASSWORD`). Use it for browser checks. Do not print it.
