---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0045", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0045", "ADR-0015", "ADR-0033", "ADR-0012"]
accepts: ["ADR-0045"]
wave: 3
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-actions
---

# Amend the Actions deploy workflows to call the App Insights release annotations API

## Summary
Amend the reusable deploy workflows in `HoneyDrunk.Actions` (`job-deploy-container-app.yml`, `job-deploy-function.yml`) with a post-deploy step that calls the Application Insights release annotations API per ADR-0045 D6 — so the deployable's SemVer tag lands as a release annotation on the App Insights Failures-blade trend graph, making "this error first appeared in v0.4.2" visible.

## Context
ADR-0045 D6 wires release tracking to the Grid's deploy flows. App Insights' release-tracking feature uses the `application_Version` property on captured telemetry (packet 03 sets that on each captured exception) **and** the release annotations API, which marks the deploy moment on the Failures trend graph.

ADR-0045 D6 is explicit: "the `HoneyDrunk.Actions` reusable deploy workflows (per ADR-0015) are amended to set `application_Version` to the deployable's SemVer tag (per ADR-0033's tag→environment mapping) and to mark the deploy via the current supported release-annotation mechanism. Captured exceptions automatically carry this version."

**Release-annotation mechanism — use the current supported one.** The deploy step marks the deploy moment on the App Insights Failures trend graph using the **current supported release-annotation mechanism — `az monitor app-insights` / ARM**. The legacy `aisvc.visualstudio.com` annotations endpoint (`https://aigs1.aisvc.visualstudio.com/applicationinsights/release/v2.0/api`) is a **fallback only** if no supported equivalent applies. Research the current surface at execution time and prefer the supported path.

`HoneyDrunk.Actions` already owns the reusable CI/CD workflows (per ADR-0012, Actions is the Grid's CI/CD control plane). The relevant deploy workflows in `.github/workflows/`:
- `job-deploy-container-app.yml` — Azure Container Apps deploy (per ADR-0015 — Notify.Functions/Worker, Pulse.Collector, future Notify Cloud).
- `job-deploy-function.yml` — Azure Function App deploy.

This packet adds a post-deploy release-annotation step to those reusable workflows, gated so it is a no-op when the App Insights resource is not configured (graceful for environments that have not provisioned telemetry yet — staging/prod are still in flight per ADR-0033).

**This is a workflow/YAML packet. No .NET project.** `HoneyDrunk.Actions` is not a versioned .NET solution — no version bump, no `## NuGet Dependencies`-driven project change. The repo's `CHANGELOG.md` (if it keeps one for the workflow surface) is updated per the repo convention.

## Scope
- `.github/workflows/job-deploy-container-app.yml` — add the post-deploy release-annotation step.
- `.github/workflows/job-deploy-function.yml` — add the same step.
- `docs/consumer-usage.md` (or the equivalent docs the deploy workflows reference) — document the new optional inputs.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## Proposed Implementation
1. **New optional workflow inputs** on both deploy workflows:
   - `app-insights-release-annotation` (boolean, default `false`) — gate the step. When `false`, the step is a clean no-op (environments without provisioned telemetry — staging/prod per ADR-0033).
   - `app-insights-resource-id` — the App Insights ARM resource id the annotation targets. Supplied by the consuming repo's release workflow.
   - The deployable's SemVer version — reuse whatever input the workflows already carry for the version/tag (per ADR-0033's tag→environment mapping). Do not add a duplicate version input if one exists.
2. **Post-deploy release-annotation step** — runs after the deploy + health-probe succeeds (an annotation for a failed deploy is misleading; only annotate a successful revision/slot). The step:
   - Authenticates with Azure via the existing OIDC federation the workflows already use (no new credential — the deploy job is already OIDC-authenticated; reuse that token / `az` session).
   - Marks the deploy via the **current supported release-annotation mechanism — `az monitor app-insights` / ARM** (the primary, default path). The legacy raw `aisvc.visualstudio.com` endpoint is a **fallback only** if the supported mechanism does not apply. **Research the current supported surface at execution time and document the choice.** The annotation payload carries the deployable's name, the SemVer version, and the deploy timestamp.
   - Is gated on `app-insights-release-annotation == true` and a non-empty `app-insights-resource-id`.
3. **Graceful no-op.** If the gate input is `false` or the resource id is empty, the step logs a single skipped-annotation line and exits 0. A deploy must never fail because release annotation was not configured — annotation is observability sugar, not a deploy gate.
4. **No secret in the workflow.** The annotation API call authenticates via the existing OIDC federation. No DSN, no instrumentation key, no connection string is needed for the annotation API — it is ARM/AAD-authenticated. If any token is required, it is acquired at runtime via OIDC; nothing is stored in the workflow or repo (invariant 8).
5. **Docs.** Update the consumer-usage docs so a consuming repo's release workflow knows to set the two new inputs. Cross-reference: the consuming repo also needs packet 03's `HoneyDrunk.Telemetry.Sink.AzureMonitor` error backing wired for the `application_Version` on captured exceptions to be meaningful — note that the annotation and the per-exception version are two halves of D6.

## Affected Files
- `.github/workflows/job-deploy-container-app.yml`
- `.github/workflows/job-deploy-function.yml`
- `docs/consumer-usage.md` (or the equivalent referenced docs)
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## NuGet Dependencies
None. `HoneyDrunk.Actions` deploy workflows are GitHub Actions YAML — no .NET project is created or modified by this packet.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0045 D6 names "the `HoneyDrunk.Actions` reusable deploy workflows"; ADR-0012 makes Actions the CI/CD control plane.
- [x] The reusable deploy workflows are the right surface — consuming repos call them; the release annotation is a deploy-time concern.
- [x] No code change in any Node — the per-exception `application_Version` is packet 03's concern in Observe; this packet only adds the deploy-moment annotation.

## Acceptance Criteria
- [ ] `job-deploy-container-app.yml` and `job-deploy-function.yml` each have a post-deploy step that marks the deploy on App Insights via the **current supported release-annotation mechanism (`az monitor app-insights` / ARM)** with the deployable name, SemVer version, and deploy timestamp; the legacy `aisvc.visualstudio.com` endpoint is used only as a documented fallback if no supported equivalent applies
- [ ] The step runs only after a successful deploy + health probe — a failed deploy produces no annotation
- [ ] New optional inputs `app-insights-release-annotation` (boolean, default `false`) and `app-insights-resource-id` gate the step; the deployable version reuses an existing version/tag input
- [ ] When the gate is `false` or the resource id is empty, the step is a clean no-op (logs one skipped line, exits 0) — a deploy never fails for lack of annotation config
- [ ] The annotation call authenticates via the existing OIDC federation — no DSN, instrumentation key, connection string, or any secret in the workflow or repo (invariant 8)
- [ ] `docs/consumer-usage.md` documents the two new inputs and notes the annotation pairs with packet 03's per-exception `application_Version`
- [ ] The current supported annotation mechanism is researched and the choice documented; `az monitor app-insights` / ARM is the default, the raw `aisvc` endpoint a fallback only
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] Existing consumers of the deploy workflows are unaffected — the new inputs are optional with safe defaults

## Human Prerequisites
- [ ] For the release annotation to land on a real resource, a consuming repo's release workflow must supply the `app-insights-resource-id` of an App Insights resource provisioned by **ADR-0040 packet 02**. Until that resource exists (and staging/prod environments stand up per ADR-0033), the annotation step is left gated `false` — the workflow change is inert and safe. This is a cross-initiative prerequisite, not a `dependencies:` edge.
- [ ] No portal step is required to land this packet itself — it is a workflow edit. The first *use* of the annotation happens when a consuming repo opts in.

## Referenced ADR Decisions
**ADR-0045 D6 — Release tracking via `application_Version`.** Container Apps deployable Nodes — the `HoneyDrunk.Actions` reusable deploy workflows are amended to set the deployable's SemVer tag (per ADR-0033's tag→environment mapping) and mark the deploy via the **current supported release-annotation mechanism (`az monitor app-insights` / ARM)**; the legacy `aisvc.visualstudio.com` endpoint is a fallback only. The Failures blade surfaces these as annotations on the trend graph. Library/Abstractions packages do not set a version. Workflow quality is lower than Sentry's release surface — acceptable for v1, named as a D11 escalation trigger.

**ADR-0015 — Container hosting.** Azure Container Apps for containerized Nodes; the Actions reusable deploy workflows are the deploy surface.

**ADR-0033 — Tag→environment mapping.** The SemVer tag drives the environment; staging/prod environments are still in flight — the annotation step is gated off until they stand up.

**ADR-0012 — Actions is the CI/CD control plane.** Reusable workflows in `HoneyDrunk.Actions` are the Grid's CI/CD surface.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** The release annotation API call is OIDC/AAD-authenticated. No DSN, instrumentation key, or connection string is committed to a workflow or the repo.

- **Annotation is never a deploy gate.** A failed or unconfigured annotation must not fail the deploy. Gate the step; no-op cleanly.
- **Reuse the existing OIDC auth.** The deploy job is already OIDC-authenticated — do not add a new credential or service principal for the annotation call.
- **Optional, backward-compatible inputs.** Existing consumers of the deploy workflows must be unaffected — new inputs default to off.
- **Use the current supported API surface.** `az monitor app-insights` / ARM is the default, supported mechanism. The raw `aisvc.visualstudio.com` endpoint is a legacy surface — fallback only if no supported equivalent applies. Research and document the choice.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0045`, `wave-3`

## Agent Handoff

**Objective:** Add a post-deploy App Insights release-annotation step to the `HoneyDrunk.Actions` reusable container-app and function deploy workflows.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make "this error first appeared in v0.4.2" visible on the App Insights Failures trend graph by annotating each successful deploy with the deployable's SemVer.
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 3.
- ADRs: ADR-0045 D6 (primary), ADR-0015 (Container Apps deploy surface), ADR-0033 (tag→environment mapping), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0045 should be Accepted before its deploy-flow changes land. No code dependency on the Observe packets — this packet is independent of packets 02/03 and can run in parallel.

**Constraints:**
- The annotation step is never a deploy gate — gate it, no-op cleanly.
- Reuse the existing OIDC auth; no new credential.
- New inputs are optional, default-off, backward-compatible.
- No secret in the workflow (invariant 8).
- Use the current supported annotation mechanism (`az monitor app-insights` / ARM) as the default; legacy `aisvc` endpoint fallback only; document the choice.

**Key Files:**
- `.github/workflows/job-deploy-container-app.yml`
- `.github/workflows/job-deploy-function.yml`
- `docs/consumer-usage.md`

**Contracts:** None — workflow inputs only.
