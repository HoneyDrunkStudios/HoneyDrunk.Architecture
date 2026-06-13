# Handoff — Wave 4: CI Validation + Notify Pilot

**Initiative:** `adr-0055-feature-flags`
**Wave transition:** Wave 3 (FeatureFlags Node standup) → Wave 4 (CI workflow + analyzer + first-consumer pilot)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 3 landed

- **Packet 05** — `HoneyDrunk.FeatureFlags` v0.1.0 stood up with `AzureAppConfigurationFeatureGate` (implements `IFeatureGate` over `Microsoft.FeatureManagement.IFeatureManagerSnapshot`), `TenantTargetingFilter` (`[FilterAlias("TenantTargeting")]`), the `AddFeatureFlags(IServiceCollection, IConfiguration)` DI extension, CI workflows wired per ADR-0012, the contract-shape canary against `HoneyDrunk.Kernel.Abstractions`, and the repo-level + per-package CHANGELOG/README. The v0.1.0 NuGet artifact is on the feed (human tag/release post-merge per invariant 27).

The substrate is complete: contract in Kernel, App Configuration backing in FeatureFlags, label conventions seeded in dev. Wave 4 wires the CI gate and the first real consumer.

## What Wave 4 must deliver

### Packet 06 — `HoneyDrunk.Actions`

Author the reusable workflow `job-featureflags-validate.yml` and the Roslyn analyzer NuGet that together enforce ADR-0055 D6:

- **Workflow** — locates `featureflags.json` files, validates against `featureflags-v1.json` (packet 02's schema), enforces the naming regex (D5), category coherence (D6), release-flag expiry (D7 — error), permission/operational `annual_review_due` past due (D7 — warning). Emits a markdown summary in the job summary.
- **Analyzer** — Roslyn analyzer NuGet targeting `netstandard2.0`. Diagnostics:
  - **HFF001 (Error)** — Literal-string flag in `IFeatureGate.IsEnabledAsync(...)` / `GetVariantAsync<T>(...)` not registered in `featureflags.json`.
  - **HFF002 (Warning)** — Variable-fed flag-name argument (defeats static analysis per D6).
  - **HFF003 (Warning)** — Literal flag name doesn't match the regex (defense in depth).
  - **HFF004 (Warning, optional v0.1)** — Direct `IFeatureManager` consumption outside `HoneyDrunk.FeatureFlags` (the first ADR-0055 invariant; the review agent enforces it regardless).

The analyzer can live in `HoneyDrunk.Actions` (default) or `HoneyDrunk.Standards` (alternative — executor decides at edit time based on which release flow is the closer fit). Either way, it ships as a `PackageReference` with `PrivateAssets: all` and auto-wires `featureflags.json` discovery via `.targets`.

### Packet 07 — `HoneyDrunk.Notify`

The first real-world flag consumer. Pilot the end-to-end loop:

1. **Declare** — `src/HoneyDrunk.Notify/featureflags.json` registers one release flag (the ADR example is `release.notify.bulk-send`; pick the genuinely in-flight Notify feature at edit time — the value is the loop, not the feature).
2. **Use** — gate the feature behind `IFeatureGate.IsEnabledAsync(BulkSendFlag)` with the name held as a `const string` (per D13 anti-pattern).
3. **CI** — `pr-core.yml` adds the `featureflags-validate` job; the project owning the gate references the analyzer NuGet (`PrivateAssets: all`).
4. **Flip** — operator (or App Configuration portal) flips the per-label state. Push-refresh per D2 propagates in ~30s.
5. **Log** — `feature_flag_evaluated` event emits via Pulse per D10.
6. **Audit** — NOT exercised in this packet (release-category is logged, not audited per D10). Packet 08 validates the audit path.

The pilot is the dress rehearsal for every Phase-5 consumer adoption. Failures here flag a substrate problem, not a Notify problem.

## Frozen / do-not-touch

- **`HoneyDrunk.FeatureFlags` v0.1.0 is the consumed published version.** Do not modify FeatureFlags from packets 06 or 07. If the executor finds a bug in v0.1.0, file a follow-up issue against the FeatureFlags repo; do not patch from this wave.
- **`HoneyDrunk.Kernel.Abstractions` is at packet 04's published minor.** Same rule.
- **`featureflags-v1.json` schema is packet 02's surface.** If a missing schema field is discovered, file a follow-up against the schema; do not patch from this wave.
- **The flag/config boundary lives in code review.** Per D12, the CI validator catches non-boolean flags; the judgment call ("this should have been config" / "this should have been a flag") is the review agent's rubric (packet 09 lands the D13 anti-patterns in `review.md`).

## Audit path — explicitly NOT exercised in Wave 4

ADR-0055 D10's audit semantics:
- **Permission flag flips** — audit yes.
- **Operational flag flips** — audit yes.
- **Release flag flips** — audit NO (logged only).

Packet 07's pilot is a **release** flag. No audit emission is expected; the pilot's negative-assertion is that no audit event lands when the flag flips. Packet 08 (Operator CLI in Wave 5) is where the audit emission for permission/operational flips is wired.

## Sequencing within the wave

- Packet 06 and packet 07 are different repos and can land in parallel. Packet 07 depends on packet 06 for the analyzer NuGet (the analyzer must exist on the package feed before Notify can opt in). Packet 06's workflow is the gate Notify's `pr-core.yml` calls — the workflow doesn't need a published artifact (it's a reusable workflow referenced by `@main`), so Notify's `pr-core.yml` can adopt it immediately on packet 06's merge.
- The analyzer's NuGet publication is a **human tag/release** step (invariant 27). After packet 06 merges, a human pushes the analyzer's first tag to publish v0.1.0 to the package feed. Until then, packet 07 either pins to the analyzer's local source for development or waits.

## Invariants binding Wave 4

- **Invariant 1** — Abstractions zero-dependency. Not directly relevant (packets 06/07 don't touch Abstractions packages), but the *consumer pattern* matters: packet 07 references `HoneyDrunk.FeatureFlags` only at the host project; flag-consuming code in other Notify projects sees only `IFeatureGate` from `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 12 / 27** — Solution-wide version bump on Notify; per-package CHANGELOG only for the package with functional changes.
- **Invariant 13** — XML documentation on any public types touched.
- **Invariant 15** — `InMemoryFeatureGate` in tests; no App Configuration in unit tests.
- **Invariant 26** — `HoneyDrunk.Standards` on every project the analyzer adds to.
- **Invariant 31 / 52** — pr-core tier-1 gate + cloud-wired review; the `featureflags-validate` job adds to the gate.
- **Invariant 51** — No `Thread.Sleep` in tests.
- **ADR-0055 anti-patterns (D13)** — the `const string` flag-name hoist; no string concatenation; one feature, one flag.

## Acceptance gate for the wave

Packet 06 — `job-featureflags-validate.yml` exists and is callable; the analyzer NuGet builds and ships diagnostics HFF001/HFF002 at minimum.

Packet 07 — Notify ships the pilot flag end-to-end. The PR description records the loop verification (which feature was gated, the steps observed during deploy + flip + log + no-audit-for-release).

Wave 5 (packet 08 Operator CLI + audit wiring; packet 09 governance docs) can then start. Packet 09 is technically only blocked by 00 — its `dependencies:` frontmatter expresses that.
