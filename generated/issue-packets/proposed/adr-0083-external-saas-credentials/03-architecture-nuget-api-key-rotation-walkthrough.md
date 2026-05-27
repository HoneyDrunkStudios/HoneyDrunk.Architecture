---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0083", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0083", "ADR-0034"]
wave: 2
initiative: adr-0083-external-saas-credentials
node: honeydrunk-architecture
---

# Author `infrastructure/walkthroughs/nuget-api-key-rotation.md` — NUGET_API_KEY rotation procedure

## Summary
Author the per-provider rotation walkthrough for `NUGET_API_KEY` against NuGet.org's 365-day Personal API Key cap, per ADR-0083 D4. Parallel with packets 02 (SonarCloud) and 04 (GitHub PAT) within Wave 2. `NUGET_API_KEY` has been in production use longer than any other external-SaaS credential and is the credential ADR-0083 retroactively documents and disciplines; this walkthrough is the canonical procedure.

## Context
ADR-0083 D4 commits per-provider rotation walkthroughs under `infrastructure/walkthroughs/`. NuGet is one of three mandatory first-wave walkthroughs covering credentials in active production today.

The blast radius per ADR-0083 §Context:

> `NUGET_API_KEY` — NuGet.org Personal API Key, bound to the org admin's nuget.org account, scoped to the `HoneyDrunk.*` package glob. NuGet.org caps Personal API Keys at 365 days for keys created in recent years (legacy never-expires keys are grandfathered but should not be assumed available for new keys). Stored as a GitHub org secret. Consumed by `release.yml:442` in `HoneyDrunk.Actions` and surfaced through `examples/publish-nuget.yml`, `docs/consumer-usage.md`, and `README.md`. **Highest blast radius after SONAR_TOKEN**: every NuGet-shipping Node's release pipeline silently fails to publish, breaking the ADR-0034 publishing pipeline across the Grid and stalling downstream package restore.

ADR-0083 D1 explicitly rules out automating this rotation despite NuGet.org's having an API for key management — the cost discipline applies (fewer than ten total external-SaaS credentials; per-provider integration cost dominates manual-rotation cost).

The walkthrough format follows the existing convention. The expected procedure per ADR-0083 D4 §"`nuget-api-key-rotation.md`":

> Rotates `NUGET_API_KEY` against NuGet.org's 365-day Personal API Key cap. Covers: log in as the org admin → `nuget.org/account/apikeys` → create a new API key with the same `HoneyDrunk.*` package glob and the same scopes (Push new packages and package versions) → copy value → GitHub org secrets → update `NUGET_API_KEY` → delete the old key from `nuget.org/account/apikeys` → verify against the next `release.yml` invocation (or trigger a no-op publish smoke test) → close the standing rotation issue → open the next → update the inventory.

This is a docs packet. No code, no .NET project, no workflow.

## Scope
- Create file `infrastructure/walkthroughs/nuget-api-key-rotation.md` with the full rotation procedure per ADR-0083 D4 §"`nuget-api-key-rotation.md`."
- Verify the `Rotation Procedure` cell in `infrastructure/reference/sensitive-inventory.md`'s `NUGET_API_KEY` row points at this file's relative path.

## Proposed Implementation

The walkthrough must cover, in order:

1. **Prerequisites and identity.** Operator must be logged in as the NuGet.org admin whose account owns the current `NUGET_API_KEY`. The key is bound to the user account, not to an organization principal on NuGet.org (NuGet.org's permission model uses package-owner-list membership rather than first-class orgs for API key issuance).
2. **Portal breadcrumb.** Log in at https://www.nuget.org → click the operator's username (top-right) → **API Keys** (or navigate directly to https://www.nuget.org/account/apikeys).
3. **Identify the existing key.** The current `NUGET_API_KEY` will be named something descriptive — `honeydrunk-grid-publish` or similar. The API Keys page lists each key with its scope, expiration date, and last-used date. Confirm which is the current production key by cross-referencing the GitHub org secret metadata (Settings → Secrets and variables → Actions → `NUGET_API_KEY` last-updated date).
4. **Generate the replacement key.** On the API Keys page, click **Create**:
   - **Key Name:** dated rotation convention `honeydrunk-grid-publish-{YYYY-MM-DD}` where `{YYYY-MM-DD}` is today's date.
   - **Expires In:** the maximum NuGet.org allows (365 days for keys created in recent years; legacy never-expires keys are grandfathered but new keys are subject to the cap).
   - **Package Owner:** the operator's nuget.org account (the owner who holds the `HoneyDrunk.*` namespace).
   - **Scopes:** **Push** (both "Push new packages and package versions" and "Push only new package versions" — the broader of the two; the existing key uses Push). Verify against the existing key's scopes; match exactly.
   - **Glob Pattern:** `HoneyDrunk.*` — must match the existing key's glob. Pushing without a glob would over-scope.
   Click **Create** and **immediately copy the new key value** to the OS clipboard. NuGet.org will not display it again.
5. **Paste into the GitHub org secret.** Navigate to https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → find `NUGET_API_KEY` → **Update** → paste the new value → **Save**.
6. **Verification — smoke-test against a release.** Two options, in order of preference:
   - **Preferred:** Wait for the next scheduled `release.yml` invocation (any Node's tag push will trigger one) and confirm the NuGet publish step succeeds. The `dotnet nuget push` step in `release.yml` returns a 401 on a bad key; success means the new key authenticates.
   - **Fallback if no release is imminent:** Trigger a `release.yml` invocation manually on a Node that's already at a recent version (the publish step is idempotent against already-published versions and will return a benign "already exists" rather than a 401). Confirm the workflow's NuGet step does not fail with auth errors.
7. **Delete the old key.** Only after verification (step 6) succeeds, return to NuGet.org → API Keys → identify the **previous** dated key → click **Delete**. Deletion is immediate and irreversible — do not delete before verification.
8. **Close the standing rotation issue.** Find the open GitHub issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` with title `[Rotate] NUGET_API_KEY — expires {previous-expiration-date}`. Comment with the new expiration date and the link to the NuGet.org API Keys page, then **Close**.
9. **Open the next standing rotation issue.** Create a new issue in `HoneyDrunk.Architecture` with title `[Rotate] NUGET_API_KEY — expires {new-expiration-date}` (the 365-day-out date) and the label `external-credential-rotation`. The issue body links to this walkthrough and the inventory row.
10. **Update the inventory row.** Edit `infrastructure/reference/sensitive-inventory.md` → `NUGET_API_KEY` row → update `Current Expiration` to the new date. Commit and PR.

Add a final **"What breaks if you forget"** section: every NuGet-shipping Node's `release.yml` silently fails to publish on the first invocation after expiry. The publish step's failure is loud (the workflow fails), but the cascading effect — downstream package restore stalls when consumers can't pull the new version — is the silent-with-delay failure that matters most. The `external-credentials-check.yml` workflow per ADR-0083 D5 mitigates this with T-30 / T-7 / T+0 escalation.

Add a **"Cross-references"** section linking to:
- `infrastructure/reference/sensitive-inventory.md` (the `NUGET_API_KEY` row)
- ADR-0034 (the public-package-distribution pipeline this gates)
- ADR-0083 D4 (the rotation-walkthrough convention this implements)

Add a brief **"Why this is not automated"** section pointing at ADR-0083 D1 — NuGet.org *does* expose an API for key management, but the cost discipline rules it out at solo-developer + fewer-than-ten-credentials scale.

## Affected Files
- `infrastructure/walkthroughs/nuget-api-key-rotation.md` (new)
- `infrastructure/reference/sensitive-inventory.md` (verify the `NUGET_API_KEY` row's `Rotation Procedure` cell)
- `CHANGELOG.md` (append to in-progress entry)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in `HoneyDrunk.Actions` (`release.yml` is unchanged; the walkthrough refers to it as the consumer but does not modify it).
- [x] No new cross-Node runtime dependency.
- [x] Per Invariant 8, the walkthrough names the key but never writes its value.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/nuget-api-key-rotation.md` exists with all ten procedural steps documented in order (prerequisites; portal breadcrumb; identify existing key; generate replacement; paste into GitHub org secret; verification via release smoke-test; delete old key; close standing issue; open next standing issue; update inventory)
- [ ] Step 4's key-naming convention is `honeydrunk-grid-publish-{YYYY-MM-DD}` and is called out explicitly
- [ ] Step 4 directs the operator to choose **365 days** as the expiration and to match the existing key's glob (`HoneyDrunk.*`) and scopes (Push) exactly
- [ ] Step 6's verification step prefers waiting for the next scheduled release with a fallback to a manual trigger against an already-released version (idempotent publish step)
- [ ] Step 7's delete-old-key step is gated on step 6's verification success, with explicit language preventing accidental delete-before-verify
- [ ] Steps 8 and 9 cite the `external-credential-rotation` label and the title-shape `[Rotate] NUGET_API_KEY — expires {YYYY-MM-DD}` per ADR-0083 D3
- [ ] Step 10's inventory-update step names `infrastructure/reference/sensitive-inventory.md` and the `Current Expiration` column
- [ ] A "What breaks if you forget" section names the publish-failure plus downstream-restore-stall failure mode
- [ ] A "Why this is not automated" section cites ADR-0083 D1's cost discipline
- [ ] A "Cross-references" section links to `sensitive-inventory.md`, ADR-0034, and ADR-0083 D4
- [ ] The `Rotation Procedure` cell in `infrastructure/reference/sensitive-inventory.md`'s `NUGET_API_KEY` row points at this walkthrough's relative path
- [ ] No secret value appears in the walkthrough
- [ ] Repo-level `CHANGELOG.md` appends to the in-progress entry

## Human Prerequisites
- [ ] Operator performs the **first rotation against this walkthrough** when the current `NUGET_API_KEY` next approaches its expiration window. The walkthrough is not "verified" until it has produced at least one successful rotation against an actual NuGet.org key. Capture any procedure ambiguities in a follow-up edit. NuGet.org's portal UI is more stable than SonarCloud's, but version-skew between this walkthrough's authoring date and a future rotation is still possible.

## Referenced ADR Decisions
**ADR-0083 D4 — Per-provider rotation walkthroughs.** Live under `infrastructure/walkthroughs/`, one per rotation-needing provider. The walkthrough is the rotation procedure: portal breadcrumb, step-by-step instructions, where to paste, verification, and inventory update.

**ADR-0083 D4 §"`nuget-api-key-rotation.md`."** The specific procedure ADR-0083 commits. **This packet deliberately swaps the "delete" step to AFTER verification** to prevent the failure mode where the new key saves incorrectly and the operator has already destroyed the old one. The ADR's described order is the same procedural steps; the swap is operationally safer.

**ADR-0083 D1 — Why this is not automated.** Vault.Rotation does not expand to cover external-SaaS PATs / API keys. NuGet.org's API for key management is acknowledged but explicitly out of scope on cost grounds. The walkthrough cites this in its "Why this is not automated" section.

**ADR-0083 §Context — Highest blast radius after SONAR_TOKEN.** Every NuGet-shipping Node's release pipeline silently fails to publish on first invocation after expiry. Downstream package restore stalls. The walkthrough's "What breaks if you forget" section names this.

**ADR-0083 D3 — Standing-issue label and title-shape.** `external-credential-rotation` label; `[Rotate] NUGET_API_KEY — expires {YYYY-MM-DD}` title.

**ADR-0034 — Public-package distribution.** The pipeline `NUGET_API_KEY` gates. Walkthrough cross-references; no edits to ADR-0034.

**Invariant 8 — "Secret values never appear in logs, traces, exceptions, or telemetry."** Walkthrough names the key but never writes its value.

## Constraints
- **Delete after verify, not before.** Same operationally-safe reordering as the SonarCloud walkthrough (packet 02). Keep a working fallback until the replacement is proven.
- **No secret values in the file.** The walkthrough names `NUGET_API_KEY` and references the NuGet.org API Keys page but never writes any actual value. Invariant 8 fully preserved.
- **Use the 365-day maximum and match the existing glob/scopes exactly.** Do not over-scope (would expand blast radius); do not under-scope (would break publish).
- **Dated key names.** `honeydrunk-grid-publish-{YYYY-MM-DD}` convention. Readable rotation history from the NuGet.org API Keys page.
- **Verification is non-destructive.** Wait for a scheduled release if one is imminent; fall back to manual trigger against an already-released version (idempotent — publish returns "already exists" rather than 401).
- **Do not edit `release.yml` in `HoneyDrunk.Actions`.** The walkthrough references `release.yml` as the consumer but does not modify it. Any change to `release.yml` is a separate ci-change packet.
- **Do not omit the "Why this is not automated" section.** It is load-bearing for closing a known operator question (per ADR-0083 §Context: "this key has been rotating-by-default whenever it expired, without a documented procedure — another data point in the drift pattern this ADR closes").

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0083`, `wave-2`

## Agent Handoff

**Objective:** Author the `NUGET_API_KEY` rotation walkthrough per ADR-0083 D4. Parallel with packets 02 (SonarCloud) and 04 (GitHub PAT) within Wave 2.

**Target:** `HoneyDrunk.Architecture`, branch from `main` after packet 01 has merged.

**Context:**
- Goal: Disciplined documented rotation for the credential with the highest blast radius after SONAR_TOKEN. Closes the rotating-by-default drift pattern ADR-0083 §Context names.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 2.
- ADRs: ADR-0083 D4 (walkthrough convention), D1 (why not automated), D3 (standing-issue label), §Context (blast radius); ADR-0034 (NuGet publishing pipeline); Invariant 8 (no secret values).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (inventory file with the `NUGET_API_KEY` row and the three new labels) must have merged.

**Constraints:**
- Delete after verify, not before.
- No secret values (Invariant 8 preserved).
- 365-day max, match existing glob (`HoneyDrunk.*`) and scopes (Push) exactly.
- Dated key names: `honeydrunk-grid-publish-{YYYY-MM-DD}`.
- Verification: prefer waiting for next scheduled release; fall back to manual trigger against an already-released version.
- Do not edit `release.yml` in `HoneyDrunk.Actions`.
- Include the "Why this is not automated" section citing ADR-0083 D1.

**Key Files:**
- `infrastructure/walkthroughs/nuget-api-key-rotation.md` (new)
- `infrastructure/reference/sensitive-inventory.md` (verify the `NUGET_API_KEY` row's `Rotation Procedure` cell)
- `CHANGELOG.md`

**Contracts:** None changed.

**PR Body Metadata:**
- `Authorship: agent`
- `Packet: generated/issue-packets/proposed/adr-0083-external-saas-credentials/03-architecture-nuget-api-key-rotation-walkthrough.md`
