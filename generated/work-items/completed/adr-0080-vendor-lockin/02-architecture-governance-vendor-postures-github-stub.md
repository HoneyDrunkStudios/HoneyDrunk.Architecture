---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0080", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0080"]
wave: 2
initiative: adr-0080-vendor-lockin
node: honeydrunk-architecture
---

# Ship the GitHub exit-playbook stub in governance/vendor-postures/

## Summary
Ship `governance/vendor-postures/github.md` as the **stub** documenting GitHub's Accept (deep, intentional) posture: full intentional lock-in with no active hedge, the surfaces depended on (source, Actions, Projects, PR workflow, OpenClaw integration, per-Node CI), the honest exit-cost narrative (months), and — most importantly — the SCM-migration pre-condition framing per ADR-0080 D5. Per ADR-0080 D8, this is the structure-and-canonical-home packet; the full migration mechanics are deferred.

## Context
ADR-0080 D5 creates two stubs at acceptance — Azure (packet 01) and GitHub (this packet). GitHub is the second of two Accept (deep, intentional) posture vendors per ADR-0080 D2.

GitHub's posture is distinct from Azure's: ADR-0080 D2 names **no hedges in place** for GitHub. The "Specific hedges in place" column for GitHub in ADR-0080 D2 reads literally: *"None. Full lock-in is the correct posture; GitHub is the substrate for the operator's solo-dev workflow and the SDLC depends on its specific affordances."* That framing — full lock-in as the correct posture — is the stub's load-bearing message. The SCM-migration **pre-condition** is *another SCM with equivalent affordances for solo-dev + AI-agent SDLC*, not "GitLab can host the source." ADR-0080 D5 makes that distinction explicit.

The GitHub surfaces the Grid currently depends on, per ADR-0080 D2:

- Source (every Node's repository)
- GitHub Actions (every Node's CI/CD pipeline, the `HoneyDrunk.Actions` reusable-workflow library per ADR-0012)
- GitHub Projects (The Hive — org Project #4 per ADR-0008)
- PR workflow (the cloud-wired review agent per ADR-0044, advisory comments via OpenClaw)
- OpenClaw integration (Signed webhook receipt, advisory PR comments)
- Per-repo CI (`pr-core.yml` reusable workflow as branch-protection gate per ADR-0011/ADR-0012)

The exit cost is honestly **months**, not weeks. A full SCM migration requires porting source, PR history, Actions, the project board, OpenClaw integration, and the per-Node CI surface to another SCM platform — and the per-Node CI surface alone is non-trivial because every Node depends on the `HoneyDrunk.Actions` reusable-workflow contract (per ADR-0012's invariants 34–36 and the broader Actions control-plane decision).

**This is a stub at acceptance.** Same framing as packet 01: ADR-0080 D8 explicitly defers full content to a follow-up packet. The stub commits the surfaces, the posture, the SCM-migration pre-condition framing, and the exit-cost range; the per-surface migration mechanics are out of scope.

This is a docs/governance packet. No code, no .NET project.

## Scope
- Create file `governance/vendor-postures/github.md` with the stub structure described in Proposed Implementation.

## Proposed Implementation
1. The `governance/vendor-postures/` directory must already exist from packet 01. If it does not, this packet cannot proceed — stop and flag.
2. Create `governance/vendor-postures/github.md` with the following stub structure:

   ```markdown
   # GitHub — Vendor Posture: Accept (deep, intentional)

   **Posture:** Accept (deep, intentional) per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2.
   **Last reviewed:** 2026-05-24 (initiative `adr-0080-vendor-lockin` packet 02).
   **Status:** Stub. Full migration mechanics deferred per ADR-0080 D8.

   ## Surfaces

   The Grid depends on GitHub across the following surfaces. **No hedges are in place by design** — per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2, full lock-in is the correct posture for GitHub: it is the substrate for the operator's solo-dev workflow and the SDLC depends on its specific affordances.

   | Surface | Source ADR(s) | Lock-in shape | Estimated exit cost |
   |---|---|---|---|
   | Source (every Node's repository) | — (substrate) | Every Grid repo lives on GitHub. Branch protection, repo settings, secret scanning, Dependabot alerts (per [ADR-0009](../../adrs/ADR-0009-package-scanning-policy.md)), CODEOWNERS, repo-level governance all encoded as GitHub-native settings. | Months. Mirror the source tree to another SCM; port branch-protection equivalents; reconcile commit-author identities. |
   | GitHub Actions (CI/CD) | [ADR-0012](../../adrs/ADR-0012-grid-cicd-control-plane.md) | `HoneyDrunk.Actions` is the canonical CI/CD control plane per [ADR-0012](../../adrs/ADR-0012-grid-cicd-control-plane.md). Every Node consumes its reusable workflows (`pr-core.yml`, the `job-*` library); per-Node `.github/workflows/*.yml` calls them. The Actions invariants (34, 35, 36 per [ADR-0015](../../adrs/ADR-0015-container-hosting-platform.md)) reference Actions semantics directly. | Months. Re-author every reusable workflow in the target CI platform's primitives (GitLab CI, Buildkite, etc.); rewire OIDC federation for Azure deploy per [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md). |
   | GitHub Projects (The Hive) | [ADR-0008](../../adrs/ADR-0008-work-tracking-and-execution-flow.md), [ADR-0014](../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) | The Hive (org Project #4) is the source of truth for in-flight work per [ADR-0008](../../adrs/ADR-0008-work-tracking-and-execution-flow.md); `hive-sync` reconciles Architecture-repo state against it per [ADR-0014](../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md). The `file-work-items.yml` workflow files issues + sets board fields + wires `addBlockedBy` automatically. | Weeks-to-months. Replicate the board schema (custom fields: Status, Wave, Node, Tier, Actor, Initiative, ADR) in the target tool; re-author `file-work-items.yml` and `hive-sync` against the target's API; migrate historical packets and their issue references. |
   | PR workflow + cloud-wired review | [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), [ADR-0079](../../adrs/ADR-0079-multi-perspective-pr-review-stack.md) | `job-review-request.yml` triggers the OpenClaw-wired `.claude/agents/review.md` agent on every non-draft PR; review comments post via the GitHub API. The `.honeydrunk-review.yaml` per-repo opt-in lives in the repo per [invariant 52](../../constitution/invariants.md). | Weeks. Re-author the review-request trigger against the target's webhook/PR-comment API; preserve the OpenClaw agent definition (it is SCM-independent). |
   | OpenClaw integration | [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), reference doc `repos/OpenClaw/` (if present in the workspace) | OpenClaw subscribes to GitHub webhooks, posts advisory comments, runs the review agent under a managed-Chromium subscription model. The integration shape is GitHub-native (webhook signature, PR-comment API, repo-permission model). | Weeks. Re-author the OpenClaw integration against the target's webhook signature and PR-comment API; the agent definition is preserved. |
   | Per-repo CI (branch-protection gate) | [ADR-0011](../../adrs/ADR-0011-code-review-and-merge-flow.md) (Proposed), [ADR-0012](../../adrs/ADR-0012-grid-cicd-control-plane.md) | Branch protection on `main` requires the tier-1 gate (`pr-core.yml`) per ADR-0011 D2 (Proposed) — the GitHub-native branch-protection rule plus required-status-check semantics is the substrate. The contract is GitHub-native (required status checks, admin override semantics). | Weeks per repo. Re-encode branch-protection rules in the target's primitives; preserve the gate's substantive content. |

   **Total estimated exit cost (all surfaces):** months. An SCM migration is not a weekend project — it is its own multi-month initiative under the standard Grid SDLC, scoped only after a D4 trigger fires and the re-evaluation conversation produces "Exit."

   ## Why Accept (deep, intentional) — and why no hedges

   See [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2's GitHub row explicitly:

   > **None. Full lock-in is the correct posture; GitHub is the substrate for the operator's solo-dev workflow and the SDLC depends on its specific affordances.**

   The reasoning, made explicit:

   1. **The SDLC depends on GitHub-native affordances.** Branch protection semantics, required status checks, the GraphQL Projects API (and its blockedBy edges), Actions matrix concurrency, OIDC federation to Azure per [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md), the Repo permission model, CODEOWNERS, secret scanning, Dependabot alerts per [ADR-0009](../../adrs/ADR-0009-package-scanning-policy.md). Hedging would mean abstracting every one of those over a portable layer — a permanent tax against a hypothetical migration.
   2. **Per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) Alternatives Considered:** "Pure abstraction discipline (vendor-agnostic everywhere)" was considered and rejected. The abstractions are the **code-level** vendor-exit posture; the posture document captures what the abstractions alone cannot.
   3. **Solo-dev + AI-agent SDLC is the operator's posture.** The OpenClaw integration, the `file-work-items.yml` automation, the `hive-sync` reconciliation, the cloud-wired review agent — these are all built against GitHub's specific shape. Re-architecting them against a portability layer would erode the AI-multiplier discipline the charter explicitly underwrites.

   ## The SCM-Migration Pre-Condition

   Per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D5 explicitly:

   > The SCM-migration pre-condition is *another SCM with equivalent affordances for solo-dev + AI-agent SDLC* — not "GitLab can host the source," but the full workflow story.

   "Equivalent affordances" means, at minimum:

   - Reusable-workflow library equivalence (the target supports composable CI workflows with the same primitive set as `pr-core.yml` / `job-*.yml`).
   - Project-board equivalence with the custom-field schema The Hive uses (Status, Wave, Node, Tier, Actor, Initiative, ADR) and an automation API matching what `file-work-items.yml` and `hive-sync` consume.
   - Webhook signature + PR-comment API equivalence sufficient for OpenClaw integration.
   - OIDC federation to Azure equivalence (or another mechanism that preserves the no-stored-secret deploy posture per [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md)).
   - Branch-protection-rule equivalence supporting required status checks and admin-override semantics.

   No target SCM today fully matches this pre-condition for the Grid's specific solo-dev + AI-agent shape. That is the **honest** state, not a marketing claim.

   ## Decision-Point Triggers

   The triggers in [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D4 apply to GitHub as to every Accept-posture vendor:

   - Deprecation or material price increase on a depended-on surface (e.g., a change to the Actions pricing model that crosses the cost-governance threshold per [ADR-0052](../../adrs/ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)).
   - Sustained reliability problems — two or more incidents exceeding one hour of impact within a single calendar quarter on a depended-on surface (handoff to [ADR-0054](../../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md)).
   - Terms change conflicts with charter — e.g., new restrictions on commercial use, mandatory data-residency conflicts, or license-change patterns that conflict with the Grid's build-in-public stance per [ADR-0039](../../adrs/ADR-0039-grid-open-source-license-policy.md).
   - Mature alternative emerges and matures for twelve or more months — the pre-condition above is the bar.
   - Adjacent Grid decision changes the math — e.g., a future ADR that adopts a fundamentally different SDLC model.
   - Vendor acquisition / corporate event — Microsoft's ownership of GitHub itself is the existing context; subsequent strategic shifts are the trigger.

   A trigger fires the **conversation**, not the migration.

   ## Reviewed-and-Held Concerns

   *None at acceptance. This section logs decision-point trigger observations that were reviewed and the assessment was "stay" or "hedge harder." Empty until the first review event occurs.*

   ## Pending Migration Mechanics

   Per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D8, the concrete per-surface migration mechanics — the specific steps for moving source, Actions, Projects, OpenClaw, and per-repo CI to a named replacement — are deferred until a real trigger fires and the re-evaluation conversation produces "Exit." This stub commits the structure, the SCM-migration pre-condition, and the honest cost range; the per-surface mechanics are filled in at the migration's own initiative.

   ## Source ADRs

   - [ADR-0008](../../adrs/ADR-0008-work-tracking-and-execution-flow.md) — Work tracking, The Hive
   - [ADR-0011](../../adrs/ADR-0011-code-review-and-merge-flow.md) — Code review and merge flow (tier-1 gate)
   - [ADR-0012](../../adrs/ADR-0012-grid-cicd-control-plane.md) — HoneyDrunk.Actions as Grid CI/CD control plane
   - [ADR-0014](../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) — Hive-Architecture reconciliation agent
   - [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — Grid-aware cloud code review
   - [ADR-0079](../../adrs/ADR-0079-multi-perspective-pr-review-stack.md) — Multi-perspective PR review stack
   - [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) — vendor posture umbrella (this file's authorizing ADR)
   ```

3. Verify relative-path resolution against the convention packet 01 established. Both files live at `governance/vendor-postures/{name}.md` (two directories deep); ADR cross-links use `../../adrs/{ADR-file}`.

4. Do **not** create any other file in this packet. Packet 03 handles the ADR-0076/0077/0078 cross-link footnotes.

## Affected Files
- `governance/vendor-postures/github.md` (new file)

## NuGet Dependencies
None. This packet creates one new Markdown file; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `governance/vendor-postures/github.md` exists with the stub structure from Proposed Implementation: header (posture/last-reviewed/status), Surfaces table covering all six GitHub surfaces (source, Actions, Projects, PR workflow + cloud-wired review, OpenClaw integration, per-repo CI) with source-ADR cite + lock-in shape + estimated-exit-cost per row, Why Accept reasoning (no hedges by design), SCM-Migration Pre-Condition framing, Decision-Point Triggers (the six from ADR-0080 D4), Reviewed-and-Held Concerns (empty placeholder), Pending Migration Mechanics note, Source ADRs reference list
- [ ] The "no hedges by design" framing is explicit in the Why Accept section — quoting ADR-0080 D2's "None. Full lock-in is the correct posture..." text
- [ ] The SCM-Migration Pre-Condition section names the five equivalence requirements (reusable workflows, project board with The Hive's custom-field schema, webhook + PR-comment API for OpenClaw, OIDC federation to Azure, branch-protection equivalence) and the honest "no target SCM today fully matches" statement
- [ ] All ADR cross-link relative paths resolve from `governance/vendor-postures/github.md` (two directories deep — `../../adrs/...`)
- [ ] The file is explicitly named a **stub** in the Status line and the Pending Migration Mechanics note — full mechanics deferred per ADR-0080 D8
- [ ] The `governance/vendor-postures/` directory already exists (from packet 01); this packet does not re-create it
- [ ] No edits to ADR-0076, ADR-0077, ADR-0078, or any other ADR file (cross-link footnotes land in packet 03)
- [ ] No edits to `constitution/invariants.md` (invariants land in packet 00)
- [ ] No edits to `catalogs/*.json` (no catalog packet in this initiative)
- [ ] No edits to `governance/vendor-postures/azure.md` (packet 01's content is preserved)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0080 D5 — Per-vendor exit-playbook stubs.** GitHub is one of two Accept (deep, intentional) vendors. The stub documents that lock-in is full and intentional; names the surfaces (source, Actions, Projects, OpenClaw, per-repo CI) and the migration cost; explicitly notes that the SCM-migration pre-condition is *another SCM with equivalent affordances for solo-dev + AI-agent SDLC* — not "GitLab can host the source," but the full workflow story.

**ADR-0080 D2 — GitHub posture: Accept (deep, intentional) with "None" in the hedges column.** The literal text from ADR-0080 D2: "None. Full lock-in is the correct posture; GitHub is the substrate for the operator's solo-dev workflow and the SDLC depends on its specific affordances." Estimated exit cost: "Months. A full SCM migration would require porting source, PR history, Actions, project board, OpenClaw integration, and the per-Node CI surface."

**ADR-0080 D4 — Decision-point triggers.** Apply to GitHub the same as to every Accept-posture vendor.

**ADR-0080 D8 — Out of scope.** "The full content of the per-vendor governance files (D5). The stubs are created with this ADR; the full content is a follow-up packet."

**Invariant 89 (added by packet 00, referenced here) — "Accept (deep, intentional)" posture vendors have a per-vendor governance file under `governance/vendor-postures/{vendor}.md`.**

## Constraints
- **Stub, not full content.** The file is explicitly a stub per ADR-0080 D8. Do not invent per-surface migration mechanics that ADR-0080 does not author.
- **"No hedges by design" is the load-bearing message.** This is not an oversight to be quietly corrected. ADR-0080 D2 explicitly assigns GitHub the "None" hedges value because the SDLC depends on GitHub's specific affordances. The stub must carry that framing intact, not soften it.
- **The SCM-migration pre-condition is not negotiable.** ADR-0080 D5 names the pre-condition explicitly: *not "GitLab can host the source," but the full workflow story*. The stub names the five equivalence requirements (reusable-workflow library, project-board schema, webhook+PR-comment API, OIDC federation, branch-protection rules) and states honestly that no current target meets the bar.
- **Match the file structure established in packet 01.** Same section headers (Surfaces / Why Accept / Decision-Point Triggers / Reviewed-and-Held Concerns / Pending — with the section title varied for GitHub's distinct framing / Source ADRs); same relative-path convention.
- **Packet 01 must merge first.** The directory `governance/vendor-postures/` is created by packet 01; this packet adds the GitHub file alongside the Azure file. If packet 01 has not landed, stop and flag.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0080`, `wave-2`

## Agent Handoff

**Objective:** Ship `governance/vendor-postures/github.md` as the stub for GitHub's Accept (deep, intentional) posture per ADR-0080 D5.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Complete the second of two Accept-posture vendor stubs, with explicit "no hedges by design" framing and the SCM-migration pre-condition.
- Feature: ADR-0080 Vendor Lock-In Posture rollout, Wave 2.
- ADRs: ADR-0080 D2/D5 (primary — GitHub posture and stub structure), ADR-0080 D4 (triggers), ADR-0080 D8 (stub-vs-full scoping). Source ADRs for each GitHub surface: ADR-0008, ADR-0011, ADR-0012, ADR-0014, ADR-0044, ADR-0079.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — `governance/vendor-postures/` directory must exist; the Azure stub establishes the file structure and relative-path convention.

**Constraints:**
- "No hedges by design" framing is load-bearing — preserve ADR-0080 D2's exact stance.
- The SCM-migration pre-condition (the five equivalence requirements) is the stub's distinguishing content.
- Stub only — full migration mechanics deferred per ADR-0080 D8.

**Key Files:**
- `governance/vendor-postures/github.md` (new)

**Contracts:** None changed.
