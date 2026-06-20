# Game Roadmap — The Ladder

**Status:** Seed (living document)
**Last updated:** 2026-06-20

The sequence of games leading to the dream game, plus the setup-readiness checklist. Per PDR-0012.

## The ladder

Each rung is **finishable on its own** and builds one reusable **node** (game system) toward the dream game. Reuse is earned on the *second* use, never designed up front.

| # | Title | In-universe? | Job / node built | Universe seed |
|---|-------|:---:|---|---|
| 1 | Learning project (codename TBD) | No (off-canon) | Take the operator through Unity → Steam once. Disposable. | — |
| 2 | Power-system game (codename TBD) | Yes | Ability/combat system — the rule-based power system's *feel* (boss-rush / wave arena). | First monsters/entities; tone of "power". |
| 3 | Choice & character game (codename TBD) | Yes | Dialogue, branching choices/consequences, light faction/reputation, the pact/bond mechanic. | Characters, lore, first factions. |
| 4 | World & traversal game (codename TBD) | Yes | World streaming, traversal, city↔realm transitions across terrains (vertical slice). | Geography; nature of the gates/realms. |
| ★ | **The dream game** (codename TBD) | Yes | Composes all nodes at scale + the systems too big to prototype standalone. | The payoff — launches to an audience built across the ladder. |

### The dream game (target — not first)
Faction-driven, fully-explorable, choice-reactive **open-world RPG**. Urban-fantasy baseline with passage into other realms; customizable protagonist who starts extremely weak; rule-based typed-essence power system; pacts as an optional layer; grey morality; "play how you choose." AAA-scale by nature — this is exactly why the ladder exists. See `titles/dream-game/concept.md`.

## Setup-readiness checklist (the ~6-month runway → ~Jan 2027)

> Full toolchain (art, music, AI, asset sources) is in [`tooling.md`](tooling.md). Highlights below.

**Tooling**
- [ ] Install **Unity (LTS)** + Unity Hub.
- [ ] Use **Visual Studio Community** with the Unity workload (free; not Rider — paid for a commercial LLC). AI tools (Claude Code, Codex) are IDE-agnostic.
- [ ] Develop on **Windows** (VS Community is Windows; aligns with PC/Steam target).

**Source control**
- [ ] New **standalone repo** for game 1 (off the Grid's NuGet/semver conventions — it's a game, not a package Node).
- [ ] **Git + Git LFS** with Unity's `.gitignore`. (Skip Unity's Plastic VCS.)
- [ ] Defer the "shared reusable-systems package + per-game repos" structure until game 3 actually needs it.

**Skill ramp (before game 1 proper)**
- [ ] Learn Unity C# idioms (MonoBehaviour lifecycle, ScriptableObjects, coroutines, component model) — weeks, not months, given existing C#.
- [ ] One **throwaway tutorial project** to learn the *editor*.

**Distribution**
- [ ] Steamworks partner account ($100 Steam Direct fee) — only at store-page time. LLC simplifies payout/tax.

**Asset pipeline (solo + AI)**
- [ ] For game 1: lean on free/cheap asset packs + AI for placeholder/some final art & audio so art never blocks *finishing*.

**Process**
- [ ] Custom game-dev agents (design/content/playtest) are a **game-3+ concern** — current infra-shaped agents are fine to start.

## Notes
- Game repos register as **HoneyPlay** Nodes in `catalogs/nodes.json` at standup (not before).
- Per-title **PDRs** get written when a game becomes a real product commitment.
