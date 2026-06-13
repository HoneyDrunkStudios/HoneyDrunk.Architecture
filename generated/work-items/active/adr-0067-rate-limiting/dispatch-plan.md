# Dispatch Plan — ADR-0067: Inbound Rate Limiting and Quota Enforcement

**Initiative:** `adr-0067-rate-limiting`
**ADR:** ADR-0067 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0067 commits the Grid's substrate, response shape, success-side headers, tier defaults, and deferral triggers for inbound rate limiting and quota enforcement. ADR-0026 D4 placed `ITenantRateLimitPolicy` / `TenantRateLimitDecision` in `HoneyDrunk.Kernel.Abstractions` as primitives but explicitly deferred the storage and substrate to consumer Nodes. ADR-0027 D6 named Notify Cloud as the first non-noop policy implementation but did not pin the substrate, the response shape, the success-side header convention, the tier-to-limits mapping, or the per-tenant quota counter store. ADR-0067 closes that gap: ASP.NET Core `RateLimiter` middleware as the in-process substrate (Cloudflare as the edge complement); RFC 7807 `application/problem+json` 429 envelope (pinned shape); IETF draft `RateLimit-*` success-side headers; per-tier defaults for Notify Cloud at GA; per-tenant counter store with Azure Storage Tables Phase-1 default; opt-in `AddGridRateLimiting()` / `UseGridRateLimiting()` in the Kernel runtime with three default-named policies (`"tier"` / `"anon"` / `"quota-billable"`); and a named distributed-limiter migration trigger.

This initiative delivers, in **6 packets across 3 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.Audit`, `HoneyDrunk.Pulse`):

1. ADR acceptance + the substrate registration in tech-stack.md + the Kernel extension surface in contracts.json (Architecture).
2. The Kernel substrate — `AddGridRateLimiting` / `UseGridRateLimiting` extension methods, the partitioned ASP.NET Core `RateLimiter` middleware, the RFC 7807 429 envelope, the IETF `RateLimit-*` headers, and the three named policies in `HoneyDrunk.Kernel` (Kernel).
3. The canonical Audit event-shape registration (`RateLimitRejected`, `QuotaOverageBilled`) — documentation in `HoneyDrunk.Audit` (Audit).
4. The canonical Pulse metric catalog (`rate_limit_rejection_count`, `rate_limit_remaining_ratio`, alarm threshold) — documentation in `HoneyDrunk.Pulse` (Pulse).
5. The Notify Cloud production rate-limit policy specification — documentation in `HoneyDrunk.Architecture` as the handoff to the deferred Notify Cloud follow-up.

**6 packets, all `Actor=Agent`, 0 `Actor=Human`.** No packet carries a Human Prerequisite that requires action *during* this initiative's filing window — packet 02 (Kernel) records a "publish the upstream NuGet package after merge" prerequisite that is the standard agents-never-tag rule. Packet 05 records the deferred Notify Cloud follow-up; that is a post-`adr-0027-notify-cloud-standup` action, not a prerequisite for this initiative.

## Trigger

ADR-0067 is Proposed with no scope. The forcing functions from the ADR's Context: Notify Cloud GA is the first commercial API consumer; ADR-0027 D6 names Notify Cloud as the first non-noop `ITenantRateLimitPolicy` implementation; without a Grid-level substrate decision Notify Cloud will hard-code its own limiter and the next public API surface (Web.Rest endpoints onboarding their first commercial tenant, Communications opening a public surface, any future Billing surface) will hard-code a different one. The cost of letting the convention drift across N Nodes is N rewrites later when the first inconsistency surfaces in a customer outage.

ADR-0042 (Idempotency) is also mid-flight on `HoneyDrunk.Kernel` — both initiatives bump the solution from `0.7.0` to `0.8.0`. The Kernel version-bump coordination is recorded in Wave 2 below.

## Scope Detection

**Multi-repo, multi-Node — but smaller than the comparable observability initiatives.** ADR-0067 lands the substrate in `HoneyDrunk.Kernel` (packet 02). Audit and Pulse get **documentation-only** packets (03, 04) that register the canonical event-name + metric-name shapes Notify Cloud will emit — no contract change in either repo. `HoneyDrunk.Architecture` carries the governance (acceptance, tech-stack, contracts.json catalog) and the deferred Notify-Cloud-policy specification.

**Notify Cloud production policy is deliberately deferred.** ADR-0027 (Notify Cloud standup) is Proposed; the Notify Cloud repo does not exist on disk; `file-work-items.yml` cannot file against it. Per the user's standing convention ("new-Node scaffolding gets its own standup ADR; don't bundle scaffold into feature packets"), the Notify Cloud rate-limit-policy implementation packet must file *after* the `adr-0027-notify-cloud-standup` initiative's packet 06 (scaffold) lands. This initiative authors the specification in packet 05 as the handoff document; the production-implementation packet against `HoneyDrunk.Notify.Cloud` is filed as a *new* follow-up packet (or new initiative) after ADR-0027 completes — see Cross-Cutting Concerns.

**No invariant edits.** ADR-0067 §Consequences/Invariants is explicit: no new invariants. The middleware-ordering requirement (`UseGridContext` before `UseGridRateLimiting`) is documented at the extension method, not as a new invariant. Existing invariants 5/6 (GridContext present) and 8 (no secrets in logs/traces) apply unchanged.

**No new Node-to-Node edges in `catalogs/relationships.json`.** Notify Cloud's consumption of `ITenantRateLimitPolicy` will land when Notify Cloud is stood up in the ADR-0027 initiative; this initiative does not edit relationships.json.

**No new abstractions in `HoneyDrunk.Kernel.Abstractions`.** The contract `ITenantRateLimitPolicy` is already there (ADR-0026 D4). This initiative ships *wiring* in the Kernel runtime, not a new contract.

## Cross-Dependency with ADR-0042 (Idempotency)

ADR-0042 is mid-flight on `HoneyDrunk.Kernel` — its packet 02 bumps the Kernel solution from `0.7.0` to `0.8.0`. This initiative's packet 02 also lands on Kernel and also targets `0.8.0`.

**This is a soft dependency, not a hard blocker.** Per invariant 27 ("all projects in a solution share one version"), the *first* packet on a solution in any active initiative bumps; subsequent packets append to the in-progress CHANGELOG entry. Two cases at execution time:

1. **ADR-0042 packet 02 lands first.** This initiative's packet 02 appends to the in-progress `[0.8.0]` CHANGELOG entry; no version bump. The Kernel solution is already at `0.8.0` when packet 02 starts; the `.csproj` files do not change.
2. **This initiative's packet 02 lands first.** ADR-0042 packet 02 appends to *our* `[0.8.0]` entry; same logic, reversed.

The executor of packet 02 checks the in-progress version state at execution time and chooses between bumping and appending. The decision is stated in the PR. Either ordering is acceptable; the two packets do not conflict on file paths (idempotency code is under `HoneyDrunk.Kernel/Idempotency/`-ish locations per ADR-0042 packet 04; rate-limit code is under `HoneyDrunk.Kernel/RateLimiting/`).

**Flagged for the operator:** the human NuGet-tag/release of `HoneyDrunk.Kernel` `0.8.0` after merge carries *both* sets of changes if both packets have merged. If they land on `main` at different times, the publisher releases `0.8.0` once after both are in — or releases `0.8.0` after the first lands and follows with `0.8.1` after the second (which would not match invariant 27 if 0.8.0 has any consumer; a single `0.8.0` release covering both is cleaner). Coordinate the tag-push to follow the second merge.

## Cross-Initiative Coupling with ADR-0027 (Notify Cloud Standup)

ADR-0027 is Proposed; the `HoneyDrunk.Notify.Cloud` repo does not exist on disk. ADR-0067 D3 / D8 / D10 commit numbers and shapes that *land* in Notify Cloud's production `ITenantRateLimitPolicy` implementation. But Notify Cloud's implementation can only be filed after the Notify Cloud repo exists and is scaffolded — i.e., after `adr-0027-notify-cloud-standup` packet 06 (scaffold) lands.

**This initiative's resolution:** packet 05 authors the full Notify Cloud rate-limit-policy specification in the Architecture repo (at `infrastructure/walkthroughs/notify-cloud-rate-limit-policy.md` or equivalent) — a doc that the future follow-up filer reads and turns into a real packet against `HoneyDrunk.Notify.Cloud`. The handoff is explicit: the specification carries a "Follow-up Notify Cloud packet" outline at the bottom (target repo, expected scope, dependencies, version-bump expectation).

The follow-up Notify Cloud packet is **not** filed in this initiative. It is filed:

- **Option A** — as part of the `adr-0027-notify-cloud-standup` initiative's wave-4 follow-up packets (the natural home, since ADR-0027 packet 06's scaffold ships a placeholder `ITenantRateLimitPolicy` that the production implementation replaces).
- **Option B** — as a new initiative `adr-0067-notify-cloud-rate-limit-policy` after `adr-0027-notify-cloud-standup` completes, if the operator prefers an explicit follow-up wave.

Either is acceptable; the choice is the operator's at the time the Notify Cloud follow-up is filed. The specification document in packet 05 is the same regardless.

**Exit criterion reconciliation.** ADR-0067's own exit criterion is "Scope agent flips Status → Accepted after the Kernel extension surface ships at 0.x and the first Notify Cloud tier-driven `ITenantRateLimitPolicy` lands." Packet 00 flips Status to Accepted at the *start* of this initiative — not at the end — because the ADR's decisions are needed *as live rules* by packets 02–05. The deeper success criterion ("Kernel surface ships + first Notify Cloud policy ships") is the **initiative-completion gate** recorded in `initiatives/active-initiatives.md`; that gate is satisfied across the ADR-0027 standup boundary, not within this initiative's filing window. This split mirrors the pattern used by other Proposed-but-implemented ADRs (ADR-0042 followed the same shape).

## No-Invariant-Edits Discipline

ADR-0067 §Consequences/Invariants is explicit:

> No new invariants are introduced by this ADR. The existing invariants that the rate limiter is required to honor: Invariant 8 (secret values never appear in logs or traces); Invariant 5 / 6 (GridContext present and populated).

Packet 00 does **not** touch `constitution/invariants.md`. ADR-0067 is **excluded from the 12-ADR pre-reservation batch** that allocated invariant numbers 54-95 to sibling ADRs — no number is reserved for ADR-0067 because ADR-0067 needs no number. If, at execution time, the user decides ADR-0067 *should* have one or more invariants codified (e.g. "every Node that exposes an HTTP surface composes `AddGridRateLimiting`", or "the 429 envelope shape is invariant"), that is a separate amendment to the ADR followed by a new acceptance packet — not a silent append from this packet.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0067, register the initiative. **No invariants added** (ADR-0067 explicitly adds none). `Actor=Agent`.
- [ ] **01** — Architecture: append the Rate Limiting section to `infrastructure/reference/tech-stack.md` (ASP.NET Core `RateLimiter` substrate + Cloudflare edge + rejected alternatives); register the new Kernel extension surface (`AddGridRateLimiting`, `UseGridRateLimiting`, the three named-policy constants) in `catalogs/contracts.json` under `honeydrunk-kernel`. **No new abstractions, no new edges.** `Actor=Agent`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — the Kernel substrate)
- [ ] **02** — Kernel: ship `AddGridRateLimiting()` / `UseGridRateLimiting()` extension methods + the ASP.NET Core `RateLimiter` middleware wiring + the RFC 7807 429 envelope (D6) + the IETF `RateLimit-*` success-side headers (D7) + the three default-named policies `"tier"` / `"anon"` / `"quota-billable"` (D9). Anonymous endpoints key on `CF-Connecting-IP`; API-key-validation pre-auth keys on the 8-character display prefix (D5). `Actor=Agent`. Blocked by: 00. **Version-coordinating packet for `HoneyDrunk.Kernel` `0.8.0` — coordinates with `adr-0042-idempotency` initiative which also bumps Kernel to `0.8.0`.**

### Wave 3 (Depends on Wave 1 — docs-only registrations, parallel; specification handoff)
- [ ] **03** — Audit: document the canonical `RateLimitRejected` and `QuotaOverageBilled` event-name + field-shape + metadata in `HoneyDrunk.Audit/README.md` (or `docs/event-catalog.md`). **Docs only, no contract change.** `Actor=Agent`. Blocked by: 00.
- [ ] **04** — Pulse: document the canonical `rate_limit_rejection_count` counter (tags `tenant_id`/`endpoint`/`tier`/`outcome`) + `rate_limit_remaining_ratio` gauge + alarm threshold (≥50 rejections / 5min for a single `(tenant_id, endpoint)`) in `HoneyDrunk.Pulse`'s README or docs. **Docs only, no contract change.** `Actor=Agent`. Blocked by: 00.
- [ ] **05** — Architecture: author the Notify Cloud production rate-limit-policy specification at `infrastructure/walkthroughs/notify-cloud-rate-limit-policy.md` — the deferred handoff to the future Notify Cloud follow-up packet (filed after `adr-0027-notify-cloud-standup` packet 06 lands). `Actor=Agent`. Blocked by: 00.

Packets within Wave 3 run in parallel — three different target repos / directories, no shared file conflict. Wave 3 packets all depend on **packet 00 only**, not packet 02 — they are docs/catalogs only; they do not consume the Kernel runtime extension. Packet 02 is the only Wave 2 packet because it is the only code-shipping packet, and only it carries the version-coordinating bump.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0067 — no invariants added](./00-architecture-adr-0067-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [tech-stack.md + contracts.json catalog](./01-architecture-rate-limiting-catalog-and-tech-stack.md) | Architecture | Agent | 1 | 00 |
| 02 | [AddGridRateLimiting / UseGridRateLimiting in Kernel](./02-kernel-rate-limiting-extensions-and-middleware.md) | Kernel | Agent | 2 | 00 |
| 03 | [Audit event-shape registration — RateLimitRejected + QuotaOverageBilled](./03-audit-rate-limit-event-shape.md) | Audit | Agent | 3 | 00 |
| 04 | [Pulse metric catalog — rate_limit_rejection_count + rate_limit_remaining_ratio + alarm](./04-pulse-rate-limit-metric-catalog.md) | Pulse | Agent | 3 | 00 |
| 05 | [Notify Cloud rate-limit policy specification — handoff to ADR-0027](./05-architecture-notify-cloud-policy-specification.md) | Architecture | Agent | 3 | 00 |

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 02 is on the solution. Per invariant 27, the *first* packet on the solution in any in-flight initiative bumps the version; subsequent packets append. The expected case at execution time is that **`adr-0042-idempotency` packet 02 has either landed first or has not yet landed**:
  - If ADR-0042 #02 lands first → the Kernel solution is already at `0.8.0` when this packet 02 starts; this packet appends to the in-progress `[0.8.0]` repo-level CHANGELOG entry and adds its per-package `HoneyDrunk.Kernel/CHANGELOG.md` entry for the rate-limiting wiring.
  - If this packet 02 lands first → it bumps the Kernel solution `0.7.0` → `0.8.0` (minor; additive new wiring per ADR-0035 D1); ADR-0042 #02 then appends.
  Either ordering is acceptable. The executor states the chosen case in the PR.
- **`HoneyDrunk.Audit`** — packet 03 is docs-only. No version bump unless the repo's convention treats doc-only updates as version-noteworthy, in which case a PATCH (`0.1.0` → `0.1.1`) is acceptable. `[Unreleased]` is forbidden — use a dated section.
- **`HoneyDrunk.Pulse`** — packet 04 is docs-only. Same rule as Audit; PATCH-bump optional per repo convention; `[Unreleased]` forbidden.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/doc edits only across packets 00, 01, 05.

## Cross-Cutting Concerns

### No new invariants — deliberate, not an oversight

The ADR is explicit. This initiative does not append placeholder text to `constitution/invariants.md` and does not reserve a batch number for ADR-0067. If the user decides later that the 429 envelope shape or the success-side header presence warrants an invariant, that is a separate ADR amendment + acceptance packet — not silent drift from this initiative.

### Notify Cloud production policy is deferred — handoff lives in packet 05

ADR-0027 (Notify Cloud standup) is Proposed; the `HoneyDrunk.Notify.Cloud` repo does not exist on disk; `file-work-items.yml` cannot file against it. This initiative's packet 05 authors the production-implementation specification in the Architecture repo; the implementation packet against `HoneyDrunk.Notify.Cloud` is filed as a follow-up after `adr-0027-notify-cloud-standup` packet 06 (scaffold) lands. The follow-up filer reads packet 05's spec and turns the "Follow-up Notify Cloud packet" outline at the bottom into a real packet.

Forecasted scope of that follow-up work-item: implementation of `ITenantRateLimitPolicy` with the D3 tier defaults baked in; the per-tenant Azure Storage Tables counter store backing D8 quotas; the App Configuration tier-override read per D2 layer 2 (behind the ADR-0055 feature flag); the `RateLimitRejected` + `QuotaOverageBilled` audit emits per the canonical shape in packet 03 of this initiative; the `rate_limit_rejection_count` + `rate_limit_remaining_ratio` metric emits per the canonical catalog in packet 04 of this initiative. Target repo `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud`. Blocked by `adr-0027-notify-cloud-standup` packet 06. Version-bumping packet for the Notify Cloud solution (`0.1.0` → `0.2.0` minor; production policy replacing the scaffold placeholder).

### Docs page for the 429 `type` URI is a deferred follow-up

ADR-0067 D6 pins the `type` URI at `https://docs.honeydrunkstudios.com/errors/rate-limited`. The docs page itself does not exist at packet-execution time. The URI is the stable machine-readable identifier; SDK consumers per ADR-0057 D8 parse the body fields directly without dereferencing the URI. Authoring the docs page is a deferred Studios-website follow-up; this initiative ships the constant URI in code (packet 02) so the convention is locked, and the page authoring is a separate, smaller task tracked outside this initiative.

### No catalog edges added in `relationships.json`

ADR-0067 D9 places the wiring in Kernel; every Node that exposes HTTP composes `AddGridRateLimiting` per host-time choice. The composition is at the host level, not a package-level dependency edge — Nodes already reference `HoneyDrunk.Kernel`. Notify Cloud's consumption of `ITenantRateLimitPolicy` lands in `relationships.json` when Notify Cloud is stood up in the ADR-0027 initiative, not here.

### Site sync

No site-sync flag. ADR-0067 is internal Core infrastructure; the Studios website does not change.

The docs page at `docs.honeydrunkstudios.com/errors/rate-limited` (D6 `type` URI target) is a separate, deferred follow-up — recorded under Deferred Follow-ups below — and not surfaced as a site-sync flag on this initiative.

### Deferred follow-ups (explicitly out of scope of this initiative)

- **Notify Cloud production `ITenantRateLimitPolicy` implementation + quota counter store.** Filed after `adr-0027-notify-cloud-standup` packet 06 lands. Specification in packet 05 of this initiative.
- **Per-tenant rate-limit override store (ADR-0067 D2 layer 1).** Deferred to first concrete need (a VIP customer or a troublemaker tenant). When that need surfaces, a new packet authors the store shape and the integration. Until then the policy operates on layer 2 + layer 3 only.
- **Distributed-limiter migration (ADR-0067 D5b).** Triggers named; the in-process limiter is sufficient at GA. When the trigger fires (Notify Cloud >3 replicas, OR paying-tenant complaint about non-determinism, OR aggregate per-process limit exceeds 3× the tier ceiling), a follow-up ADR ("Distributed Rate-Limiter Backing for Notify Cloud") picks the backing — leaning toward `HoneyDrunk.Cache` (per ADR-0058 / ADR-0059) — and commits the migration.
- **`docs.honeydrunkstudios.com/errors/rate-limited` page.** Authored on the Studios website. URI is stable now; page can be authored anytime.
- **`RateLimit-Policy` header (ADR-0067 D7).** The Grid does not currently emit it; deferred until a customer requests it.
- **Web.Rest and Communications opt-in to `AddGridRateLimiting`.** Recorded under ADR-0067 §Consequences / Affected Nodes. Each Node opts in at host time when it exposes its first tenant-facing endpoint; this initiative does not pre-emptively wire them.
- **APIM revisit.** If a Node specifically needs APIM features (developer portal, OAuth2 token issuance, transformation policies), the rate-limit substrate question is re-litigated as a single-Node choice at that point.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; tech-stack.md and contracts.json entries are removed. No runtime impact.
- **Packet 02 (Kernel substrate):** revert the PR; `HoneyDrunk.Kernel` rolls back to `0.7.0` (if this packet was the version-bumper) or keeps `0.8.0` (if ADR-0042 packet 02 already bumped — the rate-limiting code leaves but the version stays). The wiring is additive — no consuming Node depends on it at runtime until it composes it. Nodes that have not opted into `AddGridRateLimiting` see no behaviour change pre- or post-revert. If any Node has already opted in (none at the time this initiative files, by construction), that Node must drop its `AddGridRateLimiting` / `UseGridRateLimiting` calls when reverting.
- **Packet 03 (Audit docs):** revert the PR; the Rate-Limit Event Catalog section is removed from `HoneyDrunk.Audit/README.md`. No runtime impact (no code).
- **Packet 04 (Pulse docs):** revert the PR; the Rate-Limit Metric Catalog section is removed from `HoneyDrunk.Pulse`. No runtime impact.
- **Packet 05 (Notify Cloud specification):** revert the PR; the specification document is removed from `infrastructure/walkthroughs/`. No runtime impact. The deferred Notify Cloud follow-up is unaffected at the runtime level; only the reference document is gone.
- **Operational escape hatch:** if a Node that has composed `AddGridRateLimiting` produces an unexpected 429 storm (e.g. a misconfigured tier override), the operator can either (a) toggle the ADR-0055 feature flag that gates the App Configuration per-tier overrides, falling the policy back to code defaults, or (b) compose the `NoopTenantRateLimitPolicy` at the host (a one-line change) to short-circuit all decisions to `Allow`. Both are config-only changes; neither requires a code revert.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

The Notify Cloud follow-up packet is **not** in this folder and is **not** filed by this initiative's push — it is filed later, against the `HoneyDrunk.Notify.Cloud` repo, after the `adr-0027-notify-cloud-standup` initiative's packet 06 (scaffold) lands. See Cross-Cutting Concerns above.
