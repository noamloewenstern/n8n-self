# R11 Egress audit (STATIC part)

Commit: `55b3f5ac9e` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: read-only grep and read of non-test source. No app run. No proxy. `.env.local` not read.
Scope: `packages/cli/src`, `packages/core/src`, `packages/@n8n/*/src`, `packages/frontend/**`, `packages/modules/**`.
Excluded: tests, `__tests__`, stories, fixtures, `packages/nodes-base`, `packages/@n8n/nodes-langchain` (user workflow nodes), docs links.
Runtime part (section 7 of IMPLEMENTATION-PROMPT) is NOT done here.

Convention: "Server" means the n8n Node process. "Browser" means the owner's browser tab. Section 4 allows `localhost` only. A browser call to a public host breaks that rule even when the server stays quiet. Cover both.

---

## 1. Result in 10 points

1. `N8N_DIAGNOSTICS_ENABLED=false` stops PostHog (server and browser), RudderStack (server and browser), `/rest/telemetry/*` and `/rest/ph/*` proxy routes, the telemetry pulse task, and dynamic banners. [Source: packages/cli/src/server.ts:156-159 | 2026-10-10 | confidence: high]
2. The browser still contacts `api.n8n.io` for version info, "What's new", templates, and the signup onboarding POST. Server-side switches do not change this. See table C.
3. The license SDK makes no network call when the instance has no stored cert and no activation key. Calls start when a cert or key exists. [Source: node_modules/.pnpm/@n8n_io+license-sdk@3.3.0/node_modules/@n8n_io/license-sdk/dist/LicenseManager.js (minified, `isInitialRenewalRequired`, `activate`, `_renew`) | 2026-10-10 | confidence: medium]
4. MCP registry client has an env switch: `N8N_DISABLED_MODULES=mcp-registry`. Section 4 says "not env-gated". This is wrong. [Source: packages/@n8n/backend-common/src/modules/module-registry.ts:82 | 2026-10-10 | confidence: high]
5. Community node listing has an env switch: `N8N_VERIFIED_PACKAGES_ENABLED=false` (server) and `N8N_COMMUNITY_PACKAGES_ENABLED=false` (browser call skipped). Section 4 says "not env-gated". This is wrong. [Source: packages/cli/src/modules/community-packages/community-node-types.service.ts:110 | 2026-10-10 | confidence: high]
6. NEW: `models.dev` is fetched by `fetch()` with no env switch. It runs on every agent run (cost lookup) and in model pickers. Needs a code patch or an owner allowlist entry. [Source: packages/@n8n/agents/src/sdk/catalog.ts:181 | 2026-10-10 | confidence: high]
7. NEW: `sdk-templates.n8n.io` is fetched by Instance AI builder. Switch: `N8N_INSTANCE_AI_TEMPLATES_DISABLED=true`. [Source: packages/@n8n/instance-ai/src/workspace/builder-templates-service.ts:57,591 | 2026-10-10 | confidence: high]
8. NEW: the community package install path always calls `api.n8n.io/api/package` and `registry.npmjs.org`. No env switch. "Install by npm name still works" means it still contacts the internet. [Source: packages/cli/src/modules/community-packages/community-packages.service.ts:236 | 2026-10-10 | confidence: high]
9. Hosts Gravatar, Google Fonts (app UI), Sentry, Daytona, Brave: no egress by default. See table D.
10. Fonts in the app UI are local files. Google Fonts appears only in email templates (the recipient mail client loads it). [Source: packages/frontend/@n8n/design-system/src/css/fonts.scss:12,20 ; packages/cli/src/user-management/email/templates/_common.mjml:2 | 2026-10-10 | confidence: high]

---

## 2. Table A: verify the "Known egress sources" rows of section 4

| # | Source (host) | file:line | Trigger | Gating switch (env key) | Verdict | Action |
|---|---|---|---|---|---|---|
| A1 | PostHog `ph.n8n.io` (server) | `packages/cli/src/posthog/index.ts:62,67`; default host `packages/@n8n/config/src/configs/diagnostics.config.ts:11` | Startup (`server.ts:188`) | `N8N_DIAGNOSTICS_ENABLED` | Verified. Row cites `:60-62`. Real lines are `:62` (guard) and `:67` (client). | env off |
| A2 | PostHog proxy route `/rest/ph` to `ph.n8n.io` | `packages/cli/src/controllers/posthog.controller.ts:63`; registered at `packages/cli/src/server.ts:156-159` | Browser sends PostHog traffic to the instance, instance forwards | `N8N_DIAGNOSTICS_ENABLED` | New detail. Route exists only when diagnostics is on. | env off |
| A3 | RudderStack `telemetry.n8n.io` (server) | `packages/cli/src/telemetry/index.ts:185-213`; default `diagnostics.config.ts:22,26`; relay guard `packages/cli/src/events/relays/telemetry.event-relay.ts:215` | Startup, then buffer flush | `N8N_DIAGNOSTICS_ENABLED`; override `N8N_DIAGNOSTICS_CONFIG_BACKEND` | New row. | env off |
| A4 | Telemetry system tasks | `packages/cli/src/scheduling/system-tasks/main-system-tasks.ts:48`; `instance-system-tasks.ts:12` | Periodic | `N8N_DIAGNOSTICS_ENABLED` | New row. Tasks are left out when diagnostics is off. | env off |
| A5 | RudderStack source config `api-rs.n8n.io` | `packages/cli/src/controllers/telemetry.controller.ts:133`; proxy target `:17` | Browser asks the instance; instance fetches | `N8N_DIAGNOSTICS_ENABLED` (route not registered when off) | New row. | env off |
| A6 | License server `license.n8n.io` | `packages/@n8n/config/src/configs/license.config.ts:7`; `packages/cli/src/license.ts:74,112,116`; SDK `/activate`, `/renew` | Startup renew (cert needed), startup activate (key needed), shutdown detach (cert needed), UI/API activate, periodic task | `N8N_LICENSE_SERVER_URL`, `N8N_LICENSE_AUTO_RENEW_ENABLED`, `N8N_LICENSE_ACTIVATION_KEY` | Partly verified. No cert and no key means no call. See section 5. | code patch per O1 (guard rails), plus env |
| A7 | License renewal task | `packages/cli/src/scheduling/system-tasks/main-system-tasks.ts:36-39`; `packages/cli/src/license/license-renewal.task.ts:37` | Periodic | `N8N_LICENSE_AUTO_RENEW_ENABLED` | New row. | env off |
| A8 | Templates `api.n8n.io/api/` (server) | `packages/@n8n/config/src/configs/templates.config.ts:11`; `packages/cli/src/modules/instance-ai/workflow-templates.service.ts:29-39` | User action (Instance AI asks for a template) | `N8N_TEMPLATES_ENABLED`, `N8N_TEMPLATES_HOST` | Verified. Server side exists too, not only browser. | allowed (owner choice) |
| A9 | Version notifications `api.n8n.io/api/versions/` | `packages/@n8n/config/src/configs/version-notifications.config.ts:11`; browser fetch `packages/frontend/@n8n/stores/src/versions.store.ts:149`; call site `packages/frontend/editor-ui/src/app/init/index.ts:231-234` | Browser, at editor start | `N8N_VERSION_NOTIFICATIONS_ENABLED` | Verified. Call comes from the BROWSER. | env off |
| A10 | Security audit version check | `packages/cli/src/security-audit/risk-reporters/instance-risk-reporter.ts:160-166,196` | User action (run audit) | `N8N_VERSION_NOTIFICATIONS_ENDPOINT` only. Not gated by `..._ENABLED`. | New row. | env: set endpoint to a localhost dummy, or accept |
| A11 | Dynamic banners `api.n8n.io/api/banners` | `packages/@n8n/config/src/configs/dynamic-banners.config.ts:7`; `packages/cli/src/services/frontend.service.ts:246-248`; browser `packages/frontend/editor-ui/src/features/shared/banners/banners.store.ts:32-36`; call `packages/frontend/editor-ui/src/app/init/index.ts:324` | Browser, at login | `N8N_DYNAMIC_BANNERS_ENABLED` (setting is `enabled AND diagnostics.enabled`) | Verified. Already off when diagnostics is off. | env off |
| A12 | Community node listing `api.n8n.io/api/community-nodes` | `packages/cli/src/modules/community-packages/community-node-types-utils.ts:50-51`; gate `community-node-types.service.ts:110`; browser trigger `packages/frontend/editor-ui/src/app/composables/useWorkflowInitialization.ts:251-254`, `nodeTypes.store.ts:462-467` | Browser opens a workflow, server fetches | `N8N_COMMUNITY_PACKAGES_ENABLED`, `N8N_VERIFIED_PACKAGES_ENABLED` | CORRECTED. Env-gated. | env off |
| A13 | MCP registry `api.n8n.io/api/mcp-servers` | `packages/cli/src/modules/mcp-registry/registry/mcp-registry-api.client.ts:13-14,87-96`; task `mcp-registry-refresh.task.ts:7,32` (every 8 h); module is default-on `module-registry.ts:82` | Periodic (8 h) plus first fill when table is empty | `N8N_DISABLED_MODULES=mcp-registry` | CORRECTED. Env-gated by module list. Startup `init()` reads the DB only (`mcp-registry.service.ts:40-42`). | env off |
| A14 | Onboarding `api.n8n.io/api/accounts/onboarding` | `packages/frontend/@n8n/stores/src/onboarding.api.ts:4-15`; callers `users.store.ts:488-496`, `SetupView.vue:93-96`, `SignupView.vue:127-130` | Browser, only if the owner ticks the "agree" box on setup/signup | None. Opt-in checkbox. | Verified, narrowed. No call unless the box is ticked. | allowed if the box stays unticked |
| A15 | OpenTelemetry | module `otel` is not in the default module list (`module-registry.ts:45-85`) | n/a | `N8N_OTEL_ENABLED`, `N8N_ENABLED_MODULES` | Not verified in depth. See section 7. | env off |
| A16 | Daytona | `packages/@n8n/config/src/configs/instance-ai.config.ts:73-86` | n/a | `N8N_INSTANCE_AI_SANDBOX_ENABLED` default `false`; `DAYTONA_API_URL` default empty | Verified. No egress by default. DB settings can override env (`instance-ai-settings.service.ts:336-352`). | leave unset |
| A17 | Brave | `instance-ai.config.ts:167-168`; client `packages/@n8n/ai-utilities/src/web-search/brave-search.ts:4` | Only when key set | `INSTANCE_AI_BRAVE_SEARCH_API_KEY` | Verified. | leave unset |
| A18 | Frontend onboarding row ("R10") | `packages/frontend/@n8n/stores/src/onboarding.api.ts:4` | see A14 | none | Answered by A14. | n/a |

---

## 3. Table B: egress sources NOT in section 4 (new)

| # | Host | file:line | Side | Trigger | Gating switch (env key) | Action |
|---|---|---|---|---|---|---|
| B1 | `models.dev` (`/api.json`) | `packages/@n8n/agents/src/sdk/catalog.ts:4,181`; once-per-process cache `:272`; cost lookup `packages/@n8n/agents/src/runtime/loop/agent-runtime.ts:1425`; pickers `packages/cli/src/modules/agents/agents-catalog.controller.ts:27`, `instance-ai/instance-ai-model-catalog.service.ts:124-125`, `agents/agent-model-catalog.service.ts:207-208`, `@n8n/instance-ai/src/tools/models/model-catalog.service.ts:139`, `mcp/tools/agents/agent-tools.service.ts:1677` | Server (plain `fetch`, not `OutboundHttp`) | Every agent or Instance AI run (cost), and model pickers | NONE found | CODE PATCH, or owner adds `models.dev` to the allowlist in writing. Decision needed. Without it, cost data is missing and the picker may fail. [confidence: high] |
| B2 | `sdk-templates.n8n.io` | `packages/@n8n/instance-ai/src/workspace/builder-templates-service.ts:57,172,589-599`; wired at `packages/cli/src/modules/instance-ai/instance-ai.adapter.service.ts:604,933-940` | Server | Instance AI builder use; refresh every 24 h (`:59`) | `N8N_INSTANCE_AI_TEMPLATES_DISABLED=true` (also `..._TEMPLATES_URL`, `..._TEMPLATES_REFRESH_HOURS`) | env off. Set it. |
| B3 | `api.n8n.io/api/package` (ban check) and `registry.npmjs.org` | `packages/cli/src/modules/community-packages/community-packages.service.ts:49,236`; caller `community-packages.lifecycle.service.ts:190`; registry default `community-packages.config.ts:17` | Server | User installs a community package | `N8N_COMMUNITY_PACKAGES_ENABLED=false` blocks all install. `N8N_COMMUNITY_PACKAGES_REGISTRY` can point to a local mirror. The ban check has no switch. | Owner decision. Section 3 says "install by npm name still works": that path leaves localhost. |
| B4 | `api.n8n.io/api/templates/*`, `/workflows/templates/*` | `packages/@n8n/ai-workflow-builder.ee/src/tools/web/templates.ts:14,70,95` | Server | AI workflow builder tool call | Builder service is created only with `N8N_AI_ASSISTANT_BASE_URL` set (`packages/cli/src/services/ai-workflow-builder.service.ts:90`). Not fully traced. | Treat as gated by empty `N8N_AI_ASSISTANT_BASE_URL`. [confidence: medium] |
| B5 | `openrouter.ai/api/v1` (builder model) | `packages/@n8n/ai-workflow-builder.ee/src/llm-config.ts:136-158` | Server | Builder run | Same as B4 | Same as B4. Owner plans OpenRouter later anyway. [confidence: medium] |
| B6 | `n8n-preview-service.internal.n8n.cloud` | `packages/@n8n/mcp-apps/src/server/constants.ts:5`; `apps/workflow-preview/utils/url.ts:10` | MCP client host (not the n8n page) | MCP app "workflow preview" is rendered by an MCP client | Not traced. | Owner decision when MCP apps are used. Section 3 turns MCP apps ON. [confidence: low] |
| B7 | `cdn-rs.n8n.io` in MCP app | `packages/@n8n/mcp-apps/src/telemetry-contract.ts:13`; `server/apps/workflow-preview.ts:49` | MCP client host | Only if diagnostics on (`resourceDomains` set only with `instanceOrigin`; contract says "When false the UI must not load RudderStack") | `N8N_DIAGNOSTICS_ENABLED` | env off. [confidence: medium] |
| B8 | `api.firecrawl.dev` | `packages/cli/src/modules/quick-connect/handlers/firecrawl.handler.ts:9` | Server | User uses Quick Connect for Firecrawl | Module `quick-connect` (`N8N_DISABLED_MODULES`) and quick-connect config. Not traced. | Optional: add `quick-connect` to the disabled list. [confidence: low] |
| B9 | `enterprise.n8n.io` | `packages/cli/src/license/license.service.ts:72,104` | Server | User asks for trial or registers a community key | None | Code path only on user action. Patch with O1 if desired. |
| B10 | Sentry `*.sentry.io` | `packages/@n8n/config/src/configs/sentry.config.ts:12,16`; init guard `packages/core/src/errors/error-reporter.ts:208` (`if (!dsn) return`); browser `packages/frontend/editor-ui/src/app/plugins/sentry.ts:61-66`; meta tag `packages/cli/src/commands/start.ts:137-153` | Server and browser | n/a | `N8N_SENTRY_DSN`, `N8N_FRONTEND_SENTRY_DSN` default empty | No egress by default. Keep both unset. |
| B11 | `api.npms.io` | `packages/@n8n/constants/src/community-nodes.ts:1` | none | Constant has no non-test user | n/a | No egress found. |
| B12 | Model discovery for each LLM provider | `packages/@n8n/ai-utilities/src/model-discovery/providers/*.ts` (OpenAI, Anthropic, OpenRouter, others) | Server | User adds a provider credential | Credential must exist | Allowed by section 4 (LLM provider added in UI). |
| B13 | `ai-assistant.n8n.io` allowed hostname | `packages/@n8n/ai-utilities/src/model-discovery/providers/openai.ts:4` | n/a | Hostname list only | n/a | No egress. |

---

## 4. Table C: browser-side egress (owner's browser, direct to the internet)

The server proxy cannot see these calls. A runtime audit must watch the browser (DevTools or proxy on the PC).

| # | Host | file:line | Trigger | Gating switch | Action |
|---|---|---|---|---|---|
| C1 | `api.n8n.io/api/versions/<ver>` | `packages/frontend/@n8n/rest-api-client/src/api/versions.ts:50-57`; `versions.store.ts:149` | Editor start | `N8N_VERSION_NOTIFICATIONS_ENABLED` | env off |
| C2 | `api.n8n.io/api/whats-new` | `versions.ts:59-68`; `versions.store.ts:209-216` | Editor start | `N8N_VERSION_NOTIFICATIONS_ENABLED` and `..._WHATS_NEW_ENABLED` | env off |
| C3 | `api.n8n.io/api/banners` | `banners.store.ts:32-60` | Login | `N8N_DYNAMIC_BANNERS_ENABLED`, diagnostics | env off |
| C4 | `api.n8n.io/api/templates/*` | `packages/frontend/editor-ui/src/features/workflows/templates/templates.store.ts:324-418` (uses `settingsStore.templatesHost`); health test `packages/frontend/@n8n/stores/src/settings.store.ts:415-420` called from `TemplatesSearchView.vue:307` | User opens Templates | `N8N_TEMPLATES_ENABLED`, `N8N_TEMPLATES_HOST` | allowed (owner choice). Hardening: host the templates API locally via `N8N_TEMPLATES_HOST`. |
| C5 | `api.n8n.io/api/accounts/onboarding` | see A14 | Owner ticks box | none | leave unticked |
| C6 | `cdn-rs.n8n.io/v1/ra.min.js` (RudderStack SDK) | `packages/frontend/editor-ui/src/app/plugins/telemetry/index.ts:288`; init guard `packages/frontend/editor-ui/src/app/composables/useTelemetryInitializer.ts:36-46` | Editor start | `N8N_DIAGNOSTICS_ENABLED` | env off |
| C7 | PostHog script `<api_host>/static/array.js` | stub `packages/frontend/editor-ui/public/static/posthog.init.js:16`, loaded at `packages/frontend/editor-ui/index.html:11`; real init `packages/frontend/editor-ui/src/app/stores/posthog.store.ts:214-221,272` | Only after `posthog.init()`. The stub makes no request. `api_host` is the instance proxy `/rest/ph` (`frontend.service.ts:261`), not `ph.n8n.io`. | `N8N_DIAGNOSTICS_ENABLED` (`posthog.enabled`) | env off. |
| C8 | `registry.npmjs.org/<pkg>` and `api.npmjs.org/downloads/...` | `packages/frontend/editor-ui/src/features/settings/communityNodes/components/nodeCreator/CommunityNodeFooter.vue:35-39`; `CommunityNodeInfo.vue:75-92` | User views a community node in the node creator | None. Only visible when community nodes are shown. | Acceptable only if community nodes stay off (`N8N_COMMUNITY_PACKAGES_ENABLED=false`) [confidence: medium] |
| C9 | `data.jsdelivr.com`, `cdn.jsdelivr.net` (TypeScript types) | `packages/frontend/editor-ui/src/features/shared/editors/plugins/codemirror/typescript/worker/npmTypesLoader.ts:9-16`; used at `typescript.worker.ts:103` for luxon types | User opens a Code node editor | None found | Code patch, or accept. Not in section 4. Decision needed. [confidence: high for the call, medium for the trigger] |
| C10 | `www.youtube.com/embed/5LlF196PKaE` iframe | `packages/frontend/editor-ui/src/features/ai/evaluation.ee/views/EvaluationsRootView.vue:183` | User opens Evaluations setup | None | Accept or patch. Also Markdown YouTube embed `packages/frontend/@n8n/design-system/src/components/N8nMarkdown/youtube.ts:24-25` renders only if sticky-note Markdown has a YouTube link. |
| C11 | `n8niostorageaccount.blob.core.windows.net` image, YouTube link | `packages/frontend/editor-ui/src/experiments/readyToRunWorkflowsV2/workflows/ai-workflow-v4.ts:80` | Only if that PostHog experiment is on (flags are off when diagnostics is off, unless forced by env) | PostHog flags | low risk |
| C12 | `img.youtube.com` thumbnails | `packages/frontend/editor-ui/src/experiments/templateRecoV2/components/YoutubeCard.vue:23` | Experiment only | PostHog flags | low risk |
| C13 | `subscription.n8n.io` | `packages/frontend/editor-ui/src/features/settings/usage/usage.store.ts:64-68` | Used as a link base (navigation). No fetch seen. | n/a | Not traced to the end. [confidence: medium] |
| C14 | `cdn.jsdelivr.net/npm/@n8n/chat/...` | `packages/frontend/editor-ui/src/app/components/ChatEmbedModal.vue:98-100` | Text of a copy-paste snippet. The app does not load it. | n/a | No egress. |

Default CSP only restricts `script-src`. It does not restrict `connect-src`. [Source: packages/@n8n/config/src/configs/content-security-policy.ts:9 | 2026-10-10 | confidence: high] Option, NOT verified: a custom `N8N_CONTENT_SECURITY_POLICY` with a strict `connect-src` could block browser egress as a safety net. It may break features. Test before use.

---

## 5. License details (input for O1 and R2)

- Server URL default: `https://license.n8n.io/v1`. Override: `N8N_LICENSE_SERVER_URL`. [Source: packages/@n8n/config/src/configs/license.config.ts:7 | 2026-10-10 | confidence: high]
- `License.init()` builds a `LicenseManager` with `renewOnInit` set when the instance is leader and `autoRenewalEnabled`. `offlineMode` is true for non-main instances. [Source: packages/cli/src/license.ts:75,78-90,112,116 | 2026-10-10 | confidence: high]
- SDK reads: `renewOnInit` needs a cert (`hasCert()`), else "Skipping renewal on init". `activate()` posts to `<server>/activate`. `_renew()` posts to `<server>/renew` with usage metrics and passthrough data. Shutdown detach calls `_renew` only if a cert has floatable entitlements. [Source: node_modules/.pnpm/@n8n_io+license-sdk@3.3.0/.../dist/LicenseManager.js | 2026-10-10 | confidence: medium. Reason: minified file read, not run.]
- Activation at startup runs only when `N8N_LICENSE_ACTIVATION_KEY` is set and no cert is stored. [Source: packages/cli/src/commands/base-command.ts:552-562 | 2026-10-10 | confidence: high]
- Result: with no key and no cert, expect ZERO license calls at startup. Calls appear if (a) the owner sets a key or cert, (b) someone presses Activate in the UI (`packages/cli/src/license/license.service.ts:143-145`), or (c) an old cert is in the DB. Check (c) in the runtime run.
- Rails (env, no code): keep `N8N_LICENSE_ACTIVATION_KEY` empty and `N8N_LICENSE_CERT` empty; set `N8N_LICENSE_AUTO_RENEW_ENABLED=false`; set `N8N_LICENSE_SERVER_URL` to a dead localhost URL (name only; value is the owner's choice).
- The patch in r1-patch-map (isLicensed = true) does not add network calls.

---

## 6. Table D: no egress by default (empty or off until the owner configures it)

| Item | Host(s) | file:line | Why quiet |
|---|---|---|---|
| AI assistant, Gateway credits, free AI credits | host from `N8N_AI_ASSISTANT_BASE_URL` | `packages/@n8n/config/src/configs/ai-assistant.config.ts:9-10`; `packages/cli/src/services/ai.service.ts:41,78`; `ai-gateway.service.ts:71-77`; `free-ai-credits.service.ts:31` | Default is empty. Features turn off. Matches decision "no hosted URL". |
| Instance AI model | `modelUrl` empty, no key | `packages/@n8n/config/src/configs/instance-ai.config.ts:13-22` | No call until a model is connected in the UI. Default model name is `anthropic/claude-opus-4-8`. |
| Instance AI web search | SearXNG URL or Brave | `instance-ai.config.ts:167-172` | Call only with a URL or key. SearXNG upstream engines are allowed (section 4). |
| Sandbox | `N8N_SANDBOX_SERVICE_URL`, Daytona | `instance-ai.config.ts:73-94` | `sandboxEnabled` default false. |
| Source control, external secrets, SSO, SMTP, log streaming, agent channels (Slack, Telegram, Teams, WhatsApp, Discord, Linear) | user-configured hosts | for example `packages/cli/src/modules/agents/integrations/platforms/telegram-integration.ts:328`, `packages/cli/src/modules/external-secrets.ee/providers/*.ts` | Call only after the owner configures the integration. |
| Email templates | `fonts.googleapis.com`, `n8n.io` link | `packages/cli/src/user-management/email/templates/_common.mjml:2`, `_logo.mjml:1` | The recipient mail client loads the font. The server does not. Only when SMTP is set. |
| App fonts, icons | local | `packages/frontend/@n8n/design-system/src/css/fonts.scss:12,20` | Local `woff2` files. |
| Gravatar | none | grep of `gravatar` in `packages/frontend`, `packages/cli/src`: 0 hits | Not used. |
| Hard-coded docs and marketing links | `docs.n8n.io`, `n8n.io`, `community.n8n.io`, `support.n8n.io`, `creators.n8n.io`, `n8n-community.typeform.com`, GitHub | `packages/frontend/editor-ui/src/app/constants/urls.ts`, `externalLinks.ts` | Links. Egress only if the user clicks. |
| Prompt text with CDN names | `cdn.tailwindcss.com`, `cdn.jsdelivr.net/npm/alpinejs` | `packages/@n8n/workflow-sdk/src/prompts/best-practices/guides/web-app.ts:54-55` | Text given to an LLM. Generated web apps would load them. Not app egress. |
| Dev scripts | `api.n8n.io`, `n8n.io` | `packages/@n8n/workflow-sdk/scripts/fetch-test-workflows.ts:11-62` | Dev tool. Not run by the app. |

---

## 7. Recommended `.env.local` switches (names only; values are `false` or `true` as the name says)

| Env key | Set to | Effect |
|---|---|---|
| `N8N_DIAGNOSTICS_ENABLED` | `false` (already) | A1-A5, C6, C7, B7, banners |
| `N8N_VERSION_NOTIFICATIONS_ENABLED` | `false` | A9, C1, C2 |
| `N8N_DYNAMIC_BANNERS_ENABLED` | `false` | A11, C3 |
| `N8N_LICENSE_AUTO_RENEW_ENABLED` | `false` | A6, A7 |
| `N8N_DISABLED_MODULES` | include `mcp-registry` | A13. Add `otel` only if it is enabled elsewhere. Add `quick-connect` for B8. |
| `N8N_VERIFIED_PACKAGES_ENABLED` | `false` | A12 (server side) |
| `N8N_COMMUNITY_PACKAGES_ENABLED` | `false` if install by name is not needed | A12 (browser side), B3, C8 |
| `N8N_INSTANCE_AI_TEMPLATES_DISABLED` | `true` | B2 |
| `N8N_TEMPLATES_ENABLED` | `true` (owner choice) | A8, C4 stay on |
| `N8N_SENTRY_DSN`, `N8N_FRONTEND_SENTRY_DSN` | unset | B10 |
| `N8N_AI_ASSISTANT_BASE_URL` | unset | Table D |

Code patches needed (no env switch exists):
1. `models.dev` fetch (B1). Options: remove or stub `fetchProviderCatalog` and `getModelCost`; or owner approves the host.
2. `typescript` types from jsDelivr (C9). Options: stub `loadTypes`, or approve the host.
3. Community install ban-check (B3), only if install by name stays on.
4. Optional: `enterprise.n8n.io` (B9), license user-action calls (O1).

---

## 8. Corrections to section 4 of IMPLEMENTATION-PROMPT.md

- Row "PostHog analytics": line cite `:60-62` should be `:62,67`.
- Row "Community node listing": has switches `N8N_VERIFIED_PACKAGES_ENABLED` and `N8N_COMMUNITY_PACKAGES_ENABLED`. Remove "Not env-gated".
- Row "MCP registry client": has switch `N8N_DISABLED_MODULES=mcp-registry`. Remove "Not env-gated".
- Row "Frontend onboarding": POST happens only if the owner ticks the "agree" box on setup or signup.
- Row "Version notifications": the call comes from the browser, not the server. Add the security-audit path (A10).
- Row "Templates": add the browser calls (C4) and the server call (A8).
- Add rows: `models.dev` (B1), `sdk-templates.n8n.io` (B2), community install checks (B3), jsDelivr types (C9), `cdn-rs.n8n.io` (C6), RudderStack and `api-rs.n8n.io` (A3, A5), license-client conditions (section 5).
- Statement "some features are PostHog-gated; env force flags override": not re-verified here (belongs to R5).

---

## 9. Not verified

- `.env.local` real values. Not read by order.
- Runtime behavior of every row. No app run, no proxy. Section 7 of the prompt still must run.
- License SDK: read from minified `dist`. A run with a stored cert is not tested. Whether a stale cert exists in `~/.n8n-dev` DB is unknown.
- `otel` module: default list does not include it, but its code and config were not read.
- All uses of global `fetch` and `axios` across `packages/cli/src` and `@n8n/*`. Grep covered literal `http(s)://` hosts only. A host built from a variable or a config value can be missed.
- Hosts built from user data (agent integrations, external secrets, SSO, log streaming): listed as user-configured, not traced.
- `@n8n/ai-workflow-builder.ee` gating (B4, B5): traced only to the `baseUrl` check in `ai-workflow-builder.service.ts:90`.
- MCP app preview host (B6) and whether it has an override.
- Quick Connect (B8) gating and trigger.
- `subscription.n8n.io` (C13): link or fetch.
- `mcp.notion.com` and similar hosts in `packages/cli/src/oauth/oauth.service.ts:1482` and `mcp-registry/registry/mock-servers.ts`: judged as mock or comment data, not opened.
- `@n8n/computer-use`, `@n8n/local-gateway`, tray app: they dial the owner's n8n URL. Not checked for other hosts beyond a grep (only `my-instance.app.n8n.cloud` in a help string, `packages/@n8n/computer-use/src/cli.ts:114`).
- Task runner (JS and Python) outbound calls. Grep found none, no deeper read.
- Browser-only: CSS `url()` and `@font-face` in `packages/frontend/editor-ui/**/*.vue` styles were not grepped for remote URLs (only `fonts.scss`, `index.html`, and `.ts/.vue/.css/.scss` pattern greps).
- Docker/image-level egress (npm install at build time). Out of scope.
