# R9: Disable GitHub CI (category 8)

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: Grep and Read only. No file edited except this one. `.env.local` not read. No GitHub API called.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.

## Answer in brief

1. Renaming all of `.github` to `.bak_github` does NOT break the build, the dev server, or the unit tests. It breaks two pnpm scripts, one optional build step, and several docs and agent skills. It also makes a very large rename diff against upstream.
2. Renaming only `.github/workflows/` breaks almost nothing locally. It is the smaller change.
3. Disabling Actions in the GitHub repository settings (or by API) changes zero local files. It is the least-breaking option. Do not call the API from this research task.
4. Recommendation: use the settings/API disable as the main control. Add a `workflows` rename only if the owner wants file-level proof that no workflow can run. Do not rename all of `.github`.

## What `.github` holds (tracked files)

Count by `git ls-files .github`: `workflows` 111, `scripts` 101, `actions` 9, `test-metrics` 2, `ISSUE_TEMPLATE` 2, `poutine-rules` 1, plus 8 root files (`WORKFLOWS.md`, `pull_request_title_conventions.md`, `pull_request_template.md`, `docker-compose.yml`, `DEVELOPING_V3.md`, `CLAUDE.md`, `CI-TELEMETRY.md`, `actionlint.yml`). Total 234.
[Source: `git ls-files .github` | 2026-10-10 | high]

Workflow triggers (grep of `.github/workflows/*.yml`): 59 files have a trigger key (`schedule`, `push`, `pull_request`, `pull_request_target`, `release`, `workflow_run`). 68 files have no `workflow_call`. 43 files have `workflow_call`. The two sets overlap. Only the trigger files can start on their own. [Source: grep of `.github/workflows/*.yml` | 2026-10-10 | medium] (the regex is coarse; the number is an upper bound)

## Local references: what breaks if `.github` is renamed to `.bak_github`

| # | Reference | What it does | Effect of full rename | Severity |
|---|---|---|---|---|
| 1 | `package.json:74` `check:cubic-config` runs `node .github/scripts/quality/check-cubic-config.mjs` | Validates `cubic.yaml` | Fails (file not found). | Low (review-tool lint only) |
| 2 | `package.json:102` `install-workflow-scripts` runs `pnpm install --dir .github/scripts ...` | Installs CI script deps | Fails (dir not found). `check:cubic-config` calls it first (line 74). | Low |
| 3 | `scripts/build-n8n.mjs:562-577` SBOM and license step uses `.github/scripts` | Only when `N8N_GENERATE_LICENSES=true` (line 568) | With the flag: install fails. Outside CI the catch block (578-587) only warns, because it throws only when `CI=true`. Without the flag: no effect. | Low |
| 4 | `lefthook.yml:45-47` `actionlint_check`, glob `.github/workflows/*.{yml,yaml}` | Pre-commit lint of staged workflow files | Glob matches nothing, hook is skipped. No failure. | None |
| 5 | `knip.ts:68` workspace key `'.github/scripts'` | Dead-code scan config for CI scripts | Config points at a missing dir. Knip may print a hint or error. Not tested. | Low (unverified) |
| 6 | `packages/quality/policy/code-health/src/utils/workflow-scanner.ts:27` `fg('.github/workflows/*.{yml,yaml}')` | Finds workflow files for rule `workflow-pr-target-safety` | Returns an empty list. The rule loop (`workflow-pr-target-safety.rule.ts:42-48`) then does nothing. No violation. | None |
| 7 | `packages/quality/testing/playwright/scripts/select-affected-e2e.mjs:28,41-43` reads `.github/test-metrics/e2e-impact-map.json` | Chooses E2E specs to run | `existsSync` check returns `null` (fail-open, "run all"). | None |
| 8 | `packages/quality/testing/playwright/janitor.config.mjs:77` `metricsPath: '../../../../.github/test-metrics/playwright.json'` | Janitor baseline path | Janitor hook is `skip: true` (`lefthook.yml:89-94`). Manual `janitor` runs may miss the file. | Low |
| 9 | `.poutine.yml:9,48-63` | Poutine CI-security scan config | Points at missing paths. Only a CI/manual tool. | None |
| 10 | `cubic.yaml:201` ignores `.github/**` | Review-bot config | No local effect. | None |
| 11 | `OWNERS:17,258-263` | Owner map. `.github/scripts/owners/owners.mjs --check` validates it in CI | Local use only by agent skills (row 13). | None |
| 12 | `.prettierignore:12`, `.gitignore:27`, `biome.jsonc:41` | Ignore patterns | Patterns for missing paths are harmless. | None |
| 13 | `.agents/skills/create-pr/SKILL.md:77,95`, `.agents/skills/community-pr-readiness-check/SKILL.md:107-116`, `reference/teams.md:19,27`, `reference/checks.md:72,98` | Agent skills read `.github/pull_request_template.md`, `pull_request_title_conventions.md`, `scripts/owners/owners.mjs` | These skills fail to find their inputs. | Medium for agent flows only |
| 14 | `.agents/review-rules/README.md:69-73`, `.agents/review-rules/qa-dx/workflow-safety.md:3` | Docs refer to `.github` paths | Stale docs. | None |
| 15 | `CONTRIBUTING.md:128,519,610`, `.devcontainer/codespaces/README.md:227,257,261` | Doc links | Broken links. | None |
| 16 | `scripts/smoke-n8n-image.mjs:138` `'../.github/scripts/docker/kafka-native-smoke-check.mjs'` | Image smoke test | Kafka smoke check cannot find its script. Only on image smoke runs. Check what the line does before running `smoke-n8n-image`. | Low (unverified) |
| 17 | `scripts/codespace-preview/*.mjs` | Message strings point to `.github/WORKFLOWS.md` | Text only. | None |

Citations:
[Source: package.json:74,102 | 2026-10-10 | high]
[Source: scripts/build-n8n.mjs:562-587 | 2026-10-10 | high]
[Source: lefthook.yml:45-47 | 2026-10-10 | high]
[Source: knip.ts:68-78 | 2026-10-10 | high]
[Source: packages/quality/policy/code-health/src/utils/workflow-scanner.ts:26-32 | 2026-10-10 | high]
[Source: packages/quality/policy/code-health/src/rules/workflow-pr-target-safety.rule.ts:42-48 | 2026-10-10 | high]
[Source: packages/quality/policy/code-health/src/index.ts:44,159 | 2026-10-10 | high]
[Source: packages/quality/testing/playwright/scripts/select-affected-e2e.mjs:28,41-43 | 2026-10-10 | high]
[Source: packages/quality/testing/playwright/janitor.config.mjs:77 | 2026-10-10 | high]
[Source: .poutine.yml:9,48-63 | 2026-10-10 | high]
[Source: cubic.yaml:201 | 2026-10-10 | high]
[Source: OWNERS:17,258-263 | 2026-10-10 | high]
[Source: .prettierignore:12, .gitignore:27, biome.jsonc:41 | 2026-10-10 | high]
[Source: scripts/smoke-n8n-image.mjs:138 | 2026-10-10 | medium]

### Things that do NOT break

- No `pnpm build`, `dev:be`, `dev:fe:editor`, `build:docker` command reads `.github` (grep of root `package.json` found only lines 74 and 102). [Source: package.json:74,102 | 2026-10-10 | high]
- No file in `docker/` references `.github/` (grep of `docker/**` found no match). So `pnpm build:docker` is not affected. [Source: grep `\.github/` over `docker/**` | 2026-10-10 | medium]
- `.githooks/` has no `.github` or `actionlint` reference. [Source: grep over `.githooks/**` | 2026-10-10 | high]
- Packages with `.github` strings are unrelated to this repo's own `.github`: `packages/@n8n/node-cli/src/commands/release.ts:59,141,153` writes `.github/workflows/publish.yml` into a user project from a template. `packages/@n8n/agents/src/skills/registry.ts:21` lists `.github` as an ignored directory name. `packages/@n8n/instance-ai/scripts/build-snapshot.cjs:6` is a comment. [Source: those files | 2026-10-10 | high]
- Code-health rule tests build their own temp `.github/workflows` tree, so they do not need the real one. [Source: packages/quality/policy/code-health/src/rules/workflow-pr-target-safety.rule.test.ts:14 | 2026-10-10 | high]

## Effects outside local run

- GitHub reads these only under `.github`: `workflows/`, `ISSUE_TEMPLATE/`, `pull_request_template.md`, and `CODEOWNERS` if present. A full rename removes issue and PR templates on the fork. A `workflows`-only rename keeps them. (GitHub behavior; not verified here.)
- `.github/DEVELOPING_V3.md` is a plain doc. It links `./workflows/util-sync-master-to-3x.yml` and `./workflows/build-v3-nightly.yml` (lines 130, 215) and cites `.github/scripts/sync-conflict-owners.mjs` (208) and `.github/test-metrics/e2e-impact-map.json` (142). Rename of `workflows` breaks those two links. No code reads this file. [Source: .github/DEVELOPING_V3.md:130,142,208,215,243 | 2026-10-10 | high]
- Upstream sync cost. Every future `git merge` from upstream touches `.github`. Upstream edits workflow and script files often. A full rename makes 234 renames on this branch. Git rename detection may follow them, but modify/delete conflicts are likely on each merge. A `workflows`-only rename limits this to 111 files. A settings/API disable makes none. (Reasoned from git behavior; not tested.)
- The v1 history confirms the conflict risk. v1 renamed to `.bak_github`, and a v1 master commit `2ad9c80e51` renamed to `.github.bak`; the cherry-pick aborted. [Source: v1-docs/custom.md:117-124 | 2026-10-10 | high]
- The v1 note says upstream master still had `.github/` with "14 entries". That count is stale. The v2 tree has 234 tracked files. [Source: v1-docs/custom.md:124; `git ls-files .github` | 2026-10-10 | high]

## Options compared

| Option | Local breakage | Merge-conflict cost | Reversible | Proves no workflow can run |
|---|---|---|---|---|
| A. Rename `.github` to `.bak_github` | Rows 1, 2, 3 (flag only), 8, 13, 14, 15, 16. Possible knip noise (row 5). | High (234 files) | Yes (rename back) | Yes, plus it removes issue/PR templates |
| B. Rename only `.github/workflows` (e.g. to `.github/workflows.bak`) | Code-health scan finds nothing (OK). Lefthook glob matches nothing (OK). Broken links in `DEVELOPING_V3.md`, `WORKFLOWS.md`, `.devcontainer/codespaces/README.md`. `.poutine.yml` paths stale. Local build and test unaffected. | Medium (111 files) | Yes | Yes |
| C. Edit each trigger to `on: workflow_dispatch` | None for local run. But `workflow_call` reusable files must stay as they are. | Highest (about 59 edited files, edited content, not renames; each upstream change conflicts) | Hard | Mostly (manual dispatch still possible) |
| D. Disable Actions in repo settings, or by API | None | None | Yes (toggle) | Yes, at GitHub; nothing in the files |
| E. Delete `.github/workflows` | Same as B | Same as B, but history loses the files | Via git only | Yes |

Notes on C: a `workflow_dispatch`-only file can still be started by hand. A `workflow_call` file needs its caller. Editing triggers adds diff in 59 files and gains nothing over D. Not recommended.

## Prior API disable

The owner's brief says Actions were disabled through the GitHub API earlier. This research task cannot confirm that state, and it must not call the API. If that disable still holds, option D is already done, and category 8 needs no file change at all. The owner can check the state in the repo UI at Settings > Actions > General. [Source: task brief | 2026-10-10 | low]

## Recommendation

1. Least-breaking: option D. Keep the API/settings disable. Zero local files change. Zero upstream merge cost. Nothing in lefthook, pnpm scripts, `scripts/*`, code-health, templates, or `DEVELOPING_V3.md` is touched.
2. If the owner wants file-level disable too: option B, rename only `.github/workflows` to a name outside the `workflows` path. Keep `.github/scripts`, `.github/actions`, `.github/test-metrics`, templates, and docs in place. This keeps `check:cubic-config`, `install-workflow-scripts`, the SBOM step, the janitor path, the PR-template skills, and the impact map working.
3. Do not use option A. It breaks two pnpm scripts and the agent PR skills for no extra safety over B.
4. This differs from `IMPLEMENTATION-PROMPT.md:54` ("`.github` renamed to `.bak_github`"). The owner said yes to item 8 but also asked R9 to pick the scope. Ask the owner to confirm the change from A to D (or B) before the build phase.
5. If B is chosen, no code change is needed. Optional cleanup in the same change: none. Do not edit `lefthook.yml`, `knip.ts`, `.poutine.yml`, or code-health. (Edits to them would add upstream merge conflicts for no gain.)
6. Check before or after B: run `git status` for the rename and `pnpm exec lefthook run pre-commit` on a dry change to confirm the hooks skip cleanly.

## Not verified

- No command was run. Every effect above is from reading source. Neither the rename nor any script was executed.
- Whether knip fails, warns, or ignores the missing `.github/scripts` workspace (row 5).
- What `scripts/smoke-n8n-image.mjs:138` does with the Kafka script when the file is missing (row 16). Only the path string was read.
- Whether a rename keeps `git merge` conflict-free in practice. Reasoned only.
- Current GitHub-side state: whether Actions are disabled now, whether this fork has `CODEOWNERS`, whether GitHub still reads issue/PR templates from a renamed folder. No API or UI was checked.
- The count of 59 trigger files is from a coarse regex. Some matches may be inside comments, or in `workflow_call` inputs.
- Grep covered `package.json`, `lefthook.yml`, `knip.ts`, root config files, `scripts/`, `packages/` (ts, mjs, js, cjs, json, vue), `.githooks/`, `.agents/`, `.claude/`, `docker/`, `.vscode/`. File types such as `.sh`, `.toml`, `.md` inside `packages/` and `.github/scripts` internals were not searched in full. Two `Glob` and `Grep` calls on `packages/quality` were truncated by the head limit (mock JSON noise).
- Whether other `.github/scripts/*.mjs` are called from `packages/*` build scripts through a built path string (for example `path.join(root, '.github')` without a slash). The regex needed a quote or slash next to `.github`.
- The `.github/docker-compose.yml`, `.github/actionlint.yml`, `.github/CLAUDE.md` consumers were not traced.
