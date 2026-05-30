---
name: Add the deterministic per-change risk scorer to job-review-request.yml
type: ci-change
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "automation", "security", "meta", "tier-3", "adr-0087", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0087", "ADR-0086", "ADR-0044", "ADR-0083"]
wave: 2
initiative: adr-0087-per-change-risk-scoring
node: honeydrunk-actions
---

# Add the deterministic per-change risk scorer to job-review-request.yml

## Summary
Add a deterministic, arithmetic-only weighted-signal risk scorer step to `job-review-request.yml` that reads the PR's changed-file list + per-file add/delete counts, `catalogs/review-risk-signals.json`, and `catalogs/relationships.json`, then emits a numeric `risk_score`, a boolean `double_review_required`, and a one-line `risk_rationale` into the queue comment **from day one** — plus a `gate_mode:` marker distinguishing shadow from gate output. Seed the `risk-high` label via labels-as-code and apply it when the gate trips. There is **no `review_risk_class`** anywhere in this packet — the worker never read that field, so it is not emitted, not computed, and not transitioned. Ships in **Phase-1 shadow posture**.

## Context
ADR-0087 (corrected) replaces the static-per-Node `review_risk_class` flag (ADR-0044 D8 / ADR-0086 D8) with a per-change scorer. The earlier scope assumed a `review_risk_class` worker contract that had to be transitioned. **That premise was false** and is dropped: the local worker (`grid-agent-runner/lib/Queue.psm1`) parses only `head_sha` and `claimed_at` — it never read `review_risk_class` / `risk_class`. So the value the trigger writes today is dropped on the floor. Accordingly this packet emits the new explicit fields from day one and does NOT keep, compute, or emit `review_risk_class`. The trigger MAY drop the dead `risk_class:` line as cleanup (changes no behavior).

`job-review-request.yml` (commit 7a3330e) already computes the changed-file list, additions/deletions, ADR references, authorship class, and a `security`/`secrets` path heuristic, and already upserts the queue comment. This packet plugs the scorer into that existing seam — no new transport, **no LLM in the cloud Action** (ADR-0086 D2/D6: $0 marginal cost preserved).

Packet 01 (Architecture, blocking this packet) ships `catalogs/review-risk-signals.json` — the weight-bearing surface, including the `repo_to_node_id` join table the scorer uses to map `github.repository` to a `relationships.json` node id for blast-radius.

**Non-scope (do NOT do here):**
- Anything the **worker** does with `double_review_required`. The worker reading/acting on it is packet 03; building the dual-pass substrate it triggers is packet 02b. This packet only computes and records the verdict.
- Any `review_risk_class` / `risk_class` emission, computation, or retirement contract. (Optional: delete the dead `risk_class:` line; that is cleanup, not a transition.)

## Proposed Implementation

> **Line numbers below are approximate (from a prior verified pass) — re-confirm against the file on checkout; the workflow may have drifted.**

### Reading the catalogs — raw-fetch is THE mechanism
The `job-review-request.yml` workflow is invoked by `pr-review.yml` (pinned `@main`) and does **NOT** check out HoneyDrunk.Architecture. There is no Architecture working tree at runtime. Therefore the scorer reads both catalogs via cross-repo raw fetch using the existing `github-token`:

```
gh api repos/HoneyDrunkStudios/HoneyDrunk.Architecture/contents/catalogs/review-risk-signals.json --jq '.content' | base64 -d
gh api repos/HoneyDrunkStudios/HoneyDrunk.Architecture/contents/catalogs/relationships.json   --jq '.content' | base64 -d
```

(or the raw media type). Pin to `@main`. Match the field names packet 01 committed (four-signal grouping `sensitivity`/`blast_radius`/`boundary_spread`/`size`, the `forced` flag, and `repo_to_node_id`).

**Fail-open-to-shadow + logged.** If either fetch fails (network, auth, 404, malformed JSON), the scorer MUST NOT fail the workflow and MUST NOT emit a `double_review_required=true` it cannot justify. It falls back to **shadow output**: emit `risk_score: 0`, `double_review_required: false`, `gate_mode: shadow`, and `risk_rationale: catalog-fetch-failed (fail-open to shadow)`, and log a `::warning::` naming the failure. The gate never silently hard-fails a PR on infra flakiness, and a fetch failure can never produce an authoritative gate.

### Pin the numeric weights and threshold here (ADR-0087 D2/D7)
ADR-0087 D2 pins **only the ordering** — `sensitivity ≥ blast-radius > boundary-spread > size` (binding). Numeric weights and the threshold are **owned by this packet** so they stay tunable during the pilot without an ADR amendment. Each signal has a **per-signal weight cap** so the ordering is enforced as ceilings, not just nominal weights:

Choose initial values honoring the ordering, e.g. (illustrative — document the actual chosen values inline):

| Signal | Per-match contribution | Per-signal CAP |
|---|---|---|
| `sensitivity` | `high`→4, `medium`→2, `low`→1 per matched pattern | cap 10 |
| `blast_radius` | `consumed_by` count + 0.5×`consumed_by_planned`, only on `exposes.contracts`/`*.Abstractions` touch | cap 8 |
| `boundary_spread` | distinct path-roots crossed + code-bearing-extension bonus | cap 4 |
| `size` | `min(additions+deletions, cap_in)` scaled down | **cap 2** |

`threshold` = e.g. `5`. `double_review_required = (score ≥ threshold) OR (any forced sensitivity match)`.

#### Worked arithmetic example (MUST appear inline in the step as a comment block, and be the basis of the unit test)
With the above illustrative numbers and `threshold = 5`:

1. **Max-size-alone < threshold (size never trips the gate).** A 4000-line docs-only PR across one root: `sensitivity=0`, `blast_radius=0`, `boundary_spread=1` (one root, no code-bearing bonus), `size` capped at `2`. Total `= 3 < 5` → `double_review_required=false`. The `size` cap (2) is strictly below `threshold` (5), and even `size`+`boundary_spread` maxed (`2+4=6`) is only reachable by crossing multiple code boundaries — never by line count alone. **Acceptance: the maximum achievable `size` contribution (its cap) MUST be strictly less than `threshold`.**
2. **Single forced sensitivity match trips alone.** A one-line edit to `ISecretStore` resolution (a `forced` pattern): `forced` short-circuits → `double_review_required=true` regardless of total score and regardless of authorship (including `human`). Rationale names the forced pattern.
3. **Blast-radius case.** A change to `HoneyDrunk.Kernel`'s `*.Abstractions` widening an exposed contract: `repo_to_node_id["HoneyDrunk.Kernel"]="honeydrunk-kernel"`, `consumed_by=9` → `blast_radius` capped at 8, plus `sensitivity` (Abstractions glob, `high`=4) → `score ≥ 12 ≥ 5` → `double_review_required=true`.

Document every weight, cap, and the threshold inline (a comment block) and note they are packet-owned and tunable per ADR-0087 D2/D7.

### Sensitivity-forced subset (ADR-0087 D6)
A change matching any catalog pattern carrying `forced` (Vault secret-resolution, credentials, `ISecretStore`-class contracts) sets `double_review_required = true` **regardless of authorship and regardless of total score** — including human-authored PRs. The rationale must name which forced pattern tripped. Outside the forced subset: non-`human` PRs gate on score; human-authored PRs do NOT force-gate (they still surface `risk-high` as a signal).

### Boundary-spread computed from the PR file list only
`gh api repos/{owner}/{repo}/pulls/{n}/files` gives **paths + per-file additions/deletions** — NOT file contents or diff hunks. The boundary-spread signal is computed purely from those paths: count distinct top-level roots crossed (e.g. `src/<Package>/`, `infrastructure/`, `.github/`, `catalogs/`) and add a bonus when any touched file has a code-bearing extension (`.cs`, `.ps1`, `.psm1`, workflow `.yml`) vs pure docs/config (`.md`, txt). Do NOT attempt cyclomatic/control-flow analysis — not computable at this tier (ADR-0087 D2.3).

### Read `risk-gate-mode` from `.honeydrunk-review.yaml` (NOT a workflow_call input)
The double-review posture is **shadow** vs **gate** per repo. The caller `pr-review.yml` is pinned `@main` and passes only `review-config-path` — a new `workflow_call` input would be **unreachable by the operator** (the pinned caller can't pass it). Therefore read `risk-gate-mode` (values `shadow` | `gate`, default `shadow`) from each repo's `.honeydrunk-review.yaml` (the same config the workflow already loads). The operator flips a repo to `gate` by editing that repo's `.honeydrunk-review.yaml` — no caller change needed. Emit the resolved mode as `gate_mode:` in the queue comment so downstream (and the operator) can distinguish shadow output from authoritative gate output.

### Emit into the queue comment (ADR-0087 D5) — from day one, no review_risk_class
Extend the queue-comment heredoc to add:
```
risk_score: <number>
double_review_required: <true|false>
gate_mode: <shadow|gate>
risk_rationale: <one line, e.g. "sensitivity: touched ISecretStore resolution (forced); blast-radius: honeydrunk-kernel consumed_by=9">
```
Do **not** emit `risk_class:` / `review_risk_class`. Optionally remove the existing dead `risk_class:` line (cleanup; the worker never read it). Invariant 8: the rationale carries **path and contract names only, never secret values**.

### `risk-high` label (labels-as-code)
Add to `.github/config/labels.json`:
```json
{ "name": "risk-high", "color": "b60205", "description": "ADR-0087 per-change risk scorer flagged this PR for double review." }
```
The existing `seed-labels.yml` / `seed-labels-fanout.yml` propagate it Grid-wide on next run (no new seeding workflow). Apply the label in the scorer step when `double_review_required` is true, reusing the existing `gh api --method POST .../labels` pattern (match its graceful-degradation on apply failure).

### Fixture-based unit test of the scorer arithmetic
Add a unit test (matching the repo's existing test harness — e.g. a `bats`/`pytest`/PowerShell-Pester script under the repo's test dir, or a `actionlint`-adjacent script-test if the scorer logic is extracted to a script). The scorer arithmetic SHOULD be extracted into a testable script (a small `scripts/risk-score.*`) invoked by the workflow step, so it is unit-testable without running Actions. Fixtures MUST cover at least:
- **Forced-trip case:** a file list touching an `ISecretStore`/`forced` pattern → `double_review_required=true` even with `Authorship: human` and tiny size.
- **Docs-only no-trip case:** a large `.md`-only diff → `double_review_required=false` (proves size + single-root boundary-spread stay below threshold).
- **Blast-radius case:** a `*.Abstractions` change in a high-`consumed_by` node → `double_review_required=true` via blast-radius + sensitivity.

The test asserts the two binding properties: (a) max-`size`-alone < threshold; (b) any single forced match trips the gate alone.

## NuGet Dependencies
None. This packet touches a GitHub Actions workflow (YAML), a JSON label config, a small scorer script + its test, and the repo CHANGELOG. No `.csproj`, no .NET project, no `PackageReference`. (Invariant 26 does not apply.)

## Acceptance Criteria
- [ ] `job-review-request.yml` has a deterministic scorer step (logic extractable to a unit-testable script) that reads the PR changed-file list + per-file add/delete counts + `catalogs/review-risk-signals.json` + `catalogs/relationships.json` and computes a numeric `risk_score`.
- [ ] Catalogs are read via cross-repo `gh api` raw-fetch from `HoneyDrunkStudios/HoneyDrunk.Architecture@main` (the workflow does NOT check out Architecture); raw-fetch is the mechanism.
- [ ] On catalog-fetch failure the scorer **fails open to shadow**: emits `risk_score:0`, `double_review_required:false`, `gate_mode:shadow`, a `catalog-fetch-failed` rationale, and a `::warning::` log — it never fails the workflow and never emits an authoritative `double_review_required=true` it can't justify.
- [ ] Weights honor the binding ordering `sensitivity ≥ blast-radius > boundary-spread > size` with per-signal caps; the maximum `size` contribution (its cap) is strictly below the threshold; a worked arithmetic example is inline in the step proving max-size-alone < threshold AND any single `forced` match trips the gate alone.
- [ ] Any `forced`-flagged sensitivity match sets `double_review_required = true` on its own, regardless of authorship (including `human`); the rationale names the tripped forced pattern.
- [ ] `boundary_spread` is computed from the file list only (paths + add/delete counts), counting distinct path-roots + code-vs-docs; no attempt to fetch file contents/hunks.
- [ ] The queue comment carries `risk_score`, `double_review_required`, `gate_mode`, and a one-line `risk_rationale`; the rationale contains only path/contract names, never secret values (invariant 8).
- [ ] **No `review_risk_class` / `risk_class` is computed or emitted** by the scorer; the static default-`normal` `.honeydrunk-review.yaml` read is not relied upon for risk; (optionally) the dead `risk_class:` line is removed.
- [ ] `risk-gate-mode` (`shadow`|`gate`, default `shadow`) is read from the repo's `.honeydrunk-review.yaml` — NOT a `workflow_call` input — and surfaced as the `gate_mode:` queue-comment marker.
- [ ] Ships in shadow posture (default `shadow`); shadow output is observable in the queue comment with the distinguishable `gate_mode: shadow` marker.
- [ ] A `risk-high` PR label is applied when `double_review_required` is true, reusing the existing label-apply pattern with graceful degradation; `risk-high` is added to `.github/config/labels.json` (color `b60205`, ADR-0087 description); no new seeding workflow (existing `seed-labels*.yml` propagate it).
- [ ] A fixture-based unit test of the scorer arithmetic exists and passes, covering the forced-trip, docs-only-no-trip, and blast-radius cases, and asserting (a) max-size-alone < threshold and (b) single-forced-match-trips-alone.
- [ ] No LLM/model API call is added to the cloud Action (ADR-0086 D2/D6); the scorer is deterministic and re-runs to the same verdict for a fixed `(PR, head SHA)`.
- [ ] Repo-level `CHANGELOG.md` records the scorer addition and the `risk-high` label; per-package CHANGELOGs are not touched (no packages change).
- [ ] `actionlint` and the repo's existing workflow-lint pass; `permissions:` unchanged beyond what label-apply + comment-upsert already require (`pull-requests: write`, `issues: write` present).

## Human Prerequisites
- [ ] After this PR merges, run `seed-labels-fanout.yml` (or let its next scheduled run fire) so `risk-high` is seeded Grid-wide — existing labels-as-code fanout, no new infra. (Operator action; the workflow itself ships here.)
- [ ] Phase-2 entry on the `HoneyDrunk.Architecture` pilot is an operator edit of that repo's `.honeydrunk-review.yaml` setting `risk-gate-mode: gate`, AFTER observing shadow-mode firing rate (ADR-0087 D7 Phase 2 go/no-go) AND after packet 02b lands the worker dual-pass substrate — not part of this PR.

## Dependencies
Blocked by packet 01 (Architecture): the scorer has nothing to read until `catalogs/review-risk-signals.json` exists with the four-signal grouping, the `forced` flag, and the `repo_to_node_id` join table. The field names packet 01 commits are the contract this scorer parses. Independent of packet 02b (worker substrate) — the scorer ships and runs in shadow regardless of whether the worker can act on the verdict.

## Agent Handoff

**Objective:** Add the deterministic per-change risk scorer to `job-review-request.yml`, emit `risk_score`/`double_review_required`/`gate_mode`/rationale into the queue comment from day one, seed + apply `risk-high`, in Phase-1 shadow posture read from `.honeydrunk-review.yaml`. No `review_risk_class` anywhere.
**Target:** HoneyDrunk.Actions, branch from `main`.
**Context:**
- Goal: replace the phantom static `review_risk_class` Node-flag with an enforceable per-change risk verdict computed in the cheap GitHub Action.
- Feature: deterministic, arithmetic-only weighted-signal scorer (no cloud LLM).
- ADRs: ADR-0087 (pins ordering, defers numbers here), ADR-0086 D2/D6 ($0-cost / no-LLM-in-Action), ADR-0086 D8 (the dual-CLI worker the gate eventually feeds — its substrate is unbuilt, packet 02b), ADR-0044 D8 (superseded static flag), ADR-0083 (sensitive-inventory, a catalog source).

**PR metadata (required by `pr-core` checks):** the PR body must carry `Authorship: <enum>` (one of `human` / `agent-codex` / `agent-copilot` / `agent-claude-code` / `mixed`) and exactly one of `Packet: <issue link>` (this packet's filed issue) or `Out-of-band reason: <text>`. Free-form text breaks the `pr-core` metadata check.

**Acceptance Criteria:** see the checkboxes above — all must be met.

**Dependencies:** packet 01 (the `catalogs/review-risk-signals.json` it reads, incl. `repo_to_node_id`).

**Constraints:**
- **Pin numbers here; do not change the ordering.** ADR-0087 D2: "This ADR pins only the signal ordering, not the numbers. The binding constraint is the ordering `sensitivity ≥ blast-radius > boundary-spread > size`... numeric weights and the threshold... are deliberately left to the implementing packet so they remain tunable... without an ADR amendment. Re-tuning weights or the threshold is an implementation change... only a change to the ordering above would require amending this ADR." Honor the ordering via per-signal caps; choose the numbers; document them inline.
- **Size is the weakest signal (ADR-0087 D2.4).** The maximum achievable `size` contribution (its cap) MUST be strictly less than the threshold; small size must never offset a tripped sensitivity signal.
- **Boundary spread is paths-only (ADR-0087 D2.3).** Computed from the file list (paths + add/delete counts); `gh api .../files` gives no file contents or hunks. Deeper structural complexity is not computable at this tier — do not attempt it.
- **No LLM in the cloud Action (ADR-0086 D2/D6).** Deterministic so the decision is auditable, free, explainable. No model API call. LLM-judged triage is out of scope (ADR-0087 D3).
- **No `review_risk_class`.** The worker (`grid-agent-runner/lib/Queue.psm1`) parses only `head_sha` and `claimed_at` and never read `review_risk_class`/`risk_class`. There is no contract to transition. Emit the new explicit fields from day one; do not compute or emit `review_risk_class`. (Optionally delete the dead `risk_class:` line.)
- **`risk-gate-mode` from `.honeydrunk-review.yaml`, not a workflow_call input.** The caller `pr-review.yml` is pinned `@main` and passes only `review-config-path`; a new input is unreachable by the operator. Read the mode from the per-repo config and surface it as `gate_mode:`.
- **Fail open to shadow on catalog-fetch failure** — never hard-fail the PR, never emit an authoritative gate you can't justify; log a `::warning::`.
- **Invariant 8 — secret values never appear in logs, traces, exceptions, or telemetry; only secret names/identifiers may be traced.** The rationale written into the public queue comment carries names only.
- **Sensitivity-forced subset gates regardless of authorship (ADR-0087 D6)** — computes/records the verdict only; the worker acting on it (incl. for human PRs) is packet 03.
- **Non-scope:** anything the worker does with `double_review_required`.

**Key Files:**
- `.github/workflows/job-review-request.yml` (scorer step; queue-comment heredoc; config-read step; label-apply pattern) — line numbers approximate, verify on checkout.
- `scripts/risk-score.*` (new — extract scorer arithmetic for unit-testability) + its test under the repo's test dir.
- `.github/config/labels.json` (add `risk-high`)
- `CHANGELOG.md`
- Read-only via `gh api` raw fetch: `HoneyDrunkStudios/HoneyDrunk.Architecture@main:catalogs/review-risk-signals.json`, `...:catalogs/relationships.json`

**Contracts:**
- Queue-comment keys written for the worker (packet 03 reads these): `risk_score` (number), `double_review_required` (boolean), `gate_mode` (`shadow`|`gate`), `risk_rationale` (string). Keep these names stable — packet 03's worker read-path will be wired to them. There is NO `risk_class`/`review_risk_class` key.
- The catalog field names from packet 01 (four-signal grouping + `forced` flag + `repo_to_node_id`) are the parse contract; match them exactly.
