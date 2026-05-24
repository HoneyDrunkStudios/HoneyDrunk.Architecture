---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "docs", "adr-0066", "wave-6"]
dependencies: ["packet:00"]
adrs: ["ADR-0066", "ADR-0046"]
wave: 6
initiative: adr-0066-health-endpoints
node: honeydrunk-architecture
---

# Add health-endpoint checklist to review.md and the security specialist prompt

## Summary
Amend `.claude/agents/review.md` (the canonical Grid-aware code review agent per ADR-0044) and the `security` specialist agent prompt (per ADR-0046) with an ADR-0066 health-endpoint checklist. The checklist covers: three endpoints mapped, auth posture correct, contributor messages reviewed for PII per Invariant `{N3}`, contributor execution time bounded. Surfaces Invariant `{N1}`, 55, 56 at the PR-review boundary so a regression on the contract gets caught at PR time rather than at deploy time.

## Context
ADR-0066's follow-up list calls for: "Update `.claude/agents/review.md` and the `security` specialist prompt with a health-endpoint checklist: three endpoints mapped, auth posture correct, contributor messages reviewed for PII, contributor execution time bounded."

ADR-0066 D8 cites the security-specialist coupling explicitly: "The `security` specialist review per ADR-0046 gains a checklist item for contributor message review."

Two review surfaces:
1. **`.claude/agents/review.md`** — the canonical Grid-aware code-review agent that runs on every non-draft PR per ADR-0044 / invariant 52. Used by every consumer of the cloud-wired reviewer. Adding the checklist here means every PR touching health endpoints, contributors, or host composition gets the check.
2. **`security` specialist** — per ADR-0046, a narrower-scope deeper-rigor specialist invoked manually on Auth/Vault/tenant/public-API touches. ADR-0066 D8 specifically asks the security checklist to include contributor-message review.

The checklist for the review agent (broad coverage):
- The three endpoints (`/health/live`, `/health/ready`, `/health`) are mapped via `MapHoneyDrunkHealthEndpoints` or the Functions-host equivalent — not hand-rolled (Invariant `{N1}`).
- `/health/live` and `/health/ready` are anonymous; `/health` is auth-required (Invariant `{N2}`).
- Any new `IHealthContributor` registers with an explicit `ReadinessPolicy` value (D7); the default (`Required`) is the conservative fallback if no policy is declared.
- Contributor `output` strings do not carry secrets, connection strings, tenant identifiers, or provider opaque IDs (Invariant `{N3}` + ADR-0049 references).
- Contributor execution time is bounded — the Kernel aggregator applies a 1-second default timeout; contributors should target sub-100ms.
- `/health/live` does NOT consult contributors (returns based on lifecycle stage only — protection against feedback-loop restarts on dependency hiccups; D7).
- The host has an auth scheme wired so `/health` resolves to `401` for unauthenticated requests (Invariant `{N2}`).
- Container App probe configuration (if the PR touches infrastructure walkthroughs) matches the D5 defaults or documents the per-Node override reason.

The security-specialist checklist (deeper, narrower):
- Re-emphasize the contributor-message PII rule (Invariant `{N3}`) with concrete examples: connection strings, vault URIs, tenant ULIDs, Stripe IDs.
- Audit the host's auth scheme for `/health` — confirm it resolves to `401` on unauthenticated, not anonymous fallback.
- Verify probe outcomes flow as telemetry (Pulse counter / log) and NOT as audit events (D10 — probe volume is high, not forensically interesting).
- If the PR introduces a new contributor whose execution is dependent on a Vault secret or external dependency, confirm it is appropriately classified (`Required` if it truly gates readiness, `OptionalReported` if not) — a misclassified contributor can pull a Node out of rotation on a non-critical dep hiccup.

This is a docs/governance packet. No code, no .NET project. The `review.md` file is in `.claude/agents/` — the canonical location per ADR-0007.

## Scope
- `.claude/agents/review.md` — add the ADR-0066 health-endpoint checklist to the appropriate rubric section. Per ADR-0044 D3 the review agent uses a twenty-category rubric; the health-endpoint checklist most naturally fits under multiple categories (security, reliability, observability, contracts). Choose a placement — most likely under "Reliability" (the endpoints are part of the operational reliability surface) — and cross-link from "Security" and "Observability" if the file structure supports cross-links.
- `.claude/agents/security.md` (or wherever the `security` specialist agent prompt lives — check `.claude/agents/` for the file matching the ADR-0046 roster name) — add the deeper contributor-message audit checklist. If the file does not exist yet (ADR-0046 specialist standup may be ongoing), defer the security-specialist amendment to ADR-0046's standup follow-up and document the deferral in the PR.
- **Coupling reminder per invariant 33:** `.claude/agents/scope.md` (this scope agent's own file) has a context-loading contract that the review agent's context-loading contract must be a superset of. This packet does NOT change either context-loading contract — only the rubric/checklist content. If the operator wants the review agent to load any new file at PR-review time, that change is a separate packet.

## Proposed Implementation
1. **`.claude/agents/review.md`.** Open the file. Find the rubric section (per ADR-0044 D3 it carries a twenty-category rubric). Place the ADR-0066 health-endpoint checklist as a subsection under "Reliability" (or the closest matching category — read the existing structure and choose). The checklist (write each as a bullet the reviewer evaluates):
   - "Three endpoints (`/health/live`, `/health/ready`, `/health`) are exposed via `MapHoneyDrunkHealthEndpoints` (or `HealthFunctionExtensions` for Functions hosts) — not hand-rolled `MapGet` calls. **Invariant `{N1}`.**"
   - "`/health/live` and `/health/ready` are anonymous (no `RequireAuthorization`); `/health` is auth-required (`RequireAuthorization` or equivalent). **Invariant `{N2}`.**"
   - "Every registered `IHealthContributor` declares its `ReadinessPolicy` explicitly. The default (`Required`) is conservative; non-blocking contributors must declare themselves `OptionalReported` or `NotReadinessRelevant` explicitly. **ADR-0066 D7.**"
   - "Contributor `output` strings do not carry secrets, connection strings, tenant identifiers, or provider opaque IDs. Cross-reference invariants 8 and 56 and ADR-0049. **Invariant `{N3}`.**"
   - "Contributor execution is bounded — the Kernel aggregator applies a 1-second default timeout, configurable per registration. New contributors should target sub-100ms execution and call out any unavoidable overrun with a configured timeout. **ADR-0066 Operational Consequences.**"
   - "`/health/live` does NOT consult contributors. Reviewer flags any host code that wires contributors into the liveness path (e.g. a custom `/health/live` handler that calls the aggregator). **ADR-0066 D7.**"
   - "If the PR introduces infrastructure walkthrough changes for a Container App probe, the configuration matches ADR-0066 D5 defaults or documents the per-Node override reason. **ADR-0066 D5.**"
   Add the section with an "ADR-0066 (Health endpoints)" header so the rubric category is browsable.
2. **`.claude/agents/security.md`** (or matching file). If the security-specialist agent file exists (per ADR-0046 specialist standup), add a "Health endpoints (ADR-0066)" section with the deeper checklist:
   - "Audit every `IHealthContributor.CheckHealthAsync` implementation's message string for: connection strings, Vault URIs, tenant ULIDs, Stripe customer IDs, Azure resource IDs, provider opaque tokens. The contributor is responsible for redaction at the report site; the Kernel aggregator and the response writer do NOT redact. **Invariant `{N3}` + ADR-0049.**"
   - "Verify the host's auth scheme for `/health` resolves to `401` on unauthenticated requests — not anonymous fallback, not a redirect to a sign-in page that a probe credential would not follow."
   - "Verify probe outcomes flow as Pulse telemetry (counter `honeydrunk.health.probes`, histogram `honeydrunk.health.contributor.duration`, structured Warning/Error logs) and NOT as `IAuditLog` events. Probes are high-volume and not forensically interesting. **ADR-0066 D10.**"
   - "If the PR introduces a contributor whose `CheckHealthAsync` depends on a Vault secret, external HTTP call, or database round-trip, confirm its `ReadinessPolicy` accurately reflects whether the dep is required-for-traffic or merely-reported. Misclassification can pull a Node out of rotation on a non-critical hiccup. **ADR-0066 D7.**"
   - If `.claude/agents/security.md` does not yet exist, defer this step and document the deferral in the PR. ADR-0046's standup will own the file's creation and the security-specialist amendment lands in the standup or as a separate ADR-0046 follow-up packet.
3. **Confirm invariant 33's superset relationship is unchanged.** The review-agent's context-loading contract (per `.claude/agents/review.md`) must remain a superset of the scope-agent's (per `.claude/agents/scope.md`). This packet does NOT add a new file to either agent's context-loading list — only adds rubric content. If the operator wants either agent to load a new file at PR-review or scope-time, that's a separate ADR-0011 D4 / invariant 33 packet.

## Affected Files
- `.claude/agents/review.md`
- `.claude/agents/security.md` (if it exists; defer otherwise)

## NuGet Dependencies
None. This packet touches only agent prompt files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture/.claude/agents/` — the canonical agent location per ADR-0007.
- [x] No code change in any other repo.
- [x] No context-loading contract change (invariant 33 superset relationship unchanged).

## Acceptance Criteria
- [ ] `.claude/agents/review.md` carries an "ADR-0066 (Health endpoints)" section with the seven-bullet rubric checklist
- [ ] The checklist cites Invariant `{N1}`, 55, 56 by number AND by full text where they appear (the agent has access to `constitution/invariants.md`, but inlining the load-bearing text keeps the prompt readable)
- [ ] The checklist references ADR-0049 in the contributor-message PII bullet
- [ ] `.claude/agents/security.md` carries the four-bullet deeper checklist (if the file exists; otherwise the deferral is documented in the PR)
- [ ] The review-agent context-loading contract (per the file's "Context" section) is NOT changed in this packet
- [ ] The scope-agent context-loading contract (per `.claude/agents/scope.md`) is NOT changed in this packet
- [ ] No code change; no `.csproj` change; no version bump (Architecture is not a versioned .NET solution)
- [ ] `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0066 D7 — `ReadinessPolicy`.** The reviewer's check enforces explicit policy declaration on every new contributor.

**ADR-0066 D8 — Contributor message PII rule.** "The `security` specialist review per ADR-0046 gains a checklist item for contributor message review." This packet is that addition.

**ADR-0066 D10 — Probe outcomes are NOT audit events.** Security-specialist check verifies probes flow to telemetry, never to `IAuditLog`.

**ADR-0066 Operational Consequences — Contributor execution time.** "The Kernel aggregator wraps each contributor in a 1-second timeout by default; configurable per registration." Reviewer flags slow contributors before deploy time.

**ADR-0044 D3 — Review-agent rubric.** Twenty-category rubric. The ADR-0066 checklist fits under Reliability with cross-links from Security and Observability.

**ADR-0046 — `security` specialist.** Manual-invocation specialist; the contributor-message audit is a natural deep-lens check for it.

**Invariant 33 — Review/scope context-loading symmetry.** Not changed in this packet; only rubric content is added.

## Constraints
- **Invariant 33 — context-loading symmetry.** The review-agent's load list must be a superset of the scope-agent's. This packet does NOT change either load list — only adds rubric content.
- **ADR-0007 — `.claude/agents/` is the canonical location for agent definitions.** Edits target that path; do NOT introduce a parallel definition elsewhere.
- **If `.claude/agents/security.md` does not exist, defer.** ADR-0046 specialist standup owns the file's creation; do not author it as a side-effect of this packet.
- **Inline invariant text where load-bearing.** Per the scope-agent's authoring rules ("Inline invariant text. Never write 'Invariant 17' — write the actual rule text"), the review-agent rubric cites invariant numbers AND inlines the rule text where the wording matters.

## Labels
`chore`, `tier-1`, `meta`, `docs`, `adr-0066`, `wave-6`

## Agent Handoff

**Objective:** Add the ADR-0066 health-endpoint checklist to `.claude/agents/review.md` and `.claude/agents/security.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Surface Invariant `{N1}`, 55, 56 at the PR-review boundary; surface the deeper contributor-message audit at the security-specialist boundary.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 6.
- ADRs: ADR-0066 D7/D8/D10 + Operational Consequences (primary), ADR-0044 (review-agent rubric), ADR-0046 (specialist agents), ADR-0007 (`.claude/agents/` canonical location).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — Invariant `{N1}`, 55, 56 must exist before the rubric cites them by number.

**Constraints:**
- Do NOT change the context-loading contract of either agent (invariant 33 symmetry).
- Inline invariant text where load-bearing — agent rubrics rely on it.
- If `.claude/agents/security.md` does not exist (ADR-0046 standup state), defer the security-specialist amendment and document the deferral.

**Key Files:**
- `.claude/agents/review.md`
- `.claude/agents/security.md` (conditional)

**Contracts:** None changed — agent rubric content only.
