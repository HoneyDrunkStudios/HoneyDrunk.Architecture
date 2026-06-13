---
name: Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Lore
labels: ["chore", "human-only", "tier-1"]
dependencies: [1]
wave: 2
initiative: honeydrunk-lore-bringup
node: honeydrunk-lore
---

# Chore: Obsidian vault setup + Web Clipper

## Summary
Configure the repo root as an Obsidian vault and install the Obsidian Web Clipper browser extension. Together these give you a one-click path from any web article directly into `raw/`, where the scheduled ingest agent picks it up automatically.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Lore` (local clone)

## Why human-only
Obsidian is a local desktop application and Web Clipper is a browser extension. Both require UI interaction to install and configure. An agent cannot launch Obsidian or interact with browser extension settings.

## Steps

### 1. Install Obsidian
Download from obsidian.md and install. No account required for local vault use.

### 2. Open the repo root as a vault
- Open Obsidian â†’ "Open folder as vault"
- Navigate to the repo root: `HoneyDrunk.Lore/`
- Select the **root folder** â€” not `wiki/`

The vault encompasses the whole repo so Web Clipper can target `raw/`. The `wiki/` subfolder is where compiled content lives and will be the primary browsing area.

### 3. Exclude non-wiki directories from the vault view
Prevent `output/`, `tools/`, and `raw/` from cluttering the graph and file list:
- Settings â†’ Files & Links â†’ "Excluded files": add `output`, `tools`
- Leave `raw/` visible â€” you want to see what's waiting to be compiled

### 4. Recommended settings

**Files & Links**
- "New link format": Relative path
- "Use [[Wikilinks]]": on (enables backlink tracking across `wiki/`)
- "Default location for new notes": `raw/` (so any new note lands in raw, not wiki)

**Graph view**
- Settings â†’ Graph view â†’ "Show attachments": off, "Show orphans": on
- Open graph view (Ctrl+G) â€” verify `wiki/indexes/` stubs appear as nodes

**Editor**
- "Strict line breaks": off

### 5. Install Obsidian Web Clipper
- Install the browser extension: search "Obsidian Web Clipper" in your browser's extension store (Chrome, Firefox, Edge)
- After install, click the extension icon â†’ connect it to your Obsidian vault

**Configure the clipper:**
- Vault: `HoneyDrunk.Lore`
- Save location: `raw/`
- Note format: Markdown
- Filename template: `{{date}}-{{title}}` (produces dated filenames like `2026-04-11-article-title.md`)
- Include: page URL, title, author if available, full article content

Now any article you want to add to Lore is one click â€” clip it, it lands in `raw/` with a date-stamped filename, and the scheduled ingest agent handles the rest.

### 6. Commit `.obsidian/` config
After configuring, commit the `.obsidian/` directory so vault settings are preserved:
```
git add .obsidian/
git commit -m "chore: add Obsidian vault config"
```

Add workspace noise to `.gitignore`:
```
echo ".obsidian/workspace.json" >> .gitignore
echo ".obsidian/workspace-mobile.json" >> .gitignore
```

## Acceptance Criteria
- [ ] Obsidian installed locally
- [ ] Vault root is the repo root (`HoneyDrunk.Lore/`), not `wiki/`
- [ ] `output/` and `tools/` are in excluded files
- [ ] Default new note location is `raw/`
- [ ] Graph view opens and shows `wiki/indexes/` stubs
- [ ] Obsidian Web Clipper extension installed and connected to the vault
- [ ] Clipper configured to save to `raw/` with dated markdown filenames
- [ ] Test clip: clip one article, verify it appears in `raw/` as a `.md` file
- [ ] `.obsidian/` config committed to repo
- [ ] `.obsidian/workspace.json` in `.gitignore`

## Dependencies
Issue #1 (scaffold) must be complete â€” `raw/` and `wiki/` directories must exist before opening as a vault.

## Labels
`chore`, `human-only`, `tier-1`