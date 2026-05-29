# Node Standup — Ops Deployable .NET

**Applies to:** ADR-0082 D5 a–m + n–t (Core .NET + Ops Deployable additions).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure)
- `infrastructure/walkthroughs/node-standup-core-dotnet.md` (inherited — everything in Core .NET applies here too)
- `infrastructure/walkthroughs/key-vault-creation.md` (Step n)
- `infrastructure/walkthroughs/app-configuration-provisioning.md` (Step o)
- `infrastructure/walkthroughs/container-app-creation.md` (Step q)
- `infrastructure/walkthroughs/container-apps-environment-creation.md` (Step q — shared environment)
- `infrastructure/walkthroughs/container-registry-creation.md` (Step q — shared registry)
- `infrastructure/walkthroughs/key-vault-rbac-assignments.md` (Step p — managed-identity RBAC)
- `infrastructure/walkthroughs/oidc-federated-credentials.md` (deploy identity)
- `infrastructure/walkthroughs/log-analytics-workspace-and-alerts.md` (Key Vault diagnostic settings — Invariant 22)
- `infrastructure/walkthroughs/event-grid-subscriptions-on-keyvault.md` (secret rotation hookup — ADR-0006)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** 102 (node-registration-mandatory), 17 (one Key Vault per Node per env), 18 (env-vars carry Vault/AppConfig endpoints), 19 (≤ 13-char service name), 22 (Key Vault diagnostics → shared Log Analytics), 34 (Container App naming + system-assigned MI), 35 (shared environment + registry), 36 (revision mode Multiple), plus the inherited Core .NET invariants (11, 12, 26, 27, 31, 32, 33, 41, 46, 49, 52).

## Goal

Stand up an Ops Deployable .NET Node end-to-end. Same Phase A → B → C → Post-merge sequence as Core .NET, with the addition of per-environment Azure infrastructure (Key Vault, App Configuration, managed identity, Container App) and a Bicep-based deployment workflow.

- Class: `ops-deployable-dotnet`.
- Output: published `v0.1.0` Abstractions package(s) on nuget.org **plus** deployable Container App revisions in dev/staging/prod.

## Inherit from the Core .NET walkthrough

Read `node-standup-core-dotnet.md` first. Everything in its Phase A (catalog rows, context folder, sector row, `repo-to-node.yml` mapping, initiative entry), Phase B (repo creation, branch protection, label seeding, NuGet-publishing OIDC, local clone), and Phase C (`.slnx`, `Directory.Build.props`, Standards reference, test layout, `release.yml`, nightlies, contract-shape canary, in-memory fixture, smoke test, `sonar-project.properties`, `.honeydrunk-review.yaml`, `.coderabbit.yaml`, README/CHANGELOG/LICENSE/`copilot-instructions.md`/`CLAUDE.md`/`pr.yml`) applies here verbatim. Below adds only what Ops Deployable adds.

## Ops additions to Phase A

None — Phase A is identical to Core .NET.

## Ops additions to Phase B (human-only Azure provisioning)

Per environment (`dev`, `staging`, `prod`):

1. **Key Vault** `kv-hd-{service}-{env}` — follow `key-vault-creation.md`. Azure RBAC enabled, access policies forbidden (Invariant 17). Diagnostic settings routed to the shared Log Analytics workspace (Invariant 22) — follow `log-analytics-workspace-and-alerts.md`. The `{service}` token must be ≤ 13 characters (Invariant 19) so the full `kv-hd-{service}-{env}` name fits Azure's 24-char Key Vault limit.
2. **App Configuration store** `appcs-hd-{service}-{env}` — follow `app-configuration-provisioning.md`. Set `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` as Container App env vars at deploy time per Invariant 18 (never derived by convention, never hardcoded).
3. **System-assigned managed identity** on the Container App per environment (configured at app-create time in Step 4). The identity is the principal that reads from Key Vault — RBAC grant `Key Vault Secrets User`. Follow `key-vault-rbac-assignments.md`.
4. **Container App** `ca-hd-{service}-{env}` — follow `container-app-creation.md`. Per Invariant 34 (naming `ca-hd-{service}-{env}`, system-assigned Managed Identity), Invariant 35 (shared environment `cae-hd-{env}` + shared registry `acrhdshared{env}`; per-Node compute environment or registry forbidden without a follow-up ADR), Invariant 36 (revision mode `Multiple`, explicit traffic splitting on deploy). If the shared environment or registry do not yet exist in the env, follow `container-apps-environment-creation.md` and `container-registry-creation.md` first.
5. **Event Grid subscription** on the Key Vault for secret-rotation hooks if the Node consumes rotated secrets per ADR-0006 — follow `event-grid-subscriptions-on-keyvault.md`.

## Ops additions to Phase B (deploy-identity OIDC)

In addition to the NuGet-publishing OIDC federated credential (the Core .NET step), add a **deploy** OIDC federated credential for the Bicep/Container App deploy workflow:

- Subject pattern for `dev` deploy (push-to-`main`): `repo:HoneyDrunkStudios/HoneyDrunk.{NodeName}:ref:refs/heads/main`.
- Subject pattern for `staging`/`prod` deploy (SemVer tags): `repo:HoneyDrunkStudios/HoneyDrunk.{NodeName}:ref:refs/tags/v*`.

The deploy identity has Container App contributor + ACR push + App Configuration contributor on the target subscription/resource group; it does **not** have Key Vault secret-read rights (ADR-0077 D7 — the deploy identity provisions, applications read).

## Ops additions to Phase B (org-secret binding deltas)

In addition to the Core .NET secrets (`SONAR_TOKEN`, `NUGET_API_KEY`), bind any Discord webhook secrets the Node's workflows emit to (per ADR-0084) and `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` if the Node's `.honeydrunk-review.yaml` enables upstream emission. Per the matrix in `constitution/node-standup.md`, via `org-secret-repo-binding.md`.

## Ops additions to Phase C — scaffold file-tree deltas

Add to the Core .NET scaffold tree:

```
/
├── .github/workflows/
│   └── deploy.yml                  (calls HoneyDrunk.Actions job-deploy-bicep.yml — see ADR-0033 trigger model)
├── infra/                          (Bicep modules per ADR-0077; one .bicep per resource family)
│   ├── main.bicep
│   ├── modules/
│   │   ├── key-vault.bicep
│   │   ├── app-configuration.bicep
│   │   ├── container-app.bicep
│   │   └── managed-identity-rbac.bicep
│   └── parameters/
│       ├── dev.bicepparam
│       ├── staging.bicepparam
│       └── prod.bicepparam
└── src/
    └── HoneyDrunk.{NodeName}.{Service}/    (one or more deployable Services — Notify has Functions + Worker)
        └── HoneyDrunk.{NodeName}.{Service}.csproj
tests/
    ├── HoneyDrunk.{NodeName}.Tests.Unit/
    ├── HoneyDrunk.{NodeName}.Tests.Integration/  (always for Ops Deployable per Invariant 50)
    └── HoneyDrunk.{NodeName}.Tests.E2E/          (always for HTTP-fronted Ops Deployable per Invariant 50)
```

`deploy.yml` minimal caller (ADR-0033 trigger model — path-filtered push-to-`main` → dev; SemVer tags → staging then prod; environment-keyed concurrency):

```yaml
name: Deploy
on:
  push:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.{NodeName}.{Service}/**'
      - 'infra/**'
    tags: ['v*.*.*']
concurrency:
  group: deploy-${{ github.ref_name }}
  cancel-in-progress: false
permissions:
  id-token: write
  contents: read
jobs:
  dev:
    if: github.ref == 'refs/heads/main'
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      environment: dev
      bicep-file: infra/main.bicep
      parameters-file: infra/parameters/dev.bicepparam
  staging:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      environment: staging
      bicep-file: infra/main.bicep
      parameters-file: infra/parameters/staging.bicepparam
  prod:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: staging
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      environment: prod
      bicep-file: infra/main.bicep
      parameters-file: infra/parameters/prod.bicepparam
```

(`on:` keys must be merged into one mapping in the real file — push-branches-with-paths and push-tags are shown separately here for readability but YAML allows a single `push:` block with both `branches`/`paths` and `tags`. Per-deployable path scoping for multi-deployable repos like Notify; environment-keyed concurrency per ADR-0033.)

## Ops additions to Phase C — health endpoints

For every HTTP-fronted deployable Node (ADR-0066 / Invariants 80–82):

- `MapHoneyDrunkHealthEndpoints` (or the Functions-host equivalent) in the host startup.
- `/health/live` and `/health/ready` anonymous; `/health` auth-required.
- `IHealthContributor` instances aggregated per the readiness-policy model.

## Ops additions to Post-merge

Same throwaway-PR canary ritual as Core .NET. Plus:

1. Confirm `deploy.yml` dev-deploy fires on the first push-to-`main` after scaffold merge.
2. Confirm the Container App revision exists in the `dev` environment with the system-assigned managed identity bound.
3. Confirm `/health/live` and `/health/ready` return 200 from the dev revision.
4. Confirm the managed identity can resolve a test secret from `kv-hd-{service}-dev` (write a smoke-test secret, read it back through `ISecretStore`, delete it).

## v0.1.0 tag and first publish

Same as Core .NET (Abstractions package(s) published on tag push). Plus: the same tag push triggers `staging` then `prod` Bicep + Container App deployment per ADR-0033.
