---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0070", "wave-3", "human-only"]
dependencies: ["packet:00"]
adrs: ["ADR-0070"]
accepts: ["ADR-0070"]
wave: 3
initiative: adr-0070-frontend-stack
node: honeydrunk-architecture
---

# Reconcile the four consumer-PDR frontend-stack sections with ADR-0070 (operator decision)

## Summary
Two of the four consumer PDRs that ADR-0070 names as direct consumers — **PDR-0005 (Hearth)** and **PDR-0008 (Curiosities, inheriting PDR-0004 Wayside)** — explicitly commit to **native Swift + Kotlin** for mobile and explicitly **reject** React Native, Flutter, and MAUI. ADR-0070 D3 commits the Grid to **React Native + Expo** for all mobile surfaces. This is a direct conflict that needs operator architectural judgment, not silent reconciliation. The packet is `Actor=Human` because the resolution is one of three substantive choices the operator must make, and the chosen path requires either amending ADR-0070, amending the PDRs, or both.

PDR-0003 (Lately) already commits to React Native + Expo and aligns cleanly. PDR-0006 (Currents) does not commit a frontend stack and inherits ADR-0070 by default. No conflict for those two.

## Context

### What ADR-0070 commits

ADR-0070 D3 (Accepted via packet 00):

> Every mobile surface in the Grid uses **React Native + Expo**. iOS and Android come from a single codebase; the operator does not maintain two native apps.
>
> The committed shape:
> - **React Native** (current stable; tracked by the Web.UI Node's cadence where applicable).
> - **Expo** (the managed React Native runtime — eliminates most of the native-toolchain pain that vanilla RN imposes on a solo dev).
> - **Expo EAS Build** for app builds.
> - **Expo Notifications** for push.
> - **Expo Router** for routing.

ADR-0070's "Native Swift/Kotlin for mobile" alternative section is explicit about the trade:

> Solo-dev with two native codebases is not viable. The maintenance burden — two test surfaces, two release pipelines, two language ecosystems, two SDKs to track — exceeds what one human plus AI agents can sustain on the charter's many-decade horizon. … Native is held in reserve for the scenario where a specific consumer PDR's UX requirements exceed what RN+Expo can deliver (e.g., a graphics-intensive consumer app where the native rendering pipeline matters). No current or queued PDR meets that bar.

The phrase "No current or queued PDR meets that bar" is in tension with PDR-0005's and PDR-0008's actual commitments. The operator authored both — this packet surfaces the conflict for explicit resolution.

### What PDR-0005 (Hearth) commits

PDR-0005 §"Tech stack — load-bearing decisions" / "Mobile":

> - **iOS first.** SwiftUI native. Core ML for the on-device sentiment classifier and theme tracker. WeatherKit for weather sync.
> - **Android in v1.5.** Likely Kotlin + Jetpack Compose. Cross-platform frameworks (Flutter, .NET MAUI, React Native) are evaluated and rejected for v1: the watercolor render pipeline and the on-device ML pipeline both benefit from native platform APIs, and the cross-platform overhead is not worth the engineering velocity for a small mobile team.

Reasons cited: watercolor render pipeline + on-device ML pipeline benefit from native platform APIs (Core ML, WeatherKit).

### What PDR-0008 (Curiosities, inheriting PDR-0004 Wayside) commits

PDR-0008 §J inherits PDR-0004 §I's tech-stack position unchanged. PDR-0004 §I:

> **Cross-platform framework:** Native Swift (iOS) and Kotlin (Android). **Not** .NET MAUI, **not** Flutter. The aesthetic and gesture standards Wayside needs (custom map rendering, smooth scrolling, watercolor texture rendering) are easier to hit on native than on cross-platform frameworks.

Note: PDR-0004's §I does not explicitly name React Native as evaluated-and-rejected, but it commits to "Native Swift (iOS) and Kotlin (Android)" — which is incompatible with ADR-0070 D3.

### What PDR-0003 (Lately) commits

PDR-0003 §H:

> Three options evaluated [React Native + TypeScript / Flutter + Dart / Native Swift + Kotlin]. **Recommended: React Native** with Expo for fast iteration. Native modules only where required (camera, push notifications, deep links).

PDR-0003 **aligns** with ADR-0070 D3. No conflict.

### What PDR-0006 (Currents) commits

PDR-0006 does not commit a frontend stack in its Decision or Architecture Implications sections. It inherits ADR-0070 by default. No conflict.

### The operator-judgment question

Three substantive paths are available; the operator chooses:

**Path A — Amend ADR-0070 D3 to carve out a native-stack exception for graphics-intensive / on-device-ML consumer apps.**

The exception language already exists in ADR-0070's "Native Swift/Kotlin for mobile" alternative section ("Native is held in reserve for the scenario where a specific consumer PDR's UX requirements exceed what RN+Expo can deliver"). The amendment makes the exception concrete and gives PDR-0005 and PDR-0008 a sanctioned route.

Pros: preserves PDR-0005's and PDR-0008's existing commitments and their reasoned native-API arguments. Carves out a clean policy line ("graphics-intensive or on-device-ML consumer apps may opt out of D3 with an ADR amendment").

Cons: weakens ADR-0070's "no current or queued PDR meets that bar" framing; permits the multi-codebase tax the ADR rejected, on the actual two next-build PDRs (Hearth is the scout's first-build pick).

**Path B — Amend PDR-0005 and PDR-0008 to commit to React Native + Expo.**

Both PDRs are re-evaluated in light of ADR-0070's reasoning (AI-multiplier gradient, solo-dev sustainability). The watercolor render pipeline and Core ML / WeatherKit access are re-examined against Expo's native-module-escape-hatch capabilities (Expo Dev Client, Expo Modules, Expo Bare Workflow — ADR-0070 D6's per-PDR escalation path).

Pros: preserves ADR-0070's three-stack discipline at full strength. Forces an honest re-evaluation of whether PDR-0005's and PDR-0008's "native is necessary" argument actually survives 2026's RN+Expo maturity and Expo Modules's native-module integration.

Cons: requires PDR amendments and may meaningfully change PDR-0005's product shape (the watercolor town render is core identity). May not survive an honest re-eval — the on-device Core ML sentiment classifier and the watercolor render pipeline are genuinely tighter on native.

**Path C — Acknowledge a per-PDR exception without amending ADR-0070.**

Each conflicting PDR (PDR-0005, PDR-0008) carries an explicit "this PDR predates ADR-0070; the native commitment is retained per PDR §X; a future ADR amendment will document the carve-out if more than one PDR needs it" note. The carve-out is not codified in ADR-0070 itself.

Pros: cheapest immediate path — the conflicts get an honest annotation without forcing an ADR amendment or PDR rewrite right now.

Cons: leaves the policy unstable. A third PDR that wants native gets to claim the same carve-out by precedent; the policy degrades from "no native" to "ad hoc native" without explicit policy commitment. Anti-pattern under invariant 24's spirit (issue packets are immutable for the same reason: ad-hoc divergence corrodes the substrate).

### Why this packet is `Actor=Human`

The choice between Paths A, B, and C is **architectural judgment** — exactly the case the scope agent's Actor section calls out:

> `Actor=Human` — the entire work item cannot be delegated. Examples: creating a new GitHub repo, **making an architectural judgment call on a new pattern**…

The downstream PR work (the amendment, the PDR edits, the cross-reference notes) is delegable once the operator picks the path. But picking the path is the human action. This packet exists to surface the conflict, name the three paths, and trigger the operator decision. A follow-up agent-actored packet (or a set of them) lands the chosen path's edits.

This is also a case where ADR-0070's framing — "No current or queued PDR meets that bar" — is materially inaccurate in the as-authored ADR text. Either ADR-0070 is updated to acknowledge the PDR-0005/0008 exceptions (Path A), or the PDRs change (Path B), or the inaccuracy is annotated with a known-exception note (Path C). Doing nothing leaves a documented conflict in the substrate, which is the failure mode the conflict-flagging exists to prevent.

## Scope

The packet itself produces **no automatic edits**. It is a decision request. The follow-up packets (filed after operator selection) deliver the chosen path's edits.

If **Path A** is chosen:
- Edit `adrs/ADR-0070-frontend-platform-stack.md` D3 to add the native-stack exception language.
- Edit `adrs/ADR-0070-frontend-platform-stack.md` "Alternatives Considered" → "Native Swift/Kotlin for mobile" to weaken the "no current or queued PDR meets that bar" claim and acknowledge PDR-0005 and PDR-0008.
- File-packet `Actor=Agent` follow-up to execute the edits once operator picks Path A.

If **Path B** is chosen:
- Edit `pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md` §"Tech stack" Mobile subsection.
- Edit `pdrs/PDR-0004-wayside-walking-and-public-place-notes.md` §I (and update PDR-0008's §J inheritance note).
- File-packet `Actor=Agent` follow-up to execute the edits once operator picks Path B.

If **Path C** is chosen:
- Add an "ADR-0070 exception note" to PDR-0005 §"Tech stack" and PDR-0004 §I (with PDR-0008 inheriting the same note via §J).
- Annotate ADR-0070 D3 with a "Known exceptions: PDR-0005 §X, PDR-0008 (via PDR-0004 §I) — pre-ADR-0070 native commitments; carve-out documented in PDR, not yet codified in ADR-0070" note.
- File-packet `Actor=Agent` follow-up to execute the edits once operator picks Path C.

## Proposed Implementation

This is an `Actor=Human` packet. The implementation is **the operator picking a path** and then either:

1. Authoring the resulting amendment text inline (low ceremony — the operator drops the chosen text into the issue body / a follow-up commit) and the file-issues / scope agents author the agent-actored execution packet, **or**
2. Delegating the amendment authoring to the adr-composer agent (Path A) or to a per-PDR composer / refine pass (Path B / Path C), which produces the final amendment text.

In either case, this packet's closure is gated on the operator's path selection being recorded in the issue body. The execution packet (filed against `HoneyDrunk.Architecture` per the chosen path) is a separate follow-up packet, not part of this initiative folder unless the operator chooses to file it here.

## Affected Files

None directly. The packet is a decision-request. Affected files depend on the path chosen — see Scope.

## NuGet Dependencies
None.

## Boundary Check
- [x] All work in `HoneyDrunk.Architecture`. The conflict is between an Architecture-repo ADR (ADR-0070) and Architecture-repo PDRs (PDR-0003/0004/0005/0006/0008). The follow-up edits all land in the same repo.
- [x] No code change in any other repo.
- [x] `Actor=Human` is correct — the operator must pick the path before any agent can execute.

## Acceptance Criteria
- [ ] The operator records the chosen path (A, B, or C — or a hybrid) in this issue's body or in a follow-up comment
- [ ] A follow-up `Actor=Agent` execution packet is filed (in this initiative folder if the operator chooses, or as a standalone packet) carrying the actual amendment text for the chosen path
- [ ] The conflict between ADR-0070 D3 and PDR-0005 / PDR-0008 is **explicitly resolved** in the substrate — not left as undocumented divergence
- [ ] PDR-0003 (Lately) and PDR-0006 (Currents) are not touched (they already align with ADR-0070 D3 or inherit it by default)
- [ ] No silent edit to ADR-0070 body without operator selection — the ADR header is Accepted; further substantive edits require an explicit amendment per the ADR-acceptance workflow

## Human Prerequisites
- [ ] The operator reads ADR-0070 D3 and the "Native Swift/Kotlin for mobile" Alternatives Considered section
- [ ] The operator reads PDR-0005 §"Tech stack — load-bearing decisions" → Mobile subsection
- [ ] The operator reads PDR-0004 §I (which PDR-0008 §J inherits)
- [ ] The operator picks one of Paths A / B / C (or a hybrid — e.g., Path A for the graphics-intensive carve-out + Path C for the timing-defer on PDR-0008 because Curiosities is sequenced behind Hearth) and records the choice
- [ ] If Path B is selected and either PDR's product shape needs to change, the operator confirms the change is acceptable (the watercolor render pipeline and Core ML / WeatherKit access are the core product surfaces under threat)

## Referenced ADR Decisions

**ADR-0070 D3 — React Native + Expo for mobile.** "Every mobile surface in the Grid uses React Native + Expo. iOS and Android come from a single codebase; the operator does not maintain two native apps."

**ADR-0070 "Alternatives Considered" — Native Swift/Kotlin for mobile.** "Solo-dev with two native codebases is not viable… Native is held in reserve for the scenario where a specific consumer PDR's UX requirements exceed what RN+Expo can deliver… No current or queued PDR meets that bar."

**ADR-0070 D6 — Native-feature escape hatches.** "When a mobile feature requires Expo Modules / native code that Expo Managed Workflow does not cover, the per-PDR escalation path (Expo Dev Client → Expo Bare Workflow → custom native module) is documented at the consuming PDR, not here."

**PDR-0005 §"Tech stack — load-bearing decisions" / Mobile.** "iOS first. SwiftUI native. Core ML for the on-device sentiment classifier and theme tracker. WeatherKit for weather sync. Android in v1.5. Likely Kotlin + Jetpack Compose. Cross-platform frameworks (Flutter, .NET MAUI, React Native) are evaluated and rejected for v1."

**PDR-0004 §I (inherited by PDR-0008 §J).** "Cross-platform framework: Native Swift (iOS) and Kotlin (Android). Not .NET MAUI, not Flutter."

**PDR-0003 §H.** "Recommended: React Native with Expo for fast iteration." (Aligns with ADR-0070 D3 — no conflict.)

## Constraints
- **Surface the conflict; do not silently resolve it.** The operator is the deciding authority. This packet's role is to make the conflict actionable, not to pre-commit a path.
- **Preserve PDR-0003 and PDR-0006.** PDR-0003 already aligns; PDR-0006 inherits by default. Neither needs editing under any of the three paths.
- **Follow-up packet is a separate filing.** Once the operator picks a path, a `Actor=Agent` packet authors the actual edits. That packet may or may not live in this initiative folder — the operator chooses.
- **Default Path: explicit non-default.** If the operator does not act on this packet for an extended period, the default outcome is **not** silent acceptance of any path. The conflict remains documented and pending. (No code path defaults to "use native because the ADR went silent.")
- **AI-multiplier honesty.** ADR-0070's reasoning leaned on the AI-multiplier gradient (per-token-of-agent-attention productivity). PDR-0005's reasoning leaned on native-only platform APIs (Core ML on-device, WeatherKit). Both arguments are real; neither is dismissible. The operator's path selection is a judgment about which argument carries more weight for the consumer-PDR portfolio specifically.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0070`, `wave-3`, `human-only`

## Agent Handoff

**Objective:** Surface the ADR-0070-vs-PDR-0005/0008 mobile-stack conflict for explicit operator resolution. This packet does not edit any file; it triggers the operator decision that gates the follow-up execution packet.

**Target:** `HoneyDrunk.Architecture`, branch from `main` (when the follow-up execution packet runs — not this packet).

**Context:**
- Goal: Resolve the documented conflict between ADR-0070 D3 (RN + Expo) and PDR-0005 / PDR-0008's native-Swift+Kotlin commitments without silent divergence.
- Feature: ADR-0070 Frontend Platform Stack rollout, Wave 3.
- ADRs: ADR-0070 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — hard. ADR-0070 must be Accepted before its conflict with PDR-0005/0008 is binding policy.

**Constraints:**
- `Actor=Human` — operator picks Path A, B, or C (or hybrid).
- No silent edits. The substrate must explicitly record whichever resolution path is chosen.
- Follow-up execution packet is separately filed once the operator selects a path.

**Key Files (touched only by the follow-up execution packet, not this one):**
- `adrs/ADR-0070-frontend-platform-stack.md` (Path A or C)
- `pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md` (Path B or C)
- `pdrs/PDR-0004-wayside-walking-and-public-place-notes.md` (Path B or C — inherited by PDR-0008)

**Contracts:** None.
