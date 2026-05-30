---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ci-cd", "ops", "docs", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-actions
---

# CI Change: Refresh `docs/consumer-usage.md` with canonical `permissions:` blocks per ADR-0012 D5/D9

## Summary
Refresh `HoneyDrunk.Actions/docs/consumer-usage.md` so that every reusable-workflow consumer example shows the **canonical top-level `permissions:` block** required by ADR-0012 D5. The doc already exists and already documents the four primary reusable workflows (`pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`, plus deploy variants), but its examples predate ADR-0012's caller-permissions rule and may show callers without an explicit `permissions:` block — which is the exact failure mode the ADR's triggering incident exposed. This packet ensures the documented scaffolds are correct before the audit packet (08) compares live caller workflows against them.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0012 D9 names `HoneyDrunk.Actions/docs/consumer-usage.md` as the canonical scaffold source for new caller workflows: "A new Grid repo is onboarded by copying the relevant scaffolds from the runbook." Per the ADR's Process Consequences: "Onboarding a new caller workflow uses the scaffolds in `HoneyDrunk.Actions/docs/consumer-usage.md` (D9). A caller that is not mechanically copied from the scaffold is a review-agent observation (Suggest-grade)."

For this to be a working policy, the scaffolds must reflect the post-ADR-0012 state. Without this packet, the policy is "copy scaffolds that are silently wrong on the load-bearing `permissions:` block." Packet 08 (caller-permissions audit) compares live caller workflows against these scaffolds; if the scaffolds are stale, the audit's reference state is wrong.

## Proposed Implementation

### Audit and update each consumer example in `docs/consumer-usage.md`

For each section in the doc (the table of contents is at the top of the file: PR Core, PR SDK, Release, Deploy Container to App Service, Deploy Azure Container App, Deploy Azure Function App, Nightly Security, Nightly Deps, Nightly Accessibility, Weekly Governance):

1. **Read the current example block.**
2. **Determine the callee's effective permissions needs.** Read the reusable workflow's `permissions:` block in `.github/workflows/<workflow>.yml`. The callee's block is documentary under `workflow_call` but it is the source of truth for what scopes the callee actually needs at runtime.
3. **Insert or refresh the caller's top-level `permissions:` block.** Use the canonical baselines from ADR-0012 D5:

```yaml
# For nightly-security.yml callers
permissions:
  contents: read
  security-events: write
  issues: write

# For nightly-deps.yml callers
permissions:
  contents: write
  pull-requests: write

# For pr-core.yml callers
permissions:
  contents: read
  pull-requests: write
  checks: write
  security-events: write
```

For workflows not explicitly listed in D5 (release.yml, deploy variants, nightly-accessibility.yml, weekly-governance.yml), derive the canonical block from the callee's own `permissions:` declaration and document the derivation in a brief comment above the example.

4. **Add a short "Permissions" section** to each consumer-usage entry, immediately after the example, explaining:
   - Why the caller needs an explicit block (one-sentence summary of the `workflow_call` token-scope rule).
   - Whether granting more is allowed (yes, but discouraged — least privilege).
   - What happens if the block is missing (workflow-load failure on every scheduled trigger; grid-health classifies as Stale).

### Add a top-of-file "Caller permissions" section

Add a new top-level section before the per-workflow examples titled `## Caller permissions — the load-bearing rule`. Body:

```markdown
Every caller workflow that consumes a reusable workflow from `HoneyDrunk.Actions` must declare a top-level `permissions:` block. Under `workflow_call`, the callee's `permissions:` block is purely documentary — the effective job token permissions are determined by the **caller**. A caller that omits `permissions:` inherits the repository's default token scope (`contents: read`, all writes `none` in the default GitHub Actions configuration), and any reusable workflow that requests a `write` scope fails at workflow-load time with a validation error, before a single step runs.

This rule is invariant 39 in `HoneyDrunk.Architecture/constitution/invariants.md` and is governed by ADR-0012 D5.

**Validation failure is silent until the next scheduled run.** If you add a new caller without `permissions:`, your PR may merge cleanly (the workflow-load check runs at trigger time, not at merge time). The grid-health aggregator (`grid-health-report.yml`) classifies the workflow as **Stale** when its scheduled trigger fails to produce a run, surfacing the bug within ~24 hours. The review agent's Request Changes rule (per `.claude/agents/review.md`) is the earlier safety net.

The canonical permissions baselines below are minimum sets. Granting more than required is legal but discouraged. Granting less is broken at workflow-load time.
```

This section is the single load-bearing prose the per-workflow examples reference.

### Validate every example block compiles

Each example block must be valid YAML and must reference real reusable-workflow filenames in `HoneyDrunk.Actions`. The packet's executor copies each example into a scratch file and runs `actionlint` (or equivalent — e.g. `gh actions-validate` if available; otherwise GitHub's own preview at workflow-load time when the example is committed to a sandbox repo). If `actionlint` is not installed in the cloud runtime, the executor installs it via the canonical CLI install pattern (curl + tar to `/usr/local/bin/actionlint`) per ADR-0012 D4.

### Cross-link to D9 and invariant 39

At the top of the doc, under the existing intro paragraph, add a one-line cross-reference:

```markdown
> Authoritative per ADR-0012 D9 (Decision: caller-workflow scaffolding is documented here). The canonical baselines below are the source of truth for invariant 39 (caller-workflow `permissions:` superset rule).
```

### CHANGELOG entry

Append an entry to `HoneyDrunk.Actions/docs/CHANGELOG.md` (the docs-area changelog, since `consumer-usage.md` is documentation, not a versioned package). If only a repo-root `CHANGELOG.md` exists, use that.

## Affected Files
- `docs/consumer-usage.md` — top-of-file callout section, per-section permissions blocks audited and refreshed
- `docs/CHANGELOG.md` (if exists) or repo-root `CHANGELOG.md` — entry referencing ADR-0012 D5/D9

## NuGet Dependencies
None. Docs only.

## Boundary Check
- [x] Single-repo, doc-only edit.
- [x] No reusable-workflow YAML changed; this packet only changes the doc that **describes** them.
- [x] No new contract surface.

## Acceptance Criteria
- [ ] `docs/consumer-usage.md` contains a top-level `## Caller permissions — the load-bearing rule` section with the prose specified above.
- [ ] Every consumer example in the doc that calls a `HoneyDrunk.Actions` reusable workflow has a top-level `permissions:` block matching the canonical baselines from ADR-0012 D5 (or derived correctly from the callee's declaration for workflows not explicitly listed in D5).
- [ ] Each example is followed by a short "Permissions" subsection explaining the rule.
- [ ] The doc cross-references ADR-0012 D9 and invariant 39.
- [ ] Each example block parses as valid YAML (`actionlint` or equivalent verification).
- [ ] `docs/CHANGELOG.md` (if exists) or repo-root `CHANGELOG.md` updated.
- [ ] The doc still includes the existing intro, table of contents, and per-workflow sections — no content removed beyond outdated examples.

## Human Prerequisites
None. Docs-only refresh, fully delegable.

## Referenced Invariants

> **Invariant 39 (post-acceptance numbering — see packet 01):** Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. Callers that omit `permissions:` inherit the repository default, which is insufficient for any reusable workflow that requests a `write` scope. Validation failure is not detected until the next scheduled run; grid-health (invariant 40) is the safety net. See ADR-0012 D5.

The doc that this packet refreshes is the **canonical source** the rest of the Grid copies from. Stale baselines here propagate to every onboarded caller.

## Referenced ADR Decisions

**ADR-0012 D5 (Caller workflows declare `permissions:`):** "Every caller workflow that consumes a reusable workflow from `HoneyDrunk.Actions` declares a top-level `permissions:` block whose scopes are a superset of the callee's declared needs." The four canonical blocks listed in D5 (`pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`, plus the implicit shape for deploys) are the baselines this doc encodes.

**ADR-0012 D9 (Caller-workflow scaffolding documented in Actions runbook):** "The canonical caller workflow for each reusable workflow is documented in `HoneyDrunk.Actions/docs/consumer-usage.md` (a file referenced by existing reusable-workflow headers — this ADR re-mandates that it stays current). The runbook shows, for each reusable workflow: the correct `permissions:` block (per D5), the minimum set of `with:` inputs for a plain-vanilla .NET Grid repo, and the required `secrets:` passthroughs."

**ADR-0012 D9 (Process Consequence):** "Onboarding a new caller workflow uses the scaffolds in `HoneyDrunk.Actions/docs/consumer-usage.md` (D9). A caller that is not mechanically copied from the scaffold is a review-agent observation (Suggest-grade)."

## Dependencies
- Soft-blocked by packet 01 for invariant 39/40 numbering.
- This packet is the **reference state** for packet 08 (caller-permissions audit) — packet 08's audit checklist compares live caller workflows against the scaffolds this packet refreshes.

## Labels
`chore`, `tier-1`, `ci-cd`, `ops`, `docs`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Refresh the canonical caller-workflow scaffolds so every documented example carries the load-bearing `permissions:` block.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Land the documentation-side of ADR-0012 D5 / D9 so the audit packet (08) has a correct reference state to compare against.
- Feature: ADR-0012 Grid CI/CD Control Plane, D5 + D9 mechanisms.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01 for invariant numbering.
- Reference state for packet 08.

**Constraints:**
- **Invariant 39 (post-acceptance):** The canonical baselines in this doc are the source of truth. Granting more is allowed, granting less is broken. Use the exact D5 blocks for `pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`. For workflows not explicitly listed in D5, derive from the callee's own `permissions:` declaration and document the derivation.
- **Invariant 38 (post-acceptance):** Reusable workflows invoke tool CLIs directly. If the executor installs `actionlint` for validation, install via direct CLI (`curl | tar | mv`) — not via a marketplace wrapper.
- **No reusable workflow YAML changed.** This packet only edits the doc. If the executor identifies a discrepancy between the callee's declared `permissions:` and the canonical baseline (i.e. a reusable workflow itself appears to need a different scope than D5 documents), do **not** edit the workflow — file a follow-up issue and proceed with the doc reflecting the D5 baseline. The discrepancy is a separate review.
- **Preserve existing structure.** The doc's table of contents and per-workflow sections are kept. Only the per-example permissions blocks and the new top-of-file callout section are introduced.

**Key Files:**
- `docs/consumer-usage.md` — primary edit target.
- `.github/workflows/pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`, `release.yml`, `nightly-accessibility.yml`, `weekly-governance.yml`, `job-deploy-container-app.yml`, `job-deploy-container.yml`, `job-deploy-function.yml` — read-only references for the callee's declared permissions.
- `docs/CHANGELOG.md` — append entry.

**Contracts:** No code or schema contracts. The doc shape is the operator-facing contract; future changes to the per-section format are reviewed against operator readability.
