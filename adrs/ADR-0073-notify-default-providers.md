# ADR-0073: Notify Default Providers — Resend (Email), Twilio (SMS), Expo (Push)

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Ops

## Context

[ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) committed the boundary between HoneyDrunk.Communications (decision / orchestration) and HoneyDrunk.Notify (intake / delivery). The provider-slot abstraction inside Notify is already established — Notify exposes provider-shaped contracts (`IEmailSender`, `ISmsSender`, future `IPushSender`) and runtime implementations compose against those contracts. What is **not** committed: which providers fill the slots.

Current state:

- **Email.** Provider slot exists. A SendGrid adapter was sketched in early Notify work; not finalized; no production-grade default committed.
- **SMS.** Provider slot exists. No provider implementation today.
- **Push.** Provider slot was named as a future-state extension in [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 6.3 ("Push-Notification Provider-Slot Extension to HoneyDrunk.Notify"). Today: not implemented.

Without canonical defaults, every consumer PDR re-derives the provider choice (which is the wrong shape per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) — provider selection is a Notify concern, not a Communications-consumer concern). [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md) committed the **sender-identity** discipline (DKIM, SPF, DMARC, From-address governance); this ADR fills the **provider-choice** gap that ADR-0038 left implicit.

Forcing functions converging now:

- **Notify Cloud GA** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) is the first commercial product through Notify. It needs a production-grade email provider on day one and a production-grade SMS provider when its first tenant requests SMS sends.
- **Consumer-app PDRs** ([PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)) all require push notifications. Per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D3 the mobile platform is React Native + Expo; Expo's push pipeline is the natural alignment.
- **[ADR-0070](./ADR-0070-frontend-platform-stack.md)** commits React Native + Expo for mobile. Expo Notifications is the push pipeline Expo provides; aligning Notify's push provider with the mobile platform produces a coherent end-to-end story.
- **[ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md)** introduces user-facing verification email flows (account verification, password reset, account-change notification) that route through Communications → Notify. The email provider must support the deliverability discipline from [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md).

This ADR commits the **canonical defaults** for each channel, holds the **provider abstraction** (defaults are not exclusive bindings), commits the **templating choice** that pairs with the email default, and names the **revisit conditions** where the defaults are re-evaluated.

The charter framing ([`constitution/charter.md`](../constitution/charter.md) §"Why we build this way"):

> Pick defaults so every consumer PDR doesn't re-derive the choice.

A defaults ADR is workshop-pragmatic substrate work — small commitment now, large savings in downstream packets.

## Decision

### D1 — Resend is the default email provider

**Resend** is the canonical email provider for HoneyDrunk.Notify's `IEmailSender` slot. Every consumer PDR and every Communications-orchestrated email send routes through Resend by default.

The committed shape:

- **`HoneyDrunk.Notify.Providers.Resend`** (NuGet package, per the Grid's per-provider-package convention) — the `IEmailSender` implementation.
- **API key in Vault** per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — `kv-hd-notify-{env}` namespace, rotated per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 2.
- **Sender identity discipline per [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md)** — DKIM, SPF, DMARC alignment for every sending domain; per-product From-address governance.
- **Webhook-driven deliverability events** — Resend's webhook callbacks (bounce, complaint, delivered, opened, clicked) deliver into Notify's intake per [ADR-0062](./ADR-0062-inbound-webhook-verification.md)'s verification discipline.

**Why Resend as the default:**

- **Developer-experience tier.** Resend's API ergonomics are best-in-class in 2026 — clean REST shape, typed SDKs (including a .NET SDK), excellent docs, fast time-to-first-send. For a solo dev where time-to-set-up matters, this is the largest single factor.
- **Pricing alignment with the Grid's scale.** Free tier covers initial development and low-volume production (3K emails/month free; ~$20/mo for 50K). Per-1000-email pricing thereafter is predictable and competitive. The price curve does not get punishing at the volumes Notify Cloud will hit at the low-hundreds-of-tenants ceiling.
- **react-email integration is first-class.** Resend is the company behind react-email (the React-based email-templating library) per D4. The template-author → render → send pipeline is one toolchain rather than three.
- **Deliverability discipline is well-supported.** First-class DKIM / SPF / DMARC tooling, domain-verification flows, dedicated-IP options at higher tiers. Pairs with [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md).
- **Modern stewardship.** Founded 2023, well-funded, growing fast in 2026. Active product investment; not a legacy ESP coasting on existing customers.
- **Recently established as the default for "modern" .NET / TypeScript shops.** The AI-assistance gradient on Resend in 2026 is strong; Claude / Codex / Copilot pattern recognition on Resend SDK shapes is meaningful.

The negative form: SendGrid is not the default; AWS SES is not the default; Postmark is not the default; Mailgun is not the default.

### D2 — Twilio is the default SMS provider (tentative; re-evaluate at first cost-pressure inflection)

**Twilio** is the canonical SMS provider for HoneyDrunk.Notify's `ISmsSender` slot. The commitment is marked **tentative** and is re-evaluated at the first cost-pressure inflection (defined below).

The committed shape:

- **`HoneyDrunk.Notify.Providers.Twilio`** — the `ISmsSender` implementation.
- **Account credentials in Vault** per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — same namespace as Resend.
- **Per-region number management** is a Notify-internal concern; tenants do not bring their own numbers at MVP.
- **Webhook-driven delivery events** (delivered, failed, queued) deliver into Notify's intake per [ADR-0062](./ADR-0062-inbound-webhook-verification.md).
- **TCPA / SMS-marketing discipline** is a per-PDR consumer-app concern; Notify does not enforce it at the provider layer.

**Why Twilio (tentatively) as the default:**

- **Ecosystem maturity.** Twilio is the industry default for programmable SMS since 2009. Most thorough docs, most exhaustive feature surface (Verify for 2FA, Conversations for two-way, Programmable Messaging for one-way), broadest country coverage.
- **React Native SDK quality.** When mobile apps need in-app SMS verification flows that bypass Notify (the rare case), Twilio's RN SDK is the most polished.
- **AI-assistance gradient.** Claude / Codex / Copilot pattern recognition on Twilio is markedly deeper than on any alternative — the API has been stable for over a decade and is well-represented in training data.
- **Trust posture for a solo-dev shop.** Twilio's deliverability, compliance handling (10DLC registration, A2P 10DLC), and country-specific regulation navigation is operator-time-saving. The premium price buys the operator out of a class of "is my SMS being delivered in the UK / India / Germany correctly" problems.

**Why tentative:**

- **Cost.** Twilio is meaningfully more expensive per message than alternatives (MessageBird, Plivo, AWS SNS, Vonage). At low volumes the cost gap is rounding error; at production scale it becomes a real line item.
- **The Grid is pre-volume.** No SMS sends today. The premium is hypothetical until the workload materializes; at that point the cost calculus is concrete and revisitable.

**Re-evaluation triggers:**

- **First month with SMS spend > $200.** At that point, run a cost comparison against MessageBird and Plivo for the same workload mix. Switch if the savings justify the migration cost (a one-PR adapter swap behind `ISmsSender`).
- **A specific tenant-driven requirement** (regulatory, country-specific) that another provider serves better.
- **A Twilio stewardship event** (pricing change, hostile policy, API instability) that breaks trust.

Until a trigger fires, Twilio is the default.

### D3 — Expo Notifications is the default push provider

**Expo Notifications** is the canonical push provider for HoneyDrunk.Notify's `IPushSender` slot. iOS and Android push both route through Expo's push pipeline; Notify does not talk to APNs or FCM directly.

The committed shape:

- **`HoneyDrunk.Notify.Providers.Expo`** (new package, ships when push lands) — the `IPushSender` implementation.
- **Expo Push Tokens** are the addressable identifier; the mobile app (per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D3, RN + Expo) registers with Expo at app-launch and the token rounds back to the user record (Identity Node per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md)) via the consumer-PDR's registration flow.
- **Expo's Push API** is the send pipeline — Notify's `IPushSender` implementation calls Expo's Push API; Expo fan-outs to APNs and FCM internally.
- **Expo Push Receipts** are the delivery-confirmation pipeline — Notify polls receipts after send and lands the delivery / failure events into its standard intake.
- **Expo Access Tokens in Vault** per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md).

**Why Expo Notifications as the default:**

- **Alignment with the mobile platform.** Per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D3, every Grid mobile surface is RN + Expo. Expo's push pipeline is the native fit — same mental model, same SDK surface on the mobile side, no separate APNs/FCM registration dance.
- **Eliminates APNs / FCM credential complexity.** Direct APNs requires an APNs auth key per app, certificate management, p12 / .p8 file handling. Direct FCM requires service-account credentials per app. Expo wraps both behind a single Expo project and a single push token format. The credential surface shrinks from "two complex per-platform setups" to "one Expo project."
- **Free for the Grid's foreseeable scale.** Expo Notifications is free up to high volume; the Expo platform itself has paid tiers for build minutes (EAS Build) and OTA updates, but the push pipeline is free at the limits Grid PDRs will hit.
- **Receipt-driven delivery confirmation.** Expo's receipt API gives Notify the same delivered/failed events that Resend (for email) and Twilio (for SMS) provide. The cross-channel intake model stays coherent.
- **AI-assistance gradient.** Expo's docs and patterns are well-represented in 2026 AI training data; Claude / Codex / Copilot have meaningful coverage.

**Vendor risk:** Expo is one company; an Expo failure mode (acquisition, pricing change, shutdown) is real risk. The mitigation: Expo Push Tokens are translatable to native APNs / FCM tokens, and the `IPushSender` abstraction means the migration cost is a one-PR adapter swap. The risk is bounded by the wrapping pattern.

The negative form: OneSignal is not the default; direct APNs is not the default; direct FCM is not the default; raw push services are not adopted.

### D4 — Email templating uses react-email

**react-email** is the canonical email-templating library for the Grid. Email templates author in JSX, render to HTML at send time, and ship via Resend.

The committed shape:

- **react-email** for component authoring (`@react-email/components`).
- **Templates live in `HoneyDrunk.Notify.Templates`** — a per-Notify package that holds the canonical template set (verification email, password reset, account-change confirmation, account-deletion confirmation, generic transactional shapes).
- **Per-consumer-PDR templates** live in the consumer-PDR's repo when product-specific (Hearth's "welcome to the town" email, Notify Cloud's tenant onboarding email). They consume react-email components from the Notify Templates package for consistency.
- **Render at send time** — Notify's `IEmailSender` implementation accepts a rendered HTML body; the consumer code calls `render(<MyEmail />)` from react-email and passes the result to `IEmailSender.SendAsync`. The rendering is consumer-side; Notify is HTML-in.
- **Tokens and design system from Web.UI** per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) — react-email styling consumes Web.UI tokens for visual coherence between the Grid's web surfaces and its emails.

**Why react-email:**

- **Pairs with Resend** (same company; first-class integration; tested together).
- **JSX for templating** matches the [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1 React posture. Operator and AI assistants compose templates in the same idiom as web components.
- **Component reuse across email and web** — a `<Button>` styled in Web.UI can have a `<EmailButton>` equivalent in react-email with shared design tokens. Brand coherence across channels.
- **Preview tooling.** react-email's local preview server lets the operator iterate on templates without sending real emails.

**The negative form:** MJML is not adopted; raw HTML templates are not adopted; Razor templates for email are not adopted; HTML-string-concatenation is forbidden.

### D5 — Provider abstraction is held; defaults are not exclusive bindings

The defaults in D1, D2, D3 are **canonical defaults**, not exclusive bindings. The provider abstraction inside HoneyDrunk.Notify is preserved:

- **Per-tenant override is permitted.** A Notify Cloud tenant with their own SES account, their own Postmark relationship, their own Twilio sub-account can plug into the `IEmailSender` / `ISmsSender` provider slot with a tenant-scoped implementation. The default (Resend / Twilio / Expo) is what Notify uses for tenants who do not override.
- **Per-PDR override is permitted (but discouraged).** A consumer PDR that has a compelling reason to use a different provider can register an alternate implementation at host composition. The discouragement is operational — every alternate provider is one more thing to maintain, monitor, and reason about.
- **The Node-level default is enforced at scaffolding.** Every new Notify-consumer packet cites the default; overrides require justification in the packet.

The defaults are the **first answer to "which provider?"** — not the only answer.

### D6 — Out of scope

The following are explicitly **not** decided by this ADR:

- **Sender-identity policy** — owned by [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md). This ADR commits the provider; ADR-0038 commits the identity discipline (DKIM, SPF, DMARC, From-address governance).
- **Per-region provider variation.** When a future EU-tenant requirement forces EU-resident email infrastructure, the per-region override mechanism applies (D5).
- **Tenant-BYO provider tooling.** The mechanism by which a Notify Cloud tenant brings their own provider (UI for credential entry, validation flow, fallback semantics) is a Notify Cloud-internal concern.
- **Outbound-rate-limiting per provider.** Per-provider rate limits (Resend's per-second cap, Twilio's per-number cap) are operational concerns; the runtime adapter handles them.
- **Bounce / complaint handling policy.** The deliverability-event intake lands events; the policy on what to do with them (auto-suppress, raise to operator, escalate to Communications decision layer) is a Communications-side concern per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md).
- **MMS, RCS, or other rich-messaging channels.** Out of scope today; SMS is the only short-message channel committed.
- **In-app notification (toast / banner) inside the consumer app.** That is a Web.UI / per-PDR concern, not a Notify concern.
- **Webhook outbound** — when the Grid sends webhooks to external systems (Notify Cloud tenants subscribed to event types, future B2B integration), that is a separate channel with its own provider stance (likely "no provider; HTTP POST direct"). Out of scope.

## Consequences

### Affected Nodes

- **[`HoneyDrunk.Notify`](../repos/HoneyDrunk.Notify/overview.md)** — primary affected Node. Receives `HoneyDrunk.Notify.Providers.Resend`, `HoneyDrunk.Notify.Providers.Twilio`, and (in Phase 3) `HoneyDrunk.Notify.Providers.Expo` packages. Existing provider-slot abstraction unchanged.
- **HoneyDrunk.Notify.Templates** (new package) — homes the canonical react-email templates.
- **[HoneyDrunk.Communications](../repos/HoneyDrunk.Communications/overview.md)** — orchestrates sends through Notify with these providers under the hood. No change to Communications' decision/orchestration boundary.
- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) Notify Cloud** — adopts Resend and Twilio as the default tenant-experience providers. Per-tenant override is permitted per D5.
- **[ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) Identity** — verification email, password reset, account-change notification all route through Communications → Notify with Resend underneath.
- **Consumer-app PDRs** ([PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)) — each consumes Notify with these providers; push lands per consumer-PDR when their mobile app pulls on it.
- **[`HoneyDrunk.Vault`](../repos/HoneyDrunk.Vault/overview.md)** — `kv-hd-notify-{env}` namespace gains Resend API key, Twilio account credentials, Expo Access Token entries.
- **`HoneyDrunk.Web.UI`** per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) — design tokens flow into react-email templates for cross-channel brand coherence per D4.

### Invariants

No new Grid-wide invariants introduced. Conventions enforced at packet authoring and review:

- **Email sends use Resend by default.** Alternative providers require justification.
- **SMS sends use Twilio by default.** Tentative; re-evaluation triggers per D2.
- **Push sends use Expo Notifications by default.**
- **Email templates use react-email; raw HTML email is not authored by hand.**
- **Provider credentials live in Vault per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md).**

### Operational Consequences

- **Three vendors instead of one.** Each provider has its own pricing curve, its own webhook format, its own deliverability profile, its own dashboard the operator monitors. The cost is real; the mitigation is fewer-than-N (three covers email, SMS, push for the entire Grid).
- **Resend cost is bounded for the foreseeable scale.** Free tier through MVP; ~$20-$80/mo through Notify Cloud's low-hundreds-of-tenants ceiling.
- **Twilio cost is workload-dependent.** No SMS volume today; the cost grows linearly with send volume. The D2 re-evaluation trigger at $200/mo catches the inflection.
- **Expo Notifications cost is effectively zero** for the Grid's mobile-app scale. Expo's paid tiers (EAS Build, OTA) are mobile-build concerns, not push concerns.
- **Cross-channel brand coherence improves.** Web.UI tokens flow into emails via react-email; Web.UI tokens flow into push notification rich content where supported; the Grid's visual language carries across channels.
- **Vendor risk is bounded by the wrapping pattern.** Each provider is one adapter swap away from replacement. The `IEmailSender` / `ISmsSender` / `IPushSender` contracts are stable; the implementations are swappable.
- **Deliverability discipline scales.** [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md)'s sender-identity rules apply uniformly; Resend's DKIM / SPF / DMARC tooling makes the discipline operationally cheap.
- **Local-dev sends never reach real providers.** Dev environments use the InMemory implementations per [Invariant 15](../constitution/invariants.md); only `dev`/`staging`/`prod` environments hit Resend / Twilio / Expo.

### Follow-up Work

- Ship `HoneyDrunk.Notify.Providers.Resend` package (Notify-side packet, with Vault wiring and webhook intake).
- Ship `HoneyDrunk.Notify.Templates` package with the canonical react-email template set.
- Migrate or retire any legacy SendGrid adapter sketches.
- Ship `HoneyDrunk.Notify.Providers.Twilio` package when the first SMS-needing PDR pulls on it.
- Ship `HoneyDrunk.Notify.Providers.Expo` package when the first mobile-PDR push-flow pulls on it.
- Identity verification-email flow per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) Phase 2 lands on Resend.
- Notify Cloud GA documentation includes the per-tenant provider-override mechanism per D5.
- Re-evaluation calendar: track Twilio monthly spend; the D2 trigger fires the cost comparison.
- Watch list: Resend stewardship continues; Twilio pricing curve; Expo's stewardship under its current ownership.

## Alternatives Considered

### Email — Postmark

Considered. Postmark has a strong deliverability reputation, $15/mo for 10K emails, transactional-focused (which matches the Grid's needs), responsive support.

A close runner-up to Resend. Rejected as the default for two reasons. (a) Resend's developer experience and react-email integration win the time-to-set-up race for a solo-dev shop. (b) Postmark's pricing is competitive at low-volume but Resend's scales similarly. Postmark is held as a credible alternative if Resend's stewardship deteriorates; the wrapping pattern (D5) makes the swap bounded.

### Email — AWS SES

Considered. Cheapest per-email pricing at scale; integrates with the broader Azure-first posture awkwardly (SES is AWS) but functionally fine.

Rejected. The operational overhead — SES configuration, dedicated-IP warming, deliverability self-management, webhook setup via SNS — is high for a solo dev. Resend's "API key in, sends out, deliverability handled" posture is markedly cheaper in operator time. SES's per-email cost saving does not materialize until volumes the Grid is unlikely to hit at the low-hundreds-of-tenants ceiling.

### Email — SendGrid

Considered. The legacy default for "transactional email in .NET." Mature SDK, broad feature set.

Rejected. (a) Stewardship concerns — SendGrid's 2025 account-hygiene posture (aggressive suspensions, account-review delays affecting small senders) damaged trust for solo-dev shops. (b) Developer experience has not modernized at the rate Resend's has. (c) The "legacy default" status is its own argument against — solo-dev choices in 2026 should favor the well-stewarded modern entrants over the legacy incumbents where the technical capability is equivalent. Same principle as [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D2's Moq → NSubstitute reasoning.

### Email — Mailgun

Considered. Long history, decent API, fair pricing.

Rejected as second-tier on both DX and stewardship dimensions relative to Resend and Postmark. No specific argument against; just not the best fit among the credible options.

### SMS — MessageBird

Considered. Cheaper per-message than Twilio; strong international coverage (especially EU); modern API.

Rejected as the default; held as a strong contender for the D2 re-evaluation. The current default (Twilio) is justified by ecosystem maturity at MVP scale; MessageBird wins on cost at scale. If the D2 re-evaluation trigger fires, MessageBird is the leading candidate.

### SMS — Plivo

Considered. Lower per-message cost than Twilio; comparable feature set.

Rejected as the default; held as a credible D2 re-evaluation candidate alongside MessageBird.

### SMS — AWS SNS

Considered. The cheapest option; integrates with broader Azure-style cloud thinking awkwardly (SNS is AWS).

Rejected. Operational overhead — managing the SMS sending side of SNS — is high; deliverability reporting is sparse compared to Twilio. The cost saving does not materialize until volumes that justify the operator time of running SNS.

### Push — OneSignal

Considered. Cross-vendor push aggregator; handles APNs + FCM behind one SDK; has free tier.

Rejected. Adds a layer (OneSignal) on top of the layer (APNs/FCM) on top of the mobile platform (Expo). The Expo-direct path is simpler — Expo already aggregates APNs + FCM; OneSignal would aggregate Expo's aggregation. The extra layer is overhead without earning its keep at the Grid's scale.

### Push — Firebase Cloud Messaging (FCM) direct

Considered. Google's push pipeline; free; supports both Android and iOS (via APNs proxy).

Rejected per D3. Direct FCM requires per-app service-account credentials, manual APNs token handling for iOS, separate dashboards. Expo's wrap eliminates the credential complexity. If Expo ever fails as a vendor, direct FCM (for Android) + direct APNs (for iOS) is the fallback per D3's vendor-risk mitigation.

### Push — Apple Push Notification service (APNs) direct

Considered. The iOS-native push pipeline.

Rejected as standalone; the Grid is cross-platform (iOS + Android per RN + Expo), so APNs alone is incomplete. Same vendor-risk mitigation as FCM (direct APNs is the iOS-side fallback if Expo fails).

### Templating — MJML

Considered. MJML is a long-established email-templating language that produces deliverable HTML across email-client variation.

Rejected per D4. JSX (via react-email) wins on developer-experience for a React-first Grid. MJML's "MJML-language-then-compile-to-HTML" pipeline is one more language to learn; react-email's "React-and-compile-to-HTML" pipeline reuses [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1's React skills.

### Templating — Razor templates rendered to HTML email

Considered. The .NET-native templating approach; the Grid is .NET-deep.

Rejected. Razor for email loses the cross-stack alignment that JSX + react-email + React (web) + RN (mobile) gives. The Grid's frontend layer (per [ADR-0070](./ADR-0070-frontend-platform-stack.md), [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)) is React-first; email templating should match.

### Skip the defaults ADR; let each consumer-PDR pick

Considered. The argument: provider selection is implementation detail; the Grid should commit only to the abstraction.

Rejected. Without defaults, every PDR re-derives the provider choice and the Grid ends up with three email providers, two SMS providers, and two push providers — all costing the operator vendor-management time for no productivity gain. The defaults are exactly what saves PDR-side derivation; the per-PDR override (D5) preserves the escape valve for the rare case where a default doesn't fit.

### Adopt all three channels with a single provider (e.g., Twilio for SMS + SendGrid for email + … all under one bill)

Considered. The argument: one vendor relationship simplifies billing, support, and credentials.

Rejected. No single provider is best-in-class across all three channels in 2026. Twilio's email side (acquired SendGrid) is operationally separate from its SMS side; Resend doesn't do SMS; Expo doesn't do email or SMS. The best-of-each posture is the right trade for a solo-dev shop where the per-vendor overhead is dominated by per-channel quality.

## References

- [`constitution/charter.md`](../constitution/charter.md) — workshop pragmatism, defaults-as-substrate framing
- [`constitution/invariants.md`](../constitution/invariants.md) — invariants 8 (secrets discipline), 15 (in-memory providers for tests)
- [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — provider credentials via Vault
- [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) — credential rotation
- [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) — Communications / Notify boundary
- [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — Notify Cloud (first commercial product consuming these providers)
- [ADR-0038](./ADR-0038-outbound-sender-identity-and-deliverability.md) — sender-identity discipline (DKIM/SPF/DMARC)
- [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) — Identity verification-email flows
- [ADR-0062](./ADR-0062-inbound-webhook-verification.md) — webhook verification (used by all three providers' delivery callbacks)
- [ADR-0070](./ADR-0070-frontend-platform-stack.md) D3 — RN + Expo mobile platform (alignment with Expo push)
- [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) — Web.UI tokens (consumed by react-email templates for cross-channel coherence)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 6.3 — push-provider-slot context
- [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md), [PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) — PDRs consuming Notify
