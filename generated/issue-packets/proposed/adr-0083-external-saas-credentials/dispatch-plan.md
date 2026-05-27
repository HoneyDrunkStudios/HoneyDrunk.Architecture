# Dispatch Plan — ADR-0083: Sensitive Inventory and External-SaaS Credential Rotation Procedure

**Initiative:** `adr-0083-external-saas-credentials`
**ADR:** ADR-0083 (Proposed → Accepted via packet 00)
**Sector:** Infrastructure / cross-cutting
**Created:** 2026-05-26

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0083 closes the gap that ADR-0005 and ADR-0006 left uncovered: external-SaaS credentials (`SONAR_TOKEN`, `NUGET_API_KEY`, `GH_ISSUE_TOKEN`, the ADR-0044 webhook signing secret, soon Stripe/Resend/Twilio) live as GitHub organization secrets, not in any `kv-hd-*` vault, and are not rotated by `HoneyDrunk.Vault.Rotation`. The ADR builds a **registry of what the Grid holds** — credentials plus non-rotating identifiers, OIDC bindings, webhook-secret slot names, resource identifiers — at `infrastructure/reference/sensitive-inventory.md`. Rotation discipline (walkthroughs, standing issues, T-30/T-7/T+0 escalation) applies only to the `Rotates: yes` subset; non-rotating entries get an inventory row only.

This initiative delivers: ADR acceptance + one new invariant (Architecture); the seed sensitive-inventory file with 15 live/imminent rows + label seeding (Architecture); three first-wave rotation walkthroughs covering credentials in active production today — SonarCloud, NuGet, GitHub PATs (Architecture); the scheduled `external-credentials-check.yml` drift-detection workflow (Actions); the initial standing rotation issues for `Rotates: yes` entries (Architecture); and the onboarding-hook amendment to `constitution/node-standup.md` plus cross-links from `repos/HoneyDrunk.Vault.Rotation/overview.md` and `infrastructure/reference/vendor-inventory.md` (Architecture).

**8 packets across 3 waves**, targeting **2 repos** (`HoneyDrunk.Architecture` for 7 packets, `HoneyDrunk.Actions` for 1). All 8 are `Actor=Agent`; the Human Prerequisites on packet 06 (open standing issues) are zero — `gh issue create` calls are agent-executable. No new .NET projects.

## Trigger

ADR-0083 is Proposed with no scope. The forcing functions:

- **SONAR_TOKEN's 60-day expiry.** The SonarQube Cloud free plan caps PATs at 60 days with no UI to extend. SONAR_TOKEN gates ADR-0011's third-party static-analysis review surface on every public-repo PR. A missed rotation produces a silent CI degradation — SonarCloud's check just stops posting, which the operator might not notice for days or weeks. The first 60-day window is the floor for landing this initiative; the SonarCloud walkthrough (packet 02) is sequenced first within Wave 2 for that reason.
- **`NUGET_API_KEY` is rotating-by-default with no documented procedure.** This ADR retroactively documents and disciplines its rotation — the second mandatory first-wave walkthrough (packet 03). NuGet.org's 365-day cap is longer than SonarCloud's 60-day cap but still finite, and the blast radius (every NuGet-shipping Node's `release.yml` silently fails to publish, breaking ADR-0034) is the highest after SONAR_TOKEN.
- **Imminent Stripe/Resend/Twilio per PDR-0002 and ADR-0073.** D6's onboarding hook (packet 07) closes the door before those land — a new provider cannot enter a workflow without its inventory row and walkthrough existing first.
- **Lottery-bus-factor risk on non-rotating artifacts.** The broadened scope per D2 (HIVE_APP_ID, AZURE_TENANT_ID, OIDC federated-credential configurations, resource identifiers) acknowledges that *forgotten* credentials are a larger failure mode than *missed* rotations. The same registry artifact addresses both.

## Scope Detection

**Multi-repo, mostly Architecture.** Per ADR-0083 §Affected Nodes:

- **`HoneyDrunk.Architecture`** — primary: new `infrastructure/reference/sensitive-inventory.md`, three new walkthroughs under `infrastructure/walkthroughs/`, new invariant in `constitution/invariants.md`, new standing-issue labels (`external-credential-rotation`, `urgent`, `imminent`), standing rotation issues per `Rotates: yes` row, `constitution/node-standup.md` amendment, cross-links from `repos/HoneyDrunk.Vault.Rotation/overview.md` and `infrastructure/reference/vendor-inventory.md`.
- **`HoneyDrunk.Actions`** — secondary: one new scheduled workflow, `.github/workflows/external-credentials-check.yml`, plus its Markdown-table-schema sub-step.
- **`HoneyDrunk.Vault.Rotation`** — *explicitly unchanged*. The cross-link edit lands in Architecture's `repos/HoneyDrunk.Vault.Rotation/overview.md` (Architecture-owned mirror), not in the Vault.Rotation repo itself.

**No new-Node scaffolding, no contract changes, no catalog schema change.** The sensitive-inventory file is Markdown by design per D2's rejection of the JSON alternative; it does not appear in `catalogs/*`.

## Wave Diagram

### Wave 1 (No Dependencies — governance acceptance)

- [ ] **00** — Architecture: Accept ADR-0083, write **invariant 103** (pre-assigned in `constitution/invariant-reservations.md` alongside ADR-0082's 102 by the refine pass) for the unified inventory-and-rotation discipline invariant, register the initiative. `Actor=Agent`.

> **Invariant numbering.** ADR-0083's invariant is **103**, pre-assigned in `constitution/invariant-reservations.md` alongside ADR-0082's 102 by the refine pass. No "first merge wins" race between the two adjacent initiatives — both slots are fixed. Packet 00 writes the invariant text directly into `constitution/invariants.md` referencing 103.

### Wave 2 (Inventory seed + first-wave walkthroughs — depends on Wave 1)

- [ ] **01** — Architecture: Create `infrastructure/reference/sensitive-inventory.md` with the 15 live/imminent seed rows per ADR-0083 §Follow-up Work and seed the three new GitHub repo labels (`external-credential-rotation`, `urgent`, `imminent`). `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: Author `infrastructure/walkthroughs/sonarcloud-token-rotation.md`. **First in Wave 2 by sequencing within the SONAR_TOKEN 60-day window** (the forcing function). `Actor=Agent`. Blocked by: 01.
- [ ] **03** — Architecture: Author `infrastructure/walkthroughs/nuget-api-key-rotation.md`. Parallel with 02. `Actor=Agent`. Blocked by: 01.
- [ ] **04** — Architecture: Author `infrastructure/walkthroughs/github-pat-rotation.md`. Parallel with 02/03. `Actor=Agent`. Blocked by: 01.

Wave 2 is a fan-out: 01 seeds the inventory + labels, then 02/03/04 each ship one rotation walkthrough independently. SonarCloud (02) is the load-bearing one against the 60-day forcing function; the other two land alongside per ADR-0083 §Follow-up Work calling them "the three mandatory first-wave walkthroughs."

### Wave 3 (Drift-detection + standing issues + onboarding hook — depends on Wave 2)

- [ ] **05** — Actions: Author `.github/workflows/external-credentials-check.yml` — scheduled (cron: daily 09:00 ET) drift-detection workflow per D5 with the `Rotates: yes` filter and the Markdown-table-schema sub-step. `Actor=Agent`. Blocked by: 01.
- [ ] **06** — Architecture: Open the initial standing rotation issues — one per `Rotates: yes` row in the seed inventory — labeled `external-credential-rotation` and titled `[Rotate] {credential-name} — expires {YYYY-MM-DD}` per D3. `Actor=Agent`. Blocked by: 02, 03, 04 (rotation walkthroughs must exist to be linked from issue bodies).
- [ ] **07** — Architecture: D6 onboarding hook + cross-links. Amend `constitution/node-standup.md` to add the sensitive-inventory onboarding step; add cross-link from `repos/HoneyDrunk.Vault.Rotation/overview.md` noting external-SaaS PAT rotation is out of scope per ADR-0083; update `infrastructure/reference/vendor-inventory.md` to cross-link `sensitive-inventory.md` for each vendor whose artifacts the Grid holds. `Actor=Agent`. Blocked by: 01.

Packet 05 (Actions workflow) is parallel with packets 02/03/04 in calendar terms — it only needs the inventory file to exist (packet 01) so its parser has something to read; it does not need the walkthroughs to exist. It is listed in Wave 3 by topic grouping (drift-detection / onboarding) rather than by strict dependency. The agent may dispatch it as soon as packet 01 lands; the wave label is for narrative grouping.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0083](./00-architecture-adr-0083-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [sensitive-inventory.md seed + label seeding](./01-architecture-sensitive-inventory-seed.md) | Architecture | Agent | 2 | 00 |
| 02 | [sonarcloud-token-rotation walkthrough](./02-architecture-sonarcloud-token-rotation-walkthrough.md) | Architecture | Agent | 2 | 01 |
| 03 | [nuget-api-key-rotation walkthrough](./03-architecture-nuget-api-key-rotation-walkthrough.md) | Architecture | Agent | 2 | 01 |
| 04 | [github-pat-rotation walkthrough](./04-architecture-github-pat-rotation-walkthrough.md) | Architecture | Agent | 2 | 01 |
| 05 | [external-credentials-check.yml workflow](./05-actions-external-credentials-check-workflow.md) | Actions | Agent | 3 | 01 |
| 06 | [Open initial standing rotation issues](./06-architecture-open-standing-rotation-issues.md) | Architecture | Agent | 3 | 02, 03, 04 |
| 07 | [D6 onboarding hook + Vault.Rotation/vendor-inventory cross-links](./07-architecture-onboarding-hook-and-cross-links.md) | Architecture | Agent | 3 | 01 |

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/docs edits only. The repo-level `CHANGELOG.md` receives a dated entry per the repo's existing convention for ADR-acceptance events; match what ADR-0042/0045/0077/0080 acceptance packets did.
- **`HoneyDrunk.Actions`** — versioned reusable-workflow repo. The new scheduled workflow `external-credentials-check.yml` is repo-local (not a reusable workflow consumed by other repos), so no version bump is required by D5 alone. Append the workflow addition to the repo-level `CHANGELOG.md`'s in-progress entry without bumping the version.

## Cross-Cutting Concerns

### Why SonarCloud-first within Wave 2

The SONAR_TOKEN 60-day cap is the ADR's stated forcing function. The token has been live since the ADR-0011 acceptance work landed the SonarCloud organization setup; the first rotation window is the binding deadline. Packets 03 (NuGet) and 04 (GitHub PAT) are equally important per the ADR but face longer expiration cadences (365 days for NuGet, up to 366 days for fine-grained PATs), so SonarCloud goes first by deadline pressure even though all three are parallel-dispatchable within Wave 2.

### Why one inventory file, not per-Node

Per ADR-0083 D2 §Rejected alternative: inventory items don't cleanly partition by Node. SONAR_TOKEN is consumed by every public repo; HIVE_APP_ID is consumed by `hive-field-mirror.yml` and `refresh-hive-project-metadata.yml`; AZURE_TENANT_ID is consumed everywhere. A single Grid-wide table is the right granularity.

### Why Markdown, not `catalogs/sensitive-inventory.json`

Per ADR-0083 D2 §Rejected alternative: the inventory is consumed by humans during rotation, onboarding, and incident response — not by automated agents making routing decisions. Markdown is the right surface. The `external-credentials-check.yml` workflow per D5 parses the Markdown well enough for its needs (filter by `Rotates: yes`, read `Current Expiration`, compute against `TimeProvider.GetUtcNow()`), and the schema-check sub-step fails fast on table-format drift.

### Why no walkthroughs for non-rotating entries

Per ADR-0083 D4: walkthroughs are authored **only for rotation-needing entries** (`Rotates: yes`). Non-rotating entries (`Rotates: no`, `Rotates: automated-elsewhere`) intentionally have no walkthrough — there is no rotation flow to document. The inventory row itself is the deliverable for those.

### Why Vault.Rotation is out of scope

Per ADR-0083 D1: Vault.Rotation does **not** expand to cover external-SaaS PATs. The cost discipline is explicit — fewer than ten total external-SaaS credentials, per-provider rotation API engineering scales with provider count, and Vault.Rotation's existing scope (per ADR-0006) is third-party secrets the Grid issues to itself via the provider's API, written into Azure Key Vault. External-SaaS PATs target GitHub org secrets, not Key Vault, and bind to operator user accounts, not Managed Identities. Conflating the two would force Vault.Rotation to grow a second storage backend and a second identity model. The cross-link edit in packet 07 to `repos/HoneyDrunk.Vault.Rotation/overview.md` is documentation-only — it states the scope boundary, it does not change Vault.Rotation's surface.

### Why the new invariant is one clause, not two

Per ADR-0083 D7: the invariant is a single clause with two bound parts — a broader inventory-membership rule that covers everything the Grid holds, and a narrower rotation-discipline rule that applies only to the rotation-needing subset. Both parts land together in a single numbered invariant; packet 00 claims a block of size 1 (not 2) in the reservation registry.

### Coupling with ADR-0084 (Discord operator alerts)

Per ADR-0083 D3, the in-flight ADR-0084 will amend D3 to add Discord webhook alerts as the **escalation** surface on top of the GitHub-issue tracking surface this ADR establishes. **This initiative deliberately does not preempt that change.** GitHub issues remain the canonical tracking surface in this ADR's packets; the Discord escalation channel composes on top via ADR-0084's `job-discord-notify.yml` seam once ADR-0084 lands. The seven `DISCORD_WEBHOOK_*` rows + Discord guild ID are seeded by ADR-0084's first follow-up packet, not by this initiative's packet 01.

## Cross-Initiative Ordering Constraint

**This is an enforcement constraint, not a suggestion.**

1. **ADR-0084 must be promoted from `proposed/` to `active/` FIRST.** Once filed, each ADR-0084 packet has a real GitHub issue number that ADR-0083 packets can reference.
2. **The operator then updates this initiative's packet 05 and packet 06 in `proposed/`** with concrete `{Repo}#N` dependencies before promoting ADR-0083:
   - Packet 05 (the `external-credentials-check.yml` workflow) adds an `external_dependencies` reference noting that ADR-0084 packet 10 (Phase-1 emitter wiring) will edit the workflow to add Discord branches. The workflow scaffold ships in this packet; the Discord notify-call sites land in ADR-0084 packet 10.
   - Packet 06 (initial standing rotation issues) does not have a hard ADR-0084 dependency but should note the coupling — once ADR-0084 lands, the standing issues will be escalated to Discord, not only via gh-issue-comment.
3. **ADR-0083 is then promoted to `active/`.** Its packets file with the real cross-initiative dependency edges wired.

Reverse ordering (ADR-0083 first) would file ADR-0083 packet 05 against an ADR-0084 placeholder no automation can resolve, creating tombstoned blocked-by edges. Operators must not skip step 2.

### Coupling with PDR-0002 (Notify Cloud commercial trial)

Per ADR-0083 D6: Stripe / Resend / Twilio key onboarding is gated on this ADR's inventory and walkthrough machinery existing first. When PDR-0002 ships, `stripe-api-key-rotation.md`, `resend-api-key-rotation.md`, and `twilio-api-key-rotation.md` join the walkthrough set — those packets live in the PDR-0002 acceptance initiative, not here. The split per D1 §Note on overlap with ADR-0006 Tier 2: this ADR covers the inventory row + initial-provisioning walkthrough + operator-side tracking; ADR-0006 covers the post-issuance rotation into `kv-hd-notify-{env}`.

## Rollback Plan

- **Packet 00 (acceptance)** rolls back by reverting the PR — the ADR stays Proposed, the invariant reservation is released, no downstream packets land.
- **Packets 01–04** are governance/docs-only; rolling back is deleting the file(s) and reverting the label seeding.
- **Packet 05 (Actions workflow)** rolls back by deleting the workflow file. Scheduled runs stop on the next cron tick. No state is persisted by the workflow.
- **Packet 06 (standing issues)** rolls back by closing each opened issue with a `wontfix` label. The closed issues remain as audit history per D3.
- **Packet 07 (cross-links and standup amendment)** rolls back by reverting the three file edits. No code or runtime surface is affected.

Per ADR-0008 D7, the dispatch plan is updated at wave boundaries with merge dates and any decisions taken during execution.
