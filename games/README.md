# Games (HoneyPlay)

The studio's game-development planning surface — the shared fictional **universe/canon** and per-game **design docs** for HoneyDrunk's games. Parallel in shape to `business/`: a dedicated domain for things that aren't Grid architecture (`adrs/`), product strategy (`pdrs/`), or business operations (`business/`), but that an AI agent or future-me needs to reason about when building games.

This domain corresponds to the **HoneyPlay** Grid sector (`constitution/sectors.md`). When a game becomes a real repo, it registers as a HoneyPlay Node in `catalogs/nodes.json` *at standup*. Nothing here is catalogued or scaffolded until then.

Founding decision: **PDR-0012 — HoneyDrunk Enters Game Development: The Anthology-Universe Strategy** (currently a draft in `generated/pdr-drafts/`).

## Layout

- `universe/` — the shared **canon**. Living documents that *accrete* over time (like `business/context/`). The world, its cosmology, the power-system rules, the pantheon of entities/deities, factions, and bestiary. Constants shared across every in-universe game.
- `titles/` — per-game **design bundles** (like `repos/{Name}/` but for games). One folder per game; each holds its concept and design decisions.
- `roadmap.md` — the **game ladder** (game 1 → 2 → 3 → 4 → dream) and the setup-readiness checklist.
- `tooling.md` — the **toolchain & asset pipeline** (engine, art, music, AI, asset sources) by phase.

## What goes here

**Yes:**
- World canon: cosmology, lore, geography, history, factions, deities, monsters
- The power-system rulebook (the primary reusable "node")
- Per-game design docs: concept, spine, mechanics, scope, combat presentation
- The game ladder and engine/tooling setup notes

**No:**
- Product-strategy decisions about a game (positioning, pricing, whether to build it) → `pdrs/`
- Technical/Grid architecture → `adrs/`
- Studio operations → `business/`
- Game *code* → the game's own repo (a future HoneyPlay Node)

## Conventions

- **Canon docs (`universe/`) are living** — update in place as the world grows; note the change date. Keep canon *loose* until a game forces a detail (don't pour the foundation in concrete).
- **No new decision-record type** for game design yet. Design calls are captured inside these docs. A dedicated record type is formalized only if a recurring need emerges (concrete-before-abstract — same discipline the games' own systems follow).
- **Codenames** are fine until a final title is chosen; mark them `(codename)`.

## Core principles (from PDR-0012)

- **Anthology universe** — shared world, *new protagonist* per game (Elder Scrolls model).
- **Rules are canon; presentation varies** — the power system's rules are immutable shared canon; combat presentation (action *or* turn-based — no hybrid) differs per game.
- **Spine per game, not per universe** — each game commits to one thing it's about.
- **Reuse is earned on the second use** — build for the game in front of you; extract reusable systems only when a second game needs them.
