---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0068", "wave-1"]
dependencies: []
adrs: ["ADR-0068", "ADR-0006", "ADR-0015"]
wave: 1
initiative: adr-0068-background-jobs
node: honeydrunk-architecture
---

# Reflect the HoneyDrunk.Jobs deferral and the two pinned background-work substrates in Grid catalogs and Node context

## Summary
Update the Architecture-repo catalogs and Node-context files to reflect ADR-0068's follow-up checklist: remove `HoneyDrunk.Jobs` from the Planned Nodes section of `infrastructure/reference/tech-stack.md`; remove the `HoneyDrunk.Jobs` line from the Future section of `initiatives/roadmap.md`; record the grandfather posture for Vault.Rotation's Azure Functions timer triggers in `repos/HoneyDrunk.Vault.Rotation/boundaries.md` (D1/D7); record the Container Apps Jobs substrate for Communications cadence/drip-campaign scheduling in the `HoneyDrunk.Communications` repo context (D3); record the in-Node `BackgroundService` substrate for Notify retries in the `HoneyDrunk.Notify` repo context (D2); register the `adr-0068-background-jobs` initiative in `initiatives/active-initiatives.md`. ADR-0068 stays **Proposed** — the status flip is packet 05's job.

## Context
ADR-0068 settles workload categorization (in-Node `BackgroundService`, cross-Node Container Apps Jobs, GitHub Actions cron for CI/CD ops) and defers the `HoneyDrunk.Jobs` Node indefinitely (D4 — "Container Apps Jobs subsumes the Node"). The ADR's "If Accepted — Required Follow-Up Work" checklist names six catalog/reference updates that must land. This packet lands four of them (the catalog/reference half) plus initiative registration; the remaining two (the reusable workflow and the invariants) land in packets 02 and 01 respectively.

ADR-0068 D4 + Catalog obligations: "`catalogs/nodes.json` — **no `honeydrunk-jobs` entry to add.** This ADR explicitly defers the Node." This packet must therefore **not** add a `honeydrunk-jobs` Node anywhere in the catalogs. The only Jobs-Node trace in the current catalogs is the `Jobs | Ops | Background job scheduling` row in `tech-stack.md`'s Planned Nodes table (line 204) and the `HoneyDrunk.Jobs — Background job scheduling with Grid integration` line in `roadmap.md`'s Future section (line 67). Both go.

The Vault.Rotation grandfather posture (D1 + D7) is documentation-only — no code change in `HoneyDrunk.Vault.Rotation`. The context update is in `repos/HoneyDrunk.Vault.Rotation/boundaries.md` only.

ADR-0068 stays **Proposed** through this packet — the ADR header is **not** flipped here. Per the ADR's Done-When list, the Status flip happens only after the deploy workflow lands (packet 02) and the first job ships under the new substrate (packets 03 and 04). That is packet 05's job.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `infrastructure/reference/tech-stack.md` — remove the `Jobs | Ops | Background job scheduling` row from the **Planned Nodes (no code yet)** table (line 204), OR move it to a new "Deferred — substrate covered by Container Apps Jobs" subsection if such a subsection makes editorial sense (the ADR's checklist allows either). Removing is cleaner; the deferral rationale is captured in ADR-0068 itself.
- `initiatives/roadmap.md` — remove the `HoneyDrunk.Jobs — Background job scheduling with Grid integration` line from the **Future** section (line 67), OR move it to a "Deferred — substrate decided" subsection. Same editorial choice as tech-stack.md; record which was chosen in the PR description so the two files are consistent.
- `repos/HoneyDrunk.Vault.Rotation/boundaries.md` — add a "Substrate (grandfathered)" subsection recording that Vault.Rotation stays on its Azure Functions timer triggers per ADR-0068 D1/D7 (new cross-Node recurring work goes on Container Apps Jobs; Vault.Rotation is grandfathered until a natural migration moment).
- `repos/HoneyDrunk.Communications/boundaries.md` — record that cadence/drip-campaign scheduling uses Azure Container Apps Jobs per ADR-0068 D3, with cron strings 5-field UTC per ADR-0063 D6. (Pinned to `boundaries.md`, not `overview.md`.)
- `repos/HoneyDrunk.Notify/boundaries.md` — record that in-Node retries use the `IHostedService` / `BackgroundService` pattern per ADR-0068 D2, with `TimeProvider` reads per ADR-0063 D1 and ISO 8601 duration strings for backoff per ADR-0063 D6. (Pinned to `boundaries.md`, not `overview.md`.)
- `initiatives/active-initiatives.md` — register the `adr-0068-background-jobs` initiative with the packet checklist for this folder.

## Proposed Implementation
1. **`infrastructure/reference/tech-stack.md`** — remove (or relocate) the Jobs row in the Planned Nodes table. Record the PR-description rationale: "`HoneyDrunk.Jobs` deferred indefinitely per ADR-0068 D4 — Container Apps Jobs (D3) subsumes the role; in-Node work uses `BackgroundService` (D2)."
2. **`initiatives/roadmap.md`** — remove (or relocate) the `HoneyDrunk.Jobs — Background job scheduling with Grid integration` line under "Future."
3. **`repos/HoneyDrunk.Vault.Rotation/boundaries.md`** — append a "Substrate (grandfathered)" subsection (the file currently has Owns / Does NOT Own / Status sections; add Substrate after Status). The substance: "Vault.Rotation runs on Azure Functions timer triggers per ADR-0006 Tier-2 rotation. Per ADR-0068 D1/D7 this is the grandfathered substrate — new cross-Node recurring work uses Azure Container Apps Jobs (ADR-0068 D3). Vault.Rotation is not retroactively migrated; the grandfather lasts until a natural migration moment (a major Vault.Rotation rewrite, or Azure Functions plan retirement)."
4. **`repos/HoneyDrunk.Communications/boundaries.md`** (the editorial home — boundaries.md captures "what Communications Owns") — under the "What Communications Owns" list (which already includes "Cadence decisions: send now, suppress, or defer."), append a "Substrate" subsection at the end of the file (parallel to other boundary clarifications). The substance: "Cadence and drip-campaign scheduling runs as an Azure Container Apps Job per ADR-0068 D3. Cron strings are 5-field UTC per ADR-0063 D6; `TimeProvider` is used for wall-clock reads per ADR-0063 D1; ISO 8601 duration strings for any in-job pacing per ADR-0063 D6. Idempotency is mandatory per ADR-0068 D6 using `IIdempotencyStore` (ADR-0042)."
5. **`repos/HoneyDrunk.Notify/boundaries.md`** — append a "Substrate" subsection. The substance: "In-Node retry handling (the Notify retry pump and any future in-process recurring or batch work) runs as an `IHostedService` / `BackgroundService` in the Notify Worker process per ADR-0068 D2. `TimeProvider` is used for wall-clock reads per ADR-0063 D1; ISO 8601 duration strings for backoff configuration per ADR-0063 D6. Idempotency is mandatory per ADR-0068 D6 using `IIdempotencyStore` (ADR-0042). Notify never depends on a third-party in-process scheduler (Quartz, Hangfire) — invariant tied to ADR-0068 D2."
6. **`initiatives/active-initiatives.md`** — register the `adr-0068-background-jobs` initiative with the wave structure and packet checklist for this folder (00, 01, 02, 03, 04, 05).

## Affected Files
- `infrastructure/reference/tech-stack.md`
- `initiatives/roadmap.md`
- `repos/HoneyDrunk.Vault.Rotation/boundaries.md`
- `repos/HoneyDrunk.Communications/boundaries.md`
- `repos/HoneyDrunk.Notify/boundaries.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance/reference files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No `honeydrunk-jobs` entry added anywhere in the catalogs (D4 + Catalog obligations are explicit on this).
- [x] No new Node-to-Node edge — only `HoneyDrunk.Communications` and `HoneyDrunk.Notify` context get substrate-choice notes; no relationship-graph change.

## Acceptance Criteria
- [ ] `infrastructure/reference/tech-stack.md` no longer lists `Jobs | Ops | Background job scheduling` in the Planned Nodes table — either removed entirely or relocated to a "Deferred" subsection (choice recorded in the PR description)
- [ ] `initiatives/roadmap.md` no longer lists `HoneyDrunk.Jobs — Background job scheduling with Grid integration` in the Future section — either removed or relocated to a "Deferred" subsection (consistent with tech-stack.md's choice)
- [ ] `repos/HoneyDrunk.Vault.Rotation/boundaries.md` has a "Substrate (grandfathered)" subsection citing ADR-0068 D1/D7, naming Azure Functions timer triggers as the grandfathered substrate, and the "natural migration moment" condition for revisiting
- [ ] `repos/HoneyDrunk.Communications/boundaries.md` has a "Substrate" subsection citing ADR-0068 D3 (Container Apps Jobs) and ADR-0063 D6 (cron format) / D1 (`TimeProvider`)
- [ ] `repos/HoneyDrunk.Notify/boundaries.md` has a "Substrate" subsection citing ADR-0068 D2 (`BackgroundService`) and ADR-0063 D1 (`TimeProvider`) / D6 (ISO 8601 durations) — and naming Quartz/Hangfire as forbidden per the D2 invariant
- [ ] `initiatives/active-initiatives.md` registers `adr-0068-background-jobs` with the packet checklist for this folder
- [ ] `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json` are **not modified** — D4 + Catalog obligations are explicit that no `honeydrunk-jobs` Node entry is added
- [ ] ADR-0068 header is **not** modified — it stays `**Status:** Proposed` (status flip is packet 05's job)
- [ ] `adrs/README.md` is **not** modified for ADR-0068 (also packet 05's job)
- [ ] No new invariant added in this packet (invariants land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0068 D1 — Three workload categories, each with its own substrate.** CI/CD ops cron stays on GitHub Actions (out of scope for this ADR per the table). In-Node background processing uses `IHostedService` / `BackgroundService` (D2). Cross-Node recurring orchestration uses Azure Container Apps Jobs (D3).

**ADR-0068 D2 — In-Node background processing uses `IHostedService` / `BackgroundService`.** "Every Node that needs in-process recurring or background work uses ASP.NET Core's built-in `IHostedService` interface (typically via the `BackgroundService` base class). No Quartz, no Hangfire, no third-party scheduler dependency." Time substrate is `TimeProvider` per ADR-0063 D1.

**ADR-0068 D3 — Cross-Node recurring orchestration uses Azure Container Apps Jobs.** "Every cross-Node recurring or event-driven job runs on Azure Container Apps Jobs. This is the Jobs-shaped sibling of the Container Apps decision in ADR-0015." Cron strings are 5-field UTC per ADR-0063 D6. Naming: `caj-hd-{service}-{env}` (the Jobs-shaped sibling of invariant 34's `ca-hd-{service}-{env}`); the 13-character service-name limit (invariant 19) applies.

**ADR-0068 D4 — `HoneyDrunk.Jobs` Node deferred indefinitely.** "Container Apps Jobs subsumes the Node — Azure provides the scheduling, observability, retry, and durability; the per-job business logic lives in the Node that owns the job (Communications owns its drip-campaign Job; Vault.Rotation owns its rotation Jobs)." Roadmap entry moves to "Deferred" or is removed; no `honeydrunk-jobs` catalog entry.

**ADR-0068 D7 — Vault.Rotation grandfather posture.** "Vault.Rotation per ADR-0006 Tier 2 uses Azure Functions timer triggers today. The grandfather posture: stays on its existing substrate until a natural migration moment (a major rewrite of Vault.Rotation, or a Functions plan retirement). New cross-Node recurring work goes on Container Apps Jobs per D3; Vault.Rotation is not retroactively migrated."

**ADR-0068 Catalog obligations.** "`catalogs/nodes.json` — **no `honeydrunk-jobs` entry to add.** This ADR explicitly defers the Node. `catalogs/contracts.json` — no entry. The contract surface (cron strings, `BackgroundService` shape, Container Apps Jobs deploy manifest) is platform/BCL types; nothing HoneyDrunk-owned to register. `constitution/invariants.md` — append the new invariants listed above with sequential numbers at acceptance. `infrastructure/reference/tech-stack.md` — update the `HoneyDrunk.Jobs` row per the follow-up checklist. `initiatives/roadmap.md` — update line 67 per the follow-up checklist."

## Constraints
- **ADR-0068 stays Proposed.** Do not flip the ADR header in this packet. Do not edit the `adrs/README.md` index row for ADR-0068. The flip is packet 05's job.
- **No `honeydrunk-jobs` entry in any catalog.** `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json` are not modified. The Jobs deferral is the decision; the catalogs reflect it by NOT having an entry.
- **One Substrate subsection per repo-context file.** Don't sprinkle the substrate note across multiple files in the same repo's context — pick boundaries.md (it already structures ownership/non-ownership claims) and append once.
- **No invariant change.** The four ADR-0068 invariants land in packet 01 as Proposed; they are promoted in packet 05. This packet adds none.
- **Roadmap and tech-stack must be editorially consistent.** Both files reference the same Jobs Node — both remove or both relocate. The PR description names the choice.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0068`, `wave-1`

## Agent Handoff

**Objective:** Reflect ADR-0068's Jobs-deferral and substrate decisions in the Architecture-repo catalogs and Node-context files.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the catalog/reference half of ADR-0068's follow-up checklist while the ADR stays Proposed. The flip happens in packet 05 after the first consumers ship.
- Feature: ADR-0068 Background Job and Recurring Work Substrate rollout, Wave 1.
- ADRs: ADR-0068 (primary), ADR-0006 (Vault.Rotation Tier-2 grandfather context), ADR-0015 (Container Apps platform parent of Container Apps Jobs).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. First packet in the initiative.

**Constraints:**
- ADR-0068 stays Proposed through this packet — do not flip the header or the `adrs/README.md` row.
- No `honeydrunk-jobs` entry in any catalog. The Jobs deferral is the decision; the catalogs reflect it by absence.
- Roadmap and tech-stack must be editorially consistent — both remove or both relocate.

**Key Files:**
- `infrastructure/reference/tech-stack.md` — line 204 (Jobs row in Planned Nodes table).
- `initiatives/roadmap.md` — line 67 (HoneyDrunk.Jobs in Future section).
- `repos/HoneyDrunk.Vault.Rotation/boundaries.md` — new "Substrate (grandfathered)" subsection.
- `repos/HoneyDrunk.Communications/boundaries.md` — new "Substrate" subsection.
- `repos/HoneyDrunk.Notify/boundaries.md` — new "Substrate" subsection.
- `initiatives/active-initiatives.md` — register `adr-0068-background-jobs`.

**Contracts:** None changed.
