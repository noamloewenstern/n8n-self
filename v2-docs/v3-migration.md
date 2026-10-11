# v3 migration (pending)

Living doc. Update it on every v3 status change and on every n8n bump.

## Status (checked 2026-10-11)

- **Decision:** stay on v2 (`2.42.6` on `latest`). Do not move to v3 yet. Pin Docker deploys to an exact version, not `latest`.
- **Docs say v3 is released.** The n8n v3 breaking-changes page says 3.0 "has been released" with no date. [Source: https://docs.n8n.io/changelog/v30-breaking-changes | 2026-10-11 | confidence: medium]
- **Docker Hub has no stable 3.x tag.** `3`, `3.0`, `3.0.0` and `3.0.0-rc.1` return 404. Newest stable is `2.43.0`. Only `v3-nightly-*` tags exist. [Source: https://hub.docker.com/v2/repositories/n8nio/n8n/tags/ | 2026-10-11 | confidence: high]
- **Open conflict:** docs page vs. registry. Resolve before acting. Check the n8n release notes and the Docker Hub tags.
- **Repo guide:** v3 is "an operational release" with breaking changes and removals, planned for ~October 2026. [Source: .github/DEVELOPING_V3.md | 2026-10-11 | confidence: high]

## Stated benefits

No new user-facing features are listed. v3 is cleanup plus security defaults.

- Encryption key rotation on by default. Can be turned off from 2.40.3. [Source: https://docs.n8n.io/changelog/v30-breaking-changes | 2026-10-11 | confidence: medium]
- SSRF block list extended: `::/128`, `100.64.0.0/10`, `2002::/16`, `64:ff9b::/96`. [Source: same | 2026-10-11 | confidence: medium]
- Compression limits: 256 MiB decompressed, 1,000 zip entries. [Source: same | 2026-10-11 | confidence: medium]
- Slack API credential requires a signing secret. Slack Trigger workflows fail until it is set. [Source: same | 2026-10-11 | confidence: medium]
- Simpler config (see Configuration below).

## Breaking changes that affect this fork

### Deployment
- Self-hosting must use Docker. `npm` / `npx n8n` installs are dropped. Our Dockerfile path (`docker/images/n8n/Dockerfile.custom`) stays valid. [Source: https://docs.n8n.io/changelog/v30-breaking-changes | 2026-10-11 | confidence: medium]
- `n8n-node dev` needs Docker or Podman. Only relevant if we build community nodes.

### Removed nodes (check workflows for use)
- Function, Function Item, Item Lists (legacy)
- LangChain Code (legacy), HTTP Request Tool (legacy)
- Cron and Interval
- HTML Extract, iCalendar
- Convert to/from binary data, Read/Write Binary File(s), Read PDF
- Workflow Trigger, Manual Chat Trigger, Chat Messages Retriever
- Orbit, SerpApi, Motorhead, Zep (some have no replacement)
- Legacy OpenAI, OpenAI Assistant, OpenAI Model
- AI Transform (auto-migrates to Code node)
- Several document loaders and vector store Insert/Load nodes
- [Source: https://docs.n8n.io/changelog/v30-breaking-changes | 2026-10-11 | confidence: medium]

### Removed helpers and options
- `$getPairedItem` removed. Use `$('<node>').item`, `.itemMatching()` or `.pairedItem()`.
- Execute Sub-workflow: Local File and URL sources removed.
- `$evaluateExpression()` no longer works in insecure-mode task runners.
- AI Agent v1 and older modes removed. Use Tools Agent.
- [Source: same | 2026-10-11 | confidence: medium]

### Behavior changes
- Always Output Data: multi-output nodes (If, Switch) add empty items only when every output is empty.
- Gmail Trigger v1–1.3 run as v1.4. Drafts skipped unless enabled; sent or scheduled emails no longer trigger.
- Webflow OAuth2: Legacy toggle default off. Reconnected credentials request v2 scopes.
- Chat Trigger WebSocket frames are JSON with a `type` field. Custom clients must parse them.
- [Source: same | 2026-10-11 | confidence: medium]

### Retired capabilities
- Chat Hub off by default. Re-enable with `N8N_ENABLED_MODULES`. Removed in 4.0.
- Import from URL removed from the editor.
- Ask AI tab removed from the Code node.
- [Source: same | 2026-10-11 | confidence: medium]

### Configuration (env and paths)
- `N8N_PRE_EXECUTE_ERROR_CREATES_EXECUTION` removed.
- `~/.n8n/binaryData` renamed to `~/.n8n/storage`. n8n will not start if both exist.
- `N8N_DEFAULT_BINARY_DATA_MODE=default` invalid; now means `filesystem`.
- `N8N_UNVERIFIED_PACKAGES_ENABLED` defaults to `false`.
- `N8N_RUNNERS_TASK_TIMEOUT` default 60s (was 300s).
- `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` removed. Manual runs always go to workers in queue mode.
- `N8N_DB_PING_TIMEOUT` removed. Use `DB_PING_TIMEOUT_MS`.
- [Source: same | 2026-10-11 | confidence: medium]

Impact on this repo: `.env.local.example` and Coolify env need a check against this list. Binary data path matters for the Docker volume.

## Impact on custom patches (v2-docs/patch-inventory.md)

- Every custom patch must be re-checked against v3 source. Patches touching removed modules or the license/audit code are at risk.
- Community-node and Docker items in `backlog.md` (B5) are re-check items on each bump.
- Not yet checked: which patches still apply on v3.

## Pre-migration steps (do now, no version change)

1. Pin Docker and Coolify images to `2.42.6`, not `latest`.
2. Run **Settings > Migration Report** on the current v2 instance. Note every affected workflow.
3. Grep workflows for the removed node types above.
4. Keep a v3 trial on a throwaway instance using the `v3-nightly` image. Test custom patches there.

## Go / no-go

Move to v3 only when all are true:

- A stable v3 tag exists on Docker Hub (not nightly) and release notes confirm it.
- Migration Report is clean or every hit has a fix.
- Custom patches re-checked against v3 source.
- Env vars and binary data path updated.

## Update log

- 2026-10-11: created from research (docs page, DEVELOPING_V3.md, Docker Hub check).
