---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0054", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0054"]
accepts: ["ADR-0054"]
wave: 1
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Author the D7 incident-record and D8 blameless post-mortem markdown templates

## Summary
Author the two concrete markdown template files ADR-0054 commits — the D7 incident-record template and the D8 blameless post-mortem template — at `generated/incidents/_templates/incident-record.md` and `generated/incidents/_templates/post-mortem.md`. These are the canonical templates the operator (and packet 08's generator) copies when filing a new incident or post-mortem.

## Context
ADR-0054 D7 specifies an incident-record template that lives at `generated/incidents/YYYY-MM-DD-<slug>.md` with structured front-matter. ADR-0054 D8 specifies a blameless post-mortem template at `generated/incidents/post-mortems/YYYY-MM-DD-<slug>.md`. The ADR embeds both templates inline as examples; this packet extracts them into concrete template files that:

1. Serve as the canonical source for new incidents and post-mortems (copy-and-fill).
2. Are consumed by packet 08's `HoneyDrunk.Actions` generator, which scaffolds a pre-filled file from the template.
3. Are referenced by the schema registered in packet 01's `contracts.json` entry.

**`generated/incidents/` already exists** as a directory in this repo, referenced by `CLAUDE.md`. No directory creation needed — but the `_templates/` subdirectory is new. The post-mortem template needs `generated/incidents/post-mortems/` to exist; create it as an empty directory with a `.gitkeep` if necessary so future post-mortems have a home.

**Template content is fixed by the ADR.** The two templates' exact structure is given in ADR-0054 D7 (incident-record) and D8 (blameless post-mortem). Use the ADR's wording verbatim where the ADR specifies the structure; add comments / TODO placeholders where a section needs operator input at fill time.

This is a docs/templates packet. No code, no .NET project.

## Scope
- `generated/incidents/_templates/incident-record.md` (new) — the D7 incident-record template.
- `generated/incidents/_templates/post-mortem.md` (new) — the D8 blameless post-mortem template.
- `generated/incidents/post-mortems/.gitkeep` (new) — ensure the post-mortems directory exists.
- `generated/incidents/_templates/README.md` (new, optional) — a one-page note describing how the templates are used (manually copied, or scaffolded by packet 08's generator).

## Proposed Implementation
1. **`incident-record.md` template.** Author exactly the structure ADR-0054 D7 specifies. The front-matter:
   ```yaml
   ---
   incident_id: INC-YYYY-NNNN
   severity: SEV-N
   status: Open  # Open | Acknowledged | Investigating | Mitigating | Resolved | Reviewing | Closed
   opened_at: YYYY-MM-DDTHH:MM:SSZ
   acknowledged_at:
   investigating_at:
   mitigating_at:
   resolved_at:
   reviewing_at:
   closed_at:
   customer_impact: no
   affected_tenants: []
   affected_nodes: []
   alert_sources: []
   mtta_minutes:
   mtmitigate_minutes:
   mttr_minutes:
   post_mortem_required: no
   post_mortem_link:
   ---
   ```
   The body sections (from D7): `# INC-YYYY-NNNN: <title>`, `## Summary` (one-paragraph customer-facing summary), `## Timeline` (append-only during the incident, frozen at close), `## Root cause` ("unknown — investigating" is a valid root cause at incident close), `## Mitigation` (what was done to restore service), `## Customer communication` (status-page and tenant-email entries with timestamps), `## Follow-ups` (linked to issue packets or ADR amendments — an incident producing no follow-ups is itself a signal worth noting), `## Post-mortem` (link or "Not required for this SEV"). Include placeholder TODO comments on each section so the operator knows what to fill in.

2. **`post-mortem.md` template.** Author exactly the structure ADR-0054 D8 specifies. The front-matter:
   ```yaml
   ---
   incident_id: INC-YYYY-NNNN
   post_mortem_id: PM-YYYY-NNNN
   authored_at: YYYY-MM-DDTHH:MM:SSZ
   participants: [operator]
   related_adrs: []
   follow_up_packets: []
   ---
   ```
   The body sections (from D8): `# PM-YYYY-NNNN: <title> (YYYY-MM-DD)`, `## What happened` (factual narrative, no blame language), `## Impact` (customer impact, business impact, internal cost in operator hours), `## Root cause` (five-whys depth where useful), `## What went well`, `## What went poorly`, `## Where we got lucky` (things that worked by accident — catching these is the whole point of the blameless review), `## Action items` (concrete follow-ups, each linked to an issue packet or ADR amendment, with owner / deadline / status), `## Glossary / Links` (relevant ADRs, dashboards, related incidents). Include the **blameless principle** as a header comment in the template: "The post-mortem describes systems, processes, and tools — never individual fault. In a one-person studio, the operator IS the only individual; blameless language is doubly important because self-blame is the failure mode. The point is to fix the system, not the human."

3. **`post-mortems/.gitkeep`.** Create the subdirectory so future post-mortems have a home; the `.gitkeep` is the only file in it until a real post-mortem lands.

4. **`_templates/README.md` (optional).** A short note describing how the templates are used: copy manually for v0; scaffolded by `HoneyDrunk.Actions` (packet 08) for v1. Cross-reference the schema registered in packet 01.

5. **Front-matter fields are machine-readable** per D7. Use YAML, not custom syntax — `hive-sync` consumes the front-matter for MTTA/MTTR dashboards and the incident-volume report.

## Affected Files
- `generated/incidents/_templates/incident-record.md` (new)
- `generated/incidents/_templates/post-mortem.md` (new)
- `generated/incidents/post-mortems/.gitkeep` (new)
- `generated/incidents/_templates/README.md` (new, optional)

## NuGet Dependencies
None. This packet creates only markdown template files; no .NET project is created or modified.

## Boundary Check
- [x] All files in `HoneyDrunk.Architecture/generated/incidents/`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] The templates are the canonical source consumed by packet 08's generator; this packet does not author the generator.

## Acceptance Criteria
- [ ] `generated/incidents/_templates/incident-record.md` exists with the D7 front-matter (incident_id, severity, status, the seven lifecycle timestamps, customer_impact, affected_tenants, affected_nodes, alert_sources, mtta/mtmitigate/mttr minutes, post_mortem_required, post_mortem_link) and the D7 body sections (Summary, Timeline, Root cause, Mitigation, Customer communication, Follow-ups, Post-mortem) with TODO placeholders
- [ ] `generated/incidents/_templates/post-mortem.md` exists with the D8 front-matter (incident_id, post_mortem_id, authored_at, participants, related_adrs, follow_up_packets) and the D8 body sections (What happened, Impact, Root cause, What went well, What went poorly, Where we got lucky, Action items, Glossary / Links) and the blameless-principle header comment
- [ ] `generated/incidents/post-mortems/.gitkeep` exists so the subdirectory is tracked
- [ ] The front-matter is valid YAML — `hive-sync` can parse it for MTTA/MTTR aggregation
- [ ] The template files are referenced by the schema registered in packet 01's `contracts.json` entry
- [ ] No code or workflow is added in this packet (the generator lands in packet 08)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0054 D7 — Incident record template.** The full template structure as embedded in the ADR. Front-matter fields are machine-readable; `mtta_minutes`, `mtmitigate_minutes`, `mttr_minutes` are computed from the timestamps. The timeline is append-only during the incident and frozen at close. "Unknown — investigating" is a valid root cause at close; the post-mortem refines it. Follow-ups link to issue packets (per ADR-0008) or ADR amendments — an incident producing no follow-ups is itself a signal worth noting.

**ADR-0054 D8 — Blameless post-mortem template.** The full template structure as embedded in the ADR. **Blameless principle:** the post-mortem describes systems, processes, and tools — never individual fault. In a one-person studio, the operator IS the only individual; blameless language is doubly important because self-blame is the failure mode. Patterns across multiple post-mortems trigger ADR-level changes; a quarterly retrospective reads the last 90 days of post-mortems and produces a meta-report.

**ADR-0054 D6 — Incident lifecycle (seven states).** The seven states (Open → Acknowledged → Investigating → Mitigating → Resolved → Reviewing → Closed) are referenced by the front-matter's `status` field and the seven lifecycle timestamps.

## Constraints
- **Faithful to the ADR.** Use the ADR's wording verbatim where the ADR specifies the template structure. Do not invent new sections.
- **Valid YAML front-matter.** `hive-sync` parses the front-matter for MTTA/MTTR aggregation; broken YAML breaks the dashboard.
- **No generator in this packet.** The `HoneyDrunk.Actions` generator that scaffolds a pre-filled file from the template lands in packet 08.
- **No real incident in this packet.** The templates are blank canonical examples — no actual incident_id, no actual timestamps.
- **Blameless principle inlined.** The post-mortem template's header comment carries the blameless-principle text from D8 verbatim — it is load-bearing for one-person operation.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0054`, `wave-1`

## Agent Handoff

**Objective:** Author the D7 incident-record and D8 blameless post-mortem markdown templates at `generated/incidents/_templates/` so the operator (and packet 08's generator) can scaffold new incidents and post-mortems from them.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the two canonical template files that the schema in packet 01 references and the generator in packet 08 consumes.
- Feature: ADR-0054 Incident Response rollout, Wave 1.
- ADRs: ADR-0054 D7/D8 (primary), ADR-0054 D6 (lifecycle state names used in the front-matter).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0054 should be Accepted before its templates land as canonical files.

**Constraints:**
- Faithful to the ADR's template structure (verbatim where the ADR specifies wording).
- Valid YAML front-matter; broken YAML breaks `hive-sync` aggregation.
- No generator code in this packet (packet 08 owns it).
- Blameless principle inlined verbatim in the post-mortem template header.

**Key Files:**
- `generated/incidents/_templates/incident-record.md` (new)
- `generated/incidents/_templates/post-mortem.md` (new)
- `generated/incidents/post-mortems/.gitkeep` (new)

**Contracts:** The two template files are the canonical artifacts the schema in packet 01 binds.
