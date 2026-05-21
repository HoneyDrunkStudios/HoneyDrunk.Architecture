# ADR-0034: Public Package Distribution and NuGet Policy

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / cross-cutting

## Context

The Grid now has 12 live Nodes (Kernel 0.7.0, Transport 0.6.0, Vault 0.5.0, Data 0.6.0, Web.Rest 0.5.0, Auth 0.4.0, Notify 0.3.0, Communications 0.2.0, Pulse 0.3.0, Actions, Architecture, Studios) plus 13 Seed Nodes designed against frozen `.Abstractions` contracts (ADR-0016 through ADR-0025, ADR-0027, ADR-0031). Internally, packages are consumed by SHA via NuGet feeds wired through `HoneyDrunk.Actions`. Externally, **none of these are formally published anywhere a third-party consumer can `dotnet add package` against.**

Three forcing functions changed this from "can defer" to "decide now":

- **PDR-0002 / ADR-0027** commits to `HoneyDrunk.Notify.Cloud` as the first commercial product. Its SDK lives in the open Notify repo (ADR-0027 D6); paying customers will install it by name. There is no public source today.
- **ADR-0026** promoted `TenantId`, `ITenantRateLimitPolicy`, and `IBillingEventEmitter` into Kernel.Abstractions. Any external consumer of Notify Cloud's SDK transitively depends on a public Kernel package.
- **ADR-0032 (Proposed)** flags NuGet leaks in PR validation, presupposing a defined "approved feeds" list that does not exist as a single artifact.

The current state is also fragmented: some Nodes publish to GitHub Packages, some to an internal Azure Artifacts feed (per Vault bootstrap secrets), and the package metadata (`Authors`, `Company`, `RepositoryUrl`, `PackageLicenseExpression`, icons) is inconsistent across Nodes. Signing is unset.

This ADR decides distribution, identity, signing, metadata, and the approved-feeds list for **public** packages. Private packages (`HoneyDrunk.Notify.Cloud.*` and any future revenue Nodes per ADR-0027 D2) are scoped separately to a private channel; the policy here governs only the public surface.

## Decision

### D1 — Primary feed: nuget.org under the `HoneyDrunkStudios` owner

All public `.Abstractions` packages and their default backings publish to **nuget.org** under a single owner account (`HoneyDrunkStudios`). nuget.org is the default `dotnet add package` resolver and the lowest-friction surface for external consumers. GitHub Packages is **not** the primary public feed — it requires authenticated pulls which defeats "install without an account."

Internal Grid consumers continue to resolve from nuget.org for these same packages; there is no internal-vs-external split for public Nodes. The internal Azure Artifacts feed (used today for pre-release SHA-pinned builds during Kernel adoption cascades) is retained as a **pre-release-only** staging surface — pre-release versions (`-preview.N`, `-rc.N`) flow there first; stable versions land on nuget.org and are never republished back.

### D2 — Private packages: GitHub Packages under the org

`HoneyDrunk.Notify.Cloud.*` (ADR-0027) and any future Node carved out as private per ADR-0027 D2 publish to **GitHub Packages** scoped to `HoneyDrunkStudios`. Authentication uses a federated GitHub Actions token (no long-lived PAT). Private feeds get a different invariant than public ones: they may publish pre-release and stable side-by-side; nuget.org constraints do not apply.

### D3 — Package identity

Every public package is named `HoneyDrunk.<Node>[.<Slot>]`. The owner field on nuget.org is `HoneyDrunkStudios`. The following metadata fields are **required** in each project file or `Directory.Build.props` and CI-enforced (build fails if missing):

- `<Authors>HoneyDrunk Studios</Authors>`
- `<Company>HoneyDrunk Studios</Company>`
- `<Product>HoneyDrunk Grid</Product>`
- `<RepositoryUrl>` — canonical GitHub repo URL
- `<RepositoryType>git</RepositoryType>`
- `<PackageProjectUrl>` — Studios product page or repo readme
- `<PackageLicenseExpression>` — SPDX expression set by ADR-0039 (license policy); never `<PackageLicenseFile>` for public packages, to avoid stale embedded text
- `<PackageReadmeFile>` — pointing to a per-package `README.md` packed into the nupkg
- `<PackageIcon>` — the Studios mark (single shared asset, packed per-project)
- `<PackageTags>` — at minimum `honeydrunk`, the sector tag, and the slot kind (`abstractions`, `backing`, `sdk`)
- `<Description>` — one paragraph
- `<RepositoryCommit>` — set by CI from `$GITHUB_SHA`

`Directory.Build.props` at the repo root is the enforcement point; per-project overrides are limited to `<PackageId>`, `<Description>`, and `<PackageTags>`.

### D4 — SourceLink and deterministic builds

All public packages enable:

- `<PublishRepositoryUrl>true</PublishRepositoryUrl>`
- `<EmbedUntrackedSources>true</EmbedUntrackedSources>`
- `<IncludeSymbols>true</IncludeSymbols>`
- `<SymbolPackageFormat>snupkg</SymbolPackageFormat>`
- `<ContinuousIntegrationBuild>true</ContinuousIntegrationBuild>` when `$CI=true`
- `<Deterministic>true</Deterministic>`

`Microsoft.SourceLink.GitHub` is referenced from `Directory.Build.props`. Symbol packages (`.snupkg`) publish alongside the main package to nuget.org's symbol server. This is non-negotiable for any public package: external debugging without SourceLink degrades the consumer experience past the point where the SDK is usable.

### D5 — Package signing

All published packages are **author-signed** with a code-signing certificate issued to "HoneyDrunk Studios" (the LLC). Per BDR-0001 the entity is mid-Sunbiz-amendment; signing certificate procurement waits on that amendment landing so the certificate subject matches the legal entity name. Until then, packages publish **unsigned** with a Proposed-status note on this ADR. Repository signing (nuget.org server-side) is unconditionally enabled in parallel.

The signing certificate's private key lives in the Studios Key Vault (per ADR-0005); CI accesses it via federated OIDC, never as a stored secret. Rotation follows ADR-0006's secret lifecycle. No long-lived signing PAT, no key on a developer laptop.

### D6 — Release workflow factoring

Package publish lives in **HoneyDrunk.Actions** as a single reusable workflow (`job-publish-nuget.yml`), called by every Node's release workflow. This preserves the ADR-0012 invariant that CI mechanics live in the control plane. Inputs: `package-id`, `version`, `feed` (nuget.org | github | azure-artifacts). The workflow handles auth, sign, push, and post-publish verification (pulls the package by name+version and asserts metadata fields are populated).

Existing Node release workflows are amended in a discrete follow-up rollout to call this reusable workflow rather than running `dotnet nuget push` inline.

### D7 — Versioning is governed by ADR-0035

This ADR decides **where and how** packages are published. The **version semantics, deprecation rules, and ABI-stability guarantees** are scoped to ADR-0035 (Abstractions Versioning and Deprecation Policy). The two ADRs must land together; neither is useful alone.

### D8 — Approved feeds list lives in catalog form

The list of approved feeds is recorded in `catalogs/package-feeds.json` (new), keyed by `feed-id`, with fields `url`, `owner`, `visibility (public|private|prerelease-staging)`, and `consumers (node-ids)`. ADR-0032's NuGet-flag check reads this catalog as the allowlist. The catalog is the single source of truth; readme tables and ADR text reference it but do not redefine it.

## Consequences

### Affected Nodes

- **All public Nodes** (12 live + Seed Nodes as they scaffold) — gain a `Directory.Build.props` update for D3/D4 metadata; release workflows are amended per D6.
- **HoneyDrunk.Actions** — new reusable `job-publish-nuget.yml`; new caller-permissions contract requiring `id-token: write` for federated OIDC to the signing cert.
- **HoneyDrunk.Vault** — stores the signing certificate (D5) once procured.
- **HoneyDrunk.Architecture** — `catalogs/package-feeds.json` is created (D8) and indexed in `catalogs/README.md`.
- **HoneyDrunk.Notify.Cloud** — uses the private path (D2) from day one; never appears on nuget.org.

### Invariants

Adds three:

- **Invariant: every public package is owned by `HoneyDrunkStudios` on nuget.org.** No fork-owned, no individual-developer-owned public packages.
- **Invariant: every public package ships SourceLink + symbols.** Build fails if SourceLink is not produced.
- **Invariant: package publish runs through the HoneyDrunk.Actions reusable workflow.** Consumer release workflows do not call `dotnet nuget push` directly. (Parallels ADR-0012's deploy-mechanics rule.)

### Operational Consequences

- nuget.org owner account `HoneyDrunkStudios` must be claimed and bound to the studio's primary email (per BDR-0001 mail-of-record). 2FA required.
- Pre-release versions transit Azure Artifacts before nuget.org; consumers pinned to pre-release builds must add the Azure Artifacts feed. Stable consumers do not.
- Until D5 signing lands, unsigned packages will produce a yellow warning in `dotnet restore` for security-conscious consumers. This is acceptable for the Proposed → Accepted window but blocks the "remove Proposed status" gate.
- The `catalogs/package-feeds.json` is a new artifact `hive-sync` (ADR-0014) must include in drift reconciliation.

### Follow-up Work

- Procure the code-signing certificate after Sunbiz amendment lands (BDR-0001).
- Claim `HoneyDrunkStudios` on nuget.org and configure org-level 2FA.
- Author the `job-publish-nuget.yml` reusable workflow in HoneyDrunk.Actions.
- Roll out `Directory.Build.props` updates to all 12 live Nodes (one packet per repo; scope agent).
- Create `catalogs/package-feeds.json` and wire it into ADR-0032's NuGet flag check.
- Update `repos/{name}/integration-points.md` for each Node with its published feed.

## Alternatives Considered

### GitHub Packages as the primary public feed

Rejected. GitHub Packages requires authenticated pulls even for public packages, breaking the "no account required to install" baseline. nuget.org is the default resolver in `dotnet`; using anything else for the public surface adds friction with no offsetting benefit.

### Azure Artifacts as the primary feed

Rejected for the same reason as GitHub Packages, plus an additional one: Azure Artifacts is locked to an Azure tenant, which puts a paying-Microsoft-tenancy precondition on every external consumer. Retained only as the pre-release staging surface (D1) because internal consumers already authenticate there.

### Skip signing until external customers actually exist

Rejected. The expected install surface (Notify Cloud SDK, ADR-0027) implies external consumers from day one of Notify Cloud GA, and signing-cert procurement has a 1–3 week lead time bound by BDR-0001 entity status. Decide now; execute when the entity name is final.

### One package per repo (no Abstractions/backing split in NuGet identity)

Rejected. The Grid's coupling rule is Abstractions-first (every AI-sector stand-up ADR pins this). External consumers must be able to take a dependency on `HoneyDrunk.AI.Abstractions` without dragging in a default backing they don't use. Per-slot package identity is non-negotiable for that rule to hold.

### Defer until a third commercial product exists

Rejected. Notify Cloud is already one. PDR-0003 through PDR-0008 (six additional consumer products) all transitively need at least Kernel.Abstractions on nuget.org. Deferring past PDR-0002 GA forces an emergency-publish under deadline pressure.
