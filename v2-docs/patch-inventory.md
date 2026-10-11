# Patch inventory (Phase P)

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0).
Date: 2026-10-10. Status: PROPOSED. No source edited. Owner approval needed before Phase I.
Basis: `research/r1` to `r11`. Read from source only. Nothing was run.

Mark each patch with `// CUSTOM PATCH` and keep the original line commented above it. Find them with `git grep -n "CUSTOM PATCH"`.

Decision values: **port** (code patch), **env** (env var only), **skip** (not needed in v2), **drop** (owner decision), **open** (needs owner answer).

## A. v1 categories

| # | v1 category | v2 file | Status | Decision | Ref |
|---|---|---|---|---|---|
| 1 | License bypass: `isLicensed()` true | `packages/cli/src/license.ts:301` | exists | **port** | r1, r2 |
| 1 | Quotas raised | `packages/cli/src/license.ts:432` (`getValue`), `:502` (`getPlanName`) | moved | **port** (see section B) | r3 |
| 2 | Editor settings: `enterprise.*`, folders, AI flags | `packages/cli/src/services/frontend.service.ts:169-686` | replaced | **skip** (follows `isLicensed()`), except `showNonProdBanner` (row N3) | r4 |
| 2 | Editor settings: SSO `loginEnabled` forced | `frontend.service.ts:594-613` | replaced | **skip** (refresh block overwrites it; no effect) | r1, r4 |
| 2 | Editor settings: MFA | `frontend.service.ts` (config-derived, default true) | replaced | **skip** | r4 |
| 3 | Editor telemetry off (store, `Telemetry.vue`) | FE rudderstack init, `/rest/telemetry` | moved | **env** `N8N_DIAGNOSTICS_ENABLED=false` (already set). Verify at runtime | r5 |
| 4 | RBAC FE `hasRole`/`hasScope`/`isEnterpriseFeatureEnabled` | `packages/frontend/editor-ui/src/app/utils/rbac/checks/` | exists | **skip**. Backend enforces scopes; FE patch only opens pages the API refuses | r6 |
| 5 | Router guards removed: usage page | `router.ts:622-628` | exists | **skip** (passes by default) | r6 |
| 5 | Router guards removed: SAML onboarding | `router.ts:1112-1118` | exists | **skip** (passes after `isLicensed()`). Test hard load | r6 |
| 5 | Router guards removed: community nodes | `router.ts:1076-1084` | exists | **skip** (default on) | r6 |
| 6 | AI assistant hosted URL | `ai-assistant.config.ts:9-10` | n/a | **drop** (owner). Keep `baseUrl` empty | r7 |
| 7 | Build tweaks: force `linux/amd64`, chat heap | `scripts/dockerize-n8n.mjs` (`hostPlatform()`) | replaced | **env** `DOCKER_PLATFORM=linux/amd64`. Phase D | r8 |
| 8 | Disable GitHub CI | `.github/` | exists | **open** (Q1). Research advises against full rename | r9 |

## B. License and quota patch (one change set, in `License` class)

| ID | Change | File | Reason |
|---|---|---|---|
| L1 | `isLicensed(feature)` returns true, except the feature list in L2 | `license.ts:301` | One seam for all `LicenseState` getters and `@Licensed` routes |
| L2 | `isLicensed()` returns **false** for `API_DISABLED` and `SHOW_NON_PROD_BANNER` | `license.ts:301` | Inverted flags. True would kill API keys and public API, and show a banner |
| L3 | `getPlanName()` returns `'Enterprise'` | `license.ts:502` | `renewLicense()` and evaluation concurrency check plan name |
| L4 | `getValue()` quota map: `-1` for users, active workflows, variables, team projects, insights max history, retention, workflow-history prune, `quota:evaluations:maxWorkflows`, `quota:evaluations:concurrencyLimit` | `license.ts:432` | r3 |
| L5 | AI credits: large positive number, not `-1` | `license.ts:486` path | FE render of negative credits not verified |
| L6 | Users quota must be exactly `-1`. Never a positive number | `license.ts:471` | Positive value blocks non-owner login, invites, public API (`auth.service.ts:311`). v1 `10_001` would break |
| L7 | Skip `LicenseManager` creation in `License.init()`. No-op `activate()` and `renew()` | `license.ts:235-269` | Stops SDK calls to `license.n8n.io`. SDK checks X.509, so a fake cert fails |
| L8 | Throw in the two `enterprise.n8n.io` routes | `license.service.ts:72,104` | User-triggered egress |

Order: L1+L2+L3, then L4+L5+L6, then L7+L8. Three commits (open item O1 sets L7/L8 scope).

## C. v2-new items (v1 never had these)

| ID | Item | Decision | Ref |
|---|---|---|---|
| N1 | `evaluation.quota`, `projects.team.limit`, `workflowHistory.pruneTime` stay wrong in FE after L1 | **port** via L4 | r4 |
| N2 | `quota:aiGatewayBudget` | **skip** (dead while `baseUrl` empty) | r3 |
| N3 | `showNonProdBanner` set true by L1 at `frontend.service.ts:572` | **port**: covered by L2 (backend). Add FE force-false only if L2 does not reach it | r2, r4 |
| N4 | `enterprise.auditLogs` never set by refresh block | **open** (Q2) | r4 |
| N5 | `provisioning` hard-coded false | **skip** | r2, r10 |
| N6 | Opt-in modules: `agent-evals`, `promotions`, `engine-v2`, `type-availability-policies`, `instance-reporting` | **env** `N8N_ENABLED_MODULES`. Enable `agent-evals`. Others **open** (Q3) | r10 |
| N7 | Agent evals need module, not only the flag | **env** add `agent-evals` to `N8N_ENABLED_MODULES` | r7, r10 |
| N8 | Computer use needs PostHog flag override | **env** `N8N_FEATURE_FLAG_OVERRIDES` with `091_instance_ai_computer_use` set to `"variant"` | r7 |
| N9 | Eight more PostHog-gated features (activity context, at-mentions, conversation history, progressive building, preferences, setup panel, credential descriptions, concise style) | **open** (Q4). Same JSON env | r5, r10 |
| N10 | Instance AI node context / usage / folder exploration | **env** `N8N_INSTANCE_AI_NODE_CONTEXT_ENABLED`, `…_NODE_USAGE_ENABLED`, `…_FOLDER_EXPLORATION_ENABLED` (owner confirm, Q4) | r7 |
| N11 | Microsoft Agent 365 observability defaults on, ignores master switch | **env** `ENABLE_OBSERVABILITY=false`, `ENABLE_A365_OBSERVABILITY_EXPORTER=false` | r5 |
| N12 | License auto-renew safety rail | **env** `N8N_LICENSE_AUTO_RENEW_ENABLED=false` | r2, r11 |

## D. Egress gaps (policy: `localhost` only)

| ID | Host | Source | Fix | Decision |
|---|---|---|---|---|
| E1 | `models.dev` | `packages/@n8n/instance-ai/src/tools/models/model-catalog.service.ts` (plain `fetch`) | No env switch. Code patch or allow host | **open** (Q5) |
| E2 | `data.jsdelivr.com`, `cdn.jsdelivr.net` | FE Code node editor `npmTypesLoader.ts:9-16` | No env switch. Code patch or allow host | **open** (Q5) |
| E3 | `api.n8n.io` MCP registry | `modules/mcp-registry` | `N8N_DISABLED_MODULES=mcp-registry` (corrects brief: it has a switch) | **env** (brief says registry off) |
| E4 | `api.n8n.io` community node catalog | community-packages | `N8N_VERIFIED_PACKAGES_ENABLED=false` (also removes MCP `install_community_node` tool) | **open** (Q6) |
| E5 | `api.n8n.io/api/package` ban check on npm install | community-packages | No switch. Fails open | **open** (Q6) |
| E6 | `api.n8n.io` versions (security audit) | `instance-risk-reporter.ts:160-172` | `N8N_VERSION_NOTIFICATIONS_ENDPOINT` only | **open** (Q7) |
| E7 | `api.n8n.io` onboarding POST | `onboarding.api.ts` | Fires only if "agree" ticked | **skip**. Document |
| E8 | `api.n8n.io` FE direct: versions, What's new, templates | FE | Templates kept on (owner). Others: verify R11 runtime | **open** (Q7) |
| E9 | `sdk-templates.n8n.io` | Instance AI | **env** `N8N_INSTANCE_AI_TEMPLATES_DISABLED=true` | **env** |
| E10 | `docs.n8n.io` | Instance AI docs tool | No switch | **open** (Q5) |
| E11 | `api.firecrawl.dev`, `api-rs.n8n.io` | feature-specific | Document; user-triggered | **skip** |
| E12 | PostHog, RudderStack, Sentry | see r5 | Master switch off. Keep Sentry DSNs unset | **env** (done) |
| E13 | Diagnostics default `true` (one missing env var re-enables all) | `diagnostics.config.ts:18` | Default to `false`, update `config.test.ts:600` | **open** (Q8) |

## E. Corrections to the brief

1. `IMPLEMENTATION-PROMPT.md` section 4: MCP registry and community node listing do have env gates (r10, r11).
2. Section 5: `N8N_AGENT_EVALS_ENABLED=true` is not enough. Add `agent-evals` to `N8N_ENABLED_MODULES`.
3. PostHog cite should be `posthog/index.ts:62,67` (r11).
4. R1 hint `10_001` for users is wrong. Use `-1` (r2, r3).
5. R1 said workflow history prune is unlimited by default. It is 24 hours on the deprecated path (r3).
6. Category 8: r9 recommends against the full `.github` rename.

## F. Phase I commit plan (after approval)

1. L1+L2+L3 license state.
2. L4+L5+L6 quotas.
3. L7+L8 license server bypass.
4. Egress patches approved in Q5 to Q8 (one commit per host group).
5. CI disable per Q1.
6. Env flag confirmation (runtime verify only; `.env.local` is not committed).

Skipped: all FE RBAC, router, SSO, and MFA edits.

## G. Not verified (cross-cutting)

- No runtime check. FE handling of `-1` quotas, SDK behavior with no cert, hard load of `/saml/onboarding`, OpenRouter `url: ''` fallback.
- `.env.local` not read. Some keys above may already be set.
- v2-new marks inferred from module age, not v1.113 history.
- Unit tests that the patches will break are not reviewed.

## H. Updates 2026-10-11 (supersede earlier rows; reasons in `decisions.md`)

| ID | Update |
|---|---|
| O1 / L7 / L8 | Approved. Also hide or disable Activate, Renew, and "request trial/enterprise key" in the FE (location found in Phase I). |
| Egress policy | "localhost only" dropped. Only telemetry/analytics egress is blocked. E1, E2, E10 (`models.dev`, jsDelivr, `docs.n8n.io`): **leave**. E3, E4, E5: **leave on** (MCP registry, community catalog and ban check). E6: see S1. E13: **port** (diagnostics default false). |
| N4 | **port**: force `enterprise.auditLogs` true in the settings refresh. Verify in the UI after (backlog B6). |
| N6 | `N8N_ENABLED_MODULES=agent-evals,promotions` (done in `.env.local`). `engine-v2`: off (backlog B1). `type-availability-policies`: off. `instance-reporting`: off, env stubs empty (backlog B2). |
| N9, N10 | Done as env: dedicated flag vars plus `N8N_FEATURE_FLAG_OVERRIDES` (in `.env.local` and `.env.local.example`). Verify in the UI in Phase V. |
| S1 | **port**: in `instance-risk-reporter.ts`, `getOutdatedState()` returns null without any network call. No instance ID leaves the machine. (Backlog B3.) |
| Q1 | Done by owner (Actions off in repo settings). No rename. |
| Q9 | Runtime audit light and deferred (backlog B4). |
| Phase I commits | 1) L1-L3 license state. 2) L4-L6 quotas. 3) L7-L8 license server and FE buttons. 4) auditLogs force. 5) diagnostics default. 6) security audit local (S1). |

## I. Phase I status (2026-10-11)

| # | Commit | Status | Where | Differs from plan |
|---|---|---|---|---|
| 1 | `f6c66cf3bf` license state (L1-L3) | done | `packages/cli/src/license.ts` `isLicensed`, `getPlanName` | No FE change: `frontend.service.ts:572` reads `isLicensed`, so it gets false. |
| 2 | `ba98f91973` quotas (L4-L6) | done | `license.ts` `CUSTOM_QUOTAS` map used by `getValue` | Map is a module constant. Retention keys set to `-1` per brief (telemetry-only consumers). |
| 3 | `18c72a8c46` license server (L7-L8) | done | `license.ts` `License.licenseServerDisabled`, `init()`; `license/license.service.ts` two methods; FE `SettingsUsageAndPlan.vue` `canUserActivateLicense` | A static flag (not a plain edit) gates `init()` so the original code stays intact. `activate`/`renew`/`renewIfDue` were already no-ops without a manager. FE: only the Activate button existed. No "request trial" button exists. Community-plus modal shows only when unlicensed, so it stays hidden. |
| 4 | `bee424ae60` audit logs | done | `frontend.service.ts` settings refresh (`auditLogs: true`) | none |
| 5 | `bd0d6e5195` diagnostics default | done | `diagnostics.config.ts` `enabled = false`; `config.test.ts` default | 3 tests in `config.test.ts` fail on Windows paths (`uploadDir`). They failed before the patch too. Ignored per owner rule. |
| 6 | `79b363409b` security audit local | done | `instance-risk-reporter.ts` `VERSION_CHECK_DISABLED` flag in `getOutdatedState()` | Used a flag, not commented-out code, so no imports became unused. Tests for this reporter were not updated (owner rule: ignore unit tests). |

| 7 | `26507ebb9f` review fixes | done | `license.ts` `activate()` throws `LICENSE_DISABLED_MESSAGE`; `isLicensed` also returns false for `AI_GATEWAY_CLOUD_UBB` and `AI_ASSISTANT_CLOUD_UBB_ENTITLEMENT`; `license.service.ts` `renewLicense()` returns early | Added after the Opus review of commits 1-3. Not in the original six. Authorized by the owner on 2026-10-11. A startup `N8N_LICENSE_ACTIVATION_KEY` now logs "Could not activate license" (caught in `base-command.ts:564`). Boot continues. |

Known side effects (not fixed, by scope):
- `?key=` on the usage page URL now fails with the disabled message (commit 7). Before commit 7 it showed a false "success".
- The "Plans" / "Manage plan" buttons still link to n8n.io. They are plain links.
- Tests asserting upstream behavior fail or are stale: `license.test.ts` (partly updated in commits 1-3), `instance-risk-reporter` unit and integration tests.

## J. Change reference: everything on `custom.v2` vs `master` (2026-10-11)

### Commits (oldest first)

| SHA | Title | Kind |
|---|---|---|
| `52b672aa7c` | docs: add v1 custom patch reference | docs |
| `82d6223199` | docs: add v2 implementation prompt and plan | docs |
| `9216a36b18` | chore: ignore local dev server logs | repo hygiene (`.gitignore`) |
| `55b3f5ac9e` | build: exclude secrets and agent dirs from Docker build context | `.dockerignore` |
| `e2078c587c` | docs: add v2 research, decisions, patch inventory and backlog | docs |
| `4240f9b1d1` | chore: add v2 module and feature flag keys to the env example | `.env.local.example` (names only) |
| `f6c66cf3bf` | feat(core): treat the instance as licensed (custom) | code |
| `ba98f91973` | feat(core): remove license quotas (custom) | code |
| `18c72a8c46` | feat(core): disable license server calls (custom) | code (BE + FE) |
| `bee424ae60` | feat(core): enable the audit logs setting (custom) | code |
| `bd0d6e5195` | feat(config): disable diagnostics by default (custom) | code |
| `79b363409b` | feat(core): run the security audit without network calls (custom) | code |
| `1dd7a60dc2` | docs: record v2 patch status | docs, plus the "ignore unit tests" rule |
| `71b7e772a5` | build: exclude more local files from the Docker context | `.dockerignore` |
| `26507ebb9f` | fix(core): report disabled license activation and renewal (custom) | code |

### Code changes by file (find all with `git grep -n "CUSTOM PATCH"`)

| File | Change |
|---|---|
| `packages/cli/src/license.ts` | `isLicensed()` true except `API_DISABLED`, `SHOW_NON_PROD_BANNER`, and the two cloud UBB flags. `getPlanName()` returns `Enterprise`. `CUSTOM_QUOTAS` map used by `getValue()`. `License.licenseServerDisabled = true` makes `init()` skip `LicenseManager`. `activate()` throws. Exports `LICENSE_DISABLED_MESSAGE`. |
| `packages/cli/src/license/license.service.ts` | `requestEnterpriseTrial()` and `registerCommunityEdition()` throw `UserError`. `renewLicense()` returns early. |
| `packages/cli/src/services/frontend.service.ts` | Settings refresh sets `enterprise.auditLogs = true`. |
| `packages/@n8n/config/src/configs/diagnostics.config.ts` | `enabled` defaults to `false`. |
| `packages/cli/src/security-audit/risk-reporters/instance-risk-reporter.ts` | `VERSION_CHECK_DISABLED` makes `getOutdatedState()` return `null`. No network call. |
| `packages/frontend/editor-ui/src/features/settings/usage/views/SettingsUsageAndPlan.vue` | `canUserActivateLicense` is `false`. Activate button hidden. |
| Test files (`license.test.ts`, `license.service.test.ts`, `frontend.service.test.ts`, `config.test.ts`) | Edited in commits 1-5 only, before the owner's "ignore unit tests" rule. Stale tests are expected. |

### Non-code changes

- `.env.local` (gitignored, never committed): telemetry and diagnostics off, `N8N_ENABLED_MODULES=agent-evals,promotions`, feature flag vars, `N8N_FEATURE_FLAG_OVERRIDES`. Values are not recorded here.
- `.env.local.example`: names of the same keys, no values.
- `.dockerignore`: `**/.env*`, `**/*.local`, `**/.claude`, `**/.git`, `**/.vscode`, `**/.idea`, `**/.remember` (guard rules added on top of the existing whitelist).
- `.gitignore`: local dev server logs.
- `docker/images/n8n/Dockerfile.custom` and `Dockerfile.custom.dockerignore`: single-file image build, from a clean checkout to a running image. Upstream `docker/images/n8n/Dockerfile` is unchanged. Re-diff on every bump: `v2-docs/docker-and-coolify.md` section 8.
- `CLAUDE.md`: v2 section (decisions, inventory, backlog, tests rule).
- `v2-docs/`: decisions, inventory, backlog, research R1-R11, the two prompts.

### Open, in the backlog

B1 engine-v2, B2 instance-reporting, B3 outdated check, B4 runtime egress audit, B5 Docker build (`Dockerfile.custom` built and checked 2026-10-11; GHCR push and Coolify deploy not run), B6 audit logs UI check, B7. See `backlog.md`.
