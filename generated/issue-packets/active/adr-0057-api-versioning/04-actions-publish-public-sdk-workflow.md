---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-1", "core", "adr-0057", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0057"]
wave: 2
initiative: adr-0057-api-versioning
node: honeydrunk-actions
---

# Author job-publish-public-sdk.yml — reusable SDK generation and publication for TS, Swift, Kotlin

## Summary
Author the reusable workflow `job-publish-public-sdk.yml` in `HoneyDrunk.Actions/.github/workflows/` that, on a per-API tag matching `{api}-api-v{N}.{spec-revision}.{sdk-patch}`, generates SDKs for TypeScript / Swift / Kotlin from the surface's OpenAPI 3.1 spec using OpenAPI Generator, applies Studios-maintained override templates from `HoneyDrunk.Actions/openapi-templates/{language}/`, and publishes each SDK to its registry (npm, Swift Package Index / SPM, Maven Central). The workflow is parameterized per language so callers can enable / disable per-language publication independently. Seed the override templates with minimal-but-functional overrides for each language (idiomatic naming, ergonomic builders, lenient enum deserialization per ADR-0057 D4, default `User-Agent` per the ADR's footnote, auto-`Idempotency-Key` per D13). Per ADR-0057 §Operational Consequences, namespace onboarding (npm `@honeydrunk`, Maven Central `com.honeydrunkstudios`, GPG keys) is operator-time-budgeted — packet 11 carries that checklist; this workflow runs in dry-run mode until those credentials are seeded as repo / org secrets.

## Context
ADR-0057 D8 commits the three SDK languages (TypeScript, Swift, Kotlin), the per-language package coordinates (`@honeydrunk/{api}-sdk`, `HoneyDrunk{Api}Sdk`, `com.honeydrunkstudios:{api}-sdk`), the tooling (OpenAPI Generator with Studios-maintained overrides), and the publication automation pattern (per-API repo invokes a reusable workflow on tag). ADR-0057 D9 commits the version scheme (`v{API-major}.{spec-revision}.{sdk-patch}`). ADR-0057 D13 commits auto-generated `Idempotency-Key` per write request as a default. ADR-0057 §footnote-style decision near the bottom of "Alternatives Considered" commits the `User-Agent` default of `honeydrunk-{api}-sdk-{lang}/{sdk-version}`.

The Studios-maintained override templates are the lever that turns generic OpenAPI Generator output into idiomatic per-language SDKs. The defaults are workable for v1; the overrides land minimal-but-functional now and are tuned over time as concrete tenant feedback arrives. Per ADR-0057 D8: *"Default OpenAPI Generator templates are acceptable v1 starting points; where defaults are insufficient (idiomatic naming, ergonomic builders, lenient enum deserialization per D4, default `User-Agent`, auto-`Idempotency-Key` per D13), Studios maintains override templates in `HoneyDrunk.Actions/openapi-templates/{language}/`."*

**Namespace onboarding deferred to operator.** Per ADR-0057 §Operational Consequences and the ADR-0034 cross-link, the per-registry credentials require human portal work: npm `@honeydrunk` scope ownership, Maven Central `com.honeydrunkstudios` namespace verification + GPG key registration via Central Portal (formerly OSSRH), Swift Package Index registration. This packet's workflow runs in **dry-run mode** when credentials are absent — it generates and validates the SDKs but does not push to registries. The operator completes the onboarding per packet 11 and seeds the secrets; subsequent tag pushes publish for real.

ADR-0057 D8 also commits the publication-step sequence: (1) validate the spec, (2) run the breaking-change diff (`job-openapi-diff.yml` — packet 03), (3) generate SDKs for all three languages, (4) publish each SDK to its registry with the version per D9, (5) regenerate the docs site (`job-publish-docs.yml` — packet 05). This packet ships step (3) + (4) — the SDK generation and publication. Steps (1), (2), (5) ship in adjacent packets and are composed at the per-API caller site (Notify's tag-publication caller workflow chains the steps).

This is the second Actions packet; depends on the same foundation as packet 03 but is independent of it at execution time (the two workflows can be authored in parallel).

## Scope
- **New file:** `HoneyDrunk.Actions/.github/workflows/job-publish-public-sdk.yml` — the reusable workflow with per-language enable/disable inputs.
- **New directory:** `HoneyDrunk.Actions/openapi-templates/typescript/` — Studios-maintained override templates for TypeScript SDK generation.
- **New directory:** `HoneyDrunk.Actions/openapi-templates/swift/` — overrides for Swift.
- **New directory:** `HoneyDrunk.Actions/openapi-templates/kotlin/` — overrides for Kotlin.
- **New file:** `HoneyDrunk.Actions/docs/job-publish-public-sdk.md` — consumer documentation.
- Repo-level `CHANGELOG.md` entry.
- `HoneyDrunk.Actions/README.md` — workflow catalog link.

## Proposed Implementation

1. **`HoneyDrunk.Actions/.github/workflows/job-publish-public-sdk.yml`** — `workflow_call` reusable workflow. Inputs:
   ```yaml
   inputs:
     spec-path:
       description: 'Path to the OpenAPI spec.'
       type: string
       required: true
     surface-name:
       description: 'API surface name (e.g. notify, web-rest).'
       type: string
       required: true
     api-major:
       description: 'Major version of the API (e.g. 1 for v1).'
       type: number
       required: true
     spec-revision:
       description: 'Spec revision number per D9 versioning.'
       type: number
       required: true
     sdk-patch:
       description: 'SDK patch number per D9 versioning.'
       type: number
       required: true
     publish-typescript:
       description: 'Enable TypeScript SDK generation and npm publication.'
       type: boolean
       required: false
       default: true
     publish-swift:
       description: 'Enable Swift SDK generation and SPM publication.'
       type: boolean
       required: false
       default: true
     publish-kotlin:
       description: 'Enable Kotlin SDK generation and Maven Central publication.'
       type: boolean
       required: false
       default: true
     dry-run:
       description: 'If true, generate and validate but do not publish to registries.'
       type: boolean
       required: false
       default: false
     openapi-generator-version:
       description: 'OpenAPI Generator version; pinned for determinism.'
       type: string
       required: false
       default: '7.10.0'  # confirm latest stable at execution time
   secrets:
     NPM_TOKEN:
       required: false
     MAVEN_USERNAME:
       required: false
     MAVEN_PASSWORD:
       required: false
     MAVEN_GPG_PRIVATE_KEY:
       required: false
     MAVEN_GPG_PASSPHRASE:
       required: false
     # Swift Package Index uses git tags as the release signal; no per-registry secret is required for SPM if the tag push happens on a HoneyDrunk-owned GitHub repo (the SDK lives in the same per-API repo's swift subfolder, or in a dedicated companion repo — confirm at first-Swift-SDK-publication time).
   ```
   Steps (in order):
   - **Checkout** with `fetch-depth: 0`.
   - **Validate the spec.** Use `openapi-generator-cli validate -i ${{ inputs.spec-path }}` or `npx @apidevtools/swagger-cli validate`.
   - **Compute the SDK version.** `SDK_VERSION = "${{ inputs.api-major }}.${{ inputs.spec-revision }}.${{ inputs.sdk-patch }}"` per ADR-0057 D9.
   - **Conditional per-language jobs.** Three matrix branches or three sequential conditional blocks, gated on the per-language `publish-*` input.
   - **TypeScript branch (when `publish-typescript: true`):**
     - Install Node and `@openapitools/openapi-generator-cli@${{ inputs.openapi-generator-version }}`.
     - Generate: `openapi-generator-cli generate -g typescript-fetch -i ${{ inputs.spec-path }} -o /tmp/sdk-ts -c openapi-templates/typescript/config.json -t openapi-templates/typescript/templates`. Set the package name to `@honeydrunk/${{ inputs.surface-name }}-sdk` via config.
     - Run `npm test` against the generated SDK (the override templates include a minimal test that asserts the package compiles and the basic shape is correct).
     - If `dry-run: true` OR `NPM_TOKEN` is unset: log "DRY-RUN: skipping npm publish" and skip the publish step.
     - Otherwise: `npm publish --access public` with the `NPM_TOKEN` env var.
   - **Swift branch (when `publish-swift: true`):**
     - Install OpenAPI Generator (same as TypeScript).
     - Generate: `openapi-generator-cli generate -g swift5 -i ${{ inputs.spec-path }} -o /tmp/sdk-swift -c openapi-templates/swift/config.json -t openapi-templates/swift/templates`. Package name `HoneyDrunk${{ inputs.surface-name | titlecase }}Sdk`.
     - Run `swift build` (if a macOS runner is available; otherwise rely on cross-platform Swift toolchain on Linux runners — the Swift Foundation port supports Linux).
     - If `dry-run: true`: log "DRY-RUN: skipping SPM tag push" and skip. Otherwise: commit the generated SDK to the per-API repo's `swift/` subdirectory (or to a dedicated companion repo per the first-Swift-SDK-publication-time decision); push a git tag `swift-sdk-v{SDK_VERSION}`; Swift Package Index discovers the tag and updates the package. Document the chosen repo strategy in the `docs/job-publish-public-sdk.md`.
   - **Kotlin branch (when `publish-kotlin: true`):**
     - Install OpenAPI Generator.
     - Generate: `openapi-generator-cli generate -g kotlin -i ${{ inputs.spec-path }} -o /tmp/sdk-kotlin -c openapi-templates/kotlin/config.json -t openapi-templates/kotlin/templates`. Group `com.honeydrunkstudios`; artifact `${{ inputs.surface-name }}-sdk`; version `${SDK_VERSION}`.
     - Run `./gradlew build`.
     - If `dry-run: true` OR `MAVEN_USERNAME` / `MAVEN_PASSWORD` / `MAVEN_GPG_PRIVATE_KEY` / `MAVEN_GPG_PASSPHRASE` is unset: log "DRY-RUN: skipping Maven Central publish" and skip.
     - Otherwise: configure the Gradle Maven publish plugin with the secrets, sign the artifact with GPG, push to Central Portal staging, promote to release. Note: Maven Central's Central Portal (new) vs. OSSRH (legacy) onboarding distinction — confirm at packet 11 onboarding time which one is current.
   - **PR / tag summary comment** — when invoked from a tag push, summarize the three SDK publication outcomes in a workflow summary (`$GITHUB_STEP_SUMMARY`). For dry-run, summarize "generated but not published" outcomes.

2. **`HoneyDrunk.Actions/openapi-templates/typescript/`** — seed minimal-but-functional override templates:
   - `config.json` — OpenAPI Generator config: `npmName=@honeydrunk/{api}-sdk` (templated via the workflow's `surface-name` input), `typescriptThreePlus=true`, `enumPropertyNaming=UPPERCASE`, `supportsES6=true`, `withInterfaces=true`, `useSingleRequestParameter=true`.
   - `templates/` — minimal Mustache overrides for:
     - **Lenient enum deserialization** (ADR-0057 D4 — "Clients MUST ignore unknown enum values"). Override the `modelEnum.mustache` to wrap the parsed value in an `Unknown` fallback rather than throwing.
     - **Default `User-Agent` header injection** (ADR-0057 footnote — `honeydrunk-{api}-sdk-typescript/{sdk-version}`). Override the `apiInner.mustache` request-execution shim to inject the header on every request.
     - **Auto-`Idempotency-Key` for write requests** (ADR-0057 D13). Override the request-shim to detect POST / PUT / PATCH; if `Idempotency-Key` is not already set, generate a UUID v7 (use `uuid` npm package or hand-roll a small v7 generator) and inject it. Tenant code can override per-call.
     - A minimal `README.md.mustache` per the template that the generated SDK ships with — installation, quickstart, links back to `docs.{api}.honeydrunkstudios.com`.

3. **`HoneyDrunk.Actions/openapi-templates/swift/`** — seed analogous overrides:
   - `config.json` — `projectName=HoneyDrunk{Api}Sdk`, `swiftPackagePath=HoneyDrunk{Api}Sdk`, `useClasses=false` (prefer structs), `responseAs=AsyncAwait` (Swift 5.5+ async/await default).
   - `templates/` — lenient enum (Swift `enum` with `case unknown(String)` fallback), `User-Agent` injection in the URLRequest builder, auto-`Idempotency-Key` for `httpMethod in ["POST", "PUT", "PATCH"]`, minimal README.
   - The Swift Package Index requires a `Package.swift` at the repo root; the generated SDK ships its own `Package.swift` per the OpenAPI Generator Swift template.

4. **`HoneyDrunk.Actions/openapi-templates/kotlin/`** — seed analogous overrides:
   - `config.json` — `library=jvm-okhttp4` (or `jvm-ktor` — confirm which is more idiomatic for Android consumers at first-Kotlin-SDK-publication time), `serializationLibrary=kotlinx_serialization`, `groupId=com.honeydrunkstudios`, `artifactId={api}-sdk` (templated), `enumPropertyNaming=UPPERCASE`.
   - `templates/` — lenient enum (Kotlin sealed class with `Unknown(val raw: String)` fallback), `User-Agent` interceptor on the OkHttp client, `Idempotency-Key` interceptor for POST / PUT / PATCH, minimal README + `build.gradle.kts` template.

5. **`HoneyDrunk.Actions/docs/job-publish-public-sdk.md`** — consumer documentation:
   - **Purpose.** Generate and publish per-language SDKs for a public API surface per ADR-0057 D8 + D9.
   - **Tag-driven invocation** — the canonical caller is a per-API repo's tag-push workflow:
     ```yaml
     on:
       push:
         tags:
           - 'notify-api-v*'
     jobs:
       publish:
         uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-publish-public-sdk.yml@main
         with:
           spec-path: HoneyDrunk.Notify/api/openapi-v1.yaml
           surface-name: notify
           api-major: 1
           spec-revision: 0
           sdk-patch: 0
         secrets:
           NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
           MAVEN_USERNAME: ${{ secrets.MAVEN_USERNAME }}
           MAVEN_PASSWORD: ${{ secrets.MAVEN_PASSWORD }}
           MAVEN_GPG_PRIVATE_KEY: ${{ secrets.MAVEN_GPG_PRIVATE_KEY }}
           MAVEN_GPG_PASSPHRASE: ${{ secrets.MAVEN_GPG_PASSPHRASE }}
     ```
   - **Dry-run mode.** When `dry-run: true` (or when the per-registry secrets are absent), the workflow generates and validates the SDKs but does not push to registries. Use this until packet 11's operator onboarding completes.
   - **Per-language enable/disable.** Set `publish-typescript: false` (etc.) to skip a language for a specific tag.
   - **Override templates.** Document the structure of `openapi-templates/{language}/` and what overriding a Mustache template does (it replaces the default OpenAPI Generator template for that file).
   - **SDK version scheme.** Per ADR-0057 D9 — recap with examples.
   - **Multi-major coexistence.** When v2 ships, the v1 SDK line stays available on the registries; this workflow only publishes the version matching the tag.

6. **`HoneyDrunk.Actions/CHANGELOG.md`** — dated, versioned entry.

7. **`HoneyDrunk.Actions/README.md`** — workflow catalog link.

## Affected Files
- `HoneyDrunk.Actions/.github/workflows/job-publish-public-sdk.yml` (new)
- `HoneyDrunk.Actions/openapi-templates/typescript/` (new directory + config + Mustache overrides)
- `HoneyDrunk.Actions/openapi-templates/swift/` (new directory + config + Mustache overrides)
- `HoneyDrunk.Actions/openapi-templates/kotlin/` (new directory + config + Mustache overrides)
- `HoneyDrunk.Actions/docs/job-publish-public-sdk.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

## NuGet Dependencies
None. GitHub Actions YAML + Mustache templates.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Per ADR-0012, reusable workflows and CI templates live here.
- [x] No code change in any other repo.
- [x] No new abstraction or contract.
- [x] No HoneyDrunk package dependency.

## Acceptance Criteria
- [ ] `HoneyDrunk.Actions/.github/workflows/job-publish-public-sdk.yml` exists with the documented inputs and per-language conditional branches
- [ ] The workflow validates the spec, computes the SDK version per D9, and generates SDKs for the three languages using OpenAPI Generator with the override templates
- [ ] When `dry-run: true` OR per-registry secrets are absent, the workflow generates and validates but does not publish — and logs the dry-run reason clearly
- [ ] When secrets are seeded and `dry-run: false`, the workflow publishes: npm (`@honeydrunk/{surface}-sdk`), Maven Central (`com.honeydrunkstudios:{surface}-sdk`), Swift (git tag push for Swift Package Index discovery)
- [ ] `HoneyDrunk.Actions/openapi-templates/typescript/` ships `config.json` and Mustache overrides for: lenient enum deserialization, default `User-Agent` header (`honeydrunk-{api}-sdk-typescript/{sdk-version}`), auto-`Idempotency-Key` on POST/PUT/PATCH, README template
- [ ] `HoneyDrunk.Actions/openapi-templates/swift/` ships `config.json` and Mustache overrides for: lenient enum, `User-Agent`, auto-`Idempotency-Key`, README template
- [ ] `HoneyDrunk.Actions/openapi-templates/kotlin/` ships `config.json` and Mustache overrides for: lenient enum (sealed class), OkHttp interceptors for `User-Agent` and `Idempotency-Key`, README template
- [ ] `HoneyDrunk.Actions/docs/job-publish-public-sdk.md` documents the invocation contract, dry-run mode, per-language enable/disable, override template structure, version scheme, and multi-major coexistence note
- [ ] `HoneyDrunk.Actions/CHANGELOG.md` records the addition in a dated, versioned section
- [ ] `HoneyDrunk.Actions/README.md` links to the new job docs
- [ ] OpenAPI Generator version is pinned (no `latest`)
- [ ] No consuming repo is wired here — Notify's tag-publication caller workflow lands in packet 08; Web.Rest's lands in packet 07

## Human Prerequisites
- [ ] **Confirm the OpenAPI Generator version pin** before merging (`7.10.0` is a placeholder; confirm latest stable).
- [ ] **The workflow runs in dry-run mode until packet 11's operator onboarding completes.** When `NPM_TOKEN` / `MAVEN_USERNAME` / `MAVEN_PASSWORD` / `MAVEN_GPG_PRIVATE_KEY` / `MAVEN_GPG_PASSPHRASE` are seeded as repo or org secrets (per packet 11), the workflow auto-promotes from dry-run to real-publish for the first SDK tag push. The Swift Package Index pathway is git-tag-based and does not require a registry secret, but the Swift SDK companion-repo strategy (subdirectory of the per-API repo vs. dedicated `HoneyDrunk{Api}Sdk` Swift repo) is decided at first-Swift-SDK-publication time — operator decision required at that point.
- [ ] **Decide Kotlin `library` choice** at first-Kotlin-SDK-publication time — `jvm-okhttp4` is the default in this packet; `jvm-ktor` is the alternative. The choice depends on Android consumer ergonomics; the override templates assume OkHttp throughout. State the choice in the per-API caller's tag workflow.
- [ ] **Maven Central Portal vs. OSSRH** — confirm which onboarding path is current at packet 11 onboarding time and update this workflow's Maven publish step accordingly. Central Portal is the new path (post-March 2024); OSSRH is the legacy.

## Referenced ADR Decisions
**ADR-0057 D8 — Three SDK languages at v1.** TypeScript (`@honeydrunk/{api}-sdk` on npm), Swift (`HoneyDrunk{Api}Sdk` SPM), Kotlin (`com.honeydrunkstudios:{api}-sdk` on Maven Central). Tooling: OpenAPI Generator with Studios-maintained overrides in `HoneyDrunk.Actions/openapi-templates/{language}/`. Publication automation: per-API tag triggers the reusable workflow. C# / Python / Go / Ruby / PHP deferred — generate on request.

**ADR-0057 D9 — SDK version scheme.** `SDK version = v{API-major}.{spec-revision}.{sdk-patch}`. Both major SDK lines stay published indefinitely (deprecated in the registry post-sunset; never unpublished — unpublish breaks frozen consumer builds).

**ADR-0057 D4 — Lenient enum deserialization client-side contract.** "New enum value is not breaking, conditional on the documented client-side rule: clients MUST ignore unknown enum values, treating them as unrecognized." The generated SDK's deserialization is lenient on unknown enum values by default — override templates implement this per language.

**ADR-0057 D13 — Idempotency on writes.** "SDK implementations (D8) auto-generate an `Idempotency-Key` (a UUID v7) for every write request by default; the SDK consumer can override per-call." Override templates implement this via per-language request interceptors / shims.

**ADR-0057 footnote (User-Agent).** "Generated SDKs (D8) set a `User-Agent` of the form `honeydrunk-{api}-sdk-{lang}/{sdk-version}` by default; tenants can override per request. Not a hard requirement (no enforcement on the header's presence), but the SDK default ensures coverage for the population that uses generated SDKs."

**ADR-0034 (referenced) — NuGet policy and namespace ownership.** Namespace verification for npm `@honeydrunk` scope, Maven Central `com.honeydrunkstudios`, and GPG key registration are the operator-time-budgeted steps cross-referenced in packet 11.

**ADR-0012 (referenced) — Actions as CI/CD control plane.**

## Constraints
- **Dry-run is the default safe path until packet 11.** The workflow does not push to registries until per-registry secrets are seeded. The dry-run logs are loud and unambiguous about *why* they did not publish.
- **OpenAPI Generator version pinned.** No `latest`.
- **Studios-maintained overrides are minimal in this packet.** They land enough to enforce the four contract decisions (lenient enum, User-Agent, Idempotency-Key, README); deeper ergonomic tuning is evidence-driven and lands in follow-up packets per ADR-0057 §Operational Consequences ("hand-tuned wrapper layers are an evidence-driven escalation, not v1 default").
- **Three languages only.** ADR-0057 D8 explicitly defers C# / Python / Go / Ruby / PHP. This workflow does not pre-emptively wire them.
- **Per-language enable/disable.** Each language is independently togglable so a partial onboarding (e.g., npm credentials ready, Maven not) can publish what's ready.
- **No `Unreleased` CHANGELOG.**

## Labels
`feature`, `tier-1`, `core`, `adr-0057`, `wave-2`

## Agent Handoff

**Objective:** Ship the reusable `job-publish-public-sdk.yml` workflow that generates and publishes SDKs for TypeScript / Swift / Kotlin on per-API tag pushes, with Studios-maintained OpenAPI Generator override templates that enforce the four SDK contract decisions (lenient enum, default `User-Agent`, auto-`Idempotency-Key`, README convention). Run in dry-run mode until packet 11's operator onboarding seeds the per-registry credentials.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make SDK publication a single tag push on the per-API repo. Per ADR-0057 D8, hand-writing SDKs per language per API is not viable at solo-operator scale; this workflow centralizes the generation, credentials, and publication path.
- Feature: ADR-0057 rollout, Wave 2 (Actions substrate).
- ADRs: ADR-0057 D8 / D9 / D13 / D4 / footnote-User-Agent (primary); ADR-0034 (namespace onboarding deferred to operator); ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0057 Accepted.
- `packet:01` — tech-stack.md commits OpenAPI Generator as the tool.

**Constraints:**
- Dry-run until packet 11 seeds credentials.
- Pinned OpenAPI Generator version.
- Three languages only.
- Override templates are minimal-but-functional in this packet.
- Per-language enable/disable.
- No `Unreleased` CHANGELOG.

**Key Files:**
- `HoneyDrunk.Actions/.github/workflows/job-publish-public-sdk.yml` (new)
- `HoneyDrunk.Actions/openapi-templates/typescript/`, `swift/`, `kotlin/` (new directories)
- `HoneyDrunk.Actions/docs/job-publish-public-sdk.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

**Contracts:** None — reusable workflow + override-template assets only.
