---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "ops", "ci", "adr-0039", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0039", "ADR-0011"]
accepts: ["ADR-0039"]
wave: 2
initiative: adr-0039-license-policy
node: honeydrunk-actions
---

# Author job-dco-signoff.yml — the reusable DCO sign-off enforcement workflow (ADR-0039 D5)

## Summary
Author a reusable `job-dco-signoff.yml` `workflow_call` workflow in `HoneyDrunk.Actions` that enforces a `Signed-off-by:` trailer on every commit in a PR opened by a non-Studio committer, exempting Studio-employee commits (currently the sole developer), so external contributions to any Grid repo carry the Developer Certificate of Origin grant per ADR-0039 D5.

## Context
ADR-0039 D5 decides the Grid's contribution-licensing posture: **DCO (Developer Certificate of Origin), not CLA.** External contributions are accepted under the DCO — contributors `Signed-off-by:` their commits; no separate CLA is signed. ADR-0039 D5 explicitly commits: "A GitHub Action enforces `Signed-off-by:` on PRs from non-Studio committers. Studio-employee commits (currently: the sole developer) are exempted because the Studio's IP assignment covers them." ADR-0039's Consequences names this as Follow-up Work: "Wire the DCO sign-off Action in HoneyDrunk.Actions as a reusable workflow; consumer PR-validation workflows call it."

This packet builds that reusable workflow. The actual *wiring into each repo's PR-validation workflow* is the fan-out (packet 05). This packet ships only the reusable workflow itself.

The Grid is single-author today — the friction is theoretical until the first external PR (ADR-0039 Operational Consequences: "the friction is theoretical until the first external PR"). So this workflow ships, is callable, and exempts the sole developer; it does not change anything for current solo development.

## Scope
- `HoneyDrunk.Actions` — new reusable workflow file, conventionally `.github/workflows/job-dco-signoff.yml` (match the naming + location of the existing `job-*.yml` reusable workflows, e.g. `job-publish-nuget.yml`, `job-api-compatibility.yml`).
- `HoneyDrunk.Actions` consumer-usage documentation (`docs/consumer-usage.md` or the equivalent the repo uses) — document how a consumer repo's PR-validation workflow calls `job-dco-signoff.yml`.
- `HoneyDrunk.Actions` repo-level `CHANGELOG.md` — entry for the new reusable workflow.

## Proposed Implementation
1. **Reusable workflow shell.** Author `job-dco-signoff.yml` as a `workflow_call` workflow. Inputs (all optional with sensible defaults):
   - `exempt-actors` — a newline- or comma-separated list of GitHub logins whose commits skip the sign-off check (Studio employees). Default: the sole developer's login. The caller may pass an org-team reference instead if the implementing agent finds a cleaner mechanism (e.g. checking org-membership via the API) — record the chosen mechanism in the PR.
2. **The check.** The job inspects every commit in the PR (via the PR commits API or `git log base..head`). For each commit:
   - If the commit author's GitHub login is in `exempt-actors` → pass (Studio commit, IP-assignment-covered).
   - Otherwise → require a `Signed-off-by: Name <email>` trailer in the commit message, and that the sign-off name/email match the commit author. Missing or mismatched sign-off → fail the check with a clear, actionable message ("This PR includes commits without a DCO `Signed-off-by:` trailer. Run `git commit --amend --signoff` or `git rebase --signoff` — see <link to the repo CONTRIBUTING.md DCO section>.").
   - The failure message links to the DCO and to the consumer repo's `CONTRIBUTING.md` (created in packet 05).
3. **Implementation choice.** The agent may implement the check inline (a small shell/script step parsing commit trailers) or wrap an established DCO action — but ADR-0009's Dependabot-style "first-party over third-party where cheap" leaning and the Grid's reusable-workflow convention favor a small inline implementation with no third-party action dependency. If a third-party action is used, it must be pinned to a full commit SHA (Grid CI convention). Record the choice in the PR.
4. **Not a branch-protection gate yet.** ADR-0039 D5 says the Action *enforces* sign-off, but the Grid is single-author and the sole developer is exempt — so making `job-dco-signoff.yml` a *required* branch-protection check Grid-wide is premature noise. This packet ships the workflow as **callable and advisory-by-default**; whether a consumer repo makes it a required check is decided per repo in packet 05 (default: called, not required, until the first external PR). Do not add it to any repo's branch protection in this packet.
5. **Consumer-usage doc.** Document the `workflow_call` contract: how a consumer's PR-validation workflow (whatever its filename — repos do not share a uniform `pr-*.yml` name; ADR-0011's `pr-core.yml` standard is still Proposed) adds a `job-dco-signoff` job, what `exempt-actors` to pass, and that it is advisory until a repo opts to make it required.

## Affected Files
- `HoneyDrunk.Actions/.github/workflows/job-dco-signoff.yml` (new — match the actual reusable-workflow location)
- `HoneyDrunk.Actions` consumer-usage doc
- `HoneyDrunk.Actions` `CHANGELOG.md`

## NuGet Dependencies
None. This packet ships a GitHub Actions YAML workflow and Markdown docs. No .NET project is created or modified.

## Boundary Check
- [x] Reusable CI workflows live in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions, pipeline, PR check → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any other repo — consumer repos call the workflow in packet 05.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `job-dco-signoff.yml` exists in `HoneyDrunk.Actions` as a `workflow_call` reusable workflow, matching the naming/location convention of the existing `job-*.yml` workflows
- [ ] The workflow takes an `exempt-actors` input (Studio-employee logins) with the sole developer as the default
- [ ] The check inspects every commit in the PR; commits by exempt actors pass; non-exempt commits require a `Signed-off-by:` trailer matching the commit author
- [ ] A missing/mismatched sign-off fails the check with an actionable message linking to the DCO and to the consumer repo's `CONTRIBUTING.md` DCO section
- [ ] If a third-party DCO action is used, it is pinned to a full commit SHA; the PR records whether the implementation is inline or wrapped
- [ ] The workflow is callable and advisory-by-default — this packet does NOT add it to any repo's branch protection
- [ ] The consumer-usage doc documents the `workflow_call` contract and the advisory-until-first-external-PR posture
- [ ] `HoneyDrunk.Actions` repo-level `CHANGELOG.md` has an entry for the new reusable workflow under a dated, versioned section

## Human Prerequisites
- [ ] Confirm the GitHub login(s) to seed as the default `exempt-actors` value — the Studio-employee set (currently just the sole developer). If the implementing agent cannot determine the login, the developer supplies it before merge.
- [ ] (Future, not a blocker) When the first external contributor PR arrives, the developer decides per repo whether to promote `job-dco-signoff.yml` from advisory to a required branch-protection check. That decision is out of this packet's scope.

## Referenced ADR Decisions
**ADR-0039 D5 — Contribution: DCO, not CLA.** "External contributions to any Grid repo are accepted under the Developer Certificate of Origin (DCO). Contributors `Signed-off-by:` their commits; no separate CLA is signed... A GitHub Action enforces `Signed-off-by:` on PRs from non-Studio committers. Studio-employee commits (currently: the sole developer) are exempted because the Studio's IP assignment covers them under the founder's contributions to the LLC."

**ADR-0039 Follow-up Work.** "Wire the DCO sign-off Action in HoneyDrunk.Actions as a reusable workflow; consumer PR-validation workflows call it." (This packet ships the reusable workflow; packet 05 wires it into consumer repos.)

**ADR-0039 Operational Consequences.** "The DCO sign-off job adds a small friction to external contributions. The Studio is single-author today; the friction is theoretical until the first external PR."

**ADR-0011 — code-review pipeline.** The Grid's PR-validation reusable workflows live in `HoneyDrunk.Actions` and are composed by consumer repos. `job-dco-signoff.yml` follows that pattern — it is a reusable workflow consumer repos opt into, not a monolithic gate.

## Constraints
- **Exempt Studio commits.** The sole developer's commits must pass without a sign-off trailer — ADR-0039 D5 exempts them because the LLC's IP assignment already covers them. Do not require sign-off on Studio commits.
- **Advisory-by-default.** Do not add the workflow to any repo's branch protection in this packet. The Grid is single-author; making it a required gate now is noise. Promotion to required is a per-repo decision deferred to the first external PR.
- **Pin third-party actions to a full SHA** if any is used; prefer a small inline implementation with no third-party dependency.
- This packet does not bump a package version (no .NET project). The `CHANGELOG.md` entry rides the next `HoneyDrunk.Actions` release; agents never push tags (invariant 27).

## Labels
`chore`, `tier-2`, `ops`, `ci`, `adr-0039`, `wave-2`

## Agent Handoff

**Objective:** Author the reusable `job-dco-signoff.yml` workflow in `HoneyDrunk.Actions` that enforces a DCO `Signed-off-by:` trailer on non-Studio committers' PR commits.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Give every Grid repo a callable DCO enforcement workflow so external contributions carry a clear IP grant — per ADR-0039 D5's DCO-not-CLA decision.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 2.
- ADRs: ADR-0039 (D5, Follow-up Work, Operational Consequences), ADR-0011 (reusable-workflow PR-validation pattern).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0039 acceptance (soft — references ADR-0039 D5 as a live rule).

**Constraints:**
- Exempt Studio-employee commits (the sole developer) — they pass without a sign-off trailer.
- Advisory-by-default — do not add to any branch protection in this packet.
- Pin any third-party action to a full SHA; prefer an inline implementation.
- No tag push.

**Key Files:**
- `HoneyDrunk.Actions/.github/workflows/job-dco-signoff.yml` (new)
- the consumer-usage doc
- `HoneyDrunk.Actions` `CHANGELOG.md`

**Contracts:** Introduces the `job-dco-signoff.yml` `workflow_call` contract (`exempt-actors` input). Consumed by packet 05's per-repo PR-validation-workflow wiring.
