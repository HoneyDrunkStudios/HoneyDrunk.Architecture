# ADR-0046: Specialist Review Agents

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

ADR-0044 D3 binds the `review` agent (and authoring agents per the upstream-awareness clause) to a twenty-category rubric covering correctness, architectural integrity, maintainability, reuse, SOLID, performance, reliability, observability, security, enterprise readiness, testing, API design, data integrity, distributed systems concerns, CI/CD, DX, business alignment, AI/agent-specific concerns, anti-entropy, and human factors. That rubric is broad by design — it's the **Grid's shared standard for what makes a change defensible**, applied by every author and the reviewer.

The trade-off of a broad rubric is depth. The `review` agent applying twenty categories must be **broadly competent on each**, but cannot be deeply rigorous on any one of them within the per-PR cost budget (ADR-0044 D5's $5 per-PR cap). The recent ADR-0040 / ADR-0045 pivot illustrated the gap concretely: the first draft of those ADRs proposed Grafana Cloud + Sentry as the v1 backend, committing to ~$200/month of new vendor spend before considering that Azure was already paid for and App Insights covered the use case. A dedicated cost-watchdog reviewing the first draft would have caught that drift; the generalist `review` agent's Cost-Discipline checklist (ADR-0044 category 4) covers it in principle but not with the rigor a specialist applies.

The pattern: **specialist agents per lens, narrower scope, deeper rigor, invoked selectively when the lens applies.** Not every agent runs on every PR. The `cfo` agent doesn't weigh in on a typo fix; it weighs in on infrastructure ADRs. The `a11y` agent doesn't review Kernel.Abstractions changes; it reviews UI work. Specialists complement the `review` agent's baseline rubric, they do not replace it.

The forcing functions for codifying this now:

- **Agent sprawl risk.** The Grid has ~17 agents today (per `.claude/agents/`). Adding specialists ad-hoc, without a pattern, produces a roster nobody can maintain and triggers nobody can predict. Codifying the pattern up front makes the roster legible.
- **ADR-0044 just landed** with its 20-category rubric and upstream-awareness clause. That ADR's intent is the **baseline**; this ADR's intent is the **depth-on-demand layer above it**.
- **The five highest-leverage lenses are recognizable today.** CFO (including AI-cost), accessibility, security, performance, and AI safety each have concrete recurring needs that the generalist rubric only partially covers. Naming the roster while it's fresh prevents lens-by-lens improvisation.
- **The cost discipline lens specifically would have prevented the ADR-0040/0045 first-draft cost overcommit.** That's the immediate, retroactively-justifying use case.

This ADR codifies the **pattern** (specialist agents per lens, manual invocation at v1) and names the **initial roster of five** with their intended lenses. Per-agent definition files (`.claude/agents/cfo.md`, `.claude/agents/a11y.md`, `.claude/agents/security.md`, `.claude/agents/performance.md`, `.claude/agents/ai-safety.md`) land as follow-up packets. CI-triggered invocation and output-format / failure-mode discipline are explicitly deferred per the manual-first commitment.

## Decision

### D1 — Specialist agents complement, do not replace, the `review` agent

The `review` agent (per ADR-0011 and ADR-0044) remains the **baseline reviewer** with the full 20-category rubric. It runs on every PR; specialist agents do not. Specialists are **depth specialists** invoked when their lens specifically applies.

The cost / benefit boundary:

- **`review` (generalist):** "Does this PR pass the Grid's shared standard across all 20 categories?" Broadly competent, runs always (per ADR-0044 D2 differential intensity).
- **Specialist agents:** "Does this PR pass the high bar on **this specific lens** that warrants more rigor than the generalist applies?" Narrowly focused, runs selectively.

A specialist's findings do **not** displace `review` findings; both are advisory comments on the PR. The human is the final arbiter of which findings warrant action.

### D2 — Initial roster: five specialist agents

The starter roster names the five lenses with the highest recurring leverage at this stage of the Grid:

| Agent | Lens | Primary concerns | When to invoke (v1: manual) |
|-------|------|------------------|------------------------------|
| **`cfo`** | Cost impact and vendor discipline (**including AI-cost**) | Free-tier-first reasoning, vendor relationship consolidation, recurring-spend justification, paid-tier defaults questioned, sunk-cost leverage. **AI-cost specifically:** token usage analysis, model selection (Sonnet-default vs Opus-escalation per ADR-0041 cost profile), prompt efficiency, prompt-caching opportunities, per-call cost ceilings (ADR-0041 D6) and per-tenant period ceilings (ADR-0018 `ICostGuard`). | ADRs/PDRs touching infrastructure, dependencies, vendors, SKUs, or recurring costs; PRs adding new Azure resources or external service usage; **any code calling `IChatClient` / `IModelRouter` / `IAgent`**; capability registrations with cost implications |
| **`a11y`** | Accessibility (WCAG) | Semantic HTML, keyboard navigation, screen reader behavior, focus management, color contrast, ARIA correctness, form labels | PRs touching UI surfaces (Studios marketing site per ADR-0029; future consumer apps per PDR-0003 / 0005 / 0006 / 0007 / 0008) |
| **`security`** | Security review | OWASP top 10, threat modeling, auth/secret/PII handling, supply chain, injection surfaces, trust-boundary integrity | PRs touching Auth (ADR-0031), Vault (ADR-0005/0006), tenant boundaries (ADR-0026), public APIs, dependency updates (per ADR-0009) |
| **`performance`** | Runtime performance and scalability | Allocations in hot paths, blocking calls in async code, inefficient loops, serialization overhead, N+1 queries, missing indexes, query patterns, scalability under 10× load, concurrency safety, backpressure handling, batching opportunities, resource efficiency (memory pressure, connection exhaustion, cache abuse, thread starvation, queue flooding) | PRs touching hot paths (request handlers, message consumers per ADR-0028 / ADR-0042, agent execution loops); deployable Nodes (Notify.Functions, Notify.Worker, Pulse.Collector per ADR-0015); data access layers (per ADR-0036 tier-aware nodes); load-sensitive code in Notify Cloud (per ADR-0027) |
| **`ai-safety`** | AI / agent safety | Prompt injection resistance, tool permission scoping (least privilege), agent guardrails, output validation at trust boundaries, memory scoping, human override paths, audit completeness for AI decisions | PRs touching AI-sector Nodes (the 9 Seed Nodes from ADR-0016 through ADR-0025); any code calling `IChatClient` / `IModelRouter` / `IAgent`; capability registrations (per ADR-0017) |

**On the AI-cost / `cfo` consolidation specifically:** AI-cost is folded into `cfo` rather than carved out as its own agent because the analytical framework is **the same** — free-tier-first reasoning, justify-the-spend, prefer-cheaper-where-equivalent, document escalation triggers. The model-selection / prompt-efficiency / cache-opportunity sub-discipline is just the AI-flavored expression of the same lens. Splitting it produced two agents with overlapping rubrics and no clear invocation boundary; consolidating gives one agent with a richer prompt that handles both vendor SKU choices and LLM model choices under one cost-discipline framework.

These five were chosen on three criteria:

1. **The lens has high-stakes failure modes** (overspend, accessibility lawsuits, security incidents, AI misbehavior).
2. **The generalist `review` agent provably under-covers the lens** at the depth that matters — recent evidence in the CFO case (ADR-0040 first draft), upcoming evidence likely in the others.
3. **The lens has dedicated body of practice** the specialist can draw from (WCAG for a11y, OWASP for security, etc.) — specialists earn their keep because there's a real specialty to apply.

Other lenses considered (privacy/GDPR, SRE, migration safety, anti-entropy, DX) are explicit follow-up candidates per D9, not v1. Performance was promoted into the v1 roster on user direction; AI-cost was folded into `cfo` rather than carved out, per the consolidation note above.

### D3 — Manual invocation only at v1

Specialist agents are **invoked manually by the human** at v1. No CI triggers, no automatic invocation, no PR-event-driven runs. The operator decides when a lens applies and invokes the relevant specialist via Claude Code or the cloud-wired `job-review-agent.yml` (per ADR-0044) **with the specialist agent named explicitly**.

This is the same discipline that ADR-0011 D10 originally applied to the `review` agent before ADR-0044 reversed it — but reversed for a different reason. The `review` agent ran on every PR; making it automatic at scale was load-bearing for catching the discipline-failure mode of "human forgets." Specialists, by contrast, do **not** run on every PR; their invocation is inherently context-dependent. Manual is the right default because:

- **The trigger conditions in D2 are heuristic, not exact.** "PRs touching UI" requires judgment about what counts as UI. Automatic invocation on path globs would produce a population of false-positive invocations.
- **Cost discipline.** Five specialists × every PR × LLM cost = budget breach. Manual invocation keeps the population small.
- **The most valuable invocations are at ADR/PDR drafting time**, not at PR review time. The CFO agent's biggest win is challenging an ADR draft before it commits to a vendor relationship — that's a human-invoked moment, not a CI-triggered one.

CI-triggered invocation is a deferred follow-up per D9 if the manual cadence proves insufficient.

### D4 — Each specialist has its own agent definition file

Per ADR-0007's "agents-as-source-of-truth" rule, each specialist lives at `.claude/agents/{name}.md`. The file contains:

- **Identity and scope** — what lens this agent covers, what it explicitly does not cover.
- **Mandatory context load** — files this agent reads before forming a verdict (paralleling ADR-0011 D4 / ADR-0044 D2 for the generalist).
- **Rubric** — the per-lens checklist, parallel to but **deeper than** the corresponding ADR-0044 D3 categories.
- **Severity taxonomy** — `Block` / `Request Changes` / `Suggest`, same as ADR-0011 / ADR-0044 / `copilot/pr-review-rules.md`.
- **Output format** — structured verdict the human (or the automatic case, if D9 ever lands) consumes.
- **Trigger conditions** — described, not enforced at v1 (the human is the trigger).

Agent definitions are authored as follow-up packets, not in this ADR.

### D5 — Specialists are upstream-aware

The ADR-0044 D3 upstream-awareness clause applies recursively. Specialists are not just reviewers — their lens applies at **authoring time** too:

- **`cfo`** invoked against an ADR draft challenges cost commitments before they freeze. The ADR-0040/0045 pivot would have happened in the first draft, not after a user pushback round.
- **`a11y`** invoked at PDR-composition for consumer apps (PDR-0003 onward) bakes accessibility into the product definition, not bolts it on at UI implementation time.
- **`security`** invoked against the `scope` agent's packet for any Auth/Vault/tenant-boundary work surfaces threat modeling before code is written.
- **`ai-safety`** invoked against AI-sector standup ADRs (ADR-0017 through ADR-0025 still Proposed) reviews capability definitions and trust boundaries before the implementing Node ships.

This is the load-bearing intent of the specialist pattern: **lens depth applied upstream is materially cheaper than lens depth applied downstream**. Catching a vendor overcommitment in an ADR draft costs an ADR amendment. Catching it after the vendor account is created and the integration is built costs a migration.

Specialist agent files reference ADR-0044 D3 (upstream-awareness) and explicitly describe their authoring-time use cases, not only their review-time use cases.

### D6 — Cost discipline through manual invocation

Specialist invocations are LLM calls; each has a cost. The discipline that keeps this bounded is **manual invocation alone**. v1 has no automatic firing.

The expected invocation frequency at current Grid cadence:

- `cfo` — once or twice per month for ADR/PDR drafts that touch cost; additional invocations for code touching `IChatClient`/`IModelRouter` (which is currently zero but will climb with the AI-sector standup wave). The recent observability ADRs would have been the recent invocations.
- `a11y` — zero until consumer apps standup; then per UI PR.
- `security` — once per week on average (Auth/Vault/public-API PRs are routine but not constant).
- `performance` — once or twice per week, weighted toward PRs touching deployable Nodes (Notify Functions/Worker, Pulse Collector) and data access layers.
- `ai-safety` — increases as the AI-sector standup wave progresses; today low, climbing to several per week once Seed Nodes start shipping.

Combined: ~8–20 specialist invocations per month at v1. At ADR-0044's per-PR cost model (~$0.50–2 per invocation), the marginal monthly cost is single-digit-to-low-double-digit dollars. Rolls up under ADR-0044's $40–100/month cloud-review budget; no separate budget line.

If CI triggers are ever added (D9), the discipline shifts to **trigger specificity** instead — false-positive invocations are the cost-killer.

### D7 — Relationship to ADR-0044 and the rubric

This ADR **layers above** ADR-0044, it does not amend it. Specifically:

- **ADR-0044 D3's twenty categories** remain the baseline rubric. The `review` agent applies all twenty as today.
- **Specialists deepen five of the twenty categories** with dedicated lenses:
  - `cfo` deepens category 17 (Product / Business Alignment — cost-awareness sub-bullet), the cost discipline sub-bullet of category 4 (Security / Performance), and the **token / model-cost concerns within category 18** (AI / Agent-Specific — observability sub-bullet on token and cost tracking). One agent, three category touchpoints, single cost-discipline framework.
  - `a11y` deepens what is implicitly in category 16 (Developer Experience — and consumer UX more broadly, which the ADR-0044 rubric only lightly addresses because the Grid is solo-dev-API-heavy today).
  - `security` deepens category 9 (Security) — same lens, more rigor.
  - `performance` deepens category 6 (Performance and Scalability) — same lens, more rigor. Note: the cost-discipline sub-concern within category 6 stays with `cfo`; `performance` focuses on runtime characteristics, not dollar cost.
  - `ai-safety` deepens category 18 (AI / Agent-Specific, except the token/cost sub-bullet which is `cfo`'s) — same lens, more rigor.
- **No ADR-0044 categories are removed or downgraded** because specialists exist for them. The generalist `review` still runs the full rubric; specialists add depth on top, they don't subtract from the baseline.

ADR-0044's upstream-awareness clause is preserved and **extended** by D5 — authoring agents also benefit from specialist input at their respective surfaces.

### D8 — Per-agent definitions are follow-up packets

Each of the five agents gets a dedicated follow-up packet to author its `.claude/agents/{name}.md` file. The packets land in priority order:

1. **`cfo`** first — immediate retroactive value (would have caught the ADR-0040/0045 first-draft cost overcommit); applicable to every infrastructure/vendor ADR in flight or queued; AI-cost discipline applies as soon as any AI-Node code lands.
2. **`security`** second — applicable to ADR-0034 (NuGet signing), ADR-0037 (Stripe integration), ADR-0038 (sender deliverability), and ongoing.
3. **`performance`** third — applicable to the deployable Nodes (Notify.Functions, Notify.Worker, Pulse.Collector) actively being deployed per `initiatives/current-focus.md`; lands ahead of any meaningful Notify Cloud volume.
4. **`ai-safety`** fourth — applicable as the AI-sector standup wave progresses; ADR-0017 through ADR-0025 acceptance reviews would benefit.
5. **`a11y`** fifth — zero immediate need (no UI work in flight); lands before the first consumer-app PR.

Each packet creates one agent file, references this ADR as the governing decision, and updates `constitution/agent-capability-matrix.md` to register the new agent.

### D9 — Deferred work

Explicitly deferred:

- **CI-triggered invocation.** If the manual cadence proves insufficient — operator regularly wishes a specialist had run on a PR they forgot to invoke — a follow-up ADR amends D3 to add trigger-based automatic invocation. Until then, manual.
- **Output format standardization.** Manual invocation means the human sees the output in their session and acts on it; format consistency matters less than for an automated comment surface. If D9 lands automatic invocation, output format becomes load-bearing and gets decided then.
- **Failure-mode discipline.** "What stops `cfo` from blocking every PR because it's $5/month?" is moot under manual invocation — the human only invokes when they want the lens. Becomes load-bearing if D9 lands automation.
- **Roster expansion.** Privacy/GDPR, SRE, migration safety, anti-entropy, DX are all real candidates. Each lands as a future amendment with the same justification structure D2 used. (Performance was promoted into v1 per user direction; AI-cost is folded into `cfo` rather than carved out.)
- **Specialist-of-specialists.** A meta-agent that decides which specialists to invoke on a given PR is interesting but speculative; only relevant if D9 lands automation.

### D10 — Phased rollout

- **Phase 1 (Week 1–2)** — Author `.claude/agents/cfo.md` (per D8 priority). Retroactively invoke against the open PR #162 (this ADR family) and capture any findings as commits on the same branch. Treat the retroactive run as the v1 calibration: if `cfo` produces useful findings against an already-revised PR, it earns its keep.
- **Phase 2 (Week 3–4)** — Author `.claude/agents/security.md`. Invoke against ADR-0034 / 0037 / 0038 as they're refined.
- **Phase 3 (Week 5–6)** — Author `.claude/agents/performance.md`. Invoke against deployable-Node PRs in the active ADR-0015 rollout (Notify Functions/Worker, Pulse Collector Azure bring-up).
- **Phase 4 (Month 2)** — Author `.claude/agents/ai-safety.md`. Invoke against AI-sector standup ADRs (ADR-0017 onward) as they move toward acceptance.
- **Phase 5 (When UI work starts)** — Author `.claude/agents/a11y.md`. Lands ahead of the first consumer-app PR; no immediate work otherwise.

Each phase is a discrete go/no-go. Phase 1's exit criterion is "did `cfo` produce findings the human acted on?" — if yes, Phase 2 starts; if no, the pattern itself is reconsidered before adding more specialists.

## Consequences

### Affected Nodes

- **HoneyDrunk.Architecture** (this repo) — gains five new agent definition files in `.claude/agents/` over time per D8 / D10. `constitution/agent-capability-matrix.md` updated to register each new agent.
- **No code-Node changes.** This is entirely a Meta-sector decision about the agent surface.
- **Existing agents are not modified.** `review` keeps its 20-category rubric; `scope`/`adr-composer`/`pdr-composer`/`refine`/`node-audit` keep their ADR-0044 upstream-awareness references. Specialists layer on top.

### Invariants

Adds one:

- **Invariant: specialist agents are advisory and complementary to the `review` agent.** A specialist's findings do not gate merge any more than the generalist's do (ADR-0011 D5 advisory posture preserved). The human is the final arbiter.

(Final invariant number assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles.)

### Operational Consequences

- **Five new agent files** to author and maintain. Each is bounded scope (one lens, one rubric, one mandatory context-load list) and lower-cost-to-maintain than a broader agent. `cfo` carries slightly more scope than the others (cost + AI-cost) but the underlying discipline is unified.
- **The roster is now legible.** Future "should this become its own specialist?" decisions are amendments to this ADR's D2 roster, not improvisations. Sprawl is bounded by the explicit-amendment discipline.
- **The manual-only commitment means the operator must remember to invoke.** This is the explicit accepted risk — paralleling ADR-0011's pre-ADR-0044 manual posture for the `review` agent. The discipline failure mode is "I should have invoked `cfo` here and didn't." Mitigation: the agent-capability-matrix is visible during ADR/PDR drafting in Claude Code; the names suggest themselves at the right moment.
- **Specialist invocation cost is rolled up** under ADR-0044's review budget. No separate budget line at v1.
- **Specialists are upstream-aware (D5)** — invoke them at ADR drafting and at packet scoping, not only at PR review. This is the highest-leverage application of the pattern.

### Follow-up Work

- Author `.claude/agents/cfo.md` with explicit AI-cost sub-rubric (Phase 1).
- Retroactively invoke `cfo` against PR #162 once authored; capture findings as branch commits.
- Author `.claude/agents/security.md` (Phase 2).
- Author `.claude/agents/performance.md` (Phase 3).
- Author `.claude/agents/ai-safety.md` (Phase 4).
- Author `.claude/agents/a11y.md` (Phase 5, when UI work starts).
- Update `constitution/agent-capability-matrix.md` with each new agent as it lands.
- Consider CI triggers per D9 only after Phase 1's manual-invocation cadence is observed for ≥30 days.
- When a fifth specialist is proposed (privacy, SRE, etc.), it lands as an ADR amendment with the same D2-shaped justification.

## Alternatives Considered

### Expand ADR-0044 D3's rubric depth instead of adding specialists

Considered. The generalist `review` agent could be made deeper on cost, accessibility, security, and AI-safety by expanding the per-category checklist in `.claude/agents/review.md`. Rejected on two grounds:

- **Cost.** A deeper rubric is more tokens per invocation, and `review` runs on every PR. Specialists run only when invoked; their depth is paid for only when used.
- **Specialty body of practice.** Accessibility has WCAG; security has OWASP; AI-safety has a growing literature of its own. A specialist agent can reference those bodies of practice with rigor a generalist can't easily replicate.

The right answer is **both** — the generalist's rubric stays broad (ADR-0044 unchanged), specialists go deep on demand.

### One generalist "specialist coordinator" agent that subsumes all five lenses

Rejected. A single agent that knows when to act as `cfo` vs `a11y` vs `security` vs `performance` vs `ai-safety` is just a generalist with a context-switching prompt. Specialists earn their keep by being **focused** — the prompt is tuned, the context-load is narrow, the rubric is deep on one thing. Conflating them loses the advantage.

### Skip specialists; rely on the human to apply the lenses

Considered. The human (solo dev) is already the final arbiter and could in principle apply each lens manually. Rejected because: (a) the recent ADR-0040/0045 evidence shows the human misses the `cfo` lens under deadline / drafting flow, and (b) specialist agents pre-load the relevant body of practice (WCAG, OWASP) the human would otherwise have to keep in head. The agent is the lens externalized.

### Build automatic CI invocation in v1

Rejected (D3). Trigger conditions are heuristic and would produce false positives; cost discipline favors fewer invocations until evidence justifies more; the highest-value invocations are at ADR drafting, not PR review. Manual-first is the disciplined v1; automatic invocation is the documented follow-up if manual proves insufficient.

### Start with a smaller roster (just `cfo`)

Considered. `cfo` alone has the strongest retroactive justification (the ADR-0040/0045 pivot). Rejected because naming the pattern with one agent and adding others ad-hoc is exactly the sprawl risk D2's explicit-roster discipline is designed to prevent. Better to commit to five lenses up front with phased authoring than to backfill the roster every few months.

### Start with a larger roster (eight to ten specialists)

Rejected. Each agent has authoring and maintenance cost; the five-agent starter roster covers the highest-leverage lenses with the strongest body-of-practice. Privacy/GDPR, SRE, migration safety, anti-entropy, DX are named candidates for future amendments — D9 makes the path explicit. Better to land five and amend than to commit to ten and have half of them sit unused.

### Carve AI-cost out as its own agent (separate from `cfo`)

Considered. AI-cost has its own body of practice (model-selection trade-offs, prompt-caching strategies, token-budget analysis) and could justify a dedicated agent. Rejected because the **analytical framework is the same** as general cost discipline: free-tier-first, justify-the-spend, prefer-cheaper-where-equivalent, document escalation triggers. Splitting it produced two agents with overlapping rubrics and no clear invocation boundary. The unified `cfo` agent applies the same framework to both Azure SKU choices and LLM model choices; the per-domain detail lives in the rubric, not in a second agent.

### Skip the ADR; just create agent files as needed

Rejected. Agent sprawl without a governing pattern is the failure mode this ADR exists to prevent. ADR-0007 already commits agent definitions to `.claude/agents/` as source of truth; this ADR commits the **decision-making pattern** for which agents to create, when, and why. Without it, every "should we add agent X?" conversation re-litigates first principles.
