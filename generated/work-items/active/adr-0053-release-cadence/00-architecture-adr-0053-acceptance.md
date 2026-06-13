---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0053", "wave-1"]
dependencies: []
adrs: ["ADR-0053"]
accepts: ["ADR-0053"]
wave: 1
initiative: adr-0053-release-cadence
node: honeydrunk-architecture
---

# Accept ADR-0053 — flip status, add the three environments/branching/cadence invariants, register the initiative

## Summary
Flip ADR-0053 (Environments, Branching, and Release Cadence) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new operational invariants ADR-0053 commits in its Consequences/Invariants section to `constitution/invariants.md` (numbered **{N1}, {N2}, {N3}** — claim the next free contiguous block of size 3 from `constitution/invariant-reservations.md` at edit time), and register the `adr-0053-release-cadence` initiative in `initiatives/active-initiatives.md`.

**Required ADR-0053 D2 amendment (separate follow-up, NOT in this packet):** packet 02 honors the existing `rg-hd-platform-*` / `kv-hd-*` naming convention rather than the `rg-honeydrunk-*` shape ADR-0053 D2's prose proposes. The existing convention wins because it is deployed on live resources. ADR-0053 D2's text needs a follow-up amendment to reflect the existing convention, OR a separate amendment packet is authored alongside packet 02's merge. Record the chosen path in packet 02's PR body; do not amend ADR-0053 in this packet.

## Context
ADR-0053 closes the load-bearing gap behind ADR-0011 (review), ADR-0015 (Container Apps), ADR-0032 (PR validation), ADR-0033 (env-gated deploys), and ADR-0044 (AI-PR discipline) — none of those ADRs ever named the environments they presume, the branching model they assume, or the release cadence they trigger. ADR-0053 commits all three.

The ADR decides:

- **D1** — three always-on environments (`dev`, `staging`, `prod`). No per-PR ephemerals at v1; reconsider at v2 when Notify Cloud's tenant-portal UI work begins or multiple humans review in parallel.
- **D2** — Azure resource-group and resource naming: `rg-honeydrunk-{env}-{region}`; `{node}-{env}-{purpose}`; storage `hd{node}{env}{region}{shortrand}`; Key Vaults per ADR-0005 (`kv-{node}-{env}-{region}`). Region default `eastus`; multi-region deferred behind ADR-0036.
- **D3** — single Azure subscription with environment-level RBAC at v1; subscription split (`sub-honeydrunk-prod` vs `sub-honeydrunk-nonprod`) deferred to v2 when the first paying tenant lands per PDR-0002 / ADR-0050.
- **D4** — trunk-based branching with short-lived feature branches; no GitFlow `develop` / `release/*` / `hotfix/*` channels; `release/{node}-{semver}` allowed only for emergency hotfix isolation when `main` is mid-feature.
- **D5** — branch-naming convention: human prefixes `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`; AI prefixes `codex/`, `copilot/`, `claude/{agent-slug}-{token}`.
- **D6** — branch lifetime: 5-day target, 7-day stale alert (no auto-close), 30-day auto-close unless `flagged-keep-open`.
- **D7** — merge strategy: squash by default; merge commits for release branches only; never rebase-merge.
- **D8** — promotion model: `main` → `dev` auto on every merge → `staging` via `staging-{date}` tag → `prod` via `prod-{date}` tag (ADR-0033); same artefact promotes through every environment; soak windows 24h standard / 4h hotfix / 72h schema-contract.
- **D9** — release cadence: per-Node, release-as-needed; monthly floor enforced by "at least one prod release in the past 30 days OR an explicit 'no changes this month' CHANGELOG entry" per Live Node; hotfix tags `prod-{date}-hotfix-{short-slug}`; even hotfixes get a staging step.
- **D10** — versioning: SemVer per Node per ADR-0035; conventional commits per ADR-0044 D4; release-notes generation script deferred.
- **D11** — local-dev parity: every Node boots with `dotnet run` against InMemory (invariant 15) or Testcontainers (ADR-0047 D4) dependencies; "first 60 seconds" rule per `repos/{name}/overview.md`'s `## Quick Start`.
- **D12** — configuration parity: env-specific config in Azure App Configuration per ADR-0005, secrets in Key Vault, no hardcoded `if (Environment == "prod")` switches in business logic.
- **D13** — data parity: **production data MUST NEVER copy to `dev` or `staging`** — no exceptions, no "anonymized for debugging," no carve-outs.
- **D14** — rollback story: traffic-shift instant rollback for application code (ADR-0015 multi-revision); NuGet rollback via forward patch (ADR-0035 immutability); schema rollback forward-only after the contract phase begins (ADR-0048 expand/contract).
- **D15** — approvals: v1 passing CI + self-approval comment on the deploy PR for prod; v2 transitions to a true two-party gate when a second human joins; AI agents are not approvers, ever.
- **D16** — phased rollout: Phase 1 Bicep modules; Phase 2 Actions deploy workflows; Phase 3 Notify/Pulse Azure bring-up uses the new pattern; Phase 4 branch-lifetime tooling; Phase 5 local-dev parity audit; Phase 6 monthly CHANGELOG cadence; Phase 7 subscription split when paying tenant lands.

ADR-0053 is a **policy / topology** ADR. The concrete code/YAML/Bicep/walkthroughs land in this initiative's packets 01–08; the AzureBicep, the Actions workflows, the per-Node `## Quick Start` audit, and the monthly cadence enforcement workflow are all decomposed below.

Every other packet in this initiative references ADR-0053's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0053-environments-branching-and-release-cadence.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0053 row Status column to Accepted.
- `constitution/invariants.md` — add the three new operational invariants ADR-0053 commits (see Proposed Implementation for exact text) as **invariants {N1}, {N2}, {N3}** — read `constitution/invariant-reservations.md`, claim the next free contiguous block of size 3 in the **Active Reservations** table, and use those numbers (see Constraints).
- `constitution/invariant-reservations.md` — add a row to **Active Reservations** in the same PR that records the block claimed for ADR-0053.
- `initiatives/active-initiatives.md` — register the `adr-0053-release-cadence` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0053 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0053 index row in `adrs/README.md` to Accepted.
3. **Claim the invariant number block.** Open `constitution/invariant-reservations.md` and read the **Active Reservations** table plus the **Currently Accepted** high-water mark. Today's high-water mark on disk is **53**; the "next free" pointer is **54** unless another in-flight ADR has filed a reservation that consumed it. Pick the next contiguous free block of **size 3** above the highest reservation. Call those numbers `{N1}, {N2}, {N3}` for the rest of this packet's edits. Add a row to **Active Reservations** in this same PR recording the claim:
   ```
   | {N1}–{N3} | ADR-0053 | Proposed→Accepting | packet 00 of adr-0053-release-cadence |
   ```
4. Add three new invariants to `constitution/invariants.md` as **invariants {N1}, {N2}, {N3}** with the numbers chosen in step 3. The text, taken verbatim-in-substance from ADR-0053's Consequences "Invariants" subsection:
   - **{N1}. Production data MUST NEVER copy to `dev` or `staging`.** Synthetic fixtures only in lower environments; real customer data only in `prod`. No anonymization carve-out, no subsetting carve-out, no "for debugging a one-off" carve-out. Per-Node seeders generate volume-realistic synthetic data where load matters (Bogus + AutoFixture per ADR-0047 D7). Any tooling that attempts a prod-to-lower-environment copy is itself an Audit-emitting event per ADR-0030; the audit trail catches accidental violations. See ADR-0053 D13, ADR-0049.
   - **{N2}. Every Node boots locally with `dotnet run` against InMemory or Testcontainers dependencies; no Azure dependency is required for first-line development work.** First-60-seconds rule: `git clone && dotnet run` produces a running Node with no Azure provisioning step. Local secrets come from gitignored `.env` files loaded as environment variables; `HoneyDrunk.Vault` reads from env vars on the `local` profile per ADR-0005's env-var path. Each Live Node's `repos/{name}/overview.md` documents the path in a `## Quick Start` section. See ADR-0053 D11, ADR-0005, ADR-0047 D4.
   - **{N3}. Hardcoded environment-name switches in business logic are forbidden.** No `if (Environment == "prod") { ... }` branches in Node code; environment-dependent behavior is configuration-driven (Azure App Configuration per ADR-0005, keyed by environment label), not name-driven. Explicit exception: deployment workflows (`HoneyDrunk.Actions`) and bootstrap shims that read the environment label to choose the App Configuration endpoint are permitted. See ADR-0053 D12, ADR-0005.
   - Add them under a new `## Environment & Cadence Invariants` section (the file's sectioning convention groups invariants by topic — Dependency, Context, Secrets, Packaging, Testing, AI, Audit, Hosting, etc. Environment topology + branching + data-parity is a new cross-cutting topic and warrants its own section). Place it after the most-recent section per the file's current append order.
5. Register the initiative in `initiatives/active-initiatives.md` with the three-wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0053-environments-branching-and-release-cadence.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0053 header reads `**Status:** Accepted`
- [ ] The ADR-0053 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries an **Active Reservations** row for ADR-0053 claiming a contiguous size-3 block above the prior highest reservation
- [ ] `constitution/invariants.md` carries the three new operational invariants (production data never copies to lower environments; every Node boots locally with no Azure dependency; hardcoded environment-name switches in business logic are forbidden), numbered **{N1}, {N2}, {N3}** under a new `## Environment & Cadence Invariants` section, each citing ADR-0053, using the same block recorded in `invariant-reservations.md`
- [ ] `initiatives/active-initiatives.md` registers the `adr-0053-release-cadence` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)
- [ ] No `.csproj` version bump — Markdown-only

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0053 D1 — Three environments (`dev`, `staging`, `prod`).** Three always-on environments are the minimum that gives a real soak step without ritual overhead; no per-PR ephemerals at v1.

**ADR-0053 D11 — Local-dev parity.** Every Node boots with `dotnet run` against InMemory or Testcontainers dependencies; no Azure dependency required for first-line dev work; "first 60 seconds" rule documented per Node.

**ADR-0053 D12 — Configuration parity.** Environment-specific configuration lives in Azure App Configuration (per ADR-0005); no hardcoded `if (Environment == "prod")` switches in business logic.

**ADR-0053 D13 — Data parity (hardest no in the ADR).** Production data MUST NEVER copy to `dev` or `staging`. Not anonymized; not subsetted; not for "debugging a one-off"; never. Synthetic fixtures only in lower environments.

**ADR-0053 Consequences — Invariants.** ADR-0053 adds exactly three invariants: (1) production data MUST NEVER copy to `dev` or `staging`; (2) every Node boots locally with `dotnet run` against InMemory or Testcontainers; (3) hardcoded environment-name switches in business logic are forbidden.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** ADR-0053 leans on this throughout (the `.env` local-dev path, the Key Vault references per ADR-0005, the "no DSN in the workflow" pattern); the acceptance text re-grounds the invariant inline rather than citing it by number alone.

- **Acceptance precedes flip.** ADR-0053 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers come from `constitution/invariant-reservations.md`, not hardcoded.** The current verified maximum on disk in `constitution/invariants.md` is **53**. Read `constitution/invariant-reservations.md` at edit time; pick the next contiguous free block of size 3 above the highest existing reservation; record the claim in **Active Reservations** in the same PR; substitute the chosen numbers into every `{N1}/{N2}/{N3}` placeholder in this packet's edits. Do not renumber existing invariants. If a merge-time collision occurs (someone else's reservation lands first), `git pull`'s conflict on `invariant-reservations.md` triggers a shift-upward and a rewrite of the three placeholders before pushing.
- **New section.** The three invariants are cross-cutting operational rules; create a `## Environment & Cadence Invariants` section appended after the file's current last section rather than scattering the three across existing topical sections.
- **ADR-0053 D2 prose amendment is a follow-up, NOT this packet.** Packet 02 honors the existing `rg-hd-platform-*` convention rather than ADR-0053 D2's proposed `rg-honeydrunk-*` shape. A separate ADR-0053 prose-amendment packet (authored alongside packet 02's merge) reconciles the two; do not edit D2's text in this packet.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0053`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0053 to Accepted, add the three environments/branching/cadence invariants to `constitution/invariants.md`, and register the release-cadence initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0053 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 1.
- ADRs: ADR-0053 (primary), ADR-0008 (initiative/packet conventions), ADR-0005 (Vault/App Configuration), ADR-0015 (Container Apps), ADR-0033 (env-gated deploys), ADR-0035 (SemVer), ADR-0044 (AI-PR discipline), ADR-0047 (testing/local-dev parity), ADR-0049 (PII handling), ADR-0030 (Audit substrate).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0053 stays Proposed until this PR merges.
- Invariant numbers are claimed via `constitution/invariant-reservations.md`, not hardcoded. Current verified max on disk is **53**. Read the reservations file, pick the next contiguous size-3 block, record the claim in **Active Reservations** in this PR, and substitute the chosen `{N1}/{N2}/{N3}` placeholders throughout. Do not renumber existing invariants.
- ADR-0053 D2 prose amendment is a separate follow-up (alongside packet 02's merge), not this packet.

**Key Files:**
- `adrs/ADR-0053-environments-branching-and-release-cadence.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
