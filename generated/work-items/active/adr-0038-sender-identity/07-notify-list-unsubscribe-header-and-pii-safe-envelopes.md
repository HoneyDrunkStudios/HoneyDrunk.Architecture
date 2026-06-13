---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0038", "wave-3"]
dependencies: ["work-item:05"]
adrs: ["ADR-0038"]
accepts: ["ADR-0038"]
wave: 3
initiative: adr-0038-sender-identity
node: honeydrunk-notify
---

# Emit RFC 8058 one-click List-Unsubscribe headers and enforce PII-safe outbound envelopes

## Summary
Implement the two ADR-0038 outbound-header rules in the `HoneyDrunk.Notify` email path: emit RFC 8058 one-click `List-Unsubscribe` / `List-Unsubscribe-Post` headers on bulk and platform sends (and best-effort on transactional sends) per D6, and enforce that outbound envelopes carry no tenant-identifying information beyond the opaque ESP subaccount identifier per D9.

## Context
ADR-0038 commits two outbound-header rules that are Notify delivery-mechanics concerns:

**D6 — List-Unsubscribe.** "Unsubscribes are part of suppression. List-Unsubscribe (one-click, RFC 8058) is mandatory on bulk sends and on every Notify Cloud platform send. Transactional sends are exempt by RFC but Notify still emits the header for safety." This is also one of the two invariants ADR-0038 adds (landed in packet 00): "bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe."

**D9 — Privacy and PII in headers.** "Outbound message envelopes (`Message-ID`, `Return-Path`, custom headers added by Notify) must not contain tenant-identifying information beyond the opaque per-tenant subaccount identifier from the ESP. A tenant's recipient should not be able to enumerate other tenants by inspecting headers. Headers used for support correlation (`X-Notify-Message-Id`) are opaque tokens, not concatenated `tenant-id:message-id` strings."

Both rules live in Notify's email delivery path — Notify owns delivery mechanics (invariant 41). RFC 8058 one-click unsubscribe requires two headers: `List-Unsubscribe` with a `mailto:` and/or `https:` URI, and `List-Unsubscribe-Post: List-Unsubscribe=One-Click`. The HTTPS endpoint a recipient's one-click hits must, when invoked, produce an `Unsubscribed` `DeliverabilityEvent` that flows into the packet-06 suppression path — that closes the loop D6 describes. This packet emits the headers and ensures the unsubscribe action produces a `DeliverabilityEvent`; it depends on packet 05 for the `DeliverabilityEvent` type.

The PII-safe-envelope rule is a constraint on every header Notify adds. `X-Notify-Message-Id` must be an opaque token (e.g. a ULID or a hashed/random identifier) — never `{tenant-id}:{message-id}`. The opaque token must still be reversible *internally* for support correlation (Notify can look up the real message from the token) but must not be a parseable concatenation.

## Scope
- `HoneyDrunk.Notify` runtime — the email-send header construction path.
- `HoneyDrunk.Notify.Abstractions` — only if a send-classification flag (bulk vs transactional vs platform) does not already exist on the request/envelope model and one must be added to drive the mandatory-vs-best-effort header rule. Reconcile with the existing `NotificationRequest` / `NotificationEnvelope` / `EmailEnvelope` / `NotificationPriority` types first.
- The unsubscribe HTTPS endpoint handler — whichever Notify hosting surface (`HoneyDrunk.Notify.Functions` or `HoneyDrunk.Notify.Hosting.AspNetCore`) is the right home for the one-click `List-Unsubscribe-Post` target.

## Proposed Implementation
1. **Send classification.** Determine bulk vs transactional vs platform. Check the existing `NotificationRequest` / `EmailEnvelope` / `NotificationPriority` models first — if a classification already exists, reuse it. If not, add a minimal `SendClass` (or similar) enum to the Abstractions package: `Transactional`, `Bulk`, `Platform`. Per the Grid abstractions-versioning convention, use `init` members; per the naming rule it is an enum, no `I` prefix.
2. **List-Unsubscribe headers.** In the email-send path, add:
   - `List-Unsubscribe` — a header with the unsubscribe `https:` URI (the one-click endpoint) and optionally a `mailto:` fallback.
   - `List-Unsubscribe-Post: List-Unsubscribe=One-Click` — required by RFC 8058 for the one-click variant.
   - Emit both **mandatorily** on `Bulk` and `Platform` sends; emit them **best-effort** on `Transactional` sends (D6: "Notify still emits the header for safety").
   - The unsubscribe URI must itself be PII-safe per D9 — an opaque token, not a parseable `{tenant}:{recipient}` URL.
3. **One-click endpoint.** Implement (or wire) the HTTPS endpoint the `List-Unsubscribe` URI targets. A `POST` with `List-Unsubscribe=One-Click` body resolves the opaque token to `(TenantId, recipient, MessageId)` internally and produces an `Unsubscribed` `DeliverabilityEvent`, handed to the `IDeliverabilityFeedbackSink` (packet 06's default backing records the suppression). The endpoint must accept the RFC 8058 one-click POST without requiring the recipient to be authenticated or to land on a confirmation page.
4. **PII-safe envelope enforcement (D9).** Audit every header Notify adds to an outbound message — `Message-ID`, `Return-Path`, `X-Notify-Message-Id`, and any other custom `X-` header:
   - `X-Notify-Message-Id` (and any correlation header) must be an opaque token. If the current implementation concatenates `tenant-id` and `message-id`, change it to an opaque token with an internal lookup.
   - No header may contain a tenant id, tenant name, recipient enumeration data, or other tenant-identifying information beyond the ESP's opaque subaccount identifier.
   - Add a unit test asserting that a rendered outbound envelope's headers contain no raw `TenantId` value.
5. **Tests** — unit tests in `HoneyDrunk.Notify.Tests`: bulk and platform sends carry both List-Unsubscribe headers; transactional sends carry them too (best-effort); the unsubscribe URI is opaque; outbound headers contain no raw tenant identifier. An integration test in `HoneyDrunk.Notify.IntegrationTests` covers the one-click `POST` → `Unsubscribed` `DeliverabilityEvent` flow end to end. No `Thread.Sleep` (invariant 51).
6. **Version + CHANGELOG.** Packet 05 bumped the solution version for this initiative. Per invariant 27, append to the in-progress version's CHANGELOG entry — repo-level and the affected per-package changelogs (runtime, and Abstractions only if the `SendClass` enum was added). No new version bump. Update the relevant `README.md` if the public API surface changed (a new `SendClass` enum on the request model would qualify — invariant 12).

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify/` — email-send header construction (the runtime has `Routing/` and `Templates/` directories; header assembly lands in whichever is the actual rendering path — confirm against the source).
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/` or `HoneyDrunk.Notify.Hosting.AspNetCore/` — the one-click unsubscribe endpoint.
- `HoneyDrunk.Notify.Abstractions/` — a `SendClass` enum, only if no existing classification fits.
- `HoneyDrunk.Notify.Tests` and `HoneyDrunk.Notify.IntegrationTests` projects.
- Repo-level `CHANGELOG.md` (append) and the affected per-package `CHANGELOG.md` files; affected `README.md`.

## NuGet Dependencies
No new `PackageReference` entries expected — header construction and an HTTP endpoint use the runtime's existing email path and hosting dependencies. If the one-click endpoint needs a hosting surface the chosen project does not already reference, **stop and flag** rather than guessing (invariant 26). `HoneyDrunk.Standards` is already on every project; `.Tests` projects use the existing ADR-0047 stack.

## Boundary Check
- [x] List-Unsubscribe headers and outbound-envelope construction are email delivery mechanics — `HoneyDrunk.Notify` owns delivery mechanics (invariant 41).
- [x] The one-click unsubscribe producing a `DeliverabilityEvent` reuses the packet-05 contract and the packet-06 suppression backing — no parallel suppression path.
- [x] D9 PII-safe headers is a Notify-internal envelope concern — no cross-Node contract change.
- [x] Any `SendClass` addition is an Abstractions-package enum — invariant 1 holds (no runtime dependency).

## Acceptance Criteria
- [ ] Bulk and platform email sends carry both `List-Unsubscribe` and `List-Unsubscribe-Post: List-Unsubscribe=One-Click` headers (RFC 8058)
- [ ] Transactional sends carry the List-Unsubscribe headers best-effort per D6
- [ ] The `List-Unsubscribe` URI is an opaque token, not a parseable `{tenant}:{recipient}` URL
- [ ] A one-click `POST` to the unsubscribe endpoint produces an `Unsubscribed` `DeliverabilityEvent` routed to `IDeliverabilityFeedbackSink`; the endpoint accepts the RFC 8058 POST without recipient authentication
- [ ] `X-Notify-Message-Id` and every custom header Notify adds is an opaque token — no concatenated `tenant-id:message-id`
- [ ] A unit test asserts a rendered outbound envelope's headers contain no raw `TenantId` value (D9)
- [ ] Unit tests in `HoneyDrunk.Notify.Tests` cover header presence per send class; an integration test in `HoneyDrunk.Notify.IntegrationTests` covers the one-click → `DeliverabilityEvent` flow
- [ ] Test code contains no `Thread.Sleep` (invariant 51)
- [ ] The solution builds; all tests in `HoneyDrunk.Notify.Tests` and `HoneyDrunk.Notify.IntegrationTests` pass
- [ ] Repo-level and affected per-package `CHANGELOG.md` files append to the in-progress version entry (no new bump); affected `README.md` reflects any public API change

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0038 D6 — Bounce, complaint, and unsubscribe handling.** "Unsubscribes are part of suppression. List-Unsubscribe (one-click, RFC 8058) is mandatory on bulk sends and on every Notify Cloud platform send. Transactional sends are exempt by RFC but Notify still emits the header for safety."

**ADR-0038 D9 — Privacy and PII in headers.** "Outbound message envelopes (`Message-ID`, `Return-Path`, custom headers added by Notify) must not contain tenant-identifying information beyond the opaque per-tenant subaccount identifier from the ESP. A tenant's recipient should not be able to enumerate other tenants by inspecting headers. Headers used for support correlation (`X-Notify-Message-Id`) are opaque tokens, not concatenated `tenant-id:message-id` strings."

**ADR-0038 Consequences — Invariants.** "Bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe. Transactional sends emit it as best practice." (Landed as an invariant in packet 00.)

## Constraints
> **Invariant (added by packet 00) — bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe; transactional sends emit it as best practice.** This packet is the enforcement point for that invariant.

> **Invariant 41 — Delivery mechanics live in Notify.** Header construction and envelope assembly are delivery mechanics — they belong in Notify, not Communications.

> **Invariant 1 — Abstractions packages have zero HoneyDrunk runtime dependencies.** Any `SendClass` enum added to `HoneyDrunk.Notify.Abstractions` must not pull in a runtime dependency.

> **Invariant 51 — Test code contains no `Thread.Sleep`.** Async work waits via `await`, polling primitives with explicit timeouts, or synchronously-completing fakes. `Thread.Sleep` is a CI flakiness multiplier; enforced by an analyzer rule on test projects.

- **One-click means one-click.** RFC 8058 requires the `POST` to unsubscribe directly — no confirmation page, no login. The endpoint must honor this.
- **Opaque tokens, not concatenations.** Every Notify-added header and the unsubscribe URI must be an opaque token reversible only by an internal lookup — never a parseable tenant/recipient concatenation (D9).
- **No new version bump.** Append to packet 05's in-progress CHANGELOG entry.
- **Reconcile before adding `SendClass`.** Check `NotificationRequest` / `EmailEnvelope` / `NotificationPriority` for an existing send-class concept before adding an enum.

## Labels
`feature`, `tier-2`, `ops`, `adr-0038`, `wave-3`

## Agent Handoff

**Objective:** Emit RFC 8058 one-click List-Unsubscribe headers on bulk/platform/transactional email sends, wire the one-click endpoint to produce an `Unsubscribed` `DeliverabilityEvent`, and enforce PII-safe outbound envelopes.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Land the two ADR-0038 outbound-header rules (D6 List-Unsubscribe, D9 PII-safe envelopes) in Notify's email path.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 3.
- ADRs: ADR-0038 D6 / D9 (primary); the packet-00 List-Unsubscribe invariant.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:05` — hard. The one-click endpoint produces an `Unsubscribed` `DeliverabilityEvent`, so the `DeliverabilityEvent` type must exist. (Packet 06's suppression backing records the event; this packet can run in parallel with 06 since it only needs the type, not the backing — but ordering both after 05 is correct.)

**Constraints:**
- One-click = RFC 8058 direct POST, no confirmation page, no login.
- Opaque tokens for every Notify-added header and the unsubscribe URI — no tenant/recipient concatenation (D9).
- `SendClass` enum, if added, is an Abstractions enum — invariant 1.
- No `Thread.Sleep` in tests (invariant 51).
- No new version bump — append to packet 05's in-progress CHANGELOG entry.

**Key Files:**
- `HoneyDrunk.Notify/HoneyDrunk.Notify/Routing/` or `Templates/` — header construction
- `HoneyDrunk.Notify.Functions/` or `HoneyDrunk.Notify.Hosting.AspNetCore/` — one-click endpoint
- `HoneyDrunk.Notify.Abstractions/` — conditional `SendClass` enum
- `HoneyDrunk.Notify.Tests` / `HoneyDrunk.Notify.IntegrationTests` projects
- Repo-level + affected per-package `CHANGELOG.md`; affected `README.md`

**Contracts:**
- Consumes `DeliverabilityEvent` (from packet 05).
- Conditionally adds a `SendClass` enum to `HoneyDrunk.Notify.Abstractions`.
