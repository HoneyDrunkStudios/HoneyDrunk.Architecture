---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ai", "docs", "adr-0041", "wave-1"]
dependencies: []
adrs: ["ADR-0041"]
accepts: ["ADR-0041"]
wave: 1
initiative: adr-0041-model-registry
node: honeydrunk-architecture
---

# Accept ADR-0041 — flip status, add the three AI-registry invariants, register the initiative

## Summary
Flip ADR-0041 (AI Model Registry and Approval Workflow) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new AI-registry invariants ADR-0041 commits in its Consequences/Invariants section to `constitution/invariants.md` as the pre-reserved invariants **72, 73, 74**, correct one stale sentence in ADR-0041's Context, and register the `adr-0041-model-registry` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0041 decides the shape of the Grid's AI model registry, who owns it, the approval workflow for new models, the capability-declaration validation step, and how cost guardrails attach to the registry. It was authored 2026-05-21 in a batch of cross-cutting Grid-gap ADRs and has had no scope until now.

The ADR decides:
- **D1** — the model registry is a declarative `models.json` catalog inside `HoneyDrunk.AI`, exposed via a new `IModelRegistry` interface in `HoneyDrunk.AI.Abstractions`. New records: `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `IApprovalStateWriter`.
- **D2** — initial approved provider set: Anthropic, OpenAI, Azure OpenAI, and a `local` placeholder (no models registered at v1). Adding a *provider* is an ADR amendment; adding a *model* under an approved provider is a packet.
- **D3** — capability declarations are asserted by a nightly **capability canary**, not vouched for; canary failure flips `ApprovalState` to `Preview` (≤24h) or `Deprecated` (≥7d).
- **D4** — the packet workflow for adding a model: register at `Preview`, add a canary, 14-day production preview, follow-up packet to flip to `Approved`.
- **D5** — the default `IRoutingPolicy` is cost-aware with capability matching; explicit policy overrides per call are recorded in the Audit emit.
- **D6** — `CostProfile.MaxBudgetPerCallUsd` is the per-call ceiling enforced by the router; ADR-0018's `ICostGuard` is the per-tenant period ceiling enforced upstream.
- **D7** — provider API keys live in Vault per ADR-0005; the router hot-reloads credentials without restart.
- **D8** — each `ProviderRegistration` records `DataEgressPolicy`, `RetentionDays`, `RegionPolicy` (data-residency-aware routing primitive).
- **D9** — self-hosted models register the same way (`ProviderId=local`, compute-cost `CostProfile`, `DataEgressPolicy=None`); none registered at v1.
- **D10** — `models.json` is read-only at runtime; the only runtime mutation is the canary-driven `ApprovalState` flip through the constrained `IApprovalStateWriter`, recorded in Audit.

ADR-0041 is a **policy / decision** ADR. The concrete code — `IModelRegistry`, the `models.json` loader, the canary harness, the cost-aware default policy, the Audit emit on dispatch — lands in `HoneyDrunk.AI` in this initiative. Catalog and contract registration land as Architecture packets. Every other packet in this initiative references ADR-0041's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0041-ai-model-registry-and-approval-workflow.md` — flip `**Status:** Proposed` to `**Status:** Accepted`; correct the stale Context sentence (see Proposed Implementation step 5).
- `adrs/README.md` — update the ADR-0041 row Status column to Accepted.
- `constitution/invariants.md` — add the three new AI-registry invariants (see Proposed Implementation for exact text) as the pre-reserved invariants **72, 73, 74**.
- `initiatives/active-initiatives.md` — register the `adr-0041-model-registry` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0041 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0041 index row in `adrs/README.md` to Accepted.
3. Add three new invariants to `constitution/invariants.md` as invariants **72, 73, 74** (the pre-reserved block — see Constraints). The text, taken verbatim-in-substance from ADR-0041's Consequences "Invariants" subsection:
   - **72 — No AI dispatch happens against an unregistered model.** Every model an `IModelRouter` dispatches to must have a `ModelRegistration` in `HoneyDrunk.AI`'s `models.json`. Hardcoded model identifiers in non-AI Nodes are forbidden; the router rejects an unregistered `ModelId`. See ADR-0041 D1, D4.
   - **73 — Every approved model has a passing capability canary in the last 24 hours.** A model whose `HoneyDrunk.AI.Tests.Canaries` capability canary fails past 24 hours is auto-flipped from `Approved` to `Preview` via `IApprovalStateWriter`. See ADR-0041 D3.
   - **74 — Every AI dispatch emits an Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`.** Routing decisions are forensically attributable; the audit entry is durable per ADR-0030 and is distinct from observability telemetry. See ADR-0041 D5, D10.
   - Add them under the existing `## AI Invariants` section (the file already has one — invariants 28, 29, 30, 44, 45, 46 live there), matching the file's current sectioning convention.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.
5. **Correct one stale sentence in ADR-0041's Context.** ADR-0041's Context (around lines 21-22) claims "the first scaffold packets (Architecture#72, #73, AI#2) are still open." That is stale — the ADR-0016 / HoneyDrunk.AI scaffold packets closed 2026-05-20 and `HoneyDrunk.AI` shipped v0.1.0. Edit that sentence to read that the AI-Node scaffold has landed (`HoneyDrunk.AI` is live at v0.1.0) so the Context no longer references closed work as open.

## Affected Files
- `adrs/ADR-0041-ai-model-registry-and-approval-workflow.md` (status flip + stale Context sentence correction)
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0041 header reads `**Status:** Accepted`
- [ ] The ADR-0041 row in `adrs/README.md` reflects Accepted
- [ ] ADR-0041's stale Context sentence (the "first scaffold packets ... are still open" line) is corrected to reflect that the AI-Node scaffold has landed and `HoneyDrunk.AI` is live at v0.1.0
- [ ] `constitution/invariants.md` carries the three new AI-registry invariants as invariants **72, 73, 74** (no dispatch against an unregistered model; every approved model has a passing 24h canary; every dispatch emits an Audit entry), under the `## AI Invariants` section, each citing ADR-0041
- [ ] `initiatives/active-initiatives.md` registers the `adr-0041-model-registry` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0041 D1 — Registry lives in `HoneyDrunk.AI`, declarative.** A `models.json` catalog loaded at startup, exposed via `IModelRegistry` in `HoneyDrunk.AI.Abstractions`. The registry is the single source of truth for model metadata; routers, policies, and canaries consume it.

**ADR-0041 D3 — Capability declarations asserted by canary.** Every registered model has a capability canary in `HoneyDrunk.AI.Tests.Canaries` asserting each declared capability against a cheap live call. Failure flips `ApprovalState`.

**ADR-0041 Consequences — Invariants.** ADR-0041 adds exactly three invariants: (1) no AI dispatch against an unregistered model; (2) every approved model has a passing capability canary in the last 24 hours; (3) every AI dispatch emits an Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`.

## Constraints
- **Acceptance precedes flip.** ADR-0041 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Use the pre-reserved invariant numbers 72, 73, 74.** The true current maximum in `constitution/invariants.md` is invariant 51. ADR-0041's reserved block is invariants **72, 73, 74** — invariant numbers 72-74 are pre-reserved as part of a 12-ADR batch. Do not renumber existing invariants; add the three new ones with these hard numbers. **If any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.**
- **Place under `## AI Invariants`.** The file already has an `## AI Invariants` section containing invariants 28, 29, 30, 44, 45, 46. The three new invariants are AI-sector — add them there rather than creating a new section.

## Labels
`chore`, `tier-3`, `ai`, `docs`, `adr-0041`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0041 to Accepted, add the three AI-registry invariants (72, 73, 74) to `constitution/invariants.md`, correct one stale Context sentence, and register the model-registry initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0041 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0041 AI Model Registry and Approval Workflow rollout, Wave 1.
- ADRs: ADR-0041 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0041 stays Proposed until this PR merges.
- Add the three new invariants as the pre-reserved numbers **72, 73, 74** under `## AI Invariants`; do not renumber existing invariants (the file's true current max is 51). Invariant numbers 72-74 are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.
- Correct the stale ADR-0041 Context sentence — the AI-Node scaffold has landed (`HoneyDrunk.AI` is live at v0.1.0), it is not "still open."

**Key Files:**
- `adrs/ADR-0041-ai-model-registry-and-approval-workflow.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
