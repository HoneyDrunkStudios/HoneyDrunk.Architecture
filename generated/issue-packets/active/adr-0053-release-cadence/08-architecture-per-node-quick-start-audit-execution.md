---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0053", "wave-3"]
dependencies: ["packet:06"]
adrs: ["ADR-0053"]
accepts: ["ADR-0053"]
wave: 3
initiative: adr-0053-release-cadence
node: honeydrunk-architecture
---

# Run the "first 60 seconds" audit against every Live Node and produce the Grid-wide gap report

## Summary
Execute the local-dev audit playbook from packet 06 against every Live Node in `catalogs/grid-health.json`. Produce a Grid-wide gap report listing each Node's pass/miss state and the specific gap-on-miss. Per-Node remediation packets are **not** pre-written here — each miss is recorded with enough context that a follow-up scope pass in that Node's own track can decompose the fix.

## Context
ADR-0053 D16 Phase 5 reads: "Every Live Node's `repos/{name}/overview.md` gets a `## Quick Start` section per D11. Any Node that cannot meet the 60-second target gets a follow-up packet."

This packet does the **audit execution** — it runs the playbook from packet 06 against each Live Node, records the result, and surfaces gaps. Packet 06 ships the template + the audit recipe; this packet runs the recipe and produces the report. Per the playbook-not-per-Node-packets pattern (mirroring ADR-0045 packet 07), per-Node remediation is **deferred** to each Node's own scope pass — the audit's job is to identify gaps, not pre-write 12+ remediation packets.

**Why a separate execution packet.** Packet 06 (the template + playbook) is small and focused — it ships docs. Audit execution is a separate concern: it touches every Live Node's repo (cloning, building, running), takes real time per Node, and produces a Grid-wide report. Splitting the two avoids a single mega-packet that authors-and-executes in one PR.

**Expected outcome.** Per ADR-0053's Operational Consequences: "The 'first 60 seconds' audit will surface Nodes that don't meet it. Phase 5's audit is expected to find at least 2–3 Nodes that need work to hit the target. Those gaps become packets; they are not blockers for the rest of this ADR's rollout." So a non-zero gap count is the expected case, not a failure mode.

This is a docs/audit packet. No code, no .NET project. The audit's *output* is a Markdown report; the audit's *input* is the live state of every Live Node's repo.

## Scope
- `infrastructure/local-dev-audit-report.md` (new) — the Grid-wide gap report covering every Live Node: name, pass/miss, gap-on-miss (specific log line or missing prerequisite), recommended remediation (a one-line summary), and a link to the Node's `repos/{name}/overview.md`.
- For each pass Node: confirm the Node's `repos/{name}/overview.md` already carries a `## Quick Start` section that meets the playbook's criteria. If yes, record pass. If the Node passes the *boot* check but is missing the `## Quick Start` section in `overview.md`, the audit's recommended remediation is "add the Quick Start section per the template"; this is a small docs-only follow-up.
- For each miss Node: record the specific gap (e.g. "boot requires a real Service Bus connection string — no `local` profile with InMemory broker"; "boot exceeds 60 seconds; first run takes 95s on a 14-Gbps machine due to NuGet restore"; "missing `.env.example`"). The remediation is recorded as a one-line summary; the full per-Node packet is **not** pre-written here.

## Proposed Implementation
1. **Enumerate Live Nodes.** Read `catalogs/grid-health.json` for nodes with `signal: "Live"` (capitalized — the canonical value in `grid-health.json`; case-sensitive comparison required). Library-only Nodes and deployable Nodes are both in scope (the template from packet 06 has variants for both).
2. **Per Node, run the playbook:**
   - Read `repos/{name}/overview.md` to see if a `## Quick Start` section already exists.
   - Clone the Node's repo to a clean working directory.
   - Execute the documented boot path (`dotnet build && dotnet test` for library-only; `dotnet run` for deployable).
   - Time the first-run from invocation to the canonical readiness log line.
   - Confirm no Azure endpoint is reached (no `AZURE_KEYVAULT_URI` resolution against a real vault; no App Configuration; no SDK auth step).
   - Record pass / miss + the specific gap-on-miss.
3. **Aggregate into `infrastructure/local-dev-audit-report.md`.** The report has:
   - A header dated `YYYY-MM-DD` with the audit's execution date.
   - A summary line: "X/Y Live Nodes pass the 60-second target; Z Live Nodes miss with a recorded gap; W Live Nodes pass the boot check but lack the documented Quick Start section."
   - A per-Node table: Node name | Status | Gap-on-miss | Recommended remediation | Link to `overview.md`.
   - A "Follow-up packets" section listing each miss with a one-line remediation summary — these are notes for future scope passes, NOT pre-written packets. Each entry's wording is: "{Node}: {one-line summary of the fix needed}. Follow-up: scope in the Node's own track."
4. **No per-Node packet pre-written.** This is the same boundary as ADR-0045 packet 07. The audit's *output* is a structured list of gaps; each Node's scope agent (the operator's next pass against that Node) decomposes its own remediation packet.
5. **Update `catalogs/grid-health.json`.** If the audit reveals a Node has an active blocker (e.g. cannot boot locally without a real Azure resource), add the blocker to the Node's `active_blockers` array per the existing grid-health schema. This is the only catalog edit this packet makes.

## Affected Files
- `infrastructure/local-dev-audit-report.md` (new)
- `catalogs/grid-health.json` — `active_blockers` updates per Node where the audit reveals a real blocker.

## NuGet Dependencies
None.

## Boundary Check
- [x] All artefacts in `HoneyDrunk.Architecture` — audit reports and catalog updates live here.
- [x] No code change in any Node — the audit observes the Node's repo state; remediation is a future per-Node scope pass.
- [x] No per-Node packet pre-written — each miss is recorded with enough context for a future per-Node scope pass to decompose the fix.

## Acceptance Criteria
- [ ] `infrastructure/local-dev-audit-report.md` exists with the date header, summary line, per-Node table, and follow-up notes section
- [ ] Every Live Node in `catalogs/grid-health.json` (`signal: "Live"` — capitalized) is covered in the report — no skipped Node
- [ ] Each row records Node name, status (pass / miss / pass-boot-missing-quick-start), gap-on-miss, recommended remediation summary, and link to `overview.md`
- [ ] `catalogs/grid-health.json` `active_blockers` arrays are updated per Node where the audit reveals a real blocker — the only catalog edit this packet makes
- [ ] No per-Node remediation packet is pre-written — follow-ups are recorded as notes in the report's "Follow-up packets" section
- [ ] No invariant change in this packet (invariants land in packet 00)
- [ ] No `.csproj` version bump — Markdown + JSON only

## Human Prerequisites
- [ ] The audit execution requires cloning every Live Node's repo and running the documented boot path. The agent doing the audit work has the local environment to do so (Docker, .NET SDK, any documented prerequisites).
- [ ] For Nodes the agent cannot boot locally (e.g. the boot path needs a paid Azure resource that exists only in the operator's subscription), the audit records "cannot reproduce locally" as the gap and flags the Node for the operator's own audit pass — agents do not provision Azure resources to make the audit work.

## Referenced ADR Decisions
**ADR-0053 D11 — Local-dev parity.** Every Node must boot locally with `dotnet run` against InMemory or Testcontainers; the first-60-seconds rule per `repos/{name}/overview.md`'s `## Quick Start`.

**ADR-0053 D16 Phase 5 — Local-dev parity audit.** "Any Node that cannot meet the 60-second target gets a follow-up packet." This packet identifies the gaps; per-Node follow-ups are decomposed in each Node's own track.

**ADR-0053 Operational Consequences.** "The 'first 60 seconds' audit will surface Nodes that don't meet it. Phase 5's audit is expected to find at least 2–3 Nodes that need work to hit the target. Those gaps become packets; they are not blockers for the rest of this ADR's rollout."

## Constraints
> **Invariant 11 — One repo per Node.** The audit observes every Live Node's repo without modifying any of them. Remediation is each Node's own concern.

> **Invariant 25 — Dispatch plans are initiative narratives, not live state.** The audit report is *not* a dispatch plan; it is a Grid-wide finding artefact. The follow-up packets land per-Node, not in this initiative.

- **Audit, not remediation.** Identify gaps, do not fix them. Per-Node follow-up scoping is deliberately deferred to each Node's own track.
- **Every Live Node covered.** No skipping; the report's coverage is exhaustive across `signal: "Live"` (capitalized) Nodes.
- **`catalogs/grid-health.json` `active_blockers` is the only catalog edit.** Other catalog files are untouched.
- **Cannot-reproduce gaps recorded honestly.** If an agent cannot reproduce the boot path locally (because the path needs an Azure resource the agent cannot provision), record that as the gap and flag for the operator's own audit pass.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0053`, `wave-3`

## Agent Handoff

**Objective:** Run the local-dev audit playbook against every Live Node and produce the Grid-wide gap report; record blockers in `catalogs/grid-health.json`; do not pre-write per-Node remediation packets.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Identify which Live Nodes meet the 60-second local-boot target and which need work, per ADR-0053 D16 Phase 5.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 3.
- ADRs: ADR-0053 D11/D16 Phase 5 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:06` — the template + audit playbook this packet executes against.

**Constraints:**
- Audit, not remediation — no per-Node packets pre-written.
- Every Live Node covered; no skipping.
- `catalogs/grid-health.json` `active_blockers` is the only catalog edit.
- "Cannot reproduce locally" is a valid recorded gap when an agent lacks the Azure resource the boot path needs.

**Key Files:**
- `infrastructure/local-dev-audit-report.md` (new)
- `catalogs/grid-health.json`

**Contracts:** None changed.
