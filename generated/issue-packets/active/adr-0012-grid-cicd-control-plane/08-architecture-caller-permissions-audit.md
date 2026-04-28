---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "audit", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-architecture
---

# Audit: Caller-workflow `permissions:` audit across every Live + workflow-bearing Grid repo (D5)

## Summary
Audit every caller workflow across every Grid repo that calls a reusable workflow from `HoneyDrunk.Actions` against the canonical `permissions:` baselines documented in `HoneyDrunk.Actions/docs/consumer-usage.md` (per packet 05) and ADR-0012 D5. For every (repo, caller-workflow) pair, fetch the caller's top-level `permissions:` block via `gh api`, compare against the canonical baseline, and record the result in `infrastructure/caller-permissions-audit.md`. For any caller that omits `permissions:` or grants less than the callee needs, file a per-repo follow-up packet to fix it. The audit doc lands in Architecture as a single artifact; the per-repo fixes (if any) land as small chore packets in their respective repos.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0012's triggering incident was, in part, "Caller-workflow permission mismatches in seven places across six repos." Per the ADR's Unresolved Consequences Gap 3: "the seven broken callers found during the triggering incident are fixed... No automated check verifies that a new caller added after today will match the invariant." The grid-health aggregator (packet 04) catches the runtime symptom; this audit catches the static symptom and produces a baseline so future drift is visible.

The audit lives in Architecture (not Actions) because:
- The artifact is cross-repo evidence — every Grid repo's caller workflow's status, in one place.
- Architecture is the source of truth for cross-repo state per ADR-0002.
- Per-repo fixes (if any) land in the affected repos as small follow-up packets, not bundled here.

## Proposed Implementation

### `infrastructure/caller-permissions-audit.md` (new)

Structure:

1. **Purpose.** One paragraph explaining the audit, its trigger (ADR-0012 D5 / Gap 3), and its cadence (one-time today; re-audit when grid-health surfaces new drift or when a new repo is added).

2. **Method.** Short paragraph documenting the audit procedure:
   - For every Live + workflow-bearing Grid repo (the set enumerated below at scope-time; verify at execution time), enumerate caller workflows under `.github/workflows/*.yml` that contain a `uses: HoneyDrunkStudios/HoneyDrunk.Actions/...` reference.
   - For each caller, fetch the file via `gh api repos/HoneyDrunkStudios/<repo>/contents/.github/workflows/<filename>` (or `git clone` and read locally).
   - Extract the top-level `permissions:` block (NOT the per-job `permissions:` blocks — the top-level is what governs the `workflow_call` token scope).
   - Determine which reusable workflows the caller invokes.
   - Compare the caller's top-level block against the canonical baseline for those reusable workflows.

3. **Canonical baselines — single source of truth.** The audit doc does **not** copy the canonical permissions blocks inline. Instead it links out:

```markdown
The canonical caller-permissions baselines for every reusable workflow are defined in `HoneyDrunk.Actions/docs/consumer-usage.md` (per ADR-0012 D9). That document is the single source of truth; this audit compares each live caller's top-level `permissions:` block against the baseline declared there for the reusable workflow(s) the caller invokes.

Cross-link: [HoneyDrunk.Actions/docs/consumer-usage.md](https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/blob/main/docs/consumer-usage.md#caller-permissions--the-load-bearing-rule)

For workflows not yet documented in `consumer-usage.md` (release/publish, deploy variants, accessibility, governance), the audit derives the baseline from the callee's own `permissions:` declaration in `HoneyDrunk.Actions/.github/workflows/<callee>.yml` and notes the derivation per row. As `consumer-usage.md` is extended (a future small packet, not packet 05's scope), the audit's reference state shifts to the doc.
```

The audit doc records one or two permissions baselines inline as **examples** (showing the audit-table format, not as the canonical source) — typically `nightly-security.yml`'s and `pr-core.yml`'s blocks, since those are the most commonly-called reusable workflows. The doc text makes clear those examples are illustrative; the canonical baselines live in `consumer-usage.md`.

If `consumer-usage.md` has not landed at audit time (i.e. packet 05 is still in flight), the audit notes the dependency in its conclusion: "Canonical baselines link to `consumer-usage.md` (packet 05). At audit time this doc reflected the pre-05 state; comparison was done against ADR-0012 D5 directly. Re-verify after packet 05 merges if any baseline shifts." The point is that the audit's reference state is **a link**, not **inline copies that go stale**.

4. **Audit table.** Columns:
   - **Repo**
   - **Caller workflow file** (e.g. `pr.yml`, `nightly-security.yml`, `release.yml`)
   - **Reusable workflow(s) called** (one or more)
   - **Top-level `permissions:` block** (literal copy or `(missing)`)
   - **Expected superset** (the canonical baseline for the called workflows, unioned)
   - **Status** — one of:
     - `✅ Pass` — caller's block is a superset of the expected.
     - `⚠️ Over-granted` — caller's block grants scopes not needed (least-privilege violation, Suggest-grade in review terminology).
     - `❌ Under-granted` — caller's block is missing scopes the callee needs (broken at workflow-load time).
     - `❌ Missing` — caller has no top-level `permissions:` block.
   - **Follow-up issue** — link to the per-repo fix packet if Status is non-Pass; empty for Pass.

5. **Per-repo fix follow-ups.** A subsection listing every per-repo follow-up packet filed during this audit. Each follow-up is a small chore packet in the affected repo, with body specifying exactly which workflow file to edit and the canonical block to insert. Filed packets are linked here.

6. **Conclusion.** One paragraph summarizing the audit:
   - Total callers audited.
   - Pass / Over-granted / Under-granted / Missing counts.
   - List of follow-up packets filed.
   - Re-audit trigger (when this audit should run again).

7. **Re-audit cadence.** A short note: "This audit is one-time. Future drift is caught by (a) the grid-health aggregator's Stale classification when a workflow-load failure prevents a scheduled run, and (b) the review agent's Request Changes rule for new caller workflows. A repeat audit is filed only if either signal misses a real defect."

8. **Cross-references.** Invariant 39, ADR-0012 D5, ADR-0012 Gap 3, and packet 05 (consumer-usage refresh).

### Repos to audit

Every Grid repo whose `.github/workflows/` contains at least one caller workflow with a `uses: HoneyDrunkStudios/HoneyDrunk.Actions/...` reference. At scope-time (2026-04-26), the verified set is:

- HoneyDrunk.Kernel — has `pr.yml`, `publish.yml`, `nightly-security.yml`, `weekly-deps.yml`, `hive-field-mirror.yml`
- HoneyDrunk.Transport — same shape as Kernel
- HoneyDrunk.Vault — same shape as Kernel
- HoneyDrunk.Auth — same shape as Kernel
- HoneyDrunk.Web.Rest — same shape as Kernel
- HoneyDrunk.Data — same shape as Kernel plus `nightly-deps.yml` (transitional)
- HoneyDrunk.Pulse — Kernel-shape plus `deploy.yml`
- HoneyDrunk.Notify — Kernel-shape plus `deploy-functions.yml`
- HoneyDrunk.Vault.Rotation — has `deploy.yml`, `publish.yml`, `validate-pr.yml` (no `nightly-security.yml`/`weekly-deps.yml` yet — audit only what exists)
- HoneyDrunk.Communications — skip; repo not yet scaffolded.
- HoneyDrunk.Studios — `.github/workflows/` is empty at scope-time. If any TypeScript-side caller workflow has been added before this packet ships (e.g. consuming `nightly-accessibility.yml` from Actions), audit it. Otherwise, note "deferred — no callers at execution time."

**Verify the set at execution time.** Drift between scope-time and execution is expected — Communications may be scaffolded, Studios may have added a caller, Vault.Rotation may have added `nightly-security.yml`. The mandate is "audit every caller across every Live + workflow-bearing repo," not "audit a fixed eleven-repo list."

`HoneyDrunk.Architecture` and `HoneyDrunk.Actions` are excluded from the comparison side:
- Architecture's `.github/workflows/` contains `file-packets.yml` and `initiatives-sync.yml` — neither calls a HoneyDrunk.Actions reusable workflow today. If a future Architecture caller is added, include it in a re-audit.
- Actions hosts the reusable workflows; if it has its own caller workflows (e.g. `actions-ci.yml` calling `pr-core.yml` for self-test), audit those — include in the table — but framed as Actions-self-test rather than Grid-consumer.

### Per-repo fix packets (if any)

For every `❌ Under-granted` or `❌ Missing` row in the audit table, file a small per-repo packet titled:

> `chore: Add canonical permissions: block to <workflow-filename>`

Body specifies the exact YAML to insert at the top level of the caller workflow, the canonical baseline source (link to consumer-usage.md), and acceptance criteria of "after this PR merges, the next scheduled run produces a green run on the Actions tab."

These per-repo packets are filed BUT not executed in this packet — they file as separate GitHub issues against the affected repos, are tracked on the project board, and are picked up by Codex Cloud on their own. The audit doc links each filed issue.

If the audit finds zero violations, the per-repo follow-up section is "None — all callers compliant" and no follow-up packets are filed.

### `infrastructure/README.md`

Add a row for `caller-permissions-audit.md` to the existing index.

### Architecture `CHANGELOG.md`

Append entry referencing ADR-0012 D5 and this audit.

## Affected Files
- `infrastructure/caller-permissions-audit.md` (new)
- `infrastructure/README.md` (index update)
- `CHANGELOG.md` (Architecture repo root)
- Plus: zero or more per-repo follow-up packets filed as GitHub issues (not files in this repo)

## NuGet Dependencies
None.

## Boundary Check
- [x] Architecture-only file edits in this packet.
- [x] Per-repo fix packets are filed as GitHub issues, not committed as files in Architecture (per ADR-0008 — issues live where the code lives).
- [x] No workflow YAML edits in this packet (those happen in the per-repo follow-up packets).

## Acceptance Criteria
- [ ] `infrastructure/caller-permissions-audit.md` exists with the eight sections specified.
- [ ] The audit table covers every (repo, caller-workflow) pair across every workflow-bearing Grid repo whose `.github/workflows/` contains at least one `uses: HoneyDrunkStudios/HoneyDrunk.Actions/...` reference at execution time. Skipped repos (not-yet-scaffolded, or scaffolded but with no HoneyDrunk.Actions callers) are explicitly listed in the conclusion as "deferred — no callers at execution time."
- [ ] Each row's Status is exactly one of the four values (`✅ Pass`, `⚠️ Over-granted`, `❌ Under-granted`, `❌ Missing`).
- [ ] For every `❌ Under-granted` and `❌ Missing` row, a per-repo follow-up packet is filed as a GitHub issue, and the issue link is in the table's "Follow-up issue" column.
- [ ] The conclusion section states the four-state count and the list of follow-up packets.
- [ ] `infrastructure/README.md` references the new audit doc.
- [ ] Repo-level `CHANGELOG.md` updated.
- [ ] If zero violations are found, the conclusion explicitly states "All callers compliant; no follow-up packets filed" and the per-repo follow-ups section reads "None."

## Human Prerequisites
- [ ] **`gh` CLI authentication** sufficient to read every Grid repo's workflow files. Public repos are readable without auth; private repos require auth scope. The agent has `gh` available in cloud execution but may need a fine-grained PAT for any private repos in scope. Per the user's "repos public by default" convention, most Grid repos are public — the operator confirms or provides a PAT if any are private.
- [ ] **Optional re-trigger** — for any caller flagged as `❌ Under-granted` or `❌ Missing`, the operator may want to trigger a `workflow_dispatch` after the per-repo fix packet's PR merges to confirm the workflow now loads cleanly. The audit doc notes this as the verification step.

## Referenced Invariants

> **Invariant 39 (post-acceptance numbering — see packet 01):** Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. Callers that omit `permissions:` inherit the repository default, which is insufficient for any reusable workflow that requests a `write` scope. Validation failure is not detected until the next scheduled run; grid-health (invariant 40) is the safety net. See ADR-0012 D5.

The audit produces the baseline state for invariant 39 enforcement.

## Referenced ADR Decisions

**ADR-0012 D5 (Caller workflows declare a `permissions:` block):** Source of the canonical baselines.

**ADR-0012 Gap 3 (Caller-workflow permissions audit is manual):** "The seven broken callers found during the triggering incident are fixed. ... No automated check verifies that a new caller added after today will match the invariant. ... Priority: low. Grid growth rate is slow enough that the scaffold-from-runbook pattern (D9) plus the grid-health safety net (D6) is sufficient. Revisit if a second broken caller appears post-fix." The audit captures the today-state; future drift is caught by D6's grid-health Stale classification.

**ADR-0008 (Issues live where the code lives):** Per-repo fix packets are filed as GitHub issues against the affected repos, not committed as files in Architecture.

## Dependencies
- Soft-blocked by packet 01 for invariant 39 numbering.
- Soft-blocked by packet 05 for canonical baselines (the audit can use D5 directly if 05 has not merged; preferable to wait for 05 if both are in flight).

## Labels
`chore`, `tier-2`, `meta`, `docs`, `audit`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Produce the cross-repo caller-permissions audit baseline so invariant 39 has a known starting state.
**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: Land the audit artifact and file any per-repo fix follow-ups so the entire workflow-bearing-repo caller surface is known-good.
- Feature: ADR-0012 Grid CI/CD Control Plane, D5 enforcement / Gap 3 closure.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packets 01 and 05.

**Constraints:**
- **Invariant 39 (post-acceptance):** The canonical baselines are the comparison reference. Use packet 05's `consumer-usage.md` if it has merged; otherwise use ADR-0012 D5 directly. Do not invent new baselines.
- **Per-repo fix packets file as GitHub issues, not committed files** (ADR-0008). The audit doc records the filed issues' links. If `gh issue create` fails for a repo (permissions, etc.), the audit doc records the intended packet body verbatim and flags the operator to file manually.
- **No workflow YAML edits in this packet.** Migrations happen in per-repo packets, executed separately by Codex Cloud against each affected repo.
- **`HoneyDrunkStudios/HoneyDrunk.Architecture` is excluded from the comparison side** but `HoneyDrunkStudios/HoneyDrunk.Actions` self-test workflows (if any call `pr-core.yml` against itself) are audited and listed in the table separately.

**Key Files:**
- `infrastructure/oidc-federated-credentials.md` — style reference (existing infrastructure walkthrough/audit doc).
- `HoneyDrunk.Actions/docs/consumer-usage.md` — canonical baselines source (after packet 05 lands).
- `adrs/ADR-0012-grid-cicd-control-plane.md` D5 — fallback canonical baselines source.
- Every Live + workflow-bearing Grid repo's `.github/workflows/*.yml` files — read-only audit targets.

**Contracts:** No code or schema contracts. The audit doc shape is its own contract — future re-audits compare against the prior table.
