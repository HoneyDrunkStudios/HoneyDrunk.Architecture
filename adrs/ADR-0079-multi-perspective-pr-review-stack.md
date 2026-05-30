# ADR-0079: Multi-Perspective PR Review Stack — Copilot + CodeRabbit + Grid-Aware Agent (Codex + Claude)

**Status:** Accepted
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

> **Superseded in part by ADR-0086 (2026-05-26).** D1 Reviewer 3 (Codex via OpenClaw) is superseded transport-wise: same Codex CLI execution against the operator's ChatGPT Pro allotment, triggered via the pull-based local worker rather than via OpenClaw. D2 Reviewer 4 (Anthropic's native Claude Code on the web GitHub integration, post June 15 2026) is superseded: Reviewer 4 runs through the local worker via Claude Code CLI under Claude Max **today**. The June 15 dependency and the Claude-Code-on-the-web GitHub integration are removed from the Grid Review Runner's design. D3 (substantive-PR classifier safe-list), D4-D5 (Greptile/Codex-OOTB watch list), D6 (cost ceiling), D7 (Invariant 53 satisfaction via dual-model execution - now Codex CLI + Claude Code CLI, both under subscription auth, both under the local worker), D8 (auth-precedence gotcha - enforced at the worker env boundary), D9 (out-of-scope items) are preserved. See ADR-0086 D12 for the full relationship table.

## Context

[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) (Accepted) built the **Grid-aware cloud code reviewer** — the OpenClaw-hosted runner that executes the `.claude/agents/review.md` agent definition through Codex on every PR. ADR-0044 also reversed [ADR-0011](./ADR-0011-code-review-and-merge-flow.md)'s rejection of CodeRabbit and Copilot review — both are permitted to operate alongside the Grid-aware reviewer.

[ADR-0046](./ADR-0046-specialist-review-agents.md) (Accepted) committed the specialist-review-agents pattern — narrower reviewers for security, performance, accessibility — invoked when their domain is touched.

[Invariant 53](../constitution/invariants.md) introduced by ADR-0046 requires **two independent LLM-review perspectives on high-risk Nodes** (Vault, Audit, Notify Cloud tenant-data, anything that an incident in produces an outsized blast radius).

What none of those ADRs settled: **the canonical PR-review stack**. Which reviewers run on every PR? What's the per-PR cost ceiling? Who satisfies Invariant 53's "two independent perspectives" requirement? When does a fourth reviewer kick in? And — critically — Anthropic's June 15 2026 launch of Claude Agent SDK credit pooling for Claude Max subscriptions creates a new path that did not exist when ADR-0044 was authored: running the same `.claude/agents/review.md` agent through Claude Code's web GitHub integration, billed against the operator's Max subscription rather than per-token.

The forcing functions converging now:

- **AI-authored PR volume has grown** (per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) context). Wave-style rollouts produce 5-15 agent PRs per window. The PR-review stack needs to be efficient per-PR or it becomes the bottleneck.
- **Invariant 53's "two independent perspectives" requirement** is unsatisfied today on substantive Node PRs. Today's stack (Copilot + CodeRabbit + Grid-aware-via-Codex) carries two third-party perspectives plus one Grid-aware perspective; technically three reviewers but only one Grid-aware-with-true-Grid-context. The dual-model execution of the Grid-aware agent (D3) is what cleanly satisfies Invariant 53 for substantive PRs.
- **Anthropic's June 15 2026 Claude Agent SDK credit pool** (announced in early May 2026; available for Claude Max subscribers) enables running Claude Code on the web sessions against the operator's existing Max subscription without per-token billing. The economic shape of "run a second Grid-aware reviewer with a different model family on substantive PRs" changed materially.
- **The Grid's substantive-vs-trivial-PR distinction** has no formal definition today. Without one, every reviewer runs on every PR (typo fixes, docs-only changes, README updates) — paying for review on PRs where the review value is near zero.
- **The charter's "performing visibility instead of building" warning** ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 3) explicitly bounds reviewer count. Three-or-four reviewers is the cap; "let's add a fifth AI reviewer for thoroughness" is exactly the performing-visibility failure mode.

This ADR commits the **canonical PR-review stack** — three reviewers on every PR by default, four on substantive PRs — names the **substantive-PR classifier**, satisfies **Invariant 53** through the dual-model execution of the Grid-aware agent, bounds the **per-PR cost**, and amends [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) with the billing-path discipline.

## Decision

### D1 — Three reviewers run on every PR by default

Every PR (excluding draft PRs per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1's cost discipline) receives three automatic reviews:

**Reviewer 1: GitHub Copilot Code Review.** GitHub-native; included in the operator's existing GitHub Copilot subscription; no marginal cost. Provides generic code-quality signal (style, common bugs, basic security patterns). Not Grid-aware.

**Reviewer 2: CodeRabbit.** Third-party AI reviewer; ~$24/dev/mo (one seat, one developer); rule-system support via `.coderabbit.yaml` for repo-specific patterns. Provides a third-party-AI perspective independent of Microsoft (Copilot) and Anthropic (Grid-aware agent). Not Grid-aware.

**Reviewer 3: Grid-aware `review` agent via Codex (OpenClaw-triggered).** The canonical Grid-aware reviewer per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md). Trigger path: GitHub webhook → OpenClaw → Codex CLI runtime → `.claude/agents/review.md` execution → PR comment with verdict. Billing: against the operator's ChatGPT Pro allotment; API overage if the allotment is exceeded. **Grid-aware** — loads invariants, ADRs, catalogs, per-Node context, and the packet via PR body link.

**Why these three together:**

- **Copilot is the GitHub-native baseline.** Zero marginal cost; runs anyway; catches the obvious style and correctness issues. Including it means the operator does not turn off a reviewer that's already running for free.
- **CodeRabbit provides true third-party-AI independence.** Different vendor, different model, different review optics. Catches things the other two reviewers miss because of their respective biases (Copilot's training-data alignment with GitHub's repos; the Grid-aware agent's alignment with the Grid's worldview).
- **The Grid-aware agent is the Grid-context perspective.** Knows the invariants, the ADRs, the boundaries, the per-Node patterns. Catches Grid-specific violations the other reviewers cannot.

Three different perspectives. Three different things they're good at. Three different things they miss. Real perspectives, not bot stacking.

### D2 — Substantive PRs receive a fourth reviewer (Grid-aware agent via Claude)

A **fourth reviewer** runs on substantive PRs:

**Reviewer 4: Grid-aware `review` agent via Claude (Anthropic-native triggered).** Same `.claude/agents/review.md` agent definition as Reviewer 3, executed through Anthropic's native Claude Code on the web GitHub integration. Different model family (Claude vs. Codex's GPT-class), same Grid context, same review rubric.

**Trigger path:**

- GitHub webhook → Anthropic's native Claude Code on the web GitHub integration → Claude Code on the web session → `.claude/agents/review.md` execution → PR comment with verdict.
- Note: this path does **not** go through OpenClaw. Anthropic's native integration is the dedicated runtime.

**Billing path:**

- Against the operator's **Claude Max Agent SDK credit pool**, available from **June 15, 2026**.
- No per-token API billing by default. The Agent SDK credit pool is the included allotment.
- **Pre-June-15 transition state:** Reviewer 4 does not run (the Agent SDK credit pool is not yet available; per-token API billing for this path is explicitly out of scope per the cost ceiling in D6). Reviewers 1, 2, and 3 operate normally during transition.

**Same agent definition, two execution paths.** [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1's "drift between execution surfaces is forbidden" principle holds: both the Codex (Reviewer 3) and Claude (Reviewer 4) paths consume `.claude/agents/review.md` directly. The agent file is the source of truth per [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md).

**Why dual-model execution of the same agent:** Per D5, this is what cleanly satisfies [Invariant 53](../constitution/invariants.md) on substantive PRs. Two different model families (GPT-class via Codex, Claude via Anthropic) executing the same Grid-aware agent definition produce two genuinely independent reviewer perspectives that **share the Grid's worldview**. The independence is at the model level; the worldview alignment is at the agent-definition level. This is the right shape for "two independent Grid-aware reviews" — not "two copies of the same model" (no real independence) and not "two different agent definitions" (loses the Grid-context consistency).

### D3 — Substantive-PR classifier

A PR is **substantive** if its changeset touches any file outside this safe-list:

- `*.md` — Markdown files
- `*.mdx` — MDX files
- `*.txt` — Plain text files
- `docs/**` — any path under `docs/` at any depth
- `LICENSE*` — `LICENSE`, `LICENSE.md`, `LICENSE.txt`, etc.
- `SECURITY.md` — security policy file
- `CODE_OF_CONDUCT.md` — code of conduct
- `CONTRIBUTING.md` — contributing guide
- `docs/assets/**` — documentation assets (images, diagrams)

Any PR whose changeset is entirely within the safe-list is **trivial** (docs-only); Reviewer 4 does not run. Any PR that touches any file outside the safe-list is **substantive**; all four reviewers run.

**Why this safe-list:**

- **The safe-list is conservative.** Erring toward "substantive" is the cheaper failure mode (extra review on a low-impact PR) than erring toward "trivial" (missing review on a code-impacting PR). The safe-list captures the obviously-no-code-impact changesets.
- **Documentation changes can still impact Grid behavior** in narrow cases (e.g., a `README.md` that contains executable code blocks or operator instructions). The safe-list does not exclude documentation review entirely — Reviewers 1, 2, and 3 all still review docs PRs. Reviewer 4 (the fourth, model-diversity perspective) is what the safe-list skips.
- **The classifier is mechanical and stable.** A file-path-glob check in the CI workflow; no LLM judgment about "is this PR important enough." Mechanical classification means consistent application.

The classifier lives in the PR-review CI workflow (per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1's `job-review-request.yml`); the substantive-or-trivial determination is communicated to both Reviewer 3 (which always runs) and Reviewer 4 (which conditionally runs).

### D4 — Greptile is considered and not selected

**Greptile** (or similar codebase-aware AI reviewers in the same category) is considered for inclusion in the canonical stack and explicitly not selected.

**The reasoning:**

- **Overlap with CodeRabbit.** Greptile occupies the same "generic third-party AI reviewer" slot as CodeRabbit. Adding Greptile alongside CodeRabbit is two reviewers doing the same kind of work with different vendor names.
- **Overlap with the Grid-aware agent.** Greptile's value prop ("cross-file context awareness") overlaps with what the Grid-aware agent already does — and the Grid-aware agent does it with actual Grid context (invariants, ADRs, catalogs), not just code-search.
- **Cost is non-zero.** Adding another paid third-party reviewer crosses the cost ceiling without delivering perspective the existing four-reviewer-on-substantive stack doesn't already provide.
- **Charter's "performing visibility" warning** is the explicit governor. Adding reviewers to look thorough is the failure mode; adding reviewers that catch things the others miss is the right move. Greptile does not clear that bar.

Greptile is held in the **watch list**: if a future event (a class of bugs the current stack consistently misses, a specific capability Greptile uniquely provides, a forcing function not visible today) emerges, Greptile is reconsidered. Today, the stack is full.

### D5 — Codex-only review (non-Grid-aware) is considered and not selected

Codex itself ships an out-of-the-box PR-review capability — generic, not Grid-aware. Considered for inclusion as a fifth reviewer and explicitly not selected.

**The reasoning:**

- **Codex's value to the Grid is executing the Grid-aware agent**, not its own generic review. The agent-definition-based review (`.claude/agents/review.md`) is what makes Reviewer 3 valuable; running Codex's generic review on top is duplicative of the Grid-aware-agent's already-Grid-context-loaded reasoning.
- **Generic review is already covered.** Copilot (Reviewer 1) and CodeRabbit (Reviewer 2) are both generic reviewers. A third generic reviewer (Codex out-of-the-box) is the bot-stacking the charter explicitly warns against.

Codex's role in this stack is exclusively as the runtime for Reviewer 3 (Grid-aware agent execution); it is not its own reviewer slot.

### D6 — Cost ceiling and posture

The per-month cost ceiling for the canonical reviewer stack:

| Item | Cost | Notes |
|---|---|---|
| Copilot Code Review (Reviewer 1) | Included in existing GitHub Copilot subscription | No marginal cost |
| CodeRabbit (Reviewer 2) | ~$24/dev/mo × 1 dev = $24/mo | Per the operator's subscription |
| Grid-aware via Codex (Reviewer 3) | Against ChatGPT Pro allotment; API overage if exceeded | Pre-June-15 and post: bounded by allotment + occasional overage |
| Grid-aware via Claude (Reviewer 4) | Against Claude Max Agent SDK credit pool (post-June-15) | No per-token API billing by default |
| **Total recurring** | **~$24/mo + bounded overage** | |

**Cost discipline principles:**

- **No reviewer runs on draft PRs.** Per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1.
- **Reviewer 4 runs only on substantive PRs** per D3. Docs-only PRs skip Reviewer 4.
- **Reviewer 4 does not fall back to per-token Anthropic API billing.** If the Agent SDK credit pool is exhausted, Reviewer 4 is skipped on subsequent PRs that day with an advisory comment. Per-token API billing as a fallback is explicitly out of scope by default; opting in requires an ADR amendment.
- **Codex API overage on Reviewer 3** is the only uncapped variable cost. The operator monitors it via existing OpenAI billing surfaces; if overage compounds materially, the trigger is the [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) governance discipline (cost-pressure inflection → reconsider).

### D7 — Invariant 53 satisfaction

[Invariant 53](../constitution/invariants.md) (from [ADR-0046](./ADR-0046-specialist-review-agents.md)) requires two independent LLM-review perspectives on high-risk Nodes (Vault, Audit, Notify Cloud tenant-data, etc.).

This stack satisfies Invariant 53 on substantive PRs through the **dual-model execution of the Grid-aware agent**:

- **Reviewer 3 (Codex execution)** — GPT-class model family.
- **Reviewer 4 (Claude execution)** — Claude model family.
- **Same agent definition, same Grid context, two genuinely different model families.**

This is the cleanest possible satisfaction of Invariant 53:

- **The two perspectives are genuinely independent at the model level.** GPT-class and Claude-class models are trained by different organizations, on different data, with different RLHF approaches, with different bias patterns. A failure mode that GPT misses is unlikely to also be a failure mode Claude misses, and vice versa.
- **Both perspectives share the Grid's worldview** through the shared `.claude/agents/review.md` agent definition. The "two-perspective" requirement does not become "two-different-rubrics" — it becomes "two model families applying the Grid's rubric."
- **Copilot (Reviewer 1) and CodeRabbit (Reviewer 2) provide additional perspectives** but are not Grid-aware; they do not satisfy Invariant 53's "Grid-context-loaded review" intent.

**Pre-June-15 transition state:** Invariant 53 is not fully satisfied during the transition (only one Grid-aware reviewer runs). The transition state is acceptable because Invariant 53 is interpreted as "post-stack-completion requirement" — substantive PRs on high-risk Nodes during transition either land with the single Grid-aware perspective plus the two generic perspectives (degraded-but-honest posture), or the operator manually invokes a second Grid-aware review until June 15.

### D8 — Amendment to ADR-0044 (billing-path discipline)

This ADR amends [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) with explicit billing-path discipline that ADR-0044 left implicit:

**Billing paths:**

- **Reviewer 3 (Codex via OpenClaw)**: ChatGPT Pro allotment first; per-token API billing as overage. This is the path today and ongoing.
- **Reviewer 4 (Claude via Anthropic-native)**: Claude Max Agent SDK credit pool from June 15, 2026 onward; no per-token API billing as default fallback.

**Auth-precedence gotcha (operator-facing):**

> Setting `ANTHROPIC_API_KEY` in any runner environment will silently flip Claude execution to per-token API billing. The Agent SDK credit pool is consumed when the runner authenticates as the operator's Claude Max session — typically via the Claude Code on the web integration's session credentials. If a runner environment has `ANTHROPIC_API_KEY` set as an environment variable, the SDK uses it preferentially over the session credentials, and per-token billing applies. **Do not set `ANTHROPIC_API_KEY` in the Reviewer 4 runner environment by default.**

This gotcha is documented at the runner configuration level; the operator-facing checklist for setting up Reviewer 4 calls it out explicitly.

### D9 — Out of scope

The following are explicitly **not** decided by this ADR:

- **Specialist agent invocation.** Per [ADR-0046](./ADR-0046-specialist-review-agents.md), specialist agents (security, performance, accessibility) are invoked when their domain is touched. The canonical reviewer stack (D1, D2) runs in addition to specialist agents; this ADR does not change ADR-0046's invocation logic.
- **Human reviewer involvement.** All four reviewers are advisory per [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) D5 and [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1; the merge gate (operator approval) is unchanged. This ADR does not change merge-flow.
- **Cross-reviewer verdict aggregation.** Each reviewer posts its own PR comment; there is no aggregated "X of 4 reviewers approve" signal. Aggregation is a future-state concern.
- **Per-Node high-risk classification.** Per-Node "high-risk" designation (which Nodes Invariant 53 applies to) is owned by [ADR-0046](./ADR-0046-specialist-review-agents.md); this ADR does not re-decide.
- **Trivial-PR Reviewer 1/2/3 suppression.** Reviewers 1, 2, and 3 still run on docs-only PRs. The cost is low; the value (catching the rare docs-PR-that-actually-changes-behavior) is real. Only Reviewer 4 is skipped on trivial PRs per D3.
- **Per-PR reviewer override.** A PR author cannot opt out of reviewers by marking a PR "trivial" via label or commit message. The classifier is mechanical per D3.
- **The full content of `.claude/agents/review.md`.** That file is the agent definition's source of truth per [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md); this ADR does not specify the review rubric content.

## Consequences

### Affected Nodes

- **HoneyDrunk.Architecture** — primary affected Node. The PR-review CI workflow in `HoneyDrunk.Actions` (per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md)) is updated with the substantive-PR classifier per D3 and the Reviewer 4 trigger per D2.
- **HoneyDrunk.Actions** — `job-review-request.yml` (or equivalent) gets the classifier logic; CodeRabbit integration is documented at the repo level (`.coderabbit.yaml`).
- **Every Grid repo** — each repo's PR review surface now carries up to four reviewer comments per substantive PR. The repo's `CONTRIBUTING.md` (or equivalent) documents what reviewers expect.
- **[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)** — explicitly amended by this ADR per D8. The billing-path discipline and the auth-precedence gotcha are now first-class artifacts.
- **[ADR-0046](./ADR-0046-specialist-review-agents.md)** — [Invariant 53](../constitution/invariants.md) interpretation is clarified per D7. The dual-model Grid-aware-agent execution is the canonical satisfaction.

### Invariants

This ADR proposes (numbering finalized at acceptance):

- **The canonical PR review stack is four reviewers** (three on every PR, four on substantive PRs) per D1 + D2.
- **The substantive-PR classifier is the safe-list in D3.** Per-PR override is forbidden.
- **The Grid-aware agent's two execution paths (Codex + Claude) must consume the same `.claude/agents/review.md` definition.** Drift between execution paths is forbidden. (Extends [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1.)
- **`ANTHROPIC_API_KEY` is not set in the Reviewer 4 runner environment by default.** (Codifies D8's gotcha.)

### Operational Consequences

- **Substantive PRs receive four perspectives.** Real diversity, not bot stacking. The two Grid-aware perspectives satisfy Invariant 53 cleanly.
- **Trivial PRs receive three perspectives.** Reviewer 4 is skipped per D3; cost discipline preserved.
- **Per-PR cost is bounded.** ~$24/mo CodeRabbit + Codex allotment + Anthropic credit pool. No uncapped variable cost by default.
- **The pre-June-15 transition state is honest.** Reviewer 4 enables on June 15 when the Agent SDK credit pool becomes available; the transition is documented; Invariant 53's satisfaction is degraded-but-honest until then.
- **The reviewer stack is sustainable for one operator.** The cost ceiling, the cap at four reviewers, and the substantive-PR classifier together prevent the "let's add another bot" drift.
- **The auth-precedence gotcha is a known landmine.** Documented; reviewer-runner configuration is the place to enforce. If a future operator (or AI agent helping the operator) sets `ANTHROPIC_API_KEY` carelessly, billing flips silently. The mitigation: documented at every runner-configuration touchpoint.
- **PR review-comment density is meaningful.** Three or four bots posting comments per PR is real review-noise; the mitigation is reviewer-comment quality discipline at each reviewer's prompt level (already in place for the Grid-aware agent per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3's rubric; less controllable for Copilot and CodeRabbit).
- **Specialist agents per [ADR-0046](./ADR-0046-specialist-review-agents.md) compose on top.** A substantive PR touching the Vault Node receives Reviewers 1-4 plus the security specialist agent — five reviewers total. The five-reviewer ceiling on the most-sensitive PRs is the operational maximum.

### Follow-up Work

- Update `HoneyDrunk.Actions`'s `job-review-request.yml` (or equivalent) with the substantive-PR classifier per D3.
- Wire the Reviewer 4 trigger (Anthropic's native Claude Code on the web GitHub integration) at June 15 launch.
- Document the auth-precedence gotcha (D8) in HoneyDrunk.Actions's runner configuration documentation.
- Update [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) with a "Amended by ADR-0079" note linking back to this ADR.
- Update [ADR-0046](./ADR-0046-specialist-review-agents.md) with a clarifying note on [Invariant 53](../constitution/invariants.md)'s satisfaction via D7's dual-model pattern.
- Operator-facing onboarding doc (or `CONTRIBUTING.md` aggregator) explains the four-reviewer expectation.
- Cost monitoring per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) tracks CodeRabbit + Codex overage + Anthropic credit pool consumption.
- Watch list: Greptile re-evaluation if a class of missed bugs emerges; Codex out-of-the-box review re-evaluation if its Grid-context-loading capability improves; specialist agents per [ADR-0046](./ADR-0046-specialist-review-agents.md) invocation logic stays per-Node.

## Alternatives Considered

### Greptile as the third-party AI reviewer (in addition to or instead of CodeRabbit)

Considered. The argument: Greptile is a strong codebase-aware reviewer with cross-file context; could replace CodeRabbit or augment it.

Rejected per D4. Greptile's cross-file context awareness overlaps with the Grid-aware agent's actual Grid-context loading; Greptile's vendor-independence overlaps with CodeRabbit's vendor-independence. Adding Greptile is two reviewers in slots already filled. Held in the watch list per D4's reconsideration triggers.

### Codex out-of-the-box review (non-Grid-aware) as a fifth reviewer

Considered. The argument: Codex's own PR-review capability runs alongside the Grid-aware agent execution; one more perspective.

Rejected per D5. Codex's generic review duplicates Copilot's and CodeRabbit's generic-review slot; the Grid-aware-agent execution is where Codex's value lies. A fifth generic reviewer is bot stacking.

### Drop Copilot (Reviewer 1) since it's the weakest of the four

Considered. The argument: Copilot's review is generic, often noisy, and adds review-comment density.

Rejected. Copilot is zero-marginal-cost (already in the operator's subscription); dropping it does not save money. The signal-to-noise ratio is real but the cost of leaving it on is also zero; the dropping decision should be made on signal quality only, and Copilot's signal is non-zero (it catches genuine simple bugs).

### Drop CodeRabbit (Reviewer 2) since the Grid-aware agent + Copilot covers the perspective space

Considered. The argument: CodeRabbit costs $24/mo; the Grid-aware agent and Copilot together are sufficient.

Rejected. CodeRabbit's third-party-AI independence (not Microsoft, not Anthropic) is a genuine perspective the other two don't carry. Removing it would reduce vendor diversity in the reviewer pool. $24/mo is a small cost for the independent perspective.

### Run the Grid-aware agent with both Claude and Codex as standard (on every PR, not just substantive)

Considered. The argument: the dual-model satisfaction of Invariant 53 should apply universally, not just on substantive PRs.

Rejected on cost-discipline grounds. Reviewer 4's cost (against the Agent SDK credit pool) is bounded but not zero; running it on docs-only PRs burns credit that could be saved for substantive PRs. The substantive-PR classifier per D3 is the cost-discipline mechanism. Charter's anti-performing-visibility warning applies: bot stacking on trivial PRs is the failure mode the cap exists to prevent.

### Make Reviewer 4 mandatory pre-June-15 by paying per-token Anthropic API

Considered. The argument: Invariant 53 satisfaction is more important than the per-token cost.

Rejected. Pre-June-15, the API per-token cost for executing the Grid-aware agent through Claude on every substantive PR would be material (rough estimate: ~$50-$150/mo at MVP PR volume; higher at scale). The cost-vs-value trade-off does not favor paying API tokens for a feature that becomes free on June 15. The transition-state Invariant 53 degradation per D7 is the acceptable compromise.

### Use Anthropic's native Claude Code on the web integration as Reviewer 3 (replace the Codex/OpenClaw path entirely)

Considered. The argument: simplify by having a single Grid-aware reviewer using the most flexible integration.

Rejected. The OpenClaw/Codex path is established, working, and uses the operator's ChatGPT Pro subscription (no marginal cost). Replacing it would remove a working reviewer without replacing its model-family-diversity value. The two paths complement each other; dropping either loses the dual-model independence per D7.

### Replace CodeRabbit with a self-hosted alternative (open-source equivalent)

Considered. The argument: avoid the vendor relationship; reduce recurring cost.

Rejected. No open-source PR-review tool in 2026 has CodeRabbit's quality, configurability, and integration polish. The $24/mo is a fair price for the capability; the self-hosting cost (in operator time and infrastructure) would exceed the saving.

### Skip this ADR; let the existing ad-hoc reviewer set continue

Considered. The argument: Copilot + CodeRabbit + Grid-aware-via-Codex is already running; formalizing it adds no capability.

Rejected. The ADR captures the substantive-PR classifier (D3), the Invariant 53 satisfaction (D7), the June 15 enablement plan (D2), and the auth-precedence gotcha (D8). All four are new artifacts that prevent specific failure modes. The formalization is the value.

## Superseded in part by ADR-0086

[ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) (Accepted) moves the Grid Review Runner from the OpenClaw-hosted signed-webhook transport (per ADR-0044) to a pull-based local worker. The transport change cascades into Reviewer 3's substrate and reshapes Reviewer 4's enablement plan.

**Superseded transport-wise — D1 Reviewer 3 (Grid-aware `review` agent via Codex, OpenClaw-triggered).**

The trigger path is no longer "GitHub webhook → OpenClaw → Codex CLI runtime → `.claude/agents/review.md` → PR comment." Under ADR-0086 D1–D4 it becomes "GitHub PR event → cheap GitHub Action (label + comment enqueue) → local worker poll → Codex CLI (subscription auth) → PR comment + label state transition." OpenClaw is removed from the review path. Billing is unchanged: against the operator's ChatGPT Pro allotment, with API overage if exceeded. The Grid-aware property and the agent-definition source-of-truth rule are preserved verbatim.

**Superseded — D2 Reviewer 4 (Grid-aware `review` agent via Claude, Anthropic-native triggered).**

ADR-0079 D2 committed the path through Anthropic's native Claude Code on the web GitHub integration, billed against the **Claude Max Agent SDK credit pool** from **June 15, 2026**. ADR-0086 D8 reverses this:

Reviewer 4 now runs through the **same local worker** as Reviewer 3, using local **Claude Code CLI** under the operator's existing Claude Max subscription session. This is available **today**, removes the June 15 dependency, removes the auth-precedence gotcha at the worker boundary (no `ANTHROPIC_API_KEY` is ever set in the worker environment per ADR-0086 D4), and uses one substrate (the local worker) for both Reviewer 3 and Reviewer 4. Same Claude Max billing path as ADR-0079 D2 intended — subscription session, no per-token API billing — just executed via the local CLI rather than the web integration. The web-integration path is removed from the Grid Review Runner's design.

The pre-June-15 transition-state degradation of Invariant 53 satisfaction (D7) **collapses to zero** under the new path, because Claude Code CLI under Max is available now.

**Preserved verbatim:**

- D3 (substantive-PR classifier safe-list).
- D4 (Greptile considered and not selected).
- D5 (Codex out-of-the-box review considered and not selected).
- D6 (cost ceiling and posture) — ADR-0086 D6's cost shape is consistent with this accounting.
- D7 ([Invariant 53](../constitution/invariants.md) satisfaction via dual-model execution of the same Grid-aware agent) — two different model families (GPT-class via Codex CLI, Claude via Claude Code CLI) executing the same `.claude/agents/review.md` definition. The independence is at the model level; the worldview alignment is at the agent-definition level. The substrate (now the local worker) preserves both.
- D8 (auth-precedence gotcha) — preserved as a general operator-facing landmine, now enforced at the worker env boundary per ADR-0086 D4.
- D9 (out-of-scope items).

The four invariants proposed in this ADR's Consequences section are **preserved** under the new transport. The "Grid-aware agent's two execution paths (Codex + Claude) must consume the same `.claude/agents/review.md` definition" invariant continues to hold; the two paths are now Codex CLI and Claude Code CLI under the local worker (or, under the alternative, Codex CLI under the local worker plus Claude Code on the web integration post June 15).

## References

- [`constitution/charter.md`](../constitution/charter.md) — workshop craft, many-decade horizon, anti-performing-visibility warning
- [`constitution/invariants.md`](../constitution/invariants.md) — invariant 10 (Auth validates only); invariant 52 (Grid-aware reviewer per ADR-0044); invariant 53 (two independent perspectives on high-risk Nodes per ADR-0046)
- [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md) — `.claude/agents/` as source of truth (both Reviewer 3 and Reviewer 4 consume `.claude/agents/review.md`)
- [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) — base code-review-and-merge flow
- [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) — HoneyDrunk.Actions (hosts the PR-review CI workflow)
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — Grid-aware cloud code reviewer (amended by this ADR per D8)
- [ADR-0046](./ADR-0046-specialist-review-agents.md) — specialist review agents (Invariant 53 source; interpretation clarified per D7)
- [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) — cost governance (reviewer-stack cost monitoring)
