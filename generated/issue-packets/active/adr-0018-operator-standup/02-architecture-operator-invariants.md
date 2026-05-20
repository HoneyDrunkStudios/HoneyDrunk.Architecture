---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0018", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0018"]
accepts: ADR-0018
wave: 1
initiative: adr-0018-operator-standup
node: honeydrunk-operator
---

# Chore: Add ADR-0018's four new invariants to the Grid constitution

## Summary

Add four new invariants to `constitution/invariants.md` derived from ADR-0018's Consequences section: D11 (downstream coupling rule), D6 (App Configuration sourcing for cost rates / policies / thresholds), D8 (approval-event event-out, no Communications runtime edge), and D10 (contract-shape canary on four hot-path interfaces). Assign them numbers **47, 48, 49, 50** — the next four free slots above the current high-water mark of 46 (ADR-0016 already landed 44/45/46 in `## AI Invariants`; ADR-0019 occupies 40-43; collision check at edit time confirms actual numbers).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0018 explicitly delegates final invariant numbering to the scope agent at acceptance time. The four invariants the ADR proposes (in its "New invariants" section under Consequences) need to land in `constitution/invariants.md` so the canary infrastructure, downstream Node packets, and the review agent all have numbered, citable rules to reference.

These four rules govern the Operator Node's first-shipping behavior:

- **D11 — downstream coupling.** Every downstream consumer of Operator (Agents, Flow, AI, Capabilities, Evals, Sim) will compile against `HoneyDrunk.Operator.Abstractions` only. Without an invariant, drift toward runtime references or `Testing` references in production composition is silent until canaries catch it.
- **D6 — App Configuration sourcing.** Cost-rate tables, breaker thresholds, decision policies, and safety-filter configuration in code defeat the entire reason `IDecisionPolicy` and `ICostGuard` exist. An invariant makes a hardcoded threshold a build-time gating concern.
- **D8 — Communications is event-out, not a runtime edge.** A direct Operator → Communications runtime call would collapse the ADR-0013 / ADR-0019 boundary that gave Communications the single authority for outbound message orchestration. An invariant locks the rule.
- **D10 — contract-shape canary.** Even with the canary wired in CI (handled by packet 03), the obligation to *keep* the canary running on the four hot-path interfaces must outlive any single CI workflow file. An invariant ensures any future CI rewrite preserves the gate.

## Proposed Implementation

### `constitution/invariants.md` — append four new entries

Assigned numbers **47, 48, 49, 50** — the current high-water mark in `constitution/invariants.md` is **46** (ADR-0016 landed 44/45/46 in `## AI Invariants`; ADR-0019 occupies 40-43 in `## Communications Invariants`). Verify at edit time with `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20`.

**Insertion layout (Option A — chosen).** Introduce a new section `## AI Sector — Operator Invariants` placed **immediately after the `## Communications Invariants` section** (which ends at the invariant-43 entry on line 164 at the time of this packet). Append it before any later sector sections that may land between packet authoring and packet execution. This mirrors the pattern Communications established with its own dedicated section and keeps Operator's four invariants discoverable as a block. The previously-considered "append to existing `## AI Invariants`" option is rejected — it would interleave Operator rules with the cross-sector AI rules (28, 44, 45, 46) and obscure ownership.

Mark each new entry with `(Proposed — this invariant takes effect when ADR-0018 is accepted)` since ADR-0018 stays at `Status: Proposed` throughout this initiative.

The four entries:

```markdown
## AI Sector — Operator Invariants

47. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Operator.Abstractions`.**
    Composition against `HoneyDrunk.Operator` and `HoneyDrunk.Operator.Testing` is a host-time (and test-time) concern. Test projects may reference `HoneyDrunk.Operator.Testing` to pick up the in-memory fixture; production projects must not. This is the same abstraction/runtime split applied for AI, Capabilities, Vault, and Transport, restated here because it is the specific rule that allows Agents, Flow, AI, Capabilities, Evals, and Sim to proceed on `Abstractions` alone without waiting for runtime or pulling the testing fixture into production composition. See ADR-0018 D11 (Proposed — this invariant takes effect when ADR-0018 is accepted).

48. **Cost-rate tables, circuit-breaker thresholds, decision-policy rule sets, and safety-filter configuration are sourced from Azure App Configuration via Vault's `IConfigProvider`.**
    Hardcoded rates, thresholds, or policies in application code are forbidden. Rate-and-threshold refresh is operator-driven — change the config value, restart or hot-reload, no deploy required. This applies in particular to the per-window budget tables consumed by `ICostGuard` and the threshold values consumed by `ICircuitBreaker`. See ADR-0018 D6 and ADR-0005 (Proposed — this invariant takes effect when ADR-0018 is accepted).

49. **Approval notifications are emitted as events; `HoneyDrunk.Operator` does not take a runtime dependency on `HoneyDrunk.Communications`.**
    When `IApprovalGate` raises an `ApprovalRequest` that needs human attention, Operator emits an approval-needed event via the configured transport. Communications subscribes and owns the downstream workflow (resolve recipient, check preferences, check cadence, deliver via Notify) per ADR-0013 / ADR-0019. Operator does not call `ICommunicationOrchestrator` directly. This keeps Operator's safety-critical path free of an orchestration-layer dependency and keeps Communications as the single authority for whether and how a message reaches a human. See ADR-0018 D8 (Proposed — this invariant takes effect when ADR-0018 is accepted).

50. **The HoneyDrunk.Operator Node CI must include a contract-shape canary that fails the build on shape drift to `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, or `ISafetyFilter` without a corresponding version bump.**
    These four are the hot-path abstractions every downstream consumer (Agents, Flow, AI, Capabilities, Evals, Sim) compiles against. Accidental shape drift on any of them breaks every AI-sector Node that gates, breaks, budgets, or filters. The canary makes this a compile-time failure at Operator's own CI, not a discovery at consumer sites. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Operator.Abstractions`; the obligation is to keep the gate, not to use any specific implementation. See ADR-0018 D10 (Proposed — this invariant takes effect when ADR-0018 is accepted).
```

### Collision-check rule

Before committing, scan `constitution/invariants.md` and confirm the highest existing number. The default of **47-50** assumes the file's high-water mark is **46** at edit time. If something has landed in between (e.g. another AI-sector standup initiative claims 47+ first), shift the four entries to the next four free numbers and update **all three of the following in lockstep**:

1. **ADR-0018 Consequences "New invariants" section** (`adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` lines 166-173) — state the assigned numbers.
2. **This packet 02 file** — update the section heading numbers, the four entry numbers, the Summary line, the Motivation bullets, the CHANGELOG entry text, and the Referenced ADR Decisions cross-references.
3. **Packet 03 source file** at `generated/issue-packets/active/adr-0018-operator-standup/03-operator-node-scaffold.md` — every line that names an Operator invariant number must be updated. Packet 03 currently embeds the default numbers 47/48/49/50; shifts cascade from there. **Exhaustive cross-reference list** (verify each before push; line numbers approximate, use `rg` to confirm exact positions):
   - Line ~298: `"named in invariant 50"` and `"per D11 invariant 47, Abstractions is the only thing"`
   - Line ~427: `> **Operator downstream-coupling invariant (number assigned by packet 02, default 47):**`
   - Line ~429: `> **Operator App-Config-sourcing invariant (number assigned by packet 02, default 48):**`
   - Line ~431: `> **Operator approval-event-out invariant (number assigned by packet 02, default 49):**`
   - Line ~433: `> **Operator contract-shape canary invariant (number assigned by packet 02, default 50):**`

   Run `rg -n '\b(47|48|49|50|51|52|53|54)\b' generated/issue-packets/active/adr-0018-operator-standup/03-operator-node-scaffold.md` (extend the bracket to the next four numbers above the current default block to catch any shifted references). Visually classify each match as either an Operator-invariant reference (must be updated) or an unrelated number (line numbers, port numbers, etc — leave alone). Pre-filing carve-out under invariant 24 applies because packet 03 has not been filed yet.

Use ripgrep (`rg`), not `grep`, to avoid Windows Git Bash CR/LF boundary issues.

### `CHANGELOG.md` (Architecture repo)

Append to the Unreleased section: `Architecture: Add invariants 47 (Operator downstream coupling), 48 (App Config-sourced Operator rate tables, breaker thresholds, decision policies, safety-filter config), 49 (Operator approval-event event-out — no Communications runtime edge), and 50 (Operator contract-shape canary) per ADR-0018 D11, D6, D8, D10. New section `## AI Sector — Operator Invariants` introduced. (Numbers shift to next-available if collision check finds 47-50 taken.)`

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` (only if numbers shift)
- `generated/issue-packets/active/adr-0018-operator-standup/03-operator-node-scaffold.md` (only if numbers shift — pre-filing amendment under invariant 24)
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No new design decisions — invariant text restates D11/D6/D8/D10 with constitutional voice.
- [x] No existing invariants modified, only appended.
- [x] Pre-filing amendment to packet 03 permitted under invariant 24's carve-out.

## Acceptance Criteria
- [ ] Four new invariants present in `constitution/invariants.md` with text matching ADR-0018 D11, D6, D8, D10.
- [ ] Assigned numbers verified against file's current highest number. Default assumption **47-50** (current high-water mark is 46).
- [ ] Each invariant carries the qualifier `(Proposed — this invariant takes effect when ADR-0018 is accepted)`. ADR-0018 stays Proposed for this initiative.
- [ ] New section heading `## AI Sector — Operator Invariants` introduced (Option A) — entries are NOT appended to the existing `## AI Invariants` section.
- [ ] Section placed immediately after `## Communications Invariants` (the current last numbered section ending at invariant 43).
- [ ] Existing entries unmodified.
- [ ] If numbers shift, ADR-0018's Consequences section + this packet + packet 03 source file are updated in lockstep before packet 03 is filed (see the exhaustive cross-reference list in Proposed Implementation).
- [ ] `CHANGELOG.md` Unreleased section updated with assigned numbers.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0018 D6 (App Configuration sourcing):** Cost-rate tables, budget windows, breaker thresholds, decision-policy rule sets, and safety-filter configuration live in Azure App Configuration via Vault's `IConfigProvider`. Source for invariant 48.

**ADR-0018 D8 (Approval event-out, no runtime edge to Communications):** Operator emits approval-needed events; Communications subscribes. No runtime dependency on Communications. Source for invariant 49.

**ADR-0018 D10 (Contract-shape canary on four hot-path interfaces):** `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `ISafetyFilter` are canary-frozen. Source for invariant 50.

**ADR-0018 D11 (Downstream coupling rule):** Downstream Nodes compile only against `HoneyDrunk.Operator.Abstractions`. Source for invariant 47.

## Dependencies
- `packet:01` — packet 01 lands the catalog surface that invariant 47's canary will guard. Filing 02 before 01 would dangle a forward reference.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0018`, `constitution`

## Agent Handoff

**Objective:** Land four new ADR-0018-derived invariants in the Grid constitution at numbers 47-50 (or the next four available if collision check finds them taken), in a new section `## AI Sector — Operator Invariants`.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: ADR-0018's "New invariants" section is a placeholder. This packet is the finalization.
- Feature: ADR-0018 standup initiative, Wave 1, Packet 02.
- ADRs: ADR-0018.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01.

**Constraints:**

- **Each new invariant carries `(Proposed — this invariant takes effect when ADR-0018 is accepted)`.** Mirror the qualifier pattern from invariants 28, 31/32/33.
- **Insertion layout is Option A (new section).** Introduce `## AI Sector — Operator Invariants` immediately after `## Communications Invariants`. Do not append to the existing `## AI Invariants` section.
- **Number collision check is a hard gate.** Default **47-50** (current high-water mark is 46). Verify against the file's highest number at edit time. If shifted, update ADR-0018 Consequences section + this packet + packet 03 source file in lockstep per the exhaustive cross-reference list in Proposed Implementation.
- **Verbatim alignment with ADR-0018.** Restate D11/D6/D8/D10 with constitutional voice; do not introduce new requirements.
- **Pre-filing amendment to packet 03 is the mechanism** for handling number shifts. Invariant 24's carve-out applies.

**Key Files:**
- `constitution/invariants.md`
- `adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` (only on shift)
- `generated/issue-packets/active/adr-0018-operator-standup/03-operator-node-scaffold.md` (only on shift)
- `CHANGELOG.md`

**Contracts:** None.
