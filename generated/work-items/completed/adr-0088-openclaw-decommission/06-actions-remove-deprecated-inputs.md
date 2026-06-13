---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "meta", "ci", "adr-0088", "wave-4"]
dependencies: ["work-item:03"]
adrs: ["ADR-0088", "ADR-0086", "ADR-0044"]
accepts: []
wave: 4
initiative: adr-0088-openclaw-decommission
node: honeydrunk-actions
---

# Remove the vestigial deprecated `openclaw-*` inputs from `job-review-request.yml`

## Summary
In `HoneyDrunk.Actions`, remove the deprecated, ignored OpenClaw-era inputs from `.github/workflows/job-review-request.yml`: the `openclaw-webhook-url` input, the `openclaw-webhook-secret` secret, and the three fallback inputs `upload-fallback-artifact`, `post-fallback-comment`, and `artifact-name`. ADR-0086 already rewrote this workflow to the label-and-comment enqueue form; these inputs were retained as declared-but-ignored caller-compatibility shims. With OpenClaw fully decommissioned and the org secret deleted (packet 03), they are pure vestigial surface and are removed. Sequenced after the secret deletion so no caller can pass a now-nonexistent secret.

## Context
ADR-0088 D3 Group 4 step 12:

> Remove the vestigial deprecated `openclaw-webhook-url` / `openclaw-webhook-secret` / fallback inputs from `HoneyDrunk.Actions/.github/workflows/job-review-request.yml` once no caller references them. This is a cleanup follow-up in the Actions repo, sequenced after the secret is deleted so no caller can pass a now-nonexistent secret.

Verified current state of `.github/workflows/job-review-request.yml`:
- `inputs.openclaw-webhook-url` (declared lines 34–38, description: "Deprecated ADR-0044 input retained for compatibility; local-worker queueing ignores it")
- `inputs.upload-fallback-artifact` (lines 39–43, same deprecated description)
- `inputs.post-fallback-comment` (lines 44–48, same)
- `inputs.artifact-name` (lines 49–53, same)
- `secrets.openclaw-webhook-secret` (lines 85–87, "Deprecated ADR-0044 secret retained for compatibility; local-worker queueing ignores it")

**These five are declared but never referenced** in the workflow body — a repo grep confirms the only occurrences are the declaration lines. The live inputs (`queue-label`, `in-progress-label`, `reviewed-label`, `changes-requested-label`, `queue-comment-marker`, `apply-classification-labels`, `review-config-path`, `runs-on`, `github-token`) are untouched. (Note: the runner input is named `runs-on` at `job-review-request.yml:24` — consumed at `runs-on: ${{ inputs.runs-on }}`; there is no input literally named `runner`. The `runner` token elsewhere in the workflow is the `.honeydrunk-review.yaml` config key parsed from the target repo, not a workflow input.) Removal is therefore a clean deletion with no body-logic changes.

The consumer caller — `HoneyDrunk.Architecture/.github/workflows/grid-review-request.yml` — has no live OpenClaw dependency (it queues via labels/comments per ADR-0086). Confirm no caller in the org still passes any of the five removed inputs before deleting.

This is a CI/YAML packet. `Actor=Agent`. Routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" maps exactly.

## Scope
- `.github/workflows/job-review-request.yml`:
  - Remove the `openclaw-webhook-url` input block (lines 34–38).
  - Remove the `upload-fallback-artifact` input block (lines 39–43).
  - Remove the `post-fallback-comment` input block (lines 44–48).
  - Remove the `artifact-name` input block (lines 49–53).
  - Remove the `openclaw-webhook-secret` secret block (lines 85–87) from the `secrets:` map. Keep `github-token`.
- Confirm no caller (in any repo) passes any of the five removed inputs; if a caller still references one, remove that pass-through first or coordinate (none is expected per ADR-0088 — they are ignored shims).

## Proposed Implementation
1. **Verify packet 03 deleted the secret** so the `openclaw-webhook-secret` input cannot still be referencing a live org secret. Record in the PR body.
2. **Grep the org for callers** of `job-review-request.yml` that pass `openclaw-webhook-url`, `openclaw-webhook-secret`, `upload-fallback-artifact`, `post-fallback-comment`, or `artifact-name`. Expected: none (the Architecture caller `grid-review-request.yml` queues via labels/comments). If any caller passes a removed input, the removal would break that caller — coordinate removal of the pass-through first.
3. Delete the five input/secret blocks listed in Scope. Leave all live inputs (`runs-on`, `review-config-path`, `queue-label`, `in-progress-label`, `reviewed-label`, `changes-requested-label`, `queue-comment-marker`, `apply-classification-labels`) and `github-token` intact. No body-logic edit is needed (the inputs are unreferenced).
4. Validate the workflow YAML parses (e.g. `actionlint` or the repo's existing workflow-lint step) and that the reusable-workflow interface is still satisfied by its callers.
5. Update `CHANGELOG.md`.

## Affected Files
- `.github/workflows/job-review-request.yml`
- `CHANGELOG.md`

## NuGet Dependencies
None. YAML workflow edit only; no .NET project in this repo.

## Boundary Check
- [x] Edit in `HoneyDrunk.Actions` (`.github/workflows/`). Routing rule "workflow, CI, GitHub Actions → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any other repo.
- [x] **Blocked-by packet 03** — sequenced after the org secret is deleted so no caller can pass a now-nonexistent secret (ADR-0088 D3 step 12).
- [x] Live inputs and `github-token` are untouched; only the five deprecated OpenClaw-era shims are removed.
- [x] No body-logic change — the removed inputs are declared-but-unreferenced.

## Acceptance Criteria
- [ ] `inputs.openclaw-webhook-url` is removed from `job-review-request.yml`
- [ ] `secrets.openclaw-webhook-secret` is removed from `job-review-request.yml`
- [ ] `inputs.upload-fallback-artifact`, `inputs.post-fallback-comment`, and `inputs.artifact-name` are removed from `job-review-request.yml`
- [ ] All live inputs (`runs-on`, `review-config-path`, `queue-label`, `in-progress-label`, `reviewed-label`, `changes-requested-label`, `queue-comment-marker`, `apply-classification-labels`, `github-token`) are unchanged
- [ ] No caller in any repo references the removed inputs/secret (verified by org-wide grep; the Architecture caller `grid-review-request.yml` confirmed unaffected)
- [ ] The workflow YAML parses cleanly (workflow-lint / actionlint passes) and the reusable-workflow interface is still satisfied by its callers
- [ ] Packet 03's secret deletion is confirmed before this packet merges (recorded in PR body)
- [ ] CHANGELOG.md records the removal of the deprecated OpenClaw-era inputs/secret

## Human Prerequisites
- [ ] **Confirm packet 03 deleted the `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` org secret before this packet's PR merges.** Sequencing per ADR-0088 D3 step 12 — the deprecated input is removed after the secret is gone, so no caller can pass a now-nonexistent secret. Record in the PR body.

## Dependencies
- `work-item:03` — secret deletion (Architecture-repo packet; sequenced before this Actions cleanup per ADR-0088 D3 step 12).

## Referenced ADR Decisions
**ADR-0088 D3 Group 4 step 12 — Remove the vestigial deprecated `openclaw-*` inputs.** Once no caller references them, remove `openclaw-webhook-url` / `openclaw-webhook-secret` / the fallback inputs from `job-review-request.yml`. Sequenced after the secret is deleted so no caller can pass a now-nonexistent secret.

**ADR-0086 D2 — `job-review-request.yml` rewritten as the label-and-comment enqueue form.** The deprecated inputs were retained as ignored caller-compatibility shims at that rewrite; ADR-0088 removes them now that OpenClaw is fully decommissioned.

**ADR-0088 Consequences (HoneyDrunk.Actions) — "removes the vestigial deprecated `openclaw-*` inputs/secret from `job-review-request.yml` (D3 step 12), sequenced after secret deletion."**

## Constraints
- **Verify packet 03 first.** The `openclaw-webhook-secret` input must not be removed while the org secret it shadowed is still live and possibly passed by a caller. Confirm deletion before merging.
- **Remove only the five deprecated shims.** Every live input and `github-token` stays. No body-logic change.
- **Confirm no caller passes the removed inputs.** Org-wide grep; the Architecture caller queues via labels/comments and should pass none of them. If any caller still passes one, coordinate removing that pass-through first.
- **Validate the reusable-workflow interface.** After removal, the workflow must still parse and satisfy its callers' `with:`/`secrets:` blocks.
- **Invariant 8 (referenced):** *Secret values never appear in logs, traces, exceptions, or telemetry.* No secret value is touched — only the (ignored) secret *input declaration* is removed.

## Labels
`chore`, `tier-2`, `meta`, `ci`, `adr-0088`, `wave-4`

## Agent Handoff

**Objective:** Remove the five deprecated OpenClaw-era input/secret declarations (`openclaw-webhook-url`, `openclaw-webhook-secret`, `upload-fallback-artifact`, `post-fallback-comment`, `artifact-name`) from `job-review-request.yml`, after confirming the org secret is deleted and no caller references them.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Complete D3 Group 4 step 12 — clean the vestigial OpenClaw surface out of the review-request workflow.
- Feature: ADR-0088 OpenClaw decommission, Wave 4 (D3 Group 4), cross-repo Actions cleanup.
- ADRs: ADR-0088 (primary, D3 step 12), ADR-0086 (the rewrite that left the shims), ADR-0044 (the shims' origin).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — secret deletion (Architecture packet; sequenced before this cleanup).

**Constraints:**
- Verify packet 03's secret deletion first.
- Remove only the five deprecated shims; live inputs + `github-token` stay.
- Confirm no caller passes the removed inputs (org-wide grep).
- Validate the reusable-workflow YAML parses and still satisfies its callers.

**Key Files:**
- `.github/workflows/job-review-request.yml`
- `CHANGELOG.md`

**Contracts:**
- The `job-review-request.yml` reusable-workflow `inputs:` / `secrets:` interface — narrowed by removing the five deprecated entries; the live interface its callers depend on is unchanged.

**PR Body Metadata:**
- `Authorship: agent-codex`
- `Work Item: generated/work-items/completed/adr-0088-openclaw-decommission/06-actions-remove-deprecated-inputs.md`
