---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0050", "wave-1"]
dependencies: []
adrs: ["ADR-0050"]
accepts: ["ADR-0050"]
wave: 1
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-architecture
---

# Accept ADR-0050 — flip status, add the two tenant-lifecycle invariants, register the initiative

## Summary
Flip ADR-0050 (Tenant Lifecycle: Provisioning, Suspension, Offboarding, and Data Export) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the two new tenant-lifecycle invariants ADR-0050 commits in its Consequences/Invariants section to `constitution/invariants.md` (numbered **67, 68** — claimed from `constitution/invariant-reservations.md` at execution time), and register the `adr-0050-tenant-lifecycle` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0050 commits the Grid's tenant lifecycle: a seven-state enumeration (`Prospect`, `Trialing`, `Active`, `PastDue`, `Suspended`, `Offboarding`, `Closed`), a v1 self-serve-with-manual-approval provisioning model, idempotent provisioning steps spanning 5–9 Nodes, suspension semantics with 7-day payment grace and 30-day Suspended-window, the offboarding flow with a 30-day export window, the data export contract (ZIP + manifest + NDJSON + CSV + schema + README), and — most importantly — the **pseudonymization-based resolution to the collision between GDPR Article 17 (right to erasure) and Invariant 47 (audit is append-only)** (D6).

The ADR's central architectural commitment is D6: the audit substrate stores only `PseudoUserToken` / `PseudoTenantToken` opaque tokens; the PII↔token map lives in an erasable store (`HoneyDrunk.Auth.IdentityMap`); user-level erasure deletes the map row, leaving the pseudonymous tokens in audit permanently unresolvable. This satisfies GDPR Art. 17 via the EDPB-blessed pseudonymization-with-key-destruction pattern while preserving Invariant 47.

The ADR is **Proposed** with no scope. Subsequent packets in this initiative depend on its decisions as live rules — packet 02 builds the `PseudoUserToken` / `PseudoTenantToken` value types in Audit; packet 03 builds the `Tenants` state table and the `IdentityMap` in Auth; packet 05 scaffolds the provisioning workflow in Communications. The acceptance flip must land first.

ADR-0050 is **large** (6 phases, ~13 weeks per D11) and this initiative deliberately scopes only Phase 1 fully + the foundations for Phase 2 (Communications workflow scaffold) and Phase 4 (Data export pipeline). Phases 3, 5, and the Studios admin console (D9) are deferred follow-ups documented in the dispatch plan.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Invariant Numbering
ADR-0050 adds exactly **two** invariants. Their numbers are claimed at execution time from `constitution/invariant-reservations.md` per the reservation procedure:

1. **Read `constitution/invariant-reservations.md`.** Identify the file's current "high-water mark on disk" (the highest accepted invariant in `constitution/invariants.md`) and the highest existing reservation in the **Active Reservations** table.
2. **Claim the next free contiguous block of size 2** at `max(high-water, highest-active-reservation) + 1`. At authoring time of this packet the reservations file shows high-water = 53 with active reservations up through 66 (ADR-0051 54–57, ADR-0049 58–60, ADR-0054 61–63, ADR-0060 64–66), so the first-merge candidate values are **67 and 68** — but the executor MUST re-read the file at PR-open time and use whatever the actual next-free block is (first merge wins per the reservations file's collision-resolution procedure).
3. **Add a row to the Active Reservations table** in `constitution/invariant-reservations.md` in the same PR:
   - `Range`: `67-68`
   - `ADR`: `ADR-0050`
   - `Status`: `Proposed (this PR)`
   - `Notes`: `Multi-Tenant Lifecycle (audit pseudonymous-token boundary; seven-state machine). Packet 00 of adr-0050-tenant-lifecycle.`
4. **Append `67` and `68` to `constitution/invariants.md`** under a new `## Multi-Tenant Lifecycle Invariants` section placed after the existing `## Multi-Tenant Boundary Invariants` section. Each invariant cites ADR-0050 and references the reservation.
5. **If `git pull` shows a conflict** on `invariant-reservations.md` at PR-open or rebase time (another ADR's packet 00 raced and won first-merge), shift `67`/`68` upward to the new next-free block and update every reference to the numbers in this packet body and in `constitution/invariants.md` in the same rebase commit.

Do **not** assume any `## Multi-Tenant Lifecycle Invariants` section exists — create one. The file's existing sectioning convention groups invariants by topic (Dependency, Context, Secrets, Packaging, Testing, AI, Audit, Communications, Hive Sync, Hosting Platform, Multi-Tenant Boundary); tenant lifecycle is a distinct cross-cutting topic and warrants its own section.

## Scope
- `adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0050 row Status column to Accepted.
- `constitution/invariants.md` — add the two new tenant-lifecycle invariants (see Proposed Implementation for exact text), numbered `67, 68` under a new `## Multi-Tenant Lifecycle Invariants` section.
- `constitution/invariant-reservations.md` — add the Active Reservations row claiming `67-68` for ADR-0050 (per Invariant Numbering above). On merge, the row moves from Active Reservations to Reservation History with the merge date — this can be done as part of this PR's merge commit, or as a small follow-up housekeeping commit; either is acceptable per the reservations file's procedure.
- `initiatives/active-initiatives.md` — register the `adr-0050-tenant-lifecycle` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0050 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0050 index row in `adrs/README.md` to Accepted.
3. Claim `67` and `68` per the Invariant Numbering section above. Add the reservation row to `constitution/invariant-reservations.md` (Active Reservations table, then move to Reservation History in the same commit since this PR's merge consumes the reservation).
4. Add two new invariants to `constitution/invariants.md`, numbered `67` and `68` (the values claimed in step 3). The text, taken verbatim-in-substance from ADR-0050's Consequences "Invariants" subsection:
   - **67 — Audit substrate actor and subject fields accept only pseudonymous tokens.** Every actor reference written through `IAuditLog` is a `PseudoUserToken` (`pu_` + 32-char base32) or `PseudoTenantToken` (`pt_` + 32-char base32); raw email addresses, IP addresses, real names, phone numbers, and other PII patterns are rejected at the audit-writer boundary. Compile-time enforcement via value types where possible; runtime regex rejection at the boundary where not. The PII↔token map lives in `HoneyDrunk.Auth.IdentityMap`, which is erasable; destruction of the map row constitutes effective GDPR Art. 17 erasure of the corresponding pseudonymous data per EDPB Guidelines 01/2025 on pseudonymisation. This invariant **preserves and complements** invariant 47 (audit is append-only by interface) — the audit substrate never had the PII, so there is nothing to delete from it. See ADR-0050 D6.
   - **68 — Every tenant exists in exactly one of the seven enumerated states, with transitions audited and initiator-attributed.** The states are `Prospect`, `Trialing`, `Active`, `PastDue`, `Suspended`, `Offboarding`, `Closed`. State machine integrity is enforced as a compile-time enum (`TenantState`) plus a runtime transition guard that rejects undeclared transitions. Every transition emits an audit event recording the source state, target state, initiator (Customer / Ops / Webhook / Scheduled), and mechanism. See ADR-0050 D1.
   - Create a new `## Multi-Tenant Lifecycle Invariants` section after the existing `## Multi-Tenant Boundary Invariants` section. Append the two invariants under it.
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder (00 → 07).

## Affected Files
- `adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0050 header reads `**Status:** Accepted`
- [ ] The ADR-0050 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a row for ADR-0050 claiming `67-68` in the Active Reservations table at PR-open time (the numbers claimed per the file's procedure); on merge the row moves to Reservation History with the merge date
- [ ] `constitution/invariants.md` carries the two new tenant-lifecycle invariants — invariant `67` (audit substrate accepts only pseudonymous tokens; PII rejected at the boundary; complements invariant 47) and invariant `68` (seven-state tenant enumeration with audited initiator-attributed transitions) — under a new `## Multi-Tenant Lifecycle Invariants` section, each citing ADR-0050
- [ ] `initiatives/active-initiatives.md` registers the `adr-0050-tenant-lifecycle` initiative with a packet checklist (00 through 07) and the wave structure
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
- **`constitution/invariant-reservations.md` must exist on `main` before this packet executes.** That file is introduced by [PR #288](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/288); ADR-0050 already has a soft-claim row in it for invariants 67–68 (`67`–`68`). If #288 has not merged, hold this packet until it does.

## Referenced ADR Decisions
**ADR-0050 D1 — Seven-state tenant enumeration.** `Prospect`, `Trialing`, `Active`, `PastDue`, `Suspended`, `Offboarding`, `Closed`. Transitions are explicit, audited, and initiator-attributed. State is persisted canonically in `HoneyDrunk.Billing` (when standup completes) with a read-replica view in `HoneyDrunk.Auth`; until Billing scaffolds, state lives in a `Tenants` table in Auth as the interim home.

**ADR-0050 D6 — Pseudonymization at the audit boundary.** The audit substrate stores only `PseudoUserToken` (`pu_` + 32-char base32) and `PseudoTenantToken` (`pt_` + 32-char base32). PII patterns (email, IP, name, phone) are rejected at the audit-writer boundary. The PII↔token map lives in `HoneyDrunk.Auth.IdentityMap`, which is erasable. Destruction of the map row constitutes GDPR Art. 17 erasure per EDPB Guidelines 01/2025. Invariant 47 (audit append-only) is preserved — the audit substrate never had the PII to begin with.

**ADR-0050 Consequences — Invariants.** ADR-0050 adds exactly two invariants: (1) audit substrate actor/subject fields accept only pseudonymous tokens; (2) every tenant exists in exactly one of the seven enumerated states with audited initiator-attributed transitions.

**Invariant 47 (referenced, preserved) — Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry.** ADR-0050 D6's resolution preserves invariant 47 by routing PII through a separate erasable store; the audit substrate itself remains append-only.

## Constraints
- **Acceptance precedes flip.** ADR-0050 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers `67` / `68` claimed via `constitution/invariant-reservations.md`.** Append the two new invariants under a new `## Multi-Tenant Lifecycle Invariants` section after `## Multi-Tenant Boundary Invariants` using the contiguous block claimed in the reservations file (see Invariant Numbering above). Do not renumber existing invariants. First-merge-wins per the reservations file: if `git pull` flags a conflict on `invariant-reservations.md`, shift `67`/`68` upward to the new next-free block and update every reference in this packet + `constitution/invariants.md` in the same rebase commit.
- **Reference, do not restate, invariant 47.** Invariant `67` complements 47 (they are interlocking, not duplicative — 47 says "audit is durable and separate from telemetry"; `67` says "and the actor/subject fields are pseudonymous tokens, never raw PII"). The text of `67` explicitly cross-references 47.
- **The ADR's "ADR-0049" references are a citation error and are NOT corrected in this packet.** ADR-0050 text references "ADR-0049 (Tenant Data Isolation)" but the actual ADR-0049 is "Data Classification, PII Handling, and Retention Schedule." This is a discrepancy in ADR-0050 — do NOT amend the ADR's "ADR-0049" references in this packet; doing so risks introducing further drift before the actual Tenant-Data-Isolation ADR is authored. The discrepancy is documented in the dispatch plan as a deferred follow-up.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0050`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0050 to Accepted, add the two tenant-lifecycle invariants to `constitution/invariants.md`, and register the tenant-lifecycle initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0050 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 1.
- ADRs: ADR-0050 (primary), ADR-0008 (initiative/packet conventions), ADR-0030 (audit substrate, which D6 extends).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0050 stays Proposed until this PR merges.
- Claim `67` and `68` from `constitution/invariant-reservations.md` per its procedure (next contiguous block of size 2 above the high-water + active reservations); add the row to the reservations file and append the two invariants under a new `## Multi-Tenant Lifecycle Invariants` section after `## Multi-Tenant Boundary Invariants`. Do not renumber existing invariants. First-merge-wins: if `git pull` flags a conflict on the reservations file, shift `67`/`68` upward and update every reference in the same rebase.
- Invariant `67` references invariant 47 ("audit is append-only and separate from telemetry") as a complementary rule; it does not restate it.
- The ADR-0050 text contains citation errors ("ADR-0049 (Tenant Data Isolation)" — the actual ADR-0049 is a different ADR). Do NOT fix these in this packet; the discrepancy is tracked in the dispatch plan as a follow-up.

**Key Files:**
- `adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
