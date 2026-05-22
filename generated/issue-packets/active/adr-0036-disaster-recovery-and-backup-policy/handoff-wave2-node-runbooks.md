# Handoff: Wave 1 → Wave 2 (foundational artifacts → per-Node runbook documentation)

**Read once at the Wave 1 → Wave 2 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## What Wave 1 delivered (upstream artifacts Wave 2 builds on)

- **ADR-0036 is Accepted** (packet 00). Its two new DR invariants are live in `constitution/invariants.md`, numbered **60** and **61**: (60) every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json` — missing assignment is drift; (61) a missed restore drill freezes tier-affecting tenant onboarding for the affected Node. ADR-0036's D1–D9 are now binding rules.
- **`catalogs/grid-health.json` carries a `dr_tier` field on every Node** (packet 01). Vault and Audit = `T0`; Notify = `T1`; Pulse = `T2`. Memory/Knowledge = `T1`, Flow/Evals = `T2` (provisional, confirmed at standup). Stateless Nodes (Kernel, Transport, Web.Rest, Communications, Actions, Architecture, Standards, Studios) = explicit `null`. `honeydrunk-data` = `null` + a tier-inheritance note: `Audit.Data → T0, Memory.Data → T1, Pulse.Data → T2`.
- **`generated/dr-runbook.template.md` exists** (packet 02) — the shared runbook skeleton with eight sections: Node+Tier, tier rationale, backing inventory, restore procedure, failover procedure, tenant-scoped restore, cross-Node recovery ordering, drill cadence + last-drill record. Its per-tier RPO/RTO/cadence values are quoted from ADR-0036 D1. (The repo has no `templates/` directory; the shared template lives in `generated/`.)
- **`generated/restore-drills/` exists** (packet 02) — the rolling drill-outcome log directory, with a README and a drill-log entry schema: `date`, `tier`, `node`, `outcome` (pass/fail/partial), `runbook-deltas`, `operator`.

## Artifacts Wave 2 consumes

- **The packet-02 template at `generated/dr-runbook.template.md`** — packets 03, 06, 08 each copy it and fill in the bracketed slots for their Node. Do not invent a new structure; the template is the contract.
- **The packet-01 `dr_tier` values** — each runbook's tier must match the catalog. Vault = T0, Audit = T0, Notify = T1.
- **The ADR-0036 D1 tier definitions** — the template carries the RPO/RTO/geo/cadence per tier; confirm the runbook inherits them correctly.
- **The ADR-0036 D2 backup-mechanics table** — per-backing-slot Azure configuration; each runbook's backing-inventory section records the D2 config for its Node's actual backing resource type.

## Wave 2 objectives

Three independent per-Node runbook documentation packets, fully parallel:

1. **Vault T0 runbook + bootstrap-recovery procedure** (packet 03) — `repos/HoneyDrunk.Vault/dr-runbook.md` (T0) plus `vault-bootstrap-recovery.md`, the D6 special-case recovery procedure. Vault recovery is the special case: every other Node's DR depends on Vault being readable, so the bootstrap-recovery procedure must exist before any other T0 drill. The offline encrypted recovery *artifact* is provisioned later by packet 04 (`Actor=Human`); packet 03 writes the *procedure*. The recovery-ordering line (Vault recovers first) goes in `integration-points.md`.
2. **Audit T0 runbook** (packet 06) — `repos/HoneyDrunk.Audit/dr-runbook.md` (T0). Records the `Audit.Data → T0` tier-inheritance rule and the `Vault → Data → Audit` cross-Node recovery ordering in `integration-points.md`. The backing is `HoneyDrunk.Audit.Data`, which is Data-backed over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`; `HoneyDrunk.Data` ships EF Core + SQL Server providers, so the durable backing is **Azure SQL**. Record the Azure SQL T0 D2 mechanics — single-branch, no Cosmos fork.
3. **Notify T1 runbook** (packet 08) — `repos/HoneyDrunk.Notify/dr-runbook.md` (T1) covering delivery state (in-flight messages, retry queues) and the Service Bus geo-DR alias-pairing posture. Scoped to `HoneyDrunk.Notify` only — Notify Cloud T0 DR is deferred to the Notify Cloud standup.

## Constraints carried into Wave 2

> **Invariant 60 (packet 00) — every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json`.** Each runbook's stated tier must match the packet-01 catalog value exactly.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No secret value in any runbook or the Vault bootstrap-recovery doc — only names, identifiers, and procedure steps.

> **Invariant 47 — Phase-1 audit integrity is append-only-by-interface; it is explicitly not tamper-evident, and Phase 1 must not be documented or marketed as such.** The Audit runbook (packet 06) describes durability and restore — never tamper-evidence / WORM, which is deferred ADR-0030 Phase 2 work.

> **Invariant 17 — One Key Vault per deployable Node per environment, `kv-hd-{service}-{env}`.** The Vault runbook's backing inventory names the vaults by this convention.

- **The Vault offline recovery artifact never enters the repo.** ADR-0036 D6 — the repo is itself a recovery dependency. The packet-03 `vault-bootstrap-recovery.md` points to `business/context/` for the artifact's location; it does not embed recovery material.
- **Vault recovery goes first; Audit recovers after Data, after Vault.** The recovery-ordering lines in `integration-points.md` are load-bearing — packet 07b's Audit drill is hard-sequenced after packet 05's Vault drill because of this ordering.
- **In-flight Service Bus messages are not failover-durable** (ADR-0036 D2). The Notify runbook states this plainly; recovery relies on consumer idempotency (ADR-0042), not message preservation.
- **Notify ≠ Notify Cloud.** Packet 08 is the Notify T1 runbook. Notify Cloud's T0 runbook, tenant identity/billing backup, and tenant-scoped restore are out of scope — Notify Cloud is not yet scaffolded; that work belongs to the Notify Cloud standup, which inherits a hard checklist item for the T0 runbook + D5 tenant-scoped restore.
- **Audit's backing is Azure SQL — single-branch, no fork.** `Audit.Data` is Data-backed over `HoneyDrunk.Data`'s SQL Server provider; the Audit runbook records the Azure SQL D2 mechanics only. **Notify:** confirm the live Service Bus / Storage Queue topology from `repos/HoneyDrunk.Notify/` docs or `catalogs/`; if undeterminable, document the likely shape and flag for the operator.

## Acceptance signal for Wave 2 completion

`repos/HoneyDrunk.Vault/dr-runbook.md` + `vault-bootstrap-recovery.md` exist with the Vault recovery-ordering line in `integration-points.md`; `repos/HoneyDrunk.Audit/dr-runbook.md` exists with the `Audit.Data → T0` and `Vault → Data → Audit` lines in `integration-points.md`; `repos/HoneyDrunk.Notify/dr-runbook.md` exists with the Service Bus DR posture + ADR-0042 idempotency dependency in `integration-points.md`. All three runbooks follow the packet-02 template and state the correct tier. Wave 3 (Vault Azure backup config + `hive-sync` extension) and Wave 4 (the drills) build directly on these documents.
