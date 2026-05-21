# ADR-0038: Outbound Sender Identity and Deliverability

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Ops

## Context

`HoneyDrunk.Notify` (0.3.0, Ops) delivers messages across channels (email, SMS, push, in-app). `HoneyDrunk.Communications` (0.2.0, ADR-0019) is the orchestration layer above it. `HoneyDrunk.Notify.Cloud` (Seed, ADR-0027) is the multi-tenant commercial wrapper above Communications.

Today the Grid sends a trivial volume of email — primarily Studio-internal operational mail and a handful of dev-tier transactional sends — through unconfigured SMTP and SMS endpoints. The Grid does not own:

- A canonical sending domain or subdomain.
- DMARC/DKIM/SPF records for any sending identity.
- A toll-free 10DLC SMS registration.
- Sender reputation, warmup history, or bounce/complaint feedback loops.
- A list-management/unsubscribe model that survives multi-tenancy.

ADR-0029 commits Cloudflare as authoritative DNS and registrar; sender-identity records will be DNS-resident there. ADR-0027 names Notify Cloud as the first commercial Node, and the first paying tenant onboarding question after RPO/billing is "what's the sending reputation" — there is no defensible answer today.

The forcing function is the same as ADR-0036/0037: Notify Cloud GA cannot happen without this. The secondary forcing function is regulatory: 10DLC for SMS to US recipients is now mandated by carriers; unregistered traffic is filtered at the network level. Email deliverability has trended the same direction (Google/Yahoo bulk-sender rules effective Feb 2024, enforced since).

This ADR decides the sending-domain architecture, the authentication record posture, the SMS registration path, the reputation-isolation model between Studio and tenant sends, and the bounce/complaint handling contract.

## Decision

### D1 — Sending-domain architecture: subdomains per send-type

The Studio's apex domain (`honeydrunkstudios.com`, registrar-managed via Cloudflare per ADR-0029) is **not** used for bulk outbound. Instead:

- `mail.honeydrunkstudios.com` — Studio-owned transactional mail (operational, account, billing, password reset).
- `notify.honeydrunkstudios.com` — Notify Cloud platform sends on behalf of tenants who do **not** bring their own domain.
- `tenant-domain.example.com` — tenants who **do** bring their own domain delegate DKIM to Notify Cloud and continue to use their own MAIL FROM (covered in D5).

Splitting transactional from platform sends is reputation isolation: a deliverability issue on `notify.` does not contaminate `mail.`, and vice versa. The apex `honeydrunkstudios.com` is reserved for human correspondence and marketing — its SPF/DMARC posture is described below but its sending volume stays minimal.

For SMS: a single toll-free number for Studio transactional traffic; Notify Cloud tenants are 10DLC-registered with their own brand and campaign (D6).

### D2 — Email authentication: full SPF + DKIM + DMARC at strict policy

Every sending subdomain (D1) gets the full record set:

- **SPF** (`v=spf1 ...`) — declares the ESP's sending IPs only; `~all` during warmup, `-all` once reputation is established (≥30 days of clean sending).
- **DKIM** — 2048-bit RSA keys (one per ESP-relationship, rotated annually per ADR-0006 lifecycle). Selectors namespaced per ESP (`s1._domainkey.notify`).
- **DMARC** — published on the apex (`_dmarc.honeydrunkstudios.com`) covering subdomains. Initial policy `p=quarantine` with `pct=100` after 14 days of `p=none` aggregate-report observation. Target steady state is `p=reject`. Reporting addresses (`rua`/`ruf`) route to a Studio-owned inbox monitored by the bounce/complaint Node (D8).
- **BIMI** is deferred. Requires VMC certificate procurement; revisited if a tenant requires it.
- **MTA-STS** and **TLS-RPT** are published at `p=enforce` for `mail.` and `notify.` from day one. Cloudflare DNS makes this near-free.

All records are managed in the Cloudflare zone (ADR-0029 portal-managed at v1; this ADR does not force the IaC follow-up).

### D3 — Email service provider (ESP): choose one default + one fallback

The Grid adopts **one primary ESP** for transactional and platform sends and keeps a **second wired but cold** for failover. The primary is selected on three criteria: subaccount-per-tenant support (reputation isolation, D5), competitive per-message pricing at low volume, and a clean DKIM-delegation flow.

The current shortlist (decided in a follow-up implementation packet, not in this ADR text):

- **Postmark** — best transactional reputation, weak subaccount model. Likely cold fallback.
- **AWS SES** — cheapest at scale, requires more deliverability operations work.
- **Resend** — best modern DX, subaccount/tenant model is straightforward; primary candidate.

The pick is operational, not architectural; the ADR commits to the **shape** (primary + cold fallback, subaccount-per-tenant capable) and defers the vendor pick to an implementation note. Either way the **Notify** Node's ESP slot is a single interface (`IEmailDeliveryProvider`) with vendor-specific backings, so the choice is reversible at the cost of one rotation of DKIM keys.

### D4 — SMS: 10DLC for US + a single toll-free number for Studio transactional

- **Studio transactional SMS** (low volume, account/operational) — one toll-free number registered and verified through the SMS provider (Twilio likely, as a default; subject to the same primary/fallback shape as email).
- **Notify Cloud tenant SMS** — 10DLC registered per tenant brand. Tenants complete a 10DLC brand/campaign registration as part of onboarding to the SMS feature; without it, the tenant cannot send US SMS through Notify Cloud. The Notify Cloud onboarding flow gates the feature behind verified registration.
- **International SMS** — out of scope for v1 except as it falls out of the chosen provider's default coverage. Specific country compliance (UK 7-day rule, France ADCs, etc.) is a per-feature ADR follow-up.
- **Long codes (non-toll-free)** are not used. They are heavily filtered for transactional traffic on US carriers.

### D5 — Tenant identity options: platform send vs. delegated DKIM

Notify Cloud tenants get two choices:

- **Platform send** (`notify.honeydrunkstudios.com`) — the simple default. The tenant's `From:` is `notify-<tenant-id>@notify.honeydrunkstudios.com`; reply-to may be a tenant-provided address. The reputation of `notify.` is shared across the Notify Cloud tenant base.
- **Delegated DKIM** (tenant's own `MAIL FROM`) — the tenant adds CNAME records pointing DKIM selectors at the Notify Cloud DKIM keys for their domain. `From:` is the tenant's domain. Reputation is the tenant's own. Required for tenants with existing sender reputation they want to keep, and for any tenant sending more than a low-volume threshold (so a single bad-actor tenant does not corrupt the shared `notify.` reputation).

The **shared-platform option is rate-limited** below the bad-actor-blast-radius threshold; above it, tenants must move to delegated DKIM. The threshold is a Notify Cloud tier feature, not an ADR-level fixed number.

ESP subaccount-per-tenant (D3) is the implementation mechanism for reputation isolation regardless of which identity option the tenant uses.

### D6 — Bounce, complaint, and unsubscribe handling: a Notify primitive

Every send returns a deliverability outcome over time: accepted, deferred, bounced (hard/soft), complained, unsubscribed. Each ESP exposes this differently; Notify normalizes via an internal contract:

- `IDeliverabilityFeedbackSink` (new Abstractions interface in `HoneyDrunk.Notify.Abstractions`) — receives normalized `DeliverabilityEvent` records (`PrincipalId`/`TenantId`/`MessageId`/`Outcome`/`ProviderRawCode`).
- The default sink writes to the Notify durable store (Tier 1 per ADR-0036) and emits a domain event onto the Service Bus default topic per ADR-0028.
- **Hard bounces and complaints suppress the recipient** at the Notify level. Suppression is per-tenant (a tenant's bounce on a recipient does not suppress another tenant's send to that recipient), with a **platform-wide override list** for known abuse traps and complaint-honeypot addresses.
- **Unsubscribes** are part of suppression. List-Unsubscribe (one-click, RFC 8058) is mandatory on bulk sends and on every Notify Cloud platform send. Transactional sends are exempt by RFC but Notify still emits the header for safety.

### D7 — Warmup posture

`notify.honeydrunkstudios.com` and the toll-free SMS number begin sending under an **explicit warmup ramp**:

- Email warmup: start with ≤50 messages/day to engaged recipients only; double daily until target volume is reached or a complaint threshold is crossed (0.1% complaint rate target steady state, 0.3% warmup ceiling). The ESP's warmup automation is used where available.
- SMS warmup: bounded by 10DLC throughput tier; brand-level throughput increases follow the carrier ladder over weeks.
- The Studio's transactional `mail.` subdomain inherits reputation from whatever ESP-managed shared pool the Studio currently sends from; not a from-zero warmup.

Warmup status is tracked in `catalogs/grid-health.json` (new field, `sender_reputation_status`).

### D8 — Reporting and feedback-loop inbox

`postmaster@honeydrunkstudios.com` and `abuse@honeydrunkstudios.com` are configured per RFC 2142 and route to a monitored inbox (operational, not customer-facing). DMARC `rua` aggregate reports route to a parsed-and-summarized endpoint (delegated to a third-party DMARC report aggregator at v1; in-house parsing is a follow-up if volume warrants).

Feedback Loop (FBL) signups with major mailbox providers (Gmail Postmaster Tools, Microsoft SNDS, Yahoo CFL) are completed for `notify.` and `mail.` as part of the warmup.

### D9 — Privacy and PII in headers

Outbound message envelopes (`Message-ID`, `Return-Path`, custom headers added by Notify) **must not** contain tenant-identifying information beyond the opaque per-tenant subaccount identifier from the ESP. A tenant's recipient should not be able to enumerate other tenants by inspecting headers.

This is a deliberate boundary against the Notify Node leaking multi-tenant structure to recipients. Headers used for support correlation (`X-Notify-Message-Id`) are opaque tokens, not concatenated `tenant-id:message-id` strings.

### D10 — Non-email/SMS channels

Push (APNs/FCM), in-app, and webhooks are out of scope for this ADR. Push has its own identity model (APNs key, FCM project) handled in the future mobile-IAP/platform ADRs. Webhooks are tenant-configured destinations; their authenticity model (signing secrets, HMAC headers) lives in a future Notify Cloud webhook ADR.

## Consequences

### Affected Nodes

- **HoneyDrunk.Notify** — gains `IDeliverabilityFeedbackSink` in Abstractions; default backing wires to ESP normalization; bounce/complaint/unsubscribe persistence becomes a durable concern (Tier 1 per ADR-0036).
- **HoneyDrunk.Communications** — no contract change; consumes the new feedback signal where decision-orchestration depends on suppression state.
- **HoneyDrunk.Notify.Cloud** — gains tenant-onboarding gates for 10DLC registration and DKIM delegation; gains tier-tied throughput limits keyed off warmup state.
- **HoneyDrunk.Vault** — stores ESP API keys, DKIM private keys (per-selector, rotated per ADR-0006), and SMS provider credentials.
- **Cloudflare zone** (per ADR-0029) — gains the full DNS record set across `mail.`, `notify.`, and apex DMARC/MTA-STS/TLS-RPT.
- **HoneyDrunk.Architecture** — `catalogs/grid-health.json` schema gains `sender_reputation_status`.

### Invariants

Adds two:

- **Invariant: every sending subdomain has SPF + DKIM + DMARC in published state, with DMARC at minimum `p=quarantine`.** A subdomain without the full record set is forbidden from being a `MAIL FROM`.
- **Invariant: bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe.** Transactional sends emit it as best practice.

### Operational Consequences

- DMARC aggregate reports start arriving immediately upon publication. A third-party aggregator subscription (cost: low) is needed within the first week to make them useful.
- 10DLC registration is a 1–4 week clock per tenant brand. Notify Cloud onboarding documentation must set this expectation up front.
- DKIM key rotation is now a recurring Studio operator task (annual minimum, per ADR-0006). Automated via Notify; the operator confirms the new selector is published before retiring the old.
- A small population of recipients on aggressive corporate filters will reject `notify.` mail until warmup completes. Acceptable; the first Notify Cloud tenant onboarding will be against a known-engaged audience to bootstrap reputation.
- `abuse@honeydrunkstudios.com` is now a live channel; Studio operator must monitor it. Volume should be near zero with the above posture; spikes are an incident.

### Follow-up Work

- Cut the ESP primary/fallback pick from the D3 shortlist; record as an implementation note (not a new ADR unless the shape changes).
- Author the per-Node `dr-runbook.md` (ADR-0036) inclusion of ESP and DKIM-key restore procedures.
- Publish DNS records for `mail.` and `notify.` (Cloudflare portal per ADR-0029).
- Author Notify Cloud onboarding documentation covering 10DLC and DKIM delegation.
- Wire `IDeliverabilityFeedbackSink` and one default backing in Notify; canary covers the round-trip from send to suppression.
- Author the future mobile push (APNs/FCM) and Notify Cloud webhook authenticity ADRs (deferred per D10).

## Alternatives Considered

### Send everything from the apex `honeydrunkstudios.com`

Rejected. Reputation isolation is the entire point of the subdomain split. Apex sending mixes transactional Studio mail with tenant platform mail; a single bad-actor tenant complaint storm would degrade Studio account/operational deliverability.

### Skip DMARC at strict policy; stay at `p=none`

Rejected. `p=none` is for observation only; it offers no protection and signals to recipient filters that the domain isn't serious about authentication. Major mailbox providers (Gmail, Yahoo) increasingly require enforcement for bulk senders. Strict policy is the steady state; this ADR records the staged path to it.

### Use the Apex for marketing too

Out of scope but worth recording: marketing sends, when they exist, get **their own** subdomain (`news.honeydrunkstudios.com` or similar) and **their own** reputation. Mixing marketing with transactional is the canonical deliverability mistake.

### Tenant-managed DNS from day one (no shared platform `notify.` subdomain)

Rejected. Requires every tenant to complete a DNS configuration before sending a single message; an unacceptable onboarding friction floor. The two-option model (platform send default + delegated DKIM opt-in) is the standard SaaS pattern.

### Skip 10DLC and use long codes for SMS

Rejected. US carriers filter unregistered long-code traffic for transactional sends; deliverability is near zero for tenants whose recipients are on Verizon/AT&T/T-Mobile. 10DLC is the only viable path for tenant-branded US SMS at this point.

### Defer all deliverability work until first Notify Cloud tenant signs

Rejected. DMARC alignment, DKIM key publication, and ESP warmup are 30–60-day clocks at minimum; deferring them past the signing of the first tenant means the first tenant ships with no deliverability posture. Decide and execute pre-GA.
