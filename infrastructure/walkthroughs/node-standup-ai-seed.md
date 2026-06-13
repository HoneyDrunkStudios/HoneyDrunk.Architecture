# Node Standup — AI Seed (scaffold-only)

**Applies to:** ADR-0082 D5 w (the AI Seed class-specific step — Phase A only).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure)
- `infrastructure/walkthroughs/node-standup-core-dotnet.md` (the *promotion* target — when an AI Seed flips to scaffolded, the full Core .NET walkthrough runs from Phase B)
**Related invariants:** 102 (node-registration-mandatory — binds only on the first non-bootstrap PR; an AI Seed has no repo and no PR, so 102 is not yet load-bearing, but items 1–6 of its registration checklist — the catalog rows, grid-health row, and context folder — do apply now).

## Goal

Catalog a planned AI-sector (or other-sector) Node before it has been stood up. Reserve sector membership, relationships-graph slots, and the planned contract surface so the Grid knows the Node exists and so cross-cutting work (ADR drafts, capability planning, AI router routing tables) can reference the Node by name.

- Class: `ai-seed`.
- Output: a Node row in `catalogs/nodes.json` with `signal: "seed"` and `done: false`, edges in `catalogs/relationships.json`, a row in `catalogs/grid-health.json`, a five-file context folder at `repos/{NodeName}/`, and a sector row in `constitution/sectors.md` with `Signal: Seed`. **No GitHub repo, no CI, no managed identity, no scaffold packet.**

## What is NOT in scope for AI Seed

- **No GitHub repo creation.** AI Seed is Phase A only. Phase B (repo creation) and Phase C (scaffold) happen later, when the per-Node scaffold packet lands and the class is promoted from AI Seed to Core .NET (or the appropriate target class).
- **No CI workflows.** No `pr.yml`, no `release.yml`, no nightlies — there is no repo to attach them to.
- **No managed identity, no OIDC federated credential, no Key Vault, no App Configuration, no Container App, no Bicep.** All deferred to the post-promotion full standup.
- **No branch protection, no label seeding, no `.honeydrunk-review.yaml`, no `.coderabbit.yaml`, no README/CHANGELOG/LICENSE, no `copilot-instructions.md`, no `CLAUDE.md`, no `pr.yml`.** All deferred.
- **No org-secret repo binding.** No repo, no workflows that consume secrets, no binding needed.

## Phase A (only)

This is the entire AI Seed procedure. One Architecture work-item:

1. **Catalog rows.** Add the Node row to `catalogs/nodes.json` with:
   - `signal: "seed"`
   - `done: false`
   - the planned `cluster`, `energy`, `priority`, `flow`, `tags`, `long_description`, `foundational`, `strategy_base`, `tier`, `time_pressure`, `cooldown_days` per existing AI-sector precedent;
   - `links.repo`: leave `null` or omit until the post-promotion scaffold packet adds the GitHub URL (the catalog stores the repository URL under `links.repo`, not a top-level `repo` field).
2. **Relationships edges.** Add `consumes`/`consumed_by` edges to `catalogs/relationships.json` for every planned dependency. Edges must be ADR-pinned and acyclic (Invariant 4 — DAG only). For AI-sector Seeds the typical upstream is `HoneyDrunk.AI.Abstractions` (Invariant 44 — downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`); downstream consumers depend on the Seed's planned `.Abstractions`.
3. **Grid-health row.** Add the Node row to `catalogs/grid-health.json` with the planned contract surface, canary expectation, and DR tier per ADR-0036.
4. **Context folder.** Create the five-file folder at `repos/{NodeName}/`:
   - `overview.md` — what the Node will do once stood up; capability description per the source ADR.
   - `boundaries.md` — what it does NOT do; boundary rules cross-referenced to the relevant invariants.
   - `invariants.md` — the invariants the Node will enforce (typically a contract-shape canary obligation per Invariant 46 / 49 once the `.Abstractions` package exists).
   - `active-work.md` — an empty stub at Seed time; populated when the scaffold initiative starts.
   - `integration-points.md` — the planned upstream/downstream surfaces with their relationships-graph IDs.
5. **Sector row.** Add a row to `constitution/sectors.md` for the sector (AI for AI-sector Seeds) with `Signal: Seed`.
6. **Standup ADR registered.** The Seed-creating ADR (e.g. ADR-0016 through ADR-0025 for the AI Seeds) is registered in `adrs/` and `adrs/README.md`. The ADR reads `**Status:** Accepted` if it is the Seed-creating decision; its `If Accepted — Required Follow-Up Work` section lists "Per-Node scaffold packet when ready to promote."

(No Phase B. No Phase C. An AI Seed lives in this state until the operator decides to scaffold the Node.)

## Promotion to scaffolded

When the AI Seed is ready to be stood up:

1. The operator (or the `scope` agent for an initiative) decides the target class — almost always **Core .NET Abstractions+Runtime** for AI-sector Nodes (per the downstream-AI-`Abstractions`-only coupling rule in Invariant 44).
2. A new initiative is opened with a per-Node scaffold packet (`03-{node}-node-scaffold.md` shape, ADR-0031 precedent).
3. Phase B and Phase C run from `node-standup-core-dotnet.md` (or the appropriate target-class walkthrough).
4. The scaffold PR flips the catalog Node row from `signal: "seed"` / `done: false` to `signal: "Live"` / `done: true` and sets `links.repo` to the new GitHub URL. The sector row flips from `Signal: Seed` to `Signal: Live`.
5. Invariant 102 (node-registration-mandatory) is now load-bearing — the *first non-bootstrap PR* after the scaffold merges binds it.

## Promotion gate — explicit checks before scaffolding

Before promoting an AI Seed:

- The per-Node ADR exists. If only the multi-Seed wave ADR exists (one ADR creating many Seeds, as ADR-0016 did), that alone is not sufficient grounds for scaffold work — per-Node scope decisions are captured in a per-Node ADR; draft one first.
- Upstream contracts the Node will consume are stable enough to compile against (typically a stable `HoneyDrunk.AI.Abstractions` v0.X surface).
- Downstream consumers know they will be unblocked when the scaffold lands (the relationships-graph downstream edges have ADRs referencing the scaffolded Node).
