# OpenClaw Capabilities UX + Architecture Plan

This document describes a long-term direction for replacing the current "Tools" UI with a capability-driven control surface aligned with how OpenClaw works today.

## Goals

- Remove “reasoning” as a first-class user configuration, because it is not uniformly supported across model backends/providers.
- Make **MLXSession**, **LLamaCPPSession**, and **Remote** models first-class citizens with the same UX primitives.
- Treat the **gateway as connect-only**: the remote OpenClaw instance solves capability/tool execution; Think mainly configures and visualizes.
- Make capability configuration **per-personality** (with optional per-chat overrides later).
- Improve the **message input** so it becomes the place where users manage what the current OpenClaw instance can do: local tools, remote tools, MCP connections, and skills.

## Non-Goals (Near Term)

- Running MCP servers on iOS/macOS inside Think.
- Provider-specific “reasoning effort” controls in the app UI.

## Current State (2026-02)

- Reasoning tool + reasoning level were removed from: prompt formatting, tool selection UI, DB config, and event stream surfaces.
- Think can connect to a remote OpenClaw gateway and drive pairing/auth flows (`OPENCLAW_REMOTE.md`).
- Tool execution progress is persisted for UI via the agent event stream adapter (`OPENCLAW_GAPS.md` OCW-001).

## Problem Statement

The current “Tools” section is:

- Too “static” (enum-based) for OpenClaw-style dynamic tools (MCP-provided toolsets).
- Not model/backend aware (not all backends support the same tool mechanisms).
- Not integrated with skills and OpenClaw remote capabilities.

## North-Star UX

The input toolbar exposes a single “Capabilities” entry point:

- **Model**: which session is active (MLX / llama.cpp / Remote).
- **Tools**: enabled capabilities (local and/or remote toolsets).
- **Skills**: curated behaviors that shape tool usage.
- **MCP**: remote MCP servers attached to the remote OpenClaw instance (connect-only; Think configures, OpenClaw runs).
- **Workspace / Memory**: contextual inputs that change what “tools” can do.

Everything is backed by a per-personality policy, with clear “what’s enabled” chips in the composer.

## Architecture Direction

### 1) Capabilities First, Tools Second

Introduce a capability-centric model:

- **Model capabilities** (what the backend/provider supports): modalities, tool calling, streaming, etc.
- **Policy capabilities** (what the user/personality allows): which toolsets/skills are enabled for this personality/chat.
- **Resolved capabilities** = intersection of model capabilities + policy + runtime availability (downloads, device permissions, gateway connected).

### 2) Move Away From Enum-Only Tool Identifiers

OpenClaw + MCP tools are dynamic (string IDs, namespaces, versions). A hard-coded `enum ToolIdentifier` will keep fighting this.

Long-term, adopt:

- A stable `ToolID` value type (string-backed) for persistence and UI.
- A registry for “known” local tools to keep icons/labels/requirements.
- A dynamic tool catalog for remote tools discovered from gateway/OpenClaw.

This enables:

- MCP tools that appear/disappear without app updates.
- Multiple toolsets with the same “type” but different implementations.

### 3) Gateway Is Connect-Only

Think should:

- Connect to the remote gateway.
- Fetch capabilities/tool catalogs.
- Send policy configuration (per-personality) and per-request tool allowlists.

OpenClaw should:

- Own MCP server lifecycle and tool execution.
- Resolve capability compatibility (which tools can be used with which models).

### 4) Per-Personality Capability Profiles

Persist:

- Allowed tool IDs (local + remote).
- Enabled skills.
- Optional defaults (e.g., “Allow remote tools when connected”).

Then resolve for a chat:

- Chat’s personality profile + runtime availability (gateway connected, permissions granted, model downloaded).

## Milestones

### M1 (Done): Remove Reasoning As A Tool/Setting

- Remove reasoning tool + reasoning level across stack.
- Remove Qwen `/think` and Harmony “Reasoning:” sections from formatter outputs.
- Remove “Thinking UI” (viewer/buttons) and keep only channel-level rendering.

### M2: Capability-Aware Tool Picker (No Schema Changes)

- Tools sheet only shows tools that are:
  - supported by the active model/backend, and
  - available on device (permissions/downloads), and
  - allowed by personality policy.
- Show “source of truth” per tool:
  - Local tool
  - Remote tool (from gateway)
- Improve copy: “Capabilities” instead of “Tools”.

### M3: Capabilities Control Center In Composer (Per-Personality)

- Replace the tools chips with a compact “Capabilities” bar:
  - Tools chips
  - Skills chips
  - MCP status (remote only)
  - Workspace/memory indicators
- Single modal to manage:
  - Allowed tools (per personality)
  - Enabled skills (per personality)
  - Quick diagnostics (why something is disabled)

### M4: Remote Tool Catalog + MCP Management (Connect-Only)

- When a gateway is active:
  - fetch remote tool catalog and show it in Capabilities UI
  - allow enabling/disabling remote tool IDs per personality
- Add MCP management UI as a remote configuration surface:
  - list configured MCP servers (remote)
  - add/remove/enable/disable MCP servers (remote)
  - show toolsets contributed by each MCP server

### M5: Unify Storage + Tool IDs (Schema/Protocol Evolution)

- Introduce string-backed tool IDs in `Abstractions` + `Database` and migrate:
  - tool policy storage
  - skill-tool mapping
  - action tool allowlists
- Keep a compatibility layer for local built-ins (icons/labels/requirements).

## Open Questions (Need Product Decisions)

- Should “skills” be treated as just another capability source (like MCP), or a separate concept in UX?
- How should per-chat overrides interact with per-personality defaults?
- Do we want Think to optionally act as an MCP *client* (still connect-only server-wise), or keep MCP strictly remote-managed by OpenClaw?

