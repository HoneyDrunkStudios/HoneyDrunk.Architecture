---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0046", "wave-2"]
dependencies: ["work-item:01", "work-item:02"]
adrs: ["ADR-0046", "ADR-0044", "ADR-0041", "ADR-0007"]
accepts: ["ADR-0046"]
wave: 2
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Author the `cfo` specialist agent (cost + AI-cost discipline)

## Summary
Author `.claude/agents/cfo.md` — the cost-discipline specialist review agent. Its lens is cost impact and vendor discipline, **including AI-cost** (token usage, model selection, prompt efficiency, prompt-caching, per-call and per-tenant cost ceilings). It is the **first** specialist authored per ADR-0046 D8 priority order, because it has the strongest retroactive justification: a `cfo` agent reviewing the ADR-0040/0045 first drafts would have caught the proposed ~$200/month Grafana Cloud + Sentry overcommit before it froze.

## Context
ADR-0046 D8 sequences the five specialist agents and puts `cfo` first: it has immediate retroactive value, it applies to every infrastructure/vendor ADR in flight or queued, and its AI-cost discipline applies as soon as any AI-Node code lands. ADR-0046 D10 Phase 1 is exactly this packet plus the retroactive calibration run that follows it (packet 08).

The `cfo` agent consolidates general cost discipline and AI-cost into one agent (ADR-0046 D2's consolidation note and the "Carve AI-cost out as its own agent" rejected alternative): the analytical framework — free-tier-first reasoning, justify-the-spend, prefer-cheaper-where-equivalent, document escalation triggers — is the same whether the subject is an Azure SKU choice or an LLM model choice. The per-domain detail lives in the rubric, not in a second agent.

This packet depends on packet 02, which authors `copilot/specialist-review-rules.md` — the definition-file template (mandatory section zero YAML frontmatter plus the six D4 prose sections) `cfo.md` must follow.

## Scope
- `.claude/agents/cfo.md` — **new file.** The `cfo` specialist agent definition, following the section-zero-plus-six-section template from `copilot/specialist-review-rules.md`.
- No change to `constitution/agent-capability-matrix.md` — the `cfo` row stays "planned" here. The five matrix rows are flipped to "live" together in packet 08, after all five definition files exist, to avoid concurrent edits to the same table region.
- No change to `review.md` or any other agent file.

## Proposed Implementation
`cfo.md` follows the template from `copilot/specialist-review-rules.md` — a mandatory **section zero: YAML frontmatter**, then the six D4 prose sections.

**Section zero — YAML frontmatter (mandatory).** The file MUST open with a `---`-delimited YAML block before any prose; without it Claude Code will not register the agent. Match the shape of every existing agent definition in this repo (see `.claude/agents/review.md`):
- `name: cfo`
- `description:` — a folded scalar (`>-`) describing the cost + AI-cost lens and when to invoke `cfo` (ADR/PDR drafts and PRs touching cost, vendors, SKUs, recurring spend, or `IChatClient`/`IModelRouter`/`IAgent` code).
- `tools:` — exactly `Read`, `Grep`, `Glob`, `WebSearch`. `cfo` is a review-only agent: it reads code and produces advisory findings, it does not modify the repo. Do NOT include `Edit`, `Write`, `Bash`, or `Agent`.

The six D4 prose sections follow:

1. **Identity and scope.** Lens: cost impact and vendor discipline, including AI-cost. **In scope:** free-tier-first reasoning, vendor relationship consolidation, recurring-spend justification, paid-tier defaults questioned, sunk-cost leverage, and the AI-cost sub-discipline (token usage analysis, model selection, prompt efficiency, prompt-caching opportunities, per-call and per-tenant cost ceilings). **Out of scope:** runtime performance characteristics that carry no dollar implication — that is the `performance` agent's lens (ADR-0046 D7 explicitly splits the cost sub-concern of category 6 to `cfo` and the runtime characteristics to `performance`).
2. **Mandatory context load.** Files `cfo` reads before forming a verdict — at minimum the subject (ADR/PDR draft, PR diff, or `scope` packet), plus the cost-relevant Grid context: the project's stated Azure subscription model and naming convention, any cost-rate or routing-policy App Configuration context, and recent ADRs that set cost precedent. Mirror the structure of ADR-0044 D2's context-loading list for the generalist.
3. **Rubric — the cost-discipline checklist.** Author it in two parts. **General cost discipline:** Is a free or already-paid-for tier viable before a new paid tier? Does this add a new vendor relationship when an existing one covers the use case? Is recurring spend justified and documented? Is a paid-tier default questioned rather than accepted silently? Is sunk cost (already-paid Azure capacity) leveraged before new spend? **AI-cost discipline:** Is model selection deliberate — a cheaper-model default with documented escalation triggers, rather than a premium model by reflex? Is token usage analyzed? Are prompt-caching opportunities taken? Are per-call cost ceilings and per-tenant period ceilings respected? The rubric is parallel to but **deeper than** ADR-0044 D3's cost sub-bullet of category 17, the cost/resource side of category 6, and the token/model-cost concerns within category 18 — name those three category touchpoints explicitly so the relationship to the baseline rubric is legible.
4. **Severity taxonomy.** `Block` / `Request Changes` / `Suggest`, identical to `copilot/pr-review-rules.md`. Note the advisory posture: per the new ADR-0046 invariant, `cfo` findings do not gate merge — the human is the final arbiter.
5. **Output format.** A structured verdict the human consumes: an overall cost-posture summary, then findings grouped by severity, each naming the specific cost concern and a cheaper-or-justified alternative.
6. **Trigger conditions (described, not enforced).** ADRs/PDRs touching infrastructure, dependencies, vendors, SKUs, or recurring costs; PRs adding new Azure resources or external service usage; any code calling `IChatClient` / `IModelRouter` / `IAgent`; capability registrations with cost implications. State that at v1 the human is the trigger (ADR-0046 D3).

**Upstream-awareness section (D5).** `cfo.md` must explicitly describe its authoring-time use case, not only its PR-review use case: invoked against an ADR or PDR draft, `cfo` challenges cost commitments **before they freeze**. Cite the load-bearing example — the ADR-0040/0045 pivot (Grafana Cloud + Sentry, ~$200/month) would have happened in the first draft rather than after a user-pushback round. State explicitly that catching a vendor overcommitment in an ADR draft costs an ADR amendment, while catching it after the account is created and the integration is built costs a migration.

Reference ADR-0041's cost profile (the AI model registry's Sonnet-default vs Opus-escalation policy) as the canonical model-selection precedent the AI-cost rubric draws on.

## Affected Files
- `.claude/agents/cfo.md` (new)

## NuGet Dependencies
None. This packet creates and edits Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); it lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `.claude/agents/cfo.md` exists and follows the template from `copilot/specialist-review-rules.md` — section zero (YAML frontmatter) plus the six D4 prose sections
- [ ] The file opens with a YAML frontmatter block: `name: cfo`, a `description:`, and `tools:` set to exactly `Read, Grep, Glob, WebSearch` (no `Edit`/`Write`/`Bash`/`Agent`)
- [ ] The rubric covers both general cost discipline and the AI-cost sub-discipline (token usage, model selection, prompt efficiency, caching, per-call and per-tenant ceilings)
- [ ] The file names the three ADR-0044 D3 category touchpoints `cfo` deepens (category 17 cost sub-bullet, the cost/resource side of category 6, the token/model-cost concerns within category 18)
- [ ] The file explicitly scopes runtime performance characteristics OUT (they belong to the `performance` agent)
- [ ] The upstream-awareness section describes the ADR/PDR-drafting use case and cites the ADR-0040/0045 example
- [ ] The severity taxonomy is `Block`/`Request Changes`/`Suggest` and the file states findings are advisory (the new ADR-0046 invariant)
- [ ] No edit to `constitution/agent-capability-matrix.md` in this packet — the `cfo` row stays "planned"; the matrix flip to "live" is consolidated into packet 08
- [ ] The repo-level `CHANGELOG.md` gets an entry for the new agent

## Human Prerequisites
- [ ] After this PR merges, **re-sync the global agent hardlinks** so `cfo` registers in `~/.claude/agents/`. The Architecture agents are hardlinked into `~/.claude/agents/`; a newly added agent file is not picked up until the hardlink re-sync command is run and Claude Code is restarted. See the re-sync note in the project memory entry on globally-linked Architecture agents.

## Dependencies
- `work-item:01` — ADR-0046 acceptance (the agent definition references ADR-0046 decisions as live rules).
- `work-item:02` — the specialist-agent pattern doc and the definition-file template (section zero plus the six D4 sections) `cfo.md` must follow.

## Referenced ADR Decisions

**ADR-0046 D2** — `cfo` is the cost + AI-cost specialist; AI-cost is folded into `cfo` rather than carved out because the analytical framework is identical.
**ADR-0046 D4** — Six prose-section definition-file structure (identity/scope, mandatory context load, rubric, severity taxonomy, output format, trigger conditions), preceded by a mandatory section zero — YAML frontmatter — required for the file to register in Claude Code.
**ADR-0046 D5** — Upstream-aware: `cfo` invoked against an ADR draft challenges cost commitments before they freeze.
**ADR-0046 D7** — `cfo` deepens category 17's cost sub-bullet, the cost/resource side of category 6, and the token/model-cost concerns of category 18. The runtime side of category 6 stays with `performance`.
**ADR-0046 D8 / D10** — `cfo` is the first specialist authored; Phase 1 is this packet plus the retroactive calibration run (packet 08).
**ADR-0041** — The AI model registry's cost profile (Sonnet-default, Opus-escalation) is the model-selection precedent the AI-cost rubric draws on.
**ADR-0044** — The generalist `review` rubric `cfo` deepens; not amended.

## Constraints
> **New ADR-0046 invariant:** Specialist review agents are advisory and complementary to the `review` agent. `cfo` findings do not gate merge — the human is the final arbiter. The agent file must state this posture.

- **`cfo` is one agent covering two domains.** Do not split AI-cost into a separate file — ADR-0046 D2 explicitly consolidates it.
- **Do not duplicate the `performance` lens.** Runtime characteristics with no dollar implication are out of `cfo`'s scope.
- **Follow the packet-02 template.** `cfo.md` must use the section-zero-plus-six-section structure from `copilot/specialist-review-rules.md`, not an ad-hoc layout. Section zero (YAML frontmatter with `name`/`description`/`tools`) is mandatory — a file without it does not register in Claude Code.

## Labels
`docs`, `tier-2`, `meta`, `adr-0046`, `wave-2`

## Agent Handoff

**Objective:** Author `.claude/agents/cfo.md` — the cost + AI-cost discipline specialist agent — following the template (section zero YAML frontmatter plus the six D4 prose sections).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the first specialist agent (ADR-0046 D8 priority #1); enables the Phase-1 retroactive calibration run in packet 08.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 1.
- ADRs: ADR-0046 (primary), ADR-0044 (baseline rubric), ADR-0041 (AI cost profile), ADR-0007 (agent source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0046 acceptance.
- `work-item:02` — the specialist-agent pattern doc and template.

**Constraints:**
- One agent, two domains (cost + AI-cost); do not split.
- Runtime performance with no dollar implication is out of scope.
- Follow the packet-02 template: mandatory YAML frontmatter section zero (`tools: Read, Grep, Glob, WebSearch`) plus the six D4 prose sections.
- Do not edit `constitution/agent-capability-matrix.md` — the matrix flip is consolidated into packet 08.

**Key Files:**
- `.claude/agents/cfo.md` (new)
- `.claude/agents/review.md` (frontmatter-shape reference)
- `copilot/specialist-review-rules.md` (template reference)

**Contracts:** None.
