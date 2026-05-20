---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0020", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0020"]
accepts: ADR-0020
wave: 1
initiative: adr-0020-agents-standup
node: honeydrunk-agents
---

# Chore: Add ADR-0020's seven new invariants to the Grid constitution

## Summary

Add seven new invariants to `constitution/invariants.md` derived from ADR-0020's Consequences section: downstream-coupling (D2/D5/D6), no-direct-model-providers (D5/D9), no-direct-tool-implementations (D5/D9), no-direct-Memory-writes (D6/D8), function-calling-loop-lives-in-Agents-only (D12), Abstractions-no-third-party-AI-runtime (D13), and contract-shape-canary-on-four-hot-paths (D10).

Default-assigned numbers **51, 52, 53, 54, 55, 56, 57** — the next seven free slots after ADR-0016 (44/45/46 already landed in `## AI Invariants`), ADR-0017 (43-46, currently colliding with ADR-0016 — shifts at edit time), ADR-0018 (44-47, also colliding — shifts), ADR-0030 (44 landed in `## Audit Invariants`), and ADR-0031 (45-46 reserved in `## Audit Invariants`). Collision check at edit time decides actual numbers. Parallel downstream initiatives (ADR-0021/0022/0023/0024/0025) currently default to 55-92, so any shift in this packet must also be communicated through `adr-0020-agents-standup/03-agents-node-scaffold.md` updates per invariant 24's pre-filing carve-out.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0020 explicitly delegates final invariant numbering to the scope agent at acceptance time. Seven rules govern Agents:

- **Downstream coupling.** Composition against `HoneyDrunk.Agents` runtime and `HoneyDrunk.Agents.Testing` is a host-time / test-time concern.
- **No direct model providers.** Inference flows through `IChatClient` from AI; no Node uses provider SDKs directly.
- **No direct tool implementations.** Tool invocations flow through `IToolInvoker` (which composes Capabilities).
- **No direct persistent agent-state writes.** Memory access flows through `IAgentMemory` (which composes Memory).
- **Function-calling loop lives in Agents only.** No other AI-sector Node may introduce an equivalent loop of "model → tool-call → next model call."
- **Abstractions has no third-party AI-runtime compile-time dependencies.** Microsoft.Extensions.AI, provider SDKs, agent-framework libraries: not in `HoneyDrunk.Agents.Abstractions`.
- **Contract-shape canary on four hot-path interfaces.** `IAgent`, `IAgentExecutionContext`, `IToolInvoker`, `IAgentMemory`.

## Proposed Implementation

### `constitution/invariants.md` — append seven new entries

Default-assigned numbers 51-57. Use Option A (new `## AI Sector — Agents Invariants` section) if the layout supports it; else Option B (append inside the existing `## AI Invariants` section, after the highest-numbered entry). Mark each with `(Proposed — this invariant takes effect when ADR-0020 is accepted)`.

```markdown
## AI Sector — Agents Invariants

51. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Agents.Abstractions`.**
    Composition against `HoneyDrunk.Agents` and `HoneyDrunk.Agents.Testing` is a host-time (and test-time) concern. Test projects may reference `HoneyDrunk.Agents.Testing` for in-memory fixtures; production projects must not. See ADR-0020 D2, D5, D6 (Proposed — this invariant takes effect when ADR-0020 is accepted).

52. **Agents never call model providers directly.**
    All inference flows through `IChatClient` from `HoneyDrunk.AI.Abstractions`. Agent code that imports a provider SDK (`OpenAI`, `Anthropic.SDK`, `Azure.AI.OpenAI`, etc.) is a build-time violation. This extends `repos/HoneyDrunk.Agents/invariants.md` item 4 to the Grid level. See ADR-0020 D5, D9 (Proposed — this invariant takes effect when ADR-0020 is accepted).

53. **Agents never call tool implementations directly.**
    All tool invocations flow through `IToolInvoker`, which composes Capabilities's `ICapabilityRegistry` and `ICapabilityInvoker` and applies `ICapabilityGuard`. This extends `repos/HoneyDrunk.Agents/invariants.md` item 5 to the cross-Node boundary level. See ADR-0020 D5 (Proposed — this invariant takes effect when ADR-0020 is accepted).

54. **Agents never write persistent agent state directly.**
    All memory access flows through `IAgentMemory`, which composes Memory's `IMemoryStore` and `IMemoryScope`. Execution-scope state stays on `IAgentExecutionContext` and is disposed when the execution ends; anything that must survive the execution is written through `IAgentMemory`. See ADR-0020 D6, D8 (Proposed — this invariant takes effect when ADR-0020 is accepted).

55. **The function-calling loop (model tool-call output → `IToolInvoker` invocations → next inference call) lives in the `HoneyDrunk.Agents` runtime package and nowhere else.**
    No other AI-sector Node may introduce an equivalent loop. The loop composes inference (AI), tool dispatch (Agents → Capabilities), and execution state (`IAgentExecutionContext`); putting it elsewhere drags two foreign Nodes' concerns into the host. See ADR-0020 D12 (Proposed — this invariant takes effect when ADR-0020 is accepted).

56. **`HoneyDrunk.Agents.Abstractions` takes no third-party AI-runtime compile-time dependencies.**
    `Microsoft.Extensions.AI`, model-provider SDKs, agent-framework libraries (LangChain, Semantic Kernel, etc.) are forbidden in the Abstractions package. The runtime package may take them where the function-calling adapter or default implementations genuinely benefit, but Abstractions stays clean so downstream consumers do not transit external version pins. See ADR-0020 D13 and `repos/HoneyDrunk.Agents/invariants.md` item 1 (Proposed — this invariant takes effect when ADR-0020 is accepted).

57. **The HoneyDrunk.Agents Node CI must include a contract-shape canary that fails the build on shape drift to `IAgent`, `IAgentExecutionContext`, `IToolInvoker`, or `IAgentMemory` without a corresponding version bump.**
    These four are the hot-path abstractions every downstream consumer (Flow, Sim, Lore, HoneyHub when live, the Actions cloud-agent trigger path, Evals) compiles against. Accidental shape drift on any of them breaks every Node that runs an agent. The canary makes this a compile-time failure at Agents's own CI. See ADR-0020 D10 (Proposed — this invariant takes effect when ADR-0020 is accepted).
```

### Collision-check rule

The current state of `constitution/invariants.md` (verified at packet-authoring time, 2026-05-20) is:

- `## AI Invariants` section already occupies **44**, **45**, **46** (ADR-0016, Accepted — these are in the file as of today). 47 is currently free in that section.
- `## Audit Invariants` section already occupies **44** (ADR-0030 packet 02, Accepted) with **45** and **46** held by a reservation paragraph for the ADR-0031 standup.

Competing in-flight standup initiatives currently pre-claim:

- **ADR-0017 Capabilities** packet 02: defaults 43-46 — collides with ADR-0016 (which now holds 44-46); ADR-0017 must shift at its own edit time per its collision rule.
- **ADR-0018 Operator** packet 02: defaults 44-47 — collides with ADR-0016; ADR-0018 must shift.
- **ADR-0030 Audit substrate**: claimed 44 in `## Audit Invariants` (landed).
- **ADR-0031 Audit Node standup**: claims 45-46 (reserved in `## Audit Invariants`).
- **ADR-0021 Knowledge** packet 02: defaults 55-59 — collides with this packet's default of 51-57 if both land in the same window.
- **ADR-0022 Memory** packet 02: defaults 60-66.
- **ADR-0023 Evals** packet 02: defaults 67-73.
- **ADR-0024 Flow** packet 02: defaults 74-82.
- **ADR-0025 Sim** packet 02: defaults 83-92.

Before committing, the executing agent runs `rg -n '^\d+\.\s\*\*' constitution/invariants.md` and:

1. **Finds the highest currently-occupied number across all sections** (currently 46 in `## AI Invariants` and 46 in `## Audit Invariants`'s reservation note). The hard high-water mark is therefore 46.
2. **Picks the next seven monotonically free integers** that no other already-landed section claims. With current state, the next free range is **51-57** (skipping 47-50 to leave headroom for ADR-0017 / ADR-0018 if they land first and shift into 47-50, since both their PRs will pre-empt this packet's PR's view of the file).
3. **If ADR-0017 and ADR-0018 have already landed and consumed some of 47-50**, the executing agent picks the next free range above the new high-water mark (e.g. 51-57, 55-61, etc., depending on what's already in the file).
4. **If ADR-0021 Knowledge has landed first and consumed 55-59**, shift further to 58-64 or whatever next seven free integers are available above the new high-water mark, and update lockstep:
   - `adrs/ADR-0020-stand-up-honeydrunk-agents-node.md` Consequences "New invariants" section — replace 48-54 / 51-57 with the assigned numbers.
   - `generated/issue-packets/active/adr-0020-agents-standup/03-agents-node-scaffold.md` — `rg -n '\b5[1-7]\b' …` each match in the default-naming convention, replace with assigned number. Pre-filing carve-out under invariant 24 applies.

Use `rg`, not `grep`.

### `CHANGELOG.md`

Append (substitute actual assigned numbers): `Architecture: Add invariants 51-57 (Agents downstream coupling, no-direct-model-providers, no-direct-tool-impls, no-direct-Memory-writes, function-calling-loop-in-Agents-only, Abstractions-no-third-party-AI-runtime, contract-shape canary) per ADR-0020 D2/D5/D6/D9/D12/D13/D10.`

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0020-stand-up-honeydrunk-agents-node.md` (only on shift)
- `generated/issue-packets/active/adr-0020-agents-standup/03-agents-node-scaffold.md` (only on shift)
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] Verbatim restatement of D2/D5/D6/D9/D12/D13/D10 — no new requirements.

## Acceptance Criteria
- [ ] Seven new invariants present in `constitution/invariants.md` matching ADR-0020.
- [ ] Numbers verified against the current file state via `rg -n '^\d+\.\s\*\*' constitution/invariants.md`; default 51-57; shifted if upstream sibling initiatives (ADR-0017/0018/0021) have consumed any of those slots.
- [ ] Each invariant carries `(Proposed — this invariant takes effect when ADR-0020 is accepted)`.
- [ ] On number shift, ADR-0020 Consequences + packet 03 source updated in lockstep before packet 03 is filed.
- [ ] `CHANGELOG.md` updated.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0020 D2/D5/D6:** Three packages; tool invocation composes upstream; memory access composes upstream. Source for invariant 51 (default).

**ADR-0020 D5, D9:** Agents never call model providers or tool implementations directly. Sources for invariants 52, 53 (default).

**ADR-0020 D6, D8:** Memory access via `IAgentMemory`; execution-scope state only on `IAgentExecutionContext`. Source for invariant 54 (default).

**ADR-0020 D12:** Function-calling loop lives in Agents only. Source for invariant 55 (default).

**ADR-0020 D13:** Abstractions takes no third-party AI-runtime compile-time deps. Source for invariant 56 (default).

**ADR-0020 D10:** Contract-shape canary on `IAgent`, `IAgentExecutionContext`, `IToolInvoker`, `IAgentMemory`. Source for invariant 57 (default).

## Dependencies
- `packet:01`

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0020`, `constitution`

## Agent Handoff

**Objective:** Land seven new ADR-0020-derived invariants at the next available numbers.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01.

**Constraints:**

- Each invariant carries `(Proposed — this invariant takes effect when ADR-0020 is accepted)`.
- Default 51-57; shift on collision; update ADR-0020 Consequences + packet 03 in lockstep.
- Pre-filing amendment to packet 03 permitted under invariant 24.
- Use `rg`, not `grep`.

**Key Files:** `constitution/invariants.md`; conditional ADR-0020 + packet 03; `CHANGELOG.md`.

**Contracts:** None.
