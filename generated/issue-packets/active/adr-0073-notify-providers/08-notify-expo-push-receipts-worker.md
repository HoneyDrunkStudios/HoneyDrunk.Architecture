---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0073", "wave-4"]
dependencies: ["packet:06", "packet:07"]
adrs: ["ADR-0073", "ADR-0062"]
wave: 4
initiative: adr-0073-notify-providers
node: honeydrunk-notify
---

# Add the Expo Push Receipts intake seam in HoneyDrunk.Notify.Worker

## Summary
Ship the Expo Push Receipts poll-and-intake seam. After a successful Expo push send (packet 07), Notify holds the Expo `ticket-id` returned by Expo's send API; the receipts API at `https://exp.host/--/api/v2/push/getReceipts` is polled some time later to convert tickets into final delivered/failed delivery events that feed Notify's intake pipeline. Also adds a minimal `PushTokenRegistration` record to `HoneyDrunk.Notify.Abstractions` as the seam consumer-PDRs use to register a mobile user's Expo Push Token against an internal user record. **Appends to the in-progress `[0.4.0]` CHANGELOG entry.** Per-package CHANGELOG entries on `HoneyDrunk.Notify.Abstractions` (for the new record) and `HoneyDrunk.Notify.Worker` (for the new background hook). No version bump.

## Context
ADR-0073 D3 commits the **Expo Push Receipts** pipeline as the delivery-confirmation seam:

> Expo Push Receipts are the delivery-confirmation pipeline — Notify polls receipts after send and lands the delivery / failure events into its standard intake.

Expo's send API (packet 07) returns immediately with a `ticket-id` indicating the message was accepted into Expo's pipeline — **not** that it was delivered to the device. Final delivery / failure is reported via the receipts API:

- **`POST https://exp.host/--/api/v2/push/getReceipts`** — body is `{ "ids": ["ticket-1", "ticket-2", ...] }`. Response is `{ "data": { "ticket-1": { "status": "ok" | "error", "details"?: {...}, "message"?: string }, ... } }`. Receipts become available approximately 15 minutes after send and persist for ~24 hours. Once read, they may be deleted (Expo does not commit to persistence).

The pattern:

1. Packet 07's `ExpoPushNotificationSender.SendAsync` captures the ticket-id in the `DeliveryOutcome` metadata (e.g. `outcome.Metadata["expo.ticket_id"] = id`).
2. A background process (this packet) periodically:
   - Reads recent successful push outcomes whose ticket-id has not yet been resolved (the read store is **Notify's existing intake / outbox / delivery-tracking store** — confirm the existing shape at execution; the receipts poll uses the same store the rest of Notify uses to track in-flight deliveries).
   - Batches them into a `getReceipts` request.
   - Parses the response and routes each receipt into Notify's intake pipeline as a `DeliveryStatusEvent` (or the existing event shape for delivery callbacks — same routing the Resend / Twilio webhooks use in packets 01 / 04).
3. The poll cadence is bounded by Expo's ~15-minute receipt latency and the ~24-hour TTL. A 5-minute interval is a reasonable default (operator-configurable).

This packet **also** adds a minimal `PushTokenRegistration` record to `HoneyDrunk.Notify.Abstractions` so consumer-PDRs have a canonical shape for "this user has an Expo Push Token; here it is." The record is a primitive — the storage and the registration HTTP endpoint live in consumer-PDRs (Identity for the platform-wide case per ADR-0060; or per-PDR for product-specific cases). Notify itself does not store push tokens; it sends to a token the caller supplies.

> **The receipts poller is a background service in `HoneyDrunk.Notify.Worker`** (the existing Worker host that processes the queue). It does not run in `HoneyDrunk.Notify.Functions` — Functions is the queue-triggered intake; the receipts poller is a periodic background, more naturally a Worker concern. If the Functions host needs receipts polling too (e.g. operator chooses to deploy push delivery via Functions only), the poller can be lifted to a shared component; for now it lives in Worker.

## Scope
- **`HoneyDrunk.Notify.Abstractions`**:
  - New file: `PushTokenRegistration.cs` — a public record carrying the Expo Push Token + minimal context (per ADR's record-vs-interface naming rule: record drops the `I` prefix). Fields: `string ExpoPushToken`, `string? Platform` (informational: "ios" | "android"), `DateTimeOffset RegisteredAt`. The record is **consumer-input shape only** — Notify does not persist it; the consumer-PDR (Identity / Hearth / etc.) stores it against the user record and supplies the token when sending.
  - Per-package CHANGELOG entry for the additive record.
- **`HoneyDrunk.Notify.Worker`** (the existing Worker host):
  - New background service: `ExpoPushReceiptsPollService` — `BackgroundService` that periodically polls Expo's receipts API for pending tickets.
  - Options class: `ExpoPushReceiptsPollOptions` — poll interval (default: 5 minutes), batch size (default: 100 — Expo's documented max per receipts call is 100), max ticket-age before giving up (default: 24 hours).
  - DI registration: `AddHoneyDrunkNotifyExpoPushReceiptsPoll(this IServiceCollection, Action<ExpoPushReceiptsPollOptions>?)` extension. The host opts in. The poll service is **not** wired by `AddHoneyDrunkNotifyExpoPushProvider` (packet 07) — the send-side provider and the receipts-poll background are independent registrations so a host that only sends (and accepts no-confirmation delivery) does not pay for a poller.
  - Per-package CHANGELOG entry for the additive background service.
- **Repo-level `CHANGELOG.md`** — **append** to the `[0.4.0]` entry with a one-line summary for the receipts poll + `PushTokenRegistration` record.
- **`HoneyDrunk.Notify.Tests`** — unit tests for `ExpoPushReceiptsPollService` (mocking HTTP; verifying the batch-request shape; verifying the response → intake-event mapping; verifying empty-batch handling; verifying the access-token resolution).
- **`HoneyDrunk.Notify.IntegrationTests`** — integration test for the DI registration (`AddHoneyDrunkNotifyExpoPushReceiptsPoll` → background service is in the host).
- **No version bump** — solution stays at `0.4.0` from packet 06.

## Out of Scope
- **Push token storage.** `PushTokenRegistration` is the shape consumer-PDRs use to express "this user has this push token." The storage is the consumer-PDR's concern. Notify does not store push tokens.
- **The receipts persistence store.** The receipts poller reads ticket-ids from Notify's **existing** delivery-tracking store (the same store Resend/Twilio webhooks land into). If the existing store does not have a "pending Expo ticket" shape, the poll service uses an in-memory queue of ticket-ids populated at send time by `ExpoPushNotificationSender` (packet 07) — state the chosen path in the PR. The in-memory approach is acceptable for v1 because Expo's 24-hour receipt TTL is a hard upper bound, and ticket-ids that survive a Worker restart can be re-tried only by Resend/Twilio-style "we'll lose receipts for in-flight tickets across restart" — acceptable initial trade-off; durable storage is a follow-up.
- **Tenant-specific Expo project handling.** If a Notify Cloud tenant overrides their push provider with their own Expo project (per packet 05's override policy), the receipts poll uses the tenant-scoped access token. The override-resolution wrapping is the Notify Cloud follow-up's job (specified in packet 05); this packet's poller resolves the access token from the same name (`Expo--AccessToken`) the send-side uses, deferring tenant-scoped resolution to the future Notify Cloud override.
- **Mobile-side push-token capture flow.** Consumer-PDR concern.

## Proposed Implementation
1. **`PushTokenRegistration` record** in `HoneyDrunk.Notify.Abstractions`:

   ```csharp
   namespace HoneyDrunk.Notify.Abstractions;

   /// <summary>
   /// Represents a push token registered by a mobile client for delivery via
   /// <see cref="NotificationChannel.Push"/>. The token is supplied by the
   /// consuming Node (Identity, Hearth, etc.) at send time; HoneyDrunk.Notify
   /// does not persist push tokens — that is a consumer-PDR concern.
   /// </summary>
   /// <param name="ExpoPushToken">
   /// The Expo Push Token (format: <c>ExponentPushToken[...]</c> or <c>ExpoPushToken[...]</c>).
   /// Generated on the mobile side by the Expo SDK at app launch per ADR-0070 D3.
   /// </param>
   /// <param name="Platform">
   /// Informational platform identifier (<c>ios</c> / <c>android</c>); used only for
   /// logging and metric tags. Routing is determined by the Expo Push Token, not by
   /// this field.
   /// </param>
   /// <param name="RegisteredAt">
   /// When the token was registered, in UTC. Used by consumer-PDRs to age tokens
   /// (e.g. drop tokens older than 30 days that have never been used successfully).
   /// </param>
   public sealed record PushTokenRegistration(
       string ExpoPushToken,
       string? Platform,
       DateTimeOffset RegisteredAt);
   ```

   Naming follows the Grid rule — record drops `I`, interfaces keep `I`. `PushTokenRegistration`, not `IPushTokenRegistration`.
2. **`ExpoPushReceiptsPollOptions`** in `HoneyDrunk.Notify.Worker`:

   ```csharp
   public sealed class ExpoPushReceiptsPollOptions
   {
       public TimeSpan PollInterval { get; set; } = TimeSpan.FromMinutes(5);

       public int MaxBatchSize { get; set; } = 100; // Expo's documented max per getReceipts call.

       public TimeSpan MaxTicketAge { get; set; } = TimeSpan.FromHours(24); // Expo's documented receipt TTL.
   }
   ```

3. **`ExpoPushReceiptsPollService`** — `BackgroundService`:
   - Constructor injects `IHttpClientFactory`, `ISecretStore`, `IOptions<ExpoPushReceiptsPollOptions>`, `ILogger<ExpoPushReceiptsPollService>`, `TimeProvider`, and the pending-tickets source (see Scope's "in-memory queue" or "existing intake store" choice).
   - `ExecuteAsync` loop: wait for `PollInterval` via `TimeProvider.CreateTimer` or `Task.Delay(interval, timeProvider, ct)`; pull up to `MaxBatchSize` pending ticket-ids that are within `MaxTicketAge`; if any, POST `https://exp.host/--/api/v2/push/getReceipts` with `{ "ids": [...] }` and `Authorization: Bearer {Expo--AccessToken}` (resolved from `ISecretStore` per call — never cached); parse the response.
   - For each ticket-id in the response:
     - `status: "ok"` → routes a delivered `DeliveryStatusEvent` (or the existing event shape) into Notify's intake pipeline.
     - `status: "error"` → routes a failed event with the Expo-documented error classification (`DeviceNotRegistered` → permanent + the consumer-PDR should drop the token; `MessageRateExceeded` → transient; `MessageTooBig` → permanent; etc.).
   - Ticket-ids not present in the response are presumed still pending; they remain queued for the next poll until they exceed `MaxTicketAge`, at which point they are marked as "timed out — receipt never arrived" (logged at Warning, audit-emitted per ADR-0030 if the Audit hook is in place; otherwise simply logged).
   - No `Thread.Sleep` (invariant 51).
4. **`AddHoneyDrunkNotifyExpoPushReceiptsPoll`** extension in `HoneyDrunk.Notify.Worker`:

   ```csharp
   public static IServiceCollection AddHoneyDrunkNotifyExpoPushReceiptsPoll(
       this IServiceCollection services,
       Action<ExpoPushReceiptsPollOptions>? configure = null)
   {
       ArgumentNullException.ThrowIfNull(services);

       if (configure is not null)
       {
           services.ConfigureOptional(configure);
       }

       services.AddHttpClient("HoneyDrunk.Notify.Expo.Receipts");
       services.AddHostedService<ExpoPushReceiptsPollService>();

       return services;
   }
   ```

5. **Wire the captured-ticket-ids from packet 07 into the poll source.** Confirm at execution time:
   - If `ExpoPushNotificationSender` (packet 07) already writes the ticket-id to Notify's existing delivery-tracking store: the poller reads from that store.
   - If not: introduce an in-memory `IExpoTicketQueue` shape inside the Worker package (not exposed in Abstractions — purely a Worker-internal seam) that the sender writes to and the poller reads from. State the choice in the PR. The in-memory option requires that the sender and poller live in the same process, which is the existing Worker-host case.
6. **Per-package CHANGELOG entries:**
   - `HoneyDrunk.Notify.Abstractions/CHANGELOG.md` — append to the `[0.4.0]` entry: "Added `PushTokenRegistration` record — consumer-input shape for registering an Expo Push Token against an internal user record."
   - `HoneyDrunk.Notify.Worker/CHANGELOG.md` — new `[0.4.0] - {merge-date}` section (if absent) with: "Added `ExpoPushReceiptsPollService` background service that polls Expo's receipts API and routes delivered/failed events into Notify's intake pipeline per ADR-0073 D3." (The Worker's CHANGELOG may not yet have a `[0.4.0]` entry; create it. Roll any `[Unreleased]` content into the `[0.4.0]` section per the standing rule.)
7. **Repo-level `CHANGELOG.md`** — append to the `[0.4.0]` entry from packet 06 with a one-line summary of the receipts poller + `PushTokenRegistration` record.
8. **Tests:**
   - **Unit tests** in `HoneyDrunk.Notify.Tests/Providers/Expo/` (folder created by packet 07):
     - `ReceiptsPollService_WithPendingTickets_BatchesAndPolls` — verifies the request shape.
     - `ReceiptsPollService_WithDeliveredReceipts_RoutesDeliveredEvent`.
     - `ReceiptsPollService_WithErrorReceipts_RoutesFailedEvent_WithClassification`.
     - `ReceiptsPollService_WithEmptyPendingQueue_DoesNotCallApi`.
     - `ReceiptsPollService_WithTicketOlderThanMaxAge_DropsTicket_LogsWarning`.
     - `ReceiptsPollService_ResolvesAccessTokenFromSecretStore`.
   - **Integration test** in `HoneyDrunk.Notify.IntegrationTests`:
     - `AddHoneyDrunkNotifyExpoPushReceiptsPoll_RegistersBackgroundService` — verifies the hosted service is in the DI container after registration.
   - **No `Thread.Sleep`** (invariant 51); drive the poll interval with `TimeProvider.Advance` (a `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing` if not already in the test stack — add only if needed and state in PR).
   - **No live Expo calls** (invariant 15).

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/PushTokenRegistration.cs` (new).
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/CHANGELOG.md`, `README.md` updates.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/Hosting/` (or the existing convention) — new `ExpoPushReceiptsPollService.cs`, `ExpoPushReceiptsPollOptions.cs`, and `DependencyInjection/ExpoPushReceiptsServiceCollectionExtensions.cs`.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/CHANGELOG.md`, `README.md` updates.
- Repo-level `CHANGELOG.md` — append to `[0.4.0]`.
- `HoneyDrunk.Notify.Tests/Providers/Expo/` — new unit tests.
- `HoneyDrunk.Notify.IntegrationTests/` — new integration test.
- Possibly: `HoneyDrunk.Notify.Worker/Internal/IExpoTicketQueue.cs` (and an in-memory implementation) if the chosen path is the in-memory queue rather than the existing delivery-tracking store.

## NuGet Dependencies
- **`HoneyDrunk.Notify.Worker`** — confirm the existing `PackageReference` set at execution. Likely additions:
  - `Microsoft.Extensions.Hosting.Abstractions` (for `BackgroundService`) — likely already referenced.
  - `Microsoft.Extensions.Http` — likely already referenced.
  - `HoneyDrunk.Vault` — already referenced (per the v0.2.0 ADR-0005 migration).
  - No new third-party SDK.
- **`HoneyDrunk.Notify.Abstractions`** — no new `PackageReference` for `PushTokenRegistration` (BCL types only).
- **Test projects** — possibly `Microsoft.Extensions.TimeProvider.Testing` for `FakeTimeProvider` if not already referenced.

## Boundary Check
- [x] All code in `HoneyDrunk.Notify` per the routing rule.
- [x] `PushTokenRegistration` in Abstractions is a primitive (consumer-input shape only); Notify does not persist push tokens — that is consumer-PDR scope.
- [x] The receipts poll lives in Worker (a Notify-internal host) — not exposed as a public abstraction; only the registration extension is public.
- [x] The poll service does not introduce a new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify.Abstractions` exposes `PushTokenRegistration` record with the three fields and XML documentation
- [ ] `PushTokenRegistration` follows the Grid record-naming rule (no `I` prefix)
- [ ] `HoneyDrunk.Notify.Worker` exposes `ExpoPushReceiptsPollService` as a `BackgroundService` and `AddHoneyDrunkNotifyExpoPushReceiptsPoll` as the DI registration extension
- [ ] The poll service POSTs to `https://exp.host/--/api/v2/push/getReceipts` with batched ticket-ids; resolves `Expo--AccessToken` from `ISecretStore` per call (never cached)
- [ ] Delivered receipts route a delivered event into Notify's intake pipeline; error receipts route a failed event with Expo-documented classification
- [ ] Tickets exceeding `MaxTicketAge` (default 24 hours) are dropped with a Warning log
- [ ] Poll interval defaults to 5 minutes; batch size defaults to 100 (Expo's documented max); both operator-configurable via `ExpoPushReceiptsPollOptions`
- [ ] The receipts-poll service is **not** auto-wired by `AddHoneyDrunkNotifyExpoPushProvider` (packet 07) — opt-in only via `AddHoneyDrunkNotifyExpoPushReceiptsPoll`
- [ ] Per-package CHANGELOG entries on `HoneyDrunk.Notify.Abstractions` (the record) and `HoneyDrunk.Notify.Worker` (the background service); no entries on packages with no functional change (invariants 12 / 27)
- [ ] Repo-level `CHANGELOG.md`'s `[0.4.0]` entry includes the receipts-poller + `PushTokenRegistration` summary **appended** (not a new dated section)
- [ ] No version bump in this packet — solution stays at `0.4.0` from packet 06
- [ ] Unit + integration tests verify the request shape, the response → intake-event mapping, the empty-queue path, the timeout path, the access-token resolution
- [ ] Tests contain no `Thread.Sleep`; poll-interval timing driven via `TimeProvider` (the `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing` if added; state in PR)
- [ ] No live Expo calls in any test
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Confirm `Expo--AccessToken` is already in `kv-hd-notify-{env}`** (seeded by packet 07's human prereq).
- [ ] **After this packet merges, a human pushes the `HoneyDrunk.Notify` `0.4.0` release tag** so the full `0.4.0` (packets 06 + 07 + 08) publishes. Agents merge code but never tag or publish. The tag covers all `0.4.0` packets atomically.
- [ ] **Decide on the Notify.Worker deployment target.** Per ADR-0015, `HoneyDrunk.Notify.Worker` runs on Azure Container Apps as `ca-hd-notify-worker-{env}`. The receipts poller runs inside the Worker, so the existing Container App revision becomes the host. No new infrastructure is needed; this is informational.

## Referenced ADR Decisions
**ADR-0073 D3 — Expo Push Receipts are the delivery-confirmation pipeline.** "Expo Push Receipts are the delivery-confirmation pipeline — Notify polls receipts after send and lands the delivery / failure events into its standard intake."

**ADR-0073 §Operational Consequences — Cross-channel intake model.** "Receipt-driven delivery confirmation. Expo's receipt API gives Notify the same delivered/failed events that Resend (for email) and Twilio (for SMS) provide. The cross-channel intake model stays coherent."

**Grid-wide naming rule (memory: records drop I, interfaces keep it).** `PushTokenRegistration` is a record — no `I` prefix.

**ADR-0005 §Vault as the sole source of secrets** (invariant 9). The Expo Access Token resolves through `ISecretStore` on every poll.

**ADR-0021 §Applications must never pin to a specific secret version** (invariant 21). Each poll resolves the latest version.

## Constraints
- **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `PushTokenRegistration` is a pure record over BCL types.
- **Invariant 8 — Secret values never appear in logs.** The Expo Access Token never appears in any log or audit.
- **Invariant 9 — Vault is the only source of secrets.** No env-var fallback.
- **Invariant 12 — Per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Notify.Abstractions` and `HoneyDrunk.Notify.Worker` get entries; nothing else.
- **Invariant 13 — All public APIs have XML documentation.** `PushTokenRegistration`, `ExpoPushReceiptsPollOptions`, `AddHoneyDrunkNotifyExpoPushReceiptsPoll` all have XML docs.
- **Invariant 15 — Unit tests and in-process integration tests never depend on external services.** All HTTP fakes; no live Expo calls.
- **Invariant 20 / 21** — Tier-2 rotation respected; never pin to a version.
- **Invariant 27 — Solution version alignment.** Already `0.4.0`; no further bump.
- **Invariant 51 — Test code contains no `Thread.Sleep`.** Drive timing via `TimeProvider`.
- **Receipts poll is opt-in.** The poll service is not auto-registered by the send-provider extension. A host that doesn't need delivery confirmation does not pay for a poller.
- **Receipt store is in-memory acceptable for v1.** If the existing delivery-tracking store does not accommodate Expo ticket-ids, use an in-memory queue inside the Worker process. Durable storage is a follow-up if losing in-flight tickets across Worker restart proves operationally problematic.
- **Naming.** `PushTokenRegistration` is a record (no `I`); `ExpoPushReceiptsPollService` is a class (no `I`); `ExpoPushReceiptsPollOptions` is a class (no `I`). The DI extension `AddHoneyDrunkNotifyExpoPushReceiptsPoll` follows the `AddHoneyDrunkNotify*` pattern.

## Labels
`feature`, `tier-2`, `ops`, `adr-0073`, `wave-4`

## Agent Handoff

**Objective:** Ship the Expo Push Receipts poll-and-intake seam in `HoneyDrunk.Notify.Worker` and the `PushTokenRegistration` record in `HoneyDrunk.Notify.Abstractions`. Closes ADR-0073 D3's delivery-confirmation obligation.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Land the receipts pipeline so Expo sends get delivered/failed confirmation routed into Notify's standard intake.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 4.
- ADRs: ADR-0073 D3 (primary); ADR-0062 (intake events — using existing patterns); ADR-0005 (Vault for access token); ADR-0015 (Worker hosts on Container Apps — informational).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:06` — `IPushSender` + `NotificationChannel.Push` in Abstractions.
- `packet:07` — `ExpoPushNotificationSender` captures ticket-ids that this packet's poller consumes.

**Constraints:**
- Poll service is opt-in via a separate `AddHoneyDrunkNotifyExpoPushReceiptsPoll` extension — not bundled with the send-provider registration.
- Records drop `I` (Grid naming rule); interfaces keep `I`.
- Vault-resolved access token per poll; never cached.
- No `Thread.Sleep` (invariant 51); drive timing via `TimeProvider` (use `FakeTimeProvider` in tests).
- No live Expo calls in tests.
- Append to repo-level `[0.4.0]` CHANGELOG — no new dated section, no version bump.
- Per-package CHANGELOG entries only on packages with actual changes (Abstractions for the record, Worker for the background service).

**Key Files:**
- `HoneyDrunk.Notify.Abstractions/PushTokenRegistration.cs` (new record).
- `HoneyDrunk.Notify.Worker/` — new `ExpoPushReceiptsPollService.cs`, `ExpoPushReceiptsPollOptions.cs`, and DI extension.
- Repo-level `CHANGELOG.md`, per-package CHANGELOGs on Abstractions and Worker.
- Tests in the existing `HoneyDrunk.Notify.Tests/Providers/Expo/` folder (created by packet 07).

**Contracts:**
- `PushTokenRegistration` record (new, in Abstractions).
- `ExpoPushReceiptsPollOptions` class (new, internal to Worker package).
- `AddHoneyDrunkNotifyExpoPushReceiptsPoll` extension (new, public DI extension on Worker).
