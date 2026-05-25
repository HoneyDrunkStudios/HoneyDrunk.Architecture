---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0073", "wave-4"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0073", "ADR-0035"]
wave: 4
initiative: adr-0073-notify-providers
node: honeydrunk-notify
---

# Add NotificationChannel.Push and IPushSender contract for ADR-0073 D3

## Summary
Add the push channel to HoneyDrunk.Notify's abstractions: `NotificationChannel.Push = 2` added to the `NotificationChannel` enum, and `IPushSender` abstraction added to `HoneyDrunk.Notify.Abstractions` as the contract the Expo provider (packet 07) implements. **Version-bumping packet for the Notify solution from `0.3.1` → `0.4.0`** (additive new enum value + new public abstraction is a minor bump per ADR-0035 D1). The Expo provider implementation lands in packet 07; the Expo Push Receipts intake seam lands in packet 08.

## Context
ADR-0073 D3 commits **Expo Notifications** as the canonical push provider for HoneyDrunk.Notify's `IPushSender` slot. The `IPushSender` contract does not yet exist in `HoneyDrunk.Notify.Abstractions`; the `NotificationChannel` enum does not yet carry a `Push` value (per the current file at `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/NotificationChannel.cs`, only `Email = 0` and `Sms = 1` are defined).

This packet ships the **contract + enum** only. The Expo provider implementation lives in packet 07 in the new `HoneyDrunk.Notify.Providers.Push.Expo` package (channel-scoped naming per the D3 amendment in packet 00).

Splitting contract from implementation keeps `HoneyDrunk.Notify.Abstractions` honest: the abstractions package gains a new contract + enum value (additive); the implementation lands in a separate package in a separate packet. Per ADR-0035 D1, an additive new contract on an Abstractions package is a **minor** version bump.

> **Routing flow — no dispatcher change needed.** The existing `NotificationSenderResolver` (at `HoneyDrunk.Notify/Routing/NotificationSenderResolver.cs`) routes via keyed DI on the `NotificationChannel` enum value with a non-keyed fallback. The existing `NotificationDispatcher` (at `HoneyDrunk.Notify/Routing/NotificationDispatcher.cs`) reads `envelope.Channel` and delegates to the resolver — no channel-aware branching anywhere. Adding `NotificationChannel.Push = 2` is a pure additive enum extension; the resolver and dispatcher continue to work without modification. When packet 07 registers the Expo provider via `services.AddKeyedSingleton<INotificationSender>(NotificationChannel.Push, ...)` (or the `TryAddNotificationSender<T>(NotificationChannel.Push)` helper), the dispatch path lights up automatically.

The new contract — `IPushSender` — is the **abstraction-level** name. Per ADR-0073 D3, push providers implement `IPushSender` (consistent with `IEmailSender` / `ISmsSender`). However, the existing email and SMS providers in this repo implement `INotificationSender` (the channel-agnostic interface) directly and rely on keyed DI to route by channel — there is no explicit `IEmailSender` / `ISmsSender` interface in the current Abstractions package. The design choice for the push side:

- **Option A:** Add `IPushSender` as a marker interface inheriting `INotificationSender` (parallel to a hypothetical `IEmailSender` / `ISmsSender` if those existed). Documents intent; allows future per-channel cross-cutting (e.g. push-only telemetry middleware that constrains to `IPushSender`).
- **Option B:** Do not add `IPushSender`; just register `INotificationSender` against `NotificationChannel.Push` like the existing email/sms providers do.

**Recommendation: Option A**, with `IPushSender : INotificationSender` as the contract. This matches ADR-0073 D3's explicit naming and gives the same shape ADR-0073 D1 and D2 imply for `IEmailSender` / `ISmsSender` (even though the current code does not surface those marker interfaces — adding `IPushSender` now establishes the pattern; backfilling `IEmailSender` / `ISmsSender` is a separate non-gated refactor). If the execution agent finds the existing code has reasons to prefer Option B, state the choice in the PR with a brief rationale; either choice satisfies the ADR.

`HoneyDrunk.Notify.Abstractions` is the package being bumped here; the runtime `HoneyDrunk.Notify` and all 14 other packages in the solution are aligned to `0.4.0` per invariant 27 but get no functional change in this packet.

## Scope
- **`HoneyDrunk.Notify.Abstractions`**:
  - Edit `NotificationChannel.cs` — add `Push = 2` enum value with XML documentation.
  - New file (Option A path): `IPushSender.cs` — marker interface inheriting `INotificationSender`, with XML documentation citing ADR-0073 D3.
  - Per-package `CHANGELOG.md` entry for the additive changes.
  - Per-package `README.md` update — document the new enum value and the new interface in the public-API section.
- **All non-test `.csproj` files in the solution** version-bumped to `0.4.0` (invariant 27) in one commit.
- **Repo-level `CHANGELOG.md`** receives a new `[0.4.0] - {merge-date}` dated section describing the additive enum + abstraction. No `[Unreleased]` left behind.
- **Per-package CHANGELOGs for other packages** — **none** (invariants 12 / 27 — alignment-bump-only).
- **`HoneyDrunk.Notify.Tests`** — add a tiny shape test for the new enum value (`NotificationChannel.Push.Should().Be((NotificationChannel)2)`) and for the new interface (`typeof(IPushSender).Should().Implement<INotificationSender>()` if Option A is chosen).

## Out of Scope
- The Expo provider package implementation — packet 07.
- The Expo receipts intake seam — packet 08.
- A `PushTokenRegistration` record or push-token-store contract — packet 08 ships the minimal seam if needed; this packet does not pre-empt it.
- Backfilling `IEmailSender` / `ISmsSender` marker interfaces for the existing email/sms providers — separate non-gated refactor, not in scope here.
- Mobile-side Expo Push Token capture — consumer-PDR concern; not a Notify Node concern.

## Proposed Implementation
1. **Edit `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/NotificationChannel.cs`** — add the `Push` value:

   ```csharp
   namespace HoneyDrunk.Notify.Abstractions;

   /// <summary>
   /// Represents the delivery channel through which a notification is sent.
   /// </summary>
   public enum NotificationChannel
   {
       /// <summary>
       /// Email delivery (SMTP, transactional API, etc.).
       /// </summary>
       Email = 0,

       /// <summary>
       /// SMS delivery (Twilio, etc.).
       /// </summary>
       Sms = 1,

       /// <summary>
       /// Push notification delivery (Expo Push API per ADR-0073 D3, fanning out to APNs and FCM).
       /// </summary>
       Push = 2,
   }
   ```

2. **Add `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/IPushSender.cs`** (Option A path):

   ```csharp
   namespace HoneyDrunk.Notify.Abstractions;

   /// <summary>
   /// Marker interface for notification senders that deliver to <see cref="NotificationChannel.Push"/>.
   /// </summary>
   /// <remarks>
   /// <para>
   /// Inherits <see cref="INotificationSender"/>; push providers (Expo per ADR-0073 D3 — the canonical default;
   /// alternate providers if registered via D5's per-tenant or per-PDR override) implement this interface and
   /// register against <see cref="NotificationChannel.Push"/> via keyed DI.
   /// </para>
   /// <para>
   /// The Expo Push API is the canonical send pipeline; Expo Push Receipts are the canonical delivery-confirmation
   /// pipeline. See ADR-0073 D3 for the default-provider commitment and the vendor-risk mitigation rationale.
   /// </para>
   /// </remarks>
   public interface IPushSender : INotificationSender
   {
   }
   ```

3. **Version bump** — set `<Version>0.4.0</Version>` on every non-test `.csproj` in the solution in one commit (invariant 27).
4. **Per-package CHANGELOG** for `HoneyDrunk.Notify.Abstractions`:

   ```markdown
   ## [0.4.0] - {merge-date}

   ### Added

   - `NotificationChannel.Push = 2` enum value for the push notification channel per ADR-0073 D3.
   - `IPushSender` marker interface inheriting `INotificationSender` for push-channel providers.
   ```

5. **README** for `HoneyDrunk.Notify.Abstractions` — add `NotificationChannel.Push` and `IPushSender` to the public-API section.
6. **Repo-level CHANGELOG** — add a new `[0.4.0] - {merge-date}` section:

   ```markdown
   ## [0.4.0] - {merge-date}

   ### Added

   - Push notification channel — `NotificationChannel.Push = 2` and `IPushSender` interface added to `HoneyDrunk.Notify.Abstractions` per ADR-0073 D3. The Expo provider implementation (`HoneyDrunk.Notify.Providers.Push.Expo`) ships separately.

   ### Changed

   - Aligned package versions to `0.4.0` across the solution per invariant 27.
   ```

   Confirm no `[Unreleased]` content has accrued since packet 01's `[0.3.1]` close; if it has (e.g. an unrelated maintenance commit landed in between), roll that content into `[0.4.0]` per the standing "no commits under Unreleased" rule.
7. **Tests** — minimal shape tests in `HoneyDrunk.Notify.Tests`:
   - `NotificationChannel.Push.Should().Be((NotificationChannel)2);`
   - `typeof(IPushSender).Should().BeAssignableTo<INotificationSender>();` (Option A only)
   - No new test categories — these are inline shape assertions.

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/NotificationChannel.cs` — add `Push = 2`.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/IPushSender.cs` — new file (Option A).
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/CHANGELOG.md`, `README.md`.
- Repo-level `CHANGELOG.md`.
- All non-test `.csproj` files in the solution — version `0.3.1` → `0.4.0`.
- `HoneyDrunk.Notify.Tests/` — shape tests.

## NuGet Dependencies
- **`HoneyDrunk.Notify.Abstractions`** — no new `PackageReference`. The new enum value and marker interface use only BCL.
- **Other packages** — no new `PackageReference`.
- **Test project** — existing test-stack references.

## Boundary Check
- [x] Enum + abstraction changes land in `HoneyDrunk.Notify.Abstractions` (the Abstractions layer); no runtime code in this packet.
- [x] No dependency on any HoneyDrunk runtime package from Abstractions (invariant 1).
- [x] Notify is the right home — push is a notification delivery channel; Communications (decision/preference) does not need a `Push` enum value at the Communications layer (Communications routes intent to channel via Notify; the channel enum is a Notify concept).
- [x] The new `IPushSender` (Option A) is a marker for the push slot only — it does not introduce a new contract surface beyond `INotificationSender`.

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify.Abstractions` exposes `NotificationChannel.Push = 2` with XML documentation citing ADR-0073 D3
- [ ] `HoneyDrunk.Notify.Abstractions` exposes `IPushSender : INotificationSender` (or, if Option B is chosen with rationale in the PR, no marker interface — the absence is acceptable as long as the rationale is stated)
- [ ] `HoneyDrunk.Notify.Abstractions` has zero new runtime `PackageReference` (invariant 1)
- [ ] Every non-test `.csproj` in the solution is at `<Version>0.4.0</Version>` in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.4.0]` dated entry; no `[Unreleased]` content left
- [ ] `HoneyDrunk.Notify.Abstractions/CHANGELOG.md` has a `[0.4.0]` entry; other per-package CHANGELOGs receive **no** entries (alignment-bump-only per invariants 12 / 27)
- [ ] `HoneyDrunk.Notify.Abstractions/README.md` documents `NotificationChannel.Push` and `IPushSender` in the public-API section
- [ ] `NotificationSenderResolver` and `NotificationDispatcher` are **NOT** modified in this packet — they handle the new enum value via the existing keyed-DI routing automatically
- [ ] Shape tests verify the enum value and (Option A) the interface inheritance
- [ ] The `pr-core.yml` tier-1 gate passes; no contract-shape canary failure (the changes are additive)

## Human Prerequisites
- [ ] **After this packet merges, a human pushes the `HoneyDrunk.Notify` `0.4.0` release tag** so the NuGet packages publish for packet 07 to consume. Agents merge code but never tag or publish.

## Referenced ADR Decisions
**ADR-0073 D3 — Expo Notifications is the default push provider.** "Expo Notifications is the canonical push provider for HoneyDrunk.Notify's `IPushSender` slot. iOS and Android push both route through Expo's push pipeline; Notify does not talk to APNs or FCM directly. `HoneyDrunk.Notify.Providers.Push.Expo` (new package, ships when push lands) — the `IPushSender` implementation. Expo Push Tokens are the addressable identifier. Expo's Push API is the send pipeline. Expo Push Receipts are the delivery-confirmation pipeline. Expo Access Tokens in Vault per ADR-0005."

**ADR-0073 D3 amendment (packet 00).** "HoneyDrunk.Notify.Providers.Push.Expo (channel-scoped naming, parallel to Providers.Email.Resend / Providers.Sms.Twilio)."

**ADR-0035 D1 — Strict SemVer with binary-compat guarantee at minor/patch.** "New public types are additive minor bumps. New enum values on an existing public enum are additive minor bumps; consuming code that exhaustively switches on the enum gets a compiler warning but no break." (The new `Push` enum value + `IPushSender` interface together are a minor bump.)

**ADR-0073 §Operational Consequences.** "Vendor risk is bounded by the wrapping pattern. Each provider is one adapter swap away from replacement. The `IEmailSender` / `ISmsSender` / `IPushSender` contracts are stable; the implementations are swappable."

## Constraints
- **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` *abstractions* permitted. The enum value and marker interface use only BCL — no new package reference.
- **Invariant 12 — Per-package CHANGELOGs are updated only for packages with functional changes.** Only `HoneyDrunk.Notify.Abstractions` gets a per-package entry. The other 14 packages get the version alignment via `.csproj` only.
- **Invariant 13 — All public APIs have XML documentation.** The new enum value and the new interface have XML docs citing ADR-0073 D3.
- **Invariant 27 — All projects in a solution share one version and move together.** Every non-test `.csproj` to `0.4.0` in one commit. Partial bumps forbidden.
- **No `[Unreleased]` left behind.** Per the standing rule, the new `[0.4.0]` section captures any accrued content since the close of `[0.3.1]`.
- **No dispatcher / resolver modification.** The existing routing is enum-agnostic via keyed DI; do not introduce channel-specific branching in `NotificationSenderResolver` or `NotificationDispatcher`.
- **Push channel routing is keyed DI.** When packet 07 ships the Expo provider, it registers via `services.AddKeyedSingleton<INotificationSender>(NotificationChannel.Push, ...)` (or the existing `TryAddNotificationSender<T>(NotificationChannel.Push)` helper). The push send path lights up at that point — not in this packet.
- **No premature push-token-store contract.** A `PushTokenRegistration` record + receipts-poll seam may land in packet 08 if the operator decides the Notify-side intake seam belongs there. Do not ship a contract in this packet that packet 08 might want to shape differently.
- **Test project naming.** Same as the rest of the initiative — `HoneyDrunk.Notify.Tests` stays under its pre-ADR-0047 name; the rename is a separate follow-up.

## Labels
`feature`, `tier-2`, `ops`, `adr-0073`, `wave-4`

## Agent Handoff

**Objective:** Add `NotificationChannel.Push = 2` and `IPushSender` to `HoneyDrunk.Notify.Abstractions` per ADR-0073 D3 (channel-scoped amendment per packet 00). Bump the Notify solution from `0.3.1` to `0.4.0`. Ship contract only — Expo implementation in packet 07.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Land the push-channel abstraction so packet 07 can implement Expo against it.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 4 (the push channel foundation).
- ADRs: ADR-0073 D3 (primary); ADR-0035 D1 (additive minor-bump policy); ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0073 Accepted (the D3 amendment to channel-scoped naming is in the ADR text when this packet runs).
- `packet:01` — Notify solution at `0.3.1` (this packet bumps from there to `0.4.0`).

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1).
- Add `NotificationChannel.Push = 2` (not 99, not the next available number — exactly 2, parallel to Email=0/Sms=1).
- `IPushSender` marker interface inherits `INotificationSender` (Option A) unless the execution agent's review finds a reason to prefer Option B — state the choice in the PR with rationale.
- Bump every non-test `.csproj` to `0.4.0` in one commit. This is the bumping packet for `HoneyDrunk.Notify` `0.4.0`; packets 07 and 08 append.
- Do not modify `NotificationSenderResolver` or `NotificationDispatcher` — the existing keyed-DI routing handles the new enum value automatically.
- XML doc on the new enum value and interface cites ADR-0073 D3.

**Key Files:**
- `HoneyDrunk.Notify.Abstractions/NotificationChannel.cs` (edit).
- `HoneyDrunk.Notify.Abstractions/IPushSender.cs` (new — Option A).
- `HoneyDrunk.Notify.Abstractions/CHANGELOG.md`, `README.md`.
- Repo-level `CHANGELOG.md`.
- Every non-test `.csproj`.
- `HoneyDrunk.Notify.Tests/` — shape tests.

**Contracts:**
- `NotificationChannel.Push = 2` (new enum value).
- `IPushSender : INotificationSender` (new marker interface, Option A).
