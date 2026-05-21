# Dispatch Plan: ADR-0032 PR Validation Policy — Coverage Gate & NuGet Flagging

**Date:** 2026-05-17
**Trigger:** ADR-0032 (Grid-Wide PR Validation Policy — Coverage Gate and NuGet Update Flagging) Proposed 2026-05-17 — scoped same day
**Type:** Multi-repo (Actions control-plane + per-repo backfill across ten test-bearing Nodes)
**Sector:** Meta (control-plane policy) + per-Node sectors (backfill)
**Site sync required:** No. ADR-0032 governs PR-validation mechanics; the Studios website does not surface coverage state or dependency freshness. Re-evaluate only if a public "Grid health / quality" surface is ever added.

**Rollback plan:**
- Packet 01 (coverage gate + NuGet summary) is additive to `pr-core.yml` / `pr/generate-summary`. Revert via `git revert`: the gate disappears, coverage returns to decorative, the ⚠️ outdated section disappears. No consumer breakage — consumers reference `pr-core.yml@main`, so a revert simply removes the gate on the next PR. `.github/coverage-baseline.json` files already seeded in consumer repos become inert (read by nothing) — harmless; delete at leisure.
- Packet 02 (`nightly-deps` grouped issue) is additive. Revert removes the issue-maintenance step; existing `📦 Outdated Dependencies` issues are left in place (close manually if abandoning). No data loss.
- Packets 03–12 (backfill) are test-only PRs per repo. Each reverts independently via `git revert` with zero runtime impact. Reverting a backfill PR re-trips D3 for that repo until re-applied — that is the intended signal, not a regression.
- No Azure resources, no secrets provisioned by this initiative (the post-merge ratchet uses the default `GITHUB_TOKEN` with job-scoped `contents: write`). Nothing to deprovision.

## Summary

ADR-0032 is one PR Validation Policy with two parts, both owned by the Actions CI/CD control plane and implemented once in the reusable workflows:

- **Part 1 — blocking coverage gate** (D1 patch ≥ 75% tunable; D2 no-regress vs. committed `.github/coverage-baseline.json`; D3 flat 70% absolute floor; skip-when-no-test-projects, skip rendered visibly).
- **Part 2 — non-blocking NuGet flagging** (D4 outdated never blocks; D5 ⚠️ PR-summary section; D6 single grouped `📦 Outdated Dependencies` issue per repo).

**Twelve packets across eleven repos, two waves:**

- **2 Actions packets** (Wave 1, parallel): `01` coverage gate + ⚠️ summary section (D1–D5), `02` `nightly-deps` grouped tracking issue (D6).
- **10 backfill packets** (Wave 2): one per test-bearing Node — Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Pulse, Notify, Communications (packets `03`–`12`). Each is a clearly-templated copy of the canonical Kernel packet (`03`) with repo-specific substitutions.

The Actions control-plane work (Wave 1) lands **before and independent of** the per-repo backfill (Wave 2): the gate must exist before "go green against the gate" and "seed the baseline" are meaningful. Wave 2 packets are each hard-blocked by packet 01 only (not by packet 02, not by each other) — they run fully in parallel once 01 merges.

## Repo-by-repo backfill breakdown

| Repo | Test project(s) found | Gate applies? | Backfill packet |
|------|----------------------|---------------|-----------------|
| HoneyDrunk.Kernel | `HoneyDrunk.Kernel.Tests` | Yes | `03` |
| HoneyDrunk.Transport | `HoneyDrunk.Transport.Tests` | Yes | `04` |
| HoneyDrunk.Vault | `HoneyDrunk.Vault.Tests` | Yes | `05` |
| HoneyDrunk.Vault.Rotation | `…Rotation.Tests` + `…Rotation.Canary` | Yes | `06` |
| HoneyDrunk.Auth | `HoneyDrunk.Auth.Tests` + `…Auth.Canary` | Yes | `07` |
| HoneyDrunk.Web.Rest | `…Web.Rest.Tests` + `…Web.Rest.Canary` | Yes | `08` |
| HoneyDrunk.Data | `HoneyDrunk.Data.Tests` + `…Data.Canary` | Yes | `09` |
| HoneyDrunk.Pulse | `HoneyDrunk.Pulse.Tests` | Yes | `10` |
| HoneyDrunk.Notify | `…Notify.Tests` + `…Notify.IntegrationTests` | Yes | `11` |
| HoneyDrunk.Communications | `HoneyDrunk.Communications.Tests` | Yes | `12` |
| HoneyDrunk.Actions | none (no .NET solution / no test projects) | **No — gate skips** | — (no backfill) |
| HoneyDrunk.Architecture | none (docs/catalog repo) | **No — gate skips** | — (no backfill) |
| HoneyDrunk.Studios | no .NET tests; no JS test config found | **No — gate skips** | — (no backfill) |
| HoneyDrunk.Lore | no test projects | **No — gate skips** | — (no backfill) |

Ten test-bearing repos → ten backfill packets. Four cataloged repos have no test projects and are explicitly **unaffected** by the gate (it skips them with a visible `Coverage gate: skipped (no test projects)` line — no backfill, no packet, no red state).

**Current-coverage determination — assumption (applies to all of `03`–`12`).** The coverage gate and the `.github/coverage-baseline.json` mechanism do not exist yet (they ship in packet 01), and **no committed coverage artifact (`Summary.json`, baseline file) exists in any workspace repo today**. Therefore the **exact current line coverage of every test-bearing repo could not be measured at scope time**. Each backfill packet's Step 1 is "measure with `dotnet test --collect:"XPlat Code Coverage"` + ReportGenerator under the Grid filter `-assemblyfilters:+*;-*.Tests`"; the size of each backfill is whatever the measured gap to 70% turns out to be. A repo already ≥ 70% does not make its packet a no-op — the packet still seeds `.github/coverage-baseline.json` (so D2 becomes live) and confirms the gate is green. This is exactly the ADR's accepted bootstrap state (D2 absent-baseline ⇒ satisfied; the file is seeded on first post-merge run).

## Important constraints (from ADR-0032 itself)

- **ADR-0032 stays Proposed.** Per the established ADR workflow, it flips to Accepted only when the implementing PR (packet 01) merges. **No acceptance packet is in this initiative** — the user explicitly directed not to flip it. The new invariant ("Test-bearing repos enforce the coverage gate at PR time…") and any constitution edit are deferred to a later acceptance step the user will trigger; they are **not** part of these twelve packets.
- **OQ2 — sequence floor-crossing first.** Until a repo crosses 70%, D3 fails every PR there regardless of D1 (the patch gate's signal is masked). Each backfill packet states this explicitly so the masked-D1 behavior is not mistaken for a CI defect, and the backfill is positioned as the work that unblocks normal PR flow per repo. Wave 2 = floor-crossing.
- **OQ3 — baseline commit-back must not race.** Packet 01's post-merge ratchet uses rebase-and-retry + skip-if-no-change; a naive `git push` is explicitly forbidden in the packet's acceptance criteria.
- **D4 — outdated never blocks.** Packet 01's PR-time outdated-package step and packet 02's `nightly-deps` issue step are both structurally incapable of failing a check. Vulnerable packages continue to block via the unchanged `dependency-scan` job.
- **Doc convention.** No ADR number in any workflow comment, README prose, `consumer-usage.md`, or the `📦 Outdated Dependencies` issue body. The runtime packet-data identifier `adr-0032` is acceptable only as a packet-data reference.
- **Wire-vs-fold (resolved in packet 01, do not re-litigate):** the coverage gate is **folded into `pr-core.yml`'s `pr-summary` job**, not wired through `job-coverage-analysis.yml`. The latter is deprecated in place (header comment only — not deleted, not extended). Rationale is in packet 01.

## Wave Diagram

### Wave 1 — Actions control plane (two packets, parallel, no internal blockers)

- [ ] `HoneyDrunk.Actions`: Blocking coverage gate (D1–D3, skip-when-no-tests) + non-blocking ⚠️ outdated-NuGet summary section (D4/D5) — [`01-actions-coverage-gate-and-nuget-summary.md`](01-actions-coverage-gate-and-nuget-summary.md)
  - Blocked by: nothing. Lead packet.
- [ ] `HoneyDrunk.Actions`: `nightly-deps.yml` maintains a single grouped `📦 Outdated Dependencies` issue per repo (D6) — [`02-actions-nightly-deps-grouped-tracking-issue.md`](02-actions-nightly-deps-grouped-tracking-issue.md)
  - Blocked by: nothing hard. Soft sequencing on packet 01 (shared CHANGELOG version entry + `consumer-usage.md`; 01 is the bumping packet that creates the version entry 02 appends to).

**Wave 1 exit criteria (before Wave 2 backfill PRs are opened):**
- `pr-core.yml` exposes `patch-coverage-threshold` (75) and `absolute-coverage-floor` (70); the `Coverage gate` step evaluates D1/D2/D3 and skips visibly when no test project; a violation turns the required `PR Core` check red for test-bearing repos.
- The `coverage-baseline-ratchet` job runs on default-branch push with OQ3-safe commit-back; `.github/coverage-baseline.json` shape is `{ totalLineCoverage, commit, measuredAtUtc }`.
- `pr/generate-summary` renders the `### Coverage Gate` block and the non-blocking `### :warning: Outdated Packages` block; neither changes the overall icon.
- `nightly-deps.yml` maintains exactly one `📦 Outdated Dependencies` issue per repo, idempotent by stable title, auto-close-when-empty, non-blocking.
- Both packets' CHANGELOG entries landed (01 = new version entry on the Actions solution; 02 appended).

### Wave 2 — Per-repo coverage backfill (ten packets, fully parallel after packet 01)

Each packet below is **hard-blocked by packet 01 only**. They do not block each other and are not blocked by packet 02. Open them as a parallel fan-out the moment packet 01 merges and is consumed by the repo's `pr-core.yml`.

- [ ] `HoneyDrunk.Kernel`: backfill total line coverage ≥ 70% + seed baseline — [`03-kernel-coverage-backfill-to-70.md`](03-kernel-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Transport`: backfill ≥ 70% + seed baseline — [`04-transport-coverage-backfill-to-70.md`](04-transport-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Vault`: backfill ≥ 70% + seed baseline — [`05-vault-coverage-backfill-to-70.md`](05-vault-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Vault.Rotation`: backfill ≥ 70% + seed baseline — [`06-vault-rotation-coverage-backfill-to-70.md`](06-vault-rotation-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Auth`: backfill ≥ 70% + seed baseline — [`07-auth-coverage-backfill-to-70.md`](07-auth-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Web.Rest`: backfill ≥ 70% + seed baseline — [`08-web-rest-coverage-backfill-to-70.md`](08-web-rest-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Data`: backfill ≥ 70% + seed baseline — [`09-data-coverage-backfill-to-70.md`](09-data-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Pulse`: backfill ≥ 70% + seed baseline — [`10-pulse-coverage-backfill-to-70.md`](10-pulse-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Notify`: backfill ≥ 70% + seed baseline — [`11-notify-coverage-backfill-to-70.md`](11-notify-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)
- [ ] `HoneyDrunk.Communications`: backfill ≥ 70% + seed baseline — [`12-communications-coverage-backfill-to-70.md`](12-communications-coverage-backfill-to-70.md) — Blocked by: Wave 1 — `01` (hard)

**Wave 2 exit criteria:**
- Every test-bearing repo's measured total line coverage is ≥ 70% (target ≥ 72% margin) under the Grid ReportGenerator filter.
- Every test-bearing repo has a committed `.github/coverage-baseline.json` (seeded by its backfill PR and/or the post-merge ratchet).
- The `PR Core` required check is green on the backfill PR for every test-bearing repo (D3 cleared; D1 satisfied for the PR's own diff).

## Recommended dispatch order

1. **File all twelve packets in one pass.** Wave is execution sequencing, not a filing gate; the filing pipeline wires `addBlockedBy` from the `dependencies:` frontmatter automatically.
2. **Land packet 01 first.** It is the keystone — nothing else is meaningful until the gate exists.
3. **Land packet 02 next** (or in parallel with 01; soft-ordered after 01 only so the CHANGELOG version entry exists to append to).
4. **Fan out packets 03–12 in parallel** once 01 has merged and each repo's `pr-core.yml@main` consumes the new gate. There is no inter-repo ordering among the ten — they are independent test-only PRs. Practical sequencing tip: do the smallest measured gap first per repo to bank quick green checks, but this is an optimization, not a dependency.

## Filing note

Filing is automated: pushing these packets to `main` under `generated/issue-packets/active/adr-0032-pr-validation-policy/` triggers `file-packets.yml`, which creates each issue, adds it to The Hive, sets board fields from frontmatter, and wires `addBlockedBy` from the `dependencies:` arrays (`packet:01` for every Wave 2 packet). No manual `gh issue create` / `addBlockedBy` is emitted here by design — the scope agent's job ends at writing the packets. The user triggers the file-issues step separately.

## Notes

- **ADR-0032 is NOT flipped to Accepted by this initiative.** Per the established workflow and explicit user direction, it stays Proposed until packet 01's PR merges. The new invariant and any constitution renumbering are a separate later step the user will trigger — deliberately out of scope here.
- **Actor=Agent for all twelve packets.** No packet requires a human in the critical path. Packet 01's only operational note is operator awareness that sub-70% repos go red until backfilled (intended) — no portal action, no secret. No `human-only` label on any packet.
- **Templated backfill set is intentional.** ADR-0032's follow-up text explicitly permits "a clearly-templated set" for the backfill. Packet `03` (Kernel) is the canonical template; `04`–`12` are mechanical substitutions (target repo, node, sector label, test-project name, uncovered-surface hint). Each remains independently fileable and executable.
- **The dispatch plan is the one exception to packet immutability** (per the work-tracking ADR). Updates at wave boundaries are the historical record. Packet bodies are immutable post-filing.

## Archival

When every packet reaches `Done` on The Hive and both wave exit criteria are met, the entire `active/adr-0032-pr-validation-policy/` folder moves to `archive/adr-0032-pr-validation-policy/` in a single commit. Partial archival is forbidden.

## Revision history

- **2026-05-17 initial scope** — twelve packets, two waves. Wave 1 = two Actions control-plane packets (coverage gate D1–D5; `nightly-deps` grouped issue D6). Wave 2 = ten per-repo coverage backfills, each hard-blocked by packet 01, fully parallel. Current coverage undeterminable at scope time (no committed coverage artifacts in the workspace; gate/baseline mechanism not yet shipped) — every backfill packet is measure-first. ADR-0032 deliberately left Proposed; no acceptance packet included.
