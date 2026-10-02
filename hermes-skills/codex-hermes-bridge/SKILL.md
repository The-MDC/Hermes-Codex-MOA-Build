---
name: codex-hermes-bridge
description: "name: codex-hermes-bridge
description: Wire OpenAI Codex CLI's native subagent system to a Hermes Agent CLI install so each can hand work to the other — Codex delegates research/consensus/specialist work to Hermes via delegate_task, without duplicating work or fighting over concurrency limits.
license: MIT"""
version: 1.0.0
author: "unknown"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---
  version: 1.0.0
  source: packaged from a live Codex + Hermes bridging session, 2026-09
  depends_on: hermes-agent-setup

# Codex ↔ Hermes bridge

Use this skill when a user has **both** OpenAI Codex CLI and a Hermes Agent
CLI install and wants Codex to be able to hand a task to Hermes (long-running
research, Mixture-of-Agents consensus, or a role Hermes already has a
specialist skill for) instead of Codex solving it directly, or vice versa.

This is a bridge, not a merge: Codex and Hermes stay two separate agent
runtimes. The bridge is two custom Codex agent profiles plus a shared MCP
server (`codex-specialized-subagents`) and a delegation-bridge skill on the
Hermes side (`Rainhoole/hermes-agent-acp-skill`).

## What gets installed

1. **`codex-specialized-subagents`** — Codex's own specialist-delegation MCP
   server (`delegate_autopilot`, `delegate_run`, `delegate_resume`). This is
   the actively-maintained successor to the archived `codex-subagents-mcp`;
   don't install the archived one. Clone + `npm ci && npm run build` it
   yourself (not vendored in this skill) and confirm its test suite passes
   before wiring it in.
2. **Two custom Codex agents**, dropped into `~/.codex/agents/`
   (`%USERPROFILE%\.codex\agents\` on Windows):
   - `agents/hermes-bridge.toml` — a pure handoff agent. It packages the
     current task as a brief and calls `delegate_task(agent="hermes")` via
     the acp-skill bridge, then relays Hermes' result back verbatim with a
     one-line note. It must NOT attempt the task itself, and must NOT
     silently fall back to solving it in Codex without saying so if the
     bridge is unreachable.
   - `agents/hermes-research.toml` — same shape, scoped to deep/multi-source
     research and MoA-consensus questions, where Hermes' NemoHermes routing
     and MoA presets are treated as the source of truth over Codex's own
     training data.
3. **`config-snippet.toml`** — the `[agents]` concurrency caps and MCP server
   registration to merge into `~/.codex/config.toml` **by hand**. Do not
   auto-append: an existing `config.toml` may already have `[agents]` or
   `[mcp_servers.*]` tables, and a blind append will duplicate them. Set the
   Codex-side concurrency caps to match Hermes' own
   `delegation.max_concurrent_children` / `max_spawn_depth` (see
   `hermes-agent-setup`) so the two systems don't contend for the same
   thread budget.

## Install steps (Windows / PowerShell)

```powershell
.\install-codex-hermes-bridge.ps1
```

This clones and builds `codex-specialized-subagents`, drops the two agent
TOMLs into `%USERPROFILE%\.codex\agents\`, and prints the `config.toml`
block for manual merge. It deliberately does not touch `config.toml`
directly.

If there is no connected/writable folder for `.codex` in the current
session, do not guess the user's home directory to construct the path —
either ask for the exact absolute path, or hand the user this whole
directory as a ready-to-drop-in package and let them run the installer
themselves.

## What NOT to wire in, and why

- **Generic "awesome-codex-cli" list repos** that share an identical
  description ("Curated list of 150+ tools, skills, subagents & plugins for
  OpenAI Codex CLI") across unrelated GitHub accounts are mass-forked
  templates, not maintained curated lists. Treat that exact-description-match
  pattern as a signal to skip, not a reason to dig through each fork.
- **`ComposioHQ/awesome-codex-skills`** is legitimate but not Hermes-specific
  — mention it only if the user separately wants Codex reaching Slack/GitHub/
  Notion/etc. directly via Composio's `connect-apps` skill.
- **Hermes' own native Codex delegation** (tracked upstream as an in-progress
  feature for native-harness subagent delegation) will eventually replace
  this bridge entirely once merged. Check whether it has landed before
  installing this bridge on a newer Hermes build — if it has, prefer the
  native path.
- **`dsh-harness-mcp-server`** — superseded, do not reintroduce.

See `references/why-not-native.md` for the full reasoning if asked to
justify any of these exclusions.

## Files in this skill

- `agents/hermes-bridge.toml`, `agents/hermes-research.toml` — the two Codex
  agent profiles, ready to drop into `~/.codex/agents/`.
- `config-snippet.toml` — the `[agents]` + `[mcp_servers.codex-specialized-subagents]`
  block to merge by hand into `~/.codex/config.toml`.
- `install-codex-hermes-bridge.ps1` — Windows/PowerShell installer that
  clones + builds the MCP server and places the agent files.
- `references/why-not-native.md` — exclusion reasoning for repos/approaches
  considered and rejected.
