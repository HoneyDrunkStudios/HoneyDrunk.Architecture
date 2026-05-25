---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "security", "docs", "adr-0056", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0056", "ADR-0039"]
accepts: ["ADR-0056"]
wave: 3
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Author SECURITY.md — org-level + per-public-repo copy template, 90-day disclosure window, safe-harbor

## Summary
Author the canonical `SECURITY.md` content the Grid commits to per ADR-0056 D11, in two surfaces: (1) the org-level file at `HoneyDrunkStudios/.github/SECURITY.md` (which GitHub surfaces on every repo without its own override), and (2) a per-public-repo copy template that any public Grid repo can adopt. Contents: `security@honeydrunkstudios.com` disclosure email, 90-day disclosure window commitment, explicit safe-harbor language modeled on Disclose.io core terms, out-of-scope list, no bug-bounty-at-v1 statement.

## Context
ADR-0056 D11 commits to a published responsible-disclosure surface. The two surfaces are GitHub's two surfaces for repo-level security info:

- **Org-level `SECURITY.md`** at `github.com/HoneyDrunkStudios/.github/SECURITY.md`. GitHub uses this as the default for every repo in the org that does not have its own `SECURITY.md`. This is the load-bearing artifact — a single edit propagates Grid-wide.
- **Per-public-repo `SECURITY.md`** copies. Public Grid repos may override the org-level file with a repo-specific policy. ADR-0056 D11 mentions per-public-repo copies; this packet produces the **canonical template** the public repos use, and lists which public repos should adopt it. Actual per-repo PRs are a downstream task per repo — this packet does not file PRs against every Grid repo.

ADR-0056 cross-references ADR-0039 (open-source license policy — Proposed) for the open-source posture: open-source Grid projects publish the same `SECURITY.md`; the org-level file applies to closed-source repos by default and is overridden only if a repo's specific posture differs. The org-level content fits both postures.

**Where the org-level file lives.** GitHub looks for the special `.github` repo at `github.com/HoneyDrunkStudios/.github` (a meta-repo, distinct from any project repo's `.github/` folder). This repo may or may not exist at scope time. The executor:

- If `HoneyDrunkStudios/.github` exists, file the org-level `SECURITY.md` there.
- If `HoneyDrunkStudios/.github` does not exist, create the repo (org-level meta-repo for shared GitHub configuration — `SECURITY.md`, organization profile README, default community health files) and seed it with `SECURITY.md`. Repo creation is a Human Prerequisite (the operator clicks through the GitHub New Repository UI per the user's portal-first preference).

**Why the org-level file is sufficient at v1.** Per-repo `SECURITY.md` files are a override of the org-level file. At v1, no Grid repo has a policy that diverges from the canonical org-level commitment — same disclosure email, same 90-day window, same safe-harbor. A single org-level file is therefore both necessary and sufficient. Per-public-repo copies become useful only if a specific repo's posture differs (e.g., a future Grid repo with a stricter disclosure window or a different out-of-scope list). This packet produces the template; per-repo adoption is deferred unless a divergence emerges.

**`security@honeydrunkstudios.com` mailbox provisioning.** ADR-0056 D11 names `security@honeydrunkstudios.com` as the disclosure email. This is an alias on `honeydrunkstudios.com` that needs to exist before researchers can use it. Mailbox provisioning is a Human Prerequisite — the operator configures the email-forwarding alias at the registrar/email provider (Cloudflare per ADR-0029 if DNS migration has occurred, otherwise the current DNS provider). The packet's text does not block on this — `SECURITY.md` shipping the email address before the mailbox exists is acceptable for the brief window between packet merge and operator mailbox config (a researcher would receive a bounce, which is a recoverable error and recorded as a Human Prerequisite to close).

**Safe-harbor language — Disclose.io core terms.** ADR-0056 D11 specifies that the safe-harbor language follows Disclose.io's core terms (https://disclose.io/), which the operator does not author from scratch. Disclose.io publishes the core safe-harbor language under permissive licensing for adoption. The executor pulls the current Disclose.io core safe-harbor text and embeds it in `SECURITY.md`. **Do not author novel legal language** — that is explicit in the ADR.

**This is a docs packet. No code, no .NET project.**

## Scope
- `HoneyDrunkStudios/.github/SECURITY.md` (the org-level surface — may require Human Prerequisite for repo creation).
- A per-public-repo `SECURITY.md` template, placed in this repo's `templates/` location (canonical: `issues/templates/` already exists in this repo, but a `SECURITY.md` template is documentation, not an issue template — place at `templates/security-md-template.md` or the established canonical-template-collection location, whichever the executor finds at edit time).
- `repos/HoneyDrunkStudios.github/` context folder in `HoneyDrunk.Architecture` (parallel to the existing `repos/HoneyDrunk.X/` folders) if the org-level meta-repo is created — short note recording the file inventory of `.github`.

## Proposed Implementation

### 1. Org-level `SECURITY.md` content

Author the file at `HoneyDrunkStudios/.github/SECURITY.md`. Content (Markdown):

```markdown
# Security Policy

HoneyDrunk Studios maintains a published responsible-disclosure policy for the HoneyDrunk Grid. This policy applies to every Grid repo unless that repo carries its own `SECURITY.md` that overrides this one.

## Reporting a vulnerability

Send vulnerability reports to `security@honeydrunkstudios.com`. Encrypt with the PGP key at {public key URL — TBD, surface as Human Prerequisite if PGP not yet set up}.

When reporting, please include:
- A clear description of the issue and which Grid repo or service is affected.
- Steps to reproduce, where applicable.
- Your name and a contact method for follow-up — anonymous reports are accepted; named reporters are credited unless they request otherwise.

## Disclosure window

HoneyDrunk Studios commits to one of the following within **90 days** of receiving a report:
- Ship a fix.
- Publicly acknowledge the issue with a planned remediation timeline.

The 90-day window is the default expectation. Researchers reporting an issue that requires longer to remediate may negotiate an extension; researchers preferring an accelerated timeline may negotiate a shorter window. The 90 days is the floor for response, not a hard contract.

## Safe harbor

{Embed the current Disclose.io core safe-harbor text verbatim — pull from https://disclose.io/, see Implementation Notes.}

In summary: good-faith research conducted under this disclosure policy is not pursued legally by HoneyDrunk Studios.

## Out of scope

The following are out of scope for this policy:
- Testing against production tenant data without explicit prior coordination.
- Denial-of-service testing against production infrastructure without explicit prior coordination.
- Social engineering attacks against HoneyDrunk Studios personnel or contractors.
- Physical attacks against HoneyDrunk Studios infrastructure.
- Findings in third-party services HoneyDrunk Studios depends on (Stripe, Azure, GitHub, vendor consoles). Report those to the vendor directly.
- Issues in repos archived or marked as not-receiving-updates.

## Bug bounty

HoneyDrunk Studios does **not** operate a paid bug-bounty program at this time. Reporters of valid vulnerabilities are credited publicly (unless they request anonymity) and may be acknowledged in the Grid's incident post-mortems. Cash bounties may be introduced when commercial revenue justifies the budget; this policy will be updated if and when that happens.

## Cross-references

This policy is the implementing surface for ADR-0056 D11 (Threat Model and Security Review Cadence — responsible disclosure). The substrate posture is documented in `constitution/threat-model.md` in the HoneyDrunk.Architecture repo (public).
```

### 2. Per-public-repo `SECURITY.md` template

Place a template file in this repo at a path that matches the existing template-collection convention. Verified at scope time, the existing `issues/templates/` directory holds GitHub-Issue templates (not documentation templates). Two options:

- **Option A:** create `templates/security-md.md` (new top-level templates directory parallel to `issues/templates/`).
- **Option B:** create a single template doc inside an existing meta-docs location — verify at edit time whether the repo has a `templates/` or `docs/templates/` convention; match it.

The template is **identical to the org-level content** with a header note:

```markdown
<!--
This SECURITY.md was adopted from the HoneyDrunk Studios org-level template per ADR-0056 D11.
If this repo's disclosure posture diverges from the org-level default (e.g., shorter disclosure window
for a high-sensitivity repo, different out-of-scope list), edit this file directly. Otherwise, the
org-level file at https://github.com/HoneyDrunkStudios/.github/SECURITY.md covers this repo by default
and this per-repo file is redundant.
-->
```

State explicitly in the template's header note: **at v1, no Grid repo has a policy that diverges from the org-level default.** Per-public-repo copies are not yet adopted as a Grid-wide pattern; the template exists so that a future divergence has a starting point.

### 3. Context folder for the meta-repo

If the `HoneyDrunkStudios/.github` meta-repo is created (Human Prerequisite), add a thin context folder at `repos/HoneyDrunkStudios.github/` in `HoneyDrunk.Architecture`:

```
repos/HoneyDrunkStudios.github/
  overview.md       (one paragraph naming the repo's role — org-level community health files)
  boundaries.md     (one paragraph naming what does and does not belong in .github — community
                     health files only; not code; not per-project workflows)
```

This mirrors the pattern set by the other `repos/HoneyDrunk.X/` context folders in this repo.

### 4. Disclose.io safe-harbor text

Pull the current Disclose.io core safe-harbor text at edit time (https://disclose.io/), embed verbatim in `SECURITY.md`. Do not author novel legal language. If the Disclose.io site has updated the core terms since 2026-05, use the current version.

## Affected Files
- `HoneyDrunkStudios/.github/SECURITY.md` (in the meta-repo, not this repo).
- A per-public-repo `SECURITY.md` template in the established templates location of this repo.
- Optional: `repos/HoneyDrunkStudios.github/overview.md` + `boundaries.md` in this repo if the meta-repo is created.

## NuGet Dependencies
None. This packet is documentation only; no .NET project.

## Boundary Check
- [x] The org-level `SECURITY.md` lives in the `HoneyDrunkStudios/.github` meta-repo — a sibling org-level repo, not `HoneyDrunk.Architecture` itself. Per ADR-0056 D11's explicit path.
- [x] The per-public-repo `SECURITY.md` template lives in this repo's templates location.
- [x] No code change in any Grid Node repo. Adoption of the per-public-repo template by specific repos is a downstream per-repo task, not part of this packet.

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/.github/SECURITY.md` exists with: `security@honeydrunkstudios.com` disclosure email; 90-day disclosure-window commitment with the negotiate-up-or-down language; the current Disclose.io core safe-harbor text embedded verbatim; the out-of-scope list (production tenant data, DoS testing without coordination, social engineering, physical attacks, third-party-vendor findings, archived repos); explicit no-paid-bug-bounty-at-v1 statement with the revenue-justifies-bounty condition; cross-reference to ADR-0056 D11 and `constitution/threat-model.md`
- [ ] A per-public-repo `SECURITY.md` template exists in this repo's established templates location, identical to the org-level content with the header note explaining that org-level default covers most repos
- [ ] If `HoneyDrunkStudios/.github` was created during this packet, a `repos/HoneyDrunkStudios.github/` context folder in this repo carries a one-paragraph `overview.md` + `boundaries.md`
- [ ] The safe-harbor text is Disclose.io core terms, embedded verbatim — no novel legal language authored by the operator or the agent
- [ ] No per-repo `SECURITY.md` is filed against any specific Grid repo by this packet — adoption is deferred unless a divergence emerges

## Human Prerequisites
- [ ] Create the `HoneyDrunkStudios/.github` meta-repo if it does not already exist (operator clicks through the GitHub "New repository" UI; the repo is public; the repo's role is community health files). The user prefers portal-first per the memory note.
- [ ] Configure the `security@honeydrunkstudios.com` email alias at the operator's email/DNS provider (Cloudflare per ADR-0029 if DNS migration has occurred, else the current provider). The mailbox forwards to the operator's primary inbox; researchers' reports must reach the operator's eyes within hours, not days.
- [ ] (Optional but recommended) Set up a PGP key for `security@honeydrunkstudios.com` and publish the public key. If skipped at v1, the `SECURITY.md` mentions the key as TBD and clear-text reports remain acceptable per existing best practice.
- [ ] Verify the embedded Disclose.io safe-harbor text against the current published version at https://disclose.io/ — re-fetch at edit time if more than a few weeks have passed since the original embedding.

## Referenced ADR Decisions
**ADR-0056 D11 — Responsible disclosure.** Published `SECURITY.md` at the org level + per-public-repo copies. Contents: `security@honeydrunkstudios.com` disclosure email, 90-day disclosure window, explicit safe-harbor language modeled on Disclose.io's core terms, out-of-scope list (no testing against production tenant data; no DoS testing without coordination), no bug bounty at v1.

**ADR-0039 (Proposed) — Grid open-source license policy.** Open-source Grid projects publish the same `SECURITY.md`; the org-level file applies to closed-source Grid repos by default and is overridden only if a repo's specific posture differs.

**ADR-0056 D11 "On the 90-day disclosure window."** The 90-day commitment matches the industry norm (Google Project Zero, most major vendors). Not unconditional — researchers may negotiate shorter or longer.

**ADR-0056 D11 "On the safe-harbor language."** Modeled on Disclose.io's core terms; the operator does not author novel legal language.

## Constraints
- **Use Disclose.io's core terms verbatim.** Do not author novel safe-harbor legal language. The operator's legal posture is "we use the published industry-standard safe-harbor template."
- **Org-level first; per-repo as template only.** The org-level `SECURITY.md` is the load-bearing file. The per-public-repo template is for future divergence, not for immediate Grid-wide adoption.
- **`security@honeydrunkstudios.com` is named in the file even if the mailbox isn't yet provisioned.** The Human Prerequisite covers mailbox provisioning; a brief window between PR merge and mailbox setup is acceptable (bounce-error is recoverable).
- **No bug bounty at v1 is explicit, not implicit.** The file states the no-bounty posture with the trigger condition (revenue-justifies-bounty). Researchers reading the file know the answer rather than assuming.
- **No PR filed against any specific Grid repo.** Per-public-repo adoption is deferred. Filing PRs against the 10+ public Grid repos is out of scope; the template exists so that future per-repo work has a known starting point.

## Labels
`feature`, `tier-2`, `meta`, `security`, `docs`, `adr-0056`, `wave-3`

## Agent Handoff

**Objective:** Author the canonical responsible-disclosure surface — org-level `SECURITY.md` in `HoneyDrunkStudios/.github` + per-public-repo template — committing to `security@honeydrunkstudios.com`, 90-day disclosure, Disclose.io safe-harbor, explicit out-of-scope list, no-bug-bounty-at-v1.

**Target:** `HoneyDrunk.Architecture` (template), `HoneyDrunkStudios/.github` (org-level file — see Human Prerequisites for repo creation).

**Context:**
- Goal: Land the published responsible-disclosure surface so researchers know the Grid is open to engagement, and so prospect due-diligence checklists have a citable answer.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 3.
- ADRs: ADR-0056 D11 (primary); ADR-0039 (open-source posture — Proposed).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — hard. ADR-0056 must be Accepted before its published surface lands.

**Constraints:**
- Disclose.io core safe-harbor text embedded verbatim; no novel legal language.
- Org-level file is load-bearing; per-public-repo template is for future divergence.
- `security@honeydrunkstudios.com` named even if mailbox not yet provisioned (covered by Human Prerequisites).
- Explicit no-bug-bounty-at-v1 statement with revenue-justifies-bounty trigger.
- No PR filed against any specific Grid repo — adoption is deferred.

**Key Files:**
- `HoneyDrunkStudios/.github/SECURITY.md` (org-level — repo creation is a Human Prerequisite)
- A per-public-repo `SECURITY.md` template in this repo's established templates location

**Contracts:** None changed. Disclosure-surface content only.
