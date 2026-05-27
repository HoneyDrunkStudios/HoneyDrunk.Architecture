---
name: Documentation
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "studios", "frontend", "adr-0082", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0082", "ADR-0012", "ADR-0057", "ADR-0070", "ADR-0071"]
accepts: ADR-0082
wave: 3
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Chore: Author `infrastructure/walkthroughs/node-standup-studios-typescript.md` — per-class walkthrough for Studios / TypeScript standups

## Summary

Author the Studios/TypeScript per-class walkthrough at `infrastructure/walkthroughs/node-standup-studios-typescript.md` per ADR-0082 D7. Composes against `constitution/node-standup.md` (packet 01). Covers TypeScript / React / Next-style repos (HoneyDrunk.Studios, future SDK packages per ADR-0057, future per-stack Web.UI packages). Replaces the .NET solution layout with `package.json` / `tsconfig.json` / ESLint+Prettier and the Node.js CI surface.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

The Grid currently has one TypeScript repo (HoneyDrunk.Studios — the public website per ADR-0070's Next.js stack) and two prospectively planned classes:
- SDK packages per ADR-0057's API versioning stance (TypeScript and other-language SDKs published to npm).
- Per-stack Web.UI consumer packages per ADR-0071's Web.UI Node split.

The Studios standup happened before ADR-0082 was drafted; its standup procedure was implicit. The walkthrough generalizes the Studios pattern so:
- The next TypeScript standup (typed SDK, per-stack Web.UI package) doesn't re-derive Node.js tooling decisions from the Studios commit history.
- The class boundary between Studios/TypeScript and Meta/Docs/Wiki is explicit (Studios is a *primary dev surface* with build/test/lint; Meta is content-mostly).
- The class boundary between Studios/TypeScript and a future mobile (React Native + Expo per ADR-0070 D3) class is also explicit — the walkthrough notes mobile is its own future class amendment per D2.

## Proposed Implementation

### `infrastructure/walkthroughs/node-standup-studios-typescript.md` — new walkthrough

```markdown
# Node Standup — Studios / TypeScript

**Applies to:** ADR-0082 D5 x–z (the Studios/TypeScript class-specific steps).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure — mandatory steps 1–18 still apply)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** {N1} (node-registration-mandatory), 11, 12, 27, 31, 32, 33, 41, 52.

## Goal

Stand up a TypeScript / React / Next-style Node. Three phases per ADR-0082 D3, with the .NET-stack layer replaced by the Node.js-stack layer.
- Class: `studios-typescript`.
- Output: a public GitHub repo, Node.js CI online, build/test/lint passing, the Grid context plumbing in place.

## Scope of this walkthrough

Covers:
- `HoneyDrunk.Studios` retroactively (the existing standup).
- Future SDK packages per ADR-0057 (TypeScript clients published to npm).
- Future per-stack `HoneyDrunk.Web.UI.*` packages per ADR-0071.

Does NOT cover:
- React Native + Expo mobile apps per ADR-0070 D3 — that is a future class amendment to ADR-0082 D2 with its own walkthrough (mobile shells have different store-submission, signing, OTA-update, and Bicep-irrelevant concerns).
- Tauri desktop clients — also a future class.
- TypeScript-only docs sites that ship via Docusaurus per ADR-0075 — currently treated as Meta/Docs/Wiki when the repo *is* the deliverable; classify as Studios/TypeScript only if there is meaningful TS application code (not just docs config).

## What is NOT in scope for Studios/TypeScript

- **No `.slnx`, no `Directory.Build.props`, no `HoneyDrunk.Standards` reference, no test projects of the .NET shape.** Replaced by Node.js equivalents.
- **No NuGet publication.** Publication target is npm (for SDK packages) or static site hosting (for HoneyDrunk.Studios). The NuGet-publishing OIDC federated credential pattern does NOT apply; the npm publishing credential (NPM_TOKEN org secret, or OIDC-trusted publishing once npm supports the operator's flow) is the equivalent.
- **No contract-shape canary on `.Abstractions`.** Equivalent if the TS package publishes a typed surface (an SDK) is the `tsc --emitDeclarationOnly` + an `api-extractor` or similar TS-API-shape check; for HoneyDrunk.Studios (a website) there is no published surface so no equivalent canary applies.

## Phase A — Architecture registration

Same as the other classes. Six steps per ADR-0082 D4 1–4 + 7 + 18:
1. Catalog rows in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`. Sector: Studios (for HoneyDrunk.Studios), AI (for SDK packages exposing AI surfaces), Frontend (for per-stack Web.UI packages — sector to be added if it does not exist).
2. Sector row in `constitution/sectors.md` with `Signal: Seed`.
3. Five-file context folder at `repos/{NodeName}/`.
4. `repo-to-node.yml` mapping in `HoneyDrunk.Actions/.github/config/`.
5. Standup ADR + initiative entry.

**Gate:** Phase A merges before Phase B.

## Phase B — GitHub repo creation (human-only)

1. Visit https://github.com/organizations/HoneyDrunkStudios/new.
2. Name: `HoneyDrunk.{NodeName}` (e.g., `HoneyDrunk.Studios`, `HoneyDrunk.SDK.TypeScript`).
3. Visibility: **Public** (default per ADR-0082 D4 step 5).
4. Branch protection on `main` — PR required, `pr-core / core` required check (Invariant 31), no force-push, no deletion.
5. Label seeding (idempotent CLI loop).
6. **Org-secret binding** per the matrix in `constitution/node-standup.md`. For SDK packages: `NPM_TOKEN` (or OIDC-trusted-publishing equivalent) is required for publishing. For Studios: deploy-target secrets (Cloudflare Pages, Vercel, etc. — whatever the standup ADR commits to) are bound here. `SONAR_TOKEN` if Sonar is opted into for TS.
7. Local clone made.

**Gate:** Phase B complete before Phase C.

## Phase C — Scaffold landing (bootstrap PR)

File-tree to land in the bootstrap PR:

```
/
├── .github/
│   ├── copilot-instructions.md
│   └── workflows/
│       ├── pr.yml                  (Node.js CI — see below)
│       ├── release.yml             (npm publish for SDK packages; static-site deploy for Studios)
│       ├── nightly-deps.yml        (npm-audit-equivalent reusable workflow per ADR-0009 — extending the reusable workflows to cover Node.js dep scanning is itself follow-up work if not yet shipped)
│       └── nightly-security.yml    (CodeQL on TypeScript per ADR-0009; semgrep optional)
├── .honeydrunk-review.yaml         (enabled: true)
├── .coderabbit.yaml                (per ADR-0079 D2; CodeRabbit handles TS/TSX well)
├── .nvmrc                          (pin Node.js LTS version)
├── .npmrc                          (registry pinning, save-exact behavior)
├── .gitignore                      (Node-specific: node_modules, .next, dist, etc.)
├── package.json                    (name, version 0.1.0, dependencies, scripts: build, test, lint, format)
├── tsconfig.json                   (strict: true, target ES2022, module ESNext for libraries / Bundler for Next-style)
├── eslint.config.{js,mjs}          (flat-config preferred; rules track HoneyDrunk.Studios conventions)
├── .prettierrc                     (or .prettierrc.json)
├── CHANGELOG.md                    (## [0.1.0] - YYYY-MM-DD)
├── CLAUDE.md                       (primary dev surface for Studios/TypeScript — yes)
├── LICENSE                         (MIT for public; per the Grid default)
├── README.md
└── src/                            (TS sources; structure per stack — `pages/`, `app/`, etc.)
```

`pr.yml` minimal caller (Node.js — direct CLI invocation per ADR-0012 D4, no marketplace wrapper):

```yaml
name: PR Core
on:
  pull_request:
    branches: [main]
permissions:
  contents: read
  pull-requests: write
jobs:
  core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - run: npm test -- --coverage
      # Plus the org's standard secret-scan + vulnerability-scan jobs, invoked via reusable workflows from HoneyDrunk.Actions when those exist for Node.js (or inlined direct CLI calls until they do per ADR-0012 D4).
```

(If a `HoneyDrunk.Actions` `pr-typescript.yml` reusable workflow exists by the time this packet is filed, replace the inline `steps:` with a `uses:` of that workflow. Per ADR-0082 D5 y, the wrapper-marketplace-action ban applies the same way it does for .NET — npm/Node CLIs are invoked directly.)

`release.yml` minimal caller for SDK packages (npm publish on SemVer tag):

```yaml
name: Release
on:
  push:
    tags: ['v*.*.*']
permissions:
  contents: write
  id-token: write       # for npm OIDC-trusted-publishing if/when adopted
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
          registry-url: 'https://registry.npmjs.org/'
      - run: npm ci
      - run: npm run build
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

(For HoneyDrunk.Studios, `release.yml` is replaced by a deploy workflow targeting the static-site host — Cloudflare Pages, Vercel, etc. — per whatever ADR commits to that target. The current Studios deploy stance is captured in the Studios repo's own workflow; this walkthrough doesn't re-derive it.)

## Web.UI design-token consumption (per-stack Web.UI packages only)

For per-stack `HoneyDrunk.Web.UI.*` packages per ADR-0071 D1 / Invariants 87–89:
- The package consumes design tokens from `HoneyDrunk.Web.UI` core; per-PDR re-derivation is a boundary violation per Invariant 87.
- Per-PDR CSS-variable overrides are permitted.
- The per-stack package does not depend on any Grid Node's runtime contracts (Invariant 89 — the dependency direction is one-way consumer → Web.UI).

## Post-merge

Post-merge update of branch-protection on `main`:
- Add the build/test/lint job from `pr.yml` as a required status check if `pr-core / core` doesn't already encompass them.
- For SDK packages: add the typed-API-shape check (`tsc --emitDeclarationOnly` + `api-extractor` or equivalent) as a required check once the throwaway breaking-change PR confirms it fires.

## v0.1.0 tag and first publish

For SDK packages:
- Human pushes `v0.1.0` tag.
- `release.yml` runs, publishes to npm using `NPM_TOKEN` (or OIDC-trusted-publishing).
- First non-bootstrap PR may now land — invariant 102 binds it.

For HoneyDrunk.Studios:
- No NPM publish. The deploy workflow's first run after scaffold-merge is the "first publish" equivalent.
```

## Affected Files

- `infrastructure/walkthroughs/node-standup-studios-typescript.md` (new)

## NuGet Dependencies

None.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`.

## Acceptance Criteria

- [ ] `infrastructure/walkthroughs/node-standup-studios-typescript.md` exists with the structure above
- [ ] Scope section explicitly names what's covered (Studios, SDK packages per ADR-0057, per-stack Web.UI packages per ADR-0071) and what's NOT (mobile per ADR-0070 D3, Tauri desktop, TS-only docs sites)
- [ ] "What is NOT in scope" section names .NET-class artifacts that don't apply
- [ ] Three phases covered; file-tree replaces .NET layout with Node.js equivalents
- [ ] `pr.yml` example invokes CLIs directly per ADR-0012 D4 (no wrapper marketplace actions for npm/Node); points to future `pr-typescript.yml` reusable workflow if one exists
- [ ] `release.yml` example covers npm publish for SDK packages; Studios deploy is noted as ADR-dependent and not re-derived
- [ ] Web.UI design-token section names Invariants 87–89 (per-PDR re-derivation is a boundary violation; consumer → Web.UI dependency direction)
- [ ] Companion docs link `constitution/node-standup.md` and `org-secret-repo-binding.md`
- [ ] Repo-level `CHANGELOG.md` updated for the new walkthrough

## Human Prerequisites

None.

## Referenced ADR Decisions

**ADR-0082 D2** — Studios/TypeScript class; mobile and Tauri are future class amendments.
**ADR-0082 D5 x–z** — TS replacements for .NET stack (`package.json`/`tsconfig.json`/ESLint+Prettier); Node.js CI; Web.UI design-token consumption when applicable.
**ADR-0082 D7** — Walkthrough unlocked by acceptance.
**ADR-0012 D4** — CLI-invocation discipline applies the same way for npm/Node as for dotnet.
**ADR-0057** — TypeScript SDK packaging direction.
**ADR-0070** — Frontend stack; mobile is React Native + Expo per D3 (out of scope here).
**ADR-0071** — Web.UI per-stack package model; Invariants 87–89 govern consumption.

## Constraints

- **Scope is explicit.** Covers Studios, SDK packages, per-stack Web.UI; mobile/Tauri/Docusaurus-docs are out of scope.
- **No marketplace wrappers.** ADR-0012 D4's CLI-invocation discipline applies to npm/Node the same way as to dotnet.
- **Studios deploy is ADR-dependent.** The walkthrough does not invent a Studios deploy target — it points at whatever ADR commits to it.
- **Web.UI Invariants 87–89 are inlined where applicable.**
- **PR body metadata.** Strict `Authorship: <enum>` + exactly one of `Packet:` / `Out-of-band reason:`.

## Labels

`chore`, `tier-2`, `meta`, `docs`, `studios`, `frontend`, `adr-0082`, `wave-3`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/node-standup-studios-typescript.md` — operational walkthrough for TypeScript / React / Next-style Node standups.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Generalize the HoneyDrunk.Studios standup precedent and prepare the recipe for future SDK and Web.UI standups.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 3.
- ADRs: ADR-0082 (D2, D5 x–z, D7), ADR-0012 D4, ADR-0057, ADR-0070, ADR-0071.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (canonical procedure doc).

**Constraints:**
- Scope (covered/uncovered) is explicit.
- CLI-invocation discipline per ADR-0012 D4 — no marketplace wrappers for npm/Node.
- Studios deploy target is not invented — points at the responsible ADR.
- Web.UI Invariants 87–89 inlined.
- PR body carries strict `Authorship: <enum>` + exactly one of `Packet:` / `Out-of-band reason:`.

**Key Files:**
- `infrastructure/walkthroughs/node-standup-studios-typescript.md` (new)

**Contracts:** None changed.
