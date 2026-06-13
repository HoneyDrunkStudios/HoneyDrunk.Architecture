---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0073", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0073", "ADR-0062", "ADR-0006", "ADR-0038", "ADR-0005"]
wave: 2
initiative: adr-0073-notify-providers
node: honeydrunk-notify
---

# Production-harden the Resend email provider for ADR-0073 D1

## Summary
Confirm and complete the production-hardening obligations ADR-0073 D1 puts on the canonical Resend email provider: webhook intake for deliverability events per ADR-0062 (bounce / complaint / delivered / opened / clicked), Tier-2 secret rotation registration per ADR-0006, sender-identity discipline cross-reference per ADR-0038, and confirmation that the existing `HoneyDrunk.Notify.Providers.Email.Resend` package (v0.3.0) is the canonical `IEmailSender` slot fill. **First packet on the Notify solution in this initiative — rolls the existing `[Unreleased]` CHANGELOG content into a dated `[0.3.1]` patch-bump section** and bumps every non-test `.csproj` in the solution from `0.3.0` to `0.3.1`.

## Context
The `HoneyDrunk.Notify.Providers.Email.Resend` package already exists in the Notify repo at version 0.3.0 (per `HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Email.Resend/HoneyDrunk.Notify.Providers.Email.Resend.csproj`). It already:

- Implements `INotificationSender` against the Resend HTTP API (`ResendNotificationSender.cs`).
- Registers as the `NotificationChannel.Email` keyed provider via `AddHoneyDrunkNotifyResendProvider` (`DependencyInjection/ResendNotifyServiceCollectionExtensions.cs`).
- Resolves the API key from `ISecretStore` at send time using the secret name `Resend--ApiKey` (per the v0.2.0 CHANGELOG note).
- Is named `Providers.Email.Resend` (channel-scoped — the convention this initiative is preserving and extending).

What is **not yet in place** per ADR-0073 D1 + the referenced ADRs:

1. **Webhook intake for deliverability events** per ADR-0062. Resend posts webhook callbacks for bounce, complaint, delivered, opened, and clicked events. ADR-0062's verification model (HMAC signature, replay protection, payload schema validation) must be applied at the intake. The intake handler routes verified events into Notify's existing intake pipeline.
2. **Tier-2 secret rotation registration** per ADR-0006. The Resend API key sits in `kv-hd-notify-{env}` and rotates per Tier-2 cadence (≤90 days). The rotation calendar registration in `HoneyDrunk.Vault.Rotation` must list Resend as a Tier-2 rotation target with the `Resend--ApiKey` secret-name binding.
3. **Sender-identity discipline cross-reference** per ADR-0038. The Resend provider's README and the repo's overview should cross-reference ADR-0038's DKIM / SPF / DMARC / From-address governance so an operator looking at the provider knows where the discipline lives. (This packet writes the cross-reference; ADR-0038's full record-creation work is separate from this initiative — see Cross-references below.)

This is **not a new package** — it is hardening of an existing package. The version bump is a **patch** (`0.3.0` → `0.3.1`) because the changes are deliverability/operational hardening with no public API change.

> **CHANGELOG rule (per "no commits under CHANGELOG Unreleased" memory).** The repo-level `CHANGELOG.md` and per-package CHANGELOGs currently carry `[Unreleased]` content (ADR-0044 Grid Review enablement + HoneyDrunk.Standards 0.2.9 refresh, per the file at `HoneyDrunk.Notify/CHANGELOG.md`). This packet is the bumping packet for the Notify solution in this initiative — per invariant 27 it bumps every non-test `.csproj`, and per the standing rule it **rolls the existing `[Unreleased]` content into the new dated `[0.3.1]` section together with the hardening changes from this packet**. After this packet merges, the repo-level `[Unreleased]` section is empty (or absent — match the existing convention in the file).

## Scope
- **`HoneyDrunk.Notify` (intake / runtime)** — new webhook intake endpoint(s) for Resend deliverability events, applying ADR-0062's verification model. Wired into Notify's existing intake pipeline.
- **`HoneyDrunk.Notify.Providers.Email.Resend`** — provider package gets:
  - `README.md` updated with: the ADR-0073 D1 default-provider declaration; the ADR-0038 sender-identity cross-reference; the ADR-0062 webhook verification cross-reference; the ADR-0006 Tier-2 rotation cross-reference.
  - `CHANGELOG.md` updated with a `[0.3.1]` entry — appending the hardening changes; the package's existing `[Unreleased]` Standards-refresh line is rolled into the `[0.3.1]` section.
- **`HoneyDrunk.Notify.Hosting.AspNetCore`** (or wherever the existing intake HTTP routes live — confirm against the repo on execution) — register the new Resend webhook route under the existing intake routing convention.
- **`HoneyDrunk.Notify.Tests`** — unit tests for the Resend webhook intake (verifies ADR-0062 signature; rejects unsigned/replayed payloads; routes verified events into the intake pipeline). **Use the existing test project name** (`HoneyDrunk.Notify.Tests`) — the ADR-0047 `*.Tests.Unit` rename is a separate follow-up tracked under `adr-0047-testing-patterns-and-tooling` and is not gated here.
- **`HoneyDrunk.Notify.IntegrationTests`** — integration test for the end-to-end webhook intake using `WebApplicationFactory<TStartup>` per ADR-0047 Tier 2a — exercises the route, the signature verification, and the dispatch to the intake pipeline using in-process fakes for any external dependency.
- **All non-test `.csproj` files in the solution version-bumped to `0.3.1`** in one commit (invariant 27).
- **Repo-level `CHANGELOG.md`** receives a new `[0.3.1]` dated section that consolidates the existing `[Unreleased]` content (per the standing "no commits under Unreleased" rule) with the changes from this packet.

## Out of Scope
- The actual DKIM / SPF / DMARC record creation work — owned by ADR-0038 (Proposed) and its future implementation initiative. This packet only adds the **cross-reference** at the Resend provider's README.
- The Tier-2 rotation runtime in `HoneyDrunk.Vault.Rotation`. That infrastructure already exists (per the `vault-rotation-bring-up` initiative). This packet only ensures Resend is listed in the rotation calendar configuration consumed by Vault.Rotation; if the calendar configuration lives in Vault.Rotation rather than in Notify, the actual edit may land via a Vault.Rotation packet rather than here — confirm at execution time. If the Resend entry is already present (e.g. added during the original Vault.Rotation bring-up), this is a no-op.
- The Notify Cloud per-tenant override flow (packet 05's responsibility).
- The legacy SendGrid adapter migration — the Notify repo has no SendGrid adapter on disk; the ADR-0073 §Follow-up Work item is a no-op (see dispatch-plan Cross-Cutting Concerns).

## Proposed Implementation
1. **Webhook intake — author the Resend webhook endpoint(s).**
   - Add an HTTP POST endpoint (e.g. at `/internal/webhooks/resend` — confirm path convention against the existing intake routes in `HoneyDrunk.Notify.Hosting.AspNetCore` and `HoneyDrunk.Notify.Functions`).
   - Apply ADR-0062's verification: read the Resend signature header (Resend uses Svix for webhook signing — confirm header name `svix-signature` at execution time), resolve the signing-secret value from `ISecretStore` (secret name `Resend--WebhookSigningSecret` or similar — confirm with the existing Resend-secret-name convention in `HoneyDrunk.Notify.Providers.Email.Resend`), verify the HMAC, reject any payload that fails verification or whose timestamp falls outside the ADR-0062 replay window with `401 Unauthorized` or `400 Bad Request` per ADR-0062.
   - On verified payloads, parse the event and route into Notify's existing intake pipeline as a `DeliveryStatusEvent` (or whatever the existing event shape is for delivery callbacks — confirm against the existing intake-event types).
   - Map Resend event types to internal event shapes: `email.delivered` → delivered; `email.bounced` → bounced (with classification); `email.complained` → complained; `email.opened` → opened; `email.clicked` → clicked. Schema reference: Resend's webhook docs at https://resend.com/docs/dashboard/webhooks/introduction.
2. **Tier-2 rotation calendar registration.**
   - Confirm whether `HoneyDrunk.Vault.Rotation`'s rotation calendar already lists `Resend--ApiKey` (likely already in place from the `vault-rotation-bring-up` initiative). If absent, add the registration in the format used by the calendar (configuration file, attribute, or DI binding — confirm at execution time).
   - If the calendar lives in Vault.Rotation's repo, this step turns into a cross-reference in the Resend provider README only, and the actual rotation-calendar packet is filed against Vault.Rotation separately.
   - Add `Resend--WebhookSigningSecret` to the rotation calendar at Tier 2 (90-day SLA per invariant 20).
3. **README cross-references** in `HoneyDrunk.Notify.Providers.Email.Resend/README.md`:
   - Add a section "ADR-0073 D1 default provider declaration" stating: "Resend is the canonical default email provider for HoneyDrunk.Notify's `IEmailSender` slot per ADR-0073 D1. Per-tenant and per-PDR overrides are permitted per D5 but discouraged."
   - Add a section "Sender identity (ADR-0038)" stating: "DKIM, SPF, DMARC alignment for every sending domain and per-product From-address governance are owned by ADR-0038. Configure Resend's domain-verification flow per ADR-0038's discipline before sending in `dev` / `staging` / `prod` environments."
   - Add a section "Webhook intake (ADR-0062)" stating: "Resend deliverability webhooks (bounce, complaint, delivered, opened, clicked) are received and verified per ADR-0062's HMAC-signed inbound discipline. The signing secret is `Resend--WebhookSigningSecret` in `kv-hd-notify-{env}`."
   - Add a section "Rotation (ADR-0006 Tier 2)" stating: "The Resend API key (`Resend--ApiKey`) and webhook signing secret (`Resend--WebhookSigningSecret`) rotate at Tier 2 cadence (≤90 days) via `HoneyDrunk.Vault.Rotation`."
4. **Per-package CHANGELOG (`HoneyDrunk.Notify.Providers.Email.Resend/CHANGELOG.md`)** — add a `[0.3.1] - {merge-date}` section. Roll the existing `[Unreleased]` entry (Standards 0.2.9 refresh) into this section. Add the new hardening entries: webhook intake; Tier-2 rotation registration; ADR-0073 D1 default-provider declaration in README.
5. **Repo-level `CHANGELOG.md`** — add a `[0.3.1] - {merge-date}` section. Roll the existing `[Unreleased]` entries (ADR-0044 Grid Review request enablement; HoneyDrunk.Standards 0.2.9 refresh) into this section. Add the ADR-0073 production-hardening summary line.
6. **Version bump** — set `<Version>0.3.1</Version>` on every non-test `.csproj` file in the solution in one commit (invariant 27). The test projects (`HoneyDrunk.Notify.Tests`, `HoneyDrunk.Notify.IntegrationTests`) are exempt from the version bump per the existing convention. **Do not add per-package CHANGELOG entries to packages with no functional change** (invariants 12 / 27) — only the repo-level CHANGELOG and the Resend provider's CHANGELOG get entries.
7. **Unit + integration tests.** Use NSubstitute + AwesomeAssertions per the existing repo test stack (post-ADR-0047 migration is complete in this repo). Tests assert: valid signed payload → 200 + event routed; invalid signature → 401 / 400; expired timestamp → 400; malformed body → 400. Tests contain no `Thread.Sleep` (invariant 51).

## Affected Files
- `HoneyDrunk.Notify/Intake/` (or equivalent — confirm at execution) — new files for the Resend webhook route handler and the event mapper.
- `HoneyDrunk.Notify.Hosting.AspNetCore/` — register the route in the existing routing extension if needed.
- `HoneyDrunk.Notify.Providers.Email.Resend/README.md`, `CHANGELOG.md`.
- Repo-level `CHANGELOG.md`.
- All non-test `.csproj` files in the solution — version `0.3.0` → `0.3.1`.
- `HoneyDrunk.Notify.Tests/` — new tests for the webhook intake.
- `HoneyDrunk.Notify.IntegrationTests/` — new integration test for the webhook route.

## NuGet Dependencies
- **`HoneyDrunk.Notify`** — confirm whether ADR-0062's webhook verification helpers ship from `HoneyDrunk.Kernel` or from a Notify-internal helper (likely Notify-internal at this stage). No new third-party `PackageReference` is expected — the HMAC verification uses BCL primitives (`System.Security.Cryptography`). If the existing intake already references a webhook-verification helper (e.g. for a sibling Twilio or Stripe webhook), reuse it.
- **`HoneyDrunk.Notify.Providers.Email.Resend`** — no new `PackageReference`. The package's existing references (`Resend 0.4.0`, `HoneyDrunk.Vault 0.5.0`, `Microsoft.Extensions.*`, `HoneyDrunk.Standards`) are unchanged.
- **Test projects** — existing test-stack references (xUnit + NSubstitute + AwesomeAssertions + coverlet per ADR-0047). No new packages.

## Boundary Check
- [x] All work in `HoneyDrunk.Notify` per the routing rule "notification, email, SMS, SMTP, Resend, Twilio, notify, channel → HoneyDrunk.Notify".
- [x] Webhook intake is delivery mechanics (Notify owns delivery; Communications owns decision — per Notify's `boundaries.md` "If the concern is how to deliver a structurally valid notification, it belongs in Notify"). Verified deliverability events feed Notify's intake, not Communications.
- [x] No new cross-Node runtime dependency. ADR-0062 verification is currently a Notify-internal capability (or ships from Kernel — confirm at execution); no new abstraction edge is added.
- [x] Sender-identity discipline cross-reference does not duplicate ADR-0038's work — it points at ADR-0038, where the work lives.

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify` exposes an HTTP POST webhook route for Resend deliverability events (path under `/internal/webhooks/` or the existing intake-route convention)
- [ ] The route applies ADR-0062 HMAC signature verification using `ISecretStore`-resolved `Resend--WebhookSigningSecret` (or the existing Resend webhook-secret name — confirm at execution)
- [ ] Verified payloads route into Notify's existing intake event pipeline; invalid signatures or expired timestamps return 401/400 without side-effects
- [ ] Resend event types map to Notify's internal event shapes: `email.delivered`, `email.bounced`, `email.complained`, `email.opened`, `email.clicked`
- [ ] `Resend--ApiKey` and `Resend--WebhookSigningSecret` are listed in `HoneyDrunk.Vault.Rotation`'s Tier-2 rotation calendar (or, if the calendar config lives in Vault.Rotation's repo, the cross-reference is in the Resend provider README and a parallel packet is open against Vault.Rotation)
- [ ] `HoneyDrunk.Notify.Providers.Email.Resend/README.md` includes the four cross-reference sections (ADR-0073 D1 declaration, ADR-0038 sender identity, ADR-0062 webhook intake, ADR-0006 Tier-2 rotation)
- [ ] `HoneyDrunk.Notify.Providers.Email.Resend/CHANGELOG.md` has a `[0.3.1]` entry that rolls the existing `[Unreleased]` Standards-refresh content into the new dated section and adds the hardening changes
- [ ] Repo-level `CHANGELOG.md` has a `[0.3.1]` entry that rolls the existing `[Unreleased]` content (ADR-0044 Grid Review enablement + Standards 0.2.9 refresh) into the new dated section together with the ADR-0073 hardening summary
- [ ] The repo-level `CHANGELOG.md` no longer carries any commits under `[Unreleased]` (per the standing "no commits under CHANGELOG Unreleased" rule)
- [ ] Every non-test `.csproj` file in the solution is at `<Version>0.3.1</Version>` in a single commit (invariant 27)
- [ ] **Only** packages with actual functional changes get a per-package CHANGELOG entry (`HoneyDrunk.Notify.Providers.Email.Resend` gets one — `HoneyDrunk.Notify` core may also get one if the webhook route lives there). All other packages get version-aligned `.csproj` updates with **no** CHANGELOG noise (invariants 12 / 27)
- [ ] Unit + integration tests verify: signature-valid → 200 + event routed; signature-invalid → 401/400; replay-window-expired → 400; malformed body → 400; tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate and any contract-shape canary pass

## Human Prerequisites
- [ ] **Resend webhook signing secret seeded in `kv-hd-notify-{env}` for each env.** The signing secret is generated in Resend's dashboard when the operator configures the webhook destination; copy that secret into `kv-hd-notify-dev` / `kv-hd-notify-staging` / `kv-hd-notify-prod` as `Resend--WebhookSigningSecret` before the webhook route goes live.
- [ ] **Resend webhook destination configured in the Resend dashboard** for each environment (dev / staging / prod), pointing at the appropriate `/internal/webhooks/resend` URL.
- [ ] **Tier-2 rotation calendar updated** if the calendar configuration lives outside this repo. Confirm at execution time whether the calendar lives in `HoneyDrunk.Vault.Rotation`'s repo (likely) or in App Configuration; file a Vault.Rotation packet if necessary.
- [ ] **After this packet merges, a human pushes the `HoneyDrunk.Notify` `0.3.1` release tag** so the NuGet packages publish. Agents merge code but never tag or publish.

## Referenced ADR Decisions
**ADR-0073 D1 — Resend is the default email provider.** "`HoneyDrunk.Notify.Providers.Resend` (NuGet package, per the Grid's per-provider-package convention) — the `IEmailSender` implementation. API key in Vault per ADR-0005 — `kv-hd-notify-{env}` namespace, rotated per ADR-0006 Tier 2. Sender identity discipline per ADR-0038 — DKIM, SPF, DMARC alignment for every sending domain; per-product From-address governance. Webhook-driven deliverability events — Resend's webhook callbacks (bounce, complaint, delivered, opened, clicked) deliver into Notify's intake per ADR-0062's verification discipline." (Existing package name on disk is `HoneyDrunk.Notify.Providers.Email.Resend`; the channel-scoped naming is the established convention. The ADR's informal `Providers.Resend` phrasing aligns with the shipped name informally.)

**ADR-0062 §Inbound Webhook Verification** (referenced — this packet consumes the verification discipline ADR-0062 commits; the full ADR text is not inlined here but its rule set is: HMAC signature over body + timestamp header; replay window (typically 5 minutes); fail-closed on missing or invalid signature; per-provider signing-secret resolution via `ISecretStore`).

**ADR-0006 §Tier 2 (third-party rotation)** — "Tier 2 (third-party via rotation Function): ≤ 90 days." (Per invariant 20.) Third-party provider credentials rotate via `HoneyDrunk.Vault.Rotation`'s scheduled Function App, writing new versions into `kv-hd-notify-{env}`. Event Grid cache invalidation propagates the new version per ADR-0005's event-driven invalidation model — applications never pin to a specific secret version per invariant 21.

**ADR-0038 §Outbound Sender Identity and Deliverability** (referenced — discipline applied at Resend's domain-verification flow; this packet does not redefine ADR-0038's rules, it cross-references them in the provider README).

**ADR-0073 §Operational Consequences.** "Local-dev sends never reach real providers. Dev environments use the InMemory implementations per Invariant 15; only `dev`/`staging`/`prod` environments hit Resend / Twilio / Expo."

## Constraints
- **Invariant 12 — Semantic versioning with CHANGELOG and README.**
  > Breaking changes bump major. New features bump minor. Fixes bump patch. Changelogs follow Keep a Changelog format. Per-package CHANGELOG.md inside each package directory: updated only when that specific package has functional changes. Do not add noise entries for packages that were version-bumped solely to align with the solution (see invariant 27).

  Only `HoneyDrunk.Notify.Providers.Email.Resend` (and possibly `HoneyDrunk.Notify` itself, if the webhook route adds code there) gets a per-package CHANGELOG entry. Every other package in the solution gets the version bump in its `.csproj` only.
- **Invariant 15 — Unit tests and in-process integration tests never depend on external services.** The webhook intake tests use in-process fakes for `ISecretStore` and for any HTTP dispatch. No live calls to Resend, no test webhooks fired against the real Resend dashboard.
- **Invariant 20 — No secret may exceed its tier's rotation SLA without an active exception.** Tier 2 (third-party): ≤ 90 days. The Resend API key and webhook signing secret rotate within 90 days.
- **Invariant 21 — Applications must never pin to a specific secret version.** The Resend provider reads the latest version of `Resend--ApiKey` and `Resend--WebhookSigningSecret` on every send / verify call; pinning breaks Event Grid cache invalidation per ADR-0006.
- **Invariant 27 — All projects in a solution share one version and move together.** Every non-test `.csproj` goes to `0.3.1` in one commit. Partial bumps are forbidden. This is the first packet on the Notify solution in this initiative; packets 04 / 06 / 07 / 08 append to (or further bump from) `0.3.1` per the dispatch plan.
- **Invariant 51 — Test code contains no `Thread.Sleep`.** Async work waits via `await` or polling primitives with explicit timeouts.
- **No `[Unreleased]` commits left in any CHANGELOG.** Per the standing rule "no commits under CHANGELOG `Unreleased`" — the existing `[Unreleased]` content in the repo-level and per-package CHANGELOGs is rolled into the new `[0.3.1]` dated section in this packet's commit.
- **Test project naming.** The existing test project name `HoneyDrunk.Notify.Tests` (pre-ADR-0047) is acknowledged. The rename to `HoneyDrunk.Notify.Tests.Unit` is a separate follow-up tracked under `adr-0047-testing-patterns-and-tooling` — not done here. Add tests under the existing project name.
- **ADR-0073 D5 — Default is not exclusive.** The Resend provider stays composable with the existing keyed-DI shape; other providers (the existing `Providers.Email.Smtp`) remain registerable for `NotificationChannel.Email`. Do not change the resolver to hard-favor Resend.

## Labels
`feature`, `tier-2`, `ops`, `adr-0073`, `wave-2`

## Agent Handoff

**Objective:** Production-harden the Resend email provider per ADR-0073 D1: webhook intake (ADR-0062), Tier-2 rotation registration (ADR-0006), ADR-0038 cross-reference. First packet on the Notify solution in this initiative — bumps from `0.3.0` to `0.3.1` and rolls the existing `[Unreleased]` content into the dated `[0.3.1]` section.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Confirm Resend as the canonical default `IEmailSender` and complete the production-hardening obligations ADR-0073 D1 puts on it.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 2.
- ADRs: ADR-0073 D1 (primary); ADR-0062 (webhook verification — consumed); ADR-0006 (Tier-2 rotation — consumed); ADR-0038 (sender identity — cross-referenced, not implemented); ADR-0005 (Vault config — already in place); ADR-0019 (Notify is delivery-mechanics layer, Communications is decision layer — webhook intake feeds Notify's intake, not Communications).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0073 is Accepted before any consuming packet runs.

**Constraints:**
- Bump every non-test `.csproj` to `0.3.1` in one commit (invariant 27). This is the first packet on Notify in this initiative; subsequent packets (04, 06, 07, 08) sequence after.
- Roll the existing `[Unreleased]` CHANGELOG content into the dated `[0.3.1]` section in the same commit — do not leave anything in `[Unreleased]` (standing rule).
- Per-package CHANGELOGs only for packages with actual functional change (invariants 12 / 27). The Resend provider gets an entry; everything else is alignment-bump-only with no noise.
- Webhook intake applies ADR-0062's HMAC verification with `ISecretStore`-resolved signing secret; fail-closed on missing or invalid signature.
- Test project name stays `HoneyDrunk.Notify.Tests` (pre-ADR-0047). The `.Tests.Unit` rename is tracked under `adr-0047-testing-patterns-and-tooling` separately.

**Key Files:**
- `HoneyDrunk.Notify/Intake/` (or equivalent existing intake folder) — new webhook route.
- `HoneyDrunk.Notify.Providers.Email.Resend/README.md` and `CHANGELOG.md`.
- Repo-level `CHANGELOG.md`.
- Every non-test `.csproj` file — version `0.3.0` → `0.3.1`.
- Test projects — new tests under existing folder conventions.

**Contracts:**
- No public contract change. `IEmailSender` and `INotificationSender` are unchanged. The webhook intake adds an internal event-routing path, not a new abstraction.
