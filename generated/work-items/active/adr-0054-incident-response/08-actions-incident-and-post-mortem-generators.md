---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0054", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0054", "ADR-0012"]
accepts: ["ADR-0054"]
wave: 3
initiative: adr-0054-incident-response
node: honeydrunk-actions
---

# Author the HoneyDrunk.Actions incident-record and post-mortem generator workflows

## Summary
Author reusable `HoneyDrunk.Actions` workflows (and / or composite actions) that scaffold a pre-filled incident record at `generated/incidents/YYYY-MM-DD-<slug>.md` and a pre-filled blameless post-mortem at `generated/incidents/post-mortems/YYYY-MM-DD-<slug>.md` from the templates packet 02 ships. Each generator accepts the front-matter inputs (incident_id, severity, optional title), copies the template, substitutes the placeholders, and opens a PR against `HoneyDrunk.Architecture` with the new file ready for the operator to fill in. ADR-0054 D7 commits the template; this packet automates its scaffolding.

## Context
ADR-0054's Follow-up Work names:

- "Author the D7 incident-record template as a generator in `HoneyDrunk.Actions`."
- "Author the D8 post-mortem template as a generator in `HoneyDrunk.Actions`."

ADR-0012 makes `HoneyDrunk.Actions` the Grid's CI/CD control plane. Workflow scaffolds and generators belong here. The generators consume the canonical templates packet 02 ships at `generated/incidents/_templates/` in the `HoneyDrunk.Architecture` repo.

**Two generator workflows.** One for the incident record, one for the post-mortem. Each is `workflow_dispatch`-triggered (operator invokes it manually) and operates in the `HoneyDrunk.Architecture` repo (the destination):

- **Incident record generator** — inputs: `severity` (SEV-1/2/3/4), `title` (short kebab-case slug), `incident_id` (optional — auto-generated as `INC-YYYY-NNNN` from the latest existing record + 1 if omitted), `customer_impact` (yes/no, defaults no), and an alert source list. Steps:
  1. Checkout `HoneyDrunk.Architecture` `main`.
  2. Read `generated/incidents/_templates/incident-record.md`.
  3. Compute the filename: `generated/incidents/YYYY-MM-DD-sevN-<title>.md` (date from `date +%Y-%m-%d` UTC).
  4. Compute `incident_id` if not supplied — scan existing `generated/incidents/*.md` for the highest `INC-YYYY-NNNN`, increment by 1.
  5. Substitute placeholders: `incident_id`, `severity`, `opened_at` (current UTC timestamp), `customer_impact`, `alert_sources`. Leave the other timestamps blank for the operator.
  6. Create a branch, commit the new file, open a PR titled `[INC-YYYY-NNNN] <title>` against `main`. Label `incident-record` on the PR.
  7. Output the PR URL and the new `incident_id` so the operator (or PagerDuty integration) can cross-link.

- **Post-mortem generator** — inputs: `incident_id` (required — the post-mortem's parent incident), `title` (optional — defaults to the incident's title), `participants` (defaults to `[operator]`). Steps:
  1. Checkout `HoneyDrunk.Architecture` `main`.
  2. Read `generated/incidents/_templates/post-mortem.md`.
  3. Compute the filename: `generated/incidents/post-mortems/YYYY-MM-DD-<incident-id-slug>.md`.
  4. Compute `post_mortem_id` (e.g., `PM-YYYY-NNNN` matching the incident's `INC-YYYY-NNNN`).
  5. Substitute placeholders: `incident_id`, `post_mortem_id`, `authored_at` (current UTC timestamp), `participants`.
  6. Read the source incident record's `affected_nodes` / `alert_sources` / `customer_impact` and pre-fill the post-mortem's references where useful.
  7. Create a branch, commit, open a PR titled `[PM-YYYY-NNNN] post-mortem for INC-YYYY-NNNN`. Label `post-mortem`.
  8. Update the source incident record's `post_mortem_link` to the new file's path; flip its `status` to `Reviewing` (per the D6 state transition).

**No GitHub-Issue creation.** These generators emit **markdown files in a PR** to the Architecture repo. They do **not** create GitHub Issues — per the user's "no manual packet filing" feedback and the auto-filing pipeline, GitHub Issues are filed elsewhere. The post-mortem's action items (which become work items per ADR-0008) are filed by the existing packet-filing pipeline once the operator commits the action-item packets into `generated/work-items/active/`.

**Branch and PR conventions.** Match the existing `HoneyDrunk.Actions` reusable-workflow convention: input names, output names, and how the workflow runs against another repo (the Architecture repo, in this case — needs a write-permission token via GitHub App or `GITHUB_TOKEN` with appropriate scope). If a GitHub App is the established cross-repo write surface, use it; if `GITHUB_TOKEN` works for cross-repo writes when the workflow runs in the Architecture repo itself, run it there. Match the existing pattern from `HoneyDrunk.Actions` workflows that write back to other repos.

**Trigger surface.** Both generators are `workflow_dispatch` (operator invokes manually from the Actions UI) and **optionally** `repository_dispatch` so PagerDuty webhook can fire the incident-record generator when a real incident opens. The PagerDuty webhook configuration (per packet 09's alert-wiring work) can post a `repository_dispatch` event with the SEV and title, triggering the generator automatically.

**This is a workflow/YAML packet. No .NET project.** `HoneyDrunk.Actions` is not a versioned .NET solution — no version bump, no `## NuGet Dependencies`-driven project change. The repo's `CHANGELOG.md` (if it keeps one for the workflow surface) is updated per the repo convention.

## Scope
- `.github/workflows/incident-record-generator.yml` (new) — reusable workflow scaffolding the incident record.
- `.github/workflows/post-mortem-generator.yml` (new) — reusable workflow scaffolding the post-mortem.
- A composite action or inline script per workflow for: reading the template, substituting placeholders, computing the next `INC-YYYY-NNNN`, creating the branch + PR. Match the existing `HoneyDrunk.Actions` script style.
- `docs/consumer-usage.md` (or the equivalent docs the reusable workflows reference) — document the new generators and their inputs.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## Proposed Implementation
1. **`incident-record-generator.yml`.** A `workflow_dispatch` + `repository_dispatch` reusable workflow. Inputs: `severity` (SEV-1/SEV-2/SEV-3/SEV-4, required), `title` (kebab-case slug, required), `incident_id` (optional), `customer_impact` (boolean, default false), `alert_sources` (string list, default empty). Steps:
   - Checkout `HoneyDrunk.Architecture` `main` (or run within Architecture repo's Actions; the cleaner pattern is to host the workflow in Architecture and reference Actions' reusable workflows for the heavy lifting — match the existing convention).
   - Compute the next `INC-YYYY-NNNN` if not supplied (scan `generated/incidents/*.md` for the highest, increment).
   - Read the template at `generated/incidents/_templates/incident-record.md`.
   - Substitute the placeholders. Use a small Bash / Python script (whatever matches the repo convention). Note: per the CLAUDE memory about Windows Git Bash CRLF, if the script runs on Windows runners and pipes through `jq` or `gh`, insert `tr -d '\r'` after pipe outputs.
   - Compute the filename: `generated/incidents/YYYY-MM-DD-sevN-<title>.md` (UTC date).
   - Create a branch `incident/INC-YYYY-NNNN-<title>`, commit the new file, push, open the PR via `gh pr create` titled `[INC-YYYY-NNNN] <title>`, label `incident-record`.
   - Output the PR URL and `incident_id`.
2. **`post-mortem-generator.yml`.** A `workflow_dispatch` reusable workflow. Inputs: `incident_id` (required), `title` (optional, defaults to the incident record's title), `participants` (string list, default `[operator]`). Steps:
   - Checkout `HoneyDrunk.Architecture` `main`.
   - Read the source incident record at `generated/incidents/YYYY-MM-DD-...-<incident_id>.md` (or find by glob).
   - Read the template at `generated/incidents/_templates/post-mortem.md`.
   - Compute `post_mortem_id` as `PM-YYYY-NNNN` matching the incident's serial.
   - Substitute placeholders, pre-fill `affected_nodes` / `alert_sources` / `customer_impact` from the source incident record.
   - Compute the filename: `generated/incidents/post-mortems/YYYY-MM-DD-<incident-id>.md`.
   - Update the source incident record's front-matter: `post_mortem_link: ./post-mortems/<new-filename>`, `status: Reviewing`, `reviewing_at: <current UTC>`.
   - Create a branch `post-mortem/PM-YYYY-NNNN`, commit both files (the new post-mortem and the updated incident record), push, open the PR via `gh pr create` titled `[PM-YYYY-NNNN] post-mortem for INC-YYYY-NNNN`, label `post-mortem`.
   - Output the PR URL.
3. **Cross-repo write authentication.** Use the existing pattern `HoneyDrunk.Actions` workflows use for cross-repo PR creation — likely a GitHub App or a PAT stored in repo secrets. If no such pattern exists, run the workflow inside `HoneyDrunk.Architecture` itself (the Architecture repo invokes the reusable workflow from `HoneyDrunk.Actions` and the `GITHUB_TOKEN` writes back to the same repo). Document the choice in the PR.
4. **PagerDuty webhook integration (optional).** Add a `repository_dispatch` trigger to the incident-record generator so packet 09's PagerDuty alert wiring can fire the generator when a real incident opens. PagerDuty's webhook posts a JSON payload; the workflow extracts `severity`, `title`, `alert_sources` from it. Document the PagerDuty webhook payload shape so packet 09 wires the right schema.
5. **Idempotency.** If the same `incident_id` is supplied twice (e.g., PagerDuty re-fires), the generator detects an existing record and exits cleanly (no duplicate file, no duplicate PR). Log a single "incident record already exists" line.
6. **Documentation.** Update `docs/consumer-usage.md` (or the equivalent docs the reusable workflows reference) with the two new generators, their inputs, their outputs, and a worked example. Cross-reference: the templates live in `HoneyDrunk.Architecture/generated/incidents/_templates/` (packet 02); the schema is in `catalogs/contracts.json` (packet 01).
7. **No secret in the workflow.** Use OIDC where possible; otherwise `GITHUB_TOKEN` for same-repo writes. The PagerDuty webhook authentication uses a signed-secret header validated by the workflow — secret in repo secrets, never inline.
8. **No `Thread.Sleep` equivalent.** Workflow waits use `gh pr ready --watch` or polling primitives, never raw `sleep` loops longer than a few seconds.

## Affected Files
- `.github/workflows/incident-record-generator.yml` (new)
- `.github/workflows/post-mortem-generator.yml` (new)
- A composite action or script files (location matches the existing convention)
- `docs/consumer-usage.md` (or the equivalent referenced docs)
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## NuGet Dependencies
None. `HoneyDrunk.Actions` generators are GitHub Actions YAML — no .NET project is created or modified by this packet.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0054 names "Reusable workflow templates for incident-record creation" in Affected Nodes; ADR-0012 makes Actions the CI/CD control plane.
- [x] The generators consume packet 02's templates and write to packet 01's catalog-registered location.
- [x] No code change in any other Node.
- [x] No GitHub-Issue creation — the generators emit markdown files in PRs, not issues; the auto-filing pipeline handles issue creation downstream when action items become packets.

## Acceptance Criteria
- [ ] `.github/workflows/incident-record-generator.yml` exists, supports `workflow_dispatch` and `repository_dispatch`, accepts inputs (severity, title, incident_id, customer_impact, alert_sources), computes the next `INC-YYYY-NNNN`, scaffolds the file from `generated/incidents/_templates/incident-record.md`, opens a PR titled `[INC-YYYY-NNNN] <title>`, labels `incident-record`, outputs the PR URL and incident_id
- [ ] `.github/workflows/post-mortem-generator.yml` exists, supports `workflow_dispatch`, accepts inputs (incident_id, title, participants), scaffolds the file from `generated/incidents/_templates/post-mortem.md`, updates the source incident record's `post_mortem_link` + `status: Reviewing` + `reviewing_at` timestamp, opens a PR titled `[PM-YYYY-NNNN] post-mortem for INC-YYYY-NNNN`, labels `post-mortem`
- [ ] Cross-repo write authentication matches the existing `HoneyDrunk.Actions` convention (GitHub App, PAT, or running the workflow inside `HoneyDrunk.Architecture` with `GITHUB_TOKEN`) — the choice is documented
- [ ] `repository_dispatch` trigger on the incident-record generator accepts a PagerDuty-webhook payload shape so packet 09 can wire it; the payload schema is documented
- [ ] Idempotency: duplicate `incident_id` invocations exit cleanly (no duplicate file, no duplicate PR), logging one "incident record already exists" line
- [ ] No secret in the workflow file; PagerDuty webhook signed-secret header validated against a repo secret (never inline)
- [ ] `docs/consumer-usage.md` documents the two generators, their inputs, outputs, and a worked example; cross-references packet 01's schema and packet 02's templates
- [ ] Windows-runner CRLF guard applied if any pipe through `jq` / `gh` runs on Windows (insert `tr -d '\r'`)
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] Workflows pass the repo's standard YAML lint / shell-lint gates

## Human Prerequisites
- [ ] **Confirm the cross-repo write pattern.** If `HoneyDrunk.Actions` has an existing GitHub App / PAT for cross-repo writes, use it. If not, decide: host the workflow inside `HoneyDrunk.Architecture` (simpler, same-repo `GITHUB_TOKEN`) vs add a new GitHub App (more work). The agent can author either; the operator chooses.
- [ ] **PagerDuty webhook secret seeding (deferred to packet 09).** The `repository_dispatch` payload is signed by PagerDuty; the signing secret is stored in repo secrets. Packet 09's alert-wiring work seeds this secret — not this packet.

## Referenced ADR Decisions
**ADR-0054 D7 — Incident record template.** Every incident produces a markdown file at `generated/incidents/YYYY-MM-DD-<slug>.md`. The generator automates the file creation.

**ADR-0054 D8 — Post-mortem template + cadence.** The post-mortem at `generated/incidents/post-mortems/YYYY-MM-DD-<slug>.md`. The generator automates the file creation and updates the source incident record's `post_mortem_link` and `status: Reviewing`.

**ADR-0054 D6 — Incident lifecycle.** The post-mortem generator's update of `status: Reviewing` is the explicit Resolved → Reviewing state transition; `reviewing_at` timestamp records it.

**ADR-0054 Follow-up Work — Generators in `HoneyDrunk.Actions`.** "Author the D7 incident-record template as a generator in `HoneyDrunk.Actions`. Author the D8 post-mortem template as a generator in `HoneyDrunk.Actions`."

**ADR-0012 — Actions is the CI/CD control plane.** Workflow scaffolds and generators belong in `HoneyDrunk.Actions`.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** PagerDuty webhook signing secret stored in repo secrets; never inline.

- **The generators scaffold files in PRs — not GitHub Issues.** Per the user's "no manual packet filing" feedback and the auto-filing pipeline, the workflow does not create issues. The operator opens the resulting PR, fills in the timeline, and merges. Action items in the post-mortem become work items via the existing packet-filing pipeline.
- **Idempotency:** duplicate invocations exit cleanly.
- **Cross-repo write pattern matches existing convention** — do not invent a new auth scheme.
- **PagerDuty `repository_dispatch` shape is documented** so packet 09 wires it.
- **CRLF guard** if Windows runners pipe through `jq` / `gh`.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0054`, `wave-3`

## Agent Handoff

**Objective:** Author two `HoneyDrunk.Actions` reusable workflows that scaffold the D7 incident record and the D8 blameless post-mortem from the packet 02 templates, opening PRs against `HoneyDrunk.Architecture` with the new files ready for the operator to fill in.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Eliminate the manual copy-template-and-substitute-placeholders step during a real incident so the operator's cognitive load during a SEV-1 is on the incident, not on bookkeeping.
- Feature: ADR-0054 Incident Response rollout, Wave 3.
- ADRs: ADR-0054 D7/D8 (primary), ADR-0054 D6 (state transitions), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — hard. The generators consume the templates packet 02 ships; without those templates the generators have nothing to substitute placeholders into.

**Constraints:**
- Generators emit PRs, not GitHub Issues (per "no manual packet filing").
- Idempotency on duplicate invocations.
- Cross-repo write authentication matches existing pattern.
- PagerDuty `repository_dispatch` payload shape documented so packet 09 wires it.
- Windows-runner CRLF guard for `jq` / `gh` pipes.
- No secret in workflow (invariant 8).

**Key Files:**
- `.github/workflows/incident-record-generator.yml` (new)
- `.github/workflows/post-mortem-generator.yml` (new)
- A composite action or script files
- `docs/consumer-usage.md`

**Contracts:** None — workflow inputs/outputs only.
