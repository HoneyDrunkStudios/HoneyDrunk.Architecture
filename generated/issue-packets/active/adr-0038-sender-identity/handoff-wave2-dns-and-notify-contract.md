# Handoff — Wave 1 → Wave 2: reporting work + the Notify deliverability contract

**Read once at the Wave 1 → Wave 2 transition. Immutable (invariant 24).**

## What Wave 1 produced

- **ADR-0038 is Accepted.** Status flipped; `adrs/README.md` updated. The two new deliverability invariants are in `constitution/invariants.md` as invariants **65** and **66** (the current highest invariant is 51; the 65-66 block is pre-reserved for ADR-0038's 12-ADR batch — if a non-batch invariant above 51 landed before merge, the block shifted upward):
  1. *(65) Every sending subdomain has SPF + DKIM + DMARC in published state, with DMARC at minimum `p=quarantine`.* A subdomain without the full record set is forbidden as a `MAIL FROM`. Steady-state target `p=reject`; the staged path is permitted but no sending subdomain operates below `p=quarantine` once it leaves the observation window.
  2. *(66) Bulk and Notify-Cloud-platform sends emit RFC 8058 one-click List-Unsubscribe.* Transactional sends emit it as best practice.
- **`catalogs/grid-health.json` has the `sender_reputation_status` field** (packet 01), with three v1 sending identities seeded at `status: not-provisioned`: `mail.honeydrunkstudios.com`, `notify.honeydrunkstudios.com`, `studio-toll-free-sms`. Each email entry tracks `dmarc_policy` and `spf_qualifier`.
- **The ESP and SMS provider are picked** (packet 02). Read `infrastructure/reference/esp-and-sms-provider-selection.md` for the confirmed picks — the ADR's lean is Resend (primary ESP), Postmark (cold fallback), Twilio (SMS), but the operator may have overridden; the note's header and the packet-02 tracking issue carry the final decision. **Wave 2 packets 03 and 04 must read the confirmed pick — do not assume the ADR lean.**

## Wave 2 packets

Two packets, run in parallel:

- **Packet 04 (`Actor=Human`)** — reporting-inbox and feedback-loop walkthrough. `postmaster@`/`abuse@` mailboxes, a DMARC aggregator subscription, FBL signups.
- **Packet 05 (`Actor=Agent`)** — adds `IDeliverabilityFeedbackSink` + `DeliverabilityEvent` to `HoneyDrunk.Notify.Abstractions`.

The Cloudflare DNS walkthrough (packet 03) is **not** in Wave 2 — it moved to Wave 3 so its DKIM acceptance criterion is satisfiable alongside packet 09 (which issues the DKIM selectors). See the Wave 2 → Wave 3 handoff.

## Critical context for Wave 2 execution

### For packet 04 (the human reporting work)

- **DMARC starts at `p=none`.** ADR-0038 D2's staged path is mandatory: `p=none` (14-day aggregate-report observation) → `p=quarantine` (pct=100) → `p=reject`. Packet 04's DMARC aggregator subscription receives the `p=none` observation reports.
- **Packet 03's DMARC `rua` address and packet 04's DMARC aggregator endpoint must match.** Packet 03 runs in Wave 3; packet 04 records the `rua` endpoint address for packet 03 to publish. The two walkthroughs cross-reference each other.
- **No secrets in the repo** (invariant 8). Mailbox passwords, aggregator API keys, provider-console credentials are never committed.

### For packet 05 (the Notify Abstractions contract)

- `HoneyDrunk.Notify.Abstractions` is an **Abstractions package** — invariant 1: zero HoneyDrunk runtime dependencies, only `Microsoft.Extensions.*` abstractions plus the `HoneyDrunk.Kernel.Abstractions` contract package it already references for `TenantId`.
- Add **only the contract** — `IDeliverabilityFeedbackSink` (interface) and `DeliverabilityEvent` (record). The default backing is Wave 3 packet 06.
- `DeliverabilityEvent` carries `TenantId`, `RecipientAddress` (a `string` — the `Recipient.Address` value; there is **no** `PrincipalId` type in Notify.Abstractions or Kernel.Abstractions, do not invent one), `MessageId` (reuse the existing `NotificationId` type — do not introduce a parallel id), `Outcome`, `ProviderRawCode`, and an occurrence timestamp.
- **Reconcile the outcome enum before adding one.** The package already has `DeliveryOutcome`, `DeliveryStatus`, `FailureKind`. Check whether one covers the D6 outcome set (accepted / deferred / soft-bounce / hard-bounce / complained / unsubscribed) before adding a new `DeliverabilityOutcome` enum. The hard/soft bounce distinction is load-bearing — D6 suppresses on hard bounce and complaint only.
- **Grid naming rule:** records drop the `I` prefix (`DeliverabilityEvent`), interfaces keep it (`IDeliverabilityFeedbackSink`). Records use `init` members, not positional syntax.
- **Packet 05 is the first packet on the `HoneyDrunk.Notify` solution in this initiative — it bumps the version** (minor, for a new additive Abstractions surface). Every non-test `.csproj` moves to the same new version (invariant 27). Wave 3 packets 06 and 07 append to the CHANGELOG only — they do not bump again.
- **Update `catalogs/contracts.json`** (in `HoneyDrunk.Architecture`) — append `IDeliverabilityFeedbackSink` (`kind: interface`) and `DeliverabilityEvent` (`kind: type`) to the `honeydrunk-notify` block's `interfaces` array. This is a cross-repo edit.
- If `HoneyDrunk.Notify.Abstractions` has a contract-shape canary, update it for the intentional addition.

## Wave 2 exit criteria

- `postmaster@`/`abuse@` route to a monitored inbox; a DMARC aggregator is subscribed; FBL signups done or confirmed ESP-owned; the `rua` endpoint address is recorded for packet 03.
- `HoneyDrunk.Notify.Abstractions` exposes `IDeliverabilityFeedbackSink` and `DeliverabilityEvent`; solution version bumped; `catalogs/contracts.json` `honeydrunk-notify` block updated; canary (if any) updated.
