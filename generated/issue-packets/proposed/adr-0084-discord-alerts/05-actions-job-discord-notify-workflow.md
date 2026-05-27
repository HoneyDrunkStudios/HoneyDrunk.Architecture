---
name: job-discord-notify.yml Reusable Workflow
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0084", "wave-2"]
dependencies: ["packet:02"]
adrs: ["ADR-0084"]
wave: 2
initiative: adr-0084-discord-alerts
node: honeydrunk-actions
source: strategic
generator: scope
---

# Ship HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml

## Summary
Create the `job-discord-notify.yml` reusable workflow in `HoneyDrunk.Actions` per ADR-0084 D9. It is the single CI-side seam every emitter routes through for Discord posts. Inputs: `channel`, `severity`, `title`, optional `body`, optional `link`, optional `metadata` (JSON). Applies the ADR-0084 D8 redaction pre-check at the formatting boundary, then POSTs to the correct `DISCORD_WEBHOOK_*` secret.

## Target Workflow
**File:** `.github/workflows/job-discord-notify.yml`
**Family:** shared / reusable — called via `workflow_call` from every CI emitter

## Motivation
ADR-0084 D9 specifies that **every CI emitter routes through this workflow**; ad-hoc `curl` to webhook URLs in arbitrary workflows is forbidden per ADR-0084 D11. The reusable-workflow boundary is what allows: consistent message formatting across emitters, the D8 redaction pre-check applied at one place (not at every emitter site), and vendor-posture swap per ADR-0080 D2 (Discord → Slack / Mattermost / Matrix / Teams is a workflow-internal change, not a per-emitter rewrite).

This workflow is the load-bearing artifact for Wave 4 emitter rollout (packets 10–13). It must exist and pass smoke-tests before any emitter retrofit begins.

## Proposed Change
Add `.github/workflows/job-discord-notify.yml` with the following shape:

### Inputs (per ADR-0084 D9)
- `channel` (required, string): one of `ops-alerts`, `security-alerts`, `agent-activity`, `hive-activity`, `release`, `announcements`, `audit-sensitive` — selects which `DISCORD_WEBHOOK_*` secret to use. Validate at workflow start; reject unknown values with a clear error.
- `severity` (required, string): one of `info`, `medium`, `high`, `critical` — selects which emoji/color decoration. Validate at workflow start; reject unknown values.
- `title` (required, string): short one-line summary. Length-limited (Discord embed title cap is 256 chars; truncate with ellipsis at 200 to leave headroom).
- `body` (optional, string): longer text rendered as the embed `description`. Length-limited per Discord's 4096-char description cap; truncate at 4000 with `... (truncated)`.
- `link` (optional, string): URL the alert points at. If provided, rendered as the embed `url` so the title is clickable.
- `metadata` (optional, string — JSON): structured fields rendered as an embed footer or fields. If provided, must parse as JSON; reject malformed JSON with a clear error.

### Secrets (called workflow consumes via `secrets:`)
- `DISCORD_WEBHOOK_OPS_ALERTS`
- `DISCORD_WEBHOOK_SECURITY_ALERTS`
- `DISCORD_WEBHOOK_AGENT_ACTIVITY`
- `DISCORD_WEBHOOK_HIVE_ACTIVITY`
- `DISCORD_WEBHOOK_RELEASE`
- `DISCORD_WEBHOOK_ANNOUNCEMENTS`
- `DISCORD_WEBHOOK_AUDIT_SENSITIVE`

Use `secrets: inherit` from caller workflows. The `audit-sensitive` channel's secret is only available to repos selected for it per packet 02; callers from public repos passing `channel: audit-sensitive` will fail at secret resolution, which is correct.

### Redaction pre-check (per ADR-0084 D8)
Before formatting the payload, scan `title` + `body` + `metadata` for patterns matching common secret shapes. Reject with a clear error (and a `::error::` annotation) on match. Patterns to detect at minimum:
- GitHub PAT (`ghp_[A-Za-z0-9]{36,}`, `gho_...`, `ghu_...`, `ghs_...`, `ghr_...`)
- Generic JWT shape (`eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`)
- Discord webhook URL itself (`https://discord(?:app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+`) — emitters must never echo a webhook URL into a notification payload
- Generic API-key-shape heuristics (a high-entropy alphanumeric run of 32+ chars adjacent to common token keywords like `token`, `key`, `secret`, `password`)
- AWS access-key (`AKIA[0-9A-Z]{16}`)
- Azure-style connection-string fragments (`AccountKey=`, `SharedAccessKey=`)
- Base64-encoded PEM-header shapes (`-----BEGIN [A-Z ]+ PRIVATE KEY-----`)
- Standard credit-card / SSN regexes (defense-in-depth against accidentally piping customer data)

The pre-check is **fail-closed**: a match aborts the post and emits a `::error::` annotation citing ADR-0084 D8 + Invariant 8. The operator inspects the workflow log to identify the leak source. This is the same redaction-discipline shape `VaultTelemetry` uses (ADR-0084 D8: *"same redaction discipline as VaultTelemetry"*).

### Severity decoration
- `info` → green embed color (`#3FB950`), no emoji prefix beyond what the caller provides in `title`
- `medium` → yellow embed color (`#D29922`), `⚠️` prefix added to title if not already present
- `high` → orange embed color (`#FB8500`), `🔥` prefix added to title if not already present
- `critical` → red embed color (`#DA3633`), `🚨` prefix added to title if not already present

### POST step
Use `curl` directly (per Invariant 38 — reusable workflows invoke tool CLIs directly, no third-party marketplace action wrappers). POST to the resolved webhook URL with the JSON-formatted embed payload. On non-2xx response, fail the job with a clear error showing HTTP status + response body (response body redacted per the pre-check rules — same regex set applied to the response).

### Permissions
The workflow needs no special GitHub permissions — Discord POST is HTTP-only. Declare `permissions: {}` (empty) at the workflow level per invariant 39 (caller workflows must declare a superset; an empty superset is trivially satisfied).

### Smoke-test
After workflow lands, manually trigger via `workflow_dispatch` from a temporary caller in `HoneyDrunk.Architecture` or `HoneyDrunk.Actions`:
1. POST with `channel: ops-alerts`, `severity: info`, `title: "job-discord-notify smoke-test"` — verify message lands in `#ops-alerts`.
2. POST with `channel: ops-alerts`, `severity: info`, `title: "Smoke: token=ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"` — verify the workflow fails with the secret-pattern detection error and the message does NOT land in Discord.
3. Repeat (1) for each of the seven channels to confirm secret routing works for all of them.

## Consumer Impact
No consumers yet at packet-05 landing. Wave 4 emitter retrofits (packets 10–13) become the first consumers.

## Breaking Change?
- [ ] Yes — consumers need to update their caller workflows
- [x] No — backward compatible (additive: new reusable workflow with no existing consumers)

## Acceptance Criteria
- [ ] `.github/workflows/job-discord-notify.yml` exists, declares `on: workflow_call:` with the six inputs (`channel`, `severity`, `title`, `body`, `link`, `metadata`) and seven `secrets:` entries per ADR-0084 D4's naming
- [ ] Input validation rejects unknown `channel` values, unknown `severity` values, and malformed `metadata` JSON with clear error messages
- [ ] Redaction pre-check is implemented as a single step before formatting, applies the regex set listed in Proposed Change, fails-closed on match, emits a `::error::` annotation citing ADR-0084 D8 and Invariant 8
- [ ] Title length truncated to 200 chars with ellipsis; body length truncated to 4000 chars with `... (truncated)` suffix
- [ ] Severity decoration applies the four embed colors (`#3FB950` / `#D29922` / `#FB8500` / `#DA3633`) and emoji prefixes (`⚠️` / `🔥` / `🚨` for medium / high / critical; no prefix for info)
- [ ] POST step uses `curl` directly (per invariant 38) — no third-party marketplace action wrapping
- [ ] Workflow declares `permissions: {}` at the workflow level
- [ ] Smoke-test path documented in the workflow's leading comment block (3-step procedure: simple post / secret-pattern rejection / all-seven-channel routing)
- [ ] All three smoke-test cases pass when manually triggered after merge
- [ ] `HoneyDrunk.Actions/CHANGELOG.md` carries a new version entry for this addition per invariant 27 (first packet in the initiative to land on `HoneyDrunk.Actions` bumps the version)
- [ ] `HoneyDrunk.Actions/README.md` updated to document `job-discord-notify.yml` as a new reusable workflow in the workflow listing
- [ ] `HoneyDrunk.Actions/docs/consumer-usage.md` (if it exists) updated with `job-discord-notify.yml` usage example

## NuGet Dependencies
None. CI workflow, no .NET project changed.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any other repo.
- [x] Reusable workflow is the canonical CI-side seam per ADR-0084 D9; consumers in other repos call it but are not modified by this packet.

## Human Prerequisites
- [ ] After workflow lands, manually trigger the three smoke-test cases (simple post / secret-pattern rejection / all-seven-channel routing) and verify in Discord that each case produces the expected outcome. Document the smoke-test results in the PR before merge.

## Referenced ADR Decisions
**ADR-0084 D9 — Implementation seam.** Single reusable workflow `job-discord-notify.yml` per ADR-0012 reusable-workflow pattern. Inputs `channel`, `severity`, `title`, `body`, `link`, `metadata`. Handles message formatting consistently across emitters, applies D8 redaction at the formatting boundary, POSTs to the correct webhook URL. **Every CI emitter routes through this workflow; ad-hoc `curl` to webhook URLs in arbitrary workflows is forbidden per the v1 invariant in D11.**

**ADR-0084 D8 — Privacy and signal-hygiene rules.** Non-negotiable at the alert-payload level: no secret values, no customer PII, no full stack traces. Enforced by the same secret-redaction discipline as `VaultTelemetry`. The redaction pre-check in this workflow is the enforcement point for the "no secret values" clause; "no customer PII" and "no full stack traces" are emitter-side concerns the pre-check cannot fully enforce (a stack trace is a structural shape, not a regex pattern), but heuristic patterns (the `-----BEGIN PRIVATE KEY-----` and `AccountKey=` shapes) catch the most common accidental leaks.

**ADR-0084 D11 — New invariant.** *"Ad-hoc `curl` to a Discord webhook URL outside the reusable workflow / helper script is forbidden — the reusable-workflow boundary is what allows redaction, formatting consistency, and vendor-posture swap per ADR-0080 D2."* This workflow IS the reusable-workflow boundary.

**ADR-0080 D2 — Vendor-posture table.** Discord assigned **Hedge (active)** with named hedges; the `job-discord-notify.yml` workflow IS the single Grid-side seam that bounds the exit cost to days. A future Slack/Mattermost/Matrix swap edits this workflow (and the per-channel secret names), not every emitter.

**ADR-0012 D4 / Invariant 38 — Reusable workflows invoke tool CLIs directly.** This workflow uses `curl` for the POST step, not a third-party marketplace `discord-action@vX` wrapper. The reusable-workflow boundary is what we own; wrapping `curl` in a marketplace action adds a third-party dependency where none is needed.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Extends to webhook payloads per ADR-0084 D8. The redaction pre-check in this workflow is the enforcement point at the GitHub-Actions emitter boundary.

**Invariant 39 — Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions.** This workflow declares `permissions: {}` (empty), so any caller's `permissions:` block is a trivially-satisfied superset.

## Constraints
- **Reusable-workflow boundary is load-bearing.** Per ADR-0084 D11, this workflow is the ONLY allowed path for CI-side Discord posts. Future emitter packets (10–13) call this workflow; do not author ad-hoc `curl` posts in any caller.
- **Fail-closed redaction.** The pre-check aborts the post on regex match. Do not soften this to a warning or to "redact and continue" — the failure mode is a leaked secret in chat, which is irreversible; a noisy CI failure is the correct trade.
- **Direct `curl` invocation, no marketplace action wrapping** per invariant 38.
- **`permissions: {}` at workflow level** per invariant 39 (the workflow needs no GitHub API permissions).
- **Per invariant 27, this is the first packet to land on `HoneyDrunk.Actions` in this initiative — bump the version in `HoneyDrunk.Actions/CHANGELOG.md`.** Subsequent packets (10–13) append to the in-progress version entry.
- **README and consumer-usage.md updates** per the repo's existing CHANGELOG/README discipline.
- **Strict PR body discipline.** `Authorship: agent`, `Packet: <path>`.

## Labels
`ci`, `tier-2`, `ops`, `adr-0084`, `wave-2`

## Agent Handoff

**Objective:** Ship `job-discord-notify.yml` as the canonical CI-side seam for all Discord operator-alert posts per ADR-0084 D9 / D11.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Land the reusable workflow so Wave 4 emitter rollout (packets 10–13) has a single canonical seam to call.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 2.
- ADRs: ADR-0084 (D8 redaction, D9 implementation, D11 invariant), ADR-0080 D2 (Hedge posture — this seam IS the swap boundary), ADR-0012 D4 + Invariant 38 (direct CLI invocation), Invariant 8 (secret-redaction discipline), Invariant 39 (caller permissions superset).

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:02 (the seven webhooks and secrets must exist before the workflow can resolve them and the smoke-tests can run).

**Constraints:**
- Reusable-workflow boundary is load-bearing per ADR-0084 D11 — this workflow is the ONLY allowed path for CI-side Discord posts.
- Fail-closed redaction; do not soften to "redact and continue."
- Direct `curl`, no marketplace action wrapping per invariant 38.
- `permissions: {}` at workflow level per invariant 39.
- First packet to land on `HoneyDrunk.Actions` in this initiative — bump the version in `HoneyDrunk.Actions/CHANGELOG.md` per invariant 27.
- README and consumer-usage.md updated per the repo's CHANGELOG/README discipline.
- PR body: `Authorship: agent`, `Packet: <path>`.

**Key Files:**
- `.github/workflows/job-discord-notify.yml` (NEW)
- `CHANGELOG.md` (version bump)
- `README.md` (workflow listing)
- `docs/consumer-usage.md` (if it exists — usage example)

**Contracts:**
- New reusable workflow contract: inputs (`channel`, `severity`, `title`, `body`, `link`, `metadata`), secrets (seven `DISCORD_WEBHOOK_*`), no GitHub permissions required, fail-closed on redaction violations.
