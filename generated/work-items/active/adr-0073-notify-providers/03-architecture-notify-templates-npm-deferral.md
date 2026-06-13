---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0073", "wave-3", "deferred"]
dependencies: ["work-item:00"]
adrs: ["ADR-0073"]
wave: 3
initiative: adr-0073-notify-providers
node: honeydrunk-architecture
---

# DEFERRED — record the @honeydrunk/notify-templates polyglot npm-standup deferral

## Summary
Record the deferral of the `HoneyDrunk.Notify.Templates` / `@honeydrunk/notify-templates` package standup as a tracked work item on The Hive. ADR-0073 D4 commits **react-email** as the canonical email-templating library and pins the canonical template set's home at `HoneyDrunk.Notify.Templates` — a polyglot npm package living inside a .NET repo. The packaging shape, build pipeline, npm publish destination, and consumer-PDR template-extension model are non-trivial decisions warranting their own standup ADR. **This packet ships no code.** It writes a deferral document at `generated/deferred-work/adr-0073-notify-templates-npm-standup.md` describing the open questions, the rationale, and the expected shape of the future standup ADR. The deferral entry was also added to ADR-0073 §Follow-up Work by packet 00.

## Context
ADR-0073 D4 — Email templating uses react-email:

- `@react-email/components` for component authoring.
- Templates live in **`HoneyDrunk.Notify.Templates`** — a per-Notify package that holds the canonical template set (verification email, password reset, account-change confirmation, account-deletion confirmation, generic transactional shapes).
- Per-consumer-PDR templates live in the consumer-PDR's repo when product-specific. They consume react-email components from the Notify Templates package for consistency.
- Render at send time — Notify's `IEmailSender` implementation accepts a rendered HTML body; the consumer code calls `render(<MyEmail />)` from react-email and passes the result to `IEmailSender.SendAsync`.
- Tokens and design system from Web.UI per ADR-0071.

The challenge: **react-email is TypeScript/JSX, living in the npm ecosystem; `HoneyDrunk.Notify` is a .NET repo.** The canonical template set is therefore a **polyglot npm package inside a .NET repo** — react-email source in `templates/` (or a sibling structure), HTML output potentially consumed by .NET via a sibling library or via build-time emission. The packaging shape (npm package only? sibling .NET package wrapping rendered HTML? both?), the build pipeline (Node-side build inside CI; how the .NET CI integrates; how the npm package is published to npmjs.org), the publish destination (npmjs.org under `@honeydrunk` scope per ADR-0034 NuGet-feed patterns extended to npm; or GitHub Packages npm; or both), and the consumer-PDR template-extension model (how Hearth's "welcome to the town" email consumes the canonical `<EmailButton>` and contributes a new `<HearthHero>` component) are non-trivial decisions.

Per the user's standing convention ("new-Node scaffolding gets its own standup ADR; don't bundle scaffold into feature packets"), the `HoneyDrunk.Notify.Templates` / `@honeydrunk/notify-templates` package needs its **own standup ADR**. The same pattern was used for `HoneyDrunk.Cache` — ADR-0059's standup paired with ADR-0058's contract decision; the standup ADR scaffolds the Node / package independently of the consuming-contract ADR.

This packet **does not draft the standup ADR**. It records the deferral so the open question is visible on The Hive board and is not lost in the dispatch plan. The standup ADR (provisionally `ADR-0073a-notify-templates-npm-standup`, number to be assigned at draft time) is a separate, future work item.

**Operational impact during the deferral.** react-email is the **committed** templating library per ADR-0073 D4. Until the standup ADR lands and the package ships:

- The canonical template set does not exist.
- Email sends compose HTML consumer-side however the consuming Node already does — today that means Notify's existing template-renderer abstractions (`ITemplateRenderer`, `IEmailTemplateRenderer`) and the per-consumer template-string flow that exists pre-react-email.
- No new email templates should be authored in raw HTML between now and the standup ADR's acceptance (per ADR-0073 D4 negative form: "HTML-string-concatenation is forbidden"). If a consumer needs a new email template before the standup ADR lands, the consumer either waits or temporarily authors with the existing renderer + acknowledges the migration debt; the standup ADR's acceptance forces migration.

## Scope
- New file: `generated/deferred-work/adr-0073-notify-templates-npm-standup.md` — the deferral document.

## Out of Scope
- Drafting the standup ADR. That is a separate, future work item (use the `adr-composer` agent when ready to draft).
- Creating the npm package directory in `HoneyDrunk.Notify`. The standup ADR decides the directory shape; this packet does not pre-empt it.
- Choosing the publish destination, the build pipeline shape, or the consumer-extension model. The standup ADR's job.
- Migrating existing email-template usage. There is no migration until the standup ADR is accepted and the canonical template set ships.

## Proposed Implementation
1. Create the directory `generated/deferred-work/` if it does not exist. (If the directory already exists from a prior deferral document, reuse it.)
2. Author `generated/deferred-work/adr-0073-notify-templates-npm-standup.md` with the following sections:

   ```markdown
   # Deferred — @honeydrunk/notify-templates polyglot npm-package standup

   **Source ADR:** [ADR-0073](../../adrs/ADR-0073-notify-default-providers.md) D4 + §Follow-up Work
   **Recorded:** 2026-05-25
   **Status:** Deferred — standup ADR not yet drafted
   **Target ADR (provisional):** ADR-0073a (number to be assigned at draft time)
   **Target packaging:** `HoneyDrunk.Notify.Templates` (.NET side, if any) + `@honeydrunk/notify-templates` (npm)
   **Home repo:** `HoneyDrunk.Notify` (polyglot — react-email source lives alongside the .NET solution)

   ## Why deferred

   ADR-0073 D4 commits react-email as the Grid's canonical email-templating library and names `HoneyDrunk.Notify.Templates` as the home for the canonical template set. react-email is a TypeScript/JSX library in the npm ecosystem; HoneyDrunk.Notify is a .NET repo. The package is therefore polyglot — npm source inside a .NET repo. The packaging shape, build pipeline, publish destination, and consumer-PDR template-extension model are non-trivial decisions warranting a standup ADR rather than being bundled into ADR-0073's already-broad scope.

   Per the user's standing convention, new-Node and new-package scaffolding gets its own standup ADR — parallel to how ADR-0059 stood up `HoneyDrunk.Cache` paired with ADR-0058's contract decision.

   ## Open questions the standup ADR must answer

   1. **Packaging shape.** Pure npm package (TypeScript/JSX source + rendered HTML output); or polyglot npm + sibling .NET package (.NET-side HTML strings wrapping the rendered output for .NET consumers that don't want to invoke Node at runtime)? If polyglot, how do the two packages version together — independently, or solution-aligned per invariant 27?
   2. **Build pipeline.** Node-side build runs in CI alongside .NET build. How does the .NET CI gate against the Node-side build? Does the canonical template set's rendered HTML get committed to the repo, or generated fresh in CI? Reproducibility implications either way.
   3. **Publish destination.** npmjs.org under `@honeydrunk` scope (parallel to ADR-0034's NuGet-feed conventions extended to npm); or GitHub Packages npm; or both? ADR-0034 should be consulted/amended for an npm policy if one does not exist.
   4. **Consumer-PDR extension model.** A consumer-PDR (Hearth, Notify Cloud, Identity) writes a product-specific email template. The template should compose the canonical `<EmailButton>` and `<EmailLayout>` from the canonical set, and may contribute new shared components. How does extension work? Workspaces? `peerDependencies`? Plain npm imports with shared design tokens via the Web.UI package per ADR-0071?
   5. **Web.UI token interop** (ADR-0071). Web.UI is a separate Node (currently being stood up per ADR-0071). The react-email package must consume Web.UI's design tokens. How is the token contract shared — a third sibling package, runtime fetch, build-time copy?
   6. **InMemory rendering for tests** (invariant 15). Unit tests must not invoke Node to render. Does the canonical set ship pre-rendered fixtures for test consumption, or does the test fixture mock the renderer?
   7. **Preview tooling.** react-email ships a local preview server. Where does it live in the Notify repo's tooling — a `npm run preview` script at the package root? A CLI in `HoneyDrunk.Notify.Tools`?
   8. **Versioning and SemVer.** A breaking change to the canonical `<EmailLayout>` is a breaking change for every consumer-PDR template extending it. The same per-package SemVer + cascade rules ADR-0035 applies to .NET Abstractions packages should apply here — but with npm-side mechanics (peerDeps + version-range pinning).
   9. **Sender-identity integration.** ADR-0038 commits per-product From-address governance. The canonical template set should make From-address misuse hard — every template renders inside an `<EmailLayout>` that pins the product's From-address (consumed from the consumer-PDR's config). The standup ADR pins this contract.

   ## Until the standup ADR lands

   - **No `HoneyDrunk.Notify.Templates` directory is created** in `HoneyDrunk.Notify`. The standup ADR decides the directory shape.
   - **No new npm package is published.** `@honeydrunk/notify-templates` is reserved on npmjs.org by the operator if reservation is desired; that is a human-only chore, not gated here.
   - **Email sends route through Notify's existing template-renderer abstractions** (`ITemplateRenderer`, `IEmailTemplateRenderer`). The pre-react-email flow continues to operate.
   - **No new email templates should be authored in raw HTML.** ADR-0073 D4 negative form forbids "HTML-string-concatenation." Consumers needing a new template either wait for the canonical react-email set to ship, or temporarily extend the existing renderer with the understanding that migration is forced on standup-ADR acceptance.

   ## Trigger to draft the standup ADR

   Draft the standup ADR when **one** of the following fires:

   - **The first consumer-PDR needs to ship a new email template.** Identity's verification-email flow (ADR-0060 Phase 2) is a plausible first trigger — once that work item is queued, the standup ADR is a hard prerequisite.
   - **Notify Cloud GA wants the canonical tenant-onboarding email** in its onboarding flow. ADR-0027's GA work item is a plausible trigger.
   - **Operator-discretion.** The standup is independent enough to draft at any time the operator has the context window.

   When drafting, use the `adr-composer` agent. Reference this deferral document as the input.

   ## Related work

   - [ADR-0073 D4](../../adrs/ADR-0073-notify-default-providers.md) — react-email and `HoneyDrunk.Notify.Templates` commitment.
   - [ADR-0034](../../adrs/ADR-0034-public-package-distribution-and-nuget-policy.md) — public-package distribution policy (NuGet-only at v1; an npm extension is a likely addition for this standup).
   - [ADR-0035](../../adrs/ADR-0035-abstractions-versioning-and-deprecation-policy.md) — SemVer + deprecation policy (npm-side adaptation needed).
   - [ADR-0038](../../adrs/ADR-0038-outbound-sender-identity-and-deliverability.md) — sender-identity discipline that the canonical `<EmailLayout>` enforces.
   - [ADR-0071](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md) — Web.UI tokens consumed by the canonical template set.
   - [ADR-0070](../../adrs/ADR-0070-frontend-platform-stack.md) D1 — React posture (the same idiom react-email uses).
   ```

3. Save.

## Affected Files
- `generated/deferred-work/adr-0073-notify-templates-npm-standup.md` (new file)

## NuGet Dependencies
None. This packet touches only Markdown deferral-tracking files.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any repo.
- [x] No new abstraction. The deferred package's contract surface is left open for the standup ADR to define.

## Acceptance Criteria
- [ ] `generated/deferred-work/adr-0073-notify-templates-npm-standup.md` exists with the sections listed in Proposed Implementation
- [ ] The document explicitly lists at least the 9 open questions stated above
- [ ] The document explicitly states the until-standup-ADR-lands operational posture (no `HoneyDrunk.Notify.Templates` directory created; no new raw-HTML email templates)
- [ ] The document explicitly names the triggers that fire the standup ADR draft (Identity verification email, Notify Cloud GA tenant-onboarding, or operator discretion)
- [ ] The document links to ADR-0073, ADR-0034, ADR-0035, ADR-0038, ADR-0071, ADR-0070 via the standard relative-path convention
- [ ] **No code work happens.** No directory created in `HoneyDrunk.Notify`. No `.csproj` modified. No npm package created.
- [ ] **No edit to `adrs/ADR-0073-notify-default-providers.md`** — packet 00 already added the §Follow-up Work entry referencing this deferral. This packet writes the deferral document only.

## Human Prerequisites
- [ ] (Optional, not gating) **Reserve the `@honeydrunk` npm scope on npmjs.org** if not already reserved. Reserving the scope is a low-cost defensive move that prevents name squatting; reservation itself is a human-only chore on npmjs.org. The standup ADR will commit to a publish destination when drafted.

## Referenced ADR Decisions
**ADR-0073 D4.** "react-email is the canonical email-templating library for the Grid. Email templates author in JSX, render to HTML at send time, and ship via Resend. Templates live in `HoneyDrunk.Notify.Templates` — a per-Notify package that holds the canonical template set."

**ADR-0073 §Follow-up Work.** "Ship `HoneyDrunk.Notify.Templates` package with the canonical react-email template set." (Deferred to standup ADR per the entry packet 00 appended.)

**Memory: New-Node scaffolding needs its own ADR.** Per the user's standing convention, empty cataloged repos and new package standups get a standup ADR first; don't bundle scaffold into feature packets. The same convention applies to polyglot packages of non-trivial complexity.

## Constraints
- **No code work in this packet.** This is a tracking-only deferral; the standup ADR is the work item that produces code.
- **No premature directory creation.** Do not create `HoneyDrunk.Notify/HoneyDrunk.Notify.Templates/` or any sibling — the standup ADR decides the directory shape.
- **No publish-destination commitment in this packet.** npmjs.org vs GitHub Packages npm is an open question for the standup ADR.
- **No edit to ADR-0073's text.** Packet 00 already added the §Follow-up Work entry pointing at this deferral. This packet only writes the deferral document.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0073`, `wave-3`, `deferred`

## Agent Handoff

**Objective:** Record the `@honeydrunk/notify-templates` polyglot npm-package standup deferral as a tracked work item on The Hive. No code ships.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the deferral visible on The Hive so the open question isn't lost in the dispatch plan.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 3.
- ADRs: ADR-0073 D4 (primary — commits react-email; pins the template-set home; this packet records the standup deferral).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0073 is Accepted before this packet runs (because packet 00 added the §Follow-up Work entry that this document is the long-form referent of).

**Constraints:**
- Docs-only, no code, no directory creation.
- The deferral document must enumerate the 9 open questions and the operational-posture-until-standup-ADR-lands rules so a future standup-ADR drafter has a complete starting point.
- Do not draft the standup ADR in this packet. The deferral document is a placeholder, not a draft.

**Key Files:**
- `generated/deferred-work/adr-0073-notify-templates-npm-standup.md` (new file)

**Contracts:** None.
