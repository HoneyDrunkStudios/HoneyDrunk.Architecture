# Handoff — Wave 2 → Wave 3: Notify backing code + ESP provisioning + remaining docs

**Read once at the Wave 2 → Wave 3 transition. Immutable (invariant 24).**

## What Wave 2 produced

- **The reporting and feedback-loop surface exists** (packet 04) — `postmaster@`/`abuse@` route to a monitored inbox; a DMARC aggregator is subscribed; FBL signups are done. The DMARC `rua` endpoint address is recorded for packet 03 to publish.
- **The Notify deliverability contract exists** (packet 05) — `HoneyDrunk.Notify.Abstractions` exposes `IDeliverabilityFeedbackSink` and the `DeliverabilityEvent` record; `catalogs/contracts.json` lists both. The solution version was bumped (minor). Read the new contract before implementing the backing:
  - `IDeliverabilityFeedbackSink.ReceiveAsync(DeliverabilityEvent, CancellationToken)`.
  - `DeliverabilityEvent` carries `TenantId`, `RecipientAddress` (a `string` — the `Recipient.Address` value; there is no `PrincipalId` type), `MessageId` (the existing `NotificationId` type), `Outcome`, `ProviderRawCode`, and an occurrence timestamp.
  - The outcome enum — check whether packet 05 reused an existing type (`DeliveryOutcome`/`DeliveryStatus`/`FailureKind`) or added `DeliverabilityOutcome`. The hard/soft bounce distinction is load-bearing.
- **The sender-identity DNS records are NOT yet published.** Packet 03 (the Cloudflare DNS walkthrough) moved into Wave 3 — it depends on packet 09's DKIM selectors and runs after packet 09 within this wave.

## Wave 3 packets

- **Packet 06 (`Actor=Agent`)** — the default `IDeliverabilityFeedbackSink` backing: deliverability-feedback persistence and per-tenant suppression. **No message-bus broadcast** (deferred). Depends on packet 05.
- **Packet 07 (`Actor=Agent`)** — RFC 8058 one-click List-Unsubscribe headers + PII-safe outbound envelopes. Depends on packet 05.
- **Packet 08 (`Actor=Agent`)** — the Notify Cloud onboarding deliverability doc (10DLC, DKIM delegation). Depends on packet 02 (the SMS/ESP picks).
- **Packet 09 (`Actor=Human`)** — provision the primary ESP account, generate DKIM keys, register the Studio toll-free SMS number. Depends on packet 02. Runs before packet 03.
- **Packet 03 (`Actor=Human`)** — Cloudflare sender-identity DNS walkthrough; publishes SPF, DKIM, DMARC, MTA-STS, TLS-RPT. Depends on packet 02 and packet 09 (hard — needs the DKIM selectors).
- **Packet 10 (`Actor=Agent`)** — extend `hive-sync` to reconcile `sender_reputation_status`. Depends on packet 01.

06 and 07 both depend on packet 05; 03 depends on 09; 08 and 10 are independent.

## Critical context for Wave 3 execution

### For packet 06 (the default feedback-sink backing)

- **Per-tenant suppression.** ADR-0038 D6: a bounce/complaint recorded against `(TenantId, RecipientAddress)` suppresses future sends *only for that tenant*. A unit test in `HoneyDrunk.Notify.Tests` must prove tenant A's bounce does not suppress tenant B's send to the same recipient address. The **platform-wide override list** is the one cross-tenant exception — known abuse-trap / honeypot addresses suppressed for all tenants. The suppression key is the recipient address string (`Recipient.Address`); there is no `PrincipalId` type.
- **Only hard bounce and complaint suppress.** `Deferred` and `SoftBounced` do not. `Unsubscribed` does (D6: unsubscribes are part of suppression).
- **No message-bus broadcast — deferred.** D6's prose describes the sink eventually emitting a domain event onto a message bus. That is **out of scope** for packet 06: the `HoneyDrunk.Notify` runtime csproj references only `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Standards`, and `Microsoft.Extensions.*` — it has no transport/Service Bus dependency, and adding one is out of scope here. Do not add a Service Bus package. The broadcast waits until Notify takes a transport dependency (cross-reference ADR-0042). Communications reads suppression state through packet 06's query surface until then.
- **Invariant 41 boundary.** This packet stores suppression *state* — that is delivery mechanics, and ADR-0038 D6 explicitly places it "at the Notify level." Do not move preference/cadence *decision logic* into Notify; that stays in Communications.
- **The round-trip integration test uses an in-memory ESP fake** (invariant 15) — it does not block on the real ESP from packet 09. It lives in `HoneyDrunk.Notify.IntegrationTests`; unit tests live in `HoneyDrunk.Notify.Tests`.
- **No new version bump.** Packet 05 bumped the solution version. Append to the in-progress CHANGELOG entry.

### For packet 07 (List-Unsubscribe + PII-safe envelopes)

- **RFC 8058 one-click** = the `List-Unsubscribe` header (with an `https:` URI) plus `List-Unsubscribe-Post: List-Unsubscribe=One-Click`. Mandatory on bulk and platform sends, best-effort on transactional (D6). This enforces invariant 66 (the packet-00 List-Unsubscribe invariant).
- The one-click endpoint accepts a direct `POST` — **no confirmation page, no recipient login** — and produces an `Unsubscribed` `DeliverabilityEvent` that flows into packet 06's suppression backing.
- **D9 PII-safe envelopes** — `X-Notify-Message-Id` and every Notify-added header must be an opaque token, never a parseable `{tenant-id}:{message-id}` concatenation. Add a test asserting outbound headers carry no raw `TenantId`.
- Reconcile a send-class concept (`Bulk`/`Transactional`/`Platform`) against the existing `NotificationRequest`/`EmailEnvelope`/`NotificationPriority` before adding a `SendClass` enum. If added, it is an Abstractions enum — invariant 1.
- Unit tests live in `HoneyDrunk.Notify.Tests`; the one-click → `DeliverabilityEvent` integration test lives in `HoneyDrunk.Notify.IntegrationTests`. No `Thread.Sleep` (invariant 51).
- No new version bump — append to packet 05's CHANGELOG entry.

### For packet 09 (ESP + SMS provisioning, `Actor=Human`)

- Provision the **primary** ESP (the packet-02 pick). Verify `mail.` and `notify.` as sending domains; the ESP issues DKIM selectors — hand the **public** selector records to packet 03, which runs after packet 09 within this wave to complete its DKIM step.
- Register the Studio transactional **toll-free** SMS number; complete carrier toll-free verification.
- **No secrets in the repo** (invariant 8) — ESP API key, SMS auth token, DKIM private keys never committed. Keys go into the `HoneyDrunk.Notify` Key Vault per ADR-0005 naming; if that vault does not exist yet, record the destination secret names and flag the seeding as a follow-up.
- Cheapest viable tier — the Grid sends trivial v1 volume.
- **Stop before the warmup ramp** — packet 09 stands up accounts; the warmup ramp is a later operational step coordinated with the first real sends.

### For packet 03 (Cloudflare sender-identity DNS, `Actor=Human`)

- Packet 03 runs **after packet 09** within Wave 3 — it consumes the DKIM selectors packet 09's ESP account issues, so the full SPF/DKIM/DMARC/MTA-STS/TLS-RPT set is published in a single pass.
- **Conditional on the ADR-0029 apex cutover.** If the ADR-0029 apex cutover completed — `honeydrunkstudios.com` on Cloudflare authoritative DNS — packet 03's records can be published authoritatively. Otherwise packet 03 is parked on that real-world precondition (a Human-Prerequisite gate, not a packet dependency — ADR-0029 has its own initiative). Check the Cloudflare dashboard for the `honeydrunkstudios.com` zone before starting.
- **DMARC starts at `p=none`.** ADR-0038 D2's staged path is mandatory: `p=none` (14-day observation) → `p=quarantine` → `p=reject`. Publish `p=none` on day one.
- **Email records are DNS-only (grey-cloud)** per ADR-0029 D3 — never proxied. Record comments use the lean `purpose=` scheme (ADR-0029 D6).
- Packet 03's DMARC `rua` address must match the aggregator endpoint packet 04 recorded.
- **No DKIM private keys, no secrets in the repo** (invariant 8) — only DKIM *public* selector records are DNS-resident.

### For packet 08 (Notify Cloud onboarding doc)

- `HoneyDrunk.Notify.Cloud` is not scaffolded — this packet authors *documentation*, the 10DLC and DKIM-delegation onboarding requirements, as an input to the future Notify Cloud standup initiative. Mark the onboarding-feature-code deferral clearly.

### For packet 10 (`hive-sync` extension)

- Agent-definition change only — extend `.claude/agents/hive-sync.md` to reconcile `sender_reputation_status`. Follow the existing reconciliation-section shape (the ADR-0036 initiative's DR-tier lens is the model). State the D2 windows (14-day DMARC observation, 30-day SPF) in the agent definition so the check is self-contained.

## Wave 3 exit criteria

- `HoneyDrunk.Notify` has a working default `IDeliverabilityFeedbackSink` backing — deliverability-feedback persistence, per-tenant suppression + platform-wide override list, the send-path check, and the round-trip integration test. No message-bus broadcast (deferred).
- `HoneyDrunk.Notify` email sends carry RFC 8058 one-click List-Unsubscribe; the one-click endpoint produces `Unsubscribed` events; envelopes are PII-safe.
- `infrastructure/reference/notify-cloud-onboarding-deliverability.md` exists.
- The primary ESP account exists with verified domains and issued DKIM selectors; the toll-free SMS number is registered.
- `infrastructure/walkthroughs/cloudflare-sender-identity-dns.md` exists; the SPF/DKIM/DMARC/MTA-STS/TLS-RPT records are published (or packet 03 is parked on the ADR-0029 apex cutover if that has not completed).
- `hive-sync` reconciles `sender_reputation_status` and surfaces DMARC/SPF/warmup drift.
