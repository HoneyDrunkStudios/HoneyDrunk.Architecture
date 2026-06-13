---
initiative: adr-0081-home-server
adr: ADR-0081
status: proposed
generator: scope
source: strategic
---

# Dispatch Plan: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure

## Summary
ADR-0081 introduces a small always-on home server as the preferred host for OpenClaw, ADR-0044 webhook bridge, Cloudflare Tunnel, scheduled local automations, and local-agent experimentation. This is **operator-owned local infrastructure**, not a customer-facing production host. The ADR's Acceptance Criteria explicitly require five documented artifacts before the ADR can flip to `Accepted`:

1. Hardware target and budget confirmed.
2. OS choice confirmed.
3. Cloudflare Tunnel + OpenClaw bridge migration plan documented.
4. Backup plan for OpenClaw state/config documented.
5. Security checklist for the server before exposing any tunnel-backed endpoint.

This initiative produces a packet for each Acceptance-Criteria artifact, a migration runbook for D6's incremental order, and a final acceptance/flip packet.

## Trigger
ADR-0081 currently sits at `Proposed` (2026-05-24). ADR-0044's webhook-first direction sharpened the need — a Cloudflare Tunnel can expose a narrow local webhook bridge, but the bridge still needs a stable local host, and the workstation is not it.

## Target repo
All packets target `HoneyDrunkStudios/HoneyDrunk.Architecture`. There are **no Core-Node code changes**. The artifacts are docs in `infrastructure/home-server/` plus updates to `adrs/ADR-0081-...md` (status flip).

## One-PR-per-repo cadence
Per the operator's cadence rule (one PR per repo per initiative), the doc packets in Wave 1 should be batched into a single PR against `HoneyDrunk.Architecture`. The Wave 2 acceptance packet flips ADR status and lands as a small follow-up PR after Wave 1 merges and the operator has executed the human prerequisites.

If the Wave 1 PR grows uncomfortably large, the operator may split it along natural seams (e.g., hardware/OS in one PR, tunnel/backup/security in a second). The packets remain discrete issues on The Hive regardless of how PRs are sliced.

**Post-hardware-purchase amendment caveat.** Packets 01 (hardware brief), 02 (OS choice + base hardening), and 06 (D6 migration runbook) carry hardware-install-dependent doc content. The operator may not have the hardware purchased when these artifacts are authored — they can be authored ahead of the purchase as decision documents, but specific OS-tuning details, runbook command transcripts, and concrete network/storage/UPS topology may need a follow-up amendment once the actual hardware is in hand. This is low-risk because the home server is operator-internal infrastructure (per ADR-0082 packet 01's operator-internal automation infrastructure carve-out — see Discussion in ADR-0081); a docs-amendment PR after first boot is the normal mode. Flag the amendment as a discrete follow-up PR against `HoneyDrunk.Architecture` if substantive content changes; small corrections fold into the Wave 2 acceptance PR.

## Waves

### Wave 1 — Documented prerequisites for ADR acceptance (parallelizable, no inter-dependencies among themselves)
- [ ] **01** `Architecture`: Author hardware selection and budget brief (D3) — `Actor=Human` (purchasing decision)
- [ ] **02** `Architecture`: Author OS choice and base hardening playbook (D5) — `Actor=Agent` with human-prereq install steps
- [ ] **03** `Architecture`: Author the pre-exposure security checklist (D2, D5) — `Actor=Agent`
- [ ] **04** `Architecture`: Author the Cloudflare Tunnel + ADR-0044 webhook-bridge migration plan (D2, D6) — `Actor=Agent`
- [ ] **05** `Architecture`: Author the OpenClaw state and config backup plan (D5) — `Actor=Agent`
- [ ] **06** `Architecture`: Author the D6 incremental migration runbook (D6) — `Actor=Agent` with human-prereq cutover steps

### Wave 2 — Accept the ADR and record the operational floor
Blocked by all Wave 1 packets.
- [ ] **07** `Architecture`: Flip ADR-0081 status to `Accepted` and record acceptance evidence (`Actor=Human`)

There is no Wave 3. All code-Node integration with the home server (OpenClaw migration execution, scheduled-job movement, etc.) is documented in the Wave 1 runbook (packet 06) and executed by the operator following that runbook — it does not produce additional packets in this initiative.

## Site sync
No website data changes. ADR-0081 is operator-internal infrastructure; it is not published on `honeydrunkstudios.com`.

## Rollback plan
If the home server proves a poor fit before acceptance, the doc artifacts remain useful as design notes. Reverting is a no-op: workstation hosting remains valid (D6 — "the workstation setup remains valid until the home server is ready"). The ADR can be moved to `Superseded` or `Rejected` and the docs archived alongside.

## Filing
Filing is automated. Once these packets land on `main` under `proposed/adr-0081-home-server/`, they are **not yet** filed as GitHub issues — per ADR-0043, the human triages `proposed/` → `active/` before `file-work-items.yml` picks them up. No `gh issue create` commands are emitted here.

## Out-of-scope follow-ups (noted, not packeted)
- GPU/local-LLM hosting — explicitly deferred by D4 to a future ADR.
- Cloud relay for webhook durability when the home server is offline — explicitly deferred in Neutral/Follow-up.
- Broader local-infrastructure backup/DR policy — explicitly deferred in Neutral/Follow-up.
- UPS procurement — D3 says "recommended once the box becomes relied upon," but the ADR does not require it for acceptance; folded as a note in packet 01.
