---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "adr-0057", "adr-0034", "wave-4", "human-only"]
dependencies: ["work-item:00", "work-item:02", "work-item:04", "work-item:05"]
adrs: ["ADR-0057", "ADR-0034"]
wave: 4
initiative: adr-0057-api-versioning
node: honeydrunk-architecture
---

# Operator onboarding — npm @honeydrunk scope, Maven Central com.honeydrunkstudios namespace, GPG keys, Cloudflare API token

## Summary
Per ADR-0057 §Operational Consequences and the ADR-0034 cross-link, the per-registry credentials for SDK + docs publication require human portal work that cannot be agent-delegated. This packet is the operator's checklist for: (1) claiming the `@honeydrunk` npm scope; (2) verifying the `com.honeydrunkstudios` namespace at Maven Central via Central Portal; (3) generating + registering the GPG signing key for Maven artifacts; (4) confirming Swift Package Index integration (if a dedicated companion repo strategy is chosen) or git-tag-based discovery (if the SDK ships in a subdirectory of the per-API repo); (5) creating a Cloudflare API token for Pages deployment; (6) seeding all credentials as GitHub org-level secrets so the reusable workflows in packets 04 and 05 promote from dry-run to real-publish. This packet documents the work and tracks completion; the actual portal navigation is performed by the operator. `Actor=Human` — entirely portal + CLI work.

## Context
Packets 04 (`job-publish-public-sdk.yml`) and 05 (`job-publish-docs.yml`) ship in dry-run-by-default mode — they generate and validate but do not push to registries until per-registry credentials are seeded as org secrets. The seed step requires human portal work:

- **npm `@honeydrunk` scope** — npm scope claims happen via the npm web UI: account holder logs in, creates an Organization (or upgrades a User account to an Organization), claims the `@honeydrunk` scope as the organization namespace. Generates an automation token scoped to publishing under `@honeydrunk/*`. Token stored as `NPM_TOKEN` org secret in GitHub.
- **Maven Central `com.honeydrunkstudios` namespace** — Maven Central's new Central Portal (replaces OSSRH as of March 2024) requires namespace verification. Two paths: (a) DNS-based verification — add a TXT record `OSSRH-{verification-id}` to the `honeydrunkstudios.com` zone, request namespace via Central Portal, Sonatype verifies the DNS, namespace claimed; or (b) GitHub-org-based verification (`io.github.honeydrunkstudios`) which auto-verifies via repo ownership — but this gives the `io.github.honeydrunkstudios` namespace, not `com.honeydrunkstudios`, which doesn't match ADR-0057 D8's `com.honeydrunkstudios:{api}-sdk` commitment. Per ADR-0034 D3 (Proposed; the public-distribution policy that this packet's namespace work is the operator-time-budgeted component of), the canonical namespace is `com.honeydrunkstudios`; the DNS verification path is required.
- **GPG signing key** — Maven Central requires GPG-signed artifacts. The operator generates a GPG keypair (`gpg --gen-key`), uploads the public key to the standard keyservers (`gpg --keyserver keys.openpgp.org --send-keys {key-id}`), and stores the private key + passphrase as GitHub org secrets (`MAVEN_GPG_PRIVATE_KEY` + `MAVEN_GPG_PASSPHRASE`). The Maven publish step in packet 04's workflow uses these to sign before pushing to Central.
- **Maven Central credentials** — the Central Portal account credentials (username + token-style password generated via Central Portal) stored as `MAVEN_USERNAME` + `MAVEN_PASSWORD` org secrets.
- **Swift Package Index** — SPM is git-tag-based; no central registry credential is required. The choice is between: (a) ship the Swift SDK as a subdirectory of the per-API repo (e.g. `HoneyDrunk.Notify/swift/`) and push tags like `notify-swift-sdk-v1.0.0` — Swift Package Index discovers via git URL + tag; or (b) ship the Swift SDK in a dedicated companion repo (e.g. `HoneyDrunkStudios/HoneyDrunkNotifySdk`) and publish tags there. The dedicated-repo path is more idiomatic for consumers (`HoneyDrunkNotifySdk` is a cleaner Swift Package URL than a subdirectory reference). The decision is made at first-Swift-SDK-publication time. Either way, no portal credential is required — only git push rights. Swift Package Index registration is optional and indexes the repo via its public-discoverability; the per-repo `Package.swift` is the source of truth.
- **Cloudflare API token** — packet 05's `job-publish-docs.yml` deploys to Cloudflare Pages via the Cloudflare API. The operator creates a scoped API token (Account → API Tokens → Create Token → Custom token; scopes: Account.Cloudflare Pages: Edit, Account.Account Settings: Read, Zone.Zone: Read) and stores it as `CLOUDFLARE_API_TOKEN` org secret. Cloudflare Account ID stored as `CLOUDFLARE_ACCOUNT_ID` org secret.

The work is **fundamentally portal + CLI**: npm web UI; Maven Central Portal web UI; GPG CLI commands; Cloudflare dashboard. The agent has nothing to delegate to itself. `Actor=Human` with the `"human-only"` label per the user's convention.

The packet documents the work and tracks completion via the acceptance criteria checklist. The post-merge state is: every per-registry secret is seeded as a GitHub org-level secret accessible to the `HoneyDrunk.Actions` reusable workflows; the dry-run paths in packets 04 + 05 auto-promote to real-publish on the next workflow invocation.

The work is **operator-time-budgeted** — per the user's standing convention, no agent attempts the namespace verification or the credential seeding. The packet body is a checklist the operator works through over a session (Maven Central namespace verification typically takes 24-48 hours for Sonatype to process; npm scope claim is immediate; Cloudflare API token is immediate; GPG keygen is immediate).

## Scope
- npm `@honeydrunk` organization scope claimed and token issued.
- Maven Central `com.honeydrunkstudios` namespace verified.
- GPG keypair generated, public key uploaded to keyservers, private key + passphrase stored as org secrets.
- Maven Central account credentials stored as org secrets.
- Cloudflare API token scoped for Pages deployment, stored as org secret.
- Cloudflare Account ID stored as org secret.
- Swift Package Index strategy decided (subdirectory vs. companion repo) and documented.
- All credentials documented in `governance/sdk-registry-credentials.md` (or the equivalent existing file) — the metadata only, never the secret values themselves.
- `HoneyDrunk.Architecture/CHANGELOG.md` records the operator onboarding in a dated, versioned entry.

## Proposed Implementation
This packet is **Actor=Human** — the operator performs each step in the portal / CLI and records the outcome. The packet body is a checklist the operator follows.

1. **npm `@honeydrunk` scope:**
   - Log into npmjs.com with the HoneyDrunk Studios npm account.
   - Account settings → Organizations → Create an Organization. Name: `honeydrunk`. Plan: free tier sufficient (public packages only at v1).
   - The org's scope becomes `@honeydrunk`; subsequent published packages live at `@honeydrunk/{package-name}`.
   - Generate an automation token: Account → Access Tokens → Generate New Token → Automation. Scope: publish (read + publish). Copy the token (shown once).
   - Store the token as GitHub org-level secret `NPM_TOKEN` (Settings → Secrets and variables → Actions → New organization secret; visibility: Selected repositories — grant to `HoneyDrunkStudios/HoneyDrunk.Notify` and any future per-API repo that publishes SDKs).

2. **Maven Central `com.honeydrunkstudios` namespace verification:**
   - Log into central.sonatype.com (Maven Central Portal). Create an account if one doesn't exist; verify via email.
   - Namespaces → Add Namespace → enter `com.honeydrunkstudios`.
   - Choose verification method: **DNS-based** (required for the `com.*` namespace).
   - Central Portal displays a TXT record value. Add the record to the `honeydrunkstudios.com` Cloudflare DNS zone: TXT at `@` (apex), value as displayed.
   - Wait for Sonatype to verify (typically 24-48 hours; check status in Central Portal).
   - Once verified, the namespace is yours to publish under.
   - Generate Central Portal credentials: Account → Generate User Token. Username + token-style password. Copy both.
   - Store as GitHub org-level secrets: `MAVEN_USERNAME` (the displayed username — typically a UUID-style string), `MAVEN_PASSWORD` (the token).

3. **GPG signing key:**
   - On a secure local machine: `gpg --gen-key`. Choose RSA, 4096-bit, 2-year expiry. Real name: `HoneyDrunk Studios`. Email: `oleg@honeydrunkstudios.com` (or `support@honeydrunkstudios.com` if preferred). Set a passphrase; record it in 1Password / password manager.
   - List the key: `gpg --list-secret-keys --keyid-format=long`. Note the key ID (the long hex string after `sec rsa4096/`).
   - Upload public key: `gpg --keyserver keys.openpgp.org --send-keys {key-id}` and also `gpg --keyserver keyserver.ubuntu.com --send-keys {key-id}` (redundancy for keyserver availability).
   - Export private key for GitHub Actions: `gpg --armor --export-secret-keys {key-id}` (the output is the ASCII-armored private key block; copy it whole, including the `-----BEGIN PGP PRIVATE KEY BLOCK-----` and `-----END PGP PRIVATE KEY BLOCK-----` lines).
   - Store as GitHub org-level secret `MAVEN_GPG_PRIVATE_KEY` (paste the entire armored block).
   - Store the passphrase as GitHub org-level secret `MAVEN_GPG_PASSPHRASE`.

4. **Cloudflare API token:**
   - Log into the Cloudflare dashboard.
   - My Profile → API Tokens → Create Token → Custom token.
   - Token name: `HoneyDrunk Actions — Docs Pages Deploy`.
   - Permissions: Account → Cloudflare Pages: Edit; Account → Account Settings: Read; Zone → Zone: Read (only on the `honeydrunkstudios.com` zone if zone-scoping is desired).
   - Account resources: Include → HoneyDrunk Studios.
   - TTL: no expiry (or 1-year with calendar reminder).
   - Create the token; copy it (shown once).
   - Store as GitHub org-level secret `CLOUDFLARE_API_TOKEN`.
   - Note the Cloudflare Account ID (visible in the right sidebar of any Cloudflare dashboard page); store as GitHub org-level secret `CLOUDFLARE_ACCOUNT_ID`.

5. **Swift Package Index strategy decision:**
   - Decide: (a) subdirectory-in-per-API-repo (the Swift SDK ships at `HoneyDrunk.{Api}/swift/`; the per-API repo's `Package.swift` lives at that path; the SDK is referenced as `git@github.com:HoneyDrunkStudios/HoneyDrunk.{Api}.git`, path: `swift`), or (b) dedicated companion repo (a new repo `HoneyDrunkStudios/HoneyDrunk{Api}Sdk` per surface; `Package.swift` at the repo root; the SDK is referenced as `git@github.com:HoneyDrunkStudios/HoneyDrunk{Api}Sdk.git`).
   - The decision is made at first-Swift-SDK-publication time (likely when Notify's SDKs publish for real — re-run packet 08's `notify-api-v1.0.0` tag publication after this packet completes).
   - The default recommendation for v1: **subdirectory-in-per-API-repo** — avoids creating N companion repos; SPM consumers can reference a subdirectory via Swift Package Manager's path-based dependency syntax. The downside is the SDK repo URL is the per-API repo URL, which mixes the SDK with the per-API source; not idiomatic but workable at v1.
   - Document the chosen strategy in `governance/sdk-registry-credentials.md`.
   - No portal secret needed for SPM.

6. **Documentation — `governance/sdk-registry-credentials.md`** — create (or extend an existing equivalent) documenting the metadata of each registry / credential. **Never include the secret values themselves.** Required fields per registry:
   - **npm:** scope `@honeydrunk`; org account on npmjs.com; automation token stored as `NPM_TOKEN` org secret; visibility: per-repo grant.
   - **Maven Central:** namespace `com.honeydrunkstudios`; verification method DNS-based; verification status (verified on YYYY-MM-DD); Central Portal account; user-token credentials stored as `MAVEN_USERNAME` + `MAVEN_PASSWORD` org secrets; GPG key ID + expiry + uploaded keyservers.
   - **GPG:** key ID; uploaded keyservers; expiry date; passphrase stored as `MAVEN_GPG_PASSPHRASE`; private key stored as `MAVEN_GPG_PRIVATE_KEY`; renewal reminder cadence (annual review).
   - **Cloudflare:** API token scopes; token stored as `CLOUDFLARE_API_TOKEN`; Account ID stored as `CLOUDFLARE_ACCOUNT_ID`; TTL.
   - **Swift Package Index:** chosen strategy (subdirectory vs. companion repo); the rationale; the per-surface tag convention.
   - **Cross-references:** ADR-0057 D8 + D15, ADR-0034 D3, ADR-0029.

7. **`HoneyDrunk.Architecture/CHANGELOG.md`** — record the onboarding in a dated, versioned entry. Sample shape: `### Operator Onboarding — SDK Registries (2026-MM-DD)` listing the completed steps.

## Affected Files
- **GitHub org-level secrets** — seeded (not file-tracked).
- **External portal state** — npm org, Maven Central namespace + credentials, GPG keypair, Cloudflare token.
- `governance/sdk-registry-credentials.md` (new or appended-to)
- `HoneyDrunk.Architecture/CHANGELOG.md` (dated, versioned entry)

## NuGet Dependencies
None.

## Boundary Check
- [x] All file edits in `HoneyDrunk.Architecture`. Per the user's `project_repos_public_by_default` convention, the Architecture repo is public; the documentation file does NOT include any secret value, only metadata.
- [x] No code change in any other repo.
- [x] External portal state is correctly partitioned (npm, Maven Central, Cloudflare) — no overlap with Azure-side credentials.
- [x] The GPG private key, npm token, Maven credentials, Cloudflare token are stored ONLY as GitHub org-level secrets. They are NEVER committed to any repo.

## Acceptance Criteria
- [ ] `@honeydrunk` npm scope is claimed; `NPM_TOKEN` is seeded as a GitHub org-level secret with visibility to the per-API repos that will publish SDKs
- [ ] `com.honeydrunkstudios` Maven Central namespace is verified via DNS (TXT record on `honeydrunkstudios.com`); `MAVEN_USERNAME` + `MAVEN_PASSWORD` are seeded as org secrets
- [ ] GPG keypair generated, public key uploaded to `keys.openpgp.org` AND `keyserver.ubuntu.com`; `MAVEN_GPG_PRIVATE_KEY` and `MAVEN_GPG_PASSPHRASE` are seeded as org secrets
- [ ] Cloudflare API token (scoped: Account.Cloudflare Pages.Edit + Account.Account Settings.Read + Zone.Zone.Read) is created; `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` are seeded as org secrets
- [ ] Swift Package Index strategy is decided (subdirectory-in-per-API-repo recommended default) and documented
- [ ] `governance/sdk-registry-credentials.md` documents the metadata (NOT secret values) of all five registries / credential paths plus cross-references
- [ ] `HoneyDrunk.Architecture/CHANGELOG.md` records the onboarding in a dated, versioned entry
- [ ] **Post-onboarding verification:** re-run packet 08's `notify-api-v1.0.0` tag publication (`gh workflow run release-api.yml -R HoneyDrunkStudios/HoneyDrunk.Notify --ref notify-api-v1.0.0`) and confirm:
  - The `job-publish-public-sdk.yml` workflow promotes from dry-run to real-publish; `@honeydrunk/notify-sdk@1.0.0` lands on npmjs.com; `com.honeydrunkstudios:notify-sdk:1.0.0` lands on Maven Central; Swift SDK tag lands per the chosen strategy.
  - The `job-publish-docs.yml` workflow deploys to Cloudflare Pages and `docs.notify.honeydrunkstudios.com/v1/` serves the live docs.
  - This verification depends on packet 09 having completed (the Cloudflare Pages project must exist for the docs deploy). If packet 09 is incomplete at this packet's completion time, defer the verification until packet 09 lands; the SDK publication can succeed independently.
- [ ] No secret value is committed to any repo

## Human Prerequisites
- [ ] **Operator session of ~2-4 hours active time** — npm scope claim (10 min), Maven Central namespace verification request (30 min, then 24-48h wait), GPG keygen + upload (20 min), Cloudflare token (10 min), documentation (45 min), verification re-run (30 min). The 24-48h Maven Central wait dominates the elapsed time.
- [ ] **Access to:** the HoneyDrunk Studios npm account, the HoneyDrunk Studios Maven Central account (or create one), the `honeydrunkstudios.com` Cloudflare DNS zone (for the Maven Central TXT record), the HoneyDrunk Studios Cloudflare account, the HoneyDrunkStudios GitHub org admin for org-secret seeding.
- [ ] **1Password / password manager** for storing the GPG passphrase, the Maven Central credentials, and the npm token (each is shown once during creation; the org secret seeding is the only ongoing-access record).
- [ ] **Calendar reminder for GPG key expiry** (default 2 years; renewal is a 30-minute repeat of the keygen + upload + secret rotation).
- [ ] **This packet is `Actor=Human`** — agent cannot perform portal work. The operator follows the checklist and records outcomes.

## Referenced ADR Decisions
**ADR-0057 D8 — SDK languages + package coordinates.** `@honeydrunk/{api}-sdk` (npm), `HoneyDrunk{Api}Sdk` (SPM), `com.honeydrunkstudios:{api}-sdk` (Maven Central). The namespace claims here enable real publication.

**ADR-0057 D15 — Docs hosting.** Cloudflare Pages target; the API token here enables `job-publish-docs.yml` to deploy.

**ADR-0057 §Operational Consequences — Maven Central onboarding is the highest one-time cost.** "Namespace verification, GPG key registration, OSSRH (now Central Portal) onboarding. Done once for `com.honeydrunkstudios`; reused for all future Kotlin SDKs."

**ADR-0034 D3 (referenced) — Public package distribution.** Namespace / metadata fields required. The namespace verification here is the operational implementation of ADR-0034 D3's commitment.

**ADR-0029 (referenced) — Cloudflare DNS.** The TXT record for Maven Central namespace verification lives in the Cloudflare-managed `honeydrunkstudios.com` zone.

## Constraints
- **`Actor=Human` with `human-only` label** — portal + CLI work; not agent-delegable.
- **Secret values NEVER committed.** Only metadata in `governance/sdk-registry-credentials.md`. The Architecture repo is public per the user's standing convention.
- **GPG private key ASCII-armored** for org-secret storage; not raw binary.
- **Maven Central via Central Portal**, not legacy OSSRH (OSSRH retired for new namespaces post-March 2024).
- **Cloudflare API token scoped narrowly** — Cloudflare Pages Edit + minimal Read for token-validation. Not Account Admin.
- **Visibility on org secrets: per-repo grant**, not org-wide-all-repos. Each per-API repo that publishes SDKs is granted explicitly.
- **Swift Package Index strategy decided at first-Swift-SDK time**, documented post-decision; default recommendation subdirectory-in-per-API-repo.
- **Post-onboarding verification couples with packets 08 + 09** — the re-run of Notify's publication completes the loop and confirms the credentials work end-to-end.
- **No `Unreleased` CHANGELOG.**

## Labels
`chore`, `tier-3`, `ops`, `adr-0057`, `adr-0034`, `wave-4`, `human-only`

## Agent Handoff

**Objective:** Complete the operator-time-budgeted external onboarding so the SDK + docs publication pipelines (packets 04 + 05) promote from dry-run to real-publish. Specifically: npm `@honeydrunk` scope, Maven Central `com.honeydrunkstudios` namespace verification, GPG keypair + upload, Cloudflare API token; all credentials seeded as GitHub org-level secrets; metadata documented (never secret values).

**Target:** `HoneyDrunk.Architecture` for the documentation commit; external portals (npm, Maven Central, GPG keyservers, Cloudflare) for the actual onboarding.

**Context:**
- Goal: Unblock real SDK + docs publication. Until this packet completes, packets 04 + 05 run in dry-run; packet 08 ships in dry-run; packet 10's deferred spec calls out the same dependency.
- Feature: ADR-0057 rollout, Wave 4 (operator-time-budgeted external onboarding).
- ADRs: ADR-0057 D8 / D15 / §Operational Consequences (primary); ADR-0034 D3 (NuGet/namespace policy); ADR-0029 (Cloudflare DNS for the Maven Central TXT record).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0057 Accepted.
- `work-item:02` — provisioning playbook authored (cross-referenced for Cloudflare).
- `work-item:04` — SDK publication workflow shipped (this packet seeds its credentials).
- `work-item:05` — docs publication workflow shipped (this packet seeds its credential).

**Constraints:**
- `Actor=Human`.
- Secret values never committed.
- GPG ASCII-armored.
- Maven Central via Central Portal.
- Cloudflare API token narrowly scoped.
- Per-repo grant on org secrets.
- Swift Package Index decision deferred to first-publish; default recommendation subdirectory.
- No `Unreleased` CHANGELOG.

**Key Files:**
- `governance/sdk-registry-credentials.md` (new or appended-to)
- `HoneyDrunk.Architecture/CHANGELOG.md`
- GitHub org-level secrets (not file-tracked)
- External portal state (not file-tracked)

**Contracts:** None.
