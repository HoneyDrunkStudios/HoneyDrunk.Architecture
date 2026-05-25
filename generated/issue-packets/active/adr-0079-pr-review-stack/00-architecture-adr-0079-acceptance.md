---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0079", "wave-1"]
dependencies: []
adrs: ["ADR-0079", "ADR-0044", "ADR-0046", "ADR-0011"]
accepts: ["ADR-0079"]
wave: 1
initiative: adr-0079-pr-review-stack
node: honeydrunk-architecture
---

# Accept ADR-0079 — flip status, add the four PR-review-stack invariants, amend ADR-0044 and clarify ADR-0046

## Summary
Flip ADR-0079 (Multi-Perspective PR Review Stack) from Proposed to Accepted: update the ADR header, add the ADR-0079 row to `adrs/README.md`, add the four new Code Review invariants ADR-0079 commits in its Consequences/Invariants section to `constitution/invariants.md`, register the `adr-0079-pr-review-stack` initiative in `initiatives/active-initiatives.md`, amend ADR-0044 with an "Amended by ADR-0079" note linking to D8's billing-path discipline, and add a clarifying note on `constitution/invariants.md`'s invariant 53 entry that ADR-0079 D7's dual-model Grid-aware-agent execution is the canonical satisfaction.

## Context
ADR-0079 commits the **canonical PR-review stack** the Grid has been operating ad-hoc since ADR-0044's acceptance. Three reviewers run on every non-draft PR (GitHub Copilot Code Review, CodeRabbit, the Grid-aware `review` agent via Codex/OpenClaw); a fourth reviewer (the same `.claude/agents/review.md` Grid-aware agent executed through Anthropic's native Claude Code on the web GitHub integration) runs on substantive PRs from the June 15 2026 Claude Agent SDK credit-pool launch onward.

The ADR decides:
- **D1** — three reviewers (Copilot Code Review, CodeRabbit, Grid-aware via Codex) run on every non-draft PR.
- **D2** — substantive PRs receive a fourth reviewer: the Grid-aware agent via Anthropic-native Claude Code, billed against the Claude Max Agent SDK credit pool from June 15 2026. Same agent definition, two execution paths, two different model families.
- **D3** — the substantive-PR classifier is a mechanical safe-list (`*.md`, `*.mdx`, `*.txt`, `docs/**`, `LICENSE*`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `docs/assets/**`). Any PR touching anything outside the safe-list is substantive; a docs-only PR is trivial. Per-PR override is forbidden.
- **D4** — Greptile is considered and not selected (held in the watch list).
- **D5** — Codex out-of-the-box review (non-Grid-aware) is considered and not selected.
- **D6** — cost ceiling: ~$24/mo CodeRabbit + bounded Codex/Anthropic allotment overage. Reviewer 4 does **not** fall back to per-token Anthropic API billing if the credit pool is exhausted.
- **D7** — Invariant 53 satisfaction: the dual-model execution of the Grid-aware agent (Codex GPT-class + Claude) is the canonical two-independent-Grid-aware-perspectives shape. Pre-June-15 transition is degraded-but-honest.
- **D8** — amendment to ADR-0044 making the billing-path discipline first-class (Codex via OpenClaw → ChatGPT Pro; Claude via Anthropic-native → Claude Max Agent SDK credit pool) and codifying the `ANTHROPIC_API_KEY` auth-precedence gotcha.
- **D9** — explicit out-of-scope set (specialist agent invocation, human reviewer involvement, cross-reviewer verdict aggregation, per-Node high-risk classification, trivial-PR Reviewer 1/2/3 suppression, per-PR reviewer override, the content of `.claude/agents/review.md`).

ADR-0079 is a **policy / decision** ADR. The concrete CI work — the substantive-PR classifier in `job-review-request.yml`, the Reviewer 4 trigger workflow, the auth-precedence runner-config doc, the `.coderabbit.yaml` Grid template, the operator-facing four-reviewer expectation doc, the cost-tracking hook — lands in the implementing packets (01–04). Acceptance must land first because every other packet in this initiative references ADR-0079's D-decisions as live rules.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Invariant Numbering
ADR-0079 adds exactly **four** invariants. Numbering is claimed from the reservation registry, not hardcoded — read `constitution/invariant-reservations.md` and take the next free block of size **four** at the current ceiling (today the registry shows ADR-0079's block as **95–98**, but if a later ADR lands first the implementer shifts upward and updates the registry row + every `{N1}`–`{N4}` placeholder in this packet). Refer to the four new invariants as `{N1}`, `{N2}`, `{N3}`, `{N4}` throughout this packet; replace placeholders with the claimed numbers at edit time. Append the block under the existing `## Code Review Invariants` section in `constitution/invariants.md` (the section ADR-0044 created at invariants 52–53; the new four extend it).

## Scope
- `adrs/ADR-0079-multi-perspective-pr-review-stack.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — append the ADR-0079 row (Accepted, 2026-05-23, Meta) to the index table. **Scope-creep acknowledgement:** the index currently ends at ADR-0057 (line 64) while ADR files exist on disk through ADR-0079; the ADR-0058 through ADR-0078 README backlog is real but explicitly out-of-scope for this packet. This packet appends only the ADR-0079 row at the end of the existing table; backfilling the missing 21 rows is deferred to a separate housekeeping packet.
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md` — add an "Amended by ADR-0079" note pointing at ADR-0079 D8's billing-path discipline.
- `adrs/README.md` — update the ADR-0044 row's description to note the ADR-0079 amendment (one-sentence pointer; the full content stays in ADR-0044).
- `constitution/invariants.md` — append four new invariants (numbers `{N1}`–`{N4}` — see Invariant Numbering above; claimed via `constitution/invariant-reservations.md`) under `## Code Review Invariants`. Also add a one-line clarifying note on the existing invariant 53 entry that ADR-0079 D7 names the dual-model Grid-aware-agent execution as the canonical satisfaction.
- `constitution/invariant-reservations.md` — add the ADR-0079 reservation row in the **Active Reservations** table for the claimed block; update the **Current ceiling** line. (This packet's PR is the one that claims the block.)
- `initiatives/active-initiatives.md` — register the `adr-0079-pr-review-stack` initiative with the packet checklist for this folder.

## Proposed Implementation
1. **Claim the invariant block.** Read `constitution/invariant-reservations.md`. Identify the next free block of size **four** at the current ceiling. Add the ADR-0079 row to the **Active Reservations** table for that block; update the **Current ceiling** line. Substitute the claimed numbers for `{N1}`, `{N2}`, `{N3}`, `{N4}` everywhere they appear in this packet body (the four invariant texts in step 5, the references in step 4, the Affected Files list, and the Acceptance Criteria). If a later ADR's packet 00 has shifted the ceiling between this packet's authoring and its merge, take the new next-free block and update accordingly.
2. Edit the ADR-0079 header: `**Status:** Proposed` → `**Status:** Accepted`.
3. Append an ADR-0079 row to `adrs/README.md`'s index table. **Scope-creep acknowledgement:** the index currently ends at ADR-0057 (line 64) and ADR files exist on disk through ADR-0079 — the 21-row backlog is real but out-of-scope for this packet. Append the ADR-0079 row at the end of the existing table; do not backfill ADR-0058 through ADR-0078. Use the existing column shape (link, title, status, date, sector, description). Title: "Multi-Perspective PR Review Stack — Copilot + CodeRabbit + Grid-Aware Agent (Codex + Claude)". Date: 2026-05-23. Sector: Meta.
4. Update the ADR-0044 row's description in `adrs/README.md` with a brief "Amended by ADR-0079 (billing-path discipline + Reviewer 4 enablement)" pointer.
5. Add a `> **Amendment — ADR-0079.** Billing-path discipline is now first-class; see ADR-0079 D8. The `ANTHROPIC_API_KEY` runner-environment rule is codified by invariant `{N4}`.` note near the top of `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md` (after the Status header, before the Context section — match the established amendment-note convention from earlier ADRs).
6. Append four new invariants to `constitution/invariants.md` under `## Code Review Invariants` (after invariant 53). Use the numbers claimed in step 1 (`{N1}` through `{N4}`). Text, verbatim-in-substance from ADR-0079's Consequences/Invariants section:

   - **`{N1}` — The canonical PR review stack is four reviewers.** Three reviewers run on every non-draft PR (GitHub Copilot Code Review, CodeRabbit, the Grid-aware `review` agent via Codex/OpenClaw); a fourth reviewer (the same `.claude/agents/review.md` Grid-aware agent executed through Anthropic's native Claude Code on the web GitHub integration) runs on substantive PRs from the June 15 2026 Claude Agent SDK credit-pool launch onward. Adding a fifth canonical reviewer requires an ADR amendment with an explicit forcing function (the charter's anti-performing-visibility warning is the governor). See ADR-0079 D1, D2.

   - **`{N2}` — The substantive-PR classifier is the safe-list in ADR-0079 D3; per-PR override is forbidden.** A PR is trivial only if its entire changeset stays inside the safe-list (`*.md`, `*.mdx`, `*.txt`, `docs/**`, `LICENSE*`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `docs/assets/**`). Any file outside the safe-list makes the PR substantive. The classifier is mechanical — no LLM judgment, no label-based override, no commit-message escape. See ADR-0079 D3.

   - **`{N3}` — The Grid-aware `review` agent's two execution paths (Codex and Claude) must consume the same `.claude/agents/review.md` definition.** Drift between execution surfaces is forbidden. `{N3}` extends ADR-0044 D1's "agent definition is the source of truth" principle to cover both the Codex/OpenClaw and the Anthropic-native Claude Code on the web execution paths. The agent file in the Architecture repo is the canonical source; both runtimes load it directly. See ADR-0079 D2.

   - **`{N4}` — `ANTHROPIC_API_KEY` is not set in the Reviewer 4 runner environment by default.** The Claude Agent SDK credit pool is consumed when the runner authenticates as the operator's Claude Max session — typically via the Claude Code on the web integration's session credentials. If a runner environment has `ANTHROPIC_API_KEY` set as an environment variable, the SDK uses it preferentially and per-token API billing applies silently. The default Reviewer 4 runner configuration leaves `ANTHROPIC_API_KEY` unset; opting into per-token billing requires an ADR amendment per ADR-0079 D6. See ADR-0079 D8.

7. Add a one-line clarifying note to the existing invariant 53 entry in `constitution/invariants.md` (the entry currently reads "Agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge"): append "Per ADR-0079 D7, the canonical satisfaction is the dual-model execution of the Grid-aware `review` agent — Codex (GPT-class) executes the agent on every PR; Claude (Anthropic-native) executes the same agent on substantive PRs from June 15 2026 onward. Same agent definition, two model families, genuinely independent at the model level."
8. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. Place it after the existing ADR-0044 entry (Code Review Stack is the closest topical neighbor).

## Affected Files
- `adrs/ADR-0079-multi-perspective-pr-review-stack.md`
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0079 header reads `**Status:** Accepted`
- [ ] `constitution/invariant-reservations.md` carries an ADR-0079 row in **Active Reservations** for the claimed `{N1}`–`{N4}` block; the **Current ceiling** line is updated
- [ ] An ADR-0079 row exists in `adrs/README.md`'s index, appended to the end of the existing table, with status Accepted and a faithful one-paragraph description. The ADR-0058–ADR-0078 backlog is acknowledged as out-of-scope and not backfilled
- [ ] ADR-0044 carries an `> **Amendment — ADR-0079.**` note near the top (after Status, before Context) pointing at ADR-0079 D8's billing-path discipline and naming invariant `{N4}` as the codification of the `ANTHROPIC_API_KEY` rule
- [ ] The ADR-0044 row in `adrs/README.md` has a brief "Amended by ADR-0079" pointer in its description
- [ ] `constitution/invariants.md` carries four new invariants under `## Code Review Invariants` numbered with the claimed `{N1}`–`{N4}` block (the four-reviewer stack; the safe-list classifier with no per-PR override; the shared-agent-definition rule for both execution paths; the `ANTHROPIC_API_KEY` runner-environment rule), each citing ADR-0079
- [ ] The existing invariant 53 entry carries a one-line ADR-0079 D7 clarifying note naming the dual-model Grid-aware-agent execution as the canonical satisfaction
- [ ] `initiatives/active-initiatives.md` registers the `adr-0079-pr-review-stack` initiative with a packet checklist, placed near the ADR-0044 entry
- [ ] No `.coderabbit.yaml` change in this packet (that lands in packet 01); no workflow change (packets 02/03); no operator-facing doc change (packet 04)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0079 D1 — Three reviewers on every PR by default.** GitHub Copilot Code Review (zero marginal cost, included in the operator's GitHub Copilot subscription), CodeRabbit (~$24/dev/mo, third-party AI independence from Microsoft and Anthropic), Grid-aware `review` agent via Codex/OpenClaw (against the operator's ChatGPT Pro allotment; API overage on exceedance). Three different perspectives, three different things they catch.

**ADR-0079 D2 — Substantive PRs receive a fourth reviewer.** The same `.claude/agents/review.md` Grid-aware agent executed through Anthropic's native Claude Code on the web GitHub integration; billed against the Claude Max Agent SDK credit pool from June 15 2026; same agent definition, two execution paths, two model families. Pre-June-15 the workflow ships but the enable gate stays off; per-token API billing as a fallback is explicitly out of scope per D6.

**ADR-0079 D3 — Substantive-PR classifier safe-list.** Any PR whose entire changeset stays inside `*.md`, `*.mdx`, `*.txt`, `docs/**`, `LICENSE*`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `docs/assets/**` is trivial. Any file outside makes the PR substantive. Mechanical classifier — no LLM judgment, no per-PR override.

**ADR-0079 D7 — Invariant 53 satisfaction via dual-model execution.** Two genuinely independent model families (GPT-class via Codex, Claude via Anthropic) executing the same Grid-context-loaded agent definition. The two perspectives share the Grid's worldview through `.claude/agents/review.md`; their independence is at the model level. Pre-June-15 the transition state is degraded-but-honest (single Grid-aware perspective + two generic).

**ADR-0079 D8 — Amendment to ADR-0044.** Billing paths are now first-class: Codex via OpenClaw → ChatGPT Pro allotment + API overage; Claude via Anthropic-native → Claude Max Agent SDK credit pool with no per-token fallback by default. The auth-precedence gotcha (`ANTHROPIC_API_KEY` in the runner environment silently flips Claude execution to per-token billing) is codified as invariant `{N4}` and the runner-config docs (packet 03) carry the operator-facing checklist.

**ADR-0079 Consequences — Invariants.** Four new invariants (numbers `{N1}`–`{N4}`, claimed via `constitution/invariant-reservations.md`): the canonical four-reviewer stack; the safe-list classifier with no per-PR override; the shared-agent-definition rule for both execution paths; the `ANTHROPIC_API_KEY` runner-environment rule.

## Constraints
- **Acceptance precedes flip.** ADR-0079 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbering via the reservation registry.** Read `constitution/invariant-reservations.md` and claim the next free block of size **four** at the current ceiling. Add the ADR-0079 reservation row in the same PR that writes invariants. Replace every `{N1}`–`{N4}` placeholder in this packet body with the claimed numbers. Append the new invariants under `## Code Review Invariants`. Do not renumber existing invariants. If a racing PR has shifted the ceiling between this packet's authoring and merge, take the new next-free block.
- **No new invariants section.** The four new invariants extend the existing `## Code Review Invariants` section (invariants 31–33 and 52–53). Do not create a parallel section.
- **ADR-0044 amendment is one note, not a rewrite.** A short pointer at the top of ADR-0044 referencing ADR-0079 D8 + invariant `{N4}` is the full amendment. ADR-0044's body is otherwise untouched. The cross-reference in `adrs/README.md`'s ADR-0044 row is a one-sentence "Amended by ADR-0079" pointer.
- **Invariant 53 clarifying note is one line, appended to the existing entry.** Do not rewrite the invariant 53 text — append the ADR-0079 D7 sentence after the existing body.
- **`adrs/README.md` is append-only for this packet.** The 21-row backlog (ADR-0058 through ADR-0078) is real but explicitly out-of-scope. Append only the ADR-0079 row; defer the backfill to a separate housekeeping packet.
- **Initiative registration matches the dispatch plan.** `initiatives/active-initiatives.md` lists the five packets in the same wave structure as `dispatch-plan.md`.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0079`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0079 to Accepted, add the four PR-review-stack invariants (claim `{N1}`–`{N4}` from the reservation registry), amend ADR-0044 with the billing-path-discipline pointer, clarify invariant 53's canonical satisfaction, and register the initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0079 so the remaining packets in this initiative can reference its decisions as live rules and so the canonical reviewer stack is bound by invariants.
- Feature: ADR-0079 Multi-Perspective PR Review Stack, Wave 1.
- ADRs: ADR-0079 (primary), ADR-0044 (amended), ADR-0046 (Proposed — invariant 53 clarified; note ADR-0046 itself remains Proposed and is referenced for its specialist-agent invocation pattern, not as an Accepted constraint), ADR-0011 (Proposed — base review/merge flow referenced for context), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0079 stays Proposed until this PR merges.
- Claim the four-invariant block from `constitution/invariant-reservations.md`; substitute `{N1}`–`{N4}` placeholders with the claimed numbers; append under the existing `## Code Review Invariants` section; do not renumber existing invariants.
- ADR-0044 amendment is a short note pointing at ADR-0079 D8 and invariant `{N4}` — not a body rewrite.
- The invariant 53 clarification is one line appended to the existing entry.
- `adrs/README.md` is append-only for this packet — do not backfill the 21-row ADR-0058–ADR-0078 backlog.

**Key Files:**
- `adrs/ADR-0079-multi-perspective-pr-review-stack.md`
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
