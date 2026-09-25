# VS Code quickstart — local tier + DeepSeek, on Windows

The fast path. Gets `hermes3:8b` and both DeepSeek tiers
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
git clone https://github.com/The-MDC/hermes-codex-build.git
cd hermes-codex-build
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

**Optional fourth key**, only if you want Claude reachable from inside Hermes:

```
ANTHROPIC_API_KEY=sk-ant-...
```

From console.anthropic.com/settings/keys. **Use a key dedicated to this
provider** — not whatever authenticates Claude Code or any other Anthropic
surface on this machine, or spend on one becomes invisible to the other, the
same failure this config already excludes `openai-codex` to prevent for
ChatGPT. Enables `anthropic-direct` — reachable via
`/model custom:anthropic-direct:claude-sonnet-5`, wired into nothing by
default. Its absence changes no other tier; skip it if you don't need Claude
inside Hermes specifically.

**Never put a key in `config.yaml`.** CI rejects key-shaped strings there, and
`hermes-verify.ps1` checks the installed copy too.

### 3.3 — Install the config

```powershell
cd $HOME\hermes-codex-build
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
vision +    local-vl      nemotron-nano-12b-v2-vl  NOT SET UP BY THIS FILE
heavy local                                        images AND heavy local text
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
