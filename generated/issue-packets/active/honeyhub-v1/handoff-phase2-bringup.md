# Handoff — Phase 2 bringup (live-CLI smoke + mobile-relay validation)

**Read once at bringup.** This baton covers the human-run validation steps that the Phase 2 packets reference in their Human Prerequisites — the live Claude Code CLI smoke (packets 06, 08) and the mobile-over-Tailscale exercise (packets 05, 08). These cannot be fully covered by agent CI; they are operator-run on a real machine with real tools. Immutable point-in-time baton.

## 1. Live Claude Code CLI smoke (the kill-criterion check)
**Prerequisites:** the operator has the **official Claude Code CLI installed and authenticated** with their own local subscription session on the bridge host. The bridge never stores this auth — it relies on the CLI's own local session (the `[Firm]` ToS-clean path).

**Run, through the cockpit run screen (packet 08):**
1. Pair the PWA to the bridge (packet 05) — localhost / bundled-desktop path is fine.
2. Add a workspace root to the allowlist (packet 05) and confirm an out-of-allowlist path is refused.
3. Start a `claude.local` session against an allowlisted repo with a real task.
4. Watch the token-level stream render live.
5. Trigger a `needs_input` (a task that asks a clarifying question) and reply same-process.
6. Stop a run mid-flight; confirm graceful cancellation and the `stopping`→`cancelled` transition.
7. Let a run complete and produce an artifact (a branch/PR); confirm it renders as a metadata+link `DispatchArtifact` (no copied hunks).
8. Confirm the usage display shows **exact** tokens + USD (`fidelity: exact`, taken directly — not computed).

**Kill criterion (PDR-0011):** if the bridge cannot reliably stream + reply + stop for Claude Code, **stop and reduce scope to read-only session launch/logging** before building any governance — do not paper over a broken interactive path. Report the result to the operator; this is the gate the whole Phase 2 slice is validated against.

## 2. Mobile-over-Tailscale relay exercise (`[Provisional]`)
**Prerequisites:** Tailscale installed on **both** the bridge host (the operator's runner host / desktop) and the operator's phone, both on one tailnet. No inbound ports, no public surface, no HoneyHub-operated relay.

**Run:**
1. From the phone's browser, open the PWA and reach the bridge over the tailnet (the same wire protocol, same pairing token — pairing is transport-agnostic per packet 05).
2. Repeat steps 3–8 of the live-CLI smoke from mobile.
3. Confirm the mobile PWA drives the same bridge with no separate mobile UI (ADR-0091 D2 `[Firm]`: one shared PWA).

**`[Firm]` relay constraint:** the relay is an encrypted pass-through HoneyHub cannot read into; HoneyHub holds no vendor subscription auth on the path; HoneyHub operates no content-bearing middlebox. Tailscale (WireGuard mesh) satisfies this — HoneyHub runs no relay infra. A future zero-install dumb-pipe relay is `gated`, not in this bringup.

**Note:** the mobile exercise is **not blocking** for the Phase 2 packets (06/08) to merge — the bundled-desktop/localhost path is the primary Phase 2 exercise. Mobile validates the mobile-first HoneyDrunk requirement and de-risks Phase 4, but a relay hiccup does not block the first shippable slice landing.

## 3. What this bringup does NOT cover (deferred to Phase 3+)
- Codex / Copilot adapters (their own live-CLI smokes, with their own auth prerequisites — `gh` token for Copilot, ChatGPT local session for Codex).
- The routing engine, cost dashboard, coaching hints.
- The full Tauri-class single-installer packaging + code-signing + auto-update.
- Anything in the gated v2 cluster (BYOK cloud, Dev-surface, team governance, learned coaching).

## Reporting back
After the smoke + relay exercise, report to the operator: (a) did chat-shaped control work for Claude Code (the kill-criterion verdict), (b) did the exact-USD usage render correctly, (c) did the mobile/Tailscale path reach the bridge. These feed the PDR-0011 dogfood evaluation against the kill criteria.

**Record the verdict as a committed artifact.** The kill-criterion verdict is not just a verbal report — commit a short **bringup-result note** to the HoneyDrunk.HoneyHub repo (e.g. `docs/bringup/phase2-bringup-result.md`) capturing: the date, the Claude Code CLI version, the kill-criterion verdict (chat-shaped control reliable Y/N for stream/reply/stop), whether exact-USD rendered correctly, whether the mobile/Tailscale path reached the bridge, and — **if the verdict is "reduce scope"** — the explicit decision that the slice falls back to read-only launch/logging. This committed note is the durable record the dogfood evaluation and any future re-scope reference; a verbal-only verdict is not sufficient.
