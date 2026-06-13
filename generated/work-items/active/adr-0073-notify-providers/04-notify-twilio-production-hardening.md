---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0073", "wave-2"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0073", "ADR-0062", "ADR-0006", "ADR-0005"]
wave: 2
initiative: adr-0073-notify-providers
node: honeydrunk-notify
---

# Production-harden the Twilio SMS provider for ADR-0073 D2 (tentative-commitment note)

## Summary
Complete the production-hardening obligations ADR-0073 D2 puts on the canonical Twilio SMS provider: webhook intake for delivery events per ADR-0062 (delivered / failed / queued), Tier-2 secret rotation registration per ADR-0006, **tentative-commitment note** recorded in the package README and in `repos/HoneyDrunk.Notify/overview.md` (per ADR-0073 D2's re-evaluation triggers), and confirmation that the existing `HoneyDrunk.Notify.Providers.Sms.Twilio` package (v0.3.0) is the canonical `ISmsSender` slot fill. **Appends to the in-progress `[0.3.1]` CHANGELOG entry created by packet 01** — no version bump.

## Context
The `HoneyDrunk.Notify.Providers.Sms.Twilio` package already exists in the Notify repo at version 0.3.0 (per `HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Sms.Twilio/HoneyDrunk.Notify.Providers.Sms.Twilio.csproj`). It already:

- Implements `INotificationSender` against Twilio for `NotificationChannel.Sms` (per `TwilioNotificationSender.cs` and `DependencyInjection/`).
- Resolves account credentials from `ISecretStore` at send time (the v0.2.0 CHANGELOG note describes the Vault-backed pattern).
- Is named `Providers.Sms.Twilio` (channel-scoped — the convention this initiative is preserving).

What is **not yet in place** per ADR-0073 D2 + the referenced ADRs:

1. **Webhook intake for delivery events** per ADR-0062. Twilio posts webhook callbacks for `delivered`, `failed`, `queued`, `sent` events on configured `StatusCallback` URLs. ADR-0062's verification model (Twilio uses HTTP signature verification via `X-Twilio-Signature` header + the configured auth token) must be applied at the intake.
2. **Tier-2 secret rotation registration** per ADR-0006. The Twilio Account SID + Auth Token sit in `kv-hd-notify-{env}` and rotate per Tier-2 cadence (≤90 days). The rotation calendar registration in `HoneyDrunk.Vault.Rotation` must list Twilio.
3. **Tentative-commitment note** per ADR-0073 D2. The ADR explicitly marks the Twilio commitment as tentative and names the re-evaluation triggers (monthly SMS spend > $200; tenant-driven requirement; Twilio stewardship event). This note belongs in the package README so the next operator looking at the Twilio package sees the tentative posture and the trigger conditions; it also belongs in `repos/HoneyDrunk.Notify/overview.md` so the Notify Node's overview reflects the policy.

This is **not a new package** — it is hardening of an existing package. **No version bump in this packet** — it appends to the `[0.3.1]` entry packet 01 creates.

## Scope
- **`HoneyDrunk.Notify` (intake / runtime)** — new webhook intake endpoint for Twilio delivery events, applying ADR-0062's verification model (Twilio's `X-Twilio-Signature` HMAC scheme). Wired into Notify's existing intake pipeline.
- **`HoneyDrunk.Notify.Providers.Sms.Twilio`** — provider package gets:
  - `README.md` updated with: the ADR-0073 D2 default-provider declaration; the **tentative-commitment note** (re-evaluation triggers verbatim); the ADR-0062 webhook intake cross-reference; the ADR-0006 Tier-2 rotation cross-reference.
  - `CHANGELOG.md` updated with a `[0.3.1]` entry — the existing `[Unreleased]` line (if any) is rolled into the `[0.3.1]` section together with the hardening changes.
- **`HoneyDrunk.Notify.Hosting.AspNetCore`** (or the existing intake-route location) — register the Twilio webhook route.
- **`HoneyDrunk.Notify.Tests`** — unit tests for the Twilio webhook intake (signature verification; rejected-payload semantics; event-routing).
- **`HoneyDrunk.Notify.IntegrationTests`** — integration test for the webhook end-to-end.
- **`repos/HoneyDrunk.Notify/overview.md`** (in `HoneyDrunk.Architecture` — see note below) — tentative-commitment note added to the Notify overview so the Node-level architectural context reflects the policy.

> **Cross-repo note.** This packet's scope is primarily `HoneyDrunk.Notify`, but the `repos/HoneyDrunk.Notify/overview.md` update lives in `HoneyDrunk.Architecture`. **Per the issue-authoring rule "one packet = one target repo," the Architecture-side overview update is rolled into this packet's PR only if the execution agent is filing PRs against both repos in one ticket — otherwise, file a tiny follow-up packet against Architecture.** The recommended approach: the agent files the Notify-side PR (code + README), and either (a) opens a separate Architecture PR with the overview edit as a parallel `[1]` step, or (b) defers the overview edit to a quick follow-up packet that the operator files manually. The acceptance criteria below cover both paths and pass either way.

## Out of Scope
- The actual SMS-marketing / TCPA compliance work — ADR-0073 D2 explicitly names this as a per-PDR consumer-app concern; Notify does not enforce it at the provider layer.
- Per-region number management — D1 of ADR-0073's D2 names this as Notify-internal but the v1 posture is single-region (US, with the Studios toll-free number per ADR-0038). Multi-region is deferred to a tenant-driven trigger.
- The D2 cost-trigger re-evaluation itself — that fires when the trigger condition is met (e.g. monthly spend > $200). Not gated here.

## Proposed Implementation
1. **Webhook intake — author the Twilio webhook endpoint.**
   - Add an HTTP POST endpoint (e.g. at `/internal/webhooks/twilio` — confirm path convention against the Resend endpoint added in packet 01 and the existing intake routes).
   - Apply ADR-0062's verification using Twilio's HMAC scheme: read the `X-Twilio-Signature` header, recompute the signature using the Twilio auth token resolved via `ISecretStore` (secret name `Twilio--AuthToken` — confirm against the existing Twilio-secret-name convention in `HoneyDrunk.Notify.Providers.Sms.Twilio`), reject on mismatch with `401 Unauthorized` per ADR-0062.
   - On verified payloads, parse the event (Twilio's status-callback payload schema — `MessageSid`, `MessageStatus`, `ErrorCode`, etc.) and route into Notify's existing intake pipeline as a `DeliveryStatusEvent` (or the existing event shape used by packet 01's Resend handler — reuse for consistency).
   - Map Twilio statuses to internal event shapes: `delivered` → delivered; `failed` → failed (with `ErrorCode` as classification); `undelivered` → failed; `sent` → in-flight; `queued` → queued.
2. **Tier-2 rotation calendar registration.**
   - Confirm whether `HoneyDrunk.Vault.Rotation`'s rotation calendar already lists `Twilio--AuthToken` and `Twilio--AccountSid` (likely from the `vault-rotation-bring-up` initiative). If absent, register them. Twilio Auth Tokens rotate per Tier-2 cadence (≤90 days). Twilio Account SIDs are typically not rotated (they identify the account); confirm against Twilio's current account-credential model whether SID rotation is even supported. If not, document the exception in the rotation calendar configuration with an inline rationale (per invariant 20 — exceptions must be logged).
3. **README cross-references** in `HoneyDrunk.Notify.Providers.Sms.Twilio/README.md`:
   - Add a section "ADR-0073 D2 default provider declaration (tentative)" stating: "Twilio is the canonical default SMS provider for HoneyDrunk.Notify's `ISmsSender` slot per ADR-0073 D2. **The commitment is tentative** — the ADR explicitly names re-evaluation triggers (see below). Per-tenant overrides are permitted per D5."
   - Add a section "Re-evaluation triggers (ADR-0073 D2)" stating verbatim:
     - "First month with SMS spend > $200. At that point, run a cost comparison against MessageBird and Plivo for the same workload mix. Switch if the savings justify the migration cost (a one-PR adapter swap behind `ISmsSender`)."
     - "A specific tenant-driven requirement (regulatory, country-specific) that another provider serves better."
     - "A Twilio stewardship event (pricing change, hostile policy, API instability) that breaks trust."
     - "Until a trigger fires, Twilio is the default."
   - Add a section "Webhook intake (ADR-0062)" stating: "Twilio status-callback webhooks (`delivered`, `failed`, `queued`, `sent`) are received and verified per ADR-0062's HMAC-signed inbound discipline using Twilio's `X-Twilio-Signature` scheme and the auth token resolved from `Twilio--AuthToken` in `kv-hd-notify-{env}`."
   - Add a section "Rotation (ADR-0006 Tier 2)" stating: "The Twilio Auth Token (`Twilio--AuthToken`) rotates at Tier 2 cadence (≤90 days) via `HoneyDrunk.Vault.Rotation`. The Twilio Account SID (`Twilio--AccountSid`) is the account identifier and is not rotated; if Twilio's account-credential model changes to support SID rotation, this exception is removed."
   - Add a section "SMS-marketing / TCPA discipline" stating: "TCPA and SMS-marketing compliance is a per-PDR consumer-app concern per ADR-0073 D2. Notify does not enforce it at the provider layer. Consumer-PDRs that send SMS at scale (Notify Cloud, Hearth, Currents) are individually responsible for opt-in records, STOP/HELP handling, time-of-day restrictions, and 10DLC registration."
4. **Per-package CHANGELOG (`HoneyDrunk.Notify.Providers.Sms.Twilio/CHANGELOG.md`)** — add a `[0.3.1] - {merge-date}` section. Roll any existing `[Unreleased]` line into this section. Add the hardening entries: webhook intake; Tier-2 rotation registration; ADR-0073 D2 default-provider declaration with tentative-commitment note.
5. **Repo-level `CHANGELOG.md`** — **append** to the `[0.3.1]` entry created by packet 01; do **not** create a new dated section. Add one line for the Twilio production-hardening summary.
6. **`repos/HoneyDrunk.Notify/overview.md`** (Architecture-side) — see the cross-repo note in Scope. Add the tentative-commitment text under a new `## SMS Provider (ADR-0073 D2 — Tentative)` section: "Twilio is the canonical default SMS provider per ADR-0073 D2. **The commitment is tentative** pending re-evaluation triggers (first month with SMS spend > $200; tenant-driven requirement; Twilio stewardship event). When a trigger fires, the provider swap is bounded — a one-PR adapter swap behind `ISmsSender`."
7. **Version handling.** Confirm packet 01 has already bumped the solution to `0.3.1`. If yes — this packet leaves the `.csproj` files alone (no version change), and only appends to the repo-level `[0.3.1]` CHANGELOG entry plus adds the Twilio per-package CHANGELOG entry. If no (packet 01 has not yet merged) — this packet does the bump (rolling existing `[Unreleased]` into `[0.3.1]` as packet 01 would have). State the chosen path in the PR.

## Affected Files
- `HoneyDrunk.Notify/Intake/` (or equivalent) — new file for the Twilio webhook route handler.
- `HoneyDrunk.Notify.Hosting.AspNetCore/` — register the route if needed.
- `HoneyDrunk.Notify.Providers.Sms.Twilio/README.md`, `CHANGELOG.md`.
- Repo-level `CHANGELOG.md` — append to existing `[0.3.1]`.
- `HoneyDrunk.Notify.Tests/` — new tests.
- `HoneyDrunk.Notify.IntegrationTests/` — new integration test.
- `repos/HoneyDrunk.Notify/overview.md` (in `HoneyDrunk.Architecture`) — tentative-commitment section. See Scope's cross-repo note.

## NuGet Dependencies
- **`HoneyDrunk.Notify`** — no new third-party `PackageReference`. Twilio's signature scheme is verifiable with BCL `System.Security.Cryptography` (or via the existing Twilio SDK already in `Providers.Sms.Twilio` — confirm at execution which path the existing send code uses).
- **`HoneyDrunk.Notify.Providers.Sms.Twilio`** — no new `PackageReference`. The existing Twilio SDK reference is unchanged.
- **Test projects** — existing test-stack references.

## Boundary Check
- [x] All code work in `HoneyDrunk.Notify` per the routing rule.
- [x] Webhook intake is delivery mechanics per Notify's boundaries.md.
- [x] No new cross-Node runtime dependency.
- [x] TCPA / SMS-marketing discipline is correctly placed outside Notify per ADR-0073 D2 (per-PDR concern).

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify` exposes an HTTP POST webhook route for Twilio status-callback events
- [ ] The route applies ADR-0062 HMAC signature verification using Twilio's `X-Twilio-Signature` scheme and `ISecretStore`-resolved `Twilio--AuthToken`
- [ ] Verified payloads route into Notify's existing intake event pipeline; invalid signatures return 401 without side-effects
- [ ] Twilio statuses map to Notify's internal event shapes: `delivered`, `failed` (with Twilio `ErrorCode` classification), `sent` (in-flight), `queued`
- [ ] `Twilio--AuthToken` is listed in `HoneyDrunk.Vault.Rotation`'s Tier-2 rotation calendar; `Twilio--AccountSid` is either listed or its non-rotation exception is documented per invariant 20
- [ ] `HoneyDrunk.Notify.Providers.Sms.Twilio/README.md` includes the five sections (D2 declaration with tentative note, re-evaluation triggers verbatim, webhook intake, rotation, TCPA/SMS-marketing discipline)
- [ ] `HoneyDrunk.Notify.Providers.Sms.Twilio/CHANGELOG.md` has a `[0.3.1]` entry with the hardening changes
- [ ] Repo-level `CHANGELOG.md`'s `[0.3.1]` entry includes a Twilio production-hardening summary line **appended** (not a new dated section)
- [ ] `repos/HoneyDrunk.Notify/overview.md` has a `## SMS Provider (ADR-0073 D2 — Tentative)` section (or — if the cross-repo split path is chosen — a parallel Architecture-side packet is filed for the overview edit)
- [ ] No new version bump in this packet — `.csproj` files remain at `0.3.1` from packet 01. If packet 01 has not landed at execution time, this packet bumps in its stead (state the chosen path in the PR)
- [ ] Unit + integration tests verify signature-valid / signature-invalid / event-routing paths; no `Thread.Sleep`
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Twilio status-callback URL configured** in the Twilio console for each environment's Messaging Service, pointing at the appropriate `/internal/webhooks/twilio` URL.
- [ ] **`Twilio--AuthToken` and `Twilio--AccountSid` already seeded** in `kv-hd-notify-{env}` from prior Notify operational work; confirm presence before deploying the webhook route.
- [ ] **Tier-2 rotation calendar updated** if the calendar configuration lives in `HoneyDrunk.Vault.Rotation` rather than this repo — file a parallel Vault.Rotation packet if necessary.
- [ ] **No NuGet tag is pushed by this packet alone.** This packet appends to the in-progress `0.3.1` release. The tag push happens once all `0.3.1` packets (this one plus packet 01) have landed on `main` — a human pushes the tag at that point.

## Referenced ADR Decisions
**ADR-0073 D2 — Twilio is the default SMS provider (tentative).** "Twilio is the canonical SMS provider for HoneyDrunk.Notify's `ISmsSender` slot. The commitment is marked **tentative** and is re-evaluated at the first cost-pressure inflection. `HoneyDrunk.Notify.Providers.Twilio` — the `ISmsSender` implementation. Account credentials in Vault per ADR-0005 — same namespace as Resend. Per-region number management is a Notify-internal concern; tenants do not bring their own numbers at MVP. Webhook-driven delivery events (delivered, failed, queued) deliver into Notify's intake per ADR-0062. TCPA / SMS-marketing discipline is a per-PDR consumer-app concern; Notify does not enforce it at the provider layer."

**ADR-0073 D2 — Re-evaluation triggers.**
- "First month with SMS spend > $200. At that point, run a cost comparison against MessageBird and Plivo for the same workload mix. Switch if the savings justify the migration cost (a one-PR adapter swap behind `ISmsSender`)."
- "A specific tenant-driven requirement (regulatory, country-specific) that another provider serves better."
- "A Twilio stewardship event (pricing change, hostile policy, API instability) that breaks trust."
- "Until a trigger fires, Twilio is the default."

**ADR-0073 §Operational Consequences.** "Twilio cost is workload-dependent. No SMS volume today; the cost grows linearly with send volume. The D2 re-evaluation trigger at $200/mo catches the inflection."

**ADR-0006 §Tier 2.** Third-party provider credentials rotate via `HoneyDrunk.Vault.Rotation` Function App on ≤90-day cadence; new versions land in `kv-hd-notify-{env}`; Event Grid cache invalidation propagates per ADR-0005. Per invariant 21, applications never pin to a specific secret version.

## Constraints
- **Invariant 12 — Per-package CHANGELOGs are updated only for packages with functional changes.** Only `HoneyDrunk.Notify.Providers.Sms.Twilio` (and the core `HoneyDrunk.Notify` if the webhook route lives there) gets a per-package CHANGELOG entry. Every other package has `.csproj` already aligned by packet 01 and gets no entry.
- **Invariant 15 — Unit tests and in-process integration tests never depend on external services.** Webhook intake tests use in-process fakes for `ISecretStore` and any HTTP dispatch. No live Twilio calls.
- **Invariant 20 — Tier 2 ≤ 90 days rotation SLA.** Twilio Auth Token rotates within 90 days. Twilio Account SID's non-rotation is documented as an exception.
- **Invariant 21 — Applications must never pin to a specific secret version.** The Twilio provider reads the latest version of `Twilio--AuthToken` on every send / verify call.
- **Invariant 27 — All projects in a solution share one version and move together.** Already at `0.3.1` from packet 01; no further bump in this packet.
- **Invariant 51 — Test code contains no `Thread.Sleep`.**
- **D5 — Default is not exclusive.** Per-tenant override seam preserved. Do not change the resolver to hard-favor Twilio.
- **Tentative-commitment note is verbatim.** The re-evaluation-trigger block in the Twilio README quotes ADR-0073 D2 verbatim so the operator sees the same text the ADR commits — not a paraphrase.
- **Test project naming.** Same as packet 01 — keep `HoneyDrunk.Notify.Tests` and `HoneyDrunk.Notify.IntegrationTests`; the `.Tests.Unit` rename is a separate ADR-0047 follow-up.

## Labels
`feature`, `tier-2`, `ops`, `adr-0073`, `wave-2`

## Agent Handoff

**Objective:** Production-harden the Twilio SMS provider per ADR-0073 D2: webhook intake (ADR-0062), Tier-2 rotation registration (ADR-0006), tentative-commitment note in package README and Notify overview. Appends to packet 01's `[0.3.1]` CHANGELOG entry; no further version bump.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Confirm Twilio as the canonical default `ISmsSender` (tentative) and complete the production-hardening obligations.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 2.
- ADRs: ADR-0073 D2 (primary); ADR-0062 (webhook verification); ADR-0006 (Tier-2 rotation); ADR-0005 (Vault config).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0073 is Accepted.
- `work-item:01` — Resend hardening lands the `[0.3.1]` repo-level CHANGELOG entry that this packet appends to.

**Constraints:**
- No version bump — packet 01 already bumped to `0.3.1`. State the chosen path explicitly if packet 01 has not yet landed at execution time.
- Append (do not create new section) in repo-level CHANGELOG.
- Tentative-commitment text in the Twilio README quotes ADR-0073 D2 verbatim.
- TCPA / SMS-marketing discipline stays outside Notify per ADR-0073 D2 (per-PDR concern).
- Webhook intake uses Twilio's `X-Twilio-Signature` scheme; fail-closed on missing or invalid signature.

**Key Files:**
- `HoneyDrunk.Notify/Intake/` — new webhook route.
- `HoneyDrunk.Notify.Providers.Sms.Twilio/README.md` and `CHANGELOG.md`.
- Repo-level `CHANGELOG.md` (append).
- `repos/HoneyDrunk.Notify/overview.md` (cross-repo — see Scope note).
- Test projects.

**Contracts:** None changed.
