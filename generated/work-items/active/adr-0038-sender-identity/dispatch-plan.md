# Dispatch Plan: Outbound Sender Identity and Deliverability (ADR-0038)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0038 acceptance).
**Trigger:** ADR-0038 (Outbound Sender Identity and Deliverability) — Proposed 2026-05-21, part of the 2026-05-21 batch of cross-cutting Grid-gap ADRs. Scoped now so the packet set is ready when the ADR lands. The forcing function per ADR-0038's Context is the same as ADR-0036/0037: Notify Cloud GA (ADR-0027) cannot happen without a defensible sending-reputation posture — "what's the sending reputation" is the first paying-tenant onboarding question after RPO and billing. The secondary forcing function is regulatory: 10DLC for US SMS is carrier-mandated, and Google/Yahoo bulk-sender rules (effective Feb 2024) are enforced.
**Type:** Multi-repo. Most work lands in `HoneyDrunk.Architecture` (the ADR flip, the `sender_reputation_status` catalog field, the ESP/SMS implementation note, the DNS / reporting / ESP-provisioning walkthroughs, the Notify Cloud onboarding doc, the `hive-sync` extension). Three packets land code in `HoneyDrunk.Notify` (the `IDeliverabilityFeedbackSink` contract, its default backing, the List-Unsubscribe / PII-safe-envelope work). Three `Actor=Human` portal/console packets are tracked against `HoneyDrunk.Architecture`.
**Sector:** Ops.
**Site sync required:** No. Sender-identity DNS records, ESP configuration, and deliverability posture are operational artifacts, not public-facing content on the Studios marketing site. Re-evaluate only if a future Notify Cloud marketing page on the Studios site makes a deliverability claim publicly — that would be a separate site-sync packet.

**Rollback plan:**
- Architecture-side docs/catalog packets (00, 01, 02, 08, 10) revert cleanly via `git revert` — the ADR flip, the two invariants, the `sender_reputation_status` field, the ESP/SMS note, the Notify Cloud onboarding doc, and the `hive-sync` extension are all docs/text/catalog edits with no runtime consumer. Reverting `sender_reputation_status` is safe; `hive-sync` is the only reader and packet 10 adds that reader — revert both together if rolling back.
- The Notify code packets (05, 06, 07): packet 05 is an additive Abstractions change (a new interface + record) — reverting removes them; nothing else compiles against them until 06/07 land, so revert in reverse order (07, 06, 05). Packet 06's suppression store and 07's headers are additive runtime behavior; reverting removes the behavior with no migration concern (the suppression store is new, not a schema change to existing state). None of the three add a transport/Service Bus dependency, so there is no infrastructure to unwind.
- The three `Actor=Human` packets (03, 04, 09): "reverting" published DNS records, an ESP account, or a toll-free SMS registration is not a `git revert` — these are forward-only operational acts. If they are not yet done, the steady state is "no deliverability posture yet," which is the pre-ADR baseline. Removing a published DMARC record or de-provisioning an ESP account is an operational decision, not a packet rollback. The walkthrough docs themselves revert via `git revert`.

## Summary

ADR-0038 sets the Grid-wide outbound sender-identity and deliverability policy: a sending-domain subdomain split for reputation isolation — `mail.` (Studio transactional), `notify.` (Notify Cloud platform), tenant-delegated DKIM (D1); full SPF + DKIM + DMARC at staged-strict policy on every sending subdomain plus MTA-STS / TLS-RPT (D2); one primary ESP + one cold fallback, subaccount-per-tenant capable, vendor pick deferred to an implementation note (D3); 10DLC for US tenant SMS + a single Studio toll-free number (D4); two tenant email identity options — platform send vs delegated DKIM (D5); bounce/complaint/unsubscribe handling as a Notify primitive via `IDeliverabilityFeedbackSink` with per-tenant suppression (D6); a staged warmup posture tracked in `grid-health.json` (D7); a reporting and feedback-loop inbox (D8); PII-safe outbound headers (D9); and the explicit deferral of push/in-app/webhook channels (D10).

This initiative ships **11 packets** (`00`–`10`) across **three waves**:

- **Wave 1** — governance + foundational artifacts: ADR acceptance + the two deliverability invariants (00), the `sender_reputation_status` catalog field (01), the ESP/SMS provider implementation note (02). 01 and 02 run in parallel after 00.
- **Wave 2** — the human reporting work and the Notify Abstractions contract: the reporting-inbox and feedback-loop walkthrough (04, `Actor=Human`) and the `IDeliverabilityFeedbackSink` contract addition (05). Both run in parallel after Wave 1 — 04 needs the ESP pick (02), 05 needs only the ADR accepted (00).
- **Wave 3** — the Notify backing code, the human DNS + ESP provisioning, and the remaining Architecture docs: the default feedback-sink backing + suppression (06), the List-Unsubscribe / PII-safe-envelope work (07), the Notify Cloud onboarding doc (08), the ESP + SMS provisioning + DKIM keys (09, `Actor=Human`), the Cloudflare sender-identity DNS walkthrough (03, `Actor=Human`), and the `hive-sync` drift extension (10). 06 and 07 both depend on 05; 03 depends on 09 (the DKIM selectors); 08/10 are independent Architecture work. Packet 03 was moved here from Wave 2 so its DKIM acceptance criterion is satisfiable within its own wave — packet 09 issues the selectors that packet 03's DKIM records need.

## Important constraints (from ADR-0038 itself)

- **Coordinate the DNS work with ADR-0029, do not duplicate it.** ADR-0029 commits Cloudflare as authoritative DNS, portal-managed at v1. ADR-0029 D3 names email records (SPF/DKIM/DMARC) as DNS-only (grey-cloud) by definition. Packet 03's records land in the Cloudflare zone ADR-0029 establishes — packet 03 is the email-record *consumer* of ADR-0029's DNS authority, not a second DNS initiative. **Hard real-world precondition:** `honeydrunkstudios.com` must already be on Cloudflare authoritative DNS (ADR-0029 migration step 1) before packet 03's records are authoritative. ADR-0029 has its own initiative; this is a Human-Prerequisite gate, not a packet dependency.
- **DMARC follows the staged path.** ADR-0038 D2: `p=none` (14-day observation) → `p=quarantine` (pct=100) → `p=reject` (steady state). Packet 03 publishes `p=none` on day one — not `p=quarantine`. The walkthrough documents all three stages.
- **The ESP vendor pick is an operator decision.** ADR-0038 D3 defers the vendor pick to an implementation note (packet 02), naming a shortlist (Resend / AWS SES / Postmark). Packet 02 drafts with the ADR's lean (Resend primary, Postmark cold fallback, Twilio for SMS) but the operator confirms or overrides in the tracking issue before the note is final.
- **No secrets in the repo.** ESP API keys, SMS provider auth tokens, and DKIM **private** keys never enter the repo (invariant 8). DKIM **public** keys / selector records are DNS-resident and public by definition. Keys, when seeded, go into the `HoneyDrunk.Notify` Key Vault per ADR-0005 naming and are read via `ISecretStore` (invariant 9).
- **Notify owns delivery mechanics; Communications owns decision logic.** Invariant 41. ADR-0038 D6 places bounce/complaint suppression *state* "at the Notify level" — a hard bounce is a delivery fact, not a cadence decision. Communications consumes the suppression signal through packet 06's query surface (the message-bus broadcast is deferred — see Out-of-scope); it gets no contract change (ADR-0038 Affected Nodes).
- **Suppression is per-tenant.** ADR-0038 D6: a tenant's bounce on a recipient does not suppress another tenant's send to that recipient. The one exception is the platform-wide override list for known abuse-trap / honeypot addresses. This respects invariant 39 (tenant mechanics at intake/post-dispatch boundaries).
- **Notify Cloud is not scaffolded.** `HoneyDrunk.Notify.Cloud` (ADR-0027, Proposed) does not exist as a repo. Packet 08 authors the *onboarding deliverability documentation* — the 10DLC and DKIM-delegation requirements — as an input to the future Notify Cloud standup initiative. The onboarding *feature code* (the gates, tier-throughput logic) is the standup's work, explicitly deferred. Recorded so the gap is not silently assumed closed.
- **Push / in-app / webhooks are out of scope.** ADR-0038 D10 defers push (APNs/FCM) and webhook authenticity to future ADRs. No packet here touches them.

## Wave Diagram

### Wave 1 — Governance + foundational artifacts

Run packet 00 first (ADR acceptance + the two invariants). Packets 01 and 02 may run in parallel after 00 — 01 is a catalog field, 02 is a docs implementation note; neither depends on the other.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0038** — flip status, add the two deliverability invariants, register the initiative — [`00-architecture-adr-0038-acceptance.md`](00-architecture-adr-0038-acceptance.md)
  - Blocked by: nothing.
- [ ] `HoneyDrunk.Architecture`: Add the `sender_reputation_status` field to `grid-health.json` and seed the sending identities — [`01-architecture-sender-reputation-status-catalog-field.md`](01-architecture-sender-reputation-status-catalog-field.md)
  - Blocked by: Wave 1 — `00` (soft).
- [ ] `HoneyDrunk.Architecture`: Author the ESP and SMS provider implementation note — cut the primary/fallback pick from the D3 shortlist — [`02-architecture-esp-and-sms-provider-implementation-note.md`](02-architecture-esp-and-sms-provider-implementation-note.md)
  - Blocked by: Wave 1 — `00` (soft).

**Wave 1 exit criteria:**
- ADR-0038 reads `**Status:** Accepted`; the two deliverability invariants are in `constitution/invariants.md`; the initiative is registered.
- `catalogs/grid-health.json` carries `sender_reputation_status` with the three v1 sending identities seeded at `not-provisioned`.
- `infrastructure/reference/esp-and-sms-provider-selection.md` records the ESP primary/fallback and SMS provider picks, with the operator's confirmation recorded in the packet-02 tracking issue.

### Wave 2 — Human reporting work + the Notify Abstractions contract (parallel)

Packets 04 and 05 run in parallel after Wave 1. 04 is `Actor=Human` and needs the ESP pick (02); 05 is `Actor=Agent` and needs only the ADR accepted (00).

- [ ] `HoneyDrunk.Architecture`: Author the reporting-inbox and feedback-loop walkthrough — postmaster/abuse, DMARC aggregator, FBL signups — [`04-architecture-reporting-inbox-and-feedback-loops.md`](04-architecture-reporting-inbox-and-feedback-loops.md)
  - Blocked by: Wave 1 — `00` (soft), `02` (soft — the ESP pick shapes the provider-console section).
  - **`Actor=Human` — `human-only` label set.** Mailbox configuration and provider-console signups cannot be delegated.
- [ ] `HoneyDrunk.Notify`: Add `IDeliverabilityFeedbackSink` and the `DeliverabilityEvent` record to `Notify.Abstractions` — [`05-notify-deliverability-feedback-sink-contract.md`](05-notify-deliverability-feedback-sink-contract.md)
  - Blocked by: Wave 1 — `00` (soft).

**Wave 2 exit criteria:**
- `infrastructure/walkthroughs/sender-reporting-and-feedback-loops.md` exists; `postmaster@`/`abuse@` route to a monitored inbox; a DMARC aggregator is subscribed; FBL signups are done (or ESP-owned and confirmed).
- `HoneyDrunk.Notify.Abstractions` exposes `IDeliverabilityFeedbackSink` and `DeliverabilityEvent`; the solution version is bumped (minor); the canary (if any) is updated; `catalogs/contracts.json` gains the two new types in the `honeydrunk-notify` block.

### Wave 3 — Notify backing code + human DNS/ESP provisioning + remaining docs

Packets 06 and 07 both depend on packet 05. Packet 03 depends on packet 09 (the DKIM selectors); packet 09 runs first within this wave. Packets 08 and 10 are independent (10 depends on 01). Everything in this wave can start once its own dependencies are met.

- [ ] `HoneyDrunk.Notify`: Implement the default `IDeliverabilityFeedbackSink` backing — deliverability-feedback persistence and per-tenant suppression — [`06-notify-default-feedback-sink-backing-and-suppression.md`](06-notify-default-feedback-sink-backing-and-suppression.md)
  - Blocked by: Wave 2 — `05` (hard — implements the contract).
- [ ] `HoneyDrunk.Notify`: Emit RFC 8058 one-click List-Unsubscribe headers and enforce PII-safe outbound envelopes — [`07-notify-list-unsubscribe-header-and-pii-safe-envelopes.md`](07-notify-list-unsubscribe-header-and-pii-safe-envelopes.md)
  - Blocked by: Wave 2 — `05` (hard — the one-click endpoint produces a `DeliverabilityEvent`).
- [ ] `HoneyDrunk.Architecture`: Author the Notify Cloud onboarding deliverability documentation — 10DLC and DKIM delegation — [`08-architecture-notify-cloud-onboarding-deliverability-doc.md`](08-architecture-notify-cloud-onboarding-deliverability-doc.md)
  - Blocked by: Wave 1 — `00` (soft), `02` (soft — the SMS/ESP picks shape the concrete onboarding steps).
- [ ] `HoneyDrunk.Architecture`: Provision the ESP account, generate DKIM keys, register the Studio toll-free SMS number — [`09-architecture-esp-and-sms-provisioning-and-dkim-keys.md`](09-architecture-esp-and-sms-provisioning-and-dkim-keys.md)
  - Blocked by: Wave 1 — `02` (hard — the ESP and SMS provider must be picked).
  - **`Actor=Human` — `human-only` label set.** ESP/SMS account creation, KYC, and toll-free verification cannot be delegated. Runs before packet 03 within Wave 3 — it issues the DKIM selectors packet 03 publishes.
- [ ] `HoneyDrunk.Architecture`: Author the Cloudflare sender-identity DNS walkthrough and publish SPF/DKIM/DMARC/MTA-STS records — [`03-architecture-cloudflare-sender-identity-dns-walkthrough.md`](03-architecture-cloudflare-sender-identity-dns-walkthrough.md)
  - Blocked by: `02` (hard — the ESP pick determines the SPF include-domain and DKIM selector namespace), Wave 3 — `09` (hard — the DKIM selector records come from packet 09's ESP account), `00` (soft).
  - **`Actor=Human` — `human-only` label set.** Cloudflare-portal DNS record creation cannot be delegated. Real-world precondition: `honeydrunkstudios.com` on Cloudflare authoritative DNS (ADR-0029).
- [ ] `HoneyDrunk.Architecture`: Extend `hive-sync` to reconcile `sender_reputation_status` and surface DMARC/warmup drift — [`10-architecture-hive-sync-sender-reputation-drift.md`](10-architecture-hive-sync-sender-reputation-drift.md)
  - Blocked by: Wave 1 — `01` (hard — the `sender_reputation_status` field must exist to reconcile).

**Wave 3 exit criteria:**
- `HoneyDrunk.Notify` has a default `IDeliverabilityFeedbackSink` backing — deliverability-feedback persistence, per-tenant suppression with a platform-wide override list, the send-path suppression check, and the round-trip integration test. No message-bus broadcast (deferred — see Out-of-scope).
- `infrastructure/walkthroughs/cloudflare-sender-identity-dns.md` exists; SPF/DKIM/DMARC/MTA-STS/TLS-RPT records are published for `mail.`/`notify.` and the apex DMARC record; DMARC is at `p=none` (observation); DKIM is published using packet 09's selectors.
- `HoneyDrunk.Notify` email sends carry RFC 8058 one-click List-Unsubscribe headers; the one-click endpoint produces `Unsubscribed` events; outbound envelopes are PII-safe (opaque tokens, no tenant concatenation).
- `infrastructure/reference/notify-cloud-onboarding-deliverability.md` exists, covering 10DLC and the D5 identity options, with the onboarding-feature deferral to the Notify Cloud standup marked.
- The primary ESP account exists with `mail.`/`notify.` verified and DKIM selectors issued; the Studio toll-free SMS number is registered; secrets are seeded into the Notify Key Vault or their destination recorded.
- `hive-sync` reconciles `sender_reputation_status` and surfaces DMARC/SPF/warmup drift as board-item findings.

## Wave-ordering note: 03 vs 09

Packet 03 (DNS) and packet 09 (ESP provisioning) are **both in Wave 3**, with packet 03 holding a hard `dependencies:` edge on packet 09. Packet 03's DKIM record step consumes the DKIM selectors packet 09's ESP account issues, so packet 09 runs first within the wave and packet 03 publishes the full record set — SPF, DKIM, DMARC, MTA-STS, TLS-RPT — in a single pass. An earlier revision placed packet 03 in Wave 2, which created a wave inversion: packet 03's DKIM acceptance criterion could not be satisfied within Wave 2 because the selectors did not yet exist. Moving packet 03 to Wave 3 alongside packet 09 resolves that — the DKIM criterion is now satisfiable within packet 03's own wave.

## Out-of-scope / deferred items

- **HoneyDrunk.Notify.Cloud onboarding feature code.** `HoneyDrunk.Notify.Cloud` (ADR-0027, Proposed) is not scaffolded — its repo does not exist. Packet 08 authors the *onboarding deliverability documentation* (10DLC, DKIM delegation requirements); the onboarding *gates* and the tier-tied throughput limits keyed off warmup state are the **Notify Cloud standup initiative's** work. ADR-0038's Affected Nodes frames Notify Cloud's onboarding gates as a Notify-Cloud-Node concern. Recorded so the gap is not silently assumed closed.
- **The ESP cold-fallback wiring.** ADR-0038 D3 commits a primary + a "second wired but cold" ESP. Packet 02 records the fallback pick; packet 09 provisions the *primary*. Actually wiring the cold fallback as a switchable `IEmailDeliveryProvider` backing is deferred — it is a Notify provider-package follow-up (a `HoneyDrunk.Notify.Providers.Email.*` package for the fallback vendor), best done when there is real sending volume that justifies a tested failover path. Flagged so it is not forgotten.
- **The SPF `~all` → `-all` and DMARC `p=none` → `p=quarantine` → `p=reject` transitions.** Packet 03 publishes the day-one records (`~all`, `p=none`) and the walkthrough documents the staged transitions, but the *transitions themselves* are operational follow-up edits made after the D2 windows elapse (30 days clean sending for SPF; 14 days observation for DMARC). They are not packets — `hive-sync` (packet 10) surfaces a drift finding when an identity is overdue to advance, which is the mechanism that prompts the operator.
- **The warmup ramp execution.** ADR-0038 D7's warmup ramp (≤50 messages/day doubling) is an operational ramp coordinated with the first real Notify Cloud tenant sends. Packet 09 stands up the accounts but explicitly does not start the ramp. The ramp's execution and its `grid-health.json` `sender_reputation_status` updates are operational work that pairs with the first tenant onboarding, not a packet here.
- **In-house DMARC report parsing.** ADR-0038 D8 delegates DMARC aggregate-report parsing to a third-party aggregator at v1 and names in-house parsing as "a follow-up if volume warrants." Not a packet here.
- **The deliverability-event message-bus broadcast.** ADR-0038 D6's prose describes the default feedback sink eventually emitting a domain event onto a message bus so Communications can subscribe. Packet 06 does **not** do this: the `HoneyDrunk.Notify` runtime currently references only `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Standards`, and `Microsoft.Extensions.*` — it has no transport/Service Bus dependency, and adding one is out of scope for a feedback-persistence packet. Packet 06 persists deliverability feedback and maintains the per-tenant suppression list; Communications reads suppression state through packet 06's query surface until the bus path exists. The broadcast rejoins scope once Notify takes a transport dependency — cross-reference ADR-0042's idempotency/transport work, the natural home for that dependency.
- **Push (APNs/FCM) and webhook authenticity ADRs.** ADR-0038 D10 explicitly defers these to future ADRs. Not in this initiative.
- **DNS-as-IaC for the sender-identity records.** ADR-0029 D2 defers DNS-as-IaC Grid-wide; the sender-identity records inherit that deferral — portal-managed at v1.

## After filing — board fields and blocking relationships

The `file-work-items` pipeline sets Status, Wave, Node, Tier, Actor, Initiative, and ADR fields from frontmatter and wires `addBlockedBy` automatically from each packet's `dependencies:` array. For reference, the blocking graph:

- `01` blocked-by `00` (soft)
- `02` blocked-by `00` (soft)
- `03` blocked-by `00` (soft), `02` (hard), `09` (hard)
- `04` blocked-by `00` (soft), `02` (soft)
- `05` blocked-by `00` (soft)
- `06` blocked-by `05` (hard)
- `07` blocked-by `05` (hard)
- `08` blocked-by `00` (soft), `02` (soft)
- `09` blocked-by `02` (hard)
- `10` blocked-by `01` (hard)

**Actor:** packets 00, 01, 02, 05, 06, 07, 08, 10 are `Actor=Agent` (ADR flip, catalog field, docs notes, the Notify contract + backing + header code, the onboarding doc, the `hive-sync` extension — all delegable). **Packets 03, 04, 09 are `Actor=Human`** — they carry the `human-only` label because Cloudflare-portal DNS record creation, mailbox/provider-console configuration, and ESP/SMS account provisioning with KYC and toll-free verification are the *entire* work item, not a side prerequisite.

Verify a wave landed by checking The Hive for the new items + their blocked-by chains, not by inspecting the workflow log.

## Notes

- **Acceptance precedes flip.** ADR-0038 stays Proposed until packet 00's PR merges.
- **The two new invariants land in packet 00**, not in a separate `constitution/invariants.md` packet — (1) every sending subdomain has SPF + DKIM + DMARC with DMARC ≥ `p=quarantine`; (2) bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe. They are numbered **65** and **66**. The current highest invariant in `constitution/invariants.md` is 51 (verified — 1-51 all present). Invariant numbers **65-66** are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.
- **One new runtime contract.** This initiative adds `IDeliverabilityFeedbackSink` + `DeliverabilityEvent` to `HoneyDrunk.Notify.Abstractions` (packet 05). Packet 05's scope and acceptance criteria now explicitly include appending the two types to the `honeydrunk-notify` block's `interfaces` array in `catalogs/contracts.json` — note that file lives in `HoneyDrunk.Architecture`, so it is a separate cross-repo commit alongside the Notify code change.
- **Coordination with ADR-0029.** The DNS work (packet 03) lands in the Cloudflare zone ADR-0029 establishes. ADR-0029 is itself Proposed with its own initiative; packet 03's Human Prerequisites gate on the `honeydrunkstudios.com` apex being on Cloudflare authoritative DNS. The two initiatives are sequenced by that real-world precondition, not by a packet edge.
- **No new repo, no new Node.** This initiative ships an ADR flip + two invariants, one catalog field, one runtime contract + its backing + header code in an existing Node (`HoneyDrunk.Notify`), four infrastructure walkthroughs / docs, one onboarding doc, and one `hive-sync` extension. `catalogs/nodes.json` and `relationships.json` are untouched — sending identities are vendor/DNS surfaces, not Nodes.
- **No Azure/vendor resources are provisioned by an agent.** All ESP, SMS provider, Cloudflare DNS, and mailbox configuration is `Actor=Human` (packets 03, 04, 09). The portal/console steps are written as UI walkthroughs per the developer's preference, not CLI.
- **Cost.** ADR-0038 Operational Consequences: the DMARC aggregator subscription is low-cost (free tier sufficient at v1). The ESP and SMS provider plans default to the cheapest viable tier — the Grid sends trivial volume at v1. 10DLC registration carries a per-brand fee and a 1–4 week clock. The dollar cost is the recorded price of "answering the sending-reputation question defensibly when the first Notify Cloud tenant asks."
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).

## Archival

Per ADR-0008 D10, when every **filed and in-scope** packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0038-sender-identity/` folder moves to `archive/adr-0038-sender-identity/` in a single commit. Partial archival is forbidden.

The three `Actor=Human` packets (03, 04, 09) are in-scope and NOT exempt from the archival gate — they have a concrete completion path (publish the records, configure the inbox, provision the accounts). The initiative's archival waits for them to be `Done`.

## Revision history

- **2026-05-22 initial scope** — 11 packets across three waves. Drafted ahead of ADR-0038 acceptance; packets are pending-acceptance drafts, not yet filed as GitHub Issues. Notify Cloud onboarding feature code, the ESP cold-fallback wiring, the SPF/DMARC staged transitions, the warmup ramp execution, in-house DMARC parsing, and the push/webhook ADRs are recorded as out-of-scope / deferred follow-ups.
