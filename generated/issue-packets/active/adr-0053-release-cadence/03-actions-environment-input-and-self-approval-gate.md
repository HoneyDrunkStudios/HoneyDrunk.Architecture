---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0053", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0053", "ADR-0015", "ADR-0033", "ADR-0012"]
accepts: ["ADR-0053"]
wave: 2
initiative: adr-0053-release-cadence
node: honeydrunk-actions
---

# Amend the Actions deploy workflows with an `environment` input and the D15 self-approval gate

## Summary
Amend the reusable deploy workflows in `HoneyDrunk.Actions` (`job-deploy-container-app.yml`, `job-deploy-function.yml`) with two changes per ADR-0053 D16 Phase 2: (1) an explicit `environment` input that names the target environment (`dev` / `staging` / `prod`) — the existing tag → environment mapping per ADR-0033 picks the value; (2) a D15 self-approval gate that requires a self-approval comment on the deploy PR before the prod-path deploy executes.

## Context
ADR-0053 D16 Phase 2 reads: "Update HoneyDrunk.Actions reusable workflows. The `job-deploy.yml` workflow accepts an `environment` input; the tag → environment mapping (per ADR-0033) is encoded in the calling workflow. Self-approval gate (D15) wires into the prod path."

The current reusable deploy workflows (`job-deploy-container-app.yml` and `job-deploy-function.yml`) are already environment-aware in practice (the consumer release workflows from `adr-0033-deploy-trigger-model` pass `dev` / `staging` / `prod` through a `target_environment` job output), but the **input is not named formally** and the **D15 self-approval gate does not exist**. This packet codifies both.

**Input change.** Add a top-level `environment` workflow_call input (string, required when called from a consumer that pushed a tag; defaulted to `dev` when called from `push: branches: [main]`). The reusable workflow validates the value against an allowlist (`dev`, `staging`, `prod`) and fails fast on an unknown value.

**Self-approval gate (D15).** The gate runs **only on the prod path** (`environment == 'prod'`). It checks the deploy PR's comments for a comment by the PR author (an org member, non-bot) that contains the canonical approval phrase **`LGTM-PROD`** — the phrase is pinned at this exact string; do not parameterize it, do not invent alternates. Absent the comment, the workflow fails before the deploy step runs. The comment lookup is read-only against the GitHub API; no new credential is required (the existing `GITHUB_TOKEN` has `pull-requests: read`).

**PR lookup must work post-squash-merge.** ADR-0053 D7 commits squash-merge as the default; after squash the source branch is deleted, so `gh pr list --head <branch>` returns nothing for a tagged commit on `main`. The canonical lookup is `gh api /repos/{owner}/{repo}/commits/{sha}/pulls` (or the equivalent `gh api repos/${{ github.repository }}/commits/${{ github.sha }}/pulls`) — this endpoint returns the merged PRs a commit belongs to and works for squash-merged commits. The workflow uses this endpoint, not the `--head <branch>` variant.

The gate is **friction by design**, not a hard security boundary — ADR-0053 D15 calls it out explicitly: "The cost is 30 seconds per prod deploy; the value is preventing absent-minded `prod-{date}` tag pushes that bypass conscious review." The v2 transition to a true two-party gate (a second human's approval) happens when a second human joins the Studio; this packet is the v1 self-approval implementation.

**AI agents are not approvers.** ADR-0053 D15: "A Codex-authored deploy PR cannot self-approve. The human operator is the only valid approver at v1." The gate's comment-author check excludes the GitHub bot accounts the AI agents post under; the canonical implementation is "the comment author must be a member of the org and must not be a known bot account." The list of known bot accounts is documented in the workflow (kept short — `github-actions[bot]`, `dependabot[bot]`, the OpenClaw reviewer's bot account if it posts comments).

This is a workflow/YAML packet. No .NET project. `HoneyDrunk.Actions` is not a versioned .NET solution — no version bump, no `## NuGet Dependencies`-driven project change. The repo's `CHANGELOG.md` is updated per the existing repo convention.

## Scope
- `.github/workflows/job-deploy-container-app.yml` — add the `environment` input and the D15 self-approval gate (gated to `prod`).
- `.github/workflows/job-deploy-function.yml` — add the same input and gate.
- `docs/consumer-usage.md` — document the new input and the gate; document the canonical approval phrase consumers' PRs need.
- The repo `CHANGELOG.md` — append an entry under a dated SemVer section (or the equivalent, if the repo's CHANGELOG convention differs).

## Proposed Implementation
1. **New workflow input on both deploy workflows:**
   - `environment` (string, required) — one of `dev`, `staging`, `prod`. The reusable workflow validates the value at the start of the first job; an unknown value fails fast with a clear error message.
   - The existing input set is preserved unchanged; `environment` is *additive*.
2. **Validation step at the top of each deploy workflow:**
   - Bash step or composite action that reads `environment` and asserts it is in the allowlist `dev|staging|prod`. Exits non-zero on a miss; the workflow does not proceed to authentication.
3. **D15 self-approval gate — runs only on the prod path:**
   - A job that runs `if: inputs.environment == 'prod'` and gates the deploy job (the deploy job carries `needs: [self-approval-gate]`).
   - The gate job:
     - Resolves the merged PR associated with the deploy commit via `gh api repos/${{ github.repository }}/commits/${{ github.sha }}/pulls` (the `--head <branch>` variant does NOT work post-squash-merge because the source branch is deleted; squash-merge is the default per ADR-0053 D7). The endpoint returns the merged PR(s) the commit belongs to.
     - Reads the PR's comments via the GitHub API (`gh api repos/${{ github.repository }}/issues/{pr_number}/comments`).
     - Filters for comments authored by an org member (not a bot account from the documented list).
     - Asserts at least one such comment contains the canonical approval phrase **`LGTM-PROD`** (encoded as a literal string constant in the workflow file; documented in `docs/consumer-usage.md`).
     - On miss: fails with a clear error message ("No `LGTM-PROD` self-approval comment found on the deploy PR — see the D15 gate in `job-deploy-container-app.yml`"). On match: succeeds; the deploy job proceeds.
4. **No new credential required.** The PR comment lookup uses the existing `GITHUB_TOKEN` with `pull-requests: read` (which the deploy workflows already declare for release-notes assembly).
5. **Backward compatibility.** Existing consumers that already pass an environment via a different parameter name keep working — the new `environment` input is added; legacy parameters are not renamed. If a consumer relies on the implicit `dev` default, the validation step accepts the default value.
6. **Documentation.** `docs/consumer-usage.md` gets a new section: "Environment input and self-approval gate." It documents the input, the allowlist, the canonical approval phrase **`LGTM-PROD`** (pinned), the workflow's behavior on the prod path, and a sample comment a consumer's deploy PR author posts to approve a prod deploy ("`LGTM-PROD`" verbatim). The doc also documents the v1-to-v2 transition note from ADR-0053 D15 and the post-squash-merge PR-lookup endpoint (`gh api repos/{owner}/{repo}/commits/{sha}/pulls`).

## Affected Files
- `.github/workflows/job-deploy-container-app.yml`
- `.github/workflows/job-deploy-function.yml`
- `docs/consumer-usage.md`
- The repo `CHANGELOG.md`

## NuGet Dependencies
None. `HoneyDrunk.Actions` deploy workflows are GitHub Actions YAML — no .NET project is created or modified by this packet.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — the reusable deploy workflows live here per ADR-0012 (Actions is the CI/CD control plane); ADR-0053 D16 Phase 2 names "the HoneyDrunk.Actions reusable deploy workflows."
- [x] No code change in any Node — consumer release workflows already pass the value through; the input/validation/gate live in the reusable workflows.

## Acceptance Criteria
- [ ] `job-deploy-container-app.yml` and `job-deploy-function.yml` each carry an `environment` input (required string; allowlist `dev|staging|prod`); an unknown value fails fast at the top of the workflow
- [ ] Both workflows run the D15 self-approval gate **only when `environment == 'prod'`** — the gate is inert on `dev` and `staging`
- [ ] The gate resolves the deploy PR via `gh api repos/${{ github.repository }}/commits/${{ github.sha }}/pulls` (works post-squash-merge); the `--head <branch>` variant is NOT used
- [ ] The gate fails the deploy when the deploy PR has no self-approval comment from an org-member (non-bot) author containing the canonical approval phrase `LGTM-PROD`
- [ ] The gate succeeds when at least one such comment exists; the deploy job runs after the gate
- [ ] The canonical approval phrase is **`LGTM-PROD`** (pinned, literal) — encoded as a string constant in the workflow file and documented in `docs/consumer-usage.md`
- [ ] The gate uses the existing `GITHUB_TOKEN` with `pull-requests: read`; no new credential, no DSN, no secret in the workflow or repo (invariant 8)
- [ ] AI bot accounts (e.g. `github-actions[bot]`, `dependabot[bot]`, the OpenClaw reviewer bot if applicable) are excluded from the approver-author check; the list is documented in the workflow and `docs/consumer-usage.md`
- [ ] Existing consumers of the deploy workflows are unaffected — `environment` is additive; legacy parameter names are preserved
- [ ] `docs/consumer-usage.md` documents the input, the allowlist, the gate, the canonical approval phrase, a sample deploy-PR approval comment, and the v1→v2 transition note from ADR-0053 D15
- [ ] The repo `CHANGELOG.md` is updated per the existing repo convention with a dated SemVer entry

## Human Prerequisites
- [ ] None to land this packet itself — workflow edits. The first *use* of the gate is when a consuming repo's release workflow targets `environment: prod`. The usage doc covers the consumer-author's "post the `LGTM-PROD` comment" step.
- [ ] The canonical approval phrase is pinned at **`LGTM-PROD`** in this packet; no operator-decision-at-merge step. If a later packet renames the phrase, that is a separate workflow edit.

## Referenced ADR Decisions
**ADR-0053 D8 — Promotion model.** `main` → `dev` auto on merge; `dev` → `staging` via `staging-{date}` tag; `staging` → `prod` via `prod-{date}` tag + the D15 self-approval comment. Same artefact promotes through all environments.

**ADR-0053 D15 — Approvals.** v1 prod deploy = passing CI on the tagged commit + a self-approval comment on the deploy PR. The comment is friction-by-design, not a hard security gate. v2 transitions to a true two-party gate when a second human joins. AI agents are not approvers.

**ADR-0053 D16 Phase 2 — Update HoneyDrunk.Actions reusable workflows.** The `job-deploy.yml` workflow accepts an `environment` input; the self-approval gate wires into the prod path.

**ADR-0033 — Tag → environment mapping.** `staging-{date}` → staging; `prod-{date}` → prod; `main` push → dev. The mapping is encoded in the calling workflow; the reusable workflow receives the resolved `environment` value.

**ADR-0015 — Container hosting.** Azure Container Apps for containerized Nodes; the Actions reusable deploy workflows are the deploy surface.

**ADR-0012 — Actions is the CI/CD control plane.** Reusable workflows in `HoneyDrunk.Actions` are the Grid's CI/CD surface; the D15 gate lives in the reusable workflow, not in each consumer.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** The gate uses `GITHUB_TOKEN`; no DSN, instrumentation key, or credential is committed.

> **Invariant 31 — Every PR traverses the tier-1 gate before merge.** The D15 self-approval gate is *additive* to the tier-1 PR gate — it runs at deploy time (post-merge), not at PR time. Tier-1 stays exactly as is.

- **Gate is prod-only.** `dev` and `staging` deploys are unaffected — the gate's `if: inputs.environment == 'prod'` keeps it inert on lower environments.
- **Self-approval is friction, not a hard security gate.** The implementation reflects D15's framing — the comment lookup is straightforward, the canonical phrase is plain text, and a determined human can absent-mindedly approve. The friction is the value.
- **AI agents are not approvers.** Bot-account check excludes known bot accounts; the list is documented inline.
- **Existing consumers unaffected.** `environment` is additive; legacy parameter names are preserved.
- **Validate fast.** Allowlist check at the top of the workflow; an unknown environment value never reaches the deploy step.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0053`, `wave-2`

## Agent Handoff

**Objective:** Add an `environment` input and the D15 prod-only self-approval gate to the `HoneyDrunk.Actions` reusable container-app and function deploy workflows.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Codify the tag → environment mapping at the reusable-workflow level and add a friction-by-design self-approval step on prod deploys, per ADR-0053 D8 and D15.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 2.
- ADRs: ADR-0053 D8/D15/D16 Phase 2 (primary), ADR-0033 (tag → environment mapping), ADR-0015 (Container Apps deploy surface), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0053 should be Accepted before its deploy-flow changes land.

**Constraints:**
- Gate is prod-only (`if: inputs.environment == 'prod'`); inert on `dev`/`staging`.
- No new credential — reuse `GITHUB_TOKEN` with `pull-requests: read`.
- Bot accounts excluded from approver-author check.
- Existing consumers unaffected — input is additive.
- Validate `environment` value fast at the top of the workflow.

**Key Files:**
- `.github/workflows/job-deploy-container-app.yml`
- `.github/workflows/job-deploy-function.yml`
- `docs/consumer-usage.md`
- `CHANGELOG.md`

**Contracts:** None — workflow inputs only.
