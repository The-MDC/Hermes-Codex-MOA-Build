---
name: hermes-orchestration
description: "Use this skill when working on the Hermes routing build itself: changing config.yaml, adding or renaming a provider, moving an auxiliary slot, bringing the stack up on a new machine, or diagnosing why a tier answers on the wrong model, costs more than expected, or silently stopped working. Also use it before editing any model id, because each gateway names models in its own namespace and an id copied between providers is wrong by default. Triggers on: config.yaml, provider, auxiliary slot, routing, fallback, hermes-verify, hermes-apply, hermes-blockers, model id, wrong model, rate limit, 429, compression, vision slot, llama-server, Ollama tag, MCP server, bring the stack up."
version: 1.0.0
author: "Written for this Hermes build"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Orchestration, Routing, Config, Providers, Diagnostics, Maintenance]
    category: operations
    related_skills: [local-desktop]
---

# Maintaining this orchestration build

**Almost every failure in this build is silent.** A dangling model reference does not
error — Hermes resolves it by falling back to the main model, so the symptom is a
bill and a latency change, not a stack trace. Assume nothing is working just because
nothing complained.

## The shape

| Tier | Provider key | Serves |
|---|---|---|
| parent | `custom:hf-router` | the conversation |
| subagents | `custom:nvidia-nim` | delegation, its own rate-limit bucket |
| 429 fallback + heavy aux | `custom:or-fallback` | `compression`, `web_extract` |
| floor | `custom:local` | 5 auxiliary slots, offline-capable |

`vision` used to be its own tier (`custom:local-vl`, llama-server :8080). Retired
2026-09-25 along with the old floor model (hermes3:8b) — `vision` now routes to
`custom:nvidia-nim` (cloud, moved there 2026-09-27 after briefly sitting on
`custom:or-fallback`), and the floor is a single, smaller Ollama tag
(`hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0`, pulled via
Ollama's own hf.co/ feature, no second local service).

Three structural rules hold it together. Break any one and it fails **silently**:

1. **Provider references must dodge `excluded_providers`.** `deepseek`, `openrouter`
   and `ollama` are all excluded, and exclusion matches every key a provider surfaces
   under. That is why the entries are named `hf-router`, `or-fallback` and `local` —
   an entry named after its own exclusion hides itself.
2. **Subagents must not share the parent's provider**, or a fan-out eats the parent's
   bucket.
3. **No auxiliary slot may sit on `auto`.** `auto` means "use the main model", which
   puts side jobs on the parent's bucket — and it is how `vision` broke once, left on
   `auto` after the parent changed to a text-only model.

## A model id belongs to the GATEWAY, not to the model

The single most expensive mistake this build has made. The same weights are named
differently by each gateway:

```
Hugging Face router   deepseek-ai/DeepSeek-V4.1-Flash
OpenRouter            deepseek/deepseek-v4.1-flash
```

Copying an id from a model card, or from one provider to another, is wrong by
default. Nothing catches it: CI resolves provider *references*, not the ids inside
them; `discover_models: false` means Hermes never probes `/models`; and a dead
reference falls back rather than erroring. **Check the gateway's own catalog before
writing any id**, and if you cannot reach it, say the id is unverified rather than
assuming.

## The scripts

| Script | Does | Changes anything? |
|---|---|---|
| `hermes-apply.ps1` | Installs `config.yaml` and `config.toml`, backing up first | Yes — `-WhatIf` previews |
| `hermes-verify.ps1` | The gate. `-Stage a\|b\|full`, `-Deep` adds live probes | No |
| `hermes-blockers.ps1` | Diagnoses the council and Codex blockers | No |
| `hermes-report.ps1` | Paste-safe inventory of the install | No |
| `nim-preflight.sh` | Proves the NVIDIA route and that traffic lands on NVIDIA | No |

`hermes-verify.ps1 -Deep` checks each provider's **catalog before the completion**,
because a failed completion cannot distinguish a wrong model id from an exhausted
quota — and those need opposite fixes. It reads ids **out of the installed config**
rather than holding its own copy, so it cannot drift from what Hermes actually sends.

## Symptom → cause

| Symptom | What it usually means |
|---|---|
| Answers come from the wrong model | A reference fell back. Check the id against the gateway's catalog, and `discover_models: false` is still set |
| A tier costs more than expected | Something resolved to the parent — an `auto` slot, or an id the provider does not serve |
| `catalog does NOT list '<id>'` | The id is wrong **for that provider**. Not a quota problem. Do not retry |
| Catalog lists it, completion fails | Quota, billing or rate limit. The config is right |
| `answered as '<other>'` | The router silently substituted a model. Pin the provider |
| `ModuleNotFoundError` from an MCP server | **Check which interpreter ran before touching any package.** The supervisor substitutes its own runtime for a bare `command:`, so an installed package looks absent. `url:` entries are immune |
| Vision returns a bad answer rather than an error | The vision backend is down or text-only. A model that cannot see reports as poor quality, never as a missing capability |
| Tool use degrades but chat looks fine | Wrong chat template. Run the tool-calling probe; the fix is a `TEMPLATE` directive |

## Rules that are not negotiable

- **No key-shaped string enters `config.yaml`.** Every remote provider reads `key_env`.
  CI and the preflight both reject it. Loopback providers are exempt because a server
  on your own machine authenticates nothing.
- **Never hand-edit the installed `~/.hermes/config.yaml`.** The repo copy is the
  source; change it there and re-run `hermes-apply.ps1`. A hand-edit is lost on the
  next apply and invisible to CI until then.
- **Verify before claiming.** Several statements in this repo's history were plausible,
  confidently written, and wrong. If you cannot check something, write down that you
  could not, rather than writing the plausible version.

## Two things that look broken and are not

**`codex mcp list` reports `Unsupported`.** Expected and unfixable — Codex 0.154.0
removed the `mcp-server` entry point and Codex is an MCP *client* now. Delegation
runs as a subprocess and is unaffected. Do not "fix" it by wiring Codex as an
inference provider: that creates a second, invisible consumer of one ChatGPT quota,
which is why `openai-codex` sits in `excluded_providers`.

**A VL model imported into Ollama has no vision.** Ollama cannot attach the separate
`mmproj` projector, and `ollama create` *succeeds* while dropping it — leaving a model
with `-VL` in its name that cannot see. Vision models need `llama-server --mmproj`.

## Changing the config safely

1. Edit the **repo** copy, never the installed one.
2. Run the CI assertion block from `.github/workflows/checks.yml` against it locally.
   `hermes config: OK` is the pass line.
3. If you touched a model id, check it against that gateway's catalog.
4. `hermes-apply.ps1 -WhatIf`, then for real.
5. `hermes-verify.ps1 -Stage full -Deep`.

**A check that cannot fail is not a check, and one that cannot pass is worse.** This
repo has shipped both: an assertion that hardcoded a retired model and kept passing,
and a gate that failed on a permanent upstream condition so no install could ever go
green. When you add an assertion, prove it fails against a deliberately broken input
before trusting it.

## Adding a capability without drifting from the structure

`capabilities.yaml` at the repo root declares every skill and MCP server once, with the
surfaces that carry it. `scripts/check-capabilities.py` fails the build when the tree
stops matching that declaration, so the declaration is the contract, not a comment.

Two surfaces, two lookups, and the difference is the thing to get right:

| | path | resolved by |
|---|---|---|
| Hermes | `hermes-skills/<category>/<name>/SKILL.md` | the **directory** name |
| Claude Code | `.claude/skills/<category>/<name>.md` | the frontmatter **`name`** |

A Claude-side file whose filename differs from its `name` still resolves; a Hermes skill
whose frontmatter `name` differs from its directory does not. The check reports the first
as info and fails the second.

**To add a ported skill.** Add it to `INCLUDE` in `scripts/port-skills-to-hermes.js` with
its category and tags, run the port, then declare it in `capabilities.yaml`. Run the port
before writing the registry entry — it prints the exact YAML block to paste.

**To add a hand-written skill.** Write `hermes-skills/<category>/<name>/SKILL.md` by hand
with a complete `metadata.hermes` block, then declare it. There is no upstream, so the
in-repo copy *is* canonical and the port script reads it rather than rewriting it.

**To put a skill on both surfaces.** Set `surfaces: [claude, hermes]` in the registry and
re-run the port. It projects the Claude copy from the canonical source and stamps it
`generated_by:`. Nothing else to edit — the emit is driven by the registry, not by code.

**Asymmetry is allowed, silence is not.** One surface requires an `asymmetry_reason`.
Hosted MCP servers are deliberately kept out of Hermes: every discovered tool is injected
into the system prompt on *every* request, which on a ~40 RPM tier is a permanent tax.
That is a reason, and it belongs in the file.

### Is a ported skill still current?

`hermes-skills/.port-lock.json` records the SHA-256 of each upstream `SKILL.md` at port
time. To find out what has changed upstream since:

```bash
node scripts/port-skills-to-hermes.js --check
```

It writes nothing. `DRIFTED` means upstream changed — re-run the port. `RESURFACED` means
`capabilities.yaml` was edited without re-running the port, so a declared surface has no
file behind it. `absent` means the source root is not on this machine, which is normal:
the sources live outside this repo and no CI runner has them. **Drift is never a build
failure** — failing on a condition the build cannot see or fix is the gate that can never
pass, and this repo has shipped one of those already.
