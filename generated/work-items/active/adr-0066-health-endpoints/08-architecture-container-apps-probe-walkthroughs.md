---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infra", "docs", "adr-0066", "wave-6"]
dependencies: ["work-item:00", "work-item:03"]
adrs: ["ADR-0066", "ADR-0015"]
wave: 6
initiative: adr-0066-health-endpoints
node: honeydrunk-architecture
---

# Document Container Apps probe configuration for every containerized deployable Node

## Summary
Add the ADR-0066 D5 Container Apps probe declarations to each containerized deployable Node's infrastructure walkthrough doc under `repos/HoneyDrunk.{Node}/`. The walkthrough is a portal-step recipe (per the user's portal-over-CLI preference) describing the probe configuration the operator clicks into the Container App's "Health probes" blade. Covers the live deployable lines today — **Pulse.Collector**, **Notify.Worker** — and the planned containerized Nodes named in ADR-0066 D11 Affected Nodes: **Notify.Cloud**, **Operator**, **Agents**, **HoneyHub**. For the planned-but-not-yet-deployed Nodes, the walkthrough lives in the standup ADR's destination doc and inherits from this template.

## Context
ADR-0066 D5 commits the probe defaults; ADR-0066's follow-up list calls for "per-Node Container Apps probe declarations to each containerized Node's infrastructure walkthrough — Pulse, Notify (Worker), future Notify.Cloud, Operator, Agents, HoneyHub."

ADR-0015 D4 named the deployable lines: Notify.Worker and Pulse.Collector are containerized today; Notify.Functions stays on Functions; Notify.Cloud/Operator/Agents/HoneyHub are planned containerized Nodes per their standup ADRs.

Container Apps probe defaults per ADR-0066 D5:

| Probe | Path | Period | Initial delay | Timeout | Failure threshold | Success threshold |
|---|---|---|---|---|---|---|
| `livenessProbe` | `/health/live` | 30s | 10s | 3s | 3 | 1 |
| `readinessProbe` | `/health/ready` | 10s | 5s | 3s | 3 | 1 |
| `startupProbe` | `/health/live` | 5s | 0s | 3s | 30 | 1 |

The user prefers portal-over-CLI walkthroughs (memory note: "use portal UI walkthroughs, not CLI commands"). The walkthrough format follows the existing repo convention: short portal step-by-step ("click the Container App → Health probes → Add → ...") with the values from the table above.

The walkthroughs live under `repos/HoneyDrunk.{Node}/` per the existing repo-overview convention. The exact filename and location vary by Node — likely `infrastructure.md` or a sibling to `integration-points.md`. Check each Node's existing repo-overview docs and place the walkthrough where the existing infrastructure docs live, or add a new `infrastructure-container-apps.md` if no infrastructure doc exists.

This is a docs/governance packet. No code, no .NET project. Tier-2 (not tier-1) because the walkthroughs are content-heavy and span six target Nodes.

## Scope
**Folder existence pre-flagged at packet-authoring time** (verified by directory listing of `repos/`):
- `repos/HoneyDrunk.Pulse/` — **exists**. Add or extend the infrastructure walkthrough for Pulse.Collector.
- `repos/HoneyDrunk.Notify/` — **exists**. Add or extend the infrastructure walkthrough for Notify.Worker. Notify.Functions runs on Functions, not Container Apps — exclude it (the Functions deploy gate is handled in packet 10).
- `repos/HoneyDrunk.Notify.Cloud/` — **does NOT exist** at packet-authoring time. Skip in this packet. Defer the walkthrough to ADR-0027's standup destination doc; note the deferral in the PR.
- `repos/HoneyDrunk.Operator/` — **exists**. Add the walkthrough stub.
- `repos/HoneyDrunk.Agents/` — **exists**. Add the walkthrough stub.
- `repos/HoneyHub/` — **exists**. Add the walkthrough stub.
- **No discovery cycles required.** The folder-existence audit is complete; the executor adds walkthroughs to the five existing folders (Pulse, Notify, Operator, Agents, HoneyHub) and explicitly defers Notify.Cloud.
- The shared probe defaults table from ADR-0066 D5 — extracted into a reusable Markdown snippet (e.g. `repos/_shared/container-apps-probe-defaults.md` or inline in each walkthrough). Inline is simpler; the cost is duplication across five docs. Choose inline for the first round (matches the lean-doc convention) and link from each Node's walkthrough back to the ADR-0066 source of truth.

## Proposed Implementation
1. For **`repos/HoneyDrunk.Pulse/`**:
   - Add a section titled "Container Apps probe configuration (ADR-0066)" to the existing infrastructure doc (or add a new `infrastructure-container-apps.md` if no infrastructure doc exists). Include the ADR-0066 D5 probe defaults table verbatim.
   - Add a portal walkthrough: "In the Azure portal, navigate to your Pulse.Collector Container App (`ca-hd-pulse-{env}` per invariant 34). Go to Application → Containers → Edit and deploy → select the container → Health probes → Add. Add the three probes with the values from the table above. Save → Create."
   - Note any per-Node overrides (D5 prose: "per-Node overrides are permitted with reason recorded in the Node's `infrastructure/` walkthrough"). Pulse.Collector probably uses defaults — state that in the walkthrough.
   - Reference packet 10 for the deploy-workflow change that switches the readiness gate from `/health` to `/health/ready`.
2. For **`repos/HoneyDrunk.Notify/`**:
   - Same shape, targeting Notify.Worker's Container App (`ca-hd-notify-{env}` or whatever the actual name is — check the Notify infrastructure docs).
   - **Note explicitly that Notify.Functions is NOT a Container App** — it runs on Functions and its deploy gate is handled by packet 10's deploy-workflow change.
   - Notify.Worker may have a longer warm-up due to Vault secrets resolution and provider-template loading; document any per-Node override to the startup probe's failure threshold if the operator decides one is warranted, or state "defaults apply" if not.
3. For **`repos/HoneyDrunk.Operator/`**, **`repos/HoneyDrunk.Agents/`**, **`repos/HoneyHub/`** (all three exist at packet-authoring time):
   - Add the same walkthrough as a stub: probe defaults table + portal step-by-step + the note "this Node is planned per ADR-0018 / ADR-0020 / ADR-0002-0003 standup; the walkthrough applies when the Container App is first provisioned."
4. For **`repos/HoneyDrunk.Notify.Cloud/`** (does NOT exist at packet-authoring time):
   - Skip. Defer the walkthrough to ADR-0027's standup destination doc. State the deferral in the PR and add a note to ADR-0027's follow-up list.
   - **Do not create the folder in this packet** — the standup ADR creates it.
5. Inline the probe-defaults table in each walkthrough rather than centralizing in a shared file — easier to read, low duplication cost (five copies of a small table). Each walkthrough links back to ADR-0066 D5 as the source of truth.
6. State the cross-reference to packet 10: "The deploy workflow's readiness gate probes `/health/ready` (not `/health`, which is auth-required per invariant `{N2}`). See packet 10 in this initiative for the Actions-side workflow change."

## Affected Files
- `repos/HoneyDrunk.Pulse/infrastructure*.md` (or wherever the Pulse infrastructure walkthroughs live).
- `repos/HoneyDrunk.Notify/infrastructure*.md`.
- `repos/HoneyDrunk.Operator/infrastructure*.md` (folder exists; add walkthrough).
- `repos/HoneyDrunk.Agents/infrastructure*.md` (folder exists; add walkthrough).
- `repos/HoneyHub/infrastructure*.md` (folder exists; add walkthrough).
- `repos/HoneyDrunk.Notify.Cloud/` — NOT edited (folder does not exist; deferred to ADR-0027 standup).

## NuGet Dependencies
None. This packet touches only Markdown docs; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` under `repos/{Node}/` — the Grid-wide repo-overview convention.
- [x] No code change in any other repo.
- [x] No Container App YAML change in this packet — the YAML lives in `HoneyDrunk.Actions` (the deployable's release workflow inputs the probe config to the deploy step). Those YAML files are amended in packet 10.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Pulse/` infrastructure walkthrough has a "Container Apps probe configuration (ADR-0066)" section with the D5 probe-defaults table and a portal-step walkthrough for Pulse.Collector
- [ ] `repos/HoneyDrunk.Notify/` infrastructure walkthrough has the same for Notify.Worker, plus an explicit note that Notify.Functions is NOT a Container App
- [ ] `repos/HoneyDrunk.Operator/`, `repos/HoneyDrunk.Agents/`, `repos/HoneyHub/` each carry a walkthrough stub (folders exist at packet-authoring time)
- [ ] `repos/HoneyDrunk.Notify.Cloud/` is NOT touched (folder does not exist); the deferral to ADR-0027's standup is documented in the PR and a follow-up note is added to ADR-0027
- [ ] Each walkthrough is portal-step-style, not CLI-style (user preference: portal-over-CLI)
- [ ] Each walkthrough links to ADR-0066 D5 as the source of truth and notes that per-Node overrides are permitted with reason recorded in the walkthrough
- [ ] Each walkthrough cross-references packet 10 for the deploy-workflow readiness-gate switch
- [ ] No code change; no `.csproj` change; no version bump (Architecture is not a versioned .NET solution)
- [ ] `pr-core.yml` tier-1 gate passes (markdown lint, link check if configured)

## Human Prerequisites
- [ ] **Portal-side action: apply the probe configuration to each existing Container App.** For Pulse.Collector and Notify.Worker — the deployables that are live today — the operator must click through the portal walkthrough to set the three probes on the running Container Apps in each environment (`dev`, `staging`, `prod`). This is a deploy-time action, not a code action; the walkthrough exists to guide it. The walkthrough docs land in this packet's PR; the portal application happens after merge.
- [ ] **Probe configuration coordinates with the deploy workflow.** The Container App revision-health gate (per invariant 36 and ADR-0066 D5) reads `/health/ready` on a new revision. Coordinate the portal probe configuration with packet 10's deploy-workflow change so the gate consistently uses `/health/ready`.
- [ ] **Notify.Cloud is deferred.** `repos/HoneyDrunk.Notify.Cloud/` does not exist at packet-authoring time; the walkthrough belongs in ADR-0027's standup destination doc. Track this in ADR-0027's follow-up list.

## Referenced ADR Decisions
**ADR-0066 D5 — Container Apps probe defaults.** The table verbatim:

| Probe | Path | Period | Initial delay | Timeout | Failure threshold | Success threshold |
|---|---|---|---|---|---|---|
| `livenessProbe` | `/health/live` | 30s | 10s | 3s | 3 | 1 |
| `readinessProbe` | `/health/ready` | 10s | 5s | 3s | 3 | 1 |
| `startupProbe` | `/health/live` | 5s | 0s | 3s | 30 | 1 |

Per-Node overrides permitted with reason recorded in the walkthrough.

**ADR-0066 D5 — Revision health gating.** A new revision is shifted to 100% traffic only after `/health/ready` returns `200` for at least three consecutive periods on the revision's direct FQDN. The deploy workflow (packet 10) holds the gate.

**ADR-0015 D4 — Containerized deployable lines.** Notify.Worker, Pulse.Collector, plus the planned Notify.Cloud, Operator, Agents, HoneyHub. Notify.Functions stays on Functions.

**Invariant 34 — Container App naming.** `ca-hd-{service}-{env}` — referenced in the walkthrough for each Node's resource name.

**Invariant 36 — Container App revision mode is Multiple.** The probe configuration above interacts with the traffic-splitting revision gate.

## Constraints
- **Portal over CLI.** Walkthroughs are click-by-click, not CLI commands. User preference per memory.
- **Inline the probe-defaults table.** Six copies across the walkthroughs is the chosen tradeoff over a centralized shared file; readability wins.
- **Do NOT create `repos/{Node}/` folders that do not exist.** Standup ADRs create those folders; this packet only adds walkthroughs where the folder already exists.
- **No Container App YAML change.** The deployable's release workflow in `HoneyDrunk.Actions` owns the YAML; packet 10 amends those workflows.
- **Cross-reference packet 10.** Each walkthrough names the deploy-workflow readiness-gate switch as a dependency for consistent operation.

## Labels
`feature`, `tier-2`, `infra`, `docs`, `adr-0066`, `wave-6`

## Agent Handoff

**Objective:** Add ADR-0066 D5 Container Apps probe walkthroughs to each containerized deployable Node's infrastructure docs under `repos/HoneyDrunk.{Node}/`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the operator a portal-step recipe for applying the D5 probe configuration to every live and planned Container App.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 6 (infra walkthroughs + agent updates).
- ADRs: ADR-0066 D5 (primary), ADR-0015 D4 (containerized lines), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0066 Accepted; the walkthroughs cite live Invariant `{N1}`, 55, 56.
- `work-item:03` — the Kernel helper exists, so the walkthroughs are not pointing at unshipped runtime.

**Constraints:**
- Portal-step walkthroughs, not CLI commands (user preference).
- Inline the probe-defaults table in each walkthrough; link back to ADR-0066 D5.
- Do NOT create `repos/{Node}/` folders that do not exist — standup ADRs own those.
- Cross-reference packet 10 for the deploy-workflow readiness-gate switch.

**Key Files:**
- `repos/HoneyDrunk.Pulse/`, `repos/HoneyDrunk.Notify/`, `repos/HoneyDrunk.Operator/`, `repos/HoneyDrunk.Agents/`, `repos/HoneyHub/` infrastructure walkthroughs (all five folders exist; pre-verified). `repos/HoneyDrunk.Notify.Cloud/` does NOT exist — skip and defer to ADR-0027.

**Contracts:** None changed — docs-only packet.
