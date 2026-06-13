---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0046", "wave-2"]
dependencies: ["work-item:01", "work-item:02"]
adrs: ["ADR-0046", "ADR-0044", "ADR-0015", "ADR-0028", "ADR-0042", "ADR-0007"]
accepts: ["ADR-0046"]
wave: 2
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Author the `performance` specialist agent (runtime performance and scalability)

## Summary
Author `.claude/agents/performance.md` — the runtime-performance specialist review agent. Its lens is runtime performance and scalability: allocations in hot paths, blocking calls in async code, inefficient loops, serialization overhead, N+1 queries, missing indexes, scalability under 10× load, concurrency safety, backpressure handling, batching, and resource efficiency. It is the **third** specialist authored per ADR-0046 D8 priority order; ADR-0046 D10 Phase 3.

## Context
ADR-0046 D8 places `performance` third: it applies to the deployable Nodes (Notify.Functions, Notify.Worker, Pulse.Collector) actively being deployed in the ADR-0015 rollout, and it should land ahead of any meaningful Notify Cloud volume. ADR-0046 D2 records that `performance` was promoted into the v1 roster on user direction (it was originally a D9 follow-up candidate).

The crucial scoping line, from ADR-0046 D7: `performance` focuses on **runtime characteristics, not dollar cost**. The cost-discipline sub-concern within ADR-0044 D3 category 6 stays with `cfo`; `performance` takes the runtime side of the same category. The agent file must make this split explicit.

This packet depends on packet 02, which authors `copilot/specialist-review-rules.md` — the definition-file template (mandatory section zero YAML frontmatter plus the six D4 prose sections) `performance.md` must follow.

## Scope
- `.claude/agents/performance.md` — **new file.** The `performance` specialist agent definition, following the section-zero-plus-six-section template.
- No change to `constitution/agent-capability-matrix.md` — the `performance` row stays "planned" here. The five matrix rows are flipped to "live" together in packet 08, after all five definition files exist, to avoid concurrent edits to the same table region.
- No change to `review.md` or any other agent file.

## Proposed Implementation
`performance.md` follows the template from `copilot/specialist-review-rules.md` — a mandatory **section zero: YAML frontmatter**, then the six D4 prose sections.

**Section zero — YAML frontmatter (mandatory).** The file MUST open with a `---`-delimited YAML block before any prose; without it Claude Code will not register the agent. Match the shape of every existing agent definition in this repo (see `.claude/agents/review.md`):
- `name: performance`
- `description:` — a folded scalar (`>-`) describing the runtime-performance-and-scalability lens and when to invoke `performance` (PRs touching hot paths, deployable Nodes, data-access layers, load-sensitive code).
- `tools:` — exactly `Read`, `Grep`, `Glob`, `WebSearch`. `performance` is a review-only agent: it reads code and produces advisory findings, it does not modify the repo. Do NOT include `Edit`, `Write`, `Bash`, or `Agent`.

The six D4 prose sections follow:

1. **Identity and scope.** Lens: runtime performance and scalability. **In scope:** allocations in hot paths, blocking calls in async code, inefficient loops, serialization overhead, N+1 queries, missing indexes, query patterns, scalability under 10× load, concurrency safety, backpressure handling, batching opportunities, resource efficiency (memory pressure, connection exhaustion, cache abuse, thread starvation, queue flooding). **Out of scope:** dollar cost of the resources consumed — that is the `cfo` agent's lens (ADR-0046 D7 splits category 6: runtime characteristics here, cost there).
2. **Mandatory context load.** The subject (PR diff or `scope` packet), plus the performance-relevant Grid context: which Nodes are deployable (Notify.Functions, Notify.Worker, Pulse.Collector per ADR-0015), the event-driven boundaries (ADR-0028) and async message-consumer paths, the idempotency contract for async boundaries (ADR-0042), and any tier-aware data-access patterns.
3. **Rubric — the runtime-performance checklist.** Author against recognized practice: hot-path allocation review (avoidable allocations in request handlers, message consumers, agent execution loops); async correctness (no blocking calls — `.Result`, `.Wait()`, `Thread.Sleep` — on async paths); algorithmic efficiency (loop nesting, repeated work); serialization overhead; data-access patterns (N+1 queries, missing indexes, unbatched round-trips); scalability questions (does this hold up at 10× current load); concurrency safety (shared mutable state, race conditions); backpressure and batching (does an async consumer handle flooding gracefully); resource efficiency (connection pooling, cache sizing, thread-pool pressure, queue depth). The rubric is parallel to but **deeper than** ADR-0044 D3's category 6 — name that category touchpoint explicitly and state the cost sub-concern is excluded (it belongs to `cfo`).
4. **Severity taxonomy.** `Block` / `Request Changes` / `Suggest`, identical to `copilot/pr-review-rules.md`. State the advisory posture per the new ADR-0046 invariant.
5. **Output format.** A structured verdict: an overall performance-posture summary, then findings grouped by severity, each naming the specific runtime concern and a remediation, with the hot-path or load scenario that makes it matter.
6. **Trigger conditions (described, not enforced).** PRs touching hot paths (request handlers, message consumers per ADR-0028/ADR-0042, agent execution loops); deployable Nodes (Notify.Functions, Notify.Worker, Pulse.Collector per ADR-0015); data-access layers; load-sensitive code in Notify Cloud (ADR-0027). State that at v1 the human is the trigger.

**Upstream-awareness section (D5).** `performance.md` must describe its authoring-time use case: invoked against an ADR draft or a `scope` packet for a deployable Node, `performance` surfaces scalability concerns **before the code is written** — e.g. a message-consumer design that will not handle queue flooding, caught at packet-scoping time, costs a packet revision rather than a production incident under load.

## Affected Files
- `.claude/agents/performance.md` (new)

## NuGet Dependencies
None. This packet creates and edits Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); it lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `.claude/agents/performance.md` exists and follows the template from `copilot/specialist-review-rules.md` — section zero (YAML frontmatter) plus the six D4 prose sections
- [ ] The file opens with a YAML frontmatter block: `name: performance`, a `description:`, and `tools:` set to exactly `Read, Grep, Glob, WebSearch` (no `Edit`/`Write`/`Bash`/`Agent`)
- [ ] The rubric covers hot-path allocations, async-blocking calls, algorithmic efficiency, serialization overhead, N+1 queries / missing indexes, scalability under 10× load, concurrency safety, backpressure/batching, and resource efficiency
- [ ] The file names the ADR-0044 D3 category touchpoint it deepens (category 6, Performance and Scalability) and explicitly excludes the cost sub-concern (which belongs to `cfo`)
- [ ] The upstream-awareness section describes the deployable-Node scalability use case at ADR/packet drafting time
- [ ] The severity taxonomy is `Block`/`Request Changes`/`Suggest` and the file states findings are advisory
- [ ] No edit to `constitution/agent-capability-matrix.md` in this packet — the `performance` row stays "planned"; the matrix flip to "live" is consolidated into packet 08
- [ ] The repo-level `CHANGELOG.md` gets an entry for the new agent

## Human Prerequisites
- [ ] After this PR merges, **re-sync the global agent hardlinks** so `performance` registers in `~/.claude/agents/`. A newly added Architecture agent file is not picked up until the hardlink re-sync command is run and Claude Code is restarted.

## Dependencies
- `work-item:01` — ADR-0046 acceptance.
- `work-item:02` — the specialist-agent pattern doc and the definition-file template (section zero plus the six D4 sections).

## Referenced ADR Decisions

**ADR-0046 D2** — `performance` is the runtime-performance-and-scalability specialist; promoted into the v1 roster on user direction.
**ADR-0046 D4** — Six prose-section definition-file structure, preceded by a mandatory section zero — YAML frontmatter — required for the file to register in Claude Code.
**ADR-0046 D5** — Upstream-aware: `performance` invoked against an ADR/packet for a deployable Node surfaces scalability concerns before code is written.
**ADR-0046 D7** — `performance` deepens category 6 (runtime characteristics); the cost sub-concern of category 6 stays with `cfo`.
**ADR-0046 D8 / D10** — `performance` is the third specialist authored; Phase 3.
**ADR-0015** — Names the deployable Nodes (Notify.Functions, Notify.Worker, Pulse.Collector) the `performance` lens weights toward.
**ADR-0028 / ADR-0042** — Event-driven architecture and the idempotency contract for async boundaries; the message-consumer hot paths the rubric inspects.
**ADR-0044** — The generalist `review` rubric `performance` deepens; not amended.

## Constraints
> **New ADR-0046 invariant:** Specialist review agents are advisory and complementary to the `review` agent. `performance` findings do not gate merge — the human is the final arbiter. The agent file must state this posture.

- **Runtime characteristics only — not dollar cost.** ADR-0046 D7 splits category 6: `performance` takes runtime, `cfo` takes cost. Do not let the `performance` rubric drift into cost analysis.
- **Follow the packet-02 template.** Use the section-zero-plus-six-section structure, not an ad-hoc layout. Section zero (YAML frontmatter with `name`/`description`/`tools`) is mandatory — a file without it does not register in Claude Code.
- **Do not edit `constitution/agent-capability-matrix.md`** — the matrix flip is consolidated into packet 08.

## Labels
`docs`, `tier-2`, `meta`, `adr-0046`, `wave-2`

## Agent Handoff

**Objective:** Author `.claude/agents/performance.md` — the runtime-performance-and-scalability specialist agent — following the template (section zero YAML frontmatter plus the six D4 prose sections).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the third specialist agent (ADR-0046 D8 priority #3); applicable to deployable-Node PRs in the ADR-0015 rollout.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 3.
- ADRs: ADR-0046 (primary), ADR-0044 (baseline rubric), ADR-0015 (deployable Nodes), ADR-0028/0042 (async boundaries), ADR-0007 (agent source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0046 acceptance.
- `work-item:02` — the specialist-agent pattern doc and template.

**Constraints:**
- Runtime characteristics only — dollar cost belongs to `cfo`.
- Follow the packet-02 template: mandatory YAML frontmatter section zero (`tools: Read, Grep, Glob, WebSearch`) plus the six D4 prose sections.
- Do not edit `constitution/agent-capability-matrix.md` — the matrix flip is consolidated into packet 08.

**Key Files:**
- `.claude/agents/performance.md` (new)
- `.claude/agents/review.md` (frontmatter-shape reference)
- `copilot/specialist-review-rules.md` (template reference)

**Contracts:** None.
