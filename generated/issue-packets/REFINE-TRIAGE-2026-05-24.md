# Refine Triage — ADRs 0048-0080

**Date:** 2026-05-24
**Scope:** 33 ADRs scoped into packets, then refined by the refine agent. This document synthesizes the cross-ADR systemic patterns and per-initiative critical issues that surfaced.

**Verdict at-a-glance:** Every packet set returned **Needs Work**. None are ready to push as-is. The systemic issues affect almost every initiative; the per-packet issues are narrower but real.

---

## Tier 1 — Systemic Issues (Grid-wide, fix once)

### S1. Invariant numbering is broken across all 33 initiatives

**Truth check:** actual max in `constitution/invariants.md` is **53**. Verified.

**Drift surfaced:**
- Packets claim max is "49" (ADR-0058), "51" (ADR-0053, ADR-0056), or "53" (most). Only "53" is correct.
- Packets pre-reserve numbers like 78-81, 82-84, 85-88, 87-89, 90-92, 93-95, 96-97 — none of these reservations exist in any registry.
- The phrase "12-ADR batch reservation" is cited by ~15 packets but has no documented source.
- Multiple initiatives reserve **overlapping** numbers:
  - ADR-0042 reserves 75-77; ADR-0068 also reserves 75-78; ADR-0062 reserves 78-81.
  - ADR-0049 reserves 82-84; ADR-0058 reserves 82-84; ADR-0077 reserves 84-86.
  - ADR-0080 reserves 87-89; ADR-0025 (Sim) already reserves 83-92.
  - ADR-0048 reserves 93-95; ADR-0056 reserves 93-95.

**Fix:** Create a central reservation registry. Either:
- (a) `constitution/invariant-reservations.md` listing which ADR claims which numbers, with the rule "claim by writing to this file in your packet 00, before pushing." OR
- (b) Force every packet 00 to read the live max at execution time and append (not pre-reserve), with the trade-off that two ADRs accepting in the same hour can collide.

Recommendation: (a). Land the registry as a one-off fix, then sweep all packet 00s to claim against it.

### S2. Cross-initiative dependencies don't resolve via `dependencies:` field

The `dependencies: ["packet:NN"]` shape only resolves within an initiative folder. The packet-files workflow wires `addBlockedBy` from that array literally. But many initiatives have real cross-init dependencies (e.g., ADR-0078 needs ADR-0060's catalog entries; ADR-0068 needs ADR-0042's NuGet packages; ADR-0066/0069/0067 all want Kernel 0.8.0). These are documented in prose but not wired.

**Fix:** Adopt the `Repo#NN` form (placeholder until issue-numbers known) OR add a `cross-init-prereqs:` field to packet frontmatter that the dispatch agent honors. For now, every packet that depends on a cross-init artifact needs an explicit Human Prerequisite naming the gating issue.

### S3. Multiple ADRs convergent-bump `HoneyDrunk.Kernel` to 0.8.0

ADR-0042, ADR-0058, ADR-0062, ADR-0066, ADR-0067, ADR-0068, ADR-0069, ADR-0066 all bump Kernel 0.7.0 → 0.8.0 in their respective Wave-2 packets. First to merge claims 0.8.0; the rest must append. Without coordination, executors will not know which case they're in.

**Fix:** Either pre-assign Kernel versions (ADR-0042 = 0.8.0, ADR-0066 = 0.9.0, etc.) or document a single coordinator rule in `repos/HoneyDrunk.Kernel/active-work.md` and have all the Wave-2 packets reference it.

### S4. Misquoted invariants

- ADR-0072 packets cite "invariant 3 = dependency direction" — actual invariant 3 is "Provider packages depend on their parent Node's contracts."
- ADR-0072 packets cite "invariant 8 = parameterized SQL" — actual invariant 8 is "Secret values never appear in logs, traces, exceptions, or telemetry."
- ADR-0072 invents severity scale "blocking/strong/advisory" — actual rubric is `Block / Request Changes / Suggest`.
- ADR-0064 packet 03 cites data-classification tiers as `Public/Internal/Confidential/Sensitive` — actual ADR-0049 tiers are `Public/Internal/Confidential/Restricted`.
- ADR-0056, ADR-0058, ADR-0063, ADR-0076 cite invariants that don't exist (70, 71, 80, 51 stretched).

**Fix:** Sweep every packet for invariant citations; verify against current `constitution/invariants.md`. Reject the "12-ADR batch" framing entirely — there is no batch document.

### S5. Several ADRs cited as Accepted are still Proposed

- ADR-0011 (Code Review and Merge Flow) — still Proposed. Cited as Accepted by ADR-0079 packets and ADR-0080 GitHub stub.
- ADR-0046 (Specialist Review Agents) — still Proposed. Cited as Accepted by ADR-0079 and ADR-0048 packets.
- ADR-0042, ADR-0045, ADR-0049, ADR-0050, ADR-0060, ADR-0063 — all Proposed; cited as if their packets had shipped.

**Fix:** Either accept the upstream ADRs first OR soften citations to "ADR-NNNN D-letter (Proposed)" and gate Wave-2+ packets on upstream acceptance.

---

## Tier 2 — Cross-ADR Conflicts (must resolve in ADR text before packets ship)

### C1. ADR-0067 ↔ ADR-0057 (rate-limit envelope)

- **ADR-0057 D11** commits `X-RateLimit-Limit / -Remaining / -Reset` (legacy `X-` prefix).
- **ADR-0067 D7** commits unprefixed IETF form, explicitly forbidding `X-` mirrors.
- **ADR-0057 D11** keys per-tenant **AND** per-API-key.
- **ADR-0067 D5** keys per-tenant only.
- **ADR-0057 D12** error-`type` URI host is `errors.honeydrunkstudios.com`.
- **ADR-0067 D6** uses `docs.honeydrunkstudios.com/errors/`.

**Fix:** Amend ADR-0057 to reconcile with ADR-0067 (or vice versa). Add explicit "Amends ADR-0057" section in ADR-0067 + a coordinated amendment packet.

### C2. ADR-0075 ↔ ADR-0057 (docs tooling)

- **ADR-0057 D15** picks Redocly for OpenAPI docs sites with `docs.notify.honeydrunkstudios.com` URL.
- **ADR-0075 D2** picks Docusaurus for public Node docs sites without addressing OpenAPI rendering.

**Fix:** Carve scopes ("Redocly for OpenAPI reference; Docusaurus for narrative") or amend one ADR to defer to the other. ADR-0075 must explicitly supersede or harmonize ADR-0057 D15.

### C3. ADR-0073 ↔ its own text (Push provider name)

- ADR-0073 D3 literal text: `HoneyDrunk.Notify.Providers.Expo`.
- Packet 08 renames to `HoneyDrunk.Notify.Providers.Push.Expo` (channel-scoped pattern).

**Fix:** Amend ADR-0073 D3 to the channel-scoped form in packet 00, or honor the literal text.

### C4. ADR-0070 ↔ PDR-0005/PDR-0008 (frontend stack)

- ADR-0070 D3 says "no current or queued PDR meets the bar for native mobile."
- PDR-0005 (Hearth) and PDR-0008 (Curiosities) both explicitly commit to native Swift+Kotlin.

**Fix:** Re-draft ADR-0070 D3 / Alternatives Considered to acknowledge the PDR carve-outs before packet 00 flips status to Accepted. Accepting a known-wrong ADR violates the user's `feedback_adr_workflow` rule.

### C5. ADR-0067 ↔ ADR-0027 (Notify Cloud tier names)

- ADR-0067 reconciles tiers to `Free/Pro/Scale` (from ADR-0037).
- ADR-0027 currently uses `Free/Starter/Pro`.
- No packet in either initiative amends ADR-0027.

**Fix:** Add an ADR-0027 amendment packet to either initiative.

---

## Tier 3 — Boundary / Invariant Violations (must fix before packet code lands)

| ADR | Violation | Fix |
|-----|-----------|-----|
| **ADR-0048** | `RollbackAttribute` Grid-wide contract shipped in single Node package (`HoneyDrunk.Notify.Data`). Violates invariants 1/2. | Move attribute to `HoneyDrunk.Standards` or `HoneyDrunk.Data.Abstractions`. |
| **ADR-0054** | Packet 03 names `kv-hd-shared-{env}` Vault. Violates invariant 17 (one Vault per deployable Node). | Move the PagerDuty secret into `kv-hd-pulse-{env}` or `kv-hd-notify-{env}`. |
| **ADR-0054** | `IIncidentPagingSender` in Notify.Abstractions; paging intent decision belongs to Communications per invariant 41. | Move intent to Communications; Notify gets only the delivery payload. |
| **ADR-0067** | AspNetCore middleware in `HoneyDrunk.Kernel` drags `Microsoft.AspNetCore.*` into every Kernel consumer (Vault, Transport, Data, Auth, etc.). | Default to `HoneyDrunk.Kernel.Webhooks.AspNetCore` sub-package. |
| **ADR-0069** | `Money` record `==` override that throws breaks .NET equality contract (HashSet, Dictionary, EF tracking). | Drop the "throw on cross-currency `==`" rule; record-default `false` is fine. |
| **ADR-0069** | `System.Text.Json` in `HoneyDrunk.Kernel.Abstractions` violates literal invariant 1 ("only `Microsoft.Extensions.*` abstractions"). | Move `MoneyJsonConverter` to `HoneyDrunk.Kernel` (runtime) or amend invariant 1 in packet 00. |
| **ADR-0076** | Cache library Node creating own Vault violates invariant 17. | Move Redis connection string ownership to consumer Vaults (Notify Cloud, Communications). |
| **ADR-0080** | Invariant 88 "generalizes invariants 1/2/3/44" — invariants 1/2/3 are intra-Grid packaging rules, not vendor-portability rules. | Rewrite generalization to cite only invariant 44 plus 9/9a/47/48 analogues. |
| **ADR-0073** | `NotificationChannel` enum has no `Push` value; packet 08 ships `PushEnvelope` without adding the enum member. | Add `NotificationChannel.Push = 2` to scope. |
| **ADR-0062** | Packet 04 prescribes downstream Service Bus key `webhook:{provider}:{event-id}` — contradicts invariant 77 (SHA256-of-relationship). | Reword: receiver dedup key = `webhook:{provider}:{event-id}`; downstream-emitted key derives per invariant 77. |

---

## Tier 4 — Fabricated Precedents and Wrong File Paths (smaller, per-packet)

- **ADR-0048, ADR-0049, ADR-0050, ADR-0051**: Wrong source paths (`src/` prefix wrong for Auth, missing for Audit, doubled for Kernel csproj).
- **ADR-0049**: Packet 00 claims to amend invariant 47's "sensitive fields" clause — that phrase doesn't exist in invariant 47.
- **ADR-0052, ADR-0079, ADR-0074, ADR-0080**: Cite `business/context/` precedents (ADR-0040 cost note, ADR-0045 escalation note) — only `entity.md` actually exists there.
- **ADR-0053**: Claims `routing/execution-rules.md` doesn't exist — it does. Packet's fallback writes the rule to the wrong file.
- **ADR-0053**: Signal casing bug — packets filter `signal: live` (lowercase) but `grid-health.json` uses `"Live"` (capitalized). Workflows would match zero Nodes.
- **ADR-0058**: Claims `IMessageHandler` precedent (no `<T>`) — actual `contracts.json` has `IMessageHandler<T>`.
- **ADR-0059**: Filing-order rule violates `feedback_no_manual_packet_filing` memory.
- **ADR-0060**: 6-vs-7 record count drift across packets, dispatch plan, and canary.
- **ADR-0061**: Wrong line-anchored references in `nodes.json` (line 312 vs 357 — many AI/Lore Nodes between them).
- **ADR-0061**: `FileId.New()` uses Guid, but ADR D5/D7 commits to ULID.
- **ADR-0064**: Wrong classification tier name (`Sensitive` vs `Restricted`).
- **ADR-0065**: Packet 05 introduces new Pulse.Collector executable host as conditional ride-along (hidden scope expansion).
- **ADR-0071**: `cluster: "frontend"` invented (not in `nodes.json` taxonomy).
- **ADR-0072**: ADR-0073 reference doesn't exist (handoff doc copy-pasted artifact).
- **ADR-0074**: Wrong props-fragment path (`HoneyDrunk.Standards/HoneyDrunk.Standards.Tests/buildTransitive/`).
- **ADR-0075**: `honeydrunk-web-ui` Node doesn't exist in catalogs; packet 04 unfileable.
- **ADR-0076**: ADR-0033 misidentified as environments-standup ADR; correct is ADR-0053.
- **ADR-0077**: `bicep lint` doesn't accept `.bicepparam` files; packet 07 spec broken.
- **ADR-0078**: `provider_slot` field invented; no precedent in `contracts.json`.
- **ADR-0079**: ADR-0044 packets 13/17/03b referenced but unverified to exist.

---

## Tier 5 — Open Decisions Punted to Executing Agent (should decide pre-filing)

Several packets defer architectural decisions to "executor judgment at edit time":

- ADR-0048 packet 02: `database` agent invocation gate is manual but acceptance asserts it.
- ADR-0052 packet 06: `IGridContext` plumbing for `AgentId`/`AgentRunId` is undefined.
- ADR-0055 packet 06: analyzer NuGet repo location (Actions vs Standards).
- ADR-0063 packet 03: annotations assembly creates new NuGet package implicitly.
- ADR-0066 packet 03: Functions-host package split decision (yes/no).
- ADR-0067 packet 02: AspNetCore framework reference decision in Kernel.
- ADR-0070 packet 04: Hearth/Curiosities native-stack reconciliation (operator decision).
- ADR-0073 packet 03: Resend vs Svix rotation API surface uncertainty.
- ADR-0074 packet 02: props-fragment path.
- ADR-0075 packet 02: `MapOpenApi` API signature uncertainty.
- ADR-0076 packets 03/07: connection-string Vault ownership (library Node has no Vault).
- ADR-0077 packet 02: Bicep registry placement (ACR vs other).

---

## Recommended Path Forward

### Phase A (one-off cleanup)
1. Land a single PR creating `constitution/invariant-reservations.md` documenting which ADR claims which numbers (or commit to "claim on packet 00 push, no pre-reservation").
2. Land cross-ADR amendments for C1 (rate-limit envelope) and C2 (docs tooling). These are real text contradictions that must be resolved by the ADR author, not deferred to packet execution.
3. Re-draft ADR-0070 D3 to acknowledge native-mobile PDR carve-outs (C4).

### Phase B (per-initiative sweep)
For each of the 33 initiatives, dispatch a fix-pass agent with the refine report's prioritized list. Tier-3 violations must be fixed; Tier-4 corrections are mechanical; Tier-5 decisions need to be made (not punted).

### Phase C (post-fix re-refine)
Re-run refine on each touched initiative to confirm critical items resolved.

---

## Per-Initiative Refine Summaries

The full refine reports are in the conversation transcript that produced this document. Key landmines per ADR:

| ADR | Verdict | Top 1-2 blockers |
|-----|---------|------------------|
| 0048 | Needs Work | RollbackAttribute boundary; `database` agent gate |
| 0049 | Needs Work | Wave-3 packets target Seed-signal repos; D5/D6 internal contradiction |
| 0050 | Needs Work | Source paths wrong; packet 07 retroactively edits packet 05 |
| 0051 | Needs Work | False `Agents/` subfolder claim; missing `src/` prefix; unauthorized `OnBehalfOfPrincipal` type |
| 0052 | Needs Work | Invariant max claim wrong (49 vs 53); CostSummary deletion underspecified |
| 0053 | Needs Work | Signal casing (`Live` vs `live`); `routing/execution-rules.md` "doesn't exist" wrong; D2 naming conflict with existing convention |
| 0054 | Needs Work | `kv-hd-shared` invariant 17 violation; paging in Notify violates invariant 41; synthetic probe DDoS risk |
| 0055 | Needs Work | Catalog edges missing for Operator/Audit; packet 08 Operator-shell gating; CI label semantics |
| 0056 | Needs Work | Invariant max 51 vs 53; packet 08 cross-repo write undefined; packet 04 target_repo mismatch |
| 0057 | Needs Work | Collides with ADR-0067, 0075, 0062; Option A/B/C deferred to executor |
| 0058 | Needs Work | Phantom 54-81 reservation table; catalog naming missed `IMessageHandler<T>` precedent |
| 0059 | Needs Work | Filing-order violates `feedback_no_manual_packet_filing`; modules.json type mismatch |
| 0060 | Needs Work | 6-vs-7 record count drift; packet 02↔04 placeholder dance; DeletionIntent has no receiver |
| 0061 | Needs Work | Line-anchored nodes.json wrong; packet 02 cross-ref ordering; FileId GUID vs ULID |
| 0062 | Needs Work | Invariant numbering depends on unverified registry; AspNetCore drag; packet 04 contradicts invariant 77 |
| 0063 | Needs Work | Annotations assembly creates new NuGet package; AddFakeTimeProvider fires own analyzer warning |
| 0064 | Needs Work | Invariant numbers 85-88 wildly inflated; wrong tier name `Sensitive`; unauthorized `Inference` audit category |
| 0065 | Needs Work | Packet 05 hidden Pulse.Collector host expansion; `AddPulseCollector(opt:false)` dead code |
| 0066 | Needs Work | Invariant coordination asymmetric with ADR-0042; `RequireAuthorization()` startup throw risk |
| 0067 | Needs Work | Direct conflict with ADR-0057 (envelope, keying, URI) |
| 0068 | Needs Work | Invariant 75-78 collides with ADR-0042/0045 batch; cross-init NuGet deps unfileable; `caj-hd-` naming |
| 0069 | Needs Work | Record `==` override breaks .NET equality; ADR-0042 Kernel 0.8.0 race; STJ in Kernel.Abstractions |
| 0070 | Needs Work | Packet 00 accepts ADR contradicting PDR-0005/0008; packet 02 line-202 collision |
| 0071 | Needs Work | `cluster: "frontend"` invented; invariant 54-56 collision; Windows path bug |
| 0072 | Needs Work | Invariants 3, 8 misquoted; invented severity scale; ADR-0073 phantom reference |
| 0073 | Needs Work | CHANGELOG Unreleased delta; missing `NotificationChannel.Push`; polyglot npm package without ADR |
| 0074 | Needs Work | Wrong props-fragment path; fake `business/context/` precedent; stale ADR-language |
| 0075 | Needs Work | Collides directly with ADR-0057 D15; `honeydrunk-web-ui` doesn't exist; `MapOpenApi` API misuse |
| 0076 | Needs Work | Phantom invariants 70/71/80 cited; ADR-0033 misidentified; library Node forbidden a Vault |
| 0077 | Needs Work | Invariant 35 collision (`acrhdbicep` second ACR); App Insights connectionString leak; `.bicepparam` lint broken |
| 0078 | Needs Work | `provider_slot` field invented; cross-init deps not in `dependencies:`; 24-month secret violates invariant 20 |
| 0079 | Needs Work | ADR-0011/0046 cited as Accepted (both Proposed); fabricated `business/context/` precedents; packet 03 builds on undocumented Anthropic API |
| 0080 | Needs Work | Invariants 87/88/89 collide head-on with ADR-0025 Sim reservations |
