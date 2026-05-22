---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
target_repos: ["HoneyDrunk.Notify", "HoneyDrunk.Communications"]
labels: ["chore", "tier-2", "ops", "coordination", "adr-0039", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0039", "ADR-0027"]
accepts: ["ADR-0039"]
wave: 2
initiative: adr-0039-license-policy
node: honeydrunk-notify
---

# Convert HoneyDrunk.Notify and HoneyDrunk.Communications from MIT to FSL-1.1-MIT (ADR-0039 D2)

## Summary
Replace the stale extensionless `LICENSE` (MIT) file in `HoneyDrunk.Notify` and `HoneyDrunk.Communications` with a Functional Source License `LICENSE.md` (FSL-1.1-MIT text), set `<PackageLicenseFile>LICENSE.md</PackageLicenseFile>` for the **engine** packages in each repo (FSL-1.1-MIT is not a valid SPDX identifier — the engine repos use the packed-file form, not `<PackageLicenseExpression>`), add a short README section explaining the FSL non-compete clause, and keep each revenue Node's **`*.Abstractions` contract package on MIT** (and any client SDK package on MIT) via a per-project `<PackageLicenseExpression>MIT</PackageLicenseExpression>` override. Only the revenue *engine* repo's engine package is FSL.

## Context
ADR-0027 (Notify Cloud) carved out FSL for `HoneyDrunk.Notify` and `HoneyDrunk.Communications` as a one-off. ADR-0039 D2 formalizes that precedent into Grid policy: these two Nodes are the Grid's current designated revenue Nodes and license under **FSL-1.1-MIT**. Reality today, however, is that both repos still carry an `MIT License` file copied from the first Grid repo — `LICENSE` in `HoneyDrunk.Notify` and `HoneyDrunk.Communications` both begin `MIT License / Copyright (c) 2026 HoneyDrunkStudios`. The FSL decision exists in ADR text but has never been applied to the repos. This packet applies it.

FSL-1.1-MIT semantics (ADR-0039 D2): the current version is non-compete-licensed — anyone may use, modify, and contribute back, but may not use the software to offer a *competing product*; after two years each version automatically converts to MIT. The Grid uses the `MIT` future-license variant (not `Apache-2.0`) for consistency with D1.

**This is a multi-repo packet** describing one repeated unit of work across the two repos in `target_repos`. The work is identical in shape and small. The `file-packets` agent files it as a tracking issue with two child issues, or as two sibling issues.

## Per-repo work unit (repeated for HoneyDrunk.Notify and HoneyDrunk.Communications)
For each of the two repos:
1. **Replace the license file.** The repo currently carries an extensionless `LICENSE` file (MIT text — verified on disk for both `HoneyDrunk.Notify` and `HoneyDrunk.Communications`). **`git rm` the old extensionless `LICENSE`** and add a new `LICENSE.md` containing the full **FSL-1.1-MIT** license text. ADR-0039 D2 specifies `LICENSE.md` as the filename (the `.md` form, because GitHub renders it and FSL is custom text). The FSL text is the canonical FSL-1.1 template with the `// Software` line set to the repo name and the future-license set to **MIT** (not Apache-2.0). Source the template from the official FSL text (fsl.software / the FSL GitHub) — see Human Prerequisites. **The old extensionless `LICENSE` must be removed, not left in place** — a stale MIT `LICENSE` sitting beside a new FSL `LICENSE.md` is itself a license-clarity bug; the repo must carry exactly one license file after conversion.
2. **Set the engine package license metadata.** In the repo-root `Directory.Build.props`, set the engine package's license to FSL via **`<PackageLicenseFile>LICENSE.md</PackageLicenseFile>`** plus a `<None Include="LICENSE.md" Pack="true" PackagePath=""/>` item. **Do NOT set `<PackageLicenseExpression>FSL-1.1-MIT</PackageLicenseExpression>` for the FSL engine repos** — `FSL-1.1-MIT` is **not a registered SPDX license identifier**, so `<PackageLicenseExpression>FSL-1.1-MIT</PackageLicenseExpression>` fails NuGet's SPDX validation at pack time. The reliable and correct form for a custom-text license is the packed-file form (`PackageLicenseFile`). Because packet 02's shared `HoneyDrunk.Standards` fragment sets a *conditional* `<PackageLicenseExpression>MIT</PackageLicenseExpression>` default, the FSL repo must also clear that inherited expression so the two metadata forms do not both appear in the nupkg (they are mutually exclusive): set `<PackageLicenseExpression></PackageLicenseExpression>` (empty) in the repo-root `Directory.Build.props` *after* the import of the shared fragment, so only `PackageLicenseFile` remains. The binding requirement: the published engine nupkg surfaces the FSL `LICENSE.md`, with no `MIT` SPDX expression and no FSL-as-SPDX-expression.
3. **README FSL section.** Add a short README section (one paragraph + a link to the FSL FAQ at fsl.software) explaining: this Node is FSL-1.1-MIT licensed; you may use, modify, and contribute back freely; you may not use it to build a competing product; each version becomes MIT two years after release. ADR-0039 Operational Consequences and ADR-0027 both require this — "the README of FSL-licensed repos must explain it briefly."
4. **`*.Abstractions` package stays MIT — decided, not flagged.** The `*.Abstractions` package of each revenue Node (`HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Communications.Abstractions`) is **MIT-licensed**, not FSL. This is a settled decision in this packet, not a developer flag: the FSL non-compete is a moat on the *engine*; the *contract surface* that downstream Nodes are required to compile against (invariant 40 — "Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`"; invariant 48 — the analogous Audit rule) must stay permissively licensed, or every non-revenue downstream consumer would inadvertently take an FSL dependency. **Only the revenue engine repo's engine package itself is FSL.** Implementation: the `*.Abstractions` project's `.csproj` sets `<PackageLicenseExpression>MIT</PackageLicenseExpression>` — this is valid SPDX and overrides any repo-level setting — and the project does not pack the FSL `LICENSE.md`.
   - **Client SDK package (conditional — none exists today).** ADR-0039 D3: a revenue Node's client SDK is also MIT. `catalogs/nodes.json` shows `HoneyDrunk.Notify` exposes `HoneyDrunk.Notify.Abstractions` + `HoneyDrunk.Notify`; there is **no `HoneyDrunk.Notify.Sdk` package today**. Do not create one. If/when an SDK package is added, its `.csproj` sets `<PackageLicenseExpression>MIT</PackageLicenseExpression>` and carries a per-project MIT `LICENSE`, exactly like the `*.Abstractions` package.
5. **Update `catalogs/nodes.json` consistency.** No edit needed — packet 01 already sets `honeydrunk-notify` and `honeydrunk-communications` to `FSL-1.1-MIT`. This packet makes the repo match the catalog.
6. **Repo-level `CHANGELOG.md`.** Add an entry recording the license change from MIT to FSL-1.1-MIT. A license change is consumer-visible — per ADR-0039 D9 the *next package release* must call out the license change in `<PackageReleaseNotes>`; this CHANGELOG entry is the source for that. Use a dated, versioned section (no Unreleased section committed).

## Repo-list note (read before filing)
`target_repos` is exactly `HoneyDrunk.Notify` and `HoneyDrunk.Communications` — the two designated revenue Nodes that exist and are package-producing today. **`HoneyDrunk.Notify.Cloud`** (ADR-0027 D2, private) is NOT in scope — it is not yet scaffolded, and per ADR-0039 D4 it is proprietary with no public license; it adopts its `LICENSE` ("All rights reserved. Proprietary to HoneyDrunk Studios LLC.") at its own standup. **`HoneyDrunk.Billing`** and consumer-app server Nodes are future and not yet scaffolded — they adopt FSL at their own standup per ADR-0039 D2. The two-repo list is pinned; do not add repos at filing time.

## Affected Repos
`HoneyDrunk.Notify`, `HoneyDrunk.Communications` — the two repos in `target_repos`.

## NuGet Dependencies
None. This packet replaces a `LICENSE` file, sets MSBuild package-metadata properties, and edits README/CHANGELOG. No `PackageReference` is added or removed; no new .NET project is created. (If a future SDK project is added per step 4, that is its own packet with its own `## NuGet Dependencies` — not this packet.)

## Boundary Check
- [x] Each repo's `LICENSE`/`LICENSE.md`, `Directory.Build.props`, README, and CHANGELOG live in that repo — correct ownership.
- [x] No code change in any other repo. `catalogs/nodes.json` is already set by packet 01 — not touched here.
- [x] No new cross-Node runtime dependency — license metadata, not a reference.
- [x] No contract change — no interface shape touched.

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify` and `HoneyDrunk.Communications` each carry a `LICENSE.md` containing the full FSL-1.1-MIT license text (future license = MIT, not Apache-2.0)
- [ ] The prior extensionless `LICENSE` (MIT) file is removed via `git rm` in each repo — **no extensionless `LICENSE` remains in `HoneyDrunk.Notify` or `HoneyDrunk.Communications` after conversion** (exactly one license file, `LICENSE.md`)
- [ ] Each repo's root `Directory.Build.props` sets the **engine** package license via `<PackageLicenseFile>LICENSE.md</PackageLicenseFile>` + a packed `<None Include="LICENSE.md" .../>` item; `<PackageLicenseExpression>` is NOT set to `FSL-1.1-MIT` (not a valid SPDX identifier) and the inherited conditional `MIT` expression from packet 02's shared fragment is cleared so it does not appear in the engine nupkg
- [ ] The published **engine** nupkg for each repo surfaces the FSL `LICENSE.md` as its license — no `MIT` SPDX expression, no FSL-as-SPDX-expression — verify with `dotnet pack` + `.nuspec` inspection
- [ ] Each repo's `*.Abstractions` package (`HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Communications.Abstractions`) carries `<PackageLicenseExpression>MIT</PackageLicenseExpression>` (valid SPDX) and does NOT pack the FSL `LICENSE.md` — the contract surface is MIT
- [ ] Each repo's README has a short FSL section: one paragraph explaining non-compete + 2-year-to-MIT conversion, plus a link to the FSL FAQ
- [ ] No client SDK package is created; if one is added later it follows the same MIT per-project override as the `*.Abstractions` package
- [ ] Each repo's repo-level `CHANGELOG.md` records the MIT → FSL-1.1-MIT engine license change (and the MIT `*.Abstractions` posture) under a dated, versioned section
- [ ] `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Billing`, and consumer-app server Nodes are NOT touched
- [ ] No git tag is pushed (agents never push tags); the actual ADR-0039 D9 `<PackageReleaseNotes>` callout rides the next human-triggered release

## Human Prerequisites
- [ ] Confirm the canonical FSL-1.1-MIT license text source (the official template at fsl.software / the FSL GitHub repo). If the implementing agent cannot fetch it, the developer pastes the FSL-1.1-MIT template text into the packet thread before execution. The agent must not hand-author FSL text — it is a fixed legal template with only the software-name and copyright-holder lines filled in.
- [ ] Confirm the legal copyright holder string for the FSL `// Copyright` line (e.g. "HoneyDrunk Studios LLC" — consistent with ADR-0039 D4's proprietary-notice wording). If BDR-0001 (entity finalization) changes the legal name, that is a future correction, not a blocker for this packet.

## Resolved: revenue-Node `*.Abstractions` packages are MIT
ADR-0039 D3 makes the *SDK* MIT but does not explicitly name the *Abstractions* package of a revenue Node. This packet **resolves the question rather than leaving it as a post-hoc flag**: `HoneyDrunk.Notify.Abstractions` and `HoneyDrunk.Communications.Abstractions` are **MIT**.

Rationale: these are the contract surfaces downstream Nodes are *required* to compile against — invariant 40 ("Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`. Composition against `HoneyDrunk.Communications` is a host-time concern; packaged testing fixtures, when introduced, are test-time only.") and the analogous Audit invariant 48 ("Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Emitters and readers compile against `HoneyDrunk.Audit.Abstractions` only."). If the Abstractions package were FSL, every non-revenue downstream Node would inadvertently take an FSL non-compete dependency simply by depending on the contract — which the invariants mandate it do. The FSL non-compete is a moat on the *revenue engine*, not on the *interface*. Therefore the contract surface stays permissively MIT-licensed; only the revenue engine repo's engine package itself is FSL. This is decisive — the implementing agent does not flag it.

## Referenced ADR Decisions
**ADR-0039 D2 — Revenue Nodes: FSL-1.1-MIT.** Revenue Nodes license under FSL-1.1-MIT. `HoneyDrunk.Notify` and `HoneyDrunk.Communications` are current revenue Nodes (per ADR-0027). FSL semantics: non-compete now; automatic conversion to MIT after two years; the Grid uses the MIT future-license variant. "The FSL text is included as `LICENSE.md` in the repo (the SPDX identifier alone is insufficient because FSL is custom-text per project)."

**ADR-0039 D3 — SDKs and client libraries: MIT regardless of engine license.** A revenue Node's client SDK is MIT even when the engine is FSL. "`HoneyDrunk.Notify.Sdk` (the SDK in the open Notify repo) is MIT. `HoneyDrunk.Notify` (the engine) is FSL. Both live in the same repo; the repo's root `LICENSE.md` is the FSL text, and the SDK's project carries a per-project `LICENSE` and a `<PackageLicenseExpression>MIT</PackageLicenseExpression>` that overrides the `Directory.Build.props` default."

**ADR-0039 D9 — License changes are an ADR amendment.** A license change requires a `<PackageReleaseNotes>` entry on the next package release explicitly calling out the change. (This packet *is* the application of an already-accepted ADR-0039 decision, not a new license change requiring a fresh amendment — but the consumer-visible `<PackageReleaseNotes>` callout obligation still applies on the next release. ADR-0027 already established the FSL intent for these two repos; this packet reconciles the repos to that intent.)

**ADR-0039 Operational Consequences.** "FSL semantics include 'non-compete' wording that is novel to most consumers; the README of FSL-licensed repos must explain it briefly."

**ADR-0027 — FSL precedent.** ADR-0027 carved FSL for Notify and Communications; ADR-0039 D2 formalizes it. The SDK staying open under MIT is the ADR-0027 D6 pattern made into ADR-0039 D3 policy.

## Constraints
- **Do not hand-author FSL text.** FSL-1.1-MIT is a fixed legal template. Only the software-name and copyright-holder lines are filled in. Source the canonical text — do not paraphrase or summarize it.
- **Future license is MIT, not Apache-2.0.** FSL-1.1 has two variants; the Grid uses `FSL-1.1-MIT` for consistency with D1 (ADR-0039 D2).
- **`FSL-1.1-MIT` is not a valid SPDX identifier.** The engine repos use `<PackageLicenseFile>LICENSE.md</PackageLicenseFile>` only — `<PackageLicenseExpression>FSL-1.1-MIT</PackageLicenseExpression>` fails NuGet SPDX validation. Clear the inherited conditional `MIT` expression from packet 02's shared fragment so the engine nupkg carries only the file form. (MIT packages — the `*.Abstractions` package — keep `<PackageLicenseExpression>MIT</PackageLicenseExpression>`, which IS valid SPDX.)
- **`git rm` the old extensionless `LICENSE`.** Both repos currently carry an extensionless `LICENSE` (MIT). Remove it when adding `LICENSE.md` — no extensionless `LICENSE` may remain. A stale MIT file beside the new FSL file is a license-clarity bug.
- **The `*.Abstractions` packages are MIT — decided.** `HoneyDrunk.Notify.Abstractions` and `HoneyDrunk.Communications.Abstractions` carry `<PackageLicenseExpression>MIT</PackageLicenseExpression>`. Only the revenue engine repo's engine package is FSL. This is settled in this packet — not a developer flag.
- **SDK carve-out is conditional** — no `HoneyDrunk.Notify.Sdk` package exists today; do not create one. If one is added later, it gets the MIT per-project override like the `*.Abstractions` package.
- **No tag push, no release.** Agents never push tags (invariant 27). The `<PackageReleaseNotes>` license callout rides the next human-triggered release.

## Labels
`chore`, `tier-2`, `ops`, `coordination`, `adr-0039`, `wave-2`

## Agent Handoff

**Objective:** Convert `HoneyDrunk.Notify` and `HoneyDrunk.Communications` engine packages from the stale extensionless MIT `LICENSE` to FSL-1.1-MIT — `git rm` the old `LICENSE`, add `LICENSE.md` with the FSL text, set `<PackageLicenseFile>` (not `<PackageLicenseExpression>`, since FSL is not valid SPDX) engine metadata, add a README FSL section — and keep each Node's `*.Abstractions` contract package (and any SDK) on MIT.

**Target:** Coordination/tracking issue in `HoneyDrunk.Architecture` with one child issue per repo; each child branches from `main` in its own repo.

**Context:**
- Goal: Make the two designated revenue Nodes' repos match the FSL-1.1-MIT decision ADR-0027 carved and ADR-0039 D2 formalizes — they currently carry a stale MIT file.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 2.
- ADRs: ADR-0039 (D2, D3, D9, Operational Consequences), ADR-0027 (FSL precedent + SDK-stays-MIT pattern).
- In scope: `HoneyDrunk.Notify`, `HoneyDrunk.Communications`. Out: `HoneyDrunk.Notify.Cloud` (proprietary, own standup), `HoneyDrunk.Billing` and consumer-app servers (future).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0039 acceptance (soft — references ADR-0039 D2 as a live rule).
- Note: packet 02 (the MIT default in the shared fragment) is *not* a hard blocker — these repos *override* the default with FSL; the override works whether or not the shared default has landed. They are in the same wave and run in parallel.

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- Do not hand-author FSL text — source the canonical FSL-1.1-MIT template.
- Future license is MIT, not Apache-2.0.
- `git rm` the old extensionless `LICENSE`; no extensionless `LICENSE` may remain.
- `FSL-1.1-MIT` is not valid SPDX — engine repos use `<PackageLicenseFile>` only; `*.Abstractions` packages use `<PackageLicenseExpression>MIT</PackageLicenseExpression>` (valid SPDX).
- `*.Abstractions` packages are MIT — decided, not flagged.
- No SDK package exists today — do not create one.
- No tag push / no release.

**Key Files (per repo):**
- `LICENSE` (extensionless — `git rm`'d) / `LICENSE.md` (new — FSL text)
- repo-root `Directory.Build.props` (engine package license metadata — `PackageLicenseFile`, clear inherited expression)
- the `*.Abstractions` project `.csproj` (`<PackageLicenseExpression>MIT</PackageLicenseExpression>`)
- `README.md` (FSL section)
- `CHANGELOG.md`

**Contracts:** No runtime contract change — license metadata only. The engine package surfaces the FSL `LICENSE.md` (packed-file form); the `*.Abstractions` contract package stays MIT (`<PackageLicenseExpression>MIT</PackageLicenseExpression>`) so downstream Nodes compiling against it per invariants 40/48 do not inherit the FSL non-compete.
