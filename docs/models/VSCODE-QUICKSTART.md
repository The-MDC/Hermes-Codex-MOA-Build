# VS Code quickstart — local tier + DeepSeek, on Windows

The fast path. Gets `hermes3:8b`, `nemotron-nano:12b-v2` and both DeepSeek tiers
working, and nothing else. The full bring-up, including MCP servers and the two
known blockers, is `TAKEOVER.md`; this is the subset you need before any of that
matters.

Every step has a **success line**. A step is done when the output matches it —
not when the command exits without complaining. That distinction is the whole
reason this file is written out rather than improvised: a wrong chat template
still chats, and a dangling model reference still answers, just on the wrong model.

Total download: about 14 GB. Budget 20–40 minutes on a normal connection.

---

## 0. VS Code

### 0.1 — Open a PowerShell terminal

`` Ctrl+` `` opens the panel. The dropdown on its right must say **PowerShell**,
not Command Prompt or Git Bash. Everything below is PowerShell syntax; the
backtick line-continuations silently break in cmd.

```powershell
$PSVersionTable.PSVersion.Major
```

**Success:** `5` or higher. If the number is `5`, everything here still works —
`7` is nicer but nothing below requires it.

### 0.2 — Get the repo

```powershell
cd $HOME
git clone https://github.com/The-MDC/MADHATs-Claude-Enhancement.git
cd MADHATs-Claude-Enhancement
git checkout claude/lucid-noether-0ui54b
```

**Success:** `git log -1 --oneline` names a `hermes:` or `ci:` commit.

Then **File → Open Folder** on that directory, so the Claude Code extension picks
up `CLAUDE.md` and the repo's skills. Install the extension from the Marketplace
(search "Claude Code") if it is not there yet.

### 0.3 — Baseline

```powershell
pwsh -File scripts/hermes-verify.ps1 -Stage a
```

**Success:** it prints a verdict line. `FAILED` here is expected and fine — this
is a *baseline*, not a gate. Keep the output; you will compare at step 4.

If `pwsh` is not recognised, use `powershell` instead, or install PowerShell 7:
`winget install Microsoft.PowerShell`.

---

## 1. Ollama

### 1.1 — Install

```powershell
winget install Ollama.Ollama
```

Then **close and reopen the terminal** — `winget` does not refresh `PATH` in a
running shell, and this is the single most common reason the next step "fails".

```powershell
ollama --version
```

**Success:** a version prints.

### 1.2 — Confirm it is serving

```powershell
ollama list
```

**Success:** a table header prints, even with no rows.

If it hangs or errors, start the service in its own terminal with `ollama serve`
and leave it running.

---

## 2. Local models

### 2.1 — Support model

```powershell
ollama pull hermes3:8b
```

~4.7 GB. **Success:** `ollama list` shows `hermes3:8b`.

This one model already unblocks five of the eight auxiliary slots — routing,
classification, tool selection, titles, curation. If you stop here you have a
working floor.

### 2.2 — Try the registry before building anything

The heavier model may already be published to Ollama, in which case you skip the
GGUF import entirely. **Try this first:**

```powershell
ollama pull nemotron-nano:12b-v2
```

**If that succeeds:** skip to 2.5. **If it 404s**, that tag is not in the
registry and you build it from the GGUF below. Either outcome is normal; the
registry's naming does not always match ours.

### 2.3 — Download the GGUF

`hf` is not installed by default. Install it first:

```powershell
pip install -U "huggingface_hub[cli]"
hf --version
```

**Success:** a version prints. If `pip` is missing, install Python from
`winget install Python.Python.3.12`, reopen the terminal, and retry.

Then pull **only** the Q5_K_M. Without `--include` you download every quant in
the repo — tens of GB you will not use.

```powershell
hf download bartowski/nvidia_NVIDIA-Nemotron-Nano-12B-v2-GGUF `
  --include '*Q5_K_M*.gguf' `
  --local-dir "$HOME\Models\nemotron-nano-12b-v2"
```

**Success:** exactly one `.gguf` of about **8.76 GB**:

```powershell
Get-ChildItem "$HOME\Models\nemotron-nano-12b-v2" -Recurse -Filter *.gguf |
  Select-Object Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

**If the directory is empty after the command returns,** stop. That is exactly
how the previous attempt at this step failed — the command returned, the file
never appeared. Re-run once; if it is still empty, it is a network or auth
problem, not a naming one.

### 2.4 — Import it

Write the Modelfile using the **actual** filename from the previous step:

```powershell
cd "$HOME\Models\nemotron-nano-12b-v2"
$gguf = (Get-ChildItem -Recurse -Filter *.gguf | Select-Object -First 1).FullName
"FROM $gguf" | Set-Content .\Modelfile -Encoding ascii
Get-Content .\Modelfile
ollama create nemotron-nano:12b-v2 -f .\Modelfile
```

**Success:** `ollama list` shows `nemotron-nano:12b-v2`. **The tag must match
exactly** — `configs/hermes/config.yaml` names that string, and a mismatch does
not error, it silently resolves to a different model.

If `ollama create` rejects the file, the architecture is the likely cause: this
is a hybrid Mamba-Transformer (`nemotron_h`), and older llama.cpp builds cannot
load it. Update Ollama and retry once before escalating.

### 2.5 — Prove generation

```powershell
ollama run nemotron-nano:12b-v2 "Reply with exactly: ready"
```

**Success:** the reply contains `ready`.

### 2.6 — Prove TOOL CALLING

**Do not skip this.** It is the only step that catches a wrong chat template, and
a wrong template degrades tool use while ordinary chat still looks perfect.

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

(Invoke-RestMethod -Method Post `
  -Uri 'http://127.0.0.1:11434/v1/chat/completions' `
  -ContentType 'application/json' -Body $body).choices[0].message |
  ConvertTo-Json -Depth 10
```

**Success:** the response contains a `tool_calls` array naming `get_weather`.

**Failure looks like** prose about the weather, or prose *describing* the tool it
would call. Both mean the template is wrong and the fix is a `TEMPLATE` directive
in the Modelfile — a judgment call, so escalate rather than guess.

Repeat this test for `hermes3:8b` by changing the `model` line. It carries five
auxiliary slots, so its tool calling matters more than the heavy model's.

---

## 3. DeepSeek

**Nothing is installed locally.** DeepSeek-V4-Pro is 1.6T parameters and
V4.1-Flash is 552B; both are API-only. This step is two keys and a file.

### 3.1 — Create the env file

```powershell
$envFile = Join-Path $env:LOCALAPPDATA 'hermes\.env'
New-Item -ItemType File -Path $envFile -Force | Out-Null
$envFile
```

### 3.2 — Add the keys

Open it in VS Code — `code $envFile` — and add three lines. **Paste the values in
the editor, never into a terminal**, so they do not land in shell history:

```
NVIDIA_API_KEY=nvapi-...
HF_TOKEN=hf_...
OPENROUTER_API_KEY=sk-or-v1-...
```

| key | from | serves |
|---|---|---|
| `HF_TOKEN` | huggingface.co/settings/tokens | **parent** — DeepSeek-V4-Pro |
| `OPENROUTER_API_KEY` | openrouter.ai/keys | **fallback + heavy aux** — DeepSeek-V4.1-Flash |
| `NVIDIA_API_KEY` | build.nvidia.com | **subagents** — Nemotron-3-Super-120B |

Only `NVIDIA_API_KEY` is strictly required for Hermes to start. Missing either
other key makes that tier fail over silently rather than error, which is why
step 4 checks them explicitly.

**Never put a key in `config.yaml`.** CI rejects key-shaped strings there, and
`hermes-verify.ps1` checks the installed copy too.

### 3.3 — Install the config

```powershell
cd $HOME\MADHATs-Claude-Enhancement
pwsh -File scripts\hermes-apply.ps1 -WhatIf     # look first
pwsh -File scripts\hermes-apply.ps1
```

**Success:** `installed` lines for `config.yaml` and `config.toml`. Anything
already there is copied to `<name>.bak-<timestamp>` first — your existing config
is not destroyed, and any local edit survives in that backup.

---

## 4. Verify

### 4.1 — Local only

```powershell
pwsh -File scripts\hermes-verify.ps1 -Stage b
```

**Success:** both models report `present`, and Ollama answers on `127.0.0.1:11434`.

### 4.2 — The live check that matters

```powershell
pwsh -File scripts\hermes-verify.ps1 -Stage full -Deep
```

`-Deep` reads the keys from `.env` and makes one real request per provider. It
checks each provider's **catalog first**, then the completion — because a failed
completion alone cannot tell a wrong model id from an exhausted quota, and those
need opposite fixes.

**This is the step that answers the one thing CI structurally cannot:** whether
`deepseek-ai/DeepSeek-V4-Pro` is actually served by the HF router, and whether
`deepseek/deepseek-v4.1-flash` is actually on OpenRouter. Neither was
verifiable from the build container.

Three outcomes, three different meanings:

| Output | Means | Do |
|---|---|---|
| `catalog lists '<model>'` then `served '<model>'` | working | nothing |
| `catalog does NOT list '<model>'` | **the id is wrong for that provider** | use one of the nearest ids it prints; edit the repo config, re-run 3.3 |
| catalog lists it but the completion fails | quota, billing, or rate limit | check the provider dashboard — the config is right |
| `answered as '<other>', NOT the '<model>' we asked for` | **silent substitution** — a router quietly swapped models | pin the provider explicitly |

Report the `catalog does NOT list` case back before changing anything: choosing a
replacement model is a design decision, not a retry.

---

## What you have at this point

```
parent      hf-router     DeepSeek-V4-Pro        API only
subagents   nvidia-nim    Nemotron-3-Super-120B  API only
fallback    or-fallback   DeepSeek-V4.1-Flash    API only, also 2 heavy aux slots
floor       local         hermes3:8b             5 aux slots, offline-capable
            local         nemotron-nano:12b-v2   heavier local work
vision      local-vl      nemotron-nano-12b-v2-vl  NOT SET UP BY THIS FILE
```

Not covered here, deliberately: the seven MCP servers, `hermes-council`'s
dependency fault, and the Codex bridge handshake. None of them gate the model
tiers. `scripts\hermes-blockers.ps1` diagnoses the last two without changing
anything, and `TAKEOVER.md` phases 3–6 cover the rest.

**Nor is the vision tier — and that one shows up as a failure.** `config.yaml`
routes `vision` to a `local-vl` provider served by **llama.cpp on :8080**, not by
Ollama. Ollama cannot attach the `mmproj` projector a VL model needs, and it fails
by silently dropping vision rather than refusing, so `ollama create` would leave
you a model with `-VL` in its name that cannot see. `TAKEOVER.md` step 1.7 sets it
up properly.

Until you do, `hermes-verify.ps1` FAILs on port 8080. That failure is accurate
rather than noise: the vision slot genuinely has no backend. Every other tier
works around it.

If you would rather not run a second local service, revert `vision` in
`config.yaml` to `custom:or-fallback` / `deepseek/deepseek-v4.1-flash`, which is
natively multimodal and is what fixed that slot originally. One line.
