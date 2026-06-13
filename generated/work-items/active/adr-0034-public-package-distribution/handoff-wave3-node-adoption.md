# Handoff: Wave 2 → Wave 3 (publish mechanism → per-Node adoption + signing)

**Read once at the Wave 2 → Wave 3 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## What Waves 1–2 delivered (upstream changes Wave 3 builds on)

- **ADR-0034 is Accepted** (packet 00). Its three new packaging invariants are live in `constitution/invariants.md`: (1) every public package is owned by `HoneyDrunkStudios` on nuget.org; (2) every public package ships SourceLink + symbols, build fails otherwise; (3) package publish runs through the HoneyDrunk.Actions reusable workflow, not inline `dotnet nuget push`. D1–D8 are now binding rules. ADR-0034's acceptance PR was merged together with ADR-0035's (D7 — they land together).
- **`catalogs/package-feeds.json` exists** (packet 01) — the approved-feeds allowlist. Three feeds: `nuget-org-public` (public), `github-packages-private` (private), `azure-artifacts-prerelease` (prerelease-staging). It is the single source of truth; `job-publish-nuget.yml` validates its `feed` input against it.
- **The `HoneyDrunk.Standards` packaging-metadata + SourceLink fragment exists** (packet 02) — a `Directory.Build.props` fragment carrying the thirteen ADR-0034 D3 metadata fields, the six D4 SourceLink/determinism properties, the `Microsoft.SourceLink.GitHub` reference (`PrivateAssets="all"`), the packed Studios icon asset, and a build-failing MSBuild target that fails the build when any required D3 field is empty on a packable project. It is scoped to `$(IsPackable)` — it never touches test projects.
- **`job-publish-nuget.yml` exists in HoneyDrunk.Actions** (packet 03) — a reusable `workflow_call` workflow taking `package-id` / `version` / `feed`, handling auth → conditional sign → push → post-publish metadata verification, pushing `.snupkg` alongside the main package, and validating `feed` against `catalogs/package-feeds.json`. The sign stage is conditional: it author-signs when the code-signing certificate is present in the Studios Key Vault and logs an explicit `Publishing UNSIGNED` line when it is absent (BDR-0001 pending).

## Contracts Wave 3 consumes

- **The `HoneyDrunk.Standards` packaging-metadata fragment** — packet 05's per-Node adoption imports it into each repo-root `Directory.Build.props`. Confirm the consumption mechanism the repo already uses for the `HoneyDrunk.Standards` analyzer set and match it. The fragment leaves `RepositoryUrl`, `PackageProjectUrl`, and `PackageLicenseExpression` as slots the Node supplies, and `PackageId` / `Description` / `PackageTags` as per-project overrides.
- **`job-publish-nuget.yml` `workflow_call` contract** — inputs `package-id`, `version`, `feed`. The `feed` input takes a `catalogs/package-feeds.json` feed-id key: `nuget-org-public` | `github-packages-private` | `azure-artifacts-prerelease` (the workflow validates `feed` by exact `feed-id` match against the catalog). Packet 05's per-Node release-workflow amendments call it at a pinned ref. Confirm the pinned ref before filing packet 05.
- **The caller-permissions contract** — callers of `job-publish-nuget.yml` must grant `id-token: write` (federated OIDC for the signing-cert fetch and the `feed: github-packages-private` token) and `packages: write` when `feed: github-packages-private`. Documented in HoneyDrunk.Actions `docs/consumer-usage.md`.
- **`catalogs/package-feeds.json`** — the feed-id values packet 05's release workflows pass as `feed`: `nuget-org-public` for stable, `azure-artifacts-prerelease` for pre-release (`-preview.N` / `-rc.N`) per ADR-0034 D1.

## Wave 3 objectives

1. **Per-Node adoption fan-out** (packet 05) — across the **11 package-producing .NET Node repos**: Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications. Per repo: import the metadata fragment, supply the Node-level metadata slots, set the three per-project overrides on every packable project, ensure every package directory has a packed `README.md`, verify the build-failing metadata-enforcement target passes, and amend the release workflow to call `job-publish-nuget.yml` — removing every inline `dotnet nuget push`. Update `repos/{Node}/integration-points.md` with each Node's published feed.
   - **OUT of the fan-out:** `HoneyDrunk.Architecture`, `HoneyDrunk.Studios`, `HoneyDrunk.Actions` — none ships any NuGet package (Architecture is docs/catalogs, Studios is a Next.js site, Actions ships reusable workflows; exclusion is by what the repo produces, not a catalog flag — `catalogs/nodes.json` has no `packages` field); `HoneyDrunk.Standards` (self-adopts in packet 02); the 10 Seed Nodes (adopt at their own standup); private revenue Nodes (GitHub Packages path, own standup). The 11-repo list is pinned and fixed — no repo is added or dropped at filing time. `HoneyDrunk.Audit` is `signal: "Seed"` (not Live) but it is scaffolded and package-producing — buildable `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data` from the ADR-0030/0031 standup. Fan-out membership is the scaffolded-and-package-producing test, not the Live signal, so Audit is a permanent member.
2. **Signing-certificate procurement** (packet 04) — `Actor=Human`, `human-only`. After BDR-0001 lands, procure a code-signing certificate with subject = the finalized HoneyDrunk Studios legal entity, import it into the Studios Key Vault, confirm the federated-OIDC fetch path, and verify `job-publish-nuget.yml`'s sign stage flips packages from unsigned to signed.

## Constraints carried into Wave 3

> **Invariant — public package nuget.org ownership** (added by packet 00). Every public package is owned by `HoneyDrunkStudios` on nuget.org. No fork-owned, no individual-developer-owned public packages.

> **Invariant — SourceLink + symbols** (added by packet 00). Every public package ships SourceLink + symbols; the build fails if SourceLink is not produced. Packet 05's adoption brings this in via the imported fragment — verify the `.snupkg` is produced for every packable project.

> **Invariant — publish via reusable workflow** (added by packet 00). Consumer release workflows do not call `dotnet nuget push` directly. Packet 05 must leave **zero** `dotnet nuget push` in any of the 11 repos.

> **Invariant 12 — Semantic versioning with CHANGELOG and README.** Every package directory must contain a `README.md`. Packet 05 ensures `PackageReadmeFile` resolves to it and packs it; create the README where one is missing.

> **Invariant 27 — per-package changelogs only for packages with actual changes.** The metadata adoption is a tooling change — one repo-level `CHANGELOG.md` entry per repo; no per-package changelog noise for packages whose only change is the imported fragment. Packet 05 does not push tags / trigger a release (agents never push tags).

> **Invariant 1 — Abstractions packages have zero runtime HoneyDrunk dependencies.** `Microsoft.SourceLink.GitHub` is `PrivateAssets="all"` — a build-time source-indexer, not a runtime dependency — so importing the fragment into an `.Abstractions` project does not violate this.

> **Invariant 9 — Vault is the only source of secrets.** Packet 04's code-signing certificate private key lives in the Studios Key Vault, accessed via federated OIDC — never a stored secret, never a key on a laptop, no long-lived signing PAT.

- **Per-slot package identity.** Every packable project — Abstractions, default backing, providers, `.AspNetCore` — gets its own `PackageId`. Do not collapse a repo to one package (ADR-0034 Alternatives explicitly rejects "one package per repo").
- **Packet 04 is hard-gated on BDR-0001.** Do not file or start it until the human confirms the Sunbiz amendment has landed. Packets 00–03 and 05 publish unsigned in the interim — that is the ADR-0034 D5 design, not a defect.
- **Packets 04 and 05 are independent.** They may run in parallel. Packet 05's fan-out does not wait on the signing certificate; the publish workflow handles unsigned and signed identically (sign stage is conditional).

## Acceptance signal for Wave 3 completion

All 11 package-producing Nodes import the metadata fragment, set per-project + Node-level metadata, pack per-package READMEs, produce SourceLink + `.snupkg`, and call `job-publish-nuget.yml` from their release workflows with no `dotnet nuget push` remaining; `repos/{Node}/integration-points.md` records each Node's published feed. *Conditional:* if BDR-0001 has landed, the code-signing certificate is procured + seeded and published packages are author-signed (packet 04); if not, Wave 3 exits on packet 05 alone and packet 04 is filed later when BDR-0001 clears. The initiative archives when every filed and in-scope packet — including packet 04 — is `Done`.
