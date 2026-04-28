---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-1", "meta", "docs", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-architecture
---

# Feature: Author GitHub profile notifications runbook (`infrastructure/github-notifications.md`)

## Summary
Author a short runbook at `infrastructure/github-notifications.md` documenting how the solo operator configures GitHub Settings → Notifications → Actions → "Only notify for failed workflows" so that real-time per-failure notification (ADR-0012 D7) is in place. The runbook walks through the portal UI clicks, screenshots optional, and explains the division of responsibility between D7 (real-time, per-failure email) and D6 (daily aggregated `🕸️ Grid Health` issue).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0012 D7 names GitHub profile notifications as a mandatory mechanism: real-time per-failure email at the moment a workflow run fails. Without it, mid-day failures are invisible until the next D6 aggregator run up to 24 hours later. The setting is a one-time per-account configuration that the operator clicks in the GitHub Settings UI — but until it is documented, the convention is a tribal-knowledge dependency. Per the user convention "Prefers Azure Portal over CLI / portal walkthroughs over CLI commands," the runbook is structured as a portal click-walkthrough with section headers matching the actual GitHub UI label hierarchy.

This is the runbook the ADR's Follow-up Work section explicitly calls out: "Document the GitHub profile notification setup (D7) in a short runbook at `HoneyDrunk.Architecture/infrastructure/github-notifications.md`. Trivial, one-time."

## Scope

A single new file in the Architecture repo. No code. No secrets.

### `infrastructure/github-notifications.md`

The file structure should follow the same pattern as the existing `infrastructure/*` walkthroughs (`oidc-federated-credentials.md`, `key-vault-creation.md`, etc.). Required sections:

**Front matter (or header section):**
- Purpose (one-line)
- Audience (solo operator + future on-call humans)
- Scope (this is per-GitHub-account, not per-org / per-repo)
- Last verified date

**Body sections:**

1. **Why this matters.** Two short paragraphs:
   - The two-mechanism model — D7 = real-time email, D6 = daily aggregated `🕸️ Grid Health` issue. Reference invariant 40 (post-acceptance numbering from packet 01) and ADR-0012 D6/D7.
   - The mid-day failure scenario this covers. A failed workflow at 11:00 fires email at 11:00; the next D6 aggregator pass would not surface it until 03:30 UTC the next morning.

2. **Step-by-step portal walkthrough.** Numbered list with the actual UI label hierarchy GitHub uses today (verify against the live UI when authoring; GitHub Settings UI labels drift):
   1. Open https://github.com/settings/notifications
   2. Scroll to **Actions**
   3. Under **Notifications for workflow runs on repositories you're watching, or for workflows you've triggered**, there are two sub-checkboxes: **Email** and **Web and Mobile**. Confirm Email is enabled.
   4. Under that section, the dropdown labeled **Only notify for failed workflows** must be selected (the other options are "Send notifications for all workflows" and similar — the failed-only option is the load-bearing setting).
   5. Confirm the email address chosen for notifications under **Custom routing** (if applicable) routes to the operator's primary inbox.
   6. Scroll to **Watching** and confirm the operator is watching every `HoneyDrunkStudios/*` repo (repository-level watch is what makes the Actions notification fire for that repo).
   
   Each step gets a short rationale sentence. Screenshots are optional but encouraged if the agent has access to the actual UI; the walkthrough must be readable and actionable without screenshots.

3. **Verification.** A short procedure to confirm the setting is in place:
   - Trigger a deliberate failure: e.g. push a branch with a syntax error in `pr-core.yml` to a sandbox repo (or use an existing failing-workflow test fixture if one exists).
   - Within ~1 minute of the run completing, the operator's inbox receives an email with subject pattern matching the existing GitHub Actions notification format (`[HoneyDrunkStudios/<repo>] Run failed: ...`).
   - If no email arrives within 5 minutes: re-check the Watching list, then re-check the dropdown selection.

4. **Multi-operator note (forward-looking).** A one-paragraph stub acknowledging that today HoneyDrunk Studios is one operator, and that when operations grow beyond one human, the team-wide approach is either Slack/Discord webhook integration on the D6 aggregator, or a per-operator copy of this walkthrough. Defer the design decision; just name it.

5. **References:**
   - ADR-0012 D7 — bound link to the ADR section.
   - Invariant 40 (post-acceptance numbering — written as "invariant 40" in the doc body; if packet 01 hasn't merged yet, the doc author leaves a `<!-- pending acceptance: invariant 40 -->` comment until 01 lands and updates this doc).
   - Cross-link to the eventual `🕸️ Grid Health` issue once packet 04 ships and the issue exists.

### `infrastructure/README.md`

Add the new walkthrough to the existing index. Match the existing row format used for other walkthroughs (file name + one-liner).

## Affected Files
- `infrastructure/github-notifications.md` (new)
- `infrastructure/README.md` (index update)
- `CHANGELOG.md` (one-line entry — Architecture repo CHANGELOG is at the repo root)

## NuGet Dependencies
None. Docs only.

## Boundary Check
- [x] Architecture-only edit. No code repo touched.
- [x] No new contract or invariant surface — invariant 40 is added by packet 01.
- [x] Per the "Prefers Azure Portal over CLI" user convention, the doc is structured as a portal walkthrough.

## Acceptance Criteria
- [ ] `infrastructure/github-notifications.md` exists with the five body sections listed above.
- [ ] The portal walkthrough labels match the live GitHub Settings UI as of authoring (verify; GitHub labels drift).
- [ ] `infrastructure/README.md` index references the new walkthrough.
- [ ] Repo-level `CHANGELOG.md` updated with an entry referencing this packet.
- [ ] If packet 01 has not yet merged at authoring time, the doc body uses `<!-- pending acceptance: invariant 40 -->` for any reference to the not-yet-numbered invariant; the comment is removed once 01 lands.

## Human Prerequisites
- [ ] **One-time per-account portal click** — the operator opens https://github.com/settings/notifications and applies the settings the runbook documents. This is the actual D7 enablement; the packet documents it but cannot perform it. Do this either before or after the agent's PR — the runbook's value is independent of the timing of the click.
- [ ] **Verification trigger** — at runbook authoring time, the operator may want to trigger a deliberate workflow failure to confirm the email path works. Optional but recommended, since the runbook prescribes it as the verification step.

The packet's code-change critical path (writing the markdown file) is fully delegable to an agent. Actor=Agent.

## Referenced Invariants

> **Invariant 40 (post-acceptance numbering — see packet 01):** Grid pipeline health is centrally visible. The `HoneyDrunk.Actions` `🕸️ Grid Health` issue is the single canonical view of CI/CD state across the Grid, updated at least daily by the grid-health aggregator. Staleness of that issue is itself a signal — the aggregator's own failure surfaces as the issue not updating. Real-time per-failure notification is separately delivered by the operator's GitHub profile notification settings ("Only notify for failed workflows"), and both mechanisms are mandatory. See ADR-0012 D6, D7.

The runbook is the operational complement to invariant 40 — it describes how an operator turns on the mandatory D7 mechanism the invariant references.

## Referenced ADR Decisions

**ADR-0012 D7 (GitHub profile notifications):** "Settings → Notifications → Actions → 'Only notify for failed workflows' on the operator's GitHub account. This delivers one email per failed workflow run at the moment the run completes, across every repo the operator watches (which for the solo dev is all of `HoneyDrunkStudios/*`)." The runbook turns this prose into clickable steps.

**ADR-0012 D6 (Grid Health aggregator):** D7's complement. The runbook references but does not implement D6 — that is packet 04. The two mechanisms divide responsibility cleanly: D7 = real-time per-failure email; D6 = daily aggregated single-surface issue.

## Dependencies
- Soft-blocked by packet 01 (acceptance) for the invariant 40 reference. The runbook can be drafted in parallel with 01; the cross-reference is updated once 01 lands. If 01 has not merged, use a `<!-- pending acceptance: invariant 40 -->` comment in place of the reference.

## Labels
`feature`, `tier-1`, `meta`, `docs`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Author a short, actionable portal-walkthrough runbook for the GitHub profile notification setup that ADR-0012 D7 mandates.
**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: Land the operational documentation for D7 so the operator's per-account click is a documented, repeatable step.
- Feature: ADR-0012 Grid CI/CD Control Plane, D7 mechanism.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01 (acceptance) for invariant 40 cross-reference. May draft in parallel; cross-reference is finalized after 01 merges.

**Constraints:**
- **User convention — "Prefers Azure Portal over CLI."** Although this is GitHub UI not Azure, the same principle applies: structure the doc as a clickable walkthrough with the actual UI label hierarchy, not as a list of `gh` CLI commands. There is no `gh` equivalent for the Settings → Notifications → Actions configuration anyway — it is a per-account portal setting only.
- **GitHub UI label drift.** The doc must reflect the labels as they appear in the live UI at authoring time. Do not invent labels; verify each step against https://github.com/settings/notifications.
- **Trivial scope.** This is a small doc packet — three to four printed pages. Do not pad it.

**Key Files:**
- `infrastructure/oidc-federated-credentials.md` — style and tone reference (existing portal walkthrough).
- `infrastructure/key-vault-creation.md` — section structure reference.
- `infrastructure/README.md` — index format.

**Contracts:** No code or schema contracts changed.
