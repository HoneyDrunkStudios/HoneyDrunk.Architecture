# Handoff: Wave 2 → Wave 3 (enforcement mechanism → per-Node adoption)

**Read once at the Wave 2 → Wave 3 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## What Waves 1–2 delivered (upstream changes Wave 3 builds on)

- **ADR-0035 is Accepted** (packet 00). Its three new versioning invariants are live in `constitution/invariants.md`: (1) every public Abstractions package follows strict SemVer per D1 — calendar/marketing/Node-aligned versions forbidden; (2) no default-interface-member additions on shipped public interfaces — successors land on new interfaces; (3) a major-version cascade is an initiative, not a loose set of packets. D1–D9 are now binding rules. ADR-0035's acceptance PR was merged together with ADR-0034's (D10 / ADR-0034 D7 — they land together). The Kernel.Abstractions 1.0.0 baseline is recorded (the ADR-0026 `TenantId` strict-typing version is retroactively 1.0.0); every other Node's Abstractions package stays pre-1.0 until a deliberate future review.
- **The `HoneyDrunk.Standards` public-API-analyzer fragment exists** (packet 01) — a `Directory.Build.props` fragment that references `Microsoft.CodeAnalysis.PublicApiAnalyzers` (`PrivateAssets="all"`) on every packable project, wires `PublicAPI.Shipped.txt` / `PublicAPI.Unshipped.txt` as `AdditionalFiles`, sets the `RS00xx` rules to `error` severity, and turns on the switch-exhaustiveness rule. It is scoped to `$(IsPackable)` — it never touches test projects. The PR records which D3/D4 rules are analyzer-enforced vs review-enforced.
- **`job-api-diff.yml` exists in HoneyDrunk.Actions** (packet 03) — a reusable `workflow_call` workflow taking `package-id` / `version` / `declared-bump` / `surface-artifact-name` (default `public-api-surface`), resolving a package's previous published version from nuget.org, and asserting the public-surface diff matches the declared bump: no-change for `patch`, additive-only for `minor`, any-change for `major` (with a stable-major-not-preceded-by-`-rc` flag per D5). It downloads the `public-api-surface` artifact (the `PublicAPI.{Shipped,Unshipped}.txt` pair per packable project) rather than re-building. No prior published version is a clean no-op pass. Pre-1.0 (`0.Y`) violations are warnings, not hard fails.
- **The `[Obsolete]`-audit gate exists** (packet 03) — fails CI when any `[Obsolete]` member lacks a `DiagnosticId` or a `UrlFormat`. **It is a job wired into `pr-core.yml` Grid-wide** (decided in packet 03 — not a separate opt-in reusable job), so it is already active on every .NET repo and is a guaranteed no-op in any repo with no `[Obsolete]` members. **Wave 3 does not wire it per-repo** — packet 04 only confirms the repo runs `pr-core.yml` and records the audit as in effect.

## Contracts Wave 3 consumes

- **The `HoneyDrunk.Standards` public-API-analyzer fragment** — packet 04's per-Node adoption imports it into each repo-root `Directory.Build.props`. Confirm the consumption mechanism the repo already uses for the `HoneyDrunk.Standards` analyzer set (and, if the ADR-0034 initiative already landed in the repo, the packaging-metadata fragment) and match it.
- **`job-api-diff.yml` `workflow_call` contract** — inputs `package-id`, `version`, `declared-bump` (`major` | `minor` | `patch`), and `surface-artifact-name` (default `public-api-surface`). The caller uploads each packable project's `PublicAPI.{Shipped,Unshipped}.txt` pair as the `public-api-surface` artifact, then calls `job-api-diff.yml` at a pinned ref. Confirm the pinned ref before filing packet 04.
- **The `[Obsolete]`-audit** — already wired Grid-wide via `pr-core.yml` (packet 03's decided path). Wave 3 just confirms the repo runs `pr-core.yml`; no per-repo audit-wiring is needed.
- **nuget.org** — `job-api-diff.yml` resolves the previous published version from nuget.org (ADR-0034 D1). If ADR-0034's publish fan-out has not yet landed for a given Node, the API-diff is a clean no-op pass for that Node until it has a published version to diff against — not a failure.

## Wave 3 objectives

**Per-Node adoption fan-out** (packet 04) — across the **12 package-producing scaffolded .NET Node repos**: Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Observe. Per repo:

1. Import the public-API-analyzer fragment in the repo-root `Directory.Build.props`.
2. **Commit the one-time `PublicAPI.Shipped.txt` baseline** for every packable project, populated with the project's *current published public surface* — use the `PublicApiAnalyzers` "add to shipped public API" bulk code fix. Add an empty `PublicAPI.Unshipped.txt` alongside.
3. Verify `dotnet build` is green — an incomplete baseline leaves the analyzer failing.
4. Bring every existing `[Obsolete]` member into ADR-0035 D6 compliance — a `DiagnosticId` and a `UrlFormat` pointing to a migration doc (create the doc where absent: name the replacement, before/after snippet).
5. Amend the release workflow to upload the `public-api-surface` artifact (each packable project's `PublicAPI.{Shipped,Unshipped}.txt` pair) and call `job-api-diff.yml` at a pinned ref, passing `package-id` / `version` / `declared-bump` / `surface-artifact-name`.
6. Confirm the `[Obsolete]`-audit gate is active — it is resident in `pr-core.yml` Grid-wide (packet 03); verify the repo runs `pr-core.yml` and record the confirmation. No per-repo wiring.
7. Update `repos/{Node}/integration-points.md` with the Node's surface-gate enforcement.

**OUT of the fan-out:** `HoneyDrunk.Architecture`, `HoneyDrunk.Studios`, `HoneyDrunk.Actions` (these repos ship no NuGet packages); `HoneyDrunk.Standards` (self-adopts in packet 01); the 9 AI-sector Seed Nodes (AI, Capabilities, Agents, Memory, Knowledge, Flow, Operator, Evals, Sim — not yet scaffolded, adopt at their own standup); private revenue Nodes (ADR-0035 D8 — not bound by D1–D6, own standup). `HoneyDrunk.Observe` is IN the fan-out — it is a scaffolded Ops-sector Node already shipping `HoneyDrunk.Observe.Abstractions`. The 12-repo list is pinned — do not add repos at filing time. If `HoneyDrunk.Audit` is not yet package-publishing at filing time, drop it and note it.

## Constraints carried into Wave 3

> **Invariant 57 — strict SemVer** (added by packet 00). Every public Abstractions package follows strict SemVer per ADR-0035 D1. The `PublicAPI.Shipped.txt` baseline + `job-api-diff.yml` are what make this mechanically checkable.

> **Invariant 58 — no default-interface-member additions** (added by packet 00). New behavior on a shipped public interface lands on a new interface. Wave 3's baseline does not change any interface — it snapshots what exists.

> **Invariant 59 — a major cascade is an initiative** (added by packet 00). Not relevant to Wave 3's adoption work directly, but the gate Wave 3 wires is what *detects* an undeclared cascade-class break.

> **Invariant 1 — Abstractions packages have zero runtime HoneyDrunk dependencies.** `Microsoft.CodeAnalysis.PublicApiAnalyzers` is `PrivateAssets="all"` — a build-time Roslyn analyzer, not a runtime dependency — so importing the fragment into an `.Abstractions` project does not violate this.

> **Invariant 12 / 27 — CHANGELOG.** One repo-level `CHANGELOG.md` entry per repo for the surface-tracking adoption; no per-package changelog noise for packages whose only change is the imported fragment + a `PublicAPI.*.txt` pair. Packet 04 does not push tags / trigger a release (agents never push tags).

> **ADR-0035 D6 — Deprecation window.** Every `[Obsolete]` member carries a `DiagnosticId` and a `UrlFormat` pointing to a migration doc that names the replacement and shows a before/after snippet.

> **ADR-0035 D1 — Pre-1.0.** Every Node except the post-baseline Kernel is currently pre-1.0. Pre-1.0 makes no compatibility promise; `job-api-diff.yml` runs the additive check at warning severity for `0.Y` packages. The baseline commit still happens — pre-1.0 changes the diff *strictness*, not whether the surface is tracked.

- **The baseline is a snapshot, not a cleanup.** `PublicAPI.Shipped.txt` must reflect the surface *as currently published*. Do not remove, rename, or tidy public members while baselining — that would itself be an undeclared breaking change. Genuine surface cleanup is a separate deliberate major-bump packet.
- **Build green per repo before the per-repo unit is done.** An incomplete `PublicAPI.Shipped.txt` leaves the analyzer failing.
- **Review each generated baseline before merge** (a Human Prerequisite on packet 04). The baseline is the contract of record for a Node's surface; a wrong baseline silently weakens the gate. The agent generates the file; the human reviews it.
- **Pinned 12-repo list** — do not add the 9 AI-sector Seed Nodes, private revenue Nodes, Architecture, Studios, Actions, or Standards. The inclusion test is "scaffolded repo currently shipping a public `.Abstractions` package".

## Acceptance signal for Wave 3 completion

All 12 package-producing scaffolded Nodes import the analyzer fragment, have a committed `PublicAPI.Shipped.txt` baseline + empty `PublicAPI.Unshipped.txt` per packable project, build green, have every `[Obsolete]` member in D6 compliance, call `job-api-diff.yml` from their release pipelines, and have the `pr-core.yml`-resident `[Obsolete]`-audit confirmed active; `repos/{Node}/integration-points.md` records each Node's surface-gate enforcement. The initiative archives when every filed and in-scope packet is `Done`.
