---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0045", "wave-4"]
dependencies: ["packet:03"]
adrs: ["ADR-0045", "ADR-0040"]
accepts: ["ADR-0045"]
wave: 4
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-notify
---

# Migrate HoneyDrunk.Notify from Sentry config to IErrorReporter

## Summary
Migrate `HoneyDrunk.Notify` off its one-off Sentry integration onto the Grid's `IErrorReporter` (ADR-0045 D5). A source scan found **no Sentry SDK code in Notify — only account/DSN configuration**, so the primary case is a **config-only migration**: audit Notify's D8 error-capture sites, wire them to `IErrorReporter` via Notify's Pulse telemetry dependency, and archive the config-only Sentry account. The parallel-output window is skipped — nothing in Notify emits to Sentry from code, so there is nothing to run in parallel. The SDK-replacement path is kept only as a fallback if the execution-time scan unexpectedly finds SDK code.

## Context
ADR-0045 D5 makes `HoneyDrunk.Notify` the migration case. Notify has Sentry provisioned as a one-off that predates the ADR family — but **only at the account / DSN / config level**. D5/D13: this is **removed, not extended** — Notify migrates onto App Insights via `IErrorReporter`; the Notify-Sentry account is archived.

**Repo-state — the primary case is config-only.** A scan of `HoneyDrunk.Notify` found **no `Sentry` / `SentrySdk` references in the `.cs` source** and Sentry in **no `.csproj`**. Notify has a `Diagnostics/NotifyActivitySource.cs` (OTel `ActivitySource`) and a `HoneyDrunk.Notify.slnx` with ~17 projects. The Sentry integration the ADR describes lives only at the account / DSN / config level — a Sentry project + DSN provisioned but with no SDK wiring in code. So the **primary scope** of this packet is:
1. Audit Notify's D8 error-capture sites.
2. Wire those sites to `IErrorReporter`.
3. Remove any Sentry DSN/config references (`appsettings*.json` keys, Vault DSN secret references in config).
4. Archive the config-only Sentry account (human step).

**No parallel-output window.** The ADR's D10 Phase 1 parallel-run window exists to de-risk an SDK cutover. Because nothing in Notify emits to Sentry from code, there is nothing to run in parallel — the cutover *is* the moment `IErrorReporter` is wired. Skip the parallel window; record in the PR that it was skipped because no SDK code exists.

**Fallback — SDK migration.** *Only if* the execution-time scan unexpectedly finds Sentry SDK code (a host-bootstrap project, a config file the scan missed): fall back to the SDK-replacement path — replace `SentrySdk.CaptureException(...)` with `_errorReporter.CaptureException(...)`, remove `SentrySdk.Init(dsn)`, drop the `Sentry` `PackageReference`, and run a parallel-output window for parity verification. This is the fallback, not the expected path.

**Cross-package dependency.** This packet depends on `packet:03` — `HoneyDrunk.Telemetry.Sink.AzureMonitor` must implement the `IErrorReporter` facade and register it before Notify can consume it. Confirm Notify depends on `HoneyDrunk.Pulse`'s telemetry packages (Notify already consumes Pulse telemetry) and add the reference if a project that needs `IErrorReporter` lacks it.

**Notify is a live, deployable Node.** Notify is at the version its `CHANGELOG.md` records; this packet bumps the `HoneyDrunk.Notify` solution (the only ADR-0045 packet on that solution — minor bump for the error-reporting integration).

## Scope
- `HoneyDrunk.Notify` solution — wire `IErrorReporter` through Notify's Pulse telemetry dependency; route Notify's error-capture call sites (per D8) through it.
- Notify's error-capture sites — audit against ADR-0045 D8 (capture-as-error vs log-only) and route the capture-eligible ones through `IErrorReporter`.
- Sentry config references — remove DSN / config keys from `appsettings*.json` and any Vault DSN config reference (the code does not read a Sentry SDK; this is config cleanup).
- Notify test projects — update/extend tests for the new error path.
- The Notify-Sentry account and DSN — archival is a human step (see Human Prerequisites).
- **Fallback only** — if SDK code is found: replace `SentrySdk.*` calls, drop the `Sentry` `PackageReference`, run a parallel-output window.

## Proposed Implementation
1. **Scan to confirm the config-only case.** Grep the whole `HoneyDrunk.Notify.slnx` tree for `Sentry`; check `HoneyDrunk.Notify.HostBootstrap`, `HoneyDrunk.Notify.Functions`, `HoneyDrunk.Notify.Worker`, and `appsettings*.json`. The expected finding: config/DSN only, no SDK code. Record the finding in the PR. Steps 2–4 are the primary path; step 6 is the fallback.
2. **Wire `IErrorReporter`.** Confirm `HoneyDrunk.Notify` (the core project, and the deployable hosts) depend on Pulse's telemetry packages and consume the standard Pulse telemetry registration. Inject `IErrorReporter` where errors are captured. The DI registration from packet 03 makes `IErrorReporter` available once the AzureMonitor sink backing is registered in Notify's host composition.
3. **Audit error-capture sites against D8.** Route Notify's capture-eligible failures through `IErrorReporter`: failed provider sends after retries exhausted (Resend/SMTP/Twilio 5xx with no retry path), unrecoverable dispatch failures, idempotency-store write failures. Recoverable-retry successes and inbound-validation failures stay log-only (D8). The per-case mapping is the D8 list — packet 06 also lands this in `.claude/agents/review.md`. Populate `ErrorContext` with `TraceId` (from the current `Activity` / `NotifyActivitySource`), `TenantId`, `UserId` (opaque `PrincipalId`), `Release` (the Notify deployable version).
4. **Remove Sentry config.** Remove Sentry DSN / config keys from `appsettings*.json` and any config-level Vault DSN reference. The Sentry DSN *secret* in the Key Vault is not deleted by this PR (the human archival step handles decommission so a rollback window exists) — but the config stops pointing at it.
5. **Vault.** No new secret. The App Insights connection string is resolved by the Pulse AzureMonitor backing (packet 03), not by Notify directly — Notify never touches a telemetry secret (invariant 9; invariant 80).
6. **Fallback — only if SDK code is found.** Replace `SentrySdk.CaptureException(ex)` → `IErrorReporter.CaptureException(ex, errorContext)`, `SentrySdk.CaptureMessage(...)` → `IErrorReporter.CaptureMessage(...)`, Sentry breadcrumb/scope → `AddBreadcrumb`/`PushScope`; remove `SentrySdk.Init(dsn)`; drop the `Sentry` `PackageReference` from every `.csproj` that has it; run a parallel-output window (transitional config flag `errors.parallel-output-to-sentry`, default off after cutover) for parity verification, then remove the flag. Skip this entire step in the expected config-only case.
7. **XML documentation** on any new public member (invariant 13).
8. **Version bump.** Per invariant 27, this is the only ADR-0045 packet on the `HoneyDrunk.Notify` solution — it bumps the version (minor — the error-reporting integration). Every non-test `.csproj` moves to the same new version in one commit.
9. **CHANGELOG / README.** Repo-level `CHANGELOG.md` new-version entry. Per-package `CHANGELOG.md` entries only for packages with actual changes (no noise entries for alignment-only bumps — invariant 27). Update Notify's `README.md` if the error-reporting setup is part of the documented public/operational surface.

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify/` (core) — `IErrorReporter` injection, error-capture call sites.
- `HoneyDrunk.Notify.HostBootstrap`, `HoneyDrunk.Notify.Functions`, `HoneyDrunk.Notify.Worker` — Pulse telemetry registration; `appsettings*.json` Sentry config removal.
- Any `.csproj` carrying a `Sentry` `PackageReference` — reference removed (**fallback only — not expected**).
- Notify test projects — error-path tests.
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` for changed packages; every non-test `.csproj` (version bump).

## NuGet Dependencies
- **Removed:** `Sentry` (and any `Sentry.*` package) — **fallback only, not expected.** The scan found no `Sentry` `PackageReference`; remove one only if the execution-time scan unexpectedly finds it.
- **Added:** none directly — `IErrorReporter` comes from `HoneyDrunk.Telemetry.Abstractions`, which Notify reaches through its existing Pulse telemetry dependency. Confirm the Pulse telemetry project/package reference is present on the projects that need `IErrorReporter`; add the reference only if a project that needs it does not already have it.
- The AzureMonitor sink backing (`HoneyDrunk.Telemetry.Sink.AzureMonitor`) is registered in Notify's deployable **host** composition (HostBootstrap/Functions/Worker) — confirm the host references it; the App Insights SDK stays inside the Pulse sink backing, never in Notify code (invariant 80).
- `HoneyDrunk.Standards` is already on Notify's projects — no change.

## Boundary Check
- [x] `HoneyDrunk.Notify` is the correct repo — ADR-0045 D5 names Notify as the migration case explicitly.
- [x] Notify consumes `IErrorReporter` (a published Pulse contract) — it does not reference the App Insights SDK or Pulse internals (invariant 3; invariant 80).
- [x] The App Insights sink backing is composed in Notify's deployable host, not in Notify's library code — D3/D5 reversibility.
- [x] No contract change — Notify is a consumer of `IErrorReporter`, not its owner.

## Acceptance Criteria
- [ ] The Sentry footprint in `HoneyDrunk.Notify` is confirmed by a whole-solution scan; the expected finding (config/DSN only, no SDK code) is recorded in the PR
- [ ] `IErrorReporter` is injected and consumed at Notify's error-capture sites; Notify's deployable hosts register the Pulse AzureMonitor sink backing
- [ ] Notify's error-capture sites are audited against ADR-0045 D8 — capture-eligible failures (exhausted-retry provider sends, unrecoverable dispatch failures, idempotency-store write failures) route through `IErrorReporter`; recoverable retries and inbound-validation failures stay log-only
- [ ] Sentry DSN / config keys are removed from `appsettings*.json` and any config-level Vault DSN reference
- [ ] The parallel-output window is **skipped** (config-only case — nothing emits to Sentry from code) and that is recorded in the PR; the SDK-replacement fallback is applied only if the scan unexpectedly finds SDK code
- [ ] After the migration, errors flow to App Insights via `IErrorReporter`; no `SentrySdk` call exists (and none did)
- [ ] Notify reads no telemetry secret directly — the App Insights connection string is resolved by the Pulse sink backing (invariant 9; invariant 80)
- [ ] Notify test projects cover the new error path; tests use no external services (invariant 15), no `Thread.Sleep` (invariant 51)
- [ ] Every new public member has XML documentation (invariant 13)
- [ ] The `HoneyDrunk.Notify` solution version is bumped (minor); every non-test `.csproj` moves to the same version (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new-version entry; per-package `CHANGELOG.md` entries only for packages with actual changes (invariant 27)
- [ ] The solution builds; existing unit and integration tests pass

## Human Prerequisites
- [ ] **Archive the config-only Notify-Sentry account/project** after the migration PR merges and errors are confirmed flowing to App Insights (ADR-0045 D5/D13). This is a Sentry-portal action — the developer logs into the Sentry account, archives/deletes the Notify project, and decommissions the DSN. Because the migration is config-only (no SDK code emits to Sentry), no parallel-run window is needed — archive once `IErrorReporter` is wired and verified. The dispatch plan's deferred "Notify-Sentry account decommission" note tracks this.
- [ ] If a Sentry DSN secret exists in Notify's Key Vault, remove it from the vault *after* the account is archived (this packet's PR stops the config pointing at it; the secret cleanup is a separate portal step so a rollback window exists).
- [ ] The `dev` App Insights resource (ADR-0040 packet 02) must exist for the end-to-end smoke check — confirm a Notify-thrown exception lands in the App Insights Failures blade. Cross-initiative prerequisite.

## Referenced ADR Decisions
**ADR-0045 D5 — Per-Node opt-in; Notify migration.** Notify's Sentry config (no SDK code) is migrated onto `IErrorReporter` via Notify's Pulse telemetry dependency. Errors flow to App Insights instead of Sentry. The Notify-Sentry account is archived once `IErrorReporter` is wired — config-only, no parallel-run window.

**ADR-0045 D8 — Capture-vs-log policy.** Capture-as-error: unrecoverable failed dependency calls (provider 5xx with no retry path), failed dispatch with no retry remaining, write failures. Log-only at ERROR: recoverable retries that succeeded, inbound-validation failures, expected 4xx. Both: capture-eligible cases also produce an ERROR log line with the same `operation_id`.

**ADR-0045 D10 Phase 1 — Notify migration.** Config-only migration: wire the D8 capture sites to `IErrorReporter`, archive the Sentry account. No parallel-output window because nothing in Notify emits to Sentry from code. The SDK-replacement path with a parallel window is the fallback only if SDK code is found.

**ADR-0045 D13 — the Notify-Sentry setup is removed, not extended.** The account is archived once `IErrorReporter` is wired.

**ADR-0040 — Pulse is the telemetry-export boundary.** Notify consumes `IErrorReporter`; the App Insights sink backing is composed in Notify's host, never in Notify's library code.

## Constraints
> **Invariant 3 — Provider/consumer packages depend on a Node's contracts, not internals.** Notify consumes the published `IErrorReporter` contract — never the App Insights SDK, never Pulse internals.

> **Invariant 9 — Vault is the only source of secrets.** Notify reads no telemetry secret directly. The App Insights connection string is resolved by the Pulse sink backing.

> **Invariant 13 — All public APIs have XML documentation.**

> **Invariant 15 — Unit tests never depend on external services.**

> **Invariant 26 — `## NuGet Dependencies` section required; `HoneyDrunk.Standards` on every .NET project.**

> **Invariant 27 — All projects in a solution share one version and move together.** This is the only ADR-0045 packet on the `HoneyDrunk.Notify` solution — it bumps the version (minor); every non-test `.csproj` moves together. Per-package CHANGELOG entries only for packages with actual changes.

> **Invariant 51 — Test code contains no `Thread.Sleep`.**

> **Invariant 80 (error-flow, added by packet 00) — errors captured for the D8 capture-eligible cases flow through `IErrorReporter`, never via a direct backend SDK call.** This packet is the enforcement point for Notify — after it, Notify's D8 sites route through `IErrorReporter` and Notify never calls `TelemetryClient` directly.

- **Config-only is the primary case.** The scan found no Sentry SDK code — the migration is wiring `IErrorReporter` to D8 sites + config cleanup. The SDK-replacement path is a fallback only if the execution-time scan unexpectedly finds SDK code.
- **No parallel-output window.** Nothing in Notify emits to Sentry from code — there is nothing to run in parallel. Skip it; record that in the PR.
- **The account archival is human and post-merge.** Do not delete the Sentry account or DSN in this PR — archival is a portal step done after the migration is verified.

## Labels
`feature`, `tier-2`, `ops`, `adr-0045`, `wave-4`

## Agent Handoff

**Objective:** Migrate `HoneyDrunk.Notify` off its config-only Sentry integration onto the Grid's `IErrorReporter` — wire the D8 capture sites, clean up Sentry config, archive the Sentry account.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: End Notify's ungoverned Sentry drift — bring its error tracking under the Grid-wide `IErrorReporter` pattern, errors to App Insights.
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 4.
- ADRs: ADR-0045 D5/D8/D10/D13 (primary), ADR-0040 (Pulse as the telemetry-export boundary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — hard. `HoneyDrunk.Telemetry.Sink.AzureMonitor` must implement and register the `IErrorReporter` facade before Notify can consume it.

**Constraints:**
- Config-only is the primary case — the scan found no Sentry SDK code. Wire `IErrorReporter` to D8 sites + clean up Sentry config.
- No parallel-output window — nothing in Notify emits to Sentry from code. The SDK-replacement path with a parallel window is the fallback only if the scan unexpectedly finds SDK code.
- Notify consumes `IErrorReporter` only — no App Insights SDK in Notify code.
- The Sentry account archival is a human, post-merge step — not in this PR.
- First and only ADR-0045 packet on the Notify solution — bump the version (minor); all non-test `.csproj` move together.

**Key Files:**
- `HoneyDrunk.Notify/HoneyDrunk.Notify/` (core), `HoneyDrunk.Notify.HostBootstrap`, `HoneyDrunk.Notify.Functions`, `HoneyDrunk.Notify.Worker`
- `HoneyDrunk.Notify/HoneyDrunk.Notify/Diagnostics/NotifyActivitySource.cs` (for `TraceId` correlation)
- `appsettings*.json` (Sentry config removal)
- Repo-level `CHANGELOG.md`

**Contracts:**
- Consumes the `IErrorReporter` facade (from `HoneyDrunk.Telemetry.Abstractions`, packet 02). No contract owned or changed.
