# Dispatch Plan — ADR-0020 HoneyDrunk.Agents Standup

**Initiative:** `adr-0020-agents-standup`
**Sector:** AI
**Governing ADR:** [ADR-0020 — Stand Up the HoneyDrunk.Agents Node](../../../../adrs/ADR-0020-stand-up-honeydrunk-agents-node.md) (Proposed 2026-04-19; flips to Accepted after this initiative's PRs merge per the user's ADR acceptance workflow).
**Trigger:** ADR-0020 in the Proposed queue. Flow, Sim, Lore, HoneyHub (when live), the HoneyDrunk.Actions cloud-agent trigger path, and Evals are blocked on `HoneyDrunk.Agents.Abstractions` existing. This initiative builds the agent-runtime substrate that unblocks them.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Agents`)
**Site sync required:** No (scaffold-only).
**Rollback plan:**
- **Pre-tag:** `git revert` of each PR.
- **Post-tag, pre-consumer:** NuGet packages immutable; prefer fix-forward as 0.1.1.
- **Post-consumer:** forward-only.

## Summary

ADR-0020 is the standup ADR for `HoneyDrunk.Agents`. It decides what the Node owns (D1), three package families with a `.Testing` fixture (D2), five exposed interfaces (D3 — `IAgent`, `IAgentExecutionContext`, `IAgentLifecycle`, `IToolInvoker`, `IAgentMemory`; no records at stand-up), the boundary rule against AI/Capabilities/Operator/Memory/Flow (D4), upstream composition rules for tool invocation (D5) and memory (D6), the safety-gate invocation model with Operator (D7), the execution-scope-only state boundary (D8), one-way telemetry to Pulse (D9), the contract-shape canary on four hot-path interfaces (D10), in-process agent registry at stand-up (D11), the function-calling adapter belonging to Agents only (D12), and the `Abstractions` no-third-party-AI-runtime stance (D13).

Agents composes **all three foundation substrates** (AI, Capabilities, Operator) plus Memory at the runtime layer. This makes packet 03 the largest scaffold of the seven initiatives — five contracts, four default runtime implementations (`DefaultAgent` harness, `DefaultAgentLifecycle`, `DefaultToolInvoker` composing Capabilities, `DefaultAgentMemory` composing Memory), the function-calling adapter, the in-memory testing fixture, and the registry.

Four packets land the work:

1. **Architecture catalog registration + integration-points** — confirm five-interface contract set; add `honeydrunk-memory` and `honeydrunk-operator` to `consumes`; add `honeydrunk-actions` to `consumed_by_planned`; fix `repos/HoneyDrunk.Agents/boundaries.md` (`IMemoryScope` is Memory's, not Agents's); fix `repos/HoneyDrunk.Agents/integration-points.md` canary description (Agents→AI is `IChatClient` direct, not "through `IToolInvoker`"); refresh `grid-health.json`, `nodes.json`, the AI sector doc.
2. **Constitution invariants** — seven new invariants from D2/D5/D6, D5, D6, D12, D13, D10 at the next seven free numbers.
2b. **Verify `HoneyDrunk.Agents` repo + local clone (human-only)** — the GitHub repo exists, the local clone exists (LICENSE + README); verify branch protection, seed labels, confirm OIDC.
3. **HoneyDrunk.Agents scaffold** — empty repo to first-shippable. Solution, three packages (`Abstractions`, runtime, `Testing` fixture), five contracts, default `IAgent` harness + `IAgentLifecycle` (in-process registry) + `DefaultToolInvoker` (composes Capabilities) + `DefaultAgentMemory` (composes Memory) + function-calling adapter, in-memory testing fixture, five CI workflow files with contract-shape canary scoped to `HoneyDrunk.Agents.Abstractions`.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-agents-catalog-registration
   └─ Architecture: 02-architecture-agents-invariants
       Blocked by: 01

Wave 2: Verify HoneyDrunk.Agents repo + local clone (human)
   └─ Architecture: 02b-architecture-verify-agents-repo
       Blocked by: 01

Wave 3: Agents repo scaffold
   └─ HoneyDrunk.Agents: 03-agents-node-scaffold
       Blocked by: 01, 02, 02b, ADR-0016#03-ai-node-scaffold,
                   ADR-0017#04-capabilities-node-scaffold,
                   ADR-0018#03-operator-node-scaffold
```

The three cross-initiative blockers are declared in packet 03's `dependencies:` frontmatter so `file-work-items.yml` keeps the Hive board item Blocked until each upstream scaffold issue closes. Memory (ADR-0022) is NOT a hard dep — Memory is the lone substrate Agents may stub with a `DefaultAgentMemory` placeholder no-op (see packet 03 Human Prerequisites).

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + boundaries.md/integration-points fixes](./01-architecture-agents-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add seven new invariants for D2/D5/D6 / D5 / D6 / D12 / D13 / D10](./02-architecture-agents-invariants.md) | Architecture | 1 | Agent | 01 |
| 02b | [Verify HoneyDrunk.Agents repo + local clone (human-only)](./02b-architecture-verify-agents-repo.md) | Architecture | 2 | Human | 01 |
| 03 | [Stand up `HoneyDrunk.Agents` — solution, three packages, contracts, function-calling adapter, CI, in-memory testing fixture](./03-agents-node-scaffold.md) | HoneyDrunk.Agents | 3 | Agent | 01, 02, 02b, ADR-0016 packet 03, ADR-0017 packet 04, ADR-0018 packet 03 |

## Filing-order rule

Packet 03 hard-codes invariant numbers in body and acceptance criteria. **Packet 02 must merge and lock the invariant numbers before packet 03 is filed.** If packet 02's collision check shifts numbers, packet 03 source file is amended pre-filing under invariant 24's carve-out.

## What This Initiative Does **NOT** Deliver

- The downstream consumer Nodes (Flow, Sim, Lore, HoneyHub when live, Actions cloud-agent path) are not delivered here.
- The **function-calling adapter mechanism** (the specific shape — generic adapter keyed by `ModelCapabilityDeclaration`, per-provider adapters behind `IFunctionCallAdapter`, shape-translation layer) is decided **inside packet 03**, per ADR-0020 D12 ("placement pinned, mechanism deferred to scaffold"). Packet 03's executing agent picks one mechanism and ships it.
- Record shapes (`AgentId` value type, lifecycle-phase enums promoted to records, invocation-request shapes) are **deferred to scaffold or to a later ADR** per ADR-0020 D3. Packet 03 picks what is needed and ships those; deeper shape decisions wait for the first downstream consumer.
- Cross-host shared agent registry is deferred per D11; in-process at stand-up.
- Pulse signal ingress into Agents is deferred (emit-only per D9).
- The HoneyDrunk.Memory edge depends on `HoneyDrunk.Memory.Abstractions` existing. If Memory's standup initiative has not landed first, packet 03's `DefaultAgentMemory` implementation is a placeholder no-op with a structured warning and a follow-up packet wires the real composition once Memory ships. This placeholder escape is exclusive to Memory — AI / Capabilities / Operator `.Abstractions` are hard cross-initiative dependencies declared in packet 03's frontmatter and enforced via `file-work-items.yml` `addBlockedBy` wiring.

## AI-sector standup wave sequencing

ADR-0020 (Agents) requires `HoneyDrunk.AI.Abstractions`, `HoneyDrunk.Capabilities.Abstractions`, `HoneyDrunk.Operator.Abstractions`, and `HoneyDrunk.Memory.Abstractions` to exist before packet 03 can compile. The recommended landing order across the seven AI-sector standup initiatives:

1. ADR-0016 (AI) — packets exist
2. ADR-0017 (Capabilities) — packets exist
3. ADR-0018 (Operator) — this initiative's sibling
4. ADR-0021 (Knowledge) — sibling
5. ADR-0022 (Memory) — sibling
6. ADR-0020 (Agents) — **this initiative; requires 1-5 above for packet 03**
7. ADR-0023 (Evals) — depends on Agents
8. ADR-0024 (Flow) — depends on Agents, Operator, Communications
9. ADR-0025 (Sim) — depends on Flow

If Memory or any other upstream Abstractions has not shipped at the time packet 03 of THIS initiative executes, the scaffolding agent ships the corresponding default-implementation as a placeholder no-op + warning and the real composition lands as a follow-up packet. See packet 03 Human Prerequisites.

## Status flip

ADR-0020 stays at `Status: Proposed` for the duration. Scope agent flips after all packets close.

## Filing

`file-work-items.yml` auto-files on push. No manual `gh issue create`. Verify on The Hive.

## Archival

Per ADR-0008 D10, when every packet reaches `Done` and `HoneyDrunk.Agents 0.1.0` is published, the entire folder moves to `archive/`.
