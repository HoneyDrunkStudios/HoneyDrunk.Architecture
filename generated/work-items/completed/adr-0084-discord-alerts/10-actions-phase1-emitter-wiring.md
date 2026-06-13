---
name: Phase 1 Emitter Wiring — CI, Release, NuGet, Cron, ADR-0083 Escalation
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0084", "wave-4"]
dependencies: ["work-item:05"]
external_dependencies: ["HoneyDrunkStudios/HoneyDrunk.Actions#{adr-0083-packet-05-issue-number}"]
adrs: ["ADR-0084", "ADR-0083", "ADR-0033", "ADR-0034", "ADR-0012"]
wave: 4
initiative: adr-0084-discord-alerts
node: honeydrunk-actions
source: strategic
generator: scope
---

# Wire Phase 1 emitters to job-discord-notify.yml

## Summary
Retrofit the Phase 1 emitter families to call `job-discord-notify.yml` (packet 05) per ADR-0084 D6's routing table: CI failure on `main`, deploy events (ADR-0033 success/failure), NuGet publish (ADR-0034 success/failure), scheduled-workflow failures (nightly-deps, nightly-security, hive-field-mirror, weekly-governance, external-credentials-check, grid-health aggregator), and ADR-0083 credential-rotation escalation (T-30 / T-7 / T+0).

## Target Workflow
**File:** Multiple — every workflow listed below gains a `job-discord-notify` call site
**Family:** pr-core (CI-on-main side), release, nightly-deps, nightly-security, hive-field-mirror, weekly-governance, external-credentials-check, grid-health aggregator

## Motivation
ADR-0084 D6 specifies the routing for each of these emitter families:

- **CI failure on `main`** → `#ops-alerts`, High severity
- **Deploy success (ADR-0033)** → `#release`, Info
- **Deploy failure (ADR-0033)** → `#ops-alerts` + `#release`, High (multi-channel)
- **NuGet publish success (ADR-0034)** → `#release`, Info
- **NuGet publish failure (ADR-0034)** → `#ops-alerts` + `#release`, High (multi-channel)
- **Scheduled workflow failure (cron)** → `#ops-alerts`, Medium
- **Credential rotation T-30 (ADR-0083)** → `#ops-alerts`, Medium
- **Credential rotation T-7 (ADR-0083)** → `#ops-alerts` + `#security-alerts`, High (multi-channel)
- **Credential rotation T+0 (ADR-0083)** → `#security-alerts` + `#audit-sensitive`, Critical (multi-channel)

These are the load-bearing Phase 1 wirings per ADR-0084 Follow-up Work *"Phase 1 rollout — wire CI failure on `main`, release events, NuGet publishes, scheduled-workflow failures, and the ADR-0083 credential-rotation escalation to `job-discord-notify.yml`. One packet per emitter family."* This packet handles all of Phase 1 as a single workflow-edit packet because the changes are mechanically uniform (each emitter is one workflow edit adding a post-step that calls `job-discord-notify.yml` with the routing-table-specified `channel` and `severity`). If review-cycle volume justifies splitting per emitter family, do so at PR-authoring time; the packet's acceptance criteria are satisfied either by one PR covering all eight emitters or by eight PRs covering one emitter each — the load-bearing concern is that all eight emitter families end up wired by packet-10 closure.

## Proposed Change
For each emitter family, add a post-step (or a job-level `needs:`-dependent job) to the relevant workflow(s) that calls `job-discord-notify.yml` with the routing-table-specified `channel` and `severity`. The exact post-step shape:

```yaml
notify-discord:
  needs: <preceding-job-id>
  if: always() && <condition matching the emitter trigger>
  uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-discord-notify.yml@main
  with:
    channel: <channel-per-routing-table>
    severity: <severity-per-routing-table>
    title: <emitter-specific-title-template>
    body: <emitter-specific-body-template>
    link: <emitter-specific-link>
    metadata: <emitter-specific-JSON-metadata>
  secrets: inherit
```

### Per-emitter wiring

**1. CI failure on `main` (HoneyDrunk.Actions/.github/workflows/pr-core.yml or its `push: main` sibling)** — add a `notify-discord` job that runs on workflow failure when the trigger event was `push` to `main`. `channel: ops-alerts`, `severity: high`. Title format per ADR-0084 D6: `❌ {repo} / {workflow}: {commit-short} — {link-to-run}`.

**2. Deploy events (HoneyDrunk.Actions/.github/workflows/release.yml or the per-Node `job-deploy-*.yml` reusable workflows per ADR-0033)** — add two notify steps: one on deploy success (`channel: release`, `severity: info`, title `🚀 {node} {tag} → {env} ({duration})`), one on deploy failure (multi-channel: post to both `release` and `ops-alerts`, `severity: high`, title `🔥 {node} {tag} → {env} FAILED — {link-to-run}`). Multi-channel wiring means two `job-discord-notify` calls with different `channel` inputs.

**3. NuGet publish (HoneyDrunk.Actions/.github/workflows/job-publish-nuget.yml per ADR-0034)** — same pattern as deploy events: success (`channel: release`, `severity: info`, title `📦 {package} {version} published to nuget.org`); failure (multi-channel: `release` and `ops-alerts`, `severity: high`, title `📦❌ {package} {version} publish failed — {link-to-run}`).

**4. Scheduled-workflow failures** — for each of `nightly-deps.yml`, `nightly-security.yml`, `hive-field-mirror.yml`, `weekly-governance.yml`, `external-credentials-check.yml`, and the `grid-health aggregator` workflow per ADR-0012 D6, add a notify step that fires on failure. `channel: ops-alerts`, `severity: medium`. Title format `🕒❌ {workflow} ({schedule}) — {link-to-run}`.

**5. ADR-0083 credential-rotation escalation (HoneyDrunk.Actions/.github/workflows/external-credentials-check.yml)** — this is the forcing-function wiring. ADR-0083 packet 05 ships the workflow scaffold (cron + parser + escalator + gh-issue-comment emission) WITHOUT Discord branches; this packet adds the three notify-discord call sites by editing `external-credentials-check.yml` directly. The workflow scans `infrastructure/reference/sensitive-inventory.md` (packet 03 + ADR-0083 packet 01) and emits at three cadence points based on each credential's expiration date:
   - **T-30** (≤30 days to expiration): `channel: ops-alerts`, `severity: medium`. Title `🔑 {credential} expires in 30 days — {rotation-walkthrough-link}`.
   - **T-7** (≤7 days to expiration): two notify calls — `channel: ops-alerts` AND `channel: security-alerts`, `severity: high`. Title `🔑⚠️ {credential} expires in 7 days — {rotation-walkthrough-link}`.
   - **T+0** (expired): two notify calls — `channel: security-alerts` AND `channel: audit-sensitive`, `severity: critical`. Title `🔑🔥 {credential} EXPIRED — {incident-record-link}`.

   The three notify-discord call sites are added as steps after each of the existing T-30 / T-7 / T+0 escalation steps in `external-credentials-check.yml`. Use `secrets: inherit` so the seven `DISCORD_WEBHOOK_*` org secrets resolve through. **No conditional "if workflow does not exist, skip" branch** — the `external_dependencies:` entry hard-binds this packet to ADR-0083 packet 05; if ADR-0083 packet 05 has not merged, this packet PR fails fast and surfaces the cross-initiative ordering violation.

### Idempotency / re-fire behavior
For scheduled-workflow failures and credential-rotation escalations, each cron run that observes the same condition will fire a notify call — there is no de-duplication at v1 per ADR-0084 D8's deferred v2 concerns. Operator-acceptable noise; revisit at v2 if the cadence becomes load-bearing.

### Permissions
Per invariant 39, every caller workflow must declare `permissions:` as a superset of `job-discord-notify.yml`'s declared permissions. `job-discord-notify.yml` declares `permissions: {}` (per packet 05), so any caller permissions block is a trivially-satisfied superset — no new permissions are needed in the caller workflows for the Discord post itself.

## Consumer Impact
This packet retrofits emitter workflows within `HoneyDrunk.Actions`. Consumer repos calling these workflows transitively gain the Discord notifications — no consumer-side workflow edit required because the notify step is internal to the called workflow. The `secrets: inherit` in the notify-job declaration handles secret propagation from the caller's org-secret context.

## Breaking Change?
- [ ] Yes — consumers need to update their caller workflows
- [x] No — backward compatible (additive: new notify steps; existing workflow behavior unchanged except for the additional Discord post)

## Acceptance Criteria
- [ ] CI-on-main workflow(s) carry a `notify-discord` step that fires on failure when `push: main` was the trigger, with `channel: ops-alerts`, `severity: high`, and title matching `❌ {repo} / {workflow}: {commit-short} — {link-to-run}`
- [ ] Deploy workflow (`release.yml` or per-Node `job-deploy-*.yml`) carries two notify steps — success (`channel: release`, `severity: info`) and failure (multi-channel `release` + `ops-alerts`, `severity: high`)
- [ ] NuGet-publish workflow (`job-publish-nuget.yml`) carries two notify steps — success (`channel: release`, `severity: info`) and failure (multi-channel `release` + `ops-alerts`, `severity: high`)
- [ ] Six scheduled-workflow files each carry a notify-on-failure step (`channel: ops-alerts`, `severity: medium`): `nightly-deps.yml`, `nightly-security.yml`, `hive-field-mirror.yml`, `weekly-governance.yml`, `external-credentials-check.yml` (if it exists), and the grid-health aggregator workflow per ADR-0012 D6
- [ ] `external-credentials-check.yml` (pre-existing per ADR-0083 packet 05) is edited to add three escalation notify calls per the T-30 / T-7 / T+0 routing — multi-channel for T-7 (ops-alerts + security-alerts) and T+0 (security-alerts + audit-sensitive). **No conditional deferral** — the PR opens against a tree where ADR-0083 packet 05 has already merged. If the workflow does not exist, the PR fails fast and surfaces the cross-initiative ordering violation
- [ ] Every `notify-discord` job uses `secrets: inherit` to receive the `DISCORD_WEBHOOK_*` org secrets from the caller's org-secret context
- [ ] Every `notify-discord` call uses `if: always() && <condition>` so the notify fires regardless of preceding-job exit code (success-vs-failure routing is handled by the `<condition>` clause)
- [ ] Title and body templates match ADR-0084 D6's format-hint column verbatim for each emitter family (emoji prefixes, placeholder variable names)
- [ ] Per invariant 27, `HoneyDrunk.Actions/CHANGELOG.md` gains an append to the in-progress version entry (the version was bumped by packet 05) documenting Phase 1 emitter wiring
- [ ] `HoneyDrunk.Actions/README.md` updated to note that affected workflows now emit Discord notifications via `job-discord-notify.yml`
- [ ] All affected workflows pass `actionlint` and the repo's existing CI gate post-edit
- [ ] No ad-hoc `curl` to any `DISCORD_WEBHOOK_*` URL introduced in any workflow per ADR-0084 D11

## NuGet Dependencies
None. CI workflow, no .NET project changed.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`.
- [x] No code change in any other repo.
- [x] Adopting workflows are existing `HoneyDrunk.Actions` reusable / cron workflows; the notify-step retrofit is an additive change.

## Human Prerequisites
- [ ] After workflow edits land, manually trigger a synthetic failure or test cron run for each emitter family at least once to verify the Discord post lands in the expected channel. Document the verification results in the PR before merge.
- [ ] For the ADR-0083 credential-rotation escalation wiring (T-30 / T-7 / T+0), `external-credentials-check.yml` MUST exist at packet-10 execution time per the hard external dependency on ADR-0083 packet 05. If it does not exist, fail fast and surface the cross-initiative ordering violation — do not soft-defer.

## Referenced ADR Decisions
**ADR-0084 D6 — Alert-routing table.** Pins the exact channel + severity + format-hint for each emitter family. This packet wires each emitter to its routing-table-specified destination.

**ADR-0084 D9 — Implementation seam.** Every CI emitter routes through `job-discord-notify.yml`. This packet is the wiring side of D9 for Phase 1 emitter families.

**ADR-0084 D11 — New invariant.** Every operator-actionable Grid event must publish via `job-discord-notify.yml` (or the home-server helper). Ad-hoc `curl` is forbidden. This packet enforces the new invariant by adding `job-discord-notify` calls (not by adding `curl` posts) to every affected workflow.

**ADR-0084 D5 — Alert sources roster.** CI failure on `main`, deploy events, NuGet publishes, scheduled-workflow failures, ADR-0083 credential-rotation escalation — all five emitter families are on the v1 roster. This packet is the wiring of those roster entries.

**ADR-0083 D5 — Escalation cadence.** T-30 / T-7 / T+0 against credential expiration dates. The Discord destination for this cadence is the forcing function of ADR-0084; this packet wires it by editing the `external-credentials-check.yml` workflow ADR-0083 packet 05 ships. Hard external dependency on ADR-0083 packet 05.

**ADR-0033 — Environment-gated deploy trigger model.** Deploy success/failure events per environment (dev/staging/prod). This packet routes them to `#release` (success) or `#release` + `#ops-alerts` (failure).

**ADR-0034 — Public package distribution.** NuGet publish events. This packet routes them to `#release` (success) or `#release` + `#ops-alerts` (failure).

**ADR-0012 D6 — Grid Health aggregator.** Daily aggregator workflow that posts a state-of-the-Grid view. This packet routes its failures (the aggregator's own workflow failure, not the drift findings it reports) to `#ops-alerts`.

**ADR-0012 D7 — Real-time per-failure notification.** Email notification still operates per ADR-0012 D7. Discord notification is additive per ADR-0084 D1's "complementary surface" framing for ADR-0012 D6/D7.

**Invariant 38 — Reusable workflows invoke tool CLIs directly.** This packet calls `job-discord-notify.yml` via `workflow_call`; the workflow itself calls `curl` directly per its own contract. No marketplace-action wrapping introduced.

**Invariant 39 — Caller workflows declare `permissions:` superset.** `job-discord-notify.yml` declares `permissions: {}`; every caller's `permissions:` block is trivially a superset.

**Invariant 27 — All projects in a solution share one version and move together.** `HoneyDrunk.Actions` is not a .NET solution (it is a workflow repo), but the invariant's CHANGELOG-cadence discipline applies — the first packet on the repo in this initiative (packet 05) bumped the version; this packet appends to the in-progress entry.

## Constraints
- **Use `workflow_call` to `job-discord-notify.yml`, never `curl`.** Per ADR-0084 D11. The reusable-workflow boundary is what allows the Hedge-posture swap per ADR-0080 D2.
- **`secrets: inherit` in every notify-job declaration.** Caller's org-secret context propagates the seven `DISCORD_WEBHOOK_*` secrets through.
- **Title/body templates verbatim from ADR-0084 D6's format-hint column.** Match emoji prefixes and placeholder variable names exactly.
- **Multi-channel routing requires multiple notify-job declarations.** Deploy failure / NuGet publish failure / T-7 / T+0 all route to multiple channels; one `job-discord-notify` call per channel.
- **External-credentials-check escalation wiring is non-optional.** Hard external dependency on ADR-0083 packet 05; the workflow MUST exist when this packet runs. No conditional defer. If the workflow is missing, the cross-initiative ordering has been violated; surface and fix it before opening this PR.
- **Append to in-progress CHANGELOG entry per invariant 27.** Packet 05 bumped the version; this packet appends.
- **Strict PR body discipline.** `Authorship: agent`, `Work Item: <path>`.

## Labels
`ci`, `tier-2`, `ops`, `adr-0084`, `wave-4`

## Agent Handoff

**Objective:** Wire Phase 1 emitter families (CI failure on `main`, deploy events, NuGet publishes, scheduled-workflow failures, ADR-0083 credential-rotation escalation) to `job-discord-notify.yml` per ADR-0084 D6's routing table.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ship the load-bearing Phase 1 emitter wiring so the forcing-function ADR-0083 D5 escalation cadence has a saliency-appropriate destination, plus the high-frequency operator-facing CI/release/NuGet/cron signals.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 4.
- ADRs: ADR-0084 (D5 roster, D6 routing, D9 seam, D11 invariant), ADR-0083 (D5 escalation cadence — forcing function), ADR-0033 (deploy events), ADR-0034 (NuGet publishes), ADR-0012 (D6 grid-health aggregator, D7 email-notification cadence), Invariant 27 (CHANGELOG cadence — append to in-progress entry), Invariants 38/39 (direct CLI / caller-permissions superset).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:05` (`job-discord-notify.yml` must exist before emitters can call it).
- External: `HoneyDrunkStudios/HoneyDrunk.Actions#{adr-0083-packet-05-issue-number}` — `external-credentials-check.yml` workflow must already exist; this packet edits it to add the T-30/T-7/T+0 notify-discord call sites. Operator fills in the real issue number at file time.

**Constraints:**
- Use `workflow_call` to `job-discord-notify.yml`, never `curl` (ADR-0084 D11).
- `secrets: inherit` in every notify-job.
- Title/body templates verbatim from ADR-0084 D6.
- Multi-channel routing = multiple notify-job declarations.
- External-credentials-check escalation wiring is non-optional — hard external dependency on ADR-0083 packet 05.
- Append to in-progress CHANGELOG entry per invariant 27.
- PR body: `Authorship: agent`, `Work Item: <path>`.

**Key Files:**
- `.github/workflows/pr-core.yml` (or its `push: main` sibling)
- `.github/workflows/release.yml` (or per-Node `job-deploy-*.yml` per ADR-0033)
- `.github/workflows/job-publish-nuget.yml`
- `.github/workflows/nightly-deps.yml`
- `.github/workflows/nightly-security.yml`
- `.github/workflows/hive-field-mirror.yml`
- `.github/workflows/weekly-governance.yml`
- `.github/workflows/external-credentials-check.yml` (edit — adds T-30 / T-7 / T+0 notify-discord call sites; hard dep on ADR-0083 packet 05)
- Grid Health aggregator workflow (per ADR-0012 D6 — locate at packet-10 authoring time)
- `CHANGELOG.md` (append to in-progress entry)
- `README.md` (note Discord emission)

**Contracts:** None changed at the consumer-API level. Workflow-internal: every emitter family now produces a Discord post in addition to its pre-existing notification surfaces.
