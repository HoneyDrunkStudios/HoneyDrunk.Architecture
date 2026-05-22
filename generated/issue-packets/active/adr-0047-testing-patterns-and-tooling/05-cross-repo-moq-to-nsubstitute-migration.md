---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
target_repos: []
labels: ["chore", "tier-2", "coordination", "adr-0047", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0047"]
accepts: ["ADR-0047"]
wave: 1
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-architecture
---

# Migrate every Node's test projects from Moq to NSubstitute (per-Node issues)

## Summary
Replace the `Moq` mocking library with `NSubstitute` across every Node repo's test projects. Unlike the FluentAssertions migration (packet 04), this is **not** a drop-in change — Moq's lambda-based `Setup`/`Verify` API maps to NSubstitute's property-based `Returns`/`Received` API, so each test file's mock usages must be rewritten. Per ADR-0047 D14 the `file-issues` agent files **one independent issue per Node repo**; each per-Node migration runs and merges independently.

## Affected Repos (one independent issue per repo at filing time)
Every Node repo that currently references Moq in a test project. The `file-issues` agent fans this packet out per-repo at filing time.

**Derive the fan-out set from an actual grep, not this prose list.** At filing time the `file-issues` agent must run a real search across the workspace repos for `Moq` `PackageReference` entries and `using Moq;` directives (e.g. `grep -rl 'Moq' --include='*.csproj' --include='*.cs'` per cloned repo, then confirm hits are the mocking library and not a substring) and file one issue per repo with a hit. The prose candidate set below is an indicative starting point only — every .NET Node in `catalogs/nodes.json` with existing test projects (Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Actions's .NET test projects, and `HoneyDrunk.Standards`) — but the grep result is authoritative. Do not hand-maintain this list as the source of truth; a repo with zero Moq hits gets no issue.

**Each per-Node issue is independent** — there is no ordering between them, they may all run in parallel, and a failure in one does not block another. They share only the upstream dependency on packet 01 (the shared props fragment that declares `NSubstitute`).

## Motivation
ADR-0047 D2: "NSubstitute as the mocking library. Not Moq. Moq's August 2023 SponsorLink incident … damaged stewardship trust meaningfully. … NSubstitute is the community's pragmatic answer — clean API, active maintenance, no stewardship drama." ADR-0047 D14: "The Moq migration is the larger lift … the `scope` agent can author per-Node migration packets that batch the changes." ADR Consequences: "Per-Node effort is bounded but non-trivial."

The trust cost of staying on Moq compounds with every release; the migration cost is paid once. This packet pays it.

## Change Plan
Per repo:
1. Remove every `<PackageReference Include="Moq" ... />` from `*.Tests.*` `.csproj` files; adopt the packet-01 test-stack props fragment (which declares `NSubstitute`) or add `<PackageReference Include="NSubstitute" ... />` directly. Prefer the fragment.
2. Rewrite every Moq usage to the NSubstitute equivalent. The mechanical mapping (from ADR-0047 D14 and the Consequences section):
   - `new Mock<IFoo>()` → `Substitute.For<IFoo>()`
   - `mock.Object` → the substitute itself (NSubstitute substitutes are the interface, not a wrapper)
   - `mock.Setup(x => x.Method()).Returns(value)` → `sub.Method().Returns(value)`
   - `mock.Setup(x => x.Method()).ThrowsAsync(ex)` → `sub.Method().Returns(Task.FromException(ex))` or `sub.When(x => x.Method()).Do(_ => throw ex)`
   - `It.IsAny<T>()` → `Arg.Any<T>()`
   - `It.Is<T>(predicate)` → `Arg.Is<T>(predicate)`
   - `mock.Verify(x => x.Method(), Times.Once)` → `sub.Received(1).Method()`
   - `mock.Verify(x => x.Method(), Times.Never)` → `sub.DidNotReceive().Method()`
   - `mock.SetupSequence(...)` → `sub.Method().Returns(a, b, c)` (multiple-value overload)
3. Update `using Moq;` directives to `using NSubstitute;`.
4. Build and run the full test suite. Every test must pass with equivalent behavior — a mock rewrite that changes a test outcome is a defect, not a migration.
5. Confirm no `Moq` reference remains anywhere in the repo.

## Contracts Affected
None. Mocking-library choice is test-internal; no runtime contract, no `catalogs/contracts.json` change.

## NuGet Dependencies
Per affected test project:
- **Remove:** `Moq`.
- **Add (or inherit from packet-01 fragment):** `NSubstitute` — current stable.
No runtime `.csproj` is touched (test projects only — invariant 16). No new project is created.

## Cascade Validation
- [ ] No runtime package version bump — test-project-only; test projects are excluded from the solution version (invariant 27).
- [ ] No circular dependency introduced (mocking library is a leaf test dependency).
- [ ] Canary projects: if a canary uses Moq, migrate it too.

## Acceptance Criteria
- [ ] No `Moq` `PackageReference` remains in any test project in the repo
- [ ] `NSubstitute` is referenced (preferably inherited from the packet-01 test-stack props fragment)
- [ ] Every Moq usage rewritten to its NSubstitute equivalent per the mapping above
- [ ] All `using Moq;` directives updated to `using NSubstitute;`
- [ ] Full test suite builds and passes — every migrated test verifies the same behavior it verified under Moq
- [ ] No test outcome changed by the migration (a changed outcome is a defect — investigate, do not paper over)
- [ ] Repo-level `CHANGELOG.md`: a line under the in-progress version entry noting the test-tooling migration (invariant 12) — test-only change, no runtime version bump, record as tooling/chore
- [ ] No per-package `CHANGELOG.md` change for runtime packages; no README change
- [ ] CI green

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D2 — NSubstitute, not Moq.** The 2023 SponsorLink incident (undisclosed build-time telemetry scraping developer git-config emails) damaged Moq's stewardship trust. NSubstitute provides equivalent capability with cleaner stewardship history. "Migrating from Moq to NSubstitute is mechanical (different syntax but equivalent capability)."

**ADR-0047 D14 — Phased rollout.** "The Moq migration is the larger lift and may run in parallel with Phase 1 rather than blocking it. … the `scope` agent can author per-Node migration packets that batch the changes."

**ADR-0047 Consequences — operational.** "Syntax change, not drop-in — `mock.Setup(...).Returns(...)` becomes `sub.Method().Returns(...)`; `It.IsAny<T>()` becomes `Arg.Any<T>()`; `Verify` becomes `Received`. Per-Node effort is bounded but non-trivial."

## Constraints
- **Test projects only.** Do not touch runtime `.csproj` (invariant 16).
- **No solution version bump.** Test projects are excluded from the solution version (invariant 27); no release triggered.
- **Behavior must not change.** This is a syntax migration. If a rewritten test changes outcome, the rewrite is wrong — investigate, do not adjust the assertion to make it pass.
- **`Received`/`DidNotReceive` semantics differ subtly from Moq `Verify`.** NSubstitute records calls as they happen; `Received(1)` checks the call count at assertion time. Watch for tests that relied on Moq's `Verifiable()`/strict-mock behavior — those need explicit `Received`/`DidNotReceive` assertions.
- **Prefer adopting the packet-01 props fragment** over a local `NSubstitute` reference.
- **One repo per issue.** Do not batch multiple repos into one PR — the `file-issues` agent files these as independent per-Node issues.

## Labels
`chore`, `tier-2`, `coordination`, `adr-0047`, `wave-1`

## Agent Handoff

**Objective:** Replace Moq with NSubstitute across the target repo's test projects, rewriting every mock usage per the Moq→NSubstitute API mapping, with no change to any test's verified behavior.

**Target:** The per-repo target assigned at filing time (one independent issue per Node repo with Moq usage), branch from `main`.

**Context:**
- Goal: Move off Moq (compromised stewardship) to NSubstitute; converge on the shared test stack.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 1.
- ADRs: ADR-0047 (D2, D14).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:01 — the shared test-stack props fragment declares `NSubstitute`. Sequence after 01. No dependency on other per-Node Moq-migration issues — they are mutually independent and may run in parallel.

**Constraints:**
- Test projects only — never touch runtime `.csproj` (invariant 16).
- No solution version bump (invariant 27).
- Behavior must not change — a changed test outcome is a defect.
- Watch `Received`/`DidNotReceive` semantics vs Moq `Verify`/strict mocks.
- Prefer adopting the packet-01 fragment over a local reference.

**Key Files:**
- `*.Tests.*` `.csproj` files in the target repo.
- Test source files with `using Moq;` / `Mock<T>` / `It.IsAny` / `.Verify(`.
- `CHANGELOG.md` (repo-level — tooling/chore entry).

**Contracts:** None changed.
