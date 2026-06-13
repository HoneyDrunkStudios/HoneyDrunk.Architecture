---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0077", "wave-4"]
dependencies: ["work-item:18", "work-item:15"]
adrs: ["ADR-0077"]
wave: 4
initiative: adr-0077-iac-bicep
node: honeydrunk-architecture
---

# Author the bicep-import-existing-resources playbook for the D6 opportunistic-migration path

> **Supersedes packet 09** (`Architecture#388`). The D6 import playbook survives essentially unchanged in concept, but packet 09's body references the dropped registry (`br:acrhdbicep.azurecr.io/modules/...:{semver}`), per-Node-repo `infra/` import targets, and the old packet numbers (02/05/06/08). Under the ADR-0077 amendment (2026-06-02), imports target `HoneyDrunk.Infrastructure/nodes/{node}/` (or `platform/`), modules are referenced by local relative path, and the cross-references point to the re-cut packets (13/14/15/16). This packet is the corrected playbook. Issue `Architecture#388` is closed as superseded by this packet.

## Summary
Author `infrastructure/patterns/bicep-import-existing-resources.md` — the canonical playbook for the ADR-0077 D6 opportunistic-migration path: when a manually-provisioned Azure resource needs a configuration change, the operator imports it to Bicep before applying the change. The four-step path (export ARM → decompile to Bicep → reconcile drift → adopt) is unchanged from the original; the *targets* are the consolidated repo (`HoneyDrunk.Infrastructure/nodes/{node}/` or `platform/`) and module references are local relative path (no registry).

## Context
ADR-0077 D6 (unchanged by the amendment) commits the grandfather/opportunistic-import posture: new infrastructure goes through Bicep from day one; existing manually-provisioned resources are imported opportunistically at their next significant touchpoint, not in a retroactive campaign. The amendment changes only *where* imported templates land (`HoneyDrunk.Infrastructure`, not the Node's own repo) and *how* modules are referenced (local relative path, not `br:` registry).

The greenfield counterpart is packet 15's `node-leaf-template.md`; this playbook is the import counterpart. Existing resources to import opportunistically include the early Vault namespaces, existing Service Bus namespaces, and the existing `dev` platform resources (`acrhdshared{dev}`, `cae-hd-dev`) — the latter is the first natural import target and is cross-referenced from packet 14.

This is a docs packet. No code, no .NET project.

## Scope
- `infrastructure/patterns/bicep-import-existing-resources.md` (new) — the import playbook.
- `infrastructure/patterns/README.md` — extend the pattern list (or create it if packet 15 has not yet landed; check at execution time).

## Proposed Implementation
1. **Author `infrastructure/patterns/bicep-import-existing-resources.md`:**
   - **Purpose.** Quote ADR-0077 D6 verbatim. Cross-reference packet 15 (greenfield `node-leaf-template.md`) — explain when to use import vs greenfield.
   - **When this playbook is the right choice.** An existing manually-provisioned resource needs a config change; an existing resource is structurally in scope for the substrate but not yet under IaC. Not for: brand-new resources (packet 15), resources about to be deleted, clean resources that already match module defaults.
   - **The four-step path:**
     - **Step 1: Export.** `az resource show --ids {resource-id} --output json`. Save the ARM snapshot (scrub/ gitignore anything sensitive). Capture non-default configuration.
     - **Step 2: Decompile.** `az bicep decompile --file {snapshot}.json`. ARM-shaped Bicep — a starting point, not the final template.
     - **Step 3: Reconcile drift.** Two reconciliations:
       1. **Library-shape reconciliation.** Hand-rewrite the decompiled `.bicep` to consume modules by **local relative path** — replace the inline `Microsoft.KeyVault/vaults` resource with `module nodeVault '../../modules/secrets/keyVault.bicep' = { ... }` (NOT a `br:` registry ref). Replace inline tags with the composed `tags` variable (packet 15's pattern). Replace inline secrets-as-properties with Vault URI / `keyVaultSecret` references (D7).
       2. **Drift reconciliation.** Compare the library-shaped template against desired state. For each drift, decide: desired-state-precedence (Bicep updates the resource) or deployed-state-precedence (template carries the deployed value). Document each decision in the per-resource import packet body.
     - **Step 4: Adopt.** Apply via `job-deploy-bicep.yml` (packet 16). **Run `az deployment group what-if` first** — review every property Azure considers different before applying. Immutable property differences (kind, location, certain SKUs) mean recreate-not-update — fix the template to match the deployed property.
   - **Where imported templates land (amendment).** `HoneyDrunk.Infrastructure/nodes/{node}/main.bicep` for Node-owned resources; `HoneyDrunk.Infrastructure/platform/main.bicep` for shared-foundation resources (e.g. the existing `dev` platform resources — cross-reference packet 14). NOT in the Node's own repo.
   - **Per-import responsibilities.** The per-import packet is filed by the `scope` agent when the operator declares the trigger; its `target_repo` is `HoneyDrunk.Infrastructure` (not the Node's repo — changed by the amendment); the body documents the drift decisions; acceptance includes a successful `what-if` + apply on at least `dev`.
   - **`grid-health.json` reconciliation.** Mark the resource Bicep-managed once imported (inspect the catalog shape at execution time; follow the existing structure).
   - **Common failure modes.** Immutable property mismatch; missing tags (the first apply adds `hd:*` tags — desirable drift); secrets surfaced in decompiled output (strip → Vault references); RG mismatch; existing role assignments.
   - **Rollback path.** Before first apply: revert the PR, no state changed. After first apply: re-apply the captured ARM snapshot, or roll forward. Escape hatch: a resource that fails import stays manually-provisioned (note it in `grid-health.json`) — the grandfather posture is bidirectional under D6.
   - **Cross-references.** Packet 15 (greenfield), packet 14 (`platform/` shared-foundation + its import target for existing `dev` resources), packet 16 (deploy workflow), the module READMEs in `HoneyDrunk.Infrastructure/modules/*/README.md`, the existing `infrastructure/walkthroughs/` portal docs.
2. **`infrastructure/patterns/README.md`** — extend the list (or create it, checking at execution time whether packet 15 already did).

## Affected Files
- `infrastructure/patterns/bicep-import-existing-resources.md` (new)
- `infrastructure/patterns/README.md` (extend or create)

## NuGet Dependencies
None. Docs only; no .NET project.

## Boundary Check
- [x] `HoneyDrunk.Architecture` is the home for patterns — routing maps exactly.
- [x] The playbook imports no specific resource — that is per-import work, target `HoneyDrunk.Infrastructure`.
- [x] No code change in any other repo.

## Acceptance Criteria
- [ ] `infrastructure/patterns/bicep-import-existing-resources.md` exists covering: (a) purpose with the verbatim ADR-0077 D6 quote, (b) when this playbook applies (and when not), (c) the four-step path (export, decompile, reconcile in two reconciliations, adopt via what-if + apply), (d) the amendment's import targets (`HoneyDrunk.Infrastructure/nodes/{node}/` or `platform/`, NOT the Node's own repo), (e) per-import responsibilities (target `HoneyDrunk.Infrastructure`, scope-agent-filed, per-resource drift decisions documented), (f) `grid-health.json` reconciliation, (g) common failure modes, (h) the rollback path including the ARM-snapshot safety
- [ ] All module references in the playbook use the **local relative path** form `'../../modules/{concern}/{name}.bicep'` — NO `br:acrhdbicep.azurecr.io/...` anywhere
- [ ] The playbook covers the `az deployment group what-if` review discipline before any apply, including immutable-property-mismatch handling
- [ ] The playbook documents stripping secret-shaped properties from decompiled output and replacing them with Vault references (D7 / invariant 8)
- [ ] The playbook documents the bidirectional grandfather posture (a failed import can stay manually-provisioned with a `grid-health.json` note)
- [ ] Cross-references point to packets 14/15/16 (not the dead 02/05/06/08) and the `HoneyDrunk.Infrastructure/modules/*/README.md`

## Human Prerequisites
None. (Actual imports are per-import work with their own Human Prerequisites — e.g. the deploy-identity RBAC on the target RG; this packet is the playbook only.)

## Referenced ADR Decisions
**ADR-0077 D6 (unchanged) — migration from existing manual provisioning.** "New infrastructure goes through Bicep from day one. Existing resources are imported to Bicep opportunistically." Export → decompile → reconcile → adopt; no retroactive campaign; bidirectional grandfather posture.

**ADR-0077 amendment (2026-06-02).** Imported templates land in `HoneyDrunk.Infrastructure/nodes/{node}/` or `platform/`; modules referenced by local relative path; no registry. The existing `dev` platform resources are the first natural import target (packet 14).

**ADR-0077 D7 (unchanged) — secrets in Bicep.** Strip secret-shaped properties from decompiled output; use Vault references.

## Constraints
- **Local-path references only.** Every module reference in the playbook is `'../../modules/{concern}/{name}.bicep'`. No `br:` anywhere.
- **Import target is `HoneyDrunk.Infrastructure`.** Not the Node's own repo (changed by the amendment).
- **Playbook, not an import.** Author no specific-resource import here.
- **`what-if` before apply.** The review discipline is load-bearing for import safety.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0077`, `wave-4`

## Agent Handoff

**Objective:** Author `infrastructure/patterns/bicep-import-existing-resources.md` — the D6 import playbook, re-cut for the consolidated `HoneyDrunk.Infrastructure` repo with local-path module refs.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: One canonical reference for opportunistically importing existing manually-provisioned resources to Bicep.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 4.
- ADRs: ADR-0077 D6 + 2026-06-02 amendment (primary), D7 (secrets).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0077 (amended) Accepted.
- `work-item:15` — the greenfield `node-leaf-template.md` pattern this playbook cross-references and complements.

**Constraints:**
- Local-path module refs only — no `br:`.
- Import target is `HoneyDrunk.Infrastructure` (nodes/ or platform/), not the Node's repo.
- Playbook, not an import.
- `what-if` before apply.

**Key Files:**
- `infrastructure/patterns/bicep-import-existing-resources.md` (new)
- `infrastructure/patterns/README.md` (extend/create)

**Contracts:** None — docs only.
