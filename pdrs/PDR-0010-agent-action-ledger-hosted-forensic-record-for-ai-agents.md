# PDR-0010: Agent Action Ledger — Hosted Forensic Record for AI-Agent Actions

**Status:** Proposed / Exploring
**Date:** 2026-05-27
**Deciders:** HoneyDrunk Studios
**Sector:** Core / AI (substrate) · Ops (commercial wrapper) · Meta (positioning)
**Relationship:** Sequenced **behind** [PDR-0002](PDR-0002-notify-as-a-service-first-commercial-product.md) (Notify Cloud — first commercial product). **Aligns** with [PDR-0001](PDR-0001-honeyhub-platform-observation-and-ai-routing.md) §B (`IModelRouter`, cost-ledger plumbing) and with [ADR-0030](../adrs/ADR-0030-grid-wide-audit-substrate.md) / [ADR-0031](../adrs/ADR-0031-stand-up-honeydrunk-audit-node.md) (Audit Node as a record substrate, not a telemetry pipeline — invariant 47). **Aligned** with manifesto belief #7 (small surface, strong contracts).

---

## Status Caveat — Read This First

**This PDR captures thinking, not a green light.**

The Grid is pre-1.0. The Audit Node is at Seed signal. Notify Cloud has not launched. Opening a second commercial front today would split solo-dev focus across two pre-launch products and one pre-1.0 substrate cluster.

This PDR exists so the thinking is recorded while the substrate (Audit Phase-1, the `IModelRouter` + `ICostLedger` plumbing, the Capabilities permission model) is being built around the eventual product. It is **not** a commitment to build. The substrate is being built for the Grid's own internal needs first (invariant 47 — durable, attributable record of who-did-what); whether to wrap that substrate in a commercial product is a separate question, evaluated at a separate time, against the kill criteria in §K.

The strategist's explicit sequencing (Scout pass, 2026-05-26) was:

1. Notify Cloud (PDR-0002) ships and produces a first-revenue signal.
2. Audit Phase-1 (ADR-0031) lands and stabilizes — `IAuditLog`, `IAuditQuery`, `AuditEntry`, Data-backed append-only store, Auth wired as first emitter.
3. The strategist is re-invoked in **Critic** mode against the state of the world at that point.
4. Only **then** is this PDR considered for promotion from Proposed / Exploring to Accepted.

Any of those gates failing collapses this PDR back to a recorded direction the studio did not take. That is a valid outcome.

---

## Context

The product-strategist agent's Scout pass on 2026-05-26 identified a packaged-product opportunity at the 2-to-3-year horizon, behind Notify Cloud: a **hosted, append-only, forensic record for AI-agent actions** — "agent X called tool Y with arguments Z on tenant T at time U, outcome V, cost W" — with query and replay.

Three market signals converged in the week preceding the Scout pass:

- **OpenTelemetry GenAI semantic conventions graduated CNCF (2026-05-21).** Telemetry shape for agent calls is now standardized across vendors. Pure-OTel cost-tracking is going to commoditize.
- **Microsoft shipped `AgentGovernance.Extensions.ModelContextProtocol` (2026-05-22).** First-party .NET governance hooks for MCP-based agent runtimes. The Microsoft-shaped composition seam is now load-bearing.
- **Supply-chain agent incidents — TeamPCP / VS Code extension exfil (2026-05-26).** Procurement is starting to ask the "who-touched-what-with-what-token" question with a budget line attached. This shifts the buyer from "engineering curiosity" to "compliance ask."

The intersection of those three signals — standardized telemetry shape, first-party .NET runtime hooks, and budgeted compliance demand — produces a 2027 buyer profile that does not yet have a packaged product to point at.

This PDR records the substrate-cluster bet the Grid is making that, if all three signals hold and the strategist clears Critic mode, becomes a packaged product.

### The substrate cluster already aligns

The product would be assembled from primitives the Grid is building anyway, for its own internal use:

- **`HoneyDrunk.Audit`** (ADR-0030 / ADR-0031) — durable, attributable, append-only-by-interface record substrate. Invariant 47 explicitly carves Audit out of telemetry (`IAuditLog` and `IAuditQuery` are not Pulse; audit *records* never flow to Pulse). The Audit Node is the only Grid Node *designed as a record substrate, not a telemetry pipeline.*
- **`HoneyDrunk.AI` `IModelRouter` + `ICostLedger`** (PDR-0001 §B, invariant 45) — every inference call already produces a routing decision and a cost-attributable record, with cost rates sourced from App Configuration. The cost dimension required by the buyer's "track which workflows are eating your AI bill" hook is already substrate-resident.
- **`HoneyDrunk.Capabilities`** — tool registry, schema versioning, permission guards. The "did the permission check fire correctly" question (the retention-tier wedge — see §B) has a contract surface here.
- **`HoneyDrunk.Vault`** per-tenant secret routing (invariant 9a, `TenantScopedSecretResolver`) — tenants bringing their own MCP server keys / model provider keys have a substrate-resident composition story.

This is the join no pure-observability vendor (Sentry, Datadog, Honeycomb) can build retroactively — they conflate telemetry and record-of-truth at the storage layer. The Grid's invariant 47 makes that conflation a build-time failure.

### The market window

The strategist's argument for *now-vs.-2026*: the three signals above are converging *this quarter*, and the dominant 2027 agent-runtime substrate (MCP) just got its first-party .NET governance hooks (signal b). Building the substrate now, on the Grid's own timeline, with first-party Microsoft seams already in the ecosystem, is materially cheaper than building it in 2027 against a pre-existing telemetry vendor's retro-fitted "agent observability" surface.

But the Grid is solo-dev and pre-1.0. The window is real; the capacity to ship into it is not, until Notify Cloud has produced a sales-motion signal in the same buyer segment (.NET shops). This PDR refuses to open a second commercial front before that signal exists.

---

## Problem Statement

### 1. The Grid's substrate cluster is being built for internal use, but the same cluster is a packaged product the .NET ecosystem does not have

The Audit Node, `IModelRouter`, `ICostLedger`, and Capabilities are being built because the Grid's own internal use needs them (invariant 47: incident reconstruction; invariant 28: no hardcoded models; invariant 45: operator-configurable cost rates). Independently of any commercial intent, the cluster ends up looking exactly like a 2027 SaaS product wedge.

The risk is that without recording this thinking now, the substrate gets built in a shape that is correct for internal use but expensive to retrofit for external use (re-marshalling AuditEntry into a different transport, re-introducing tenant scoping after the fact, etc.). The fix is cheap: record the eventual external shape now, then verify at each substrate decision that the internal-shape choice does not foreclose the external-shape option.

### 2. The buyer profile exists, but does not yet pay for a packaged product

**Primary buyer (2027 horizon):** Engineering lead at a 20-to-80-person regulated .NET shop (fintech, healthtech, regulated SaaS) running Claude Code, GitHub Copilot Agents, internal MCP servers, or `Microsoft.AgentGovernance.*` flows in production, who will get a 2027 compliance ask and have nothing to show.

What this buyer has today:

- Helicone, Langfuse, OpenLLMetry — all show the *cost* of LLM calls. None of them is shaped as a record-of-truth. Their retention is observability-class (sampled, time-bounded, telemetry-coupled).
- Sentry / Datadog / Honeycomb — generic APM. Will add "agent observability" features, but their storage shape is the wrong substrate to retrofit a 7-year audit window onto.
- Roll-your-own — what most .NET shops are doing today. Brittle, never reviewed, falls over the moment a compliance auditor asks for it.

What this buyer needs (and the Grid's substrate is shaped for):

- **Attribution** — which tenant / user / workflow triggered the cost?
- **Policy** — did the Capabilities permission check fire correctly? Did the model-router policy hold?
- **Replay** — given a 90-day-old prompt, can the call be reconstructed?
- **Retention** — can the record survive a 7-year audit window without going through a telemetry vendor's retention tier (which makes the economics impossible)?

### 3. The Grid cannot afford to open a second commercial front today

PDR-0002 is in flight. Notify Cloud has not launched. The sales motion in the .NET-shop buyer segment is unproven. Opening a second commercial front today would:

- Split solo-dev attention across two pre-launch products.
- Risk shipping both at lower quality than either deserves.
- Validate neither sales motion cleanly — losing the diagnostic signal of "did the .NET-shop wedge work" because too many variables changed at once.

The fix is sequencing, not abandonment. Notify Cloud first; this PDR's substrate-cluster bet gets validated as a side effect of internal need; commercial wrapping waits for the Notify Cloud signal.

### 4. The cost-only "AI observability" category already exists — and is the wrong product to compete with directly

Helicone, Langfuse, OpenLLMetry, and the OTel GenAI semconv collectively already own the "track which workflows are eating your AI bill" use case. That is *cost-as-telemetry*, and the substrate beneath it is observability-shaped. Building a Grid-hosted product that competes on this surface alone is a losing fight against incumbents with more engineering hours, more language coverage, and a longer head start.

The Grid's edge is not cost-as-telemetry. It is **cost as attribution into a record substrate** — the join between the cost ledger and the Audit substrate's append-only, tenant-attributable, permission-correlated record. Cost is the hook (an existing budget line buyers already know how to expense); the retention surface — attribution, policy, replay — is the product.

This distinction is load-bearing. §F formalizes it as a boundary disclaimer.

---

## Decision

The decisions below are recorded with **Proposed / Exploring** status. They become real decisions only when the gating sequence in §A completes successfully and this PDR is promoted to Accepted via a Critic-mode strategist pass.

### A. Sequencing — Notify Cloud first, then Audit Phase-1, then re-evaluate

This PDR does not unblock work. The sequencing is load-bearing.

```
PDR-0002 (Notify Cloud) ships → Notify Cloud public launch (target 2026-09-15)
  → first-revenue signal in the .NET-shop buyer segment
    → Audit Phase-1 (ADR-0031) lands fully — IAuditLog, IAuditQuery, AuditEntry,
       Data-backed append-only store, Auth wired as first emitter, Operator
       reconciled
      → Audit Node hits a v1.0 release (signal: GA, not Seed)
        → product-strategist invoked in Critic mode against the state of the
           world at that point
          → only then: this PDR is considered for promotion to Accepted
            → only then: any build work starts on a commercial wrapper
```

**Each gate is a hard prerequisite, not a soft preference.** If Notify Cloud sunsets at its 90-day decision point (per PDR-0002 §K), this PDR almost certainly collapses with it — the .NET-shop sales motion will not have validated, and opening a second front against an unproven motion is a worse bet, not a better one.

Conversely, if Notify Cloud extends past day 90 with paying customers, the .NET-shop motion is validated; the question becomes "is the substrate cluster ready," which is the second gate.

### B. The product wedge — cost hook, audit retention

The smallest viable wedge, recorded for future reference:

**`HoneyDrunk.Audit.Cloud` ingest endpoint + MCP-middleware-shaped adapter.** The adapter is `Microsoft.AgentGovernance.Extensions.ModelContextProtocol`-compatible — it sits inside the buyer's MCP runtime and ships every tool call as an `AuditEntry` over a signed REST surface. Bring-your-own MCP servers. Free tier at <100K events/mo.

The cost-tracking hook (the same surface Helicone wins on) is **present but disclaimed as the product.** Every `AuditEntry` carries the cost dimensions the `ICostLedger` already produces; that data renders into a "your AI bill by workflow" view; the view is the hook. The *retention* surface — query depth, replay window, permission-correlation, per-tenant Vault scoping — is the product.

This is the same "cost is the hook, audit is the product" split that distinguishes a record substrate from a telemetry pipeline (invariant 47). It is the wedge that pure observability vendors cannot build retroactively, because their storage shape is wrong.

**~8 solo-dev weeks after Audit Phase-1 ships** is the strategist's build estimate. That estimate is recorded as-is; it has not been validated against the actual substrate shape and will be re-derived at promotion time.

### C. Substrate reuse, not a new Node — provisional

**Default position: hosted surface over the existing `HoneyDrunk.Audit` Node + existing `IModelRouter` + Capabilities + Vault. No new Grid Node.**

This matches manifesto belief #7 (small surface, strong contracts — reuse the substrate, do not duplicate it) and the PDR-0002 pattern (Notify Cloud is a new repo, but it is a wrapper Node, not a new substrate Node — the substrate stays in Notify and Communications).

The commercial wrapper, if built, lives in a **new repo** — provisionally `HoneyDrunk.Audit.Cloud` — in the **Ops** sector (parallels Notify Cloud's positioning). It consumes the Audit Node's existing contracts (`IAuditLog`, `IAuditQuery`, `AuditEntry`), the AI Node's `IModelRouter` / `ICostLedger`, Capabilities's permission surface, and Vault's per-tenant scoping. It adds:

- An ingest API (REST + the MCP-middleware adapter) that translates inbound MCP tool calls into `AuditEntry` envelopes.
- Multi-tenant primitives (per PDR-0002 §F — `TenantId` propagation, per-tenant API keys, per-tenant rate limits, per-tenant Vault scoping, billing events). These are Grid-wide primitives (per ADR-0026 / PDR-0002 §F), not Audit-Cloud-specific. Audit Cloud is the *second consumer* of those primitives if it ships; Notify Cloud is the first.
- A query / replay surface (web app + REST) over `IAuditQuery`.
- Stripe-based metered billing on event volume + retention tier.

**This default is provisional.** If the substrate work surfaces a concrete reason to introduce a new Audit Cloud-specific abstraction at the Grid level (e.g., a different append shape than `IAuditLog` exposes), the Critic-mode strategist pass re-opens the question. The default is "no new Node" because invariant 47 already makes Audit the substrate; adding a parallel substrate would be the boundary violation invariant 47 was written to prevent.

### D. MCP positioning — middleware path, not a marketplace

**Ship an MCP-middleware-shaped ingest adapter alongside the SDK.** The Microsoft `AgentGovernance.Extensions.ModelContextProtocol` package (shipped 2026-05-22, signal b above) is the dominant 2027 agent-runtime composition seam for .NET. Routing through that seam means the buyer's existing MCP-runtime composition picks up the Grid's audit surface *without code changes* — the same install motion Notify Cloud uses on the notification side.

**Explicit non-position: not an MCP server marketplace.** That space is Docker's, Anthropic's, and Microsoft's turf, with deeper distribution and platform incentives than a solo-dev studio can match. The MCP angle is *routing-and-record*, not *hosting-and-discovery*. The product is what happens to the audit trail of the tools, not the tools themselves.

### E. Pricing wedge — event volume + retention tier, not seats

**Default position recorded, not committed:**

- **Free tier at <100K events/mo.** Install motion. Buyer can wire MCP middleware in 30 seconds, watch their first hour of agent calls render into the query surface, decide whether to expense it.
- **Metered tiers above 100K events/mo, with retention as the second axis.** 30-day retention at the cheap tier; 90-day, 1-year, 7-year retention as the upsell. Retention is where Audit's append-only substrate is the moat — pure observability vendors structurally cannot price 7-year retention competitively because their storage shape is wrong.
- **Not competing on seat pricing.** Helicone and Langfuse already win there. The Grid's substrate is event-shaped (one `AuditEntry` per tool call), and the cost shape that makes the Grid competitive is per-event-with-retention, not per-seat-with-collaboration-features.

**Per-tenant BYO model-provider keys (parallels PDR-0002 §F).** Higher-tier tenants bring their own OpenAI / Anthropic / Azure OpenAI keys through `TenantScopedSecretResolver` (invariant 9a); cost-attribution renders against the tenant's own billing relationship with the provider, not against a Grid-managed pool.

### F. Boundary disclaimer — cost-as-hook, not cost-as-product

**The Grid does not compete with Helicone, Langfuse, or OpenLLMetry on cost-only AI observability.** That category is settled and the Grid is structurally behind on engineering hours and language coverage there.

The boundary, restated as an invariant candidate for the Critic-mode pass:

- **Cost is the hook.** A renderable "your AI bill by workflow" surface is a v1 product feature. It is what the buyer expenses against. It is not the product.
- **The product is the audit substrate's properties — append-only, immutable, per-tenant attributable, permission-correlated, replay-capable, retention-shaped.** These are properties Helicone / Langfuse / OpenLLMetry structurally cannot retrofit, because their storage substrate is telemetry-shaped (sampled, time-bounded, optimized for aggregate signal — exactly the substrate invariant 47 prohibits Audit from being).
- **The competitive proof is invariant 47.** The Grid has a build-time check (the contract-shape canary in invariant 49) that prevents the substrate from drifting toward telemetry. No competitor has that gate. They cannot get it without re-platforming.

This boundary is the entire reason this PDR exists as a separable thought from the cost-observability market. If the boundary blurs — if Audit Cloud ends up reading like a cost-tracking tool with retention features — the wedge is dead. Critic-mode strategist pass enforces this at promotion time.

### G. Kill criteria — hard, dated, falsifiable

The strategist's framing was kill-criteria-forward. Recorded:

- **If Notify Cloud sunsets at its 90-day decision point (PDR-0002 §K), this PDR almost certainly collapses with it.** The .NET-shop sales motion will not have validated. Re-opening Audit Cloud against an unvalidated motion is a worse bet, not a better one. A small carve-out: if Notify Cloud sunsets specifically because the *notification* category is wrong (not because the .NET-shop *buyer segment* is wrong), the gate may still hold. The Critic-mode pass evaluates which one was the cause.
- **If Audit Phase-1 (ADR-0031) does not land within 9 months of this PDR's date** (i.e., by 2027-02-27), this PDR collapses. The market window the strategist named (signals a / b / c above) is dated to 2026–2027. Missing it materially weakens the wedge.
- **At any point post-promotion: if no buyer pays >$30/mo within 6 months of public launch, kill.** Mirrors PDR-0002 §K. The retention-tier upsell needs price elasticity above the $30/mo line; if no buyer crosses it, the wedge is hollow.
- **At any point post-promotion: if no design partner sticks past month 3, kill.** A design partner who churns at month 3 is signal that the product is not solving the compliance ask buyers were procuring against. No design partner past month 3 = the buyer profile in §2 above did not materialize.
- **At any point: if the cost-vs-audit boundary in §F blurs — if the product reads as cost-tracking with retention rather than record-substrate with cost-attribution — kill the commercial wrapper, keep the substrate.** The substrate has internal Grid value (invariant 47) independent of the commercial wrapper. The wrapper has no value without the boundary.

The kill criteria are recorded here as load-bearing. They become enforceable only after this PDR is promoted to Accepted; until then, they are the bar the Critic-mode pass tests against.

### H. Pre-1.0 carve-out — exploratory only

The Grid is pre-1.0. Core Nodes (Kernel, Vault, Auth, Data, Web.Rest, Transport) have shipped Live, but Audit is at Seed signal. Opening a second commercial surface while Core Nodes are still pre-1.0 is the failure mode this PDR is most concerned about — it splits attention, splits sales motion, and produces commercial commitments against unstable substrate.

**Hard rule: this PDR's commercial direction does not authorize build work until both gates pass — Notify Cloud launches AND the Audit Node hits a v1.0 release.** Substrate work on Audit, `IModelRouter`, `ICostLedger`, and Capabilities continues on its existing internal-Grid timeline; this PDR does not change that timeline or accelerate it. The substrate is being built for the Grid's internal needs first; the commercial possibility is a side-effect, not a driver.

This carve-out is the answer to the manifesto belief #7 concern: do not introduce a small surface (a hosted commercial product) on top of substrate that is itself still finding its small surface.

---

## Options Evaluated

### Option 1: Do nothing — never write this PDR

**Description:** The Grid builds the Audit Node, `IModelRouter`, `ICostLedger`, and Capabilities for its own internal use. No record is made of the eventual commercial-wrapper possibility.

**Pros:**
- Maximum focus on Notify Cloud as the only commercial product.
- Substrate is built purely for internal needs; no risk of premature commercial-shape contamination.

**Cons:**
- Loses the cheap option-value of recording the eventual external shape now. Substrate decisions get made without the external-shape constraint in view; some may foreclose options the studio later regrets.
- Forfeits the documented market window. If signals a / b / c (OTel GenAI semconv, MCP governance, supply-chain incidents) hold, the strategist's 2027 thesis is materially harder to validate in 2027 than in 2026.
- Treats "should we ever build this" and "should we build this now" as the same question. They are not. This PDR is the first; PDR-0002 §K's evaluation produces the input to the second.

**Verdict:** Rejected. The strategist's Scout pass surfaced this as the top 2-to-3-year opportunity. Refusing to record the thinking — and the dependency chain to its eventual evaluation — would lose option-value cheaply. The PDR itself does not authorize build; it captures the substrate-cluster bet so the bet can be evaluated at the right time.

### Option 2: Open the second commercial front now, in parallel with Notify Cloud

**Description:** Begin building `HoneyDrunk.Audit.Cloud` in parallel with Notify Cloud, on the bet that the market window (signals a / b / c) is narrower than the strategist's 2027 horizon and the Grid needs to be in market in 2026.

**Pros:**
- Captures the market window aggressively.
- Validates two sales motions simultaneously (notifications, audit) in the same .NET-shop segment.

**Cons:**
- Splits solo-dev focus across two pre-launch products and one pre-1.0 substrate cluster. PDR-0002's launch slips materially.
- Validates neither sales motion cleanly. If sign-up rates are weak across both, the diagnostic signal is muddied — was it the notification wedge, the audit wedge, the .NET-shop segment, or the studio's marketing reach?
- Builds the commercial wrapper against pre-1.0 Audit substrate. Substrate breaks force commercial-wrapper breaks; commercial wrapper SLOs constrain substrate evolution. Exactly the boundary violation invariant 47 was built to prevent (Audit must be free to evolve as a substrate; coupling it to a commercial SLO before v1.0 is premature).
- Indistinguishable from premature platform sprawl, which is the explicit lesson PDR-0002 §H draws from PDR-0001's HoneyHub reframing.

**Verdict:** Rejected. The market window is real, but the cost of opening two fronts is higher than the cost of missing one quarter of the window. Sequenced builds let the studio validate one motion cleanly before opening the next.

### Option 3: Build the substrate, but skip the commercial wrapper entirely

**Description:** Build Audit, `IModelRouter`, `ICostLedger`, and Capabilities for the Grid's own internal needs. Never wrap them as a commercial product. Treat the strategist's wedge as a "nice substrate property" rather than a commercial opportunity.

**Pros:**
- Maximum focus on internal Grid value.
- No risk of commercial-shape contamination of substrate decisions.
- Simpler studio story: "we make a notifications product (Notify Cloud); we have great internal audit; that's it."

**Cons:**
- Forfeits the documented commercial opportunity with no fallback. If Notify Cloud's 90-day decision point produces "drop to maintenance" rather than "extend," the Grid has burned 4 months proving the .NET-shop motion works on notifications and has no second product to validate the segment with.
- The strategist's thesis is that the join between Audit + AI-router + Capabilities is structurally hard for competitors to build retroactively. Walking away from that moat is leaving option-value on the table.
- The substrate exists either way (internal need). The marginal cost of recording the eventual commercial shape now is one PDR; the marginal cost of *not* recording it is being unable to evaluate the bet when Notify Cloud's signal lands.

**Verdict:** Rejected as a now-decision. Recorded as the **fallback** if the Critic-mode pass at promotion time rejects the commercial wrapper. The substrate has standalone internal value regardless of the commercial decision.

### Option 4: Build a new dedicated Node (`HoneyDrunk.Audit.Cloud` as a Grid Node, not a wrapper repo)

**Description:** Instead of a hosted surface over the existing Audit Node, introduce `HoneyDrunk.Audit.Cloud` as a peer Node in the Grid topology, with its own contracts and own substrate.

**Pros:**
- Cleaner separation between "internal Grid audit" and "external audit-as-a-service."
- Avoids any concern about commercial-shape contamination of the internal Audit Node.

**Cons:**
- Directly violates manifesto belief #7 (small surface, strong contracts — reuse, do not duplicate). The Audit Node already *is* the substrate; standing up a second one is the failure mode.
- Doubles the maintenance surface for substrate work. Every Audit invariant (47, 48, 49) would need a parallel statement for Audit Cloud, and the two would inevitably drift.
- Mirrors PDR-0002's explicit pattern: Notify Cloud is a wrapper repo over the Notify Node, not a parallel Notify Node. Inconsistency would be a credible signal to architecture reviewers that the studio does not actually believe its own pattern.

**Verdict:** Rejected as the default. The Critic-mode pass at promotion time may re-open the question if substrate work surfaces a concrete reason — but the default is single-substrate.

### Option 5: Record the bet now, sequence behind Notify Cloud + Audit Phase-1, re-evaluate via Critic-mode pass (Selected, Provisional)

**Description:** This PDR. Capture the substrate-cluster bet at Proposed / Exploring status. Sequence the commercial decision behind PDR-0002 launch and Audit Phase-1 landing. Re-invoke the strategist in Critic mode at the gating point. Promote to Accepted only if the Critic pass clears the wedge.

**Pros:**
- Preserves option-value cheaply (one PDR, no build cost).
- Lets substrate decisions stay internally-driven, with the eventual external shape visible as a check rather than a driver.
- Sequencing is honest about the studio's capacity — one commercial front at a time, validate one sales motion cleanly before opening the next.
- Kill criteria are dated and falsifiable (§G), not aspirational.
- Aligns with manifesto belief #7 (small surface — record the thinking, not the scaffolding) and PDR-0002's wrapper-repo pattern.

**Cons:**
- "Proposed / Exploring" status is unusual for a PDR. Most PDRs commit to a direction; this one explicitly defers.
- Recording the thinking creates a temptation to start building. The §H carve-out and §G kill criteria push against this, but the temptation is real.
- The market window may close before the gating sequence completes. Accepted as a known cost.

**Verdict:** Selected. The PDR captures the thinking and the gating discipline; it does not authorize build. If the market window closes, the studio loses the opportunity but does not lose the substrate work (which was for internal use anyway). If Notify Cloud succeeds and Audit Phase-1 lands cleanly, the studio has a recorded, evaluated wedge ready for promotion.

---

## Trade-offs

| Trade-off | Favored Position | Rationale |
|---|---|---|
| Record the thinking now vs. wait until Notify Cloud signal lands | **Record now** | Option-value is cheap (one PDR). Recording forces substrate decisions to be made with the eventual external shape visible — not as a driver, but as a check. Waiting risks foreclosing options inside the substrate work. |
| Open second commercial front now vs. sequence behind Notify Cloud | **Sequence** | Splitting solo-dev focus loses both sales motions. One clean signal beats two muddied ones. |
| Pre-1.0 commercial build vs. post-1.0 commercial build | **Post-1.0** | Commercial SLOs constrain substrate evolution. Coupling the commercial wrapper to pre-1.0 Audit is the boundary failure invariant 47 was written to prevent. Wait for Audit to GA. |
| New Audit Cloud Node vs. wrapper repo over existing Audit Node | **Wrapper repo** | Manifesto belief #7. The Audit Node *is* the substrate; standing up a parallel Audit substrate is the failure mode, not the design. |
| Compete on cost-as-product vs. cost-as-hook with audit-as-product | **Cost-as-hook** | Helicone / Langfuse / OpenLLMetry already own cost-as-product. The Grid's edge is the substrate join (invariant 47, append-only, per-tenant attributable, permission-correlated). Cost is the budget line buyers expense against; the record substrate is what they pay for. |
| Seat pricing vs. event volume + retention tier pricing | **Event volume + retention** | Audit's append-only substrate is the moat. Pure observability vendors structurally cannot price 7-year retention competitively. Pricing on the moat amplifies the moat; pricing on seats puts the Grid on Helicone's home turf. |
| MCP middleware adapter vs. MCP server marketplace | **Middleware adapter** | The buyer's MCP runtime is the composition seam (Microsoft `AgentGovernance.Extensions.ModelContextProtocol`, signal b). Routing through that seam needs zero code changes. Becoming an MCP server *host* is Docker / Anthropic / Microsoft turf with deeper distribution and platform incentives than a solo-dev studio can match. |
| Hard kill criteria vs. soft evaluation thresholds | **Hard kill criteria** | PDR-0002 §K's hard rule (architectural invariant) is the pattern. Soft thresholds in a solo-dev shop produce indefinite extension. Hard, dated, falsifiable criteria force decisive action — extend, drop to maintenance, or sunset, per the PDR-0002 §K shape. |
| Promote on Scout-pass evidence vs. require Critic-mode pass | **Require Critic** | Scout is option-discovery; Critic is option-validation. Promotion to Accepted requires a Critic pass against the actual state of the world at gating time — not against today's projections. |

---

## Architecture Implications

The implications below are recorded as the **shape** the commercial wrapper would take, *if* this PDR is promoted at the gating sequence. Substrate work on Audit, AI, Capabilities, and Vault is unaffected by this PDR — that work is being done for internal Grid needs and continues on its existing timeline.

### Provisional new repo: `HoneyDrunk.Audit.Cloud` (Ops sector)

If the gating sequence clears and this PDR promotes:

- A new repo, parallel in shape to `HoneyDrunk.Notify.Cloud` (PDR-0002 §Architecture Implications).
- **No new Grid Node.** It is a commercial wrapper over the existing Audit Node — the same pattern PDR-0002 uses for Notify Cloud.
- It is the *second consumer* of the Grid multi-tenant primitives (ADR-0026, originally written for Notify Cloud). It does not introduce new tenant primitives; if it tries to, the Critic-mode pass should reject the wrapper as not-yet-ready.

### Provisional package families

- `HoneyDrunk.Audit.Cloud.Abstractions` — `IAuditCloudGateway`, `IAuditCloudApiKeyStore`, `EventVolumePolicy`, `RetentionTierPolicy`. Tenant primitives stay in Kernel (per PDR-0002 §F).
- `HoneyDrunk.Audit.Cloud` — runtime composition. Multi-tenant gateway, API key validation, rate limiter, retention-tier enforcement.
- `HoneyDrunk.Audit.Client` — idiomatic .NET SDK. The package buyers install. Parallels `HoneyDrunk.Notify.Client`.
- `HoneyDrunk.Audit.Cloud.Mcp` — MCP middleware adapter (`Microsoft.AgentGovernance.Extensions.ModelContextProtocol`-compatible). The install seam. Routes inbound MCP tool calls into `AuditEntry` envelopes against the gateway.
- `HoneyDrunk.Audit.Cloud.Billing.Stripe` — Stripe-specific billing adapter. Parallels `HoneyDrunk.Notify.Cloud.Billing.Stripe`.
- `HoneyDrunk.Audit.Cloud.Web` — multi-tenant management website (signup, billing, query / replay surface, retention-tier selection).

### Provisional dependencies

```
Audit Cloud
  ├─ consumes ──► Audit (IAuditLog, IAuditQuery, AuditEntry) — substrate
  ├─ consumes ──► AI (IModelRouter, ICostLedger) — cost-attribution hook
  ├─ consumes ──► Capabilities (permission-check surface for replay attribution)
  ├─ consumes ──► Auth (IApiKeyAuthenticator, per PDR-0002's Auth surface)
  ├─ consumes ──► Vault (per-tenant secrets — invariant 9a)
  ├─ consumes ──► Web.Rest (response envelopes, correlation)
  ├─ consumes ──► Kernel (IGridContext, lifecycle, telemetry)
  └─ emits telemetry ──► Pulse  (operational only; audit records are NOT telemetry, invariant 47)
```

The dependency graph is materially the same shape as Notify Cloud's (PDR-0002 §Architecture Implications), with substrate substitutions: Notify is replaced by Audit + AI + Capabilities; the rest of the wrapper layer is identical (multi-tenant primitives, billing, Web.Rest, Auth-API-key path).

### Substrate decisions the studio commits to verify *now*, against the eventual external shape

These are the checks substrate work must pass at internal-build time, recorded here so the work does not foreclose external-build later:

| Substrate decision | The check |
|---|---|
| `AuditEntry` shape | Carries enough dimensions to render a per-workflow, per-tenant, per-cost view without a follow-on join. PDR-0001 §B's `ICostLedger` output must be representable inside the `AuditEntry` envelope (as metadata or as a typed sub-field). |
| `IAuditQuery` shape | Supports per-tenant filtering at the contract level, not at the call site. (Invariant 47 already implies this; recording it as load-bearing for the external wedge.) |
| Audit retention model | The append-only store (ADR-0031 D4) must support 7-year retention at a cost shape that is economically defensible. If the Phase-1 Data-backed store cannot, that constraint surfaces *before* the Critic-mode pass, not at commercial-build time. |
| Capabilities permission-check trace | Capabilities's permission-check decisions must be representable in `AuditEntry` (probably as a category or as metadata on the `AuditEntry` for the corresponding tool call). The retention-tier wedge ("did the permission check fire correctly") is the entire reason this matters. |
| Vault per-tenant scoping | Already covered by invariant 9a. Verify that `TenantScopedSecretResolver` works for *external* tenants, not just internal ones. (PDR-0002's commercial work has the same need; this PDR inherits the answer.) |
| `IModelRouter` cost-rate sourcing | Already covered by invariant 45 (App Configuration). Verify that per-tenant rate overrides are representable, if BYO-key tenants need cost-attribution against their own provider relationships. |

These checks become **architecture-review items at internal-substrate PR time**, not deferred to commercial-build time. The studio commits to running them now so that the eventual commercial shape is not foreclosed.

---

## Product Implications

### Provisional tier shape

Recorded for the Critic-mode pass. Not committed.

| Stage | Tier | Buyer | Hook |
|---|---|---|---|
| Evaluation | Free | Eng lead exploring | 100K events/mo, 30-day retention, MCP middleware install in 30 seconds. Renders the "your AI bill by workflow" view immediately. |
| Activation | Starter | Eng lead at a 20-to-80-person .NET shop | Higher event volume, 90-day retention, query / replay surface. Removes any free-tier watermarks on rendered reports. |
| Expansion | Pro | Compliance-driven .NET shop | 1-year retention, BYO model-provider keys, decision-log integration with Capabilities permission traces, exportable audit packets. |
| Future | Enterprise | Regulated mid-market | 7-year retention, dedicated tenant Vault scoping, SOC2 (Phase 4+). |

Specific dollar prices are deferred to the promotion-time PDR (or amendment). They are not load-bearing at Proposed / Exploring status — they depend on cost-shape data from Audit Phase-1 that does not yet exist.

### Buyer profile alignment with Notify Cloud

The buyer profile (eng lead at a 20-to-80-person regulated .NET shop) is **adjacent to but materially different from** Notify Cloud's profile (indie .NET dev / small team, 2-to-5-devs). The overlap is "uses .NET, lives on NuGet, prefers Microsoft-shaped composition seams." The non-overlap is "compliance-driven procurement, longer sales cycles, larger ACV, different evaluation criteria."

This is recorded as a **risk and a benefit**. Risk: the .NET-shop signal Notify Cloud produces validates a slightly different buyer than Audit Cloud needs. Benefit: if Notify Cloud's signal lands cleanly, it has produced *brand presence* in the .NET-shop ecosystem that Audit Cloud inherits without paying for it twice.

The Critic-mode pass should explicitly evaluate whether the Notify Cloud signal is transferable, or whether Audit Cloud needs an independent buyer-validation pass.

### Build-in-public alignment

Same posture as PDR-0002. The substrate (Audit, AI, Capabilities, Vault) is open source; the commercial wrapper is private. The architecture is the marketing — the buyer can read `IAuditLog`'s shape, the `AuditEntry` envelope, the invariant 47 carve-out — and that transparency is the moat against generic "agent observability" products.

The license posture (FSL or BSL) is inherited from PDR-0002's resolution (per ADR-0027 D11 → ADR-0039: FSL on the substrate, two-year auto-conversion to Apache 2.0). Commercial wrapper stays private.

---

## What Does NOT Change

- **The Grid's manifesto and invariants.** No invariant is added, amended, or removed by this PDR. The Critic-mode pass at promotion time may propose new invariants (e.g., a cost-as-hook-not-product boundary); they are not introduced here.
- **The Audit Node's internal-Grid build trajectory.** ADR-0030 / ADR-0031 / invariant 47 / invariant 49 stand as written. Audit is built for the Grid's internal needs first; this PDR does not change that timeline or accelerate it.
- **The `HoneyDrunk.AI` Node's `IModelRouter` / `ICostLedger` work.** Already required by PDR-0001 §B and invariant 45. This PDR does not introduce new requirements; it commits to verifying the existing requirements are externally-shaped (the §Architecture Implications check table).
- **PDR-0002 (Notify Cloud).** This PDR is sequenced behind PDR-0002 and does not amend, reframe, or compete with it. Notify Cloud is the first commercial product. This PDR is *possibly* the second, not the replacement.
- **The solo-dev operating model.** Same as PDR-0002. No hiring commitment. No investor narrative.
- **HoneyHub.** This PDR has no opinion on HoneyHub's external vs. internal positioning. PDR-0001 / PDR-0009 own that question.

---

## Risks

| Risk | Severity | Description |
|---|---|---|
| **Market window closes before gating sequence completes** | High | Signals a / b / c (OTel GenAI semconv, MCP governance, supply-chain incidents) are dated to 2026–2027. If Notify Cloud slips, or Audit Phase-1 slips, or the Critic-mode pass takes too long, the wedge is materially weaker by the time it is promoted. Mitigation: §G's "9-month for Audit Phase-1" kill criterion. |
| **Notify Cloud's sales motion does not validate the .NET-shop segment** | High | If Notify Cloud sunsets at its 90-day decision point, the gate for this PDR almost certainly fails. The substrate work continues (internal value), but the commercial wrapper option is foreclosed. Mitigation: §G's tie to PDR-0002 §K. |
| **Substrate work makes choices that foreclose the external shape** | Medium-High | If the `AuditEntry` shape, `IAuditQuery` filtering, or retention store can't support the eventual external use, the wedge is dead at commercial-build time and the studio discovers it too late. Mitigation: the §Architecture Implications check table — verify *now*, not at promotion time. |
| **Cost-as-hook boundary blurs** | Medium-High | If the commercial wrapper ends up positioned as cost-tracking with retention features, Helicone / Langfuse / OpenLLMetry win. The wedge requires the boundary to hold. Mitigation: §F is a hard rule; the Critic-mode pass enforces it; §G's kill criterion fires if the boundary slips post-launch. |
| **Pre-1.0 commercial commitment compromises substrate evolution** | Medium-High | If the commercial wrapper ships before Audit Node hits v1.0, commercial SLOs constrain substrate decisions in ways invariant 47 was designed to prevent. Mitigation: §H's hard rule — no build until Audit v1.0. |
| **MCP runtime ecosystem fragments before 2027** | Medium | If MCP loses dominant-substrate status (Microsoft pivots, Anthropic forks, a new protocol gains adoption), the middleware-adapter wedge weakens. The `Audit.Client` SDK is still there, but the install motion gets harder. Mitigation: the SDK is the second path; MCP is the primary path. Both ship at v1. Critic-mode pass re-evaluates the protocol bet at promotion time. |
| **Buyer profile in §2 does not crystalize** | Medium | The 2027 compliance-ask narrative depends on procurement actually budgeting for "who-touched-what-with-what-token." If buyers continue to roll their own through 2027, the wedge is real but the willingness-to-pay is not. Mitigation: §G's design-partner kill criterion (no stick past month 3 = profile did not materialize). |
| **Two-front commercial sprawl** | Medium | Even with sequencing, the studio is committing to evaluating *two* commercial products over a 2-year horizon. If Notify Cloud succeeds modestly and Audit Cloud also succeeds modestly, the studio ends up with two products neither of which fully gets the attention required. Mitigation: §H's hard rule; the Critic-mode pass tests whether the studio has capacity for two products at promotion time. |
| **Competitor builds the same wedge first** | Low-Medium | Helicone / Langfuse / OpenLLMetry could theoretically re-platform onto an append-only substrate. None has shown signal of doing so (invariant 47 is structurally hard to retrofit), but it is not impossible. Mitigation: the Grid's edge is the *time* invariant 47 has already been live in the Audit Node by the gating point. A competitor starting in 2027 cannot catch up to a 2026 invariant. |
| **Compliance auditors do not accept "append-only-by-interface" as sufficient** | Medium | Phase-1 Audit is explicitly **not** tamper-evident (ADR-0030 D8, D9). The Phase-1 substrate is sufficient for internal use; whether it is sufficient for a 2027 *external* compliance ask depends on buyer-specific requirements. Mitigation: ADR-0030 D8a names the trigger (concrete compliance / customer / incident requirement) that promotes Phase-1 to Phase-2 tamper-evidence. The trigger lands when a real buyer demands it, not speculatively. |

---

## Mitigations

| Risk | Mitigation |
|---|---|
| Market window closes | §G's 9-month-for-Audit-Phase-1 kill criterion; the Critic-mode pass at promotion time tests window status against then-current signals. |
| Notify Cloud signal fails to validate | §G's tie to PDR-0002 §K. The PDR collapses cleanly back to a recorded direction not taken. The substrate continues for internal value. |
| Substrate forecloses external shape | The §Architecture Implications check table is run at internal-substrate PR time, not at commercial-build time. Architecture reviewers are explicitly authorized to flag PRs that fail the table even if internal needs are met. |
| Cost-as-hook boundary blurs | §F is a hard rule. The Critic-mode pass at promotion time tests positioning against this rule. §G's post-launch kill criterion fires if the boundary slips after launch. |
| Pre-1.0 commercial commitment | §H's hard rule. No build until Audit v1.0. Mechanical, not discretionary. |
| MCP fragmentation | Two install paths at v1 (MCP adapter + SDK). MCP is primary, SDK is secondary. Critic-mode pass re-evaluates which is primary at promotion time. |
| Buyer profile does not crystalize | §G's design-partner kill criterion. No stuck design partner past month 3 = collapse. |
| Two-front sprawl | §H's hard rule and the Critic-mode pass. If the studio is overloaded at promotion time, the pass should defer. Deferral is a valid outcome. |
| Competitor builds same wedge | Substrate work continues regardless. Invariant 47's time-in-place is the moat the competitor cannot retrofit. |
| Phase-1 audit not sufficient for compliance | ADR-0030 D8a's trigger model. Promote to Phase-2 tamper-evidence only when a real buyer demand fires the trigger. Do not speculate. |

---

## Consequences

### Short-term (next 6–12 months)

- **No new work is authorized by this PDR.** Substrate work on Audit, AI, Capabilities, and Vault continues on its existing internal-Grid trajectory.
- **The §Architecture Implications check table is added to architecture-review concerns** for substrate PRs on Audit, AI, Capabilities, and Vault. Failing the table is a flaggable concern, not a blocker, at internal-build time — but a substrate PR that *consciously* forecloses an external shape needs an explicit acknowledgment.
- **Notify Cloud (PDR-0002) ships and produces a first sales-motion signal.** That signal is the input to the first gate of this PDR.
- **Audit Phase-1 (ADR-0031) lands and stabilizes.** That landing is the input to the second gate.

### Medium-term (12–24 months)

- **Gating sequence either clears or it does not.** If both gates pass cleanly:
  - Strategist is invoked in Critic mode.
  - Critic pass either promotes this PDR to Accepted or returns it to "do not promote."
  - Promotion authorizes a Phase 2 PDR (or amendment) with specific pricing, specific tier definitions, specific repo / package / ADR follow-ups, and a launch timeline.
  - Promotion also authorizes ADR-level work: a standup ADR for `HoneyDrunk.Audit.Cloud`, an MCP-middleware-adapter contract ADR, a retention-tier ADR.
- **If either gate fails:**
  - This PDR collapses to "recorded direction not taken." No build authorized.
  - The substrate retains internal value (invariant 47 still applies).
  - The next commercial candidate is re-evaluated through a fresh Scout-mode pass — likely a different opportunity, not a retry of this one.

### Long-term (post-24 months)

- **If promoted and shipped:** the Grid has a second commercial surface. Two .NET-shop products. The studio's positioning shifts from "we make a notifications product" to "we make a portfolio of substrate-shaped products." The Grid is positioned for additional commercial candidates against the same substrate cluster (Communications, Knowledge, Memory) on the same wrapper pattern.
- **If not promoted:** the substrate cluster remains internal. The studio's positioning stays "notifications first; everything else is internal infrastructure." That is a valid outcome. The substrate work was not wasted; it earns its keep on internal value (invariant 47).

---

## Rollout — Phased Approach

This PDR is **non-actionable** at Proposed / Exploring status. The phases below describe the *evaluation* sequence, not a build sequence. No build phase is authorized by this PDR.

### Phase 0 — Recording (this PDR, 2026-05-27)

- This PDR is filed.
- The §Architecture Implications check table is communicated to architecture reviewers as a flaggable concern for substrate PRs.
- No code work.

### Phase 1 — Notify Cloud signal (through 2026-12-15, per PDR-0002 §K)

- Notify Cloud ships, soft-launches, public-launches.
- PDR-0002 §K's 90-day decision point fires.
- The outcome of PDR-0002 §K is the input to the first gate of this PDR.

### Phase 2 — Audit Phase-1 landing (parallel to Phase 1)

- ADR-0031's full scope (D1–D11) lands.
- Audit Node moves from Seed signal toward GA. Operationally: `IAuditLog`, `IAuditQuery`, `AuditEntry`, Data-backed append-only store, Auth as first emitter, Operator reconciled, contract-shape canary in place.
- Audit Node hits a v1.0 release.

### Phase 3 — Critic-mode strategist pass (post-Phase-2)

- Strategist invoked in Critic mode against the then-current state of: Notify Cloud signal, Audit Node maturity, MCP ecosystem health, the §F boundary disclaimer, the §G kill criteria.
- Critic pass produces one of three verdicts:
  - **Promote to Accepted.** This PDR becomes a commitment. A Phase 2 PDR (or amendment) is filed with specific build-authorization details.
  - **Do not promote, retain at Proposed.** The PDR continues to record the direction; the gating sequence is re-evaluated at a later point.
  - **Do not promote, supersede with a counter-PDR.** The Critic pass surfaces that the direction is wrong. A new PDR closes this one out and records the new direction.

### Phase 4 (conditional) — Build phase

- **Only if Phase 3 produces Promote.**
- Driven by a Phase 2 PDR or PDR amendment, not by this PDR.
- The build phase shape mirrors PDR-0002's Phase 1–5 — new repo standup ADR, Stripe integration ADR, soft launch, public launch, 90-day decision point.

---

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Specific dollar prices for Free / Starter / Pro / Enterprise tiers | Product (Phase 3) | Deferred to promotion-time PDR. Depends on cost-shape data from Audit Phase-1 that does not yet exist. |
| Whether the §G "Notify Cloud sunsets" gate has a buyer-segment carve-out | Product (Phase 1 → Phase 3) | Default position: if Notify Cloud sunsets specifically because the *notification* category was wrong (not because the *.NET-shop buyer segment* was wrong), the gate may still hold. The Critic-mode pass evaluates which one was the cause. |
| Whether Audit Phase-1's append-only-by-interface is sufficient for the eventual external compliance ask | Architecture (Phase 2) | ADR-0030 D9 is explicit that Phase-1 is **not** tamper-evident. The Critic-mode pass at Phase 3 must evaluate whether the buyer in §2 will accept this, or whether Phase-2 tamper-evidence (ADR-0030 D8a's trigger) needs to fire before commercial launch. |
| Whether the MCP middleware adapter remains the primary install path at promotion time | Product / Architecture (Phase 3) | Depends on MCP ecosystem health at Phase 3. Critic pass re-evaluates. SDK is the backup primary if MCP fragments. |
| Whether the brand sits under HoneyDrunk Studios (parallel to HoneyDrunk Notify) or as a separate brand | Product (Phase 3) | Default position: under HoneyDrunk Studios (PDR-0002 §H pattern). Revisited at promotion. |
| Whether the commercial wrapper repo is named `HoneyDrunk.Audit.Cloud` or some other form | Architecture (Phase 3) | Default position: `HoneyDrunk.Audit.Cloud`, parallel to `HoneyDrunk.Notify.Cloud`. Revisited at promotion. |
| Whether `Audit.Cloud` ships its own marketing site or sits under a section of `audit.honeydrunkstudios.com` | Product (Phase 3) | Default position: subdomain under HoneyDrunk Studios, parallel to PDR-0002 §H. Revisited at promotion. |
| Whether the Capabilities permission-check trace shape needs a contract change to surface in `AuditEntry` cleanly | Architecture (Phase 0 → Phase 3) | The §Architecture Implications check table flags this as a substrate-decision check. Resolved before Phase 3, not deferred. |
| Whether the cost-attribution dimensions in `AuditEntry` are sufficient for per-tenant BYO-key rendering | Architecture (Phase 0 → Phase 3) | The §Architecture Implications check table flags this. Resolved before Phase 3. |
| Whether a second-source signal (independent of the strategist) should fire before Critic-mode pass — e.g., 3+ inbound design-partner inquiries via the build-in-public surface | Product (Phase 3) | Open. The Critic-mode pass is one signal; a market-side pull signal would be a second. Default: not required. Reconsidered at promotion. |

---

## Recommended Follow-Up Artifacts

The artifacts below are **conditional on promotion**. They are recorded as the expected follow-up chain so the Critic-mode pass at Phase 3 has a concrete shape to evaluate. None of these is authorized by this PDR.

| Artifact | Type | Triggered by | Purpose |
|---|---|---|---|
| Phase 2 PDR (or amendment to PDR-0010) | PDR | Phase 3 Critic-mode "Promote" | Commits to specific pricing, specific tier feature gates, specific launch timeline. Carries the build-authorization. |
| `HoneyDrunk.Audit.Cloud` standup ADR | ADR | Phase 2 PDR | Stands up the new wrapper repo per the standup-ADR convention. Names package families, downstream coupling rule, contract-shape canary, dependency surface. Parallels [ADR-0027](../adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md). |
| MCP middleware adapter contract ADR | ADR | Phase 2 PDR | Defines the `HoneyDrunk.Audit.Cloud.Mcp` adapter shape, its `Microsoft.AgentGovernance.Extensions.ModelContextProtocol` integration boundary, and the `AuditEntry`-translation contract. |
| Retention-tier policy ADR | ADR | Phase 2 PDR | Defines `RetentionTierPolicy`, the per-tier query / replay window, and the cost-shape boundary between tiers. Likely interacts with ADR-0030 D8 (deferred tamper-evidence) if the 7-year tier triggers the Phase-2 substrate work. |
| Cost-attribution-in-AuditEntry design doc | Design doc | Phase 0 (substrate review concern) — landed before Phase 3 | Specifies how `ICostLedger` output renders into the `AuditEntry` envelope. The §Architecture Implications check table item that resolves *before* Critic-mode pass, not after. |
| Capabilities-permission-trace-in-AuditEntry design doc | Design doc | Phase 0 (substrate review concern) — landed before Phase 3 | Specifies how Capabilities's permission-check decisions render into `AuditEntry`. Same trigger and timing as above. |
| Audit Cloud retrospective PDR (conditional) | PDR | Phase 3 Critic-mode "Do not promote, supersede" | If the Critic pass determines the direction is wrong, the retrospective PDR documents the substrate-cluster bet that did not pay off and the lessons that inform the next commercial-candidate selection. |
| API key authentication pattern reuse | (existing) | Phase 2 PDR | Inherited from PDR-0002's API key ADR. No new artifact — verify the existing one fits Audit Cloud's needs. |
| Grid multi-tenant primitives reuse | (existing) | Phase 2 PDR | Inherited from [ADR-0026](../adrs/ADR-0026-grid-multi-tenant-primitives.md). Audit Cloud is the second consumer; no new primitives needed. If the substrate work surfaces a need for new primitives, that is itself a Critic-mode pass concern. |
| Stripe billing integration reuse | (existing) | Phase 2 PDR | Inherited from PDR-0002's Stripe ADR. Audit Cloud uses the same `BillingEvent` shape, same webhook bridge, same `Cloud.Billing.Stripe` provider-slot pattern — but metered on events + retention tier instead of notification events. |
| Open-source license decision reuse | (existing) | Phase 2 PDR | Inherited from [ADR-0039](../adrs/ADR-0039-grid-open-source-license-policy.md). Audit substrate is FSL (already covered); the commercial wrapper repo stays private. No new license decision. |
