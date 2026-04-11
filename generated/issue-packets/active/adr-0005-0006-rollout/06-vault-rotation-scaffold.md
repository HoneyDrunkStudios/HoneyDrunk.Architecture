---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault.Rotation
labels: ["feature", "tier-3", "core", "infrastructure", "new-node", "adr-0006"]
dependencies: []
adrs: ["ADR-0006"]
wave: 1
initiative: adr-0005-0006-rollout
blocked: repo-does-not-exist-yet
node: honeydrunk-vault
---

# Feature: Scaffold new sub-Node `HoneyDrunk.Vault.Rotation` Function App

## Summary
Create the `HoneyDrunk.Vault.Rotation` repo, solution, CI pipeline, Function App skeleton, and its own `kv-hd-vaultrot-{env}` vault so Tier-2 third-party secret rotation has a home.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault.Rotation` (new — does not exist yet)

## Motivation
ADR-0006 Tier 2 introduces `HoneyDrunk.Vault.Rotation` as a brand-new sub-Node to rotate third-party provider secrets (Resend, Twilio, OpenAI, etc.) that Azure cannot rotate natively. A single shared rotation Node keeps operational burden low and RBAC auditable in one place. This packet is scaffolding only — individual provider rotators land in follow-up issues.

## Proposed Implementation

### Repo scaffolding
- Create `HoneyDrunkStudios/HoneyDrunk.Vault.Rotation` on GitHub
- Solution layout (match existing Node conventions — see `HoneyDrunk.Notify` and `HoneyDrunk.Pulse` repos as reference):
  ```
  HoneyDrunk.Vault.Rotation/
    HoneyDrunk.Vault.Rotation.sln
    src/
      HoneyDrunk.Vault.Rotation/              (Function App host)
      HoneyDrunk.Vault.Rotation.Abstractions/ (IRotator, RotationResult, etc.)
      HoneyDrunk.Vault.Rotation.Providers/    (per-provider rotators — Resend, Twilio, OpenAI stubs)
    tests/
      HoneyDrunk.Vault.Rotation.Tests/
      HoneyDrunk.Vault.Rotation.Canary/
    .github/workflows/
    CHANGELOG.md
    README.md
    LICENSE
  ```
- `.gitignore`, `Directory.Build.props`, `global.json` aligned with the rest of the Grid
- Kernel + Vault dependencies wired via `AddHoneyDrunkNode` and the new env-driven `AddVault`

### Function App skeleton
- One placeholder timer-triggered Function (`RotateThirdPartySecretsFunction`) that logs "not yet implemented" and exits
- `IRotator` interface in `.Abstractions`:
  ```csharp
  public interface IRotator
  {
      string ProviderName { get; }
      Task<RotationResult> RotateAsync(RotationContext ctx, CancellationToken ct);
  }
  ```
- DI registration scaffolding that discovers `IRotator` implementations

### Infrastructure (documented, not provisioned here)
- Its own `kv-hd-vaultrot-{env}` vault (13-char budget: `vaultrot` = 8 chars — fits)
- System-assigned Managed Identity on the Function App
- RBAC: `Key Vault Secrets Officer` on every downstream vault it rotates into (granted per-vault, not wildcard)
- OIDC federated credentials for CI
- Portal walkthroughs belong in the `architecture-infra-portal-walkthroughs` packet

### CI pipeline
- Standard Grid workflow: build, test, canary, publish artifact, deploy-to-staging (OIDC)
- Must include the SLA deploy-gate step (see `actions-deploy-gate-sla-check` packet) when that lands
- No service-principal client secrets anywhere in the workflow

## Affected Packages
- New: `HoneyDrunk.Vault.Rotation` (Function host)
- New: `HoneyDrunk.Vault.Rotation.Abstractions`
- New: `HoneyDrunk.Vault.Rotation.Providers`

## NuGet Dependencies

### New: `HoneyDrunk.Vault.Rotation` (Function App host)
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — required on every HoneyDrunk .NET project |
| `HoneyDrunk.Kernel` (latest stable) | `IGridContext`, `AddHoneyDrunkNode` bootstrap |
| `HoneyDrunk.Vault` (latest stable) | `ISecretStore` — for reading the Function App's own credentials |
| `Microsoft.Azure.Functions.Worker` (latest stable) | Isolated worker model host |
| `Microsoft.Azure.Functions.Worker.Sdk` (latest stable) | Build tooling for isolated Functions |
| `Microsoft.Azure.Functions.Worker.Extensions.Timer` (latest stable) | Timer trigger for the rotation schedule |
| `Microsoft.Azure.Functions.Worker.Extensions.Http` (latest stable) | HTTP trigger for the webhook invalidation endpoint |
| `Azure.Identity` (latest stable) | `DefaultAzureCredential` / Managed Identity |
| ProjectRef: `HoneyDrunk.Vault.Rotation.Abstractions` | `IRotator`, `RotationContext`, `RotationResult` |
| ProjectRef: `HoneyDrunk.Vault.Rotation.Providers` | Provider stub discovery |

### New: `HoneyDrunk.Vault.Rotation.Abstractions`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — required on every HoneyDrunk .NET project |

### New: `HoneyDrunk.Vault.Rotation.Providers`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — required on every HoneyDrunk .NET project |
| `Azure.Identity` (latest stable) | Credential chain for future provider API calls |
| `Azure.Security.KeyVault.Secrets` (latest stable) | Writing rotated secret versions into target Key Vaults |
| ProjectRef: `HoneyDrunk.Vault.Rotation.Abstractions` | `IRotator` contract |

### New: `HoneyDrunk.Vault.Rotation.Tests`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — required on every HoneyDrunk .NET project |
| `xunit` (latest stable) | Test framework |
| `xunit.runner.visualstudio` (latest stable) | VS test runner integration |
| `Microsoft.NET.Test.Sdk` (latest stable) | Test SDK |
| `coverlet.collector` (latest stable) | Code coverage |
| ProjectRef: `HoneyDrunk.Vault.Rotation.Abstractions` | Unit under test |
| ProjectRef: `HoneyDrunk.Vault.Rotation.Providers` | Unit under test |

### New: `HoneyDrunk.Vault.Rotation.Canary`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — required on every HoneyDrunk .NET project |
| `xunit` (latest stable) | Test framework |
| `xunit.runner.visualstudio` (latest stable) | VS test runner integration |
| `Microsoft.NET.Test.Sdk` (latest stable) | Test SDK |
| ProjectRef: `HoneyDrunk.Vault.Rotation.Abstractions` | Integration boundary under test |

## Boundary Check
- [x] Rotation logic does not belong in `HoneyDrunk.Vault` (Vault is a client/cache/provider library — no outbound scheduled write responsibilities)
- [x] Does not duplicate Azure-native rotation (Tier 1 is KV policy, not this Node)
- [x] One shared rotator is simpler than per-Node rotators and aligns with ADR-0006 Alternatives Considered

## Acceptance Criteria
- [ ] Repo created under HoneyDrunkStudios
- [ ] Solution builds with zero warnings
- [ ] Function App skeleton deploys locally via `func start`
- [ ] `IRotator` abstraction defined and discovered by DI
- [ ] CI workflow present, green on first commit, no client secrets
- [ ] `CHANGELOG.md` created with v0.0.1 entry
- [ ] `README.md` describes purpose, tier, and links ADR-0006
- [ ] Canary project stub exists (no tests yet)
- [ ] 13-char service-name budget verified for `vaultrot`

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 19:** Service names in Azure resource naming must be ≤ 13 characters. Required to fit within Azure's 24-character Key Vault name limit (`kv-hd-{service}-{env}`). See ADR-0005.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 1 (Azure-native): ≤ 30 days. Tier 2 (third-party via rotation Function): ≤ 90 days. Certificates: auto-renewed 30 days before expiry. Exceptions must be logged in Log Analytics. See ADR-0006.

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. Required for rotation SLA monitoring, unauthorized access alerting, and audit. See ADR-0006.

## Referenced ADR Decisions

**ADR-0006 (Secret Rotation and Lifecycle):** Five-tier rotation model — Azure-native rotation (≤30d), third-party rotation via `HoneyDrunk.Vault.Rotation` Function (≤90d), Event Grid cache invalidation on `SecretNewVersionCreated`, audit via Log Analytics, and deploy-blocking rotation SLAs.
- **§Tier 2:** `HoneyDrunk.Vault.Rotation` is a new Azure Function App sub-Node for rotating third-party secrets (Resend, Twilio, OpenAI). Triggers via Event Grid or manual. Mints new key via provider API, writes to Key Vault, disables old version after grace period. Where no rotation API exists, emits reminder pointing to manual runbook.
- **§New sub-Node:** `HoneyDrunk.Vault.Rotation` needs its own vault (`kv-hd-vaultrot-{env}`), Managed Identity, RBAC as Secrets Officer on every vault it rotates into, CI pipeline, and standard Grid scaffolding.

## Context
- ADR-0006 §Tier 2 and §New sub-Node
- Invariants 17 (per-Node vault), 19 (13-char service name), 20 (rotation SLA), 21 (no version pinning), 22 (diag to Log Analytics)
- Reference repos: `HoneyDrunk.Notify`, `HoneyDrunk.Pulse`

## Dependencies
- **`create-vault-rotation-repo`** (human-only chore, filed on `HoneyDrunk.Architecture`) — the repo must exist on GitHub before this packet can be filed as an issue. This is the hard blocker.
- **Architecture infra setup packet** (`architecture-infra-setup`) — provides both the new-Node catalog registration and the portal walkthroughs for creating the `kv-hd-vaultrot-{env}` vault and wiring OIDC

**Filing sequence:** file `create-vault-rotation-repo` immediately (human-only). Once a human closes it (repo created), file this packet against the new repo. Until then, this packet is excluded from the filing batch.

## Labels
`feature`, `tier-3`, `core`, `infrastructure`, `new-node`, `adr-0006`

## Agent Handoff

**Objective:** Stand up the `HoneyDrunk.Vault.Rotation` repo, solution, CI, and Function App skeleton end-to-end.
**Target:** new repo `HoneyDrunkStudios/HoneyDrunk.Vault.Rotation`, branch `main` (initial)
**Context:**
- Goal: Create the Tier-2 rotation home so downstream rotator issues have somewhere to land
- Feature: Rotation lifecycle rollout
- ADRs: ADR-0006 (five-tier rotation model, third-party rotation via Vault.Rotation Function, Event Grid cache invalidation, Log Analytics audit, deploy-blocking SLAs)

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:**
- `create-vault-rotation-repo` packet (human-only chore on HoneyDrunk.Architecture) — hard blocker; repo must exist first
- `architecture-infra-setup` packet (catalogs + portal walkthroughs, same repo)

**Constraints:**
- Invariant 11: One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — one repo per Node
- Invariant 19: Service names in Azure resource naming must be ≤ 13 characters. Required to fit within Azure's 24-character Key Vault name limit (`kv-hd-{service}-{env}`). See ADR-0005. — service name short enough for `kv-hd-vaultrot-{env}` to fit Azure's 24-char limit
- No cross-vault wildcard RBAC — grants must be per-target-vault
- No client-secret CI authentication anywhere

**Key Files (to be created):**
- Entire new repo tree listed above

**Contracts:**
- New public `IRotator` + `RotationContext` + `RotationResult` in `.Abstractions`
- No consumers yet — pure producer of a new sub-Node surface
