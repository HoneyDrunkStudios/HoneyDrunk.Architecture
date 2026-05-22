---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0038", "wave-2"]
dependencies: ["packet:00", "packet:02"]
adrs: ["ADR-0038"]
accepts: ["ADR-0038"]
wave: 2
initiative: adr-0038-outbound-sender-identity-and-deliverability
node: honeydrunk-architecture
---

# Author the reporting-inbox and feedback-loop walkthrough — postmaster/abuse, DMARC aggregator, FBL signups

## Summary
Author `infrastructure/walkthroughs/sender-reporting-and-feedback-loops.md` and execute it: configure the RFC 2142 `postmaster@` and `abuse@` mailboxes routing to a monitored inbox, subscribe to a third-party DMARC aggregate-report aggregator, and complete the mailbox-provider Feedback Loop (FBL) signups per ADR-0038 D8. `Actor=Human` — mailbox configuration and provider-console signups are portal/console work, and the developer prefers UI walkthroughs over CLI.

## Context
ADR-0038 D8 requires the deliverability feedback surface that makes DMARC and warmup observable:

- `postmaster@honeydrunkstudios.com` and `abuse@honeydrunkstudios.com` configured per RFC 2142, routing to a monitored operational inbox.
- DMARC `rua` aggregate reports route to a parsed-and-summarized endpoint — ADR-0038 D8 delegates this to a third-party DMARC report aggregator at v1 (in-house parsing is a deferred follow-up).
- Feedback Loop (FBL) signups with the major mailbox providers — Gmail Postmaster Tools, Microsoft SNDS, Yahoo CFL — completed for `notify.` and `mail.` as part of warmup.

ADR-0038's Operational Consequences flag two things: (1) DMARC aggregate reports start arriving immediately on DNS publication, so the aggregator subscription is needed "within the first week"; (2) `abuse@honeydrunkstudios.com` becomes a live channel the operator must monitor — volume should be near zero, spikes are an incident.

This packet pairs with packet 03 (the DNS records): packet 03 publishes the DMARC record whose `rua`/`ruf` point at the endpoints this packet configures. The two can run in parallel within Wave 2, but the DMARC `rua` address in packet 03 must match the aggregator endpoint this packet sets up — the walkthroughs cross-reference each other.

This packet depends on packet 02 only loosely — the ESP often provides its own FBL/postmaster tooling, so knowing the ESP shapes the walkthrough's provider-console section. The mailbox routing itself is independent of the ESP pick.

This packet authors a walkthrough doc **and** executes it. No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/sender-reporting-and-feedback-loops.md` (new) — the portal/console walkthrough.
- `catalogs/grid-health.json` — optionally annotate the `sender_reputation_status` entries' `notes` field to record that FBL/reporting is configured.
- The `honeydrunkstudios.com` mailbox configuration and the third-party aggregator / provider-console accounts (not repo artifacts).

## Proposed Work (human-executed, mail provider + Cloudflare + provider consoles)
1. **`postmaster@` and `abuse@` mailboxes** — configure both addresses per RFC 2142. They route to a monitored operational inbox (the walkthrough documents the routing target — a Studio operational mailbox, not customer-facing). If `honeydrunkstudios.com` mail is handled by a mailbox provider, this is a routing-rule / alias step in that provider's admin console; document the click path.
2. **DMARC aggregate-report aggregator** — sign up for a third-party DMARC report aggregator (the walkthrough names candidates — e.g. Postmark's free DMARC monitoring, Dmarcian, URIports, or the ESP's built-in DMARC tooling if the chosen ESP from packet 02 provides one). Record the `rua` endpoint address the aggregator gives — this is the address packet 03's DMARC record must use. Document where the aggregator's summary reports are reviewed.
3. **FBL signups** — complete Feedback Loop registration with the major mailbox providers for `notify.` and `mail.`:
   - **Gmail Postmaster Tools** — add and verify the sending domains.
   - **Microsoft SNDS / JMRP** — register the sending IPs / domains (note: SNDS is IP-based; if the ESP owns the IPs, this may be the ESP's responsibility — the walkthrough clarifies).
   - **Yahoo CFL (Complaint Feedback Loop)** — register the sending domains.
   - The walkthrough documents which signups are Studio-owned vs ESP-owned (shared-pool ESPs often own the IP-level FBL registration).
4. **Document the monitoring expectation** — `abuse@` is a live incident channel per ADR-0038 Operational Consequences; the walkthrough states the operator monitors it and that a complaint spike is an incident.
5. Annotate `grid-health.json` `sender_reputation_status` notes to record reporting/FBL is configured.

## Affected Files
- `infrastructure/walkthroughs/sender-reporting-and-feedback-loops.md` (new)
- `catalogs/grid-health.json` — optional `notes` annotation.

## NuGet Dependencies
None. This packet has no .NET project — it is mailbox/console configuration plus one walkthrough doc.

## Boundary Check
- [x] The walkthrough doc and the optional `grid-health.json` annotation live in `HoneyDrunk.Architecture`.
- [x] No code change in any repo.
- [x] Mailbox and provider-console configuration are vendor surfaces, not Nodes.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/sender-reporting-and-feedback-loops.md` exists as a step-by-step UI walkthrough
- [ ] `postmaster@honeydrunkstudios.com` and `abuse@honeydrunkstudios.com` are configured per RFC 2142 and route to a monitored operational inbox
- [ ] A third-party DMARC aggregate-report aggregator is subscribed; the `rua` endpoint address is recorded and matches (or is handed to) packet 03's DMARC record
- [ ] FBL signups are completed for `notify.` and `mail.` with Gmail Postmaster Tools, Microsoft SNDS/JMRP, and Yahoo CFL — or the walkthrough documents which are ESP-owned and confirms the ESP has registered them
- [ ] The walkthrough records that `abuse@` is a live incident channel the operator monitors
- [ ] `catalogs/grid-health.json` notes (optionally) record reporting/FBL configuration
- [ ] No mailbox password, aggregator API key, or provider-console credential appears in the repo (invariant 8)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Admin access to the `honeydrunkstudios.com` mailbox provider to create `postmaster@` / `abuse@` routing.
- [ ] A decision on the third-party DMARC aggregator (the walkthrough lists candidates; the operator picks one — a free tier is sufficient at v1 per the developer's default-cheapest-tier preference).
- [ ] Accounts at Gmail Postmaster Tools, Microsoft SNDS, and Yahoo CFL — or confirmation from the ESP (packet 02 pick) that it owns the IP-level FBL registration.
- [ ] The monitored operational inbox that `postmaster@` / `abuse@` route to must exist.

## Referenced ADR Decisions
**ADR-0038 D8 — Reporting and feedback-loop inbox.** `postmaster@honeydrunkstudios.com` and `abuse@honeydrunkstudios.com` are configured per RFC 2142 and route to a monitored inbox (operational, not customer-facing). DMARC `rua` aggregate reports route to a parsed-and-summarized endpoint — delegated to a third-party DMARC report aggregator at v1; in-house parsing is a follow-up if volume warrants. Feedback Loop signups with major mailbox providers (Gmail Postmaster Tools, Microsoft SNDS, Yahoo CFL) are completed for `notify.` and `mail.` as part of warmup.

**ADR-0038 Operational Consequences.** "DMARC aggregate reports start arriving immediately upon publication. A third-party aggregator subscription (cost: low) is needed within the first week to make them useful." "`abuse@honeydrunkstudios.com` is now a live channel; Studio operator must monitor it. Volume should be near zero with the above posture; spikes are an incident."

**ADR-0038 D2 — DMARC `rua`/`ruf`.** Reporting addresses route to a Studio-owned inbox monitored by the bounce/complaint handling described in D6/D8.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No mailbox password, aggregator API key, or provider-console credential is committed to the repo. The walkthrough records configuration steps and endpoint addresses (which are not secrets) only.

- **Cross-reference packet 03.** The DMARC `rua` address this packet configures must be the address packet 03's DMARC record publishes. The two walkthroughs reference each other; if packet 03 ran first with a placeholder `rua`, this packet's completion includes correcting it.
- **Cheapest viable tier.** The DMARC aggregator's free tier is sufficient at v1 — the developer's default-cheapest-tier preference applies. Do not subscribe to a paid plan without a concrete reason.
- **Portal/console UI walkthrough.** No CLI. Click-by-click per the developer's preference.
- **Clarify ESP-owned vs Studio-owned FBL.** Shared-pool ESPs often own the IP-level FBL registration (SNDS in particular is IP-based). The walkthrough must not instruct the operator to register IPs the ESP owns.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0038`, `wave-2`

## Agent Handoff

**Objective:** Author the reporting-inbox and feedback-loop walkthrough and execute it — `postmaster@`/`abuse@` mailboxes, a DMARC aggregator subscription, and FBL signups for `notify.` and `mail.`.

**Target:** Tracked against `HoneyDrunk.Architecture`; the work is human-executed in mailbox and provider consoles. `Actor=Human` — `human-only` label set. The walkthrough doc lands in `infrastructure/walkthroughs/`.

**Context:**
- Goal: Stand up the deliverability feedback surface ADR-0038 D8 mandates so DMARC reports and complaint signals are observable.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 2.
- ADRs: ADR-0038 D8 (primary), D2 (the DMARC `rua` endpoint), D6 (the bounce/complaint handling this feedback feeds).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0038 should be Accepted first.
- `packet:02` — soft. The ESP pick shapes the walkthrough's provider-console section (ESP-owned vs Studio-owned FBL); the mailbox routing is ESP-independent.

**Constraints:**
- Cross-reference packet 03 — the DMARC `rua` address must match.
- Cheapest viable aggregator tier (free tier sufficient at v1).
- Portal/console UI walkthrough, no CLI.
- Clarify ESP-owned vs Studio-owned FBL registration.

**Key Files:**
- `infrastructure/walkthroughs/sender-reporting-and-feedback-loops.md` (new)
- `catalogs/grid-health.json` (optional notes annotation)

**Contracts:** None — mailbox/console configuration, no code.
