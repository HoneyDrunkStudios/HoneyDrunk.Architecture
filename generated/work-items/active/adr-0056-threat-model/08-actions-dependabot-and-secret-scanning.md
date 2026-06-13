---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "meta", "security", "ci-cd", "adr-0056", "wave-4"]
dependencies: ["work-item:00"]
adrs: ["ADR-0056", "ADR-0009", "ADR-0012", "ADR-0044"]
accepts: ["ADR-0056"]
wave: 4
initiative: adr-0056-threat-model
node: honeydrunk-actions
---

# Enable Dependabot + GitHub secret scanning + push protection Grid-wide; wire critical-CVE auto-work-item

## Summary
Operationalize ADR-0056 D7 and D8 in `HoneyDrunk.Actions` (the CI/CD control plane per ADR-0012): (1) add a canonical `dependabot.yml` template that every Grid repo adopts, with security alerts + auto-PR for patch versions / human-merge for minor+major; (2) wire the critical-CVE → auto-work-item flow as a reusable workflow that consumes Dependabot alert webhooks and authors a packet via the existing work-item authoring path; (3) document the Grid-wide GitHub-side security feature enablement (secret scanning, push protection, Dependabot alerts) as a `business/context/`-equivalent operator playbook so the Settings-UI toggles are explicit. The actual GitHub-side enablement is a Human Prerequisite (Settings-UI clicks).

## Context
ADR-0056 D7 (dependency / supply-chain) and D8 (secret scanning) both name GitHub-native tooling as the v1 baseline. The Grid currently has **partial coverage** — per the memory note "ADR-0009 Dependabot stance: alerts yes, auto-PRs no; grouped nightly-deps replaces per-package Dependabot PRs" — so the existing posture is alerts-but-no-auto-PR. ADR-0056 D7 amends that posture: **auto-PR for patch versions is now on**, minor / major still human-merge. ADR-0056 also commits to:

- **Critical-severity CVEs auto-create work items** via a GitHub Actions integration per ADR-0008's work-item authoring path. The packet carries `security` + `priority:critical` labels and routes to the operator's primary queue.
- **GitHub Advanced Security code scanning (CodeQL)** on all public repos (free for public OSS) and on private repos when the per-committer cost is justified (recorded as a future trigger; not enabled now for private repos).
- **GitHub secret scanning** enabled Grid-wide; **push protection** enabled where supported.
- **SBOM generation per release** — tool selection deferred (see packet 09's tracker).

This packet is the **Actions-control-plane surface** for those commitments. Per ADR-0012 (Proposed — naming Actions as the CI/CD control plane) and ADR-0044 (Accepted — review-agent / PR-discipline control plane), the right home for cross-repo CI configuration is `HoneyDrunk.Actions`, not per-Node repos. The pattern: ship the canonical config + a fan-out mechanism here; per-Node repos consume the canonical config via reusable workflow + a thin per-repo `dependabot.yml` that copies the canonical template.

**ADR-0009 reconciliation.** ADR-0009 (Accepted) is the current Grid stance on package scanning: nightly grouped CVE scan + PR-time vulnerability gate, **no Dependabot auto-PRs**. ADR-0056 D7 amends this — Dependabot auto-PR for patch versions is now on (still gated by the existing PR-time vulnerability check from ADR-0009 — auto-merge is **never** introduced; minor/major still require human review per ADR-0044). The amendment lives in `HoneyDrunk.Actions`'s shared config + this packet's docs; ADR-0009 itself is not re-decided (ADR-0056 is the integrating layer per its own D13).

**The Settings-UI enablement is Human-only.** GitHub's Dependabot alerts, secret scanning, and push protection are toggled per-repo (or org-wide via the org's Security Settings). These are portal-clicks, not workflow YAML. The operator follows the playbook this packet ships; the workflow side ships the configurable canonical templates the repos adopt.

**Critical-CVE auto-work-item flow.** ADR-0008 governs work-item authoring (`scope` agent surface). The auto-create path on a Critical CVE:

1. GitHub emits a Dependabot alert webhook on the affected repo.
2. A reusable workflow in `HoneyDrunk.Actions` consumes the webhook (or polls Dependabot alerts on a schedule — fallback if webhook reception is not configured).
3. The workflow filters by severity = Critical.
4. The workflow invokes the work-item authoring path: drafts a packet using a security-tuned variant of the standard template (with CVE ID, affected version range, fix version if available, exploitability assessment as extra fields), labels it `security` + `priority:critical`, files it in the affected repo via `file-work-items.yml`.
5. The packet is **labeled and prioritized** but **not auto-merged**. Even patch-version Dependabot PRs require human review per ADR-0044's invariant 52.

**This packet's scope is narrow.** It ships:
- The canonical `dependabot.yml` template (one file, copy-to-per-repo pattern).
- A reusable workflow at `.github/workflows/job-cve-to-packet.yml` (or similar) that consumes Dependabot alerts and authors a packet.
- A `business/context/`-equivalent operator playbook documenting the Settings-UI toggles required Grid-wide (Dependabot alerts, secret scanning, push protection, CodeQL on public repos) — placed in `HoneyDrunk.Actions/docs/security-tooling-enablement.md` or the established cross-cutting-docs location.

It does **not** ship:
- Per-repo `dependabot.yml` adoption PRs (downstream task; the canonical template is the start; per-repo adoption follows the same pattern as the `pr-core.yml` fan-out).
- The actual GitHub-side enablement (Human Prerequisite).
- SBOM tooling selection (deferred per packet 09).

**This is a workflow/YAML + docs packet. No .NET project.** `HoneyDrunk.Actions` is not a versioned .NET solution.

## Scope
- A canonical `dependabot.yml` template in `HoneyDrunk.Actions` for per-repo adoption.
- A reusable workflow `.github/workflows/job-cve-to-packet.yml` (or equivalent) consuming Dependabot alerts and authoring packets.
- A `docs/security-tooling-enablement.md` operator playbook documenting GitHub Settings-UI toggles.
- The repo `CHANGELOG.md` if `HoneyDrunk.Actions` keeps one for the workflow surface.

## Proposed Implementation

### 1. Canonical `dependabot.yml` template

Place at a canonical location in `HoneyDrunk.Actions` — verified at edit time:
- If `HoneyDrunk.Actions/templates/dependabot.yml` exists, amend it.
- If no template exists, create `HoneyDrunk.Actions/templates/dependabot.yml`.

Content (Dependabot config — see Dependabot v2 schema):

```yaml
# Canonical dependabot.yml for HoneyDrunk Grid repos.
# Per ADR-0056 D7 + ADR-0009 reconciliation: alerts on; auto-PR for patches; minor/major human-merge.
# Adopt by copying to .github/dependabot.yml at the consumer repo's root.

version: 2
updates:
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    versioning-strategy: "increase-if-necessary"
    # Auto-PR is on for security alerts; the pr-core.yml gate (per ADR-0044 invariant 52) reviews them.
    # Patch-version updates are auto-PR'd; minor/major are also PR'd but explicitly require human merge per ADR-0044.
    # No auto-merge anywhere — even patch versions go through review.
    allow:
      - dependency-type: "all"
    labels:
      - "dependencies"
      - "dependabot"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "dependabot"
      - "ci"
  # Add `npm`, `pip`, etc. ecosystems as repos adopt them.
```

Document the per-repo adoption recipe in `HoneyDrunk.Actions`'s consumer-usage docs (the established docs location for reusable-workflow consumer instructions): copy the template to `<repo>/.github/dependabot.yml`, customize ecosystems for the repo (a Studios repo also has `npm`; a Lore repo has none).

### 2. Critical-CVE auto-work-item reusable workflow

Place at `HoneyDrunk.Actions/.github/workflows/job-cve-to-packet.yml` (or the established reusable-workflow naming convention).

The workflow:

```yaml
# Reusable workflow: consume Dependabot security alerts and author critical-severity work items.
# Per ADR-0056 D7. Invoked on a schedule (cron) and/or via repository_dispatch from Dependabot alert webhooks.
# Authors packets via the file-work-items.yml work-item authoring path (per ADR-0008).
# Critical-severity only; non-critical alerts ride Dependabot's standard PR flow.

name: job-cve-to-packet

on:
  workflow_call:
    inputs:
      target-repo:
        description: "The repo whose Dependabot alerts to scan."
        required: true
        type: string
      severity-threshold:
        description: "Severity floor — only alerts at or above this severity author packets."
        required: false
        type: string
        default: "critical"

permissions:
  contents: read
  issues: write
  security-events: read

jobs:
  scan-and-author:
    runs-on: ubuntu-latest
    steps:
      - name: Fetch active Dependabot alerts
        run: |
          # Use the GitHub CLI or REST API to fetch open Dependabot alerts for the target repo.
          # gh api /repos/{owner}/{repo}/dependabot/alerts?state=open
          # Filter by severity == critical (or the threshold input).
          # ...
      - name: Draft packet content per alert
        run: |
          # For each critical alert, prepare packet content with:
          # - CVE ID
          # - Affected package + version range
          # - Fix version (if available)
          # - Exploitability assessment (from the alert's `security_vulnerability` block)
          # - Generated packet filename: generated/work-items/active/standalone/{YYYY-MM-DD}-{repo}-cve-{cve-id}.md
          # - Frontmatter: type=bug-fix, tier=2, labels=["security", "priority:critical", "cve", "tier-2"]
          # - dependencies: []
          # - target_repo from input
          # ...
      - name: Commit packet to HoneyDrunk.Architecture
        run: |
          # The packet is written to HoneyDrunk.Architecture (the work-item substrate),
          # which file-work-items.yml then files as an issue in the target repo on push to main.
          # Use a deploy key or PAT scoped to HoneyDrunk.Architecture.
          # ...
```

The workflow is **scaffolded but not fully implemented** in this packet — the implementation requires Dependabot webhook plumbing or scheduled API polling, both of which require operator-side credentials decisions. This packet ships the workflow file with the documented behavior + commented-out implementation steps as a starter. The fuller implementation is a follow-up if the auto-create path becomes load-bearing.

**Why scaffold-not-implement:** the load-bearing claim of D7 is that critical CVEs become work items. Whether that happens via webhook or via scheduled-polling is an implementation detail the operator decides based on operational preference. The workflow's surface shape (inputs, outputs, permissions, target file location) is the part that needs to be canonical; the polling-vs-webhook decision is downstream.

### 3. Operator playbook for GitHub Settings-UI enablement

Place at `HoneyDrunk.Actions/docs/security-tooling-enablement.md`. Operator-facing playbook:

```markdown
# GitHub security tooling enablement (Grid-wide)

> Per ADR-0056 D7 + D8. This is operator-facing — the toggles are clicked in the GitHub Settings UI, not configured in YAML.

## Org-level settings (HoneyDrunkStudios org)

Navigate to: https://github.com/organizations/HoneyDrunkStudios/settings/security_analysis

Enable Grid-wide:
- [ ] **Dependabot alerts** — Enable for all repositories (public + private).
- [ ] **Dependabot security updates** — Enable for all repositories (auto-PR on alert).
- [ ] **Dependency graph** — Enable for all repositories.
- [ ] **Secret scanning** — Enable for all repositories (free for public, GHAS-included for private — see cost note below).
- [ ] **Push protection for secret scanning** — Enable Grid-wide. Blocks pushes containing detected secrets at the push gate.
- [ ] **Code scanning** — Enable on all public repos (free CodeQL default setup). On private repos: deferred until per-committer cost is justified (see GHAS cost note).

## GitHub Advanced Security (GHAS) — private repo cost note

GHAS bundles secret scanning + push protection + code scanning for private repos. Cost: per-active-committer per month at the time of writing. At studio scale with one active committer, the cost is bounded; with N active committers the cost scales linearly.

- Enable GHAS on private revenue-bearing repos (Notify Cloud, future Billing) as a Grid-wide-default-on baseline.
- Defer GHAS on private experimental repos until they have material traffic.

The cost-tier decision is the operator's at-edit-time call. The default Grid-wide answer per ADR-0056 D7 is "secret scanning on private = on (via GHAS)."

## Per-repo configuration

Each Grid repo carries `.github/dependabot.yml` copied from the canonical template at `HoneyDrunk.Actions/templates/dependabot.yml`. Per-repo adoption is a small PR per repo; the fan-out follows the same pattern as the `pr-core.yml` rollout. {Reference the existing fan-out doc if one exists.}

## Backlog burn-down

When Dependabot is enabled Grid-wide, an initial wave of CVE alerts will surface — historical accumulation across all repos. **Expect 50-200 alerts on day one**, of which 5-20 will be critical / high. The operator triages:

1. Critical: rotate or update immediately (within the runbook from packet 06's time-to-rotation targets if a secret is involved; otherwise update the dependency).
2. High: update within the standard sprint cadence.
3. Medium / Low: triage during the next quarterly review.

Schedule the backlog burn-down for the first 1-2 weeks after enablement. Steady-state volume is much lower.

## Historical secret-scan triage

When push protection is enabled, GitHub scans history and may flag secrets committed and rotated months/years ago. Triage per the found-secret runbook (`business/context/found-secret-rotation-runbook.md`, packet 06): even historical leaks may need re-rotation if the value is still active anywhere.

## Cross-references

- ADR-0056 D7 (Dependabot + supply chain).
- ADR-0056 D8 (secret scanning).
- ADR-0009 (existing package-scanning posture; this enablement amends to allow auto-PR for patches).
- ADR-0012 (Proposed — Actions is the CI/CD control plane; canonical config lives here).
- ADR-0044 invariant 52 (every non-draft PR runs the review agent — applies to Dependabot PRs).
- Found-secret runbook (packet 06) — what to do when scanning finds something.
```

### 4. Repo `CHANGELOG.md` (if maintained)

If `HoneyDrunk.Actions` keeps a `CHANGELOG.md` for the workflow surface, append an entry under the current in-progress version (or create a dated entry) noting:
- Canonical `dependabot.yml` template added.
- `job-cve-to-packet.yml` reusable workflow scaffolded.
- Security-tooling-enablement playbook documented.

## Affected Files
- `HoneyDrunk.Actions/templates/dependabot.yml` (canonical template).
- `HoneyDrunk.Actions/.github/workflows/job-cve-to-packet.yml` (scaffolded reusable workflow).
- `HoneyDrunk.Actions/docs/security-tooling-enablement.md` (operator playbook).
- `HoneyDrunk.Actions/CHANGELOG.md` if the repo keeps one for workflow-surface changes.
- `HoneyDrunk.Actions/docs/consumer-usage.md` (or equivalent) extended with the dependabot.yml adoption recipe.

## NuGet Dependencies
None. `HoneyDrunk.Actions` is not a versioned .NET solution. No .NET project is created or modified.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo per the routing rule "workflow, CI, GitHub Actions, pipeline → HoneyDrunk.Actions" and per ADR-0012 (Proposed — Actions is the CI/CD control plane).
- [x] No code change in any Node — the canonical `dependabot.yml` is copied per-repo; that fan-out is a downstream task, not in this packet.
- [x] The org-level / repo-level Settings-UI enablement is a Human Prerequisite — explicit, not implicit.

## Acceptance Criteria
- [ ] `HoneyDrunk.Actions/templates/dependabot.yml` exists as the canonical Dependabot config with: weekly NuGet + github-actions ecosystem updates; auto-PR allowed; no auto-merge anywhere; appropriate labels (`dependencies`, `dependabot`, `ci` where applicable); 10 open-PR limit; explicit comment lines naming ADR-0056 D7 + ADR-0009 reconciliation + ADR-0044 invariant 52
- [ ] `HoneyDrunk.Actions/.github/workflows/job-cve-to-packet.yml` exists as a scaffolded reusable workflow (with documented behavior + commented-out implementation steps for either webhook or scheduled-polling path) authoring critical-severity packets into `HoneyDrunk.Architecture`'s `generated/work-items/active/standalone/` substrate via the existing work-item authoring path
- [ ] `HoneyDrunk.Actions/docs/security-tooling-enablement.md` exists as the operator playbook covering: org-level Dependabot alerts / security updates / dependency graph / secret scanning / push protection / code scanning toggles; GHAS cost-tier decision for private repos; per-repo `dependabot.yml` adoption recipe; backlog burn-down expectations (50-200 day-one alerts, 5-20 critical/high); historical secret-scan triage cross-reference to packet 06
- [ ] Consumer-usage docs are extended with the `dependabot.yml` adoption recipe
- [ ] `HoneyDrunk.Actions/CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] No per-repo `dependabot.yml` adoption PR is filed by this packet — that is a downstream task
- [ ] No org-level Settings-UI toggle is clicked by the packet — that is a Human Prerequisite

## Human Prerequisites
- [ ] Enable Dependabot alerts org-wide at https://github.com/organizations/HoneyDrunkStudios/settings/security_analysis. The user prefers portal-first; this is a portal click.
- [ ] Enable Dependabot security updates org-wide (the auto-PR-for-alerts behavior; auto-merge stays off).
- [ ] Enable GitHub secret scanning org-wide. Free for public; included with GHAS for private — decide the private-repo cost question for revenue-bearing repos.
- [ ] Enable push protection for secret scanning org-wide.
- [ ] Enable CodeQL code scanning on all public repos (free default setup).
- [ ] Decide private-repo GHAS cost-tier — default per ADR-0056 D7 is "secret scanning on private = on (via GHAS)."
- [ ] Triage the initial CVE backlog (1-2 weeks of operator time, 50-200 alerts expected day-one with 5-20 critical/high) — per the operator playbook section.
- [ ] Triage the initial historical secret-scan triage — push protection scans history on enablement; expect findings from rotated-long-ago secrets. Use packet 06's runbook.
- [ ] Per-repo adoption of `.github/dependabot.yml` from the canonical template — small PR per repo, follows the existing fan-out pattern.

## Referenced ADR Decisions
**ADR-0056 D7 — Dependency / supply-chain scanning.** Dependabot Grid-wide; auto-PR for patches with human merge; critical CVEs auto-create work items; CodeQL on public repos free; SBOM tool deferred (packet 09 tracker).

**ADR-0056 D8 — Secret scanning.** GitHub-native secret scanning Grid-wide; push protection where supported; optional local hooks (`git-secrets`, `gitleaks`) at repos with hook infrastructure; the found-secret runbook (packet 06) governs response.

**ADR-0009 — Existing package-scanning posture.** Nightly grouped CVE scan + PR-time vulnerability gate. This packet's amendment: Dependabot auto-PR for patches is on; minor/major still human-merge; no auto-merge anywhere. The PR-time vulnerability gate from ADR-0009 still runs on every PR including Dependabot's.

**ADR-0012 (Proposed) — Actions as CI/CD control plane.** Canonical CI configuration lives in `HoneyDrunk.Actions`, not per-Node repos. The shared templates and reusable workflows in this packet follow that posture.

**ADR-0044 — PR discipline and review-agent.** Invariant 52: every non-draft PR on an enabled repo runs the cloud-wired `review` agent. Dependabot PRs are not exempt — they run through the same review surface.

**ADR-0008 — Issue-packet authoring.** The critical-CVE auto-create path produces packets via the standard authoring surface; the packet template is a security-tuned variant of the standard.

## Constraints
- **No auto-merge anywhere.** Even patch-version Dependabot PRs go through review per ADR-0044 invariant 52. The dependabot.yml allows auto-PR but never auto-merge.
- **The reusable workflow is scaffolded, not fully implemented.** The webhook-vs-polling decision is an operator-side choice; this packet ships the workflow file's surface + documented behavior + commented-out implementation steps. Full implementation is a follow-up if needed.
- **Settings-UI enablement is Human Prerequisite, not in-PR YAML.** GitHub's Dependabot / secret scanning / push protection / CodeQL toggles are portal clicks. The operator playbook documents the clicks.
- **No per-repo adoption PRs filed.** The canonical template exists; per-repo PRs follow the same fan-out pattern as `pr-core.yml`. Filing 11+ PRs at once is downstream work, not this packet.
- **Critical-only auto-create.** High / Medium / Low severities ride Dependabot's standard PR flow without packet creation. Critical alone gets the packet — D7 is explicit.
- **PR-time vulnerability gate from ADR-0009 still runs.** This packet does not remove the existing per-PR scan; it adds Dependabot alerts as a complementary surface.

## Labels
`feature`, `tier-2`, `meta`, `security`, `ci-cd`, `adr-0056`, `wave-4`

## Agent Handoff

**Objective:** Land the canonical `dependabot.yml` template + the scaffolded `job-cve-to-packet.yml` reusable workflow + the operator playbook for GitHub-side security tooling enablement, in `HoneyDrunk.Actions`.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make the Grid-wide Dependabot + secret scanning + push protection + critical-CVE-auto-work-item posture concrete and discoverable, with the Settings-UI clicks documented for the operator and the canonical workflow/config in the CI/CD control plane.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 4.
- ADRs: ADR-0056 D7 + D8 (primary), ADR-0009 (existing scanning — amended), ADR-0012 (Proposed — Actions as CI/CD control plane), ADR-0044 (review-agent on every PR including Dependabot's), ADR-0008 (work-item authoring path).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0056 should be Accepted before the operational tooling lands.

**Constraints:**
- No auto-merge anywhere — patch-version Dependabot PRs go through review.
- Reusable workflow scaffolded with documented behavior + commented-out implementation steps; full implementation deferred until webhook-vs-polling decision is made.
- Settings-UI enablement is Human Prerequisite.
- No per-repo adoption PRs filed.
- Critical-only auto-create; non-critical rides Dependabot's standard PR flow.
- Existing PR-time vulnerability gate from ADR-0009 still runs.

**Key Files:**
- `HoneyDrunk.Actions/templates/dependabot.yml`
- `HoneyDrunk.Actions/.github/workflows/job-cve-to-packet.yml`
- `HoneyDrunk.Actions/docs/security-tooling-enablement.md`
- Consumer-usage docs (extended)
- `HoneyDrunk.Actions/CHANGELOG.md` if maintained

**Contracts:** None — workflow + template + docs only.
