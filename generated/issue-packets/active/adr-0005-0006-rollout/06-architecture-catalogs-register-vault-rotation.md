---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "catalogs", "adr-0006"]
dependencies: []
adrs: ["ADR-0006"]
wave: 1
---

# Feature: Register `HoneyDrunk.Vault.Rotation` in `catalogs/nodes.json` and `relationships.json`

## Summary
Add the new `HoneyDrunk.Vault.Rotation` sub-Node to the Grid catalogs so it shows up in routing, dependency walks, and the Grid graph.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0006 introduces a brand-new sub-Node. Until it is registered in `catalogs/nodes.json` and `catalogs/relationships.json`, every future scope pass will miss it and routing rules will fail to match it. This packet is small and independent and can run in parallel with the repo scaffold packet.

## Proposed Implementation

### `catalogs/nodes.json`
Append a new Node entry with at minimum:
```json
{
  "id": "honeydrunk-vault-rotation",
  "type": "node",
  "name": "HoneyDrunk.Vault.Rotation",
  "public_name": "HoneyDrunk.Vault.Rotation",
  "short": "Tier-2 third-party secret rotation Function",
  "description": "Azure Function App that rotates third-party provider secrets (Resend, Twilio, OpenAI, ...) into per-Node Key Vaults on schedule. Sibling to HoneyDrunk.Vault; separate deployable.",
  "sector": "Core",
  "signal": "Seed",
  "cluster": "foundation",
  "tags": ["infrastructure", "rotation", "secrets", "functions", "azure"],
  "links": { "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Vault.Rotation" }
}
```
Match the style of existing entries (see `honeydrunk-vault` block as reference). Mark `signal: "Seed"` until first deployment.

### `catalogs/relationships.json`
Add edges:
- `honeydrunk-vault-rotation` → `honeydrunk-vault` (consumes `ISecretStore` for its own credentials)
- `honeydrunk-vault-rotation` → `honeydrunk-kernel` (standard Node runtime dependency)
- `honeydrunk-vault-rotation` → every deployable Node whose vault it writes into (dependency direction: rotator → target vaults). Enumerate from current Live deployable Nodes: auth, web-rest, data, notify, pulse (pending), actions, studios. Use the actual IDs present in `nodes.json`.

### `routing/repo-discovery-rules.md`
Add a keyword mapping row:
```
| rotation, secret rotation, IRotator, RotationResult, third-party rotation, Vault.Rotation | HoneyDrunk.Vault.Rotation |
```

### `repos/HoneyDrunk.Vault.Rotation/` stub
Create `overview.md`, `boundaries.md`, `active-work.md`, `invariants.md`, `integration-points.md` as minimal stubs pointing at ADR-0006 and marking the Node as "scaffolding in progress". Match the file set present in `repos/HoneyDrunk.Vault/`.

## Affected Packages
- None (catalog + docs only)

## Boundary Check
- [x] Catalogs live in HoneyDrunk.Architecture
- [x] No cross-repo changes
- [x] Doesn't duplicate routing rules — adds a single new row

## Acceptance Criteria
- [ ] New Node entry present in `catalogs/nodes.json`, JSON valid, style matches existing entries
- [ ] `catalogs/relationships.json` includes all edges listed above, validated against existing IDs
- [ ] `routing/repo-discovery-rules.md` has the new keyword row
- [ ] `repos/HoneyDrunk.Vault.Rotation/` stub directory created with five minimal files
- [ ] `relationships.json` still forms a DAG (invariant 4)
- [ ] `initiatives/active-initiatives.md` updated with a new "Vault.Rotation Bring-Up" initiative entry pointing at the scaffold packet

## Context
- ADR-0006 §New sub-Node
- Invariant 4 — no circular dependencies
- `catalogs/nodes.json` current structure for reference

## Dependencies
None — can run in parallel with the scaffold packet and the infra walkthroughs packet. Should merge *before* downstream per-Node migration packets so routing works.

## Labels
`chore`, `tier-1`, `meta`, `catalogs`, `adr-0006`

## Agent Handoff

**Objective:** Register the new sub-Node in catalogs, routing, and repos-docs stubs.
**Target:** HoneyDrunk.Architecture, branch from `main`
**Context:**
- Goal: Make the Grid aware of `HoneyDrunk.Vault.Rotation` before downstream migration work begins
- Feature: Rotation lifecycle rollout
- ADRs: ADR-0006

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:** None (but the repo scaffolding packet is a natural sibling)

**Constraints:**
- Invariant 4 — DAG must remain acyclic
- Don't invent relationship edges beyond what ADR-0006 supports

**Key Files:**
- `catalogs/nodes.json`
- `catalogs/relationships.json`
- `routing/repo-discovery-rules.md`
- `repos/HoneyDrunk.Vault.Rotation/overview.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/boundaries.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/active-work.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/invariants.md` (new)
- `repos/HoneyDrunk.Vault.Rotation/integration-points.md` (new)
- `initiatives/active-initiatives.md`

**Contracts:** None
