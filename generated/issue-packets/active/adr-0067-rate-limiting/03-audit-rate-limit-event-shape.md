---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["feature", "tier-2", "core", "docs", "adr-0067", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0067"]
wave: 3
initiative: adr-0067-rate-limiting
node: honeydrunk-audit
---

# Register RateLimitRejected and QuotaOverageBilled audit event-shapes in HoneyDrunk.Audit

## Summary
Confirm and document the canonical shape of the two audit event-types ADR-0067 D10 commits — `RateLimitRejected` (every hard 429) and `QuotaOverageBilled` (Pro/Scale tenants over their monthly quota; request proceeded, billing meter incremented) — in `HoneyDrunk.Audit`'s docs. This is a docs-only packet: no contract change, no code change. The two event-types ride the existing `AuditEntry.EventName` field; this packet pins the canonical names, categories, outcomes, and metadata-field shapes so Notify Cloud (when its standup completes) emits the right entries and downstream forensic queries find them by stable name.

## Context
ADR-0067 D10 commits two audit event-shapes that flow through the existing `HoneyDrunk.Audit.Abstractions` `IAuditLog`:

- **`RateLimitRejected`** — emitted on every hard 429 (rate-limit rejection or hard-quota overage). Fields: `tenant_id` (or `null` for anonymous), `endpoint`, `limit_type` (`burst` / `sustained` / `daily-quota` / `monthly-quota`), `tier`, `retry_after_seconds`, `correlation_id`. Captured durably per ADR-0030's WORM-by-interface stance.
- **`QuotaOverageBilled`** — emitted for Pro/Scale tenants over their monthly quota when the overage is **billable** (the request proceeded and the Stripe meter was incremented per ADR-0037 D2; the request was NOT rejected). Marks the transition from in-quota to overage-billed.

`HoneyDrunk.Audit` is a live Node at v0.1.0. Its `AuditEntry` record carries a free-string `EventName` field; there is no enum of named events. The two event-types here are documented canonical strings consumed by `Notify Cloud`'s `ITenantRateLimitPolicy` implementation (when it ships per ADR-0027 standup + the ADR-0067 deferred follow-up in packet 05) and any future Node that opts into rate-limit / quota auditing.

This packet **does not** add code, does not change `IAuditLog` / `AuditEntry`, and does not introduce a new abstraction. It pins the names and the field shape in repo docs (`README.md` or a new `docs/event-catalog.md`) so the Audit Node's repo carries the canonical reference. The Architecture catalog (`catalogs/contracts.json`) already has Audit's contract surface from ADR-0030's catalog packet — no contracts.json edit is required here either; this is repo-level documentation only.

> **Why doc-only.** `AuditEntry.EventName` is a free string; the Grid does not yet maintain a typed enum or registry of event names. The audit substrate is "append-only-by-interface" (Phase-1 honest limitation per the Audit `README.md`). Until a typed registry is introduced (a future ADR if and when warranted), the canonical-event-name discipline is enforced by *documentation* — consumers refer to this catalog and emit the documented names verbatim. The same pattern is used elsewhere in the Grid (e.g., audit event-names from ADR-0030 itself are documented, not enumerated).

`HoneyDrunk.Audit` is a docs-only target here — no `.csproj` edits, no version bump. The repo's existing release cadence (CHANGELOG-as-version-of-record) carries a noise-free entry if the repo's convention treats doc-only updates as version-noteworthy, or no entry at all if it treats them as trivia. Match the repo's existing convention; default to a `## Documentation` subsection in an upcoming unreleased CHANGELOG entry (creating one if no `[Unreleased]`-equivalent dated section currently exists), per the user's memory note "No commits under CHANGELOG Unreleased — move to dated versioned section + SemVer bump before committing."

Specifically: do **not** add an `[Unreleased]` section. Either append a `## Documentation` note to the most recent dated version entry already present (if the user's convention allows additive doc notes to a released version's CHANGELOG entry), or create a new dated PATCH-bumped CHANGELOG entry (e.g., `[0.1.1] - 2026-MM-DD`) for the doc addition. The repo's existing convention takes priority; state the choice in the PR.

## Scope
- `HoneyDrunk.Audit/README.md` — extend with a `## Rate-Limit Event Catalog` section (or a new `docs/event-catalog.md` if the repo prefers a sub-page; match the repo's existing convention), documenting the canonical event-name + field shape for `RateLimitRejected` and `QuotaOverageBilled`.
- `HoneyDrunk.Audit/CHANGELOG.md` — record the documentation addition. Either append to the most recent dated entry as a `## Documentation` subsection if the convention allows, or create a new dated PATCH-bumped entry (e.g., `[0.1.1] - 2026-MM-DD`). Do **not** introduce an `[Unreleased]` line.
- No `.csproj` edits. No code change. No version bump beyond the optional PATCH-for-docs.

## Proposed Implementation
1. Open `HoneyDrunk.Audit/README.md`. Append a new section after the existing `## Redaction` section (the README is brief — adding the catalog inline is the lightest option). If the executor judges this section to be more than ~80 lines of net new content, lift it into `docs/event-catalog.md` and add a link from README; otherwise inline it.
2. The section documents two canonical event-names. Use the exact text below (substance-verbatim — match exactly so future-Audit-repo readers find one canonical source):

   ```
   ## Rate-Limit Event Catalog

   The Grid emits two canonical audit event-types from the rate-limiter substrate (ADR-0067 D10). Both ride the existing `AuditEntry.EventName` field; no new contract is required. Producers (Notify Cloud at GA per ADR-0067; any future Node that opts into rate-limit / quota auditing) must emit these names verbatim so forensic queries find them.

   ### `RateLimitRejected`

   Emitted on every hard 429 — a rate-limit rejection (burst / sustained / daily-quota / monthly-quota for Free tier or any hard-ceiling tier).

   - **Category:** `AuditCategory.Security` (the 429 is the Grid's enforcement against an abuse-shaped pattern, even when the cause is legitimate over-limit usage).
   - **Outcome:** `AuditOutcome.Denied`.
   - **Actor:** the tenant identifier when authenticated; `"anonymous"` for unauthenticated endpoints.
   - **Target:** the endpoint route.
   - **TenantId:** the resolved `TenantId` (authenticated) or `TenantId.Internal`-sentinel-equivalent (anonymous — never `TenantId.Internal` itself; use a reserved-anonymous tenant value per the API-key-store contract).
   - **Metadata fields** (in the `Metadata` dictionary, lower-case keys):
     - `limit_type` — one of `"burst"`, `"sustained"`, `"daily-quota"`, `"monthly-quota"`.
     - `tier` — `"free"` / `"pro"` / `"scale"` for authenticated; `"anonymous"` for unauthenticated.
     - `retry_after_seconds` — the advisory retry window (integer-as-string for the metadata dictionary).
     - `endpoint` — the endpoint route (also present in `Target` but duplicated here for query convenience).

   No secret value is recorded. API-key full values are never present; the 8-character display prefix is allowed if the limiter keyed on it (the pre-auth-API-key-validation case per ADR-0067 D5).

   ### `QuotaOverageBilled`

   Emitted for Pro/Scale tenants whose monthly quota was exceeded **and** the overage is billable (the request proceeded; the Stripe meter was incremented per ADR-0037 D2). Marks the transition from in-quota to overage-billed for forensic and billing-reconciliation purposes.

   - **Category:** `AuditCategory.SystemAction` (billing-related transition is a system action, not a user-facing decision).
   - **Outcome:** `AuditOutcome.Succeeded` (the request succeeded; the billing meter was incremented).
   - **Actor:** the tenant identifier.
   - **Target:** the endpoint route.
   - **TenantId:** the resolved `TenantId`.
   - **Metadata fields:**
     - `quota_window` — `"monthly"` (extensible to `"daily"` if a daily-billable quota is ever introduced; ADR-0067 D3 has none at GA).
     - `quota_ceiling` — the tier ceiling that was exceeded (integer-as-string).
     - `quota_usage` — the post-increment usage count (integer-as-string).
     - `tier` — `"pro"` / `"scale"` (Free tier hard-429s on quota overage and emits `RateLimitRejected`, not this event).
     - `endpoint` — the endpoint route.
     - `billing_meter_id` — the Stripe meter identifier per ADR-0037 D2 (non-secret operator-visible string).

   No secret value is recorded. Stripe API keys, webhook signing secrets, and other ADR-0037 secrets are never present.

   ## Cross-references

   - **ADR-0067 D10** — rate-limit audit emit contract.
   - **ADR-0030** — audit substrate, WORM-by-interface stance, durable channel.
   - **ADR-0037 D2** — Stripe meter overage billing pipe.
   - **Invariant 8** — secret values never appear in audit entries.
   ```

   Adjust prose to match the repo's existing tone if the README's style differs noticeably; preserve the canonical event-name strings, field names, and category/outcome assignments verbatim.
3. Update `HoneyDrunk.Audit/CHANGELOG.md`. Two options per the repo's convention:
   - **Option A** — if doc-only additions are acceptable as an additive note on the most recent dated version entry, append a `## Documentation` subsection to that entry recording "Added Rate-Limit Event Catalog documenting `RateLimitRejected` and `QuotaOverageBilled` canonical event-names per ADR-0067 D10."
   - **Option B** — create a new dated PATCH-bumped entry (e.g., `[0.1.1] - 2026-MM-DD`) with the same note. Bump `Directory.Build.props` (or the per-`.csproj` `<Version>` if that is the repo's convention) to `0.1.1` accordingly.
   - Do **not** use `[Unreleased]`. State the chosen option in the PR.
4. Update repo-level `README.md` if needed to link to the new section (the existing README is short enough that the section appears in the same file; if the section is lifted to `docs/event-catalog.md`, add a `## Documentation` link in the README).

## Affected Files
- `HoneyDrunk.Audit/README.md` (the canonical event-catalog section appended).
- `HoneyDrunk.Audit/CHANGELOG.md` (the documentation note).
- Optionally `HoneyDrunk.Audit/docs/event-catalog.md` if the executor lifts the section out of README.
- Optionally `HoneyDrunk.Audit/Directory.Build.props` if Option B is chosen for the CHANGELOG bump.

## NuGet Dependencies
None. This packet touches only Markdown documentation and possibly a single `<Version>` bump.

## Boundary Check
- [x] All edits in `HoneyDrunk.Audit`. Routing rule "audit, AuditLog, audit substrate → HoneyDrunk.Audit" maps exactly.
- [x] No contract change to `IAuditLog` / `IAuditQuery` / `AuditEntry` / `AuditCategory` — the rate-limit event-types ride the existing `EventName` free-string field.
- [x] No new abstraction. No new code. Documentation-only registration of two canonical event-names per ADR-0067 D10.
- [x] No `AuditCategory` enum value added — the two events map to existing categories (`Security` and `SystemAction`).

## Acceptance Criteria
- [ ] `HoneyDrunk.Audit/README.md` (or `docs/event-catalog.md`) carries a Rate-Limit Event Catalog section
- [ ] `RateLimitRejected` is documented with category `Security`, outcome `Denied`, the metadata-field set (`limit_type`, `tier`, `retry_after_seconds`, `endpoint`), and the no-secret-values guarantee
- [ ] `QuotaOverageBilled` is documented with category `SystemAction`, outcome `Succeeded`, the metadata-field set (`quota_window`, `quota_ceiling`, `quota_usage`, `tier`, `endpoint`, `billing_meter_id`), and the no-secret-values guarantee
- [ ] Cross-references to ADR-0067 D10, ADR-0030, ADR-0037 D2, and invariant 8 are present
- [ ] `HoneyDrunk.Audit/CHANGELOG.md` records the documentation addition under a dated version section (either appended to an existing dated entry as a `## Documentation` subsection, or a new dated PATCH-bumped entry); `[Unreleased]` is NOT used
- [ ] No code change in any `.cs` file
- [ ] No `IAuditLog` / `AuditEntry` / `AuditCategory` contract change
- [ ] `Directory.Build.props` / `<Version>` is bumped only if Option B is chosen and only by PATCH (0.1.0 → 0.1.1)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0067 D10 — Audit emission.** "Every **hard** 429 (rate limit or hard-quota overage) emits a `RateLimitRejected` audit event with fields: `tenant_id` (or `null` for anonymous), `endpoint`, `limit_type` (`burst` / `sustained` / `daily-quota` / `monthly-quota`), `tier`, `retry_after_seconds`, `correlation_id`. Captured durably per ADR-0030's WORM-by-interface stance. Quota-overage **billable** events (Pro/Scale tenants over their monthly quota) emit `QuotaOverageBilled` instead of `RateLimitRejected` — the request proceeded, the billing meter was incremented, and the audit record captures the transition. Audit is emitted via the Notify Cloud `ITenantRateLimitPolicy` implementation (or the equivalent per-Node implementation). The middleware does not emit Audit directly — the policy is the auditor, the middleware is the enforcer."

**ADR-0030 (referenced) — Audit substrate.** Phase-1 stance is append-only-by-interface; the `IAuditLog.AppendAsync(AuditEntry)` contract is the durable channel. Event-name discipline is enforced by documentation in Phase 1 (no typed registry).

**ADR-0037 D2 (referenced) — Stripe meter overage.** Pro/Scale tenants over their monthly quota are billed via the Stripe meter overage pipe; the request proceeds; a `BillingEvent` is emitted with the overage marker; Stripe handles the metered pricing. `QuotaOverageBilled` audit-records the transition.

**Invariant 8 — Secret values never appear in logs, traces, or audit entries.** Full API keys, Stripe API keys, webhook signing secrets, and any other secret material must never appear in the audit entries documented here. API-key display prefixes (8-character non-secret per the API-key-store contract Notify Cloud commits in ADR-0027) are permitted.

## Constraints
- **No code change.** This packet only documents canonical event-names; no contract or runtime change.
- **No `AuditCategory` enum modification.** Both events map to existing categories — `RateLimitRejected` → `Security`; `QuotaOverageBilled` → `SystemAction`.
- **No `[Unreleased]` CHANGELOG.** Per the user's standing convention, move directly to a dated version section. PATCH-bump or append-to-most-recent-dated-entry per the repo's existing convention.
- **No secret values in any documented event.** Invariant 8 applies to audit entries; the catalog explicitly states this.
- **Notify Cloud is the first emitter, not this packet.** This packet documents the shape; Notify Cloud (when it stands up per ADR-0027 + the deferred follow-up packet 05 of this initiative) is the first Node that actually emits these events. No emit-side code lands here.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0067`, `wave-3`

## Agent Handoff

**Objective:** Document the canonical shape of the `RateLimitRejected` and `QuotaOverageBilled` audit event-types in the `HoneyDrunk.Audit` repo, so Notify Cloud (and any future Node) emits the right entries.

**Target:** `HoneyDrunk.Audit`, branch from `main`.

**Context:**
- Goal: Pin the canonical event-name + field-shape for the two ADR-0067 D10 audit events. No code change; documentation-only registration in the Audit repo.
- Feature: ADR-0067 Inbound Rate Limiting and Quota Enforcement rollout, Wave 3.
- ADRs: ADR-0067 D10 (primary), ADR-0030 (audit substrate, referenced), ADR-0037 D2 (Stripe meter overage, referenced).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0067 should be Accepted before its event-types are documented as canonical.

**Constraints:**
- No code change. No new `AuditCategory` value. No new abstraction.
- Both events ride the existing `AuditEntry.EventName` free-string field — no contract change.
- `[Unreleased]` is forbidden in `CHANGELOG.md`; use a dated version section.
- No secret material in any documented field; invariant 8 applies.

**Key Files:**
- `HoneyDrunk.Audit/README.md` (or `docs/event-catalog.md`) — the new Rate-Limit Event Catalog section.
- `HoneyDrunk.Audit/CHANGELOG.md` — documentation entry under a dated version.

**Contracts:** None changed. `IAuditLog` / `IAuditQuery` / `AuditEntry` are unchanged.
