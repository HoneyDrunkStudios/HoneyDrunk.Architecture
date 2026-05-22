---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repos: ["HoneyDrunk.Kernel", "HoneyDrunk.Transport", "HoneyDrunk.Vault", "HoneyDrunk.Auth", "HoneyDrunk.Web.Rest", "HoneyDrunk.Data", "HoneyDrunk.Notify", "HoneyDrunk.Communications", "HoneyDrunk.Pulse", "HoneyDrunk.Actions"]
labels: ["ci", "tier-2", "core", "ops", "coordination", "adr-0044", "wave-2"]
dependencies: ["packet:06", "packet:07", "packet:08", "packet:09", "packet:10"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 2
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Enable the cloud reviewer on the 10 remaining live Nodes (Phase 2 rollout)

## Summary
Roll the cloud reviewer out to the **10 remaining live .NET Nodes** — Kernel, Transport, Vault, Auth, Web.Rest, Data (Core); Notify, Communications, Pulse, Actions (Ops) — by authoring a `.honeydrunk-review.yaml` (`enabled: true`) and a `pr-review.yml` caller in each. This is the Phase-2 fan-out, gated on a successful Phase-1 go/no-go. It is filed as a coordination/tracking issue in `HoneyDrunk.Architecture` with one child issue per Node repo.

## Repo-list reconciliation (read this before filing)
ADR-0044 D11 Phase 2 says "rollout to all 12 live Nodes." The Grid has exactly **12 live Nodes** per `catalogs/grid-health.json` (`signal: "Live"`): Kernel, Transport, Vault, Data, Web.Rest, Auth (Core); Notify, Communications, Pulse, Actions (Ops); Architecture, Studios (Meta). This packet's fan-out is those 12 **minus two**:

- **`HoneyDrunk.Architecture`** — already enabled in Phase 1 (packet 06). Not re-enabled here.
- **`HoneyDrunk.Studios`** — a TypeScript repo, not a .NET Node; its onboarding is evaluated separately (see the dispatch plan's out-of-scope list). Not part of this .NET-shaped fan-out.

That leaves **exactly 10 .NET Node repos** in scope, enumerated in `target_repos` above. **`HoneyDrunk.Observe` is explicitly OUT** — it carries `signal: "Seed"` in `catalogs/grid-health.json` (it is scaffolded but not a live Node) and is not among the 12 live Nodes per the Grid state in CLAUDE.md. Do not add Observe to this fan-out; if Observe reaches `Live` status later, its enablement is a separate follow-up packet, not a silent addition here.

## Context
ADR-0044 D11 Phase 2 rolls the reviewer out to the live Nodes after Phase 1 (the Architecture-repo pilot, packet 06) proves the cloud reviewer's verdicts are at least as useful as the local agent's at acceptable cost. Each repo opts in via `.honeydrunk-review.yaml` with `enabled: true`. Authorship classification (D6) becomes mandatory and PR-size discipline (D7, warnings-only) activates Grid-wide — both come for free via the `pr-core.yml` jobs (packet 07); this packet only adds the per-repo reviewer config and caller.

**This is a multi-repo packet** describing one repeated unit of work across the 10 repos in `target_repos`. The `file-issues` agent files it as a tracking issue in `HoneyDrunk.Architecture` with 10 child issues (one per Node), or as 10 sibling issues — the human/dispatch decides the filing shape. The work per repo is identical and small.

## Per-repo work unit (repeated for each of the 10 Node repos)
For each Node repo:
1. Author `.honeydrunk-review.yaml` at the repo root with `enabled: true`, `severity_floor: Suggest`, `model: sonnet`, `cost_cap_per_pr_usd: 5.00`, and `skip_paths` tuned for that repo (generated code, designer files — per the packet-05 schema doc).
2. Author/extend `.github/workflows/pr-review.yml` to call `job-review-agent.yml` on `pull_request` opened/synchronize/ready_for_review.
3. Verify the repo's PR template carries the `Authorship:` line (or add it) so `authorship-check` (now Grid-wide via `pr-core.yml`) passes.
4. **Private revenue Nodes are excluded from the default rollout** — per ADR-0044 Operational Consequences, any `.Cloud` revenue Node (per ADR-0027 D2) is excluded from the default v1 rollout and requires an explicit opt-in. If a Node in the list is a private revenue Node, leave it `enabled: false` (or omit the file) and note it; do not enable it as part of the default fan-out.

## Affected Repos
Exactly these 10 .NET Node repos: HoneyDrunk.Kernel, HoneyDrunk.Transport, HoneyDrunk.Vault, HoneyDrunk.Auth, HoneyDrunk.Web.Rest, HoneyDrunk.Data, HoneyDrunk.Notify, HoneyDrunk.Communications, HoneyDrunk.Pulse, HoneyDrunk.Actions. **`HoneyDrunk.Architecture` is excluded** (already enabled in Phase 1, packet 06). **`HoneyDrunk.Studios` is excluded** (TypeScript repo, evaluated separately). **`HoneyDrunk.Observe` is excluded** (`signal: "Seed"` in `catalogs/grid-health.json` — not a live Node). Do not add repos to this list; it is pinned, not "any live Node at filing time."

## NuGet Dependencies
None. This packet adds YAML config and a caller workflow per repo; no .NET project or package reference changes.

## Boundary Check
- [x] Each `.honeydrunk-review.yaml` and `pr-review.yml` lives in its own Node repo — correct ownership.
- [x] No cross-Node runtime dependency introduced; the reviewer is CI tooling.
- [x] Private revenue Nodes excluded from the default rollout per ADR-0044 Operational Consequences.

## Acceptance Criteria
- [ ] Each of the 10 .NET Node repos in `target_repos` (private revenue Nodes excluded) has a `.honeydrunk-review.yaml` with `enabled: true` at its repo root
- [ ] Each has a `pr-review.yml` caller invoking `job-review-agent.yml` at a pinned ref on `pull_request` opened/synchronize/ready_for_review
- [ ] Each repo's PR template carries the `Authorship:` line
- [ ] The cloud reviewer posts an advisory comment on a real or test PR in each enabled repo
- [ ] `HoneyDrunk.Observe`, `HoneyDrunk.Architecture`, and `HoneyDrunk.Studios` are NOT touched by this fan-out (Observe is Seed; Architecture is Phase-1; Studios is TypeScript)
- [ ] Any private revenue Node touched by the list is documented as excluded and left `enabled: false` / no file
- [ ] Each repo's `CHANGELOG.md` carries an entry noting cloud-review enablement (CI tooling change)

## Human Prerequisites
- [ ] The Phase-1 → Phase-2 go/no-go decision (from packet 06) must be a documented "go" before this packet is filed
- [ ] Confirm the pinned `job-review-agent.yml` ref for all 10 callers
- [ ] Confirm the list of private revenue Nodes to exclude (per ADR-0027 D2 / `catalogs/nodes.json`)
- [ ] Verify the Anthropic/GitHub-App secrets are available to each Node's CI surface (org-level secrets cover this if configured org-wide in packet 02)

## Dependencies
- `packet:06` — Phase-1 pilot + go/no-go (**hard** — Phase 2 does not start until Phase 1's exit criterion is met).
- `packet:07` — authorship/pr-size checks in `pr-core.yml` (**hard** — Phase 2 makes authorship classification mandatory; the checks must exist).
- `packet:08` — Grid-wide labels (**hard** — `large-pr` etc. must exist before `pr-size-check` runs in these repos).
- `packet:09` — D3 rubric in the upstream authoring agents (soft — agent PRs raised in these repos should be authored against the same rubric the reviewer evaluates; the upstream-authoring discipline, not only the `Authorship:` line, should be live as the fan-out lands).
- `packet:10` — execution-surface authorship emitters (soft — agent PRs in these repos should declare `Authorship:` automatically once the emitters land).

## Referenced ADR Decisions

**ADR-0044 D11 Phase 2** — Rollout to the live Nodes; each opts in via `.honeydrunk-review.yaml` with `enabled: true`; authorship classification becomes mandatory; PR-size discipline activates with warnings only. (D11 says "all 12 live Nodes"; this packet covers the 10 not already enabled in Phase 1 — Architecture is the Phase-1 pilot, Studios is TypeScript and onboarded separately.)
**ADR-0044 D4** — `.honeydrunk-review.yaml` v1 schema and the enabled gate.
**ADR-0044 Operational Consequences** — Private revenue Nodes (per ADR-0027 D2) are excluded from the default v1 rollout and require explicit opt-in.

## Constraints
- **Phase 2 is gated on a documented Phase-1 "go".** Do not file this packet before the Phase-1 outcome is recorded.
- **Private revenue Nodes excluded by default.** Do not enable a `.Cloud` revenue Node as part of the default fan-out.
- **Advisory only.** Never make the review check required on any Node.
- **Pinned 10-repo list.** Do not add `HoneyDrunk.Observe` (Seed), `HoneyDrunk.Architecture` (Phase-1), or `HoneyDrunk.Studios` (TypeScript) to the fan-out.
- One small, identical work unit per repo — file as 10 issues or a tracking issue with 10 sub-tasks.

## Labels
`ci`, `tier-2`, `core`, `ops`, `coordination`, `adr-0044`, `wave-2`

## Agent Handoff

**Objective:** Enable the cloud reviewer on the 10 remaining live .NET Nodes — `.honeydrunk-review.yaml` (`enabled: true`) + `pr-review.yml` caller per repo. Exclude private revenue Nodes.

**Target:** Coordination/tracking issue in `HoneyDrunk.Architecture`, with one child issue per Node repo; each child branches from `main` in its own repo.

**Context:**
- Goal: Phase-2 fan-out after the Phase-1 pilot proves the reviewer.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 2.
- ADRs: ADR-0044 (D11 Phase 2, D4, Operational Consequences), ADR-0027 (private revenue Node definition).
- In scope: the 10 .NET Node repos in `target_repos`. Out: Observe (Seed), Architecture (Phase-1), Studios (TypeScript).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:06` (hard), `packet:07` (hard), `packet:08` (hard), `packet:09` (soft), `packet:10` (soft).

**Constraints:**
- Gated on a documented Phase-1 "go".
- Private revenue Nodes excluded; advisory only.
- Pinned 10-repo list — do not add Observe, Architecture, or Studios.

**Key Files (per repo):**
- `.honeydrunk-review.yaml` (new, repo root)
- `.github/workflows/pr-review.yml` (new or extended)
- the repo PR template
- `CHANGELOG.md`

**Contracts:** Consumes `job-review-agent.yml` (`workflow_call`) and the `.honeydrunk-review.yaml` v1 schema.
