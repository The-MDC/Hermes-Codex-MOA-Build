# Hermes–Codex Build

A multi-tier model orchestration for [Hermes Agent](https://github.com/hermes-agent),
with the Codex CLI wired in as an MCP tool server, a declared capability registry,
and the runbook to bring the whole thing up on a Windows machine.

This repo is the **build**, not a product. It carries configuration, verification
scripts, skills and documentation — nothing that ships to an end user.

## The routing

Five tiers, each on its own rate-limit bucket. That isolation is the point: the
parent cannot starve its own children, and losing the network costs cloud capability
but not the floor.

| Tier | Provider | Model | Role |
|---|---|---|---|
| parent | `custom:hf-router` | `deepseek-ai/DeepSeek-V4-Pro` | 1.6T (49B active), 1M ctx |
| subagents | `custom:nvidia-nim` | `nvidia/llama-3.3-nemotron-super-49b-v1.5` | high-compute delegation |
| fallback | `custom:or-fallback` | `deepseek/deepseek-v4.1-flash` | 429 escape, 2 heavy aux slots |
| floor | `custom:local` | `hermes3:8b` (Ollama) | offline, 5 auxiliary slots |
| vision + heavy local | `custom:local-vl` | `nemotron-nano-12b-v2-vl` | llama.cpp on :8080, **not** Ollama |

The `fallback` row compresses an ordered chain in `fallback_providers:`. As of
2026-09-25 it is two cloud links deep before the local last resort: **1)**
`nvidia/llama-3.3-nemotron-super-49b-v1.5` on NVIDIA NIM (cloud-hosted, reusing
the `nvidia-nim` bucket subagents already spend — a fallback there now competes
with delegation traffic), **2)** the DeepSeek entry the table shows above, **3)**
`hermes3:8b` local, unchanged. That NIM model id was corroborated by three
independent resellers, not verified first-party — `config.yaml`'s comment on the
entry has the detail and the self-verify command.

**Nemotron-3-Super-120B-A12B is retired**, on request (2026-09-25): `subagents`
above and the MoA aggregator both moved to the same 49B model as the fallback
link. No reference to the 120B model remains in `config.yaml`.

**A model id belongs to the gateway, not to the model.** The same weights carry
different ids per gateway — Hugging Face calls it `deepseek-ai/DeepSeek-V4.1-Flash`,
OpenRouter calls it `deepseek/deepseek-v4.1-flash` — and an id copied between
providers is wrong by default. `discover_models: false` means Hermes never probes
`/models`, so a bad id does not error: it silently resolves to the main model.

**The vision tier is a separate server on purpose.** A VL GGUF ships as two files,
the language model and a separate `mmproj` projector. Ollama cannot attach the
second, and it does not refuse — `ollama create` *succeeds*, silently dropping
vision, leaving a model with `-VL` in its name that cannot see.

## Codex

Codex 0.154.0 removed the `codex mcp-server` entry point, so `codex mcp list`
reports `Unsupported` and always will. `scripts/codex-mcp/server.js` rebuilds the
interface locally: a dependency-free stdio MCP server exposing `codex_exec` and
`codex_status`, putting typed arguments in front of the same subprocess the bundled
skill already drives.

It is **not** an inference provider — `openai-codex` stays in `excluded_providers`,
because Hermes' own provider and the Codex CLI read different token files against the
same ChatGPT window.

## Capabilities

`capabilities.yaml` declares every skill and MCP server once, with the surfaces that
carry it and a required reason for any asymmetry.
`scripts/check-capabilities.py` fails the build when the tree stops matching it.

```
skills        95 declared    77 Claude Code    29 Hermes    11 both
mcp servers   16 declared    10 Claude Code     8 Hermes     2 both
```

**This is not a parity demand.** Hosted MCP servers are kept out of Hermes on
purpose: every discovered tool is injected into the system prompt on *every* request,
which on a ~40 RPM tier is a permanent tax. Asymmetry is legitimate; unexplained
asymmetry is indistinguishable from an accident, and that is what the gate catches.

Skills resolve differently on each surface, which is why they are compared by name
and never by path:

| | path | resolved by |
|---|---|---|
| Hermes | `hermes-skills/<category>/<name>/SKILL.md` | the **directory** name |
| Claude Code | `.claude/skills/<category>/<name>.md` | the frontmatter **`name`** |

## Layout

| Path | What |
|---|---|
| `configs/hermes/config.yaml` | the routing core — providers, auxiliary slots, MCP servers |
| `configs/codex/config.toml` | Codex CLI config |
| `capabilities.yaml` | the single declaration of what exists |
| `hermes-skills/` | 29 skills in Hermes format, plus `.port-lock.json` |
| `.claude/skills/` | 77 skills in Claude Code format |
| `scripts/` | apply, verify, report, doctor, capability gate, skill port, Codex shim |
| `docs/models/` | `TAKEOVER.md` (full bring-up), `VSCODE-QUICKSTART.md` (fast path) |

## Scripts

```bash
pwsh -File scripts/hermes-apply.ps1 -WhatIf   # show what installing would change
pwsh -File scripts/hermes-apply.ps1           # install configs, with backups
pwsh -File scripts/hermes-verify.ps1          # the acceptance gate
pwsh -File scripts/hermes-report.ps1          # paste-safe install inventory
bash   scripts/repo-doctor.sh                 # toolchain, hooks, egress
python3 scripts/check-capabilities.py         # registry vs disk
node   scripts/port-skills-to-hermes.js       # re-port skills to both surfaces
node   scripts/port-skills-to-hermes.js --check   # what has drifted upstream
```

## Commands

`/orchestrate` `/quality-gate` `/harness-audit` `/learn` `/evolve` `/skill-create`
`/model-route` `/plan` `/security` `/checkpoint` `/doctor` `/market-brief`

## Bring it up

Start at `docs/models/TAKEOVER.md`. `docs/models/VSCODE-QUICKSTART.md` is the subset
that gets the local tier and DeepSeek working and nothing else.

Nothing in this repo has executed against a real Hermes install on Windows. CI proves
the files parse and agree with each other; it cannot prove behaviour.

## Sources

- Anthropic knowledge-work plugins — github.com/anthropics/knowledge-work-plugins
- Everything Claude Code — github.com/affaan-m/everything-claude-code
- Cloudflare security-audit skill (MIT) — github.com/cloudflare/security-audit-skill
- Codex CLI — github.com/openai/codex
