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
| GitHub Projects (The Hive) | [ADR-0008](../../adrs/ADR-0008-work-tracking-and-execution-flow.md), [ADR-0014](../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) | The Hive (org Project #4) is the source of truth for in-flight work per [ADR-0008](../../adrs/ADR-0008-work-tracking-and-execution-flow.md); `hive-sync` reconciles Architecture-repo state against it per [ADR-0014](../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md). The `file-packets.yml` workflow files issues + sets board fields + wires `addBlockedBy` automatically. | Weeks-to-months. Replicate the board schema (custom fields: Status, Wave, Node, Tier, Actor, Initiative, ADR) in the target tool; re-author `file-packets.yml` and `hive-sync` against the target's API; migrate historical packets and their issue references. |
| PR workflow + cloud-wired review | [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), [ADR-0079](../../adrs/ADR-0079-multi-perspective-pr-review-stack.md) | `job-review-request.yml` triggers the OpenClaw-wired `.claude/agents/review.md` agent on every non-draft PR; review comments post via the GitHub API. The `.honeydrunk-review.yaml` per-repo opt-in lives in the repo per [invariant 52](../../constitution/invariants.md). | Weeks. Re-author the review-request trigger against the target's webhook/PR-comment API; preserve the OpenClaw agent definition (it is SCM-independent). |
| OpenClaw integration | [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), reference doc `repos/OpenClaw/` (if present in the workspace) | OpenClaw subscribes to GitHub webhooks, posts advisory comments, runs the review agent under a managed-Chromium subscription model. The integration shape is GitHub-native (webhook signature, PR-comment API, repo-permission model). | Weeks. Re-author the OpenClaw integration against the target's webhook signature and PR-comment API; the agent definition is preserved. |
| Per-repo CI (branch-protection gate) | [ADR-0011](../../adrs/ADR-0011-code-review-and-merge-flow.md), [ADR-0012](../../adrs/ADR-0012-grid-cicd-control-plane.md) | Branch protection on `main` requires the tier-1 gate (`pr-core.yml`) per ADR-0011 D2 — the GitHub-native branch-protection rule plus required-status-check semantics is the substrate. The contract is GitHub-native (required status checks, admin override semantics). | Weeks per repo. Re-encode branch-protection rules in the target's primitives; preserve the gate's substantive content. |

**Total estimated exit cost (all surfaces):** months. An SCM migration is not a weekend project — it is its own multi-month initiative under the standard Grid SDLC, scoped only after a D4 trigger fires and the re-evaluation conversation produces "Exit."

## Why Accept (deep, intentional) — and why no hedges

See [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D2's GitHub row explicitly:

> **None. Full lock-in is the correct posture; GitHub is the substrate for the operator's solo-dev workflow and the SDLC depends on its specific affordances.**

The reasoning, made explicit:

1. **The SDLC depends on GitHub-native affordances.** Branch protection semantics, required status checks, the GraphQL Projects API (and its blockedBy edges), Actions matrix concurrency, OIDC federation to Azure per [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md), the repo permission model, CODEOWNERS, secret scanning, Dependabot alerts per [ADR-0009](../../adrs/ADR-0009-package-scanning-policy.md). Hedging would mean abstracting every one of those over a portable layer — a permanent tax against a hypothetical migration.
2. **Per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) Alternatives Considered:** "Pure abstraction discipline (vendor-agnostic everywhere)" was considered and rejected. The abstractions are the **code-level** vendor-exit posture; the posture document captures what the abstractions alone cannot.
3. **Solo-dev + AI-agent SDLC is the operator's posture.** The OpenClaw integration, the `file-packets.yml` automation, the `hive-sync` reconciliation, the cloud-wired review agent — these are all built against GitHub's specific shape. Re-architecting them against a portability layer would erode the AI-multiplier discipline the charter explicitly underwrites.

## The SCM-Migration Pre-Condition

Per [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) D5 explicitly:

> The SCM-migration pre-condition is *another SCM with equivalent affordances for solo-dev + AI-agent SDLC* — not "GitLab can host the source," but the full workflow story.

"Equivalent affordances" means, at minimum:

- Reusable-workflow library equivalence (the target supports composable CI workflows with the same primitive set as `pr-core.yml` / `job-*.yml`).
- Project-board equivalence with the custom-field schema The Hive uses (Status, Wave, Node, Tier, Actor, Initiative, ADR) and an automation API matching what `file-packets.yml` and `hive-sync` consume.
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
- [ADR-0014](../../adrs/ADR-0014-hive-architecture-reconciliation-agent.md) — Hive–Architecture reconciliation agent
- [ADR-0044](../../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — Grid-aware cloud code review
- [ADR-0079](../../adrs/ADR-0079-multi-perspective-pr-review-stack.md) — Multi-perspective PR review stack
- [ADR-0080](../../adrs/ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) — vendor posture umbrella (this file's authorizing ADR)
