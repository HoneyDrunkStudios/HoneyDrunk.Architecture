# Dispatch Plan — ADR-0018 HoneyDrunk.Operator Standup

**Initiative:** `adr-0018-operator-standup`
**Sector:** AI
**Governing ADR:** [ADR-0018 — Stand Up the HoneyDrunk.Operator Node](../../../../adrs/ADR-0018-stand-up-honeydrunk-operator-node.md) (Proposed 2026-04-19; flips to Accepted after this initiative's PRs merge per the user's ADR acceptance workflow — scope agent flips Status, never on first draft. ADR-0018 carries an additive 2026-05-16 amendment from ADR-0030/0031 relocating `IAuditLog` / `AuditEntry` out of Operator into the new `HoneyDrunk.Audit` Node — this initiative respects that amendment.)
**Trigger:** ADR-0018 in the Proposed queue. Five AI-sector consumers (Agents, Flow, AI, Capabilities, Evals) plus every domain Node that needs policy enforcement on agent-invoked paths are blocked on `HoneyDrunk.Operator.Abstractions` existing. This initiative builds the human-policy-enforcement substrate that unblocks them.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Operator`)
**Site sync required:** No (scaffold-only).
**Rollback plan:**
- **Pre-tag rollback** (before `v0.1.0` is pushed): `git revert` of each PR. Packets 01/02/02b are independent reverts; packet 03 reverts the entire scaffold as a single PR.
- **Post-tag rollback** (after `v0.1.0` is pushed but before downstream Nodes consume): NuGet packages are immutable. Either `dotnet nuget delete` if the packages were just pushed pre-discovery, or fix-forward as `0.1.1`. Practical hard rollback after a tag is messy — prefer fix-forward.
- **After downstream consumers start:** rollback is no longer a clean option; treat any defect as forward-only.

## Summary

ADR-0018 is the standup ADR for `HoneyDrunk.Operator`. It decides what the Node owns (D1), three package families with a `.Testing` fixture (D2), **eight Operator-owned contracts (five interfaces + three records)** plus two more (`IAuditLog`, `AuditEntry`) relocated to HoneyDrunk.Audit per the 2026-05-16 amendment (D3 as amended), the lowercase "operator" disambiguation (D4), Auth layering (D5), App Configuration sourcing (D6), one-way telemetry to Pulse (D7), the event-out approval pattern for Communications (D8), append-only-by-interface audit log — now owned by Audit per the amendment (D9), the contract-shape canary on four hot-path interfaces (D10), the downstream coupling rule (D11), and first-class runtime dependencies on Kernel + Auth + Data (D12).

**Critical amendment to respect:** the 2026-05-16 ADR-0030/0031 amendment relocates `IAuditLog` and `AuditEntry` out of `HoneyDrunk.Operator.Abstractions` into the new `HoneyDrunk.Audit.Abstractions`. Operator is now a **consumer** of those two contracts, not their owner. The other eight Operator contracts (`IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter`, `CostEvent`, `ApprovalRequest`, `ApprovalDecision`) are unaffected and stay Operator-owned. Every packet in this initiative reflects this amendment.

Four packets land the work:

1. **Architecture catalog registration + integration-points** — `contracts.json` (rename `ICostController` → `ICostGuard`; add `IDecisionPolicy`, `ISafetyFilter`; add three Operator-owned records `CostEvent`, `ApprovalRequest`, `ApprovalDecision`; mark `IAuditLog`/`AuditEntry` as relocated to `honeydrunk-audit`); update `relationships.json` `consumes`/`exposes.contracts`/`exposes.packages`/`consumed_by_planned`; refresh `grid-health.json`; tighten prose drift for `ICostController` → `ICostGuard`; add `integration-points.md` and `active-work.md`.
2. **Constitution invariants** — four new invariants from D11, D6, D8, D10 at the next four free numbers (47/48/49/50 assumed; collision check at edit time — current high-water mark in `constitution/invariants.md` is 46). Landed in a new `## AI Sector — Operator Invariants` section (Option A in packet 02).
2b. **Verify `HoneyDrunk.Operator` repo + verify local clone (human-only)** — the GitHub repo exists, the local working tree at `c:/.../HoneyDrunk.Operator/` exists and is a proper git clone (has scaffolding-source materials in `docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`). Confirm branch protection, seed labels, verify OIDC federated credential.
3. **HoneyDrunk.Operator scaffold** — empty repo to first-shippable state. Solution, three packages (`Abstractions`, runtime, `Testing` fixture), eight Operator-owned contracts (`IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter`, `CostEvent`, `ApprovalRequest`, `ApprovalDecision`) inside `HoneyDrunk.Operator.Abstractions`, default runtime implementations, in-memory testing fixture, five CI workflow files including the contract-shape canary on the four hot-path interfaces per D10.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-operator-catalog-registration
   └─ Architecture: 02-architecture-operator-invariants
       Blocked by: 01

Wave 2: Verify HoneyDrunk.Operator repo and local clone (human)
   └─ Architecture: 02b-architecture-verify-operator-repo
       Blocked by: 01

Wave 3: Operator repo scaffold
   └─ HoneyDrunk.Operator: 03-operator-node-scaffold
       Blocked by: 01, 02, 02b
```

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + integration-points](./01-architecture-operator-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add four new invariants for D11 / D6 / D8 / D10](./02-architecture-operator-invariants.md) | Architecture | 1 | Agent | 01 |
| 02b | [Verify HoneyDrunk.Operator repo + clone (human-only)](./02b-architecture-verify-operator-repo.md) | Architecture | 2 | Human | 01 |
| 03 | [Stand up `HoneyDrunk.Operator` — solution, three packages, contracts, CI, in-memory testing fixture](./03-operator-node-scaffold.md) | HoneyDrunk.Operator | 3 | Agent | 01, 02, 02b |

## Filing-order rule

Packet 03 hard-codes invariant numbers (default 47/48/49/50 — current high-water mark in `constitution/invariants.md` is 46) in its body and acceptance criteria. Filed packets are immutable (invariant 24). Therefore:

**Packet 02 cannot be filed until packet 01 has been filed.** Packet 02's `dependencies: ["packet:01"]` makes this explicit at the data layer, and per invariant 24 packet 02 becomes immutable the moment it lands as a GitHub Issue — so the dependency resolves to a `packet:01` issue number that must already exist. The filing pipeline (`file-packets.yml`) processes packets in two-digit-prefix order on each push, so as long as packets 01 and 02 land in the same push the wiring is automatic.

**Packet 02 must be filed, its PR merged, and the assigned invariant numbers locked in `constitution/invariants.md` before packet 03 is filed.** Packet 02b can run in parallel with packet 02. If packet 02's collision check shifts numbers away from 47/48/49/50, the packet 02 source file AND the packet 03 source file MUST be amended in place before push (pre-filing carve-out under invariant 24). Packet 02's Proposed Implementation section carries an exhaustive cross-reference list of every numbered line in packet 03 to keep this rewrite mechanical.

**Race between AI-sector standup initiatives.** ADR-0018, 0020, 0021, 0022, 0023, 0024, 0025 all want the next free invariant numbers. Whichever lands first claims them; the others shift in lockstep. The dispatch plan assumes a serial landing order across the seven AI-sector standup initiatives — see "AI-sector standup wave sequencing" below.

## What This Initiative Does **NOT** Deliver

- The five downstream consumer Nodes (Agents, Flow, AI, Capabilities, Evals) are not delivered here. Operator's stand-up unblocks them; each gets its own standup ADR + initiative.
- `IAuditLog` and `AuditEntry` are explicitly **out of scope** in this initiative per the 2026-05-16 ADR-0030/0031 amendment. They land under the HoneyDrunk.Audit Node standup initiative, not here.
- The approval-notification **transport mechanism** (D8) is deferred to a follow-up packet. The stand-up commitment is the event-out pattern, not the wire shape.
- Pulse signal ingress into Operator is deferred (emit-only at stand-up per D7).
- The first production decision-policy implementations (e.g. an OPA-style rule evaluator) ship as follow-up packets.

## AI-sector standup wave sequencing

The seven AI-sector standup initiatives (ADR-0016 through ADR-0025) all want next-free invariant numbers and all build on each other's `Abstractions` packages. Recommended serial landing order:

1. ADR-0016 (AI) — landed; claimed invariants 44/45/46 in `## AI Invariants`
2. ADR-0017 (Capabilities) — packets exist; claims the next set
3. ADR-0018 (Operator) — this initiative; default claim 47/48/49/50 in a new `## AI Sector — Operator Invariants` section
4. ADR-0020 (Agents) — depends on AI, Capabilities, Operator, Memory, Knowledge `Abstractions` existing
5. ADR-0021 (Knowledge) — depends on AI `Abstractions`
6. ADR-0022 (Memory) — depends on AI, Auth `Abstractions`
7. ADR-0023 (Evals) — depends on AI, Agents, Capabilities, Operator, Knowledge, Memory `Abstractions`
8. ADR-0024 (Flow) — depends on Agents, Operator, Communications `Abstractions`
9. ADR-0025 (Sim) — depends on AI, Flow, Memory, Operator `Abstractions`

Practical ordering: stand up AI + Capabilities + Operator first (the three substrates), then Memory + Knowledge in parallel, then Agents (composes the substrates + Memory + Knowledge), then Evals + Flow + Sim (each composes Agents).

## Status flip

ADR-0018 stays at `Status: Proposed` for the duration of this initiative's PRs. The scope agent flips Status → Accepted after all four packets close, per the user's standing ADR acceptance workflow — not from inside any packet.

## Filing

The `file-packets.yml` workflow auto-files on push to `generated/issue-packets/active/**/*.md`. No manual `gh issue create` commands. Verify by checking The Hive (org Project #4) for the new items and their blocking edges.

## Archival

Per ADR-0008 D10, when every packet reaches `Done` and `HoneyDrunk.Operator 0.1.0` is published to NuGet, the entire `active/adr-0018-operator-standup/` folder moves to `archive/adr-0018-operator-standup/` in a single commit.
