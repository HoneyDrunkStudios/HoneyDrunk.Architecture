# Dispatch Plan — HoneyHub v1 (Standup + Phase 2)

**Initiative:** `honeyhub-v1`
**Sector:** Meta (ADRs label it "Meta / AI / Platform"; `Meta` is the canonical existing sector)
**Program:** [HoneyHub](../../../../initiatives/programs/honeyhub.md) (the cross-ADR program tracker; current-focus row #1, the lead near-term build thread per PDR-0011)
**Governing ADRs (all stay at current Status across these packet PRs):**
- [ADR-0090 — Local Runner Bridge](../../../../adrs/ADR-0090-honeyhub-local-runner-bridge.md) (Accepted) — bridge boundary + session contract + capability flags (spike-validated).
- [ADR-0091 — App Stack and Repo / Node Home](../../../../adrs/ADR-0091-honeyhub-app-stack-and-repo-node-home.md) (Proposed) — new `HoneyDrunk.HoneyHub` Node; React+Vite PWA; Tauri-class shell bundling the bridge; **bridge = Rust**; Cloudflare Pages static host; Tailscale mobile relay; no hosted backend at v1.
- [ADR-0092 — Session, Usage Telemetry, Routing](../../../../adrs/ADR-0092-honeyhub-session-usage-telemetry-and-routing.md) (Proposed) — DispatchSession/UsageSignal persistence (local-first); exact/derived/estimated fidelity; routing into ADR-0010; rules-based coaching.
- [ADR-0082 — Canonical Node Standup](../../../../adrs/ADR-0082-canonical-node-standup-procedure.md) — the standup procedure.

**Trigger:** ADR-0090 Accepted + ADR-0091/0092 Proposed (operator-confirmed stack: new repo, React+Vite PWA, Tauri-class shell, **Rust bridge**). The program tracker's Next action: "cut the `HoneyDrunk.HoneyHub` node-standup packets (ADR-0082) and the session/usage-telemetry + routing implementation packets." This initiative is the standup + Phase 2 (the first shippable slice); Phase 3+ is outlined at low resolution (packet 09).

**Type:** **Multi-repo** — `HoneyDrunk.Architecture` (the program tracker: catalog registration, context folder, repo-to-node mapping) + the new `HoneyDrunk.HoneyHub` repo (scaffold + Phase 2 build).

**Site sync required:** No at standup/Phase 2 (no public-API surface change to publicize yet). When the Creator/Meta cockpit goes live and a `0.x` ships, a site-sync follow-up may publicize HoneyHub — flag then, not now.

## Scope detection: multi-repo
Two repos:
1. **`HoneyDrunk.Architecture`** — Phase A standup registration (packet 01) + Phase B human repo creation tracking + the `repo-to-node.yml` mapping (packet 02).
2. **`HoneyDrunk.HoneyHub`** (new) — the scaffold (packet 03) and all of Phase 2 (packets 04–08) + the Phase 3+ outline tracker (packet 09).

The `HoneyDrunk.HoneyHub → HoneyDrunk.Architecture` (read backend) and `→ HoneyDrunk.AI` (routing) edges are **named but not wired** at v1 (ADR-0091 D6); the AI consume edge is wired when the Phase 3+ routing packet is cut (packet 09 notes this).

## Wave Diagram
```
Wave 1: Phase A — Architecture registration                    (Agent)
   └─ Architecture: 01-architecture-honeyhub-catalog-registration
        (no deps; lands catalogs + 5-file context folder + sector row;
         declares node_class: studios-typescript-native per the ADR-0082 2026-06-06 amendment)

Wave 2: Phase B — GitHub repo creation                          (Human)
   └─ Architecture(tracking): 02-architecture-create-honeyhub-repo
        Blocked by: packet 01
        (repo + branch protection on `pr / build` + labels + repo-to-node.yml + clone;
         no org secret required by default for studios-typescript-native)

Wave 3: Phase C — scaffold                                      (Agent)
   └─ HoneyHub: 03-honeyhub-node-scaffold
        Blocked by: packet 01, packet 02
        (workspace monorepo: React+Vite PWA + Rust bridge crate + shell wrapper +
         shared-types session contract; dual-lane CI; no Grid package published)

Wave 4: Phase 2 — bridge core + trust boundary                 (Agent)
   ├─ HoneyHub: 04-honeyhub-bridge-core
   │     Blocked by: packet 03
   │     (run-state machine, AgentBackendAdapter trait, process lifecycle,
   │      wire protocol, fake adapter — the keystone)
   └─ HoneyHub: 05-honeyhub-pairing-and-allowlist
         Blocked by: packet 04
         (per-device identity, revocable token, workspace-root + backend allowlist)

Wave 5: Phase 2 — the one backend + the local store            (Agent)
   ├─ HoneyHub: 06-honeyhub-claude-code-adapter
   │     Blocked by: packet 04, packet 05
   │     (claude.local — official CLI, local auth, exact tokens+USD)
   └─ HoneyHub: 07-honeyhub-local-store-and-notifications
         Blocked by: packet 04
         (embedded local-first store + retention + state-only notifications)

Wave 6: Phase 2 — the run screen (integration capstone)        (Agent)
   └─ HoneyHub: 08-honeyhub-minimal-run-screen
         Blocked by: packet 06, packet 07
         (start/watch/reply/stop/see-artifacts; fidelity-honest usage display)
         ← FIRST SHIPPABLE SLICE COMPLETE

Wave 7: Phase 3+ outline (tracking placeholder)                (Agent)
   └─ HoneyHub: 09-honeyhub-phase3-plus-outline
         Blocked by: packet 08
         (Codex+Copilot adapters, usage normalization+cost, routing engine,
          coaching, Tauri packaging, Tailscale relay — each re-scoped before exec)
```

Within a wave, packets can run in parallel (05 depends only on 04; 07 depends only on 04, so 06 and 07 can proceed once their deps land). Across waves, sequencing is strict via the `dependencies:` frontmatter — the keystone (04) gates everything in Phase 2; the run screen (08) is the last integration step.

## Packet List
| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Register HoneyDrunk.HoneyHub in Architecture catalogs + 5-file context folder](./01-architecture-honeyhub-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Create HoneyDrunk.HoneyHub repo + branch protection + labels + repo-to-node + org-secret + clone](./02-architecture-create-honeyhub-repo.md) | Architecture (tracking) | 2 | Human | packet:01 |
| 03 | [Scaffold HoneyDrunk.HoneyHub — workspace monorepo (React+Vite PWA + Rust bridge crate), dual-lane CI](./03-honeyhub-node-scaffold.md) | HoneyHub | 3 | Agent | packet:01, packet:02 |
| 04 | [Rust bridge core — process lifecycle + session contract over the wire (stream/reply/stop)](./04-honeyhub-bridge-core.md) | HoneyHub | 4 | Agent | packet:03 |
| 05 | [Secure pairing + workspace-root allowlist + backend allowlist](./05-honeyhub-pairing-and-allowlist.md) | HoneyHub | 4 | Agent | packet:04 |
| 06 | [Claude Code backend adapter — drive the official CLI under the user's own local auth](./06-honeyhub-claude-code-adapter.md) | HoneyHub | 5 | Agent | packet:04, packet:05 |
| 07 | [Local-first DispatchSession store + state-only notifications](./07-honeyhub-local-store-and-notifications.md) | HoneyHub | 5 | Agent | packet:04 |
| 08 | [Minimal React PWA run screen — start/watch/reply/stop/see artifacts](./08-honeyhub-minimal-run-screen.md) | HoneyHub | 6 | Agent | packet:06, packet:07 |
| 09 | [Phase 3+ outline (Codex/Copilot, usage+cost, routing, coaching, packaging, relay)](./09-honeyhub-phase3-plus-outline.md) | HoneyHub | 7 | Agent | packet:08 |

## Handoffs (wave-transition batons)
- [`handoff-standup-to-phase2.md`](./handoff-standup-to-phase2.md) — read at the Wave 3→4 transition (scaffold landed → build the bridge): the session contract, the build order, the `[Firm]` boundaries, the Phase 2 kill-criterion gate.
- [`handoff-phase2-bringup.md`](./handoff-phase2-bringup.md) — read at Phase 2 bringup: the human-run live Claude Code CLI smoke (the kill-criterion check, referenced by packets 06/08) and the mobile-over-Tailscale relay exercise (referenced by packets 05/08).

## Open / unresolved decisions for the refine pass to focus on
These are deliberately **not over-committed** in the packets; the refine pass should sharpen each before (or at) the relevant packet:
1. **Mixed TS+Rust node-class** — **RESOLVED.** ADR-0082 D2 gained a dedicated seventh class, **`studios-typescript-native`**, via its 2026-06-06 one-row amendment (operator-approved); `constitution/node-standup.md` is updated in lockstep. HoneyHub stands up under that class: a dual Node + Cargo workspace, a **self-contained `pr.yml`** (NOT `pr-core.yml`), required `main` check **`pr / build`**, no NuGet/Standards, and **no org secret required by default**. Packets 01/03 + ADR-0091 D1 declare `node_class: studios-typescript-native`; packet 02 wires `pr / build` into branch protection.
2. **The wire protocol** (ADR-0090 `[Provisional]`). Packet 04 commits a concrete versioned protocol behind a clean boundary; the exact shape (WebSocket vs HTTP+SSE) is the implementer's call — refine should confirm it survives both localhost and the Tailscale relay.
3. **Routing-engine placement** (ADR-0092 Open Q, `[Provisional]`) — live HoneyDrunk.AI `IModelRouter` call vs app-side policy-config copy. Deferred to Phase 3+ (packet 09); the refine pass for the routing child packet must resolve it, and that packet also wires the deferred `HoneyHub → AI` catalog edge.
4. **Mobile relay** (ADR-0091 D5, `[Provisional]`) — Tailscale for v1; pairing is built transport-agnostic (packet 05) so the relay does not bake into the trust core. Refine the relay bringup (handoff) separately; a zero-install dumb-pipe relay is `gated`.
5. **Embedded store engine + retention windows** (ADR-0092 D1, `[Provisional]`) — SQLite-class default + a 30-day-ish transcript window; packet 07 ships configurable defaults. Refine if dogfooding shows different needs.
6. **Desktop-shell toolkit + code-signing + auto-update** (ADR-0091 Open Q) — deferred to Phase 3+ (packet 09 §3f); the scaffold (packet 03) ships only a minimal shell wrapper.
7. **Web.UI design-token adoption** — packet 03 consumes `@honeydrunk/web-ui-tokens` if available, else ships local placeholder tokens with a follow-up. Refine should confirm Web.UI token availability at scaffold time.

## Scoping risks
- **First `studios-typescript-native` Grid repo.** The dual Node+Rust CI lane in a **self-contained `pr.yml`** (not `pr-core.yml`) is new; the scaffold (packet 03) is where it is proven, with the required `main` check being the repo's own **`pr / build`**. The first-PR `status: skipped`/add-check-after-first-run pattern still applies for surfacing the check name in branch protection — not a blocker, but the first real exercise.
- **Third Grid language (Rust).** ADR-0091 accepts this cost explicitly and marks the bridge language `[Provisional]`. If the adapter spike (packet 06) shows driving the official CLIs from the UI's own TS process is dramatically cheaper, the bridge language can move TS-ward via an ADR-0091 amendment note (no `[Firm]` line crossed — the ADR-0090 session contract is the boundary, not the implementation language). Surface this signal from packet 06.
- **Kill criterion is real.** Packet 08 (run screen) + the bringup handoff validate the PDR-0011 Phase 2 kill criterion: if chat-shaped control can't reliably stream/reply/stop for Claude Code, scope reduces to read-only launch/logging. Do not let packets 04–06 paper over a broken interactive path.
- **No hosted backend at v1 (`[Firm]`).** The PWA is static (Cloudflare Pages, a deploy concern handled outside this initiative); the bridge is local. No Azure Container App / Function / Key Vault / managed identity applies to HoneyHub at v1 — do not provision any. The only "infra" touches are the GitHub repo (packet 02) and (later, deferred) a Cloudflare Pages project. No org secret is required by default for this `studios-typescript-native` Node (the self-contained `pr.yml` consumes none; `SONAR_TOKEN` is bound only if a Sonar lane is later added).
- **BYOK / subscription-auth boundary (`[Firm]`).** The entire v2 cloud cluster is gated; nothing in this initiative touches subscription auth or hosted execution. Any packet drifting toward holding/forwarding a subscription token crosses the ADR-0090 D10 / PDR-0011 §3 hard boundary — reject in review.

## Status-flip handling
ADR-0091 and ADR-0092 stay at `Status: Proposed` (and ADR-0090 stays Accepted) across all packet PRs. None of these packets flips any ADR Status. Per the operator's standing workflow, the scope agent flips ADR-0091/0092 → Accepted only after this initiative's PRs have merged and the Phase 2 slice ships — a separate post-merge housekeeping step (one-line edit to each ADR header + `adrs/README.md` + a CHANGELOG note). The **standup packets (01–03) carry `accepts: ADR-0091`** so hive-sync's auto-flip mechanic recognizes the standup as the ADR-0091 acceptance work; the Phase 2 build packets (04–09) do **not** carry an `accepts:` field (they are implementation against already-decided ADRs, not the acceptance trigger).

## Implementation-notes packet
Per the operator's standing process (ADR-0008 amendment), this initiative closes with an as-built implementation-notes record authored by the **implementing** agent (not hive-sync) capturing decided→as-built deltas (e.g. the actual wire protocol chosen, the actual store engine, whether the bridge language held at Rust, the mixed-class CI shape as built). Cut that packet when Phase 2 ships; it never rewrites the immutable packets/decisions.

## Filing
`file-packets.yml` in `HoneyDrunk.Architecture` triggers automatically on push to `generated/issue-packets/active/**/*.md` and runs `file-packets.sh` — it creates each issue, adds it to The Hive (project #4), sets Status/Wave/Node/Tier/Actor/Initiative/ADR fields from frontmatter, and wires `addBlockedBy` from each packet's `dependencies:` array. **No `gh issue create` / `gh project item-add` / `addBlockedBy` commands here** — they run automatically once the packets land on `main`. Verify a wave landed by checking The Hive for the new items + their blocked-by chains.

Filing-order note: packets 01–09 can all be pushed together — the `dependencies:` frontmatter wires the blocking edges so the board reflects the strict cross-wave ordering automatically (packet 02 blocked-by 01; 03 blocked-by 01+02; 04 blocked-by 03; etc.). The human packet (02) and the Phase 3+ tracker (09) file the same way.

## Archival
Per ADR-0008 D10, when every packet reaches `Done` on The Hive **and** the Phase 2 slice ships, the entire `active/honeyhub-v1/` folder moves to `archive/honeyhub-v1/` in a single commit. Partial archival is forbidden. hive-sync moves individual closed packet files `active/`→`completed/` per the per-packet lifecycle; initiative-level archival is the post-completion sweep.
