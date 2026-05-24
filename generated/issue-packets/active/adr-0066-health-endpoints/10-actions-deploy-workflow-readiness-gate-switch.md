---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci", "adr-0066", "wave-6"]
dependencies: ["packet:03"]
adrs: ["ADR-0066", "ADR-0015", "ADR-0033"]
wave: 6
initiative: adr-0066-health-endpoints
node: honeydrunk-actions
---

# Switch the Container Apps deploy workflow's readiness gate from /health to /health/ready

## Summary
Amend the Container Apps deploy workflow in `HoneyDrunk.Actions` so the post-deploy readiness gate probes `/health/ready` (anonymous, empty-body 200/503 contract per ADR-0066 D2) rather than `/health` (which becomes auth-required after this initiative — Invariant `{N2}`). The change preserves invariant 36's traffic-shift-on-revision-health gate while removing the inconsistency between the deploy probe and the Grid-wide contract. The Notify Worker `release-worker.yml` (per ADR-0066 Context) and any parallel Container Apps deploy workflow (Pulse.Collector's release workflow, the shared `job-deploy-container-app.yml` per ADR-0015) all switch in this single PR so deploys are consistent across the deployable lines.

## Context
ADR-0066 Context names the inconsistency: "The Worker's release workflow (`release-worker.yml`) gates traffic on `/health`; the readiness endpoint exists for monitoring rather than for the deploy gate." After this initiative `/health` is auth-required (Invariant `{N2}`), so an unauthenticated probe from the deploy workflow returns `401`, breaking the deploy gate. The fix is to probe `/health/ready` instead — which is anonymous (D6), returns the right semantics ("is this revision ready to serve traffic?"), and matches invariant 36's revision-health gate.

ADR-0066 D5 makes the rule explicit: "Container-App revision health gating: a new revision is shifted to `100%` traffic only after `/health/ready` has returned `200` for at least three consecutive periods on the revision's direct FQDN. The probe configuration above provides the timing; the deploy workflow (`job-deploy-container-app.yml` per ADR-0015) holds the gate."

ADR-0066 follow-up list calls this out specifically: "Coordinate with the deploy-workflow owner (ADR-0015's `job-deploy-container-app.yml` in `HoneyDrunk.Actions`) to confirm the readiness-gate probe target switches from `/health` to `/health/ready` for new revisions."

The Notify.Functions deploy gate is a related but separate path — Notify.Functions is on the Functions host, not Container Apps. Its `release-functions-host` (or equivalent) workflow gates on `/api/health` (the Functions-host prefixed equivalent of `/health`). If the Functions deploy gate probes `/api/health`, it has the same problem after this initiative — `/health` is auth-required. The fix is to probe `/api/health/ready` (Functions-host prefixed `/health/ready`). Include the Functions deploy gate in this packet.

This packet runs in Wave 6 alongside packet 08 (per-Node infrastructure walkthroughs) and packet 09 (review-agent updates). It hard-blocks behind packet 03 only — the Kernel runtime endpoints must exist before the deploy gate probes them. It does NOT block on packets 05/06 (the Node-side amendments) because the workflow change is environment-independent — once the workflow targets `/health/ready`, it works against any revision that exposes that endpoint per the ADR-0066 contract; whether the revision was built before or after packet 05/06 merged is irrelevant to the gate's correctness as long as `/health/ready` is reachable on that revision.

**The sequencing risk:** if packet 10 lands before packets 05/06 finish deploying, a Container App revision whose code is from before packet 05/06 may not have `/health/ready` mapped at all (in Pulse.Collector's case, the placeholder endpoint exists; in Notify.Worker's case, the readiness endpoint exists but the body shape and contributor wiring change). In practice the workflow probes the path regardless of body shape (it consumes the status code), and the path exists on both old and new revisions. So packet 10 is safe to land in any order relative to packets 05/06; the operator should still verify in the deploy log that the probe is hitting the right endpoint.

`HoneyDrunk.Actions` is the CI/CD control plane per ADR-0012. The workflows live in `.github/workflows/` of the Actions repo, with reusable workflows shared via the `workflow_call` trigger. Confirm at execution time where the relevant workflows live (likely `job-deploy-container-app.yml` per ADR-0015 D14, plus the per-deployable callers like `release-worker.yml` if they hold their own gate logic).

## Scope
- `HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml` — the reusable Container Apps deploy workflow per ADR-0015. Change the readiness-gate probe target from `/health` to `/health/ready`.
- `HoneyDrunk.Actions/.github/workflows/release-worker.yml` (or the Notify Worker release caller's workflow file — confirm name at execution time) — same change if it holds its own probe call rather than using the reusable workflow.
- The Pulse.Collector release workflow (whichever file holds it) — same change.
- The Notify.Functions deploy gate's workflow — change `/api/health` to `/api/health/ready` (Functions-host prefixed `/health/ready`).
- Workflow tests / smoke tests if the Actions repo has them.
- Repo-level `CHANGELOG.md` (if the Actions repo carries one — confirm convention).

## Proposed Implementation
1. **Locate the workflows.** Identify the workflows that contain the readiness-gate probe call. Likely candidates: `job-deploy-container-app.yml` (the reusable per ADR-0015), `release-worker.yml`, a Pulse.Collector release workflow (name TBD), a Notify.Functions deploy workflow. State the located workflows in the PR.
2. **Change the probe target.**
   - For Container Apps deploys (Notify.Worker, Pulse.Collector): change the probe URL path from `/health` to `/health/ready`. The probe call is likely a `curl -fsSL https://{revision-direct-fqdn}/health/ready` or an Azure CLI `az containerapp` probe-check step — confirm the exact shape and amend it. The probe expects `200` for healthy (HTTP 200 with empty body per ADR-0066 D2); `503` (or any non-`200`) triggers the gate's failure path. The probe does not parse the body — it relies on the status code. Match invariant 36's "three consecutive periods" condition; the probe loop should keep `/health/ready` returning `200` for the configured number of attempts before declaring the revision ready.
   - For Notify.Functions: change `/api/health` to `/api/health/ready`. The Functions-host adds the `/api/` prefix to the route; ADR-0066 D11 names this as a host-imposed prefix accommodated by the per-host Functions binding. Same status-code semantics.
3. **No auth header.** Per ADR-0066 D6, `/health/ready` is anonymous — the workflow does NOT need to pass an auth credential. Remove any auth-token handling that existed for the previous `/health` probe (which would have needed auth after Invariant `{N2}` came into effect). If the workflow currently has no auth handling (because `/health` was placeholder-only and anonymous historically), the change is just the URL path swap.
4. **Update the workflow's documentation** (the `#`-comment header at the top of the workflow file, or an associated `docs/` file) — note that the probe target is `/health/ready` per ADR-0066, anonymous, and the gate evaluates HTTP 200 over three consecutive periods per invariant 36.
5. **Smoke-test the change** if the Actions repo has a workflow-test scaffold. Otherwise, the operator validates by deploying a known-healthy revision and observing the deploy gate pass against `/health/ready` (this is a Human Prerequisite below).
6. **Versioning.** If the Actions repo uses workflow versioning via `@v1`-style tags or branch refs, follow the existing convention. If reusable workflows are referenced by SHA pin from caller workflows in other repos (per the Grid's reusable-workflow discipline), confirm callers consume the updated SHA after this PR merges — the workflow change is not active in other repos until they bump the ref.
7. **CHANGELOG.** If the Actions repo carries a `CHANGELOG.md`, add an entry. ADR-0012 sets `HoneyDrunk.Actions` as the CI/CD control plane but the changelog convention may be lighter than for code repos — match the existing pattern.

## Affected Files
- `HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml` (and/or wherever the Container Apps readiness gate lives).
- `HoneyDrunk.Actions/.github/workflows/release-worker.yml` (Notify Worker).
- `HoneyDrunk.Actions/.github/workflows/` whichever Pulse.Collector release workflow exists.
- `HoneyDrunk.Actions/.github/workflows/` whichever Notify.Functions release workflow exists.
- `HoneyDrunk.Actions/CHANGELOG.md` (if present).
- Inline workflow documentation (`#`-comment headers).

## NuGet Dependencies
None. This packet touches only GitHub Actions YAML; no .NET project is created or modified.

## Boundary Check
- [x] All change is in `HoneyDrunk.Actions` — the CI/CD control plane per ADR-0012 / invariant 35-adjacent rules.
- [x] No code change in any other repo. (The deployable Nodes already expose `/health/ready`; packets 05 and 06 ensure its body/auth semantics match the ADR-0066 contract.)
- [x] No new dependency.

## Acceptance Criteria
- [ ] Every Container Apps deploy workflow's readiness-gate probe targets `/health/ready` (not `/health`)
- [ ] The Notify.Functions deploy gate's probe targets `/api/health/ready` (not `/api/health`)
- [ ] The probe expects HTTP 200 for healthy; the gate's "three consecutive periods" condition (invariant 36 / ADR-0066 D5) is preserved
- [ ] No auth credential is passed on the readiness probe (the endpoint is anonymous per ADR-0066 D6)
- [ ] Workflow inline documentation reflects the new probe target and the ADR-0066 reference
- [ ] If the Actions repo carries a `CHANGELOG.md`, an entry is added
- [ ] Caller workflows in other repos that pin to a specific SHA of the reusable workflow are NOT changed in this PR (they bump in their own repos when ready to consume) — but the PR notes which callers will need to bump
- [ ] `pr-core.yml` tier-1 gate passes (Actions repo's own PR gate)

## Human Prerequisites
- [ ] **Validate the change against a live deployment.** After this PR merges, perform a known-good deploy of one Container App (e.g. Pulse.Collector in `dev`) and observe the deploy log to confirm the readiness-gate probe hits `/health/ready` and receives `200` over three consecutive periods. If the probe receives `503` or `401` from a still-old revision, that indicates the deploy gate is hitting the right endpoint but the revision's contract is mismatched — investigate before treating it as a workflow bug.
- [ ] **Coordinate with packets 05 (Pulse) and 06 (Notify) deploy windows.** This packet's workflow change is environment-independent (`/health/ready` exists on every revision that maps the contract — both the old placeholder and the new Kernel-helper version expose it). But the *behaviour* of `/health/ready` (empty body vs `{ "status": "Ready" }` JSON, dependency-free vs aggregator-driven) differs by revision. Validate after each Node's amendment ships that the workflow continues to gate correctly.
- [ ] **Caller workflows that pin to a specific SHA.** If the reusable `job-deploy-container-app.yml` is consumed by caller workflows in `HoneyDrunk.Notify`, `HoneyDrunk.Pulse`, or other Container Apps deployers via a SHA pin, those callers must bump the pin to consume this change. This packet does NOT bump the pin in other repos; that is a deliberate per-repo decision so consumers control when the gate change takes effect.

## Referenced ADR Decisions
**ADR-0066 D5 — Container-App revision health gating.** "A new revision is shifted to `100%` traffic only after `/health/ready` has returned `200` for at least three consecutive periods on the revision's direct FQDN. The probe configuration above provides the timing; the deploy workflow (`job-deploy-container-app.yml` per ADR-0015) holds the gate."

**ADR-0066 D6 — Auth posture.** `/health/ready` is anonymous; the probe needs no credential.

**ADR-0066 D11 / Functions-host prefix accommodation.** Notify.Functions exposes `/api/health/ready` (the `/api/` prefix is the Functions host's; the endpoint suffix is uniform).

**ADR-0066 Follow-up — Deploy-workflow coordination.** "Coordinate with the deploy-workflow owner (ADR-0015's `job-deploy-container-app.yml` in `HoneyDrunk.Actions`) to confirm the readiness-gate probe target switches from `/health` to `/health/ready` for new revisions." This packet is that change.

**ADR-0015 D14 — Reusable Container Apps deploy workflow.** `job-deploy-container-app.yml` is the canonical deploy gate; caller workflows compose it.

**ADR-0012 — HoneyDrunk.Actions as CI/CD control plane.** This packet's edits live in the control-plane repo.

**ADR-0033 — Environment-gated deploy-trigger model.** The probe gate is part of the per-environment deploy flow ADR-0033 describes; the change here applies uniformly to `dev`, `staging`, `prod`.

## Constraints
- **Invariant 36 — Container App revision-mode-Multiple with traffic splitting.** The "three consecutive periods" condition is preserved; only the probe URL changes.
- **Invariant `{N2}` — `/health/live` and `/health/ready` anonymous; `/health` auth-required.** The reason for this change.
- **ADR-0012 — Actions is the CI/CD control plane.** Workflow edits live here; no parallel deploy logic gets introduced in deployable repos.
- **Do NOT bump caller workflows in other repos in this PR.** Bumping the SHA pin in `HoneyDrunk.Notify` or `HoneyDrunk.Pulse` is each consumer's decision; this packet only changes the canonical workflow.
- **Probe consumes status code only.** ADR-0066 D2 — bodies are empty on probes; the workflow must not parse the body.
- **No auth on the readiness probe.** Remove any historical auth-credential handling tied to the previous `/health` probe; `/health/ready` is anonymous.

## Labels
`feature`, `tier-2`, `ops`, `ci`, `adr-0066`, `wave-6`

## Agent Handoff

**Objective:** Switch the Container Apps deploy workflow's readiness-gate probe from `/health` to `/health/ready` so the gate continues to work after `/health` becomes auth-required.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Preserve invariant 36's revision-health gate by probing the unauthenticated `/health/ready` endpoint instead of the auth-required `/health` aggregate.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 6.
- ADRs: ADR-0066 D5/D6 (primary), ADR-0015 D14 (reusable Container Apps deploy workflow), ADR-0012 (Actions as CI/CD control plane), ADR-0033 (environment-gated deploys), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — the Kernel runtime endpoints exist; the deploy gate probes a path the Kernel helper maps.

**Constraints:**
- Change URL path only; preserve invariant 36's "three consecutive periods" condition.
- Remove any auth-credential handling on the readiness probe.
- Do NOT bump caller workflows in other repos in this PR.
- The probe consumes status code only; bodies are empty on probes per ADR-0066 D2.

**Key Files:**
- `HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml` (and per-deployable caller workflows that hold their own probe logic, e.g. `release-worker.yml` for Notify Worker and the Pulse.Collector release workflow).
- `HoneyDrunk.Actions/.github/workflows/` Notify.Functions deploy workflow.
- `HoneyDrunk.Actions/CHANGELOG.md` if present.

**Contracts:** None changed — workflow YAML only.
