---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "core", "identity", "constitution", "adr-0060"]
dependencies: ["work-item:01"]
adrs: ["ADR-0060"]
accepts: ADR-0060
wave: 1
initiative: adr-0060-identity-standup
node: honeydrunk-identity
---

# Chore: Add ADR-0060's three new invariants to the Grid constitution

## Summary

Add three new invariants to `constitution/invariants.md` derived from ADR-0060's Consequences section: D1 (Identity owns the user record and the `IdentityMap` — not Auth), D6 (internal-token issuance exclusivity), and D7 (contract-shape canary on the frozen Identity Abstractions surface). Claim the next free block from `constitution/invariant-reservations.md` (block size 3); ADR-0060's row in that file reserves the range. At scoping time (2026-05-24) the reservation framework's next-free is **64**, so the default assignments are **{N1}=64, {N2}=65, {N3}=66**. A reservation re-check at edit time confirms the actual numbers (reservation framework: first merge wins; if another ADR's packet 00 merged first and shifted the block upward, all three placeholders shift in lockstep).

This packet substitutes the assigned numbers into `repos/HoneyDrunk.Identity/invariants.md` (placeholder text left by packet 01) and into the source file for packet 04 (the scaffold) — pre-filing carve-out under invariant 24 applies because packet 04 has not been filed yet.

**Note on the dropped fourth invariant.** ADR-0060's Consequences originally proposed a fourth invariant for D13's downstream-Abstractions-only coupling rule. That pattern is already restated in invariants 40 (Communications), 44 (AI), 47 (Operator), and 48 (Audit); a per-Node restatement for Identity is not load-bearing. The rule applies via the general convention these existing invariants establish. ADR-0060's Consequences §Invariants subsection is finalized in this packet to reflect three numbered invariants, not four.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0060 explicitly delegates final invariant numbering to the scope agent at acceptance time. The three invariants the ADR commits to (in its Consequences `### Invariants` subsection, after the dropped D13 entry) need to land in `constitution/invariants.md` so the canary infrastructure, downstream consumer packets, and the review agent all have numbered, citable rules to reference:

- **D1 — user-record ownership.** Without an invariant, drift toward Auth-owns-user-records (the world before ADR-0060) is silent until someone tries to land a user CRUD endpoint inside Auth. The invariant locks the boundary the moment ADR-0060 is Accepted.
- **D6 — internal-token issuance exclusivity.** The affirmative version of Invariant 10: not only does Auth not issue, but Identity is the **only** Node that issues internal JWT bearer tokens. Any other Node minting JWTs for internal use is a boundary violation.
- **D7 — contract-shape canary.** Even with the canary wired in CI (handled by packet 04 of this initiative), the obligation to *keep* the canary running on the six interfaces + seven records of `HoneyDrunk.Identity.Abstractions` must outlive any single CI workflow file. The invariant ensures any future CI rewrite preserves the gate. Same pattern as Communications (invariant 43), AI (invariant 46), Audit (invariant 49), Operator (invariant 50).

**Dropped from the original four.** D13's downstream-Abstractions-only coupling rule was originally proposed as a fourth invariant. It is dropped because invariants 40 (Communications), 44 (AI), 47 (Operator), and 48 (Audit) already establish the pattern at the general level; per-Node restatement adds noise without changing enforcement. ADR-0060's Consequences §Invariants subsection is finalized to three numbered invariants in this packet.

## Reservation Lookup (Hard Gate, Run Before Any Edit)

Before authoring any of the edits below, read `constitution/invariant-reservations.md` and confirm the ADR-0060 reservation row's range. Per the reservation framework (first merge wins), the assigned numbers come from the row, not from a hardcoded value:

```bash
rg -n '^\| .* \| ADR-0060 \| ' constitution/invariant-reservations.md
```

The row's `Range` column gives the three assigned numbers in landing order: D1 → `{N1}`, D6 → `{N2}`, D7 → `{N3}`. Default at scoping time (2026-05-24): **{N1}=64, {N2}=65, {N3}=66** (next free above ADR-0054's 61–63 reservation). If between scoping and edit time another packet 00 merged that shifted ADR-0060's block, the row in `invariant-reservations.md` will already have been edited by that packet 00's author (per the file's "How a collision is resolved at merge time" section); take the numbers from the current row, not from this packet's default text.

**Cross-references to update with the assigned numbers (in lockstep, before commit):**

- `adrs/ADR-0060-stand-up-honeydrunk-identity-node.md` — Consequences `### Invariants` subsection. Drop the originally-proposed downstream-Abstractions-only-coupling bullet (D13). Replace the preamble line with the three assigned numbers.
- `repos/HoneyDrunk.Identity/invariants.md` (authored by packet 01 with `{N1}` / `{N2}` / `{N3}` placeholders) — substitute the three assigned numbers.
- `04-identity-node-scaffold.md` source file (this initiative's packet 04) — currently uses `{N1}` / `{N2}` / `{N3}` placeholders in acceptance criteria, constraints, and Referenced-Invariants sections. Substitute the assigned numbers in place pre-push under invariant 24's pre-filing carve-out. **Packets 02 and 04 cannot be filed in the same push** because packet 04's placeholders depend on packet 02's actual assignment.

## Proposed Implementation

### `constitution/invariants.md` — new `## Identity Invariants` section

Introduce a new section `## Identity Invariants` placed **immediately after the existing `## Audit Invariants` section** (which currently ends with invariant 49 on lines 190-191). This mirrors the pattern Audit established with its own dedicated section and keeps Identity's three invariants discoverable as a block.

Assigned numbers come from `constitution/invariant-reservations.md`'s ADR-0060 row — default `{N1}=64, {N2}=65, {N3}=66` (verify at edit time per the §Reservation Lookup above). Mark each new entry with `(Proposed — this invariant takes effect when ADR-0060 is accepted)` since ADR-0060 stays at `Status: Proposed` throughout this initiative.

The three entries (substitute `{N1}` / `{N2}` / `{N3}` with the assigned numbers):

```markdown
## Identity Invariants

{N1}. **User identity records, the `IdentityMap` (PII ↔ PseudoUserToken ↔ UserId ↔ ExternalSubject), and the user profile live in `HoneyDrunk.Identity`, not in `HoneyDrunk.Auth`.**
    Auth validates JWT Bearer tokens; Identity owns the user record. The `IdentityMap` is the single most PII-concentrated table in the Grid — per ADR-0049 it is Restricted / Sensitive PII; per ADR-0036 it is T0 backup tier. The map ownership relocates from the interim `HoneyDrunk.Auth.IdentityMap` (per ADR-0050 D6) to `HoneyDrunk.Identity.IdentityMap` per ADR-0060 D3 / the additive amendment to ADR-0050. Auth retains no user record state. See ADR-0060 D1 / D3 (Proposed — this invariant takes effect when ADR-0060 is accepted).

{N2}. **Internal-token issuance for service-to-service `UserPrincipal` flows is the exclusive responsibility of `HoneyDrunk.Identity.IInternalTokenIssuer`.**
    Any other Node minting JWT Bearer tokens for internal Grid use is a boundary violation. This is the affirmative version of Invariant 10 — Invariant 10 says Auth doesn't issue; this invariant says only Identity does. Tokens are short-lived (≤ 5 min) and signed with a key resolved through `ISecretStore` per Invariants 8 and 9; Auth validates the tokens through its existing `IJwtBearerValidator` JWKS-based path. Invariant 10 survives intact. See ADR-0060 D6 (Proposed — this invariant takes effect when ADR-0060 is accepted).

{N3}. **The HoneyDrunk.Identity Node CI must include a contract-shape canary for the full `HoneyDrunk.Identity.Abstractions` public surface.**
    Shape drift on `IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth`, or any of the supporting records (`UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`) is a build failure unless paired with an intentional version bump. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Identity.Abstractions`; the obligation is to keep the gate, not to use any specific implementation. See ADR-0060 D7 (Proposed — this invariant takes effect when ADR-0060 is accepted).
```

Notes for the executing agent:

- **Numbers come from `invariant-reservations.md`'s ADR-0060 row, not from hardcoded defaults.** The reservation framework (first merge wins) means if another packet 00 merged first and shifted ADR-0060's block upward, the row already reflects the new range — take the numbers from the row at edit time. Do NOT recalculate via a high-water-mark scan of `invariants.md`; reservations claim numbers above any landed invariants.
- **Preserve all existing invariants unchanged.** This packet only appends.
- **No `(Proposed)` qualifier needs to be removed later by a separate edit.** The qualifier in parentheses takes effect / lifts when ADR-0060 is flipped to Accepted by the scope agent at initiative completion. That housekeeping step does not require touching `constitution/invariants.md` — the qualifier just becomes informationally accurate at that point.

### `adrs/ADR-0060-stand-up-honeydrunk-identity-node.md` — finalize the invariant numbers in Consequences

In ADR-0060's Consequences section, the `### Invariants` subsection currently lists four "Invariant proposal:" bullets without numeric assignments. (1) Remove the bullet proposing the downstream-Abstractions-only-coupling invariant (D13) — its rule already exists generally via invariants 40 / 44 / 47 / 48 (see §Summary's "dropped fourth invariant" note). (2) Replace the existing preamble line (`This ADR proposes (not commits — invariant numbers and final wording assigned by the scope agent at acceptance):`) with:

> `Assigned invariant numbers (taken from constitution/invariant-reservations.md's ADR-0060 row; defaults assume the row's authored range of 64–66 has not shifted via the first-merge-wins rule):`
> `- **{N1}** (default 64) — Identity user-record ownership (D1 / D3)`
> `- **{N2}** (default 65) — Internal-token issuance exclusivity (D6)`
> `- **{N3}** (default 66) — Identity contract-shape canary (D7)`

Substitute `{N1}` / `{N2}` / `{N3}` with the actual numbers from the reservation row. The three remaining "Invariant proposal:" bullets stay otherwise unchanged — only the preamble sentence flips from tentative to assigned, and the D13 bullet is removed.

### `repos/HoneyDrunk.Identity/invariants.md` — substitute the placeholders

Packet 01 authored this file with `{N1}` / `{N2}` / `{N3}` placeholders in the trailing paragraph. Substitute the three assigned numbers:

- `{N1}` → (default 64) Identity user-record ownership
- `{N2}` → (default 65) Internal-token issuance exclusivity
- `{N3}` → (default 66) Identity contract-shape canary

### `04-identity-node-scaffold.md` source file — substitute the placeholders (pre-filing, invariant 24's carve-out)

This initiative's packet 04 source file (`04-identity-node-scaffold.md`, also in this folder) uses `{N1}` / `{N2}` / `{N3}` placeholders in its acceptance criteria, constraints, and Referenced-Invariants sections. Substitute the assigned numbers in place pre-push:

- `{N1}` → (default 64)
- `{N2}` → (default 65)
- `{N3}` → (default 66)

Run `rg -n '\{N[123]\}' generated/work-items/active/adr-0060-identity-standup/04-identity-node-scaffold.md` to confirm every placeholder is replaced before push. **Packets 02 and 04 cannot be filed in the same push** — the user must push packet 02 first, wait for the merge, observe the actual assigned numbers, then substitute and push packet 04.

### `CHANGELOG.md` (Architecture repo)

Append to the current dated SemVer section (substitute the actual assigned numbers): `Architecture: Add invariants 54 (Identity owns user records, IdentityMap, user profile — not Auth), 55 (Internal-token issuance is exclusively HoneyDrunk.Identity.IInternalTokenIssuer's responsibility — affirmative version of Invariant 10), 56 (Downstream Nodes take a runtime dependency only on HoneyDrunk.Identity.Abstractions), and 57 (HoneyDrunk.Identity CI must include a contract-shape canary for the full Abstractions surface) per ADR-0060 D1 / D6 / D7. New section ## Identity Invariants introduced. ADR-0060 Consequences §Invariants subsection finalized. repos/HoneyDrunk.Identity/invariants.md placeholders substituted. Packet 04 source file (the scaffold) edited in place pre-filing under invariant 24's carve-out to substitute the assigned numbers.`

## Affected Files

- `constitution/invariants.md` (append new `## Identity Invariants` section after `## Audit Invariants`)
- `adrs/ADR-0060-stand-up-honeydrunk-identity-node.md` (Consequences `### Invariants` subsection — finalize the numbers, replace the tentative-numbering preamble)
- `repos/HoneyDrunk.Identity/invariants.md` (substitute `{N1}` / `{N2}` / `{N3}` placeholders)
- `generated/work-items/active/adr-0060-identity-standup/04-identity-node-scaffold.md` (substitute `{N-ownership}` / `{N-issuance}` / `{N-canary}` placeholders — pre-filing amendment under invariant 24)
- `CHANGELOG.md` (entry under current dated SemVer section)

## NuGet Dependencies

None. Architecture is a knowledge repo.

## Boundary Check

- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No new design decision — invariant text is taken from ADR-0060 D1 / D6 / D7 with light wordsmithing for the constitution's voice.
- [x] No existing invariants modified, only appended.
- [x] Pre-filing amendment to packet 04 permitted under invariant 24's carve-out.
- [x] ADR-0060 Status stays Proposed. The Status flip is a separate post-merge housekeeping step.

## Acceptance Criteria

- [ ] **Collision check performed at edit time** using `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20`. The actual assigned numbers are recorded in the PR body and substituted into every cross-reference target. **Hardcoding 64/65/66 is wrong if the high-water mark has moved.**
- [ ] `constitution/invariants.md` has a new `## Identity Invariants` section placed immediately after `## Audit Invariants`.
- [ ] The three new invariants carry text matching ADR-0060 D1 / D6 / D7 with the `(Proposed — this invariant takes effect when ADR-0060 is accepted)` qualifier.
- [ ] Invariant 64's text states: user identity records, the `IdentityMap`, and the user profile live in `HoneyDrunk.Identity`, not in `HoneyDrunk.Auth`. References ADR-0050 D6's interim placement and the additive amendment.
- [ ] Invariant 65's text states: internal-token issuance for service-to-service `UserPrincipal` flows is exclusively `HoneyDrunk.Identity.IInternalTokenIssuer`'s responsibility. References Invariant 10's preservation.
- [ ] Invariant 66's text states: the HoneyDrunk.Identity Node CI must include a contract-shape canary for the full `HoneyDrunk.Identity.Abstractions` public surface. Names all six interfaces + all seven records.
- [ ] **All cross-reference targets updated in lockstep with the assigned numbers:** ADR-0060 Consequences, `repos/HoneyDrunk.Identity/invariants.md`, packet 04 source file (pre-filing under invariant 24's carve-out).
- [ ] `adrs/ADR-0060-stand-up-honeydrunk-identity-node.md` Consequences `### Invariants` subsection has its preamble sentence replaced with the assigned-number list. The remaining three "Invariant proposal:" bullets stay after dropping the D13 coupling-restatement proposal.
- [ ] `repos/HoneyDrunk.Identity/invariants.md` no longer contains the literal placeholder strings `{N1}`, `{N2}`, `{N3}`.
- [ ] `generated/work-items/active/adr-0060-identity-standup/04-identity-node-scaffold.md` no longer contains the literal placeholder strings `{N-ownership}`, `{N-issuance}`, `ADR-0060-D13`, `{N-canary}`.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section describing the invariant additions and the cross-reference substitutions (not under `## Unreleased`).
- [ ] PR body explicitly notes: (1) the three new invariants landed at their assigned numbers under `## Identity Invariants`; (2) ADR-0060 Consequences finalized; (3) `repos/HoneyDrunk.Identity/invariants.md` placeholders substituted; (4) packet 04 source file edited in place pre-filing to substitute the assigned numbers.

## Human Prerequisites

- [ ] Packet 01 of this initiative merged to `main` before this packet's PR is opened. Without that merge, this packet has no `repos/HoneyDrunk.Identity/invariants.md` to substitute placeholders into, and no `## Audit Invariants` predecessor section to anchor the new `## Identity Invariants` placement against.
- [ ] Confirm the assigned-number text in ADR-0060 Consequences matches the user's understanding of D1 / D6 / D7 — all three are mechanical text edits, but ADR Consequences edits warrant a quick eye before merge.

## Referenced Invariants

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Survives ADR-0060 intact. Invariant 65 (this packet) is the affirmative version: not only does Auth not issue, but Identity is the only Node that does. The two invariants together pin the validation-vs-issuance boundary unambiguously.

> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — Packet 04 of this initiative cites the three invariant numbers this packet assigns. Packet 04 must be amended in place pre-filing once this packet's PR merges and the actual assigned numbers are known. **Packets 02 and 04 cannot be filed in the same push.**

> **Invariant 47:** Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. — Identity is a first-class emitter alongside Auth; the new event types (`UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased`, `InternalTokenIssued` sampled) flow through `IAuditLog`. Invariant 64 (this packet) is upstream of Invariant 47 — Identity owns the writes that get audited.

> **Invariant 49:** The HoneyDrunk.Audit Node CI must include a contract-shape canary for the full `HoneyDrunk.Audit.Abstractions` public surface. — The precedent for invariant 66 (this packet). Same contract-shape canary applied to Identity.

## Referenced ADR Decisions

**ADR-0060 D1 (Identity Node ownership):** Identity is the Core sector's single Node owning the user record, the external-IdP seam, internal-token issuance, and account-deletion fan-out. Restated as constitutional invariant 64 by this packet.

**ADR-0060 D6 (Internal-token issuance — Identity issues, Auth validates):** Identity issues short-lived internal JWT bearer tokens. Auth validates these tokens through its existing JWKS path. Invariant 10 holds: Auth still only validates. Restated as constitutional invariant 65 by this packet.

**ADR-0060 D7 (Contract-shape canary):** A contract-shape canary is added to the Identity Node's CI; it fails the build if any of the six interfaces or six records change shape without a corresponding version bump. Restated as constitutional invariant 66 by this packet.

**ADR-0060 D13 (Downstream Abstractions-only coupling, captured in §If Accepted and §Invariants):** Downstream Nodes compile only against `HoneyDrunk.Identity.Abstractions`. This remains an ADR constraint backed by the existing Abstractions-only coupling convention; it is not a fourth ADR-0060 constitutional invariant.

## Dependencies

- `work-item:01` — Packet 01 of this initiative must merge so the `repos/HoneyDrunk.Identity/invariants.md` file exists with placeholders, and so the `## Audit Invariants` section's adjacency is settled (no concurrent constitution edits between this packet and packet 01).

## Labels

`chore`, `tier-2`, `architecture`, `core`, `identity`, `constitution`, `adr-0060`

## Agent Handoff

**Objective:** Add three new invariants - Identity user-record ownership (D1), internal-token issuance exclusivity (D6), and Identity contract-shape canary (D7) - to `constitution/invariants.md` under a new `## Identity Invariants` section at the next three free slots identified by collision check at edit time. Finalize the invariant numbers in ADR-0060's Consequences `### Invariants` subsection. Substitute the `{N1}` / `{N2}` / `{N3}` placeholders in `repos/HoneyDrunk.Identity/invariants.md`. Substitute the `{N-ownership}` / `{N-issuance}` / `{N-canary}` placeholders in `04-identity-node-scaffold.md`.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Land the three constitutional invariants ADR-0060 restates so packet 04 of this initiative (the HoneyDrunk.Identity scaffold) can cite them by number, and so the review agent has citable rules for canary-requirement, internal-token-issuance, and user-record-ownership enforcement.
- Feature: ADR-0060 standup initiative — this is packet 02 (constitution side).
- ADRs: ADR-0060 (this packet finalizes its three restated invariants).

**Acceptance Criteria:** As listed above.

**Dependencies:** `work-item:01` (catalog registration + context folder + ADR-0050/Auth amendments). Must be merged to `main` before this packet's PR is authored.

**Constraints:**

- **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Before a packet is filed, it may be amended to fill in missing operational context without violating this rule. — Packet 04 of this initiative cites the three invariant numbers assigned here. Packet 04 must be amended in place pre-filing once this packet's PR merges and the actual assigned numbers are known. **Packets 02 and 04 cannot be filed in the same push.**
- **The assignment is dynamic — do NOT hardcode 64/65/66.** Use the actual assigned numbers from the §Collision-Check Protocol. At scoping time the high-water mark is 53; if it moved, shift all three together.
- **Preserve all existing invariants unchanged.** This packet only appends a new section and the three entries within it.
- **No `(Proposed)` qualifier removal needed.** The qualifier in parentheses takes effect / lifts when ADR-0060 is flipped to Accepted; no separate edit needed to lift it.
- **Ordering of the three entries within the section is fixed:** D1 first, then D6, then D7. The numeric assignment maps in landing order: D1 first assigned slot, D6 second, D7 third.

**Key Files:**
- `constitution/invariants.md` — append new `## Identity Invariants` section with three entries after `## Audit Invariants`
- `adrs/ADR-0060-stand-up-honeydrunk-identity-node.md` — Consequences `### Invariants` subsection preamble sentence (replace tentative-numbering preamble with the assigned-number list)
- `repos/HoneyDrunk.Identity/invariants.md` — substitute `{N1}` / `{N2}` / `{N3}` placeholders
- `generated/work-items/active/adr-0060-identity-standup/04-identity-node-scaffold.md` — substitute `{N-ownership}` / `{N-issuance}` / `{N-canary}` placeholders (pre-filing carve-out under invariant 24)
- `CHANGELOG.md` — append entry under current dated SemVer section

**Contracts:** This packet does not author any new contracts. It records the three constitutional rules. Authoring the actual `.cs` files happens in packet 04 (the scaffold inside `HoneyDrunk.Identity`).
