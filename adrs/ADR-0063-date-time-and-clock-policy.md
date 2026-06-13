# ADR-0063: Grid-Wide Date, Time, and Clock Policy

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up work items (do not accept and leave the catalogs stale):

- [ ] Add `AddSystemTimeProvider()` and `AddFakeTimeProvider()` DI registration extension methods to `HoneyDrunk.Kernel` (production wires `TimeProvider.System`; test fixtures wire `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`)
- [ ] Update [`repos/HoneyDrunk.Kernel/boundaries.md`](../repos/HoneyDrunk.Kernel/boundaries.md) to record the date/time policy ownership — Kernel is the home for the DI registration helpers, but no Kernel-owned interface wraps `TimeProvider` (it is a BCL type)
- [ ] Update [`repos/HoneyDrunk.Kernel/overview.md`](../repos/HoneyDrunk.Kernel/overview.md) to add a "Date and Time" section pointing at this ADR
- [ ] Update [`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) to add a "Date and Time" row referencing `TimeProvider` (production) and `Microsoft.Extensions.TimeProvider.Testing` (tests)
- [ ] Update [`adrs/ADR-0047-testing-patterns-and-tooling.md`](./ADR-0047-testing-patterns-and-tooling.md) cascade — the testing-pattern doc and the test-project templates should reference `FakeTimeProvider` as the committed test substrate for time-dependent code
- [ ] Update [`adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md`](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) serialization section (D-series covering envelope / payload shape) to pin ISO 8601 with `Z` for instants, `YYYY-MM-DD` for dates, and ISO 8601 duration strings for spans, consistent with D4 below — the cross-reference is one-way; this ADR pins the format, ADR-0057 governs the API surface
- [ ] Add a new analyzer rule (or extend `HoneyDrunk.Standards`) that flags `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, and `DateTimeOffset.Now` in non-test code, with an opt-out attribute for documented interop exceptions per D3
- [ ] Promote the relevant decisions (D1, D2, D3, D11) into numbered invariants once this ADR is Accepted — scope agent assigns invariant numbers in the same PR that flips Status
- [ ] Scope agent flips Status → Accepted after the analyzer rule lands and the DI helpers ship in Kernel

## Context

Time is not yet a Grid-level concern. Every Node currently reads "now" via `DateTimeOffset.UtcNow` or `DateTime.UtcNow` directly. Active in-flight packets — the audit emitter wiring in [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md), the idempotency lease handling in [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md), the Notify Cloud API key issuance in [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — already work around this by reaching for an injected `TimeProvider` in test paths while production paths call `DateTimeOffset.UtcNow` directly. The pattern is converging without a written rule, and the divergence between "what packets do" and "what production code does" is widening.

The forcing functions:

- **[ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) Tier-2b Testcontainers pilots** are about to hit "how do I make this deterministic" questions. Invariant 51 bans `Thread.Sleep` in test code, but the resolution — drive time via an injected fake clock — is not codified at the Grid level.
- **[ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md) idempotency TTLs**, **[ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) rotation deadlines**, audit timestamps per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md), [ADR-0013](./ADR-0013-communications-orchestration-layer.md) Communications cadence rules, and future Memory expirations all need a single "now" source. Ad-hoc `DateTimeOffset.UtcNow` calls scatter the time read across every Node, and every test that depends on time bottoms out at either `Thread.Sleep` (banned) or a one-off injected fake.
- **[ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md) Service Bus event timestamps** and **[ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) audit log timestamps** are emitted at the producer, must survive serialization, and must round-trip through downstream consumers without timezone drift. No ADR pins the on-wire format today.
- **[ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md)** governs public HTTP API shape but defers the serialization detail for instants/dates/durations to a future cross-cutting decision. This ADR is that cross-cutting decision.
- **The Communications drip-campaign and cadence-policy work** ([ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md)) is the next consumer to land cadence rules — cron strings, recurring intervals, business-hours windows — and they must read the clock through a substrate that tests can fake.
- **[ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md)** (Proposed, paired with this ADR) pins the cron-string format and depends on this ADR's `TimeProvider` decision for the "what clock does the cron evaluator read" question.

This ADR settles date/time handling **broadly**: storage format, time zone discipline, .NET type usage, serialization shape, cadence specification format, and the test substrate. It is intentionally not scoped only to a "TimeProvider abstraction" decision — the substrate is one piece; the broader policy is what stops every Node from reinventing the wheel.

## Decision

### D1 — `TimeProvider` is the Grid-wide clock abstraction

Every Node reads "now" via [`System.TimeProvider.GetUtcNow()`](https://learn.microsoft.com/en-us/dotnet/api/system.timeprovider). Direct calls to `DateTimeOffset.UtcNow`, `DateTimeOffset.Now`, `DateTime.UtcNow`, and `DateTime.Now` are **forbidden** in production code.

`TimeProvider` is a .NET 8+ BCL type. It is not a HoneyDrunk-owned interface — Kernel does not wrap it, does not re-export it, does not provide a `IGridClock` shim. The platform abstraction is sufficient; layering a Grid-specific interface on top would be ceremony without value.

Production composition wires `TimeProvider.System`. Test composition wires `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`. The DI registration helpers (`AddSystemTimeProvider()` for production hosts, `AddFakeTimeProvider()` for test fixtures) live in `HoneyDrunk.Kernel` per D11.

The exceptions (documented; opt-out attribute on the analyzer rule):

- Interop with libraries that demand `DateTime` or `DateTime.UtcNow` directly (e.g., a third-party SDK whose entry point computes its own timestamps). The interop layer is the boundary; everything inside the Grid reads through `TimeProvider`.
- Truly process-startup-time concerns where DI is not yet available (the host's bootstrap log line). These are bounded by the host startup; once DI is up, the rule applies.

### D2 — UTC at rest, everywhere

All persisted timestamps are UTC. Database columns store UTC. Service Bus message timestamps are UTC. Audit records are UTC. Cache TTL boundaries are UTC. Idempotency record expiry instants are UTC. Configuration timestamps are UTC.

No Node stores a local-time timestamp. No Node stores a timezone offset alongside a "local instant" and expects downstream code to interpret it. The on-disk and on-wire format is the UTC instant; conversion to a user's or tenant's display timezone happens at the **presentation boundary** (HTTP response serialization for a user-facing surface, or report rendering for an audit export), never before.

The justification: every cross-Node hop, every audit query, every billing event, every cadence evaluation reads timestamps. If any of them apply a timezone conversion in transit, the conversion compounds and the round-trip is no longer identity. UTC at rest is the discipline that keeps the round-trip clean.

### D3 — Type usage policy

| .NET type | Use for | Banned for new code? |
|-----------|---------|---------------------|
| `DateTimeOffset` | Instants (anything with a real, timezone-relevant moment in time) | No — preferred |
| `DateOnly` | Calendar dates (birthdays, billing periods, invoice dates) | No — preferred for dates without a time component |
| `TimeOnly` | Wall-clock times (business-hours windows, daily cutoff times) | No — preferred for times without a date component |
| `TimeSpan` | Durations (TTLs, retry backoff intervals, delays) | No — preferred |
| `DateTime` | Legacy interop only | **Yes — banned in new code** |

`DateTime` is banned because it carries no offset and its `Kind` (`Local`, `Utc`, `Unspecified`) is a runtime property that has historically been the source of timezone bugs across the .NET ecosystem. `DateTimeOffset` is the strict replacement for instants.

The analyzer rule (per the follow-up checklist) flags `DateTime` usage in non-test code. The opt-out attribute permits documented interop cases (third-party SDK that demands `DateTime`); the rule applies everywhere else.

### D4 — ISO 8601 with `Z` for serialization

The on-wire formats for date/time-shaped values:

| Shape | Format | Example |
|-------|--------|---------|
| Instant (`DateTimeOffset`) | ISO 8601 with `Z` suffix | `"2026-05-23T14:30:00Z"` |
| Calendar date (`DateOnly`) | ISO 8601 date | `"2026-05-23"` |
| Wall-clock time (`TimeOnly`) | ISO 8601 time | `"14:30:00"` |
| Duration (`TimeSpan`) | ISO 8601 duration | `"PT5M"`, `"PT1H30M"`, `"P1DT2H"` |

This format is pinned for:

- Web.Rest API request and response payloads (cross-references [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md))
- Service Bus message envelopes and user-properties (cross-references [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md))
- Audit record serialization (cross-references [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md))
- App Configuration values that carry timestamps or durations
- Any JSON document persisted in the Grid

The reasoning: ISO 8601 with `Z` is the unambiguous, lexically-sortable, timezone-correct representation. The `Z` suffix makes UTC explicit in the on-wire form so a downstream consumer reading the value cannot mistake it for a local-time string. ISO 8601 duration strings (`"PT5M"`) are similarly unambiguous and survive serialization in environments where `TimeSpan`-shaped values would otherwise need a custom converter.

### D5 — Time zone IDs use IANA, never Windows

When a Node persists or transmits a time zone identifier (tenant default timezone, user preference, business-hours window timezone), the value is an **IANA timezone string** — `"America/New_York"`, `"Europe/London"`, `"Asia/Tokyo"`.

Windows time-zone IDs (`"Eastern Standard Time"`, `"GMT Standard Time"`) are forbidden in stored or transmitted data. They are a Windows-platform convention; they do not survive cross-platform interop; they conflate "standard time" and "daylight time" in their names in ways that are correct for legacy reasons but confusing for everyone else.

.NET 10's `TimeZoneInfo` API supports both Windows and IANA identifiers transparently on the runtime side (so reading a stored IANA value works fine on Windows hosts). The storage format is pinned to IANA; the platform-level interop is the runtime's problem, not the Grid's.

Tenant default timezone and user timezone preference are stored as IANA strings. Conversion to a display timezone at the presentation boundary uses the runtime's `TimeZoneInfo.FindSystemTimeZoneById(ianaString)`.

### D6 — Cadence specification: cron strings (5-field, UTC) for recurring; ISO 8601 durations for delays

For Communications cadence rules ([ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md)), Notify retry schedules ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)), background jobs ([ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md)), and any other scheduled recurring work:

- **Recurring schedules** use a **5-field cron string in UTC**. Example: `"0 9 * * 1-5"` = 09:00 UTC, Monday through Friday. No 6-field (with seconds) variant; if sub-minute precision is required, that workload should not be a cron-scheduled job.
- **Delays and intervals** use **ISO 8601 duration strings**. Example: `"PT5M"` = 5-minute delay; `"P1D"` = 1-day interval.
- **Business-hours-relative cadence** ("send at 09:00 in the tenant's timezone, Monday–Friday") is encoded as a cron string in UTC paired with the tenant's IANA timezone string, evaluated at scheduling time. The cadence policy resolves the tenant's local 09:00 to a UTC instant using the stored IANA timezone; the scheduled job runs in UTC. The tenant timezone is read from tenant configuration, not the host machine's timezone.

The alternatives considered and rejected:

- **6-field cron with seconds.** Adds precision the Grid does not need; sub-minute recurring work belongs in `IHostedService` per [ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md), not in a cron-scheduled job.
- **Quartz-style cron with year and weekday-of-month tokens.** Capability the Grid does not have a workload for; reject until a real consumer pulls.
- **Polymorphic cadence spec (cron OR interval OR rate-limit envelope).** A single union type at the policy boundary that accepts any of three shapes was tempting; rejected because it pushes the union-type complexity into every consumer's switch statements. Two separate types (`CronExpression` for recurring, `TimeSpan` or ISO 8601 duration for delays) is cleaner and matches how schedulers actually consume the data.

### D7 — `FakeTimeProvider` is the test substrate

Tests that depend on time advance the fake clock; they never sleep, never wall-clock-poll, never insert `await Task.Delay()` to wait for a time-driven event.

The substrate is `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider` (the Microsoft.Extensions package, MIT-licensed, distributed via NuGet). The package is added to test projects via `Directory.Build.props` for the test-project template per [ADR-0047 D10](./ADR-0047-testing-patterns-and-tooling.md) (or its equivalent — the testing-pattern doc owns the template).

Test fixtures expose `FakeTimeProvider` so individual tests can:

- Call `Advance(TimeSpan)` to move time forward
- Call `SetUtcNow(DateTimeOffset)` to jump to a specific instant
- Assert on time-shifted observations after advancing the clock

The ban on `Thread.Sleep` ([Invariant 51](../constitution/invariants.md)) remains in force. `FakeTimeProvider.Advance` is the committed replacement everywhere a test would otherwise have inserted a sleep to wait for a TTL to expire, a retry window to elapse, or a cadence boundary to cross.

### D8 — Audit timestamps are read once at emit, never regenerated

Every audit record emitted per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) carries a `DateTimeOffset` UTC instant read from `TimeProvider.GetUtcNow()` at the **point of emit** (the call into `IAuditLog`). The Audit Node and any downstream consumers (forensic query surface, audit export, billing reconciliation) must **not** regenerate the timestamp.

The boundary: the emitter is the timestamp authority. Subsequent layers persist, query, and display the timestamp; they do not change it. The reasoning: a timestamp that drifts as it crosses Nodes is not a forensic record; it is a guess. Reading the timestamp once at emit and freezing it preserves the "who did what, when" guarantee that [Invariant 47](../constitution/invariants.md) commits.

### D9 — Idempotency TTL semantics

Per [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md), idempotency record expiry is computed from `TimeProvider.GetUtcNow()` **at write time**, stored as a UTC instant (`DateTimeOffset` in code, ISO 8601 with `Z` on the wire and at rest).

The TTL is an additive interval over the write-time instant:

```
expiryInstant = clock.GetUtcNow() + ttl
```

The expiry instant is stored. The TTL value itself is not stored (it is a configuration, not state). Re-reads compare the stored expiry instant against `clock.GetUtcNow()` at read time. This means tests that drive `FakeTimeProvider.Advance(ttl)` and re-read an idempotency record see it as expired — the standard test pattern across the ADR-0042 packet wave.

The InMemory idempotency store, the Cosmos idempotency store, and any future backing all observe this semantic. The store does not own a clock; it reads the consumer's injected `TimeProvider`.

### D10 — Gregorian assumed; non-Gregorian calendars out of scope

Every date in the Grid is Gregorian. Calendar arithmetic (`DateOnly.AddDays`, `DateOnly.AddMonths`) uses Gregorian semantics.

Internationalization for non-Gregorian calendars (Hijri, Hebrew, Japanese imperial, Buddhist, etc.) is **explicitly out of scope** for this ADR. If a product surface ever needs to display dates in a non-Gregorian calendar, that conversion happens at the presentation layer, the storage stays Gregorian, and a future ADR pins the per-surface convention.

This is a deliberate scope cap. Multi-calendar support is a real concern in some markets; it is not a concern the Grid has today, and committing the scope now without a real consumer would invent a contract that the first real consumer might find wrong.

### D11 — Where the contract lives — Kernel helpers, no Kernel interface

`TimeProvider` is a .NET 8+ BCL type. Kernel does **not** wrap it. Kernel does **not** publish `IGridClock` or `IClock` or any HoneyDrunk-owned interface that proxies `TimeProvider`. The platform-level abstraction is the contract; layering an additional interface on top is ceremony without value.

What Kernel **does** provide:

- **DI registration helpers** in `HoneyDrunk.Kernel`:
  - `services.AddSystemTimeProvider()` — registers `TimeProvider.System` as the singleton
  - `services.AddFakeTimeProvider(DateTimeOffset? initialInstant = null)` — registers `FakeTimeProvider`, exposes it on the service collection for test fixtures to retrieve and drive
- **Convention extension methods** on `DateTimeOffset` and `TimeSpan` where they earn their keep — for example, `clock.GetUtcNow().IsAfter(someInstant)` as a more readable equivalent of `clock.GetUtcNow() > someInstant` in cadence math. The extensions are convenience, not contract; consumers may use the raw comparison operators if they prefer.
- **A `CadenceMath` static helper** (if it earns its keep) for the cron-string → next-occurrence math used by [ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md). Concrete shape is deferred to the first feature packet that consumes it; the boundary is "Kernel owns the helper, consuming Nodes call it."

The naming convention: `CadenceMath` is a record-style static helper, not an interface; no `I` prefix (per the Grid-wide naming rule).

### D12 — Migration path for existing code

Every Node in the Grid currently uses `DateTimeOffset.UtcNow` directly in production paths. The migration is per-Node, packet-driven, and scoped:

- **New code** (anything landing after this ADR is Accepted) reads `TimeProvider.GetUtcNow()`. No grace period; the analyzer rule fails the build.
- **Existing code** is migrated opportunistically. When a packet touches a code path that reads `DateTimeOffset.UtcNow`, that read is converted to `TimeProvider.GetUtcNow()` in the same packet. No bulk-migration packet is filed; the burden is amortized across the natural touch points.
- **Tests that currently fake time via per-test custom shims** migrate to `FakeTimeProvider` when the surrounding test is touched. Tests that don't depend on time are left alone.

The analyzer rule has a configurable severity: at first introduction it ships as a **warning**; once the bulk of touched code paths have migrated (judged by the user, no metric committed), it flips to **error**. This is the same migration discipline applied to other Grid-wide analyzer rules.

## Consequences

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] DI registration helpers (`AddSystemTimeProvider`, `AddFakeTimeProvider`) ship in `HoneyDrunk.Kernel`
- [ ] Analyzer rule flagging direct `DateTime.UtcNow` / `DateTimeOffset.UtcNow` reads in non-test code ships (warning severity initially)
- [ ] `Microsoft.Extensions.TimeProvider.Testing` is added to the test-project template (per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D10 / Directory.Build.props)
- [ ] `repos/HoneyDrunk.Kernel/overview.md` and `boundaries.md` reflect the date/time policy ownership
- [ ] `infrastructure/reference/tech-stack.md` has a date/time row
- [ ] Cross-references in [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md), [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md), and [ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md) are in place
- [ ] Scope agent flips Status → Accepted

### Unblocks

Accepting this ADR unblocks the following:

- **[ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md) cron-format pin.** ADR-0068 D5 references this ADR's D6 for the cron format. Without this ADR Accepted, ADR-0068 cannot pin the format.
- **Communications cadence rules** ([ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md)). The cadence policy reads cron strings under D6 and the clock under D1.
- **Notify Cloud retry scheduling** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)). Retry backoff uses ISO 8601 durations per D6; the retry trigger time is computed via `TimeProvider` per D1.
- **Tier-2b Testcontainers deterministic tests** ([ADR-0047](./ADR-0047-testing-patterns-and-tooling.md)). Integration tests that depend on time advance `FakeTimeProvider`; container-resident services that read their own wall clock are bounded by the test's time-window assertions, not the host's clock state.
- **Audit forensic query reliability** ([ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)). The "who did what, when" guarantee per [Invariant 47](../constitution/invariants.md) is sharpened by D8 — the emit-time timestamp is authoritative.

### New invariants (proposed; scope agent assigns numbers at acceptance)

- **Production code reads time via `TimeProvider`.** Direct calls to `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, or `DateTimeOffset.Now` are forbidden outside documented interop boundaries. Enforced by analyzer rule.
- **All persisted and transmitted timestamps are UTC.** Local-time storage and local-time on-wire formats are forbidden.
- **`DateTime` is banned in new code.** `DateTimeOffset`, `DateOnly`, `TimeOnly`, and `TimeSpan` are the committed types. Exceptions for interop are opt-in via analyzer attribute.
- **Tests that depend on time advance `FakeTimeProvider`.** `Thread.Sleep` is already banned by [Invariant 51](../constitution/invariants.md); `Task.Delay` as a "wait for time-driven event" pattern is also banned in test code (it is not a fake — it is real wall-clock wait).
- **Stored time-zone identifiers are IANA.** Windows TZ ID storage is forbidden.

### Catalog obligations

- `catalogs/nodes.json` — no entry to add. This ADR adds no Node.
- `catalogs/contracts.json` — no entry to add. This ADR commits no HoneyDrunk-owned contract (it commits to using the BCL's `TimeProvider`).
- `constitution/invariants.md` — append the new invariants listed above with sequential numbers assigned at acceptance.
- `infrastructure/reference/tech-stack.md` — add a date/time row.

### Negative

- **Analyzer warnings will fire across the entire existing codebase on day one.** Every Node currently calls `DateTimeOffset.UtcNow` directly in production paths. The first day after this ADR's analyzer rule lands will produce many warnings. Mitigation: ship the rule at warning severity initially per D12; flip to error after the natural touch points have migrated.
- **`Microsoft.Extensions.TimeProvider.Testing` is a Microsoft NuGet package and adds a test-project dependency.** It is MIT-licensed and stewardship is Microsoft; the trust posture is good. The dependency itself is small. Acceptable cost.
- **Cron-string format pinned to 5-field UTC removes some expressiveness.** Workloads that need sub-minute precision or weekday-of-month semantics cannot use cron at all and must use `IHostedService` (per [ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md) D2) or a future cadence-rule extension. Acceptable trade-off; the Grid does not have a workload today that needs the expressiveness.
- **No `IGridClock` interface means consumers that wanted to mock at the `IGridClock` seam must mock `TimeProvider` directly.** `TimeProvider` is mockable (it is abstract on Microsoft's side and `FakeTimeProvider` is the committed test seam); the "we own our own interface" preference does not earn its keep against a perfectly serviceable BCL primitive.
- **IANA-only time zone storage is a constraint at tenant ingestion.** Tenants that hand the Grid a Windows TZ ID via API must have it translated to IANA at the intake boundary. The translation is well-defined (.NET 10 supports both at the runtime side); the discipline is a one-time intake step.

## Alternatives Considered

### Wrap `TimeProvider` in a HoneyDrunk-owned `IGridClock` interface

Considered. The argument: every other Grid substrate (`ISecretStore`, `ICacheStore<T>`, `IAuditLog`, `ITransportPublisher`) is a HoneyDrunk-owned interface; the clock should be too.

Rejected per D1 and D11. `TimeProvider` is a BCL primitive whose API surface is exactly what the Grid needs (`GetUtcNow()`, `CreateTimer`, `GetTimestamp`). Wrapping it would add a HoneyDrunk-flavoured interface that proxies one-to-one calls into `TimeProvider`. The wrapping earns nothing — there is no additional concern (telemetry, retries, tenant scoping) the wrapper would introduce. The Grid's coupling rule is "abstract where the abstraction earns its keep"; here the BCL has already done the abstracting.

### Allow `DateTime` for new code with a strict UTC-Kind convention

Considered. The argument: `DateTime.UtcNow` is shorter; if everyone agrees to use `Kind = Utc`, the offset problem is solved.

Rejected per D3. The Kind-discipline approach has been tried at .NET-ecosystem scale and has not held. The historical record is unambiguous: `DateTime` with a "convention-enforced Kind" is the source of more timezone bugs than `DateTime` itself. `DateTimeOffset` carries the offset in its type; the offset cannot be silently lost. The cost of the longer name is a flat 13 characters; the cost of timezone bugs is unbounded.

### Pin epoch-second `long` timestamps for serialization (Unix time)

Considered. The argument: epoch seconds (or epoch milliseconds) are unambiguous, sort lexically as integers, and survive every serializer without a converter.

Rejected per D4. The trade-off is debuggability. A human reading a Service Bus message envelope or an audit record cannot tell `1716470400` is "May 23, 2024 12:00:00 UTC" without converting it; the same human reading `"2026-05-23T14:30:00Z"` knows immediately. The Grid's operational legibility premium (debuggable, browser-explorable, copy-pasteable into a query) wins over the (small) serialization simplification. Internal storage formats may still use epoch seconds where the persistence layer favors it (e.g., a database `bigint` column); the on-wire format stays ISO 8601 with `Z`.

### Allow Windows TZ IDs alongside IANA

Considered. The argument: .NET 10's `TimeZoneInfo` resolves both; storing the user's input as-is and converting at read time would be the most user-friendly approach.

Rejected per D5. The user-friendly version of the input handling lives at the intake boundary (convert Windows → IANA on incoming API requests; reject on storage); the storage format itself must be one shape. Storing whichever shape the user supplied creates an N×2 query surface where every read has to normalize. IANA-only storage is the simpler discipline; intake conversion is the friendly part.

### Use NodaTime instead of BCL date/time types

Considered. The argument: NodaTime is the .NET community's "correct" date/time library — `Instant`, `LocalDate`, `ZonedDateTime`, `Duration` — and the design is cleaner than the BCL's accidental history.

Rejected. NodaTime is excellent for products whose domain is "calendaring is the core feature" (Stripe-style billing periods, multi-calendar internationalization, complex business-hours arithmetic). The Grid's domain is "we read 'now' a lot and persist instants"; the BCL's `DateTimeOffset`/`DateOnly`/`TimeOnly`/`TimeSpan` quartet is sufficient for that. Adopting NodaTime would mean every consumer Node takes a NodaTime dependency, every API surface translates between NodaTime and BCL types at the boundary, every test fixture mocks NodaTime's `IClock` instead of `TimeProvider`. The cost compounds; the benefit is not real for the Grid's actual workload.

### Defer the date/time policy until the first cadence-rule packet needs it

Considered. The argument: this ADR is "broad" — it pins decisions for serialization, type usage, time zones, cron format, and the clock substrate all at once. Maybe each could land in its own ADR when its first consumer needs it.

Rejected. The forcing function is not the first consumer of any single sub-decision — it is the **convergence** of forcing functions across multiple in-flight packets ([ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md), [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md), [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md), [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md), [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md), [ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md)) all reaching for the same sub-decisions in slightly different ways. Filing one broad ADR that resolves them in lockstep is the dispatch-efficient move. Splitting into N narrow ADRs would mean each in-flight packet re-litigates the sub-decision it touches.

### Pin a 6-field cron format (with seconds)

Considered. The argument: some scheduling backends (Quartz, Hangfire) support sub-minute precision via a seconds field; allowing it leaves a door open.

Rejected per D6. The Grid does not have a workload today that needs sub-minute precision. Workloads that *do* need it (a future heartbeat emitter, a polling probe) belong in `IHostedService` per [ADR-0068](./ADR-0068-background-job-and-recurring-work-substrate.md) D2, not in a cron-scheduled job. The 5-field convention is what every operator already knows; pinning 6-field invites operator confusion ("is the first field seconds or minutes?") for no concrete benefit.

### Use `Stopwatch` or `Environment.TickCount` for elapsed-time measurements instead of `TimeProvider`

Considered. The argument: elapsed-time measurements (how long did this operation take) are a different concern from "what wall-clock instant did this happen at"; `Stopwatch` is the correct tool for the former.

**Not rejected — clarified.** This ADR governs wall-clock reads (`GetUtcNow()`) and time-driven decisions (TTLs, cadence, retries). Elapsed-time measurements for telemetry purposes (`Stopwatch`, `Environment.TickCount`) are out of scope; they are a Pulse/observability concern and the existing usage stands. The analyzer rule per D12 does not flag `Stopwatch` usage.
