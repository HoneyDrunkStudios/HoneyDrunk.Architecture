---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "pilot", "adr-0055", "wave-4"]
dependencies: ["packet:05", "packet:06"]
adrs: ["ADR-0055"]
wave: 4
initiative: adr-0055-feature-flags
node: honeydrunk-notify
---

# Pilot ADR-0055 — declare one release flag, gate an in-progress feature, validate the end-to-end loop

## Summary
Pilot the ADR-0055 flag system end-to-end in `HoneyDrunk.Notify` per Phase 2: declare a `release.notify.<feature>` flag in a new `src/HoneyDrunk.Notify/featureflags.json`, compose `AddFeatureFlags` in Notify's host, gate an in-progress feature behind `IFeatureGate.IsEnabledAsync` at the feature's entry point, wire `job-featureflags-validate.yml` and the Roslyn analyzer NuGet, and verify the end-to-end loop: **declare → use → CI validates → flip via App Configuration → log emitted → audit recorded for permission/operational categories** (release-flag flips are logged, not audited).

## Context
ADR-0055 D14 Phase 2 names Notify as the pilot consumer: "Pilot consumption in `HoneyDrunk.Notify` (one release flag for an in-progress bulk-send feature) to validate the end-to-end loop." The ADR's example flag is `release.notify.bulk-send`. **Use the bulk-send feature if it is in flight at execution time; otherwise pick any genuinely in-progress Notify feature and name the flag accordingly** — the value of the pilot is the end-to-end loop validation, not the specific feature chosen. The Notify launch tracker is the authority on what features are currently in flight; consult it at edit time.

`HoneyDrunk.Notify` is a live Node currently at v0.3.0. This packet amends Notify to consume the flag system and ships the first real-world flag gate. The change is functional (a real feature is gated; a Notify deploy after this packet leaves the feature behind a default-off flag in staging/prod and on in dev per D9) — per invariants 12/27 it bumps the solution one minor version.

The end-to-end loop has six observable steps; the acceptance criteria verify each:
1. **Declare** — the flag is registered in `featureflags.json` per D6 (and packet 02's schema).
2. **Use** — code calls `_featureGate.IsEnabledAsync("release.notify.<feature>")` (literal string, picked up by the Roslyn analyzer per packet 06).
3. **CI validates** — `job-featureflags-validate.yml` passes; the Roslyn analyzer's HFF001 does not fire on the literal flag string (it is registered).
4. **Flip via App Configuration** — a human (or the Operator CLI from packet 08 when it lands; the App Configuration portal directly until then) flips the flag's per-label value. The push-refresh propagates within seconds.
5. **Log emitted** — `HoneyDrunk.Pulse` records a `feature_flag_evaluated` event per D10 with the structured fields (`flag.name`, `flag.category`, `flag.decision`, etc.).
6. **Audit** — for **release-category** flags, no audit event (D10: "Release-flag flips are logged but not audited"). The audit gate runs for **permission** and **operational** flips; the pilot does not exercise the audit path. Document this explicitly in the PR description — the pilot validates the **release** loop, not the audit loop. The audit loop is validated by packet 08's Operator CLI (which emits the audit events) and by a future permission-category pilot (deferred to Notify.Cloud per Phase 4).

## Scope
- `src/HoneyDrunk.Notify/featureflags.json` (new) — register the pilot release flag.
- Notify host composition — call `AddFeatureFlags(builder.Configuration)` in the host startup, and ensure App Configuration is wired with the feature-flag section per D2/D9 (label-aware refresh).
- The feature's entry point — wrap the code path behind `await _featureGate.IsEnabledAsync("release.notify.<feature>")`.
- `.github/workflows/pr-core.yml` — call `job-featureflags-validate.yml` per packet 06.
- The Notify project that consumes flags — add a `PackageReference` to the analyzer NuGet from packet 06 (`PrivateAssets: all`) so the Roslyn analyzer runs at build time.
- A new unit/integration test asserting flag-on and flag-off behavior using `InMemoryFeatureGate` (per invariant 15 and packet 04's testing fixture).
- The Notify solution version bumps to the next minor (invariant 27).
- `HoneyDrunk.Notify` per-package `CHANGELOG.md` and `README.md` updates as needed (per invariant 12, only the package with the functional change gets an entry).
- Repo-level `CHANGELOG.md` for the new version.

## Proposed Implementation
1. **Audit at execution time.** Confirm with the Notify launch tracker which Notify feature is genuinely in flight at edit time. ADR-0055's example is `release.notify.bulk-send`; if bulk-send isn't in flight, pick a real candidate (the value here is validating the loop, not the feature choice). Record the chosen flag name in the PR description.
2. **Declare** — `src/HoneyDrunk.Notify/featureflags.json`:
   ```json
   {
     "$schema": "https://schemas.honeydrunkstudios.com/featureflags-v1.json",
     "flags": [
       {
         "name": "release.notify.<feature>",
         "category": "release",
         "description": "<feature> in Notify; ships in <target version>. Pilot flag for ADR-0055 end-to-end validation.",
         "owner": "HoneyDrunk.Notify",
         "created": "<YYYY-MM-DD>",
         "expires_on": "<created + 90 days>",
         "expected_orphan": false
       }
     ]
   }
   ```
   The `expires_on` is 90 days from `created` per ADR-0055 D7 default — surface it explicitly so the executor doesn't pick an arbitrary date.
3. **Compose** — in Notify's host startup (the executable Notify project, not the abstractions/runtime packages):
   ```csharp
   builder.Configuration.AddAzureAppConfiguration(opt =>
   {
       opt.Connect(new Uri(builder.Configuration["AppConfig:Endpoint"]!),
                  new ManagedIdentityCredential())
          .Select(KeyFilter.Any, label: env)             // dev/staging/prod/ci per D9
          .UseFeatureFlags(ff => ff.Label = env)         // label-scoped feature flags
          .ConfigureRefresh(r => r.Register("FeatureManagement:Sentinel", refreshAll: true)
                                  .SetCacheExpiration(TimeSpan.FromSeconds(30)));
   });
   builder.Services.AddFeatureFlags(builder.Configuration);
   ```
   `env` resolves from `ASPNETCORE_ENVIRONMENT` (or the equivalent) per ADR-0033's environment convention; align with the existing Notify env-resolution pattern.
4. **Use** — at the feature's entry point (the Notify code path being gated):
   ```csharp
   private const string BulkSendFlag = "release.notify.bulk-send"; // const for analyzer; per D13 anti-pattern, never concatenate
   …
   if (!await _featureGate.IsEnabledAsync(BulkSendFlag))
   {
       // current behaviour — fall back to per-message sends, or return the existing pre-feature response
       return await _existingPath.ExecuteAsync(ct);
   }
   // new feature behaviour, only reached when the flag is on
   return await _bulkSendPath.ExecuteAsync(ct);
   ```
   The `const string` hoist is per ADR-0055 D13 anti-pattern ("String-concatenating flag names at the call site"); the analyzer in packet 06 sees the literal string and validates against `featureflags.json`. **Do not** inline the string into multiple call sites — hoist it once.
5. **CI** — `.github/workflows/pr-core.yml` adds a `featureflags-validate` job calling `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-featureflags-validate.yml@main` with `featureflags-json-glob: 'src/**/featureflags.json'`. The Notify project that holds `featureflags.json` opts into the analyzer by adding a `PackageReference` to the analyzer NuGet (`PrivateAssets: all`).
6. **Tests** — add a unit/integration test in the appropriate Notify test project asserting:
   - **Flag off** — `InMemoryFeatureGate.SetFlag("release.notify.<feature>", false)` → the feature entry point invokes `_existingPath`, not `_bulkSendPath`.
   - **Flag on** — `InMemoryFeatureGate.SetFlag("release.notify.<feature>", true)` → the feature entry point invokes `_bulkSendPath`.
   These cover the ADR-0044/0047 "test both flag-on and flag-off states" expectation. No `Thread.Sleep` (invariant 51); no App Configuration in the test (invariant 15).
7. **App Configuration seeding (operator-side prerequisite, captured as Human Prerequisite).** Once this packet's PR merges and Notify deploys to dev, a human creates the flag in the dev App Configuration resource per packet 03's walkthrough: create the flag named `release.notify.<feature>` with the `dev` label `enabled: true` and the `staging`/`prod`/`ci` labels `enabled: false` (per D9). The flag exists in `featureflags.json` regardless — App Configuration is the *runtime* substrate; the registry is the source of truth.
8. **Verify the loop end-to-end (operator action, captured as Human Prerequisite).**
   a. Deploy Notify to dev with the flag at `enabled: true` (the D9 default for dev).
   b. Exercise the gated feature; confirm the new code path runs (validates step 2 + 4).
   c. Confirm a `feature_flag_evaluated` event appears in Pulse / App Insights with the structured fields (validates step 5).
   d. Flip the flag to `enabled: false` in App Configuration; within ~30 seconds, confirm the next request takes the old code path (validates the push-refresh from D2).
   e. Confirm no audit event was emitted (D10 — release-category does not audit). This is a *negative* assertion — packet 08 (Operator CLI + audit wiring) validates the *positive* audit path for permission/operational categories.
9. **Version bump.** Bump every non-test `.csproj` in the Notify solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` adds a new dated entry; the Notify project that holds the feature gate gets a per-package CHANGELOG entry (functional change). Other Notify packages bumped only for alignment get no per-package entry (invariant 12).

## Affected Files
- `src/HoneyDrunk.Notify/featureflags.json` (new)
- The Notify host startup file (composition wiring)
- The feature's entry point file (the gated code path)
- `.github/workflows/pr-core.yml` (add the `featureflags-validate` job)
- The Notify project that owns the feature gate — add `PackageReference` to the analyzer NuGet
- The Notify test project — new flag-on/flag-off tests
- Every non-test `.csproj` in the Notify solution — version bump (invariant 27)
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` for the changed package
- `README.md` if the public API surface or composition story changed

## NuGet Dependencies
- The Notify project that owns the host composition:
  - `HoneyDrunk.FeatureFlags` — the v0.1.0 published by packet 05 (concrete `IFeatureGate` implementation + `TenantTargetingFilter`). Confirm published version at edit time.
  - `HoneyDrunk.Kernel.Abstractions` — already referenced by Notify; ensure the version is at least packet 04's minor.
- The Notify project that owns the feature gate (the same project, or a sibling project that already references `HoneyDrunk.Kernel.Abstractions`):
  - `HoneyDrunk.Actions.FeatureFlagsAnalyzer` (or whichever name packet 06 ships) — `PrivateAssets: all`.
- The Notify test project that holds the new flag tests:
  - `HoneyDrunk.Kernel.Abstractions.Testing` — for `InMemoryFeatureGate`. Already referenced if Notify uses Kernel test fixtures; confirm at edit time.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Notify` — its own host composition, the feature gate site, the new test. Routing rule "notification, email, SMS, ... notify, channel → HoneyDrunk.Notify" maps here.
- [x] No contract change — Notify consumes `IFeatureGate` as shipped by packet 04 and the App-Configuration-backed implementation as shipped by packet 05.
- [x] Preference/cadence/suppression decision logic is NOT touched — that is Communications' boundary (invariant 41). This packet gates one Notify delivery-mechanics feature.
- [x] Audit wiring is NOT exercised — release-category flags are logged, not audited (D10). Packet 08 validates the audit path.

## Acceptance Criteria
- [ ] `src/HoneyDrunk.Notify/featureflags.json` exists, validates against the `featureflags-v1.json` schema (packet 02), and declares one release flag with `name` matching the regex, `category: release`, `created`, `expires_on` (90 days from created), `expected_orphan: false`
- [ ] The Notify host wires App Configuration with the label-aware feature-flag refresh per ADR-0055 D2/D9 (Managed Identity per ADR-0005; no secret in code)
- [ ] The Notify host calls `AddFeatureFlags(builder.Configuration)` to register the App-Configuration-backed `IFeatureGate`
- [ ] The gated feature's entry point evaluates `await _featureGate.IsEnabledAsync(BulkSendFlag)` (or the equivalent for the chosen feature) with the flag name held as a `const string` near the call site (per ADR-0055 D13 anti-pattern)
- [ ] The new unit/integration tests assert flag-on triggers the new path and flag-off triggers the existing path; use `InMemoryFeatureGate.SetFlag(...)` (invariant 15)
- [ ] `.github/workflows/pr-core.yml` calls `job-featureflags-validate.yml@main` from packet 06
- [ ] The Notify project that owns the feature gate references the analyzer NuGet from packet 06 (`PrivateAssets: all`); the build picks up the analyzer and emits no HFF001/HFF003 diagnostics on the new flag use site
- [ ] Every non-test `.csproj` in the Notify solution is at the same new minor version in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new dated version entry; the package that holds the functional change has a per-package CHANGELOG entry; other packages bumped for alignment have NO per-package entry (invariant 12)
- [ ] No `Thread.Sleep` in test code (invariant 51); no external dependencies in tests (invariant 15)
- [ ] The PR description records the end-to-end loop verification (which feature was gated, which six steps were observed during the operator-side validation)
- [ ] The `pr-core.yml` tier-1 gate passes, the `featureflags-validate` job is green, and the analyzer fires no errors on the new flag use site

## Human Prerequisites
- [ ] Packet 05's `HoneyDrunk.FeatureFlags` v0.1.0 must be published to NuGet (human tag/release per invariant 27) before this packet's PR can build.
- [ ] Packet 06's analyzer NuGet must be published (or available via a local source) before this packet's project can reference it.
- [ ] After this PR merges and Notify deploys to dev: create the flag in the dev App Configuration resource per packet 03's walkthrough. Set `dev` label `enabled: true`, `staging`/`prod`/`ci` labels `enabled: false`. Until this happens, the flag does not exist at runtime — `IFeatureGate.IsEnabledAsync` returns the default (`false`), and the gated feature stays off.
- [ ] Run the end-to-end loop verification (the six observable steps in the Proposed Implementation step 8) and record findings in the PR description.

## Referenced ADR Decisions
**ADR-0055 D14 Phase 2 — Notify pilot.** "Pilot consumption in `HoneyDrunk.Notify` (one release flag for an in-progress bulk-send feature) to validate the end-to-end loop: declare → use → CI validates → flip via operator CLI → log emitted → audit recorded."

**ADR-0055 D9 — Local-dev affordances.** Dev label defaults the flag on; staging/prod/ci default off. The pilot exercises this — in dev, the gated feature is live by default; in higher environments, it's behind the flag.

**ADR-0055 D10 — Release flips are logged but not audited.** The pilot flag is `category: release`; flips emit `feature_flag_evaluated` log events to Pulse but NOT audit events. The audit-event path is exercised by packet 08 (Operator CLI with permission/operational flips). The pilot does not exercise that path — explicitly noted in the PR description.

**ADR-0055 D13 — Anti-pattern: string-concatenating flag names.** The pilot holds the flag name as a `const string` so the Roslyn analyzer can resolve it and the registry stays accurate.

**ADR-0055 D6 — Per-Node `featureflags.json`.** The pilot is the first real consumer of this; the file lands at `src/HoneyDrunk.Notify/featureflags.json` per the ADR's path convention.

## Constraints
- **Pilot validates the release-flag loop, not the audit loop.** Audit is a permission/operational concern (D10); the pilot is a release flag. Packet 08 validates the audit path.
- **Don't speculatively add a permission or operational flag.** The pilot is one release flag (per the ADR's Phase 2 wording). A permission flag for Notify.Cloud is a Phase 4 deferred item.
- **Const-string flag name.** Per ADR-0055 D13 anti-pattern, hold the flag name in a `const string`; never interpolate or concatenate the flag name at the call site. The analyzer enforces this with HFF002.
- **Default-off in higher environments.** Per D9, the staging/prod label values for the flag are `enabled: false`. The flag stays off in production until the feature is ready to ship — at which point the operator flips the flag, then in a follow-up the flag and its `expires_on` cleanup PR retires the flag entirely per D7.
- **Invariant 27 — solution-wide version bump.** Every non-test `.csproj` in the Notify solution bumps in one commit.
- **Invariant 12 — per-package CHANGELOGs only for packages with actual changes.** The package holding the feature gate gets an entry; other Notify packages bumped solely for alignment get no per-package entry.

## Labels
`feature`, `tier-2`, `ops`, `pilot`, `adr-0055`, `wave-4`

## Agent Handoff

**Objective:** Pilot the ADR-0055 flag system end-to-end in `HoneyDrunk.Notify` with one release flag gating an in-progress feature, validating the declare → use → CI → flip → log loop.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Confirm the flag substrate works end-to-end against a real consumer before the broader Grid rollout (Notify.Cloud Phase 4, consumer-app PDR adoption Phase 5).
- Feature: ADR-0055 Feature Flag rollout, Wave 4 (the pilot).
- ADRs: ADR-0055 D2/D9/D10/D13/D14 (primary), ADR-0026 (RequestContext source for ITargetingContext — Notify's host composition already provides this), ADR-0033 (env resolution), ADR-0005 (App Configuration backing via Managed Identity).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:05` — `HoneyDrunk.FeatureFlags` v0.1.0 published to NuGet.
- `packet:06` — `job-featureflags-validate.yml` and the analyzer NuGet published.

**Constraints:**
- One release flag. No speculative permission/operational flags.
- Const-string flag name; analyzer HFF002 enforces.
- Default-on in dev; default-off elsewhere (D9).
- Solution-wide minor bump; per-package CHANGELOG only for the package with functional changes (invariants 12, 27).
- Audit path is NOT exercised here — release-category flips are logged, not audited (D10).

**Key Files:**
- `src/HoneyDrunk.Notify/featureflags.json` (new)
- Notify host composition file — `AddFeatureFlags` wiring.
- The gated feature's entry-point file — `IFeatureGate.IsEnabledAsync` call.
- `.github/workflows/pr-core.yml` — `featureflags-validate` job.
- Notify test project — flag-on/flag-off tests with `InMemoryFeatureGate`.
- Every non-test `.csproj` for the solution-wide minor bump.
- Repo-level + per-package `CHANGELOG.md`.

**Contracts:**
- Consumes `IFeatureGate` from `HoneyDrunk.Kernel.Abstractions` (packet 04's surface).
- Consumes `HoneyDrunk.FeatureFlags`'s `AddFeatureFlags` (packet 05's host composition).
- The flag declaration in `featureflags.json` matches `featureflags-v1.json` (packet 02's schema).
