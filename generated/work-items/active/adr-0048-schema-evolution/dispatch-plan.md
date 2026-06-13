# Dispatch Plan — ADR-0048: Data Schema Evolution and Migration Policy

**Initiative:** `adr-0048-schema-evolution`
**ADR:** ADR-0048 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0048 commits the Grid's response to a missing schema-evolution policy: **EF Core Migrations** as the Grid-wide framework for relational stores (D1), the **expand → migrate code → contract** pattern as the zero-downtime mechanic (D2), the **out-of-band `migrate.yml` workflow** as the timing model — operator-triggered, separate from app deploy, compatible with ADR-0015 D6's multi-revision window (D3/D4/D11), per-store backward-compatibility windows (D5), online DDL primitives on tables ≥ 100k rows (D6), schema-on-read for document stores (D7), append-only-by-interface migration constraints for the Audit `AuditEntry` table (D8), tenant-scoped-vs-Grid-wide migration ordering (D9), forward-only rollback (D10), file/naming conventions plus the `migrate.yml` reusable workflow (D11), round-trip tests + `[Rollback]` attribute as test requirements (D12), a specialist `database` review agent per ADR-0046 (D13), and a 6-phase rollout (D14).

This initiative delivers: ADR acceptance + the three schema-evolution invariants + catalog registration (Architecture); the `database` specialist agent (Architecture); the `review.md` D3-category-13 delegation to `database` (Architecture); the `scope.md` packet pre-flight schema-change detector + the invariant-33 review/scope context-loading mirror (Architecture); the new `migrate.yml` reusable workflow (Actions); the canonical `Migrations/README.md` per-Node template (Architecture); the retroactive annotation of Notify's existing scaffold migrations (Notify); and the schema-on-read documentation for the Kernel idempotency Cosmos dedup store (Kernel, Phase 2 pilot).

**9 packets across 4 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`, `HoneyDrunk.Notify`, `HoneyDrunk.Kernel`). All 9 are `Actor=Agent`, 0 `Actor=Human`. Three packets carry Human Prerequisites (the workflow packet 05 needs portal RBAC + Key Vault secret seeding before its first consumer invocation; packet 00 needs invariant-number confirmation; packet 08 names an optional path-placement decision) — but the *code/docs* work is fully delegable in every case, so all stay `Actor=Agent`.

## Trigger

ADR-0048 is Proposed with no scope. The forcing functions from the ADR's Context:

- **Audit standup (ADR-0031)** is the first Tier 0 Node that will live for years and accumulate migrations. An append-only-by-interface store with no migration policy is the highest-cost place to invent one ad-hoc — D14 Phase 3 sequences Audit adoption *after* this initiative's foundation lands.
- **Memory and Knowledge standups (ADR-0021/0022)** introduce embedding stores and document indexes whose schemas will evolve as the AI sector matures. Each Node inventing its own pattern produces three incompatible migration stories before the AI sector has even shipped — D14 Phase 4 sequences their adoption.
- **Billing standup (ADR-0037)** will hold Stripe-reconciled tenant ledger data; wrong-schema or lost-data outcomes are commercially disqualifying — D14 Phase 5.
- **Notify Cloud GA (PDR-0002 / ADR-0027)** is the first commercial product; per-tenant data will accumulate; the deploy cadence will pick up; ADR-0015 D6's "two revisions alive at once" property will be exercised every release — D14 Phase 6.
- **ADR-0042's `IIdempotencyStore` contract test** (formalized as a Tier 2a contract test per ADR-0047 D4) exercises a real backing — meaning the migration that creates the dedup table is itself test-exercised in CI. ADR-0048 D14 Phase 2 pilots on this Node (the document-store side of the policy).
- **ADR-0047 D4 commits Testcontainers** for Tier 2b integration tests against real Postgres. Migration round-trip testing now has a natural home; the testing surface exists, the policy on what to test there does not — ADR-0048 D12 fills that gap.
- **ADR-0044 D3 category 13 (Data and persistence integrity)** binds the `review` agent to a per-PR checklist on data changes. That checklist is meaningless without a committed migration policy to check against — ADR-0048 D13 commits the specialist agent and the rubric the checklist defers to.

The ADR needs decomposition into actionable packets.

## Scope Detection

**Multi-repo, multi-Node.** The policy lands in `HoneyDrunk.Architecture` (governance, catalogs, the `database` agent, the per-Node template, the review/scope agent wiring), the workflow lands in `HoneyDrunk.Actions` (`migrate.yml` reusable workflow), the retroactive annotation lands in `HoneyDrunk.Notify` (existing scaffold migrations), and the schema-on-read pilot lands in `HoneyDrunk.Kernel` (Cosmos idempotency dedup store).

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node. The Audit / Memory / Knowledge / Billing adoptions named in ADR-0048 D14 Phases 3–6 are deliberately **out of scope** for this initiative — each follows in its own standup ADR's track (ADR-0031 for Audit, ADR-0021/0022 for Memory/Knowledge, ADR-0037 for Billing).

**No new contracts.** ADR-0048 introduces no Grid-wide runtime contracts. The `[Rollback]` attribute is an *informational declarative attribute* per D12; packet 07's pragmatic compromise ships it inside `HoneyDrunk.Notify.Data` for v1 with a documented follow-up to consolidate it into `HoneyDrunk.Data.Abstractions` (or wherever the Grid decides) when more Nodes adopt migrations. No `relationships.json` edge changes; no `contracts.json` interface additions.

## Cross-Dependency with sibling ADRs

ADR-0048 references several sibling ADRs as live context:

- **ADR-0015 (Container Hosting Platform, Accepted) D6** — multi-revision traffic-split window. The expand/contract pattern (D2) and the out-of-band `migrate.yml` workflow (D3) are designed precisely to be safe in this window. **No hard packet dependency** — ADR-0015 is already Accepted and the dependency is conceptual.
- **ADR-0033 (Environment-Gated Deploy Trigger Model, Proposed) D1/D7** — `dev` is unprotected; `staging`/`prod` are protected via GitHub Environment rules. `migrate.yml` inherits this posture (packet 05). **Soft dependency** — ADR-0033's acceptance is not a hard block on this initiative, but the Environment-protection-rules behavior is recorded in packet 05's frontmatter and Human Prerequisites.
- **ADR-0030 (Grid-Wide Audit Substrate, Accepted) D4** — append-only-by-interface. ADR-0048 D8's migration-time invariants enforce this at the migration-PR review surface. The `database` agent (packet 02) checks D8.
- **ADR-0042 (Idempotency Contract for Async Boundaries, Proposed/Accepted at scope time)** — names the Cosmos-backed `IIdempotencyStore` whose schema-on-read pilot lands here (packet 08). ADR-0042's acceptance status at scope time is *Proposed*; an in-flight initiative `adr-0042-idempotency` is shipping its acceptance and code packets. **Soft dependency** — packet 08 documents the dedup-state shape from ADR-0042 D1/D2/D3/D4/D6; if ADR-0042 is Accepted before this initiative's Wave 4 executes, packet 08 lands cleanly; if not, the executor reads the in-flight ADR-0042 ACCEPTED packet body and the Cosmos backing implementation (the ADR-0042 packet 03 work in `HoneyDrunk.Data`) for the canonical shape. No `dependencies:` edge to ADR-0042 packets in this initiative.
- **ADR-0046 (Specialist Review Agents, Proposed)** — the pattern the `database` agent follows (packet 02). An in-flight initiative `adr-0046-specialist-review-agents` ships the initial roster of five specialists (`cfo`, `security`, `performance`, `ai-safety`, `a11y`). The `database` agent is a **sixth specialist** outside the initial roster — added by ADR-0048's D13 commitment. **Soft dependency** — packet 02 references ADR-0046's pattern but doesn't strictly need ADR-0046 to be Accepted first (the specialist file structure is documented in ADR-0046 D4 regardless of status). If ADR-0046 is Accepted before this initiative's Wave 2 executes, the integration is cleaner; if not, the executor follows the existing `.claude/agents/*.md` structure plus the ADR-0046 D4 specification. No `dependencies:` edge to ADR-0046 packets in this initiative.
- **ADR-0047 (Testing Patterns and Tooling, Accepted) D11** — Tier 2b round-trip test job. ADR-0048 D12's round-trip test feeds this gate. **Soft dependency** — ADR-0047 is Accepted; the gate exists. Per-Node adoption is per ADR-0047's roll-out; packet 07 is conditional on Notify's Tier 2b project existing (recorded as a deferred test addition if it doesn't yet).
- **ADR-0036 (Disaster Recovery, Proposed) D9** — `dr-runbook.md` per Node. ADR-0048 D10 step 6 says the runbook "gains a Migration Failure section." **Soft dependency** — if `dr-runbook.md` doesn't exist in a target Node (likely the case today since ADR-0036 is still Proposed), the template (packet 06) and the per-Node README (packet 07/08) reference the future location with "to be added when ADR-0036 lands."

**No cross-initiative `dependencies:` edges in this initiative's packets.** The cross-ADR relationships above are conceptual and documentation-level; the filing pipeline does not need to wire `addBlockedBy` between this initiative and the sibling initiatives. The packets cite each sibling ADR by ID in the body for traceability.

## Wave Diagram

### Wave 1 (Foundation — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0048, add the three schema-evolution invariants (numbers **93/94/95**), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: add the `schema_evolution` field to `catalogs/grid-health.json` for every Node; extend `repos/{name}/integration-points.md` template with a Migration Coordination section. `Actor=Agent`. Blocked by: 00.

> **Invariant numbering.** The current verified maximum in `constitution/invariants.md` is **53**. Invariant numbers **93, 94, 95** are pre-reserved for ADR-0048 as part of a 12-ADR batch (ADR-0042: 75/76/77; ADR-0043: 78/79; ADR-0045: 80; ADR-0046: 81; ADR-0024 Flow: 74-82; ADR-0025 Sim: 83-92; ADR-0048: 93/94/95). If any invariant above 53 lands from outside this batch before packet 00 merges, shift this block upward, never reuse a number.

### Wave 2 (Specialist agent + review/scope wiring — parallel)
- [ ] **02** — Architecture: author `.claude/agents/database.md` specialist review agent per ADR-0046 pattern + ADR-0048 D13 rubric. `Actor=Agent`. Blocked by: 00.
- [ ] **03** — Architecture: update `.claude/agents/review.md` D3 category 13 to delegate depth review to the `database` specialist. `Actor=Agent`. Blocked by: 00.
- [ ] **04** — Architecture: add schema-change pre-flight detection to `.claude/agents/scope.md`; mirror context-loading additions in `review.md` per invariant 33. `Actor=Agent`. Blocked by: 00.

### Wave 3 (Workflow + per-Node template — parallel)
- [ ] **05** — Actions: author the `migrate.yml` reusable workflow per ADR-0048 D3/D11. `Actor=Agent`. Blocked by: 00.
- [ ] **06** — Architecture: author the canonical per-Node `Migrations/README.md` template per ADR-0048 D11 and D14 Phase 1. `Actor=Agent`. Blocked by: 00.

### Wave 4 (First adopters — Notify retroactive annotation + Kernel.Idempotency Phase 2 pilot — parallel)
- [ ] **07** — Notify: retroactively annotate the existing scaffold migrations with `[Rollback]` attributes; adopt the `Migrations/README.md` template from packet 06; add a Tier 2b round-trip test if the test project exists. `Actor=Agent`. Blocked by: 00, 02, 06.
- [ ] **08** — Kernel: document the Cosmos schema-on-read pattern for the `IIdempotencyStore` dedup state in `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` per ADR-0048 D7 and D14 Phase 2. `Actor=Agent`. Blocked by: 00, 06.

Packets within a wave run in parallel. **Wave-2 packets 02/03/04** are independent — 02 creates a new agent file, 03 edits review.md's category 13 stanza, 04 edits scope.md and review.md's context-loading list. The three edits to `review.md` from packets 03 and 04 touch different sections; either order is safe. **Wave-3 packets 05/06** are different repos. **Wave-4 packets 07/08** are different repos and different domains (Notify relational scaffold annotation vs Kernel document-store schema-on-read doc).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0048](./00-architecture-adr-0048-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [grid-health schema_evolution + integration-points Migration Coordination](./01-architecture-grid-health-schema-evolution-field.md) | Architecture | Agent | 1 | 00 |
| 02 | [`database` specialist review agent](./02-architecture-author-database-specialist-agent.md) | Architecture | Agent | 2 | 00 |
| 03 | [review.md D3 category 13 delegation to `database`](./03-architecture-review-d3-category-13-delegation.md) | Architecture | Agent | 2 | 00 |
| 04 | [scope.md pre-flight schema-change detection + invariant-33 mirror](./04-architecture-scope-preflight-schema-detection.md) | Architecture | Agent | 2 | 00 |
| 05 | [`migrate.yml` reusable workflow](./05-actions-migrate-yml-reusable-workflow.md) | Actions | Agent | 3 | 00 |
| 06 | [per-Node `Migrations/README.md` template](./06-architecture-migrations-readme-template.md) | Architecture | Agent | 3 | 00 |
| 07 | [Notify retroactive scaffold-migration annotation](./07-notify-retroactive-migration-annotation.md) | Notify | Agent | 4 | 00, 02, 06 |
| 08 | [Kernel idempotency Cosmos schema-on-read doc](./08-kernel-idempotency-cosmos-schema-on-read-doc.md) | Kernel | Agent | 4 | 00, 06 |

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution. Catalog/doc/governance/agent edits only (packets 00, 01, 02, 03, 04, 06).
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; packet 05 is a YAML workflow + optional composite-action change. CHANGELOG updated per repo convention.
- **`HoneyDrunk.Notify`** — packet 07 is annotation-and-docs only. **Patch bump** is appropriate (no new public API, no new feature, no break). Every non-test `.csproj` bumps together per invariant 27. Confirm Notify's current version at execution time.
- **`HoneyDrunk.Kernel`** — packet 08 is docs-only (a new `Migrations/README.md` next to `HoneyDrunk.Kernel.Abstractions`). **No version bump for docs alone** per invariant 12/27; if a Kernel release is already in flight, the doc rides along. Confirm at execution time.

## Cross-Cutting Concerns

### Audit, Memory, Knowledge, Billing, Notify Cloud — deliberate deferral

ADR-0048 D14 Phases 3–6 name Audit, Memory, Knowledge, Billing, and Notify Cloud as future adopters. This initiative does **not** ship those adoptions, by design:

- **Audit** — D14 Phase 3. The full pattern (round-trip test from day one, D8 constraints baked into the `database` agent's Audit-specific rules) is part of **Audit's standup track (ADR-0031)**. Per the memory note "New-Node / standup work gets its own ADR; don't bundle into feature packets." ADR-0031's standup track adopts the policy this initiative ships.
- **Memory, Knowledge** — D14 Phase 4. Each is a separate standup track (ADR-0021/0022) that consumes ADR-0048's pattern.
- **Billing** — D14 Phase 5. ADR-0037's standup track consumes the pattern, with the 30-day window per ADR-0048 D5 matching ADR-0042 D4's billing TTL.
- **Notify Cloud** — D14 Phase 6. The future per-tenant variant of D9 (if and when adopted) triggers a follow-up ADR per ADR-0048's Follow-up Work.

This initiative ships **the foundation** (governance, agent, workflow, template, two first-adopters). Every other consumer adopts the shipped policy in its own track. This keeps the initiative bounded and consistent with the Grid's standup-gets-its-own-ADR rule.

### The `[Rollback]` attribute's Grid-level home — deferred follow-up

ADR-0048 D12 names a `[Rollback(Strategy = ..., Notes/Reason = "...")]` attribute on every migration class but does not pin where the type lives. Three reasonable homes:

- (a) **`HoneyDrunk.Data.Abstractions`** — Grid-level, every migration-bearing Node references the same type. Cleanest long-term answer.
- (b) **Per-Node `HoneyDrunk.<Node>.Data`** — quick to ship; duplication across Nodes.
- (c) **A new tiny `HoneyDrunk.Migrations.Abstractions` package** — a Grid-level home that lives independently of the Data Node. Over-architected for v1.

**Packet 07's pragmatic compromise.** Ship (b) inside `HoneyDrunk.Notify.Data` for v1, with a recorded follow-up to consolidate into (a) or (c) once more Nodes adopt migrations. This avoids blocking the Notify annotation on a Data-side packet; the consolidation is a small follow-up packet against `HoneyDrunk.Data` and a coordinated update across consuming Nodes.

**This is a noted follow-up, not in this initiative's scope.** The follow-up is filed if and when the operator decides the duplication is meaningful; with one consumer (Notify) at v1, it isn't urgent.

### Path placement for the Kernel idempotency Cosmos schema-on-read doc — alternative documented

ADR-0048 D7 says "the dedup-state schema is documented in the Kernel's `Migrations/` folder" but the actual Cosmos backing lives in the Data repo (`HoneyDrunk.Data.Idempotency.Cosmos`). Packet 08's default is **`src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md`** (next to the contract), with the alternative path `src/HoneyDrunk.Data.Idempotency.Cosmos/Migrations/README.md` (next to the v1 backing) documented as a one-line retarget. The default is the cleaner long-term answer; the alternative is the conventional EF Core placement. Operator decision before execution.

### Site sync

No site-sync flag. ADR-0048 is internal Core-sector infrastructure — no public-facing Studios website content changes.

### Deferred follow-ups (explicitly out of scope)

- **Audit / Memory / Knowledge / Billing / Notify Cloud adoption** — D14 Phases 3–6; each follows in its own standup ADR's track.
- **Partition-key change on Cosmos** — ADR-0048 D7 names it as the most expensive Cosmos migration shape; a follow-up ADR if and when first needed. Not before then.
- **Per-tenant schemas** — ADR-0048 D9's second branch; a follow-up ADR if and when adopted.
- **`dev` automation of `migrate.yml`** — ADR-0048 names "auto-running `migrate.yml` against `dev` on every merge that touches `Migrations/`" as a Phase-4+-evaluated follow-up. Not in this initiative.
- **`[Rollback]` attribute Grid-level consolidation** — see the Cross-Cutting Concern above.
- **`dr-runbook.md` Migration Failure section template update** — ADR-0036 Follow-up Work; depends on ADR-0036 acceptance and template existence. Not in this initiative; the per-Node README (packets 07/08) and the canonical template (packet 06) point at the future location with "to be added when ADR-0036 lands."
- **`HoneyDrunk.Architecture`'s ADR index amendment for D14 Phase 1 → Phase 2 transition.** The Phase-2 pilot completion (packet 08 merging) is a milestone update for the initiative tracker; the dispatch plan updates at wave boundaries per ADR-0008 D7 ("dispatch plans are the one exception to packet immutability"), so updating this plan when Wave 4 completes is in-scope per the plan's living-narrative posture.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PRs. ADR returns to Proposed; the three invariants (93/94/95) and the `schema_evolution` catalog field are removed. No runtime impact.
- **Packet 02 (`database` agent file):** revert the PR. The agent file leaves `.claude/agents/`. No consumer breaks — specialists are manually invoked.
- **Packet 03 (review.md D3 category 13 delegation):** revert the PR. The generalist `review` agent's existing category-13 surface checks remain; the delegation stanza is removed.
- **Packet 04 (scope.md pre-flight + review.md context-loading mirror):** revert the PR. The scope agent loses the schema-change detector; the review.md context-loading list returns to its prior state. Invariant 33's symmetry is preserved either way (both `scope.md` and `review.md` revert together).
- **Packet 05 (`migrate.yml` workflow):** revert the workflow YAML. No consumer breaks — the workflow is `workflow_dispatch`-only via consumer-side caller workflows; reverting it disables the caller's `uses:` reference, which is itself caller-side.
- **Packet 06 (per-Node template):** revert the template file. No consumer breaks — the template is reference content; Nodes that already copied it (packets 07/08) retain their per-Node copies.
- **Packet 07 (Notify retroactive annotation):** revert the PR. Notify's scaffold migrations lose the `[Rollback]` attribute; the Notify `Migrations/README.md` is removed; any round-trip test added is removed. Notify's solution version rolls back the patch bump. Invariant 95 is unmet for Notify until re-applied.
- **Packet 08 (Kernel idempotency Cosmos schema-on-read doc):** revert the PR. The doc and the empty `Backfill/` directory are removed. No runtime impact (the doc is reference content; the Cosmos backing implementation is unchanged).

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
