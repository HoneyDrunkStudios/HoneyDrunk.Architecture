---
title: HoneyDrunk.HoneyHub - Overview
description: Node overview, surfaces, and session contract for the HoneyHub Agent Cockpit.
type: node-context/overview
node: honeydrunk-honeyhub
sector: Meta
signal: Seed
version: 0.0.0
repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
node_class: studios-typescript-native
stack: TypeScript, React, Vite, PWA, Tauri-class shell, Rust bridge
---

# HoneyDrunk.HoneyHub - Overview

**Sector:** Meta
**Signal:** Seed
**Version:** 0.0.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`
**Node class:** `studios-typescript-native`
**Stack:** TypeScript, React, Vite, PWA, Tauri-class shell, Rust bridge

HoneyDrunk.HoneyHub is the Agent Cockpit Node. v1 is a free, local-first cockpit for starting, watching, interrupting, replying to, and governing local AI coding-agent sessions. It is one shared React PWA across mobile and desktop, with a desktop shell that bundles the local runner bridge and a mobile path that reaches that bridge over a secure relay.

The bridge drives local agent CLIs under the user's own local auth. The initial backend is Claude Code, followed later by Codex and Copilot. HoneyHub does not hold subscription auth, does not become a hosted execution service at v1, and does not turn into an editor or terminal.

## Surfaces

| Surface | Purpose |
|---|---|
| Web / PWA | Shared responsive UI for sessions, bridge pairing, notifications, usage, and artifacts. |
| Desktop shell | Tauri-class wrapper around the same UI, bundling the Rust bridge for one local install. |
| Mobile PWA | Same UI reaching a paired bridge over the approved secure relay path. |

## Session Contract

The ADR-0090 session model is the core contract:

- `DispatchSession`
- `DispatchRun`
- `DispatchMessage`
- `DispatchControlEvent`
- `DispatchArtifact`
- `UsageSignal`
- `PolicyHint`

Backends declare capability flags honestly:

- `streaming_output`
- `interactive_reply`
- `resume_session`
- `stop_signal`
- `structured_events`
- `usage_exact`
- `usage_estimated`

## Current Focus

Phase 2 ships the first useful slice: scaffold the mixed TypeScript/Rust workspace, implement the bridge core, add pairing and allowlists, implement the Claude Code adapter, persist sessions locally, emit state-only notifications, and build the minimal run screen.
