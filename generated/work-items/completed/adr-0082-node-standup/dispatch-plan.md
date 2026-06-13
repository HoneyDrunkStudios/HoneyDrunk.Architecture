# Dispatch Plan — ADR-0082: Canonical Node Standup Procedure

**Initiative:** `adr-0082-node-standup`
**ADR:** ADR-0082 (Proposed → Accepted via packet 00)
**Sector:** Meta (governance + standup procedure)
**Created:** 2026-05-26

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0082 commits the **canonical Grid Node standup procedure** that every previous standup re-derived from precedent. The initiative produces:

- Acceptance + one new invariant (D6 — node-registration-mandatory before first non-bootstrap PR; **invariant 102**, pre-assigned in the reservation registry alongside ADR-0083's 103 by the refine pass to avoid the placeholder race).
- The **canonical procedure document** at `constitution/node-standup.md` (the load-bearing deliverable; D1).
- **Five per-class walkthroughs** in `infrastructure/walkthroughs/` (D7): Core .NET, Ops Deployable .NET, Meta/Docs/Wiki, AI Seed, Studios/TypeScript.
- The **org-secret repo-binding walkthrough** (D7/D8) covering the manual GitHub portal step the per-class walkthroughs reference.

**8 packets across 3 waves**, all targeting **`HoneyDrunk.Architecture`** (single-repo initiative — no code or infrastructure changes anywhere else). All 8 `Actor=Agent`. No `Actor=Human`. No human prerequisites for packet *authoring* — the walkthroughs themselves describe future human portal steps for future standups.

This initiative deliberately does NOT include:
- The `sonarcloud-org-onboarding.md` walkthrough — ADR-0082 D7 names it but explicitly assigns it to the ADR-0011 acceptance pass; the existing `infrastructure/walkthroughs/sonarcloud-organization-setup.md` already covers it.
- Any standup of a new Node — ADR-0082 commits *the procedure*, not a procedure execution.
- Backfill / amendment of prior standup ADRs (ADR-0019 / ADR-0027 / ADR-0031 / ADR-0059 / ADR-0060 / ADR-0061 / ADR-0071) — per ADR-0082's Consequences, retrofitting is explicitly out of scope.

## Trigger

ADR-0082's Context identifies the gap surfacing during the ADR-0011 acceptance work (currently in flight on branch `adr-0011-acceptance`): wiring `sonar-project.properties` + `job-sonarcloud.yml` into every public repo asked "where is the canonical procedure I'm extending?" — and got no answer. Each new standup pays a 30–60-minute "rediscover the procedure" tax. AI-authored standup packets (per ADR-0044 D6) have no procedure to reference, so they re-derive from whichever recent ADR they happened to read.

Concrete drift channels already in the wild per ADR-0082's Context:
- The `repo-to-node.yml` mapping was added retroactively for Audit (commit `23a183c`) after the Audit standup packets had been filed.
- ADR-0044's `.honeydrunk-review.yaml` gate (Invariant 52) and ADR-0011's tier-1 `pr-core / core` check (Invariant 31) live in different cross-cutting ADRs; standup is expected to discover both.
- Contract-shape canary obligations re-justified per Node rather than treated as a standard step.
- "Public by default unless ADR-recorded carve-out" lived in memory rather than in the constitution.

## Scope Detection

**Single-repo.** All 8 packets target `HoneyDrunk.Architecture`. The ADR is process architecture — it commits how future standups happen but does not standup anything itself. No code change in any other repo; no relationships-graph edge change; no catalog entry added by this initiative (the procedure governs how future catalogs land, not its own).

## Wave Diagram

### Wave 1 (governance — acceptance)
- [ ] **00** — Architecture: Accept ADR-0082, write **invariant 102** (D6 node-registration-mandatory rule; pre-assigned in the reservation registry alongside ADR-0083's 103) into a new `## Standup Procedure Invariants` section, append ADR-0082 row to `adrs/README.md`, register initiative. `Actor=Agent`.

### Wave 2 (canonical procedure document)
- [ ] **01** — Architecture: Author `constitution/node-standup.md` per D1 — three-phase chain (D3), eighteen mandatory steps (D4), class-specific steps a–z (D5), per-class org-secret binding matrix (D8). `Actor=Agent`. Blocked by: 00.

### Wave 3 (per-class walkthroughs + org-secret binding walkthrough — parallel)
- [ ] **02** — Architecture: Author `infrastructure/walkthroughs/node-standup-core-dotnet.md` (D5 a–m + post-merge throwaway-PR canary ritual). `Actor=Agent`. Blocked by: 01.
- [ ] **03** — Architecture: Author `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` (D5 n–t + deploy plumbing + health endpoints). `Actor=Agent`. Blocked by: 01.
- [ ] **04** — Architecture: Author `infrastructure/walkthroughs/node-standup-meta-docs.md` (D5 u–v reduced procedure + content-shape canary for content-shipping Meta repos). `Actor=Agent`. Blocked by: 01.
- [ ] **05** — Architecture: Author `infrastructure/walkthroughs/node-standup-ai-seed.md` (D5 w — Phase A only — plus promotion gate to Core .NET). `Actor=Agent`. Blocked by: 01.
- [ ] **06** — Architecture: Author `infrastructure/walkthroughs/node-standup-studios-typescript.md` (D5 x–z — TS replacements, Node.js CI, Web.UI design-token consumption). `Actor=Agent`. Blocked by: 01.
- [ ] **07** — Architecture: Author `infrastructure/walkthroughs/org-secret-repo-binding.md` (D7/D8 — portal click-path; per-class matrix snapshot; stop-condition on unexpected access policy). `Actor=Agent`. Blocked by: 01.

Packets 02–07 are parallel within Wave 3 — they all depend on packet 01 (which holds the canonical rules they compose against) but have no inter-walkthrough dependencies. One PR per packet per the "one PR per repo per initiative" convention applied per packet.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0082](./00-architecture-adr-0082-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [`constitution/node-standup.md`](./01-architecture-node-standup-procedure-doc.md) | Architecture | Agent | 2 | 00 |
| 02 | [Walkthrough — Core .NET](./02-architecture-walkthrough-node-standup-core-dotnet.md) | Architecture | Agent | 3 | 01 |
| 03 | [Walkthrough — Ops Deployable .NET](./03-architecture-walkthrough-node-standup-ops-deployable-dotnet.md) | Architecture | Agent | 3 | 01 |
| 04 | [Walkthrough — Meta / Docs / Wiki](./04-architecture-walkthrough-node-standup-meta-docs.md) | Architecture | Agent | 3 | 01 |
| 05 | [Walkthrough — AI Seed](./05-architecture-walkthrough-node-standup-ai-seed.md) | Architecture | Agent | 3 | 01 |
| 06 | [Walkthrough — Studios / TypeScript](./06-architecture-walkthrough-node-standup-studios-typescript.md) | Architecture | Agent | 3 | 01 |
| 07 | [Walkthrough — Org-Secret Repo Binding](./07-architecture-walkthrough-org-secret-repo-binding.md) | Architecture | Agent | 3 | 01 |

## Invariant Numbering

ADR-0082 adds exactly **one** invariant (D6), pre-assigned at **102** in `constitution/invariant-reservations.md` alongside ADR-0083's 103. The pre-assignment was committed by the refine pass to avoid the "first merge wins" race between the two adjacent initiatives. Packet 00's PR writes the invariant text into `constitution/invariants.md`; no upward-shift contingency is required because the reservation is fixed.

The invariant lands under a **new** `## Standup Procedure Invariants` section in `constitution/invariants.md` (the existing sections — Dependency, Context, Secrets, Packaging, Testing, Audit, Code Review, Infrastructure, Hive Sync, Multi-Tenant, Communications, AI — are not the right home for a standup-procedure rule).

## Cross-Cutting Concerns

### `sonarcloud-org-onboarding.md` is NOT in this initiative

ADR-0082 D7 names six walkthroughs unlocked by acceptance — five per-class plus `org-secret-repo-binding.md` — and notes a *seventh* (`sonarcloud-org-onboarding.md`) explicitly as the deliverable of the ADR-0011 acceptance pass. The existing `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (titled "SonarQube Cloud Organization Setup") covers this; this initiative does NOT re-author or relocate it.

### Procedural enforcement, not CI-enforced

ADR-0082 D6's invariant **102** is procedural — the catalogs (in `HoneyDrunk.Architecture`) and the new repo (in another GitHub repo) live in different repositories; a cross-repo CI gate would require a new mechanism this ADR explicitly does not commit to. Enforcement lives in:
1. Human / agent author adherence (using packet 01's procedure document as reference).
2. The `review` agent's per-PR check (ADR-0044 D3 category 10 — Enterprise readiness / supportability).
3. The `node-audit` agent's periodic pass (ADR-0043 Tactical source).
4. The `hive-sync` agent's reconciliation pass (Invariant 38).

A future "catalog-coherence" reusable workflow in `HoneyDrunk.Actions` that diffs the org's repo list against `catalogs/nodes.json` and `repo-to-node.yml` is an unblocked follow-up — not committed by ADR-0082, not in this initiative.

### Org-secret matrix is a living snapshot

The per-class org-secret binding matrix in `constitution/node-standup.md` (packet 01) and reproduced in `org-secret-repo-binding.md` (packet 07) carries a snapshot date (2026-05-25). Future ADR-0083 inventory passes update the matrix in `constitution/node-standup.md`; that change flows to packet 07's walkthrough at next revision. No ADR amendment required for matrix extensions — only D2 taxonomy and D6 invariant wording changes require ADR amendment per ADR-0082's Consequences.

### Existing standup ADRs are not retrofitted

ADR-0019 / ADR-0027 / ADR-0031 / ADR-0059 / ADR-0060 / ADR-0061 / ADR-0071 retain their `If Accepted — Required Follow-Up Work` checklists as immutable historical records. Future standup ADRs (ADR-0083, future per-Node ADRs as AI Seeds promote) reference this ADR and `constitution/node-standup.md` as the procedure source.

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; repo-level `CHANGELOG.md` is updated per repo convention by each packet that lands a constitutional / walkthrough change.

## Rollback Plan

- **Packet 00 (acceptance):** revert the PR. ADR returns to Proposed; the new invariant is removed; the new `## Standup Procedure Invariants` section is removed. The reservation row in `constitution/invariant-reservations.md` is removed. No runtime impact.
- **Packet 01 (procedure document):** revert the PR. `constitution/node-standup.md` is removed. Future standups continue re-deriving from precedent (the pre-ADR-0082 state). The walkthroughs from packets 02–07 lose their composition target — they would need to be reverted too, or to inline the rules.
- **Packets 02–07 (walkthroughs):** revert independently. Each walkthrough is a separate file; reverting one does not affect the others. The procedure document (packet 01) still stands.
- **Architectural escape hatch:** if the procedure document or walkthroughs reveal a structural problem post-merge, edits are governed by lightweight PR review against ADR-0082 (not by ADR ceremony) — only D2 taxonomy or D6 invariant wording changes require ADR amendment.

## Out-of-scope items from ADR-0082

- **`sonarcloud-org-onboarding.md`** — already covered by existing `sonarcloud-organization-setup.md`; ADR-0011 acceptance owns any refinements.
- **CI-enforced catalog-coherence gate** — unblocked follow-up; not committed by ADR-0082.
- **New-class amendments** (mobile per ADR-0070 D3, Tauri desktop, Bicep-only infrastructure repos, Honeyclaw/OpenClaw configuration repos) — when added, they amend D2 with a one-row addition plus a per-class walkthrough; not in this initiative.
- **Retrofitting prior standup ADRs.** Explicitly out of scope per ADR-0082's Consequences.

## Cross-Cutting — site sync

No site-sync flag. ADR-0082 is internal Grid governance — no Studios public-facing content changes.

## Filing

This initiative lands in `generated/work-items/proposed/adr-0082-node-standup/` (the ADR-0043 D4 landing zone). Per ADR-0043 the scope agent does not self-promote to `active/`. After human review of the proposed packets, the operator (or the file-issues agent following the human-review approval) moves the folder to `active/` at which point `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in the folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays.

No manual `gh issue create` from the scope agent. PR bodies for each packet must carry strict `Authorship: <enum>` + exactly one of `Work Item:` (pointing at the packet path) or `Out-of-band reason:` — free-form text breaks pr-core checks.
