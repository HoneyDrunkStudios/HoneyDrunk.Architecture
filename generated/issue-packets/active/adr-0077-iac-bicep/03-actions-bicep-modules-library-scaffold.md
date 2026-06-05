---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "infrastructure", "adr-0077", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0077", "ADR-0012"]
wave: 3
initiative: adr-0077-iac-bicep
node: honeydrunk-actions
---

# Scaffold the bicep/modules library layout and bicepconfig.json linter rules

> **STATUS — SUPERSEDED (2026-06-02) by packets 11 + 13.** Filed as `Actions#118` (OPEN, unmerged). The ADR-0077 amendment (2026-06-02) relocates the Bicep modules library out of `HoneyDrunk.Actions/bicep/` and into the new `HoneyDrunk.Infrastructure` repo: the tree + single root `bicepconfig.json` land in packet 11 (repo standup); the module bodies land in packet 13. This packet is retained for traceability; do not execute it. Close `Actions#118` as superseded by packets 11 + 13. See `dispatch-plan.md`.

## Summary
Scaffold the Bicep modules library structure in `HoneyDrunk.Actions/bicep/` per ADR-0077 D2 — create the seven per-concern subdirectories (`networking/`, `compute/`, `identity/`, `data/`, `secrets/`, `messaging/`, `observability/`), an empty-state `README.md` documenting the library's conventions and the registry-publish flow, and `bicepconfig.json` carrying the linter rules that enforce ADR-0077 D3 (required tags, name conventions, secret-shaped-literal detection). Do not author actual modules yet — those land in packet 05.

## Context
ADR-0077 D2 places the canonical Bicep modules library in `HoneyDrunk.Actions/bicep/modules/`, organized by **concern** (not by Node):

| Module group | Owns |
|---|---|
| **Networking** | Virtual networks, subnets, private endpoints, NSGs, public IPs, DNS zones |
| **Compute** | Container Apps environment, Container Apps, Container Apps Jobs, Function Apps |
| **Identity** | Managed identities, role assignments, RBAC scopes |
| **Data** | SQL servers, SQL databases, Postgres servers, Cosmos accounts, Storage accounts, Redis |
| **Secrets** | Key Vault, Key Vault secrets-as-resources, App Configuration stores |
| **Messaging** | Service Bus namespaces, topics, subscriptions, queues, Event Grid topics |
| **Observability** | Application Insights, Log Analytics, Action Groups, Alerts |

ADR-0077 D3 commits the linter rules in `bicepconfig.json`. The rules enforce:
- Required tags on every resource: `hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`.
- Resource-name conventions: per-resource-type prefix (`ca-`, `redis-`, `kv-`, `sb-`, `acr`, `cae-`, `log-`, etc.), `hd-` Grid identifier, `{service}` or `{node}` name within the ≤13-char service-name length limit per invariant 19, `{env}` suffix.
- Best-effort secret-shaped-literal detection (`accountKey`, `connectionString`, `password`, `apiKey` literals) to enforce ADR-0077 D7 / invariant 85.

Bicep's `bicepconfig.json` supports custom analyzer rules via its `analyzers.core.rules` block and pluggable conventions. The first cut of rules uses Bicep's built-in linter rule set with project-specific severity tuning; pure-custom rules (Bicep does not yet support fully arbitrary user-defined rules) for tag and name enforcement land as required-input checks expressed via module-parameter `@allowed` / `@minLength` / `@description` decorators inside each module rather than via the global linter. **Document this clearly in the library README and the `bicepconfig.json` comments** — the linter handles what Bicep's analyzer surface supports; the module structure itself enforces the rest at module-author time.

This packet **does not** author actual modules — packet 05 does that. This packet ships the scaffold and the rules so packet 04 (the publish workflow) and packet 05 (the modules) have a stable surface to land on.

`HoneyDrunk.Actions` is the Grid's CI/CD control plane per ADR-0012. The repo is not a versioned .NET solution — no version bump, no `## NuGet Dependencies`. The repo `CHANGELOG.md` (if it keeps one for the workflow surface) is updated per the repo convention.

## Scope
- `bicep/` (new top-level directory in `HoneyDrunk.Actions`).
- `bicep/README.md` (new) — documents the library's conventions, the seven per-concern subdirectories, the registry-publish flow (`bicep-publish.yml` — packet 04), the module reference pattern (`br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`), and the linter rule set.
- `bicep/modules/networking/.gitkeep` — placeholder so the empty directory tracks in git.
- `bicep/modules/compute/.gitkeep`
- `bicep/modules/identity/.gitkeep`
- `bicep/modules/data/.gitkeep`
- `bicep/modules/secrets/.gitkeep`
- `bicep/modules/messaging/.gitkeep`
- `bicep/modules/observability/.gitkeep`
- `bicep/bicepconfig.json` (new) — the linter configuration. Placed at `bicep/` (not `bicep/modules/`) so it applies to the modules **and** to any future per-repo `infra/main.bicep` examples or test templates that might land in the repo. Bicep resolves `bicepconfig.json` by file-system search from the template directory upward.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface — a new entry for the `bicep/` substrate.

## Proposed Implementation
1. **Create the directory tree.** `bicep/`, `bicep/modules/`, and the seven per-concern subdirectories. Each per-concern subdirectory gets a `.gitkeep` for git tracking. The repo's existing `actions/`, `docs/`, `examples/`, `scripts/` top-level dirs are the precedent for a new top-level `bicep/`.
2. **`bicep/README.md`** — author it with these sections:
   - **Library purpose** — quote ADR-0077 D2 verbatim on per-concern modularization and registry publishing.
   - **Per-concern subdirectories** — the table from ADR-0077 D2 (the seven concerns and what each owns).
   - **Module file convention** — one Bicep file per module, named `{name}.bicep` (e.g. `compute/containerApp.bicep`). Tests, if added later, in a sibling `{name}.tests.bicep`. Per-concern subdir may carry a small `README.md` listing its modules and their parameters once modules land.
   - **Publish flow** — `bicep-publish.yml` (packet 04) runs `az bicep publish` for each changed module against `acrhdbicep` on tagged release of the form `modules/v{N}.{N}.{N}`. The publish flow is per-tag, not per-PR — modules are version-pinned at consumer time, never overwritten.
   - **Module reference pattern** — consumers reference the registry path with an immutable version: `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`. Local-path references (`./modules/...`) are forbidden in per-Node templates — only registry references.
   - **Linter rules** — what `bicepconfig.json` enforces and what is enforced by module-parameter convention instead.
3. **`bicep/bicepconfig.json`** — author with these settings:
   - The Bicep schema reference (`$schema: https://aka.ms/bicep/bicepconfig-schema.json`).
   - `analyzers.core.enabled: true`.
   - `analyzers.core.rules` block enabling the built-in rules that align with ADR-0077: `no-hardcoded-env-urls`, `no-unused-params`, `no-unused-vars`, `secure-parameter-default`, `secure-params-in-nested-deploy`, `outputs-should-not-contain-secrets`, `simplify-interpolation`, `prefer-interpolation`, `protect-commandtoexecute-secrets`, `use-resource-id-functions`, `use-stable-resource-identifiers`, `use-stable-vm-image`. Set severity `error` on the security-shaped rules (`secure-parameter-default`, `outputs-should-not-contain-secrets`, `protect-commandtoexecute-secrets`, `secure-params-in-nested-deploy`); `warning` on the others.
   - Include a `// ` JSON-comment block (Bicep's `bicepconfig.json` supports JSON-with-comments) explaining what the file does NOT enforce (per-Node tag presence, name convention) and why (Bicep's analyzer surface does not yet support fully custom rules; tag/name enforcement is module-author convention via `@allowed` parameters and the module README).
4. **Update the repo `CHANGELOG.md`** if the repo keeps one for the workflow surface — note the new `bicep/` substrate and the ADR-0077 reference.

## Affected Files
- `bicep/` (new directory tree)
- `bicep/README.md` (new)
- `bicep/bicepconfig.json` (new)
- `bicep/modules/{networking,compute,identity,data,secrets,messaging,observability}/.gitkeep` (new)
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface

## NuGet Dependencies
None. `HoneyDrunk.Actions` ships GitHub Actions YAML and (now) Bicep — no .NET project is created or modified by this packet.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0077 D2 names "`HoneyDrunk.Actions/bicep/modules/`" as the canonical home; ADR-0012 makes Actions the CI/CD control plane.
- [x] The seven per-concern subdirectory structure matches ADR-0077 D2's table exactly.
- [x] No code change in any Node — this is repo scaffolding.

## Acceptance Criteria
- [ ] `bicep/` directory exists at the repo root with seven per-concern subdirectories (`networking`, `compute`, `identity`, `data`, `secrets`, `messaging`, `observability`) each holding a `.gitkeep` so empty dirs track in git
- [ ] `bicep/README.md` documents the library purpose (verbatim quote of ADR-0077 D2's modularization rationale), the per-concern subdirectory table, the file convention (`{name}.bicep`), the publish flow (`bicep-publish.yml` on `modules/v{N}.{N}.{N}` tag), and the module-reference pattern (`br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`)
- [ ] `bicep/bicepconfig.json` carries the Bicep linter rules enabling the security-shaped rules at `error` severity (`secure-parameter-default`, `outputs-should-not-contain-secrets`, `protect-commandtoexecute-secrets`, `secure-params-in-nested-deploy`) and the convention rules at `warning` severity
- [ ] `bicep/bicepconfig.json` carries a comment block explicitly stating what the file does NOT enforce (per-Node tag presence, full name convention) and why — so a future executor reading the rules understands the scope
- [ ] `bicep/README.md` documents that tag and name enforcement is module-author convention (via `@allowed` / `@minLength` / `@description` decorators and the module README) until Bicep's analyzer surface supports custom rules
- [ ] No `.bicep` file exists in `bicep/modules/` yet — module authoring lives in packet 05
- [ ] No workflow file is added or modified by this packet — `bicep-publish.yml` is packet 04; the `bicep lint` PR gate is packet 07
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 D2 — Modularize by concern.** Modules live in `HoneyDrunk.Actions/bicep/modules/`, organized by the seven per-concern subdirectories. Published to `acrhdbicep` on tagged release (`modules/v{N}.{N}.{N}`). Per-Node templates consume via registry references; local-path references forbidden in per-Node templates.

**ADR-0077 D3 — Linter rules in `bicepconfig.json`.** Required tags, naming conventions, secret-shaped-literal detection. CI gate (packet 07) fails the PR on violation. `bicepconfig.json` enforces what Bicep's analyzer surface supports; the rest is module-author convention until Bicep's analyzer surface evolves.

**ADR-0012 — Actions is the Grid CI/CD control plane.** The Bicep modules library and the publish/deploy workflows belong in `HoneyDrunk.Actions`.

**Invariant 19 — Service names in Azure resource naming must be ≤ 13 characters.** Modules accepting a `service` or `node` name parameter should `@maxLength(13)` that parameter to enforce the invariant at module-author time.

## Constraints
- **Module structure mirrors ADR-0077 D2's table exactly.** Seven subdirectories, the concerns named verbatim. Do not add or rename; if a future need arises, that is a follow-up packet.
- **No actual modules in this packet.** `.gitkeep` placeholders only. Module authoring is packet 05.
- **`bicepconfig.json` enables built-in rules; custom rules deferred.** Bicep does not yet support fully custom analyzer rules. The README documents this clearly.
- **Local-path module references are forbidden in per-Node templates.** Document this in the README; modules-in-this-repo reference siblings by relative path during local development, but per-Node `infra/main.bicep` references use registry paths only.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `infrastructure`, `adr-0077`, `wave-3`

## Agent Handoff

**Objective:** Scaffold the Bicep modules library tree (`bicep/modules/{networking,compute,identity,data,secrets,messaging,observability}/`), author the library README, and commit the `bicepconfig.json` linter rules. Do not author actual modules.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Land the library substrate so packet 04 (publish workflow) and packet 05 (first module set) can build on a stable scaffold.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 3.
- ADRs: ADR-0077 D2/D3 (primary), ADR-0012 (Actions as CI/CD control plane), invariant 19 (≤13-char service names).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0077 should be Accepted before its substrate scaffold lands.

**Constraints:**
- Module structure exactly matches ADR-0077 D2's seven concerns — verbatim names.
- No actual modules in this packet — `.gitkeep` only.
- `bicepconfig.json` enables Bicep's built-in security-shaped rules at `error` severity; convention rules at `warning`.
- Document what the linter does NOT enforce, and why — so a future executor understands the scope.
- Local-path module references are forbidden in per-Node templates — registry references only.

**Key Files:**
- `bicep/README.md`
- `bicep/bicepconfig.json`
- `bicep/modules/{networking,compute,identity,data,secrets,messaging,observability}/.gitkeep`

**Contracts:** None — repo scaffolding only.
