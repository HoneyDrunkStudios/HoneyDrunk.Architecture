# Product Decision Records

Index of all PDRs for the HoneyDrunk Grid.

PDRs capture **product-level strategic decisions** — platform positioning, domain boundaries, capability tier definitions, and ecosystem expansion. They carry enough architectural depth to guide future ADRs, roadmap planning, and node boundaries, but the primary lens is product strategy, not implementation.

For technical architecture decisions, see [ADRs](../adrs/README.md).

| ID | Title | Status | Date | Sector | Impact |
|----|-------|--------|------|--------|--------|
| [PDR-0001](PDR-0001-honeyhub-platform-observation-and-ai-routing.md) | HoneyHub Platform: Observation and AI Routing Layers | Accepted | 2026-03-30 | Meta / AI | Positions HoneyHub as an external-facing platform. Introduces Observation and AI Routing domains. |
| [PDR-0002](PDR-0002-notify-as-a-service-first-commercial-product.md) | HoneyDrunk Notify: First Commercial Product on the Grid | Proposed | 2026-05-02 | Ops / Meta | Names HoneyDrunk Notify (Notify Cloud architecturally) as the Grid's first commercial app. Reframes PDR-0001 §C — HoneyHub is no longer the external-facing product. Open core: Notify engine OSS (FSL/BSL), `HoneyDrunk.Notify.Cloud` wrapper private. |
| [PDR-0003](PDR-0003-lately-currents-based-connection-app.md) | Lately: Currents-Based Connection App | Proposed | 2026-05-05 | Apps | Consumer connection app (codename Lately). Currents-based matching (current book/show/album), nightly Room with fingerprint mechanic. Introduces Apps sector for consumer surfaces. Sequenced after Notify Cloud public launch. |
| [PDR-0004](PDR-0004-wayside-walking-and-public-place-notes.md) | Wayside: Walking and Public Place-Notes | Proposed | 2026-05-05 | Apps | Consumer walking + place-memory app (codename Wayside). Hand-drawn watercolor maps, Mochi companion, public place-notes layer with 30-day decay. Yearly Atlas print-on-demand revenue hook. Direction-only; deferred behind Notify Cloud and Hearth. |
| [PDR-0005](PDR-0005-hearth-personal-growth-as-a-living-town.md) | Hearth: Personal Growth as a Living Town | Proposed | 2026-05-05 | Apps | Consumer personal-growth app (codename Hearth). Reflections, goals, care actions, creative sessions, and milestones build a sentiment/growth-responsive town; Tomoe pen-pal NPC; no streaks or XP grind ever. Yearly Artifact + Founding Townsfolk lifetime tier. Consumer wedge alongside Notify Cloud. |
| [PDR-0006](PDR-0006-currents-social-suggestions-and-quests.md) | Currents: Social Suggestions and Lightweight Quests | Proposed | 2026-05-06 | Apps / AI / Social | Consumer social discovery app around active books/shows/music/games/places/projects. Turns Currents into suggestions and small-group prompts/quests; no XP, streaks, public feed, or dating surface at v1. |

## Statuses

- **Proposed** — Under discussion, not yet decided
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
