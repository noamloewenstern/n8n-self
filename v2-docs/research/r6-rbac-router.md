# R6: RBAC, roles, projects, router guards in v2

Commit checked: `55b3f5ac9ef8b30ee49c30780cef577acbc623c2` (branch `custom.v2`, n8n 2.43.0). Date: 2026-10-10.
Method: Read and Grep only. Every line number was re-checked with Grep/Read on this commit. No source file was edited. `.env.local` was not read. Builds on `r1-patch-map.md` (categories 4 and 5); this file does not repeat the R1 tables.

Citation form: `[Source: path:line | 2026-10-10 | confidence]`.

## 1. Result in short

1. The three v1 router guard removals (usage, SAML onboarding, community nodes) need NO patch in v2 when `License.isLicensed()` returns `true` and the env is set as below.
2. The three v1 rbac checks (`hasRole`, `hasScope`, `isEnterpriseFeatureEnabled`) need NO patch. The backend enforces the same scopes. A FE `true` only opens a screen that the API then refuses.
3. The only role the user needs is `global:owner`. It holds every global scope.
4. One licence gate has an effect that the FE cannot change: `@Licensed(...)` on controllers. It returns 403 until `isLicensed()` is `true`.

## 2. Scopes, roles, projects (v2 model)

### 2.1 Role types

| Type | Values | Source |
|---|---|---|
| Global role (FE `ROLE`) | `global:owner`, `global:member`, `global:admin`, `global:chatUser`, `default` (setup user, no email) | [Source: packages/@n8n/api-types/src/schemas/user.schema.ts:7-13 \| 2026-10-10 \| high] |
| Global scope map | `GLOBAL_SCOPE_MAP` maps owner, admin, member, chatUser to scope arrays | [Source: packages/@n8n/permissions/src/roles/role-maps.ee.ts:35-40 \| 2026-10-10 \| high] |
| Project role map | `project:admin`, `project:personalOwner`, `project:editor`, `project:viewer`, `project:chatUser` | [Source: packages/@n8n/permissions/src/roles/role-maps.ee.ts:42-48 \| 2026-10-10 \| high] |
| Sharing role maps | credential sharing, workflow sharing, secrets-provider-connection sharing | [Source: role-maps.ee.ts:50-66 \| 2026-10-10 \| high] |

Scope files: `packages/@n8n/permissions/src/roles/scopes/{global,project,credential-sharing,workflow-sharing,secrets-provider-connection-sharing}-scopes.ee.ts`. Scope format is `resource:operation` (for example `communityPackage:install`).

### 2.2 Global admin equals owner

`GLOBAL_ADMIN_SCOPES = GLOBAL_OWNER_SCOPES.concat()`. Admin has the same scopes as owner. [Source: packages/@n8n/permissions/src/roles/scopes/global-scopes.ee.ts:197 | 2026-10-10 | high]
`GLOBAL_MEMBER_SCOPES` is a smaller list (line 199). `GLOBAL_CHAT_USER_SCOPES` is smaller still (line 232). [Source: global-scopes.ee.ts:199,232 | 2026-10-10 | high]

The owner list includes the scopes that guard the three v1 pages:
- `communityPackage:install`, `:uninstall`, `:update`, `:list`. [Source: global-scopes.ee.ts:41-44 | 2026-10-10 | high]
- `saml:manage` (line 69), `ldap:manage` (line 63), `license:manage` (line 65). Line numbers from a Read window; re-grep before editing. [Source: global-scopes.ee.ts:60-72 | 2026-10-10 | medium]

### 2.3 Where the FE gets its scopes

- The backend returns `user.globalScopes` as the slugs of the scopes on the user's role. [Source: packages/@n8n/permissions/src/utilities/get-global-scopes.ee.ts:8-9 | 2026-10-10 | high]
- The FE loads them with `RBACStore.setGlobalScopes(user.globalScopes ?? [])`. [Source: packages/frontend/editor-ui/src/app/init/index.ts:309 | 2026-10-10 | medium]
- `useRBACStore` keeps `globalScopes`, `scopesByProjectId` and `scopesByResourceId`. Its `hasScope` calls the generic `hasScope` from `@n8n/permissions`. [Source: packages/frontend/@n8n/stores/src/rbac.store.ts:1-3,10-14 | 2026-10-10 | high]

So the FE `hasScope` reflects real server data. It is not a policy by itself.

### 2.4 Projects

- Types: personal project (one per user) and team project. [Source: packages/cli/src/services/project.service.ee.ts:198-199 | 2026-10-10 | medium]
- Team project create: `createTeamProject()` reads `licenseState.getMaxTeamProjects()` and passes it as `limit` to `insertTeamProjectWithAdmin`. A `null` result throws `TeamProjectOverQuotaError`. [Source: packages/cli/src/services/project.service.ee.ts:511-532 | 2026-10-10 | high]
  - The default quota is `0` (R1 row 1.2i). `isLicensed()=true` does NOT fix this. The `getValue()` patch must return a high `quota:maxTeamProjects`. See R1 "Suggested minimal patch set", step 2.
- Role licensing: `RoleService.isRoleLicensed(role)`.
  - Custom role: `license.isCustomRolesLicensed()`.
  - `project:admin`, `project:editor`, `project:viewer`: `isProjectRoleAdminLicensed()`, `...EditorLicensed()`, `...ViewerLicensed()`.
  - `global:admin`: `isAdvancedPermissionsLicensed()`.
  - [Source: packages/@n8n/backend-services/src/services/role.service.ts:471-491 | 2026-10-10 | high]
- Callers that REJECT an unlicensed role: `project.service.ee.ts:793` and `:886` (add or change project member role), `user.service.ts:352` (change user role), token-exchange module (296, 344). [Source: packages/cli/src/services/project.service.ee.ts:793,886 | 2026-10-10 | high]
- Invite of `global:admin` throws `ForbiddenError` when `isAdvancedPermissionsLicensed()` is false. [Source: packages/cli/src/services/user.service.ts:545-549 | 2026-10-10 | high]
- All these checks pass once `isLicensed()` is `true`, because they call `isLicensed(feature)` underneath. [Source: packages/@n8n/backend-common/src/license-state.ts:56-58,129-131 | 2026-10-10 | high]
- FE project routes: `custom` middleware `checkProjectAvailability`. It returns `true` when the project is in `myProjects`, or when no `projectId` param exists. [Source: packages/frontend/editor-ui/src/features/collaboration/projects/projects.routes.ts:28-34 | 2026-10-10 | high] This is a data check, not a licence check. No patch.

## 3. Router and middleware (FE)

### 3.1 Dispatch

- The router imports `middleware` from `@/app/utils/rbac/middleware`. [Source: packages/frontend/editor-ui/src/app/router.ts:17 | 2026-10-10 | high]
- The `beforeEach` guard loops over `to.meta.middleware`, reads options from `to.meta.middlewareOptions[name]`, and awaits each function. If any calls `next(location)`, the loop stops. [Source: router.ts:1222-1238 | 2026-10-10 | high]
- Before this, `settingsStore.showSetupPage` forces a redirect to the setup view. [Source: router.ts:1209-1216 | 2026-10-10 | high]
- If the guard throws, the user goes to sign-in (or to personal settings for an MFA error). [Source: router.ts:1241-1262 | 2026-10-10 | high]

Seven middleware names exist. [Source: packages/frontend/editor-ui/src/app/utils/rbac/middleware.ts:11-19 | 2026-10-10 | high]

| Name | File | Behavior | On failure |
|---|---|---|---|
| `authenticated` | `middleware/authenticated.ts` | Needs a signed-in user | sign-in |
| `guest` | `middleware/guest.ts` | Needs no user | home |
| `defaultUser` | `middleware/defaultUser.ts` | Needs the setup user | home |
| `role` | `middleware/role.ts:6-16` | `hasRole(checkRoles)` | `VIEWS.HOMEPAGE` |
| `rbac` | `middleware/rbac.ts:11-25` | `hasScope({scope, projectId, resourceType, resourceId, options})`. It infers project and resource from the route. | `VIEWS.HOMEPAGE` |
| `enterprise` | `middleware/enterprise.ts:6-16` | `isEnterpriseFeatureEnabled(options)` | `VIEWS.HOMEPAGE` |
| `custom` | `middleware/custom.ts:4-14` | Calls the route's own function. `false` means redirect. | `VIEWS.HOMEPAGE` |

`authenticated`, `guest`, `defaultUser` file contents were not read here (names only). [Source: middleware.ts:3-9 | 2026-10-10 | medium]

### 3.2 Check functions

All three are the unmodified upstream bodies. No v1 `return true` patch is applied on this branch.

| Check | Body | Source |
|---|---|---|
| `hasRole` | Returns `false` without a user or without roles. `default` user maps to `ROLE.Default`. Else `checkRoles.includes(role)`. | [Source: packages/frontend/editor-ui/src/app/utils/rbac/checks/hasRole.ts:5-15 \| 2026-10-10 \| high] |
| `hasScope` | `true` when `opts.scope` is empty. Else `rbacStore.hasScope(...)`. | [Source: .../rbac/checks/hasScope.ts:4-20 \| 2026-10-10 \| high] |
| `isEnterpriseFeatureEnabled` | `true` when `options.feature` is empty. Else `every`/`some` over `settingsStore.isEnterpriseFeatureEnabled[feature]`. Default mode `allOf`. | [Source: .../rbac/checks/isEnterpriseFeatureEnabled.ts:4-19 \| 2026-10-10 \| high] |

`settingsStore.isEnterpriseFeatureEnabled` is `computed(() => settings.value.enterprise ?? {})`. [Source: packages/frontend/@n8n/stores/src/settings.store.ts:90 | 2026-10-10 | high] The backend fills `settings.enterprise.*` from `License.isXxxEnabled()` (R1 row 2.4). So once `isLicensed()` is `true`, these keys are `true` with no FE edit.

Unit tests sit beside each check (`hasRole.test.ts`, `hasScope.test.ts`, `isEnterpriseFeatureEnabled.test.ts`). A FE patch would break them. [Source: directory listing of packages/frontend/editor-ui/src/app/utils/rbac/checks | 2026-10-10 | high]

## 4. v1 removed guards and their v2 equivalent

Setting for all rows: `License.isLicensed()` returns `true` (R1 row 1.3). Default env unless stated.

### 4.1 Usage page

| Item | v2 |
|---|---|
| Route | Path `usage` under `/settings`. Name `VIEWS.USAGE`. Middleware `['authenticated', 'custom']`. [Source: router.ts:616-628 \| 2026-10-10 \| high] |
| Guard | `custom` returns `!settingsStore.settings.hideUsagePage`. [Source: router.ts:624-627 \| 2026-10-10 \| high] |
| Parent redirect | `/settings` redirects to `PERSONAL_SETTINGS` if `hideUsagePage`, else `USAGE`. [Source: router.ts:605-611 \| 2026-10-10 \| high] |
| Backend source | `hideUsagePage` comes from `globalConfig.hideUsagePage`. Default `false`. [Source: packages/@n8n/config/src/index.ts:265 \| 2026-10-10 \| high] (carried from R1 row 2.6; not re-grepped) |
| Needs a patch? | NO. The default `false` opens the page. Also no licence gate here. Do not set the env that hides it. |
| Backend for the page | `GET /license` is open to any signed-in user. The `POST` routes need `license:manage` (owner has it). [Source: packages/cli/src/license/license.controller.ts:21-27,44,60,72 \| 2026-10-10 \| high] |

### 4.2 SAML onboarding

| Item | v2 |
|---|---|
| Route | `/saml/onboarding`, `VIEWS.SAML_ONBOARDING`, layout `auth`, middleware `['authenticated', 'custom']`. [Source: router.ts:1106-1124 \| 2026-10-10 \| high] |
| Guard | `ssoStore.isEnterpriseSamlEnabled && !settingsStore.isCloudDeployment`. [Source: router.ts:1114-1118 \| 2026-10-10 \| high] |
| Data flow | `isEnterpriseSamlEnabled` is a `ref(false)` set by `ssoStore.initialize({features.saml})`. [Source: packages/frontend/editor-ui/src/features/settings/sso/sso.store.ts:84,116 \| 2026-10-10 \| high] `features.saml` = `settingsStore.isEnterpriseFeatureEnabled[EnterpriseEditionFeature.Saml]`. [Source: packages/frontend/editor-ui/src/app/init/index.ts:98,303 \| 2026-10-10 \| high] |
| Needs a patch? | NO, if the backend sets `enterprise.saml = true`. That follows from `isLicensed()` (R1 row 2.4). `isCloudDeployment` is `false` for a self-hosted instance. |
| Caution | `isEnterpriseSamlEnabled` starts `false` until `initialize()` runs. A hard load of `/saml/onboarding` before init would redirect home. This is an ordering risk, not a licence risk. Not tested. |
| Backend | `SamlController` routes use `samlLicensedMiddleware` plus `@GlobalScope('saml:manage')`. [Source: packages/cli/src/modules/sso-saml/saml.controller.ee.ts:56-57,71-72,90-91,241-242 \| 2026-10-10 \| high] `initsso` uses `samlLicensedAndEnabledMiddleware` (line 212). The licence middleware passes once `isLicensed()` is `true`. A SAML IdP is still needed to log in. |

### 4.3 Community nodes

| Item | v2 |
|---|---|
| Route | Path `community-nodes` under `/settings`, `VIEWS.COMMUNITY_NODES`, middleware `['authenticated', 'rbac', 'custom']`. [Source: router.ts:1071-1090 \| 2026-10-10 \| high] |
| rbac | `scope: ['communityPackage:list', 'communityPackage:update']`. Default mode (`allOf`, see 5.1 below). [Source: router.ts:1078-1080 \| 2026-10-10 \| high] |
| custom | `settingsStore.isCommunityNodesFeatureEnabled`. [Source: router.ts:1081-1084 \| 2026-10-10 \| high] |
| Data flow | `isCommunityNodesFeatureEnabled = computed(() => settings.value.communityNodesEnabled)`. [Source: packages/frontend/@n8n/stores/src/settings.store.ts:252 \| 2026-10-10 \| high] Backend: `communityNodesEnabled: Container.get(CommunityPackagesConfig).enabled`. [Source: packages/cli/src/services/frontend.service.ts:328 \| 2026-10-10 \| high] Env `N8N_COMMUNITY_PACKAGES_ENABLED`, default `true`. [Source: packages/cli/src/modules/community-packages/community-packages.config.ts:12-13 \| 2026-10-10 \| high] |
| Needs a patch? | NO. The env default is `true`. The owner role has both scopes. Do not set `N8N_COMMUNITY_PACKAGES_ENABLED=false`. |
| Backend | `POST/GET/DELETE/PATCH` need `communityPackage:install/list/uninstall/update`. [Source: packages/cli/src/modules/community-packages/community-packages.controller.ts:14,24,30,38 \| 2026-10-10 \| high] A custom npm registry needs `COMMUNITY_NODES_CUSTOM_REGISTRY`; it throws `FeatureNotLicensedError` otherwise. [Source: packages/cli/src/modules/community-packages/community-packages.service.ts:500 \| 2026-10-10 \| high] That passes after `isLicensed()=true`. |
| Link to implementation brief | The brief says community node listing is off while install by npm name works (v2-docs/IMPLEMENTATION-PROMPT.md:93). The listing uses `verifiedEnabled` (`N8N_VERIFIED_PACKAGES_ENABLED`). That is a separate knob from the route guard. [Source: community-packages.config.ts:24-25 \| 2026-10-10 \| high] |

### 4.4 Summary table

| v1 patch | v2 location | Patch still needed with `isLicensed()=true`? |
|---|---|---|
| Usage `custom` guard removed | `router.ts:622-628`, `:607` | No |
| SAML onboarding `custom` guard removed | `router.ts:1112-1118` | No |
| Community nodes `custom` guard and `rbac` options removed | `router.ts:1076-1084` | No |
| `hasRole` returns `true` | `app/utils/rbac/checks/hasRole.ts:5` | No (owner passes all role checks that matter; optional) |
| `hasScope` returns `true` | `.../checks/hasScope.ts:4` | No |
| `isEnterpriseFeatureEnabled` returns `true` | `.../checks/isEnterpriseFeatureEnabled.ts:4` | No |

## 5. Other `enterprise` and `rbac` routes that depend on the licence

These use the `enterprise` middleware. All pass once `settings.enterprise.<key>` is `true`.

| Route | Line | Feature or scope | Note |
|---|---|---|---|
| Workflow debug view | `router.ts:329-334` | `DebugInEditor` | Depends on `enterprise.debugInEditor`. |
| Project role view | `router.ts:823-830` (feature at ~830) | `CustomRoles` | `enterprise.customRoles`. [Source: settings.store.ts:229 \| 2026-10-10 \| high] |
| Roles settings | `router.ts:893-900` | `CustomRoles` and scope `role:manage` | Owner has `role:manage` (not individually re-grepped in the owner list). |
| `resolvers` | `router.ts:794-810` | scopes `credentialResolver:*` and `useDynamicCredentials().isEnabled` | Needs `DYNAMIC_CREDENTIALS`. |
| `encryption-keys` | `router.ts:1036-1046` | scope `encryptionKey:manage` and module `rotationEnabled === true` | Module setting, not a licence. |
| `gateway-credits` | `router.ts:772-778` | `isAiGatewayEnabled && !isAiGatewayCloudUbbEnabled` | Needs a non-empty AI assistant `baseUrl` (R1 row 6.1). Stays off by decision. |
| `workers` | `router.ts:1063-1068` | scope `workersView:manage` | No licence. |
| `ldap` | `router.ts:1095-1101` | scope `ldap:manage` | No licence guard in the FE. |

### 5.1 Scope mode

`rbac` option `options: { mode: 'allOf' }` is explicit on `resolvers` (line 804). Other routes with an array of scopes (for example community nodes) use the default. The default mode is set in `@n8n/permissions` `hasScope`. [Source: packages/@n8n/permissions/src/utilities/has-scope.ee.ts:11 | 2026-10-10 | low] I did not read the default. Not verified.

## 6. Backend enforcement the FE patches cannot bypass

All of this runs on the server. A FE edit changes none of it.

1. **Scope check per route.** `ControllerRegistry.createScopedMiddleware()` calls `userHasScopes(req.user, [scope], globalOnly, req.params)`. A miss returns 403 `MISSING_SCOPE`. [Source: packages/cli/src/controller.registry.ts:262-285 \| 2026-10-10 \| high]
2. **Licence check per route.** `createLicenseMiddleware()` returns 403 `Plan lacks license for this feature` when `license.isLicensed(feature)` is false. [Source: packages/cli/src/controller.registry.ts:252-259 \| 2026-10-10 \| high] This is the one place where the backend patch (`isLicensed()=true`) matters for routes tagged `@Licensed(...)`.
3. **Order.** Scoped middleware, controller middleware, then route middleware, in that order. [Source: controller.registry.ts:240-248 \| 2026-10-10 \| medium]
4. **`userHasScopes` logic.** Global role scope first (`hasGlobalScope`). Then credential manage-instance special case. Then resource roles and project roles from the database. [Source: packages/cli/src/permissions.ee/check-access.ts:60-80 \| 2026-10-10 \| high] (the project and resource branches were not read in full).
5. **Global scopes come from the DB role.** `getGlobalScopes(user)` reads `user.role.scopes`. A FE `true` does not add a scope to the user. [Source: get-global-scopes.ee.ts:8-9 \| 2026-10-10 \| high]
6. **Role licence checks** in services (section 2.4). They run in the service layer and ignore the FE.
7. **Quota checks** (`getMaxTeamProjects`, users, variables) run in services and in the repository (`insertTeamProjectWithAdmin(..., limit)`). [Source: project.service.ee.ts:511-532 | 2026-10-10 | high] They read `getValue()`, not `isLicensed()`.
8. **Public API routes** use `@Licensed(PROJECT_ROLE_ADMIN)` and `@Licensed(CUSTOM_ROLES)`. [Source: packages/cli/src/public-api/v1/controllers/projects.public.controller.ts:80-244 | 2026-10-10 | high] [Source: roles.public.controller.ts:124,156,192 | 2026-10-10 | high]

## 7. Patch decision for this task

| Layer | Patch | Reason |
|---|---|---|
| Backend `License.isLicensed()` | YES (R1 1.3) | Opens `@Licensed` routes, role checks, `enterprise.*` flags. |
| Backend `License.getValue()` quotas | YES (R1 step 2) | Team project limit default is `0`. Not covered by `isLicensed()`. |
| FE router guards (3) | NO | Pass by default (section 4). |
| FE `hasRole`, `hasScope`, `isEnterpriseFeatureEnabled` | NO | Backend state already feeds them. A patch adds test churn and gives no API access. |
| User account | Use `global:owner` | Only owner/admin hold all scopes. Member and chatUser do not. |

Risk if a FE-only `true` were used instead of the backend patch: the user sees every page, and every API call returns 403 (section 6). This is the reason to avoid FE-only patches.

## 8. Not verified

- Runtime behavior. No app was started. Every claim is from reading source.
- Exact line numbers inside `global-scopes.ee.ts` for `saml:manage`, `ldap:manage`, `license:manage`, `role:manage`, `encryptionKey:manage` (read from one window, not individually grepped). Whether `role:manage` and `encryptionKey:manage` are in the owner list.
- Default `mode` of the generic `hasScope` in `@n8n/permissions` (`allOf` vs `anyOf`).
- Contents of `authenticated.ts`, `guest.ts`, `defaultUser.ts` middleware.
- `userHasScopes` project-role and resource-role branches past line 80 of `check-access.ts`.
- Exact lines of `ldap:manage`, `RBACStore.setGlobalScopes` (init/index.ts:309 is from a sed window).
- Whether a hard load of `/saml/onboarding` runs after `ssoStore.initialize()`.
- Whether `settings.enterprise.debugInEditor` exists as a key under that name (R1 lists the key set; not re-checked).
- `global:admin` vs `global:owner` differences beyond scope equality (invite, transfer, and setup flows).
- Whether the e2e controller, `sso.test.ts`, `projects.routes.test.ts` or other tests assert guard behavior that a future patch would break.
- Whether any module-level FE route (under `packages/modules/*/frontend`) adds its own guards. Not searched.
- The `hideUsagePage` and `HIRING` env names (R1 carry-over).
- Public API key scopes (`public-api-permissions.ee.ts`). Not read.
