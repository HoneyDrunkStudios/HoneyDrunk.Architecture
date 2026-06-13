---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["enhancement", "tier-2", "ci-cd", "ops", "quality"]
dependencies: []
adrs: ["ADR-0011", "ADR-0012"]
initiative: standalone
node: honeydrunk-actions
actor: Agent
---

# CI: Grid-wide multi-metric coverage baselines (line + branch + method)

## Summary

Extend the HoneyDrunk PR coverage gate to track and ratchet **branch coverage** and **method coverage** alongside line coverage, then re-baseline every .NET consumer repo so the new ratchets are seeded with real measured values. Today the gate (ADR-0011 D2) only ratchets `totalLineCoverage`; branch and method are emitted by coverlet into the same Cobertura artifact but the gate ignores them.

Display of all three metrics already landed in HoneyDrunk.Actions#147 (Scope 1, informational-only). This packet covers Scope 2: schema extension, optional per-metric gating, and per-repo baseline seeding so the metrics become actually-enforced policy, not just a visible number.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Actions` — primary changes land in `pr-core.yml`, `coverage-baseline-ratchet.yml`, and the consumer-usage docs. Consumer-repo baseline re-seeding is mechanical (Actions ships the schema; the next push:main on each consumer repo writes the new baseline). The roll-forward sweep across the 12 .NET consumers is the natural follow-up of merging this packet's Actions PR.

## Motivation

### Why now

- **Display landed; ratchet is the missing half.** Actions#147 made line / branch / method visible in every PR's gate output, but only line is enforced. Reviewers can see branch at 51% on one PR, branch at 48% on the next, and nothing fails — the ratchet protection is silently asymmetric.
- **Line coverage is a weak gate on its own.** A method with `if (a && b && c)` and a single test that hits the all-true path reports 100% line coverage on that method, 12.5% branch coverage (1/8 cases), and 100% method coverage. The ratchet on line alone misses regressions where a test was deleted and only one of three branches still ran.
- **Method coverage as a cheap "did we leave whole files untested" signal.** Once a method's first line is hit, line coverage is "fine" for that method even if 90% of its body is uncovered. Method coverage catches the opposite shape — entire methods that no test exercises at all. Cheaper to interpret than branch.
- **Coverlet already emits all three.** Cobertura XML has `branch-rate` per file and `<line branch="true" condition-coverage="X% (c/t)">` per branch; `<method>` per method. The data is in the artifact every PR uploads. We're choosing not to gate on data we already have.

### Why a single packet (not per-repo)

The schema and gate logic are owned by HoneyDrunk.Actions (invariant 35). The 12 consumer repos consume the workflow at `@main`, so a single Actions PR changes the gate behavior for all of them at once. The per-repo baseline file re-seed is mechanical — the existing `coverage-baseline-ratchet.yml` workflow already writes the file on push:main; this packet just changes what fields it writes.

## Proposed Implementation

### 1. Baseline file schema extension

Current schema (in every consumer's `.github/coverage-baseline.json`):

```json
{
  "totalLineCoverage": 70.9,
  "commit": "abc1234",
  "measuredAtUtc": "2026-05-19T13:36:44Z"
}
```

New schema:

```json
{
  "totalLineCoverage": 70.9,
  "totalBranchCoverage": 51.3,
  "totalMethodCoverage": 82.4,
  "commit": "abc1234",
  "measuredAtUtc": "2026-05-19T13:36:44Z"
}
```

The new fields are **optional on read** (a baseline file with only `totalLineCoverage` keeps working — the gate treats absent fields as "no baseline for this metric"). They become populated automatically the next time `coverage-baseline-ratchet.yml` runs on push:main in each consumer repo.

### 2. `pr-core.yml` gate inputs

Add two new optional inputs (default: off — line-only gating preserved as today):

```yaml
inputs:
  enable-branch-ratchet:
    description: 'Gate on branch coverage in addition to line (D2 extension)'
    required: false
    type: boolean
    default: false
  enable-method-ratchet:
    description: 'Gate on method coverage in addition to line (D2 extension)'
    required: false
    type: boolean
    default: false
```

The Python gate logic adds two conditional comparisons, both using the same 1-decimal rounding the line gate uses (per #147):

```python
if enable_branch_ratchet and 'totalBranchCoverage' in baseline_json:
    branch_baseline = float(baseline_json['totalBranchCoverage'])
    if round(branch_rate, 1) < round(branch_baseline, 1):
        failures.append(f'branch {pct(branch_rate)}% < baseline {pct(branch_baseline)}% (D2-branch)')

if enable_method_ratchet and 'totalMethodCoverage' in baseline_json:
    method_baseline = float(baseline_json['totalMethodCoverage'])
    if round(method_rate, 1) < round(method_baseline, 1):
        failures.append(f'method {pct(method_rate)}% < baseline {pct(method_baseline)}% (D2-method)')
```

Both inputs default `false` to preserve current behavior across all 12 consumers. Each consumer's `pr.yml` opts in by setting `enable-branch-ratchet: true` etc. when their team is ready.

### 3. `coverage-baseline-ratchet.yml` updates

The ratchet workflow computes the new baseline on push:main and writes the JSON. Update it to:

- Parse branch + method from the Cobertura artifact using the same logic added to `pr-core.yml` in #147.
- Write all three values whether or not the consumer has opted into branch/method gating — having the field populated unconditionally means the day the consumer opts in, they get a real baseline instead of a bootstrap.

The ratchet's existing one-way semantics apply: the baseline only moves **up**. Line baseline never ratchets down; branch and method same. If a refactor PR genuinely drops branch coverage permanently, the team's choice to opt into the ratchet is what introduces the friction — they can also opt out per-PR via `enable-branch-ratchet: false` if they need to land the refactor.

### 4. Consumer-usage doc updates

`HoneyDrunk.Actions/docs/consumer-usage.md` (or wherever the gate inputs are documented) needs:

- A new section explaining the three metrics, what each gate catches, and when to opt in.
- Sample `pr.yml` snippet showing `enable-branch-ratchet: true` as an opt-in for repos that want stricter gating.
- A note that branch ratcheting is **volatile** — refactors often shift branch coverage by several points without changing test quality. Recommend repos opt in only after Kernel has run with branch ratcheting for ≥ 30 days and the team has a feel for the noise level.

### 5. Rollout plan (informational — not part of this packet's execution)

After this Actions PR merges:

| Repo | Suggested opt-in |
|---|---|
| HoneyDrunk.Kernel | Branch + method on, after a 30-day soak with display-only |
| HoneyDrunk.Audit, .Vault, .Auth, .Transport, .Web.Rest, .Data, .Notify, .Pulse, .Communications, .AI, .Observe | Method on (low-noise), branch off initially |

Per-consumer opt-in PRs are out of scope for this packet — each repo's team decides when to flip the inputs in their `pr.yml`. The packet only delivers the mechanism.

## Affected Files

- `HoneyDrunk.Actions/.github/workflows/pr-core.yml` — two new inputs, two new conditional gate checks.
- `HoneyDrunk.Actions/.github/workflows/coverage-baseline-ratchet.yml` — parse + write all three metrics.
- `HoneyDrunk.Actions/docs/consumer-usage.md` (or equivalent) — documentation of new inputs and rollout guidance.
- `HoneyDrunk.Actions/docs/CHANGELOG.md` — Added entry under [Unreleased].

No consumer-repo changes in this packet. The first push:main run on each consumer after the Actions PR merges will populate the new fields in their baseline files automatically.

## Acceptance Criteria

- [ ] `pr-core.yml` accepts `enable-branch-ratchet` and `enable-method-ratchet` inputs, both default `false`. Existing consumers (none of which set these inputs today) see no behavior change.
- [ ] When opted in, the gate compares the current PR's branch/method coverage against `totalBranchCoverage` / `totalMethodCoverage` from the consumer's baseline file using the same 1-decimal rounding as the line ratchet (#147).
- [ ] Failure messages are clear and per-metric: `branch X% < baseline Y% (D2-branch)` and `method X% < baseline Y% (D2-method)`. Multiple metric failures concatenate in the verdict (e.g., `FAILED — branch ...; method ...`).
- [ ] `coverage-baseline-ratchet.yml` writes all three fields on every push:main run for every consumer (regardless of whether the consumer has opted into branch/method gating). Bootstrapping reads gracefully — a baseline file missing branch/method fields is treated as "no baseline yet" for those metrics; the gate doesn't fail, and the ratchet writes them next run.
- [ ] Consumer-usage doc has a new section explaining the three metrics, when each gate fires, recommended rollout cadence, and noise expectations for branch coverage.
- [ ] CHANGELOG entry under [Unreleased] describes the schema extension and the new inputs.
- [ ] Smoke test: open a no-op PR against a consumer repo that has `enable-branch-ratchet: false` (current state of all 12) — gate passes regardless of branch coverage. Then flip Kernel's `pr.yml` to `enable-branch-ratchet: true` in a separate follow-up PR, push a deliberately branch-coverage-reducing change, observe the gate fail with `branch X% < baseline Y% (D2-branch)`. Then revert.

## Boundary Check

- Single repo (HoneyDrunk.Actions); no Architecture-repo changes beyond this packet itself.
- No constitutional invariant changes. ADR-0011 D2 (coverage ratchet) is extended in scope, but not amended — the ratchet still ratchets, just across more dimensions now.
- No new external dependencies (coverlet already emits the data).
- Backward compatibility: every existing consumer continues to work without modification. New inputs default off, baseline schema additions are read-tolerant.

## Referenced Invariants

- **Invariant 35** — HoneyDrunk.Actions owns the CI/CD control plane. Consumer repos consume reusable workflows; gate logic lives here.

## Referenced ADR Decisions

- **ADR-0011 D2** — Coverage ratchet. This packet extends the ratchet from line-only to optionally line + branch + method.
- **ADR-0011 D11** — Cost discipline (median PR run < 60s). Branch and method coverage are computed during the existing Cobertura parse pass; no additional `dotnet test` invocation, no new runtime.
- **ADR-0012** — Grid CI/CD control plane. Actions owns; consumers consume.

## Constraints

- Do NOT raise the line-coverage baseline as part of this packet. The baseline ratchet on line is already in place and moves on its own as consumers add tests; bundling a line-bump into this packet conflates "establish new metrics" with "raise the bar on existing metric".
- Do NOT make branch or method ratcheting the default. Branch coverage is genuinely volatile during refactors; defaulting it on across 12 repos would create a wave of false-failure noise before teams have data to set expectations. Opt-in.
- Do NOT touch per-consumer `pr.yml` files in this PR. The opt-in per repo is a separate decision per team; this packet only delivers the mechanism.
- Do NOT add a coverage UI / dashboard / per-method drill-down. SonarCloud already provides that view for any Grid repo. This packet is about the in-PR gate only.

## Agent Handoff

**Context:** Actions#147 (the Scope 1 PR that landed display of branch + method) is the prerequisite — its parse logic for branch and method is what gets reused here. Read `pr-core.yml`'s `Coverage gate` step from `main` after #147 merges to see the current state.

**Key files:**
- `HoneyDrunk.Actions/.github/workflows/pr-core.yml` — extend the Python `Coverage gate` step.
- `HoneyDrunk.Actions/.github/workflows/coverage-baseline-ratchet.yml` — extend the JSON-writing logic.
- `HoneyDrunk.Actions/docs/consumer-usage.md` (or whichever doc the inputs live in) — new section.

**Test approach:** the Python gate logic is exercisable end-to-end via the existing `pr-core.yml` flow on any consumer PR. Suggest opening a draft PR in HoneyDrunk.Kernel after merge with `enable-branch-ratchet: true` set in its `pr.yml`, observing the gate behavior, then reverting and merging Kernel separately once the team is ready to opt in.

**Filing context:** standalone packet — gate-cleanup hardening within ADR-0011's existing scope. No ADR amendment, no initiative folder. `accepts:` is absent because no ADR flips on completion.
