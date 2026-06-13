---
name: Documentation
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "ai", "adr-0082", "wave-3"]
dependencies: ["work-item:01"]
adrs: ["ADR-0082", "ADR-0016", "ADR-0017", "ADR-0018", "ADR-0019", "ADR-0020", "ADR-0021", "ADR-0022", "ADR-0023", "ADR-0024", "ADR-0025"]
accepts: ADR-0082
wave: 3
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Chore: Author `infrastructure/walkthroughs/node-standup-ai-seed.md` — per-class walkthrough for AI Seed (scaffold-only) standups

## Summary

Author the AI Seed per-class walkthrough at `infrastructure/walkthroughs/node-standup-ai-seed.md` per ADR-0082 D7. This is the smallest walkthrough — AI Seed standups are Phase A only (catalog rows + context folder + sector row + nothing else). Composes against `constitution/node-standup.md` (packet 01). Explicitly names the promotion gate from `signal: "seed"` (Phase A only) to a Core .NET class standup (the full three-phase procedure) when the per-Node scaffold packet lands.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

AI Seed is the class for "cataloged but not yet stood up" Nodes — the nine AI-sector Nodes (per ADR-0016 through ADR-0025) were created as a wave with `signal: "seed"` and `done: false` long before their per-Node scaffold packets landed. The Seed state lets the Grid acknowledge the Node's existence (sector membership, relationships graph, planned contracts) without paying the full standup cost up front.

Without a dedicated walkthrough, future AI-sector standups (or future cataloged-then-stood-up Nodes in any sector) re-derive what Seed entails. The walkthrough also makes the **promotion gate** explicit — when an AI Seed Node is ready to be stood up, the per-Node scaffold packet flips `signal: "Live"` and `done: true` and runs the full Core .NET (or appropriate) class procedure from Phase B.

## Proposed Implementation

### `infrastructure/walkthroughs/node-standup-ai-seed.md` — new walkthrough

```markdown
# Node Standup — AI Seed (scaffold-only)

**Applies to:** ADR-0082 D5 w (the AI Seed class-specific step — Phase A only).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure)
- `infrastructure/walkthroughs/node-standup-core-dotnet.md` (the *promotion* target — when AI Seed flips to scaffolded, the full Core .NET walkthrough runs from Phase B)
**Related invariants:** {N1} (binds only on first non-bootstrap PR — AI Seed has no repo and no PR, so {N1} is not yet load-bearing; the catalog-state and context-folder items 1–6 of {N1} do apply now).

## Goal

Catalog a planned AI-sector (or other sector) Node before it has been stood up. Reserve sector membership, relationships-graph slots, and the planned contract surface so the Grid knows the Node exists and so cross-cutting work (ADR drafts, capability planning, AI router routing tables) can reference the Node by name.

- Class: `ai-seed`.
- Output: a Node row in `catalogs/nodes.json` with `signal: "seed"` and `done: false`, edges in `catalogs/relationships.json`, a row in `catalogs/grid-health.json`, a five-file context folder at `repos/{NodeName}/`, and a sector row in `constitution/sectors.md` with `Signal: Seed`. **No GitHub repo, no CI, no managed identity, no scaffold packet.**

## What is NOT in scope for AI Seed

- **No GitHub repo creation.** AI Seed is Phase A only. Phase B (repo creation) and Phase C (scaffold) happen later, when the per-Node scaffold packet lands and the class is promoted from AI Seed to Core .NET (or appropriate target class).
- **No CI workflows.** No `pr.yml`, no `release.yml`, no nightlies. There is no repo to attach them to.
- **No managed identity, no OIDC federated credential, no Key Vault, no App Configuration, no Container App, no Bicep.** All deferred to the post-promotion full standup.
- **No branch protection, no label seeding, no `.honeydrunk-review.yaml`, no `.coderabbit.yaml`, no README/CHANGELOG/LICENSE, no `copilot-instructions.md`, no `CLAUDE.md`, no `pr.yml`.** All deferred.
- **No org-secret repo binding.** No repo, no workflows that consume secrets, no binding needed.

## Phase A (only)

This is the entire AI Seed procedure. One Architecture work-item:

1. **Catalog rows.** Add the Node row to `catalogs/nodes.json` with:
   - `signal: "seed"`
   - `done: false`
   - The planned `cluster`, `energy`, `priority`, `flow`, `tags`, `long_description`, `foundational`, `strategy_base`, `tier`, `time_pressure`, `cooldown_days` per existing AI-sector precedent.
   - `repo`: leave as `null` or omit until the post-promotion scaffold packet adds the GitHub URL.
2. **Relationships edges.** Add `consumes`/`consumed_by` edges to `catalogs/relationships.json` for every planned dependency. Edges must be ADR-pinned (per Invariant 4 — DAG only, no cycles). For AI-sector Seeds the typical upstream is `HoneyDrunk.AI.Abstractions` per Invariant 44; downstream consumers depend on the Seed's planned `.Abstractions`.
3. **Grid-health row.** Add the Node row to `catalogs/grid-health.json` with contract surface, canary expectation, DR tier per ADR-0036.
4. **Context folder.** Create the five-file folder at `repos/{NodeName}/`:
   - `overview.md` — what the Node will do once stood up. Capability description per the source ADR.
   - `boundaries.md` — what it does NOT do. Boundary rules cross-referenced to the relevant invariants.
   - `invariants.md` — the invariants the Node will enforce (typically a contract-shape canary obligation per Invariant 46 / 49 / et al. once the `.Abstractions` package exists).
   - `active-work.md` — empty stub at Seed time; populated when the scaffold initiative starts.
   - `integration-points.md` — the planned upstream/downstream surfaces with the relationships-graph IDs.
5. **Sector row.** Add a row to `constitution/sectors.md` for the sector (AI for AI-sector Seeds) with `Signal: Seed`.
6. **Standup ADR registered.** The Seed-creating ADR (e.g., ADR-0016 through ADR-0025 for the AI Seeds) is registered in `adrs/` and `adrs/README.md` if it is a per-Node ADR; the multi-Seed wave ADR (single ADR creating many Seeds, as ADR-0016 did) is also registered. The ADR has `**Status:** Accepted` if it is the Seed-creating decision; an `If Accepted — Required Follow-Up Work` section lists "Per-Node scaffold packet when ready to promote".

(No Phase B. No Phase C. AI Seed lives in this state until the operator decides to scaffold the Node.)

## Promotion to scaffolded

When the AI Seed is ready to be stood up:

1. The operator (or the scope agent for an initiative) decides the target class — almost always **Core .NET Abstractions+Runtime** for AI-sector Nodes (per ADR-0044 D8's downstream-AI-Abstractions-only coupling rule).
2. A new initiative is opened with a per-Node scaffold packet (`03-{node}-node-scaffold.md` shape per ADR-0031 precedent).
3. Phase B and Phase C run from `node-standup-core-dotnet.md` (or appropriate target-class walkthrough).
4. The scaffold PR flips the catalog Node row from `signal: "seed"` / `done: false` to `signal: "Live"` / `done: true` and sets the `repo` field to the new GitHub URL. The sector row is flipped from `Signal: Seed` to `Signal: Live`.
5. Invariant {N1} (node-registration-mandatory) is now load-bearing — the *first non-bootstrap PR* after the scaffold merges binds it.

## Promotion gate — explicit checks before scaffolding

Before promoting an AI Seed:
- The per-Node ADR exists (if no per-Node ADR yet, draft one — the multi-Seed wave ADR alone is not sufficient grounds for scaffold work; per-Node scope decisions are captured in a per-Node ADR).
- Upstream contracts the Node will consume are stable enough to compile against (typically `HoneyDrunk.AI.Abstractions` v0.X stable surface).
- Downstream consumers know they will be unblocked when the scaffold lands (relationships-graph downstream edges have ADRs referencing the scaffolded Node).
```

## Affected Files

- `infrastructure/walkthroughs/node-standup-ai-seed.md` (new)

## NuGet Dependencies

None.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`.

## Acceptance Criteria

- [ ] `infrastructure/walkthroughs/node-standup-ai-seed.md` exists with the structure above
- [ ] "What is NOT in scope" section is explicit — no repo, no CI, no infra, no scaffold-time artifacts
- [ ] Phase A is the entire procedure; six steps are enumerated (catalog rows, relationships edges, grid-health row, context folder, sector row, ADR registration)
- [ ] Promotion-to-scaffolded section names the catalog/sector flips, the {N1}-binding effect, and the typical target class for AI-sector Seeds (Core .NET Abstractions+Runtime)
- [ ] Promotion gate is named — per-Node ADR exists, upstream contracts stable, downstream consumers ready
- [ ] Companion docs link `constitution/node-standup.md` and `node-standup-core-dotnet.md` (the typical promotion target)
- [ ] Repo-level `CHANGELOG.md` updated for the new walkthrough

## Human Prerequisites

None.

## Referenced ADR Decisions

**ADR-0082 D2** — AI Seed class; Phase A only; promotes to Core .NET when scaffold packet lands.
**ADR-0082 D5 w** — Phase A only specification.
**ADR-0082 D7** — Walkthrough unlocked by acceptance.
**ADR-0016 through ADR-0025** — The nine AI-sector Nodes that established the Seed precedent.

## Constraints

- **Smallest walkthrough.** AI Seed is intentionally minimal; the walkthrough must not invent steps that ADR-0082 does not commit to.
- **Promotion path is named, not prescribed in detail.** The walkthrough points at `node-standup-core-dotnet.md` for the post-promotion Phase B and C; it does not re-derive that content.
- **{N1} binding clarified.** Items 1–6 of {N1} (catalog state and context folder) apply at Seed time; items 7–10 (repo-level) do not bind until the scaffold lands and the first feature PR appears.
- **PR body metadata.** Strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

## Labels

`chore`, `tier-2`, `meta`, `docs`, `ai`, `adr-0082`, `wave-3`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/node-standup-ai-seed.md` — the smallest standup walkthrough (Phase A only) plus the promotion-to-scaffolded gate.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Codify the AI Seed precedent set by ADR-0016 through ADR-0025 so future Seed-then-scaffold Nodes have a clear recipe.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 3.
- ADRs: ADR-0082 (D2, D5 w, D7), the nine AI-sector ADRs for precedent.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (canonical procedure doc).

**Constraints:**
- Smallest walkthrough; no invented steps beyond ADR-0082 D5 w.
- Promotion target is named (typically Core .NET Abstractions+Runtime) but the walkthrough does not re-derive Phase B/C — it points at the Core walkthrough.
- {N1} binding is clarified — Seed binds items 1–6; repo-level items 7–10 bind post-scaffold.
- PR body carries strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

**Key Files:**
- `infrastructure/walkthroughs/node-standup-ai-seed.md` (new)

**Contracts:** None changed.
