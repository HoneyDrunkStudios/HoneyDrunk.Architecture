# ADR-0033: Environment-Gated Deploy-Trigger Model for Deployable Nodes

**Status:** Proposed
**Date:** 2026-05-18
**Deciders:** HoneyDrunk Studios
**Sector:** Ops

## Context

The Grid has three deployable lines, all standing up under ADR-0015's hosting decision:

- `Notify.Functions` — Azure Function App, released by `HoneyDrunk.Notify/.github/workflows/release-functions.yml` on `functions-v*` tags.
- `Notify.Worker` — Azure Container App, released by `HoneyDrunk.Notify/.github/workflows/release-worker.yml` on `worker-v*` tags.
- `Pulse.Collector` — Azure Container App, released by `HoneyDrunk.Pulse/.github/workflows/release-collector.yml` on `collector-v*` tags.

Each consumer release workflow is triggered **only** by its SemVer-shaped tag (plus `workflow_dispatch`), resolves `environment: dev` GitHub vars in a `resolve` job, and calls the matching reusable deploy workflow in HoneyDrunk.Actions (`job-deploy-function.yml` or `job-deploy-container-app.yml`). Only the `dev` environment is provisioned today. The header comments in all three release workflows already frame the dev-only/tag-only scope as "intentional, not a gap" and explicitly name staging/prod promotion gating as a deliberate follow-up. **This ADR is that follow-up, decided.**

The driver for change: HoneyDrunk is a solo developer plus AI agents merging packet PRs to `main` continuously. Cutting a tag for every dev deploy is ceremony with no payoff — `dev` is a disposable environment and is never a promotion source, so its version-of-record is irrelevant there. Tag-gating is friction that only earns its keep for environments that need deliberate, versioned, rollback-able promotion (staging/prod), which do not exist yet.

Two prior ADRs bound this decision:

- **ADR-0012** (Proposed) names HoneyDrunk.Actions as the CI/CD control plane: deploy logic lives in reusable workflows, never reimplemented in consumer repos. This ADR must preserve that invariant.
- **ADR-0015** (Accepted) picks Azure Container Apps with `Multiple`-revision traffic-shifting and explicitly **deferred** staging/prod gating. This ADR resolves that deferral.

A grounding fact established by reading both reusable deploy workflows: they are `on: workflow_call` only. They take an `environment` input, a built artifact/image, and Azure/Key Vault coordinates. They have no opinion about what triggered the caller. **Trigger policy is not deploy mechanics** — it is the consumer workflow's `on:` block, which by construction cannot be centralized through `workflow_call`. ADR-0012's invariant governs deploy *mechanics* (build → push → revision → probe → traffic-shift), all of which remain in the control plane unchanged.

## Decision

Deployable Nodes adopt a **hybrid, environment-gated trigger model**, implemented entirely in the consumer release workflows. The control plane (HoneyDrunk.Actions) is **not** modified.

### D1 — Trigger model per environment

Each consumer release workflow gains a second trigger alongside its existing tag trigger:

- **`push` to `main`, path-filtered → `dev`.** Continuous deploy to the disposable environment for fast feedback. The deploy artifact is identified by commit SHA only; this is acceptable because `dev` is never a promotion source.
- **SemVer-shaped tag (`<line>-v*`), unfiltered → `staging` / `prod`.** Deliberate, versioned, CHANGELOG/SemVer-anchored, rollback-able promotion. Tags remain the trigger for every environment that needs a version-of-record. (`staging`/`prod` are still not provisioned; this records the model so it is not re-litigated when they are.)
- **`workflow_dispatch` retained** as the manual escape hatch for both paths.

The version-of-record rule (CHANGELOG + SemVer tag; no commits under `Unreleased`) is unchanged and continues to govern every promotion. A push-to-`main` dev deploy has no version stamp by design and is explicitly **not** a promotion source.

### D2 — Trigger-to-environment resolution is explicit

The existing `resolve` job in each release workflow is the single place trigger intent is mapped to a target environment. A tag ref (`refs/tags/<line>-v*`) resolves the promotion environment; a `main` branch push resolves `dev`. The mapping is an explicit conditional in `resolve`, not inferred implicitly from `vars.HD_ENV` and not scattered across jobs. A header comment block (matching the existing in-file convention) documents the two trigger paths.

### D3 — Path filtering is part of the decision, not optional

The `push: branches: [main]` trigger on each release workflow carries a `paths:` filter scoped to **that deployable's own source** — its project directory and `.csproj`, its `Dockerfile`, and any solution-level inputs that affect its build. This makes "not every green `main` is release-intent" concrete for the dev line and bounds Container App inactive-revision churn. The tag trigger is **not** path-filtered: a deliberately pushed tag is always deploy-intent.

### D4 — Multi-deployable repos: per-deployable independence

In a repo with more than one deployable (HoneyDrunk.Notify: `Notify.Functions` on `functions-v*` / `Notify.Functions/`, and `Notify.Worker` on `worker-v*` / `Notify.Worker/`), each release workflow's push-to-`main` path filter is scoped to **only its own** deployable's source. A Functions-only commit must not redeploy the Worker, and vice versa. Each line keeps its independent tag prefix for promotion. This is the multi-deployable correctness rule and applies to any future repo with more than one deployable.

### D5 — Concurrency

Each release workflow declares a `concurrency` group whose key includes the **resolved environment**, so dev churn can never cancel a staging/prod promotion:

- **Dev (branch-push path): `cancel-in-progress: true`.** The latest `main` supersedes in-flight dev deploys; correct for a disposable environment and prevents overlapping Container App revisions from rapid pushes.
- **Tag (promotion path): `cancel-in-progress: false`.** A deliberate versioned promotion must never be silently cancelled by a later one; promotions queue.

### D6 — Stated promotion model for staging/prod (deferred but decided)

When `staging`/`prod` are provisioned, a promotion tag is cut from a `main` commit that has already been dev-deployed and observed. Promotion **rebuilds from the tagged source** through the same reusable deploy workflow, with the environment selected by the trigger — it does **not** promote the dev-built artifact, because dev builds carry no version stamp and the reusable workflows already build-on-deploy from source/Dockerfile. Identical-artifact promotion is explicitly deferred and is the reconsideration point if build non-determinism or build-time cost later justifies it.

### D7 — `dev` remains an unprotected GitHub Environment by design

A required-reviewer protection rule on the `dev` GitHub Environment would block push-to-`main` deploys on approval, defeating the purpose of D1. `dev` must remain unprotected. Environment protection rules are the mechanism for `staging`/`prod` only, complementary to (not a replacement for) the tag trigger.

### D8 — Relationship to ADR-0012 and ADR-0015

This decision **amends ADR-0015** by resolving its explicitly-deferred staging/prod gating question and recording the promotion model (D6). It **clarifies ADR-0012** without changing any of its invariants: trigger policy is consumer-workflow-owned (the `on:` block, inherently per-repo); deploy mechanics remain control-plane-owned. No new invariants are introduced. No `catalogs/relationships.json` edge changes — this is CI trigger policy, not a Node contract or dependency-graph change.

## Consequences

### Affected Nodes

- **HoneyDrunk.Notify** — `release-functions.yml` and `release-worker.yml` each gain a path-filtered push-to-`main` trigger, an explicit trigger→environment mapping in `resolve`, and a `concurrency` block. The two lines are independently path-scoped per D4.
- **HoneyDrunk.Pulse** — `release-collector.yml` gains the same three changes (single-deployable, so D4 is trivially satisfied).
- **HoneyDrunk.Actions** — **No change.** The reusable deploy workflows already accept the `environment` input and build-on-deploy; trigger policy is out of their scope by construction.

### Invariants

No new invariants. No change to existing invariants. ADR-0012's invariants 34–38 and ADR-0015's invariants 34–36 (hosting-platform numbering) are untouched; this ADR adds no enforcement surface.

### Operational Consequences

- Continuous dev deploys produce Container App inactive revisions at merge cadence. ADR-0015 sets no revision-retention policy; revision GC is named as a follow-up consideration, out of scope here.
- Dev rollback is roll-forward (push again, or `workflow_dispatch` a prior ref). Dev is not a rollback-critical environment. Staging/prod rollback (when provisioned) is revision traffic-shift / slot semantics per ADR-0015, with a SemVer tag as the rollback target — which is why tags remain the promotion trigger.
- A stale `paths:` filter (deployable source moved, filter not updated) causes dev to silently stop auto-deploying — a fail-safe no-op, not a bad deploy, but invisible to central observability: the ADR-0012 grid-health aggregator tracks scheduled nightlies, not release workflows, so a release line going silent is not surfaced today. Known gap, non-blocking; named here so agents do not rely on grid-health to catch it.

### Follow-up Work

Not part of this ADR's landing; each is discrete and scoped separately via the scope agent after this ADR is accepted:

- Amend the three consumer release workflows (`release-functions.yml`, `release-worker.yml`, `release-collector.yml`) per D1–D5 and D7. Two repos, three workflows; no control-plane PR.
- Update each workflow's header comment block to document the dual-trigger model (replacing the current "dev-only/tag-only — intentional, not a gap" framing, which this ADR supersedes).
- Consider extending the ADR-0012 grid-health aggregator to track release workflows, or accept the silent-no-op gap (D8 / Operational Consequences). Low priority; flagged, not committed.
- Consider a Container App inactive-revision retention/GC policy as an amendment to ADR-0015 if dev revision accumulation becomes a practical concern.

## Alternatives Considered

### Status quo — tag-only for every environment

Rejected. This is the friction the user is removing. For a disposable `dev` environment under a continuous solo-dev + AI-agent merge cadence, requiring a tag per dev deploy is ceremony with no payoff: `dev` is never a promotion source, so its version-of-record is irrelevant. Keeping it tag-only permanently defers the follow-up the release-workflow headers already named.

### Push-to-`main` for all environments, GitHub Environment approval gate for staging/prod (no tags)

Rejected on the version-of-record rule. Gating staging/prod by an approval click instead of a tag makes promotion SHA-based: an approval is not a version, and the prod rollback target degrades from "v1.4.2" to "some SHA". This contradicts the hard rule that the version-of-record is the CHANGELOG + SemVer tag. Environment protection rules are retained as a *complement* to tags for staging/prod (D7), not a replacement.

### Centralize trigger policy in a HoneyDrunk.Actions reusable workflow

Rejected as not mechanically possible and not desirable. A reusable workflow consumed via `workflow_call` cannot own the caller's `on:` block — trigger policy is irreducibly per-consumer-repo. Attempting to push it into the control plane would either fail (workflow_call has no trigger surface) or smear trigger logic into deploy mechanics, blurring exactly the line ADR-0012 draws. The clean factoring is: trigger policy = consumer `on:` block; deploy mechanics = reusable workflow. This ADR keeps that factoring intact.

### Promote the dev-built artifact to staging/prod (artifact promotion)

Deferred, not adopted (D6). Same-binary promotion has appeal (build once, deploy many) but dev builds carry no version stamp and the reusable workflows already build-on-deploy from source/Dockerfile, so rebuild-from-tag is the lower-friction model today. Reconsider if build non-determinism or build-time cost becomes a concrete problem.

## Implementation Notes (2026-06-01) — As-Built: Staged Approval-Gate Promotion

Recorded per ADR-0008 § Implementation-Notes Packets. Full as-built record (every delta + rationale, PRs, follow-ups) lives in this initiative's `implementation-notes.md` — under `generated/issue-packets/active/adr-0033-deploy-trigger-model/` while in flight, and `generated/issue-packets/completed/adr-0033-deploy-trigger-model/` once `hive-sync` archives it (invariant 37). The decision above is preserved as written; implementation refined it materially. Headline deltas (decided ➜ as-built):

- **Promotion (D1/D7):** `tag → staging → manual prod gate → prod`, staged in one run. The gate is the `prod` GitHub Environment's required-reviewers rule, reached only after staging (`resolve-prod`/`deploy-prod` both `needs: deploy-staging`). Tags remain the promotion trigger, so version-of-record is preserved — the gate is added *on top*, reconciling (not adopting) the rejected "approval-gate, no tags" alternative.
- **Shape (D2/D5):** per-environment static deploy jobs (`deploy-{dev,staging,prod}`) with job-level concurrency, instead of a dynamic `resolve`-mapped single environment / top-level concurrency.
- **Artifact (D6):** Functions = build-once same-artifact; containers rebuild the tagged source per per-env registry, with literal same-artifact promotion deferred pending a registry-topology decision.
- **Path filters (D3/D4):** corrected — the Worker closure includes core `Notify` + `Abstractions` + shared-*source* `HostBootstrap`/`ProviderSupport` (packet 02 wrongly excluded the first two); `NuGet.config` and `.dockerignore` added.
- **Deviations:** CHANGELOG entry dropped (neither repo has a repo-level `CHANGELOG.md`); ADR references retained in workflow comments (operator choice, against the no-ADR-numbers doc convention).

Trigger logic was proven on the first real `deploy-dev` runs (resolve + OIDC + skip-logic all correct); the deploys then surfaced dev infrastructure/RBAC gaps (Key Vault access, AcrPull, managed-environment join) tracked toward ADR-0077 (Infrastructure-as-Code).
