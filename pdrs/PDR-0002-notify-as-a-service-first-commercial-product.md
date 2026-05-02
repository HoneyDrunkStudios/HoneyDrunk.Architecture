# PDR-0002: HoneyDrunk Notify — First Commercial Product on the Grid

**Status:** Proposed
**Date:** 2026-05-02
**Deciders:** HoneyDrunk Studios
**Sector:** Ops (primary) · Meta (positioning)
**Reframes:** [PDR-0001](PDR-0001-honeyhub-platform-observation-and-ai-routing.md) — the "platform positioning shift" in PDR-0001 §C is downgraded from a committed direction to an aspirational one. HoneyHub is **not** the first commercial product. Notify Cloud is.

---

## Context

The manifesto says the Grid is the product, but the Grid is **not** what gets sold. Apps built on the Grid are. The current Grid has no shipping commercial app — every Node is internal, and the only candidate that has ever been positioned as external (HoneyHub, per PDR-0001) is a 12+ month build before it has a customer-shaped surface. That is too long to wait for the first revenue signal.

Today's strategist review (2026-05-02) ranked four candidates as the first commercial app on the Grid:

| Candidate | Commercial wedge | Dogfood value | Time-to-first-customer |
|---|---|---|---|
| **Notify Cloud — hosted Notify + Communications** | Strongest. Indie .NET devs gluing SES + Twilio, paying Courier/Knock/Loops $50–$200/mo. | Heaviest. Forces Notify to GA, pushes Container Apps deployment, exercises Vault, Auth, Web.Rest, Pulse end-to-end. | Shortest. Notify's delivery engine already exists. |
| HoneyPlay narrative game | Weak. Indie game market is brutal; no recurring revenue shape. | High — pushes AI sector hard. | Long. Game design + content + AI orchestration. |
| Creative tool on HoneyDrunk.AI | Middle. Crowded category. | High — pushes AI Node and Knowledge. | Long. Requires AI Node to reach runtime, not Seed. |
| Anime self-improvement app | Weakest (saturated category, weak wedge, low Grid dogfood). | Low. | Long. |

**Verdict:** Notify Cloud first. The user said "spin it up, I'd like to see what that looks like" — this PDR is the formal write-up.

This PDR also resolves an implicit tension with PDR-0001. PDR-0001 set HoneyHub up as the external-facing platform and committed the Grid to two new domains (Observation, AI Routing) under that framing. Today's strategist call reframed HoneyHub as **internal-only** with kill criteria by 2026-09-30. PDR-0001's Observation and AI Routing decisions stand on their own merits and remain Accepted; PDR-0001 §C "platform positioning shift" — HoneyHub becoming an external product — is treated as **aspirational, not committed**, and is superseded by this PDR's framing of Notify Cloud as the commercial wedge.

---

## What It Does

In plain language: **HoneyDrunk Notify is a hosted API that sends notifications to your users across multiple channels — email, SMS, and (later) push and in-app — with smart routing decisions baked in.**

You hit one endpoint: *"tell user X about event Y."* The service decides:

- **Which channel** — email vs. SMS based on user preferences and urgency.
- **Which provider** — Resend vs. SES vs. Mailgun for email; Twilio vs. Vonage for SMS.
- **When** — now, batched, or held for quiet hours.
- **Whether at all** — deduplication, rate limits, opt-outs, frequency caps.

Then it sends, logs every routing decision, and exposes a dashboard to see what happened and why.

The pain it solves: *"I'm building a SaaS. I need to notify users — sign-ups, password resets, alerts, billing reminders. I don't want to sign up for SendGrid AND Twilio AND a push provider, wire conditional logic across all three, and maintain quiet hours, retries, rate limits, dedup, and opt-outs myself."*

One API. The service handles the rest.

How it sits next to the field:

- **SendGrid / Postmark / Mailgun** — email-only.
- **Twilio** — SMS-only.
- **Courier / Knock / Loops** — multichannel, but JS-first, expensive ($50–$250/mo entry), opinionated toward big-team workflows.
- **Novu** — multichannel OSS, Node.js-native.
- **HoneyDrunk Notify** — multichannel, **.NET-native**, cheap entry, opinionated routing out of the box, decision-log transparency, OSS engine.

---

## Problem Statement

### 1. The Grid has no commercial product

Every Node is internal. The Grid's sustainability model (manifesto §Sustainability — "Open Core. Paid Orchestration.") has no paid-orchestration surface in market. Without a commercial app, the Grid is an architecture exhibit, not a business.

### 2. Notify is a delivery engine with no operator load

Notify is Live (v0.1.0), ships email (Resend, SMTP) and SMS (Twilio), and has a queue-backed worker. It has **zero traffic that isn't internal test runs**. The team building it (one person) is its only operator. There is no production pressure shaping its API, its rate-limits, or its multi-tenant story — because there is no production.

### 3. Indie .NET devs glue notification stacks themselves

The market gap Notify Cloud targets:

- Indie .NET devs running side projects who currently glue **SendGrid + Twilio + a `MailKit` wrapper** by hand, typically inside a `BackgroundService` they wrote three times across three projects.
- Small teams (2–5 devs) running a SaaS product who outgrow transactional-email-only providers and need SMS or in-app channels but don't want to stand up Courier/Knock infrastructure or pay enterprise rates.
- Agencies building on .NET who want a notification layer they can drop in and not own.

For these buyers, today's options are: (a) hand-rolled glue, brittle and rebuilt per-project; (b) Courier or Knock, which are powerful but expensive ($50/mo entry, $200+ at moderate volume) and **not .NET-shaped** (they are JS-first and treat .NET as a translated SDK afterthought); (c) Loops, which is email-only; (d) raw SES + raw Twilio, which is cheap but is the same hand-rolled glue.

Notify Cloud is for option (a) buyers who would pay $10–$30/mo to stop hand-rolling, and option (b) buyers who would pay less for a .NET-native multichannel layer. It is **not** for enterprise buyers — that is a future tier, not a v1 wedge.

### 4. The Grid needs production telemetry, and dogfood is the cheapest source

The Grid's Pulse, Vault, Auth, and Web.Rest Nodes have no production traffic. Notify Cloud forces them into a real production-pressure environment without requiring HoneyHub or any AI-sector Node to ship first. Notify Cloud is the **shortest path** to forcing the Grid into production-grade behavior across its Core and Ops sectors.

---

## Decision

### A. Notify Cloud is the first commercial product on the Grid

**HoneyDrunk Notify** (architecturally: "Notify Cloud") is a hosted, multi-tenant version of the Notify + Communications stack offered to external developers as a **multichannel, .NET-friendly, cheap-entry alternative to Courier/Knock**. It ships as a managed service with REST and SDK surfaces, billed monthly, with a free tier intended for evaluation.

Notify Cloud is not "hosted Notify with a price tag." It is a packaged product:

- A REST API and a `HoneyDrunk.Notify.Client` NuGet package (the latter is the wedge — installable in 30 seconds, idiomatic to .NET teams, signs requests with an API key).
- Multi-tenant tenant isolation enforced at the gateway, queue, and Vault layers.
- A minimal management surface (web app) for tenant signup, API key issuance, rate-limit visibility, and basic delivery logs.
- Stripe-based metered billing with a free tier and two paid tiers (see §C).

### B. Buyer profile and JTBD

**Primary buyer: indie .NET dev / small team (2–5 devs).**

Job to be done: *"I need to send transactional notifications across email and SMS from my .NET app without writing the glue or paying enterprise prices for a JS-first product."*

Distinguishing characteristics:
- Already on .NET (web API, Blazor, MAUI, or a worker service).
- Has 1–3 channels they need (email always, SMS sometimes, push later).
- Volume is in the low thousands per month per tenant at signup, scaling to tens of thousands.
- Price-sensitive at the entry tier; willing to pay $10–$30/mo to stop maintaining glue.
- Values the .NET SDK shape over feature breadth.

**Secondary buyer (later, not v1): agencies and small SaaS teams.**

Same JTBD plus: *"and I want my customer's templates and routing rules to live somewhere I can hand to a non-developer."* This is the entry point to the higher tier and to a future templates-and-flows feature. Not a v1 target; included here so the v1 architecture does not foreclose it.

**Explicit non-buyers (v1):**
- Enterprise teams needing SOC2 / HIPAA / multi-region. Notify Cloud is single-region (Azure East US to start) and does not pursue compliance certifications for v1. This is a deliberate cut — the buyer profile above does not need them.
- High-volume senders (>1M/mo). Pricing and architecture are not optimized for this; the v1 ceiling at the top tier is set deliberately low to keep the cost shape predictable.

### C. Capability tiers and pricing

The pricing structure mirrors Loops (clean entry tier) and undercuts Courier (which starts at $50/mo). **Stripe-based metered billing**, monthly cycles.

| Tier | Price (USD/mo) | Included events/mo | Channels | Tenants | Notes |
|---|---|---|---|---|---|
| **Free** | $0 | 500 | Email only | 1 project, 1 API key | Evaluation tier. Watermark in email footer ("Sent via Notify Cloud — try it at notify.honeydrunkstudios.com"). The watermark is the marketing wedge for the free tier and is the reason it is free. |
| **Starter** | $19/mo | 10,000 | Email + SMS | 3 projects, 5 API keys | The entry buyer. Removes the watermark. SMS metered separately at provider cost + 20%. |
| **Pro** | $49/mo | 50,000 | Email + SMS + (push, when available) | 10 projects, unlimited API keys | The agency / small-SaaS tier. Decision logs from Communications (audit trail of why each message was sent or suppressed) become available here, not in Starter. |

**Pricing intent:**
- **Free tier exists for the watermark, not for the funnel.** Every free-tier email is a marketing impression. The conversion rate from Free to Starter is expected to be low (<5%); the watermark impressions are the value Free tier produces.
- **Starter is the buyer-shaped tier.** $19/mo is below Loops' $49 entry, well below Courier's $50, and is the price an indie dev will swipe a card for without an internal review.
- **Pro is the ceiling for v1.** Anything above Pro is "contact us" — there is no v1 enterprise tier. Adding one is a Phase 4+ decision when ≥3 paying Pro customers ask for it.

**SMS economics:** Twilio sends are passed through at provider cost + 20%. Email sends through Resend are absorbed in the tier flat rate — Resend's pricing makes the math work up to the Pro ceiling.

**Comparable pricing (for reference, not commitment):**
- Courier: starts $50/mo, 10K events.
- Knock: starts $250/mo (enterprise-shaped).
- Loops: starts $49/mo, 1K contacts (email-only, contact-based not event-based).
- SendGrid Essentials: $15/mo, 50K sends (email-only, no SMS, no orchestration).

Notify Cloud at $19/mo for 10K events with email + SMS is competitive on price and category-leading on .NET shape.

### D. Wedge

Notify Cloud does not win on "we send better email." That is a losing fight against SendGrid, Resend, and Postmark, all of which are years deep on deliverability infrastructure. The wedge is:

1. **Multichannel out of the box.** Email + SMS in one SDK call, one bill, one dashboard. Most email-only competitors (Loops, Postmark Essentials) fail this immediately. SES/Twilio glue users pay this cost daily.
2. **.NET-native SDK and API shape.** The `HoneyDrunk.Notify.Client` package is idiomatic .NET — `IServiceCollection` extension method, `IHttpClientFactory`-driven, async cancellation tokens, structured error types. Courier and Knock have .NET SDKs that read like translated TypeScript.
3. **Opinionated routing logic.** Communications's preference, cadence, and decision-log surfaces (per ADR-0019) are exposed as a feature, not buried as plumbing. "Why was this user not sent the message?" is a one-API-call question on Pro.
4. **Cheap entry, no enterprise upsell pressure.** $19 is the price; there is no "talk to sales" tier for v1. The market segment Notify Cloud targets is one that has been actively excluded by Courier/Knock's pricing strategy.

### E. Sequencing and dependencies

Notify Cloud is **not** the next packet. It depends on three blockers:

1. **`HoneyDrunk.Actions#20` (CI/CD foundation).** Without this, no Node ships to Container Apps. Notify Cloud cannot deploy without it.
2. **Notify GA (currently 0.1.0, deployed only as Functions and InMemory worker).** Notify Cloud requires Notify deployed to Container Apps under ADR-0015, with the Azure Storage queue backend in production, with the `Resend` provider in production, with Vault wired for tenant secrets.
3. **Communications scaffold + Notify refactor (ADR-0019, currently Proposed).** Notify Cloud sells Communications's preference / cadence / decision-log story as the Pro-tier wedge. Without ADR-0019 landed, the Pro tier is hollow.

These are sequenced, not parallel:

```
Actions#20 unblock
  → Notify deploys to Container Apps internal (ADR-0015)
    → ADR-0019 lands (Communications scaffold + Notify refactor)
      → Notify hits 1.0 (multi-tenant-ready: tenant ID on every request, per-tenant Vault, per-tenant rate limits)
        → Notify Cloud surface + billing + marketing site
          → Notify Cloud public launch
```

The expected calendar shape (rough):

| Milestone | Earliest | Owner |
|---|---|---|
| Actions#20 | already in flight | scope-agent driven |
| Notify on Container Apps internal | +2 weeks after Actions#20 | scope-agent driven |
| ADR-0019 Accepted (Communications scaffold + Notify refactor done) | +4 weeks | scope-agent driven |
| Notify 1.0 with multi-tenant primitives | +2 months | dedicated initiative |
| Notify Cloud soft launch (waitlist, no payment) | +3 months | new initiative |
| Notify Cloud public launch (Stripe, Free + Starter + Pro live) | +4 months | new initiative |

**Public launch target: 2026-09-15.** This is the date the kill-criteria clock (§K) starts.

### F. What changes architecturally when Notify goes multi-tenant

The internal Notify Node has no concept of tenants. It dispatches what it is given. Going multi-tenant introduces six concrete architectural changes.

**These primitives are designed Grid-wide, not Notify-specific.** `TenantId` propagation, per-tenant rate-limit policy, per-tenant Vault scoping, and tenant-scoped billing events live in Kernel and shared infrastructure — not in `HoneyDrunk.Notify`. Notify is the *first consumer*; future commercial Nodes (if any) inherit the same primitives without retrofitting. The follow-up "Grid multi-tenant primitives ADR" formalizes this scope. The table below describes the Notify-specific application of those primitives:

| Change | Where | Notes |
|---|---|---|
| **Tenant ID on every request** | `NotificationRequest` carries a `TenantId`. `IGridContext` gains a `TenantId` propagation rule. | Already partially present — Kernel has tenant primitives. This formalizes them as required for Notify Cloud surfaces. |
| **Per-tenant API keys with hashed storage** | New `INotifyCloudApiKeyStore` contract, backed by Vault for issuance and a hashed lookup table for validation. | API keys never appear in logs — Invariant 8 already covers this. |
| **Per-tenant rate limits** | The intake gateway (post-ADR-0019: `Notify/Intake/`) checks a `TenantRateLimitPolicy` before enqueueing. Tenant exceeded → 429, recorded in Pulse. | Lives in Notify (delivery-side throttling), not Communications. Communications's cadence is per-user-per-intent; this is per-tenant-per-time-window. Different concern. |
| **Per-tenant provider secrets** | Tenants can BYO their own Resend / Twilio keys (Pro tier feature). Stored in tenant's section of `kv-hd-notify-cloud-{env}`. | Requires Vault scoping per tenant. Default tier uses Notify Cloud's shared provider keys. |
| **Tenant-scoped billing events** | Every successful delivery emits a `BillingEvent` to a queue Stripe consumes via webhook bridge. | New surface — a thin `HoneyDrunk.Notify.Cloud.Billing` adapter, not a Notify concern. |
| **Multi-tenant Web.Rest exposure** | Notify Cloud REST API lives on `notify.honeydrunkstudios.com` (subdomain decision deferred — see Open Questions). Auth is API key, not JWT. Web.Rest gains an `IApiKeyAuthenticator`. | Adds a new auth path to Auth Node — keep it cleanly separate from JWT bearer to preserve Invariant 10 (Auth validates, never issues — API key validation is still validation, not issuance). |

**The bar:** none of these changes should compromise Notify's internal Grid use. The internal callers continue to send to Notify with no `TenantId` (defaults to `internal`, no rate limit, no billing). The multi-tenant surface is additive, not a replacement.

### G. What is **NOT** in scope for Notify Cloud v1

The kill list. Cuts are deliberate.

- **No mobile push (APNS/FCM).** Push is on the v1 tier table as "(push, when available)" with an asterisk — it ships in v1.5, not v1. Push has unique device-token storage requirements and tightly-platform-coupled SDK shape. v1 ships email + SMS only.
- **No in-app / WebSocket channels.** Different domain (real-time, persistent connections). Out of scope for v1; reconsider after v1 customer feedback.
- **No deliverability dashboards.** Bounce rates, spam scores, IP reputation graphs — these are SendGrid's home turf. Notify Cloud surfaces delivery success/failure per message but does not compete on deliverability analytics depth.
- **No template editor UI.** Templates are uploaded via API or as files in the SDK. A WYSIWYG editor is a Phase 4 feature, not v1.
- **No SOC2 / HIPAA / GDPR DPA-as-a-product.** The buyer profile in §B does not need these. v1 ships with a privacy policy and standard ToS, not with a compliance-certified posture. Compliance is a Phase 4+ decision triggered by an enterprise tier introduction.
- **No multi-region / DR.** v1 is single-region (Azure East US). DR is "best-effort backup of tenant configs and API keys to a second region's Storage account" — not a hot DR posture.
- **No webhook ingress (inbound emails, SMS replies).** v1 is outbound-only.
- **No SLA.** v1 ships with a "best-effort uptime" stance and is honest about it on the marketing site. SLAs are a Pro+ feature for v2.
- **No team / org / role management.** Each tenant is one billing entity with up to N API keys. Multi-user accounts within a tenant are a Phase 4 feature.
- **No programmatic tenant provisioning (signup-as-API).** Tenants sign up via the marketing site and are provisioned by a manual or semi-manual flow at v1. Self-service signup-via-API is a v1.5 feature.
- **No analytics / usage dashboards beyond a basic event log.** The Pro tier exposes the Communications decision log; that is the analytics surface for v1.

The cuts above are aggressive on purpose. The fastest way to ship v1 at quality is to ship the smallest v1 that has a buyer-shaped surface.

### H. Domain and brand positioning

HoneyDrunk Notify launches as a **product surface inside the HoneyDrunk Studios brand**, not as a separate brand. The marketing site lives at `notify.honeydrunkstudios.com` (proposed — see Open Questions for the alternative). The customer-facing name is **"HoneyDrunk Notify"**; "Notify Cloud" is the internal architectural shorthand for the multi-tenant wrapper repo and packages.

**Brand model: studio → product.** HoneyDrunk Studios is the parent brand. HoneyDrunk Notify is the first commercial product. Future products (a HoneyPlay game, a creative tool, etc.) are additional product brands under the studio. There are **no separate sub-brands per Node**.

**Internal Grid Nodes are invisible to customers.** Auth, Vault, Communications, Pulse — the customer never sees these names. They see "your Notify API key," "your Notify dashboard," "your delivery logs." The Grid is the studio's architecture; it is not customer-facing language. Marketing copy talks about features and outcomes, not Nodes or Sectors.

**Commercialization of other Nodes is deferred.** Vault-as-a-Service, Auth-as-a-Service, and Communications-as-a-Service are **not** committed by this PDR. The multi-tenant primitives the Grid builds for Notify Cloud are designed Grid-wide (see Recommended Follow-Up Artifacts — "Grid multi-tenant primitives ADR"), so future commercial productization of any other Node is cheap if it ever makes sense. But the *commercial decision* is deferred until Notify Cloud has shipped and found traction. Avoiding premature platform sprawl is the lesson from PDR-0001's HoneyHub-as-platform reframing.

This is consistent with the manifesto's build-in-public stance: HoneyDrunk Studios is a build-in-public studio, and its first commercial product is named after, and lives under, the studio brand. Spinning up a separate brand for v1 would dilute the studio narrative without producing any commercial benefit.

If Notify Cloud scales past the kill-criteria bar in §K, a separate brand decision can be revisited as a follow-up PDR. v1 commits to the studio-branded surface.

### I. Multi-tenant boundary impact on internal Grid use

A non-trivial concern. The strategist's bar was: "if multi-tenanting forces architectural changes that compromise internal Grid use, kill Notify Cloud." This decision commits to a stance:

**Multi-tenant Notify is a superset of internal Notify.** Internal callers are tenant `internal`, with no rate limits, no billing, and using the Grid's shared Resend / Twilio keys via the Grid's existing Vault. Notify Cloud is additive — new gateways, new policies, new key stores — running on the same Notify deployment. This is the same architectural pattern Stripe uses for its own internal sends ("we use our own product"), the same pattern AWS uses for its internal SES, and the same pattern Twilio uses for its internal Twilio.

The architectural risk is real and is called out in §M (Risks): if tenant isolation enforcement bleeds into the core Notify dispatch path in a way that internal callers cannot avoid, that is a kill condition. The mitigation is that all tenant-aware concerns (API key auth, rate limit, billing emission, per-tenant Vault scoping) live in **gateway-layer middleware**, not in the core dispatch path. The dispatch path receives an already-resolved request with tenant context attached; it does not know how that tenant context was obtained.

This is the same separation Notify already enforces between intake (post-ADR-0019: `Notify/Intake/`) and routing (`Notify/Routing/`). Notify Cloud extends intake. It does not change routing.

### J. Why Notify Cloud specifically (and not the other candidates)

Short rationale. Long version is in the strategist conversation arc that produced this PDR.

- **Notify Cloud vs. HoneyPlay narrative game.** HoneyPlay is the best dogfood of the AI sector but has a weak commercial wedge — indie game economics are brutal, and the AI sector is at "Seed" signal across nine Nodes. HoneyPlay would force the AI sector to ship 9 Nodes before there is a customer, which is the same time-to-revenue problem PDR-0001 had with HoneyHub.
- **Notify Cloud vs. creative tool on HoneyDrunk.AI.** Middle-ranked on both axes. Crowded category (every AI startup is shipping a creative tool), and depends on AI Node reaching runtime, which is months of work. Notify Cloud depends on Notify reaching 1.0, which is weeks.
- **Notify Cloud vs. anime self-improvement app.** Saturated category, weak wedge, low Grid dogfood. Killed in the strategist call.
- **Notify Cloud vs. HoneyHub-as-external (PDR-0001).** HoneyHub remains valuable as an internal control plane, but its external-facing form (per PDR-0001 §C) is a 12+ month build before there is a customer-shaped surface. Notify Cloud ships first; HoneyHub-external becomes either a v2 product or is dropped per the kill criteria the user has set against it for 2026-09-30.

Notify Cloud wins because it has the **shortest time-to-customer of any commercial candidate, the highest dogfood value, and a buyer profile that is concretely identifiable today** — not "indie devs in general," but specifically indie .NET devs gluing SES + Twilio. That is the wedge.

### K. Kill criteria

Notify Cloud gets killed if either of the following conditions triggers within 90 days of public launch (i.e., by **2026-12-15** assuming a 2026-09-15 public launch):

1. **<10 paying customers (Starter or Pro) within 90 days of public launch.** This is the commercial bar. Free-tier signups do not count. If the addressable market is correctly identified and the wedge is real, 10 paying customers in 90 days is achievable. If it is not achieved, the wedge is not real and Notify Cloud does not have product-market fit at the v1 surface. Kill.
2. **Multi-tenanting forces architectural changes that compromise internal Grid use.** Specifically: if any of the changes in §F bleed into the core Notify dispatch path in a way that internal callers must now know about tenancy (e.g., internal callers must pass a `TenantId`, internal callers hit rate limits they didn't ask for, internal callers' Vault paths get rewritten). This is a hard kill — the Grid's internal use of Notify is non-negotiable.

A third soft kill condition that triggers a PDR review (not an automatic kill):

3. **Operating cost exceeds revenue by 3× at any point in the first 90 days.** If 50 paying customers at $19/mo ($950/mo revenue) requires >$2,850/mo in Azure + Resend + Twilio + Stripe fees, the unit economics are broken. This triggers a pricing or scope review, not an immediate kill.

### L. Support model for a solo dev

Realistic support shape for one person + AI agents:

- **No phone support. No SLA. No 24/7.**
- Email support at `support@honeydrunkstudios.com` with a 48h target on weekdays.
- Status page at `status.honeydrunkstudios.com` (a static page wired to a Pulse health summary; no full StatusGator-grade infra).
- Public Discord (or GitHub Discussions on a public `HoneyDrunk.Notify.Cloud.Community` repo — TBD) for community support and visibility.
- Documentation site (subset of the HoneyDrunk Studios marketing site) carries SDK reference, API reference, and "common patterns" guides.
- AI agents (the same agents that build the Grid) handle first-line triage on inbound support emails — propose a draft reply for human review, do not auto-send.

This is honest about the support shape a solo dev can deliver. The pricing tiers reflect this — there is no "premium support" or "white-glove onboarding" tier in v1, because there is no human to deliver it.

### M. Open-source strategy: open core + private commercial wrapper

The Notify engine is open source. The commercial wrapper (multi-tenant gateway, billing, tenant management, ops glue) is private. This is the **open core** model — first concrete instance of the manifesto's "Open Core. Paid Orchestration." stance.

**What is open (default-public per studio repo policy):**
- `HoneyDrunk.Notify` — the engine. Provider integrations, routing logic, queue worker, intake pipeline, decision-making.
- `HoneyDrunk.Notify.Client` — the SDK. Idiomatic .NET, used by both self-hosters and HoneyDrunk Notify customers. Ships to NuGet under the same license as the engine.
- `HoneyDrunk.Communications` — the orchestration layer. Preferences, cadence, decision logs.
- All Notify and Communications-related ADRs and PDRs.

**What is private:**
- `HoneyDrunk.Notify.Cloud` — multi-tenant gateway, API key issuance/rotation, rate-limit policies, billing event emission, tenant Vault scoping, abuse detection.
- `HoneyDrunk.Notify.Cloud.Billing.Stripe` — Stripe webhook bridge and subscription logic.
- `HoneyDrunk.Notify.Cloud.Web` — the management website (signup, billing, dashboards).

**Why open the engine:**
- **Distribution.** Open source is the marketing channel a solo dev with no audience can credibly run. GitHub stars, contributor pull requests, public issue triage, and dev-community visibility produce inbound the studio cannot otherwise generate.
- **Trust.** Buyers can read what they're paying for. The architecture is the marketing — consistent with the build-in-public stance.
- **Adoption.** Self-hosters who choose not to pay were never going to convert; they boost adoption metrics, write blog posts, and some eventually become hosted-service customers when they tire of running it themselves.
- **The competitive proof.** Novu — a direct multichannel-notification competitor — was built on exactly this model and reached venture-fundable adoption on the strength of OSS first.

**Why keep the commercial wrapper private:**
- Multi-tenant boundary, billing logic, and ops tooling are commercial-only. Open-sourcing them invites an AWS-style "host this for cheaper" competitor against a solo dev who cannot match infra economics.
- Customer-data-adjacent concerns (tenant isolation enforcement, abuse detection, billing fraud, abuse heuristics) are easier to iterate on without public scrutiny of half-baked states.
- The commercial wrapper has zero educational or community value as OSS — it is studio-specific glue, not a reusable primitive.

**License — open question, FSL or BSL.** The Notify engine is licensed under a **source-available license** (Functional Source License or Business Source License — final choice deferred to the standup ADR for `HoneyDrunk.Notify.Cloud`). These licenses allow read, modify, redistribute, and self-host, but block "host this as a competing commercial service." MIT/Apache would expose the engine to hyperscaler rehosting, which is the failure mode this license posture prevents. Sentry uses FSL; HashiCorp and MariaDB use BSL — the model is well-established.

**Customer-facing framing.** The marketing site at `notify.honeydrunkstudios.com` says: *"Notify is open source. HoneyDrunk Notify is the hosted version we run."* Self-hosting is supported (with documentation), and the value of the hosted service is **reliability + multi-tenant management + billing + support** — not closed-source secrets. Buyers who self-host are not lost revenue; they are amplifiers and future customers.

---

## Options Evaluated

### Option 1: Status quo — Notify stays internal, no commercial product

**Description:** Notify stays at v0.1.0 internal-only. The Grid continues building toward HoneyHub-as-external per PDR-0001. No commercial revenue for the foreseeable future.

**Pros:**
- No multi-tenant complexity to manage.
- Builder focus stays on architecture, not product.
- HoneyHub-as-platform vision (PDR-0001 §C) remains undisturbed.

**Cons:**
- No revenue. Manifesto's "Open Core. Paid Orchestration." has no paid surface.
- No production telemetry forcing function on Vault, Auth, Pulse, Web.Rest.
- Grid risks becoming a permanently internal exhibit.
- HoneyHub-as-external is 12+ months from a customer-shaped surface; in the meantime, the Grid produces nothing in market.

**Verdict:** Rejected. Solo-dev studios that don't ship commercial work eventually run out of runway or motivation. The Grid needs a commercial surface; the question is which one.

### Option 2: HoneyHub-as-external as the first commercial product (per PDR-0001 §C)

**Description:** Continue treating HoneyHub as the primary external commercial product. Spend the next 12 months building the Observation layer, AI Routing, capability tiers, billing for capability tiers, and onboarding.

**Pros:**
- Aligns with PDR-0001's stated direction.
- HoneyHub is a more ambitious product with a larger TAM if it works.

**Cons:**
- 12+ months to first customer. Nothing ships commercially in the interim.
- PDR-0001 §C is already being treated as aspirational, not committed (per today's strategist call).
- Observation domain has connector sprawl risk (PDR-0001 §Risks). Building Observation correctly before there is a customer to validate it is high-cost, high-uncertainty.
- HoneyHub's buyer profile is "engineering leader at a 50-person company" — a longer sales cycle, larger ACV, but also a fundamentally different go-to-market than a solo-dev studio can run.

**Verdict:** Rejected. HoneyHub remains valuable internally and is not killed by this decision. But it is not the first commercial product — the time horizon is wrong for this studio's stage.

### Option 3: HoneyPlay narrative game as the first commercial product

**Description:** Build a narrative game on the AI sector. Sell on Steam.

**Pros:**
- Best dogfood of the AI sector — every AI Node gets exercised.
- Creative work the user is motivated to do.

**Cons:**
- Indie game commercial economics are brutal — most indie games make <$10K total.
- AI sector is at "Seed" across 9 Nodes; reaching playable means shipping all 9 first.
- Grid sectors not exercised: Ops (no notification needs in a single-player game), Core (already exercised but not under production load), Auth (game has no auth needs).
- Time-to-customer: 12–18 months minimum.

**Verdict:** Rejected as first commercial product. May become a future product once the AI sector ships, but not the wedge.

### Option 4: Creative tool on HoneyDrunk.AI as the first commercial product

**Description:** Build a generative creative tool (image, video, story) on the AI Node, sell as a SaaS.

**Pros:**
- Hot category — generative tools are where the venture money is.
- Forces the AI sector forward.

**Cons:**
- Crowded market — every AI startup is shipping a creative tool.
- Depends on AI Node reaching production-ready, which is months of work.
- The AI sector has 9 Nodes; even a minimal creative tool needs AI + Knowledge + maybe Memory.
- Buyer profile is diffuse — "creators" is not a buyer-shaped segment.

**Verdict:** Rejected. Middle-ranked on both axes; lacks the buyer specificity Notify Cloud has.

### Option 5: Notify Cloud as the first commercial product (Selected)

**Description:** Hosted, multi-tenant Notify + Communications. Stripe billing. .NET-native SDK. Email + SMS at $19/mo entry.

**Pros:**
- Shortest time-to-customer of any candidate (3–4 months).
- Notify already exists at v0.1.0; the delta to commercial is "multi-tenant + billing + marketing," not "build a Node from scratch."
- Highest dogfood value — forces Notify GA, ADR-0015 deployment, ADR-0019 acceptance, Vault production usage, Auth API key path, Pulse production telemetry.
- Buyer profile is concretely identifiable: indie .NET devs gluing SES + Twilio.
- Wedge is real: multichannel + .NET-native + cheap entry, against Courier/Knock's enterprise pricing and Loops' email-only scope.
- Pricing model is competitive ($19/mo undercuts Loops and Courier; matches the buyer's willingness to pay).

**Cons:**
- Multi-tenant complexity introduces architectural risk to Notify (mitigated by §I — gateway-layer-only).
- Solo-dev support model is constrained — no SLA, no 24/7. May limit growth past Pro tier.
- Email is a deliverability arms race — Notify Cloud does not win on deliverability alone.
- Customer-acquisition cost in the indie .NET dev segment is unknown; marketing channel needs validation (likely .NET community: Reddit, Discord, dev.to, dotnet conferences).

**Verdict:** Selected. Best ratio of wedge sharpness to time-to-customer to dogfood value. Pricing matches the buyer; scope is aggressive on cuts; kill criteria are well-defined.

### Option 6: Notify Cloud but defer Communications integration (email + SMS only, no orchestration story)

**Description:** Ship Notify Cloud with just Notify's delivery surface. No Communications, no preferences, no cadence, no decision log.

**Pros:**
- Faster to ship. Doesn't depend on ADR-0019 acceptance.
- Smaller surface = less to maintain.

**Cons:**
- Loses the Pro-tier wedge entirely. Without preferences / cadence / decision logs, Notify Cloud is just SendGrid + Twilio repackaged, and SendGrid + Twilio are already cheaper at scale.
- No differentiation against Loops or Courier on the orchestration axis.
- Forces Notify Cloud to compete on deliverability — the losing fight identified in §D.

**Verdict:** Rejected. Communications is the wedge for the Pro tier, and the Pro tier is where revenue compounds past Starter. Shipping without Communications produces a Notify Cloud v1 that is worse than its competitors on the dimensions that matter.

---

## Trade-offs

| Trade-off | Favored Position | Rationale |
|---|---|---|
| Build Notify Cloud now vs. wait for HoneyHub-as-platform | **Build Notify Cloud** | Time-to-customer wins. HoneyHub-external is 12 months out; Notify Cloud is 4. Revenue and production telemetry now beat a bigger product later. |
| Multi-tenant complexity in Notify vs. simplicity of internal-only | **Accept the complexity, contained at gateway layer** | The dispatch path is preserved for internal use. All tenant concerns live in middleware. The risk is real (§K kill condition 2) but contained. |
| Aggressive scope cuts (no push, no in-app, no SOC2) vs. broader v1 surface | **Aggressive cuts** | The buyer profile (indie .NET dev) does not need push or SOC2. Shipping fewer features faster matches the buyer's expectations and the solo-dev's capacity. |
| Free tier as funnel vs. free tier as marketing impression | **Marketing impression** | The watermark on free-tier emails is the value the free tier produces. Conversion-funnel framing is wrong — most free users will never convert, and that's fine if the watermark is doing its job. |
| Studio brand vs. separate Notify Cloud brand | **Studio brand** | Build-in-public is the studio's stance. Separate brand dilutes that without commercial benefit at v1 scale. |
| $19 entry tier vs. higher entry tier | **$19** | Below Loops' $49 and Courier's $50. The buyer's willingness-to-pay is in the $10–$30 range. $19 is the sweet spot — high enough to be taken seriously, low enough to be a no-review purchase. |
| Single-region vs. multi-region | **Single-region (East US)** | Multi-region adds infrastructure cost and DR complexity that a v1 customer base does not need. Buyer profile is global indie devs who tolerate East-US latency. |
| Communications in v1 vs. Notify-only in v1 | **Communications in v1** | The orchestration surface is the wedge for the Pro tier. Without it, the Pro tier is hollow. Worth the dependency on ADR-0019. |
| 90-day kill clock vs. longer runway | **90 days** | Aligns with the strategist's bar. Solo-dev studios can't afford to sustain a non-converting commercial product. If the wedge is real, 10 customers in 90 days is achievable; if it's not, kill quickly and learn. |

---

## Architecture Implications

### New surface area

**New repo: `HoneyDrunk.Notify.Cloud`** (proposed name — open question on final naming).

This is a new Node in the **Ops** sector. It is the multi-tenant gateway, billing bridge, and tenant-management surface that wraps Notify + Communications for external sale. It is a separate Node, not a feature inside Notify, because:

- It introduces external-facing concerns (Stripe webhooks, API key management, marketing-facing REST API) that should not live on Notify's public boundary.
- It has a different release cadence — Notify Cloud will iterate on pricing, tenant management, and billing logic at a higher tempo than Notify's delivery engine.
- Notify's invariants (channel-agnostic delivery, queue-backed dispatch) should not be polluted by Notify Cloud-specific concerns.

**Package families (parallels ADR-0016 / 0017 / 0019 stand-up shape):**

- `HoneyDrunk.Notify.Cloud.Abstractions` — `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `TenantRateLimitPolicy`, `BillingEvent`. `TenantId` lives in Kernel as a Grid-wide primitive, not in this package.
- `HoneyDrunk.Notify.Cloud` — runtime composition. Multi-tenant gateway, API key validation middleware, rate limiter, billing event emitter.
- `HoneyDrunk.Notify.Client` — **the wedge.** Idiomatic .NET SDK. The NuGet package indie devs install.
- `HoneyDrunk.Notify.Cloud.Billing.Stripe` — Stripe-specific billing adapter. Provider-slot pattern; alternative billing providers (Paddle, LemonSqueezy) can be added later without changing the core.
- `HoneyDrunk.Notify.Cloud.Web` — the multi-tenant management website (signup, billing, API keys, basic delivery logs). Likely Blazor Server or Astro + minimal API; decision deferred to the scaffold ADR.

### Dependencies

```
Notify Cloud
  ├─ consumes ──► Communications (ICommunicationOrchestrator) — Pro tier wedge
  ├─ consumes ──► Notify (INotificationSender) — delivery
  ├─ consumes ──► Auth (API key validation path — new)
  ├─ consumes ──► Vault (per-tenant secrets)
  ├─ consumes ──► Web.Rest (response envelopes, correlation)
  ├─ consumes ──► Kernel (IGridContext, lifecycle, telemetry)
  └─ emits telemetry ──► Pulse
```

Notify Cloud does **not** consume HoneyHub. Notify Cloud does **not** consume any AI-sector Node at v1. (Pro tier could add AI-driven preference learning later — that is a Phase 4 conversation, not v1.)

### Boundary changes to existing Nodes

| Node | Change | Notes |
|---|---|---|
| **HoneyDrunk.Notify** | Add `TenantId` to `NotificationRequest`. Per-tenant rate limiting in the intake gateway. Per-tenant Vault scoping. | Backwards-compatible — internal callers default to `internal` tenant. |
| **HoneyDrunk.Communications** | Same `TenantId` propagation. Decision log entries are tenant-scoped. | Implicit if Communications takes `IGridContext` for tenant resolution — no contract surface change. |
| **HoneyDrunk.Auth** | New `IApiKeyAuthenticator` middleware path, separate from JWT. | Still validation-only (Invariant 10 preserved — API key validation is not issuance; issuance lives in Notify Cloud). |
| **HoneyDrunk.Vault** | Per-tenant secret scoping pattern documented as a first-class use case. | No Vault contract change; this is a usage pattern, not a new surface. |
| **HoneyDrunk.Pulse** | New per-tenant telemetry tags (`tenant_id` as a label, with discipline that it is a low-cardinality tier — paying customers are in tens, not millions, at v1). | Cardinality bound by the kill criteria (10–100 paying customers). |
| **HoneyDrunk.Web.Rest** | New API key auth path on the response envelope side (correlation IDs are still issued, but the auth surface is new). | Matches the Auth change above. |

### What does NOT change

- **The Grid's internal Notify usage.** Internal callers continue to call Notify exactly as today. They acquire a `TenantId.Internal` value through the same Kernel `IGridContext` they already use; no callsite changes.
- **Notify's delivery routing, retry, and worker mechanics.** The dispatch path is unchanged. Notify Cloud-specific concerns live in intake, not routing.
- **Vault's contract surface.** Per-tenant scoping is a usage pattern, not a contract change.
- **Auth's JWT validation path.** API key auth is a parallel path, not a replacement.
- **Pulse's collection model.** Tenant tags are a labeling addition.
- **HoneyHub.** This PDR does not change HoneyHub's internal direction. It only reframes PDR-0001 §C.
- **Any AI-sector Node.** v1 Notify Cloud does not depend on AI sector.
- **Architecture invariants 1–36.** No invariant is amended or removed by this PDR. New invariants may be proposed by the follow-up ADRs.

---

## Product Implications

### Tier shape and progression

| Stage | Tier | Buyer | Hook |
|---|---|---|---|
| Evaluation | Free | Indie dev exploring | Watermark in email footer; 30-second SDK install |
| Activation | Starter ($19) | Indie dev / side project | Removes watermark; SMS support |
| Expansion | Pro ($49) | Small SaaS / agency | Decision logs, more projects, BYO provider keys |
| Future | Enterprise (no v1) | Mid-market | Phase 4+; reconsidered at >10 Pro customers |

### Customer acquisition

The .NET indie community is a **specific, addressable channel set**:

- `r/dotnet` and `r/csharp` on Reddit — high-quality content drives awareness.
- .NET Discord servers (the official .NET Discord, the Blazor Discord, several MAUI-related servers).
- `dev.to`, `Hashnode`, and dotnet-focused blogs.
- .NET conferences (NDC, .NET Conf, dotnetos) — community visibility, not paid sponsorship at v1.
- **The HoneyDrunk Studios website itself** — build-in-public is the marketing strategy. Every public repo, every public PDR, every public ADR is content. Notify Cloud is the commercial surface that monetizes that content.

The HoneyDrunk Studios website (`Studios` Node, Live in the Meta sector) is already public. Notify Cloud becomes its first revenue-bearing call to action.

### Build-in-public alignment

Notify Cloud's build is itself content. Every architectural decision (multi-tenant boundary, Vault scoping, billing event design, Communications integration) is a public PDR or ADR. Indie .NET devs who land on the marketing site can read the architecture they're paying for. This is consistent with the manifesto's "Transparency is marketing" stance and is a moat against generic competitors who can't or won't expose their architecture.

### Pricing-to-architecture coupling

Pricing tiers are not arbitrary — each tier maps to a clean architectural feature surface:

- **Free → Starter** is gated by *channels* (email-only vs. email+SMS) and *watermark removal*. Architecturally, this is a tenant-attribute check at intake time.
- **Starter → Pro** is gated by *Communications decision logs, BYO provider keys, project count*. Architecturally, this exposes Communications's audit surface and per-tenant Vault scoping.

This coupling means "what does the Pro tier do" maps directly to architectural surfaces that already exist in the Grid (Communications, Vault). Notify Cloud is not building features for tiers; it is exposing existing Grid surfaces under a tier gate.

---

## What Does NOT Change

- **The Grid's manifesto.** "Open Core. Paid Orchestration." gets its first paid orchestration surface; it is not a new principle.
- **HoneyHub's internal role** as the Grid's control plane (per ADR-0003). HoneyHub is reframed as internal-only (per the strategist call); ADR-0003 is not invalidated.
- **PDR-0001's Observation and AI Routing decisions** stand on their own merits. They were strategically valuable for HoneyHub-internal even before HoneyHub-external was reframed; that strategic value persists.
- **All architectural invariants (1–36).**
- **All ADRs in flight (0013, 0019).** ADR-0019 becomes a hard prerequisite for Notify Cloud, not an optional follow-up.
- **The solo-dev operating model.** This PDR commits the Grid to a commercial product but does not commit to hiring or to an investor narrative. Notify Cloud is solo-shipped with AI agents, on the same operating model as everything else.

---

## Risks

| Risk | Severity | Description |
|---|---|---|
| **No paying customers within 90 days** | High | The kill criterion. Indie .NET dev segment may be smaller than estimated, or the wedge may be insufficient against entrenched competitors. |
| **Multi-tenanting bleeds into core dispatch path** | High | If tenant concerns end up in `NotificationDispatcher` or downstream, internal Grid usage is compromised. This is kill criterion 2. |
| **Email deliverability weakness sinks reputation** | Medium-High | Resend handles deliverability, but a Notify Cloud-shaped abuse case (a tenant sending spam) could affect reputation across all tenants on the same Resend pool. Per-tenant Resend keys (Pro tier feature) mitigate at the Pro tier; Starter tenants share. |
| **Stripe billing edge cases** | Medium | Failed payments, prorations, plan changes, refunds. Standard SaaS billing complexity that does not exist for an internal tool. |
| **Solo-dev support overload** | Medium | If Notify Cloud gets 50+ paying customers, support volume may exceed solo capacity. Pricing may need to absorb a part-time support contractor at that scale. |
| **Communications scaffold ships incomplete (ADR-0019)** | Medium | Notify Cloud depends on ADR-0019. If ADR-0019 ships with a stub decision log (e.g., in-memory only in production), the Pro tier wedge is hollow. |
| **Indie dev segment is too price-sensitive even at $19** | Medium | The buyer may exist but not pay. Mitigated by the Free tier (some marketing impressions even from non-payers); not eliminated. |
| **Notify GA slips past 4 months** | Medium | The dependency chain (Actions#20 → ADR-0015 deploy → ADR-0019 → Notify 1.0 → Notify Cloud) is long. Any single dependency slipping pushes Notify Cloud launch past the 2026-09-15 target. |
| **Operating cost exceeds revenue** | Low-Medium | Soft kill criterion 3. Mitigations: Container Apps' scale-to-zero shape, Resend pricing absorbs cleanly at v1 volumes. |
| **Tenant abuse / spam / fraud** | Medium | First-time multi-tenant exposure means first-time abuse exposure. Rate limits, per-tenant audit, and Stripe radar mitigate; do not eliminate. |
| **Brand confusion with HoneyHub-as-platform language in PDR-0001** | Low-Medium | External viewers reading both PDRs may wonder which is "the product." This PDR's reframing in the header should resolve, but the website needs explicit framing. |

---

## Mitigations

| Risk | Mitigation |
|---|---|
| No paying customers in 90 days | Pre-launch waitlist (soft launch at +3 months) to validate signal before Stripe is live. If waitlist is below 50 sign-ups, delay public launch and re-evaluate the wedge before spending Stripe-integration time. |
| Multi-tenanting bleeds into core dispatch | All tenant concerns enforced at gateway layer (intake middleware), not in `NotificationDispatcher`. Architectural review of every Notify Cloud PR confirms tenant logic stays in `HoneyDrunk.Notify.Cloud` or `HoneyDrunk.Notify/Intake/`, never in `HoneyDrunk.Notify/Routing/` or `HoneyDrunk.Notify/Worker`. |
| Email deliverability weakness | Pro tier offers BYO Resend / Twilio keys. Per-tenant Resend keys for Pro isolate reputation. Free + Starter tiers share a Notify Cloud-managed Resend pool with abuse rate limits and an automated abuse-detection signal that pauses tenants exceeding thresholds. |
| Stripe billing edge cases | Use Stripe's metered billing primitives (the well-trodden path), not a custom invoicing system. Stripe's webhook reliability and dispute handling are battle-tested. |
| Solo-dev support overload | Tier pricing reflects no SLA. AI-agent-assisted first-line triage. Pro tier may include a Community Discord channel that is community-supported, not solo-supported. |
| Communications scaffold incomplete | Hard requirement: ADR-0019 must be Accepted (both halves landed) before Notify Cloud public launch. Notify Cloud soft launch can ship with the in-memory decision log; public launch requires a persistent decision log backend (which is a Communications open question, not a Notify Cloud one). |
| Indie dev price sensitivity | Free tier exists for marketing impression. If $19 proves too high, the next experiment is $9 Starter, not lowering Pro. |
| Notify GA slip | Sequencing is explicit. Dependencies are issued as concrete prerequisites, each with its own scope-agent-driven packet stream. Notify Cloud launch slips with them; the kill clock starts at public launch, not at PDR acceptance. |
| Operating cost > revenue | Container Apps scale-to-zero on Consumption keeps idle cost near zero. Resend / Twilio costs are linear with usage and metered through to the customer at +20%. |
| Tenant abuse / fraud | Per-tenant rate limits at intake. Stripe Radar for payment fraud. Manual review for the first 100 signups (solo-dev-feasible at this scale). |
| Brand confusion with PDR-0001 | This PDR's header explicitly reframes PDR-0001 §C. Marketing site copy makes Notify Cloud the headline product; HoneyHub is presented as "the internal control plane that powers the Grid." |

---

## Consequences

### Short-term (next 4 months — through 2026-09-15)

- **Notify is forced from "Live, internal" to "GA, multi-tenant-ready."** Tenant primitives, rate limits, per-tenant Vault scoping, billing event emission.
- **ADR-0019 becomes hard-prerequisite, not optional.** Acceptance is gated on Notify Cloud launch needs.
- **A new repo (`HoneyDrunk.Notify.Cloud` or final naming)** stands up with its own scaffold ADR (per the standup-ADR convention).
- **Stripe integration is built.** First non-Azure third-party billing surface in the Grid.
- **Marketing presence on `notify.honeydrunkstudios.com`** (or final domain).
- **Production telemetry** flows through Pulse for the first time at non-trivial volume.
- **HoneyHub's external-platform direction (PDR-0001 §C)** is publicly reframed as internal-only, and the kill clock the user already set against HoneyHub-as-external (2026-09-30) runs in parallel with Notify Cloud's launch clock.

### Long-term (post-90-day kill clock)

If Notify Cloud clears the 90-day bar:

- **The Grid has a revenue-bearing surface.** "Open Core. Paid Orchestration." has its first paid example.
- **Notify Cloud becomes the customer-facing front of the Grid**, reshaping the studio's public narrative around a shipping commercial product.
- **The Grid's production posture is forced** — every Core and Ops Node now operates under production load.
- **Future commercial products** (the next PDR after this one) have a template: pick a Node, package it as a service, tier it, sell it. The Grid is positioned as a portfolio of commercial Nodes, not a single mega-product.
- **HoneyHub-external is either revisited as a v2 product** (with Notify Cloud revenue funding it) **or formally killed** at the 2026-09-30 internal-only kill date.

If Notify Cloud does not clear the 90-day bar:

- **Notify Cloud is killed.** The repo is archived but remains public (per the public-by-default repo posture).
- **A retrospective PDR is written** documenting what the wedge missed.
- **Notify reverts to internal-only.** The multi-tenant primitives are kept (they are clean additions) but no longer have a customer.
- **The next commercial candidate is selected.** Likely the creative tool on HoneyDrunk.AI, with the lessons from Notify Cloud applied.

Either outcome generates more learning than continuing to ship internal-only Nodes.

---

## Rollout — Phased Approach

### Phase 1: Dependency unblock (weeks 0–4)

- `HoneyDrunk.Actions#20` lands (CI/CD foundation).
- ADR-0015 deployment workflow lands (`job-deploy-container-app.yml`).
- Notify deploys to Container Apps internal (the dogfood test before multi-tenancy).
- ADR-0019 ships both halves (Communications standup + Notify refactor) and flips Accepted.

**Exit criteria:** Notify is deployed to `ca-hd-notify-stg` with the Azure Storage queue backend, the Resend provider, and the post-ADR-0019 intake pipeline. Communications is at 0.1.0 with in-memory defaults.

### Phase 2: Notify multi-tenant primitives (weeks 4–10)

- `TenantId` propagated through `NotificationRequest`, `IGridContext`, and the intake pipeline.
- Per-tenant rate limit policy at intake.
- Per-tenant Vault scoping pattern documented and implemented.
- Notify ships 1.0 with the multi-tenant surface available but not exposed externally.

**Exit criteria:** Internal Grid usage of Notify is unchanged. A test tenant (`TenantId = "test-tenant-1"`) can be provisioned manually and exercised end-to-end through the new gateway path.

### Phase 3: Notify Cloud scaffold (weeks 10–14)

- New repo standup ADR for `HoneyDrunk.Notify.Cloud` (per the standup-ADR convention — empty cataloged repo gets its own ADR).
- `HoneyDrunk.Notify.Cloud.Abstractions`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Notify.Client`, `HoneyDrunk.Notify.Cloud.Billing.Stripe`, `HoneyDrunk.Notify.Cloud.Web` packages scaffolded.
- API key issuance and validation flow.
- Stripe metered billing wired with test products and webhook bridge.
- Marketing site copy drafted at `notify.honeydrunkstudios.com`.

**Exit criteria:** A waitlist signup form is live. Stripe is in test mode. The SDK is published to NuGet at 0.1.0-preview.

### Phase 4: Soft launch (weeks 14–16)

- Waitlist opens. Marketing posts on Reddit, dev.to, .NET Discord servers.
- 10–20 hand-picked beta tenants provisioned. No payment yet.
- Feedback loop: weekly review of beta tenant pain points; package adjustments shipped within 7-day cycles.

**Exit criteria:** ≥50 waitlist signups. Beta tenants have sent ≥1,000 messages combined without a Sev-2 or higher incident.

### Phase 5: Public launch (week 16, ~2026-09-15)

- Stripe live mode. Free + Starter + Pro tiers active.
- Watermark on free-tier emails.
- Status page live.
- Documentation site live.
- **The 90-day kill clock starts here.**

**Exit criteria for "successful public launch":** Public traffic, working signup flow, Stripe charges processing, no Sev-1 incidents in the first 7 days.

### Phase 6: Kill-clock review (week 28, ~2026-12-15)

- Count paying customers. <10 → kill per §K.
- Review architectural state of Notify. Tenant logic in core dispatch path → kill per §K.
- Review unit economics. Cost > 3× revenue → pricing or scope review per §K.

**Exit criteria:** Either Notify Cloud is committed to as a sustained product (and the next PDR is "what does Notify Cloud v1.5 look like"), or Notify Cloud is killed and a retrospective PDR is written.

---

## Resolved Questions

| Question | Resolved | Decision |
|---|---|---|
| Free tier shape — 500 events/mo + watermark | 2026-05-02 | 500 events/mo + watermark in email footer ("Sent via HoneyDrunk Notify — try it at notify.honeydrunkstudios.com"). Specific watermark wording validated against beta tenants in Phase 4. |
| Billing infrastructure — Stripe | 2026-05-02 | Stripe metered billing. Re-evaluate if international VAT compliance (which Paddle and LemonSqueezy handle as merchant-of-record but Stripe does not by default) becomes a friction at scale. |
| Product name and architectural shorthand | 2026-05-02 | Customer-facing brand: **HoneyDrunk Notify**. Internal architectural shorthand: **Notify Cloud**. The "NaaS" abbreviation is dropped — it collides with Network-as-a-Service in cloud parlance. |
| Final repo name for the commercial wrapper | 2026-05-02 | `HoneyDrunk.Notify.Cloud`. The SDK shared between self-hosters and hosted-service customers stays at `HoneyDrunk.Notify.Client`. |

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Domain — `notify.honeydrunkstudios.com` vs. a separate brand domain (`honeydrunk-notify.com`, `gridnotify.com`, etc.) | Product | Default proposed: `notify.honeydrunkstudios.com` per §H. Separate brand revisited only if Notify Cloud clears the 90-day bar and grows past the studio's current shape. |
| Open-source license — FSL vs. BSL for the Notify engine | Architecture / Legal | Default proposed: FSL (Functional Source License). Both prevent hyperscaler rehosting while allowing self-host, modify, and redistribute. FSL has a 2-year automatic conversion to Apache; BSL has a configurable conversion window. Final choice in the `HoneyDrunk.Notify.Cloud` standup ADR. |
| Support model — email vs. Discord vs. GitHub Discussions for community | Product | Default proposed: email + public Discord. GitHub Discussions if Discord proves too noisy. |
| Tenant provisioning — fully manual at v1, semi-automated at v1.5, or fully automated at launch | Operations | Default proposed: manual at soft launch (10–20 beta tenants), semi-automated at public launch (signup form auto-provisions tenant ID, API key issuance is automated, Stripe subscription is automated). |
| Abuse detection threshold — what triggers an automatic tenant pause | Operations / Communications | Default proposed: bounce rate > 10%, spam complaint rate > 0.5%, or 5× normal volume in a 1-hour window. Specific thresholds tuned during soft launch. |
| AI-agent-assisted support draft loop — which agent, what prompt, what review gate | Operations | Defer to Phase 4. The agent ecosystem already exists; the integration shape (inbound email → agent draft reply → human review) is a specific scope-agent task. |
| Per-tenant feature flagging — needed at v1 or deferred | Architecture | Default proposed: deferred. v1 ships flat tier features; per-tenant overrides are a Phase 4+ operations need. |
| Compliance posture statement — what does the marketing site say about privacy / data handling | Product / Legal | Default proposed: a clear privacy policy + a "we are not SOC2 / HIPAA certified — if you need certified compliance, Notify Cloud v1 is not for you" honest disclaimer on the pricing page. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|---|---|---|
| `HoneyDrunk.Notify.Cloud` standup ADR | ADR | Stand up the new Node per the standup-ADR convention. Names package families, downstream coupling rule, contract-shape canary, dependency surface. |
| Grid multi-tenant primitives ADR | ADR | Defines `TenantId` propagation, intake-layer rate limit policy, per-tenant Vault scoping, and billing event emission as **Grid-wide** patterns — not Notify-specific. Notify Cloud is the first consumer; future commercial Nodes (if any) inherit the same primitives without retrofitting. The Notify-specific changes in §F are the first concrete application of these Grid-wide primitives. |
| API key authentication pattern ADR | ADR | Defines the `IApiKeyAuthenticator` middleware in HoneyDrunk.Auth, the API key issuance flow, and the storage shape (hashed in Notify Cloud, never raw). Preserves Invariant 10. |
| Stripe billing integration ADR | ADR | Defines the `BillingEvent` shape, the webhook bridge, and the `HoneyDrunk.Notify.Cloud.Billing.Stripe` provider-slot pattern. |
| Notify Cloud pricing and tier feature gates design doc | Design doc | Maps tier features to architectural surfaces. Defines what changes in code when a tenant upgrades from Starter to Pro. |
| Communications decision-log persistence ADR | ADR | The persistent backend ADR-0019 deferred. Notify Cloud Pro tier requires this — soft launch can use in-memory, public launch needs persistent. |
| Tenant onboarding and provisioning workflow design doc | Design doc | The end-to-end flow from signup form submission to working API key, including Stripe subscription creation, Vault tenant scoping, and welcome-email-via-Communications. |
| HoneyHub internal-only reframing PDR or amendment | PDR / amendment | Formalizes the strategist's call that HoneyHub-as-external is killed at 2026-09-30 unless re-justified. Ensures PDR-0001 §C is not left as ambiguous direction. |
| Marketing site copy and pricing page design doc | Design doc | The customer-facing surface. Aligns the build-in-public framing with the commercial-product framing. |
| Notify Cloud retrospective PDR (conditional) | PDR | If Notify Cloud is killed at the 90-day bar, the retrospective PDR documents what the wedge missed and informs the next commercial-candidate selection. |
