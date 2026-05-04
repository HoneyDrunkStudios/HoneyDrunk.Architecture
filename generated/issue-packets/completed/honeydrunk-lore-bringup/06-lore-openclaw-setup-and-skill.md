---
name: Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Lore
labels: ["chore", "human-only", "tier-1", "automation"]
dependencies: [1, 2, 4]
wave: 3
initiative: honeydrunk-lore-bringup
node: honeydrunk-lore
---

# Chore: OpenClaw setup + Lore sourcing skill

## Summary
Install and configure OpenClaw (openclaw.ai) as a local AI assistant connected to the Lore vault and messaging apps. Then build a custom Lore sourcing skill so you can say "add this to Lore" or "find content about X for Lore" from your phone or any connected messaging app, and the content lands in `raw/` automatically.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Lore` (local machine)

## Why human-only
OpenClaw is a local application that installs on your machine and connects to desktop apps (Obsidian) and messaging services (WhatsApp, Telegram, etc.). Installation and messaging account linking require UI interaction. The Lore skill definition is agent-writable but only useful once the runtime is installed.

---

## Part A â€” Install OpenClaw

### 1. Install on Windows
OpenClaw ships a bash install script. On Windows, run it in Git Bash or WSL:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

After installation, verify it started:
- Check the system tray for the OpenClaw icon
- Or run `openclaw status` in your terminal

If the bash install does not work on your Windows setup, check openclaw.ai/docs for the Windows-native installer â€” they list Mac, Windows, and Linux support.

### 2. Choose your AI provider
OpenClaw supports Anthropic Claude, OpenAI, and local models. Use Claude:
- Settings â†’ AI Provider â†’ Anthropic
- Enter your Anthropic API key
- Select model: claude-sonnet-4-6 (or latest Sonnet for balance of speed and quality)

### 3. Connect a messaging app
OpenClaw delivers through apps you already use. Pick one as your primary Lore interface:

**Recommended: Telegram** (easiest setup, works well on mobile + desktop)
- Create a Telegram bot via BotFather (search @BotFather in Telegram)
- Copy the bot token
- OpenClaw Settings â†’ Integrations â†’ Telegram â†’ paste token
- Start a conversation with your bot â€” OpenClaw responds through it

**Alternative: WhatsApp**
- Settings â†’ Integrations â†’ WhatsApp
- Follow the QR code pairing flow
- Note: WhatsApp integration requires the WhatsApp app open on your phone periodically to stay connected

---

## Part B â€” Connect Obsidian

### 4. Link Obsidian to OpenClaw
OpenClaw has a native Obsidian integration:
- Settings â†’ Integrations â†’ Obsidian
- Point it at the vault root: `HoneyDrunk.Lore/`
- Verify: send a test message "list my vault files" â€” OpenClaw should return a file listing

---

## Part C â€” Build the Lore sourcing skill

OpenClaw skills are defined as markdown or JSON instruction files that tell OpenClaw what to do when triggered. Skills live in the ClawHub directory or a local skills folder.

### 5. Create the Lore skill

Create a new skill file. The skill should handle three trigger phrases:

**Trigger 1: "add [URL] to Lore"**
- Fetch the page at the URL
- Extract: title, author (if present), publication date, full article content, source URL
- Check `sourcing-playbook.md` relevance criteria â€” if the content matches a category, proceed; if clearly out of scope, respond "this does not match Lore sourcing criteria" and stop
- Save to `raw/` as a markdown file named `YYYY-MM-DD-slug-of-title.md`
- Include frontmatter: `source`, `title`, `author`, `date_clipped`, `category` (matched category from playbook)
- Respond: "Added to Lore: [title] â†’ raw/YYYY-MM-DD-slug.md"

**Trigger 2: "find content about [topic] for Lore"**
- Search the web for recent (last 30 days) content matching the topic
- Filter results against `sourcing-playbook.md` relevance criteria
- For each qualifying result (max 5): save to `raw/` using the same format as Trigger 1
- Respond with a summary: "Added N items to Lore about [topic]: [list of titles]"

**Trigger 3: "what does Lore know about [topic]"**
- Search `wiki/` for pages matching the topic
- Summarize findings and list relevant page filenames
- Check `wiki/indexes/gaps.md` â€” if the topic appears there, note it as a known gap
- Respond with a brief summary

### Skill file content

```yaml
name: lore-sourcing
description: Add content to HoneyDrunk.Lore or query what Lore knows
triggers:
  - "add * to Lore"
  - "add * to lore"
  - "find content about * for Lore"
  - "find content about * for lore"
  - "what does Lore know about *"
  - "what does lore know about *"

vault: HoneyDrunk.Lore
playbook_path: sourcing-playbook.md

instructions: |
  You are the Lore sourcing agent for HoneyDrunk Studios.
  
  Before acting, read sourcing-playbook.md from the vault root to understand
  what content belongs in Lore and the relevance criteria.
  
  For "add [URL] to Lore":
  1. Fetch the URL content
  2. Check relevance criteria from sourcing-playbook.md
  3. If out of scope, respond with why and stop
  4. Save to raw/ as YYYY-MM-DD-title-slug.md with frontmatter:
     - source: [URL]
     - title: [article title]
     - author: [author if available]
     - date_clipped: [today]
     - category: [matched category from playbook]
  5. Confirm: "Added to Lore: [title] -> raw/[filename]"
  
  For "find content about [topic] for Lore":
  1. Web search: "[topic] site:relevant-sources last month"
  2. Filter results against sourcing-playbook.md relevance criteria
  3. Save qualifying results (max 5) to raw/ using same format
  4. Summarize: "Added N items to Lore about [topic]"
  
  For "what does Lore know about [topic]":
  1. Search wiki/ for matching pages
  2. Check wiki/indexes/gaps.md for the topic
  3. Summarize findings with page references
```

### 6. Test the skill
Send these messages to your connected bot:
- "add [paste any relevant article URL] to Lore" â€” verify file appears in `raw/`
- "find content about MCP servers for Lore" â€” verify 1-5 files appear in `raw/`
- "what does Lore know about software architecture" â€” verify it searches `wiki/`

---

## Acceptance Criteria

**Part A â€” Install**
- [ ] OpenClaw installed and running on your machine
- [ ] Claude (Anthropic) set as AI provider with API key configured
- [ ] At least one messaging integration connected (Telegram recommended)
- [ ] Test message sent and responded to

**Part B â€” Obsidian**
- [ ] Obsidian integration connected and pointing at `HoneyDrunk.Lore/` vault root
- [ ] "list my vault files" returns a file listing via messaging app

**Part C â€” Lore skill**
- [ ] Lore sourcing skill created and loaded in OpenClaw
- [ ] Trigger 1 test: URL clip lands in `raw/` with correct frontmatter
- [ ] Trigger 2 test: topic search adds at least one file to `raw/`
- [ ] Trigger 3 test: wiki query returns a meaningful response
- [ ] Out-of-scope URL test: clearly irrelevant URL is rejected with a reason

---

## Dependencies
- Issue #1 (scaffold) â€” `raw/` directory must exist
- Issue #2 (Obsidian) â€” vault must be configured and connected
- Issue #4 (sourcing-playbook.md) â€” skill reads the playbook for relevance criteria

## Labels
`chore`, `human-only`, `tier-1`, `automation`

## Notes
- OpenClaw documentation: openclaw.ai/docs
- ClawHub for community skills: openclaw.ai/clawhub
- The Lore skill reads `sourcing-playbook.md` at runtime â€” updating the playbook updates the skill behavior without reinstalling
- If OpenClaw adds new capabilities (RSS integration, scheduled sourcing), revisit this issue to extend the skill
