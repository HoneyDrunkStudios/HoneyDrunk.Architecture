---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0083", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0083", "ADR-0011"]
wave: 2
initiative: adr-0083-external-saas-credentials
node: honeydrunk-architecture
---

# Author `infrastructure/walkthroughs/sonarcloud-token-rotation.md` — SONAR_TOKEN rotation procedure (forcing-function packet)

## Summary
Author the per-provider rotation walkthrough for `SONAR_TOKEN` against the SonarQube Cloud free plan's 60-day Personal Access Token cap, per ADR-0083 D4. This is the **forcing-function packet** for this initiative — the 60-day cap is the load-bearing deadline for landing the rotation procedure. Sequenced first within Wave 2; without it, the first SONAR_TOKEN expiry produces a silent CI degradation that breaks ADR-0011's third-party static-analysis review surface on every public-repo PR.

## Context
ADR-0083 D4 commits per-provider rotation walkthroughs under `infrastructure/walkthroughs/`, one per rotation-needing provider. SonarCloud is one of three mandatory first-wave walkthroughs covering credentials in active production today.

The forcing function per ADR-0083 §Context:

> `SONAR_TOKEN` — SonarQube Cloud Personal Access Token, bound to the org admin's user account. The free/OSS plan caps PAT expiration at 60 days with no UI to extend. Stored as a GitHub org secret. Consumed by `job-sonarcloud.yml` in `HoneyDrunk.Actions` (per ADR-0011 D11). Forcing function for this ADR: a missed rotation silently breaks SonarCloud analysis on every PR after the 60-day window, which is a code-review-gate degradation that ADR-0011 explicitly relies on for public-repo coverage.

ADR-0011's acceptance pass authored `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (already in the repo per the `infrastructure/walkthroughs/` listing) and that walkthrough explicitly defers the *"and how do I rotate this PAT in 60 days, and how does the Grid notice when I forget?"* question to this packet's deliverable.

The walkthrough format follows the existing convention (`sonarcloud-organization-setup.md`, `key-vault-creation.md`, `oidc-federated-credentials.md`, `github-app-hive-walkthrough.md`, etc.): portal breadcrumb, step-by-step instructions, where to paste the new value, verification steps, and the inventory-update step.

This is a docs packet. No code, no .NET project, no workflow.

## Scope
- Create file `infrastructure/walkthroughs/sonarcloud-token-rotation.md` with the full rotation procedure per ADR-0083 D4 §"`sonarcloud-token-rotation.md`."
- Cross-link from `infrastructure/walkthroughs/sonarcloud-organization-setup.md` to the new file (a one-line "for rotation procedure, see `sonarcloud-token-rotation.md`" link at the appropriate point in the setup walkthrough).
- Verify the `Rotation Procedure` cell in `infrastructure/reference/sensitive-inventory.md`'s `SONAR_TOKEN` row points at this file's relative path (the link was pre-populated in packet 01 against an anticipated path; this packet confirms the path matches).

## Proposed Implementation

The walkthrough must cover, in order:

1. **Prerequisites and identity.** Operator must be logged in as the SonarCloud org admin whose user account owns the current `SONAR_TOKEN`. Note that the PAT is bound to the user, not the organization — rotating away from the original admin requires a separate setup-style flow per `sonarcloud-organization-setup.md`, not this walkthrough.
2. **Portal breadcrumb.** Log in at https://sonarcloud.io → click avatar (top-right) → **My Account** → **Security** tab.
3. **Identify the existing token.** The current `SONAR_TOKEN` will be named something like `honeydrunk-grid-ci` or whatever the original setup walkthrough chose. The Security tab lists all PATs with their issuance date and expiration date. Confirm which one is the current production token by cross-referencing the GitHub org secret's metadata (Settings → Secrets and variables → Actions → `SONAR_TOKEN` last-updated date should be near the SonarCloud token's issuance date).
4. **Generate the replacement token.** In the same Security tab, generate a new token with:
   - **Name:** the next dated rotation name — convention `honeydrunk-grid-ci-{YYYY-MM-DD}` where `{YYYY-MM-DD}` is today's date. The dated name makes the rotation history readable from the Security tab alone.
   - **Type:** User Token (per SonarCloud's PAT classification; this is the type the existing token uses).
   - **Expiration:** the maximum the free plan allows (60 days as of authoring). If SonarCloud's free plan adopts a longer cap, use the new maximum.
   - **Scopes:** match the existing token's scopes — typically the default User Token scope set (the SonarCloud documentation referenced from the original setup walkthrough enumerates the exact scopes; do not over-grant).
   Click **Generate** and **immediately copy the new token value** to the OS clipboard. SonarCloud will not display it again.
5. **Paste into the GitHub org secret.** Navigate to https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → find `SONAR_TOKEN` → **Update** → paste the new value → **Save**.
6. **Verification — open PR check.** Open the most recent non-draft PR on any HoneyDrunk public repo (any repo with `.honeydrunk-review.yaml`'s `enabled: true`) and **Re-run failed jobs** or push a trivial empty commit to trigger a fresh PR-core run. Confirm that the SonarCloud check posts on the PR within the usual cadence (5–10 minutes). The token is verified working when the SonarCloud check returns Pass, Fail-with-findings, or Pending — any of those three means the token authenticated successfully. A 401-shaped failure in the SonarCloud step's logs means the new token did not save correctly; repeat step 5.
7. **Revoke the old token.** Only after verification (step 6) returns a SonarCloud-authenticated result, return to SonarCloud → My Account → Security → identify the **previous** dated token (the one whose dated suffix matches the previous rotation) → click **Revoke**. The revocation is immediate and irreversible — do not revoke before verification.
8. **Close the standing rotation issue.** Find the open GitHub issue in `HoneyDrunk.Architecture` with the label `external-credential-rotation` and a title matching `[Rotate] SONAR_TOKEN — expires {previous-expiration-date}`. Comment with the new expiration date and the link to the SonarCloud Security tab showing the new token, then **Close** the issue.
9. **Open the next standing rotation issue.** Create a new issue in `HoneyDrunk.Architecture` with title `[Rotate] SONAR_TOKEN — expires {new-expiration-date}` (the 60-day-out date) and the label `external-credential-rotation`. The issue body links to this walkthrough and to the inventory row. The `external-credentials-check.yml` workflow per ADR-0083 D5 will pick up the new expiration on its next scheduled run and add `urgent` / `imminent` comments at T-30 / T-7 automatically.
10. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md`. In the `SONAR_TOKEN` row, update `Current Expiration` to the new date. Commit and PR; the workflow re-reads the file on its next scheduled run.

Add a final **"What breaks if you forget"** section: per ADR-0083 §Context, missed SONAR_TOKEN rotation produces a silent CI degradation — SonarCloud's check just stops posting on PRs, which the operator might not notice for days or weeks. The `external-credentials-check.yml` workflow per ADR-0083 D5 mitigates this with T-30 / T-7 / T+0 escalation, but the walkthrough should explicitly name the failure mode for first-time-readers.

Add a **"Cross-references"** section linking to:
- `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (initial setup; out of scope here)
- `infrastructure/reference/sensitive-inventory.md` (the `SONAR_TOKEN` row)
- ADR-0011 (the static-analysis surface SONAR_TOKEN gates)
- ADR-0083 D4 (the rotation-walkthrough convention this file implements)

## Affected Files
- `infrastructure/walkthroughs/sonarcloud-token-rotation.md` (new)
- `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (add one-line cross-link to the new rotation walkthrough)
- `infrastructure/reference/sensitive-inventory.md` (verify the `Rotation Procedure` link in the `SONAR_TOKEN` row matches this file's path; correct if drift)
- `CHANGELOG.md` (append to in-progress entry)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] Per Invariant 8, the walkthrough names the token but never writes its value into any artifact.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/sonarcloud-token-rotation.md` exists with all ten procedural steps documented in order (prerequisites; portal breadcrumb; identify existing token; generate replacement; paste into GitHub org secret; verification via PR check; revoke old token; close standing issue; open next standing issue; update inventory)
- [ ] Step 4's token-naming convention is `honeydrunk-grid-ci-{YYYY-MM-DD}` and is called out explicitly
- [ ] Step 4 explicitly directs the operator to choose the **maximum** expiration the free plan allows (60 days as of authoring)
- [ ] Step 6's verification check is non-destructive — re-run failed jobs or push an empty commit on an existing PR, not creation of a new PR
- [ ] Step 7's revoke-old-token step is gated on step 6's verification success, with explicit language preventing accidental revoke-before-verify
- [ ] Steps 8 and 9 cite the `external-credential-rotation` label and the title-shape `[Rotate] SONAR_TOKEN — expires {YYYY-MM-DD}` per ADR-0083 D3
- [ ] Step 10's inventory-update step explicitly names `infrastructure/reference/sensitive-inventory.md` and the `Current Expiration` column
- [ ] A "What breaks if you forget" section names the silent-CI-degradation failure mode per ADR-0083 §Context
- [ ] A "Cross-references" section links to `sonarcloud-organization-setup.md`, `sensitive-inventory.md`, ADR-0011, and ADR-0083 D4
- [ ] `infrastructure/walkthroughs/sonarcloud-organization-setup.md` adds a one-line cross-link to the new rotation walkthrough at an appropriate point in its text
- [ ] The `Rotation Procedure` cell in `infrastructure/reference/sensitive-inventory.md`'s `SONAR_TOKEN` row points at this walkthrough's relative path
- [ ] No secret value appears in the walkthrough — token names and procedure references only
- [ ] Repo-level `CHANGELOG.md` appends to the in-progress entry from packets 00/01

## Human Prerequisites
- [ ] Operator must perform the **first rotation against this walkthrough** within the SONAR_TOKEN's current 60-day window once the walkthrough lands. This is the live-fire test of the procedure — the walkthrough is not "verified" until it has produced at least one successful rotation against an actual SonarCloud token. Capture any procedure ambiguities or portal-UI drift in a follow-up edit to the walkthrough. (This is a procedural Prerequisite, not a code Prerequisite — the agent-produced walkthrough is correct against the ADR; the operator's job is to confirm against the live portal.)

## Referenced ADR Decisions
**ADR-0083 D4 — Per-provider rotation walkthroughs.** Live under `infrastructure/walkthroughs/`, one per rotation-needing provider. Three mandatory first-wave walkthroughs unblocked by ADR-0083 acceptance: SonarCloud (this packet), NuGet (packet 03), GitHub PATs (packet 04). The walkthrough is the rotation procedure: portal breadcrumb, step-by-step instructions, where to paste the new value, verification steps, and the inventory-update step.

**ADR-0083 D4 §"`sonarcloud-token-rotation.md`."** The specific procedure ADR-0083 commits: log in as the org admin → User → My Account → Security → revoke old token → generate new token with the same scopes → copy value → GitHub org secrets → update `SONAR_TOKEN` → verify against an open PR's SonarCloud check → close the standing rotation issue → open a new one with the new expiration date → update `infrastructure/reference/sensitive-inventory.md`. **This packet deliberately swaps the "revoke" step to AFTER verification** to prevent the failure mode where the new token saves incorrectly and the operator has already destroyed the old one. The ADR's described order is the same procedural steps; the swap is operationally safer.

**ADR-0083 D3 — Standing-issue label and title-shape.** `external-credential-rotation` label; `[Rotate] {credential-name} — expires {YYYY-MM-DD}` title. Closed on rotation, new issue opened immediately.

**ADR-0083 §Context — silent-CI-degradation failure mode.** The forcing function. Walkthrough's "What breaks if you forget" section names this explicitly.

**ADR-0011 D11 — `job-sonarcloud.yml` consumes `SONAR_TOKEN`.** The downstream consumer the walkthrough must keep working.

**Invariant 8 — "Secret values never appear in logs, traces, exceptions, or telemetry."** Walkthrough names the token but never writes its value.

## Constraints
- **Revoke after verify, not before.** ADR-0083 D4's text lists "revoke old token → generate new token" as the procedural sequence. This packet deliberately reorders to "generate new → paste → verify → then revoke old" because the operationally-safe ordering is to keep a working fallback until the replacement is proven. The ADR's text is a high-level enumeration of the steps the walkthrough must cover; the walkthrough may sequence them safely. Verify the new token is working (step 6) **before** revoking the old (step 7).
- **No secret values in the file.** The walkthrough names the token (`SONAR_TOKEN`), references the SonarCloud portal location where the value is generated, and directs the operator to paste into the GitHub org secret — but never writes any actual value. Invariant 8 fully preserved.
- **Use the maximum allowed expiration.** The free plan's 60-day cap is the maximum; do not generate a shorter-lived token. A 60-day cadence is the highest-tolerable for the silent-CI-degradation failure mode; shorter would mean more frequent rotations with no benefit.
- **Dated token names.** The `honeydrunk-grid-ci-{YYYY-MM-DD}` convention makes the rotation history readable from the SonarCloud Security tab alone, without cross-referencing GitHub issue history. Use it.
- **Verification step is non-destructive.** Use an existing PR's "re-run failed jobs" or push an empty commit. Do not direct the operator to open a new throwaway PR — that adds noise.
- **Cross-link both directions.** Update `sonarcloud-organization-setup.md` to point at the new rotation walkthrough (the setup walkthrough is the entry point for new operators).

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0083`, `wave-2`

## Agent Handoff

**Objective:** Author the `SONAR_TOKEN` rotation walkthrough per ADR-0083 D4, sequenced first within Wave 2 against the 60-day forcing function.

**Target:** `HoneyDrunk.Architecture`, branch from `main` after packet 01 has merged.

**Context:**
- Goal: Close the rotation-procedure gap before the first SONAR_TOKEN expiry window. Without this walkthrough, ADR-0011's third-party static-analysis review surface silently degrades on every public-repo PR.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 2 forcing-function packet.
- ADRs: ADR-0083 D4 (walkthrough convention), D3 (standing-issue label and title-shape), §Context (silent-CI-degradation failure mode); ADR-0011 D11 (`job-sonarcloud.yml` consumer); Invariant 8 (no secret values).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (inventory file with the `SONAR_TOKEN` row and the three new labels) must have merged.

**Constraints:**
- Revoke after verify, not before — the operationally-safe ordering, even though the ADR's prose lists revoke first.
- No secret values in the file (Invariant 8 preserved).
- Use the 60-day maximum.
- Dated token names: `honeydrunk-grid-ci-{YYYY-MM-DD}`.
- Verification is non-destructive — re-run failed jobs or push an empty commit on an existing PR.
- Cross-link both directions: update `sonarcloud-organization-setup.md` to point at the new file.

**Key Files:**
- `infrastructure/walkthroughs/sonarcloud-token-rotation.md` (new)
- `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (one-line cross-link addition)
- `infrastructure/reference/sensitive-inventory.md` (verify the `SONAR_TOKEN` row's `Rotation Procedure` cell)
- `CHANGELOG.md`

**Contracts:** None changed.

**PR Body Metadata:**
- `Authorship: agent`
- `Work Item: generated/work-items/proposed/adr-0083-external-saas-credentials/02-architecture-sonarcloud-token-rotation-walkthrough.md`
