# HoneyDrunk Studios — Charter

> The personal version of the manifesto. When this doc and `manifesto.md` disagree, this doc wins. The manifesto is the public-facing story; this is what the studio actually is.

---

## What this is

HoneyDrunk is **a workshop, not a startup.**

It is a personal computing platform — built by one human, with AI agents as collaborators — meant to be lived in and built on for **many decades to come**. The Grid is the workshop. The apps, games, tools, robotics projects, AI experiments, and whatever else happens here are the things built in the workshop.

The Grid exists so that standing up the next cool thing — whatever it turns out to be — is as easy as composing a few packages behind a UI. That ease of composition is the whole point. Everything else (the ADRs, the invariants, the audit substrate, the catalogs, the agent definitions) is in service of it.

This is the **single most important framing in the entire ecosystem**. When any other artifact — manifesto, ADR, PDR, agent prompt, conversation — drifts into language that sounds like a startup pitch deck, this charter is the tiebreaker.

---

## What this is not

It is not a startup. It is not VC-shaped. It is not optimizing for MRR, ARR, exit, or any external definition of "traction."

That doesn't mean revenue is forbidden. It means **revenue is one of many experiments the Grid lets us run**, not the purpose the Grid was built to serve. Notify Cloud is a real commercial trial. Future Nodes may be too. But the studio doesn't live or die by what any of them earns.

It also is not a hobby project. The discipline is real — enterprise-grade architecture, contracts, ADRs, invariants, telemetry, audit, threat modeling. Not because customers demand it, but because building things this way is the craft. The discipline is intrinsic to the goal.

The right metaphor is closer to a **lifelong personal lab** than to either a startup or a side project.

---

## Why we build this way

Four motivations stacked, in order of weight:

1. **Craft.** Building things well — at a level a serious engineer would respect — is satisfying in itself. The substrate gets to be enterprise-grade because that's the point, not because anyone is paying for it.

2. **Learning.** Every Node, every ADR, every product experiment is an excuse to learn something — multi-tenant primitives, distributed systems, AI orchestration, robotics, deliverability, payment infrastructure, whatever the next project pulls in. The Grid is a teaching machine that the operator happens to also be the student of.

3. **Career and beyond.** The work compounds professionally. A solo dev with a public, well-architected Grid spanning .NET infrastructure, AI agents, and commercial experiments is a different person — and a different professional artifact — than one without it. This is true whether or not any individual product succeeds commercially.

4. **Cool stuff.** Apps, games, tools, robotics, AI things. The substrate exists so the cool stuff is cheap to build. The cool stuff is the visible output; the substrate is what makes it sustainable.

Revenue, when it happens, is a fifth motivation — welcome, useful, validating. Not the engine.

---

## The portfolio model

The studio runs **many projects in parallel**. Some currently exist as PDRs; more will. There is no upper bound on how many is "too many," as long as the substrate carries them.

Projects exist in three states:

- **Active** — being worked on, shipping changes, accepting feedback.
- **Maintenance** — alive, running, but not actively iterated. Existing users (often just the operator) continue to use it.
- **Sunset** — gracefully retired. Repo archived (still public per the build-in-public stance), infrastructure torn down, learnings captured.

**Sunsetting a project is not a failure.** It's a normal lifecycle event. A project that taught us something, ran for a while, and was deliberately retired is a successful project. A project that taught us something it didn't need to teach us and now drags on attention is one we should sunset.

The wrong framing: *"this product didn't hit $X MRR by Y date → kill it."*

The right framing: *"is this still serving its purpose — use, learning, craft, or revenue? If yes, keep it. If no, sunset it deliberately and move on."*

---

## Commercial trials

Some projects will be commercial experiments. **Notify Cloud is the current one**, with more likely to follow as the substrate matures.

Commercial trials follow a different cadence than personal-use projects, but they're still trials. The questions to ask:

- Did we learn what we wanted to learn from making it commercial?
- Are people paying? How many? Why?
- Is the architecture better for having external tenants pressure-test it?
- Is the maintenance cost (time, money, attention) worth what the project returns (revenue, learning, dogfood, brand)?

When a commercial trial doesn't earn external customers, that's a data point — not a kill signal. The product can drop to maintenance mode, run for internal use indefinitely, and the multi-tenant primitives it exercised in the Grid become permanently valuable.

**Kill clocks are out. Decision points are in.** At checkpoint dates, deliberately decide: keep active, drop to maintenance, or sunset gracefully. All three are valid outcomes.

---

## The AI multiplier

This studio is built on a bet: that **a disciplined solo operator with AI agents can sustain a system that would have required a small team five years ago, and a larger team ten years ago.**

The bet is not blind faith — it's based on observable reality. A 2026 solo dev with Claude / Codex / Copilot, Grid-aware tooling, custom subagent definitions, and a substrate that compounds across projects is a fundamentally different productive unit than a 2022 solo dev.

This bet underwrites:

- **The open-ended portfolio.** Maintaining 25+ Grid repos and a growing PDR set (currently 8, with no upper bound by design) is a different math problem in 2026 than in 2020.
- **The architecture investment.** The substrate is worth building because AI agents help maintain it.
- **The decades-long horizon.** As AI capability grows, the multiplier grows with it. The Grid is built to ride that gradient.

If the bet were wrong — if AI capability plateaued or got gated — the Grid's pace would slow. It wouldn't die. The substrate is real either way; the rate of new projects on it is what depends on the multiplier. That's an acceptable downside.

---

## Build-in-public, honestly

The studio is public. The repos are public (with the documented commercial carve-outs per ADR-0027 and ADR-0039). The ADRs are public. The PDRs are public. The drift reports, post-mortems, and roadmap are public.

Build-in-public here means showing the **whole shape**, including:

- Things we tried that didn't work.
- Projects in maintenance mode that aren't being actively developed.
- ADRs we proposed and later superseded.
- Honest assessments of what's working and what isn't.

It doesn't mean performing success. It means being visible during the actual process, which includes the boring parts and the failed parts.

---

## How to read other docs in light of this

When `manifesto.md`, an ADR, a PDR, or any other artifact uses language that sounds startup-shaped — kill clocks, MRR targets, "sustain the Grid through paid tiers," "first commercial product," "go-to-market" — interpret it through this charter, not the other way around.

Specifically:

- **"Open Core. Paid Orchestration."** (manifesto §Sustainability) is a *trial framing*, not a structural commitment. Some Nodes may follow this model. The studio itself is not financed by it.
- **Kill criteria in PDRs** are *decision points*, not termination triggers. The default move on missing a kill criterion is "drop to maintenance," not "shut it down."
- **"First commercial product"** language (PDR-0002) describes a product trial, not a stake-the-studio bet.
- **Architecture-heavy ADRs that look like over-investment for a 12-month startup** are correctly-sized for a many-decade platform. The cost-benefit math runs differently here.

When in doubt, this charter is the tiebreaker. If the charter and another doc disagree, the other doc is the one that needs updating.

---

## What this charter licenses

Explicit permissions, in plain language:

- **Sunset projects without ceremony.** If a project has stopped serving its purpose, retire it. No need to wait for permission, run a process, or grieve the decision.
- **Drop products to maintenance mode.** A commercial trial that didn't catch on can keep running for the operator's own use indefinitely. That is a valid steady state.
- **Spend on the foundation.** Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work.
- **Refuse focus advice that assumes a single-product company.** The studio is structurally a portfolio. Advice to "just focus on one thing" misreads what this is.
- **Take time.** There is no quarterly clock. Months-long pauses on individual projects are fine if attention is elsewhere on the Grid.

---

## What this charter forbids

Three failure modes worth naming, all of which the charter exists to prevent:

1. **Quietly drifting into startup logic.** Reading a Hacker News thread on a Sunday and waking up Monday committed to a 90-day kill clock and a growth target. This charter is the antibody.

2. **Architecture-as-procrastination.** Even in a workshop, the foundation eventually has to serve the cool stuff being built on top of it. If a year goes by and only ADRs ship, the foundation is consuming the workshop instead of supporting it. Self-check periodically.

3. **Performing visibility instead of building.** Build-in-public is a side effect of the work, not the work. If posts about the Grid are landing while the Grid itself isn't moving, something is inverted.

---

## In one sentence

**HoneyDrunk is a many-decade personal computing platform that exists so its operator can keep building cool things — at a level of craft worth respecting — with AI agents as long-running collaborators, and where any individual project is allowed to succeed, plateau, or sunset on its own terms without threatening the whole.**

Everything else in the constitution serves that sentence.
