---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "docs", "infrastructure", "adr-0081", "adr-0044", "wave-1"]
dependencies: []
adrs: ["ADR-0081", "ADR-0044"]
accepts: []
wave: 1
initiative: adr-0081-home-server
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Author the Cloudflare Tunnel + ADR-0044 webhook-bridge migration plan (ADR-0081 D2, D6)

## Summary
Author `infrastructure/home-server/tunnel-and-bridge-migration-plan.md` — the step-by-step plan for moving the Cloudflare Tunnel (`grid-review.honeydrunkstudios.com`) and the ADR-0044 webhook bridge off the workstation and onto the home server. Satisfies ADR-0081's third Acceptance Criterion ("Cloudflare Tunnel + OpenClaw bridge migration plan is documented").

## Context
ADR-0044's webhook-first review path makes the tunnel + bridge load-bearing infrastructure. ADR-0081 D6 sequences the migration: stand up the OS and base hardening first, then install OpenClaw and toolchains, **then** move the tunnel and bridge, then verify on a single Architecture PR before moving anything else. This packet captures that sequence as an executable runbook so it is repeatable and recoverable.

This packet is for the **tunnel + bridge slice specifically**. The broader six-step D6 migration runbook lives in packet 06. They cross-reference each other; this one is the deep-dive on the most security-sensitive step.

## Scope
- New doc: `infrastructure/home-server/tunnel-and-bridge-migration-plan.md`.
- Updates `infrastructure/home-server/README.md` to list it.

## Proposed Implementation

### Document structure for `tunnel-and-bridge-migration-plan.md`

1. **Goal and exit criteria** — single Architecture PR receives a successful webhook-delivered review on the home server; workstation tunnel/bridge processes are stopped; rollback path remains valid.

2. **Pre-flight** — links to packet 03's pre-exposure security checklist; the checklist must be walked before the cutover.

3. **Inventory of the current state** (what's running on the workstation right now)
   - `cloudflared` config file path and tunnel ID/name
   - GitHub webhook delivery URL pointing at `grid-review.honeydrunkstudios.com`
   - Bridge process name, command line, log location, secret-source path
   - Service supervisor (systemd unit, launchd plist, NSSM service, scheduled task — whichever the workstation uses)

4. **Migration steps** — numbered, each with verification
   1. On the home server: install `cloudflared`; copy or re-mint tunnel credentials per Cloudflare's recommended path. Document which path was chosen (copy vs re-mint) and why.
   2. On the home server: install the bridge as a service under its dedicated user account (per packet 02). Bridge does not start yet.
   3. On the home server: place the bridge's signing-secret in OS credential storage per packet 02's mechanism; verify the bridge can read it without it appearing in `ps` arguments or environment dumps (invariant 8).
   4. Configure Cloudflare DNS / Tunnel ingress routing in the Cloudflare dashboard so `grid-review.honeydrunkstudios.com` points at the **new** tunnel. Note: this is the cutover moment.
   5. Start the bridge service on the home server.
   6. Start `cloudflared` on the home server.
   7. From the GitHub repo settings (Architecture repo's webhook config), use **Recent Deliveries → Redeliver** to replay the last successful delivery against the new endpoint. Confirm 200 OK and that the bridge log shows the signed delivery being verified and OpenClaw being invoked.
   8. Trigger a real test review on a throwaway PR against `HoneyDrunk.Architecture` to confirm end-to-end functionality.
   9. Once the throwaway PR review completes successfully, stop the workstation's bridge and `cloudflared` (but leave them installed and re-startable for rollback).

5. **Rollback** — explicit reverse of steps 9 → 4 (restart workstation processes, restore the workstation's tunnel as the DNS target). Time budget: < 5 minutes.

6. **Verification after 24 hours** — at least one webhook delivery during a wall-clock period where the workstation was asleep, confirming the home-server path is what kept review running.

7. **Workstation teardown** (only after the 24-hour verification) — remove or disable the workstation supervisor entries; archive the workstation's `cloudflared` config to a backup location; remove the workstation's copy of the bridge signing secret from OS credential storage.

### Cross-references to package
- Pre-flight: packet 03 (security checklist).
- Backup of the migrated bridge state: packet 05 (backup plan).
- Full six-step migration order: packet 06 (this packet is the deep-dive on step 3 of the six).

## Affected Files
- `infrastructure/home-server/tunnel-and-bridge-migration-plan.md` (new)
- `infrastructure/home-server/README.md` (update)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] Doc lives in `HoneyDrunk.Architecture/infrastructure/home-server/`.
- [x] No code change; no Node touched. The ADR-0044 bridge implementation lives outside this initiative — this packet is a relocation plan, not a redesign.
- [x] No secret committed.

## Acceptance Criteria
- [ ] `infrastructure/home-server/tunnel-and-bridge-migration-plan.md` exists with the goal+exit-criteria, pre-flight, inventory, numbered migration steps, rollback, 24-hour verification, and workstation teardown sections
- [ ] Each migration step has an explicit verification (what the operator looks at to confirm the step worked) — no step is "do X" without "verify Y"
- [ ] The cutover moment (DNS/ingress flip to the new tunnel) is called out unambiguously, with the rollback inverse documented adjacent to it
- [ ] The rollback path has a time budget of < 5 minutes documented
- [ ] The plan references packet 03's pre-exposure security checklist as a hard gate before cutover
- [ ] The plan honors D6's sequence: OS + hardening + OpenClaw installed *before* tunnel/bridge move; tunnel/bridge move *before* moving scheduled jobs; workstation fallback *only* disabled after verification
- [ ] `infrastructure/home-server/README.md` lists this artifact
- [ ] Repo-level `CHANGELOG.md` entry for ADR-0081 appended (per invariants 12, 27)
- [ ] No secret value (tunnel credential, bridge signing secret) appears in any committed file (invariant 8)

## Human Prerequisites
- [ ] None for authoring the plan. Executing the plan is a follow-up the operator runs against the actual hardware once it is online.

## Dependencies
None. The packet can be authored in parallel with all other Wave 1 artifacts. The plan **references** packets 02 (OS hardening), 03 (security checklist), 05 (backup plan), and 06 (overall migration runbook), but those references are conceptual — the doc can be authored without those files existing yet, with the cross-links resolved during the combined Wave 1 PR review.

## Agent Handoff

**Objective:** Document the cutover from workstation-hosted to home-server-hosted Cloudflare Tunnel and ADR-0044 webhook bridge, satisfying ADR-0081's third Acceptance Criterion.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Satisfy ADR-0081 Acceptance Criterion 3 ("Cloudflare Tunnel + OpenClaw bridge migration plan is documented") and concretize D6's sequence for the most security-sensitive step.
- Feature: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure.
- ADRs: ADR-0081 (this initiative); ADR-0044 (the webhook bridge whose host is being migrated).

**Acceptance Criteria:** (mirrored above)

**Dependencies:** None among the Wave 1 packets.

**Constraints:**
- ADR-0081 D2 (full text): see packet 03 — narrow, authenticated, application-layer-verified tunnel exposure; no router port-forwarding; one tiny local bridge per public integration; no wholesale dashboard/gateway tunnel.
- ADR-0081 D6 (full text): "The workstation setup remains valid until the home server is ready. Migration order:
  1. Stand up server OS and basic hardening.
  2. Install OpenClaw, Git, Node/.NET/Python toolchains as needed.
  3. Move Cloudflare Tunnel and ADR-0044 webhook bridge.
  4. Verify ADR-0044 webhook delivery on one Architecture PR.
  5. Move scheduled jobs one at a time.
  6. Only then disable workstation cron/poll fallbacks that the server replaces."
- ADR-0044 D2 (paraphrased): the webhook bridge is the trigger rail for cloud reviews; it must verify the GitHub signed payload before invoking the reviewer.
- Invariant 8: secret values never appear in logs/traces/exceptions/telemetry — verification step for the bridge secret must check `ps`/env exposure too.

**Key Files:**
- `infrastructure/home-server/tunnel-and-bridge-migration-plan.md` (new — primary artifact)
- `infrastructure/home-server/README.md` (update)
- `CHANGELOG.md` (append)

**Contracts:** None.

---

## PR Body Requirements
The PR opened against `HoneyDrunk.Architecture` for this packet must include in its body:

```
Authorship: Agent
Packet: generated/issue-packets/proposed/adr-0081-home-server/04-architecture-home-server-tunnel-and-webhook-bridge-migration-plan.md
```
