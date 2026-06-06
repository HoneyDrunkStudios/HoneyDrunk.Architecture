# ADR-0091: HoneyHub App Stack and Repo / Node Home

**Status:** Proposed
**Date:** 2026-06-06
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform
**Implements:** [PDR-0011](../pdrs/PDR-0011-honeyhub-v1-agent-cockpit-and-usage-governance.md) (HoneyHub v1 — Agent Cockpit) §"Architecture Implications" + Amendment §6 (the `[Provisional]` app-stack / Tauri-class-shell / mobile-relay decision the PDR named as a follow-up artifact).
**Relationships:** Builds on [ADR-0090](ADR-0090-honeyhub-local-runner-bridge.md) (HoneyHub Local Runner Bridge) — answers its deferred open question "does the first bridge live in an existing HoneyHub repo, a new repo, or an ADR-0086 runner package," and consumes its session contract / capability flags. Stands up a new Node via the [ADR-0082](ADR-0082-canonical-node-standup-procedure.md) canonical standup procedure. Consumes the [PDR-0009](../pdrs/PDR-0009-honeyhub-as-internal-daily-driver-workspace.md) structural-backend framing (Architecture repo as read backend) for the later Dev-surface layer. Builds on the [ADR-0086](ADR-0086-pull-based-local-worker-grid-review-runner.md) local-worker substrate as the solo-mode bridge host. Tracked in the [HoneyHub program](../initiatives/programs/honeyhub.md). Sibling to [ADR-0092](ADR-0092-honeyhub-session-usage-telemetry-and-routing.md) (Session, Usage Telemetry, and Routing).

---

## Context

ADR-0090 decided the **bridge boundary** and the **session contract** (`DispatchSession` / `DispatchRun` / `UsageSignal`, capability flags, PRs-as-artifacts, the `[Firm]` BYOK-only-cloud rule). It explicitly did **not** decide "the actual app": where the code lives, what UI framework renders the cockpit, what language the bridge is implemented in, how the project is structured, how the static PWA surface is built/deployed, or how a mobile PWA reaches a bridge running on a different machine. ADR-0090 deferred all of that to "the app-stack ADR" and left a matching open question on the books. This is that ADR.

The product shape this ADR packages is fixed by PDR-0011 Amendment §6 ("Option A," already chosen by the operator):

- **One shared web/PWA UI** serving both mobile (HoneyDrunk solo operation) and desktop (individual developers) — built in parallel, not phased.
- **Desktop = a single packaged native shell (Tauri-class) that bundles the local bridge** — one easy install, so a developer does not separately install a UI and a bridge daemon.
- **Mobile = the same PWA**, reaching the bundled bridge over a **secure relay**.

This ADR does not re-litigate that product shape; it decides the **engineering substrate** that realizes it and registers the Grid Node that owns the code. It is deliberately narrow: it picks a UI framework, a bridge implementation language, a repo/package structure, a static-PWA build/deploy path, and a mobile relay mechanism — and it marks the genuinely revisable choices `[Provisional]` so they can move on signal without a new ADR (per the PDR-0011 Amendment §7 flexibility posture).

---

## Decision

### D1. The code lives in a new Grid Node and repo: `HoneyDrunk.HoneyHub`

HoneyHub v1 gets its **own new Node and repo**, registered through the [ADR-0082](ADR-0082-canonical-node-standup-procedure.md) canonical standup procedure. This resolves ADR-0090's open question "existing HoneyHub repo, new repo, or ADR-0086 package": **a new repo**, not an existing one (there is no existing HoneyHub *app* repo — `HoneyDrunk.Studios` is the marketing site, and the ADR-0086 runner is operator-internal automation, not a product surface) and not an ADR-0086 package (the runner substrate *hosts* the solo-mode bridge, but it is not where the cockpit code lives).

- **Node name: `HoneyDrunk.HoneyHub`.** Chosen over `HoneyDrunk.Web` (the placeholder name floated in PDR-0011's open questions) because the product is not "the Grid's web UI" — it is a named product (Agent Cockpit) with desktop + mobile surfaces and a bundled bridge, broader than a single web front-end. `HoneyDrunk.HoneyHub` keeps the product name as the Node identity and leaves `HoneyDrunk.Web.*` free for the eventual internal Grid web front-ends if those ever need their own Node. `[Provisional]` — the exact Node id can still change at standup time if a better convention surfaces; what is `[Firm]` is that it is *a new, dedicated Node*, not a folder inside an existing repo.
- **Node class (ADR-0082 D2): `studios-typescript-native`** — the dedicated dual TS-UI + native-bridge class added to ADR-0082 D2 by its 2026-06-06 one-row amendment (the lightweight "new shape ⇒ one-row D2 amendment + per-class walkthrough" path ADR-0082 pre-authorizes; node-standup.md names "Tauri desktop" as exactly such a case). HoneyHub is a TypeScript web/PWA + Tauri-class shell surface plus a native (Rust) bridge crate in one dual **Node + Cargo** workspace. CI is a **self-contained `pr.yml`** that directly invokes the npm/pnpm lane **and** a `cargo build`/`cargo test`/`cargo clippy` lane — it does **not** call the .NET `pr-core.yml`, and there is **no** `pr-typescript.yml` reusable workflow in HoneyDrunk.Actions (the PR reusable workflows are `pr-core.yml`/`pr-sdk.yml`/`pr-review.yml`, all .NET-shaped), so this follows ADR-0082 D5y's "invoke CLIs directly until that workflow is built" path. The required `main` branch-protection check is the job's own name — **`pr / build`** — not `pr-core / core`; no `.slnx`/`Directory.Build.props`/`HoneyDrunk.Standards`/NuGet; no org secret is required by default. (If D3's bridge-language pick ever moved to .NET, the repo would still be a TS-UI + native-binary workspace and remain in this class — only the lane's toolchain would change.)

The actual catalog/sector/context-folder wiring (`nodes.json`, `relationships.json`, `grid-health.json`, `sectors.md`, `repos/HoneyDrunk.HoneyHub/`, `repo-to-node.yml`) is **node-standup execution work**, not performed by this ADR — see D6 and the Consequences. This ADR names the Node and its placement; the standup packet lands the edges.

### D2. The stack is "Option A": one shared web/PWA UI; a Tauri-class desktop shell bundling the bridge; mobile = the same PWA over a secure relay

This restates the PDR-0011 Amendment §6 product decision as the engineering target, so D3–D5 have a fixed frame:

| Surface | What ships | Bridge reach |
|---|---|---|
| **Web / PWA** | One responsive web app, installable as a PWA. The single UI codebase for every surface. | Talks to a bridge over the wire protocol (ADR-0090 follow-up). |
| **Desktop** | A **Tauri-class native shell** that wraps the same web UI **and bundles the local bridge** in one installer. One install = UI + bridge, paired locally with zero relay. | Bridge runs in-process / co-bundled; localhost. |
| **Mobile** | The **same PWA** (no separate native app at v1). | Reaches a bridge on the operator's runner host / desktop over the **secure relay** (D5). |

This is `[Firm]` at the shape level (it is the operator's chosen Option A) and `[Provisional]` at the implementation level (which Tauri-class toolkit, which relay) — the firm/provisional split is enumerated in the Decision Ledger.

### D3. UI framework and bridge language `[Provisional]`

Two concrete picks, both `[Provisional]` (revisable by a conversation + an amendment note, no new ADR, per PDR-0011 Amendment §7), with rationale:

**UI framework `[Provisional]`: React + Vite, as a PWA, wrapped by the desktop shell.**

- React is the Grid's committed web stack ([ADR-0070](ADR-0070-frontend-platform-stack.md) — React for web) and the Web.UI design-token system ([ADR-0071](ADR-0071-stand-up-honeydrunk-web-ui-node.md)) already targets React, so the cockpit inherits the Grid's component/token discipline instead of inventing a parallel one. Vite gives a fast static-PWA build that drops straight onto a static host (D4) and is the standard renderer source for Tauri-class shells.
- Rationale for `[Provisional]`: the *exact* meta-framework is the revisable part. If the later PDR-0009 Dev-surface layer (server-rendered, data-heavy) makes a Next-style SSR framework pay for itself, the UI can migrate within the React commitment without crossing a `[Firm]` line. The `[Firm]` part is "one shared React PWA codebase across all three surfaces"; the meta-framework choice is the working assumption.

**Bridge implementation language `[Provisional]`: Rust, paired with the Tauri-class desktop shell.** *(Operator-confirmed 2026-06-06. Remains `[Provisional]` per the flexibility posture — revisable behind the stable ADR-0090 session contract — but Rust is the endorsed default, not an open question.)*

Three candidates were weighed against the ADR-0090 contract (process launch/lifecycle, stream/reply/stop, official-CLI driving under the user's own local auth, secure pairing, artifact detection):

| Candidate | Pros | Cons |
|---|---|---|
| **Rust** *(selected, `[Provisional]`)* | Pairs natively with the Tauri-class shell (Tauri's core is Rust) — the bridge and the desktop shell share one runtime and one installer, which is the **whole point of Option A's "one easy install."** Strong process-control and IPC story; small, dependency-light single-binary daemon that is also clean to ship as a standalone service on the ADR-0086 runner host for solo mode. | Not a Grid-native language (the Grid is .NET + TypeScript); a third language to maintain. Smaller in-house familiarity than .NET/TS. |
| **Node / TypeScript** | Shares the language and toolchain with the web UI; one dependency graph; fastest to a first adapter given the UI is already TS. | Bundling a Node runtime into the Tauri-class shell fights the shell's Rust core (you end up shipping two runtimes); heavier process-control story; a long-lived Node daemon on the runner host is a larger surface than a Rust binary. |
| **.NET** | Grid-native; reuses Kernel/AI contracts directly; the routing layer (ADR-0092) reaches into HoneyDrunk.AI which is .NET, so a .NET bridge could share types. | Does **not** pair with the Tauri-class shell (no native .NET-in-Tauri story) — you'd ship a .NET runtime alongside the shell, defeating the single-install goal; heaviest install footprint of the three for a per-developer local daemon. |

**Pick: Rust**, because Option A's bundled-shell-with-bridge is the load-bearing product requirement and Rust is the only candidate that makes "the desktop shell *is* the bridge host" a single binary rather than two stapled runtimes. The cost — a third Grid language — is accepted and explicitly flagged in Risks. Marked `[Provisional]`: if the desktop-shell toolkit pick (D2) moves to a non-Rust shell, or if the first adapter spike shows the official CLIs are far cheaper to drive from the UI's own TS process, the bridge language is revisited via an amendment note — no `[Firm]` line is crossed by swapping the adapter language behind the stable ADR-0090 session contract (the contract is the boundary; the implementation language is not).

> **Note on the routing/AI-contract pull toward .NET.** ADR-0092's routing engine plugs into HoneyDrunk.AI's `IRoutingPolicy` (.NET, ADR-0010). That is **not** a reason to make the bridge .NET: the routing/telemetry logic is a HoneyHub-app concern that can call HoneyDrunk.AI over a contract boundary (or reimplement the cost-first policy shape app-side and treat HoneyDrunk.AI as the canonical policy source), and the routing engine does not run *inside* the local bridge — it runs in the app/UI tier where session and usage data aggregate. The bridge's job is narrow (drive local CLIs); the routing brain lives a layer up. See ADR-0092 D3.

### D4. Repo/package structure and static-PWA build/deploy

**Structure `[Provisional]`: a single repo, lightly multi-package (a workspace), not a many-repo split.**

- One `HoneyDrunk.HoneyHub` repo containing: the **web/PWA UI** package, the **desktop shell** package (the Tauri-class wrapper), and the **bridge** package (Rust per D3). A workspace layout (e.g. a pnpm/Cargo workspace pair) keeps the three buildable and versioned together while staying one repo — consistent with the operator's "one PR per repo per initiative" working rule and avoiding cross-repo version lockstep for a v1 product that ships as one unit.
- `[Provisional]` because the package granularity (one UI package vs. UI + shared-types + shell + bridge as four packages) is a working assumption to refine as the surface grows; the `[Firm]` part is "one repo for the v1 product," not the internal package count.

**Static-PWA build/deploy:**

- The PWA surface is a **static build** (Vite output: HTML/JS/CSS + service worker + manifest). The bridge is **local** (bundled in the desktop shell, or run on the ADR-0086 runner host for solo mode) — it is **not** a hosted backend, so there is no server tier to deploy for v1. This keeps the deploy story trivial and the `[Firm]` "local-first" posture intact.
- **Hosting:** the static PWA is served from the Grid's existing edge platform — Cloudflare Pages per [ADR-0029](ADR-0029-cloudflare-dns-and-edge-platform.md) (Cloudflare as the Grid's registrar / DNS / edge), on a HoneyHub subdomain. `[Provisional]` — any static host works; Cloudflare Pages is the default because the Grid already commits Cloudflare at the edge and the PWA is pure static assets. No Azure Container App / Functions deploy is needed for the cockpit itself (it would be needed only later, for a hosted relay or the BYOK-cloud provider — both gated, both out of this ADR).
- The desktop shell ships as a **downloadable installer** (per-OS Tauri-class bundle), distributed from the HoneyHub site / GitHub Releases. Code-signing and auto-update are standup/packaging concerns, named as follow-up, not decided here.

### D5. Mobile relay mechanism `[Provisional]`

The mobile PWA cannot run a local CLI; it must reach a bridge on another machine (the operator's runner host or desktop). ADR-0090's spike already found that **Claude Code (`--remote-control`) and Copilot (`--remote`/`--connect`) ship native remote-session control** — but that is per-backend session control, not a general transport for the *whole cockpit* (session list, usage, notifications, control events across all three backends). HoneyHub still needs one secure network path from the PWA to the bridge.

Options weighed (the four ADR-0090 named — LAN, Tailscale, cloud relay, hosted HoneyHub tunnel):

| Option | Pros | Cons |
|---|---|---|
| **Same-LAN direct** | Zero infra; trivial. | Useless off the home network — fails the mobile-first HoneyDrunk requirement the moment the operator leaves the LAN. |
| **Tailscale (WireGuard mesh)** *(selected v1, `[Provisional]`)* | Secure by default (end-to-end WireGuard); the bridge host and the operator's phone join one tailnet; no inbound ports, no public surface, no HoneyHub-operated relay to run or pay for. Fits the solo-operator + ADR-0086-runner-host shape exactly. Honors the `[Firm]` "HoneyHub holds no subscription auth / no hosted execution" boundary — HoneyHub operates **no** middlebox that sees session content. | Requires the user to install Tailscale (acceptable for solo/operator and individual-dev tiers; a friction point for a future zero-install consumer tier). Not a HoneyHub-branded path. |
| **HoneyHub-operated cloud relay / hosted tunnel** | Zero client setup; brandable; the smoothest future consumer experience. | HoneyHub would operate a middlebox carrying session traffic — a security, cost, and **`[Firm]`-boundary** risk (a relay that terminates/forwards session content drifts toward the hosted-execution shape the Grid bans; it must stay a dumb encrypted pipe if ever built). Real infra to run and pay for. Deferred. |

**Pick: Tailscale for v1**, with the per-backend native remote-control (`--remote-control` / `--remote`) used where it cleanly covers a single backend's live session. `[Provisional]` because the relay is exactly the kind of packaging assumption PDR-0011 Amendment §7 lists as revisable: if a zero-install consumer tier becomes real, a HoneyHub-operated **dumb-pipe** relay (encrypted end-to-end, HoneyHub never decrypts session content) is the documented next step — gated on demand, and constrained so it never becomes a content-bearing middlebox. The `[Firm]` constraint on this row is not "use Tailscale" but "any relay is an encrypted pass-through HoneyHub cannot read into, and HoneyHub never holds vendor subscription auth on the path."

### D6. Node-graph placement (stated, not catalog-committed here)

This ADR **states** the relationships; the actual `catalogs/*.json` and `constitution/sectors.md` edits are ADR-0082 node-standup execution (Phase A of the standup), deliberately **not** performed by this ADR — consistent with the recent convention that scope/standup work, not the deciding ADR, touches shared catalogs (ADR-0082 D3 Phase A; the ADR-0027 packet-01 deferral precedent).

The intended placement, for the standup packet to wire:

- **`HoneyDrunk.HoneyHub` → Architecture repo** (consumes): as the **structural read backend** for the later Dev-surface layer (PDR-0009 §B — Architecture repo as HoneyHub's structural backend; the cockpit reads decisions/catalogs as a derived read-index, never authoritatively writes them).
- **`HoneyDrunk.HoneyHub` → local runner bridge** (composes): the bridge defined by ADR-0090 is *part of this Node* (the bundled-shell package per D2/D3), exercising the ADR-0090 session contract.
- **`HoneyDrunk.HoneyHub` → `HoneyDrunk.AI`** (consumes, later): for the routing layer's `IRoutingPolicy` per ADR-0092 / ADR-0010 — a relationship named for when the routing telemetry ADR lands, not wired at v1 standup.
- **`HoneyDrunk.HoneyHub` → ADR-0086 runner substrate** (hosts): the runner host is the solo-mode bridge host; this is an operational hosting relationship, not a package edge.
- **Sector: Meta / AI / Platform**, matching PDR-0011 and ADR-0090.

No catalog edge is committed by this ADR. Over-committing the graph here would duplicate the standup packet's Phase-A work and risk drift between the ADR text and the catalog; the standup packet is the single place those edges land.

---

## Consequences

### Positive

- ADR-0090's deferred "where does the app live" question is closed: a named new Node (`HoneyDrunk.HoneyHub`), a named stack (React PWA + Tauri-class shell + Rust bridge), a named structure (one workspace repo), a named deploy (static on Cloudflare Pages), and a named relay (Tailscale).
- The bundled-shell-with-bridge realizes Option A's "one easy install" — the Rust bridge and Tauri-class shell share one runtime and one installer.
- The static-PWA + local-bridge shape means **no hosted backend to deploy or pay for at v1**, keeping the `[Firm]` local-first posture and the cost story near-zero (no Container App / Functions tier for the cockpit).
- Tailscale honors the `[Firm]` boundary: HoneyHub operates no content-bearing middlebox and holds no subscription auth on the mobile path.
- Reuses Grid commitments instead of inventing parallel ones: ADR-0070 React, ADR-0071 design tokens, ADR-0029 Cloudflare edge, ADR-0082 standup, ADR-0086 runner host.

### Negative

- **A third Grid language (Rust).** The Grid is .NET + TypeScript; the Rust bridge adds a toolchain, a CI lane, and a maintenance surface. Accepted as the price of the single-install Option A; flagged `[Provisional]` so it can be revisited if the desktop-shell pick or the adapter-spike economics change.
- **A mixed-class Node** (TypeScript UI + native bridge) is a new ADR-0082 standup shape. Resolved: ADR-0082 D2 gained a dedicated seventh class, **`studios-typescript-native`**, via its 2026-06-06 one-row amendment; HoneyHub stands up under that class (self-contained `pr.yml`, required check `pr / build`, dual Node + Cargo workspace, no NuGet/Standards, no org secret by default).
- **Tailscale install friction** is acceptable for solo/individual-dev tiers but is a known gap for any future zero-install consumer tier — the deferred dumb-pipe relay is the named (gated) answer.
- **Desktop packaging surface** (per-OS installers, code-signing, auto-update) becomes real product work, named as follow-up.

### Affected / named Nodes

- **`HoneyDrunk.HoneyHub`** (new) — owns the cockpit UI, the Tauri-class shell, and the bundled bridge. Stood up via ADR-0082.
- **`HoneyDrunk.Architecture`** — consumed as the structural read backend (later Dev-surface layer); standup packet lands the catalog edges.
- **`HoneyDrunk.AI`** — consumed later for routing (ADR-0092); named, not wired here.
- **ADR-0086 runner host** — solo-mode bridge host (operational, not a package edge).

### Cascade

- Node standup (ADR-0082) for `HoneyDrunk.HoneyHub`: catalog rows, sector row, context folder, repo creation, branch protection, CI, `repo-to-node.yml`, org-secret binding — all **execution work**, not this ADR.
- No `constitution/invariants.md` change. This ADR introduces **no new invariant** — the `[Firm]` boundaries it relies on (BYOK-only cloud, local-first, PRs-as-artifacts, no content-bearing middlebox) are already established by ADR-0090 and PDR-0011 Amendment §3/§7; restating them as a relay constraint does not warrant a constitution entry for a solo operator (consistent with ADR-0089 D7 and ADR-0090's no-new-invariant posture).
- No catalog/Node-graph edge is committed by this ADR (D6).

### Tier

Tier 2 (per `routing/request-types.md`) — a product/stack decision that unblocks a standup; the standup itself and the build work are the heavier follow-ups.

---

## Alternatives Considered

### Put the cockpit code in an existing repo (HoneyDrunk.Studios or the ADR-0086 runner)

Rejected. `HoneyDrunk.Studios` is the marketing site (different deploy, different audience, different stack discipline); the ADR-0086 runner is operator-internal automation, not a product surface. Folding a product into either blurs both. A dedicated Node is the clean home and matches every prior product standup (Notify Cloud got its own Node per ADR-0027).

### Node / TypeScript bridge (share the UI's language)

Rejected as the v1 pick (kept as the named `[Provisional]` fallback). Sharing the UI's language is genuinely attractive and would reach a first adapter fastest, but bundling a Node runtime into the Tauri-class shell ships two runtimes and fights the shell's Rust core — defeating Option A's single-install goal. If the adapter spike shows driving the official CLIs from TS is dramatically cheaper, the `[Provisional]` tag allows the swap.

### .NET bridge (Grid-native, shares HoneyDrunk.AI types)

Rejected. The Grid-native pull is real, but .NET does not pair with the Tauri-class shell (no native .NET-in-Tauri story → two runtimes in the installer) and is the heaviest per-developer local-daemon footprint. The routing layer's need for HoneyDrunk.AI types is satisfied over a contract boundary (ADR-0092 D3), not by making the bridge .NET.

### Native mobile app instead of the shared PWA

Rejected for v1, consistent with PDR-0011 Amendment §6 ("mobile = the same PWA"). A native app is a separate codebase, store-review cycle, and maintenance surface; the PWA reuses the one shared UI and reaches the bridge over the relay. A native shell can wrap the PWA later if push/notification limits demand it.

### HoneyHub-operated cloud relay as the v1 mobile path

Rejected for v1. A HoneyHub-run relay is the smoothest future consumer experience but introduces a content-bearing middlebox (security, cost, and `[Firm]`-boundary risk) before the core UX is proven. Tailscale gives a secure path with no HoneyHub-operated infra; the dumb-pipe relay is the gated next step if a zero-install tier becomes real.

### Multi-repo split (UI repo + shell repo + bridge repo)

Rejected for v1. Three repos for one product that ships as a single unit forces cross-repo version lockstep and triples the standup/CI surface. One workspace repo keeps the three packages buildable together; the split is available later if the surfaces diverge.

---

## Decision Ledger

Per the HoneyHub flexibility posture (PDR-0011 Amendment §7), each decision is tagged `[Firm]` or `[Provisional]`. Firm boundaries are kept minimal and load-bearing.

- **`[Firm]`** — do not move without a real new decision:
  - **HoneyHub v1 lives in its own dedicated new Node/repo** (`HoneyDrunk.HoneyHub`), stood up via ADR-0082 — not folded into an existing repo or the ADR-0086 package (D1).
  - **Option A stack shape** (D2): one shared web/PWA UI; desktop = a Tauri-class shell that **bundles the bridge** (one install); mobile = the same PWA over a secure relay. (This is the operator's chosen product shape, PDR-0011 Amendment §6.)
  - **Local-first / no hosted backend at v1** (D4): the PWA is static; the bridge is local; there is no server tier for the cockpit. (Inherits PDR-0011 §G / Amendment §7 local-first default.)
  - **Any mobile relay is an encrypted pass-through HoneyHub cannot read into, and HoneyHub never holds vendor subscription auth on the path** (D5) — the relay never becomes a content-bearing or auth-holding middlebox (ties to the ADR-0090 D10 / PDR-0011 Amendment §3 `[Firm]` boundary).
  - **One shared React PWA codebase across all three surfaces** (D3) — not three divergent UIs.
- **`[Provisional]`** — working assumptions, revise on signal via a conversation + an amendment note here (no new ADR) as long as no `[Firm]` line is crossed:
  - the Node id string `HoneyDrunk.HoneyHub` (rationale: a better naming convention may surface at standup);
  - the UI meta-framework within the React commitment — React + Vite PWA today; SSR (Next-class) allowed later if the Dev-surface layer pays for it (D3);
  - the **bridge language: Rust** (rationale: pairs with the Tauri-class shell for single-install Option A; revisit if the shell pick changes or the adapter spike favors TS) (D3);
  - the desktop-shell toolkit (Tauri-class, exact toolkit TBD) (D2);
  - the repo package granularity — one workspace repo, package count TBD (D4);
  - the static host — Cloudflare Pages default, any static host works (D4);
  - the **mobile relay: Tailscale** for v1; HoneyHub-operated dumb-pipe relay is the gated next step for a zero-install tier (D5).

> **Lightweight amendment note (template for future revisions):** A `[Provisional]` change is recorded as a dated bullet appended to this ledger ("Amended YYYY-MM-DD: bridge language moved Rust → TypeScript because the desktop-shell pick moved to an Electron-class shell; no `[Firm]` line crossed"). Only crossing a `[Firm]` line requires a new or amended ADR.

---

## Open Questions

| Question | Owner | Status |
|---|---|---|
| Exact desktop-shell toolkit (Tauri vs a Tauri-class alternative) and its code-signing / auto-update story. | Architecture / Product | Open — packaging follow-up. |
| Does the mixed TS-UI + Rust-bridge repo need a new ADR-0082 D2 class row, or does it standup as two declared classes in one repo? | Architecture | **Resolved (2026-06-06)** — new ADR-0082 D2 class `studios-typescript-native` (one-row amendment); HoneyHub stands up under it with a self-contained `pr.yml` (required check `pr / build`). |
| When does the PDR-0009 Dev-surface read-layer attach, and does it pull the UI toward SSR? | Architecture / Product | Open — gated (v2 / Dev-surface). |
| If a zero-install consumer tier becomes real, what is the exact dumb-pipe relay design that stays inside the `[Firm]` no-content-middlebox boundary? | Architecture / Security | Open — gated on demand. |
