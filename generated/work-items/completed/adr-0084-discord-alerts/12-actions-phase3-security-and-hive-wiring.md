---
name: Phase 3 Emitter Wiring — Hive-Sync, Packet Lifecycle, GitHub Security, Sonar, CodeRabbit
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0084", "wave-4"]
dependencies: ["work-item:05"]
adrs: ["ADR-0084", "ADR-0014", "ADR-0079"]
wave: 4
initiative: adr-0084-discord-alerts
node: honeydrunk-actions
source: strategic
generator: scope
---

# Wire Phase 3 emitters — hive-sync drift, packet lifecycle, GH security alerts, Sonar, CodeRabbit

## Summary
Retrofit the Phase 3 emitter families to call `job-discord-notify.yml` (packet 05) per ADR-0084 D6's routing table: ADR-0014 hive-sync drift findings → `#hive-activity` (Medium); packet lifecycle transitions (`active/` → `completed/`) → `#hive-activity` (Info); PR opened/merged → `#hive-activity` (Info); GitHub Dependabot/CodeQL High+ → `#security-alerts` (High); GitHub secret-scanning hit → `#security-alerts` + `#audit-sensitive` (Critical, multi-channel); SonarCloud quality-gate failure → `#security-alerts` (Medium); CodeRabbit P0/P1 finding → `#security-alerts` (High).

## Target Workflow
**File:** Multiple — hive-sync agent, packet lifecycle hooks, GitHub event-webhook bridge, SonarCloud post-step, CodeRabbit post-step
**Family:** hive-sync, packet-lifecycle, security, code-review

## Motivation
ADR-0084 D6 specifies the routing for each Phase 3 emitter:

- **Hive-sync drift finding (ADR-0014)** → `#hive-activity`, Medium, `🔄 hive-sync: {finding-summary} — {issue-link}`
- **Packet lifecycle transition (`active/` → `completed/`)** → `#hive-activity`, Info, `✅ {packet-slug} completed — {issue-link}`
- **PR opened** → `#hive-activity`, Info, `🆕 {repo}#{pr}: {title} — {pr-link}`
- **PR merged** → `#hive-activity`, Info, `✔️ {repo}#{pr} merged — {pr-link}`
- **GitHub Dependabot / CodeQL High+ alert** → `#security-alerts`, High, `🛡️ {repo}: {alert-summary} — {alert-link}`
- **GitHub secret-scanning hit** → `#security-alerts` + `#audit-sensitive`, Critical (multi-channel), `🛡️🔥 secret detected in {repo} — {alert-link}` (no value)
- **SonarCloud quality-gate failure (main or PR)** → `#security-alerts`, Medium, `📊 SonarCloud gate failed on {repo}#{pr-or-main} — {link}`
- **CodeRabbit P0/P1 finding (ADR-0079)** → `#security-alerts`, High, `🐰 CodeRabbit {severity} on {repo}#{pr} — {pr-link}`

These are the load-bearing Phase 3 wirings per ADR-0084 Follow-up Work *"Phase 3 rollout — wire hive-sync findings, packet lifecycle transitions, GitHub Dependabot / CodeQL / secret-scanning alerts, SonarCloud and CodeRabbit signals."*

## Proposed Change

### 1. Hive-sync drift finding wiring
The hive-sync agent runs per ADR-0014 (likely via OpenClaw scheduled/manual execution per ADR-0081). When it produces a drift finding (a packet that moved without updating `filed-work-items.json`, an ADR status mismatch, an alert-routing-table drift per packet 01, an external-credentials-inventory drift, etc.), it emits a notify via `discord-notify.ps1` (packet 06, home-server side) to `#hive-activity`. If hive-sync execution runs in GitHub Actions instead of on the home server, use `job-discord-notify.yml` — match the live execution surface.

### 2. Packet lifecycle transition wiring
The `hive-sync` agent owns the `active/` → `completed/` packet movement per invariant 37. When it moves a packet, it emits a notify to `#hive-activity` with title `✅ {packet-slug} completed — {issue-link}`. Same execution-surface routing as #1.

### 3. PR opened / merged wiring
Two options per ADR-0084 D5:
- **GitHub repository-webhook → home-server relay (per ADR-0081):** the home server listens for `pull_request` events from each Grid repo and emits a notify via `discord-notify.ps1` per packet 06.
- **GitHub-Actions-on-`pull_request` reusable workflow:** add a tiny workflow (`.github/workflows/job-notify-pr-lifecycle.yml`) that callers invoke from their own `pr-core.yml` on PR open/merge events and that emits a notify via `job-discord-notify.yml`.

The home-server-relay option (per ADR-0081) is the cleaner v1 choice because it does not require every consumer repo to add a workflow call. The reusable-workflow option works if the home-server relay is not yet operational. Choose at packet execution time based on ADR-0081's live state; document the choice in the PR body.

### 4. GitHub Dependabot / CodeQL High+ alert wiring
Add a webhook handler — either on the home server per ADR-0081 (listens for GitHub `security_advisory` / `secret_scanning_alert` / `code_scanning_alert` events) or via a GitHub-Actions workflow scheduled to poll the GitHub Security API per repo per the existing `nightly-security.yml` pattern. The handler filters for severity ≥ High and emits a notify via the appropriate seam to `#security-alerts`. Title `🛡️ {repo}: {alert-summary} — {alert-link}`.

### 5. GitHub secret-scanning hit wiring
Critical-severity multi-channel routing to `#security-alerts` AND `#audit-sensitive`. Two notify calls. The alert-summary text MUST NOT contain the detected secret value — only the path/file location, the secret type ("AWS access key" / "GitHub PAT" / etc.), and the alert link. This is the load-bearing redaction discipline per ADR-0084 D8 and Invariant 8.

### 6. SonarCloud quality-gate failure wiring
SonarCloud emits webhook events on quality-gate failure (configurable in the SonarCloud project's webhook settings). Either (a) a home-server webhook receiver listens and emits a notify via `discord-notify.ps1`, or (b) a workflow polls the SonarCloud API and emits via `job-discord-notify.yml`. Same execution-surface routing as #1. `channel: security-alerts`, `severity: medium`. Title `📊 SonarCloud gate failed on {repo}#{pr-or-main} — {link}`.

### 7. CodeRabbit P0/P1 finding wiring
CodeRabbit emits findings as PR comments per ADR-0079. Wiring requires either (a) a webhook bridge that listens for new CodeRabbit comments and parses the severity, or (b) a CodeRabbit-side rule output that emits to a structured channel the Grid can consume. The cleanest v1 option is the home-server webhook bridge per ADR-0081 — listens for GitHub PR comment events from the CodeRabbit bot account, parses the comment for P0/P1 severity markers per `.coderabbit.yaml` configuration, and emits a notify via `discord-notify.ps1` to `#security-alerts`. `severity: high`. Title `🐰 CodeRabbit {severity} on {repo}#{pr} — {pr-link}`.

### Common shape
All notify steps use `secrets: inherit` (or local secret resolution for home-server-side); use `if: always() && <condition>` for the conditional fire; title/body templates verbatim from ADR-0084 D6's format-hint column.

## Consumer Impact
Some of these wirings (PR opened/merged) may require consumer-repo cooperation if the GitHub-Actions reusable-workflow path is chosen. The home-server-relay path (per ADR-0081) avoids consumer-side changes. Document the chosen path in the PR body.

## Breaking Change?
- [ ] Yes — consumers need to update their caller workflows
- [x] No — backward compatible (additive: new notify wiring; no existing behavior changed)

## Acceptance Criteria
- [ ] Hive-sync agent emits notify to `#hive-activity` with `severity: medium` and title `🔄 hive-sync: {finding-summary} — {issue-link}` on any drift finding
- [ ] Hive-sync agent emits notify to `#hive-activity` with `severity: info` and title `✅ {packet-slug} completed — {issue-link}` when it moves a packet from `active/` to `completed/`
- [ ] PR opened / merged events emit notify to `#hive-activity` with `severity: info`, title matching `🆕 {repo}#{pr}: {title}` for opened or `✔️ {repo}#{pr} merged` for merged, and link to PR HTML URL — via home-server relay per ADR-0081 or reusable-workflow path (document the chosen path in PR body)
- [ ] GitHub Dependabot / CodeQL High+ alerts emit notify to `#security-alerts` with `severity: high` and title `🛡️ {repo}: {alert-summary} — {alert-link}` — via home-server bridge or scheduled-poll workflow (document chosen path)
- [ ] GitHub secret-scanning hits emit notify to **both** `#security-alerts` AND `#audit-sensitive` with `severity: critical`, title `🛡️🔥 secret detected in {repo} — {alert-link}`, and **no detected secret value in the alert-summary text** (per ADR-0084 D8 and Invariant 8)
- [ ] SonarCloud quality-gate failures emit notify to `#security-alerts` with `severity: medium` and title `📊 SonarCloud gate failed on {repo}#{pr-or-main} — {link}` — via home-server webhook bridge or workflow-poll path (document chosen path)
- [ ] CodeRabbit P0/P1 findings emit notify to `#security-alerts` with `severity: high` and title `🐰 CodeRabbit {severity} on {repo}#{pr} — {pr-link}` — via home-server webhook bridge listening for CodeRabbit-bot PR comments parsed against `.coderabbit.yaml` severity markers
- [ ] All notify wirings use the canonical seam for their execution surface (`job-discord-notify.yml` for GitHub Actions emitters; `discord-notify.ps1` for home-server emitters) — never ad-hoc `curl` per ADR-0084 D11
- [ ] The secret-scanning notify wiring is explicitly verified at PR-review time for redaction compliance — the alert-summary template must not interpolate any field that could carry a secret value (only `{repo}`, alert location, secret type, and `{alert-link}`)
- [ ] Per invariant 27, `HoneyDrunk.Actions/CHANGELOG.md` appends to the in-progress version entry documenting Phase 3 emitter wiring
- [ ] `HoneyDrunk.Actions/README.md` (and home-server bridge README if applicable) updated to note Phase 3 emitters
- [ ] All affected workflows pass `actionlint` and the repo's existing CI gate post-edit

## NuGet Dependencies
None. CI workflow + home-server bridge code (if used) is PowerShell / shell, no .NET project changed.

## Boundary Check
- [x] All Actions-side edits in `HoneyDrunk.Actions`.
- [x] Home-server-side edits (if used) target the home-server bridge repo and the `infrastructure/scripts/discord-notify.ps1` helper landed in packet 06.
- [x] No code change in any application Node.
- [x] No catalog change.

## Human Prerequisites
- [ ] If the home-server-relay path is chosen for any wiring (PR lifecycle, GitHub security webhooks, SonarCloud webhook, CodeRabbit bridge), the operator configures the relevant GitHub repository webhooks / SonarCloud webhooks to point at the home-server bridge endpoint before that wiring goes live. Document each configuration step in the PR.
- [ ] After workflow/bridge edits land, manually trigger or wait for natural occurrences of each emitter family at least once to verify the Discord post lands in the expected channel. For the secret-scanning hit verification specifically, **do not introduce a real secret to trigger an alert** — use a fake / canary secret-like string that GitHub's secret-scanning rules will flag for testing, and verify the alert summary does not contain the canary value.

## Referenced ADR Decisions
**ADR-0084 D5 — Alert sources roster.** All seven Phase 3 emitter families are on the v1 roster: hive-sync drift, packet lifecycle, PR opened/merged, GitHub Dependabot/CodeQL, GitHub secret-scanning, SonarCloud, CodeRabbit.

**ADR-0084 D6 — Alert-routing table.** Pins the exact channel + severity + format-hint for each Phase 3 emitter.

**ADR-0084 D8 — Privacy and signal-hygiene rules.** Critical for the secret-scanning wiring: the alert-summary text MUST NOT contain the detected secret value — only metadata. This is non-negotiable.

**ADR-0084 D9 — Implementation seam.** Cloud emitters use `job-discord-notify.yml`; home-server emitters use `discord-notify.ps1`. Both contracts are bit-for-bit equivalent.

**ADR-0084 D11 — New invariant.** Ad-hoc `curl` is forbidden in any seam.

**ADR-0084 Follow-up Work Phase 3.** Names this packet's scope verbatim.

**ADR-0014 — hive-sync agent.** Owns packet lifecycle movement and drift detection. Source of the `#hive-activity` Medium-severity emissions for drift and Info-severity emissions for packet completion.

**ADR-0079 — Multi-perspective PR review stack.** CodeRabbit is a v1 reviewer per ADR-0079 D1; P0/P1 severity classification per `.coderabbit.yaml`.

**ADR-0081 — Home server for local agent infrastructure.** Hosts the webhook bridges (PR lifecycle, GitHub security, SonarCloud, CodeRabbit) per D5 / D7. The home-server-relay path is the cleaner v1 choice for these emitters.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Critical for the secret-scanning wiring per ADR-0084 D8.

**Invariant 37 — Completed work items are moved to `completed/`.** The `hive-sync` agent owns this movement; the notify wiring fires at the movement.

## Constraints
- **Secret-scanning notify text MUST NOT contain detected secret values.** This is the load-bearing constraint of the secret-scanning wiring. The alert-summary template interpolates only `{repo}`, alert location, secret type, and `{alert-link}` — never a field that could carry the secret value itself.
- **Use the canonical seam for each emitter's execution surface.** Document the choice (cloud vs home server) in the PR body for each Phase 3 emitter family.
- **Multi-channel routing requires multiple notify calls.** Secret-scanning hits route to both `#security-alerts` AND `#audit-sensitive`.
- **Title/body templates verbatim from ADR-0084 D6.** Match emojis and placeholder names exactly.
- **Append to in-progress CHANGELOG entry per invariant 27.**
- **Strict PR body discipline.** `Authorship: agent`, `Work Item: <path>`.

## Labels
`ci`, `tier-2`, `ops`, `adr-0084`, `wave-4`

## Agent Handoff

**Objective:** Wire Phase 3 emitters (hive-sync, packet lifecycle, PR lifecycle, GitHub security, SonarCloud, CodeRabbit) to `#hive-activity` / `#security-alerts` / `#audit-sensitive` via the canonical seams.

**Target:** `HoneyDrunk.Actions` (for any GitHub-Actions-side wiring) and home-server bridge code (for any home-server-relay-side wiring per ADR-0081).

**Context:**
- Goal: Surface the high-volume hive-and-security signal classes on glanceable channels separate from the day-to-day ops surface.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 4.
- ADRs: ADR-0084 (D5 roster, D6 routing, D8 secret-redaction, D9 seam, D11 invariant), ADR-0014 (hive-sync), ADR-0079 (CodeRabbit), ADR-0081 (home-server bridges), Invariants 8/27/37.

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:05 (`job-discord-notify.yml` must exist). Work Item:06 (`discord-notify.ps1`) is required for any home-server-side wiring; same-wave so structurally satisfied.

**Constraints:**
- Secret-scanning notify text MUST NOT contain detected secret values.
- Use the canonical seam for each emitter's execution surface.
- Multi-channel routing = multiple notify calls.
- Title/body templates verbatim from ADR-0084 D6.
- Append to in-progress CHANGELOG entry per invariant 27.
- PR body: `Authorship: agent`, `Work Item: <path>`.

**Key Files:**
- Hive-sync agent definition (`.claude/agents/hive-sync.md` or OpenClaw runbook per ADR-0081 — locate at authoring time)
- GitHub event-webhook bridge code (home server per ADR-0081 — locate at authoring time)
- SonarCloud webhook receiver code (home server per ADR-0081 — locate at authoring time)
- CodeRabbit comment-listener bridge code (home server per ADR-0081 — locate at authoring time)
- `.github/workflows/job-notify-pr-lifecycle.yml` (NEW, optional — only if reusable-workflow path is chosen instead of home-server relay)
- `CHANGELOG.md` (append to in-progress entry)
- `README.md`

**Contracts:** None changed at the consumer-API level. Workflow-internal and bridge-internal: seven Phase 3 emitter families now produce Discord posts.
