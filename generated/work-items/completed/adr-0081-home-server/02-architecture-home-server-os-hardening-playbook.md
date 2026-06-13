---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "docs", "infrastructure", "adr-0081", "wave-1"]
dependencies: []
adrs: ["ADR-0081"]
accepts: []
wave: 1
initiative: adr-0081-home-server
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Author home-server OS choice and base hardening playbook (ADR-0081 D5)

## Summary
Author `infrastructure/home-server/os-and-hardening.md` recording the chosen OS for the home server, the rationale, and a step-by-step base-hardening checklist (dedicated service accounts, automatic conservative updates, SSH posture, firewall defaults, audit logging). This is the second of five Acceptance-Criteria artifacts ADR-0081 requires.

## Context
ADR-0081's Acceptance Criteria require: "OS choice is confirmed." D5 ("Security posture is least-privilege and recoverable") spells out the obligations the OS install must satisfy: dedicated OS users for long-running automation, secrets in OS credential storage or Vault-backed mechanisms, conservative automatic updates, regular backups, and treatment as infrastructure rather than a casual desktop.

This packet stops at *documenting* the OS choice and the hardening playbook. Executing the install and applying the hardening is a Human Prerequisite — the agent cannot SSH into a physical machine the operator just received. The doc is the deliverable; the install evidence (a one-line confirmation in the doc, "applied on YYYY-MM-DD") closes the loop later.

## Scope
- New doc: `infrastructure/home-server/os-and-hardening.md`.
- Updates `infrastructure/home-server/README.md` (created by packet 01 or this packet, whichever lands first) to list the new doc.

## Proposed Implementation

### Document structure for `os-and-hardening.md`
1. **OS choice** — name (e.g., Ubuntu Server LTS, Debian stable, NixOS, Windows Server, etc.), version, rationale (LTS cadence, container support, operator familiarity).
2. **Rejected alternatives** — one line each for any OS considered and rejected.
3. **Install checklist** — disk layout (LVM/ZFS/plain), encryption disposition (LUKS / BitLocker / none-with-rationale), hostname, timezone, locale.
4. **User and account model** (D5: "Dedicated OS user/service accounts for long-running automation where practical") — operator account, dedicated service accounts for OpenClaw, for the ADR-0044 webhook bridge, and for the Cloudflare Tunnel daemon. Each with the principle of least privilege; sudoers entries enumerated.
5. **Secret storage at the OS layer** (D5: "Secrets stored in OS credential storage, OpenClaw config secrets, or Vault-backed mechanisms; never committed to repo files") — name the mechanism (e.g., `pass`, Linux keyring, Windows Credential Manager, sops-with-age) and which secrets live there vs. in HoneyDrunk.Vault. Cloudflare Tunnel credentials get an explicit row (D5 calls them out by name).
6. **Update posture** (D5: "Automatic OS/package updates configured conservatively") — unattended-upgrades or equivalent configured for security-only by default; reboot window documented.
7. **Network and SSH** — firewall default-deny inbound; SSH key-only, no password auth; SSH port choice; fail2ban or equivalent disposition.
8. **Audit logging** — `journald`/`auditd` retention, where logs ship (local + optional Pulse sink later).
9. **Backups handoff** — links to packet 05's backup plan; this doc only confirms the OS install enables the backup mechanism that plan describes.
10. **Applied evidence** — a single line the operator fills in after running the playbook: "Applied to `<hostname>` on `YYYY-MM-DD`."

## Affected Files
- `infrastructure/home-server/README.md` (update to add this artifact; create if not yet present)
- `infrastructure/home-server/os-and-hardening.md` (new)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] Doc lives in `HoneyDrunk.Architecture/infrastructure/home-server/`.
- [x] No code change; no Node touched.
- [x] No secret committed — secret *names* and storage *locations* only.

## Acceptance Criteria
- [ ] `infrastructure/home-server/os-and-hardening.md` exists with the OS name, version, and rationale recorded
- [ ] The doc enumerates at least one rejected alternative OS with a one-line reason
- [ ] Dedicated service accounts are named for OpenClaw, the ADR-0044 webhook bridge, and the Cloudflare Tunnel daemon, each with their privilege envelope documented (D5)
- [ ] OS-layer secret storage mechanism is named and rationalized; Cloudflare Tunnel credential storage is called out as a distinct row (D5)
- [ ] Automatic-update posture is documented (mechanism, scope, reboot window) per D5
- [ ] SSH posture is documented (key-only, no password auth; port; brute-force defense disposition)
- [ ] Firewall default is recorded as deny-inbound with explicit allow rules listed (this is the OS-layer counterpart to D2's "no public router/firewall exposure" — the local firewall is also default-deny)
- [ ] Audit log retention and storage location are recorded
- [ ] The doc has a placeholder "Applied to `<hostname>` on `YYYY-MM-DD`" line that the operator fills in after running the playbook
- [ ] `infrastructure/home-server/README.md` lists this artifact (created or updated)
- [ ] Repo-level `CHANGELOG.md` entry for ADR-0081 appended (per invariants 12, 27 — append to the in-progress entry created by packet 01, or create it here if 01 has not landed)
- [ ] No secret value appears in any committed file (invariant 8)

## Human Prerequisites
- [ ] Decide the OS (operator judgment call — familiarity, container ergonomics, LTS posture)
- [ ] Install the OS on the chosen hardware
- [ ] Apply the hardening playbook against the freshly installed host
- [ ] Fill in the "Applied to ... on ..." line in the doc once the playbook is applied (this can be a follow-up PR or part of the same PR depending on timing)

## Dependencies
None. Can land before or independently of packet 01 (hardware brief). The doc is useful design even if hardware has not arrived yet.

## Agent Handoff

**Objective:** Document the home-server OS choice and a runnable base-hardening playbook so ADR-0081's second Acceptance Criterion is satisfied.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Satisfy ADR-0081 Acceptance Criterion 2 ("OS choice is confirmed") and concretize D5 ("Security posture is least-privilege and recoverable").
- Feature: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure.
- ADRs: ADR-0081 (this initiative).

**Acceptance Criteria:** (mirrored above)

**Dependencies:** None among the Wave 1 packets.

**Constraints:**
- ADR-0081 D5 (full text): "The server must be treated as infrastructure, not a casual desktop:
  - Dedicated OS user/service accounts for long-running automation where practical.
  - Secrets stored in OS credential storage, OpenClaw config secrets, or Vault-backed mechanisms; never committed to repo files.
  - Cloudflare Tunnel credentials protected as machine secrets.
  - GitHub tokens scoped to required repos/actions only.
  - Automatic OS/package updates configured conservatively.
  - Regular backup of OpenClaw state, config, and durable automation metadata.
  - No autonomous destructive or external actions beyond the same review/approval rules that apply on the workstation."
- ADR-0081 D2 forbids public router/firewall exposure. The OS-layer firewall posture in this doc is the local complement to that rule — default-deny inbound at the host, not just at the router.
- Invariant 8: "Secret values never appear in logs, traces, exceptions, or telemetry." The doc names secret *storage locations*, never values.
- Invariant 9: "Vault is the only source of secrets" for *Grid Node* secret access. OS-layer secrets (Cloudflare Tunnel credential, OS service-account secrets) live in OS credential storage per D5; this is consistent because the home server is not a Grid Node, it is operator infrastructure that hosts Grid-Node-adjacent processes.

**Key Files:**
- `infrastructure/home-server/os-and-hardening.md` (new — primary artifact)
- `infrastructure/home-server/README.md` (update or create)
- `CHANGELOG.md` (append to or create the in-progress ADR-0081 entry)

**Contracts:** None — documentation packet.

---

## PR Body Requirements
The PR opened against `HoneyDrunk.Architecture` for this packet must include in its body:

```
Authorship: Agent
Work Item: generated/work-items/proposed/adr-0081-home-server/02-architecture-home-server-os-hardening-playbook.md
```

If multiple Wave 1 packets land in one combined PR per the initiative's cadence rule, list the additional packets on separate `Work Item:` lines (one per line) or use a single `Work Item:` line pointing to the dispatch plan with the individual packet paths in the PR description.
