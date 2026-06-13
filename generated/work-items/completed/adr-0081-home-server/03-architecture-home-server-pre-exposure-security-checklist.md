---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "docs", "infrastructure", "security", "adr-0081", "wave-1"]
dependencies: []
adrs: ["ADR-0081"]
accepts: []
wave: 1
initiative: adr-0081-home-server
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Author the home-server pre-exposure security checklist (ADR-0081 D2, D5)

## Summary
Author `infrastructure/home-server/pre-exposure-security-checklist.md` — the gate the operator must walk through **before** exposing any tunnel-backed endpoint from the home server. This satisfies ADR-0081's fifth Acceptance Criterion ("Security checklist exists for the server before exposing any tunnel-backed endpoint").

## Context
ADR-0081 D2 forbids public router/firewall exposure and constrains all inbound traffic to narrow, authenticated tunnels with application-layer signature verification. D5 mandates least-privilege, recoverable security posture. Together they imply a concrete pre-flight checklist — a single page the operator runs through every time a new tunnel-backed endpoint is about to go live, that confirms the host, the tunnel, and the bridge are all in the expected state.

This is a single, well-bounded artifact and is the natural place to centralize "what must be true before we open inbound." Packet 02's hardening playbook is what makes those things true at install time; this checklist is what re-verifies them at exposure time.

## Scope
- New doc: `infrastructure/home-server/pre-exposure-security-checklist.md`.
- Updates `infrastructure/home-server/README.md` to list it.

## Proposed Implementation

### Document structure for `pre-exposure-security-checklist.md`
A flat checklist organized by layer. Every item is a checkbox with a one-line "how to verify" hint.

1. **Host posture** (verifies packet 02 hardening is still in force)
   - [ ] OS package updates applied within last 7 days (`apt list --upgradable` empty or only non-security; equivalent on chosen OS)
   - [ ] Host firewall default-deny inbound verified; only the explicitly allowed local ports are open
   - [ ] SSH posture is key-only, no password auth; SSH access restricted to operator account only
   - [ ] No unexpected listening services on the host (review `ss -tulpn` or equivalent)
   - [ ] Service accounts (OpenClaw, webhook bridge, cloudflared) run as their dedicated users, not as root or operator

2. **Tunnel posture** (D2 — "no public router/firewall exposure")
   - [ ] No router port-forwarding rule exists for this hostname or any inbound port to the home server
   - [ ] Cloudflare Tunnel is configured to forward only the specific application paths listed in packet 04's migration plan — not the whole machine, not the OpenClaw dashboard wholesale (D2 explicit rule)
   - [ ] Tunnel credentials are stored as machine secrets per packet 02's OS-layer secret-storage decision (D5)
   - [ ] Tunnel daemon is running as its dedicated service account, not as root

3. **Bridge posture** (D2 — "Every inbound integration verifies an application-layer secret/signature before triggering work")
   - [ ] The webhook bridge has signature/HMAC verification enabled and rejects unsigned requests
   - [ ] The shared secret used for signature verification is sourced from OS credential storage or Vault, not a file in the repo (invariants 8, 9)
   - [ ] Bridge rejects requests for any path other than the specific webhook path documented in packet 04

4. **Application-layer auth** (D2 — narrow exposure)
   - [ ] For the ADR-0044 webhook bridge: the GitHub webhook secret matches what GitHub is configured to send; a deliberate test delivery from the GitHub UI succeeds and an unsigned cURL probe fails
   - [ ] For any future integration: the equivalent of the above is done before the exposure goes live

5. **Logging and rollback**
   - [ ] Inbound bridge logs are flowing to the configured destination (local journal + future Pulse sink)
   - [ ] The operator knows the exact `cloudflared` and bridge stop commands to take the exposure offline within 60 seconds if needed
   - [ ] A rollback path to running the bridge on the workstation is documented (D6: "The workstation setup remains valid until the home server is ready")

The checklist ends with a "Signed off by `<operator>` on `YYYY-MM-DD` for exposure of `<integration name>`" entry the operator fills in each time the list is walked. The doc thus accumulates an audit trail of exposure events over time.

## Affected Files
- `infrastructure/home-server/pre-exposure-security-checklist.md` (new)
- `infrastructure/home-server/README.md` (update)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] Doc lives in `HoneyDrunk.Architecture/infrastructure/home-server/`.
- [x] No code change; no Node touched.
- [x] No secret committed.

## Acceptance Criteria
- [ ] `infrastructure/home-server/pre-exposure-security-checklist.md` exists with all five sections above (Host, Tunnel, Bridge, Application-layer auth, Logging/rollback)
- [ ] Every item is a verifiable checkbox with a one-line "how to verify" hint
- [ ] The "no router port-forwarding" check is present and unambiguous (D2)
- [ ] The "tunnel does not expose the whole machine" check is present (D2)
- [ ] The "signature/HMAC verification enabled" check is present (D2)
- [ ] The doc includes a per-exposure sign-off line the operator fills in each time
- [ ] The 60-second-takedown command is documented or links to a runbook section that documents it
- [ ] `infrastructure/home-server/README.md` lists this artifact
- [ ] Repo-level `CHANGELOG.md` entry for ADR-0081 appended (per invariants 12, 27)
- [ ] No secret value appears in any committed file (invariant 8)

## Human Prerequisites
- [ ] None for authoring the checklist. Walking the checklist (filling in sign-off lines) happens at exposure time, packet 04's migration cutover, and every subsequent integration.

## Dependencies
None. Can land in parallel with all other Wave 1 packets. The checklist references concepts from packets 02 (hardening) and 04 (tunnel/bridge migration) but does not require either to have landed first — the references are conceptual, not file-link-dependent.

## Agent Handoff

**Objective:** Produce the operator's pre-flight checklist that gates every new tunnel-backed exposure, satisfying ADR-0081's fifth Acceptance Criterion.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Satisfy ADR-0081 Acceptance Criterion 5 ("Security checklist exists for the server before exposing any tunnel-backed endpoint").
- Feature: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure.
- ADRs: ADR-0081; ADR-0044 (the first concrete consumer of the tunnel-backed exposure).

**Acceptance Criteria:** (mirrored above)

**Dependencies:** None among the Wave 1 packets.

**Constraints:**
- ADR-0081 D2 (full text): "The home server must not require inbound router port-forwarding. Public ingress uses Cloudflare Tunnel or a similarly narrow, authenticated tunnel. Rules:
  - Expose only specific webhook/application paths, never the whole machine.
  - Do not tunnel the OpenClaw dashboard/gateway wholesale.
  - Prefer one tiny local bridge per public integration.
  - Every inbound integration verifies an application-layer secret/signature before triggering work.
  For ADR-0044 specifically, GitHub posts to a Cloudflare Tunnel hostname, the tunnel forwards to a local webhook bridge, and the bridge verifies the signed payload before invoking OpenClaw locally."
- ADR-0081 D5 (full text): see packet 02 — least-privilege service accounts, machine-secret storage for tunnel credentials, conservative auto-updates, no autonomous destructive actions.
- Invariant 8: "Secret values never appear in logs, traces, exceptions, or telemetry." — applies to bridge log content too; the checklist should note that bridge logs must not echo secrets.
- Invariant 9: "Vault is the only source of secrets" for Grid Node access. Operator-infrastructure secrets (tunnel credential, GitHub webhook secret on the bridge side) live in OS credential storage per D5; this is a deliberate boundary — the home server is not a Grid Node.

**Key Files:**
- `infrastructure/home-server/pre-exposure-security-checklist.md` (new — primary artifact)
- `infrastructure/home-server/README.md` (update)
- `CHANGELOG.md` (append)

**Contracts:** None.

---

## PR Body Requirements
The PR opened against `HoneyDrunk.Architecture` for this packet must include in its body:

```
Authorship: Agent
Work Item: generated/work-items/proposed/adr-0081-home-server/03-architecture-home-server-pre-exposure-security-checklist.md
```
