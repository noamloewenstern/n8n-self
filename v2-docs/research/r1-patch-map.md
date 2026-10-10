# R1: v1 custom patch map to v2

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: read `v1-docs/custom-full.diff`, then Glob/Grep every v2 path. `v1-docs/custom.md` was a hypothesis only. No source file was edited. `.env.local` was not read.

Status words: **exists** (same file, same code), **moved** (new path, same logic), **replaced** (new function or file does the job), **removed** (v2 deleted the code).

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.

## Key finding: one choke point

In v2, `LicenseState.isLicensed()` calls `licenseProvider.isLicensed()`. The provider is `License`. So patching `License.isLicensed()` alone makes `LicenseState` return true too. The deprecated `License.isXxxEnabled()` getters also call `License.isLicensed()`.
[Source: packages/@n8n/backend-common/src/license-state.ts:33-45 | 2026-10-10 | high]
[Source: packages/cli/src/license.ts:301-303 | 2026-10-10 | high]

Numeric quotas do NOT go through `isLicensed()`. They go through `getValue()`. Two paths exist:
- `LicenseState.getMax*()` calls `LicenseState.getValue()`, which calls `License.getValue()`. [Source: packages/@n8n/backend-common/src/license-state.ts:47-51 | 2026-10-10 | high]
- Deprecated `License.getUsersLimit()`, `getVariablesLimit()`, `getAiCredits()`, `getTeamProjectLimit()`, `getTriggerLimit()` call `License.getValue()` directly. `frontend.service.ts` and `license.service.ts` use them. [Source: packages/cli/src/license.ts:469-500 | 2026-10-10 | high]

`License.getValue()` is one function that feeds both paths. [Source: packages/cli/src/license.ts:432-434 | 2026-10-10 | high]
The v1 patch did not touch the deprecated getters. It hardcoded the settings object instead. v2 can reach the same result with fewer edits (see Notes for the patch plan, at the end).

The e2e test controller already overrides `isLicensed`, `getValue` and `getPlanName` on the `License` instance. It is a proof that these three are the complete seam. [Source: packages/cli/src/controllers/e2e.controller.ts:216-229 | 2026-10-10 | high]

## Category 1: License bypass (backend)

| ID | v1 file and hunk | v2 file:line | Status | Notes |
|---|---|---|---|---|
| 1.1 | `backend-common/src/license-state.ts` `isLicensed()` returns `true` | `packages/@n8n/backend-common/src/license-state.ts:33` | exists, changed | v2 takes `BooleanLicenseFeature \| BooleanLicenseFeature[]`. Array means "any of". A patch must return `true` for both shapes. `assertProvider()` is still called first. Redundant if 1.3 is patched. [Source: license-state.ts:33-45 \| 2026-10-10 \| high] |
| 1.2a | `getMaxUsers()` to `10_001` | `license-state.ts:233` | exists | Unchanged body. [Source: license-state.ts:233-235 \| 2026-10-10 \| high] |
| 1.2b | `getMaxActiveWorkflows()` to `10_001` | `license-state.ts:237` | exists | Unchanged. |
| 1.2c | `getMaxVariables()` to `10_001` | `license-state.ts:241` | exists | Unchanged. |
| 1.2d | `getMaxAiCredits()` to `10_000_001` | `license-state.ts:245` | exists | Unchanged. |
| 1.2e | `getWorkflowHistoryPruneQuota()` to `UNLIMITED_LICENSE_QUOTA` | `license-state.ts:249` | exists | Unchanged. Already unlimited by default when `getValue` returns undefined. |
| 1.2f | `getInsightsMaxHistory()` to `30` | `license-state.ts:253` | exists | Default is `7`. Used by Insights (see 1.6). |
| 1.2g | `getInsightsRetentionMaxAge()` to `180` | `license-state.ts:257` | exists | v2 default already `180`. Only consumer left is the telemetry relay. [Source: packages/cli/src/events/relays/telemetry.event-relay.ts:2008 \| 2026-10-10 \| high] |
| 1.2h | `getInsightsRetentionPruneInterval()` to `120` | `license-state.ts:261` | exists | v2 default `24`. Only consumer is the telemetry relay (line 2009). Low value. |
| 1.2i | `getMaxTeamProjects()` to `10_001` | `license-state.ts:265` | exists | `isTeamProjectsLicensed()` (line 269) derives from it. Default is `0`, so this one matters. |
| 1.2j | `getMaxWorkflowsWithEvaluations()` to `10_001` | `license-state.ts:274` | exists | Default `0`. Feeds `settings.evaluation.quota`. [Source: packages/cli/src/services/frontend.service.ts:441,681 \| 2026-10-10 \| high] |
| 1.3 | `cli/src/license.ts` `isLicensed()` returns `true` | `packages/cli/src/license.ts:301` | exists | Same code as v1 original. This is the single choke point. |
| 1.4 | `License.getPlanName()` returns `'Enterprise'` | `packages/cli/src/license.ts:502` | exists | Same original. v2 adds a caller: `license.service.ts:181` skips renewal when plan is `'Community'`. Also used by `evaluation-concurrency.helper.ts:75`. [Source: license.ts:502-504 \| 2026-10-10 \| high] |
| 1.5 | `license.service.ts` `planName: 'Enterprise'` | `packages/cli/src/license/license.service.ts:65` | exists | Redundant if 1.4 is patched. Same file, shifted lines. [Source: license.service.ts:64-65 \| 2026-10-10 \| high] |
| 1.6 | `insights.service.ts` `getAvailableDateRanges()`: max history `MAX_SAFE_INTEGER`, hourly `true` | `packages/modules/insights/backend/src/insights.settings.ts:24-30` and `packages/modules/insights/backend/src/insights.service.ts:390-394` | moved and split | The logic now lives in TWO places. `insights.settings.ts` has `getAvailableDateRanges()`. `insights.service.ts:390` has the same two-line pattern inside a date validation method. v1 patched one place. v2 needs both, or one fix at the source: make `getInsightsMaxHistory()` return `-1` (the code already maps `-1` to `MAX_SAFE_INTEGER`) and make `isInsightsHourlyDataLicensed()` true via 1.3. [Source: insights.settings.ts:26-29 \| 2026-10-10 \| high] [Source: insights.service.ts:391-394 \| 2026-10-10 \| high] |

## Category 2: Frontend settings served by backend (`frontend.service.ts`)

File: `packages/cli/src/services/frontend.service.ts` (same path, 740+ lines in v2). The initial settings object is built in `initSettings()` (line 169). The refresh runs in `getSettings()`/refresh code (lines ~495-686).

| ID | v1 hunk | v2 file:line | Status | Notes |
|---|---|---|---|---|
| 2.1 | `sso.saml.loginEnabled`, `sso.ldap.loginEnabled` to `true` | `frontend.service.ts:278,282` | exists | v2 also has `sso.managedByEnv` (276) and `sso.oidc` (285). The refresh block (594-613) overwrites `loginEnabled` from `globalConfig.sso.*.loginEnabled` when licensed. So with 1.3 patched, the real config wins, not `true`. Forcing `true` shows SAML/LDAP login buttons with no provider set up. v1 kept `enterprise.saml/ldap` false. Decide: skip this patch. |
| 2.2 | `hiringBannerEnabled` to `false` | `frontend.service.ts:313` | exists | Still `globalConfig.hiringBanner.enabled`. Default `true`. [Source: packages/@n8n/config/src/configs/hiring-banner.config.ts:7 \| 2026-10-10 \| high] Env alone can turn it off. Check the env name in the config class before patching. |
| 2.3 | `aiAssistant.enabled` to `true` | `frontend.service.ts:314-318` | exists, changed | v2 adds `cloudUbbEnabled`. Refresh at 621-627 sets `enabled` from the license. With 1.3 true, `enabled` becomes true. `setup` = `!!aiAssistant.baseUrl \|\| !!N8N_AI_ANTHROPIC_KEY` (line 623). Category 6 says keep `baseUrl` empty, so `setup` stays false unless an Anthropic key env is set. |
| 2.4 | `enterprise.*` all `true`, `projects.team.limit` `10_000` | `frontend.service.ts:340-371` (initial) and `552-588` (refresh) | replaced | v2 initial object: `apiKeyScopes` and `workflowHistory` keys are gone. New keys: `namedVersions`, `provisioning`, `customRoles`, `personalSpacePolicy`, `dataRedaction`, `otelCustomSpanAttributes`, `workflowReviews`. `provisioning` is hard `false` in the refresh: `// temporarily disabled until this feature is ready for release` (line 563). With 1.3 true, the refresh block sets all other keys true. No hardcoded `true` object is needed. [Source: frontend.service.ts:552-588 \| 2026-10-10 \| high] |
| 2.5 | `mfa.enabled` to `true` | `frontend.service.ts:372-375,659` | exists | Refresh sets `mfa.enabled = globalConfig.mfa.enabled`. Default `true` (mfa.config.ts:7). No patch needed. `mfaEnforcement` comes from `licenseState.isMFAEnforcementLicensed()` (562). |
| 2.6 | `hideUsagePage` to `false` | `frontend.service.ts:376` | exists | `globalConfig.hideUsagePage`, default `false`. [Source: packages/@n8n/config/src/index.ts:265 \| 2026-10-10 \| high] No patch needed. |
| 2.7 | `license.environment` to `'development'` | `frontend.service.ts:377-380` | exists | Type still allows `'development'`. [Source: packages/@n8n/api-types/src/frontend-settings.ts:232 \| 2026-10-10 \| high] Purpose in v1 was to avoid the non-production banner path. In v2 the banner uses `enterprise.showNonProdBanner` (see 3.7), not this field. Low value. |
| 2.8 | `variables.limit` to `10_000` | `frontend.service.ts:381-383` and `616-619` | exists | Refresh uses `license.getVariablesLimit()`, which returns `UNLIMITED_LICENSE_QUOTA` (-1) when `getValue` is undefined. Needs the FE to treat -1 as unlimited. Verify in the UI. |
| 2.9 | `askAi.enabled`, `aiCredits.enabled`, `aiCredits.credits` to `true` / `1_000_000_000` | `frontend.service.ts:387-398` and `629-639` | exists, changed | `aiCredits.setup` is new: `!!aiAssistant.baseUrl`. `credits` = `license.getAiCredits()`, default `0` (line 637). Needs `getValue` patch to show credits. |
| 2.10 | `folders.enabled` to `true` | `frontend.service.ts:434-436` and `678` | exists | Refresh at 678 uses `license.isFoldersEnabled()`. True after 1.3. |
| 2.11 | Refresh block commented out (flags + `isAiAssistantEnabled` etc. forced) | `frontend.service.ts:528-588` | exists, changed | Do not comment it out in v2. It already yields `true` through 1.3. New in v2: `isAiBuilderEnabled` (538), `isAiGatewayEnabled` (641-651), `workerPools` (590), `workflowReviews` (664-668), `evaluationConcurrencyLimit` (546). |
| 2.12 | `team.limit` and `folders.enabled` refresh commented out | `frontend.service.ts:675,678` | exists | Line 675 uses `getTeamProjectLimit()` with default `0`. Needs `getValue` patch or a direct override. |
| 2.13 | `// import { LICENSE_FEATURES }` commented | `frontend.service.ts:4` | exists | v2 still uses `LICENSE_FEATURES` (538, 572, 582). Do not comment out. |

## Category 3: Frontend store and init (telemetry, plan flags, banner)

| ID | v1 file and hunk | v2 file:line | Status | Notes |
|---|---|---|---|---|
| 3.1 | `settings.store.ts` `isTelemetryEnabled` to `false` | `packages/frontend/@n8n/stores/src/settings.store.ts:192` | moved | Now `computed(() => settings.value.telemetry?.enabled)`. Also exported (482). Other readers: `npsSurvey.store.ts:36`, `assistant.store.ts`. [Source: settings.store.ts:192 \| 2026-10-10 \| high] If the backend sends `telemetry.enabled=false` (via `N8N_DIAGNOSTICS_ENABLED=false`), this is already false. |
| 3.2 | `components/Telemetry.vue` `isTelemetryEnabled` to `false` | `packages/frontend/editor-ui/src/app/composables/useTelemetryInitializer.ts:34-36` | replaced | The component is gone. A composable now owns the logic. It gates on `telemetry.value?.enabled`. Used in `app/App.vue`. [Source: useTelemetryInitializer.ts:34-50 \| 2026-10-10 \| high] |
| 3.3 | `isCommunityPlan` to `false` | `settings.store.ts:271` | moved | Still `planName.toLowerCase() === 'community'`. The store reads `settings.license.planName` (line 77). If 1.4/2.x gives `'Enterprise'`, this is false without a patch. |
| 3.4 | `isDevRelease` to `false` | `settings.store.ts:273` | moved | Still `releaseChannel === 'dev'`. |
| 3.5 | `folders.value.enabled = true` | `settings.store.ts:295` | moved | Reads `settings.folders?.enabled`. True after backend patch. |
| 3.6 | `eventsApi.sessionStarted` call commented | `settings.store.ts:386-388` | moved | Guarded by `fetchedSettings.telemetry.enabled`. API client is `packages/frontend/@n8n/rest-api-client/src/api/events.ts`. False with diagnostics off. |
| 3.7 | `init.ts` `NON_PRODUCTION_LICENSE` banner not pushed | `packages/frontend/editor-ui/src/app/init/index.ts:182-184` | moved | Condition `settingsStore.isEnterpriseFeatureEnabled.showNonProdBanner`. `showNonProdBanner` comes from `license.isLicensed(SHOW_NON_PROD_BANNER)` (backend line 572). With 1.3 true, it becomes TRUE and the banner shows. This is a regression risk. Fix: force `showNonProdBanner: false` in the backend refresh (v1 did the same, commented line 1348 of the diff). |
| 3.8 | `NonProductionLicenseBanner.vue` `dismissible` true | `packages/frontend/editor-ui/src/features/shared/banners/components/banners/NonProductionLicenseBanner.vue:7` | moved | Still `:dismissible="false"`. Not needed if 3.7 is fixed. |
| 3.9 | `isBelowUserQuota` commented (dead) | n/a | removed | `isBelowUserQuota` has no match in `packages/frontend`. No action. |

## Category 4: RBAC checks (frontend)

| ID | v1 file | v2 file:line | Status | Notes |
|---|---|---|---|---|
| 4.1 | `utils/rbac/checks/hasRole.ts` returns `true` | `packages/frontend/editor-ui/src/app/utils/rbac/checks/hasRole.ts:5` | moved | Import alias changed to `@n8n/stores/users.store` and `@/app/types/rbac`. Body same as v1 original. Test file `hasRole.test.ts` exists beside it and will fail if the body changes. |
| 4.2 | `hasScope.ts` returns `true` | `.../rbac/checks/hasScope.ts:4` | moved | Same. Uses `@n8n/stores/rbac.store`. Test file exists. |
| 4.3 | `isEnterpriseFeatureEnabled.ts` returns `true` | `.../rbac/checks/isEnterpriseFeatureEnabled.ts:4` | moved | Same. Test file exists. |

All three in `packages/frontend/editor-ui/src/app/utils/rbac/checks/`. Index: `index.ts` in the same folder.
Note: server-side scope checks still run. Frontend `true` only opens the UI. API calls can still return 403.

## Category 5: Router guards (frontend)

File: `packages/frontend/editor-ui/src/app/router.ts` (moved from `src/router.ts`).

| ID | v1 hunk | v2 file:line | Status | Notes |
|---|---|---|---|---|
| 5.1 | Usage page `custom` guard removed | `router.ts:622-628` | moved | Guard still reads `!settings.hideUsagePage`. Also the `/settings` redirect (607) reads `hideUsagePage`. Both pass when `hideUsagePage` is `false` (default). Patch not needed. |
| 5.2 | Community nodes: `custom` guard removed, rbac options removed | `router.ts:1073-1090` (middleware at 1076) | moved | Guard: `isCommunityNodesFeatureEnabled` = `settings.communityNodesEnabled`. v2 reads `CommunityPackagesConfig.enabled` (frontend.service.ts:328). Env controls this. v1 also removed `rbac` options. That makes the rbac check pass with no scope. Not needed if 4.2 returns `true`. |
| 5.3 | SAML onboarding `custom` guard removed | `router.ts:1105-1124` (middleware at 1112) | moved | Guard: `ssoStore.isEnterpriseSamlEnabled && !isCloudDeployment`. After 1.3, `enterprise.saml` is true, so the guard passes. Patch likely not needed. |
| 5.4 | Evaluation route `custom` guard commented | `router.ts:372-380` | removed | v2 already has `middleware: ['authenticated']` only. No patch. |

New `custom` guards in v2 that v1 never had (listed only): AI gateway credits `router.ts:~772` (needs `isAiGatewayEnabled`, which needs a baseUrl), resolvers `~794`, encryption keys `~1036` (needs module setting `rotationEnabled`).

## Category 6: AI assistant base URL

| ID | v1 hunk | v2 file:line | Status | Notes |
|---|---|---|---|---|
| 6.1 | `baseUrl` default to `https://ai-assistant.n8n.io` | `packages/@n8n/config/src/configs/ai-assistant.config.ts:9` | exists, NOT WANTED | v2 still `baseUrl: string = ''`. Decision: do not port. A non-empty `baseUrl` also flips `aiAssistant.setup`, `aiCredits.setup`, `aiBuilder.setup`, and `aiGateway.enabled` in `frontend.service.ts` (623, 638, 644, 656). Keeping it empty keeps these off. |

## Category 7: Build and Docker (deferred to the Docker phase)

| ID | v1 file and hunk | v2 file:line | Status | Notes |
|---|---|---|---|---|
| 7.1 | `scripts/dockerize-n8n.mjs` `getDockerPlatform()` forced `linux/amd64` | `scripts/dockerize-n8n.mjs:104-111` (`hostPlatform()`) | replaced | Function renamed. It already honors `DOCKER_PLATFORM`. Set the env var instead of patching. The bake file derives the platform from `BAKE_LOCAL_PLATFORM` (`docker/docker-bake.hcl:45`). [Source: scripts/dockerize-n8n.mjs:104-111 \| 2026-10-10 \| high] |
| 7.2 | `chat/package.json` heap flag on `build:vite`, `build:bundle` | `packages/frontend/@n8n/chat/package.json:9-10` | exists | Unchanged originals. Only needed if the build OOMs. `pnpm build` passed 72/72 per the brief. Low priority. |
| 7.3 | `docker/images/n8n-custom/*` (Dockerfile, build scripts, README) | none | not on master | `docker/images/` holds `engine`, `n8n`, `n8n-base`, `node-pc`, `runners`. The v1 files stay in `v1-docs/docker/images/n8n-custom/`. Port is a new task. |

## Category 8: Disable GitHub CI

| ID | v1 change | v2 state | Status | Notes |
|---|---|---|---|---|
| 8.1 | `.github/` renamed to `.bak_github/` | `.github/` exists with 234 tracked files, 111 workflow files. No `.bak_github` or `.github.bak`. | exists (not renamed) | A plain rename breaks tooling in v2. References found: `package.json:74` (`check:cubic-config`), `package.json:102` (`install-workflow-scripts`), `scripts/build-n8n.mjs:562-573` (SBOM tooling installs into `.github/scripts`), `knip.ts:68`, `lefthook.yml:46` (workflow lint glob), `.poutine.yml`, `cubic.yaml`, `packages/quality/policy/code-health/src/utils/workflow-scanner.ts`. Safer option: rename or delete only `.github/workflows/` (and keep `.github/scripts`, `.github/actions` that scripts read). Owner said yes to item 8, but R9 must pick the scope. |
| 8.2 | `.bak_github/scripts/*` copies | `.github/scripts/` has bump-versions, ensure-provenance-fields, many more | exists | Do not copy. Scripts changed in v2. |
| 8.3 | `.github/actions/setup-nodejs-github` deleted | v2 `.github/actions/` holds `build-n8n-docker`, `ci-filter`, `docker-registry-login`, `load-n8n-docker`, `run-workflow-script`, `setup-nodejs` | removed upstream | Nothing to port. |

## Counts

| Status | Count |
|---|---|
| exists (same file) | 28 |
| moved (new path, same logic) | 14 |
| replaced (new function or file) | 4 |
| removed (v2 dropped code or guard) | 3 |
| not wanted / not on master | 2 |

(Rows counted: 1.1-1.6 with 1.2a-j as 10 items, 2.1-2.13, 3.1-3.9, 4.1-4.3, 5.1-5.4, 6.1, 7.1-7.3, 8.1-8.3.)
Of these, patches still NEEDED in v2 (after the choke-point approach): 1.3, 1.4 (or `getValue` override), `License.getValue` quota defaults, 1.6 (both files), `showNonProdBanner` false, hiring banner env check, and the optional UI-only `true` overrides for category 4. Many v1 hunks (2.4, 2.5, 2.6, 2.10, 2.11, 3.3 to 3.6, 5.1 to 5.4) become no-ops.

## Suggested minimal patch set (hypothesis, for the patch plan phase)

1. `License.isLicensed()` returns `true` (covers `LicenseState` and every `isXxxEnabled()`).
2. `License.getValue()` returns a high quota for each numeric key and `'Enterprise'` for `planName`. This fixes user, variable, team project, AI credit and evaluation limits, and Insights history, in one place.
3. `License.getPlanName()` returns `'Enterprise'` (or rely on 2).
4. Insights: `getInsightsMaxHistory()` returns `-1` (both call sites already map it).
5. `frontend.service.ts`: force `showNonProdBanner: false` after the refresh.
6. Frontend rbac checks (4.1 to 4.3), optional. Update their unit tests.
7. License server egress (O1): `License.init()` creates a `LicenseManager` with `serverUrl` `https://license.n8n.io/v1` and renew-on-init. `isLicensed()` = `true` does not stop these calls. Needs a separate decision (R2). [Source: packages/cli/src/license.ts:74,106-129 | 2026-10-10 | high]

## v2-only license gates and features v1 never touched (list only)

- Boolean features not in v1: `SCIM`, `TYPE_AVAILABILITY_POLICIES`, `GIT_CONNECTIONS`, `NAMED_VERSIONS`, `CUSTOM_ROLES`, `AI_BUILDER`, `DYNAMIC_CREDENTIALS`, `PERSONAL_SPACE_POLICY`, `TOKEN_EXCHANGE`, `DATA_REDACTION`, `OTEL_CUSTOM_SPAN_ATTRIBUTES`, `WORKFLOW_REVIEWS`, `WORKER_POOLS`, `AI_GATEWAY`, `AI_GATEWAY_CLOUD_UBB`, `AI_ASSISTANT_CLOUD_UBB_ENTITLEMENT`, `BINARY_DATA_AZURE`, `EXECUTION_DATA_S3`, `EXECUTION_DATA_AZURE`, `PROJECT_ROLE_ADMIN/EDITOR/VIEWER`, `COMMUNITY_NODES_CUSTOM_REGISTRY`, `INSIGHTS_VIEW_*`. [Source: packages/@n8n/constants/src/index.ts:12-48 | 2026-10-10 | high]
- Quotas not in v1: `quota:aiGatewayBudget` (read at frontend.service.ts:648), `quota:evaluations:concurrencyLimit` (license-state.ts:287; helper at `packages/cli/src/evaluation.ee/evaluation-concurrency.helper.ts:41`).
- `LicenseState` helpers: `isTeamProjectsLicensed()` (269), `getEvaluationConcurrencyQuota()` (287), `isSsoManagedLicensed`-style combined check at line 222 (`['feat:saml','feat:oidc']`).
- Backend modules that read license: `modules/scim/` (scim-auth.middleware.ts), `modules/promotions.ee/`, `modules/type-availability-policies/` (node and credential policy checks), `modules/agents/` (builder, AI gateway), `modules/n8n-packages/` importers, `modules/instance-ai/instance-ai.adapter.service.ts`.
- Binary and execution data storage: `base-command.ts:393-444` throws if S3/Azure mode is chosen without license. Binary data stays on filesystem per the decision table, so no impact now.
- License renewal task: `packages/cli/src/license/license-renewal.task.ts`, `main-system-tasks.ts`, `license.controller.ts`.
- Frontend settings flags: `dynamicBanners` (needs `diagnostics.enabled`, frontend.service.ts:246-249), `workflowReviews`, `workerPools`, `aiGateway`, `aiBuilder`, `granularCredentialSharing`, `envFeatureFlags`, `evaluation.*Enabled`.

## Not verified

- Runtime behavior. No app was started. Every claim is from reading source.
- Whether `FrontendSettings` and its Zod schema accept `variables.limit = -1`, `aiCredits.credits` huge values, and `enterprise.projects.team.limit = -1` in the UI.
- The FE reaction to `-1` for `variables.limit` and user quota. Needs a UI check.
- Exact env var name for `hiringBanner.enabled`. Not read from `hiring-banner.config.ts`.
- Whether forcing `sso.saml/ldap.loginEnabled = true` (v1 2.1) has any effect in v2 after the refresh overwrites it. Reasoned only.
- Line numbers of the three new router `custom` guards (~772, ~794, ~1036). Read from a sed window, not individually grepped.
- Whether `license.environment='development'` has any other FE consumer. Not searched.
- Whether other FE telemetry sinks exist beyond `useTelemetryInitializer.ts` and `settings.store.ts` (for example PostHog init, `usePostHog`). R5 should cover this.
- Backend telemetry (`telemetry/index.ts`, `telemetry.event-relay.ts`) and `LicenseMetricsService` collect/send paths. Not traced here.
- Whether the `.github` rename breaks other tooling beyond the files found by grep (grep covered json, mjs, js, ts, yml, yaml only).
- Whether `pnpm build` of the chat package still needs the heap flag on this machine.
- Unit tests for patched files (hasRole, hasScope, isEnterpriseFeatureEnabled, license, license-state, frontend.service) were not run or reviewed for breakage.
