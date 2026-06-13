# Dispatch Plan — ADR-0061 HoneyDrunk.Files Standup

**Initiative:** `adr-0061-files-standup`
**Sector:** Core
**Governing ADR:** [ADR-0061 — Stand Up the HoneyDrunk.Files Node](../../../../adrs/ADR-0061-stand-up-honeydrunk-files-node.md) (Proposed 2026-05-23; stays Proposed across all four packet PRs. Flips to Accepted only after every packet in this initiative is closed, as a separate post-merge housekeeping step the scope agent runs — see "Status-flip handling" below.)
**Trigger:** ADR-0061 in the Proposed queue. Every PDR-driven consumer-app concept (PDR-0005 Hearth as scout's first-build pick, PDR-0003 Lately, PDR-0006 Currents, PDR-0008 Curiosities) plus Notify's optional `file_id` attachment path and PDR-0002 Notify Cloud's tenant-attachment story are blocked on `HoneyDrunk.Files.Abstractions` existing. This initiative builds the byte-substrate that unblocks them.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Files` (new))
**Site sync required:** No (scaffold-only; no public-API surface change needs site update yet — when `HoneyDrunk.Files 0.1.0` ships and the first consumer wires up, a site-sync follow-up may be warranted)
**Rollback plan:**
- **Pre-tag rollback** (before `v0.1.0` is pushed in Files): `git revert` of each PR. Packets 01/02/03 are independent reverts (Architecture-side); packet 04 reverts the entire scaffold as a single PR.
- **Post-tag rollback** (after `v0.1.0` is pushed in Files but before any consumer references it): NuGet packages are immutable. Either `dotnet nuget delete` if the packages were just pushed and pre-discovery, or fix-forward as `0.1.1`. Practical hard rollback after a tag is messy — prefer fix-forward.
- **After first consumer (e.g., Hearth's media packet) lands:** rollback of Files Abstractions is no longer a clean option — the consumer has a compile-time reference. Treat any defect as forward-only.
- **`file-work-items.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Summary

ADR-0061 is the stand-up ADR for `HoneyDrunk.Files`. It decides what the Node owns (D1), the package families (D3: `Abstractions` + runtime + `InMemory` reference adapter + `AzureBlob` placeholder), the five exposed contracts plus six supporting records (D6), the default backing (D4: Azure Blob Storage v1; R2 reconsidered post-6-months), the tenant-isolation strategy (D5: single container per environment, path-prefixed), the upload-flow shape (D7: signed-URL direct-to-blob), the public-vs-private posture (D8: metadata-driven, CDN-fronted public or short-lived SAS), the processing pipeline shape (D9: async, idempotent, scan-before-available), the quota model (D10), retention/soft-delete + deletion cascade (D11), the audit-event surface (D12), Notify-attachment compatibility (D13), Vault wiring (D14), and the charter sanity check (D15). None of that has been built — the `HoneyDrunkStudios/HoneyDrunk.Files` repo does not exist yet.

Four packets land the work:

1. **Architecture catalog registration + context folder** — register `honeydrunk-files` in every catalog file (`nodes.json`, `relationships.json`, `grid-health.json`, `modules.json`, `contracts.json`), add Core-sector row to `sectors.md`, add Files row to `tech-stack.md`, add Q2 2026 roadmap bullet, add active-initiatives entry, create `repos/HoneyDrunk.Files/` context folder with `overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md` matching the Audit template. Does **not** flip ADR-0061's Status — that is a separate post-merge housekeeping step.
2. **Constitution invariants** — two new invariants from ADR-0061's §New invariants subsection added to `constitution/invariants.md` at the next two free slots under a new `## Files Invariants` section. `{N-domain-meaning}` = Files persists bytes + bytes-metadata only, never domain meaning. `{N-download-shape}` = every Files download is CDN-fronted public or short-lived SAS; long-lived shared-key URLs forbidden Grid-wide. The third ADR candidate (Restricted-tier EXIF strip) stays a documented design decision pending first-feature-packet evidence.
3. **Create the HoneyDrunk.Files GitHub repo (human-only)** — create the public repo on `HoneyDrunkStudios`, apply branch protection, seed labels, configure OIDC federated credential, clone locally. Same shape as the Audit/Capabilities create-repo packets.
4. **HoneyDrunk.Files scaffold** — empty repo to first-shippable state. Solution, four packages (`Abstractions`, runtime, `InMemory` reference adapter, `AzureBlob` placeholder), five interfaces + six records + three enums + `FileId` strong-typed id, default runtime composition (upload session orchestrator, metadata composer, quota policy reader, processing pipeline dispatcher, telemetry helpers), `InMemoryFileStore` + `InMemorySasMinter` + `PassThroughVirusScan` reference impls, two reflection-based constitutional-invariant enforcement tests (`DomainMeaningBoundaryTests`, `DownloadShapeTests`), end-to-end smoke tests (round-trip via InMemory adapter), full CI including the contract-shape canary scoped to `HoneyDrunk.Files.Abstractions`, `README`/`CHANGELOG`/`LICENSE` per package.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates
   ├─ Architecture: 01-architecture-files-catalog-registration   (Agent)
   └─ Architecture: 02-architecture-files-invariants             (Agent)
         Blocked by: packet 01 (so repos/HoneyDrunk.Files/invariants.md
                                 exists for the trailing-paragraph edit)

Wave 2: GitHub repo creation (human-only, sequenced after packet 01 so the
        catalogs already point at the eventual repo when packet 03 creates it)
   └─ Architecture: 03-architecture-create-files-repo            (Human)
         Blocked by: packet 01

Wave 3: HoneyDrunk.Files scaffold
   └─ HoneyDrunk.Files: 04-files-node-scaffold                   (Agent)
         Blocked by: packet 02 (invariant number placeholders {N-domain-meaning}
                                 and {N-download-shape} must be substituted
                                 pre-push with the assigned numbers)
                     packet 03 (the GitHub repo must exist and the local working
                                 tree must be cloned before scaffolding can run)
```

In practice packets 01 and 02 can be filed in the same push — packet 02's `dependencies: ["work-item:01"]` wires the blocking edge automatically. Packet 03 can also travel in the same push (it depends only on packet 01). The strict ordering is just packet 04 — it must wait for packet 02's PR to merge so the invariant numbers actually land, and it must wait for packet 03 to be Done so the target repo exists.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Register HoneyDrunk.Files's standup decisions in Architecture catalogs](./01-architecture-files-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add two new Files invariants (domain-meaning boundary + download shape) to the constitution](./02-architecture-files-invariants.md) | Architecture | 1 | Agent | work-item:01 |
| 03 | [Create `HoneyDrunkStudios/HoneyDrunk.Files` public repo, branch protection, labels, OIDC, clone locally (human-only)](./03-architecture-create-files-repo.md) | Architecture (tracking issue) | 2 | Human | work-item:01 |
| 04 | [Stand up `HoneyDrunk.Files` — solution, four packages, contracts, CI with canary, InMemory reference adapter, smoke tests](./04-files-node-scaffold.md) | HoneyDrunk.Files | 3 | Agent | work-item:01, work-item:02, work-item:03 |

## Phase Mapping (ADR-0061 "If Accepted" checklist → packets)

ADR-0061's "If Accepted — Required Follow-Up Work" checklist, mapped to packets:

| Checklist item | Packet |
|---|---|
| Create `HoneyDrunk.Files` GitHub repo as public | packet 03 |
| Add `honeydrunk-files` entry to `catalogs/nodes.json` | packet 01 |
| Add `honeydrunk-files` entries to `catalogs/relationships.json` | packet 01 |
| Add `honeydrunk-files` to `catalogs/grid-health.json` and `catalogs/modules.json` | packet 01 |
| Update `constitution/sectors.md` Core-sector entry | packet 01 |
| Update `infrastructure/reference/tech-stack.md` | packet 01 (Files in Planned Nodes table; Azure SDK row's Used By updated) |
| Update `initiatives/roadmap.md` | packet 01 |
| Create `repos/HoneyDrunk.Files/` context folder with overview/boundaries/invariants stubs | packet 01 (also adds `integration-points.md` for completeness) |
| File the `HoneyDrunk.Files` scaffold packet | packet 04 |
| Scope agent assigns final invariant numbers if any new invariants are promoted at acceptance time | packet 02 (assigns the two definitive candidates; the conditional EXIF candidate stays a design decision per the ADR's own qualifier) |
| Scope agent flips Status → Accepted after the scaffold packet lands | Separate post-merge housekeeping step — see "Status-flip handling" below |

## What This Initiative Does NOT Deliver

The following are explicitly out of scope for this initiative. Each becomes a separate packet at the appropriate time:

- **The real `HoneyDrunk.Files.AzureBlob` implementation.** Per ADR-0061 D3, the AzureBlob package is a placeholder at v0.1.0 — `.csproj` + `Placeholder.cs` + README naming the deferred status. The actual implementation (Azure.Storage.Blobs reference, real `AzureBlobFileStore : IFileStore`, real SAS minting via user-delegation keys, real path-prefixed storage layout) lands with the first feature packet that activates Files (likely PDR-0005 Hearth's first media-bearing packet).

- **Azure resource provisioning.** No Storage Account, no CDN profile, no Front Door endpoint, no Defender for Storage subscription, no Key Vault, no managed identity for the Files Node — all deferred per memory `feedback_provision_when_needed`. HoneyDrunk.Files is a library Node at Phase 1. Cross-link the Azure walkthroughs at [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) for when this work lands.

- **The production processing toolchain.** v0.1.0 ships only `PassThroughVirusScan` (a no-op stage for tests). The image library (ImageSharp / Magick.NET / SkiaSharp), audio toolchain (FFmpeg / NAudio), EXIF-strip implementation, and Defender-for-Storage malware-scan integration all land with the first feature packet activating processing. Per ADR-0061 D9 the contracts are stable; only the stages' implementations are deferred.

- **Notify's optional `file_id` attachment-path wiring.** Per ADR-0061 D13, Notify's `Attachment` record gains an optional `file_id` field that resolves via `IFileStore` at delivery time. That code change lives in `HoneyDrunk.Notify` and depends on `HoneyDrunk.Files.Abstractions 0.1.0` being published. It is a follow-up Notify-side packet, not part of this initiative.

- **The first consumer's media packet (Hearth's photo upload).** Per ADR-0061's "Unblocks" list, accepting this ADR unblocks Hearth's first media-bearing packet. That packet is scoped under PDR-0005 Hearth's own initiative (not yet stood up at scoping time of this Files initiative) and depends on `HoneyDrunk.Files.Abstractions 0.1.0` being published.

- **Tenant-offboarding event-handler wiring.** Per ADR-0061 D11, Files consumes `TenantOffboarding` / `TenantClosed` / `UserErasureRequest` events to execute the deletion cascade. The event-handler wiring (Transport subscriber + cascade implementation) lands with the first feature packet that activates the cascade — not in this scaffold. The scaffold ships the `IFileStore.DeleteAsync` soft-delete surface and the `FileDescriptor.SoftDeletedAt` field that the cascade will use.

- **The PDR-driven app Nodes' catalog ids and edges.** ADR-0061's "If Accepted" mentions Hearth/Lately/Currents/Curiosities as future consumers. Their Node ids (`honeydrunk-hearth`, etc.) do not exist in `nodes.json` as of 2026-05-24 — they get added by each PDR's own standup ADR. Packet 01's `consumed_by_planned` for Files lists only the existing Nodes named in ADR-0061 D13 (Notify, Communications); speculative app-Node ids would create downstream churn.

- **Billing tenant tier-defaults seeding.** Per ADR-0061 D10, quota tier defaults are sourced from Billing when stood up. Billing is not yet stood up; the scaffold ships in-code seed values matching ADR-0061 D10's table (`tnt_internal` 1 TB / 1M files / 1 GB single; Trialing 500 MB / 1000 / 25 MB; etc.) that the host overrides via App Configuration when Billing lands. Billing standup is its own future ADR.

- **App Configuration seeding for `files:quota:*` keys.** Per packet 04, the runtime reads `files:quota:byte-total-default`, `files:quota:file-count-default`, `files:quota:single-file-cap-default`, `files:retention:soft-delete-window-days`, etc. **Seeding the actual values in Azure App Configuration** is a deploy-time concern carried by whichever host first composes `HoneyDrunk.Files` runtime — not by this scaffold. Packet 04 ships the read path and sensible startup defaults (matching ADR-0061 D10) if the keys are unset (with `::warning::` logs). Setting them for real in App Config is a Human Prerequisite of the first consuming deployable.

- **SonarCloud onboarding for HoneyDrunk.Files.** Follows the pattern from the ADR-0011 code-review-pipeline initiative's per-repo onboarding packets. Separate follow-up packet, post-`v0.1.0`. Flagged in packet 04's Human Prerequisites.

- **Grid-health aggregator wiring** for the new repo: if `HoneyDrunk.Actions/.github/workflows/grid-health-aggregator.yml` auto-discovers from `catalogs/nodes.json`, packet 01's edit is sufficient. If not, packet 04's Human Prerequisites flag a small follow-up to add `HoneyDrunk.Files` to the watched-repos list. Confirm which behavior is in place at execution time.

- **Post-v0.1.0 catalog version-bumps.** After packet 04 lands `v0.1.0`, the `catalogs/modules.json` entries for Files (which packet 01 wrote at v0.0.0) need to bump to v0.1.0, and the `catalogs/grid-health.json` Files row needs to flip its `version` from `0.0.0` to `0.1.0` and update its `active_blockers` array. That follow-up is one small Architecture chore packet filed after v0.1.0 ships — not in this initiative.

## Cross-ADR Invariant Numbering — Coordination Honored

At scoping time (2026-05-24), the `constitution/invariants.md` high-water mark is **49** (the last `## Audit Invariants` entry — `49.` Audit contract-shape canary). The expected assignments for this initiative's packet 02 are:

- **`{N-domain-meaning}` (assigned by reservation registry)** — Files persists bytes + bytes-metadata, never domain meaning.
- **`{N-download-shape}` (assigned by reservation registry)** — every download is CDN-fronted public or short-lived SAS.

The expected numbers will hold unless another invariant-numbering packet lands between this scoping and packet 02's edit time. Packet 02's collision-check protocol is authoritative — the agent reads `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20` at edit time and uses the actual high-water + 1 and high-water + 2.

**Filing-order rule (hard, enforced by `dependencies:` frontmatter):**

1. Push packets 01 and 02 in the same push (they may travel together — packet 02's `dependencies: ["work-item:01"]` wires the blocking edge automatically).
2. Push packet 03 in the same wave or shortly after (it depends only on packet 01).
3. Wait for packet 02's PR to merge so the assigned invariant numbers actually land in `constitution/invariants.md`.
4. Wait for packet 03 to close (the Files repo must exist before packet 04 can be filed against it).
5. **Substitute the actual assigned numbers** for `{N-domain-meaning}` and `{N-download-shape}` in `04-files-node-scaffold.md` source file in place pre-push (invariant 24's pre-filing carve-out applies; packet 04 has not been filed yet at that point).
6. Push packet 04.

**Packets 02 and 04 cannot be filed in the same push** because packet 04's placeholders depend on packet 02's actual assignment.

## Asymmetry vs ADR-0031 Audit standup

Four deliberate asymmetries vs Audit are worth recording (Audit being the closest substrate analog):

1. **Four packages, not two.** Audit ships `Abstractions` + `Data`. Files ships `Abstractions` + runtime + `InMemory` reference adapter + `AzureBlob` placeholder. The extra packages reflect (a) the multi-backing reality (InMemory for tests, AzureBlob for production, future R2 / Backblaze adapters) and (b) the larger reference-adapter surface (Audit's in-memory test double is small enough to live `internal` to a test project; Files' InMemory adapter is a real reusable composition with three classes).

2. **`HoneyDrunk.Files.InMemory` ships as a package, not `internal` to tests.** Unlike Audit (ADR-0031 D2 + ADR-0027 D3: small known consumer set, fixture stays `internal`), Files' first-named consumer is PDR-0005 Hearth — an external repo that will need to mock `IFileStore` in its own unit tests from the first media-bearing packet. This is the ADR-0017 Capabilities pattern (ships `HoneyDrunk.Capabilities.Testing` at standup) applied to a substrate Node. Cutting the InMemory adapter later as non-breaking is possible but unnecessary — the v0.1.0 commit is the right moment.

3. **`HoneyDrunk.Files.AzureBlob` ships as an empty placeholder, not as a backing-named runtime.** Audit's `HoneyDrunk.Audit.Data` is the *only* backing at v0.1.0 — it's named for its backing (per ADR-0031 D2's "bare `HoneyDrunk.Audit` runtime rejected"). Files takes the opposite approach: the bare `HoneyDrunk.Files` runtime is the composition home, and the `HoneyDrunk.Files.AzureBlob` package is one of N sibling backing adapters (with `HoneyDrunk.Files.InMemory` being the v0.1.0 sibling, and future R2 / Backblaze siblings the optional Phase-2). The empty placeholder reflects the ADR-0061 D3 commitment: the AzureBlob package exists at standup but has no implementation; the Azure adapter lands with the first feature packet.

4. **Five interfaces + six records + three enums, not three contracts.** Audit's public surface is exactly three contracts (`IAuditLog`, `IAuditQuery`, `AuditEntry`) — all frozen. Files has a wider surface because (a) the upload flow (`IFileUploadSession`), (b) metadata queries (`IFileMetadata`), (c) the processing pipeline (`IFileProcessor`), and (d) the quota policy (`IFileQuotaPolicy`) are all separable concerns that downstream consumers compose against independently. All five interfaces are on the hot path for some consumer; the canary covers the whole Abstractions assembly.

## Notes

- **Why packet 03 is its own item.** The `HoneyDrunk.Files` GitHub repo does not exist yet. Creation is org-admin only (Org-owner role on `HoneyDrunkStudios`) — it cannot be delegated to an agent. Surfacing it as a Wave-2 work item with `Actor=Human` keeps it visible on The Hive board as a blocker on packet 04 instead of being a hidden prereq buried in the scaffold packet's body. Same shape as `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md`.

- **Why `HoneyDrunk.Files.AzureBlob` ships empty at v0.1.0.** ADR-0061 D3 is explicit: "Placeholder project carrying the .NET version, analyzers, and CI wiring; no implementation on day one. The Azure adapter lands with the first feature packet that activates Files." Adding stub code now (e.g., a skeletal `AzureBlobFileStore` that throws `NotImplementedException`) would lie about the package's status and force a churn-PR when the real implementation lands. The empty placeholder + an explicit README notice is the honest shape.

- **Why ship `HoneyDrunk.Files.InMemory` as a package, not an internal fixture.** PDR-0005 Hearth (the named first consumer per ADR-0061 D2/D15) is an external repo that will write its own unit tests for the media-upload flow. Those tests need to mock `IFileStore` — and the cleanest path is to take a PackageReference on `HoneyDrunk.Files.InMemory` and compose against the reference adapter. Keeping the fixture `internal` (the Audit pattern) would force Hearth's tests to write their own `IFileStore` mock from scratch, which (a) duplicates work and (b) drifts from the canonical reference implementation. The Capabilities pattern (ship `Testing` at standup) is the right precedent here.

- **Why two reflection-based invariant-enforcement tests.** Constitutional invariants `{N-domain-meaning}` and `{N-download-shape}` are runtime rules the review agent cites at PR time — but a PR can quietly add a domain-meaning field to `FileDescriptor` (e.g., `ContentDescription`) or a string-returning download overload (`IFileStore.GetRawDownloadUrlAsync(FileId)`) that the canary doesn't catch (because it's an *addition*, not a removal). The reflection-based tests in `HoneyDrunk.Files.Abstractions.Tests` make those additions a build failure — the constitutional rule becomes a CI gate, not just a documentation reference.

- **Status flip happens after merge, not now.** ADR-0061 stays Proposed for this scoping run. The user's standing workflow says the scope agent flips Status → Accepted after the follow-up PRs merge. None of the four packets here flip ADR-0061's Status — that is a separate housekeeping step the scope agent handles when the initiative completes.

- **`accepts: ADR-0061` frontmatter.** Every packet in this initiative carries `accepts: ADR-0061` so the hive-sync agent's auto-flip mechanic recognizes the initiative as the ADR's acceptance work. Per user constraint, this is mandatory and is checked at filing.

- **Repo is public by default.** Per memory `project_repos_public_by_default`, HoneyDrunk repos are public unless a revenue/compliance/experiment carve-out applies. Files substrate is a Core primitive — no carve-out. The *bytes* stored are the consuming Node's data (a journal entry in Hearth, an avatar in Lately, an attachment in Notify Cloud); Files itself owns no secrets and its public surface is byte-shaped abstractions, not tenant-specific behavior. Packet 03's portal step specifies Visibility = Public.

- **No ADR numbers in user-facing docs or code comments.** Per memory `feedback_no_adr_in_docs`, the scaffold's README and per-package READMEs do **not** cite "ADR-0061" by number in their narrative — the README explains what the package does. Runtime / packet-data references (catalog entries, frontmatter, this dispatch plan, the CHANGELOG) are fine to cite ADRs by number.

- **No commits under CHANGELOG Unreleased.** Per memory `feedback_no_unreleased_commits`, the scaffold's first commit lands under `## [0.1.0] - YYYY-MM-DD`, not under `## Unreleased`. The tag push happens after merge — but the version section in CHANGELOG is dated and SemVer-bumped before the commit. Packet 04's acceptance criteria call this out.

- **No manual packet filing.** Per memory `feedback_no_manual_packet_filing`, file-work-items.yml auto-files on push to main. Do not run `gh issue create` against these packets. Filing happens by pushing the packet files into `generated/work-items/active/adr-0061-files-standup/`. The filing-order rule above governs which packets land in which push.

- **Files → Audit edge direction (unambiguous).** Files references `HoneyDrunk.Audit.Abstractions` (for `IAuditLog` and `AuditEntry`) per ADR-0061 D12. Audit does NOT reference Files. The new edge in packet 01's `catalogs/relationships.json` reflects this: `honeydrunk-files.consumes` includes `honeydrunk-audit`; `honeydrunk-audit.consumed_by_planned` adds `honeydrunk-files`. The DAG stays acyclic.

## Status-flip handling

ADR-0061 stays at `Status: Proposed` for the duration of this scoping run and across all four packet PRs. Per the user's standing ADR acceptance workflow (`feedback_adr_workflow.md`): new ADRs start Proposed; the scope agent flips Status → Accepted only after the bundle's PRs have merged, never on a first-draft packet.

None of the four packets in this initiative flip ADR-0061's status. That is a separate housekeeping step the scope agent performs once packets 01 / 02 / 03 / 04 are all closed and the scaffold has merged. The flip is a one-line edit to `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` line 3 (`**Status:** Proposed` → `**Status:** Accepted`), plus any matching update to `adrs/README.md` if it carries a per-ADR Status entry, plus a CHANGELOG note. The hive-sync agent's ADR auto-acceptance loop may also reconcile this on its next run if it is delayed.

This is the same pattern ADR-0031 Audit standup followed.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND `HoneyDrunk.Files 0.1.0` is published to NuGet, the entire `active/adr-0061-files-standup/` folder moves to `archive/adr-0061-files-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done` and `v0.1.0` ships.

## Filing

The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/work-items/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.
