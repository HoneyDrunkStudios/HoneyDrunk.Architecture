# Product Decision Records

Index of all PDRs for the HoneyDrunk Grid.

PDRs capture **product-level strategic decisions** — platform positioning, domain boundaries, capability tier definitions, and ecosystem expansion. They carry enough architectural depth to guide future ADRs, roadmap planning, and node boundaries, but the primary lens is product strategy, not implementation.

For technical architecture decisions, see [ADRs](../adrs/README.md).

| ID | Title | Status | Date | Sector | Impact |
|----|-------|--------|------|--------|--------|
| [PDR-0001](PDR-0001-honeyhub-platform-observation-and-ai-routing.md) | HoneyHub Platform: Observation and AI Routing Layers | Accepted | 2026-03-30 | Meta / AI | Positions HoneyHub as an external-facing platform. Introduces Observation and AI Routing domains. |
| [PDR-0002](PDR-0002-notify-as-a-service-first-commercial-product.md) | HoneyDrunk Notify: First Commercial Product on the Grid | Proposed | 2026-05-02 | Ops / Meta | Names HoneyDrunk Notify (Notify Cloud architecturally) as the Grid's first commercial app. Reframes PDR-0001 §C — HoneyHub is no longer the external-facing product. Open core: Notify engine OSS (FSL/BSL), `HoneyDrunk.Notify.Cloud` wrapper private. |
| [PDR-0003](PDR-0003-lately-currents-based-connection-app.md) | Lately: Currents-Based Connection App | Proposed | 2026-05-05 | Market | Consumer connection app (codename Lately). Currents-based matching (current book/show/album), nightly Room with fingerprint mechanic. Treats Apps as a proposed consumer-portfolio label pending constitution work. Sequenced after Notify Cloud public launch. |
| [PDR-0004](PDR-0004-wayside-walking-and-public-place-notes.md) | Wayside: Walking and Public Place-Notes | Superseded by PDR-0008 (Curiosities) | 2026-05-05 | Market | Consumer walking + place-memory app (codename Wayside). **Superseded 2026-05-16 by PDR-0008**, which inverts the priority: curated discovery becomes the v1 lead, walk-memory + Mochi the backbone, public UGC marginalia cut from v1. Retained as the source of detail for Mochi's persona, watercolor maps, the moderation stack, and Atlas/pricing logic. |
| [PDR-0005](PDR-0005-hearth-personal-growth-as-a-living-town.md) | Hearth: Personal Growth as a Living Town | Proposed | 2026-05-05 | Market | Consumer personal-growth app (codename Hearth). Reflections, goals, care actions, creative sessions, and milestones build a sentiment/growth-responsive town; Tomoe pen-pal NPC; no streaks or XP grind ever. Yearly Artifact + Founding Townsfolk lifetime tier. Consumer wedge alongside Notify Cloud. |
| [PDR-0006](PDR-0006-currents-social-suggestions-and-quests.md) | Currents: Social Suggestions and Lightweight Quests | Proposed | 2026-05-06 | Market / AI / Social | Consumer social discovery app around active books/shows/music/games/places/projects. Turns Currents into suggestions and small-group prompts/quests; no XP, streaks, public feed, or dating surface at v1. |
| [PDR-0007](PDR-0007-arcadia-city-quest-map-and-place-unlocks.md) | Arcadia: City Quest Map and Place Unlocks | Superseded by PDR-0008 (Curiosities) — originally superseded by PDR-0004 (amended 2026-05-09) | 2026-05-07 | Market / Location / AI / Play | Originally a standalone consumer city-exploration app. Absorbed into Wayside 2026-05-09 (PDR-0004 §P), then **superseded 2026-05-16 by PDR-0008**, which makes this PDR's question-mark discovery loop the v1 lead of a single discovery-first app. Live direction is PDR-0008. |
| [PDR-0008](PDR-0008-curiosities-discovery-first-city-app.md) | Curiosities: Discovery-First City App | Proposed | 2026-05-16 | Market / Location / AI / Play | Supersedes PDR-0004 and PDR-0007. Inverts Wayside's priority: curated question-mark discovery is the v1 lead loop; walk-memory + Mochi is the retention backbone; public UGC marginalia cut from v1 (deferred post-v1). Content production named as the v1 critical path with explicit kill criteria. Atlas reframed as a discovery artifact. Direction-only; behind Notify Cloud and Hearth. |
| [PDR-0009](PDR-0009-honeyhub-as-internal-daily-driver-workspace.md) | HoneyHub as Internal Daily-Driver Workspace | Proposed | 2026-05-25 | Meta / Platform | Extends PDR-0001. Names internal-daily-driver fitness as a first-class success criterion peer to external-platform positioning. Upgrades the Architecture repo from "static context" to HoneyHub's structural backend. Names the composition model (structural + operational backends), PRs-as-artifacts boundary, generic per-Node management shell, and products-via-same-shell integration. No new Nodes, no scaffolding. |
| [PDR-0010](PDR-0010-agent-action-ledger-hosted-forensic-record-for-ai-agents.md) | Agent Action Ledger: Hosted Forensic Record for AI-Agent Actions | Proposed / Exploring | 2026-05-27 | Core / AI · Ops · Meta | Records the substrate-cluster bet identified by the product-strategist's Scout pass as the top 2-to-3-year SaaS opportunity behind Notify Cloud. Captures thinking only — not a green light. Hard sequencing: Notify Cloud (PDR-0002) launch → Audit Phase-1 (ADR-0031) lands → Audit Node v1.0 → strategist Critic-mode pass → only then considered for promotion. Default: hosted wrapper over existing Audit + IModelRouter + Capabilities + Vault, no new Grid Node. Cost-as-hook, audit-as-product boundary. Hard kill criteria (Notify Cloud sunset → collapse; Audit Phase-1 slips past 9 months → collapse; no >$30/mo buyer in 6 months post-launch → kill; no stuck design partner past month 3 → kill). |

## Statuses

- **Proposed** — Under discussion, not yet decided
- **Proposed / Exploring** — Direction recorded with explicit gating; not yet a commitment to build
- **Accepted** — Decision made, follow-up ADRs and roadmap items expected
- **Superseded** — Replaced by a newer PDR (link to replacement)
- **Rejected** — Considered and explicitly declined

## Relationship to ADRs

A PDR often precedes one or more ADRs. The PDR establishes the strategic direction; ADRs define the technical implementation boundaries. PDRs reference downstream ADRs in their "Recommended Follow-Up Artifacts" section.

## Creating a New PDR

Use the `pdr-composer` agent or create manually:

1. Copy the structure from an existing PDR
2. Use the next sequential number: `PDR-{NNNN}-{kebab-case-title}.md`
3. Include at minimum: Status, Date, Deciders, Context, Problem Statement, Decision, Options Evaluated, Tradeoffs, Consequences, Follow-Up Artifacts
4. Add a row to this index
