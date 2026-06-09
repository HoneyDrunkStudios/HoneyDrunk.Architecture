---
name: Home-Server Discord-Notify Helper Script
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "adr-0084", "wave-2"]
dependencies: ["packet:02"]
adrs: ["ADR-0084", "ADR-0081"]
wave: 2
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Ship infrastructure/scripts/discord-notify.ps1 home-server helper

## Summary
Author `infrastructure/scripts/discord-notify.ps1` as the home-server-side equivalent of `job-discord-notify.yml` per ADR-0084 D9. Same input contract (`-Channel`, `-Severity`, `-Title`, `-Body`, `-Link`, `-Metadata`), same redaction pre-check (per ADR-0084 D8), same POST shape — but reads webhook URLs from local secret storage per ADR-0081 D5's machine-secret discipline rather than from GitHub org secrets.

## Context
ADR-0084 D9 explicitly defines two delivery paths: *"GitHub Actions for cloud-CI emitters, home-server helper for local emitters."* Per ADR-0084 D11, **both paths route through their respective seams** — ad-hoc `curl` is forbidden in either environment, and a Discord post from a home-server-hosted automation (the ADR-0044 webhook bridge per ADR-0081, scheduled local OpenClaw runs, manual operator scripts) must call this helper, not the webhook URL directly.

The script is PowerShell because the home server runs Windows per ADR-0081 D2 (or D3, depending on which decision pins OS — ADR-0081 specifies Windows as the host OS for the OpenClaw bridge and scheduled local automations). A Python or Node alternative is conceivable for cross-platform agent use, but PowerShell is the load-bearing choice for the v1 home-server emitter contract. The script-language deferral noted in ADR-0084 D9 (*"TBD shape, likely a one-file Python/Node/PowerShell"*) is resolved here to PowerShell.

The script mirrors the workflow's contract precisely — same input names (PowerShell-cased: `-Channel`, `-Severity`, etc.), same validation, same redaction regex set, same severity decorations, same POST shape. Two seams, one contract; future emitter changes touch both seams in parallel. The cost — *"a reusable workflow plus a home-server helper script is two delivery paths,"* per the ADR's Negative Consequences section — is accepted because GitHub Actions and the home server are the two distinct execution environments and a single seam would require centralizing everything through one or the other.

## Scope
- `infrastructure/scripts/discord-notify.ps1` (NEW) — the helper script.
- `infrastructure/scripts/README.md` (NEW or APPEND) — document the script's contract, the local-secret-storage convention it reads from, and the smoke-test procedure.

## Proposed Implementation
1. Create `infrastructure/scripts/discord-notify.ps1` with the following shape:

   ### Parameters (mirror ADR-0084 D9 inputs in PowerShell idiom)
   - `[Parameter(Mandatory=$true)] [ValidateSet('ops-alerts','security','agent-activity','hive-activity','release','announcements','audit-sensitive')] [string] $Channel`
   - `[Parameter(Mandatory=$true)] [ValidateSet('info','medium','high','critical')] [string] $Severity`
   - `[Parameter(Mandatory=$true)] [string] $Title`
   - `[Parameter(Mandatory=$false)] [string] $Body`
   - `[Parameter(Mandatory=$false)] [string] $Link`
   - `[Parameter(Mandatory=$false)] [string] $Metadata` — JSON string; parsed and validated if provided

   ### Secret resolution per ADR-0081 D5
   The home server stores machine secrets per ADR-0081 D5's discipline (the exact mechanism is Credential Manager / a sealed env-file / Windows DPAPI-encrypted blob — match the live home-server convention as ADR-0081 specifies at packet-06 execution time). The script reads the webhook URL for the requested channel from that store under a key matching the GitHub org-secret name (`DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}`). If the secret is not present locally, the script fails with a clear error: *"Webhook URL for channel {channel} not found in local secret storage. Seed via ADR-0081 D5's procedure before running."*

   ### Redaction pre-check
   Identical regex set to `job-discord-notify.yml` (packet 05):
   - GitHub PAT shapes
   - JWT shape
   - Discord webhook URL itself
   - Generic high-entropy alphanumeric runs adjacent to `token` / `key` / `secret` / `password` keywords
   - AWS access-key
   - Azure connection-string fragments
   - PEM private-key headers
   - Credit-card / SSN shapes

   Fail-closed on match. Emit a clear error message citing ADR-0084 D8 and Invariant 8; do not POST.

   ### Length-truncation and severity decoration
   Identical to `job-discord-notify.yml`: title truncated to 200 chars with ellipsis; body truncated to 4000 chars with `... (truncated)`; severity decoration (`info` no prefix; `medium` `⚠️`; `high` `🔥`; `critical` `🚨`) with matching embed colors.

   ### POST step
   `Invoke-RestMethod -Method Post -Uri $webhookUrl -ContentType 'application/json' -Body $payload`. On non-2xx response, throw with the HTTP status and the response body (response body filtered through the same redaction pre-check). PowerShell's default behavior is to throw on non-2xx, so the script just needs to format the error correctly.

2. Create or append `infrastructure/scripts/README.md` to document:
   - The script's contract (`-Channel`, `-Severity`, `-Title`, `-Body`, `-Link`, `-Metadata` — same as `job-discord-notify.yml`).
   - The local-secret-storage convention the script reads from (with a cross-link to ADR-0081 D5).
   - The smoke-test procedure: run `pwsh ./discord-notify.ps1 -Channel ops-alerts -Severity info -Title "discord-notify.ps1 smoke-test"` from the home server and verify the message lands.
   - The cross-link to `job-discord-notify.yml` as the GitHub-Actions sibling; same contract, two execution paths.

## Affected Files
- `infrastructure/scripts/discord-notify.ps1` (NEW)
- `infrastructure/scripts/README.md` (NEW or APPEND)

## NuGet Dependencies
None. PowerShell script, no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] Script is governance/infrastructure tooling; no Node contract change.

## Acceptance Criteria
- [ ] `infrastructure/scripts/discord-notify.ps1` exists with the six parameters (`-Channel`, `-Severity`, `-Title`, `-Body`, `-Link`, `-Metadata`), `ValidateSet` constraints on `-Channel` and `-Severity` matching ADR-0084 D2's channel taxonomy and D9's severity values
- [ ] The script reads the channel's webhook URL from local secret storage per ADR-0081 D5's machine-secret discipline (the exact mechanism matches the live home-server convention at packet-06 execution time)
- [ ] The redaction pre-check applies the identical regex set as `job-discord-notify.yml` (packet 05), fails-closed on match, cites ADR-0084 D8 and Invariant 8 in the error message
- [ ] Title and body length limits match `job-discord-notify.yml` (200 chars + ellipsis for title; 4000 chars + `... (truncated)` for body)
- [ ] Severity decoration (emoji prefixes and embed colors) matches `job-discord-notify.yml` exactly — `info` no prefix `#3FB950`; `medium` `⚠️` `#D29922`; `high` `🔥` `#FB8500`; `critical` `🚨` `#DA3633`
- [ ] POST uses `Invoke-RestMethod`; non-2xx responses throw with HTTP status + redacted response body
- [ ] `infrastructure/scripts/README.md` exists (or has been amended) to document the script's contract, the local-secret-storage convention, the smoke-test procedure, and the cross-link to `job-discord-notify.yml` as the GitHub-Actions sibling
- [ ] The contract surface (parameter names, validation set, redaction set, output shape) is bit-for-bit equivalent to `job-discord-notify.yml`'s contract — a future emitter change touches both seams in parallel
- [ ] Smoke-test runs successfully when executed manually from the home server post-merge: `pwsh ./discord-notify.ps1 -Channel ops-alerts -Severity info -Title "discord-notify.ps1 smoke-test"` produces a message in `#ops-alerts`

## Human Prerequisites
- [ ] Operator has seeded the seven `DISCORD_WEBHOOK_*` values into the home-server local secret storage per ADR-0081 D5's machine-secret discipline before running the smoke-test. The seven webhook URLs come from packet 02's Discord provisioning; the operator copies each URL from the corresponding GitHub org secret (or directly from Discord) into local storage.
- [ ] Operator runs the smoke-test manually post-merge and documents the result in the PR (success / failure + observed behavior).

## Referenced ADR Decisions
**ADR-0084 D9 — Implementation seam.** *"For emitters outside GitHub Actions (the home-server-hosted ADR-0044 bridge, scheduled local automations per ADR-0081), a small shared helper script (TBD shape, likely a one-file Python/Node/PowerShell that mirrors the workflow's contract) lives in `HoneyDrunk.Architecture/infrastructure/scripts/discord-notify.{ext}` and reads webhook URLs from local secret storage (per ADR-0081 D5's machine-secret discipline). Same contract, same redaction rules, two delivery paths — GitHub Actions for cloud-CI emitters, home-server helper for local emitters."* This packet resolves the language deferral to PowerShell (the home server's native shell per ADR-0081).

**ADR-0084 D8 — Privacy and signal-hygiene rules.** The redaction pre-check in this script is the enforcement point at the home-server emitter boundary, identical to the `job-discord-notify.yml` enforcement point on the GitHub-Actions side. Same regex set, same fail-closed discipline.

**ADR-0084 D11 — New invariant.** Ad-hoc `curl` (or `Invoke-RestMethod` against a webhook URL) outside this script is forbidden on the home server, parallel to the GitHub-Actions-side prohibition. The two-seam boundary is what allows the Hedge-posture swap per ADR-0080 D2 — a future Slack/Mattermost/Matrix migration edits two files (`job-discord-notify.yml` + `discord-notify.ps1`), not every emitter site.

**ADR-0081 D5 — Machine-secret discipline.** The home server stores machine secrets via Credential Manager / sealed env-file / DPAPI-encrypted blob (match the live mechanism at packet execution time). The script reads webhook URLs from that store under keys matching the GitHub org-secret naming pattern (`DISCORD_WEBHOOK_{CHANNEL_UPPER_SNAKE}`).

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Extends to webhook payloads per ADR-0084 D8. The redaction pre-check enforces this at the home-server emitter boundary.

## Constraints
- **Contract bit-for-bit equivalent to `job-discord-notify.yml`.** Parameter names, validation set, redaction regex set, severity decoration, length truncation, error shape — all identical to packet 05's workflow contract. A future change to one seam triggers a parallel change to the other; do not let them drift.
- **PowerShell, not Python or Node.** The ADR-0084 D9 language deferral resolves to PowerShell here because the home server is Windows per ADR-0081. A Python alternative is acceptable as a follow-up if cross-platform agent use becomes load-bearing; not v1.
- **Read from local secret storage per ADR-0081 D5.** Do not hardcode webhook URLs in the script, do not read from a file in plaintext, do not fall back to GitHub-org-secret resolution (those are workflow-side; the home server does not have access to them).
- **Fail-closed redaction.** Identical to the workflow side; do not soften to "redact and continue."
- **No webhook URL value in the script or README.** Reference URLs by location (local secret-storage slot) but never by value. Same Invariant 8 discipline as the workflow.
- **Strict PR body discipline.** `Authorship: agent`, `Packet: <path>`.

## Labels
`chore`, `tier-2`, `meta`, `ops`, `adr-0084`, `wave-2`

## Agent Handoff

**Objective:** Ship `infrastructure/scripts/discord-notify.ps1` as the home-server-side equivalent of `job-discord-notify.yml` per ADR-0084 D9. Bit-for-bit contract equivalence to packet 05's workflow.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the home-server emitter seam so local automations (ADR-0044 bridge, scheduled OpenClaw runs, manual operator scripts per ADR-0081) have a single canonical seam to call.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 2.
- ADRs: ADR-0084 (D8, D9, D11), ADR-0081 (D5 — machine-secret discipline; home-server OS pins PowerShell), Invariant 8 (secret-redaction discipline).

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:02 (the seven webhooks must exist before the script can be smoke-tested with real secret values).

**Constraints:**
- Contract bit-for-bit equivalent to `job-discord-notify.yml` (packet 05). Do not let the seams drift.
- PowerShell (not Python or Node) — resolves the ADR-0084 D9 language deferral against the ADR-0081 home-server OS.
- Read webhook URLs from local secret storage per ADR-0081 D5; no hardcoding, no plaintext file, no GitHub-org-secret fallback.
- Fail-closed redaction.
- No webhook URL value in the script or README — Invariant 8 discipline.
- PR body: `Authorship: agent`, `Packet: <path>`.

**Key Files:**
- `infrastructure/scripts/discord-notify.ps1` (NEW)
- `infrastructure/scripts/README.md` (NEW or APPEND)
- `.github/workflows/job-discord-notify.yml` in `HoneyDrunk.Actions` (read-only reference for contract equivalence)

**Contracts:**
- New helper-script contract: parameters (`-Channel`, `-Severity`, `-Title`, `-Body`, `-Link`, `-Metadata`), local-secret resolution per ADR-0081 D5, fail-closed redaction per ADR-0084 D8. Contract equivalent to `job-discord-notify.yml`.
