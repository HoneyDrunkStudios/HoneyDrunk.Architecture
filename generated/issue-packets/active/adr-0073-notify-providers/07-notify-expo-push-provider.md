---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0073", "wave-4"]
dependencies: ["packet:06"]
adrs: ["ADR-0073", "ADR-0062", "ADR-0006", "ADR-0005"]
wave: 4
initiative: adr-0073-notify-providers
node: honeydrunk-notify
---

# Ship HoneyDrunk.Notify.Providers.Push.Expo package implementing IPushSender against Expo's Push API

## Summary
Ship the new `HoneyDrunk.Notify.Providers.Push.Expo` package implementing `IPushSender` against Expo's Push API. Vault-backed Expo Access Token (`Expo--AccessToken` in `kv-hd-notify-{env}`). Registers as the `NotificationChannel.Push` keyed provider via a new `AddHoneyDrunkNotifyExpoPushProvider` extension following the existing `AddHoneyDrunkNotifyResendProvider` pattern. **Appends to the in-progress `[0.4.0]` CHANGELOG entry created by packet 06.** New package — ships with its own `CHANGELOG.md` and `README.md` from the first commit (invariant 12).

## Context
Packet 06 added `NotificationChannel.Push = 2` and `IPushSender` to `HoneyDrunk.Notify.Abstractions`. This packet ships the concrete Expo provider — the canonical default per ADR-0073 D3.

**Channel-scoped naming.** Per the D3 amendment in packet 00, the package is `HoneyDrunk.Notify.Providers.Push.Expo` (not `HoneyDrunk.Notify.Providers.Expo`), parallel to the existing `HoneyDrunk.Notify.Providers.Email.Resend` and `HoneyDrunk.Notify.Providers.Sms.Twilio`.

ADR-0073 D3 commits:

- **Expo Push Tokens** are the addressable identifier; the mobile app (per ADR-0070 D3 RN+Expo) registers with Expo at app-launch and the token rounds back to the user record (Identity per ADR-0060) via the consumer-PDR's registration flow. **The token-capture flow on the mobile side is a consumer-PDR concern; this packet only sends to a token already in hand.**
- **Expo's Push API** is the send pipeline — Notify's `IPushSender` calls Expo's REST endpoint at `https://exp.host/--/api/v2/push/send`; Expo fan-outs to APNs and FCM internally.
- **Expo Push Receipts** are the delivery-confirmation pipeline — Notify polls receipts after send and lands the delivery / failure events into its standard intake. **The receipts-poll worker is packet 08's scope; this packet's send returns the Expo `ticket` IDs that the receipts-poll worker consumes.**
- **Expo Access Tokens in Vault** per ADR-0005.

The Expo Push API:

- POST `https://exp.host/--/api/v2/push/send` — body is an array of messages; each message has `to` (Expo Push Token), `title`, `body`, `data` (arbitrary payload), `sound`, `priority`, `channelId` (Android channel), etc. Response is an array of `ticket` objects, each with a `status` of `ok` (with a `ticket-id`) or `error` (with an `error-code` and `message`).
- The Expo Access Token authenticates the request via the `Authorization: Bearer {token}` header. Tokens are managed in the Expo dashboard.

For this packet's scope:

- **Send only.** This packet's `ExpoPushNotificationSender.SendAsync` accepts a `NotificationEnvelope` whose `Channel == NotificationChannel.Push` and whose `Payload` is a `PushEnvelope` (a new record-type parallel to the existing `EmailEnvelope` — confirm at execution whether the existing payload model uses a discriminated union per channel or a generic object; mirror the pattern).
- **Returns a `DeliveryOutcome`** that captures the Expo `ticket-id` in the outcome's `Provider`-specific data so packet 08's receipts-poll worker can resolve the ticket to a final delivered/failed status.
- **No receipts-poll worker in this packet.** That is packet 08.

The Expo Access Token rotates at Tier 2 per ADR-0006 (90-day cadence). Registered in `HoneyDrunk.Vault.Rotation`'s calendar in this packet (or, if the calendar lives in Vault.Rotation's repo, cross-referenced in the Expo provider README with a parallel Vault.Rotation packet).

> **Vendor risk per ADR-0073 D3.** Expo is a single vendor. The mitigation is the `IPushSender` abstraction itself — if Expo fails as a vendor, the swap to direct APNs + direct FCM (or to OneSignal) is a one-PR adapter swap behind the same interface. This packet ships the Expo binding; the abstraction it implements is the seam.

## Scope
- **New package: `HoneyDrunk.Notify.Providers.Push.Expo`**.
  - `HoneyDrunk.Notify.Providers.Push.Expo.csproj` — channel-scoped naming, version `0.4.0`, follows the structure of the existing `HoneyDrunk.Notify.Providers.Email.Resend.csproj` (PackageId, PackageTags, README/CHANGELOG packaged, HoneyDrunk.Standards reference with `PrivateAssets: all`, ProjectReference to `HoneyDrunk.Notify.Abstractions`, PackageReference to `HoneyDrunk.Vault` for `ISecretStore`, linked compile of the `HoneyDrunk.Notify.ProviderSupport` helpers — confirm against the Resend project at execution).
  - `ExpoPushNotificationSender.cs` — implements `IPushSender`. Reads `Expo--AccessToken` from `ISecretStore` per call; POSTs to `https://exp.host/--/api/v2/push/send`; maps Expo's response to `DeliveryOutcome`; captures the Expo `ticket-id` in outcome metadata for packet 08's consumption.
  - `ExpoPushOptions.cs` — options class with the Expo project ID (non-secret; informational), optional defaults (priority, channel ID for Android).
  - `DependencyInjection/ExpoPushNotifyServiceCollectionExtensions.cs` — `AddHoneyDrunkNotifyExpoPushProvider(this IServiceCollection, Action<ExpoPushOptions>)` extension; follows the `AddHoneyDrunkNotifyResendProvider` shape.
  - `CHANGELOG.md` — new file with `[0.4.0] - {merge-date}` initial entry (invariant 12).
  - `README.md` — new file documenting the package purpose, installation, public API, the ADR-0073 D3 default-provider declaration, the ADR-0062 receipts cross-reference (packet 08), the ADR-0006 Tier-2 rotation cross-reference.
- **Add the new project to the solution (`HoneyDrunk.Notify.slnx`)** so it builds with the rest.
- **`HoneyDrunk.Notify.Tests`** — unit tests for `ExpoPushNotificationSender` (mocking the HTTP boundary; verifying request shape; verifying the response → `DeliveryOutcome` mapping; verifying secret-resolution).
- **`HoneyDrunk.Notify.IntegrationTests`** — integration test for the DI registration and the keyed-DI routing (`services.AddHoneyDrunkNotifyExpoPushProvider(...)` → resolve `INotificationSender` keyed by `NotificationChannel.Push` → expect `ExpoPushNotificationSender`).
- **Repo-level `CHANGELOG.md`** — **append** to the `[0.4.0]` entry created by packet 06 with the Expo provider summary line.
- **No version bump** — solution is already at `0.4.0` from packet 06.

## Out of Scope
- **Receipts polling.** Packet 08.
- **Push-token capture flow** on the mobile side. Consumer-PDR concern.
- **`PushTokenRegistration` record** for storing tokens against user records. If packet 08 decides a Notify-side intake seam belongs there, the record ships in packet 08. This packet only **sends** to tokens already in hand.
- **APNs / FCM direct fallback.** ADR-0073 D3 names this as the vendor-risk mitigation, but it does not ship now; only when Expo as a vendor fails does the swap fire.
- **OneSignal alternative.** Explicitly rejected per ADR-0073 D3 alternatives. Do not provide an OneSignal adapter.

## Proposed Implementation
1. **Project scaffold.** Copy the structure from `HoneyDrunk.Notify.Providers.Email.Resend/`:
   - `HoneyDrunk.Notify.Providers.Push.Expo.csproj` — same shape, swapped `PackageId`, `Description`, `PackageTags` (`notify;provider;push;expo;notifications;grid`), and the ProjectReference / PackageReferences. Replace the `Resend 0.4.0` package reference with no third-party push SDK — the Expo Push API is plain HTTPS / JSON and uses `IHttpClientFactory` + `System.Text.Json` (BCL); a third-party Expo .NET SDK is not necessary and would add maintenance surface.
   - Add the same `<Compile Include="..\HoneyDrunk.Notify.ProviderSupport\..." Link="..." />` items the Resend project uses (`OptionsRegistrationExtensions.cs`, `SecretStoreExtensions.cs`, `ServiceCollectionRegistrationExtensions.cs`) so the DI registration shape matches.
   - Set `<Version>0.4.0</Version>`.
2. **`ExpoPushNotificationSender`** — internal sealed partial class implementing `IPushSender` and `INotificationSender`. Constructor injects `IHttpClientFactory`, `ISecretStore`, `IOptions<ExpoPushOptions>`, `ILogger<ExpoPushNotificationSender>`. Constants:
   - `const string ProviderName = "expo";`
   - `const string AccessTokenSecretName = "Expo--AccessToken";`
   - `const string HttpClientName = "HoneyDrunk.Notify.Expo";`
   - `const string PushEndpoint = "https://exp.host/--/api/v2/push/send";`
   In `SendAsync`:
   - Validate the envelope's payload is a `PushEnvelope` (or whatever the existing payload shape for push is — if a `PushEnvelope` record does not exist in `HoneyDrunk.Notify.Abstractions`, add it in this packet alongside the sender. The record carries: `string ExpoPushToken`, `string Title`, `string Body`, `IReadOnlyDictionary<string, object>? Data`, optional priority / channel / sound).
   - If the payload is wrong-shape, return `DeliveryOutcome.Failed(... FailureKind.Permanent, "Missing or invalid PushEnvelope payload on the notification envelope.")` — same pattern as Resend.
   - Resolve `Expo--AccessToken` via `ISecretStore.GetRequiredSecretValueAsync(...)`.
   - Build the Expo Push API request body: `[{ "to": pushToken, "title": ..., "body": ..., "data": ..., "sound": ..., "priority": ... }]` (single-message array; batching is a v2 concern).
   - POST to `PushEndpoint` via the named `IHttpClient`; set `Authorization: Bearer {accessToken}`.
   - Parse the response. Expo returns an envelope `{ "data": [{ "status": "ok" | "error", "id"?: string, "details"?: object, "message"?: string }] }`. For a single-message send, the `data` array has one element.
   - On `status: "ok"` → return `DeliveryOutcome.Succeeded(...)` and **stash the `id` (ticket-id) in the outcome's `Provider`-specific metadata** so packet 08's receipts-poll worker can resolve it. The exact stash mechanism depends on the existing `DeliveryOutcome` shape — if it has a `Metadata: IReadOnlyDictionary<string, string>?` field, use `["expo.ticket_id"] = id`; if not, add a typed Expo-specific outcome detail. State the chosen path in the PR.
   - On `status: "error"` → classify the failure per Expo's documented error codes. `DeviceNotRegistered` is permanent (the push token is invalid; the consumer-PDR should drop it from the user record); `InvalidCredentials` is permanent (auth-token rotation needed — log + audit); `MessageTooBig` is permanent; `MessageRateExceeded` is transient (retry); HTTP 5xx is transient. Return `DeliveryOutcome.Failed(... FailureKind.Permanent | FailureKind.Transient ...)`.
   - Handle HTTP-level errors (network, timeout) as transient.
3. **`ExpoPushOptions`** — options class with: `string? ProjectId` (informational; appears in logs/audit, not the request body), optional `string? DefaultPriority` (e.g. `"high"`), optional `string? DefaultAndroidChannelId`. No `AccessToken` option (the token resolves from Vault at send time per ADR-0005, never from in-process options — same pattern as the Resend `ApiKey` is no longer in `ResendOptions` per the v0.2.0 CHANGELOG note "Bootstrap-time `ApiKey` option usage is obsolete and no longer used for delivery").
4. **`AddHoneyDrunkNotifyExpoPushProvider`** extension — copy the shape from `AddHoneyDrunkNotifyResendProvider`:
   - `ArgumentNullException.ThrowIfNull(services); ArgumentNullException.ThrowIfNull(configure);`
   - `services.ConfigureOptional(configure);`
   - `services.AddHttpClient("HoneyDrunk.Notify.Expo");`
   - `return services.TryAddNotificationSender<ExpoPushNotificationSender>(NotificationChannel.Push);`
5. **Solution file** — add the new project to `HoneyDrunk.Notify.slnx`.
6. **Vault.Rotation calendar** — register `Expo--AccessToken` at Tier 2 (≤90 days). Same handling as packets 01 and 04 — if the calendar lives in Vault.Rotation's repo, this is a cross-reference + parallel Vault.Rotation packet.
7. **CHANGELOG entries:**
   - **New `HoneyDrunk.Notify.Providers.Push.Expo/CHANGELOG.md`** — initial `[0.4.0] - {merge-date}` with `### Added` listing the package's purpose.
   - **Repo-level `CHANGELOG.md`** — **append** to the `[0.4.0]` entry from packet 06 with a line: "Shipped `HoneyDrunk.Notify.Providers.Push.Expo` package implementing `IPushSender` against Expo's Push API per ADR-0073 D3."
   - **No other per-package CHANGELOG entries** — alignment-bump-only for unchanged packages (invariants 12 / 27).
8. **README** for the new package — sections: Overview (Expo provider for HoneyDrunk.Notify's push channel); Installation (`dotnet add package HoneyDrunk.Notify.Providers.Push.Expo`); Quick Start (the `AddHoneyDrunkNotifyExpoPushProvider` usage block); Configuration (`ExpoPushOptions` fields); Vault Secrets (`Expo--AccessToken` in `kv-hd-notify-{env}`); ADR-0073 D3 default-provider declaration; ADR-0062 receipts cross-reference (receipts handled in packet 08); ADR-0006 Tier-2 rotation cross-reference; ADR-0070 D3 mobile-platform alignment note (RN + Expo).
9. **Tests:**
   - **Unit tests** in `HoneyDrunk.Notify.Tests` under a new folder `Providers/Expo/`:
     - `SendAsync_WithValidEnvelope_ReturnsSucceeded` — fakes the HTTP response with `{ "data": [{ "status": "ok", "id": "ticket-123" }] }`; asserts the outcome is `Succeeded` and the ticket-id is captured in outcome metadata.
     - `SendAsync_WithInvalidPayload_ReturnsPermanentFailure`.
     - `SendAsync_WithDeviceNotRegistered_ReturnsPermanentFailure`.
     - `SendAsync_WithMessageRateExceeded_ReturnsTransientFailure`.
     - `SendAsync_WithHttp500_ReturnsTransientFailure`.
     - `SendAsync_ResolvesAccessTokenFromSecretStore` — verifies `ISecretStore.GetRequiredSecretValueAsync("Expo--AccessToken", ...)` is called.
     - `SendAsync_SetsAuthorizationBearerHeader` — verifies the outbound HTTP request carries `Authorization: Bearer {token}`.
   - **Integration test** in `HoneyDrunk.Notify.IntegrationTests`:
     - `AddHoneyDrunkNotifyExpoPushProvider_RegistersSenderAgainstPushChannel` — `services.AddHoneyDrunkNotifyExpoPushProvider(...)` → resolve `INotificationSender` keyed by `NotificationChannel.Push` → expect a non-null `ExpoPushNotificationSender`.
   - **No `Thread.Sleep`** (invariant 51).
   - **No live Expo calls** (invariant 15) — all HTTP is faked.

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Push.Expo/` — entire new package directory.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.slnx` — add the new project.
- Repo-level `CHANGELOG.md` — append to `[0.4.0]`.
- `HoneyDrunk.Notify.Tests/Providers/Expo/` — new unit tests.
- `HoneyDrunk.Notify.IntegrationTests/` — new integration test.
- (Possibly) `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/PushEnvelope.cs` — new payload record if it does not exist (state choice in PR; per-channel envelope records likely exist per the `EmailEnvelope` pattern referenced in `ResendNotificationSender`).

## NuGet Dependencies
- **`HoneyDrunk.Notify.Providers.Push.Expo`** (new):
  - `<ProjectReference Include="..\HoneyDrunk.Notify.Abstractions\HoneyDrunk.Notify.Abstractions.csproj" />`
  - `<PackageReference Include="HoneyDrunk.Standards" Version="0.2.9"><PrivateAssets>all</PrivateAssets><IncludeAssets>...</IncludeAssets></PackageReference>` (StyleCop + EditorConfig analyzers per the existing convention).
  - `<PackageReference Include="HoneyDrunk.Vault" Version="0.5.0" />` (for `ISecretStore`).
  - `<PackageReference Include="Microsoft.Extensions.DependencyInjection.Abstractions" Version="10.0.7" />`
  - `<PackageReference Include="Microsoft.Extensions.Http" Version="10.0.7" />` (for `IHttpClientFactory`).
  - `<PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="10.0.7" />`
  - `<PackageReference Include="Microsoft.Extensions.Options" Version="10.0.7" />`
  - `<PackageReference Update="Microsoft.CodeAnalysis.NetAnalyzers" Version="10.0.202" />`
  - The linked `<Compile Include="..\HoneyDrunk.Notify.ProviderSupport\..."` items for shared DI / secret-store helpers.
  - **No third-party Expo SDK.** Expo's Push API is plain JSON over HTTPS — using `HttpClient` + `System.Text.Json` keeps the dependency surface minimal.
- **Test projects** — existing test-stack references (xUnit + NSubstitute + AwesomeAssertions + coverlet).

## Boundary Check
- [x] All code in `HoneyDrunk.Notify` per the routing rule. The new package is a `HoneyDrunk.Notify.Providers.*` sibling.
- [x] Channel-scoped naming (`Providers.Push.Expo`) matches the established Email/Sms convention and the D3 amendment in packet 00.
- [x] `IPushSender` is the abstraction the sender implements (added in packet 06); the implementation lives in this packet per the Abstractions / runtime split.
- [x] Vault secret resolution via `ISecretStore` per invariants 9 / 21 — never pin a version, never log the value (invariant 8).
- [x] No dependency on `HoneyDrunk.Transport`, `HoneyDrunk.Kernel.Abstractions` beyond what `HoneyDrunk.Notify.Abstractions` already pulls in, or any other Node beyond Vault.

## Acceptance Criteria
- [ ] New package `HoneyDrunk.Notify.Providers.Push.Expo` builds and ships at version `0.4.0`
- [ ] `ExpoPushNotificationSender` implements `IPushSender` (and transitively `INotificationSender`)
- [ ] `AddHoneyDrunkNotifyExpoPushProvider` extension registers the sender against `NotificationChannel.Push` via the existing `TryAddNotificationSender<T>` helper
- [ ] Expo Access Token resolves from `ISecretStore` using secret name `Expo--AccessToken` on every send (never cached in options, never pinned to a version per invariant 21)
- [ ] Send POSTs to `https://exp.host/--/api/v2/push/send` with `Authorization: Bearer {token}` header
- [ ] Successful sends capture the Expo `ticket-id` in the outcome metadata for packet 08 to consume
- [ ] Expo error codes map correctly: `DeviceNotRegistered` / `InvalidCredentials` / `MessageTooBig` → Permanent; `MessageRateExceeded` / HTTP 5xx / network → Transient
- [ ] No third-party Expo SDK referenced — pure `HttpClient` + `System.Text.Json`
- [ ] `HoneyDrunk.Standards` referenced with `PrivateAssets: all` per invariant 26
- [ ] Package ships with `CHANGELOG.md` and `README.md` from the first commit (invariant 12); both packed in the NuGet output
- [ ] Repo-level `CHANGELOG.md`'s `[0.4.0]` entry includes the Expo provider summary line (**appended** to packet 06's entry, not a new dated section)
- [ ] `Expo--AccessToken` is registered in `HoneyDrunk.Vault.Rotation`'s Tier-2 rotation calendar (or, if the calendar lives in Vault.Rotation's repo, cross-referenced in the Expo provider README and a parallel Vault.Rotation packet is filed)
- [ ] New project added to `HoneyDrunk.Notify.slnx`
- [ ] Unit + integration tests pass; no `Thread.Sleep` (invariant 51); no live Expo calls (invariant 15)
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Expo project created in the Expo dashboard** for each environment (a single Expo project may serve all three envs via different access tokens, or three separate projects — operator choice). Expo project ID stored in `ExpoPushOptions.ProjectId` (informational, not a secret).
- [ ] **Expo Access Token seeded in each `kv-hd-notify-{env}` vault** as `Expo--AccessToken` before the Expo provider is composed in any host. The token is generated in the Expo dashboard with push-send permissions.
- [ ] **Tier-2 rotation calendar updated** for `Expo--AccessToken` — file a Vault.Rotation packet if the calendar lives there.
- [ ] **No NuGet tag pushed by this packet alone.** This packet appends to the in-progress `0.4.0` release; the tag push happens after packet 08 (or after the operator decides the `0.4.0` set is complete). A human pushes the tag.

## Referenced ADR Decisions
**ADR-0073 D3 — Expo Notifications is the default push provider.** "`HoneyDrunk.Notify.Providers.Push.Expo` (new package, ships when push lands) — the `IPushSender` implementation. Expo Push Tokens are the addressable identifier. Expo's Push API is the send pipeline — Notify's `IPushSender` implementation calls Expo's Push API; Expo fan-outs to APNs and FCM internally. Expo Push Receipts are the delivery-confirmation pipeline. Expo Access Tokens in Vault per ADR-0005."

**ADR-0073 D3 — Vendor risk mitigation.** "Expo is one company; an Expo failure mode (acquisition, pricing change, shutdown) is real risk. The mitigation: Expo Push Tokens are translatable to native APNs / FCM tokens, and the `IPushSender` abstraction means the migration cost is a one-PR adapter swap. The risk is bounded by the wrapping pattern."

**ADR-0073 §Operational Consequences.** "Expo Notifications cost is effectively zero for the Grid's mobile-app scale. Expo's paid tiers (EAS Build, OTA) are mobile-build concerns, not push concerns."

**ADR-0005 §Vault as the sole source of secrets** (invariant 9). The Expo Access Token resolves through `ISecretStore` on every send — never via environment variables, never via config-file values, never via an in-process options field.

**ADR-0006 §Tier 2 (third-party rotation)** (invariant 20). Third-party provider credentials rotate at ≤90 days via `HoneyDrunk.Vault.Rotation`.

## Constraints
- **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** This packet ships runtime code, not abstractions — invariant 1 is honored at the Abstractions package, not here. (Just noting the boundary: this package depends on `HoneyDrunk.Notify.Abstractions` via ProjectReference, which is fine.)
- **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The Expo Access Token value never appears in any log, never in any thrown exception's message, never in any audit field. Only the secret name (`Expo--AccessToken`) may appear.
- **Invariant 9 — Vault is the only source of secrets.** The Expo Access Token resolves through `ISecretStore` per call. No environment-variable fallback. No options-bag fallback.
- **Invariant 12 — Semantic versioning with CHANGELOG and README.** New package ships with both files from the first commit.
- **Invariant 13 — All public APIs have XML documentation.** `AddHoneyDrunkNotifyExpoPushProvider`, `ExpoPushOptions`, and `PushEnvelope` (if newly authored) have XML docs.
- **Invariant 15 — Unit tests and in-process integration tests never depend on external services.** No live Expo calls in any test.
- **Invariant 20 — Tier 2 rotation SLA ≤ 90 days.** `Expo--AccessToken` rotates on Tier-2 cadence.
- **Invariant 21 — Applications must never pin to a specific secret version.** Resolve the latest version per call.
- **Invariant 26 — `HoneyDrunk.Standards` reference with `PrivateAssets: all` on every new .NET project.**
- **Invariant 27 — All projects in a solution share one version and move together.** New package ships at `0.4.0` aligned with packets 06 / 08.
- **Invariant 51 — Test code contains no `Thread.Sleep`.**
- **Channel-scoped naming.** Package name is `HoneyDrunk.Notify.Providers.Push.Expo` — not `HoneyDrunk.Notify.Providers.Expo` (ADR D3 informal description is overridden by the D3 amendment in packet 00).
- **No third-party Expo SDK.** Expo's Push API is plain JSON over HTTPS; using BCL keeps the dependency surface small and the audit surface minimal.
- **OneSignal is explicitly rejected** per ADR-0073 D3 alternatives. No OneSignal adapter.
- **No receipts-poll worker.** That is packet 08's scope. This packet only sends and captures ticket IDs.

## Labels
`feature`, `tier-2`, `ops`, `adr-0073`, `wave-4`

## Agent Handoff

**Objective:** Ship the new `HoneyDrunk.Notify.Providers.Push.Expo` package implementing `IPushSender` against Expo's Push API per ADR-0073 D3. Channel-scoped naming. Vault-backed access token. Captures Expo ticket-IDs for packet 08's receipts poll.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Land the canonical default push provider.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 4.
- ADRs: ADR-0073 D3 (primary); ADR-0062 (receipts intake — packet 08 scope); ADR-0006 (Tier-2 rotation); ADR-0005 (Vault config); ADR-0070 D3 (mobile platform alignment).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:06` — `IPushSender` + `NotificationChannel.Push = 2` exist in `HoneyDrunk.Notify.Abstractions`; Notify solution at `0.4.0`.

**Constraints:**
- Channel-scoped package naming.
- Vault-backed access token (resolve every call; never cache).
- No third-party Expo SDK; pure `HttpClient` + JSON.
- No receipts-poll worker — packet 08.
- Capture Expo ticket-id in outcome metadata for packet 08 to consume.
- Append to repo-level `[0.4.0]` CHANGELOG entry; new per-package CHANGELOG + README from first commit.
- No `Thread.Sleep`; no live Expo calls in tests.

**Key Files:**
- New: `HoneyDrunk.Notify.Providers.Push.Expo/` directory with `.csproj`, `ExpoPushNotificationSender.cs`, `ExpoPushOptions.cs`, `DependencyInjection/ExpoPushNotifyServiceCollectionExtensions.cs`, `README.md`, `CHANGELOG.md`.
- Edited: `HoneyDrunk.Notify.slnx`, repo-level `CHANGELOG.md`.
- Possibly new: `HoneyDrunk.Notify.Abstractions/PushEnvelope.cs` (state choice in PR).
- New tests: `HoneyDrunk.Notify.Tests/Providers/Expo/` and `HoneyDrunk.Notify.IntegrationTests/`.

**Contracts:**
- Implements `IPushSender` (from `HoneyDrunk.Notify.Abstractions` per packet 06).
- Possibly new `PushEnvelope` record in `HoneyDrunk.Notify.Abstractions` if no per-channel payload record exists for push yet (mirror the `EmailEnvelope` pattern used by Resend).
