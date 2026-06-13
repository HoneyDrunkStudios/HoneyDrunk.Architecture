---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0035", "wave-2"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0035", "ADR-0034", "ADR-0012"]
accepts: ["ADR-0035"]
wave: 2
initiative: adr-0035-abstractions-versioning
node: honeydrunk-actions
---

# Author job-api-diff.yml and the [Obsolete]-audit job — the ADR-0035 D9 enforcement gates

## Summary
Author a new reusable workflow `HoneyDrunk.Actions/.github/workflows/job-api-diff.yml` that compares a built package's public surface against its previous published version and asserts the diff matches the declared SemVer bump (additive-only for minor, no change for patch), and add an `[Obsolete]`-audit job that fails CI when any `[Obsolete]` member lacks a `DiagnosticId` and a `UrlFormat` — so ADR-0035's version semantics are mechanically enforced in the CI control plane, not left to review judgment.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0035 D9 commits three CI gates. Gate 1 (`Microsoft.CodeAnalysis.PublicApiAnalyzers` on every public package, `PublicAPI.{Shipped,Unshipped}.txt` tracked) is the `HoneyDrunk.Standards` fragment from packet 01. Gates 2 and 3 are HoneyDrunk.Actions' and are this work-item:

- **Gate 2 — API-diff job.** D9: "compares the post-build `Unshipped.txt` to the previous-version package on nuget.org and asserts the diff matches the declared bump (additive-only for minor, no changes for patch). Implemented as a new reusable workflow `job-api-diff.yml`."
- **Gate 3 — `[Obsolete]` audit job.** D9: "any `[Obsolete]` member without a `DiagnosticId` and a `UrlFormat` fails CI."

ADR-0035's Follow-up Work names the deliverable directly: "Author `job-api-diff.yml` in HoneyDrunk.Actions." HoneyDrunk.Actions is the Grid CI/CD control plane (ADR-0012) — these gates belong there as reusable workflows that consumer release pipelines call, exactly like ADR-0034's `job-publish-nuget.yml`.

This packet builds the two workflows. Per-Node wiring (each Node's release workflow calling `job-api-diff.yml`, each Node's PR pipeline running the `[Obsolete]` audit) is packet 04.

## Proposed Change

### `job-api-diff.yml` (ADR-0035 D9 gate 2)
New reusable workflow callable via `workflow_call`. Inputs:
- `package-id` — the package whose surface is being diffed (e.g. `HoneyDrunk.Kernel.Abstractions`).
- `version` — the version being built/published.
- `declared-bump` — `major` | `minor` | `patch`. The caller declares the intended SemVer level; the job asserts the actual surface diff is consistent with it.
- **Artifact handoff — decided shape (do not leave open).** The caller uploads the built package's `PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` for each packable project as a GitHub Actions artifact named `public-api-surface` (one artifact per caller run, containing the `PublicAPI.*.txt` pair under a per-project subdirectory path). `job-api-diff.yml` takes an input `surface-artifact-name` (default `public-api-surface`) and downloads that artifact rather than re-building. This is the same upload-artifact / download-artifact handoff `job-publish-nuget.yml` (ADR-0034 packet 03) uses for the `.nupkg`; the API-diff reuses that pattern with its own artifact name. Pin this shape in `docs/consumer-usage.md` as the committed contract — packet 04 wires callers against exactly this artifact name and layout.

Behaviour:
- Resolves the **previous published version** of `package-id` from nuget.org (the primary public feed per ADR-0034 D1). For a package with no prior published version (pre-1.0 first publish), the job is a clean no-op pass and logs that it had no baseline to diff against.
- Computes the public-surface diff between the previous version and the build under test. The diff source is the `PublicAPI.{Shipped,Unshipped}.txt` files (the packet-01 analyzer convention) and/or a package-level API extractor — pick the mechanism that is reliable against a nuget.org-published package and record it in the PR.
- **Asserts the diff matches `declared-bump`:**
  - `patch` — **no IL/surface change permitted.** Any public-surface delta fails the job (ADR-0035 D1: patch is "documentation, XML doc fixes, package metadata, no IL change").
  - `minor` — **additive-only.** New interfaces/records/enum-values/extension methods are allowed; any removal, signature change, narrowed return, widened parameter, rename, reorder, or added-required-interface-member fails the job (ADR-0035 D1 major-change list).
  - `major` — any change is allowed; the job passes the diff but **still asserts D5 was honored** to the extent it can see it: a stable `X.0.0` whose immediately-prior version on the feed was not an `X.0.0-rc.N` is flagged (ADR-0035 D5: "No version skips: `1.0.0 → 2.0.0-preview.1 → … → 2.0.0-rc.1 → 2.0.0`"). Whether this is a hard fail or a warning is a strictness call — record it in the PR; default to fail for stable majors.
- **Pre-1.0 handling.** ADR-0035 D1: pre-1.0 (`0.Y.Z`) makes no compatibility promise, but the minor/patch *additive* rules still apply to `0.Y` cascades. The job runs the same additive check for a `0.Y` minor bump but downgrades a violation to a warning (not a hard fail) when the package is pre-1.0, since pre-1.0 explicitly allows breakage. Record the pre-1.0-vs-1.0+ strictness switch in `docs/consumer-usage.md`.
- Fails loudly with a clear diff printout naming each offending surface element; never reports success on an inconsistent diff.

### `[Obsolete]`-audit job (ADR-0035 D9 gate 3)
A job that scans the public surface for `[Obsolete]` attributes and fails when any `[Obsolete]` member lacks **both** a `DiagnosticId` and a `UrlFormat`. ADR-0035 D6 requires every deprecated member carry `[Obsolete(message, error: false)]` with a `DiagnosticId` and a `UrlFormat` pointing to a migration doc.

- Mechanism: implement as a self-contained CI job step here — a source-scan over the `PublicAPI.Shipped.txt`-tracked types or a reflection scan over the built assembly. Do not push a Roslyn analyzer for this into the packet-01 `HoneyDrunk.Standards` fragment — the gate ships in HoneyDrunk.Actions as a job so it is self-contained and centrally owned. Pick the more reliable of source-scan vs reflection-scan and record the choice in the PR.
- **Decided: the `[Obsolete]`-audit ships as a job wired into `pr-core.yml`** — not as a separate opt-in reusable job. ADR-0035 D9 says a malformed `[Obsolete]` "fails CI"; wiring into the tier-1 `pr-core.yml` gate is the only reading that makes the gate Grid-wide and unconditional, so it is the committed choice. The gate is a **PR-time check** — a malformed `[Obsolete]` is caught before merge. It **must be a guaranteed clean no-op in any repo with zero `[Obsolete]` members** so it never blocks an unrelated PR (the same no-op-guard discipline as ADR-0047's `job-integration-tests.yml`). Because it lands in `pr-core.yml`, packet 04 does **not** wire it per-repo — it is already active everywhere; packet 04 only confirms and records.
- Failure message names each offending member and states the fix: add a `DiagnosticId` and a `UrlFormat`.

### Caller-permissions and consumer documentation
Document in `HoneyDrunk.Actions` `docs/consumer-usage.md`: the `job-api-diff.yml` caller snippet, the `declared-bump` input contract, the `public-api-surface` artifact-handoff shape (artifact name + per-project layout), and the pre-1.0-vs-1.0+ strictness behavior. State that the `[Obsolete]`-audit is active Grid-wide via `pr-core.yml` and needs no per-Node opt-in. This mirrors the ADR-0012 / ADR-0034 caller-contract documentation pattern.

## Consumer Impact
- `job-api-diff.yml` affects no consumer repo until its release workflow is wired to call it — that is packet 04's fan-out. `job-api-diff.yml` is purely additive.
- The `[Obsolete]`-audit job is wired into `pr-core.yml` in this packet, so it becomes active Grid-wide on every .NET repo immediately. It must be a guaranteed no-op in every repo with no `[Obsolete]` members so it does not block existing PRs (the same no-op-guard discipline as ADR-0047's `job-integration-tests.yml`). Packet 04 does not wire it per-repo — it only confirms it is active.

## Breaking Change?
- [ ] Yes
- [x] No — new reusable workflow + a new audit job in `pr-core.yml`, additive. The `[Obsolete]`-audit's mandatory no-op guard keeps it non-breaking for repos with no `[Obsolete]` members.

## Acceptance Criteria
- [ ] `.github/workflows/job-api-diff.yml` exists and is callable via `workflow_call` with inputs `package-id`, `version`, `declared-bump`, and `surface-artifact-name` (default `public-api-surface`)
- [ ] `job-api-diff.yml` downloads the `public-api-surface` artifact (the `PublicAPI.{Shipped,Unshipped}.txt` pair per packable project) rather than re-building — the committed artifact-handoff contract
- [ ] The job resolves the previous published version from nuget.org and is a clean no-op pass when there is no prior version
- [ ] `declared-bump: patch` fails on any public-surface change; `declared-bump: minor` fails on any non-additive change; `declared-bump: major` allows any change but flags a stable major not preceded by an `-rc.N` per ADR-0035 D5
- [ ] Pre-1.0 (`0.Y.Z`) packages get the additive check at warning severity, not hard fail (ADR-0035 D1: pre-1.0 makes no compatibility promise); the strictness switch is documented in `docs/consumer-usage.md`
- [ ] The job fails loudly with a per-element diff printout and never reports success on an inconsistent diff
- [ ] The `[Obsolete]`-audit ships as a job wired into `pr-core.yml` and fails CI when any `[Obsolete]` member lacks a `DiagnosticId` or a `UrlFormat`, naming each offending member
- [ ] The `[Obsolete]`-audit is a guaranteed no-op in repos with no `[Obsolete]` members so it never blocks an unrelated PR
- [ ] `docs/consumer-usage.md` documents the `job-api-diff.yml` caller snippet, the `declared-bump` contract, the `public-api-surface` artifact-handoff shape, the pre-1.0 strictness behavior, and that the `[Obsolete]`-audit is active Grid-wide via `pr-core.yml` (no per-repo opt-in)
- [ ] `docs/CHANGELOG.md` updated with a new entry for `job-api-diff.yml` and the `[Obsolete]`-audit `pr-core.yml` job
- [ ] `README.md` updated to list `job-api-diff.yml` among the reusable workflows and to note the `[Obsolete]`-audit as part of the `pr-core.yml` tier-1 gate

## Human Prerequisites
None for building the workflows. (Resolving the previous published version from nuget.org needs no credential — read access to a public package is anonymous. The `HoneyDrunkStudios` nuget.org account claim is ADR-0034 packet 03's prerequisite, not this packet's.)

## Dependencies
- `work-item:00` — ADR-0035 acceptance (soft — references ADR-0035 D9 as a live rule).
- `work-item:01` — the `HoneyDrunk.Standards` public-API-analyzer fragment (**hard** — `job-api-diff.yml` diffs the `PublicAPI.{Shipped,Unshipped}.txt` files that fragment establishes; without the convention there is nothing to diff).

## Referenced ADR Decisions
**ADR-0035 D9 — Enforcement.** Three CI gates land in HoneyDrunk.Actions. Gate 1 (Standards, packet 01): `PublicApiAnalyzers` on every public package, `PublicAPI.{Shipped,Unshipped}.txt` tracked, CI fails if `Unshipped.txt` is stale. Gate 2 (this packet): API-diff job in the release workflow compares post-build `Unshipped.txt` to the previous-version package on nuget.org and asserts the diff matches the declared bump (additive-only for minor, no changes for patch) — "Implemented as a new reusable workflow `job-api-diff.yml`." Gate 3 (this packet): `[Obsolete]`-audit job — any `[Obsolete]` member without a `DiagnosticId` and a `UrlFormat` fails CI.

**ADR-0035 D1 — Strict SemVer.** Major = any change to a frozen interface/record/enum a downstream compiled binary could observe as a break (member removal, signature change, narrowed return, widened parameter, rename, enum underlying-type change, reordered record positional parameters, added required interface member). Minor = additive only (new interface, new record, new enum value at the end, new extension method). Patch = documentation / XML doc / package metadata, no IL change. Pre-1.0 (`0.Y.Z`) is explicitly unstable — the minor/patch rules apply to `0.Y` cascades but no compatibility promise is made.

**ADR-0035 D5 — Pre-release channel.** New majors ship as `X.0.0-preview.N` first (14-calendar-day minimum in market), then `-rc.N` (7-day minimum), then stable. No version skips: `1.0.0 → 2.0.0-preview.1 → 2.0.0-preview.2 → 2.0.0-rc.1 → 2.0.0`, never `1.0.0 → 2.0.0` direct.

**ADR-0035 D6 — Deprecation window.** A removed member carries `[Obsolete(message, error: false)]` with a `DiagnosticId` and a `UrlFormat` pointing to a migration doc, for at least one minor release, with a 60-calendar-day minimum window (1.0+).

**ADR-0034 D1 — Primary feed.** nuget.org under `HoneyDrunkStudios` is the primary public feed — the authority `job-api-diff.yml` resolves the previous published version from.

**ADR-0012** — CI mechanics live in the HoneyDrunk.Actions control plane via reusable workflows; consumers call them.

## Constraints
> **Invariant — publish via reusable workflow** (added by ADR-0034's acceptance). Consumer release workflows do not run release mechanics inline; they call HoneyDrunk.Actions reusable workflows. `job-api-diff.yml` follows that pattern — it is a reusable `workflow_call` workflow, not inline logic copied per repo.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** `job-api-diff.yml` needs no secret (public-package read is anonymous), but if any auth is added for a private feed it must resolve from Vault and never echo to logs.

> **Invariant 31 — Every PR traverses the tier-1 gate before merge.** The `[Obsolete]`-audit is wired into `pr-core.yml`, so it joins the tier-1 gate Grid-wide and must be a guaranteed no-op in repos with no `[Obsolete]` members so it never blocks an unrelated PR.

- **The API-diff is the mechanical SemVer check** — it is the gate that catches a minor bump that actually broke the surface. It must fail hard on a `minor`-declared non-additive change; a warning is not enough (D9: "asserts the diff matches the declared bump").
- **Pre-1.0 is genuinely allowed to break** — do not hard-fail a `0.Y` package on a non-additive change; warn. The hard guarantee starts at 1.0.0 (D1).
- **No-baseline is a pass, not a fail** — a first publish of a package has nothing to diff against; pass cleanly and log it.
- **No-op guard is mandatory** — the `[Obsolete]`-audit is in `pr-core.yml` and must never block a PR in a repo that has zero `[Obsolete]` members.
- **Artifact handoff is a committed contract** — `job-api-diff.yml` consumes the `public-api-surface` artifact (the `PublicAPI.{Shipped,Unshipped}.txt` pair); packet 04 wires callers against exactly this name and layout. Do not leave the handoff shape "to be decided in the PR".

## Labels
`ci`, `tier-2`, `ops`, `adr-0035`, `wave-2`

## Agent Handoff

**Objective:** Build `job-api-diff.yml` (the ADR-0035 D9 gate-2 reusable workflow that asserts a package's public-surface diff matches its declared SemVer bump) and the `[Obsolete]`-audit job wired into `pr-core.yml` (gate 3 — fails CI on an `[Obsolete]` member missing a `DiagnosticId` or `UrlFormat`).

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: ADR-0035's version semantics enforced mechanically in the CI control plane; consumer release/PR pipelines call these gates (packet 04 wires them).
- Feature: ADR-0035 Abstractions Versioning and Deprecation Policy rollout, Wave 2.
- ADRs: ADR-0035 (D9 primary, D1/D5/D6), ADR-0034 (D1 — nuget.org is the previous-version source), ADR-0012 (reusable-workflow factoring).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0035 acceptance (soft).
- `work-item:01` — the `HoneyDrunk.Standards` public-API-analyzer fragment (hard — `job-api-diff.yml` diffs the `PublicAPI.{Shipped,Unshipped}.txt` files it establishes).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- The API-diff fails hard on a `minor`-declared non-additive change; a warning is not enough.
- Pre-1.0 (`0.Y`) packages get the additive check at warning severity — pre-1.0 is genuinely allowed to break.
- No prior published version is a clean pass, logged.
- The `[Obsolete]`-audit is wired into `pr-core.yml` (decided — not an opt-in reusable job) and must be a guaranteed no-op in repos with no `[Obsolete]` members.
- The artifact handoff is the `public-api-surface` artifact (`PublicAPI.{Shipped,Unshipped}.txt` pair, per-project layout) — a committed contract, not a PR-time decision.

**Key Files:**
- `.github/workflows/job-api-diff.yml` (new)
- `.github/workflows/pr-core.yml` (amended — adds the `[Obsolete]`-audit job)
- `docs/consumer-usage.md`
- `docs/CHANGELOG.md`
- `README.md`

**Contracts:** Defines the `job-api-diff.yml` `workflow_call` input contract (`package-id` / `version` / `declared-bump` / `surface-artifact-name`) and the `public-api-surface` artifact handoff (`PublicAPI.{Shipped,Unshipped}.txt` pair, per-project layout). Consumes the `PublicAPI.{Shipped,Unshipped}.txt` convention from packet 01 and nuget.org as the previous-version source (ADR-0034 D1).
