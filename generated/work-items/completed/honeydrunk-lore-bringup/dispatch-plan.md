# Dispatch Plan — honeydrunk-lore-bringup

**Initiative:** `honeydrunk-lore-bringup`  
**Status:** Wave 1 ready  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Issues filed:** Yes (Lore#1–5, Architecture#9)  

---

## Summary

Stand up HoneyDrunk.Lore as a flat-file LLM-compiled wiki. Three waves: repo scaffold + catalog registration, then Obsidian + sourcing playbook, then the automation layer (scheduled ingest agent + OpenClaw skill).

---

## Wave Diagram

### Wave 1 — Foundation (parallel, no dependencies)
- [ ] `01` Lore#1 — Repo scaffold + CLAUDE.md schema doc
- [ ] `02` Architecture#9 — Catalog registration for HoneyDrunk.Lore

### Wave 2 — Content layer (parallel, depends on Wave 1)
- [ ] `03` Lore#4 — sourcing-playbook.md
- [ ] `04` Lore#2 — Obsidian vault setup + Web Clipper (human-only)
  - Blocked by: Wave 1 — Lore#1

### Wave 3 — Automation layer (parallel, depends on Wave 2)
- [ ] `05` Lore#3 — Scheduled ingest agent (CronCreate)
  - Blocked by: Wave 1 — Lore#1, Wave 2 — Lore#2
- [ ] `06` Lore#5 — OpenClaw setup + Lore sourcing skill (human-only)
  - Blocked by: Wave 1 — Lore#1, Wave 2 — Lore#2, Wave 2 — Lore#4

---

## Wave 1 Exit Criteria

Before starting Wave 2:
- [ ] Lore#1 merged — `raw/`, `wiki/`, `output/`, `tools/` exist, CLAUDE.md written
- [ ] Architecture#9 merged — `honeydrunk-lore` in `catalogs/nodes.json`, routing rules updated

---

## Wave 2 Exit Criteria

Before starting Wave 3:
- [ ] Lore#4 merged — `sourcing-playbook.md` at repo root with all 12 categories
- [ ] Lore#2 complete — Obsidian vault open, Web Clipper installed and clipping to `raw/`

---

## Packet Index

| # | File | Target Repo | Issue | Wave | Actor |
|---|------|-------------|-------|------|-------|
| 01 | [01-lore-scaffold-and-claude-md.md](01-lore-scaffold-and-claude-md.md) | HoneyDrunk.Lore | [Lore#1](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/1) | 1 | Agent |
| 02 | [02-architecture-catalog-registration.md](02-architecture-catalog-registration.md) | HoneyDrunk.Architecture | [Architecture#9](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/9) | 1 | Agent |
| 03 | [03-lore-sourcing-playbook.md](03-lore-sourcing-playbook.md) | HoneyDrunk.Lore | [Lore#4](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/4) | 2 | Agent |
| 04 | [04-lore-obsidian-vault-setup.md](04-lore-obsidian-vault-setup.md) | HoneyDrunk.Lore | [Lore#2](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/2) | 2 | Human |
| 05 | [05-lore-scheduled-ingest-agent.md](05-lore-scheduled-ingest-agent.md) | HoneyDrunk.Lore | [Lore#3](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/3) | 3 | Agent |
| 06 | [06-lore-openclaw-setup-and-skill.md](06-lore-openclaw-setup-and-skill.md) | HoneyDrunk.Lore | [Lore#5](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/5) | 3 | Human |

---

## Site Sync

Not required — Lore is an internal wiki, not a public-facing node. No Studios update needed at this stage.

---

## Rollback Plan

Lore is a new repo with no downstream consumers. Any wave can be abandoned cleanly:
- Wave 1 rollback: delete the Lore repo, revert Architecture#9 catalog changes
- Wave 2 rollback: delete `sourcing-playbook.md`, skip Obsidian setup
- Wave 3 rollback: remove CronCreate trigger, uninstall OpenClaw skill

No core Grid nodes are affected at any wave.

---

## History

| Date | Event |
|------|-------|
| 2026-04-11 | Initiative scoped, 6 issues filed on The Hive, packets written |
| 2026-04-13 | Packets 01, 03, 05 extended with LLM Wiki v2 patterns (confidence/supersession, consolidation, crystallization, retention decay, self-healing lint, v2 hook trajectory). Filed issues Lore#1, Lore#4, Lore#3 need body sync to match updated packets before Wave 1 work begins. |
