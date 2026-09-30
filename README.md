# Hermes–Codex Build

A multi-tier model orchestration for [Hermes Agent](https://github.com/hermes-agent),
with the Codex CLI wired in as an MCP tool server, a declared capability registry,
and the runbook to bring the whole thing up on a Windows machine.

This repo is the **build**, not a product. It carries configuration, verification
scripts, skills and documentation — nothing that ships to an end user.

## The routing

Four remote-ish roles plus a local one, no longer on four separate rate-limit
buckets the way this section used to describe — the parent itself moved local,
see below.

| Tier | Provider | Model | Role |
|---|---|---|---|
| parent | `custom:local` | `hf.co/unsloth/Llama-3_3-Nemotron-Super-49B-v1_5-GGUF:UD-Q8_K_XL` (Ollama) | moved off DeepSeek/hf-router 2026-09-28, on request |
| subagents | `custom:nvidia-nim` | `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | high-compute delegation, also the MoA reference model |
| fallback | `custom:or-fallback` | `qwen/qwen3.5-122b-a10b` | 429 escape, 2 heavy aux slots |
| floor | `custom:local` | `hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0` (Ollama) | offline, 5 auxiliary slots |
| aggregator | `custom:local` | `hf.co/unsloth/Llama-3_3-Nemotron-Super-49B-v1_5-GGUF:UD-Q8_K_XL` (Ollama) | MoA aggregator, same GGUF as parent — a different role, not a conflict |

**DeepSeek is fully removed from this build, repo-wide, on request (2026-09-28).**
`fallback` (and the two heavy auxiliary slots that ride on it) reverted to
`qwen/qwen3.5-122b-a10b`, the same id that tier ran before a DeepSeek was ever
put there; the MoA reference model moved to the `nemotron-3-nano-omni-30b-a3b-reasoning`
id `subagents` already uses; the MoA aggregator moved to a local 49B Nemotron
GGUF specifically so it would NOT share a bucket with that same reference model
(same-provider MoA self-grades, see `config.yaml`'s `moa:` comment). `parent`
moved to that same local 49B GGUF, on request ("the current parent is the 49B
Nemotron") — not a self-grading conflict with the aggregator sharing the same
model, since parent and MoA aggregator are unrelated roles. The `hf-router`
provider is removed entirely: it existed for exactly one reason (serving
DeepSeek-V4-Pro as parent) and nothing else in this file ever used it.

Moving the parent local also resolves what used to be an open question here:
promoting any of the remaining CLOUD tiers to parent would have collapsed that
tier's own bucket isolation (nvidia-nim with subagents, or-fallback with its
auxiliary slots). Local has no rate-limit bucket to collapse.

The `fallback` row compresses an ordered chain in `fallback_providers:`, two
cloud links deep before the local last resort: **1)**
`nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` on NVIDIA NIM (cloud-hosted,
reusing the `nvidia-nim` bucket subagents already spend — a fallback there now
competes with delegation traffic), **2)** `qwen/qwen3.5-122b-a10b`, matching the
table above, **3)** the local floor model, unchanged in role. Fallback 1's id
replaced `nvidia/llama-3.3-nemotron-super-49b-v1.5` on 2026-09-27 after that one
turned out to be dead (HTTP 410, end-of-life 2026-08-26) — the "corroborated by
three resellers" verification this section used to cite was wrong; `config.yaml`'s
comment on the entry has the full story and the self-verify command.

**There is no `vision + heavy local` tier anymore.** `local-vl`
(nemotron-nano-12b-v2-vl on llama.cpp :8080) is removed as of 2026-09-25, on
request, along with the old floor model (hermes3:8b). `vision` routes to
`custom:nvidia-nim` / `nvidia/ising-calibration-1.5-31b` now (moved there
2026-09-27, off an earlier or-fallback/DeepSeek revert of the same slot). The
floor model above is Llama-3.2-based and text-only, so none of this was
incidental: there was never a vision-capable replacement on the laptop tier.

**Nemotron-3-Super-120B-A12B is retired**, on request (2026-09-25). It is not
the same thing as the 49B Nemotron in the aggregator row above — the 120B was a
routing-tier model and is gone with no replacement of its own; the 49B is a
separate, later addition, standalone in this build.

**A model id belongs to the gateway, not to the model.** The same weights carry
different ids per gateway — Hugging Face called DeepSeek-V4.1-Flash
`deepseek-ai/DeepSeek-V4.1-Flash`, OpenRouter called the identical weights
`deepseek/deepseek-v4.1-flash` — and an id copied between providers is wrong by
default. `discover_models: false` means Hermes never probes `/models`, so a bad
id does not error: it silently resolves to the main model. Kept as the
illustrative example even though DeepSeek is leaving this build, because it's
the clearest real case this repo hit of the failure mode itself.

**Why the vision tier used to be a separate server**, kept for context even
though the tier itself is gone: a VL GGUF ships as two files, the language model
and a separate `mmproj` projector. Ollama cannot attach the second, and it does
not refuse — `ollama create` *succeeds*, silently dropping vision, leaving a
model with `-VL` in its name that cannot see. That risk doesn't apply to the
current floor model since it isn't a vision model at all.

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
that gets the local tier and the cloud tiers working and nothing else.

Nothing in this repo has executed against a real Hermes install on Windows. CI proves
the files parse and agree with each other; it cannot prove behaviour.

## Sources

- Anthropic knowledge-work plugins — github.com/anthropics/knowledge-work-plugins
- Everything Claude Code — github.com/affaan-m/everything-claude-code
- Cloudflare security-audit skill (MIT) — github.com/cloudflare/security-audit-skill
- Codex CLI — github.com/openai/codex


