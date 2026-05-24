# Dispatch Plan — ADR-0060 Stand Up the HoneyDrunk.Identity Node

**Initiative:** `adr-0060-identity-standup`
**Sector:** Core
**Governing ADR:** [ADR-0060 — Stand Up the HoneyDrunk.Identity Node](../../../../adrs/ADR-0060-stand-up-honeydrunk-identity-node.md) (Proposed 2026-05-23; flips to Accepted after this initiative's PRs merge per the user's ADR acceptance workflow — scope agent flips Status, never on first draft)
**Trigger:** ADR-0060 names the user-record boundary the Grid had never homed. Auth is validation-only; no Node owned the user record, the external-IdP seam, internal-token issuance, or the user-level GDPR Art. 17 path. Hearth (PDR-0005) is the scout's first-build pick and is blocked on this boundary; Lately (PDR-0003), Curiosities (PDR-0008), and Notify.Cloud are queued behind it. This initiative stands up the Node so those consumer apps have somewhere to land their signup work.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Identity` (new))
**Site sync required:** No (scaffold-only; no public-API surface change needs site update yet — when `HoneyDrunk.Identity 0.1.0` ships and Hearth wires the first consumer flow, a site-sync follow-up may be warranted)
**Rollback plan:**
- **Pre-tag rollback** (before `v0.1.0` is pushed in Identity): `git revert` of each PR. Packets 01/02/03 are independent reverts; packet 04 reverts the entire scaffold as a single PR.
- **Post-tag rollback** (after `v0.1.0` is pushed in Identity but before Hearth/Lately/Curiosities consumes it): NuGet packages are immutable. Either `dotnet nuget delete` if the packages were just pushed and pre-discovery, or fix-forward as `0.1.1`. Practical hard rollback after a tag is messy — prefer fix-forward.
- **After first consumer takes a PackageReference:** rollback of Identity Abstractions is no longer a clean option — the consumer has a compile-time reference. Treat any defect as forward-only.
- **`file-packets.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Summary

ADR-0060 is the stand-up ADR for `HoneyDrunk.Identity`. It decides what the Node owns (D1: user record, external-IdP seam, internal-token issuance, account-deletion fan-out), the IdP-wrapping posture (D2: thin seam over an external IdP, leading candidate Entra External ID — vendor confirmation deferred to Phase 2), the `UserId`/`PrincipalId`/`ExternalSubject` shape (D3), the six interfaces + seven records (D4), where the user profile lives (D5: in Identity, not the IdP), internal-token issuance discipline (D6: Identity issues, Auth validates — Invariant 10 holds), the contract-shape canary (D7), the account-deletion fan-out (D8: user-level GDPR Art. 17 path), the Node's own managed identity (D9: deferred to first deployable host), explicit boundaries against Auth / Audit / Tenant Lifecycle / Communications / Notify / Vault / external IdP (D10), the charter sanity check (D11), the phased rollout (D12), and the relationships to existing ADRs (D13). None of that has been built — the `HoneyDrunkStudios/HoneyDrunk.Identity` repo does not exist yet.

Four packets land the work:

1. **Architecture catalog registration** — `honeydrunk-identity` registered in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json` (6 interfaces + 7 records per D4), `catalogs/grid-health.json`, and `catalogs/modules.json`. Identity row added to `constitution/sectors.md` Core sector. New `repos/HoneyDrunk.Identity/` context folder (overview/boundaries/invariants/active-work/integration-points) matching the Audit/Operator template. Additive amendment on ADR-0050 (IdentityMap relocates from `HoneyDrunk.Auth.IdentityMap` to `HoneyDrunk.Identity.IdentityMap` per D3 — D6 architectural posture unchanged). Additive amendments on `repos/HoneyDrunk.Auth/overview.md` and `boundaries.md` (validation-only clarification; user-record-ownership pointer to Identity). Initiative + Q2 2026 roadmap bullet registered.
2. **Constitution invariants** — four new invariants from D1/D6/D13/D7 added to `constitution/invariants.md` at numbers **54, 55, 56, 57** (next four free slots above the current high-water mark of 53). New `## Identity Invariants` section. 54 = user-record ownership; 55 = internal-token issuance exclusivity; 56 = downstream Abstractions-only coupling; 57 = Identity contract-shape canary. ADR-0060 Consequences `### Invariants` subsection finalized with the assigned numbers. `repos/HoneyDrunk.Identity/invariants.md` placeholders substituted. Packet 04 source-file placeholders substituted pre-push (invariant 24's pre-filing carve-out).
3. **Create HoneyDrunk.Identity GitHub repo (human-only)** — create the public repo on `HoneyDrunkStudios`, apply branch protection, seed labels, configure OIDC federated credential, clone locally. Same shape as `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md` — create-and-configure, not verify-and-clone (the Identity repo was not pre-created during ADR-0060 drafting).
4. **HoneyDrunk.Identity scaffold** — empty repo to first-shippable v0.1.0 state per D12 Phase 1. Solution, two packages (`Abstractions` + runtime), six interfaces + seven records + two enums + `UserRecord`, runtime impls (`DataUserDirectory`, `DataUserProfileStore`, `JwksInternalTokenIssuer`, `EventBasedIdentityDeletionFanout`, `DefaultIdentityHealth`), Data-backed user-record / IdentityMap / ExternalSubjectMap / UserProfile entities, `IdentityOptions` bound via `IConfigProvider`, in-memory test fixtures (five `internal sealed` classes), end-to-end smoke test (signup → claim mapping → user record → token issuance → round-trip), full CI including the D7 contract-shape canary scoped to `HoneyDrunk.Identity.Abstractions`, READMEs/CHANGELOGs per package. **No Entra adapter, no OAuth callback HTTP surface, no full deletion fan-out workflow, no IdentityMap relocation from Auth, no Container App / managed identity / Key Vault provisioning** — all Phase 2/3 follow-ups.

## Wave Diagram

```
Wave 1: Architecture catalog + invariants + create-repo (partially parallel)
   ├─ Architecture: 01-architecture-identity-catalog-registration
   │     Blocked by: none (foundation of the initiative).
   ├─ Architecture: 02-architecture-identity-invariants
   │     Blocked by: packet 01 (needs `repos/HoneyDrunk.Identity/invariants.md`
   │                  placeholders in place to substitute; needs `## Audit Invariants`
   │                  predecessor section settled).
   └─ Architecture: 03-architecture-create-identity-repo  (human-only)
         Blocked by: packet 01 (catalog must register `honeydrunk-identity` and
                     create `repos/HoneyDrunk.Identity/` first).

Wave 2: HoneyDrunk.Identity scaffold
   └─ HoneyDrunk.Identity: 04-identity-node-scaffold
         Blocked by: packet 01 (catalog + context folder + ADR-0050/Auth amendments
                                 must be on main)
                     packet 02 (invariant numbers must be assigned and substituted
                                pre-filing into this packet's source)
                     packet 03 (GitHub repo must exist; local working tree must be cloned)
```

In practice packets 01 and 03 can be filed in the same push (packet 01 is agent; packet 03 is human-only; they target different work surfaces). Packet 02 must wait for packet 01 to merge so the `repos/HoneyDrunk.Identity/invariants.md` file exists. Packet 04 cannot be filed until packet 02's PR is merged (so the assigned invariant numbers can be substituted into packet 04's `{N-*}` placeholders pre-push).

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Register HoneyDrunk.Identity in Architecture catalogs, sectors, context folder, and ADR-0050/Auth amendments](./01-architecture-identity-catalog-registration.md) | Architecture | 1 | Agent | none |
| 02 | [Add ADR-0060's four new invariants to the Grid constitution (default 54-57)](./02-architecture-identity-invariants.md) | Architecture | 1 | Agent | 01 |
| 03 | [Create `HoneyDrunkStudios/HoneyDrunk.Identity` public repo, branch protection, labels, OIDC, clone locally (human-only)](./03-architecture-create-identity-repo.md) | Architecture (tracking issue) | 1 | Human | 01 |
| 04 | [Stand up `HoneyDrunk.Identity` — solution, two packages, six interfaces + seven records, in-memory fixtures, smoke test, CI with canary](./04-identity-node-scaffold.md) | HoneyDrunk.Identity | 2 | Agent | 01, 02, 03 |

## Phase Mapping (ADR-0060 "If Accepted" checklist → packets)

ADR-0060's "If Accepted — Required Follow-Up Work" checklist, mapped to packets:

| Checklist item | Packet |
|---|---|
| Create the `HoneyDrunk.Identity` GitHub repo as **public** | packet 03 |
| Add `honeydrunk-identity` Node entry to `catalogs/nodes.json` | packet 01 |
| Add `honeydrunk-identity` entries to `catalogs/relationships.json` (consumes / consumed_by_planned / consumes_detail) | packet 01 |
| Add the D4 contracts to `catalogs/contracts.json` under `honeydrunk-identity` | packet 01 |
| Add `honeydrunk-identity` row to `catalogs/grid-health.json` | packet 01 |
| Add `honeydrunk-identity` entries to `catalogs/modules.json` for `HoneyDrunk.Identity.Abstractions` and `HoneyDrunk.Identity` | packet 01 |
| Update `constitution/sectors.md` Core-sector table to add the Identity row | packet 01 |
| Author the additive amendment note on `adrs/ADR-0050-...` (IdentityMap relocation) | packet 01 |
| Author the additive amendment note on `repos/HoneyDrunk.Auth/` context files | packet 01 |
| Wire the contract-shape canary into Actions for the frozen surfaces | packet 04 (CI file inside HoneyDrunk.Identity, not in HoneyDrunk.Actions — the reusable workflow already exists per `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml`) |
| Create `repos/HoneyDrunk.Identity/` context folder in the Architecture repo | packet 01 |
| File the HoneyDrunk.Identity scaffold packet | packet 04 |
| Scope agent flips Status → Accepted after the first packet declaring this ADR in `accepts:` merges | scope-agent housekeeping (happens automatically after this initiative's packets are filed and merge — see Notes below) |

Each packet carries `accepts: ADR-0060` so the hive-sync agent's auto-flip mechanic recognizes the initiative as the ADR's acceptance work.

## What This Initiative Does NOT Deliver

The following are explicitly out of scope for this initiative. Each becomes a separate packet at the appropriate time:

- **The Entra External ID adapter (`IExternalIdpClaimMapper` implementation).** Per ADR-0060 D2, the IdP-vendor confirmation lands in the **first feature packet** (when Hearth, Lately, or Curiosities pulls on Identity). v0.1.0 ships only the in-memory test fixture. The vendor choice (Entra vs. Clerk vs. Auth0 vs. Supabase vs. self-hosted) is re-evaluated at the Phase-2 packet's scoping; the wrapping-seam architecture ensures the choice is bounded.

- **The OAuth callback HTTP surface, JWKS endpoint, `/users/me` surface, OAuth 2.1 PKCE flow handler.** Per ADR-0060 D12 Phase 2/3, those are deployable-host concerns. v0.1.0 is library-shaped — no HTTP server, no public endpoints. The deployable host (Container App `ca-hd-identity-{env}`) lands in a Phase 2/3 packet.

- **The full account-deletion fan-out workflow.** Per ADR-0060 D8 / D12 Phase 3, the full per-consumer ack-collection workflow + IdentityMap relocation from `HoneyDrunk.Auth.IdentityMap` to `HoneyDrunk.Identity.IdentityMap` + the Studios admin-console pages land in Phase 3. v0.1.0 ships the `IIdentityDeletionFanout.EraseAsync` boundary + in-memory test loop + a single Communications `DeletionIntent` emission.

- **The Identity Node's own managed identity (Azure provisioning).** Per ADR-0060 D9, the Node runs under its own dedicated managed identity, distinct from Auth's, Audit's, and Operator's. **HoneyDrunk.Identity at Phase 1 is a library Node** — both `Abstractions` and runtime are library packages. The managed identity, Key Vault `kv-hd-identity-{env}`, Container App `ca-hd-identity-{env}`, and the App Configuration namespace for `Identity:*` belong with whichever packet first deploys an Identity-composing host (Phase 2/3). Same precedent as ADR-0016 (AI) and ADR-0031 (Audit) — library Nodes defer Azure provisioning until first composition in a deployable host.

- **App Configuration seeding for `Identity:*` keys.** Per ADR-0060 D6 the signing-key reference + token TTL + issuer + audience + signing algorithm are sourced via `IConfigProvider`. Seeding the actual values in Azure App Configuration is a deploy-time concern carried by the first consuming deployable, not by this scaffold. The scaffold ships the read path and sensible startup defaults if the keys are unset.

- **Key Vault seeding for the internal-token signing key.** Per ADR-0060 D9, the signing key lives in `kv-hd-identity-{env}`. Provisioning the Vault namespace and seeding the key happen with the Phase-2/3 deployable-host packet. v0.1.0's `JwksInternalTokenIssuer` reads via `ISecretStore` — that path works against the in-memory secret-store fixture for tests and against a real Vault when the host wires one.

- **SonarCloud onboarding for HoneyDrunk.Identity.** Follows the pattern from `generated/issue-packets/active/adr-0011-code-review-pipeline/06-kernel-sonarcloud-onboarding.md`. Separate follow-up packet, post-`v0.1.0`. Flagged in packet 04's Human Prerequisites.

- **OpenClaw/Codex reviewer onboarding for HoneyDrunk.Identity.** Per ADR-0044 D1, a repo is `enabled` for the cloud-wired review agent when it carries a `.honeydrunk-review.yaml` with `enabled: true`. Separate follow-up packet, post-`v0.1.0`. Flagged in packet 04's Human Prerequisites.

- **Grid-health aggregator wiring** for the new repo: if `HoneyDrunk.Actions/.github/workflows/grid-health-aggregator.yml` auto-discovers from `catalogs/nodes.json`, packet 01's edit is sufficient. If not, packet 04's Human Prerequisites flag a small follow-up to add `HoneyDrunk.Identity` to the watched-repos list. Confirm which behavior is in place at execution time.

- **Hearth signup-flow feature packet.** Per ADR-0060 D12 Phase 2, the first user-facing app's signup flow lands the IdP-vendor confirmation and the first concrete `IExternalIdpClaimMapper`. That packet belongs to Hearth's bring-up initiative, not this one.

- **IdentityMap relocation from `HoneyDrunk.Auth` to `HoneyDrunk.Identity`.** Per ADR-0060 D3 + D12 Phase 3, the table relocation is a Phase-3 concern. The ADR-0050 amendment (landed by packet 01) records the intent in the catalogs and the ADR text; the actual table move happens in a Phase-3 packet that coordinates Auth's existing IdentityMap-related code with Identity's new home.

## Cross-ADR Invariant Numbering — Coordination Honored

The default assignment for this initiative's four constitutional invariants is **54, 55, 56, 57** (next four free slots above the current high-water mark of 53 — set by ADR-0044's invariants 52 and 53). Packet 02 of this initiative runs a `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20` collision check at edit time and assigns whatever the actual next four free slots are.

**Collision pre-claims to be aware of (do not block on, but check):**

- **In-flight AI-sector standups** (ADR-0020 Agents, ADR-0021 Knowledge, ADR-0022 Memory, ADR-0023 Evals, ADR-0024 Flow, ADR-0025 Sim) — each carries its own invariant-numbering packet that may land between this scoping and packet 02's edit time. If any AI-sector packet lands first and claims 54-57 (or part of it), this initiative's four entries shift up together.

**Filing-order rule (hard):**

1. Push packet 01 (and packet 03 — human-only — can travel in the same push; both target Architecture and touch different surfaces).
2. Wait for packet 01's PR to merge.
3. Push packet 02. Wait for it to merge so the assigned numbers actually land in `constitution/invariants.md`.
4. Wait for packet 03's chore issue to be Done so the public repo exists, branch protection is applied, labels are seeded, OIDC is wired, and the local working tree exists.
5. **Substitute the actual assigned numbers** for `{N-ownership}` / `{N-issuance}` / `{N-coupling}` / `{N-canary}` in `04-identity-node-scaffold.md` source file in place pre-push (invariant 24's pre-filing carve-out applies; packet 04 has not been filed yet).
6. Push packet 04.

Packet 04 cannot be filed before packets 01, 02, 03 are all merged/Done, and the invariant-number substitution is complete.

## Asymmetry vs ADR-0031 Audit / ADR-0018 Operator standups

Three deliberate asymmetries are worth recording:

1. **Two packages, not three.** Audit ships `Abstractions` + `Data` (two — backing-slot naming). Operator ships `Abstractions` + runtime + `Testing` fixture (three — ADR-0017 pattern). Identity ships **two**: `HoneyDrunk.Identity.Abstractions` and `HoneyDrunk.Identity` (bare-runtime, not a backing slot). No provider-axis packages — the IdP-vendor slot is an injection point on `IExternalIdpClaimMapper`, not a separate package. No `Testing` package at stand-up (ADR-0027 D3 precedent followed — internal fixtures, cut to a `Testing` package later as non-breaking when a third consumer needs it).

2. **`HoneyDrunk.Identity` is a bare runtime, NOT a backing-slot name.** Per ADR-0060 D4 the contracts are storage-agnostic; the runtime uses `IRepository<...>` via `HoneyDrunk.Data.Abstractions` for persistence. A future alternative backing is not a sibling package — the data layer is abstracted via Data's existing pattern. This differs from Audit (where `HoneyDrunk.Audit.Data` is the backing slot and a future `HoneyDrunk.Audit.Cosmos` would be a sibling slot).

3. **All six interfaces + seven records frozen at stand-up, not a hot subset.** Per ADR-0060 D4 + D7, the public surface is exactly six interfaces and seven records (plus the supporting `UserRecord` record and enums); all of them are on the hot path for the first user-facing app. The canary covers the whole Abstractions surface from v0.1.0. Same posture as Audit's "all three contracts frozen, not four-of-N hot subset."

4. **Identity is upstream of Audit, Auth, Communications, Data, Vault.** Identity consumes all five. The DAG direction is unambiguous: `identity → audit`, `identity → auth`, `identity → communications`, `identity → data`, `identity → vault`, `identity → kernel`. No reverse edges. Specifically: Identity is **not** a downstream consumer of Operator (the AI-sector control plane); Identity is upstream of human-policy enforcement.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND `HoneyDrunk.Identity 0.1.0` is published to NuGet, the entire `active/adr-0060-identity-standup/` folder moves to `archive/adr-0060-identity-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done`.

## Notes

- **Why packet 03 is its own item.** The `HoneyDrunk.Identity` GitHub repo does not exist yet. Creation is org-admin only (Org-owner role on `HoneyDrunkStudios`) — it cannot be delegated to an agent. Surfacing it as a Wave-1 work item with `Actor=Human` keeps it visible on The Hive board as a blocker on packet 04 instead of being a hidden prereq buried in the scaffold packet's body. Same shape as `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md`.

- **Why the scaffold packet keeps the in-memory fixtures internal.** ADR-0027 D3 is the precedent (Communications), followed by ADR-0031 (Audit). The fixtures live at `tests/HoneyDrunk.Identity.Tests/Fixtures/` with `internal` visibility. The first user-facing consumer (Hearth in Phase 2) writes its own narrowly-scoped test double; when a third consumer needs the fixtures, they cut into a `HoneyDrunk.Identity.Testing` package as a non-breaking change.

- **Why all six interfaces + seven records are frozen in the canary.** ADR-0060 D7: every contract is on the hot path for the first user-facing app's signup flow. There is no low-traffic remainder to leave un-frozen; freezing all of them from the first scaffold costs nothing and removes the "which one slipped through" failure mode. Packet 04's CI scopes the api-compatibility canary to the `HoneyDrunk.Identity.Abstractions` assembly — the whole-assembly diff covers all of them.

- **Status flip happens after merge, not now.** ADR-0060 stays Proposed for this scoping run. The user's standing workflow says the scope agent flips Status → Accepted after the follow-up PRs merge. None of the four packets here flip ADR-0060's Status — that is a separate housekeeping step the scope agent handles when the initiative completes.

- **`accepts: ADR-0060` frontmatter.** Every packet in this initiative carries `accepts: ADR-0060` so the hive-sync agent's auto-flip mechanic recognizes the initiative as the ADR's acceptance work. Per user constraint, this is mandatory and is checked at filing.

- **Repo is public by default.** Per memory `project_repos_public_by_default`, HoneyDrunk repos are public unless a revenue/compliance/experiment carve-out applies. Identity is identity-layer code, not credential storage (per ADR-0060 D2 the credential store lives in the external IdP). No carve-out applies. Packet 03's portal step specifies Visibility = Public.

- **No ADR numbers in user-facing docs or code comments.** Per memory `feedback_no_adr_in_docs`, the scaffold's README and per-package READMEs do **not** cite "ADR-0060" by number in their narrative — the README explains what the package does. Runtime / packet-data references (catalog entries, frontmatter, this dispatch plan, the CHANGELOG, ADR text itself) are fine to cite ADRs by number.

- **No commits under CHANGELOG Unreleased.** Per memory `feedback_no_unreleased_commits`, the scaffold's first commit lands under `## [0.1.0] - YYYY-MM-DD`, not under `## Unreleased`. The tag push happens after merge.

- **No manual packet filing.** Per memory `feedback_no_manual_packet_filing`, file-packets.yml auto-files on push to main. Do not run `gh issue create` against these packets. Filing happens by pushing the packet files into `generated/issue-packets/active/adr-0060-identity-standup/`. The filing-order rule above governs which packets land in which push.

- **Identity edge direction (unambiguous).** Throughout this initiative, Identity is **upstream** of every Node it consumes. `HoneyDrunk.Identity` references `HoneyDrunk.Audit.Abstractions`, `HoneyDrunk.Auth.Abstractions`, `HoneyDrunk.Data.Abstractions`, `HoneyDrunk.Vault`, `HoneyDrunk.Communications.Abstractions`, `HoneyDrunk.Kernel.Abstractions`. None of those reference any `HoneyDrunk.Identity.*` package. The DAG stays acyclic. Future downstream consumers (Hearth, Lately, Curiosities, Notify.Cloud) will reference `HoneyDrunk.Identity.Abstractions`.

- **ADR-0050 amendment is additive, not a rewrite.** Packet 01 appends a new `## Amendment — 2026-05-23 (driven by ADR-0060 standup)` section to ADR-0050; it does not modify D6's architectural posture or ADR-0050's `Status:` line. Only the Node owning the IdentityMap relocates from `HoneyDrunk.Auth.IdentityMap` to `HoneyDrunk.Identity.IdentityMap`. The pseudonymization model, the legal posture (Art. 4(5) carve-out), and the audit-substrate invariants are unchanged.

- **Auth context amendments are additive, not a rewrite.** Packet 01 appends one sentence to `repos/HoneyDrunk.Auth/overview.md`'s Purpose section and one bullet to `repos/HoneyDrunk.Auth/boundaries.md`'s "What Auth Does NOT Own" list. The existing text — including the "it is not an identity provider" line and the "User management — No user CRUD, registration, or profiles" bullet — stays.

## Filing

The `file-packets.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/issue-packets/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.
