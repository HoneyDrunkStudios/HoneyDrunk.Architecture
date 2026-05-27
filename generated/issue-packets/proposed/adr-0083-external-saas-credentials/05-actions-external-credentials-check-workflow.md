---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "infrastructure", "ci", "workflow", "adr-0083", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0083", "ADR-0054", "ADR-0063"]
wave: 3
initiative: adr-0083-external-saas-credentials
node: honeydrunk-actions
---

# Author `.github/workflows/external-credentials-check.yml` — scheduled drift-detection for sensitive-inventory

## Summary
Author the scheduled `external-credentials-check.yml` workflow in `HoneyDrunk.Actions` per ADR-0083 D5. The workflow runs daily at 09:00 ET, parses `infrastructure/reference/sensitive-inventory.md` from `HoneyDrunk.Architecture`, filters by `Rotates: yes`, computes days-to-expiry against `TimeProvider.GetUtcNow()` (equivalent: the workflow runner's UTC clock), and escalates at T-30 (comment + `urgent` label on the standing issue), T-7 (comment + `imminent` label), and T+0 (SEV-2 incident record per ADR-0054 + operator notification per ADR-0019 → ADR-0073). Includes a Markdown-table-schema-check sub-step that fails the workflow fast on table-format drift.

## Context
ADR-0083 D5 commits the drift-detection workflow:

> A new scheduled workflow in `HoneyDrunk.Actions`, **`external-credentials-check.yml`** (cron: daily 09:00 ET), parses `infrastructure/reference/sensitive-inventory.md`, **filters by `Rotates: yes`** (rows with `Rotates: no` and `Rotates: automated-elsewhere` are skipped — they have no expiration to compute against), computes days-to-expiry for each remaining row, and:
>
> - **T-30 days or fewer:** comments on the open rotation issue (or opens one if missing), applies the `urgent` label.
> - **T-7 days or fewer:** comments again, applies the `imminent` label.
> - **T+0 (past expiration):** files a **SEV-2 incident record** per ADR-0054 in `generated/incidents/{YYYY-MM-DD}-{credential}-expired.md` and emits an Operator approval-gate-shaped notification per ADR-0019 → ADR-0073 (operator's notification channel).
>
> The workflow is **drift-detection only** — it does not call provider APIs to fetch live expiration data. The inventory is the source of truth; the workflow reads each `Rotates: yes` row's `Current Expiration` field and computes against `TimeProvider.GetUtcNow()` per ADR-0063.

This packet ships exactly that workflow. The Markdown-table parser is the most operationally fragile sub-step; ADR-0083 §Consequences §Negative explicitly names this:

> `external-credentials-check.yml` parses Markdown. Workflow brittleness against table-format edits is a real concern; the workflow includes a schema-check step that fails fast if the table shape drifts. The schema check is part of the workflow's follow-up work below.

This is a workflow packet in `HoneyDrunk.Actions`. No .NET project, no Architecture-repo edits.

## Scope
- Create file `.github/workflows/external-credentials-check.yml` in `HoneyDrunk.Actions` with the workflow described in Proposed Implementation.
- Append to the repo-level `CHANGELOG.md` in-progress entry noting the workflow addition (no version bump — the workflow is repo-local, not a reusable workflow consumed by other repos).

## Proposed Implementation

### Workflow shape

```yaml
name: External Credentials Drift Check

on:
  schedule:
    # 09:00 ET = 14:00 UTC (EST) or 13:00 UTC (EDT)
    # Use 13:00 UTC as the canonical run time; the 1-hour seasonal drift is acceptable
    # because the T-30/T-7/T+0 thresholds are day-grained, not hour-grained.
    - cron: '0 13 * * *'
  workflow_dispatch:
    # Allow manual runs for debugging / first-rotation testing.

permissions:
  contents: read       # checkout inventory file
  issues: write        # comment, open, label rotation issues in HoneyDrunk.Architecture
  # No contents:write — the workflow does not modify the inventory file.

jobs:
  check-credentials:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout HoneyDrunk.Architecture (inventory source)
        uses: actions/checkout@v4
        with:
          repository: HoneyDrunkStudios/HoneyDrunk.Architecture
          token: ${{ secrets.GH_ISSUE_TOKEN }}
          # GH_ISSUE_TOKEN is reused — already permitted to open/comment issues
          # in HoneyDrunk.Architecture per its existing scope.

      - name: Schema-check the inventory table
        id: schema-check
        run: |
          # Fail fast if the inventory file's Markdown table doesn't match
          # the D2 column shape. The downstream parser depends on stable headers.
          # The exact column set this script validates:
          #   Name | Kind | Provider | Where Stored | Bound To | Rotates |
          #   Expiration Cadence | Current Expiration | Rotation Procedure |
          #   Use Cases | Blast Radius if Missed | Owner | Notes
          python3 .github/scripts/inventory-schema-check.py \
            infrastructure/reference/sensitive-inventory.md
        # The schema-check script lives inside this packet's deliverable —
        # author it alongside the workflow under .github/scripts/.

      - name: Parse and evaluate Rotates:yes rows
        id: parse
        run: |
          # Filter by Rotates: yes
          # For each filtered row: compute days-to-expiry from Current Expiration
          #   vs the runner's UTC clock (ISO 8601 dates, UTC, per ADR-0063 N2)
          # Output a JSON array of escalations: [{name, expiration, days_to_expiry, escalation_tier}]
          # where escalation_tier ∈ {ok, urgent_T30, imminent_T7, expired_T0}.
          python3 .github/scripts/inventory-evaluate.py \
            infrastructure/reference/sensitive-inventory.md \
            > escalations.json

      - name: Apply T-30 escalations (urgent label + comment)
        if: success()
        run: |
          # For each row with escalation_tier == urgent_T30:
          #   gh issue list --label external-credential-rotation \
          #     --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
          #     --search "[Rotate] $name"
          #   - If the issue exists: gh issue comment with the T-30 message and
          #     gh issue edit --add-label urgent
          #   - If the issue does not exist (inventory has Current Expiration
          #     but no matching issue): gh issue create with the T-30 message,
          #     label external-credential-rotation,urgent
          python3 .github/scripts/inventory-escalate.py \
            --tier urgent_T30 \
            --escalations escalations.json
        env:
          GH_TOKEN: ${{ secrets.GH_ISSUE_TOKEN }}

      - name: Apply T-7 escalations (imminent label + comment)
        if: success()
        run: |
          python3 .github/scripts/inventory-escalate.py \
            --tier imminent_T7 \
            --escalations escalations.json
        env:
          GH_TOKEN: ${{ secrets.GH_ISSUE_TOKEN }}

      - name: Apply T+0 escalations (SEV-2 incident + standing-issue comment)
        if: success()
        run: |
          # For each row with escalation_tier == expired_T0:
          #   - Create generated/incidents/{YYYY-MM-DD}-{credential}-expired.md
          #     in HoneyDrunk.Architecture per ADR-0054 D7 incident-record shape
          #   - Open a PR against HoneyDrunk.Architecture with the incident file
          #     (the PR is the operator's incident-creation surface; do not commit
          #     directly to main).
          #   - Comment on the standing rotation issue with the incident path.
          # NOTE: Discord notification at T-30 / T-7 / T+0 is OWNED BY ADR-0084
          # packet 10 — that packet edits this workflow to add `notify-discord`
          # call sites after each of the three escalation steps. This packet
          # ships the workflow scaffold WITHOUT Discord branches; the operator
          # gets ONLY a gh-issue-comment escalation between this packet landing
          # and ADR-0084 packet 10 landing. See Risks below.
          python3 .github/scripts/inventory-escalate.py \
            --tier expired_T0 \
            --escalations escalations.json
        env:
          GH_TOKEN: ${{ secrets.GH_ISSUE_TOKEN }}

      - name: Summary
        if: always()
        run: |
          # Print a one-block summary to the workflow run summary so a glance at
          # the Actions tab shows what fired today.
          python3 .github/scripts/inventory-summary.py \
            escalations.json >> $GITHUB_STEP_SUMMARY
```

### Supporting scripts

Author the four supporting scripts under `.github/scripts/`:

1. **`inventory-schema-check.py`** — parses the Markdown file, asserts that there is exactly one Markdown table with the expected column headers in the expected order. Exits non-zero with a clear error message on drift. The expected column list per ADR-0083 D2: `Name | Kind | Provider | Where Stored | Bound To | Rotates | Expiration Cadence | Current Expiration | Rotation Procedure | Use Cases | Blast Radius if Missed | Owner | Notes`.
2. **`inventory-evaluate.py`** — parses the table, filters rows where `Rotates: yes`, parses `Current Expiration` as **strict ISO 8601 `YYYY-MM-DD`** (no placeholder text accepted — `TBD …` or similar forms fail-fast with a clear error per N1 of the refine pass), computes `days_to_expiry` against `datetime.utcnow().date()` (UTC per ADR-0063 N2), and emits the JSON array of escalations.
3. **`inventory-escalate.py`** — accepts `--tier` ∈ `{urgent_T30, imminent_T7, expired_T0}` and the escalations file, iterates rows matching the tier, and performs the per-tier action via `gh` CLI (comment, label, create issue, create incident file via PR). On T+0, the script opens a PR via `gh pr create` against `HoneyDrunk.Architecture` to land the incident-record file — do not commit directly to `main`.
4. **`inventory-summary.py`** — emits a Markdown summary to `$GITHUB_STEP_SUMMARY` listing every row evaluated, its days-to-expiry, and its escalation tier (including `ok`). Operator-friendly format.

### Use the existing `GH_ISSUE_TOKEN`

The workflow reuses `GH_ISSUE_TOKEN` rather than creating a new dedicated PAT. The token already has issue:write on `HoneyDrunkStudios/HoneyDrunk.Architecture` per its existing scope (per the inventory row's `Use Cases` cell). Reusing minimizes the PAT count.

If a future re-evaluation determines `GH_ISSUE_TOKEN` should not be reused for this workflow (e.g., separation-of-concerns concern), a follow-up packet introduces a dedicated PAT and adds an inventory row for it — but at this packet, reuse is the cost-disciplined choice.

### Per-environment cron note

The 13:00 UTC cron equates to 09:00 EDT or 08:00 EST. The 1-hour seasonal shift is acceptable because the T-30/T-7/T+0 thresholds are day-grained per ADR-0083 D5. If the operator wants a sharper 09:00 ET regardless of daylight saving, a follow-up packet can switch to two cron entries (`0 13 * * *` for the EDT half of the year, `0 14 * * *` for the EST half) — out of scope here.

## Affected Files
- `.github/workflows/external-credentials-check.yml` (new)
- `.github/scripts/inventory-schema-check.py` (new)
- `.github/scripts/inventory-evaluate.py` (new)
- `.github/scripts/inventory-escalate.py` (new)
- `.github/scripts/inventory-summary.py` (new)
- `CHANGELOG.md` (append to in-progress entry; no version bump)

## NuGet Dependencies
None. This packet ships GitHub Actions YAML and Python scripts, not .NET code.

## Boundary Check
- [x] All workflow edits in `HoneyDrunk.Actions` (the source-of-truth repo for shared CI/CD configuration per invariant 37).
- [x] The workflow checks out `HoneyDrunkStudios/HoneyDrunk.Architecture` for the inventory file, which is read-only checkout (the workflow opens PRs for incident files via `gh pr create`, never commits to `main` directly per ADR-0054).
- [x] Per Invariant 8, the workflow reads and parses the inventory but never logs or stores any secret value — only names, expiration dates, and metadata.
- [x] Per Invariant 38 ("Reusable workflows invoke tool CLIs directly"), this workflow uses `gh` CLI and Python rather than wrapping a marketplace action. The four supporting scripts are first-party.
- [x] Per Invariant 39, the workflow declares `permissions:` explicitly (`contents: read`, `issues: write`).
- [x] Per Invariant 40 (grid pipeline health is centrally visible), the workflow's results land on the workflow summary page; failures are surfaced through the standard "Only notify for failed workflows" GitHub profile setting plus the grid-health aggregator that polls workflow state.

## Acceptance Criteria
- [ ] `.github/workflows/external-credentials-check.yml` exists with the cron schedule `0 13 * * *` plus `workflow_dispatch`
- [ ] The workflow declares `permissions: { contents: read, issues: write }` explicitly
- [ ] The workflow checks out `HoneyDrunkStudios/HoneyDrunk.Architecture` using `GH_ISSUE_TOKEN` and reads `infrastructure/reference/sensitive-inventory.md`
- [ ] A schema-check sub-step (`inventory-schema-check.py`) fails the workflow fast on Markdown table drift, asserting the D2 column set in the expected order
- [ ] A parse sub-step (`inventory-evaluate.py`) filters by `Rotates: yes`, parses `Current Expiration` as ISO 8601, computes days-to-expiry against UTC per ADR-0063 N2, emits a JSON escalations file
- [ ] T-30 sub-step (`inventory-escalate.py --tier urgent_T30`) comments on the standing rotation issue and adds the `urgent` label; opens the issue if missing
- [ ] T-7 sub-step (`inventory-escalate.py --tier imminent_T7`) comments and adds the `imminent` label
- [ ] T+0 sub-step (`inventory-escalate.py --tier expired_T0`) creates `generated/incidents/{YYYY-MM-DD}-{credential}-expired.md` per ADR-0054 D7 incident-record shape, via PR against `HoneyDrunk.Architecture` (never direct commit to `main`)
- [ ] **T+0 incident PR body carries strict Authorship metadata.** Per the operator's PR-metadata rule (every HoneyDrunk Grid PR body needs strict `Authorship: <enum>` + exactly one of `Packet:` / `Out-of-band reason:`), the PR `inventory-escalate.py` opens at T+0 includes verbatim:
  - `Authorship: agent-claude-code`
  - `Out-of-band reason: external-credentials-check.yml drift detection; T+0 expiration of {credential}; see incident record at {incident-record-path}`
  - Where `{credential}` is the row's `Name` column and `{incident-record-path}` is the relative path to the `generated/incidents/{YYYY-MM-DD}-{credential}-expired.md` file the PR itself creates
  - The script's PR-body template is the source of truth for this format; do not rely on operator memory
- [ ] T+0 sub-step comments on the standing rotation issue with the incident-record path (the load-bearing escalation surface this packet ships)
- [ ] **Discord notification at T-30 / T-7 / T+0 is NOT shipped by this packet.** That wiring is owned by ADR-0084 packet 10, which edits this workflow to add `notify-discord` call sites after each escalation step. The workflow scaffold + cron schedule + parsing logic land here; the Discord branches do not. The conditional defer language ("if external-credentials-check.yml does not exist, skip") is gone from ADR-0084 packet 10 — that packet hard-depends on this one
- [ ] Until ADR-0084 packet 10 lands, the operator's only escalation surface is the gh-issue-comment path (T-30 / T-7 / T+0 each add a comment to the standing rotation issue; the urgent/imminent labels apply; T+0 also files the SEV-2 incident PR). This is acknowledged as a temporary gap in the Risks section below
- [ ] A summary sub-step (`inventory-summary.py`) writes every evaluated row to `$GITHUB_STEP_SUMMARY` with its days-to-expiry and escalation tier
- [ ] Workflow uses `gh` CLI and Python directly per Invariant 38 — no marketplace-action wrapping of `gh` operations
- [ ] Workflow reuses `GH_ISSUE_TOKEN` rather than introducing a new dedicated PAT (cost-disciplined per ADR-0083 D1)
- [ ] The four supporting scripts under `.github/scripts/` are authored alongside the workflow YAML in the same PR
- [ ] No secret value is logged, traced, or written to any file by the workflow (Invariant 8 preserved)
- [ ] Repo-level `CHANGELOG.md` appends to the in-progress entry (no version bump — workflow is repo-local, not a reusable workflow consumed by other repos)
- [ ] Workflow does not modify the inventory file (`contents: read` only on Architecture checkout)
- [ ] Workflow does not call any provider API (SonarCloud, NuGet, GitHub PAT-management) — drift-detection only, per ADR-0083 D5
- [ ] **Heartbeat:** every successful run writes a one-line success-heartbeat to the workflow's `$GITHUB_STEP_SUMMARY` and ALSO adds `external-credentials-check.yml` to the grid-health aggregator's "must run weekly" watch list (whichever surface the operator chose at packet-authoring time). The rationale: `external-credentials-check.yml` reuses `GH_ISSUE_TOKEN`, which is itself a rotation-needing PAT. If `GH_ISSUE_TOKEN` expires silently, this workflow stops running and the inventory drift goes undetected — the "watcher who watches the watcher" hole. The heartbeat or the grid-health watch entry is the load-bearing mitigation. The operator confirms which of the two paths was chosen in the PR body.

## Human Prerequisites
- [ ] **Confirm `GH_ISSUE_TOKEN` has issue:write on `HoneyDrunkStudios/HoneyDrunk.Architecture`** in the GitHub org secret's scope settings. The reuse-it-don't-create-new decision per ADR-0083 D1 depends on this being true. If the existing token's scope is narrower than required, the operator either (a) regenerates the token with the broader scope per the github-pat-rotation walkthrough (packet 04) — and updates the inventory row's `Current Expiration` — or (b) defers this packet pending a dedicated PAT, which would require its own inventory row first.
- [ ] **First-run verification.** After the workflow lands, trigger it manually via `workflow_dispatch`. Verify:
  - The schema-check passes against the inventory file packet 01 shipped.
  - The summary shows every `Rotates: yes` row with `escalation_tier: ok` (no escalations on day-1 if the seed dates were set correctly).
  - If any escalation fires immediately, that is real and the operator handles it via the relevant rotation walkthrough (packet 02/03/04).
- [ ] **Confirm the cron tick.** After 24 hours, verify the scheduled run fired automatically (Actions tab → External Credentials Drift Check → Last run). GitHub Actions cron jitter is real (sometimes runs are skipped if the runner is under-provisioned at the scheduled time); a missed tick is informational but not actionable on the first occurrence.
- [ ] **Add `external-credentials-check.yml` to the grid-health aggregator's watch list** (if the heartbeat-via-grid-health path was chosen in the acceptance criteria above). Concretely: edit the aggregator's per-workflow entry list to include `HoneyDrunk.Actions/.github/workflows/external-credentials-check.yml` with a "must have run in the last 7 days" rule. This closes the "watcher who watches the watcher" hole — if `GH_ISSUE_TOKEN` silently expires and this workflow stops running, the aggregator surfaces the silence at the next grid-health pass.

## Referenced ADR Decisions
**ADR-0083 D5 — Drift-detection workflow.** Daily cron, parses the inventory, filters by `Rotates: yes`, escalates at T-30 / T-7 / T+0. Drift-detection only — does not call provider APIs. The inventory is the source of truth.

**ADR-0083 D5 §Rejected alternative — Provider-API-driven drift detection.** Not adopted at solo-developer + fewer-than-ten-credentials scale; the cheap version catches the actual failure mode (operator forgets to update the inventory after a rotation).

**ADR-0083 D5 §"Silent breakage is no longer the failure mode."** The T-30 / T-7 / T+0 escalation makes the consuming-workflow break the fourth signal, not the first. This packet ships exactly that escalation.

**ADR-0083 §Consequences §Negative — "`external-credentials-check.yml` parses Markdown."** The workflow includes a schema-check sub-step that fails fast on table drift. This packet ships exactly that sub-step.

**ADR-0054 D7 — Incident-record front-matter.** T+0 incident files conform to ADR-0054's incident-record shape: `generated/incidents/{YYYY-MM-DD}-{credential}-expired.md` with the SEV-2 classification and the standard front-matter fields.

**ADR-0063 N2 — "All persisted and transmitted timestamps are UTC."** The workflow computes days-to-expiry in UTC, against UTC `Current Expiration` values, per the clock-policy invariant.

**ADR-0019 → ADR-0073 — Operator notification path.** For T+0, ADR-0083 D5 directs an operator notification per the ADR-0019 → ADR-0073 channel. The full Notify substrate is not yet live; this packet ships a best-effort placeholder (a clear comment on the standing rotation issue) and the operator can swap in the real Notify call when ADR-0073 lands.

**Invariant 8 — "Secret values never appear in logs, traces, exceptions, or telemetry."** The workflow reads names and dates only; never logs or stores any secret value.

**Invariants 37, 38, 39, 40 — Grid CI/CD discipline.** The workflow is in `HoneyDrunk.Actions` (the source-of-truth repo per 37); uses `gh` CLI and Python directly without marketplace wrapping (per 38); declares `permissions:` explicitly (per 39); results land on the workflow summary and surface through the standard failure-notification path (per 40).

## Constraints
- **Drift-detection only — no provider API calls.** Per ADR-0083 D5 §Rejected alternative: do not add SonarCloud API calls, NuGet API calls, or GitHub PAT introspection calls to "double-check" the inventory against live provider state. The inventory is the source of truth; the operator's discipline to update it on rotation is the trusted contract.
- **Never modify the inventory file.** Workflow has `contents: read` on Architecture, not `write`. Any "fix the inventory automatically" affordance is out of scope and would couple the workflow to ADR-0083's broader governance discipline in unhealthy ways.
- **T+0 incidents land via PR, not direct commit.** Per ADR-0054 and the standard "no direct commit to `main`" Grid discipline. The PR is the operator's incident-creation surface; the operator merges with whatever incident-acknowledgement comment.
- **Reuse `GH_ISSUE_TOKEN`, do not create a new PAT.** Per ADR-0083 D1's cost discipline (fewer than ten PATs total Grid-wide); adding a dedicated PAT for this workflow would push the count higher without proportional benefit. If `GH_ISSUE_TOKEN`'s scope is insufficient, address via the existing token (packet 04 walkthrough) rather than minting a new one.
- **`gh` CLI directly, not marketplace actions.** Per Invariant 38 ("Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI"). `gh` is a stable first-party CLI.
- **Declare `permissions:` explicitly.** Per Invariant 39. `{ contents: read, issues: write }` — no broader.
- **Day-grained, not hour-grained.** Per ADR-0083 D5: thresholds are T-30 days, T-7 days, T+0 day. The 13:00 UTC vs 09:00 ET seasonal-shift discrepancy is irrelevant because the workflow's day boundary is the date, not the hour.
- **No secret value handling in any script.** The inventory file carries names and dates only (per packet 01's invariant-8 preservation). The workflow's scripts must not be designed to "decrypt and validate" any value, because there are no values to decrypt — only metadata to compute against.
- **Schema-check sub-step is non-negotiable.** ADR-0083 §Consequences §Negative explicitly cites table-format drift as a known concern; the schema check is the named mitigation. Do not ship the workflow without it.

## Risks

- **No Discord escalation between this packet landing and ADR-0084 packet 10 landing.** This workflow ships the scaffold (cron + parser + escalator) and emits via gh-issue-comment only at T-30 / T-7 / T+0. The Discord destination is shipped by ADR-0084 packet 10, which edits this workflow to add `notify-discord` call sites. During the window between this packet's PR merging and ADR-0084 packet 10's PR merging, the operator gets only a label change + a comment on the standing rotation issue at T-30/T-7 and a SEV-2 incident PR at T+0 — no Discord post. The operator must read GitHub issue notifications (the failure mode this initiative is closing) during that window. The mitigation: ADR-0084 packet 10 is on Wave 4 of the ADR-0084 initiative and is intended to land within the same operator-sprint as this packet.
- **The workflow itself is a rotation-needing-PAT consumer.** `GH_ISSUE_TOKEN` is reused; if it expires silently, this workflow stops running and the inventory drift goes undetected — the canonical "watcher who watches the watcher" hole. The mitigation is the heartbeat criterion below in Acceptance Criteria + the operator's grid-health-aggregator watch list.
- **Markdown table parser brittleness.** ADR-0083 §Consequences §Negative explicitly cites this. The schema-check sub-step is the mitigation; ensure it ships and is tested against the format ADR-0083 packet 01 establishes.

## Labels
`feature`, `tier-2`, `infrastructure`, `ci`, `workflow`, `adr-0083`, `wave-3`

## Agent Handoff

**Objective:** Ship the scheduled `external-credentials-check.yml` workflow in `HoneyDrunk.Actions` plus its four supporting Python scripts under `.github/scripts/`, implementing the T-30 / T-7 / T+0 drift-detection escalation per ADR-0083 D5.

**Target:** `HoneyDrunk.Actions`, branch from `main` after packet 01 has merged (the inventory file must exist for the workflow's parser to have a target).

**Context:**
- Goal: Close the silent-CI-degradation failure mode. After this packet, a missed rotation surfaces at T-30 (issue comment + `urgent` label), T-7 (`imminent` label), and T+0 (SEV-2 incident) — not at the silent consuming-workflow break weeks later.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 3.
- ADRs: ADR-0083 D5 (the workflow's full specification), §Consequences §Negative (schema-check mitigation); ADR-0054 D7 (incident-record shape); ADR-0063 N2 (UTC for all timestamps); ADR-0019 / ADR-0073 (operator notification path, best-effort placeholder for now); Invariants 8 (no secret values), 37 (source of truth in Actions), 38 (gh CLI directly), 39 (explicit permissions), 40 (centrally visible).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 must have merged (the inventory file is the workflow's parser target).

**Constraints:**
- Drift-detection only — no provider API calls.
- Never modify the inventory file (`contents: read` only).
- T+0 incidents land via PR, not direct commit.
- Reuse `GH_ISSUE_TOKEN`; do not create a new PAT.
- `gh` CLI directly per Invariant 38; no marketplace-action wrapping.
- Declare `permissions:` explicitly per Invariant 39.
- Day-grained, not hour-grained.
- No secret value handling in any script (Invariant 8 preserved).
- Schema-check sub-step is non-negotiable.

**Key Files:**
- `.github/workflows/external-credentials-check.yml` (new)
- `.github/scripts/inventory-schema-check.py` (new)
- `.github/scripts/inventory-evaluate.py` (new)
- `.github/scripts/inventory-escalate.py` (new)
- `.github/scripts/inventory-summary.py` (new)
- `CHANGELOG.md`

**Contracts:** None changed.

**PR Body Metadata:**
- `Authorship: agent`
- `Packet: generated/issue-packets/proposed/adr-0083-external-saas-credentials/05-actions-external-credentials-check-workflow.md`
