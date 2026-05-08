# Dispatch Plan — ADR-0016 HoneyDrunk.AI Standup

**Initiative:** `adr-0016-honeydrunk-ai-standup`
**Sector:** AI
**Governing ADR:** [ADR-0016 — Stand Up the HoneyDrunk.AI Node](../../../../adrs/ADR-0016-stand-up-honeydrunk-ai-node.md) (Proposed 2026-04-19; flips to Accepted after this initiative's PRs merge per the user's ADR acceptance workflow — scope agent flips Status, never on first draft)
**Trigger:** ADR-0016 accepted into the Proposed queue. Six AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) are blocked on `HoneyDrunk.AI.Abstractions` existing. This initiative builds the substrate that unblocks them.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.AI`)
**Site sync required:** No (scaffold-only; no public-API surface change needs site update yet — when 0.1.0 ships and downstream Nodes start consuming, a site-sync follow-up may be warranted)
**Rollback plan:**
- **Pre-tag rollback** (before `v0.1.0` is pushed): `git revert` of each PR. Packets 01/02/02b are independent reverts; packet 03 reverts the entire scaffold as a single PR.
- **Post-tag rollback** (after `v0.1.0` is pushed but before downstream Nodes consume): NuGet packages are immutable. Either `dotnet nuget delete` if the packages were just pushed and pre-discovery, or fix-forward as `0.1.1`. Practical hard rollback after a tag is messy — prefer fix-forward.
- **After downstream consumers start (post-this-initiative):** rollback is no longer a clean option; treat any defect as forward-only.
- **`file-packets.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Summary

ADR-0016 is the standup ADR for `HoneyDrunk.AI`. It decides what the Node owns (D1), the package families (D2), the seven exposed contracts (D3), routing scope (D4), App Configuration sourcing for routing/cost (D5), Microsoft.Extensions.AI shape compatibility without type-identity coupling (D6), one-way telemetry to Pulse (D7), the contract-shape canary (D8), and the downstream coupling rule (D9). None of that has been built — the AI repo is empty.

Four packets land the work:

1. **Architecture catalog registration** — `contracts.json`, `relationships.json`, `grid-health.json`, `nodes.json`, `ai-sector-architecture.md`, `repos/HoneyDrunk.AI/{boundaries,invariants}.md`. Resolves the D3-vs-"If Accepted" checklist discrepancy by treating D3 as canonical (drops `IInferenceResult`, adds `ICostLedger`).
2. **Constitution invariants** — three new invariants from D5, D8, D9 added to `constitution/invariants.md` at numbers 44/45/46. Also drops invariant 28's `(Proposed)` qualifier (originally scoped to ADR-0010 packet 04 — superseded; see §Supersedes).
2b. **Verify `HoneyDrunk.AI` repo + clone locally (human-only)** — the GitHub repo exists from ADR-0016 drafting (only `.gitignore`, `LICENSE`, `README.md` committed), but the local working tree at `c:/.../HoneyDrunkStudios/HoneyDrunk.AI` does not. This packet is a chore: confirm branch protection matches Grid org default, seed labels, clone the repo locally, and gate filing of packet 03.
3. **HoneyDrunk.AI scaffold** — empty repo to first-shippable state. Solution, six packages, seven contracts, default runtime, four provider slots (InMemory functional, three stubs), five CI workflow files including the contract-shape canary scoped to Abstractions.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-ai-catalog-registration
   └─ Architecture: 02-architecture-ai-invariants
       Blocked by: 01 (so 02's invariant text aligns with the catalog surface 01 lands)

Wave 2: Verify HoneyDrunk.AI repo and clone locally (human)
   └─ Architecture: 02b-architecture-verify-ai-repo
       Blocked by: 01 (catalog must register the AI Node first)

Wave 3: AI repo scaffold
   └─ HoneyDrunk.AI: 03-ai-node-scaffold
       Blocked by: 01, 02, 02b
```

In practice 01 and 02 are both Architecture-repo packets touching different files (catalogs vs constitution), so they could be authored as a single PR. They are kept as separate packets to honor the "one logical change per packet" rule and to give the user a clean review surface for each (catalog drift is one mental model; invariant numbering is another). Packet 02b is a separate human-only chore so the work stays visible on The Hive board as its own item.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration (`contracts.json`, `relationships.json`, `grid-health.json`, `nodes.json`, `ai-sector-architecture.md`, repo invariants/boundaries)](./01-architecture-ai-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add invariants 44/45/46 + drop invariant 28 `(Proposed)` qualifier](./02-architecture-ai-invariants.md) | Architecture | 1 | Agent | 01 |
| 02b | [Verify HoneyDrunk.AI repo + clone locally (human-only)](./02b-architecture-verify-ai-repo.md) | Architecture (tracking issue) | 2 | Human | 01 |
| 03 | [Stand up `HoneyDrunk.AI` — solution, six packages, contracts, CI, InMemory provider](./03-ai-node-scaffold.md) | HoneyDrunk.AI | 3 | Agent | 01, 02, 02b |

## Phase Mapping

- **Wave 1 (packets 01 + 02) = ADR-0016's "If Accepted" catalog/constitution obligations.**
  - Packet 01 covers all four catalog/doc edits in the "If Accepted" checklist except invariants and the scaffold (catalogs/contracts.json + grid-health.json + nodes.json phrasing + ai-sector-architecture.md phrasing) and resolves the D3-vs-checklist discrepancy. Also lands `repos/HoneyDrunk.AI/{boundaries.md, invariants.md}` cleanups for `local models` drift and constitutional cross-references.
  - Packet 02 covers the invariants ADR-0016 explicitly delegates to the scope agent at acceptance, plus the invariant 28 qualifier removal originally scoped to the now-superseded ADR-0010 packet 04.
- **Wave 2 (packet 02b) = repo verification + local clone (human-only chore).** The GitHub repo exists, but the local clone doesn't and branch protection / labels need to be confirmed before scaffolding. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md`, except this one is verify-and-clone rather than create.
- **Wave 3 (packet 03) = the standup itself.** Larger than typical bring-up packets because the AI Node carries six packages and seven contracts, all of which must land together to give the contract-shape canary a coherent baseline.

## Discrepancies Flagged for the User

**1. Discrepancy in ADR-0016's "If Accepted" checklist.** The ADR's checklist (line 12) lists `IInferenceResult` as one of the seven contracts. The D3 table (lines 54–62) lists `ICostLedger` instead. These cannot both be true — there are seven contracts, not eight.

**Resolution:** Per the user's explicit instruction during scoping, **D3 is canonical**. This initiative ships `ICostLedger` and does **not** ship `IInferenceResult`. Packet 01 swaps the catalog entries accordingly. Packet 03 authors `ICostLedger.cs` and does not author `IInferenceResult.cs`.

**Action item for the human:** When flipping ADR-0016 to Accepted (after this initiative's PRs merge), correct the "If Accepted" checklist on line 12 of the ADR to list `ICostLedger` instead of `IInferenceResult`. Packet 01's Human Prerequisites section calls this out.

Also: `relationships.json` line 190 currently lists `IInferenceResult` in the `honeydrunk-ai` `exposes.contracts` array (this file existed before ADR-0016 and was authored against the now-superseded ADR-0010 inventory). Packet 01 cleans this up.

**2. Stale `Providers.Local` references across catalogs and AI repo docs.** ADR-0016 D2 line 48 lists the fourth provider slot as `HoneyDrunk.AI.Providers.InMemory` (deterministic test double for Evals and CI). Earlier docs and catalogs were authored against a now-retired `Providers.Local` / local-ONNX framing. Drift is present in `catalogs/relationships.json:191`, `catalogs/contracts.json` (the `IModelProvider` description), `catalogs/nodes.json` (value_props line 596 + tags line 586), `constitution/ai-sector-architecture.md:111`, `repos/HoneyDrunk.AI/overview.md:21`, and `repos/HoneyDrunk.AI/active-work.md:22-26`.

**Resolution:** Packet 01 completes the rename across all six locations. Final grep over `catalogs/` and `repos/HoneyDrunk.AI/` must show zero `Providers.Local` and zero `local/ONNX` matches.

**3. Internal disagreement on `HoneyDrunk.AI.Abstractions`'s allowed dependencies.** ADR-0016 D2 line 42 says Abstractions has "Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions" (Kernel.Abstractions allowed). Repo-local invariant 1 at `repos/HoneyDrunk.AI/invariants.md:5` says zero HoneyDrunk dependencies, only `Microsoft.Extensions.*` abstractions allowed (Kernel.Abstractions forbidden). These cannot both be true.

**Resolution:** Per the user's explicit scoping resolution, the **strict stance wins**. `HoneyDrunk.AI.Abstractions` ships with zero `HoneyDrunk.*` references. Kernel reference lives in the `HoneyDrunk.AI` runtime package, not Abstractions. Rationale: keeps the hottest contract surface in the Grid dependency-clean for downstream consumers; matches the existing repo-local invariant; the runtime package is where Kernel reference belongs.

Packet 01 amends ADR-0016 D2 line 42 in the same edit it lands the catalog drift fixes — replacing `Zero runtime dependencies beyond \`HoneyDrunk.Kernel\` abstractions.` with `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.` Packet 03 keeps `Abstractions` HoneyDrunk-free in code and explicitly cites this stance in its Constraints section so the executing agent does not introduce a Kernel.Abstractions reference. Practical fallout: `InferenceCost.OperationCorrelationId` stays `string`; `ICostLedger.GetSummaryAsync(string scope, ...)` keeps `string` params; GridContext/CorrelationId propagation lives in the AI runtime package's `InferenceTelemetry`, not in any Abstractions type.

## Supersedes

This initiative supersedes the parked routing-contracts packet at `generated/issue-packets/active/adr-0010-observe-ai-routing-phase-1/04-ai-add-routing-contracts.md`. That packet's three contracts (`IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`) are authored here as part of the seven-contract D3 surface in packet 03. The cross-repo edit it carried — removing invariant 28's `(Proposed — this invariant takes effect when ADR-0010 is accepted)` qualifier — is rolled into packet 02 of this initiative.

**Action:** As part of packet 01's PR (or in a small Architecture cleanup commit), rename `generated/issue-packets/active/adr-0010-observe-ai-routing-phase-1/04-ai-add-routing-contracts.md` to `04-ai-add-routing-contracts.superseded.md`. The `.superseded.md` suffix prevents `file-packets.yml` from picking it up. The file is kept for historical traceability rather than deleted outright. The ADR-0010 initiative's dispatch plan (if it references packet 04) should also be updated to reflect the supersession.

## Filing-order rule

Packet 03 hard-codes invariant numbers 44/45/46 in its body and acceptance criteria. Filed packets are immutable (invariant 24). Therefore:

**Packet 02 must be filed, its PR merged, and the assigned invariant numbers locked in `constitution/invariants.md` before packet 03 is filed.** Packet 02b can run in parallel with packet 02 — it doesn't depend on the invariant numbers — but its issue must be Done before packet 03 is filed (the local working tree must exist for the scaffolding agent).

If packet 02's collision check at edit time forces a renumber away from 44/45/46, the packet 03 source file at `generated/issue-packets/active/adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold.md` MUST be amended in place before push (it has not been filed yet at that point — invariant 24's pre-filing carve-out applies). **Packets 02 and 03 cannot be filed in the same push.** Concretely:

1. Push packets 01, 02, and 02b (they may travel together — packet 02's `dependencies: ["packet:01"]` and packet 02b's `dependencies: ["packet:01"]` wire the blocking edges automatically; packet 02b is also `actor: human` so it routes onto The Hive as a human-only item).
2. Wait for packet 02's PR to merge so the assigned invariant numbers actually land in `constitution/invariants.md`. Wait for packet 02b's chore issue to be Done so the local working tree exists.
3. If the numbers shifted away from 44/45/46, edit `03-ai-node-scaffold.md` in place to match (pre-filing carve-out under invariant 24).
4. Push packet 03.

Packet 02's acceptance criteria call this out; packet 03's body assumes the lock has happened.

## Sequencing vs ADR-0017 (Capabilities standup)

ADR-0017's standup initiative also intends to claim the next three free invariant numbers. There is a **race condition between the two initiatives' packet 02s** — whichever lands first takes 44/45/46; the other shifts.

**Recommended order:** ADR-0016 lands first because (a) it unblocks six Nodes including Capabilities itself, and (b) ADR-0017's scaffold compiles against `HoneyDrunk.AI.Abstractions` which doesn't exist until ADR-0016 ships. If ADR-0017 lands first by accident, ADR-0016's packet 02 shifts its three invariants to 47/48/49 and packet 03's source file is amended accordingly under invariant 24's pre-filing carve-out.

## Asymmetry vs ADR-0017's `*.Testing` package — deliberate

ADR-0017 D2 uses a separate `HoneyDrunk.Capabilities.Testing` NuGet artifact for downstream test fixtures. ADR-0016 D2 uses `HoneyDrunk.AI.Providers.InMemory` instead — same role (deterministic test double), different shape (a "provider slot" not a `*.Testing` package). The asymmetry is deliberate: the InMemory provider is a real provider implementation that can ship in production hosts (e.g., Evals as a deterministic eval fixture in production-grade eval runs), while a `*.Testing` artifact would be tagged production-forbidden. Downstream Node standup ADRs in the AI sector should pick the pattern that matches their fixture's intended runtime stance — not blindly copy whichever they read first.

## What This Initiative Does **NOT** Deliver

The six downstream-blocked Nodes are **not** delivered by this initiative. The initiative unblocks them, but each gets its own bring-up:

- **HoneyDrunk.Capabilities** — repo not yet scaffolded; will compile against `ModelCapabilityDeclaration`.
- **HoneyDrunk.Operator** — repo not yet scaffolded; will wrap `IChatClient` calls with safety controls.
- **HoneyDrunk.Agents** — repo not yet scaffolded; will compile against `IChatClient` + `IEmbeddingGenerator`.
- **HoneyDrunk.Memory** — repo not yet scaffolded; will use `IEmbeddingGenerator` for vector recall.
- **HoneyDrunk.Knowledge** — repo not yet scaffolded; will use `IEmbeddingGenerator` for retrieval.
- **HoneyDrunk.Evals** — repo not yet scaffolded; will target `IModelProvider` with `InMemoryModelProvider` as the deterministic fixture.

Each of these will need its own standup ADR (per the user's "new-Node scaffolding gets its own ADR/packet" rule) before scaffolding packets are written.

The three OpenAI/Anthropic/AzureOpenAI provider implementations are **stubs** in this initiative. Each needs a follow-up packet to author the actual SDK integration with `ISecretStore`-backed credential resolution. Those packets are not blocked on anything in this initiative once `HoneyDrunk.AI 0.1.0` ships — they can be filed independently.

The `HoneyDrunk.AI.Interop.MEAI` adapter package is deferred to Q3 2026 per ADR-0016 D6 and is not in scope for this initiative.

**SonarCloud onboarding for `HoneyDrunk.AI`** follows the pattern from `generated/issue-packets/active/adr-0011-code-review-pipeline/06-kernel-sonarcloud-onboarding.md` — a separate follow-up packet, not in scope here. Packet 03's Human Prerequisites flag this as a post-merge follow-up.

**`IRoutingPolicy` first implementation** (e.g., a cost-first concrete policy) is **not in scope** for this initiative. Packet 03 ships the contracts and a `DefaultModelRouter` that resolves a registered policy from DI; the cost-first implementation lands as a follow-up so the contract surface can settle before any policy locks against it. `repos/HoneyDrunk.AI/active-work.md` mentions a cost-first first implementation — that's directional, not a packet-3 deliverable.

**Per-tenant AI cost rollups** (composing `ICostLedger` with ADR-0026's `IBillingEventEmitter`) are deferred to whichever Node first commercializes inference, per ADR-0026 D10 and PDR-0002 (Notify-as-a-Service). `ICostLedger` ships tenant-agnostic in this initiative.

**Grid-health aggregator** wiring for the new repo: if `HoneyDrunk.Actions/.github/workflows/grid-health-aggregator.yml` auto-discovers from `catalogs/nodes.json`, packet 01's edit is sufficient. If not, packet 03's Human Prerequisites flag a small follow-up to add `HoneyDrunk.AI` to the watched-repos list. Confirm which behavior is in place at execution time.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and `HoneyDrunk.AI 0.1.0` is published to NuGet, the entire `active/adr-0016-honeydrunk-ai-standup/` folder moves to `archive/adr-0016-honeydrunk-ai-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done`.

## Notes

- **Scoping insight: the contract-shape canary needs no Actions packet.** Initially scoped this initiative as four packets (with a separate Actions packet to wire the canary). Investigation showed `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml` already exists and supports `project-path`-scoped diffing. Per ADR-0016 D9, `HoneyDrunk.AI.Abstractions` is the only public-boundary package — so scoping the canary to that one assembly satisfies D8 without per-type filtering. The wiring is a single `.github/workflows/api-compatibility.yml` file inside HoneyDrunk.AI itself, folded into packet 03's CI bring-up. No Actions repo change required.

- **Why two Architecture packets in Wave 1, not one.** Catalog drift correction (packet 01) and invariant numbering (packet 02) are conceptually separate review concerns. A single mega-PR mixing them would obscure the D3-canonical resolution of the `IInferenceResult`/`ICostLedger` discrepancy. Packets 01 and 02 may be filed in the same push (their `dependencies:` frontmatter wires the `packet:01 → packet:02` blocking edge automatically); the **hard split is between 02 and 03** — see the Filing-order rule above. Packet 03 must not be filed until packet 02 has landed in `constitution/invariants.md` and the assigned numbers are confirmed, so any required amendments to packet 03's source file can happen pre-filing.

- **Why packet 02b is its own item.** The `HoneyDrunk.AI` GitHub repo already exists (created during ADR-0016 drafting), but the local working tree at `c:/.../HoneyDrunkStudios/HoneyDrunk.AI` doesn't, and branch protection / labels need to be checked. Surfacing this as a Hive-board item with `Actor=Human` keeps it visible as a blocker on packet 03 instead of becoming a hidden prereq buried in the scaffold packet's body. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` — except verify-and-clone, not create.

- **Status flip happens after merge, not now.** ADR-0016 stays Proposed for this scoping run. The user's standing workflow says the scope agent flips Status → Accepted after the follow-up PR merges. None of the three packets in this initiative flip ADR-0016's status — that is a separate housekeeping step the scope agent handles when the initiative completes.

- **No Azure provisioning in scope.** HoneyDrunk.AI is a library Node, not a deployable. There is no Key Vault, no Container App, no resource group to create. App Configuration provisioning (the Grid-shared App Config that ADR-0005 describes) is already in place from the ADR-0005/0006 rollout — packet 03 just consumes it via `IConfigProvider`. When the cost-rate keys and routing-policy keys actually need to be seeded in App Config, that is a follow-up Human Prerequisite carried by whichever packet first stands up an inference-using deployable.

## Filing

The `file-packets.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/issue-packets/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the three new items and their blocking edges.
