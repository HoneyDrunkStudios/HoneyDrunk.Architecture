---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0046", "wave-2"]
dependencies: ["work-item:01", "work-item:02"]
adrs: ["ADR-0046", "ADR-0044", "ADR-0031", "ADR-0005", "ADR-0009", "ADR-0007"]
accepts: ["ADR-0046"]
wave: 2
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Author the `security` specialist agent (security review)

## Summary
Author `.claude/agents/security.md` — the security-review specialist agent. Its lens is security: OWASP top 10, threat modeling, auth/secret/PII handling, supply chain, injection surfaces, and trust-boundary integrity. It is the **second** specialist authored per ADR-0046 D8 priority order; ADR-0046 D10 Phase 2.

## Context
ADR-0046 D8 places `security` second: it applies to ADR-0034 (NuGet signing), ADR-0037 (Stripe integration), ADR-0038 (sender deliverability), and ongoing Auth/Vault/public-API/dependency PRs that are routine but not constant. The generalist `review` agent covers category 9 (Security) broadly; the `security` specialist deepens it with OWASP rigor and threat-modeling discipline a generalist cannot apply within the per-PR cost budget.

This packet depends on packet 02, which authors `copilot/specialist-review-rules.md` — the definition-file template (mandatory section zero YAML frontmatter plus the six D4 prose sections) `security.md` must follow.

## Scope
- `.claude/agents/security.md` — **new file.** The `security` specialist agent definition, following the section-zero-plus-six-section template.
- No change to `constitution/agent-capability-matrix.md` — the `security` row stays "planned" here. The five matrix rows are flipped to "live" together in packet 08, after all five definition files exist, to avoid concurrent edits to the same table region.
- No change to `review.md` or any other agent file.

## Proposed Implementation
`security.md` follows the template from `copilot/specialist-review-rules.md` — a mandatory **section zero: YAML frontmatter**, then the six D4 prose sections.

**Section zero — YAML frontmatter (mandatory).** The file MUST open with a `---`-delimited YAML block before any prose; without it Claude Code will not register the agent. Match the shape of every existing agent definition in this repo (see `.claude/agents/review.md`):
- `name: security`
- `description:` — a folded scalar (`>-`) describing the security-review lens and when to invoke `security` (PRs/packets touching Auth, Vault, tenant boundaries, public APIs, dependency updates).
- `tools:` — exactly `Read`, `Grep`, `Glob`, `WebSearch`. `security` is a review-only agent: it reads code and produces advisory findings, it does not modify the repo. Do NOT include `Edit`, `Write`, `Bash`, or `Agent`.

The six D4 prose sections follow:

1. **Identity and scope.** Lens: security review. **In scope:** OWASP top 10, threat modeling, authentication/authorization handling, secret handling, PII handling, supply-chain risk, injection surfaces, trust-boundary integrity. **Out of scope:** AI/agent-specific safety concerns (prompt injection, tool-permission scoping, agent guardrails) — those belong to the `ai-safety` agent. Note the deliberate adjacency: an AI-Node PR may warrant both `security` and `ai-safety`; the human invokes both when both lenses apply.
2. **Mandatory context load.** The subject (PR diff or `scope` packet), plus the security-relevant Grid context: the Grid's secret-handling invariants (Vault is the only source of secrets; secret values never appear in logs/traces/exceptions/telemetry), the tenant-boundary invariants, the Auth posture (Auth validates tokens, never issues them), and the dependency-update posture from ADR-0009.
3. **Rubric — the security checklist.** Author it against recognized practice: OWASP top 10 coverage (injection, broken auth, sensitive-data exposure, etc.); threat-model questions (what is the trust boundary, what crosses it, who can reach this surface); secret-handling (no hardcoded secrets, all access via `ISecretStore`, no secret values in logs/traces); PII-handling (redaction before persistence or logging); supply-chain (new dependency provenance, lockfile discipline, the ADR-0009 alerts-yes/auto-PRs-no stance); injection-surface review (every external input crossing a trust boundary). The rubric is parallel to but **deeper than** ADR-0044 D3's category 9 — name that category touchpoint explicitly.
4. **Severity taxonomy.** `Block` / `Request Changes` / `Suggest`, identical to `copilot/pr-review-rules.md`. State the advisory posture per the new ADR-0046 invariant.
5. **Output format.** A structured verdict: an overall security-posture summary, then findings grouped by severity, each naming the specific vulnerability class and a remediation.
6. **Trigger conditions (described, not enforced).** PRs touching Auth (ADR-0031), Vault (ADR-0005/0006), tenant boundaries (ADR-0026), public APIs, and dependency updates (ADR-0009). State that at v1 the human is the trigger.

**Upstream-awareness section (D5).** `security.md` must describe its authoring-time use case: invoked against a `scope` agent's packet for any Auth/Vault/tenant-boundary work, `security` surfaces threat modeling **before code is written**. State the load-bearing intent — surfacing a trust-boundary gap at packet-scoping time costs a packet revision; surfacing it after the code ships costs an incident plus a fix.

## Affected Files
- `.claude/agents/security.md` (new)

## NuGet Dependencies
None. This packet creates and edits Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); it lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `.claude/agents/security.md` exists and follows the template from `copilot/specialist-review-rules.md` — section zero (YAML frontmatter) plus the six D4 prose sections
- [ ] The file opens with a YAML frontmatter block: `name: security`, a `description:`, and `tools:` set to exactly `Read, Grep, Glob, WebSearch` (no `Edit`/`Write`/`Bash`/`Agent`)
- [ ] The rubric covers OWASP top 10, threat modeling, secret/PII handling, supply chain, injection surfaces, and trust-boundary integrity
- [ ] The file names the ADR-0044 D3 category touchpoint it deepens (category 9, Security)
- [ ] The file explicitly scopes AI/agent-specific safety OUT (that is the `ai-safety` agent's lens) and notes both may apply to one AI-Node PR
- [ ] The upstream-awareness section describes the `scope`-packet threat-modeling use case
- [ ] The severity taxonomy is `Block`/`Request Changes`/`Suggest` and the file states findings are advisory
- [ ] No edit to `constitution/agent-capability-matrix.md` in this packet — the `security` row stays "planned"; the matrix flip to "live" is consolidated into packet 08
- [ ] The repo-level `CHANGELOG.md` gets an entry for the new agent

## Human Prerequisites
- [ ] After this PR merges, **re-sync the global agent hardlinks** so `security` registers in `~/.claude/agents/`. A newly added Architecture agent file is not picked up until the hardlink re-sync command is run and Claude Code is restarted.

## Dependencies
- `work-item:01` — ADR-0046 acceptance.
- `work-item:02` — the specialist-agent pattern doc and the definition-file template (section zero plus the six D4 sections).

## Referenced ADR Decisions

**ADR-0046 D2** — `security` is the security-review specialist; OWASP is the body of practice it draws on.
**ADR-0046 D4** — Six prose-section definition-file structure, preceded by a mandatory section zero — YAML frontmatter — required for the file to register in Claude Code.
**ADR-0046 D5** — Upstream-aware: `security` invoked against a `scope` packet surfaces threat modeling before code is written.
**ADR-0046 D7** — `security` deepens category 9 (Security) — same lens, more rigor; no category removed or downgraded.
**ADR-0046 D8 / D10** — `security` is the second specialist authored; Phase 2.
**ADR-0044** — The generalist `review` rubric `security` deepens; not amended.
**ADR-0009** — Dependabot stance: alerts yes, auto-PRs no; the supply-chain rubric reflects this.

## Constraints
> **New ADR-0046 invariant:** Specialist review agents are advisory and complementary to the `review` agent. `security` findings do not gate merge — the human is the final arbiter. The agent file must state this posture.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The `security` rubric must check for violations of this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs — all access goes through `ISecretStore`. The `security` rubric must check for violations of this.

- **Do not duplicate the `ai-safety` lens.** Prompt injection, tool-permission scoping, and agent guardrails are out of `security`'s scope.
- **Follow the packet-02 template.** Use the section-zero-plus-six-section structure, not an ad-hoc layout. Section zero (YAML frontmatter with `name`/`description`/`tools`) is mandatory — a file without it does not register in Claude Code.
- **Do not edit `constitution/agent-capability-matrix.md`** — the matrix flip is consolidated into packet 08.

## Labels
`docs`, `tier-2`, `meta`, `adr-0046`, `wave-2`

## Agent Handoff

**Objective:** Author `.claude/agents/security.md` — the security-review specialist agent — following the template (section zero YAML frontmatter plus the six D4 prose sections).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the second specialist agent (ADR-0046 D8 priority #2); applicable to ADR-0034/0037/0038 reviews.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 2.
- ADRs: ADR-0046 (primary), ADR-0044 (baseline rubric), ADR-0031 (Auth), ADR-0005 (Vault), ADR-0009 (dependency stance), ADR-0007 (agent source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0046 acceptance.
- `work-item:02` — the specialist-agent pattern doc and template.

**Constraints:**
- AI/agent-specific safety is out of scope (that is `ai-safety`).
- The rubric must check invariants 8 and 9 (secret handling).
- Follow the packet-02 template: mandatory YAML frontmatter section zero (`tools: Read, Grep, Glob, WebSearch`) plus the six D4 prose sections.
- Do not edit `constitution/agent-capability-matrix.md` — the matrix flip is consolidated into packet 08.

**Key Files:**
- `.claude/agents/security.md` (new)
- `.claude/agents/review.md` (frontmatter-shape reference)
- `copilot/specialist-review-rules.md` (template reference)

**Contracts:** None.
