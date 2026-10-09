# v1 custom patches (reference only)

Copied from branch `custom.v1` (commits `331f3c5d2c`, `01d1f7f74f`). Not built or used on `custom.v2`.

## Files

- `custom.md`: patch reference. Categories, v1 base `9806e6fc72`, v1 → v2 path map.
- `custom-full.diff`: full v1 patch diff (1736 added lines).
- `docker/images/n8n-custom/`: v1 custom Docker image (Dockerfile, build scripts, README).

## Summary

v1 (1.113.0) local-only patches:

1. License bypass: `isLicensed()` → true, quotas hardcoded.
2. Editor settings forced: SAML/LDAP, AI assistant, `enterprise.*`, MFA, folders.
3. Telemetry off (FE store, `Telemetry.vue`).
4. RBAC checks (`hasRole`, `hasScope`, `isEnterpriseFeatureEnabled`) always true.
5. Router guards removed (usage, SAML onboarding, community nodes).
6. AI assistant base URL → `https://ai-assistant.n8n.io`.
7. Build: `linux/amd64` forced; chat package heap 4 GB.
8. CI disabled: `.github/` → `.bak_github/`.

## Caveats

- Local/personal use only. RBAC open to all users.
- Patches target v1. Port to v2 by hand (see `custom.md` → "Porting to v2").
- Each patch marked `// CUSTOM PATCH` in source (v1 tree only).
