---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0039", "wave-3"]
dependencies: ["packet:01", "packet:05"]
adrs: ["ADR-0039", "ADR-0014"]
accepts: ["ADR-0039"]
wave: 3
initiative: adr-0039-license-policy
node: honeydrunk-architecture
---

# Add license-drift reconciliation to the hive-sync agent's responsibilities (ADR-0039 D8)

## Summary
Extend the `hive-sync` agent's definition (`.claude/agents/hive-sync.md`) so that, on each run, it reconciles the `license` field in `catalogs/nodes.json` against each repo's actual repo-root `LICENSE` / `LICENSE.md` file and reports any mismatch as drift — making invariant 67 (license-field-matches-LICENSE-file) an actively-enforced reconciliation, not just a written rule.

## Context
ADR-0039 D8 makes `catalogs/nodes.json` the single source of truth for each Node's license and assigns the reconciliation duty: "`hive-sync` (ADR-0014) reconciles the catalog with each repo's actual `LICENSE` file." ADR-0039's Operational Consequences names it explicitly: "License catalog reconciliation is a new `hive-sync` responsibility; the first run will surface existing LICENSE-file inconsistencies as drift to clean up." Invariant 67 (added by packet 00) states the rule; this packet makes `hive-sync` the enforcer.

The fan-out (packet 05) has already cleaned up the existing inconsistencies, so the *first* reconciliation run after this packet should be near-clean — but the responsibility must be permanent so future drift (a repo's `LICENSE` edited without a catalog update, or vice versa) is caught.

This is a docs/agent-definition-only packet. No code, no workflow, no .NET project — it edits the `hive-sync` agent's instruction file.

## Scope
- `.claude/agents/hive-sync.md` — add a license-drift reconciliation responsibility to the agent's instruction set.
- `catalogs/README.md` or the catalog-schema doc, if one exists — note that `hive-sync` reconciles the `nodes.json` `license` field. Do not create a new doc solely for this.
- ADR-0014's reconciliation-scope description, if `hive-sync`'s responsibilities are also enumerated in an ADR-0014-derived doc — keep the agent file and any such doc consistent.

## Proposed Implementation
1. **Add the reconciliation step to `hive-sync.md`.** In the agent's responsibilities section, add a "License drift" check: for each Node in `catalogs/nodes.json`, the agent reads the Node's `license` field and the repo-root `LICENSE` / `LICENSE.md` of the corresponding repo, and verifies they agree:
   - `license: MIT` ↔ the `LICENSE` file is the MIT license text.
   - `license: FSL-1.1-MIT` ↔ a `LICENSE.md` file with FSL-1.1-MIT text.
   - `license: proprietary` ↔ a short `LICENSE` file with the proprietary "All rights reserved. Proprietary to HoneyDrunk Studios LLC." reservation (ADR-0039 D4).
   A mismatch — or a missing `LICENSE` file, or a missing `license` field — is reported as drift.
2. **Match `hive-sync`'s existing drift-reporting mechanism.** `hive-sync` already reports drift (per ADR-0014 / invariant 37/38 — board-item correspondence, packet-path reconciliation). License drift is reported through whatever channel `hive-sync` already uses for its drift output (`initiatives/drift-report.md`, a board comment, or a backlog packet under `proposed/` per ADR-0043's reactive-source pattern — the implementing agent matches the existing convention; record which in the PR). Do not invent a new reporting surface.
3. **Detection depth is pragmatic.** The agent need not parse legal text token-by-token. A workable check: the SPDX identifier or the license-title line (`MIT License`, the FSL header, the proprietary reservation sentence) matches the catalog `license` value. The goal is catching a repo whose `LICENSE` says one thing while the catalog says another — not auditing license-text correctness.
   - **`visibility` consistency.** Packet 01 also added a `visibility` field (`public` | `private`) to every node entry. The reconciliation also checks the catalog is internally consistent: a `proprietary`-license Node must be `private`; an `MIT`/`FSL-1.1-MIT` Node must be `public`. An inconsistent pair (`proprietary` + `public`, or `MIT` + `private`) is reported as drift. This lets the public/private split be derived mechanically from the catalog rather than re-asserted in prose.
4. **No `hive-sync` schedule/trigger change.** `hive-sync` runs through OpenClaw scheduled/manual execution (invariant 38). This packet adds a *check* to an existing run, not a new run cadence.

## Affected Files
- `.claude/agents/hive-sync.md`
- the catalog-schema doc, if one exists (otherwise none)

## NuGet Dependencies
None. This packet edits an agent-definition Markdown file. No .NET project is created or modified.

## Boundary Check
- [x] Agent definitions and catalog reconciliation are `HoneyDrunk.Architecture` concerns. Routing rule "architecture, catalog → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.claude/agents/hive-sync.md` includes a license-drift reconciliation responsibility: for each Node, the `catalogs/nodes.json` `license` field is checked against the corresponding repo's repo-root `LICENSE` / `LICENSE.md`
- [ ] The check covers all three license values (`MIT`, `FSL-1.1-MIT`, `proprietary`) and flags a missing `LICENSE` file, a missing `license` field, or a missing `visibility` field as drift
- [ ] The check flags `license`/`visibility` inconsistency (`proprietary` not `private`, or a public license marked `private`) as drift
- [ ] License drift is reported through `hive-sync`'s existing drift-reporting mechanism — no new reporting surface is invented (PR records which mechanism)
- [ ] The detection is pragmatic (SPDX identifier / license-title line match), not a full legal-text audit
- [ ] No change to `hive-sync`'s run cadence or trigger — the check is added to existing runs
- [ ] If a catalog-schema doc exists, it notes that `hive-sync` reconciles the `license` field

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0039 D8 — License catalog.** "`hive-sync` (ADR-0014) reconciles the catalog with each repo's actual `LICENSE` file."

**ADR-0039 Operational Consequences.** "License catalog reconciliation is a new `hive-sync` responsibility; the first run will surface existing LICENSE-file inconsistencies as drift to clean up." (The fan-out in packet 05 cleans up the known inconsistencies first — the first post-packet-06 run should be near-clean.)

**ADR-0014 — `hive-sync` agent.** `hive-sync` runs through OpenClaw scheduled/manual execution and is the Grid's reconciliation agent for board-item correspondence and packet-path lifecycle (invariants 37, 38). License-drift reconciliation joins that responsibility set.

**Invariant 67 (added by packet 00).** Every Node has a `license` field in `catalogs/nodes.json` and a matching `LICENSE` file in the repo root; the SPDX expression (`MIT`, `FSL-1.1-MIT`, or `proprietary`) must match the actual file; drift is reconciled by `hive-sync`. This packet makes `hive-sync` the enforcer of that invariant.

## Constraints
- **Match `hive-sync`'s existing drift-reporting convention** — do not invent a new report file or surface.
- **Pragmatic detection** — identifier/title-line match, not legal-text parsing.
- **No new run cadence** — the check rides existing `hive-sync` runs.
- This packet does not bump a package version (no .NET project). Agents never push tags (invariant 27).

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0039`, `wave-3`

## Agent Handoff

**Objective:** Add license-drift reconciliation (catalog `license` field vs repo `LICENSE` file) to the `hive-sync` agent's responsibilities.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make invariant 67 actively enforced — `hive-sync` catches any future divergence between the `catalogs/nodes.json` `license` field and a repo's actual `LICENSE` file.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 3.
- ADRs: ADR-0039 (D8, Operational Consequences), ADR-0014 (`hive-sync` agent).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — the `license` catalog field (hard — the field `hive-sync` reconciles against).
- `packet:05` — the per-repo `LICENSE` reconciliation (soft ordering — packet 05 cleans up known drift so `hive-sync`'s first run is near-clean; `hive-sync` could technically ship before 05, but sequencing it after avoids a noisy first run).

**Constraints:**
- Match `hive-sync`'s existing drift-reporting mechanism — no new surface.
- Pragmatic detection — identifier/title-line match.
- No change to run cadence.

**Key Files:**
- `.claude/agents/hive-sync.md`
- the catalog-schema doc, if one exists

**Contracts:** No runtime contract. Extends the `hive-sync` agent's reconciliation responsibilities; consumes the `catalogs/nodes.json` `license` field (packet 01).
