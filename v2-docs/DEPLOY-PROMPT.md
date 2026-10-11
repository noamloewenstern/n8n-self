# Prompt for the deploy agent: run the custom n8n image

Give this whole file to an agent that has access to the server. It works for Coolify or for any Docker host.

---

## Task

Build and run n8n from a Git repository with one Dockerfile. Do not change any file in the repository. Do not push.

## Inputs

| Item | Value |
|---|---|
| Repository (SSH) | `git@github.com:noamloewenstern/n8n-self.git` |
| Repository (HTTPS) | `https://github.com/noamloewenstern/n8n-self.git` |
| Branch | `custom.v2` |
| Build context | The repository root (`/`) |
| Dockerfile | `docker/images/n8n/Dockerfile.custom` |
| Container port | `5678` |
| Persistent volume | Destination `/home/node/.n8n` (database and encryption key) |
| Health check | `GET /healthz` on port `5678`. Expect HTTP 200. |

The repository is private. Ask the owner for a deploy key or a token if you have none. Never print it.

## Do this

**In Coolify:** create an application from the repository, build pack **Dockerfile**, base directory `/`, Dockerfile location `/docker/images/n8n/Dockerfile.custom`, ports exposes `5678`. Add the volume, the health check and the environment variables below. In Advanced, **turn off the injection of build arguments**. Mark every variable as runtime only. Deploy.

**On any other Docker host (Linux, Docker 23 or newer):**

```bash
git clone --branch custom.v2 <repository> n8n-build
cd n8n-build
docker build -f docker/images/n8n/Dockerfile.custom -t n8n-custom:custom.1 .
docker run -d --name n8n --restart unless-stopped \
  -p 5678:5678 -v n8n_data:/home/node/.n8n \
  --env-file /path/outside/the/repo/n8n.env n8n-custom:custom.1
```

Keep `n8n.env` outside the repository with permission `600`.

## Environment variables

Set these as runtime variables. Do not use `--build-arg` for any of them.

| Name | Value |
|---|---|
| `N8N_ENCRYPTION_KEY` | Generate once (`openssl rand -hex 32`). Store it in the secret store. Give the owner one copy by a private channel. If it changes, saved credentials stop working. Never log it. |
| `N8N_HOST` | The public host name. Ask the owner. |
| `N8N_PROTOCOL` | `https` (or `http` if no TLS in front) |
| `N8N_PORT` | `5678` |
| `N8N_PROXY_HOPS` | `1` when a reverse proxy (Coolify's proxy) is in front. Else leave unset. |
| `N8N_WEBHOOK_URL` | The public base URL, for example `https://<host>/`. Ask the owner. |
| `N8N_DIAGNOSTICS_ENABLED` | `false` |
| `N8N_VERSION_NOTIFICATIONS_ENABLED` | `false` |
| `N8N_PERSONALIZATION_ENABLED` | `false` |
| `N8N_ENABLED_MODULES` | `agent-evals,promotions` |
| Feature flags | Copy the names and the values from the block `v2 additions: modules and feature flags` in `.env.local.example` in the repository (committed, no secrets). That block includes `N8N_FEATURE_FLAG_OVERRIDES`. Skip the lines for `N8N_INSTANCE_REPORTING_*`. |

Do not set `N8N_LICENSE_*` or any AI key unless the owner asks. Do not look for or copy any `.env.local`. It does not exist on the server.

## Rules

- Build on Linux from a normal `git clone`. A clone with Windows (CRLF) line endings fails.
- The build needs about 8 GB of free RAM and takes about 8 to 11 minutes.
- Never put a secret in the Git repository, in a build argument, in a log or in a message back to the owner.
- Keep any image you push to a registry **private**. This build removes the n8n license checks.

## Check

1. The build log ends without error. If it says `the source tree is not in the build context` or `CRLF line endings`, stop and report the exact line.
2. `curl -s -o /dev/null -w '%{http_code}' http://localhost:5678/healthz` prints `200` (or use the public URL).
3. Open the public URL. n8n shows the "set up owner account" page. Create the owner account only if the owner asks you to.
4. After login: Settings, Usage and plan shows plan **Enterprise** with no limits.
5. Optional: `docker run --rm --entrypoint sh <image> -c "find / -xdev -name '.env*' 2>/dev/null"` prints nothing.

## Report back

Reply with: the commit SHA you built, the image tag, build duration, the result of checks 1 to 4, any variable you could not set, and any error with its exact text. Do not include secret values.
