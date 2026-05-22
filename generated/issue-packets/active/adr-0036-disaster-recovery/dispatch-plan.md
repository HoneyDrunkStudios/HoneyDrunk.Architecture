# Dispatch Plan: Disaster Recovery and Backup Policy (ADR-0036)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0036 acceptance).
**Trigger:** ADR-0036 (Disaster Recovery and Backup Policy) — Proposed 2026-05-21, part of the 2026-05-21 batch of cross-cutting Grid-gap ADRs. Scoped now so the packet set is ready when the ADR lands. The forcing function per ADR-0036's Context is PDR-0002 / ADR-0027 Notify Cloud GA ("what's your RPO?" is the first paying-tenant onboarding question) and ADR-0030 Audit (a security audit log with undefined durability carries an unjustified trust premium).
**Type:** Multi-repo. Most work lands in `HoneyDrunk.Architecture` (the ADR flip, catalog field, runbook template, per-Node runbook docs, `hive-sync` extension) — the per-Node runbook docs live in the `repos/{name}/` context directories which are in the Architecture repo. The four `Actor=Human` Azure-portal/drill packets (04, 05, 07a, 07b) are tracked against `HoneyDrunk.Vault` and `HoneyDrunk.Audit`.
**Sector:** Infrastructure / cross-cutting.
**Site sync required:** No. DR policy, tier assignments, runbooks, and drill logs are operational artifacts, not public-facing content on the Studios marketing site. Re-evaluate only if a future "trust / security" page on the Studios site states an RPO commitment publicly — that would be a separate site-sync packet, and ADR-0036's tier table would be its source.

**Rollback plan:**
- Architecture-side packets (00, 01, 02, 09) revert cleanly via `git revert` — the ADR flip, the two invariants, the `dr_tier` catalog field, the runbook template, the `restore-drills/` directory, and the `hive-sync` extension are all docs/text/catalog edits with no runtime consumer. Reverting `dr_tier` from `grid-health.json` is safe; `hive-sync` is the only reader and packet 09 adds that reader — revert both together if rolling back.
- The per-Node runbook packets (03, 06, 08) are pure documentation — `dr-runbook.md` files and `integration-points.md` edits. Reverting deletes the docs; no runtime impact.
- The three `Actor=Human` config/artifact packets (04, 07a) and the drill packets (05, 07b): "reverting" the Azure portal backup configuration is not advisable (soft-delete / purge protection / geo-redundancy / geo-redundant SQL storage are strictly safer states and purge protection is irreversible by design). The offline recovery artifact (packet 04) — "reverting" means destroying the artifact, which is never wanted. Treat 04 and 07a as forward-only operational work; if they are not yet done, the steady state is simply "DR config not yet applied," which is the pre-ADR baseline.
- Packet 05 (Vault drill) and packet 07b (Audit drill) leave only a drill-log entry in `generated/restore-drills/` — reverting deletes the log entry. The ephemeral environments are torn down by the packets themselves.

## Summary

ADR-0036 sets the Grid-wide DR and backup policy: three durability tiers (T0/T1/T2) with explicit RPO/RTO targets, geo posture, and restore-drill cadence (D1); concrete Azure backup mechanics per backing-slot type (D2); restore drills as the proof a backup works (D3); manual cross-region failover via documented runbooks — no automated failover at solo-developer scale (D4); tenant-scoped restore for multi-tenant Nodes (D5); a Vault bootstrap-recovery procedure that must exist before any other T0 drill (D6); backup-retention-vs-data-subject-deletion handling (D7); a cost ceiling that makes tier promotion an ADR amendment (D8); and the documentation surface — per-Node `dr-runbook.md`, the `dr_tier` field in `catalogs/grid-health.json`, and `generated/restore-drills/` (D9).

This initiative ships **11 packets** (`00`–`06`, `07a`, `07b`, `08`, `09`) across **four waves**:

- **Wave 1** — governance + foundational artifacts: ADR acceptance + the two DR invariants (00), the `dr_tier` catalog field + backfill (01), the `generated/dr-runbook.template.md` template + `generated/restore-drills/` directory (02).
- **Wave 2** — the per-Node runbook documentation: Vault T0 runbook + bootstrap-recovery procedure (03), Audit T0 runbook (06), Notify T1 runbook (08). All three are documentation packets and run in parallel after Wave 1.
- **Wave 3** — the Vault T0 Azure backup configuration + the offline bootstrap-recovery artifact (04, `Actor=Human`), the Audit.Data T0 Azure SQL backup configuration (07a, `Actor=Human`), and the `hive-sync` DR drift-detection extension (09). 04, 07a, and 09 are independent of each other and run in parallel; 07a depends only on the Audit runbook (06), not on any drill.
- **Wave 4** — the restore drills: the first Vault drill (05) and the first Audit drill (07b). Both `Actor=Human`. The Audit drill is hard-sequenced after the Vault drill per the Vault → Data → Audit recovery ordering.

## Important constraints (from ADR-0036 itself)

- **Vault recovery is the special case and goes first.** ADR-0036 D6: every other Node's DR depends on Vault being readable; the Vault bootstrap-recovery procedure (procedure doc = packet 03; offline artifact = packet 04) must exist before any other T0 drill. The drill order is fixed: Vault drill (05) before Audit drill (07b).
- **Tier promotion is an ADR amendment, not a config change.** ADR-0036 D8. Packet 01 records the tier assignments; moving a Node up a tier later is a new ADR, not a `grid-health.json` edit.
- **Manual failover only.** ADR-0036 D4: no automated cross-region failover at this stage — spurious failover under solo-developer operations is a worse failure mode than degraded availability. Every runbook documents a manually-triggered failover.
- **In-flight messages are not failover-durable.** ADR-0036 D2: Service Bus geo-DR forced failover does not preserve in-flight messages; the recovery posture relies on consumer idempotency (ADR-0042). ADR-0036 and ADR-0042 are mutually load-bearing.
- **The offline recovery artifact never enters the repo.** ADR-0036 D6: the GitHub-hosted Architecture repo is itself a recovery dependency. The artifact is physical (encrypted USB / printed shares); its location is recorded in `business/context/`, not in `repos/`.
- **Stateless Nodes are not tiered.** ADR-0036 D1: Kernel, Transport, Web.Rest, Communications, Actions, Architecture, Standards, Studios have DR posture "redeploy from source" via ADR-0033 — `dr_tier: null`, explicitly, so the absence is unambiguous.
- **Data inherits its consumer's tier.** ADR-0036 Consequences: `HoneyDrunk.Data` has no own tier; `Audit.Data → T0, Memory.Data → T1, Pulse.Data → T2`. `HoneyDrunk.Audit.Data` is Data-backed over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`; `HoneyDrunk.Data` ships EF Core + SQL Server providers — so the Audit backing is concretely **Azure SQL**. The Audit runbook (06) and the Audit backup-config packet (07a) are single-branch Azure SQL, with no Cosmos fork.
- **Audit durability ≠ tamper-evidence.** ADR-0036 gives Audit T0 durability; the ADR-0030 Phase 2 hash-chain/WORM tamper-evidence work is decoupled and still deferred. Per invariant 47, Phase 1 must not be documented or marketed as tamper-evident — the Audit runbook (packet 06) describes durability only.

## Wave Diagram

### Wave 1 — Governance + foundational artifacts

Run packet 00 first (ADR acceptance + the two invariants). Packets 01 and 02 may run in parallel with each other after 00 — 01 is a catalog field, 02 is the runbook template + directory; neither depends on the other.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0036** — flip status, add the two DR invariants, register the initiative — [`00-architecture-adr-0036-acceptance.md`](00-architecture-adr-0036-acceptance.md)
  - Blocked by: nothing.
- [ ] `HoneyDrunk.Architecture`: Add the `dr_tier` field to `grid-health.json` and backfill every stateful Node — [`01-architecture-dr-tier-catalog-field-and-backfill.md`](01-architecture-dr-tier-catalog-field-and-backfill.md)
  - Blocked by: Wave 1 — `00` (soft — references the packet-00 `dr_tier` invariant as a live rule).
- [ ] `HoneyDrunk.Architecture`: Create the `generated/dr-runbook.template.md` template and the `generated/restore-drills/` directory — [`02-architecture-dr-runbook-template-and-restore-drills-directory.md`](02-architecture-dr-runbook-template-and-restore-drills-directory.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0036 D3/D9 as live rules).

**Wave 1 exit criteria:**
- ADR-0036 reads `**Status:** Accepted`; the two DR invariants (numbered 60 and 61) are in `constitution/invariants.md`; the initiative is registered.
- `catalogs/grid-health.json` carries a new `dr_tier` field on every Node (a genuine schema addition — `_meta.schema_version` bumped); stateful Nodes have T0/T1/T2; stateless Nodes have explicit `null`; Data has `null` + the tier-inheritance note.
- `generated/dr-runbook.template.md` exists with its eight sections; `generated/restore-drills/` exists with its README and drill-log schema.

### Wave 2 — Per-Node runbook documentation (parallel)

Packets 03, 06, 08 are independent documentation packets. They all consume the packet-02 template and the packet-01 `dr_tier` field. They may run fully in parallel.

- [ ] `HoneyDrunk.Vault` (docs in `HoneyDrunk.Architecture`): Author the Vault T0 `dr-runbook.md` + the `vault-bootstrap-recovery.md` procedure — [`03-vault-dr-runbook-and-bootstrap-recovery-doc.md`](03-vault-dr-runbook-and-bootstrap-recovery-doc.md)
  - Blocked by: Wave 1 — `01` (soft), `02` (hard — fills in the template).
- [ ] `HoneyDrunk.Audit` (docs in `HoneyDrunk.Architecture`): Author the Audit T0 `dr-runbook.md` with the Data tier-inheritance and recovery-ordering rules — [`06-audit-dr-runbook.md`](06-audit-dr-runbook.md)
  - Blocked by: Wave 1 — `01` (soft), `02` (hard — fills in the template).
- [ ] `HoneyDrunk.Notify` (docs in `HoneyDrunk.Architecture`): Author the Notify T1 `dr-runbook.md` for delivery state + Service Bus DR posture — [`08-notify-dr-runbook-t1.md`](08-notify-dr-runbook-t1.md)
  - Blocked by: Wave 1 — `01` (soft), `02` (hard — fills in the template).

**Wave 2 exit criteria:**
- `repos/HoneyDrunk.Vault/dr-runbook.md` and `vault-bootstrap-recovery.md` exist; the Vault recovery-ordering line is in `integration-points.md`.
- `repos/HoneyDrunk.Audit/dr-runbook.md` exists; the `Audit.Data → T0` tier-inheritance and `Vault → Data → Audit` recovery ordering are in `integration-points.md`.
- `repos/HoneyDrunk.Notify/dr-runbook.md` exists; the Service Bus DR posture + ADR-0042 idempotency dependency are in `integration-points.md`.

### Wave 3 — Vault Azure backup config + Audit.Data backup config + the hive-sync extension (parallel)

Packets 04, 07a, and 09 are independent of each other and may run in parallel. Packets 04 and 07a are `Actor=Human`; packet 09 is `Actor=Agent`.

- [ ] `HoneyDrunk.Vault`: Apply Vault T0 Azure backup configuration + create the offline bootstrap-recovery artifact — [`04-vault-t0-backup-config-and-offline-recovery-artifact.md`](04-vault-t0-backup-config-and-offline-recovery-artifact.md)
  - Blocked by: Wave 2 — `03` (hard — the bootstrap-recovery procedure doc must exist for packet 04 to execute it).
  - **`Actor=Human` — `human-only` label set.** Azure Portal configuration of Key Vault backup flags and the creation of a physical encrypted offline artifact cannot be delegated.
- [ ] `HoneyDrunk.Audit`: Apply Audit.Data T0 Azure SQL backup configuration — [`07a-audit-data-t0-backup-config.md`](07a-audit-data-t0-backup-config.md)
  - Blocked by: Wave 2 — `06` (hard — the Audit runbook must exist so the live config can be checked against it). No dependency on the Vault drill — this is the config step, not the drill.
  - **`Actor=Human` — `human-only` label set.** Azure Portal configuration of Azure SQL backup flags cannot be delegated.
- [ ] `HoneyDrunk.Architecture`: Extend `hive-sync` to reconcile `dr_tier` assignments and overdue restore drills — [`09-architecture-hive-sync-dr-drift-detection.md`](09-architecture-hive-sync-dr-drift-detection.md)
  - Blocked by: Wave 1 — `01` (hard — the `dr_tier` field must exist to reconcile), `02` (hard — `restore-drills/` must exist to reconcile).

**Wave 3 exit criteria:**
- Every Vault Key Vault has soft-delete + purge protection on, 90-day retention, diagnostics to Log Analytics; the offline encrypted bootstrap-recovery artifact exists with its location recorded in `business/context/`.
- The Audit.Data Azure SQL backing has T0 backup configuration applied — geo-redundant storage, weekly LTR for 1 year, 35-day PITR.
- `hive-sync` reconciles `dr_tier` completeness and restore-drill currency, surfacing both as board-item drift findings.

### Wave 4 — Restore drills

Packet 05 (Vault drill) goes first. Packet 07b (first Audit drill) is hard-sequenced after 05 per the Vault → Data → Audit recovery ordering.

- [ ] `HoneyDrunk.Vault`: Execute the first Vault T0 restore drill and log the outcome — [`05-vault-first-restore-drill.md`](05-vault-first-restore-drill.md)
  - Blocked by: Wave 3 — `04` (hard — the offline artifact and backup config must be in place for a meaningful drill).
  - **`Actor=Human` — `human-only` label set.**
- [ ] `HoneyDrunk.Audit`: Execute the first Audit T0 restore drill and log the outcome — [`07b-audit-first-restore-drill.md`](07b-audit-first-restore-drill.md)
  - Blocked by: Wave 4 — `05` (hard — the Vault drill must prove the Vault recovery path first, per Vault → Data → Audit ordering); Wave 3 — `07a` (hard — the Audit.Data T0 backup config must be applied before a meaningful drill).
  - **`Actor=Human` — `human-only` label set.**

**Wave 4 exit criteria:**
- The first Vault drill is executed; a T0 Vault entry exists in `generated/restore-drills/`.
- The first Audit drill is executed; a T0 Audit entry exists in `generated/restore-drills/`.
- Both drills were within ADR-0036's 90-day-from-acceptance first-drill mandate, or the slip is recorded.

## Out-of-scope / deferred items

- **HoneyDrunk.Notify.Cloud T0 DR.** ADR-0036's Affected Nodes names Notify Cloud as T0 (tenant identity & billing data) with tenant-scoped restore (D5) a hard requirement. But `HoneyDrunk.Notify.Cloud` is not yet scaffolded — ADR-0027 (its standup ADR) is itself Proposed and its repo does not exist. Notify Cloud's T0 runbook, tenant identity/billing backup configuration, and the D5 tenant-scoped restore path are deferred to the **Notify Cloud standup initiative**. ADR-0036's own text frames Notify Cloud DR as "a Notify Cloud GA prerequisite" — it belongs to that bring-up, not here. Packet 08 covers `HoneyDrunk.Notify` (T1) only and says so explicitly. Recorded here so the gap is not silently assumed closed. **The Notify Cloud standup initiative must inherit a hard checklist item: a T0 `dr-runbook.md` and the ADR-0036 D5 tenant-scoped restore path are GA-blocking deliverables for Notify Cloud — this deferral is tracked, not waived.**
- **Memory / Knowledge / Flow / Evals runbooks.** ADR-0036 D1 names provisional tiers (Memory T1, Knowledge T1, Flow T2, Evals T2) and packet 01 records them provisionally. But these Nodes are Seed (not scaffolded). Their `dr-runbook.md` and drill cadence are authored at each Node's standup, recorded in the standup ADR amendment per ADR-0036 Consequences. Not packets here.
- **Vault.Rotation / Observe / AI-sector Seed Node DR.** Seed Nodes that hold no state yet have `dr_tier: null` (packet 01) with a "assigned at standup" note. DR scoping happens at each standup. Not here.
- **The DPA template / data-subject-deletion mechanics (ADR-0036 D7).** D7 says GDPR data-subject deletion must be honored across active stores and backups, and that "the Studio's DPA template (not yet authored; deferred to a future ADR) must state retention windows explicitly." Authoring the DPA template and the deletion-across-backups mechanics is explicitly deferred by ADR-0036 itself to a future ADR. Not a packet here. The runbooks (03/06/08) record the retention windows D2 sets, which is the input that future DPA work consumes.
- **Pulse T2 runbook.** ADR-0036 Consequences: "HoneyDrunk.Pulse — T2; existing posture mostly matches." Pulse's T2 posture is low-criticality (RPO ≤ 24 hr, LRS, annual drill) and ADR-0036 explicitly notes its current posture already mostly satisfies it. A Pulse T2 runbook is worth authoring but is **deliberately not in this initiative's critical path** — it can be a follow-up tactical packet (node-audit) once the T0/T1 runbooks and drills, which are the actual forcing functions, are done. Flagged so it is not forgotten: Pulse should get a T2 `dr-runbook.md` as a low-priority follow-up.
- **Cross-region standby capacity provisioning.** ADR-0036 D4 explicitly does not adopt automated cross-region failover or standing standby compute at this stage. No packet provisions a standby region. Reconsidered when the Grid has more than one paying tenant whose contract requires it (D4).

## After filing — board fields and blocking relationships

The `file-packets` pipeline sets Status, Wave, Node, Tier, Actor, Initiative, and ADR fields from frontmatter and wires `addBlockedBy` automatically from each packet's `dependencies:` array. For reference, the blocking graph:

- `01` blocked-by `00` (soft)
- `02` blocked-by `00` (soft)
- `03` blocked-by `01` (soft), `02` (hard)
- `06` blocked-by `01` (soft), `02` (hard)
- `08` blocked-by `01` (soft), `02` (hard)
- `04` blocked-by `03` (hard)
- `07a` blocked-by `06` (hard)
- `09` blocked-by `01` (hard), `02` (hard)
- `05` blocked-by `04` (hard)
- `07b` blocked-by `05` (hard), `07a` (hard)

**Actor:** packets 00, 01, 02, 03, 06, 08, 09 are `Actor=Agent` (ADR flip, catalog field, templates, per-Node runbook docs, agent-definition extension — all delegable). **Packets 04, 05, 07a, 07b are `Actor=Human`** — they carry the `human-only` label because Azure Portal backup configuration, the creation of a physical offline encrypted artifact, and operator-executed restore drills are the *entire* work item, not a side prerequisite.

Verify a wave landed by checking The Hive for the new items + their blocked-by chains, not by inspecting the workflow log.

## Notes

- **Acceptance precedes flip.** ADR-0036 stays Proposed until packet 00's PR merges.
- **The two new invariants land in packet 00**, not in a separate `constitution/invariants.md` packet — (1) every stateful Node has a `dr_tier` (invariant 60); (2) a missed restore drill freezes tier-affecting tenant onboarding (invariant 61). The verified current highest invariant in `constitution/invariants.md` is 51; numbers 60–61 are pre-reserved for ADR-0036 as part of a 12-ADR batch. If any invariant above 51 lands from outside this batch before merge, shift this block upward — never reuse a number.
- **The 90-day first-drill clock starts at acceptance.** ADR-0036 Follow-up Work mandates the first Vault and Audit drills within 90 days of acceptance. Packets 05 and 07b are the drills; they should be filed and executed inside that window. The `hive-sync` extension (packet 09) treats a Node with no drill log past the 90-day grace window as drift — and computes the grace boundary from ADR-0036's accepted-date read out of the ADR header at runtime, not from a hardcoded date.
- **No new repo, no new ADR, no new runtime contract.** This initiative ships an ADR flip + two invariants, one new catalog schema field, one runbook template + a new directory, three per-Node runbook docs, one `hive-sync` extension, and four human Azure-portal/drill packets. `catalogs/contracts.json` is untouched — `dr_tier` is catalog metadata, not a runtime contract.
- **No Azure resources are provisioned by an agent.** All Azure portal work (Key Vault backup flags, Audit.Data Azure SQL backup policy, ephemeral drill environments) is `Actor=Human` (packets 04, 05, 07a, 07b). The portal steps are written as UI walkthroughs per the developer's preference, not CLI.
- **Cost.** ADR-0036 D8 / Operational Consequences: T0 geo-redundant storage is ~2–3× T2 LRS; Vault, Audit, and (future) Notify Cloud T0 stores carry this premium. Restore drills cost ~3–5 operator-days/year at full Grid maturity. The dollar cost is the recorded price of "answering RPO defensibly when a tenant asks." No new compute is stood up — there is no standing standby region (D4).
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).

## Archival

Per ADR-0008 D10, when every **filed and in-scope** packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0036-disaster-recovery/` folder moves to `archive/adr-0036-disaster-recovery/` in a single commit. Partial archival is forbidden.

The `Actor=Human` packets (04, 05, 07a, 07b) are in-scope and NOT exempt from the archival gate — they have a concrete completion path (ADR-0036's 90-day first-drill mandate). The initiative's archival waits for them to be `Done`.

## Revision history

- **2026-05-22 initial scope** — 10 packets across four waves. Drafted ahead of ADR-0036 acceptance; packets are pending-acceptance drafts, not yet filed as GitHub Issues. Notify Cloud T0 DR, the Memory/Knowledge/Flow/Evals runbooks, the DPA template (ADR-0036 D7), and the Pulse T2 runbook are recorded as out-of-scope / deferred follow-ups.
- **2026-05-22 refinement** — pre-filing corrections from a refinement review. Invariants pinned to numbers 60–61 (verified current max 51; pre-reserved in a 12-ADR batch). `dr_tier` clarified as a genuine new catalog schema field. The runbook template path pinned to `generated/dr-runbook.template.md` (no `templates/` directory exists). Old packet 07 split into **07a** (Audit.Data Azure SQL backup config — Wave 3, blocked only on 06) and **07b** (first Audit restore drill — Wave 4, blocked on 05 + 07a). The Audit runbook (06) and 07a rewritten as single-branch Azure SQL — `Audit.Data` is Data-backed over `HoneyDrunk.Data`'s SQL Server provider; the dual-branch "SQL or Cosmos" fork and the operator-flag hedge removed. The `hive-sync` 90-day grace anchor changed to read ADR-0036's accepted-date at runtime. Packet 04 strengthened to confirm the vault's region has an Azure-defined paired region before relying on geo-replication. Initiative now ships **11 packets** across four waves.
