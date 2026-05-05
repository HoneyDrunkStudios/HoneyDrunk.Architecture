---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0017", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0017"]
wave: 1
initiative: adr-0017-honeydrunk-capabilities-standup
node: honeydrunk-capabilities
---

# Chore: Add ADR-0017's four new invariants to the Grid constitution

## Summary
Add four new invariants to `constitution/invariants.md` derived from ADR-0017's Consequences section: D9 (downstream coupling rule), D6 (descriptor versioning), D5+D10 (authorization through Auth), and D8 (contract-shape canary). Assign them numbers **43, 44, 45, 46** — the next four free numbers assuming ADR-0016's invariants pack (proposed 39/40/41 originally, expected to renumber to 40/41/42 since ADR-0026 already took 39) lands first. Collision check at edit time decides the actual numbers.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0017 explicitly delegates final invariant numbering to the scope agent at acceptance time. The four invariants the ADR proposes (in its "New invariants" section under Consequences) need to land in `constitution/invariants.md` so the canary infrastructure, downstream Node packets, and the review agent all have a numbered, citable rule to reference.

These four rules govern the Capabilities Node's first-shipping behavior:

- **D9 — downstream coupling.** Every AI-sector consumer from packet 04 onward will compile against `HoneyDrunk.Capabilities.Abstractions` and only that package. Without an invariant, drift toward `HoneyDrunk.Capabilities` direct references or `HoneyDrunk.Capabilities.Testing` references in production composition is silent until canaries catch it. Better to forbid it explicitly.
- **D6 — descriptor versioning.** A registry where descriptors can be unversioned breaks the entire "tools evolve without breaking consumers" promise. An invariant makes unversioned registration a build-time gating concern.
- **D5/D10 — Auth as the authorization root.** A second permission model in the Grid is a second trust boundary, and the two models drift. An invariant locks the rule that `ICapabilityGuard` projects Auth's policy, never invents its own.
- **D8 — contract-shape canary.** Even with the canary wired in CI (handled by packet 04), the obligation to *keep* the canary running on the four hot-path contracts must outlive any single CI workflow file. An invariant ensures any future CI rewrite preserves the gate.

## Proposed Implementation

### `constitution/invariants.md` — append four new entries

The current state of the file (verified 2026-05-04):

- Highest assigned number is **39** (ADR-0026's "Tenant mechanics stay at intake and post-dispatch boundaries.")
- Numbers 29-30 are reserved for ADR-0010 (the placeholder line is still present at line 113)
- ADR-0016's standup initiative also files three new invariants. ADR-0016 packet 02's source file at `generated/issue-packets/active/adr-0016-honeydrunk-ai-standup/02-architecture-ai-invariants.md` proposes 39/40/41; that packet's collision-check language acknowledges it must shift if 39 is taken. Since ADR-0026 has already landed and grabbed 39, ADR-0016's packet 02 is expected to file at 40/41/42 (its collision-check logic handles this automatically when it executes).

Working assumption: ADR-0016 packet 02 lands first (it is also Wave 1 and depends on its own packet 01). It claims 40/41/42. ADR-0017 packet 02 (this one) claims **43, 44, 45, 46**.

**Collision-check rule for the executing agent:** Before committing, scan `constitution/invariants.md` and confirm the highest existing number. If the highest is 42, claim 43-46. If the highest is something else (e.g. 39 because ADR-0016 has not yet landed, or 46 because some other initiative grabbed slots in the interim), claim the next four free numbers. This is a hard gate, not a best-effort.

If the assigned numbers shift away from 43-46:

- The corresponding bullets in ADR-0017's Consequences section ("New invariants (proposed for `constitution/invariants.md`)") at lines 128-131 are updated to state the assigned numbers.
- The packet 04 source file at `generated/issue-packets/active/adr-0017-honeydrunk-capabilities-standup/04-capabilities-node-scaffold.md` is amended in place before push. Per the dispatch plan's filing-order rule, packet 04 is not filed until this packet has merged, so the pre-filing carve-out under invariant 24 applies.
- `repos/HoneyDrunk.Capabilities/integration-points.md` (created in packet 01) references the canary invariant by phrase ("number assigned at acceptance") rather than by number, so no edit is required there. If for some reason a number has been baked into that file already, update it.

### Where the four entries land in `constitution/invariants.md`

The current file ends with:

```markdown
## Multi-Tenant Boundary Invariants

39. **Tenant mechanics stay at intake and post-dispatch boundaries.** ...
```

There is no AI-Capabilities-specific section header. The four new invariants belong logically alongside the AI invariants but are about Capabilities specifically. Two acceptable layouts:

- **Option A (preferred): introduce a new `## AI Sector — Capabilities Invariants` section after `## Multi-Tenant Boundary Invariants`.** Mirrors the structure ADR-0016 packet 02 set: ADR-0016 added its three invariants under the existing `## AI Invariants` section because that section was already labeled generically. ADR-0017's invariants are specifically about the Capabilities Node, so a sibling section is clearer than overloading `AI Invariants` with substrate-specific rules.
- **Option B (acceptable): append the four entries inside the existing `## AI Invariants` section, right after the three ADR-0016-derived entries (40/41/42).** This matches ADR-0016 packet 02's choice of "no new section header — stay inside `## AI Invariants`". Acceptable but it stretches that section into two logical groupings (substrate inference rules vs substrate tool-registry rules) under one header.

The executing agent picks based on what the file looks like at edit time:

- If `## AI Invariants` already contains 28 + the three ADR-0016-derived entries, **Option A** is preferred — start a new `## AI Sector — Capabilities Invariants` section to keep each substrate's rules visually clustered.
- If the file structure has otherwise drifted in unexpected ways, fall back to **Option B** (append inside `## AI Invariants`) and mention the deviation in the PR body.

### Invariant text — assuming numbers 43, 44, 45, 46

Append the four entries as:

```markdown
## AI Sector — Capabilities Invariants

43. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Capabilities.Abstractions`.**
    Composition against `HoneyDrunk.Capabilities` and `HoneyDrunk.Capabilities.Testing` is a host-time (and test-time) concern, resolved at application startup. Test projects may reference `HoneyDrunk.Capabilities.Testing` to pick up the in-memory registry/dispatcher fixture. Production projects must not. This is the same abstraction/runtime split applied for AI, Vault, and Transport, restated here because it is the specific rule that allows Agents, Operator, Memory, Knowledge, Evals, and tool-registering domain Nodes to proceed on `Abstractions` alone without waiting for the runtime or pulling the testing fixture into production composition. See ADR-0017 D9 (Proposed — this invariant takes effect when ADR-0017 is accepted).

44. **Every registered capability descriptor carries an explicit version; the registry key is `(name, version)`.**
    Unversioned registration is a build failure. Version-aware lookup is required of the registry implementation. The specific version *format* (name-suffixed string, strict semver, hybrid) is decided by the scaffold packet that ships the first registry implementation, but the principle that descriptors are versioned is fixed at acceptance. See ADR-0017 D6 (Proposed — this invariant takes effect when ADR-0017 is accepted).

45. **Authorization for capability invocation is resolved through `HoneyDrunk.Auth` policy via `ICapabilityGuard`.**
    Capabilities does not maintain an independent permission model. The `ICapabilityGuard` interface is the local surface a downstream Node compiles against; its default implementation delegates to Auth. Invocation paths must always pass through the guard before dispatch — no bypass surface exists. See ADR-0017 D5 and D10 (Proposed — this invariant takes effect when ADR-0017 is accepted).

46. **The HoneyDrunk.Capabilities Node CI must include a contract-shape canary that fails the build on shape drift to `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, or `ICapabilityGuard` without a corresponding version bump.**
    These four are the hot-path abstractions every downstream consumer compiles against. Accidental shape drift on any of them breaks every AI-sector Node and every tool-registering domain Node simultaneously. The canary makes this a compile-time failure at Capabilities's own CI, not a discovery at consumer sites. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Capabilities.Abstractions`; the obligation is to keep the gate, not to use any specific implementation. See ADR-0017 D8 (Proposed — this invariant takes effect when ADR-0017 is accepted).
```

If Option B is chosen instead (append inside `## AI Invariants`), drop the `## AI Sector — Capabilities Invariants` heading and place the four entries after ADR-0016's three.

### Notes for the executing agent

- **Each new invariant entry MUST be marked `(Proposed — this invariant takes effect when ADR-0017 is accepted)`** at the end of its body. ADR-0017 is still at `Status: Proposed` at the time this packet's PR lands — none of the four packets in this initiative flip ADR-0017's status. The status flip is a separate post-merge housekeeping step. Until that flip happens, the four new invariants are themselves Proposed. This matches the existing pattern: invariant 28 (ADR-0010), invariants 31/32/33 (ADR-0011) all carry `(Proposed — this invariant takes effect when ADR-XXXX is accepted)` qualifiers — replicate that exact qualifier shape verbatim, substituting `ADR-0017`.
- Do not modify the existing entries (28, 31-39) or the `_Invariants 29–30 are reserved..._` placeholder.
- If ADR-0016 packet 02 has not yet merged at the time this packet executes, the highest number is still 39 and the four new entries claim 40/41/42/43. In that case the executing agent for this packet does the renumber, updates ADR-0017's Consequences bullets accordingly, and amends packet 04's source file (per the lockstep-rename criterion below). The dispatch plan's filing-order rule and invariant 24's pre-filing carve-out cover the packet-04 amendment.

### Lockstep renumber of packet 04 source file

Packet 04 (the scaffold) hard-codes the assumed invariant numbers 43-46 in roughly ten places. If the collision check shifts the numbers away from 43-46, every reference in `04-capabilities-node-scaffold.md` must update in lockstep before that packet is filed.

After determining the actually-assigned numbers, run:

```bash
rg -n '\b4[3-6]\b' generated/issue-packets/active/adr-0017-honeydrunk-capabilities-standup/04-capabilities-node-scaffold.md
```

Use ripgrep (`rg`), not `grep` — Windows Git Bash's `grep` boundary semantics differ subtly from ripgrep's. For each match, replace the old number with the assigned one. The matches are concentrated in the Constraints and Referenced Invariants sections; verify by re-running the rg query and confirming zero hits at the old numbers and the expected count at the new numbers. Where a reference is purely narrative ("the Capabilities downstream-coupling invariant"), the number does not need to be there at all — those phrase-keyed references are preferred per the packet's existing pattern. The numbers stay in places where they are genuinely needed (e.g. parenthetical "default 43" annotations, the actual `constitution/invariants.md` insertion).

### `CHANGELOG.md` (Architecture repo)

Append to the Unreleased section: `Architecture: Add invariants 43 (Capabilities downstream coupling), 44 (descriptor versioning), 45 (Auth as authorization root for ICapabilityGuard), and 46 (Capabilities contract-shape canary) per ADR-0017 D9, D6, D5+D10, D8. (Numbers shift to next-available if collision check finds 43-46 taken.)`

If renumbered, update the changelog line to state the actually-assigned numbers.

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` (only if the assigned numbers differ from 43/44/45/46 — update the Consequences "New invariants" bullets)
- `generated/issue-packets/active/adr-0017-honeydrunk-capabilities-standup/04-capabilities-node-scaffold.md` (only if the assigned numbers differ from 43/44/45/46 — pre-filing amendment per invariant 24's carve-out)
- `CHANGELOG.md`

## NuGet Dependencies
None. Architecture is a knowledge repo.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No new design decisions — invariant text is taken from ADR-0017's "New invariants" section, with light wordsmithing for the constitution's voice.
- [x] No existing invariants modified, only appended.
- [x] Pre-filing amendment to packet 04's source file is permitted under invariant 24's carve-out; post-filing amendment is forbidden, so the dispatch plan's filing-order rule (packet 04 not filed until this packet's PR has merged) is the structural protection.

## Acceptance Criteria
- [ ] Four new invariants present in `constitution/invariants.md` with text matching ADR-0017 D9, D6, D5+D10, D8.
- [ ] Assigned numbers verified against the current highest number in the file. Default assumption is 43-46; renumber to next-available if 43-46 are taken (most likely 40-43 if ADR-0016 has not yet landed; possibly higher if other initiatives have grabbed slots in the interim).
- [ ] Each invariant's body cites its source ADR decision.
- [ ] **Each new invariant entry carries the qualifier `(Proposed — this invariant takes effect when ADR-0017 is accepted)`** at the end of its body. ADR-0017 stays at `Status: Proposed` for this entire initiative — the Status flip is a separate post-merge housekeeping step. This pattern matches existing entries 28 (ADR-0010), 31, 32, 33 (ADR-0011) which all carry the same qualifier shape.
- [ ] Existing entries (28, 29-30 reservation, 31-39) are unmodified.
- [ ] If invariant numbers shifted away from 43-46, the corresponding bullets in ADR-0017's Consequences section ("New invariants (proposed for `constitution/invariants.md`)") at lines 128-131 are updated to match.
- [ ] If invariant numbers shifted away from 43-46, the packet 04 source file at `generated/issue-packets/active/adr-0017-honeydrunk-capabilities-standup/04-capabilities-node-scaffold.md` is amended before that packet is filed. After determining the assigned numbers, run `rg -n '\b4[3-6]\b' generated/issue-packets/active/adr-0017-honeydrunk-capabilities-standup/04-capabilities-node-scaffold.md` and update each match to the actually-assigned number. Use ripgrep (`rg`), not `grep`, for predictable boundary semantics on Windows Git Bash. After replacement, re-run the rg query and confirm zero hits at the old numbers. The dispatch plan's filing-order rule guarantees packet 04 has not been filed yet at the time this packet's PR merges.
- [ ] `CHANGELOG.md` Unreleased section updated with the four invariant numbers actually assigned.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0017 D5 (Authorization routes through Auth):** `ICapabilityGuard` resolves authorization decisions by consulting Auth policy via the already-established `HoneyDrunk.Auth` contracts. No new edge in `relationships.json` is added; the Capabilities → Auth dependency already exists. — Source for invariant 45.

**ADR-0017 D6 (Tool-schema versioning principle):** Every registered tool descriptor carries an explicit `version` field. The public registry key is the pair `(name, version)`. The specific versioning *model* is deferred to the scaffold packet, but the principle is fixed at acceptance. — Source for invariant 44.

**ADR-0017 D8 (Contract-shape canary):** A contract-shape canary is added to the Capabilities Node's CI: it fails the build if any of `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, `ICapabilityGuard` change shape without a corresponding version bump. — Source for invariant 46.

**ADR-0017 D9 (Downstream coupling rule):** Downstream Nodes (Agents, Operator, Memory, Knowledge, Evals, and domain Nodes that *expose* tools) compile only against `HoneyDrunk.Capabilities.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.Capabilities` or on `HoneyDrunk.Capabilities.Testing` in production composition. — Source for invariant 43.

**ADR-0017 D10 (Auth dependency is first-class):** Capabilities takes a first-class runtime dependency on HoneyDrunk.Auth for authorization resolution. The default `ICapabilityGuard` implementation cannot produce an allow/deny decision without Auth. — Reinforces invariant 45.

## Dependencies
- `packet:01` — packet 01 lands the catalog surface (especially the four D3 contract names) that invariant 46's canary will guard. Filing 02 before 01 would leave a forward-reference dangling.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0017`, `constitution`

## Agent Handoff

**Objective:** Land four new ADR-0017-derived invariants in the Grid constitution at the next four available numbers, in a single edit. Update ADR-0017 Consequences bullets and packet 04's source file if the assigned numbers shift away from 43-46.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: ADR-0017's "New invariants" section is a placeholder with the qualifier "Numbering is tentative — scope agent finalizes at acceptance." This packet is the finalization.
- Feature: ADR-0017 standup initiative, Wave 1, Packet 02.
- ADRs: ADR-0017 (sole source).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 of this initiative (catalog registration + integration-points + Status flip) must merge first.

**Constraints:**

- **Each new invariant carries `(Proposed — this invariant takes effect when ADR-0017 is accepted)`.** ADR-0017 stays at `Status: Proposed` across the entire initiative — none of the four packets flip its status. Mirror the qualifier pattern from invariants 28 (ADR-0010) and 31/32/33 (ADR-0011) verbatim, substituting `ADR-0017`.
- **Number collision check is a hard gate.** Default 43-46. Verify against the file's highest number at edit time. If shifted, update both ADR-0017's Consequences section (lines 128-131) and packet 04's source file. Do not file partial edits — either all four invariants land at consistent numbers across all three files, or none of them.
- **Section choice (Option A vs Option B) is a stylistic call, not a correctness one.** Pick based on what the file looks like at edit time. Default to Option A (new `## AI Sector — Capabilities Invariants` section).
- **Verbatim alignment with ADR-0017.** The invariant bodies should restate D9/D6/D5+D10/D8 with constitutional voice, not introduce new requirements. Anything novel belongs in a follow-up ADR.
- **Pre-filing amendment to packet 04 is the mechanism** for handling number shifts. Invariant 24: filed packets are immutable, but pre-filing edits are permitted. The dispatch plan's filing-order rule (packet 04 not filed until this packet's PR has merged) is what makes the carve-out applicable.

**Key Files:**
- `constitution/invariants.md` — append four entries (Option A: under a new `## AI Sector — Capabilities Invariants` section; Option B: inside `## AI Invariants`)
- `adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` — only edited if numbers shifted from 43/44/45/46 (lines 128-131 in the Consequences section)
- `generated/issue-packets/active/adr-0017-honeydrunk-capabilities-standup/04-capabilities-node-scaffold.md` — only edited if numbers shifted from 43/44/45/46
- `CHANGELOG.md`

**Contracts:** None.
