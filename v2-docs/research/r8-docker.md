# R8: Build and Docker

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: Read and Grep only. `.env.local` was not read. No Docker command was run.

## Short answers

1. **The npm@11.4.1 pin is NOT needed.** Drop it.
2. **Platform:** `DOCKER_PLATFORM` is optional. Without it, the platform is the host CPU architecture. Windows x64 gives `linux/amd64`.
3. **Minimal path:** `pnpm install`, then `pnpm build:docker` (with no secrets in env), then verify. Details in section 3.
4. **`.dockerignore`:** safe in practice (allowlist). It fails the `**/` prefix rule only in its first line, and that line is correct for an allowlist. Details in section 4.

## 1. Is the npm@11.4.1 pin still needed?

No.

- The v1 pin existed "to fix the vulnerable cross-spawn dependency". It was one line: `RUN npm install -g npm@11.4.1`.
  [Source: v1-docs/docker/images/n8n-custom/Dockerfile:61-62 | 2026-10-10 | high]
- The v2 runtime Dockerfile has no `npm install -g` step. It has no `npm` command except `NODE_GYP` path use and `rm -rf /root/.npm`.
  [Source: docker/images/n8n/Dockerfile:11,84 | 2026-10-10 | high]
- The v2 base image removes `/root/.npm` and `apk-tools`. It does not install npm packages.
  [Source: docker/images/n8n-base/Dockerfile:28-29 | 2026-10-10 | high]
- The v2 lockfile resolves `cross-spawn` to `7.0.6` (patched line) and `6.0.6` (old line, one dependent).
  [Source: pnpm-lock.yaml:17301,17305 | 2026-10-10 | medium]
- The `cross-spawn` in the global npm is inside the Node.js image (`/usr/local/lib/node_modules/npm` or the DHI Node layer). The base image pins `node:26.10.0` by digest. A new npm comes with a new Node digest, not with a Dockerfile step.
  [Source: docker/images/n8n/Dockerfile:3-6 | 2026-10-10 | high]
- The v2 Dockerfile is a different file from the v1 one. The v1 Dockerfile was a two-stage build with `COPY . /src`. v2 builds on the host (`build-n8n.mjs`) and copies `./compiled`. The pin has no place to go in v2 without a new `RUN` layer.

Residual risk: the global npm version inside the DHI Node 26.10.0 image is unknown. Scan the built image (`docker run --rm --entrypoint sh n8nio/n8n:local -c "npm ls -g cross-spawn"`) before you decide the pin is moot. See "Not verified".

Decision: do not port the pin. If the scan shows `cross-spawn` below 7.0.5 in global npm, add one line after the `mkdir -p /usr/local/bin` RUN in a custom Dockerfile layer. Do not edit the upstream Dockerfile.

## 2. How the platform is chosen

| Step | Logic | Source |
|---|---|---|
| `DOCKER_PLATFORM` set | `hostPlatform()` returns it. For bake, it is copied to `PLATFORMS`. | [Source: scripts/dockerize-n8n.mjs:105,261 | 2026-10-10 | high] |
| Not set, bake path | Bake uses `BAKE_LOCAL_PLATFORM` and keeps only the architecture: `linux/<arch>`. | [Source: docker/docker-bake.hcl:41-45 | 2026-10-10 | high] |
| Not set, podman path | `os.arch()` maps `x64` to `amd64` and `arm64` to `arm64`. Other values throw. | [Source: scripts/dockerize-n8n.mjs:104-111 | 2026-10-10 | high] |
| Engine choice | Bake is used when `docker buildx bake` works. Podman is the fallback. `CONTAINER_ENGINE` forces one. | [Source: scripts/dockerize-n8n.mjs:213-215 | 2026-10-10 | high] |

Result: on this Windows 11 x64 machine, no `DOCKER_PLATFORM` is needed. The result is `linux/amd64`. Set `DOCKER_PLATFORM=linux/amd64` anyway to make the intent explicit. It costs nothing.

Note: `build-n8n.mjs` has no platform logic. It builds on the host. The pnpm deploy output in `./compiled` is not CPU-specific except for native modules. The Dockerfile recompiles `isolated-vm`, `sqlite3` and `kafka-javascript` for musl in the `native-builder` stage.
[Source: docker/images/n8n/Dockerfile:15-45 | 2026-10-10 | high]
[Source: scripts/build-n8n.mjs:262,317,321 | 2026-10-10 | high] (the script removes host prebuilds and `deps`)

v1 comparison: `build-x86.sh` hardcoded `--platform linux/x86_64`. v2 needs no such flag.
[Source: v1-docs/docker/images/n8n-custom/build-x86.sh:5 | 2026-10-10 | high]

## 3. Minimal path to a local linux/amd64 `n8nio/n8n:local`

Script chain: `pnpm build:docker` runs `node scripts/build-n8n.mjs && node scripts/dockerize-n8n.mjs`.
[Source: package.json:17 | 2026-10-10 | high]

Default names: image `n8nio/n8n`, tag `local`. Both are the script defaults, so no env var is needed.
[Source: scripts/dockerize-n8n.mjs:40,42 | 2026-10-10 | high]
The default name has two path parts, so `shouldPush` is false and the image loads into the local daemon.
[Source: scripts/dockerize-n8n.mjs:46-47,165 | 2026-10-10 | high]

Steps, in order:

1. Apply the license patches (Phase B/C of the plan). Docker copies `./compiled`, which is built from source.
2. `pnpm install` (Node `>=24`, pnpm `12.4.2`).
3. `DOCKER_PLATFORM=linux/amd64 pnpm build:docker`. Run it from a shell where `.env.local` is NOT loaded. Do not wrap it in `dotenvx run`. See risk R-3.
4. Build output: `compiled/`, `dist/task-runner-javascript/`, then the image `n8nio/n8n:local` and `n8nio/runners:local`. The script also writes `docker-build-manifest.json`.
   [Source: scripts/dockerize-n8n.mjs:129-141,278-282 | 2026-10-10 | high]
5. The `runners` image is built too (`selectTargets()` always adds it). It is not needed for a first test if you run with `N8N_RUNNERS_MODE=internal`. To skip it, run `docker buildx bake -f docker/docker-bake.hcl n8n --load` after `build:n8n`. This is optional and unverified.
   [Source: scripts/dockerize-n8n.mjs:60-67 | 2026-10-10 | high]

Faster variant (skips the runners image):
`pnpm build:n8n` then `docker buildx bake -f docker/docker-bake.hcl n8n --load` (with `PLATFORMS=linux/amd64`).

Filesystem binary data:
- Default is `filesystem` in regular mode and `database` in queue mode. The code is `this.mode ??= executionsConfig.mode === 'queue' ? 'database' : 'filesystem'`.
  [Source: packages/core/src/binary-data/binary-data.config.ts:64 | 2026-10-10 | high]
- A single container is not queue mode, so no env var is needed. Set `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` in the container env file to make it explicit. The env name is proven by the test file.
  [Source: packages/core/src/binary-data/__tests__/binary-data.config.test.ts:59 | 2026-10-10 | high]
- Mount a volume at `/home/node/.n8n`. The Dockerfile creates and chowns that folder.
  [Source: docker/images/n8n/Dockerfile:82-83 | 2026-10-10 | high]
- Pass runtime config with `--env-file <container.env>` at `docker run`. Never bake it. `CLAUDE.md` says to use a separate container env file, not `.env.local`.

No secrets in layers, by design:
- The Dockerfile copies only `./compiled`, the entrypoint, and native-builder outputs. It has no `ARG` for secrets.
  [Source: docker/images/n8n/Dockerfile:60-72 | 2026-10-10 | high]
- The context is an allowlist (section 4). Env files are excluded twice.
- The build stage has no `COPY . .`.

## 4. `.dockerignore` check against the global rules

Global rule: every pattern `**/`-prefixed; exclude env, secrets, `.claude`, `.git`, `.vscode`, `.idea`, `.remember`; prefer explicit allowlist; no secret `ARG`; verify the artifact.

| Check | Result | Source |
|---|---|---|
| Strategy | Allowlist: `*` ignores everything, then `!` re-includes specific paths. This meets "prefer an explicit allowlist". | [Source: .dockerignore:5 | 2026-10-10 | high] |
| `**/.env*` | Present, `**/`-prefixed. | [Source: .dockerignore:46 | 2026-10-10 | high] |
| `**/.claude` | Present, prefixed. | [Source: .dockerignore:47 | 2026-10-10 | high] |
| `**/.git` | Present, prefixed. | [Source: .dockerignore:48 | 2026-10-10 | high] |
| `**/*.local` | MISSING. | gap |
| `**/.vscode`, `**/.idea`, `**/.remember` | MISSING. | gap |
| `*` on line 5 | Not `**/`-prefixed. Correct for an allowlist: `*` matches only the context root, and all `!` entries are root-relative. Deeper entries are allowed only by explicit `!x/**`. | [Source: .dockerignore:5 | 2026-10-10 | medium] |

Exposure analysis (why the gaps are low risk now):
- Re-included trees: `compiled/**`, `patches/**`, `scripts/**`, `packages/@n8n/task-runner-python/**`, `packages/@n8n/typescript-config/**`, `packages/quality/efficiency/scale/benchmark/**`, `dist/task-runner-javascript/**`.
  [Source: .dockerignore:8-9,16-19,33-43 | 2026-10-10 | high]
- Lines 46-48 come AFTER the `!` lines, so they override re-includes. This is the correct order (last match wins in `.dockerignore`).
- A `.env.local` file inside a re-included tree is caught by `**/.env*`. A `foo.local` file is not. No known `*.local` file is in those trees (not searched; see "Not verified").
- The `.git`, `.claude` patterns stop nested copies, for example a stray `.claude` folder under `scripts/`.

Recommended small fix (optional, one hunk): append `**/*.local`, `**/.vscode`, `**/.idea`, `**/.remember`. This follows the global rule. It is not required for the local build. It would be a separate commit (change hygiene).

Last global-rule item: "verify, do not assume". After the build, run:
`docker run --rm --entrypoint sh n8nio/n8n:local -c "find / -xdev -name '.env*' -not -path '*/node_modules/*' 2>/dev/null"`
and `docker history --no-trunc n8nio/n8n:local` to inspect for env values. The Dockerfile has no `ARG` that takes a secret, so history should show none.

## 5. Risks

| ID | Risk | Detail | Mitigation |
|---|---|---|---|
| R-1 | License patch not in image | Docker copies `./compiled`. A stale `compiled/` ships old code. `pnpm build:docker` rebuilds it, but a manual `bake` does not. | Always run `build:n8n` first. Check a patched string in `compiled/` before bake. |
| R-2 | Windows host for `build-n8n.mjs` | The script uses `find ... -exec rm -rf {} +` and shell pipes (lines 262, 306, 394). These need a POSIX shell. zx on Windows uses bash only if found. | Run in Git Bash or WSL2. Not verified on this machine. [Source: scripts/build-n8n.mjs:262,306 \| 2026-10-10 \| medium] |
| R-3 | `.env.local` leak via env | Running the build under `dotenvx run -f .env.local` puts secrets in the process env. zx passes the env to child commands. BuildKit does not copy host env into layers, but `docker buildx bake` reads env vars for variables (`NODE_VERSION`, `IMAGE_TAG`, `PLATFORMS`, `N8N_VERSION`). A name clash would change the build. | Build with a clean shell. Do not use dotenvx for build commands. |
| R-4 | pnpm symlink trap | `COPY --link` into pnpm symlink targets silently breaks modules. The Dockerfile warns about it. Do not add `--link` to custom COPY steps for `node_modules`. | [Source: docker/images/n8n/Dockerfile:63-65 \| 2026-10-10 \| high] |
| R-5 | Native module rebuild | `isolated-vm`, `sqlite3`, `kafka-javascript` are rebuilt in Alpine with `apk add python3 make g++`. The build needs network access and Alpine mirrors. | Allow network on first build. |
| R-6 | Base image pull | `RUNTIME_IMAGE=n8nio/base:26.10.0@sha256:...` is pulled from Docker Hub. `BUILDER_IMAGE` is `node:26.10.0-alpine3.24`. Pinned by digest. | Expect a download. Digest pins protect against tag drift. [Source: docker/images/n8n/Dockerfile:5-6 \| 2026-10-10 \| high] |
| R-7 | Base image uses Node 26, v1 used Node 22 | `NODE_VERSION` default `26.10.0`. Community nodes and task runner behavior differ from v1. | Out of scope for the image build. Test on the Phase D checks. [Source: docker/docker-bake.hcl:4 \| 2026-10-10 \| high] |
| R-8 | Runner mode | No `N8N_RUNNERS` string exists in the entrypoint. The v2 default for code nodes is the task runner. Without the `runners` sidecar or `N8N_RUNNERS_MODE=internal`, Code nodes may fail. | Verify in Phase D. Set env in the container env file. Not verified. |
| R-9 | Queue mode flips binary data | If `EXECUTIONS_MODE=queue` is set, binary data defaults to `database`. | Keep regular mode, or set `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` explicitly. |
| R-10 | Gitignored `compiled/` | `compiled` is in `.gitignore`. `.dockerignore` allows it. Good. A local `compiled/` can hold old files from a previous build and ship them. | Delete `compiled/` (project path, not a protected path) before a rebuild if you doubt it. Do not use `rm -rf` on any parent. [Source: .gitignore:68 \| 2026-10-10 \| high] |
| R-11 | Image size and time | First build compiles three native modules and the whole monorepo. Expect a long build. | Plan for it. Use `pnpm build > build.log 2>&1` (rule in `AGENTS.md`). |
| R-12 | Podman path ignores bake args | The podman branch sends no build args. | Not applicable if Docker Desktop has buildx. [Source: scripts/dockerize-n8n.mjs:177-181 \| 2026-10-10 \| high] |

## 6. Not verified

- Whether `build-n8n.mjs` runs on native Windows. Not run (no execution allowed). Needs a Git Bash or WSL2 check.
- The `npm` and `cross-spawn` version inside `dhi.io/node:26.10.0` and `n8nio/base:26.10.0`. Needs an image scan.
- Whether `cross-spawn@6.0.6` in `pnpm-lock.yaml` ends up in `compiled/`. Needs `compiled/node_modules/.pnpm` listing after the build.
- That `docker buildx bake --load` works with the active builder on this machine. The script handles the `docker` driver, but the local driver is unknown.
- That the runners image is not needed for a smoke test.
- That Code nodes work without a runner (R-8). `docker/images/n8n/docker-entrypoint.sh` was not read in full. Grep found no `runners` string in it.
- That no `*.local` file lives in a re-included tree (`scripts/`, `patches/`, `compiled/`).
- The `N8N_DEFAULT_BINARY_DATA_MODE` allowed-mode list (`availableModes`). Lines 23-27 of the config were not read in full.
- The exact `BAKE_LOCAL_PLATFORM` value on Windows (assumed `windows/amd64`, so the code takes `[1]` = `amd64`).
