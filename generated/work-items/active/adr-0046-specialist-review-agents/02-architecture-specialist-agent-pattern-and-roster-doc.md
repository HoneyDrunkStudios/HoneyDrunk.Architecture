---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0046", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0046", "ADR-0044", "ADR-0007", "ADR-0011"]
accepts: ["ADR-0046"]
wave: 1
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Codify the specialist-agent pattern and register the roster in the capability matrix

## Summary
Author the shared specialist-agent reference doc (`copilot/specialist-review-rules.md`) that codifies ADR-0046's pattern — what a specialist agent is, the per-agent definition-file template all five must follow (D4), the manual-invocation discipline (D3), and the upstream-awareness clause (D5) — and register the five roster agents (`cfo`, `security`, `performance`, `ai-safety`, `a11y`) in `constitution/agent-capability-matrix.md` as "planned" rows so the names are visible at ADR/PDR drafting time before the individual definition files land.

## Context
ADR-0046 D2 names the roster but the per-agent definition files land incrementally (packets 03–07, phased over Week 1 through "when UI work starts"). Two problems follow from that staggering:

1. **The five definition files need a common template.** ADR-0046 D4 specifies six required prose sections for every `.claude/agents/{name}.md` specialist file (identity/scope, mandatory context load, rubric, severity taxonomy, output format, trigger conditions). On top of those six, every real agent definition in this repo opens with a **YAML frontmatter block** (`name:`, `description:`, `tools:`) before any prose — without it the file does not register in Claude Code at all. The template must therefore codify a mandatory **section zero: YAML frontmatter** ahead of the six prose sections. Authoring that template once — rather than re-deriving it in each of packets 03–07 — keeps the five files structurally consistent and gives each downstream packet a concrete skeleton to fill.
2. **The roster must be legible before the files exist.** ADR-0046's Operational Consequences explicitly states the mitigation for the manual-invocation discipline-failure risk ("I should have invoked `cfo` here and didn't") is that "the agent-capability-matrix is visible during ADR/PDR drafting in Claude Code; the names suggest themselves at the right moment." That mitigation only works if all five names are in the matrix from the start — including `a11y`, whose file may not land for months.

This packet is the pattern-codification half of Wave 1; packet 01 is the governance flip. Together they make ADR-0046's pattern real before any specialist file is authored.

## Scope
- `copilot/specialist-review-rules.md` — **new file.** The shared reference for the specialist-agent pattern: definition, the D4 six-section template, the D3 manual-invocation rule, the D5 upstream-awareness clause, and the D7 relationship to ADR-0044's twenty-category rubric.
- `constitution/agent-capability-matrix.md` — add five new rows (`cfo`, `security`, `performance`, `ai-safety`, `a11y`) to "The Agents" table, marked as planned/rolling-out, and a status note explaining the phased D8/D10 authoring order. Add the five to the Decision Tree where natural (a "Do I need a deep single-lens review?" branch pointing at the specialist roster).
- No `.claude/agents/{name}.md` specialist files (those are packets 03–07).
- No change to `.claude/agents/review.md` (the generalist is unchanged per ADR-0046 Consequences — "Existing agents are not modified").

## Proposed Implementation

### `copilot/specialist-review-rules.md`
The file establishes, in order:

1. **What a specialist agent is.** A narrow-lens, deeper-rigor reviewer that complements the generalist `review` agent. Quote ADR-0046 D1's cost/benefit boundary: `review` answers "Does this PR pass the Grid's shared standard across all 20 categories?" and runs always; a specialist answers "Does this PR pass the high bar on **this specific lens**?" and runs selectively. A specialist's findings do not displace `review` findings — both are advisory comments; the human is the final arbiter.
2. **The definition-file template — section zero plus the D4 six sections.** Every `.claude/agents/{name}.md` specialist file MUST open with **section zero: YAML frontmatter**, then carry the six D4 prose sections.

   **Section zero — YAML frontmatter (mandatory).** A `---`-delimited YAML block at the very top of the file, before any prose. Without it the file will NOT register in Claude Code. It matches the shape of every existing agent definition in this repo (see `.claude/agents/review.md`):
   - `name:` — the agent's invocation name (`cfo`, `security`, `performance`, `ai-safety`, `a11y`).
   - `description:` — a folded scalar (`>-`) describing the lens and when to invoke the agent; this is what surfaces in agent-selection UIs.
   - `tools:` — the tool allowlist. Specialist review agents are **review-only**: they read code and produce advisory findings, they do not modify the repo. Their `tools` list is therefore exactly `Read`, `Grep`, `Glob`, `WebSearch` — and explicitly **not** `Edit`, `Write`, `Bash`, or `Agent`. (This is narrower than the generalist `review` agent, which carries `Agent` and `TodoWrite`; a single-lens specialist does not delegate or track tasks.)

   The six D4 prose sections follow the frontmatter: (a) **Identity and scope** — the lens covered and what is explicitly out of scope; (b) **Mandatory context load** — files read before forming a verdict, paralleling ADR-0044 D2 for the generalist; (c) **Rubric** — the per-lens checklist, parallel to but **deeper than** the corresponding ADR-0044 D3 category; (d) **Severity taxonomy** — `Block` / `Request Changes` / `Suggest`, identical to `copilot/pr-review-rules.md`; (e) **Output format** — the structured verdict the human consumes; (f) **Trigger conditions** — described, not enforced at v1 (the human is the trigger). Provide section zero plus all six as a copy-paste skeleton so packets 03–07 fill it rather than re-derive it.
3. **The D3 manual-invocation rule.** Specialists are invoked manually by the human at v1 — no CI triggers, no PR-event-driven runs. The operator decides when a lens applies and invokes the named specialist via Claude Code or the cloud-wired review runner with the specialist agent named explicitly. State the three reasons from D3: trigger conditions are heuristic not exact; five specialists on every PR breaches the cost budget; the highest-value invocations are at ADR/PDR drafting time, not PR review time. State that CI-triggered invocation is a deferred follow-up (D9).
4. **The D5 upstream-awareness clause.** Specialists are not just PR reviewers — their lens applies at authoring time too. A specialist file must explicitly describe its authoring-time use cases (e.g. `cfo` invoked against an ADR draft, `security` invoked against a `scope` packet), not only its review-time use cases. State the load-bearing intent: lens depth applied upstream is materially cheaper than applied downstream.
5. **The D7 relationship to ADR-0044.** This pattern layers above ADR-0044's twenty-category rubric; it does not amend or subtract from it. Each specialist *deepens* a specific subset of the twenty categories — `cfo` deepens category 17 (cost sub-bullet), the cost/resource side of category 6, and the token/model-cost concerns within category 18; `security` deepens category 9; `performance` deepens category 6 (runtime characteristics, not dollar cost); `ai-safety` deepens category 18 (except the token/cost sub-bullet); `a11y` deepens the consumer-UX surface lightly addressed in category 16. The generalist `review` still runs all twenty.
6. **Cost discipline (D6).** Specialist invocations are LLM calls; the discipline that bounds them at v1 is manual invocation alone. Specialist cost rolls up under ADR-0044's review budget — no separate budget line.

### `constitution/agent-capability-matrix.md`
Add five rows to "The Agents" table. Suggested content (the execution agent may tighten wording):

| Agent | Trigger | Consumes | Produces | Does NOT do |
|-------|---------|----------|----------|-------------|
| **cfo** | Manual — ADR/PDR draft or PR touching cost, vendors, SKUs, recurring spend, or `IChatClient`/`IModelRouter`/`IAgent` code | The draft or PR diff, cost-relevant ADRs, App Configuration cost-rate context | Advisory cost-discipline findings (`Block`/`Request Changes`/`Suggest`) | Gate merge, make spend decisions, replace `review` |
| **security** | Manual — PR/packet touching Auth, Vault, tenant boundaries, public APIs, dependency updates | The diff or packet, security-relevant ADRs, OWASP body of practice | Advisory security findings | Gate merge, replace `review` |
| **performance** | Manual — PR touching hot paths, deployable Nodes, data-access layers, load-sensitive code | The diff, performance-relevant ADRs | Advisory runtime-performance findings | Gate merge, replace `review` |
| **ai-safety** | Manual — PR/ADR touching AI-sector Nodes, capability registrations, or `IChatClient`/`IModelRouter`/`IAgent` code | The diff or ADR, AI-sector ADRs | Advisory AI/agent-safety findings | Gate merge, replace `review` |
| **a11y** | Manual — PR/PDR touching UI surfaces (Studios site, future consumer apps) | The diff or PDR, WCAG body of practice | Advisory accessibility findings | Gate merge, replace `review` |

Add a status note below the table: the five specialists roll out across ADR-0046 packets 03–07 in priority order (`cfo` Phase 1, `security` Phase 2, `performance` Phase 3, `ai-safety` Phase 4, `a11y` Phase 5 when UI work starts); the rows are listed now so the roster is legible at ADR/PDR drafting time even before each definition file lands. The note also records that **the five rows are flipped from planned to live in a single later packet (packet 08)** once all five definition files exist — not incrementally by packets 03–07 — to avoid five concurrent edits to the same table region. In the Decision Tree, add a branch: "Do I need a deeper single-lens review than the generalist gives (cost, security, performance, AI-safety, accessibility)? → yes → the matching specialist agent (manual invocation)."

## Affected Files
- `copilot/specialist-review-rules.md` (new)
- `constitution/agent-capability-matrix.md`

## NuGet Dependencies
None. This packet creates and edits Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] `copilot/` and `constitution/` are Architecture-repo governance directories. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any repo.
- [x] No specialist `.claude/agents/{name}.md` file created here — those are packets 03–07.

## Acceptance Criteria
- [ ] `copilot/specialist-review-rules.md` exists and codifies: the specialist-vs-generalist boundary (D1), the definition-file template as a copy-paste skeleton — **section zero (mandatory YAML frontmatter: `name`/`description`/`tools`, with `tools` fixed to `Read, Grep, Glob, WebSearch` for these review-only agents) plus the D4 six prose sections** — the D3 manual-invocation rule with its three justifications, the D5 upstream-awareness clause, the D7 relationship to ADR-0044's twenty categories, and the D6 cost-discipline note
- [ ] The template's section-zero frontmatter block is shown verbatim as copy-paste skeleton and states explicitly that without frontmatter the agent file does not register in Claude Code
- [ ] `constitution/agent-capability-matrix.md` carries five new rows (`cfo`, `security`, `performance`, `ai-safety`, `a11y`) in "The Agents" table
- [ ] A status note in the matrix explains the phased D8/D10 authoring order and states the rows precede the definition files deliberately
- [ ] The Decision Tree carries a branch routing to the specialist roster for deep single-lens reviews
- [ ] No `.claude/agents/{name}.md` specialist file is created in this packet
- [ ] `.claude/agents/review.md` is unchanged (the generalist is not modified per ADR-0046 Consequences)
- [ ] The repo-level `CHANGELOG.md` gets an entry for the governance addition (new `copilot/` reference doc + matrix roster expansion)

## Human Prerequisites
None. Pure Architecture-repo governance-doc authoring.

## Dependencies
- `work-item:01` — ADR-0046 acceptance. The pattern doc references ADR-0046's decisions as live rules; soft dependency, but the doc should not land before the ADR is Accepted.

## Referenced ADR Decisions

**ADR-0046 D1** — Specialists complement, do not replace, `review`. The cost/benefit boundary: `review` runs always against twenty categories; specialists run selectively at high rigor on one lens. Both advisory.
**ADR-0046 D3** — Manual invocation only at v1. No CI triggers. Three justifications: heuristic triggers, cost budget, highest-value invocations are at drafting time.
**ADR-0046 D4** — Each specialist has its own `.claude/agents/{name}.md` file with six required prose sections (identity/scope, mandatory context load, rubric, severity taxonomy, output format, trigger conditions). The template adds a mandatory section zero — YAML frontmatter — ahead of the six, matching every existing agent definition in this repo, because Claude Code will not register a file that lacks it.
**ADR-0046 D5** — Specialists are upstream-aware; the ADR-0044 upstream-awareness clause applies recursively. Specialist files describe authoring-time use cases, not only review-time ones.
**ADR-0046 D6** — Cost discipline through manual invocation alone at v1; specialist cost rolls up under ADR-0044's review budget.
**ADR-0046 D7** — Layers above ADR-0044, does not amend it. Specialists deepen five of the twenty categories; no category is removed or downgraded.
**ADR-0046 D8 / D10** — Per-agent definitions are follow-up packets, authored in priority order across a phased rollout.
**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions; the capability matrix is the quick-reference card over it.

## Constraints
> **ADR-0046 Consequences — "Existing agents are not modified."** `review` keeps its twenty-category rubric; `scope`/`adr-composer`/`pdr-composer`/`refine`/`node-audit` keep their ADR-0044 upstream-awareness references. Specialists layer on top. Do not edit `review.md` or any existing agent file in this packet.

- **Do not author the specialist agent files here.** The five `.claude/agents/{name}.md` files are packets 03–07. This packet authors only the shared pattern doc and the matrix rows.
- **The template is a skeleton, not a filled file.** `specialist-review-rules.md` provides the section-zero-plus-six-section structure; the per-lens rubric content is authored per-agent in packets 03–07.
- **Section zero is non-negotiable.** The template must require the YAML frontmatter block (`name`/`description`/`tools`) as the file's opening, with `tools` fixed to `Read, Grep, Glob, WebSearch`. A specialist file without frontmatter does not register in Claude Code.
- **Do not amend ADR-0044.** The relationship is layering (D7), not amendment.

## Labels
`docs`, `tier-2`, `meta`, `adr-0046`, `wave-1`

## Agent Handoff

**Objective:** Author `copilot/specialist-review-rules.md` codifying ADR-0046's specialist-agent pattern and the D4 six-section template, and register the five roster agents in `constitution/agent-capability-matrix.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0046's pattern real and the roster legible before any specialist definition file lands.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 1.
- ADRs: ADR-0046 (D1/D3/D4/D5/D6/D7/D8/D10), ADR-0044 (baseline rubric, not amended), ADR-0007 (agent source of truth), ADR-0011 (advisory posture).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0046 acceptance (soft).

**Constraints:**
- Do not create specialist agent files (packets 03–07).
- Do not modify `review.md` or any existing agent file.
- Do not amend ADR-0044.

**Key Files:**
- `copilot/specialist-review-rules.md` (new)
- `constitution/agent-capability-matrix.md`

**Contracts:** None.
