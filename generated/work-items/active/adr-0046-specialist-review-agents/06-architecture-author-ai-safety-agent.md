---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0046", "wave-2"]
dependencies: ["work-item:01", "work-item:02"]
adrs: ["ADR-0046", "ADR-0044", "ADR-0016", "ADR-0017", "ADR-0007"]
accepts: ["ADR-0046"]
wave: 2
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Author the `ai-safety` specialist agent (AI / agent safety)

## Summary
Author `.claude/agents/ai-safety.md` — the AI/agent-safety specialist review agent. Its lens is AI and agent safety: prompt injection resistance, tool-permission scoping (least privilege), agent guardrails, output validation at trust boundaries, memory scoping, human override paths, and audit completeness for AI decisions. It is the **fourth** specialist authored per ADR-0046 D8 priority order; ADR-0046 D10 Phase 4.

## Context
ADR-0046 D8 places `ai-safety` fourth: its applicability climbs as the AI-sector standup wave progresses, and the AI-sector Node standup-ADR acceptance reviews would benefit from it. Today the need is low; it climbs to several invocations per week once Seed Nodes start shipping.

**AI-sector Node ADR range — verified.** The AI-sector Seed Node standup ADRs are ADR-0016 (HoneyDrunk.AI), ADR-0017 (Capabilities), ADR-0018 (Operator), and ADR-0020 through ADR-0025 (Agents, Knowledge, Memory, Evals, Flow, Sim) — nine ADRs in total. **ADR-0019 is HoneyDrunk.Communications, which is not an AI-sector Node** (it is an orchestration layer above Notify); it must be excluded from the `ai-safety` trigger range. The trigger range is therefore "ADR-0016 through ADR-0025, excluding ADR-0019."

The scoping line, from ADR-0046 D7: `ai-safety` deepens ADR-0044 D3 category 18 (AI / Agent-Specific) **except the token/cost sub-bullet**, which belongs to `cfo`. The agent file must make this split explicit — `ai-safety` covers behavioral safety; `cfo` covers token/model cost.

This packet depends on packet 02, which authors `copilot/specialist-review-rules.md` — the definition-file template (mandatory section zero YAML frontmatter plus the six D4 prose sections) `ai-safety.md` must follow.

## Scope
- `.claude/agents/ai-safety.md` — **new file.** The `ai-safety` specialist agent definition, following the section-zero-plus-six-section template.
- No change to `constitution/agent-capability-matrix.md` — the `ai-safety` row stays "planned" here. The five matrix rows are flipped to "live" together in packet 08, after all five definition files exist, to avoid concurrent edits to the same table region.
- No change to `review.md` or any other agent file.

## Proposed Implementation
`ai-safety.md` follows the template from `copilot/specialist-review-rules.md` — a mandatory **section zero: YAML frontmatter**, then the six D4 prose sections.

**Section zero — YAML frontmatter (mandatory).** The file MUST open with a `---`-delimited YAML block before any prose; without it Claude Code will not register the agent. Match the shape of every existing agent definition in this repo (see `.claude/agents/review.md`):
- `name: ai-safety`
- `description:` — a folded scalar (`>-`) describing the AI/agent-safety lens and when to invoke `ai-safety` (PRs/ADRs touching AI-sector Nodes, capability registrations, or `IChatClient`/`IModelRouter`/`IAgent` code).
- `tools:` — exactly `Read`, `Grep`, `Glob`, `WebSearch`. `ai-safety` is a review-only agent: it reads code and produces advisory findings, it does not modify the repo. Do NOT include `Edit`, `Write`, `Bash`, or `Agent`.

The six D4 prose sections follow:

1. **Identity and scope.** Lens: AI / agent safety. **In scope:** prompt injection resistance, tool-permission scoping (least privilege), agent guardrails, output validation at trust boundaries, memory scoping, human override paths, audit completeness for AI decisions. **Out of scope:** the token/cost side of AI work — model selection, prompt efficiency, token budgets — that is `cfo`'s lens (ADR-0046 D7). Also out of scope: general (non-AI) security — that is `security`'s lens; note that an AI-Node PR may warrant both `ai-safety` and `security`, and the human invokes both when both lenses apply.
2. **Mandatory context load.** The subject (PR diff, AI-sector standup ADR, or capability definition), plus the AI-relevant Grid context: the AI-sector Node catalog and the abstraction/runtime split (downstream AI-sector Nodes depend only on `HoneyDrunk.AI.Abstractions`), the capability-registration model (ADR-0017), and the AI invariants in `constitution/invariants.md` (model selection via `IModelRouter`, never hardcoded; routing policies and capability declarations sourced from App Configuration).
3. **Rubric — the AI-safety checklist.** Author against recognized AI-safety practice: prompt-injection resistance (is untrusted input that reaches a prompt treated as hostile); tool-permission scoping (does each tool/capability grant the least privilege necessary); agent guardrails (are there limits on what an agent loop can do unsupervised); output validation at trust boundaries (is model output validated before it crosses out of the AI boundary); memory scoping (is agent memory scoped per tenant/project, not globally readable); human override paths (can a human interrupt or veto an agent decision); audit completeness for AI decisions (is every consequential AI decision recorded attributably). The rubric is parallel to but **deeper than** ADR-0044 D3's category 18 — name that category touchpoint explicitly and state the token/cost sub-bullet is excluded (it belongs to `cfo`).
4. **Severity taxonomy.** `Block` / `Request Changes` / `Suggest`, identical to `copilot/pr-review-rules.md`. State the advisory posture per the new ADR-0046 invariant.
5. **Output format.** A structured verdict: an overall AI-safety-posture summary, then findings grouped by severity, each naming the specific safety concern and a remediation.
6. **Trigger conditions (described, not enforced).** PRs touching AI-sector Nodes — the nine Seed Node standup ADRs are ADR-0016 through ADR-0025 **excluding ADR-0019** (ADR-0019 is HoneyDrunk.Communications, not an AI-sector Node); any code calling `IChatClient` / `IModelRouter` / `IAgent`; capability registrations (ADR-0017). State that at v1 the human is the trigger.

**Upstream-awareness section (D5).** `ai-safety.md` must describe its authoring-time use case: invoked against an AI-sector standup ADR (the AI-sector standup ADRs — ADR-0016 through ADR-0025 excluding ADR-0019 — are still Proposed), `ai-safety` reviews **capability definitions and trust boundaries before the implementing Node ships**. State the load-bearing intent — a missing human-override path or an over-broad tool permission caught in the standup ADR costs an ADR amendment; caught after the Node ships costs a rebuild of the safety surface.

## Affected Files
- `.claude/agents/ai-safety.md` (new)

## NuGet Dependencies
None. This packet creates and edits Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); it lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `.claude/agents/ai-safety.md` exists and follows the template from `copilot/specialist-review-rules.md` — section zero (YAML frontmatter) plus the six D4 prose sections
- [ ] The file opens with a YAML frontmatter block: `name: ai-safety`, a `description:`, and `tools:` set to exactly `Read, Grep, Glob, WebSearch` (no `Edit`/`Write`/`Bash`/`Agent`)
- [ ] The trigger range names AI-sector Node standup ADRs as ADR-0016 through ADR-0025 excluding ADR-0019 (Communications, not an AI-sector Node)
- [ ] The rubric covers prompt injection resistance, tool-permission scoping, agent guardrails, output validation at trust boundaries, memory scoping, human override paths, and audit completeness for AI decisions
- [ ] The file names the ADR-0044 D3 category touchpoint it deepens (category 18, AI / Agent-Specific) and explicitly excludes the token/cost sub-bullet (which belongs to `cfo`)
- [ ] The file explicitly scopes general non-AI security OUT (that is the `security` agent's lens) and notes both may apply to one AI-Node PR
- [ ] The upstream-awareness section describes the AI-sector standup-ADR review use case
- [ ] The severity taxonomy is `Block`/`Request Changes`/`Suggest` and the file states findings are advisory
- [ ] No edit to `constitution/agent-capability-matrix.md` in this packet — the `ai-safety` row stays "planned"; the matrix flip to "live" is consolidated into packet 08
- [ ] The repo-level `CHANGELOG.md` gets an entry for the new agent

## Human Prerequisites
- [ ] After this PR merges, **re-sync the global agent hardlinks** so `ai-safety` registers in `~/.claude/agents/`. A newly added Architecture agent file is not picked up until the hardlink re-sync command is run and Claude Code is restarted.

## Dependencies
- `work-item:01` — ADR-0046 acceptance.
- `work-item:02` — the specialist-agent pattern doc and the definition-file template (section zero plus the six D4 sections).

## Referenced ADR Decisions

**ADR-0046 D2** — `ai-safety` is the AI/agent-safety specialist.
**ADR-0046 D4** — Six prose-section definition-file structure, preceded by a mandatory section zero — YAML frontmatter — required for the file to register in Claude Code.
**ADR-0046 D5** — Upstream-aware: `ai-safety` invoked against an AI-sector standup ADR reviews capability definitions and trust boundaries before the Node ships.
**ADR-0046 D7** — `ai-safety` deepens category 18 except the token/cost sub-bullet, which is `cfo`'s.
**ADR-0046 D8 / D10** — `ai-safety` is the fourth specialist authored; Phase 4.
**ADR-0016** — HoneyDrunk.AI standup; the abstraction/runtime split (downstream AI-sector Nodes depend only on `HoneyDrunk.AI.Abstractions`).
**ADR-0017** — Capabilities standup; the capability-registration model the `ai-safety` rubric inspects for tool-permission scoping.
**ADR-0044** — The generalist `review` rubric `ai-safety` deepens; not amended.

## Constraints
> **New ADR-0046 invariant:** Specialist review agents are advisory and complementary to the `review` agent. `ai-safety` findings do not gate merge — the human is the final arbiter. The agent file must state this posture.

> **Invariant 28:** Application code must never hardcode a model name or provider — all model selection goes through `IModelRouter`. The `ai-safety` rubric should flag any hardcoded model/provider as both a safety and a governance concern.

- **Do not duplicate the `cfo` or `security` lens.** Token/model cost belongs to `cfo`; general non-AI security belongs to `security`. `ai-safety` covers behavioral AI/agent safety only.
- **The AI-sector trigger range excludes ADR-0019.** ADR-0019 (HoneyDrunk.Communications) is not an AI-sector Node. The AI-sector Node standup ADRs are ADR-0016 through ADR-0025 excluding ADR-0019.
- **Follow the packet-02 template.** Use the section-zero-plus-six-section structure, not an ad-hoc layout. Section zero (YAML frontmatter with `name`/`description`/`tools`) is mandatory — a file without it does not register in Claude Code.
- **Do not edit `constitution/agent-capability-matrix.md`** — the matrix flip is consolidated into packet 08.

## Labels
`docs`, `tier-2`, `meta`, `adr-0046`, `wave-2`

## Agent Handoff

**Objective:** Author `.claude/agents/ai-safety.md` — the AI/agent-safety specialist agent — following the template (section zero YAML frontmatter plus the six D4 prose sections).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the fourth specialist agent (ADR-0046 D8 priority #4); applicable to AI-sector standup-ADR reviews.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 4.
- ADRs: ADR-0046 (primary), ADR-0044 (baseline rubric), ADR-0016 (AI standup), ADR-0017 (Capabilities), ADR-0007 (agent source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0046 acceptance.
- `work-item:02` — the specialist-agent pattern doc and template.

**Constraints:**
- Token/model cost is out of scope (that is `cfo`); general non-AI security is out of scope (that is `security`).
- The AI-sector trigger range is ADR-0016 through ADR-0025 excluding ADR-0019 (Communications).
- The rubric should flag hardcoded model/provider names (invariant 28).
- Follow the packet-02 template: mandatory YAML frontmatter section zero (`tools: Read, Grep, Glob, WebSearch`) plus the six D4 prose sections.
- Do not edit `constitution/agent-capability-matrix.md` — the matrix flip is consolidated into packet 08.

**Key Files:**
- `.claude/agents/ai-safety.md` (new)
- `.claude/agents/review.md` (frontmatter-shape reference)
- `copilot/specialist-review-rules.md` (template reference)

**Contracts:** None.
