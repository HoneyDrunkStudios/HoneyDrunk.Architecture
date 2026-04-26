---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "automation", "adr-0008"]
dependencies: []
adrs: ["ADR-0008"]
initiative: standalone
node: honeydrunk-actions
---

# Feature: GitHub Action that mirrors issue labels into The Hive project v2 custom fields

## Summary
Build a reusable GitHub Actions workflow in `HoneyDrunk.Actions` that listens for issue events across every org repo and mirrors well-known labels (`wave-N`, `adr-NNNN`, `tier-N`) plus the issue's source repo onto the corresponding GitHub Projects v2 custom fields on the org-level board "The Hive" (project #4). This closes the ADR-0008 D4 gap: D4 assumes the board "mirrors labels into custom fields via workflow automation," but GitHub Projects v2 does not ship that capability — it has auto-add, auto-close, and auto-archive workflows, but no label→field mapping. Without this workflow, every issue filed across the Grid requires a manual CLI backfill to get its Wave, Node, Tier, and ADR fields populated.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
The ADR-0005/0006 rollout (2026-04-10) exposed this gap in practice. After filing 11 issues across 9 repos, every one landed on The Hive board with `Status=Backlog` but all other custom fields empty — Wave, Initiative, Node, Tier, and ADR were blank. A one-off `gh project item-edit` backfill pass got them populated, but that's not a sustainable pattern: every future issue filed to any org repo would need the same manual pass. The board becomes a second-class tracking surface unless field population is automated.

ADR-0008 D4 reads: *"Labels are authoritative in the issue; the board mirrors them into custom fields via workflow automation."* That's the promised contract. This packet delivers it.

## Proposed Implementation

### Workflow file: `.github/workflows/hive-field-mirror.yml`

A reusable workflow in `HoneyDrunk.Actions` that:

- **Triggers** on `issues.opened`, `issues.labeled`, `issues.unlabeled`, `issues.edited`, and is callable via `workflow_call` so individual repos can also dispatch it deliberately
- **Auth** via a fine-grained GitHub App installation token (preferred) or an organization-level PAT with these scopes:
  - `repository:issues:read` on every org repo
  - `organization_projects:write` on HoneyDrunkStudios
  - Stored as the org secret `HIVE_FIELD_MIRROR_TOKEN`
- **Uses the Projects v2 GraphQL API** — specifically `addProjectV2ItemById` (idempotent — if the item is already on the board, it returns the existing item ID) and `updateProjectV2ItemFieldValue` for each field
- **Field mapping rules:**

| Source | Target field | Logic |
|---|---|---|
| Issue label `wave-1` / `wave-2` / `wave-3` | `Wave` (single select) | Direct mapping to "Wave 1" / "Wave 2" / "Wave 3" option. If no wave label, set to `N/A`. |
| Issue labels matching `adr-\d{4}` | `ADR` (text) | Comma-join all matched labels in uppercase: `"ADR-0005, ADR-0006"`. |
| Issue label `tier-1` / `tier-2` / `tier-3` | `Tier` (single select) | Direct mapping. If absent, leave unchanged (do NOT overwrite a human-set value with empty). |
| Issue's source repo (`github.event.repository.name`) | `Node` (single select) | Lookup via embedded `repo-to-node.yml` mapping (see below). |
| Issue label matching `initiative-<slug>` | `Initiative` (single select) | Optional — only set if the label exists and a matching option exists on the field. |

- **Repo → Node lookup table** (stored in the workflow repo as `.github/config/repo-to-node.yml`):

```yaml
HoneyDrunk.Kernel: honeydrunk-kernel
HoneyDrunk.Transport: honeydrunk-transport
HoneyDrunk.Vault: honeydrunk-vault
HoneyDrunk.Vault.Rotation: honeydrunk-vault
HoneyDrunk.Auth: honeydrunk-auth
HoneyDrunk.Web.Rest: honeydrunk-web-rest
HoneyDrunk.Data: honeydrunk-data
HoneyDrunk.Pulse: pulse
HoneyDrunk.Notify: honeydrunk-notify
HoneyDrunk.Actions: honeydrunk-actions
HoneyDrunk.Architecture: honeydrunk-architecture
HoneyDrunkStudios: honeydrunk-studios
```

- **Does NOT touch:**
  - `Status` field — the human owns Status transitions (Backlog → Ready → In Progress / In Progress – Agent → Done)
  - `Title`, `Labels`, `Repository`, `Linked pull requests` — these are built-in fields GitHub populates automatically
  - `Initiative` when absent — do not overwrite human-set values

- **Idempotent** — running the workflow twice on the same issue with the same labels produces no net change. Safe to rerun on error.

### Caller-side integration

Each repo that wants its issues mirrored must either:
- Enable the repo in the auto-add workflow on The Hive (see ADR-0008 D5) — then this workflow fires on every `issues.*` event via a repo-level dispatch workflow, or
- Add a one-line `.github/workflows/hive-mirror.yml` that calls the reusable workflow on `issues.*` events. A copy-pasteable snippet lives in the Actions README.

### Documentation
- `README.md` section in `HoneyDrunk.Actions` covering: what it does, how to enable it per repo, the field mapping table, how to add new Nodes to the lookup table, how to rotate the token.
- Cross-link from ADR-0008 D4 once this packet lands (separate small ADR edit, not part of this packet).

### Backfill script: `scripts/hive-backfill-issue.sh`
A thin shell script that invokes the same GraphQL calls for a single issue by URL, so one-off backfills can be run from the terminal. Useful when an issue was filed before this workflow existed, or when the workflow failed for any reason. Takes `--url` as input.

## Affected Packages
- None (CI and tooling only)

## Boundary Check
- [x] CI plumbing and cross-repo automation live in `HoneyDrunk.Actions` per routing rules
- [x] Projects v2 integration is a meta concern — fits Actions, not Architecture (Architecture holds the specs, Actions runs them)
- [x] No runtime contract changes to any Node
- [x] Repo → Node lookup table mirrors `catalogs/nodes.json` but is intentionally duplicated — cross-repo data fetch at workflow run time adds fragility for small benefit. Drift risk is small and visible (one config file, handful of entries).

## Acceptance Criteria
- [ ] `hive-field-mirror.yml` exists and is callable via `workflow_call`
- [ ] `repo-to-node.yml` lookup table exists with every current deployable and library Node
- [ ] Filing a test issue in `HoneyDrunk.Actions` itself with labels `wave-1, adr-0008, tier-2` results in the Hive board item having Wave=Wave 1, ADR="ADR-0008", Tier=2, Node=honeydrunk-actions within 30 seconds
- [ ] Removing the `wave-1` label updates the field to `N/A` within 30 seconds
- [ ] Re-running the workflow on the same issue is a no-op (idempotent)
- [ ] Auth via fine-grained token stored as org secret `HIVE_FIELD_MIRROR_TOKEN`; no client secrets anywhere
- [ ] `README.md` documents per-repo enablement, the field mapping table, and token rotation
- [ ] `scripts/hive-backfill-issue.sh` works against a single issue URL
- [ ] Workflow passes `actionlint`
- [ ] Status field is never written by the workflow (verified by a test that sets Status=Ready before running the workflow and asserts it's still Ready after)

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. The token used by this workflow is a GitHub-managed secret, not a runtime secret — invariant 9 doesn't apply (it governs Node runtime, not CI tokens), but the token should still rotate via the same discipline.

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools. (This workflow is what makes the Issue-plus-board lifecycle work seamlessly across the Grid.)

> **Invariant 24:** Issue packets are immutable specifications. State lives on the Project board, never in the packet file. (The board is the source of truth for live state — so keeping its fields accurate via this workflow is load-bearing.)

## Referenced ADR Decisions

**ADR-0008 (Work Tracking and Execution Flow):** Single org-level GitHub Project v2 "The Hive" as the cross-repo board. Issues live in target repos; board aggregates them. Labels are authoritative; board mirrors labels into custom fields.
- **§D3 — Canonical custom field schema:** `Status`, `Wave`, `Initiative`, `Node`, `Tier`, `ADR`. Six fields must be populated for every tracked item.
- **§D4 — Canonical label conventions:** `wave-{N}`, `adr-{NNNN}`, `tier-{N}`, `blocked`. "The board mirrors them into custom fields via workflow automation." ← **this packet delivers the workflow.**
- **§D5 — Auto-add via org-wide repo filter:** auto-add workflow with `repo:HoneyDrunkStudios/*` filter. Complementary but orthogonal — auto-add puts items on the board; this packet sets their fields.

## Context
- ADR-0008 D4 promised the mirroring but didn't specify an implementation — this packet fills that gap.
- The ADR-0005/0006 rollout (2026-04-10) exposed the gap in practice: 11 issues landed on the board with empty fields and required a manual `gh project item-edit` backfill.
- Projects v2 GraphQL API docs: https://docs.github.com/en/graphql/reference/mutations#updateprojectv2itemfieldvalue
- Field IDs and option IDs for The Hive project are discoverable via `gh project field-list 4 --owner HoneyDrunkStudios --format json` at workflow runtime — no need to hardcode IDs; look them up lazily and cache per run.

## Dependencies
None — standalone packet.

**Not blocked on, but related to:**
- ADR-0008 D5 auto-add workflow enablement (one-time portal task). If that workflow isn't enabled, issues still need `gh project item-add` before this mirror workflow can find them on the board. Both should exist together for the full automation story.

## Labels
`ci`, `tier-2`, `ops`, `automation`, `adr-0008`

## Agent Handoff

**Objective:** Deliver the GitHub Action that automatically populates The Hive board's custom fields from issue labels and the source repo, so ADR-0008 D4 holds true in practice.
**Target:** HoneyDrunk.Actions, branch from `main`
**Context:**
- Goal: Close the ADR-0008 D4 mirroring gap so no future issue requires manual field backfill
- Feature: Grid-wide work tracking automation
- ADRs: ADR-0008 (Work Tracking and Execution Flow)

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:** None. The workflow stands alone; it doesn't need any Wave 1/2 Vault packets or the OIDC workflow to be in place.

**Constraints:**
- **Idempotency is non-negotiable.** The workflow will re-fire on every label change, and on every edit event. Running it ten times in a row must produce identical board state.
- **Never write Status.** That's human-owned. Test explicitly.
- **Graceful on missing options.** If an issue has a label like `wave-4` that doesn't map to a real Wave option, log a warning and skip that field — do not fail the workflow.
- **Token security:** fine-grained installation token or org PAT, stored in org secrets, not exposed in logs. Follow invariant 8 discipline even though it governs runtime secrets not CI tokens.
- **No hardcoded project/field IDs in the workflow file.** Look them up at runtime via the GraphQL introspection calls so a new field on The Hive doesn't break the workflow.
- **Must work with or without ADR-0008 D5 auto-add enabled.** If the item isn't on the board yet, add it first (`addProjectV2ItemById` handles this).

**Key Files:**
- `.github/workflows/hive-field-mirror.yml` (new, reusable)
- `.github/config/repo-to-node.yml` (new)
- `scripts/hive-backfill-issue.sh` (new)
- `README.md` (update — per-repo enablement docs, field mapping table, token rotation)

**Contracts:**
- Reusable workflow input interface: `project-number` (default `4`), `project-owner` (default `HoneyDrunkStudios`)
- `HIVE_FIELD_MIRROR_TOKEN` org secret naming convention
- `repo-to-node.yml` schema — one-line repo-name → node-id mapping
