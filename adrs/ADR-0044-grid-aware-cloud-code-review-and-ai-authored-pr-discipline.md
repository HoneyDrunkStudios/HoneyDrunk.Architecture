# ADR-0044: Grid-Aware Cloud Code Review and AI-Authored PR Discipline

**Status:** Accepted
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

> **Superseded in part by ADR-0086 (2026-05-26).** D1's GitHub Actions trigger rail + signed webhook -> OpenClaw transport is rewritten as a pull-based local worker (cheap Action emits label + queue comment; local worker on the home server polls and runs the agent under Codex CLI + Claude Code CLI subscription auth). D5's default subscription-backed runtime moves from OpenClaw/Codex to local Codex CLI + Claude Code CLI. D2 (context-loading contract), D3 (twenty-category rubric), D4 (`.honeydrunk-review.yaml` - with the `runner` enum updated per ADR-0086 D5), D6 (authorship classification), D7 (PR-size discipline), D8 (multi-perspective for high-risk Nodes - substrate moves to local worker), D9 (post-merge sampling audit - substrate moves to local worker), D10 (relationship to ADR-0011 - preserved), D11 (phase clock reset per ADR-0086 D11) are otherwise preserved. See ADR-0086 D12 for the full relationship table.

## Context

ADR-0011 (Proposed) established the Grid's code review pipeline with the Grid-aware `review` agent as **local-only and human-invoked** (D10). The accepted risk was "a distracted solo developer may forget to invoke the review agent." The same ADR (D11) rejected CodeRabbit on the grounds that the automatic-LLM-reviewer slot was already filled by Copilot.

Both decisions were correct in April 2026. Both are stale today:

- **AI-authored PR volume has scaled.** Wave-style rollouts routinely produce 5-15 agent PRs in a window. The AI-sector standup wave (ADR-0016 through ADR-0025) adds nine Nodes' worth of scaffold packets. ADR-0043's Strategic and Tactical sources will mechanically generate agent PRs on cadence once running. "Human remembers to invoke the review agent" is no longer a viable discipline.
- **Copilot's automatic review has not earned its slot.** Its PR-time signal is generic (style nits, occasional null-check suggestions) and not Grid-aware. It does not load `constitution/invariants.md`, cannot read a packet via PR-body link, and has no knowledge of which ADRs govern a change. It fills a slot in name only.
- **CodeRabbit was reconsidered** in the conversation that produced this ADR. Its rule system via `.coderabbit.yaml` is genuinely strong for prose-shaped rules, but its hard limit is that it cannot actively load Grid catalogs (`relationships.json`, `contracts.json`, `grid-health.json`) at review time, walk invariants, or reason against a linked packet's stated scope. The "make sense with the Grid and our ADRs" requirement is the one thing no third-party tool can do, because no third-party tool knows the Grid.

The conclusion: **the slot that needs filling is not "automatic LLM reviewer" generically - it's "automatic Grid-aware LLM reviewer."** That slot is empty. Filling it means automatic invocation of the existing local `review` agent, not adopting an external service that fills the slot only by name.

The build is small, but the runtime placement matters. The prompt logic exists in `.claude/agents/review.md`. The context-loading contract is defined in ADR-0011 D4. The workflow host exists in HoneyDrunk.Actions, but GitHub Actions should be the cheap trigger/visibility rail, not the reasoning brain. The default v1 runtime is an OpenClaw-hosted Grid Review Runner using Codex through the Studio's existing subscription/session. GitHub Actions emits/validates review requests and exposes advisory status; OpenClaw performs the Grid-aware review and posts the verdict back to the PR.

The cost calculus has also shifted. The April 2026 ADR-0011 D10 rejection was per-PR cloud LLM cost against a low PR volume; at today's volume (~20-50 agent PRs/month), an Anthropic/API-backed GitHub Action makes AI review a recurring variable bill and sends private repo diffs to an external model API by default. The Studio already runs OpenClaw/Codex locally. The cheapest and most controllable v1 is therefore: use a signed GitHub-to-OpenClaw webhook as the primary request path, keep a poll/replay fallback for outages, run the review in OpenClaw/Codex, track the reviewed head SHA, and comment back only when the PR changed.

This ADR amends ADR-0011 to **reverse the human-invoked-only stance**, **reverse the CodeRabbit rejection as moot** (we're not adopting an alternative), and add **AI-authored PR discipline** that the automatic Grid Review Runner makes practical to enforce.

## Decision

The decision has two intertwined halves: the **build** (D1-D5) makes the **discipline** (D6-D9) practical. Neither half stands alone.

### D1 - Build the automatic Grid Review Runner with GitHub Actions as the trigger rail

The Grid builds, owns, and operates its own automatic Grid-aware code reviewer. Implementation:

- A new reusable workflow, `HoneyDrunk.Actions/.github/workflows/job-review-request.yml`, follows the existing `pr-core.yml` factoring (per ADR-0012) and validates whether a PR should request review.
- Triggered on `pull_request` events: `opened`, `synchronize`, `ready_for_review`. Not on `draft` PRs (cost discipline; draft is by definition WIP).
- Emits a review request payload containing the repo, PR number, head SHA, author class, changed-file summary, packet link, and `.honeydrunk-review.yaml` settings.
- Delivers the request to OpenClaw through a signed webhook path as the Phase-1 primary transport. The webhook receiver verifies HMAC signature, timestamp/replay window, request size, and idempotency before enqueueing work.
- Uses a durable poll/replay fallback when webhook delivery is unavailable: the workflow leaves a machine-readable artifact/comment that OpenClaw can discover later, using the same request payload and idempotency key. The fallback is not a second review path; it is the backup transport for the same runner contract.
- OpenClaw runs the Grid Review Runner using Codex and `.claude/agents/review.md` as the canonical prompt source (per ADR-0007's source-of-truth rule).
- The runner posts the verdict as a PR comment using the format already defined in `.claude/agents/review.md` and records the reviewed head SHA to avoid re-reviewing unchanged diffs. The idempotency key is `owner/repo#pr@headSha`; webhook retries, duplicate GitHub events, and manual replays must converge on the same queued/reviewed request instead of producing duplicate comments.
- The workflow/check surface remains **non-required** and advisory, per ADR-0011 D5's posture - preserved by this ADR.

The agent definition itself does not change. The same prompt that runs locally runs through the automatic runner. Drift between execution surfaces is forbidden - all surfaces consume `.claude/agents/review.md` directly.

### D2 - Context loading is identical to the local invocation

The Grid Review Runner loads exactly the context ADR-0011 D4 already mandates:

1. `constitution/invariants.md`
2. Governing ADRs referenced in the packet frontmatter
3. `catalogs/relationships.json`
4. `catalogs/contracts.json`
5. For each target repo: `repos/{node}/overview.md`, `boundaries.md`, `invariants.md`
6. `copilot/pr-review-rules.md`
7. The packet file (via PR-body link)
8. The PR diff

The runner checks out/updates both the target repo and `HoneyDrunkStudios/HoneyDrunk.Architecture` using local `gh` authentication or a narrowly scoped GitHub App token, so the context above is locally readable by the agent. This mirrors the local OpenClaw workspace layout exactly.

ADR-0011 D4's coupling rule (review-agent context-loading must mirror scope-agent context-loading) is preserved. Updates land in `.claude/agents/review.md`; the next runner invocation picks them up without workflow changes.

### D3 - Review goals and rubric

The reviewer evaluates every PR against **twenty named categories**. The rubric is not the reviewer's private checklist - it is the **Grid's shared standard for any code change**, applied symmetrically by authors at authoring time and by the reviewer at evaluation time (see "Upstream awareness" below).

This ADR binds the **categories and the questions within them**. The detailed per-category execution detail - exactly what to look for, what counts as a finding at each severity - lives in `.claude/agents/review.md` per ADR-0007's source-of-truth rule. Updates to the categories or their questions are amendments to this D3; updates to the answers/checklists are edits to the agent file.

#### 1. Correctness and functional integrity

- **Core correctness.** Does the code work? Does it satisfy the requirement (packet adherence)? Are edge cases handled? Are null/empty/error states covered? Are calculations accurate (precision, rounding)? Are timezone, culture, and locale issues considered? Are async flows correct? Are retries safe?
- **State correctness.** Does state mutate safely? Are transitions valid? Is eventual consistency handled where it applies? Are transactions atomic where required? Is partial failure handled?
- **Behavioral consistency.** Does behavior match existing platform expectations? Does the change break existing workflows? Are API contracts preserved? Are side effects predictable?

#### 2. Architectural integrity

- **Boundary enforcement.** Is logic in the correct layer? Is domain logic leaking into transport, UI, or data layers? Is infrastructure leaking into business logic? Are abstractions respected? Are abstractions leaking across boundaries?
- **Node governance.** Does this belong in this Node/package/service (per `repos/{node}/overview.md`)? Is domain ownership respected? Is another Node already responsible? Is this creating hidden coupling or accidental coupling? Is package ownership respected? Is functionality duplicated elsewhere in the Grid? Should this have been an extension point/plugin instead?
- **Dependency hygiene.** Are dependencies necessary and justified? Is the dependency too heavy for the use case? Is dependency direction correct (per `catalogs/relationships.json`)? Are there circular references? Is the package graph still clean? Are we introducing transitive bloat? Is the abstraction level appropriate (consuming `*.Abstractions` per ADR-0035, never reaching into backings)? Is an internal SDK/package being bypassed? Is the dependency trustworthy, maintained, and license-compatible? Is there hidden vendor lock-in?
- **Architectural drift.** Does this move the system away from established patterns? Is this introducing a "special case architecture"? Is temporary code pretending to be permanent?

#### 3. Maintainability

- **Complexity management.** Is the solution simpler than the problem? Can complexity be reduced? Are there too many abstractions? Is there unnecessary indirection? Is control flow understandable?
- **Readability.** Is intent obvious? Are names meaningful? Is the code self-documenting? Is cognitive load reasonable?
- **Evolvability.** Can this be extended safely? Will future modifications cause regressions? Will this become painful in six months? Is the design composable and future-proof enough for the known roadmap? Is this rigid or flexible at the right places? Are hidden assumptions or temporal/order dependencies being introduced? Does this increase cognitive load unnecessarily?
- **Technical debt.** Is debt being introduced intentionally or accidentally? Is debt documented (TODO/FIXME, follow-up packet, ADR amendment)? Is the debt acceptable for the business value?

#### 4. Reuse and ecosystem cohesion

- **Reuse.** Is existing functionality reused before creating new logic? Could this extend an existing service, module, extension point, or plugin? Is this solving an already-solved problem? Is this generic enough to become shared infrastructure? Is duplication emerging across Nodes? Should this move into Kernel, Data, Transport, or another platform Node?
- **Shared contracts.** Are shared SDKs and contracts respected (per `catalogs/contracts.json`)? Is naming aligned across the ecosystem? Are standards consistent?
- **Platform consistency.** Does this feel like HoneyDrunk code? Does it follow established patterns? Would another engineer immediately recognize the conventions?

#### 5. SOLID and design principles

- **SRP.** Does the class or module have one responsibility?
- **OCP.** Can behavior be extended without modification (where the cost is justified - not for hypothetical futures)?
- **LSP.** Are abstractions substitutable in practice?
- **ISP.** Are interfaces appropriately scoped, not too broad?
- **DIP.** Are high-level policies isolated from implementation details?
- **Additional.** DRY (no copy-paste), KISS (simplest solution that works), YAGNI (no speculative features), composition over inheritance where the trade-off favors it, explicit over implicit, convention over configuration.

#### 6. Performance and scalability

- **Runtime performance.** Expensive allocations in hot paths? Blocking calls in async code? Inefficient loops? Over-fetching data? Excessive serialization? Chatty APIs? Cache invalidation risks? Hot-path concerns? Horizontal scalability blockers?
- **Database performance.** N+1 queries? Missing indexes? Table scans? Large payloads where pagination would help? Query explosion under realistic load?
- **Scalability.** Will this work under 10× load? Is concurrency safe? Is backpressure handled? Is batching possible where it matters? Are retry storms, lock contention, or horizontal scaling blockers possible?
- **Resource efficiency.** Memory pressure, connection exhaustion, cache abuse, thread starvation, queue flooding.

#### 7. Reliability and resilience

- **Fault tolerance.** What happens when dependencies fail? Is retry logic safe? Are retries idempotent (per ADR-0042)? Are timeouts defined? Are circuit breakers used where they belong? Is cancellation handled? Are dead-letter paths defined where relevant?
- **Recovery.** Can the system recover automatically? Is state recoverable per ADR-0036's DR posture? Is replay safe? Is partial failure handled? Are rollback consistency and transaction boundaries correct?
- **Defensive programming.** Are assumptions validated at trust boundaries? Are invariants protected? Are dangerous operations guarded?
- **Chaos resistance.** Does this fail gracefully? Are cascading failures possible? Are blast radii bounded?

#### 8. Observability and diagnostics

- **Logging.** Are logs actionable, not noise? Is context included? Are logs structured? Are log levels correct (no `Information`-level chatter in hot paths)? Will support/devs actually be able to diagnose production issues from them?
- **Metrics.** Are business metrics captured? Are operational metrics captured? Are metrics meaningful rather than vanity counters? Can SLOs be measured?
- **Tracing.** Is distributed tracing propagated and correlated (per ADR-0010 and ADR-0040)? Are spans meaningful? Are cross-Node flows observable?
- **Diagnostics.** Can support and debugging teams diagnose issues quickly? Is failure provenance clear? Are error messages useful to humans? Are failures observable without reproducing locally? Is sensitive data kept out of telemetry?

#### 9. Security

- **Input handling.** Validation at trust boundaries? Sanitization where the data is rendered? Injection risks (SQL, command, expression) closed?
- **Authentication and authorization.** Proper auth boundaries (per ADR-0031)? Principle of least privilege? Tenant isolation (per ADR-0026)?
- **Secret handling.** No hardcoded secrets (Invariant 8)? Secure config usage (per ADR-0005)? Rotation support (per ADR-0006)?
- **Data protection.** PII handled appropriately (per ADR-0040 D9)? Encryption at rest and in transit where required? Audit trails complete (per ADR-0030)?
- **Dependency security.** Vulnerable packages flagged (per ADR-0009)? Unsafe transitive dependencies caught? Supply chain risk bounded?

#### 10. Enterprise readiness

- **Operational maturity.** Deployable safely (per ADR-0033)? Rollback ready? Configurable per environment? Feature-flaggable where it matters? Requires migration sequencing or backfill? Zero-downtime compatible? Infra dependencies documented?
- **Supportability.** Easy to troubleshoot? Clear ownership in `repos/{node}/overview.md`? Safe defaults?
- **Documentation.** Does this need an ADR or amendment? Runbooks needed (per ADR-0036)? Config docs updated? Are examples/sample configs, manifests/schema updates, dashboards, or operational notes needed?
- **Compliance.** PCI, GDPR, SOC2 implications? Retention rules (per ADR-0036 D7)? Audit requirements (per ADR-0030)?

#### 11. Testing quality

- **Coverage quality.** Happy paths tested? Failure paths tested? Edge cases tested? Regression tests added where a bug is fixed? Concurrency/load/security cases tested where relevant?
- **Test architecture.** Are tests maintainable? Are tests brittle (testing internals)? Are tests meaningful (not tautological assertions like `Assert.True(true)`)?
- **Verification depth.** Unit tests in the right project? Integration tests for cross-Node seams (per ADR-0011 Gap 1)? Contract tests for `*.Abstractions` surfaces? End-to-end tests where they earn their keep (per ADR-0011 Gap 3)?
- **Anti-patterns.** No testing implementation details. No excessive mocking that mocks the system under test. No non-deterministic tests (no real time, real randomness, real network in unit tests).

#### 12. API and contract design

- **API ergonomics.** Is the API intuitive? Is naming consistent? Are responses predictable?
- **Versioning.** Breaking changes labeled and gated per ADR-0035? Contract drift avoided? Serialization changes documented? Deprecation path documented? Backward compatibility honored at the published version? Client impact analyzed?
- **Consumer safety.** Are defaults safe? Are contracts explicit (no silent assumptions)?

#### 13. Data and persistence integrity

- **Data correctness.** Referential integrity preserved? Precision and rounding handled correctly (financial, time)? Idempotency where writes can repeat (per ADR-0042)?
- **Migration safety.** Backfill strategy clear? Rollback strategy clear? DB compatibility maintained? Zero-downtime where the table is hot?
- **Multi-tenant integrity.** Isolation guarantees (per ADR-0026)? Cross-tenant leakage prevented in queries, caches, and any in-memory state?

#### 14. Distributed systems concerns

- **Messaging.** Duplicate delivery handled (per ADR-0042)? Ordering assumptions explicit? Poison/dead-letter behavior defined? Double-processing and reentrancy risks handled?
- **Event architecture.** Event versioning planned? Contract evolution path clear? Outbox pattern where it belongs?
- **Consistency models.** Strong vs eventual consistency awareness - is the chosen model right for the use case and communicated to consumers?

#### 15. CI/CD and delivery

- **Pipeline quality.** Build reproducibility? Deterministic outputs (per ADR-0034 D4)? Artifact traceability?
- **Release safety.** Safe rollout path (per ADR-0033)? Canary support where it earns its keep? Environment parity between dev/staging/prod? Feature flags/backfills/migration sequencing considered? Rollback safety explicit?
- **Automation.** Is manual work avoidable? Is operational toil reduced rather than added? Are environment/config/infra changes captured rather than tribal?

#### 16. Developer experience (DX)

- **Ease of use.** Is the abstraction pleasant to consume? Is onboarding easy for the next reader?
- **Discoverability.** Can developers find the right extension points? Are conventions self-evident?
- **Tooling integration.** IntelliSense, XML docs, examples? Analyzer support where mistakes are catchable?

#### 17. Product and business alignment

- **Business fit.** Is this solving the right problem? Is the implementation over-engineered for the actual requirement?
- **Cost awareness.** Infra cost impact (per ADR-0011 D6's cost discipline)? Operational burden added? Vendor lock-in introduced?
- **Strategic alignment.** Does this align with Grid direction (constitution and roadmap)? Does it strengthen platform leverage or fragment it?

#### 18. AI and agent-specific concerns

This category is load-bearing as the Grid leans further into agent-authored code and agent-executed workflows.

- **Agent safety.** Prompt injection resistance at trust boundaries? Tool permission scoping (per ADR-0017 capabilities)? Output validation before it leaves the agent's surface?
- **Memory integrity.** Is agent memory scoped correctly (per ADR-0022's scope hierarchy)? Is context leakage possible across agents or tenants?
- **Human override.** Can operators intervene (per ADR-0018 `IApprovalGate`)? Is the agent's behavior auditable (per ADR-0030)?
- **Agent observability.** Decision tracing - can we reconstruct why the agent did what it did? Tool usage tracing? Token and cost tracking (per ADR-0011 D6 and ADR-0041 cost profile)?

#### 19. Anti-entropy and long-term system health

This is the category most organizations never formalize, and the one that determines whether the system is still legible in three years. Load-bearing for the Grid's long-term cohesion.

- **Entropy detection.** Is this increasing fragmentation? Is naming diverging across Nodes? Is inconsistency creeping in where consistency used to hold?
- **Pattern erosion.** Are teams (including AI agents) bypassing standards? Is this "one-off syndrome" - a single justified exception that will be cited as precedent for ten unjustified ones?
- **Ecosystem sustainability.** Will this still make sense in 3 years? Does this increase architectural gravity (load-bearing dependencies) in a way that constrains future moves?

#### 20. Human factors

- **Team comprehension.** Would another engineer (or another agent on a different prompt) understand this quickly?
- **Bus factor.** Is knowledge being concentrated where only one person (or one agent run) holds it? Is the change reversible by someone who didn't make it?
- **Communication quality.** Is intent documented (PR body, packet adherence, ADR if scope warrants)? Are trade-offs explained, not just decisions stated?

#### Upstream awareness - the rubric is shared across authoring and review

**The categories above are not the reviewer's checklist alone.** They are the Grid's standard for what makes a change defensible, and they apply symmetrically to every agent that **authors** code or scoped work - not only to the reviewer that evaluates the result. An author who applies the rubric upstream prevents the problem; a reviewer who applies it downstream catches what slipped through. Both layers exist; the upstream layer is the load-bearing one for long-term system health, because catching a problem at review costs a review cycle, while catching it at authoring time costs nothing.

The rubric therefore binds the following authoring surfaces, each via a section in its agent definition file referencing this D3:

- **`scope`** - when decomposing a packet, evaluates which categories apply to the work and ensures the packet captures their implications. What's the failure mode (Reliability)? What observability is required (Observability)? What's the security blast radius (Security)? What's the testing strategy (Testing)? What anti-entropy risk does this carry (Anti-Entropy)? Packets that omit relevant categories produce changes that miss them at execution time.
- **`adr-composer`** - when proposing an ADR, reasons about the decision against the categories that apply. Does this introduce architectural drift (Architectural Integrity)? Cost implications (Performance / Cost / Product alignment)? Long-term entropy (Anti-Entropy)? Security or compliance implications (Security / Enterprise Readiness)? AI/agent implications where relevant (Category 18)?
- **`pdr-composer`** - same as `adr-composer`, with extra weight on Category 17 (Product / Business Alignment) and Category 19 (Anti-Entropy and Long-Term Health). PDRs that pass the rubric are likelier to age well.
- **`refine`** - when challenging scoped work, evaluates whether the packet has accounted for the categories the work touches. A packet that ignores Reliability or Observability or Anti-Entropy on a change where those clearly apply surfaces as a `refine` finding.
- **Execution agents** (Codex via packet, Copilot in-IDE, Claude Code in authoring mode) - write code mindful of the categories. Each execution surface's prompt or system instructions references this D3 as the **authoring discipline** the agent must consider before producing a diff. The categories most load-bearing at code-writing time (Correctness, Code Quality, SOLID, Reuse, Security, Performance, Testing, AI/Agent-Specific, Human Factors) are surfaced as a brief authoring checklist; the rest are by reference.
- **`review`** (this reviewer) - applies the full rubric as the evaluation gate.
- **`node-audit`** - when auditing a Node's health (per ADR-0043's Tactical source), walks the rubric to identify systemic gaps that span PRs rather than living in any single one. Findings flow to packets per ADR-0043.

The shared rubric is the **single most important structural decision** in this ADR. A reviewer that catches only what authors missed is useful but expensive. A whole ecosystem of agents reasoning against the same rubric - at scope, at decision, at authoring, at refinement, at review, at audit - is what keeps a 13-Node Grid coherent under solo-developer-plus-AI throughput.

The mechanical change: each agent definition file (`scope.md`, `adr-composer.md`, `pdr-composer.md`, `refine.md`, `review.md`, `node-audit.md`, and the execution-surface prompts) gains a section referencing this D3 and the relevant subset of categories with severity expectations. Updates to the rubric are amendments to this D3 and propagate via agent-file updates per ADR-0007's source-of-truth rule. Drift between this D3 and any agent file is an anti-pattern; `hive-sync` (per ADR-0014) reconciles.

#### Severity and the agent-file binding

The reviewer's verdict comments findings against these categories using the severity taxonomy in `copilot/pr-review-rules.md` (`Block` / `Request Changes` / `Suggest`). The taxonomy, the per-category execution detail, and the per-agent authoring discipline all live in their respective agent files. This D3 binds the **categories, their questions, and the shared-upstream principle**; everything downstream of those bindings evolves in agent files without ADR ceremony.

### D4 - Per-repo configuration via `.honeydrunk-review.yaml`

Each repo carries an optional `.honeydrunk-review.yaml` at the repo root. The v1 schema is deliberately minimal; the file's primary purpose is the **enabled/disabled gate** during phased rollout. Additional knobs land as later amendments.

v1 schema:

```yaml
enabled: true                # required; default-off until repo opts in (D11)
severity_floor: Suggest      # minimum severity for posted findings: Suggest | Request Changes | Block
skip_paths:                  # globs excluded from review
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
runner: local-worker         # local-worker | api-ci; default ADR-0086 local worker
```

`cost_cap_per_pr_usd` is omitted for `local-worker` because ADR-0086's subscription-backed path has no per-token API spend. Repos using the preserved `api-ci` fallback must set an explicit non-zero `cost_cap_per_pr_usd` alongside the provider/model configuration.

Per-path review-instruction overrides (the `path_instructions`-style surface CodeRabbit offers) are **explicitly deferred to a polish phase** (D11). v1 relies on the agent's built-in context loading and the prompt definition in `.claude/agents/review.md`. If per-path overrides earn their keep based on observed v1 gaps, they land in v2 with a documented schema; until then the configuration surface stays small.

Repos without a `.honeydrunk-review.yaml` are treated as `enabled: false` during v1 phased rollout. This is the opt-in gate.

### D5 - Cost guardrails are part of the build

The runner ships with the following cost guardrails as default behavior (not configurable):

- **Subscription-backed default.** v1 uses OpenClaw/Codex through the Studio's existing subscription/session, avoiding a new per-token Anthropic/OpenAI API bill for routine PR review.
- **API fallback is explicit.** Any future `api-ci` fallback must set a non-zero `cost_cap_per_pr_usd`, name the provider/model, and preserve the advisory posture. It is not the v1 default.
- **Skip on draft PRs.** Already noted in D1.
- **Skip on PRs labeled `skip-review`.** Manual escape hatch for the rare case (label-as-config, no schema change).
- **Skip on unchanged head SHAs.** If the runner already reviewed the current PR head SHA, it does not re-run.
- **Skip on PR-size limits when extreme.** If the diff exceeds 2000 lines (after `skip_paths` exclusions), the agent reviews only the highest-risk files (Node `.Abstractions/**`, `*.csproj` changes, anything touching `boundaries.md` or `invariants.md`) and posts a comment indicating coverage was capped.
- **Cache context loads per runner invocation.** Catalogs and invariants don't change within a single review run; loaded once and reused across files in the diff.

Expected incremental monthly model cost for v1 is approximately $0 beyond the existing Codex subscription/session. If API-backed fallback becomes necessary, review-tooling spend is tracked in `business/context/`; breaching $200/month for two consecutive months triggers an ADR amendment (revisit provider selection, sampling rate, or cap).

### D6 - Authorship classification

Every PR declares its authorship class in the PR body, in a single line: `Authorship: <class>`. Classes:

- **`human`** - written by the solo developer by hand. Default for any PR that doesn't declare otherwise.
- **`agent-codex`** - written by Codex against a packet spec.
- **`agent-copilot`** - written via GitHub Copilot in-IDE, accepted by the human.
- **`agent-claude-code`** - written by Claude Code (this surface).
- **`mixed`** - substantial contribution from both human and agent.

A CI check (added to `pr-core.yml`) verifies the line is present and parseable; absence fails the check as required. Codex/Copilot/Claude-Code execution surfaces are amended in follow-up packets to emit the line automatically (a small change to each surface's commit/PR-creation template).

Authorship class drives D7, D8, and D9.

### D7 - PR-size discipline for AI-authored changes

Non-`human` PRs carry a soft size cap, enforced via a new `pr-size-check` job in `pr-core.yml`:

- **≤ 400 changed lines** (excluding `skip_paths` from D4 and excluding test code) - normal review path.
- **> 400, ≤ 800 changed lines** — PR body must include a `Size justification:` block. A `large-pr` label is auto-applied. The Grid Review Runner's verdict must explicitly address whether the size is justified given the packet.
- **> 800 changed lines** - CI auto-comments requesting a split or a `refine` pass. The PR can still merge if the human overrides; the override is logged.

This catches PR sprawl - the most common AI-authorship failure mode - before review effort is spent on it.

### D8 - Multi-perspective review for high-risk-Node PRs

A non-`human` PR that touches a high-risk Node requires **two independent LLM-review perspectives** before merge. High-risk Nodes:

- **HoneyDrunk.Kernel** - any change to `*.Abstractions` (per ADR-0035 ABI cascade rules).
- **HoneyDrunk.Vault** - any change to secret handling, bootstrap, or rotation.
- **HoneyDrunk.Auth** - any change to token validation, principal resolution, or the Audit emit boundary (ADR-0031).
- **HoneyDrunk.Audit** - any change to the append-only-by-interface guarantee (ADR-0030 Phase 1).
- **HoneyDrunk.Payments** (per ADR-0037) - any change.
- **Any `.Cloud` revenue Node** (per ADR-0027 D2) - any change.

The catalog of high-risk Nodes lives in `catalogs/grid-health.json` under a new field, `review_risk_class`, so the list evolves with the Grid without amending this ADR. The Grid Review Runner auto-detects high-risk touches and:

- Switches to the highest-quality locally available Codex review profile for the first pass.
- Triggers a second pass automatically using a deliberately contrarian prompt ("identify ways the first reviewer was wrong"). The two passes are independent sessions, posted as separate comments.

The human may also invoke the `refine` agent against the PR's packet + diff (skeptical-senior-dev archetype) when a deeper manual escalation is warranted.

Two same-runner passes remain the default because they are cheapest and automatic under the OpenClaw/Codex setup. Separate multi-agent cloud review modes are intentionally out of scope for ADR-0044; the review system should stay subscription-backed, local/runtime-owned, and low-noise unless a future ADR deliberately reopens provider-backed review.

Filed ADR-0044 work items are immutable per invariant 24. Any legacy packet text that still references `/ultrareview` is superseded by this ADR text and must not be used to implement or revive a separate multi-agent cloud review mode.

### D9 - Post-merge sampling audit

Every Nth agent-authored merged PR (starting N=10, tunable via the weekly briefing per ADR-0043) is selected for a deeper post-merge audit:

- Selection is automatic (CI labels the chosen PR `audit-sample` at merge time).
- Audit reruns the canonical OpenClaw/Codex Grid Review Runner against the merged PR's diff using an audit-mode instruction block that asks what the pre-merge review missed.
- Output is committed to `generated/post-merge-audits/{YYYY-MM-DD}-{repo}-{pr-number}.md`.
- Findings at `Block` or `Request Changes` severity become Reactive packets per ADR-0043's Reactive source taxonomy.

The audit measures **the review process's own quality**, not individual bugs (the code already shipped). The audit-mode instruction block is owned by the canonical review-agent prompt/config used by the OpenClaw/Codex Grid Review Runner, not forked into workflow YAML or a runner-only prompt. The workflow selects audit mode and supplies the merged PR diff plus original review artifacts; the reviewer prompt remains the single source of review behavior. Findings feed back into `.claude/agents/review.md` and this ADR. Without this loop, review-process drift would surface only as production incidents.

### D10 - Relationship to ADR-0011

This ADR **amends ADR-0011** at three points:

- **ADR-0011 D5 (review agent is advisory)** - preserved. The automatic Grid Review Runner is also advisory; it posts a comment/status and never becomes a blocking gate. ADR-0011's advisory rationale (agent outages don't halt merges, cost discipline on trivial PRs, symmetry with `refine`) all still apply.
- **ADR-0011 D10 (local-only, human-invoked)** - **reversed.** The Grid-aware `review` agent now runs automatically via the OpenClaw/Codex Grid Review Runner on every non-draft, non-`skip-review`-labeled, `enabled: true`-config'd PR. The local/manual invocation path remains available (and is the right tool for offline review, ad-hoc deep dives, and pre-PR feedback), but is no longer the only invocation path.
- **ADR-0011 D11 (rejected CodeRabbit)** - **rendered moot.** The original rationale (Copilot fills the automatic slot; the local agent fills the deeper slot) is superseded by the recognition that "automatic Grid-aware reviewer" is a distinct slot that neither Copilot nor CodeRabbit can fill. This ADR fills that slot by building, not by buying.

GitHub Copilot review remains enabled at the org level; its role is reduced to "generic LLM second opinion" with no specific responsibility in the pipeline. It costs nothing additional (existing subscription) and its occasional useful comment is upside, not a contract.

ADR-0011's invariants 31-33 are preserved. This ADR adds two more (Consequences section).

### D11 - Phased rollout

Phased to minimize blast radius and let v1 earn its keep before polish:

- **Phase 1 (Week 1-2) - MVP on one pilot repo.** Build `job-review-request.yml` and the OpenClaw/Codex Grid Review Runner. Enable on `HoneyDrunk.Architecture` only (lowest blast radius - architecture PRs are predominantly docs/catalogs). Verify trigger reliability, reviewed-head-SHA tracking, output quality, and cost model. No discipline changes yet.
- **Phase 2 (Week 3-6) - Rollout to all 12 live Nodes.** Each repo opts in via `.honeydrunk-review.yaml` with `enabled: true`. Authorship classification (D6) becomes mandatory. PR-size discipline (D7) activates with warnings only.
- **Phase 3 (Month 2) - Discipline tightening.** High-risk-Node multi-perspective (D8) activates once `review_risk_class` lands in `catalogs/grid-health.json`. PR-size discipline moves from warnings to auto-comments at the > 800 threshold.
- **Phase 4 (Month 3+) - Sampling audit.** D9 activates. Polish features (per-path config overrides, learnings from prior reviews, output formatter improvements) land based on observed v1-v3 gaps. Each polish feature is its own follow-up packet, not part of this ADR.

Each phase is a discrete go/no-go. Phase 1's exit criterion is "the automatic runner's verdicts are at least as useful as the local/manual agent's, the trigger path is reliable, and incremental model cost stays near zero under the subscription-backed default." If that bar is missed, Phase 2 doesn't start.

## Consequences

### Affected Nodes

- **HoneyDrunk.Actions** - primary affected Node; new reusable workflow `job-review-request.yml`; new jobs `pr-size-check` and `authorship-check` added to `pr-core.yml`; post-merge `audit-sample` labeling job added.
- **HoneyDrunk.Architecture** (this repo) - pilot for Phase 1; OpenClaw runner configuration/runbook; new directory `generated/post-merge-audits/`; new field `review_risk_class` in `catalogs/grid-health.json`; `.honeydrunk-review.yaml` authored as the v1 reference.
- **OpenClaw workspace/runtime** - hosts the Grid Review Runner, tracks reviewed PR head SHAs, loads local target/Architecture repos, runs Codex, and posts review comments via `gh`.
- **HoneyDrunk.Vault** - no Anthropic API key is required for v1. Webhook signing credentials are required for the Phase-1 primary path and are stored per ADR-0005/ADR-0006 secret discipline; local `gh` auth remains acceptable for PR checkout/comment writeback in the OpenClaw-hosted runner.
- **Every Grid repo (eventually)** - adds `.honeydrunk-review.yaml`, `large-pr` and `audit-sample` labels via the existing label-setup pattern, and the `Authorship:` line convention to PR templates.
- **Codex execution surface** - amended in a follow-up packet to emit `Authorship: agent-codex` and the corresponding commit trailer (`Authorship:` and `Co-authored-by:`).
- **Claude Code commit-template behavior** - amended to emit `Authorship: agent-claude-code`.
- **`.claude/agents/review.md`** - gains the per-category execution detail implementing D3's twenty categories.
- **`.claude/agents/scope.md`, `adr-composer.md`, `pdr-composer.md`, `refine.md`, `node-audit.md`** - each gains a section referencing D3 and the subset of categories relevant to its authoring surface, per D3's upstream-awareness clause. Updates land per ADR-0007's source-of-truth rule.
- **Execution-surface prompts** (Codex packet-execution prompt, Copilot in-IDE custom instructions, Claude Code authoring-mode system instructions) - each surfaces the load-bearing authoring categories (Correctness, Code Quality, SOLID, Reuse, Security, Performance, Testing, AI-specific, Human Factors) per D3's upstream-awareness clause.

### Invariants

Adds two:

- **Invariant: every non-draft PR on an `enabled` repo requests an automatic Grid Review Runner pass.** Skip is via the `skip-review` label or `enabled: false` config - both explicit, both visible. Runner unavailability is surfaced as advisory/pending, not hidden.
- **Invariant: agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge.** The catalog of high-risk Nodes lives in `catalogs/grid-health.json`.

ADR-0011's invariants 31-33 are preserved. Final invariant numbers for the two new invariants are assigned when the implementing work updates `constitution/invariants.md`; this ADR deliberately does not reserve specific numbers because the existing 34+ range is already contested between ADR-0012's CI/CD invariants (34-38) and ADR-0015's hosting invariants (34-36). `hive-sync` reconciles the final assignments at landing time.

### Operational Consequences

- **Per-PR cloud LLM API cost is avoided in v1 by design.** The default runner uses the existing OpenClaw/Codex subscription/session. API-backed execution remains a future fallback only, with explicit caps and provider choice.
- **OpenClaw availability becomes part of the advisory review surface.** If the local runner is offline, the workflow/request path marks the review pending or unavailable and posts/records that state; PRs remain mergeable because the reviewer is advisory.
- **Webhook credentials are required v1 infrastructure for the primary path.** Phase 1 uses a signed GitHub-to-OpenClaw webhook with a shared secret or narrowly scoped GitHub App/webhook credential. The poll/artifact path remains as a fallback and manual replay surface, not the default. Do not provision Anthropic API credentials for v1.
- **PR diffs stay in the local OpenClaw/Codex path by default.** They are not sent to Anthropic API as part of v1. Any future external API fallback must be documented and explicitly enabled. Private revenue Nodes (per ADR-0027 D2) are explicitly **excluded from the default v1 rollout** and require an explicit opt-in via `.honeydrunk-review.yaml`.
- **The manual review invocation remains available** and is the right tool for offline review or pre-PR feedback. The automatic runner does not replace it; it makes the routine case automatic.
- **Copilot's role diminishes.** It remains enabled (zero marginal cost from the existing subscription) but no longer carries a specific responsibility in the pipeline.
- **The `Authorship:` declaration adds friction.** For agent surfaces, one-time template change. For humans, one line per PR.
- **Phase 1's pilot repo (Architecture)** will generate the first reliability signal, reviewed-SHA behavior, and review-quality signal. Phases 2+ are gated on that signal.

### Follow-up Work

- Author `job-review-request.yml` in HoneyDrunk.Actions (Phase 1 trigger rail).
- Author the OpenClaw/Codex Grid Review Runner runbook/config in Architecture.
- Author `authorship-check` and `pr-size-check` jobs in `pr-core.yml`.
- Author the `audit-sample` post-merge labeling job.
- Create the narrowly scoped GitHub-to-OpenClaw webhook credential and store it per ADR-0005/0006. Do not provision an Anthropic API key for v1.
- Author `.honeydrunk-review.yaml` v1 schema doc in this repo (`copilot/review-config-schema.md` or similar).
- Enable on the Architecture repo (Phase 1).
- Add `review_risk_class` field to `catalogs/grid-health.json` schema; populate for current Nodes (deferred until Phase 3 activates).
- Create `generated/post-merge-audits/` directory with a README.
- Amend Codex execution surface to emit `Authorship:` + commit trailer.
- Update `.claude/agents/review.md` with: (a) per-category execution detail implementing D3's twenty categories; (b) any clarifications needed for OpenClaw runner execution (e.g., explicit handling of "context loaded from the architecture repo checkout").
- Update `.claude/agents/scope.md` with a section referencing D3 and the categories relevant to scoping (Correctness scope adherence, Reliability, Observability requirements, Security blast radius, Testing strategy, Anti-Entropy risk, AI/agent implications).
- Update `.claude/agents/adr-composer.md` and `.claude/agents/pdr-composer.md` with sections referencing D3 and the categories relevant to architectural and product decisions (Architectural Integrity, Cost, Anti-Entropy, Security/Compliance, AI/agent implications; PDR adds extra weight on Product / Business Alignment).
- Update `.claude/agents/refine.md` with a section referencing D3 and the rubric-completeness check it must perform on packets and dispatch plans.
- Update `.claude/agents/node-audit.md` with a section referencing D3 as the systemic-health rubric.
- Update execution-surface prompts (Codex packet-execution prompt, Copilot in-IDE custom instructions, Claude Code authoring-mode system instructions) to surface the load-bearing authoring categories.
- Verify `copilot/pr-review-rules.md` covers the severity taxonomy across all twenty D3 categories; expand where gaps exist.
- Wire `hive-sync` to detect drift between D3 and any agent file's referenced category list, per ADR-0014's reconciliation mandate.
- Author the ADR-0011 amendment record (or supersession note) reflecting D9 reversals.

## Alternatives Considered

### Adopt CodeRabbit

Considered seriously. CodeRabbit's `.coderabbit.yaml` rule system is genuinely strong for prose-shaped rules and `path_instructions` (per-glob review guidance). Free for public repos; paid for private. Zero engineering to adopt.

Rejected because the requirement is **Grid awareness in the active sense** - reading `catalogs/contracts.json` at review time, walking `relationships.json` to assess downstream impact, resolving the packet via PR-body link, checking the diff against the packet's stated scope. CodeRabbit cannot do any of these; its rules are text-bound. Inlining the Grid context into `.coderabbit.yaml` is possible up to a point but degrades as the Grid grows and produces a maintenance surface (drift between the YAML inline copy and the canonical catalog files).

The build path costs 1-2 days of engineering and near-zero incremental model cost under the existing OpenClaw/Codex subscription/session, in exchange for a reviewer that is structurally capable of doing the job. The buy path costs $0 in engineering and $0-30/month, in exchange for a reviewer that is structurally incapable of the most important slot. The build wins on capability.

### Continue ADR-0011 D10's local-only posture

Rejected. The accepted risk in D10 ("a distracted solo developer may forget to invoke the review agent") has materialized as AI-authored PR volume scaled. The Wave 1 ADR-0005/0006 rollout was 15 packets; the AI-sector standup wave is comparable; ADR-0043's Strategic source generates more. "Human invokes the agent on every PR" is not a discipline that survives volume.

### Build the polished version up front (config layer, learnings, output formatter)

Rejected. Polish before observation is over-engineering. v1's job is to prove the slot's capability; polish features earn their keep against observed v1 gaps, not against imagined ones. Per-path config overrides, learnings from prior reviews, and richer output formatting are all reasonable v2+ work; making them prerequisites blocks Phase 1 unnecessarily.

### Build a separate Grid-fit reviewer alongside CodeRabbit for generic

Considered. The argument: CodeRabbit's free public tier covers security/conventions/bugs/performance; our build covers Grid fit; total cost roughly the same; two perspectives.

Rejected on the cumulative-vendor-surface argument and on the recognition that **our review agent's prompt already covers security/conventions/bugs/performance** - Grid fit is the addition, not the substitute. Building two reviewers when one with the right prompt does both is duplication. If gaps appear in v1 against the non-Grid surfaces, adding CodeRabbit later as a complementary signal is a small follow-up amendment; presuming the gap up front is decision-under-uncertainty.

### Automate only for high-risk repos; keep manual-only elsewhere

Rejected. The discipline failure mode ("human forgets to invoke") applies equally to non-high-risk repos. The incremental model cost difference between "request reviews for all enabled Nodes" and "request reviews for only high-risk Nodes" is near-zero under the subscription-backed OpenClaw/Codex runner, and the simplicity benefit of one consistent policy is large. Phased rollout (D11) gets the same blast-radius safety without the permanent split-policy.

### Make the automatic reviewer a required blocking check

Rejected. Preserves ADR-0011 D5's advisory posture. Required check on any AI runtime — local OpenClaw or third-party API — strands merges on runner outage, auth expiry, webhook failure, or provider outage. Advisory plus weekly-briefing visibility (per ADR-0043 D5 of the briefing surfacing skipped reviews - though with auto-invocation, "skipped" should be near-zero) achieves observability without the lockout risk.

### Use only API-hosted frontier review to maximize review quality

Rejected on cost and operational coupling. The marginal quality gain on routine PRs does not justify turning every PR into external API spend and provider dependency. High-risk-Node PRs get a second independent pass under D8; routine PRs use the OpenClaw/Codex subscription-backed runner by default.

### Defer until first AI-authored production regression

Rejected. The regression is the wrong learning signal; by the time it lands, the review-process drift it would surface has been ongoing for weeks. v1 cost is low enough that pre-incident adoption is cheaper than post-incident scrambling. Same argument as ADR-0043: industrialize the cheap process change before it has to be justified under fire.

## Superseded in part by ADR-0086

[ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) (Accepted) reshapes this ADR's transport and execution substrate while preserving the discipline halves. The substrate change is invisible to `.claude/agents/review.md`; both substrates consume the same canonical agent file per [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md).

**Superseded:**

- **D1 — Build the automatic Grid Review Runner with GitHub Actions as the trigger rail (signed webhook → OpenClaw).** The signed-webhook-to-OpenClaw transport is replaced by a pull-based local worker. The cheap GitHub Action now enqueues review requests via a GitHub-native queue (label `needs-agent-review` + structured queue comment); a local worker on the always-on home server polls GitHub on a 1–5-minute cadence, claims one PR at a time via label swap, runs the agent under subscription-backed Codex CLI / Claude Code CLI, and posts the verdict back to the PR. The Cloudflare Tunnel for review traffic and the OpenClaw process on the review path are decommissioned at cutover per ADR-0086 D10.
- **D5 — Subscription-backed default = OpenClaw/Codex.** Reframed: the subscription-backed default is now local CLIs (Codex CLI under ChatGPT Pro, Claude Code CLI under Claude Max), invoked by the local worker. The `api-ci` fallback is preserved with the same constraints; the `openclaw-codex` runner enum value is removed from `.honeydrunk-review.yaml` per ADR-0086 D5.

**Preserved verbatim:**

- D2 (context-loading contract — the same eight-item mandatory load).
- D3 (twenty-category rubric and upstream-awareness clause across `scope`, `adr-composer`, `pdr-composer`, `refine`, execution agents, `review`, `node-audit`).
- D4 (`.honeydrunk-review.yaml` per-repo config — `enabled`, `severity_floor`, `skip_paths`, `cost_cap_per_pr_usd`), with the `runner` enum updated per ADR-0086 D5.
- D6 (authorship classification — `Authorship:` line + `pr-core.yml` check).
- D7 (PR-size discipline for non-`human` PRs at the 400 / 800 line bands).
- D8 (multi-perspective for high-risk Nodes — two independent passes), with the implementation substrate change per ADR-0086 D8 (two local-worker invocations, one Codex CLI pass + one Claude Code CLI pass; contrarian-prompt fallback preserved).
- D9 (post-merge sampling audit every Nth PR; audit-mode instruction block in the canonical agent file).
- D10 (relationship to ADR-0011 — D5 advisory posture preserved, D10 local-only reversal preserved, D11 rejection of CodeRabbit remains moot).

**Phased rollout clock reset:**

- D11's Phase 1–4 progression is moot for the new substrate. ADR-0086 D11 resets the clock: Phase A pilots the worker on `HoneyDrunk.Architecture`; Phase B migrates the other `enabled` repos and triggers the OpenClaw-review-path decommission; Phase C ramps to all 12 live Nodes. The exit criteria from ADR-0044 D11 Phase 1 (verdict quality, reliable triggers, near-zero marginal cost) carry over to ADR-0086 Phase A.

The two invariants added by this ADR's Consequences section are **preserved** under the new transport, with the "requests an automatic review pass" mechanism redefined as "lands in the GitHub-native queue, processed by the local worker."
