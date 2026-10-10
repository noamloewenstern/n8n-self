# R5: Telemetry, diagnostics, error reporting, trace exporters

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: Read and Grep on source only. No app was started. `.env.local` was not read. Only env key names appear here.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.

## Summary

1. One master switch exists: `N8N_DIAGNOSTICS_ENABLED`. Its default is `true`. [Source: packages/@n8n/config/src/configs/diagnostics.config.ts:17-18 | 2026-10-10 | high]
2. With the switch `false`, these paths stop: PostHog (backend and frontend), RudderStack (backend, frontend, MCP app UIs), telemetry proxy routes, pulse task, buffer flush task, dynamic banners, personalization survey, `sessionStarted` call, Instance AI LangSmith traces.
3. PostHog init skip is verified (see section 1).
4. The switch is env-only and default-on. An unset env var on any run (for example `docker run` without the key) turns all telemetry on. Patch G1 fixes this.
5. Sentry is off by default (empty DSN). Keep `N8N_SENTRY_DSN` and `N8N_FRONTEND_SENTRY_DSN` unset.
6. Three paths ignore the master switch and need other switches or a patch: version fetch in security audit (G2), signup email submit (G3), license server (G4, scope is R2).
7. Side effect of switch `false`: the Activity log (`114_instance_activity_context`) turns off unless a flag override is set (G5).
8. `packages/@n8n/telemetry` holds event definitions only. It sends nothing (section 8).

## 1. PostHog

### 1.1 Backend client: init skip verified

`PostHogClient.init()` returns before it creates the SDK client when `diagnostics.enabled` is `false`, or when `instanceAi.evalInstance` is `true`. [Source: packages/cli/src/posthog/index.ts:59-64 | 2026-10-10 | high]
The dynamic import of `posthog-node` and `new PostHog(...)` sit after that return. [Source: packages/cli/src/posthog/index.ts:66-69 | 2026-10-10 | high]
`this.postHog` stays `undefined`. Each method then does nothing:
- `track`, `groupIdentify`, `identify` use `this.postHog?.` [Source: packages/cli/src/posthog/index.ts:100,122,142 | 2026-10-10 | high]
- `fetchFlagsFromPostHog` returns empty flags when `this.postHog` is unset. [Source: packages/cli/src/posthog/index.ts:217-219 | 2026-10-10 | high]
- Env overrides from `N8N_FEATURE_FLAG_OVERRIDES` and the dedicated force flags still apply. [Source: packages/cli/src/posthog/index.ts:169,195,259-320 | 2026-10-10 | high]
- `stop()` and `setupExpressSessionContext` check `postHog` first. [Source: packages/cli/src/posthog/index.ts:73-74,85 | 2026-10-10 | high]

Call sites of `init()`: `base-command.ts` (all commands) and `server.ts` (main server). Both go through the same skip. [Source: packages/cli/src/commands/base-command.ts:256 | 2026-10-10 | high] [Source: packages/cli/src/server.ts:188 | 2026-10-10 | high]

| Item | Value |
|---|---|
| Destination | `https://ph.n8n.io` (default), project key in code default |
| Sends | Events with `distinctId`, properties, group `company`, flag evaluation requests |
| Switch | `N8N_DIAGNOSTICS_ENABLED`. Host and key have own env: `N8N_DIAGNOSTICS_POSTHOG_API_HOST`, `N8N_DIAGNOSTICS_POSTHOG_API_KEY` |
| Source | packages/@n8n/config/src/configs/diagnostics.config.ts:6-11 |

### 1.2 Frontend PostHog

- The editor always loads a stub script, `posthog.init.js`. The stub makes no network call by itself. [Source: packages/frontend/editor-ui/index.html:11 | 2026-10-10 | high]
- The stub loads `<api_host>/static/array.js` only when `window.posthog.init(...)` runs. [Source: packages/frontend/editor-ui/public/static/posthog.init.js:14-17 | 2026-10-10 | high]
- `usePostHog().init()` returns when `settings.posthog.enabled` is `false`. [Source: packages/frontend/editor-ui/src/app/stores/posthog.store.ts:218-221 | 2026-10-10 | high]
- Backend sends `posthog.enabled = diagnostics.enabled`. [Source: packages/cli/src/services/frontend.service.ts:255-263 | 2026-10-10 | high]
- Frontend `api_host` is the instance proxy `/rest/ph`, not the PostHog host. [Source: packages/cli/src/services/frontend.service.ts:261 | 2026-10-10 | high]
- Server flags still reach the store with PostHog off. This is the path for env force flags. [Source: packages/frontend/editor-ui/src/app/stores/posthog.store.ts:206-212 | 2026-10-10 | high]

### 1.3 PostHog reverse proxy

`PostHogController` proxies `/rest/ph` to `diagnostics.posthogConfig.apiHost`. Auth is skipped. [Source: packages/cli/src/controllers/posthog.controller.ts:55-80 | 2026-10-10 | high]
The server imports this controller only when `diagnostics.enabled` is `true`. [Source: packages/cli/src/server.ts:156-159 | 2026-10-10 | high]
With the switch off, the route does not exist.

## 2. Telemetry (RudderStack)

### 2.1 Backend

| Item | Value |
|---|---|
| Init | `Telemetry.init()` creates the RudderStack client only when `enabled` is `true` and the key and URL parse. [Source: packages/cli/src/telemetry/index.ts:185-218 | 2026-10-10 | high] |
| Caller | `TelemetryEventRelay.init()` returns first when `enabled` is `false`, so `telemetry.init()` is never called. [Source: packages/cli/src/events/relays/telemetry.event-relay.ts:214-217 | 2026-10-10 | high] |
| Destination | `https://telemetry.n8n.io` (default backend config) |
| Sends | `track`, `identify`, `group` events with `instance_id`, `user_id`, version, plan, counters. Fake IP `0.0.0.0` on frontend calls. |
| Switch | `N8N_DIAGNOSTICS_ENABLED`. Endpoint has own env: `N8N_DIAGNOSTICS_CONFIG_BACKEND`. |
| Guards | `track`, `group`, `identify` and the flush methods return when `rudderStack` is unset. [Source: packages/cli/src/telemetry/index.ts:227,243,448,487,525,629 | 2026-10-10 | high] |

Only one place builds the backend client (`telemetry/index.ts:210`). A second `new RudderStack` exists in `HooksService.getRudderStackClient`. That method runs only when a user-supplied external hook file calls it. [Source: packages/cli/src/services/hooks.service.ts:121-123 | 2026-10-10 | high] No hook file is configured. Risk is low.

### 2.2 Scheduled senders

| Task | What it sends | Gate |
|---|---|---|
| `TelemetryPulseTask` | `pulse` packet: plan name, trigger quota and usage, role counts, source control flags, team project count | Added to task list only if `diagnostics.enabled`. [Source: packages/cli/src/scheduling/system-tasks/main-system-tasks.ts:48-51 \| 2026-10-10 \| high] Packet body: [Source: packages/cli/src/telemetry/index.ts:252-264 \| 2026-10-10 \| high] |
| `TelemetryBufferFlushTask` | Buffered execution counts, agent metrics, Public API usage, every 6 hours | Added only if `diagnostics.enabled`. [Source: packages/cli/src/scheduling/system-tasks/instance-system-tasks.ts:12-15 \| 2026-10-10 \| high] Interval: [Source: packages/cli/src/telemetry/telemetry-buffer-flush.task.ts:14 \| 2026-10-10 \| high] |

### 2.3 Frontend

| Item | Value |
|---|---|
| Init gate | `useTelemetryInitializer` returns when `telemetry.enabled` is false. [Source: packages/frontend/editor-ui/src/app/composables/useTelemetryInitializer.ts:36-46 \| 2026-10-10 \| high] |
| Backend settings | `telemetry.config` (key, URL, proxy, sourceConfig) is built only if `enabled`. [Source: packages/cli/src/services/frontend.service.ts:173-189 \| 2026-10-10 \| high] |
| Script load | `https://cdn-rs.n8n.io/v1/ra.min.js`. Loads only inside `initRudderStack`, after the gate. [Source: packages/frontend/editor-ui/src/app/plugins/telemetry/index.ts:283-298 \| 2026-10-10 \| high] |
| Data path | Browser sends to the instance `/rest/telemetry/proxy`. The instance forwards to `telemetry.n8n.io`. [Source: packages/cli/src/controllers/telemetry.controller.ts:16-21,80-103 \| 2026-10-10 \| high] |
| Source config | Instance fetches `https://api-rs.n8n.io/sourceConfig` for the browser SDK. [Source: packages/cli/src/controllers/telemetry.controller.ts:127-140 \| 2026-10-10 \| high] |
| Routes | Controller loaded only if `diagnostics.enabled`. [Source: packages/cli/src/server.ts:156-159 \| 2026-10-10 \| high] |
| `sessionStarted` | Guarded by `fetchedSettings.telemetry.enabled`. Calls the instance API, not an external host. [Source: packages/frontend/@n8n/stores/src/settings.store.ts:386-387 \| 2026-10-10 \| high] |

Fact: R1 item 3.1 and 3.2 need no patch for diagnostics off. The flag arrives from the backend as `false`. [Source: packages/frontend/@n8n/stores/src/settings.store.ts:192 | 2026-10-10 | high]

### 2.4 MCP app UIs

`McpService.buildMcpAppTelemetryConfig()` returns a disabled config when `diagnostics.enabled` is `false`. [Source: packages/cli/src/modules/mcp/mcp.service.ts:308-319 | 2026-10-10 | high]
The MCP app UI loads RudderStack from `https://cdn-rs.n8n.io` only when `config.enabled` is `true`. [Source: packages/@n8n/mcp-apps/src/telemetry-contract.ts:13 | 2026-10-10 | high] [Source: packages/@n8n/mcp-apps/src/telemetry/index.ts:62-64 | 2026-10-10 | high]
`N8N_MCP_APPS_ENABLED=true` does not turn this back on. The two switches are independent. [Source: packages/cli/src/modules/mcp/mcp.service.ts:278,319 | 2026-10-10 | high]

## 3. Sentry and error reporting

| Path | file:line | Sends | Destination | Gate |
|---|---|---|---|---|
| Backend `ErrorReporter` | `packages/core/src/errors/error-reporter.ts:208` (`if (!dsn) return;`) and `packages/cli/src/commands/base-command.ts:125-148` | Errors, optional traces and profiles | The DSN host | `N8N_SENTRY_DSN`. Default empty. [Source: packages/@n8n/config/src/configs/sentry.config.ts:12-13 \| 2026-10-10 \| high] |
| Frontend Sentry | `packages/frontend/editor-ui/src/app/plugins/sentry.ts:61-64` | Browser errors | The DSN host | `N8N_FRONTEND_SENTRY_DSN`. Default empty. [Source: packages/@n8n/config/src/configs/sentry.config.ts:16-17 \| 2026-10-10 \| high] |
| DSN injection | `packages/cli/src/commands/start.ts:138-152` | Meta tag `n8n:config:sentry` | Browser | Same DSN setting |
| Express error handler | `packages/cli/src/abstract-server.ts:123-124` | Express errors | The DSN host | Needs Sentry init, so needs DSN |
| Task broker | `packages/cli/src/task-runners/task-broker/task-broker-server.ts:169-171` | Errors | The DSN host | `if (backendDsn)` |
| Task runner | `packages/@n8n/task-runner/src/task-runner-sentry.ts:18-21` | Runner errors | The DSN host | `if (!dsn) return`. The launcher passes `N8N_SENTRY_DSN` through. [Source: packages/cli/src/task-runners/task-runner-process-js.ts:65-66 \| 2026-10-10 \| high] |
| Log streaming Sentry destination | `packages/cli/src/modules/log-streaming.ee/destinations/message-event-bus-destination-sentry.ee.ts:1` | Event bus messages | User-set DSN | User must add a destination. None exists by default. |
| Vite Sentry plugin | `packages/frontend/editor-ui/vite.config.mts:190-208` | Source maps at build time | Sentry | Needs `SENTRY_AUTH_TOKEN` at build. Not set. [Source: packages/frontend/editor-ui/vite.config.mts:36 \| 2026-10-10 \| medium] |

No default DSN exists in the config. No patch needed. Keep both DSN env keys unset.
The `N8N_DIAGNOSTICS_ENABLED` switch does NOT gate Sentry. The DSN gates it.

## 4. License server (usage reports)

R2 owns the decision. This section lists only the telemetry-relevant facts.

- `License.init()` builds a `LicenseManager` with `server = globalConfig.license.serverUrl` (default `https://license.n8n.io/v1`). [Source: packages/cli/src/license.ts:74,106-109 | 2026-10-10 | high] [Source: packages/@n8n/config/src/configs/license.config.ts:6-7 | 2026-10-10 | high]
- Main instance gets `offlineMode = false`. Workers and webhook processes get `offlineMode = true`. [Source: packages/cli/src/license.ts:73-75,116 | 2026-10-10 | high]
- Main passes two collectors to the SDK: `collectUsageMetrics` and `collectPassthroughData`. [Source: packages/cli/src/license.ts:86-91,121-122 | 2026-10-10 | high]
- Usage metrics: active and total workflows, enabled and total users, credentials, production and manual executions, active trigger count, evaluations count. [Source: packages/cli/src/metrics/license-metrics.service.ts:11-39 | 2026-10-10 | high]
- Passthrough data: up to 1000 active workflow IDs. A code comment says the license server forwards it to telemetry. [Source: packages/cli/src/metrics/license-metrics.service.ts:42-47 | 2026-10-10 | high]
- The SDK calls both collectors in one `Promise.all` before a server call. Seen in the minified SDK only. [Source: node_modules/.pnpm/@n8n_io+license-sdk@3.3.0/node_modules/@n8n_io/license-sdk/dist/LicenseManager.js:29 | 2026-10-10 | low]
- Renewal on init uses `renewOnInit: shouldRenew`. [Source: packages/cli/src/license.ts:99,112 | 2026-10-10 | high]
- A scheduled task renews the license when `N8N_LICENSE_AUTO_RENEW_ENABLED` is `true` (default). [Source: packages/cli/src/scheduling/system-tasks/main-system-tasks.ts:36-39 | 2026-10-10 | high]
- Shutdown can send a detach call: `N8N_LICENSE_DETACH_FLOATING_ON_SHUTDOWN`, default `true`. [Source: packages/@n8n/config/src/configs/license.config.ts:17-19 | 2026-10-10 | high]
- `N8N_DIAGNOSTICS_ENABLED=false` does NOT gate any of these. (G4)
- The pulse packet also holds license data, but it is gated by the master switch. [Source: packages/cli/src/telemetry/index.ts:252-258 | 2026-10-10 | high]

Env that may reduce license traffic without a patch: `N8N_LICENSE_AUTO_RENEW_ENABLED`, `N8N_LICENSE_DETACH_FLOATING_ON_SHUTDOWN`, `N8N_LICENSE_SERVER_URL` (point to loopback). These keys are not in the list of applied flags in `IMPLEMENTATION-PROMPT.md` section 5. The initial `renewOnInit` and the usage collectors still run for a main instance unless R2 picks a code patch.

## 5. Version check, banners, templates, onboarding

| Path | file:line | Sends | Destination | Gate |
|---|---|---|---|---|
| Version list (browser) | `packages/frontend/@n8n/stores/src/versions.store.ts:142-151` | `instanceId`, current version | `https://api.n8n.io/api/versions/` | `N8N_VERSION_NOTIFICATIONS_ENABLED`. [Source: packages/@n8n/config/src/configs/version-notifications.config.ts:6-11 \| 2026-10-10 \| high] |
| What's new (browser) | `packages/frontend/@n8n/stores/src/versions.store.ts:209-216` | `instanceId`, version | `https://api.n8n.io/api/whats-new` | Needs `enabled` AND `whatsNewEnabled`. So `N8N_VERSION_NOTIFICATIONS_ENABLED=false` stops it. [Source: packages/frontend/@n8n/stores/src/versions.store.ts:211-212 \| 2026-10-10 \| high] |
| Version list (security audit) | `packages/cli/src/security-audit/risk-reporters/instance-risk-reporter.ts:160-172` | Header `n8n-instance-id`, version in URL | `https://api.n8n.io/api/versions/` (the same config key as above) | NOT gated. See G2. Call site: [Source: packages/cli/src/security-audit/risk-reporters/instance-risk-reporter.ts:42,190-196 \| 2026-10-10 \| high] |
| Dynamic banners | `packages/frontend/editor-ui/src/features/shared/banners/banners.store.ts:32-56` | Version, instance data, `publishedWorkflowCount` filter | `https://api.n8n.io/api/banners` | `N8N_DYNAMIC_BANNERS_ENABLED` AND `diagnostics.enabled`. [Source: packages/cli/src/services/frontend.service.ts:246-249 \| 2026-10-10 \| high] |
| Personalization survey | `packages/cli/src/services/frontend.service.ts:264-265` | Survey answers go to the instance | Instance only (flag shown to UI) | `N8N_PERSONALIZATION_ENABLED` AND `diagnostics.enabled`. |
| Signup email submit | `packages/frontend/@n8n/stores/src/onboarding.api.ts:4-21` | `instance_id`, `user_id`, email, `agree` | `https://api.n8n.io/api/accounts/onboarding` | Not env-gated. Runs only if the user ticks the `agree` box on the Setup or Signup form. [Source: packages/frontend/editor-ui/src/features/core/auth/views/SetupView.vue:93-97 \| 2026-10-10 \| high] [Source: packages/frontend/editor-ui/src/features/core/auth/views/SignupView.vue:127-131 \| 2026-10-10 \| high] See G3. |
| Templates | `packages/cli/src/services/frontend.service.ts:319-321`, `packages/cli/src/modules/instance-ai/workflow-templates.service.ts:29-34` | Template search and fetch | `https://api.n8n.io/api/` | `N8N_TEMPLATES_ENABLED`, `N8N_TEMPLATES_HOST`. Kept on by owner decision. |
| Community nodes | `packages/cli/src/modules/community-packages/community-node-types-utils.ts:50-51`, `community-packages.service.ts:236` | Node listing queries | `https://api.n8n.io/api/community-nodes`, `/api/package` | No env gate found here. R10 owns this. |
| MCP registry | `packages/cli/src/modules/mcp-registry/registry/mcp-registry-api.client.ts:12-14` | Registry queries | `https://api.n8n.io/api/mcp-servers` | No env gate found here. R10 owns this. |

Not-used constant: `N8N_IO_BASE_URL` in `@n8n/constants` has no importer outside its own file. [Source: packages/@n8n/constants/src/api.ts:1 | 2026-10-10 | high]

## 6. Trace exporters (Instance AI, agents, OpenTelemetry, Microsoft)

### 6.1 LangSmith in Instance AI

- No Langfuse code exists in `packages` source. Grep found only LangSmith. [Source: packages/@n8n/instance-ai/src/tracing/langsmith-tracing.ts:22 | 2026-10-10 | high]
- `isLangSmithTracingEnabled()` returns `false` first when the process env `N8N_DIAGNOSTICS_ENABLED` is the text `false`. [Source: packages/@n8n/instance-ai/src/tracing/langsmith-tracing.ts:797-800 | 2026-10-10 | high]
- This check reads `process.env` directly. It does not read `GlobalConfig`. A different config source would not stop it.
- Without that, tracing turns on if `LANGCHAIN_TRACING_V2`, `LANGSMITH_TRACING`, an API key, or an endpoint env key is set, or if a proxy config exists. [Source: packages/@n8n/instance-ai/src/tracing/langsmith-tracing.ts:802-818 | 2026-10-10 | high]
- Proxy config exists only when `AiService.isProxyEnabled()` is true. That needs a non-empty `N8N_AI_ASSISTANT_BASE_URL`. [Source: packages/cli/src/services/ai.service.ts:78 | 2026-10-10 | high] [Source: packages/cli/src/modules/instance-ai/tracing/instance-ai-tracing.service.ts:499-509 | 2026-10-10 | high]
- Feedback upload uses the same enable check. [Source: packages/@n8n/instance-ai/src/tracing/langsmith-tracing.ts:882-886 | 2026-10-10 | high]
- Result: with `N8N_DIAGNOSTICS_ENABLED=false` in the process env and no LangSmith env keys, no trace leaves the host.

### 6.2 Agent session LangSmith export

The endpoint `POST /:agentId/threads/:threadId/langsmith-export` calls `ensureEnabled()`. That throws unless `AiService.isProxyEnabled()` is true. [Source: packages/cli/src/modules/agents/agent-session-langsmith-export.service.ts:123-127 | 2026-10-10 | high] [Source: packages/cli/src/modules/agents/agent-threads.controller.ts:67 | 2026-10-10 | high]
With `N8N_AI_ASSISTANT_BASE_URL` empty, this export is off.

### 6.3 `@n8n/agents` LangSmith integration

`LangSmithTelemetry` is an SDK class. It sets `LANGCHAIN_TRACING_V2 ??= 'true'` when a caller creates it. [Source: packages/@n8n/agents/src/integrations/langsmith.ts:381 | 2026-10-10 | high]
I found no `new LangSmithTelemetry` in `packages/cli/src/modules/agents`. Grep matched only the export service. Confidence is medium (the search covered `cli/src/modules/agents` only).

### 6.4 OpenTelemetry module

Default `enabled = false`. Env key `N8N_OTEL_ENABLED`. [Source: packages/cli/src/modules/otel/otel.config.ts:9-10 | 2026-10-10 | high]
The owner sets it `false`. No gap.

### 6.5 Microsoft Agent 365 observability (new finding)

`setMicrosoftObservabilityDefaults()` sets `ENABLE_OBSERVABILITY=true` and `ENABLE_A365_OBSERVABILITY_EXPORTER=true` when they are unset. It runs at config load for every process. [Source: packages/cli/src/utils.ts:149-159 | 2026-10-10 | high] [Source: packages/cli/src/config/index.ts:13 | 2026-10-10 | high]
The consumer is the Microsoft Agent 365 node code. It starts the `ObservabilityManager` only when both env values are `true`. [Source: packages/@n8n/nodes-langchain/nodes/vendors/Microsoft/microsoft-utils.ts:338-343 | 2026-10-10 | high] [Source: packages/@n8n/nodes-langchain/nodes/vendors/Microsoft/microsoft-utils.ts:640-660 | 2026-10-10 | medium]
The exporter runs only inside a workflow that uses that node with Microsoft credentials. It is not a background sender. It ignores `N8N_DIAGNOSTICS_ENABLED`. See G6.

## 7. Other switches that touch telemetry

- `N8N_METRICS=false` turns off the Prometheus endpoint. That is a local pull endpoint, not egress. [Source: packages/cli/src/server.ts:173 | 2026-10-10 | high]
- Frontend hooks: `EXTERNAL_FRONTEND_HOOKS_URLS` loads user scripts. Not set. Out of scope.
- `inE2ETests` forces `diagnostics.enabled = false`. This does not apply to normal runs. [Source: packages/cli/src/config/index.ts:15-16 | 2026-10-10 | high]

## 8. `packages/@n8n/telemetry`

The package holds event schemas, the PostHog blacklist, redaction and a catalog CLI. The `src/index.ts` file has no `fetch`, `http` or `import` of a network client by grep. [Source: packages/@n8n/telemetry/src/index.ts:1 | 2026-10-10 | medium]
The backend and the editor import it for event names and validation only. The editor uses `POSTHOG_EVENTS_BLACKLIST`. [Source: packages/frontend/editor-ui/src/app/plugins/telemetry/index.ts:4,30-32 | 2026-10-10 | high]
No patch needed.

## 9. Gaps that need a code patch or a decision

| ID | Gap | Evidence | Proposed action |
|---|---|---|---|
| G1 | Master switch default is `true`. One missing env key (new shell, container run, CI) turns all telemetry on. Defaults also hold live keys and hosts. | diagnostics.config.ts:17-18, 6-11, 21-26 | Change `enabled` default to `false`. Optionally blank the three default endpoint strings. Update `packages/@n8n/config/test/config.test.ts:600-604` (defaults test). One commit. Defense in depth. Not required while `.env.local` is loaded. |
| G2 | Security audit fetches `api.n8n.io` versions with the instance ID. `N8N_VERSION_NOTIFICATIONS_ENABLED=false` does not stop it. | instance-risk-reporter.ts:42,160-172,190-196 | Skip `getNextVersions` when `versionNotifications.enabled` is `false`. The `catch` already handles failure. Runs only when someone runs the audit (API or CLI). Low frequency. |
| G3 | Signup email submit posts to `api.n8n.io` and has no env gate. | onboarding.api.ts:4-21; SetupView.vue:93-97 | Owner leaves the `agree` box empty. Optional patch: make `submitContactEmail` a no-op. The box is unchecked by default (checkbox field, no default value, SetupView.vue:76-80). |
| G4 | License server traffic ignores diagnostics. Usage metrics and workflow IDs go with renew calls. | license.ts:74,86-91,106-129 | R2 decides. A patch at `License.init()` can set `offlineMode` true and `renewOnInit` false, and pass empty collectors. |
| G5 | Activity log depends on diagnostics or a flag override. With diagnostics off, the relay does not start. | activity.event-relay.ts:65-69, 88-93 | If the owner wants the Activity log, set `N8N_FEATURE_FLAG_OVERRIDES` with `114_instance_activity_context` true. `overrideEnablesFlag()` then starts the relay with no PostHog. Needs a runtime check. |
| G6 | Microsoft Agent 365 exporter defaults to on and ignores the master switch. | utils.ts:149-159; microsoft-utils.ts:338-343 | Set `ENABLE_OBSERVABILITY=false` and `ENABLE_A365_OBSERVABILITY_EXPORTER=false` in env (the defaults function does not override a set value, utils.test.ts:352-358). Or never use that node. No code patch needed. |
| G7 | LangSmith guard reads `process.env.N8N_DIAGNOSTICS_ENABLED` only. | langsmith-tracing.ts:797-800 | Keep the env var set in every launch path. Do not set `LANGSMITH_*` or `LANGCHAIN_*` keys. If G1 is done, still keep the env value set, because the guard needs the literal text `false`. |

Env keys to add to `.env.local` (names only, owner decision): `N8N_LICENSE_AUTO_RENEW_ENABLED`, `N8N_LICENSE_DETACH_FLOATING_ON_SHUTDOWN`, `N8N_LICENSE_SERVER_URL`, `N8N_PERSONALIZATION_ENABLED`, `ENABLE_OBSERVABILITY`, `ENABLE_A365_OBSERVABILITY_EXPORTER`, `N8N_VERSION_NOTIFICATIONS_WHATS_NEW_ENABLED`, `N8N_FEATURE_FLAG_OVERRIDES`. I did not read `.env.local`. Some of these may be set already.

## 10. Egress map after the switch (summary)

| Host | Source | State with current flags |
|---|---|---|
| `ph.n8n.io` | PostHog | Off. |
| `telemetry.n8n.io` | RudderStack data plane | Off. |
| `cdn-rs.n8n.io` | RudderStack SDK script (editor, MCP apps) | Off. |
| `api-rs.n8n.io` | RudderStack source config | Off (route not registered). |
| `api.n8n.io` versions / whats-new | Browser fetch | Off. |
| `api.n8n.io` versions | Security audit | On when an audit runs (G2). |
| `api.n8n.io` banners | Browser fetch | Off. |
| `api.n8n.io` templates | Browser and Instance AI | On (owner choice). |
| `api.n8n.io` community nodes, packages, MCP servers, accounts/onboarding | Various | R10. Onboarding only if box ticked (G3). |
| `license.n8n.io` | License SDK | On unless R2 patch (G4). |
| Sentry hosts | Error reporting | Off (no DSN). |
| LangSmith hosts | Instance AI traces | Off (switch and no keys). |
| Microsoft observability | Agent 365 node | Off unless that node runs (G6). |

## Not verified

- Runtime behavior. No app was started. No network capture was made. R11 must confirm with a capture.
- Exact payload and endpoints of the license SDK. I read only a matched line of the minified `LicenseManager.js`. I did not read `httpRequest.js`.
- Whether `isProxyEnabled()` has other true conditions beyond the `aiAssistant.baseUrl` check and the license check at `ai.service.ts:78`.
- Whether any caller of `new LangSmithTelemetry` exists outside `packages/cli/src/modules/agents`.
- Whether `packages/@n8n/telemetry/src/index.ts` re-exports a network module. I grepped one file only.
- Whether frontend code outside the files I read calls an external host with `fetch`, `axios` or `get/post` on a full URL. The host-string grep covered literal hosts in non-test source. Computed URLs were not traced.
- Whether browser-use or computer-use gateway code contacts `n8n.cloud` or other hosts. Not searched beyond test-file matches.
- Whether `nodes-base` nodes (for example Form Trigger footer or n8n nodes) send anything to n8n hosts. Not searched.
- The Sentry Vite plugin conditions (`vite.config.mts:190-208`) were not read in full. Build-time only.
- Whether `ENABLE_OBSERVABILITY` is already set in `.env.local`. File not read, by rule.
- Whether Docker builds (later phase) pass `N8N_DIAGNOSTICS_ENABLED` into the image env. G1 would cover that case.
- Lines 640-660 of `microsoft-utils.ts` (ObservabilityManager use) were seen only in a grep window.
