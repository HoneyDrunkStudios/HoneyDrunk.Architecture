---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.UI
labels: ["feature", "tier-2", "web-ui", "scaffold", "adr-0071"]
dependencies: ["packet:01", "packet:02", "packet:03"]
adrs: ["ADR-0071", "ADR-0070", "ADR-0035", "ADR-0039", "ADR-0009"]
accepts: ADR-0071
wave: 3
initiative: adr-0071-web-ui-standup
node: honeydrunk-web-ui
---

# Feature: Stand up the HoneyDrunk.Web.UI repo — pnpm monorepo, five packages, tokens + CSS shipped at 0.1.0, CI with npm publish-on-tag

## Summary
Bring the empty `HoneyDrunk.Web.UI` repo from zero to first-shippable state per ADR-0071 D5 (Phase 1) and D6 (Package layout). Land the pnpm-workspace monorepo, the five package families (`@honeydrunk/web-ui-tokens` + `@honeydrunk/web-ui-css` shipped at 0.1.0 with real content; `@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native` as honest 0.0.0 placeholders), the D6 contracts surface inside `@honeydrunk/web-ui-tokens` (color/spacing/typography/radii/shadows/motion/breakpoints/z-index scales), the primitive CSS bundle inside `@honeydrunk/web-ui-css` (reset + base typography + utility classes), Vitest-based unit tests for the tokens shape and the CSS bundle, and the standard CI pipeline (PR core + release with npm publish-on-tag + nightly deps + nightly security).

This is the unblocker for Studios' tokens-migration follow-up packet, Notify Cloud admin's tokens + CSS consumption, and every PDR-driven consumer app's first scaffolding packet. After this packet merges and `v0.1.0` tags, those consumers can take a `@honeydrunk/web-ui-tokens@0.1.0` and `@honeydrunk/web-ui-css@0.1.0` dependency and start wiring their own work in parallel.

**Invariant numbers assigned.** Web.UI constitutional invariants are `{N1}` (Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`), `{N2}` (`HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios), and `{N3}` (`HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts). These placeholders are substituted with the actual assigned numbers in place pre-push, after packet 02 of this initiative merges and lands the actual numeric assignments (expected block 87–89 per reservation registry).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Web.UI`

## Motivation
ADR-0071 D5 specifies the Phase 1 deliverable: "Repo created; tokens + primitive CSS shipped as `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css`. No components yet. Studios' existing tokens migrate in as Phase 1's first input. The Studios website becomes the first consumer immediately." Packet 03 created the GitHub repo and cloned the local tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Web.UI/` (`.gitignore`, `LICENSE`, placeholder `README.md` only), verified the `@honeydrunk` npm scope, and seeded `NPM_TOKEN`. Catalogs, Web.UI invariants (`{N1}`, `{N2}`, `{N3}`), and the Studios tokens inventory (at `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` in the Architecture repo) are already in place. This packet ships the code.

Until this packet ships: every consumer named in ADR-0071 has no `@honeydrunk/web-ui-tokens@0.1.0` or `@honeydrunk/web-ui-css@0.1.0` to reference; Studios' migration is blocked; Notify Cloud admin invents its own colors; every queued consumer-app PDR pays the per-surface design tax independently. ADR-0071 D5 explicitly requires tokens + CSS in the first commit; the three placeholder packages are intentional honest gaps that ship at 0.0.0 and gain real implementations at Phase 2/3/4 per consumer demand.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Web.UI/
├── package.json                      (workspace root — name "@honeydrunk/web-ui-workspace", private:true)
├── pnpm-workspace.yaml               (lists ./packages/* as workspaces)
├── pnpm-lock.yaml                    (committed lockfile)
├── tsconfig.base.json                (shared TypeScript base; per-package tsconfig extends this)
├── .npmrc                            (npm registry; engine-strict; auto-install-peers if applicable)
├── CHANGELOG.md                      (repo-level — ## [0.1.0] - YYYY-MM-DD)
├── README.md
├── LICENSE                           (placed by packet 03; verify content matches Grid LICENSE)
├── .editorconfig
├── .gitignore                        (from packet 03; extend with node_modules, dist, .turbo, .next, etc.)
├── .github/
│   └── workflows/
│       ├── pr-core.yml               (build + test all packages on PR)
│       ├── release.yml               (on tag v*.*.*, build + npm publish for shipped packages)
│       ├── nightly-deps.yml          (grouped deps PR per ADR-0009)
│       └── nightly-security.yml      (security audit; manual close per memory feedback_manual_close_security_issues)
└── packages/
    ├── tokens/
    │   ├── package.json              (name: "@honeydrunk/web-ui-tokens", version: 0.1.0, real content)
    │   ├── README.md
    │   ├── CHANGELOG.md              (## [0.1.0])
    │   ├── tsconfig.json             (extends tsconfig.base.json)
    │   ├── src/
    │   │   ├── index.ts              (re-export tokens object + types)
    │   │   ├── tokens.ts             (the DesignTokens JSON-as-TS const — see content section)
    │   │   ├── types.ts              (TypeScript type definitions for DesignTokens)
    │   │   └── build-css.ts          (build-time script: emits dist/css/variables.css from tokens)
    │   ├── dist/                     (gitignored — built artifacts)
    │   │   ├── index.js              (CJS)
    │   │   ├── index.mjs             (ESM)
    │   │   ├── index.d.ts            (types)
    │   │   ├── tokens.json           (stack-agnostic JSON for non-TS consumers)
    │   │   └── css/
    │   │       └── variables.css     (CSS variables emission of tokens)
    │   ├── scripts/
    │   │   └── emit-json-and-css.mjs (build-script entrypoint — produces tokens.json + variables.css)
    │   └── test/
    │       └── tokens.test.ts        (Vitest — structural assertion: every sector key from sectors.md is present)
    ├── css/
    │   ├── package.json              (name: "@honeydrunk/web-ui-css", version: 0.1.0, real content)
    │   ├── README.md
    │   ├── CHANGELOG.md              (## [0.1.0])
    │   ├── tsconfig.json
    │   ├── src/
    │   │   ├── reset.css             (modern CSS reset — sane defaults)
    │   │   ├── typography.css        (base typography for h1-h6, p, ul, ol, blockquote, code, etc.)
    │   │   ├── utilities.css         (utility class taxonomy — hd-m-*, hd-p-*, hd-flex, hd-grid, hd-text-*, etc.)
    │   │   └── index.css             (@imports for reset + typography + utilities; single entrypoint consumers import)
    │   └── test/
    │       └── css-bundle.test.ts    (Vitest — assert dist/index.css contains hd- prefixed selectors and known utility classes)
    ├── react/
    │   ├── package.json              (name: "@honeydrunk/web-ui-react", version: 0.0.0 PLACEHOLDER)
    │   ├── README.md                 (states: "Placeholder. Phase 2 — first components ship at first non-Studios consumer demand.")
    │   ├── CHANGELOG.md              (## [0.0.0] - YYYY-MM-DD — "Placeholder package created.")
    │   ├── tsconfig.json
    │   └── src/
    │       └── index.ts              (export const PLACEHOLDER = true; /* see README */)
    ├── blazor/
    │   ├── HoneyDrunk.Web.UI.Blazor.csproj  (placeholder .NET project; targets net10.0; HoneyDrunk.Standards reference)
    │   ├── README.md                 (states: "Placeholder. Phase 3 — first components ship at first Blazor consumer demand.")
    │   ├── CHANGELOG.md              (## [0.0.0] - YYYY-MM-DD)
    │   └── Placeholder.cs            (// Placeholder. No implementation on day one. See README.)
    └── native/
        ├── package.json              (name: "@honeydrunk/web-ui-native", version: 0.0.0 PLACEHOLDER)
        ├── README.md                 (states: "Placeholder. Phase 4 — first components ship at first mobile PDR.")
        ├── CHANGELOG.md              (## [0.0.0] - YYYY-MM-DD)
        ├── tsconfig.json
        └── src/
            └── index.ts              (export const PLACEHOLDER = true; /* see README */)
```

**Placeholder discipline (matches the `HoneyDrunk.Files.AzureBlob` pattern from ADR-0061's scaffold packet):** The three placeholder packages (`react`, `blazor`, `native`) ship at version **0.0.0** (not 0.1.0). Their `index.ts` / `Placeholder.cs` files carry only the placeholder comment. Their CHANGELOGs explicitly name them as placeholders. Their READMEs name the phase at which the real implementation lands. This is the honest shape: shipping a stub with `NotImplementedException` or empty components would lie about the package's status and force a churn-PR when the real implementation lands.

Note that this **departs from the standard invariant 27** ("all projects in a solution share one version and move together") — but invariant 27 is .NET-centric and references csproj `<Version>`. The JS monorepo posture is per-package versioning, which is the standard pnpm-workspace pattern; explicitly call this out in the PR body. The shipped packages (`tokens`, `css`) move together at 0.1.0; the placeholders stay at 0.0.0 until their respective Phase ships. **Add `HoneyDrunk.Web.UI.Blazor` to the workspace-versioning posture as a NuGet placeholder at 0.0.0** — it does not version-couple to the npm packages since it ships separately. This is the load-bearing departure from the .NET monorepo precedent.

### Workspace root — `package.json`

```json
{
  "name": "@honeydrunk/web-ui-workspace",
  "version": "0.1.0",
  "private": true,
  "description": "HoneyDrunk Grid — cross-stack design system monorepo. Tokens, primitive CSS, component contracts.",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI.git"
  },
  "homepage": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI",
  "engines": {
    "node": ">=22"
  },
  "packageManager": "pnpm@9.0.0",
  "scripts": {
    "build": "pnpm -r --filter './packages/tokens' --filter './packages/css' build",
    "test": "pnpm -r --filter './packages/tokens' --filter './packages/css' test",
    "lint": "pnpm -r --filter './packages/tokens' --filter './packages/css' lint",
    "ci": "pnpm run build && pnpm run test"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "vitest": "^2.1.0",
    "@types/node": "^22.0.0"
  }
}
```

The `engines.node: ">=22"` field enforces Node 22 minimum — the LTS line at scoping time.

### Workspace declaration — `pnpm-workspace.yaml`

```yaml
packages:
  - "packages/tokens"
  - "packages/css"
  - "packages/react"
  - "packages/native"
```

`packages/blazor` is excluded from the pnpm workspace because it's a .NET project, not an npm package. The Blazor placeholder's `HoneyDrunk.Web.UI.Blazor.csproj` is treated as a sibling .NET project that ships via NuGet, not npm — the CI handles it separately.

### Base TypeScript config — `tsconfig.base.json`

Pinned per the refine-pass guidance:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2022", "DOM"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "isolatedModules": true,
    "noEmit": false
  }
}
```

Per-package `tsconfig.json` extends this and overrides `outDir` / `rootDir` / `include` as needed.

### Package — `packages/tokens/`

#### `packages/tokens/package.json`

```json
{
  "name": "@honeydrunk/web-ui-tokens",
  "version": "0.1.0",
  "description": "HoneyDrunk Grid design tokens — color, spacing, typography, radii, shadows, motion, breakpoints, z-index. Stack-agnostic JSON + CSS variables.",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI.git",
    "directory": "packages/tokens"
  },
  "main": "./dist/index.js",
  "module": "./dist/index.mjs",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.mjs",
      "require": "./dist/index.js"
    },
    "./json": "./dist/tokens.json",
    "./css/variables.css": "./dist/css/variables.css"
  },
  "files": [
    "dist",
    "README.md",
    "CHANGELOG.md"
  ],
  "scripts": {
    "build": "tsc -p tsconfig.json && node scripts/emit-json-and-css.mjs",
    "test": "vitest run",
    "lint": "tsc --noEmit"
  },
  "publishConfig": {
    "access": "public"
  },
  "engines": {
    "node": ">=22"
  }
}
```

#### `packages/tokens/src/tokens.ts`

The tokens object — sector colors from `constitution/sectors.md` are mandatory and round-trip exactly per `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` (in the Architecture repo). Other categories are sensible Tailwind-shaped defaults; Studios' migration packet (out of scope) reconciles any drift.

```typescript
/**
 * HoneyDrunk Grid design tokens.
 *
 * The single source of truth for the Grid's visual language.
 * Stack-agnostic — consumed by React, Blazor, React Native, and any
 * other consumer through the JSON export or the CSS-variables emission.
 *
 * Sector colors round-trip from constitution/sectors.md exactly.
 */
export const tokens = {
  color: {
    sector: {
      core: "#7B61FF",       // violetFlux
      ops: "#FF8C00",        // cyberOrange
      meta: "#FFFF00",       // neonYellow
      honeynet: "#00FF41",   // matrixGreen
      creator: "#14B8A6",    // chromeTeal
      market: "#F5B700",     // aurumGold
      honeyplay: "#FF2A6D",  // neonPink
      cyberware: "#00D1FF",  // electricBlue
      ai: "#D946EF",         // synthMagenta
    },
    // Neutral palette — Tailwind-shaped 50-950 scale; Studios' migration packet reconciles to actuals.
    neutral: {
      50: "#fafafa",
      100: "#f4f4f5",
      200: "#e4e4e7",
      300: "#d4d4d8",
      400: "#a1a1aa",
      500: "#71717a",
      600: "#52525b",
      700: "#3f3f46",
      800: "#27272a",
      900: "#18181b",
      950: "#09090b",
    },
  },
  space: {
    0: "0",
    1: "4px",
    2: "8px",
    3: "12px",
    4: "16px",
    6: "24px",
    8: "32px",
    12: "48px",
    16: "64px",
    24: "96px",
  },
  typography: {
    fontFamily: {
      sans: "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
      mono: "ui-monospace, 'SF Mono', 'Cascadia Code', Consolas, monospace",
    },
    fontSize: {
      xs: "12px",
      sm: "14px",
      base: "16px",
      lg: "18px",
      xl: "20px",
      "2xl": "24px",
      "3xl": "30px",
      "4xl": "36px",
      "5xl": "48px",
    },
    fontWeight: {
      regular: 400,
      medium: 500,
      semibold: 600,
      bold: 700,
    },
    lineHeight: {
      tight: 1.2,
      normal: 1.5,
      relaxed: 1.75,
    },
  },
  radius: {
    none: "0",
    sm: "4px",
    md: "8px",
    lg: "12px",
    xl: "16px",
    full: "9999px",
  },
  shadow: {
    sm: "0 1px 2px rgba(0,0,0,0.05)",
    md: "0 4px 6px rgba(0,0,0,0.1)",
    lg: "0 10px 15px rgba(0,0,0,0.1)",
    xl: "0 20px 25px rgba(0,0,0,0.1)",
  },
  motion: {
    duration: {
      fast: "150ms",
      normal: "250ms",
      slow: "400ms",
    },
    easing: {
      standard: "cubic-bezier(0.4, 0, 0.2, 1)",
      in: "cubic-bezier(0.4, 0, 1, 1)",
      out: "cubic-bezier(0, 0, 0.2, 1)",
      inOut: "cubic-bezier(0.4, 0, 0.2, 1)",
    },
  },
  breakpoint: {
    mobile: "640px",
    tablet: "768px",
    desktop: "1024px",
    wide: "1280px",
  },
  zIndex: {
    base: 0,
    dropdown: 1000,
    sticky: 1100,
    modal: 1300,
    toast: 1400,
    tooltip: 1500,
  },
} as const;

export type Tokens = typeof tokens;
```

#### `packages/tokens/src/index.ts`

```typescript
export { tokens } from "./tokens.js";
export type { Tokens } from "./tokens.js";
```

#### `packages/tokens/scripts/emit-json-and-css.mjs`

Build-script entry-point. **Uses `fileURLToPath()` for cross-platform path handling — NOT `outPath.pathname.replace(/^\//, '')` which is broken on Windows** (per refine-pass note):

```javascript
#!/usr/bin/env node
// Build script: imports the compiled tokens module and emits two artifacts:
//   1. dist/tokens.json — stack-agnostic JSON for non-TS consumers
//   2. dist/css/variables.css — CSS-variables emission consumable by primitive CSS and per-PDR consumers

import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import { tokens } from "../dist/index.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const distDir = join(__dirname, "..", "dist");
const cssDir = join(distDir, "css");

await mkdir(cssDir, { recursive: true });

// Emit JSON
await writeFile(join(distDir, "tokens.json"), JSON.stringify(tokens, null, 2), "utf8");

// Emit CSS variables
function flatten(obj, prefix = "hd") {
  const lines = [];
  for (const [key, value] of Object.entries(obj)) {
    const kebab = key.replace(/([A-Z])/g, "-$1").toLowerCase();
    const name = `${prefix}-${kebab}`;
    if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      lines.push(...flatten(value, name));
    } else {
      lines.push(`  --${name}: ${value};`);
    }
  }
  return lines;
}

const cssLines = [":root {", ...flatten(tokens), "}"];
await writeFile(join(cssDir, "variables.css"), cssLines.join("\n") + "\n", "utf8");

console.log(`Emitted ${join(distDir, "tokens.json")} and ${join(cssDir, "variables.css")}`);
```

The `fileURLToPath()` import + `dirname()` derivation is the cross-platform pattern that works on both Windows and POSIX. **Do not use `import.meta.url`'s pathname directly** (e.g., `new URL("..", import.meta.url).pathname`) — on Windows that yields a leading slash that breaks `mkdir` and `writeFile`.

#### `packages/tokens/test/tokens.test.ts`

**Structural assertion only — iterates sector keys from a known list, does NOT hex-couple.** Per the refine-pass guidance, the test must remain valid if `constitution/sectors.md` rebrands colors.

```typescript
import { describe, it, expect } from "vitest";
import { tokens } from "../src/tokens.js";

describe("@honeydrunk/web-ui-tokens", () => {
  // Sector keys that constitution/sectors.md defines today.
  // If sectors.md adds a new sector or renames one, this list must update in lockstep.
  // Hex values are intentionally NOT asserted here — a palette rebrand should not break this test.
  const SECTOR_KEYS = [
    "core",
    "ops",
    "meta",
    "honeynet",
    "creator",
    "market",
    "honeyplay",
    "cyberware",
    "ai",
  ] as const;

  it("exposes a color.sector record covering every sector key", () => {
    for (const key of SECTOR_KEYS) {
      expect(tokens.color.sector).toHaveProperty(key);
      expect(typeof tokens.color.sector[key as keyof typeof tokens.color.sector]).toBe("string");
      // Sanity: the value looks like a hex color.
      expect(tokens.color.sector[key as keyof typeof tokens.color.sector]).toMatch(/^#[0-9a-fA-F]{3,8}$/);
    }
  });

  it("exposes the canonical token categories", () => {
    expect(tokens).toHaveProperty("color");
    expect(tokens).toHaveProperty("space");
    expect(tokens).toHaveProperty("typography");
    expect(tokens).toHaveProperty("radius");
    expect(tokens).toHaveProperty("shadow");
    expect(tokens).toHaveProperty("motion");
    expect(tokens).toHaveProperty("breakpoint");
    expect(tokens).toHaveProperty("zIndex");
  });

  it("space scale is 4px-based and includes the canonical steps", () => {
    expect(tokens.space).toHaveProperty("0");
    expect(tokens.space).toHaveProperty("1");
    expect(tokens.space).toHaveProperty("4");
    expect(tokens.space).toHaveProperty("16");
  });

  it("typography exposes fontFamily / fontSize / fontWeight / lineHeight", () => {
    expect(tokens.typography).toHaveProperty("fontFamily");
    expect(tokens.typography).toHaveProperty("fontSize");
    expect(tokens.typography).toHaveProperty("fontWeight");
    expect(tokens.typography).toHaveProperty("lineHeight");
  });

  it("breakpoints cover mobile / tablet / desktop / wide", () => {
    expect(tokens.breakpoint).toHaveProperty("mobile");
    expect(tokens.breakpoint).toHaveProperty("tablet");
    expect(tokens.breakpoint).toHaveProperty("desktop");
    expect(tokens.breakpoint).toHaveProperty("wide");
  });
});
```

### Package — `packages/css/`

#### `packages/css/package.json`

```json
{
  "name": "@honeydrunk/web-ui-css",
  "version": "0.1.0",
  "description": "HoneyDrunk Grid primitive CSS — reset, base typography, utility classes. Built on @honeydrunk/web-ui-tokens CSS variables.",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI.git",
    "directory": "packages/css"
  },
  "main": "./dist/index.css",
  "exports": {
    ".": "./dist/index.css",
    "./reset.css": "./dist/reset.css",
    "./typography.css": "./dist/typography.css",
    "./utilities.css": "./dist/utilities.css"
  },
  "files": [
    "dist",
    "README.md",
    "CHANGELOG.md"
  ],
  "scripts": {
    "build": "node scripts/copy-css.mjs",
    "test": "vitest run",
    "lint": "echo 'no lint for CSS package'"
  },
  "publishConfig": {
    "access": "public"
  },
  "peerDependencies": {
    "@honeydrunk/web-ui-tokens": "^0.1.0"
  },
  "engines": {
    "node": ">=22"
  }
}
```

The peerDependency declaration: consumers of `@honeydrunk/web-ui-css` must also install `@honeydrunk/web-ui-tokens` because the CSS uses the variables emitted by the tokens package. This makes the dependency explicit and consumer-resolved.

#### `packages/css/src/reset.css`

A minimal modern reset. Names follow `hd-` prefix where applicable (for the utility classes; the reset uses universal/type selectors):

```css
/* HoneyDrunk Web.UI Primitive CSS — Reset */

*, *::before, *::after {
  box-sizing: border-box;
}

* {
  margin: 0;
}

html, body {
  height: 100%;
}

body {
  line-height: var(--hd-typography-line-height-normal, 1.5);
  -webkit-font-smoothing: antialiased;
}

img, picture, video, canvas, svg {
  display: block;
  max-width: 100%;
}

input, button, textarea, select {
  font: inherit;
}

p, h1, h2, h3, h4, h5, h6 {
  overflow-wrap: break-word;
}
```

#### `packages/css/src/typography.css`

```css
/* HoneyDrunk Web.UI Primitive CSS — Base Typography */

body {
  font-family: var(--hd-typography-font-family-sans);
  font-size: var(--hd-typography-font-size-base);
  font-weight: var(--hd-typography-font-weight-regular);
  color: var(--hd-color-neutral-900);
}

h1 { font-size: var(--hd-typography-font-size-5xl); font-weight: var(--hd-typography-font-weight-bold); line-height: var(--hd-typography-line-height-tight); }
h2 { font-size: var(--hd-typography-font-size-4xl); font-weight: var(--hd-typography-font-weight-bold); line-height: var(--hd-typography-line-height-tight); }
h3 { font-size: var(--hd-typography-font-size-3xl); font-weight: var(--hd-typography-font-weight-semibold); line-height: var(--hd-typography-line-height-tight); }
h4 { font-size: var(--hd-typography-font-size-2xl); font-weight: var(--hd-typography-font-weight-semibold); line-height: var(--hd-typography-line-height-normal); }
h5 { font-size: var(--hd-typography-font-size-xl); font-weight: var(--hd-typography-font-weight-medium); line-height: var(--hd-typography-line-height-normal); }
h6 { font-size: var(--hd-typography-font-size-lg); font-weight: var(--hd-typography-font-weight-medium); line-height: var(--hd-typography-line-height-normal); }

code, pre {
  font-family: var(--hd-typography-font-family-mono);
}
```

#### `packages/css/src/utilities.css`

A minimal utility taxonomy with the `hd-` prefix:

```css
/* HoneyDrunk Web.UI Primitive CSS — Utility Classes */

/* Display */
.hd-block { display: block; }
.hd-inline-block { display: inline-block; }
.hd-inline { display: inline; }
.hd-flex { display: flex; }
.hd-inline-flex { display: inline-flex; }
.hd-grid { display: grid; }
.hd-hidden { display: none; }

/* Flex */
.hd-flex-row { flex-direction: row; }
.hd-flex-col { flex-direction: column; }
.hd-items-center { align-items: center; }
.hd-items-start { align-items: flex-start; }
.hd-items-end { align-items: flex-end; }
.hd-justify-center { justify-content: center; }
.hd-justify-between { justify-content: space-between; }
.hd-justify-start { justify-content: flex-start; }
.hd-justify-end { justify-content: flex-end; }
.hd-gap-1 { gap: var(--hd-space-1); }
.hd-gap-2 { gap: var(--hd-space-2); }
.hd-gap-3 { gap: var(--hd-space-3); }
.hd-gap-4 { gap: var(--hd-space-4); }

/* Margin */
.hd-m-0 { margin: var(--hd-space-0); }
.hd-m-1 { margin: var(--hd-space-1); }
.hd-m-2 { margin: var(--hd-space-2); }
.hd-m-4 { margin: var(--hd-space-4); }

/* Padding */
.hd-p-0 { padding: var(--hd-space-0); }
.hd-p-1 { padding: var(--hd-space-1); }
.hd-p-2 { padding: var(--hd-space-2); }
.hd-p-4 { padding: var(--hd-space-4); }

/* Text */
.hd-text-left { text-align: left; }
.hd-text-center { text-align: center; }
.hd-text-right { text-align: right; }

/* Color (a small starter set; consumers extend via CSS-variable cascade) */
.hd-text-neutral-900 { color: var(--hd-color-neutral-900); }
.hd-text-neutral-500 { color: var(--hd-color-neutral-500); }
.hd-bg-neutral-50 { background-color: var(--hd-color-neutral-50); }
.hd-bg-neutral-900 { background-color: var(--hd-color-neutral-900); }

/* Border radius */
.hd-rounded-none { border-radius: var(--hd-radius-none); }
.hd-rounded-sm { border-radius: var(--hd-radius-sm); }
.hd-rounded-md { border-radius: var(--hd-radius-md); }
.hd-rounded-lg { border-radius: var(--hd-radius-lg); }
.hd-rounded-full { border-radius: var(--hd-radius-full); }

/* Shadow */
.hd-shadow-sm { box-shadow: var(--hd-shadow-sm); }
.hd-shadow-md { box-shadow: var(--hd-shadow-md); }
.hd-shadow-lg { box-shadow: var(--hd-shadow-lg); }
```

#### `packages/css/src/index.css`

The single entrypoint:

```css
@import "./reset.css";
@import "./typography.css";
@import "./utilities.css";
```

#### `packages/css/scripts/copy-css.mjs`

Cross-platform CSS copy script using `fileURLToPath()`:

```javascript
#!/usr/bin/env node
// Build script: copies src/*.css to dist/ for publishing.

import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdir, copyFile, readdir } from "node:fs/promises";

const __dirname = dirname(fileURLToPath(import.meta.url));
const srcDir = join(__dirname, "..", "src");
const distDir = join(__dirname, "..", "dist");

await mkdir(distDir, { recursive: true });

const files = await readdir(srcDir);
for (const file of files) {
  if (file.endsWith(".css")) {
    await copyFile(join(srcDir, file), join(distDir, file));
    console.log(`Copied ${file}`);
  }
}
```

#### `packages/css/test/css-bundle.test.ts`

```typescript
import { describe, it, expect } from "vitest";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

describe("@honeydrunk/web-ui-css", () => {
  it("dist/index.css imports reset, typography, and utilities", async () => {
    const indexCss = await readFile(join(__dirname, "..", "dist", "index.css"), "utf8");
    expect(indexCss).toContain("reset.css");
    expect(indexCss).toContain("typography.css");
    expect(indexCss).toContain("utilities.css");
  });

  it("utilities.css uses the hd- prefix on every class", async () => {
    const utilities = await readFile(join(__dirname, "..", "dist", "utilities.css"), "utf8");
    // Every class selector in the file should be hd-prefixed.
    const classMatches = utilities.match(/^\s*\.([a-z][\w-]*)/gm) ?? [];
    for (const match of classMatches) {
      const className = match.trim().slice(1);
      expect(className).toMatch(/^hd-/);
    }
  });

  it("reset.css sets box-sizing: border-box on universal selector", async () => {
    const reset = await readFile(join(__dirname, "..", "dist", "reset.css"), "utf8");
    expect(reset).toMatch(/box-sizing:\s*border-box/);
  });
});
```

### Placeholder packages — `packages/react/`, `packages/blazor/`, `packages/native/`

Each ships at **version 0.0.0** with a minimal placeholder file, a README that explicitly names the phase at which the real implementation lands, and a CHANGELOG with a `## [0.0.0]` entry.

#### `packages/react/package.json`

```json
{
  "name": "@honeydrunk/web-ui-react",
  "version": "0.0.0",
  "description": "HoneyDrunk Grid React components — placeholder. Phase 2: first components ship at first non-Studios consumer demand. See README.",
  "license": "MIT",
  "private": true,
  "engines": {
    "node": ">=22"
  }
}
```

Note **`"private": true`** — the placeholder must NOT publish to npm. Only `tokens` and `css` are published at v0.1.0. The `release.yml` workflow's publish step is filtered to exclude `private` packages.

#### `packages/react/src/index.ts`

```typescript
// Placeholder. No implementation on day one — see README.
//
// Phase 2: the first React component pack (Button, Input, Label, Card,
// Modal, Toast, Alert, Spinner, Skeleton) ships at first non-Studios
// consumer demand. At that time this file is replaced with the real
// implementations and the package version bumps from 0.0.0 to 0.1.0.
export const PLACEHOLDER = true;
```

#### `packages/react/README.md`

```markdown
# @honeydrunk/web-ui-react — Placeholder

**Status:** Placeholder. No implementation on day one.

**Phase 2:** First React component pack (Button, Input, Label, Card, Modal, Toast, Alert, Spinner, Skeleton) ships at first non-Studios consumer demand. The phasing matches consumer demand — the Node does not pre-ship surface it does not have consumers for.

For now, consume `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` directly; build product-specific components on top of those primitives.
```

#### `packages/blazor/HoneyDrunk.Web.UI.Blazor.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Razor">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <Version>0.0.0</Version>
    <Description>HoneyDrunk Grid Blazor components — placeholder. Phase 3: first components ship at first Blazor consumer demand. See README.</Description>
    <Authors>HoneyDrunk Studios</Authors>
    <PackageProjectUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI</PackageProjectUrl>
    <RepositoryUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI</RepositoryUrl>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <PackageReadmeFile>README.md</PackageReadmeFile>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <None Include="README.md" Pack="true" PackagePath="\" />
  </ItemGroup>
</Project>
```

`<IsPackable>false</IsPackable>` ensures the placeholder does not publish to NuGet at v0.0.0. The first feature packet that implements Blazor components flips `IsPackable` to `true` and bumps the version. Add `HoneyDrunk.Standards` reference is **deferred** to that future packet — the placeholder doesn't need analyzers since there's nothing to analyze.

#### `packages/blazor/Placeholder.cs`

```csharp
// Placeholder. No implementation on day one — see README.
//
// Phase 3: the first Blazor component or two ships at first Blazor
// consumer demand. At that time this file is replaced with the real
// component implementations, IsPackable flips to true, the package
// version bumps from 0.0.0, and HoneyDrunk.Standards is referenced.
namespace HoneyDrunk.Web.UI.Blazor;

internal static class Placeholder
{
}
```

#### `packages/native/package.json` and `packages/native/src/index.ts`

Same shape as the React placeholder — `"private": true`, version 0.0.0, placeholder `index.ts`, README naming Phase 4 (first mobile PDR) as the trigger.

### Repo-level `README.md`

```markdown
# HoneyDrunk.Web.UI

Cross-stack design system for the HoneyDrunk Grid. Owns design tokens, primitive CSS, and component contracts shared across React, Blazor, and React Native consumers. Tokens cross-stack; components per-stack.

## Packages

| Package | Stack | Version | Status |
|---------|-------|---------|--------|
| `@honeydrunk/web-ui-tokens` | stack-agnostic | 0.1.0 | Shipping — design tokens (JSON + CSS variables) |
| `@honeydrunk/web-ui-css` | web (React + Blazor) | 0.1.0 | Shipping — primitive CSS bundle (reset + typography + utilities) |
| `@honeydrunk/web-ui-react` | React | 0.0.0 | Placeholder — first components ship at first non-Studios consumer demand |
| `HoneyDrunk.Web.UI.Blazor` (NuGet) | Blazor | 0.0.0 | Placeholder — first components ship at first Blazor consumer demand |
| `@honeydrunk/web-ui-native` | React Native | 0.0.0 | Placeholder — first components ship at first mobile PDR |

## For downstream consumers — minimal wiring

```bash
pnpm add @honeydrunk/web-ui-tokens @honeydrunk/web-ui-css
```

```css
/* In your global CSS entrypoint */
@import "@honeydrunk/web-ui-tokens/css/variables.css";
@import "@honeydrunk/web-ui-css";
```

```ts
// In your JS/TS, if you need programmatic access to tokens
import { tokens } from "@honeydrunk/web-ui-tokens";

console.log(tokens.color.sector.core); // "#7B61FF"
```

For non-Node consumers (Blazor), import the CSS file directly from the published package or from a CDN unpkg URL.

## Phase-1 honest limitation

This is a Phase-1 release. The following are intentional gaps:

1. **No React, Blazor, or React Native components ship at v0.1.0.** The three component packages (`@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native`) ship as placeholders at version 0.0.0. Their READMEs name the phase at which the real implementation lands.
2. **No designer-tooling integration.** Figma / Penpot integration is deferred indefinitely (lands when designer joins the workflow).
3. **No icon library.** The Grid will commit to a single icon set in a future release; for now consumers choose their own icons.

## Per-PDR overrides

Per-PDR consumers can override any token via the standard CSS-variable cascade. Set the variable at your application root and every downstream component that reads from it sees the override:

```css
:root {
  --hd-color-accent-primary: #ff6600; /* warmer than the default — fine */
}
```

The override flows downstream only — the canonical token set is not bidirectionally absorbed.

## License

MIT.
```

### CHANGELOG (repo-level)

```markdown
# Changelog

All notable changes to HoneyDrunk.Web.UI are documented here.

## [0.1.0] - YYYY-MM-DD

### Added

- Initial release of HoneyDrunk.Web.UI — the Creator sector's anchor Node.
- `@honeydrunk/web-ui-tokens` 0.1.0 — design tokens (color, spacing, typography, radii, shadows, motion, breakpoints, z-index). Sector colors round-trip from constitution/sectors.md exactly.
- `@honeydrunk/web-ui-css` 0.1.0 — primitive CSS bundle (reset, base typography, utility classes with hd- prefix).
- `@honeydrunk/web-ui-react` 0.0.0 — placeholder package (Phase 2 implementation deferred to first non-Studios consumer demand).
- `HoneyDrunk.Web.UI.Blazor` 0.0.0 — placeholder package (Phase 3 implementation deferred to first Blazor consumer demand).
- `@honeydrunk/web-ui-native` 0.0.0 — placeholder package (Phase 4 implementation deferred to first mobile PDR).
- pnpm-workspace monorepo with TypeScript 5.6, Vitest 2.1.
- CI: pr-core, release (npm publish-on-tag for non-private packages), nightly-deps, nightly-security.
```

### CI workflows

#### `.github/workflows/pr-core.yml`

```yaml
name: PR Core
on:
  pull_request:
    branches: [main]

jobs:
  core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm run build
      - run: pnpm run test
      - run: pnpm run lint
```

#### `.github/workflows/release.yml`

```yaml
name: Release
on:
  push:
    tags:
      - "v*.*.*"

jobs:
  publish-npm:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
          registry-url: https://registry.npmjs.org
      - run: pnpm install --frozen-lockfile
      - run: pnpm run build
      # Publish only non-private packages. The placeholder packages
      # (@honeydrunk/web-ui-react, @honeydrunk/web-ui-native) have
      # "private": true and are skipped naturally by pnpm publish.
      - name: Publish @honeydrunk/web-ui-tokens
        working-directory: packages/tokens
        run: pnpm publish --access public --no-git-checks
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      - name: Publish @honeydrunk/web-ui-css
        working-directory: packages/css
        run: pnpm publish --access public --no-git-checks
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
  # NuGet publish job for HoneyDrunk.Web.UI.Blazor is intentionally
  # absent at v0.1.0 — the .csproj has IsPackable=false. The first
  # feature packet that implements Blazor components adds the NuGet
  # publish job with OIDC federated credential authentication.
```

#### `.github/workflows/nightly-deps.yml`

Standard grouped-deps PR per ADR-0009 — copies the pattern from `HoneyDrunk.Files` or `HoneyDrunk.Audit` but adapts the package manager from NuGet to pnpm. The agent scaffolds this as a minimal pnpm-aware variant; full ADR-0009 alignment is a follow-up if drift is observed.

#### `.github/workflows/nightly-security.yml`

Standard npm audit + dependency-review per memory `feedback_manual_close_security_issues` (workflow creates/comments on issues; human closes them).

## Affected Files
Entire repo is created from this packet. Notable new files:

- `package.json`, `pnpm-workspace.yaml`, `pnpm-lock.yaml`, `tsconfig.base.json`, `.npmrc`, `.editorconfig`, `README.md`, `CHANGELOG.md`
- `packages/tokens/` — `package.json`, `tsconfig.json`, `src/{index.ts, tokens.ts, types.ts, build-css.ts}`, `scripts/emit-json-and-css.mjs`, `test/tokens.test.ts`, `README.md`, `CHANGELOG.md`
- `packages/css/` — `package.json`, `tsconfig.json`, `src/{reset.css, typography.css, utilities.css, index.css}`, `scripts/copy-css.mjs`, `test/css-bundle.test.ts`, `README.md`, `CHANGELOG.md`
- `packages/react/` — `package.json`, `tsconfig.json`, `src/index.ts` (placeholder), `README.md`, `CHANGELOG.md`
- `packages/blazor/` — `HoneyDrunk.Web.UI.Blazor.csproj` (IsPackable=false), `Placeholder.cs`, `README.md`, `CHANGELOG.md`
- `packages/native/` — `package.json`, `tsconfig.json`, `src/index.ts` (placeholder), `README.md`, `CHANGELOG.md`
- `.github/workflows/` — `pr-core.yml`, `release.yml`, `nightly-deps.yml`, `nightly-security.yml`

## NuGet Dependencies

The Blazor placeholder (`packages/blazor/HoneyDrunk.Web.UI.Blazor.csproj`) does **NOT** carry a `HoneyDrunk.Standards` PackageReference at v0.0.0 — there is no implementation source to lint, and adding the reference would force the .NET nightly-deps machinery onto a placeholder with no real .NET deps to maintain. The first feature packet that implements Blazor components adds `HoneyDrunk.Standards` (with `PrivateAssets="all"`) and `Microsoft.AspNetCore.Components.Web` as needed.

Per invariant 26, packets for .NET code work include `## NuGet Dependencies`. The Blazor placeholder's deferred-status is documented here as the rationale for the empty section.

| Package | Notes |
|---|---|
| (none — placeholder ships with zero NuGet deps at v0.0.0) | First feature packet adds `HoneyDrunk.Standards` (`PrivateAssets="all"`) and `Microsoft.AspNetCore.Components.Web` per actual component needs |

## Boundary Check

- [x] All work inside `HoneyDrunk.Web.UI`. No other Grid repos edited.
- [x] **Zero `HoneyDrunk.*` dependencies in any Web.UI package** per ADR-0071 D9 / constitutional invariant `{N3}`. No `@honeydrunk/kernel-abstractions` (does not exist; even if a future JS Kernel binding ships, Web.UI does not consume it). No `HoneyDrunk.Kernel`, no `HoneyDrunk.Standards` in the Blazor placeholder (deferred to first feature packet), no anything-Grid-Node-runtime in any package.
- [x] `tokens` and `css` packages publish to npm under `@honeydrunk` scope. `react`, `native` placeholders carry `"private": true` and do not publish. `HoneyDrunk.Web.UI.Blazor` carries `IsPackable=false` and does not publish to NuGet.
- [x] Scaffold does NOT include: real React components (Phase 2), real Blazor components (Phase 3), real React Native components (Phase 4), designer tooling (Phase 5), icon library (deferred indefinitely).
- [x] The three placeholder packages are **honestly named** in their READMEs and CHANGELOGs — no claim of any component shipped at v0.0.0, no language describing them as "production-ready" or "implemented."
- [x] tsconfig pinned per refine-pass: `target: ES2022`, `module: "ESNext"`, `moduleResolution: "Bundler"`, `resolveJsonModule: true`, `engines.node: ">=22"`.
- [x] Build scripts use `fileURLToPath()` for cross-platform path handling (not `outPath.pathname.replace(/^\//, '')` which is broken on Windows).
- [x] `tokens.test.ts` uses structural assertion (iterates sector keys list) — does NOT hex-couple values, so a future palette rebrand does not break the test.
- [x] Records / interfaces — n/a (TypeScript). The Grid naming convention "records drop I, interfaces keep it" is .NET-specific.

## Acceptance Criteria

- [ ] `pnpm install --frozen-lockfile && pnpm run build && pnpm run test` succeeds from a fresh clone with no errors.
- [ ] `packages/tokens/package.json` declares `version: "0.1.0"`, name `@honeydrunk/web-ui-tokens`, exports `.`, `./json`, `./css/variables.css`, includes `dist/` in `files`, has `publishConfig.access: "public"`.
- [ ] `packages/tokens/dist/tokens.json` exists after build and contains the 9 sector colors from `constitution/sectors.md` (`#7B61FF`, `#FF8C00`, `#FFFF00`, `#00FF41`, `#14B8A6`, `#F5B700`, `#FF2A6D`, `#00D1FF`, `#D946EF`) under `color.sector.{core, ops, meta, honeynet, creator, market, honeyplay, cyberware, ai}`.
- [ ] `packages/tokens/dist/css/variables.css` exists after build and contains `--hd-color-sector-core: #7B61FF;` and the other 8 sector CSS variables under `:root`.
- [ ] `packages/tokens/test/tokens.test.ts` uses **structural assertion** — iterates a sector-key list and asserts each key exists and the value is a hex string. **Does NOT assert specific hex values** beyond the regex check. A future palette rebrand in `sectors.md` does not break this test.
- [ ] `packages/tokens/scripts/emit-json-and-css.mjs` uses `fileURLToPath()` for path handling — **not** `import.meta.url`'s `.pathname` (which is broken on Windows). Build runs cleanly on Windows + Linux.
- [ ] `tsconfig.base.json` declares `target: "ES2022"`, `module: "ESNext"`, `moduleResolution: "Bundler"`, `resolveJsonModule: true`, `strict: true`.
- [ ] Root `package.json` declares `engines.node: ">=22"` and `packageManager: "pnpm@9.0.0"` (or current pnpm 9.x).
- [ ] `packages/css/package.json` declares `version: "0.1.0"`, name `@honeydrunk/web-ui-css`, peerDependency on `@honeydrunk/web-ui-tokens`, exports `.` + `./reset.css` + `./typography.css` + `./utilities.css`.
- [ ] `packages/css/src/utilities.css` uses **`hd-` prefix on every class selector**. `packages/css/test/css-bundle.test.ts` asserts this with a regex over the file content and passes.
- [ ] `packages/css/src/reset.css` sets `box-sizing: border-box` on the universal selector. Test asserts.
- [ ] `packages/css/src/index.css` imports reset + typography + utilities. Test asserts.
- [ ] `packages/react/package.json` declares `version: "0.0.0"`, `"private": true`, and has the placeholder `index.ts` with only the `PLACEHOLDER` constant and the comment block.
- [ ] `packages/native/package.json` declares `version: "0.0.0"`, `"private": true`, and has the placeholder `index.ts` with only the `PLACEHOLDER` constant and the comment block.
- [ ] `packages/blazor/HoneyDrunk.Web.UI.Blazor.csproj` declares `<Version>0.0.0</Version>`, `<IsPackable>false</IsPackable>`, no `HoneyDrunk.Standards` PackageReference, no `Microsoft.AspNetCore.Components.Web` PackageReference (both deferred). `Placeholder.cs` contains only the placeholder comment block.
- [ ] All three placeholder packages' READMEs explicitly state placeholder status and name the Phase at which the real implementation lands. **No claim of "production-ready", "implemented", "component pack", or any language suggesting the placeholder is functional.**
- [ ] `release.yml` publishes `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` to npm on tag `v*.*.*` push, using `NPM_TOKEN` from secrets. Skips placeholder packages via their `"private": true` flag.
- [ ] `release.yml` does **not** include a NuGet publish step at v0.1.0 (the Blazor placeholder has `IsPackable=false`). A NuGet publish step is added by the first feature packet that implements Blazor components.
- [ ] `pr-core.yml` runs `pnpm install --frozen-lockfile`, `pnpm run build`, `pnpm run test`, `pnpm run lint` on every PR to `main`.
- [ ] Repo-level `CHANGELOG.md` has a `## [0.1.0] - YYYY-MM-DD` entry covering the scaffold (per memory `feedback_no_unreleased_commits` — no `## Unreleased` block at commit time).
- [ ] Per-package `CHANGELOG.md` files each have their own version entry naming what shipped: `tokens` + `css` at `## [0.1.0]`; `react`, `blazor`, `native` at `## [0.0.0]` with explicit "Placeholder package created. No implementation." text.
- [ ] Repo-level `README.md` and per-package `README.md` files all present.
- [ ] Repo `README.md` includes a `## For downstream consumers — minimal wiring` section showing copy-pasteable `pnpm add @honeydrunk/web-ui-tokens @honeydrunk/web-ui-css` + the CSS import lines + the JS programmatic-access snippet.
- [ ] Repo `README.md` includes a `## Phase-1 honest limitation` section that explicitly names: (a) the three placeholder packages and their Phase 2/3/4 deferral; (b) no designer-tooling integration; (c) no icon library.
- [ ] **The README does NOT cite "ADR-0071" by number in narrative paragraphs.** Per memory `feedback_no_adr_in_docs`. (Runtime metadata references — CHANGELOG, catalog entries elsewhere — are fine; the README is user-facing narrative.)
- [ ] Test suite runs and passes — minimum coverage: `tokens.test.ts` (sector key structural assertion + canonical category presence + space-scale shape + typography shape + breakpoint shape), `css-bundle.test.ts` (index.css imports, hd- prefix on utilities, reset uses border-box).
- [ ] Manual confirmation that pushing tag `v0.1.0` triggers `release.yml` and publishes `@honeydrunk/web-ui-tokens@0.1.0` + `@honeydrunk/web-ui-css@0.1.0` to npmjs.com under the `@honeydrunk` scope (do not actually push the tag in this PR — verify the workflow exists and a tag-push trigger is configured).
- [ ] **No `.github/dependabot.yml` file exists.** Per ADR-0009, dependency-scanning lives in the nightly workflows; no Dependabot config file is committed.
- [ ] `pnpm-lock.yaml` is committed.

## Human Prerequisites

- [ ] Packet 03 of this initiative complete — `HoneyDrunkStudios/HoneyDrunk.Web.UI` repo exists on GitHub with org-default branch protection, labels seeded, OIDC federated credential wired, `@honeydrunk` npm scope verified, `NPM_TOKEN` seeded, and the local working tree cloned at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Web.UI/`.
- [ ] Packet 02 of this initiative merged — the three new Web.UI invariants exist in `constitution/invariants.md` so this packet's acceptance criteria reference them by number. **This packet's source file uses `{N1}` / `{N2}` / `{N3}` placeholders** for the three Web.UI-related invariant numbers; substitute the real numbers in place pre-push under invariant 24's pre-filing carve-out, **after** packet 02 merges and the assigned numbers are known. At scoping time (2026-05-25) the expected assignments are 87 / 88 / 89, but the collision-check protocol at packet 02's edit time is authoritative.
- [ ] After this packet's PR merges, push tag `v0.1.0` from `main` to trigger the first npm publish. Tags are human-pushed.
- [ ] **`NPM_TOKEN` repository (or org-level) secret is available to the `HoneyDrunk.Web.UI` repo before `v0.1.0` is tagged.** Packet 03 seeds this; verify it's bound to the repo before tagging.
- [ ] **No Azure resource provisioning required for this packet.** HoneyDrunk.Web.UI is a published-package library Node; no runtime host, no Container App, no Function App, no Storage Account, no CDN, no Key Vault. Ever. The repo is npm/NuGet-only — published packages, not services.
- [ ] **After this packet's PR merges and `v0.1.0` ships,** file the Studios-side migration packet to add `@honeydrunk/web-ui-tokens` as a Studios dependency and replace Studios' informal CSS-variable declarations with the import. That packet is out of scope here — it lives against the `HoneyDrunk.Studios` repo and references `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` as the migration source.
- [ ] After this packet's PR merges and `v0.1.0` ships, file a small follow-up Architecture packet to bump the two shipped `modules.json` entries (`web-ui-tokens`, `web-ui-css`) from `0.0.0` to `0.1.0` and to flip the `grid-health.json` Web.UI row's `version` from `0.0.0` to `0.1.0`, `signal` from `Seed` to `Live` (if appropriate), and clear the `active_blockers` array. The three placeholder entries (`web-ui-react`, `web-ui-blazor`, `web-ui-native`) stay at `0.0.0`. That follow-up is not in this packet's scope.
- [ ] After this packet's PR merges, file a SonarCloud onboarding follow-up packet for `HoneyDrunk.Web.UI` modeled on the corresponding ADR-0011 onboarding packet (if SonarCloud is being applied to JS/TS Nodes — verify the current Grid pattern at the time).
- [ ] After this packet's PR merges, if any future Web.UI consumer (Studios, Notify Cloud admin, or any PDR-driven app) chooses an alternative scope name because the `@honeydrunk` scope has been renamed for any reason, file an amendment packet to ADR-0071 D6 to update the scope name in lockstep across the ADR + catalog + tokens-inventory + this scaffold's package.json files.

## Referenced Invariants

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet establishes Web.UI's monorepo + CI.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — All five packages ship README + CHANGELOG; repo-level files also.

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This packet's `{N1}` / `{N2}` / `{N3}` placeholders are substituted in place pre-push after packet 02 merges and assigns the actual numbers.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. — Section is present above with the deferred-status rationale for the Blazor placeholder.

> **Invariant 27:** All projects in a solution share one version and move together. — **Explicit departure for this packet.** Invariant 27 is .NET-centric and references csproj `<Version>`. The JS monorepo posture is per-package versioning. The two shipped packages (`tokens`, `css`) move together at 0.1.0; the three placeholders stay at 0.0.0 until their respective Phases ship. This departure is documented in the PR body and is consistent with the per-package npm publishing pattern. Future Web.UI version bumps will explicitly call out which packages move and which stay.

> **Invariant `{N1}` (this initiative, packet 02):** Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`. Per-PDR re-derivation of tokens or primitive CSS is a boundary violation. Per-PDR overrides via standard CSS-variable cascade are permitted. — This packet ships the consumable substrate that enforces this invariant cross-PDR. Studios' migration packet (out of scope) and every consumer's first-scaffolding packet honor this invariant by consuming the published packages.

> **Invariant `{N2}` (this initiative, packet 02):** `HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios. The Studios website is a product Node, not the design-system host. — Web.UI is published as standalone npm packages that Studios will consume. No Studios sources live in Web.UI; no Web.UI sources live in Studios.

> **Invariant `{N3}` (this initiative, packet 02):** `HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts. Web.UI is purely client-side substrate; the dependency direction is consumer→Web.UI, never the inverse. — Verified by every package's `package.json` (no `HoneyDrunk.*` or `@honeydrunk/kernel-*` dependencies; only third-party libraries and other workspace packages) and by the Blazor placeholder's `HoneyDrunk.Web.UI.Blazor.csproj` (no `HoneyDrunk.*` PackageReferences).

## Referenced ADR Decisions

- **ADR-0071 D1** — Web.UI is the Creator sector's owner of design tokens, primitive CSS, and component contracts. This packet ships the substrate.
- **ADR-0071 D3** — Web.UI is consumed by Studios — not folded into Studios. The packages are published standalone; Studios consumes them via a follow-up migration packet.
- **ADR-0071 D4** — Per-stack component strategy: tokens cross-stack, components per-stack. Tokens + CSS ship at standup; component packages are placeholders for Phase 2/3/4.
- **ADR-0071 D5** — Phased shipping. Phase 1 (this packet): tokens + primitive CSS shipped as `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css`. No components yet.
- **ADR-0071 D6** — Package layout. Five packages: tokens (stack-agnostic JSON+CSS), css (web shared), react (per-stack), blazor (per-stack), native (per-stack). npm scope `@honeydrunk`; NuGet `HoneyDrunk.*`.
- **ADR-0071 D7** — Semantic versioning per ADR-0035 discipline applied to JS/CSS packages. Tokens + CSS start at 0.1.0; placeholders at 0.0.0; pre-1.0 packages do not carry the same compatibility promise.
- **ADR-0071 D9** — Web.UI has zero runtime dependency on any Grid Node. Verified in every package.
- **ADR-0070 D1** — React is the default for consumer-facing web. The future `@honeydrunk/web-ui-react` package implements components in React.
- **ADR-0035** — Semantic versioning discipline. Pre-1.0 packages do not carry the same compatibility promise. Web.UI starts at 0.x and stays there until the cross-PDR consumer base stabilizes.
- **ADR-0039** — Web.UI is public per the Grid default; license is MIT.
- **ADR-0009** — No `.github/dependabot.yml`; nightly workflows handle deps.

## Dependencies

- `packet:01` — Architecture catalog registration must be merged so `repos/HoneyDrunk.Web.UI/` context folder, `honeydrunk-web-ui` catalog entries, and `studios-tokens-inventory.md` exist (the scaffolding agent reads the inventory to seed the sector-color block in `tokens.ts`).
- `packet:02` — the three new Web.UI invariants must exist in `constitution/invariants.md` before this packet's acceptance criteria reference them by number. Substitute the assigned `{N1}` / `{N2}` / `{N3}` numbers in this packet's source file in place pre-push under invariant 24's pre-filing carve-out, **after** packet 02 merges.
- `packet:03` — the `HoneyDrunk.Web.UI` GitHub repo must exist with branch protection, labels, OIDC, the `@honeydrunk` npm scope verified, `NPM_TOKEN` seeded, and the local working tree cloned. The scaffolding agent has nowhere to author into without packet 03 done.

## Labels

`feature`, `tier-2`, `web-ui`, `scaffold`, `adr-0071`

## Agent Handoff

**Objective:** Take the empty `HoneyDrunk.Web.UI` repo and ship version 0.1.0 with the pnpm-workspace monorepo, the two shipped packages (`@honeydrunk/web-ui-tokens` with tokens JSON + CSS variables; `@honeydrunk/web-ui-css` with reset + typography + utilities), the three honest 0.0.0 placeholder packages (`@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native`), the Vitest test suite (structural-assertion-only — no hex coupling), and the full CI pipeline (PR core + release with npm publish-on-tag + nightly deps + nightly security). Sector colors round-trip from `constitution/sectors.md` exactly via the `studios-tokens-inventory.md` reference. The placeholder packages are honestly named — no claim of "production-ready" or "implemented" anywhere in the repo.

**Target:** HoneyDrunk.Web.UI, branch from `main`. (Packet 03 ensures `main` exists with `.gitignore`/`LICENSE` already in place, the `@honeydrunk` npm scope is verified, and `NPM_TOKEN` is seeded.)

**Context:**
- Goal: Unblock Studios' tokens-migration follow-up packet, Notify Cloud admin's tokens + CSS consumption, every PDR-driven consumer app's first scaffolding packet (Hearth/Lately/Currents/Curiosities). Anchor the Creator sector by shipping its first published artifact.
- Feature: ADR-0071 standup initiative — this is the substrate scaffold, the fourth packet of the initiative (after Architecture catalog registration, the three new Web.UI invariants `{N1}` / `{N2}` / `{N3}`, and the human-only repo creation + npm scope verification + NPM_TOKEN seeding).
- ADRs: ADR-0071 (sole governing standup ADR); ADR-0070 (frontend stack — React the default for consumer web); ADR-0035 (semver discipline applied to JS/CSS packages); ADR-0039 (public per Grid default; MIT license); ADR-0009 (no Dependabot config file).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01, 02, and 03 of this initiative must merge / be Done first.

**Constraints:**

- **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet establishes Web.UI's monorepo + CI.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — All five packages ship README + CHANGELOG; repo-level files also.
- **Invariant 27 departure:** Invariant 27 ("all projects in a solution share one version") is .NET-centric. The JS monorepo posture is per-package versioning. Shipped (`tokens`, `css`) move together at 0.1.0; placeholders (`react`, `blazor`, `native`) stay at 0.0.0. Document the departure in the PR body.
- **Invariant `{N1}` (Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`):** This packet ships the consumable substrate. Per-PDR re-derivation is a boundary violation; per-PDR CSS-variable overrides are permitted. The published packages are the single source of truth that every consumer will reference.
- **Invariant `{N2}` (Web.UI does not host Studios; Web.UI is consumed by Studios):** No Studios sources live in this repo. The repo is standalone; Studios will migrate to consume it via a follow-up packet.
- **Invariant `{N3}` (Web.UI does not depend on any Grid Node's runtime contracts):** Zero `HoneyDrunk.*` PackageReferences in any package. No `@honeydrunk/kernel-abstractions` (would not exist anyway). Verified by every package.json and the Blazor .csproj.
- **`cluster: "visualization"`** matches the Studios precedent (packet 01 landed this). Do not invent `frontend` as a cluster value.
- **`tsconfig.base.json` is pinned:** `target: ES2022`, `module: "ESNext"`, `moduleResolution: "Bundler"`, `resolveJsonModule: true`, `strict: true`. Per-package tsconfig extends and overrides only the project-specific bits.
- **Root `package.json` declares `engines.node: ">=22"` and `packageManager: "pnpm@9.0.0"`** — Node 22 LTS minimum; pnpm 9.x.
- **Build scripts use `fileURLToPath()` for cross-platform path handling.** Do not use `import.meta.url`'s `.pathname` directly (broken on Windows due to the leading-slash artifact). This applies to `packages/tokens/scripts/emit-json-and-css.mjs` and `packages/css/scripts/copy-css.mjs`.
- **`tokens.test.ts` uses structural assertion only.** Iterates a sector-key list and asserts each key exists + the value matches a hex regex. **Does NOT assert specific hex values.** A future palette rebrand in `constitution/sectors.md` does not break this test.
- **Sector colors round-trip exactly.** The 9 sector colors in `packages/tokens/src/tokens.ts` are the values from `constitution/sectors.md` (cross-referenced in `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` from packet 01). Studios' migration depends on these round-tripping. If any sector color in `sectors.md` differs from the values in this scaffold, fix the scaffold to match `sectors.md`.
- **Placeholder discipline.** `react`, `blazor`, `native` packages ship at version 0.0.0 with `"private": true` (npm) / `<IsPackable>false</IsPackable>` (NuGet). Their `index.ts` / `Placeholder.cs` contains only the placeholder comment + a sentinel constant. **Do not stub out class shapes, prop shapes, or component shells.** Adding stubs would lie about the package's status and force a churn-PR when the real implementation lands. The empty placeholder + explicit README notice is the honest shape.
- **`HoneyDrunk.Web.UI.Blazor.csproj` does NOT reference `HoneyDrunk.Standards` at v0.0.0.** The placeholder has no implementation to analyze; adding the reference would force the .NET nightly-deps machinery on a placeholder. The first feature packet that implements Blazor components adds `HoneyDrunk.Standards` (with `PrivateAssets="all"`).
- **`release.yml` publishes only non-private packages.** `tokens` and `css` publish to npm under `@honeydrunk` scope using `NPM_TOKEN`. The three placeholders are skipped automatically (their `"private": true` flag tells pnpm publish to skip them). **No NuGet publish step at v0.1.0** — the Blazor placeholder has `IsPackable=false`.
- **No `.github/dependabot.yml`** (ADR-0009). Org-default Dependabot security alerts stay enabled.
- **README does not cite "ADR-0071" by number in narrative paragraphs.** Per memory `feedback_no_adr_in_docs`.
- **CHANGELOG entries land under dated SemVer-bumped sections, not under `## Unreleased`.** Per memory `feedback_no_unreleased_commits`.

**Key Files:**
- `package.json` (workspace root), `pnpm-workspace.yaml`, `pnpm-lock.yaml`, `tsconfig.base.json`, `.npmrc`, `.editorconfig`
- `packages/tokens/` — `package.json`, `src/{index.ts, tokens.ts, types.ts}`, `scripts/emit-json-and-css.mjs`, `test/tokens.test.ts`
- `packages/css/` — `package.json`, `src/{reset.css, typography.css, utilities.css, index.css}`, `scripts/copy-css.mjs`, `test/css-bundle.test.ts`
- `packages/react/` — `package.json` (private + 0.0.0), `src/index.ts` (placeholder)
- `packages/blazor/` — `HoneyDrunk.Web.UI.Blazor.csproj` (IsPackable=false + 0.0.0), `Placeholder.cs`
- `packages/native/` — `package.json` (private + 0.0.0), `src/index.ts` (placeholder)
- `.github/workflows/{pr-core, release, nightly-deps, nightly-security}.yml`
- `README.md`, `CHANGELOG.md` (repo-level), per-package `README.md` and `CHANGELOG.md`

**Contracts:**
- D6 public surface (`DesignTokens` JSON schema + TS types in `@honeydrunk/web-ui-tokens`; `TokensCssVariables` emitted as `dist/css/variables.css`; `PrimitiveCss` bundle in `@honeydrunk/web-ui-css`) authored fresh in this packet.
- The shipped tokens/css packages establish the cross-PDR consumable substrate that every future consumer references.
