---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0083", "wave-3"]
dependencies: ["packet:02", "packet:03", "packet:04"]
adrs: ["ADR-0083"]
wave: 3
initiative: adr-0083-external-saas-credentials
node: honeydrunk-architecture
---

# Open initial standing rotation issues for every `Rotates: yes` row in the seed inventory

## Summary
Open one GitHub issue in `HoneyDrunk.Architecture` per `Rotates: yes` row in the seed `infrastructure/reference/sensitive-inventory.md` per ADR-0083 D3 §"reminder cadence." Each issue is labeled `external-credential-rotation` and titled `[Rotate] {credential-name} — expires {YYYY-MM-DD}`, with a body linking to the inventory row and the rotation walkthrough. This packet establishes the standing-tracking surface that `external-credentials-check.yml` (packet 05) escalates against and that the new invariant 103 per packet 00 requires for every `Rotates: yes` row.

## Context
ADR-0083 D3 commits the standing-issue tracking surface:

> Every rotation-needing credential in the inventory (rows with `Rotates: yes`) carries a **standing GitHub issue** in `HoneyDrunk.Architecture` labeled `external-credential-rotation` with the title shape `[Rotate] {credential-name} — expires {YYYY-MM-DD}`. The issue body links to the inventory row and the rotation walkthrough. The issue is **closed on rotation**, and a new issue is opened immediately with the new expiration date in the title. Non-rotating inventory entries (rows with `Rotates: no` or `Rotates: automated-elsewhere`) do **not** get standing issues — there is nothing to escalate to.

Per the new invariant 103 per ADR-0083 D7 (lands in packet 00), every `Rotates: yes` row **must** carry an open standing issue. This packet seeds those issues for the existing seed inventory. Future rotations close the seeded issue and open a fresh one with the new expiration date per the per-provider walkthrough (packets 02 / 03 / 04).

The `Rotates: yes` rows in the seed inventory per packet 01:

| # | Credential | Walkthrough |
|---|------------|-------------|
| 1 | `SONAR_TOKEN` | `infrastructure/walkthroughs/sonarcloud-token-rotation.md` (packet 02) |
| 2 | `NUGET_API_KEY` | `infrastructure/walkthroughs/nuget-api-key-rotation.md` (packet 03) |
| 3 | `GH_ISSUE_TOKEN` | `infrastructure/walkthroughs/github-pat-rotation.md` (packet 04) |
| 4 | `HIVE_FIELD_MIRROR_TOKEN` | `infrastructure/walkthroughs/github-pat-rotation.md` (packet 04) |
| 5 | `LABELS_FANOUT_PAT` | `infrastructure/walkthroughs/github-pat-rotation.md` (packet 04) |
| 6 | `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` | *no walkthrough yet — see Notes* |
| 7 | `ANTHROPIC_API_KEY` | *no walkthrough yet — `status: planned`* |
| 8 | `OPENAI_API_KEY` | *no walkthrough yet — `status: planned`* |

Rows 1–5 have walkthroughs in this initiative. Row 6 (`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`) per ADR-0083 §Follow-up Work: *"A future `openclaw-webhook-secret-rotation.md` walkthrough lands with the webhook-bridge work."* The standing issue for this row is opened anyway — it satisfies invariant 103 and the issue body explicitly notes that the walkthrough is pending the webhook-bridge work. Rows 7–8 are `status: planned`; the standing issue is opened with the same note (walkthrough pending the credential going live).

This is a process/governance packet executed via `gh issue create` calls. No file edits beyond the optional comment-back to the inventory row noting "standing issue: #N" if that cross-reference style is adopted.

## Scope
- Open one GitHub issue in `HoneyDrunk.Architecture` per `Rotates: yes` row in the seed inventory (8 issues for the seed set).
- For rows 1–5 (with walkthroughs): the issue body links to the relevant walkthrough.
- For row 6 (`OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`): the issue body notes the walkthrough is pending the webhook-bridge work and links to the inventory row.
- For rows 7–8 (`status: planned`): the issue body notes the walkthrough is pending the credential going live.

## Proposed Implementation

For each `Rotates: yes` row in the seed inventory, execute (or instruct execution of) `gh issue create` against `HoneyDrunkStudios/HoneyDrunk.Architecture` with the shape:

**Title:** `[Rotate] {credential-name} — expires {current-expiration-date}`

where `{current-expiration-date}` is the ISO 8601 `YYYY-MM-DD` date from the inventory row's `Current Expiration` column. Per N1 of the refine pass, packet 01 now writes a real (or provisional `today + provider-cap-days`) ISO 8601 date in every `Rotates: yes` row — the `TBD …` placeholder string is forbidden. This packet relies on that strictness; the title always carries a parseable ISO 8601 date.

**Body template (rows 1–5):**

```markdown
Standing rotation issue per ADR-0083 D3.

**Credential:** `{credential-name}`
**Provider:** {provider-name}
**Current expiration:** {current-expiration-date}
**Rotation procedure:** [`{walkthrough-relative-path}`](../tree/main/{walkthrough-relative-path})
**Inventory row:** [`infrastructure/reference/sensitive-inventory.md`](../tree/main/infrastructure/reference/sensitive-inventory.md)

When rotating: follow the walkthrough end-to-end. When done, close this issue and immediately open the next one with the new expiration date in the title.

The scheduled [`external-credentials-check.yml`](https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/blob/main/.github/workflows/external-credentials-check.yml) workflow per ADR-0083 D5 will comment on this issue at T-30 (adding label `urgent`) and T-7 (adding label `imminent`), and will create a SEV-2 incident record at T+0 per ADR-0054.

---
Per ADR-0083 D7 invariant 103 — every `Rotates: yes` inventory row carries an open standing issue.
```

**Body template (row 6 — `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`):** same shape, but `**Rotation procedure:**` reads `*Pending — `openclaw-webhook-secret-rotation.md` lands with the webhook-bridge work per ADR-0083 §Follow-up Work.*` and the body notes that rotation should follow the inventory row's free-form notes until the walkthrough lands.

**Body template (rows 7–8 — `status: planned` keys):** same shape, but `**Rotation procedure:**` reads `*Pending — credential not yet provisioned. Walkthrough lands when the credential goes live.*` and the issue may be labeled with an additional `planned` label (or omitted from the seed set if the operator prefers not to open standing issues for not-yet-provisioned credentials; see Decision Points below).

**Labels for each issue:** `external-credential-rotation` (mandatory per D3). No `urgent` or `imminent` at seed time — those are applied by `external-credentials-check.yml` (packet 05) based on the computed days-to-expiry on its first scheduled run.

**Assignees:** the operator's GitHub handle (single name today per the inventory's `Owner` column).

### Decision Points

**`status: planned` credentials.** ADR-0083 D3 says non-rotating entries get no standing issue, but is silent on the `status: planned` case. Two reasonable readings:

- **Read A** (default — adopt for this packet): open the standing issue at seed time with the "walkthrough pending the credential going live" body. Invariant 103 reads literally — `Rotates: yes` means an open standing issue, regardless of whether the credential is currently provisioned. The issue is a placeholder until the credential goes live; at that point its title's expiration date is updated and it functions normally.
- **Read B** (alternative): defer opening the standing issue until the credential is provisioned, on the grounds that there is nothing to rotate yet. This requires interpreting 103 more loosely.

This packet adopts **Read A** for two reasons: (1) the literal-invariant reading is the safer default for an early-stage invariant whose enforcement edges have not been tested; (2) keeping the placeholder issue ensures the operator notices at credential-provisioning time that the inventory row exists and is wired through the discipline. If after some operating experience Read B is preferred, a follow-up packet closes the placeholder issues and adds the deferred-open rule to the standup procedure (packet 07's hook material). Out of scope here.

**Inventory back-link.** Whether to add a `**Standing issue:** #N` cell to each `Rotates: yes` inventory row, or leave the back-link implicit. ADR-0083 D2's column shape does not include a "standing issue" column. This packet does **not** add such a column — the back-link is implicit via the title-shape convention (`[Rotate] {credential-name}` is searchable). If a back-link is later useful, it can be added in `Notes` per-row without a column-shape change.

## Affected Files
- None directly in this packet. Issues are opened via `gh issue create`; no file changes are required.
- N/A — packet 01 always writes a real ISO 8601 date per N1 of the refine pass, so this packet's `gh issue create` calls always have parseable dates available. No follow-up inventory edit is needed from this packet.

## NuGet Dependencies
None.

## Boundary Check
- [x] All issues created in `HoneyDrunk.Architecture`. No cross-repo issue creation.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.
- [x] Per Invariant 8, issue titles and bodies carry credential names and dates only, never values.

## Acceptance Criteria
- [ ] One open GitHub issue in `HoneyDrunk.Architecture` exists for each of the 8 `Rotates: yes` rows in the seed inventory: `SONAR_TOKEN`, `NUGET_API_KEY`, `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`
- [ ] Every issue's title matches `[Rotate] {credential-name} — expires {YYYY-MM-DD}` with a real ISO 8601 date (provisional or actual per packet 01's N1 strictness; never `YYYY-MM-DD-pending`)
- [ ] Every issue carries the `external-credential-rotation` label
- [ ] Every issue is assigned to the operator (`Owner` column in the inventory row)
- [ ] Issues for rows 1–5 (`SONAR_TOKEN`, `NUGET_API_KEY`, `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`) link to their per-provider walkthrough under `infrastructure/walkthroughs/` (packets 02/03/04)
- [ ] Issue for `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` notes the walkthrough is pending the webhook-bridge work per ADR-0083 §Follow-up Work
- [ ] Issues for `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` (`status: planned`) note the walkthrough is pending the credential going live; optional `planned` label applied
- [ ] No issues opened for any `Rotates: no` or `Rotates: automated-elsewhere` inventory row (those have no rotation discipline per ADR-0083 D3)
- [ ] Issue bodies never carry credential values — names, expiration dates, and procedure references only (Invariant 8 preserved)
- [ ] No catalog change, no inventory column change (the back-link to standing issues is implicit via title-shape per Decision Points)
- [ ] No `TBD …` placeholder text appears in any inventory row or issue title (packet 01's N1 strictness is preserved end-to-end)

## Human Prerequisites
- [ ] **Replace provisional dates with real `Current Expiration` dates** in the inventory rows for `SONAR_TOKEN`, `NUGET_API_KEY`, `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` if any were still provisional at packet 01 merge time. Fill those in the same review cycle as this packet's PR — the issue title's date is load-bearing for the T-30 / T-7 / T+0 schedule.
- [ ] **Optional: decide on `status: planned` issue posture.** Read A (this packet's default) opens placeholder issues for `ANTHROPIC_API_KEY` and `OPENAI_API_KEY`. If Read B (defer until provisioned) is preferred, close these two issues after creation with a comment explaining the deferral. The operator may decide either way without amending this packet.

## Referenced ADR Decisions
**ADR-0083 D3 — Standing-issue tracking surface.** Every `Rotates: yes` row carries a standing GitHub issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation`, titled `[Rotate] {credential-name} — expires {YYYY-MM-DD}`. Closed on rotation, new issue opened immediately. Non-rotating entries get no standing issue.

**ADR-0083 D7 invariant 103 — Rotation-discipline triplet.** Every `Rotates: yes` row must carry an open standing issue (one of the three triplet conditions; the other two are the `Current Expiration` date and the rotation walkthrough). This packet establishes condition #3 for the seed set.

**ADR-0083 §Follow-up Work — "Open the initial standing rotation issues for the rotation-needing subset."** This packet is exactly that follow-up work.

**ADR-0083 §Follow-up Work — Future walkthroughs (`openclaw-webhook-secret-rotation.md`, etc).** Row 6's issue body explicitly references the pending walkthrough; this packet's body is forward-compatible with later walkthrough additions.

**Invariant 8 — "Secret values never appear in logs, traces, exceptions, or telemetry."** Issue titles and bodies carry names and dates only.

## Constraints
- **No issues for non-rotating rows.** Per ADR-0083 D3 explicit statement: "Non-rotating inventory entries (rows with `Rotates: no` or `Rotates: automated-elsewhere`) do **not** get standing issues — there is nothing to escalate to." Do not open issues for `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, the OIDC federated-credential summary row, Application Insights connection strings, or the Azure Key Vault summary row.
- **Title shape is exact.** `[Rotate] {credential-name} — expires {YYYY-MM-DD}` — capital R, em-dash (Unicode `—`, not ASCII `--`), four-digit year, two-digit month, two-digit day. The `external-credentials-check.yml` workflow (packet 05) searches issues by title; format drift breaks the search.
- **`external-credential-rotation` label is mandatory.** The label is what `external-credentials-check.yml` filters on and what the inventory invariant 103 enforces.
- **No `urgent` or `imminent` label at seed time.** Those labels are applied by the scheduled workflow based on computed days-to-expiry, not at issue creation. Pre-applying them would confuse the workflow's idempotency check (which assumes label additions are tier transitions).
- **Read A for `status: planned` rows.** This packet opens placeholder issues for `ANTHROPIC_API_KEY` and `OPENAI_API_KEY`. The operator may close them later if Read B is preferred; the packet does not preempt that choice.
- **No catalog or inventory-column changes in this packet.** The back-link to standing issues is implicit via title-shape; no new column added.
- **Never write a secret value into an issue title, body, or comment.** Invariant 8 fully preserved.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0083`, `wave-3`

## Agent Handoff

**Objective:** Open 8 standing rotation issues in `HoneyDrunk.Architecture`, one per `Rotates: yes` row in the seed inventory, satisfying invariant 103's rotation-discipline triplet condition #3.

**Target:** `HoneyDrunk.Architecture`, branch from `main` only if the optional inventory edit is needed; otherwise execute via `gh issue create` directly (no PR required for issue creation — the `gh` calls land issues directly on the repo).

**Context:**
- Goal: Seed the standing-tracking surface that `external-credentials-check.yml` (packet 05) escalates against, and that invariant 103 requires.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 3.
- ADRs: ADR-0083 D3 (standing-issue convention), D7 invariant 103 (rotation-discipline triplet); ADR-0083 §Follow-up Work; Invariant 8 (no secret values).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 02, 03, 04 must have merged (issue bodies for rows 1–5 link to the per-provider walkthroughs that those packets ship). Without the walkthroughs landed, the issue body links would be broken at seed time.

**Constraints:**
- No issues for non-rotating rows.
- Title shape is exact: `[Rotate] {credential-name} — expires {YYYY-MM-DD}` with Unicode em-dash.
- `external-credential-rotation` label is mandatory; no `urgent` or `imminent` at seed time.
- Read A for `status: planned` rows — open placeholder issues; operator may close later.
- No catalog or inventory-column changes.
- Never write a secret value (Invariant 8 preserved).

**Key Files:**
- None directly; issue creation is via `gh issue create`. Optional inventory edit only if TBDs in packet 01 need to be filled in the same review cycle.

**Contracts:** None changed.

**PR Body Metadata:**
- If a PR is needed for the optional inventory edit:
  - `Authorship: agent`
  - `Packet: generated/issue-packets/proposed/adr-0083-external-saas-credentials/06-architecture-open-standing-rotation-issues.md`
- If only `gh issue create` calls are needed (no file edits), no PR is opened; the issues themselves are the deliverable.
