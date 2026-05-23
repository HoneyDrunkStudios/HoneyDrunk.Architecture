---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0046", "wave-3"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0046", "ADR-0044", "ADR-0029", "ADR-0007"]
accepts: ["ADR-0046"]
wave: 3
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Author the `a11y` specialist agent (accessibility / WCAG)

## Summary
Author `.claude/agents/a11y.md` — the accessibility specialist review agent. Its lens is accessibility (WCAG): semantic HTML, keyboard navigation, screen-reader behavior, focus management, color contrast, ARIA correctness, and form labels. It is the **fifth and last** specialist authored per ADR-0046 D8 priority order; ADR-0046 D10 Phase 5.

## Context
ADR-0046 D8 places `a11y` fifth with explicit reasoning: there is **zero immediate need** — no UI work is in flight today — but the file should land before the first consumer-app PR so accessibility is baked in rather than bolted on. ADR-0046 D10 Phase 5 is gated on "when UI work starts."

This packet is placed in **Wave 3** of the initiative rather than Wave 2 deliberately, to reflect that `a11y` has no near-term invocation surface. It is still authored within this initiative — rather than deferred to a future ADR — because ADR-0046's Operational Consequences require the full roster legible in the capability matrix from the start, and authoring all five files keeps the roster real rather than aspirational. The file sits ready; the human invokes it when consumer-app UI work begins.

This packet depends on packet 02, which authors `copilot/specialist-review-rules.md` — the definition-file template (mandatory section zero YAML frontmatter plus the six D4 prose sections) `a11y.md` must follow.

## Scope
- `.claude/agents/a11y.md` — **new file.** The `a11y` specialist agent definition, following the section-zero-plus-six-section template.
- No change to `constitution/agent-capability-matrix.md` — the `a11y` row stays "planned" here. The five matrix rows are flipped to "live" together in packet 08, after all five definition files exist, to avoid concurrent edits to the same table region.
- No change to `review.md` or any other agent file.

## Proposed Implementation
`a11y.md` follows the template from `copilot/specialist-review-rules.md` — a mandatory **section zero: YAML frontmatter**, then the six D4 prose sections.

**Section zero — YAML frontmatter (mandatory).** The file MUST open with a `---`-delimited YAML block before any prose; without it Claude Code will not register the agent. Match the shape of every existing agent definition in this repo (see `.claude/agents/review.md`):
- `name: a11y`
- `description:` — a folded scalar (`>-`) describing the accessibility/WCAG lens and when to invoke `a11y` (PRs/PDRs touching UI surfaces — the Studios site and future consumer apps).
- `tools:` — exactly `Read`, `Grep`, `Glob`, `WebSearch`. `a11y` is a review-only agent: it reads code and produces advisory findings, it does not modify the repo. Do NOT include `Edit`, `Write`, `Bash`, or `Agent`.

The six D4 prose sections follow:

1. **Identity and scope.** Lens: accessibility (WCAG). **In scope:** semantic HTML, keyboard navigation, screen-reader behavior, focus management, color contrast, ARIA correctness, form labels. **Out of scope:** general developer-experience and non-accessibility UX — the generalist `review` agent's category 16 covers that broadly; `a11y` is the accessibility-specific deepening of the consumer-UX surface. Out of scope also: backend/API code with no rendered UI.
2. **Mandatory context load.** The subject (PR diff or PDR draft), plus the UI-relevant Grid context: the Studios marketing site stack (ADR-0029) and, when they exist, the consumer-app stacks; the WCAG body of practice (WCAG 2.2 AA as the baseline target unless a PDR sets otherwise).
3. **Rubric — the accessibility checklist.** Author against WCAG: semantic HTML (correct landmark and heading structure, native elements over `div` soup); keyboard navigation (every interactive element reachable and operable by keyboard, logical tab order); screen-reader behavior (meaningful accessible names, no announcement gaps); focus management (visible focus indicators, focus moved correctly on route/modal changes, no focus traps); color contrast (text and UI components meet WCAG AA contrast ratios); ARIA correctness (ARIA used only where native semantics fall short, no broken or redundant ARIA); form labels (every input has a programmatically associated label, errors announced). The rubric is parallel to but **deeper than** what ADR-0044 D3 category 16 lightly addresses — name that category touchpoint explicitly and note ADR-0046 D7's observation that the baseline rubric only lightly covers consumer UX because the Grid is solo-dev-API-heavy today.
4. **Severity taxonomy.** `Block` / `Request Changes` / `Suggest`, identical to `copilot/pr-review-rules.md`. State the advisory posture per the new ADR-0046 invariant.
5. **Output format.** A structured verdict: an overall accessibility-posture summary, then findings grouped by severity, each naming the WCAG success criterion at issue and a remediation.
6. **Trigger conditions (described, not enforced).** PRs touching UI surfaces — the Studios marketing site (ADR-0029) and future consumer apps (PDR-0003 / 0005 / 0006 / 0007 / 0008). State that at v1 the human is the trigger and that the lens is dormant until consumer-app UI work begins.

**Upstream-awareness section (D5).** `a11y.md` must describe its authoring-time use case: invoked at **PDR-composition time** for consumer apps (PDR-0003 onward), `a11y` bakes accessibility into the product definition rather than bolting it on at UI-implementation time. State the load-bearing intent — accessibility designed into a product definition costs nothing extra; accessibility retrofitted onto a shipped UI costs a rework pass and risks the accessibility-lawsuit failure mode ADR-0046 D2 names.

## Affected Files
- `.claude/agents/a11y.md` (new)

## NuGet Dependencies
None. This packet creates and edits Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); it lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `.claude/agents/a11y.md` exists and follows the template from `copilot/specialist-review-rules.md` — section zero (YAML frontmatter) plus the six D4 prose sections
- [ ] The file opens with a YAML frontmatter block: `name: a11y`, a `description:`, and `tools:` set to exactly `Read, Grep, Glob, WebSearch` (no `Edit`/`Write`/`Bash`/`Agent`)
- [ ] The rubric covers semantic HTML, keyboard navigation, screen-reader behavior, focus management, color contrast, ARIA correctness, and form labels, against WCAG 2.2 AA as the baseline
- [ ] The file names the ADR-0044 D3 category touchpoint it deepens (category 16, Developer Experience — the consumer-UX surface) and notes the baseline rubric covers it only lightly
- [ ] The upstream-awareness section describes the PDR-composition-time use case for consumer apps
- [ ] The severity taxonomy is `Block`/`Request Changes`/`Suggest` and the file states findings are advisory
- [ ] No edit to `constitution/agent-capability-matrix.md` in this packet — the `a11y` row stays "planned"; the matrix flip to "live" (with the dormant-lens note) is consolidated into packet 08
- [ ] The repo-level `CHANGELOG.md` gets an entry for the new agent

## Human Prerequisites
- [ ] After this PR merges, **re-sync the global agent hardlinks** so `a11y` registers in `~/.claude/agents/`. A newly added Architecture agent file is not picked up until the hardlink re-sync command is run and Claude Code is restarted. (This also completes the five-agent roster — re-sync once after this packet covers it if packets 03–06 were merged together.)

## Dependencies
- `packet:01` — ADR-0046 acceptance.
- `packet:02` — the specialist-agent pattern doc and the definition-file template (section zero plus the six D4 sections).

## Referenced ADR Decisions

**ADR-0046 D2** — `a11y` is the accessibility specialist; WCAG is the body of practice it draws on. Accessibility lawsuits are a named high-stakes failure mode.
**ADR-0046 D4** — Six prose-section definition-file structure, preceded by a mandatory section zero — YAML frontmatter — required for the file to register in Claude Code.
**ADR-0046 D5** — Upstream-aware: `a11y` invoked at PDR-composition for consumer apps bakes accessibility into the product definition.
**ADR-0046 D7** — `a11y` deepens what is implicitly in category 16 (the consumer-UX surface the baseline rubric only lightly addresses).
**ADR-0046 D8 / D10** — `a11y` is the fifth and last specialist authored; Phase 5, gated on "when UI work starts." Placed in Wave 3 of this initiative to reflect zero near-term invocation surface.
**ADR-0029** — The Studios marketing-site stack — the existing UI surface `a11y` reviews.
**ADR-0044** — The generalist `review` rubric `a11y` deepens; not amended.

## Constraints
> **New ADR-0046 invariant:** Specialist review agents are advisory and complementary to the `review` agent. `a11y` findings do not gate merge — the human is the final arbiter. The agent file must state this posture.

- **The agent file is authored now; the lens is dormant.** ADR-0046 D8 is explicit that `a11y` has zero immediate need — the file lands ready, invocation waits for consumer-app UI work. Do not treat dormancy as a reason to defer authoring.
- **Follow the packet-02 template.** Use the section-zero-plus-six-section structure, not an ad-hoc layout. Section zero (YAML frontmatter with `name`/`description`/`tools`) is mandatory — a file without it does not register in Claude Code.
- **Do not edit `constitution/agent-capability-matrix.md`** — the matrix flip is consolidated into packet 08.

## Labels
`docs`, `tier-2`, `meta`, `adr-0046`, `wave-3`

## Agent Handoff

**Objective:** Author `.claude/agents/a11y.md` — the accessibility/WCAG specialist agent — following the template (section zero YAML frontmatter plus the six D4 prose sections).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the fifth and last specialist agent (ADR-0046 D8 priority #5); the file sits ready ahead of the first consumer-app UI PR.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 5.
- ADRs: ADR-0046 (primary), ADR-0044 (baseline rubric), ADR-0029 (Studios site), ADR-0007 (agent source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0046 acceptance.
- `packet:02` — the specialist-agent pattern doc and template.

**Constraints:**
- Author the file now even though the lens is dormant until UI work starts.
- Follow the packet-02 template: mandatory YAML frontmatter section zero (`tools: Read, Grep, Glob, WebSearch`) plus the six D4 prose sections.
- Do not edit `constitution/agent-capability-matrix.md` — the matrix flip is consolidated into packet 08.

**Key Files:**
- `.claude/agents/a11y.md` (new)
- `.claude/agents/review.md` (frontmatter-shape reference)
- `copilot/specialist-review-rules.md` (template reference)

**Contracts:** None.
