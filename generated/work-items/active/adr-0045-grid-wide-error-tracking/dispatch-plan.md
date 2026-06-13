# Dispatch Plan — ADR-0045: Grid-Wide Error Tracking

**Initiative:** `adr-0045-grid-wide-error-tracking`
**ADR:** ADR-0045 (Proposed → Accepted via packet 00)
**Sector:** Ops / cross-cutting
**Created:** 2026-05-22

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

> **Amendment — 2026-05-22.** This dispatch plan and its packets were corrected: the error path targets **`HoneyDrunk.Pulse`**, not `HoneyDrunk.Observe`. Observe's `boundaries.md` states outbound telemetry to external sinks belongs to Pulse; Pulse (v0.3.0, LIVE) already owns `IErrorSink` and the `HoneyDrunk.Telemetry.Sink.*` provider family. ADR-0045 was amended to match (the same correction applied to companion ADR-0040). Packets 02/03 retargeted Observe → Pulse; the `IErrorReporter`/`IErrorSink` reconciliation, the invariant-80 numbering, the contracts.json catalog placement, the config-only Notify migration, and the shared-scrubber consumption were all corrected.

## Summary

ADR-0045 makes **errors** a fourth Grid signal type alongside the traces/metrics/logs of ADR-0040, and selects **Application Insights' Failures + exception tracking** as the v1 backend (revised in PR #164 to pivot off the original Sentry-Grid-wide framing; Sentry becomes the documented D11 escalation path). Errors flow through `HoneyDrunk.Pulse` via a new `IErrorReporter` **facade** — layered over Pulse's existing `IErrorSink` — whose App Insights backing uses the App Insights .NET SDK directly, a deliberate carve-out from ADR-0040's OTLP path because the App Insights error model carries non-OTLP fields (`problem_id`, `application_Version`, Failures-blade grouping dimensions).

This initiative delivers: the `IErrorReporter` facade + error-model types in `HoneyDrunk.Telemetry.Abstractions`, the App-Insights-SDK error-capture backing + error PII processor extended into the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor`, the Actions deploy-workflow release-annotation step, the config-only `HoneyDrunk.Notify` migration off its Sentry account, the `IErrorReporter` contract registration in `catalogs/contracts.json`, the error-flow invariant (number 80), the D8 review-rubric mapping, the D11 escalation-trigger operator doc, and the Phase 2/3 deployable-Node wiring playbook.

**8 packets across 4 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Pulse`, `HoneyDrunk.Actions`, `HoneyDrunk.Notify`). 8 `Actor=Agent`, 0 `Actor=Human`. (No `human-only` packet — but several packets carry Human Prerequisites: the Sentry-account archival, and the cross-initiative dependency on ADR-0040's Azure provisioning.)

## Trigger

ADR-0045 is Proposed with no scope. Forcing functions (from the ADR's Context): ADR-0040 just landed claiming unified observability, and the error gap makes the claim partially false; the AI-sector standup wave (ADR-0016–0025) is about to emit error volume that needs problem-grouping triage; Notify Cloud GA carries an implicit "we know when errors happen" expectation; and the existing ungoverned Notify-Sentry one-off needs governance.

## Scope Detection

**Multi-repo.** ADR-0045 touches `HoneyDrunk.Pulse` (the new `IErrorReporter` facade + the App Insights error backing extending `HoneyDrunk.Telemetry.Sink.AzureMonitor`), `HoneyDrunk.Actions` (the deploy-workflow release-annotation step), `HoneyDrunk.Notify` (the config-only Sentry→`IErrorReporter` migration), and `HoneyDrunk.Architecture` (acceptance, the `contracts.json` registration, the error-flow invariant, the review-rubric mapping, the escalation doc, the wiring playbook). The new `IErrorReporter` facade is consumed by every deployable Node — but the per-Node wiring is mechanically identical and deliberately deferred to a playbook (packet 07) rather than fanned out into premature per-Node packets.

## Wave Diagram

### Wave 1 (governance + catalog — depends only on the cross-initiative ADR-0040 acceptance)
- [ ] **00** — Architecture: Accept ADR-0045, add the error-flow invariant (number 80), register the initiative. `Actor=Agent`. Blocked by: ADR-0040 packet 00 (cross-initiative).
- [ ] **01** — Architecture: register the `IErrorReporter` facade in `catalogs/contracts.json` under the Pulse Node and record the D8 policy. `Actor=Agent`. Blocked by: 00.

### Wave 2 (the error-reporting facade)
- [ ] **02** — Pulse: add the `IErrorReporter` facade + `ErrorContext`/`ErrorScope`/`Breadcrumb`/`ErrorLevel` to `HoneyDrunk.Telemetry.Abstractions`. `Actor=Agent`. Blocked by: 00, ADR-0040 packet 03 (cross-initiative — Pulse-solution version-bump sequencing).

### Wave 3 (the App Insights backing + the deploy-flow change — parallel)
- [ ] **03** — Pulse: implement the App-Insights-SDK error backing + the error PII `ITelemetryProcessor` in `HoneyDrunk.Telemetry.Sink.AzureMonitor`. `Actor=Agent`. Blocked by: 02, ADR-0040 packet 05 (cross-initiative — consumes the shared PII scrubber).
- [ ] **04** — Actions: amend the reusable deploy workflows with the App Insights release-annotation step. `Actor=Agent`. Blocked by: 00. (Independent of the Pulse packets — parallel with 03.)

### Wave 4 (the Notify migration + the governance/rollout docs — parallel)
- [ ] **05** — Notify: migrate `HoneyDrunk.Notify` off its config-only Sentry account onto `IErrorReporter`. `Actor=Agent`. Blocked by: 03.
- [ ] **06** — Architecture: add the D8 mapping to `review.md` and document the D11 escalation triggers. `Actor=Agent`. Blocked by: 00. (Independent of 02–05 — parallel.)
- [ ] **07** — Architecture: author the deployable-Node error-wiring playbook for Phase 2/3 rollout. `Actor=Agent`. Blocked by: 00. (Independent of 02–05 — parallel.)

Packets within a wave run in parallel. Note Wave 4 is not strictly gated as a wave — only packet 05 depends on a Wave 3 packet; packets 06 and 07 depend only on packet 00 and could run as early as Wave 2. They are grouped into Wave 4 for tidy filing, but the `dependencies:` frontmatter is the real ordering signal — 06 and 07 will unblock as soon as 00 lands.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0045](./00-architecture-adr-0045-acceptance.md) | Architecture | Agent | 1 | ADR-0040 #00 (X-init) |
| 01 | [IErrorReporter contract + D8 policy catalog](./01-architecture-error-tracking-catalog-and-contracts.md) | Architecture | Agent | 1 | 00 |
| 02 | [IErrorReporter facade](./02-pulse-ierror-reporter-abstraction.md) | Pulse | Agent | 2 | 00, ADR-0040 #03 (X-init) |
| 03 | [App Insights error backing + PII processor](./03-pulse-app-insights-error-backing.md) | Pulse | Agent | 3 | 02, ADR-0040 #05 (X-init) |
| 04 | [Actions release-annotation step](./04-actions-app-insights-release-annotation.md) | Actions | Agent | 3 | 00 |
| 05 | [Notify Sentry→IErrorReporter migration](./05-notify-migrate-sentry-to-ierror-reporter.md) | Notify | Agent | 4 | 03 |
| 06 | [review.md D8 mapping + D11 escalation doc](./06-architecture-review-d8-mapping-and-escalation-doc.md) | Architecture | Agent | 4 | 00 |
| 07 | [Deployable-Node error-wiring playbook](./07-architecture-deployable-node-error-wiring-playbook.md) | Architecture | Agent | 4 | 00 |

## Cross-Initiative Dependency Wiring — ADR-0040

ADR-0045 is built on the same Azure Monitor backend as ADR-0040 (`adr-0040-telemetry-backend-and-retention`), pivoted in the same PR (#164). The two initiatives share infrastructure. **The filing pipeline does not resolve `work-item:NN` references across initiative folders** — a `work-item:NN` edge only resolves within the same folder. So every ADR-0045→ADR-0040 dependency is expressed as a qualified `{Repo}#N` issue edge, *or* — where it is a human/portal prerequisite rather than a packet ordering — as a Human Prerequisites note. The wiring:

| ADR-0045 packet | Depends on (ADR-0040) | Form | Why |
|---|---|---|---|
| 00 (acceptance) | ADR-0040 packet 00 (acceptance) | `dependencies:` edge — `Architecture#<n>` | Sibling observability ADR; the edge exists for invariant-numbering hygiene within the 12-ADR batch. ADR-0045 packet 00 appends invariant **80** (pre-reserved). |
| 02 (`IErrorReporter` facade) | ADR-0040 packet 03 (Pulse telemetry work) | `dependencies:` edge — `Architecture#<n>` | ADR-0040's Pulse work bumps the `HoneyDrunk.Pulse` solution version (invariant 27). ADR-0045's Pulse work sequences after ADR-0040's Pulse waves so version-bump ownership is unambiguous. |
| 03 (App Insights error backing) | ADR-0040 packet 05 (PII processors) | `dependencies:` edge — `Architecture#<n>` | ADR-0040 packet 05 builds the PII scrubber as a shared, mechanism-agnostic component from the start; ADR-0045 packet 03 **consumes** it (a plain hard dependency — no refactor needed). |
| 03, 05 (App Insights resource) | ADR-0040 packet 02 (App Insights provisioning) | **Human Prerequisites note**, not an edge | ADR-0045 D2 captures errors into the *same* App Insights resource ADR-0040 provisions — **ADR-0045 provisions no new resource**. The dependency is on a provisioned Azure resource, a human/portal artifact — recorded as a Human Prerequisite, not a `dependencies:` edge. |

**Action before this folder is pushed to `main`:** the `dependencies:` arrays of packets 00, 02, and 03 currently carry the placeholders `Architecture#ADR0040-PACKET00`, `Architecture#ADR0040-PACKET03`, `Architecture#ADR0040-PACKET05`. These must be replaced with the real `Architecture#<issue-number>` once ADR-0040's packets are filed and their GitHub issue numbers are known. A placeholder left in place will produce a `::warning::` and an unwired edge. The safe sequence: file the ADR-0040 folder first, read the issue numbers off The Hive, substitute them here, then push this folder.

**Co-landing recommendation:** land ADR-0040 fully — at minimum Waves 1–3 (packets 00, 02, 03, 05) — before ADR-0045's Pulse packets (02, 03). ADR-0045 packets 00, 01, 04, 06, 07 have no hard ADR-0040 code dependency and can land earlier (00 still wants ADR-0040 #00 first for invariant numbering).

## PII Processor — `ITelemetryProcessor` is correct; the scrubber is shared

ADR-0040 D9 is OTel-native (`SpanProcessor`/`LogRecordProcessor`). ADR-0045 D7 names `ITelemetryProcessor`. **This is not a contradiction once the mechanism is understood:**

- ADR-0045 D3 routes errors through the **App Insights .NET SDK directly** (the carve-out — the error model needs non-OTLP fields). The App Insights SDK's *only* filter hook is `ITelemetryProcessor`; OTel `SpanProcessor`s do not sit in the SDK's pipeline. So the error path **must** use `ITelemetryProcessor` — the correct and only mechanism for SDK-captured exception telemetry. ADR-0040 D9's mechanism choice applies to the **OTLP path**, not the SDK path.

The **regex scrubbing rules** (emails, phones, credit cards, API keys, JWT shapes) are **shared, not duplicated**. ADR-0040 packet 05 builds the PII scrubber as a **shared, mechanism-agnostic `PiiScrubber`** (string in → redacted string out + an attribute allowlist) from the start. ADR-0045 packet 03's error `ITelemetryProcessor` simply **consumes** it. No refactor is needed — the component is shared by construction. This is a plain hard cross-initiative dependency (packet 03 → ADR-0040 packet 05), not a soft/recommendation edge.

## Observe-vs-Pulse Boundary — RESOLVED

The error path targets **`HoneyDrunk.Pulse`**, not `HoneyDrunk.Observe`. `repos/HoneyDrunk.Observe/boundaries.md` explicitly states outbound telemetry to external sinks belongs to Pulse — Observe is the *inbound* external-system observation layer. `HoneyDrunk.Pulse` (v0.3.0, LIVE) already owns `ITraceSink`/`ILogSink`/`IMetricsSink`/`IAnalyticsSink`/**`IErrorSink`** and the `HoneyDrunk.Telemetry.Sink.*` provider family (including `HoneyDrunk.Telemetry.Sink.AzureMonitor` and `HoneyDrunk.Telemetry.Sink.Sentry`). ADR-0045 was amended 2026-05-22 to match, the same correction applied to companion ADR-0040. Packets 02 and 03 target `HoneyDrunk.Pulse`. The `IErrorReporter` facade is added to `HoneyDrunk.Telemetry.Abstractions` alongside the existing `IErrorSink`; the App Insights error backing extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package — no new package. Pulse.Collector's error-wiring is no longer gated — packet 07's playbook covers it as a near-mechanical change.

## Version Bumps

- **`HoneyDrunk.Pulse`** — packets 02 and 03 land on the solution. The version-bump rule (invariant 27) interacts with ADR-0040's Pulse packets. The packets are written to **check the in-progress version state at edit time**: whichever of {ADR-0040's Pulse packets, ADR-0045 #02/03} is the first un-released packet bumps the solution; the rest append. Because ADR-0045's Pulse packets are sequenced *after* ADR-0040's Pulse waves (via the cross-initiative `dependencies:` edges), the expected outcome is ADR-0040 bumped the solution and by the time ADR-0045 #02 lands the solution may be at a released version — in which case #02 bumps (minor, new public types) and #03 appends. Each packet records which case applied.
- **`HoneyDrunk.Notify`** — packet 05 is the only ADR-0045 packet on the solution; it bumps the version (minor — the error-reporting integration). Per-package CHANGELOG entries only for packages with actual changes.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; packet 04 is a workflow/YAML change. CHANGELOG updated per the repo convention if it keeps one.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only (packets 00, 01, 06, 07).

## Cross-Cutting Concerns

### Site sync

No site-sync flag. ADR-0045 is internal Ops infrastructure — no public-facing Studios website content changes.

### Notify-Sentry account decommission (deferred item)

Notify's Sentry integration is **config-only** — a scan found no Sentry SDK code, only account/DSN configuration. Packet 05's PR removes the Sentry config references and wires `IErrorReporter`. The Sentry **account/project archival** is a human, post-merge step (a Sentry-portal action) — recorded in packet 05's Human Prerequisites. **It is tracked here, in this dispatch-plan deferred list — not in any catalog.** `catalogs/grid-health.json` node entries carry only `signal`/`version`/`canary_status`/`last_release`/`active_blockers`/`notes`; there is no schema slot for a decommission item. Because the migration is config-only (nothing emits to Sentry from code), there is no parallel-run window — archive the account once `IErrorReporter` is wired and verified.

**Deferred item:** Archive the config-only Notify-Sentry account/project and decommission its DSN after packet 05 merges and errors are confirmed flowing to App Insights.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the error-flow invariant (number 80) and the `contracts.json` entry removed. No runtime impact.
- **Packet 02 (`IErrorReporter` facade):** revert the PR; the `HoneyDrunk.Pulse` solution version rolls back. No consumer depends on `IErrorReporter` until packet 03's backing and packet 05's Notify wiring land — a revert is contained to the abstraction package; the existing `IErrorSink` is untouched.
- **Packet 03 (App Insights error backing):** revert the PR. No Node captures errors through the backing until a host composes it — the revert is contained to `HoneyDrunk.Telemetry.Sink.AzureMonitor`. The shared `PiiScrubber` from ADR-0040 packet 05 is consumed, not modified — reverting packet 03 leaves it intact.
- **Packet 04 (Actions release annotation):** revert the workflow edit; the new inputs default off, so even un-reverted the step is inert until a consumer opts in.
- **Packet 05 (Notify migration):** revert the PR; `HoneyDrunk.Notify`'s solution version rolls back. The Notify-Sentry account is *not* deleted until the human archival step — so a revert restores the Sentry config cleanly (the account still exists).
- **Packet 06 (review.md / escalation doc):** revert the PR. Docs only.
- **Packet 07 (wiring playbook):** revert the PR. Docs only.
- **Backend-level escape hatch:** ADR-0045 D11's escalation path (Sentry as a dedicated error backend) is the architectural rollback for the *backend choice itself* — `IErrorReporter`/`IErrorSink` stay, the existing `HoneyDrunk.Telemetry.Sink.Sentry` backing is activated as the error sink, the swap is a single Pulse-side config change.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

**Before pushing:** replace the three cross-initiative placeholders (`Architecture#ADR0040-PACKET00` in packet 00, `Architecture#ADR0040-PACKET03` in packet 02, `Architecture#ADR0040-PACKET05` in packet 03) with the real `Architecture#<issue-number>` values once ADR-0040's packets are filed. A placeholder left in place produces a `::warning::` and an unwired cross-initiative edge.
