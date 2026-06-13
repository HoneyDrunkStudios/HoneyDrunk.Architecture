---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "adr-0049", "wave-4", "backfill", "coordinator", "fan-out"]
dependencies: ["work-item:03"]
adrs: ["ADR-0049"]
wave: 4
initiative: adr-0049-pii-classification
node: honeydrunk-architecture
coordinator: true
actual_target_repos: ["HoneyDrunkStudios/HoneyDrunk.Vault", "HoneyDrunkStudios/HoneyDrunk.Data", "HoneyDrunkStudios/HoneyDrunk.Auth"]
---

# Backfill [Classification]/[PiiField] attributes on Core-sector Node persisted records (Auth, Vault, Data)

## Summary
**This is a coordinator packet, not an executable single-repo packet.** Walk every persisted record type, every `AuditEntry` payload shape, and every API/contract type in the Core-sector deployable Nodes — `HoneyDrunk.Auth`, `HoneyDrunk.Vault`, `HoneyDrunk.Data` — and apply the correct `[Classification]` and `[PiiField]` attributes from packet 02. This is the largest one-time cost of ADR-0049 D10 Phase 2; per-Node PRs land on each repo separately sequenced by the order below. The `security` specialist (per ADR-0046 D2 / ADR-0049 D8) reviews each PR.

> **READ THIS FIRST — packet shape and Hive routing.**
> - `target_repo: HoneyDrunk.Architecture` in the front-matter is **literal only** because The Hive's per-packet schema requires a single value. **This packet does not file a PR against `HoneyDrunk.Architecture`.** The Architecture repo gets zero code edits from this packet.
> - The actual execution surface is the three repos listed in front-matter `actual_target_repos`: `HoneyDrunk.Vault`, `HoneyDrunk.Data`, `HoneyDrunk.Auth`. Each gets its own PR with its own `security`-specialist review and its own release tag.
> - **The Hive routing rule is the `actual_target_repos` list, not `target_repo`.** When this packet is filed as an issue, the issue lives on `HoneyDrunk.Architecture` (as a tracking issue for the coordinator), but the work-tracking Issues for the executor live in each `actual_target_repos` entry. The executor (or a downstream coordinator agent) opens the three child issues at execution time.
> - The `coordinator: true` front-matter field is the load-bearing signal. Any downstream tooling (file-work-items workflow, agent dispatcher, `scope` agent) that routes solely on `target_repo` will mis-route this packet — the `coordinator` flag exists so that tooling can branch on it. If tooling doesn't yet honor `coordinator: true`, the human-readable callout in this section is the safety net.
> - This shape matches the per-Node fan-out pattern used in `kernel-adoption-alignment` (packets 01-10 per Node), where each Node got its own packet rather than a coordinator. The reviewer flagged that **per-Node packets would be the cleaner alternative**; the trade-off is six packets instead of one. The choice here (one coordinator) keeps the dispatch plan readable; the cost is this routing-clarification callout. If the per-Node alternative is later preferred, this packet can be split into `07a-vault-backfill.md`, `07b-data-backfill.md`, `07c-auth-backfill.md` with no other change.

## Context
ADR-0049 D10 Phase 2 commits the backfill of every persisted/transmitted field across the 12 live Nodes. Net code change is small (annotations) but the surface is broad: every record persisted by `HoneyDrunk.Data` repositories, every API contract field, every Audit-emitted payload type, every secret-store key shape gets a `[Classification(...)]` (and, where applicable, `[PiiField(...)]`) marker. The analyzer rule from packet 03 fires at `Warning` severity during the backfill window — unmarked fields surface as build warnings; the warnings become errors at the 30-day mark when packet 10 flips the analyzer.

This packet covers the **Core-sector deployable + library Nodes** whose persistence/contract surface intersects PII or tenant-attributable data:

- **`HoneyDrunk.Auth`** — the most PII-dense Node in the Core sector. User identities, sign-in records, token-validation traces, authorization-policy decisions, signing-key references. Read the current `HoneyDrunk.Auth` source for the actual record types; expect at minimum user-identity records (PII), claims (potentially Sensitive PII), and policy decisions (Confidential).
- **`HoneyDrunk.Vault`** — the secret-store surface. Secret *values* are never persisted in records anyway (they live in the backing vault), but secret *metadata* (names, expiry, rotation status), tenant-scoped resolver state, and audit-emit shapes around secret rotation all need classification. Most are Confidential or Internal; raw user-attributable correlation metadata may be Restricted.
- **`HoneyDrunk.Data`** — the persistence-contracts repo itself. Mostly Internal or Confidential; the `OutboxMessage` shape and any tenant-attributable repository state needs explicit marking.

Other Core-sector Nodes (Kernel, Transport, Web.Rest, Communications, Notify, Notify.Cloud, Audit) are handled either by their own ADR-0049-tracking packets or by packet 08 (Ops-sector backfill). Kernel-Abstractions itself doesn't need backfill — the attributes ship from there, and Kernel's runtime types are operational and Internal-classed by default.

> **The "fields you should not have been storing at all" finding.** ADR-0049 Operational Consequences: "Some Nodes will discover fields they should not have been storing at all (e.g., a debug field capturing a full request body). That is a *finding*, not a regression; treat as such." When the executor encounters such a field, they should:
> 1. Mark it `[Classification(DataClass.Restricted)]` to surface the regression to the security reviewer.
> 2. Open a **separate** issue in the target repo (not in this initiative) tracking the field's removal.
> 3. Do NOT delete the field in this packet's PR. Mark-and-flag is the entirety of this packet's responsibility on that path.

## Scope
Three separate PRs, sequenced as follows. Each PR lands on `main` in its respective target repo independently; the `security` specialist reviews each.

1. **`HoneyDrunk.Auth`** PR — backfill all persisted-record, contract-type, and Audit-emit payload classifications.
2. **`HoneyDrunk.Vault`** PR — backfill secret-metadata records and tenant-resolver state.
3. **`HoneyDrunk.Data`** PR — backfill outbox-message shapes, repository-state records, migration-context shapes.

Order: Vault → Data → Auth (Vault first because Auth depends on Vault for signing-key references; Data second because Auth's user persistence may flow through `HoneyDrunk.Data`; Auth last after both upstream Nodes are marked). Within each PR:

- Add `[Classification(...)]` to every public/internal property on persisted records, API request/response types, and `AuditEntry`-payload types.
- Add `[PiiField(...)]` to every field whose runtime value is PII per ADR-0049 D2.
- Set `Purpose` strings using the convention `"{node}:{operation}"` (e.g. `"auth:signin"`, `"vault:rotation-correlation"`, `"data:tenant-outbox"`).
- Update each per-package `CHANGELOG.md` with an entry describing the backfill (real change for every package that ships marked types).
- Update each `README.md` only if the public API surface gained the attributes in a way consumers need to know about — typically a one-sentence addition to the API-surface section.
- Version-bump each repo's solution per invariant 27 (every non-test `.csproj` to the same new minor version in one commit).

## Proposed Implementation

Per-Node procedure (repeat for Vault, then Data, then Auth):

1. **Read every persisted-record type, contract type, and `AuditEntry`-payload type in the Node.** Use `Grep` against the Node's source for `record ` declarations and `class ` declarations on persisted/contract surfaces. Skim each for the property list.

2. **For each property, determine the classification:**
   - **Public** — intentionally world-readable (e.g. a published version string, a public health-check status string).
   - **Internal** — operational, no tenant attribution (e.g. internal correlation IDs not tied to a user).
   - **Confidential** — tenant-attributable but not user-identifying (e.g. `TenantId`, tenant-scoped configuration keys, billing line-item IDs).
   - **Restricted** — user-identifying or sensitive (e.g. email, name, signing key references, payment instrument IDs).
   - **When in doubt: Restricted.** ADR-0049 D1's default-to-Restricted rule.

3. **For each Restricted property, determine the PII sub-category:**
   - **PII** — identifies a natural person (name, email, phone, IP address, device ID).
   - **SensitivePii** — Article 9 special-category (government ID, financial-account credential, biometric, precise geolocation, health, religion, political opinion, racial/ethnic origin, trade-union membership, children's data, full PAN).
   - **Pseudonymous** — opaque Grid-scoped identifier (`PrincipalId`, `TenantId`, hashed-email idempotency key, correlation IDs, agent-execution IDs).
   - Properties carrying non-PII Restricted data (e.g. raw secret-name strings, machine-internal opaque tokens) get `[Classification(DataClass.Restricted)]` WITHOUT a `[PiiField]` marker. The `[PiiField]` attribute is only for personal data.

4. **Apply the markers.** Use the worked example from ADR-0049 D4 as the template:
   ```csharp
   public sealed record SomePersistedRecord(
       [Classification(DataClass.Restricted)]
       [PiiField(PiiCategory.Pii, Purpose = "auth:identity")]
       string Email,
       
       [Classification(DataClass.Confidential)]
       TenantId Tenant,
       
       [Classification(DataClass.Restricted)]
       [PiiField(PiiCategory.Pseudonymous, Purpose = "auth:correlation")]
       PrincipalId Subject
   );
   ```

5. **Build the Node.** The analyzer rule from packet 03 fires at `Warning` for every unmarked property on a persisted-record/audit-payload type. After backfill, the build should show **zero analyzer warnings** in the changed file set; if any remain, that's an unmarked field the executor missed.

6. **Run the `security` specialist review.** Per ADR-0046 D2 and ADR-0049 D8, the `security` agent is invoked for any PR that touches new `[PiiField(SensitivePii)]` declarations or new boundaries that handle Restricted-class data. The executor opens each Node PR and tags it for `security` review. The specialist's pass is the second of two reviews (the generalist `review` agent is the first pass per ADR-0044 D3 category 9 Security).

7. **Per-Node CHANGELOG and version bump.** Each Node repo's `CHANGELOG.md` gets a new `[X.Y.0]` entry. Per-package CHANGELOG entries only on packages that gained markers (real changes). Bump every non-test `.csproj` to the same new minor version in one commit per invariant 27.

8. **Sequencing across repos.** Vault PR merges first. Wait for the Vault NuGet release tag to land on the package feed before opening the Data PR (Data may not depend on Vault for persisted-record types, but the cross-Node review-routing convention says we sequence by topology). Data PR merges, then release. Auth PR merges last, after both upstream releases.

9. **Coordination with the catalog population packet (09).** Packet 09 populates `catalogs/data-classification.json` based on the actual `[Classification]`/`[PiiField]` markers landed across the Grid. Packet 09 waits for this packet AND packet 08 to complete (both backfill packets must merge before the catalog can be populated coherently).

10. **The "should not have been storing at all" finding workflow.** If the executor encounters a field that was logging or persisting something the Node should not have (e.g. a debug field capturing a full request body), mark it `[Classification(DataClass.Restricted)]` to surface to the security reviewer AND open a follow-up issue in the target repo tracking the field's removal. Do not delete the field in this packet's PR; the deletion is its own scope and warrants its own review.

## Affected Files
- Per-Node `[Classification]`/`[PiiField]` additions across record types, contract types, and Audit-payload types — across Auth, Vault, Data repos.
- Per-package `CHANGELOG.md` entries on every package gaining markers.
- Per-package `README.md` updates only where the API-surface change is consumer-visible.
- Repo-level `CHANGELOG.md` entries on Auth, Vault, Data.
- Every non-test `.csproj` in each repo's solution — version bump.

## NuGet Dependencies
- Each Node repo's relevant packages gain (or version-bump the existing) `PackageReference` on `HoneyDrunk.Kernel.Abstractions` at the packet-02 version. Most already reference it — verify and bump.
- No other new package references.

## Boundary Check
- [x] Markers land in the Node that owns the records — Auth's records in Auth, Vault's in Vault, Data's in Data. No cross-repo edit.
- [x] The `[Classification]` and `[PiiField]` attributes are from `HoneyDrunk.Kernel.Abstractions` (the established Grid-wide-primitive home per ADR-0026/0042/0049). No new shared package introduced.
- [x] No runtime-behavior change in this packet — pure declarative annotation. The redactors (packets 04, 05) consume the markers at runtime.

## Acceptance Criteria
- [ ] Three separate PRs filed and merged: one on `HoneyDrunk.Vault`, one on `HoneyDrunk.Data`, one on `HoneyDrunk.Auth`, in that order
- [ ] Every persisted-record/contract-type/Audit-payload property in each Node carries a `[Classification(...)]` attribute (or is explicitly `[Classification(DataClass.Public)]` if the field is intentionally public)
- [ ] Every property carrying personal data (per ADR-0049 D2) additionally carries a `[PiiField(...)]` attribute with the appropriate `PiiCategory` and a `Purpose` string
- [ ] The analyzer rule from packet 03 shows ZERO warnings against the touched files post-backfill (it may still warn on other files in the repo; that's other Nodes' scope)
- [ ] Each PR receives a generalist `review` agent pass AND a `security` specialist pass; the security pass approves or requests changes
- [ ] Each repo's `CHANGELOG.md` has a new `[X.Y.0]` entry describing the classification backfill
- [ ] Per-package `CHANGELOG.md` entries land only on packages with marker additions (no noise entries for alignment-only bumps, invariant 12/27)
- [ ] Every non-test `.csproj` in each repo's solution is at the new same minor version in a single commit (invariant 27)
- [ ] Any "field that should not exist" finding is mark-and-flag only: marker applied, follow-up issue opened in the target repo, NOT deleted in this PR
- [ ] Vault PR is released to the package feed before the Data PR opens; Data is released before the Auth PR opens (cross-Node sequencing)

## Human Prerequisites
- [ ] **Confirm packet 02 (Kernel attributes) and packet 03 (Standards analyzer) are merged and released.** Both upstream artifacts must be on the package feed before any of the three Node PRs can build.
- [ ] **For each of the three Node releases, push the git release tag after the PR merges.** Agents merge code; humans tag releases. Vault tag → Data tag → Auth tag, in sequence, with each tag's package available on the feed before the next downstream PR opens.
- [ ] **Allocate the `security` specialist review on each of the three PRs.** Per ADR-0046's manual-invocation posture at v1.

## Referenced ADR Decisions
**ADR-0049 D10 Phase 2 — Backfill existing Nodes.** "Walk every persisted record type, every `AuditEntry` shape, every API contract across the live 12 Nodes; apply correct classifications. The `security` specialist drives this Node-by-Node; the `scope` agent authors per-Node packets."

**ADR-0049 D1 — Four-tier taxonomy and default-to-Restricted.** "When classification is unclear, default to Restricted. The cost of over-classification is operational friction; the cost of under-classification is a privacy incident. The `security` specialist (ADR-0046 D2) breaks ties on review."

**ADR-0049 D2 — PII sub-taxonomy.** PII / SensitivePii / Pseudonymous mapping is the load-bearing distinction for fields that need `[PiiField]` markers in addition to `[Classification]`.

**ADR-0049 D8 — Owners and reviewers.** Classification assignment is the field author's responsibility; the generalist `review` agent is the first pass; the `security` specialist is invoked for new `[PiiField(SensitivePii)]` declarations, classification downgrades, and new Restricted-boundary work.

**ADR-0049 Operational Consequences — "should not have been storing at all" finding.** A finding is not a regression; treat as a separate follow-up, not in-scope of the backfill PR.

**Invariant 58 (from packet 00).** "Every persisted field, every public API contract field, and every `AuditEntry` payload field carries a `[Classification]` attribute. Unmarked fields on records inside Restricted-class contexts are a CI gate failure under the `HoneyDrunk.Standards` analyzer rule. Explicit `[Classification(DataClass.Public)]` is the way to opt out."

## Constraints
- **Three separate PRs in three repos.** Do not combine. Each PR is reviewed independently; cross-Node sequencing (Vault → Data → Auth) is enforced via human release-tag gating between them.
- **Mark only — do not refactor.** This packet's scope is pure declarative annotation. If a field's existence is questionable, mark-and-flag; do not delete.
- **Default to Restricted on ambiguity** per ADR-0049 D1. Over-classification is safe; under-classification is a privacy incident.
- **`security` specialist review is mandatory on each PR** per ADR-0046 D2 and ADR-0049 D8. The generalist `review` agent's first pass is necessary but not sufficient.
- **Invariant 27 — Solution-version bump per repo.** Each repo's bump is its own commit on its own branch.
- **Invariant 12 — Per-package CHANGELOG only on packages with real marker additions.** No noise entries.

## Labels
`feature`, `tier-2`, `core`, `adr-0049`, `wave-4`, `backfill`

## Agent Handoff

**Objective:** Backfill `[Classification]` and `[PiiField]` markers across the Core-sector live Nodes Auth, Vault, Data — three separate PRs sequenced Vault → Data → Auth with `security` specialist review on each.

**Target:** This coordinator packet lives in `HoneyDrunk.Architecture`. The executor opens three separate PRs in `HoneyDrunk.Vault`, `HoneyDrunk.Data`, and `HoneyDrunk.Auth` respectively, each branched from `main`.

**Context:**
- Goal: Apply the field-marking discipline shipped in packet 02 to the Core-sector live Nodes' persistence/contract surfaces.
- Feature: ADR-0049 Data Classification rollout, Wave 4 (Phase 2 backfill).
- ADRs: ADR-0049 D10 Phase 2 (primary), ADR-0049 D1/D2 (taxonomy), ADR-0049 D8 (review duties), ADR-0046 D2 (`security` specialist).

**Acceptance Criteria:** As listed above. Each PR has its own subset of acceptance criteria mapped to its repo.

**Dependencies:**
- `work-item:03` — `HoneyDrunk.Standards` analyzer rule exists so the executor can use its warnings as a backfill checklist (zero warnings post-backfill = complete).
- (Implicit via packet 03's dependency on `work-item:02`.)

**Constraints:**
- Three separate PRs; do not combine.
- Mark only — no refactoring; "should not exist" findings are mark-and-flag with a separate follow-up issue.
- Default to Restricted on ambiguity.
- `security` specialist review on each PR (ADR-0046 D2 manual invocation).
- Sequence: Vault → Data → Auth with human release tags between them.
- Invariant 27 per-repo solution-version bumps; invariant 12 per-package CHANGELOG only where real markers landed.

**Key Files:**
- Per-Node persisted records, contract types, `AuditEntry` payload types.
- Per-package `CHANGELOG.md` entries.
- Repo-level `CHANGELOG.md` entries on Vault, Data, Auth.
- Every non-test `.csproj` in each repo's solution.

**Contracts:** No new contracts shipped. Existing types gain `[Classification]` and `[PiiField]` attributes.
