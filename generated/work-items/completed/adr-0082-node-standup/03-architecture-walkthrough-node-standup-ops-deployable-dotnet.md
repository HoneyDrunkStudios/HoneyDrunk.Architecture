---
name: Documentation
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infra", "ops", "adr-0082", "wave-3"]
dependencies: ["work-item:01"]
adrs: ["ADR-0082", "ADR-0005", "ADR-0012", "ADR-0015", "ADR-0033", "ADR-0066", "ADR-0077"]
accepts: ADR-0082
wave: 3
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Chore: Author `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` — per-class walkthrough for Ops Deployable .NET standups

## Summary

Author the Ops Deployable .NET per-class walkthrough at `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` per ADR-0082 D7. Composes against `constitution/node-standup.md` (packet 01) and the Core .NET walkthrough (packet 02 — Ops Deployable inherits everything Core .NET does). Adds the deployment-specific operational sequence per ADR-0082 D5 n–t: Key Vault per environment, App Configuration per environment, system-assigned managed identity per environment, Container Apps wiring, Bicep modules at `infra/`, deploy trigger model, health endpoints.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Ops Deployable .NET Nodes (Notify Functions+Worker, Pulse.Collector, Notify Cloud, Operator when deployed, Communications when deployed) inherit everything Core .NET requires *and* add the per-environment infrastructure provisioning plus the deployment plumbing. Without a dedicated walkthrough, every Ops standup re-derives the Key Vault / App Configuration / managed identity / Container Apps / Bicep / deploy trigger sequence from the most recent Ops precedent.

The Communications standup (ADR-0019) and the Notify Cloud standup (ADR-0027) are the freshest Ops Deployable precedents; this walkthrough generalizes their pattern.

## Proposed Implementation

### `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` — new walkthrough

Create the file following the Core .NET walkthrough's structure but adding the Ops addendum. Concretely:

```markdown
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
- `infrastructure/walkthroughs/oidc-federated-credentials.md` (deploy identity)
- `infrastructure/walkthroughs/log-analytics-workspace-and-alerts.md` (Key Vault diagnostic settings — Invariant 22)
- `infrastructure/walkthroughs/event-grid-subscriptions-on-keyvault.md` (secret rotation hookup — ADR-0006)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** {N1} (node-registration-mandatory), 17 (Key Vault per env), 18 (env-vars for endpoints), 19 (13-char service-name limit), 22 (Key Vault diag → Log Analytics), 34 (Container App naming), 35 (shared env + registry), 36 (revision mode Multiple), plus inherited invariants from Core .NET (11, 12, 26, 27, 31, 32, 33, 41, 46, 49, 52).

## Goal

Stand up an Ops Deployable .NET Node end-to-end. Same Phase A → B → C → Post-merge sequence as Core .NET, with the addition of per-environment Azure infrastructure (Key Vault, App Configuration, managed identity, Container App) and a Bicep-based deployment workflow.
- Class: `ops-deployable-dotnet`.
- Output: published `v0.1.0` Abstractions package(s) on nuget.org PLUS deployable Container App revisions in dev/staging/prod environments.

## Inherit from Core .NET walkthrough

Read `node-standup-core-dotnet.md` first. Everything Phase A (catalog rows, context folder, sector row, `repo-to-node.yml` mapping, initiative entry), Phase B (repo creation, branch protection, label seeding, OIDC for NuGet publishing, local clone), and Phase C (`.slnx`, `Directory.Build.props`, Standards reference, test layout, `release.yml`, nightlies, contract-shape canary, in-memory fixture, smoke test, `sonar-project.properties`, `.honeydrunk-review.yaml`, `.coderabbit.yaml`, README/CHANGELOG/LICENSE/`copilot-instructions.md`/`CLAUDE.md`/`pr.yml`) applies here verbatim. Below adds only what Ops Deployable adds.

## Ops additions to Phase A

(None — Phase A is the same as Core .NET.)

## Ops additions to Phase B (human-only Azure provisioning)

Per environment (`dev`, `staging`, `prod`):

1. **Key Vault** `kv-hd-{service}-{env}` — follow `key-vault-creation.md`. Azure RBAC enabled (access policies forbidden per Invariant 17). Diagnostic settings routed to the shared Log Analytics workspace per Invariant 22 — follow `log-analytics-workspace-and-alerts.md`.
2. **App Configuration store** `appcs-hd-{service}-{env}` — follow `app-configuration-provisioning.md`. Set `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` as Container App env vars at deploy time per Invariant 18 (never derived by convention).
3. **System-assigned managed identity** on the Container App per environment (configured at app-create time in Step 4 below). The identity is the principal that reads from Key Vault — RBAC grant: `Key Vault Secrets User`. Follow `key-vault-rbac-assignments.md`.
4. **Container App** `ca-hd-{service}-{env}` — follow `container-app-creation.md`. Per Invariant 34 (naming `ca-hd-{service}-{env}`, system-assigned Managed Identity), Invariant 35 (shared environment `cae-hd-{env}` + shared registry `acrhdshared{env}`; per-Node compute environment or registry forbidden without follow-up ADR), Invariant 36 (revision mode `Multiple`, explicit traffic splitting on deploy). If the shared environment or registry do not yet exist in the env, follow `container-apps-environment-creation.md` and `container-registry-creation.md` first.
5. **Event Grid subscription** on the Key Vault for secret rotation hooks if the Node consumes rotated secrets per ADR-0006 — follow `event-grid-subscriptions-on-keyvault.md`.

## Ops additions to Phase B (deploy-identity OIDC)

In addition to the NuGet-publishing OIDC federated credential (the Core .NET step), add a **deploy** OIDC federated credential for the Bicep/Container App deploy workflow:

- Subject pattern for `dev` deploy (push-to-`main`): `repo:HoneyDrunkStudios/HoneyDrunk.{NodeName}:ref:refs/heads/main`.
- Subject pattern for `staging`/`prod` deploy (SemVer tags): `repo:HoneyDrunkStudios/HoneyDrunk.{NodeName}:ref:refs/tags/v*`.

The deploy identity has Container App contributor + ACR push + App Configuration contributor on the target subscription/resource group; it does NOT have Key Vault secret-read rights (per ADR-0077 D7 — the deploy identity provisions, applications read).

## Ops additions to Phase B (org-secret binding deltas)

In addition to the Core .NET secrets (`SONAR_TOKEN`, `NUGET_API_KEY`), bind any Discord webhook secrets the Node's workflows emit to (per ADR-0084) and `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` if the Node's `.honeydrunk-review.yaml` enables upstream emission. Per the matrix in `constitution/node-standup.md`.

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

`deploy.yml` minimal caller (ADR-0033 trigger model):

```yaml
name: Deploy
on:
  push:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.{NodeName}.{Service}/**'
      - 'infra/**'
  push:
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

(Per-deployable path scoping for multi-deployable repos like Notify; environment-keyed concurrency per ADR-0033.)

## Ops additions to Phase C — health endpoints

For every HTTP-fronted deployable Node (per ADR-0066 / Invariant 80–82):
- `MapHoneyDrunkHealthEndpoints` (or Functions-host equivalent) in the host startup.
- `/health/live` and `/health/ready` anonymous; `/health` auth-required.
- `IHealthContributor` instances aggregated per the readiness-policy model.

## Ops additions to Post-merge

Same throwaway-PR canary ritual as Core .NET. Plus:

1. Confirm `deploy.yml` dev-deploy fires on first push-to-`main` after scaffold merge.
2. Confirm the Container App revision exists in the `dev` environment with the system-assigned managed identity bound.
3. Confirm `/health/live` and `/health/ready` return 200 from the dev revision.
4. Confirm the managed identity can resolve a test secret from `kv-hd-{service}-dev` (write a smoke-test secret, read it back through `ISecretStore`, delete it).

## v0.1.0 tag and first publish

Same as Core .NET (Abstractions package(s) published on tag push). Plus: the same tag push triggers `staging` then `prod` Bicep+Container App deployment per ADR-0033.
```

## Affected Files

- `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` (new)

## NuGet Dependencies

None.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`.

## Acceptance Criteria

- [ ] `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` exists with the structure above
- [ ] The walkthrough explicitly inherits the Core .NET walkthrough; it adds Ops-specific steps n–t rather than restating Core steps a–m
- [ ] Per-environment provisioning sequence covers Key Vault (Invariant 17), App Configuration (ADR-0005), system-assigned managed identity (per env), Container App (Invariants 34, 35, 36)
- [ ] Deploy-identity OIDC federated credential is documented as a separate identity from the NuGet-publishing identity, with explicit RBAC scoping (no Key Vault secret-read per ADR-0077 D7)
- [ ] Org-secret binding delta from Core .NET is named (Discord webhooks per ADR-0084, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`)
- [ ] File-tree delta from Core .NET names the `infra/` Bicep layout and the `HoneyDrunk.{NodeName}.Tests.Integration` + `Tests.E2E` projects per Invariant 50
- [ ] `deploy.yml` example matches ADR-0033 trigger model (push-to-main → dev; tags → staging then prod; environment-keyed concurrency; per-deployable path scoping)
- [ ] Health-endpoint setup per ADR-0066 is documented (anonymous live/ready, auth-required `/health`)
- [ ] Post-merge confirmation steps include dev-deploy verification, managed-identity secret-read smoke test, and health-endpoint check
- [ ] Companion docs are linked (all eight infrastructure walkthroughs referenced above)
- [ ] Repo-level `CHANGELOG.md` updated for the new walkthrough

## Human Prerequisites

None for the walkthrough authoring itself. (The walkthrough *describes* human portal steps; the packet that uses the walkthrough has the human prerequisites.)

## Referenced ADR Decisions

**ADR-0082 D5 n–t** — Ops Deployable additions: Key Vault per env, App Configuration per env, managed identity per env, Container Apps wiring, Bicep modules, deploy trigger model, health endpoints.
**ADR-0082 D7** — Walkthrough unlocked by acceptance.
**ADR-0005** — App Configuration provisioning; env-var endpoint discipline.
**ADR-0012 D5** — Caller permissions superset rule.
**ADR-0015** — Container Apps stance; naming, shared environment/registry, revision mode.
**ADR-0033** — Deploy trigger model (push-to-main → dev; tags → staging+prod; environment-keyed concurrency; per-deployable path scoping).
**ADR-0066** — Health endpoints contract.
**ADR-0077** — Bicep modules at `infra/`; deploy-identity does not have secret-read rights.

## Constraints

- **Inheritance, not duplication.** This walkthrough inherits from `node-standup-core-dotnet.md` — it adds the Ops-specific steps n–t and the deploy plumbing, but does not restate Core steps a–m.
- **Per-environment, per-Node specificity.** Key Vault, App Configuration, and managed identity are per-Node-per-environment; the walkthrough is explicit about the `{service}` and `{env}` substitution and the 13-char service-name limit (Invariant 19).
- **Deploy identity ≠ publish identity.** The walkthrough is explicit that the deploy OIDC federated credential is a separate identity from the NuGet-publishing one, with no Key Vault secret-read rights per ADR-0077 D7.
- **`deploy.yml` example tracks ADR-0033.** Per-deployable path scoping for multi-deployable repos; environment-keyed concurrency; correct branch/tag triggers.
- **PR body metadata.** Strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

## Labels

`chore`, `tier-2`, `meta`, `docs`, `infra`, `ops`, `adr-0082`, `wave-3`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` — the operational walkthrough for Ops Deployable .NET Node standups, inheriting from the Core .NET walkthrough and adding D5 n–t plus deploy plumbing.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Generalize the Communications and Notify Cloud Ops Deployable standup precedents into a reusable walkthrough.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 3.
- ADRs: ADR-0082 (D5 n–t, D7), ADR-0005, ADR-0012 D5, ADR-0015, ADR-0033, ADR-0066, ADR-0077.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (canonical procedure doc). Packet 02 (Core .NET walkthrough) is not a hard blocker — this walkthrough composes against `constitution/node-standup.md` and references the Core walkthrough as a Companion doc — but landing 02 first reduces churn for the reader.

**Constraints:**
- Inheritance, not duplication — Core .NET steps are referenced, not restated.
- Per-environment, per-Node specificity (the `{service}`-`{env}` substitution and 13-char limit).
- Deploy identity ≠ publish identity; deploy identity has no secret-read.
- `deploy.yml` example follows ADR-0033 trigger model.
- PR body carries strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

**Key Files:**
- `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` (new)

**Contracts:** None changed.
