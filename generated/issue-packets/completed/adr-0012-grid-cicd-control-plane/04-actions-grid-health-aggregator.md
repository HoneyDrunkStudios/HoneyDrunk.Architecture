---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0012", "wave-2"]
dependencies: ["03-architecture-tracked-workflows-catalog"]
adrs: ["ADR-0012"]
wave: 2
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-actions
---

# CI Change: Author `grid-health-report.yml` aggregator workflow (D6 implementation)

## Summary
Author `.github/workflows/grid-health-report.yml` in `HoneyDrunk.Actions`. The workflow runs on a daily schedule (`30 3 * * *` UTC), reads `HoneyDrunk.Architecture/catalogs/grid-health.json` to discover Grid repos and their `tracked_workflows`, polls `gh api` for each (repo, workflow) latest run, classifies each pair as Pass / Fail / Stale / Missing, renders a single markdown report, and find-or-creates: (a) a stable `🕸️ Grid Health` issue in `HoneyDrunk.Actions` whose body is fully replaced on every run, and (b) a per-repo `[grid-health] {workflow} failing` issue in each affected repo for newly-red pairs (closed automatically when the pair returns to Pass). This is the headline deliverable of ADR-0012's follow-up work.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
Until this workflow exists, pipeline visibility falls back to D7 (GitHub profile notifications) alone. D7 catches failures that fire emails when a workflow runs and fails, but does **not** catch:
- **Staleness** — a workflow that should have run on schedule but did not (e.g. caller-permissions bug fails workflow-load before it can fire any email).
- **Missing runs** — a workflow declared in the catalog but never executed (catches misconfiguration at repo-add time).
- **The single-surface "current state of everything"** — D7 is per-event; D6 is per-snapshot.

ADR-0012 D6 specifies the aggregator end-to-end with no contract ambiguity remaining. This packet is purely implementation work against a fully specified target.

## Proposed Implementation

### `.github/workflows/grid-health-report.yml` (new)

**Triggers:**
- `schedule:` — `cron: "30 3 * * *"` (UTC). Thirty minutes after the latest scheduled nightly trigger across the Grid, chosen so every nightly has had a reasonable chance to finish.
- `workflow_dispatch:` — operator can run on demand for verification or after a known recovery.

**Permissions (top-level):**
```yaml
permissions:
  contents: read           # checkout
  issues: write            # find-or-create the 🕸️ Grid Health issue and per-repo failure issues
```

The cross-repo issue creation (per-repo failure issues in Auth, Vault, Kernel, etc.) requires a token with `Issues: Write` on those repos. The default `GITHUB_TOKEN` only has scope on the repo running the workflow (`HoneyDrunk.Actions`). The workflow uses a HoneyDrunk.Actions repo secret named `GRID_HEALTH_PAT` with `Issues: Write` scope on every node with non-empty `tracked_workflows` plus `HoneyDrunk.Actions` and `HoneyDrunk.Architecture` (the same scope shape as `LABELS_FANOUT_PAT` from ADR-0011 packet 05b — copy that pattern; as Communications, Vault.Rotation, and other Seed nodes scaffold scheduled workflows, the PAT scope must be extended to include them, captured in the secrets-inventory entry). The token is referenced via `secrets.GRID_HEALTH_PAT`. If the secret is missing, the workflow fails fast with a clear message naming the secret and the required scopes.

**Concurrency:**
```yaml
concurrency:
  group: grid-health-report
  cancel-in-progress: false
```

Prevents two scheduled-and-dispatch runs from racing.

**Jobs (single job, sequential steps):**

1. **Checkout `HoneyDrunk.Actions`** at `main`.
2. **Checkout `HoneyDrunk.Architecture`** at `main` into `architecture/` (sparse-checkout `catalogs/grid-health.json` only).
3. **Read the catalog and assert schema version.** Parse `architecture/catalogs/grid-health.json`. **Before reading any repo entry**, read `_meta.schema_version` and fail-fast if its value is not at least `"1.1"`. Use a precise check: extract the string, split on `.`, compare numerically — or use `jq` with an explicit `>=` semver-style comparison. The intended message on failure is:
   ```
   ERROR: catalogs/grid-health.json _meta.schema_version is "<actual>", aggregator requires ">=1.1".
   tracked_workflows was introduced at schema 1.1 (packet 03 of the ADR-0012 rollout).
   Verify catalogs/grid-health.json has been updated and merged before running this aggregator.
   ```
   Then exit non-zero. The hard-block on packet 03 already enforces ordering at filing time; this assertion makes the failure mode debuggable if a stale `main` checkout or a future schema regression slips through. After the assertion passes, extract every repo entry's `id`, `name`, `signal`, and `tracked_workflows` array. Repos with `signal: "Seed"` and `tracked_workflows: []` are skipped entirely (they are pre-scaffold and have no workflows to poll).
4. **Poll workflow runs.** For each (repo, workflow_filename) pair:
   - Call `gh api repos/HoneyDrunkStudios/{repo}/actions/workflows/{filename}/runs?per_page=1`.
   - If the API returns `404 Not Found` for the workflow path: classify as **Missing** (workflow declared in catalog but does not exist in the repo).
   - If the API returns `200` with `total_count == 0`: classify as **Missing** (workflow exists but has never run).
   - If the API returns `200` with at least one run, examine the latest run's `conclusion` and `created_at`:
     - `conclusion == "success"` and `created_at` within the staleness window → **Pass**.
     - `conclusion in ["failure", "cancelled", "timed_out"]` → **Fail**.
     - `conclusion == "success"` but `created_at` outside the staleness window → **Stale**.
     - `conclusion == null` (in-progress) and the most recent successful run is within the staleness window → **Pass**. If no recent successful run exists → **Stale**.
   - Staleness windows by workflow filename pattern:
     - `nightly-security.yml`, `nightly-deps.yml`, `nightly-accessibility.yml` — 28 hours (24h schedule + 4h grace).
     - `weekly-deps.yml` — 8 days (7-day schedule + 1-day grace; the cron is `0 3 * * 1`, Monday-only — the window must accommodate every non-Monday day of the week without flagging Stale).
     - `weekly-governance.yml` — 8 days (same rationale as `weekly-deps.yml`).
     - **Generic fallback for any future `weekly-*.yml` workflow** — 8 days. This ensures a future weekly workflow added to a repo's `tracked_workflows` does not flood the report with false-Stale on six days out of seven before someone remembers to extend the explicit window list. The implementation: if the filename starts with `weekly-`, the window is 8 days regardless of explicit listing.
     - **Generic fallback for any future `nightly-*.yml` workflow** — 28 hours, matching the explicit nightly entries.
     - `publish.yml` — no staleness window (release-trigger, not schedule); only Pass / Fail classifications.
     - Any other tracked workflow that does not match one of the prefix patterns above — default to 28 hours but emit a warning to the job summary listing the workflow filename and noting that the default may not be appropriate. The catalog does not currently support per-workflow staleness override; this is a future extension if needed.
5. **Render the report.** Build a markdown table with rows = repos and columns = the union of all tracked_workflows across the Grid. Each cell is one of `🟢 Pass`, `🔴 Fail`, `🟡 Stale`, `⚫ Missing`, or empty (workflow not in this repo's tracked_workflows). Each non-empty cell is a markdown link to the most recent run URL (if any). Above the table:
   - **Header line** with overall status: `🟢 all green` / `🟡 N stale or missing` / `🔴 N failures`.
   - **Last updated** timestamp in UTC, ISO-8601.
   - A short legend explaining the four states.
   Below the table:
   - A "Per-repo failure issues" section listing every open `[grid-health] {workflow} failing` issue across the Grid with a link.
   - A "Catalog drift" section noting any repo in the live `HoneyDrunkStudios/*` org that is NOT in `grid-health.json` (this implements a partial fix for ADR-0012 Gap 4 without scoping a separate workflow). List as a `🟡 Catalog drift` line under the header if any drift is detected.
6. **Update the `🕸️ Grid Health` issue.**
   - **Default path (title-based find-or-create):** find the issue in `HoneyDrunkStudios/HoneyDrunk.Actions` by exact title `🕸️ Grid Health` (use `gh issue list --search 'in:title "🕸️ Grid Health"' --state all` and filter results by exact title match — substring matches and variation-selector-normalized matches are rejected).
   - **Cached-number fallback path** (only if the variation-selector test in Human Prerequisites forced this path): read the issue number from `vars.GRID_HEALTH_ISSUE_NUMBER`. If the variable is empty on first run, create the issue and write the number back via `gh variable set GRID_HEALTH_ISSUE_NUMBER --body "$NUMBER"`. Subsequent runs read the variable and skip the title search.
   - If found and open: replace the body with the rendered markdown via `gh issue edit`.
   - If found and closed: re-open with the same body.
   - If not found (default path) or variable empty (fallback path): create with `gh issue create --title "🕸️ Grid Health" --body "<rendered>"` and apply the `grid-health` label (label seeded by ADR-0011's labels-as-code packet 05a if available; otherwise create the label inline). For the fallback path, capture the new issue number into `vars.GRID_HEALTH_ISSUE_NUMBER` immediately after creation.
7. **Open per-repo failure issues for newly-red pairs.**
   - For each (repo, workflow) classified as **Fail** or **Stale**:
     - Compute the stable title `[grid-health] {workflow} failing` (literal — for `nightly-security.yml` failing in `HoneyDrunk.Auth`, the title is `[grid-health] nightly-security.yml failing`).
     - Look for an existing open issue with that exact title in the affected repo (using `GRID_HEALTH_PAT`).
     - If found and open: edit body with current details (latest run URL, classification, last successful run timestamp). Do **not** create a duplicate.
     - If not found: create it with the rendered details and the `grid-health` label.
8. **Close per-repo failure issues for recovered pairs.**
   - For each (repo, workflow) classified as **Pass**:
     - Look for an open issue with title `[grid-health] {workflow} failing` in that repo.
     - If found: close it with a comment `Resolved by run <url> at <timestamp> UTC.`
9. **Job summary.** Append the rendered report to `$GITHUB_STEP_SUMMARY` so the workflow run page itself shows the same report (useful when debugging the aggregator).

**Failure handling.** If any step fails:
- The `🕸️ Grid Health` issue is **not updated** (the previous body is left in place).
- The stale `Last updated` timestamp on the issue is itself the signal that the aggregator is broken (per ADR-0012 D6's recursive design — "if the aggregator workflow fails, the single `🕸️ Grid Health` issue stops updating, and the stale timestamp is the signal").
- D7 also fires an email for the failed aggregator run.
- The workflow exits non-zero so the failure is visible in the Actions tab.

**Implementation language.** Bash + `gh` CLI + `jq`. No Python, no Node. The classification logic is small enough (~150 lines) to be readable shell. If the script grows past 300 lines, refactor to a single `scripts/grid-health-aggregator.sh` invoked from a thin workflow step — but start inline.

### `scripts/grid-health-aggregator.sh` (optional, only if inline grows past 300 lines)

If the inline workflow exceeds the readability threshold, extract the classification + rendering logic into a shell script under `scripts/` in `HoneyDrunk.Actions`. Keep the workflow file thin (auth, checkout, invoke, push back to issue). Document inputs/outputs at the top of the script.

### `docs/grid-health-aggregator.md` (new)

Short operator-facing doc:
- What the aggregator does (one paragraph).
- The four classifications (Pass, Fail, Stale, Missing) with examples.
- How to read the `🕸️ Grid Health` issue.
- How to deliberately re-run via `workflow_dispatch`.
- How to silence a known-broken-not-fixable-yet pair (today: no mechanism — close the per-repo issue manually with a comment; the next run will reopen it; this is intentional. A future "snooze" mechanism is named here as a deferred enhancement).
- Cross-link to ADR-0012 D6 and invariant 40.

## Affected Files
- `.github/workflows/grid-health-report.yml` (new)
- `scripts/grid-health-aggregator.sh` (optional, only if extracted)
- `docs/grid-health-aggregator.md` (new)
- `CHANGELOG.md` (Actions repo root)

## NuGet Dependencies
None. Pure GitHub Actions / shell.

## Boundary Check
- [x] Lives in `HoneyDrunk.Actions` per ADR-0012 D1 (Actions is the CI/CD control plane).
- [x] Reads but does not write `HoneyDrunk.Architecture/catalogs/grid-health.json`.
- [x] Cross-repo writes are constrained to `Issues: Write` only via a scoped PAT.
- [x] No new contract surface.

## Acceptance Criteria
- [ ] `.github/workflows/grid-health-report.yml` exists with `schedule: cron: "30 3 * * *"` and `workflow_dispatch:` triggers.
- [ ] Top-level `permissions:` block declares `contents: read` and `issues: write`.
- [ ] The workflow checks out `HoneyDrunk.Architecture` (sparse) and reads `catalogs/grid-health.json`.
- [ ] Before reading any repo entry, the workflow asserts `_meta.schema_version >= "1.1"` and fails fast with a clear diagnostic message if the assertion fails.
- [ ] Each repo's `tracked_workflows` is iterated; each pair classified Pass / Fail / Stale / Missing with the staleness windows specified, including the `weekly-*.yml` 8-day fallback and the `nightly-*.yml` 28-hour fallback.
- [ ] On a `weekly-deps.yml` run that completed last Monday, polling on a Sunday does **not** classify as Stale (verified by inspecting the report on a non-Monday).
- [ ] `pr-core.yml` is never polled (would not appear in any `tracked_workflows` per packet 03, but the workflow defends against accidental inclusion with an explicit skip).
- [ ] On a successful run, the `🕸️ Grid Health` issue in `HoneyDrunk.Actions` is updated (or created if absent) with the markdown report.
- [ ] Title-based find-or-create is idempotent — running the workflow twice in a row produces no duplicate issues.
- [ ] On a `Fail` or `Stale` classification, a stable-titled per-repo issue is opened (or its body updated if it already exists). On `Pass`, the per-repo issue is closed with a comment.
- [ ] `GRID_HEALTH_PAT` secret is referenced in the workflow; missing-secret produces a fast, clear failure.
- [ ] `concurrency:` block prevents overlapping runs.
- [ ] Job summary contains the rendered markdown report.
- [ ] `docs/grid-health-aggregator.md` exists and documents the four classifications and the re-run procedure.
- [ ] One end-to-end verification run is performed via `workflow_dispatch` and the produced `🕸️ Grid Health` issue body is reviewed for sanity (operator confirms in PR comments).
- [ ] Repo-level `CHANGELOG.md` entry created or appended with a one-line summary.
- [ ] If `scripts/grid-health-aggregator.sh` is extracted: it has a usage header, handles missing inputs gracefully, and is idempotent.

## Human Prerequisites
- [ ] **Provision `GRID_HEALTH_PAT` repo secret** in `HoneyDrunk.Actions`. Fine-grained PAT scoped to:
  - Every Grid repo with at least one entry in `catalogs/grid-health.json` `tracked_workflows` plus `HoneyDrunk.Actions` itself (where the `🕸️ Grid Health` issue lives) and `HoneyDrunk.Architecture` (where the catalog is read from). Concretely at scope-time: Kernel, Transport, Vault, Vault.Rotation (when scaffolded), Auth, Web.Rest, Data, Pulse, Notify, Communications (when scaffolded), Studios (when its workflow set is non-empty), Architecture, Actions.
  - Permissions: `Issues: Write` only. Nothing else.
  - Expiry: maximum (one year).
- [ ] **Document the PAT in a secrets inventory.** Add an entry to `HoneyDrunk.Architecture/infrastructure/secrets-inventory.md` listing: secret name (`GRID_HEALTH_PAT`), where it lives (HoneyDrunk.Actions repo secret), purpose (grid-health aggregator cross-repo Issues: Write), creation date, expiry date (creation + 1 year), rotation owner (the operator), and a one-line "what breaks if expired" (the aggregator stops being able to create per-repo failure issues; the `🕸️ Grid Health` issue stops updating; D7 email still fires for the aggregator workflow itself failing). **If `infrastructure/secrets-inventory.md` does not exist today**, do **not** block this packet — file a small follow-up packet titled "Author `infrastructure/secrets-inventory.md` as the canonical Grid secrets registry" and note in this packet's PR body that the inventory entry will land in that follow-up. The PAT's existence is documented in the meantime in the PR body itself.
- [ ] **Validate `🕸️ Grid Health` find-or-create idempotency before relying on it.** The title `🕸️ Grid Health` contains a variation-selector (the spider-web emoji is `🕸️` = `U+1F578 U+FE0F`); GitHub search may or may not normalize the variation selector consistently across `gh issue list --search 'in:title "..."'` queries. Before the first scheduled run, perform a one-shot test:
  1. Manually create an issue in `HoneyDrunk.Actions` titled exactly `🕸️ Grid Health` (paste the emoji from the ADR or this packet, do not retype).
  2. Run `gh issue list --repo HoneyDrunkStudios/HoneyDrunk.Actions --search 'in:title "🕸️ Grid Health"' --state all --json number,title`.
  3. If the search returns the manually-created issue exactly once, find-or-create by title is reliable — proceed.
  4. If the search returns zero or more-than-one results, **fall back to caching the issue number in a `HoneyDrunk.Actions` Actions Variable** (e.g. `vars.GRID_HEALTH_ISSUE_NUMBER`). The workflow reads the variable on each run; on first run when the variable is empty, it creates the issue and writes the number back via `gh variable set`. Subsequent runs read the variable directly and bypass the title search.
- [ ] **One-time create the `🕸️ Grid Health` issue placeholder** (only required if the variation-selector test above forced the cached-number fallback; otherwise optional — the title-based find-or-create handles first-run creation).
- [ ] **Verify GitHub profile notifications are configured** per packet 02's runbook. The aggregator's own failures fire D7 email; without D7, an aggregator failure is invisible until the next manual check.
- [ ] **First-run sanity review.** After the first scheduled or dispatched run, the operator reads the produced `🕸️ Grid Health` issue body and confirms each cell's classification matches the actual state of the corresponding workflow's last run. Any divergence is filed as a follow-up.

The code-change critical path is fully delegable. Actor=Agent.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

The `GRID_HEALTH_PAT` value must never appear in step output, job summary, or the `🕸️ Grid Health` issue body. `gh` CLI uses environment-variable injection by default; do not echo `$GH_TOKEN` or pass the PAT on a command line where `set -x` would print it.

> **Invariant 38 (post-acceptance numbering — see packet 01):** Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

The aggregator uses `gh` (GitHub's first-party CLI) and `jq` directly — not a marketplace wrapper. `actions/checkout` is a first-party GitHub action and is permitted.

> **Invariant 40 (post-acceptance numbering):** Grid pipeline health is centrally visible. The `HoneyDrunk.Actions` `🕸️ Grid Health` issue is the single canonical view of CI/CD state across the Grid, updated at least daily by the grid-health aggregator. Staleness of that issue is itself a signal — the aggregator's own failure surfaces as the issue not updating. Real-time per-failure notification is separately delivered by the operator's GitHub profile notification settings ("Only notify for failed workflows"), and both mechanisms are mandatory. See ADR-0012 D6, D7.

This packet is the implementation that backs invariant 40.

## Referenced ADR Decisions

**ADR-0012 D6 (Grid Health aggregator):** End-to-end specification of the workflow this packet implements. The `🕸️ Grid Health` issue title is exactly `🕸️ Grid Health` (stable title, find-or-create idempotency). The four classifications (Pass / Fail / Stale / Missing) are bound to specific `gh api` responses as listed in the Proposed Implementation. Per-repo failure issues use the title pattern `[grid-health] {workflow} failing` (also stable, also find-or-create idempotent). Recovery (state returns to Pass) auto-closes per-repo issues with a comment.

**ADR-0012 D6 (recursive failure design):** "If the aggregator workflow fails, the single `🕸️ Grid Health` issue stops updating, and the stale timestamp is the signal." The implementation must NOT swallow errors and continue with a partial report — a partial report would update the issue with a misleadingly-recent timestamp. Errors propagate, the workflow exits non-zero, the issue body is left untouched, and D7 emails the operator.

**ADR-0012 D6 (`pr-core.yml` exclusion):** "`pr-core.yml` is excluded because its state is per-PR, not time-scheduled, and belongs on the PR surface (ADR-0011 D1)." The aggregator must not poll `pr-core.yml` even if (incorrectly) added to a `tracked_workflows` array — defensive skip.

**ADR-0012 D6 (catalog dependency):** "Adding a new Grid repo without adding it to the catalog means the aggregator cannot see it." The aggregator's "Catalog drift" line in the report (Step 5 above) implements a partial fix for ADR-0012 Gap 4: it lists repos in the live `HoneyDrunkStudios/*` org that are missing from `grid-health.json`. This does not require a separate workflow; it is one extra `gh api repos` call in the aggregator.

## Dependencies
- **Hard-blocked by packet 03** (`tracked_workflows` catalog). The aggregator reads `tracked_workflows` directly; without it, there is nothing to iterate.
- Soft-blocked by packet 01 (acceptance) for invariant 38 / 40 numbering.

## Labels
`feature`, `tier-2`, `ci-cd`, `ops`, `adr-0012`, `wave-2`

## Agent Handoff

**Objective:** Ship the daily grid-health aggregator that produces the `🕸️ Grid Health` issue and per-repo failure issues per ADR-0012 D6.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Land the headline deliverable of ADR-0012's follow-up — central pipeline visibility across the Grid.
- Feature: ADR-0012 Grid CI/CD Control Plane, D6 mechanism.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- **Hard-blocked by packet 03** — `tracked_workflows` must exist in the catalog before this workflow has anything to poll.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. The `GRID_HEALTH_PAT` value must never appear in any output. Use environment-variable injection (`env: GH_TOKEN: ${{ secrets.GRID_HEALTH_PAT }}`) and never pass the token on a command line where `set -x` would print it.
- **Invariant 38 (post-acceptance):** Reusable workflows invoke tool CLIs directly. Use `gh` and `jq` directly; no third-party marketplace wrappers. `actions/checkout` is a first-party permitted exception.
- **Invariant 40 (post-acceptance):** The `🕸️ Grid Health` issue is the canonical surface; staleness of the issue is itself a signal. On any error, do not update the issue body — let the stale timestamp signal the aggregator failure.
- **Idempotency.** Title-based find-or-create for both the `🕸️ Grid Health` issue and per-repo failure issues. Two consecutive runs must produce zero duplicates.
- **`pr-core.yml` exclusion.** Per ADR-0012 D6, never poll `pr-core.yml`. Defensive skip even if it accidentally appears in a catalog entry.

**Key Files:**
- `.github/workflows/nightly-security.yml` — style reference for `gh api` invocation patterns and shell quoting.
- `.github/workflows/file-packets.yml` — style reference for cross-repo `gh issue` operations using a scoped PAT.
- `.github/actions-repo/.github/actions/dotnet/setup` — composite-action pattern reference (in case the aggregator's classification logic moves to a composite action).
- `.github/workflows/hive-field-mirror.yml` — reference for cross-repo write operations and PAT conventions.

**Contracts:** No code or NuGet contracts. Behavioral contract is the `🕸️ Grid Health` issue body shape (markdown table + header status line + per-repo issue links + catalog-drift section). The body shape is the operator-facing contract; future changes to it are reviewed against the operator's mental model, not a schema.
