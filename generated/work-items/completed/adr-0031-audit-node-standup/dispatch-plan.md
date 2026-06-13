# Dispatch Plan — ADR-0031 Stand Up the HoneyDrunk.Audit Node

> ## ⚠ PRE-FILING REWRITE REQUIRED — Do Not Push This Initiative Until Both Steps Are Complete
>
> The packets in this initiative reference upstream ADR-0030 issues that **do not exist yet** as GitHub issues. The dependency frontmatter currently contains literal placeholder strings — `Architecture#108` and `Architecture#109` — which `file-work-items.sh` cannot resolve. If you push as-is, the `addBlockedBy` wiring will silently skip those edges and the wave gate will not exist on The Hive.
>
> **Required sequence before pushing this initiative's packets:**
>
> 1. **File AND merge** the ADR-0030 acceptance initiative (`generated/work-items/active/adr-0030-audit-substrate/`). Both packets — `01-architecture-adr-0030-acceptance.md` and `02-architecture-audit-emission-invariant.md` — must reach `main`. That run produces two real GitHub issue numbers on `HoneyDrunkStudios/HoneyDrunk.Architecture`.
> 2. **Look up the assigned issue numbers** via The Hive or `gh issue list -R HoneyDrunkStudios/HoneyDrunk.Architecture` after that initiative files.
> 3. **Substitute the real issue numbers** in three places in this initiative's packet sources, in place, pre-push (invariant 24's pre-filing carve-out applies — none of these packets have been filed yet at that point):
>    - `01-architecture-audit-coupling-and-canary-invariants.md` frontmatter `dependencies:` — replace `"Architecture#109"` with `"Architecture#<real-number>"` for ADR-0030 packet 02.
>    - `02-architecture-create-audit-repo.md` frontmatter `dependencies:` — replace `"Architecture#108"` with `"Architecture#<real-number>"` for ADR-0030 packet 01.
>    - Every prose mention of `Architecture#108` / `Architecture#109` in packet bodies and in this dispatch plan (search-and-replace the two distinct placeholder strings across the initiative folder).
> 4. **Then push** this initiative's packets per the filing-order rule below (packets 01 + 02 together, wait for merge, then packet 03, then packet 04).
>
> The placeholder strings are forbidden in `dependencies:` per the scope agent's own rules — `file-work-items.sh` accepts only integer-valued `{Repo}#N` references and silently skips unrecognized forms. A pushed-as-is state would file these packets onto The Hive with no upstream blocker — exactly the failure mode `addBlockedBy` exists to prevent.

**Initiative:** `adr-0031-audit-node-standup`
**Sector:** Core
**Governing ADR:** [ADR-0031 — Stand Up the HoneyDrunk.Audit Node](../../../../adrs/ADR-0031-stand-up-honeydrunk-audit-node.md) (Proposed 2026-05-16; flips to Accepted after this initiative's PRs merge per the user's ADR acceptance workflow — scope agent flips Status, never on first draft)
**Driving Decision ADR:** [ADR-0030 — Grid-Wide Audit Substrate](../../../../adrs/ADR-0030-grid-wide-audit-substrate.md) (must be Accepted before ADR-0031 can flip; gated by the [ADR-0030 acceptance initiative](../adr-0030-audit-substrate/dispatch-plan.md))
**Trigger:** ADR-0030 records that Grid-wide durable, attributable audit is a first-class concern homed in a new dedicated `HoneyDrunk.Audit` Node. ADR-0031 is the stand-up ADR — what the Node owns, the package shape, the three frozen contracts, the contract-shape canary, the downstream coupling rule, and what the first PR scaffolds. Two of ADR-0030's eventual consumers — HoneyDrunk.Auth (durable security-event emitter) and a future tenant-facing forensics surface (built over `IAuditQuery`) — are blocked on `HoneyDrunk.Audit.Abstractions` existing. This initiative builds the substrate that unblocks them.
**Type:** Multi-repo (3 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Audit` (new) + `HoneyDrunk.Auth`)
**Site sync required:** No (scaffold-only; no public-API surface change needs site update yet — when `HoneyDrunk.Audit 0.1.0` ships and Auth wires the first emitter, a site-sync follow-up may be warranted)
**Rollback plan:**
- **Pre-tag rollback** (before `v0.1.0` is pushed in Audit): `git revert` of each PR. Packets 01/02 are independent reverts; packet 03 reverts the entire scaffold as a single PR; packet 04 reverts the Auth emitter change.
- **Post-tag rollback** (after `v0.1.0` is pushed in Audit but before Auth consumes it): NuGet packages are immutable. Either `dotnet nuget delete` if the packages were just pushed and pre-discovery, or fix-forward as `0.1.1`. Practical hard rollback after a tag is messy — prefer fix-forward.
- **After Auth consumes (packet 04 merged):** rollback of Audit Abstractions is no longer a clean option — Auth has a compile-time reference. Treat any defect as forward-only.
- **`file-work-items.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Sequencing Against ADR-0030 Acceptance — HARD BLOCKER

This initiative is **gated** on ADR-0030's acceptance initiative completing. The acceptance initiative writes two packets (filed in `generated/work-items/active/adr-0030-audit-substrate/`):

- [`01-architecture-adr-0030-acceptance.md`](../adr-0030-audit-substrate/01-architecture-adr-0030-acceptance.md) — registers `honeydrunk-audit` Node in catalogs, adds Core-sector row, flips ADR-0030 Status to Accepted, verifies the ADR-0018 amendment, creates the `repos/HoneyDrunk.Audit/` context folder (already on disk), registers the bring-up initiative + roadmap bullet.
- [`02-architecture-audit-emission-invariant.md`](../adr-0030-audit-substrate/02-architecture-audit-emission-invariant.md) — lands the substrate-level audit-emission boundary invariant `{N-substrate}` (originally drafted as 44; the collision-check protocol in that packet shifts to the next free slot at edit time — likely 47 or higher, since 44/45/46 are claimed by ADR-0016 AI standup), with two slots reserved for this initiative.

Both ADR-0030 packets must merge to `main` before this initiative's packets can usefully execute, because:

- Without ADR-0030 packet 01: `catalogs/nodes.json` has no `honeydrunk-audit` row, ADR-0030 still reads Proposed, and the ADR-0031 acceptance flip later in this initiative would chain through an un-Accepted driving ADR — invalid per ADR-0031's own "Done When" gate.
- Without ADR-0030 packet 02: the substrate-level audit-emission boundary invariant `{N-substrate}` does not exist in `constitution/invariants.md`, the `## Audit Invariants` section does not exist, and this initiative's packet 01 (which adds the two new invariants `{N-coupling}` + `{N-canary}` to that section) has no section to append to and no substrate-level invariant to slot next to.

**Filing rule:** the user authorizes filing this initiative's packets **only after** Architecture#108 (ADR-0030 packet 01) and Architecture#109 (ADR-0030 packet 02) are merged. The dependency frontmatter on packets 01 and 02 of this initiative will resolve to those issue numbers at filing time using the qualified `Architecture#NN` form — the numbers below are placeholders updated pre-push.

## Summary

ADR-0031 is the stand-up ADR for `HoneyDrunk.Audit`. It decides what the Node owns (D1), the package families (D2: `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data`), the three exposed contracts (D3: `IAuditLog`, `IAuditQuery`, `AuditEntry`), Data-backed append-only storage (D4), the Node's own managed identity (D5), Auth as the first emitter with Operator reconciled (D6), one-way telemetry to Pulse (D7), the contract-shape canary (D8), the downstream coupling rule (D9), and what scaffolds in the first PR (D11). None of that has been built — the `HoneyDrunkStudios/HoneyDrunk.Audit` repo does not exist yet.

Four packets land the work:

1. **Constitution invariants** — two new invariants from D9 and D8 added to `constitution/invariants.md` at numbers **45** and **46** (the slots reserved by ADR-0030 packet 02). 45 = downstream Abstractions-only coupling. 46 = Audit contract-shape canary requirement.
2. **Create HoneyDrunk.Audit GitHub repo (human-only)** — create the public repo on `HoneyDrunkStudios`, apply branch protection, seed labels, configure OIDC federated credential, clone locally. Same shape as the Capabilities create-repo packet — except this one is brand-new creation, not verify-and-clone.
3. **HoneyDrunk.Audit scaffold** — empty repo to first-shippable state. Solution, two packages (`Abstractions` + `Data`), three contracts, Data-backed append-only `IAuditLog` writer + `IAuditQuery` reader over `IRepository`/`IUnitOfWork`, audit-class retention hook (App Config-sourced), in-memory `IAuditLog`/`IAuditQuery` fixture living `internal` to the runtime package's test project (D2 — deliberately not a `Testing` package per ADR-0027 precedent), end-to-end smoke test (write through `IAuditLog`, read back through `IAuditQuery` against the in-memory fixture), full CI including the D8 contract-shape canary scoped to `HoneyDrunk.Audit.Abstractions`, `README`/`CHANGELOG`/`LICENSE` per package.
4. **Auth as first emitter** — wire `HoneyDrunk.Auth` to emit durable `AuditEntry` records for login attempts and authorization grants/denials via `IAuditLog`, additively to its existing OTel traces, on the separate durable channel per ADR-0030 D6 and the substrate-level audit-emission boundary invariant `{N-substrate}` (landed by ADR-0030 packet 02). Auth's identity-out-of-traces invariant is untouched — audit records are out-of-band of traces. **Per ADR-0026, Auth passes the Kernel `TenantId` strong type from `IGridContext.TenantId` directly to `AuditEntry.TenantId` — no stringification at the emission site.**

## Wave Diagram

```
Wave 1: Architecture audit invariants (next two free slots — `{N-coupling}` and `{N-canary}`) + create HoneyDrunk.Audit repo (parallel)
   ├─ Architecture: 01-architecture-audit-coupling-and-canary-invariants
   │     Blocked by: Architecture#109 (ADR-0030 packet 02 must merge so the
   │                 `## Audit Invariants` section and the substrate-level audit-emission
   │                 boundary invariant `{N-substrate}` exist).
   └─ Architecture: 02-architecture-create-audit-repo  (human-only)
         Blocked by: Architecture#108 (catalog must register `honeydrunk-audit`
                     and create `repos/HoneyDrunk.Audit/` first — already in place).

Wave 2: HoneyDrunk.Audit scaffold
   └─ HoneyDrunk.Audit: 03-audit-node-scaffold
         Blocked by: packet 01 (invariant number placeholders `{N-coupling}` and `{N-canary}` are referenced in the scaffold's
                                 acceptance criteria and CHANGELOG)
                     packet 02 (the GitHub repo must exist and the local working tree
                                must be cloned before scaffolding can run)

Wave 3: Auth wired as first emitter
   └─ HoneyDrunk.Auth: 04-auth-wire-first-emitter
         Blocked by: packet 03 (Auth needs `HoneyDrunk.Audit.Abstractions 0.1.0`
                                 published to NuGet — Auth references it as a
                                 PackageReference, not a ProjectReference)
```

In practice packets 01 and 02 can be filed in the same push — both target Architecture and touch different files (`constitution/invariants.md` vs. GitHub portal/CLI). The `dependencies:` frontmatter wires the blocking edges to the upstream ADR-0030 packets automatically.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Add two new Audit invariants (downstream Abstractions-only coupling + contract-shape canary, assigned `{N-coupling}` and `{N-canary}`) to the constitution](./01-architecture-audit-coupling-and-canary-invariants.md) | Architecture | 1 | Agent | Architecture#109 |
| 02 | [Create `HoneyDrunkStudios/HoneyDrunk.Audit` public repo, branch protection, labels, OIDC, clone locally (human-only)](./02-architecture-create-audit-repo.md) | Architecture (tracking issue) | 1 | Human | Architecture#108 |
| 03 | [Stand up `HoneyDrunk.Audit` — solution, two packages, three contracts, Data-backed append-only store, CI with canary, in-memory fixture, smoke test](./03-audit-node-scaffold.md) | HoneyDrunk.Audit | 2 | Agent | 01, 02 |
| 04 | [Wire `HoneyDrunk.Auth` as the first `IAuditLog` emitter — durable login attempts, authz grants/denials, identity-out-of-traces invariant untouched](./04-auth-wire-first-emitter.md) | HoneyDrunk.Auth | 3 | Agent | 03 |

## Phase Mapping (ADR-0031 "If Accepted" checklist → packets)

ADR-0031's "If Accepted — Required Follow-Up Work" checklist, mapped to packets:

| Checklist item | Packet |
|---|---|
| Create the `HoneyDrunk.Audit` GitHub repo as **public** | packet 02 |
| Add `honeydrunk-audit` Node entry to `catalogs/nodes.json` | ADR-0030 packet 01 (already on disk; the row was authored in that scoping pass) |
| Add `honeydrunk-audit` entries and the new edges to `catalogs/relationships.json` | ADR-0030 packet 01 |
| Add `IAuditLog`, `IAuditQuery`, `AuditEntry` to `catalogs/contracts.json` under `honeydrunk-audit`; mark Operator's existing entries relocated | ADR-0030 packet 01 |
| Add the `honeydrunk-audit` row to `catalogs/grid-health.json` | ADR-0030 packet 01 |
| Add `honeydrunk-audit` entries to `catalogs/modules.json` for `HoneyDrunk.Audit.Abstractions` and `HoneyDrunk.Audit.Data` | ADR-0030 packet 01 (already on disk in `catalogs/modules.json` — verified pre-scoping) |
| Update `constitution/sectors.md` Core-sector table to add the **Audit** row | ADR-0030 packet 01 |
| Append the additive amendment note to `adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` | ADR-0030 packet 01 (the 2026-05-16 amendment is already on disk; ADR-0030 packet 01 verifies, does not re-author) |
| Wire the contract-shape canary into Actions for the three frozen contracts | packet 03 (CI file inside HoneyDrunk.Audit, not in HoneyDrunk.Actions — the reusable workflow already exists per `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml`) |
| Create `repos/HoneyDrunk.Audit/` context folder in the Architecture repo | already on disk — verified pre-scoping (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) |
| File the HoneyDrunk.Audit scaffold packet | packet 03 |
| Reference ADR-0030 (Grid-Wide Audit Substrate) as the driving decision | this dispatch plan + every packet's `adrs:` frontmatter |
| Scope agent assigns final invariant numbers when flipping Status → Accepted | packet 01 (assigns 45 and 46); ADR-0030 packet 02 already assigned 44 |

ADR-0030 packets 01 and 02 carry the catalog, sectors, ADR-0018-amendment, and substrate-invariant work. This initiative is responsible for the **packaging/CI/scaffold half** of ADR-0031's "If Accepted" checklist — the constitutional invariants for the standup's two rules (D8 + D9), the public repo, the scaffold itself, and the first emitter (Auth). The Operator reconciliation half of D5 is **not** in this initiative — see "What This Initiative Does NOT Deliver" below.

## What This Initiative Does NOT Deliver

The following are explicitly out of scope for this initiative. Each becomes a separate packet at the appropriate time:

- **HoneyDrunk.Operator reconciliation as `IAuditLog`/`IAuditQuery` consumer.** Per ADR-0030 D5 and ADR-0031 D6, Operator is reclassified from owner to consumer/emitter of the relocated contracts. The catalog-side reconciliation (marking `IAuditLog`/`AuditEntry` relocated in `contracts.json`, adding the `honeydrunk-operator → honeydrunk-audit` edge, appending the additive amendment note to ADR-0018) lands in ADR-0030 packet 01 — already scoped. The **code-side** reconciliation does not exist yet because **HoneyDrunk.Operator is not yet scaffolded** (the repo carries only `LICENSE`, `README.md`, `contracts/`, `docs/`, `policies/`, `prompts/`, `staging/` — no `.slnx`, no `.csproj`, no source). When Operator's own stand-up initiative scaffolds it, that scaffolding packet must add the `HoneyDrunk.Audit.Abstractions` PackageReference and emit `AuditEntry` for its AI-runtime decisions via `IAuditLog`. Surfacing it here for traceability; not authoring a packet that has nothing to edit.

- **`repos/HoneyDrunk.Operator/boundaries.md` "Audit trail" + "Decision authority" cleanup.** The Operator boundaries doc currently lists "Audit trail — immutable log of every AI decision, tool invocation, and human override" under "What Operator Owns." Per ADR-0030 D5, Operator is no longer the owner — Audit is. This doc reconciliation lands with Operator's stand-up initiative, not here. Flagging so it does not get lost.

- **Hash-chain / WORM tamper-evidence.** Per ADR-0030 D8a / D9 and ADR-0031 §Negative, Phase 1 is append-only-by-interface, NOT tamper-evident. Hash-chain/WORM is deferred behind the boundary until a stated trigger fires (compliance, customer-contract, or incident-class requirement). The scaffold must not document or describe the store as tamper-evident.

- **The deployable tenant-facing forensics read Service.** Per ADR-0030 D8b, deferred behind the boundary; built later over the existing `IAuditQuery` with no contract change. Not in scope here.

- **The `HoneyDrunk.Audit.Testing` package.** Per ADR-0031 D2 and ADR-0027 D3 precedent, the in-memory `IAuditLog`/`IAuditQuery` fixture ships `internal` to the runtime package's test project. When a third consumer (beyond Auth and Operator) needs it, it is cut into a `HoneyDrunk.Audit.Testing` package as a non-breaking change. Not in this initiative.

- **The Audit Node's own managed identity (Azure provisioning).** Per ADR-0031 D5, the Audit Node runs under its own dedicated managed identity, distinct from Auth's and Operator's. **`HoneyDrunk.Audit` is a library Node at Phase 1** — both `Abstractions` and `Data` are library packages, not deployables. The managed identity is needed at the moment Audit's `Data` composition first runs in a deployable host (i.e., when a Container App composes `HoneyDrunk.Audit.Data`). At that point the host's managed identity assumes Audit's identity scope. Provisioning the user-assigned managed identity and applying RBAC against Key Vault / App Configuration belongs with whichever packet first deploys an Audit-composing host — not this scaffold. Same precedent as ADR-0016 AI standup, which deferred Azure provisioning ("HoneyDrunk.AI is a library Node, not a deployable. There is no Key Vault, no Container App, no resource group to create."). Cross-link the Azure walkthroughs at [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) for when this work lands.

- **App Configuration seeding for the audit-class retention policy.** Per ADR-0031 D4, the retention value is sourced via App Configuration through Vault's `IConfigProvider` — not hardcoded. The `HoneyDrunk.Audit.Data` runtime reads `audit:retention:days` (and any related keys) from `IConfigProvider`. **Seeding the actual value in Azure App Configuration** is a deploy-time concern carried by whichever host first composes `HoneyDrunk.Audit.Data` — not by this scaffold. Packet 03 ships the read path and a sensible startup default if the key is unset (a long retention, e.g. 365d, with a `::warning::` if the key is missing). Setting it for real in App Config is a Human Prerequisite of the first consuming deployable, not of this scaffold.

- **SonarCloud onboarding for HoneyDrunk.Audit.** Follows the pattern from `generated/work-items/active/adr-0011-code-review-pipeline/06-kernel-sonarcloud-onboarding.md`. Separate follow-up packet, post-`v0.1.0`. Flagged in packet 03's Human Prerequisites.

- **Grid-health aggregator wiring** for the new repo: if `HoneyDrunk.Actions/.github/workflows/grid-health-aggregator.yml` auto-discovers from `catalogs/nodes.json`, ADR-0030 packet 01's edit is sufficient. If not, packet 03's Human Prerequisites flag a small follow-up to add `HoneyDrunk.Audit` to the watched-repos list. Confirm which behavior is in place at execution time.

- **`repos/HoneyDrunk.Auth/integration-points.md` update with the Audit row.** Packet 04 wires Auth as the first emitter (a code change inside `HoneyDrunk.Auth`), but the corresponding catalog-side reconciliation — adding an "Audit" row under "Upstream Dependencies" in `repos/HoneyDrunk.Auth/integration-points.md` (in `HoneyDrunk.Architecture`) — is a separate follow-up Architecture packet. `file-work-items.yml` opens PRs against a single `target_repo`; packet 04 targets Auth, so the Architecture-side edit cannot ride along in the same PR. The follow-up is one paragraph + a CHANGELOG entry; file it as a small Architecture chore packet after packet 04's PR merges so the catalog reflects shipped reality, not a pre-emptive claim.

## Cross-ADR Invariant Numbering — Coordination Honored (Collision-Aware)

The dispatch plan for ADR-0030 originally reserved invariants **45** and **46** for this initiative, assuming 44 was free for the substrate. **That assumption no longer holds.** As of 2026-05-20, `constitution/invariants.md` carries:

- `## AI Invariants` section, **44 / 45 / 46** = ADR-0016 AI standup (downstream Abstractions-only coupling, App-Config sourcing, AI Node contract-shape canary). **Already landed.**

This means ADR-0030 packet 02's own collision-check protocol will shift the substrate-level audit-emission boundary invariant to whatever is the next free slot at its edit time (typically **47** if no other invariant-numbering packet lands between, or higher if e.g. ADR-0018 packet 02's 47-50 claim lands first). The two slots reserved for this initiative will be the next two after that.

The logical allocation is therefore:

- **`{N-substrate}` = audit-emission boundary invariant** (substrate-level, lands with ADR-0030 packet 02). Auditable security events emitted to the Audit substrate via `IAuditLog`, on a durable channel separate from observability. Phase 1 append-only-by-interface, NOT tamper-evident.
- **`{N-coupling}` = downstream Abstractions-only coupling** (ADR-0031 D9). This initiative, packet 01.
- **`{N-canary}` = Audit contract-shape canary requirement** (ADR-0031 D8). This initiative, packet 01.

Where the three concrete numbers are determined by collision check at each packet's actual edit time, in landing order. Throughout this initiative's packet sources, the three placeholders `{N-substrate}`, `{N-coupling}`, `{N-canary}` are used so packets 01/02/03/04 can be filed without prematurely committing to numeric assignments that may shift.

Packet 01 of this initiative reads `## Audit Invariants` section from `constitution/invariants.md` post-ADR-0030-merge, finds the substrate-level invariant + its reservation note for two slots, and appends the two new invariants under the same section. If the reservation note no longer matches the next two free slots (because another invariant-numbering packet landed between ADR-0030 packet 02's merge and packet 01's edit), packet 01 stops, surfaces, and waits for ADR-0030 packet 02 to be fixed-forward in a new packet (invariant 24's no-amendment rule applies).

Packet 01 then updates three cross-references in lockstep with the assigned numbers:

- `adrs/ADR-0031-stand-up-honeydrunk-audit-node.md` — the "New invariant (proposed for `constitution/invariants.md`)" subsection in Consequences (replace the tentative-numbering preamble with the assigned numbers).
- `repos/HoneyDrunk.Audit/invariants.md` — the trailing cross-reference paragraph (update with the assigned numbers).
- Packets 03 and 04 source files of this initiative — their `{N-substrate}` / `{N-coupling}` / `{N-canary}` placeholders are substituted with the assigned numbers in place pre-push. **Packets 03 and 04 cannot be filed in the same push as packet 01** for this reason: the invariant numbers in 03 and 04 must match what packet 01 actually landed.

**Collision pre-claims to be aware of (do not block on, but check):**

- **ADR-0018 packet 02 (Operator standup invariants)** pre-claims slots **47–50**. If ADR-0018 packet 02 lands between this initiative's packet 01 and ADR-0030 packet 02, the substrate's next-free-slot calculation shifts. If ADR-0018 packet 02 lands between this initiative's packet 01 edit time and its push, this initiative's two slots shift.
- **AI-sector standups in flight** (ADR-0020 Agents, ADR-0021 Knowledge, ADR-0022 Memory, ADR-0023 Evals, ADR-0024 Flow, ADR-0025 Sim) — each carries its own invariant-numbering packet. None are pre-claimed at scoping time but landing order is uncertain.

**Filing-order rule (hard):**

1. Push packets 01 and 02 in the same push (they may travel together — packet 02 is human-only, packet 01 is agent; both reference Architecture#108/#109 issues that must already be merged on `main`).
2. Wait for packet 01's PR to merge so the assigned numbers actually land in `constitution/invariants.md`.
3. Wait for packet 02's chore issue to be Done so the public repo exists, branch protection is applied, labels are seeded, OIDC is wired, and the local working tree at `c:/.../HoneyDrunkStudios/HoneyDrunk.Audit/` exists.
4. **Substitute the actual assigned numbers** for `{N-substrate}`, `{N-coupling}`, `{N-canary}` in `03-audit-node-scaffold.md` and `04-auth-wire-first-emitter.md` source files in place pre-push (invariant 24's pre-filing carve-out applies; packets 03 and 04 have not been filed yet).
5. Push packet 03.
6. Wait for packet 03's PR to merge and for `HoneyDrunk.Audit 0.1.0` to publish to NuGet.
7. Push packet 04 (Auth emitter) once `HoneyDrunk.Audit.Abstractions 0.1.0` is discoverable on the consumer feed.

Packet 04 cannot be filed before packet 03's PR is merged and `v0.1.0` is tagged-and-published — Auth needs to add a `PackageReference` that resolves on the consumer feed.

## Asymmetry vs ADR-0016 AI / ADR-0017 Capabilities standups

Three deliberate asymmetries are worth recording:

1. **Two packages, not six.** The AI standup ships `Abstractions` + runtime + four provider slots (six packages). Capabilities ships `Abstractions` + runtime + `Testing` (three). Audit ships **two**: `HoneyDrunk.Audit.Abstractions` and `HoneyDrunk.Audit.Data`. No provider slots — there is no "router," "policy evaluator," or "provider-axis runtime" in Audit. The store *is* the runtime concern (per ADR-0031 §Alternatives Considered).

2. **`HoneyDrunk.Audit.Data` is a backing-slot name, not a bare runtime.** Per ADR-0031 D2 (and §Alternatives Considered: "Bare `HoneyDrunk.Audit` runtime package…rejected"), the runtime package is named for its backing. A future alternative backing would be a sibling slot (`HoneyDrunk.Audit.Cosmos`, `HoneyDrunk.Audit.S3`, etc.), not a replacement of a bare runtime. This matches `HoneyDrunk.Data.*` and `HoneyDrunk.Vault.Providers.*` precedents and is the only Grid Node where the runtime package is backing-named. **Do not** rename to bare `HoneyDrunk.Audit` later — that would close off the sibling-slot path.

3. **No `Testing` package at stand-up.** Per ADR-0031 D2 + §Alternatives Considered ("Ship a `HoneyDrunk.Audit.Testing` package at stand-up (ADR-0017 pattern) — rejected") and ADR-0027 D3 precedent, the in-memory `IAuditLog`/`IAuditQuery` fixture lives **`internal` to the runtime package's test project** until a third consumer (beyond Auth and Operator) needs it. This is a deliberate departure from ADR-0017's ship-`Testing`-at-stand-up pattern, justified by the same reasoning ADR-0027 used: the consumer set is small (2) and known (Auth, Operator). Cutting `HoneyDrunk.Audit.Testing` later is non-breaking. Packet 03 must keep the fixture under `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/` (or equivalent) with `internal` visibility — explicitly NOT a `src/HoneyDrunk.Audit.Testing/` project.

4. **All three contracts frozen, not a four-of-N hot subset.** Per ADR-0031 D8 + §Alternatives Considered ("Freeze only a hot subset of contracts in the canary — rejected"). The Audit public surface is exactly three contracts and all three are on the hot path. There is no low-traffic remainder to leave un-frozen. The canary in packet 03 covers `IAuditLog`, `IAuditQuery`, and `AuditEntry` from the first scaffold.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND `HoneyDrunk.Audit 0.1.0` is published to NuGet AND `HoneyDrunk.Auth 0.x.0` ships its first emitter version, the entire `active/adr-0031-audit-node-standup/` folder moves to `archive/adr-0031-audit-node-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done` and the version bump in the consuming repo (Auth) lands.

## Notes

- **Why packet 02 is its own item.** The `HoneyDrunk.Audit` GitHub repo does not exist yet. Creation is org-admin only (Org-owner role on `HoneyDrunkStudios`) — it cannot be delegated to an agent. Surfacing it as a Wave-1 work item with `Actor=Human` keeps it visible on The Hive board as a blocker on packet 03 instead of being a hidden prereq buried in the scaffold packet's body. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md`. (The ADR-0016 AI standup used "verify-and-clone" packet 02b because the AI repo had been created during ADR-0016 drafting; the Audit repo was not pre-created.)

- **Why the scaffold packet keeps the in-memory fixture internal.** ADR-0031 D2 + §Alternatives Considered explicitly reject shipping `HoneyDrunk.Audit.Testing` at stand-up because the consumer set (Auth, Operator) is small and known. ADR-0027 D3 is the precedent. The fixture lives at `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/InMemoryAuditLog.cs` (or equivalent) with `internal` visibility. Downstream consumers (Auth at packet 04, eventually Operator) write their own narrowly-scoped test doubles or wait for the eventual `HoneyDrunk.Audit.Testing` package — that follow-up packet will not block.

- **Why all three contracts are frozen in the canary.** ADR-0031 D8 + §Alternatives Considered: the public surface is exactly three contracts and all three are on the hot path (`IAuditLog` on the write path of every security/privileged-action event, `AuditEntry` as its payload, `IAuditQuery` on every forensic read). There is no low-traffic remainder to leave un-frozen; freezing all three from the first scaffold costs nothing and removes the "which one slipped through" failure mode. Packet 03's CI scopes the api-compatibility canary to the `HoneyDrunk.Audit.Abstractions` assembly — the whole-assembly diff covers all three.

- **Status flip happens after merge, not now.** ADR-0031 stays Proposed for this scoping run. The user's standing workflow says the scope agent flips Status → Accepted after the follow-up PRs merge. None of the four packets here flip ADR-0031's Status — that is a separate housekeeping step the scope agent handles when the initiative completes. **And** ADR-0031 cannot flip to Accepted until ADR-0030 is also Accepted (per ADR-0031's own "Done When" gate). The order is: ADR-0030 packets merge → ADR-0030 flips Accepted (ADR-0030 packet 01 does this) → this initiative's four packets merge → ADR-0031 flips Accepted (scope agent housekeeping after this initiative completes).

- **`accepts: ADR-0031` frontmatter.** Every packet in this initiative carries `accepts: ADR-0031` so the hive-sync agent's auto-flip mechanic recognizes the initiative as the ADR's acceptance work. Per user constraint, this is mandatory and is checked at filing.

- **Repo is public by default.** Per memory `project_repos_public_by_default`, HoneyDrunk repos are public unless a revenue/compliance/experiment carve-out applies. Audit substrate is a Core primitive — no carve-out applies. Packet 02's portal step specifies Visibility = Public.

- **No ADR numbers in user-facing docs or code comments.** Per memory `feedback_no_adr_in_docs`, the scaffold's README and per-package READMEs do **not** cite "ADR-0031" by number in their narrative — the README explains what the package does. Runtime / packet-data references (catalog entries, frontmatter, this dispatch plan, the CHANGELOG) are fine to cite ADRs by number.

- **No commits under CHANGELOG Unreleased.** Per memory `feedback_no_unreleased_commits`, the scaffold's first commit lands under `## [0.1.0] - YYYY-MM-DD`, not under `## Unreleased`. The tag push happens after merge — but the version section in CHANGELOG is dated and Semver-bumped before the commit. Packet 03's acceptance criteria call this out.

- **No manual packet filing.** Per memory `feedback_no_manual_packet_filing`, file-work-items.yml auto-files on push to main. Do not run `gh issue create` against these packets. Filing happens by pushing the packet files into `generated/work-items/active/adr-0031-audit-node-standup/`. The filing-order rule above governs which packets land in which push.

- **Auth → Audit edge direction (unambiguous).** Throughout this initiative, the dependency direction is **Auth → Audit, never the reverse**. `HoneyDrunk.Auth` references `HoneyDrunk.Audit.Abstractions` (added by packet 04). `HoneyDrunk.Audit` does not reference any `HoneyDrunk.Auth.*` package — its `Abstractions` carries only `HoneyDrunk.Kernel.Abstractions`, and its `Data` carries Kernel + Data + Vault, with no Auth reference anywhere. The phrase **"first emitter Auth"** in ADR-0030 D6 and ADR-0031 D6 means Auth is the first *producer* of `AuditEntry` records — Audit's catalog row gains an inbound edge from `honeydrunk-auth`, not an outbound edge to it. The DAG stays acyclic: `auth → audit → kernel`, `auth → audit → data → kernel`.

- **ADR-0018 amendment pre-flight check.** ADR-0018 (Operator standup) was amended on 2026-05-16 to acknowledge that `IAuditLog` and `AuditEntry` relocate from Operator's ownership to the new `HoneyDrunk.Audit` Node, and that Operator is reclassified from owner to consumer/emitter. Before pushing this initiative's packets, **verify the amendment is on `main`** in `HoneyDrunk.Architecture` — `git log -- adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` should show the 2026-05-16 amendment commit. If it is missing (e.g., still in a feature branch), ADR-0030 packet 01 is not safe to merge yet and this initiative is not safe to file. The amendment is a documentation-only change (no contract or code edits) but it is the ADR-side anchor for the relocation that ADR-0030 packet 01 records in the catalogs. Pre-flight: `git -C HoneyDrunk.Architecture log --oneline -- adrs/ADR-0018-stand-up-honeydrunk-operator-node.md | head -5` and visually confirm a 2026-05-16 commit naming the audit relocation.

## Filing

The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/work-items/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.
