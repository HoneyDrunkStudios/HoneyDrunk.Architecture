---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "docs", "ops", "adr-0028"]
dependencies: []
adrs: ["ADR-0028"]
accepts: ADR-0028
wave: 1
initiative: adr-0028-event-driven-architecture
node: honeydrunk-architecture
---

# Chore: Add D3 signals-vs-events disambiguation to Pulse boundaries

## Summary
Update `repos/HoneyDrunk.Pulse/boundaries.md` to add ADR-0028 D3's "Pulse signals are not domain events" disambiguation as an explicit subsection under "What Pulse Does NOT Own." Architecture-repo doc edit only; no code or other catalog touches.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0028's "If Accepted — Required Follow-Up Work" checklist line 3 says:

> Update `repos/HoneyDrunk.Pulse/boundaries.md` to add the "Pulse signals are not domain events" disambiguation introduced in D3

The Pulse boundary doc today already disclaims Transport under "What Pulse Does NOT Own" ("Message publishing for events belongs in Transport"). That sentence is correct but too short — it does not surface the conflation it is meant to head off. The Grid's most-conflated concept in messaging surfaces is "Pulse is a Transport consumer for free observability" — subscribe Pulse to a Transport topic, route domain events through it, get traces and metrics by side effect. The ADR's D3 explicitly rejects this and pins the rule: telemetry signals ride OpenTelemetry over OTLP; domain events ride Transport; the two channels are intentionally separate and stay separate. Pulse never receives domain events as a consumer.

The negative form is also instructive: do not put metrics on Service Bus topics. Do not put domain events through OTLP. Do not subscribe Pulse to Transport topics to "make it learn what happened." The boundary doc needs to say this in the same place a reader is looking when they ask "what does Pulse not own?" — under "What Pulse Does NOT Own."

This packet adds that disambiguation as a structured subsection so the rule is visible from one glance.

## Scope

Single-file edit. No other repo context files touched. No `catalogs/*.json` edits. No constitution edits. No code.

## Proposed Implementation

### Edits to `repos/HoneyDrunk.Pulse/boundaries.md`

The current file is:

```markdown
# HoneyDrunk.Pulse - Boundaries

## What Pulse Owns
- Sink interfaces (`ITraceSink`, `ILogSink`, `IMetricsSink`, `IAnalyticsSink`, `IErrorSink`)
- OpenTelemetry preconfigured pipelines with Grid context enrichment
- Multi-backend fan-out with per-sink failure isolation
- Pulse.Collector (OTLP HTTP + gRPC receiver) using Kernel canonical Pulse identity fallback
- Shared event contracts (`PulseIngested`, etc.)

## What Pulse Does NOT Own
- **Context model** - GridContext definition and canonical Node IDs belong in Kernel
- **Transport** - Message publishing for events belongs in Transport
- **Secret management** - Sink credentials come from Vault
```

Replace it with:

```markdown
# HoneyDrunk.Pulse - Boundaries

## What Pulse Owns
- Sink interfaces (`ITraceSink`, `ILogSink`, `IMetricsSink`, `IAnalyticsSink`, `IErrorSink`)
- OpenTelemetry preconfigured pipelines with Grid context enrichment
- Multi-backend fan-out with per-sink failure isolation
- Pulse.Collector (OTLP HTTP + gRPC receiver) using Kernel canonical Pulse identity fallback
- Shared event contracts (`PulseIngested`, etc.) — emitted by Pulse via Transport when a batch lands; not a substitute for telemetry

## What Pulse Does NOT Own
- **Context model** - GridContext definition and canonical Node IDs belong in Kernel
- **Transport** - Message publishing for events belongs in Transport
- **Secret management** - Sink credentials come from Vault

## Pulse Signals Are Not Domain Events

The single most-conflated concept in the Grid's messaging surfaces is "Pulse is a Transport consumer for free observability" — subscribe Pulse to a Transport topic, route domain events through it, get traces and metrics by side effect. This is the wrong shape, and the Grid's messaging architecture intentionally rejects it.

**Telemetry signals ride OpenTelemetry over OTLP.** Nodes emit traces, metrics, logs, errors, and analytics signals to the Pulse Collector via OTLP HTTP or gRPC. The Pulse Collector fans out to backends (Tempo, Loki, Mimir, Sentry, PostHog, Azure Monitor) with per-sink failure isolation. No Transport hop, no Service Bus topic, no Event Grid involvement. This is the existing pipeline and the only correct shape for telemetry.

**Domain events ride Transport.** `PulseIngested` is a domain event ("telemetry was ingested for batch X") that happens to be emitted by Pulse — it is *not* the telemetry itself. It rides Transport as a pub/sub event so downstream Grid Nodes can react to ingestion completion. Other domain events emitted by Pulse, if any are added later, ride the same Transport channel by the same rule.

**Pulse never receives domain events as a consumer.** Pulse observes; it does not subscribe. If a Node wants Pulse to see something, it emits a span / metric / log via the OpenTelemetry pipeline, not a Transport message. Subscribing Pulse to a Transport topic to "make it learn what happened" would couple observability to event schemas, put telemetry processing in the path of domain delivery, and blur the architectural seam between OTel-shaped signals and Transport-shaped events. None of those costs are paid by the existing design, and they will not be paid by this one.

The negative form, said directly:

- Do **not** put metrics on Service Bus topics.
- Do **not** put traces or logs on Service Bus queues.
- Do **not** put domain events through OTLP.
- Do **not** subscribe Pulse to Transport topics to "instrument what happened."
- Do **not** treat `PulseIngested` as a telemetry channel — it is a domain pub/sub event about ingestion completion, not the telemetry it announces.

Pulse instruments domain events from inside the Nodes that emit them, via the OpenTelemetry pipeline. The two channels — OTel for signals, Transport for events — are intentionally separate and stay separate.

## Decision Test

If the concern is **trace, metric, log, error, or analytics signal**, it belongs on the OpenTelemetry pipeline. Emit via OTLP HTTP/gRPC to the Pulse Collector. Pulse owns.

If the concern is **a durable, attributable record of "this business thing happened, with these consumers needing to react"**, it is a domain event. It rides Transport, not Pulse. The downstream consumers subscribe to the Transport topic; Pulse observes whatever traces and metrics those consumers emit while processing the event.

If both channels seem to apply ("I want a metric AND a domain event"), emit both — a metric via OTLP and a domain event via Transport. They do not collapse into one channel.
```

### `CHANGELOG.md` (Architecture repo)

Append to the existing in-progress `## [Unreleased]` section under `### Changed`:

- "Pulse boundaries: added the 'Pulse signals are not domain events' disambiguation per ADR-0028 D3. Telemetry rides OpenTelemetry to the Pulse Collector; domain events ride Transport; Pulse never receives domain events as a consumer. Negative-form rules and a decision test included."

## Affected Files
- `repos/HoneyDrunk.Pulse/boundaries.md` (rewrite — adds `## Pulse Signals Are Not Domain Events` and `## Decision Test` sections; one minor expansion of the existing `PulseIngested` bullet under "What Pulse Owns")
- `CHANGELOG.md` (Unreleased entry)

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No code changes anywhere; one markdown doc + CHANGELOG.
- [x] No `catalogs/*.json` edits. No `constitution/*.md` edits. No `adrs/*.md` edits. No other repo context files (Transport, Communications, Notify, etc.) edited.
- [x] The new disambiguation text mirrors ADR-0028 D3 directly. The ADR is the source of truth — any deviation is grounds to stop and flag rather than ship.
- [x] The existing three "Does NOT Own" bullets (Context model, Transport, Secret management) are preserved. The existing five "Owns" bullets are preserved with one minor expansion (the `PulseIngested` bullet extended to name it as "emitted by Pulse via Transport when a batch lands; not a substitute for telemetry").

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Pulse/boundaries.md` retains the existing "What Pulse Owns" section with all five existing bullets; the `PulseIngested` bullet is extended to clarify it is a Transport-emitted batch-completion event, not telemetry.
- [ ] The existing three "What Pulse Does NOT Own" bullets are preserved verbatim.
- [ ] A new `## Pulse Signals Are Not Domain Events` section is added after "What Pulse Does NOT Own" with the text from the Proposed Implementation section: an introductory framing paragraph, three principle paragraphs (telemetry rides OTel; domain events ride Transport; Pulse never receives domain events as a consumer), a negative-form bulleted list of five "Do not" rules, and a closing sentence about the two channels staying separate.
- [ ] A new `## Decision Test` section is added after the signals-vs-events section with the three-bullet test from the Proposed Implementation (signal → OTel; domain event → Transport; both → emit both, do not collapse).
- [ ] `CHANGELOG.md` Unreleased section has the changed-entry described above.
- [ ] No file other than `repos/HoneyDrunk.Pulse/boundaries.md` and `CHANGELOG.md` is edited.
- [ ] PR description references this packet (per the PR-to-packet linking invariant inlined below).
- [ ] PR description states explicitly: the new sections track ADR-0028 D3 — any drift from D3 is grounds to stop and flag rather than ship.

## Human Prerequisites
None. This packet is fully delegable; the agent edits one doc file and opens a PR.

## Referenced ADR Decisions

**ADR-0028 D3 (Pulse signals are not domain events):** Telemetry signals ride OpenTelemetry over the OTLP wire format. Nodes emit traces/metrics/logs to the Pulse Collector via HTTP or gRPC. The Pulse Collector fans out to backends (Tempo, Loki, Mimir, Sentry, PostHog, Azure Monitor). No Transport hop, no Service Bus topic, no Event Grid involvement. Domain events ride Transport. `PulseIngested` is a domain event ("telemetry was ingested for batch X") that happens to be emitted by Pulse — it is *not* the telemetry. Pulse never receives domain events as a consumer; Pulse observes, it does not subscribe.

**ADR-0028 D2 row 4 (telemetry use case):** Primary backing is direct OTLP via HTTP/gRPC, then Pulse Collector → backends. No broker between Node and Pulse Collector. The matrix's "Why this backing" cell: "Telemetry is **not a domain event**. It rides OpenTelemetry, not Transport."

**ADR-0028 §Alternatives — "Treat Pulse as a Transport consumer and route domain events through it for 'free observability'":** Rejected. "This is the conflation D3 names explicitly. Pulse is observability infrastructure; domain events are business state. Subscribing Pulse to Transport topics would (a) couple observability to event schema, (b) put telemetry processing in the path of domain delivery, (c) blur the architectural seam between OTel-shaped signals and Transport-shaped events." The new "Pulse Signals Are Not Domain Events" section in the boundary doc is the operational form of this rejection.

**ADR-0028 §"New invariants (proposed for `constitution/invariants.md`)":** The first proposed invariant is "Telemetry signals ride OpenTelemetry; domain events ride Transport. Pulse is not subscribed to Transport topics. Nodes do not emit metrics or traces over Transport. The two channels stay separate." This packet encodes the rule into the Pulse boundary doc (not the constitution — the constitution edit is a separate scope-agent acceptance-time concern out of scope for this initiative).

## Referenced Invariants

> **Invariant 12:** Semantic versioning with `CHANGELOG.md` and `README.md`. Every shipped change gets an entry in the repo-level changelog. — This packet ships a documentation surface change in the Architecture repo; CHANGELOG entry mandatory.

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR receives a degraded review.

## Dependencies
None. Wave 1 foundational packet; runs in parallel with packets 01 and 02.

## Labels
`chore`, `tier-1`, `docs`, `ops`, `adr-0028`

## Agent Handoff

**Objective:** Update `repos/HoneyDrunk.Pulse/boundaries.md` to add ADR-0028 D3's "Pulse signals are not domain events" disambiguation as an explicit `## Pulse Signals Are Not Domain Events` section, plus a `## Decision Test` section. The existing "Owns" and "Does NOT Own" content is preserved with one minor `PulseIngested` clarification.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close the most-conflated concept in the Grid's messaging surfaces ("Pulse is a Transport consumer for free observability") by stating the rule directly in the Pulse boundary doc and giving readers a quick decision test.
- Feature: ADR-0028 Event-Driven Architecture and Messaging, Wave 1.
- ADR: ADR-0028 (Proposed at edit time; auto-flipped to Accepted by hive-sync after all four packets in this initiative close).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**

- **Invariant 12:** Semantic versioning with `CHANGELOG.md` and `README.md`. Every shipped change gets an entry in the repo-level changelog. This packet ships a documentation surface change; CHANGELOG entry mandatory.

- **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files.

- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor.

- **Verbatim ADR alignment.** The new disambiguation text tracks ADR-0028 D3 directly. The agent does not paraphrase the rule into something looser or stricter; the text in the Proposed Implementation section above is the canonical wording. If the agent reads the live ADR and finds it has been amended after this packet was authored, the agent follows the ADR's live text and notes the divergence in the PR body.

- **Preserve existing bullets.** The five existing "Owns" bullets and three existing "Does NOT Own" bullets are not removed or reworded. The one expansion permitted is the `PulseIngested` bullet, extended to name it as a Transport-emitted batch-completion event so the new section's reference to it lands cleanly.

- **No code.** No `.cs`, `.csproj`, `.json` (other than the existing CHANGELOG which is markdown), or YAML touched.

- **No other context files.** Transport boundaries, Communications boundaries, Notify boundaries — all out of scope for this packet; they are separate packets in this initiative (Transport, packet 02) or out of scope.

- **No initiative or roadmap or constitution edits.** Per the initiative-level direction, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `adrs/README.md`, `catalogs/*.json`, and `constitution/invariants.md` are all out of scope for this initiative.

**Key Files:**
- `repos/HoneyDrunk.Pulse/boundaries.md` — full rewrite per the Proposed Implementation section
- `CHANGELOG.md` — Unreleased section append

**Contracts:** None changed. This is a boundary doc edit; no interface or type surface is touched.
