---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0054", "wave-2"]
dependencies: ["packet:03", "packet:04"]
adrs: ["ADR-0054", "ADR-0028", "ADR-0005"]
accepts: ["ADR-0054"]
wave: 2
initiative: adr-0054-incident-response
node: honeydrunk-pulse
---

# Add the every-5-minute synthetic paging-path probe to HoneyDrunk.Pulse

## Summary
Add the **paging-path synthetic probe** to `HoneyDrunk.Pulse` per ADR-0054 D3's "who watches the watchmen" pattern: every 5 minutes the probe fires a **fake SEV-3** alert that flows through both the Notify primary path and the PagerDuty secondary path; if either path goes silent for > 15 minutes, the **other path** fires a SEV-2 about the missing path. The probe is itself a Grid-health-monitored synthetic on the Pulse synthetic-monitoring surface ADR-0028 defines.

## Context
ADR-0054 D3 names the synthetic paging-path probe as the mechanism that detects "Notify is itself down" and "PagerDuty is itself down" — the failure modes that the redundant paging pattern exists to survive. Without the probe, the operator only discovers paging-path failure when a real incident is silenced — too late.

The probe's behavior (verbatim from D3):

- **Every 5 minutes**, the probe fires a synthetic SEV-3 alert.
- The alert flows through **both** the Notify primary path (packet 04's `IIncidentPagingSender`) and the PagerDuty secondary path (packet 03's integration).
- The probe **verifies arrival** on both paths — the Notify-side delivery-status surface (packet 04 records arrival per the existing pattern) and the PagerDuty-side ack or auto-resolve (PagerDuty's Events API v2 returns a dedup-key receipt on POST; the probe can poll the PagerDuty incident's state or rely on PagerDuty's webhook back to a probe-receipt endpoint).
- **If either path goes silent for > 15 minutes** (three consecutive 5-min probe cycles miss arrival verification on one path), the **other path** fires a **SEV-2** about the missing path. The SEV-2 says "PagerDuty silent for 15+ min" or "Notify silent for 15+ min."
- The fake SEV-3 itself does **not** burn a real PagerDuty incident's ack tax — D3 says "SEV-3 fires Notify only (no PagerDuty cost burn for non-paging-worthy events)." **But the probe is the exception** — it must fire PagerDuty too, otherwise it cannot verify the PagerDuty path. The probe uses a dedicated PagerDuty Events API v2 integration configured to **auto-resolve immediately** so it doesn't accumulate. The probe's special-cased behavior is documented in PagerDuty's integration (probably as a dedicated service with auto-resolve, or with the `event_action: resolve` immediately following the `event_action: trigger`).
- The probe **does not page the operator's phone** — D3 says "SEV-3 fires Notify only." For the probe's purposes, the Notify-side verification is that Notify *received and accepted* the page-intake call, not that the SMS arrived on the operator's phone. The probe uses an internal verification endpoint, not a real SMS. Notify's intake (packet 04) records delivery status — the probe queries that status surface.

**Pulse owns synthetic monitoring.** Per ADR-0028 (event-driven architecture / synthetic monitoring) and the existing Pulse surface, Pulse runs scheduled synthetic probes. The new probe lives on the Pulse synthetic-monitoring surface — match the existing convention.

**Pulse is a Seed Node** per the catalog. Its solution exists and is versioned; this is the first ADR-0054 packet on the Pulse solution → minor bump per invariant 27.

**Vault.** The probe authenticates to PagerDuty via the Events API v2 key stored at `pagerduty-events-api-key` in `kv-hd-pulse-{env}` per packet 03's canonical Vault placement (invariant 17 — no shared Vault). The probe authenticates to Notify via the existing Notify intake surface (no new credential — Notify's intake authenticates via the Grid identity per ADR-0005's intra-Grid auth).

## Scope
- `HoneyDrunk.Pulse` solution — a new synthetic probe `PagingPathProbe` on the Pulse synthetic-monitoring surface, running every 5 minutes.
- The probe's verification logic — confirms each fired probe arrived on Notify (via Notify's delivery-status surface) and PagerDuty (via the Events API v2 receipt or PagerDuty's webhook back to a probe-receipt endpoint).
- The 15-min-silent SEV-2 escalation — the surviving path fires a SEV-2 alert about the missing path.
- Pulse test projects — tests covering the happy path (both arrive), each silent-path scenario (Notify-silent, PagerDuty-silent), and the escalation behavior. Tests use the InMemory provider for both Notify and PagerDuty per invariant 15.
- Repo-level `CHANGELOG.md` and per-package `CHANGELOG.md` for changed packages.

## Proposed Implementation
1. **Define the probe.** `PagingPathProbe` is a scheduled job on the Pulse synthetic-monitoring surface — match the existing scheduled-synthetic pattern. The schedule is **every 5 minutes**. The probe carries a unique `FingerprintKey = "pulse.paging-path-probe"` so D5 dedup does not collapse it with anything else.
2. **Fire the probe through both paths.** Each probe cycle:
   - Invokes `IIncidentPagingSender.PageOperator(...)` (from packet 04) with `Severity = SEV-3`, `Title = "Pulse paging-path probe"`, `Summary = "Synthetic probe, 5-min cycle"`, `PagerDutyIncidentUrl = <probe-receipt-url>`, `FingerprintKey = "pulse.paging-path-probe-<cycle-id>"`.
   - Posts a synthetic event to the PagerDuty Events API v2 (using the dedicated probe-integration key from Vault), with `event_action: trigger` followed immediately by `event_action: resolve` so PagerDuty does not accumulate open incidents from the probe.
3. **Verify arrival.**
   - **Notify side:** query Notify's delivery-status surface for the probe's fingerprint key; expect `delivered: true` (or `accepted` — match the existing Notify status semantics) within the cycle's verification window (e.g., 90 seconds).
   - **PagerDuty side:** the Events API v2 returns a dedup-key receipt on POST; the probe records the receipt. Optionally, PagerDuty's webhook back can confirm processing — the simpler v0 implementation is to treat the Events API v2 200-OK receipt as proof of arrival.
4. **15-min silent → SEV-2.** Track the per-path consecutive miss count. If a path misses **three consecutive cycles** (5 min × 3 = 15 min), fire a SEV-2 alert about the missing path through the **surviving** path:
   - If Notify is silent, fire the SEV-2 via PagerDuty (`event_action: trigger`, severity high, summary "Notify paging path silent for 15 min").
   - If PagerDuty is silent, fire the SEV-2 via Notify (call `IIncidentPagingSender.PageOperator(SEV-2, "PagerDuty paging path silent for 15 min", ..., FingerprintKey = "pulse.pagerduty-path-down")`).
   - The SEV-2 is **paged for real** — it is the warning the operator must see.
5. **Auto-recovery.** When a previously-silent path comes back, the SEV-2 auto-resolves per the D5 auto-resolve pattern (5 minutes of continuous health). The probe sends an `event_action: resolve` to PagerDuty for the SEV-2 and / or marks the Notify-side SEV-2 resolved per the existing dedup pattern.
6. **No real operator-phone notification from SEV-3 probe.** The Notify intake's existing channel routing must NOT deliver the SEV-3 probe SMS to the operator's personal phone — that would be a flood. Use a Notify intake variant that records arrival without actually dispatching to the SMS provider, OR have the probe call a dedicated diagnostics endpoint that exercises the intake validation/queueing without the final SMS send. **Match Notify's existing synthetic-test pattern** (Notify presumably already has a "test delivery" or "dry-run" path; if not, the probe configures the intake with an explicit `diagnostic = true` flag and Notify gates the final-channel dispatch on it). Document the choice.
7. **PagerDuty probe-integration discipline.** The probe's PagerDuty integration is a **dedicated** service / integration in PagerDuty (per packet 03's walkthrough — the probe should have its own service, not the main "HoneyDrunk Studios Operator" service, so probe firings don't bury real incidents). Coordinate with packet 03: if the walkthrough doesn't already provision a probe-dedicated service, this packet's PR comment requests the addition (and the walkthrough is amended).
8. **Pulse's own telemetry.** The probe emits its own metrics — probe success rate, per-path miss count, per-cycle latency. Per ADR-0040, this goes through the Pulse OTLP surface and lands in App Insights. Per ADR-0045, probe failures are *not* errors (D12 in ADR-0045 says synthetic probe failure → metric/log, not an exception) — so probe outcomes flow to metrics, not to `IErrorReporter`.
9. **XML documentation** on every public member (invariant 13).
10. **Version bump.** First ADR-0054 packet on the `HoneyDrunk.Pulse` solution → minor bump per invariant 27.
11. **CHANGELOG / README.** Repo-level `CHANGELOG.md` new-version entry. Per-package `CHANGELOG.md` for packages with actual changes. Update Pulse `README.md` if the synthetic-probe surface is part of the documented public/operational surface.
12. **Tests.** Unit / integration tests cover: happy path (both arrive), Notify-silent (probe escalates via PagerDuty), PagerDuty-silent (probe escalates via Notify), recovery / auto-resolve, the probe SMS does NOT route to the operator's personal phone. Tests use InMemory Notify and a stubbed PagerDuty Events API client (invariant 15); no `Thread.Sleep` (invariant 51) — time-based behavior uses a virtual clock or polling primitives with explicit timeouts.

## Affected Files
- `HoneyDrunk.Pulse/Synthetics/` or the existing scheduled-synthetic location — `PagingPathProbe.cs`, the probe handler.
- `HoneyDrunk.Pulse/Synthetics/PagerDuty/` (or equivalent) — a thin PagerDuty Events API v2 client used by the probe.
- Pulse host bootstrap projects — DI registration of the probe, Vault binding for the PagerDuty Events API key, the schedule registration.
- Pulse test projects — probe tests.
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` for changed packages; every non-test `.csproj` (version bump).
- `HoneyDrunk.Pulse/README.md` if the probe surface is documented externally.

## NuGet Dependencies
- **PagerDuty Events API v2 client** — there is no first-party SDK; the API is a simple HTTP POST to `https://events.pagerduty.com/v2/enqueue` with a JSON payload. Use `System.Net.Http.HttpClient` from `Microsoft.Extensions.Http` (Pulse already references this) — no new external NuGet package. Document the choice in the PR.
- **Notify intake** is consumed via the existing `HoneyDrunk.Notify.Abstractions` package reference Pulse already has (or that the Pulse host bootstrap adds — confirm at edit time).
- The new abstraction types (if any new public abstractions are introduced) live in the appropriate Pulse-abstractions package — invariant 1.
- `HoneyDrunk.Standards` is already on Pulse's projects — no change (invariant 26).

## Boundary Check
- [x] `HoneyDrunk.Pulse` is the correct repo — synthetic monitoring is a Pulse responsibility per ADR-0028 and the existing Pulse synthetic-monitoring surface.
- [x] Pulse consumes `IIncidentPagingSender` (a published Notify Abstractions contract per packet 04) — it does not reach into Notify internals (invariant 3).
- [x] Pulse consumes the PagerDuty Events API as an external HTTP surface — no Notify involvement on the secondary path.
- [x] The probe is the **exception** that fires PagerDuty for SEV-3 — D3 says SEV-3 fires Notify only "except for the synthetic probe." Document the exception in the probe's XML docs.
- [x] Probe failures emit metrics, not `IErrorReporter` captures (ADR-0045 D12).

## Acceptance Criteria
- [ ] `PagingPathProbe` runs every 5 minutes on the Pulse synthetic-monitoring surface
- [ ] Each cycle fires through both the Notify intake (`IIncidentPagingSender.PageOperator` with `Severity = SEV-3` and a unique `FingerprintKey`) and the PagerDuty Events API v2 (`event_action: trigger` followed immediately by `event_action: resolve` so PagerDuty does not accumulate)
- [ ] The probe **verifies arrival** on both paths within the cycle's verification window: Notify via the delivery-status surface; PagerDuty via the Events API receipt
- [ ] On 3 consecutive misses on one path (15 min silent), the **surviving** path fires a real SEV-2 about the missing path; the SEV-2 actually pages the operator
- [ ] Recovery: when a previously-silent path is back for 5 minutes, the SEV-2 auto-resolves per D5
- [ ] The probe's SEV-3 SMS does NOT dispatch to the operator's personal phone — match Notify's existing synthetic / dry-run pattern, or add the `diagnostic = true` flag (documented)
- [ ] The probe's PagerDuty integration is a **dedicated** service (not the main operator service) so probe firings don't bury real incidents; coordinate with packet 03's walkthrough
- [ ] Probe outcomes emit metrics through the existing Pulse OTLP surface (per ADR-0040); probe failures are metrics, NOT `IErrorReporter` captures (ADR-0045 D12)
- [ ] PagerDuty Events API v2 key is read from Vault via `ISecretStore` (invariants 8, 9); the documented path matches packet 03's walkthrough
- [ ] Every new public member has XML documentation; the probe's XML docs name the D3 exception (probe fires PagerDuty for SEV-3 even though D3 says SEV-3 fires Notify only)
- [ ] Tests cover happy path, both silent-path scenarios, recovery, and the no-personal-phone-SMS guarantee; tests run in-process (invariant 15); no `Thread.Sleep` (invariant 51); time-based behavior uses a virtual clock or polling primitives
- [ ] The version-state check is performed: the `HoneyDrunk.Pulse` solution bumps (first ADR-0054 packet on the solution) — minor bump for the new probe (invariant 27)
- [ ] Repo-level `CHANGELOG.md` carries the new version entry; per-package `CHANGELOG.md` for packages with actual changes; `README.md` updated if the probe surface is documented externally
- [ ] The solution builds; existing unit tests pass; tier-1 gate passes

## Human Prerequisites
- [ ] **Packet 03's PagerDuty walkthrough must create a dedicated probe service / integration in PagerDuty** so probe firings have their own surface and don't bury real-incident triage. If packet 03's walkthrough did not provision this, follow-on to packet 03 to add it.
- [ ] **Confirm Vault path for the PagerDuty Events API v2 key** — packet 03 documents the path; this packet's DI registration reads from it.
- [ ] **Confirm Notify intake's diagnostic / synthetic pattern** at execution time. If Notify has no existing "do not actually send to the operator" path, document the gap and either add the `diagnostic = true` flag in this packet's PR (small follow-on to packet 04) or use Notify's InMemory provider in the dev/staging environment.

## Referenced ADR Decisions
**ADR-0054 D3 — Synthetic paging-path probe.** "Pulse (ADR-0028) runs a synthetic probe every 5 minutes that fires a fake SEV-3 alert and verifies arrival on both Notify and PagerDuty paths. If either path goes silent for > 15 minutes, the other path fires a SEV-2 about the missing path. This is the 'who watches the watchmen' pattern. The Pulse probe is itself a Grid-health-monitored synthetic."

**ADR-0054 D3 — Exception for the probe firing PagerDuty on SEV-3.** D3 says "SEV-3 fires Notify only (no PagerDuty cost burn for non-paging-worthy events)" — the probe is the exception because it must fire PagerDuty to verify the path; the probe uses an immediate-resolve pattern so it does not accumulate.

**ADR-0054 D5 — Single-page rule, fingerprint, auto-resolve.** The probe's `FingerprintKey` participates in D5 dedup; the 15-min-silent SEV-2 has its own fingerprint; auto-resolve fires when the underlying condition clears for 5 minutes.

**ADR-0028 — Pulse synthetic monitoring surface.** The new probe lives on the Pulse synthetic-monitoring surface ADR-0028 defines; match the existing scheduled-synthetic pattern.

**ADR-0045 D12 — Synthetic monitoring is not an error source.** Probe failures emit metrics/logs, not `IErrorReporter` captures. Probe outcomes flow to metrics through the existing Pulse OTLP surface.

**ADR-0040 — Pulse is the telemetry-export boundary.** Probe metrics flow through the existing Pulse OTLP path to App Insights.

**ADR-0005 — Vault placement.** Pulse's Vault is `kv-hd-pulse-{env}` per invariant 17 (one Vault per deployable Node — no shared Vault fallback). The PagerDuty Events API v2 key is read from the documented path. If `kv-hd-pulse-{env}` does not exist yet, provisioning it is a Human Prerequisite for this packet — packet 03 holds the canonical Vault placement for the PagerDuty secret and matches this rule.

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** Any new abstraction types respect this.

> **Invariant 3 — Provider packages depend on their parent Node's contracts, not internals.** Pulse consumes `IIncidentPagingSender` from `HoneyDrunk.Notify.Abstractions`; never Notify internals.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The PagerDuty Events API v2 key never appears in logs, traces, the probe's emitted metrics, or any captured exception.

> **Invariant 9 — Vault is the only source of secrets.** The PagerDuty Events API v2 key is read via `ISecretStore`.

> **Invariant 13 — All public APIs have XML documentation.**

> **Invariant 15 — Unit tests never depend on external services.** Probe tests use InMemory Notify and a stubbed PagerDuty Events API client.

> **Invariant 17 — One Key Vault per deployable Node per environment.** Pulse's secret reads from the Pulse-environment Vault.

> **Invariant 26 — Issue packets for .NET code work include a `## NuGet Dependencies` section.**

> **Invariant 27 — All projects in a solution share one version and move together.** First ADR-0054 packet on `HoneyDrunk.Pulse` → version bumps.

> **Invariant 31 — Every PR traverses the tier-1 gate before merge.**

> **Invariant 51 — Test code contains no `Thread.Sleep`.** Time-based behavior uses a virtual clock or polling primitives with explicit timeouts.

- **The probe is the SEV-3-fires-PagerDuty exception.** Document this in XML docs.
- **The probe does NOT dispatch to the operator's personal phone.** Notify-side synthetic / dry-run / diagnostic flag handles this.
- **The probe's PagerDuty service is dedicated** (not the main operator service) so probe firings don't bury real incidents.
- **Probe failures are metrics, not `IErrorReporter` captures** (ADR-0045 D12).
- **PagerDuty Events API v2 trigger + immediate resolve** so PagerDuty does not accumulate open incidents from the probe.

## Labels
`feature`, `tier-2`, `ops`, `adr-0054`, `wave-2`

## Agent Handoff

**Objective:** Add the every-5-minute synthetic paging-path probe to `HoneyDrunk.Pulse` so the Grid detects Notify-itself-down and PagerDuty-itself-down within 15 minutes.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Implement the "who watches the watchmen" pattern from ADR-0054 D3 — the cross-path liveness probe that exercises both paging surfaces every 5 minutes and escalates if either goes silent.
- Feature: ADR-0054 Incident Response rollout, Wave 2.
- ADRs: ADR-0054 D3 / D5 (primary), ADR-0028 (Pulse synthetic monitoring), ADR-0045 D12 (probe failures emit metrics, not captures), ADR-0040 (Pulse OTLP boundary), ADR-0005 (Vault placement).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — hard. The PagerDuty integration (Events API v2 key, dedicated probe service) must exist before the probe can fire it.
- `packet:04` — hard. The probe consumes `IIncidentPagingSender` from packet 04; the contract must exist.

**Constraints:**
- Probe fires PagerDuty for SEV-3 (the D3 exception); uses immediate-resolve.
- No personal-phone SMS from the probe.
- Dedicated PagerDuty probe service (coordinate with packet 03).
- Probe failures are metrics, not `IErrorReporter` captures (ADR-0045 D12).
- Vault-stored Events API v2 key (invariants 8, 9, 17).
- No `Thread.Sleep` — virtual clock / polling primitives.
- Perform the invariant-27 version-bump check on `HoneyDrunk.Pulse` — first ADR-0054 packet → bumps.

**Key Files:**
- `HoneyDrunk.Pulse/Synthetics/PagingPathProbe.cs` (new, location matches existing scheduled-synthetic convention)
- `HoneyDrunk.Pulse/Synthetics/PagerDuty/PagerDutyEventsApiClient.cs` (new, thin HTTP client)
- Pulse host bootstrap projects — DI registration, schedule registration, Vault binding
- Pulse test projects — probe tests
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md`; non-test `.csproj` (version bump)

**Contracts:**
- `IIncidentPagingSender` (consumed) — from packet 04.
- PagerDuty Events API v2 (external) — HTTP surface, no SDK.
