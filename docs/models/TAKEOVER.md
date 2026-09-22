# Takeover runbook — bringing the Hermes stack up from Hermes Desktop

For whoever implements this next, running on the Windows box rather than in CI.
Self-contained on purpose: you do not need to read another file in this repo to
execute it. Context for *why* the stack is shaped this way is in
`running-the-stack.md` and `handoff-2026-09-22.md`; you do not need either to
follow the steps below.

## Division of labour

| Model | Does | Does not |
|---|---|---|
| **Nemotron Nano 12B v2** (local) | Runs the numbered steps. Copies commands, compares output to the stated success line, reports which step failed. | Decide anything. Edit config by hand. Improvise a fix. |
| **Claude Sonnet** | Every ESCALATE row. Diagnoses failures, writes config changes, decides trade-offs. | Skip the verify gate because a step "looks fine". |

**The one rule that matters:** a step is done when its success line matches. Not
when the command exits 0, not when the output looks plausible. A wrong chat
template still chats. A dangling model reference still answers — on the wrong
model.

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
predictably until Ollama holds both models.

### Step 1.1 — Confirm Ollama is serving

```powershell
ollama list
```

**Success:** a table prints, even if empty.
**If `ollama` is not recognised:** install Ollama, reopen the shell, retry once.

### Step 1.2 — Pull the support model

```powershell
ollama pull hermes3:8b
```

**Success:** `ollama list` now shows `hermes3:8b`.

### Step 1.3 — Import the Nemotron floor

Download the Q5_K_M only. **Not** `bartowski/nvidia_Llama-3.1-Nemotron-Nano-8B-v1-GGUF`
— that is a March 2025 Llama-3.1 model, three Nemotron generations old, and not
what this config names.

The `--include` filter matters: the repo holds every quant, and without it you
pull tens of GB you will not use.

```powershell
hf download bartowski/nvidia_NVIDIA-Nemotron-Nano-12B-v2-GGUF `
  --include '*Q5_K_M*.gguf' `
  --local-dir "$HOME\Models\nemotron-nano-12b-v2" `
  --max-workers 4
```

**Success:** exactly one `.gguf` of about **8.76 GB** exists under that directory.

```powershell
Get-ChildItem "$HOME\Models\nemotron-nano-12b-v2" -Filter *.gguf |
  Select-Object Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

If the machine has under 16 GB of RAM, stop and escalate rather than continuing:
`NVIDIA-Nemotron-Nano-9B-v2` at Q5 (~6.5 GB) is the substitution, and swapping it
means editing `config.yaml` in the repo, which is a Sonnet action.

**ESCALATE** if the directory is empty after the command returns. The previous
attempt at this step, with the older model, failed exactly this way: the command
returned, the file never appeared.

### Step 1.4 — Register it with Ollama

Write a `Modelfile` next to the GGUF, substituting the actual filename:

```
FROM ./<the-file>.gguf
```

Then:

```powershell
cd "$HOME\Models\nemotron-nano-12b-v2"
ollama create nemotron-nano:12b-v2 -f .\Modelfile
```

**Success:** `ollama list` shows `nemotron-nano:12b-v2`. The tag must match exactly —
`config.yaml` names this string, and a mismatch resolves to nothing.

### Step 1.5 — Prove generation

```powershell
ollama run nemotron-nano:12b-v2 "Reply with exactly: ready"
```

**Success:** the reply contains `ready`.

### Step 1.6 — Prove TOOL CALLING

Do not skip this. It is the step that catches a wrong chat template, and a wrong
template degrades tool use silently while ordinary chat looks fine.

```powershell
$body = @{
  model = 'nemotron-nano:12b-v2'
  messages = @(@{ role='user'; content='What is the weather in Denver? Use the tool.' })
  tools = @(@{
    type = 'function'
    function = @{
      name = 'get_weather'
      description = 'Get current weather for a city'
      parameters = @{
        type = 'object'
        properties = @{ city = @{ type='string' } }
        required = @('city')
      }
    }
  })
} | ConvertTo-Json -Depth 10

(Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:11434/v1/chat/completions' `
  -ContentType 'application/json' -Body $body).choices[0].message |
  ConvertTo-Json -Depth 10
```

**Success:** the response contains a `tool_calls` array naming `get_weather`.
**Failure looks like:** prose describing the weather, or prose describing the tool
it would call. Both mean the template is wrong.

**ESCALATE** on failure. The fix is a `TEMPLATE` directive in the Modelfile, and
choosing it is a judgment call.

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

### Step 3.3 — Point the two MCP subprocess variables

`config.yaml` names these by variable rather than by path, so the file stays
portable between machines.

```powershell
[Environment]::SetEnvironmentVariable('HERMES_SKILLS_SERVER',
  "$env:LOCALAPPDATA\hermes\skills-mcp-server\dist\index.js", 'User')
[Environment]::SetEnvironmentVariable('HERMES_VENV_PYTHON',
  "$env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\python.exe", 'User')
```

**Success:** both paths exist.

```powershell
Test-Path $env:LOCALAPPDATA\hermes\skills-mcp-server\dist\index.js
Test-Path $env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\python.exe
```

Open a new shell before continuing — `SetEnvironmentVariable ... 'User'` does not
affect the current one.

### Step 3.4 — Restart the gateway

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
& $env:HERMES_VENV_PYTHON -m hermes_council.server --help
```

**Success:** help text.
**Known failure:** `ModuleNotFoundError: No module named 'mcp.server.fastmcp'` —
the package imports but its MCP entrypoint does not, which is an SDK version
mismatch inside the Hermes venv.

**ESCALATE.** Until it is fixed, comment the `hermes-council` block out of
`configs/hermes/config.yaml` and re-run step 3.2, rather than leaving it
crash-looping on every Hermes start.

### Step 4.2 — Codex bridge

```powershell
codex mcp list
```

**Success:** a `hermes` entry with no `Unsupported`.
**Known failure:** status `Unsupported`. The binary and the registration both
exist, so this is a protocol-version mismatch, not a missing install. Note that
`codex mcp-server` and the standalone `codex-mcp-server` binary were **removed**
on 2026-09-05; the replacement is `codex app-server`, JSON-RPC 2.0 over
stdio/websocket/unix socket. One official page still documents the removed tool —
treat it as stale.

**ESCALATE.** Codex is reached as a subprocess through the bundled `codex` skill,
so delegation still works while this is broken.

---

## Phase 5 — prove the routing

Four tests, one per tier. Run them in order.

### Step 5.1 — Parent

```powershell
hermes --print "Reply with exactly: parent-ok"
```

**Success:** `parent-ok`, and `hermes` reports the model as
`deepseek-ai/DeepSeek-V4-Pro`.

**ESCALATE** if it answers on a different model. The likely cause is that the HF
router does not serve a 1.6T model, in which case the parent moves to
`or-fallback` — a config change, not a retry.

### Step 5.2 — Delegation

```powershell
hermes --print "Delegate to a subagent: have it reply with exactly subagent-ok"
```

**Success:** `subagent-ok`. Subagents must run on `nvidia/nemotron-3-super-120b-a12b`,
a different provider from the parent. Same provider on both means the split
collapsed and the parent's bucket is being spent twice.

### Step 5.3 — Tool call through Hermes

```powershell
hermes --print "Search the web for today's date and report it."
```

**Success:** a tool call is made and a date comes back. This exercises SearXNG and
Crawl4AI rather than the model.

### Step 5.4 — Local floor

```powershell
hermes --print --model custom:local:hermes3:8b "Reply with exactly: floor-ok"
```

**Success:** `floor-ok`, served with no network dependency.

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
| Parent resolves to the wrong model | Sonnet | HF router likely does not serve V4-Pro; move parent to `or-fallback` |
| `hermes mcp list` missing an entry | Nemotron | Re-run step 3.2, restart gateway, re-check once |
| `ModuleNotFoundError: mcp.server.fastmcp` | Sonnet | MCP SDK version mismatch in the venv |
| `codex mcp list` says `Unsupported` | Sonnet | Protocol mismatch; `codex app-server` is the current interface |
| Any key visible outside `.env` | **Human** | Rotate it first, then continue |
| Ollama tag not found | Nemotron | Tag string must match `config.yaml` exactly; re-run step 1.4 |
