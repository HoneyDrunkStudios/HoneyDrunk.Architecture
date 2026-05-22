---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0034", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0034", "ADR-0012", "ADR-0005"]
accepts: ["ADR-0034"]
wave: 2
initiative: adr-0034-public-package-distribution
node: honeydrunk-actions
---

# Author job-publish-nuget.yml — the single reusable package-publish workflow (ADR-0034 D6)

## Summary
Author a new reusable workflow `HoneyDrunk.Actions/.github/workflows/job-publish-nuget.yml` that handles package authentication, signing, push, and post-publish verification for any Node's release pipeline, parameterised by `package-id`, `version`, and `feed` — so package publish lives in the CI control plane and consumer release workflows never call `dotnet nuget push` directly.

## Target Workflow
**File:** `.github/workflows/job-publish-nuget.yml`
**Family:** release (reusable `workflow_call`, follows the ADR-0012 reusable-workflow factoring)

## Motivation
ADR-0034 D6 commits package publish to "a single reusable workflow (`job-publish-nuget.yml`), called by every Node's release workflow. This preserves the ADR-0012 invariant that CI mechanics live in the control plane." ADR-0034 adds an invariant (created in packet 00): "Package publish runs through the HoneyDrunk.Actions reusable workflow. Consumer release workflows do not call `dotnet nuget push` directly." Today some Nodes publish to GitHub Packages, some to an internal Azure Artifacts feed, with inline push logic that has drifted per-repo. This packet builds the one workflow that replaces all of it. Per-Node release workflows are amended to call it in packet 05.

## Proposed Change

### Workflow shape (ADR-0034 D6)
New reusable workflow callable via `workflow_call`. Inputs:
- `package-id` — the package being published (e.g. `HoneyDrunk.Kernel.Abstractions`).
- `version` — the package version (the Node's release workflow supplies it; ADR-0034 D7 / ADR-0035 govern the version *semantics* — this workflow does not compute or validate SemVer beyond what `feed` selection requires).
- `feed` — a feed-id from `catalogs/package-feeds.json`: one of `nuget-org-public` | `github-packages-private` | `azure-artifacts-prerelease`. **The `feed` input values are the catalog `feed-id` keys verbatim** — not the short names `nuget.org` / `github` / `azure-artifacts`. The workflow validates the supplied `feed` against the catalog by exact `feed-id` match, so the input enum and the catalog keys must be identical strings. (ADR-0034 D6 describes the feeds informally as "nuget.org | github | azure-artifacts"; this packet binds the actual workflow input to the catalog's `feed-id` keys so validation is a direct lookup.)

The caller passes the path to the built `.nupkg` (and `.snupkg`) artifact, or the workflow builds + packs from a checked-out repo — match the existing `HoneyDrunk.Actions` release-workflow pattern (e.g. how the Container Apps deploy workflow takes its inputs). Record the chosen artifact-handoff shape in `docs/consumer-usage.md`.

The workflow handles four stages per D6: **auth → sign → push → post-publish verification**.

### Feed selection and auth
Each `feed` value below is the exact `feed-id` key from `catalogs/package-feeds.json`:
- `feed: nuget-org-public` — push to `https://api.nuget.org/v3/index.json`. Auth via the nuget.org API key resolved from the CI-surface Key Vault (per ADR-0005; never a hardcoded secret, never echoed to logs). This is the stable-release path.
- `feed: azure-artifacts-prerelease` — push to the internal Azure Artifacts feed (URL from `catalogs/package-feeds.json`, `feed-id: azure-artifacts-prerelease`). This is the pre-release-only staging path per ADR-0034 D1 — pre-release versions (`-preview.N`, `-rc.N`) flow here first.
- `feed: github-packages-private` — push to GitHub Packages scoped to `HoneyDrunkStudios`. Per ADR-0034 D2, auth uses a **federated GitHub Actions token** — no long-lived PAT. This is the private-revenue-Node path.

The workflow validates `feed` against `catalogs/package-feeds.json` (the allowlist from packet 01) by exact `feed-id` match: an unknown feed-id is a hard failure. It also enforces the ADR-0034 D1 staging rule — a stable (non-pre-release) version targeting `azure-artifacts-prerelease` is a failure (stable lands on nuget.org, never on the staging feed), and a pre-release version targeting `nuget-org-public` is a failure or a warning per the ADR-0035 pre-release flow (default: fail; the caller opts into nuget.org pre-release explicitly if ADR-0035 allows it — record the chosen strictness in the PR).

### Signing (ADR-0034 D5)
- The workflow has a **sign** stage that author-signs the package with the code-signing certificate when one is available, resolved from the Studios Key Vault via **federated OIDC** (per ADR-0005 / ADR-0006 — never a stored secret, never a key on a developer laptop, no long-lived signing PAT).
- Per ADR-0034 D5, the signing certificate is **gated on the BDR-0001 Sunbiz amendment landing** so the certificate subject matches the legal entity name. Until then, packages publish **unsigned**. The workflow must therefore make the sign stage **conditional**: if the signing certificate secret is present in Vault, sign; if absent, skip the sign stage cleanly and publish unsigned. This is not a silent skip — the workflow logs `Publishing UNSIGNED — code-signing certificate not yet provisioned (BDR-0001 pending)` so the unsigned state is visible in every run.
- Repository signing (nuget.org server-side) is unconditionally enabled — ADR-0034 D5: "Repository signing (nuget.org server-side) is unconditionally enabled in parallel." Nothing in this workflow blocks it; it is a nuget.org account/feed setting (see Human Prerequisites).

### Post-publish verification (ADR-0034 D6)
After push, the workflow **pulls the package back by name + version** and asserts the ADR-0034 D3 metadata fields are populated (`Authors`, `Company`, `Product`, `RepositoryUrl`, `PackageLicenseExpression`, `PackageReadmeFile`, `PackageIcon`, `Description`, etc.). A package that publishes with empty required metadata fails the verification stage and the workflow run, so a metadata regression is caught at publish time, not by a consumer.

### Caller-permissions contract (ADR-0034 Consequences)
ADR-0034's Affected Nodes section: HoneyDrunk.Actions gains "a new caller-permissions contract requiring `id-token: write` for federated OIDC to the signing cert." The workflow documents in `docs/consumer-usage.md` that callers must grant `id-token: write` (for the OIDC signing-cert fetch and the `feed: github-packages-private` federated token) and `packages: write` when `feed: github-packages-private`. This mirrors the existing ADR-0012 caller-permissions contract pattern.

### Graceful behaviour
- Feed unreachable / push rejected → the workflow fails loudly with the feed's error; it never reports success on a failed push.
- `.snupkg` symbol package is pushed alongside the main package to the feed's symbol server (nuget.org's symbol server for `feed: nuget-org-public`) — ADR-0034 D4.

## Consumer Impact
- No consumer repo is affected until its release workflow is amended to call `job-publish-nuget.yml` — that is packet 05's fan-out. This workflow is purely additive.
- Existing `HoneyDrunk.Actions` reusable workflows are untouched.

## Breaking Change?
- [ ] Yes
- [x] No — new reusable workflow, additive. No consumer calls it until packet 05.

## Acceptance Criteria
- [ ] `.github/workflows/job-publish-nuget.yml` exists and is callable via `workflow_call` with inputs `package-id`, `version`, `feed`
- [ ] `feed` accepts exactly the `catalogs/package-feeds.json` feed-id keys — `nuget-org-public` / `github-packages-private` / `azure-artifacts-prerelease`; the value is validated against the catalog by exact `feed-id` match and an unknown feed is a hard failure
- [ ] nuget.org auth uses the API key from the CI-surface Key Vault; GitHub Packages auth uses a federated GitHub Actions token (no long-lived PAT) per ADR-0034 D2
- [ ] The ADR-0034 D1 staging rule is enforced: a stable version targeting `azure-artifacts` fails; pre-release-vs-nuget.org strictness is implemented and the chosen strictness recorded in the PR
- [ ] The sign stage is conditional: signs when the code-signing certificate is present in Vault (via federated OIDC), skips cleanly and logs an explicit `Publishing UNSIGNED` message when absent (BDR-0001 pending)
- [ ] The `.snupkg` symbol package is pushed alongside the main package to the feed's symbol server
- [ ] Post-publish verification pulls the package back by name+version and fails the run if any required ADR-0034 D3 metadata field is empty
- [ ] `docs/consumer-usage.md` documents the caller snippet, the `id-token: write` / `packages: write` permissions contract, and the artifact-handoff shape
- [ ] `docs/CHANGELOG.md` updated with a new entry for the `job-publish-nuget.yml` reusable workflow
- [ ] `README.md` updated to list `job-publish-nuget.yml` among the reusable workflows

## Human Prerequisites
- [ ] Claim the `HoneyDrunkStudios` owner account on nuget.org, bind it to the studio's primary email (BDR-0001 mail-of-record), and enable org-level 2FA — ADR-0034 Operational Consequences. Cross-link the infrastructure walkthrough doc if one exists.
- [ ] Generate a nuget.org API key scoped to push for `HoneyDrunk.*` packages and seed it into the CI-surface Key Vault (per ADR-0005). The workflow resolves it by name; it is never committed.
- [ ] Enable nuget.org server-side repository signing on the `HoneyDrunkStudios` account/feed — ADR-0034 D5 (unconditional, independent of the author-signing cert).
- [ ] Configure the federated OIDC trust between GitHub Actions and the Studios Key Vault for the signing-cert fetch (subscription / RBAC / federated credential — portal steps).
- [ ] The code-signing certificate itself is **not** a prerequisite for this packet — D5 explicitly publishes unsigned until the BDR-0001 Sunbiz amendment lands. Certificate procurement + Vault seeding is packet 04.

## Dependencies
- `packet:00` — ADR-0034 acceptance (soft — references ADR-0034 D6 as a live rule).
- `packet:01` — `catalogs/package-feeds.json` (**hard** — the workflow validates the `feed` input against this catalog's allowlist).

## Referenced ADR Decisions
**ADR-0034 D6 — Release workflow factoring.** Package publish lives in HoneyDrunk.Actions as a single reusable workflow `job-publish-nuget.yml`, called by every Node's release workflow. Inputs: `package-id`, `version`, `feed`. ADR-0034 D6 names the feeds informally as "nuget.org | github | azure-artifacts"; this packet binds the actual `feed` input to the `catalogs/package-feeds.json` feed-id keys (`nuget-org-public` | `github-packages-private` | `azure-artifacts-prerelease`) so validation is a direct catalog lookup. The workflow handles auth, sign, push, and post-publish verification (pulls the package by name+version and asserts metadata fields are populated). Existing Node release workflows are amended in a discrete follow-up rollout to call this workflow rather than running `dotnet nuget push` inline.

**ADR-0034 D5 — Package signing.** All published packages are author-signed with a code-signing certificate issued to "HoneyDrunk Studios". Per BDR-0001 the entity is mid-Sunbiz-amendment; signing-cert procurement waits on that amendment so the subject matches the legal entity name. Until then, packages publish **unsigned**. Repository signing (nuget.org server-side) is unconditionally enabled in parallel. The signing cert's private key lives in the Studios Key Vault; CI accesses it via federated OIDC, never as a stored secret. No long-lived signing PAT.

**ADR-0034 D1 — Primary feed.** nuget.org under `HoneyDrunkStudios` is the primary public feed; stable versions land on nuget.org and are never republished back. Azure Artifacts is the pre-release-only staging surface — `-preview.N` / `-rc.N` flow there first.

**ADR-0034 D2 — Private packages.** GitHub Packages under the org for private revenue Nodes; auth uses a federated GitHub Actions token, no long-lived PAT.

**ADR-0012** — CI mechanics live in the HoneyDrunk.Actions control plane via reusable workflows; consumers call them.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The nuget.org API key, the federated tokens, and the signing-certificate material must never be echoed into workflow logs. Only secret names/identifiers may be traced.

> **Invariant 9 — Vault is the only source of secrets.** The nuget.org API key resolves through the CI-surface Key Vault; the signing certificate resolves from the Studios Key Vault via federated OIDC. No hardcoded keys, no env-file secrets, no key on a developer laptop.

> **Invariant 31 — Every PR traverses the tier-1 gate before merge.** This is a release-family reusable workflow, not a PR check; it does not alter the tier-1 gate.

- **No `dotnet nuget push` in consumer repos.** The whole point of D6 — and the new invariant packet 00 adds — is that publish runs through this workflow. The workflow is the only place push happens.
- **Sign stage is conditional, not silently skipped.** When the cert is absent, log an explicit `Publishing UNSIGNED` line so the unsigned state is visible in every run until BDR-0001 lands.
- **`feed` is validated against the catalog.** An unknown or mistyped feed-id is a hard failure, never a default-to-something fallback.
- **No long-lived PAT** anywhere — nuget.org via Vault-stored API key, GitHub Packages and signing-cert via federated OIDC tokens.

## Labels
`ci`, `tier-2`, `ops`, `adr-0034`, `wave-2`

## Agent Handoff

**Objective:** Build `job-publish-nuget.yml` — the single reusable package-publish workflow. Parameterise on `package-id` / `version` / `feed`; handle auth, conditional signing, push, and post-publish metadata verification; validate `feed` against `catalogs/package-feeds.json`.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: One control-plane workflow for all package publishing; consumer release workflows stop calling `dotnet nuget push` directly (packet 05 amends them).
- Feature: ADR-0034 Public Package Distribution rollout, Wave 2.
- ADRs: ADR-0034 (D6 primary, D1/D2/D5), ADR-0012 (reusable-workflow factoring), ADR-0005 (Key Vault / federated OIDC), ADR-0006 (cert rotation lifecycle).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0034 acceptance (soft).
- `packet:01` — `catalogs/package-feeds.json` (hard — the `feed` input is validated against it).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- No `dotnet nuget push` in consumer repos; this workflow is the only place push happens.
- The sign stage is conditional but never silently skipped — log `Publishing UNSIGNED` when the cert is absent.
- `feed` is validated against the catalog; unknown feed-id is a hard failure.
- No long-lived PAT anywhere.

**Key Files:**
- `.github/workflows/job-publish-nuget.yml` (new)
- `docs/consumer-usage.md`
- `docs/CHANGELOG.md`
- `README.md`

**Contracts:** Consumes `catalogs/package-feeds.json` (read-only, from the architecture-repo checkout — ADR-0008 D8 checks out both repos) — the `feed` input is validated by exact `feed-id` match against this catalog. Defines the `job-publish-nuget.yml` `workflow_call` input contract (`package-id` / `version` / `feed`, where `feed` is one of `nuget-org-public` / `github-packages-private` / `azure-artifacts-prerelease`) and the caller-permissions contract (`id-token: write`, `packages: write` on `feed: github-packages-private`).
