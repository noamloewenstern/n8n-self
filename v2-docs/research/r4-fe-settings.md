# R4: Frontend settings (v2)

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: read source with Read/Grep. No app was started. `.env.local` was not read. No source file was edited.
This file adds to `r1-patch-map.md` (category 2 and 3). It does not repeat R1 rows. It gives flag-by-flag detail.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.

## 1. Data flow (short)

1. `initSettings()` builds the object once. All license flags start `false` or `0`. [Source: packages/cli/src/services/frontend.service.ts:169-454 | 2026-10-10 | high]
2. `getSettings()` refreshes license-derived and DB-derived fields on every call. It ends at `return this.settings`. [Source: packages/cli/src/services/frontend.service.ts:495-686 | 2026-10-10 | high]
3. `getPublicSettings()` returns a small subset (sso, enterprise saml/ldap/oidc, mfa) to unauthenticated users. [Source: packages/cli/src/services/frontend.service.ts:721-758 | 2026-10-10 | high]
4. The FE type is `FrontendSettings`. [Source: packages/@n8n/api-types/src/frontend-settings.ts:82 | 2026-10-10 | high]
5. The FE store keeps the raw object in `settings` and sets `setSettings()` on each fetch. [Source: packages/frontend/@n8n/stores/src/settings.store.ts:281-311 | 2026-10-10 | high]

Choke point (from R1): every `License.isXxxEnabled()` getter calls `License.isLicensed()`. `LicenseState.isLicensed()` calls the same provider. [Source: packages/cli/src/license.ts:319-426 | 2026-10-10 | high]
Rule for this file: "patched" means `License.isLicensed()` returns `true` (R1 patch 1.3). "Needs patch" means a flag stays wrong after that patch.

Legend for the "Source" column:
- **L** = license-derived (changes with `isLicensed()`).
- **C** = config/env-derived (no license).
- **L+C** = both must be true.
- **D** = database or runtime value.

## 2. Flag table

### 2.1 SSO

| Flag | Where computed | Source | After `isLicensed()=true` | Needs patch? |
|---|---|---|---|---|
| `enterprise.saml` | refresh: `license.isSamlEnabled()` (560). Initial `false` (343). | L | `true` | No |
| `enterprise.ldap` | refresh: `license.isLdapEnabled()` (558). Initial `false` (342). | L | `true` | No |
| `enterprise.oidc` | refresh: `licenseState.isOidcLicensed()` (561). Initial `false` (344). | L | `true` | No |
| `sso.saml.loginEnabled` | Initial `false` (278). Refresh sets `globalConfig.sso.saml.loginEnabled` only if SAML licensed (602-607). | L+C | Follows config value, not `true` | No (see R1 2.1: skip v1 patch) |
| `sso.saml.loginLabel` | Refresh: `getSamlLoginLabel()` (604). | L+D | Value from DB | No |
| `sso.ldap.loginEnabled`, `loginLabel` | Refresh from `globalConfig.sso.ldap.*` if LDAP licensed (594-599). | L+C | Follows config | No |
| `sso.oidc.loginEnabled` | Refresh from `globalConfig.sso.oidc.loginEnabled` if OIDC licensed (609-613). | L+C | Follows config | No |
| `sso.oidc.loginUrl`, `callbackUrl` | Static URLs from base URL (287-288). | C | Same | No |
| `sso.managedByEnv` | `globalConfig.instanceSettingsLoader.ssoManagedByEnv` (276). | C | Same | No |
| `userManagement.authenticationMethod` | `getCurrentAuthenticationMethod()` (272, 502). | D | Value from DB | No |

FE side:
- `app/init/index.ts` copies `enterprise.saml/ldap/oidc` into the SSO store as `isEnterprise*Enabled` and copies the `loginEnabled` values. [Source: packages/frontend/editor-ui/src/app/init/index.ts:97-100 | 2026-10-10 | high]
- SSO login buttons show only when `isXxxLoginEnabled && isEnterpriseXxxEnabled && isDefaultAuthenticationXxx`. [Source: packages/frontend/editor-ui/src/features/settings/sso/sso.store.ts:27-32 | 2026-10-10 | high]
- Result: after the patch, SSO buttons do not show until an admin configures a provider and sets it as the default method. This is correct behavior.

### 2.2 AI assistant, Ask AI, AI Builder, AI credits, AI gateway

| Flag | Where computed | Source | After `isLicensed()=true` | Needs patch? |
|---|---|---|---|---|
| `aiAssistant.enabled` | `license.isAiAssistantEnabled()` (533, 622). Initial `false` (315). | L | `true` | No |
| `aiAssistant.setup` | `!!aiAssistant.baseUrl \|\| !!process.env.N8N_AI_ANTHROPIC_KEY` (623-624). Only inside the `if (isAiAssistantEnabled)` block. | C | `false` while `baseUrl` is empty and no key env | No (by design, R1 6.1) |
| `aiAssistant.cloudUbbEnabled` | `licenseState.isAiAssistantCloudUbbEntitlementLicensed()` (625-626). | L | `true` | Check: it may change billing UI. See Not verified. |
| `askAi.enabled` | `license.isAskAiEnabled()` (535, 629-632). | L | `true` | No |
| `aiBuilder.enabled` | `license.isLicensed(AI_BUILDER)` (538, 653-654). | L | `true` | No |
| `aiBuilder.setup` | `!!aiAssistant.baseUrl \|\| !!globalConfig.aiBuilder.apiKey` (655-656). | C | `false` without key | No |
| `aiCredits.enabled` | `license.isAiCreditsEnabled()` (537, 634-635). | L | `true` | No |
| `aiCredits.credits` | `license.getAiCredits()` (637). Default `0` (`license.ts:485-487`). | L (quota via `getValue`) | `0` | Yes, only if credits must show a number. Patch `getValue` (R1 patch 2). |
| `aiCredits.setup` | `!!aiAssistant.baseUrl` (638). | C | `false` | No |
| `aiGateway` (optional key) | Set only if `globalConfig.aiGateway.enabled && isAiGatewayLicensed() && !!baseUrl` (641-651). | L+C+C | Key absent while `baseUrl` is empty | No |
| `aiGateway.budget` | `license.getValue(LICENSE_QUOTAS.AI_GATEWAY_BUDGET) ?? 0` (648). | L (quota) | `0` | Only if gateway is wanted. Not planned. |

FE gates:
- `isAiAssistantEnabled = aiAssistant.enabled && aiAssistant.setup`. So the license alone does NOT turn on the assistant UI. [Source: packages/frontend/@n8n/stores/src/settings.store.ts:118-120 | 2026-10-10 | high]
- `isAiBuilderEnabled = aiBuilder.enabled && aiBuilder.setup`. [Source: settings.store.ts:124-126 | 2026-10-10 | high]
- `isAiCreditsEnabled = aiCredits.enabled && aiCredits.setup`. [Source: settings.store.ts:160-162 | 2026-10-10 | high]
- `isAskAiEnabled = askAi.enabled` (no setup check). [Source: settings.store.ts:122 | 2026-10-10 | high]
- `isAiGatewayEnabled = aiGateway?.enabled ?? false`. [Source: settings.store.ts:170 | 2026-10-10 | high]

Note: v1 patch 2.3 and 2.9 forced `enabled` true. In v2 the FE needs `setup` too. This matches R1 decision 6.1 (keep `baseUrl` empty).

### 2.3 Folders

| Flag | Where computed | Source | After patch | Needs patch? |
|---|---|---|---|---|
| `folders.enabled` | Initial `false` (434-436). Refresh: `license.isFoldersEnabled()` (678). `isFoldersEnabled` = `isLicensed(FOLDERS)` (`license.ts:424-426`). | L | `true` | No |

FE: `setSettings` copies it to `folders.value.enabled` (295). `isFoldersFeatureEnabled = folders.value.enabled` (200). Five editor files read `isFoldersFeatureEnabled` (ProjectNavigation, ProjectHeader, WorkflowsView, useGlobalEntityCreation, SettingsPersonalView). [Source: settings.store.ts:200,295 | 2026-10-10 | high]

### 2.4 MFA

| Flag | Where computed | Source | After patch | Needs patch? |
|---|---|---|---|---|
| `mfa.enabled` | Initial `false` (373). Refresh: `globalConfig.mfa.enabled` (659). Default `true` (`mfa.config.ts:7`). | C | `true` | No |
| `mfa.enforced` | Refresh: `await mfaService.isMFAEnforced()` (662). Comment says "TODO: read from settings". | D | `false` unless an admin sets it | No |
| `enterprise.mfaEnforcement` | Refresh: `licenseState.isMFAEnforcementLicensed()` (562). | L | `true` | No |

FE: `isMFAEnforcementLicensed = enterprise.mfaEnforcement` (194-196). `isMfaFeatureEnabled = mfa.value.enabled` (198). `isMFAEnforced` is read in `getSettings` even in public mode (346). [Source: settings.store.ts:194-198,346 | 2026-10-10 | high]

### 2.5 Workflow history, diffs, named versions

| Flag | Where computed | Source | After patch | Needs patch? |
|---|---|---|---|---|
| `workflowHistory.pruneTime` | `getWorkflowHistoryPruneTime()` (403). Takes the smaller finite value of license limit and `globalConfig.workflowHistory.pruneTime` (default `-1`). | L (quota) + C | See below | Yes if `getValue` is patched wrongly |
| `workflowHistory.licensePruneTime` | `getWorkflowHistoryLicensePruneTime()` = `License.getWorkflowHistoryPruneLimit()` (404). | L (quota) | See below | Yes, see below |
| `enterprise.workflowDiffs` | Refresh: `licenseState.isWorkflowDiffsLicensed()` (581). Initial `false` (358). | L | `true` | No |
| `enterprise.namedVersions` | Refresh: `license.isLicensed(NAMED_VERSIONS)` (582). v2-only. | L | `true` | No |

Detail on prune time:
- `getWorkflowHistoryPruneLimit()` returns `getValue(WORKFLOW_HISTORY_PRUNE_LIMIT) ?? DEFAULT_WORKFLOW_HISTORY_PRUNE_LIMIT`. The default is `24` hours. [Source: packages/cli/src/license.ts:490-494 | 2026-10-10 | high] [Source: packages/@n8n/constants/src/index.ts:81 | 2026-10-10 | high]
- This is NOT `-1`. So with no license value, the history is pruned after 24 hours unless `getValue` returns `-1` for this quota key. R1 row 1.2e names `getWorkflowHistoryPruneQuota()` in `LicenseState`. That is a different function. The settings object uses the deprecated `License.getWorkflowHistoryPruneLimit()`. Patch the `getValue` seam, or this flag stays at `24`.
- The pruner reads the same helper. [Source: packages/cli/src/workflows/workflow-history/workflow-history-manager.ts:17 | 2026-10-10 | high]
- Config helper logic: `-1` license returns config value. `-1` config returns license value. Otherwise `min`. [Source: packages/cli/src/workflows/workflow-history/workflow-history-helper.ts:12-29 | 2026-10-10 | high]

FE: `WorkflowHistory.vue` reads `settings.enterprise.workflowDiffs` for the diff view. `workflowHistory.store.ts` reads `workflowHistory.licensePruneTime` and `pruneTime`. [Source: packages/frontend/editor-ui/src/features/workflows/workflowHistory/views/WorkflowHistory.vue:81 | 2026-10-10 | high] [Source: packages/frontend/editor-ui/src/features/workflows/workflowHistory/workflowHistory.store.ts:31-33 | 2026-10-10 | high]

### 2.6 showNonProdBanner

| Flag | Where computed | Source | After patch | Needs patch? |
|---|---|---|---|---|
| `enterprise.showNonProdBanner` | Initial `false` (352). Refresh: `license.isLicensed(LICENSE_FEATURES.SHOW_NON_PROD_BANNER)` (572). Feature key `feat:showNonProdBanner`. | L | `true` (regression) | **Yes.** Force `false` after the refresh. |

FE: `app/init/index.ts` pushes the `NON_PRODUCTION_LICENSE` banner when this flag is `true`. The banner is not dismissible. [Source: packages/frontend/editor-ui/src/app/init/index.ts:182-183 | 2026-10-10 | high] [Source: packages/frontend/editor-ui/src/features/shared/banners/components/banners/NonProductionLicenseBanner.vue:7 | 2026-10-10 | high] [Source: packages/@n8n/constants/src/index.ts:27 | 2026-10-10 | high]
This is the only `enterprise.*` flag that must be forced to `false`.

### 2.7 enterprise.* (full list)

All keys of `IEnterpriseSettings`. [Source: packages/@n8n/api-types/src/frontend-settings.ts:50-80 | 2026-10-10 | high]

| Key | Refresh line | Source | After patch | Needs patch? |
|---|---|---|---|---|
| `sharing` | 554 `isSharingEnabled()` | L | true | No |
| `ldap` | 558 | L | true | No |
| `saml` | 560 | L | true | No |
| `oidc` | 561 | L | true | No |
| `mfaEnforcement` | 562 | L | true | No |
| `logStreaming` | 556 | L | true | No |
| `advancedExecutionFilters` | 565 | L | true | No |
| `variables` | 567 | L | true | No |
| `sourceControl` | 569 | L | true | No |
| `auditLogs` | none (initial `false`, 350) | none | stays `false` | No refresh code exists. Not set in v2 refresh. See Not verified. |
| `externalSecrets` | 571 | L | true | No |
| `showNonProdBanner` | 572 | L | true | **Yes** (force false) |
| `debugInEditor` | 574 | L | true | No |
| `binaryDataS3` | 575 `isS3Available && isS3Selected && isS3Licensed` | L+C | false (mode is filesystem) | No |
| `workerView` | 577 | L | true | No |
| `advancedPermissions` | 579 | L | true | No |
| `workflowDiffs` | 581 | L | true | No |
| `namedVersions` | 582 | L | true | No |
| `provisioning` | 563 hard `false` | none | false | No (upstream disabled it) |
| `projects.team.limit` | 675 `getTeamProjectLimit()`; default `0` (`license.ts:498-500`) | L (quota) | `0` | **Yes**, patch `getValue` for team project quota |
| `customRoles` | 583 | L | true | No |
| `personalSpacePolicy` | 584 | L | true | No |
| `dataRedaction` | 585 | L | true | No |
| `otelCustomSpanAttributes` | 586 | L | true | No |
| `workflowReviews` | 587 | L | true | No |

FE: `isEnterpriseFeatureEnabled = settings.enterprise ?? {}` (90). The RBAC check `isEnterpriseFeatureEnabled.ts` is a separate layer (R1 4.3). [Source: settings.store.ts:90 | 2026-10-10 | high]

### 2.8 Other flags named in the task or near them

| Flag | Where computed | Source | After patch | Needs patch? |
|---|---|---|---|---|
| `hiringBannerEnabled` | `globalConfig.hiringBanner.enabled` (313). Env `N8N_HIRING_BANNER_ENABLED`, default `true`. | C | Same | No. Set the env var to `false`. [Source: packages/@n8n/config/src/configs/hiring-banner.config.ts:6-7 | 2026-10-10 | high] |
| `hideUsagePage` | `globalConfig.hideUsagePage` (376) | C | Same | No |
| `license.planName` | Refresh: `license.getPlanName()` (540) | L (via `getValue('planName')`) | `'Community'` unless `getValue` or `getPlanName` patched | **Yes** (R1 1.4) |
| `license.consumerId` | `license.getConsumerId()` (541) | D | `'unknown'` without manager | No |
| `license.environment` | Initial: `tenantId === 1 ? 'production' : 'staging'` (379) | C | Same | No (R1 2.7: low value) |
| `userManagement.quota` | `license.getUsersLimit()` (269, 501). Default `-1`. | L (quota) | `-1` | Check FE reaction to `-1` |
| `variables.limit` | Initial `0` (382). Refresh: `getVariablesLimit()` only if `isVariablesEnabled()` (616-619). | L+quota | `-1` | Check FE reaction to `-1` |
| `evaluation.quota` | `licenseState.getMaxWorkflowsWithEvaluations()` (441, 681) | L (quota) | `0` default | **Yes**, patch `getValue` (R1 1.2j) |
| `isTelemetryEnabled` (FE) | `settings.telemetry?.enabled` (settings.store.ts:192). Backend: `globalConfig.diagnostics.enabled` (174), forced `false` if frontend config is invalid (183-186). | C | Same | No. Set `N8N_DIAGNOSTICS_ENABLED=false`. |
| `isCommunityPlan` (FE) | `planName.toLowerCase() === 'community'` (settings.store.ts:271) | L (via planName) | `true` until planName patched | Follows `planName` patch |
| `posthog.enabled`, `personalizationSurveyEnabled`, `dynamicBanners.enabled` | All gated on `diagnostics.enabled` (256, 265, 248) | C | Same | No. Off with diagnostics off. |

## 3. Flags that stay wrong after `isLicensed()=true` (summary)

1. `enterprise.showNonProdBanner` becomes `true`. Force `false`.
2. `license.planName` stays `'Community'` (and FE `isCommunityPlan` stays `true`). Patch `getValue('planName')` or `getPlanName()`.
3. Numeric quotas stay at defaults: `enterprise.projects.team.limit = 0`, `aiCredits.credits = 0`, `evaluation.quota = 0`, `workflowHistory.licensePruneTime = 24`, `workflowHistory.pruneTime = 24`. Fix with `License.getValue()`.
4. AI assistant, builder and credits UI stay off by design (`setup = false`). Keep `baseUrl` empty (R1 6.1).
5. `enterprise.auditLogs` stays `false`. No v2 refresh line sets it.

## 4. v2-only flags that v1 lacked

"v1 lacked" is based on R1 (v1 initial object listed `apiKeyScopes` and `workflowHistory` under `enterprise`, and not the keys below). I did not diff against a v1 tree in this task. See Not verified.

In `enterprise.*`: `namedVersions`, `provisioning`, `customRoles`, `personalSpacePolicy`, `dataRedaction`, `otelCustomSpanAttributes`, `workflowReviews`. [Source: frontend.service.ts:359-370 | 2026-10-10 | high]

Top-level `FrontendSettings` keys that are new or moved in v2 (all in `initSettings()`):
- `settingsMode`, `previewMode` (193-194, 198)
- `endpointMcp`, `endpointMcpTest`, `endpointHealth`, `healthCheckTimeoutMs` (202-203, 207-208)
- `evaluationConcurrencyLimit` (226)
- `jwksUri` (238)
- `dynamicBanners` (246-252)
- `logStreaming.managedByEnv`, `sso.managedByEnv`, `communityNodesManagedByEnv` (292, 276, 330)
- `dataTables` (294)
- `workflowTagsDisabled`, `workflowsAutosaveDisabled`, `workflowsGroupsWithTriggersEnabled`, `workflowsGroupsWithManyBoundariesEnabled`, `useWorkflowPublicationService` (305-310)
- `granularCredentialSharing` (311)
- `aiAssistant.cloudUbbEnabled` (317)
- `aiBuilder`, `aiCredits.setup`, optional `aiGateway` (390-398, 646)
- `ai.allowSendingParameterValues` (399-401)
- `chatTrigger.disablePublicChat` (430)
- `workerPools` (437)
- `evaluation.collectionsEnabled`, `configEvalsEnabled`, `agentEvalsEnabled`, `forceAgentWorthTesting` (442-445)
- `activeModules`, `canvasOnly`, `collaboration.crdt` (447-451)
- `envFeatureFlags`, `expressionEngine` (452-453)
- optional `workflowReviews` policy object (664-668)

[Source: packages/cli/src/services/frontend.service.ts:193-454 | 2026-10-10 | high]

New license feature keys that feed these: see the list in `r1-patch-map.md` ("v2-only license gates").

## 5. FE store notes (`settings.store.ts`)

- `planName` default is `'Community'` when `settings.license.planName` is missing. [Source: settings.store.ts:77 | 2026-10-10 | high]
- `mfa` and `folders` live in two separate refs (64-65), set in `setSettings` (294-295). Both default `false` before the first fetch.
- `getSettings()` calls `eventsApi.sessionStarted` only when `telemetry.enabled` (386-388).
- `isDevRelease` reads `releaseChannel === 'dev'` (273). Config-derived. No license link.
- No FE flag in this store reads `showNonProdBanner`. The banner logic is in `app/init/index.ts:182`.
- The FE does its own `true` overrides only in the RBAC checks (R1 category 4). It does not override `settings.*`.

## 6. Test files that fix these values

`frontend.service.test.ts` mocks `getWorkflowHistoryPruneTime` and `getWorkflowHistoryLicensePruneTime` to `24`. Test defaults for `showNonProdBanner: false` are in `frontend-test-utils/src/defaults.ts:42` and `editor-ui/src/__tests__/mocks.ts:281`. A patch to `frontend.service.ts` needs a check against `packages/cli/src/services/__tests__/frontend.service.test.ts`. [Source: packages/cli/src/services/__tests__/frontend.service.test.ts:29-30 | 2026-10-10 | high]

## Not verified

- Runtime output of `GET /rest/settings`. Everything is from source reading.
- FE behavior for `userManagement.quota = -1`, `variables.limit = -1`, `projects.team.limit = -1` (unlimited marker) in the UI. R1 lists the same gap.
- Whether `getValue()` returning a number for `quota:workflowHistoryPrune` of `-1` reaches `pruneTime` correctly. Logic read, not run.
- Why `enterprise.auditLogs` has no refresh line in v2. I did not search for another writer of this key (for example in a module).
- Whether `aiAssistant.cloudUbbEnabled = true` changes any billing UI. I did not search FE consumers.
- Whether v1 lacked each v2-only key. R1 and the v2 source were used. `v1-docs/custom-full.diff` was not re-read for this list.
- Line numbers for `license.ts:319-426` getters were checked only for the getters grepped (319-321, 329-351, 379, 424). Others in that range were not individually opened.
- Whether other FE files read `settings.enterprise.*` flags with a second license check (for example `useEnvFeatureFlag`). Not searched.
- Unit tests for `frontend.service.ts` were not run or opened beyond lines 29-30.
