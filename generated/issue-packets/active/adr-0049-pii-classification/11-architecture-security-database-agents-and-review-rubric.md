---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "adr-0049", "wave-5"]
dependencies: ["packet:00"]
adrs: ["ADR-0049", "ADR-0046"]
wave: 5
initiative: adr-0049-pii-classification
node: honeydrunk-architecture
---

# Update security agent rubric, review agent D3 category 9 checklist, and promote the database specialist to v1 roster

## Summary
Three coordinated updates to the `.claude/agents/` execution surface, all in one Architecture PR:

1. **`.claude/agents/security.md`** — add the canonical ADR-0049 D1–D6 rubric so the `security` specialist has a concrete reference to cite when reviewing PRs that touch `[PiiField]` declarations, classification downgrades, or new Restricted-class boundaries.
2. **`.claude/agents/review.md`** — amend the D3 category 9 (Security) checklist to include the classification-completeness check (per ADR-0044 D3 + ADR-0049 D8).
3. **`.claude/agents/database.md`** — promote the `database` specialist agent from ADR-0046 D9 candidate to v1 roster, authored from scratch with ADR-0049 D8 as its scope (schema migrations on PII-bearing stores; index design on PII-bearing tables; retention-policy configuration changes).

Single PR because all three changes are agent-definition edits in the same `.claude/agents/` directory.

## Context
ADR-0049 D8 commits the owners-and-reviewers rubric:

- The generalist `review` agent (per ADR-0044 D3 category 9) flags missing/wrong classifications as part of every PR review — low-precision first pass.
- The `security` specialist (per ADR-0046 D2) is invoked for new `[PiiField(SensitivePii)]` declarations, classification downgrades (Restricted→Confidential is a red flag), new Restricted-boundary work, and new Nodes storing user-attributable data.
- The `database` specialist (named as a follow-up candidate in ADR-0046 D9; **promoted to v1 roster by this ADR**) is invoked for schema migrations on PII-bearing stores, index design on PII-bearing tables (an index on `email` makes erasure easier; a composite index that locks in field placement makes it harder), and retention-policy configuration changes on Cosmos containers, App Insights workspaces, or storage accounts.

ADR-0049 follow-up work explicitly names: "Update `.claude/agents/security.md` with the canonical D1–D6 rubric. Update `.claude/agents/review.md` D3 category 9 with the classification-completeness checklist. Promote the `database` specialist agent from ADR-0046 D9 candidate to v1 roster; author `.claude/agents/database.md`."

The three agent files live alongside the existing roster:

- **`.claude/agents/security.md`** — exists per ADR-0046 D2 (one of the initial five specialists). This packet *amends* it to add the rubric section.
- **`.claude/agents/review.md`** — exists per ADR-0044. This packet *amends* it (a small addition to D3 category 9). Per invariant 33 (review-agent/scope-agent context-loading coupling), if this packet adds a new file to `review.md`'s required-reading list, it must also add it to `scope.md`'s required-reading list. The classification rubric addition is a *rule-list* edit, not a context-loading edit, so symmetry is preserved by construction — unless the executor finds they need `security.md` (or similar) loaded as context by `review.md`, in which case `scope.md` gets the same edit. Surface this if it arises.
- **`.claude/agents/database.md`** — does **not** exist. This packet creates it. Pattern after the existing specialist agents (`security.md`, `cfo.md`, `performance.md`, `ai-safety.md`, `a11y.md` per ADR-0046).

> **About the architecture agents hardlink.** Per the user's memory note "Architecture agents hardlinked globally," the 10 Architecture agents are hardlinked into `~/.claude/agents/`. Adding a new agent file in this packet requires a re-sync step after merge — see Human Prerequisites.

## Scope
Single PR in `HoneyDrunk.Architecture`:

- `.claude/agents/security.md` — new "ADR-0049 D1–D6 rubric" section with the four-tier taxonomy, PII sub-taxonomy, retention schedule pointers, attribute usage, redaction expectations, and erasure-policy summary inline.
- `.claude/agents/review.md` — amend the D3 category 9 (Security) checklist with new bullet items for classification completeness, `[PiiField]`-marker correctness, and Restricted-boundary regression detection.
- `.claude/agents/database.md` — new agent file authored against ADR-0049 D8's scope and ADR-0046's agent-definition pattern.

## Proposed Implementation

### 1. `security.md` — add D1–D6 rubric

Read the existing `.claude/agents/security.md` (per ADR-0046 D2 acceptance packet 04 — that packet authored the file). Add a new section after the existing "Scope" / "Invocation" / "Tools" sections; pattern-match the existing section convention. The new section's content:

> ## ADR-0049 Data Classification Rubric
>
> When reviewing PRs that touch classified data, apply the rubric below.
>
> **D1 — Four-tier taxonomy.** Every datum is Public, Internal, Confidential, or Restricted. Classification is field-level, not record-level. Default-to-Restricted on ambiguity.
> - Public: world-readable.
> - Internal: studio-operator only.
> - Confidential: tenant-attributable; tenant isolation enforced.
> - Restricted: PII, secrets, payment, message bodies, journal text, location, photos. Encrypted at rest; access logged; forbidden in observability.
>
> **D2 — PII sub-taxonomy.** Restricted-tier personal data is one of:
> - PII (Article 4 personal data): name, email, IP, behavioral telemetry.
> - SensitivePii (Article 9 special category): government ID, financial, biometric, precise geolocation, health, religion, political opinion, racial origin, trade-union, children's data.
> - Pseudonymous: opaque Grid-scoped identifier with separately-held mapping.
>
> **D3 — Retention.** Field-level — defer to the ADR-0049 D3 retention schedule table. Highlight reviewable rows: audit 730 days (T0 7yr), telemetry 90/93 days, error 90d, PII deleted within 30 days of erasure, backups exempt from immediate erasure per Article 17(3).
>
> **D4 — Marking.** `[Classification(...)]` mandatory on every persisted/contract/audit-payload field. `[PiiField(...)]` additional on PII-bearing fields with `Purpose` string. Analyzer rule from `HoneyDrunk.Standards` catches unmarked at compile time (error severity per packet 10).
>
> **D5 — Boundary redaction.** Pulse log/trace/error and Audit append paths redact `[PiiField]` markers via reflection. Defense-in-depth: emitter pre-redacts AND boundary defends. Evals `evals.sensitive=true` carve-out preserved. StackTrace never redacted.
>
> **D6 — Right to erasure.** Pseudonymous token in audit + erasable PII↔token map in per-Node identity store. SensitivePii NEVER in audit even as tokens — rejected at append per invariant 83.
>
> **What I flag specifically:**
> - New `[PiiField(SensitivePii)]` declaration on any field — confirm Article 9 lawful basis (explicit consent or 9(2)(a-j)).
> - Classification downgrade (Restricted→Confidential, Confidential→Internal, etc.) — red flag; require explicit justification in PR body.
> - New HTTP endpoint or message envelope shape handling Restricted-class data without redaction at the boundary.
> - New persisted store for user-attributable data without retention configuration matching ADR-0049 D3.
> - Stack-trace-included exception logging where the exception's `Data` dictionary or message likely carries Pii (regex fallback only is insufficient if a field-level marker is available).
> - Missing `[Classification]` on any new property in a record under `HoneyDrunk.Data`/`HoneyDrunk.Audit`-referencing project (the analyzer fires too, but I double-check the *correctness* of the marker, not just its presence).
> - Cross-region data movement violating invariant 84 (Restricted data leaves US East 2).

### 2. `review.md` — amend D3 category 9 checklist

Read `.claude/agents/review.md`. The D3 rubric per ADR-0044 has 20 categories; category 9 is Security. Find the existing category 9 checklist and add new bullet items at the bottom:

> - **Classification completeness (ADR-0049 D4):** Every new public/internal property on a persisted-record, API-contract, or `AuditEntry`-payload type carries `[Classification(...)]`. The `HoneyDrunk.Standards` analyzer rule (error severity) catches absent markers; the reviewer confirms the marker's *tier* is correct (no debug-only fields marked Internal that should be Restricted).
> - **PII marker correctness (ADR-0049 D2/D4):** When a property carries personal data, `[PiiField(...)]` is also applied with the correct `PiiCategory` and a `Purpose` string. Defaulting to `Pseudonymous` for opaque IDs; `SensitivePii` for Article 9 categories; `Pii` for everything else identifying a natural person.
> - **Restricted-boundary regression (ADR-0049 D5):** A new HTTP endpoint, message envelope, audit event family, or persisted store handling Restricted-class data must reach the Pulse/Audit boundary redactors via the `[PiiField]` marker discipline; defense-in-depth requires both emitter pre-redaction and boundary defense.
> - **SensitivePii in audit (invariant 83):** Any code path that could land a `SensitivePii`-marked value in an `AuditEntry` `Before`/`After` or `Metadata` payload is a hard rejection — the Audit Node refuses the append at runtime; the reviewer confirms the code doesn't even *attempt* such an append.
> - **Cross-region movement (invariant 84):** Confirm new infra/replication config does not move Restricted-class data out of Azure US East 2.

Per invariant 33: this edit is to the rule list, not the context-loading section. Symmetry with `scope.md` is preserved by construction.

### 3. `database.md` — create the new specialist agent

Pattern after the existing `.claude/agents/security.md` (per ADR-0046 D2 packet 04) and `.claude/agents/performance.md` (per ADR-0046's performance-specialist packet, if it has landed). The file structure:

> ---
> name: database
> description: Specialist review agent for schema migrations, index design, and retention configuration on stores containing classified data. Per ADR-0046 D9 + ADR-0049 D8.
> ---
>
> ## Role
> The `database` specialist reviews PRs that change schema, indexes, or retention configuration on stores containing classified data. Promoted from ADR-0046 D9 candidate to v1 roster by ADR-0049 D8.
>
> ## Scope
> Invoked manually (per ADR-0046 D1 v1 manual-invocation posture) for:
> - Schema migrations on `HoneyDrunk.Data`-backed stores (relational, document, key-value).
> - Index design on PII-bearing tables — an index on `email` makes erasure easier; a composite index that locks in field placement makes it harder.
> - Retention-policy configuration changes on Cosmos containers, App Insights workspaces, storage accounts, Service Bus queues/topics.
> - New persisted store for user-attributable data — confirm retention matches ADR-0049 D3.
>
> ## Rubric
> When invoked, apply:
>
> 1. **Migration safety.** Forward-only by default; expand → migrate code → contract for relational stores per ADR-0048. Cosmos and document stores follow schema-on-read with backfill-by-runbook. `[Rollback]` declaration is mandatory; Tier 2b round-trip test required.
>
> 2. **Index design vs erasure.** A primary-key or unique-index on a `[PiiField(Pii)]`-marked column makes per-record erasure trivial. A composite index spanning multiple fields locks in field placement and makes erasure expensive. Prefer the former; flag the latter.
>
> 3. **Retention configuration.** Compare the new store's configured retention against the ADR-0049 D3 table. Telemetry stores 90/93 days. Error events 90 days. Audit records 730 days minimum (7 years for T0). Tenant data indefinite while tenant active + 90 days grace. Restricted PII deleted within 30 days of erasure request. Backups exempt from immediate erasure per Article 17(3).
>
> 4. **AuditEntry table specifics.** The `AuditEntry` table follows the append-only-by-interface property — no `Update` migration shape, no `Delete` migration shape on `AuditEntry` itself. Schema additions (new columns) are fine; schema *changes* (column type changes, column drops) require explicit ADR amendment.
>
> 5. **Backup region.** Confirm new backup/replication settings stay within Azure US East 2 per invariant 84.
>
> ## Tools and context
> The `database` agent loads:
> - `constitution/invariants.md` — for invariants 47, 82, 83, 84 (data-classification), invariant 60 (DR tiers from ADR-0036), and any new database/migration invariants.
> - `adrs/ADR-0049-data-classification-pii-handling-and-retention-schedule.md` — for the retention schedule (D3) and policy principles (D6).
> - `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md` (when Accepted) — for the migration framework.
> - `adrs/ADR-0036-disaster-recovery-and-backup-policy.md` — for DR tier semantics.
> - The PR diff (the target of the review).
>
> ## Invocation
> Manual per ADR-0046 D1 at v1. Operator decides when a lens applies. Future CI-trigger automation deferred per ADR-0046 D11.
>
> ## Output format
> Concise advisory comment on the PR. Findings categorized: `migration-risk`, `index-vs-erasure`, `retention-mismatch`, `audit-append-only-violation`, `region-leak`. No automatic Request Changes; the operator decides.

This is the file's initial content. Match the front-matter, section-header, and tone conventions of the existing `.claude/agents/` roster. Read at least two existing specialist files at branch time to align format.

### Architecture-side housekeeping
- Update `initiatives/active-initiatives.md` tracking entry to mark this packet's progress.
- No version-bump (Architecture is not a versioned .NET solution).
- No catalog edit needed — the agent roster is not catalog-tracked at v1.

## Affected Files
- `.claude/agents/security.md` — new "ADR-0049 D1–D6 rubric" section appended.
- `.claude/agents/review.md` — D3 category 9 (Security) checklist amended.
- `.claude/agents/database.md` — new agent file authored.
- `initiatives/active-initiatives.md` — initiative tracking update.

## NuGet Dependencies
None. Agent-definition files are Markdown.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` `.claude/agents/`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] Invariant 33 (review-agent/scope-agent context-loading coupling) — the `review.md` edit is a rule-list amendment, not a context-loading addition. Symmetry preserved. Surface if the executor finds otherwise.
- [x] New `database.md` agent's context-loading list does not overlap with `review.md`'s or `scope.md`'s required-reading list — the agent is a new specialist, not a context superset.

## Acceptance Criteria
- [ ] `.claude/agents/security.md` has a new section documenting the ADR-0049 D1–D6 rubric with the inline taxonomy, marker discipline, redaction expectations, erasure policy, and the named "what I flag specifically" checklist
- [ ] `.claude/agents/review.md` D3 category 9 (Security) checklist has new bullet items covering classification completeness, PII marker correctness, Restricted-boundary regression, SensitivePii-in-audit rejection, and cross-region movement
- [ ] `.claude/agents/database.md` exists with the full content described in Proposed Implementation step 3 — front-matter, role, scope, rubric, tools/context, invocation, output format
- [ ] All three files follow the existing `.claude/agents/` formatting conventions (read at least two existing specialist files to align)
- [ ] `initiatives/active-initiatives.md` tracking entry is updated
- [ ] Invariant 33 symmetry check passes — no file added to `review.md`'s context-loading list without a matching edit to `scope.md`

## Human Prerequisites
- [ ] **Re-sync the Architecture agent hardlinks after merge.** Per the user's memory note "Architecture agents hardlinked globally" — the 10 Architecture agents are hardlinked into `~/.claude/agents/`. The new `database.md` and the edits to `security.md`/`review.md` need to propagate. Run the documented re-sync command in the hardlink documentation (the memory note says the command is in the file itself); requires a Claude Code restart afterwards to register.
- [ ] **No automatic invocation triggered.** Per ADR-0046 D1's v1 posture, the `database` specialist is manual-only. The operator decides when to invoke it on a given PR.

## Referenced ADR Decisions
**ADR-0049 D8 — Owners and reviewers.** "The specialist `security` agent (per ADR-0046 D2) is invoked for any PR touching: a new `[PiiField]` declaration of category `SensitivePii`; a change to a field's classification (downgrade Restricted → Confidential is a red flag; promotion is fine); a new boundary that handles Restricted-class data ... The specialist `database` agent (named as a follow-up candidate per ADR-0046 D9; promoted to v1 roster by this ADR's follow-up work) is invoked for any PR touching: Schema migrations on `HoneyDrunk.Data`-backed stores; Index design on PII-bearing tables; Retention-policy configuration changes."

**ADR-0049 Follow-up Work.** "Update `constitution/invariants.md` with the Invariant 47 amendment and three new invariants. Update `.claude/agents/security.md` with the canonical D1–D6 rubric. Update `.claude/agents/review.md` D3 category 9 with the classification-completeness checklist. Promote the `database` specialist agent from ADR-0046 D9 candidate to v1 roster; author `.claude/agents/database.md`."

**ADR-0046 D2 — Specialist roster.** The `security` specialist is part of the initial v1 roster of five. The `database` specialist was a D9 candidate; this packet promotes it.

**ADR-0046 D1 — Manual invocation at v1.** No CI triggers, no automatic firing; the operator decides when a lens applies.

**ADR-0044 D3 — Twenty-category review rubric.** Category 9 is Security; this packet amends category 9's checklist.

**Invariant 33 — Review-agent and scope-agent context-loading coupling.** The `review.md` edit is rule-list-only; no context-loading change; symmetry preserved by construction. If the executor finds otherwise, surface.

## Constraints
- **Single PR for all three agent-file edits.** Same directory, same review pass, same merge. Splitting them creates avoidable in-flight inconsistency.
- **Inline the rubric text in `security.md`.** Do not just cite ADR-0049 D1–D6 — the security agent has no access to the ADRs at execution time; the rubric must be self-contained in the agent file.
- **Match existing agent-file conventions.** Read at least two existing specialist agent files (`security.md` if it exists post-ADR-0046, plus one other like `cfo.md`) before authoring `database.md`. Don't invent a new front-matter or section format.
- **No CI-trigger wiring for the `database` specialist.** v1 is manual invocation per ADR-0046 D1; CI triggers are deferred future work.
- **Invariant 33 check.** If editing `review.md` adds a new file to its required-reading list, the same file must be added to `scope.md`'s required-reading list in the same PR (and any other adjacent edits per the coupling rule).
- **Architecture hardlink re-sync** is a post-merge human step, not a packet acceptance criterion — but the executor must flag it in the PR body so the operator doesn't forget.

## Labels
`feature`, `tier-2`, `meta`, `adr-0049`, `wave-5`

## Agent Handoff

**Objective:** Land three coordinated agent-file edits in `.claude/agents/`: rubric on `security.md`, checklist amendment on `review.md`, new `database.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`. Single PR.

**Context:**
- Goal: Operationalize ADR-0049 D8's reviewer rubric and promote the `database` specialist.
- Feature: ADR-0049 Data Classification rollout, Wave 5 (governance close).
- ADRs: ADR-0049 D8 + Follow-up Work (primary), ADR-0046 D1/D2/D9 (specialist roster + manual-invocation posture), ADR-0044 D3 (review rubric).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0049 Accepted before the security agent gains a rubric citing it.

**Constraints:**
- Single PR for all three edits.
- Inline the rubric text in `security.md` — the agent has no ADR file access at execution time.
- Match existing agent-file conventions.
- No CI-trigger wiring (manual invocation per ADR-0046 D1).
- Invariant 33 symmetry check on `review.md`.
- Hardlink re-sync is a post-merge human action; flag in PR body.

**Key Files:**
- `.claude/agents/security.md` — rubric section appended.
- `.claude/agents/review.md` — D3 category 9 checklist amended.
- `.claude/agents/database.md` — new agent file.
- `initiatives/active-initiatives.md` — initiative tracking update.

**Contracts:** Agent-definition contracts (not code contracts). New specialist `database` agent enters the v1 roster.
