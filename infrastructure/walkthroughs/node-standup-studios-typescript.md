# Node Standup — Studios / TypeScript

**Applies to:** ADR-0082 D5 x–z (the Studios/TypeScript class-specific steps).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure — mandatory steps 1–18 still apply)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** 102 (node-registration-mandatory), 11 (one repo per Node), 12 (CHANGELOG + README), 27 (shared version), 31 (tier-1 gate required), 32 (agent PRs link their packet), 33 (review/scope context coupling), 41 (new repos registered in `repos/`), 52 (cloud review on enabled repos), plus 87–89 (Web.UI design-token consumption, where applicable).

## Goal

Stand up a TypeScript / React / Next-style Node. Three phases per ADR-0082 D3, with the .NET-stack layer replaced by the Node.js-stack layer.

- Class: `studios-typescript`.
- Output: a public GitHub repo, Node.js CI online, build/test/lint passing, the Grid context plumbing in place.

## Scope of this walkthrough

Covers:

- `HoneyDrunk.Studios` retroactively (the existing standup that predated ADR-0082).
- Future SDK packages per ADR-0057 (TypeScript clients published to npm).
- Future per-stack `HoneyDrunk.Web.UI.*` packages per ADR-0071.

Does NOT cover:

- React Native + Expo mobile apps per ADR-0070 D3 — a future class amendment to ADR-0082 D2 with its own walkthrough (mobile shells have different store-submission, signing, OTA-update, and Bicep-irrelevant concerns).
- Tauri desktop clients — also a future class.
- TypeScript-only docs sites that ship via Docusaurus per ADR-0075 — treated as Meta/Docs/Wiki when the repo *is* the deliverable; classify as Studios/TypeScript only if there is meaningful TS application code (not just docs config).

## What is NOT in scope for Studios/TypeScript

- **No `.slnx`, no `Directory.Build.props`, no `HoneyDrunk.Standards` reference, no .NET-shaped test projects.** Replaced by Node.js equivalents.
- **No NuGet publication.** The publication target is npm (for SDK packages) or static-site hosting (for HoneyDrunk.Studios). The NuGet-publishing OIDC federated credential pattern does not apply; the npm publishing credential (`NPM_TOKEN` org secret, or OIDC-trusted publishing once npm supports the operator's flow) is the equivalent.
- **No contract-shape canary on `.Abstractions`.** The equivalent, if the TS package publishes a typed surface (an SDK), is a `tsc --emitDeclarationOnly` + `api-extractor`-style TS-API-shape check; for HoneyDrunk.Studios (a website) there is no published surface, so no equivalent canary applies.

## Phase A — Architecture registration

Same as the other classes (ADR-0082 D4 steps 1–4, 7, 18):

1. Catalog rows in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`. Sector: Studios (HoneyDrunk.Studios), AI (SDK packages exposing AI surfaces), or Creator/Frontend (per-stack Web.UI packages — sector added if it does not exist).
2. Sector row in `constitution/sectors.md` with `Signal: Seed`.
3. Five-file context folder at `repos/{NodeName}/`.
4. `repo-to-node.yml` mapping in `HoneyDrunk.Actions/.github/config/`.
5. Standup ADR + initiative entry.

**Gate:** Phase A merges before Phase B.

## Phase B — GitHub repo creation (human-only)

1. Visit `https://github.com/organizations/HoneyDrunkStudios/new`.
2. Name: `HoneyDrunk.{NodeName}` (e.g. `HoneyDrunk.Studios`, `HoneyDrunk.SDK.TypeScript`).
3. Visibility: **Public** (default per ADR-0082 D4 step 5).
4. Branch protection on `main` — PR required, `pr-core / core` required check (Invariant 31), no force-push, no deletion.
5. Label seeding (idempotent CLI loop).
6. **Org-secret binding** per the matrix in `constitution/node-standup.md`, via `org-secret-repo-binding.md`. For SDK packages: `NPM_TOKEN` (or OIDC-trusted-publishing equivalent) is required for publishing. For Studios: deploy-target secrets (Cloudflare Pages, Vercel, etc. — whatever the standup ADR commits to) are bound here. `SONAR_TOKEN` if Sonar is opted into for TS.
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
└── src/                            (TS sources; structure per stack — pages/, app/, etc.)
```

`pr.yml` minimal caller (Node.js — direct CLI invocation per ADR-0012 D4 / Invariant 38, no marketplace wrapper):

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
      # Plus the org's standard secret-scan + vulnerability-scan jobs, invoked via reusable workflows from
      # HoneyDrunk.Actions when those exist for Node.js (or inlined direct CLI calls until they do, per ADR-0012 D4).
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

(For HoneyDrunk.Studios, `release.yml` is replaced by a deploy workflow targeting the static-site host — Cloudflare Pages, Vercel, etc. — per whatever ADR commits to that target. The current Studios deploy stance lives in the Studios repo's own workflow; this walkthrough does not re-derive it.)

## Web.UI design-token consumption (per-stack Web.UI packages only)

For per-stack `HoneyDrunk.Web.UI.*` packages per ADR-0071 D1 / Invariants 87–89:

- The package consumes design tokens from `HoneyDrunk.Web.UI` core; per-PDR re-derivation is a boundary violation (Invariant 87 — Grid frontend surfaces consume tokens and primitive CSS from `HoneyDrunk.Web.UI`).
- Per-PDR CSS-variable overrides are permitted.
- The per-stack package does not depend on any Grid Node's runtime contracts (Invariant 89 — the dependency direction is one-way, consumer → Web.UI).

## Post-merge

Post-merge update of branch protection on `main`:

- Add the build/test/lint job from `pr.yml` as a required status check if `pr-core / core` does not already encompass it.
- For SDK packages: add the typed-API-shape check (`tsc --emitDeclarationOnly` + `api-extractor` or equivalent) as a required check once the throwaway breaking-change PR confirms it fires.

## v0.1.0 tag and first publish

For SDK packages:

1. The human pushes the `v0.1.0` tag.
2. `release.yml` runs and publishes to npm using `NPM_TOKEN` (or OIDC-trusted-publishing).
3. The first non-bootstrap PR may now land — invariant 102 binds it.

For HoneyDrunk.Studios:

- No npm publish. The deploy workflow's first run after scaffold-merge is the "first publish" equivalent.
