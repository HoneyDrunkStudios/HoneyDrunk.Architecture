# Charter-Aware ADR and Node Candidate Surface

**Date:** 2026-05-23
**Branch:** `claude/adr-nodes-architecture-Lbg7F`
**Author:** adr-composer (deep-dive ideation pass)
**Status:** Draft for operator review — nothing here is committed. Items the operator green-lights move into the proper composer/scope flow.

---

## Reading guide

This is a candidate-surfacing document. The brief was *"don't worry about over-engineering — do as much upfront as possible."* The goal is to **maximize coverage** of every gap the new charter (`constitution/charter.md`) makes visible or higher-priority, while explicitly avoiding duplication with the 69 ADRs, 8 PDRs, and 1 BDR already on file.

The charter's load-bearing shifts:

- **Workshop, not startup.** Sunsetting is normal. Maintenance mode is a valid steady state. Kill clocks are out; decision points are in.
- **Many-decade horizon.** Investments amortize across decades. Vendor exits, archival, and operator-memory persistence are now correctly-sized concerns, not premature optimization.
- **AI multiplier bet.** A solo dev plus a long-running AI fleet is the productive unit. Tooling and observability for the fleet itself is now load-bearing.
- **Portfolio model.** No upper bound on PDR count. The substrate must carry many parallel projects in three lifecycle states (Active / Maintenance / Sunset).
- **Build-in-public, honestly.** Failed experiments, post-mortems, drift reports are surfaces — and need first-class governance.
- **Bus-factor-of-1.** Family emergencies and multi-week absences are realistic scenarios the Grid must keep running through.
- **Foundation-as-public-artifact.** The Grid is built to a level a serious engineer would respect, in the open.

Everything below derives from one or more of those clauses.

---

## Coverage baseline

What is **already covered** by ADRs 0001–0069 and PDRs 0001–0008 (so I deliberately do not propose duplicates):

| Domain | Covered by |
|---|---|
| Identity / user record | ADR-0060 (Identity Node) |
| Distributed cache | ADR-0058 / ADR-0059 (Cache Node) |
| File / blob storage | ADR-0061 (Files Node) |
| Billing / payments | ADR-0037 (Billing Node, Stripe) |
| Idempotency | ADR-0042 |
| Webhook receive | ADR-0062 |
| Time / clock | ADR-0063 |
| Local dev orchestration | ADR-0065 (Aspire stance) |
| Health endpoints | ADR-0066 |
| Rate limiting | ADR-0067 |
| Background jobs | ADR-0068 |
| Currency / money | ADR-0069 |
| PR review, AI-authored discipline | ADR-0011, ADR-0044, ADR-0046 |
| Testing patterns | ADR-0047 |
| Telemetry / errors | ADR-0040, ADR-0045 |
| DR / backups | ADR-0036 |
| OSS license posture | ADR-0039 |
| Audit substrate | ADR-0030, ADR-0031 |
| Communications / Notify split | ADR-0019 |
| Container platform | ADR-0015 |
| Cloudflare edge / DNS | ADR-0029 |
| Multi-tenant primitives | ADR-0026 |
| Schema evolution | ADR-0048 |
| PII / classification | ADR-0049 |
| Tenant lifecycle | ADR-0050 |
| AI agent authz / tool scoping | ADR-0051 |
| Cost governance / kill switches | ADR-0052 |
| Environments / cadence | ADR-0053 |
| Incident response (one-person) | ADR-0054 |
| Feature flags | ADR-0055 |
| Threat model / security cadence | ADR-0056 |
| Public HTTP API versioning | ADR-0057 |
| Prompt / persona registry | ADR-0064 |
| AI model registry | ADR-0041 |
| Mailbox / entity | BDR-0001 |

What is **uncovered** (the hunting ground for this document):

- Charter-specific lifecycle artifacts (portfolio governance, sunset playbook, maintenance-mode SLA)
- Many-decade artifacts (vendor exit, archival, operator-memory persistence, format preservation)
- AI-multiplier substrate (agent-fleet observability, long-running session memory, transcript governance, embedding versioning)
- Workshop ergonomics (DX baseline, doc-freshness contract, cross-Node refactor playbook)
- Build-in-public surfaces (failed-experiments shelf, Grid-wide changelog aggregator)
- Cross-PDR shared consumer capabilities (search, geo, realtime, push, analytics, i18n, mobile baseline)
- The four empty Sectors (HoneyNet, Creator, Market, HoneyPlay) and the Cyberware foundation
- Family-emergency / multi-week-absence operating mode

---

## Cluster 1 — Project lifecycle & portfolio governance

The charter introduces three explicit project states (Active / Maintenance / Sunset). Nothing in the constitution operationalizes them. This cluster fixes that.

### 1.1 Project Lifecycle and State Model (Active / Maintenance / Sunset)

- **Type:** ADR
- **Charter hook:** "Projects exist in three states: Active, Maintenance, Sunset … Sunsetting a project is not a failure."
- **Why it matters:** Today every Node has a `signal` (Seed/Awake/Wiring/Live/Echo) that describes its build phase, but no lifecycle state that describes its **project status**. A Live Node could be Active, Maintenance, or pre-sunset and we have no field, no SLA delta, and no governance. This is the most-cited charter clause without an artifact.
- **Coverage check:** ADR-0050 (Tenant Lifecycle) covers tenants, not projects. ADR-0054 (Incident Response) assumes Active. ADR-0036 DR tiers (T0/T1/T2) describe disaster posture, not project intent. No overlap.
- **Rough scope/size:** Medium — ADR + one catalog packet (add `project_state` field to `nodes.json` + PDR/BDR frontmatter)
- **Priority signal:** **Now** — every other governance ADR below depends on this taxonomy

### 1.2 Sunset Playbook for Nodes, Services, and PDRs

- **Type:** ADR
- **Charter hook:** "Sunset projects without ceremony" + "Repo archived (still public per the build-in-public stance), infrastructure torn down, learnings captured."
- **Why it matters:** When (not if) Notify Cloud or Hearth or a future PDR is sunset, what happens to the repo, the canary tests in dependent Nodes, the catalog entries, the open packets, the running infrastructure, the audit retention, the tenant data, and the public-facing Studios listing? Today, nothing.
- **Coverage check:** ADR-0050 D-* covers tenant-data exit; this ADR is the **project-level** counterpart. ADR-0049 covers retention schedules. ADR-0039 (license) governs what license terms persist post-sunset.
- **Rough scope/size:** Medium — ADR + one runbook packet (the actual playbook lives in `routing/` as a procedure)
- **Priority signal:** **Soon** — no sunset is imminent, but writing the playbook before it's needed is the charter-shaped move

### 1.3 Maintenance-Mode SLA Contract

- **Type:** ADR
- **Charter hook:** "A commercial trial that didn't catch on can keep running for the operator's own use indefinitely. That is a valid steady state."
- **Why it matters:** A Maintenance-mode Node should have lower CI cadence, lower DR tier, lower test-coverage floor, no auto-bump on Kernel breaking changes, and explicit "no new features" labeling. Without this, every project drifts into "Active by default" and consumes attention proportional to its codebase, not its current value.
- **Coverage check:** Adjoins ADR-0036 (DR tiers) and ADR-0047 (coverage thresholds). Both index by Node criticality, not by lifecycle state. ADR-0035 (abstractions versioning) needs a Maintenance-mode rule for "deprecate-but-don't-break."
- **Rough scope/size:** Medium — ADR that adjusts thresholds in 3–4 existing ADRs by reference; one catalog packet adding `maintenance_since` and `maintenance_sla` fields
- **Priority signal:** **Soon** — needed before the first deliberate Maintenance transition

### 1.4 Portfolio Health Scorecard

- **Type:** ADR
- **Charter hook:** Portfolio model § "is this still serving its purpose — use, learning, craft, or revenue?"
- **Why it matters:** The charter explicitly names four success vectors (use, learning, craft, revenue). A per-project scorecard that tracks each — and surfaces when a project should be considered for state transition — is the operational form of the charter's framing. Otherwise the charter is a doc, not a process.
- **Coverage check:** ADR-0043 (continuous backlog generation) produces work-item signal. This is the orthogonal **project-level** signal. No overlap.
- **Rough scope/size:** Large — ADR + new file `governance/portfolio-scorecard.md` + quarterly review cadence; possibly a small dashboard in Studios
- **Priority signal:** **Soon** — pairs with 1.1 and 1.3

### 1.5 Charter-Conformance Review for ADRs/PDRs/BDRs

- **Type:** ADR (process)
- **Charter hook:** Charter § "How to read other docs in light of this" — explicit instruction that the charter is the tiebreaker.
- **Why it matters:** The charter forbids "quietly drifting into startup logic." A standing review checkpoint — every accepted ADR/PDR explicitly cites which charter clauses it leans on or against — is the antibody. Currently no ADR cites the charter at all.
- **Coverage check:** ADR-0046 (specialist review agents) names a future role but doesn't fix a process. ADR-0044 D3 has a 20-category rubric — adding a "charter alignment" category is the smallest version of this.
- **Rough scope/size:** Small — ADR amending ADR-0044 D3 rubric + ADR/PDR/BDR templates
- **Priority signal:** **Now** — cheap and high-leverage

### 1.6 PDR / BDR Promotion and Demotion Process

- **Type:** ADR
- **Charter hook:** Charter § Portfolio model — "deliberately decide: keep active, drop to maintenance, or sunset gracefully."
- **Why it matters:** Decision points need a defined ritual: who decides, what evidence is required, what cadence. Today PDRs go Proposed → Accepted but the inverse path (Accepted → Maintenance, Accepted → Sunset) is undefined.
- **Coverage check:** PDR-0008 supersedes PDR-0004/0007 — there is informal precedent. This ADR formalizes it.
- **Rough scope/size:** Small — ADR + addendum to PDR README
- **Priority signal:** **Soon**

---

## Cluster 2 — Many-decade horizon

These investments amortize across the planned multi-decade horizon. They are over-investments for a 12-month startup; they are correctly-sized here.

### 2.1 Vendor-Exit Playbooks (Azure, Cloudflare, Stripe, Anthropic/OpenAI, GitHub)

- **Type:** ADR
- **Charter hook:** "If the bet were wrong — if AI capability plateaued or got gated — the Grid's pace would slow. It wouldn't die." Generalizes to any vendor lock.
- **Why it matters:** The Grid is increasingly Azure-centric (Container Apps, Key Vault, App Configuration, App Insights post-PR #164), Cloudflare-centric (ADR-0029), Stripe-centric (ADR-0037), and Anthropic/OpenAI-centric (ADR-0041). A many-decade horizon implies at least one of these vendors will become hostile or untenable. This ADR defines the **exit-readiness posture** per vendor (active hedge / documented-exit / accept-lock-in) and what mitigations exist.
- **Coverage check:** ADR-0036 (DR) covers region failover within a vendor, not vendor exit. ADR-0029 picks Cloudflare without an exit plan. ADR-0040/0045 picks Azure Monitor without an exit plan. No overlap.
- **Rough scope/size:** Large — one umbrella ADR + per-vendor sub-documents in `governance/vendor-exits/`
- **Priority signal:** **Soon** — write while leverage is still cheap (before lock-in compounds)

### 2.2 Repo Archival Policy and Mechanics

- **Type:** ADR
- **Charter hook:** "Repo archived (still public per the build-in-public stance)"
- **Why it matters:** GitHub `archived` is a one-way switch with cascade effects: PR creation is blocked, branch protection becomes moot, packages stop building, canary tests at dependents break silently. Need a defined order-of-operations.
- **Coverage check:** Adjoins 1.2 (Sunset Playbook) — this is the mechanical sub-step.
- **Rough scope/size:** Small — could be folded into 1.2 as a section, or stand alone
- **Priority signal:** **Eventually** — bundle with 1.2

### 2.3 Knowledge / Operator-Memory Persistence (the "what-the-operator-knew" archive)

- **Type:** ADR + Node (could ride on the existing Lore Node)
- **Charter hook:** "Long-running AI agents as collaborators" + many-decade horizon + bus-factor implicit.
- **Why it matters:** The operator's accumulated context — why-we-did-that, dead-ends, unstated invariants, vendor-conversation history, design-debate transcripts — currently lives in chat logs, scattered ADRs, and the operator's head. Over a decade this is the single largest erosion risk. Lore is positioned for this but is currently scoped as a wiki-ish thing. This ADR formalizes Lore (or a new sub-Node) as the **durable operator-memory archive** that survives Claude/Codex/Copilot session boundaries.
- **Coverage check:** Lore (Seed) exists in catalog. PDR-0001 hints at Knowledge-graph use. ADR-0064 (Prompt/Persona registry) is adjacent but not the same. ADR-0030 (Audit) is about action records, not narrative knowledge.
- **Rough scope/size:** Large — ADR that scopes Lore's actual mandate + initial ingest packets
- **Priority signal:** **Soon** — value compounds with age; start early

### 2.4 Format and Data Preservation (long-lived file formats and migration policy)

- **Type:** ADR
- **Charter hook:** Many-decade horizon — formats and SDKs that exist today may not in 20 years.
- **Why it matters:** Hearth produces user journals. Lately stores currents. Curiosities accumulates place-memory. Notify stores deliverability history. If any of these is in a proprietary or fragile format in 2026, in 2046 the data is unreadable. Establish: human-readable canonical exports, an annual "open everything" CI test, a documented format-migration policy.
- **Coverage check:** ADR-0048 (schema evolution) covers in-flight DB migrations, not multi-decade format preservation. ADR-0050 covers user data export at exit. No overlap.
- **Rough scope/size:** Medium — ADR + one packet to add a "long-read CI" workflow
- **Priority signal:** **Eventually** — high charter alignment, low immediate forcing function

### 2.5 Operator Succession / Bus-Factor Document

- **Type:** ADR or BDR-adjacent
- **Charter hook:** Implicit. Charter explicitly frames the studio as decades-long without specifying what happens if the operator can't operate.
- **Why it matters:** The Grid is built around one human. Every credential, registrar account, billing relationship, key vault, and signing identity is operator-controlled. Without a succession dossier (who to contact, where the recovery codes are, what to keep running, what to sunset, who owns the LLC), a single life event flushes the Grid.
- **Coverage check:** BDR-0001 (mailbox/entity) is in this domain — same legal-and-vendor surface. This would be the formal continuation. Likely a BDR.
- **Rough scope/size:** Medium — BDR + sealed-envelope physical/digital deposit
- **Priority signal:** **Soon** — disproportionate downside risk

### 2.6 "Two-Week Vacation" Auto-Operating Mode

- **Type:** ADR
- **Charter hook:** Charter § What this licenses — "Take time. There is no quarterly clock. Months-long pauses on individual projects are fine."
- **Why it matters:** What happens when the operator is offline for 14+ days? Today: paging fires into a void (ADR-0054 09:00–21:00 ET window). Alerts pile up. Tenant onboarding stalls. Drift accumulates. Defined "vacation mode" sets: degraded-but-honest tenant SLA, auto-snooze of non-critical alerts, automatic deferral of agent-authored PRs, public Studios banner.
- **Coverage check:** ADR-0054 mentions vacation only as a constraint — no formal off-mode. Adjacent to 1.3 (Maintenance-Mode SLA). Distinct because this is operator-level, not project-level.
- **Rough scope/size:** Medium — ADR + one packet to add vacation-mode toggles to Pulse/Notify/Operator
- **Priority signal:** **Soon**

---

## Cluster 3 — AI-multiplier infrastructure

The charter explicitly underwrites the AI bet. The substrate that makes the bet pay off needs deliberate investment.

### 3.1 Agent-Fleet Observability (cross-session, cross-agent)

- **Type:** ADR
- **Charter hook:** "AI agents as long-running collaborators" + AI multiplier
- **Why it matters:** Today we observe individual agent runs (per ADR-0044, ADR-0046, ADR-0051). We do not observe **fleet behavior** — week-over-week agent quality drift, tool-call frequency by agent, packet-acceptance rate per agent, cost-per-shipped-feature. Without this, the AI multiplier is a vibes-based bet.
- **Coverage check:** ADR-0040 (telemetry) covers transport; ADR-0045 (error tracking) covers failures; ADR-0046 (specialist agents) adds capacity. None aggregates a fleet-health view.
- **Rough scope/size:** Large — ADR + dashboard packets in Pulse/Studios
- **Priority signal:** **Now** — already operating a fleet; metric debt accruing

### 3.2 Agent Versioning and Lifecycle (deprecation, rollback)

- **Type:** ADR
- **Charter hook:** AI multiplier — agents are first-class citizens; their lifecycle should mirror Node lifecycle.
- **Why it matters:** `.claude/agents/` is the source of truth (ADR-0007), but agents have no version field, no changelog, no rollback path. When the `scope` agent makes a behavior change that produces lower-quality packets, there is no clean way to revert or A/B.
- **Coverage check:** ADR-0007 governs storage; this governs evolution. ADR-0064 (Prompt registry) is adjacent — prompts are versioned, but agent **prompt + capability-loading-rules + context-loading-list** is the full surface.
- **Rough scope/size:** Medium — ADR + tooling packet
- **Priority signal:** **Soon**

### 3.3 Long-Running Session Memory (cross-conversation persistence for Claude/Codex)

- **Type:** ADR + possibly a sub-Node on Memory
- **Charter hook:** "Long-running collaborators" + AI multiplier compounding over decades
- **Why it matters:** Each Claude Code session today starts fresh. Decades of context will accumulate, and tooling like skills + project knowledge is fragmented and ad-hoc. Define what cross-session persistence the operator wants, what the agents should never persist (per ADR-0049 PII), and what the substrate looks like.
- **Coverage check:** HoneyDrunk.Memory is **agent runtime** memory inside Grid systems; this is **operator-facing collaborator** memory. Distinct surface. ADR-0064 is prompts, not session state.
- **Rough scope/size:** Large — ADR + new Memory-adjacent contracts
- **Priority signal:** **Soon**

### 3.4 Model-Fallback and Degraded-Mode Contracts

- **Type:** ADR
- **Charter hook:** Vendor-exit hedge (cross-references 2.1) + AI plateau acceptable downside.
- **Why it matters:** When Anthropic has an outage, when OpenAI rate-limits, when a model is deprecated mid-roadmap — what does the Grid do? Define per-capability fallback chains and graceful degradation (e.g., AI-driven feature falls back to rule-based, with a banner). Today: undefined. Notify Cloud or Hearth running through a multi-day Anthropic outage is a category of incident with no playbook.
- **Coverage check:** ADR-0041 (model registry) defines the catalog. ADR-0052 (cost kill-switches) cuts off, not falls back. Gap is the fallback semantics.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon**

### 3.5 Embedding Versioning and Re-Indexing Policy

- **Type:** ADR
- **Charter hook:** Many-decade horizon — embeddings will be re-generated many times.
- **Why it matters:** HoneyDrunk.Knowledge and HoneyDrunk.Memory both store embeddings. When the underlying embedding model changes (new OpenAI model, switch from `text-embedding-3-small`), all prior embeddings become noise. Define: embedding-model identity field on every stored vector, re-index trigger, dual-write window, cost-budgeted re-embed pipeline.
- **Coverage check:** Knowledge/Memory ADRs (0021/0022) don't address this. ADR-0041 (model registry) catalogs models, doesn't govern data invalidation.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon** — required before Knowledge ships v1

### 3.6 Transcript / Conversation Governance (PII, retention, replayability)

- **Type:** ADR
- **Charter hook:** Build-in-public + AI ethics + ADR-0049 PII.
- **Why it matters:** Every Claude/Codex/Copilot session generates a transcript. Some are publishable (architecture debates); some contain user data; some contain operator secrets. Need: classification policy, retention schedule, public-archive procedure, redaction tooling.
- **Coverage check:** ADR-0049 covers PII in app data; transcripts are a category not addressed. ADR-0030 audit substrate covers actions, not transcripts.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon** — material for the public-failed-experiments shelf (cluster 5)

### 3.7 Inter-Agent Communication Protocol

- **Type:** ADR
- **Charter hook:** "AI agents as collaborators" — implies plural.
- **Why it matters:** `.claude/agents/` defines individual agents. They communicate today only via handoff documents and shared filesystem state. When the AI sector (Flow, Operator, Agents) goes live, the runtime equivalent needs a contract. This ADR scopes what inter-agent messages look like, idempotency, audit, supervision.
- **Coverage check:** ADR-0042 (idempotency) and ADR-0030 (audit) are the substrate. ADR-0017/0020/0024 (Capabilities/Agents/Flow Node standups) hint at runtime. Pure protocol-level ADR doesn't exist.
- **Rough scope/size:** Medium
- **Priority signal:** **Eventually** — wait for Agents Node to land

---

## Cluster 4 — Workshop ergonomics & substrate hygiene

The charter explicitly licenses spending on the foundation. These are the unglamorous-but-load-bearing items.

### 4.1 DX Baseline Per Node (`make repo`, `make test`, `make pack`, `make smoke`)

- **Type:** ADR
- **Charter hook:** "Building things this way is the craft. The discipline is intrinsic to the goal."
- **Why it matters:** Every Node should respond to the same five commands. Today: each Node has its own conventions. This ADR mandates a contract (probably a `Makefile` or `task` runner) so the operator and agents pay the same low cost to operate any Node.
- **Coverage check:** ADR-0065 (Aspire) is the multi-service local orchestrator; this is the per-repo entry point. Distinct but related.
- **Rough scope/size:** Medium — ADR + one packet per live Node (12 packets)
- **Priority signal:** **Soon** — DX debt compounds invisibly

### 4.2 Documentation Freshness Contract (`overview.md`, `boundaries.md`, `invariants.md`)

- **Type:** ADR
- **Charter hook:** Workshop ergonomics + build-in-public.
- **Why it matters:** Every repo has `overview.md`, `boundaries.md`, `invariants.md` in this Architecture repo. They drift relative to actual code. Define: doc-freshness CI check that fails when these files are >N days stale relative to the target repo's main branch.
- **Coverage check:** ADR-0014 (hive-sync) keeps catalogs aligned with packets, not with code. ADR-0043 (backlog generation) is adjacent. No direct coverage.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon**

### 4.3 Cross-Node Refactor Playbook

- **Type:** ADR
- **Charter hook:** Workshop ergonomics — the Grid Promise says any Node can do X; refactoring across Nodes needs to be cheap.
- **Why it matters:** Today, a contract change in `Kernel.Abstractions` cascades to 11+ repos with no defined choreography. Kernel Adoption Alignment (the 11/11-closed initiative) was that exact pattern, but every Kernel breaking change re-derives the playbook from scratch. Codify it.
- **Coverage check:** ADR-0035 (abstractions versioning) is the rule; this is the **procedure** for when the rule says "this is a breaking change." ADR-0028 (event-driven) and ADR-0019 (Comms split) are precedent.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon**

### 4.4 Local Catastrophe Runbooks (laptop dies, GitHub down, Azure region out, internet out)

- **Type:** ADR
- **Charter hook:** Many-decade horizon — every catastrophic scenario will happen at least once.
- **Why it matters:** What does the operator do if their laptop is bricked at 10pm? If GitHub is fully down for 24 hours? If `*.azure.com` is unreachable from FL? Define the off-substrate continuity plan.
- **Coverage check:** ADR-0036 (DR) covers Grid-side outages, not operator-side. ADR-0054 (incident response) assumes operator + GitHub are both up.
- **Rough scope/size:** Small — runbook lives in `routing/`
- **Priority signal:** **Eventually**

### 4.5 ADR / PDR / BDR Index and Search Surface

- **Type:** ADR (small)
- **Charter hook:** Decades of decisions accumulate. Findability is load-bearing.
- **Why it matters:** 69 ADRs today, growing weekly. Linear scan is already painful. A faceted index (by sector, by Node, by status, by charter clause) is overdue.
- **Coverage check:** `initiatives/proposed-adrs.md` is the live list; no read-side surface.
- **Rough scope/size:** Small — script-generated index file
- **Priority signal:** **Soon** — cheap, immediately useful

---

## Cluster 5 — Build-in-public surfaces

The charter expands "build-in-public" to include the boring and failed parts. These need first-class governance.

### 5.1 Public Failed-Experiments Shelf

- **Type:** ADR
- **Charter hook:** "Build-in-public here means showing the whole shape, including: Things we tried that didn't work."
- **Why it matters:** PDR-0004 and PDR-0007 are Superseded. ADR-0004 and ADR-0013 are Superseded. Today these are buried in supersession notes. A dedicated public surface ("the morgue", "the lab notebook") that surfaces what was tried and why it was retired is a charter-shaped artifact.
- **Coverage check:** ADR-0030 audit is internal. Studios website surfaces Nodes, not failed experiments.
- **Rough scope/size:** Medium — ADR + Studios page + sourcing convention
- **Priority signal:** **Soon**

### 5.2 Grid-Wide Changelog Aggregator

- **Type:** ADR
- **Charter hook:** Build-in-public + workshop ergonomics.
- **Why it matters:** 12 live Nodes each have a `CHANGELOG.md`. There is no aggregated "what shipped this week across the Grid" view. The Studios website does not surface this. The operator cannot scan it. The public cannot follow along.
- **Coverage check:** ADR-0014 (hive-sync) is adjacent but catalog-oriented. Per-repo changelogs are mandated by invariant 12; aggregation is not.
- **Rough scope/size:** Small — script + Studios page
- **Priority signal:** **Soon**

### 5.3 Public Post-Mortem Cadence and Format

- **Type:** ADR
- **Charter hook:** "Honest assessments of what's working and what isn't."
- **Why it matters:** `generated/incidents/` exists per CLAUDE.md. Cadence, format, public-vs-private classification, and redaction rules are not defined.
- **Coverage check:** ADR-0054 (incident response) creates incidents; this governs the **public artifact** of an incident.
- **Rough scope/size:** Small
- **Priority signal:** **Soon**

### 5.4 Public Roadmap Discipline (and what's allowed to be on it)

- **Type:** ADR
- **Charter hook:** Build-in-public + charter forbids "performing visibility instead of building."
- **Why it matters:** `initiatives/roadmap.md` is public. What goes on it? Only Accepted ADRs? PDRs at any stage? Speculative items? Today the answer is mixed. The charter framing ("vision is a direction, not a destination on a calendar") implies a different roadmap shape than what teams usually publish.
- **Coverage check:** Roadmap exists; this is governance.
- **Rough scope/size:** Small
- **Priority signal:** **Eventually**

---

## Cluster 6 — Cross-PDR shared capabilities

Recurring patterns across PDRs 0002/0003/0005/0006/0008 that deserve dedicated cross-cutting ADRs or Nodes. Each of these would otherwise be re-implemented in every consumer app.

| Capability | Required by | Proposed surface |
|---|---|---|
| **Search / full-text + faceted** | PDR-0003 (find currents), PDR-0006 (discover currents), PDR-0008 (find curiosities) | New Node: `HoneyDrunk.Search` (see 7.x) |
| **Geo / GIS / proximity** | PDR-0008 (city), PDR-0007 (superseded — but the geo signal stands), PDR-0005 (Hearth town tiles) | New Node: `HoneyDrunk.Geo` |
| **Realtime / presence / pub-sub fanout** | PDR-0003 (currents activity), PDR-0006 (social loop), PDR-0005 (town visit) | New Node: `HoneyDrunk.Realtime` |
| **Push notifications (mobile)** | All consumer PDRs | Extend HoneyDrunk.Notify provider slots **or** new Node |
| **User-facing payments + receipts + tax** | PDR-0005 (POD print), PDR-0006 (paid tier), PDR-0008 (paid tier) | Extend ADR-0037 (Billing) — see 6.1 |
| **Product analytics (opt-in, charter-aligned)** | All consumer PDRs | New Node: `HoneyDrunk.Signal` (see 7.x) |
| **i18n / l10n** | All consumer PDRs that ever ship outside US | New Node: `HoneyDrunk.Locale` |
| **Edge compute (Cloudflare Workers)** | PDR-0008 (city tile delivery), Studios | Extend ADR-0029 — see 6.2 |
| **Mobile (iOS/Android) baseline** | All consumer PDRs | New Node: `HoneyDrunk.Mobile` baseline kit |
| **Web frontend baseline (beyond Studios)** | Notify Cloud admin UI, Hearth web, others | New Node: `HoneyDrunk.Web.UI` |
| **Legal / consent / cookie / DSR runtime** | All consumer PDRs in EU/CA | New Node: `HoneyDrunk.Legal` |

### 6.1 User-Facing Payments Extension to ADR-0037

- **Type:** ADR (amends ADR-0037)
- **Charter hook:** Portfolio model — commercial trials are not one-shape.
- **Why it matters:** ADR-0037 covers **subscription billing** (Notify Cloud). PDR-0005 needs **one-shot Stripe Checkout** (POD purchase). PDR-0006/0008 need **paid-tier in-app subscription**. PDR-0003 may need **boost / one-time purchase**. These are five distinct billing shapes; ADR-0037 covers one.
- **Coverage check:** ADR-0037 — extends it.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon** (gated on first non-Notify-Cloud paid trial)

### 6.2 Edge-Compute Stance Extension to ADR-0029

- **Type:** ADR (amends ADR-0029)
- **Charter hook:** AI-multiplier + cost.
- **Why it matters:** ADR-0029 picks Cloudflare for DNS/edge but doesn't take a position on Workers. Consumer PDRs want low-latency reads at edge (PDR-0008 tile delivery, PDR-0003 currents preview). Define when Workers are appropriate vs. Container Apps origin.
- **Coverage check:** ADR-0029 — extends it.
- **Rough scope/size:** Medium
- **Priority signal:** **Eventually**

### 6.3 Push-Notification Provider-Slot Extension to HoneyDrunk.Notify

- **Type:** ADR (extends ADR-0019/Notify boundaries)
- **Charter hook:** Cross-PDR shared capability.
- **Why it matters:** Every consumer PDR needs push (APNs/FCM). Today Notify covers email/SMS only. The right move is a `HoneyDrunk.Notify.Providers.Push` slot, not a new Node — preserves Notify Cloud's commercial wedge.
- **Coverage check:** Notify owns delivery; this is a provider extension.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon**

---

## Cluster 7 — New consumer-product-driven Nodes

Each is a candidate; not all should be standing up. They are listed so the operator can pick which are first-class Nodes vs. capabilities folded into existing Nodes.

| # | Proposed Node | Sector | Signal class | Why a Node (not a folder in another Node) |
|---|---|---|---|---|
| 7.1 | **HoneyDrunk.Search** | Core | Seed | Distinct backing (Azure AI Search / Postgres FTS / Meilisearch); separable index lifecycle |
| 7.2 | **HoneyDrunk.Geo** | Core | Seed | Heavy domain (PostGIS / S2 / H3); independent test surface |
| 7.3 | **HoneyDrunk.Realtime** | Core | Seed | WebSocket / SignalR / Server-Sent-Events; horizontal scale model is different from Web.Rest |
| 7.4 | **HoneyDrunk.Push** | Ops | Seed | Could fold into Notify; standalone if push fan-out becomes a commercial wedge |
| 7.5 | **HoneyDrunk.Signal** (analytics) | Creator (or Ops) | Seed | Opt-in event collection separate from Pulse telemetry; charter requires creator-data discipline |
| 7.6 | **HoneyDrunk.Locale** | Core | Seed | i18n catalogs, locale fallback, translation-management interface — small but everywhere |
| 7.7 | **HoneyDrunk.Mobile** | Creator (or Core) | Seed | iOS/Android baseline: GridContext propagation, push wiring, auth flows, file pickers; MAUI vs. native is the first decision |
| 7.8 | **HoneyDrunk.Web.UI** | Creator | Seed | Reusable web frontend kit: design tokens, auth widgets, dashboards — for non-Studios apps |
| 7.9 | **HoneyDrunk.Legal** | Core | Seed | ToS/Privacy templates, consent capture, cookie banners, DSR runtime — load-bearing for any EU/CA exposure |
| 7.10 | **HoneyDrunk.Forge** (planned in `sectors.md` already) | Creator | Seed | Asset registry / import pipeline — needed once non-trivial creative work ships |
| 7.11 | **HoneyDrunk.Lifecycle** | Meta | Seed | Houses the lifecycle catalogs (project_state, dr_tier, license, abstractions_version) — could fold into Architecture |
| 7.12 | **HoneyDrunk.Portfolio** | Meta | Seed | Scorecard automation; could fold into Architecture |
| 7.13 | **HoneyDrunk.Telemetry.Aggregator** | Ops | Seed | "What shipped" + "what failed" dashboard substrate — could fold into Pulse |

**Recommended formalize-now subset:** 7.1 Search, 7.2 Geo, 7.3 Realtime, 7.5 Signal, 7.9 Legal, 7.7 Mobile baseline. The rest can be deferred or folded.

For each formalize-now candidate, the proposing ADR should specify boundaries / sector / signal / dependency direction following the ADR-0059–0061 pattern.

---

## Cluster 8 — AI sector deepening

The 9 AI Nodes are designed in `ai-sector-architecture.md`. There are interaction-gap ADRs worth surfacing.

### 8.1 Multi-Agent Coordination Protocol (Flow ↔ Agents ↔ Operator)

- **Type:** ADR
- **Charter hook:** AI-multiplier; multi-agent is the long-horizon shape.
- **Why it matters:** The sector doc describes each Node in isolation. The hand-offs (Flow asks Operator for approval, Operator returns decision, Flow resumes; Agent A produces context, Agent B consumes it) need a protocol-level ADR with correlation, retry, supervision.
- **Coverage check:** ADR-0024 (Flow standup), ADR-0018 (Operator standup), ADR-0020 (Agents standup) are vertical. This is horizontal.
- **Rough scope/size:** Medium
- **Priority signal:** **Eventually** (after the three Nodes are scaffolded)

### 8.2 Plan / Sim Integration with HoneyHub

- **Type:** ADR
- **Charter hook:** AI bet — autonomy with foresight.
- **Why it matters:** Sim Node exists in design as "pre-execution validation." The integration shape with HoneyHub (HoneyHub proposes a plan → Sim evaluates → Operator approves → Flow executes) is undefined.
- **Coverage check:** PDR-0001 hints at it; ADR-0025 (Sim standup) is a placeholder.
- **Rough scope/size:** Medium
- **Priority signal:** **Eventually**

### 8.3 Tool-Call Contract Versioning and Backwards Compatibility

- **Type:** ADR
- **Charter hook:** Many-decade horizon — tools evolve; agents bound to old contracts must keep working.
- **Why it matters:** Capabilities Node owns tool definitions. When a tool's schema changes, what happens to in-flight workflows? To running agents? Define backward-compat windows.
- **Coverage check:** ADR-0017 (Capabilities standup), ADR-0035 (abstractions versioning) are adjacent. This is the AI-specific extension.
- **Rough scope/size:** Medium
- **Priority signal:** **Eventually**

### 8.4 Agent Cost Attribution (per agent, per workflow, per tenant)

- **Type:** ADR
- **Charter hook:** Cost discipline + charter's "cost is a design constraint."
- **Why it matters:** ADR-0052 covers kill-switches at thresholds; ADR-0041 catalogs model rates. Per-agent attribution (which agent burned how much, on what work) is missing. Required for fleet-level decisions ("is the `node-audit` agent cost-justified?").
- **Coverage check:** Extends ADR-0052 and ADR-0041.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon**

---

## Cluster 9 — Cyberware / HoneyMech foundation

The Cyberware sector is empty. Robotics is a long-fuse charter direction. The minimum ADR set before this can credibly start:

### 9.1 Real-Time Boundary ADR (when Web.Rest stops being enough)

- **Type:** ADR
- **Charter hook:** Cyberware sector — "where code meets matter."
- **Why it matters:** REST is not real-time. Robotics requires sub-100ms loops, deterministic latency, possibly hard real-time. Define the Grid's stance: where does HTTP end and the real-time substrate begin? Adjoins 7.3 (Realtime Node).
- **Rough scope/size:** Medium
- **Priority signal:** **Park** until Cyberware has a concrete first project

### 9.2 Hardware Abstraction Layer (HAL) Boundary

- **Type:** ADR + Node
- **Charter hook:** Cyberware sector.
- **Why it matters:** HoneyMech.Servo / HoneyMech.Courier (planned) need a HAL abstraction analogous to Vault's provider slot. ROS2, raw GPIO, MQTT — what's the contract?
- **Rough scope/size:** Large
- **Priority signal:** **Park**

### 9.3 Sim-to-Hardware Contract (HoneyDrunk.Sim ↔ HoneyMech.Sim ↔ Servo)

- **Type:** ADR
- **Charter hook:** Cyberware sector.
- **Why it matters:** Plans that pass in Sim must transfer to hardware. Define the contract that prevents sim-to-real gaps from becoming silent.
- **Rough scope/size:** Large
- **Priority signal:** **Park**

### 9.4 Edge / On-Device Compute Stance (when the Grid runs outside Azure)

- **Type:** ADR
- **Charter hook:** Cyberware + AI-multiplier (on-device inference).
- **Why it matters:** Robotics runs on a Pi / Jetson / embedded. The Grid's Azure-centric posture (ADR-0015) has no on-device story. Defines what subset of Kernel can run there.
- **Rough scope/size:** Large
- **Priority signal:** **Park**

---

## Cluster 10 — HoneyNet / Creator / Market / HoneyPlay seeding

Each is an empty Sector. Charter says "no upper bound on PDR count, as long as the substrate carries them." The minimum to seed a Sector without forcing a roadmap commitment:

### 10.1 HoneyNet Seed — `HoneyDrunk.Sentinel` (defensive scan-and-alert) ADR

- **Type:** ADR + Node
- **Charter hook:** Build-in-public + craft.
- **Why it matters:** HoneyNet (Matrix Green) exists as a Sector with zero Nodes. Sentinel is named in catalogs as future. A minimal Seed-class ADR establishes the boundary (defensive only, no offensive tooling, no third-party data collection).
- **Rough scope/size:** Medium
- **Priority signal:** **Park** until a concrete need

### 10.2 Creator Seed — `HoneyDrunk.Signal` (see 7.5) as the anchor Node

- **Type:** ADR + Node
- **Why it matters:** Creator sector empty. Signal is the natural first Node — opt-in analytics is creator-data discipline made concrete (charter manifesto belief #10).
- **Priority signal:** **Soon** if any consumer app ships

### 10.3 Market Seed — `HoneyDrunk.HiveXP` ADR (XP primitives, no marketplace yet)

- **Type:** ADR + Node
- **Why it matters:** Market sector empty. The manifesto names HiveXP as a planned Node. A minimal ADR scopes XP as a primitive without committing to a marketplace.
- **Priority signal:** **Park**

### 10.4 HoneyPlay Seed — `HoneyDrunk.Draft` (narrative scaffolding) ADR

- **Type:** ADR + Node
- **Why it matters:** HoneyPlay empty. Draft is named as planned. Minimal Seed ADR sets boundaries (narrative content vs. game runtime).
- **Priority signal:** **Park**

---

## Cluster 11 — Operational realism for a one-person studio

These overlap with cluster 2 (many-decade) but operate on shorter horizons (hours/days, not decades).

### 11.1 Per-PDR SLA Tiering

- **Type:** ADR
- **Charter hook:** Portfolio model + maintenance-mode.
- **Why it matters:** Notify Cloud (paid) deserves a different SLA than Hearth (free consumer) than Curiosities (pre-launch). Today ADR-0054 has one SLA tier. Define tier matrix coupled to project_state (cluster 1) and DR tier (ADR-0036).
- **Rough scope/size:** Medium
- **Priority signal:** **Soon**

### 11.2 Operator-Incapacitated Fallback (paging the family or trusted contact)

- **Type:** BDR or ADR
- **Charter hook:** Bus-factor.
- **Why it matters:** ADR-0054 pages the operator. What if the operator can't be reached? Who escalates? What information do they have? This is the runtime-incident counterpart to 2.5 (Operator Succession).
- **Rough scope/size:** Small
- **Priority signal:** **Soon**

### 11.3 Family Emergency / Personal Mode (multi-day, planned or unplanned)

- **Type:** ADR
- **Charter hook:** Workshop framing + take-time license.
- **Why it matters:** Distinct from 2.6 (Vacation) — vacation is planned weeks ahead. Family emergencies are sudden and indefinite. Defines the runbook: what to switch off, what to leave on, what banner appears.
- **Rough scope/size:** Small
- **Priority signal:** **Soon**

---

## Cluster 12 — Compliance & legal-adjacent

The charter doesn't require these. Consumer PDRs that ever launch to EU/CA users do.

### 12.1 ToS / Privacy / EULA Templates and Lifecycle

- **Type:** ADR
- **Charter hook:** Build-in-public + portfolio (consumer trials need terms).
- **Why it matters:** PDR-0002 (Notify Cloud), PDR-0005 (Hearth), PDR-0006 (Currents), PDR-0008 (Curiosities) each need ToS + Privacy. Without a template + version-history process, each one re-derives or copies. Define: canonical templates, semantic versioning of legal docs, user-notification mechanic.
- **Coverage check:** ADR-0039 (license) is the OSS code license. ADR-0049 covers PII handling internally. Neither covers user-facing legal documents.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon** (gated on Notify Cloud's first paying tenant)

### 12.2 DSR (Data Subject Rights) Operational Playbook

- **Type:** ADR
- **Charter hook:** Build-in-public (be honest about what you do with data).
- **Why it matters:** GDPR/CCPA require user data access/export/deletion within statutory windows. ADR-0050 covers tenant lifecycle; ADR-0060 (Identity) hints at "erasure fan-out." Need the operational playbook (who handles, what SLA, what audit, what affirmative receipt to user).
- **Coverage check:** ADR-0050, ADR-0060 — this is the procedural complement.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon**

### 12.3 DMCA / Abuse / Trust-and-Safety Policy

- **Type:** ADR
- **Charter hook:** Build-in-public + charter forbids performing-success.
- **Why it matters:** PDR-0003 (Lately) and PDR-0006 (Currents) have user-generated content and user-to-user contact. They will receive abuse reports. PDR-0008 has location data which has a tighter risk profile. Define: report intake, triage SLA, takedown mechanics, ban appeals.
- **Coverage check:** PDR-0004 §C had a moderation stack design (now historical-only). No ADR.
- **Rough scope/size:** Medium
- **Priority signal:** **Soon** (gated on first UGC product launch)

### 12.4 License Grandfathering When Commercial Trials Sunset

- **Type:** ADR
- **Charter hook:** Sunset playbook + license posture (ADR-0039).
- **Why it matters:** Notify Cloud uses FSL-1.1-MIT (per ADR-0039 drift). If Notify Cloud sunsets, what happens to the FSL license? Does the code revert to MIT? Do paying tenants get a perpetual non-commercial license? This needs a charter-shaped answer.
- **Coverage check:** ADR-0039 — extends it.
- **Rough scope/size:** Small
- **Priority signal:** **Eventually**

---

## Cluster 13 — Per-Node coverage gaps

ADR-0047 (testing) and ADR-0036 (DR) apply across all Nodes. But per-Node specialization is often missing.

### 13.1 Per-Node SLO Sheet (latency, error rate, availability)

- **Type:** ADR (sets the format) + 12 sub-packets (one per Live Node)
- **Charter hook:** Workshop craft.
- **Why it matters:** ADR-0066 (health endpoints) gives shape. Actual SLO targets per Node are undefined. Without targets, paging thresholds (ADR-0054) are guessed.
- **Rough scope/size:** Medium (ADR) + many small follow-up packets
- **Priority signal:** **Soon**

### 13.2 Per-Node Sunset Playbook Sketches

- **Type:** Documentation effort
- **Charter hook:** 1.2 (Sunset Playbook).
- **Why it matters:** Each Node would, at sunset time, have unique concerns (e.g., Notify retention vs. Vault key-vault decom). A one-page-per-Node sketch is cheap insurance.
- **Rough scope/size:** Small per Node
- **Priority signal:** **Eventually**

### 13.3 Per-Node Testing Strategy Pages (on top of ADR-0047 baseline)

- **Type:** Documentation effort
- **Charter hook:** Workshop craft + testing rigor.
- **Why it matters:** ADR-0047 is Grid-wide. Per-Node specifics (which contracts get contract tests, which integration tests need real-Azure vs. emulator, what coverage exceptions apply) need a page.
- **Rough scope/size:** Small per Node
- **Priority signal:** **Soon**

---

## Cluster 14 — Foundation-as-public-artifact

The charter explicitly licenses the Grid being public and the substrate being part of the "what gets built" story.

### 14.1 Grid-as-SDK Story (external consumer pathway)

- **Type:** ADR
- **Charter hook:** Charter — "A solo dev with a public, well-architected Grid spanning .NET infrastructure, AI agents, and commercial experiments is a different professional artifact." Implies someone outside HoneyDrunk could meaningfully consume Grid packages.
- **Why it matters:** ADR-0034 (public NuGet) defines distribution. The narrative — what does it mean for an external .NET dev to depend on `HoneyDrunk.Kernel` — is not articulated. Define: SDK promise, support posture, onboarding doc, sample app.
- **Coverage check:** ADR-0034 covers distribution mechanics. This covers product framing.
- **Rough scope/size:** Medium
- **Priority signal:** **Eventually**

### 14.2 Public NuGet Release Cadence and Roadmap

- **Type:** ADR
- **Charter hook:** Build-in-public + 14.1.
- **Why it matters:** ADR-0034 says "publish to NuGet." When? On what cadence? Predictability matters for external consumers but is overkill for purely internal use. Define the contract (e.g., 4-week tagged releases for foundation Nodes; on-demand for ops Nodes).
- **Coverage check:** Extends ADR-0034.
- **Rough scope/size:** Small
- **Priority signal:** **Eventually**

---

## Top 12 — would-start-tomorrow shortlist

Ranked by sequencing rationale. The first three are substrate that all others depend on.

| # | Title | Cluster | Rationale |
|---|---|---|---|
| 1 | **Project Lifecycle and State Model (Active / Maintenance / Sunset)** | 1.1 | Substrate. Every other lifecycle ADR depends on this taxonomy. Cheap to land. |
| 2 | **Maintenance-Mode SLA Contract** | 1.3 | Required before the first deliberate Maintenance transition; coupled to #1. |
| 3 | **Sunset Playbook for Nodes / Services / PDRs** | 1.2 | Charter explicitly licenses sunset; need procedure before it's needed in anger. |
| 4 | **Operator Succession / Bus-Factor BDR** | 2.5 | Disproportionate downside risk; pure paperwork; can write today. |
| 5 | **"Two-Week Vacation" Auto-Operating Mode** | 2.6 | First real test of the workshop framing — Grid must keep running through absences. |
| 6 | **Charter-Conformance Review (amend ADR-0044 D3 rubric)** | 1.5 | Smallest possible antibody against startup-drift; tiny edit. |
| 7 | **Agent-Fleet Observability** | 3.1 | AI multiplier is live now; measure or fly blind. |
| 8 | **Knowledge / Operator-Memory Persistence (formalize Lore)** | 2.3 | Value compounds with age; ten-year delta on start date matters. |
| 9 | **DX Baseline Per Node (`make repo` contract)** | 4.1 | Substrate hygiene; reduces cost of every future cross-Node ADR. |
| 10 | **Vendor-Exit Playbooks (Azure, Cloudflare, Stripe, AI providers)** | 2.1 | Write while leverage is cheap, before lock-in compounds. |
| 11 | **Per-PDR SLA Tiering** | 11.1 | Notify Cloud paid tenants are coming; cannot share Hearth's SLA. |
| 12 | **Embedding Versioning and Re-Indexing Policy** | 3.5 | Required before Knowledge ships v1; cheap to define now. |

---

## Probably-yes-but-later parking lot

One-line entries. Each is a real candidate but not in the top 12 right now.

- **Documentation Freshness Contract** (4.2) — wait for the first painful drift incident
- **Cross-Node Refactor Playbook** (4.3) — codify after the next Kernel breaking change
- **Public Failed-Experiments Shelf** (5.1) — needs material from sunsets
- **Grid-Wide Changelog Aggregator** (5.2) — small script; do when bored
- **Public Post-Mortem Cadence** (5.3) — wait for first real incident in production
- **Transcript / Conversation Governance** (3.6) — coupled with 2.3 ideally
- **Agent Versioning and Lifecycle** (3.2) — small, do after one Now item ships
- **Model-Fallback and Degraded-Mode Contracts** (3.4) — wait for first AI-feature production launch
- **HoneyDrunk.Search / Geo / Realtime Node ADRs** (7.1–7.3) — propose at first consumer-PDR build start
- **HoneyDrunk.Signal Node ADR (analytics)** (7.5) — gate on first consumer-app launch
- **HoneyDrunk.Locale Node ADR** (7.6) — gate on first non-US user
- **HoneyDrunk.Mobile Node ADR** (7.7) — gate on first consumer-PDR mobile build
- **HoneyDrunk.Legal Node ADR** (7.9) — gate on first EU/CA user
- **ToS / Privacy / EULA Templates** (12.1) — gate on Notify Cloud paying tenant
- **DSR Operational Playbook** (12.2) — gate on first regulated-jurisdiction user
- **DMCA / Abuse / T&S Policy** (12.3) — gate on first UGC product launch
- **Agent Cost Attribution** (8.4) — gate on first month with >$N agent spend
- **Local Catastrophe Runbooks** (4.4) — write before first long trip
- **Repo Archival Policy** (2.2) — fold into Sunset Playbook
- **Family Emergency / Personal Mode** (11.3) — companion to Vacation Mode
- **Operator-Incapacitated Fallback** (11.2) — companion to Operator Succession
- **PDR / BDR Promotion-Demotion Process** (1.6) — bundle with Maintenance-Mode SLA
- **Format and Data Preservation** (2.4) — write before first 5-year data set
- **Push-Notification Provider-Slot for Notify** (6.3) — gate on first consumer mobile build
- **Per-Node SLO Sheets** (13.1) — start with Notify, Pulse, Vault
- **Portfolio Health Scorecard** (1.4) — bundle with 1.1/1.3

---

## "Charter says no" list

Things that look like obvious next ADRs in a startup framing but the charter actively de-prioritizes or forbids. Listed so the operator knows what to **not** propose.

- **Kill-clock ADRs.** Anything that says "if MRR doesn't hit $X by Y, kill the project." Charter §"Commercial trials": "Kill clocks are out. Decision points are in." Use Maintenance-mode instead.
- **Single-product focus ADRs.** Anything that argues "focus the Grid on Notify Cloud" or "AI-first studio." Charter §"What this licenses": "Refuse focus advice that assumes a single-product company."
- **MRR / ARR targeting ADRs.** Anything that establishes growth-rate targets. Revenue is a fifth motivation, not the engine.
- **Customer-acquisition-cost / channel-mix ADRs.** This is startup machinery; not workshop machinery.
- **Marketing-attribution / funnel-instrumentation ADRs.** "Honest visibility" is the charter mode; funnel optimization is its opposite.
- **VC-readiness / fundraising / pitch-deck ADRs.** Out of scope by charter.
- **Quarterly OKR / KPI framework ADRs.** Charter §"What this licenses": "There is no quarterly clock."
- **"Pivot the Grid" ADRs.** The Grid is intentionally portfolio-shaped; pivots are a startup primitive.
- **Aggressive deprecation of mature Nodes for headcount efficiency.** No headcount pressure; charter explicitly says solo dev + AI agents is the productive unit.
- **Lock-in-by-design ADRs.** Anything that argues for tighter coupling to a single vendor "for velocity" — runs counter to 2.1 (vendor exit) and the many-decade horizon.

---

## New Nodes recommended to formalize now

A clean numbered list with proposed sector placement, in priority order:

1. **HoneyDrunk.Search** — Sector: **Core**. Distributed full-text + faceted search abstraction. Provider slots (Azure AI Search, PostgreSQL FTS, InMemory).
2. **HoneyDrunk.Geo** — Sector: **Core**. Geospatial primitives. Provider slots (PostGIS, S2, H3, InMemory).
3. **HoneyDrunk.Realtime** — Sector: **Core**. WebSocket / SignalR / SSE abstraction with GridContext propagation.
4. **HoneyDrunk.Signal** — Sector: **Creator** (anchors the empty Sector). Opt-in product analytics; creator-data discipline.
5. **HoneyDrunk.Legal** — Sector: **Core**. ToS / Privacy / consent runtime; DSR fan-out.
6. **HoneyDrunk.Mobile** — Sector: **Creator**. Mobile baseline (iOS/Android); first decision MAUI vs. native.
7. **HoneyDrunk.Locale** — Sector: **Core**. i18n catalogs, locale fallback, translation interface.
8. **HoneyDrunk.Sentinel** — Sector: **HoneyNet** (anchors the empty Sector). Defensive scan-and-alert.

Notes:

- Nodes 7.4 (Push), 7.8 (Web.UI), 7.11 (Lifecycle), 7.12 (Portfolio), 7.13 (Telemetry.Aggregator) are intentionally **deferred** — better folded into Notify, Studios, or Architecture respectively until a forcing function justifies separation.
- The four Cyberware Nodes (9.x) stay parked.
- The four AI Nodes already in flight (Capabilities/Operator/Agents/Knowledge/Memory/Evals/Flow/Sim/AI per ADRs 0016–0025) are not duplicated here.

---

## Open questions for operator input

Items I could not decide without an operator call. Each is gating one or more candidates above.

1. **What "Maintenance Mode" looks like operationally.** Cluster 1.3. Is it `signal: Echo` per the existing taxonomy, a new `project_state: Maintenance` field, or both? Affects every Node's catalog row and the Studios website.
2. **Notify Cloud's sunset clause posture.** Cluster 12.4. If Notify Cloud is ever sunset, do paying tenants get perpetual MIT, perpetual-non-commercial, source escrow, or self-host instructions? This decision shapes ADR-0039's FSL-1.1-MIT terms.
3. **Single Memory vs. split (agent-memory vs. operator-memory).** Clusters 2.3 and 3.3. Is the long-running operator-collaborator memory a new Node, a sub-package of Memory, or grafted onto Lore? Three credible answers; the right one depends on operator intent for Lore.
4. **Mobile baseline: MAUI vs. native vs. React Native vs. Flutter.** Cluster 7.7. Big platform-direction decision; doesn't belong in a candidate document; flagging so the operator schedules it explicitly.
5. **Geo footprint by 2026-Q4.** Cluster 12 entries depend on whether any consumer PDR ships to EU users this year. If yes, ToS/Privacy/DSR are urgent; if no, they slide.
6. **HoneyHub's intended lifecycle state.** PDR-0001 is Accepted but Phase 1-only. Is HoneyHub Active, Pre-Active, or Maintenance? Determines whether cluster 8.2 (Sim/HoneyHub integration) is gated on HoneyHub work.
7. **Lifecycle Node vs. fold-into-Architecture.** Cluster 7.11. Does the operator want a separate Meta-sector Node for portfolio governance, or do these stay as catalog fields owned by this Architecture repo?
8. **Cyberware horizon.** Cluster 9 is parked. If the operator has a 2027 robotics intent, the parking should be re-evaluated.
9. **Public vs. private for Charter-Conformance review (1.5).** Does the per-ADR charter-citation become a public artifact or an internal review note?
10. **Operator-incapacitated fallback contact.** Cluster 11.2 / 2.5. This is a human conversation that has to happen offline before it can be specified.

---

## Closing note

This list is intentionally broad. Roughly two-thirds of it is gated by forcing functions that haven't fired yet — that is by design per the user's "do as much upfront as possible" instruction. The Top-12 shortlist is the subset where the forcing function has fired or where landing the ADR cheaply is itself a charter-aligned investment.

Recommended next move: operator green-lights the Top-12 (or a subset) into the proper composer flow one at a time, and selects which of the eight new Nodes to formalize next. Everything else stays in this document as a parking lot.
