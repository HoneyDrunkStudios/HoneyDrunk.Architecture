---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "ops", "docs", "infrastructure", "human-only", "adr-0081", "wave-1"]
dependencies: []
adrs: ["ADR-0081"]
accepts: []
wave: 1
initiative: adr-0081-home-server
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Author home-server hardware selection and budget brief (ADR-0081 D3)

## Summary
Author `infrastructure/home-server/hardware-brief.md` recording the chosen mini-PC make/model, RAM/storage/CPU configuration, budget, vendor, and purchase decision against ADR-0081's D3 minimum/preferred targets. This is the first of five Acceptance-Criteria artifacts ADR-0081 requires before it can flip to `Accepted`.

## Context
ADR-0081's Acceptance Criteria require: "Hardware target and budget are confirmed." D3 fixes the envelope: a boring low-power mini PC, not a rack/homelab project. The brief turns "modern low-power x86 CPU with virtualization support; 32 GB RAM minimum, 64 GB preferred; 1 TB NVMe minimum, 2 TB preferred; wired Ethernet; quiet/low-power; external backup target" into an actual purchase decision the operator can act on.

This packet is `Actor=Human` because the entire work item is a procurement and judgment decision — the agent cannot pick a SKU, place an order, or commit a budget on the operator's behalf.

## Scope
- New doc: `infrastructure/home-server/hardware-brief.md`.
- Updates `infrastructure/home-server/README.md` (new index file) to list the brief as the first artifact in the ADR-0081 series.

## Proposed Implementation

### Document structure for `hardware-brief.md`
1. **Decision summary** — chosen mini-PC make/model, total budget, vendor, order date (or "planned").
2. **Spec against D3** — table showing minimum, preferred, and chosen for CPU, RAM, storage, networking, power/noise envelope, and backup target.
3. **Rationale** — why this SKU vs alternatives at similar price/perf. Note virtualization support explicitly (D3 requires it).
4. **UPS disposition** — D3 says a UPS is "recommended once the box becomes relied upon for webhooks/scheduled automation." Record whether a UPS is bundled now, deferred (with a trigger), or not planned.
5. **Backup-target plan** — external drive or NAS named, capacity, where it physically lives. Detailed backup *operations* live in packet 05; this brief only confirms the hardware target exists.
6. **What this does not include** — explicitly: no GPU (D4 defers local-LLM hosting); no rack hardware (D3 says "not a homelab project").

### Index doc
Create `infrastructure/home-server/README.md` as the directory index, listing the five planned artifacts (hardware brief, OS hardening, security checklist, tunnel/bridge migration plan, backup plan) plus the D6 migration runbook. The index is a one-paragraph orientation plus a links table.

## Affected Files
- `infrastructure/home-server/README.md` (new)
- `infrastructure/home-server/hardware-brief.md` (new)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] Doc lives in `HoneyDrunk.Architecture/infrastructure/` — the established home for operator-facing infrastructure walkthroughs (precedent: `infrastructure/review-agent-credentials-setup.md` for ADR-0044).
- [x] No code change; no Node touched.
- [x] No secret committed (the doc references vendor and SKU only).

## Acceptance Criteria
- [ ] `infrastructure/home-server/README.md` exists and lists every planned artifact for this initiative with relative links
- [ ] `infrastructure/home-server/hardware-brief.md` records the chosen make/model, exact RAM/storage/CPU spec, total budget, vendor, and order/planned date
- [ ] The spec table maps every D3 minimum and preferred target to the chosen value with a pass/fail/N-A marker
- [ ] Virtualization support is explicitly confirmed on the chosen CPU (D3 requirement)
- [ ] UPS disposition is recorded (bundled / deferred-with-trigger / not-planned)
- [ ] Backup target hardware is named (external drive or NAS make/model and capacity)
- [ ] The doc explicitly states GPU and rack hardware are out of scope per D4 and D3
- [ ] Repo-level `CHANGELOG.md` gets a new in-progress entry referencing ADR-0081 and this packet (per invariants 12, 27 — this is the bumping packet for the initiative)
- [ ] No secret value appears in any committed file

## Human Prerequisites
- [ ] Research mini-PC SKUs against D3 minimums (Intel N100/N150 / i3 / i5 class, 32–64 GB RAM, 1–2 TB NVMe, wired NIC, low noise/power)
- [ ] Confirm budget envelope
- [ ] Select vendor and place order (or commit to a planned order date)
- [ ] Select and acquire backup-target hardware (or commit to a planned acquisition)
- [ ] Decide UPS disposition

## Dependencies
None. This is the first packet in the initiative and can land independently of the other Wave 1 artifacts.

## Agent Handoff

**Objective:** Record the operator's hardware decision for the home server in a versioned doc so ADR-0081's first Acceptance Criterion is satisfied.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Satisfy ADR-0081 Acceptance Criterion 1 ("Hardware target and budget are confirmed").
- Feature: ADR-0081 — Home Server for OpenClaw and Local Agent Infrastructure.
- ADRs: ADR-0081 (this initiative); ADR-0044 (the webhook-first review path that makes always-on hosting load-bearing).

**Acceptance Criteria:** (mirrored above)

**Dependencies:** None.

**Constraints:**
- ADR-0081 D3: "The first home server should be a boring low-power mini PC, not a rack/homelab project. Minimum target: Modern low-power x86 CPU with virtualization support (Intel N100/N150 class or better; i3/i5-class preferred if budget allows); 32 GB RAM minimum; 64 GB preferred for local agent concurrency and container headroom; 1 TB NVMe minimum; 2 TB preferred; Wired Ethernet; Quiet/low-power enough to run continuously; External backup drive or NAS target for backup. A UPS is recommended once the box becomes relied upon for webhooks/scheduled automation."
- ADR-0081 D4: "Running large local LLMs is not a Phase 1 requirement... Do not overbuy the first server for speculative GPU needs." — the brief must not include GPU spec.
- ADR-0081 Scope boundary: "This server is not a production application host for public HoneyDrunk customer-facing services/products." — the brief is for operator-owned local control-plane hosting only.

**Key Files:**
- `infrastructure/home-server/README.md` (new — directory index)
- `infrastructure/home-server/hardware-brief.md` (new — primary artifact)
- `CHANGELOG.md` (in-progress entry referencing ADR-0081)

**Contracts:** None — this is a documentation packet.

---

## PR Body Requirements
The PR opened against `HoneyDrunk.Architecture` for this packet must include in its body:

```
Authorship: Human
Packet: generated/issue-packets/proposed/adr-0081-home-server/01-architecture-home-server-hardware-brief.md
```

(`Authorship: Human` because this packet is `Actor=Human` — the operator authors the brief based on their procurement decision. If the operator delegates the markdown drafting to an agent after deciding the SKU, switch to `Authorship: Agent` and keep the same `Packet:` line.)
