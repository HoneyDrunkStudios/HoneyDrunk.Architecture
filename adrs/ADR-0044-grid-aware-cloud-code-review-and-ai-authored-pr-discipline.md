# ADR-0044: Grid-Aware Cloud Code Review and AI-Authored PR Discipline

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

ADR-0011 (Proposed) established the Grid's code review pipeline with the Grid-aware `review` agent as **local-only and human-invoked** (D10). The accepted risk was "a distracted solo developer may forget to invoke the review agent." The same ADR (D11) rejected CodeRabbit on the grounds that the automatic-LLM-reviewer slot was already filled by Copilot.

Both decisions were correct in April 2026. Both are stale today:

- **AI-authored PR volume has scaled.** Wave-style rollouts routinely produce 5–15 agent PRs in a window. The AI-sector standup wave (ADR-0016 through ADR-0025) adds nine Nodes' worth of scaffold packets. ADR-0043's Strategic and Tactical sources will mechanically generate agent PRs on cadence once running. "Human remembers to invoke the review agent" is no longer a viable discipline.
- **Copilot's automatic review has not earned its slot.** Its PR-time signal is generic (style nits, occasional null-check suggestions) and not Grid-aware. It does not load `constitution/invariants.md`, cannot read a packet via PR-body link, and has no knowledge of which ADRs govern a change. It fills a slot in name only.
- **CodeRabbit was reconsidered** in the conversation that produced this ADR. Its rule system via `.coderabbit.yaml` is genuinely strong for prose-shaped rules, but its hard limit is that it cannot actively load Grid catalogs (`relationships.json`, `contracts.json`, `grid-health.json`) at review time, walk invariants, or reason against a linked packet's stated scope. The "make sense with the Grid and our ADRs" requirement is the one thing no third-party tool can do, because no third-party tool knows the Grid.

The conclusion: **the slot that needs filling is not "automatic LLM reviewer" generically — it's "automatic Grid-aware LLM reviewer."** That slot is empty. Filling it means cloud-wiring the existing local `review` agent, not adopting an external service that fills the slot only by name.

The build is small. The prompt logic exists in `.claude/agents/review.md`. The context-loading contract is defined in ADR-0011 D4. The workflow host exists in HoneyDrunk.Actions. The Claude Agent SDK provides the runtime. The MVP is a 1–2 day engineering project — wire the existing agent into a GitHub Action, post the verdict as a PR comment. Polish (per-path config, learnings, output formatter) is bounded follow-up.

The cost calculus has also shifted. The April 2026 ADR-0011 D10 rejection was per-PR cloud LLM cost against a low PR volume; at today's volume (~20–50 agent PRs/month) and current Sonnet pricing, expected monthly cost is ~$40–100. Comparable to CodeRabbit private-tier; cheaper than running `/ultrareview` on every PR; smaller than the cost of a single late-caught production regression.

This ADR amends ADR-0011 to **reverse the local-only stance**, **reverse the CodeRabbit rejection as moot** (we're not adopting an alternative), and add **AI-authored PR discipline** that the cloud-wired reviewer makes practical to enforce.

## Decision

The decision has two intertwined halves: the **build** (D1–D5) makes the **discipline** (D6–D9) practical. Neither half stands alone.

### D1 — Build the cloud-wired reviewer as `job-review-agent.yml` in HoneyDrunk.Actions

The Grid builds, owns, and operates its own cloud-wired Grid-aware code reviewer. Implementation:

- A new reusable workflow, `HoneyDrunk.Actions/.github/workflows/job-review-agent.yml`, follows the existing `pr-core.yml` factoring (per ADR-0012).
- Triggered on `pull_request` events: `opened`, `synchronize`, `ready_for_review`. Not on `draft` PRs (cost discipline; draft is by definition WIP).
- Invokes the Claude Agent SDK against the `.claude/agents/review.md` definition (per ADR-0007's source-of-truth rule).
- Posts the verdict as a PR comment using the format already defined in `.claude/agents/review.md`.
- Sets a **non-required** check run (advisory, per ADR-0011 D5's posture — preserved by this ADR).

The agent definition itself does not change. The same prompt that runs locally via Claude Code runs in the cloud workflow. Drift between the two execution surfaces is forbidden — both consume `.claude/agents/review.md` directly.

### D2 — Context loading is identical to the local invocation

The cloud-wired reviewer loads exactly the context ADR-0011 D4 already mandates:

1. `constitution/invariants.md`
2. Governing ADRs referenced in the packet frontmatter
3. `catalogs/relationships.json`
4. `catalogs/contracts.json`
5. For each target repo: `repos/{node}/overview.md`, `boundaries.md`, `invariants.md`
6. `copilot/pr-review-rules.md`
7. The packet file (via PR-body link)
8. The PR diff

The workflow checks out both the target repo and `HoneyDrunkStudios/HoneyDrunk.Architecture` (using a GitHub App token scoped to read on the architecture repo) so the context above is locally readable by the agent. This mirrors the local Claude Code workspace layout exactly.

ADR-0011 D4's coupling rule (review-agent context-loading must mirror scope-agent context-loading) is preserved. Updates land in `.claude/agents/review.md`, the workflow re-runs without code change.

### D3 — Review goals and rubric

The cloud-wired reviewer (and the local one, since both consume `.claude/agents/review.md`) evaluates every PR against five dimensions. Each dimension carries a category of concerns. The detailed per-dimension checklist — what specifically to look for, what counts as a finding, what severity to apply — lives in `.claude/agents/review.md` per ADR-0007's source-of-truth rule and ADR-0011 D6/D7's binding precedent that responsibility-checklists live in the agent file, not in the ADR text. This ADR binds the **dimensions and their intent**; the agent file binds the **checklists that implement them**.

**1. Correctness and reliability.** Does the code do what the packet says it should? Are bugs likely to be present — off-by-one, null dereference, incorrect boolean logic, race conditions in async paths, swallowed exceptions, incorrect error propagation? Are edge cases handled and error paths exercised? Does the change preserve the behavior of code it touches (no silent regressions)? Are the tests **actually exercising the new behavior** — no tautological assertions (`Assert.True(true)`, `Assert.Equal(x, x)`), no mocked-out system-under-test, no boilerplate that would pass regardless of the production change? Is there at least one negative-path assertion (wrong inputs produce wrong-shaped errors, not silent success)? Are tests in the correct test project (unit in `.Tests`, integration separated per ADR-0011 Gap 1)?

**2. Code quality.** Is the code maintainable, readable, and appropriately simple? Does it honor **DRY** — no copy-paste of logic that already exists in this file, this Node, or another Grid Node's published package? Does it honor **SOLID** where the abstractions justify the cost: single responsibility per class; open for extension, closed for modification; Liskov substitution preserved; interface segregation respected; dependencies inverted at boundaries? Does it follow the conventions in this Node and the Grid (naming, file layout, formatting beyond what analyzers catch, idiomatic patterns)? Does it use **established patterns** rather than inventing parallel ones? Is the result **enterprise-grade** — would a senior engineer at a larger shop ship this without rework?

**3. Design hygiene.** Does the change **extend or reuse existing code** rather than write parallel new code? Before writing a new method or class, was there a usable existing one in this file, this Node, or a referenced Node's package? Cross-Node copy-paste is forbidden and is a Block-grade finding (see also dimension 5). Is the resulting surface **testable** — dependencies injectable, side effects isolated, no static mutable state where avoidable, time and randomness abstracted where they affect behavior? Is it **extensible** at the seams that warrant it (open/closed where the cost is justified, **not** for hypothetical futures — per the project's "no premature abstraction" stance)? Is it **configurable** at the right boundaries (settings, environment, feature flags — not magic numbers, not hardcoded environment-specific values), **without over-engineering toward configurability for its own sake**?

**4. Security and performance.**
   - **Security.** Does the change introduce a regression — secret in logs (Invariant 8), PII in telemetry (ADR-0040 D9), missing tenant-scoping (ADR-0026), broken or bypassed authentication paths (ADR-0031), unvalidated input crossing a trust boundary, SQL/command injection surface, deserialization of untrusted data, secrets in source? Does it weaken an existing security boundary?
   - **Performance.** Does the change introduce a regression in a hot path — synchronous I/O in a request handler, unbounded loops, allocation in tight loops, new HTTP or database round-trips per request, N+1 queries, blocking calls in async paths, missing pagination on potentially-large result sets, new outbound calls without timeouts?
   - **Cost discipline.** ADR-0011 D6's named checklist (log volume, LLM cost caps, CI guards, Azure SKU justification) is part of this dimension, not a separate concern.

**5. Grid fit.** This is the dimension only a Grid-aware reviewer can evaluate, and it is why this reviewer is built rather than bought.
   - **Node-job adherence.** Is the change consistent with the Node's stated purpose in `repos/{node}/overview.md`? Does the Node continue to do its correct job — neither more (scope inflation) nor less (responsibility erosion)?
   - **Boundary respect.** Does the change cross a Node boundary it shouldn't? Does it leak responsibility into a different Node's surface (per `repos/{node}/boundaries.md` and the sector-interaction rules in `constitution/sector-interaction-map.md`)?
   - **Reuse-across-Nodes over reimplementation.** If logic the PR needs already exists in another Grid Node's published package, the PR **must consume that package**, not duplicate the logic. Cross-Node copy-paste is the single most expensive long-term failure mode and is a Block-grade finding.
   - **Dependency hygiene.** When the PR needs functionality from another Node, does it take the dependency the **right way** — via the upstream Node's published `*.Abstractions` per ADR-0035, never via a reach-around into the backing implementation? Is the version pinned correctly?
   - **Invariant preservation.** Every Grid-wide invariant (`constitution/invariants.md`) and every per-Node invariant (`repos/{node}/invariants.md`) is preserved. Walked explicitly per ADR-0011 D7.
   - **Packet adherence.** The change does what the linked packet says — no more (scope creep, undocumented refactors riding along), no less (scope shortfall, declared work missing). Side effects not in the packet are flagged.
   - **Contract preservation.** Public surfaces (`*.Abstractions`) follow ADR-0035 versioning rules; no silent ABI breaks at minor/patch versions; `PublicAPI.Unshipped.txt` updates match the declared bump.

The verdict comments findings against these dimensions using the severity taxonomy in `copilot/pr-review-rules.md` (`Block` / `Request Changes` / `Suggest`). The taxonomy and the per-dimension checklist are the two things `.claude/agents/review.md` binds; updates land there, not in this ADR. The dimensions themselves change only via amendment to this D3.

### D4 — Per-repo configuration via `.honeydrunk-review.yaml`

Each repo carries an optional `.honeydrunk-review.yaml` at the repo root. The v1 schema is deliberately minimal; the file's primary purpose is the **enabled/disabled gate** during phased rollout. Additional knobs land as later amendments.

v1 schema:

```yaml
enabled: true                # required; default-off until repo opts in (D11)
severity_floor: Suggest      # minimum severity for posted findings: Suggest | Request Changes | Block
skip_paths:                  # globs excluded from review
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
model: sonnet                # sonnet | opus; default sonnet, opus for high-risk-Node touches per D8
cost_cap_per_pr_usd: 5.00    # hard ceiling; agent aborts if exceeded mid-review and posts a partial-review comment
```

Per-path review-instruction overrides (the `path_instructions`-style surface CodeRabbit offers) are **explicitly deferred to a polish phase** (D11). v1 relies on the agent's built-in context loading and the prompt definition in `.claude/agents/review.md`. If per-path overrides earn their keep based on observed v1 gaps, they land in v2 with a documented schema; until then the configuration surface stays small.

Repos without a `.honeydrunk-review.yaml` are treated as `enabled: false` during v1 phased rollout. This is the opt-in gate.

### D5 — Cost guardrails are part of the build

The workflow ships with the following cost guardrails as default behavior (not configurable):

- **Hard per-PR ceiling** (`cost_cap_per_pr_usd` from D4, default $5). The agent's runtime tracks accumulated token cost; on cap exceedance, the agent posts a partial-review comment naming what was reviewed and what was skipped, and the workflow exits cleanly. Never silently fails.
- **Skip on draft PRs.** Already noted in D1.
- **Skip on PRs labeled `skip-review`.** Manual escape hatch for the rare case (label-as-config, no schema change).
- **Skip on PR-size limits when extreme.** If the diff exceeds 2000 lines (after `skip_paths` exclusions), the agent reviews only the highest-risk files (Node `.Abstractions/**`, `*.csproj` changes, anything touching `boundaries.md` or `invariants.md`) and posts a comment indicating coverage was capped.
- **Sonnet by default.** Opus only when D8's high-risk-Node trigger fires. Model selection is the largest cost lever; defaulting to the cheaper model is non-negotiable.
- **Cache context loads per workflow run.** Catalogs and invariants don't change within a single PR run; loaded once and reused across files in the diff.

Expected monthly cost: $40–100 at current AI-PR cadence. Tracked in `business/context/` under review-tooling cost. Breaching $200/month for two consecutive months triggers an ADR amendment (revisit model selection, sampling rate, or cap).

### D6 — Authorship classification

Every PR declares its authorship class in the PR body, in a single line: `Authorship: <class>`. Classes:

- **`human`** — written by the solo developer by hand. Default for any PR that doesn't declare otherwise.
- **`agent-codex`** — written by Codex against a packet spec.
- **`agent-copilot`** — written via GitHub Copilot in-IDE, accepted by the human.
- **`agent-claude-code`** — written by Claude Code (this surface).
- **`mixed`** — substantial contribution from both human and agent.

A CI check (added to `pr-core.yml`) verifies the line is present and parseable; absence fails the check as required. Codex/Copilot/Claude-Code execution surfaces are amended in follow-up packets to emit the line automatically (a small change to each surface's commit/PR-creation template).

Authorship class drives D7, D8, and D9.

### D7 — PR-size discipline for AI-authored changes

Non-`human` PRs carry a soft size cap, enforced via a new `pr-size-check` job in `pr-core.yml`:

- **≤ 400 changed lines** (excluding `skip_paths` from D4 and excluding test code) — normal review path.
- **> 400, ≤ 800 changed lines** — PR body must include a `Size justification:` block. A `large-pr` label is auto-applied. The cloud reviewer's verdict must explicitly address whether the size is justified given the packet.
- **> 800 changed lines** — CI auto-comments requesting a split or a `refine` pass. The PR can still merge if the human overrides; the override is logged.

This catches PR sprawl — the most common AI-authorship failure mode — before review effort is spent on it.

### D8 — Multi-perspective review for high-risk-Node PRs

A non-`human` PR that touches a high-risk Node requires **two independent LLM-review perspectives** before merge. High-risk Nodes:

- **HoneyDrunk.Kernel** — any change to `*.Abstractions` (per ADR-0035 ABI cascade rules).
- **HoneyDrunk.Vault** — any change to secret handling, bootstrap, or rotation.
- **HoneyDrunk.Auth** — any change to token validation, principal resolution, or the Audit emit boundary (ADR-0031).
- **HoneyDrunk.Audit** — any change to the append-only-by-interface guarantee (ADR-0030 Phase 1).
- **HoneyDrunk.Billing** (when standup lands per ADR-0037) — any change.
- **Any `.Cloud` revenue Node** (per ADR-0027 D2) — any change.

The catalog of high-risk Nodes lives in `catalogs/grid-health.json` under a new field, `review_risk_class`, so the list evolves with the Grid without amending this ADR. The cloud workflow auto-detects high-risk touches and:

- Switches the model to Opus for the first pass.
- Triggers a second pass automatically using a deliberately contrarian prompt ("identify ways the first reviewer was wrong"). The two passes are independent sessions, posted as separate comments.

Alternative escalation paths the human may invoke instead:
- `/ultrareview` — multi-agent cloud review (billed separately).
- `refine` agent against the PR's packet + diff (skeptical-senior-dev archetype).

The PR body records which path was used. Two same-agent passes is the default because it's cheapest and automatic; the alternatives exist for cases the human judges warrant deeper scrutiny.

### D9 — Post-merge sampling audit

Every Nth agent-authored merged PR (starting N=10, tunable via the weekly briefing per ADR-0043) is selected for a deeper post-merge audit:

- Selection is automatic (CI labels the chosen PR `audit-sample` at merge time).
- Audit runs `/ultrareview` against the merged PR's diff.
- Output is committed to `generated/post-merge-audits/{YYYY-MM-DD}-{repo}-{pr-number}.md`.
- Findings at `Block` or `Request Changes` severity become Reactive packets per ADR-0043's Reactive source taxonomy.

The audit measures **the review process's own quality**, not individual bugs (the code already shipped). Findings feed back into `.claude/agents/review.md` and this ADR. Without this loop, review-process drift would surface only as production incidents.

### D10 — Relationship to ADR-0011

This ADR **amends ADR-0011** at three points:

- **ADR-0011 D5 (review agent is advisory)** — preserved. The cloud-wired reviewer is also advisory; it posts a comment and a non-required check, never a blocking gate. ADR-0011's advisory rationale (agent outages don't halt merges, cost discipline on trivial PRs, symmetry with `refine`) all still apply.
- **ADR-0011 D10 (local-only, human-invoked)** — **reversed.** The Grid-aware `review` agent now runs automatically in the cloud on every non-draft, non-`skip-review`-labeled, `enabled: true`-config'd PR. The local invocation path via Claude Code remains available (and is the right tool for offline review, ad-hoc deep dives, and pre-PR feedback), but is no longer the only invocation path.
- **ADR-0011 D11 (rejected CodeRabbit)** — **rendered moot.** The original rationale (Copilot fills the automatic slot; the local agent fills the deeper slot) is superseded by the recognition that "automatic Grid-aware reviewer" is a distinct slot that neither Copilot nor CodeRabbit can fill. This ADR fills that slot by building, not by buying.

GitHub Copilot review remains enabled at the org level; its role is reduced to "generic LLM second opinion" with no specific responsibility in the pipeline. It costs nothing additional (existing subscription) and its occasional useful comment is upside, not a contract.

ADR-0011's invariants 31–33 are preserved. This ADR adds two more (Consequences section).

### D11 — Phased rollout

Phased to minimize blast radius and let v1 earn its keep before polish:

- **Phase 1 (Week 1–2) — MVP on one pilot repo.** Build `job-review-agent.yml`. Enable on `HoneyDrunk.Architecture` only (lowest blast radius — architecture PRs are predominantly docs/catalogs). Verify cost model and output quality. No discipline changes yet.
- **Phase 2 (Week 3–6) — Rollout to all 12 live Nodes.** Each repo opts in via `.honeydrunk-review.yaml` with `enabled: true`. Authorship classification (D6) becomes mandatory. PR-size discipline (D7) activates with warnings only.
- **Phase 3 (Month 2) — Discipline tightening.** High-risk-Node multi-perspective (D8) activates once `review_risk_class` lands in `catalogs/grid-health.json`. PR-size discipline moves from warnings to auto-comments at the > 800 threshold.
- **Phase 4 (Month 3+) — Sampling audit.** D9 activates. Polish features (per-path config overrides, learnings from prior reviews, output formatter improvements) land based on observed v1–v3 gaps. Each polish feature is its own follow-up packet, not part of this ADR.

Each phase is a discrete go/no-go. Phase 1's exit criterion is "the cloud-wired agent's verdicts are at least as useful as the local agent's, at acceptable cost." If that bar is missed, Phase 2 doesn't start.

## Consequences

### Affected Nodes

- **HoneyDrunk.Actions** — primary affected Node; new reusable workflow `job-review-agent.yml`; new jobs `pr-size-check` and `authorship-check` added to `pr-core.yml`; post-merge `audit-sample` labeling job added.
- **HoneyDrunk.Architecture** (this repo) — pilot for Phase 1; new directory `generated/post-merge-audits/`; new field `review_risk_class` in `catalogs/grid-health.json`; `.honeydrunk-review.yaml` authored as the v1 reference.
- **HoneyDrunk.Vault** — stores the Anthropic API key used by `job-review-agent.yml` (per ADR-0005); GitHub App credentials for the architecture-repo checkout token (also per ADR-0005).
- **Every Grid repo (eventually)** — adds `.honeydrunk-review.yaml`, `large-pr` and `audit-sample` labels via the existing label-setup pattern, and the `Authorship:` line convention to PR templates.
- **Codex execution surface** — amended in a follow-up packet to emit `Authorship: agent-codex` and the corresponding commit trailer (`Authorship:` and `Co-authored-by:`).
- **Claude Code commit-template behavior** — amended to emit `Authorship: agent-claude-code`.
- **`.claude/agents/review.md`** — gains the per-dimension checklists implementing D3's five dimensions (correctness/reliability, code quality, design hygiene, security/performance, Grid fit). Updates land in this file per ADR-0007's source-of-truth rule.

### Invariants

Adds two:

- **Invariant: every non-draft PR on an `enabled` repo runs the cloud-wired `review` agent.** Skip is via the `skip-review` label or `enabled: false` config — both explicit, both visible.
- **Invariant: agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge.** The catalog of high-risk Nodes lives in `catalogs/grid-health.json`.

ADR-0011's invariants 31–33 are preserved. Numbering for these two new invariants is reserved at 34–35 (with the caveat that the next-numbered ADR's invariants must avoid collision — `hive-sync` reconciles).

### Operational Consequences

- **Per-PR cloud LLM cost is now non-zero by design.** Tracked monthly; ceiling is $200/month for two consecutive months before reconsideration. The build saves money relative to running `/ultrareview` per PR or paying CodeRabbit private-tier, but it is not free.
- **Anthropic API key becomes load-bearing CI infrastructure.** Outage halts the cloud reviewer (workflow fails gracefully and posts a comment; PR can still merge — advisory posture). Rotation per ADR-0006.
- **GitHub App for cross-repo checkout** — a new GitHub App scoped to read `HoneyDrunk.Architecture` is created; its installation token is fetched per workflow run. Credentials in Vault.
- **PR diffs are sent to the Anthropic API.** Code is not customer data in any sense relevant to ADR-0036 (no tenant data is in repo diffs); the egress is acceptable and is documented here so it isn't relitigated. Private revenue Nodes (per ADR-0027 D2) are explicitly **excluded from the default v1 rollout** and require an explicit opt-in via `.honeydrunk-review.yaml`.
- **The local Claude Code review invocation remains available** and is the right tool for offline review or pre-PR feedback. The cloud workflow does not replace it; it makes the routine case automatic.
- **Copilot's role diminishes.** It remains enabled (zero marginal cost from the existing subscription) but no longer carries a specific responsibility in the pipeline.
- **The `Authorship:` declaration adds friction.** For agent surfaces, one-time template change. For humans, one line per PR.
- **Phase 1's pilot repo (Architecture)** will generate the first real cost data and the first review-quality signal. Phases 2+ are gated on that signal.

### Follow-up Work

- Author `job-review-agent.yml` in HoneyDrunk.Actions (Phase 1 MVP).
- Author `authorship-check` and `pr-size-check` jobs in `pr-core.yml`.
- Author the `audit-sample` post-merge labeling job.
- Create the GitHub App for cross-repo checkout; store credentials in Vault.
- Provision the Anthropic API key in Vault; configure rotation per ADR-0006.
- Author `.honeydrunk-review.yaml` v1 schema doc in this repo (`copilot/review-config-schema.md` or similar).
- Enable on the Architecture repo (Phase 1).
- Add `review_risk_class` field to `catalogs/grid-health.json` schema; populate for current Nodes (deferred until Phase 3 activates).
- Create `generated/post-merge-audits/` directory with a README.
- Amend Codex execution surface to emit `Authorship:` + commit trailer.
- Update `.claude/agents/review.md` with: (a) per-dimension checklists implementing D3's five dimensions; (b) any clarifications needed for cloud-context execution (e.g., explicit handling of "context loaded from the architecture repo checkout").
- Verify `copilot/pr-review-rules.md` covers the severity taxonomy across all five D3 dimensions; expand where gaps exist.
- Author the ADR-0011 amendment record (or supersession note) reflecting D9 reversals.

## Alternatives Considered

### Adopt CodeRabbit

Considered seriously. CodeRabbit's `.coderabbit.yaml` rule system is genuinely strong for prose-shaped rules and `path_instructions` (per-glob review guidance). Free for public repos; paid for private. Zero engineering to adopt.

Rejected because the requirement is **Grid awareness in the active sense** — reading `catalogs/contracts.json` at review time, walking `relationships.json` to assess downstream impact, resolving the packet via PR-body link, checking the diff against the packet's stated scope. CodeRabbit cannot do any of these; its rules are text-bound. Inlining the Grid context into `.coderabbit.yaml` is possible up to a point but degrades as the Grid grows and produces a maintenance surface (drift between the YAML inline copy and the canonical catalog files).

The build path costs 1–2 days of engineering and $40–100/month in API spend, in exchange for a reviewer that is structurally capable of doing the job. The buy path costs $0 in engineering and $0–30/month, in exchange for a reviewer that is structurally incapable of the most important slot. The build wins on capability.

### Continue ADR-0011 D10's local-only posture

Rejected. The accepted risk in D10 ("a distracted solo developer may forget to invoke the review agent") has materialized as AI-authored PR volume scaled. The Wave 1 ADR-0005/0006 rollout was 15 packets; the AI-sector standup wave is comparable; ADR-0043's Strategic source generates more. "Human invokes the agent on every PR" is not a discipline that survives volume.

### Build the polished version up front (config layer, learnings, output formatter)

Rejected. Polish before observation is over-engineering. v1's job is to prove the slot's capability; polish features earn their keep against observed v1 gaps, not against imagined ones. Per-path config overrides, learnings from prior reviews, and richer output formatting are all reasonable v2+ work; making them prerequisites blocks Phase 1 unnecessarily.

### Build a separate Grid-fit reviewer alongside CodeRabbit for generic

Considered. The argument: CodeRabbit's free public tier covers security/conventions/bugs/performance; our build covers Grid fit; total cost roughly the same; two perspectives.

Rejected on the cumulative-vendor-surface argument and on the recognition that **our review agent's prompt already covers security/conventions/bugs/performance** — Grid fit is the addition, not the substitute. Building two reviewers when one with the right prompt does both is duplication. If gaps appear in v1 against the non-Grid surfaces, adding CodeRabbit later as a complementary signal is a small follow-up amendment; presuming the gap up front is decision-under-uncertainty.

### Cloud-wire only for high-risk repos; keep local-only elsewhere

Rejected. The discipline failure mode ("human forgets to invoke") applies equally to non-high-risk repos. The cost difference between "cloud-wire all 12 Nodes" and "cloud-wire 4 Nodes" is small ($40 vs $100/month order of magnitude); the simplicity benefit of one consistent policy is large. Phased rollout (D11) gets the same blast-radius safety without the permanent split-policy.

### Make the cloud reviewer a required blocking check

Rejected. Preserves ADR-0011 D5's advisory posture. Required check on a third-party-runtime service (Anthropic API) bakes a single vendor into branch protection and strands merges on every API outage. Advisory plus weekly-briefing visibility (per ADR-0043 D5 of the briefing surfacing skipped reviews — though with auto-invocation, "skipped" is now near-zero) achieves observability without the lockout risk.

### Use only Opus to maximize review quality

Rejected on cost. Opus is ~5× the cost of Sonnet per token at current pricing. The marginal quality gain on routine PRs does not justify the cost; Opus belongs on high-risk-Node PRs (D8) where the failure cost is high enough to warrant the spend. Default-Sonnet, escalate-to-Opus is the standard cost-quality factoring for tiered LLM use.

### Defer until first AI-authored production regression

Rejected. The regression is the wrong learning signal; by the time it lands, the review-process drift it would surface has been ongoing for weeks. v1 cost is low enough that pre-incident adoption is cheaper than post-incident scrambling. Same argument as ADR-0043: industrialize the cheap process change before it has to be justified under fire.
