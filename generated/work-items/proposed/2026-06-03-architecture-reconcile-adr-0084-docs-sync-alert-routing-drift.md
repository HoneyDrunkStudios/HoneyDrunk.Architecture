---
title: Reconcile ADR-0084 docs-sync alert-routing drift
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
wave: 1
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
tier: 2
labels: ["chore", "tier-2", "meta", "adr-0084", "hive-sync", "strategic"]
dependencies: []
adrs: ["ADR-0084", "ADR-0085", "ADR-0014"]
source: strategic
generator: scope
---

# Reconcile ADR-0084 docs-sync alert-routing drift

## Summary

Resolve the hive-sync drift finding where the live alert-routing table includes the ADR-0085 docs-sync run-report row but ADR-0084 D6 does not, so the Architecture repo has one clear rule for whether post-acceptance alert-routing rows are expected live-only additions or ADR-table drift.

## Context

The 2026-06-03 hive-sync drift report surfaces:

- Category 15: alert-routing-table drift
- Item: live-only row for ADR-0085 docs-sync run report to `#hive-activity`
- Detail: the row exists in `constitution/alert-routing.md` but not ADR-0084 D6

ADR-0084 D6 says the ADR table is the committed-shape snapshot and the operational reference copy lives in `constitution/alert-routing.md`. The live file also says new alert sources land in `constitution/alert-routing.md` under ADR-0084 D10, not by editing the ADR table. That leaves a drift-semantics gap: hive-sync reports the docs-sync row as drift even though the live routing document appears to allow post-acceptance live rows.

This packet is scoped to Architecture because the affected surfaces are ADR prose, the constitution alert-routing reference, and hive-sync drift semantics. It does not touch HoneyDrunk.Actions, docs-sync runtime code, Discord webhooks, or any external service.

## Scope

- Inspect ADR-0084 D6 and D10, `constitution/alert-routing.md`, `initiatives/drift-report.md`, and the hive-sync drift logic or documented check that compares the ADR table to the live table.
- Reconcile the docs-sync row so future hive-sync output does not repeatedly report an expected live-only routing row as unexplained drift.
- Preserve ADR-0084's operator-alert safety boundary: Discord routing must go through the approved seam, and payloads must never include secret values, customer PII, or full stack traces.
- If resolving the drift requires a real policy choice that is not already decided by ADR-0084 or ADR-0085, stop and convert the work into a small ADR amendment proposal instead of silently choosing.

## Acceptance Criteria

- [ ] The ADR-0085 docs-sync run-report routing row is either explicitly governed as an allowed live-table addition or reconciled into the ADR-0084 committed-shape surface, with the reason documented.
- [ ] `constitution/alert-routing.md` and ADR-0084 D6/D10 no longer give conflicting instructions about whether new post-acceptance alert sources should be mirrored into the ADR table.
- [ ] The hive-sync drift behavior or its documented expected output no longer treats the ADR-0085 docs-sync row as an unexplained Category 15 drift item.
- [ ] No Discord webhook URL, secret value, customer PII, or full stack trace is copied into any changed file, generated report, or PR body.
- [ ] If implementation changes shipped behavior in Architecture automation, the repo-level changelog is updated according to the Architecture repo convention; documentation-only clarification may omit a changelog entry if that is the local convention.

## Human Prerequisites

None.

## Dependencies

None.

## Labels

- chore
- tier-2
- meta
- adr-0084
- hive-sync
- strategic

## Agent Handoff

**Objective:** Reconcile the ADR-0084 alert-routing drift semantics for the ADR-0085 docs-sync row.

**Target:** HoneyDrunkStudios/HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: ADR-0043 strategic backlog cleanup from accepted-decision drift.
- Feature: Keep ADR-0084 operator-alert routing governance and live routing references coherent.
- ADRs: ADR-0084, ADR-0085, ADR-0014.

**Acceptance Criteria:**
- [ ] The ADR-0085 docs-sync row is no longer surfaced as unexplained alert-routing drift.
- [ ] The committed ADR snapshot, live routing table, and hive-sync drift semantics are mutually consistent.
- [ ] No secret values, webhook URLs, customer PII, or full stack traces appear in the diff or PR body.

**Dependencies:**
- None.

**Constraints:**
- ADR-0084 D6: the alert-routing table pins v1 routing, while `constitution/alert-routing.md` is the operational reference copy.
- ADR-0084 D10: new alert sources require a row in the routing table or its `alert-routing.md` successor, the caller must pass a concrete channel and severity to the approved notification seam, and high-volume sources need a suppression rule.
- Grid invariant 107: Every operator-actionable Grid event publishes to Discord via `HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml` for GitHub Actions emitters or the ADR-0086 runner's Key Vault-resolved path for non-Actions emitters. No Discord channel may receive secret values, customer PII, or full stack traces. Ad-hoc `curl` to a Discord webhook URL outside those seams is forbidden.
- Grid invariant 8: Secret values never appear in logs, traces, exceptions, or telemetry. This packet extends that discipline to generated reports and PR prose.
- Architecture repo boundary: this repo owns ADRs, constitution files, routing rules, catalogs, generated work items, and agent workflow governance. Do not implement docs-sync runtime behavior in another repo under this packet.

**Key Files:**
- `adrs/ADR-0084-discord-operator-alerts-surface.md`
- `constitution/alert-routing.md`
- `initiatives/drift-report.md`
- Hive-sync drift-check implementation or documentation, if present in this repo

**Contracts:**
- No public code contract changes are expected.
