---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["feature", "tier-2", "honeyhub", "scaffold", "adr-0091", "wave-3"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0091", "ADR-0090", "ADR-0092", "ADR-0082", "ADR-0070", "ADR-0039"]
accepts: ADR-0091
source: human
generator: scope
wave: 3
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Feature: Scaffold HoneyDrunk.HoneyHub — workspace monorepo (React+Vite PWA + Rust bridge crate), CI dual-lane, first-shippable state

## Summary
Bring the empty `HoneyDrunk.HoneyHub` repo from zero to first-shippable scaffold per ADR-0091 D4 (repo/package structure) and the ADR-0082 Phase C mandatory + `studios-typescript-native` class-specific steps (the dual TS-UI + native-bridge class added by the ADR-0082 2026-06-06 amendment). Land the workspace monorepo holding (1) the **React + Vite PWA** UI package, (2) the **Rust bridge** crate (compiling but minimal — the real bridge core is Phase 2 / packet 04), and (3) the **Tauri-class desktop shell** package as a declared-but-minimal wrapper. Wire the dual-lane CI (Node.js lane for the PWA + Rust lane for the bridge crate) in a **self-contained `pr.yml`** (NOT calling `pr-core.yml`; required check `pr / build`), the standard repo hygiene files (`README.md`, `CHANGELOG.md`, `LICENSE`, `.honeydrunk-review.yaml`, `.github/copilot-instructions.md`, `CLAUDE.md`), and the placeholder package surfaces so Phase 2 packets have somewhere to build into.

This is the bootstrap PR (ADR-0082 Phase C): it may introduce items 7 (`.honeydrunk-review.yaml`), 8 (`pr.yml`), and the org-secret refinements in the same commit as the rest of the scaffold. Invariant 102 binds the *second* (first feature) PR, not this bootstrap PR.

**No Grid package is published at v1.** The PWA is a static build (deployed to Cloudflare Pages — a deploy concern handled later, not in this scaffold); the bridge is a bundled binary, not a published Grid npm/NuGet package. The scaffold ships a buildable, testable, CI-green repo — not a release.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub`

## Motivation
Packet 02 created the GitHub repo and cloned the local tree (`.gitignore`, `LICENSE`, placeholder `README.md`). Packet 01 landed the catalogs and the `repos/HoneyDrunk.HoneyHub/` context folder. This packet ships the scaffold so Phase 2 (bridge core, pairing, the Claude Code adapter, the run screen, the local store — packets 04–08) has a structured, CI-green workspace to build into.

Per ADR-0091 D4: **one `HoneyDrunk.HoneyHub` repo, lightly multi-package (a workspace)** containing the web/PWA UI package, the desktop shell package (Tauri-class wrapper), and the bridge package (Rust). The `[Firm]` part is "one repo for the v1 product"; the package granularity is `[Provisional]` — this scaffold uses a pragmatic four-package shape (ui, shell, bridge, shared-types) and the body notes it may consolidate.

## Mixed-class scaffold (the first TS+Rust Grid repo)
Per ADR-0091 D1 and packet 01's `active-work.md`, HoneyHub is declared **`node_class: studios-typescript-native`** (the dedicated dual TS-UI + native-Rust-bridge class added by the ADR-0082 2026-06-06 amendment — see ADR-0082 D2 and `constitution/node-standup.md`). Concretely:
- The **Node.js workspace** (pnpm or npm workspaces) holds the UI, shell-frontend, and shared-types packages.
- The **Cargo workspace** holds the Rust bridge crate (and the Tauri-class shell's Rust core if the shell toolkit is Tauri).
- **CI runs both lanes via a self-contained `pr.yml`.** There is **no** `pr-typescript.yml` reusable workflow in HoneyDrunk.Actions (the only PR reusable workflows are `pr-core.yml`/`pr-sdk.yml`/`pr-review.yml`, all .NET-shaped), so per the `studios-typescript-native` class (and the ADR-0082 D5y "invoke CLIs directly until that workflow is built" path), the repo ships a self-contained `pr.yml` that does **not** call `pr-core.yml`. It runs an **npm/pnpm lane** (`npm ci`/`pnpm install` → `build` → `test` → `lint`) **and** a **Rust lane** (`cargo build` → `cargo test` → `cargo clippy -- -D warnings`), wired so a failure in either lane fails the gate. Per invariant 38 (reusable workflows invoke tool CLIs directly — wrapping a tool with a stable CLI in a third-party marketplace action is forbidden), invoke `cargo` and `npm`/`pnpm` directly; do not wrap them in marketplace actions.
- **The single required `main` status check is this job's own name — `pr / build` — not `pr-core / core`** (packet 02 sets the branch-protection rule accordingly). When a shared `pr-typescript.yml` is eventually built, the repo can migrate to call it; until then `pr.yml` is self-contained.

This scaffold's CI shape is what the `studios-typescript-native` class documents. Record any divergence in the PR body.

## Proposed Implementation

### Repository layout (target shape; package granularity `[Provisional]` per ADR-0091 D4)
```
HoneyDrunk.HoneyHub/
├── package.json                      (workspace root; private:true; workspaces ./packages/*)
├── pnpm-workspace.yaml               (or npm workspaces — match Grid TS convention)
├── tsconfig.base.json                (shared TS base; per-package tsconfig extends)
├── Cargo.toml                        (Cargo workspace root; members = ["crates/*"])
├── .npmrc / .editorconfig / .gitignore  (extend with target/, dist/, node_modules/, .tauri/)
├── README.md  CHANGELOG.md  LICENSE
├── .honeydrunk-review.yaml           (enabled: true)
├── CLAUDE.md  .github/copilot-instructions.md
├── .github/workflows/
│   ├── pr.yml                        (self-contained; runs Node + Rust lanes directly; job name `build` → check `pr / build`)
│   ├── nightly-deps.yml              (grouped deps per ADR-0009 — Node + cargo)
│   └── nightly-security.yml          (audit; manual close)
├── packages/
│   ├── ui/                           (@honeydrunk/honeyhub-ui — React + Vite PWA; the one shared UI)
│   │   ├── package.json  vite.config.ts  tsconfig.json
│   │   ├── public/manifest.webmanifest  (PWA manifest)
│   │   ├── src/  (App shell, a placeholder run-screen route, service-worker registration)
│   │   └── test/ (Vitest smoke: app renders)
│   ├── shell/                        (the Tauri-class desktop shell wrapper — minimal at scaffold)
│   └── shared-types/                 (@honeydrunk/honeyhub-types — the ADR-0090 session-contract TS types)
└── crates/
    └── bridge/                       (the Rust bridge crate — compiling, minimal; real core is packet 04)
        ├── Cargo.toml
        ├── src/lib.rs                (module skeleton: session, process, pairing, adapter traits — stubs)
        └── tests/                    (a compiling smoke test)
```

### `packages/shared-types` — the ADR-0090 session contract as TypeScript types
Ship the ADR-0090 D3 entity types as the canonical TS surface both the UI and (over the wire) the bridge agree on. Define `DispatchSession`, `DispatchRun`, `DispatchMessage`, `DispatchControlEvent`, `DispatchArtifact`, `UsageSignal`, `PolicyHint`, the run-state enum (`created | queued | starting | running | needs_input | finalizing | completed | stopping | failed | cancelled`), the `AgentBackend` discriminator (`claude.local | codex.local | copilot.local`), and the capability-flag set (`streaming_output`, `interactive_reply`, `resume_session`, `stop_signal`, `structured_events`, `usage_exact`, `usage_estimated`). Add the `UsageSignal.fidelity` field (`exact | derived | estimated`) per ADR-0092 D2. These are **type definitions only** at scaffold — no behavior. They are the shared contract Phase 2 packets implement against.

### `crates/bridge` — Rust bridge crate skeleton (compiling, minimal)
A compiling crate with module stubs that name the ADR-0090 D1 bridge responsibilities so packet 04 has clear seams: `session` (lifecycle), `process` (launch/lifecycle), `pairing` (device identity + token + workspace-root allowlist), `adapter` (a `trait AgentBackendAdapter` declaring stream/reply/stop/resume and capability flags), `artifact` (detection). At scaffold these are stubs with a compiling smoke test — **the real process launch, the session contract over the wire, and the Claude Code adapter are Phase 2 (packets 04–05).** Do not implement CLI driving here.

### `packages/ui` — React + Vite PWA shell
A minimal installable PWA per ADR-0091 D3 (React + Vite, PWA, the single shared UI codebase): app shell, a placeholder `/run` route (the real run screen is packet 07), `manifest.webmanifest` + service-worker registration so it installs as a PWA, a Vitest smoke test that the app renders. No bridge wiring yet (Phase 2). Consume the Grid's Web.UI design tokens per ADR-0071 if the `@honeydrunk/web-ui-tokens` package is published and available; otherwise ship local placeholder tokens and note a follow-up to adopt Web.UI tokens (flag in PR body — do not block the scaffold on Web.UI token availability).

### `packages/shell` — Tauri-class desktop shell (minimal wrapper)
A minimal shell package that wraps the `ui` build and declares the intent to bundle the bridge (ADR-0091 D2: desktop = a Tauri-class shell that bundles the local bridge). At scaffold it is a thin wrapper that builds; the actual bridge bundling + single-installer packaging + code-signing/auto-update are `[Provisional]` packaging follow-ups (ADR-0091 Open Questions), **not** delivered here. If the chosen toolkit is Tauri, its Rust core joins the Cargo workspace; if the exact Tauri-class toolkit is still undecided, ship the shell package as a declared placeholder and record the toolkit decision as open in the PR body and `active-work.md`.

### CI — self-contained dual-lane `pr.yml`
`pr.yml` is **self-contained** — it does **not** call `pr-core.yml`. There is no `pr-typescript.yml` reusable workflow in HoneyDrunk.Actions (the PR reusable workflows are `pr-core.yml`/`pr-sdk.yml`/`pr-review.yml`, all .NET-shaped), and `pr-core.yml` assumes a .NET solution shape this repo does not have. Per the `studios-typescript-native` class and ADR-0082 D5y's "invoke CLIs directly until that workflow is built" path, `pr.yml` runs both lanes directly: the Node lane (`npm ci`/`pnpm install` → `build` → `test` → `lint`) and the Rust lane (`cargo build` → `cargo test` → `cargo clippy -- -D warnings`), both via direct CLI calls (invariant 38), wired so either lane's failure fails the gate. The workflow's job is named `build` so its required status check on `main` is **`pr / build`** (the check packet 02 wires into branch protection). The workflow declares its own `permissions:` block scoped to what the lanes need (read contents, write checks/PR status) — there is no reusable-workflow permissions-superset to satisfy here, since nothing is being called. When a shared `pr-typescript.yml` is later built, the repo can migrate `pr.yml` to call it (and re-point the required check); until then it is self-contained. `nightly-deps.yml` and `nightly-security.yml` consume the reusable workflows (ADR-0009); the deps job covers both Node and cargo dependency graphs.

### Repo hygiene files
- **`README.md`** (invariant 12) — purpose, the three surfaces, local-dev setup for the dual Node+Rust toolchain, link to `repos/HoneyDrunk.HoneyHub/overview.md`. Do **not** cite ADR numbers in narrative prose.
- **`CHANGELOG.md`** (invariant 12) — first entry `## [0.1.0] - YYYY-MM-DD` (scaffold), not `## Unreleased`.
- **`LICENSE`** — MIT (placed by packet 02; verify content).
- **`.honeydrunk-review.yaml`** with `enabled: true` (invariant 52 — a missing file is a silent disable).
- **`.github/copilot-instructions.md`** — per-repo file pointing back to Architecture's copilot-instructions + HoneyHub addenda.
- **`CLAUDE.md`** — links to `repos/HoneyDrunk.HoneyHub/overview.md` and notes the dual Node+Rust local-dev toolchain.

### Per-package READMEs + CHANGELOGs
Each package/crate (`ui`, `shell`, `shared-types`, `bridge`) gets a `README.md` and `CHANGELOG.md` from the first commit (invariant 12 — every package directory must contain a README and CHANGELOG; new projects have them from the first commit). The CHANGELOGs carry `## [0.1.0] - YYYY-MM-DD` (or `## [0.0.0]` for placeholder-only packages — declare honestly).

## Acceptance Criteria
- [ ] Workspace monorepo builds: the Node workspace (`ui`, `shell`, `shared-types`) and the Cargo workspace (`bridge`) both build clean.
- [ ] `packages/shared-types` exports the ADR-0090 session-contract types (`DispatchSession`, `DispatchRun`, `DispatchMessage`, `DispatchControlEvent`, `DispatchArtifact`, `UsageSignal` with `fidelity`, `PolicyHint`), the run-state enum, the `AgentBackend` discriminator, and the seven capability flags.
- [ ] `crates/bridge` compiles with module stubs (`session`, `process`, `pairing`, `adapter` with an `AgentBackendAdapter` trait, `artifact`) and a passing smoke test. No CLI-driving implementation (deferred to packet 04).
- [ ] `packages/ui` is an installable PWA (manifest + service worker) with an app shell, a placeholder `/run` route, and a passing Vitest smoke test.
- [ ] `packages/shell` builds as a minimal Tauri-class wrapper; bridge bundling + installer packaging + code-signing recorded as `[Provisional]` follow-ups, not delivered.
- [ ] A **self-contained** `pr.yml` (NOT calling `pr-core.yml`) runs both the Node lane and the Rust lane (cargo build/test/clippy via direct CLI), wired so either lane's failure fails the gate; the job is named `build` so the required check is `pr / build`; `pr.yml` declares its own `permissions:` block scoped to the lanes' needs (no reusable-workflow superset applies since nothing is called); first PR is green.
- [ ] `nightly-deps.yml` + `nightly-security.yml` consume the reusable workflows and cover Node + cargo graphs.
- [ ] `.honeydrunk-review.yaml` (`enabled: true`), `.github/copilot-instructions.md`, `CLAUDE.md`, repo `README.md`, repo `CHANGELOG.md` (`## [0.1.0]`), `LICENSE` (MIT) all present.
- [ ] Each package/crate has a `README.md` + `CHANGELOG.md` from the first commit (invariant 12).
- [ ] CHANGELOG entries are dated and SemVer-bumped (`## [0.1.0] - YYYY-MM-DD`), not under `## Unreleased`.
- [ ] No Grid npm/NuGet package is published; no tag is pushed by the agent (invariant 27 — agents never push tags); the PR body notes HoneyHub publishes no Grid package at v1.
- [ ] PR body links the packet (invariant 32) and records the open desktop-shell-toolkit decision + the Web.UI-token-adoption follow-up.

## Human Prerequisites
- [ ] Packet 02 Done — repo exists, branch protection active, repo-to-node mapped (via packet 10), local tree cloned. (`studios-typescript-native` requires no org secret by default: the self-contained `pr.yml` runs no Sonar job, so `SONAR_TOKEN` is conditional — bound only if a Sonar lane is later added to `pr.yml`.)
- [ ] Local dev machine has both the Node.js toolchain (Node >=22, pnpm/npm) and the Rust toolchain (`rustup`, stable `cargo`, `clippy`) installed — required for the agent (or a human running the agent locally) to build/test both lanes before pushing. Per the memory note on CRLF: run `dotnet format`-equivalent (here, `cargo fmt` + the Node formatter) locally before committing after any full-file rewrite, since Write-tool output is LF on Windows.
- [ ] (Post-merge, human, deferred) First-PR branch-protection update to add the Rust-lane + PWA-build canary as required checks once each runs cleanly — not blocking this scaffold.
- [ ] (Deferred, not this packet) Cloudflare Pages project for the static PWA host (ADR-0091 D4 / ADR-0029) — a deploy concern, set up when the PWA is ready to publish, not at scaffold.
- [ ] (Deferred, not this packet) The desktop-shell toolkit pick + code-signing + auto-update (ADR-0091 Open Questions) — packaging follow-up.

## Dependencies
- `packet:01` — catalog registration + context folder must be in `main` (the scaffold's CLAUDE.md and PR body cross-reference `repos/HoneyDrunk.HoneyHub/`).
- `packet:02` — the GitHub repo must exist, branch protection active, repo-to-node mapped (via packet 10), local tree cloned, before the scaffold can be filed and authored. (No `SONAR_TOKEN` is required by default for `studios-typescript-native` — the self-contained `pr.yml` runs no Sonar job; `SONAR_TOKEN` is bound only if a Sonar lane is later added.)

## Agent Handoff
**Objective:** Scaffold the empty `HoneyDrunk.HoneyHub` repo to a CI-green, buildable, first-shippable workspace (React+Vite PWA + Rust bridge crate + Tauri-class shell wrapper + shared session-contract types), with no Grid package published.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, branch from `main`.
**Context:**
- Goal: stand up the HoneyHub Agent Cockpit Node so Phase 2 has a structured workspace.
- Feature: Phase C scaffold (ADR-0082) for the Grid's first mixed TS+Rust repo.
- ADRs: ADR-0091 (stack: React+Vite PWA, Tauri-class shell bundling the Rust bridge, one workspace repo, Cloudflare Pages static host), ADR-0090 (session contract + capability flags — shipped here as TS types only), ADR-0092 (UsageSignal.fidelity field), ADR-0082 (standup procedure), ADR-0070 (React is the Grid web stack), ADR-0039 (MIT license).

**Acceptance Criteria:** as listed above.

**Dependencies:** packets 01 + 02 merged/Done.

**Constraints (full invariant text inlined):**
- Invariant 12 (Semantic versioning with CHANGELOG and README): every package directory must contain a `README.md` (purpose, installation, public API) and a `CHANGELOG.md`; new projects have both from the first commit.
- Invariant 27 (all projects in a solution share one version and move together; agents never push tags): the workspace packages move together where they version; the agent does not push the `v0.1.0` tag — a human pushes it after merge if/when a release is cut.
- Invariant 31 (Every PR traverses the tier-1 gate before merge — build, unit tests, analyzers, vulnerability scan, secret scan are required branch-protection checks): for the `studios-typescript-native` class this gate is delivered by the **self-contained `pr.yml`** (Node + Rust lanes run directly, not via `pr-core.yml`), and the required `main` check is **`pr / build`**, not `pr-core / core`. The scaffold's first PR must pass `pr / build`.
- Invariant 38 (reusable workflows invoke tool CLIs directly — wrapping a tool with a stable CLI in a third-party marketplace action is forbidden): invoke `cargo`, `npm`/`pnpm`, and `vite` directly in CI; no marketplace wrappers.
- Invariant 39 (caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions): applies only when a workflow *calls* a reusable workflow. `pr.yml` is self-contained (calls nothing), so it declares its own least-privilege `permissions:` block scoped to the lanes' needs; there is no reusable-workflow superset to satisfy. (The `nightly-*.yml` workflows that DO consume reusable workflows must still honor the superset rule.)
- Invariant 52 (every non-draft PR on an `enabled` repo runs the cloud-wired review agent; a repo is enabled when it carries `.honeydrunk-review.yaml` with `enabled: true`): ship `.honeydrunk-review.yaml` with `enabled: true`.
- The `[Firm]` not-an-editor / not-a-terminal boundary (PDR-0011): HoneyHub gains no code editor and no terminal — the scaffold ships a cockpit shell, not an IDE.
- The `[Firm]` BYOK-only / never-subscription-auth boundary (ADR-0090 D10): no scaffold code holds, stores, or proxies vendor subscription auth; the bridge drives official CLIs under the user's own local session.
- ADR-0082 D2 taxonomy: HoneyHub stands up as the dedicated **`studios-typescript-native`** class (added by the ADR-0082 2026-06-06 amendment — a dual Node + Cargo workspace, self-contained `pr.yml` with required check `pr / build`, no NuGet/Standards, no org secret required by default).

**Key Files:**
- `package.json`, `pnpm-workspace.yaml`, `tsconfig.base.json`, `Cargo.toml`
- `packages/ui/**`, `packages/shell/**`, `packages/shared-types/**`, `crates/bridge/**`
- `.github/workflows/pr.yml` (+ nightly-deps/nightly-security)
- `.honeydrunk-review.yaml`, `CLAUDE.md`, `.github/copilot-instructions.md`, `README.md`, `CHANGELOG.md`

**Contracts:**
- `packages/shared-types`: the ADR-0090 D3 session-model TS types + the ADR-0092 D2 `fidelity` field — type definitions only, the surface Phase 2 implements against.
- `crates/bridge`: the `AgentBackendAdapter` trait skeleton (stream/reply/stop/resume + capability flags) — stub only, implemented in packet 04/05.
