# Hermes–Codex Build — Claude Code context

## What this repo is

A multi-tier model orchestration for Hermes Agent, with the Codex CLI wired in as an
MCP tool server. Configuration, verification scripts, skills and a bring-up runbook.

**It carries no product content.** No company, no branding, no business figures. If
you are about to add any, you are in the wrong repo. `SCRUB` in
`scripts/port-skills-to-hermes.js` removes product references from ported skill
content, and the port fails if one survives into the output tree.

## The routing

```
parent      custom:hf-router     deepseek-ai/DeepSeek-V4-Pro        1.6T (49B active), 1M ctx
subagents   custom:nvidia-nim    nvidia/nemotron-3-nano-omni-30b-a3b-reasoning  high-compute delegation
fallback    custom:or-fallback   deepseek/deepseek-v4.1-flash       429 escape + 2 heavy aux
floor       custom:local         Hermes-3-Llama-3.2-3B-abliterated:Q8_0 (Ollama)   offline, 5 aux slots
```

**There is no local vision tier anymore.** `local-vl` (nemotron-nano-12b-v2-vl on
llama.cpp :8080) was removed 2026-09-25 along with the old floor model
(hermes3:8b), on request. `vision` now routes to `custom:or-fallback`
(DeepSeek-V4.1-Flash, cloud) instead — same as before the local-vl tier ever
existed. The new floor model is Llama-3.2-based and text-only, so this wasn't a
side effect of the swap: there was never a vision-capable replacement on offer.

This diagram lists ROLES, not every provider. `anthropic-direct` (claude-sonnet-5,
Anthropic's OpenAI-compatible endpoint) exists in `providers:` and is deliberately
wired into none of the five roles above — reachable only via
`/model custom:anthropic-direct:claude-sonnet-5`. See the comment on that entry and
on the MoA `aggregator:` block for why it was kept out.

`fallback_providers:` is an ordered chain, not a single role — the table's one
`fallback` row is now two links deep. **Fallback 1** is
`nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` on NVIDIA NIM (cloud-hosted, same
bucket `nvidia-nim` already spends on subagents — a fallback firing there now
competes with delegation traffic); **fallback 2** is the DeepSeek entry the table
still shows; the local floor model (Hermes-3-Llama-3.2-3B-abliterated:Q8_0)
remains last resort, unchanged in role.

**The id above is a 2026-09-27 replacement for a dead model, not the original
choice.** `nvidia/llama-3.3-nemotron-super-49b-v1.5` (added 2026-09-25, replacing
Nemotron-3-Super-120B-A12B) was never live-verified from this sandbox — this
repo's own egress proxy blocks `build.nvidia.com`/`docs.api.nvidia.com` — and was
instead "triangulated" against three NIM resellers. That triangulation was wrong:
a real Hermes session on this NIM account hit the id live via `/moa` and got back
HTTP 410 Gone, end-of-life 2026-08-26 — a month before the triangulation was
trusted. The replacement was live-verified the way that matters: it actually
answered, on this account, the same day it replaced the dead id. See the comment
on the `nvidia-nim` provider entry in `config.yaml` for the full story, and run
`bash scripts/nim-preflight.sh --list | grep -i nemotron` after any future swap
here — that command would have caught this immediately.

Three rules that have each cost a session here:

1. **A model id belongs to the GATEWAY, not the model.** The same weights carry
   different ids per gateway. `discover_models: false` means Hermes never probes
   `/models`, so a wrong id does not error — it silently resolves to the main model.
2. **`auto` in an auxiliary slot means "use the main model".** That is how vision
   broke silently when the parent changed to a model with no vision encoder.
3. **A provider named after its own exclusion hides itself.** `excluded_providers`
   matches case-insensitively against every key a provider surfaces under, which is
   why the OpenRouter entry is called `or-fallback`.

## Capabilities

`capabilities.yaml` declares every skill and MCP server once, with its surfaces and a
required `asymmetry_reason` when it is on one surface only.
`scripts/check-capabilities.py` makes that binding — it fails the build when disk
stops matching the declaration.

Name resolution differs by surface, which matters when adding anything:

- **Hermes** resolves a skill by its **directory** name — `hermes-skills/<category>/<name>/SKILL.md`
- **Claude Code** resolves it by the frontmatter **`name`** — `.claude/skills/<category>/<name>.md`

A skill with a malformed `metadata.hermes` block loads without complaint and simply
never triggers. The gate checks frontmatter for exactly that reason.

Hosted MCP servers are kept out of Hermes on purpose: every discovered tool is
injected into the system prompt on *every* request, which on a ~40 RPM tier is a
permanent tax. Asymmetry is legitimate; unexplained asymmetry is not.

## Verification

Run these before trusting a change. Each exists because something passed silently
that should not have:

```bash
python3 scripts/check-capabilities.py             # registry vs disk
node   scripts/port-skills-to-hermes.js           # re-port; prints `scrub: clean`
node   scripts/port-skills-to-hermes.js --check   # upstream drift, writes nothing
bash   scripts/repo-doctor.sh                     # toolchain, hooks, egress
pwsh -File scripts/hermes-verify.ps1              # the acceptance gate, on the box
```

**A check that cannot fail is not a check, and one that cannot pass is worse.** This
repo has shipped both: an assertion that hardcoded a retired model and kept passing,
and a gate that failed on a permanent upstream condition so no install could ever go
green. When you add an assertion, prove it fails against a deliberately broken input
before trusting it.

## Changing the config safely

1. Edit the **repo** copy, never the installed one.
2. Run the CI assertion block from `.github/workflows/checks.yml` locally.
   `hermes config: OK` is the pass line.
3. If you touched a model id, check it against **that gateway's** catalog.
4. `hermes-apply.ps1 -WhatIf`, then for real.
5. `hermes-verify.ps1 -Stage full -Deep`.

## Behaviour rules

1. Read context files before generating — never assume.
2. One deliverable per prompt; don't batch unrelated tasks.
3. Use AskUserQuestion when a task needs clarification before execution.
4. Apply the `security-review` skill before any production-bound change.
5. Apply the `verification-loop` skill before opening a PR.

## Skills and commands

Skills live in `.claude/skills/` by domain: marketing, sales, product, engineering,
data, operations, legal, finance, productivity, cowork, ecc.

Commands live in `.claude/commands/`:
`/orchestrate` `/quality-gate` `/harness-audit` `/learn` `/evolve` `/skill-create`
`/model-route` `/plan` `/security` `/checkpoint` `/doctor` `/market-brief`

## Hooks

Wired in `.claude/settings.json` — the only file Claude Code reads hooks from.
`scripts/repo-doctor.sh` fails if any of these points at a missing script.

- `before-submit-prompt.js` — `UserPromptSubmit` — secret scanning on the prompt
- `after-mcp-execution.js` — `PostToolUse` / `mcp__.*` — MCP result logging
- `post-edit-check.js` — `PostToolUse` / `Write|Edit` — console.log warning, Prettier, `tsc --noEmit`
- `pre-bash-guard.js` — `PreToolUse` / `Bash` — blocks `--no-verify` git hook bypass (the only blocking hook)
- `stop-audit.js` — `Stop` — console.log sweep across changed files

**Not active**: `session-start.js`, `session-end.js`, `pre-compact.js` and `stop.js`
are unwired forwarders to Cursor hooks that were never in this repo — they do
nothing. `.claude/hooks/hooks.json` was a Cursor config (Cursor event names,
`.cursor/` paths that never existed) and has been removed; Claude Code never read it.
See `.claude/hooks/README.md`.
