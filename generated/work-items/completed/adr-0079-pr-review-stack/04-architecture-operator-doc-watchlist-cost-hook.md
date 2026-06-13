---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0079", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0079", "ADR-0046", "ADR-0052", "ADR-0044"]
accepts: ["ADR-0079"]
wave: 3
initiative: adr-0079-pr-review-stack
node: honeydrunk-architecture
---

# Update operator-facing docs with the four-reviewer expectation, record the Greptile/Codex-OOTB watch-list, and hook reviewer-stack cost monitoring into ADR-0052

## Summary
Three governance documentation tasks from ADR-0079's Follow-up Work: (1) extend the operator-facing onboarding / `CONTRIBUTING.md` aggregator with the four-reviewer expectation so the operator (and any AI agent helping the operator) understands the canonical stack; (2) record the Greptile + Codex-OOTB-review watch-list with reconsideration triggers so future-state decisions have a documented starting point; (3) wire reviewer-stack cost monitoring (CodeRabbit + Codex overage + Anthropic credit pool consumption) into ADR-0052's cost-governance surface so the per-month spend is tracked alongside the rest of the Grid's recurring costs.

## Context
ADR-0079's Follow-up Work names three doc/governance tasks beyond the workflow plumbing of packets 02 and 03:
- "Operator-facing onboarding doc (or `CONTRIBUTING.md` aggregator) explains the four-reviewer expectation."
- "Watch list: Greptile re-evaluation if a class of missed bugs emerges; Codex out-of-the-box review re-evaluation if its Grid-context-loading capability improves; specialist agents per ADR-0046 invocation logic stays per-Node."
- "Cost monitoring per ADR-0052 tracks CodeRabbit + Codex overage + Anthropic credit pool consumption."

These three are operator-facing or governance-tracking artifacts; they depend only on the acceptance flip (packet 00) and are independent of the workflow plumbing (packets 02/03). They are grouped into one packet because they share the same target repo, the same governance surface, and benefit from being authored together to avoid drift between the operator doc, the watch list, and the cost-tracking entry.

ADR-0079 D9 explicitly preserves ADR-0046 (Proposed)'s specialist-agent invocation logic — the watch-list note for "specialist agents stay per-Node" is a non-decision, captured here only to make the preservation explicit and prevent a future drift conversation. ADR-0046 itself remains Proposed; the watch-list note describes the preservation of the pattern ADR-0046 proposes, not an Accepted constraint.

`business/context/` today holds only `entity.md` and `operating-costs.md`. The watch-list note created here is a new cross-cutting artifact in that directory; packet 01 also lands a note there (the safe-list policy note). These two packets together establish the convention for cross-cutting policy notes in `business/context/`. The ADR-0052 cost-tracking hook extends the existing `operating-costs.md` ledger (the Planned Additions table already names CodeRabbit as a pending line item). The four-reviewer expectation lives in `CONTRIBUTING.md` at the Architecture repo root — this file **does not exist today** and is created by this packet.

This is a docs/governance packet. No code, no .NET project. No workflow change.

## Scope
- **Operator-facing four-reviewer expectation doc.** **Create** `CONTRIBUTING.md` at the Architecture repo root (the file does not exist today). The initial body is a "Code review on the Grid" section naming the four reviewers, the substantive-vs-trivial distinction, and what to expect on a PR. Future operator-onboarding content (welcome, contributor workflow, etc.) can extend the same file as new packets need it; this packet seeds the file with the reviewer-stack content only.
- **Watch-list note in `business/context/`.** Create a new note (e.g. `pr-review-watch-list.md`) recording Greptile, Codex-OOTB review, and the ADR-0046 (Proposed) specialist-agent preservation as a single artifact — the reconsideration-triggers note for the reviewer stack.
- **Cost-tracking hook in `business/context/operating-costs.md`.** Extend the existing recurring-cost ledger with the reviewer-stack line items: CodeRabbit (~$24/mo — already named as a Planned Addition; promote to a recurring line once provisioned per packet 01's Human Prerequisites), Codex API overage (bounded variable), Anthropic Claude Max Agent SDK credit pool (no per-token by default; opt-in via ADR amendment only). The ADR-0052 cost-governance surface itself is referenced; the line items land in `operating-costs.md` (the Grid's recurring-cost ledger of record).

## Proposed Implementation
1. **Operator-facing four-reviewer expectation.** **Create** `CONTRIBUTING.md` at the Architecture repo root (the file does not exist today). Seed it with a top-level "Code review on the Grid" section:
   - The four canonical reviewers, each one paragraph:
     - **Reviewer 1: GitHub Copilot Code Review** — GitHub-native, zero marginal cost, generic code quality.
     - **Reviewer 2: CodeRabbit** — third-party AI, ~$24/dev/mo, vendor-independent of Microsoft and Anthropic.
     - **Reviewer 3: Grid-aware `review` agent via Codex/OpenClaw** — runs `.claude/agents/review.md`, loads Grid context (invariants, ADRs, catalogs, packet).
     - **Reviewer 4: Grid-aware `review` agent via Anthropic-native Claude Code** — same agent definition, different model family, runs on substantive PRs from June 15 2026 onward; the dual-model satisfaction of Invariant 53.
   - The substantive-vs-trivial distinction with a pointer to the canonical safe-list (packet 01's policy note).
   - "What to expect on a PR": three reviewer comments on a trivial PR; four reviewer comments on a substantive PR (post-June-15). On a high-risk-Node PR, ADR-0046's specialist agent (Proposed pattern) adds a fifth (the operational maximum per the charter's anti-performing-visibility warning).
   - Reference the source ADRs: ADR-0079 (the canonical stack), ADR-0044 (the Grid-aware reviewer), ADR-0046 (specialist agents — Proposed), and the relevant invariants (52, 53, and the `{N1}`–`{N4}` block packet 00 claims).
2. **Watch-list note.** Create a new note in `business/context/` (e.g. `pr-review-watch-list.md`) titled along the lines of "ADR-0079 reviewer-stack watch list". Body:
   - **Greptile** (held in watch list per ADR-0079 D4). Reconsideration trigger: a class of bugs the current four-reviewer stack consistently misses, AND Greptile's cross-file context awareness or other capability would plausibly have caught the class. If the trigger fires, the next ADR amendment evaluates Greptile against the current stack's perspective coverage.
   - **Codex out-of-the-box review** (held in watch list per ADR-0079 D5). Reconsideration trigger: Codex OOTB review gains Grid-context-loading capability comparable to running `.claude/agents/review.md` directly, AND the OOTB review covers a perspective the current Grid-aware agent does not (which is hard to imagine given the agent's design, but the watch list is honest about uncertainty).
   - **ADR-0046 (Proposed) specialist agents** (no decision pending; ADR-0079 D9 preserves ADR-0046's invocation logic). Note: when a substantive PR touches a high-risk Node, ADR-0046's specialist agent (security, performance, accessibility, etc.) composes on top of the four-reviewer stack — a five-reviewer operational maximum on the most-sensitive PRs.
   - **Cap discipline.** The charter's anti-performing-visibility warning explicitly bounds reviewer count. Adding a fifth canonical reviewer (beyond ADR-0046 specialists) requires an ADR amendment with an explicit forcing function — not a "let's add another bot for thoroughness" decision.
3. **Cost-tracking hook in `business/context/operating-costs.md`.** Extend the existing recurring-cost ledger (the file already exists; CodeRabbit is named in its Planned Additions table). Add line items:
   - **CodeRabbit** — promote from Planned Additions to a recurring line at ~$24/dev/mo × 1 seat = ~$24/mo (do this once the operator's CodeRabbit subscription is provisioned per packet 01's Human Prerequisites; until then, keep it in Planned Additions with a footnote). Trigger for re-evaluation: > $30/mo (a price hike) or > $50/mo (a multi-seat trigger if a second developer joins, which is a separate ADR conversation per the charter's solo-developer posture).
   - **Codex API overage** — bounded variable, against the operator's ChatGPT Pro allotment first. Trigger for re-evaluation: monthly overage > $50/mo sustained for two consecutive months (the ADR-0052 cost-pressure inflection — reconsider Reviewer 3's allotment or move some Codex work off-allotment).
   - **Anthropic Claude Max Agent SDK credit pool** — no per-token billing by default (ADR-0079 D6). Trigger for re-evaluation: credit-pool exhaustion frequency > 1 day/month sustained for two consecutive months → ADR amendment to opt into per-token billing or to add a second Max subscription. Per-token API billing as a fallback is **forbidden by default**; an amendment is required.
   - **Total recurring contribution from the reviewer stack** — ~$24/mo + bounded overage. Within the Grid's broader cost ceiling.
4. **Repo `CHANGELOG.md`** — one-line entry per repo convention referencing this packet and ADR-0079.

## Affected Files
- `CONTRIBUTING.md` at the Architecture repo root (new — does not exist today).
- A watch-list note in `business/context/` (new file).
- `business/context/operating-costs.md` (existing — extend the recurring-cost ledger and/or promote the existing CodeRabbit Planned Additions entry).
- `CHANGELOG.md`.

## NuGet Dependencies
None. This packet touches only Markdown governance/operator docs; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` — `CONTRIBUTING.md`, `business/context/`, and `CHANGELOG.md` all live here. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No workflow change — packets 02 and 03 are the workflow changes.

## Acceptance Criteria
- [ ] `CONTRIBUTING.md` is created at the Architecture repo root with a "Code review on the Grid" section naming the four canonical reviewers each with a one-paragraph description; the substantive-vs-trivial distinction with a pointer to packet 01's safe-list policy note; the "what to expect on a PR" expectation (three vs four reviewer comments, plus specialist agents on high-risk Nodes); references to ADR-0079, ADR-0044, ADR-0046 (Proposed), and invariants 52, 53, and the `{N1}`–`{N4}` block packet 00 claims
- [ ] A new watch-list note in `business/context/` records Greptile, Codex-OOTB review, and the ADR-0046 (Proposed) specialist-agent preservation as reconsideration triggers with explicit conditions for each; the cap-discipline statement (no fifth canonical reviewer without an ADR amendment + forcing function) is included
- [ ] `business/context/operating-costs.md` is extended with the three reviewer-stack line items (CodeRabbit promoted from Planned Additions once provisioned, Codex API overage, Anthropic credit pool); each line names its re-evaluation trigger; the per-token-billing-forbidden default is noted on the Anthropic line
- [ ] The repo `CHANGELOG.md` is updated per repo convention
- [ ] No invariant change (the four PR-review-stack invariants land in packet 00); no `.coderabbit.yaml` change (packet 01); no workflow change (packets 02/03)

## Human Prerequisites
- [ ] None for the doc edits themselves.
- [ ] The cost-ledger entries become real numbers once the CodeRabbit subscription is provisioned (the operator's one-time portal step per packet 01's Human Prerequisites) and once Reviewer 4 is enabled post-June-15 (per packet 03's Human Prerequisites). Until then, the ledger entries are forward-looking estimates.

## Referenced ADR Decisions
**ADR-0079 D1/D2 — The four-reviewer canonical stack.** Three reviewers on every non-draft PR (Copilot, CodeRabbit, Grid-aware via Codex); a fourth reviewer (Grid-aware via Anthropic-native Claude) on substantive PRs from June 15 2026 onward.

**ADR-0079 D4 — Greptile held in watch list.** Reconsideration trigger: a class of missed bugs the current stack consistently misses AND a Greptile-unique capability not otherwise covered.

**ADR-0079 D5 — Codex OOTB review held in watch list.** Reconsideration trigger: Grid-context-loading capability gains in Codex OOTB.

**ADR-0079 D6 — Per-token Anthropic API billing forbidden by default.** Credit-pool exhaustion → skip; opting in requires an ADR amendment.

**ADR-0079 D9 — ADR-0046 specialist-agent invocation preserved.** A substantive PR touching a high-risk Node receives Reviewers 1–4 plus ADR-0046's specialist agent (five reviewers — the operational maximum).

**ADR-0044 — Grid-aware cloud code reviewer.** Reviewers 3 and 4 execute the same `.claude/agents/review.md` agent defined by ADR-0044.

**ADR-0046 (Proposed) — Specialist review agents.** Narrower reviewers (security, performance, accessibility) invoked when their domain is touched; ADR-0079 preserves the per-Node invocation logic of this Proposed pattern.

**ADR-0052 (Proposed) — Cost governance, budget alerts, and kill switches.** The reviewer-stack cost line items register against the broader Grid cost-governance surface this Proposed ADR describes; the immediate ledger of record is `business/context/operating-costs.md`.

**Invariant `{N1}` (packet 00) — Canonical four-reviewer stack.** Adding a fifth canonical reviewer requires an ADR amendment with an explicit forcing function.

## Constraints
- **Operator-facing language.** `CONTRIBUTING.md` and the watch-list note are read by the operator (and any AI agent assisting). Plain-spoken; no jargon-as-pretext.
- **Watch list is reconsideration-trigger documentation, not state.** The watch list does not say "add Greptile next month" — it says "if X happens, reconsider Greptile." Trigger-driven.
- **Cap discipline is explicit.** The fifth-canonical-reviewer prohibition (without ADR amendment + forcing function) is named in the watch-list note. ADR-0046 specialists are the documented exception (per-Node, ADR-bound).
- **Per-token-billing-forbidden default is loud.** The Anthropic credit-pool ledger entry names the forbidden-default rule explicitly so a future operator does not flip on per-token billing without an ADR amendment (the same defense-in-depth as invariant `{N4}` + packet 03's workflow gotcha banner).
- **No invariant or catalog change here.** Invariants land in packet 00; the safe-list policy note lands in packet 01; the workflow changes land in packets 02/03.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0079`, `wave-3`

## Agent Handoff

**Objective:** Update the operator-facing onboarding doc with the four-reviewer expectation, record the Greptile/Codex-OOTB-review watch list with reconsideration triggers, and hook reviewer-stack cost monitoring into the ADR-0052 cost-governance surface.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the four-reviewer expectation visible to the operator (and any helping AI agent); document the watch list as trigger-driven reconsideration; track reviewer-stack costs against the Grid's recurring-cost ledger (`business/context/operating-costs.md`).
- Feature: ADR-0079 Multi-Perspective PR Review Stack rollout, Wave 3.
- ADRs: ADR-0079 D1/D2/D4/D5/D6/D9 (primary), ADR-0044 (the Grid-aware reviewer baseline), ADR-0046 (Proposed — specialist agents preserved per ADR-0079 D9), ADR-0052 (Proposed — cost-governance surface referenced; ledger of record is `operating-costs.md`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0079 should be Accepted before its policy is bound into operator docs and the cost ledger. Independent of packets 01/02/03 — can run in parallel with the CI plumbing.

**Constraints:**
- Operator-facing language; trigger-driven watch list (not scheduled state); explicit cap discipline; the per-token-billing-forbidden default is loud.
- No invariant or catalog change here.

**Key Files:**
- `CONTRIBUTING.md` at the Architecture repo root (new — does not exist today).
- The watch-list note in `business/context/` (new file).
- `business/context/operating-costs.md` (existing — extend the recurring-cost ledger).
- `CHANGELOG.md`.

**Contracts:** None changed.
