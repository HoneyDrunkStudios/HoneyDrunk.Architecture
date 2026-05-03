---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Lore
labels: ["feature", "tier-1", "docs"]
dependencies: [1]
wave: 2
initiative: honeydrunk-lore-bringup
node: honeydrunk-lore
---

# Feature: sourcing-playbook.md â€” content curation guide

## Summary
Create `sourcing-playbook.md` at the repo root. This is the human + agent guide for what content belongs in Lore, where to find it, and what relevance criteria to apply. It is the config that the OpenClaw skill and RSS agent read to decide what to clip vs. skip.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Lore`

## Motivation
The wiki compounds only if the right content goes in. Without a sourcing guide, clipping is arbitrary. The playbook makes sourcing intentional and reproducible, and gives agents enough context to source on your behalf.

## Proposed Implementation

Write `sourcing-playbook.md` at the repo root with the following content.

---

### File: `sourcing-playbook.md`

```markdown
# Lore â€” Sourcing Playbook

This document defines what content belongs in Lore, where to find it, and how to decide what to clip. It is read by humans during manual curation sessions and by agents (OpenClaw skill, RSS agent) performing automated sourcing.

---

## How to use this playbook

**Manual session (weekly):** Go through the sources listed under each category. Clip anything relevant to `raw/` using Obsidian Web Clipper. Aim for 3-10 items per session â€” quality over volume.

**OpenClaw:** Say "source Lore" or "add [URL] to Lore" to trigger the skill. The skill uses this playbook to filter what is worth keeping.

**RSS agent:** Polls feeds daily, filters against relevance criteria defined here, and drops qualifying items in `raw/` automatically.

**Your own explorations are sources too.** When a query session, debug investigation, or research thread yields something worth keeping, crystallize it â€” write it to `output/` and let the next compile pass pull it into `wiki/`. Treat it exactly like an external article: same relevance criteria, same compile path. This is how the wiki compounds from your own work, not just from the outside world.

---

## Categories

### 1. AI / LLM Research & Tooling
*Core to everything HoneyDrunk builds â€” models, agents, evals, prompting, MCP, tooling.*

**What to clip:**
- Model capability announcements and benchmark results
- Agent architecture patterns (planning, memory, tool use, multi-agent)
- Prompt engineering techniques and evals methodology
- MCP (Model Context Protocol) updates and new servers
- New AI development tools and frameworks
- LLM infrastructure and cost optimization

**What to skip:**
- General AI hype with no technical substance
- Product announcements with no architecture or engineering detail

**Sources:**
- Anthropic blog + research papers (anthropic.com/research)
- Simon Willison blog (simonwillison.net)
- Andrej Karpathy blog and GitHub
- Hugging Face blog (huggingface.co/blog)
- The Batch â€” Andrew Ng newsletter
- LangChain blog
- ArXiv cs.AI and cs.LG â€” applied agent work only
- Hacker News â€” AI/LLM posts with substantial discussion

---

### 2. Software Architecture
*Patterns that influence Grid design â€” distributed systems, event-driven, CQRS, domain modeling.*

**What to clip:**
- Event-driven and message-based architecture patterns
- CQRS, event sourcing, outbox patterns
- Domain-driven design and bounded contexts
- Distributed systems fundamentals (CAP, eventual consistency, sagas)
- API design and contract-first development

**What to skip:**
- Language-specific tutorials not applicable to .NET
- Opinion pieces without concrete trade-off analysis

**Sources:**
- Martin Fowler blog (martinfowler.com)
- ByteByteGo newsletter and blog
- High Scalability (highscalability.com)
- InfoQ architecture articles
- The Architecture Notes newsletter

---

### 3. Azure & Cloud
*Platform HoneyDrunk builds on â€” new services, best practices, pricing, identity.*

**What to clip:**
- Azure service announcements relevant to the Grid (Functions, Container Apps, App Config, Key Vault, Event Grid, AI services)
- Azure identity and RBAC changes
- Cost optimization strategies for Azure
- GitHub Actions + Azure integration patterns
- Cloud-native patterns (KEDA, Dapr)

**What to skip:**
- AWS/GCP content unless directly comparative to Azure
- Azure services outside the Grid current or planned scope

**Sources:**
- Azure Updates blog (azure.microsoft.com/updates)
- Azure DevBlogs (devblogs.microsoft.com/azure)
- Azure Architecture Center (learn.microsoft.com/azure/architecture)
- John Savill Technical Training (YouTube)
- Azure Friday (Channel 9)

---

### 4. .NET Ecosystem
*Runtime â€” framework updates, libraries, patterns, performance.*

**What to clip:**
- .NET release notes and preview features
- ASP.NET Core and C# language updates
- NuGet ecosystem: new libraries worth evaluating
- Performance and benchmarking
- Minimal API and middleware patterns

**What to skip:**
- Framework comparisons aimed at beginners
- Content covering stable, well-understood .NET APIs already in use

**Sources:**
- .NET Blog (devblogs.microsoft.com/dotnet)
- Andrew Lock blog (andrewlock.net)
- Nick Chapsas (YouTube and blog)
- Scott Hanselman blog (hanselman.com)
- .NET Weekly newsletter

---

### 5. Solo Dev / Indie SaaS
*How HoneyDrunk operates as a studio â€” product strategy, pricing, go-to-market, sustainability.*

**What to clip:**
- Build-in-public case studies and revenue milestones
- Pricing strategy and packaging for developer tools
- Distribution and discoverability for niche SaaS
- Solo founder operating patterns
- Open source + paid tier models

**What to skip:**
- VC-funded startup content focused on growth-at-all-costs
- General entrepreneurship advice not grounded in product or technical work

**Sources:**
- Indie Hackers (indiehackers.com) â€” filter for SaaS and dev tools
- The Bootstrapped Founder â€” Arvid Kahl
- Pieter Levels blog and Twitter
- Hacker News Show HN threads
- Tiny Seed blog

---

### 6. Developer Tooling & AI Coding
*Tools that improve the development workflow â€” Claude Code, MCP servers, IDEs, productivity.*

**What to clip:**
- Claude Code updates and new features
- MCP server releases relevant to development workflows
- IDE and editor updates (VS Code, JetBrains)
- AI-assisted coding patterns and prompting strategies

**What to skip:**
- Tool comparisons without depth
- Anything that does not directly improve the solo dev + AI agent workflow

**Sources:**
- Claude Code release notes and changelog
- VS Code blog (code.visualstudio.com/updates)
- GitHub blog (github.blog)
- Changelog podcast
- The Pragmatic Engineer â€” Gergely Orosz

---

### 7. Game Development / Unity
*HoneyPlay sector â€” narrative, simulation, games powered by the Grid.*

**What to clip:**
- Unity engine updates (LTS releases, new features)
- Unity + AI integration patterns
- Procedural generation and simulation techniques
- Narrative design and interactive storytelling
- Game architecture patterns applicable to the Grid
- Indie game development workflow and tooling

**What to skip:**
- Beginner Unity tutorials
- AAA studio news with no applicable patterns

**Sources:**
- Unity Blog (blog.unity.com)
- Game Developer Magazine (gamedeveloper.com)
- r/gamedev â€” architecture and systems posts only
- Game Programming Patterns (gameprogrammingpatterns.com)
- GDC Vault free talks

---

### 8. DevOps & CI/CD
*Ops sector â€” shipping reliably, observability, deployment patterns.*

**What to clip:**
- GitHub Actions updates and new features
- Container and Docker best practices
- Observability patterns (OpenTelemetry, distributed tracing)
- DORA metrics and delivery performance
- Deployment strategies (blue/green, canary, feature flags)

**What to skip:**
- DevOps culture pieces without technical substance
- Jenkins and legacy CI content

**Sources:**
- GitHub Actions changelog
- Docker blog (docker.com/blog)
- OpenTelemetry blog
- DevOps.com â€” CI/CD and observability only
- Charity Majors blog (charity.wtf)

---

### 9. Workflow Automation
*Automating the solo dev operating rhythm â€” agents, triggers, integrations.*

**What to clip:**
- No-code and low-code automation patterns (n8n, Make, Zapier)
- Webhook-driven automation patterns
- AI agent automation case studies
- Scheduled and event-driven workflow patterns

**What to skip:**
- Enterprise RPA content
- Automation platforms with no integration path to the Grid

**Sources:**
- n8n blog (n8n.io/blog)
- Zapier blog â€” developer automation only
- Make (make.com) updates
- Hacker News â€” automation and workflow posts

---

### 10. Emerging Technology
*Signals from adjacent fields that may influence the Grid long-term direction.*

**What to clip:**
- Robotics and embodied AI (Cyberware sector relevance)
- WebAssembly and edge computing advances
- New programming paradigms with architectural implications
- Brain-computer interfaces and HCI research

**What to skip:**
- Speculative futures without engineering substance
- Consumer technology reviews

**Sources:**
- MIT Technology Review (technologyreview.com)
- IEEE Spectrum (spectrum.ieee.org)
- Ars Technica â€” deep technical dives only
- The New Stack (thenewstack.io)
- Hacker News â€” emerging tech high signal posts

---

### 11. Security & Ethical Hacking
*HoneyNet sector â€” resilience testing, digital hygiene, threat modeling.*

**What to clip:**
- Application security patterns for .NET and Azure
- OAuth2 / OIDC security considerations
- API security and secrets management best practices
- CTF write-ups with applicable defensive techniques
- Threat modeling frameworks and OWASP updates

**What to skip:**
- Malicious tooling without defensive application
- CVE announcements for technologies outside the Grid stack

**Sources:**
- OWASP blog and updates
- Troy Hunt blog (troyhunt.com)
- Scott Brady blog â€” .NET identity and security
- HackerOne Hacktivity â€” public disclosures
- Security Weekly podcast

---

### 12. Creator Economy & Marketplace
*Market sector â€” XP systems, gigs, payouts, marketplace dynamics.*

**What to clip:**
- Creator monetization models and platform economics
- XP and gamification system design
- Marketplace dynamics and pricing models
- Digital goods and licensing patterns

**What to skip:**
- Influencer content without product or system depth
- Speculative digital asset content

**Sources:**
- Lenny Newsletter â€” product and marketplace patterns
- Hacker News â€” marketplace and economy posts
- Stratechery â€” platform and marketplace analysis

---

## Relevance criteria (for agents)

When deciding whether to clip something, apply these in order:

1. **Actionable or instructive?** Can this be applied to HoneyDrunk design, architecture, or operation? If yes, clip.
2. **Durable?** Will this still matter in 6 months? Patterns and trade-off analyses usually do. Current-events opinion pieces usually do not.
3. **In scope?** Matches one of the 12 categories above? If not, skip.
4. **Deep enough?** Has technical substance, concrete examples, or case study data? Surface-level overviews are not worth compiling.

When in doubt: clip it. It is easier to lint duplicates out than to recover from missing content.

---

## Session rhythm

| Frequency | Activity |
|-----------|----------|
| Daily (automated) | RSS agent and OpenClaw skill monitor feeds and clip qualifying items |
| Weekly (manual, ~20 min) | Scan source lists for items automation missed, check `wiki/indexes/gaps.md` for open questions |
| Monthly (manual, ~10 min) | Review this playbook â€” add new sources, remove dead ones, refine relevance criteria |
```

## Acceptance Criteria
- [ ] `sourcing-playbook.md` exists at repo root
- [ ] All 12 categories present with What to clip / What to skip / Sources sections
- [ ] Relevance criteria section present
- [ ] Session rhythm section present
- [ ] File is valid markdown

## Dependencies
Issue #1 (scaffold) â€” repo must exist.

## Labels
`feature`, `tier-1`, `docs`

## Agent Handoff

**Objective:** Write `sourcing-playbook.md` at the repo root with the content specified in the Proposed Implementation section above.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Lore`, branch from `main`

**Constraints:**
- Write the file exactly as specified â€” do not summarize or shorten any section
- No other files should be modified

**Key Files:**
- `sourcing-playbook.md` (new)
