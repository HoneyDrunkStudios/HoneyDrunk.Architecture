---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0054", "wave-4"]
dependencies: ["work-item:00"]
adrs: ["ADR-0054", "ADR-0036"]
accepts: ["ADR-0054"]
wave: 4
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Author the per-Node runbook minimum-set playbook and the rollout scaffold

## Summary
Author the **per-Node runbook minimum-set rollout playbook** at `infrastructure/walkthroughs/per-node-runbook-rollout.md` per ADR-0054 D10: scaffold the canonical `restart.md` / `rollback.md` / `health-check.md` / `common-sev2-patterns.md` (and `escalation.md` for Tier 0 Nodes) templates as boilerplate, plus the fanout strategy for each deployable Node. The playbook explains how each Node owner (the operator, with agent assistance) fills in the Node-specific content from the boilerplate. Per-Node packets that actually create the runbooks in each Node's `runbooks/` directory are a fanout downstream of this packet — they are not bundled here.

## Context
ADR-0054 D10 commits the per-Node runbook convention: every deployable Node has a `runbooks/` directory with the minimum file set (`restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`); Tier 0 Nodes per ADR-0036 also have `escalation.md`. The convention was registered in packet 01; the directories and content do not yet exist.

**Why a playbook, not a fanout of per-Node packets now.** Packet 10 is the **template + strategy** packet; the per-Node creation is downstream. Reasons:

- The runbook content is Node-specific — `restart.md` for `HoneyDrunk.Notify` (Container App revision restart) is different from `restart.md` for `HoneyDrunk.Vault.Rotation` (Function App restart). Each Node's runbook needs domain knowledge that an Architecture-repo-only packet cannot supply.
- The fanout is mechanical once the boilerplate is in place. Per-Node packets are filed from the playbook; they execute in their target repos.
- The playbook decouples the **convention** (this packet) from the **content** (per-Node packets), letting the convention land cleanly without waiting for every Node's content.

**This packet authors:**

1. The five boilerplate templates (`restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`, `escalation.md`) as scaffolds with TODO placeholders and per-Node guidance.
2. The playbook doc explaining: which Nodes need which files, the per-Node-packet template (so the next round of fanout packets is mechanical), and the order of rollout (Tier 0 first per ADR-0036).
3. The per-Node-packet template for the fanout: a `_templates/per-node-runbook-packet.md` packet template that the scope agent uses to generate one packet per Node in a follow-on initiative.

**What this packet does NOT do:**

- Does NOT create runbook files in the actual Node repos. That is the per-Node fanout, downstream.
- Does NOT fill in Node-specific content. That is per-Node packet work.

**Tier classification per ADR-0036.** The runbook minimum set differs by tier:

- **Tier 0** (Vault, Audit, Notify Cloud tenant data — the "blast-radius" Nodes): `restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`, **`escalation.md`** (e.g., "Vault unavailability with no recovery in 30 min → page Azure support").
- **Tier 1** (Notify, Memory, Knowledge — important but lower blast radius): the four files without `escalation.md`.
- **Tier 2** (Pulse, Flow, Evals — important but recoverable in hours): the four files without `escalation.md`.
- **Library-only** (Kernel, Vault [the abstraction package], Transport, Architecture, Standards): **exempt** — no `runbooks/` directory, marked `not_applicable: true` per packet 01.

The deployable Node list at edit time: confirm against `catalogs/nodes.json` and ADR-0036 tier mapping. Deployable Nodes today (2026-05) include: Vault.Rotation, Notify, Communications, Pulse, (future: Audit, Operator, Notify Cloud). The Tier-0/1/2 mapping comes from ADR-0036.

This is a docs/templates packet. No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/per-node-runbook-rollout.md` (new) — the rollout playbook explaining tiers, file set, content expectations, and the per-Node fanout strategy.
- `_templates/runbooks/restart.md`, `_templates/runbooks/rollback.md`, `_templates/runbooks/health-check.md`, `_templates/runbooks/common-sev2-patterns.md`, `_templates/runbooks/escalation.md` (new — boilerplate scaffolds with TODO placeholders).
- `_templates/per-node-runbook-packet.md` (new) — the packet template the scope agent uses to fanout per-Node runbook packets in a follow-on initiative.
- The Per-Node runbook fanout (downstream, not in this packet) — a separate initiative or set of packets executes per Node.

## Proposed Implementation
1. **Boilerplate scaffold for `restart.md`.** The file template covers: pre-flight checks (is the Node currently serving?), the exact restart command per common deploy surface (Container App revision restart, Function App restart, App Service restart), verification (which endpoint to probe, expected response), rollback hint if restart doesn't recover. Each section carries TODO placeholders for the Node-specific values (resource name, port, endpoint).
2. **Boilerplate scaffold for `rollback.md`.** Covers: identifying the previous tagged release per ADR-0033 tag → environment mapping, the rollback command per deploy surface, verification, post-rollback follow-up. TODO placeholders for the Node-specific tag scheme and revision identifiers.
3. **Boilerplate scaffold for `health-check.md`.** Covers: which endpoints to probe (the standard `/health` / `/ready` per the Kernel convention), which Pulse dashboard to consult, expected metric ranges, common false-positive patterns. TODO placeholders for the Node's specific endpoints and dashboards.
4. **Boilerplate scaffold for `common-sev2-patterns.md`.** Covers: a handful (3-7) of known SEV-2-class failure modes with diagnostic steps and mitigation. Examples from the ADR: "Latency spike on tenant-facing endpoint — check downstream dependency", "Queue backup — check worker process count", etc. TODO placeholders for each Node to fill in its specific patterns.
5. **Boilerplate scaffold for `escalation.md` (Tier 0 only).** Covers: what to escalate, where, when. Examples: "Vault unavailability with no recovery in 30 min → page Azure support via portal" (D10 example); "Audit write-path failure → engage security review channel". TODO placeholders for the Node-specific escalation paths.
6. **The rollout playbook.**
   - Lists every deployable Node from `catalogs/nodes.json` with its tier (per ADR-0036) and required file set.
   - Documents the rollout order: **Tier 0 Nodes first** (Vault is critical — even though "Vault" in the catalog is currently the library, the deployable Vault.Rotation and the Vault-using Nodes need their runbooks; clarify per ADR-0005 and ADR-0006 which deployables need Vault-related runbooks).
   - Lists the per-Node-packet template (`_templates/per-node-runbook-packet.md`) to be used in a follow-on fanout initiative.
   - Cross-references the freshness rule from D10: "A runbook older than 90 days that has not been touched is flagged in the nightly `hive-sync` report." (The `hive-sync` enforcement is a follow-on; the convention is recorded here.)
   - Cross-references the post-mortem update rule: "After every SEV-1/2 post-mortem, the affected Node's runbooks are reviewed and updated if relevant."
7. **Per-Node-packet template.** A `_templates/per-node-runbook-packet.md` packet template the scope agent uses to fanout. The template has frontmatter (`target_repo`, `initiative: adr-0054-per-node-runbooks`, `wave`, `node`), a Summary section ("Create the minimum runbook set for {Node}"), a Scope section listing the four / five files, and Acceptance Criteria checking each file exists with Node-specific content. The fanout initiative is **a separate initiative folder** (`adr-0054-per-node-runbooks/`) that the scope agent generates next; not this packet's commit.
8. **`escalation.md` only for Tier-0.** The scaffold is included for all Tier classifications but Tier-1 and Tier-2 Nodes mark it `not_applicable: true` and do not create the file in their `runbooks/` directory.

## Affected Files
- `infrastructure/walkthroughs/per-node-runbook-rollout.md` (new)
- `_templates/runbooks/restart.md` (new — boilerplate)
- `_templates/runbooks/rollback.md` (new — boilerplate)
- `_templates/runbooks/health-check.md` (new — boilerplate)
- `_templates/runbooks/common-sev2-patterns.md` (new — boilerplate)
- `_templates/runbooks/escalation.md` (new — boilerplate, Tier-0 only)
- `_templates/per-node-runbook-packet.md` (new — packet scaffold for the fanout)

## NuGet Dependencies
None. This packet creates only markdown template / playbook files; no .NET project.

## Boundary Check
- [x] All files in `HoneyDrunk.Architecture` — correct home for cross-Node playbooks and templates.
- [x] No code change in any other repo.
- [x] The per-Node runbook creation is a downstream fanout, scoped from this playbook — not in this packet's commit.
- [x] Library-only Nodes (Kernel, Vault library, Transport, Architecture, Standards) are exempt per packet 01's `not_applicable: true` marking.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/per-node-runbook-rollout.md` exists, lists every deployable Node from `catalogs/nodes.json` with its ADR-0036 tier and required file set, documents the rollout order (Tier 0 first), and cross-references the D10 freshness rule and the post-mortem update rule
- [ ] Five boilerplate runbook scaffolds exist at `_templates/runbooks/restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`, `escalation.md` — each with TODO placeholders for Node-specific values
- [ ] `_templates/per-node-runbook-packet.md` exists as a packet template the scope agent can copy for the fanout — frontmatter (`target_repo`, `initiative: adr-0054-per-node-runbooks`, `wave`, `node`), Summary, Scope, Acceptance Criteria sections — ready for placeholder substitution per Node
- [ ] The playbook documents that the per-Node fanout is a **separate follow-on initiative** (`adr-0054-per-node-runbooks/`), not part of this packet
- [ ] Library-only Nodes (Kernel, Vault [library], Transport, Architecture, Standards) are marked exempt; deployable Nodes (Vault.Rotation, Notify, Communications, Pulse, future Audit / Operator / Notify Cloud) carry the requirement
- [ ] `escalation.md` is required only for Tier-0 Nodes per ADR-0036; Tier-1 / Tier-2 Nodes do not create that file
- [ ] No runbook content is created in any Node repo by this packet — that is the per-Node fanout

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0054 D10 — Per-Node runbooks at `repos/{node}/runbooks/`.** Minimum file set: `restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md` for every deployable Node; `escalation.md` additionally for Tier 0 Nodes per ADR-0036. Operator agent (ADR-0018) consults the runbooks during incident mitigation — runbook content quality directly affects operator-agent suggestion quality.

**ADR-0054 D10 — Runbook freshness.** A runbook older than 90 days that has not been touched is flagged in the nightly `hive-sync` report. After every SEV-1/2 post-mortem, the affected Node's runbooks are reviewed and updated. Game days (D11) exercise the runbooks; an exercise that finds a runbook gap requires a same-day patch.

**ADR-0036 — Tier classification.** Tier-0 Nodes (Vault, Audit, Notify Cloud tenant data) require the additional `escalation.md`. Tier-1 / Tier-2 Nodes do not. Library-only Nodes are exempt.

**ADR-0033 — Tag → environment mapping.** `rollback.md` boilerplate references the tag → environment mapping for identifying the previous tagged release.

**ADR-0054 Affected Nodes — All deployable Nodes.** "Minimum runbook set required for deployable Nodes; `health-check.md` required for all Nodes." (The "all Nodes" reading is loose — library-only Nodes are exempt per packet 01's `not_applicable: true`; the cleaner reading is "all deployable Nodes, plus `health-check.md` is the minimum-of-minimums for any Node with operational presence." This packet preserves the cleaner reading.)

## Constraints
- **Playbook + templates, not per-Node content.** This packet authors the scaffold and the strategy; the per-Node fanout is a separate downstream initiative.
- **Tier-0 gets `escalation.md`; Tier-1/2 does not.** Follow ADR-0036's tier mapping at edit time.
- **Library-only Nodes exempt.** Kernel, Vault library, Transport, Architecture, Standards do not have `runbooks/` directories.
- **The `hive-sync` freshness check is a follow-on**, not part of this packet. Record as a deferred item.
- **The per-Node-packet template is ready for fanout** but the fanout itself is a separate initiative (`adr-0054-per-node-runbooks/`).

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0054`, `wave-4`

## Agent Handoff

**Objective:** Author the per-Node runbook minimum-set rollout playbook, the five boilerplate scaffold templates, and the per-Node-packet template for a follow-on fanout initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make D10's runbook convention concrete via boilerplate that every Node owner (with agent assistance) fills in. The per-Node creation is downstream; this packet's job is the substrate.
- Feature: ADR-0054 Incident Response rollout, Wave 4.
- ADRs: ADR-0054 D10 (primary), ADR-0036 (tier classification), ADR-0033 (tag → environment mapping), ADR-0054 D11 (game days exercise runbooks — referenced).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0054 should be Accepted before its runbook convention's content lands.

**Constraints:**
- Playbook + templates only; no per-Node content in this packet.
- Tier-0 gets `escalation.md`; Tier-1/2 does not.
- Library-only Nodes exempt.
- The `hive-sync` freshness check is a deferred follow-on.

**Key Files:**
- `infrastructure/walkthroughs/per-node-runbook-rollout.md` (new)
- `_templates/runbooks/` (new — five boilerplate files)
- `_templates/per-node-runbook-packet.md` (new — fanout packet scaffold)

**Contracts:** None changed. The boilerplate templates are the scaffold consumed by the future fanout initiative.
