---
name: FSL LICENSE Application
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["chore", "tier-2", "ops", "licensing", "adr-0027"]
dependencies: ["packet:01"]
adrs: ["ADR-0027"]
accepts: ADR-0027
wave: 2
initiative: adr-0027-notify-cloud-standup
node: honeydrunk-communications
---

# Chore: Apply Functional Source License (FSL) to HoneyDrunk.Communications

## Summary
Apply the Functional Source License (FSL-1.1-Apache-2.0) to the `HoneyDrunk.Communications` repo per ADR-0027 D11. Commit the FSL-1.1-Apache-2.0 license text as `LICENSE` at the repo root, update README, configure every shipping `.csproj` to reference the license file in NuGet package metadata, bump the solution from 0.2.0 to 0.3.0.

This is the Communications-side application of the same FSL choice ADR-0027 D11 commits to for both `HoneyDrunk.Notify` (packet 03) and `HoneyDrunk.Communications` (this packet). The license text is identical between the two repos; the per-`.csproj` updates and the version bump are repo-specific.

**No code or contract changes.** This is a licensing-posture commit.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Communications`

## Motivation
ADR-0027 D11 identifies three repos for the FSL license application — `HoneyDrunk.Notify`, `HoneyDrunk.Notify.Client` (lives in `HoneyDrunk.Notify` per D6), and `HoneyDrunk.Communications`. This packet handles Communications.

Communications is the decision-layer orchestration substrate that sits between Notify Cloud and Notify. Per ADR-0027 D5, the hot delivery path is Notify Cloud → Communications → Notify — Communications is on the customer-facing critical path for every paying Notify Cloud tenant. Its license posture must match the engine's posture (FSL with two-year Apache 2.0 conversion) so:

- A self-hoster reading the public Notify engine can also self-host the Communications layer above it under the same license terms.
- The "Notify is open source under FSL" marketing-page framing (PDR-0002 §H) accurately covers the full self-hostable stack — engine + decision layer + SDK.
- Future contributors to Communications read the same license posture they read for the engine.

Same rationale as packet 03: relicensing later is hostile to early contributors; picking now means the first commercial Notify Cloud customer reads a stable license across both repos.

## Proposed Implementation

### `LICENSE` file — new file at repo root

Commit the canonical FSL-1.1-Apache-2.0 license text. Same text as packet 03 — fetch from https://fsl.software/FSL-1.1-Apache-2.0.template and inline verbatim.

Header parameters:

- **Licensor:** HoneyDrunk Studios
- **Change Date:** Two years from the date of this commit (e.g., if this PR merges on 2026-MM-DD, the Change Date is 2028-MM-DD)
- **Change License:** Apache License, Version 2.0

If packets 03 and 04 land on the same calendar day, both repos' LICENSE files will carry the same Change Date — that is fine and expected.

### `README.md` — license section update

Add or update a `## License` section near the bottom of the existing `README.md`:

```markdown
## License

HoneyDrunk.Communications is released under the [Functional Source License v1.1](https://fsl.software/), with automatic conversion to the Apache License, Version 2.0 two years after the date of each release. See [LICENSE](./LICENSE) for the full text.

The license permits any non-competing use — read, modify, self-host, redistribute. The only restriction is using HoneyDrunk.Communications to provide a hosted commercial messaging-orchestration service that competes with HoneyDrunk Notify Cloud. After the two-year conversion date, even that restriction is lifted (under Apache 2.0).

This matches the license posture of [HoneyDrunk.Notify](https://github.com/HoneyDrunkStudios/HoneyDrunk.Notify) — the two repos are designed to be consumed together for a self-hosted notification stack.
```

If the README already has a license section (e.g., MIT or Apache), replace it with the FSL section above.

### Update repo description (GitHub UI)

The repo description should reference the license. Suggested text:

> Outbound-messaging orchestration substrate above HoneyDrunk.Notify — recipient resolution, preference enforcement, cadence policy, decision logs. Released under FSL-1.1-Apache-2.0. Composed by HoneyDrunk Notify Cloud (commercial wrapper) and self-hosting consumers alike.

This is a GitHub UI update via Settings → Description; not a file commit. The packet's Human Prerequisites section calls it out.

### Per-`.csproj` license metadata updates

Every shipping `.csproj` in `src/*` must declare the license in its package metadata. Edit each `.csproj` to add (or update if a `PackageLicenseExpression` already exists):

```xml
<PropertyGroup>
  <!-- existing properties -->
  <PackageLicenseFile>LICENSE</PackageLicenseFile>
</PropertyGroup>

<ItemGroup>
  <None Include="..\..\LICENSE" Pack="true" PackagePath="\" />
</ItemGroup>
```

(Adjust the `..\..\LICENSE` path relative to the project file location.)

Same reasoning as packet 03: do not use `PackageLicenseExpression` with an SPDX identifier — FSL is not in the SPDX list. `PackageLicenseFile` + `<None Include=... Pack="true">` packages the LICENSE into the .nupkg. If the existing `.csproj` has a `<PackageLicenseExpression>` declaration, remove it.

Apply to every `.csproj` under `src/`:

- `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj`
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj`

(If additional shipping projects exist in `src/` — confirm at edit time by listing the directory — apply the metadata update to each.)

Do **not** edit `tests/*.csproj` — test projects do not ship as NuGet packages.

### Version bump

Per invariant 27 ("All projects in a solution share one version and move together"), this is the bumping packet on the Communications solution for this initiative. Bump from 0.2.0 to **0.3.0** (minor bump — license addition is a package-metadata addition, not a breaking API change).

Update the solution-shared `<Version>` in `Directory.Build.props` (or wherever the centralized version property lives — confirm by reading the file). Every `src/*.csproj` picks up the version from there per the existing solution pattern. Test projects are excluded.

### Repo-level `CHANGELOG.md`

Per invariant 12, this packet creates a new repo-level version entry. Add a `## [0.3.0] - 2026-MM-DD` block (replace `MM-DD` with the date the PR merges) with:

```markdown
## [0.3.0] - 2026-MM-DD

### Added
- FSL-1.1-Apache-2.0 license file at repo root. Two-year auto-conversion to Apache 2.0 per ADR-0027 D11.
- README.md license section pointing at LICENSE.
- Per-`.csproj` `PackageLicenseFile` metadata so NuGet packages declare the license.

### Notes
- This is a licensing-posture commit. No code or contract changes. All public APIs unchanged.
- Matches the license posture applied to HoneyDrunk.Notify v0.4.0 (the two repos ship together as a self-hostable notification stack).
- See [HoneyDrunk Architecture ADR-0027](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D11 for the rationale.
```

### Per-package `CHANGELOG.md`

Per invariant 12, per-package changelogs are updated only for packages with actual changes. Both shipping packages (`HoneyDrunk.Communications.Abstractions`, `HoneyDrunk.Communications`) receive the license-metadata update, so both get an entry:

```markdown
## [0.3.0] - 2026-MM-DD

### Added
- `PackageLicenseFile` metadata declaring FSL-1.1-Apache-2.0 license.
```

## Affected Files
- `LICENSE` (new file at repo root)
- `README.md` (license section update)
- `Directory.Build.props` (version bump from 0.2.0 to 0.3.0)
- Every shipping `.csproj` under `src/`:
  - `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj`
  - `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj`
  - (and any other shipping projects discovered at edit time)
- Repo-level `CHANGELOG.md` (new `## [0.3.0]` entry)
- Per-package `CHANGELOG.md` files (one entry per shipping package)

## NuGet Dependencies
None. This packet adds no PackageReference entries. It only updates `.csproj` metadata (`PackageLicenseFile`, version) and packages the LICENSE file into NuGet artifacts via `<None Include=... Pack="true">`.

## Boundary Check
- [x] All edits inside the `HoneyDrunk.Communications` repo.
- [x] No code changes — `.cs` files are untouched.
- [x] No contract changes — public API surface is unchanged at v0.3.0.
- [x] Test projects are excluded from the version bump per invariant 27.
- [x] License text is the canonical FSL-1.1-Apache-2.0 verbatim; no paraphrase.

## Acceptance Criteria
- [ ] `LICENSE` file exists at repo root with the canonical FSL-1.1-Apache-2.0 text. Header parameters set: Licensor = HoneyDrunk Studios, Change Date = two years from the PR merge date, Change License = Apache License, Version 2.0.
- [ ] `README.md` has a `## License` section pointing at `LICENSE` with the FSL framing described above. Any pre-existing license section is removed.
- [ ] Every shipping `.csproj` under `src/` declares `<PackageLicenseFile>LICENSE</PackageLicenseFile>` and `<None Include="..\..\LICENSE" Pack="true" PackagePath="\" />` (path adjusted per project depth). No `.csproj` carries both `PackageLicenseExpression` and `PackageLicenseFile`.
- [ ] Solution version bumped from 0.2.0 to 0.3.0 in `Directory.Build.props`. Every shipping `.csproj` resolves to 0.3.0 at build time. Test projects are unaffected.
- [ ] Repo-level `CHANGELOG.md` has a new `## [0.3.0] - YYYY-MM-DD` entry covering the license addition, with rationale link to ADR-0027 D11.
- [ ] Per-package `CHANGELOG.md` files (`HoneyDrunk.Communications.Abstractions`, `HoneyDrunk.Communications`, and any other shipping packages) each have a `## [0.3.0]` entry with the license-metadata text.
- [ ] `dotnet pack` runs clean across all shipping projects with no warnings about license metadata. The produced `.nupkg` files each contain the `LICENSE` file at the root.
- [ ] Build is clean: `dotnet build` passes with no warnings (warnings-as-errors).
- [ ] No `.cs` files are modified. License application is metadata-only.
- [ ] `tests/*` are unchanged (no version bumps, no metadata changes).
- [ ] PR body explicitly references ADR-0027 D11 with the link to the ADR file.

## Human Prerequisites
- [ ] Update the GitHub repo description via Settings → General → Description on https://github.com/HoneyDrunkStudios/HoneyDrunk.Communications. Suggested text: "Outbound-messaging orchestration substrate above HoneyDrunk.Notify — recipient resolution, preference enforcement, cadence policy, decision logs. Released under FSL-1.1-Apache-2.0. Composed by HoneyDrunk Notify Cloud (commercial wrapper) and self-hosting consumers alike."
- [ ] After the PR merges, push tag `v0.3.0` from `main` to trigger the release workflow and publish the new packages to NuGet. Tags are human-pushed per invariant 27 — agents never push tags.
- [ ] Confirm OIDC federated credential for `repo:HoneyDrunkStudios/HoneyDrunk.Communications:ref:refs/tags/v*` is in place for the NuGet publishing identity.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Communications ships its own version cycle; the FSL application is a repo-local concern.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Two tiers: repo-level CHANGELOG.md (next to the .slnx file) is mandatory; per-package CHANGELOG.md is updated only when that specific package has functional changes. — License metadata change applies to every shipping package; every shipping per-package CHANGELOG gets an entry.

> **Invariant 27:** All projects in a solution share one version and move together. Test projects are excluded. Releases are triggered by pushing a git tag; agents never push tags. The first packet to land on a solution in an initiative bumps the version. — This is the bumping packet on the Communications solution for the adr-0027-notify-cloud-standup initiative. Every shipping project moves from 0.2.0 to 0.3.0 in this single commit.

> **Invariant 56 (assigned by packet 02 of this initiative — number subject to collision-check):** The open-source repos paired with `HoneyDrunk.Notify.Cloud` (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`) ship under the Functional Source License (FSL) with two-year auto-conversion to Apache 2.0. The license file is committed at the repo root; every shipping `.csproj` declares `PackageLicenseFile` (or `PackageLicenseExpression = "LicenseRef-FSL-1.1-Apache-2.0"`). The wrapper repo (`HoneyDrunk.Notify.Cloud`, private) is `LicenseRef-Proprietary`. — This packet is the application of that invariant to the Communications repo.

## Referenced ADR Decisions

**ADR-0027 D5 (Boundary rule):** The hot delivery path for Notify Cloud customers is Notify Cloud → Communications → Notify. Communications is on the customer-facing critical path; its license must match the engine's so the full self-hostable stack reads with one license posture. — Reinforces the substance of D11 applied to this repo.

**ADR-0027 D11 (FSL on open engine repos):** Open-source repos paired with Notify Cloud ship under FSL with two-year auto-conversion to Apache 2.0. Three repos identified: `HoneyDrunk.Notify` (engine + SDK), `HoneyDrunk.Notify.Client` (lives in `HoneyDrunk.Notify` per D6), `HoneyDrunk.Communications` (this repo). — This packet is the substance of D11 applied to the Communications repo. Identical license text to packet 03; different target repo, different per-`.csproj` updates, different version bump.

## Dependencies
- `packet:01` — packet 01 lands the new constitution language and context-folder content that references FSL. Filing 04 before 01 would mean the FSL commit lands without a constitutional anchor describing why.

## Labels
`chore`, `tier-2`, `ops`, `licensing`, `adr-0027`

## Agent Handoff

**Objective:** Apply the Functional Source License (FSL-1.1-Apache-2.0) to the `HoneyDrunk.Communications` repo. Commit the canonical license text at the repo root, update README, update every shipping `.csproj`'s license metadata, bump the solution version from 0.2.0 to 0.3.0, update CHANGELOGs.

**Target:** HoneyDrunk.Communications, branch from `main`.

**Context:**
- Goal: Match the license posture applied to `HoneyDrunk.Notify` (packet 03). The two repos ship together as a self-hostable notification stack and must read with one license posture.
- Feature: ADR-0027 standup initiative, Wave 2, Packet 04.
- ADRs: ADR-0027 (sole governing ADR for the license choice).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 of this initiative must merge first (constitutional context for FSL).

**Constraints:**

- **The license text is canonical FSL-1.1-Apache-2.0 verbatim.** Fetch from https://fsl.software/. Identical body text to packet 03; only the three header parameters (Licensor, Change Date, Change License) are customized — and those values match packet 03.
- **No code or contract changes in this packet.** `.cs` files are untouched. Public API surface at v0.3.0 is identical to v0.2.0.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. Two tiers — repo-level mandatory, per-package only when the package has functional changes. — License metadata change applies to every shipping package; every shipping per-package CHANGELOG gets an entry.
- **Invariant 27:** All projects share one version. Test projects excluded. Releases are triggered by pushing a git tag; agents never push tags. — This is the bumping packet. Every shipping `.csproj` resolves to 0.3.0.
- **FSL is not in the SPDX list.** Use `<PackageLicenseFile>LICENSE</PackageLicenseFile>` plus `<None Include=... Pack="true">`. Do not use `<PackageLicenseExpression>`. If one exists in any `.csproj`, remove it.
- **Test projects are excluded.** No edits to `tests/*.csproj`.
- **No commits under CHANGELOG `Unreleased`.** Per the user's standing rule, commits land under a dated versioned entry — `## [0.3.0] - YYYY-MM-DD`.

**Key Files:**
- `LICENSE` (new file at repo root — canonical FSL-1.1-Apache-2.0 text)
- `README.md` (replace any existing license section)
- `Directory.Build.props` (or wherever the centralized version property lives — bump 0.2.0 → 0.3.0)
- Every shipping `.csproj` under `src/` (add `<PackageLicenseFile>` and `<None Include=... Pack="true">`; remove any `<PackageLicenseExpression>`)
- Repo-level `CHANGELOG.md` (new `## [0.3.0]` entry)
- Per-package `CHANGELOG.md` files (one entry per shipping package)

**Contracts:** None. Public API surface at 0.3.0 is identical to 0.2.0.
