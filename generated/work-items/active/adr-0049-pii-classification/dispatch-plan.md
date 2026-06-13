# Dispatch Plan — ADR-0049: Data Classification, PII Handling, and Retention Schedule

**Initiative:** `adr-0049-pii-classification`
**ADR:** ADR-0049 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0049 commits the Grid's canonical data-classification posture. It supplies the missing definition of "sensitive field" (closing Invariant 47's hollow reference), the PII sub-taxonomy with explicit GDPR Article 9 mapping, the Grid-wide retention schedule, the mechanical-enforcement attributes (`[Classification]`, `[PiiField]`), the boundary-redaction extensions to ADRs 0030/0040/0045, the right-to-erasure policy principle (mechanics deferred to sibling ADR-0050), the v1 Azure US East 2 residency commitment, and the inventory artifact (`catalogs/data-classification.json`) that makes Grid-wide classification visible.

This initiative delivers: ADR acceptance + 1 invariant amendment + 3 new invariants + catalog schema (Architecture); the attribute surface in `HoneyDrunk.Kernel.Abstractions` and the analyzer rule in `HoneyDrunk.Standards`; attribute-aware redaction in Pulse's Azure Monitor sink and Audit's append path, plus the cross-boundary PII-scrubbing canary; per-Node backfill across the Core-sector (Auth, Vault, Data) and Ops-sector (Notify, Communications) live Nodes; catalog population from the post-backfill surface + analyzer severity flip + hive-sync reconciliation; agent rubric updates (`security`, `review`, new `database`); and the commercial/legal artifacts (DPA + TIA + DPF runbook).

**13 packets across 6 waves**, targeting **7 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.Standards`, `HoneyDrunk.Pulse`, `HoneyDrunk.Audit`, `HoneyDrunk.Studios`, plus the per-Node backfill PRs that the coordinators 07/08 open in `HoneyDrunk.Auth`, `HoneyDrunk.Vault`, `HoneyDrunk.Data`, `HoneyDrunk.Notify`, `HoneyDrunk.Communications`). 12 packets are `Actor=Agent`; **1 packet (12) is `Actor=Human`** with the `human-only` label — the legal-document substance authoring is operator-only.

## Trigger

ADR-0049 is Proposed with no scope. The forcing functions from the ADR's Context:

1. **Invariant 47 is hollow without a "sensitive field" definition.** The reviewer agent and `security` specialist cannot enforce a redaction rule with no definition. ADR-0049 D2 supplies the definition (`[PiiField(SensitivePii)]`); packet 00 amends Invariant 47 to bind it.
2. **PDR-driven packet generation is blocked.** PDR-0003 (Lately), PDR-0005 (Hearth), PDR-0006 (Currents), PDR-0008 (Curiosities) all describe consumer apps that will collect personal data. None can move to `scope`-driven packet generation without a Grid-wide classification rubric.
3. **ADR-0036 D7's deferred backup-vs-erasure reconciliation is overdue.** Notify Cloud GA will inevitably receive a data-subject-deletion request. ADR-0049 D6 commits the policy principle; sibling ADR-0050 commits the mechanics; the DPA template (packet 12) closes ADR-0036 D7.
4. **The AI-sector standup wave** (Memory, Knowledge) introduces Nodes whose entire purpose is durable storage of user-attributable content. They need the classification scheme from day one (ADR-0049 D10 Phase 6 deferred).
5. **Florida Digital Bill of Rights effective 2026-07-01** introduces consumer rights to access/correction/deletion/portability — free compliance if D6 mechanics are in place.

## Scope Detection

**Multi-repo, multi-Node, cross-cutting.** The contract lands in `HoneyDrunk.Kernel.Abstractions` (the established Grid-wide-primitive home — same placement as `IGridContext`, `TenantId`, ADR-0042's `IGridMessageEnvelope`). The enforcement analyzer lands in `HoneyDrunk.Standards.Analyzers`. The boundary redactors land in `HoneyDrunk.Pulse` and `HoneyDrunk.Audit`. The catalog and governance artifacts land in `HoneyDrunk.Architecture`. The legal/commercial artifacts land in `HoneyDrunk.Studios`. The backfill fans out to the 5 Core/Ops-sector Live Nodes (Auth, Vault, Data, Notify, Communications) via coordinator packets 07 and 08.

**Contract is additive — no forced downstream cascade.** The new contracts (`ClassificationAttribute`, `PiiFieldAttribute`, `DataClass`, `PiiCategory`) are *additive* to `HoneyDrunk.Kernel.Abstractions`. Per ADR-0035 this is an additive minor bump on Kernel; downstream Nodes adopt the markers as their backfill PRs land. The analyzer rule from packet 03 is a `Warning` at first (30-day adoption ramp per ADR-0049 D10 Phase 1) — unmarked surface is visible-but-non-blocking until packet 10 flips to error.

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node. The new `database` specialist agent (packet 11) is an agent-definition addition, not a Node standup; ADR-0046 D9 named it as a follow-up candidate, this ADR's follow-up promotes it.

## Cross-ADR Coupling

ADR-0049 extends ADRs 0030, 0036, 0040, 0045, and 0046, and is sibling to ADR-0050. The relationships:

- **ADR-0030 (Audit Substrate)** — extended. Invariant 47's "sensitive field" gains a definition (packet 00); the audit append path runs the attribute-aware redactor and rejects SensitivePii outright (packet 05, new invariant 59).
- **ADR-0036 (Disaster Recovery)** — extended. ADR-0036 D7's deferred DPA work is closed by packet 12; ADR-0036 D7's deferred backup-vs-erasure reconciliation is closed by ADR-0049 D3 (retention) + D6 (erasure policy) + ADR-0050 (mechanics).
- **ADR-0040 (Telemetry Backend)** — extended. The previously-implicit "sensitive field" in ADR-0040 D9's PII carve-outs is bound to the `[PiiField]` markers (packet 04); the PII-scrubbing canary that ADR-0040 deferred is shipped (packet 06).
- **ADR-0045 (Grid-Wide Error Tracking)** — extended. The error-channel scrubbing rule from ADR-0045 D7 is now mechanically enforced via the same shared redactor (packet 04).
- **ADR-0046 (Specialist Review Agents)** — extended. The `security` specialist gains the canonical D1–D6 rubric (packet 11). The `database` specialist is promoted from D9 candidate to v1 roster (packet 11).
- **ADR-0050 (Tenant Lifecycle, sibling)** — depends on this ADR. ADR-0050's tenant-lifecycle mechanics (create / suspend / export / delete) implement against the classification taxonomy (D1), the PII sub-taxonomy (D2), the erasure policy principle (D6), and the inventory catalog (D9) that this ADR commits. ADR-0050 is in its own initiative; this initiative does not flip ADR-0050.

**This initiative is a hard dependency for ADR-0050 packet authoring** — ADR-0050 scope cannot decompose into actionable packets until ADR-0049's D6 policy principle and D2 taxonomy are Accepted (packet 00 closes this gate).

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0049, amend Invariant 47, add invariants **58, 59, 60**, register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: Author the `catalogs/data-classification.json` schema and seed an empty inventory. `Actor=Agent`. Blocked by: 00.

> **Invariant numbering.** Invariant numbers **58, 59, 60** are claimed from `constitution/invariant-reservations.md`, which is the source of truth for in-flight invariant ranges. At authoring time `constitution/invariants.md` max is **53** and ADR-0051 reserves **54–57**, so ADR-0049's reserved block is **58–60**. Packet 00 must re-read the reservation row before opening its PR; if the registry has shifted, update every ADR-0049 packet reference in the same rebase and never reuse a number already landed or reserved.

### Wave 2 (Depends on Wave 1 — contract foundation, parallel)
- [ ] **02** — Kernel: Add `[Classification]`, `[PiiField]`, `DataClass`, `PiiCategory` to `HoneyDrunk.Kernel.Abstractions`. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Kernel` in this initiative.**
- [ ] **03** — Standards: Ship the unmarked-classification analyzer rule at `Warning` severity. `Actor=Agent`. Blocked by: 02. **Version-bumping packet for `HoneyDrunk.Standards` in this initiative.**

### Wave 3 (Depends on Wave 2 — redactor integrations + canary, parallel)
- [ ] **04** — Pulse: Wire attribute-aware redaction into the Azure Monitor sink (logs, traces, errors). `Actor=Agent`. Blocked by: 02. **Version-bumping packet for `HoneyDrunk.Pulse` in this initiative.**
- [ ] **05** — Audit: Wire attribute-aware redaction + SensitivePii rejection into the append path. `Actor=Agent`. Blocked by: 02. **Version-bumping packet for `HoneyDrunk.Audit` in this initiative.**
- [ ] **06** — Pulse: Ship the PII-scrubbing canary (closes deferred follow-ups from ADR-0040 and ADR-0045). `Actor=Agent`. Blocked by: 04, 05. Appends to packet 04's in-progress `[X.Y.0]` CHANGELOG entry — no re-bump.

### Wave 4 (Depends on Wave 2 — per-Node backfill, parallel coordinators)
- [ ] **07** — Architecture (coordinator opening PRs in Vault, Data, Auth): Backfill Core-sector `[Classification]`/`[PiiField]` markers. `Actor=Agent`. Blocked by: 03.
- [ ] **08** — Architecture (coordinator opening PRs in Notify, Communications, possibly Pulse): Backfill Ops-sector markers. `Actor=Agent`. Blocked by: 03.

> Wave 4 packets are coordinators; the actual edits land via per-Node PRs the executor opens. Three Core-sector PRs (Vault → Data → Auth, sequential with human release tags between them) and two-or-three Ops-sector PRs (Notify → Communications, possibly Pulse) all proceed in parallel within Wave 4 with the per-sector sequencing inside each coordinator.

### Wave 5 (Depends on Wave 4 — catalog population + governance close, parallel)
- [ ] **09** — Architecture: Populate `catalogs/data-classification.json` from the post-backfill Grid surface; annotate `catalogs/contracts.json`. `Actor=Agent`. Blocked by: 01, 07, 08.
- [ ] **10** — Standards + Architecture (two sibling PRs): Flip the analyzer to error severity; wire `hive-sync` reconciliation. `Actor=Agent`. Blocked by: 09. **30-day window check** from packet 03's merge.
- [ ] **11** — Architecture: Update `.claude/agents/security.md`, `.claude/agents/review.md`, author `.claude/agents/database.md`. `Actor=Agent`. Blocked by: 00.

### Wave 6 (Depends on Wave 1 — commercial/legal artifacts, deferred-paced)
- [ ] **12** — Studios: Author DPA template, v1 TIA, DPF enrollment runbook. **`Actor=Human`** with `human-only` label. Blocked by: 00.

Packets within a wave run in parallel. **Wave-3 packets 04 and 05 are independent** — different repos, different solutions; **packet 06 is hard-blocked behind both** (the canary exercises both redactor implementations end-to-end). **Wave-4 packets 07 and 08 are independent** — different sets of target Nodes, different coordinator scopes. **Wave-5 packet 11 can land in parallel with Wave 5 packets 09/10** because it touches only `.claude/agents/`, not the catalog files; if convenient it lands earlier (as soon as packet 00 has merged), but is grouped in Wave 5 for cleanliness with the other Phase 4–5 governance closures. **Wave-6 packet 12 can also land earlier** in agent-PR scaffolding form once packet 00 has merged — the full closure waits on operator legal authoring.

> **Important sequencing note about packet 02's coupling with ADR-0042.** ADR-0042 also bumps `HoneyDrunk.Kernel` (its packet 02). If ADR-0042's Kernel packet lands first, this packet 02 bumps from that version (e.g. 0.7.0 → 0.8.0 by ADR-0042, then this packet's bump to 0.9.0). If this packet's 02 lands first (less likely given ADR-0042 has been Accepted earlier), Kernel goes 0.7.0 → 0.8.0 here and ADR-0042's next Kernel-touching packet appends to the CHANGELOG. Read the current Kernel version at branch time and bump from there. The version-bumping discipline is per-initiative-first-packet-on-the-solution (invariant 27).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0049](./00-architecture-adr-0049-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Data-classification catalog schema](./01-architecture-data-classification-catalog-schema.md) | Architecture | Agent | 1 | 00 |
| 02 | [Kernel classification attributes + enums](./02-kernel-classification-attributes-and-enums.md) | Kernel | Agent | 2 | 00 |
| 03 | [Standards unmarked-field analyzer](./03-standards-unmarked-field-analyzer.md) | Standards | Agent | 2 | 02 |
| 04 | [Pulse attribute-aware redaction](./04-pulse-attribute-aware-redaction.md) | Pulse | Agent | 3 | 02 |
| 05 | [Audit attribute-aware redactor + SensitivePii rejection](./05-audit-attribute-aware-redactor-and-sensitivepii-rejection.md) | Audit | Agent | 3 | 02 |
| 06 | [Pulse PII-scrubbing canary](./06-pulse-pii-scrubbing-canary.md) | Pulse | Agent | 3 | 04, 05 |
| 07 | [Core-sector classification backfill (Vault, Data, Auth)](./07-core-nodes-classification-backfill.md) | Architecture (fan-out) | Agent | 4 | 03 |
| 08 | [Ops-sector classification backfill (Notify, Communications)](./08-ops-nodes-classification-backfill.md) | Architecture (fan-out) | Agent | 4 | 03 |
| 09 | [Populate data-classification catalog](./09-architecture-populate-data-classification-catalog.md) | Architecture | Agent | 5 | 01, 07, 08 |
| 10 | [Flip analyzer to error + hive-sync reconciliation](./10-standards-flip-analyzer-to-error-and-hive-sync-reconciliation.md) | Standards + Architecture | Agent | 5 | 09 |
| 11 | [Security/review/database agent updates](./11-architecture-security-database-agents-and-review-rubric.md) | Architecture | Agent | 5 | 00 |
| 12 | [DPA + TIA + DPF artifacts](./12-studios-dpa-tia-dpf-artifacts.md) | Studios | **Human** | 6 | 00 |

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 02 is the first packet on the solution in this initiative; it bumps every non-test `.csproj` to the same new minor version (additive feature: classification attributes + enums; no break per ADR-0035). The exact number depends on whether ADR-0042's Kernel packets land first — read at branch time.
- **`HoneyDrunk.Standards`** — packet 03 bumps the solution one minor version (analyzer behavior change shipped as an additive rule). Packet 10's Standards-side PR is the second on this solution in this initiative; it appends to the in-progress CHANGELOG entry without re-bumping (invariant 27).
- **`HoneyDrunk.Pulse`** — packet 04 bumps the solution one minor version. Packet 06 is the second Pulse-touching packet in this initiative; it appends to the CHANGELOG entry without re-bumping (invariant 27).
- **`HoneyDrunk.Audit`** — packet 05 bumps the solution one minor version (additive Abstractions surface + runtime redactor behavior).
- **`HoneyDrunk.Auth` / `HoneyDrunk.Vault` / `HoneyDrunk.Data` / `HoneyDrunk.Notify` / `HoneyDrunk.Communications`** — each gets a solution-version bump via the relevant Wave 4 backfill PR (one minor version per Node).
- **`HoneyDrunk.Studios`** — no .NET solution version-bump needed; the legal documents are Markdown.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/agent-definition edits only.

## Cross-Cutting Concerns

### `HoneyDrunk.Analyzers` vs `HoneyDrunk.Standards.Analyzers` — naming pinned

ADR-0049 D4 names the analyzer package as "`HoneyDrunk.Analyzers`." The existing Grid analyzer package is **`HoneyDrunk.Standards.Analyzers`** (under the `HoneyDrunk.Standards` repo). Same artifact, same role. Packet 03 ships the new rule in the existing canonical package — no new package is created. The ADR's text uses "HoneyDrunk.Analyzers" as a working name; the executor uses the canonical name. There is no operator decision pending.

### Audit redactor's SensitivePii — rejection, not redaction

ADR-0049 D5's table row for Audit reads: "`[PiiField(SensitivePii)]` → `[REDACTED:sensitive]`." ADR-0049 D6's text and invariant 59 (added in packet 00) read: "`[PiiField(SensitivePii)]`-marked fields never appear in the audit channel, even as redaction-tokens. The Audit Node rejects appends whose Before/After payload reflection surfaces a SensitivePii marker. Only the field-name-and-class metadata may appear."

These two are in tension only on a surface reading. The resolution: D5's "`[REDACTED:sensitive]`" describes the redactor's *output* if you ran it through; D6's text overrides that for the audit channel specifically, mandating *rejection of the append* rather than persistence of the redacted form. Packet 05 implements D6's stricter reading — the audit redactor refuses the append and emits operational telemetry naming the offending field + classification, but persists nothing. The "field name, classification, source Node" record D6 alludes to is the operational-telemetry signal to Pulse, not a persisted partial audit entry.

### The 30-day analyzer window

Packet 03 ships the analyzer at `Warning`. Packet 10 flips it to `Error`. The 30-day window starts from packet 03's merge date. The executor of packet 10 checks at branch time whether 30 days have elapsed; if not, waits. The window is a deliberate adoption ramp — Wave 4 backfill PRs (packets 07/08) need time to land before unmarked-field surface fails CI for in-flight branches.

### Audit-side `IAuditTokenizer` stub vs ADR-0050's real implementation

Packet 05 ships an `InMemoryAuditTokenizer` stub. The real Auth-backed tokenizer (per ADR-0049 D6's PII↔token map principle) is part of **sibling ADR-0050's tenant-lifecycle scope**. This initiative ships the seam and the stub; ADR-0050 wires the real impl. Until ADR-0050 lands, the in-process audit-redaction path works correctly with the stub (deterministic-hash tokens with an InMemory map); production deployments would need a real impl before relying on right-to-erasure end-to-end. This is acknowledged in packet 05 and surfaced in the Wave 3 handoff.

### Consumer-app PDR onboarding stores — deferred

ADR-0049 D10 Phase 6 covers consumer-app onboarding stores (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0008 Curiosities). They self-register in `catalogs/data-classification.json` at their own Node standup, applying the D4 attributes from day one. This initiative does **not** scope any consumer-app work. The closure of "PDR-to-scope blockage cleared" is structural: the rubric exists, the attributes exist, the analyzer exists, the catalog exists — the next PDR-standup packet generation can proceed.

### AI-sector Memory/Knowledge — deferred to standup

ADR-0049 D11 names `HoneyDrunk.Memory` (ADR-0022) and `HoneyDrunk.Knowledge` (ADR-0021) as Nodes whose standup canaries should include the redaction surface from day one. Both are Proposed in their own initiatives. This initiative does NOT scope their backfill or canary work. When those standup ADRs reach scope-driven packet generation, they consume this ADR's contract surface (attributes from packet 02; analyzer from packet 03; redactors from packets 04/05). Their packets will *reference* this initiative as completed-context, not block on it (apart from the contract-surface NuGet availability).

### Human release tags between waves

Wave 4 (per-Node backfill) consumes `HoneyDrunk.Kernel.Abstractions` at the packet-02-published version. Agents merge code; humans push git release tags. The release-tag steps are surfaced in the Human Prerequisites of packets 04, 05, 07, and 08 — the operator pushes a `HoneyDrunk.Kernel` tag after packet 02 merges, then a `HoneyDrunk.Standards` tag after packet 03 merges, then per-Node tags as backfill PRs land.

Wave 5 packet 09 (catalog population) reads the post-merge state of the live Nodes; it does not strictly require their releases to be on the package feed (the catalog walk is source-level, not package-level), but its CI-build does build the Architecture repo's normal toolchain and is unaffected. Wave 5 packet 11 (agent files) and Wave 6 packet 12 (legal artifacts) have no package-release dependencies.

### `Actor=Human` for packet 12 — operator legal authoring

Packet 12 is the only `Actor=Human` packet in this initiative. The legal substance of the DPA, TIA, and DPF enrollment is operator-only. The packet has a two-stage workflow: Stage 1 is the agent-PR scaffolding (file structure, ADR cross-references, procedural sections, DPF runbook fully authored, TIA technical sections); Stage 2 is the operator-completed legal substance + DPF payment, landing in subsequent commits at the operator's pace. The `human-only` label reflects the *substance*-completion gate.

### Deferred follow-ups (explicitly out of scope)

- **ADR-0050 (Tenant Lifecycle)** — sibling ADR; depends on this one's D6 principle. Its own initiative.
- **Consumer-app PDR standups** — Phase 6 of ADR-0049 D10; each PDR's own standup track.
- **AI-sector Memory/Knowledge classification canaries** — those Nodes' own standup tracks (ADR-0021, ADR-0022).
- **Real `IAuditTokenizer` wiring against the per-Node identity store** — ADR-0050's scope.
- **Customer-counterparty DPA signature flow** — commercial negotiation, not a packet.
- **External legal review of the DPA template** — operator-decided, optional.
- **Multi-region data residency** — ADR-0049 D7 explicitly out of scope; a future ADR when the first non-US-residency tenant requirement arrives.
- **More precise analyzer detection scope** (call-graph through `IRepository<T>` generic positions rather than the v1 PackageReference-based heuristic) — v2 of the analyzer rule.

### Site sync

No site-sync flag. ADR-0049 is internal Core-sector governance and infrastructure — no public-facing Studios website content changes. The legal documents authored in packet 12 sit in the Studios repo's `business/legal/` folder, not as published pages.

## Rollback Plan

- **Packet 00 (acceptance + invariants):** revert the PR. ADR returns to Proposed; Invariant 47 reverts to its pre-amendment form; invariants 58/59/60 are removed. No runtime impact.
- **Packet 01 (catalog schema):** revert the PR. The new `data-classification.json` file is deleted; the catalog index doc reverts. No runtime impact.
- **Packet 02 (Kernel attributes):** revert the PR; the Kernel solution rolls back one minor version. The attributes leave `HoneyDrunk.Kernel.Abstractions`. Downstream packets that consumed them (03–08) would break at the next build; do not revert 02 alone — coordinate with downstream packets.
- **Packet 03 (Standards analyzer rule):** revert the PR; the analyzer rule is removed from `HoneyDrunk.Standards.Analyzers`. Standards rolls back one minor version. Backfill packets 07/08 lose their warning-driven checklist but can still proceed manually.
- **Packet 04 (Pulse redactor):** revert the PR; Pulse rolls back one minor version. The `LogRecordProcessor`/`SpanProcessor`/error-reporter revert to their pre-redactor behavior. The defense-in-depth half at the boundary is lost; the emitter-side discipline from packets 07/08 markers remains in place but unenforced at the Pulse boundary. PII may leak in telemetry until re-applied.
- **Packet 05 (Audit redactor + tokenizer):** revert the PR; Audit rolls back one minor version. The append path reverts to no-redaction; the new `IAuditTokenizer` interface leaves Abstractions. Audit entries from emitters that pre-redacted are still safe; emitters that relied on the boundary defense leak raw values into audit. The SensitivePii-rejection contract is gone — invariant 59 is unenforced until re-applied.
- **Packet 06 (canary):** revert the PR; the canary leaves the Pulse test suite. CI no longer catches redactor regressions; a future redactor change could silently break without test failure.
- **Packet 07 (Core-sector backfill):** revert each Node's PR independently. Auth/Vault/Data lose their markers; the Pulse/Audit redactors find nothing to redact on those Nodes' types. Roll back each Node's solution version per the revert.
- **Packet 08 (Ops-sector backfill):** same as 07 for Notify/Communications.
- **Packet 09 (catalog population):** revert the PR. `data-classification.json` returns to empty; `contracts.json` annotations are removed. No runtime impact; hive-sync (if active) detects this as drift and emits findings until re-populated.
- **Packet 10 (analyzer-flip + hive-sync rule):** revert either PR independently. Standards analyzer returns to Warning; hive-sync reconciliation rule is removed. Phase 4 reopens; the 30-day window may need to be re-evaluated.
- **Packet 11 (agent files):** revert the PR. `security.md` loses its rubric section; `review.md` loses the D3 category 9 checklist items; `database.md` is deleted. The Architecture-agents hardlink re-sync would need re-running to clear the cached versions.
- **Packet 12 (legal artifacts):** revert the PR. DPA/TIA/DPF files leave the Studios repo. No customer-counterparty contract relies on them at v1 yet (they are new artifacts); revert is contained.

**Operational escape hatch for redactor regressions:** if packets 04 or 05 ship a redactor bug that drops legitimate data (false positive) or fails to redact PII (false negative), the operational telemetry from the Audit Node (packet 05) and the canary failures (packet 06) surface the issue before it spreads. Revert the specific packet; the upstream packets (00–03, 07–08) stay intact.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. Packet 12 will surface `Actor=Human` on the board via its `human-only` label. No manual `gh issue create`.
