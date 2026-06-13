---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0073", "wave-1"]
dependencies: []
adrs: ["ADR-0073"]
accepts: ["ADR-0073"]
wave: 1
initiative: adr-0073-notify-providers
node: honeydrunk-architecture
---

# Accept ADR-0073 — amend D3 provider naming and record npm-templates deferral

## Summary
Flip ADR-0073 (Notify Default Providers — Resend / Twilio / Expo) from Proposed to Accepted: update the ADR header, add the ADR-0073 row to `adrs/README.md`, register the `adr-0073-notify-providers` initiative in `initiatives/active-initiatives.md`, **amend D3** to channel-scoped provider naming (`HoneyDrunk.Notify.Providers.Push.Expo`), and record the `@honeydrunk/notify-templates` npm-templates standup deferral as a Required Decision in the ADR. ADR-0073 adds **no new invariants** (its §Consequences / Invariants section is explicit on that point) — `constitution/invariants.md` is **not** modified.

## Context
ADR-0073 commits the canonical default providers for HoneyDrunk.Notify's three channels — Resend (email, D1), Twilio (SMS, D2, tentative), Expo Notifications (push, D3) — plus react-email as the templating choice (D4) that pairs with the email default. The provider abstraction (`IEmailSender` / `ISmsSender` / future `IPushSender`) is preserved; per-tenant and per-PDR overrides remain allowed but discouraged (D5).

ADR-0073's decisions:

- **D1 — Resend is the default email provider.** `HoneyDrunk.Notify.Providers.Email.Resend` (the existing package, already shipping at v0.3.0) fills the `IEmailSender` slot. API key in Vault per ADR-0005 (`kv-hd-notify-{env}` namespace), rotated per ADR-0006 Tier 2. Sender-identity discipline per ADR-0038. Webhook-driven deliverability events per ADR-0062.
- **D2 — Twilio is the default SMS provider (tentative; re-evaluate at first cost-pressure inflection).** `HoneyDrunk.Notify.Providers.Sms.Twilio` (existing) fills the `ISmsSender` slot. Account credentials in Vault. Webhook delivery events per ADR-0062. Re-evaluation trigger: first month with SMS spend > $200, or specific tenant-driven requirement, or a Twilio stewardship event.
- **D3 — Expo Notifications is the default push provider.** New `HoneyDrunk.Notify.Providers.Push.Expo` package (per **D3 amendment**, see below) implementing `IPushSender`. Expo Push Tokens are the addressable identifier. Expo Access Tokens in Vault. Receipt-driven delivery confirmation via Expo's receipts API.
- **D4 — Email templating uses react-email.** `@react-email/components` for component authoring. Templates live in `HoneyDrunk.Notify.Templates` (new package — **deferred to a standup ADR**, see below). Per-consumer-PDR templates consume react-email components from the Notify Templates package for consistency. Render at send time (consumer-side); Notify is HTML-in. Tokens and design system from Web.UI per ADR-0071.
- **D5 — Provider abstraction is held; defaults are not exclusive bindings.** Per-tenant override permitted (Notify Cloud BYO-provider seam). Per-PDR override permitted but discouraged. Node-level default enforced at packet scaffolding.
- **D6 — Out of scope.** Sender-identity policy (owned by ADR-0038); per-region provider variation; tenant-BYO provider tooling; outbound-rate-limiting; bounce/complaint policy (Communications-side); MMS/RCS; in-app toasts; outbound webhooks.

ADR-0073 §Consequences / Invariants is explicit:

> No new Grid-wide invariants introduced. Conventions enforced at packet authoring and review.

This packet does **not** edit `constitution/invariants.md` and does **not** reserve a number from the pre-allocated batch.

## D3 amendment — channel-scoped provider naming

ADR-0073 D3 names the push package `HoneyDrunk.Notify.Providers.Expo`. The Grid's existing per-channel provider naming (already in the `HoneyDrunk.Notify` repo on disk) uses **channel-scoped** naming:

- `HoneyDrunk.Notify.Providers.Email.Resend` (exists today, v0.3.0)
- `HoneyDrunk.Notify.Providers.Email.Smtp` (exists today, v0.3.0)
- `HoneyDrunk.Notify.Providers.Sms.Twilio` (exists today, v0.3.0)

The ADR's D3 wording (`Providers.Expo`) is inconsistent with the established channel-scoped pattern. **This packet amends D3** to `HoneyDrunk.Notify.Providers.Push.Expo` — channel-scoped, parallel to email/sms. The amendment is recorded inline in D3 with a dated note (no full revision history block — the ADR was Proposed when amended, not yet Accepted, so the amendment is an authorship correction).

D1 and D2's descriptive phrasings in the ADR (`Providers.Resend` / `Providers.Twilio`) are similarly informal but the existing packages already ship under their channel-scoped names. **No amendment to D1 or D2 is required** — the shipped code is authoritative; the ADR's descriptive phrasing is informally aligned without an explicit revision line.

## Deferred — `@honeydrunk/notify-templates` npm-templates standup

ADR-0073 D4 commits react-email as the canonical email-templating library and pins the canonical template set's home as `HoneyDrunk.Notify.Templates` (mentioned in §Consequences / Affected Nodes). react-email is a TypeScript/JSX library that lives in the npm ecosystem; `HoneyDrunk.Notify` is a .NET repo. The canonical template set is therefore an **npm package living inside a .NET repo** (a polyglot package: react-email source in `templates/`, rendered HTML output potentially consumed by .NET via a sibling library or via build-time emission).

The packaging shape, build pipeline, publish destination (npmjs.org under `@honeydrunk` scope per ADR-0034 patterns), and consumer-PDR template-extension model are non-trivial decisions warranting their own standup ADR — parallel to how `HoneyDrunk.Cache` got ADR-0059 paired with ADR-0058's contract decision. Per the user's standing convention ("new-Node scaffolding gets its own standup ADR; don't bundle scaffold into feature packets"), **packet 03 in this initiative is deferred** with a placeholder until the standup ADR (provisionally `ADR-0073a-notify-templates-npm-standup`, number to be assigned at draft time) is drafted and accepted.

This packet records the deferral in the ADR's Follow-up Work section so the open question is visible from the ADR text and not hidden in the dispatch plan only.

## Scope
- `adrs/ADR-0073-notify-default-providers.md` — flip `**Status:** Proposed` → `**Status:** Accepted`. Amend D3 to channel-scoped `Providers.Push.Expo` naming with a dated note. Append a "Deferred — Required Decision: notify-templates npm-package standup" entry under Follow-up Work.
- `adrs/README.md` — add the ADR-0073 row (Status: Accepted, Date: 2026-05-25, Sector: Ops, with the impact summary).
- `initiatives/active-initiatives.md` — register the `adr-0073-notify-providers` initiative under `## In Progress` with the packet tracking checklist (10 packets, 4 waves).
- `constitution/invariants.md` — **NOT modified.** ADR-0073 adds no new invariants.

## Proposed Implementation
1. **Edit the ADR-0073 header**: `**Status:** Proposed` → `**Status:** Accepted`. Keep the original `**Date:** 2026-05-23` (the original drafting date); add a separate dated note in the D3 amendment block (next step).
2. **Amend D3** — inside the D3 section, edit the bullet that names the package:
   - **From:** `**HoneyDrunk.Notify.Providers.Expo** (new package, ships when push lands) — the IPushSender implementation.`
   - **To:** `**HoneyDrunk.Notify.Providers.Push.Expo** (new package, ships when push lands) — the IPushSender implementation. *(Amended 2026-05-25 from the original "HoneyDrunk.Notify.Providers.Expo" to align with the Grid's channel-scoped provider naming used by HoneyDrunk.Notify.Providers.Email.Resend, HoneyDrunk.Notify.Providers.Email.Smtp, and HoneyDrunk.Notify.Providers.Sms.Twilio.)*`
3. **Append the deferral entry to §Follow-up Work** — add a new line:
   - `Deferred — Required Decision: HoneyDrunk.Notify.Templates / @honeydrunk/notify-templates polyglot npm-package standup ADR. The canonical react-email template set named in D4 is a polyglot npm package inside a .NET repo; the packaging shape, build pipeline, npm publish destination, and consumer-PDR template-extension model warrant a standup ADR. Until that ADR lands, react-email is the committed library but the canonical template set does not ship; email sends compose HTML consumer-side however the consuming Node already does (today: Notify's existing template renderer).`
4. **Add the ADR-0073 row to `adrs/README.md`** — append after the most recent row. Use the same `| ID | Title | Status | Date | Sector | Impact |` shape. Suggested row text:
   - `| [ADR-0073](ADR-0073-notify-default-providers.md) | Notify Default Providers — Resend (Email), Twilio (SMS), Expo (Push) | Accepted | 2026-05-23 | Ops | Canonical default providers for HoneyDrunk.Notify's three channels: Resend (email, D1), Twilio (SMS, D2, tentative pending first cost-pressure inflection), Expo Notifications (push, D3, channel-scoped Providers.Push.Expo package). react-email as the canonical email-templating library (D4) pairing with the Resend default. Provider abstraction held — per-tenant and per-PDR overrides allowed but discouraged (D5). No new Grid-wide invariants. Sender-identity (ADR-0038), webhook intake (ADR-0062), and Tier-2 rotation (ADR-0006) discipline applied to all three providers from their existing ADRs. HoneyDrunk.Notify.Templates / @honeydrunk/notify-templates npm-package standup deferred to its own follow-up ADR. |`
5. **Register the initiative in `initiatives/active-initiatives.md`** under `## In Progress` with the wave structure and packet checklist for this folder. Match the existing entry-shape used by sibling initiatives (`adr-0058-caching-strategy`, `adr-0067-rate-limiting`): an `### ADR-0073 Notify Default Providers` heading, Status / Scope / Initiative / Board / Description fields, and a Tracking checklist of the 9 packets in this folder split across 4 waves (per dispatch-plan.md). Use the file naming as the canonical packet references; GitHub issue numbers backfill via `hive-sync` after filing.
6. **Do NOT modify `constitution/invariants.md`.** ADR-0073 §Consequences / Invariants is explicit: no new Grid-wide invariants. The conventions stated there (email defaults to Resend, SMS to Twilio, push to Expo, react-email-no-raw-HTML, Vault for credentials) are enforced at packet authoring and review — not as numbered invariants.

## Affected Files
- `adrs/ADR-0073-notify-default-providers.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0073 header reads `**Status:** Accepted`
- [ ] ADR-0073 D3 names the push package `HoneyDrunk.Notify.Providers.Push.Expo` with the dated amendment note inline
- [ ] ADR-0073 §Follow-up Work contains the `@honeydrunk/notify-templates` standup-deferral line
- [ ] `adrs/README.md` has a new row for ADR-0073 with Status: Accepted, Sector: Ops, and a one-paragraph impact summary
- [ ] `initiatives/active-initiatives.md` registers the `adr-0073-notify-providers` initiative under `## In Progress` with the 9-packet tracking checklist split across 4 waves
- [ ] `constitution/invariants.md` is **NOT** modified
- [ ] No catalog schema change in this packet (no edits to `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json`)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0073 §Consequences / Invariants.** "No new Grid-wide invariants introduced. Conventions enforced at packet authoring and review: Email sends use Resend by default. Alternative providers require justification. SMS sends use Twilio by default. Tentative; re-evaluation triggers per D2. Push sends use Expo Notifications by default. Email templates use react-email; raw HTML email is not authored by hand. Provider credentials live in Vault per ADR-0005."

**ADR-0073 §Follow-up Work.** "Ship `HoneyDrunk.Notify.Providers.Resend` package (Notify-side packet, with Vault wiring and webhook intake). Ship `HoneyDrunk.Notify.Templates` package with the canonical react-email template set. Migrate or retire any legacy SendGrid adapter sketches. Ship `HoneyDrunk.Notify.Providers.Twilio` package when the first SMS-needing PDR pulls on it. Ship `HoneyDrunk.Notify.Providers.Expo` package when the first mobile-PDR push-flow pulls on it. Identity verification-email flow per ADR-0060 Phase 2 lands on Resend. Notify Cloud GA documentation includes the per-tenant provider-override mechanism per D5. Re-evaluation calendar: track Twilio monthly spend; the D2 trigger fires the cost comparison. Watch list: Resend stewardship continues; Twilio pricing curve; Expo's stewardship under its current ownership."

**ADR-0073 D5 — Provider abstraction is held; defaults are not exclusive bindings.** Per-tenant override permitted. Per-PDR override permitted but discouraged. Node-level default enforced at scaffolding.

## Constraints
- **Acceptance precedes implementation.** ADR-0073 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **No invariant edits.** ADR-0073 §Consequences / Invariants is explicit: no new invariants. Do not append placeholder text to `constitution/invariants.md`. Do not reserve a number for ADR-0073 in the pre-reservation batch.
- **D3 amendment is the only structural correction.** D1 and D2 phrasings remain as written; the shipped code names (`Providers.Email.Resend`, `Providers.Sms.Twilio`) are authoritative against the ADR's informal descriptions. Only D3 needed correction because the package does not yet exist.
- **`@honeydrunk/notify-templates` package does not ship in this initiative.** Packet 03 records the deferral; no code work happens until the standup ADR lands. Email sends in this initiative use the existing Notify template renderer.
- **No constitution row reserved for ADR-0073.** ADR-0073 is excluded from any invariant pre-reservation; if at execution time the user decides ADR-0073 should have a numbered invariant (e.g. "no raw HTML email") that is a separate amendment + new acceptance packet, not a silent append from this packet.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0073`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0073 to Accepted, amend D3 to channel-scoped naming, record the npm-templates deferral, and register the initiative. No invariant edits.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0073 so the remaining packets (Resend production hardening, Twilio production hardening, Expo push provider standup, override-policy doc, npm-templates deferral) can reference its decisions as live rules.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 1.
- ADRs: ADR-0073 (primary); ADR-0019 (Notify/Communications boundary — provider selection is a Notify concern); ADR-0027 (Notify Cloud — first commercial consumer of the defaults, Proposed); ADR-0038 (sender identity, Proposed — discipline applied to Resend); ADR-0062 (webhook verification — discipline applied to all three providers' delivery callbacks); ADR-0006 (Tier-2 rotation — applied to all three providers' credentials).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- ADR-0073 stays Proposed until this PR merges.
- **No invariant edits** — ADR-0073 adds no new Grid-wide invariants. Do not append placeholder text; do not reserve a batch number.
- **D3 amendment must use the exact channel-scoped name** `HoneyDrunk.Notify.Providers.Push.Expo` (Push capitalized as a channel segment, mirroring `.Email.` and `.Sms.`).
- The npm-templates deferral entry in §Follow-up Work must be explicit about the open questions: polyglot packaging shape, build pipeline, npm publish destination, consumer-PDR extension model.

**Key Files:**
- `adrs/ADR-0073-notify-default-providers.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
