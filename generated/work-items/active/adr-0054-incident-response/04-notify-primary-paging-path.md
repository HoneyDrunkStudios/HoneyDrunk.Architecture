---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-2", "ops", "adr-0054", "wave-2"]
dependencies: ["work-item:00", "work-item:03"]
adrs: ["ADR-0054", "ADR-0019"]
accepts: ["ADR-0054"]
wave: 2
initiative: adr-0054-incident-response
node: honeydrunk-communications
---

# Implement the primary paging path: Communications-owned intent, Notify delivery (companion-app push or v0 SMS fallback)

## Summary
Implement the primary paging path per ADR-0054 D3 with **paging intent owned by `HoneyDrunk.Communications`** (per invariant 41 — "Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify") and **delivery owned by `HoneyDrunk.Notify`** (the channel-agnostic delivery surface). A new `IIncidentPagingIntent` lives in `HoneyDrunk.Communications.Abstractions`; the Communications handler decides (severity, fingerprint dedup, operator-availability gating, the `Diagnostic` flag) and then composes the delivery payload that flows through Notify's existing `INotificationSender` to the operator's phone via push notification (the Studios-internal companion app) with **v0 SMS via the existing Twilio provider as the fallback** when the companion app is not yet built. Each paged alert includes a deep-link to the corresponding PagerDuty incident (per D3 — "PagerDuty is the source of truth for acknowledgment").

## Context
ADR-0054 D3 specifies two redundant paging paths. The secondary path is PagerDuty (packet 03). The **primary** path is split per the ADR-0019 / invariant-41 boundary:

- **Decision / intent layer** — `HoneyDrunk.Communications`. The Communications Node owns the *decision* to page (severity, fingerprint dedup, operator-availability gating, the `Diagnostic` flag distinguishing synthetic-probe pages from real pages, the audit-of-the-page-itself emission). Per invariant 41 ("Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify"), paging *intent* is a Communications concern.
- **Delivery layer** — `HoneyDrunk.Notify`. Notify owns the *delivery mechanics*: SMS via Twilio (v0); push via the Studios-internal companion app (v1). Notify already ships the `INotificationSender` channel-agnostic dispatch contract; this packet uses it as the existing delivery handoff — **no new `IIncidentPagingSender` on the Notify side**.

ADR-0054 D3 names the primary path's delivery target as "the operator's personal phone via push notification (initially APNs/FCM through a small Studios-internal companion app, or via SMS if the companion app is not yet built)." Latency target: **< 30 seconds from alert fire to phone receipt** under healthy Grid conditions.

The companion app is **future work**. ADR-0054's Operational Consequences: "The companion-app push integration (D3 primary path) is initial work. v0 may use SMS via Notify if the companion app isn't ready; the trade-off is slightly higher delivery latency for v0." This packet ships **v0 with SMS** as the delivery channel; the companion-app push integration is a follow-on that does not block this packet's acceptance criteria. v0 SMS uses Notify's existing Twilio provider via `INotificationSender`.

**Communications is the target Node for this packet** because the new contract — `IIncidentPagingIntent` — and the handler that owns severity / dedup / availability / `Diagnostic` decisioning live there. Notify is unchanged at the contract surface for this packet (no new `IIncidentPagingSender` is added to `Notify.Abstractions`).

**Notify is live (Notify v0.x in the catalog), and already ships:**
- `INotificationSender` / `INotificationGateway` — the channel-agnostic dispatch surface. **The Communications paging handler calls this existing contract for delivery.**
- Twilio provider — SMS delivery.
- Resend / SMTP providers — email (used by tenant communications elsewhere, not for paging).
- Queue-backed async delivery, idempotency keys (per ADR-0042), delivery status tracking.

This packet adds a new **incident-paging intent path** in Communications that:
1. Accepts a `PageOperatorRequest` (the *intent* — pre-classified severity from the caller, plus the `Diagnostic` flag, content, fingerprint, etc.).
2. Applies Communications-owned decision logic (operator-availability window per D2; D5 dedup; the `Diagnostic`-gated final-dispatch decision — `Diagnostic: true` short-circuits the actual operator-phone SMS).
3. Composes the final delivery payload (severity-tagged subject, summary, PagerDuty deep-link).
4. Dispatches through Notify's existing `INotificationSender` for SMS (v0) or push (v1).

The new Communications intent surface is callable from:

- Packet 06's Pulse synthetic probe (the every-5-minute fake SEV-3 verification — it sets `Diagnostic: true`).
- Packet 09's Azure Monitor → PagerDuty wiring also posts to Communications in parallel (both paths fire for SEV-1/2 per D3 — `Diagnostic: false`).
- Future direct-from-Source paging calls (Audit, Vault, etc.).

**Cross-deep-link.** Each paged delivery carries a deep-link to the PagerDuty incident — D3 says "Notify-pushed alerts include a deep-link to the PagerDuty incident for ack." The PagerDuty incident URL is supplied by the caller; the Communications handler embeds it in the dispatch payload; the SMS body / push notification body renders it.

**Communications is a deployable Node** at the version its `CHANGELOG.md` records; this packet bumps the `HoneyDrunk.Communications` solution (the first ADR-0054 packet on the solution — minor bump for the new paging-intent surface). Per the dispatch plan, packet 05 (tenant-email templates) also bumps Communications; coordinate the bump so both packets land in one combined minor bump if they merge close in time.

**Vault.** No new Notify-side secret class introduced here — the SMS path reuses Notify's existing Twilio credential in `kv-hd-notify-{env}`. The operator's personal mobile is read from `kv-hd-communications-{env}` (Communications' own Vault per invariant 17) as a Communications-side configuration secret (e.g., `operator-paging-phone`), or alternately stays in `kv-hd-notify-{env}` if Communications reads via Notify's delivery payload (final placement chosen at edit time based on whether Communications needs the phone number directly or only via Notify's existing routing — confirm the existing pattern). If Communications does not yet have a Vault, provision `kv-hd-communications-{env}` first per the ADR-0005 walkthrough — per invariant 17 there is no shared Vault.

## Scope
- `HoneyDrunk.Communications` solution — add the `IIncidentPagingIntent` contract in `HoneyDrunk.Communications.Abstractions` and its handler in `HoneyDrunk.Communications`. The handler owns the severity / dedup / availability / `Diagnostic` decisioning and dispatches through Notify's existing `INotificationSender`.
- Communications test projects — tests covering the SMS-delivery handoff (with the existing Twilio fake / InMemory provider exposed by Notify) and the `Diagnostic: true` short-circuit.
- `HoneyDrunk.Notify` is **not modified** by this packet. The Communications handler consumes the existing `INotificationSender` contract from `HoneyDrunk.Notify.Abstractions`. If a small Notify enhancement is required (e.g., a delivery-status query surface the Communications handler reads to record handoff success), record it as a deferred follow-on; the v0 SMS path through `INotificationSender` already returns delivery status.
- Repo-level `CHANGELOG.md` and any per-package CHANGELOG that actually changes; the `README.md` if the paging surface is documented externally.

## Proposed Implementation
1. **Define the intent contract.** Add `IIncidentPagingIntent` to `HoneyDrunk.Communications.Abstractions`. The contract accepts a record:

   ```csharp
   PageOperatorRequest(
       Severity Severity,
       string Title,
       string Summary,
       string PagerDutyIncidentUrl,
       string FingerprintKey,
       bool Diagnostic);
   ```

   - `Severity` — pre-classified by the caller (sources of severity: D4 routing table, Pulse probe sets SEV-3 for the synthetic).
   - `Diagnostic` — when `true`, the Communications handler **does not dispatch the final SMS/push to the operator's personal phone**. Used by Pulse's synthetic probe (packet 06) to verify the intent path is alive without flooding the operator every 5 minutes. The handler still records the intent-receipt in the delivery-status surface so the probe can verify arrival.

2. **Communications handler — decision logic.** The handler in `HoneyDrunk.Communications` applies:
   - **Operator-availability gating (D2):** within coverage (09:00–21:00 ET), all SEV-1/2 dispatch; outside coverage, SEV-3/4 do not page even if `Diagnostic: false`.
   - **D5 dedup-window (1 hour fingerprint dedup):** repeated calls with the same `FingerprintKey` within the window are silently aggregated, not re-delivered. The dedup state lives in the Communications-side store.
   - **`Diagnostic` gate:** if `Diagnostic: true`, record the intent in delivery-status and stop — do **not** call `INotificationSender`. The arrival-verification surface for the probe reads delivery-status.
   - **Severity-tagged composition:** the handler composes the dispatch payload (subject prefix, summary, deep-link to PagerDuty incident URL) before handing off to Notify.

3. **Delivery handoff via existing Notify contract.** The handler calls `INotificationSender.Send(...)` from `HoneyDrunk.Notify.Abstractions` with the composed payload. v0 routes through Notify's existing Twilio SMS provider; v1 will route through the future Notify push provider. **No new contract is added to `Notify.Abstractions` by this packet.**

4. **Operator phone number from Vault.** The operator's personal mobile is read from `kv-hd-communications-{env}` as a secret (e.g., `operator-paging-phone`). If `kv-hd-communications-{env}` does not yet exist, provision it first per the ADR-0005 walkthrough — per invariant 17 there is no shared Vault. The Twilio sender credentials remain in `kv-hd-notify-{env}` (consumed by Notify's existing provider, not by Communications).

5. **Idempotency.** Reuse the existing Notify idempotency-key mechanism (ADR-0042) at the delivery boundary (`INotificationSender` already enforces it). The Communications handler's `FingerprintKey` maps to the idempotency key passed into `INotificationSender.Send(...)`. The D5 1-hour dedup-window policy lives in the Communications handler (the decision layer), not in Notify.

6. **Companion-app push placeholder.** The v1 companion-app push provider is a Notify-side concern (not a Communications concern). Do not add a placeholder in this packet's Communications surface; the future Notify push provider is added when the companion app stands up. The Communications handler's call to `INotificationSender.Send(...)` is channel-agnostic — when Notify's push provider lands, Communications dispatches push automatically.

7. **Delivery status tracking.** Communications exposes a delivery-status read surface keyed by `FingerprintKey` so the synthetic probe (packet 06) can verify arrival of `Diagnostic: true` intents (those never reach `INotificationSender`). For non-diagnostic intents, the status reflects Notify's underlying delivery status flowed back through the handoff.

8. **D5 dedup state.** The Communications handler holds the fingerprint-window state (in-memory cache + persisted backstop — match the existing Communications-side dedup pattern if one exists; otherwise an in-memory `IMemoryCache` with a 1-hour expiry is acceptable for v0 and documented as a v1 hardening target).

9. **XML documentation** on every public member (invariant 13).
10. **Version bump.** Per invariant 27, this is the first or second ADR-0054 packet on the `HoneyDrunk.Communications` solution (packet 05 also lands templates) — minor bump for the new paging-intent surface. If packet 05 lands first, this packet's bump is the patch increment (or a combined minor if they merge together). Every non-test `.csproj` moves to the same new version in one commit.
11. **CHANGELOG / README.** Repo-level `CHANGELOG.md` new-version entry. Per-package `CHANGELOG.md` entries only for packages with actual changes (invariant 27). Update Communications' `README.md` if the paging surface becomes part of the documented public/operational surface.
12. **Tests.** Unit tests cover: the SMS happy path with the existing Twilio fake / InMemory provider exposed by Notify; the `Diagnostic: true` short-circuit (intent recorded, `INotificationSender` not called); D5 fingerprint dedup; D2 operator-availability gating; deep-link rendering. Tests do not call the real Twilio provider (invariant 15); no `Thread.Sleep` (invariant 51).

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify/Paging/` (or the equivalent location for new channel-specific intake handlers — match existing Notify directory convention).
- `HoneyDrunk.Notify.Abstractions/` — `IIncidentPagingSender` / `PageOperatorRequest` / `IPagingPushProvider` interface declarations (per invariant 1).
- `HoneyDrunk.Notify.HostBootstrap` / `Functions` / `Worker` — DI registration of the new paging intake handler and Vault binding for `operator-paging-phone`.
- Notify test projects — paging-intake tests.
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` for changed packages; every non-test `.csproj` (version bump).
- `HoneyDrunk.Notify/README.md` if it documents the public/operational surface.

## NuGet Dependencies
- **No new external dependency.** SMS delivery reuses the existing Twilio provider package Notify already references.
- The new abstraction types live in `HoneyDrunk.Notify.Abstractions` — invariant 1 (Abstractions packages take only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package they already reference). No external runtime dependency added to Abstractions.
- `HoneyDrunk.Standards` is already on Notify's projects — no change (invariant 26).
- If a new project is created (e.g., a dedicated `HoneyDrunk.Notify.Paging` package), it carries the full standard reference set: `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Notify` (or whichever is the host-composed runtime package), `HoneyDrunk.Standards` (`PrivateAssets: all`), the standard test stack on its `.Tests.Unit` project (invariant 26, ADR-0047). Document why a new project is needed rather than extending an existing one.

## Boundary Check
- [x] `HoneyDrunk.Notify` is the correct repo — ADR-0054 D3 names "the Grid's own Notify Node" as the primary paging path; routing rule "notification, email, SMS, SMTP, Resend, Twilio, notify, channel → HoneyDrunk.Notify" maps exactly.
- [x] Per ADR-0019, Notify owns **delivery mechanics**; decision/orchestration belongs to Communications. The intake contract accepts a **pre-decided** SEV + content payload — Notify does not decide severity or operator availability.
- [x] No code change in any other Node. The synthetic probe (packet 06) and the routing layer (packet 09) call this intake; they do not implement it.
- [x] The abstraction stays free of external runtime dependencies (invariant 1).

## Acceptance Criteria
- [ ] `IIncidentPagingSender` (or the equivalent intake contract — match Notify's existing channel-special-purpose pattern) exists in `HoneyDrunk.Notify.Abstractions` with `PageOperatorRequest { Severity, Title, Summary, PagerDutyIncidentUrl, FingerprintKey }`
- [ ] The handler routes the intake to the existing Twilio SMS provider in v0; the SMS body renders severity + one-line summary + the PagerDuty deep-link
- [ ] The operator's personal mobile number is read from Vault (`operator-paging-phone` in `kv-hd-notify-{env}`) — never hardcoded (invariants 8, 9)
- [ ] Idempotency uses the existing Notify mechanism (ADR-0042); repeated calls with the same `FingerprintKey` within the dedup window are silently aggregated
- [ ] A `IPagingPushProvider` placeholder exists for the v1 companion-app push integration; v0 implementation is no-op or "not implemented" — the companion-app integration is a follow-on, not a blocker
- [ ] Delivery status (success / failure / latency) is recorded per Notify's existing delivery-status pattern so the synthetic probe (packet 06) can verify arrival
- [ ] Notify is the **delivery** layer only — severity decision, operator-availability gating, and dedup-window policy live in the source / routing layer, not in Notify
- [ ] Unit tests cover SMS happy path, idempotency dedup, fingerprint-key handling, deep-link rendering; tests run in-process (invariant 15); no `Thread.Sleep` (invariant 51)
- [ ] The version-state check is performed: the `HoneyDrunk.Notify` solution bumps (first ADR-0054 packet on the solution) — minor bump for the new paging-intake surface (invariant 27)
- [ ] Repo-level `CHANGELOG.md` carries the new version entry; per-package `CHANGELOG.md` for packages with actual changes; `README.md` updated if the paging surface is documented externally
- [ ] The solution builds; existing unit tests pass; tier-1 gate passes (build, unit, analyzers, vuln, secret scan — invariant 31)

## Human Prerequisites
- [ ] **Provision PagerDuty (packet 03) before exercising this packet's path** — the deep-link rendered in the SMS body points at a PagerDuty incident URL, and the synthetic probe (packet 06) will verify both paths together.
- [ ] **Seed the operator's personal mobile number into Vault** as `operator-paging-phone` in `kv-hd-notify-{env}`. The agent cannot perform the Vault secret seeding via portal — this is a portal step.
- [ ] **Twilio sender phone number** must already exist (it does — Notify is LIVE with SMS support). Confirm carrier delivery to the operator's phone in a manual test after merge.
- [ ] The companion-app push integration is a follow-on; no portal step is required at v0.

## Referenced ADR Decisions
**ADR-0054 D3 — Paging mechanism, primary path.** Alerts route through `HoneyDrunk.Notify` per ADR-0019 (Communications owns decision/orchestration; Notify owns intake/delivery). Delivery target: the operator's personal phone via push notification (initially APNs/FCM through a small Studios-internal companion app, or via SMS if the companion app is not yet built). Latency target < 30 seconds. Cost bundled into Notify infra already running. Notify-pushed alerts include a deep-link to the PagerDuty incident for ack. **Both paths fire for SEV-1/2.** SEV-3 fires Notify only. SEV-4 fires neither.

**ADR-0054 — v0 SMS fallback.** "v0 may use SMS via Notify if the companion app isn't ready; the trade-off is slightly higher delivery latency for v0." The companion-app push integration is initial work, not a blocker.

**ADR-0019 — Communications/Notify split.** Notify owns **delivery mechanics**; Communications owns **decision/orchestration**. The paging intake accepts a pre-decided SEV + content payload; Notify does not decide severity.

**ADR-0042 — Idempotency.** The intake's `FingerprintKey` maps to the existing Notify idempotency key; repeated calls with the same fingerprint within the dedup window are silently aggregated, not re-delivered.

**ADR-0005 — Vault placement.** Twilio credentials and the operator paging phone number live in `kv-hd-notify-{env}` per the one-Vault-per-Node-per-environment rule.

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `HoneyDrunk.Notify.Abstractions` takes only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package it already references. No external SDK in Abstractions.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The operator paging phone number and Twilio credentials never appear in logs, in the SMS body's diagnostic envelope, or in any captured exception.

> **Invariant 9 — Vault is the only source of secrets.** The operator paging phone number is read via `ISecretStore`; never via environment variables or hardcoded constants.

> **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards`.

> **Invariant 15 — Unit tests never depend on external services.** SMS path tests use the existing Twilio fake / InMemory provider.

> **Invariant 17 — One Key Vault per deployable Node per environment.** Notify's Vault is `kv-hd-notify-{env}`.

> **Invariant 26 — Work items for .NET code work include a `## NuGet Dependencies` section; `HoneyDrunk.Standards` is on every new .NET project** (analyzers, `PrivateAssets: all`).

> **Invariant 27 — All projects in a solution share one version and move together.** First ADR-0054 packet on `HoneyDrunk.Notify` → version bumps.

> **Invariant 31 — Every PR traverses the tier-1 gate before merge.** Build, unit tests, analyzers, vulnerability scan, secret scan are required.

> **Invariant 51 — Test code contains no `Thread.Sleep`.**

- **Notify is delivery, not decision.** Severity, dedup-window, and operator-availability gating live in the source / routing layer; the intake accepts pre-decided payloads.
- **v0 SMS fallback is fine.** The companion-app push integration is a follow-on. v0 SMS ships with this packet.
- **Deep-link required.** Every paged SMS body carries the PagerDuty incident URL — that is the operator's ack surface.

## Labels
`feature`, `tier-2`, `ops`, `adr-0054`, `wave-2`

## Agent Handoff

**Objective:** Add the incident-paging intake contract and its v0 SMS-via-Twilio handler to `HoneyDrunk.Notify` so the routing layer (packet 09), the synthetic probe (packet 06), and the future direct-from-Source paging callers can deliver pages to the operator's phone with a deep-link to the PagerDuty incident.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Implement the primary path of the redundant paging mechanism (D3). PagerDuty (packet 03) is the secondary. Both paths fire for SEV-1/2.
- Feature: ADR-0054 Incident Response rollout, Wave 2.
- ADRs: ADR-0054 D3 (primary), ADR-0019 (Notify owns delivery; Communications owns decision), ADR-0042 (idempotency), ADR-0005 (Vault placement).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0054 should be Accepted before its paging substrate ships.
- `work-item:03` — hard. The PagerDuty incident URL the SMS body deep-links to is created by PagerDuty (the secondary path) — the cross-link requires the PagerDuty integration to exist. Functionally, the URL is a parameter — the code compiles without PagerDuty existing — but the end-to-end test requires it.

**Constraints:**
- Notify is delivery, not decision (ADR-0019).
- v0 SMS via existing Twilio provider; companion-app push is a follow-on.
- Vault-stored operator paging phone number (invariants 8, 9, 17).
- Idempotency via the existing Notify mechanism (ADR-0042).
- Perform the invariant-27 version-bump check on the `HoneyDrunk.Notify` solution — first ADR-0054 packet → bumps.

**Key Files:**
- `HoneyDrunk.Notify.Abstractions/` — `IIncidentPagingSender`, `PageOperatorRequest`, `IPagingPushProvider`
- `HoneyDrunk.Notify/Paging/` — handler implementation routing to existing Twilio SMS
- Notify host bootstrap projects — DI registration, Vault secret binding
- Notify test projects — paging-intake tests
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` for changed packages; every non-test `.csproj` (version bump)

**Contracts:**
- `IIncidentPagingSender` — the new paging intake. Consumed by packet 06 (synthetic probe) and packet 09 (routing wiring).
- `IPagingPushProvider` — placeholder for v1 companion-app push; v0 no-op.
