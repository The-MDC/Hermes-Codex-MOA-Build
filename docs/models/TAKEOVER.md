# Takeover runbook — bringing the Hermes stack up from Hermes Desktop

For whoever implements this next, running on the Windows box rather than in CI.
Self-contained on purpose: you do not need to read another file in this repo to
execute it. Context for *why* the stack is shaped this way is in
`running-the-stack.md` and `handoff-2026-09-22.md`; you do not need either to
follow the steps below.

## Division of labour

Three actors, not two — because the local runner cannot run the steps that install
the local runner, and every earlier version of this table left that unsaid.

| Actor | Available | Does | Does not |
|---|---|---|---|
| **A human, or Claude** | from the start | Phases 0 through step 1.3, before any local model exists. Installs Ollama, pulls `hermes3:8b`, installs llama.cpp, stands up `llama-server`. | Skip step 1.4 because "the model is there". |
| **`nemotron-nano-12b-v2-vl`** (local, llama-server :8080) — the **VL runner** below and in the escalation table | **step 1.3 onward** | Runs the numbered steps. Compares command output **and screenshots** against the stated success line, and reports which step failed. | Decide anything. Edit config by hand. Improvise a fix. Execute commands — see below. |
| **Claude Sonnet** | from the start | Every ESCALATE row. Diagnoses failures, writes config changes, decides trade-offs. | Skip the verify gate because a step "looks fine". |

**Why a vision model runs this runbook.** The loop below is "compare the output to
the stated success line", and on a Windows bring-up much of that output is not text.
`winget`'s installer dialogs, the VS Code terminal dropdown that must read
*PowerShell* rather than Command Prompt, the `ollama list` table, an error popup,
the Cloudflare and Render dashboard pages — a text-only runner sees none of it,
because none of it arrives on stdout. Several success lines in this file describe
exactly those things. Hand the VL model a screenshot and it can check them.

**It reads and reports; it does not execute — until step 1.4 says otherwise.** This
model was imported from a bare GGUF with no `TEMPLATE` directive, so its tool-calling
convention is unverified, and a wrong template degrades tool use while ordinary chat
looks perfect. Commands stay in the shell a human or the harness drives.

**Step 1.4 is the gate that lifts this.** It runs two probes against :8080 — one that
the model genuinely sees an image, one that it emits real `tool_calls` — and its
outcome table says which of the three roles this runner may actually hold. Do not
promote it to driving execution on the strength of ordinary chat looking fine; that
is exactly what a wrong template hides. (The quickstart covers Ollama's `hermes3:8b` on :11434 only; it does
not probe this model at all.)

**The availability column is load-bearing.** `nemotron-nano-12b-v2-vl` is served by
`llama-server` on `127.0.0.1:8080`, and step 1.3 is what starts it. Before that it
has no backend, so it cannot be the thing checking step 1.3's own success line.
The same was quietly true of the model this table used to name — imported at step
1.4 — which is how a runbook ends up implying a model runs the steps that create it.

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

The local tier backs the floor plus five auxiliary slots, and the VL runner backs
vision plus all heavy local text. Nothing else works predictably until Ollama holds
`hermes3:8b` and `llama-server` is answering on :8080.

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

### Step 1.3 — Local vision AND heavy local text: llama.cpp, NOT Ollama

**Do not try to do this with Ollama.** A VL GGUF ships as two files — the language
model and a separate `mmproj` projector — and Ollama's Modelfile cannot attach the
second one. Two `FROM` lines error, `ADAPTER` does not work
([ollama#14730](https://github.com/ollama/ollama/issues/14730),
[ollama#9967](https://github.com/ollama/ollama/issues/9967)).

The failure mode is why this warning is here: **`ollama create` succeeds**, silently
dropping the projector. You get a model with `-VL` in its name that cannot see —
the same silent capability loss that `vision: auto` already caused once.

Download both files (≈10.5 GB total):

```powershell
hf download Vastined/NVIDIA-Nemotron-Nano-12B-v2-VL-BF16-GGUF `
  --include '*Q5_K_M*.gguf' '*mmproj*.gguf' `
  --local-dir "$HOME\Models\nemotron-nano-12b-v2-vl"
```

**Success:** two files — `...VL-Q5_K_M.gguf` at about **8.77 GB** and
`...VL-BF16-mmproj.gguf` at about **1.69 GB**. The projector is not quantized and
there is only one; if you have only the first file, vision will not work.

#### Get llama.cpp

Requires **b6315 or later** — that is where `nemotron_h`, this model's hybrid
Mamba-Transformer architecture, became supported. An older build refuses to load
rather than degrading, which is the good failure. Current nightlies are around
**b11118** (checked 2026-09-23), so any recent build clears the floor comfortably.

Releases are at <https://github.com/ggml-org/llama.cpp/releases>. Take a `b#####` tag,
**not** a `v0.4.x` one — the `v` releases carry no Windows binaries. Pick one zip:

| Asset | When |
|---|---|
| `llama-b#####-bin-win-cuda-12.4-x64.zip` | NVIDIA GPU, driver for CUDA 12.x |
| `llama-b#####-bin-win-cuda-13.4-x64.zip` | NVIDIA GPU, newer driver |
| `llama-b#####-bin-win-cpu-x64.zip` | no NVIDIA GPU, or unsure |
| `llama-b#####-bin-win-cpu-arm64.zip` | Snapdragon X / ARM laptop |

**A CUDA build also needs its runtime.** Download the matching
`cudart-llama-bin-win-cuda-<same-version>-x64.zip` and unzip it **into the same
folder**. Without it `llama-server.exe` exits immediately on a missing DLL, and the
error does not mention CUDA.

```powershell
$dest = "$HOME\llama.cpp"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
# unzip BOTH archives into $dest, then:
$env:PATH = "$dest;$env:PATH"
llama-server --version
```

**Success:** a version line carrying a `b#####` number ≥ 6315.

#### Serve it

```powershell
$m = "$HOME\Models\nemotron-nano-12b-v2-vl"
llama-server -m "$m\NVIDIA-Nemotron-Nano-12B-v2-VL-Q5_K_M.gguf" `
             --mmproj "$m\NVIDIA-Nemotron-Nano-12B-v2-VL-BF16-mmproj.gguf" `
             --alias nemotron-nano-12b-v2-vl `
             --host 127.0.0.1 --port 8080 `
             -c 16384 -ngl 99 --jinja
```

Four of those decide whether this works on a laptop:

- **`--alias` is load-bearing.** Without it llama-server names the model after its
  file path, `config.yaml`'s `local-vl.default_model` stops matching, and
  `hermes-verify.ps1` reports an id mismatch that reads like a wrong model.
- **`-c 16384`** matches `local-vl.context_length` in `config.yaml`. Leave it off and
  llama-server allocates the model's native window; the KV cache, not the weights, is
  what exhausts a 16 GB laptop. Raise both numbers together or neither.
- **`-ngl 99`** offloads every layer it can to the GPU. A CPU-only build ignores it,
  so it is safe to leave in. Lower it toward `-ngl 20` if VRAM is the limit — the
  model still runs, just slower.
- **`--jinja`** uses the model's own chat template. Step 1.4's tool-call probe fails
  without it, and it fails as *prose about calling a tool* rather than as an error.

**`--host 127.0.0.1` is deliberate.** The server takes no key — `local-vl.api_key` is
the literal placeholder `"no-key-required"` — so binding `0.0.0.0` would put an
unauthenticated model endpoint on the local network. If it genuinely has to leave the
box, put a reverse proxy in front and add auth there.

**Success:**

```powershell
(Invoke-RestMethod http://127.0.0.1:8080/v1/models).data.id
```

prints exactly `nemotron-nano-12b-v2-vl`.

#### Keep it running

The `vision` slot and all heavy local text route here, so a stopped server is a
missing capability — `hermes-verify.ps1` FAILs on port 8080 for that reason. A
terminal window someone can close is not a deployment. Pick one:

1. **Windows service via NSSM** — survives logout and reboot, restarts on crash.
   `nssm install llama-vl "$HOME\llama.cpp\llama-server.exe"`, set the arguments and
   startup directory, then `nssm start llama-vl`. Use this before relying on the tier,
   and definitely before handing the machine off.
2. **Scheduled Task at log on** — `schtasks /create /tn llama-vl /sc onlogon /rl
   highest /tr "...\llama-server.exe <args>"`. No extra software; does not survive a
   logged-out reboot.
3. **A pinned terminal** — what the bare command above gives you. Fine while bringing
   the stack up, wrong for anything after.
4. **Docker** with `--restart unless-stopped`. Clean lifecycle, but GPU passthrough on
   Windows adds a layer and the model files have to be mounted in.

Start at 3 to prove it works, then move to 1.

**If you would rather not run a second local service,** revert `vision` in
`config.yaml` to `custom:or-fallback` / `deepseek/deepseek-v4.1-flash`. That model
is natively multimodal and is what fixed the slot originally. One line, no loss
except offline capability.

### Step 1.4 — Prove the VL model SEES and CALLS TOOLS

Two probes, and they answer two different questions. Run both.

The division-of-labour table scopes the VL runner to **read, compare and report** —
not to execute commands — precisely because its tool calling is unproven. This step
is what lifts that restriction, or confirms it should stay.

**Probe 1 — does it actually see?** The whole reason for this tier. A VL model served
without its projector loads fine and answers about images from the text alone.

```powershell
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 64,64
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.FillEllipse([System.Drawing.Brushes]::Red, 8, 8, 48, 48)
$g.Dispose()
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$b64 = [Convert]::ToBase64String($ms.ToArray())
$bmp.Dispose(); $ms.Dispose()

$body = @{
  model = 'nemotron-nano-12b-v2-vl'
  messages = @(@{
    role = 'user'
    content = @(
      @{ type='text'; text='What colour is the shape? Answer with one word.' },
      @{ type='image_url'; image_url=@{ url="data:image/png;base64,$b64" } }
    )
  })
  max_tokens = 10
} | ConvertTo-Json -Depth 12

(Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8080/v1/chat/completions' `
  -ContentType 'application/json' -Body $body).choices[0].message.content
```

**Success:** the reply says **red**.

**Failure looks like** a refusal, a description of something that is not there, or a
guess like "blue" — all of which mean the projector is not attached. Restart
`llama-server` and confirm `--mmproj` is on the command line and points at the
`...mmproj.gguf` file, not at the model. This is the failure that `ollama create`
produces silently, and it is why this tier is not an Ollama tag.

**Probe 2 — does it emit real `tool_calls`?**

```powershell
$body = @{
  model = 'nemotron-nano-12b-v2-vl'
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

(Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8080/v1/chat/completions' `
  -ContentType 'application/json' -Body $body).choices[0].message | ConvertTo-Json -Depth 10
```

**Success:** a `tool_calls` array naming `get_weather`.

**Failure looks like** prose about the weather, or prose *describing* the tool it
would call. Both mean the chat template is wrong — the GGUF was imported with no
`TEMPLATE` directive, so whatever the file embeds is what you get.

**What each outcome means for the role:**

| Probe 1 | Probe 2 | The VL runner |
|---|---|---|
| red | `tool_calls` | Can read, compare, report **and drive execution**. Lift the restriction |
| red | prose | Reads and reports only, as the table already says. Usable — this is the expected case until a template is fixed |
| wrong | either | **Not usable for vision at all.** `--mmproj` is missing or wrong; fix that before anything else |

**ESCALATE** on a probe-1 failure. A template fix for probe 2 is a judgment call and
also escalates, but the build is still usable meanwhile.

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
| `hermes mcp list` missing an entry | VL runner | Re-run step 3.2, restart gateway, re-check once |
| `ModuleNotFoundError: mcp.server.fastmcp` | VL runner | NOT a package fault — the supervisor substituted its Python. Check `HERMES_COUNCIL_PYTHON`, not pip |
| `codex mcp list` says `Unsupported` | **Nobody** | Expected and unfixable — the interface was removed upstream. Delegation is the subprocess path; prove it at step 5.5 |
| A fallback/aux slot 404s on OpenRouter | Sonnet | OpenRouter ids are lowercase `deepseek/...`, not the Hugging Face `deepseek-ai/DeepSeek-...` form. Same model, different namespace |
| Any key visible outside `.env` | **Human** | Rotate it first, then continue |
| Ollama tag not found | VL runner | Tag string must match `config.yaml` exactly; re-run step 1.4 |
