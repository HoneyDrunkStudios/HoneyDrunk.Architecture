---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0073", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0073", "ADR-0027"]
wave: 3
initiative: adr-0073-notify-providers
node: honeydrunk-architecture
---

# Author the Notify Cloud per-tenant provider-override policy specification

## Summary
Author the canonical per-tenant provider-override policy specification at `business/context/notify-cloud-tenant-override-policy.md`. ADR-0073 D5 commits the seam ("per-tenant override is permitted; per-PDR override is permitted but discouraged"); the mechanics — credential-entry UI, validation flow, fallback semantics — are Notify Cloud-internal per ADR-0073 D6 ("tenant-BYO provider tooling"). This packet writes the specification document that the future Notify Cloud follow-up packet (filed against `HoneyDrunk.Notify.Cloud` after `adr-0027-notify-cloud-standup` packet 06 lands) implements. **No code ships in this packet.**

## Context
ADR-0073 D5 — Provider abstraction is held; defaults are not exclusive bindings:

> Per-tenant override is permitted. A Notify Cloud tenant with their own SES account, their own Postmark relationship, their own Twilio sub-account can plug into the `IEmailSender` / `ISmsSender` provider slot with a tenant-scoped implementation. The default (Resend / Twilio / Expo) is what Notify uses for tenants who do not override.

ADR-0073 D6 — Out of scope:

> Tenant-BYO provider tooling. The mechanism by which a Notify Cloud tenant brings their own provider (UI for credential entry, validation flow, fallback semantics) is a Notify Cloud-internal concern.

The decision is recorded; the mechanics are not. Without a specification document, the Notify Cloud follow-up packet has no design to consume. This packet authors that specification in the Architecture repo so the follow-up filer (in the future `adr-0027-notify-cloud-standup` initiative or a sibling initiative) has the canonical input.

**Notify Cloud's repo does not yet exist on disk.** ADR-0027 is Proposed; the `HoneyDrunk.Notify.Cloud` repo creation is gated on ADR-0027's standup packets. Per the user's standing convention ("file-work-items can't file against repos that don't exist"), the production implementation packet for the tenant-override flow lives in the Notify Cloud standup initiative — not here. This packet's job is to be the design input that initiative consumes.

This packet's location pin is **deliberate**: `business/context/notify-cloud-tenant-override-policy.md` — `business/` is the directory that holds product/business-policy documents that consuming initiatives (Notify Cloud, identity, billing) reference at draft time. Confirm the directory exists or create it; the parallel sibling `business/context/notify-cloud-rate-limit-policy.md` from the `adr-0067-rate-limiting` initiative establishes the convention (or, if that initiative chose `infrastructure/walkthroughs/` as its location, mirror that choice — confirm at execution).

## Scope
- New file: `business/context/notify-cloud-tenant-override-policy.md` (or the directory matching the `adr-0067-rate-limiting` initiative's choice — confirm at execution).

## Out of Scope
- The Notify Cloud implementation packet — filed against `HoneyDrunk.Notify.Cloud` after the standup packets land.
- The Notify-side provider abstraction work — the abstraction already exists in `HoneyDrunk.Notify.Abstractions` (`INotificationSender` keyed by `NotificationChannel`). This packet does not propose changes to the abstraction.
- Stripe / billing integration for BYO-provider tenants (the tenant pays nothing extra for using their own provider; this is not a billing concern).
- The actual provider-credential storage in `kv-hd-notify-cloud-{env}` or a tenant-scoped vault namespace — see ADR-0026 for the tenant-scoped secret pattern. This packet documents the choice but the implementation is the follow-up's job.

## Proposed Implementation
1. Confirm whether the sibling override-policy doc from `adr-0067-rate-limiting` landed at `business/context/` or `infrastructure/walkthroughs/`. Mirror the choice.
2. Create the file at the confirmed location with the following sections:

   ```markdown
   # Notify Cloud Per-Tenant Provider Override Policy

   **Source ADR:** [ADR-0073](../../adrs/ADR-0073-notify-default-providers.md) D5 + D6
   **Target Node:** `HoneyDrunk.Notify.Cloud` (Proposed via [ADR-0027](../../adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md))
   **Status:** Specification — implementation packet filed under Notify Cloud standup after `adr-0027-notify-cloud-standup` packet 06 lands.
   **Authored:** 2026-05-25

   ## Why this exists

   ADR-0073 D5 commits the seam: a Notify Cloud tenant may bring their own email / SMS / push provider credentials and route their tenant's sends through their own SES, Postmark, Twilio sub-account, Expo project, etc. The default (Resend / Twilio / Expo) is what Notify uses for tenants who do not override.

   ADR-0073 D6 explicitly names tenant-BYO tooling as Notify Cloud-internal. This document specifies what Notify Cloud builds.

   ## Tenant override scope

   A tenant override consists of three independent decisions, one per channel:

   - **Email provider override.** Tenant supplies credentials for an alternate `IEmailSender`-compatible provider (SES, Postmark, Mailgun, SendGrid, their own Resend account, etc.). When set, all tenant emails route through the override; the platform Resend account is bypassed.
   - **SMS provider override.** Tenant supplies credentials for an alternate `ISmsSender`-compatible provider (their own Twilio sub-account, MessageBird, Plivo, etc.). When set, all tenant SMS routes through the override; the platform Twilio account is bypassed.
   - **Push provider override.** Tenant supplies credentials for an alternate `IPushSender`-compatible provider (their own Expo project, OneSignal, direct APNs+FCM). Override is per-platform if needed (iOS-only override is acceptable; the unprovided channel falls back to platform).

   Each channel is independent — a tenant can override Email only, leave SMS on platform Twilio, and have no push needs at all.

   ## Credential storage

   Tenant-scoped credentials follow the [ADR-0026 D5 tenant-scoped secret pattern](../../adrs/ADR-0026-grid-multi-tenant-primitives.md) (invariant 9a): the secret name format is `tenant-{tenantId}-{secretName}` resolved via `TenantScopedSecretResolver`. Examples for a tenant whose `TenantId` ULID resolves to `01J0...`:

   - `tenant-01J0-Resend--ApiKey` (if the tenant overrode to a different Resend account)
   - `tenant-01J0-Postmark--ServerToken` (if the tenant overrode to Postmark)
   - `tenant-01J0-Twilio--AuthToken` (if the tenant overrode their Twilio sub-account)
   - `tenant-01J0-Expo--AccessToken` (if the tenant overrode their Expo project)

   The credential **values** live in the same `kv-hd-notify-cloud-{env}` namespace as the platform credentials. Tenant credentials are never co-located with another tenant's; the secret name's tenant prefix is the isolation seam. Invariant 9a applies — `TenantId.Internal` continues to resolve the un-prefixed platform names.

   ## Per-tenant override resolution

   When dispatching a tenant send, Notify Cloud's runtime composes the provider resolution as follows:

   1. **Identify the tenant** from the inbound send context (typically via `IGridContext.TenantId`).
   2. **Look up the tenant's override configuration** (a small per-tenant record stored in Notify Cloud's tenant table). The record names which channels are overridden and which alternate provider the override binds.
   3. **For overridden channels**: resolve credentials via `TenantScopedSecretResolver` using the tenant-prefixed secret name; instantiate the alternate provider's `INotificationSender` implementation; dispatch through it.
   4. **For non-overridden channels**: dispatch through the platform default (Resend / Twilio / Expo).
   5. **For overridden channels whose credentials are missing or invalid**: see "Fallback semantics" below.

   The composition happens at dispatch time, not at host registration. The platform default registrations remain in DI (Resend at `NotificationChannel.Email`, Twilio at `NotificationChannel.Sms`, Expo at `NotificationChannel.Push`); the override dispatch replaces the resolved sender per-call when a tenant override applies. The `NotificationSenderResolver` already exists; the override resolution is a pre-dispatch wrapper around it.

   ## Validation flow (BYO-provider onboarding)

   When a Notify Cloud tenant enters override credentials in the Notify Cloud admin UI:

   1. **Schema-validate the credentials** for the named provider (e.g. Resend API keys start with `re_`; Postmark server tokens are UUIDs; Twilio Account SIDs start with `AC`).
   2. **Live-test the credentials** with a low-risk provider-side call (Resend: GET `/domains`; Postmark: GET `/server`; Twilio: GET account resource; Expo: GET `/push/getReceipts` with empty body) that round-trips a 200 / 401 / 403 with the credentials.
   3. **Store the credentials in Vault** under the tenant-prefixed name. Audit the credential set per [ADR-0030](../../adrs/ADR-0030-grid-wide-audit-substrate.md) — the audit entry records the tenant ID, the channel, the provider name, and the timestamp. Credential **values** are never audited (invariant 8).
   4. **Confirm to the tenant** that override is active. The tenant's first send post-confirmation routes through the override.

   Validation is the gate — if the live-test fails, the credentials are not stored and the tenant sees the failure with an actionable error.

   ## Fallback semantics

   At dispatch time, an override may fail for runtime reasons (rotated credential that the tenant did not re-enter; provider outage; account suspension). Two fallback choices:

   - **Fail the send** (strict). The tenant override is the chosen behaviour and a fallback to platform Resend would deliver email under the platform's From-address — a deliverability and brand risk for the tenant. The strict choice respects the override's intent.
   - **Fall back to platform** (lax). The send goes out via platform Resend; the tenant is alerted via Notify Cloud's tenant notification channel. The lax choice prioritizes delivery over override fidelity.

   **Decision: strict by default.** A tenant who has chosen an override has done so deliberately. Falling back silently to platform is a surprise; the platform-vs-tenant From-address risk is real. The tenant override fails the send with a clear error; the tenant's admin is notified; the next send retries. The lax option is offered as a per-tenant opt-in setting ("fall back to platform if my provider fails — accept that my emails may show the HoneyDrunk From-address temporarily") but defaults off.

   The send-failure audit entry (per ADR-0030) records the override failure with the rotated/missing credential reason — the audit value never includes the credential value itself.

   ## Per-PDR override (out of scope for Notify Cloud)

   ADR-0073 D5 also permits per-PDR override (a consuming Node — Hearth, Currents, etc. — may register an alternate provider at its host composition). This is **not** a Notify Cloud concern; it is a per-PDR composition choice made in the consumer's `AddHoneyDrunk*Provider()` host registration. Notify Cloud's per-tenant override is independent and operates only against tenants of the Notify Cloud Service.

   ## Open questions for the implementation packet

   - **UI surface.** The Notify Cloud admin UI is per ADR-0027's standup; UI mockups, validation-error UX, and credential-rotation reminders are the implementation packet's design work.
   - **Audit detail.** ADR-0030's `AuditEntry` shape carries the override decision; the implementation packet decides whether per-send override-resolution events emit an audit entry or only the credential-management events do (per-send may be too noisy at scale).
   - **Tenant tier-gating.** ADR-0027 introduces tiers (Free / Pro / Scale per ADR-0037 reconciled in ADR-0067). Is BYO-provider available on all tiers, or gated to Pro+? Implementation packet decides; default recommendation is "Pro+ only" — BYO-provider is a power-user feature whose support cost is non-trivial.
   - **Credential-rotation reminder cadence.** A tenant who entered credentials 80 days ago is approaching the typical 90-day rotation window. Notify Cloud should remind them. The cadence and channel (in-app banner? email reminder?) is the implementation packet's design.

   ## Follow-up Notify Cloud packet outline

   The packet that consumes this specification:

   - **Target repo:** `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud`
   - **Expected wave:** post-standup (Wave 3 or 4 of the `adr-0027-notify-cloud-standup` initiative)
   - **Blocked by:** `adr-0027-notify-cloud-standup` packet 06 (scaffold)
   - **Version-bump impact:** Notify Cloud minor (new tenant-facing feature)
   - **Scope:** tenant-override configuration record + admin UI + credential validation flow + dispatch-time override resolver + audit hooks + strict fallback policy + Pro+ tier-gating
   - **References:** this specification document, ADR-0073 D5/D6, ADR-0026 D5 (tenant-scoped secrets), ADR-0030 (audit emit), ADR-0027 (Notify Cloud tier shape), ADR-0067 D3 (tier-name reconciliation), invariant 9a (tenant-scoped secrets pattern), invariant 8 (no secret values in logs/traces).

   ## Related work

   - [ADR-0073](../../adrs/ADR-0073-notify-default-providers.md) — the default-provider commitment that this override mechanism is the escape valve for.
   - [ADR-0027](../../adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — Notify Cloud standup (Proposed; the implementing Node).
   - [ADR-0026](../../adrs/ADR-0026-grid-multi-tenant-primitives.md) — tenant-scoped secret pattern (invariant 9a).
   - [ADR-0030](../../adrs/ADR-0030-grid-wide-audit-substrate.md) — audit emit for override credential management.
   - [ADR-0019](../../adrs/ADR-0019-stand-up-honeydrunk-communications-node.md) — Notify is delivery mechanics; the per-tenant override is delivery-side, not Communications decision-side.
   ```

3. Save.

## Affected Files
- `business/context/notify-cloud-tenant-override-policy.md` (new file; confirm directory choice against sibling `adr-0067-rate-limiting` packet 05 at execution)

## NuGet Dependencies
None. This packet touches only Markdown specification files.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule matches.
- [x] No code change in any repo.
- [x] The specification respects Notify's boundary (delivery mechanics) and Communications' boundary (decision/preference) — the override decision is a tenant-configuration choice made at the Notify Cloud admin layer, not a per-send decision-logic choice; it operates inside the Notify-delivery boundary.

## Acceptance Criteria
- [ ] The specification document exists at `business/context/notify-cloud-tenant-override-policy.md` (or the mirror location matching `adr-0067-rate-limiting` packet 05 — state the chosen path in the PR if different)
- [ ] The document covers: tenant override scope (3 channels independent); credential storage (ADR-0026 D5 tenant-scoped secret pattern); per-tenant override resolution (dispatch-time wrapping the existing `NotificationSenderResolver`); validation flow (schema + live-test + Vault store + audit); fallback semantics (strict by default, lax as per-tenant opt-in); per-PDR override out of scope for Notify Cloud; open questions for the implementation packet; follow-up Notify Cloud packet outline
- [ ] The document explicitly cites invariants 8 (no secrets in audit) and 9a (tenant-scoped secret pattern)
- [ ] The document explicitly states the strict-fallback decision with the rationale (override's intent + From-address brand risk)
- [ ] The document explicitly defers the open questions (UI, audit detail, tier-gating, rotation-reminder cadence) to the implementation packet — none of them are resolved here
- [ ] **No code work.** No edits to `HoneyDrunk.Notify`, `HoneyDrunk.Vault`, `HoneyDrunk.Vault.Rotation`, or any other code repo.
- [ ] **No edit to ADR-0073's text** or any other ADR.
- [ ] **No catalog change.** No edits to any `catalogs/` file.

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0073 D5 — Provider abstraction is held; defaults are not exclusive bindings.** "Per-tenant override is permitted. A Notify Cloud tenant with their own SES account, their own Postmark relationship, their own Twilio sub-account can plug into the `IEmailSender` / `ISmsSender` provider slot with a tenant-scoped implementation. The default (Resend / Twilio / Expo) is what Notify uses for tenants who do not override. Per-PDR override is permitted (but discouraged)."

**ADR-0073 D6 — Out of scope.** "Tenant-BYO provider tooling. The mechanism by which a Notify Cloud tenant brings their own provider (UI for credential entry, validation flow, fallback semantics) is a Notify Cloud-internal concern."

**ADR-0026 D5 — Tenant-scoped secrets are a Vault usage pattern, not an `ISecretStore` contract change** (invariant 9a). "Tenant-owned secrets use `tenant-{tenantId}-{secretName}` and resolve through `TenantScopedSecretResolver`; `TenantId.Internal` uses the standard node-level secret path."

**ADR-0030 §IAuditLog emit obligations.** Override credential-management events (entered, validated, rotated, removed) emit `AuditEntry` records via `IAuditLog`. The audit entry records the tenant ID, the channel, the provider name, and the timestamp. Credential **values** never appear in audit (invariant 8).

**ADR-0027 §Tenant tier shape** + **ADR-0067 D3 tier-name reconciliation.** Notify Cloud tiers at GA: Free / Pro / Scale (reconciled from ADR-0027's original Free / Starter / Pro to ADR-0037's Free / Pro / Scale). BYO-provider is a candidate Pro+ gate per the implementation packet.

## Constraints
- **Docs-only, no code.** This packet writes the specification; the implementation packet is filed against Notify Cloud after the standup lands.
- **No abstraction change to `HoneyDrunk.Notify`.** The existing `INotificationSender` / `NotificationSenderResolver` already supports per-call provider substitution via keyed DI. The override is a dispatch-time wrapper, not a contract change.
- **Strict-fallback default is committed.** This document's "strict by default, lax as opt-in" decision binds the implementation packet. Reopening this decision is an amendment to this document, not a silent implementation drift.
- **Per-PDR override stays out of Notify Cloud's scope.** A consumer-PDR's host-composition override is independent and not Notify Cloud's concern.
- **Open questions are deferred deliberately.** UI design, audit detail, tier-gating, rotation reminders — those are the implementation packet's design space. Resolving them in this specification would couple to a particular UI framework / audit-emit cadence / tier-naming that the standup ADR has not yet committed.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0073`, `wave-3`

## Agent Handoff

**Objective:** Author the canonical per-tenant provider-override policy specification at `business/context/notify-cloud-tenant-override-policy.md` as the design input the future Notify Cloud implementation packet consumes. No code ships.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Spec the per-tenant override mechanics so the Notify Cloud follow-up packet (filed against `HoneyDrunk.Notify.Cloud` after its standup lands) has a complete design.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 3.
- ADRs: ADR-0073 D5 / D6 (primary); ADR-0027 (Notify Cloud — Proposed, implementing Node); ADR-0026 (tenant-scoped secret pattern); ADR-0030 (audit emit for credential management).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0073 is Accepted.

**Constraints:**
- Docs-only.
- Strict-fallback default is committed in the spec; lax is opt-in per-tenant.
- Open questions (UI, audit detail, tier-gating, rotation cadence) are deferred to the implementation packet — not resolved here.
- Confirm the directory choice (`business/context/` vs `infrastructure/walkthroughs/`) against the sibling `adr-0067-rate-limiting` packet 05 at execution time; mirror the choice.

**Key Files:**
- `business/context/notify-cloud-tenant-override-policy.md` (new file)

**Contracts:** None.
