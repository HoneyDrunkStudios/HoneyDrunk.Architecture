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

## Context
- ADR-0006 §Tier 2 and §New sub-Node
- Invariants 17 (per-Node vault), 19 (13-char service name), 20 (rotation SLA), 21 (no version pinning), 22 (diag to Log Analytics)
- Reference repos: `HoneyDrunk.Notify`, `HoneyDrunk.Pulse`

## Dependencies
- **Catalogs registration packet** (`architecture-catalogs-register-vault-rotation`) — must land in the same window so the Grid graph knows the new Node exists
- **Infra walkthroughs packet** (`architecture-infra-portal-walkthroughs`) — walkthroughs for creating the `kv-hd-vaultrot-{env}` vault and wiring OIDC

## Labels
`feature`, `tier-3`, `core`, `infrastructure`, `new-node`, `adr-0006`

## Agent Handoff

**Objective:** Stand up the `HoneyDrunk.Vault.Rotation` repo, solution, CI, and Function App skeleton end-to-end.
**Target:** new repo `HoneyDrunkStudios/HoneyDrunk.Vault.Rotation`, branch `main` (initial)
**Context:**
- Goal: Create the Tier-2 rotation home so downstream rotator issues have somewhere to land
- Feature: Rotation lifecycle rollout
- ADRs: ADR-0006

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:**
- Catalog entries updated (parallel packet)
- Infra walkthroughs available (parallel packet)

**Constraints:**
- Invariant 11 — one repo per Node
- Invariant 19 — service name short enough for `kv-hd-vaultrot-{env}` to fit Azure's 24-char limit
- No cross-vault wildcard RBAC — grants must be per-target-vault
- No client-secret CI authentication anywhere

**Key Files (to be created):**
- Entire new repo tree listed above

**Contracts:**
- New public `IRotator` + `RotationContext` + `RotationResult` in `.Abstractions`
- No consumers yet — pure producer of a new sub-Node surface
