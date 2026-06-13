---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0055", "wave-5"]
dependencies: ["work-item:00"]
adrs: ["ADR-0055"]
wave: 5
initiative: adr-0055-feature-flags
node: honeydrunk-architecture
---

# Roll ADR-0055 governance into review.md, feature-flow-catalog, and the escalation-triggers doc

## Summary
Land the three governance / discovery / operator artifacts the ADR's Follow-up Work names: roll the D13 anti-pattern checklist into `.claude/agents/review.md`, add a new "feature-flag evaluation" flow to `constitution/feature-flow-catalog.md`, and document the D15 escalation triggers in `business/context/` so the operator can recognize them when they fire. None of these is a code change; together they close the loop on the ADR's discipline + observability + escalation surface.

## Context
ADR-0055 names three docs/governance follow-ups beyond the catalogs/invariants/schema landed in earlier packets:
- **`.claude/agents/review.md`** — the `review` agent's checklist gains the D13 anti-pattern rules so every PR review sees them.
- **`constitution/feature-flow-catalog.md`** — the Grid's canonical "how a feature flows through the system" catalog gains a new entry for feature-flag evaluation, end-to-end from `IFeatureGate.IsEnabledAsync(...)` → App Configuration lookup → targeting filter evaluation → log emission → audit (for permission/operational).
- **`business/context/`** — the D15 escalation triggers are operator-readable signals; documenting them where the operator looks for grid-wide context makes them findable when they fire.

These three are independent of every other packet (they only depend on packet 00's acceptance to ground the citations). They are grouped into Wave 5 for tidy filing, but their `dependencies:` frontmatter is the real signal — they unblock as soon as 00 lands.

This is a docs-only packet. No code, no .NET project, no workflow change.

## Scope
- `.claude/agents/review.md` — append a new section "ADR-0055 Anti-Patterns (Feature Flags)" with the six D13 anti-patterns.
- `constitution/feature-flow-catalog.md` — append a new flow entry "Feature-Flag Evaluation."
- `business/context/feature-flag-escalation-triggers.md` (new) — the four D15 triggers documented for the operator.

## Proposed Implementation
1. **`.claude/agents/review.md`** — append a new section. The review agent's rubric (per ADR-0044 D3) is already a 20-category checklist; this packet adds the D13 anti-patterns as items the agent watches for. Section title: "ADR-0055 Anti-Patterns (Feature Flags)." Each anti-pattern from D13 gets a checklist line:
   - **Flag-checking inside a tight loop.** Hoist the evaluation outside the loop or rely on per-request scoped caching. Flag the PR if a `IsEnabledAsync` call appears inside a loop body (the review agent uses the diff and the changed-files context to detect this — name the pattern explicitly so the agent has a target to recognize).
   - **Flag as a stand-in for authorization.** Authorization decisions belong in `HoneyDrunk.Capabilities` per ADR-0051. A permission flag gates *availability* of a feature to a tenant; a Capabilities check authorizes the principal's invocation. Flag any PR that uses `IFeatureGate.IsEnabledAsync` as the only gate on a sensitive action.
   - **Flag-checking without `RequestContext` access.** Tenant-targeted flags need the context to flow through; flag any PR that introduces a hardcoded tenant id, a constructed-fake targeting context, or a bypass for a flag in a code path that should have plumbed the context.
   - **String-concatenating flag names.** `IsEnabledAsync($"release.{node}.{feature}")` defeats the Roslyn analyzer. Flag any PR with a non-literal flag-name argument; suggest the `const string` hoist pattern.
   - **Long-lived release flags.** A release flag with an `expires_on` extended more than once signals work-pattern issues — the right response is shipping in smaller increments, not extending the flag indefinitely. Flag any PR that extends an `expires_on` past the second time.
   - **Permission flags whose only effect is UX text.** UX-only changes belong in i18n, not the flag system. Flag any PR that uses `IFeatureGate` to toggle a label or a text snippet.
   Each line follows the existing rubric format (terse trigger + the recommended remediation), matching the style of the other categories in `review.md`.

2. **`constitution/feature-flow-catalog.md`** — append a new entry. The catalog already documents flows like "a message from intake to delivery" or "a webhook from receipt to normalization." A new flow:
   > **Feature-Flag Evaluation (ADR-0055)**
   > A flag-gated code path executes the following flow at every evaluation:
   >
   > 1. **Caller invokes `IFeatureGate.IsEnabledAsync(flagName)`** in `HoneyDrunk.<Node>`. The flag name is a `const string` matching the regex `{category}.{node}.{feature}`.
   > 2. **`AzureAppConfigurationFeatureGate`** (`HoneyDrunk.FeatureFlags`) resolves the ambient `ITargetingContext` from `RequestContext` (per ADR-0026); on off-request paths, the caller supplies it explicitly via the second overload.
   > 3. **`Microsoft.FeatureManagement.IFeatureManagerSnapshot`** reads the flag definition from App Configuration's feature-flag surface. Per ADR-0055 D9, the per-environment label scopes the read.
   > 4. **Targeting filters evaluate**: built-in `PercentageFilter` and `TimeWindowFilter`, plus the custom `TenantTargetingFilter` from `HoneyDrunk.FeatureFlags`. The filter chain composes per the JSON shape (D3 example).
   > 5. **Decision returns** as `ValueTask<bool>` (or `ValueTask<T>` for variants).
   > 6. **`feature_flag_evaluated` log event** emits via `HoneyDrunk.Pulse`'s `ILogger` per D10; hotpath flags sample at 1%.
   > 7. **No audit event for evaluation.** Evaluations are too high-volume for audit; the audit surface is *flip* events (D10), which is the operator-CLI path (packet 08) and ride the separate `IAuditLog` substrate.
   >
   > Cross-references: ADR-0055 D2 (backend), D3 (targeting), D4 (abstraction), D9 (label inversion), D10 (observability), ADR-0040 (Pulse → App Insights backing), ADR-0026 (RequestContext).
   Match the section style and depth of existing entries in the catalog.

3. **`business/context/feature-flag-escalation-triggers.md`** (new) — the four D15 escalation triggers documented for the operator. Each trigger gets:
   - **Symptom** — what the operator observes.
   - **Threshold** — when the trigger fires (active flag count, flip frequency, operator complaint, etc.).
   - **Action** — what the operator does (evaluate LaunchDarkly, GrowthBook, etc.).

   The four triggers, from ADR-0055 D15:
   - **Operator workflow pain** — active flag count exceeds ~100 and App Configuration's UI / SDK becomes the operator bottleneck. Symptom: time spent on routine flag operations exceeds a working-day's worth per month; the operator reaches for spreadsheets to track flags. Action: evaluate LaunchDarkly (rich dashboard, targeting UX) and GrowthBook (self-hosted, similar UX).
   - **Experimentation needs** — A/B testing with statistical significance, conversion tracking, automated decision rollouts become a requirement. Symptom: a product or experimentation track explicitly requests these capabilities. Action: LaunchDarkly's experimentation surface or a dedicated experimentation platform; App Configuration is not built for this.
   - **Multi-tenant operator delegation** — tenant-scoped operator personas need to flip flags within their tenant boundary; App Configuration's RBAC is workspace-level, not flag-level. Symptom: a Notify.Cloud tenant operator needs to flip their own flags without grid-wide write access. Action: LaunchDarkly's project/environment model, or build a thin authorization layer on top of App Configuration.
   - **Cost escalation** — App Configuration's flag-evaluation API cost becomes meaningful (extremely unlikely at v1 Grid scale). Symptom: App Configuration's monthly bill traceable to the feature-flag surface exceeds a noticeable share of the ops budget. Action: re-evaluate per-flag pricing of LaunchDarkly vs hosting GrowthBook.

   Cross-reference the doc from `business/context/README.md` (or whatever the index file is named — confirm at edit time).

4. **No code change. No invariant change.** All three artifacts are governance/discovery surfaces.

## Affected Files
- `.claude/agents/review.md` — new "ADR-0055 Anti-Patterns (Feature Flags)" section appended.
- `constitution/feature-flow-catalog.md` — new "Feature-Flag Evaluation" flow entry appended.
- `business/context/feature-flag-escalation-triggers.md` (new) — the four D15 triggers.
- `business/context/README.md` (or the index file) — one-line entry for the new escalation-triggers doc.

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] `.claude/agents/review.md` is the canonical review-agent prompt; per the agent context-loading contract (invariant 33), updates here must mirror scope.md's context-loading where relevant — but this packet only adds anti-pattern rubric items, not context-loading changes, so the coupling rule is not triggered.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` has a new "ADR-0055 Anti-Patterns (Feature Flags)" section appended, listing the six D13 anti-patterns each as a terse-trigger + remediation rubric item matching the existing review-rubric style
- [ ] `constitution/feature-flow-catalog.md` has a new "Feature-Flag Evaluation" flow entry covering the seven-step evaluation flow (caller → context → SDK → filters → decision → log → no-audit-on-evaluation) with cross-references to ADR-0055 D2/D3/D4/D9/D10, ADR-0040, ADR-0026
- [ ] `business/context/feature-flag-escalation-triggers.md` exists and documents the four D15 triggers with Symptom / Threshold / Action for each
- [ ] `business/context/README.md` (or equivalent index) lists the new escalation-triggers doc
- [ ] No invariant change in this packet (invariants land in packet 00)
- [ ] No code change; no .NET project modified

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0055 D13 — Anti-patterns explicitly forbidden.** Six anti-patterns: tight-loop flag-checking; flag-as-authorization; flag-without-RequestContext; string-concatenated flag names; long-lived release flags; permission flags whose only effect is UX text. The review agent enforces these per ADR-0044 D3.

**ADR-0055 D10 — Observability split.** Evaluations log; flips audit (permission/operational only). The feature-flow-catalog entry documents this end-to-end so the discoverability surface matches the runtime reality.

**ADR-0055 D15 — Escalation triggers.** Four operator-recognizable triggers: workflow pain past ~100 flags, experimentation needs, multi-tenant operator delegation, cost escalation. Each carries a Symptom / Threshold / Action triple in `business/context/`.

**ADR-0055 Follow-up Work.** Explicitly names: "Update `.claude/agents/review.md` with the D13 anti-pattern checklist," "Add a new 'feature-flag evaluation' flow to `constitution/feature-flow-catalog.md`," "Document the D15 escalation triggers in `business/context/` so the operator can recognize them."

## Constraints
- **Match existing doc style.** `review.md`'s rubric format, `feature-flow-catalog.md`'s flow-entry shape, and `business/context/`'s entry pattern are conventions; match them rather than authoring fresh structure.
- **Cross-references are inline.** Every ADR reference is a full-text cross-reference (`ADR-0055 D13`, `ADR-0040`, etc.) so the docs are useful without the reader knowing the ADR catalog by heart.
- **Don't restate invariants.** The two new ADR-0055 invariants live in `constitution/invariants.md` (packet 00). The review.md anti-patterns are D13's call-site checklist; they reinforce the invariants without duplicating them.
- **Coupling with scope.md.** Invariant 33: `review.md`'s context-loading section must be a superset of `scope.md`'s. This packet only adds rubric items, not context-loading; the coupling rule is not triggered. If the executor finds the rubric edit *does* require new context loading (e.g., the agent now needs to read `featureflags.json` files when reviewing PRs), mirror the addition in `scope.md` as well — but at scoping time the rubric is judgment-driven, not context-loaded.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0055`, `wave-5`

## Agent Handoff

**Objective:** Land the three governance / discovery / operator docs the ADR's Follow-up Work names: D13 anti-patterns into `review.md`, feature-flag evaluation flow into `feature-flow-catalog.md`, D15 escalation triggers into `business/context/`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close the loop on ADR-0055's discipline (review.md), discoverability (flow catalog), and escalation-readiness (operator-readable triggers).
- Feature: ADR-0055 Feature Flag rollout, Wave 5.
- ADRs: ADR-0055 D10/D13/D15 (primary), ADR-0044 D3 (review-agent rubric structure).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0055 should be Accepted before its anti-patterns and escalation triggers are documented as governance.

**Constraints:**
- Match existing doc style for each surface.
- Inline cross-references; don't assume the reader knows the ADR catalog by heart.
- Don't duplicate invariants; the rubric items reinforce, not restate.
- Coupling with scope.md (invariant 33) — not triggered by this packet (no context-loading change), but watch for it if the rubric grows to need new context.

**Key Files:**
- `.claude/agents/review.md` — new section appended.
- `constitution/feature-flow-catalog.md` — new flow entry appended.
- `business/context/feature-flag-escalation-triggers.md` (new).
- `business/context/README.md` — index entry.

**Contracts:** None changed.
