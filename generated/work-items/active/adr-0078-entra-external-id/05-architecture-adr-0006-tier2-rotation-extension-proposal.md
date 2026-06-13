---
name: ADR Drafting
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "identity", "secrets", "adr-0078", "wave-3"]
dependencies: ["work-item:03"]
adrs: ["ADR-0078", "ADR-0006"]
wave: 3
initiative: adr-0078-entra-external-id
node: honeydrunk-vault-rotation
---

# Chore: Draft ADR-0006 Tier-2 rotation extension amendment for long-expiry Entra App Registration client secrets (follow-up placeholder)

## Summary

Draft an ADR-0006 amendment that formalizes a long-expiry exception path for Entra App Registration client secrets, so the temporary invariant-20 exception logged by packet 03 of this initiative becomes a documented standing posture rather than an indefinite undocumented one. The amendment either: (a) raises the Tier-2 SLA carve-out for IdP-tenant-bound client secrets (e.g., from 90 days to 365 or 730 days) with documented operational rationale, OR (b) commits to authoring an `IRotator` implementation for Entra App Registration secrets that automates the rotation on the existing 90-day cadence. The ADR records which path the user picks, the operational trade-offs, and the cost shape.

This is the **follow-up packet placeholder** the user named in the scoping refinement — "add follow-up packet placeholder for ADR-0006 Tier-2 rotation extension." The packet is queued in Wave 3 because it depends on packet 03's invariant-20 exception being a known live concern. The actual ADR draft is the work; this packet schedules it.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Per packet 03 of this initiative, Step 7 logs an active invariant-20 exception for the Entra App Registration client secret: Entra defaults to 24-month expiration, the Grid has no `IRotator` for Entra App Registration secrets, and the operational burden of 90-day manual portal rotation is non-trivial for a solo-dev shop. The exception is logged in Log Analytics (or `governance/exceptions/invariant-20-entra-app-secret.md`) but it is **not** documented as a standing exception in ADR-0006 itself; the exception record is an operational log entry, not a permanent constitutional carve-out.

Two paths resolve this:

- **(a) Raise the Tier-2 SLA for IdP-tenant-bound secrets.** Amend ADR-0006 to add an IdP-secret tier (e.g., Tier-2a) with a documented longer SLA (365 or 730 days). The amendment records the operational rationale (Microsoft enforces strong app-secret hygiene; secret values are never log-traced; the consumer-app surface is browser-based PKCE so the client secret is not in the primary OAuth flow; the secret is needed only for service-to-service Microsoft Graph calls per ADR-0060 D8) and the security trade-off (longer secret lifetime = larger blast radius if leaked; mitigated by Microsoft's portal-side secret rotation when forced and by manual rotation if a leak is suspected).

- **(b) Ship an `IRotator` for Entra App Registration secrets in `HoneyDrunk.Vault.Rotation`.** Per ADR-0006 D2, Tier-2 secrets rotate via a rotation Function (HoneyDrunk.Vault.Rotation). An `EntraAppRegistrationRotator` would call the Microsoft Graph API to add a new client secret to the App Registration, write the new value to `kv-hd-identity-{env}`, and (after a TTL grace period) delete the old secret. The 90-day cadence is preserved; the operational burden disappears.

Path (b) is the architecturally cleaner option but adds a moderate amount of Vault.Rotation work. Path (a) is the cheaper option but accepts a documented widening of the SLA. The ADR records the user's pick and the trade-off analysis.

This packet schedules the ADR drafting; the ADR itself is the work the user (or the `adr-composer` agent) authors when the packet executes.

## Proposed Implementation

### Step 1 — Open the next available ADR number

Read `adrs/` and pick the next available ADR number above the current high-water mark (which at file authoring is ADR-0080 — see `constitution/invariant-reservations.md` for the highest in-flight Proposed ADR). At the time this packet executes, the high-water mark may have moved; use the actual next-available number.

Create the new ADR file as `adrs/ADR-{NNNN}-tier-2-idp-secret-rotation-cadence.md` (substitute the actual number).

### Step 2 — Author the ADR

The ADR follows the existing ADR template (see e.g., `adrs/ADR-0078-end-user-identity-entra-external-id.md` for a recent example). Required sections:

- **Status:** Proposed
- **Date:** the date of authoring
- **Deciders:** HoneyDrunk Studios
- **Sector:** Core / Infrastructure (the secret-rotation policy is cross-cutting; pick the closer of Core or Infrastructure based on the user's preference at drafting time).

- **Context:** ADR-0006 commits Tier-2 secrets to ≤ 90-day rotation via the HoneyDrunk.Vault.Rotation Function. ADR-0078 commits Microsoft Entra External ID as the end-user IdP; Entra App Registration client secrets default to 24-month expiration. Packet 03 of `adr-0078-entra-external-id` logged an active invariant-20 exception covering the gap. This ADR resolves the gap by either widening the SLA for IdP-tenant-bound secrets or by committing to a rotation Function implementation.

- **Decision (D1):** The chosen path (a or b). Document the trade-offs of the other path.
  - If path (a): name the new tier (e.g., Tier-2a), commit the new SLA (365 or 730 days), document the operational rationale, document the security trade-off, document the mitigations.
  - If path (b): commit to an `EntraAppRegistrationRotator` in `HoneyDrunk.Vault.Rotation`, name the Microsoft Graph API calls it makes, name the App Configuration keys it reads, commit to the 90-day cadence, document the TTL grace period for old-secret deletion, document the operational rollout (Function App provisioning, OIDC federated credential setup, etc.).

- **Decision (D2+):** Any sub-decisions that fall out of D1.

- **Consequences:**
  - Invariant 20 — if path (a): the invariant text may be amended to reference the new Tier-2a; if path (b): the invariant text is unchanged because the 90-day cadence is preserved.
  - Operational consequences — what changes in the runbook, the on-call posture, the cost shape.
  - Affected Nodes — at minimum, HoneyDrunk.Vault.Rotation (if path b) or HoneyDrunk.Architecture (if path a, for the invariant text amendment).
  - Follow-up work — packet sequence for implementation if path (b); invariant-text amendment packet if path (a).

- **Alternatives Considered:**
  - The unchosen path (a or b).
  - **Defer indefinitely** — keep the invariant-20 exception record open. Rejected because it accumulates technical debt and the exception record's "Follow-up" field promises a resolution.
  - **Move to a different IdP** that supports auto-rotating client secrets natively. Rejected per ADR-0078 D7 — the wrapping seam supports migration but the migration cost is real; the rotation policy is the proportionate fix.

- **References:**
  - ADR-0006 (Secret Rotation and Lifecycle) — the parent ADR being amended.
  - ADR-0078 (End-User Identity — Microsoft Entra External ID) — the forcing function.
  - Packet 03 of `adr-0078-entra-external-id` — the live invariant-20 exception record.
  - `governance/exceptions/invariant-20-entra-app-secret.md` (if used) — the exception record itself.
  - Invariant 20 — the SLA being amended or preserved.

### Step 3 — Register the ADR

- Add the row to `adrs/README.md` (if the index has caught up to high-number rows by the time this packet executes; if not, no README update needed — the README has been lagging behind per the file-authoring observation).
- Add the ADR's invariant reservation (if any) to `constitution/invariant-reservations.md`. If path (a) amends invariant 20's text without adding a new invariant, no reservation is needed. If path (b) adds a new invariant codifying the `EntraAppRegistrationRotator` requirement, claim a size-1 block from the registry.
- Do NOT flip the ADR to Accepted. ADRs start at Proposed per the user's standing workflow (memory `feedback_adr_workflow`); acceptance happens via a subsequent acceptance packet authored by the scope agent.

### Step 4 — Close the invariant-20 exception loop

Once this ADR's acceptance packet (a future packet) merges, the invariant-20 exception record from packet 03 is closed (its "Follow-up" field references this ADR; the record is updated to "Resolved by ADR-{NNNN}").

This packet's scope ends at *drafting* the ADR. The acceptance + invariant-text amendment is a follow-up packet under the newly-drafted ADR's own acceptance initiative.

### `CHANGELOG.md` (Architecture repo)

Append to the current dated SemVer section:

> `Architecture: Draft ADR-{NNNN} (Tier-2 IdP secret rotation cadence) per the follow-up commitment in packet 05 of adr-0078-entra-external-id. Records the chosen resolution path (raise SLA for IdP-tenant-bound secrets OR commit to an EntraAppRegistrationRotator in HoneyDrunk.Vault.Rotation) for the active invariant-20 exception that packet 03 of adr-0078-entra-external-id logged. ADR Status is Proposed; acceptance is a follow-up packet under the new ADR's own acceptance initiative.`

## Affected Files

- `adrs/ADR-{NNNN}-tier-2-idp-secret-rotation-cadence.md` (new — the ADR draft)
- `adrs/README.md` (new index row IF the README has caught up to recent ADR numbers; otherwise skip)
- `constitution/invariant-reservations.md` (new reservation IF path (b) is chosen and a new invariant is added)
- `CHANGELOG.md` (entry under current dated SemVer section)

## NuGet Dependencies

None. Architecture is a knowledge repo.

## Boundary Check

- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No code changes; ADR drafting only.
- [x] No new constitutional invariants land in *this* packet — at most a reservation row in `invariant-reservations.md` is added if path (b) requires a new invariant.
- [x] The new ADR stays at Status: Proposed per memory `feedback_adr_workflow`. Acceptance is a separate downstream packet.
- [x] The packet does NOT execute either path (a) or path (b) — it drafts the decision document.

## Acceptance Criteria

- [ ] A new ADR exists at `adrs/ADR-{NNNN}-tier-2-idp-secret-rotation-cadence.md` with Status: Proposed.
- [ ] The ADR's Context section names packet 03 of `adr-0078-entra-external-id` as the forcing function and references the live invariant-20 exception record.
- [ ] The ADR's Decision section records the chosen path (a or b) and documents the trade-offs of the other.
- [ ] The ADR's Consequences section names the affected Nodes (HoneyDrunk.Vault.Rotation if path b; HoneyDrunk.Architecture if path a) and the operational consequences.
- [ ] The ADR's Alternatives Considered section explicitly names the unchosen path plus "defer indefinitely" and "move to a different IdP" with rejection rationale.
- [ ] If path (b) is chosen and adds a new invariant: `constitution/invariant-reservations.md` has a new reservation row claimed for the new ADR.
- [ ] If `adrs/README.md` has caught up to the recent ADR numbers (currently lagging behind): the new ADR row is added to the index.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section.
- [ ] The invariant-20 exception record from packet 03 of `adr-0078-entra-external-id` is updated to reference the new ADR in its "Follow-up" field.
- [ ] The new ADR stays at Status: Proposed. Acceptance is a separate packet authored later.

## Human Prerequisites

- [ ] **Packet 03 of this initiative must be Done before this packet executes.** Without packet 03 having logged the invariant-20 exception, this ADR has no concrete forcing function to reference. The user may push packet 03 and this packet in the same Wave if the Wave-3 dispatch happens after Wave-2 is fully closed.
- [ ] **The user must pick path (a) or path (b) before the ADR is drafted.** This is an architectural judgment call the user makes; the agent authoring the ADR does not pick the path autonomously. The packet's execution starts with a confirmation: "Which path? (a) raise the SLA for IdP-tenant-bound secrets, or (b) ship an EntraAppRegistrationRotator in HoneyDrunk.Vault.Rotation?"
- [ ] The user reviews and approves the draft before it merges (per the standard ADR workflow).

## Referenced Invariants

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 1 (Azure-native): ≤ 30 days. Tier 2 (third-party via rotation Function): ≤ 90 days. Certificates: auto-renewed 30 days before expiry. Exceptions must be logged in Log Analytics. — The invariant under consideration. The ADR drafted by this packet either amends the invariant text (path a) or preserves it while adding a new rotation Function implementation (path b).

> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. — This packet's scope is fixed at "draft the ADR"; any change to the path-a-vs-path-b decision happens via the ADR's own follow-up packets after acceptance, not via amending this packet.

## Referenced ADR Decisions

**ADR-0006 (Secret Rotation and Lifecycle):** The parent ADR being amended (path a) or extended by implementation (path b). ADR-0006 D2 commits Tier-2 secrets to ≤ 90-day rotation via the rotation Function.

**ADR-0078 D6 — Per-application configuration shape.** Per-app Entra App Registration client secrets live in `kv-hd-identity-{env}`; this ADR governs how often those secrets rotate.

**ADR-0078 D8 — Cost posture.** The Entra App Registration client secrets carry zero direct cost (free tier); the operational cost of rotation (manual portal vs. Function-automated) is the trade-off this ADR resolves.

## Constraints

- This packet is a **placeholder for follow-up work**. It does not author the ADR's content beyond outlining its required structure. The actual decision (path a or path b), the specific SLA numbers, the specific Microsoft Graph API calls (if path b) are filled in when the packet executes.
- The new ADR starts at Status: Proposed per the user's standing workflow (memory `feedback_adr_workflow`). Acceptance is a separate downstream packet, not this packet's scope.
- This packet does NOT execute either path. Path (b) — shipping the `EntraAppRegistrationRotator` — is a future Vault.Rotation feature packet under the new ADR's own initiative. Path (a) — amending invariant 20's text — is a future Architecture invariant-amendment packet under the new ADR's own initiative.
- The new ADR's number comes from "next available above the current high-water mark." Do NOT pre-claim ADR-0081 or any other specific number in this packet's body — the number is assigned at draft time based on what is live then.

## Labels

`chore`, `tier-3`, `core`, `docs`, `identity`, `secrets`, `adr-0078`, `wave-3`

## Agent Handoff

**Objective:** Draft an ADR amendment to ADR-0006 that resolves the live invariant-20 exception logged by packet 03 of `adr-0078-entra-external-id`. Pick path (a) raise the Tier-2 SLA for IdP-tenant-bound secrets, or path (b) commit to an `EntraAppRegistrationRotator` in `HoneyDrunk.Vault.Rotation`. Document the chosen path, the trade-offs of the unchosen path, and the operational consequences. ADR Status: Proposed.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Convert the temporary invariant-20 exception into a permanent documented posture (constitutional carve-out or automated rotation).
- Feature: ADR-0078 End-User Identity rollout, Wave 3, Packet 05 (the follow-up placeholder).
- ADRs: ADR-0006 (the parent rotation ADR), ADR-0078 (the forcing function).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 03 of this initiative.

**Constraints:**
- **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. — The invariant under amendment or preservation; do not pre-decide which until the user picks the path.
- **Invariant 24:** Work items are immutable once filed as a GitHub Issue. — This packet's scope is "draft the ADR"; any follow-on work is under the new ADR's own initiative, not via amending this packet.
- ADR starts at Status: Proposed per memory `feedback_adr_workflow`. Acceptance is a separate downstream packet.
- The path-a-vs-path-b decision is the user's architectural judgment call, not the agent's. The packet's execution starts with confirmation from the user.
- The new ADR's number is "next available above the current high-water mark," determined at draft time. Do not pre-claim a specific number.

**Key Files:**
- `adrs/ADR-{NNNN}-tier-2-idp-secret-rotation-cadence.md` — new (the ADR draft)
- `constitution/invariant-reservations.md` — new reservation row IF path (b) requires a new invariant
- `adrs/README.md` — new row IF the index has caught up
- `CHANGELOG.md` — append under current dated SemVer section
- `governance/exceptions/invariant-20-entra-app-secret.md` — update the "Follow-up" field to point to the new ADR (if the Markdown exception-record route was chosen in packet 03)

**Contracts:** None changed directly. Path (b), if chosen, would later add an `EntraAppRegistrationRotator` to `HoneyDrunk.Vault.Rotation` — that's a follow-up packet under the new ADR's initiative, not this packet's scope.
