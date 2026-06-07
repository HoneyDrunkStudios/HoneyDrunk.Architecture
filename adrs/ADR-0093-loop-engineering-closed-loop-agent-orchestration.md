# ADR-0093: Loop Engineering — Closed-Loop Agent Orchestration

**Status:** Proposed
**Date:** 2026-06-07
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform

**Relationships:** Names the discipline already enacted piecemeal by [ADR-0043](ADR-0043-continuous-backlog-generation-strategy.md) (backlog-generation loops) and [ADR-0014](ADR-0014-hive-architecture-reconciliation-agent.md) (`hive-sync` reconciliation loop). Builds on the [ADR-0086](ADR-0086-pull-based-local-worker-grid-review-runner.md) Grid Agent Runner as the execution substrate. Composes [ADR-0052](ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) (budget/kill-switch), [ADR-0051](ADR-0051-ai-agent-authorization-and-tool-scoping-model.md) (tool scoping), [ADR-0042](ADR-0042-idempotency-contract-for-async-boundaries.md) (idempotency), [ADR-0030](ADR-0030-grid-wide-audit-substrate.md) (audit), [ADR-0044](ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)/[ADR-0079](ADR-0079-multi-perspective-pr-review-stack.md) (review gates), [ADR-0087](ADR-0087-per-change-risk-scoring-for-double-review.md) (risk routing), and [ADR-0023](ADR-0023-stand-up-honeydrunk-evals-node.md) (evaluation gate). Surfaces in the operator cockpit via [ADR-0090](ADR-0090-honeyhub-local-runner-bridge.md)/[ADR-0092](ADR-0092-honeyhub-session-usage-telemetry-and-routing.md) (HoneyHub) and, at the long horizon, [ADR-0003](ADR-0003-honeyhub-control-plane.md) (control plane).

---

## Context

The studio is built on the AI-multiplier bet (`constitution/charter.md` §"The AI multiplier"): a disciplined solo operator with AI agents sustaining a system that would once have required a team. The operational expression of that bet is **the operator should stop being the part of the system that triggers, contextualizes, and re-invokes agents by hand.** The shift is from *prompting agents* to *designing the loops that prompt agents* — the operator moves from operator-in-the-hot-path to loop designer.

The Grid already runs loops; it has never named the pattern. `hive-sync` (ADR-0014) is a scheduled closed reconciliation loop. The four ADR-0043 backlog sources are state-driven loops that synthesize packets and drain them at a human gate. The PR-activity autofix loop (subscribe → CI fails → re-kick → merge) is an event-driven build loop. Each was designed in isolation; the pattern is tribal knowledge smeared across an ADR (the policy), an ADR-0086 job spec (the schedule), a `.claude/agents/*.md` file (the behavior), and `constitution/alert-routing.md` (the notification). Three gaps follow from never having named it:

1. **A loop is not a first-class artifact.** Nothing says, in one reviewable place: *this loop's trigger, inputs, prompt synthesizer, gate, feedback sink, stop condition, budget, kill-switch, owner, and autonomy tier.*
2. **Every gate bottoms out at the human.** Loops are open-loop-with-human-triage today — correct for now, but it caps throughput at the operator's attention. The leverage move is to make the *gate itself* an agent/eval so the human sees only escapes. The Node for this — Evals (ADR-0023) — is designed but unscaffolded.
3. **There is no fleet posture.** A handful of loops on one runner is the present; many concurrent loops across many agents is the trajectory the AI-multiplier bet implies. Without a forward-compatible contract, fleet scale-out becomes a retrofit.

This ADR names the discipline, makes a loop a first-class governed artifact, pins the success-definition rigor that autonomy requires, and sets a fleet-ready-but-not-fleet-built posture consistent with the charter's prohibition on architecture-as-procrastination (`constitution/charter.md` §"What this charter forbids" #2).

This is a **Meta-sector** decision about how work runs, not a code-Node change. It composes existing primitives; it does not introduce a new runtime Node at v1.

---

## Decision

### D1 — A loop is a first-class Grid artifact: the Loop Definition Record (LDR)

A **loop** is a feedback control system that invokes an agent: it is triggered by state, synthesizes a scoped prompt from that state, runs a bounded agent, evaluates the output against a gate, writes the result back so the next iteration is better, and stops on a terminal condition.

Loops become reviewable artifacts under a new top-level `loops/` directory, one Markdown file per loop with structured frontmatter — the **Loop Definition Record (LDR)**, the same first-class move the Grid made for ADRs, PDRs, and BDRs. Every LDR declares the seven-part anatomy plus its governance envelope:

| Field | Meaning |
|-------|---------|
| `id` | Stable loop identity (`loop-NNNN-{slug}`). Never reused; the unit of fleet identity (D8). |
| `trigger` | Clock or event that wakes the loop. |
| `inputs` | The state the loop reads to decide what to do (catalogs, drift report, CI status, issue state). |
| `synthesizer` | How a state-delta becomes a scoped prompt — the agent + prompt template. |
| `gate` | The check the output must pass (D2/D3). |
| `feedback_sink` | Where results are written so the next iteration improves (audit, report, drift surface). |
| `stop` | Terminal condition(s) (D5). |
| `budget` | Per-run and per-window cost/iteration cap (ADR-0052). |
| `kill_switch` | The named control that halts this loop and, at fleet scale, participates in stop-the-world (D8). |
| `owner` | Accountable human (the operator at v1). |
| `autonomy_tier` | `A` / `B` / `C` (D4). |
| `idempotency` | The dedup/lease key shape for safe concurrent runs (ADR-0042; D8). |

An automation that has a trigger and a synthesizer but **no gate and no feedback_sink is not a loop** — it is a cron job, and it is registered as such (it stays on GitHub Actions cron per ADR-0068), not as an LDR.

### D2 — Closed-loop is the bar: every registered loop must close

Open-loop automation generates and hopes; closed-loop evaluates the output and lets the evaluation change the next input. Every LDR must close: it must name a `gate` and a `feedback_sink`. The human is an allowed gate (and is the v1 default gate for most loops, preserving the ADR-0043 `proposed → active` discipline), but "no gate" is never allowed.

### D3 — Success Definition is a required, executable, separately-authored section (centerpiece)

A loop can only be trusted to "run until done" if **done is a machine-checkable predicate**, not prose. Every LDR carries a **Success Definition** with four parts, expressed as executable checks (commands + expected outcomes), not bullet points a human interprets:

| Part | Question it answers | Example substrate |
|------|---------------------|-------------------|
| **Done-when** | Did the intended thing happen? | acceptance tests, the build/test command, an endpoint returning 200 |
| **Still-true** | Did nothing else break? | full regression suite, canaries (Invariant 14/15), the ADR-0032 coverage gate |
| **Out-of-bounds** | What may the loop *not* do to reach green? | the invariants in `constitution/invariants.md`, repo boundaries, "don't touch Abstractions contracts," "don't delete or skip tests," "coverage may not drop" |
| **Escalate-when** | When is the loop *not allowed* to self-certify? | criterion unevaluable, two checks conflict, ambiguity → human gate |

Two binding rules:

- **The Success Definition is authored separately from the worker.** The party that *defines* done is never the agent that *achieves* it — otherwise the agent grades its own homework. This reuses the existing seam: the issue packet / LDR specifies acceptance criteria (authored by `scope`/human), the execution agent satisfies them. The upgrade is rewriting those criteria from human-interpreted bullets into runner-evaluated predicates.
- **Rigor scales with autonomy (D4).** "How specific is success" and "how much autonomy" are the same dial. A loop without a complete, executable Success Definition does not qualify for any autonomy tier above A (human-gated).

### D4 — Autonomy ladder, bounded by blast radius

Loops graduate through three trust tiers; a loop earns the next tier only after proving the prior one:

- **Tier A — Human-gated.** Loop generates; human triages/promotes. The v1 default and where ADR-0043 already operates.
- **Tier B — Eval-gated.** Loop generates; an automated eval (ADR-0023 Evals) scores; failures auto-reject; the human sees passes plus escapes. Requires the Evals Node.
- **Tier C — Self-tuning.** Loop reads its own audit/eval history and adjusts its own thresholds/cadence; the human reviews the *tuning*, not each output.

Two coupling rules constrain the dial:

- **Autonomy is bounded by blast radius, not only by success-rigor.** A loop may be highly autonomous on low-blast-radius work (docs, tests, version bumps) and must stay gated on high-blast-radius work (Abstractions contracts, infra, anything in the ADR-0087 `forced` sensitive set). ADR-0087's per-change risk scorer is the mechanism that *routes* autonomy per change rather than per loop.
- **`WriteMode = "pr"` is the floor and artifacts are the write boundary.** No loop mutates authoritative state outside a reviewable git branch/PR (the ADR-0090 D9 PRs-as-artifacts boundary). Everything a loop produces is revertible.

### D5 — The autonomous Build Loop pattern and its three exits

A build loop wraps the canonical Grid done-gate (`dotnet build -c Release` + `dotnet test`) in: build → test → read failures → fix → repeat. To be safe it must have **three terminal states**, not one:

1. **Done** — Success Definition (D3) passes → open PR, stop.
2. **Stuck** — no progress across N iterations (same error, or churn without the gate advancing) → stop and escalate with a diagnosis.
3. **Over-budget** — iteration/token/cost cap hit (ADR-0052 kill-switch) → stop and report.

The stuck-detector and the budget cap matter as much as the done-gate; "don't stop till done" in practice means "don't stop till done, stuck, or broke — and escalate the last two." Two anti-gaming requirements:

- **The load-bearing gate checks must live outside the worker's write scope** — canaries defined in another repo, a coverage baseline that can only ratchet up (ADR-0032), a review agent the worker cannot edit (ADR-0044/0079), and ultimately the human promotion gate. A gate the worker can reach into, it can game.
- **Loop maturity and test maturity advance together.** An autonomous build loop satisfies whatever gate it is given; a thin test suite turns "ran till green" into "ran till the easiest green." This is the standing argument for scaffolding Evals (ADR-0023) as a second gate the worker cannot satisfy by editing.

### D6 — Loop authorship is gated; agents propose, humans promote

LDRs are reviewable artifacts governed exactly like ADR-0043 packets: a `loops/proposed/` landing zone for agent-authored loop candidates and a `loops/` (active) home for human-promoted loops. **Agents may propose new loops; only a human promotes a loop into existence.** This single rule is the load-bearing fleet-safety control (D8): it is what prevents a fleet of agents from silently spinning up autonomous loops — including loops that spawn loops. Loop creation is never self-service for an agent, in the same way a packet never self-promotes from `proposed/` to `active/`.

### D7 — Execution substrate is the ADR-0086 Grid Agent Runner; loops compose existing primitives

Loops run on the ADR-0086 pull-based runner at v1. No new execution substrate is introduced. Loops compose, never re-implement, the primitives the Grid already has:

- **Budget / stop** — ADR-0052 (`ILlmDispatcher` kill-switch, per-category caps, anomaly detection).
- **Tool scoping / authorization** — ADR-0051 (`AgentPrincipal`, capability bundles at the `IToolInvoker` boundary) for in-Grid agent execution.
- **Concurrency safety** — ADR-0042 (idempotency keys, dedup) for any loop that writes or runs concurrently.
- **Provenance** — ADR-0030 audit + the PDR-0010 agent-action-ledger shape: every loop run is traceable to its trigger, inputs, gate outcome, and authorship (ADR-0044 D6 `Authorship:` tags).
- **Gates** — ADR-0044/0079 review, ADR-0032 coverage, ADR-0087 risk routing, ADR-0023 evals.

### D8 — Fleet-readiness: forward-compatible contracts now, gated orchestrator later

The AI-multiplier trajectory is many concurrent loops across many agents — a fleet. The charter forbids building the fleet orchestrator before it is needed; it does not excuse painting into a corner that prevents it. The split:

**Designed in now (cheap, painful to retrofit):**
- **Stable loop identity** (`id`, D1) and **per-run identity** as the unit of fleet addressing and attribution.
- **Per-run idempotency + a lease/claim model** (ADR-0042) so two runs never duplicate the same work.
- **Per-agent / per-run cost attribution** (ADR-0052 D6) so fleet spend is attributable, not aggregate-only.
- **Structured run records** composing the ADR-0090 `DispatchRun` / `UsageSignal` model so loop runs and cockpit sessions share one shape.
- **A single fleet registry surface** — `loops/` plus a live-state index — so "what is the fleet doing right now" has one answer.

**Gated for later (expensive, premature today — built when concurrent autonomous loops exceed a real threshold):**
- Multi-runner work distribution across more than the single ADR-0086 host.
- A backpressure / fairness / priority scheduler for a saturated fleet.
- Fleet-wide autoscale and a **global "stop-the-world" kill-switch** extending ADR-0052 from per-category caps to a fleet-aggregate ceiling.
- Cross-agent coordination beyond leases.

v1 runs a handful of loops on one runner. The orchestrator is named, not built.

### D9 — HoneyHub Loop Console is the operator-facing surface

HoneyHub is the cockpit that already drives agent *sessions* (ADR-0090 bridge, ADR-0092 session/usage/routing). The natural operator surface for loop engineering is a **Loop Console** in HoneyHub: define an LDR, launch a loop run, watch its heartbeat, approve the one human gate, and see per-loop cost. It composes — does not fork — the ADR-0090 session model and the ADR-0092 `UsageSignal` / routing engine, and it inherits ADR-0090's `[Firm]` boundaries verbatim (artifacts-as-write-boundary; honest capability flags; state-only notifications; cloud/hosted execution BYO-API-key only, never a subscription token). At fleet scale the Loop Console becomes the **fleet console** — the home of the loop-observability meta-loop (D10) — and aligns with the long-horizon ADR-0003 HoneyHub control plane.

The Loop Console is **gated on HoneyHub v1 shipping** (ADR-0091 app stack, ADR-0092 session/usage — both Proposed; the `HoneyDrunk.HoneyHub` repo is mid-standup). It is registered as a future phase in the HoneyHub program (`initiatives/programs/honeyhub.md`), not built by this ADR's packets. The Architecture-side loop substrate (D1–D8) is buildable today and does not wait on HoneyHub.

### D10 — Loops observe themselves; loop-health is distinct from output-health

Leaving the hot path means losing ambient awareness, so the loops need their own observability. Every loop emits a heartbeat — last run, success rate, escalation count, cost — through Pulse (ADR-0010/0040). "Output passed the gate" is not "the loop is healthy": loops rot as the model, codebase, and gate assumptions drift, and a stale gate can pass garbage. LDRs therefore carry a re-validation cadence, and the fleet registry surfaces loop-health independently of per-run output. The scarce resource at fleet scale is **operator attention, not compute** — so escalation quality (a diagnosis and options, not "failed") and batching (digest vs. interrupt, per the ADR-0043 weekly-briefing / ADR-0084 out-of-band split) are first-class LDR concerns.

### D11 — Cost and token usage are a first-class loop signal, not a footnote

Loops change the cost model from *per-prompt* (a human decides each spend) to *per-outcome and unbounded* (the loop decides, repeatedly, unattended). At fleet scale that is the single fastest way to burn money silently. Cost and token usage are therefore a first-class signal at every layer of a loop, not only a stop condition:

- **Every loop run accounts tokens and cost, at declared fidelity.** Loop runs reuse the ADR-0092 `UsageSignal` exact / derived / estimated model and its `[Firm]` honesty rule — **never render an estimate as exact.** Per the ADR-0090 spike, fidelity is backend-shaped: Claude Code exposes exact tokens **and** USD; Codex exact tokens with USD derived from operator rates; Copilot premium-requests + duration with tokens/USD estimated. An LDR declares the fidelity it will get from its backend.
- **Cost is attributable, never aggregate-only.** Per-run, per-loop, and per-agent attribution (ADR-0052 D6) is a fleet-readiness contract (D8): "which loop, which agent, which run spent this" must always have an answer.
- **Cost is both a stop condition and a success criterion.** The over-budget exit (D5) halts a runaway loop, but a loop that produces a correct artifact at unacceptable cost is still a **failed** loop. **Token/cost efficiency is part of the Success Definition's `still-true` band (D3)** — a loop may declare a per-run cost ceiling and a cost-per-successful-outcome target, and breaching it is a gate failure, not just an alert. This is **loop ROI**: a loop that costs more in tokens + review than doing the task by hand is retired at the weekly briefing.
- **Right-sizing and caching are standing optimizations.** Loops select the cheapest model that clears their gate (a cheap model for triage/discovery, a strong one for building) via the ADR-0041 model registry, and exploit prompt caching where the backend supports it. The **`cfo` specialist review agent (ADR-0046)** — whose remit explicitly includes AI-cost (model selection, token budgets, prompt-caching opportunities) — is the standing reviewer of loop cost at LDR authoring and at the weekly ROI pass.
- **Cost/token burn is a primary heartbeat metric and is anomaly-detected.** Cost is a first-class field in the D10 loop heartbeat, and the ADR-0052 anomaly rules (5× hour-over-hour, 3× day-over-day) apply per loop and fleet-wide — runaway burn is caught before a hard cap fires. At fleet scale the **stop-the-world kill-switch (D8) is cost-triggered**: a fleet-aggregate spend ceiling halts the fleet, not just the offending loop.

---

## Consequences

### Prerequisites and Sequencing

This ADR is layered: the substrate is buildable now; higher autonomy tiers and the fleet/console surfaces are gated on decisions that are themselves still Proposed or on Nodes not yet scaffolded. **What must be complete before each layer lands:**

| Layer | Hard prerequisites | Status of prerequisites |
|-------|--------------------|-------------------------|
| **Substrate (D1, D2, D3, D6, D7)** — `loops/` + LDR template, doctrine doc, backfill existing loops, runner loop-job convention | ADR-0086 runner; ADR-0043 packet-lifecycle discipline; ADR-0052 budget/kill-switch; ADR-0030/0031 audit | **All Accepted / scaffolded.** Substrate can land immediately. |
| **Tier A loops (D4)** — human-gated | Substrate above; ADR-0044/0079 review gates | **All Accepted.** |
| **Autonomous Build Loop (D5)** — three-exit, build/test-gated | ADR-0032 coverage gate (the `still-true` success check) | **ADR-0032 Proposed** — build-loop `still-true` gate is incomplete until accepted + rolled out in `pr-core.yml`. |
| **Tier B loops (D4)** — eval-gated | ADR-0023 Evals Node **scaffolded** (the gate the worker cannot game) | **ADR-0023 Proposed; AI sector unscaffolded.** Tier B is blocked until Evals stands up. |
| **Autonomy routing (D4)** — per-change blast-radius gating | ADR-0087 risk scorer in enforce posture | **ADR-0087 Proposed**, shipping in shadow; itself names the ADR-0086 dual-pass worker substrate as a hard prerequisite. |
| **Write/concurrent loops + fleet identity (D7, D8)** | ADR-0042 idempotency contract; ADR-0051 agent authorization | **Both Proposed.** Single-loop read/PR-mode work is unaffected; concurrent write-loops and fleet leasing wait on these. |
| **HoneyHub Loop Console (D9)** | HoneyHub v1 shipped — ADR-0091 app stack + ADR-0092 session/usage | **Both Proposed; `HoneyDrunk.HoneyHub` mid-standup.** Console is a future HoneyHub-program phase. |
| **Fleet orchestrator (D8 gated set)** | Concurrent-autonomous-loop count exceeding a real threshold | **Not yet triggered.** Named, not built. |
| **Tier C self-tuning (D4)** | Tiers A+B proven; loop-health telemetry (D10) | **Future.** |

The substrate (Tier A) is the only layer this ADR's packets implement. Everything above it is sequenced behind its named prerequisite and tracked, not scoped now.

### Affected surfaces

- **New:** `loops/` (active) and `loops/proposed/` directories; `loops/LDR-TEMPLATE.md`; `constitution/loop-engineering.md` (the doctrine — open vs closed, the seven-part anatomy, the Success Definition four parts, the A/B/C ladder, the fleet posture, the loop-authorship gate, the cost/token economics); backfilled LDRs for the existing loops (`hive-sync`, the four ADR-0043 sources, the PR-activity autofix loop).
- **Amended by follow-up:** the HoneyHub program gains a Loop Console phase row; `constitution/agent-capability-matrix.md` notes loop-owning agents; ADR-0086 runner job-spec docs gain a loop-job convention.
- **No code-Node changes** at v1; no new runtime Node.

### Invariants

No new invariant at v1, following the ADR-0089 precedent (a solo operator running a handful of loops does not justify a canary-enforced rule). The promotion path is named: if concurrent **autonomous** (Tier B+) loops appear, or a self-tuning loop ships, candidate invariants become load-bearing — *"every autonomous loop carries a complete executable Success Definition, a named kill-switch, and a human-promoted LDR"* and *"no agent promotes a loop into existence."* Those are filed as an amendment when the trigger fires, not pre-committed.

### Operational

- The operator's job shifts from prompt-craft toward control-engineering: observability, damping, bounded authority, and idempotency become the recurring concerns.
- Attention, not compute, is the binding constraint; loops that escalate poorly rebuild the bottleneck they were meant to remove.
- Cost moves from per-prompt to per-outcome and is unbounded without the D5/D7 caps; loop ROI (does this loop cost less than doing the task by hand?) is a standing review at the weekly briefing.

---

## Alternatives Considered

### Leave loops smeared across ADRs, runner job specs, and agent files (status quo)

Rejected. The loops already exist; what is missing is a single reviewable artifact per loop and a named discipline. The asymmetry (execution industrialized, loop design artisanal) is the same throughput cap ADR-0043 diagnosed one level up.

### Build a single fleet orchestrator now

Rejected — it is the exact architecture-as-procrastination the charter forbids. A handful of loops on one runner does not need a scheduler, backpressure, or autoscale. D8's forward-compatible contracts cost little; the orchestrator is gated on a real trigger.

### Full autonomy with no human gate

Rejected. Without the D6 authorship gate and the D3/D5 out-of-bounds checks, a loop satisfies the letter of a weak gate while violating its spirit (deleting the failing test counts as "tests pass"). The human gate at promotion and the gates-outside-worker-reach rule are the anti-gaming spine.

### GitHub Actions cron as the loop substrate

Rejected as a *loop* substrate (it remains correct for pure cron per ADR-0068). Cron has a trigger and a synthesizer but no gate, no feedback sink, and no run state — it is automation, not a closed loop. Loops run on the ADR-0086 runner where state, gates, and feedback compose.

### Defer the success-definition rigor as a later refinement

Rejected. The executable, separately-authored Success Definition (D3) is the load-bearing part of every autonomous loop; deferring it would mean shipping autonomy on prose criteria, which is precisely the failure mode (thrash or false-green) this ADR exists to prevent.

---

## Decision Ledger

Per the HoneyHub flexibility posture (PDR-0011 Amendment §7), load-bearing lines are tagged.

- **`[Firm]`** — do not move without a new decision:
  - a loop is closed by definition — **a gate and a feedback sink are required** (D2);
  - the **Success Definition is executable and authored separately from the worker** (D3);
  - **agents propose loops; only a human promotes one into existence** (D6);
  - **`WriteMode = "pr"`; artifacts are the write boundary** (D4; inherits ADR-0090 D9);
  - **load-bearing gate checks live outside the worker's write scope** (D5);
  - **cost and token usage are a first-class signal** — accounted per run at declared fidelity, attributable per agent/run, and a success criterion not just a stop condition; **never render an estimate as exact** (D11);
  - the **fleet orchestrator is gated, not built at v1**; the contracts are fleet-ready (D8).
- **`[Provisional]`** — working assumptions, revise on signal: the LDR frontmatter field set (D1); the autonomy-ladder promotion criteria (D4); the stuck-detector heuristic (D5); the fleet-registry surface shape (D8); the Loop Console layout (D9); the re-validation cadence (D10).

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Does the live-state fleet index live in `loops/`, a catalog (`catalogs/loops.json`), or Pulse? | Architecture | Open — substrate packet decides the v1 shape |
| What is the exact stuck-detector signal (iteration count, gate-delta, or both)? | Architecture / Ops | Open (D5 `[Provisional]`) |
| Does the Loop Console reuse `DispatchSession` directly or define a `LoopRun` sibling? | Product / Architecture | Deferred to the HoneyHub-program phase (D9) |
| What concurrent-autonomous-loop count triggers the fleet orchestrator (D8 gated set)? | Architecture | Open — named, not yet quantified |

---

## Follow-Up Work

- Author `constitution/loop-engineering.md` (the doctrine).
- Create `loops/` and `loops/proposed/`; author `loops/LDR-TEMPLATE.md`.
- Backfill LDRs for `hive-sync`, the four ADR-0043 sources, and the PR-activity autofix loop (proves the LDR shape against real loops).
- Add a loop-job convention to the ADR-0086 runner job-spec docs.
- Register the HoneyHub Loop Console as a future phase in `initiatives/programs/honeyhub.md`.
- File the autonomy-invariant amendment when the first Tier-B loop is proposed.
