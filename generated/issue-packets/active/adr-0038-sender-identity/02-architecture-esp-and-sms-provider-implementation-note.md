---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "ops", "docs", "adr-0038", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0038"]
accepts: ["ADR-0038"]
wave: 1
initiative: adr-0038-sender-identity
node: honeydrunk-architecture
---

# Author the ESP and SMS provider implementation note — cut the primary/fallback pick from the D3 shortlist

# > [!IMPORTANT]
# > **Operator decision required.** ADR-0038 D3 deliberately defers the ESP vendor pick to "a follow-up implementation packet, not the ADR text" and names a shortlist (Resend / AWS SES / Postmark). This packet records the decision; it does not make it unilaterally. The agent drafts the note with the ADR's stated lean (Resend as primary candidate, Postmark as likely cold fallback) but the operator confirms or overrides before the note is finalized. The same applies to the SMS provider (Twilio named as the D4 default).

## Summary
Author an implementation note in the `infrastructure/` area recording the ESP primary/fallback pick and the SMS provider pick that ADR-0038 D3/D4 defer out of the ADR text. The note pins: which ESP is primary, which is the cold fallback, the SMS provider, and the rationale against ADR-0038 D3's three selection criteria (subaccount-per-tenant support, low-volume pricing, clean DKIM-delegation flow).

## Context
ADR-0038 D3 commits the Grid to the **shape** — one primary ESP, one cold fallback, both subaccount-per-tenant capable — and explicitly defers the vendor pick: "The pick is operational, not architectural; the ADR commits to the shape ... and defers the vendor pick to an implementation note." D3 names a shortlist:

- **Resend** — best modern DX, straightforward subaccount/tenant model; **primary candidate**.
- **AWS SES** — cheapest at scale, more deliverability-operations work.
- **Postmark** — best transactional reputation, weak subaccount model; **likely cold fallback**.

D4 names **Twilio** as the likely SMS-provider default, "subject to the same primary/fallback shape as email."

The pick is reversible: ADR-0038 D3 notes the Notify ESP slot is a single `IEmailDeliveryProvider` interface with vendor-specific backings, so a vendor switch costs one DKIM-key rotation. The note exists so the human-executed account-provisioning packet (09) and the Notify provider-backing packets (05–07) know which vendor they are configuring against.

This is a docs/decision packet. No code, no .NET project. The agent drafts; the operator confirms the vendor choices in the tracking issue before the note is considered final.

## Scope
- `infrastructure/reference/` — a new implementation note, e.g. `esp-and-sms-provider-selection.md`, recording the ESP primary/fallback and SMS provider picks with rationale.
- `infrastructure/reference/vendor-inventory.md` — add the chosen ESP and SMS provider rows (or update existing rows — `HoneyDrunk.Notify` already has a `Providers.Email.Resend` package, so Resend may already be present; reconcile).

## Proposed Implementation
1. **Draft the ESP selection note.** Default recommendation, per ADR-0038 D3's stated lean:
   - **Primary ESP: Resend.** Rationale: straightforward subaccount-per-tenant model (the D5 reputation-isolation mechanism), competitive low-volume pricing, clean DKIM-delegation flow, best modern DX. The Notify repo already ships a `HoneyDrunk.Notify.Providers.Email.Resend` package — the existing investment aligns.
   - **Cold fallback ESP: Postmark.** Rationale: best transactional reputation as a failover safety net; its weak subaccount model is acceptable for a cold-standby that is not the multi-tenant primary.
   - Record each pick against the D3 criteria: subaccount-per-tenant support, low-volume per-message pricing, DKIM-delegation cleanliness.
2. **Draft the SMS provider selection note.** Default recommendation: **Twilio** as primary, per ADR-0038 D4's named default — toll-free verification for Studio transactional, 10DLC brand/campaign registration for tenant SMS. Record whether a cold SMS fallback is wired at v1 or deferred (D4 says "subject to the same primary/fallback shape" — note the operator's call).
3. **Flag the operator decision.** The note's header states the picks are the ADR's lean and require operator confirmation. The operator records confirmation (or an override) in this packet's tracking issue.
4. **Update `vendor-inventory.md`** — add/reconcile the ESP and SMS provider rows with lock-in assessment (reversibility: one DKIM-key rotation per ADR-0038 D3).
5. Record the API-token / API-key storage convention at a pointer level only: per-Node Vault, per ADR-0005 secret-naming, resolved via `ISecretStore` (invariant 9). **No keys, account IDs, or secrets in the repo.** The actual key seeding happens in packet 09 and the Notify Cloud standup.

## Affected Files
- `infrastructure/reference/esp-and-sms-provider-selection.md` (new)
- `infrastructure/reference/vendor-inventory.md`

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] `infrastructure/reference/` lives in `HoneyDrunk.Architecture` — correct home for vendor-selection implementation notes (sibling to `vendor-inventory.md`).
- [x] No code change in any repo. The Notify provider-backing code is packets 05–07; this note only records which vendor those packets target.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `infrastructure/reference/esp-and-sms-provider-selection.md` exists and records the primary ESP, the cold-fallback ESP, and the SMS provider
- [ ] Each ESP pick is justified against ADR-0038 D3's three criteria (subaccount-per-tenant, low-volume pricing, DKIM-delegation flow)
- [ ] The SMS provider pick is recorded with the toll-free + 10DLC posture from D4
- [ ] The note's header flags that the picks are the ADR's lean and require operator confirmation; the operator's confirmation/override is recorded in the tracking issue
- [ ] `vendor-inventory.md` carries the ESP and SMS provider rows with a reversibility/lock-in note
- [ ] No API key, account ID, secret, or token appears anywhere in the repo (invariant 8)

## Human Prerequisites
- [ ] **Operator confirms or overrides the ESP primary/fallback pick** (default lean: Resend primary, Postmark cold fallback) before the note is finalized. Record the decision in the tracking issue.
- [ ] **Operator confirms or overrides the SMS provider pick** (default lean: Twilio) and decides whether a cold SMS fallback is wired at v1 or deferred.

## Referenced ADR Decisions
**ADR-0038 D3 — Email service provider: choose one default + one fallback.** One primary ESP for transactional and platform sends, one second ESP wired but cold for failover. Selection criteria: subaccount-per-tenant support (reputation isolation per D5), competitive low-volume per-message pricing, clean DKIM-delegation flow. Shortlist: Postmark (best transactional reputation, weak subaccount — likely cold fallback), AWS SES (cheapest at scale, more deliverability-ops work), Resend (best modern DX, straightforward subaccount model — primary candidate). The pick is operational, not architectural; the Notify ESP slot is a single `IEmailDeliveryProvider` interface, so the choice is reversible at the cost of one DKIM-key rotation.

**ADR-0038 D4 — SMS: 10DLC for US + a single toll-free number for Studio transactional.** Studio transactional SMS uses one toll-free number registered through the SMS provider (Twilio likely as a default, subject to the same primary/fallback shape as email). Notify Cloud tenant SMS is 10DLC-registered per tenant brand. Long codes are not used.

**ADR-0029 D2 / D5 — secret-token storage convention.** Vendor API tokens, when first issued, are stored in the consuming Node's per-Node Key Vault per ADR-0005 secret-naming and accessed via `ISecretStore`. No tokens are provisioned by a docs packet.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No ESP API key, SMS provider auth token, account SID, or webhook signing secret may be committed to the repo. The note records vendor names and the storage convention only.

- **Agent drafts, operator decides.** The agent writes the note with the ADR's stated lean but must not present the vendor pick as final without the operator's confirmation in the tracking issue.
- **Pointer-level secret convention only.** This note states *where* keys go (per-Node Vault, ADR-0005 naming); it does not contain keys and does not seed Vault. Seeding is packet 09 / the Notify Cloud standup.
- **Reconcile with the existing Resend package.** `HoneyDrunk.Notify` already ships `HoneyDrunk.Notify.Providers.Email.Resend` — the note and vendor inventory should acknowledge this rather than treat Resend as net-new.

## Labels
`chore`, `tier-2`, `ops`, `docs`, `adr-0038`, `wave-1`

## Agent Handoff

**Objective:** Author the ESP and SMS provider implementation note that ADR-0038 D3/D4 defer out of the ADR text; record the picks and rationale, flag for operator confirmation.

**Target:** `HoneyDrunk.Architecture` (`infrastructure/reference/`), branch from `main`.

**Context:**
- Goal: Pin which ESP and SMS provider the human-provisioning packet (09) and the Notify provider-backing packets (05–07) target.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 1.
- ADRs: ADR-0038 D3 / D4 (primary), ADR-0005 (secret-naming convention referenced at pointer level).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0038 should be Accepted before its D3 implementation-note follow-up is executed.

**Constraints:**
- Agent drafts with the ADR's lean (Resend primary, Postmark fallback, Twilio SMS); operator confirms in the tracking issue.
- No secrets in the repo (invariant 8) — vendor names and storage convention only.
- Reconcile with the existing `HoneyDrunk.Notify.Providers.Email.Resend` package.

**Key Files:**
- `infrastructure/reference/esp-and-sms-provider-selection.md` (new)
- `infrastructure/reference/vendor-inventory.md`

**Contracts:** None changed — documentation only.
