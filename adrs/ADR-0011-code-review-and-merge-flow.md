# ADR-0011: Code Review and Merge Flow

**Status:** Proposed
**Date:** 2026-04-12
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

ADR-0008 defines the Packet → Issue → Board → PR → Merge lifecycle (D6). Stages 1–4 — Spec, Ticket, Dashboard, Execution — are fully specified. Stage 5 — Merge — is a single line: "PR merges, issue closes, board item → Done via workflow." There is no convention for *how* a PR earns its merge.

This was tolerable when every PR was authored by the solo developer: the author and the reviewer were the same person, and the review was whatever the developer thought about before clicking Merge. With the ADR-0005 / ADR-0006 Wave 1 rollout, agent-authored PRs are about to land for the first time, and two things change:

1. **The author and reviewer are no longer the same person.** A cloud-agent PR is authored by the Claude Agent SDK against a packet spec. The human solo developer is the first set of human eyes on the diff. The review gate now has a real job.
2. **The review convention must exist before first use.** With 15 packets in flight across 10 repos in Wave 1, and the `.claude/agents/review.md` agent already defined but not yet wired into the PR flow, every agent PR that merges without a named gate invents the gate ad hoc, and drift starts on day one — the same problem ADR-0008 solved for work tracking.

Some of the pipeline already exists. `HoneyDrunk.Actions` ships `pr-core.yml`, which orchestrates build-and-test, static analysis (including the ADR-0009 vulnerability gate), secret scanning, and a PR summary comment. The review agent is defined in `.claude/agents/review.md` and is invoked locally by the solo developer via Claude Code before clicking Merge — deliberately *not* wired as a cloud workflow, to keep per-PR LLM cost at zero. GitHub Copilot review runs automatically on PRs where it is enabled and fills the "automatic LLM reviewer" slot, since it is already paid for via the existing Copilot subscription. The solo developer reviews and merges. What is missing is the *named pipeline* that ties these stages together with explicit owners, inputs, outputs, and blocking posture — plus honest accounting of which stages are aspirational.

This ADR picks up exactly where ADR-0008 D6 stage 5 begins and ends at the merge button. Sector is **Meta**, same as ADR-0008, because this is process architecture for the Grid's execution machinery, not system topology.

This ADR depends on ADR-0007 (agent definitions live in `.claude/agents/`), ADR-0008 (the upstream lifecycle and the packet as immutable spec), ADR-0009 (the PR-time vulnerability gate that already blocks on High+), and ADR-0010 (Proposed — the observation layer whose invariants 29–30 are reserved, which is why this ADR's new invariants begin at 31).

## Decision

Code review and merge are defined by eleven bound decisions. Together they describe the ordered pipeline a PR traverses from "agent opens PR" to "human clicks Merge," the owner and artifact contract of each stage, the honest present-or-aspirational status of each, and the specific static-analysis tool chosen to fill the third-party analysis slot.

### D1 — GitHub PR is the system of record for review state

The pull request object in GitHub is the source of truth for what stages have run on a PR, what they returned, and whether the PR is mergeable. Check runs (from `pr-core.yml` and peers), review comments (from Copilot and the review agent), and the native Review state (from the human) are the three surfaces. Branch protection enforces the gate.

The org Project board (ADR-0008 D1) tracks the *packet's* lifecycle, not the PR's. When the PR merges, the packet's board `Status` transitions to `Done` via the existing merge workflow. The PR never becomes a board item in its own right.

Rejected: tracking review state in a custom board field, an external tool, or a YAML file inside the repo. All three duplicate state GitHub already owns natively and drift trivially.

### D2 — Ordered review pipeline, fail-fast cheap-first

Every agent-authored or human-authored PR traverses the following stages in order. Stages within a tier run in parallel; tiers run sequentially. A stage that fails blocks progression to later tiers but does not prevent earlier-tier stages from finishing and reporting.

| # | Stage | Tier | Owner | Status today |
|---|---|---|---|---|
| 1 | Build | 1 | `job-build-and-test.yml` | **Present** |
| 2 | Unit tests | 1 | `job-build-and-test.yml` | **Present** |
| 3 | Static analysis — analyzers & formatting | 1 | `job-static-analysis.yml` (HoneyDrunk.Standards) | **Present** |
| 4 | Vulnerability scan (PR gate) | 1 | `job-static-analysis.yml` + `security/vulnerability-scan` | **Present (ADR-0009)** |
| 5 | Secret scan (diff) | 1 | `job-secret-scan.yml` | **Present** |
| 6 | Integration tests | 2 | *(slot, not yet built)* | **Aspirational** |
| 7 | Static analysis — SonarCloud | 2 | `job-sonarcloud.yml` (public repos only — see D11) | **Aspirational (tool chosen, wiring pending)** |
| 8 | Review agent (architectural review) | 3 | `.claude/agents/review.md` via **local Claude Code, human-invoked** | **Present** |
| 9 | Copilot review (automatic LLM reviewer) | 3 | GitHub Copilot PR review (cloud, automatic) | **Present** |
| 10 | E2E tests | 4 | *(slot, not yet built)* | **Aspirational** |
| 11 | Human review and merge | 5 | Solo developer | **Present** |

**Tier semantics:**

- **Tier 1** — cheap, deterministic, already exists via `pr-core.yml`. Build, tests, analyzers, vuln scan, secret scan. Must pass before tier 2 is worth spending money on. Roughly 2–5 minutes.
- **Tier 2** — more expensive but still deterministic. Integration tests against contract-compatible fakes; SonarCloud third-party static analysis. Required before the LLM review tier.
- **Tier 3** — advisory, LLM-driven. Two reviewers run in parallel but with different trigger models: **Copilot** runs automatically in the cloud on every PR and is paid for through the existing Copilot subscription; **the review agent** runs locally via Claude Code, invoked by the human solo developer before clicking Merge, to keep per-PR LLM cost at zero (see D10 for rationale). Both produce PR comments, neither produces a required check. Because the review agent is human-triggered, the "must not run on failing PRs" rule is enforced by the human noticing a red tier-1 check and declining to invoke the agent.
- **Tier 4** — E2E tests. Slowest, least diagnostic, most infra cost. Last gate before human.
- **Tier 5** — the human. The solo developer reads the tier 3 agent verdicts, spot-checks the diff, and clicks Merge.

Fail-fast is the ordering principle: LLM review is the expensive stage and should never run on a PR that already failed `dotnet build`. This is a cost-discipline decision, not a correctness one.

### D3 — Per-stage artifact contracts

Every stage has a defined input → output contract. The contracts are small enough to fit in this table; each is expanded where non-obvious.

| Stage | Reads | Writes |
|---|---|---|
| Build | Source tree, `.slnx`, `NuGet.config` | Check run (pass/fail), build logs |
| Unit tests | Built assemblies, `.Tests` projects | Check run, test-results artifact, coverage-reports artifact |
| Static analysis — analyzers | Source tree, `HoneyDrunk.Standards` rules, `.editorconfig` | Check run, warning list on PR summary |
| Vulnerability scan | `dotnet list package --vulnerable --include-transitive` | Check run; blocks on High+ per ADR-0009 |
| Secret scan | PR diff | Check run, findings posted as PR annotation |
| Integration tests *(slot)* | Built assemblies from stage 1, cross-Node test projects wired against contract-compatible fakes (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue` per invariant 15) | Check run, test-results artifact |
| Static analysis — SonarCloud | Source tree, `sonar-project.properties`, coverage report from unit tests, PR diff | Check run, inline PR annotations, SonarCloud quality gate status |
| Review agent | Packet file (via issue link), governing ADRs, `constitution/invariants.md`, affected Nodes' `boundaries.md` + `invariants.md`, `catalogs/relationships.json`, `catalogs/contracts.json`, PR diff | **Advisory** PR comment in the format defined by `.claude/agents/review.md` |
| Copilot review | PR diff, repo `.github/copilot-instructions.md` | Inline PR comments |
| E2E tests *(slot)* | Deployed test environment, Playwright test project | Check run, run artifacts, Playwright HTML report, trace files for failed runs |
| Human review | All of the above, aggregated on the PR page | Approving review, merge commit |

**Input "packet file (via issue link)" is non-negotiable for the review agent.** Packets are the canonical statement of scope for a work item (ADR-0008 D7). A review that cannot see what the PR was *supposed* to do cannot evaluate whether it did it. The PR body must link to the packet file in the Architecture repo; the review agent resolves the link, reads the packet, and uses it as the primary scope anchor. PRs whose body does not link to a packet are, by convention, out-of-band work — see D9.

### D4 — The review agent is the scope agent's context-loading peer

ADR-0008 binds the scope agent to a context-loading contract on the way *in* to execution: before authoring a packet, scope reads Grid topology, invariants, boundaries, relationships, and routing rules. This ADR binds the review agent to the symmetric contract on the way *out*: before rendering a verdict, the review agent reads the **same** Grid context, augmented with the packet and the PR diff.

The symmetry is deliberate. If the two agents load the same context, there is no class of defect the scoping agent could introduce that the review agent could miss for lack of information. Drift between the two context-loading contracts is an anti-pattern; updates to one must be mirrored in the other.

The review agent's mandatory context load is:

1. `constitution/invariants.md` — all numbered invariants
2. The governing ADRs referenced in the packet frontmatter
3. `catalogs/relationships.json` — downstream cascade
4. `catalogs/contracts.json` — contract surface
5. For each target repo: `repos/{node}/overview.md`, `boundaries.md`, `invariants.md` if present
6. `copilot/pr-review-rules.md` — severity taxonomy
7. The packet file
8. The PR diff

This list lives in `.claude/agents/review.md` (authoritative per ADR-0007) and is the binding definition. Changes to the context-loading contract are edits to that file, not to this ADR.

### D5 — Review agent is advisory, not blocking

The review agent posts a PR comment with a structured verdict (`Approved`, `Request Changes`, `Block`) per the format in `.claude/agents/review.md`. It does **not** set a required check that physically prevents merge.

Rationale:
- **Agent outages do not halt merges.** A Claude Agent SDK outage or a cost-cap exhaustion cannot strand the Grid.
- **Cost discipline.** Required-check posture would force a full context-loading run on every tiny PR. Advisory posture lets the cloud action skip invocation (or run cheaper) when the diff is trivial.
- **Symmetry with `refine`.** On the scoping side of the Grid, `refine` is advisory too — it challenges packets but never holds a lock on them. The review gate mirrors that posture.
- **Solo-dev agency.** The human is the reviewer of last resort. A `Block` verdict is authoritative documentation that a bypass happened, not a technical lockout.

The advisory posture does not weaken the tier-1 gates. Build, tests, analyzers, vulnerability scan, and secret scan all remain **required** branch-protection checks via `pr-core.yml`. Advisory applies to tiers 2–4 that rely on an LLM or an environment beyond CI. SonarCloud (D11) is an exception — it is tier 2, deterministic, and its quality gate is a required check on public repos.

### D6 — Cost discipline is a named review agent responsibility

No separate tool exists for this. Instead, the review agent's checklist (in `.claude/agents/review.md`) carries an explicit **Cost Discipline** section that the review agent evaluates on every PR:

- New logging at `Information` level or below in hot paths (request handlers, message consumers, job loops) without a sampling rate
- New LLM agent invocations without a cost cap or model-routing budget
- New CI jobs without an `if:` guard, a `paths:` filter, or a `schedule:` tier that prevents firing on every push
- New Azure resources without an SKU justification in the packet
- New outbound HTTP calls in request hot paths
- Loops over `catalogs/*.json` or `repos/*` that would grow unbounded as the Grid expands

Cost findings follow the normal severity taxonomy (Block / Request Changes / Suggest). Most are Suggest or Request Changes; a new Azure resource without SKU justification in a public-repo PR is Block-grade because it cannot be reverted silently once merged and committed to history.

This decision binds the review agent definition file. Updates to the Cost Discipline checklist are edits to `.claude/agents/review.md`, not to this ADR.

### D7 — Grid-alignment check is a named review agent responsibility

Grid alignment is the single most Grid-specific thing a review can do, and it is what the review agent exists for. Three questions, answered against the packet and the diff:

1. **Does the PR honor the packet?** Scope creep, scope shortfall, undocumented side effects.
2. **Does the PR respect the affected Nodes' boundaries?** Read `repos/{node}/boundaries.md`; flag any work that has leaked into a different Node's responsibility.
3. **Does the PR preserve every invariant?** Walk `constitution/invariants.md` and each repo-specific `invariants.md`. Invariants 1–28 are the enforcement surface today (and 31–33 once this ADR lands).

Output is a PR comment using the format already defined in `.claude/agents/review.md`. Findings reference the specific invariant number, boundary rule, file, and line.

### D8 — How failures surface

| Failure class | Where it shows up | Blocks merge? |
|---|---|---|
| Build, tests, analyzers, vuln scan, secret scan | PR check (red) | **Yes** (branch protection) |
| Integration tests *(when built)* | PR check (red) | **Yes** (branch protection) |
| SonarCloud quality gate — public repo | PR check (red) + inline annotations | **Yes** (branch protection) |
| SonarCloud quality gate — private repo | n/a — not enabled on private repos by default (see D11) | No |
| Review agent `Block` verdict | PR comment | No — advisory, human decides |
| Review agent `Request Changes` | PR comment | No — advisory |
| Copilot review comments | Inline PR comments | No |
| E2E tests *(when built)* | PR check | **Yes** (branch protection) |
| Human approval missing | PR review state | **Yes** (branch protection, "require 1 approval") |

The aggregated PR summary comment (already generated by `pr-core.yml`'s `pr-summary` job) is the single place a human looks first. The summary shows tier-1 results. Tier-3 agent verdicts are separate comments the human reads before merging.

### D9 — Out-of-band PRs (no packet link)

A PR that does not link to a packet is out-of-band: it was not authored from a scope-agent spec. Examples: a hotfix typed directly in the GitHub web UI, a README correction, a dependabot-style auto-update (not enabled today per ADR-0009, but could be).

Out-of-band PRs still traverse the full pipeline, with one modification: the review agent's packet-loading step is skipped. The agent runs with only the Grid context (invariants, boundaries, relationships, diff). Verdicts are rendered against the diff alone, and findings cannot reference packet scope. This is a weaker review, and it is acknowledged — out-of-band PRs exist, they should remain possible, and the review gate should degrade gracefully rather than refuse to run.

Out-of-band PRs must carry an `out-of-band` label. The reviewer-of-last-resort (human) uses this as a signal to spot-check scope manually.

### D10 — The review agent runs locally via Claude Code, invoked by the human

The execution model for the review agent is **deliberately local-only**. The human solo developer invokes `.claude/agents/review.md` via Claude Code against an open PR before clicking Merge. There is no `pr-review-agent.yml`, no cloud workflow, no per-PR GitHub Action that spawns a Claude Agent SDK run. The local invocation is the intended end state, not a temporary workaround for missing wiring.

**Rationale:**

- **Per-PR LLM cost is zero.** A cloud-wired review agent would run the Claude Agent SDK on every `pull_request` event — every push to a feature branch, every synchronize, every reopen. At agent-authored PR volume (15 packets in Wave 1 alone, with more waves to come), this becomes a meaningful recurring cost for a solo-dev budget. Local invocation means the human pays only when they actually want a review, using the Claude Code subscription they already have.
- **The automatic LLM reviewer slot is already filled by Copilot.** GitHub Copilot PR review runs automatically on every PR and is paid for via the existing Copilot subscription. Cloud-wiring the review agent would add a second automatic LLM reviewer on top of Copilot, which is the exact overlap that led D11 to reject CodeRabbit. The local review agent is the *deeper-context* reviewer the human reaches for when they want Grid-aware analysis — complementary to Copilot, not a duplicate.
- **Solo-dev workflow already has the human at the keyboard.** The human is the one clicking Merge. They are already in Claude Code for other work. Invoking the review agent as a local command before merge is one extra step, not an extra context switch.
- **No cloud infrastructure to maintain.** No `pr-review-agent.yml` to author, no `ANTHROPIC_API_KEY` org secret to provision and rotate, no GitHub Actions runner cost, no debugging "why did the review agent time out on this PR" incidents.

**Accepted risk:** a distracted solo developer may forget to invoke the review agent and merge a PR that received only tier-1 gates plus Copilot review. This is a behavioral failure mode, not a technical one. Mitigations:

- Copilot's automatic review covers the "generic code review" surface, so a forgotten review-agent invocation still gets LLM-reviewed by Copilot.
- The tier-1 gate (build, tests, analyzers, vuln scan, secret scan) still blocks merge via branch protection, independently of whether the review agent ran.
- The review agent's unique value is Grid-awareness (invariants, boundaries, packets, ADRs). Forgetting it means losing Grid-specific review on that PR, not losing all review.
- The human solo developer holds this discipline personally. An invariant enforcing "review agent must run on every agent-authored PR" is not added because it would be a rule enforced only by the same human who is the only possible violator — the self-discipline is sufficient and a written invariant would not strengthen it.

**Invocation contract:**

1. Human opens the PR locally in Claude Code (workspace already contains both the target repo and `HoneyDrunk.Architecture`)
2. Invokes the `review` agent against the open PR
3. Agent loads the context listed in D4 (invariants, boundaries, catalogs, governing ADRs, packet file via PR body link, PR diff)
4. Agent produces a verdict using the format in `.claude/agents/review.md`
5. Human reads the verdict and either: posts it as a PR comment for audit trail, requests changes on the PR, or proceeds to merge

**Explicitly rejected alternative: cloud wiring.** See the "Cloud-wire the review agent" entry in Alternatives Considered for the full cost-vs-automation analysis.

### D11 — SonarCloud is the third-party static analysis tool; public-repos-first

The third-party static analysis slot (D2 stage 7) is filled by **SonarCloud**. Tool choice rationale:

- **Free for public HoneyDrunk repos.** The Grid is public by default, and SonarCloud's public-repo tier includes PR decoration, branch analysis, and the full C# rule set at zero cost. This is load-bearing: the cost/maintenance argument against self-hosted SonarQube Community Edition does not apply when the service is hosted free.
- **Complements the review agent rather than overlapping it.** LLMs (the review agent, Copilot) are weak at quantitative metrics — cognitive complexity scores, cross-file duplication detection, cyclomatic complexity thresholds — and those are exactly what SonarCloud is strong at. The two layers are complementary, not redundant.
- **Mature .NET support.** SonarCloud's C# analyzer (SonarAnalyzer.CSharp) is a Roslyn analyzer with deep coverage, runs via the standard `dotnet-sonarscanner` CLI, and integrates cleanly with the existing `dotnet test` + coverlet pipeline.
- **Native GitHub PR decoration.** No bespoke comment-posting workflow required. SonarCloud sets a check run directly from its GitHub App.

**Public-vs-private posture:**

- **Public repos** — SonarCloud is enabled via a new `job-sonarcloud.yml` called from `pr-core.yml`. The quality gate is a **required** branch-protection check. This is the default posture for every Grid repo unless explicitly private.
- **Private repos** — SonarCloud is **not enabled by default**. Private-tier SonarCloud is paid per line of code, and the set of private repos in the Grid is small (revenue / compliance / experiment exceptions only). Private repos rely on the tier-1 gate plus the review agent's architectural checks. If a private repo warrants SonarCloud coverage, it is an explicit opt-in decision recorded in a packet against that repo, and the per-LOC cost is justified against the packet's business driver.

**Rejected alternatives for this slot:**

- **SonarQube Community Edition (self-hosted).** Free but requires operating a service. Community Edition lacks PR analysis and branch analysis — the two features that make the tool useful at PR time. Developer Edition adds them at real cost. For a solo dev, the operational burden is disqualifying when SonarCloud public-tier solves the same problem at zero cost and zero maintenance.
- **CodeRabbit.** LLM-based PR reviewer that runs automatically in the cloud and posts verdicts as PR comments. Rejected for two overlapping reasons: (a) the **automatic LLM reviewer** slot is already filled by **GitHub Copilot**, which is included in the existing Copilot subscription at no marginal cost; (b) the **deeper Grid-aware LLM reviewer** slot is filled by the **local review agent** (D10), which is strictly better for HoneyDrunk because it knows the Grid (invariants, boundaries, packets, ADRs) and runs on a per-invocation basis rather than every PR. CodeRabbit would be a paid third LLM reviewer duplicating functionality already present in two forms. Not a quality judgment against CodeRabbit — a structural judgment that its slot is taken twice over.
- **Custom static analysis framework.** Infinite flexibility, infinite maintenance. No unique domain requirement justifies building a new tool when mature off-the-shelf options exist.

**Contract for the SonarCloud stage:**
- **Input:** source tree, `sonar-project.properties` at the repo root, coverage report from stage 2 (unit tests), PR diff
- **Output:** required PR check (quality gate status), inline PR annotations for findings at or above the severity threshold defined in the SonarCloud project settings
- **Owner:** new `job-sonarcloud.yml` in `HoneyDrunk.Actions`, called from `pr-core.yml` tier 2
- **Secrets:** `SONAR_TOKEN` as an org secret scoped to `HoneyDrunkStudios`
- **Cost discipline:** the stage must only run on `pull_request` events and pushes to `main`. Not on every feature-branch push, not on tags. Budget: median PR run under 60 seconds

## Consequences

### Process Consequences

- Every agent-authored PR in the ADR-0005 / ADR-0006 Wave 1 rollout traverses this pipeline. Because the review agent is local-only (D10), the solo developer must personally invoke it via Claude Code on every agent-authored Wave 1 PR before clicking Merge. This is a self-discipline decision made in exchange for zero per-PR LLM cost — no cloud workflow is being built to enforce it.
- Packet-linking in PR bodies becomes load-bearing. The scope agent already includes packet links in its Agent Handoff output; the execution agent (ADR-0008 D8) must carry the link into the PR body. This is a minor update to the cloud execution workflow.
- The review agent's context-loading contract and the scope agent's context-loading contract are now explicitly coupled. Updates to one must be mirrored in the other; divergence is an anti-pattern.
- `pr-core.yml` usage becomes mandatory for every Grid repo that carries .NET code. ADR-0009 already mandates this for vulnerability scanning; this ADR reaffirms the mandate for the full tier-1 gate.
- SonarCloud onboarding is a new organizational task. A SonarCloud organization linked to `HoneyDrunkStudios` must be created, `SONAR_TOKEN` provisioned as an org secret, and each public repo imported. Onboarding is per-repo but the template is shared — see Follow-up Work.

### Code Review Invariants

The following invariants must be added to `constitution/invariants.md` under a new **Code Review Invariants** section, numbered 31 onwards (invariants 29–30 are reserved for ADR-0010):

31. **Every PR traverses the tier-1 gate before merge.** Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken. See ADR-0011.

32. **Agent-authored PRs must link to their packet in the PR body.** The review agent resolves the packet via this link. Absent the link, the PR is treated as out-of-band and receives a degraded review. See ADR-0011 D9.

33. **Review-agent and scope-agent context-loading contracts are coupled.** The set of files loaded by the review agent (D4) must be a superset of the set loaded by the scope agent. Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. See ADR-0011 D4.

### Follow-up Work

None of the following is part of this ADR. Each is discrete follow-up and should be scoped separately via the scope agent.

- **Wire `pr-core.yml` into every .NET repo** — follow-up for ADR-0009 that this ADR re-mandates. Already in the ADR-0009 rollout initiative.
- **Author `job-sonarcloud.yml` in `HoneyDrunk.Actions`** — reusable workflow that runs `dotnet-sonarscanner begin` / `dotnet build` / `dotnet test` / `dotnet-sonarscanner end`, publishes coverage, and reports the quality gate. Called from `pr-core.yml` tier 2 on public repos.
- **SonarCloud organization setup** — create the `honeydrunkstudios` SonarCloud organization, link it to the GitHub org, install the SonarCloud GitHub App on public repos, provision `SONAR_TOKEN` as an org secret. Portal walkthrough in `HoneyDrunk.Architecture/infrastructure/` per the "prefer portal over CLI" convention.
- **Per-repo SonarCloud onboarding** — each public repo adds a `sonar-project.properties` file, imports the project into SonarCloud, and enables the SonarCloud check in branch protection. One packet per active repo.
- **Update the cloud execution workflow to include the packet link in the PR body** — minor amendment to the ADR-0008 D8 workflow.
- **Add the `out-of-band` label to each Grid repo's label set** — trivial, automatable via a repo-setup script.
- **Amend `.claude/agents/scope.md`** to cross-reference ADR-0011 D4 (coupled context-loading contract).
- **Amend `.claude/agents/review.md`** to add the Cost Discipline section per D6 if it is not already present, and to reference ADR-0011 as the governing decision.

## Unresolved Consequences

These are known gaps in the ADR-0011 pipeline that have been identified but not yet resolved. They are tracked here so agents reading this ADR know what they cannot rely on today. The pattern mirrors ADR-0008's Unresolved Consequences block: name the gap, define the contract, flag as "slot defined, not yet built."

### Gap 1 — Integration tests (stage 6)

**Promised:** A contract-boundary integration-test stage runs between tier-1 and the LLM review tier. Tests exercise cross-Node integration points — for example, wiring a real `IAuthTokenValidator` from Auth against an `InMemorySecretStore` from Vault and a `InMemoryBroker` from Transport, and asserting the composition behaves correctly across the seam.

**Current state:** no cross-Node integration test runner exists. No dedicated integration test projects exist. The concept is on the user's radar but not formally scoped.

**Contract when built:**
- **Input:** built assemblies from stage 1, dedicated integration test projects (naming convention TBD) that compose runtime implementations from multiple Nodes against contract-compatible fakes (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue` per invariant 15) for any external seams
- **Output:** required PR check (pass/fail), test-results artifact
- **Owner:** new `job-integration-tests.yml` in `HoneyDrunk.Actions`, called from `pr-core.yml` tier 2
- **Blocking:** yes, when built

**Relationship to canary tests (invariant 14).** Canary tests are a **separate and already-existing mechanism** and must not be confused with integration tests. Canaries are small fail-fast console applications that reference the HoneyDrunk NuGet packages as consumers and exercise a smoke-test path — their job is to break loudly and immediately when a package ships in an unusable state. Integration tests exercise cross-Node *behavior* under composition; canaries exercise cross-Node *consumability*. Both validate boundary health, but at different layers and via different tooling. Neither replaces the other, and this ADR does not attempt to merge them into a single stage.

**Impact until resolved:** cross-Node composition bugs (e.g., a change to Auth's token validator that breaks when composed with Transport's message envelope) are caught only by the review agent's invariant walk and manual testing. Unit tests inside each Node cannot see the seam. Canary tests catch package-shipping regressions but not cross-Node composition regressions.

### Gap 2 — SonarCloud wiring (stage 7)

**Promised (D11):** SonarCloud runs in tier 2 on every public repo, with its quality gate as a required branch-protection check.

**Current state:** tool chosen (SonarCloud). Organization not yet created. `SONAR_TOKEN` not yet provisioned. `job-sonarcloud.yml` does not exist in `HoneyDrunk.Actions`. No repo has a `sonar-project.properties` file. No repo has the SonarCloud check in branch protection. The decision is made; the implementation is queued.

**Contract when built:** see D11 (contract already defined — no bake-off needed, only onboarding).

**Impact until resolved:** the only static analysis on PRs today is the HoneyDrunk.Standards analyzers (StyleCop + EditorConfig) that ship via `HoneyDrunk.Standards`. These catch style and simple correctness issues but do not catch duplication, security hotspots, or cognitive-complexity regressions. The review agent's architectural review partially compensates.

**Priority:** medium. Onboarding is well-understood and can be staged per-repo. No rush to land everywhere before Wave 1 — the review agent and tier-1 gates cover the urgent cases.

### Gap 3 — E2E tests (stage 10)

**Promised:** **Playwright-based** end-to-end automation tests against a deployed test environment run in tier 4 before the human gate. Scope includes browser-driven UI flows (against HoneyHub, the Studios marketing site, and any other web surfaces) and Playwright-driven API flows (against Web.Rest and other HTTP-fronted Nodes) that exercise the full deployed stack end-to-end, not just a single service in isolation. These are **true automation tests**, not smoke tests and not canaries.

**Current state:** no E2E test infrastructure exists. No test environment is deployed. No Playwright test project exists in any repo. Playwright has not been installed anywhere. This is aspirational and on the user's radar personally but not formally scoped.

**Distinction from canaries and integration tests.** Canaries (invariant 14, see Gap 1) are console-app smoke tests that verify packages are consumable. Integration tests (Gap 1) compose multiple Nodes in-process with fakes for external seams. Playwright E2E tests (this gap) run against a **deployed** stack — real Azure resources, real databases, real authentication, real network hops. They are the slowest, most expensive, and most realistic layer, and they catch a class of defects the first two layers cannot (deployment config errors, real TLS/DNS/identity misconfigurations, race conditions under real latency).

**Contract when built:**
- **Input:** deployed test environment (URL, credentials from the test environment's Key Vault), dedicated Playwright test project (TypeScript or C# binding TBD), Playwright browsers installed on the runner
- **Output:** required PR check (pass/fail) on PRs to `main`; not required on draft PRs. Playwright HTML report published as an artifact. Trace files retained for failed runs for 7 days to aid post-mortem
- **Owner:** new `job-playwright-e2e.yml` in `HoneyDrunk.Actions`, called from `pr-core.yml` tier 4 gated behind a workflow input default `false`
- **Blocking:** yes on `main`-targeting PRs, when built
- **Cost discipline:** Playwright E2E runs consume test-environment time and potentially cost money (runner minutes, Azure resource uptime, any metered services exercised). Opt-in per repo. PRs targeting release branches get the full run; PRs targeting `main` from feature branches may skip E2E at the author's discretion until the stage stabilizes. Browser binaries must be cached across runs to avoid a several-hundred-megabyte redownload on every job

**Impact until resolved:** no pre-merge validation against real Azure services (Service Bus, Key Vault, Storage, etc.). Regressions at the integration seam are caught only when someone tries the deployed environment manually. Acceptable at current scale; a gap to close before the Grid reaches real users.

### Gap 4 — Cost discipline is manual in the review agent, not tool-enforced

**Promised (D6):** the review agent walks a cost-discipline checklist on every PR.

**Current state:** the checklist is defined in `.claude/agents/review.md` (as part of this ADR's follow-up work). No automated tool measures "log volume added by this PR" or "estimated Azure SKU monthly spend" or "LLM tokens per request in the hot path." The review agent reasons about cost qualitatively from the diff.

**Contract when built (optional):** a future tool could measure cost deltas quantitatively — a `cost-impact` report generated as a PR comment from static analysis of logging statements, SKU declarations, and LLM invocations. Slot is not named as a stage in D2 because no concrete tool is planned. If one is built, it joins tier 2 alongside integration tests and SonarCloud, and is a candidate for automation (unlike the review agent itself — see D10 for why the *agent* stays local).

**Impact until resolved:** cost regressions are caught by the review agent's qualitative reasoning, which is uneven. A hot-path log statement at `Information` that fires on every request could ship unnoticed if the review agent does not flag it. The solo dev spot-checks this manually as the reviewer of last resort.

### Gap 5 — SonarCloud coverage on private repos

**Promised (D11):** private repos are not covered by SonarCloud by default; if a private repo warrants it, coverage is opt-in and recorded in a packet.

**Current state:** the set of private repos is small today (revenue / compliance / experiment exceptions from the user's default-public posture). None currently have SonarCloud coverage. The cost of SonarCloud private-tier per LOC has not been budgeted.

**Contract when adopted:** same D11 contract, with `SONAR_TOKEN` scoped to the private org's SonarCloud project and the quality gate promoted to a required check for that repo only.

**Impact until resolved:** private repos receive only tier-1 static analysis (HoneyDrunk.Standards analyzers) plus the review agent's architectural review. Quantitative metrics (cognitive complexity, duplication) are not measured on private repos. Acceptable as long as private repos remain a small exception and are primarily exercised by the solo dev rather than agents.

## Alternatives Considered

### Ad-hoc review without formalization

Let every PR find its own review convention: whatever the human remembers to check, whatever Copilot happens to comment on, whatever agent is handy. Rejected. This is the current state as of 2026-04-11, and it is exactly the drift problem ADR-0008 solved for work tracking. Without a named pipeline, the first agent-authored PR invents the convention, the tenth diverges from the first, and by the time the solo dev notices, the review gate exists in a dozen incompatible forms. The whole point of Wave 1 of ADR-0005 / ADR-0006 is that it is the first real exercise of the agent authorship flow — if that first wave ships without a named review gate, every subsequent rollout imports the drift.

### Skip the review agent; rely on Copilot review + human only

Rejected. Copilot review does not load Grid context. It does not read `constitution/invariants.md`, does not know what `boundaries.md` says for the affected Node, does not know which ADRs govern the change, and does not know what the packet was supposed to do. It can comment on style and obvious bugs. It cannot tell you the PR violates invariant 8 by logging a secret name alongside the value, because it does not know invariant 8 exists. The review agent is the only stage that can carry that context, and removing it would remove the Grid's only architecture-aware automated check.

### Defer the static analysis tool choice to a later bake-off

Rejected during the drafting of this ADR. The initial draft left the slot unfilled pending a bake-off among SonarQube (self-hosted), SonarCloud, CodeRabbit, and a custom framework. Analysis collapsed the decision cleanly: SonarCloud's public-repo tier is free, its quantitative metrics complement (not duplicate) the review agent, its .NET support is mature, and its GitHub PR decoration is native. SonarQube self-hosted fails the solo-dev operational-burden test. CodeRabbit duplicates the review agent. A custom framework has no domain justification. The bake-off produced a clear winner before running, so the slot is filled in this ADR rather than deferred — same move ADR-0008 made on decisions like D1 where the alternative list collapsed to one viable option.

### Track review state outside GitHub PR checks

Rejected. GitHub's PR surface (check runs, review comments, native review state) is the native system of record for PR state. A parallel tracker would have to reconcile with GitHub on every event, duplicate data that already exists, and introduce a second source of truth. Violates "fewer moving parts." The Project board (ADR-0008 D1) tracks packet state; the PR tracks PR state. No overlap.

### Cloud-wire the review agent for automatic per-PR runs

Rejected. The initial draft of this ADR (D10) proposed a `pr-review-agent.yml` reusable workflow in `HoneyDrunk.Actions` that would invoke the Claude Agent SDK on every `pull_request` event, checking out the PR and Architecture repo, running `.claude/agents/review.md`, and posting the verdict as a PR comment. Rejected on cost grounds after recognizing a structural overlap.

**The cost problem.** Cloud-wiring the review agent means paying the Claude Agent SDK cost on every push to every feature branch, every synchronize, every reopen. At agent-authored PR volume (Wave 1 alone is 15 packets, with additional waves to come), the recurring per-PR cost is meaningful against a solo-dev budget. Local invocation means the cost is zero at the margin — the human pays only for the invocations they actually want, and via the Claude Code subscription they already have for other work.

**The structural overlap.** A cloud-wired review agent is functionally identical in shape to CodeRabbit: an LLM-based PR reviewer that runs automatically in the cloud and posts verdicts as comments. Strictly better than CodeRabbit for HoneyDrunk (Grid-aware, no vendor markup), but the *slot* is the same. And that slot is already filled by **GitHub Copilot review**, which runs automatically on every PR and is paid for via the existing Copilot subscription. Adding the review agent as a second automatic cloud LLM reviewer on top of Copilot is exactly the duplication D11 rejected CodeRabbit for.

**The resolution.** Treat Copilot as the automatic LLM reviewer (the "CodeRabbit slot"). Treat the review agent as the *deeper Grid-aware reviewer the human reaches for on demand* — a complementary role that does not belong on the automatic cloud path. The two reviewers are differentiated by trigger model (automatic-cloud vs. manual-local) rather than by scope, and the differentiation is load-bearing for cost discipline.

**Residual risk accepted.** A distracted solo developer may merge a PR without invoking the review agent. This is a behavioral risk, not a technical one. Copilot still runs, tier-1 gates still run, the review agent's unique Grid-awareness is what gets skipped. Accepted in exchange for zero recurring cost. See D10 for the full rationale.

### Make the review agent a required check that physically blocks merge

Rejected. Advisory posture (D5) is the correct call for a solo-dev, cost-sensitive Grid where the agent runtime is a third-party service with non-zero cost per invocation. Required-check posture would (a) strand merges during Claude Agent SDK outages, (b) force a full context load on every trivial PR, (c) bake a specific agent runtime into branch protection rules which then become a migration hazard if the runtime changes, and (d) break symmetry with `refine`, which is advisory on the scoping side. The human solo dev is the reviewer of last resort; the review agent is expert advice the human reads before clicking Merge.

### A single reusable "full-pipeline" workflow instead of tiered jobs

Rejected. `pr-core.yml` already exists and is already tiered internally (build-and-test, static-analysis, secret-scan, pr-summary run as parallel jobs with dependencies). The tier model from D2 maps onto GitHub Actions job dependencies naturally. A monolithic workflow would lose the parallelism within a tier and lose the ability to short-circuit on tier-1 failures without paying for tier-2.

### Blocking cost discipline via a dedicated tool

Rejected for now. No mature tool measures "log volume added by this PR" or "estimated monthly Azure spend delta" well enough to be reliable. Attempting to build one is out of scope. The review agent's qualitative cost-discipline checklist (D6) is cheaper to operate and catches the common cases (new log statement in a request handler, new Azure resource without SKU justification, new LLM call without a budget). Named as a gap (Unresolved Consequences gap 5) so it is trackable as a future tool slot if a good option emerges.

### Enabling SonarCloud on private repos by default

Rejected for now. SonarCloud's private-tier pricing is per line of code and adds real recurring cost. The set of private repos in the Grid is small (revenue / compliance / experiment exceptions only) and is primarily exercised by the solo dev rather than by agents, so the drift risk that justifies SonarCloud on public repos is lower on private ones. Default-opt-out with a per-repo opt-in path (recorded as a packet) matches the solo-dev cost discipline posture. See Gap 6.
