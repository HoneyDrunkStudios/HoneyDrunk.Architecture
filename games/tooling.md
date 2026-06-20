# Game Dev — Tooling & Pipeline

**Status:** Seed (living document)
**Last updated:** 2026-06-20

The toolchain for HoneyDrunk's games. Goal: a **solid foundation** you can actually create/modify with, plus heavy **buy/generate** to stay unblocked, with **AI integrated into the tools** wherever it exists. Per PDR-0012 and the 2026-06-20 tooling conversation.

Operator's posture (decided 2026-06-20): mix of buying/generating assets *and* keeping a real foundational capability; favor AI that plugs **into** the DCC tools; standardize 2D on **Adobe CC**; decide **music per game**.

## Engine & code (decided)
- **Unity (LTS)** — engine.
- **Visual Studio Community** + Unity workload — IDE (free; not Rider).
- **Git + Git LFS** + Unity `.gitignore` — version control.
- **Claude Code + Codex** — AI coding (already in use; IDE-agnostic).

## 2D art / images — Adobe CC (decided)
- **Photoshop** (raster, UI, textures, Steam capsule art) + **Illustrator** (vector, icons, logos).
- **Adobe Firefly** built in (Generative Fill/Expand, generative recolor) — **commercially-safe training**, so shippable. This is the AI-in-the-tool the operator wanted *and* it resolves the commercial AI-licensing risk for 2D.
- **Substance 3D** (part of CC) for PBR texturing when 3D ramps up — includes AI sampler (image → material).
- **Aseprite** (~$20 once) *only if* a game goes pixel-art.

## 3D — Blender foundation
- **Blender** (free) — modeling, sculpting, rig, animation. The 3D backbone (game-2+ / dream-game concern; game 1 may need none).
- Stylized-fast: **Synty** low-poly packs.
- Later (dream game): **Substance Painter** for hero-asset texturing.

### Blender + AI — mid-2026 state (researched 2026-06-20)
The "latest and greatest" snapshot. Re-verify before relying on it — this space moves monthly.

- **The headline: AI *drives* Blender via MCP.** Claude can operate Blender directly through the **Model Context Protocol** — it reads the scene and writes/runs Python to build geometry, apply materials, and do the technical scut-work *in plain language*. Open-source **`blender-mcp`** (ahujasid) works with any LLM; **Anthropic shipped an official Blender connector in April 2026**. **This is the route to try first — it rides our existing Claude access, no extra art-gen subscription to start.**
- **Blender Foundation stance (May 2026):** **no native generative AI** in core, by design ("made by humans, for humans") — they even capped Anthropic's donation to one-time. But they're launching a **"Blender Lab"** exploring natural-language input + an **official MCP server** on Blender's Python API. So gen-AI stays third-party; the MCP/agent route is blessed.
- **3D model generation (companion tools, import to Blender):**
  - **Tripo** — 2026 game-dev favorite: ~8s gens, **clean quad topology auto-optimized for engines**, built-in rigging. Best for fast game-ready assets.
  - **Meshy** — most all-in-one: built-in **auto-rigging + 500+ animation presets**, clean edge flow. Best balance for solo.
  - **Rodin** (ByteDance) — leader for **hyper-realistic humans** / photorealistic objects.
  - Also: 3D AI Studio, 3D-Agent (in-Blender via MCP), BlenderGPT, Hunyuan 3D.
- **Rigging & animation:**
  - **Auto-Rig Pro** (~$40 once) — top paid rigging addon (smart bones, auto weights, production rigs). Plus free **Mixamo** / **AccuRig** for humanoids.
  - **Mocap-from-video:** **DeepMotion**, **Plask**, **Move.ai**, **Autodesk Flow Studio** — phone video → Blender-ready animation.
  - Meshy/Tripo also rig + animate their own gens.
- **Texturing:** **Dream Textures** (Stable Diffusion inside Blender) + **Adobe Substance** (AI sampler); gen tools texture what they produce.
- **Caveats (unchanged):** generated meshes suit **props / base meshes / concepting** but need cleanup/retopo for **hero assets**; **check commercial licensing** on each gen tool before shipping.

**Modern solo-dev 3D pipeline:** Blender (free foundation) + **Claude-over-MCP** for technical ops + **Tripo/Meshy** for asset gen + **Auto-Rig Pro/Mixamo** + **mocap-from-video** for animation.

Sources (2026-06-20): [Blender AI policy](https://www.blender.org/news/upcoming-blender-development-fund-and-ai-policies/) · [blender-mcp](https://github.com/ahujasid/blender-mcp) · [Claude drives Blender via MCP](https://medium.com/@creativeaininja/claude-drives-blender-through-mcp-now-heres-what-actually-changes-684f28f78c7b) · [Tripo/Meshy/Rodin compared](https://medium.com/data-science-in-your-pocket/ai-3d-model-generators-compared-tripo-ai-meshy-ai-rodin-ai-and-more-8d42cc841049) · [Blender animation addons (game dev)](https://mocaponline.com/blogs/mocap-news/blender-animation-addons-guide) · [DeepMotion × Blender](https://www.deepmotion.com/companion-tools/blender)

## Audio / music — decide per game (decided)
Foundation tools ready regardless of the per-game call:
- **Audacity** (free) — editing. **bfxr/jsfxr** (free) — instant game SFX.
- Library sources: **freesound.org**, **incompetech**, Unity Asset Store / Humble audio packs.

Per-game music menu (pick when the game is real):
- **Library / royalty-free** — fastest, safe licensing (default for game 1).
- **Compose in a DAW** — **Reaper** (~$60 once) if/when we want an in-house composing capability; AI-in-tool options like iZotope (AI mastering/repair) and stem-separation.
- **AI-generated** (Suno/Udio) — fast drafts; commercial-use/licensing risk + Steam disclosure for shipped games.

Later (dream game): audio middleware **FMOD / Wwise** (free for indie under revenue thresholds).

## Asset sources (the real "art pipeline" for early games)
- **Kenney.nl** — free, CC0, huge. Ideal for game 1.
- **Unity Asset Store**, **Fab** (Epic marketplace; free Megascans), **itch.io** packs, **Humble Bundles**, Synty.

## AI tooling (where it fits)
- **In-tool (preferred):** Adobe Firefly (PS/AI), Substance AI sampler, Blender Dream Textures, **Blender MCP** (Claude operates Blender via natural language — see "Blender + AI" above), optionally **Unity Muse** (AI textures/sprites/anim/behavior — subscription) + **Unity Sentis** (run models in-game).
- **3D model/anim gen:** Tripo, Meshy, Rodin (gen); Auto-Rig Pro, Mixamo, AccuRig (rig); DeepMotion, Plask, Move.ai (mocap-from-video).
- **Standalone:** Claude Code/Codex (code), ElevenLabs (voice/placeholder VO), Midjourney/Stable Diffusion + ComfyUI (concepting/mood boards), Suno/Udio (music drafts).

## Production / capture
- **OBS** (free) — capture, trailers, store media.
- Issue tracking: reuse **The Hive** (GitHub Projects).
- **Steamworks SDK** at store-page time.

## ⚠️ Commercial AI-asset policy
- **Game 1 (disposable/learning):** use AI assets freely.
- **Any commercial game:** prefer **Adobe Firefly** (commercial-safe) and properly-licensed/contracted/own assets for *shipped* content; use Midjourney/SD/Suno for *concepting and placeholders* only. **Steam requires disclosing AI-generated content** at submission — comply.

## Install/decide checklist by phase

**Ready by ~Jan 2027 (game 1):**
- [ ] Unity LTS + Unity Hub
- [ ] Visual Studio Community + Unity workload
- [ ] Git + Git LFS configured on the game repo
- [ ] Adobe CC (Photoshop + Illustrator; + Substance if any 3D)
- [ ] Blender (only if game 1 uses 3D)
- [ ] Audacity + bfxr; freesound/incompetech bookmarked
- [ ] Kenney.nl + Unity Asset Store account
- [ ] OBS

**Build-toward-dream pipeline (game 2+):**
- [ ] Blender proficiency + Substance Painter
- [ ] Decide composing (Reaper) vs. contracting music
- [ ] FMOD/Wwise evaluation
- [ ] Contract specialist artists/composers for shipped dream-game assets
- [ ] Terrain/world tooling (e.g. Gaia / World Machine) for the open world
- [ ] Localization tooling
- [ ] Optional: Unity Muse for in-engine AI
