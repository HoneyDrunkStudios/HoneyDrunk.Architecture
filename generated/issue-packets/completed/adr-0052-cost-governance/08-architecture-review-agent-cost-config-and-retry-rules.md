---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "ops", "docs", "adr-0052", "wave-1"]
dependencies: ["packet:00", "packet:02"]
adrs: ["ADR-0052", "ADR-0044"]
accepts: ["ADR-0052"]
wave: 1
initiative: adr-0052-cost-governance
node: honeydrunk-architecture
---

# Add cost-config and BudgetExceededException-retry review categories to .claude/agents/review.md

## Summary
Update `.claude/agents/review.md` per ADR-0052's Follow-up Work item: add a `cost-config` review category that treats edits to `business/context/cost-budgets.json` as production-critical config changes (per ADR-0044 D3), and add a `cost-kill-switch-retry` check that flags any code path catching `BudgetExceededException` and retrying within the same billing window. Update `pr-review-rules.md` to map both new categories into the rubric's severity coverage.

## Context
ADR-0052's Operational Consequences names `business/context/cost-budgets.json` as production-critical: "A mis-edit could disable the kill-switch (raise the hard cap to infinity) or trigger spurious shutdowns (drop the hard cap below current month-to-date). The file's PR review is therefore a production-config review; the `review` agent (per ADR-0044) should treat it accordingly."

ADR-0052 D4 names the no-retry contract on `BudgetExceededException`: "The exception type is `sealed` and the documentation calls out the no-retry contract; the `review` agent (per ADR-0044) gains a category check for 'code catches `BudgetExceededException` and retries' as a defect."

ADR-0052's Follow-up Work names both items explicitly:
- "Add a `cost-config` review category to `.claude/agents/review.md` per ADR-0044 D3, covering the production-critical nature of `business/context/cost-budgets.json` changes."
- "Add an integration test for the `BudgetExceededException` no-retry contract — verify that the exception type is sealed, that the default retry policies do not retry it, and that the `review` agent's category check catches catch-and-retry patterns."

The integration-test half of the second bullet lands in packet 06's canary; this packet's job is the `review`-agent-side rule.

**ADR-0044 D3 — review rubric.** The `review` agent operates against a twenty-category rubric in `.claude/agents/review.md`. Each category names what to look for, severity bands, and example violations. New categories follow the same structure. `pr-review-rules.md` maps every category onto a severity (e.g., `block` / `comment` / `informational`) so the reviewer agent can produce a consistent verdict.

**File locations at edit time.** `.claude/agents/review.md` lives in the Architecture repo. `pr-review-rules.md` likewise lives in the Architecture repo (path TBD per repo convention; check at edit time). Both are tracked artifacts that the review pipeline reads.

## Scope
- `.claude/agents/review.md` — add two new review categories:
  - `cost-config` — production-critical config review for `business/context/cost-budgets.json`.
  - `cost-kill-switch-retry` — defect detection for catch-and-retry on `BudgetExceededException`.
- `pr-review-rules.md` (path per repo convention) — map both new categories to severity bands consistent with the existing rubric.
- Repo-level `CHANGELOG.md`.

## Proposed Implementation
1. **`cost-config` review category in `.claude/agents/review.md`.** Add a new category section. Content:
   - **Trigger.** Any PR that modifies `business/context/cost-budgets.json` (or, if the file's path moves, the configured cost-budget JSON path).
   - **What to look for.**
     - **Cap value sanity.** Soft and hard caps for every category, in the ranges the ADR-0052 D2 narrative establishes ($50–$5000 for AI inference is the reasonable band today; $300–$1000 for Azure infra; etc.). Sudden jumps (e.g., AI inference hard cap raised from $1500 to $50000 in a single PR) require explicit justification in the PR description.
     - **Hard cap above soft cap.** Hard caps must be greater than or equal to soft caps; a hard cap below the soft cap is nonsensical and a defect.
     - **Hard cap not removed without category-level kill-switch removal.** If a hard cap is set to null/removed, the category's `kill_switch` field must also be `"none"` — otherwise the runtime expects a value and may default to permissive (defect).
     - **Anomaly thresholds in band.** Hour-over-hour multiplier in `[1.5, 20.0]`; day-over-day multiplier in `[1.2, 10.0]`. Values outside the band indicate either disabled detection (very high) or noise-trap detection (very low).
     - **Dev overlay values smaller than prod.** A dev cap that exceeds the prod cap is almost certainly a mistake.
     - **PR description carries reasoning.** Per ADR-0052 D2: "Changes to the file are tracked by git, reviewed via the standard PR flow, and audited. The PR flow is the slow path for changing caps — it preserves a permanent record of 'the cap was raised on this date, by this PR, with this reasoning.'" A PR that changes caps without describing why is a documentation defect.
   - **Severity.** `block` — the review agent does not approve a `cost-config` change without explicit operator sign-off in the PR description (a comment like "Approved by Oleg, raising cap for customer-demo window" is sufficient).
   - **Why it matters.** Cite ADR-0052 D2 and the Operational Consequences directly: this is the only mechanism for persistent cap changes; the file is production-critical; the audit trail is the git history; the override CLI (D11) is the fast path for emergencies and does not mutate this file.
2. **`cost-kill-switch-retry` review category in `.claude/agents/review.md`.** Add a new category section. Content:
   - **Trigger.** Any PR that touches code in the dispatcher / LLM-call path, OR adds a `catch` clause referencing `BudgetExceededException`, OR adds a retry policy in code that includes `BudgetExceededException` in the catch-and-retry set.
   - **What to look for.**
     - **Direct catch-and-retry.** `catch (BudgetExceededException) { /* retry */ }` is a defect. The exception is sealed; the cap is closed for the billing window or until an override; a retry inside the same window will either throw again or, worse, succeed on a race condition with the cache refresh and incur further spend.
     - **Generic exception swallowing.** `catch (Exception)` blocks that wrap LLM calls and continue the loop are suspicious — they may swallow `BudgetExceededException` implicitly. The reviewer should ask whether the block is specifically excluding sealed non-transient exception types.
     - **Polly / retry-library configuration.** A `Policy.Handle<Exception>()` configured against an LLM-call delegate is a defect unless the policy explicitly excludes `BudgetExceededException`. The reviewer flags the policy and suggests `Policy.Handle<Exception>(ex => ex is not BudgetExceededException)`.
     - **Top-level loop catch.** ADR-0052 D4 explicitly allows a top-level loop to catch the exception, write checkpoint state to Audit, and exit cleanly. The reviewer recognizes this pattern (single top-level handler that does not invoke the LLM-call site again in the same process) and approves it.
   - **Severity.** `block` — a catch-and-retry on `BudgetExceededException` defeats the kill-switch and is a budgeting defect.
   - **Why it matters.** Cite ADR-0052 D4 and invariant 91 directly: the no-retry contract is the substrate of the kill-switch; without it the cap is advisory only.
3. **`pr-review-rules.md` mapping.** Add both new categories to the rules table with `block` severity. Match the existing table format (column conventions at edit time). The mapping ensures the review pipeline produces a consistent verdict regardless of which reviewer instance runs.
4. **CHANGELOG.** Repo-level `CHANGELOG.md` carries an entry naming the two new review categories.

## Affected Files
- `.claude/agents/review.md`
- `pr-review-rules.md` (path per repo convention; check at edit time)
- Repo-level `CHANGELOG.md`

## NuGet Dependencies
None. Documentation only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The `review` agent and the PR review rules are Architecture-repo concerns.
- [x] No code change in any other repo.
- [x] The dispatcher canary for the no-retry contract lives in `HoneyDrunk.AI` (packet 06), not this packet.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` carries a new `cost-config` review category triggered on edits to `business/context/cost-budgets.json`, severity `block`, with the cap-sanity / hard-greater-than-soft / dev-smaller-than-prod / anomaly-band / PR-description-justification checks listed
- [ ] `.claude/agents/review.md` carries a new `cost-kill-switch-retry` review category triggered on dispatcher-path code, severity `block`, with direct-catch-and-retry / generic-swallowing / Polly-handle / top-level-loop-allowed semantics specified
- [ ] Both new categories cite ADR-0052 D2 / D4 and invariant 91 as the source-of-truth
- [ ] `pr-review-rules.md` (or its equivalent) maps both new categories to `block` severity in the existing table format
- [ ] Repo-level `CHANGELOG.md` carries an entry naming the two new categories
- [ ] No edit to other agent files; no code change; no edit to the catalog or budget config

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0052 Operational Consequences — `cost-budgets.json` production-critical.** A mis-edit could disable the kill-switch or trigger spurious shutdowns. The PR-review flow on this file is a production-config review; the `review` agent (per ADR-0044) treats it accordingly.

**ADR-0052 D2 — Slow PR path is the only persistent-cap change mechanism.** The git history is the audit trail; PR description carries the reasoning. The fast path (D11 override CLI) is for emergencies and does not mutate the JSON file.

**ADR-0052 D4 — `BudgetExceededException` no-retry contract.** The exception is sealed and non-transient. Callers must not retry. The `review` agent gains a catch-and-retry detection rule.

**ADR-0052 Follow-up Work — explicit naming of both review-agent additions.** "Add a `cost-config` review category to `.claude/agents/review.md` per ADR-0044 D3." "Add an integration test for the `BudgetExceededException` no-retry contract — and the `review` agent's category check catches catch-and-retry patterns."

**ADR-0044 D3 — Review rubric in `.claude/agents/review.md`.** The twenty-category rubric structure: trigger, what-to-look-for, severity, why-it-matters. New categories follow the existing structure; `pr-review-rules.md` maps every category onto a severity band.

**Invariant 91 (this initiative, packet 00) — Hot-path cap check on every LLM call.** Catch-and-retry defeats the kill-switch and violates this invariant.

## Constraints
- **Match the existing rubric structure.** New categories follow the same shape as the existing twenty (trigger, what-to-look-for, severity, why-it-matters).
- **Severity is `block` for both.** Both categories represent budgeting defects with high blast radius; `comment` or `informational` would defeat the rule's purpose.
- **Cite the ADR / invariant as source-of-truth.** Reviewers and authors must be able to trace the rule back to ADR-0052 D2 / D4 and invariant 91 without ambiguity.
- **Top-level loop catch is allowed.** Document the carve-out so the reviewer agent does not produce false positives on the explicitly-permitted pattern in ADR-0052 D4 ("Most callers should propagate the exception. Specific call sites (e.g., a long-running agent loop) may want to halt cleanly with a checkpoint rather than crash; the convention is to catch the exception only at the top-level loop, log the budget breach as a structured event, write any in-flight state to Audit for resumption, and exit.").
- **No edit to packet-06 canary.** The runtime test that proves the contract is packet 06's canary; this packet's job is the review-agent-side rule.

## Labels
`feature`, `tier-3`, `ops`, `docs`, `adr-0052`, `wave-1`

## Agent Handoff

**Objective:** Add two new categories to the `review` agent's rubric (`cost-config` and `cost-kill-switch-retry`), severity `block` for both, with the source-of-truth pointers to ADR-0052 D2 / D4 and invariant 91.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close ADR-0052's two named review-agent follow-ups: the production-config gate on cap edits, and the catch-and-retry defect detection.
- Feature: ADR-0052 Cost Governance rollout, Wave 1.
- ADRs: ADR-0052 D2/D4 (primary), ADR-0044 D3 (review rubric structure).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — invariant 91 exists for `cost-kill-switch-retry` to cite.
- `packet:02` — `business/context/cost-budgets.json` exists for `cost-config` to target.

**Constraints:**
- Match the existing rubric structure.
- Severity `block` for both.
- Document the top-level-loop carve-out from D4 so reviewers don't false-positive on the allowed pattern.

**Key Files:**
- `.claude/agents/review.md`
- `pr-review-rules.md` (or its equivalent)
- Repo-level `CHANGELOG.md`

**Contracts:** None. Documentation only.
