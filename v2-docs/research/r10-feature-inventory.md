# R10: v2 feature inventory

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: Glob, Grep and Read of source. No source file was edited. `.env.local` was not read. No app was started.
Process note: the brief said "Read, Grep, Glob, Write only". The agent also ran read-only `grep`/`ls`/`sed` through Bash for about 10 calls before it noticed. No file changed. Every cited line below was seen in tool output.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`. Paths are relative to the repo root.
Abbreviations: PH = PostHog. FF = feature flag. LS = `LicenseState`. "Opt-in" = module is not in the default module list.
"v2-new" = absent from v1.113. The v1 base is `9806e6fc72` per `v1-docs/custom.md:3`. No git history was read. All v2-new marks are inferred from module age and from `v1-docs/custom.md`. Confidence is medium or low unless said otherwise.

Read `v2-docs/research/r1-patch-map.md` first. This file does not repeat R1. The license choke point is `License.isLicensed()` (R1).

## 1. Key findings

1. **Five modules are opt-in.** They do not load unless `N8N_ENABLED_MODULES` lists them: `agent-evals`, `promotions`, `engine-v2`, `type-availability-policies`, `instance-reporting`.
   [Source: packages/@n8n/backend-common/src/modules/module-registry.ts:45-87 | 2026-10-10 | high]
   [Source: packages/@n8n/backend-common/src/modules/module-registry.ts:104-106 | 2026-10-10 | high]
2. **`N8N_AGENT_EVALS_ENABLED=true` alone does not turn on agent evals.** It only forces the PH flag `101_agent_evals`. The REST surface lives in the opt-in `agent-evals` module. The module also needs `agents` and `data-table` active.
   [Source: packages/cli/src/posthog/index.ts:272-274 | 2026-10-10 | high]
   [Source: packages/cli/src/modules/agent-evals/agent-evals.module.ts:5-15 | 2026-10-10 | high]
   [Source: packages/cli/src/modules/agent-evals/agent-evals-required-modules.ts:5 | 2026-10-10 | high]
   Action: add `agent-evals` to `N8N_ENABLED_MODULES`. I did not read `.env.local`. It may already be set.
3. **PH-gated features stay off with `N8N_DIAGNOSTICS_ENABLED=false`, unless an override exists.** `PostHogClient.init()` returns early when diagnostics are off. Then every flag is empty, and `=== true` checks fail. The general override is `N8N_FEATURE_FLAG_OVERRIDES` (JSON). Seven flags also have a dedicated env var (section 4).
   [Source: packages/cli/src/posthog/index.ts:59-64 | 2026-10-10 | high]
   [Source: packages/@n8n/config/src/configs/feature-flags.config.ts:58-59 | 2026-10-10 | high]
4. **MCP registry client has no env gate.** Only `N8N_DISABLED_MODULES=mcp-registry` stops the 8-hour refresh and the first fetch. The module is default-on. [Source: packages/cli/src/modules/mcp-registry/mcp-registry-refresh.task.ts:7-27 | 2026-10-10 | high]
5. **Community node listing is env-gated, but one call is not.** `N8N_VERIFIED_PACKAGES_ENABLED=false` stops the catalog fetch. The ban check `POST https://api.n8n.io/api/package` still runs on every install. It fails open when the host is unreachable. [Source: packages/cli/src/modules/community-packages/community-packages.service.ts:235-252 | 2026-10-10 | high]
6. **Side effect of finding 5.** With `N8N_VERIFIED_PACKAGES_ENABLED=false`, the MCP tool `install_community_node` is not registered. [Source: packages/cli/src/modules/mcp/mcp-tool-availability.ts:51-73 | 2026-10-10 | high]
7. **Onboarding call is opt-in by the user, not by env.** `POST https://api.n8n.io/api/accounts/onboarding` runs only when the user ticks the "agree" box on the setup or signup form. The browser sends it directly. The checkbox has no default value. No env var gates it. [Source: packages/frontend/@n8n/stores/src/onboarding.api.ts:4-23 | 2026-10-10 | high]
8. **New egress hosts that the brief did not list** (section 6): `sdk-templates.n8n.io`, `api.firecrawl.dev`, `enterprise.n8n.io`, `api-rs.n8n.io`, `telemetry.n8n.io`, and `api.n8n.io` in the AI workflow builder templates tool.
9. **No per-feature code patch is needed for licensed features.** One `License.isLicensed()` patch (R1) opens every `licenseFlag` module and every `@Licensed(...)` route. The module registry calls `licenseState.isLicensed(licenseFlag)` at init. [Source: packages/@n8n/backend-common/src/modules/module-registry.ts:208-213 | 2026-10-10 | high]
   Exception 1: `provisioning` is forced `false` in the frontend settings refresh (R1 row 2.4).
   Exception 2: numeric quotas need the `getValue` fix (R1).

## 2. How modules load

- `MODULE_NAMES` has 39 names. [Source: packages/@n8n/backend-common/src/modules/modules.config.ts:5-45 | 2026-10-10 | high]
- `defaultModules` has 34 names. `eligibleModules` = default + `N8N_ENABLED_MODULES` − `N8N_DISABLED_MODULES`. A name in both env lists throws. [Source: module-registry.ts:97-107 | 2026-10-10 | high]
- Env names: `N8N_ENABLED_MODULES`, `N8N_DISABLED_MODULES`. [Source: modules.config.ts:62-67 | 2026-10-10 | high]
- At init, a module is skipped when its `licenseFlag` is unlicensed or the instance type is not in `instanceTypes`. [Source: module-registry.ts:208-220 | 2026-10-10 | high]
- Only `insights` is loaded from a workspace package (`@n8n/backend-module-insights`, source `packages/modules/insights/backend`). [Source: packages/cli/src/modules/modules.manifest.ts:7-9 | 2026-10-10 | high]
- `packages/modules/*` holds the frontend half of five modules (`insights`, `instance-registry`, `mcp`, `otel`, `type-availability-policies`) plus the insights backend. [Source: packages/modules/README.md | 2026-10-10 | low] (listing only; README not read)
- The module-set decision for the owner: "enable all new v2 features" means default modules + the five opt-in modules. See section 7 for which opt-in modules the owner should skip.

## 3. Backend module inventory

Columns: Default = in `defaultModules`. License = module `licenseFlag` or the getter that gates routes. PH = PostHog flag. All module events go to `TelemetryEventRelay`, then to RudderStack and PH. Both stop when `N8N_DIAGNOSTICS_ENABLED=false` (section 5). Column "Out" = outbound hosts beyond user-configured targets.

| Module | Purpose (1 line) | Default | Env flags (names) | License gate | PH flag | Out | v2-new |
|---|---|---|---|---|---|---|---|
| agents | Build and run AI agents; chat integrations; knowledge; sandbox | on | `N8N_AGENTS_PLAN_TOOLS_ENABLED`, `N8N_AGENTS_TRACING_ENABLED`, `N8N_AGENTS_BACKGROUND_TASKS_ENABLED`, `N8N_AGENTS_AI_SANDBOX_ENABLED`, `N8N_AGENTS_MODULES`, `N8N_SCHEDULER_AGENT_TASKS_ENABLED` | none found in module | UI only: `125_agents_n8n_chat`, `103_inline_agents`, `120_agents_empty_state_templates` | per integration: `api.telegram.org`, `api.linear.app`, Slack, Teams; LLM host | yes (medium) |
| agent-evals | Run eval datasets against a real agent | **opt-in** | `N8N_AGENT_EVALS_ENABLED`, `N8N_AGENT_EVALS_RUN_TIMEOUT_MINUTES` | none | `101_agent_evals` (hard gate, 404 when off) | LLM host | yes (high) |
| insights | Usage and time-saved dashboards | on | none | quotas `getInsightsMaxHistory` and `INSIGHTS_VIEW_*` (R1 1.2f, 1.6) | none | none | no (v1 patched it) |
| external-secrets | Vault-style secret providers | on | `N8N_EXTERNAL_SECRETS_UPDATE_INTERVAL`, `_CONNECT_TIMEOUT`, `_REFRESH_TIMEOUT`, `_PREFER_GET`, `N8N_ENV_FEAT_EXTERNAL_SECRETS_FOR_PROJECTS`, `_MULTIPLE_CONNECTIONS`, `_ROLE_BASED_ACCESS` | `feat:externalSecrets` | none | configured vault | feature no; module form unknown |
| community-packages | Install and list community nodes | on | `N8N_COMMUNITY_PACKAGES_ENABLED`, `_REGISTRY`, `_PREVENT_LOADING`, `_AUTH_TOKEN`, `N8N_VERIFIED_PACKAGES_ENABLED`, `N8N_UNVERIFIED_PACKAGES_ENABLED`, `N8N_REINSTALL_MISSING_PACKAGES`, `ENVIRONMENT` (raw) | custom registry only: `COMMUNITY_NODES_CUSTOM_REGISTRY` | none | `api.n8n.io`, `registry.npmjs.org` | feature no; unknown |
| data-table | Built-in tables | on | `N8N_DATA_TABLES_*` (size, upload, cleanup) | none | none | none | unknown |
| oauth-server | OAuth 2 server for MCP clients | on | `N8N_OAUTH_SERVER_*_RATE_LIMIT` (5) | none | none | none | likely yes (low) |
| mcp | Instance MCP server (main only) | on | `N8N_MCP_ACCESS_ENABLED` (loader, default false), `N8N_MCP_BUILDER_ENABLED`, `N8N_MCP_APPS_ENABLED`, `N8N_MCP_BASE_URL`, `N8N_MCP_SERVER_*`, `N8N_MCP_COMMUNITY_NODE_DISCOVERY_ENABLED`, `N8N_MCP_CLIENT_*` | folders, team projects (reads) | `087_mcp_apps`, `114_instance_activity_context`, `120_credential_descriptions`, `111_context_preferences` | none; app telemetry config uses `diagnostics` | partly (server existed; apps, builder new) |
| provisioning | Map IdP claims to roles | on | `N8N_SSO_SCOPES_*`, `N8N_SSO_JUST_IN_TIME_PROVISIONING` | module: any of `feat:oidc`, `feat:saml`, `feat:ldap`. Routes: `LS.isProvisioningLicensed()` = `feat:saml` or `feat:oidc` | none | IdP | likely yes (low) |
| breaking-changes | v2 to v3 migration report | on (main) | reads many legacy env vars | one rule reads `isExternalSecretsLicensed` | none | none | likely yes (low) |
| source-control | Git sync of workflows | on (main) | `N8N_SOURCECONTROL_DEFAULT_SSH_KEY_TYPE` | `feat:sourceControl` | none | user git remote | feature no |
| promotions | Promote packages between environments over git | **opt-in** (main) | none | `GIT_CONNECTIONS` (module and route) | none | user git remote | yes (medium) |
| dynamic-credentials | Per-end-user credentials | on | `N8N_DYNAMIC_CREDENTIALS_*` (5) | `DYNAMIC_CREDENTIALS` | none | none | yes (medium) |
| chat-hub | Chat UI for models and agents | on | `N8N_CHAT_HUB_*` (3) | none | UI only: `077_chat_hub_semantic_search`, `078_floating_chat_hub_panel` | LLM host | unknown |
| sso-oidc | OIDC login | on (main) | `N8N_SSO_OIDC_LOGIN_ENABLED` | `feat:oidc` | none | IdP | no |
| sso-saml | SAML login | on (main) | `N8N_SSO_SAML_LOGIN_ENABLED`, `N8N_ENV_FEAT_SIGNED_SAML_REQUESTS` | `feat:saml` | none | IdP | no |
| log-streaming | Stream events to destinations | on | none | `feat:logStreaming` | none | user destinations | no |
| ldap | LDAP login | on (main) | `N8N_SSO_LDAP_LOGIN_ENABLED` | `feat:ldap` | none | LDAP server | no |
| quick-connect | One-click credential setup | on | `N8N_QUICK_CONNECT_OPTIONS` (default empty) | none | none | `api.firecrawl.dev` (handler only) | yes (medium) |
| workflow-builder | Entity store for builder sessions | on (main) | none | AI builder routes use `feat:aiBuilder` | none | none | unknown |
| favorites | User favorites | on (main) | none | none | none | none | likely yes (low) |
| redaction | Redact execution data | on | none | `DATA_REDACTION` | none | none | yes (medium) |
| instance-registry | Track main, worker, webhook processes | on | none | none | none | none | likely yes (low) |
| instance-ai | n8n Assistant: chat, builder, sandbox, web search | on (main) | `N8N_INSTANCE_AI_*` (50+), `N8N_AI_ANTHROPIC_KEY`, `DAYTONA_*`, `N8N_SANDBOX_SERVICE_*`, `INSTANCE_AI_BRAVE_SEARCH_API_KEY`, `N8N_INSTANCE_AI_TEMPLATES_URL/_DISABLED/_REFRESH_HOURS` (raw env) | reads `folders`, `namedVersions`, `sharing`, team projects | 13 flags (section 4) | model host, SearXNG, `sdk-templates.n8n.io`, Daytona, Brave | yes (high) |
| mcp-registry | Catalog of remote MCP servers | on | none (`ENVIRONMENT`, `N8N_MCP_SERVERS_DEV_URL` raw) | none | none (UI footer has a PH test) | `api.n8n.io/api/mcp-servers` | yes (medium) |
| otel | OpenTelemetry traces | on, feature off | `N8N_OTEL_ENABLED` and 12 `N8N_OTEL_*` | custom span attrs: `OTEL_CUSTOM_SPAN_ATTRIBUTES` | none | OTLP endpoint | yes (medium) |
| token-exchange | Token exchange and embed login | on (main) | `N8N_TOKEN_EXCHANGE_ENABLED`, `N8N_EMBED_LOGIN_ENABLED`, others (10) | `TOKEN_EXCHANGE` | none | none | yes (medium) |
| instance-version-history | Record version changes | on (main) | none | none | none | none | likely yes (low) |
| encryption-key-manager | Key rotation | on | none found | none | none | none | yes (medium) |
| oauth-jwe | JWE for OAuth | on | none found | none | none | none | likely yes (low) |
| runtime-credentials | Credential field rules | on | `N8N_SECURITY_SENSITIVE_FIELD_RULES` | none | none | none | likely yes (low) |
| n8n-packages | Export and import packages | on | `N8N_IMPORT_MAX_*` (4) | reads variables, folders, projectRole | none | none | yes (medium) |
| workflow-reviews | Review requests before publish | on | none | `WORKFLOW_REVIEWS` | none | none | yes (medium) |
| engine-v2 | Execution engine v2 (main, not queue) | **opt-in** | `N8N_ENGINE_MODE` and `N8N_ENGINE_*` | none | none | none (remote mode: own engine process) | yes (high) |
| policy-infrastructure | Base for policy checks | on | none | none | none | none | yes (medium) |
| type-availability-policies | Allow or deny node and credential types | **opt-in** | none | `TYPE_AVAILABILITY_POLICIES` | none | none | yes (high) |
| instance-reporting | Daily report to a receiver | **opt-in** (main) | `N8N_INSTANCE_REPORTING_BASE_URL`, `_AUTH_TOKEN`, `_LABEL` | needs certificate or token | none | the receiver | yes (high) |
| inbound-auth-core | Bind inbound-auth contracts | on | none | none | none | none | likely yes (low) |
| scim | SCIM user provisioning | on (main) | `N8N_SCIM_RATE_LIMIT` | `feat:scim` | none | none | yes (medium) |

Sources for the table:
- Default list and opt-in: `module-registry.ts:45-87`.
- Module decorators: `packages/cli/src/modules/*/*.module.ts` (all 39 read by Grep). Examples: `agent-evals.module.ts:12`, `promotions.module.ts:6-11`, `provisioning.module.ts:5-9`, `token-exchange.module.ts:7-11`, `workflow-reviews.module.ts:9`, `dynamic-credentials.module.ts:16`, `scim.module.ts:10`.
- Opt-in comments: `engine-v2.module.ts:14`, `instance-reporting.module.ts:11-13`. [high]
- Env names: `packages/cli/src/modules/*/*.config.ts` and `packages/@n8n/config/src/configs/*.config.ts`. [high]
- Route-level `@Licensed`: `ldap.controller.ee.ts:21`, `log-streaming.controller.ts:45`, `oidc.controller.ee.ts:43`, `promotion-changes.controller.ts:21`, `type-availability-policies/*.controller.ts` (22 uses), `workflow-reviews.ee` (10 uses). [high]
- `agents` license: Grep for `LICENSE_FEATURES`, `feat:` and `is*Licensed` in `modules/agents` found nothing. [medium]
- Purposes of `favorites`, `oauth-jwe`, `runtime-credentials`, `encryption-key-manager`, `policy-infrastructure`, `inbound-auth-core`: from the module name only. [low]
- Out-of-module routes with `@Licensed`: `controllers/ai.controller.ts` (`feat:aiBuilder` lines 85, 246, 302, 315, 335; `feat:askAi` line 222; `feat:aiGateway` lines 265, 276, 287), `role.controller.ts:144,164,187` (`CUSTOM_ROLES`), `project-pool-settings.controller.ee.ts:13,24` (`WORKER_POOLS`), `security-settings.controller.ts`. [high]

Feature gates outside `modules/` (not modules, but v2 features):
- Worker pools: `LS.isWorkerPoolsLicensed()` = `feat:workerPools`; env `N8N_WORKER_POOLS_ENABLED` (default false). [Source: packages/@n8n/backend-common/src/license-state.ts:177-179 | 2026-10-10 | high] [Source: packages/@n8n/config/src/configs/scaling-mode.config.ts:20-21 | 2026-10-10 | high]
- Durable scheduler: `N8N_SCHEDULER_ENABLED` (default false) and eight related flags. [Source: packages/@n8n/config/src/configs/scheduler.config.ts:42-43 | 2026-10-10 | high]
- Workflow publication service: `N8N_USE_WORKFLOW_PUBLICATION_SERVICE` (default true). [Source: packages/@n8n/config/src/configs/workflows.config.ts:32-33 | 2026-10-10 | high]
- Expression engine: `N8N_EXPRESSION_ENGINE_FRONTEND` (default `legacy`), observability on, native evaluation off. [Source: packages/@n8n/config/src/configs/expression-engine.config.ts:31-32,64-65,123-124 | 2026-10-10 | high]
- Real-time collaboration (CRDT): `N8N_COLLABORATION_CRDT` default `'off'`. [Source: packages/@n8n/config/src/configs/collaboration.config.ts | 2026-10-10 | medium] (value read from Grep of the class, line not captured)
- Canvas-only mode: `N8N_CANVAS_ONLY` default false. [Source: packages/@n8n/config/src/configs/canvas-only.config.ts:34-35 | 2026-10-10 | high]
- AI Gateway ("Gateway credits"): `N8N_AI_GATEWAY_ENABLED` default true, but it needs `aiAssistant.baseUrl`; with an empty base URL it stays off. [Source: packages/cli/src/services/ai-gateway.service.ts:71-77 | 2026-10-10 | medium] [Source: packages/@n8n/config/src/configs/ai-gateway.config.ts:10-11 | 2026-10-10 | high]
- Activity log: `N8N_ACTIVITY_LOG_RETENTION_DAYS`, `N8N_ACTIVITY_LOG_MAX_ENTRIES`. Gate is PH `114_instance_activity_context`. [Source: packages/cli/src/events/relays/activity.event-relay.ts:88-118 | 2026-10-10 | high]

## 4. PostHog flags and their env overrides

With PH off, `PostHogClient.applyEnvOverrides()` still adds the overrides below. Then it merges `N8N_FEATURE_FLAG_OVERRIDES`. [Source: packages/cli/src/posthog/index.ts:259-300 | 2026-10-10 | high]
The frontend takes server-evaluated flags, so overrides reach the UI. [Source: packages/frontend/editor-ui/src/app/stores/posthog.store.ts:199-212 | 2026-10-10 | high]

| Flag key | Gates | Dedicated env var | Needs `N8N_FEATURE_FLAG_OVERRIDES`? | Source |
|---|---|---|---|---|
| `084_eval_collections` | Eval collections, eval insights | `N8N_EVAL_COLLECTIONS_ENABLED` | no | posthog/index.ts:262-264; evaluation-collections.controller.ee.ts:46-47 |
| `088_config_evaluations` (variant `variant`) | Config evals in Instance AI and UI | `N8N_CONFIG_EVALS_ENABLED` | no | posthog/index.ts:268-270; instance-ai.adapter.service.ts:744 |
| `101_agent_evals` | Agent evals | `N8N_AGENT_EVALS_ENABLED` (+ module) | no | posthog/index.ts:272-274; agent-evals-flag-gate.ts:21-24 |
| `104_canvas_aia_node_context` | Canvas node context in Assistant | `N8N_INSTANCE_AI_NODE_CONTEXT_ENABLED` | no | posthog/index.ts:276-278 |
| `109_instance_ai_node_usage` | Node-usage tool | `N8N_INSTANCE_AI_NODE_USAGE_ENABLED` | no | posthog/index.ts:280-282 |
| `110_instance_ai_folder_exploration` (variant `test`) | Folder listing in Assistant | `N8N_INSTANCE_AI_FOLDER_EXPLORATION_ENABLED` | no | posthog/index.ts:284-287; instance-ai.schema.ts:2865 |
| `117_flexible_groups_triggers` | Triggers inside canvas groups | `N8N_WORKFLOWS_GROUPS_WITH_TRIGGERS_ENABLED` | no | posthog/index.ts:289-291 |
| `122_flexible_groups_multiple_boundaries` | Many boundary nodes in groups | `N8N_WORKFLOWS_GROUPS_WITH_MANY_BOUNDARIES_ENABLED` | no | posthog/index.ts:293-295 |
| `087_mcp_apps` (variant `variant`) | MCP apps | `N8N_MCP_APPS_ENABLED` (read in `mcp.service.ts`, not in PH override) | no | mcp.service.ts:294-301; endpoints.config.ts:207-208 |
| `114_instance_activity_context` | Shared activity recording and retrieval (Instance AI, MCP, activity log) | none | **yes** | activity.event-relay.ts:88-93; mcp.service.ts:282 |
| `116_at_mentions_enabled` | Workflow, node and group mentions in Assistant | none | **yes** | instance-ai.schema.ts:2822; adapter:759 |
| `109_instance_ai_conversation_history` (variant `variant`) | Conversation-history tool | none | **yes** | adapter:745-747 |
| `111_instance_ai_progressive_building` (variant `variant`) | Progressive building | none | **yes** | adapter:748-750 |
| `111_context_preferences` (variant `variant`) | Saved AI preferences, MCP `aiPreference:*` tools | none | **yes** | mcp-tool-availability.ts:19-21; adapter:763 |
| `118_instance_ai_setup_overhaul` (variant `variant`) | Setup panel | none | **yes** | adapter:741,753 |
| `120_credential_descriptions` | Credential descriptions in builder and MCP | none | **yes** | credential-descriptions.service.ts:12; adapter:743; mcp.service.ts:287 |
| `124_instance_ai_concise_style` (variant `variant`) | Concise reply style. `N8N_INSTANCE_AI_PROMPT_VERSION` overrides it | none | **yes** | adapter:751-752; instance-ai.schema.ts:2837 |
| `085_eval_vendor_sdk_interception` | Kill switch. Default is ON (`!== false`) | none | no (already on) | eval/execution.service.ts:275-276 |
| `121_empty_canvas_groups` | Telemetry property only | none | no | telemetry.event-relay.ts:1302-1305 |
| `125_agents_n8n_chat` (variants `variant-a`, `variant-b`) | UI experiment | none | yes (UI only) | frontend experiments.ts:172-176 |

Frontend-only growth experiments (about 40: onboarding, templates, nudges, trial modal) are listed in `packages/frontend/editor-ui/src/app/constants/experiments.ts:20-176`. They are not product features. I do not recommend overriding them. [Source: experiments.ts:178-190 | 2026-10-10 | high]

Override format. The value is a JSON object, `flag -> boolean | string | {value, payload}`. Invalid JSON leaves all flags untouched. [Source: feature-flags.config.ts:46-59 | 2026-10-10 | high]

## 5. Telemetry

- Backend: `Telemetry.init()` builds RudderStack only when `diagnostics.enabled`. Every `this.rudderStack` use is guarded. [Source: packages/cli/src/telemetry/index.ts:186-197 | 2026-10-10 | high] [Source: packages/cli/src/telemetry/index.ts:448 | 2026-10-10 | medium]
- PostHog: `init()` returns early when diagnostics are off. `track()` then calls `this.postHog?.capture`, which is a no-op. [Source: posthog/index.ts:59-64,100 | 2026-10-10 | high]
- Hosts and keys live in config defaults: `https://ph.n8n.io`, `https://telemetry.n8n.io` (front and back). [Source: packages/@n8n/config/src/configs/diagnostics.config.ts:11,22,26 | 2026-10-10 | high]
- Frontend settings carry `posthog.enabled` and `telemetry.enabled`; R1 and R5 cover the UI side.
- MCP apps build a telemetry config from `diagnostics`; disabled config when diagnostics are off. [Source: mcp.service.ts:308-312 | 2026-10-10 | medium]
- Per-module events: 25 module directories call `eventService.emit`. They all go through the relay. [Source: Grep of `this.eventService` in packages/cli/src/modules | 2026-10-10 | medium]
- The personalization survey emits only a telemetry event. It has no direct call. [Source: packages/cli/src/controllers/me.controller.ts:230 | 2026-10-10 | high]
- `GET /rest/telemetry/rudderstack/sourceConfig` is a public route. It would call `api-rs.n8n.io` when a client asks. The editor only asks when telemetry is on. [Source: packages/cli/src/controllers/telemetry.controller.ts:117-135 | 2026-10-10 | high]

## 6. Outbound hosts (beyond R1/R5/R11 list)

| Host | Where | Trigger | Env gate | Source |
|---|---|---|---|---|
| `api.n8n.io/api/community-nodes` | community-node-types-utils.ts:51 | Node creator opens community catalog | `N8N_VERIFIED_PACKAGES_ENABLED=false` or `N8N_COMMUNITY_PACKAGES_ENABLED=false` | community-node-types.service.ts:110 [high] |
| `api.n8n.io/api/package` | community-packages.service.ts:236 | Every install (ban check) | none; fails open | :235-252 [high] |
| `api.n8n.io/api/community-nodes` (reinstall) | community-packages.service.ts:403 | Only if `N8N_REINSTALL_MISSING_PACKAGES=true` | that flag (default false) | :392-415 [high] |
| `api.n8n.io/api/mcp-servers` | mcp-registry-api.client.ts:14,88-97 | Startup takeover, then every 8 h | `N8N_DISABLED_MODULES=mcp-registry` only | mcp-registry-refresh.task.ts:7,23-27 [high] |
| `api.n8n.io/api/accounts/onboarding` | onboarding.api.ts:4-5 | User ticks "agree" in setup or signup | none | SetupView.vue:93-97; SignupView.vue:127-130 [high] |
| `sdk-templates.n8n.io` | @n8n/instance-ai/src/workspace/builder-templates-service.ts:57 | Builder sandbox setup, then daily | `N8N_INSTANCE_AI_TEMPLATES_DISABLED=true` (raw env, line 591,599). Also moot while `N8N_INSTANCE_AI_SANDBOX_ENABLED=false` (default) | instance-ai.adapter.service.ts:933-942; sandbox-setup.ts:476 [high] |
| `api.n8n.io/api` (templates search) | @n8n/ai-workflow-builder.ee/src/tools/web/templates.ts:14 | Legacy builder tool | not tied to `N8N_TEMPLATES_ENABLED` (not verified) | [medium] |
| `api.firecrawl.dev` | quick-connect/handlers/firecrawl.handler.ts:9,37 | User clicks a Firecrawl quick-connect option | `N8N_QUICK_CONNECT_OPTIONS` empty by default | quick-connect.config.ts:64-65 [high] |
| `enterprise.n8n.io` | license/license.service.ts:72,104 | User requests trial or registers community edition | none | [high] |
| `api-rs.n8n.io` | telemetry.controller.ts:133 | Client asks for RudderStack source config | diagnostics | [high] |
| `api.openai.com` (synthetic) | instance-ai/eval/openai-envelope.ts:12 | Eval only; synthetic URL, not a call (not verified) | n/a | [low] |

Hosts already in the brief (templates, banners, version notifications, license, `ph.n8n.io`) are unchanged. See `IMPLEMENTATION-PROMPT.md:127-140`.

## 7. Owner goal: "enable all new v2 features". What each feature needs

Legend: **none** = on after R1's license patch and defaults. **env** = env only. **patch** = code patch.

| Feature | Needs | Detail |
|---|---|---|
| All `licenseFlag` modules (workflow-reviews, dynamic-credentials, token-exchange, scim, ldap, sso-*, source-control, log-streaming, external-secrets, type-availability-policies, promotions) | none (after R1 item 1) | `ModuleRegistry` and `@Licensed` read `LS.isLicensed`. [high] |
| `@Licensed` API routes (ai builder, ask-ai, ai gateway, custom roles, worker pools, variables, folders, named versions) | none | Same choke point. |
| AI builder (`feat:aiBuilder`) | env | Routes open after R1. `aiBuilder.setup` needs `N8N_AI_ANTHROPIC_KEY` or an assistant base URL. Owner chose no base URL. So the legacy builder stays unset. Instance AI is the main path. (R1 2.3) |
| AI Gateway / Gateway credits | none (inert) | Needs `aiAssistant.baseUrl`. Owner decision: leave off. |
| Instance AI (n8n Assistant) | env (UI) | Default module. Needs a model connection in the admin UI. Env `N8N_INSTANCE_AI_MODEL` has a default `anthropic/claude-opus-4-8`. [Source: instance-ai.config.ts:13-14 | 2026-10-10 | high] |
| Instance AI extras (node usage, folder exploration, node context, config evals, workflow suggestions) | env | Dedicated env vars. Section 4. |
| Instance AI extras (activity context, at-mentions, conversation history, progressive building, preferences, setup panel, credential descriptions, concise style) | env (`N8N_FEATURE_FLAG_OVERRIDES`) | No dedicated env. One JSON value enables all. Owner decision needed: these are PH experiments. |
| Agents | none | Default module. Chat integrations need user credentials. Background tasks and AI sandbox are off by default. |
| Agent evals | env | Add `agent-evals` to `N8N_ENABLED_MODULES` (finding 2). |
| MCP server | env (UI) | Default module. Access is a UI toggle. Env alias `N8N_MCP_ACCESS_ENABLED`. |
| MCP apps | env | `N8N_MCP_APPS_ENABLED=true` (set). |
| MCP registry | none | Default on. Owner wanted it off for now: use `N8N_DISABLED_MODULES=mcp-registry`. Check the side effects: `agents` and Instance AI use the registry when active (`instance-ai.service.ts:2595`, `agent-execution.service.ts:112` test `isActive`). They degrade, not break. [medium] |
| Community node listing off | env | `N8N_VERIFIED_PACKAGES_ENABLED=false`. Cost: MCP `install_community_node` disappears (finding 6). Manual install by npm name still works. The ban check still calls `api.n8n.io` and fails open when blocked. |
| Provisioning (SCIM role mapping from IdP) | patch | Backend opens after R1. Frontend refresh forces `provisioning` false (R1 2.4, `frontend.service.ts:563`). Upstream says "not ready". Recommend: do not enable. |
| Engine v2 | env | `N8N_ENABLED_MODULES` + `engine-v2`. Main only. Not queue mode. Changes how workflows execute. **Recommend: do not enable** without a separate test pass. [Source: engine-v2.module.ts:14-33 | 2026-10-10 | high] |
| Instance reporting | env | Opt-in. Needs a receiver URL and a token or certificate. It would send daily numbers out. **Recommend: leave off.** Egress policy forbids it. |
| Type availability policies, promotions | env | Add to `N8N_ENABLED_MODULES`. Useful only for multi-team governance and git promotion. Owner choice. |
| OpenTelemetry | env | Module loads; feature off with `N8N_OTEL_ENABLED=false`. |
| Worker pools | env | Needs `N8N_WORKER_POOLS_ENABLED` and queue mode. Not for a single instance. |
| Durable scheduler | env | `N8N_SCHEDULER_ENABLED` (default false). Experimental. |
| Workflow history / insights limits | patch (R1) | `getValue` quotas. |
| Real-time collaboration | env | `N8N_COLLABORATION_CRDT` (values not verified). |

Suggested `N8N_ENABLED_MODULES` for "all new, minus risky": `agent-evals`. Optional: `promotions`, `type-availability-policies`. Not recommended: `engine-v2`, `instance-reporting`. Names only; values are for the owner to confirm.

## 8. `@n8n/*` packages (feature-relevant)

All paths are `packages/@n8n/<name>`. "Gate" is how the feature turns on. Descriptions come from each `package.json` unless marked.

| Package | Purpose | Gate or flag | v2-new |
|---|---|---|---|
| `agents` | AI agent SDK for the code-first engine | `agents` module | yes (medium) |
| `ai-node-sdk`, `ai-utilities` | SDK and helpers for AI nodes | none | unknown |
| `ai-workflow-builder.ee` | Legacy AI workflow builder (LangChain); uses `api.n8n.io` templates | `feat:aiBuilder`; `N8N_AI_ANTHROPIC_KEY` | no |
| `instance-ai` | n8n Assistant runtime, tools, sandbox, memory | `instance-ai` module | yes (high) |
| `mcp-apps`, `mcp-browser`, `mcp-browser-extension` | MCP app UIs; Playwright browser tools; Chrome extension | `N8N_MCP_APPS_ENABLED`; `N8N_INSTANCE_AI_BROWSER_USE_ENABLED` (default true) | yes (medium) |
| `computer-use`, `local-gateway` | Local AI gateway (files, shell, screen, browser) for the Assistant | `N8N_INSTANCE_AI_LOCAL_GATEWAY_DISABLED` (default false) | yes (high) |
| `engine`, `node-engine-compatibility` | Engine v2 and v1-node adapter | `engine-v2` module | yes (high) |
| `crdt` | CRDT layer for collaborative editing | `N8N_COLLABORATION_CRDT` | yes (medium) |
| `blob-storage` | Blob layer: filesystem, S3, Azure | execution data mode needs license (R1) | yes (medium) |
| `scheduler` | Durable scheduler | `N8N_SCHEDULER_ENABLED` (default false) | yes (medium) |
| `expression-runtime` | Isolated expression runtime | `N8N_EXPRESSION_ENGINE_*` | yes (medium) |
| `workflow-sdk` | TypeScript SDK to build workflows | used by builder and CLI | yes (medium) |
| `cli` (`@n8n/cli`) | Client CLI: workflows, credentials, promotions, packages | none | yes (high) |
| `telemetry` | Frontend telemetry event catalog | diagnostics | unknown |
| `permissions`, `decorators`, `di`, `config`, `constants`, `api-types`, `backend-common`, `db`, `errors` | Core libraries | n/a | n/a |
| `backend-network`, `backend-services`, `inbound-auth`, `extension-sdk`, `imap`, `syslog-client`, `task-runner`, `task-runner-python`, `tournament`, `typeorm`, `json-schema-to-zod`, `node-cli`, `create-node`, `module-cli`, `scan-community-package`, `codemirror-*`, `eslint-*`, `oxlint-config`, `stylelint-config`, `typescript-config`, `vitest-config`, `backend-test-utils`, `chat-hub`, `nodes-langchain`, `node-engine-compatibility`, `utils` | Support, tooling or node packs; no feature gate found | none | unknown |

[Source: packages/@n8n/*/package.json `description` fields (Grep) | 2026-10-10 | high for the quoted ones; low for the last row (names only)]

## 9. Not verified

- Runtime behavior. No app was started. Every claim is from reading source.
- `v2-new` marks. No git history of v1.113 was read. Marks use module age and `v1-docs/custom.md` only. Treat "likely" and "unknown" as guesses.
- Whether `.env.local` already lists `N8N_ENABLED_MODULES` or `N8N_FEATURE_FLAG_OVERRIDES`. The file was not read.
- Values accepted by `N8N_COLLABORATION_CRDT`. Only the default (`off`) was seen, and the exact line was not captured.
- Whether the `agents` module has any license check outside `modules/agents` (for example in `@n8n/agents`). Only `cli/src/modules` was searched.
- Purposes of `favorites`, `oauth-jwe`, `runtime-credentials`, `encryption-key-manager`, `policy-infrastructure`, `inbound-auth-core`. Names only.
- Whether `ai-workflow-builder.ee` template search is gated by `N8N_TEMPLATES_ENABLED`. Not traced.
- Whether `api.openai.com` synthetic URLs in `instance-ai/eval/*` ever leave the process.
- Whether disabling `mcp-registry` breaks any default UI flow (the footer component `McpRegistrySuggestionFooter` uses PH). Only `isActive` checks in `instance-ai` and `agents` were seen.
- Frontend side of module `settings()` payloads (what each module shows in `/rest/module-settings`).
- Whether `N8N_AI_ENABLED` (default false) gates anything the owner wants. Not traced.
- Whether `custom.v2` `.env.local` sets `N8N_INSTANCE_AI_SANDBOX_ENABLED`. Default false means the builder sandbox and `sdk-templates.n8n.io` stay unused.
- Whether `diagnostics` off also stops the public `/rest/telemetry/*` proxy routes. They exist whenever the controller loads.
