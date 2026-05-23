# ADR-0053: Environments, Branching, and Release Cadence

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / cross-cutting

## Context

The Grid has 12 Live Nodes, 13 Seed Nodes, an active Notify/Pulse Azure Container Apps rollout (ADR-0015), env-gated deploys (ADR-0033), code-review and PR-validation policies (ADR-0011, ADR-0032), and an AI-PR-discipline ADR (ADR-0044) — yet **no ADR defines what environments exist, what branches look like, or how often things ship.** The decision surface that all of those other ADRs presume has never been recorded.

The gaps today:

- **ADR-0033 (env-gated deploys)** binds tag → environment mapping (`staging-*` deploys to staging, `prod-*` deploys to prod) but the environments themselves are not named, not characterized, and not committed. The "what is staging" question is implicit. The "is there a dev environment" question is unanswered.
- **ADR-0015 (Container Apps rollout)** assumes multi-revision deploy targets and traffic-shift rollbacks — but does not say whether the deploy target is dev, staging, prod, or all three, and does not address per-PR ephemeral environments at all.
- **ADR-0011 (code review)** and **ADR-0032 (PR validation)** describe what happens at the PR boundary but presume a branching model (long-lived `main`, short-lived feature branches, or GitFlow-style `develop`/`release/*` channels) that no ADR has actually committed.
- **ADR-0044 (AI-PR discipline)** governs `codex/` and `copilot/`-prefixed branches but the prefix convention itself, and how `claude/{agent-slug}` branches fit, are de-facto practice without a written rule.
- **Notify.Functions / Notify.Worker / Pulse.Collector Azure bring-up** is the current top blocker per `initiatives/current-focus.md`. Landing this ADR unblocks the deployment topology those Nodes need: which environments they target, how revisions promote, and what the rollback story looks like.
- **One-developer-plus-agents has unique constraints** that off-the-shelf branching models do not account for:
  - PR review is **asynchronous between you and Codex**, not between two humans on the same calendar. Codex authors a PR, the developer reviews when next at the keyboard. Latency between author-and-reviewer can be hours or a day.
  - **Long-lived branches** are a worse cost than for a team because review feedback loops are slower; a feature branch that goes stale produces drift the AI author cannot resolve without re-opening the work.
  - **AI-authored branches** dominate the PR mix; the cost of branch sprawl falls on the human reviewer as cognitive load, not on a CI queue.

This ADR commits the environment topology, branching model, branch-naming convention, branch-lifetime expectations, merge strategy, promotion model, release cadence, local-dev parity expectations, configuration parity rules, data parity rules, rollback story, and approval policy. It closes the load-bearing gap behind ADRs 0011 / 0015 / 0032 / 0033 / 0044 and unblocks the Notify/Pulse Azure rollout.

## Decision

### D1 — Environment topology: three environments (dev, staging, prod)

The Grid commits to **three always-on environments**:

| Environment | Purpose | Source of truth | Data shape | Audience |
|---|---|---|---|---|
| **`dev`** | Latest `main`; integration sandbox for the developer and agents | Auto-deployed from `main` on every merge | Seed data only; safe to wipe | Developer + agents only |
| **`staging`** | Prod-equivalent configuration and infrastructure shape; final pre-prod soak | Manual deploy via `staging-{date}` tag (per ADR-0033) | Synthetic fixtures; volume-realistic where load matters | Developer + Notify.Cloud customer dry-runs (when GA per PDR-0002) |
| **`prod`** | The live Grid | Manual deploy via `prod-{date}` tag (per ADR-0033) | Real customer data; PII-bearing | Customers; the operator |

**No per-PR ephemerals in v1.** Per-PR ephemeral environments (a fresh Azure resource group per pull request) are a real ergonomic win for visual-review-heavy work, but they carry meaningful cost and meaningful Bicep/Pulumi-template complexity. At the current Grid volume (one developer, AI agents authoring most PRs, branch lifetimes targeted at < 5 working days per D6), the `dev` environment is sufficient. **Discussed as v2** when either (a) Notify Cloud's tenant onboarding flow needs reviewer-visible URL-per-PR previews, or (b) multiple humans are reviewing in parallel.

**Three environments — not two and not four.** Two (dev + prod) skips the prod-equivalent soak step and forces dry-runs to happen on customer-facing infrastructure. Four (dev + staging + qa + prod) reintroduces the GitFlow-era ceremony this ADR is explicitly rejecting. Three is the smallest topology that gives a real soak step without ritual overhead.

### D2 — Resource-group and naming convention

Azure resource groups and resources follow a deterministic naming scheme so the operator can predict any resource's name without lookup:

- **Resource groups:** `rg-honeydrunk-{env}-{region}` (e.g., `rg-honeydrunk-prod-eastus`, `rg-honeydrunk-staging-eastus`, `rg-honeydrunk-dev-eastus`).
- **Resources within a group:** `{node}-{env}-{purpose}` (e.g., `notify-functions-prod-eastus`, `notify-worker-staging-eastus`, `pulse-collector-dev-eastus`).
- **Storage accounts and other globally-unique-name resources:** `hd{node}{env}{region}{shortrand}` (no dashes, ≤24 chars per Azure rules; `shortrand` is a 4-char hash of the resource-group ID so two regions cannot collide).
- **Key Vaults (per ADR-0005):** `kv-{node}-{env}-{region}` (e.g., `kv-notify-prod-eastus`), one Key Vault per Node per environment.

This aligns with ADR-0033's deploy-trigger expectations and makes the deploy workflows trivially parameterizable: substitute `{env}` and the workflow targets the right resource group.

**Region default:** `eastus` for all v1 environments. Multi-region is a follow-up gated on the ADR-0036 DR pattern; v1 is single-region by design.

### D3 — Subscription split: single subscription with environment-level RBAC at v1

Azure billing and isolation can be split at the **tenant**, **subscription**, **resource-group**, or **resource-tag** level. The blast-radius and cost-attribution trade-offs differ by level.

**v1 commitment: single Azure subscription, environment-level RBAC.** All three environments live in one subscription; `rg-honeydrunk-prod-*` resource groups have a narrower RBAC (`Owner` = operator only; `Contributor` = the deploy workflow's managed identity scoped to that RG). Non-prod resource groups are looser (`Contributor` includes development tooling).

**v2 commitment (deferred): subscription split when the first paying tenant arrives.** When PDR-0002 / ADR-0050 lands Notify Cloud's first paying tenant, production moves to a dedicated subscription (`sub-honeydrunk-prod`); non-production stays on the current subscription (`sub-honeydrunk-nonprod`). The split delivers true blast-radius isolation (a runaway non-prod resource cannot eat into prod's quota or be billed against prod's cost center), cleaner cost attribution (per-environment invoices), and cleaner RBAC (cross-environment privilege escalation requires cross-subscription action). The cost is template duplication and the one-time data migration.

**Why not v1 split:** The operational overhead of cross-subscription deploys, cross-subscription DNS, and cross-subscription private-link wiring is non-trivial. At one developer with no paying tenants, the blast-radius benefit is theoretical. Pay the split cost when the benefit becomes concrete.

### D4 — Branching model: trunk-based with short-lived feature branches

**`main` is always deployable.** Every merge to `main` produces an artifact that auto-deploys to `dev` (per D8). `main` is the single long-lived branch; there is no `develop` channel, no `release/*` channel as a permanent target, no `hotfix` channel as a permanent target.

**Feature branches are short-lived.** A feature branch exists from open-PR to merge-to-main; it does not become a long-lived shared branch. The target lifetime is < 5 working days (D6).

**No GitFlow.** GitFlow's `develop`/`release/*`/`hotfix/*`/`feature/*` channel split optimizes for **scheduled release trains across multiple parallel developers**. The Grid has neither parallel developers (one operator) nor scheduled release trains (D9). The GitFlow ceremony cost — merge-back-to-develop after a release, hotfix sync across branches, the integration-merge cadence — produces friction without delivering value at this scale.

**Release branches optional, only for hotfix isolation.** A `release/{node}-{semver}` branch is permitted when an emergency hotfix must ship without bringing the current `main` along (rare, named here for completeness). The branch is short-lived, created off the prod tag, the fix merges in, the tag is cut, then the branch is deleted within 7 days. Day-to-day work does not use release branches.

### D5 — Branch naming convention

All branches follow `{type}/{ticket-or-slug}`. The `{type}` prefix carries the author and the change kind:

**Human-authored branches** (typed by the operator in-IDE):

| Prefix | Purpose | Example |
|---|---|---|
| `feat/` | New feature work | `feat/notify-cloud-tenant-portal` |
| `fix/` | Bug fix | `fix/idempotency-window-off-by-one` |
| `chore/` | Tooling, dependencies, non-functional changes | `chore/upgrade-kernel-0.8.0` |
| `docs/` | Documentation-only changes | `docs/adr-0048-expand-contract` |
| `refactor/` | Internal restructure with no behavior change | `refactor/audit-store-extraction` |

**AI-authored branches** (per ADR-0044 D2's authorship-disclosure rule):

| Prefix | Author | Example |
|---|---|---|
| `codex/` | OpenAI Codex (via the cloud execution surface) | `codex/notify-functions-otlp-wiring` |
| `copilot/` | GitHub Copilot in-IDE | `copilot/pulse-collector-canary` |
| `claude/{agent-slug}-{token}` | Specialist Claude agent (already in use) | `claude/adr-review-dFtgC` |

The `claude/{agent-slug}-{token}` shape mirrors what `.claude/agents/*` actually emits today and is codified here so future specialist agents do not invent their own conventions.

**Branch name discipline matters because:**

- The PR-validation policy (ADR-0032) and the AI-PR discipline ADR (ADR-0044) inspect the branch prefix to route the appropriate review checklist.
- The CI workflow filters in HoneyDrunk.Actions (per ADR-0012) can fan out different jobs by prefix (e.g., AI-authored branches may run additional review canaries).
- The operator's mental model — "is this PR Codex's work or mine?" — is preserved at a glance, every time.

### D6 — Branch lifetime: 5-day target, 7-day stale, 30-day auto-close

- **Target:** Feature branches merge within **5 working days** of first commit.
- **Stale alert:** A PR with no commits in **7 days** is flagged stale by an Actions workflow (a comment on the PR; no automatic closure at this stage).
- **Auto-close:** A branch with no PR activity in **30 days** is auto-closed by an Actions workflow unless tagged `flagged-keep-open`. The branch is deleted; the work can re-open under a new branch.

**The forcing function:** AI-authored PRs are bottlenecked on the human reviewer. The longer the queue grows, the harder it is to reason about which PR depends on which; the more drift accumulates between feature branches and `main`; the more rework Codex has to do on stale work. The 5-day target is a flow-control mechanism: it pressures the queue toward small, focused PRs that the reviewer can pick up quickly. The 30-day auto-close prevents zombie branches from cluttering the branch list permanently.

**This is more aggressive than typical team conventions.** A 5-person team can absorb 2-week-lived feature branches because review capacity scales with team size. A one-developer-plus-agents shop has fixed human-review capacity; the only flow-control lever is branch lifetime. Set it short on purpose.

### D7 — Merge strategy: squash by default, merge commits for release branches

- **Squash merge to `main` for feature work.** One PR = one commit on `main`. The PR title becomes the squash-commit message (and is conventional-commits-shaped per ADR-0044 D4). The PR description becomes the commit body. `main` history is a clean sequence of feature/fix/chore commits, one per PR, in merge order.
- **Merge commit for release branches.** When a `release/{node}-{semver}` branch (per D4) merges back to `main` after a hotfix, use a non-squash merge so the hotfix history is preserved (the operator can `git log --first-parent` the release branch and see the actual fix commits). Squash on a hotfix branch would discard the audit trail the hotfix was created to produce.
- **Never rebase-merge.** Rebase-merge rewrites SHAs on `main` and breaks any external reference (Codex's branch checkpoints, CI artifact SHAs, the operator's git-blame links). Squash-merge produces a new SHA at the squash point but does not rewrite history.

The squash convention pairs naturally with ADR-0044's commit-message standards: one conventional commit per merged PR, perfectly traceable to the PR that authored it.

### D8 — Promotion model: main → dev → staging → prod

Each promotion step is explicit about who triggers it and what artifact moves:

| Promotion | Trigger | Mechanism | Approval |
|---|---|---|---|
| `main` → `dev` | Automatic on every merge | The build artifact (container image, NuGet package, etc.) deploys to `dev`'s Azure resources via the HoneyDrunk.Actions reusable workflow | None; merge is the approval |
| `dev` → `staging` | Manual; operator pushes `staging-{date}` tag on the same commit (per ADR-0033) | The tag triggers the staging deploy workflow; same artifact (no rebuild) promotes to `staging` | Tag push = approval; CI must be green |
| `staging` → `prod` | Manual; operator pushes `prod-{date}` tag after staging soak | The tag triggers the prod deploy workflow; same artifact promotes to `prod` | Tag push + D15 self-approval comment on the deploy PR; CI must be green |

**Key properties:**

- **Same artifact promotes through all environments.** Build once at merge-to-main; the same container image / NuGet package / function-app zip moves through `dev` → `staging` → `prod`. Per ADR-0015's multi-revision strategy, Container Apps holds the prior revision and traffic-shifts forward; rollback is a traffic-shift back to the prior revision (D14).
- **Staging soak is a real step, not a formality.** Default soak window is **24 hours** for normal releases; **4 hours** for hotfixes; **72 hours** for changes that include schema migrations (per ADR-0048's expand/contract phasing). The soak window is recorded in the deploy PR's body.
- **The tag is the audit trail.** `prod-2026-05-22-1430` is the canonical reference for "what's currently in prod"; the tag points at the merged commit, which traces to the PR, which traces to the artifact SHA. ADR-0033's audit log builds on this.

### D9 — Release cadence: per-Node, release-as-needed (no fixed calendar)

**No fixed release train.** A weekly or bi-weekly release train adds calendar ceremony (cut date, release branch, release notes assembly, etc.) without delivering value at the Studio's scale. Studios is small enough that the marginal cost of a release is mostly tooling, not coordination; pay the tooling cost once (per the deploy workflows) and the per-release cost drops to near-zero.

**Soft target: monthly cadence per Live Node.** Every Live Node ships **at least one prod release per calendar month** OR an explicit "no changes this month" entry in the Node's CHANGELOG.md. The "no changes" entry is load-bearing: it makes inactivity visible. A Live Node that goes silent for three months without a "no changes" entry is a Grid-health-aggregator (ADR-0012) alert.

**Hotfix discipline:**

- **Hotfix tag format:** `prod-{date}-hotfix-{short-slug}` (e.g., `prod-2026-05-22-hotfix-idempotency-leak`).
- **Hotfix path:** Either (a) `main` is currently clean and the fix can ship from `main` (preferred), or (b) `main` is mid-feature and the fix ships from a `release/{node}-{prior-semver}` branch (D4).
- **Hotfix soak:** Reduced from 24h to 4h per D8, but never zero. Even hotfixes get a staging step; "ship straight to prod" is not in this ADR.

**The cadence reflects the team shape.** A calendar-bound release train is for coordinating multiple humans against a market expectation (e.g., enterprise SaaS with quarterly feature drops). HoneyDrunk has no such expectation; releases happen when work is done.

### D10 — Versioning: SemVer per Node, conventional commits, release notes deferred

- **SemVer per Node**, per ADR-0035 (NuGet/versioning). Major/minor/patch semantics apply at the Node level; library packages and deployable packages versioned independently per Node.
- **Conventional commits** per CLAUDE.md and ADR-0044 D4. The squash-merge convention (D7) means every commit on `main` is a conventional commit.
- **Release notes generation deferred.** A script that reads conventional-commit messages between two tags and produces a CHANGELOG.md entry is desirable; it is not committed in this ADR (the scope is a separate tooling decision). Until the script exists, CHANGELOG.md entries are authored by the developer at release time. The conventional-commits discipline (D7 + ADR-0044) means the manual authoring is mechanical, not creative.
- **Tag → SemVer mapping:** Tags on `main` of the form `{node}-v{semver}` (e.g., `notify-v0.4.0`) trigger the NuGet publish workflow per ADR-0034. The `staging-{date}` and `prod-{date}` tags (D8) are for deploys, not version cuts; they are orthogonal.

### D11 — Local-dev parity: `dotnet run` against Testcontainers or InMemory

**Every Node must boot locally with `dotnet run`** against either (a) the InMemory contract-compatible fakes per Invariant 15, or (b) the Testcontainers-driven Tier 2b dependencies per ADR-0047 D4. **No Azure dependency is required for first-line development work.**

The forcing function: the **first 60 seconds** of trying a Node must be `git clone && dotnet run`. If the operator must provision an Azure Key Vault, an Application Insights resource, and a Service Bus namespace before seeing the Node boot, the Node's onboarding cost is so high that contributions (human or agent) stall.

**Vault bootstrap uses ADR-0005's env-var path.** Local secrets come from `.env` files (gitignored) loaded into environment variables; `HoneyDrunk.Vault` reads from env vars when configured for the `local` profile. No real Key Vault is required to boot a Node locally.

**The "first 60 seconds" experience is documented per Node in `repos/{name}/overview.md`.** A `## Quick Start` section with: clone command, prerequisites (Docker for Testcontainers, .NET SDK version), boot command, expected log lines. If a Node cannot meet the 60-second target, the gap is recorded as a follow-up.

This parity-with-local property is what makes ADR-0047 D1's Tier 1 and Tier 2a unit/integration tests possible at all — if the Node could not boot without Azure, those tests could not run on a CI machine without Azure credentials either.

### D12 — Configuration parity: App Configuration per ADR-0005, no hardcoded env strings

- **Environment-specific configuration lives in Azure App Configuration** (per ADR-0005), keyed by environment label.
- **Secrets** live in Key Vault (per ADR-0005), referenced from App Configuration via Key Vault references.
- **Diffs between environments** are surfaceable via the Operator CLI (the future `hd config diff dev staging` command); the human can audit what differs without manually clicking through the Azure portal.
- **Hardcoded environment strings in code are forbidden.** No `if (Environment == "prod") { ... }` switches in business logic. If behavior must differ by environment, it differs via configuration injected at startup, not via runtime environment-checking. The exception: deployment workflows (HoneyDrunk.Actions) and bootstrap shims (which read the environment label to choose the App Configuration endpoint) are explicitly allowed to check environment.

The discipline matters because configuration-driven behavior is testable; environment-name-switched behavior is only testable in the named environment. The latter pattern is how subtle "works in staging, breaks in prod" bugs are born.

### D13 — Data parity: production data MUST NEVER copy to dev or staging

**Hard rule, no exceptions:** Production data MUST NEVER be copied to `dev` or `staging`. Not anonymized; not subsetted; not for "debugging a one-off"; never.

- **`dev` data:** Seed data generated by the Node's `seed` command (per Node convention) or by integration-test fixtures. Wiped freely.
- **`staging` data:** Synthetic fixtures generated by per-Node seeders. Realistic in shape and volume (where load matters); never sourced from real customer records.
- **`prod` data:** Real customer data. PII-bearing. Subject to ADR-0049's classification rules.

**Why no exception:** Production data carries PII, regulatory obligation, and contract-bound restrictions on use. Copying it to `dev` (where it would sit in a permissive RBAC environment, accessible to development tooling and to AI agents) is a data-classification violation per ADR-0049. The "anonymization is enough" claim is repeatedly proven false in industry (re-identification attacks on supposedly anonymous datasets are routine); the Studio takes the operational cost of synthetic data rather than the legal-and-trust cost of leaking real data into lower environments.

**Synthetic-fixture quality is a real cost.** A staging environment with weak fixtures cannot catch volume-sensitive bugs (a query that is fast on 10 rows and slow on 1M rows; an index that helps on uniform data and hurts on skewed data). The Studio pays this cost by investing in volume-realistic synthetic generators (Bogus per ADR-0047 D7 for shape; AutoFixture for volume) rather than by importing real data.

**Cross-ref ADR-0049 (PII handling) and ADR-0030 (audit substrate).** Any tooling that attempts to copy prod data to a lower environment is itself an Audit-emitting event (an attempt to violate the rule); the audit trail catches accidental violations.

### D14 — Rollback story: traffic-shift instant rollback; schema rollback forward-only

**For application code:** Per ADR-0015's multi-revision Container Apps strategy, rollback is an instant traffic-shift back to the prior revision. The prior revision is retained for 7 days by default; the operator can shift traffic back at any time during that window. The mechanism is `az containerapp revision set-traffic` with the prior revision's name; rollback completes in < 60 seconds.

**For library packages (NuGet):** Per ADR-0035, a published package version is **immutable**. Rollback means publishing a higher-versioned patch that reverts the offending change (a `0.4.1` that undoes `0.4.0`'s breakage). The package is never yanked; the version history is append-only.

**For schema changes:** Per ADR-0048's expand/contract pattern, **rollbacks are forward-only after the contract phase begins**. The expand-phase writes are reversible (the old schema still works); the contract-phase writes are not (the old schema is dropped). The implication for this ADR:

- During the expand phase, code can be rolled back via traffic-shift; the new schema is still compatible with the prior code.
- During the contract phase, code cannot be rolled back via traffic-shift; the prior code does not understand the new schema. A failure during contract requires a forward-fix (a new release that re-expands or completes the migration), not a rollback.
- This implies the **soak window for contract-phase releases is the 72-hour version per D8**, because the rollback safety net is gone for that release.

The operator must know which phase any given release is in. The deploy PR's body records the schema-change phase explicitly; the operator decides the soak window accordingly.

### D15 — Approvals: passing CI + self-approval comment at v1; two-party gate at v2

**v1 approval rules:**

- **`dev` deploy:** None. The merge to `main` is the approval; auto-deploy follows.
- **`staging` deploy:** A passing CI run on the tagged commit. Tag push is the approval.
- **`prod` deploy:** A passing CI run on the tagged commit AND a self-approval comment on the deploy PR. The comment is the human checkpoint: the operator explicitly says "yes, this is ready for prod" before the deploy workflow proceeds.

The self-approval comment is **not** ceremony — it is a friction-by-design step. The operator must read the deploy PR's body (which records the soak window, the schema-change phase, the rollback path) and explicitly acknowledge it. The cost is 30 seconds per prod deploy; the value is preventing absent-minded `prod-{date}` tag pushes that bypass conscious review.

**v2 approval rules (when a second human joins):** The self-approval comment becomes a true two-party gate. A different human's approval is required for the prod deploy; self-approval by the deploy PR's author is no longer sufficient. This is the standard SOC2-flavored separation-of-duties pattern; it is not yet relevant because there is only one human, but the path forward is recorded so the v2 transition is mechanical, not a re-design.

**AI agents are not approvers.** A Codex-authored deploy PR cannot self-approve. The human operator is the only valid approver at v1; the v2 transition does not change that — the second human is the second approver, not the AI agent.

### D16 — Phased rollout

- **Phase 1 (Week 1) — Codify the environments.** Author `infra/{env}/` Bicep modules for `dev`, `staging`, `prod` following the D2 naming convention. Single subscription per D3 v1.
- **Phase 2 (Week 1–2) — Update HoneyDrunk.Actions reusable workflows.** The `job-deploy.yml` workflow accepts an `environment` input; the tag → environment mapping (per ADR-0033) is encoded in the calling workflow. Self-approval gate (D15) wires into the prod path.
- **Phase 3 (Week 2) — Notify/Pulse Azure bring-up uses the new pattern.** The currently-blocked Notify.Functions / Notify.Worker / Pulse.Collector deploys (per `initiatives/current-focus.md`) are the first deploys against this topology.
- **Phase 4 (Week 3) — Branch-lifetime tooling.** Stale-PR alert workflow (D6); auto-close-after-30-days workflow (D6); branch-prefix validation in CI (D5).
- **Phase 5 (Week 3–4) — Local-dev parity audit.** Every Live Node's `repos/{name}/overview.md` gets a `## Quick Start` section per D11. Any Node that cannot meet the 60-second target gets a follow-up packet.
- **Phase 6 (Month 2) — CHANGELOG cadence enforcement.** A monthly Actions workflow checks every Live Node for either a prod deploy in the past 30 days or a "no changes" CHANGELOG entry; missing entries become Grid-health-aggregator alerts (per ADR-0012).
- **Phase 7 (When first paying tenant lands)** — Execute D3 v2 subscription split.

Each phase is a discrete go/no-go.

## Consequences

### Affected Nodes

- **HoneyDrunk.Actions** — reusable deploy workflows updated per Phase 2; stale-PR and auto-close workflows added per Phase 4; branch-prefix validation added per Phase 4.
- **HoneyDrunk.Notify, HoneyDrunk.Notify.Functions, HoneyDrunk.Notify.Worker** — the in-flight Azure bring-up consumes the new topology (Phase 3); CHANGELOG.md cadence per D9.
- **HoneyDrunk.Pulse, HoneyDrunk.Pulse.Collector** — same as Notify (Phase 3).
- **HoneyDrunk.Vault** — local-dev env-var path (per ADR-0005) is the documented bootstrap for D11.
- **Every Live Node** — `repos/{name}/overview.md` gains a `## Quick Start` section per D11; CHANGELOG.md cadence per D9.
- **HoneyDrunk.Architecture** — `constitution/sectors.md` references the three environments; `catalogs/services.json` gains an `environments: [dev, staging, prod]` field per service; `routing/execution-rules.md` references the branch-naming convention per D5.
- **HoneyDrunk.Audit** — D13's attempted-violation events emit through Audit (per ADR-0030); the "someone tried to copy prod to dev" event is high-signal.
- **HoneyDrunk.Operator (Seed)** — when scaffolded, gets the `hd config diff {env1} {env2}` command per D12.
- **All AI-sector Seed Nodes** (per ADR-0016–0025) — consume the topology from day one of standup; their standup ADRs reference this ADR for the deploy target.

### Invariants

Adds three:

- **Invariant: production data MUST NEVER copy to `dev` or `staging`.** Synthetic fixtures only in lower environments; real data only in `prod`. Cross-ref ADR-0049.
- **Invariant: every Node boots locally with `dotnet run` against InMemory or Testcontainers dependencies; no Azure dependency is required for first-line dev work.** First-60-seconds rule documented per Node.
- **Invariant: hardcoded environment-name switches in business logic are forbidden.** Environment-dependent behavior is configuration-driven, not name-driven. Exception: deployment workflows and bootstrap shims.

(Final invariant numbering assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **Three environments cost real money.** `dev` and `staging` each consume Azure resources; the line-item per environment is meaningful even at low load. The cost is named here and acknowledged as a cost-of-doing-business item; ADR-0040's $100/month observability ceiling does not include the environment-baseline cost (compute, storage, networking).
- **Phase 3 unblocks the Notify/Pulse Azure bring-up.** The Notify.Functions / Notify.Worker / Pulse.Collector deploys that have been blocked in `current-focus.md` get a concrete target topology to deploy against.
- **Branch-lifetime discipline produces friction.** The 5-day target and 7-day stale alert will pressure work-in-progress to wrap up faster. This is the intent. Branches flagged stale may need to be closed and re-opened with smaller scope; the cost is recognized.
- **The "first 60 seconds" audit will surface Nodes that don't meet it.** Phase 5's audit is expected to find at least 2–3 Nodes that need work to hit the target. Those gaps become packets; they are not blockers for the rest of this ADR's rollout.
- **Self-approval is friction, not gate.** The v1 self-approval comment per D15 is intentionally not a hard gate (the operator could deploy without commenting if the tag push wasn't gated by the comment). The friction is the value; the v2 transition to a true two-party gate is when the gate becomes load-bearing.
- **Schema rollback is harder than code rollback.** D14 documents this explicitly; the operator must internalize the expand/contract phasing per ADR-0048 to deploy schema changes safely. The deploy PR body's "schema-change phase" field is the operational checkpoint.
- **Synthetic-fixture investment is real.** D13's no-prod-data-in-lower-envs rule shifts cost to building better fixture generators. The Studio accepts this trade-off; the Bogus + AutoFixture toolchain per ADR-0047 D7 is the substrate.
- **The CHANGELOG cadence catches dormant Nodes.** A Live Node that goes three months without a prod deploy or a "no changes" entry surfaces as a grid-health alert per Phase 6; the operator either ships the Node or demotes its Live status.

### Follow-up Work

- Author `infra/{env}/` Bicep modules for `dev`, `staging`, `prod` (Phase 1).
- Update HoneyDrunk.Actions deploy workflows with `environment` parameter and self-approval gate (Phase 2).
- Notify.Functions / Notify.Worker / Pulse.Collector Azure bring-up using the new topology (Phase 3).
- Stale-PR alert workflow + auto-close-after-30-days workflow + branch-prefix validation (Phase 4).
- `## Quick Start` section per Node `overview.md` and remediation packets for Nodes that miss the 60-second target (Phase 5).
- Monthly CHANGELOG cadence enforcement workflow (Phase 6).
- Subscription split when the first paying tenant lands (Phase 7).
- `hd config diff {env1} {env2}` command on HoneyDrunk.Operator (when scaffolded).
- Release-notes generation script (deferred per D10).
- Schema-change-phase field added to the deploy PR template (per D14).
- Update `constitution/invariants.md` with the three new invariants.
- Update `catalogs/services.json` schema with an `environments` field.
- Document per-Node environment-baseline cost in `business/context/` for cost-awareness.

## Alternatives Considered

### GitFlow (long-lived `develop`, `release/*`, `hotfix/*`, `feature/*`)

Considered as the most-recognized off-the-shelf branching model. Rejected as overhead-heavy for the team size:

- GitFlow optimizes for **scheduled releases with multiple developers**. The Studio has neither.
- The merge-back-to-develop step after each release, the hotfix sync across branches, and the integration-merge cadence are coordination tools — but there is nothing to coordinate (one developer).
- The cognitive cost of "which branch should this fix target" is real and recurring; trunk-based makes it trivial (target `main`, always).
- GitFlow's release-branch model presumes the release is a multi-week effort with parallel feature work continuing on develop. The Studio's release model (D9) is per-Node, on-demand; the GitFlow shape doesn't fit the cadence.

GitFlow's hotfix model is partially preserved in D4's release-branch carve-out — hotfix isolation when `main` is mid-feature is a real need — but the full GitFlow ceremony is rejected.

### Release-train weekly cadence

Considered. The argument for: forcing function for shipping, predictable customer expectations, easier release-note authoring. Rejected:

- **Adds cadence ceremony where flow works better.** A weekly release train means cutting a release branch, deciding what's in and out, doing release notes, even when nothing meaningful changed that week.
- **Studios has no external cadence expectation.** Customers (when they exist per PDR-0002) expect Notify Cloud to work; they do not expect a Tuesday release schedule.
- **Per-Node release-as-needed (D9) is more honest.** Some Nodes will release weekly; some will release monthly; some will go a quarter without changes. Forcing them all to the same cadence produces fake activity.

### Per-PR ephemeral environments at v1

Considered. Strong product (reviewer can see a live URL per PR). Rejected:

- **Cost.** Each ephemeral environment provisions a resource group's worth of Azure resources; at the AI-PR volume this ADR anticipates (per ADR-0044), the resource-group churn is non-trivial.
- **Bicep/Pulumi template complexity.** Per-PR provisioning requires fully parameterized templates with deterministic teardown; the current Bicep modules are not built for this.
- **Reviewer value is limited at v1.** Most PRs are code review, not visual review; a deployed URL doesn't materially help review .NET refactor PRs. The PRs that *would* benefit (Notify Cloud tenant-portal UI work) are far enough in the future that v2 is the right time.

Recorded for v2 reconsideration when Notify Cloud's tenant-portal UI work begins.

### Single environment (dev = prod)

Considered as the maximally-minimal topology. Rejected:

- **No prod-equivalent soak step.** Changes go from `main` straight to customer-facing infrastructure; the operator never sees the change running with prod-like config before customers do.
- **Data parity rule (D13) becomes meaningless.** A single environment is prod; there is no lower env to protect from prod data.
- **Hotfixes have no testing surface.** Even a 4-hour hotfix soak (D9) needs an environment to soak in.

The cost saved by collapsing to a single environment is small (one resource group's worth); the cost of missing a regression in front of customers is large. Three-environment topology is the right floor.

### Four environments (dev + staging + qa + prod)

Considered. A separate `qa` environment between `dev` and `staging` is a common pattern. Rejected:

- **No QA team to use it.** The classical `qa` environment exists for a QA function to run scripted test suites against; the Studio has no such function (automated tests run against `dev` per ADR-0047 D5).
- **Redundant with `staging`.** `staging`'s prod-equivalent config and soak step are already the "is this ready for prod" surface; a separate `qa` would either duplicate that or sit unused.

Four environments is a team-shape decision, not a Grid-shape decision; the Studio's team shape doesn't justify the fourth.

### Subscription split at v1 (full prod isolation immediately)

Considered. Strong blast-radius story. Rejected as v1:

- **Operational overhead.** Cross-subscription deploys, cross-subscription DNS, cross-subscription private-link wiring all add real complexity.
- **No paying tenant yet.** The blast-radius benefit is theoretical until there's customer data to protect at a higher tier.
- **Cost attribution doesn't matter yet.** A single subscription's invoice is the operator's invoice; there's no second team to bill against.

Recorded as v2 (D3); the trigger is "first paying tenant arrives." When that trigger fires, the split is mechanical.

### Rebase-merge instead of squash-merge

Considered. Some teams prefer rebase-merge for preserving granular commit history. Rejected:

- **SHA rewriting breaks external references.** Codex's branch checkpoints, CI artifact SHAs, the operator's git-blame links all reference commit SHAs; rebase-merge changes them.
- **AI authorship attribution is harder.** A squashed commit cleanly attributes a PR to its author (Codex, Copilot, or human). A rebased series spreads the attribution across multiple commits.
- **Conventional-commits discipline is per-PR, not per-commit.** ADR-0044 D4 binds the PR-level commit message to conventional-commits format; squash-merge preserves that without forcing each in-progress commit to also be conventional.

Squash-merge is the right default for trunk-based + AI-authored + conventional-commits combined.

### Allow long-lived feature branches (no 30-day auto-close)

Considered. The 30-day auto-close is aggressive; some PRs legitimately take longer to land (e.g., the Kernel Adoption Alignment initiative spanned weeks). Rejected as default:

- **Zombie branches are the real risk.** A branch that has been stale for 30+ days is almost always either abandoned work, AI-authored experiments that didn't pan out, or work superseded by a different PR. Auto-closing them clears the branch list without lost work (the commits remain reachable via reflog and re-openable as a new branch).
- **The `flagged-keep-open` escape hatch handles legitimate long-running work.** A PR that legitimately needs > 30 days gets the tag; auto-close skips it. The friction is intentional — keeping a branch alive past 30 days requires an explicit decision.

The 30-day window is calibrated for the AI-PR volume per ADR-0044; if AI authorship rate changes meaningfully, the window can be re-tuned.

### Defer this ADR until Notify Cloud GA forces it

Rejected. The Notify/Pulse Azure bring-up is **already blocked** in `current-focus.md` on the missing environment topology; deferring this ADR keeps the block in place. Notify Cloud GA is even further out; tying this decision to GA postpones a current blocker by months. Land now, refine later.

### Skip per-Node CHANGELOG cadence (just track ADR-driven changes)

Rejected. The CHANGELOG cadence per D9 is the visibility mechanism for dormant Nodes; without it, a Live Node can go silent for a quarter without anyone noticing. ADR-driven changes track cross-cutting decisions but miss per-Node implementation work. The "no changes this month" entry is the load-bearing piece — it makes inactivity visible.

### Allow prod-data-to-staging "for debugging hard issues"

Considered. The argument: some bugs only reproduce against real data shape; synthetic fixtures cannot catch them. Rejected categorically:

- **Synthetic-fixture quality is the right solution.** If a bug only reproduces against real data, the fixture generator is missing something; improve the generator.
- **Data classification rules are non-negotiable.** ADR-0049 binds PII handling; "for debugging" is not a carve-out PII regulations recognize.
- **The slippery slope is real.** A single "just this once" copy of prod data to staging becomes a recurring pattern, becomes a process, becomes the way bugs are debugged. The hard rule is the only stable rule.

This is the single hardest no in this ADR. It is recorded as no exceptions, on purpose.
