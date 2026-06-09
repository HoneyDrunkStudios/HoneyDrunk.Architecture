# Loop Engineering — Doctrine

> The operational expression of the charter's **AI-multiplier bet**: the operator
> stops being the part of the system that triggers, contextualizes, and re-invokes
> agents by hand, and becomes the person who **designs the loops that prompt agents**.
> This document is the *how*; the governing decision is
> [ADR-0093](../adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md).

**Last Updated:** 2026-06-09
**Governing decision:** ADR-0093 (Accepted)
**Sector:** Meta / AI / Platform

---

## Why this exists

The Grid already runs loops; it never named the pattern. `hive-sync` is a scheduled
reconciliation loop. The four ADR-0043 backlog sources are state-driven loops that
synthesize packets and drain them at a human gate. The PR-activity autofix loop
(subscribe → CI fails → re-kick → merge) is an event-driven build loop. Each was
designed in isolation; the discipline was tribal knowledge smeared across an ADR
(the policy), an ADR-0086 job spec (the schedule), a `.claude/agents/*.md` file (the
behavior), and `constitution/alert-routing.md` (the notification).

Loop engineering names the discipline and makes a loop a **first-class, reviewable
artifact** — the same move the Grid made for ADRs, PDRs, and BDRs. The asymmetry it
closes: *execution is industrialized; loop design was artisanal.* With a solo operator,
an artisanal upstream is a hard cap on throughput.

The shift in one line: **from prompting agents to engineering the control systems that
prompt agents.** The operator's recurring concerns move from prompt-craft toward
control engineering — observability, damping, bounded authority, idempotency.

---

## Open vs. closed: the bar

- **Open-loop automation** generates and hopes. It has a trigger and a synthesizer;
  it does not check its own output or let that check change the next input. A cron job
  is open-loop. It stays on GitHub Actions cron (ADR-0068) and is **not** an LDR.
- **Closed-loop** evaluates the output against a gate and writes the result back so the
  next iteration is better. **Every registered loop must close.** It must name a `gate`
  and a `feedback_sink`. The human is an allowed gate (and is the v1 default gate for
  most loops); **"no gate" is never allowed.**

> An automation with a `trigger` and a `synthesizer` but **no `gate` and no
> `feedback_sink` is not a loop — it is a cron job**, and it is registered as such.

---

## The seven-part anatomy

A **loop** is a feedback control system that invokes an agent. Every loop — and every
Loop Definition Record (LDR) — declares these seven parts:

| Part | Question it answers |
|------|---------------------|
| **trigger** | What clock or event wakes the loop? |
| **inputs** | What state does the loop read to decide what to do? (catalogs, drift report, CI status, issue state) |
| **synthesizer** | How does a state-delta become a scoped prompt? (the agent + prompt template) |
| **gate** | What check must the output pass? (the Success Definition, below) |
| **feedback_sink** | Where do results get written so the next iteration improves? (audit, report, drift surface) |
| **stop** | What are the terminal condition(s)? (done / stuck / over-budget) |
| *(+ governance envelope)* | budget, kill_switch, owner, autonomy_tier, idempotency |

The trigger → synthesizer → gate → feedback_sink → stop chain is the loop. The
governance envelope is what makes it safe to run unattended.

---

## The Success Definition (centerpiece)

A loop can only be trusted to run **unattended** if **done is a machine-checkable
predicate**, not prose. Every LDR carries a **Success Definition** in the same four parts —
but how *executable* those parts must be scales with the autonomy tier the loop claims
(see "Rigor scales with autonomy" below). At **Tier A** (human-gated, `WriteMode=pr`, a human
promotes every result) the bands may be **human-verifiable predicates** — a reviewer can
read them and rule. To graduate **above Tier A** — where no human is in the per-iteration
loop — every band must be an **executable check** (command + expected outcome), not a bullet
a human interprets. The four-part shape is mandatory at every tier; the executability is the
dial:

| Part | Question | Example substrate |
|------|----------|-------------------|
| **Done-when** | Did the intended thing happen? | acceptance tests; `dotnet build -c Release` + `dotnet test`; an endpoint returning 200 |
| **Still-true** | Did nothing else break? | full regression suite; canaries (Invariant 14/15); the ADR-0032 coverage gate; **cost stayed within the per-run ceiling** (see Cost economics) |
| **Out-of-bounds** | What may the loop *not* do to reach green? | `constitution/invariants.md`; repo boundaries; "don't touch Abstractions contracts"; "don't delete or skip tests"; "coverage may not drop" |
| **Escalate-when** | When is the loop *not allowed* to self-certify? | criterion unevaluable; two checks conflict; ambiguity → human gate |

Two binding rules (`[Firm]`):

1. **The Success Definition is authored separately from the worker.** The party that
   *defines* done is never the agent that *achieves* it — otherwise the agent grades its
   own homework. This reuses the existing seam: the packet / LDR specifies acceptance
   criteria (authored by `scope`/human); the execution agent satisfies them. The upgrade
   is rewriting those criteria from human-interpreted bullets into runner-evaluated
   predicates.
2. **Rigor scales with autonomy.** "How specific is success" and "how much autonomy" are
   the same dial. A loop without a complete, executable Success Definition does not
   qualify for any autonomy tier above A.

---

## The autonomy ladder

Loops graduate through three trust tiers; a loop earns the next tier only after proving
the prior one.

| Tier | Name | Who gates | Requires |
|------|------|-----------|----------|
| **A** | Human-gated | Loop generates; human triages/promotes | The substrate (this doc) + ADR-0044/0079 review gates. **The v1 default.** |
| **B** | Eval-gated | Loop generates; an automated eval scores; failures auto-reject; human sees passes + escapes | The Evals Node (ADR-0023) — the gate the worker cannot edit. **Blocked until Evals stands up.** |
| **C** | Self-tuning | Loop reads its own audit/eval history and adjusts its own thresholds/cadence; human reviews the *tuning*, not each output | Tiers A+B proven + loop-health telemetry. **Future.** |

Two coupling rules constrain the dial:

- **Autonomy is bounded by blast radius, not only by success-rigor.** A loop may be highly
  autonomous on low-blast-radius work (docs, tests, version bumps) and must stay gated on
  high-blast-radius work (Abstractions contracts, infra, anything in the ADR-0087 `forced`
  sensitive set). ADR-0087's per-change risk scorer *routes* autonomy per change rather
  than per loop.
- **`WriteMode = "pr"` is the floor; artifacts are the write boundary** (`[Firm]`). No
  loop mutates authoritative state outside a reviewable git branch/PR (the ADR-0090 D9
  PRs-as-artifacts boundary). Everything a loop produces is revertible.

---

## The Build Loop pattern and its three exits

An autonomous **build loop** wraps the canonical Grid done-gate
(`dotnet build -c Release` + `dotnet test`) in: build → test → read failures → fix →
repeat. To be safe it must have **three terminal states**, not one:

1. **Done** — the Success Definition passes → open PR, stop.
2. **Stuck** — no progress across N iterations (same error, or churn without the gate
   advancing) → stop and escalate **with a diagnosis**.
3. **Over-budget** — iteration/token/cost cap hit (the ADR-0052 kill-switch) → stop and
   report.

"Don't stop till done" in practice means **"don't stop till done, stuck, or broke — and
escalate the last two."** The stuck-detector and the budget cap matter as much as the
done-gate.

Two anti-gaming requirements (`[Firm]`):

- **Load-bearing gate checks live outside the worker's write scope** — canaries defined
  in another repo, a coverage baseline that can only ratchet up (ADR-0032), a review agent
  the worker cannot edit (ADR-0044/0079), and ultimately the human promotion gate. *A gate
  the worker can reach into, it can game* (deleting the failing test counts as "tests
  pass").
- **Loop maturity and test maturity advance together.** An autonomous build loop satisfies
  whatever gate it is given; a thin test suite turns "ran till green" into "ran till the
  easiest green." This is the standing argument for scaffolding Evals (ADR-0023) as a
  second gate the worker cannot satisfy by editing.

---

## The loop-authorship gate (load-bearing fleet safety)

LDRs are governed exactly like ADR-0043 packets:

- `loops/proposed/` — agent-authored loop candidates (the landing zone).
- `loops/` (active) — human-promoted loops.

**Agents may propose new loops; only a human promotes a loop into existence** (`[Firm]`).
This single rule is the load-bearing fleet-safety control: it is what prevents a fleet of
agents from silently spinning up autonomous loops — including loops that spawn loops. Loop
creation is never self-service for an agent, in the same way a packet never self-promotes
from `proposed/` to `active/`.

---

## Execution substrate

Loops run on the **ADR-0086 pull-based Grid Agent Runner** at v1. No new execution
substrate is introduced. Loops **compose, never re-implement**, the primitives the Grid
already has:

| Concern | Primitive |
|---------|-----------|
| Budget / stop | ADR-0052 (`ILlmDispatcher` kill-switch, per-category caps, anomaly detection) |
| Tool scoping / authorization | ADR-0051 (`AgentPrincipal`, capability bundles at the `IToolInvoker` boundary) |
| Concurrency safety | ADR-0042 (idempotency keys, dedup) for any loop that writes or runs concurrently |
| Provenance | ADR-0030 audit + the PDR-0010 agent-action-ledger shape; ADR-0044 D6 `Authorship:` tags |
| Gates | ADR-0044/0079 review, ADR-0032 coverage, ADR-0087 risk routing, ADR-0023 evals |

A loop's runner job spec lives at
`infrastructure/workers/grid-agent-runner/config/jobs/{job-id}.psd1` (keyed by the short
`JobId`, e.g. `hive-sync`) and follows the **loop-job convention** documented in that
directory's README. The LDR is the decision record; the job spec is the schedule +
execution wiring; the LDR `id` (`loop-NNNN-{job-id}`) maps 1:1 to the `JobId`.

---

## Cost and token usage are a first-class signal

Loops change the cost model from *per-prompt* (a human decides each spend) to
*per-outcome and unbounded* (the loop decides, repeatedly, unattended). At fleet scale that
is the single fastest way to burn money silently. Cost is therefore first-class at every
layer of a loop, not only a stop condition:

- **Every loop run accounts tokens and cost, at declared fidelity.** Loop runs reuse the
  ADR-0092 `UsageSignal` **exact / derived / estimated** model and its `[Firm]` honesty
  rule — **never render an estimate as exact.** Fidelity is backend-shaped: Claude Code
  exposes exact tokens **and** USD; Codex exact tokens with USD derived from operator
  rates; Copilot premium-requests + duration with tokens/USD estimated. An LDR declares
  the fidelity it will get from its backend.
- **Cost is attributable, never aggregate-only.** Per-run, per-loop, and per-agent
  attribution (ADR-0052 D6) is a fleet-readiness contract: "which loop, which agent, which
  run spent this" must always have an answer.
- **Cost is both a stop condition and a success criterion.** The over-budget exit halts a
  runaway loop, but a loop that produces a correct artifact at unacceptable cost is still a
  **failed** loop. **Token/cost efficiency is part of the Success Definition's `still-true`
  band** — a loop may declare a per-run cost ceiling and a cost-per-successful-outcome
  target; breaching it is a gate failure, not just an alert. This is **loop ROI**: a loop
  that costs more in tokens + review than doing the task by hand is retired at the weekly
  briefing.
- **Right-sizing and caching are standing optimizations.** Loops select the cheapest model
  that clears their gate (cheap for triage/discovery, strong for building) via the ADR-0041
  model registry, and exploit prompt caching where the backend supports it. The **`cfo`
  specialist review agent (ADR-0046)** is the standing reviewer of loop cost at LDR
  authoring and at the weekly ROI pass.
- **Burn is a heartbeat metric and is anomaly-detected.** Cost is a first-class field in
  the loop heartbeat; the ADR-0052 anomaly rules (5× hour-over-hour, 3× day-over-day) apply
  per loop and fleet-wide. At fleet scale the stop-the-world kill-switch is cost-triggered.

---

## Loops observe themselves

Leaving the hot path means losing ambient awareness, so loops need their own observability.

- **Every loop emits a heartbeat** — last run, success rate, escalation count, cost —
  through Pulse (ADR-0010/0040).
- **Loop-health is distinct from output-health.** "Output passed the gate" is not "the loop
  is healthy": loops rot as the model, codebase, and gate assumptions drift, and a stale
  gate can pass garbage. LDRs therefore carry a **re-validation cadence**, and the fleet
  registry surfaces loop-health independently of per-run output.
- **The scarce resource at fleet scale is operator attention, not compute.** Escalation
  quality (a diagnosis and options, not "failed") and batching (digest vs. interrupt, per
  the ADR-0043 weekly-briefing / ADR-0084 out-of-band split) are first-class LDR concerns.
  A loop that escalates poorly rebuilds the bottleneck it was meant to remove.

---

## Fleet posture: forward-compatible now, orchestrator later

The AI-multiplier trajectory is many concurrent loops across many agents — a fleet. The
charter forbids building the fleet orchestrator before it is needed; it does not excuse
painting into a corner that prevents it.

**Designed in now (cheap, painful to retrofit):**

- **Stable loop identity** (`id`) and **per-run identity** as the unit of fleet addressing
  and attribution.
- **Per-run idempotency + a lease/claim model** (ADR-0042) so two runs never duplicate the
  same work.
- **Per-agent / per-run cost attribution** (ADR-0052 D6).
- **Structured run records** composing the ADR-0090 `DispatchRun` / `UsageSignal` model so
  loop runs and cockpit sessions share one shape.
- **A single fleet registry surface** — `loops/` plus a live-state index — so "what is the
  fleet doing right now" has one answer.

**Gated for later (built when concurrent autonomous loops exceed a real threshold):**

- Multi-runner work distribution beyond the single ADR-0086 host.
- A backpressure / fairness / priority scheduler for a saturated fleet.
- Fleet-wide autoscale and a global **stop-the-world** kill-switch (cost-triggered).
- Cross-agent coordination beyond leases.

> v1 runs a handful of loops on one runner. **The orchestrator is named, not built.**

---

## The operator surface

HoneyHub is the cockpit that already drives agent *sessions* (ADR-0090 bridge, ADR-0092
session/usage/routing). The operator surface for loop engineering is a **Loop Console** in
HoneyHub: define an LDR, launch a loop run, watch its heartbeat, approve the one human gate,
and see per-loop cost. It composes — does not fork — the ADR-0090 session model and the
ADR-0092 routing engine, and inherits ADR-0090's `[Firm]` boundaries verbatim. The Loop
Console is **gated on HoneyHub v1 shipping** and is registered as a future phase in
`initiatives/programs/honeyhub.md`. The Architecture-side substrate (this doc + `loops/`)
is buildable today and does not wait on HoneyHub.

---

## Authoring an LDR — checklist

1. Copy `loops/LDR-TEMPLATE.md` to `loops/proposed/loop-NNNN-{slug}.md` (next free
   `NNNN`; ids are never reused — see `constitution/naming-conventions.md`).
2. Fill the seven-part anatomy and the governance envelope.
3. Write the **Success Definition** as executable checks — and have it authored/reviewed by
   someone other than the worker that will satisfy it.
4. Declare the autonomy tier you are *claiming*, and confirm the rigor matches (Tier > A
   requires a complete executable Success Definition; Tier B requires an Evals gate).
5. Declare cost fidelity, the per-run cost ceiling, and the cost-per-outcome target.
6. Set the re-validation cadence.
7. If the loop runs on the runner, author the matching
   `infrastructure/workers/grid-agent-runner/config/jobs/{job-id}.psd1` job spec per the
   loop-job convention.
8. Leave it in `loops/proposed/` for **human promotion**. An agent never moves its own LDR
   to `loops/`.

---

## Relationship to other doctrine

- **ADR-0043** (continuous backlog generation) is one level up: it industrialized *work
  sourcing*. Loop engineering industrializes *loop design*. The four ADR-0043 sources are
  backfilled here as LDRs.
- **ADR-0014** (`hive-sync`) is the canonical scheduled reconciliation loop — backfilled
  here as `loop-0001`.
- **ADR-0086** (Grid Agent Runner) is the execution substrate.
- **The charter** (`constitution/charter.md` §"The AI multiplier", §"What this charter
  forbids" #2) is the tiebreaker: name the fleet orchestrator, do not build it before it
  is needed.
