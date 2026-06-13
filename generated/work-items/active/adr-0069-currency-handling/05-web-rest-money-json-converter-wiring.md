---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["feature", "tier-2", "core", "adr-0069", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0069", "ADR-0057"]
wave: 3
initiative: adr-0069-currency-handling
node: honeydrunk-web-rest
---

# Wire the MoneyJsonConverter into Web.Rest default JSON options and pin a canary

## Summary
Register the `MoneyJsonConverter` (shipped by packet 02 in `HoneyDrunk.Kernel` runtime — **not** Abstractions) into `HoneyDrunk.Web.Rest`'s default JSON serializer options via the existing `HoneyDrunk.Web.Rest.AspNetCore.Serialization.JsonOptionsDefaults.Configure` seam, and add a canary that round-trips a `Money` payload to assert ADR-0069 D9's shape (`{"amount": "string", "currency": "ISO"}`). The packet is forward-compatibility wiring against `HoneyDrunk.Kernel` so every future Web.Rest endpoint surfacing a price uses the canonical shape by construction, and locks the SDK-side parsing target ADR-0057 D8/D14-equivalent commits.

**Seam exists today.** `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs` already exposes `static void Configure(JsonSerializerOptions options)` that consumers call. The converter registration lands as one line inside `Configure`. No new seam needed; no "deferred" branch.

## Context
ADR-0069 D9 commits the JSON shape for `Money`: `{"amount": "123.45", "currency": "USD"}`, with `amount` as a JSON string and `currency` as uppercase ISO 4217 alpha-3. The `MoneyJsonConverter` ships in `HoneyDrunk.Kernel` (runtime package, per packet 02 — **not** `HoneyDrunk.Kernel.Abstractions`; invariant 1 keeps Abstractions free of runtime classes). `Money` carries **no** `[JsonConverter]` attribute (attribute placement would force the converter into Abstractions). Explicit registration in every consumer's `JsonSerializerOptions` is therefore **required** for `Money` payloads to serialize/deserialize via the D9 shape. Web.Rest is the first such consumer.

ADR-0057 (Public HTTP API Versioning and Client SDK Strategy) D8 / D14-equivalent commits the canonical SDK-side parsing target for monetary values — the JSON shape ADR-0069 D9 commits is exactly that target. Web.Rest is the layer where the Grid serves HTTP traffic, so it is the right place to:

1. Register the converter in the centralized `JsonOptionsDefaults.Configure` seam so every Web.Rest serializer call (including consumer SDK clients that use Web.Rest's defaults) picks up the D9 shape.
2. Pin the shape with a canary (round-trip assertion).

The catalog packet (01) already added `Money` to `consumes_detail["honeydrunk-kernel"]` for `honeydrunk-web-rest`, anticipating this wiring.

**Cross-Node version dependency.** This packet builds against the new `Money`/`CurrencyCode` surface shipped by packet 02 in `HoneyDrunk.Kernel`. The package reaches the NuGet feed only after a human tags/releases the `HoneyDrunk.Kernel` solution version. Same Human Prerequisite as packet 03.

`HoneyDrunk.Web.Rest` is at v0.5.0 (per the csproj files). This packet is the first packet on the Web.Rest solution in this initiative — per invariant 27 it bumps every non-test `.csproj` in the solution to the same new minor version. The functional change is small (one converter-registration line in `JsonOptionsDefaults.Configure` plus a canary), so the bump is minor (the safer default for any new public-API-shape commitment — every `JsonOptionsDefaults.SerializerOptions` consumer now picks up the converter).

## Scope
- `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs` — register `MoneyJsonConverter` in the existing `Configure(JsonSerializerOptions options)` method by appending `options.Converters.Add(new MoneyJsonConverter());`. This is the production seam already in use across the codebase (`JsonOptionsDefaults.SerializerOptions` is consumed by every error-response serializer, controller, and SDK client).
- `HoneyDrunk.Web.Rest.AspNetCore/HoneyDrunk.Web.Rest.AspNetCore.csproj` — add `<PackageReference Include="HoneyDrunk.Kernel" Version="X.Y.Z" />` (the runtime package — the converter lives in `HoneyDrunk.Kernel`, not `HoneyDrunk.Kernel.Abstractions`) where `X.Y.Z` is the version shipped by packet 02. Web.Rest already takes a runtime dependency on the Kernel runtime is fine (Web.Rest is downstream of Kernel in the DAG).
- `HoneyDrunk.Web.Rest.Canary/` (or equivalent canary project — confirm the canary project name at edit time) — add a canary that constructs a `Money(123.45m, CurrencyCode.Usd)`, serializes it to JSON via `JsonOptionsDefaults.SerializerOptions`, asserts the result is exactly `{"amount":"123.45","currency":"USD"}`, deserializes it back, and asserts the round-trip preserves the value. Add a negative-case canary that constructs JSON with `amount` as a number (`{"amount":123.45,"currency":"USD"}`) and asserts it fails to deserialize (D9's amount-as-string discipline).
- All non-test `.csproj` files in the solution version-bumped together (invariant 27).
- `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` gets an entry (real change — the `JsonOptionsDefaults` seam now registers `MoneyJsonConverter`). The other packages (alignment bumps only) get no per-package CHANGELOG entry (invariant 12).
- Repo-level `CHANGELOG.md` gets a new version entry.

## Proposed Implementation
1. **Add the Kernel runtime reference** to `HoneyDrunk.Web.Rest.AspNetCore.csproj`: `<PackageReference Include="HoneyDrunk.Kernel" Version="X.Y.Z" />` at the version packet 02 shipped. (If the project already references Kernel for other reasons, just bump to the new version.) Confirm the released Kernel version is on the feed first (Human Prerequisite).
2. **Edit `JsonOptionsDefaults.Configure`** in `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs` — append one line: `options.Converters.Add(new MoneyJsonConverter());`. Place it after the existing `JsonStringEnumConverter` line so the converter list ordering stays stable. Add the `using HoneyDrunk.Kernel.Serialization;` (or whatever namespace `MoneyJsonConverter` lives in per packet 02) at the top of the file.
3. **Add the round-trip canary.** In the canary project, write a test that:
   - Constructs `var money = new Money(123.45m, CurrencyCode.Usd);` (or `Money.Usd(123.45m)`).
   - Serializes via `JsonSerializer.Serialize(money, JsonOptionsDefaults.SerializerOptions)`.
   - Asserts the JSON output equals `{"amount":"123.45","currency":"USD"}` (modulo whitespace).
   - Deserializes the JSON back via `JsonSerializer.Deserialize<Money>(json, JsonOptionsDefaults.SerializerOptions)` and asserts the result equals the original `money`.
4. **Add the amount-as-number negative canary.** Construct a hand-built JSON string `{"amount":123.45,"currency":"USD"}` and assert that `JsonSerializer.Deserialize<Money>(..., JsonOptionsDefaults.SerializerOptions)` throws `JsonException` (D9: `amount` must always be a JSON string, never a number).
5. **Bump versions.** Every non-test `.csproj` in `HoneyDrunk.Web.Rest.slnx` moves to the same new minor version (invariant 27). `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` describes the converter registration. Other packages: alignment bumps only, no per-package CHANGELOG (invariant 12).
6. **README.** Update `HoneyDrunk.Web.Rest.AspNetCore/README.md` (or wherever the public-API surface is documented) to note that `Money` payloads serialize via the canonical D9 shape automatically by virtue of the `JsonOptionsDefaults` registration.

## Affected Files
- `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs` — append one converter registration line inside `Configure`; add the `using HoneyDrunk.Kernel.Serialization;` import.
- `HoneyDrunk.Web.Rest.AspNetCore/HoneyDrunk.Web.Rest.AspNetCore.csproj` — `HoneyDrunk.Kernel` (runtime) `PackageReference` + version bump.
- `HoneyDrunk.Web.Rest.Canary/` — round-trip canary + amount-as-number negative canary.
- Every other non-test `.csproj` in `HoneyDrunk.Web.Rest.slnx` — alignment version bump.
- `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md`; repo-level `CHANGELOG.md`.
- `HoneyDrunk.Web.Rest.AspNetCore/README.md` — public-API note.

## NuGet Dependencies
- **New:** `HoneyDrunk.Kernel` `X.Y.Z` (the runtime package version shipped by packet 02) on `HoneyDrunk.Web.Rest.AspNetCore` — the runtime package is the right reference because `MoneyJsonConverter` lives there (invariant 1 keeps Abstractions free of runtime classes). `HoneyDrunk.Kernel.Abstractions` will come in transitively if it was not already referenced (`Money` and `CurrencyCode` are still in Abstractions). If a Web.Rest project's public DTO directly references `Money` or `CurrencyCode`, that project additionally takes a direct `PackageReference` on `HoneyDrunk.Kernel.Abstractions` (none today — wiring-only packet).
- No new test packages.

## Boundary Check
- [x] All edits in `HoneyDrunk.Web.Rest`. Routing rule "HTTP, REST, ASP.NET Core, JSON serialization → HoneyDrunk.Web.Rest" maps exactly.
- [x] The new HoneyDrunk dependency is `HoneyDrunk.Kernel` (runtime) — Web.Rest is downstream of Kernel in the DAG; runtime-to-runtime dependency is permitted (invariant 4).
- [x] No `Money`-bearing endpoint or DTO is added; the wiring is forward-compatible only.
- [x] No change to other Nodes; the SDK-shape commitment per ADR-0057 is honored by the converter shape ADR-0069 D9 already pinned in packet 02.

## Acceptance Criteria
- [ ] `HoneyDrunk.Web.Rest.AspNetCore` takes a `PackageReference` on `HoneyDrunk.Kernel` (runtime) at the version shipped by packet 02
- [ ] `MoneyJsonConverter` is registered in `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs`'s `Configure` method — one new `options.Converters.Add(new MoneyJsonConverter());` line, with the appropriate `using` import
- [ ] A round-trip canary asserts `Money(123.45m, CurrencyCode.Usd)` serializes to `{"amount":"123.45","currency":"USD"}` (via `JsonOptionsDefaults.SerializerOptions`) and round-trips back to the same value
- [ ] A negative canary asserts that `{"amount":123.45,"currency":"USD"}` (amount-as-number) fails to deserialize with `JsonException` — D9's amount-as-string discipline
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry dated to the merge, describing the Money converter wiring + canary
- [ ] `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` has an entry describing the converter registration
- [ ] Other packages (alignment bumps only) get NO per-package CHANGELOG entry (invariant 12)
- [ ] `HoneyDrunk.Web.Rest.AspNetCore/README.md` reflects the new JSON-options behavior
- [ ] No `Money`-bearing endpoint or DTO is added in this packet (forward-compatibility wiring only)
- [ ] The `pr-core.yml` tier-1 gate passes; the Web.Rest canary project's tests pass

## Human Prerequisites
- [ ] `HoneyDrunk.Kernel` solution at the version shipped by packet 02 must be tagged and released to the package feed before this packet's branch can compile. Agents merge code; humans tag/release. (Same prerequisite as packet 03.)

## Referenced ADR Decisions
**ADR-0069 D9 — JSON shape.** `{"amount": "123.45", "currency": "USD"}`. `amount` is a JSON string, never a number (precision preservation). `currency` is uppercase ISO 4217 alpha-3. The `MoneyJsonConverter` shipped by packet 02 (in `HoneyDrunk.Kernel` runtime — not Abstractions, per invariant 1) implements this shape. Because `Money` carries no `[JsonConverter]` attribute, explicit registration in every consumer's options is **required** — Web.Rest's `JsonOptionsDefaults.Configure` is the production registration site.

**ADR-0069 D1 (referenced) — `Money` is NOT annotated with `[JsonConverter]`.** Attribute placement would force the converter into `HoneyDrunk.Kernel.Abstractions`, violating invariant 1. Explicit registration is the canonical wiring pattern; Web.Rest does it once in `JsonOptionsDefaults.Configure` and every Web.Rest serializer call picks the converter up automatically.

**ADR-0057 D8 / D14-equivalent (referenced) — SDK-side parsing target.** The committed JSON shape per ADR-0069 D9 **is** the SDK-side parsing target for monetary values. Web.Rest's default options carry the converter so the wire-shape contract is honored end-to-end from server to SDK.

**ADR-0035 D1 / pre-1.0 disclaimer (referenced) — pre-1.0 minor bump.** The Web.Rest version bump is minor (new converter behavior on the default JSON options).

## Constraints
- **Invariant 27 — solution-wide version bump.** Every non-test `.csproj` moves together.
- **Invariant 12 — per-package CHANGELOGs only for real changes.** `HoneyDrunk.Web.Rest.AspNetCore` gets an entry; the canary project may get one if functional behavior is added; everywhere else (alignment bumps) — no per-package CHANGELOG entry.
- **Invariant 13 — XML docs.** Any new public extension or configurator must be documented.
- **No `Money`-bearing endpoint.** This packet does not add a new HTTP endpoint that surfaces a `Money`. It only wires the converter for forward compatibility.
- **No `Money.Zero` (no-arg).** Per ADR-0069 D2 — the canary uses `Money.Usd(123.45m)` or `Money.Zero(CurrencyCode.Usd)`, never a `Money.Zero` without a currency.
- **Amount as a JSON string is non-negotiable.** D9's precision discipline — the negative canary pins this; do not relax it.

## Labels
`feature`, `tier-2`, `core`, `adr-0069`, `wave-3`

## Agent Handoff

**Objective:** Wire the `MoneyJsonConverter` into the Web.Rest default JSON options and pin ADR-0069 D9's shape with a round-trip + amount-as-number-rejects canary. Forward-compatibility wiring only — no `Money`-bearing endpoint is added.

**Target:** `HoneyDrunk.Web.Rest`, branch from `main`.

**Context:**
- Goal: Lock the SDK-side parsing target ADR-0057 D8 commits, by construction, for every future Web.Rest endpoint that surfaces a price.
- Feature: ADR-0069 Currency Handling rollout, Wave 3 — Web.Rest converter wiring.
- ADRs: ADR-0069 D1/D9 (primary), ADR-0057 D8/D14-equivalent (SDK shape commitment), ADR-0035 (pre-1.0 versioning).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `MoneyJsonConverter` must exist in `HoneyDrunk.Kernel.Abstractions` and the Kernel package must be released on the feed.

**Constraints:**
- Explicit converter registration is **required** — `Money` carries no `[JsonConverter]` attribute (the converter lives in the `HoneyDrunk.Kernel` runtime to keep Abstractions STJ-free per invariant 1). `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs` already exposes the `Configure(JsonSerializerOptions)` seam used grid-wide; register the converter there. No "deferred" branch; no new seam.
- Amount-as-string is non-negotiable (D9). The negative canary pins it.
- Every non-test `.csproj` in the solution version-bumped in one commit (invariant 27).
- Per-package CHANGELOG only on `HoneyDrunk.Web.Rest.AspNetCore` (real change — the JSON defaults pick up a new converter).
- No new `Money`-bearing endpoint or DTO — wiring + canary only.

**Key Files:**
- `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs` — append the `MoneyJsonConverter` registration inside `Configure`.
- `HoneyDrunk.Web.Rest.AspNetCore/HoneyDrunk.Web.Rest.AspNetCore.csproj` — `HoneyDrunk.Kernel` (runtime) `PackageReference`.
- `HoneyDrunk.Web.Rest.Canary/` — round-trip + amount-as-number negative canary.
- Every other non-test `.csproj` in `HoneyDrunk.Web.Rest.slnx` — alignment version bump.
- `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.

**Contracts:**
- `MoneyJsonConverter` (existing, from packet 02, in `HoneyDrunk.Kernel` runtime) — registered explicitly in `JsonOptionsDefaults.Configure`.
- No new Web.Rest contract; no new endpoint.
