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

# Author job-openapi-diff.yml — the breaking-change CI gate per ADR-0057 D7

## Summary
Author the reusable workflow `job-openapi-diff.yml` in `HoneyDrunk.Actions/.github/workflows/` that runs `oasdiff` (or equivalent) on every PR that modifies an `openapi-v*.yaml`, classifies the diff against ADR-0057 D4's breaking-change taxonomy, and **fails the build** when a diff classified as breaking lands on a *released* spec. PRs against a not-yet-released (unreleased major) spec pass the gate even when the diff is breaking — the unreleased spec is, by definition, not yet committed. This is the load-bearing enforcement that makes invariant `{N2}` ("breaking changes require a major version bump") enforceable rather than aspirational.

## Context
ADR-0057 D7 commits the breaking-change CI gate: *"Every PR that modifies an `openapi-v*.yaml` runs an OpenAPI diff (tooling: `oasdiff` or equivalent) against the last released spec. A diff classified as 'breaking' per D4's taxonomy fails the build unless the spec being modified is for a new (unreleased) major version."* The gate is invariant-load-bearing — without it, the D4 taxonomy and invariant `{N2}` are operator-honor-system enforcement, which is exactly the failure mode ADR-0057 is designed to prevent.

`oasdiff` (https://github.com/Tufin/oasdiff) is the most mature open-source OpenAPI 3.0/3.1 diff tool. It classifies changes into `BREAKING` / `INFO` / `WARNING` categories, supports YAML/JSON specs, ships as a single Go binary, and has a deterministic CLI. It is the default tool choice per ADR-0057 D7's "or equivalent" — pin the concrete version in this workflow so reviewers and packet authors do not re-litigate the choice per surface.

The "last released spec" question is non-trivial. ADR-0057 D9 commits SDK version coordinates that include the spec revision; the *released* spec is the spec at the most recent `{api}-api-v{N}.{spec-revision}.{sdk-patch}` git tag (per D8's tag convention). The workflow needs to resolve the last released spec for a given spec file in a given repo. Two strategies:

- **Tag-anchored** — the workflow checks out the latest tag matching `{api}-api-v{N}.*` for the same major as the spec under change, extracts the spec file at that tag, runs `oasdiff` between the tagged version and the PR head version. This is the canonical approach per D8's tag scheme.
- **Branch-anchored** — the workflow checks out the spec file from the latest commit on `main` and runs `oasdiff` between that and the PR head. Simpler but doesn't capture the "released" semantics — a PR that lands `oasdiff`-breaking changes to `main` and then a follow-up PR that adds more breaking changes would not catch the cumulative break because each PR's diff vs. `main` would be small.

The tag-anchored approach is correct per D8; the workflow ships with the tag-anchored mode as the default. The branch-anchored mode is available as a secondary input for surfaces that have not yet shipped their first tag (Web.Rest at v1 freeze time per packet 07 — the spec is being reverse-engineered and there is no prior tag).

ADR-0057 D4 lists the breaking-change categories: removed endpoint, removed response field, renamed field, type narrowing, semantic change, removed enum value, added required request field, changed error code mapping, changed authentication requirement, changed rate-limit envelope, changed pagination scheme. `oasdiff` covers most of these directly via its built-in breaking-change classification; a few (semantic change, changed error code mapping in *meaning*) are not detectable by `oasdiff` alone and require human-reviewer attention — `oasdiff` flags the structural diff and the human review confirms the semantic interpretation. The workflow surfaces this on the PR comment.

`HoneyDrunk.Actions` is the central CI/CD control plane (per ADR-0012). Reusable workflows live in `.github/workflows/job-*.yml` and are invoked from consuming repos via `uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml@v1` (or `@main` per the user's standing convention; the version-pin convention per HoneyDrunk.Actions is documented separately).

This is the **first of four Actions packets** in this initiative — the breaking-change gate is independent of the other three (publication, docs, GraphQL) and is the highest-value substrate piece because it gates every spec change going forward.

## Scope
- **New file:** `HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml` — the reusable workflow.
- **New file:** `HoneyDrunk.Actions/docs/job-openapi-diff.md` (or extend an existing job-docs file) — the consumer documentation: how a per-API repo invokes the workflow, expected inputs, gate semantics.
- Repo-level `CHANGELOG.md` entry for the new workflow.
- `HoneyDrunk.Actions/README.md` — link to the new job docs from the workflow catalog section.

## Proposed Implementation

1. **`HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml`** — a reusable workflow with `on: workflow_call:`. Inputs (with defaults that match the common case):
   ```yaml
   inputs:
     spec-path:
       description: 'Path to the OpenAPI spec under change (e.g. api/openapi-v1.yaml).'
       type: string
       required: true
     surface-name:
       description: 'API surface name for tag resolution (e.g. notify, web-rest, honeyhub).'
       type: string
       required: true
     diff-mode:
       description: 'tag (compare against latest released tag) or branch (compare against main).'
       type: string
       required: false
       default: 'tag'
     is-unreleased-major:
       description: 'If true, breaking diffs are allowed (the spec is for a not-yet-released major).'
       type: boolean
       required: false
       default: false
     oasdiff-version:
       description: 'oasdiff version to use; pinned for determinism.'
       type: string
       required: false
       default: 'v1.10.18'  # confirm the latest stable at execution time; pin a concrete release tag
   ```
   Steps:
   - **Checkout PR head.** `actions/checkout@v4` with `fetch-depth: 0` (needed for the tag-resolution branch below).
   - **Install oasdiff.** Pin the version via the input; install the single Go binary directly (`curl -L https://github.com/Tufin/oasdiff/releases/download/${{ inputs.oasdiff-version }}/oasdiff_linux_amd64.tar.gz | tar xz` — or the official install script). Add to `PATH`.
   - **Resolve the comparison base.**
     - If `diff-mode = tag`: extract the major from `spec-path` (regex on the filename `openapi-v(\d+)\.yaml`); list tags matching `{surface-name}-api-v{major}.*`; pick the highest semver-sorted tag; check out that tag's `spec-path` into `/tmp/base-spec.yaml`. If no tag exists yet (first release), fall back to branch mode with a workflow warning ("no released tag yet — comparing against main").
     - If `diff-mode = branch`: check out `main`'s `spec-path` into `/tmp/base-spec.yaml`. If `main` does not have the file yet, the PR is introducing the spec for the first time — emit a workflow info ("first introduction of spec — no diff to check") and exit 0.
   - **Run oasdiff.** `oasdiff diff /tmp/base-spec.yaml ${{ inputs.spec-path }} --format json > /tmp/diff.json` and `oasdiff breaking /tmp/base-spec.yaml ${{ inputs.spec-path }} --format json > /tmp/breaking.json` (the second invocation is the breaking-change classifier).
   - **Classify and gate.** Parse `/tmp/breaking.json`; if the breaking-change list is empty, the gate passes (emit a PR comment summarizing the diff with the non-breaking changes). If the list is non-empty:
     - If `is-unreleased-major = true`, the gate passes with a PR comment indicating "breaking changes detected but allowed for unreleased major spec." Include the full classification list.
     - If `is-unreleased-major = false`, **the workflow fails (`exit 1`)**. The PR comment includes the full classification list, each entry citing the ADR-0057 D4 category (`Removed endpoint`, `Renamed field`, etc.) and the structural location (path, method, field). The PR comment also includes the remediation: "Bump the major version: copy `openapi-v{N}.yaml` to `openapi-v{N+1}.yaml`, apply the breaking changes there, leave `openapi-v{N}.yaml` unchanged for the duration of the deprecation window per ADR-0057 D6."
   - **PR comment publication.** Use the `marocchino/sticky-pull-request-comment@v2` (or equivalent already in HoneyDrunk.Actions) to publish the diff summary; sticky so reruns replace rather than append.
   - **Categories not detectable structurally.** Append a footer to the PR comment: "Note: oasdiff cannot detect *semantic* changes to a field's meaning (the field name and type are unchanged but the interpretation changed) or *changed error code mapping in meaning* (a 409 still returns 409 but the meaning shifted). The Grid-aware review agent (per ADR-0044) flags these on human review of the PR; the OpenAPI-diff gate does NOT catch them."

2. **`HoneyDrunk.Actions/docs/job-openapi-diff.md`** — author the consumer documentation:
   - **Purpose.** Enforce invariant `{N2}` (breaking changes require a major version bump) on every PR that modifies an `openapi-v*.yaml`.
   - **Invocation example** — a minimal caller YAML in a consuming repo (e.g. `HoneyDrunk.Notify/.github/workflows/pr-openapi.yml`):
     ```yaml
     on:
       pull_request:
         paths:
           - 'HoneyDrunk.Notify/api/openapi-v*.yaml'
     jobs:
       openapi-diff:
         uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml@main
         with:
           spec-path: HoneyDrunk.Notify/api/openapi-v1.yaml
           surface-name: notify
     ```
   - **When `is-unreleased-major: true`** — set this for a PR that is building a future-major spec (e.g. `openapi-v2.yaml`) that has not yet been GA'd. The flag is removed when the new major ships GA.
   - **Tag scheme.** Per ADR-0057 D9: `{surface-name}-api-v{N}.{spec-revision}.{sdk-patch}`. The workflow resolves the highest tag matching `{surface-name}-api-v{major}.*` for the major under change.
   - **First-release case.** Until the first tag exists, the workflow runs in branch-anchored mode and emits an info-level warning. This is normal for Web.Rest at v1 freeze and Notify at v1 introduction.
   - **What is NOT enforced.** Semantic changes (field name + type unchanged; meaning changed) and changed-error-code-mapping-in-meaning are not detected by oasdiff alone; the Grid-aware review agent (ADR-0044) catches them on human review. The OpenAPI-diff gate is the *structural* enforcement; the review agent is the *semantic* enforcement.
   - **CI gate behavior.** Required check on every PR that modifies an `openapi-v*.yaml` in the consuming repo. The consuming repo's branch protection adds `openapi-diff` as a required check.

3. **`HoneyDrunk.Actions/CHANGELOG.md`** — add an entry to the most recent dated, versioned section (not `[Unreleased]` per the user's standing convention). Match the existing CHANGELOG entry shape — terse, one line per addition.

4. **`HoneyDrunk.Actions/README.md`** — link to `docs/job-openapi-diff.md` from the workflow catalog section (the README likely has a "Reusable Workflows" subsection listing each `job-*.yml`).

## Affected Files
- `HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml` (new)
- `HoneyDrunk.Actions/docs/job-openapi-diff.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

## NuGet Dependencies
None. This packet ships GitHub Actions YAML; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "GitHub Actions, reusable workflow, CI/CD → HoneyDrunk.Actions" maps exactly per ADR-0012.
- [x] No code change in any other repo.
- [x] No new abstraction or contract — this is a reusable workflow asset.
- [x] No `HoneyDrunk.*` package dependency.

## Acceptance Criteria
- [ ] `HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml` exists as a `workflow_call` reusable workflow with the documented inputs (`spec-path`, `surface-name`, `diff-mode`, `is-unreleased-major`, `oasdiff-version`)
- [ ] The workflow checks out the PR head, installs the pinned `oasdiff` version, resolves the comparison base per `diff-mode` (tag or branch), runs `oasdiff breaking`, and gates on the result
- [ ] When the diff is breaking AND `is-unreleased-major = false`, the workflow exits non-zero and publishes a sticky PR comment with the D4-category-classified breaking-change list and the remediation guidance
- [ ] When the diff is breaking AND `is-unreleased-major = true`, the workflow exits zero and publishes a PR comment indicating breaking changes are allowed for the unreleased major
- [ ] When the diff is non-breaking, the workflow exits zero and the PR comment summarizes the non-breaking additions
- [ ] When there is no comparison base (first introduction of the spec; no tag and no `main` file), the workflow exits zero with an informational comment
- [ ] PR comment includes the footer about semantic / error-meaning changes being uncaught by oasdiff — reviewer attention required
- [ ] `HoneyDrunk.Actions/docs/job-openapi-diff.md` documents the invocation contract, the tag scheme, the first-release case, and the not-enforced categories
- [ ] `HoneyDrunk.Actions/CHANGELOG.md` records the addition in a dated, versioned section (no `[Unreleased]`)
- [ ] `HoneyDrunk.Actions/README.md` links to the new job docs from the workflow catalog
- [ ] No consuming repo is wired in this packet — the wiring lands per-Node when the per-Node spec lands (Web.Rest in packet 07; Notify in packet 08)

## Human Prerequisites
- [ ] **Confirm the pinned `oasdiff` version against the latest stable release** before merging. The packet body lists `v1.10.18` as a placeholder; the executor confirms (or bumps to) the latest stable release at PR time and updates the workflow input default accordingly.

## Referenced ADR Decisions
**ADR-0057 D7 — Breaking-change CI gate (load-bearing).** "Every PR that modifies an `openapi-v*.yaml` runs an OpenAPI diff (tooling: `oasdiff` or equivalent) against the last released spec. A diff classified as 'breaking' per D4's taxonomy fails the build unless the spec being modified is for a new (unreleased) major version. The reviewer cannot land a breaking change to a released spec without bumping the major."

**ADR-0057 D4 — Breaking-change taxonomy.** Eleven breaking categories: removed endpoint, removed response field, renamed field (request or response), type narrowing, semantic change in field meaning, removed enum value, added required request field, changed error code mapping, changed authentication requirement, changed rate-limit envelope shape, changed pagination scheme. Six non-breaking categories: new optional request field, new response field, new endpoint, new optional query parameter, new enum value (with the documented client-side "ignore unknown" rule), loosened type, looser validation. `oasdiff` covers the structural categories directly; semantic-meaning changes and error-code-mapping-meaning changes are reviewer-judgment-enforced.

**ADR-0057 D9 — SDK and spec versioning.** Spec version tag scheme: `{api}-api-v{API-major}.{spec-revision}.{sdk-patch}`. Highest tag matching `{surface-name}-api-v{major}.*` is the comparison base.

**ADR-0012 (referenced) — Actions as CI/CD control plane.** Reusable workflows in `HoneyDrunk.Actions/.github/workflows/job-*.yml` consumed by per-repo callers via `uses:`.

**ADR-0044 (referenced) — Grid-aware review agent.** Catches semantic changes that `oasdiff` cannot detect structurally. The review agent and the OpenAPI-diff gate complement each other; the gate enforces structure, the agent enforces semantics.

**Invariant `{N2}` — Breaking changes require a major version bump.** This workflow is the enforcement mechanism.

## Constraints
- **Pin `oasdiff` to a concrete release tag.** Floating versions ("latest") break determinism; the workflow input has a default that the executor confirms at PR time.
- **Reusable, not invoked.** This packet adds the reusable workflow; it does NOT wire any consuming repo. The wiring happens in packets 07 (Web.Rest), 08 (Notify), and future per-Node packets.
- **PR comment is sticky.** Reruns replace the comment rather than appending — keeps the PR conversation clean.
- **First-release case handled.** Web.Rest and Notify both hit the no-tag-yet path at v1 introduction; the workflow falls back to branch mode with a warning rather than failing.
- **No `Unreleased` CHANGELOG entry.** Per the user's standing convention, the CHANGELOG addition lands in a dated, versioned section.
- **`oasdiff` is the chosen tool.** ADR-0057 D7 says "`oasdiff` or equivalent." This workflow picks `oasdiff`. A future packet may swap if `oasdiff` drifts or another tool becomes dominant — that swap is a follow-up ADR, not a silent change.

## Labels
`feature`, `tier-1`, `core`, `adr-0057`, `wave-2`

## Agent Handoff

**Objective:** Ship the reusable `job-openapi-diff.yml` workflow that runs `oasdiff` on every PR modifying an `openapi-v*.yaml`, classifies the diff per ADR-0057 D4, and fails the build on breaking diffs to released specs. This is the enforcement mechanism for invariant `{N2}`.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make ADR-0057 D4's breaking-change taxonomy machine-enforced rather than human-honor-system. Every per-API repo wires this workflow into its PR checks (the wiring lands per-Node in packets 07, 08, and future per-Node packets).
- Feature: ADR-0057 rollout, Wave 2 (Actions substrate).
- ADRs: ADR-0057 D4 / D7 / D9 (primary); ADR-0012 (Actions as CI/CD control plane); ADR-0044 (review agent complements the gate on semantic categories).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — invariants `{N1}-{N4}` live; the workflow enforces `{N2}`.
- `packet:01` — tech-stack.md commits `oasdiff` as the tool; this packet pins the version.

**Constraints:**
- Pin `oasdiff` version.
- Reusable workflow only; no consuming repo wired here.
- Sticky PR comment.
- First-release case handled (no tag yet → branch mode with warning).
- No `Unreleased` CHANGELOG entry.

**Key Files:**
- `HoneyDrunk.Actions/.github/workflows/job-openapi-diff.yml` (new)
- `HoneyDrunk.Actions/docs/job-openapi-diff.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

**Contracts:** None — reusable workflow only.
