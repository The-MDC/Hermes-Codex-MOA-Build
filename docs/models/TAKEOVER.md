# Takeover runbook — bringing the Hermes stack up from Hermes Desktop

For whoever implements this next, running on the Windows box rather than in CI.
Self-contained on purpose: you do not need to read another file in this repo to
execute it. Context for *why* the stack is shaped this way is in
`handoff-2026-09-22.md`; you do not need it to follow the steps below.

## Division of labour

**RETIRED to two actors, 2026-09-25.** This table used to name three: a human/Claude
for bootstrap, a local VL model as a screenshot-reading "runner" for steps 1.3
onward, and Claude Sonnet for escalations. The VL runner's whole tier —
`nemotron-nano-12b-v2-vl` on `llama-server` :8080 — is retired along with
`hermes3:8b`, on request ("remove hermes 8B and the 12b"). There is no local
vision model left to hand step-execution to. What follows is what the old
section explained about *why* that role existed and what replaced it; the
actual steps below (Phase 1 onward) are now run by a human or Claude directly,
same as Phase 0.

| Actor | Available | Does | Does not |
|---|---|---|---|
| **A human, or Claude** | from the start | Every phase, start to finish — Ollama, the floor model pull, all verification. | Skip the verify gate because a step "looks fine". |
| **Claude Sonnet** | from the start | Every ESCALATE row. Diagnoses failures, writes config changes, decides trade-offs. | — |

**Why a vision model used to run this runbook**, kept for context: the loop is
"compare the output to the stated success line", and on a Windows bring-up much
of that output is not text — installer dialogs, the VS Code terminal dropdown,
dashboard pages. A text-only runner sees none of that, since it never hits
stdout. That reasoning is sound; it just no longer has a model to attach to
here, since the tier it depended on is gone.

**The one rule that matters, unchanged:** a step is done when its success line
matches. Not when the command exits 0, not when the output looks plausible. A
dangling model reference still answers — on the wrong model.

## Stop conditions

Stop and escalate to Sonnet immediately if any of these are true. Do not continue
down the list hoping a later step fixes an earlier one.

- `scripts/hermes-verify.ps1` prints any `FAIL` line and you have already run the
  step that was supposed to clear it.
- A command asks for, prints, or would write an API key anywhere except
  `$HERMES_HOME\.env`.
- A step requires editing `config.yaml` by hand. The repo copy is the source;
  changes belong there, then reinstalled via step 4.
- Two consecutive steps fail for what looks like the same underlying reason.

---

## Phase 0 — establish the starting state

### Step 0.1 — Record what is there now

```powershell
cd <repo>
pwsh -File scripts/hermes-verify.ps1
```

**Success:** the script runs and prints a verdict line, `OK` or `FAILED`.

Failures here are expected on a first run — this step is a *baseline*, not a gate.
Save the output. You will compare against it at step 6.1.

**ESCALATE** if the script itself errors rather than printing a verdict.

---

## Phase 1 — local models

The local tier backs the floor plus five auxiliary slots. Nothing else works
predictably until Ollama holds it. (There is no second local tier anymore —
`vision` routes to the cloud; see Step 1.3 below for why.)

### Step 1.1 — Confirm Ollama is serving

```powershell
ollama list
```

**Success:** a table prints, even if empty.
**If `ollama` is not recognised:** install Ollama, reopen the shell, retry once.

### Step 1.2 — Pull the floor model

```powershell
ollama pull hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0
```

**Success:** `ollama list` now shows the full tag above (swapped from
`hermes3:8b` 2026-09-25, on request). ~3.4 GB, verified live against the
Hugging Face repo (3,421,895,840 bytes). Needs a reasonably current Ollama —
the `hf.co/` direct-pull feature; check `ollama --version` if the pull is
rejected. Note it is an "abliterated" (refusal-removed) fine-tune, a real
behavior change from hermes3:8b, not just a smaller download — it now backs
every local-routed auxiliary slot, `approval` included.

### Step 1.3 — RETIRED 2026-09-25 · was "Local vision AND heavy local text"

This step, and Step 1.4 below, downloaded and served `nemotron-nano-12b-v2-vl`
via a second local server (`local-vl`, llama.cpp on :8080) — the VL runner the
old Division of Labour section described. That tier is gone from
`config.yaml` entirely, on request ("remove hermes 8B and the 12b").

`vision` now routes to the cloud: `custom:or-fallback` / `deepseek/deepseek-v4.1-flash`,
the same route it used before this tier ever existed and the one-line revert
this file always documented as the alternative to running a second local
service. Nothing to download, build, or serve here anymore.

The reasoning this step used to carry — why Ollama can't be trusted with a
VL GGUF's separate `mmproj` projector, the exact llama.cpp build floor and the
two PRs (`#19547`, `#23638`) a working build needed — is preserved in
`configs/hermes/config.yaml`'s git history if a local vision tier is ever
rebuilt. It no longer describes anything this file asks you to do. Skip to
Phase 2.

### Step 1.4 — RETIRED 2026-09-25 · was "Prove the VL model SEES and CALLS TOOLS"

Retired along with Step 1.3 above — there is no local vision model left to
probe. `vision`'s cloud route (DeepSeek-V4.1-Flash) is natively multimodal and
was verified as this slot's fix before the VL tier ever existed; nothing new
to prove here.

---

## Phase 2 — credentials

### Step 2.1 — Confirm the env file

```powershell
$e = Join-Path $env:LOCALAPPDATA 'hermes\.env'
Test-Path $e
```

**Success:** `True`. If `False`:

```powershell
New-Item -ItemType File -Path $e -Force
```

### Step 2.2 — Confirm the three keys are present

```powershell
Select-String -Path $e -Pattern '^(NVIDIA_API_KEY|HF_TOKEN|OPENROUTER_API_KEY)=' |
  ForEach-Object { ($_ -split '=')[0] }
```

**Success:** all three names print. **Names only — never print a value, never
paste one into a chat window, never put one in `config.yaml`.**

Only `NVIDIA_API_KEY` is strictly required to start. `HF_TOKEN` enables the parent
tier and `OPENROUTER_API_KEY` the fallback, so a stack missing either will run
degraded rather than fail loudly.

A fourth, fully optional key, `ANTHROPIC_API_KEY`, enables `anthropic-direct`
(claude-sonnet-5) — unwired into any tier, reachable only via
`/model custom:anthropic-direct:claude-sonnet-5`. Absent, nothing else is
affected. If set, use a key dedicated to this provider, never one shared with
Claude Code or another Anthropic surface on this machine — see the comment on
`anthropic-direct` in `config.yaml` for why.

### Step 2.3 — Render token

`render` is deliberately absent from this config. Its endpoint failed DNS
repeatedly, and an earlier revision of the deployed `config.yaml` carried an
**inline Render bearer token**.

**This is a human action, not a model action.** Rotate that token in the Render
dashboard. It persists in shell history and in the `config.yaml.bak-*` files on
this machine. Deleting the line does not un-expose it.

---

## Phase 3 — install the config

### Step 3.1 — Dry run

```powershell
pwsh -File scripts/hermes-apply.ps1 -WhatIf
```

**Success:** it lists what it would back up and install, and changes nothing.

### Step 3.2 — Apply

```powershell
pwsh -File scripts/hermes-apply.ps1
```

**Success:** `installed` lines for `config.yaml` and `config.toml`. Any existing
file is copied to `<name>.bak-<timestamp>` first.

### Step 3.3 — Point the three MCP subprocess variables

`config.yaml` names these by variable rather than by path, so the file stays
portable between machines.

```powershell
[Environment]::SetEnvironmentVariable('HERMES_SKILLS_SERVER',
  "$env:LOCALAPPDATA\hermes\skills-mcp-server\dist\index.js", 'User')

# hermes-council: the LAUNCHER is the command, and it pins the interpreter.
# HERMES_VENV_PYTHON is no longer used -- pointing at the venv was the bug.
[Environment]::SetEnvironmentVariable('HERMES_COUNCIL_LAUNCHER',
  "$PWD\scripts\hermes-council-launch.cmd", 'User')
[Environment]::SetEnvironmentVariable('HERMES_COUNCIL_PYTHON',
  (Get-Command python).Source, 'User')

# codex-mcp: same launcher pattern, one runtime over. The supervisor substitutes
# its own Node for a bare `command:` entry exactly as it did its own Python.
[Environment]::SetEnvironmentVariable('HERMES_CODEX_LAUNCHER',
  "$PWD\scripts\codex-mcp-launch.cmd", 'User')
[Environment]::SetEnvironmentVariable('HERMES_CODEX_NODE',
  (Get-Command node).Source, 'User')
```

Confirm the interpreter you just pinned is the one that actually has the package:

```powershell
& (Get-Command python).Source -c "import hermes_council; print('ok')"
```

**Success:** both paths exist.

```powershell
Test-Path $env:LOCALAPPDATA\hermes\skills-mcp-server\dist\index.js
Test-Path $env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\python.exe
```

Open a new shell before continuing — `SetEnvironmentVariable ... 'User'` does not
affect the current one.

### Step 3.4 — Install the ported skills

`hermes-skills/` holds 31 skills: 29 Claude skills converted to Hermes format, plus
two written by hand for this build. They are what let this install carry work on its
own rather than being a bare model router — research, security audit, investor
material, local desktop operation. Copying them is a separate step from
`hermes-apply.ps1`, which installs two config files and nothing else.

```powershell
$dest = Join-Path $HOME '.hermes\skills'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item -Path 'hermes-skills\*' -Destination $dest -Recurse -Force
hermes skills list
```

**Success:** `hermes skills list` shows 31 skills across 12 categories — the eleven
ported ones (`blockchain`, `software-development`, `security`, `research`, `finance`,
`creative`, `devops`, `productivity`, `media`, `autonomous-ai-agents`) plus
**`operations`**.

**`operations` is the one that matters for handing this build over.**
`operations/local-desktop` teaches `terminal`, `process` and `execute_code` as this
machine's capability surface; `operations/hermes-orchestration` covers *this* routing
build — the five tiers, the gateway ids, the scripts. Both are hand-written.

They are deliberately narrow, and step 3.4a installs the upstream skills that cover
the general case: upstream's `autonomous-ai-agents/hermes-agent` documents Hermes
itself better than ours does, and ours should not restate it.

Editing rule, and it differs by origin: the **ported** skills are regenerated by
`scripts/port-skills-to-hermes.js`, so hand-edits there are lost on the next run.
The `operations/` skills are written by hand and the script never touches them —
edit those directly.

`README.md` and `.port-lock.json` are copied along with the skills and are inert to
Hermes, which loads a skill from a `<category>/<name>/SKILL.md` directory and ignores
loose files. The lockfile is the record of which upstream revision each ported skill
came from. To find out whether any of them has gone stale:

```powershell
node scripts\port-skills-to-hermes.js --check
```

It writes nothing and never fails on drift — the upstream sources are not on this
machine, and `absent` for all of them is the expected answer here. Re-port on a box
that has them.

Both `operations/` skills are also declared for the **Claude surface** in
`capabilities.yaml` and generated into `.claude/skills/operations/`. That matters for a
handoff: it is what lets the model *instructing* this build see the same two skills the
local tier is being handed, instead of only Hermes seeing them.

### Step 3.4a — Enable the three upstream skills this build relies on

Hermes ships 24 categories of **optional** skills in its own tree, disabled by
default. Three of them back capabilities this config already turns on, and without
them those capabilities exist only on paper:

| Skill | Why this build needs it |
|---|---|
| `research/searxng-search` | `web.search_backend` is `searxng`. The backend is configured and the container documented; nothing taught the agent to use it. |
| `mcp/mcporter` | List, auth and call MCP servers from the terminal. This build runs 8 MCP servers and has lost time to three separate **silent** MCP failures. It is the only tool here that can diagnose them. |
| `software-development/subagent-driven-development` | `delegation` routes subagents to `custom:nvidia-nim` and `moa` aggregates through it. Both configured, neither taught. |

```powershell
# These live in the Hermes SOURCE tree. A one-line installer leaves none on disk,
# so find it rather than assuming a path.
$opt = @(
  "$HOME\.hermes\optional-skills",
  "$HOME\hermes-agent\optional-skills",
  "$env:LOCALAPPDATA\hermes\optional-skills"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $opt) {
  git clone --depth 1 https://github.com/NousResearch/hermes-agent "$HOME\hermes-agent-src"
  $opt = "$HOME\hermes-agent-src\optional-skills"
}
Write-Host "optional-skills: $opt"

$dest = Join-Path $HOME ".hermes\skills"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item (Join-Path $opt "research\searxng-search")                          $dest -Recurse -Force
Copy-Item (Join-Path $opt "mcp\mcporter")                                     $dest -Recurse -Force
Copy-Item (Join-Path $opt "software-development\subagent-driven-development")  $dest -Recurse -Force
hermes skills list
```

**Success:** all three appear in `hermes skills list`. `hermes-verify.ps1` warns for
each one that does not, from stage `b` onward.

**Do not port a Claude equivalent for these.** They are already in Hermes format.
`scripts/port-skills-to-hermes.js` exists to convert skills Hermes does *not* ship —
porting over something upstream already has is how `pptx` came to carry 1.3 MB of
duplicate OOXML schemas before it was caught.

### Step 3.5 — Restart the gateway

```powershell
hermes gateway restart
hermes gateway status
```

**Success:** status reports a running process.

---

## Phase 4 — known-broken items

Both were already failing before this runbook. Neither blocks the model tiers.

### Step 4.1 — hermes-council

```powershell
& $env:HERMES_COUNCIL_PYTHON -m hermes_council.server --help
```

**Success:** help text.

This used to read `$env:HERMES_VENV_PYTHON`, which step 3.3 above declares
obsolete and never sets — so on a box that followed this runbook in order, the
command ran with an empty interpreter path and failed for a reason that had
nothing to do with `hermes_council`. `HERMES_COUNCIL_PYTHON` is the variable
step 3.3 actually sets, and the one the launcher pins.

**This was the blocker, and it is FIXED — the cause was not what it looked like.**
The error was `ModuleNotFoundError: No module named 'mcp.server.fastmcp'`, which
reads as a missing dependency. It was not. `hermes_council` imports cleanly under
the interpreter it was installed into; the Hermes supervisor was substituting its
own bundled Python when launching the MCP entry.

The fix is `scripts/hermes-council-launch.cmd` — the supervisor launches the
launcher, the launcher pins the interpreter, and there is no longer anything for
the supervisor to substitute. Set `HERMES_COUNCIL_PYTHON` to the interpreter that
can import `hermes_council`:

```powershell
(Get-Command python).Source        # find it
[Environment]::SetEnvironmentVariable('HERMES_COUNCIL_PYTHON','<that path>','User')
[Environment]::SetEnvironmentVariable('HERMES_COUNCIL_LAUNCHER',"$PWD\scripts\hermes-council-launch.cmd",'User')
```

**If it errors again, check WHICH interpreter ran before suspecting any package.**
That inversion is the whole lesson: the error named a module, so a missing module
was the obvious inference, and it was wrong.

### Step 4.2 — Codex bridge

```powershell
codex mcp list
```

**Expected output:** `Unsupported`. **That is the correct result. Do not escalate
it, and do not try to repair it.**

`codex mcp-server` and the standalone `codex-mcp-server` binary were **removed**
in Codex 0.154.0 on 2026-09-05. The replacement, `codex app-server`, speaks its
own JSON-RPC 2.0 protocol and is not an MCP server — Codex is an MCP *client*
now. There is no handshake left to succeed, so no configuration on this box can
make this line pass. One official page still documents the removed tool; treat it
as stale.

This step is kept because the output is worth *recognising*. An earlier revision
called it a blocker and `hermes-verify.ps1` raised a FAIL on it, which made the
phase 6 gate unreachable on any machine with `codex` on PATH — a gate that can
never go green stops being read, and then it hides the failures that are real.
The verifier now warns instead.

**Delegation is unaffected** and is proven separately at step 5.5. Hermes reaches
Codex as a subprocess through the bundled `codex` skill, which never touches this
interface.

Do **not** "fix" this by setting `model.openai_runtime: codex_app_server`. That
routes Hermes' own reasoning through Codex and creates a second, invisible
consumer of the same ChatGPT 5-hour window — exactly what `openai-codex` sits in
`excluded_providers` to prevent. See `docs/models/codex-handoff.md`.

---

## Phase 5 — prove the routing

Five tests: one per tier, plus Codex delegation. Run them in order.

### Step 5.1 — Parent

```powershell
hermes --print "Reply with exactly: parent-ok"
```

**Success:** `parent-ok`, and `hermes` reports the model as
`deepseek-ai/DeepSeek-V4-Pro`.

**ESCALATE** if it answers on a different model — but **not** for the reason this
step used to give. It said the likely cause was the HF router not serving a 1.6T
model, and that has since been checked: the router serves
`deepseek-ai/DeepSeek-V4-Pro` through four live inference providers (novita,
featherless-ai, deepinfra, baseten). Coverage is not the problem.

So a different model here means something else — a silent substitution by the
router, a `discover_models` regression that unpinned the picker, or the parent
falling through to `fallback_providers` because `HF_TOKEN` is absent or spent.
`hermes-verify.ps1 -Deep` separates those: it prints the id the endpoint
*returned* alongside the one requested.

### Step 5.2 — Delegation

```powershell
hermes --print "Delegate to a subagent: have it reply with exactly subagent-ok"
```

**Success:** `subagent-ok`. Subagents must run on `nvidia/llama-3.3-nemotron-super-49b-v1.5`
(swapped from `nemotron-3-super-120b-a12b` 2026-09-25), a different provider from
the parent. Same provider on both means the split collapsed and the parent's
bucket is being spent twice.

### Step 5.3 — Tool call through Hermes

```powershell
hermes --print "Search the web for today's date and report it."
```

**Success:** a tool call is made and a date comes back. This exercises SearXNG and
Crawl4AI rather than the model.

### Step 5.4 — Local floor

```powershell
hermes --print --model custom:local:hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0 "Reply with exactly: floor-ok"
```

**Success:** `floor-ok`, served with no network dependency.

### Step 5.5 — Codex delegation

The step that proves the path Hermes actually uses. Everything in this repo about
Codex concerns the MCP bridge, which is dead upstream and does not matter;
delegation runs the CLI as a **subprocess**, and nothing until now exercised it.

```powershell
codex login status
```

**Success:** exits 0. If not, `codex login` (browser OAuth against the ChatGPT
plan — no separate billing), or set `CODEX_API_KEY` for metered per-token use.

Then one real delegation, in a throwaway directory so nothing real is edited:

```powershell
$t = Join-Path $env:TEMP 'codex-smoke'
New-Item -ItemType Directory -Path $t -Force | Out-Null
Push-Location $t
codex exec --json --sandbox workspace-write "Create hello.txt containing exactly: ready"
Get-Content .\hello.txt
Pop-Location
```

**Success:** a JSONL event stream on stdout, and `hello.txt` contains `ready`.

**Failure looks like** a hang with no output — Codex is an interactive terminal
app and needs a pty. From Hermes the bundled `codex` skill supplies that via
`terminal(..., pty=true, background=true)`; see `docs/models/codex-handoff.md:93`.

If it fails with `setting up uid map: Permission denied`, the sandbox cannot open
in this context. `--sandbox danger-full-access` works **per call** — never as the
config default.

---

## Phase 6 — the gate

### Step 6.1 — Full verification

```powershell
pwsh -File scripts/hermes-verify.ps1 -Deep
```

**Success:** `OK      no failures`.

`-Deep` makes one live request per remote provider. It prints the model id the
endpoint *returned*, which is not always the one requested — a router that
silently substitutes a model is exactly what this catches, and no local check can.

### Step 6.2 — Record the result

If anything diverged from this repo, update `docs/models/handoff-2026-09-22.md`
rather than leaving the difference undocumented. That file exists because the last
divergence went unrecorded for three days and cost a session to rediscover.

---

## Escalation table

| Symptom | Owner | First move |
|---|---|---|
| Model answers but ignores tools | Sonnet | Wrong chat template — fix the Modelfile `TEMPLATE` |
| Parent resolves to the wrong model | Sonnet | NOT router coverage — the HF router is confirmed to serve V4-Pro via 4 live providers. Check `HF_TOKEN`, `discover_models`, and the returned-vs-requested id from `-Deep` |
| `hermes mcp list` missing an entry | A human, or Claude | Re-run step 3.2, restart gateway, re-check once |
| `ModuleNotFoundError: mcp.server.fastmcp` | A human, or Claude | NOT a package fault — the supervisor substituted its Python. Check `HERMES_COUNCIL_PYTHON`, not pip |
| `codex mcp list` says `Unsupported` | **Nobody** | Expected and unfixable — the interface was removed upstream. Delegation is the subprocess path; prove it at step 5.5 |
| A fallback/aux slot 404s on OpenRouter | Sonnet | OpenRouter ids are lowercase `deepseek/...`, not the Hugging Face `deepseek-ai/DeepSeek-...` form. Same model, different namespace |
| Any key visible outside `.env` | **Human** | Rotate it first, then continue |
| Ollama tag not found | A human, or Claude | Tag string must match `config.yaml` exactly; re-run step 1.2 |
