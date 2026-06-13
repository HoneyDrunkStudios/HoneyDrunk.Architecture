---
name: Sensitive Inventory — Discord Rows
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0084", "wave-2"]
dependencies: ["work-item:02"]
external_dependencies: ["HoneyDrunkStudios/HoneyDrunk.Architecture#{adr-0083-packet-01-issue-number}"]
adrs: ["ADR-0084", "ADR-0083"]
wave: 2
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

<!-- Operator: fill in the real ADR-0083 packet 01 issue number in `external_dependencies` once ADR-0083 has been
     filed. ADR-0083 packet 01 ships `infrastructure/reference/sensitive-inventory.md`; this packet appends seven
     Discord webhook rows to it. The file MUST already exist before this packet runs. Per the cross-initiative
     ordering constraint in the dispatch plan, ADR-0084 is promoted to `active/` first; once filed, the operator
     updates ADR-0083 packets 05 and 06 with real ADR-0084 issue numbers; then ADR-0083 is promoted and packet 01
     files; this packet then runs against the existing `sensitive-inventory.md`. -->

# Append seven Discord webhook rows to infrastructure/reference/sensitive-inventory.md

## Summary
Append seven new rows to `infrastructure/reference/sensitive-inventory.md` — one per Discord webhook URL provisioned in packet 02 — using **ADR-0083 D2's canonical column set** (Name | Kind | Provider | Where Stored | Bound To | Rotates | Expiration Cadence | Current Expiration | Rotation Procedure | Use Cases | Blast Radius if Missed | Owner | Notes). Each row carries `Kind: webhook-signing-secret`, `Rotates: no`, `Expiration Cadence: n/a — non-expiring (rotate on suspected compromise only)`, owner solo-dev, blast-radius prose per channel, and a pointer at the rotation walkthrough (which lands in packet 04).

## Context
ADR-0084 D4 explicitly classifies each Discord webhook URL as an external-SaaS credential per ADR-0083: *"Each Discord webhook URL is an external-SaaS credential per ADR-0083 and lands in `infrastructure/reference/sensitive-inventory.md` as seven inventory rows."* Discord webhook URLs have no provider-imposed expiration; they remain valid until manually revoked. The inventory rows therefore carry a non-expiring cadence but still appear in the inventory because they are external-SaaS credentials by every other property — bound to a Discord-resource principal, stored as GitHub org secrets, with a real blast radius if leaked.

**Cross-initiative coupling with ADR-0083.** This packet has a hard external dependency on ADR-0083 packet 01 (the inventory-seed packet). The file `infrastructure/reference/sensitive-inventory.md` MUST already exist when this packet runs. Per the cross-initiative ordering constraint in both dispatch plans, the operator promotes ADR-0084 to `active/` first, but ADR-0083 packet 01 must merge to `main` before this packet 03 PR is opened. There is no "create file if missing" branch — the file is created exactly once, by ADR-0083 packet 01.

## Scope
- `infrastructure/reference/sensitive-inventory.md` — **append** seven rows (the file must already exist per ADR-0083 packet 01; this packet does NOT create it).

## Proposed Implementation
1. Read the existing `infrastructure/reference/sensitive-inventory.md` (landed by ADR-0083 packet 01). Verify the table header matches ADR-0083 D2's canonical thirteen-column set: `Name | Kind | Provider | Where Stored | Bound To | Rotates | Expiration Cadence | Current Expiration | Rotation Procedure | Use Cases | Blast Radius if Missed | Owner | Notes`. If the column set has drifted from ADR-0083 D2, stop and surface the drift — do not silently re-map columns.

2. Append the seven Discord rows under the existing table, in this order (matching the ADR-0084 D4 listing order):

   | Name | Kind | Provider | Where Stored | Bound To | Rotates | Expiration Cadence | Current Expiration | Rotation Procedure | Use Cases | Blast Radius if Missed | Owner | Notes |
   |---|---|---|---|---|---|---|---|---|---|---|---|---|
   | `DISCORD_WEBHOOK_OPS_ALERTS` | `webhook-signing-secret` | Discord | GitHub org secret (`HoneyDrunkStudios`) | Discord channel `#ops-alerts` webhook | `no` | n/a — non-expiring (rotate on suspected compromise only) | n/a | `infrastructure/walkthroughs/discord-webhook-rotation.md` | CI failure on `main`, scheduled-workflow failures, deploy/release failure escalation, credential-rotation T-30 (ADR-0083) via `job-discord-notify.yml` (packet 05) | Leaked URL enables anonymous POST to `#ops-alerts` — alert-channel pollution and possible op-misdirection, not data exfiltration | solo-dev | Stored as GitHub org secret per ADR-0084 D4 |
   | `DISCORD_WEBHOOK_SECURITY_ALERTS` | `webhook-signing-secret` | Discord | GitHub org secret (`HoneyDrunkStudios`) | Discord channel `#security-alerts` webhook | `no` | n/a — non-expiring (rotate on suspected compromise only) | n/a | `infrastructure/walkthroughs/discord-webhook-rotation.md` | Dependabot/CodeQL/secret-scanning/Sonar/CodeRabbit emitter wiring (packet 12); credential-rotation T-7 / T+0 (ADR-0083) via `job-discord-notify.yml` | Leaked URL enables anonymous POST to `#security-alerts` — alert-channel pollution and possible op-misdirection of security signals, not data exfiltration | solo-dev | Stored as GitHub org secret per ADR-0084 D4 |
   | `DISCORD_WEBHOOK_AGENT_ACTIVITY` | `webhook-signing-secret` | Discord | GitHub org secret (`HoneyDrunkStudios`) | Discord channel `#agent-activity` webhook | `no` | n/a — non-expiring (rotate on suspected compromise only) | n/a | `infrastructure/walkthroughs/discord-webhook-rotation.md` | ADR-0044/ADR-0046 review-pipeline emitter wiring (packet 11) | Leaked URL enables anonymous POST to `#agent-activity` — channel pollution risk; agent-activity signals do not carry secrets per ADR-0084 D8 | solo-dev | Stored as GitHub org secret per ADR-0084 D4 |
   | `DISCORD_WEBHOOK_HIVE_ACTIVITY` | `webhook-signing-secret` | Discord | GitHub org secret (`HoneyDrunkStudios`) | Discord channel `#hive-activity` webhook | `no` | n/a — non-expiring (rotate on suspected compromise only) | n/a | `infrastructure/walkthroughs/discord-webhook-rotation.md` | hive-sync + packet-lifecycle + PR-lifecycle emitter wiring (packet 12) | Leaked URL enables anonymous POST to `#hive-activity` — channel pollution risk; PR/issue/hive-sync signals do not carry secrets per ADR-0084 D8 | solo-dev | Stored as GitHub org secret per ADR-0084 D4 |
   | `DISCORD_WEBHOOK_RELEASE` | `webhook-signing-secret` | Discord | GitHub org secret (`HoneyDrunkStudios`) | Discord channel `#release` webhook | `no` | n/a — non-expiring (rotate on suspected compromise only) | n/a | `infrastructure/walkthroughs/discord-webhook-rotation.md` | NuGet-publish + deploy-event emitter wiring (packet 10) | Leaked URL enables anonymous POST to `#release` — channel pollution risk; release events do not carry secrets per ADR-0084 D8 | solo-dev | Stored as GitHub org secret per ADR-0084 D4 |
   | `DISCORD_WEBHOOK_ANNOUNCEMENTS` | `webhook-signing-secret` | Discord | GitHub org secret (`HoneyDrunkStudios`) | Discord channel `#announcements` webhook | `no` | n/a — non-expiring (rotate on suspected compromise only) | n/a | `infrastructure/walkthroughs/discord-webhook-rotation.md` | Operator-authored announcements via the rotation-walkthrough's smoke-test path | Leaked URL enables anonymous POST to `#announcements` — most-public-eventual channel per ADR-0084 D2's v1-operator-only-but-eventually-community-facing framing; brand-damage risk if leaked URL is used to post hostile content; rotate immediately on suspected compromise | solo-dev | Stored as GitHub org secret per ADR-0084 D4 |
   | `DISCORD_WEBHOOK_AUDIT_SENSITIVE` | `webhook-signing-secret` | Discord | GitHub org secret (`HoneyDrunkStudios`, `Repository access: Selected repositories`) | Discord channel `#audit-sensitive` webhook | `no` | n/a — non-expiring (rotate on suspected compromise only) | n/a | `infrastructure/walkthroughs/discord-webhook-rotation.md` | ADR-0083 credential-rotation T+0 escalation + ADR-0030 audit-anomaly emitters | Leaked URL enables anonymous POST to `#audit-sensitive` — private channel; anomaly-channel pollution and possible misdirection of audit-anomaly signals; secret values still never appear per ADR-0084 D8, so leaked URL does not enable data exfiltration even via tampered posts | solo-dev | `Repository access: Selected repositories` — Architecture / Vault / Audit / other private repos only — not exposed to public-repo workflows per ADR-0084 D4 |

   For each row, populate cells using inline `<br>`-separated bullets where multi-line content is needed inside a cell (matching the format ADR-0083 packet 01 establishes for the SonarCloud / NuGet / GitHub-PAT rows). Do not break rows across multiple Markdown table rows — the schema-check sub-step in `external-credentials-check.yml` (ADR-0083 packet 05) depends on one Markdown table row per inventory entry.

3. If the existing preamble in `sensitive-inventory.md` lists the ADRs that govern subsets of rows, append a one-liner noting that the seven Discord webhook rows are governed by ADR-0084 and that rotation is governed by `infrastructure/walkthroughs/discord-webhook-rotation.md` (which lands in packet 04).

## Affected Files
- `infrastructure/reference/sensitive-inventory.md` (APPEND only — the file must already exist per ADR-0083 packet 01)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] Inventory file is governance documentation, not Node contract; no catalog change.

## Acceptance Criteria
- [ ] `infrastructure/reference/sensitive-inventory.md` exists (pre-existing per ADR-0083 packet 01) and now contains seven new rows matching the seven Discord webhook secrets from ADR-0084 D4 (exact secret names: `DISCORD_WEBHOOK_OPS_ALERTS`, `DISCORD_WEBHOOK_SECURITY_ALERTS`, `DISCORD_WEBHOOK_AGENT_ACTIVITY`, `DISCORD_WEBHOOK_HIVE_ACTIVITY`, `DISCORD_WEBHOOK_RELEASE`, `DISCORD_WEBHOOK_ANNOUNCEMENTS`, `DISCORD_WEBHOOK_AUDIT_SENSITIVE`)
- [ ] Each row carries the full ADR-0083 D2 thirteen-column set (`Name | Kind | Provider | Where Stored | Bound To | Rotates | Expiration Cadence | Current Expiration | Rotation Procedure | Use Cases | Blast Radius if Missed | Owner | Notes`) — not a subset
- [ ] Each row has `Kind: webhook-signing-secret`, `Provider: Discord`, `Rotates: no`, `Expiration Cadence: n/a — non-expiring (rotate on suspected compromise only)`, and `Current Expiration: n/a`
- [ ] Each row's `Rotation Procedure` column points at `infrastructure/walkthroughs/discord-webhook-rotation.md`
- [ ] Each row carries channel-specific blast-radius prose (not boilerplate) — the prose distinguishes the public-channel-pollution risk of `#ops-alerts` / `#security-alerts` / `#agent-activity` / `#hive-activity` / `#release` from the brand-damage risk of `#announcements` and the private-channel risk of `#audit-sensitive`
- [ ] The `DISCORD_WEBHOOK_AUDIT_SENSITIVE` row's Notes column explicitly states `Repository access: Selected repositories` per ADR-0084 D4
- [ ] No webhook URL appears in the file — only credential names, Kind, Provider, store location, binding, cadence, expiration, walkthrough pointer, use cases, blast-radius prose, owner, and notes (per Invariant 8 and ADR-0084 D8)
- [ ] **No "create file if missing" branch executed** — if the file does not exist, the PR fails fast and the operator surfaces the ordering violation (ADR-0083 packet 01 must merge first)
- [ ] The format of the seven new rows is parseable by ADR-0083 packet 05's schema-check sub-step (one Markdown row per entry; multi-line content uses inline `<br>` or `<ul>`/`<li>`)

## Human Prerequisites
None — packet 02 (the human-only provisioning) is a hard `dependencies:` entry. ADR-0083 packet 01 is a hard `external_dependencies:` entry. By packet-03 execution time, the seven secrets and seven webhooks already exist and the inventory file already exists; this packet only documents the seven Discord rows in the inventory.

## Referenced ADR Decisions
**ADR-0084 D4 — Webhook URL storage.** Each Discord webhook URL is an external-SaaS credential per ADR-0083 D1's CI/ops-machinery category. Lands in `infrastructure/reference/sensitive-inventory.md` as seven inventory rows. Discord webhook URLs have no provider-imposed expiration — they remain valid until manually revoked. The inventory rows therefore carry `Expiration Cadence: n/a — non-expiring (rotate on suspected compromise only)`. The `#audit-sensitive` webhook secret has `Repository access: Selected repositories` per the same decision.

**ADR-0083 D1 — External-SaaS credential categorization.** Discord webhooks fall into the CI/ops-machinery category — bound to a Discord-resource principal, stored as GitHub org secrets, with a real blast radius if leaked. They appear in the inventory because they are external-SaaS credentials by every property except cadence.

**ADR-0083 D2 — Inventory format.** Canonical thirteen-column set: `Name | Kind | Provider | Where Stored | Bound To | Rotates | Expiration Cadence | Current Expiration | Rotation Procedure | Use Cases | Blast Radius if Missed | Owner | Notes`. The seven Discord rows conform to this set verbatim.

**ADR-0084 D8 — Privacy and signal-hygiene rules.** Webhook URLs are secret values per Invariant 8. They never appear in the inventory file — only credential names and metadata.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Extends to inventory files per ADR-0084 D8 — webhook URLs are not pasted into `sensitive-inventory.md`.

## Constraints
- **No webhook URLs in the file.** Only credential names, owner, cadence, expiration, walkthrough pointer, blast-radius prose, and notes. The URL values live exclusively in GitHub org secrets.
- **Match ADR-0083 D2's canonical column set verbatim.** Do not invent a shorter or wider column set; the seven Discord rows compose into the same table other inventory rows occupy.
- **APPEND only — do not create the file.** ADR-0083 packet 01 creates the file. If the file does not exist when this packet runs, the cross-initiative ordering has been violated; fail fast and surface the violation.
- **Strict PR body discipline.** `Authorship: agent`, `Work Item: <path>`.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0084`, `wave-2`

## Agent Handoff

**Objective:** Append seven Discord webhook rows to `infrastructure/reference/sensitive-inventory.md` using ADR-0083 D2's canonical thirteen-column set.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the seven Discord webhooks as inventory rows so they are tracked under the same governance ADR-0083 D2 specifies for every external-SaaS credential.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 2.
- ADRs: ADR-0084 (D4, D8), ADR-0083 (D1, D2 — format), Invariant 8 (secret values never in files).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` (the seven secrets and webhooks must exist before the inventory describes them).
- External: `HoneyDrunkStudios/HoneyDrunk.Architecture#{adr-0083-packet-01-issue-number}` — ADR-0083 packet 01 creates `infrastructure/reference/sensitive-inventory.md`; this packet appends to it. Operator fills in the real issue number at file time.

**Constraints:**
- No webhook URLs in the file — only credential names and metadata.
- Match ADR-0083 D2's canonical thirteen-column set verbatim.
- APPEND only — do not create the file. If it does not exist, the cross-initiative ordering has been violated; fail fast.
- PR body: `Authorship: agent`, `Work Item: <path>`.

**Key Files:**
- `infrastructure/reference/sensitive-inventory.md` (APPEND only)
- `adrs/ADR-0084-discord-operator-alerts-surface.md` (read-only reference for the seven secret names and channel taxonomy)
- `adrs/ADR-0083-external-saas-credential-rotation.md` (read-only reference for the inventory column structure)

**Contracts:** None changed.
