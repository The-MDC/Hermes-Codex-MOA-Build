---
name: hermes-agent-setup
description: "name: hermes-agent-setup
description: Configure, diagnose, and extend a NousResearch Hermes Agent CLI install (~/.hermes or %USERPROFILE%\AppData\Local\hermes) — multi-provider model routing, MCP server wiring, delegation limits, and the common failure modes that show up in config.yaml, .env, and gateway_state.json.
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
  source: packaged from a live Hermes Agent CLI support session, 2026-09

# Hermes Agent setup & troubleshooting

Use this skill when working on a **Hermes Agent CLI** install (the NousResearch
agent stack — `config.yaml`, `.env`, `delegation.*`, MoA presets, `hermes doctor`).
It is not about the older Sinonjs/Facebook "Hermes JS engine", and it is not
about a generically-named "concierge" or "assistant" product — verify you're
looking at a real `~/.hermes/` (or Windows `%USERPROFILE%\AppData\Local\hermes\`)
tree with a `config.yaml` before applying anything here.

## Before touching anything

1. Locate the real config: `~/.hermes/config.yaml` (Linux/macOS) or
   `%USERPROFILE%\AppData\Local\hermes\config.yaml` (Windows). Confirm it
   exists and has a `model:`, `mcp_servers:`, and `delegation:` block before
   assuming this skill applies.
2. Back up before every edit: `cp config.yaml config.yaml.bak-$(date +%Y%m%d-%H%M%S)`
   (or the PowerShell equivalent). Same for `.env`. Never edit either file
   without a timestamped backup sitting next to it first.
3. Never print, log, or paste an actual API key or token value back to the
   user or into a generated file — reference it by its `.env` variable name
   (`${OPENROUTER_API_KEY}`, `${NVIDIA_API_KEY}`, etc.) instead, exactly as
   Hermes' own config schema expects.

## Multi-provider model routing

Hermes' named providers (as of the 0.21.x config schema) are: `openrouter`,
`openai-codex`, `nous`, `zai`, `kimi-coding` / `kimi-coding-cn`, `minimax` /
`minimax-cn`, `bedrock`. Anything else (NVIDIA NIM, a self-hosted vLLM
endpoint, etc.) has to go through the **custom OpenAI-compatible endpoint
path** — a `base_url` + `key_env` pair, not a named provider slug.

`fallback_model:` in `config.yaml` is a **single dict, not a list** — confirm
this against the live install's own commented example before writing a
fallback chain; a previous pass on this exact install used `fallback_providers:`
(plural, list-shaped) and it silently failed to load. See
`references/multiprovider-config-additions.yaml` for a corrected, tested
block (NVIDIA NIM fallback + a `hermes-council` MCP server wired through
OpenRouter) with the reasoning for each choice inline.

Rule of thumb for adding a new provider or MCP server to `mcp_servers:`:
confirm the underlying package is actually installed on the target machine
(`pip show <pkg>` / `npm ls <pkg>` / check `~/.hermes/plugins/`) **before**
adding its entry to `config.yaml`. Referencing an uninstalled plugin or a
since-unpublished npm package (e.g. `render-mcp-server`, unpublished by its
maintainer 2026-01-12) is exactly what produces an `ENOVERSIONS` restart
crash-loop in `logs/mcp-stderr.log`.

## Delegation and cost knobs

`delegation.max_concurrent_children` and `model.default` are a cost/speed
trade-off, not a correctness issue — don't "fix" one to match a template
without asking:
- Higher `max_concurrent_children` (e.g. 9) = more parallel sub-agent work,
  linearly more spend.
- `model.default` set to the main model (e.g. `claude-sonnet-5`) bills every
  auxiliary/delegated call at main-model rates; pointing it at a cheap model
  (e.g. `qwen3.5:cloud`) isolates that cost but changes auxiliary-task quality.

Always state both options with their trade-off and let the user pick; see
`references/multiprovider-config-additions.yaml` for the exact ranked
reasoning used last time.

## Common failure signatures and their real causes

See `references/troubleshooting.md` for the full list. Highlights:
- `gateway_state.json` shows `startup_failed` → check whether a channel like
  WhatsApp is `_ENABLED=true` in `.env` but never paired (`hermes whatsapp`
  to pair, or disable the flag).
- Duplicate keys inside `.env` (same variable appearing 2-3×) are usually
  produced by Hermes' own onboarding/auth flow appending without checking
  for an existing key — not by re-running a setup script that truncates
  first. Dedupe by hand, keep the last value, preserve line order.
- MCP servers stuck needing interactive OAuth (circleci, craft, comfy-cloud,
  fireflies, linear, wordpress-com, cloudflare, etc.) need `hermes mcp login
  <server>` run interactively by the human — this cannot be done from an
  unattended session.
- `fleet_restart_pending` stuck with a PID that no longer exists = a
  requested restart that never completed. Investigate with `hermes doctor`
  before deleting the marker file — confirm nothing else reads it first.

## Installing a skill/plugin into a live Hermes tree

Prefer the real `hermes skills install <name>` / `hermes plugin install
<name>` commands when they exist. When cloning a skill's source directly
(e.g. because `.git` lock operations fail on a mounted/network drive), strip
`.git` and note in the handoff that the resulting layout may not exactly
match what a hub install would have produced — point Hermes at the correct
subfolder per that skill's own README rather than assuming the top-level
clone dir is right.

## Files in this skill

- `references/multiprovider-config-additions.yaml` — a corrected,
  schema-verified `config.yaml` fragment (NVIDIA fallback + hermes-council
  MCP server) with inline reasoning. Treat every `${VAR}` in it as a
  required `.env` entry, never a placeholder to fill in literally.
- `references/troubleshooting.md` — the full list of failure signatures
  found on a real install this skill was extracted from, each with root
  cause and fix, so future sessions don't re-diagnose the same crash-loop
  from scratch.
