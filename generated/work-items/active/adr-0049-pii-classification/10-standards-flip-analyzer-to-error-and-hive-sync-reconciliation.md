---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "adr-0049", "wave-5"]
dependencies: ["work-item:09"]
adrs: ["ADR-0049"]
wave: 5
initiative: adr-0049-pii-classification
node: honeydrunk-architecture
---

# Flip the classification analyzer to error severity + wire hive-sync reconciliation

## Summary
Two coordinated changes — Phase 1's 30-day warning window has closed and the catalog is populated, so:

1. **`HoneyDrunk.Standards`** PR — flip the unmarked-classification analyzer rule from `Warning` to `Error` severity. Unmarked fields on persisted records/audit payloads now fail the build at the tier-1 gate.
2. **`HoneyDrunk.Architecture`** PR — wire `hive-sync` to reconcile `catalogs/data-classification.json` against source-code `[Classification]`/`[PiiField]` attributes nightly, treating drift as a finding.

Sibling PRs in two repos. Both close ADR-0049 D10 Phase 4 ("Flip the Phase 1 analyzer warnings to errors at the 30-day mark"). The hive-sync wiring is the ongoing-drift-detection mechanism; the analyzer flip is the at-commit enforcement.

> **30-day window note.** ADR-0049 D10 commits the 30-day warning window starting from when the analyzer ships (packet 03). The agent executing this packet checks at branch time whether 30 days have elapsed since packet 03's merge. If less than 30 days, **the agent flags this and waits** — flipping early surprises every Node author whose backfill PR hasn't merged yet. If more than 30 days have elapsed and packets 07/08/09 have all merged, the flip lands.

## Context
ADR-0049 D10 commits a six-phase rollout. Phase 1 ships attributes + analyzer at `Warning` severity. Phase 2 backfills Live Nodes (packets 07/08). Phase 3 ships redactors and the canary (packets 04/05/06). Phase 4 lands the catalog and the analyzer flip plus the `hive-sync` reconciliation. This packet closes Phase 4's two remaining actions:

- **Analyzer flip.** The analyzer at `Warning` was a deliberate grace period — unmarked fields surfaced as build warnings during the backfill so the executors of packets 07/08 had a checklist. Once the backfill is complete (packet 09 confirms this by populating the catalog from a known-marked surface), the analyzer flips to `Error` and any unmarked field on a persisted record / audit payload fails the build. From this packet forward, "developer added a field and forgot to classify it" is a CI gate failure, not a warning.
- **`hive-sync` reconciliation.** Ongoing drift detection — a future PR that lands a new persisted-record type without marking it correctly is caught at commit time by the analyzer; but classification drift between the source code and the catalog (e.g. an existing field's classification tier changed, or a new contract was added but the catalog was not refreshed) is caught by `hive-sync`'s nightly walk. The walk reflects over each Node's marker state and compares against the catalog entry; mismatches are emitted as findings to the operator-facing channel per ADR-0014.

## Scope
Two separate PRs, sequenced as written:

1. **`HoneyDrunk.Standards`** PR — analyzer severity flip from `Warning` to `Error`.
2. **`HoneyDrunk.Architecture`** PR — `hive-sync` reconciliation rule for `catalogs/data-classification.json`.

Order: Standards first (the analyzer flip needs to land before the next post-merge cycle when `hive-sync` runs). Then Architecture (the hive-sync rule). The Architecture PR can run on the assumption that the analyzer is at error severity.

### Standards PR
- Edit the analyzer's `DiagnosticDescriptor` constructor — change `DiagnosticSeverity.Warning` to `DiagnosticSeverity.Error`.
- Update `HoneyDrunk.Standards.Analyzers/CHANGELOG.md` with a per-package entry: "Unmarked-classification analyzer rule severity flipped from Warning to Error per ADR-0049 D10 Phase 4 — unmarked fields on persisted records/audit payloads now fail the build at the tier-1 gate."
- Update `HoneyDrunk.Standards.Analyzers/README.md` — change the "warning at v1" framing to "error after the 30-day Phase 1 window closed."
- Repo-level `CHANGELOG.md` — new `[X.Y.0]` entry (this is a behavior change shipped through a minor version bump; invariant 27 applies).
- Solution-version bump on every non-test `.csproj`.

### Architecture PR
- Update the `hive-sync` agent definition at `.claude/agents/hive-sync.md` (or whatever the canonical agent file is — read the repo at branch time) to include the new reconciliation rule.
- The rule's behavior: walk `catalogs/data-classification.json`; for each `nodes.{NodeName}` entry, fetch the post-merge marker state from that Node's source code (the OpenClaw-cron'd execution surface per ADR-0044 has Node-source access during scheduled runs); compute the current `highest_classification`, `pii_categories`, `sensitive_pii`, `contracts[]`, `stores[]`; diff against the catalog; emit a finding per drift.
- A finding's emit channel matches existing hive-sync findings (per ADR-0014 D3 + invariant 38) — likely a board item on The Hive with the `drift` label. Confirm the existing channel at branch time and reuse it.
- Document the rule in `routing/repo-discovery-rules.md` if it adds any new keyword; otherwise no routing change.

## Proposed Implementation

### Standards PR procedure

1. Open the analyzer file added by packet 03 in `HoneyDrunk.Standards.Analyzers`.
2. Change the diagnostic severity from `Warning` to `Error`. Confirm the rule still fires on the test cases added by packet 03 — they should now report `Error` instead of `Warning`. The test assertions may need updating; align the severity expectation in the analyzer-tests project.
3. Update the test fixture project (if one exists) that uses `[Classification(DataClass.Public)]` to confirm the opt-out — the opt-out still produces NO diagnostic at any severity.
4. Bump every non-test `.csproj` in the Standards solution to the same new minor version (invariant 27).
5. Update `HoneyDrunk.Standards.Analyzers/CHANGELOG.md` and `README.md` accordingly. Repo-level `CHANGELOG.md` new entry.
6. Tag for human release after merge.

### Architecture PR procedure

1. Open `.claude/agents/hive-sync.md` (or the canonical hive-sync agent definition).
2. Add a new section to its reconciliation rules: "Data-classification catalog reconciliation. On each nightly run, walk `catalogs/data-classification.json` and verify the per-Node markers in source still match the catalog's `highest_classification`, `pii_categories`, `sensitive_pii`, `contracts[]`, `stores[]`. Emit drift findings via the standard board-item path per ADR-0014 D3 / invariant 38."
3. Document the exact source-walk procedure with enough detail for the OpenClaw-execution-cron to run it: which Node repos, which files to scan (records under persistence/contract/Audit-payload paths), what reflection semantics to apply.
4. If the existing hive-sync `boundaries.md` or similar config file needs an entry for this rule, add it; if not, this is purely an agent-definition addition.
5. No version-bump on the Architecture repo (governance-only changes).
6. CHANGELOG entry — Architecture uses an initiative-tracking model (per `initiatives/active-initiatives.md`), not a repo-level CHANGELOG. Note the change in `initiatives/active-initiatives.md` under this initiative's tracking entry.

## Affected Files

### Standards PR
- `HoneyDrunk.Standards.Analyzers/` — analyzer rule severity edit.
- `HoneyDrunk.Standards.Tests/` — test severity assertions updated.
- `HoneyDrunk.Standards.Analyzers/CHANGELOG.md`, `README.md`.
- Repo-level `CHANGELOG.md`.
- Every non-test `.csproj` in the Standards solution.

### Architecture PR
- `.claude/agents/hive-sync.md` — new reconciliation rule section.
- Possibly hive-sync config file edits.
- `initiatives/active-initiatives.md` — initiative tracking update.

## NuGet Dependencies
- Standards PR: no new package references.
- Architecture PR: no .NET project edits.

## Boundary Check
- [x] Standards PR is contained to `HoneyDrunk.Standards` — analyzer rule severity change is a Standards-internal concern.
- [x] Architecture PR is contained to `HoneyDrunk.Architecture` — agent-definition change is Architecture-internal.
- [x] No new cross-Node runtime dependency.
- [x] Per invariant 33 (review-agent/scope-agent context-loading coupling): this packet edits `.claude/agents/hive-sync.md`, not `review.md` or `scope.md`, so no symmetry-coupling concern arises. If the executor finds themselves adding a new file to `hive-sync.md`'s required-reading list and that file is *also* loaded by `review.md`/`scope.md`, surface — but this is unlikely.

## Acceptance Criteria

### Standards PR
- [ ] The unmarked-classification analyzer rule severity is `Error` (was `Warning` from packet 03)
- [ ] The analyzer's test cases still pass with the severity-expectation updated
- [ ] `[Classification(DataClass.Public)]` remains a valid opt-out (no diagnostic at any severity)
- [ ] Every non-test `.csproj` in the Standards solution is at the new same minor version (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[X.Y.0]` entry; per-package CHANGELOG entry only on `HoneyDrunk.Standards.Analyzers` (real change)
- [ ] `HoneyDrunk.Standards.Analyzers/README.md` documents the severity-change history

### Architecture PR
- [ ] `.claude/agents/hive-sync.md` has a new section documenting data-classification catalog reconciliation
- [ ] The section names the source-walk procedure with enough detail for the OpenClaw-execution-cron to run it
- [ ] The drift-finding emit channel matches existing hive-sync findings per ADR-0014 D3 + invariant 38
- [ ] `initiatives/active-initiatives.md` tracking entry is updated
- [ ] Invariant 33 symmetry check: if any file added to `hive-sync.md`'s required-reading list is *also* loaded by `review.md`/`scope.md`, the symmetry edit lands together; if not (the typical case), no coupling concern

## Human Prerequisites
- [ ] **Confirm 30 days have elapsed since packet 03's merge.** If fewer, the analyzer flip lands too early and surprises in-flight backfill PRs. The executor confirms by reading packet 03's merge date; if under 30 days, this packet WAITS.
- [ ] **Confirm packets 07, 08, 09 are all merged.** The analyzer flip presumes backfill is complete; the hive-sync rule presumes the catalog is populated.
- [ ] **Push the Standards release tag after the Standards PR merges.** The new analyzer severity reaches consuming projects only after the package is on the feed.

## Referenced ADR Decisions
**ADR-0049 D10 Phase 4 — Catalog + hive-sync + analyzer flip.** "Wire `hive-sync` reconciliation rule for the catalog. Flip the Phase 1 analyzer warnings to errors at the 30-day mark."

**ADR-0049 D10 Phase 1 — Analyzer at warning for 30 days.** "Existing fields are `[Classification(DataClass.Internal)]` by default (compatibility); the analyzer surfaces unclassified surface as warnings, not errors, for the first 30 days." The 30-day clock starts from packet 03's merge.

**ADR-0014 — Hive-sync reconciliation pattern.** Drift findings emit to the board-item channel per ADR-0014 D3 + invariant 38.

**Invariant 58 (from packet 00).** "Every persisted field, every public API contract field, and every `AuditEntry` payload field carries a `[Classification]` attribute. Unmarked fields on records inside Restricted-class contexts are a CI gate failure under the `HoneyDrunk.Standards` analyzer rule." This packet operationalizes "CI gate failure."

## Constraints
- **30-day window enforcement.** Do not flip the analyzer before 30 days have elapsed since packet 03's merge. The window is a deliberate adoption ramp.
- **Two separate PRs.** Standards and Architecture changes are independent — file separately, review separately. The cross-Node sequencing (Standards merged + released before Architecture's hive-sync rule starts running in production cron) keeps the analyzer's behavior consistent with the reconciliation rule's expectations.
- **`[Classification(DataClass.Public)]` remains a valid opt-out** at error severity too. Do not remove the opt-out behavior.
- **No version-bump on Architecture.** Architecture is not a versioned .NET solution; governance/agent edits don't bump.
- **Invariant 33 coupling check.** When editing `.claude/agents/hive-sync.md`, check whether any file added to its required-reading list is *also* in `review.md`'s or `scope.md`'s required-reading list; if so, mirror the edits.

## Labels
`feature`, `tier-2`, `meta`, `adr-0049`, `wave-5`

## Agent Handoff

**Objective:** Two sibling PRs that close ADR-0049 D10 Phase 4: flip the Standards analyzer to error severity; wire hive-sync to reconcile the data-classification catalog against source markers nightly.

**Target:** This coordinator packet lives in `HoneyDrunk.Architecture`. The executor opens two separate PRs: one on `HoneyDrunk.Standards`, one on `HoneyDrunk.Architecture`.

**Context:**
- Goal: Close the Phase 1 30-day adoption ramp; start ongoing drift detection.
- Feature: ADR-0049 Data Classification rollout, Wave 5 (Phase 4 close).
- ADRs: ADR-0049 D10 Phase 4 (primary), ADR-0014 (hive-sync reconciliation pattern).

**Acceptance Criteria:** As listed above, split between the two PRs.

**Dependencies:**
- `work-item:09` — catalog populated.
- (Implicit via 09's deps: packets 03, 07, 08 all merged.)

**Constraints:**
- 30-day window since packet 03's merge.
- Two separate PRs, Standards first then Architecture.
- `[Classification(DataClass.Public)]` remains a valid opt-out.
- Invariant 33 symmetry check on the hive-sync edit.

**Key Files:**
- Standards PR: analyzer rule severity edit; tests; CHANGELOGs.
- Architecture PR: `.claude/agents/hive-sync.md`; `initiatives/active-initiatives.md`.

**Contracts:** No code contracts changed. Analyzer rule severity is a build-time enforcement change.
