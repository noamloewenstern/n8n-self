# R7: AI assistant on an unlicensed, PostHog-off, local-only instance

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: read source with Read/Grep/Glob. No app was started. `.env.local` was not read. `r1-patch-map.md` was read first and is not repeated here.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.

## 1. Short answers

1. No hosted default URL exists in n8n source. `N8N_AI_ASSISTANT_BASE_URL` defaults to `''`. [Source: packages/@n8n/config/src/configs/ai-assistant.config.ts:9-10 | 2026-10-10 | high]
2. The hosted URL `https://ai-assistant.n8n.io` exists only inside the npm package `@n8n_io/ai-assistant-sdk` 1.27.0. The SDK uses it when `baseUrl` is `null` or `undefined`. n8n passes `''`, and `'' ?? default` is `''`. So the SDK never falls back to the hosted host. [Source: node_modules/.pnpm/@n8n_io+ai-assistant-sdk@1.27.0/node_modules/@n8n_io/ai-assistant-sdk/dist/index.js:146,152,176 | 2026-10-10 | high]
3. Instance AI (the "n8n Assistant") needs NO license patch and NO PostHog flag. It needs a model connection, a sandbox, and a web-search decision. See section 3.
4. Keep `baseUrl` empty. Then `AiService.isProxyEnabled()` is `false` even if the license patch makes `isAiAssistantEnabled()` true. Every proxy path stays off. See section 4.
5. Three features DO depend on PostHog flags or env switches: computer use (frontend flag), agent evals (flag plus opt-in module), MCP apps (flag or env). The env overrides in section 5 replace PostHog. No code patch is needed for them.

## 2. Config classes

| Config | File:line | Default |
|---|---|---|
| `AiAssistantConfig.baseUrl` (`N8N_AI_ASSISTANT_BASE_URL`) | `packages/@n8n/config/src/configs/ai-assistant.config.ts:9-10` | `''` |
| `AiBuilderConfig.apiKey` (`N8N_AI_ANTHROPIC_KEY`) | `packages/@n8n/config/src/configs/ai-builder.config.ts:9-10` | `''` |
| `InstanceAiConfig.model` | `packages/@n8n/config/src/configs/instance-ai.config.ts:13-14` | `anthropic/claude-opus-4-8` |
| `InstanceAiConfig.modelUrl`, `modelApiKey` | `instance-ai.config.ts:17-22` | `''` |
| `InstanceAiConfig.sandboxEnabled` | `instance-ai.config.ts:73-74` | `false` |
| `InstanceAiConfig.sandboxProvider` | `instance-ai.config.ts:77-78` | `n8n-sandbox` |
| `daytonaApiUrl`, `n8nSandboxServiceUrl` | `instance-ai.config.ts:81-82,89-90` | `''` |
| `braveSearchApiKey`, `searxngUrl` | `instance-ai.config.ts:167-172` | `''` |
| `workflowSuggestionsEnabled` | `instance-ai.config.ts:9-10` | `false` |
| `browserUseEnabled`, `localGatewayDisabled` | `instance-ai.config.ts:65-70` | `true`, `false` |

[Source: the files above | 2026-10-10 | high]

The package `packages/@n8n/instance-ai` has no hosted default for the model, the sandbox, or search. Its only fixed hosts are listed in section 7. [Source: packages/@n8n/instance-ai/src (grep of http(s) literals) | 2026-10-10 | medium]

## 3. How Instance AI starts with an OpenRouter key from the admin UI

### 3.1 Module and gate

- The module `instance-ai` is in the default module list. It has no `licenseFlag`. [Source: packages/@n8n/backend-common/src/modules/module-registry.ts:84 | 2026-10-10 | high] [Source: packages/cli/src/modules/instance-ai/instance-ai.module.ts:6 | 2026-10-10 | high]
- The admin switch `enabled` starts as `true`. [Source: packages/cli/src/modules/instance-ai/instance-ai-settings.service.ts:288 | 2026-10-10 | high]
- Chat endpoints use scope `instanceAi:message`. Settings endpoints use `instanceAi:manage`. Scopes come from the role, not from a license. Owner and admin have all four `instanceAi:*` scopes. Member has `message` and `gateway`. [Source: packages/@n8n/permissions/src/roles/scopes/global-scopes.ee.ts:185-188,228-229 | 2026-10-10 | high]
- Chat refuses to run when no model exists. [Source: packages/cli/src/modules/instance-ai/instance-ai.controller.ts:150-156 | 2026-10-10 | high]
- Frontend gate: module active, `enabled !== false`, (`setupCompleted` or the user can manage), and the user can message. No license or PostHog term. [Source: packages/frontend/editor-ui/src/features/ai/instanceAi/composables/useInstanceAiAvailability.ts:14-24 | 2026-10-10 | high]

### 3.2 Setup rule

`setupCompleted` is true only when model, sandbox, and web-search decision are all set. [Source: packages/@n8n/api-types/src/schemas/instance-ai.schema.ts:2573-2574 | 2026-10-10 | high]
- Model source `ui` needs a model credential id and a model name. [Source: instance-ai.schema.ts:2544-2548 | 2026-10-10 | high]
- Sandbox source `none` when `sandboxEnabled` is false. [Source: instance-ai.schema.ts:2553-2559 | 2026-10-10 | high]
- Web search `none` unless a search credential, an env search config, or `searchDisabled` exists. [Source: instance-ai.schema.ts:2560-2566 | 2026-10-10 | high]
- An owner or admin can open the assistant before setup is complete. A member cannot. [Source: useInstanceAiAvailability.ts:42-48 | 2026-10-10 | high]
- The chat endpoint checks the model only. Sandbox and search are not required to chat. [Source: instance-ai-settings.service.ts:1325-1333 | 2026-10-10 | high]

### 3.3 OpenRouter key path

1. Admin sends `PUT /instance-ai/settings` with `modelConnection` of type `openRouterApi` and a model name. [Source: packages/cli/src/modules/instance-ai/instance-ai.controller.ts:743-744 | 2026-10-10 | high]
2. Allowed model credential types include `openRouterApi`. [Source: packages/@n8n/api-types/src/schemas/instance-ai.schema.ts:2438-2448 | 2026-10-10 | high]
3. The service maps `openRouterApi` to provider `openrouter` and builds the id `openrouter/<model>`. [Source: instance-ai-settings.service.ts:87-97,1477-1507 | 2026-10-10 | high]
4. The `@n8n/agents` model factory builds the model with `@openrouter/ai-sdk-provider` and passes `creds.baseURL`. For OpenRouter the config carries `url: ''`. The package default should apply, but this was not proven. [Source: packages/@n8n/agents/src/runtime/model/model-factory.ts:385-389 | 2026-10-10 | medium] [Source: instance-ai-settings.service.ts:1500-1503 | 2026-10-10 | high]
5. The credential type `openRouterApi` has the hidden field `url` default `https://openrouter.ai/api/v1`. [Source: packages/@n8n/nodes-langchain/credentials/OpenRouterApi.credentials.ts:28 | 2026-10-10 | high]
6. The credential broker has no license check. [Source: packages/cli/src/credentials/instance-credential-broker.ts (grep for license: no match) | 2026-10-10 | medium]

Two traps:
- Do NOT set `N8N_INSTANCE_AI_MODEL`. When set, the model name becomes env-managed and the UI cannot change it. [Source: instance-ai-settings.service.ts:453,1544 | 2026-10-10 | high]
- Do NOT set a provider key such as `ANTHROPIC_API_KEY` in the server env. It counts as an env model connection and blocks the UI connection. [Source: instance-ai-settings.service.ts:412-422,1642-1653 | 2026-10-10 | high] [Source: packages/@n8n/instance-ai/docs/configuration.md:26-29 | 2026-10-10 | high]

The condition for UI-managed settings is `isDirectSelfManaged()`: not cloud and not proxy. With `baseUrl` empty this is true. [Source: instance-ai-settings.service.ts:1671-1673 | 2026-10-10 | high]

## 4. Why the empty `baseUrl` keeps the hosted service off

`AiService.isProxyEnabled()` = license `isAiAssistantEnabled()` AND `baseUrl` non-empty. [Source: packages/cli/src/services/ai.service.ts:75-79 | 2026-10-10 | high]

Every call to the hosted client is behind `isProxyEnabled()`:
- Instance AI run config (proxy token, search proxy, tracing proxy). [Source: packages/cli/src/modules/instance-ai/instance-ai.service.ts:1008 | 2026-10-10 | high]
- Model resolution. [Source: packages/cli/src/modules/instance-ai/instance-ai-model.service.ts:66,141 | 2026-10-10 | high]
- LangSmith feedback proxy. [Source: packages/cli/src/modules/instance-ai/tracing/instance-ai-tracing.service.ts:500 | 2026-10-10 | high]
- Sandbox proxy. [Source: packages/cli/src/modules/instance-ai/sandbox/instance-ai-sandbox.service.ts:279 | 2026-10-10 | high]
- Activation lock. [Source: packages/cli/src/modules/instance-ai/instance-ai-credit.service.ts:146-151 | 2026-10-10 | high]
- Agents module hosted paths. [Source: packages/cli/src/modules/agents/agent-runtime-reconstruction.service.ts:759 | 2026-10-10 | high] [Source: packages/cli/src/modules/agents/agent-sandbox-runtime.service.ts:420 | 2026-10-10 | high] [Source: packages/cli/src/modules/agents/agent-session-langsmith-export.service.ts:124 | 2026-10-10 | high]
- AI gateway and free AI credits also need a non-empty `baseUrl`. [Source: packages/cli/src/services/ai-gateway.service.ts:75 | 2026-10-10 | high] [Source: packages/cli/src/services/free-ai-credits.service.ts:31 | 2026-10-10 | high]

Frontend flags that depend on `baseUrl` stay off with it empty:
- `aiAssistant.setup` = `baseUrl` OR `N8N_AI_ANTHROPIC_KEY`. [Source: packages/cli/src/services/frontend.service.ts:621-627 | 2026-10-10 | high]
- `aiCredits.setup` = `baseUrl`. [Source: frontend.service.ts:634-639 | 2026-10-10 | high]
- `aiGateway.enabled` needs `baseUrl`. [Source: frontend.service.ts:641-651 | 2026-10-10 | high]
- `aiBuilder.setup` = `baseUrl` OR `N8N_AI_ANTHROPIC_KEY`. [Source: frontend.service.ts:653-657 | 2026-10-10 | high]

Risk for the R1 patch plan: if `License.isLicensed()` returns `true` AND someone sets `N8N_AI_ANTHROPIC_KEY`, then `aiAssistant.setup` and `aiBuilder.setup` both become `true`. The frontend then shows the classic assistant. Its backend client has `baseUrl ''`, so its calls fail. Do not set `N8N_AI_ANTHROPIC_KEY` unless the classic AI workflow builder is wanted. [Source: frontend.service.ts:621-627,653-657 | 2026-10-10 | high] [Source: packages/cli/src/services/ai.service.ts:41-51 | 2026-10-10 | high] The failure mode of the client with an empty base URL is reasoned, not run (see section 9).

## 5. Feature table

"Needs license?" means "does the code call a license check?". With the R1 choke-point patch (`License.isLicensed()` returns `true`) all license checks pass. Without it, they fail closed.

| Feature | Backend or env switch | Needs license? | Needs PostHog flag? | Replacement without PostHog | Code patch needed? |
|---|---|---|---|---|---|
| Instance AI chat and settings | Module default-on. Model connection required. | No | No | None needed | No |
| Instance AI folders in tools | `license.isLicensed('feat:folders')` | Yes | Flag `110_instance_ai_folder_exploration` for exploration | `N8N_INSTANCE_AI_FOLDER_EXPLORATION_ENABLED=true` | No (R1 patch covers license) |
| Instance AI named versions | `feat:namedVersions` | Yes | No | None | No (R1 patch covers it) |
| Instance AI canvas node context | None | No | Flag `104_canvas_aia_node_context` | `N8N_INSTANCE_AI_NODE_CONTEXT_ENABLED=true` | No |
| Instance AI node usage | None | No | Flag `109_instance_ai_node_usage` | `N8N_INSTANCE_AI_NODE_USAGE_ENABLED=true` | No |
| Instance AI setup flow (panel or wizard) | None | No | Flag `118_instance_ai_setup_overhaul` | Unset gives the wizard. Override with `N8N_FEATURE_FLAG_OVERRIDES` | No |
| Workflow suggestions | `N8N_INSTANCE_AI_WORKFLOW_SUGGESTIONS_ENABLED=true` and restart | No | No | Not needed | No |
| Agent evals | Opt-in module `agent-evals` AND flag gate | No | Flag `101_agent_evals` | `N8N_AGENT_EVALS_ENABLED=true` AND `N8N_ENABLED_MODULES=agent-evals` | No |
| MCP apps | `endpoints.mcpAppsEnabled` | No | Flag `087_mcp_apps` | `N8N_MCP_APPS_ENABLED=true` | No |
| Computer use | Env `N8N_INSTANCE_AI_BROWSER_USE_ENABLED` (default true), `N8N_INSTANCE_AI_LOCAL_GATEWAY_DISABLED` (default false) | No | Frontend flag `091_instance_ai_computer_use`, value `variant` | `N8N_FEATURE_FLAG_OVERRIDES` | No |
| Web search (SearXNG) | `N8N_INSTANCE_AI_SEARXNG_URL` or admin search credential `searXngApi` | No | No | Not needed | No |
| Sandbox | `N8N_INSTANCE_AI_SANDBOX_ENABLED` + provider URL, or admin sandbox connection | No | No | Not needed | No |
| Classic AI assistant / AI builder | License `isAiAssistantEnabled` / `feat:aiBuilder` + `baseUrl` or `N8N_AI_ANTHROPIC_KEY` | Yes | No | Out of scope | See section 4 risk |

Evidence per row:

- Folders and named versions: [Source: packages/cli/src/modules/instance-ai/instance-ai.adapter.service.ts:960,965,1054,1989,4146 | 2026-10-10 | high]. `isTeamProjectsLicensed() ?? true` at line 955. [Source: instance-ai.adapter.service.ts:955 | 2026-10-10 | high]
- Env overrides for `104`, `109`, `110` flags: [Source: packages/cli/src/posthog/index.ts:276-287 | 2026-10-10 | high]
- Setup flow flag and env override text: [Source: packages/@n8n/instance-ai/docs/configuration.md:53-58 | 2026-10-10 | high]. Flag key: [Source: packages/@n8n/api-types/src/schemas/instance-ai.schema.ts:2840 | 2026-10-10 | high]
- Workflow suggestions: the README says "No Enterprise license is required" and the flag defaults to `false`. The services have no HTTP endpoints. The module loads the event relay only when the flag is on. [Source: packages/cli/src/modules/instance-ai/workflow-suggestions/README.md:3-5 | 2026-10-10 | high] [Source: packages/cli/src/modules/instance-ai/instance-ai.module.ts:34-40 | 2026-10-10 | high]. No user-facing endpoint was found. See section 9.
- Agent evals: the gate calls `getFeatureFlags(user)` and requires `101_agent_evals === true`. [Source: packages/cli/src/modules/agent-evals/agent-evals-flag-gate.ts:21-24 | 2026-10-10 | high]. The module is declared opt-in. [Source: packages/cli/src/modules/agent-evals/agent-evals.module.ts:6-12 | 2026-10-10 | high]. `agent-evals` is NOT in the default module list. [Source: packages/@n8n/backend-common/src/modules/module-registry.ts:45-87 | 2026-10-10 | high]. It is a known module name. [Source: packages/@n8n/backend-common/src/modules/modules.config.ts:7 | 2026-10-10 | high]. The env override sets the flag. [Source: packages/cli/src/posthog/index.ts:272-274 | 2026-10-10 | high]. Env name: [Source: packages/@n8n/config/src/configs/evaluation.config.ts:52-53 | 2026-10-10 | high]. The runner also needs the Agents module switch on (default on). [Source: packages/cli/src/modules/agents/agents-settings.service.ts:29-37,74-80 | 2026-10-10 | high]
- MCP apps: [Source: packages/cli/src/modules/mcp/mcp.service.ts:294-301 | 2026-10-10 | high]. Env: [Source: packages/@n8n/config/src/configs/endpoints.config.ts:207-208 | 2026-10-10 | high]. The module `mcp` has no `licenseFlag`. [Source: packages/cli/src/modules/mcp/mcp.module.ts:12 | 2026-10-10 | high]
- Computer use flag: [Source: packages/frontend/editor-ui/src/experiments/instanceAiComputerUse/useInstanceAiComputerUseExperiment.ts:9-13 | 2026-10-10 | high]. Name: [Source: packages/frontend/editor-ui/src/app/constants/experiments.ts:127 | 2026-10-10 | high]. Store and view use it: [Source: packages/frontend/editor-ui/src/features/ai/instanceAi/instanceAiSettings.store.ts:108-111 | 2026-10-10 | high] [Source: packages/frontend/editor-ui/src/features/ai/instanceAi/views/SettingsInstanceAiView.vue:659 | 2026-10-10 | high]. Backend side has no flag: only the two admin switches. [Source: packages/cli/src/modules/instance-ai/computer-use-availability.ts:62-90 | 2026-10-10 | high]. Computer use also needs the user to run the `@n8n/computer-use` daemon on the same machine. [Source: packages/@n8n/instance-ai/docs/configuration.md:76-79 | 2026-10-10 | high]
- Web search order: proxy, then Brave key, then SearXNG, then none. [Source: packages/cli/src/modules/instance-ai/instance-ai.adapter.service.ts:3658-3700 | 2026-10-10 | high]. Admin credential `searXngApi` field `apiUrl`. [Source: instance-ai-settings.service.ts:1202-1203 | 2026-10-10 | high]. The search call uses `globalThis.fetch` with `format=json`. It has no SSRF guard, so `http://localhost` works. [Source: packages/@n8n/ai-utilities/src/web-search/searxng-search.ts:22-47 | 2026-10-10 | high]. `fetch-url` uses the enforced SSRF policy. [Source: instance-ai.adapter.service.ts:3550-3551 | 2026-10-10 | high]. The stock SearXNG image needs `json` in `search.formats`. [Source: packages/@n8n/instance-ai/docs/configuration.md:318-329 | 2026-10-10 | high]
- Sandbox: provider `n8n-sandbox` needs `N8N_SANDBOX_SERVICE_URL`. Daytona needs `DAYTONA_API_URL` and `DAYTONA_API_KEY`. No hosted default. [Source: instance-ai-settings.service.ts:1617-1631 | 2026-10-10 | high] [Source: packages/@n8n/instance-ai/docs/configuration.md:95-104 | 2026-10-10 | high]. Without a sandbox, `workflowBuilderAvailable` is false and the assistant cannot build workflows. [Source: packages/cli/src/modules/instance-ai/instance-ai.module.ts:96 | 2026-10-10 | high] [Source: configuration.md:118-121 | 2026-10-10 | high]

### 5.1 PostHog off: how flags resolve

- `PostHogClient.init()` returns early when `diagnostics.enabled` is false. No PostHog client exists. [Source: packages/cli/src/posthog/index.ts:59-64 | 2026-10-10 | high]
- Without a client, `fetchFlagsFromPostHog` returns empty flags. [Source: posthog/index.ts:217-219 | 2026-10-10 | high]
- `getFeatureFlags` never throws. It applies env overrides after PostHog. [Source: posthog/index.ts:172-206 | 2026-10-10 | high]
- Env: `N8N_FEATURE_FLAG_OVERRIDES` takes a JSON map, for example `{"091_instance_ai_computer_use":"variant","101_agent_evals":true}`. [Source: packages/@n8n/config/src/configs/feature-flags.config.ts:55-59 | 2026-10-10 | high]
- The editor accepts server-evaluated flags even when the PostHog SDK does not load. [Source: packages/frontend/editor-ui/src/app/stores/posthog.store.ts:203-212 | 2026-10-10 | high]
- Flags that no env override covers resolve to `undefined`, which means "off". This is the fail-closed default. [Source: packages/frontend/editor-ui/src/app/stores/posthog.store.ts:72-74 | 2026-10-10 | high]

Open question: do the server-evaluated flags (with overrides) reach the editor when `diagnostics.enabled` is false? The code comment says yes. The path that fills `evaluatedFeatureFlags` was not traced. See section 9.

## 6. License summary for the AI rows

- `AiService.init()` returns early when `license.isAiAssistantEnabled()` is false. [Source: packages/cli/src/services/ai.service.ts:33-37 | 2026-10-10 | high]
- Instance AI does not call `AiService.init()` on the direct self-hosted path. It only calls `isProxyEnabled()`. So an unlicensed instance with the module on works for Instance AI. [Source: packages/cli/src/modules/instance-ai/instance-ai-settings.service.ts:329-331,1671-1673 | 2026-10-10 | medium]
- The R1 choke-point patch makes `isAiAssistantEnabled()` true. With `baseUrl` empty, `isProxyEnabled()` is still false. So the patch does not turn on any hosted path.

## 7. Outbound hosts per feature

Hosts are for a local-only instance with an OpenRouter key and no `baseUrl`.

| Feature | Host | When | Can it be turned off? | Source |
|---|---|---|---|---|
| Model calls | `openrouter.ai` (path `/api/v1`) | Every chat run | Choose a local model URL instead (`N8N_INSTANCE_AI_MODEL_URL`, OpenAI-compatible) | OpenRouterApi.credentials.ts:28 |
| Model picker catalog | `models.dev` (`/api.json`) | Admin opens the model list. Cached. On failure the list is empty. | Block the host. Picker degrades. | packages/@n8n/agents/src/sdk/catalog.ts:4; instance-ai-model-catalog.service.ts:90-102,123-126 |
| n8n docs tool | `docs.n8n.io` (`/llms.txt`) | Assistant calls docs tool | No env switch found | packages/@n8n/instance-ai/src/tools/n8n-docs/registry.ts:7-8,180 |
| Builder templates CDN | `sdk-templates.n8n.io` | Sandbox builds, refresh each 24 h | `N8N_INSTANCE_AI_TEMPLATES_DISABLED=true` or `N8N_INSTANCE_AI_TEMPLATES_URL` | packages/@n8n/instance-ai/src/workspace/builder-templates-service.ts:57,145,591; configuration.md:144-146 |
| Workflow templates | `api.n8n.io` (`N8N_TEMPLATES_HOST`) | Assistant opens a template by id | `N8N_TEMPLATES_ENABLED=false` | packages/cli/src/modules/instance-ai/workflow-templates.service.ts:29-34; packages/@n8n/config/src/configs/templates.config.ts:6-11 |
| Web search | The SearXNG URL set by the admin (local) | Assistant web-search | Leave search disabled | adapter:3688-3698 |
| Web fetch | Any URL the model or user picks | Assistant fetch-url | Per-call approval and SSRF guard | adapter:3550-3551 |
| Sandbox | The sandbox service or Daytona URL set by the admin | Workflow build | Not applicable | settings.service:1617-1631 |
| Sandbox contents | Inside the sandbox, `npm install` and similar reach the npm registry | Workflow build | Control in the sandbox network | configuration.md:118-121 (reasoned) |
| LangSmith tracing | `api.smith.langchain.com` (SDK default) | Only if a LangSmith key, endpoint, or `LANGSMITH_TRACING=true` is set | `N8N_DIAGNOSTICS_ENABLED=false` forces off | packages/@n8n/instance-ai/src/tracing/langsmith-tracing.ts:797-819 |
| MCP registry list | `api.n8n.io` (`/api/mcp-servers`) | At module init and each 8 h | No env switch. `ENVIRONMENT=dev` and `N8N_MCP_SERVERS_DEV_URL` change the URL. | packages/cli/src/modules/mcp-registry/registry/mcp-registry-api.client.ts:12-14,88-97; mcp-registry-refresh.task.ts:7-33; mcp-registry.module.ts:22-29 |
| Eval mocks only | `context7.com` | Only in eval endpoints (`instanceAi:eval`) | Do not call eval endpoints | packages/cli/src/modules/instance-ai/eval/api-docs.ts:12 |
| MCP app telemetry | RudderStack via the instance proxy | Only if diagnostics are on | `N8N_DIAGNOSTICS_ENABLED=false` | packages/cli/src/modules/mcp/mcp.service.ts:309-319 |
| Hosted AI service | `ai-assistant.n8n.io` | NEVER with `baseUrl` empty | Already off | SDK dist/index.js:146 |

Note: the Chrome Web Store URL in `computer-use-prompt.ts:4` is a link shown to the user. The server does not fetch it. [Source: packages/@n8n/instance-ai/src/agent/computer-use-prompt.ts:4 | 2026-10-10 | high]

The MCP registry fetch (`api.n8n.io`) is outside the AI package. It is relevant because Instance AI MCP connections list servers from it. R1/R5 may already track `api.n8n.io`; check there before adding an item.

## 8. Code patches needed for unlicensed, PostHog-off, local-only

Result: NO code patch is required for the AI rows in the table of section 5.

Required config (no code):
1. Keep `N8N_AI_ASSISTANT_BASE_URL` unset.
2. Keep `N8N_DIAGNOSTICS_ENABLED=false`. This disables PostHog, RudderStack, and LangSmith tracing.
3. Do not set `N8N_INSTANCE_AI_MODEL`, `ANTHROPIC_API_KEY`, or any provider key in the server env. Add the OpenRouter key in the admin UI.
4. For members to use the assistant: set up a sandbox and either a search connection or "continue without search" in the admin UI.
5. Optional switches: `N8N_FEATURE_FLAG_OVERRIDES` (computer use), `N8N_MCP_APPS_ENABLED`, `N8N_AGENT_EVALS_ENABLED` + `N8N_ENABLED_MODULES=agent-evals`, `N8N_INSTANCE_AI_WORKFLOW_SUGGESTIONS_ENABLED`, `N8N_INSTANCE_AI_SEARXNG_URL`.

Optional patches (decision for the patch-plan phase, not required):
- P-AI-1: none. The R1 license choke point already unblocks folders and named versions in the adapter.
- P-AI-2 (low priority): the MCP registry call to `api.n8n.io` has no off switch. If the owner wants zero egress, patch `McpRegistryApiClient.getUrl()` or remove the system task. This is an egress decision for R2/R5, not an AI-assistant need.
- P-AI-3 (low priority): `docs.n8n.io` fetch has no off switch. Same egress decision.
- Test impact: if R1 patches `License.isLicensed()`, unit tests for `ai.service`, `frontend.service`, and `instance-ai.adapter.service` may fail. Not run.

## 9. Not verified

- Runtime behavior. No app was started. Every claim is from reading source.
- That the editor receives server-evaluated flags (including `N8N_FEATURE_FLAG_OVERRIDES`) when `diagnostics.enabled=false`. The comment at `posthog.store.ts:206-207` says so. The code path that passes `evaluatedFeatureFlags` into `init()` was not traced.
- That `091_instance_ai_computer_use` set to `"variant"` is enough to show the computer-use UI. The store check was read. A browser check was not done.
- Whether the Instance AI model picker allows a typed model name when `models.dev` is blocked. Only the empty-catalog fallback was read. The frontend picker was not read.
- The exact failure when the classic AI assistant client has `baseUrl ''` (section 4 risk). The SDK request code was read only up to the `baseUrl` lines. The result of `fetch('/v1/...')` was not tested.
- Whether any user-facing route exposes workflow suggestions. Only the README, the module, and file names were read. `self-healing-results.controller.ts` was not read.
- HOW the OpenRouter host is reached. `buildModelConfig` returns `url: ''` for `openRouterApi`, because `URL_FIELD_MAP` has no `openRouterApi` entry (`instance-ai-settings.service.ts:100-104,1500-1503`). The model factory then passes `baseURL: creds.baseURL` to `createOpenRouter` (`model-factory.ts:389`). `provider-credentials.ts:5,35,56` shows `baseURL` is optional. Whether an empty string falls back to the provider default `https://openrouter.ai/api/v1` was not checked (grep of `@openrouter/ai-sdk-provider/dist/index.js` found no match). The section 3.3 step 4 claim is therefore medium confidence. Test with a real key before relying on it. If `''` does not fall back, a small patch would be needed (map `openRouterApi` to a `url` field or default the URL).
- Whether `docs.n8n.io` and `sdk-templates.n8n.io` calls fail safely when blocked. Not traced.
- Whether the sandbox `npm install` host list is complete. Reasoned from the docs only.
- Which of these hosts R1, R2, and R5 already list. Cross-check before the final egress table.
- The list of tests that break under the R1 patch. Not run.
- Whether `N8N_ENABLED_MODULES=agent-evals` also needs a frontend module entry. Only the backend module was read.
- `packages/@n8n/instance-ai/CLAUDE.md` was read. It holds dev rules and test commands only. It has no setup claims.
