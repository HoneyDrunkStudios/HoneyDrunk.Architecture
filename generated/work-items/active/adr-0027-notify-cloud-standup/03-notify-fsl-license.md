---
name: FSL LICENSE Application
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["chore", "tier-2", "ops", "licensing", "adr-0027"]
dependencies: ["work-item:01"]
adrs: ["ADR-0027"]
accepts: ADR-0027
wave: 2
initiative: adr-0027-notify-cloud-standup
node: honeydrunk-notify
---

> **STATUS - superseded by NovOutbox (2026-06-13):** Retained for historical traceability only. Do not execute this packet until the open-engine licensing work is revalidated against the NovOutbox supersession in PR #627.

# Chore: Apply Functional Source License (FSL) to HoneyDrunk.Notify

## Summary
Apply the Functional Source License (FSL-1.1-Apache-2.0) to the `HoneyDrunk.Notify` repo per ADR-0027 D11. This covers both the engine (`HoneyDrunk.Notify`, `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Notify.Functions`, `HoneyDrunk.Notify.Hosting.AspNetCore`) and the customer-facing SDK (`HoneyDrunk.Notify.Client` — lives in this repo per ADR-0027 D6).

Commit the FSL-1.1-Apache-2.0 license text as `LICENSE` at the repo root, update the repo description to call out the FSL license, and configure every shipping `.csproj` to reference the license file in NuGet package metadata. **No code or contract changes.** This is a licensing-posture commit.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Motivation
PDR-0002 §M deferred the FSL-vs-BSL choice to the Notify Cloud standup ADR. ADR-0027 D11 picks **FSL** and identifies three repos to apply it to: `HoneyDrunk.Notify` (the engine + the SDK), `HoneyDrunk.Notify.Client` (lives inside `HoneyDrunk.Notify` per D6 but covered explicitly), and `HoneyDrunk.Communications` (the orchestration layer). This packet handles the Notify repo; packet 04 handles the Communications repo. Both packets land the same license text but in different target repos with different per-`.csproj` package metadata updates.

The license decision must land before:

- The first commercial Notify Cloud customer reads a marketing page that says "Notify is open source under FSL — read it, modify it, self-host it, redistribute it" (PDR-0002 §H framing).
- `HoneyDrunk.Notify.Cloud` ships v0.1.0 of its scaffold (packet 06 of this initiative) — that packet's CHANGELOG and marketing-adjacent text reference FSL as a settled posture.
- Any new contributor commits code expecting the repo to stay MIT or Apache-only — relicensing later is hostile to early contributors, so the license posture must be settled now.

**Why FSL (the substance of ADR-0027 D11), restated briefly for the repo's commit message and PR body:**

- Solo-dev defaults beat configuration. FSL is a single license file with a fixed two-year auto-conversion to Apache 2.0. BSL requires the licensor to specify a Change Date and Change License per release; the default Change Date is four years out.
- Two-year conversion matches the kill-clock cadence (PDR-0002).
- The competitor restriction is the only commercially load-bearing FSL clause — both FSL and BSL block "host this as a competing commercial service."
- Sentry's precedent (developer-tooling SaaS sold to indies) is closer to Notify Cloud's buyer profile than HashiCorp's (enterprise infrastructure).
- Build-in-public alignment — FSL text is short, plain-language, and easy for an indie .NET dev to read on a marketing site and trust.

## Proposed Implementation

### `LICENSE` file — new file at repo root

Commit the canonical FSL-1.1-Apache-2.0 license text. The canonical source is https://fsl.software/ — fetch the FSL-1.1-Apache-2.0 variant (the Apache-2.0-convertible variant) and commit it verbatim.

The FSL text has a header block that includes the licensor name and the "Change Date" / "Change License" parameters baked into the text — those are the two-year-from-publication date and Apache-2.0 respectively. Use:

- **Licensor:** HoneyDrunk Studios
- **Change Date:** Two years from the date of this commit (i.e., if this PR merges on 2026-MM-DD, the Change Date is 2028-MM-DD)
- **Change License:** Apache License, Version 2.0

The full FSL-1.1-Apache-2.0 text is approximately 600 words and can be fetched directly from https://fsl.software/FSL-1.1-Apache-2.0.template. Inline the canonical text in the commit — do not write a paraphrase or summary. The PR body should link to https://fsl.software/ for reviewers.

### `README.md` — license section update

Add or update a `## License` section near the bottom of the existing `README.md`:

```markdown
## License

HoneyDrunk.Notify is released under the [Functional Source License v1.1](https://fsl.software/), with automatic conversion to the Apache License, Version 2.0 two years after the date of each release. See [LICENSE](./LICENSE) for the full text.

The license permits any non-competing use — read, modify, self-host, redistribute. The only restriction is using HoneyDrunk.Notify to provide a hosted notification service that competes with HoneyDrunk Notify Cloud. After the two-year conversion date, even that restriction is lifted (under Apache 2.0).

The customer-facing SDK `HoneyDrunk.Notify.Client` lives in this repo and ships under the same license.
```

If the README already has a license section (e.g., MIT or Apache), replace it with the FSL section above.

### Update repo description (GitHub UI)

The repo description should reference the license. Suggested text:

> Channel-agnostic notification intake and delivery engine for .NET — multi-provider (Resend, Twilio, SMTP), queue-backed. Released under FSL-1.1-Apache-2.0. The hosted commercial service (HoneyDrunk Notify Cloud) sits above this engine.

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

(Adjust the `..\..\LICENSE` path relative to the project file location — depending on the project's depth in `src/`, the relative path may be `..\LICENSE` or `..\..\LICENSE`.)

**Do not** use `PackageLicenseExpression` with an SPDX identifier — FSL is not in the SPDX list (as of 2026-05). The `LicenseRef-` extension exists for non-SPDX licenses but is less widely supported by NuGet tooling than `PackageLicenseFile`. The `<PackageLicenseFile>` + `<None Include=... Pack="true">` pattern packages the LICENSE file into the .nupkg and is the canonical NuGet shape for non-SPDX licenses.

If the existing `.csproj` has a `<PackageLicenseExpression>MIT</PackageLicenseExpression>` or similar, remove that line. NuGet errors on having both `PackageLicenseExpression` and `PackageLicenseFile`.

Apply to every `.csproj` under `src/`:

- `src/HoneyDrunk.Notify.Abstractions/HoneyDrunk.Notify.Abstractions.csproj`
- `src/HoneyDrunk.Notify/HoneyDrunk.Notify.csproj`
- `src/HoneyDrunk.Notify.Functions/HoneyDrunk.Notify.Functions.csproj`
- `src/HoneyDrunk.Notify.Hosting.AspNetCore/HoneyDrunk.Notify.Hosting.AspNetCore.csproj`
- `src/HoneyDrunk.Notify.Client/HoneyDrunk.Notify.Client.csproj` (if it exists as a separate `src/` directory; otherwise it's part of the `HoneyDrunk.Notify` runtime project — confirm at edit time)

Do **not** edit `tests/*.csproj` — test projects do not ship as NuGet packages.

### Version bump

Per invariant 27 ("All projects in a solution share one version and move together. The first packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only."), this is the bumping packet on the Notify solution for this initiative. Bump the solution version from 0.3.0 to **0.4.0** (minor bump — license change is a metadata addition to the package, not a breaking change to public API).

Update the solution-shared `<Version>` in `Directory.Build.props` (or wherever the centralized version property lives — confirm by reading the file). Every `src/*.csproj` picks up the version from there per the existing solution pattern. If any project overrides the centralized version, fix that override so all shipping projects ship at 0.4.0.

Test projects are excluded from the version bump per invariant 27.

### Repo-level `CHANGELOG.md`

Per invariant 12, this packet must create a new repo-level version entry. Add a `## [0.4.0] - 2026-MM-DD` block (replace `MM-DD` with the date the PR merges) with:

```markdown
## [0.4.0] - 2026-MM-DD

### Added
- FSL-1.1-Apache-2.0 license file at repo root. Two-year auto-conversion to Apache 2.0 per ADR-0027 D11.
- README.md license section pointing at LICENSE.
- Per-`.csproj` `PackageLicenseFile` metadata so NuGet packages declare the license.

### Notes
- This is a licensing-posture commit. No code or contract changes. All public APIs unchanged.
- The customer-facing SDK `HoneyDrunk.Notify.Client` is covered by the same LICENSE (lives in this repo per ADR-0027 D6).
- See [HoneyDrunk Architecture ADR-0027](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D11 for the rationale.
```

### Per-package `CHANGELOG.md`

Per invariant 12, per-package changelogs are updated **only for packages with actual changes**. Since this packet adds the LICENSE file (a package-metadata change) to every shipping package, every shipping package gets an entry. The entry text is identical across packages — license metadata is the substance:

```markdown
## [0.4.0] - 2026-MM-DD

### Added
- `PackageLicenseFile` metadata declaring FSL-1.1-Apache-2.0 license.
```

Update each shipping package's `CHANGELOG.md` (whatever path the existing repo uses — typically `src/{Package}/CHANGELOG.md`). Do **not** add noise entries to per-package CHANGELOGs whose package metadata did not change — but every shipping `.csproj` in this packet's affected-files list got the metadata update, so every shipping package's CHANGELOG gets an entry.

## Affected Files
- `LICENSE` (new file at repo root)
- `README.md` (license section update)
- `Directory.Build.props` (version bump from 0.3.0 to 0.4.0)
- Every shipping `.csproj` under `src/`:
  - `src/HoneyDrunk.Notify.Abstractions/HoneyDrunk.Notify.Abstractions.csproj`
  - `src/HoneyDrunk.Notify/HoneyDrunk.Notify.csproj`
  - `src/HoneyDrunk.Notify.Functions/HoneyDrunk.Notify.Functions.csproj`
  - `src/HoneyDrunk.Notify.Hosting.AspNetCore/HoneyDrunk.Notify.Hosting.AspNetCore.csproj`
  - `src/HoneyDrunk.Notify.Client/HoneyDrunk.Notify.Client.csproj` (if it exists as a separate project)
- Repo-level `CHANGELOG.md` (new `## [0.4.0]` entry)
- Per-package `CHANGELOG.md` files (one entry per shipping package)

## NuGet Dependencies
None. This packet adds no PackageReference entries. It only updates existing `.csproj` metadata (`PackageLicenseFile`, version) and packages the LICENSE file into NuGet artifacts via `<None Include=... Pack="true">`.

## Boundary Check
- [x] All edits inside the `HoneyDrunk.Notify` repo.
- [x] No code changes — `.cs` files are untouched.
- [x] No contract changes — public API surface is unchanged at v0.4.0.
- [x] Test projects are excluded from the version bump per invariant 27.
- [x] License text is the canonical FSL-1.1-Apache-2.0 verbatim; no paraphrase, no studio-authored variant.

## Acceptance Criteria
- [ ] `LICENSE` file exists at repo root with the canonical FSL-1.1-Apache-2.0 text. The header parameters are set: Licensor = HoneyDrunk Studios, Change Date = two years from the PR merge date, Change License = Apache License, Version 2.0.
- [ ] `README.md` has a `## License` section pointing at `LICENSE` with the FSL framing described above. Any pre-existing license section (e.g., MIT, Apache) is removed.
- [ ] Every shipping `.csproj` under `src/` declares `<PackageLicenseFile>LICENSE</PackageLicenseFile>` and `<None Include="..\..\LICENSE" Pack="true" PackagePath="\" />` (path adjusted per project depth). No `.csproj` carries both `PackageLicenseExpression` and `PackageLicenseFile` — NuGet errors on that combination.
- [ ] Solution version bumped from 0.3.0 to 0.4.0 in `Directory.Build.props` (or wherever the centralized version property lives). Every shipping `.csproj` resolves to 0.4.0 at build time. Test projects are unaffected (per invariant 27).
- [ ] Repo-level `CHANGELOG.md` has a new `## [0.4.0] - YYYY-MM-DD` entry covering the license addition, with rationale link to ADR-0027 D11.
- [ ] Per-package `CHANGELOG.md` files updated for every shipping package with the license-metadata entry.
- [ ] `dotnet pack` runs clean across all shipping projects with no warnings about license metadata. The produced `.nupkg` files each contain the `LICENSE` file at the root.
- [ ] Build is clean: `dotnet build` passes with no warnings (warnings-as-errors).
- [ ] No `.cs` files are modified in the diff. License application is metadata-only.
- [ ] `tests/*` are unchanged (no version bumps, no metadata changes).
- [ ] PR body explicitly references ADR-0027 D11 with the link to the ADR file, and quotes the four FSL-vs-BSL rationales (solo-dev defaults beat configuration; two-year conversion matches kill-clock cadence; competitor restriction is the only commercially load-bearing clause; Sentry precedent; build-in-public alignment).

## Human Prerequisites
- [ ] Update the GitHub repo description via Settings → General → Description on https://github.com/HoneyDrunkStudios/HoneyDrunk.Notify. Suggested text: "Channel-agnostic notification intake and delivery engine for .NET — multi-provider (Resend, Twilio, SMTP), queue-backed. Released under FSL-1.1-Apache-2.0. The hosted commercial service (HoneyDrunk Notify Cloud) sits above this engine." This is a GitHub UI action; the agent cannot perform it.
- [ ] After the PR merges, push tag `v0.4.0` from `main` to trigger the release workflow and publish the new packages to NuGet. Tags are human-pushed per invariant 27 — agents never push tags.
- [ ] Confirm OIDC federated credential for `repo:HoneyDrunkStudios/HoneyDrunk.Notify:ref:refs/tags/v*` is in place for the NuGet publishing identity (almost certainly already configured for this repo, but worth a quick check). Cross-link: [infrastructure/walkthroughs/oidc-federated-credentials.md](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Notify ships its own version cycle; the FSL application is a repo-local concern that does not propagate to other repos' versioning.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Breaking changes bump major. New features bump minor. Fixes bump patch. Changelogs follow Keep a Changelog format. Two tiers: repo-level CHANGELOG.md (next to the .slnx file) is mandatory; per-package CHANGELOG.md (inside each package directory) is updated only when that specific package has functional changes. — License metadata change applies to every shipping package, so every shipping per-package CHANGELOG gets an entry.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every .csproj in the solution (excluding test projects) is updated to the same new version in a single commit. Partial bumps — where some projects in a solution are on a different version than others — are forbidden. Releases are triggered by pushing a git tag; agents never push tags. The first packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only. The repo-level CHANGELOG.md must always get an entry for the new version. Per-package changelogs are updated only for packages with actual changes — do not add alignment-bump noise entries. — This is the bumping packet on the Notify solution for the adr-0027-notify-cloud-standup initiative. Every shipping project moves from 0.3.0 to 0.4.0 in this single commit. Test projects do not bump.

> **Invariant 56 (assigned by packet 02 of this initiative — number subject to collision-check):** The open-source repos paired with `HoneyDrunk.Notify.Cloud` (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`) ship under the Functional Source License (FSL) with two-year auto-conversion to Apache 2.0. The license file is committed at the repo root; every shipping `.csproj` declares `PackageLicenseFile` (or `PackageLicenseExpression = "LicenseRef-FSL-1.1-Apache-2.0"`). The wrapper repo (`HoneyDrunk.Notify.Cloud`, private) is `LicenseRef-Proprietary`. — This packet is the application of that invariant to the Notify repo. The invariant number is subject to collision-check by packet 02; if the number shifts, this packet's body and acceptance criteria refer to the rule by phrase rather than by number ("the FSL invariant landed by packet 02 of this initiative").

## Referenced ADR Decisions

**ADR-0027 D6 (SDK lives in open Notify repo):** The customer-facing SDK `HoneyDrunk.Notify.Client` lives in the public `HoneyDrunk.Notify` repo, not in `HoneyDrunk.Notify.Cloud`. — The SDK is covered by the same FSL LICENSE as the rest of this repo. No separate license commit needed; the LICENSE file at the repo root applies to every package shipped from this repo, SDK included.

**ADR-0027 D11 (FSL on open engine repos):** Open-source repos paired with Notify Cloud ship under FSL with two-year auto-conversion to Apache 2.0. The competitor restriction (block hyperscaler rehosting) is the only commercially load-bearing FSL clause. Both FSL and BSL produce the same protection; the trade is configurability vs simplicity — FSL is a single global default (two years, Apache), BSL is per-release configurable. Solo-dev defaults beat configuration; Sentry's precedent (developer-tooling SaaS) is closer to Notify Cloud's buyer profile than HashiCorp's enterprise-infrastructure precedent. — This packet is the substance of D11 applied to the Notify repo.

## Dependencies
- `work-item:01` — packet 01 lands the new constitution language and context-folder content (especially `repos/HoneyDrunk.Notify.Cloud/overview.md`'s Visibility and Licensing section that references FSL). Filing 03 before 01 would mean the FSL commit lands without a constitutional anchor describing why.

## Labels
`chore`, `tier-2`, `ops`, `licensing`, `adr-0027`

## Agent Handoff

**Objective:** Apply the Functional Source License (FSL-1.1-Apache-2.0) to the `HoneyDrunk.Notify` repo. Commit the canonical license text at the repo root, update README, update every shipping `.csproj`'s license metadata, bump the solution version from 0.3.0 to 0.4.0, update CHANGELOGs.

**Target:** HoneyDrunk.Notify, branch from `main`.

**Context:**
- Goal: Settle the license posture for the engine + SDK before the first commercial Notify Cloud customer reads marketing copy that says "Notify is open source under FSL." Relicensing later is hostile to early contributors; picking now means the first customer reads a stable license.
- Feature: ADR-0027 standup initiative, Wave 2, Packet 03.
- ADRs: ADR-0027 (sole governing ADR for the license choice).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 of this initiative must merge first (so the constitutional context for FSL is in place).

**Constraints:**

- **The license text is canonical FSL-1.1-Apache-2.0 verbatim.** Fetch from https://fsl.software/ — do not write a paraphrase, do not author a studio-specific variant. The only customization is the three header parameters (Licensor, Change Date, Change License); the body text is the canonical license.
- **No code or contract changes in this packet.** `.cs` files are untouched. The public API surface at v0.4.0 is identical to v0.3.0. The version bump is solely a metadata change.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. Breaking changes bump major. New features bump minor. Fixes bump patch. Every repo must have a repo-level CHANGELOG.md; per-package CHANGELOG.md is updated only when that specific package has functional changes. — License metadata change applies to every shipping package; every shipping per-package CHANGELOG gets an entry.
- **Invariant 27:** All projects in a solution share one version and move together. Test projects are excluded. Releases are triggered by pushing a git tag; agents never push tags. The first packet to land on a solution in an initiative bumps the version. — This is the bumping packet. Every shipping `.csproj` resolves to 0.4.0 from `Directory.Build.props` (or wherever the centralized version lives). No partial bumps.
- **FSL is not in the SPDX list.** Use `<PackageLicenseFile>LICENSE</PackageLicenseFile>` plus `<None Include=... Pack="true">` to package the LICENSE into each `.nupkg`. Do not use `<PackageLicenseExpression>` with FSL — NuGet will error or warn. If the existing `.csproj` has a `PackageLicenseExpression`, remove that line so the metadata is unambiguous.
- **The SDK ships from this repo per ADR-0027 D6.** `HoneyDrunk.Notify.Client` is covered by the same LICENSE; do not author a separate license file or metadata for it.
- **Test projects are excluded.** Do not edit `tests/*.csproj`. They do not ship as NuGet packages and do not need license metadata.
- **No commits under CHANGELOG `Unreleased`.** Per the user's standing rule, commits land under a dated versioned entry — `## [0.4.0] - YYYY-MM-DD`.

**Key Files:**
- `LICENSE` (new file at repo root — canonical FSL-1.1-Apache-2.0 text from https://fsl.software/)
- `README.md` (replace any existing license section with the FSL section described above)
- `Directory.Build.props` (or wherever the centralized version property lives — bump 0.3.0 → 0.4.0)
- Every shipping `.csproj` under `src/` (add `<PackageLicenseFile>` and `<None Include=... Pack="true">`; remove any `<PackageLicenseExpression>`)
- Repo-level `CHANGELOG.md` (new `## [0.4.0]` entry)
- Per-package `CHANGELOG.md` files (one entry per shipping package)

**Contracts:** None. This packet does not modify any contracts or any code. The public API surface at 0.4.0 is identical to 0.3.0.
