# R3: Quotas (v1 hardcoded values vs v2)

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: read `v1-docs/custom-full.diff`, then Read/Grep every v2 path. No source file was edited. `.env.local` was not read. No app was started.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.
Builds on R1 (`v2-docs/research/r1-patch-map.md`). R1 content is not repeated. Only quota facts are added.

## 1. How v2 reads a quota

One function feeds all numeric quotas: `License.getValue(feature)`. It returns `this.manager?.getFeatureValue(feature)`. Without a license, the result is `undefined`. [Source: packages/cli/src/license.ts:432-434 | 2026-10-10 | high]

Two read paths use it:

- Path A. `LicenseState.getMax*()` calls `LicenseState.getValue()`. That calls `licenseProvider.getValue()`. The provider is `License`. [Source: packages/@n8n/backend-common/src/license-state.ts:47-51 | 2026-10-10 | high]
- Path B. Deprecated `License.getUsersLimit()`, `getTriggerLimit()`, `getVariablesLimit()`, `getAiCredits()`, `getWorkflowHistoryPruneLimit()`, `getTeamProjectLimit()` call `License.getValue()` directly. [Source: packages/cli/src/license.ts:469-500 | 2026-10-10 | high]

The quota key names are in one table. [Source: packages/@n8n/constants/src/index.ts:64-76 | 2026-10-10 | high]
`UNLIMITED_LICENSE_QUOTA = -1`. [Source: packages/@n8n/constants/src/index.ts:79 | 2026-10-10 | high]

The e2e controller already overrides `getValue` on the `License` instance (`license.getValue = getFeatureValue`). This proves that `getValue` is the complete seam. [Source: packages/cli/src/controllers/e2e.controller.ts:227 | 2026-10-10 | high]

## 2. Rule that decides the patch value: -1 is not the same as "large"

Some code tests `=== -1` to mean "unlimited". A large number such as `10_001` is treated as a real limit there. This matters for the user quota and for the team project quota. Details are in section 4.

Conclusion: for every quota, prefer `-1` where the consumer supports it. Use a large positive number only where `-1` is wrong (AI credits, insights days, explained below).

## 3. Quota table (v1 value, v2 location, v2 default, patch)

"v2 default" is the value when `getValue` returns `undefined` (no license).

| # | Quota (key) | v1 hardcode | v2 getter and file:line | v2 default | Read path | Minimal change to unlimited |
|---|---|---|---|---|---|---|
| 1 | Users `quota:users` | `LicenseState.getMaxUsers()` = `10_001` | `license-state.ts:233-235` (A). `license.ts:470-472` `getUsersLimit()` (B) | `-1` (unlimited) | A and B | Do not patch. Default is already `-1`. Patch must not return a positive number (see 4.1). |
| 2 | Active workflows (triggers) `quota:activeWorkflows` | `getMaxActiveWorkflows()` = `10_001` | `license-state.ts:237-239` (A). `license.ts:475-477` `getTriggerLimit()` (B) | `-1` | A and B | Do not patch. Default is `-1`. Display only (see 4.2). |
| 3 | Variables `quota:maxVariables` | `getMaxVariables()` = `10_001`. FE `variables.limit` = `10_000` | `license-state.ts:241-243` (A). `license.ts:480-482` (B) | `-1` | A and B | Do not patch. Default is `-1`. |
| 4 | AI credits `quota:aiCredits` | `getMaxAiCredits()` = `10_000_001`. FE `aiCredits.credits` = `1_000_000_000` | `license-state.ts:245-247` (A). `license.ts:485-487` (B) | `0` | A and B | Return a large number (for example `1_000_000_000`) from `getValue`. `-1` is not safe here: FE shows `credits` as a number (see 4.5). |
| 5 | Workflow history prune `quota:workflowHistoryPrune` | `getWorkflowHistoryPruneQuota()` = `UNLIMITED_LICENSE_QUOTA` | `license-state.ts:249-251` (A). `license.ts:490-495` `getWorkflowHistoryPruneLimit()` (B) | A: `-1`. B: `DEFAULT_WORKFLOW_HISTORY_PRUNE_LIMIT` = `24` hours | A and B | Return `-1` from `getValue`. Path B default is `24`, not `-1` (see 4.3). This is a difference from what R1 states for 1.2e. |
| 6 | Insights max history `quota:insights:maxHistoryDays` | `getInsightsMaxHistory()` = `30`; service forced `MAX_SAFE_INTEGER` | `license-state.ts:253-255` (A). Callers: `insights.settings.ts:26-28`, `insights.service.ts:391-393` | `7` | A | Return `-1` from `getValue`. Both callers map `-1` to `MAX_SAFE_INTEGER`. |
| 7 | Insights retention max age `quota:insights:retention:maxAgeDays` | `getInsightsRetentionMaxAge()` = `180` | `license-state.ts:257-259` | `180` | A | No patch. Only the telemetry relay reads it (`telemetry.event-relay.ts:2008`). |
| 8 | Insights retention prune interval `quota:insights:retention:pruneIntervalDays` | `getInsightsRetentionPruneInterval()` = `120` | `license-state.ts:261-263` | `24` | A | No patch. Only the telemetry relay reads it (`telemetry.event-relay.ts:2009`). |
| 9 | Team projects `quota:maxTeamProjects` | `getMaxTeamProjects()` = `10_001`. FE `projects.team.limit` = `10_000` | `license-state.ts:265-267` (A). `license.ts:498-500` (B) | `0` | A and B | Return `-1` from `getValue`. `isTeamProjectsLicensed()` accepts `-1` or `> 0` (`license-state.ts:269-272`). Backend and FE both handle `-1` (see 4.4). |
| 10 | Evaluations: workflows `quota:evaluations:maxWorkflows` | `getMaxWorkflowsWithEvaluations()` = `10_001` | `license-state.ts:274-276` | `0` (= feature disabled) | A | Return `-1` from `getValue`. All consumers handle `-1` (see 4.6). |

Note on the e2e defaults (reference only): the same table exists for tests with different values, for example team projects `0`, insights `7`, evaluations `1`. [Source: packages/cli/src/controllers/e2e.controller.ts:152-168 | 2026-10-10 | high]

[Source: packages/@n8n/backend-common/src/license-state.ts:233-276 | 2026-10-10 | high]

## 4. Consumer notes (why each patch value is safe or unsafe)

### 4.1 Users: keep `-1`, never a positive number

`License.isWithinUsersLimit()` returns `getUsersLimit() === UNLIMITED_LICENSE_QUOTA`. It is true only when the quota is `-1`. [Source: packages/cli/src/license.ts:560-564 | 2026-10-10 | high]

Callers of `isWithinUsersLimit()` that block when it is false:

- Login of non-owner users: `ForbiddenError(USERS_QUOTA_REACHED)`. [Source: packages/cli/src/auth/auth.service.ts:310-313 | 2026-10-10 | high]
- Invite emails. [Source: packages/cli/src/services/user.service.ts:529-534 | 2026-10-10 | high]
- Password reset (two places). [Source: packages/cli/src/controllers/password-reset.controller.ts:97,184 | 2026-10-10 | high]
- Auth controller. [Source: packages/cli/src/controllers/auth.controller.ts:230-232 | 2026-10-10 | high]

Public API user endpoints return 403 when the quota is not `-1`:

- [Source: packages/cli/src/public-api/v1/shared/middlewares/global.middleware.ts:176-180 | 2026-10-10 | high]
- [Source: packages/cli/src/public-api/public-api-controller.registry.ts:261-264 | 2026-10-10 | high]

Hazard: the v1 patch set `LicenseState.getMaxUsers()` to `10_001`. In v2, that makes `public-api-controller.registry.ts:261` return 403 for the user quota middleware. v1 did not touch `License.getUsersLimit()`, so the login paths stayed safe. Do not copy the v1 value `10_001` for users. Leave the default `-1`.
Confidence for the v1 side effect: medium (reasoned from code, not run).

FE: `userManagement.quota` is `license.getUsersLimit()` (`frontend.service.ts:269,501`). The FE treats `-1` as unlimited: `userQuota.value === -1 || userQuota.value > allUsers.length`. [Source: packages/frontend/@n8n/stores/src/users.store.ts:147 | 2026-10-10 | high]

### 4.2 Active workflows: display only

No enforcement code was found. Readers: usage page data (`license.service.ts:54-55`), telemetry (`telemetry/index.ts:254`), and FE usage store. FE shows "unlimited" when the limit is below `0`. [Source: packages/frontend/editor-ui/src/features/settings/usage/views/SettingsUsageAndPlan.vue:295 | 2026-10-10 | medium]

### 4.3 Workflow history prune: two defaults

Path A default is `-1`. Path B default is `24` hours. [Source: packages/@n8n/constants/src/index.ts:81 | 2026-10-10 | high]
The real prune code uses path B: `getWorkflowHistoryPruneTime()`. If the license value is `-1`, it uses the config value. Otherwise it uses `min(config, license)`. [Source: packages/cli/src/workflows/workflow-history/workflow-history-helper.ts:12-29 | 2026-10-10 | high]
With no patch, history is pruned after 24 hours when the config is `-1`. A `getValue` patch to `-1` gives the config value. Check the config key `workflowHistory.pruneTime` in the Docker phase.

### 4.4 Team projects: `-1` works end to end

- Backend: `insertTeamProjectWithAdmin` skips the count check when `limit === -1`. [Source: packages/@n8n/db/src/repositories/project.repository.ts:29-48 | 2026-10-10 | high]
- Caller: `createTeamProject`. [Source: packages/cli/src/services/project.service.ee.ts:514-526 | 2026-10-10 | high]
- FE: `hasUnlimitedProjects = teamProjectsLimit === -1`. [Source: packages/frontend/editor-ui/src/features/collaboration/projects/projects.store.ts:80-82 | 2026-10-10 | high]
- FE value comes from `frontend.service.ts:675` (`getTeamProjectLimit()`), default `0`. With a `getValue` patch, the FE gets `-1`.

### 4.5 AI credits and AI gateway

- `getMaxAiCredits()` has no consumer except the telemetry relay (`telemetry.event-relay.ts:2005`). [Source: packages/cli/src/events/relays/telemetry.event-relay.ts:2002-2011 | 2026-10-10 | high]
- `License.getAiCredits()` feeds `settings.aiCredits.credits`, only when `isAiCreditsEnabled` is true (`frontend.service.ts:634-639`). `aiCredits.setup` is `!!aiAssistant.baseUrl`, so it stays false while `baseUrl` is empty (R1 category 6). The credit number then has no visible effect.
- Not verified: how the FE renders a negative `credits`. Use a large positive number to avoid the question.

### 4.6 Evaluations: `-1` is handled everywhere

| Consumer | Behavior at `-1` | Source |
|---|---|---|
| Public API gate `assertEvaluationsEnabled` | Blocks only when `=== 0`. `-1` passes. | `evaluations.public.controller.ts:272-276` |
| `evaluation-config.service.ts` first-config quota | Checks only when `limit > 0`. `-1` is skipped. | `evaluation-config.service.ts:38-48` |
| `evaluation-test-run.service.ts` | Returns early when `=== -1`. | `evaluation-test-run.service.ts:56-68` |
| FE `isEvaluationEnabled` | `quota !== 0`. | `features/ai/evaluation.ee/evaluation.store.ts:26` |
| FE license check | `workflowsWithEvaluationsLimit !== 0`. | `useEvaluationsLicense.ts:9` |
| FE wizard and root view | Treat `-1` as unlimited. | `SetupWizard.vue:36`, `EvaluationsRootView.vue:77` |

All sources above: [2026-10-10 | high], paths relative to `packages/cli/src/` for the first three and `packages/frontend/editor-ui/src/` for the last three.

## 5. New v2 quotas that v1 never had

| Quota | Key | v2 location | v2 default | Read path | Patch |
|---|---|---|---|---|---|
| Evaluation concurrency | `quota:evaluations:concurrencyLimit` | `license-state.ts:287-289` (A). `evaluation-concurrency.helper.ts:19,40-45` (direct `license.getValue`) | `undefined`, then plan tier default | A, and direct | See 5.1. |
| AI gateway budget | `quota:aiGatewayBudget` | `frontend.service.ts:648` (direct `license.getValue`). FE `settings.store.ts:180` | `0` | direct | None needed while `aiAssistant.baseUrl` is empty. The block at `frontend.service.ts:641-651` needs `baseUrl`, so it never runs. |
| Instance AI credits (cloud plan data only) | `quota:instanceAiCredits` | Not in `LICENSE_QUOTAS`. Read from cloud plan data in `trialIntroModal.store.ts:123` and `TrialIntroModal.vue:70` | n/a | FE cloud plan store | None. Cloud-only experiment. |

### 5.1 Evaluation concurrency: a trap when `planName` becomes `'Enterprise'`

`resolveEvaluationConcurrencyLimit` order: (1) env `N8N_CONCURRENCY_EVALUATION_LIMIT`, (2) license quota (`0` is ignored, `-1` and positive values count), (3) plan tier default. [Source: packages/cli/src/evaluation.ee/evaluation-concurrency.helper.ts:64-77 | 2026-10-10 | high]
Tier defaults: `Community: 1`, `Pro: 1`, `Business: 3`, `Enterprise: 5`. [Source: packages/cli/src/evaluation.ee/evaluation-concurrency.helper.ts:11-16 | 2026-10-10 | high]
If the patch sets `getPlanName()` to `'Enterprise'` and `getValue('quota:evaluations:concurrencyLimit')` stays `undefined`, the limit is `5`. To remove the cap, return `-1` for this key.
Consumer logic: the test runner caps concurrency only when `evaluationLimit > 0` (`test-runner.service.ee.ts:575-579`), so `-1` is unlimited there. [Source: packages/cli/src/evaluation.ee/test-runner/test-runner.service.ee.ts:575-579 | 2026-10-10 | high]
Config default for the env path is `-1`. [Source: packages/@n8n/config/src/configs/executions.config.ts:30 | 2026-10-10 | high]
Other callers of the resolver: `concurrency-control.service.ts:120`, `agent-eval-runner.service.ts:317`, `frontend.service.ts:226,546`.
Not verified: how `ConcurrencyControlService` handles `-1` from the license path (line 120 was not read in full).

## 6. Recommended minimal change (single seam)

Patch `License.getValue()` (`packages/cli/src/license.ts:432-434`). Return a fixed map for numeric keys, and keep other keys on the normal path. Suggested map:

| Key | Return |
|---|---|
| `quota:users` | `-1` |
| `quota:activeWorkflows` | `-1` |
| `quota:maxVariables` | `-1` |
| `quota:workflowHistoryPrune` | `-1` |
| `quota:maxTeamProjects` | `-1` |
| `quota:evaluations:maxWorkflows` | `-1` |
| `quota:evaluations:concurrencyLimit` | `-1` |
| `quota:insights:maxHistoryDays` | `-1` |
| `quota:aiCredits` | `1_000_000_000` |
| `planName` | `'Enterprise'` |

This fixes path A and path B together. v1 patched only path A (LicenseState) and hardcoded the FE settings object. v2 needs no FE settings hardcodes for quotas.

Keys that need no entry: `quota:insights:retention:*` (telemetry only), `quota:aiGatewayBudget` (dead while `baseUrl` is empty).

Alternative if `getValue` must stay untouched: patch the six `LicenseState.getMax*` and six deprecated `License.get*Limit` functions. That is 12 edits and path B can drift. The single seam is better.

Unit test impact: `license.test.ts` and `license-state.test.ts` assert the default values. They will fail after the patch. Not run.

## Not verified

- Runtime behavior. No app was started. All claims come from source reading.
- FE rendering of `aiCredits.credits` when it is huge or negative.
- FE rendering of `variables.limit = -1` in the variables UI (R1 also lists this).
- That `FrontendSettings` Zod schema accepts `-1` for `enterprise.projects.team.limit`, `variables.limit` and `userManagement.quota`. Only the TypeScript consumers were read.
- `ConcurrencyControlService` behavior with a license value of `-1` (`concurrency-control.service.ts:55-57,120`).
- Config key and default for `workflowHistory.pruneTime` (read only through the helper).
- That `activeWorkflows` has no enforcement path. Grep found only display and telemetry uses. `ActiveWorkflowManager` was not read.
- The v1 side effect on the public API user endpoints (4.1). Reasoned from `getMaxUsers() = 10_001`; not run.
- Other v2 quota-like limits that are not license keys (for example AI builder, agent, or data-table limits in config classes). Only `license`-based quotas were searched.
- Whether `getFeatureValue` in the `@n8n_io/license-sdk` filters keys. SDK source in `node_modules` was not read.
- `license.test.ts`, `license-state.test.ts`, and `frontend.service.test.ts` breakage.
