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
subagents   custom:nvidia-nim    nvidia/nemotron-3-super-120b-a12b  high-compute delegation
fallback    custom:or-fallback   deepseek/deepseek-v4.1-flash       429 escape + 2 heavy aux
floor       custom:local         hermes3:8b (Ollama)                offline, 5 aux slots
vision +    custom:local-vl      nemotron-nano-12b-v2-vl            llama.cpp :8080, NOT Ollama
heavy local                                                         images AND heavy local text
```

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
