# Dispatch Plan — ADR-0057: Public HTTP API Versioning and Client SDK Strategy

**Initiative:** `adr-0057-api-versioning`
**ADR:** ADR-0057 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-25

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0057 commits the Grid's substrate for public HTTP APIs: URL-path versioning with OpenAPI 3.1 as the source of truth (D7); a four-tier breaking-change taxonomy enforced by an `oasdiff` CI gate (D4 + D7); a 180-day deprecation lifecycle with tenant-notification cadence routed through Communications + Notify (D5); a hard two-major coexistence window (D6); three published SDK languages — TypeScript, Swift, Kotlin — generated from the spec via OpenAPI Generator (D8); per-API key + OAuth 2.1 PKCE auth (D10); IETF unprefixed `RateLimit-*` headers reconciled with ADR-0067 (D11); RFC 7807 `application/problem+json` errors with `traceId` / `correlationId` extensions (D12); `Idempotency-Key` per ADR-0042 on writes (D13); cursor-based pagination defaults (D14); Scalar-plus-Docusaurus docs sites reconciled with ADR-0075 at `docs.{api}.honeydrunkstudios.com` (D15); HoneyHub as the narrow GraphQL-schema-evolution exception (D1 + D16).

This initiative delivers, in **12 packets across 4 waves**, targeting **5 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Actions`, `HoneyDrunk.Web.Rest`, `HoneyDrunk.Notify`, `HoneyDrunk.Studios`):

1. ADR acceptance, four invariants reserved at `{N1}-{N4}` (current claim 102-105), tech-stack + catalog + named-flow registration, and three operator playbooks (migration template, deprecation runbook, docs-subdomain provisioning) — Architecture x3.
2. Four reusable workflows in `HoneyDrunk.Actions` per ADR-0012's CI/CD control plane posture — the OpenAPI breaking-change diff gate (D7's load-bearing enforcement), the per-language SDK generation + publication pipeline (D8), the per-API docs site builder + Cloudflare Pages deployer (D15), and the HoneyHub GraphQL substrate (D16 — workflows ship now as buildable substrate; HoneyHub repo doesn't exist yet) — Actions x4.
3. Phase 1 pilot on `HoneyDrunk.Web.Rest` (low-risk: OpenAPI v1 spec reverse-engineered, surface frozen at v1, Option C envelope alignment, cursor primitives added) and Phase 2 pilot on `HoneyDrunk.Notify` (the dry run for Notify Cloud GA: real per-endpoint spec, SDKs publish in dry-run until credentials seeded, docs scaffold).
4. Studios-side docs subdomain provisioning for the first concrete instance (`docs.notify.honeydrunkstudios.com`); a deferred-handoff specification for the Notify Cloud Phase 3 GA-blocker work (analogous to ADR-0067 packet 05's deferred Notify Cloud spec); and the operator-time-budgeted external onboarding (npm scope, Maven Central namespace, GPG keys, Cloudflare API token).

**12 packets total. 10 are `Actor=Agent`. 2 are `Actor=Human`** — packet 09 (Cloudflare DNS + Pages portal work) and packet 11 (external registry onboarding) carry the `human-only` label per the user's convention.

## Trigger

ADR-0057 is Proposed with no scope. The forcing functions from the ADR's Context:

- **Notify Cloud GA** (PDR-0002 / ADR-0027) is the first commercial API consumer. Without this ADR, every breaking change to a Notify Cloud endpoint risks a tenant outage.
- **The AI-sector standup wave** (ADR-0016 through ADR-0025) introduces multiple Nodes whose long-term posture includes public surfaces. They need the substrate committed before each invents its own.
- **Mobile consumer apps** (PDRs 0003 / 0005 / 0006 / 0008) all have a real-world client-version tail. The first breaking change to an API breaks installed mobile clients absent a versioning policy.
- **ADR-0035 is the internal-case companion** — settled for internal abstractions; this ADR is the external-facing companion. Without it the Grid has half a versioning story.

The cost of letting the convention drift across N Nodes is N rewrites later when the first inconsistency surfaces in a customer outage.

## Scope Detection

**Multi-repo, multi-Node — similar in scope to the observability initiatives.** ADR-0057 lands the substrate workflows in `HoneyDrunk.Actions` (packets 03-06), the per-API instances in `HoneyDrunk.Web.Rest` (packet 07) and `HoneyDrunk.Notify` (packet 08), the Studios-side docs subdomain provisioning (packet 09), the governance + catalog + invariants + playbooks + deferred-spec + onboarding documentation in `HoneyDrunk.Architecture` (packets 00, 01, 02, 10, 11). Five repos total.

**Notify Cloud Phase 3 (D17 Phase 3) is deliberately deferred.** ADR-0027 (Notify Cloud standup) is Proposed; the `HoneyDrunk.Notify.Cloud` repo does not exist on disk; `file-packets.yml` cannot file against it. Per the user's standing convention ("new-Node scaffolding gets its own standup ADR; don't bundle scaffold into feature packets"), the Notify Cloud public-API packet must file *after* the `adr-0027-notify-cloud-standup` initiative's scaffold packet lands. This initiative authors the specification in packet 10 as the handoff document; the production-implementation packet against `HoneyDrunk.Notify.Cloud` is filed as a *new* follow-up packet (or a new initiative `adr-0057-notify-cloud-public-api`) after ADR-0027 completes — see Cross-Initiative Coupling below.

**HoneyHub Phase 4 (D17 Phase 4) implementation is similarly deferred** — HoneyHub does not exist on disk; ADR-0003 (HoneyHub) is Proposed. The **substrate** ships in this initiative (packet 06 — the two GraphQL reusable workflows in Actions) because the workflows are buildable Actions assets, not invoked by any caller yet. The actual `schema.graphql` commitment, the breaking-change gate enabling on the HoneyHub repo, and the HoneyHub docs site provisioning at `docs.honeyhub.honeydrunkstudios.com` land as part of (or after) the HoneyHub standup.

**Four invariants added** — `{N1}-{N4}`, claimed at `102-105` per `constitution/invariant-reservations.md` rule 5 (next free above ADR-0080's 99-101). Packet 00 writes the invariants verbatim; rule 5's collision-shift mechanism handles the case where another in-flight initiative consumes the block first.

**No new abstractions in `.Abstractions` packages.** Web.Rest's new types (`ProblemDetails`, `CursorPageRequest`, `CursorPageResult`, `ApiErrorResponse.Type`) land in `HoneyDrunk.Web.Rest.Abstractions` 0.6.0; that *is* an Abstractions package. Per the package's existing posture and invariant 1, the new types are zero-runtime-dependency Studios-defined records. Notify consumes them at v0.4.0 (packet 08). No other Abstractions package is touched.

**Two `catalogs/contracts.json` updates introduce the `publicHttpApi` block convention** (packet 01 introduces the schema with populated entries for Web.Rest and Notify; packets 07 and 08 populate the spec-path / SDK-coordinates / docs-URL fields, either as sibling commits to Architecture or as follow-up packets — operator decision).

**No new edges in `catalogs/relationships.json`.** Notify already consumes Web.Rest; the Web.Rest 0.6.0 bump propagates as a transitive version-pin update, not a new edge.

## Wave Diagram

### Wave 1 (No Dependencies — governance, catalog, playbooks)
- [ ] **00** — Architecture: Accept ADR-0057, reserve invariants `{N1}-{N4}` (current claim 102-105), write the four invariants verbatim, register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: tech-stack.md + `publicHttpApi` block in contracts.json + `deprecation-notification` flow in feature-flow-catalog.md. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: three operator playbooks — migration-guide template, deprecation runbook, docs-subdomain provisioning playbook. `Actor=Agent`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — Actions substrate; parallel)
- [ ] **03** — Actions: `job-openapi-diff.yml` — the load-bearing breaking-change CI gate per D7. `Actor=Agent`. Blocked by: 00, 01.
- [ ] **04** — Actions: `job-publish-public-sdk.yml` — per-language SDK generation + publication for TS / Swift / Kotlin; Studios-maintained override templates in `openapi-templates/{language}/`. `Actor=Agent`. Blocked by: 00, 01.
- [ ] **05** — Actions: `job-publish-docs.yml` — Scalar + Docusaurus docs build + Cloudflare Pages deploy. `Actor=Agent`. Blocked by: 00, 01.
- [ ] **06** — Actions: `job-graphql-inspector.yml` + `job-publish-graphql-docs.yml` — HoneyHub Phase 4 substrate (ships now; not invoked until HoneyHub stands up). `Actor=Agent`. Blocked by: 00, 01.

Packets 03-06 are mutually independent and can run in parallel.

### Wave 3 (Depends on Wave 2 — Phase 1 pilot on Web.Rest)
- [ ] **07** — Web.Rest: reverse-engineered `openapi-v1.yaml`, surface frozen at v1, Option C envelope alignment (additive RFC 7807 via content negotiation), cursor pagination primitives, IETF rate-limit header hook, Docusaurus scaffold, per-repo CI wiring; version-bump to `0.6.0`. `Actor=Agent`. Blocked by: 00, 01, 03, 05.

### Wave 4 (Depends on Wave 3 — Phase 2 pilot, Studios docs provisioning, deferred-spec handoff, operator onboarding)
- [ ] **08** — Notify: `openapi-v1.yaml` for the existing endpoints with full ADR-0057 conventions, cursor refactor on list endpoints, RFC 7807 middleware composition from Web.Rest 0.6.0, Idempotency-Key on `POST /v1/notify/send` (or deferred-substrate note), Docusaurus scaffold, per-repo CI wiring; version-bump to `0.4.0`. `Actor=Agent`. Blocked by: 00, 01, 03, 04, 05, 07.
- [ ] **09** — Studios: Cloudflare DNS + Pages provisioning for `docs.notify.honeydrunkstudios.com` per packet 02's playbook. `Actor=Human` (portal work). Blocked by: 00, 02.
- [ ] **10** — Architecture: Notify Cloud Phase 3 specification — the deferred handoff to the future `adr-0027-notify-cloud-standup` follow-up (analogous to ADR-0067 packet 05). `Actor=Agent`. Blocked by: 00, 02.
- [ ] **11** — Architecture: operator onboarding checklist — npm `@honeydrunk` scope, Maven Central `com.honeydrunkstudios` namespace verification, GPG keypair + upload, Cloudflare API token; org secret seeding. `Actor=Human` (portal + CLI). Blocked by: 00, 02, 04, 05.

Within Wave 4: packets 08, 09, 10, 11 are mutually independent at the dependency level — 08 depends on Web.Rest 0.6.0 (Wave 3); 09 + 10 + 11 depend only on Wave 1. They are grouped as Wave 4 because they round out the initiative (Phase 2 pilot, first concrete docs provisioning, deferred handoff, operator onboarding) and complete the **post-onboarding verification loop** described under Cross-Cutting Concerns.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0057 — reserve invariants {N1}-{N4}, register initiative](./00-architecture-adr-0057-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Public-API substrate in tech-stack.md + contracts.json + feature-flow-catalog.md](./01-architecture-public-api-catalog-and-tech-stack.md) | Architecture | Agent | 1 | 00 |
| 02 | [Migration template + deprecation runbook + docs-subdomain provisioning playbook](./02-architecture-migration-and-deprecation-playbooks.md) | Architecture | Agent | 1 | 00 |
| 03 | [job-openapi-diff.yml — breaking-change CI gate](./03-actions-openapi-diff-workflow.md) | Actions | Agent | 2 | 00, 01 |
| 04 | [job-publish-public-sdk.yml — TS / Swift / Kotlin SDK generation + publication](./04-actions-publish-public-sdk-workflow.md) | Actions | Agent | 2 | 00, 01 |
| 05 | [job-publish-docs.yml — Scalar + Docusaurus + Cloudflare Pages](./05-actions-publish-docs-workflow.md) | Actions | Agent | 2 | 00, 01 |
| 06 | [job-graphql-inspector.yml + job-publish-graphql-docs.yml — HoneyHub Phase 4 substrate](./06-actions-graphql-inspector-and-docs-workflows.md) | Actions | Agent | 2 | 00, 01 |
| 07 | [Web.Rest Phase 1 pilot — openapi-v1.yaml + Option C envelope + cursor primitives + 0.6.0](./07-web-rest-openapi-v1-and-envelope-migration.md) | Web.Rest | Agent | 3 | 00, 01, 03, 05 |
| 08 | [Notify Phase 2 pilot — openapi-v1.yaml + SDK + docs (dry-run) + 0.4.0](./08-notify-openapi-v1-and-sdk-pilot.md) | Notify | Agent | 4 | 00, 01, 03, 04, 05, 07 |
| 09 | [Studios — Cloudflare DNS + Pages for docs.notify.honeydrunkstudios.com](./09-studios-docs-notify-subdomain-provisioning.md) | Studios | Human | 4 | 00, 02 |
| 10 | [Notify Cloud Phase 3 specification — deferred handoff to ADR-0027 standup](./10-architecture-notify-cloud-phase3-specification.md) | Architecture | Agent | 4 | 00, 02 |
| 11 | [Operator onboarding — npm scope + Maven Central namespace + GPG + Cloudflare token](./11-architecture-sdk-registry-and-credentials-onboarding.md) | Architecture | Human | 4 | 00, 02, 04, 05 |

## Version Bumps

- **`HoneyDrunk.Web.Rest`** — packet 07 bumps the solution `0.5.0` → `0.6.0` (minor; additive per ADR-0035 D1 — new types in Abstractions, additive optional field on `ApiErrorResponse`, new middleware extension). Both `.csproj` files in one commit per invariant 27. Per-package CHANGELOGs entered only for packages with functional change (`Abstractions` and `AspNetCore` both have changes). Repo-level `CHANGELOG.md` gets a new dated `[0.6.0]` entry. No `[Unreleased]`.
- **`HoneyDrunk.Notify`** — packet 08 bumps the solution `0.3.0` → `0.4.0` (minor; additive — new OpenAPI spec, new docs scaffold, new workflow wiring, list-endpoint cursor refactor consuming Web.Rest 0.6.0 primitives; no breaking change). All non-test `.csproj` files in one commit per invariant 27. Per-package CHANGELOGs only for packages with functional change. Repo-level `CHANGELOG.md` gets a new dated `[0.4.0]` entry.
- **`HoneyDrunk.Actions`** — packets 03, 04, 05, 06 each add reusable workflows + override-template directories + consumer docs. The Actions repo's CHANGELOG convention dictates whether each addition is its own dated entry or batched; default to one dated entry per packet (or one combined entry per wave's merge — operator choice). No `[Unreleased]`.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance / catalog / doc edits only across packets 00, 01, 02, 10, 11. The repo-level `CHANGELOG.md` records each packet's contribution in dated, versioned entries.
- **`HoneyDrunk.Studios`** — packet 09 records the docs-subdomain provisioning in `CHANGELOG.md` (dated, versioned).

## Cross-Initiative Coupling with ADR-0027 (Notify Cloud Standup)

ADR-0027 is Proposed; the `HoneyDrunk.Notify.Cloud` repo does not exist on disk. ADR-0057 D17 Phase 3 commits numbers and shapes that *land* in Notify Cloud's production public-API surface. But Notify Cloud's implementation can only be filed after the Notify Cloud repo exists and is scaffolded — i.e., after `adr-0027-notify-cloud-standup` packet 06 (scaffold) lands.

**This initiative's resolution:** packet 10 authors the full Notify Cloud Phase 3 public-API specification in the Architecture repo (at `infrastructure/walkthroughs/notify-cloud-public-api-specification.md`) — a doc that the future follow-up filer reads and turns into a real packet against `HoneyDrunk.Notify.Cloud`. The handoff is explicit: the specification carries a "Follow-up Notify Cloud packet" outline at the bottom (target repo, expected scope, dependencies, version-bump expectation).

The follow-up Notify Cloud packet is **not** filed in this initiative. It is filed:

- **Option A** — as part of the `adr-0027-notify-cloud-standup` initiative's wave-4 follow-up packets (natural home, since ADR-0027 packet 06's scaffold ships placeholder controllers that the production implementation replaces).
- **Option B** — as a new initiative `adr-0057-notify-cloud-public-api` after `adr-0027-notify-cloud-standup` completes, if the operator prefers an explicit follow-up wave (parallels how ADR-0067's Notify Cloud rate-limit policy is being handled).

Either is acceptable; the choice is the operator's at the time the Notify Cloud follow-up is filed. The specification document in packet 10 is the same regardless.

**Exit-criterion reconciliation.** ADR-0057's exit criterion is the substrate complete + Web.Rest v1 frozen + Notify v1 spec/SDKs/docs live — all within this initiative's filing window. **Notify Cloud Phase 3 is explicitly outside the exit criterion** — it is satisfied across the ADR-0027 standup boundary. This mirrors the ADR-0067 pattern (acceptance flips at the start; the deeper success criterion is the initiative-completion gate recorded in `initiatives/active-initiatives.md` and satisfied across multiple wave / initiative boundaries).

## Cross-Initiative Coupling with ADR-0067 (Rate Limiting) and ADR-0075 (Docs Tooling)

**Already reconciled in the ADR text itself.** ADR-0057 D11 was amended (2026-05-24) to defer to ADR-0067 D5/D7 as the canonical source for the rate-limit envelope (unprefixed IETF `RateLimit-*` headers; per-tenant keying; no legacy `X-RateLimit-*` mirrors; `Retry-After` in seconds). ADR-0057 D15 was amended (2026-05-24) to defer to ADR-0075 D1 + D2 as the canonical sources for Scalar (OpenAPI reference) + Docusaurus (narrative). The packets in this initiative reference both ADRs at the appropriate points — packet 01 records the reconciliation in tech-stack.md; packet 07 wires Web.Rest's `RateLimit-*` hook complementary to the Kernel limiter; packets 05, 06, and 09 consume the Scalar + Docusaurus + Cloudflare Pages choices reconciled with ADR-0075's substrate.

**No new conflicts.** The reconciliations were performed at refine time and are reflected in the ADR text and in the packets here. The OpenAPI-diff CI gate (packet 03) does not conflict with ADR-0067's rate-limit infrastructure; the docs publication workflow (packet 05) consumes Scalar in static-publication mode, not the `Scalar.AspNetCore` runtime mode that ADR-0075 D1 uses — the two are complementary uses of the same renderer.

## Cross-Initiative Coupling with ADR-0034 (NuGet / Public Distribution Policy)

ADR-0034 (Proposed) commits the NuGet policy + namespace decisions: nuget.org as the primary feed for public packages; GitHub Packages for private; `HoneyDrunkStudios` owner; per-package metadata requirements; the namespace ownership decisions including `com.honeydrunkstudios` for Maven Central. ADR-0057 D8's SDK publication consumes ADR-0034 D3's namespace decisions for the per-language registries.

**This initiative does NOT amend ADR-0034.** ADR-0034 remains Proposed; this initiative's packet 11 is the **operator-time-budgeted implementation of ADR-0034 D3's namespace claims** for the SDK registries (npm `@honeydrunk`, Maven Central `com.honeydrunkstudios`, Swift Package Index — git-tag-based, no central namespace). The work is portal-only; no ADR amendment necessary. Once packet 11 completes and the namespaces are claimed, ADR-0034 can move toward acceptance independently; ADR-0057 does not block on it.

## Cross-Cutting Concerns

### Post-onboarding verification loop is the load-bearing closure

The post-onboarding verification described in packet 11's acceptance criteria — re-running packet 08's `notify-api-v1.0.0` tag publication and confirming the SDKs land on the registries + the docs site serves at `docs.notify.honeydrunkstudios.com/v1/` — is the **end-to-end proof** that the substrate works. Until this verification passes, the initiative is not fully exited; packets 03-06 are buildable but not exercised end-to-end on a real publication target.

The verification depends on:
- Packet 08 having pushed `notify-api-v1.0.0` (the tag itself is operator-pushed per the agents-never-tag rule).
- Packet 09 having provisioned the Cloudflare Pages project + DNS for `docs.notify`.
- Packet 11 having seeded the per-registry credentials as GitHub org secrets.

When all three are complete, the operator (or a follow-up agent) re-runs `release-api.yml` on the existing tag and confirms the end-to-end flow. This is the initiative's exit gate — record success in `initiatives/active-initiatives.md` at that point.

### Dry-run posture is intentional through Phase 2 pilot

Packets 04, 05, 08 ship in dry-run-by-default mode. This is intentional, not a defect:
- It prevents accidental publication when credentials are missing.
- It exercises the build / generation / validate logic without external side effects.
- The promotion from dry-run to real-publish is a one-flip event triggered by packet 11's credential seeding (`NPM_TOKEN` / `MAVEN_USERNAME` / etc. become non-empty; the workflows' conditional checks pass; the publish steps execute).

The dry-run logs are required to be loud and unambiguous about *why* they did not publish — so an operator triaging the workflow run knows whether the dry-run was credential-driven (expected pre-packet-11) or for some other reason.

### The four invariants land at acceptance, not later

Packet 00 reserves the four-invariant block `{N1}-{N4}` and writes the verbatim invariant texts into `constitution/invariants.md` in the same PR. This follows the ADR-0008 D5 (superseded by D6) registry pattern that landed in `invariant-reservations.md` — reservation + writing in the same PR. Subsequent packets reference the resolved numbers; if a collision forces a shift at PR time, packet 00 also updates every `{N1}/{N2}/{N3}/{N4}` placeholder in packets 01-11 in the same PR (rule 5 of `invariant-reservations.md`).

### Web.Rest envelope migration is Option C (pinned)

Three options were considered for Web.Rest's RFC 7807 alignment: (A) sudden cutover; (B) defer to v2; (C) additive content negotiation. **Option C is pinned**. The middleware emits both shapes via `Accept`-header content negotiation; default-`ApiErrorResponse` preserves backwards compatibility; clients that signal `Accept: application/problem+json` get RFC 7807. ADR-0057 D4 classifies this as non-breaking; the OpenAPI-diff gate (packet 03) confirms.

The pinning rationale: Option A breaks every Web.Rest consumer; Option B defers the alignment for 180+ days during which downstream code keeps coupling to the Studios-specific shape. Option C is the only path that exercises the substrate now (per ADR-0057 D17 Phase 1's pilot intent) without breaking consumers.

### HoneyHub Phase 4 substrate ships now; implementation deferred

Packet 06 ships `job-graphql-inspector.yml` and `job-publish-graphql-docs.yml` as buildable Actions assets. HoneyHub itself does not exist on disk; ADR-0003 is Proposed. The substrate-now-implementation-later split is the same pattern as Notify Cloud Phase 3 — the substrate is reusable infrastructure that takes time to build correctly, so it lands before the consumer exists, ready to be invoked when the standup happens. This pre-positioning is per ADR-0057 D17 Phase 5's "AI-sector inherits Phase 1 substrate at standup."

### `catalogs/contracts.json` cross-repo update for packets 07 + 08

Packets 07 (Web.Rest) and 08 (Notify) ship their per-API OpenAPI spec, SDK coordinates (Notify only — Web.Rest has none per the deferred-language reasoning), and docs URL. The `catalogs/contracts.json` entries for those Nodes need their `publicHttpApi.openApiSpecPath` / `sdkCoordinates` / `docsUrl` populated. This is awkward to land *from* a per-repo PR (the PR targets Web.Rest or Notify; the catalog file lives in Architecture). Two options:
- **Option A** — include a sibling commit to `HoneyDrunk.Architecture` in the same PR set if the operator drives the PRs together.
- **Option B** — file a tiny follow-up packet against Architecture (e.g., `12-architecture-publichttpapi-population.md`) once 07 and 08 have landed.

Operator decision at execution time; either is acceptable. The packets call this out as a Human Prerequisite line.

### Cloudflare Pages free-tier sufficiency

Per the user's `feedback_default_cheapest_azure_tier` rule extended to vendor SaaS: Cloudflare Pages free tier supports the entirety of this initiative's docs traffic. No paid tier needed at v1. Packet 09 confirms.

### Audit footprint

Per ADR-0030 (Audit substrate) and ADR-0057 §Consequences:
- Every deprecation announcement → `IAuditLog` event (Communications-orchestrated; the `deprecation-notification` flow in packet 01).
- Every T-90 / T-30 / T-7 tenant email dispatch → `IAuditLog` event.
- Every post-sunset rejected request → `IAuditLog` event (when the first deprecation runs in earnest, post-Notify Cloud GA).

This initiative does not ship the audit emits; packets 07 and 08 reference the audit substrate in their respective middleware compositions, but no `RateLimitRejected`-style new audit event types are introduced. The deprecation-notification flow is the named flow that surfaces the audit footprint as a single referenceable concept.

### Site sync

No site-sync flag. ADR-0057 is internal Core infrastructure (workflows, conventions, governance) and per-API operational documentation; the public `honeydrunkstudios.com` marketing site does not change. The per-API docs subdomains (`docs.{api}.honeydrunkstudios.com`) are new public surfaces but are catalogued as their own Studios-sector responsibility per ADR-0057 §Cross-ref Studios sector — packet 09 ships the first instance.

### Deferred follow-ups (explicitly out of scope of this initiative)

- **Notify Cloud Phase 3 public-API + SDKs + docs implementation.** Filed after `adr-0027-notify-cloud-standup` scaffold lands. Specification in packet 10.
- **HoneyHub schema commitment + breaking-change gate enabling + docs subdomain.** Filed after HoneyHub stands up. Substrate ships in packet 06.
- **Web.Rest docs subdomain provisioning** (`docs.web-rest.honeydrunkstudios.com`). Follows packet 09's pattern; tracked separately because Web.Rest's docs traffic is low and the dry-run state is acceptable through Phase 1.
- **Per-API `catalogs/contracts.json` population follow-up packet** for Web.Rest + Notify (operator-decision; sibling commit vs. follow-up packet).
- **C# / Python / Go / Ruby / PHP SDKs.** Generated on request per ADR-0057 D8.
- **`docs.honeydrunkstudios.com/errors/` page authoring.** Each error `type` URI ships in code now; the per-page authoring on the Studios website is a deferred, operator-driven content task.
- **Hand-tuned SDK wrapper layers.** Generated SDKs are functional but not idiomatically polished; hand-tuned wrappers land only on evidence per ADR-0057 §Operational Consequences.
- **OAuth 2.1 with PKCE end-user flow.** ADR-0057 D10 commits both API key and OAuth; OAuth lands when the first end-user-facing Notify Cloud (or future consumer-app) feature requires it.

## Rollback Plan

- **Packets 00-02 (governance / catalog / playbooks):** revert the PR. ADR returns to Proposed; the four invariants are removed from `invariants.md`; the reservation is removed from `invariant-reservations.md`; tech-stack / catalog / feature-flow-catalog / playbook documents are removed. No runtime impact.
- **Packets 03-06 (Actions substrate):** revert the per-workflow PR. The reusable workflow is removed; consumer documentation is removed; any consuming repo wired against it stops invoking it (none at the time these workflows land, by construction). No runtime impact in `HoneyDrunk.Actions` itself.
- **Packet 07 (Web.Rest 0.6.0):** revert the PR; Web.Rest rolls back to `0.5.0`. The new types in Abstractions (`ProblemDetails`, `CursorPageRequest`, `CursorPageResult`) and the additive `ApiErrorResponse.Type` field are removed; consuming Nodes (Notify after packet 08) must drop their consumption — though packet 08 has not yet landed if packet 07 is being reverted. The OpenAPI spec is removed; the docs scaffold is removed; the per-repo CI wiring is removed. Web.Rest consumers see the pre-0.6.0 shape.
- **Packet 08 (Notify 0.4.0):** revert the PR; Notify rolls back to `0.3.0`. The OpenAPI spec is removed; the docs scaffold is removed; the per-repo CI wiring is removed; the cursor-pagination refactor on list endpoints reverts. If the SDKs published for real (post-packet-11), the published versions stay on the registries (per ADR-0057 D9 — never unpublish; mark deprecated if necessary). The dry-run-published SDKs are not in any registry; nothing to unpublish.
- **Packet 09 (Studios docs subdomain provisioning):** revert the documentation PR. The Cloudflare DNS record + Pages project remain in Cloudflare (revert means manual deletion via the Cloudflare portal — the operator's decision). The docs subdomain stops resolving if the DNS record is removed.
- **Packet 10 (Notify Cloud Phase 3 spec):** revert the PR; the specification document is removed; the cross-initiative coupling note in `active-initiatives.md` is reverted. No runtime impact.
- **Packet 11 (operator onboarding):** revert the documentation PR. The npm / Maven Central / Cloudflare credentials remain claimed in their respective portals (revert means manual deletion via each portal — the operator's decision). The GitHub org secrets remain seeded unless manually removed. The dry-run posture re-asserts itself if any secret is unset.
- **Operational escape hatch:** if the OpenAPI-diff gate (packet 03) produces false positives blocking legitimate non-breaking changes, the gate's `is-unreleased-major: true` input can be set per-PR as a temporary opt-out, or the consuming repo's branch protection can mark the check as advisory rather than required. Both are config-only changes; neither requires a code revert. The over-strict gate is then tuned in a follow-up packet against the workflow.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

The Notify Cloud Phase 3 follow-up packet is **not** in this folder and is **not** filed by this initiative's push — it is filed later, against the `HoneyDrunk.Notify.Cloud` repo, after the `adr-0027-notify-cloud-standup` initiative's scaffold lands. See Cross-Initiative Coupling above. The HoneyHub Phase 4 schema commitment + per-repo CI wiring is similarly filed later, against the future HoneyHub repo, after the HoneyHub standup completes.
