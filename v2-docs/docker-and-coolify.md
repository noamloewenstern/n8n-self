# Build the custom.v2 Docker image and deploy it to Coolify

Status: updated 2026-10-11. `Dockerfile.custom` was built on Docker Desktop (Linux engine 29.8, amd64) and checked: see section 6. The Coolify steps and the GHCR push were **not** run. Parts that come from Coolify's public docs carry their source. Untested parts are marked "unverified".

Short version for the repository: `docker/images/n8n/README.custom.md`.

## 1. The short answer

Give Coolify the repository, the branch `custom.v2`, and the path `/docker/images/n8n/Dockerfile.custom`. Coolify builds the whole image from Git and runs it. You add the environment variables, a volume and a health check.

| Coolify field | Value |
|---|---|
| Source | This repository (public or private, deploy key or GitHub App) |
| Branch | `custom.v2` |
| Build pack | Dockerfile |
| Base directory | `/` |
| Dockerfile location | `/docker/images/n8n/Dockerfile.custom` |
| Ports exposes | `5678` |
| Storage | Persistent volume, destination `/home/node/.n8n` |
| Environment variables | Runtime only (section 4) |
| Advanced | Turn off the injection of build arguments |
| Health check | Path `/healthz`, port `5678` |

The upstream `Dockerfile` cannot do this. It needs a folder `compiled/` that a script makes on the host first (section 2). `Dockerfile.custom` makes that folder inside the build, then runs the upstream steps. One file, one `docker build`, no host tools.

One warning about "public image": this build removes the n8n license checks. Keep any registry package **private** (section 5.3).

## 2. The options and the decision

| Option | How it works | Fit |
|---|---|---|
| **A1. Coolify builds the upstream Dockerfile** | Coolify clones the repo and runs `docker build`. | Does not work. `compiled/` is not in Git. |
| **A2. One self-contained Dockerfile (`Dockerfile.custom`)** | A first stage builds `compiled/` inside the image build. The later stages are the upstream stages. | **Chosen (owner, 2026-10-11).** Works from a clean checkout on any host. Costs: you diff it against upstream on every bump (section 8), and the build needs about 8 GB of RAM. |
| **B. Build on your PC, push to GHCR, Coolify pulls the image** | You run `docker build`, then `docker push`. Coolify uses the "Docker Image" type. | Good fallback. Best if the Coolify server is small, or if you want a tag to roll back to (section 5). |
| **C. Run `pnpm build:docker` on the Coolify server** | The server builds with the repo scripts. | Not recommended. Heavy, needs tools on the production host, and the script fails on Windows. |

Why the upstream Dockerfile fails alone: the repo has two steps in `package.json`: `build:docker = node scripts/build-n8n.mjs && node scripts/dockerize-n8n.mjs`. The first step runs `pnpm install`, `pnpm build` and `pnpm deploy` and writes `compiled/`. The second runs `docker buildx bake`. The Dockerfile then does `COPY ./compiled …`. Without step 1 there is nothing to copy. On native Windows step 1 fails: `scripts/build-n8n.mjs:26` reads its own folder with `new URL(import.meta.url).pathname`, which gives `/C:/Users/...`. [Source: package.json:17, scripts/build-n8n.mjs:26, docker/images/n8n/Dockerfile | 2026-10-11 | high]

Coolify's own docs describe option B as a supported pattern, and they describe the Dockerfile build pack for option A2. [Coolify: Dockerfile build pack](https://coolify.io/docs/applications/build-packs/dockerfile), [Coolify: Deploy a Docker image](https://coolify.io/docs/applications/deployments/docker-image)

Rule for A2 or B at deploy time:

- The Coolify server has 8 GB or more of free RAM, and you want "push to Git = deploy": use A2 in Coolify.
- The Coolify server is small, or you want fast deploys and a fixed tag to roll back to: build on your PC and use B.

## 3. How the image is built, and why it is not smaller

### 3.1 The stages

Only the last stage ships. The other stages stay in the build cache.

| Stage | Base | What it does | Ships? |
|---|---|---|---|
| `source-build` | `node:26.10.0-bookworm` (pinned by digest) | Installs pnpm 12.4.2. Copies the repo. Runs `pnpm install --frozen-lockfile`, then `node scripts/build-n8n.mjs` (build, `pnpm deploy --prod`, strips, checks). Makes `/src/compiled`. | No |
| `toolchain` | upstream Alpine builder | Adds `python3 make g++`. | No |
| `native-builder` | `toolchain` | Rebuilds `isolated-vm`, `sqlite3` and `kafka-javascript` for Alpine (musl). | Only 3 `.node` files |
| last stage | upstream `n8nio/base` | Copies `/src/compiled`, the entrypoint and the 3 native files. Runs as user `node`. | **Yes** |

The first stage uses a glibc image on purpose. Upstream CI also builds on glibc (Ubuntu) and runs on Alpine. `build-n8n.mjs` handles that split. An Alpine first stage would make `pnpm install` pick musl packages.

The stage `source-build` sets `DOCKER_BUILD=true`. This makes `scripts/prepare.mjs` skip `lefthook install` (there is no `.git` in the build). The stage does not set `CI=true`. That flag would remove the e2e controller and add `--trust-lockfile`, and a local `pnpm build:docker` does neither.

### 3.2 What is in the image

Measured on the built image (2026-10-11):

| Item | Size | Note |
|---|---|---|
| Whole image | 1.84 GB | |
| `/usr/local/lib/node_modules/n8n` (the `compiled` closure) | about 1.3 GB, 118,000 files, 1,761 packages | n8n's real production dependencies |
| Runtime base (Node, fonts, GraphicsMagick, git, ssh, librdkafka) | about 0.5 GB | Upstream choice |
| Largest packages | `n8n-nodes-base` 147 MB, editor UI 63 MB, `isolated-vm` 32 MB, `date-fns` 28 MB, `js-tiktoken` 22 MB, `element-plus` 22 MB, langchain nodes 22 MB, `typescript` 2 copies x 20 MB, `agent-browser` 20 MB | |

Already gone, so there is nothing more to strip safely:

- Dev dependencies. `pnpm deploy --prod` leaves them out. We checked: no `vitest`, `eslint`, `vite`, `webpack`, `jest`, `storybook`, `@biomejs`, `turbo`, `prettier`, `esbuild`, `ts-node` or `tsx` in the closure.
- Source files, tests and build tools. First-party source maps: 0 MB. Test files and `__tests__` folders: 0 MB. Markdown files: 1 MB.
- Third-party source maps, `.d.ts` files, `isolated-vm` prebuilds, the librdkafka source and the non-musl `agent-browser` binaries. `build-n8n.mjs` strips them and checks that they are gone.
- Compilers, `-dev` packages and the pnpm store. They live only in the build stages.

Why we stop here: to go below 1.8 GB you must remove a feature. The two `typescript` copies are real dependencies of n8n features (code and AI workflow tooling). `agent-browser`, `playwright-core` and `js-tiktoken` serve AI and browser nodes. The base image carries fonts and GraphicsMagick for the Edit Image and PDF nodes, and git and ssh for the Git and SSH nodes. Each removal needs a test of that feature. We did not do any of them. If you want one, name the feature you will never use and test it after the cut.

## 4. Coolify setup, step by step

All steps come from Coolify's public docs and are unverified on your server. [Coolify: Dockerfile build pack](https://coolify.io/docs/applications/build-packs/dockerfile)

1. Project, then New resource, then a repository source. Pick this repository and branch `custom.v2`.
2. Build pack **Dockerfile**. Base directory `/`. Dockerfile location `/docker/images/n8n/Dockerfile.custom`.
3. Ports exposes `5678`. The process listens on `0.0.0.0` by default in the container.
4. Set the domain. Coolify's proxy adds HTTPS.
5. Storage: add a persistent volume with destination `/home/node/.n8n`. Without it you lose the database and the encryption key on every deploy.
6. **Advanced, then turn off the injection of build arguments.** Coolify otherwise adds an `ARG` for each variable and for `SOURCE_COMMIT`. A build argument stays in the image history and can be read with `docker history`. The build does not need any variable. [Coolify: Dockerfile build pack](https://coolify.io/docs/applications/build-packs/dockerfile)
7. Environment variables. Add them as **runtime** variables. Values are set in Coolify only, never in Git:

   | Name | Purpose |
   |---|---|
   | `N8N_ENCRYPTION_KEY` | One fixed key. Keep a copy. If it changes, saved credentials stop working. (Without it, n8n makes a key in the volume, and the volume is then the only copy.) |
   | `N8N_HOST`, `N8N_PROTOCOL`, `N8N_PORT` | Public host name, `https`, `5678`. |
   | `N8N_PROXY_HOPS` | `1`, because Coolify's proxy is in front. |
   | `N8N_WEBHOOK_URL` | Public base URL for webhooks. (`WEBHOOK_URL` is the old v1 name.) |
   | `N8N_DIAGNOSTICS_ENABLED`, `N8N_VERSION_NOTIFICATIONS_ENABLED`, `N8N_PERSONALIZATION_ENABLED` | `false`. |
   | `N8N_ENABLED_MODULES`, and the feature flag names in `.env.local.example` | The values you use on your PC. They are in `.env.local`. Copy only the ones you need. |

   The names above exist in the n8n config classes (`packages/@n8n/config/src`). [Source: grep of `@Env(...)` | 2026-10-11 | high] Do not copy `.env.local` as a whole.
8. Health check: path `/healthz`, port `5678`.
9. Deploy. Watch the build log. The first build downloads about 1,700 packages and compiles the whole monorepo.
   - On this PC (Docker Desktop) a full build from a fresh clone took 465 s (about 8 minutes) with a warm pnpm cache and warm base images. The first build, with cold caches, took about 11 minutes. The compile stage alone is about 2 minutes.
   - Coolify's build server may be slower. Give it 8 GB or more of free RAM. Coolify can use a separate build server. [Coolify: Build applications](https://coolify.io/docs/applications/builds/overview)

The container runs the JavaScript task runner inside itself (the default `N8N_RUNNERS_MODE=internal`). You do not need the separate runners image. [Source: packages/@n8n/config/src/configs/runners.config.ts:17, container log "Registered runner JS Task Runner" | 2026-10-11 | high]

### Updates and rollback

- Update: push to `custom.v2`, then press Deploy, or call Coolify's deploy webhook from your own script. Each deploy rebuilds. [Coolify: GitHub Actions](https://coolify.io/docs/applications/ci-cd/github/actions)
- Rollback: Coolify keeps no image tag for a Git build. To roll back, deploy an older commit. For fast rollbacks use option B (section 5): build once, push a version tag, deploy by tag.

### If the build fails in Coolify

| Message in the build log | Cause and fix |
|---|---|
| `the source tree is not in the build context` | Coolify did not use `Dockerfile.custom.dockerignore`, so the root `.dockerignore` (a whitelist) removed the source. Check that the Dockerfile location is exactly `/docker/images/n8n/Dockerfile.custom` and that the build uses BuildKit. If it still fails, tell the maintainer: the fix is to move the ignore rules into the root `.dockerignore`. |
| `CRLF line endings in the build context` | The checkout has Windows line endings. Coolify clones on Linux, so this means a custom clone. Use `core.autocrlf=false`. |
| Killed, or `JavaScript heap out of memory` | Not enough RAM. Use a separate build server, or switch to option B. |
| `ERR_PNPM_FROZEN_LOCKFILE_WITH_OUTDATED_LOCKFILE` | The clone lacks `pnpm-lock.yaml` or has a changed one. Check that the branch is the one you pushed. |

## 5. Build on your own machine (option B, and local tests)

The command is the same on every host. The repository root is the context:

```bash
docker build -f docker/images/n8n/Dockerfile.custom -t n8n-custom:local .
```

Optional build arguments: `--build-arg N8N_VERSION=2.43.0-custom.1` (image label) and `--build-arg N8N_RELEASE_TYPE=stable` (default `stable`; upstream uses `dev`). Never pass a secret as a build argument.

### 5.1 Host differences

| Host | What to do |
|---|---|
| **Linux, CI, Coolify** | Nothing special. A normal `git clone` works. |
| **Windows (Docker Desktop)** | **Do not build from your working tree.** Git for Windows (`core.autocrlf=true`) writes CRLF. The file `packages/cli/bin/n8n` then starts with `#!/usr/bin/env node` plus a carriage return, and the container stops with `env: 'node\r': No such file or directory`. Make a clean clone with LF endings, in a **short path**: `git clone -c core.autocrlf=false -c core.longpaths=true --branch custom.v2 git@github.com:noamloewenstern/n8n-self.git C:\n8n-build`. A long path (for example inside `AppData`) hits the 260-character limit: the clone silently lacks files such as `pnpm-lock.yaml`. You do not need WSL for this. |
| **WSL2** | Clone into the Linux home folder (`~/n8n-build`), never `/mnt/c`. Turn on Docker Desktop, Settings, Resources, WSL integration for your distribution. Give WSL 8 GB or more: `memory=8GB` in `%UserProfile%\.wslconfig`, then `wsl --shutdown`. |
| **macOS, Apple silicon** | The default image is `linux/arm64`. For an x86-64 server add `--platform linux/amd64`. This runs under emulation, is slow and may fail. Prefer an x86-64 build host or option A2 on the server. |
| **Any host, BuildKit** | The Dockerfile uses `RUN --mount=type=cache` and `COPY --link`. Use Docker 23 or newer (BuildKit is the default). With an older Docker set `DOCKER_BUILDKIT=1`. |

The Dockerfile stops in seconds, with a clear message, if the source tree is missing or has CRLF endings. [Verified: a build from the Windows working tree stopped at that step | 2026-10-11]

### 5.2 Push to GHCR (option B)

You need a GitHub personal access token (classic) with `write:packages`. Do not put the token on a command line or in a file in the repo. Read it from an environment variable.

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u noamloewenstern --password-stdin
docker tag n8n-custom:local ghcr.io/noamloewenstern/n8n:2.43.0-custom.1
docker push ghcr.io/noamloewenstern/n8n:2.43.0-custom.1
```

Use a version tag that never moves. Raise the number on each build. Do not use `latest`: a mutable tag can pull different content on a later deploy. [Coolify: Deploy a Docker image](https://coolify.io/docs/applications/deployments/docker-image)

In Coolify use a **Docker Image** application: image `ghcr.io/noamloewenstern/n8n`, tag `2.43.0-custom.1`, then the same storage, variables (section 4, steps 5 to 8) and health check. To update, change the tag and press Deploy. Check once that Coolify really pulls the new image. Unverified.

### 5.3 Public or private package?

A new GHCR package is private. Keep it private. This build turns on enterprise features without a license key, and n8n's license does not allow that. A private image for your own use is a smaller problem than a public image that anyone can pull. This is not legal advice. It is the reason to avoid "public".

To pull a private image, the Coolify server needs a login with a second token that has only `read:packages`. Log in on the server as the user that Coolify uses for Docker:

```bash
echo "$GHCR_READ_TOKEN" | docker login ghcr.io -u noamloewenstern --password-stdin
```

Do this on every Coolify server that pulls the image. [Coolify: Docker registries](https://coolify.io/docs/applications/builds/docker-registries) The docs and community guides differ on where to enter the login. Check your Coolify version. Unverified.

The same applies to the Git repository itself: it holds the patches. Keep the fork private, or accept that the patches are public.

## 6. What is verified and what is not

| Claim | State |
|---|---|
| `pnpm build:docker` fails on native Windows at `build-n8n.mjs:26` | Verified (log) |
| The upstream Dockerfile needs a prebuilt `compiled/` | Verified (read the file) |
| `Dockerfile.custom` builds from a clean LF checkout with one `docker build` | **Verified 2026-10-11** (exit 0; image 1.84 GB; closure 2188 MB to 1314 MB; compile stage 2 min 13 s with a warm pnpm cache) |
| No `.env*` file inside the image | **Verified** (`find / -xdev -name '.env*'` printed nothing) |
| Both license patches are in the image | **Verified** (`License activation is disabled` and `licenseServerDisabled` in `dist/license.js`) |
| The container boots and `/healthz` returns 200 | **Verified** (throwaway env file, port 5679) |
| `/rest/settings` after owner setup: `enterprise.auditLogs` true, `showNonProdBanner` false, telemetry false, version notifications false, `releaseChannel` `stable`, 21 of 25 enterprise flags true | **Verified** |
| `/rest/license`: plan `Enterprise`, all limits `-1` | **Verified** |
| The container log shows no host `license.n8n.io`, `enterprise.n8n.io`, `ph.n8n.io`, `telemetry.n8n.io` or `api.n8n.io` | **Verified** for the first 2 minutes. This is not a full egress audit (backlog B4). |
| A build from the CRLF Windows tree stops at once with a clear message | **Verified** |
| The same build without the guard gives a broken image (`env: 'node\r'`) | **Verified** (the first test build) |
| The image has no dev tools and no tests | **Verified** (list in section 3.2) |
| The committed state (commit `d12b6dee4f`, fresh LF clone at a short path) builds and passes the checks in section 9 | **Verified 2026-10-11** (exit 0 in 465 s with a warm pnpm cache; image 1.84 GB; no `.env*`; patches present; `/healthz` 200; settings and license values as above; 0 egress host lines) |
| Coolify steps (build pack, volume, variables, health check) | From Coolify docs, not tried |
| Coolify uses `Dockerfile.custom.dockerignore` | **Unverified.** The Coolify docs do not mention `.dockerignore`. The Dockerfile has a guard that stops with a clear message. |
| The Coolify server has enough RAM for the build | Unknown. Needs 8 GB or more (estimate). |
| GHCR push, private package, Coolify pull | Not run |
| Build for `linux/arm64`, or on macOS | Not run |

## 7. Common problems

- `permission denied` on `docker` (Linux): log out and in after `usermod -aG docker "$USER"`.
- `env: 'node\r': No such file or directory` at container start: the build used CRLF files. Build from a clone with `core.autocrlf=false` (section 5.1).
- `ERR_PNPM_FROZEN_LOCKFILE_WITH_OUTDATED_LOCKFILE` in a Windows clone: the path was too long and the clone lacks files. Clone to a short path with `core.longpaths=true`.
- Build killed or `JavaScript heap out of memory`: more RAM. In WSL set `memory=` in `%UserProfile%\.wslconfig`. In Docker Desktop raise the memory limit.
- `denied` on `docker push`: the token needs `write:packages`, and the user name in `docker login` must match the owner in the image name.
- Coolify cannot pull a private image: log in to `ghcr.io` on the Coolify server with a `read:packages` token.
- Settings vanish after a deploy: the volume on `/home/node/.n8n` is missing.
- The ignore rules: the root `.dockerignore` and `Dockerfile.custom.dockerignore` both remove `.env*`, `*.local`, `.claude`, `.git`, `.vscode`, `.idea` and `.remember`. Check the final image with the `find` command in section 9 after each first build.

## 8. Re-check on every n8n bump

`Dockerfile.custom` is a copy of upstream text plus one stage. It does not follow upstream by itself. Do this list each time you merge a new n8n version, before you build.

1. **Diff the Dockerfile.** Run:
   ```bash
   git diff --no-index docker/images/n8n/Dockerfile docker/images/n8n/Dockerfile.custom
   ```
   Only the known differences may show (all marked `CUSTOM PATCH` or in the header): the header comment, the `SOURCE_IMAGE` and `PNPM_VERSION` args, the `source-build` stage, `COPY --from=source-build` in place of `COPY ./compiled`, the entrypoint `--chmod`, and `N8N_RELEASE_TYPE=stable`. Any other difference is upstream drift. Copy it into `Dockerfile.custom`.
2. **Copy the pins.** `NODE_VERSION`, `BUILDER_IMAGE` and `RUNTIME_IMAGE` must equal the upstream values. Set `SOURCE_IMAGE` to the same Node version (`node:<NODE_VERSION>-bookworm`) and look up its new digest (`docker buildx imagetools inspect node:<version>-bookworm`). Set `PNPM_VERSION` to the `packageManager` value in `package.json`.
3. **Diff the build scripts.** Run `git diff <old>..<new> -- scripts/build-n8n.mjs scripts/dockerize-n8n.mjs docker/docker-bake.hcl`. Look for: a new env var that the script reads, a new build argument, a new image target, a new step that the Dockerfile must do too. `Dockerfile.custom` runs only `build-n8n.mjs`. It does not run `dockerize-n8n.mjs` or the bake file. Anything those two add must be copied by hand (the labels and build arguments are already copied).
4. **Check native modules.** The upstream Dockerfile rebuilds `isolated-vm`, `sqlite3` and `kafka-javascript`. A new native module there means a new `COPY` and `RUN` pair in `native-builder`.
5. **Check the ignore list.** If upstream adds a new top-level folder with local or secret files, add it to `Dockerfile.custom.dockerignore` with a `**/` prefix. Also keep the root `.dockerignore` guard lines.
6. **Check the entrypoint.** `docker/images/n8n/docker-entrypoint.sh` is copied from the source, so a change reaches the image. Read the diff once.
7. **Check line endings.** `.gitattributes` forces LF only for `*.sh` and `*.patch`. If upstream adds more scripts with a shebang, the CRLF guard (it checks `packages/cli/bin/n8n`) must cover them.
8. **Check the size.** Compare the image size and the `Closure ... MB` line in the build log with section 3.2. A jump means a new heavy dependency or a strip that stopped matching.
9. **Re-run the checks in section 9** on the new image.
10. **Re-check the patches.** Run `git grep -n "CUSTOM PATCH"` and the "re-check on bump" items in `v2-docs/backlog.md`.
11. **Update the version label and tags** (`N8N_VERSION`, the GHCR tag, the Coolify tag).

## 9. Check a built image

Run after every build. Replace `IMG` with the image name.

```bash
# 1. No env file inside the image (expect no output)
docker run --rm --entrypoint sh IMG -c "find / -xdev -name '.env*' 2>/dev/null"

# 2. The license patch is in the code (expect 1 and 3)
docker run --rm --entrypoint sh IMG -c "cd /usr/local/lib/node_modules/n8n; grep -c 'License activation is disabled' dist/license.js; grep -c licenseServerDisabled dist/license.js"

# 3. Boot with a throwaway env file (not .env.local)
docker run -d --name n8n-test --env-file container-test.env -p 5679:5678 IMG
curl -s -o /dev/null -w '%{http_code}' http://localhost:5679/healthz     # expect 200
docker logs n8n-test 2>&1 | grep -iE 'license\.n8n|enterprise\.n8n|ph\.n8n|telemetry\.n8n|api\.n8n'   # expect no output
docker rm -f n8n-test
```

`/rest/settings` shows only a short public list until an owner exists. To check `enterprise.auditLogs`, `showNonProdBanner` and the license plan, create a throwaway owner with `POST /rest/owner/setup`, keep the cookie, then call `/rest/settings` and `/rest/license`. Expect: `auditLogs` true, `showNonProdBanner` false, telemetry false, plan `Enterprise`, limits `-1`.

`container-test.env` holds only throwaway values, for example `N8N_ENCRYPTION_KEY` (any test string), `N8N_DIAGNOSTICS_ENABLED=false`, `N8N_VERSION_NOTIFICATIONS_ENABLED=false`, `N8N_PERSONALIZATION_ENABLED=false` and `N8N_SECURE_COOKIE=false`. Do not use real keys. Do not copy `.env.local`.
