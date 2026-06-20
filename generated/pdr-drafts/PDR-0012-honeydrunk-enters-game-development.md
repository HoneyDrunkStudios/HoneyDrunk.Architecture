# PDR-0012: HoneyDrunk Enters Game Development — The Anthology-Universe Strategy

**Status:** Draft (pre-Proposed — pending review, then promote to `pdrs/PDR-0012`)
**Date:** 2026-06-20
**Deciders:** HoneyDrunk Studios
**Sector:** HoneyPlay
**Codename:** (universe name TBD; first title codename TBD)

> This is a working draft in `generated/pdr-drafts/`. Per repo process, drafts mature here and are promoted into `pdrs/` (with an index row in `pdrs/README.md`) once reviewed. Living creative canon lives separately in `games/` — this PDR is the *decision*, not the worldbuilding.

---

## Context

Everything HoneyDrunk has shipped to date is backend infrastructure (Core/Ops/Meta/AI sectors) or consumer utility apps (the "Play"-tagged PDRs — Hearth, Curiosities, Lately, Currents). Nothing is a *creative, narrative-driven consumer game*.

The operator wants to begin building their **first game at the start of next year (target ~January 2027)**. This is a genuinely new direction for the studio: a consumer-facing creative product rather than infrastructure-for-other-software. The Grid already anticipated this — the **HoneyPlay** sector (*"Gaming, narrative, and media — worlds to explore, leagues to compete in, and creative sandboxes"*) exists in `constitution/sectors.md` with **zero real Nodes** (placeholders only). This PDR activates that sector at the strategy level.

The operator has an ambitious "dream game" they are *not* attempting first. The strategy below is built around reaching it safely over multiple smaller, finishable games.

## Problem Statement

### 1. A first game is a graveyard of over-scope
The most common failure mode for a first game is an ambitious title that never ships. The dream game (a faction-driven, fully-explorable, choice-reactive open-world RPG) is AAA-scale and must not be game #1, #2, or #3.

### 2. The studio's skills are infra-shaped, not game-shaped
The operator is a strong C#/.NET developer with a mature multi-repo + AI-agent workflow, but has not shipped a game (engine, asset pipeline, store release, playtesting). The transferable parts (C#, CI, decision discipline) and the gaps (engine, assets, distribution, design iteration) must be named.

### 3. Effort should compound, not be thrown away
The operator wants to build reusable "nodes" (game systems) that carry forward between titles, mirroring the Grid's Node philosophy — without falling into the premature-framework trap that kills indie projects.

### 4. The artifacts have no home yet
Game *product* decisions fit PDRs, but a shared fictional **universe/canon** and per-game **design docs** are neither product-strategy, technical-architecture, nor business records. The repo needs a place for them that still follows process.

## Decision

### A. HoneyDrunk enters game development under the HoneyPlay sector
Games are products under HoneyDrunk Studios, sectored as **HoneyPlay**. Each shipped game becomes a HoneyPlay Node registered in `catalogs/nodes.json` *at standup* — not before. This PDR introduces future per-game Nodes without scaffolding them (same pattern as ADR-0037 introducing the future Billing Node without cataloguing it).

### B. Engine: Unity, with C# in Visual Studio
- **Unity (LTS)** — chosen for the largest ecosystem/asset/tutorial base, C#-native scripting (transfers the operator's strongest skill), and a clear path to PC/Steam. Rejected alternatives: Godot (lighter, viable, smaller ecosystem), MonoGame (most .NET-native but slowest to a finished game), Unreal (furthest from the current stack).
- **IDE: Visual Studio Community** (free; first-class Unity integration via the Unity workload). **Not** JetBrains Rider — Rider is excellent but a paid license for a commercial LLC and offers only marginal gains for a first game. AI tooling (Claude Code, Codex) is IDE-agnostic and does not influence this choice.
- **Platform: PC / Steam** for the first title. Steamworks Direct fee ($100/app) incurred only at store-page time; the existing HoneyDrunk Studios LLC simplifies payout/tax setup.
- **Art/music/AI toolchain** — foundation + buy/generate + AI-in-tool. 2D standardized on **Adobe CC** (Firefly is commercial-safe-trained, resolving the shipped-AI-asset licensing risk for 2D); **Blender** for 3D; music decided per game; assets sourced from Kenney/Unity Asset Store/Fab. Commercial titles must comply with **Steam's AI-content disclosure** and prefer licensed/contracted/Firefly assets for shipped content. Full detail in `games/tooling.md`.

### C. The Anthology-Universe model
Smaller games progressively build toward the dream game **inside a shared fictional universe**, but **do not follow the same protagonist**. Precedent: Elder Scrolls (one world, new customizable hero per game, different eras/regions).

The constants and variables are explicit:

| Constant (shared canon) | Variable (per game) |
|---|---|
| The world, its history & geography | Protagonist |
| Factions and their frictions | Spine (what *that* game is about) |
| The power-system **rules** | Combat **presentation** (action *or* turn-based; no hybrid) |
| Entities & deities (the recurring "cast") | Genre, era, region, tone |

Two derived principles:
- **"Rules are canon; presentation varies."** The power system's *rules* (costs, conditions, limits, interactions) are immutable canon and the primary reusable node; how those rules are expressed in moment-to-moment play differs per game.
- **"Spine per game, not per universe."** A universe can be spine-agnostic; an individual game cannot. Each game commits to one spine.

Not every game must be in-universe — standalone palette-cleansers are allowed.

### D. The game ladder
1. **Game 1 — learning project, standalone, off-canon.** Tiny, disposable by design. Its only job: take the operator through Unity → Steam once (build, polish, store page, ship, observe real players). Deliberately *not* in the universe to avoid locking canon prematurely.
2. **Game 2 — the power-system node.** Small contained combat game (boss-rush / wave arena). Establishes the rule-based power system's *feel*; seeds the first monsters/entities. First in-universe title.
3. **Game 3 — the choice & character node.** Story-driven small-footprint game; builds dialogue, branching choices/consequences, light faction/reputation, and the pact/bond mechanic. Seeds characters, lore, factions.
4. **Game 4 — the world & traversal node.** Vertical slice proving city↔other-realm transition and exploration across terrains.
5. **Dream game.** Composes all nodes at scale, adds the systems too large to prototype standalone, launches to an audience built across the prior titles.

### E. Reuse is earned, not designed
Build the system the game in front of you needs; extract the reusable version only on its **second** use. No universal frameworks up front. AI assistance lowers refactor cost over the multi-year arc but does not change this discipline.

### F. Artifact homes (the "split")
- **Product-strategy decisions about games → PDRs** (this one, and a future per-title PDR when a game becomes a real product commitment).
- **Shared canon + per-game design docs → the new `games/` domain** (mirrors `business/`): `games/universe/` (living canon), `games/titles/` (per-game design bundles), `games/roadmap.md` (the ladder).
- **No new "Game Design Record" record type** is introduced now. Design calls are captured inside the `games/` docs; a dedicated record type is formalized only if a recurring need emerges (concrete-before-abstract).

## Options Evaluated

- **Go straight for the dream game** — rejected; near-certain non-completion as a first game.
- **Unrelated one-off games** — rejected as the *primary* path; loses the compounding audience/lore/tooling benefit. Retained as an *allowed* exception (palette-cleansers).
- **Shared protagonist across games** — rejected in favor of anthology; a weak entry can't taint a franchise protagonist, and the anthology unlocks immortal entities/deities as the recurring cast.
- **Godot / MonoGame / Unreal** — see §B.
- **New GDR record type now** — rejected as premature.

## Tradeoffs

- Anthology adds a (light) canon constraint to each in-universe game; mitigated by keeping canon loose and accreting.
- A multi-year ladder defers revenue; acceptable because game 1's explicit goal is *learning the full loop*, not revenue.
- Unity carries licensing tiers to track as revenue grows; acceptable at current scale.

## Consequences

- The HoneyPlay sector moves from placeholder to active strategy (no Nodes catalogued yet).
- A `games/` domain is added to the repo for canon + design docs.
- Future work: per-title PDRs at product-commitment time; HoneyPlay Node standups at repo-creation time; possible custom game-dev agents (design/content/playtest) — a **game-3+ concern**, not now.

## Recommended Follow-Up Artifacts

- Promote this draft to `pdrs/PDR-0012` + index row once reviewed.
- `games/` domain scaffold (this pass).
- Setup-readiness checklist execution over the ~6-month runway (Unity/VS install, git+LFS Unity project hygiene, one throwaway tutorial project) — tracked in `games/roadmap.md`.
- Game-1 concept lock (see `games/titles/game-01/concept.md`).
