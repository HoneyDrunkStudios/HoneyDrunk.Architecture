---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
target_repos: ["HoneyDrunk.Kernel", "HoneyDrunk.Transport", "HoneyDrunk.Vault", "HoneyDrunk.Auth", "HoneyDrunk.Web.Rest", "HoneyDrunk.Data", "HoneyDrunk.Notify", "HoneyDrunk.Communications", "HoneyDrunk.Pulse", "HoneyDrunk.Actions"]
labels: ["ci", "tier-2", "core", "ops", "coordination", "adr-0086", "wave-2"]
dependencies: ["packet:07", "packet:08"]
adrs: ["ADR-0086", "ADR-0044"]
accepts: []
wave: 2
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Enable runner: local-worker on the 10 remaining live .NET Nodes (Phase B fan-out, supersedes ADR-0044 packet 11)

## Summary
Roll the pull-based local-worker reviewer out to the 10 remaining live .NET Nodes — Kernel, Transport, Vault, Auth, Web.Rest, Data (Core); Notify, Communications, Pulse, Actions (Ops) — by authoring (or updating) a `.honeydrunk-review.yaml` (`enabled: true`, `runner: local-worker`) and a `.github/workflows/pr-review.yml` caller in each. **This packet supersedes ADR-0044 Architecture#182 (packet 11 of the ADR-0044 initiative)**, which was still pending at the time ADR-0086 was authored and which would have shipped `runner: openclaw-codex` — now removed from the schema by ADR-0086 D5. Filed as a coordination/tracking issue in `HoneyDrunk.Architecture` with one child issue per Node repo.

## Supersession of ADR-0044 packet 11
ADR-0044 packet 11 (Architecture#182) was the Phase-2 fan-out under the old OpenClaw transport. At the time ADR-0086 was authored, Architecture#182 was still open — no Node beyond Architecture had been opted in. ADR-0086 D11 Phase B says: "Enable on the other repos that ADR-0044's Phase 2 had reached. Each repo's `.honeydrunk-review.yaml` migrates from `runner: openclaw-codex` to `runner: local-worker`." Since no migration is actually needed (no repo carries `openclaw-codex` today), the cleanest path is: close ADR-0044 Architecture#182 as superseded, and file this packet at the new default (`runner: local-worker`) from the start.

ADR-0086 packet 01 (acceptance) marks Architecture#182 as superseded in `initiatives/active-initiatives.md` with a pointer to this packet. Filing this packet at the new default avoids a two-step (open-at-old-default-then-migrate) that would burn 10 PRs unnecessarily.

## Repo-list reconciliation (read this before filing)
ADR-0086 D11 Phase C names "all 12 live Nodes" as the eventual full-Grid target. The Grid has exactly 12 live Nodes per `catalogs/grid-health.json` (`signal: "Live"`): Kernel, Transport, Vault, Data, Web.Rest, Auth (Core); Notify, Communications, Pulse, Actions (Ops); Architecture, Studios (Meta).

Phase B's scope is the 12 minus two:
- **`HoneyDrunk.Architecture`** — already enabled in Phase A (packet 07). Not re-enabled here.
- **`HoneyDrunk.Studios`** — a TypeScript/Next.js repo, not a .NET Node; its onboarding is a separately scoped follow-up (matches the ADR-0044 packet 11 carve-out). Not part of this .NET-shaped fan-out.

That leaves **exactly 10 .NET Node repos** in scope, enumerated in `target_repos` above. **`HoneyDrunk.Observe` is explicitly OUT** — it carries `signal: "Seed"` in `catalogs/grid-health.json` (scaffolded but not a live Node). **`HoneyDrunk.Vault.Rotation` is OUT** — its CI shape is non-canonical (uses `validate-pr.yml` instead of `pr.yml`) per the ADR-0011 onboarding notes; onboard when its CI conforms to the Grid convention. **`HoneyDrunk.Lore`, `HoneyDrunk.Standards` are OUT** — docs/analyzer pack, no application code. **`HoneyDrunk.AI`, `HoneyDrunk.Capabilities`, `HoneyDrunk.Agents`, `HoneyDrunk.Memory`, `HoneyDrunk.Knowledge`, `HoneyDrunk.Flow`, `HoneyDrunk.Operator`, `HoneyDrunk.Audit`** are OUT — Seed Nodes with no live .NET application code yet; some may be enabled in Phase C if/when they go Live.

## Per-repo work unit (repeated for each of the 10 Node repos)
For each Node repo, in a single PR per repo (one-PR-per-repo-per-initiative discipline):

1. **Author or update `.honeydrunk-review.yaml`** at the repo root with:
   ```yaml
   enabled: true
   severity_floor: Suggest
   skip_paths:
     - "**/*.Designer.cs"
     - "**/*.g.cs"
     - "**/generated/**"
   runner: local-worker
   ```
   Tune `skip_paths` for the specific repo (e.g., add Functions auto-generated host files for Notify/Pulse; add EF migrations for Data if the operator chooses to exclude them). Use the worked example in `copilot/review-config-schema.md` (packet 04) as the reference.

2. **Author or update `.github/workflows/pr-review.yml`** to call `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-review-request.yml@<pinned-ref>` (the pinned ref bumps to whatever packet 05 landed at) on `pull_request` events `opened`, `synchronize`, `ready_for_review`. The caller's `permissions:` block must be:
   ```yaml
   permissions:
     contents: read
     pull-requests: write
     issues: write
   ```
   (per invariant 39 — superset of the rewritten reusable workflow's permissions).

3. **Verify the repo's PR template carries the `Authorship:` line** (already mandatory Grid-wide per ADR-0044 packet 07 / authorship-check). If missing, add it as part of this PR.

4. **Verify the worker labels and managed PR labels are present on the repo** — should already be true after packet 06's Grid-wide fan-out. If any are missing on a particular repo (rare; idempotent fan-out is robust), the rewritten Action's `gh label create --force` will create them at first use.

5. **CHANGELOG.md** in the repo carries an entry noting the local-worker review enablement (CI tooling change).

6. **Smoke test on the PR itself:** the PR enabling the worker is itself reviewed by the worker. Confirm in the PR body that the queue comment appears, the worker claims, the verdict posts, and labels transition correctly. If the smoke test fails on a particular repo, halt that repo's PR and diagnose against the worker (packet 03) or the workflow (packet 05); do not propagate the failure across the remaining 9 repos.

## Private revenue Nodes
ADR-0086 inherits ADR-0044's private-revenue-Node carve-out (ADR-0044 Operational Consequences): any `.Cloud` revenue Node is excluded from the default rollout. None of the 10 repos in `target_repos` is a `.Cloud` Node today; if any of them adopts a `.Cloud` shape later, this packet's `enabled: true` decision is revisited at that time. Recording for completeness; no action in this packet.

## Affected Files (per repo)
- `.honeydrunk-review.yaml` (repo root, new or in-place edit)
- `.github/workflows/pr-review.yml` (new or in-place edit)
- `.github/PULL_REQUEST_TEMPLATE.md` (if `Authorship:` line is missing — likely not)
- `CHANGELOG.md` (per repo)

## NuGet Dependencies
None. YAML config + caller workflow per repo; no .NET project or `csproj` changes.

## Boundary Check
- [x] Each `.honeydrunk-review.yaml` and `pr-review.yml` lives in its own Node repo — correct ownership.
- [x] No cross-Node runtime dependency introduced; the reviewer is CI tooling.
- [x] `HoneyDrunk.Architecture` excluded (Phase A pilot, already enabled).
- [x] `HoneyDrunk.Studios` excluded (TypeScript repo, separately scoped).
- [x] `HoneyDrunk.Observe` excluded (Seed Node).
- [x] `HoneyDrunk.Vault.Rotation` excluded (non-canonical CI shape; onboard later).
- [x] Seed AI-sector and library Nodes excluded.

## Acceptance Criteria
- [ ] Each of the 10 .NET Node repos in `target_repos` has a `.honeydrunk-review.yaml` with `enabled: true` and `runner: local-worker` at its repo root
- [ ] Each has a `pr-review.yml` caller invoking `job-review-request.yml` at a pinned ref on `pull_request` `opened`/`synchronize`/`ready_for_review`
- [ ] Each caller declares `permissions: { contents: read, pull-requests: write, issues: write }` per invariant 39
- [ ] Each repo's PR template carries the `Authorship:` line
- [ ] On each repo's enablement PR, the pull-based local worker posts an advisory verdict comment and the labels transition (queue → claim → terminal state); the smoke-test outcome is recorded in each PR body
- [ ] `HoneyDrunk.Observe`, `HoneyDrunk.Architecture`, `HoneyDrunk.Studios`, `HoneyDrunk.Vault.Rotation`, Seed Nodes, library Nodes are NOT touched by this fan-out
- [ ] Each repo's `CHANGELOG.md` carries an entry noting local-worker review enablement
- [ ] ADR-0044 Architecture#182 (the superseded fan-out) is closed as superseded by this packet's tracking issue in `HoneyDrunk.Architecture`
- [ ] `initiatives/active-initiatives.md` updates the ADR-0044 entry to mark Architecture#182 closed/superseded and the ADR-0086 entry to mark Phase B in progress

## Human Prerequisites
- [ ] Packet 07 (Phase-A cutover) and packet 08 (decommission) must be complete — Phase B cannot start until Phase A is green and OpenClaw decommissioning happened
- [ ] Confirm the pinned `job-review-request.yml` ref the per-repo callers invoke — this is the tag/SHA after packet 05 merged
- [ ] After this packet's tracking issue is filed, the 10 child issues can be tackled in parallel (one PR per repo); each PR's smoke test is the per-repo go decision
- [ ] If any repo's smoke test fails, halt that repo's PR and diagnose; do not propagate the failure across the remaining 9
- [ ] Close ADR-0044 Architecture#182 as superseded once this packet's tracking issue is filed; cross-link Architecture#182 to the new tracking issue for traceability

## Dependencies
- `packet:07` — Phase-A cutover (**hard** — Phase B does not start until Phase A is green).
- `packet:08` — OpenClaw decommission (**hard** — ADR-0086 D10 sequences the decommission before Phase B begins).

## Referenced ADR Decisions

**ADR-0086 D5** — `.honeydrunk-review.yaml` `runner:` enum: `local-worker` (default), `api-ci` (preserved), `openclaw-codex` (removed). Each Phase-B repo authors `runner: local-worker`.

**ADR-0086 D11 Phase B** — Enable on the other repos that ADR-0044's Phase 2 had reached. Each repo's `.honeydrunk-review.yaml` migrates from `runner: openclaw-codex` to `runner: local-worker`. The four new labels are added to each repo's label set via the existing label-setup pattern (already done Grid-wide in packet 06).

**ADR-0086 D11 Phase A → Phase B sequencing** — Each phase is a discrete go/no-go. Missing Phase A's bar pauses Phase B. The OpenClaw webhook bridge is decommissioned at Phase A → Phase B cutover per D10 — that's packet 08, which precedes this packet.

**ADR-0044 packet 11 (Architecture#182)** — Superseded by this packet. The same 10-Node target list; the `runner:` value flips from `openclaw-codex` to `local-worker` because no migration is needed (no repo had actually been opted in before ADR-0086 landed).

**Invariant 39 (ADR-0012 D5)** — Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's. The 10 per-repo callers all declare the widened block.

**ADR-0044 D6 (preserved)** — Authorship classification mandatory Grid-wide. The PR template's `Authorship:` line is required on every repo.

## Constraints
> **Invariant 31:** Every PR traverses the tier-1 gate before merge. The reviewer remains advisory; the per-repo caller's check is non-required.

> **Invariant 39:** Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. The widened block is required on every per-repo caller.

> **Invariant 52 (preserved from ADR-0044 with "requests" redefined by ADR-0086):** Every non-draft PR on an `enabled` repo lands in the GitHub-native queue and is processed by the local worker. Skip is via `skip-review` or `enabled: false`.

- **One PR per repo per initiative.** Discipline carried over from the operator's standing convention (memory-pinned). Each of the 10 repos gets one PR.
- **Advisory only.** Never make the review check required on any Node.
- **Phase A go is the precondition.** Do not start Phase B until packet 07's exit criteria are met.
- **OpenClaw decommission precedes Phase B.** Per ADR-0086 D10, packet 08 ships first.
- **Smoke test per repo.** Each repo's enablement PR is itself reviewed by the worker — the smoke-test outcome is recorded in the PR body.
- **Halt on per-repo failure.** Do not propagate a failed smoke test across the remaining repos; diagnose the specific repo first.
- **Private revenue Nodes excluded.** None of the 10 are `.Cloud` Nodes today; recorded for completeness.

## Labels
`ci`, `tier-2`, `core`, `ops`, `coordination`, `adr-0086`, `wave-2`

## Agent Handoff

**Objective:** Fan the pull-based local-worker reviewer out to the 10 remaining live .NET Nodes by authoring `.honeydrunk-review.yaml` (`runner: local-worker`) and a `pr-review.yml` caller in each. Smoke-test each enablement PR. Close ADR-0044 Architecture#182 as superseded.

**Target:** Tracking issue in `HoneyDrunk.Architecture`; 10 child issues, one per target_repo. Each child PR opens against `main` in its own Node repo.

**Context:**
- Goal: Phase B fan-out — every live .NET Node receives the pull-based local-worker review.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase B.
- ADRs: ADR-0086 (primary, D5/D11 Phase B), ADR-0044 (D6 authorship preserved; packet 11 superseded), ADR-0012 D5 / invariant 39.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:07` (hard), `packet:08` (hard).

**Constraints:**
- One PR per repo per initiative.
- Advisory only; never required.
- Phase A go is the precondition; OpenClaw decommission precedes Phase B.
- Smoke test per repo; halt on per-repo failure.
- `HoneyDrunk.Observe` / `HoneyDrunk.Architecture` / `HoneyDrunk.Studios` / `HoneyDrunk.Vault.Rotation` / Seed Nodes / library Nodes excluded.

**Key Files (per repo):**
- `.honeydrunk-review.yaml` (new or edit)
- `.github/workflows/pr-review.yml` (new or edit)
- `.github/PULL_REQUEST_TEMPLATE.md` (only if `Authorship:` missing)
- `CHANGELOG.md`

**Contracts:** Each repo's caller consumes `job-review-request.yml@<pinned-ref>` via `workflow_call`. The `.honeydrunk-review.yaml` v1 schema (packet 04) is the per-repo config.
