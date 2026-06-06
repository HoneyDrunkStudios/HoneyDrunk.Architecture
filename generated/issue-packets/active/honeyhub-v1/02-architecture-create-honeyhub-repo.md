---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "honeyhub", "adr-0091", "human-only", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0091", "ADR-0082"]
accepts: ADR-0091
source: human
generator: scope
wave: 2
initiative: honeyhub-v1
node: honeydrunk-honeyhub
actor: human
---

# Chore: Create HoneyDrunk.HoneyHub repo + branch protection + labels + repo-to-node + org-secret binding + clone (human-only, Phase B)

## Summary
Create the public `HoneyDrunkStudios/HoneyDrunk.HoneyHub` GitHub repo (Phase B of the ADR-0082 standup), apply the Grid's standard settings (branch protection on `main` requiring the repo's own **`pr / build`** check — this is a `studios-typescript-native` Node whose self-contained `pr.yml` does not call the .NET `pr-core.yml`), labels, security analysis), add the `repo-to-node.yml` mapping in `HoneyDrunk.Actions`, optionally bind any org Actions secrets its CI will consume (by default **none** are required — see Step 6), and clone the repo locally so packet 03's scaffolding agent has a working tree to author into. This is an org-admin action that cannot be delegated to an agent — it gates packet 03.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (tracking issue lives here; the actual work happens at the GitHub org level + locally on the operator's machine).

## Actor
**`Human`.** Org-admin rights on `HoneyDrunkStudios` are required to create the repo, apply branch protection, seed labels, configure org-secret repo bindings, and clone. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation
`03-honeyhub-node-scaffold.md` defines the workspace monorepo, the Rust bridge crate, the React+Vite PWA package, and the CI lanes — but cannot be executed by the scaffolding agent until the GitHub repo exists, branch protection is active, the repo is mapped in `repo-to-node.yml`, the org secrets its workflows reference are bound to the repo, and a local working tree is cloned. Per the Phase A→B→C gate chain in `constitution/node-standup.md`: Phase A (packet 01) must merge before Phase B; Phase B must complete before Phase C is fileable (invariant 24 — a packet's `target_repo` must exist before its issue can be filed).

**Mixed TS+Rust note:** HoneyHub is the Grid's first `studios-typescript-native` repo (TypeScript UI + Rust native bridge in one dual Node + Cargo workspace, per the ADR-0082 2026-06-06 amendment). The CI that the scaffold (packet 03) wires is a **self-contained `pr.yml`** (it does NOT call the .NET `pr-core.yml` — there is no `pr-typescript.yml` reusable workflow in HoneyDrunk.Actions; the only PR reusable workflows are `pr-core.yml`/`pr-sdk.yml`/`pr-review.yml`, all .NET-shaped). The `pr.yml` job is named `build` and runs both a Node.js lane (`npm ci && build && test`) and a Rust lane (`cargo build && cargo test && cargo clippy`). For branch protection, the **single required status check at standup is the repo's own `pr / build`**, NOT `pr-core / core`. Additional canary checks (if any) are added in a follow-up branch-protection update after the scaffold's first PR confirms each lane runs cleanly, the same first-PR `status: skipped` pattern the Audit/Files/Web.UI standups used.

## Steps

### Step 1 — Create the public repo (portal)
1. Open https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. Fill in:
   - **Repository name:** `HoneyDrunk.HoneyHub`
   - **Description:** `HoneyHub — the Agent Cockpit. A mobile PWA + desktop shell that starts, watches, interrupts, and governs local Codex / Claude Code / Copilot sessions via their official CLIs under your own local auth. Bundled local runner bridge (Rust); local-first session/usage store; usage governance + routing.`
   - **Visibility:** **Public** (Grid default per ADR-0039; no revenue/compliance/experiment carve-out applies — the free local cockpit is build-in-public substrate).
   - **Initialize with:** check `.gitignore` (template: `Node` — the dominant surface; the scaffold extends it with Rust `target/` and Tauri build artifacts), check `LICENSE` (template: `MIT` — matches other Grid public repos). Do **not** add a README (packet 03 authors it).
3. Click **Create repository**.
4. Open repo Settings — confirm default branch `main`, Visibility Public, Issues + Actions enabled.

### Step 2 — Branch protection on `main`
Open Settings → Branches and create a rule on `main`:
- **Require a pull request before merging:** on
- **Require approvals:** off (solo developer; matches other Grid repos)
- **Require status checks to pass before merging:** on
- **Required status checks:** **`pr / build`** only for now (the repo's own self-contained `pr.yml` job — NOT `pr-core / core`; HoneyHub does not consume the .NET `pr-core.yml`). The check name will not resolve in the GitHub UI until the scaffold's first `pr.yml` run reports it — add it by name (or add it after the first scaffold PR run surfaces it), the same way other repos' canary checks are added once they first report. Any additional canary checks are deferred to a follow-up branch-protection update after the scaffold's first PR runs each lane cleanly.
- **Allow force pushes:** off
- **Allow deletions:** off
- **Require signed commits:** off (matches Grid posture)

### Step 3 — Security analysis settings
Open Settings → Code security and analysis:
- **Dependabot alerts:** Enabled (org default)
- **Dependabot security updates:** **Off** (grouped nightly-deps workflow replaces per-package Dependabot PRs)
- **CodeQL default-setup:** **Off** (org "HoneyDrunk Grid — public default" config keeps default-setup off)
- **Secret scanning:** Enabled; **Push protection:** Enabled

### Step 4 — Seed labels (CLI)
Run from any directory with `gh` authenticated as the org owner:

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "tier-3:5319E7" "honeyhub:8957E5" "scaffold:BFDADC" "adr-0090:1D76DB" "adr-0091:1D76DB" "adr-0092:1D76DB" "wave-2:FBCA04" "wave-3:FBCA04" "wave-4:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.HoneyHub --color "$color" 2>/dev/null
done
```

"already exists" errors are fine (idempotent).

### Step 5 — Add the repo-to-node mapping (in HoneyDrunk.Actions)
Per invariant 41 (and ADR-0082 mandatory step 7), add the mapping so issue routing and the grid-health aggregator resolve issues filed against the new repo back to its Node identity. Edit `HoneyDrunk.Actions/.github/config/repo-to-node.yml` and add a row mapping `HoneyDrunk.HoneyHub` → `honeydrunk-honeyhub` (match the format of the existing rows). This is a small PR against `HoneyDrunk.Actions` — it can travel as its own commit or be bundled with this chore's tracking work; flag it in the chore so it is not forgotten (this was the most frequently missed standup step historically).

### Step 6 — Org-secret repo binding (by default: NONE required)
GitHub does not auto-propagate `Selected repositories`-scoped org secrets to new repos. For every org Actions secret the new repo's workflows will consume, visit `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/{SECRET_NAME}` and add `HoneyDrunk.HoneyHub` to the access list.

**For the `studios-typescript-native` class, the default per-class matrix requires NO org secrets** (per the ADR-0082 2026-06-06 amendment / the `constitution/node-standup.md` matrix note):

- **`SONAR_TOKEN` — NOT required by default.** The Sonar job lives in `pr-core.yml`, which HoneyHub does **not** consume (its `pr.yml` is self-contained, Node + Rust lanes only). The SonarCloud job therefore does not run, so `SONAR_TOKEN` is unnecessary unless/until a Sonar lane is explicitly added to `pr.yml`. **Keep this binding step in the runbook but treat it as conditional/optional**: bind `SONAR_TOKEN` only if the scaffold (or a later PR) wires a Sonar lane into `pr.yml`.
- **`NPM_TOKEN` / `NUGET_API_KEY` — not required.** HoneyHub publishes no npm/NuGet Grid package at v1 (static PWA + co-bundled binary).
- **`DISCORD_WEBHOOK_*` — only if the scaffold's CI emits operator-actionable Discord alerts** (it likely does not at standup); bind per the matrix only if a workflow wires one.

Net: at standup, this step is typically a **no-op** for HoneyHub. Confirm the scaffold's `pr.yml` references no org secret before considering this step complete; bind only what an actually-wired lane consumes.

### Step 7 — Clone the repo locally
```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.HoneyHub.git
cd HoneyDrunk.HoneyHub
git status
```
The clone should land at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.HoneyHub/` containing `.gitignore`, `LICENSE`, and possibly a placeholder `README.md` — packet 03 overwrites the README and creates everything else.

### Step 8 — Confirm Architecture-side prereq
Confirm packet 01 (the catalog registration packet) has merged to `main` so `repos/HoneyDrunk.HoneyHub/` and the catalog rows exist. The GitHub-side actions here are technically independent of packet 01's merge, but the scaffold (packet 03) is not — surfacing the dependency here keeps the chain visible on The Hive.

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.HoneyHub` repo exists, is public, default branch `main`, Issues + Actions enabled.
- [ ] Repo initialized with `.gitignore` (Node template) and `LICENSE` (MIT).
- [ ] Branch protection on `main` requires **`pr / build`** (the repo's own self-contained `pr.yml` job, NOT `pr-core / core`), no force-pushes, no deletions, signed commits not required.
- [ ] Dependabot alerts Enabled; Dependabot security updates Off; CodeQL default-setup Off; Secret scanning + push protection Enabled.
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `tier-3`, `honeyhub`, `scaffold`, `adr-0090`, `adr-0091`, `adr-0092`, `wave-2`, `wave-3`, `wave-4`, `human-only`, `out-of-band` all exist on the repo.
- [ ] `HoneyDrunk.Actions/.github/config/repo-to-node.yml` maps `HoneyDrunk.HoneyHub` → `honeydrunk-honeyhub` (merged to `HoneyDrunk.Actions` main).
- [ ] Org-secret binding handled per the `studios-typescript-native` matrix: **no org secret is required by default** (no `SONAR_TOKEN` — `pr.yml` does not consume `pr-core.yml`; no `NPM_TOKEN`/`NUGET_API_KEY` — no package published). Any secret is bound only if a `pr.yml` lane actually consumes it.
- [ ] Local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.HoneyHub/` exists (clean clone: `.gitignore` + `LICENSE` + at most a placeholder `README.md`).
- [ ] Packet 01 confirmed merged to `main`.
- [ ] This chore issue closed after all checks pass; packet 03 becomes fileable.

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios` (create repo, branch protection, labels, org-secret bindings) — see `infrastructure/walkthroughs/org-secret-repo-binding.md` for the per-secret Selected-repositories flow.
- [ ] Browser with GitHub session logged in as the org owner.
- [ ] `gh` CLI installed and authenticated as the org owner.
- [ ] Packet 01 merged to `main` (confirms catalog rows + `repos/HoneyDrunk.HoneyHub/` exist).
- [ ] Write access to `HoneyDrunk.Actions` to land the `repo-to-node.yml` mapping (Step 5).

## Dependencies
- `packet:01` — Architecture catalog registration must have merged so the catalogs already point at the eventual repo and the context folder exists. The GitHub-side actions are technically independent of packet 01's merge, but the scaffold (packet 03) is not; the dependency keeps the chain visible on The Hive.

## Downstream Unblocks
- Packet 03 (`03-honeyhub-node-scaffold.md`) becomes fileable once this chore is Done.

## Agent Handoff
**Objective:** (Human-executed) Create the `HoneyDrunk.HoneyHub` repo, apply standard settings, map repo-to-node, bind org secrets, clone locally.
**Target:** GitHub org `HoneyDrunkStudios` + local machine + a `repo-to-node.yml` PR against `HoneyDrunk.Actions`.
**Context:** Phase B of the ADR-0082 standup for `HoneyDrunk.HoneyHub`. This is org-admin work, not agent-delegable.

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 01 merged.

**Constraints:**
- Invariant 11 (One repo per Node — each repo has its own solution, CI pipeline, and versioning): new Node ⇒ new repo. This chore creates it.
- Invariant 31 (Every PR traverses the tier-1 gate before merge — build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks): for this `studios-typescript-native` Node the gate is delivered by the repo's **self-contained `pr.yml`** (Node + Rust lanes), not `pr-core.yml`. The required check on `main` is **`pr / build`**, not `pr-core / core`.
- Invariant 41 (new Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time; a repo missing from the catalog is invisible to grid observability) — the `repo-to-node.yml` mapping (Step 5) is the routing half of this.
- Invariant 24 (issue packets are immutable once filed; pre-filing amendments permitted) — the repo must exist before packet 03 can be filed against it.
- Repo is public (ADR-0039 Grid default); no carve-out applies.

**Key Files:**
- GitHub repo settings (portal), org-secret access lists (portal).
- `HoneyDrunk.Actions/.github/config/repo-to-node.yml`.

**Contracts:** None.
