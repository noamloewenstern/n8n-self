# R2: How v2 gates features, and every license network call

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: read the source with Read and Grep. Read the minified license SDK (`@n8n_io/license-sdk` 3.3.0) with a read-only script. No source file was edited. `.env.local` was not read. No app was started.
Builds on `r1-patch-map.md`. R1 content is not repeated. Section 9 corrects two R1 items.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.
SDK path: `packages/cli/node_modules/@n8n_io/license-sdk/dist/LicenseManager.js`. It is one minified line, so SDK citations name the method, not a line.

## 1. Summary

1. The only code that talks to the license server is the SDK (`LicenseManager`). It has two outbound requests: `POST {server}/activate` and `POST {server}/renew`. [Source: LicenseManager.js (methods `activate`, `_renew`) | 2026-10-10 | high]
2. The SDK posts through its own `undici` client. It does not use n8n `OutboundHttp`. [Source: license-sdk/dist/httpRequest.js (`postRequest`) | 2026-10-10 | high]
3. With NO cert in the database, NO `N8N_LICENSE_CERT`, and NO `N8N_LICENSE_ACTIVATION_KEY`, the SDK sends nothing on init, on the renewal task, or on shutdown. See section 3.
4. Three user-triggered REST routes still send requests: `/license/activate`, `/license/renew` (only if a cert exists), and two `enterprise.n8n.io` routes. They need a code patch.
5. The SDK cannot be fooled with a fake cert. It checks an X.509 chain against an approved issuer. So the bypass must be in n8n code (`License` class). [Source: LicenseManager.js (`loadCert`: "cert was not issued by an approved issuer") | 2026-10-10 | high]
6. Blanket `isLicensed() = true` has two inverted flags. `feat:apiDisabled` would DISABLE the public API. `feat:showNonProdBanner` would show the banner. See section 6.
7. Numeric quotas must return exactly `-1` (unlimited) in 4 places. A "big number" such as `10_001` BREAKS them. See section 7. This corrects R1 items 1.2a and the `getValue` plan.

## 2. Gate architecture (v2)

| Layer | What it does | Source |
|---|---|---|
| `License` (cli) | Owns the SDK `LicenseManager`. Implements `LicenseProvider`. `isLicensed()` asks the manager. `getValue()` asks the manager. | license.ts:40, 301-303, 432-434 |
| `LicenseState` (backend-common) | Thin wrapper. `isLicensed()` calls `provider.isLicensed()`. An array means "any of". `getMax*()` call `getValue()` with a default. | license-state.ts:33-51, 233-289 |
| `LicenseState` provider wiring | `initLicense()` calls `license.init()`, then `setLicenseProvider(license)`. | base-command.ts:545-549 |
| Module registry | A module with `licenseFlag` starts only if `licenseState.isLicensed(flag)` is true. Checked ONCE at startup. | module-registry.ts:208-213 |
| `@Licensed(feature)` controller decorator | Adds a middleware. It returns 403 "Plan lacks license for this feature" if `license.isLicensed(feature)` is false. | controller.registry.ts:252-260 |
| Public API `isLicensed` middleware | Same, with `FeatureNotLicensedError`. | global.middleware.ts:185-190 |
| Role gating | `RoleService.isRoleLicensed()` maps roles to `isProjectRole*Licensed`, `isCustomRolesLicensed`, `isAdvancedPermissionsLicensed`. | role.service.ts:471-493 |
| Frontend settings | Backend sends `settings.enterprise.*`, `settings.license.planName`, quota fields. | frontend.service.ts:540-588, 616-681 |
| FE `isEnterpriseFeatureEnabled` | Reads `settingsStore.isEnterpriseFeatureEnabled[feature]`. That is `settings.enterprise`. | isEnterpriseFeatureEnabled.ts:15-17, settings.store.ts:90 |
| FE `hasScope` | Reads `rbacStore.hasScope(...)`. Scopes come from the server. | hasScope.ts:11-19 |
| FE `hasRole` | Compares the current user role with the list. Returns `false` with no user. | hasRole.ts:5-15 |

Notes:
- `LicenseState` throws `ProviderNotSetError` if the provider is not set. [Source: license-state.ts:22-24 | 2026-10-10 | high]
- The deprecated `License.isXxxEnabled()` getters call `License.isLicensed()`. [Source: license.ts:313-426 | 2026-10-10 | high]
- Direct callers of `License.isLicensed()` skip `LicenseState`: `controller.registry.ts:254`, `global.middleware.ts:187`, `instance-ai.adapter.service.ts:960,965,1054,1135,1989,4146`, `frontend.service.ts:572`. So the patch point must be `License.isLicensed()`, not `LicenseState`. [Source: grep results | 2026-10-10 | high]
- FE checks are UI only. Server-side `@GlobalScope`, `@ProjectScope` and `@Licensed` still run. [Source: controller.registry.ts:252-262 | 2026-10-10 | high]
- Module `licenseFlag` is not re-checked after `license.reload()`. Patch `isLicensed()` before `initModules()`. It runs before in `start.ts` because `initLicense()` is at line 249. [Source: start.ts:249 | 2026-10-10 | high]

## 3. Every license network call (O1)

Server URL: `LicenseConfig.serverUrl`, env `N8N_LICENSE_SERVER_URL`, default `https://license.n8n.io/v1`. [Source: packages/@n8n/config/src/configs/license.config.ts:6-7 | 2026-10-10 | high]
The SDK sets `server ?? "https://license.n8n.io/v1"`. An empty string is NOT nullish, so `''` would stay empty and every request would fail with an invalid URL (no egress). [Source: LicenseManager.js constructor | 2026-10-10 | medium]

### 3.1 Calls to `license.n8n.io` (SDK)

| # | Call | Where it starts | Trigger | Needs a cert? | Bypass: what to return locally |
|---|---|---|---|---|---|
| N1 | `POST {server}/renew` (cause `startup`) | `new LicenseManager({... renewOnInit: shouldRenew ...})` then `manager.initialize()` at license.ts:106-129. `shouldRenew` is set at license.ts:99. SDK `_doInitialization` calls `renewalCron({force:true})` when `isInitialRenewalRequired()`. | Process start on a main leader or a CLI command. Only if `autoRenewalEnabled`, a cert exists, and the cert is due or has detached entitlements. | Yes | Nothing. Do not create the manager (skip `init`). No request is sent. |
| N2 | `POST {server}/renew` (cause `auto`) | `LicenseRenewalTask.run()` calls `license.renewIfDue()`. license-renewal.task.ts:36-38. `renewIfDue` is at license.ts:265-267. | System task every `AUTORENEWAL_INTERVAL` (task schedule at license-renewal.task.ts:16). The task is registered only if `autoRenewalEnabled`. main-system-tasks.ts:36-39. | Yes (`isRenewalDue()` is false with no cert) | Nothing. Set `autoRenewalEnabled=false` (`N8N_LICENSE_AUTO_RENEW_ENABLED=false`) or make `renewIfDue` a no-op. |
| N3 | `POST {server}/renew` (cause `request`) | `license.renew()` at license.ts:269-276, called by `LicenseService.renewLicense()` at license.service.ts:180-193, called by controller `POST /license/renew` at license.controller.ts:71-76. | User presses "Renew" on the Usage page. FE: usage.ts:21. | Yes. With no cert the SDK throws "renewal failed because current cert is not initialized" before any request. | Return success with local data. Do not call the SDK. |
| N4 | `POST {server}/renew` (cause `shutdown`, `detachFloatingEntitlements: true`) | `License.shutdown()` calls `manager.shutdown()` at license.ts:287-299. SDK `detachFloatingEntitlements`. | Process stop. Only if `detachFloatingOnShutdown` (default true, license.config.ts:18-19), not multi-main (license.ts:114-115), and the cert has a floatable entitlement. | Yes | Nothing. No manager means `shutdown()` returns at license.ts:293-295. |
| N5 | `POST {server}/renew` (clear) | `license.clear()` at license.ts:278-285. Called by CLI `license:clear` (commands/license/clear.ts:18-19). Same detach step as N4. | Operator runs `n8n license:clear`. | Yes | Nothing. `clear()` returns if there is no manager. |
| N6 | `POST {server}/activate` (startup) | `initLicense()` at base-command.ts:551-567. It calls `license.activate(activationKey)` at line 562. | Start with `N8N_LICENSE_ACTIVATION_KEY` set and an empty cert. Skipped if a cert exists (base-command.ts:554-558). | No | Nothing. Make `activate()` a no-op. Also leave the env var unset. |
| N7 | `POST {server}/activate` (UI) | `license.activate()` at license.ts:235-244, via `LicenseService.activateLicense()` at license.service.ts:136-160, via controller `POST /license/activate` at license.controller.ts:59-69. | User enters a key on the Usage page. FE: usage.ts:17. | No | Do not call the SDK. Return local data (see 3.3). |
| N8 | Usage data inside N1-N5 payloads | `collectUsageMetrics` (license.ts:86-88, 121) and `collectPassthroughData` (license.ts:89-91, 122). Source: license-metrics.service.ts:11-48. | Sent in every `/renew` body: workflow, user, credential and execution counts, and up to 1000 active workflow IDs. | n/a | Nothing is sent when N1-N5 are removed. The `LicenseMetricsService` class can stay. |

SDK request bodies, for reference. `/activate` body: `reservationId`, `tenantId`, `productIdentifier`, `deviceFingerprint`, optional `eulaUri`, `email`, `consumerId`, `renewalToken`. `/renew` body: `consumerId`, `tenantId`, `deviceFingerprint`, `productIdentifier`, `renewalToken`, `detachFloatingEntitlements`, `cause`, `usageMetrics`, `passthroughData`. [Source: LicenseManager.js (`activate`, `_renew`) | 2026-10-10 | high]
Request timeout: 10 s. [Source: LicenseManager.js | 2026-10-10 | high]
Proxy: the SDK reads `http_proxy_license_server`, `https_proxy_license_server`, `http_proxy`, `https_proxy`, `no_proxy`. [Source: license-sdk/dist/httpRequest.js | 2026-10-10 | high]

### 3.2 Calls that do NOT start

| Item | Why no request | Source |
|---|---|---|
| SDK internal renewal timer | `autoRenewTimer: false`. n8n schedules renewals with the system task (N2). | license.ts:111 |
| Worker and webhook instances | `offlineMode = !isMainInstance`. The SDK throws on activate and renew in offline mode. | license.ts:75, 116; LicenseManager.js |
| `license.reload()` | Calls `reloadStoredCert()`. It reads the stored cert. It never renews. | license.ts:246-262; LicenseManager.js (`reloadStoredCert`) |
| `onExpirySoon` callback | Calls `reload()`. No network. | license.ts:566-580 |
| `getManagementJwt()` etc. | Read the loaded cert only. | license.ts:436-441 |
| Init with no cert | `loadCert('')` sets `licenseCert = undefined`. `isInitialRenewalRequired()` is false (no cert). | LicenseManager.js (`initCert`, `isInitialRenewalRequired`) |

### 3.3 Calls to `enterprise.n8n.io` (not the license SDK)

| # | Call | Where | Trigger | Bypass: local value |
|---|---|---|---|---|
| E1 | `POST https://enterprise.n8n.io/enterprise-trial` | license.service.ts:70-83. Controller `POST /license/enterprise/request_trial` at license.controller.ts:26-41, scope `license:manage`. FE: usage.ts:27. | User requests a trial. | Throw `Error('Disabled on this instance')`. The controller turns it into `BadRequestError` (license.controller.ts:31-39). Send nothing. |
| E2 | `POST https://enterprise.n8n.io/community-registered` | license.service.ts:85-126. Controller `POST /license/enterprise/community-registered` at license.controller.ts:43-57. FE: usage.ts:37. | User registers the community edition by email. | Throw `BadRequestError`. Send nothing. Do not emit `license-community-plus-registered`. |

Both use `outboundHttp.requests({ useDefaultSsrfPolicy: 'unsafe' })`. [Source: license.service.ts:38-41 | 2026-10-10 | high]
These hosts are hard-coded. No env var changes them.

### 3.4 Local values when the license is bypassed

Rule: when the manager does not exist, these are the values that n8n already returns. They are the safe "local" values.

| Method | Value | Source |
|---|---|---|
| `getManagementJwt()` | `''` | license.ts:436-439 |
| `getConsumerId()` | `'unknown'` | license.ts:463-465 |
| `getCurrentEntitlements()` | `[]` | license.ts:428-430 |
| `getMainPlan()` | `undefined`. Then `planId: ''` in `getLicenseData()`. | license.ts:446-461; license.service.ts:64 |
| `getExpiryDate()`, `getTerminationDate()` | `null` | license.ts:506-520 |
| `loadCertStr()` | `''` (DB key `SETTINGS_LICENSE_CERT_KEY` empty) | license.ts:160-173 |
| `isCertValid()`, `hasFeatureInCert()` | `false` | license.ts:305-311 |
| `getInfo()` | `'n/a'` | license.ts:552-558 |
| `activate()`, `renew()`, `clear()`, `renewIfDue()` | return without work | license.ts:238-240, 270-272, 279-281, 266 |

The e2e test controller replaces `isLicensed`, `getValue` and `getPlanName` on the `License` instance. It proves these three methods are the full seam. [Source: e2e.controller.ts:215-229 | 2026-10-10 | high]
Warning: that test code returns `-1` for any non-numeric key, so `getValue('planName')` gives `-1` there. A real patch must return `'Enterprise'` for `planName`. [Source: e2e.controller.ts:218-226 | 2026-10-10 | high]

### 3.5 Two ways to stop the egress

- Option A. Config only. No cert, no `N8N_LICENSE_ACTIVATION_KEY`, `N8N_LICENSE_AUTO_RENEW_ENABLED=false`, `N8N_LICENSE_SERVER_URL` set to a dead local URL. This covers N1, N2, N4, N5, N6. It does NOT cover N3, N7, E1, E2 (user routes). The brief says env alone is not enough. [Source: IMPLEMENTATION-PROMPT.md:87 | 2026-10-10 | high]
- Option B. Code. In `License.init()`, do not create `LicenseManager`. Log one debug line. Then every manager call is already guarded by `if (!this.manager)`. Add no-ops for `activate` and `renew`, and throws for E1 and E2. Add the `isLicensed` and `getValue` overrides in section 6 and 7. Also set the config default `serverUrl` to `''` as a second barrier. This covers all 12 calls.
- Caution for Option B: `initLicense()` still calls `loadCertStr()` (base-command.ts:554) only when an activation key is set. Fine.
- Caution: `license.test.ts` mocks `LicenseManager` and expects the constructor call (license.test.ts:49-94). Tests will fail and need an update. [Source: license.test.ts:49-94 | 2026-10-10 | medium]

## 4. Other cert consumers (not the license server)

These read the cert. They send it to OTHER hosts. With the cert empty and `aiAssistant.baseUrl` empty, they stay off.

| Consumer | What it does | Gate | Source |
|---|---|---|---|
| `AiService.init()` | Builds `AiAssistantClient` with `licenseCert` and `consumerId`. | `isAiAssistantEnabled()`. After a bypass this is TRUE. The client is built with `baseUrl ''`. | ai.service.ts:31-57 |
| `AiService.isProxyEnabled()` | Needs license AND non-empty `baseUrl`. | `baseUrl` | ai.service.ts:76-79 |
| `AiGatewayService.isEnabled()` | Needs license AND `aiGateway.enabled` (default true) AND non-empty `baseUrl`. | `baseUrl` | ai-gateway.service.ts:71-77; ai-gateway.config.ts:10-11 |
| `FreeAiCreditsService.isEligible()` | Needs `aiCredits` licensed AND `baseUrl`. | `baseUrl` | free-ai-credits.service.ts:28-35 |
| `AiWorkflowBuilderService` | Reads `loadCertStr()` and `getConsumerId()`. | Not traced. | ai-workflow-builder.service.ts:92-104 |
| `InstanceReportingModule` | Opt-in module. Needs a receiver URL AND (auth token OR a cert). With an empty cert it logs a warning and sends nothing. | `N8N_ENABLED_MODULES` | instance-reporting.module.ts:34-42, 98-105 |

Keep `aiAssistant.baseUrl` empty. R1 category 6 already says this.

## 5. `isLicensed()` gates by v2 area (what a blanket `true` opens)

Backend modules with `licenseFlag`. All open when `isLicensed()` is true. Each is checked once at startup (module-registry.ts:210).

| Module | Flag | Source |
|---|---|---|
| workflow-reviews | `WORKFLOW_REVIEWS` | workflow-reviews.module.ts:9 |
| ldap | `feat:ldap` | ldap.module.ts:4 |
| dynamic-credentials | `DYNAMIC_CREDENTIALS` | dynamic-credentials.module.ts:16 |
| type-availability-policies | `TYPE_AVAILABILITY_POLICIES` | type-availability-policies.module.ts:16 |
| token-exchange | `TOKEN_EXCHANGE` | token-exchange.module.ts:9 |
| source-control | `feat:sourceControl` | source-control.module.ts:7 |
| scim | `feat:scim` | scim.module.ts:10 |
| sso-saml | `feat:saml` | sso-saml.module.ts:5 |
| sso-oidc | `feat:oidc` | sso-oidc.module.ts:5 |
| log-streaming | `LOG_STREAMING` | log-streaming.module.ts:15 |
| provisioning | any of oidc, saml, ldap | provisioning.module.ts:7 |
| external-secrets | `feat:externalSecrets` | external-secrets.module.ts:5 |
| promotions | `GIT_CONNECTIONS` | promotions.module.ts:9 |

Other gates that use `isLicensed`/`LicenseState` and open with `true`:
- `insights` controller (`feat:insights:viewDashboard`): insights.controller.ts:42, 64. Settings: insights.settings.ts:17-18, 29.
- `mfa.service.ts:46, 61` (`isMFAEnforcementLicensed`).
- `redaction` (`isDataRedactionLicensed`): redaction-context-hook.ts:53; execution-redaction.service.ts:416.
- `otel` custom span attributes: otel-lifecycle-handler.ts:241.
- `provisioning` controllers: provisioning.controller.ee.ts:22, 32; role-mapping-rule.controller.ee.ts:42-111.
- `n8n-packages` importers (folders, project role admin, variables): project-importer.ts:153; workflow-package-importer.ts:186; project-package-importer.ts:344; import-gates.ts:34.
- `community-packages` custom registry: community-packages.service.ts:500.
- `mcp`: mcp-protected-resource.ts:88; mcp.service.ts:1003; search-projects.tool.ts:98.
- `instance-ai` adapter: instance-ai.adapter.service.ts:960, 965, 1054, 1135, 1989, 4146.
- `user.service.ts:545`: global admin role invite needs `isAdvancedPermissionsLicensed()`.
- `variables.service.ee.ts:192`: `isVariablesLicensed()`.

Confidence: high for file:line (read this session). Medium for the claim "v1 never touched these" (taken from R1, which read the v1 diff).

## 6. Gates that `isLicensed() = true` does NOT open, or opens WRONG

### 6.1 Inverted flags (a blanket `true` is harmful)

| Flag | Effect of `true` | Required value | Source |
|---|---|---|---|
| `feat:apiDisabled` | `License.isAPIDisabled()` is true. `isApiKeyAuthEnabled()` is false. API-key routes return 404. `settings.publicApi.enabled` is false. The API-key auth strategy abstains. | `false` | license.ts:393-396; public-api/index.ts:420-422; api-keys.controller.ts:26-31; api-key-auth.strategy.ts:87; frontend.service.ts:298 |
| `feat:showNonProdBanner` | The "non-production license" banner shows. R1 item 3.7 found this. | `false` | frontend.service.ts:572; init/index.ts:182-184 |

The patch must be: `isLicensed(f) = f !== 'feat:apiDisabled' && f !== 'feat:showNonProdBanner'`.
R1 did not list `feat:apiDisabled`. This is a new finding.

### 6.2 Plan-name checks

| Check | Result when `planName` is `'Community'` | Result with `'Enterprise'` | Source |
|---|---|---|---|
| `renewLicense()` early return | Returns at once (no renew) | Calls `license.renew()` (see N3) | license.service.ts:181 |
| `resolveEvaluationConcurrencyLimit()` | Tier default 1 | Tier default 5 (`Enterprise: 5`). Unknown names fall back to 1. | evaluation-concurrency.helper.ts:11-15, 75-76 |
| FE `isCommunityPlan` | true | false | settings.store.ts:271 |
| FE Usage page `isCommunity`, `'registered community'` | Shows upgrade UI | Shows plan badge | SettingsUsageAndPlan.vue:72, 75 |
| FE `usage.store` default | `DEFAULT_PLAN_NAME` | uses given name | usage.store.ts:33, 45 |
| Telemetry plan fields | `Community` | `Enterprise` | telemetry/index.ts:253; telemetry.event-relay.ts:1827, 1916 |

`getPlanName()` reads `getValue('planName') ?? 'Community'`. [Source: license.ts:502-504 | 2026-10-10 | high] So `getValue` must return `'Enterprise'` for `planName`, or `getPlanName()` must be patched.

### 6.3 Cloud checks

`globalConfig.deployment.type === 'cloud'` is a separate flag, not a license gate. Default is not cloud. No license patch changes it. Do NOT set it to `cloud`. Cloud-only effects (sample): `server.ts:183`, `posthog/index.ts:74`, `instance-ai-settings.service.ts:324-325`, `agent-budget-alert.service.ts:34`, `concurrency-control.service.ts:238`. [Source: grep results | 2026-10-10 | high]
FE `cloudPlanStore` is cloud-only (`useGlobalEntityCreation.ts:575`). It is not reached on self-hosted.

### 6.4 Gates not opened by a license flag

| Gate | What else it needs | Source |
|---|---|---|
| SCIM routes | DB setting `scim.provisioning.enabled` must be `'true'` (set by an admin in the UI) | scim-settings.service.ts:6, 20-29; scim-auth.middleware.ts:29 |
| AI assistant, AI credits, AI gateway, AI builder `setup` | Non-empty `aiAssistant.baseUrl` (R1 item 6.1) | ai.service.ts:76-79; ai-gateway.service.ts:71-77; free-ai-credits.service.ts:31 |
| `binaryDataS3`, `executionDataS3/Az` settings | Mode must also be chosen: `isS3Available && isS3Selected && isS3Licensed` | frontend.service.ts:575 |
| `provisioning` setting | Hard-coded `false` in the refresh block ("temporarily disabled") | frontend.service.ts:563 (R1 item 2.4) |
| Community nodes UI | `CommunityPackagesConfig.enabled` (env) | frontend.service.ts:328 (R1 item 5.2) |
| Instance reporting | Opt-in module plus receiver URL plus credential | instance-reporting.module.ts:34-105 |
| Dynamic banners | `diagnostics.enabled` (R1 section "v2-only") | frontend.service.ts:246-249 |
| `Licensed` module setting caches | Module `settings()` is built once at startup and cached | instance-reporting.module.ts:60 (comment); module-registry.ts:230-232 |

## 7. Numeric quotas (`getValue`): exact values needed

`getValue()` goes to the manager. With no manager it returns `undefined`. Each caller then uses its own default.

| Key | Default when `undefined` | Consumer that needs a special value | Local value to return | Source |
|---|---|---|---|---|
| `quota:users` | `-1` (`LicenseState`), `-1` (`License.getUsersLimit`) | Must equal EXACTLY `-1` in 6 places. A value like `10_001` blocks: Public API `RequiresUserQuota` (403), `validLicenseWithUserQuota` (403), invite email, signup token resolve, password reset, auth. | `-1` | license-state.ts:233-235; license.ts:469-472, 560-564; public-api-controller.registry.ts:261; global.middleware.ts:176; user.service.ts:529; auth.controller.ts:230-238; password-reset.controller.ts:97, 184 |
| `quota:activeWorkflows` | `-1` | UI/telemetry only (`getTriggerLimit`, `getMaxActiveWorkflows`) | `-1` | license.service.ts:55; telemetry/index.ts:254 |
| `quota:maxVariables` | `-1` | `getRemainingVariableQuota` returns `null` (unlimited) only when `=== -1` | `-1` | variables.service.ee.ts:183-189; frontend.service.ts:618 |
| `quota:workflowHistoryPrune` | `-1` | none found beyond telemetry | `-1` | license-state.ts:249-251 |
| `quota:maxTeamProjects` | `0` (blocks team projects) | `insertTeamProjectWithAdmin` skips the count check only when `limit === -1`. `isTeamProjectsLicensed()` is true for `-1` or `>0`. | `-1` | license-state.ts:265-272; project.repository.ts:40; project.service.ee.ts:514; frontend.service.ts:675 |
| `quota:aiCredits` | `0` | Display only (`aiCredits.credits`). `setup` needs `baseUrl`. | `0` (or any display value; no effect while `baseUrl` is empty) | license-state.ts:245-247; frontend.service.ts:634-639 |
| `quota:aiGatewayBudget` | `0` | Display only | leave `undefined` | frontend.service.ts:648 |
| `quota:insights:maxHistoryDays` | `7` | `-1` maps to `MAX_SAFE_INTEGER` in both consumers | `-1` | license-state.ts:253-255; insights.settings.ts:26-28; insights.service.ts:391-393 |
| `quota:insights:retention:maxAgeDays` | `180` | Telemetry only (R1 item 1.2g) | leave `undefined` | license-state.ts:257 |
| `quota:insights:retention:pruneIntervalDays` | `24` | Telemetry only (R1 item 1.2h) | leave `undefined` | license-state.ts:261 |
| `quota:evaluations:maxWorkflows` | `0` | `=== -1` skips the check in `assertEvaluationQuotaAvailable`. `> 0` enforces in `evaluation-config`. `=== 0` returns an error in the public evaluations controller. | `-1` | license-state.ts:274-276; evaluation-test-run.service.ts:57-58; evaluation-config.service.ts:38-39; evaluations.public.controller.ts:273 |
| `quota:evaluations:concurrencyLimit` | `undefined` | `0` and non-numbers are ignored. Falls to the tier table by plan name. | leave `undefined`. Tier `Enterprise` gives 5. Env `N8N_CONCURRENCY_EVALUATION_LIMIT` wins. | evaluation-concurrency.helper.ts:40-45, 64-77 |
| `planName` | `'Community'` | See 6.2 | `'Enterprise'` | license.ts:502-504 |

Rule for the patch: one `getValue(feature)` function. For `planName` return `'Enterprise'`. For each key in the table return the "Local value". For other keys return `undefined`.

## 8. v2-only license gates (v1 patch did not touch them)

From R1 section "v2-only license gates", re-checked here with source:
- Boolean flags added in v2: `SCIM`, `TYPE_AVAILABILITY_POLICIES`, `GIT_CONNECTIONS`, `NAMED_VERSIONS`, `CUSTOM_ROLES`, `AI_BUILDER`, `DYNAMIC_CREDENTIALS`, `PERSONAL_SPACE_POLICY`, `TOKEN_EXCHANGE`, `DATA_REDACTION`, `OTEL_CUSTOM_SPAN_ATTRIBUTES`, `WORKFLOW_REVIEWS`, `WORKER_POOLS`, `AI_GATEWAY`, `AI_GATEWAY_CLOUD_UBB`, `AI_ASSISTANT_CLOUD_UBB_ENTITLEMENT`, `BINARY_DATA_AZURE`, `EXECUTION_DATA_S3`, `EXECUTION_DATA_AZURE`. [Source: packages/@n8n/constants/src/index.ts:12-62 | 2026-10-10 | high]
- Quotas added in v2: `quota:aiGatewayBudget`, `quota:evaluations:maxWorkflows`, `quota:evaluations:concurrencyLimit`. [Source: constants/src/index.ts:71, 75-76 | 2026-10-10 | high]
- Modules with a `licenseFlag` and no v1 equivalent: `workflow-reviews`, `dynamic-credentials`, `type-availability-policies`, `token-exchange`, `scim`, `promotions`, `provisioning`. See section 5.
- Role gating by license (`RoleService.isRoleLicensed`): custom roles, project admin/editor/viewer, global admin. [Source: role.service.ts:471-493 | 2026-10-10 | high]
- Policy checks that run on workflow save and credential use: node-type-policy.check.ts:146; credential-type-policy.check.ts:230; restricted-node-types.provider.ts:41. With `true` these ENFORCE policies. They only restrict types if an admin sets policies. [Source: those files | 2026-10-10 | medium]
- Multi-main: `isMultiMainLicensed` is checked in `start.ts` (`ensureMultiMainLicensed`, lines 251-253 and 360-380). With `true` it passes. Not needed for a single instance. [Source: start.ts:228-253, 360-380 | 2026-10-10 | high]
- Enterprise gate on `evaluation.ee/`, `environments.ee/`, `sso.ee/` use `LicenseState`; same behavior.

## 9. Corrections to R1

1. R1 item 1.2a and the suggested patch 2 say `getMaxUsers()` should return `10_001`. In v2 this BREAKS user-quota gates. Return `-1`. See section 7.
2. R1 does not list `feat:apiDisabled`. A blanket `isLicensed = true` disables API keys. See section 6.1.
3. R1 item 1.2e says `getWorkflowHistoryPruneQuota` is already unlimited. Confirmed. No change.
4. R1 suggestion 7 says `isLicensed() = true` does not stop license server calls. Confirmed, and refined: with no cert the SDK sends nothing at init. The remaining calls are the user routes and any case with a cert or activation key.

## 10. Suggested patch set for O1 (hypothesis, for the patch plan)

1. `License.init()`: do not construct `LicenseManager`. Log one debug line. [license.ts:59-137]
2. `License.isLicensed(f)`: `true`, except `feat:apiDisabled` and `feat:showNonProdBanner` which return `false`. [license.ts:301-303]
3. `License.getValue(k)`: implement the section 7 table. [license.ts:432-434]
4. `License.activate()` and `License.renew()`: no-op. [license.ts:235-276]
5. `LicenseService.renewLicense()`: return early. [license.service.ts:180-193]
6. `LicenseService.requestEnterpriseTrial()` and `registerCommunityEdition()`: throw. [license.service.ts:70-126]
7. `LicenseConfig.serverUrl` default `''` and `autoRenewalEnabled` default `false`. [license.config.ts:6-11] Second barrier only.
8. `frontend.service.ts`: after the refresh block, force `enterprise.showNonProdBanner = false` (R1 item 3.7).
9. Update tests: `license.test.ts`, `license.service.test.ts`, `license-renewal.task.test.ts`, `main-system-tasks.test.ts`, `frontend.service.test.ts`. Not run here.
10. Verify (egress run): start with no cert and read the logs and the network trace. Expect zero requests to `license.n8n.io` and `enterprise.n8n.io`.

## 11. Not verified

- Runtime behavior. No app was started. No network capture was made. Every claim comes from reading source.
- The SDK is minified. Method bodies were read by splitting the text. The claim "only two outbound requests" rests on one search for `C(` in `LicenseManager.js` and on `httpRequest.js` exporting only `postRequest`. A third call hidden in a code path I did not print is unlikely but not excluded. [confidence: medium-high]
- Behavior of the SDK with `server: ''`. Reasoned from `??`, not run.
- Whether `@n8n_io/ai-assistant-sdk` `AiAssistantClient` makes a request in its constructor when `baseUrl` is empty. After a bypass `AiService.init()` builds one (ai.service.ts:44-51). Not traced. Also not traced: `AiWorkflowBuilderService` (ai-workflow-builder.service.ts:92-104).
- Whether the FE and the `FrontendSettings` schema accept `-1` for `variables.limit` and `enterprise.projects.team.limit`. (R1 has the same open item.)
- Dynamic banner request (`dynamic-banners.ts`, `banners.store.ts:50` sends `planName`) and its host. Left to R5.
- Whether other callers pass through `Container.get(License)` and call SDK methods I did not list. The grep covered `getPlanName`, `getMainPlan`, `getConsumerId`, `getManagementJwt`, `getCurrentEntitlements`, `getExpiryDate`, `getTerminationDate`, `isCertValid`, `hasFeatureInCert`, `loadCertStr`, `isWithinUsersLimit` in `.ts` and `.vue` under `packages`.
- Whether any `.ee` file outside the lists in section 5 calls `licenseState.is*` (the cli/src grep outside `modules/` was done only for quota, plan and role methods, not for every boolean). Use `r10-feature-inventory.md` for the full list.
- Whether the `Licensed` decorator on public API routes uses `LicenseState` or `License`. Read `global.middleware.ts:185-190` (`License`) only.
- The claim "v1 never had" for each gate. Taken from R1.
- Test files were not run or reviewed for breakage.
- `libs` outside `packages/` (for example `docker/` images or `scripts/`) were not searched for license URLs.
