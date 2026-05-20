# Dispatch Plan: ADR-0033 Environment-Gated Deploy-Trigger Model

**Date:** 2026-05-20
**Trigger:** ADR-0033 (Environment-Gated Deploy-Trigger Model for Deployable Nodes) Proposed 2026-05-18 — scoped 2026-05-20.
**Type:** Multi-repo (per-deployable consumer-workflow amendments across two repos; no control-plane PR).
**Sector:** Ops.
**Site sync required:** No. ADR-0033 governs consumer release-workflow trigger policy and changes nothing user-facing.

**Rollback plan:**
- Each packet edits a single workflow file in a single repo. Revert per packet via `git revert` — the workflow returns to tag-only triggering, the `resolve` job goes back to its hard-coded `environment: dev`, the `concurrency` block disappears, and the header comment goes back to the dev-only/tag-only framing. No data loss, no consumer breakage (consumer release workflows are not themselves consumed by anything).
- No Azure resources, no secrets, no GitHub Environment changes provisioned by this initiative. Nothing to deprovision.
- A partially-reverted state (e.g. packet 01 reverted, 02 still in) is operationally fine — the three workflows are independent. A revert on the Notify Worker (packet 02) without a matching revert on Notify Functions (packet 01) means the Functions line keeps its dual-trigger model and the Worker line goes back to tag-only — no shared state to corrupt.

## Summary

ADR-0033 resolves the explicitly-deferred staging/prod gating question left by ADR-0015 and the dev-only/tag-only follow-up already named in the three release workflows' headers. The decision is a **hybrid, environment-gated trigger model** implemented entirely in consumer release workflows — no `HoneyDrunk.Actions` change, no new invariants, no `catalogs/relationships.json` edge change.

Each consumer release workflow gains:
- a path-filtered `push: branches: [main]` trigger (continuous dev deploy);
- an explicit trigger-to-environment mapping in the `resolve` job (`target_environment` output as the single anchor for future staging/prod conditional);
- a `concurrency` block keyed on the resolved environment (dev `cancel-in-progress: true`, tag path `cancel-in-progress: false`);
- a header comment that replaces the current "dev-only / tag-only — intentional, not a gap" framing with the dual-trigger model.

The existing SemVer tag triggers (`functions-v*`, `worker-v*`, `collector-v*`) are preserved unchanged — they remain the promotion trigger for staging/prod (when provisioned). The version-of-record rule (CHANGELOG + SemVer tag) is untouched; push-to-`main` dev deploys are explicitly **not** a promotion source.

**Three packets across two repos, one wave:**

- 1 Notify packet for `release-functions.yml` (Functions deployable)
- 1 Notify packet for `release-worker.yml` (Worker deployable)
- 1 Pulse packet for `release-collector.yml` (Collector deployable)

The three workflow amendments are independent — same logical change, three different files in two repos. They can land in any order. Each packet carries `accepts: ["ADR-0033"]` so the `hive-sync` auto-flip will move ADR-0033 from Proposed to Accepted once all three implementing issues close (capped by `MAX_FLIPS_PER_RUN=3`, fine here — only one ADR is implicated).

## Important constraints (from ADR-0033 itself and the scope brief)

- **HoneyDrunk.Actions gets NO change packet.** ADR-0033 D8 / Affected Nodes pins this explicitly. The reusable deploy workflows in `HoneyDrunk.Actions` (`job-deploy-function.yml`, `job-deploy-container-app.yml`) already take an `environment` input and have no opinion about what triggered the caller. Trigger policy is consumer-owned by construction (a `workflow_call` reusable workflow cannot own the caller's `on:` block). The ADR-0012 invariant on reusable workflows is preserved exactly as written — this initiative does not touch it.
- **Two LOW-PRIORITY follow-ups are NOT scoped here, by direction.**
  - Extending the ADR-0012 grid-health aggregator to track release workflows is named in ADR-0033 Follow-up Work but explicitly low priority / not committed. Not in this initiative.
  - A Container App inactive-revision retention/GC policy as a possible ADR-0015 amendment is named as low priority. Not in this initiative.
  Both are deliberately deferred. Re-scope them later if dev revision accumulation or release-workflow-silent-no-op surface as concrete problems.
- **`accepts: ["ADR-0033"]` on every packet.** ADR-0033 stays Proposed at scope time; per the established ADR acceptance workflow and the `hive-sync` auto-flip rule, the ADR flips to Accepted when **every** packet carrying `accepts: ADR-0033` closes on GitHub. Three packets — all three must close. No acceptance packet is included in this initiative (and ADR-0033 itself is not edited by any packet here).
- **No shared-index-file edits.** Per the scope brief, this initiative does not touch `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `adrs/README.md`, `catalogs/*.json`, or any other shared index file. Those are `hive-sync` outputs — the agent will surface ADR-0033 in `proposed-adrs.md` automatically until the three packets close, then flip it.
- **Header comment doc convention.** No ADR number in any workflow header comment, code comment, README prose, or CHANGELOG entry text. The runtime packet-data identifier `adr-0033` is acceptable only as packet frontmatter.
- **CHANGELOG, not Unreleased.** Per the no-Unreleased-commits convention, each packet's CHANGELOG entry lands under a dated SemVer section, not under `Unreleased`. Per-repo sequencing details are spelled out in § CHANGELOG sequencing below — the in-packet bodies defer to this section rather than carrying their own sequencing rules (which would push against packet immutability when execution order shifts).
- **No `.csproj` version bump.** All three packets are CI/workflow-only — no source-tree change, no runtime artifact change. Invariant 27 (one solution version, all projects move together) does not apply to workflow-only changes.

## Cross-packet sanity checks (D4 enforcement)

Two of the three packets live in HoneyDrunk.Notify, which has two deployables. D4 (per-deployable independence) is enforced **across** packets 01 and 02 — neither one alone can satisfy it.

| Packet | Workflow | Filter must include | Filter must NOT include |
|---|---|---|---|
| 01 | `release-functions.yml` | `HoneyDrunk.Notify.Functions/**` + solution-level inputs | any `HoneyDrunk.Notify.Worker/**` path |
| 02 | `release-worker.yml` | `HoneyDrunk.Notify.Worker/**` + solution-level inputs | any `HoneyDrunk.Notify.Functions/**` path |
| 03 | `release-collector.yml` | `Pulse.Collector/**` + Pulse libraries it links against + solution-level inputs | (single-deployable repo — D4 trivially satisfied) |

Reviewer instruction: when reviewing packet 01's PR, also look at the current state of `release-worker.yml`'s filter on `main`. When reviewing packet 02's PR, also look at the current state of `release-functions.yml`'s filter on `main`. The two filters must be disjoint on the deployable-source paths. This is the D4 correctness boundary and the only inter-packet review concern in this initiative.

## Wave Diagram

### Wave 1 — Three independent workflow amendments (no internal blockers, fully parallel)

All three packets are independent. They can be filed in one pass and executed in parallel on Codex Cloud (or wherever PRs are authored). There is no Wave 2.

- [ ] `HoneyDrunk.Notify`: amend `release-functions.yml` for environment-gated deploy triggers — [`01-notify-functions-deploy-trigger-model.md`](01-notify-functions-deploy-trigger-model.md)
  - Blocked by: nothing.
- [ ] `HoneyDrunk.Notify`: amend `release-worker.yml` for environment-gated deploy triggers — [`02-notify-worker-deploy-trigger-model.md`](02-notify-worker-deploy-trigger-model.md)
  - Blocked by: nothing.
- [ ] `HoneyDrunk.Pulse`: amend `release-collector.yml` for environment-gated deploy triggers — [`03-pulse-collector-deploy-trigger-model.md`](03-pulse-collector-deploy-trigger-model.md)
  - Blocked by: nothing.

**Wave 1 exit criteria (= initiative exit criteria):**
- All three workflows have a `push: branches: [main]` trigger with a tight `paths:` filter scoped to the deployable's own source (and, for Pulse.Collector, the libraries it links against).
- D4 disjoint-filter check holds on the two Notify workflows: a Functions-only commit on `main` triggers `release-functions.yml` only; a Worker-only commit on `main` triggers `release-worker.yml` only. Verified end-to-end on real merges (or no-op test commits).
- All three `resolve` jobs emit a `target_environment` output. All three `deploy` jobs consume that output instead of the literal `dev`.
- All three workflows have a top-level `concurrency` block with the documented expression form (dev key vs. per-tag key; `cancel-in-progress` differs by path).
- Both Container App workflows (packets 02 and 03) use `dev-<sha>` as the image tag on the branch-push path and the SemVer tag verbatim on the tag path.
- All three workflow header comments describe the dual-trigger model; the prior dev-only/tag-only framing is removed.
- The `dev` GitHub Environment in HoneyDrunk.Notify and HoneyDrunk.Pulse remains unprotected (no required-reviewer rule) per ADR-0033 D7 — verified before merge.
- Both `CHANGELOG.md` files (Notify and Pulse) have entries under dated SemVer sections, not `Unreleased`.
- All three GitHub Issues close on the target repos. `hive-sync` auto-flips ADR-0033 from Proposed to Accepted on its next run.

## Filing

Filing is automated. Pushing these packets to `main` under `generated/issue-packets/active/adr-0033-deploy-trigger-model/` triggers `file-packets.yml` in HoneyDrunk.Architecture, which:
1. Creates the GitHub issue in `target_repo` for each packet.
2. Adds it to The Hive (Project #4).
3. Sets `Status`, `Wave`, `Node`, `Tier`, `Actor` (default Agent), `Initiative`, and `ADR` fields from frontmatter.
4. Resolves each `dependencies:` entry (none in this initiative — all three packets are independent) and calls `addBlockedBy` for any blocking edges.

No manual `gh issue create` / `addBlockedBy` is emitted here by design — the scope agent's job ends at writing the packets. The user pushes the packet directory to `main` to trigger filing.

## Recommended dispatch order

There is no required order. Three suggestions, in increasing levels of caution:

1. **Fastest:** File all three at once, open three PRs in parallel, merge as each is reviewed.
2. **Sequential by repo:** Land packet 03 (Pulse — single deployable, simplest D4 story) first to validate the trigger model end-to-end on real infra; then land packets 01 and 02 together (same repo, same CHANGELOG entry, D4 disjoint-filter check shared between them).
3. **Most cautious:** Land packet 03 first (single deployable, lowest D4 risk); observe two real-world branch-push deploys for a day or two on Pulse; then land packets 01 and 02. Adds a day of confidence at the cost of a day of latency on Notify.

The user picks the order at PR time. None of these choices change the packets.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on The Hive and the Wave 1 exit criteria are met, the entire `active/adr-0033-deploy-trigger-model/` folder is moved to `completed/adr-0033-deploy-trigger-model/` in a single commit (per the `hive-sync` invariant on lifecycle moves and the no-partial-archival rule). The `hive-sync` agent handles the move and updates `filed-packets.json` path keys.

## CHANGELOG sequencing

Per-repo CHANGELOG version sequencing for this initiative — the in-packet bodies defer to this section.

### HoneyDrunk.Notify (packets 01 + 02)

The implementing agent for either packet inspects `HoneyDrunk.Notify/CHANGELOG.md` and picks the next patch version above the current latest (e.g. if latest is `0.5.0`, next is `0.5.1`).

- **If packets 01 and 02 ship together (single PR or same-day separate PRs):** both packets append entries under the same dated `0.5.1` (or next-patch) section. One version entry, two bullet items.
- **If packet 01 ships first and packet 02 follows:** packet 01 creates the dated `0.5.1` section. Packet 02 appends to that same `0.5.1` section if the agent is working same-day; otherwise it bumps to `0.5.2` and creates its own dated section.
- **If packet 02 ships first and packet 01 follows:** symmetric — packet 02 creates the entry, packet 01 appends or bumps.
- **No `.csproj` version bump** for either packet. Workflow-only changes; Invariant 27 (one solution version, all projects move together) does not apply.

The agent for whichever packet lands first owns the version-entry creation. The agent for the second packet inspects the existing CHANGELOG state at implementation time and follows the rule above. Packet bodies must not encode "I am first" or "I am second" assumptions — the dispatch plan owns that sequencing.

### HoneyDrunk.Pulse (packet 03)

Independent repo. The implementing agent inspects `HoneyDrunk.Pulse/CHANGELOG.md` and picks the next patch version above the current latest. Single packet, single dated version entry, no cross-packet sequencing.

## Considered and explicitly out-of-scope path-filter entries

For audit traceability, the following paths were considered for the `paths:` filters and explicitly ruled out:

- `obj/`, `bin/` — build artifacts, never committed (covered by `.gitignore`).
- `.gitignore` itself — affects only ignore behavior, never the deployed binary.
- `pr-body.md`, `coverage-raw`, `coverage-report` — PR-pipeline artifacts, not committed to `main` as source.
- `nightly-deps.yml` and any other unrelated workflow file — only the per-deployable release workflow path is in each filter (one workflow file per filter; cross-listing other workflows would create false-positive deploys).
- `HoneyDrunk.Notify.Tools/**`, `HoneyDrunk.Notify.ProviderSupport/**` — utility projects not referenced by either deployable's `.csproj`. If they become runtime dependencies later, add them at that time.
- `HoneyDrunk.Notify.IntegrationTests/**`, `HoneyDrunk.Notify.Tests/**`, `Pulse.Tests/**` — test projects. Test-only commits must not trigger release workflows (Test 5 in each packet's acceptance criteria asserts this).
- `HoneyDrunk.Pulse.Sample.Api/**`, `HoneyDrunk.Pulse.Sample.Worker/**` — sample projects, not part of the Collector's `ProjectReference` graph.

None of these intersect with the deployable's runtime binary. Adding any of them to the filter would either silently bloat redeploys or violate D4.

## Branch protection note

Release workflow runs are **not** required checks on the `main` branch-protection rule in either HoneyDrunk.Notify or HoneyDrunk.Pulse. The PR-side checks (`pr.yml`) remain the merge gate; a failing release **after** merge is a deploy concern (revert PR or hot-fix), not a branch-protection concern. Do not add the dual-trigger release workflows to required checks on `main` — doing so would block merges while waiting for a post-merge deploy. This is a deliberate design choice consistent with the ADR-0033 dual-trigger model: dev deploys must follow merges, not gate them.

## Notes

- **ADR-0033 stays Proposed at scope time.** Auto-flip happens via `hive-sync` once all three packet issues close. No manual flip is in this initiative.
- **Actor=Agent for all three packets.** No packet requires a human in the critical path. The only `dev` GitHub Environment protection-rule check (D7) is a five-second look at the Environment settings to confirm no required reviewer was added since ADR-0015 stood up the environment — folded into the Human Prerequisites of each packet as "None" with a verification note, not as a required portal step.
- **Two LOW-PRIORITY follow-ups deliberately not scoped:** grid-health aggregator extension for release workflows; Container App inactive-revision retention/GC policy. Both named in ADR-0033 Follow-up Work, both explicitly low priority / not committed. Re-scope as standalone packets if and when concrete need surfaces.
- **The dispatch plan is the one exception to packet immutability** (per ADR-0008 D7). Updates at wave boundaries are the historical record. Packet bodies are immutable post-filing.

## Revision history

- **2026-05-20 initial scope** — three packets, single wave, fully parallel. One per consumer release workflow (`release-functions.yml`, `release-worker.yml` in HoneyDrunk.Notify; `release-collector.yml` in HoneyDrunk.Pulse). No `HoneyDrunk.Actions` change. No shared-index-file edits. ADR-0033 left Proposed; auto-flip on packet closure via `hive-sync`. Grid-health aggregator extension and Container App revision-GC policy named in ADR-0033 Follow-up Work but not scoped here per direction.
- **2026-05-20 refine pass** — applied refine-report fixes against the actual source repos before filing. Path-filter corrections: dropped non-existent `Directory.Build.props` / `Directory.Packages.props` from all three packets (forward-looking note added in each); dropped standalone `HoneyDrunk.Notify.Functions.csproj` from packet 01 (covered by project-directory glob); added shared-library paths to packets 01 and 02 per `HoneyDrunk.Notify.Functions.csproj` and `HoneyDrunk.Notify.Worker.csproj` `ProjectReference` graphs to close the silent-no-deploy gap (packet 03's Pulse library set was already correct). Prose corrections: fixed `Pulse.Collector.csproj` → `HoneyDrunk.Pulse.Collector.csproj` in packet 03. Expression form: collapsed multi-line `${{ }}` in `concurrency.group` and `image-tag` to single-line in all three packets; switched `dev-<short-sha>` → `dev-<sha>` (full 40-char `github.sha`) in packets 02 and 03 comments and prose, no expression change. Acceptance criteria: added Test 5 (tests-only commit does not trigger release) to all three packets. Packet 01: added build-job clarification and image-tag omission rationale. CHANGELOG sequencing moved out of packet 02 prose into this dispatch plan's new § CHANGELOG sequencing. Added § Considered and explicitly out-of-scope path-filter entries and § Branch protection note here; mirrored branch-protection guidance into each packet's Human Prerequisites.
