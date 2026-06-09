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

# Author the home-server OpenClaw state and config backup plan (ADR-0081 D5)

## Summary
Author `infrastructure/home-server/backup-plan.md` describing what gets backed up from the home server (OpenClaw state, OpenClaw config, ADR-0044 bridge config, tunnel config, scheduled-job metadata, OS-credential-store contents), the cadence, the destination, the restore procedure, and the verification cadence. Satisfies ADR-0081's fourth Acceptance Criterion ("Backup plan for OpenClaw state/config is documented").

## Context
ADR-0081 D5 requires "Regular backup of OpenClaw state, config, and durable automation metadata." Without a documented plan, "backup" stays an intention; with one, the operator can both run the backups and trust the restore. ADR-0081's Neutral/Follow-up section also notes "A future ADR may define a broader local-infrastructure backup/DR policy if the server becomes mission-critical" — this packet is the operational floor that lives until that broader ADR exists.

## Scope
- New doc: `infrastructure/home-server/backup-plan.md`.
- Updates `infrastructure/home-server/README.md` to list it.

## Proposed Implementation

### Document structure for `backup-plan.md`

1. **What is backed up**
   - **OpenClaw state** — sessions, durable metadata, anything OpenClaw persists between restarts. Identify the exact paths.
   - **OpenClaw config** — config files the operator hand-edited (not regeneratable from default install).
   - **ADR-0044 bridge config** — bridge service unit file, config file, log location.
   - **Cloudflare Tunnel config** — `cloudflared` config file and credentials file path (note: credentials are sensitive; backed-up credentials are themselves a secret-handling concern, see below).
   - **Scheduled-job metadata** — crontab / systemd timer files / scheduled task XML.
   - **OS credential store** — `pass` store, keyring DB, or equivalent. Note this contains secrets and must be encrypted at the backup destination.
   - **Host config** — `/etc/` subset (firewall rules, sshd config, the things hardening touched per packet 02).

2. **What is NOT backed up** (and why)
   - The OS root partition (re-installable from packet 02's playbook).
   - Container images (re-pullable).
   - Source code / worktrees (already on GitHub; the home server is not their source of truth).
   - HoneyDrunk.Vault contents (lives in Azure; backed up by Azure per ADR-0005).

3. **Cadence**
   - Backups run daily. Restore-tested monthly.
   - Cadence rationale: OpenClaw state changes session-by-session; daily is the right granularity for a solo-operator workload. More frequent adds noise; less frequent risks losing a day of session data.

4. **Destination**
   - Primary: external drive or NAS (named in packet 01's hardware brief).
   - Encryption: backups are encrypted at rest (mechanism named — restic native encryption, age, or equivalent).
   - Retention: 30 daily rolling snapshots; 6 monthly snapshots. Rationale: 30 days catches "I broke something a few days ago," 6 months catches "I broke something subtly months ago."

5. **Tooling**
   - Choose one: `restic`, `borg`, `rsync` + hardlink rotation, or equivalent. Document the choice and the exact backup command.
   - Document where the backup tool's own credential (repo password / SSH key) lives — OS credential store per packet 02, never on disk in cleartext (invariant 8).

6. **Restore procedure**
   - Step-by-step: how to restore OpenClaw state to a freshly-installed home server. The procedure should be runnable from packet 02's hardening playbook + packet 06's migration runbook + this restore section, with no extra knowledge required.
   - Document the expected restore time. If it's > 30 minutes, note that as a known constraint and a future improvement.

7. **Restore verification cadence**
   - Monthly: pick a random file from the backup; verify it restores byte-identical to the source.
   - Quarterly: rehearse a full restore to a scratch VM or directory; OpenClaw must start and load state successfully.
   - Verification results are appended to a "Restore log" section at the bottom of this doc — date, what was tested, pass/fail.

8. **Failure modes**
   - Destination full: documented response.
   - Destination unreachable (NAS offline, drive disconnected): documented response.
   - Backup tool authentication failure: documented response.
   - Each failure mode says how the operator will notice (Pulse alarm, scheduled task non-completion notification, etc.) — backup-silent-failures are the worst kind.

## Affected Files
- `infrastructure/home-server/backup-plan.md` (new)
- `infrastructure/home-server/README.md` (update)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] Doc lives in `HoneyDrunk.Architecture/infrastructure/home-server/`.
- [x] No code change; no Node touched.
- [x] No secret committed.

## Acceptance Criteria
- [ ] `infrastructure/home-server/backup-plan.md` exists with the eight sections above
- [ ] "What is backed up" lists OpenClaw state, OpenClaw config, ADR-0044 bridge config, Cloudflare Tunnel config, scheduled-job metadata, OS credential store, and host config — each with the exact paths on the chosen OS
- [ ] "What is NOT backed up" lists at least the OS root partition, container images, worktrees, and Vault contents, each with a one-line reason
- [ ] Cadence is daily backups, monthly restore-tests, quarterly full-restore rehearsals
- [ ] Destination, encryption mechanism, and retention policy are recorded
- [ ] Backup tooling is named (restic / borg / equivalent) with the exact backup command documented
- [ ] Restore procedure is step-by-step and self-contained (modulo packet 02 + packet 06)
- [ ] Restore-log section exists at the bottom of the doc for the operator to append verification results
- [ ] At least three failure modes (destination-full, destination-unreachable, auth-failure) are documented with detection and response
- [ ] `infrastructure/home-server/README.md` lists this artifact
- [ ] Repo-level `CHANGELOG.md` entry for ADR-0081 appended (per invariants 12, 27)
- [ ] No secret value (backup repo password, credential store contents, tunnel credential) appears in any committed file (invariant 8)

## Human Prerequisites
- [ ] None for authoring the plan. Setting up the backup tool, configuring the destination, and running the first backup are operator follow-ups once the hardware is online.

## Dependencies
None. Can land in parallel with all other Wave 1 packets. References packets 01 (hardware brief — backup destination) and 02 (OS hardening — secret storage) conceptually, not file-link-dependently.

## Agent Handoff

**Objective:** Produce the backup plan for OpenClaw state and home-server config so ADR-0081's fourth Acceptance Criterion is satisfied and the home server is not a single-machine single-point-of-failure for Grid automation state.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Satisfy ADR-0081 Acceptance Criterion 4 ("Backup plan for OpenClaw state/config is documented").
- Feature: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure.
- ADRs: ADR-0081 (this initiative).

**Acceptance Criteria:** (mirrored above)

**Dependencies:** None among the Wave 1 packets.

**Constraints:**
- ADR-0081 D5 (relevant excerpt): "Regular backup of OpenClaw state, config, and durable automation metadata."
- ADR-0081 Neutral/Follow-up: "A future ADR may define a broader local-infrastructure backup/DR policy if the server becomes mission-critical." — this plan is the operational floor until that ADR exists; design it so the future ADR can extend it without rewriting.
- Invariant 8: "Secret values never appear in logs, traces, exceptions, or telemetry." — applies to backup logs and backup-tool authentication state too.
- Invariant 9: Vault is the source of secrets for Grid Nodes. The home server's OS credential store (which contains the backup-tool repo password, tunnel credential, etc.) is *operator infrastructure secret storage*, not a Grid secret store — this distinction is per ADR-0081 D5's explicit "OS credential storage, OpenClaw config secrets, or Vault-backed mechanisms" enumeration.

**Key Files:**
- `infrastructure/home-server/backup-plan.md` (new — primary artifact)
- `infrastructure/home-server/README.md` (update)
- `CHANGELOG.md` (append)

**Contracts:** None.

---

## PR Body Requirements
The PR opened against `HoneyDrunk.Architecture` for this packet must include in its body:

```
Authorship: Agent
Packet: generated/issue-packets/proposed/adr-0081-home-server/05-architecture-home-server-openclaw-backup-plan.md
```
