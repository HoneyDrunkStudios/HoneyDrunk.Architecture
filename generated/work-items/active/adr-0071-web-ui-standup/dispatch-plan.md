# Dispatch Plan — ADR-0071 HoneyDrunk.Web.UI Standup

**Initiative:** `adr-0071-web-ui-standup`
**Sector:** Creator (anchor)
**Governing ADR:** [ADR-0071 — Stand Up the HoneyDrunk.Web.UI Node](../../../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md) (Proposed 2026-05-23; stays Proposed across all four packet PRs. Flips to Accepted only after every packet in this initiative is closed, as a separate post-merge housekeeping step the scope agent runs — see "Status-flip handling" below.)
**Paired ADR:** [ADR-0070 — Frontend Platform Stack](../../../../adrs/ADR-0070-frontend-platform-stack.md) (merged in PR #288; commits React for consumer web, Blazor for simple admin, React Native + Expo for mobile). Web.UI is the cross-stack reconciliation point ADR-0070's three-stack split requires.
**Trigger:** ADR-0071 in the Proposed queue. Studios needs formal tokens (its existing tokens are informal); Notify Cloud admin needs visual identity from day one; every queued consumer-app PDR (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0008 Curiosities) is blocked on `@honeydrunk/web-ui-tokens` + `@honeydrunk/web-ui-css` existing. This initiative anchors the Creator sector and ships the cross-PDR design substrate.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Web.UI` (new))
**Site sync required:** No (scaffold-only; no public-API surface change needs site update yet — when `@honeydrunk/web-ui-tokens 0.1.0` and `@honeydrunk/web-ui-css 0.1.0` publish and Studios migrates, a site-sync follow-up may be warranted to publicize the Creator sector going live)
**Rollback plan:**
- **Pre-tag rollback** (before `v0.1.0` is pushed in Web.UI): `git revert` of each PR. Packets 01/02/03 are independent reverts (Architecture-side); packet 04 reverts the entire scaffold as a single PR.
- **Post-tag rollback** (after `v0.1.0` is pushed but before any consumer references the published packages): npm packages are immutable. Either `npm unpublish` within the 72-hour window (npm allows unpublish only for new package versions and only briefly), or fix-forward as `0.1.1`. Practical hard rollback after a tag is messy — prefer fix-forward.
- **After first consumer (e.g., Studios' migration packet) lands:** rollback of Web.UI tokens is no longer a clean option — Studios has a published-version reference. Treat any defect as forward-only.
- **`file-work-items.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Summary

ADR-0071 is the stand-up ADR for `HoneyDrunk.Web.UI`. It decides what the Node owns (D1, D2: the Creator sector's anchor for design substrate — tokens, primitive CSS, component contracts), the per-stack split (D4: tokens cross-stack, components per-stack), the Studios-consumes-Web.UI inversion (D3), the phased shipping plan (D5: tokens + CSS at Phase 1; React/Blazor/RN components per-consumer-demand at Phase 2/3/4), the package layout (D6: five packages — `@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native`), the semver discipline (D7), the explicit boundaries (D8), the zero-Grid-Node-runtime-dependency posture (D9), and the charter sanity check (D10). None of that has been built — the `HoneyDrunkStudios/HoneyDrunk.Web.UI` repo does not exist yet.

Four packets land the work:

1. **Architecture catalog registration + context folder + Studios tokens inventory** — register `honeydrunk-web-ui` in every catalog file (`nodes.json`, `relationships.json`, `grid-health.json`, `modules.json`, `contracts.json`), anchor the Creator-sector row in `sectors.md` (replaces the "No real Nodes yet" placeholder), add Frontend section + Planned Nodes row to `tech-stack.md`, add Q2 2026 roadmap bullet, add active-initiatives entry, create `repos/HoneyDrunk.Web.UI/` context folder with `overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md` matching the Studios template, and create a fifth file `studios-tokens-inventory.md` capturing Studios' informal tokens (9 sector colors + recommended categories) as the source of truth for packet 04's first `@honeydrunk/web-ui-tokens` release. Does **not** flip ADR-0071's Status — that is a separate post-merge housekeeping step.
2. **Constitution invariants** — three new invariants from ADR-0071's §Invariants subsection added to `constitution/invariants.md` under a new `## Web.UI Invariants` section at block 87–89 (per the reservation registry; ADR-0071 already holds this block). `{N1}` = Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`. `{N2}` = `HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios. `{N3}` = `HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts. All three are definitive (none are conditional on first-feature-packet evidence). **No `(Proposed)` or `(takes effect when accepted)` qualifier** on the invariants — they land in final active form.
3. **Create the HoneyDrunk.Web.UI GitHub repo + verify `@honeydrunk` npm scope + seed `NPM_TOKEN` (human-only)** — create the public repo on `HoneyDrunkStudios`, apply branch protection, seed labels, verify or claim the `@honeydrunk` npm scope under the HoneyDrunk Studios npm organization, generate and seed an `NPM_TOKEN` Automation token (org-level or repo-level), configure OIDC federated credential for the future NuGet Blazor publish, clone locally. **The npm scope verification + NPM_TOKEN seeding moves to this human-only packet** (NOT the scaffold) so blockers are caught at Wave 2 instead of mid-scaffold.
4. **HoneyDrunk.Web.UI scaffold** — empty repo to first-shippable state. pnpm-workspace monorepo with `engines.node: ">=22"`, `tsconfig.base.json` pinned per refine-pass (`target: ES2022`, `module: "ESNext"`, `moduleResolution: "Bundler"`, `resolveJsonModule: true`), five packages (`tokens` + `css` shipped at v0.1.0 with real content; `react` + `blazor` + `native` as honest 0.0.0 placeholders mirroring the `HoneyDrunk.Files.AzureBlob` placeholder discipline), tokens JSON + CSS-variables emission via build script using `fileURLToPath()` (cross-platform), primitive CSS bundle with `hd-` prefix, Vitest tests using **structural assertion only** (iterates sector-key list, does NOT hex-couple — survives palette rebrands), full CI (PR core + release with npm publish-on-tag for non-private packages + nightly deps + nightly security), README with "For downstream consumers — minimal wiring" and "Phase-1 honest limitation" sections.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates
   ├─ Architecture: 01-architecture-web-ui-catalog-registration   (Agent)
   └─ Architecture: 02-architecture-web-ui-invariants             (Agent)
         Blocked by: packet 01 (so repos/HoneyDrunk.Web.UI/invariants.md
                                 exists for the trailing-paragraph edit)

Wave 2: GitHub repo creation + npm scope + NPM_TOKEN (human-only,
        sequenced after packet 01 so the catalogs already point at
        the eventual repo and the npm-scope text exists when packet 03
        executes)
   └─ Architecture: 03-architecture-create-web-ui-repo            (Human)
         Blocked by: packet 01

Wave 3: HoneyDrunk.Web.UI scaffold
   └─ HoneyDrunk.Web.UI: 04-web-ui-node-scaffold                  (Agent)
         Blocked by: packet 02 (invariant number placeholders {N1}, {N2},
                                 {N3} must be substituted pre-push with
                                 the assigned numbers)
                     packet 03 (the GitHub repo must exist, the @honeydrunk
                                 npm scope must be verified, NPM_TOKEN must
                                 be seeded, and the local working tree must
                                 be cloned before scaffolding can run)
```

In practice packets 01 and 02 can be filed in the same push — packet 02's `dependencies: ["work-item:01"]` wires the blocking edge automatically. Packet 03 can also travel in the same push (it depends only on packet 01). The strict ordering is just packet 04 — it must wait for packet 02's PR to merge so the invariant numbers actually land, and it must wait for packet 03 to be Done so the target repo exists and npm publishing is configured.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Register HoneyDrunk.Web.UI's standup decisions in Architecture catalogs](./01-architecture-web-ui-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add three new Web.UI invariants (token consumption + Studios-not-host + zero Grid-Node runtime dependency) to the constitution](./02-architecture-web-ui-invariants.md) | Architecture | 1 | Agent | work-item:01 |
| 03 | [Create `HoneyDrunkStudios/HoneyDrunk.Web.UI` public repo, verify @honeydrunk npm scope, seed NPM_TOKEN, branch protection, labels, OIDC, clone locally (human-only)](./03-architecture-create-web-ui-repo.md) | Architecture (tracking issue) | 2 | Human | work-item:01 |
| 04 | [Stand up `HoneyDrunk.Web.UI` — pnpm-workspace monorepo, five packages (tokens + CSS shipped at 0.1.0; React/Blazor/Native placeholders), CI with npm publish-on-tag](./04-web-ui-node-scaffold.md) | HoneyDrunk.Web.UI | 3 | Agent | work-item:01, work-item:02, work-item:03 |

## Phase Mapping (ADR-0071 "If Accepted" checklist → packets)

ADR-0071's "If Accepted — Required Follow-Up Work" checklist, mapped to packets:

| Checklist item | Packet |
|---|---|
| Create `HoneyDrunk.Web.UI` GitHub repo as public | packet 03 |
| Add `honeydrunk-web-ui` Node entry to `catalogs/nodes.json` with Creator sector | packet 01 (`cluster: "visualization"` — `frontend` is not in the existing taxonomy) |
| Add `honeydrunk-web-ui` entries to `catalogs/relationships.json` | packet 01 |
| Anchor the Creator sector in `constitution/sectors.md` | packet 01 |
| Add Web.UI to `catalogs/modules.json` with the per-stack package layout from D6 | packet 01 (5 entries at 0.0.0 pre-scaffold) |
| Add Web.UI to `catalogs/grid-health.json` reflecting the stood-up package surface | packet 01 (at 0.0.0; flips to 0.1.0 in post-release reconciliation) |
| Update `constitution/sectors.md` Creator-sector text — Web.UI is the anchor | packet 01 (replaces "No real Nodes yet" placeholder line) |
| Create `repos/HoneyDrunk.Web.UI/` context folder | packet 01 (5 files: overview, boundaries, invariants, integration-points, studios-tokens-inventory) |
| File the HoneyDrunk.Web.UI scaffold packet | packet 04 |
| Confirm the paired ADR-0070 is Accepted | ADR-0070 merged in PR #288 (paired ADR) — already done at scoping time |
| Scope agent flips Status → Accepted after the first packet declaring this ADR in `accepts:` merges and the tokens package publishes its 0.x release | Separate post-merge housekeeping step — see "Status-flip handling" below |

## What This Initiative Does NOT Deliver

The following are explicitly out of scope for this initiative. Each becomes a separate packet at the appropriate time:

- **The real `@honeydrunk/web-ui-react` component pack.** Per ADR-0071 D5 Phase 2, the React component pack (Button, Input, Label, Card, Modal, Toast, Alert, Spinner, Skeleton) ships at first non-Studios consumer demand. The placeholder package at v0.0.0 is the honest standup state.

- **The real `HoneyDrunk.Web.UI.Blazor` component pack.** Per ADR-0071 D5 Phase 3, Blazor components ship at first Blazor consumer demand (likely Notify Cloud admin if/when its admin surface grows beyond what tokens + CSS alone provide).

- **The real `@honeydrunk/web-ui-native` component pack.** Per ADR-0071 D5 Phase 4, React Native components ship at first mobile PDR.

- **Designer-tooling integration.** Per ADR-0071 D5 Phase 5, Figma / Penpot integration is deferred indefinitely (lands when designer joins the workflow).

- **Icon library / re-export.** Per ADR-0071's What-it-doesn't-own — Web.UI may opinionate on which icon set the Grid uses but does not author icons. The opinion + re-export package (`@honeydrunk/web-ui-icons`) lands later if the Grid commits to a single icon set.

- **Studios' migration packet.** Per ADR-0071 D3 and `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` (created by packet 01), Studios consumes Web.UI tokens from the first 0.1.0 release. The migration is a Studios-side follow-up packet (add the `@honeydrunk/web-ui-tokens` dependency, replace Studios' informal CSS-variable declarations with the import, replace Tailwind config color block with the tokens import, verify `/grid` WebGL renders identically, ship). That packet is filed against the `HoneyDrunk.Studios` repo after v0.1.0 publishes — not in this initiative.

- **Notify Cloud admin's tokens + CSS consumption.** Per ADR-0071 D5 Phase 2, Notify Cloud admin consumes tokens + CSS at Phase 2. That wiring lives in the Notify Cloud standup ADR's own initiative (ADR-0027) — Notify Cloud is not yet stood up, so its Web.UI consumption is part of its eventual scaffolding packet.

- **PDR-driven app Node consumption.** Each of the four queued consumer-app PDRs (Hearth, Lately, Currents, Curiosities) consumes Web.UI from its first scaffolding packet. None of those Nodes have a stand-up ADR yet, so their Web.UI consumption is part of each PDR's eventual standup initiative.

- **No Azure resource provisioning.** HoneyDrunk.Web.UI is a published-package library Node — npm + NuGet only. Ever. No runtime host, no Container App, no Function App, no Storage Account, no CDN, no App Configuration, no Key Vault. No Azure walkthrough applies.

- **SonarCloud onboarding for HoneyDrunk.Web.UI.** Follows the pattern from the ADR-0011 code-review-pipeline initiative's per-repo onboarding packets, if SonarCloud is being applied to JS/TS Nodes (verify current Grid pattern at the time). Separate follow-up packet, post-`v0.1.0`. Flagged in packet 04's Human Prerequisites.

- **Grid-health aggregator wiring** for the new repo: if `HoneyDrunk.Actions/.github/workflows/grid-health-aggregator.yml` auto-discovers from `catalogs/nodes.json`, packet 01's edit is sufficient. If not, packet 04's Human Prerequisites flag a small follow-up to add `HoneyDrunk.Web.UI` to the watched-repos list. Confirm which behavior is in place at execution time.

- **Post-v0.1.0 catalog version-bumps.** After packet 04 lands `v0.1.0`, the two shipped `modules.json` entries for Web.UI (`web-ui-tokens`, `web-ui-css`) need to bump to v0.1.0, and the `catalogs/grid-health.json` Web.UI row needs to flip its `version` from `0.0.0` to `0.1.0` and update its `active_blockers` array. The three placeholder entries (`web-ui-react`, `web-ui-blazor`, `web-ui-native`) stay at `0.0.0`. That follow-up is one small Architecture chore packet filed after v0.1.0 ships — not in this initiative.

- **The `@honeydrunk` scope alternative-name pivot.** If packet 03's npm scope verification reveals that `@honeydrunk` is taken by an unrelated user/org and cannot be reclaimed, an ADR-0071 D6 amendment packet is needed to rename the scope across the ADR + packet 01's catalog entries + packet 04's package.json files + the context-folder docs. That pivot is **flagged in packet 03 as a hard-stop** but is not pre-emptively scoped here.

## Cross-ADR Invariant Numbering — Coordination Honored

At scoping time (2026-05-25), the `constitution/invariant-reservations.md` Active Reservations table records ADR-0071 holding block **87–89** for these three invariants. The expected assignments for this initiative's packet 02 are:

- **`{N1}` = 87** — Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`.
- **`{N2}` = 88** — `HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios.
- **`{N3}` = 89** — `HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts.

The expected numbers will hold unless another in-flight Proposed ADR's packet 00 lands and shifts the block at the reservation-collision rule. Packet 02's reservation-claim protocol is authoritative — the agent re-reads `constitution/invariant-reservations.md` at edit time and uses whatever the actual block ends up being.

**Filing-order rule (hard, enforced by `dependencies:` frontmatter):**

1. Push packets 01 and 02 in the same push (they may travel together — packet 02's `dependencies: ["work-item:01"]` wires the blocking edge automatically).
2. Push packet 03 in the same wave or shortly after (it depends only on packet 01).
3. Wait for packet 02's PR to merge so the assigned invariant numbers actually land in `constitution/invariants.md` and the reservation row moves to the History table.
4. Wait for packet 03 to close (the Web.UI repo must exist, the `@honeydrunk` scope must be verified, and NPM_TOKEN must be seeded before packet 04 can be filed against the repo and scaffold can authenticate to npm).
5. **Substitute the actual assigned numbers** for `{N1}`, `{N2}`, `{N3}` in `04-web-ui-node-scaffold.md` source file in place pre-push (invariant 24's pre-filing carve-out applies; packet 04 has not been filed yet at that point).
6. Push packet 04.

**Packets 02 and 04 cannot be filed in the same push** because packet 04's placeholders depend on packet 02's actual assignment.

## Asymmetry vs ADR-0061 Files standup (the closest substrate analog)

Five deliberate asymmetries vs Files (which is the most-recent substrate Node standup) are worth recording:

1. **JS/TS monorepo, not .NET solution.** Files is .NET-only — solution file (`.slnx`), MSBuild projects, NuGet packages. Web.UI is the first JS/TS-shaped Node standup the Grid has done — pnpm workspace, `package.json` per package, npm publish via `release.yml`. The five packages do not share a single `.csproj`-style version (per-package versioning is the standard npm-workspace pattern); the .NET-centric invariant 27 ("all projects in a solution share one version") is documented as an explicit departure in packet 04 and the PR body.

2. **Two shipped packages + three placeholders, not one or four shipped.** Files ships Abstractions + runtime + InMemory + AzureBlob (placeholder) at v0.1.0 — four .NET packages at the same version, one of them a placeholder. Web.UI ships tokens + CSS at v0.1.0 (real content) and three placeholders at v0.0.0 (react, blazor, native). The placeholder discipline (no implementation source beyond the sentinel; explicit README + CHANGELOG status) is the same; the count and the version-coupling shape are different.

3. **No Abstractions package — tokens IS the contract.** Files has a dedicated `HoneyDrunk.Files.Abstractions` package for the public contract surface, with a contract-shape canary in CI scoped to that package. Web.UI's "contract" is the tokens JSON shape itself — `@honeydrunk/web-ui-tokens` IS the contract. A contract-shape canary would need to compare the published tokens JSON against the previous version's published JSON — a different mechanism than the .NET `api-compatibility` workflow. This packet does NOT ship the JS-side contract-shape canary; it lands as a follow-up packet once the Grid commits to a tools-choice for JS API diff (e.g., `api-extractor`, `tsd`, or a tokens-specific differ). For v0.1.0 the structural-assertion tests in `packages/tokens/test/tokens.test.ts` provide the test-time floor.

4. **No `HoneyDrunk.Standards` reference at standup.** Web.UI is JS-first; `HoneyDrunk.Standards` is the .NET analyzer / build-tooling package. The Blazor placeholder doesn't reference Standards either (deferred to first feature packet per the placeholder discipline). The JS/TS analyzer / formatter stance is a separate decision — eslint / prettier / tsc-strict are reasonable defaults but no Grid-wide JS analyzer convention exists at scoping time. This packet ships with `tsc --strict` as the type-floor; lint rules are a follow-up if drift is observed.

5. **Three packets-of-context + scope-verification, not two.** Packet 03 carries an extra Wave-2 burden that Files / Audit / Identity didn't have: the npm scope verification + NPM_TOKEN seeding. This is the first JS-publishing Node standup, so the scope claim is a hard one-time gate. Files / Audit / Capabilities / Identity / Audit Communications didn't need this — they ship NuGet, which uses the existing OIDC credential.

## Notes

- **Why packet 03 carries npm scope verification.** ADR-0071 D6 commits to the `@honeydrunk` npm scope. If that scope is taken by an unrelated user/org, the package naming has to pivot — which would force an ADR amendment + cross-packet renames. Catching this at packet 03 (human-only Wave 2) instead of mid-scaffold (Wave 3 agent execution) keeps the surprise at the right wave. **Moving the npm scope step from the scaffold to packet 03 is a deliberate refine-pass decision** so packet 04's agent execution does not surprise-stop on a portal step.

- **Why three honest placeholders, not stubbed-out class shapes.** ADR-0071 D5 explicitly names tokens + CSS as Phase 1 and React/Blazor/Native components as Phase 2/3/4. Stubbing component shapes at standup would (a) lie about the package's status, (b) force a churn-PR when the real implementation lands, and (c) confuse consumers into thinking they can already import a `Button` from the React placeholder. The empty placeholder + explicit README is the honest shape — same pattern as `HoneyDrunk.Files.AzureBlob` in ADR-0061's scaffold packet.

- **Why the `tsconfig.base.json` is pinned to exact values in packet 04.** The refine-pass specifically called out `target: ES2022`, `module: "ESNext"`, `moduleResolution: "Bundler"`, `resolveJsonModule: true`, `engines.node: ">=22"`. These are the modern-2026 minimums for a clean TypeScript publishing setup; any drift (e.g., `target: ES2015` for older-browser support; `module: "CommonJS"` for legacy bundlers; `moduleResolution: "Node10"` for legacy module resolution) would force consumers into older toolchain compatibility modes. The pinned values are the load-bearing choice.

- **Why build scripts use `fileURLToPath()`.** On Windows, `new URL("..", import.meta.url).pathname` returns a leading-slash artifact like `/C:/path/to/file` that breaks `fs.mkdir` and `fs.writeFile`. The `fileURLToPath()` import from `node:url` is the cross-platform-correct way to derive a file system path from an ESM module's URL. The refine-pass specifically flagged the older `outPath.pathname.replace(/^\//, '')` workaround as fragile — `fileURLToPath()` is the right answer.

- **Why `tokens.test.ts` is structural and not hex-coupled.** If the test asserts `tokens.color.sector.core === "#7B61FF"` and `constitution/sectors.md` is later rebranded (a designer joins; the violetFlux gets a refresh), the test breaks even though the code is still correct. The structural assertion (iterates a sector-key list, asserts each key exists with a hex-shaped string value) is the right floor — a palette rebrand still passes. The refine-pass specifically called this out.

- **Why the `(Proposed)` qualifier was dropped on the invariants.** Earlier drafts of constitutional invariants for in-flight ADRs sometimes carried a qualifier like "(Proposed — takes effect when ADR-XXXX is accepted)". The refine-pass landed the editorial decision: drop the qualifier. The invariants land in their final active form. The reasoning: the ADR's "Done When" gate carries the proposed-vs-accepted semantic; the constitutional text should read as immediately-active because that's how the review agent treats it. Carrying the qualifier in invariant text creates ambiguity at review time. Three packets in this initiative honor this — packet 02's invariant text does NOT carry the qualifier.

- **Why Studios tokens inventory is captured in packet 01, not packet 04.** Packet 04 (the scaffold) needs concrete starting values for the tokens JSON's color block. If those values lived in the scaffold packet's body, they would be hard to cross-reference for Studios' migration packet (the agent reads the Architecture repo for context, not the Web.UI repo). Capturing the inventory at packet 01 (in the Architecture repo at `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md`) means: (a) packet 04's scaffolding agent has a stable reference; (b) Studios' future migration packet has the same reference; (c) the 9 sector colors live in one canonical place (Architecture's catalog domain, not the Web.UI repo where they would feel like product-specific data). The refine-pass landed this layout.

- **Status flip happens after merge, not now.** ADR-0071 stays Proposed for this scoping run. The user's standing workflow says the scope agent flips Status → Accepted after the follow-up PRs merge. None of the four packets here flip ADR-0071's Status — that is a separate housekeeping step the scope agent handles when the initiative completes.

- **`accepts: ADR-0071` frontmatter.** Every packet in this initiative carries `accepts: ADR-0071` so the hive-sync agent's auto-flip mechanic recognizes the initiative as the ADR's acceptance work. Per user constraint, this is mandatory and is checked at filing.

- **Repo is public by default.** Per memory `project_repos_public_by_default`, HoneyDrunk repos are public unless a revenue/compliance/experiment carve-out applies. Design tokens / CSS / component contracts are exactly the build-in-public substrate the Grid licenses — no carve-out applies. Packet 03's portal step specifies Visibility = Public.

- **No ADR numbers in user-facing docs or code comments.** Per memory `feedback_no_adr_in_docs`, the scaffold's README and per-package READMEs do **not** cite "ADR-0071" by number in their narrative — the README explains what the package does. Runtime / packet-data references (catalog entries, frontmatter, this dispatch plan, the CHANGELOG) are fine to cite ADRs by number.

- **No commits under CHANGELOG Unreleased.** Per memory `feedback_no_unreleased_commits`, the scaffold's first commit lands under `## [0.1.0] - YYYY-MM-DD`, not under `## Unreleased`. The tag push happens after merge — but the version section in CHANGELOG is dated and SemVer-bumped before the commit. Packet 04's acceptance criteria call this out.

- **No manual packet filing.** Per memory `feedback_no_manual_packet_filing`, file-work-items.yml auto-files on push to main. Do not run `gh issue create` against these packets. Filing happens by pushing the packet files into `generated/work-items/active/adr-0071-web-ui-standup/`. The filing-order rule above governs which packets land in which push.

- **Cluster value is `visualization`, not `frontend`.** The existing `nodes.json` taxonomy allows: `foundation`, `security`, `observability`, `infrastructure`, `orchestration`, `governance`, `visualization`, `cognition`, `quality`, `knowledge`. `frontend` is **not** in the taxonomy. `visualization` matches the Studios precedent (Studios is `cluster: "visualization"`) and is the closest semantic match for a design-substrate Node. Packet 01 honors this choice; packet 04 documents it in its Constraints.

## Status-flip handling

ADR-0071 stays at `Status: Proposed` for the duration of this scoping run and across all four packet PRs. Per the user's standing ADR acceptance workflow (`feedback_adr_workflow.md`): new ADRs start Proposed; the scope agent flips Status → Accepted only after the bundle's PRs have merged, never on a first-draft packet.

None of the four packets in this initiative flip ADR-0071's status. That is a separate housekeeping step the scope agent performs once packets 01 / 02 / 03 / 04 are all closed and the scaffold has merged and `v0.1.0` of `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` have published to npm. The flip is a one-line edit to `adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md` line 3 (`**Status:** Proposed` → `**Status:** Accepted`), plus any matching update to `adrs/README.md` if it carries a per-ADR Status entry, plus a CHANGELOG note.

This is the same pattern ADR-0061 Files standup, ADR-0031 Audit standup, ADR-0060 Identity standup, and ADR-0059 Cache standup followed.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND `@honeydrunk/web-ui-tokens 0.1.0` + `@honeydrunk/web-ui-css 0.1.0` are published to npm, the entire `active/adr-0071-web-ui-standup/` folder moves to `archive/adr-0071-web-ui-standup/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done` and `v0.1.0` ships.

## Filing

The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/work-items/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.
