---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0054", "wave-4"]
dependencies: ["packet:10"]
adrs: ["ADR-0054", "ADR-0018"]
accepts: ["ADR-0054"]
wave: 4
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Amend the operator-agent prompt template to consult per-Node runbooks during incident mitigation

## Summary
Amend the operator-agent prompt template per ADR-0054 D10: include "consult `repos/{affected-node}/runbooks/` for the affected Node before suggesting mitigations" in the agent's instructions for the Investigating / Mitigating phases of an incident. The agent's prompt amendment is the integration point that turns the per-Node runbooks (packet 10's boilerplate + the per-Node fanout's content) into mitigation suggestions during a real SEV-1/2.

## Context
ADR-0054 D10 names the operator-agent integration explicitly: "The operator agent **consumes the runbooks** when generating mitigation suggestions during the Investigating / Mitigating phases of an incident. The agent's prompt template is amended (per ADR-0018) to include 'consult `repos/{affected-node}/runbooks/` for the affected Node before suggesting mitigations.' Runbook content quality directly affects operator-agent suggestion quality; runbook neglect is a feedback loop."

ADR-0018 is the **operator agent** standup ADR. The operator agent's prompt template lives where ADR-0018 establishes — likely `.claude/agents/operator.md` or `agents/operator/` in the Architecture repo (the exact location was set by ADR-0018's implementation; this packet locates and amends the established file).

**Two amendment scopes:**

1. **Investigating-phase guidance.** When the operator agent is suggesting investigation paths for a freshly-acked incident, the prompt instructs the agent to:
   - Identify the affected Node(s) from the incident record's `affected_nodes` field.
   - Read `repos/{affected-node}/runbooks/health-check.md` to know which endpoints / metrics to probe.
   - Read `repos/{affected-node}/runbooks/common-sev2-patterns.md` to know which diagnostic paths to suggest first.
2. **Mitigating-phase guidance.** When the operator agent is suggesting mitigations, the prompt instructs the agent to:
   - Read `repos/{affected-node}/runbooks/restart.md` for restart paths.
   - Read `repos/{affected-node}/runbooks/rollback.md` for rollback paths.
   - For Tier-0 Nodes (per ADR-0036), read `repos/{affected-node}/runbooks/escalation.md` if the runbooks' direct mitigations have not resolved the incident in the appropriate time.

**The amendment is additive.** ADR-0018's existing operator-agent surface is not rewritten — the runbook-consult instructions extend the existing prompt template. Match the existing convention for adding capability-specific instructions to the agent.

**Coordination with packet 10.** Packet 10 created the boilerplate scaffolds and the per-Node-packet template; the per-Node runbook fanout is a separate downstream initiative. Until the fanout completes, many Node `runbooks/` directories will be empty or carry only boilerplate. The agent's prompt must handle this gracefully — if the affected Node has no populated runbook, the agent says so and proceeds with generic best-practice mitigation rather than failing. The instruction text covers this.

**Hive-sync coupling.** Per ADR-0011 D4 / invariant 33, the review-agent and scope-agent context-loading sets are coupled. The operator agent's context-loading set is also coupled to its prompt template — the runbook-consult instructions are visible only if the agent reads its own prompt file at execution time, which the cloud-execution surface (ADR-0018) handles. Confirm at edit time that the prompt amendment lands in the file the cloud-execution surface reads.

**This is a docs/governance packet.** No code, no .NET project. The amendment lives in the operator-agent prompt file.

## Scope
- The operator-agent prompt template (likely `.claude/agents/operator.md` or the equivalent ADR-0018-established location — locate at edit time).
- A small note in `business/context/` (or the equivalent operator-facing reference) cross-linking the amendment to D10.

## Proposed Implementation
1. **Locate the operator-agent prompt template.** Per ADR-0018, the operator-agent prompt lives in `.claude/agents/operator.md` or the equivalent. At edit time, locate the file by searching the Architecture repo for the operator-agent prompt — the file name and structure follow the ADR-0044-established review-agent convention (`.claude/agents/{agent-name}.md`). If the operator-agent file does not yet exist (ADR-0018 may be Proposed without full implementation), this packet **conditionally creates** a stub file with the D10 amendment as its incident-handling section, and notes the dependency on ADR-0018's full standup.
2. **Add the runbook-consult instruction.** Append (or extend the existing "Incident Mitigation" / "Operator Tasks" section, if one exists) with:
   - **Investigating phase:** "When investigating an open incident, identify the affected Node(s) from the incident record's `affected_nodes` field. For each affected Node, read `repos/{node}/runbooks/health-check.md` to know which endpoints and metrics to probe, and `repos/{node}/runbooks/common-sev2-patterns.md` to know which diagnostic paths to suggest first. If the runbook is empty (only boilerplate) or absent, note this in the suggestion and fall back to generic Grid-wide best practices."
   - **Mitigating phase:** "When suggesting mitigations, read `repos/{node}/runbooks/restart.md` for restart procedures and `repos/{node}/runbooks/rollback.md` for rollback procedures. For Tier-0 Nodes per ADR-0036 (Vault, Audit, Notify Cloud tenant data), also read `repos/{node}/runbooks/escalation.md` if the direct mitigations do not resolve the incident within the SEV-appropriate ack/resolve window."
   - **Graceful-empty handling:** "If a runbook file does not exist or contains only the boilerplate TODO placeholders from `_templates/runbooks/`, treat it as absent. Suggest filling it in as a post-incident follow-up per the D10 freshness rule."
   - **Cross-link to D10 / D11.** Note the runbook-content-quality feedback loop from D10 ("runbook neglect is a feedback loop") and the game-day exercise (D11) as the discipline that keeps runbooks fresh.
3. **Coordinate with the review-agent and scope-agent context-loading contracts.** The review agent's context-loading set is a superset of the scope agent's (invariant 33). The operator agent's prompt amendment is not part of either set — it lives in the operator-agent's own prompt file — so this packet does not need to mirror anything in the review or scope agent files. Confirm this is correct at edit time; if the operator agent shares prompt content with another agent (via include / shared template), the amendment may need to land in the shared file.
4. **`business/context/` cross-link.** Add a short note (or extend the existing telemetry/operator note from ADR-0040/0045 packets) cross-linking to the operator-agent runbook-consult amendment. This makes the integration point discoverable from operator-facing context, not just from the agent file.
5. **No new ADR or invariant.** ADR-0018 governs operator-agent surface; ADR-0054 D10 is the source of this amendment. Reference both.

## Affected Files
- `.claude/agents/operator.md` (or the equivalent ADR-0018-established location — located at edit time)
- `business/context/` (small cross-link note)
- If a shared prompt-template file exists (e.g., an `agent-instructions.md` shared across agents), it may be the right home for the amendment — match the existing convention.

## NuGet Dependencies
None. This packet touches only Markdown governance/agent files; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` — `.claude/agents/operator.md` (or equivalent) and `business/context/` both live here. Routing rule "architecture, ADR, agent, sector → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] The operator agent's prompt amendment extends the existing ADR-0018-established surface — does not fork it.
- [x] No runbook content is created in any Node repo by this packet — that is the per-Node fanout from packet 10.

## Acceptance Criteria
- [ ] The operator-agent prompt template (located by searching the Architecture repo at edit time — likely `.claude/agents/operator.md`) carries the runbook-consult instruction: read `repos/{node}/runbooks/health-check.md` + `common-sev2-patterns.md` during Investigating; read `restart.md` + `rollback.md` (+ `escalation.md` for Tier-0) during Mitigating
- [ ] The instruction handles the empty / boilerplate / absent runbook case gracefully — agent notes the gap and falls back to Grid-wide best practices, suggests filling in as a post-incident follow-up per the D10 freshness rule
- [ ] The amendment extends the existing operator-agent surface; does not fork it
- [ ] If the operator-agent file does not exist (ADR-0018 not yet fully implemented), a stub file is created with the D10 amendment as its incident-handling section; the dependency on ADR-0018's full standup is documented in the PR
- [ ] `business/context/` carries a short note cross-linking to the operator-agent runbook-consult amendment, discoverable from operator-facing context
- [ ] No runbook content created in any Node repo — that is the per-Node fanout
- [ ] No invariant change (the runbook-set invariant lives in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0054 D10 — Operator-agent integration.** "The operator agent consumes the runbooks when generating mitigation suggestions during the Investigating / Mitigating phases of an incident. The agent's prompt template is amended (per ADR-0018) to include 'consult `repos/{affected-node}/runbooks/` for the affected Node before suggesting mitigations.' Runbook content quality directly affects operator-agent suggestion quality; runbook neglect is a feedback loop."

**ADR-0054 D6 — Incident lifecycle.** The Investigating and Mitigating phases are explicit states in the lifecycle; the operator agent is active during both.

**ADR-0054 D10 — Runbook freshness.** Runbooks older than 90 days untouched are flagged in the nightly `hive-sync` report. The amendment instructs the agent to surface the freshness gap during incident handling as a post-incident follow-up.

**ADR-0018 — Operator agent standup.** ADR-0018 governs the operator agent's prompt-template surface. The amendment extends, does not fork, the existing prompt.

**ADR-0036 — Tier classification.** Tier-0 Nodes have `escalation.md` in their runbook set; the agent reads `escalation.md` only for Tier-0 affected Nodes.

## Constraints
- **Extend, do not fork, the operator-agent prompt.** The runbook-consult instructions join the existing operator-agent surface — match the established format. If the file does not yet exist (ADR-0018 not fully implemented), create a stub with the D10 amendment as its incident-handling section.
- **Graceful-empty handling.** Agent must handle absent / boilerplate-only runbooks without failing.
- **No runbook content here.** The per-Node fanout (downstream of packet 10) creates runbook content. This packet wires the agent to *read* the runbooks.
- **No invariant change here.** The runbook-set invariant lives in packet 00.
- **Hive-sync coupling note.** Operator-agent prompt content is not part of the review/scope agent context-loading contracts; confirm at edit time.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0054`, `wave-4`

## Agent Handoff

**Objective:** Amend the operator-agent prompt template (per ADR-0018) to consult `repos/{affected-node}/runbooks/` during the Investigating / Mitigating phases of an incident, with graceful handling of empty / absent runbooks.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the per-Node runbook content (packet 10 + the per-Node fanout) actionable during a real SEV-1/2 — the operator agent reads the runbooks and translates them into mitigation suggestions.
- Feature: ADR-0054 Incident Response rollout, Wave 4.
- ADRs: ADR-0054 D10 (primary), ADR-0018 (operator agent surface), ADR-0036 (tier classification — Tier-0 reads `escalation.md`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:10` — hard. The per-Node runbook playbook + boilerplate templates must exist before the agent can be told to read them.

**Constraints:**
- Extend, don't fork, the operator-agent prompt.
- Graceful-empty handling for absent / boilerplate-only runbooks.
- No runbook content in this packet.
- No invariant change in this packet.

**Key Files:**
- `.claude/agents/operator.md` (or equivalent — locate at edit time)
- `business/context/` (cross-link note)

**Contracts:** None changed.
