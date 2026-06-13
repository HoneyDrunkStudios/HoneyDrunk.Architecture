# Dispatch Plan — ADR-0027 HoneyDrunk.Notify.Cloud Standup

**Initiative:** `adr-0027-notify-cloud-standup`
**Sector:** Ops
**Governing ADR:** [ADR-0027 — Stand Up the HoneyDrunk.Notify.Cloud Node](../../../../adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) (Proposed 2026-05-02; flips to Accepted only after every packet in this initiative is closed, as a separate post-merge housekeeping step the scope agent runs. None of the packets in this initiative flip ADR-0027's status.)
**Prerequisite ADR:** [ADR-0026 — Grid Multi-Tenant Primitives](../../../../adrs/ADR-0026-grid-multi-tenant-primitives.md) (**Accepted** as of 2026-05-20 — confirmed at scoping time). Notify Cloud is the first real (non-noop) consumer of `ITenantRateLimitPolicy` and `IBillingEventEmitter`. Per ADR-0027 D10 the standup ADR cannot flip Accepted until ADR-0026 is Accepted; that gate is now satisfied.
**Trigger:** PDR-0002 commits HoneyDrunk Notify as the Grid's first commercial product. ADR-0027 is the standup ADR that decides what the Notify Cloud Node owns, its package families, its four exposed contracts, its private-repo visibility, and the FSL license posture of the surrounding open-source engine repos. This initiative is the follow-up work.
**Type:** Multi-repo (4 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Notify` + `HoneyDrunk.Communications` + `HoneyDrunk.Notify.Cloud` (new, private))
**Site sync required:** No (scaffold + license-application only; no Studios website content depends on this initiative yet — marketing-site copy that mentions FSL on Notify is a separate PDR-0002 follow-up doc tracked elsewhere)
**Rollback plan:**
- **Pre-tag rollback** (before `v0.1.0` of `HoneyDrunk.Notify.Cloud` is pushed): `git revert` each PR independently. Packets 01–03 are reverts in the Architecture, Notify, and Communications repos respectively. Packet 04 is the human-only chore; reverting it means deleting the private repo (org-admin action). Packet 05's scaffold reverts as a single PR.
- **Post-tag rollback** (after `v0.1.0` of Notify.Cloud is pushed but before customers consume): The private feed packages are unconsumed at this stage. Pull from the feed or fix-forward as `0.1.1`. The FSL LICENSE commits on Notify and Communications are pure additions; reverting them is a clean revert. Once a customer is paying against the hosted service, rollback is no longer a clean option — treat any defect as forward-only.
- **`file-work-items.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Summary

ADR-0027 is the standup ADR for `HoneyDrunk.Notify.Cloud` — the Grid's first commercial-revenue-bearing Node and its first private repo. It decides what the Node owns (D1), the private-repo visibility carve-out (D2), the four package families (D3 — Abstractions / runtime / Stripe billing / Web), the four frozen contracts (D4 — `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance`), the boundary rule with Notify and Communications (D5), the SDK-stays-in-open-Notify-repo rule (D6), one-way telemetry to Pulse (D7), the contract-shape canary (D8), the leaf-node downstream coupling (D9), the hard prerequisite on ADR-0026 (D10), the Functional Source License (FSL) for the open engine repos (D11), API key validation routed through Auth (D12), and the first-PR scaffold checklist (D13). None of that has been built — the Node does not exist on disk and the GitHub repo does not exist yet.

Five packets land the work:

1. **Architecture context-folder + sector-map registration** — create the standard `repos/HoneyDrunk.Notify.Cloud/` folder with five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`), update `constitution/sectors.md` Ops-sector entry to include Notify Cloud. **Does NOT touch `catalogs/*.json` or shared initiative/ADR index files** — hive-sync reconciles those after the initiative completes. Does **not** flip ADR-0027's Status — that is a separate post-merge housekeeping step.
2. **Constitution invariants** — six new invariants from ADR-0027's "New invariants (proposed for `constitution/invariants.md`)" section: D2 (repo public-default + revenue carve-out), D5 (hot-path goes through Communications), D6 (SDK lives in open Notify repo), D4/D12 (API key hashed-only / returned-once), D8 (contract-shape canary), D11 (FSL on engine repos). Assigned to the next six free numbers after the file's current highest, with a hard collision-check gate at edit time.
3. **FSL LICENSE for `HoneyDrunk.Notify`** — apply the Functional Source License (two-year auto-conversion to Apache 2.0) to the open Notify engine + SDK repo per ADR-0027 D11. Includes `LICENSE` file commit, repo description update, and `PackageLicenseExpression` / `PackageLicenseFile` settings in every shipping `.csproj`. **The SDK package (`HoneyDrunk.Notify.Client`) lives in this repo per D6 and ships under the same FSL** — no separate package metadata required.
4. **FSL LICENSE for `HoneyDrunk.Communications`** — same change applied to the Communications repo per ADR-0027 D11. Separate packet from 03 because target repos differ; both packets ship the same license text but the target file paths and `.csproj` updates are repo-specific.
5. **Create `HoneyDrunk.Notify.Cloud` GitHub repo as PRIVATE (human-only)** — org-admin chore. The Grid's first private repo. Explicit revenue carve-out from the public-by-default policy per ADR-0027 D2.
6. **HoneyDrunk.Notify.Cloud scaffold** — empty repo to first-shippable state per ADR-0027 D13. Solution layout, four projects (`HoneyDrunk.Notify.Cloud.Abstractions`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Notify.Cloud.Billing.Stripe`, `HoneyDrunk.Notify.Cloud.Web`) plus matching `.Tests` projects, the four D4 contracts in Abstractions, default `INotifyCloudGateway` wiring API-key-validation → rate-limit → orchestration-delegation → billing-emission, in-memory `INotifyCloudApiKeyStore` for tests, Notify-Cloud-specific `ITenantRateLimitPolicy` implementation replacing Kernel's noop, Stripe billing-adapter stub, Web project placeholder (signup form scaffold + health endpoint), five CI workflows including the contract-shape canary scoped to `HoneyDrunk.Notify.Cloud.Abstractions`, Container Apps deployment configuration referencing ADR-0015's `job-deploy-container-app.yml` workflow targeting `ca-hd-notify-cloud-stg`, proprietary `LICENSE` file (`LicenseRef-Proprietary`).

## Wave Diagram

```
Wave 1: Architecture context + constitution updates (sequential)
   ├─ Architecture: 01-architecture-notify-cloud-context-folder
   └─ Architecture: 02-architecture-notify-cloud-invariants
       Blocked by: 01 (so the invariant text aligns with the context-folder content 01 lands)

Wave 2: FSL on open engine repos (parallel — independent target repos)
   ├─ Notify: 03-notify-fsl-license
   │   Blocked by: 01 (so the new constitution language about FSL is present before the LICENSE file references it)
   └─ Communications: 04-communications-fsl-license
       Blocked by: 01

Wave 3: Private repo creation (human-only)
   └─ Architecture: 05-architecture-create-notify-cloud-repo
       Blocked by: 01, 02

Wave 4: Notify.Cloud scaffold (the substrate stand-up)
   └─ Notify.Cloud: 06-notify-cloud-node-scaffold
       Blocked by: 01, 02, 05
```

Packets 03 and 04 can ship in parallel — same change to different repos. Packet 05 is human-only and gates packet 06 because the private repo it creates is the target repo of packet 06 — `file-work-items.sh` cannot file an issue against a repo that does not exist yet.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Architecture context-folder + sector-map registration](./01-architecture-notify-cloud-context-folder.md) | Architecture | 1 | Agent | — |
| 02 | [Add six new invariants for D2 / D5 / D6 / D4+D12 / D8 / D11](./02-architecture-notify-cloud-invariants.md) | Architecture | 1 | Agent | 01 |
| 03 | [Apply FSL LICENSE to `HoneyDrunk.Notify`](./03-notify-fsl-license.md) | Notify | 2 | Agent | 01 |
| 04 | [Apply FSL LICENSE to `HoneyDrunk.Communications`](./04-communications-fsl-license.md) | Communications | 2 | Agent | 01 |
| 05 | [Create `HoneyDrunk.Notify.Cloud` GitHub repo as PRIVATE (human-only)](./05-architecture-create-notify-cloud-repo.md) | Architecture (tracking issue) | 3 | Human | 01, 02 |
| 06 | [Stand up `HoneyDrunk.Notify.Cloud` — solution, four packages, contracts, CI, Container Apps wiring](./06-notify-cloud-node-scaffold.md) | HoneyDrunk.Notify.Cloud | 4 | Agent | 01, 02, 05 |

## Phase Mapping

- **Wave 1 (packets 01 + 02) = ADR-0027's "If Accepted" obligations on the Architecture repo, minus catalog reconciliation.**
  - Packet 01 covers the new `repos/HoneyDrunk.Notify.Cloud/` context folder (five files matching the template used by `repos/HoneyDrunk.Communications/`) and the sector-map row in `constitution/sectors.md`. It explicitly does **not** touch `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/contracts.json`, or `catalogs/modules.json` per the user's standing instruction that hive-sync reconciles shared catalog indexes after standup initiatives complete. The same instruction applies to `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, and `adrs/README.md`.
  - Packet 02 covers the six new invariants ADR-0027 explicitly delegates to the scope agent at acceptance.
- **Wave 2 (packets 03 + 04) = the FSL license obligation from D11.** Two separate packets because target repos differ. The license text is identical; the per-`.csproj` `PackageLicenseExpression`/`PackageLicenseFile` updates and the repo-level LICENSE file commits are repo-specific. Both packets reference the FSL invariant landed by packet 02.
- **Wave 3 (packet 05) = the human-only private repo creation chore.** Surfaced as its own packet so it lives on The Hive board with `Actor=Human` and the `human-only` label. **First private repo in the Grid** — the packet must explicitly call this out so the human selects "Private" rather than the org default of Public.
- **Wave 4 (packet 06) = the standup itself.** Four packages, four contracts, in-memory API key store, Notify-Cloud-specific rate-limit policy replacing Kernel's noop, Stripe billing-adapter stub, Web placeholder, full CI including the contract-shape canary, and Container Apps deployment config referencing ADR-0015's reusable workflow.

## Filing-order rule

Packet 06 hard-codes invariant numbers in its body and acceptance criteria. Filed packets are immutable (invariant 24). Therefore:

**Packet 02 must be filed, its PR merged, and the assigned invariant numbers locked in `constitution/invariants.md` before packet 06 is filed.**

The invariants this packet adds are sized as the next six free numbers after the file's current highest. As of 2026-05-20, the file's highest assigned number is **43** (ADR-0019 Communications canary). However, two in-flight initiatives — ADR-0016 AI standup and ADR-0017 Capabilities standup — are also waiting to land three and four new invariants respectively. Their packet 02s claim 44/45/46 and 47/48/49/50 (or whatever the next-free sequence is at the moment each lands; collision-check is in their dispatch plans).

**Working assumption for this initiative's packet 02:** the file's highest existing number at the time this packet lands could be anywhere from 43 (none of ADR-0016/0017 have landed yet) to 50 (both have landed and claimed 44-46 and 47-50). Packet 02's `Proposed Implementation` section explicitly says "scan the file at edit time; claim the next six free numbers regardless of what they are." Default-assumption text in this dispatch plan uses **51-56** under the conservative assumption that ADR-0016 and ADR-0017 both land first.

**Packets 02 and 06 cannot be filed in the same push.** Concretely:

1. Push packets 01, 02, 03, 04 (they may travel together — packet 02 / 03 / 04's `dependencies: ["work-item:01"]` wire the blocking edges automatically).
2. Push packet 05 in the same wave or shortly after (it depends on 01 and 02).
3. Wait for packet 02's PR to merge so the assigned invariant numbers actually land in `constitution/invariants.md`.
4. Wait for packet 05 to close (the private repo must exist before packet 06 can be filed against it).
5. If the numbers shifted away from the assumed 51-56, edit `06-notify-cloud-node-scaffold.md` in place to match (pre-filing carve-out under invariant 24).
6. Push packet 06.

Packet 02's acceptance criteria call this out; packet 06's body assumes the lock has happened.

## Sequencing vs ADR-0016 and ADR-0017

Three standup initiatives are in flight concurrently and each claims the next available invariant numbers:

- **ADR-0016 (AI standup):** three invariants. Packet 02's default is 44/45/46.
- **ADR-0017 (Capabilities standup):** four invariants. Packet 02's default is 43/44/45/46 (per its dispatch plan note that ADR-0019's 43 may already be taken — collision-check at edit time wins).
- **ADR-0027 (this initiative, Notify Cloud standup):** six invariants. Default 51-56 assuming the two above land first.

Whichever lands first takes the lowest numbers; the others shift. ADR-0027's packet 02 explicitly uses runtime collision-check rather than hard-coded numbers, and its packet 06 source file is amended in place if the numbers shift (pre-filing carve-out under invariant 24).

The user's instruction during scoping is that this race is resolved by whichever PR merges first — no hard sequencing requirement between the three standup initiatives at the invariant-numbering layer. The substantive work of each initiative is independent and can ship in any order.

## What This Initiative Does **NOT** Deliver

- **The Stripe billing-adapter implementation.** Per ADR-0027 D13, the `HoneyDrunk.Notify.Cloud.Billing.Stripe 0.1.0` package ships as a *stub* — the interface is implemented but the actual webhook bridge / metered-billing wiring is deferred to a follow-up ADR (per PDR-0002's recommended follow-up artifacts: Stripe billing integration ADR). The stub satisfies the contract-shape canary; production wiring lands later.
- **The Web project's full surface.** D13 says the `HoneyDrunk.Notify.Cloud.Web 0.1.0` ships as a placeholder — health endpoint + signup form scaffold only. Signup flow, billing dashboard, delivery logs, and tenant management UI all land in follow-up packets.
- **API key authentication middleware in `HoneyDrunk.Auth`.** Per ADR-0027 D12, the validation primitive lives in Auth as a new `IApiKeyAuthenticator` middleware path. The detailed mechanism (middleware shape, hashing scheme, rotation flow) is a separate follow-up ADR. This stand-up commits to the boundary; the mechanism is settled later.
- **The Communications decision-log persistence backend.** Per ADR-0027's "Unblocks" section, Notify Cloud Pro tier exposes the decision log, which tightens the requirements on the persistence backend. That is a separate ADR (Communications decision-log persistence ADR).
- **Per-tenant AI cost rollups, Pro-tier preference learning, multi-region deployment.** All explicitly out of scope at v1 per ADR-0027 D5's "v1 dependencies" framing and PDR-0002 Phase 5.
- **Production tenant data, real Stripe integration, real Auth API-key middleware.** The scaffold proves the contract surface compiles, the canary catches drift, and the in-memory composition runs end-to-end. Production-shape work follows.
- **Catalog reconciliation in `catalogs/*.json`, the `nodes.json` `visibility` schema-field introduction, sector index updates, ADR README index updates, initiative tracking entries.** These are deferred to the hive-sync agent's next run after this initiative's PRs merge. Per the user's standing instruction, scope agent does not touch shared index files.

## Notes

- **First private repo in the Grid.** The whole Grid has been public-by-default since inception. Packet 05's body explicitly documents (a) the revenue carve-out from D2, (b) the customer-data-adjacent-infrastructure / hyperscaler-defense / billing-integrity justifications, (c) the human-only step of clicking "Private" rather than letting GitHub default to Public, and (d) the LicenseRef-Proprietary stance (no public license file).
- **The SDK stays in the open Notify repo per D6.** Packet 03's FSL LICENSE application covers the SDK as a same-repo artifact — no separate license commit for `HoneyDrunk.Notify.Client`. Future contributors must not relocate the SDK into the private Notify.Cloud repo. The scaffold packet (06) does not author SDK source files.
- **Two-stage license posture.** Open engine repos (Notify + Communications) get FSL (two-year auto-conversion to Apache 2.0). The private wrapper repo (Notify.Cloud) gets `LicenseRef-Proprietary` — all rights reserved by default of being private. Both stances are recorded by ADR-0027 D11 and packet 02's FSL invariant.
- **Contract-shape canary needs no Actions repo change.** Per ADR-0027 D8 and the pattern established in ADR-0016 D8 / ADR-0017 D8 / ADR-0019 D8, the existing `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml` already supports `project-path`-scoped diffing. Packet 06 wires a single `.github/workflows/api-compatibility.yml` file inside HoneyDrunk.Notify.Cloud itself, scoped to `HoneyDrunk.Notify.Cloud.Abstractions`. No Actions repo change required.
- **Kernel multi-tenant primitives are CONSUMED, not redefined.** ADR-0027 D4 is explicit: `TenantId`, `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` all live in `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026 (now Accepted). Packet 06 does **not** declare any of these in `HoneyDrunk.Notify.Cloud.Abstractions`. Notify Cloud is the first *real* (non-noop) consumer of `ITenantRateLimitPolicy` and the first *real* implementation of `IBillingEventEmitter` in the Grid — but it does not own those contracts.
- **Records drop `I`; interfaces keep it.** Per the Grid-wide naming rule set 2026-04-19. `NotifyCloudTenantTier` (record) and `ApiKeyIssuance` (record) drop the prefix; `INotifyCloudGateway` and `INotifyCloudApiKeyStore` (interfaces) keep it.
- **ADR-0026 prerequisite is satisfied.** Confirmed at scoping time (2026-05-20): `adrs/ADR-0026-grid-multi-tenant-primitives.md` line 3 reads `**Status:** Accepted`. The hard prerequisite from ADR-0027 D10 is met — this initiative can proceed without waiting on ADR-0026.
- **Container Apps deployment is staged for `stg` only.** Per ADR-0027 D13 and PDR-0002's single-region commitment, the first deploy target is `ca-hd-notify-cloud-stg` in East US. Production (`prd`) Container App provisioning follows in a deploy-the-stage packet downstream of this initiative; staging is sufficient to prove the deployment path compiles.
- **Status flip happens after merge, not now.** ADR-0027 stays Proposed for this scoping run. The user's standing workflow says the scope agent flips Status → Accepted after the follow-up PRs merge. None of the six packets in this initiative flip ADR-0027's status — that is a separate housekeeping step the scope agent handles when the initiative completes.

## Filing

The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/work-items/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the six new items and their blocking edges.

The exception is packet 05 (the human chore), which itself contains a "Next Steps" script the human runs after creating the private repo. That script is the path by which packet 06 is filed against the new repo.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and `HoneyDrunk.Notify.Cloud 0.1.0` is published to the private feed, the entire `active/adr-0027-notify-cloud-standup/` folder moves to `archive/adr-0027-notify-cloud-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done`. Catalog reconciliation (`catalogs/nodes.json` visibility-field introduction, the new Node entry, `catalogs/relationships.json` dependency edges, `catalogs/grid-health.json` row, `catalogs/contracts.json` four-contract block, `catalogs/modules.json` package entries) also happens during hive-sync's reconciliation pass after the initiative completes — scope agent does not author those edits.
