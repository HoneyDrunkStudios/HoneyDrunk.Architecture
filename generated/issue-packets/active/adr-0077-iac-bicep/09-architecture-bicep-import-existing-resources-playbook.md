---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0077", "wave-6"]
dependencies: ["packet:00"]
adrs: ["ADR-0077"]
wave: 6
initiative: adr-0077-iac-bicep
node: honeydrunk-architecture
---

# Author the bicep-import-existing-resources playbook for the D6 opportunistic-migration path

> **STATUS — SUPERSEDED (2026-06-02) by packet 17.** Filed as `Architecture#388` (OPEN, unmerged). The D6 import playbook survives in concept, but this packet's body references the dropped registry (`br:acrhdbicep.azurecr.io/...`), per-Node-repo `infra/` import targets, and the old packet numbers (02/05/06/08). Packet 17 re-cuts it for the consolidated `HoneyDrunk.Infrastructure` repo (import targets `nodes/{node}/` or `platform/`; local-path module refs; cross-refs to packets 14/15/16). This packet is retained for traceability; do not execute it. Close `Architecture#388` as superseded by packet 17. See `dispatch-plan.md`.

## Summary
Author `infrastructure/patterns/bicep-import-existing-resources.md` — the canonical playbook for the ADR-0077 D6 opportunistic-migration path: when a manually-provisioned Azure resource (an existing Vault namespace, Service Bus namespace, Container App, etc.) needs a configuration change, the operator imports it to Bicep before applying the change. The playbook documents the four-step path the ADR commits — export ARM → decompile to Bicep → reconcile drift → adopt — plus the per-Node responsibilities, the `grid-health.json` reconciliation pattern, the rollback path, and the failure modes specific to imported resources (deployment-mode safety, immutable property mismatches, missing tags).

## Context
ADR-0077 D6 commits the opportunistic-migration discipline:

> **Existing resources are imported to Bicep opportunistically.** When an existing resource needs a configuration change, the operator authors a Bicep template for it as part of the change. The migration path: export the existing resource to ARM JSON (`az resource show --ids ... --query properties`), decompile it to Bicep (`az bicep decompile --file resource.json`), reconcile drift between the decompiled template and the desired state, and adopt the resource into the deploy pipeline thereafter.
>
> **A per-Node import-to-Bicep packet** is filed when the Node's next significant infrastructure work happens; not a campaign.

The discipline matches the grandfather pattern from ADR-0058 D9, ADR-0074 D6, ADR-0075 D4 — no retroactive campaign, no flag-day migration, no parallel-track maintenance. Each Node converges on Bicep-managed-everything when its existing infrastructure naturally touches.

The playbook is the canonical reference operators (or the `scope` agent) consult when they file a per-Node import packet. Without a documented playbook, each import is invented from scratch — including the parts where drift surfaces unexpected differences between the deployed resource and what the operator thought it was, where `az bicep decompile` produces ARM-ish Bicep that needs hand-cleanup to match the modules-library shape, and where immutable resource properties (Storage account kind, ACR SKU, etc.) make a naive deployment fail because Bicep wants to recreate-not-update.

The playbook does **not** import any specific resource — that is per-Node work, filed as a per-Node packet when the Node's next infrastructure touch happens. The playbook is the procedure operators follow when they file that packet.

Sibling to packet 08's per-Node template scaffold pattern. Together packets 08 + 09 cover the two D6 paths: (08) new infrastructure goes through Bicep from day one; (09) existing infrastructure is imported opportunistically. The `scope` agent uses them complementarily — packet 08 for greenfield infrastructure packets; packet 09 for import packets.

This is a docs packet. No code, no .NET project.

## Scope
- `infrastructure/patterns/bicep-import-existing-resources.md` (new) — the import playbook.

## Proposed Implementation
1. **Author `infrastructure/patterns/bicep-import-existing-resources.md`** with these sections:

   **Purpose.** Quote ADR-0077 D6 verbatim. Cross-reference packet 08 — the greenfield pattern — and explain when to use this playbook (import) vs that one (greenfield).

   **When this playbook is the right choice.**
   - An existing manually-provisioned Azure resource needs a configuration change. Importing first, then changing through Bicep, is the path.
   - An existing resource is structurally in scope for the Bicep substrate (it would be re-provisioned via a module from packet 05 if it were new today) but is not yet under IaC.
   - Not for: brand-new resources (packet 08 is the right pattern for those); not for resources the Grid is about to delete (just delete via portal — no import needed); not for cross-environment audit (running this on a clean dev resource that already matches a module's defaults is busywork).

   **The four-step path.**
   - **Step 1: Export.** Use `az resource show --ids {resource-id} --output json` to capture the full ARM representation. Save to `infra/imported-{resource}-snapshot.json` in the Node repo (gitignored if it contains anything sensitive, or scrubbed before commit). Document any non-default Azure resource configuration the operator did not remember setting.
   - **Step 2: Decompile.** Run `az bicep decompile --file infra/imported-{resource}-snapshot.json`. This produces a `.bicep` file alongside the JSON. The output is ARM-shaped Bicep — verbose, full of explicit defaults, no use of the modules library. **It is a starting point, not the final template.**
   - **Step 3: Reconcile drift.** Two reconciliations happen here:
     1. **Library-shape reconciliation.** Hand-rewrite the decompiled `.bicep` to consume modules from `acrhdbicep` (packet 05) — replace the inline `Microsoft.KeyVault/vaults` resource with a `module identityVault 'br:acrhdbicep.azurecr.io/modules/secrets/keyVault:1.0.0' = { ... }` reference. Replace inline tags with the composed `tags` variable per packet 08's pattern. Replace inline secrets-as-properties with `secretRef`s per ADR-0077 D7.
     2. **Drift reconciliation.** Compare the decompiled (now library-shaped) template against the desired state. If the deployed resource has properties that no longer match the Grid's desired configuration (e.g. soft-delete disabled where ADR-0005 wants it enabled, a wrong tag, a SKU below the module default), record the drift in the import packet's body. Decide for each drift: **(a)** the desired state takes precedence (the Bicep deploy will update the resource to match); **(b)** the deployed state takes precedence (the template carries the deployed value as a parameter / override). Document each decision in the per-Node import packet so the change is visible at PR review.

   **Step 4: Adopt.** Apply the Bicep template via `job-deploy-bicep.yml` (packet 06). The first deploy executes the drift reconciliation. **Run `az deployment what-if` first** — what-if for an imported resource will list every property Azure considers different between the template and the live resource; review carefully before applying. Some property differences are immutable (resource kind, location, certain SKUs); a difference there means recreate-not-update, which is rarely what the import wants — fix the template to match the deployed property and try again.

   **Per-Node responsibilities.**
   - The per-Node import packet is filed by the `scope` agent when the operator declares the trigger (a configuration change needed on the existing resource).
   - The packet's `target_repo` is the Node's repo (not Architecture); the templates land under the Node's `infra/`.
   - The packet's body documents the drift decisions per resource.
   - Acceptance includes a successful `what-if` + apply on at least the `dev` environment.

   **`grid-health.json` reconciliation.** Add an `imported_via_bicep: true` (or similar) field on the per-resource entry, or move the entry from a "manually-provisioned" section to a "bicep-managed" section if the catalog uses that shape. Inspect `catalogs/grid-health.json` at packet execution time and follow its existing shape — do not invent a new structure.

   **Common failure modes.**
   - **Immutable property mismatch.** The deployed resource's `kind` or `location` differs from the decompiled template. Bicep wants to delete-and-recreate. Fix the template to match.
   - **Missing tags.** Deployed resources may have no `hd:*` tags. The first Bicep apply adds them — this is a desirable drift, document the operator's awareness.
   - **Secrets in the decompiled output.** `az bicep decompile` may surface secret-shaped properties (admin keys, connection strings) as inline parameters. Strip them; use `secretRef` shapes; re-route the consumer to the Vault.
   - **Resource group mismatch.** The deployed resource may live in a non-conformant RG. The import packet either accepts the RG (and tolerates the naming mismatch) or moves the resource (which is a separate, more invasive operation — usually defer).
   - **Existing role assignments.** RBAC assignments are separately-managed resources. The decompiled output may or may not include them. Add them to the template explicitly if they are part of the desired state.

   **Rollback path.**
   - **Before the first Bicep apply.** Revert the PR; no state changed; the existing resource stays as it was.
   - **After the first Bicep apply.** The resource is now Bicep-managed and may have been updated to reconcile drift. Rollback requires either (a) re-applying the previous state via a captured ARM snapshot (which the import packet should commit alongside the new template — the snapshot from Step 1), or (b) accepting the Bicep-managed state and rolling forward with corrections.
   - **Escape hatch.** A resource that fails import (immutable property mismatch the operator cannot resolve) can stay manually-provisioned — document in `grid-health.json` as `imported_via_bicep: false` and note the blocking property. The grandfather pattern is bidirectional under D6.

   **Cross-references.** Packet 08 (greenfield pattern), packet 02 (ACR walkthrough), packets 06/07 (workflows), the existing `infrastructure/walkthroughs/` portal docs (for resources that have a sibling portal walkthrough — useful context on what the original provisioning shape was).

2. **No `infrastructure/patterns/README.md` edit needed** — packet 08 creates that README; this packet adds a new file to the directory and packet 08's executor adds the cross-reference. If packets 08 and 09 land in different waves and packet 08 has not yet created the README, this packet's executor creates `infrastructure/patterns/README.md` instead, listing both patterns.

## Affected Files
- `infrastructure/patterns/bicep-import-existing-resources.md` (new)
- `infrastructure/patterns/README.md` — extend the list of patterns to include this one (or create the README if packet 08 has not yet landed; coordinate by checking the file's existence at execution time)

## NuGet Dependencies
None. Docs-only — no .NET project.

## Boundary Check
- [x] `HoneyDrunk.Architecture` is the correct home for patterns — routing rule maps to it directly.
- [x] The playbook does not import any specific resource — that is per-Node work.
- [x] No code change in any other repo.

## Acceptance Criteria
- [ ] `infrastructure/patterns/bicep-import-existing-resources.md` exists and covers: (a) purpose with the verbatim ADR-0077 D6 quote, (b) when this playbook is the right choice (and when it is not), (c) the four-step path (export, decompile, reconcile drift in two reconciliations — library-shape and drift-decision, adopt via what-if + apply), (d) per-Node responsibilities (per-Node target repo, the `scope` agent files the per-Node packet, per-resource drift decisions documented in the packet body), (e) `grid-health.json` reconciliation, (f) common failure modes (immutable property mismatch, missing tags, secrets in decompiled output, RG mismatch, role assignments), (g) the rollback path including the snapshot-ARM-JSON safety
- [ ] The playbook explicitly cross-references packet 08 (greenfield), packet 02 (ACR walkthrough), packets 06/07 (workflows)
- [ ] The playbook covers the `what-if` review discipline: `az deployment what-if` runs first; immutable property mismatches are surfaced before any apply
- [ ] The playbook documents the `secretRef`-shape replacement for any secret-shaped property that `az bicep decompile` surfaces in plain form (invariant 8 / invariant 85 / ADR-0077 D7)
- [ ] The playbook documents the bidirectional grandfather posture: a resource that fails import can stay manually-provisioned with a note in `grid-health.json`
- [ ] `infrastructure/patterns/README.md` lists this pattern (and `per-node-bicep-template.md` from packet 08); if packet 08 has not yet landed, create the README and list both
- [ ] No specific resource is imported by this packet — the playbook is the procedure; per-Node imports are per-Node packets

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 D6 — Migration from existing manual provisioning.** "New infrastructure goes through Bicep from day one. Existing resources are imported to Bicep opportunistically. The migration path: export the existing resource to ARM JSON, decompile it to Bicep, reconcile drift between the decompiled template and the desired state, and adopt the resource into the deploy pipeline thereafter. A per-Node import-to-Bicep packet is filed when the Node's next significant infrastructure work happens; not a campaign."

**ADR-0077 D7 — Secrets in Bicep.** The decompile step may surface secret-shaped properties in plain form; the playbook documents stripping them and replacing with `secretRef` shapes.

**ADR-0077 D3 — Naming and tagging.** Imports may have missing tags; the first Bicep apply adds them. This is desirable drift; the playbook documents the operator's awareness.

**Grandfather pattern precedents.** ADR-0058 D9 (caching), ADR-0074 D6 (testing library), ADR-0075 D4 (documentation tooling) all use the same opportunistic-migration shape.

## Constraints
- **Playbook, not import.** The doc is the procedure; do not import any specific resource here.
- **The `what-if` discipline is mandatory.** Every import documents a `what-if` review before the first apply. Immutable property mismatches are caught before they become a recreate-not-update incident.
- **No secret values in code blocks.** Every code block in the doc must be safe to copy-paste. Strip secrets that `az bicep decompile` surfaces — never paste an example with a real-shaped secret literal.
- **Bidirectional grandfather.** A resource that fails import can stay manually-provisioned with documentation. The playbook documents this — D6's grandfather pattern is bidirectional.
- **Coordinate with packet 08 on the README.** Whichever packet lands first creates `infrastructure/patterns/README.md`; the other extends it. Check at execution time.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0077`, `wave-6`

## Agent Handoff

**Objective:** Author `infrastructure/patterns/bicep-import-existing-resources.md` — the canonical playbook for the ADR-0077 D6 opportunistic-migration path (export → decompile → reconcile drift → adopt).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Document the import procedure so per-Node import packets — filed when an existing resource's next significant touch happens — have a single canonical reference.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 6.
- ADRs: ADR-0077 D3/D6/D7 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0077 should be Accepted before its import playbook lands.

**Constraints:**
- Playbook, not import — do not import any specific resource.
- `what-if` review is mandatory before every first apply.
- No secret values in code blocks (invariant 8 / 85).
- Bidirectional grandfather — resources can stay manually-provisioned if import fails; document in `grid-health.json`.
- Coordinate with packet 08 on the `infrastructure/patterns/README.md` (whichever lands first creates it).

**Key Files:**
- `infrastructure/patterns/bicep-import-existing-resources.md` (new)
- `infrastructure/patterns/README.md` (create or extend)

**Contracts:** None — docs only.
