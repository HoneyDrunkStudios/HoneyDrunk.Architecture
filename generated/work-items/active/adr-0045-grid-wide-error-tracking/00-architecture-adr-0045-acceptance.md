---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0045", "wave-1"]
dependencies: ["Architecture#ADR0040-PACKET00"]
adrs: ["ADR-0045", "ADR-0040"]
accepts: ["ADR-0045"]
wave: 1
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-architecture
---

# Accept ADR-0045 — flip status, add the error-flow invariant, register the initiative

## Summary
Flip ADR-0045 (Grid-Wide Error Tracking) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the one new error-flow invariant ADR-0045 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0045-grid-wide-error-tracking` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0045 makes **errors** a fourth Grid signal type alongside traces, metrics, and logs from ADR-0040, and was revised in PR #164 to pivot to **Application Insights' Failures + exception tracking** as the v1 backend (Sentry becomes the documented D11 escalation path). The ADR decides:

- **D1** — errors are a fourth Grid signal type with first-class error-tracking semantics (problem grouping, release tracking, fingerprinting). Errors are not logs.
- **D2** — backend v1 is Application Insights' Failures + exception tracking, captured into the **same App Insights resource** ADR-0040 provisions. No new vendor, no new billing line.
- **D3** — errors flow through `HoneyDrunk.Pulse` via a new `IErrorReporter` **facade** in `HoneyDrunk.Telemetry.Abstractions`, layered over Pulse's **existing `IErrorSink`** (it does not duplicate it). The error connector uses the App Insights .NET SDK (a carve-out from ADR-0040's OTLP-only path, because the App Insights error model carries non-OTLP fields — `problem_id`, `application_Version`, custom dimensions for Failures-blade grouping).
- **D4** — cross-link between errors, traces, and logs is native via the shared `operation_id`; no configured integration needed on the App Insights path.
- **D5** — per-Node opt-in via Pulse telemetry configuration; `HoneyDrunk.Notify`'s existing Sentry usage is **migrated** onto `IErrorReporter` (removed, not extended).
- **D6** — release tracking via the `application_Version` property; the Actions deploy workflows call the App Insights release annotations API.
- **D7** — PII / tenant-scoping carve-outs: `tenant_id` allowed, `user_id` pseudonymous (`PrincipalId`), prompt/completion text forbidden by default per ADR-0040 D9's carve-out, common PII patterns scrubbed by a regex processor.
- **D8** — the capture-an-error-vs-log-a-line policy.
- **D9** — cost: near-zero v1 contribution; within ADR-0040's $100/month ceiling.
- **D10** — four-phase rollout: abstraction + Notify migration → deployable Nodes → AI-sector standup → escalation evaluation.
- **D11** — documented escalation path to Sentry (via the existing `HoneyDrunk.Telemetry.Sink.Sentry` package) with four explicit triggers.
- **D12** — Pulse synthetic monitoring is not an error source (a synthetic probe failure → metric/log, not an exception; errors come from application code paths).
- **D13** — relationship to ADR-0010 (preserved — Observe untouched), ADR-0040 (extended), and the Notify-Sentry setup (removed).

ADR-0045 is a **policy / decision** ADR. The concrete code — the `IErrorReporter` facade and its types in `HoneyDrunk.Telemetry.Abstractions`, the App Insights error-capture backing in `HoneyDrunk.Telemetry.Sink.AzureMonitor`, the Notify migration, the Actions release-annotation step — lands in the implementing packets (02–06). Catalog updates land as packet 01.

Every other packet in this initiative references ADR-0045's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Cross-Initiative Dependency — ADR-0040
ADR-0045 is a sibling observability ADR built on the same Azure Monitor backend, pivoted in the same PR (#164). Its `dependencies:` frontmatter references **ADR-0040's acceptance packet** (packet 00 of `adr-0040-telemetry-backend-and-retention`). That cross-initiative reference must be expressed as a `{Repo}#N` qualified edge once ADR-0040's packets are filed and their issue numbers are known. **Until ADR-0040 packet 00 has a GitHub issue number, leave the placeholder `Architecture#ADR0040-PACKET00` in this packet's `dependencies:` and replace it with the real `Architecture#<n>` before this folder is pushed to `main`** — `work-item:NN` edges only resolve *within the same initiative folder*, so a same-folder ordinal cannot point at ADR-0040. The ADR-0040 dependency is for invariant-numbering hygiene only — see the invariant-numbering note below.

## Invariant Numbering
The verified current maximum invariant number in `constitution/invariants.md` is **51**. ADR-0045 adds exactly **one** invariant; its **pre-reserved number is 80** — pre-allocated as part of a 12-ADR batch (ADR-0045 is one ADR in that batch; numbers 52–80+ are reserved across the batch even though the file currently tops out at 51). Append invariant 80 to `constitution/invariants.md`. Do **not** assume any `## Telemetry Invariants` section exists — ADR-0040's packets may not have landed yet. Append the invariant in an appropriate section (an existing observability/Ops-flavoured section, or create a new section if none fits). Add this batch note in or beside the invariant: *"Invariant 80 is pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift upward, never reuse."*

## Scope
- `adrs/ADR-0045-grid-wide-error-tracking.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0045 row Status column to Accepted.
- `constitution/invariants.md` — add the one new error-flow invariant ADR-0045 commits (see Proposed Implementation for exact text) as **invariant 80** (pre-reserved — see Invariant Numbering above).
- `initiatives/active-initiatives.md` — register the `adr-0045-grid-wide-error-tracking` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0045 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0045 index row in `adrs/README.md` to Accepted.
3. Add one new invariant to `constitution/invariants.md` as **invariant 80**. The text, taken verbatim-in-substance from ADR-0045's Consequences "Invariants" subsection:
   - **Errors captured for the capture-eligible cases (ADR-0045 D8) flow through `IErrorReporter`, never via a direct backend SDK call.** This preserves backend reversibility (the D11 Sentry escalation) and the centralized PII-scrubbing surface. Secret values must never survive scrubbing into a captured exception — this invariant **references** invariant 8 ("Secret values never appear in logs, traces, exceptions, or telemetry") rather than restating it.
   - Number it **80** (pre-reserved — see Invariant Numbering). Append it; do not renumber any existing invariant. Do not assume a `## Telemetry Invariants` section exists — append under an appropriate existing section, or create one. Include the batch note: *"Invariant 80 is pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift upward, never reuse."*
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0045-grid-wide-error-tracking.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0045 header reads `**Status:** Accepted`
- [ ] The ADR-0045 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the one new error-flow invariant (errors flow through `IErrorReporter`, never a direct backend SDK call) as **invariant 80**, citing ADR-0045, referencing (not restating) invariant 8, and carrying the pre-reservation batch note
- [ ] `initiatives/active-initiatives.md` registers the `adr-0045-grid-wide-error-tracking` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0045 D3 — Errors flow through Pulse; `IErrorReporter` is a facade over `IErrorSink`.** A new `IErrorReporter` facade in `HoneyDrunk.Telemetry.Abstractions`, layered over Pulse's existing `IErrorSink` — it adds ambient-context capture and breadcrumb/scope ergonomics, it does not duplicate the sink contract. The App Insights connector for errors uses the App Insights .NET SDK and extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package (a carve-out from ADR-0040's OTLP-only path). A future backend swap (Sentry per D11, via the existing `HoneyDrunk.Telemetry.Sink.Sentry`) is a configuration change.

**ADR-0045 Consequences — Invariants.** ADR-0045 adds exactly one invariant: errors captured for the D8 capture-eligible cases flow through `IErrorReporter`, never via a direct backend SDK call. Reserved number 80.

**Invariant 8 (referenced) — Secret values never appear in logs, traces, exceptions, or telemetry.** The error-flow invariant references invariant 8: scrubbing must never let a secret survive into a captured exception.

## Constraints
- **Acceptance precedes flip.** ADR-0045 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant number 80.** Append the one new invariant as number 80 (pre-reserved). Do not renumber existing invariants. Do not assume a `## Telemetry Invariants` section exists; append under an appropriate section or create one. Include the batch note.
- **Reference, do not restate, invariant 8.** The error-flow invariant references invariant 8 (secrets never in telemetry) — write them as complementary.
- **Replace the placeholder dependency.** `Architecture#ADR0040-PACKET00` is a placeholder; substitute the real `Architecture#<issue-number>` once ADR-0040's packets are filed and before this folder is pushed.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0045`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0045 to Accepted, add the error-flow invariant to `constitution/invariants.md`, and register the error-tracking initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0045 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 1.
- ADRs: ADR-0045 (primary), ADR-0040 (the telemetry backend ADR-0045 extends), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- ADR-0040 packet 00 (cross-initiative) — sibling observability ADR; the edge exists for invariant-numbering hygiene within the 12-ADR batch. Express as `Architecture#<issue-number>` once filed.

**Constraints:**
- Acceptance precedes flip — ADR-0045 stays Proposed until this PR merges.
- Append the one new invariant as **number 80** (pre-reserved); do not renumber existing invariants; do not assume a `## Telemetry Invariants` section exists; include the batch note.
- The error-flow invariant references invariant 8 (secrets never in telemetry) — it does not restate it.

**Key Files:**
- `adrs/ADR-0045-grid-wide-error-tracking.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
