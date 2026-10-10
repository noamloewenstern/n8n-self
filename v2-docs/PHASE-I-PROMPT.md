# Brief: implement, build, and explain the custom.v2 patches

Use this file as the full brief. Writing style: ASD-STE100 (short sentences, active voice). Follow `AGENTS.md` and root `CLAUDE.md`.

## 0. Read first (in this order)

1. `v2-docs/decisions.md` (owner decisions, closed. Do not re-ask.)
2. `v2-docs/patch-inventory.md` (what to patch. Section H overrides earlier rows.)
3. `v2-docs/backlog.md` (deferred work. Do not do it, except B5 as set in section 4.)
4. `v2-docs/research/r2-licensing.md`, `r3-quotas.md`, `r4-fe-settings.md`, `r5-telemetry.md` (file:line evidence). Re-grep every line before editing. Lines may have shifted.
5. `v2-docs/IMPLEMENTATION-PROMPT.md` sections 2.3 and 4 (rules).

Branch: `custom.v2`. Base n8n 2.43.0. Research commit `55b3f5ac9e`.

## 1. Goal

A personal local n8n v2 build that:
- Runs with no license key and has all enterprise features unlocked.
- Sends no telemetry or analytics (PostHog, RudderStack, Sentry, license server, version/instance-ID reporting).
- Keeps useful in-app calls (templates, MCP registry, community catalog, `models.dev`, jsDelivr, `docs.n8n.io`).
- Marks every custom change `// CUSTOM PATCH` with the original line commented above it.

## 2. Binding rules

- **Commits:** the owner authorizes the six commits in section 3 for this task. Make no other commit. Do not push. One logical change per commit. End each message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Commit message style: Conventional Commits. Security hygiene (`AGENTS.md`): describe what the code does, not the threat.
- **Secrets:** never print, copy, or commit `.env.local` values. `.env.local` is already updated. Do not edit it unless a step needs a new key. Names only in docs.
- **Surgical:** every changed line traces to the patch inventory. Touch no other code. Do not reformat. Do not fix unrelated issues. List them for the owner instead.
- **No `any`. Avoid `as`.** Follow `AGENTS.md` TypeScript rules. Use shared utilities where they exist.
- **Subagents:** set `model` explicitly. Use `sonnet` for implementation of a written spec. Use `opus` (or the session's top model) for the final review of the license change set. Give implementers Read, Grep, Glob, Edit, Write, and scoped Bash. Give reviewers Read, Grep, Glob only.
- **Do not start the dev servers.** Do not run the Playwright or E2E suites. Do not run full-repo lint or typecheck. See section 5.
- Do not touch `v1-docs/`, `packages/quality/testing/playwright/expectations/` (pre-existing deleted files in the working tree), or `.github/`.

## 3. Phase I: implement (six commits, in order)

For each commit: re-grep the target, edit, re-read the diff, run the checks in section 5, commit.

### Commit 1: license state
`packages/cli/src/license.ts`
- `isLicensed(feature)` returns `true`, except `LICENSE_FEATURES.API_DISABLED` and `LICENSE_FEATURES.SHOW_NON_PROD_BANNER`, which return `false`.
- `getPlanName()` returns `'Enterprise'`.
- Also check `packages/cli/src/services/frontend.service.ts` (~line 572, `showNonProdBanner`). If the backend patch already yields `false`, make no FE change.
- Message: `feat(core): treat the instance as licensed (custom)`.

### Commit 2: quotas
`packages/cli/src/license.ts` `getValue()` (~line 432).
- Return `-1` for: users, active workflows (trigger), variables, team projects, insights max history, insights retention max age, insights retention prune interval, workflow-history prune, `quota:evaluations:maxWorkflows`, `quota:evaluations:concurrencyLimit`.
- AI credits: a large positive number (for example `1_000_000_000`). Never `-1`.
- Users must be exactly `-1`. A positive number blocks non-owner login (`auth.service.ts:311`). Check the quota-key constants in `LICENSE_QUOTAS` and `quota:*` names. Use `r3-quotas.md` as the map. Confirm each consumer treats `-1` as unlimited by reading its code.
- Message: `feat(core): remove license quotas (custom)`.

### Commit 3: license server and FE buttons
`packages/cli/src/license.ts`, `license.service.ts` (~lines 72, 104), FE license UI.
- `License.init()` must not create `LicenseManager`. Make `activate()`, `renew()`, `renewIfDue()` no-ops. Make sure `shutdown()` and every other method handles a missing manager. Read all uses of `this.manager` first.
- The two `enterprise.n8n.io` service methods throw `UserError` with a plain message ("License activation is disabled on this instance.").
- Hide or disable the Activate, Renew, and "request trial / enterprise key" actions in the FE. Find them: grep `license/activate`, `license/renew`, `requestTrial`, `enterprise` in `packages/frontend/editor-ui/src` (usage page and license settings). Prefer the smallest change (a flag or `v-if`). If the usage page is not reachable or has no such buttons, say so and skip.
- Message: `feat(core): disable license server calls (custom)`.

### Commit 4: audit logs flag
`packages/cli/src/services/frontend.service.ts` settings refresh (`enterprise` block). Set `auditLogs: true`. Initial value at ~line 350 may stay.
- Message: `feat(core): enable the audit logs setting (custom)`.

### Commit 5: diagnostics default
`packages/@n8n/config/src/configs/diagnostics.config.ts` (~line 18): default `enabled` to `false`. Update the default in `packages/@n8n/config/test/config.test.ts` (~line 600). Run that test file.
- Message: `feat(config): disable diagnostics by default (custom)`.

### Commit 6: local security audit
`packages/cli/src/security-audit/risk-reporters/instance-risk-reporter.ts`: `getOutdatedState()` returns `null` before any network call. No request. No instance ID. Add `// CUSTOM PATCH` with the original lines kept as comments. Remove only the imports and members your change makes unused. Run the existing test file for this reporter. Update tests that assert the network call.
- Message: `feat(core): run the security audit without network calls (custom)`.

After commit 6, verify: `git grep -n "CUSTOM PATCH"` lists every patch. Update `v2-docs/patch-inventory.md` statuses (done / skipped / differs from plan, with file:line). Update `v2-docs/decisions.md` if you deviated. Commit docs as: `docs: record v2 patch status`.

### Skipped on purpose (do not implement)
FE RBAC checks, router guards, SSO and MFA settings, v1 hosted AI URL, `engine-v2`, `type-availability-policies`, `instance-reporting`, `provisioning`, runtime egress audit.

## 4. Phase D: Docker (light)

Do this after Phase I. Source: `v2-docs/research/r8-docker.md`, backlog B5.
1. Add `**/*.local`, `**/.vscode`, `**/.idea`, `**/.remember` to `.dockerignore`. Commit: `build: exclude more local files from the Docker context`.
2. Build from a clean shell, not under dotenvx: `DOCKER_PLATFORM=linux/amd64 pnpm build:docker > build-docker.log 2>&1`. Confirm `compiled/` is fresh (rebuild with `pnpm build > build.log 2>&1` first if `packages/cli/dist` is older than the commit-1 time). Use Git Bash. If Docker is not running or the build fails for an environment reason, stop. Report the exact error. Do not work around it with workarounds that change source.
3. Check the image holds no env files: `docker run --rm --entrypoint sh n8nio/n8n:local -c "find / -xdev -name '.env*' 2>/dev/null"`. Expect no project env files.
4. Do not push. Do not copy `.env.local` into any image or build arg.
5. One light boot check is allowed: start the container with a separate throwaway env file you create in the scratchpad (no secrets), `curl` `/healthz`, then stop and remove the container. Skip if it would need more than this.

## 5. Verification (light, by design)

**Owner rule (2026-10-11): ignore unit tests.** Do not run them, fix them, or write them. A test that fails because of a custom patch is expected. The skipped test steps below are superseded. Commits 1 to 3 already include test edits. Do not extend that. Format and lint on changed files still apply.

The owner does not want a full run or E2E suite. Use the cheapest check that is sufficient:
- After each commit, re-read `git diff HEAD~1` (the diff is truth, not your summary).
- Run `pnpm exec biome format` and `pnpm exec eslint` on the changed files only (explicit paths). Follow `AGENTS.md` "Verify changes".
- Run `pnpm test <file> --maxWorkers=1` from the owning package for each test file that covers a changed file (`license.test.ts`, `license-state` tests, `frontend.service` tests, `config.test.ts`, security-audit tests). Fix tests that fail because of the patch (they assert the old behavior). Keep those test edits in the same commit. Do not delete tests.
- Run `pnpm typecheck` in `packages/cli` and `packages/@n8n/config` once at the end if it completes in reasonable time. Otherwise skip and say so.
- For "before declaring done", ask: what would break this? Check one concrete failure mode per commit (for example: non-owner login after commit 2; shutdown with no manager after commit 3).

**Say plainly what is unverified.** Anything you did not run or could not confirm goes into the report under "Not verified". Known open items: the license SDK sends nothing without a cert (read from minified code only); the FE handling of `-1` quotas; hard load of `/saml/onboarding`; the OpenRouter `url: ''` fallback; whether `auditLogs: true` shows anything in the UI; the env feature flags actually enable the features. Do not claim these work. Tell the owner.

## 6. Final deliverable: an Artifact overview

After all commits, publish one Artifact (private) that explains the work for the owner. Load the `artifact-design` skill first. The page is read-only: no input needed, so no interactive controls. Content:
1. One-paragraph summary: what the build is now.
2. A table of the commits (SHA short, title, files, one-line why).
3. Per patch: what changed (before and after, short code snippet), why, how it affects behavior, and risk.
4. What changed in `.env.local` / `.env.local.example` (names only, no values for secrets, which are none).
5. What was skipped on purpose and why (v2 handles it, or owner decision).
6. "Not verified" list and what the owner should check by hand (concrete clicks: for example open Settings > Usage; confirm Activate button is gone; open Insights; check the audit log menu).
7. Where docs live (`v2-docs/`), and the backlog items.
Reference commit SHAs and `file:line`. Keep it scannable. Give the owner the artifact link.

## 7. Report (chat, concise)

End with: commits made (SHA and title), checks run and results, deviations from the plan, unverified items, the artifact link, and any question only the owner can answer. No long narration.
