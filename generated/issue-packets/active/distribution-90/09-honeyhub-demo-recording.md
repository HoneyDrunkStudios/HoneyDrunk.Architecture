---
name: HoneyHub 2-Minute Demo Recording
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["chore", "tier-1", "ai", "distribution-90", "honeyhub", "human-only"]
dependencies: ["packet:06"]
adrs: ["PDR-0011"]
source: human
generator: scope
wave: 3
initiative: distribution-90
node: honeydrunk-honeyhub
actor: human
---

# Chore: Record the 2-minute HoneyHub demo (phone over Tailscale)

## Summary
Record a ~2-minute screen capture of the real thing: driving a live Claude Code session in a real repo from a phone, over Tailscale, through the HoneyHub cockpit. Host it (YouTube, public or unlisted-then-public at launch) and link it from the HoneyHub README. The demo is the single highest-leverage launch asset — Show HN and the blog post live or die on "show me".

## Context
Distribution 90 Wave 3. `Actor=Human`: recording requires the operator's physical devices (phone + dev machine), live Tailscale network, real vendor session auth, and the operator's narration/taste. No part of the critical path is delegable; an agent follow-up may embed the link (folded into packet 10's PR or a one-line README commit).

## Suggested shot list (guidance, not a script)
1. Cold open on the phone: cockpit connected, repo visible (~10s — no setup footage; setup is README material).
2. Dispatch a real task to Claude Code (something visibly real, e.g. "fix this failing test" in a real repo).
3. Show the session streaming live on the phone; pocket the phone moment optional but effective.
4. Show the result landing (diff/PR), and the cost/token usage display (a PDR-0011 v1 differentiator — always-on usage visibility).
5. Close: one line on what HoneyHub is (free, local-first, your own CLIs) + where to get it.

Honesty constraint (PDR-0011 `[Firm]` honest-capability-flags principle, extended to marketing): no staged/faked output, no sped-up segments presented as real-time without a label.

## Human Prerequisites
- [ ] Everything — this packet is entirely operator work: record, edit (cuts only; no production polish needed), upload, set thumbnail/title, provide the URL for README/post embedding.

## Acceptance Criteria
- [ ] ≤ ~2:30 video showing a real phone-driven Claude Code session end-to-end against HoneyHub v0.1.0 (or the release-candidate `main` that becomes v0.1.0).
- [ ] Hosted at a stable public URL (public at latest by packet-11 submission time).
- [ ] Linked from the HoneyHub `README.md` (replacing packet 08's placeholder) — this one-line edit may be done by an agent or folded into packet 10's work.
- [ ] Nothing in-frame leaks secrets, tokens, private repo content, or non-public Grid material (treat the recording like a log under invariant 8's spirit: secret values never appear in any emitted surface).

## Dependencies
- `packet:06` — the launch-blocking stack must be merged so the demo shows the real shipping build. (Recording may run in parallel with packet 08's docs work; re-record only if 08 visibly changes the UX.)

## Downstream Unblocks
Packets 10 (post embeds the demo) and 11 (submissions link it).

## Agent Handoff
**Objective:** Not delegable — `Actor=Human` (`human-only`). The only agent-eligible fragment is the post-hoc README link edit, which belongs to packet 10 or a trivial follow-up commit.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub` (README link), recording itself off-repo.
**Constraints:** honesty constraint above; secret hygiene in-frame.
**Key Files:** `README.md` (one line, post-recording).
**Contracts:** None.
