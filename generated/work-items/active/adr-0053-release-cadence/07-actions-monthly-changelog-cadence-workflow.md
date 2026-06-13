---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0053", "wave-3"]
dependencies: ["work-item:00", "work-item:03"]
adrs: ["ADR-0053", "ADR-0012", "ADR-0033"]
accepts: ["ADR-0053"]
wave: 3
initiative: adr-0053-release-cadence
node: honeydrunk-actions
---

# Author the monthly CHANGELOG cadence enforcement workflow per D9 / D16 Phase 6

## Summary
Author a scheduled Actions workflow `monthly-changelog-cadence.yml` per ADR-0053 D9 / D16 Phase 6: it runs once per month against every Live Node and asserts that the Node has either (a) at least one `prod-{date}` tag in the past 30 days (per ADR-0033's tag → environment mapping) or (b) an explicit `## [no changes this month]` CHANGELOG entry under the dated SemVer section. Missed Nodes surface as Grid-health alerts via the existing grid-health aggregator (ADR-0012).

## Context
ADR-0053 D9 reads: "Every Live Node ships at least one prod release per calendar month OR an explicit 'no changes this month' entry in the Node's CHANGELOG.md. The 'no changes' entry is load-bearing: it makes inactivity visible. A Live Node that goes silent for three months without a 'no changes' entry is a Grid-health-aggregator (ADR-0012) alert."

ADR-0053 D16 Phase 6 (Month 2): "A monthly Actions workflow checks every Live Node for either a prod deploy in the past 30 days or a 'no changes' CHANGELOG entry; missing entries become Grid-health-aggregator alerts (per ADR-0012)."

The workflow is scheduled, scoped to the org, and reads each repo's CHANGELOG via the GitHub API. It does not require Azure resources or any deploy-flow integration — it observes the version-of-record (the CHANGELOG) and the tag history; that is sufficient signal.

**Dependency on packet 03.** Packet 03 codifies the `environment` input convention in the deploy workflows; the cadence workflow's "deployed within the last 30 days" check uses the existing tag naming (`prod-{date}` per ADR-0033) which is independent of packet 03, but the workflow's *audit log* records the `environment` from the deploy workflow's run output for traceability. Without packet 03, the audit log carries no explicit environment label and reads less cleanly. The hard requirement is on the tag naming alone; the soft requirement is on packet 03's input for cleaner audit logs.

**Live Nodes list.** ADR-0053 D9 names "every Live Node." The Grid's source of truth for Node status is `catalogs/grid-health.json` (the `signal` field — values include `live`, `seed`, `archived`). The workflow reads `catalogs/grid-health.json` from `HoneyDrunk.Architecture` to enumerate Live Nodes, then iterates each Live Node's repo.

**Where the alert goes.** ADR-0053 D16 Phase 6 says "missing entries become Grid-health-aggregator alerts." The grid-health aggregator (ADR-0012) is the canonical alert surface. The workflow either calls the aggregator's API (if one exists) or opens a GitHub Issue in `HoneyDrunk.Architecture` per the existing nightly-security pattern. The latter is the safer default — the existing aggregator API surface is not yet finalized; an Issue is the same operational signal and the operator already has a manual-close convention for security issues (per the memory record).

This is a workflow/YAML packet. No .NET project. The repo's `CHANGELOG.md` is updated per the existing convention.

## Scope
- `.github/workflows/monthly-changelog-cadence.yml` (new) — the scheduled workflow.
- `docs/consumer-usage.md` — document the workflow's behavior and how a Node's CHANGELOG should carry the "no changes this month" entry.
- The repo `CHANGELOG.md` — dated SemVer entry.

## Proposed Implementation
1. **`monthly-changelog-cadence.yml` — workflow shape:**
   - Trigger: `on: schedule: cron: '0 4 1 * *'` — 04:00 UTC on the 1st of each month.
   - Also `on: workflow_dispatch:` so the operator can run it manually for testing.
   - One job that iterates the Live Nodes:
     - Reads `catalogs/grid-health.json` from `HoneyDrunkStudios/HoneyDrunk.Architecture` via the GitHub API (`gh api /repos/HoneyDrunkStudios/HoneyDrunk.Architecture/contents/catalogs/grid-health.json`) and parses it for nodes with `signal: "Live"` (capitalized — the canonical value in `grid-health.json` is `"Live"`, not `"live"`; case-sensitive comparison required).
     - For each Live Node, runs two checks in parallel:
       - **Check A — Prod deploy in the past 30 days.** `gh api /repos/HoneyDrunkStudios/{repo}/tags` and filter for tags matching `prod-{YYYY-MM-DD}` (or `{component}-v*` followed by a `prod-{date}` deploy tag per the multi-deployable Notify pattern from `infrastructure/conventions/tag-and-release-conventions.md`). If at least one matches and its date is within the past 30 days: pass.
       - **Check B — 'No changes this month' CHANGELOG entry.** `gh api /repos/HoneyDrunkStudios/{repo}/contents/CHANGELOG.md` and search the file for an entry shaped `## [no changes - YYYY-MM]` or `## [<version>] - YYYY-MM-DD` with body text "no changes this month" (the precise format is documented in the workflow and in `docs/consumer-usage.md`; nothing fancy — string match against a canonical shape). If the entry references the current calendar month: pass.
     - If either check passes: the Node is on-cadence. If both fail: open or update a single issue on `HoneyDrunkStudios/HoneyDrunk.Architecture` titled `Grid-health: cadence miss — {node} {YYYY-MM}` per the existing nightly-security pattern; the issue body lists the Node, the missed month, the recommended remediation (either ship a release or add a `## [no changes - YYYY-MM]` CHANGELOG entry), and a re-check date.
   - The workflow respects an "exempt list" — a comment-block in the workflow file naming Nodes to skip (e.g. `HoneyDrunk.Architecture` itself, which has no `CHANGELOG.md` of the usual shape). The exempt list is short and inline; if it grows beyond 2–3 entries, factor it out into a JSON file.
2. **Issue creation idempotency.** The workflow checks for an existing open issue with the canonical title shape before opening a new one. Existing issue: comment-update with the new month's status. Closed issue: open a new issue (the operator manually closed the prior, signalling the prior miss is resolved).
3. **Manual close.** Per the operator's preference, the workflow never closes an issue automatically — manual close only (matching the nightly-security convention).
4. **Permissions.** `permissions: contents: read, issues: write`. The `contents: read` is repo-wide via cross-repo `gh api` calls — the workflow runs under a token (the `GITHUB_TOKEN` for the same-repo issue API plus a Grid-scoped PAT or app token for cross-repo reads). The existing `nightly-security.yml` is the precedent for cross-repo token usage; mirror that pattern.
5. **Docs.** `docs/consumer-usage.md` documents the canonical shape of the "no changes this month" CHANGELOG entry and gives a sample. The doc also notes that the workflow is scheduled in `HoneyDrunk.Actions` only — Grid repos do **not** schedule a per-repo caller; the workflow runs Grid-wide once from `HoneyDrunk.Actions`.

## Affected Files
- `.github/workflows/monthly-changelog-cadence.yml` (new)
- `docs/consumer-usage.md`
- The repo `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — the workflow is Grid-wide observability per ADR-0012 (Actions is the CI/CD control plane).
- [x] No code change in any Node — the workflow observes the version-of-record (CHANGELOG) and the tag history; no Node-side wiring needed.

## Acceptance Criteria
- [ ] `monthly-changelog-cadence.yml` exists with `schedule: cron: '0 4 1 * *'` and `workflow_dispatch:` triggers
- [ ] The workflow reads `catalogs/grid-health.json` from `HoneyDrunkStudios/HoneyDrunk.Architecture` and enumerates Live Nodes (`signal: "Live"` — capitalized, case-sensitive)
- [ ] For each Live Node, the workflow runs two checks: (A) prod tag in the past 30 days; (B) `## [no changes - YYYY-MM]` CHANGELOG entry referencing the current calendar month
- [ ] Both fail → a Grid-health alert issue is opened (or updated) on `HoneyDrunkStudios/HoneyDrunk.Architecture` per the existing nightly-security issue pattern
- [ ] The workflow is idempotent — an existing open alert issue gets a comment update, not a duplicate issue
- [ ] The workflow never auto-closes issues — manual close per the operator's standing preference
- [ ] An inline exempt-list documents Nodes that have no `CHANGELOG.md` of the usual shape (e.g. `HoneyDrunk.Architecture`)
- [ ] `docs/consumer-usage.md` documents the canonical "no changes this month" CHANGELOG entry shape with a sample
- [ ] No new credential — reuse `GITHUB_TOKEN` and the same cross-repo token pattern `nightly-security.yml` uses
- [ ] No secret in the workflow or repo (invariant 8)
- [ ] The repo `CHANGELOG.md` is updated per the existing convention with a dated SemVer entry
- [ ] No `.csproj` version bump — workflow-only

## Human Prerequisites
- [ ] None to land this packet itself.
- [ ] First-run review: after the workflow merges, run it manually via `workflow_dispatch` once. Review the candidate alert list; flag any Node that shows a false-positive miss and adjust the exempt list or fix the CHANGELOG shape detection accordingly.

## Referenced ADR Decisions
**ADR-0053 D9 — Release cadence.** Per-Node release-as-needed; monthly floor: "every Live Node ships at least one prod release per calendar month OR an explicit 'no changes this month' entry in the Node's CHANGELOG.md. The 'no changes' entry is load-bearing: it makes inactivity visible."

**ADR-0053 D16 Phase 6 — Monthly CHANGELOG cadence enforcement.** "A monthly Actions workflow checks every Live Node for either a prod deploy in the past 30 days or a 'no changes' CHANGELOG entry; missing entries become Grid-health-aggregator alerts."

**ADR-0033 — Tag → environment mapping.** `prod-{date}` tags trigger the prod deploy workflow; the cadence workflow's Check A reads these tags.

**ADR-0012 — Actions is the CI/CD control plane.** The cadence workflow lives in `HoneyDrunk.Actions`; the alert surface is the grid-health aggregator (or, until that surface is finalized, a GitHub Issue on `HoneyDrunk.Architecture` per the existing nightly-security pattern).

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** The workflow uses `GITHUB_TOKEN` and the same cross-repo token pattern `nightly-security.yml` uses; no DSN, instrumentation key, or credential is committed.

> **Invariant 38 — The Architecture repo tracks all Hive board items.** Cadence-miss alert issues land on `HoneyDrunkStudios/HoneyDrunk.Architecture` (the Grid's governance home) and are tracked on The Hive board per `initiatives/board-items.md` (per the existing non-initiative tracking convention for nightly-security / grid-health issues).

- **Idempotent.** Existing open alert issue → comment update; closed issue → new issue.
- **Manual close only.** Per the operator's standing preference, the workflow never auto-closes — matches nightly-security.
- **Live Nodes only.** Seed and archived Nodes are skipped; the `signal: "Live"` (capitalized) filter is the source of truth.
- **Exempt list inline.** Architectures repo itself is exempt; the inline list is short.
- **Same cross-repo token pattern as nightly-security.** Do not invent a new token model.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0053`, `wave-3`

## Agent Handoff

**Objective:** Author the monthly CHANGELOG cadence enforcement workflow per ADR-0053 D9 / D16 Phase 6.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make Node inactivity visible — every Live Node either ships a prod release every month or explicitly says "no changes this month"; misses become Grid-health alert issues.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 3.
- ADRs: ADR-0053 D9/D16 Phase 6 (primary), ADR-0033 (tag → environment mapping), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0053 should be Accepted before its cadence enforcement lands.
- `work-item:03` — the `environment` input convention is finalized in the deploy workflows; the cadence workflow's audit log reads the `environment` value from deploy-workflow run outputs where applicable.

**Constraints:**
- Idempotent issue creation; existing open alert gets a comment update.
- Manual close only; mirrors nightly-security.
- Live Nodes only; `signal: "Live"` (capitalized) is the source of truth.
- Same cross-repo token pattern as `nightly-security.yml`.
- Inline exempt list for Nodes without the usual CHANGELOG shape.

**Key Files:**
- `.github/workflows/monthly-changelog-cadence.yml` (new)
- `docs/consumer-usage.md`
- `CHANGELOG.md`

**Contracts:** None — workflow inputs and a scheduled run.
