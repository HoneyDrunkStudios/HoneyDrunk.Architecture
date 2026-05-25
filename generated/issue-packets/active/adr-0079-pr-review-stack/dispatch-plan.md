# Dispatch Plan — ADR-0079: Multi-Perspective PR Review Stack

**Initiative:** `adr-0079-pr-review-stack`
**ADR:** ADR-0079 (Proposed → Accepted via packet 00)
**Sector:** Meta (governance + CI)
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0079 commits the canonical PR-review stack: **three reviewers on every non-draft PR** (GitHub Copilot Code Review, CodeRabbit, Grid-aware `review` agent via Codex/OpenClaw) and **a fourth reviewer on substantive PRs** (the same `.claude/agents/review.md` Grid-aware agent executed through Anthropic's native Claude Code on the web GitHub integration). The fourth reviewer is the cleanest available satisfaction of Invariant 53 ("two independent LLM-review perspectives on high-risk Nodes") because it runs the same Grid-context-loaded agent against a different model family (Claude vs. Codex's GPT-class). A mechanical safe-list distinguishes substantive from trivial PRs; trivial (docs-only) PRs skip Reviewer 4 to preserve cost discipline.

This initiative delivers: ADR acceptance + four new Code Review invariants + the `.coderabbit.yaml` Grid template + the substantive-PR classifier wired into `HoneyDrunk.Actions`'s PR-review pipeline + the Reviewer 4 trigger (gated on the June 15 2026 Claude Agent SDK credit-pool availability) + the auth-precedence runner-config gotcha doc + the operator-facing four-reviewer expectation note + the cost-tracking hook into ADR-0052.

**5 packets across 3 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`). All 5 `Actor=Agent`, 0 `Actor=Human`. Multiple packets carry Human Prerequisites — CodeRabbit subscription provisioning (one-time), Anthropic Claude Max session credential setup for the GitHub-Actions runner (post-June-15), and the explicit decision to enable Reviewer 4 across the Grid — but the code/YAML/docs work itself is fully delegable.

## Trigger

ADR-0079 is Proposed with no scope. Forcing functions from the ADR's Context:

- **AI-authored PR volume has grown** — wave-style rollouts emit 5–15 agent PRs per window; the reviewer stack must be cost-efficient per-PR or it bottlenecks the throughput.
- **Invariant 53's "two independent perspectives" requirement is unsatisfied today** on substantive Node PRs — today's stack carries only one Grid-aware reviewer.
- **Anthropic's June 15 2026 Claude Agent SDK credit pool** for Claude Max subscribers creates a new no-per-token billing path that did not exist when ADR-0044 was authored.
- **The Grid has no formal substantive-vs-trivial PR classifier** — without one, every reviewer runs on every docs-only PR.
- **The charter's anti-performing-visibility warning** explicitly bounds reviewer count.

## Scope Detection

**Multi-repo.** ADR-0079 touches `HoneyDrunk.Architecture` (acceptance, four invariants, the safe-list catalog/policy note, the operator-facing expectation doc, the ADR-0052 cost-tracking hook) and `HoneyDrunk.Actions` (the classifier in the PR-review workflow, the Reviewer 4 trigger workflow, the auth-precedence runner-config doc). The `.coderabbit.yaml` template (Architecture packet 01) is the Grid's reference shape — per-repo `.coderabbit.yaml` adoption is deliberately deferred to a follow-up fan-out (see Out-of-scope below) rather than fanned into premature per-Node packets.

**No new-Node scaffolding.** Both target repos are live. No empty cataloged repo is touched; no standup ADR needed.

## Wave Diagram

### Wave 1 (governance + foundation)
- [ ] **00** — Architecture: Accept ADR-0079, add the four new Code Review invariants (numbers **54, 55, 56, 57**), register the initiative, amend ADR-0044 with the "Amended by ADR-0079" note, clarify ADR-0046 Invariant 53 satisfaction. `Actor=Agent`.
- [ ] **01** — Architecture: author the `.coderabbit.yaml` Grid template and record the substantive-PR safe-list as a cross-cutting policy note in `business/context/` (or the established location). `Actor=Agent`. Blocked by: 00.

### Wave 2 (CI plumbing — parallel)
- [ ] **02** — Actions: add the substantive-PR classifier to `job-review-request.yml` (or its caller `pr-core.yml`), surfacing a boolean output for downstream jobs. `Actor=Agent`. Blocked by: 00, 01.
- [ ] **03** — Actions: wire the Reviewer 4 trigger (Anthropic-native Claude Code on the web GitHub integration) gated on substantive-PR true; document the auth-precedence (`ANTHROPIC_API_KEY`) gotcha at the runner-configuration level. `Actor=Agent`. Blocked by: 00, 02.

### Wave 3 (operator-facing + cost tracking)
- [ ] **04** — Architecture: update the operator-facing onboarding doc (`CONTRIBUTING.md` aggregator and the operator quickstart) with the four-reviewer expectation; record the watch-list (Greptile, Codex OOTB review) for future-state reconsideration; wire the cost-monitoring hook into the ADR-0052 reviewer-stack cost surface. `Actor=Agent`. Blocked by: 00. (Parallel with 02/03 — depends only on the acceptance flip.)

Packets within a wave run in parallel. The `dependencies:` frontmatter is the real ordering signal — packet 04 unblocks as soon as packet 00 lands (the Wave 3 grouping is for tidy filing only).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0079](./00-architecture-adr-0079-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [`.coderabbit.yaml` template + safe-list policy](./01-architecture-coderabbit-template-and-substantive-safe-list.md) | Architecture | Agent | 1 | 00 |
| 02 | [Substantive-PR classifier in `job-review-request.yml`](./02-actions-substantive-pr-classifier.md) | Actions | Agent | 2 | 00, 01 |
| 03 | [Reviewer 4 trigger + auth-precedence runner doc](./03-actions-reviewer4-claude-trigger-and-auth-gotcha.md) | Actions | Agent | 2 | 00, 02 |
| 04 | [Four-reviewer operator doc + watch-list + cost hook](./04-architecture-operator-doc-watchlist-cost-hook.md) | Architecture | Agent | 3 | 00 |

## Invariant Numbering

The verified current maximum invariant number in `constitution/invariants.md` is **53**. ADR-0079's Consequences/Invariants section names exactly four new rules (D1+D2's four-reviewer stack, D3's safe-list, the shared-agent-definition discipline that extends ADR-0044 D1, and the `ANTHROPIC_API_KEY` runner-environment rule from D8). These are numbered **54, 55, 56, 57** under the existing `## Code Review Invariants` section — appended after invariant 53. ADR-0079 was not part of the 12-ADR pre-reservation batch (ADR-0044/0045/0046 etc.); its numbering is sequential.

If invariants land between numbers 54–57 from another ADR before packet 00 merges, shift this block upward, never reuse. As of 2026-05-24, no overlap is visible.

## Cross-Cutting Concerns

### Pre-June-15 transition state

ADR-0079 D2 + D7 are explicit: until **June 15, 2026** (the Claude Agent SDK credit-pool launch), Reviewer 4 does not run. Packets 02 and 03 ship with the substantive-PR classifier wired and the Reviewer 4 workflow file authored, but the workflow's `enabled` gate stays off until the credit pool is available. Reviewers 1, 2, and 3 operate normally during transition. Invariant 53's full satisfaction degrades to "single Grid-aware perspective + two generic perspectives" until June 15 — degraded-but-honest per D7.

### Per-repo `.coderabbit.yaml` fan-out (deferred)

Packet 01 ships the Grid-canonical `.coderabbit.yaml` template + the placement convention. Per-repo adoption across the 12+ Grid repos is a follow-up fan-out item, *not* in scope here. The justification: CodeRabbit's defaults are sensible without a per-repo config; the per-repo config refines for repo-specific patterns (e.g. Vault's secret-handling patterns, Audit's append-only constraints). The fan-out can be incremental, repo-by-repo, driven by observed reviewer noise — not a blocking pre-condition for ADR-0079.

### Coupling with ADR-0046 specialist agents

ADR-0079 D9 explicitly **does not** change ADR-0046's specialist-agent invocation logic. A substantive PR touching a high-risk Node receives Reviewers 1–4 *plus* whatever specialist agent ADR-0046 invokes for the touched domain — a five-reviewer operational maximum on the most-sensitive PRs. The cap is real; the charter's anti-performing-visibility warning bounds further additions to a future ADR with an explicit forcing function.

### Watch list — Greptile and Codex out-of-the-box review

ADR-0079 D4 and D5 hold both in the watch list. Packet 04 records the triggers under which each is reconsidered (a class of bugs the current stack consistently misses; a Greptile-unique capability not otherwise covered; Codex OOTB Grid-context-loading improvements). The watch list is not state to be reconciled; it is a documented reconsideration trigger.

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only (packets 00, 01, 04). The repo `CHANGELOG.md` is updated per repo convention.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; workflow/YAML changes (packets 02, 03). The repo `CHANGELOG.md` is updated per repo convention if it keeps one for the workflow surface.

## Rollback Plan

- **Packet 00 (governance):** revert the PR. ADR returns to Proposed; the four new invariants and the ADR-0044/0046 amendment notes are removed. No runtime impact.
- **Packet 01 (`.coderabbit.yaml` template + safe-list policy):** revert the PR. Docs/template only. No repo has yet adopted the template (per-repo adoption is the deferred fan-out).
- **Packet 02 (substantive-PR classifier):** revert the workflow edit. The classifier output is consumed only by packet 03's gate; reverting it makes the gate evaluate as "trivial" (Reviewer 4 skipped) — safe failure mode.
- **Packet 03 (Reviewer 4 trigger + auth-precedence doc):** revert the workflow edit and the doc change. Reviewer 4 simply does not run; Reviewers 1, 2, 3 operate normally. No tenant-facing or runtime impact.
- **Packet 04 (operator doc + watch-list + cost hook):** revert the PR. Docs only.
- **Architectural escape hatch:** if Reviewer 4 produces low-value review noise post-June-15, the operator can flip `enabled: false` on the Reviewer 4 workflow gate — Invariant 53 satisfaction degrades to the pre-June-15 transition state until a fix lands or the ADR is amended.

## Out-of-scope items from ADR-0079

- **Per-repo `.coderabbit.yaml` fan-out** — the Grid template + placement convention land in packet 01; per-repo adoption is incremental, not scoped here. Each repo's adoption is a small follow-up PR against observed reviewer noise.
- **Specialist agent invocation changes** — ADR-0046's invocation logic is preserved per ADR-0079 D9.
- **Cross-reviewer verdict aggregation** — ADR-0079 D9 names this as a future-state concern. No packet here.
- **Per-PR reviewer override (label-based opt-out)** — D9 forbids this. No packet here.
- **Greptile / Codex OOTB review packets** — D4 and D5 hold both in the watch list. Reconsideration is trigger-driven, not scheduled. Packet 04 records the triggers.
- **Pre-June-15 paying-per-token for Reviewer 4** — D6 explicitly out of scope; opting in requires an ADR amendment.

## Cross-Cutting — site sync

No site-sync flag. ADR-0079 is internal CI/governance infrastructure — no Studios public-facing content changes.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
