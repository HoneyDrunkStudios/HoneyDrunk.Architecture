# Dispatch Plan — ADR-0030 Grid-Wide Audit Substrate (Capability Acceptance)

**Initiative:** `adr-0030-audit-substrate`
**Sector:** Core
**Governing ADR:** [ADR-0030 — Grid-Wide Audit Substrate](../../../../adrs/ADR-0030-grid-wide-audit-substrate.md) (Proposed 2026-05-16; flips to Accepted after this initiative's PRs merge — packet 01 performs the flip; the scope agent never flips Status on first draft)
**Driven Standup ADR (out of scope here):** [ADR-0031 — Stand Up the HoneyDrunk.Audit Node](../../../../adrs/ADR-0031-stand-up-honeydrunk-audit-node.md) (stays Proposed; scoped in a separate run after this initiative completes)
**Trigger:** ADR-0030 is the capability/decision ADR for the Grid-wide durable, attributable security and action audit substrate. ADR-0031 (the standup ADR, already written) cannot flip to Accepted until ADR-0030 is Accepted. This initiative accepts ADR-0030's Architecture-side decisions so the ADR-0031 standup scoping run can follow cleanly.
**Type:** Single-repo, multi-packet (one repo: `HoneyDrunk.Architecture`). Treated with a dispatch plan because it is an ADR-acceptance initiative with sequenced packets, an explicit cross-ADR coordination obligation, and a deferred follow-on initiative that must not get lost.
**Site sync required:** No. ADR-0030 acceptance is catalog/constitution/context-folder registration only — no public-API surface ships and no Studios website data changes. When `HoneyDrunk.Audit 0.1.0` ships from the later ADR-0031 standup, a site-sync follow-up may be warranted then, not now.
**Merge order (hard):** Packet 01's PR merges to `main` **before** packet 02's PR. `dependencies: ["work-item:01"]` on packet 02 is only a Hive board blocked-by edge — it is not a git merge gate. Packet 02's pre-merge check verifies `catalogs/nodes.json` carries `honeydrunk-audit` and `repos/HoneyDrunk.Audit/invariants.md` exists on `main` before merging. Merging 02 ahead of 01 leaves invariant 44 referencing an unregistered substrate and a dangling forward-reference in `repos/HoneyDrunk.Audit/invariants.md`. Merge order is **01 → 02**; revert order is the inverse (**02 → 01**).
**Rollback plan:**
- **Pre-merge:** standard `git revert` of each PR. Packets 01 and 02 are independent reverts (01 is catalog/context/ADR-amendment; 02 is the single new invariant). Reverting 01 without 02 would orphan invariant 44's substrate reference — revert 02 first if both are being undone.
- **Post-merge, pre-ADR-0031-standup:** the only artifacts are catalog rows, a constitution section, an ADR status flip, an additive ADR-0018 amendment, and a context folder. All are reversible by a follow-up Architecture PR. No NuGet package, no repo, no Azure resource exists yet (the standup is a separate initiative).
- **`file-work-items.yml` lifecycle gotcha:** after these packets move through The Hive, hive-sync may move the source files from `active/` to `completed/` per invariant 37. A `git revert` only undoes content edits, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Summary

ADR-0030 is the **capability/decision** ADR — it records what Grid-wide audit is, where it lives (a new dedicated `HoneyDrunk.Audit` Node in Core, not Operator, not Kernel), why, the Operator contract reconciliation, the one-way Pulse telemetry direction, and the phased-integrity scope discipline (Phase 1 is append-only-by-interface, explicitly **not** tamper-evident; hash-chain/WORM and the tenant-facing forensics Service deferred behind the boundary). It does **not** scaffold the Node — that is governed by the separate standup ADR (ADR-0031).

Two packets land the Architecture-side acceptance:

1. **Accept ADR-0030** — register the `honeydrunk-audit` Node and its four new dependency edges across `nodes.json` / `relationships.json` / `contracts.json` / `grid-health.json` / `modules.json`; add the Core-sector Audit row to `sectors.md`; flip the ADR-0030 index + header to Accepted; append the additive amendment note to ADR-0018 (relocating `IAuditLog`/`AuditEntry` out of Operator, reclassifying Operator to consumer-not-owner); mark Operator's `IAuditLog` relocated in `contracts.json`; create the `repos/HoneyDrunk.Audit/` context folder; register the initiative + roadmap bullet.
2. **Audit-emission boundary invariant** — add invariant **44** in a new `## Audit Invariants` section, with an explicit reservation note that **45/46** belong to the ADR-0031 standup and are deliberately not landed here.

## Wave Diagram

```
Wave 1: ADR-0030 Architecture acceptance (sequenced within the wave)
   ├─ Architecture: 01-architecture-adr-0030-acceptance
   │     (catalog registration, sectors row, ADR index flip, ADR-0018 additive
   │      amendment, repos/HoneyDrunk.Audit/ context folder, trackers)
   └─ Architecture: 02-architecture-audit-emission-invariant
         Blocked by: 01 (invariant 44 references the substrate + context folder
                         that packet 01 registers; ADR-0030 flip happens in 01)
```

Both packets target `HoneyDrunk.Architecture` and touch different files (catalogs/context/ADR-amendment vs. the constitution). They are kept as separate packets to honor the one-logical-change rule and to give a clean review surface for each (catalog + ADR-0018 amendment is one mental model; invariant numbering with the cross-ADR reservation is another). They may be filed in the same push — packet 02's `dependencies: ["work-item:01"]` wires the blocking edge automatically.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Accept ADR-0030 — catalog registration, sectors, ADR-0018 amendment, context folder, trackers](./01-architecture-adr-0030-acceptance.md) | Architecture | 1 | Agent | — |
| 02 | [Add the audit-emission boundary invariant (44); reserve 45/46 for ADR-0031](./02-architecture-audit-emission-invariant.md) | Architecture | 1 | Agent | 01 |

Both packets are `Actor=Agent`. Each carries a `## Human Prerequisites` section, but the prerequisites are confirm-before-merge sanity checks (the invariant-numbering split; the ADR-0018 amendment wording), not actions on the agent's critical path — so neither is `human-only`.

## Cross-ADR Invariant Numbering — the coordination obligation

The user's explicit constraint: the scope agent assigns final invariant numbers at acceptance, and ADR-0030 + ADR-0031 must not double-number the constitution.

- ADR-0030 proposes **one** invariant — the audit-emission boundary (auditable security events emitted to the Audit substrate via `IAuditLog` on a durable channel separate from observability). → assigned **44**, landed by packet 02 of this initiative.
- ADR-0031 restates **two** invariants for the stand-up's contract-coupling and canary rules:
  - Audit downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions` (ADR-0031 D9). → reserved **45**, landed by the ADR-0031 standup initiative.
  - The Audit Node CI must include a contract-shape canary for `IAuditLog`/`IAuditQuery`/`AuditEntry` (ADR-0031 D8). → reserved **46**, landed by the ADR-0031 standup initiative.

ADR-0031's own Consequences section already states that the audit-emission boundary invariant "is not restated here to avoid double-numbering. The scope agent assigns final numbers across both ADRs at acceptance." This dispatch plan records the allocation: **44 → ADR-0030 (here); 45 → ADR-0031 D9; 46 → ADR-0031 D8 (both there)**. Packet 02 writes a reservation note in `constitution/invariants.md` for 45/46 so the ADR-0031 scoping run has an unambiguous, pre-allocated home and cannot accidentally collide or renumber.

Highest existing invariant number at scoping time is **43**. If a newer ADR grabs 44/45/46 between authoring and landing, packet 02's hard collision-check shifts the allocation and updates the ADR-0030 cross-reference and `repos/HoneyDrunk.Audit/invariants.md`; the 45/46 reservation shifts with it.

## What This Initiative Does NOT Deliver

This initiative accepts the **capability/decision** ADR only. Explicitly out of scope (all governed by the separate ADR-0031 standup, scoped in a later run the user will request):

- **The HoneyDrunk.Audit GitHub repo.** Public by Grid default; created by an ADR-0031-governed step.
- **The scaffold** — `HoneyDrunk.Audit.slnx`, `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data`, `.Tests` projects, `HoneyDrunk.Standards` wiring, CI via Actions shared workflows, `README`/`CHANGELOG`/`LICENSE`, the Data-backed append-only store, the in-memory fixture, the end-to-end smoke test.
- **The three contracts as code** (`IAuditLog`, `IAuditQuery`, `AuditEntry`). This initiative registers them in `contracts.json` only.
- **The contract-shape canary in CI** (ADR-0031 D8) and its constitutional invariant (reserved 46).
- **The Audit downstream Abstractions-only coupling invariant** (ADR-0031 D9, reserved 45).
- **The Node's own managed identity** (ADR-0031 D5).
- **HoneyDrunk.Auth wired as the first emitter** (ADR-0030 D6 — a separate packet against the stood-up Abstractions).
- **HoneyDrunk.Operator reconciled as consumer/emitter** (ADR-0030 D5 — a separate packet; the *catalog/ADR-0018-amendment* side of that reconciliation IS in packet 01, but the Operator *code* re-targeting is not).
- **Hash-chain / WORM tamper-evidence** (ADR-0030 D8a — deferred behind the boundary, gated on a stated trigger).
- **The deployable tenant-facing forensics read Service** (ADR-0030 D8b — deferred behind the boundary, gated on a stated trigger).

The dependency relationship is explicit so the ADR-0031 scoping run follows cleanly: **ADR-0031's checklist gates its acceptance on ADR-0030 being Accepted.** This initiative is what makes ADR-0030 Accepted. When both packets here are Done and ADR-0030 reads Accepted, the user can request an ADR-0031 standup scoping run with a registered Node, an accepted driving ADR, a populated `repos/HoneyDrunk.Audit/` context folder, and invariants 45/46 pre-reserved as the clean base.

## Phase Mapping (ADR-0030 "If Accepted" checklist → packets)

ADR-0030's "If Accepted — Required Follow-Up Work" checklist, mapped:

| ADR-0030 checklist item | Packet |
|---|---|
| Add `honeydrunk-audit` to `nodes.json` | 01 (Part A) |
| Add `honeydrunk-audit` + edges to `relationships.json` | 01 (Part B) |
| Add `IAuditLog`/`IAuditQuery`/`AuditEntry` to `contracts.json`; mark Operator's pair relocated | 01 (Part C) |
| Add `honeydrunk-audit` to `grid-health.json` | 01 (Part D) |
| Add `honeydrunk-audit` to `modules.json` (two package families) | 01 (Part E) |
| Update `sectors.md` Core table with the Audit row | 01 (Part F) |
| Add the audit-emission boundary invariant | **02** |
| Append additive amendment note to ADR-0018 | 01 (Part H) |
| Scaffold governed by ADR-0031 — not bundled here | (out of scope — separate initiative) |
| Scope agent assigns final invariant numbers at acceptance | 02 (assigns 44; reserves 45/46 for ADR-0031) |

The "create the `repos/HoneyDrunk.Audit/` context folder" obligation appears in ADR-0031's checklist, not ADR-0030's, but it is landed here in packet 01 (Part I) deliberately: the context folder is a pure-knowledge artifact that gives the ADR-0031 scoping run an anchor, and it carries no scaffold/code commitment. ADR-0031's own checklist copy of that item becomes a verify-not-create step when the standup is scoped.

## Sequencing vs the ADR-0031 standup initiative

The ADR-0031 standup is a **separate initiative**, scoped in a later run. It must come after this one because:

1. ADR-0031's "Done When" checklist item 1 is literally "ADR-0030 (Grid-Wide Audit Substrate) is Accepted (driving decision; this stand-up does not flip Accepted before it)."
2. ADR-0031's scaffold packet compiles `IAuditLog`/`IAuditQuery`/`AuditEntry` against the catalog surface packet 01 registers.
3. ADR-0031's two invariants (45/46) are pre-reserved by packet 02 — the standup scoping run reads the reservation note and lands them at the allocated numbers without a collision check race.

If the ADR-0031 standup is scoped before this initiative's PRs merge by accident, it has no Accepted driving ADR and no registered Node — it should be parked until this initiative completes.

## Archival

Per ADR-0008 D10, when both packets reach `Done` on The Hive and ADR-0030 reads `Accepted`, the entire `active/adr-0030-audit-substrate/` folder moves to the completed/archive location in a single commit. Partial archival is forbidden. The hive-sync agent moves individual closed packet files per invariant 37 (per-packet lifecycle); initiative-level archival is the post-completion sweep.

## Notes

- **Why this is the capability ADR's initiative, not the standup's.** The user explicitly asked to scope ADR-0030 first and to make the ADR-0031 dependency explicit without re-scoping ADR-0031. This dispatch plan and its two packets do exactly that: they land ADR-0030's Architecture-side decisions and stop at the boundary the user drew. The standup is named, mapped, and dependency-pinned — but not scoped.
- **Why the ADR-0018 amendment is in packet 01, not its own packet.** The amendment is a few additive lines appended to ADR-0018 recording the relocation/reclassification. It is part of ADR-0030's "If Accepted" checklist and is conceptually inseparable from the `contracts.json` relocation marking (Part C) — splitting them across packets would let the catalog say "relocated" while ADR-0018 still reads "owned," a transient inconsistency. Kept together, reviewed together.
- **No Azure provisioning in scope.** `HoneyDrunk.Audit` is a library Node at stand-up; the Node's own managed identity (ADR-0031 D5) is an ADR-0031-standup concern, not this initiative's. No Key Vault, no Container App, no resource group here.
- **No new ADR drafted.** ADR-0030 and ADR-0031 already exist. This initiative does not author a third ADR — it accepts ADR-0030 and leaves ADR-0031 Proposed for its own scoping run.
- **Status flip happens in packet 01, after merge.** ADR-0030 stays Proposed in the draft through this scoping run. Packet 01 performs the Proposed → Accepted flip as part of its acceptance work; that lands when packet 01's PR merges. The scope agent never flips Status on first draft (the user's standing ADR acceptance workflow).

## Filing

The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/work-items/active/**/*.md`. No `gh issue create` commands in this plan — the pipeline files the issues, adds them to The Hive (org Project #4), sets Status/Wave/Node/Tier/Actor/Initiative/ADR fields from frontmatter, and wires the `work-item:01 → work-item:02` `addBlockedBy` edge from packet 02's `dependencies:` frontmatter. Verify after push by checking The Hive for the two new items and the blocking edge — not by reading the workflow log.

**Per the user's instruction: do not file yet.** These packets are written for review. Filing happens on push to `main` once the user approves.
