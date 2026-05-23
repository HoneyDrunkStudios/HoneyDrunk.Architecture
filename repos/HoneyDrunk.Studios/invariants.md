# HoneyDrunk.Studios — Invariants

Studios-specific invariants (supplements `constitution/invariants.md`).

1. **Studios is a consumer of `HoneyDrunk.Web.UI`, never its host.**
   Per [ADR-0071](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md) D3, the shared design substrate lives in Web.UI. Studios consumes tokens, primitive CSS, and React components from Web.UI. New design primitives are not authored in Studios for cross-Node reuse — they go to Web.UI first and Studios consumes them.

2. **Studios is build-time read-only over the Architecture catalogs.**
   Catalog data (`catalogs/*.json`, `adrs/`, `pdrs/`, `business/decisions/`, `initiatives/*.md`) is consumed at build time from the published Architecture repo. Studios does not write back, does not call mutating APIs, and does not require runtime read access to the Architecture repo.

3. **Studios runs no agents.**
   Studios is a static-first Next.js surface. AI use happens upstream in editorial workflow, not in the running Studios app.

4. **Studios is the build-in-public surface, not the build-in-public mechanism.**
   The charter's build-in-public stance ([`constitution/charter.md`](../../constitution/charter.md) §"Build-in-public, honestly") is honored by what Studios surfaces (ADRs, PDRs, drift reports, post-mortems, the visualizer). The discipline that produces those artifacts lives elsewhere — Studios renders them.

5. **Three.js / WebGL is a Studios-specific concern.**
   Other Grid frontends do not inherit a 3D dependency. `HoneyDrunk.Web.UI` does not opinionate on canvas or 3D runtimes. If another consumer surface ever needs WebGL, it picks its own runtime — Studios' choice is not a Grid default.
