---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0038", "wave-1"]
dependencies: []
adrs: ["ADR-0038"]
accepts: ["ADR-0038"]
wave: 1
initiative: adr-0038-outbound-sender-identity-and-deliverability
node: honeydrunk-architecture
---

# Accept ADR-0038 — flip status, add the two deliverability invariants, register the initiative

## Summary
Flip ADR-0038 (Outbound Sender Identity and Deliverability) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the two new deliverability invariants ADR-0038 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0038-outbound-sender-identity-and-deliverability` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0038 sets the Grid-wide outbound sender-identity and deliverability policy: a sending-domain subdomain split for reputation isolation — `mail.honeydrunkstudios.com` for Studio transactional, `notify.honeydrunkstudios.com` for Notify Cloud platform sends, tenant-delegated DKIM for tenants bringing their own domain (D1); full SPF + DKIM + DMARC at staged-strict policy on every sending subdomain (D2); one primary ESP + one cold fallback, subaccount-per-tenant capable, vendor pick deferred to an implementation note (D3); 10DLC for US tenant SMS plus a single Studio toll-free number for transactional (D4); the two tenant identity options — platform send vs delegated DKIM (D5); bounce/complaint/unsubscribe handling as a Notify primitive via `IDeliverabilityFeedbackSink` (D6); a staged warmup posture (D7); a reporting and feedback-loop inbox (D8); PII-safe outbound headers (D9); and the explicit deferral of push/in-app/webhook channels (D10).

ADR-0038 is a **policy / decision** ADR. The concrete code — `IDeliverabilityFeedbackSink` and its default backing — is a small, real contract addition and lands in this initiative (packets 05–07). The DNS record publication, ESP/SMS provider account provisioning, and feedback-loop inbox setup are human/portal work and land as `Actor=Human` packets (03, 04, 09). The Notify Cloud onboarding documentation lands as packet 08.

Every other packet in this initiative references ADR-0038's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0038-outbound-sender-identity-and-deliverability.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0038 row Status column to Accepted.
- `constitution/invariants.md` — add the two new deliverability invariants ADR-0038 commits (see Proposed Implementation for exact text). Add them as invariants **65** and **66** — the pre-reserved block for ADR-0038 (see Constraints).
- `initiatives/active-initiatives.md` — register the `adr-0038-outbound-sender-identity-and-deliverability` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0038 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0038 index row in `adrs/README.md` to Accepted.
3. Add two new invariants to `constitution/invariants.md`, numbered **65** and **66**. The text, taken verbatim-in-substance from ADR-0038's "Invariants" Consequences subsection:
   - **65. Every sending subdomain has SPF + DKIM + DMARC in published state, with DMARC at minimum `p=quarantine`.** A subdomain without the full record set is forbidden from being a `MAIL FROM`. The DMARC steady-state target is `p=reject`; the staged path (`p=none` observation → `p=quarantine` → `p=reject`) is permitted, but no sending subdomain may operate below `p=quarantine` once it leaves the observation window. See ADR-0038 D2.
   - **66. Bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe.** Every bulk send and every Notify Cloud platform send carries the `List-Unsubscribe` and `List-Unsubscribe-Post` headers for one-click unsubscribe. Transactional sends emit the header as best practice (RFC-exempt but Notify still adds it). See ADR-0038 D6.
   - Add them under a new `## Deliverability Invariants` section, or the closest existing section, matching the file's current sectioning convention. Invariant numbers **65-66** are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0038-outbound-sender-identity-and-deliverability.md`
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
- [ ] ADR-0038 header reads `**Status:** Accepted`
- [ ] The ADR-0038 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the two new deliverability invariants (every sending subdomain has SPF + DKIM + DMARC with DMARC ≥ `p=quarantine`; bulk and platform sends emit RFC 8058 one-click List-Unsubscribe), numbered **65** and **66**, each citing ADR-0038
- [ ] `initiatives/active-initiatives.md` registers the `adr-0038-outbound-sender-identity-and-deliverability` initiative with a packet checklist
- [ ] No catalog schema change in this packet (the `sender_reputation_status` field is added in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0038 D2 — Email authentication: full SPF + DKIM + DMARC at strict policy.** Every sending subdomain gets the full record set. SPF declares the ESP's sending IPs (`~all` during warmup, `-all` once reputation is established). DKIM uses 2048-bit RSA keys, one per ESP-relationship, rotated annually per ADR-0006, selectors namespaced per ESP. DMARC is published on the apex covering subdomains: initial `p=quarantine` with `pct=100` after 14 days of `p=none` aggregate-report observation; steady state `p=reject`.

**ADR-0038 D6 — Bounce, complaint, and unsubscribe handling: a Notify primitive.** RFC 8058 one-click List-Unsubscribe is mandatory on bulk sends and on every Notify Cloud platform send. Transactional sends are RFC-exempt but Notify still emits the header for safety.

**ADR-0038 Consequences — Invariants.** ADR-0038 adds exactly two invariants: (1) every sending subdomain has the full SPF + DKIM + DMARC record set with DMARC at minimum `p=quarantine`; (2) bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe.

## Constraints
- **Acceptance precedes flip.** ADR-0038 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers are pre-reserved: 65 and 66.** The current highest invariant in `constitution/invariants.md` is 51 (verified — 1-51 all present). ADR-0038's reserved block is invariants **65** and **66**. Do not renumber existing invariants. Invariant numbers **65-66** are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0038`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0038 to Accepted, add the two deliverability invariants to `constitution/invariants.md`, and register the outbound-sender-identity initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0038 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 1.
- ADRs: ADR-0038 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0038 stays Proposed until this PR merges.
- Add the two new invariants as numbers **65** and **66** (current highest is 51; the 65-66 block is pre-reserved for ADR-0038's 12-ADR batch). Do not renumber existing invariants. If any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.

**Key Files:**
- `adrs/ADR-0038-outbound-sender-identity-and-deliverability.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
