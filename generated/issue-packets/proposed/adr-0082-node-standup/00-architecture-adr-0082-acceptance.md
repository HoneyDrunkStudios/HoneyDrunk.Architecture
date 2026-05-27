---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0082", "wave-1"]
dependencies: []
adrs: ["ADR-0082", "ADR-0007", "ADR-0008", "ADR-0011", "ADR-0012", "ADR-0014", "ADR-0034", "ADR-0044", "ADR-0046"]
accepts: ["ADR-0082"]
wave: 1
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Accept ADR-0082 — flip status, claim invariant 102 for the node-registration-mandatory rule, register initiative

## Summary

Flip ADR-0082 (Canonical Node Standup Procedure) from Proposed to Accepted: update the ADR header, append an ADR-0082 row to `adrs/README.md`, write **invariant 102** (D6's "Node registration mandatory before first non-bootstrap PR" rule — pre-reserved alongside ADR-0083's 103 in `constitution/invariant-reservations.md` per the refine pass coordination) into `constitution/invariants.md` under a new `## Standup Procedure Invariants` section, and register the `adr-0082-node-standup` initiative in `initiatives/active-initiatives.md` with the seven-packet checklist. This packet is acceptance-only; the canonical procedure document and the per-class walkthroughs land in subsequent packets in this initiative.

## Context

ADR-0082 commits the **canonical Node standup procedure** that every Grid standup has been ad-hoc re-deriving from precedent since the Communications standup (ADR-0019). The ADR names eight bound sub-decisions:

- **D1** — one canonical procedure document at `constitution/node-standup.md` (new file landed by packet 01).
- **D2** — a six-class Node taxonomy (Core .NET Abstractions+Runtime, Core .NET Runtime-only, Ops Deployable .NET, Meta/Docs/Wiki, AI Seed scaffold-only, Studios/TypeScript). Closed for 2026-05-25; new classes amend D2's row and add a per-class walkthrough, not a new ADR.
- **D3** — three-phase procedure with hard prerequisite gates: Phase A Architecture registration → Phase B GitHub repo creation (human-only org-admin) → Phase C scaffold landing (agent-eligible). Optional Phase D hive-sync reconciliation.
- **D4** — eighteen mandatory steps for every Node class (sector assignment, context folder, catalog entries, repo, branch protection, repo-to-node mapping, label seeding, `.honeydrunk-review.yaml`, CodeRabbit, README/CHANGELOG/LICENSE, `.github/copilot-instructions.md`, optional CLAUDE.md, `pr-core.yml`, initiative entry).
- **D5** — class-specific steps (a–z): .slnx + Directory.Build.props + Standards reference; test project layout; release.yml + nightly-deps + nightly-security; OIDC federated credential subject pattern; contract-shape canary; in-memory fixture; smoke test; `sonar-project.properties` + `job-sonarcloud.yml`. Ops adds Key Vault per env, App Config per env, managed identity per env, Container Apps wiring, Bicep modules, deploy trigger model, health endpoints. Meta drops NuGet/OIDC. AI Seed is Phase A only. Studios/TypeScript replaces .slnx/Directory.Build.props/Standards with `package.json`/`tsconfig.json`/ESLint+Prettier and adds Node.js CI.
- **D6** — **new invariant** (the one this packet writes): every Node repo must have, before its first non-bootstrap PR merges, ten things: `catalogs/nodes.json` row, `catalogs/relationships.json` edges, `catalogs/grid-health.json` row, five-file `repos/{Node}/` context folder, `constitution/sectors.md` row, `repo-to-node.yml` mapping, `.honeydrunk-review.yaml` at repo root, `pr.yml` calling `pr-core.yml`, branch protection requiring `pr-core / core`, **and org-secret repo binding** for every org Actions secret the repo's workflows reference (minimum `SONAR_TOKEN`; conditional `NUGET_API_KEY`, `LABELS_FANOUT_PAT`, `HIVE_FIELD_MIRROR_TOKEN`, `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`, ADR-0084 Discord webhook stack, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`). The scaffold PR (the first PR after repo creation) is the "bootstrap PR" and is permitted to introduce items 7–10 in the same commit; the invariant binds the second PR.
- **D7** — six follow-up walkthroughs unlocked: five per-class node-standup walkthroughs in `infrastructure/walkthroughs/` plus `org-secret-repo-binding.md`. (`sonarcloud-org-onboarding.md` is named in D7 as already-owned by the ADR-0011 acceptance pass — the existing `sonarcloud-organization-setup.md` covers this; this initiative does not re-author it.)
- **D8** — org-secret access propagation is not automatic. `Selected repositories` is the Grid default for live-credential org secrets; promoting to `All repositories` requires an ADR amendment. The per-class binding matrix lives in `constitution/node-standup.md` (per D1) and is updated as the org-secret inventory grows (cross-cutting ADR-0083 D5/D6).

ADR-0082 is **Tier 3 process architecture**. No code changes, no runtime impact. The follow-up walkthrough packets are Tier 2 docs.

This is a docs/governance-only acceptance packet. No code, no workflow, no .NET project.

## Invariant Numbering

ADR-0082 adds exactly **one** invariant (D6 — the node-registration-mandatory rule), numbered **102**. The slot is **pre-assigned in `constitution/invariant-reservations.md`** alongside ADR-0083's 103 to avoid the "first merge wins" placeholder race between the two adjacent ADRs (the refine pass committed this coordination). The reservation row already exists in the registry; this packet writes the invariant text into `constitution/invariants.md` and consumes the reservation by referencing 102 directly. No placeholder substitution at edit time; no upward-shift contingency.

The invariant lands under a **new** `## Standup Procedure Invariants` section in `constitution/invariants.md` (no existing section is the right home — it is not Dependency, Context, Secrets, Packaging, Testing, Audit, Code Review, Infrastructure, Hive Sync, Multi-Tenant, Communications, or AI; standup procedure is its own concern). Place the new section after the existing `## Communications Invariants` section.

## Scope

- `adrs/ADR-0082-canonical-node-standup-procedure.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — append the ADR-0082 row (Accepted, 2026-05-25, Meta) at the end of the existing table. **Scope-creep acknowledgement:** the index currently has gaps (per the ADR-0079 acceptance packet's note, the index lags behind disk by ~21 rows); this packet appends only the ADR-0082 row and does not backfill.
- `constitution/invariants.md` — add a new `## Standup Procedure Invariants` section after `## Communications Invariants`, containing one invariant numbered **102** (the reservation is already pre-assigned in `constitution/invariant-reservations.md`).
- `constitution/invariant-reservations.md` — **no edit needed in this packet for the reservation row itself** (the row claiming 102 for ADR-0082 was pre-assigned alongside ADR-0083's 103 in the refine pass). Update only the row's `Status` from `Proposed` to `Proposed → Accepted` if the registry's convention tracks acceptance status in that column.
- `initiatives/active-initiatives.md` — register the `adr-0082-node-standup` initiative with the packet checklist for this folder.

## Proposed Implementation

1. **Confirm the pre-assigned invariant slot.** Open `constitution/invariant-reservations.md` and verify the row claiming **102** for ADR-0082 already exists in the **Active Reservations** table (the refine pass pre-assigned 102 to ADR-0082 and 103 to ADR-0083 to avoid the placeholder race; both rows live in the registry). If the registry's convention tracks acceptance status, mark the ADR-0082 row's Status as `Proposed → Accepted` in the same PR as the ADR header flip. No upward-shift contingency — the slot is fixed at 102.

2. Edit the ADR-0082 header: `**Status:** Proposed` → `**Status:** Accepted`.

3. Append an ADR-0082 row to `adrs/README.md`'s index table. Append at the end of the existing table; do not backfill prior missing rows. Use the existing column shape (link, title, status, date, sector, description). Title: "Canonical Node Standup Procedure". Date: 2026-05-25. Sector: Meta. Description: one paragraph naming the canonical procedure document (`constitution/node-standup.md`), the six-class taxonomy, the three-phase prerequisite chain, the org-secret repo-binding policy, and that the procedure is the one source future standup packets reference.

4. Add a new `## Standup Procedure Invariants` section to `constitution/invariants.md` after the existing `## Communications Invariants` section (which ends at invariant 43 in current text — verify section order in the file before placement; if the file has been reordered since this packet's authoring, place the new section in the topical position that mirrors ADR sector — Meta — adjacent to other meta-process invariants).

5. Add the new invariant under that section, numbered **102** (pre-assigned per step 1). Text, verbatim-in-substance from ADR-0082 D6:

   - **102 — Node registration is mandatory before the first non-bootstrap PR merges.** Every Node repo must have, before its first non-bootstrap PR merges:
     1. an entry in `catalogs/nodes.json` (Node row),
     2. a corresponding edges section in `catalogs/relationships.json`,
     3. an entry in `catalogs/grid-health.json`,
     4. a context folder at `repos/{NodeName}/` with all five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`),
     5. a sector row in `constitution/sectors.md`,
     6. a `repo-to-node.yml` mapping in `HoneyDrunk.Actions/.github/config/`,
     7. a `.honeydrunk-review.yaml` at the repo root with `enabled: true` or `enabled: false` explicitly declared,
     8. a `pr.yml` workflow calling `HoneyDrunk.Actions`'s `pr-core.yml`,
     9. branch protection on `main` requiring the `pr-core / core` status check, **and**
     10. **org-secret repo binding** — the org admin has bound the new repo to every org Actions secret the repo's workflows reference. Minimum set for any Node consuming `pr-core.yml` is `SONAR_TOKEN` (ADR-0011 D11). Per-class conditional additions (`NUGET_API_KEY`, `LABELS_FANOUT_PAT`, `HIVE_FIELD_MIRROR_TOKEN`, `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`, the ADR-0084 Discord webhook stack, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`) follow the matrix in `constitution/node-standup.md`. GitHub does not auto-propagate org secrets with `Selected repositories` access policy, so without this step the new repo's first non-bootstrap PR consuming any of those secrets hard-fails — silently in the case of empty-string substitution, loudly for explicit-required wiring.

     A "bootstrap PR" is the scaffold PR itself (the first PR after repo creation, landing the scaffold packet — exemplar `03-{node}-node-scaffold.md`). A bootstrap PR is permitted to introduce items 7, 8, 9, and 10 in the same commit as the rest of the scaffold; the invariant binds the *second* PR (the first feature PR). Items 1–6 must exist before the scaffold PR (they are Phase A; the scaffold is Phase C; Phase A merges first per D3's prerequisite gate).

     Enforcement: procedural — human review at PR time, supplemented by the `review` agent per ADR-0044 D3 category 10 (Enterprise readiness / supportability) for items 1–9 (catalog rows, context folder, sectors row, repo-to-node mapping, .honeydrunk-review.yaml, pr.yml, branch protection), the `node-audit` agent per ADR-0043's Tactical source, and the `hive-sync` agent's reconciliation pass per Invariant 38. **Item 10 — org-secret repo binding — is NOT checkable by the `review` agent at v1**: the GitHub org-secret repository-access policy is admin-only API surface, and the `review` agent runs without an admin token. Item-10 enforcement reduces to operator memory and the per-class binding matrix in `constitution/node-standup.md` at v1. A future packet may add a manual `gh secret list` operator checklist step or a dedicated admin-token cron, but neither is committed by ADR-0082. No CI gate at this time (the catalogs and the new repo are in different repositories — a cross-repo CI gate is an unblocked follow-up, not committed by ADR-0082). See ADR-0082 D6, D8.

6. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. Place it after the existing ADR-0079 entry (the closest topical neighbor — both Meta governance, both PR-procedure-adjacent).

## Affected Files

- `adrs/ADR-0082-canonical-node-standup-procedure.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies

None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria

- [ ] ADR-0082 header reads `**Status:** Accepted`
- [ ] `constitution/invariant-reservations.md` already carries the pre-assigned ADR-0082 row for slot **102** in **Active Reservations** (added in the refine pass alongside ADR-0083's 103); this packet does not add or shift the row, only optionally marks Status as `Proposed → Accepted` if the registry convention tracks acceptance there
- [ ] An ADR-0082 row exists in `adrs/README.md`'s index, appended to the end of the existing table, with status Accepted, date 2026-05-25, sector Meta, and a faithful one-paragraph description
- [ ] `constitution/invariants.md` carries a new `## Standup Procedure Invariants` section containing invariant **102** (the node-registration-mandatory rule with the ten enumerated items, the bootstrap-PR carve-out, the procedural-enforcement clause, and a citation of ADR-0082 D6/D8)
- [ ] `initiatives/active-initiatives.md` registers the `adr-0082-node-standup` initiative with a packet checklist (00 acceptance, 01 canonical procedure doc, 02–06 per-class walkthroughs, 07 org-secret repo-binding walkthrough), placed near the ADR-0079 entry
- [ ] Repo-level `CHANGELOG.md` updated with a new entry for the governance/docs change (per invariant 12 + 27); since `HoneyDrunk.Architecture` is not a versioned .NET solution, follow the existing repo CHANGELOG convention for governance edits
- [ ] No `constitution/node-standup.md` change in this packet (that lands in packet 01); no walkthrough authoring (packets 02–07)

## Human Prerequisites

None.

## Referenced ADR Decisions

**ADR-0082 D1 — One canonical procedure document, in the constitution.** Lives at `constitution/node-standup.md`; landed by packet 01 of this initiative. Edits are PR-reviewed against this ADR — no ADR amendment per update unless D2 taxonomy or D6 invariant wording changes.

**ADR-0082 D2 — Six Node-class taxonomy.** Core .NET Abstractions+Runtime (default), Core .NET Runtime-only, Ops Deployable .NET, Meta/Docs/Wiki, AI Seed (scaffold-only), Studios/TypeScript. Closed for 2026-05-25; future class additions require a one-row amendment to D2 plus a per-class walkthrough.

**ADR-0082 D3 — Three-phase prerequisite chain.** Phase A (Architecture registration, no GitHub repo yet) → Phase B (GitHub repo creation, human-only org-admin) → Phase C (scaffold landing, agent-eligible). Optional Phase D (hive-sync reconciliation). The Phase A→B and Phase B→C boundaries are physical (cross-repo state transitions).

**ADR-0082 D6 — Node registration mandatory invariant.** The text written by this packet. Procedural enforcement at solo-developer + AI-agent scale; CI gate is an unblocked follow-up.

**ADR-0082 D8 — Org-secret access propagation is not automatic.** `Selected repositories` is the Grid default. Promotion to `All repositories` requires an ADR amendment. Per-class binding matrix lives in `constitution/node-standup.md` per D1, not in this ADR; ADR-0082 commits the *policy* that the binding step exists, not the snapshot of the list.

## Constraints

- **Acceptance precedes flip.** ADR-0082 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant number is pre-assigned at 102.** The reservation row for ADR-0082 at slot 102 already exists in `constitution/invariant-reservations.md` (paired with ADR-0083's 103 reservation by the refine pass). This packet writes the invariant text into `constitution/invariants.md` referencing 102 directly. The invariant lands under a **new** `## Standup Procedure Invariants` section. Do not renumber existing invariants. **No "first merge wins" contingency** — both 102 and 103 are pre-assigned; no upward shift is required between authoring and merge.
- **Invariant text is verbatim-in-substance from D6.** Do not paraphrase or compress. The ten-item enumeration, the bootstrap-PR carve-out, and the procedural-enforcement clause must all appear in the invariant body.
- **No `constitution/node-standup.md` work in this packet.** That is packet 01. This packet is acceptance + invariant + initiative registration only.
- **No walkthrough authoring in this packet.** Packets 02–07 own the walkthroughs.
- **`adrs/README.md` is append-only for this packet.** Do not backfill prior missing rows. Append only the ADR-0082 row.
- **One PR per repo per initiative.** This packet is the only Architecture packet in Wave 1; subsequent Architecture packets in this initiative are Wave 2.
- **PR body metadata.** Every PR body must include strict `Authorship: <enum>` plus exactly one of `Packet:` (pointing at this packet path) or `Out-of-band reason:` — free-form text breaks pr-core checks.

## Labels

`chore`, `tier-3`, `meta`, `docs`, `adr-0082`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0082 to Accepted, write the pre-assigned **invariant 102** (the node-registration-mandatory rule from D6) into a new `## Standup Procedure Invariants` section in `constitution/invariants.md`, append the ADR-0082 row to `adrs/README.md`, and register the `adr-0082-node-standup` initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0082 so the remaining packets (01 canonical procedure doc, 02–06 per-class walkthroughs, 07 org-secret binding walkthrough) can reference its decisions as live rules and the new invariant binds future standups.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 1.
- ADRs: ADR-0082 (primary), ADR-0007 (`.claude/agents/` location), ADR-0008 (packet/issue/board lifecycle), ADR-0011 D11 (SonarCloud org-secret forcing example), ADR-0012 (reusable workflow factoring), ADR-0014 (hive-sync org-secret stack), ADR-0034 (NuGet publishing org secret), ADR-0044 (`.honeydrunk-review.yaml` gate), ADR-0046 (specialist review agents context).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0082 stays Proposed until this PR merges.
- Invariant 102 is pre-assigned in `constitution/invariant-reservations.md` (paired with ADR-0083's 103 by the refine pass); write it directly into `constitution/invariants.md` under a new `## Standup Procedure Invariants` section. Do not renumber existing invariants. No upward-shift contingency.
- Invariant text is verbatim-in-substance from ADR-0082 D6 — the ten-item enumeration, the bootstrap-PR carve-out, and the procedural-enforcement clause all appear in the body.
- No procedure doc, no walkthrough authoring in this packet — those are packets 01–07.
- `adrs/README.md` is append-only — do not backfill prior missing rows.
- PR body carries strict `Authorship: <enum>` + exactly one of `Packet:` / `Out-of-band reason:`.

**Key Files:**
- `adrs/ADR-0082-canonical-node-standup-procedure.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
