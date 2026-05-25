# Dispatch Plan — ADR-0073: Notify Default Providers (Resend / Twilio / Expo)

**Initiative:** `adr-0073-notify-providers`
**ADR:** ADR-0073 (Proposed → Accepted via packet 00)
**Sector:** Ops
**Created:** 2026-05-25

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0073 commits the **canonical default providers** for each of HoneyDrunk.Notify's three channel slots — Resend (email, D1), Twilio (SMS, D2, tentative), Expo Notifications (push, D3) — plus the **react-email templating choice** that pairs with the email default (D4). The provider abstraction (`IEmailSender` / `ISmsSender` / future `IPushSender`) is preserved; per-tenant and per-PDR overrides remain allowed but discouraged (D5). The ADR introduces **no new Grid-wide invariants** (§Consequences / Invariants is explicit on that point — only conventions enforced at packet authoring / review).

The initiative ships, in **9 packets across 4 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Notify`):

1. **Packet 00** — ADR acceptance (status flip, README index row, initiative registration, ADR amendment to D3 — see "Required ADR Amendment" below).
2. **Packet 01** — Email production hardening of the existing `HoneyDrunk.Notify.Providers.Email.Resend` package (Resend is already the wired Email provider but the ADR-0073 wiring obligations — webhook intake per ADR-0062, DKIM/SPF/DMARC handoff per ADR-0038, Tier-2 rotation per ADR-0006 — are not all in place). **Version-bumping packet for Notify** (rolls existing `[Unreleased]` into `[0.3.1]`).
3. **Packet 02** — Sender-identity wiring confirmation in Architecture — cross-references ADR-0038's DKIM/SPF/DMARC discipline from `repos/HoneyDrunk.Notify/overview.md` (not duplicating ADR-0038's work; pointing at it).
4. **Packet 03 — DEFERRED** — `@honeydrunk/notify-templates` polyglot npm-templates standup placeholder. Records the deferral; no code ships. The canonical react-email template set's standup gets its own ADR; this packet creates the deferral document.
5. **Packet 04** — SMS production hardening of the existing `HoneyDrunk.Notify.Providers.Sms.Twilio` package (D2 wiring obligations parallel to packet 01 — webhook intake, Tier-2 rotation; tentative-commitment note recorded in package README and in repo overview).
6. **Packet 05** — Notify Cloud per-tenant override policy specification — handoff to ADR-0027 standup (Notify Cloud repo does not yet exist; this initiative authors the spec in Architecture's `business/context/`).
7. **Packet 06** — Push — `IPushSender` contract in `HoneyDrunk.Notify.Abstractions` + `NotificationChannel.Push = 2` enum addition. **Version-bumping packet to `0.4.0`.** **Provider-package naming uses channel-scoping** (`Providers.Push.Expo`, parallel to the existing `Providers.Email.Resend` / `Providers.Sms.Twilio`) — this reconciles a naming mismatch in ADR-0073 D3. **Packet 00 amends D3 to channel-scoped naming** so the package shipped in packet 07 matches the rest of the Grid.
8. **Packet 07** — Ship `HoneyDrunk.Notify.Providers.Push.Expo` package implementing `IPushSender` against Expo's Push API. Vault-backed Expo Access Token. Captures Expo ticket-IDs for packet 08's receipts poll.
9. **Packet 08** — Expo Push Receipts poll-and-intake seam in `HoneyDrunk.Notify.Worker` + minimal `PushTokenRegistration` record in Abstractions for consumer-PDR token registration.

**9 packets total. All `Actor=Agent`, 0 `Actor=Human`.** No `human-only` label. Some packets carry Human Prerequisites (vault secrets for Resend/Twilio/Expo, DKIM record creation, Expo project creation) but the code work itself is delegable.

## Trigger

ADR-0073 is Proposed with no execution scope. Forcing functions from the ADR's Context:

- **Notify Cloud GA (PDR-0002, ADR-0027)** needs a production-grade email provider day one and a production-grade SMS provider when the first tenant requests SMS sends.
- **Identity verification flows (ADR-0060 Phase 2)** route verification emails through Communications → Notify with Resend underneath.
- **Consumer-app PDRs (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0008 Curiosities)** all require push notifications. Per ADR-0070 D3 the mobile platform is React Native + Expo; Expo's push pipeline is the natural alignment.
- Without canonical defaults, every consumer PDR re-derives the provider choice (the wrong shape per ADR-0019 — provider selection is a Notify concern, not a Communications-consumer concern).

## Scope Detection

**Multi-repo, two repos.** All code work lands in `HoneyDrunk.Notify` (the affected Node per ADR-0073 §Consequences / Affected Nodes). Governance, override-policy doc, npm-templates standup deferral, and ADR amendment land in `HoneyDrunk.Architecture`.

**No new Grid-wide invariants.** ADR-0073 §Consequences / Invariants is explicit:

> No new Grid-wide invariants introduced. Conventions enforced at packet authoring and review.

This initiative does **not** edit `constitution/invariants.md` and does **not** reserve a number from the pre-allocated batch.

**No new Node-to-Node edges in `catalogs/relationships.json`.** Resend, Twilio, Expo are external SaaS vendors, not HoneyDrunk Nodes. Provider packages are additive to Notify's existing `packages` list.

**No new abstractions in `HoneyDrunk.Kernel.Abstractions`.** All contracts (`IEmailSender`, `ISmsSender`, new `IPushSender`) live in `HoneyDrunk.Notify.Abstractions`.

## Required ADR Amendment — D3 provider-package naming

ADR-0073 D3 names the push package `HoneyDrunk.Notify.Providers.Expo`. The Grid's existing per-channel provider naming (already in `HoneyDrunk.Notify/`) uses **channel-scoped** naming:

- `HoneyDrunk.Notify.Providers.Email.Resend` (exists today)
- `HoneyDrunk.Notify.Providers.Email.Smtp` (exists today)
- `HoneyDrunk.Notify.Providers.Sms.Twilio` (exists today)

The ADR's D3 phrasing is inconsistent with this established pattern. Packet 00 reconciles by amending D3 to `HoneyDrunk.Notify.Providers.Push.Expo` — channel-scoped, parallel to email/sms. The ADR's D1 (`HoneyDrunk.Notify.Providers.Resend`) and D2 (`HoneyDrunk.Notify.Providers.Twilio`) descriptive phrasings are similarly unscoped, but those packages already ship under their channel-scoped names — the existing names take precedence and the ADR's description is informally aligned without an explicit amendment line.

The amendment to D3 is the only structural correction. Packet 00 lands it during ADR acceptance.

## Required Decision — `@honeydrunk/notify-templates` npm package standup

ADR-0073 D4 commits **react-email** as the canonical email-templating library and pins the canonical template set's home as `HoneyDrunk.Notify.Templates` (mentioned by name in §Consequences / Affected Nodes). The challenge: react-email is a TypeScript/JSX library that lives in the npm ecosystem; `HoneyDrunk.Notify` is a .NET repo. The canonical template set is therefore an **npm package living inside a .NET repo** (a polyglot package — react-email source in `templates/`, rendered HTML output potentially consumed by .NET via a sibling .NET library or via build-time HTML emission).

The packaging shape, build pipeline, publish destination (npmjs.org under `@honeydrunk` scope per ADR-0034 patterns), and consumer-PDR template extension model are **non-trivial decisions** that warrant their own standup ADR — the same way `HoneyDrunk.Cache` got an ADR-0059 standup paired with ADR-0058's contract decision. Per the user's standing convention ("new-Node scaffolding gets its own standup ADR; don't bundle scaffold into feature packets"), packet 03 in this initiative is **deferred** with a placeholder until the standup ADR (provisionally `ADR-0073a-notify-templates-npm-standup`) is drafted and accepted.

Until the standup ADR lands, the canonical react-email template set does not ship. Email sends route through Resend with consumer-side HTML composed however the consuming Node already does it (today: Notify's existing template renderer; the canonical react-email set is a Phase-2 ergonomic improvement, not a runtime prerequisite).

**Packet 03 documents the deferral and the open questions** that the future standup ADR must answer. Packet 03 ships even though it ships no code — its purpose is to record the deferral on The Hive so the work is not lost.

## Wave Diagram

### Wave 1 (Governance — no dependencies)
- [ ] **00** — Architecture: accept ADR-0073 (status flip + README index row + initiative registration); amend D3 to channel-scoped `Providers.Push.Expo` naming; record the `@honeydrunk/notify-templates` npm-standup deferral as a Required Decision. **No invariant edits.** `Actor=Agent`.

### Wave 2 (Notify production-hardening — code, parallel within wave; runs after governance)
- [ ] **01** — Notify: Resend email provider production hardening — webhook intake per ADR-0062, Tier-2 rotation registration per ADR-0006, sender-identity README cross-reference to ADR-0038. **First packet on Notify in this initiative — rolls existing `[Unreleased]` content into a dated patch-bump section and bumps from `0.3.0` → `0.3.1`.** `Actor=Agent`. Blocked by: 00.
- [ ] **04** — Notify: Twilio SMS provider production hardening — webhook intake per ADR-0062, Tier-2 rotation registration per ADR-0006, tentative-commitment note recorded in package README and Notify repo overview (`repos/HoneyDrunk.Notify/overview.md`). `Actor=Agent`. Blocked by: 00, 01.

### Wave 3 (Architecture documentation — runs after governance; parallel within wave)
- [ ] **02** — Architecture: ADR-0038 sender-identity wiring cross-reference confirmation — verify the discipline is documented on the Notify side; add a one-paragraph cross-reference to `repos/HoneyDrunk.Notify/overview.md` and to the Resend provider README. **No new policy** — this packet just makes the existing ADR-0038 rules visible at the package boundary. `Actor=Agent`. Blocked by: 00.
- [ ] **03** — Architecture: `@honeydrunk/notify-templates` npm-templates standup deferral — placeholder ADR/standup intent recorded as a packet in this initiative; **no code ships**. Documents the open questions, deferral rationale, and the expected shape of the future standup ADR. `Actor=Agent`. Blocked by: 00. **DEFERRED — does not ship code; serves as the "deferred work" tracker on The Hive.**
- [ ] **05** — Architecture: Notify Cloud per-tenant provider-override policy specification — author the canonical doc at `business/context/notify-cloud-tenant-override-policy.md` describing the UI + validation + fallback semantics for Notify Cloud tenants who bring their own Resend / Twilio / Expo credentials. `Actor=Agent`. Blocked by: 00. **Handoff to the ADR-0027 (Notify Cloud) standup initiative; no Notify Cloud repo work filed here.**

### Wave 4 (Notify push channel — adds new contract + enum + package; depends on production-hardening waves only via the version sequencing rule)
- [ ] **06** — Notify: add `NotificationChannel.Push = 2` to the enum + add `IPushSender` contract to `HoneyDrunk.Notify.Abstractions`. **Version-bumping packet for the Notify solution from `0.3.x` → `0.4.0`** (additive new enum value + new public abstraction is a minor bump per ADR-0035 D1). `Actor=Agent`. Blocked by: 00, 01.
- [ ] **07** — Notify: ship `HoneyDrunk.Notify.Providers.Push.Expo` package implementing `IPushSender` against Expo's Push API + Expo Push Receipts polling for delivery confirmation. Vault-backed Expo Access Token. Appends to the in-progress `[0.4.0]` CHANGELOG entry. `Actor=Agent`. Blocked by: 06.
- [ ] **08** — Notify: register Expo Push Token capture flow placeholder in `HoneyDrunk.Notify.Abstractions` — minimal `PushTokenRegistration` record + the receipts-poll background-worker hook in `HoneyDrunk.Notify.Worker`. The user-side registration UI lives in consumer-PDRs (out of scope here); this packet ships the Notify-side intake seam only. Appends to the in-progress `[0.4.0]` CHANGELOG. `Actor=Agent`. Blocked by: 06, 07.

Packets within a wave run in parallel where dependencies allow. The exception: Wave 4 packets (06, 07, 08) share the Notify solution and must sequence — 06 is the bumping packet (adds enum + contract); 07 ships the package; 08 ships the receipts-poll seam.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0073 — amend D3 naming + record npm-templates deferral](./00-architecture-adr-0073-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Resend email provider production hardening (0.3.1 bump)](./01-notify-resend-production-hardening.md) | Notify | Agent | 2 | 00 |
| 02 | [ADR-0038 sender-identity cross-reference in Notify](./02-architecture-sender-identity-cross-reference.md) | Architecture | Agent | 3 | 00 |
| 03 | [DEFERRED — `@honeydrunk/notify-templates` npm-standup placeholder](./03-architecture-notify-templates-npm-deferral.md) | Architecture | Agent | 3 | 00 |
| 04 | [Twilio SMS provider production hardening (tentative-commitment note)](./04-notify-twilio-production-hardening.md) | Notify | Agent | 2 | 00, 01 |
| 05 | [Notify Cloud per-tenant override policy specification](./05-architecture-notify-cloud-override-policy.md) | Architecture | Agent | 3 | 00 |
| 06 | [Add `NotificationChannel.Push = 2` + `IPushSender` (0.4.0 bump)](./06-notify-push-channel-and-contract.md) | Notify | Agent | 4 | 00, 01 |
| 07 | [Ship `HoneyDrunk.Notify.Providers.Push.Expo` package](./07-notify-expo-push-provider.md) | Notify | Agent | 4 | 06 |
| 08 | [Expo Push Receipts intake seam in Notify.Worker](./08-notify-expo-push-receipts-worker.md) | Notify | Agent | 4 | 06, 07 |

## Version Bumps

- **`HoneyDrunk.Notify`** — multi-packet, multi-wave. Per invariant 27, the first packet bumps and subsequent packets append.
  - **Packet 01 (Resend production hardening)** is the first packet on the Notify solution in this initiative. It must **roll the existing `[Unreleased]` CHANGELOG content into a dated patch-bump section** (per the standing rule "no commits under CHANGELOG `Unreleased`"). The accrued `[Unreleased]` content (per `CHANGELOG.md`: ADR-0044 Grid Review enablement + HoneyDrunk.Standards 0.2.9 refresh) is bundled into a dated `[0.3.1]` section together with the Resend production-hardening changes. Solution bumps from `0.3.0` to `0.3.1` (patch — bugfix/hardening, no new public surface). Per-package CHANGELOG entries only for packages with actual functional change (per invariant 12): repo-level + `HoneyDrunk.Notify.Providers.Email.Resend`. The repo's other 14 packages get the version alignment via their `.csproj` files and get **no** per-package CHANGELOG entries (alignment-bump-only; no noise).
  - **Packet 04 (Twilio production hardening)** appends to the in-progress `[0.3.1]` repo-level entry; adds a per-package entry to `HoneyDrunk.Notify.Providers.Sms.Twilio` for the production-hardening changes; no version bump (already at `0.3.1`).
  - **Packet 06 (push channel + contract)** is the bumping packet for the minor bump `0.3.1` → `0.4.0` (additive new enum value + new public `IPushSender` contract is a minor per ADR-0035 D1). Per-package CHANGELOG entry added to `HoneyDrunk.Notify.Abstractions`; alignment bumps on all other packages with no noise.
  - **Packet 07 (Expo provider)** creates a **new package** `HoneyDrunk.Notify.Providers.Push.Expo` with its own `[0.4.0]` CHANGELOG and README from the first commit (invariant 12). Appends to the in-progress repo-level `[0.4.0]` entry.
  - **Packet 08 (receipts seam)** appends to the in-progress `[0.4.0]` entry; adds per-package entries to `HoneyDrunk.Notify.Abstractions` (the `PushTokenRegistration` record) and `HoneyDrunk.Notify.Worker` (the receipts-poll hook).
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution. Governance, doc, and ADR-amendment edits across packets 00, 02, 03, 05.

## Cross-Cutting Concerns

### Pre-existing test project naming — `HoneyDrunk.Notify.Tests` is acknowledged but not renamed here

ADR-0047 D1 / D11 commit the canonical test project naming `*.Tests.Unit` (with `*.Tests.Integration` and `*.Tests.E2E` for the higher tiers). The Notify repo currently has `HoneyDrunk.Notify.Tests` (pre-ADR-0047 naming) and `HoneyDrunk.Notify.IntegrationTests`. Renaming to `*.Tests.Unit` / `*.Tests.Integration` is a **separate ADR-0047 fan-out follow-up** tracked under the existing `adr-0047-testing-patterns-and-tooling` initiative — not gated by this initiative. ADR-0073 packets add tests to the existing project names; the future ADR-0047 fan-out renames them once.

### `NotificationChannel.Push = 2` is the seam

Packet 06 adds `NotificationChannel.Push = 2` to the enum at `HoneyDrunk.Notify.Abstractions/NotificationChannel.cs`. `NotificationSenderResolver` (in `HoneyDrunk.Notify/Routing/NotificationSenderResolver.cs`) routes via keyed DI on the enum value, so no resolver change is needed — registering the Expo provider with `services.AddKeyedSingleton<INotificationSender>(NotificationChannel.Push, ...)` (or, more accurately, via the `TryAddNotificationSender<T>(NotificationChannel.Push)` provider-support helper, parallel to `AddHoneyDrunkNotifyResendProvider`) wires it in. `NotificationDispatcher.DispatchAsync` already reads `envelope.Channel` and delegates to the resolver — no dispatcher change needed.

The new enum value is **additive** at the public surface; existing consumers that exhaustively switch on `NotificationChannel` will get a compiler warning but no break (the enum is not `[Flags]`, and analyzers will surface missing arms). This is a **minor** version bump per ADR-0035 D1.

### Provider naming reconciliation

The ADR D3 text uses `HoneyDrunk.Notify.Providers.Expo`. The Grid's actual code uses **channel-scoped** naming: `Providers.Email.Resend`, `Providers.Sms.Twilio`. Packet 00 amends D3 to `HoneyDrunk.Notify.Providers.Push.Expo` to match. Packet 07 ships under the channel-scoped name. The D1/D2 phrasings in the ADR are similarly informal (`HoneyDrunk.Notify.Providers.Resend`, `HoneyDrunk.Notify.Providers.Twilio`) but the existing packages already ship under their channel-scoped names; the ADR description is not authoritative against shipped code.

### Sender-identity discipline lives in ADR-0038, not here

ADR-0073 D1 / D6 commit Resend as the email provider but **explicitly defer sender identity to ADR-0038**. This initiative does **not** ship DKIM record creation, SPF record creation, DMARC policy authoring, or the subdomain-split work — those are ADR-0038's deliverables. This initiative's packet 02 cross-references ADR-0038 from the Notify side so a future operator finds the discipline; packet 02 ships docs only.

### Webhook intake discipline lives in ADR-0062, not here

ADR-0073 D1 / D2 commit webhook-driven deliverability events from Resend (D1) and Twilio (D2) into Notify's intake **per ADR-0062's verification discipline**. Packets 01 and 04 wire the webhook handlers using ADR-0062's contracts; they do not redefine the verification model.

### Tier-2 secret rotation lives in ADR-0006 + HoneyDrunk.Vault.Rotation

ADR-0073 D1 / D2 mandate rotation per ADR-0006 Tier 2. Packets 01 and 04 register the Resend / Twilio credentials with the Vault.Rotation Function App's rotation calendar (operational config registration — not new code in Vault.Rotation; the rotation infrastructure already exists per the `vault-rotation-bring-up` initiative). Expo Access Token rotation (packet 07) follows the same pattern.

### Notify Cloud per-tenant override is deferred to ADR-0027

ADR-0073 D5 commits the per-tenant override seam but does not ship the UI / validation / fallback semantics — those are Notify Cloud-internal concerns per the ADR's §D6 Out of Scope ("Tenant-BYO provider tooling"). Packet 05 authors the canonical specification at `business/context/notify-cloud-tenant-override-policy.md`; the actual Notify Cloud implementation packet is filed under the `adr-0027-notify-cloud-standup` initiative after Notify Cloud's repo scaffold packet lands.

### Repos public-by-default per the user's standing rule

The `HoneyDrunk.Notify` repo is **public**. No secrets, no env-specific identifiers, no Vault URIs in packet content. Vault secret **names** (e.g. `Resend--ApiKey`, `Twilio--AccountSid`, `Expo--AccessToken`) are non-secret identifiers and may appear in code and docs; the **values** never appear anywhere outside Vault.

### Site sync

No site-sync flag. ADR-0073 is internal Ops infrastructure; the Studios website does not change. The Notify Cloud override-policy doc (packet 05) ships in Architecture's `business/context/`, not on the public website.

### Deferred follow-ups (explicitly out of scope of this initiative)

- **`HoneyDrunk.Notify.Templates` npm package standup ADR** — packet 03 records the deferral. A future standup ADR (provisionally `ADR-0073a` or a numbered sibling) decides the polyglot-package shape, build pipeline, npm publish destination, and consumer-PDR extension model. Until then, react-email is the committed library but the canonical template set does not ship.
- **Migrating or retiring the legacy SendGrid adapter sketch.** ADR-0073 §Follow-up Work mentions this. No SendGrid adapter ships in `HoneyDrunk.Notify` today (the package directory listing shows `Providers.Email.Smtp` and `Providers.Email.Resend` only — no `Providers.Email.SendGrid`). The follow-up is a no-op; nothing to migrate or retire.
- **Identity verification-email flow on Resend** (ADR-0060 Phase 2). Filed under the `adr-0060-identity-standup` initiative. This initiative ships the Resend production-hardening that Identity's flow consumes, but the Identity-side flow itself is not here.
- **Test project rename `Notify.Tests` → `Notify.Tests.Unit`.** Filed under `adr-0047-testing-patterns-and-tooling`. Not gated here.
- **D2 cost-trigger re-evaluation for Twilio.** Operational follow-up; happens when monthly SMS spend > $200 (or per the other D2 triggers). Tracked outside this initiative.
- **Per-region provider variation** (D6). Deferred to a future EU-tenant requirement.
- **Bounce / complaint policy** (D6). Lives in Communications, not Notify; filed under a future Communications initiative.

## Rollback Plan

- **Packet 00 (governance):** revert the PR. ADR returns to Proposed; D3 naming reverts to `HoneyDrunk.Notify.Providers.Expo`; README index row is removed; initiative registration is removed. No runtime impact.
- **Packet 01 (Resend hardening):** revert the PR. Resend webhook intake reverts; the Tier-2 rotation registration reverts; the existing send path is unchanged (Resend has shipped since 0.1.0). The `[0.3.1]` CHANGELOG entry returns to `[Unreleased]` — note that the standing rule forbids leaving accrued work in `[Unreleased]` long-term, so a follow-up patch-bump must promote the content again.
- **Packet 02 (sender-identity cross-reference):** revert the PR. The Resend README and Notify overview lose the ADR-0038 callouts. No runtime impact.
- **Packet 03 (npm-templates deferral):** revert the PR. The deferral document is removed; the open questions return to the dispatch-plan body. No runtime impact.
- **Packet 04 (Twilio hardening):** revert the PR. Twilio webhook intake and Tier-2 rotation registration revert; tentative-commitment note is removed.
- **Packet 05 (Notify Cloud override policy):** revert the PR. The specification doc is removed from `business/context/`. The deferred Notify Cloud follow-up is unaffected at the runtime level; only the reference document is gone.
- **Packet 06 (push channel + contract):** revert the PR. `NotificationChannel.Push = 2` is removed; `IPushSender` is removed. Notify rolls back to `0.3.1`. No consuming Node depends on `Push` at runtime (packet 07 was the first consumer); reverting 06 forces reverting 07 and 08 together.
- **Packets 07 / 08 (Expo provider + receipts seam):** revert the two PRs. The Expo provider package is unpublished; the receipts-poll hook is removed from the Worker. Mobile apps that have already registered Expo Push Tokens see no sends — the seam is gone — but the Expo Push Tokens themselves are unaffected on Expo's side; a future re-introduction can resume.
- **Operational escape hatch:** at any point, the operator can drop a provider registration (remove `AddHoneyDrunkNotifyResendProvider()` / `AddHoneyDrunkNotifyTwilioProvider()` / `AddHoneyDrunkNotifyExpoProvider()` from the host composition) to disable that channel. The Notify dispatcher will fail any envelope routed to a disabled channel with a `Permanent` failure ("no provider registered for channel X"), which is the existing behaviour today.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
