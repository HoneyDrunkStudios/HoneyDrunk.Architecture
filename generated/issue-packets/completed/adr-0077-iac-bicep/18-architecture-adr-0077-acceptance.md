---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0077", "wave-1"]
dependencies: []
adrs: ["ADR-0077"]
accepts: ["ADR-0077"]
wave: 1
initiative: adr-0077-iac-bicep
node: honeydrunk-architecture
---

# Accept ADR-0077 (amended) — flip status, add the three IaC invariants, register the initiative

> **Supersedes packet 00** (`Architecture#384`). Packet 00 accepted ADR-0077 in its pre-amendment shape and included an invariant-35 carve-out for the `acrhdbicep` Bicep-module registry. The ADR-0077 amendment (2026-06-02) drops the registry, so the invariant-35 carve-out is NO LONGER NEEDED — invariant 35 stands unchanged. The three new IaC invariants are reworded to remove references to the dropped registry, per-Node `infra/` directories, and `br:` registry refs, and to point at the consolidated `HoneyDrunk.Infrastructure` repo. Issue `Architecture#384` is closed as superseded by this packet. **ADR-0077 is still Proposed on `main`; nothing has shipped — this is a pre-implementation re-cut, not a migration off a shipped shape.**

## Summary
Flip ADR-0077 (Infrastructure-as-Code — Bicep, as amended 2026-06-02) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, claim the next free invariant block (size 3) in `constitution/invariant-reservations.md`, add the three new IaC invariants to `constitution/invariants.md` (reworded for the consolidated-repo / no-registry shape), and register the `adr-0077-iac-bicep` initiative in `initiatives/active-initiatives.md`. **Do NOT amend invariant 35** — the registry is dropped, so no carve-out is needed.

## Context
ADR-0077 commits Bicep as the canonical IaC tool for every Azure resource the Grid provisions. The 2026-06-02 amendment consolidates all Bicep *content* into a new `HoneyDrunk.Infrastructure` repo (`modules/` + `platform/` + `nodes/`), drops the cross-repo module registry (`acrhdbicep` ACR, `bicep-publish.yml`, the SemVer-tag-publish flow, `br:` refs), keeps the deploy/lint *pipeline* in `HoneyDrunk.Actions` per ADR-0012, and decouples infra deploys from application release tags. The tool choice (D1), modularize-by-concern principle (D2), naming/tagging rules (D3), secrets-by-URI discipline (D7), Azure-deep posture (D5), and grandfather/import posture (D6) are unchanged.

The ADR decides (post-amendment effective shape):
- **D1** — Bicep is the canonical IaC tool. No manual Portal provisioning for new resources; no raw ARM JSON; no CLI scripts as primary IaC. (Location amended: Bicep files live in `HoneyDrunk.Infrastructure`, not per-Node repos.)
- **D2** — Modularize by concern (the seven concern groups). (Distribution amended: modules referenced by local relative path within the consolidated repo; the registry is dropped.)
- **D3** — Naming/tagging conventions enforced by `bicepconfig.json` linter rules. A single root config covers `modules/`/`platform/`/`nodes/`.
- **D4** — Per-environment deployment via `main.bicep` + `parameters.{env}.bicepparam`. (Location amended: under `nodes/{node}/` and `platform/`. Cadence amended: infra deploys on its own cadence, decoupled from app release tags.)
- **D5** — Azure-deep vendor posture, acknowledged honestly.
- **D6** — New infrastructure goes through Bicep from day one; existing resources imported opportunistically. Unchanged.
- **D7** — Bicep templates never contain secret values. Unchanged.
- **D8** — Out of scope; the `platform/` layer's home (`rg-hd-platform-shared`) is the one revisited item.
- **Amendment (2026-06-02)** — consolidation into `HoneyDrunk.Infrastructure`; registry dropped; pipeline stays in Actions; decoupled cadence; invariant 35 unchanged.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0077-infrastructure-as-code-bicep.md` — flip `**Status:** Proposed` to `**Status:** Accepted`; reconcile the `## Consequences` and `## Follow-up Work` prose to the post-amendment shape (these two trailing sections still describe the pre-amendment shape — `HoneyDrunk.Actions/bicep/modules/`, per-Node `infra/`, the `acrhdbicep` registry, the publish workflow — and now contradict the amendment block).
- `adrs/README.md` — update the ADR-0077 row Status to Accepted.
- `constitution/invariant-reservations.md` — claim the next free block (size 3); add the row.
- `constitution/invariants.md` — add the three new IaC invariants under a new `## Infrastructure-as-Code Invariants` section. **Do NOT amend invariant 35.**
- `initiatives/active-initiatives.md` — register the `adr-0077-iac-bicep` initiative with the post-amendment packet checklist.

## Proposed Implementation
1. Flip the ADR-0077 header to `**Status:** Accepted`.
2. Update the ADR-0077 index row in `adrs/README.md` to Accepted.
3. **Claim the invariant block.** Read `constitution/invariant-reservations.md`; take the next free block (size 3). Add the row in this PR. Use `{N1}/{N2}/{N3}` placeholders throughout; substitute the live numbers at PR time. If a racing ADR's packet lands first, rebase upward and update every placeholder together.
4. **Add three new IaC invariants** to `constitution/invariants.md`, numbered `{N1}/{N2}/{N3}`, under a new `## Infrastructure-as-Code Invariants` section placed after `## Audit Invariants`:
   - **`{N1}` — New Azure infrastructure is provisioned via Bicep.** Every new Azure resource — Container Apps, Key Vault, App Configuration, Service Bus, Event Grid, Storage, Application Insights, Azure Cache for Redis, anything else — is declared in a Bicep template in `HoneyDrunk.Infrastructure` (per-concern reusable `modules/`, the shared-foundation `platform/` layer, or a per-Node leaf template under `nodes/{node}/`) and applied through the `HoneyDrunk.Actions` reusable Bicep deploy workflow (`job-deploy-bicep.yml`) per ADR-0012. Manual Azure Portal provisioning of new resources, raw ARM JSON, and Azure CLI scripts as primary IaC are boundary violations. Existing resources manually provisioned before ADR-0077 are grandfathered and imported to Bicep at their next significant touchpoint per ADR-0077 D6 — not in a retroactive campaign. See ADR-0077 D1, D6, and the 2026-06-02 amendment.
   - **`{N2}` — Bicep templates never contain secret values.** Bicep templates reference secrets via Vault URIs and `keyVaultSecret` resources; parameter files (`.bicepparam`) carry non-secret configuration only; the GitHub Actions OIDC-federated deploy identity has rights to provision resources, not to read secret values. This codifies invariant 8 (secrets never appear in logs, traces, exceptions, or telemetry) extended to IaC payloads. The linter flags hardcoded secret-shaped literals (`accountKey`, `connectionString`, `password`, `apiKey`) on a best-effort basis. See ADR-0077 D7.
   - **`{N3}` — Bicep templates apply the Grid naming and tagging conventions enforced by linter rules.** Every Azure resource declared in Bicep carries a per-resource-type prefix (`ca-`, `kv-`, `redis-`, `sb-`, etc.), the `hd-` Grid identifier, a `{service}` or `{node}` name truncated to fit Azure's resource-name length limits (≤13 chars per invariant 19 where applicable), and an `{env}` suffix. Every resource carries the required tags `hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, and `hd:adr`. A single root `bicepconfig.json` in `HoneyDrunk.Infrastructure` flags missing tags and non-conformant names across `modules/`, `platform/`, and `nodes/`; the `bicep lint` gate (consumed from `HoneyDrunk.Actions` per ADR-0012) fails the PR on violation. See ADR-0077 D3.
5. **Do NOT amend invariant 35.** The registry is dropped per the 2026-06-02 amendment; there is no second ACR to carve out. Invariant 35 keeps its existing text and number, governing the shared container-image ACR `acrhdshared{env}` only.
6. **Register the initiative** in `initiatives/active-initiatives.md` with the post-amendment wave structure and packet checklist (packets 07, 10–18; note 00–06/08/09 superseded).
7. **Reconcile the ADR's trailing prose to the amendment.** The `## Consequences` (esp. *Affected Nodes*) and `## Follow-up Work` sections still describe the pre-amendment shape. Update them to the consolidated shape while preserving the decision history (the amendment block and D1–D8 are NOT touched):
   - *Affected Nodes* — `HoneyDrunk.Actions` no longer "hosts the per-concern Bicep modules under `bicep/modules/`"; it owns the reusable deploy/lint **workflows** only. Add **`HoneyDrunk.Infrastructure`** as the Node owning all Bicep content (`modules/` + `platform/` + `nodes/`). Per-Node entries no longer "own `infra/main.bicep` in its repo" — they own a `nodes/{node}/` leaf template in `HoneyDrunk.Infrastructure`.
   - *Follow-up Work* — drop/re-point the items naming `HoneyDrunk.Actions/bicep/modules/`, the registry, the publish workflow, and `br:`/`modules/v*` flows; the surviving items (deploy workflow in Actions, lint config, import playbook) re-point to the consolidated shape.
   - Where a line is superseded rather than deleted, prefer a brief "(per the 2026-06-02 amendment)" parenthetical over silent rewrites, so the record stays auditable.

## Affected Files
- `adrs/ADR-0077-infrastructure-as-code-bicep.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. Markdown governance files only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0077 header reads `**Status:** Accepted`
- [ ] The ADR-0077 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a row reserving the `{N1}–{N3}` block for ADR-0077 (size 3)
- [ ] `constitution/invariants.md` carries the three new IaC invariants (new Azure infrastructure is provisioned via Bicep in `HoneyDrunk.Infrastructure` with the D6 grandfather carve-out; Bicep templates never contain secret values; Bicep templates apply Grid naming + tagging conventions enforced by linter rules), numbered `{N1}/{N2}/{N3}` under a new `## Infrastructure-as-Code Invariants` section, each citing ADR-0077
- [ ] None of the three invariants references the dropped registry, per-Node `infra/` directories, or `br:` refs — they point at `HoneyDrunk.Infrastructure` (`modules/`/`platform/`/`nodes/`) and the Actions deploy/lint workflows
- [ ] **Invariant 35 is NOT amended** — no `acrhdbicep` carve-out; its text and number are unchanged
- [ ] `initiatives/active-initiatives.md` registers the `adr-0077-iac-bicep` initiative with the post-amendment packet checklist (active: 07, 10–18; superseded: 00–06, 08, 09)
- [ ] The ADR's `## Consequences` (incl. *Affected Nodes*) and `## Follow-up Work` sections are reconciled to the consolidated shape — no surviving reference to `HoneyDrunk.Actions/bicep/modules/`, per-Node `infra/`, the `acrhdbicep` registry, the publish workflow, or `br:`/`modules/v*` flows; `HoneyDrunk.Infrastructure` is named as the Bicep-content Node — while D1–D8 prose and the amendment block remain untouched
- [ ] No catalog schema change in this packet (catalog updates land in packets 10/12)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 D1/D2/D3/D4/D6/D7 + the 2026-06-02 amendment.** Bicep is canonical (D1). Modularize by concern (D2). Naming/tagging linter rules (D3). Per-environment deploy via `main.bicep` + `.bicepparam` (D4). Grandfather/opportunistic import (D6). Secrets-by-URI (D7). The amendment consolidates all Bicep content into `HoneyDrunk.Infrastructure` (`modules/`+`platform/`+`nodes/`), drops the registry (`acrhdbicep`, `bicep-publish.yml`, SemVer-tag-publish, `br:` refs), keeps the deploy/lint pipeline in Actions (ADR-0012), decouples infra deploys from app release tags, and confirms invariant 35 stands unchanged.

## Constraints
- **Acceptance precedes flip.** ADR-0077 stays Proposed until this PR merges.
- **Invariant numbers come from the reservation registry.** Claim the next free size-3 block in this same PR; substitute the `{N1}/{N2}/{N3}` placeholders against the registry at PR time.
- **New section.** Place the three IaC invariants under a new `## Infrastructure-as-Code Invariants` section after `## Audit Invariants`; do not renumber existing invariants.
- **Do NOT amend invariant 35.** The registry is dropped; the carve-out from the superseded packet 00 is explicitly removed. If you find yourself editing invariant 35, stop — that is the old shape.
- **No registry language in the invariants.** The IaC invariants must not mention `acrhdbicep`, `bicep-publish.yml`, `modules/v{N}.{N}.{N}`, `br:`, or per-Node `infra/` directories.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0077`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0077 (amended) to Accepted, claim the invariant block, add the three IaC invariants reworded for the consolidated-repo / no-registry shape, register the initiative — and do NOT amend invariant 35.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the amended ADR-0077 so the re-cut packets can reference its decisions as live rules.
- Feature: ADR-0077 Infrastructure-as-Code — Bicep rollout (amended 2026-06-02), Wave 1.
- ADRs: ADR-0077 + 2026-06-02 amendment (primary), ADR-0008 (initiative/packet conventions), ADR-0012 (pipeline in Actions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet of the re-cut initiative.

**Constraints:**
- Acceptance precedes flip.
- Claim the invariant block from `invariant-reservations.md` in this same PR; substitute `{N1}/{N2}/{N3}` at PR time.
- Three IaC invariants under a new section; no renumbering of existing invariants.
- DO NOT amend invariant 35 (registry dropped — no carve-out).
- No registry/`infra/`/`br:` language in the invariants.

**Key Files:**
- `adrs/ADR-0077-infrastructure-as-code-bicep.md`, `adrs/README.md`
- `constitution/invariant-reservations.md`, `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
