---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0038", "wave-3"]
dependencies: ["packet:00", "packet:02"]
adrs: ["ADR-0038", "ADR-0027"]
accepts: ["ADR-0038"]
wave: 3
initiative: adr-0038-outbound-sender-identity-and-deliverability
node: honeydrunk-architecture
---

# Author the Notify Cloud onboarding deliverability documentation — 10DLC and DKIM delegation

## Summary
Author the Notify Cloud tenant-onboarding deliverability documentation per ADR-0038's Follow-up Work: the 10DLC SMS brand/campaign registration path (D4) and the two email tenant-identity options — platform send vs delegated DKIM (D5). The doc captures the onboarding gates Notify Cloud must enforce and the timelines tenants must be told about up front.

## Context
ADR-0038's Follow-up Work lists: "Author Notify Cloud onboarding documentation covering 10DLC and DKIM delegation." ADR-0038's Affected Nodes section: "HoneyDrunk.Notify.Cloud — gains tenant-onboarding gates for 10DLC registration and DKIM delegation; gains tier-tied throughput limits keyed off warmup state."

**`HoneyDrunk.Notify.Cloud` is not yet scaffolded.** ADR-0027 (its standup ADR) is itself Proposed and the repo does not exist — the same situation the ADR-0036 DR initiative flagged for Notify Cloud T0 DR. So the onboarding *feature code* (the gates, the tier-throughput limits) cannot be built here. What **can** and should be authored now is the **deliverability onboarding documentation** — the source-of-truth doc the future Notify Cloud onboarding flow and its standup packets will implement against. This is consistent with how ADR-0038 frames it ("onboarding documentation"), and with the developer's docs-for-solo-and-agents preference.

The doc covers:

**D4 — 10DLC for tenant SMS.** Notify Cloud tenants who want US SMS complete a 10DLC brand + campaign registration as part of onboarding. Without it, the tenant cannot send US SMS. The onboarding flow gates the SMS feature behind verified 10DLC registration. 10DLC registration is a 1–4 week clock per tenant brand — the doc states this expectation up front.

**D5 — Two email identity options.** Platform send (`notify-<tenant-id>@notify.honeydrunkstudios.com`, shared `notify.` reputation, rate-limited below the bad-actor blast-radius threshold) vs delegated DKIM (tenant's own `MAIL FROM`, tenant adds CNAME records pointing DKIM selectors at the Notify Cloud DKIM keys, tenant's own reputation). Above the rate-limit threshold, tenants must move to delegated DKIM. ESP subaccount-per-tenant is the reputation-isolation mechanism regardless.

This is a documentation packet. No code, no .NET project. It lands the onboarding deliverability doc in the Architecture repo so the Notify Cloud standup initiative has it as an input.

## Scope
- A new doc — `infrastructure/reference/notify-cloud-onboarding-deliverability.md` (or `repos/HoneyDrunk.Notify.Cloud/` if a context directory for the not-yet-scaffolded Node exists; check, and prefer `infrastructure/reference/` if it does not). The doc covers 10DLC onboarding and the D5 email identity options.

## Proposed Implementation
1. **Author the 10DLC onboarding section.** Cover:
   - The tenant-facing requirement: a 10DLC brand + campaign registration completed before the tenant can send US SMS through Notify Cloud.
   - The onboarding gate: the SMS feature is unavailable until 10DLC registration is verified.
   - The timeline expectation: 1–4 weeks per tenant brand — stated up front in onboarding so tenants plan for it.
   - Who does what: the tenant supplies brand/campaign details; the registration is submitted through the SMS provider (the provider picked in packet 02); the carrier/registry verifies.
   - International SMS is out of scope for v1 except as it falls out of the provider's default coverage (D4).
2. **Author the email tenant-identity-options section.** Cover:
   - **Platform send** — the simple default. `From:` is `notify-<tenant-id>@notify.honeydrunkstudios.com`; reply-to may be tenant-provided. Shared `notify.` reputation. Rate-limited below the bad-actor blast-radius threshold (the threshold is a Notify Cloud tier feature, not an ADR-fixed number — the doc says this).
   - **Delegated DKIM** — the tenant adds CNAME records pointing DKIM selectors at the Notify Cloud DKIM keys for their domain; `From:` is the tenant's domain; reputation is the tenant's own. Required for tenants with existing sender reputation to preserve, and for any tenant above the platform-send rate-limit threshold.
   - The tenant-facing DNS steps for delegated DKIM (the CNAME records they add) — at a level the onboarding flow can turn into instructions.
   - ESP subaccount-per-tenant is the reputation-isolation mechanism for both options.
3. **Author the warmup/throughput note.** Tenant throughput limits are keyed off warmup state (`sender_reputation_status`, packet 01) — a tier feature. The doc references the catalog field as the source of the warmup state the future tier-throughput logic reads.
4. **Mark the implementation as deferred.** The doc explicitly states the onboarding *gates* and *tier-throughput logic* are built in the Notify Cloud standup initiative (ADR-0027), not here — this packet authors the deliverability requirements the standup implements against.

## Affected Files
- `infrastructure/reference/notify-cloud-onboarding-deliverability.md` (new) — or under a `repos/HoneyDrunk.Notify.Cloud/` context directory if one exists.

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] Documentation lands in `HoneyDrunk.Architecture` — `HoneyDrunk.Notify.Cloud` is not scaffolded, so the doc lives in the Architecture repo as an input to the future standup initiative.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `infrastructure/reference/notify-cloud-onboarding-deliverability.md` (or the equivalent context-directory doc) exists
- [ ] The doc covers the 10DLC onboarding requirement, the SMS-feature gate, and the 1–4-week-per-brand timeline expectation
- [ ] The doc covers both email identity options — platform send (shared `notify.` reputation, rate-limited) and delegated DKIM (tenant domain, tenant reputation, CNAME steps)
- [ ] The doc states that above the platform-send rate-limit threshold tenants must move to delegated DKIM, and that the threshold is a tier feature, not an ADR-fixed number
- [ ] The doc references `sender_reputation_status` (packet 01) as the source of warmup state for tier-throughput logic
- [ ] The doc explicitly marks the onboarding gates and tier-throughput logic as deferred to the Notify Cloud standup initiative (ADR-0027)
- [ ] No secrets, API keys, or tenant data in the doc (invariant 8)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0038 D4 — SMS: 10DLC for US.** Notify Cloud tenant SMS is 10DLC registered per tenant brand. Tenants complete a 10DLC brand/campaign registration as part of onboarding to the SMS feature; without it, the tenant cannot send US SMS through Notify Cloud. The onboarding flow gates the feature behind verified registration. 10DLC registration is a 1–4 week clock per tenant brand — Notify Cloud onboarding documentation must set this expectation up front (ADR-0038 Operational Consequences).

**ADR-0038 D5 — Tenant identity options: platform send vs. delegated DKIM.** Platform send (`notify-<tenant-id>@notify.honeydrunkstudios.com`, shared `notify.` reputation, the simple default) vs delegated DKIM (tenant adds CNAME records pointing DKIM selectors at the Notify Cloud DKIM keys, tenant's own `MAIL FROM` and reputation). The shared-platform option is rate-limited below the bad-actor blast-radius threshold; above it, tenants must move to delegated DKIM. The threshold is a Notify Cloud tier feature, not an ADR-fixed number. ESP subaccount-per-tenant is the reputation-isolation mechanism regardless of identity option.

**ADR-0038 Follow-up Work.** "Author Notify Cloud onboarding documentation covering 10DLC and DKIM delegation."

**ADR-0027 — Notify Cloud standup (Proposed).** `HoneyDrunk.Notify.Cloud` is the multi-tenant commercial wrapper above Communications. Its repo is not yet scaffolded; its standup is a separate Proposed ADR. The onboarding feature code is built in that standup initiative.

## Constraints
- **Documentation, not feature code.** `HoneyDrunk.Notify.Cloud` does not exist as a repo. This packet authors the deliverability onboarding requirements; the gates and tier-throughput logic are the Notify Cloud standup's work. Mark this clearly so the gap is not silently assumed closed.
- **No secrets, no tenant data** (invariant 8).
- **Threshold numbers are tier features.** The rate-limit threshold and throughput tiers are deliberately not ADR-fixed — the doc describes the mechanism, not specific numbers.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0038`, `wave-3`

## Agent Handoff

**Objective:** Author the Notify Cloud onboarding deliverability documentation covering 10DLC SMS registration and the platform-send-vs-delegated-DKIM email identity options.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the deliverability onboarding requirements doc as an input to the future Notify Cloud standup initiative.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 3.
- ADRs: ADR-0038 D4 / D5 / Follow-up Work (primary), ADR-0027 (Notify Cloud standup — the initiative that builds the gates).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0038 should be Accepted first.
- `packet:02` — soft. The SMS provider pick (10DLC registration goes through the chosen provider) and the ESP pick (DKIM delegation) shape the doc's concrete steps.

**Constraints:**
- Documentation only — `HoneyDrunk.Notify.Cloud` is not scaffolded; the gates are the standup's work. Mark the deferral clearly.
- No secrets or tenant data (invariant 8).
- Threshold numbers are tier features, not ADR-fixed — describe the mechanism.

**Key Files:**
- `infrastructure/reference/notify-cloud-onboarding-deliverability.md` (new)

**Contracts:** None — documentation only.
