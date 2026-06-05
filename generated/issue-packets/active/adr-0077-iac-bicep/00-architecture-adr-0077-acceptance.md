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

# Accept ADR-0077 — flip status, add the three IaC invariants, amend invariant 35, register the initiative

> **STATUS — SUPERSEDED (2026-06-02) by packet 18** (`18-architecture-adr-0077-acceptance.md`). Filed as `Architecture#384` (OPEN, unmerged — nothing shipped). The ADR-0077 amendment (2026-06-02) drops the cross-repo Bicep module registry, so this packet's invariant-35 carve-out is no longer needed and its IaC-invariant wording (which referenced the registry / per-Node `infra/` / `br:` refs) is reworded by packet 18. This packet is retained for traceability; do not execute it. Close `Architecture#384` as superseded by packet 18. See `dispatch-plan.md`.

## Summary
Flip ADR-0077 (Infrastructure-as-Code — Bicep) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new IaC invariants ADR-0077 commits in its Consequences/Invariants section to `constitution/invariants.md` (numbered per the reservation claimed in `constitution/invariant-reservations.md`), amend invariant 35's text to carve out the Bicep-module ACR (`acrhdbicep`) so it does not collide with the shared container-image ACR (`acrhdshared{env}`), and register the `adr-0077-iac-bicep` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0077 commits **Bicep** as the canonical IaC tool for every Azure resource the Grid provisions. Today, infrastructure is provisioned via a mix of Azure Portal clicks and ad-hoc Azure CLI scripts — there is no version-controlled, declarative IaC for the Grid's overall topology. ADR-0077 decides the tool (Bicep), the modularization strategy (per-concern modules in `HoneyDrunk.Actions/bicep/modules/`, published to a shared `acrhdbicep` Bicep registry), the naming and tagging conventions (linter-enforced), the per-environment deploy model (`main.bicep` + `parameters.{env}.bicepparam`), and the migration posture (D6 — new infrastructure goes through Bicep from day one; existing manually-provisioned resources are grandfathered and imported opportunistically at their next significant touchpoint).

The ADR decides:
- **D1** — Bicep is the canonical IaC tool for all Azure infrastructure. No manual Portal provisioning for new resources. No raw ARM JSON. No CLI scripts as primary IaC. Terraform / Pulumi / Crossplane / Azure Blueprints / mixed-IaC are explicitly rejected.
- **D2** — Modularize by concern, not by Node. Modules live in `HoneyDrunk.Actions/bicep/modules/` (Networking / Compute / Identity / Data / Secrets / Messaging / Observability) and are published to a dedicated `acrhdbicep` Azure Container Registry on tagged release. Per-Node templates consume modules via registry references (`br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`).
- **D3** — Naming and tagging conventions enforced by Bicep linter rules (`bicepconfig.json`). Required tags: `hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`. Required name shape: per-resource-type prefix + `hd-` Grid identifier + `{service}` or `{node}` + `{env}` suffix. CI gate fails the PR on linter violation.
- **D4** — Per-environment deployment via `main.bicep` + `parameters.{env}.bicepparam`. The Actions reusable deploy workflow `job-deploy-bicep.yml` runs `az deployment group create` per environment.
- **D5** — Vendor-exit posture explicitly acknowledged. The Grid is Azure-only by current design; modularization by concern is the hedge against future Terraform migration cost. The vendor-exit playbook itself is named as separate follow-up work.
- **D6** — Migration from existing manual provisioning: new infrastructure goes through Bicep from day one; existing resources are imported opportunistically (export ARM → decompile to Bicep → reconcile drift → adopt) at their next significant touchpoint. No retroactive campaign.
- **D7** — Bicep templates never contain secret values. Secrets reference Vault by URI; parameter files carry non-secret config only; the deploy identity has rights to provision resources, not to read secret values.
- **D8** — Out of scope: vendor-exit playbook content, multi-region topology, Azure Policy / Blueprints, detailed cost-allocation tagging beyond D3, Bicep-generated docs, deploy-workflow specifics, subscription / resource-group topology.

ADR-0077 is a **policy / substrate** ADR. The concrete code — the Actions modules library, `bicepconfig.json`, the `bicep-publish.yml` and `job-deploy-bicep.yml` workflows, the first module set, the `bicep lint` PR gate, the per-Node template-scaffold pattern, and the D6 import playbook — lands as the remaining packets in this initiative. Every other packet references ADR-0077's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0077-infrastructure-as-code-bicep.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0077 row Status column to Accepted.
- `constitution/invariant-reservations.md` — claim the next free block (size 3) and add the row. The block is `{N1}–{N3}` (claimed at file authoring time as **90–92**; if a later in-flight ADR's packet 00 lands first, rebase upward and update every `{N*}` placeholder in this packet and `constitution/invariants.md` together).
- `constitution/invariants.md` — add the three new IaC invariants (see Proposed Implementation for exact text), numbered `{N1}/{N2}/{N3}` (the block reserved in `invariant-reservations.md`). **Amend the existing invariant 35 text in the same PR** to explicitly carve out the Bicep-module ACR.
- `initiatives/active-initiatives.md` — register the `adr-0077-iac-bicep` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0077 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0077 index row in `adrs/README.md` to Accepted.
3. **Claim the invariant block.** Read `constitution/invariant-reservations.md`. Take the next free block (size 3) — at file authoring time **90–92**. Add the row in the same PR as this packet's edits; if the file shows a higher next-free at claim time, take that instead and update every `{N1}/{N2}/{N3}` placeholder in this packet's body together with the invariant text in step 4.
4. Add three new invariants to `constitution/invariants.md`, numbered `{N1}/{N2}/{N3}` (the block from step 3). The text, taken verbatim-in-substance from ADR-0077's Consequences "Invariants" section:
   - **`{N1}` — New Azure infrastructure is provisioned via Bicep.** Every new Azure resource — Container Apps, Key Vault, App Configuration, Service Bus, Event Grid, Storage, Application Insights, Azure Cache for Redis, anything else — is declared in a Bicep template, version-controlled in the owning repo, and applied through the `HoneyDrunk.Actions` reusable Bicep deploy workflow. Manual Azure Portal provisioning of new resources, raw ARM JSON, and Azure CLI scripts as primary IaC are boundary violations. Existing resources manually provisioned before ADR-0077 are grandfathered and imported to Bicep at their next significant touchpoint per ADR-0077 D6 — not in a retroactive campaign. See ADR-0077 D1, D6.
   - **`{N2}` — Bicep templates never contain secret values.** Bicep templates reference secrets via Vault URIs and `keyVaultSecret` resources; parameter files (`.bicepparam`) carry non-secret configuration only; the GitHub Actions OIDC-federated deploy identity has rights to provision resources, not to read secret values. This codifies invariant 8 (secrets never appear in logs, traces, exceptions, or telemetry) extended to IaC payloads. The linter flags hardcoded secret-shaped literals (`accountKey`, `connectionString`, `password`, `apiKey`) on a best-effort basis. See ADR-0077 D7.
   - **`{N3}` — Bicep templates apply the Grid naming and tagging conventions enforced by linter rules.** Every Azure resource declared in Bicep carries a per-resource-type prefix (`ca-`, `kv-`, `redis-`, `sb-`, etc.), the `hd-` Grid identifier, a `{service}` or `{node}` name truncated to fit Azure's resource-name length limits (≤13 chars per invariant 19 where applicable), and an `{env}` suffix. Every resource carries the required tags `hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, and `hd:adr`. `bicepconfig.json` flags missing tags and non-conformant names; `bicep lint` in `pr-core.yml` fails the PR on violation. See ADR-0077 D3.
   - Create a new `## Infrastructure-as-Code Invariants` section. The file's existing sectioning convention groups invariants by topic (Dependency / Context / Secrets / Packaging / Testing / Infrastructure / Work Tracking / AI / Code Review / Hosting Platform / Hive Sync / Multi-Tenant Boundary / Communications / Audit). IaC is a new cross-cutting topic; place the new section after `## Audit Invariants`.
5. **Amend invariant 35 to explicitly carve out the Bicep-module ACR.** The current invariant 35 text reads roughly "one shared ACR (`acrhdshared{env}`) per environment." Amend it to read (substantively): **"one shared container-image ACR `acrhdshared{env}` per environment; one shared Bicep-module ACR `acrhdbicep` is permitted Grid-wide per ADR-0077 D2 (environment-agnostic, modules-only, distinct purpose)."** This is a text-only amendment — invariant 35 keeps its number. Land it in the same PR as the new IaC invariants so the new `acrhdbicep` registry catalog/walkthrough work in packets 01/02 does not contradict the constitution.
6. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0077-infrastructure-as-code-bicep.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md` (claim the size-3 block; add the row)
- `constitution/invariants.md` (add the three new IaC invariants; amend invariant 35 text)
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency — IaC is a substrate concern; no contract cascade.

## Acceptance Criteria
- [ ] ADR-0077 header reads `**Status:** Accepted`
- [ ] The ADR-0077 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a row reserving the `{N1}–{N3}` block for ADR-0077 (size 3), per the file's "How a packet 00 claims a block" procedure
- [ ] `constitution/invariants.md` carries the three new IaC invariants (new Azure infrastructure is provisioned via Bicep with the D6 grandfather carve-out; Bicep templates never contain secret values; Bicep templates apply Grid naming + tagging conventions enforced by linter rules), numbered `{N1}/{N2}/{N3}` under a new `## Infrastructure-as-Code Invariants` section, each citing ADR-0077
- [ ] `constitution/invariants.md` invariant 35 text is amended in the same PR to read (substantively) "one shared container-image ACR `acrhdshared{env}` per environment; one shared Bicep-module ACR `acrhdbicep` is permitted Grid-wide per ADR-0077 D2 (environment-agnostic, modules-only, distinct purpose)" — invariant 35 keeps its number
- [ ] `initiatives/active-initiatives.md` registers the `adr-0077-iac-bicep` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 D1 — Bicep is the canonical IaC tool.** Every Azure resource declared in Bicep; no manual Portal provisioning for new resources; no raw ARM JSON; no CLI scripts as primary IaC. Terraform / Pulumi / Crossplane explicitly rejected (Azure-only Grid; abstraction tax not justified; state-file overhead avoided; AI-assistance gradient on Bicep is good).

**ADR-0077 D3 — Naming and tagging conventions enforced by Bicep linter rules.** `bicepconfig.json` flags missing required tags and non-conformant names; CI `bicep lint` fails the PR on violation. Required tags `hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`.

**ADR-0077 D6 — Migration from existing manual provisioning.** New infrastructure goes through Bicep from day one; existing resources are imported opportunistically (export → decompile → reconcile → adopt) at their next significant touchpoint, not in a retroactive campaign. The discipline matches the grandfather pattern from ADR-0058 D9, ADR-0074 D6, ADR-0075 D4.

**ADR-0077 D7 — Secrets in Bicep.** Templates never contain secret values; secrets reference Vault by URI; parameter files carry non-secret config only; deploy identity has provisioning rights, not secret-read rights. Codifies invariant 8 extended to IaC payloads.

**ADR-0077 Consequences — Invariants.** ADR-0077 adds exactly three invariants: (1) new Azure infrastructure is provisioned via Bicep with the D6 grandfather carve-out; (2) Bicep templates never contain secret values; (3) Bicep templates apply Grid naming + tagging conventions enforced by linter rules.

## Constraints
- **Acceptance precedes flip.** ADR-0077 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers come from the reservation registry.** Read `constitution/invariant-reservations.md` and claim the next free block (size 3) in the same PR. At file authoring time the block is **90–92**; this packet uses `{N1}/{N2}/{N3}` placeholders throughout — substitute the actual numbers at PR time. If a racing ADR's packet 00 lands first, rebase upward, update the registry row, and update every `{N*}` placeholder here and in `constitution/invariants.md` together.
- **New section.** The three IaC invariants are a new cross-cutting topic; create a `## Infrastructure-as-Code Invariants` section after `## Audit Invariants` rather than appending to an unrelated section.
- **Invariant 35 amendment is mandatory and lands in this PR.** Invariant 35 today names `acrhdshared{env}` as "the" shared ACR — a literal collision with the new `acrhdbicep` registry that packets 01/02 catalog and provision. Amend invariant 35's text in this same PR to explicitly carve out the Bicep-module ACR per the wording in step 5 of Proposed Implementation. Do NOT defer the amendment to a follow-up packet; the constitution must not contradict the catalog/walkthrough work that lands in Waves 1–2.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0077`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0077 to Accepted, claim the next free invariant block in `invariant-reservations.md`, add the three IaC invariants to `constitution/invariants.md`, amend invariant 35 to carve out `acrhdbicep`, and register the Bicep IaC initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0077 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0077 Infrastructure-as-Code — Bicep rollout, Wave 1.
- ADRs: ADR-0077 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0077 stays Proposed until this PR merges.
- Claim the invariant block from `constitution/invariant-reservations.md` in this same PR. The reserved range at file authoring is **90–92**; substitute the live `{N1}/{N2}/{N3}` placeholders against the registry at PR time. Land the three new invariants under a new `## Infrastructure-as-Code Invariants` section; do not renumber existing invariants.
- Amend invariant 35's text in the same PR to carve out `acrhdbicep` — the constitution must not contradict the new registry catalog/walkthrough work in packets 01/02. Invariant 35 keeps its number; only the text changes.

**Key Files:**
- `adrs/ADR-0077-infrastructure-as-code-bicep.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
