# ADR-0087: Per-Change Risk Scoring for the Double-Review Gate

**Status:** Proposed
**Date:** 2026-05-30
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

[ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) D8 (Accepted,
2026-05-26) keeps the discipline that *"agent-authored PRs touching a high-risk
Node receive two independent LLM-review perspectives before merge"* — the dual
**Codex CLI + Claude Code CLI** pass synthesized into one verdict, which is also
the mechanism intended to satisfy [Invariant 53](../constitution/invariants.md). D8
*re-homes* the intended *substrate* of that double review onto the local worker (that
substrate is ADR-0086 deferred work and **is not yet built** — see D8 of this ADR),
but **inherited its definition of "high risk" verbatim from [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D8**, which defines risk as a
**static property of a Node**:

> "A non-`human` PR that touches a high-risk Node requires two independent
> LLM-review perspectives… High-risk Nodes: HoneyDrunk.Kernel (any `*.Abstractions`
> change), HoneyDrunk.Vault (any secret-handling change), HoneyDrunk.Auth, …
> The catalog of high-risk Nodes lives in `catalogs/grid-health.json` under a new
> field, `review_risk_class`."

**The gap.** Neither ADR-0044 nor ADR-0086 defines what makes a *change* high-risk;
both pin risk to the *repo*. Three concrete problems follow:

1. **`review_risk_class` is a phantom — and nothing ever consumed it.** The field
   was deferred at ADR-0044 acceptance ("populate… deferred until Phase 3
   activates"), is still absent from `catalogs/grid-health.json`, and Invariant 53
   explicitly records itself as *"accepted as the Phase-3 target state but not
   enforceable"* until the field lands. The trigger workflow that landed in
   `HoneyDrunk.Actions` (`job-review-request.yml`, commit 7a3330e) reads a
   `review_risk_class` key from each repo's static `.honeydrunk-review.yaml`
   (defaulting to `normal`, and the pilot config doesn't even set it) and writes it
   into the queue comment as `risk_class:`. **But the local worker never reads it.**
   Verified in `infrastructure/workers/grid-agent-runner/lib/Queue.psm1`:
   `Get-HeadShaFromQueueComment` parses only `head_sha`, `Get-ClaimedAtFromQueueComment`
   parses only `claimed_at`, and no function anywhere in the runner consumes
   `risk_class` / `review_risk_class`. So the value is written and dropped on the
   floor — a dead config key wired to a value nobody populates *and* a payload field
   nobody reads. There is no live double-review behavior keyed off it today.

2. **Repo-granularity is the wrong shape.** A repo is not "high risk" forever. A
   README typo in `HoneyDrunk.Vault` is not high risk; a one-line change to
   `ISecretStore` resolution semantics is. Conversely, a "normal" repo can ship a
   change that widens a public contract a dozen Nodes consume. Tagging the *Node*
   over-fires on docs/test churn in sensitive repos and under-fires on dangerous
   changes in ordinary repos.

3. **Size is not the signal.** ADR-0044 D7's PR-size discipline already handles
   *bulk*. Risk is orthogonal: **a one-line change can be the highest-risk change
   in a wave** if it touches token validation, a secret-resolution path, a Kernel
   abstraction, or a contract with a large consumer fan-out. The signal is the
   *nature and location* of the diff, not its line count.

**What already exists that we should reuse rather than reinvent:**

- **`catalogs/relationships.json`** — the authoritative dependency graph. Each
  Node carries `consumed_by`, `consumed_by_planned`, and an `exposes.contracts`
  list. This is the canonical **blast-radius** signal: Kernel is `consumed_by` nine
  live Nodes (plus nine planned); a leaf Node consumed by nobody has near-zero
  downstream fan-out. We do not need to invent a criticality ranking — the graph
  already encodes it.
- **ADR-0083's `sensitive-inventory.md`** — the Grid's canonical index of
  credentials, identifiers, and load-bearing identity bindings, keyed to their
  consuming workflows/paths (`SONAR_TOKEN`, OIDC subject patterns, webhook signing
  secrets, etc.). ADR-0083 D2 **deliberately rejected a "criticality tier" column**
  in favor of prose `Blast Radius if Missed`, and made the file human-Markdown, not
  tooling-JSON. So it is *not* a machine-readable risk score — but it is an
  authoritative enumeration of *which artifacts and paths are sensitive*, which a
  sensitivity heuristic can key off without re-deriving the list.
- **`catalogs/flow_tiers.json`** — the Tier 1/2/3 execution taxonomy already maps
  "affects contracts, invariants, or cross-repo boundaries" to Tier 3. This is a
  pre-existing *change-shaped* (not repo-shaped) risk axis we can borrow vocabulary
  from.
- **The trigger workflow seam** — `job-review-request.yml` already computes the
  changed-file list, additions/deletions, ADR references, authorship class, and a
  `security`/`secrets` path heuristic (`secret|credential|token|key vault|pat|api
  key|rotation|sensitive`), and already writes a `risk_class` field into the queue
  comment (currently the unread `.honeydrunk-review.yaml` default, see gap #1). The
  scorer plugs into this existing transport — the queue comment — to deliver its
  verdict; it does not need new transport. Note the cloud-Action tier sees only the
  PR file list and per-file additions/deletions (`gh api …/files`); it does **not**
  fetch file contents or diff hunks. The available signals are bounded by that.

The forcing function: ADR-0086 D8 and Invariant 53 both depend on a definition of
"high risk" that does not exist in an enforceable form. This ADR supplies that
definition as a **per-change (per-PR) signal**, replacing the static `review_risk_class`
Node-flag concept.

## Decision

This ADR commits a **per-PR risk score** as the gate that flips a PR into the
double-review path, replacing the static-Node `review_risk_class` concept from
ADR-0044 D8 / ADR-0086 D8. The decision has eight bound sub-decisions.

### D1 — Risk is assessed per-change, not per-Node. The unread `review_risk_class` key is simply not used.

The unit of risk assessment is the **(PR, head SHA)** pair, not the repo. The
`review_risk_class` config key — whether sourced from `grid-health.json` (ADR-0044's
never-populated plan) or from `.honeydrunk-review.yaml` (the workflow's current
default-`normal` read) — is **not the risk source**. Invariant 53's "high-risk Node"
wording is reinterpreted (see D8) as "high-risk *change*."

**No transition phase, because there is no contract to protect (decided).** An
earlier draft proposed retaining the `review_risk_class` name as a computed value
"for one transition phase to avoid churning the local-worker queue-comment contract."
That premise is **false** and is dropped. There is no such contract: the worker reads
**no** `review_risk_class` / `risk_class` field. Verified in
`infrastructure/workers/grid-agent-runner/lib/Queue.psm1` — the only queue-comment
fields parsed are `head_sha` (`Get-HeadShaFromQueueComment`) and `claimed_at`
(`Get-ClaimedAtFromQueueComment`); nothing in the runner consumes the risk field.
The `review_risk_class` key in `.honeydrunk-review.yaml` and the `risk_class:` line
the trigger writes into the queue comment are a **phantom gate that was never
consumed** — not a live contract being transitioned. Accordingly:

- The scorer emits `risk_score`, `double_review_required`, and `risk_rationale` into
  the queue comment **from day one** (D5). There is no interim computed-`review_risk_class`
  step and no retirement step, because nothing ever read the field.
- The `review_risk_class` config key / `risk_class` queue-comment line are simply
  **not used** by this design. The trigger may stop writing the dead `risk_class:`
  line as a cleanup (packet detail); doing so changes no behavior because the worker
  never read it.

A Node's standing sensitivity remains an **input** to the per-change score (D2), not
the output. The change from ADR-0044/0086 is: sensitivity-of-location is one
weighted signal among several, evaluated against *what the diff actually touches*,
not a binary flag that fires on any PR to the repo.

### D2 — Four weighted risk signals

The score is a weighted sum of four signals, each independently observable from data
the trigger workflow already collects or can collect cheaply:

1. **Sensitivity of touched area (highest weight).** Does the diff touch a
   sensitive path or symbol? Sensitivity is resolved against a committed
   **sensitivity map** (D4) derived from — not duplicating — the areas ADR-0044 D8
   and ADR-0083 already name: `*.Abstractions/**` (Kernel ABI), secret/Vault
   handling (`**/Vault/**`, `ISecretStore`, secret-resolution paths), Auth token
   validation and principal resolution, the Audit append-only boundary, Transport
   middleware/envelope, Data migration/persistence paths, `.honeydrunk-review.yaml`
   / `boundaries.md` / `invariants.md`, any path or org-secret named in
   `sensitive-inventory.md`, OIDC subject patterns, and CI workflow files that wield
   privileged tokens. **This is the signal that makes a one-line change high-risk.**

2. **Blast radius (high weight).** How many downstream consumers depend on the
   touched contracts? Resolved from `catalogs/relationships.json`: a change to a
   Node's `exposes.contracts` or `*.Abstractions` package scores proportional to the
   size of that Node's `consumed_by` (and, at a discount, `consumed_by_planned`)
   set. A change confined to internal/runtime code with no contract surface scores
   low here regardless of repo.

3. **Boundary spread (medium weight).** A **structural** signal computed from the
   file *paths* only: how many distinct package / boundary roots the diff straddles
   (e.g. distinct top-level path roots such as `src/<Package>/…`, `infrastructure/…`,
   `.github/…`, `catalogs/…`), and whether the diff touches **code-bearing file
   extensions** (`.cs`, `.ps1`, `.psm1`, `.yml` workflow files, …) versus pure
   docs/config (`.md`, plain text). A change that straddles several packages or
   crosses a code boundary is structurally riskier than one confined to a single
   package or to docs, **independent of how many lines it changes**. This is
   deliberately **not** a line-count proxy. **Tier limitation:** because the
   cloud-Action scorer has only the file list + per-file add/delete counts and does
   **not** fetch file contents or diff hunks (see Context), deeper structural
   complexity — control-flow shape, cyclomatic complexity, API-surface deltas — is
   **not computable at this tier** and is explicitly out of scope for this signal. A
   richer complexity signal that reads file contents is a possible future
   worker-tier enhancement (Follow-up Work), not part of this ADR.

4. **Diff size (lowest weight).** Total added+deleted lines, file count. Included
   because large diffs do carry review-coverage risk, but **explicitly the weakest
   signal** so that size alone never forces double-review and small size never
   exempts a sensitive change. Coordinates with — does not duplicate — ADR-0044 D7's
   independent PR-size discipline. Note: size and boundary-spread are both derived
   from the same file/line data, but they read **different facets** of it — size is a
   magnitude (line/file *counts*), boundary-spread is a structural shape (distinct
   *roots* crossed, code-vs-docs). The ordering below ranks the structural facet over
   the magnitude facet; it does not claim to rank a signal over the data it is
   derived from.

**This ADR pins only the signal ordering, not the numbers.** The binding constraint is
the ordering `sensitivity ≥ blast-radius > boundary-spread > size`. The concrete numeric
weights and the threshold above which a PR flips into double-review are **deliberately
left to the implementing packet** so they remain tunable against observed firing rate
during the pilot (D7) **without an ADR amendment**. Re-tuning weights or the threshold
is an implementation change, not an architecture change; only a change to the *ordering*
above would require amending this ADR.

### D3 — Mechanism: deterministic weighted-signal scorer in the trigger workflow

The scorer is a **deterministic, heuristic, weighted-signal evaluator** that runs in
the existing `job-review-request.yml` workflow seam (the cheap GitHub Action, no LLM
in the cloud path per ADR-0086 D2). It consumes the changed-file list and per-file
add/delete counts (`gh api …/files` — file contents and diff hunks are **not**
fetched at this tier), the committed sensitivity map, and `relationships.json`; it
emits a numeric `risk_score`, a boolean `double_review_required`, and a one-line
`risk_rationale` into the queue comment **from day one** (D5). The worker does not
read any risk field today (D1); a follow-up adds `double_review_required` consumption
to the worker as part of standing up the dual-pass substrate (see D8, Follow-up Work).

**This ADR is scoped to the deterministic, arithmetic gate only.** The gate is
deterministic so that the decision is auditable, free (no cloud LLM spend per ADR-0086
D6), and explainable in the queue comment ("why was my one-line PR double-reviewed?").
An LLM-judged risk triage is **out of scope** for this ADR — not a deferred or reserved
future phase of it. If LLM-based risk escalation is ever wanted, it is a separate future
ADR with its own decision; this ADR neither builds it nor reserves a slot for it. See
Alternatives Considered for why pure-LLM and pure-static-label options were not chosen.

### D4 — Sensitivity map: one committed catalog, derived from existing sources

The sensitivity inputs live in a new committed catalog,
**`catalogs/review-risk-signals.json`**, structured as
machine-readable path-glob and symbol/contract patterns with per-pattern weight
contributions. A new dedicated catalog is committed deliberately: `grid-health.json`
is **not** retrofitted with a risk structure (it is repo-readiness data at the wrong
granularity), and neither `relationships.json` (a weightless dependency graph) nor
`sensitive-inventory.md` (human-Markdown ADR-0083 D2 kept tooling-free) is the right
home for a weight-bearing machine surface. It is **derived from and cross-references** — never silently
duplicates — the authoritative sources:

- ADR-0044 D8's enumerated high-risk areas (Kernel Abstractions, Vault, Auth, Audit,
  `.Cloud` revenue Nodes).
- `catalogs/relationships.json` `exposes.contracts` (for blast-radius lookups).
- ADR-0083's `infrastructure/reference/sensitive-inventory.md` rows (sensitive
  org-secrets, OIDC patterns, webhook secrets, consuming workflow paths).

Why a new catalog rather than reusing one of the above directly: `relationships.json`
is a dependency graph (no weights), `grid-health.json` is repo readiness (wrong
granularity), and `sensitive-inventory.md` is human-Markdown that ADR-0083 D2
deliberately kept tooling-free and tier-free. The scorer needs a single
weight-bearing, machine-readable surface; this catalog is that surface, and it stays
honest via a `hive-sync`/`node-audit` cross-check that flags drift between it and its
sources (follow-up). The catalog evolves with the Grid without amending this ADR —
the same "list lives in a catalog, not the ADR body" property ADR-0044 D8 wanted for
`review_risk_class`, now correctly shaped.

### D5 — The score is transparent and recorded

The trigger workflow writes a `risk_score`, the `double_review_required` boolean, and
a one-line `risk_rationale` (which signals fired, e.g. `sensitivity: touched
ISecretStore resolution; blast-radius: Kernel.Abstractions consumed_by=9`) into the
queue comment — these explicit fields ship from day one (D1), replacing the dead
`risk_class:` line. Once the dual-pass worker substrate exists (D8 prerequisite), the
worker will read `double_review_required` to decide whether to run the second model
pass per ADR-0086 D8; until then the field is recorded and observed (shadow, D7) but
not acted on. A `risk-high` PR label is applied when the gate trips (creatable via the
existing labels-as-code pattern), so the gate is visible in the PR UI and the weekly
briefing. The rationale makes every double-review decision auditable and tunable — the
operator can see *why* a one-line PR was flagged.

### D6 — Authorship interaction: agent PRs gate on score; the most-sensitive paths force the gate regardless of authorship

The score is computed for **every** enabled PR. There are two ways the double-review
gate fires:

1. **Score-based (agent-authored).** For non-`human` (agent-authored) PRs, the gate
   fires when `double_review_required` (the score crosses the D2 threshold). This is the
   ADR-0044 D8 / former-Invariant-53 scope, now driven by the per-change score rather
   than a static Node flag.

2. **Sensitivity-forced (any authorship).** When the **sensitivity signal trips on the
   most sensitive paths** — Vault secret-resolution, credentials, and
   `ISecretStore`-class contracts (the subset of D2.1 the new Invariant 53 names
   explicitly) — the PR is forced into the double-review gate **regardless of
   authorship**, including human-authored PRs. Such a PR is labeled `risk-high` **and**
   reviewed accordingly with the dual-model pass.

This is a deliberate **change from earlier drafts**, which exempted human-authored PRs
on the "the human is already a perspective" rationale. That exemption is **withdrawn for
the most-sensitive paths**: a hand-edit to secret-resolution or a credentials contract
is exactly where a second independent model perspective is most valuable, and authorship
does not lower that risk. Outside those most-sensitive paths, human-authored PRs are not
force-gated — they get the single Grid-aware pass and surface `risk-high` as a signal —
because the human author supplies one perspective for ordinary changes.

**Amendment to ADR-0086 D8 / ADR-0044 D8 scope.** Both prior ADRs scoped double-review
to *agent-authored* PRs only. Forcing human-authored PRs on the most-sensitive paths
into the gate **extends** that scope. This is an explicit, intentional amendment, encoded
in the rewritten Invariant 53 ("forced into the double-review gate regardless of
authorship" for the named sensitive paths) so the constitution and this ADR agree and do
not contradict ADR-0086's general agent-only handling — the human-PR force-gate is the
narrow, named exception, not a blanket reversal. The operator may also manually request
the second pass on any PR.

### D7 — Phased activation, tuned against firing rate

- **Phase 1 — Shadow.** Scorer runs and records `risk_score` + `double_review_required`
  + `risk_rationale` in the queue comment, but nothing acts on them. The operator
  observes the firing rate on real PRs in the `HoneyDrunk.Architecture` pilot
  (consistent with ADR-0086 Phase A blast radius) and tunes weights/threshold. No
  behavior change. **This phase has no external prerequisite** — the scorer ships and
  runs in shadow independently of the worker.
- **Phase 2 — Gate on pilot.** `double_review_required` actually triggers the second
  worker pass on the pilot repo. Verify the gate fires on genuinely risky changes and
  stays quiet on docs/test churn. **Hard prerequisite:** this phase cannot begin until
  the ADR-0086 dual-pass execution + synthesis + contrarian-fallback substrate exists
  in the worker (D8) — that substrate is **not yet implemented** and is what
  `double_review_required` triggers.
- **Phase 3 — Grid-wide.** The gate activates on all `enabled` repos as ADR-0086
  Phase B/D reaches them. Invariant 53 becomes enforceable (per-change definition).
  (No `review_risk_class` key needs retiring — it was never consumed; see D1.)

There is no Phase 4. The deterministic gate is the full scope of this ADR; LLM-based
escalation is out of scope (D3) and would be a separate future ADR if ever pursued.

### D8 — Relationship to ADR-0086 D8 and Invariant 53: amendment-in-part, not supersession

This ADR is a **standalone ADR that amends ADR-0086 D8 (and transitively ADR-0044 D8)
in part** — it replaces *only* the definition of "high risk" (the *trigger* for
double-review). It does **not** supersede ADR-0086, and it does **not** define or
build the dual-CLI execution substrate itself.

**Honest statement of the substrate's status (corrected).** The dual Codex/Claude
second pass + synthesis + contrarian-prompt fallback that ADR-0086 D8 describes is
**not yet implemented**. Verified:
ADR-0086's own Follow-up Work still lists *"Implement dual-pass synthesis in the
worker"* as not-done; `infrastructure/workers/grid-agent-runner/lib/Agent.psm1`'s
`Invoke-ReviewAgentPasses` runs a flat `foreach ($command in $JobSpec.AgentCommands)`
loop with **no** risk-conditional second pass; and
`infrastructure/workers/grid-agent-runner/lib/Synthesis.psm1`'s `Join-ReviewFindings`
is defined and exported but has **zero callers** (dead code). So that substrate is
**ADR-0086 deferred work**, not a preexisting thing this ADR preserves. This ADR
changes the *trigger* for double-review; the execution substrate the trigger fires is
a **hard prerequisite** that must be built (under ADR-0086's follow-up) before the
enforcement (Phase 2/3) end of this ADR. The per-change scorer can ship and run in
shadow (Phase 1) independently, but **nothing acts on `double_review_required` until
that substrate exists**.

| Prior decision | Posture under this ADR |
|---|---|
| ADR-0086 D8 — dual Codex/Claude substrate, synthesis, contrarian fallback | **Unchanged scope, but NOT yet built.** This ADR does not modify it and does not preserve a working thing — the substrate is ADR-0086 *deferred/unimplemented* work and a **hard prerequisite** for this ADR's Phase 2/3. Only the *trigger* into it is what this ADR defines. |
| ADR-0086 D8 / ADR-0044 D8 — "high-risk Node" via static `review_risk_class` | **Amended.** Replaced by the per-change scorer (D1–D5). The `review_risk_class` key was never consumed by the worker, so there is no contract to transition — it is simply unused (D1). |
| ADR-0086 D8 / ADR-0044 D8 — double-review scoped to *agent-authored* PRs only | **Amended (scope extended).** Human-authored PRs touching the most-sensitive paths (Vault secret-resolution, credentials, `ISecretStore`-class contracts) are now force-gated too (D6). Narrow named exception, not a blanket reversal. |
| ADR-0044 D7 — PR-size discipline | **Preserved**, distinct axis; size is the weakest signal here (D2.4). |
| ADR-0083 — sensitive-inventory | **Reused as a source**, not modified. The new catalog cross-references it. |
| Invariant 53 — "high-risk Node" via static `review_risk_class` | **Reinterpreted and rewritten in place** (number unchanged) as "high-risk *change*", computed per-change by the scorer. The `grid-health.json:review_risk_class` catalog reference is removed from the invariant. ADR-0044 D8's static `review_risk_class`-as-per-Node-flag wording is **superseded** so the two no longer conflict. Proposed new wording quoted under Consequences → Invariants. Becomes enforceable once Phase 3 lands (closing the "not enforceable" caveat). |

**Recommendation: standalone ADR (this one), not an amendment buried in ADR-0086.**
Rationale: ADR-0086 is Accepted and about *transport/substrate*; risk *definition* is
a distinct, reusable concern that ADR-0044, ADR-0086, and Invariant 53 all point at.
A standalone ADR gives it one citable home, keeps ADR-0086's Accepted text immutable
(Invariant-24-style discipline), and lets the definition evolve without reopening the
review-runner ADR. ADR-0086 D8 and Invariant 53 gain a one-line "high-risk is defined
per-change per ADR-0087" amendment pointer at this ADR's acceptance.

## Consequences

### Affected Nodes

- **HoneyDrunk.Architecture** — new `catalogs/review-risk-signals.json`; this ADR;
  amendment pointers appended to ADR-0044 D8 / ADR-0086 D8 references and Invariant 53
  (number unchanged — only the catalog reference and "enforceable once ADR-0087 Phase
  3" note change). Pilot repo for Phases 1–2.
- **HoneyDrunk.Actions** — `job-review-request.yml` gains the deterministic scorer
  step (reads changed files + per-file add/delete counts + `review-risk-signals.json`
  + `relationships.json`, writes `risk_score` / `double_review_required` /
  `risk_rationale` into the queue comment from day one). The existing default-`normal`
  `review_risk_class` read and the dead `risk_class:` queue-comment line are dropped
  (neither was ever consumed by the worker; D1). New `risk-high` label seeded via
  labels-as-code.
- **The local worker (ADR-0086 / ADR-0081 host)** — must first **gain the dual-pass
  execution + synthesis + contrarian-fallback substrate**, which is ADR-0086 deferred
  work that does **not exist yet** (D8) and is a hard prerequisite for Phase 2/3. As
  part of that work the worker will begin reading `double_review_required` from the
  queue comment to decide the second pass. The worker reads no risk field today; there
  is no legacy `review_risk_class` read to retire (D1).
- **`.claude/agents/review.md`** — **no change** required (the gate is upstream of the
  agent).
- **Every `enabled` repo** — gains the `risk-high` label; gate activates per ADR-0086
  Phase B/D cadence.

### Cascade Impact

Per `catalogs/relationships.json`, the scorer's blast-radius signal will fire most
strongly on changes to **HoneyDrunk.Kernel** (`consumed_by` = 9 live + 9 planned) and
its `*.Abstractions`, then **Vault** / **Transport** / **Auth** / **Data** contracts.
This correctly concentrates double-review on the genuinely high-fan-out contract
changes the static-Node approach would have over-applied to every docs PR in those
repos. No runtime cascade — this is review-process architecture; no Node code or
contract changes.

### Tier

This ADR is itself a **Tier 3** change per `catalogs/flow_tiers.json` (affects an
invariant's enforceability and a cross-repo review boundary; requires an ADR). The
mechanism it builds *classifies* other PRs into the double-review path but is not a
runtime contract.

### Invariants

- **Invariant 53 is reinterpreted and rewritten in place** — no new invariant is
  added. The decision is to make the rewritten wording **self-contained and
  unambiguous** so it cannot collide with any other invariant or leave room for
  questions: it states plainly that "high risk" is computed per-change by the scorer
  and is **never** a static per-repo flag. The ADR-0044 D8 / former-Invariant-53
  `review_risk_class`-as-per-Node-flag language is **superseded** by this wording, so
  the two no longer contradict each other. Proposed new Invariant 53 text:

  > 53. **Agent-authored PRs whose changes are scored high-risk receive two
  >    independent LLM-review perspectives before merge.** "High risk" is computed
  >    **per change**, on the (PR, head SHA) pair, by the deterministic weighted-signal
  >    scorer defined in ADR-0087 (signals: sensitivity of touched area, blast radius,
  >    boundary spread, diff size), evaluated against `catalogs/review-risk-signals.json`
  >    and `catalogs/relationships.json`. It is **never** a static per-Node or per-repo
  >    flag; no `review_risk_class` repo field gates this invariant. A change whose
  >    sensitivity signal trips the most sensitive paths (Vault secret-resolution,
  >    credentials, `ISecretStore`-class contracts) is forced into the double-review
  >    gate **regardless of authorship**. The second perspective is the dual Codex CLI +
  >    Claude Code CLI pass on the local worker, synthesized into one verdict (ADR-0086
  >    D8); the human may also invoke `refine` for manual escalation. Enforceable once
  >    ADR-0087 Phase 3 lands **and** the ADR-0086 dual-pass worker substrate it depends
  >    on is implemented (D8 prerequisite).

  This rewording closes the prior "accepted as the Phase-3 target state but not
  enforceable" caveat at Phase 3 and removes the now-dead `grid-health.json:review_risk_class`
  catalog pointer. Applying it is a follow-up at this ADR's acceptance (see Follow-up Work).
- No invariant is weakened. Invariant 8 (no secrets in logs) is preserved — the scorer
  reads *paths and contract names*, never secret values, and the `sensitive-inventory`
  cross-reference uses names only.

### Follow-up Work

- Author `catalogs/review-risk-signals.json` (path globs + contract/symbol patterns +
  per-signal weights), derived from ADR-0044 D8 areas, `relationships.json`
  `exposes.contracts`, and `sensitive-inventory.md` rows. Mark the Vault
  secret-resolution / credentials / `ISecretStore`-class patterns as the
  **sensitivity-forced** subset that gates regardless of authorship (D6).
- Implement the deterministic scorer step in `job-review-request.yml`; pin weights and
  threshold (ordering per D2 is binding; numbers are packet-tunable per D2/D7); emit
  `risk_score` / `double_review_required` / `risk_rationale` into the queue comment
  from day one, and drop the dead `risk_class:` line (it was never consumed; D1).
- **Prerequisite (ADR-0086 deferred work): build the dual-pass execution + synthesis +
  contrarian-fallback substrate in the worker** — `Invoke-ReviewAgentPasses` gains a
  risk-conditional second pass and calls `Join-ReviewFindings` (currently dead code)
  for synthesis. This is the same item ADR-0086 Follow-up Work lists as *"Implement
  dual-pass synthesis in the worker"* and is a **hard prerequisite** for this ADR's
  Phase 2/3 (D8). Nothing acts on `double_review_required` until it lands.
- Once that substrate exists, wire `double_review_required` consumption into it so the
  scorer's verdict actually triggers the second pass (D5, D7 Phase 2). No
  `review_risk_class` queue-comment key needs retiring — it was never read (D1).
- Wire the **sensitivity-forced** gate so it fires on human-authored PRs touching the
  named sensitive paths (D6).
- Seed the `risk-high` label via labels-as-code.
- Add a `hive-sync` / `node-audit` cross-check that flags drift between
  `review-risk-signals.json` and its source documents.
- At acceptance: **rewrite Invariant 53 in place** to the wording quoted under
  Consequences → Invariants (removing the `grid-health.json:review_risk_class` pointer
  and the static-flag language), and append amendment pointers to ADR-0044 D8 and
  ADR-0086 D8 (static-flag superseded; human-PR force-gate on sensitive paths extends
  their agent-only scope).

## Alternatives Considered

### A. Keep `review_risk_class` as a static per-Node flag (ADR-0044/0086 as written)

Rejected. This is the status quo the operator is correcting. It over-fires on
docs/test churn in sensitive repos, under-fires on dangerous changes in ordinary
repos, and treats a one-line `ISecretStore` change identically to a README edit in the
same repo. It also remains a phantom (never populated). Repo-granularity is the wrong
shape for a risk that is fundamentally about *what the diff does*.

### B. LLM-judged risk triage (as the gate, or as a hybrid tiebreaker)

Considered: have an LLM read every diff and judge "is this high risk?", either as the
gate itself or as a tiebreaker that upgrades borderline deterministic scores.
**Rejected and explicitly out of scope for this ADR.** A cloud LLM in the trigger path
violates ADR-0086 D2's "no LLM in the cloud Action" / D6's $0-marginal-cost design;
running it on the worker makes the gate non-deterministic and unauditable for a
decision that should be explainable ("why was my one-line PR double-reviewed?"). This
ADR commits the deterministic, arithmetic gate only and does **not** reserve a future
hybrid phase (no "Phase 4"). If LLM-based escalation is ever wanted, it is a separate
future ADR with its own decision — not a deferred slot inside this one.

### C. Pure label-driven heuristic (operator/author hand-applies a `risk-high` label)

Considered: reuse the existing label-classification machinery and let a human or the
authoring agent tag risk. Rejected as the primary mechanism — it reintroduces the
ADR-0044 D10 failure mode ("a distracted solo developer forgets"), and an
agent-authored PR self-assessing its own risk is exactly the case the double-review
safeguard exists to backstop. The label is kept as an *output* (D5) for visibility,
not as the input.

### D. Reuse `flow_tiers.json` Tier 3 directly as the gate

Considered: Tier 3 already means "affects contracts, invariants, cross-repo
boundaries." Rejected as insufficient alone — Tier is assigned at *planning/packet*
time and is coarse (three buckets), whereas the gate must fire on the *actual diff*,
including changes that slipped scope or weren't tier-classified (out-of-band PRs per
ADR-0044). Tier vocabulary is borrowed in the sensitivity map; Tier is not the gate.

### E. Amend ADR-0086 D8 in place instead of a standalone ADR

Considered. Rejected per D8 rationale: ADR-0086 is Accepted and transport-scoped;
folding a reusable risk *definition* into it would mutate Accepted text and bury a
cross-cutting concern that ADR-0044, ADR-0086, and Invariant 53 all reference. A
standalone ADR is the citable, evolvable home.

## References

- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — D8 origin of the static "high-risk Node" definition this ADR amends; D7 PR-size discipline (distinct axis)
- [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) — D8 dual-CLI substrate (ADR-0086 deferred/unimplemented work; a **hard prerequisite** for this ADR's Phase 2/3, see its Follow-up Work "Implement dual-pass synthesis in the worker"), D2/D6 cheap-Action/$0-cost constraints the scorer respects
- [ADR-0083](./ADR-0083-external-saas-credential-rotation.md) — sensitive-inventory; a sensitivity-map source (reused, not modified)
- [ADR-0046](./ADR-0046-specialist-review-agents.md) — Invariant 53 source
- [`constitution/invariants.md`](../constitution/invariants.md) — Invariant 53 (rewritten in place to the per-change definition quoted above; static-flag wording superseded; becomes enforceable at Phase 3)
- [`catalogs/relationships.json`](../catalogs/relationships.json) — blast-radius signal source
- [`catalogs/flow_tiers.json`](../catalogs/flow_tiers.json) — Tier vocabulary borrowed into the sensitivity map
- `HoneyDrunk.Actions/.github/workflows/job-review-request.yml` (commit 7a3330e) — the trigger seam the scorer plugs into

## Resolved Decisions

The six questions that were open at first draft are now resolved and encoded in the
body above. Recorded here for traceability:

1. **Catalog.** New dedicated `catalogs/review-risk-signals.json`. `grid-health.json` is
   **not** retrofitted. (D4.)
2. **Invariant.** Invariant 53 is **reinterpreted and rewritten in place** — no new
   invariant. The rewritten wording is self-contained and unambiguous: high risk is
   computed per-change by the scorer, never a static per-repo flag. ADR-0044 D8's static
   `review_risk_class`-as-per-Node-flag language is **superseded** so the two do not
   collide. Proposed text quoted under Consequences → Invariants. (D8, Consequences.)
3. **Weights/threshold.** This ADR pins **only the signal ordering**
   (`sensitivity ≥ blast-radius > boundary-spread > size`); numeric weights and the
   threshold are left to the implementing packet, tunable without an ADR amendment. The
   third signal is **boundary spread** (distinct package/path-root boundaries crossed +
   code-vs-docs classification), a structural signal computed from the file list only —
   **not** a line-count proxy. Deeper structural complexity (control-flow shape, API
   deltas) is **not computable at the cloud-Action tier** without fetching file
   contents and is deferred to a possible future worker-tier enhancement. (D2.)
4. **Human-authored sensitive PRs.** Human-authored PRs touching the most-sensitive
   paths (Vault secret-resolution, credentials, `ISecretStore`-class contracts) **are**
   forced into the double-review gate — labeled `risk-high` **and** dual-model reviewed,
   regardless of authorship. This extends the agent-only scope of ADR-0086 D8 / ADR-0044
   D8 and is encoded as the named exception in the rewritten Invariant 53. (D6.)
5. **`review_risk_class` field.** **Corrected decision (supersedes the earlier "keep
   the name one transition phase" call).** Once the code was checked, the earlier
   premise proved false: the worker reads **no** `review_risk_class` / `risk_class`
   field (`lib/Queue.psm1` parses only `head_sha` and `claimed_at`). There is no worker
   contract to protect, so there is **no transition phase and no retirement step**. The
   scorer emits `risk_score` / `double_review_required` / `risk_rationale` from day one;
   the `review_risk_class` config key and the `risk_class:` queue-comment line are a
   never-consumed phantom gate and are simply **not used** (the trigger may drop the
   dead line as cleanup). (D1.)
6. **Hybrid LLM tiebreaker.** **Dropped.** This ADR is scoped to the deterministic /
   arithmetic gate only. No Phase 4 is reserved. LLM-judged escalation appears only in
   the rejected Alternatives (B) as explicitly out of scope. (D3, D7, Alternative B.)
