# custom branch: patch reference

Reference for AI agents and humans porting the `custom` branch patches. Written from `git diff 9806e6fc72 custom` (base = last v1 commit `9806e6fc72`, n8n 1.113.0 line).

Goal of the branch: run a local n8n build with all enterprise/licensed features unlocked, telemetry off, and a custom Docker image. Personal/local use only. Licensing enforcement is disabled.

## Convention

Every patch is marked `// CUSTOM PATCH`. Original line is kept commented above it. To list all patches on any tree:

```bash
git grep -n "CUSTOM PATCH"
```

## Commits on custom (v1 base, oldest first)

| SHA | Subject | Area |
|---|---|---|
| 6be3e14fe9 | patch | Mixed code patches |
| 916192b445 | updated custom docker | Docker image |
| 8465790593 | renamed .github to ifnore acrtinos | CI disabled |
| adbff6b2f4 | change vars to see changes | Misc |
| e5feebf04c | added scripts for local-build | Build |
| 9e6cb87fb1 | small patches for build | Build |
| 769741eabd | docs: Add custom.md documenting branch changes | Docs |

Merge commits (`Merge branch 'master' into custom`) are noise; ignore for porting.

## Categories

### 1. License bypass (backend)

Files:
- `packages/@n8n/backend-common/src/license-state.ts`
- `packages/cli/src/license.ts`
- `packages/cli/src/license/license.service.ts`
- `packages/cli/src/modules/insights/insights.service.ts`

What:
- `LicenseState.isLicensed()` and `License.isLicensed()` return `true` for every feature. Original call to `licenseProvider` / `manager.hasFeatureEnabled` commented out.
- Quotas hardcoded (originally read from license, falling back to unlimited or 0):
  - `getMaxUsers`, `getMaxActiveWorkflows`, `getMaxVariables`, `getMaxTeamProjects`, `getMaxWorkflowsWithEvaluations` → `10_001`
  - `getMaxAiCredits` → `10_000_001`
  - `getWorkflowHistoryPruneQuota` → `UNLIMITED_LICENSE_QUOTA`
  - `getInsightsMaxHistory` → `30`; `getInsightsRetentionMaxAge` → `180`; `getInsightsRetentionPruneInterval` → `120`
- `getPlanName()` and `license.service` planName → `'Enterprise'`.
- `InsightsService.getAvailableDateRanges()`: max history = `Number.MAX_SAFE_INTEGER`, hourly data always licensed.

Why: unlock enterprise UI and limits without a license key.

### 2. Frontend settings / feature flags (backend-served)

File: `packages/cli/src/services/frontend.service.ts`

What (settings object sent to editor):
- `sso.saml.loginEnabled`, `sso.ldap.loginEnabled` → `true`
- `aiAssistant.enabled` → `true`; `askAi.enabled`, `aiCredits.enabled` → `true`; `aiCredits.credits` → `1_000_000_000`
- `hiringBannerEnabled` → `false`
- `enterprise.*` → mostly `true` (sharing, logStreaming, advancedExecutionFilters, variables, sourceControl, auditLogs, externalSecrets, debugInEditor, binaryDataS3, workerView, advancedPermissions, apiKeyScopes, workflowHistory, workflowDiffs). `ldap`, `saml`, `oidc`, `mfaEnforcement` still `false`. `projects.team.limit` → `10_000`.
- `mfa.enabled` → `true`
- `hideUsagePage` → `false`
- `license.environment` → `'development'`
- `variables.limit` → `10_000`
- `folders.enabled` → `true`
- Refresh block that reads `this.license.isXxx()` for `enterprise.*` is commented out (so it does not overwrite the hardcoded values above).

### 3. Frontend store / init

Files (v1 paths):
- `packages/frontend/editor-ui/src/stores/settings.store.ts`
- `packages/frontend/editor-ui/src/init.ts`
- `packages/frontend/editor-ui/src/components/Telemetry.vue`
- `packages/frontend/editor-ui/src/components/banners/NonProductionLicenseBanner.vue`

What:
- `isTelemetryEnabled` → `false` (store and `Telemetry.vue`). No telemetry sessionStarted event.
- `isCommunityPlan` → `false`; `isDevRelease` → `false`.
- `folders.value.enabled` → `true`.
- `init.ts`: NON_PRODUCTION_LICENSE banner not pushed.
- Banner `dismissible` → `true`.

### 4. RBAC and enterprise checks (frontend)

Files (v1 paths):
- `packages/frontend/editor-ui/src/utils/rbac/checks/hasRole.ts` → always `true`
- `.../checks/hasScope.ts` → always `true`
- `.../checks/isEnterpriseFeatureEnabled.ts` → always `true`

Note: `hasRole.ts` has dead code after `return true;`.

### 5. Router guards (frontend)

File: `packages/frontend/editor-ui/src/router.ts`

What: removed custom middleware guards:
- Usage page: `custom` (hideUsagePage) guard removed.
- Community nodes: `custom` guard removed; `rbac` kept with `middleware: ['authenticated', 'rbac']` but its `middlewareOptions` and `telemetry` commented out, so the rbac scope check has no options.
- SAML onboarding: `custom` guard removed.
- Evaluation route: `custom` guard commented, not active.

### 6. Config

File: `packages/@n8n/config/src/configs/ai-assistant.config.ts`

`baseUrl` default → `https://ai-assistant.n8n.io` (was `''`). Env `N8N_AI_ASSISTANT_BASE_URL` still overrides.

### 7. Build and Docker

Files:
- `scripts/dockerize-n8n.mjs`: `getDockerPlatform()` forced to `linux/amd64` (original `linux/${dockerArch}` commented).
- `packages/frontend/@n8n/chat/package.json`: `build:vite` and `build:bundle` get `NODE_OPTIONS="--max-old-space-size=4096"`.
- `docker/images/n8n-custom/Dockerfile` (new, 66 lines): two stage. Stage 1 `n8nio/base:${NODE_VERSION}` runs `pnpm install --frozen-lockfile`, `pnpm build`, trims FE package.json via `.github/scripts/trim-fe-packageJson.js`, strips `.ts`/`.vue` sources, runs `pnpm --filter=n8n --prod deploy /compiled`. Stage 2 copies `/compiled` into `/usr/local/lib/node_modules/n8n`, downloads task-runner-launcher `LAUNCHER_VERSION=1.1.2` with sha256 check, `npm rebuild sqlite3`, pins `npm@11.4.1` (cross-spawn CVE).
- `docker/images/n8n-custom/Dockerfile.ghcr.custom`: `FROM ghcr.io/noamloewenstern/n8n:custom2`.
- `docker/images/n8n-custom/build-mac.sh` (`linux/arm64`) and `build-x86.sh` (`linux/x86_64`): `docker buildx build -t n8n-patch ...`.
- `docker/images/n8n-custom/README.md`: usage `docker build -t n8n-custom -f docker/images/n8n-custom/Dockerfile .`

### 8. CI disabled

- `.github/` renamed to `.bak_github/` (all workflows, issue templates, CODEOWNERS, actionlint.yaml, PR templates).
- `.github/actions/setup-nodejs-github/action.yml` deleted.
- `.bak_github/scripts/` added: `bump-versions.mjs`, `ensure-provenance-fields.mjs`, `update-changelog.mjs`, `validate-docs-links.js`, `trim-fe-packageJson.js`, `package.json`.
- `.bak_github/workflows/sbom-generation-callable.yml` added.

Why: GitHub Actions not wanted on the fork. The v1 master commit `2ad9c80e51 delete github actions` renames to `.github.bak`, which conflicts with this branch's `.bak_github` rename, so cherry-pick aborted. Cherry-picking it again will conflict the same way. `origin/master` (v2) still has a `.github/` directory with 14 entries, so the disable is not applied there.

## Porting to v2 (master `e2b4fee0ec`, n8n 2.43.0)

Path changes (v1 → v2 on `master`):

| v1 path | v2 path | Status |
|---|---|---|
| `packages/@n8n/backend-common/src/license-state.ts` | same | exists, changed |
| `packages/cli/src/license.ts` | same | exists |
| `packages/cli/src/license/license.service.ts` | same | exists |
| `packages/cli/src/services/frontend.service.ts` | same | exists, heavily changed |
| `packages/cli/src/modules/insights/insights.service.ts` | `packages/modules/insights/backend/src/insights.service.ts` | moved |
| `packages/@n8n/config/src/configs/ai-assistant.config.ts` | same | exists |
| `packages/frontend/@n8n/chat/package.json` | same | exists |
| `packages/frontend/editor-ui/src/stores/settings.store.ts` | `packages/frontend/@n8n/stores/src/settings.store.ts` | moved |
| `packages/frontend/editor-ui/src/router.ts` | `packages/frontend/editor-ui/src/app/router.ts` | moved |
| `packages/frontend/editor-ui/src/utils/rbac/checks/*.ts` | `packages/frontend/editor-ui/src/app/utils/rbac/checks/*.ts` | moved |
| `.../components/banners/NonProductionLicenseBanner.vue` | `packages/frontend/editor-ui/src/features/shared/banners/components/banners/NonProductionLicenseBanner.vue` | moved |
| `packages/frontend/editor-ui/src/init.ts` | not found by name | search |
| `packages/frontend/editor-ui/src/components/Telemetry.vue` | not found by name | search |
| `scripts/dockerize-n8n.mjs` | same | exists |
| `docker/images/n8n-custom/*` | not on master | port needed |
| `.github/` workflows | `.github/` on master (not renamed) | re-apply rename if still wanted |

Notes for porting:
- v2 changed 38 of these files (527 insertions, 2601 deletions vs v1 base). Expect manual re-apply, not a cherry-pick. Re-derive each patch from the v2 file; do not replay the diff.
- v2 Dockerfile (`docker/images/n8n/Dockerfile`) is multi-stage with native-module builder stages (isolated-vm, sqlite3, confluent kafka). The custom v1 Dockerfile does not map onto it. Port the idea (copy compiled tree, pin npm, launcher) onto the v2 layout.
- Node 24+ and pnpm 12.4.2 on v2 (v1: Node 22, pnpm 10.16).
- Re-verify every quota, flag, and default against v2 types before trusting this list. Values here describe v1 behavior.

## Known issues in the patch set

- Global `isLicensed() → true` also enables features whose code paths assume a real license (for example, the license-state `getValue` and the planName used by FE). Test each feature after porting.
- `hasRole` / `hasScope` return `true` for all users. Any RBAC-gated UI is open. Fine for single-user local use; not for shared deployments.
- Telemetry disabled in both FE store and `Telemetry.vue`; BE telemetry not touched.
- `hiringBannerEnabled` hardcoded `false`; original read from `config.getEnv('hiringBanner.enabled')`.

## Last updated

- 2026-10-09, by Noam Loewenstern (analysis by Claude)
